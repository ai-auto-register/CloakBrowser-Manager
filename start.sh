#!/usr/bin/env bash
# One-click startup for CloakBrowser Manager (Linux / macOS / WSL)
#
# - Reads configuration from .env (if present)
# - Uses `uv` to sync dependencies and run the backend
# - Ensures the frontend is installed (and built if missing)
# - Starts uvicorn (backend + built frontend) on the configured host/port
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32mOK  %s\033[0m\n' "$1"; }
err()  { printf '    \033[31mERR %s\033[0m\n' "$1"; }

# --- Ensure uv is available ------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
    step "Installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Make uv available in this shell without a restart
    export PATH="$HOME/.local/bin:$PATH"
    command -v uv >/dev/null 2>&1 || { err "uv not found after install"; exit 1; }
    ok "uv installed"
fi

# --- Load .env -------------------------------------------------------------
ENV_FILE="$ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    step "Loading .env"
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
    ok ".env loaded"
else
    echo "    (.env not found, using defaults / existing env)"
fi

# Apply defaults
: "${HOST:=127.0.0.1}"
: "${PORT:=8080}"
: "${DATA_DIR:=$ROOT/data}"
export HOST PORT DATA_DIR

mkdir -p "$DATA_DIR"

# --- Sync Python dependencies ----------------------------------------------
step "Syncing Python dependencies (uv sync)"
uv sync --quiet --project "$ROOT"
ok "dependencies synced"

# --- Frontend -------------------------------------------------------------
step "Checking frontend build"
if [ ! -f "$FRONTEND/dist/index.html" ]; then
    echo "    Building frontend (first run)..."
    if [ ! -d "$FRONTEND/node_modules" ]; then
        npm --prefix "$FRONTEND" install || { err "npm install failed"; exit 1; }
    fi
    npm --prefix "$FRONTEND" run build || { err "npm run build failed"; exit 1; }
    ok "frontend built"
else
    ok "frontend build exists, skipping"
fi

# --- Start backend --------------------------------------------------------
step "Starting CloakBrowser Manager"
echo "    DATA_DIR : $DATA_DIR"
if [ -n "${AUTH_TOKEN:-}" ]; then
    echo "    AUTH      : enabled"
else
    echo "    AUTH      : disabled"
fi
printf '    \033[33mURL       : http://%s:%s\033[0m\n\n' "$HOST" "$PORT"

exec uv run --project "$ROOT" --directory "$ROOT" uvicorn backend.main:app --host "$HOST" --port "$PORT"
