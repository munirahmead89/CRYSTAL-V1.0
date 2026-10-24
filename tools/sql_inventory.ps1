# Inventories every object defined across the SQL in this repository.
#
#   powershell -ExecutionPolicy Bypass -File tools\sql_inventory.ps1
#
# Answers the two questions that decide whether the files can simply be
# concatenated: which objects are defined more than once, and which of those
# duplicates are CREATE (would fail on re-run) versus CREATE OR REPLACE (safe).
param(
    [string]$Root = "supabase"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

$files = @()
$files += Get-ChildItem -Recurse -Filter "*.sql" -Path $Root -ErrorAction SilentlyContinue
$files += Get-ChildItem -Filter "APPLY_*.sql" -ErrorAction SilentlyContinue

$pattern = '^\s*create\s+(or\s+replace\s+)?(function|table|index|policy|trigger|type|publication)\s+([\w\.\[\]"]+)'

$defs = @{}
foreach ($f in $files) {
    $lines = Get-Content -LiteralPath $f.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) {
            $replace = $Matches[1] -ne $null
            $kind = $Matches[2]
            $name = $Matches[3] -replace '"', ''
            $key = "$kind $name"
            if (-not $defs.ContainsKey($key)) {
                $defs[$key] = New-Object System.Collections.ArrayList
            }
            [void]$defs[$key].Add([pscustomobject]@{
                    File = $f.Name
                    Line = $i + 1
                    Replace = $replace
                })
        }
    }
}

Write-Host "Scanned $($files.Count) file(s). Distinct objects: $($defs.Count)`n"

$unsafe = @()
foreach ($entry in $defs.GetEnumerator()) {
    # A plain `create x` appearing anywhere is a re-run hazard: it aborts the
    # whole transaction on a second apply, exactly like the malformed function
    # declarations found earlier.
    $plain = @($entry.Value | Where-Object { -not $_.Replace })
    if ($plain.Count -gt 0) {
        $unsafe += [pscustomobject]@{
            Object = $entry.Key
            PlainCreates = ($plain | ForEach-Object { "$($_.File):$($_.Line)" }) -join ", "
            Total = $entry.Value.Count
        }
    }
}

Write-Host "=== Objects with at least one plain CREATE (not idempotent) ==="
if ($unsafe.Count -eq 0) {
    Write-Host "  (none - every definition is CREATE OR REPLACE / IF NOT EXISTS)"
} else {
    $unsafe | Sort-Object Object | ForEach-Object {
        Write-Host ("  {0,-52} x{1}  plain: {2}" -f $_.Object, $_.Total, $_.PlainCreates)
    }
}

Write-Host "`n=== Objects defined in more than one FILE (merge order matters) ==="
$multi = @()
foreach ($entry in $defs.GetEnumerator()) {
    $distinctFiles = @($entry.Value | Select-Object -ExpandProperty File -Unique)
    if ($distinctFiles.Count -gt 1) {
        $multi += [pscustomobject]@{
            Object = $entry.Key
            Files = ($distinctFiles -join ", ")
            Count = $entry.Value.Count
        }
    }
}
if ($multi.Count -eq 0) {
    Write-Host "  (none)"
} else {
    $multi | Sort-Object Object | ForEach-Object {
        Write-Host ("  {0,-48} x{1}  <- {2}" -f $_.Object, $_.Count, $_.Files)
    }
}

Write-Host "`n=== Unguarded policy/trigger drops needed before re-creating ==="
$dropped = 0
foreach ($f in $files) {
    $dropped += @(Select-String -Path $f.FullName -Pattern '^\s*drop policy if exists|^\s*drop trigger if exists' -ErrorAction SilentlyContinue).Count
}
Write-Host "  $dropped `drop ... if exists` statements present (these are what make policy creation re-runnable)"