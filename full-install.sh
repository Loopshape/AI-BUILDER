#!/bin/bash
# ===============================================================
# Local AI Full Installer for Termux / Proot ARM
# Sets up Python env, Node, Whisper.cpp, dependencies
# ===============================================================

set -e

REPO_DIR="$HOME/.repository/AI-BUILDER"
ENV_DIR="$HOME/env"
PYTHON_VERSION=3.12

echo "[INSTALLER] Starting Local AI Termux Full Installer..."

# -----------------------------
# Create directories
# -----------------------------
mkdir -p "$REPO_DIR/public"
cd "$REPO_DIR"

# -----------------------------
# Python Virtualenv
# -----------------------------
echo "[INSTALLER] Installing Python packages..."
pkg install python clang make cmake git -y

# Ensure pip, venv, setuptools
python3 -m ensurepip --upgrade
python3 -m pip install --upgrade pip setuptools wheel

# Create virtual environment if not exists
if [ ! -d "$ENV_DIR" ]; then
    python3 -m venv "$ENV_DIR"
fi
source "$ENV_DIR/bin/activate"

# Install compatible Python packages
cat > requirements.txt <<EOL
sounddevice==0.5.2
scipy
numpy
EOL

pip install -r requirements.txt

# -----------------------------
# Node/NPM
# -----------------------------
echo "[INSTALLER] Installing Node.js..."
pkg install nodejs-lts -y
npm init -y
npm install express dotenv

# -----------------------------
# Whisper.cpp Build
# -----------------------------
echo "[INSTALLER] Installing whisper.cpp..."
if [ ! -d "$REPO_DIR/whisper.cpp" ]; then
    git clone https://github.com/ggerganov/whisper.cpp.git
fi

cd whisper.cpp
mkdir -p build
cd build
cmake ..
make -j$(nproc)

# Download English model
mkdir -p models
cd models
if [ ! -f "ggml-base.en.bin" ]; then
    wget https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
fi
cd "$REPO_DIR"

# -----------------------------
# .env
# -----------------------------
cat > .env <<EOL
PORT=3000
OLLAMA_USER=loop
OLLAMA_PASSWORD=6677788
OLLAMA_MODEL=2244-1
REPO_DIR=$REPO_DIR
EOL

# -----------------------------
# server.js
# -----------------------------
cat > server.js <<'EOL'
#!/usr/bin/env node
const express = require('express');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const AI_USER = process.env.OLLAMA_USER || "loop";
const AI_PASS = process.env.OLLAMA_PASSWORD || "6677788";
const MODEL = process.env.OLLAMA_MODEL || "2244-1";
const REPO_DIR = process.env.REPO_DIR || path.join(__dirname, '.ai_builder');
const LOG_FILE = path.join(REPO_DIR, 'chat.log');

if (!fs.existsSync(REPO_DIR)) fs.mkdirSync(REPO_DIR, { recursive: true });
fs.writeFileSync(LOG_FILE, fs.existsSync(LOG_FILE) ? fs.readFileSync(LOG_FILE) : '', { flag: 'a' });

app.use((req, res, next) => {
    const auth = { login: AI_USER, password: AI_PASS };
    const b64auth = (req.headers.authorization || '').split(' ')[1] || '';
    const [login, password] = Buffer.from(b64auth, 'base64').toString().split(':');
    if (login && password && login === auth.login && password === auth.password) return next();
    res.set('WWW-Authenticate', 'Basic realm="Local AI"');
    res.status(401).send('Authentication required.');
});

app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/log', (req, res) => {
    if (!fs.existsSync(LOG_FILE)) return res.send("No chat log found.");
    res.send(fs.readFileSync(LOG_FILE, 'utf8'));
});

function speakOffline(text) {
    spawn('espeak', [text]);
}

app.get('/api/stream', (req, res) => {
    const prompt = req.query.prompt;
    if (!prompt) return res.status(400).json({ error: "Missing prompt" });
    const timestamp = new Date().toISOString();
    fs.appendFileSync(LOG_FILE, `[${timestamp}] USER: ${prompt}\n`);
    res.writeHead(200, { 'Content-Type':'text/event-stream', 'Cache-Control':'no-cache', 'Connection':'keep-alive' });

    const ai = spawn('ollama', ['run', MODEL, prompt, '--stream', '--quiet']);
    let aiText = '';
    ai.stdout.on('data', chunk => {
        const text = chunk.toString();
        aiText += text;
        res.write(`data: ${text}\n\n`);
    });
    ai.on('close', () => {
        fs.appendFileSync(LOG_FILE, `[${timestamp}] AI: ${aiText.trim()}\n\n`);
        speakOffline(aiText);
        res.write(`event: end\ndata: [DONE]\n\n`);
        res.end();
    });
});

app.get('/api/listen', (req, res) => {
    const stt = spawn('python', [path.join(REPO_DIR, 'stt_offline.py')]);
    let text = '';
    stt.stdout.on('data', data => text += data.toString());
    stt.on('close', () => res.json({ text: text.trim() }));
});

app.listen(PORT, () => {
    console.log(`[SERVER] Local AI running at http://localhost:${PORT}`);
    console.log(`[SERVER] Model: ${MODEL}`);
    console.log(`[SERVER] Chat log: ${LOG_FILE}`);
});
EOL

# -----------------------------
# stt_offline.py
# -----------------------------
cat > stt_offline.py <<'EOL'
#!/usr/bin/env python3
import os
import subprocess
import sys

WHISPER_CPP_BIN = os.path.expanduser("~/.repository/AI-BUILDER/whisper.cpp/build/main")
AUDIO_FILE = "/tmp/temp.wav"
DURATION = 5
SAMPLE_RATE = 16000

if not os.path.exists(WHISPER_CPP_BIN):
    print("[ERROR] whisper.cpp binary not found!")
    sys.exit(1)

try:
    import sounddevice as sd
    import numpy as np
    from scipy.io.wavfile import write

    print(f"[STT] Recording {DURATION}s...")
    audio = sd.rec(int(DURATION * SAMPLE_RATE), samplerate=SAMPLE_RATE, channels=1, dtype='int16')
    sd.wait()
    write(AUDIO_FILE, SAMPLE_RATE, audio)
except Exception as e:
    print("[ERROR] Recording failed, falling back to Termux mic:", e)
    try:
        subprocess.run(["termux-microphone-record", "-o", AUDIO_FILE, "-d", str(DURATION*1000)], check=True)
    except Exception as e2:
        print("[ERROR] Termux mic fallback failed:", e2)
        sys.exit(1)

try:
    result = subprocess.run([WHISPER_CPP_BIN, "-f", AUDIO_FILE, "-m", "ggml-base.en.bin"],
                            capture_output=True, text=True)
    text = result.stdout.strip().split("\n")[-1]
    print(text)
except Exception as e:
    print("[ERROR] whisper.cpp failed:", e)
EOL

chmod +x server.js stt_offline.py

echo "[INSTALLER] Full install completed!"
echo "Run 'source $ENV_DIR/bin/activate' and 'node server.js' to start Local AI."
