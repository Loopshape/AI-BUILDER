#!/usr/bin/env bash
set -e

USER_NAME="${USER:-loop}"
AI_PASS="6677788"
MODEL="2244-1"
REPO_DIR="$HOME/.ai_builder"
ENV_DIR="$HOME/env"
PYTHON_VERSION="python3"
SERVER_JS="$REPO_DIR/server.js"
LOG_FILE="$REPO_DIR/chat.log"

echo "[INSTALLER] Starting Termux Local AI setup for user: $USER_NAME"

mkdir -p "$REPO_DIR"

# === Dependency Check ===
echo "[INSTALLER] Checking dependencies..."
deps=(gawk vim net-tools xxd curl wget git node npm nvm espeak unzip python3-pip)
need_install=()

for dep in "${deps[@]}"; do
    if ! command -v $dep >/dev/null 2>&1; then
        need_install+=("$dep")
    fi
done

if [ ${#need_install[@]} -gt 0 ]; then
    echo "[ACTION] Installing missing packages: ${need_install[*]}"
    if command -v pkg >/dev/null 2>&1; then
        pkg install -y "${need_install[@]}"
    else
        apt update
        apt install -y "${need_install[@]}"
    fi
fi

# === Python Virtual Environment Setup ===
if [ ! -d "$ENV_DIR" ]; then
    echo "[INSTALLER] Setting up Python virtual environment at $ENV_DIR"
    $PYTHON_VERSION -m venv "$ENV_DIR"
fi

source "$ENV_DIR/bin/activate"
pip install --upgrade pip setuptools wheel

# === Install Vosk offline STT ===
if ! pip show vosk >/dev/null 2>&1; then
    echo "[INSTALLER] Installing Vosk"
    pip install git+https://github.com/alphacep/vosk-api.git#subdirectory=python
fi

# === Install requirements.txt if exists ===
if [ -f "$REPO_DIR/requirements.txt" ]; then
    echo "[INSTALLER] Installing Python requirements from requirements.txt"
    pip install -r "$REPO_DIR/requirements.txt"
fi

# === Node / NVM Setup ===
if [ ! -d "$HOME/.nvm" ]; then
    echo "[INSTALLER] Installing NVM"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.6/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# === JS Packages ===
npm install -g react vue grunt gulp express lodash backbone

# === Server.js Environment ===
touch "$LOG_FILE"

if [ ! -f "$SERVER_JS" ]; then
    echo "[INSTALLER] Creating default server.js"
    cat > "$SERVER_JS" <<EOL
#!/usr/bin/env node
const express = require('express');
const fs = require('fs');
const { spawn } = require('child_process');
const app = express();
const PORT = process.env.PORT || 3000;
const AI_USER = process.env.OLLAMA_USER || "$USER_NAME";
const AI_PASS = process.env.OLLAMA_PASSWORD || "$AI_PASS";
const MODEL = process.env.OLLAMA_MODEL || "$MODEL";
const LOG_FILE = "$LOG_FILE";

if (!fs.existsSync(LOG_FILE)) fs.writeFileSync(LOG_FILE, '', { flag: 'a' });

app.use((req, res, next) => {
    const auth = { login: AI_USER, password: AI_PASS };
    const b64auth = (req.headers.authorization || '').split(' ')[1] || '';
    const [login, password] = Buffer.from(b64auth, 'base64').toString().split(':');
    if (login && password && login === auth.login && password === auth.password) return next();
    res.set('WWW-Authenticate', 'Basic realm="Local AI"');
    res.status(401).send('Authentication required.');
});

app.use(express.static(__dirname + '/public'));

app.get('/api/log', (req, res) => {
    if (!fs.existsSync(LOG_FILE)) return res.send("No chat log found.");
    res.send(fs.readFileSync(LOG_FILE, 'utf8'));
});

function speakOffline(text) {
    spawn('espeak', [text]);
}

app.get('/api/stream', (req, res) => {
    const prompt = req.query.prompt;
    if (!prompt) return res.status(400).json({ error: "Missing prompt parameter" });
    const timestamp = new Date().toISOString();
    fs.appendFileSync(LOG_FILE, \`[\${timestamp}] USER: \${prompt}\n\`);
    res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive' });

    const ai = spawn('ollama', ['run', MODEL, prompt, '--stream', '--quiet']);
    let aiText = '';
    ai.stdout.on('data', (chunk) => {
        const text = chunk.toString();
        aiText += text;
        res.write(\`data: \${text}\n\n\`);
    });
    ai.on('close', () => {
        fs.appendFileSync(LOG_FILE, \`[\${timestamp}] AI: \${aiText.trim()}\n\n\`);
        speakOffline(aiText);
        res.write('event: end\ndata: [DONE]\n\n');
        res.end();
    });
});

app.get('/api/listen', (req, res) => {
    const stt = spawn('python3', ["$REPO_DIR/stt_offline.py"]);
    stt.stdout.on('data', (data) => {
        const text = data.toString().trim();
        if (text) res.json({ text });
    });
});

app.listen(PORT, () => {
    console.log(\`[SERVER] Local AI Server running at http://localhost:\${PORT}\`);
    console.log(\`[SERVER] Model: \${MODEL}\`);
    console.log(\`[SERVER] Chat log: \${LOG_FILE}\`);
});
EOL
    chmod +x "$SERVER_JS"
fi

# === Start Ollama server in background ===
if ! pgrep -f "ollama serve" >/dev/null; then
    echo "[INSTALLER] Starting Ollama server in background..."
    nohup ollama serve >/dev/null 2>&1 &
fi

echo "[INSTALLER] Setup complete!"
echo "[INFO] Run server with: node $SERVER_JS"
