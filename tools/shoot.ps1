# Drives the app on a connected device/emulator and captures screenshots.
#
#   powershell -File tools\shoot.ps1 -Steps "tap:540,1400|capture:welcome|wait:3"
#
# Step verbs:
#   tap:X,Y          send a single tap at device pixel coordinates
#   swipe:X1,Y1,X2,Y2[,MS]
#   text:hello       type into the focused field
#   key:CODE         e.g. key:KEYCODE_BACK
#   wait:SECONDS     sleep
#   capture:NAME     write NAME.png into the output folder (full resolution)
#   preview:NAME     also write a scaled NAME.preview.png for quick inspection
#
# Coordinates are device pixels. The Pixel-class emulator used for store shots
# is 1080x2424, so a point at (x,y) in a 400px-wide preview is (x*2.7, y*2.7).
param(
    [string]$Steps = "",
    [string]$OutDir = "$env:USERPROFILE\Desktop\crystal_screenshots",
    [int]$PreviewWidth = 420
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path

function Capture([string]$name) {
    $dest = Join-Path $OutDir "$name.png"
    & powershell -ExecutionPolicy Bypass -File (Join-Path $here "capture_screenshot.ps1") -Out $dest | Out-Null
    # A throw inside the child powershell does NOT propagate here, so the exit
    # code has to be checked explicitly. Without this, a dead emulator reports
    # "captured <name>" and silently produces nothing.
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $dest)) {
        throw "capture of '$name' failed (exit $LASTEXITCODE)"
    }
    $preview = Join-Path $OutDir "$name.preview.png"
    & powershell -ExecutionPolicy Bypass -File (Join-Path $here "resize_png.ps1") -In $dest -Out $preview -Max $PreviewWidth | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $preview)) { throw "preview of '$name' failed" }
    Write-Host "captured $name"
}

foreach ($step in ($Steps -split '\|')) {
    if ([string]::IsNullOrWhiteSpace($step)) { continue }
    $verb, $arg = $step -split ':', 2
    switch ($verb) {
        'tap'    {
            # `input touchscreen tap`, not plain `input tap`: on this emulator the
            # plain form is accepted and exits 0 but Flutter never sees the
            # event, so taps silently do nothing.
            $p = $arg -split ','
            & $adb shell input touchscreen tap $p[0] $p[1]
        }
        'swipe'  {
            $p = $arg -split ','
            if ($p.Count -ge 5) { & $adb shell input touchscreen swipe $p[0] $p[1] $p[2] $p[3] $p[4] }
            else { & $adb shell input touchscreen swipe $p[0] $p[1] $p[2] $p[3] }
        }
        'text'   { & $adb shell input text $arg }
        'key'    { & $adb shell input keyevent $arg }
        'wait'   { Start-Sleep -Seconds ([double]$arg) }
        'capture' { Capture $arg }
        'preview' {
            $dest = Join-Path $OutDir "$arg.png"
            $preview = Join-Path $OutDir "$arg.preview.png"
            & powershell -ExecutionPolicy Bypass -File (Join-Path $here "resize_png.ps1") -In $dest -Out $preview -Max $PreviewWidth | Out-Null
            Write-Host "preview $arg"
        }
        default { throw "unknown step verb '$verb'" }
    }
    # A short settle after every action avoids capturing mid-transition.
    Start-Sleep -Milliseconds 700
}