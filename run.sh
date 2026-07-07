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
# VENV_DIR="$BACKEND_DIR/venv"

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

# if ! command -v npm &>/dev/null; then
#   echo "ERROR: npm is not installed. Install Node.js (which includes npm) and re-run." >&2
#   echo "  macOS:   brew install node" >&2
#   echo "  Ubuntu:  sudo apt-get install -y nodejs npm" >&2
#   echo "  Or use nvm: https://github.com/nvm-sh/nvm" >&2
#   exit 1
# fi

echo "Using: $(python3 --version), $(node -v), npm $(npm -v)"

# --- Backend setup ---------------------------------------------------------
echo "--- Setting up backend ---"
cd "$BACKEND_DIR"

# if [ ! -d "$VENV_DIR" ]; then
#   echo "Creating Python virtual environment..."
#   python3 -m venv "$VENV_DIR"
# fi

# # shellcheck disable=SC1091
# source "$VENV_DIR/bin/activate"
# pip install -q --upgrade pip
# pip install -q -r requirements.txt

echo "Starting FastAPI backend on port $BACKEND_PORT..."
python3 -m uvicorn main:app --host 0.0.0.0 --port "$BACKEND_PORT" --reload &
BACKEND_PID=$!

# deactivate

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
