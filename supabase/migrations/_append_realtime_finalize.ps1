# Wires the realtime publication safety net into 00021_full_schema.sql.
#
# Two halves, both required:
#
#   PART 1 (_realtime_prelude.sql)   inserted at the TOP, before any table
#                                    exists. Replaces the unsafe
#                                    `enable_realtime()` that did
#                                    `ALTER PUBLICATION ... DROP TABLE` with
#                                    no exception handler: on a fresh database
#                                    that DROP raises and aborts the whole
#                                    script, so a correct block appended at the
#                                    bottom would never be reached.
#
#   PART 2 (_realtime_finalize.sql)  appended at the BOTTOM. Derives the
#                                    complete publication membership from
#                                    pg_publication_tables and re-asserts the
#                                    presence broadcast policies.
#
# IDEMPOTENT: any previous copy of either half is removed before re-inserting,
# so this can be run repeatedly to correct a bad result.
#
#   powershell -ExecutionPolicy Bypass -File supabase/migrations/_append_realtime_finalize.ps1

$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $dir '00021_full_schema.sql'
$preludePath = Join-Path $dir '_realtime_prelude.sql'
$finalPath = Join-Path $dir '_realtime_finalize.sql'

foreach ($p in @($target, $preludePath, $finalPath)) {
  if (-not (Test-Path $p)) { throw "missing $p" }
}

$raw = [System.IO.File]::ReadAllText($target, [System.Text.Encoding]::UTF8)
$prelude = [System.IO.File]::ReadAllText($preludePath, [System.Text.Encoding]::UTF8).Trim()
$final = [System.IO.File]::ReadAllText($finalPath, [System.Text.Encoding]::UTF8).Trim()

# --- Remove previous copies, so this is safe to re-run ------------------------

# Part 2 runs from its marker to the end of the file.
$finalMarker = 'Realtime publication ' + [char]0x2014 + ' PART 2 of 2'
$idx = $raw.IndexOf($finalMarker)
if ($idx -ge 0) {
  Write-Output 'removing previous PART 2'
  $raw = $raw.Substring(0, $idx).TrimEnd() + "`r`n"
}

# Part 1 runs from its marker to the end of the schema header block. It was
# inserted directly after the generated header, so find the first migration
# banner that follows it and cut from the marker up to that point.
$preludeMarker = 'Realtime publication ' + [char]0x2014 + ' PART 1 of 2'
$idx = $raw.IndexOf($preludeMarker)
if ($idx -ge 0) {
  Write-Output 'removing previous PART 1'
  # Everything from the marker up to the first `-- 000` section banner.
  $nextBanner = $raw.IndexOf("`r`n-- 000", $idx)
  if ($nextBanner -lt 0) { $nextBanner = $raw.IndexOf("`n-- 000", $idx) }
  if ($nextBanner -lt 0) { throw 'PART 1 removal: could not find the following migration banner' }
  $raw = $raw.Substring(0, $idx).TrimEnd() + "`r`n" + $raw.Substring($nextBanner).TrimStart("`r", "`n")
}

# --- Insert PART 1 directly after the generated header ------------------------
# It must precede the first migration, otherwise the unsafe helper is created
# and called before it is replaced.
$firstBanner = $raw.IndexOf('-- 000')
if ($firstBanner -lt 0) { throw 'no migration banner found; is this the generated file?' }

$before = $raw.Substring(0, $firstBanner).TrimEnd()
$after = $raw.Substring($firstBanner)
$raw = $before + "`r`n`r`n" + $prelude + "`r`n`r`n" + $after

# --- Append PART 2 at the very end ---------------------------------------------
$raw = $raw.TrimEnd() + "`r`n`r`n" + $final + "`r`n"

[System.IO.File]::WriteAllText($target, $raw, (New-Object System.Text.UTF8Encoding($false)))

# --- Verification ---------------------------------------------------------------
$dq = ([regex]::Matches($raw, '\$\$')).Count
$p1 = ([regex]::Matches($raw, 'PART 1 of 2')).Count
$p2 = ([regex]::Matches($raw, 'PART 2 of 2')).Count
$guard = ([regex]::Matches($raw, 'when duplicate_object then null;\s*\r?\n\s*when undefined_table then null;\s*\r?\n\s*when undefined_object then null;')).Count

Write-Output ("PART 1 present   : $p1 (must be 1)")
Write-Output ("PART 2 present   : $p2 (must be 1)")
Write-Output ("safe add-only fn : $guard (must be >= 1)")
Write-Output ("dollar quotes    : $dq (balanced: " + ($dq % 2 -eq 0) + ")")
Write-Output ("lines            : " + ($raw -split "`r?`n").Length)
Write-Output ("size             : " + [math]::Round((Get-Item $target).Length / 1KB, 1) + " KB")

if ($dq % 2 -ne 0) { throw 'unbalanced dollar quotes' }
if ($p1 -ne 1) { throw "PART 1 count is $p1, expected 1" }
if ($p2 -ne 1) { throw "PART 2 count is $p2, expected 1" }
if ($guard -lt 1) { throw 'the add-only enable_realtime replacement is missing' }

# PART 1 must come before every `select public.enable_realtime();` call.
$p1Pos = $raw.IndexOf('PART 1 of 2')
$firstCall = $raw.IndexOf('select public.enable_realtime();')
if ($p1Pos -lt 0 -or $firstCall -lt 0) { throw 'could not locate PART 1 or the first enable_realtime() call' }
if ($p1Pos -gt $firstCall) {
  throw 'PART 1 is placed AFTER the first enable_realtime() call - the unsafe helper would run first'
}
Write-Output 'ordering         : PART 1 precedes every enable_realtime() call'
