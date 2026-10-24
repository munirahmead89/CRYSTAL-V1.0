# Builds a macOS app bundle injecting Supabase credentials from secrets.env.
# Run from project root:
#   powershell -ExecutionPolicy Bypass -File tools/build_macos.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path "secrets.env")) {
    Write-Error "secrets.env not found. Copy secrets.env.example to secrets.env and fill in your Supabase URL + anon key."
}

& "C:\flutterSDK\flutter\bin\flutter.bat" config --enable-macos-desktop
& "C:\flutterSDK\flutter\bin\flutter.bat" pub get
& "C:\flutterSDK\flutter\bin\flutter.bat" build macos --release --dart-define-from-file=secrets.env

Get-ChildItem "build\macos\*\*.app" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host ("App bundle ready: {0}" -f $_.FullName)
}
