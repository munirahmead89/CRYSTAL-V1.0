# ===================================================================
# Crystal Messenger - Start the real-time server (Windows)
#
# Checks that Erlang is installed, builds the server the first time,
# then runs it. Safe to run repeatedly.
# ===================================================================

$ErrorActionPreference = "Stop"

function Need-Command($cmd, $hint) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "  '$cmd' was not found on this computer." -ForegroundColor Red
        Write-Host "  Install it once, then run this script again:" -ForegroundColor Yellow
        Write-Host "    $hint" -ForegroundColor Cyan
        exit 1
    }
}

Need-Command "erl"     "Install Erlang/OTP from https://www.erlang.org/downloads (or: winget install Erlang.ErlangOTP)"
Need-Command "escript" "Reinstall Erlang/OTP (the installer includes escript)."

Write-Host ""
Write-Host "== Crystal Messenger server ==" -ForegroundColor Green

Push-Location $PSScriptRoot

try {
    # Fetch rebar3 (build tool) automatically if missing.
    if (-not (Get-Command rebar3 -ErrorAction SilentlyContinue)) {
        if (-not (Test-Path ".\rebar3")) {
            Write-Host "Downloading rebar3 build tool..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri "https://s3.amazonaws.com/rebar3/rebar3" -OutFile ".\rebar3"
        }
        # Compile via escript wrapper
        Write-Host "Compiling server (first run downloads libraries)..." -ForegroundColor Yellow
        escript .\rebar3 compile
        if ($LASTEXITCODE -ne 0) { throw "Build failed." }

        Write-Host ""
        Write-Host "Starting server on port 8081 (Ctrl+C to stop)..." -ForegroundColor Green
        Write-Host ""
        erl -pa _build/default/lib/*/ebin -eval "application:ensure_all_started(crystal_server)" -noshell
    }
    else {
        Write-Host "Compiling server..." -ForegroundColor Yellow
        rebar3 compile
        if ($LASTEXITCODE -ne 0) { throw "Build failed." }

        Write-Host ""
        Write-Host "Starting server on port 8081 (Ctrl+C to stop)..." -ForegroundColor Green
        Write-Host ""
        rebar3 shell
    }
}
finally {
    Pop-Location
}
