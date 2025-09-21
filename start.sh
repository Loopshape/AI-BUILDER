#!/usr/bin/env bash
set -e
echo "[STARTER] Launching Local AI + Crypto + VNC GUI..."

# --- Load .env ---
export $(grep -v '^#' ~/.ai_builder/.env | xargs)

# --- Activate Python venv ---
source ~/env/bin/activate

# --- Start Node.js server in background ---
NODE_LOG="$HOME/.ai_builder/server.log"
echo "[STARTER] Starting Node.js server..."
nohup node ~/.ai_builder/server.js > "$NODE_LOG" 2>&1 &

# --- Start TightVNC server ---
mkdir -p $HOME/.vnc
echo $SERVER_PASS | vncpasswd -f > $HOME/.vnc/passwd
chmod 600 $HOME/.vnc/passwd

cat > $HOME/.vnc/xstartup <<'EOF'
#!/bin/sh
xrdb $HOME/.Xresources
startxfce4 &
EOF
chmod +x $HOME/.vnc/xstartup

echo "[STARTER] Starting TightVNC server on :1..."
vncserver :1 -geometry 1280x720 -depth 24

# --- Optional: Encrypted backup ---
bash ~/.ai_builder/backup.sh

echo "[STARTER] All services started!"
echo "[INFO] Node server: http://localhost:3000 (logs: $NODE_LOG)"
echo "[INFO] VNC server: localhost:5901 (password: $SERVER_PASS)"
echo "[INFO] Stop VNC: vncserver -kill :1"
