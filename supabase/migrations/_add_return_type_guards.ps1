# Inserts a "return type changed" guard in front of every
# `create or replace function` in 00021_full_schema.sql.
#
# WHY THIS IS NEEDED
#
# PostgreSQL cannot change a function's return type in place. Replaying the
# merged schema against a database that already has an earlier definition
# fails with:
#
#   ERROR:  42P13: cannot change return type of existing function
#   HINT:  Use DROP FUNCTION get_messages(uuid,timestamp with time zone,integer) first.
#
# The chain really does do this. `get_messages` and `get_messages_after` are
# created by 00001 as `returns setof public.messages` and then redefined by
# 00012 as `returns table (id uuid, ...)`. So the very upgrade path this single
# file exists to support is the one that breaks.
#
# For each definition the guard compares the declared return type against
# `pg_get_function_result` for the installed function and drops first only when
# they disagree. Same return type -> the original `create or replace` runs
# untouched, so the common case is unaffected.
#
# Comparison is done by normalising BOTH sides inside SQL (lowercase, all
# whitespace removed) rather than predicting how Postgres will render
# `returns table (...)`. That keeps the guard correct even when the rendering
# of a type alias differs (`int` vs `integer`, `timestamptz` vs
# `timestamp with time zone`).
#
# IDEMPOTENT: a definition already preceded by a guard is skipped, so this can
# be re-run over an already-processed file without nesting DO blocks.
#
#   powershell -ExecutionPolicy Bypass -File supabase/migrations/_add_return_type_guards.ps1

$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $dir '00021_full_schema.sql'
if (-not (Test-Path $target)) { throw "missing $target" }

$raw = [System.IO.File]::ReadAllText($target, [System.Text.Encoding]::UTF8)

# Strip any guards this script inserted on a previous run, so the file is
# always rebuilt from a clean state. Without this a partially-applied pass
# could never be corrected by simply re-running.
$guardBlock = '(?ms)^do \$\$\r?\ndeclare\r?\n  v_want text := .*?^end;\r?\n\$\$;\r?\n(?:\r?\n)?'
$raw = [regex]::Replace($raw, $guardBlock, '')
$stripped = ([regex]::Matches([System.IO.File]::ReadAllText($target, [System.Text.Encoding]::UTF8), $guardBlock)).Count

$lines = $raw -split "`r?`n"

# Reads the function name, identity arguments and declared return type from
# the `create or replace function` line at $start. Returns $null if the header
# cannot be parsed, in which case the definition is left untouched.
function Read-FunctionHeader([string[]] $l, [int] $start) {
  $name = $null
  for ($i = $start; $i -lt $l.Length; $i++) {
    if ($null -eq $name) {
      if ($l[$i] -match 'create or replace function\s+(?:public\.)?(\w+)\s*\(') {
        $name = $matches[1]
      } else {
        continue
      }
    }

    $open = $l[$i].IndexOf('(')
    if ($open -lt 0) { continue }
    $buf = ''
    $depth = 0
    $j = $i
    for (; $j -lt $l.Length; $j++) {
      foreach ($ch in $l[$j].ToCharArray()) {
        if ($ch -eq '(') { $depth++ } elseif ($ch -eq ')') { $depth-- }
      }
      $buf += $l[$j]
      if ($depth -le 0) { break }
    }
    $argsRaw = $buf.Substring($buf.IndexOf('(') + 1, $buf.LastIndexOf(')') - $buf.IndexOf('(') - 1)
    $tail = $buf.Substring($buf.LastIndexOf(')') + 1)

    $opts = $tail
    for ($k = $j + 1; $k -lt $l.Length; $k++) {
      $opts += ' ' + $l[$k].Trim()
      if ($opts -match '(?i)returns\s+(table\s*\(.*?\)|setof\s+[\w\.\[\]]+|[\w\.\[\]]+)\s*(?:language\b|security\b|as\b|$)') { break }
    }
    if ($opts -notmatch '(?i)returns\s+(table\s*\(.*?\)|setof\s+[\w\.\[\]]+|[\w\.\[\]]+)\s*(?:language\b|security\b|as\b|$)') {
      return $null
    }
    $returnText = $matches[1].Trim()

    # Identity argument types: the type token of each parameter, in order,
    # with any default expression removed. `to_regprocedure` resolves the
    # aliases itself, so `int` and `timestamptz` are accepted as written.
    $argTypes = @()
    $argCount = 0
    foreach ($a in ($argsRaw -split ',' | Where-Object { $_.Trim() })) {
      $a = $a -replace '(?i)default\s+.*$', ''
      $parts = $a.Trim() -split '\s+'
      if ($parts.Count -lt 2) { return $null }
      $argTypes += $parts[-1]
      $argCount++
    }

    return [pscustomobject]@{
      Name       = $name
      ArgTypes   = $argTypes
      ReturnText = $returnText
    }
  }
  return $null
}

