#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==== CONFIG ====
MODEL="2244-1"
PORT=3000
PASSWORD="6677788"
REPO_DIR="$HOME/.ai_builder"
BIN_DIR="$HOME/bin"
LOGFILE="$REPO_DIR/server.log"
PIDFILE="$REPO_DIR/server.pid"

echo "[INFO] Starting Local AI Offline Install..."

# ==== TERMUX PACKAGES ====
pkg update -y
pkg upgrade -y
pkg install -y nodejs git curl wget unzip

# ==== CREATE REPO DIR ====
mkdir -p "$REPO_DIR/public"
mkdir -p "$BIN_DIR"

# ==== INSTALL NGROK (optional, nur wenn Internet) ====
if ! command -v ngrok >/dev/null 2>&1; then
    echo "[INFO] Installing ngrok (optional)..."
    wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-arm64.zip -O /tmp/ngrok.zip
    unzip -o /tmp/ngrok.zip -d "$BIN_DIR"
    chmod +x "$BIN_DIR/ngrok"
    export PATH="$BIN_DIR:$PATH"
fi

# ==== WRITE .env ====
cat > "$REPO_DIR/.env" <<EOL
OLLAMA_MODEL=$MODEL
PORT=$PORT
OLLAMA_PASSWORD=$PASSWORD
EOL

# ==== WRITE server.js ====
cat > "$REPO_DIR/server.js" <<'EOL'
import express from "express";
import { spawn } from "child_process";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import bodyParser from "body-parser";

dotenv.config();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3000;
const PASSWORD = process.env.OLLAMA_PASSWORD || "6677788";

app.use(express.static(path.join(__dirname, "public")));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.json());

app.get("/", (req, res) => { res.sendFile(path.join(__dirname, "public/login.html")); });

app.post("/login", (req, res) => {
  if (req.body.password === PASSWORD) res.redirect("/app.html");
  else res.send("<h2>Wrong password. <a href='/'>Try again</a></h2>");
});

app.post("/api/ollama", (req, res) => {
  const prompt = req.body.prompt || "Hello AI!";
  const model = process.env.OLLAMA_MODEL || "2244-1";
  const ollama = spawn("ollama", ["run", model, prompt]);
  let output = "";
  ollama.stdout.on("data", (data) => output += data.toString());
  ollama.stderr.on("data", (data) => console.error("[OLLAMA ERROR]", data.toString()));
  ollama.on("close", () => res.json({ reply: output.trim() }));
});

app.listen(PORT, "0.0.0.0", () => console.log(`🚀 Offline server running on http://localhost:${PORT}`));
EOL

# ==== COPY login.html + app.html ====
# Hier deine vorher gebauten login.html + app.html Dateien im gleichen Ordner wie dieses Script liegen
cp ./login.html "$REPO_DIR/public/login.html"
cp ./app.html "$REPO_DIR/public/app.html"

# ==== CREATE start.sh ====
cat > "$REPO_DIR/start.sh" <<EOL
#!/data/data/com.termux/files/usr/bin/bash
set -e
export OLLAMA_MODEL=$MODEL
export PORT=$PORT

LOGFILE="$LOGFILE"
PIDFILE="$PIDFILE"

# Kill old process
[ -f "\$PIDFILE" ] && kill \$(cat "\$PIDFILE") 2>/dev/null && rm -f "\$PIDFILE"

# Start server
nohup node "$REPO_DIR/server.js" > "\$LOGFILE" 2>&1 &
echo \$! > "\$PIDFILE"
echo "[INFO] Offline Local AI server started, PID: \$(cat \$PIDFILE)"
echo "[INFO] Access at http://localhost:\$PORT"

# Optional ngrok if Internet available
if command -v ngrok >/dev/null 2>&1; then
    echo "[INFO] Optional ngrok: starting if Internet available..."
    nohup ngrok http \$PORT > "$REPO_DIR/ngrok.log" 2>&1 &
    sleep 2
    NGROK_URL=\$(curl -s http://127.0.0.1:4040/api/tunnels | grep -oP '(?<="public_url":")[^"]+')
    [ -n "\$NGROK_URL" ] && echo "[INFO] ngrok URL: \$NGROK_URL"
fi
EOL

chmod +x "$REPO_DIR/start.sh"

echo "[INFO] OFFLINE INSTALL DONE! Run the server with:"
echo "$REPO_DIR/start.sh"
