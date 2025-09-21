#!/usr/bin/env bash
set -e
echo "[UPDATE] Starting system & environment auto-update..."

# --- Load .env ---
export $(grep -v '^#' ~/.ai_builder/.env | xargs)

# --- 1. Update Debian packages ---
echo "[UPDATE] Updating Debian packages..."
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y
sudo apt clean

# --- 2. Update Python packages in venv ---
echo "[UPDATE] Updating Python packages..."
source ~/env/bin/activate
pip install --upgrade pip setuptools wheel
pip list --outdated --format=freeze | cut -d = -f 1 | xargs -n1 pip install -U

# --- 3. Update Node.js / NPM packages ---
echo "[UPDATE] Updating Node.js packages..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts --reinstall-packages-from=default
nvm use --lts
npm install -g npm
npm update -g

echo "[UPDATE] All packages updated successfully!"
