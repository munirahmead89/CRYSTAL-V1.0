# ===================================================================
# Crystal Messenger - Local APK Build Script (Windows PowerShell)
#
# Usage:
#   .\scripts\build.ps1                    # Build universal APK
#   .\scripts\build.ps1 -SplitAbi          # Build split APKs per ABI
#   .\scripts\build.ps1 -Aab               # Build AAB for Play Store
#   .\scripts\build.ps1 -Shorebird         # Build APK with Shorebird (OTA-capable)
#   .\scripts\build.ps1 -Shorebird -Aab    # Build AAB with Shorebird
#   .\scripts\build.ps1 -Clean             # Clean build first
#
# Environment:
#   Set SUPABASE_URL and SUPABASE_ANON_KEY in .env or as env vars.
# ===================================================================

param(
    [switch]$SplitAbi,
    [switch]$Aab,
    [switch]$Clean,
    [switch]$Release,
    [switch]$Shorebird
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$FlutterDir = Join-Path $Root "crystal_messenger"

Write-Host ""
Write-Host "  Crystal Messenger - Build" -ForegroundColor Cyan
Write-Host "  =========================" -ForegroundColor Cyan
Write-Host ""

# --- Load .env if exists ---
$envFile = Join-Path $Root ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^\s*([^#][^=]+)=(.+)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    Write-Host "  Loaded .env" -ForegroundColor DarkGray
}

# --- Validate env vars ---
$supabaseUrl = [Environment]::GetEnvironmentVariable("SUPABASE_URL")
$supabaseKey = [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY")

if ([string]::IsNullOrEmpty($supabaseUrl) -or [string]::IsNullOrEmpty($supabaseKey)) {
    Write-Host "  WARNING: SUPABASE_URL or SUPABASE_ANON_KEY not set" -ForegroundColor Yellow
    Write-Host "  Build will use defaults from api_constants.dart" -ForegroundColor Yellow
    $defineArgs = ""
} else {
    Write-Host "  SUPABASE_URL: $supabaseUrl" -ForegroundColor DarkGray
    $defineArgs = "--dart-define=SUPABASE_URL=$supabaseUrl --dart-define=SUPABASE_ANON_KEY=$supabaseKey"
}

Write-Host ""

# --- Clean ---
if ($Clean) {
    Write-Host "[1/3] Cleaning build..." -ForegroundColor Yellow
    Push-Location $FlutterDir
    flutter clean
    Pop-Location
    Write-Host "  Clean complete" -ForegroundColor Green
}

# --- Dependencies ---
Write-Host "[2/3] Installing dependencies..." -ForegroundColor Yellow
Push-Location $FlutterDir
flutter pub get
Pop-Location
Write-Host "  Dependencies installed" -ForegroundColor Green

# --- Code generation ---
Write-Host "  Running code generation..." -ForegroundColor Yellow
Push-Location $FlutterDir
dart run build_runner build --delete-conflicting-outputs
Pop-Location
Write-Host "  Code generation complete" -ForegroundColor Green

# --- Build ---
Write-Host "[3/3] Building..." -ForegroundColor Yellow
Push-Location $FlutterDir

$buildMode = if ($Release) { "--release" } else { "--release" }

if ($Shorebird) {
    # Shorebird builds: replace flutter build with shorebird release
    $shorebirdArgs = @("release", "android")
    if ($Aab) {
        # Default is AAB, no flag needed
    } else {
        $shorebirdArgs += "--artifact", "apk"
    }
    if (-not [string]::IsNullOrEmpty($defineArgs)) {
        # Shorebird doesn't support --dart-define directly; env vars must be set before build
        Write-Host "  NOTE: Set SUPABASE_URL and SUPABASE_ANON_KEY as env vars before running" -ForegroundColor Yellow
    }
    Write-Host "  Building with Shorebird (OTA-capable)..." -ForegroundColor Yellow
    Write-Host "  Command: shorebird $($shorebirdArgs -join ' ')" -ForegroundColor DarkGray
    Invoke-Expression "shorebird $($shorebirdArgs -join ' ')"
} elseif ($Aab) {
    Write-Host "  Building AAB (Play Store)..." -ForegroundColor Yellow
    Invoke-Expression "flutter build appbundle $buildMode $defineArgs"
} elseif ($SplitAbi) {
    Write-Host "  Building split APKs (per ABI)..." -ForegroundColor Yellow
    Invoke-Expression "flutter build apk $buildMode --split-per-abi $defineArgs"
} else {
    Write-Host "  Building universal APK..." -ForegroundColor Yellow
    Invoke-Expression "flutter build apk $buildMode $defineArgs"
}

Pop-Location

# --- Output ---
Write-Host ""
Write-Host "Build complete!" -ForegroundColor Green
Write-Host ""

if ($Shorebird) {
    Write-Host "Shorebird release created. To push a patch later:" -ForegroundColor Cyan
    Write-Host "  shorebird patch android" -ForegroundColor Cyan
    Write-Host ""
    $shorebirdDir = Join-Path $FlutterDir ".shorebird"
    if (Test-Path $shorebirdDir) {
        Write-Host "Shorebird config: $shorebirdDir" -ForegroundColor DarkGray
    }
} elseif ($Aab) {
    $aabPath = Join-Path $FlutterDir "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $aabPath) {
        Write-Host "AAB: $aabPath" -ForegroundColor Cyan
    }
} else {
    $apkDir = Join-Path $FlutterDir "build\app\outputs\flutter-apk"
    if (Test-Path $apkDir) {
        Get-ChildItem $apkDir -Filter "*.apk" | ForEach-Object {
            Write-Host "APK: $($_.FullName)" -ForegroundColor Cyan
        }
    }
}

Write-Host ""
