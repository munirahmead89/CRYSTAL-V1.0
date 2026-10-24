# Builds an iOS archive (ipa) injecting Supabase credentials from secrets.env
# (gitignored; the only secret source). Run from project root:
#   powershell -ExecutionPolicy Bypass -File tools/build_ios.ps1
#
# Prereqs: Xcode + CocoaPods installed on a Mac; run `flutter config
# --enable-macos-desktop` if targeting macOS too.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path "secrets.env")) {
    Write-Error "secrets.env not found. Copy secrets.env.example to secrets.env and fill in your Supabase URL + anon key."
}

# iOS credentials come through --dart-define-from-file exactly like Android, so
# the SAME secrets.env drives every platform with zero per-platform duplication.
& "C:\flutterSDK\flutter\bin\flutter.bat" pub get
& "C:\flutterSDK\flutter\bin\flutter.bat" build ipa --release --dart-define-from-file=secrets.env

Get-ChildItem "build\ios\archive\*.xcarchive" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host ("Archive ready: {0}" -f $_.FullName)
}
