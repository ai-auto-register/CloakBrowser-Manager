<#
.SYNOPSIS
    One-click startup script for CloakBrowser Manager (local dev).

.DESCRIPTION
    - Reads configuration from .env (if present)
    - Uses `uv` to sync dependencies and run the backend
    - Ensures the frontend is installed (and built if missing)
    - Starts uvicorn (backend + built frontend) on the configured host/port

.REQUIRES
    uv  (https://docs.astral.sh/uv/)  — installed automatically via pip if missing
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$Root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$Backend  = Join-Path $Root "backend"
$Frontend = Join-Path $Root "frontend"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "    ERR $msg" -ForegroundColor Red }

# --- Ensure uv is available ------------------------------------------------
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Step "Installing uv"
    python -m pip install --quiet uv
    if ($LASTEXITCODE -ne 0) { Write-Err "pip install uv failed"; exit 1 }
    Write-Ok "uv installed"
}

# --- Load .env -------------------------------------------------------------
$EnvFile = Join-Path $Root ".env"
if (Test-Path $EnvFile) {
    Write-Step "Loading .env"
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $idx = $line.IndexOf("=")
            $k = $line.Substring(0, $idx).Trim()
            $v = $line.Substring($idx + 1).Trim()
            # Strip surrounding quotes
            if ($v -match '^".*"$') { $v = $v.Substring(1, $v.Length - 2) }
            elseif ($v -match "^'.*'$") { $v = $v.Substring(1, $v.Length - 2) }
            Set-Item -Path "Env:$k" -Value $v
        }
    }
    Write-Ok ".env loaded"
} else {
    Write-Host "    (.env not found, using defaults / existing env)" -ForegroundColor DarkGray
}

# Apply defaults for HOST / PORT if not set
if (-not $env:HOST) { $env:HOST = "127.0.0.1" }
if (-not $env:PORT) { $env:PORT = "8080" }
if (-not $env:DATA_DIR) { $env:DATA_DIR = Join-Path $Root "data" }

# Ensure DATA_DIR exists
New-Item -ItemType Directory -Force -Path $env:DATA_DIR | Out-Null

# --- Sync Python dependencies ----------------------------------------------
Write-Step "Syncing Python dependencies (uv sync)"
uv sync --quiet --project "$ROOT"
if ($LASTEXITCODE -ne 0) { Write-Err "uv sync failed"; exit 1 }
Write-Ok "dependencies synced"

# --- Frontend -------------------------------------------------------------
Write-Step "Checking frontend build"
$DistDir = Join-Path $Frontend "dist"
if (-not (Test-Path (Join-Path $DistDir "index.html"))) {
    Write-Host "    Building frontend (first run)..."
    if (-not (Test-Path (Join-Path $Frontend "node_modules"))) {
        npm --prefix "$Frontend" install
        if ($LASTEXITCODE -ne 0) { Write-Err "npm install failed"; exit 1 }
    }
    npm --prefix "$Frontend" run build
    if ($LASTEXITCODE -ne 0) { Write-Err "npm run build failed"; exit 1 }
    Write-Ok "frontend built"
} else {
    Write-Ok "frontend build exists, skipping"
}

# --- Start backend --------------------------------------------------------
Write-Step "Starting CloakBrowser Manager"
Write-Host "    DATA_DIR : $env:DATA_DIR"
Write-Host "    AUTH      : $(if ($env:AUTH_TOKEN) { 'enabled' } else { 'disabled' })"
Write-Host "    URL       : http://$($env:HOST):$($env:PORT)" -ForegroundColor Yellow
Write-Host ""

uv run --project "$ROOT" --directory "$ROOT" uvicorn backend.main:app --host $env:HOST --port $env:PORT
