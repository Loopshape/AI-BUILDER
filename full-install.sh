#!/bin/bash
set -e

echo "[INSTALLER] Starting Local AI setup..."

# Update apt repositories
sudo apt update
sudo apt upgrade -y

# Install essential system packages
sudo apt install -y curl wget git espeak build-essential

# Install Node.js via NodeSource (LTS)
if ! command -v node >/dev/null 2>&1; then
    echo "[INSTALLER] Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Verify installation
echo "[INSTALLER] Node.js version: $(node -v)"
echo "[INSTALLER] npm version: $(npm -v)"

# Go to AI-BUILDER directory
cd ~/.repository/AI-BUILDER || exit

# Create package.json if missing
if [ ! -f package.json ]; then
    echo "[INSTALLER] Creating package.json..."
    cat > package.json <<EOL
{
  "name": "local-ai-server",
  "version": "1.0.0",
  "description": "Local AI Server with offline TTS",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "dotenv": "^16.0.0",
    "express": "^4.18.2"
  },
  "engines": {
    "node": ">=14"
  }
}
EOL
fi

# Install Node.js dependencies
echo "[INSTALLER] Installing Node.js packages..."
npm install

# Create log folder
mkdir -p ~/.repository/AI-BUILDER/.ai_builder
touch ~/.repository/AI-BUILDER/.ai_builder/chat.log

echo "[INSTALLER] Installation complete!"
echo "[INSTALLER] You can now start the server with: npm start"
