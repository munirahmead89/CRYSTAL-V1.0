# Rewrites every `enable_realtime*` helper IN PLACE in 00021_full_schema.sql so
# it is add-only and exception-guarded.
#
# THE PROBLEM
#
# Two helpers (from 00001 and 00003) do:
#
#     alter publication supabase_realtime drop table ...;
#     alter publication supabase_realtime add table ...;
#
# with NO exception handler. DROP on a table that is not currently a publication
# member is an error. On a fresh database the tables were only just created, so
# they are not members, so the DROP raises and — with no handler — the whole
# script aborts partway through, leaving a half-built schema and no realtime.
#
# Defining a corrected version elsewhere does not help: 00001 later does
# `create or replace`, overwriting the good body with the unsafe one. The
# definition has to be corrected where it is.
#
# WHY WHOLE-TEXT REGEX, NOT A LINE LOOP
#
# A line-based pass has to find the body boundaries by scanning for a line that
# is exactly `$$;`. That mis-tracks on the very first definition in the file
# and silently deletes delimiters — which is exactly what happened the first
# time this was attempted, losing 14 `$$` markers. Matching the complete
# definition in one regex (`create or replace ... ^$$;`) is atomic: either the
# whole definition is replaced or none of it is.
#
# IDEMPOTENT: a helper that already lacks a `drop table` and already has an
# exception handler is returned unchanged, so re-running is a no-op.
#
#   powershell -ExecutionPolicy Bypass -File supabase/migrations/_fix_realtime_helpers.ps1

$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $dir '00021_full_schema.sql'
if (-not (Test-Path $target)) { throw "missing $target" }

$raw = [System.IO.File]::ReadAllText($target, [System.Text.Encoding]::UTF8)
$dqBefore = ([regex]::Matches($raw, '\$\$')).Count

# One complete helper definition: signature through its closing `$$;`.
$pattern = '(?ms)^create or replace function public\.(?<name>enable_\w+)\(\).*?^\$\$;'

if (-not [regex]::IsMatch($raw, $pattern)) { throw 'no enable_realtime* definitions found' }

$script:checked = 0
$script:fixed = 0

$new = [regex]::Replace($raw, $pattern, {
  param($mt)
  $name = $mt.Groups['name'].Value
  $def = $mt.Value
  $script:checked++

  $hasDrop = $def -match '(?m)^\s*drop table'
  $hasEx = $def -match '(?m)^\s*exception\s*$'
  if (-not $hasDrop -and $hasEx) { return $def }   # already safe

  $openIdx = $def.IndexOf('$$;')
  if ($openIdx -lt 0) { return $def }
  $head = $def.Substring(0, $openIdx + 3)

  # Recover the intended table list from the original ADD statement so the
  # corrected body publishes exactly what the original meant to publish.
  $tables = @()
  if ($def -match '(?is)add table\s+(?<list>public\.[\w,\s]+?);') {
    $tables = $matches['list'] -split ',' |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -match '^public\.\w+$' } |
      Sort-Object -Unique
  }
  if ($tables.Count -eq 0) {
    $tables = @(
      'public.profiles', 'public.messages', 'public.message_receipts',
      'public.conversations', 'public.conversation_members', 'public.devices'
    )
  }

  # Wrap long lists across lines, mirroring the original formatting.
  $lines = @()
  $cur = '    add table '
  foreach ($t in $tables) {
    if (($cur + $t).Length -gt 72) {
      $lines += $cur.TrimEnd()
      $cur = '      '
    }
    $cur += $t + ', '
  }
  $lines += ($cur.TrimEnd() -replace ',$', '')
  $body = $lines -join "`r`n"

  $script:fixed++

  # A single-quoted here-string, not a double-quoted one: the comments contain
  # SQL backticks, which PowerShell would treat as escape characters in a
  # double-quoted string and silently mangle the output.
  $template = @'
begin
  -- Corrected in place. The original ran a DROP before the ADD, with no
  -- exception handler. Dropping a table that is not yet a publication member
  -- raises, which aborted the entire schema build on a fresh database.
  -- Add-only is idempotent: a table that is already a member raises
  -- duplicate_object, which is absorbed below.
  alter publication supabase_realtime
__BODY__;
exception
  when duplicate_object then null;        -- already a member
  when undefined_table then null;         -- not created by this schema
  when undefined_object then null;        -- no such publication
  when insufficient_privilege then null;  -- not the owner
end;
$$;
'@

  return $head + "`r`n" + $template.Replace('__BODY__', $body).TrimEnd() + "`r`n"
})

[System.IO.File]::WriteAllText($target, $new, (New-Object System.Text.UTF8Encoding($false)))

$dqAfter = ([regex]::Matches($new, '\$\$')).Count
Write-Output ("dollar quotes before : $dqBefore")
Write-Output ("dollar quotes after  : $dqAfter (balanced: " + ($dqAfter % 2 -eq 0) + ")")
Write-Output ("helpers checked      : $script:checked")
Write-Output ("helpers rewritten    : $script:fixed")
Write-Output ("lines                : " + ($new -split "`r?`n").Length)

if ($dqAfter % 2 -ne 0) { throw "unbalanced dollar quotes: $dqAfter" }
# Each rewritten helper has exactly two `$$` markers before and after, so the
# total must be unchanged. A drop means delimiters were lost.
if ($dqAfter -ne $dqBefore) {
  throw "dollar-quote count changed ($dqBefore -> $dqAfter): delimiters were lost"
}

# Hard verification on the result.
$bad = 0
foreach ($mt in [regex]::Matches($new, $pattern)) {
  $b = $mt.Value
  $n = $mt.Groups['name'].Value
  if ($b -match '(?m)^\s*drop table') { $bad++; Write-Output "  UNSAFE drop remains in $n" }
  if ($b -notmatch '(?m)^\s*exception\s*$') { $bad++; Write-Output "  MISSING handler in $n" }
  if ($b -notmatch '(?m)^\s*begin\s*$') { $bad++; Write-Output "  MISSING begin in $n" }
  if ($b -notmatch '(?m)^\s*end;\s*$') { $bad++; Write-Output "  MISSING end in $n" }
}
if ($bad -gt 0) { throw "$bad structural problem(s) remain" }
Write-Output 'verified: every enable_realtime* helper is add-only and exception-guarded'
