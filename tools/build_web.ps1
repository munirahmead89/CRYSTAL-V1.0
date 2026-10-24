# Builds the Web release (deploy to Supabase Hosting / Vercel / APKPure web)
# injecting Supabase credentials from secrets.env. Run from project root:
#   powershell -ExecutionPolicy Bypass -File tools/build_web.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path "secrets.env")) {
    Write-Error "secrets.env not found. Copy secrets.env.example to secrets.env and fill in your Supabase URL + anon key."
}

# NOTE: only the SUPABASE_URL + SUPABASE_ANON_KEY (PUBLISHABLE) credentials are
# safe for web; they are public by design. NEVER expose the service_role key.
& "C:\flutterSDK\flutter\bin\flutter.bat" config --enable-web
& "C:\flutterSDK\flutter\bin\flutter.bat" pub get
& "C:\flutterSDK\flutter\bin\flutter.bat" build web --release --dart-define-from-file=secrets.env

Get-ChildItem "build\web" -ErrorAction SilentlyContinue | Select-Object -First 6 | ForEach-Object {
    Write-Host ("Web artifact: {0}" -f $_.FullName)
}
