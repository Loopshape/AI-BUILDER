#!/usr/bin/env bash
# start.sh - Local AI Starter for Termux / Proot

# Set repository and venv paths
REPO_DIR="$HOME/.repository/AI-BUILDER"
VENV_DIR="$HOME/env"

# Activate Python virtual environment
if [ -f "$VENV_DIR/bin/activate" ]; then
    echo "[START] Activating Python venv..."
    source "$VENV_DIR/bin/activate"
else
    echo "[WARN] Python virtual environment not found at $VENV_DIR"
    exit 1
fi

# Ensure required Python packages are installed
REQ_FILE="$REPO_DIR/requirements.txt"
if [ -f "$REQ_FILE" ]; then
    echo "[START] Installing Python dependencies..."
    pip install --upgrade pip
    pip install -r "$REQ_FILE"
fi

# Set Node/NVM environment
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Optional: Load Homebrew (if installed)
if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Start Local AI server
SERVER_LOG="$REPO_DIR/server.log"
echo "[START] Starting Local AI Server..."
nohup node "$REPO_DIR/server.js" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
echo "[START] Server running in background (PID $SERVER_PID)"
echo "[START] Logs: $SERVER_LOG"

# Optional: keep shell open for CLI usage
echo "[INFO] You can now run '~/bin/ai' to interact with Local AI CLI."
echo "[INFO] Press Ctrl+C to exit this shell; server will continue running."

# Wait a bit to let server start
sleep 2

# Tail the log (optional, comment out if not needed)
tail -f "$SERVER_LOG"
