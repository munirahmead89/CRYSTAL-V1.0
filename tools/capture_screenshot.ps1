# Captures a screenshot from a connected Android device/emulator via adb.
#
#   powershell -File tools\capture_screenshot.ps1 -Out shot.png
#
# The file is written on the device first and then pulled, rather than piping
# `adb exec-out` into a PowerShell redirect: `>` mangles binary data, so the
# direct pipe produces a file that is not a valid image.
param(
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Serial = "",
    [string]$RemotePath = ""
)

$ErrorActionPreference = "Stop"

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { throw "adb not found at $adb" }

$args = @()
if ($Serial) { $args += @("-s", $Serial) }

if (-not $RemotePath) {
    $RemotePath = "/sdcard/_crystal_shot_$([guid]::NewGuid().ToString('N').Substring(0,8)).png"
}

$outDir = Split-Path -Parent $Out
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

# Clean up any stale file first: a leftover at the same path would be pulled
# instead of the new screenshot.
& $adb @args shell rm -f $RemotePath | Out-Null
& $adb @args shell screencap -p $RemotePath
if ($LASTEXITCODE -ne 0) { throw "screencap failed (exit $LASTEXITCODE)" }

# Poll until the file exists and stops growing, otherwise `adb pull` can race the
# write and produce a truncated PNG.
for ($i = 0; $i -lt 20; $i++) {
    $size = & $adb @args shell "stat -c %s $RemotePath 2>/dev/null"
    if ($size -and [int64]$size -gt 0) {
        $size2 = & $adb @args shell "stat -c %s $RemotePath 2>/dev/null"
        if ($size -eq $size2) { break }
    }
    Start-Sleep -Milliseconds 250
}

& $adb @args pull $RemotePath $Out | Out-Null
& $adb @args shell rm -f $RemotePath | Out-Null

$len = (Get-Item -LiteralPath $Out).Length
if ($len -lt 1024) { throw "captured file is only $len bytes - screencap likely failed" }

# Verify it really is a PNG and not a text/error payload.
$fs = [System.IO.File]::OpenRead($Out)
try {
    $hdr = New-Object byte[] 8
    [void]$fs.Read($hdr, 0, 8)
} finally { $fs.Dispose() }
$sig = ($hdr | ForEach-Object { $_.ToString("X2") }) -join ""
if ($sig -ne "89504E470D0A1A0A") { throw "not a PNG (header $sig)" }

Write-Host ("captured {0:N0} bytes -> {1}" -f $len, $Out)