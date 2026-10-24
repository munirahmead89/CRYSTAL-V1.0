# Builds a Windows release (as a deployable folder + optional MSIX) injecting
# Supabase credentials from secrets.env. Run from project root:
#   powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path "secrets.env")) {
    Write-Error "secrets.env not found. Copy secrets.env.example to secrets.env and fill in your Supabase URL + anon key."
}

& "C:\flutterSDK\flutter\bin\flutter.bat" config --enable-windows-desktop
& "C:\flutterSDK\flutter\bin\flutter.bat" pub get
& "C:\flutterSDK\flutter\bin\flutter.bat" build windows --release --dart-define-from-file=secrets.env

Get-ChildItem "build\windows\x64\runner\Release" -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.PSIsContainer -or $_.Extension -eq ".exe") {
        Write-Host ("Release artifact: {0}" -f $_.FullName)
    }
}