$out = New-Object System.Text.StringBuilder
$inserted = 0
$skipped = 0
$unparsed = 0

for ($i = 0; $i -lt $lines.Length; $i++) {
  $line = $lines[$i]

  if ($line -match '^\s*create or replace function\s') {
    # Idempotency: skip if a guard we already wrote sits immediately above.
    # Scans upward for our own marker rather than testing for a trailing `$$;`,
    # because every function body ends with `$$;` — that test alone would
    # wrongly report a guard for any function that merely follows another.
    $alreadyGuarded = $false
    for ($j = $i - 1; $j -ge 0 -and $j -ge $i - 25; $j--) {
      if ($lines[$j] -match 'to_regprocedure') { $alreadyGuarded = $true; break }
      # Stop if we have walked past the start of the previous function.
      if ($lines[$j] -match '^\s*create (or replace )?function\s') { break }
    }

    $header = Read-FunctionHeader $lines $i
    if ($null -eq $header) {
      $unparsed++
    } elseif (-not $alreadyGuarded) {
      $procName = 'public.' + $header.Name
      $sigTypes = $header.ArgTypes -join ','
      $regProc = "$procName($sigTypes)"
      # Literals for the SQL string. Doubling embedded quotes is enough: the
      # only one that can appear is the quoting of the return type.
      $regLit = $regProc.Replace("'", "''")
      $wantLit = $header.ReturnText.Replace("'", "''")

      [void]$out.AppendLine('do $$')
      [void]$out.AppendLine('declare')
      [void]$out.AppendLine('  v_want text := ' + "'" + $wantLit + "';")
      [void]$out.AppendLine('  v_have text;')
      [void]$out.AppendLine('begin')
      [void]$out.AppendLine('  -- 42P13 guard. PostgreSQL cannot change a function''s return type')
      [void]$out.AppendLine('  -- in place, so drop the installed version when the return type')
      [void]$out.AppendLine('  -- differs from the one this file declares. Same type -> no-op.')
      [void]$out.AppendLine('  select pg_get_function_result(p.oid) into v_have')
      [void]$out.AppendLine('    from pg_proc p')
      [void]$out.AppendLine('   where p.oid = to_regprocedure(' + "'" + $regLit + "'" + ');')
      [void]$out.AppendLine('')
      [void]$out.AppendLine('  if v_have is not null')
      [void]$out.AppendLine('     and regexp_replace(lower(v_have), ''\s+'', '''', ''g'')')
      [void]$out.AppendLine('         <> regexp_replace(lower(v_want), ''\s+'', '''', ''g'')')
      [void]$out.AppendLine('  then')
      [void]$out.AppendLine('    drop function if exists ' + $regProc + ';')
      [void]$out.AppendLine('  end if;')
      [void]$out.AppendLine('end;')
      [void]$out.AppendLine('$$;')
      [void]$out.AppendLine('')
      $inserted++
    } else {
      $skipped++
    }
  }

  [void]$out.AppendLine($line)
}

[System.IO.File]::WriteAllText($target, $out.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Output ("guards removed  : " + $stripped + " (from a previous run)")
Write-Output ("guards inserted : " + $inserted)
Write-Output ("already guarded : " + $skipped)
Write-Output ("headers unread  : " + $unparsed)
Write-Output ("lines           : " + $out.ToString().Split("`n").Length)

if ($unparsed -gt 0) {
  Write-Warning "$unparsed definition(s) could not be parsed and were left un-guarded."
}
