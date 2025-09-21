#!/usr/bin/env bash
set -e
echo "[LAUNCHER] Starting complete Local AI + Crypto + Lightning environment..."

# --- Load environment variables ---
export $(grep -v '^#' ~/.ai_builder/.env | xargs)

# --- Activate Python venv ---
source ~/env/bin/activate
echo "[LAUNCHER] Python venv activated."

# --- Auto-update system & packages ---
echo "[LAUNCHER] Running auto-update..."
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean

pip install --upgrade pip setuptools wheel
pip list --outdated --format=freeze | cut -d = -f 1 | xargs -n1 pip install -U

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts --reinstall-packages-from=default
nvm use --lts
npm install -g npm
npm update -g
echo "[LAUNCHER] Auto-update completed."

# --- Start Node.js server ---
NODE_LOG="$HOME/.ai_builder/server.log"
echo "[LAUNCHER] Starting Node.js server..."
nohup node ~/.ai_builder/server.js > "$NODE_LOG" 2>&1 &

# --- Setup VNC ---
mkdir -p $HOME/.vnc
echo $SERVER_PASS | vncpasswd -f > $HOME/.vnc/passwd
chmod 600 $HOME/.vnc/passwd

cat > $HOME/.vnc/xstartup <<'EOF'
#!/bin/sh
xrdb $HOME/.Xresources
startxfce4 &
EOF
chmod +x $HOME/.vnc/xstartup

echo "[LAUNCHER] Starting VNC server on :1..."
vncserver :1 -geometry 1280x720 -depth 24

# --- Encrypted Backups ---
mkdir -p ~/.ai_builder/backups ~/.ai_builder/secure ~/.ai_builder/wallets
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup AI & secure data
BACKUP_FILE="$HOME/.ai_builder/backups/backup_$TIMESTAMP.tar.gz"
SECURE_BACKUP="$BACKUP_FILE.gpg"
tar -czf "$BACKUP_FILE" -C "$HOME/.ai_builder/secure" .
echo "$SERVER_PASS" | gpg --batch --yes --passphrase-fd 0 -c "$BACKUP_FILE"
rm "$BACKUP_FILE"
echo "[BACKUP] Encrypted AI backup created: $SECURE_BACKUP"

# Backup Wallets
if [ -d "$HOME/.ai_builder/wallets" ]; then
  WALLET_BACKUP="$HOME/.ai_builder/backups/wallet_$TIMESTAMP.tar.gz"
  WALLET_SECURE="$WALLET_BACKUP.gpg"
  tar -czf "$WALLET_BACKUP" -C "$HOME/.ai_builder/wallets" .
  echo "$SERVER_PASS" | gpg --batch --yes --passphrase-fd 0 -c "$WALLET_BACKUP"
  rm "$WALLET_BACKUP"
  echo "[BACKUP] Encrypted wallet backup created: $WALLET_SECURE"
fi

# --- Test Wallet CLI (Lightning/Balance) ---
if [ -f "$HOME/.ai_builder/wallet-cli.sh" ]; then
  echo "[LAUNCHER] Testing Wallet CLI..."
  bash ~/.ai_builder/wallet-cli.sh
fi

# --- Summary ---
echo "[LAUNCHER] All services started successfully!"
echo "[INFO] Node server: http://localhost:3000 (logs: $NODE_LOG)"
echo "[INFO] VNC server: localhost:5901 (password: $SERVER_PASS)"
echo "[INFO] Stop VNC: vncserver -kill :1"
echo "[INFO] Encrypted backups located in ~/.ai_builder/backups"
