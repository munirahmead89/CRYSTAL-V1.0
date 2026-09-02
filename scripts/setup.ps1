# ===================================================================
# Crystal Messenger - One-Command Setup (Windows PowerShell)
#
# Usage:
#   .\scripts\setup.ps1
#
# What it does:
#   1. Copies .env.example -> .env (if not exists)
#   2. Copies server/.env.server.example -> server/.env.server (if not exists)
#   3. Installs Flutter dependencies
#   4. Builds the Docker image for the Erlang server
# ===================================================================

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host ""
Write-Host "  Crystal Messenger Setup" -ForegroundColor Cyan
Write-Host "  ========================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Environment files ---
Write-Host "[1/4] Setting up environment files..." -ForegroundColor Yellow

$envFile = Join-Path $Root ".env"
$envExample = Join-Path $Root ".env.example"
if (!(Test-Path $envFile)) {
    if (Test-Path $envExample) {
        Copy-Item $envExample $envFile
        Write-Host "  Created .env from .env.example" -ForegroundColor Green
        Write-Host "  >> Edit .env with your Supabase credentials before running the app" -ForegroundColor DarkYellow
    } else {
        Write-Host "  .env.example not found, skipping" -ForegroundColor Red
    }
} else {
    Write-Host "  .env already exists, skipping" -ForegroundColor DarkGray
}

$serverEnvFile = Join-Path $Root "server\.env.server"
$serverEnvExample = Join-Path $Root "server\.env.server.example"
if (!(Test-Path $serverEnvFile)) {
    if (Test-Path $serverEnvExample) {
        Copy-Item $serverEnvExample $serverEnvFile
        Write-Host "  Created server/.env.server from .env.server.example" -ForegroundColor Green
        Write-Host "  >> Edit server/.env.server with your SUPABASE_JWT_SECRET" -ForegroundColor DarkYellow
    } else {
        Write-Host "  server/.env.server.example not found, skipping" -ForegroundColor Red
    }
} else {
    Write-Host "  server/.env.server already exists, skipping" -ForegroundColor DarkGray
}

# --- 2. Flutter dependencies ---
Write-Host ""
Write-Host "[2/4] Installing Flutter dependencies..." -ForegroundColor Yellow

$flutterDir = Join-Path $Root "crystal_messenger"
if (Test-Path (Join-Path $flutterDir "pubspec.yaml")) {
    Push-Location $flutterDir
    try {
        flutter pub get
        Write-Host "  Flutter dependencies installed" -ForegroundColor Green
    } catch {
        Write-Host "  flutter pub get failed (is Flutter installed?)" -ForegroundColor Red
    }
    Pop-Location
} else {
    Write-Host "  crystal_messenger/pubspec.yaml not found, skipping" -ForegroundColor Red
}

# --- 3. Docker image ---
Write-Host ""
Write-Host "[3/4] Building server Docker image..." -ForegroundColor Yellow

$serverDir = Join-Path $Root "server"
$dockerfile = Join-Path $serverDir "Dockerfile"
if (Test-Path $dockerfile) {
    try {
        docker build -t crystal-server:latest $serverDir
        Write-Host "  Docker image built: crystal-server:latest" -ForegroundColor Green
    } catch {
        Write-Host "  Docker build failed (is Docker running?)" -ForegroundColor Red
    }
} else {
    Write-Host "  server/Dockerfile not found, skipping" -ForegroundColor Red
}

# --- 4. Summary ---
Write-Host ""
Write-Host "[4/4] Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Edit .env with your Supabase URL and anon key"
Write-Host "  2. Edit server/.env.server with your Supabase JWT secret"
Write-Host "  3. Start the server:  docker compose up -d"
Write-Host "  4. Run the Flutter app:"
Write-Host "     cd crystal_messenger"
Write-Host "     flutter run" -ForegroundColor White
Write-Host ""
