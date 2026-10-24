# Builds a signed, store-ready release APK.
#
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File tools/build_release.ps1
#   powershell -ExecutionPolicy Bypass -File tools/build_release.ps1 -Abi arm64
#
# Outputs (build\app\outputs\flutter-apk\):
#   app-release.apk    one APK carrying arm64-v8a (+ armeabi-v7a by default)
#
# The x86/x86_64 slices are excluded on purpose: they are ~23 MB of native code
# that no phone can load, and including them pushes the download up for everyone.
param(
    # Device ABIs to include. Default is the two phone architectures. Pass
    # "arm64" for an arm64-only build (see the Application Control note below).
    [ValidateSet('all', 'arm64')]
    [string]$Abi = 'all'
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# --- required inputs -------------------------------------------------------

if (-not (Test-Path "secrets.env")) {
    Write-Error "secrets.env not found. Copy secrets.env.example to secrets.env and fill in your Supabase URL + anon key."
}

if (-not (Test-Path "android/key.properties")) {
    # The Gradle build aborts a release task without this, so fail here first
    # with a message that says what to do about it.
    Write-Error @"
android/key.properties not found.

A release build cannot be signed without it, and the Gradle build will now stop
rather than fall back to the Android debug key: an APK signed by the public
debug key installs but can never be updated, which would permanently block every
future release of this package name.

Create one, or regenerate the key:
  keytool -genkey -v -keystore android\play-upload.jks -keyalg RSA -keysize 4096 -validity 10000 -alias upload

Then copy tools/key.properties.example to android\key.properties and fill it in.
Back the keystore up outside this repository: losing it is unrecoverable.
"@
}

# --- locate the Flutter SDK ------------------------------------------------
# Read from local.properties rather than hardcoding a path, so the script works
# on any machine that has done `flutter doctor` at least once.

$localProps = Join-Path $root "local.properties"
if (-not (Test-Path $localProps)) {
    Write-Error "local.properties not found. Run `flutter doctor` once, or create it with sdk.dir and flutter.sdk."
}

$props = @{}
Get-Content $localProps | ForEach-Object {
    if ($_ -match '^\s*([^=]+?)\s*=\s*(.*)$') {
        # local.properties is Java properties, so a Windows path arrives escaped:
        #   sdk.dir=C\:\Users\me\AppData\Local\Android\Sdk
        # Undo both escapes or every path lookup fails on a bogus "C\" drive.
        $value = $matches[2].Trim() -replace '\\\\', '\' -replace '\\:', ':'
        $props[$matches[1]] = $value
    }
}
$flutterBat = Join-Path $props["flutter.sdk"] "bin\flutter.bat"
if (-not (Test-Path $flutterBat)) {
    Write-Error "flutter.sdk in local.properties does not resolve to a Flutter install: $flutterBat"
}

# Keeps Gradle from picking up a real user profile's Android prefs, which can
# carry a conflicting SDK path.
$env:ANDROID_PREFS_ROOT = $null

# --- build -----------------------------------------------------------------

& $flutterBat pub get
if ($LASTEXITCODE -ne 0) { Write-Error "pub get failed" }

# --target-platform is what this project's build translates into per-ABI
# filtering; see the ABI handling in android/app/build.gradle.kts. It is
# deliberately NOT --split-per-abi: that sets `splits.abi`, which conflicts with
# the ndk.abiFilters this build configures, and Gradle refuses to configure.
# Result is one APK holding the requested phone ABIs, which is also what APKPure
# wants for a single download.
$targetPlatform = if ($Abi -eq 'arm64') { 'android-arm64' } else { 'android-arm,android-arm64' }

& $flutterBat build apk `
    --release `
    --target-platform $targetPlatform `
    --dart-define-from-file=secrets.env
if ($LASTEXITCODE -ne 0) { Write-Error "Gradle build failed (see output above)" }

# --- report ----------------------------------------------------------------

$outDir = Join-Path $root "build\app\outputs\flutter-apk"
Get-ChildItem $outDir -Filter "*.apk" -ErrorAction SilentlyContinue |
    Sort-Object Name |
    ForEach-Object {
        Write-Host ("  {0,-32} {1,6:N1} MB" -f $_.Name, ($_.Length / 1MB))
    }

# A store upload whose versionCode is not higher than what is already published
# is rejected, so make the value impossible to miss.
$version = (Select-String -Path (Join-Path $root "pubspec.yaml") -Pattern '^version:\s*(\S+)' |
    Select-Object -First 1).Matches[0].Groups[1].Value
Write-Host ""
Write-Host "Built from pubspec version $version"
Write-Host "ABIs: $targetPlatform"
Write-Host "Before uploading, confirm the build number is higher than any version already live."