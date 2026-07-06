#!/usr/bin/env bash
#
# run.sh — starts the FastAPI backend and the React (Vite) frontend together.
# Debian/Ubuntu-specific version: uses apt-get for system dependencies,
# python3-venv, and installs Node.js/npm via apt (or NodeSource if apt's
# version is too old) when they're missing.
#
# Usage:
#   ./run.sh          # start both servers
#   Ctrl+C            # stops both servers cleanly
#
# Assumes this script lives at the project root, alongside backend/ and frontend/.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
VENV_DIR="$BACKEND_DIR/venv"
BACKEND_PORT=8000
FRONTEND_PORT=5173
MIN_NODE_MAJOR=18

echo "=== Task Manager launcher (Debian/Ubuntu) ==="

# --- Root/sudo helper ----------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo &>/dev/null; then
    SUDO="sudo"
  else
    echo "ERROR: this script needs root privileges to install packages, and 'sudo' isn't available." >&2
    echo "Re-run as root, or install sudo first." >&2
    exit 1
  fi
fi

apt_update_once() {
  if [ -z "${APT_UPDATED:-}" ]; then
    echo "Updating apt package index..."
    $SUDO apt-get update -y
    APT_UPDATED=1
  fi
}

# --- Sanity checks / auto-install -----------------------------------------
if ! command -v python3 &>/dev/null; then
  echo "python3 not found. Installing via apt..."
  apt_update_once
  $SUDO apt-get install -y python3
fi

if ! python3 -c "import ensurepip" &>/dev/null; then
  echo "python3-venv/ensurepip not found. Installing via apt..."
  apt_update_once
  $SUDO apt-get install -y python3-venv python3-pip
fi

if ! command -v pip3 &>/dev/null; then
  echo "pip3 not found. Installing via apt..."
  apt_update_once
  $SUDO apt-get install -y python3-pip
fi

install_node_via_nodesource() {
  echo "Installing Node.js ${MIN_NODE_MAJOR}.x via NodeSource..."
  apt_update_once
  $SUDO apt-get install -y ca-certificates curl gnupg
  curl -fsSL "https://deb.nodesource.com/setup_${MIN_NODE_MAJOR}.x" | $SUDO -E bash -
  $SUDO apt-get install -y nodejs
}

if ! command -v npm &>/dev/null; then
  echo "npm not found."
  install_node_via_nodesource
else
  NODE_MAJOR="$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')"
  if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt "$MIN_NODE_MAJOR" ]; then
    echo "Installed Node.js version is too old (found v${NODE_MAJOR:-unknown}, need >= $MIN_NODE_MAJOR)."
    install_node_via_nodesource
  fi
fi

echo "Using: $(python3 --version), $(node -v), npm $(npm -v)"

# --- Backend setup ---------------------------------------------------------
echo "--- Setting up backend ---"
cd "$BACKEND_DIR"
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating Python virtual environment..."
  python3 -m venv "$VENV_DIR"
fi
# shellcheck disable=SC1091
source "./backend/venv/bin/activate"
pip install -q --upgrade pip
pip install -q -r requirements.txt
echo "Starting FastAPI backend on port $BACKEND_PORT..."
uvicorn main:app --host 0.0.0.0 --port "$BACKEND_PORT" --reload &
BACKEND_PID=$!
deactivate

# --- Frontend setup ---------------------------------------------------------
echo "--- Setting up frontend ---"
cd "$FRONTEND_DIR"
if [ ! -d "node_modules" ]; then
  echo "Installing npm dependencies..."
  npm install
fi
echo "Starting React frontend on port $FRONTEND_PORT..."
npm run dev -- --port "$FRONTEND_PORT" --host &
FRONTEND_PID=$!

# --- Cleanup on exit ---------------------------------------------------------
cleanup() {
  echo ""
  echo "Shutting down servers..."
  kill "$BACKEND_PID" 2>/dev/null || true
  kill "$FRONTEND_PID" 2>/dev/null || true
  wait "$BACKEND_PID" 2>/dev/null || true
  wait "$FRONTEND_PID" 2>/dev/null || true
  echo "Stopped."
}
trap cleanup EXIT INT TERM

echo ""
echo "=================================================="
echo " Backend:  http://localhost:$BACKEND_PORT  (docs at /docs)"
echo " Frontend: http://localhost:$FRONTEND_PORT"
echo " Press Ctrl+C to stop both servers."
echo "=================================================="

# Wait on both background processes; if either exits, the script exits too.
wait
