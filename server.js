#!/usr/bin/env node

const express = require('express');
const path = require('path');
const fs = require('fs');
const { spawn, spawnSync } = require('child_process');
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

// Basic Auth
app.use((req, res, next) => {
    const auth = { login: AI_USER, password: AI_PASS };
    const b64auth = (req.headers.authorization || '').split(' ')[1] || '';
    const [login, password] = Buffer.from(b64auth, 'base64').toString().split(':');
    if (login && password && login === auth.login && password === auth.password) return next();
    res.set('WWW-Authenticate', 'Basic realm="Local AI"');
    res.status(401).send('Authentication required.');
});

// Serve static frontend
app.use(express.static(path.join(__dirname, 'public')));

// Chat log endpoint
app.get('/api/log', (req, res) => {
    if (!fs.existsSync(LOG_FILE)) return res.send("No chat log found.");
    res.send(fs.readFileSync(LOG_FILE, 'utf8'));
});

// Offline TTS function
function speakOffline(text) {
    spawn('espeak', [text]);
}

// AI streaming endpoint
app.get('/api/stream', (req, res) => {
    const prompt = req.query.prompt;
    if (!prompt) return res.status(400).json({ error: "Missing prompt parameter" });

    const timestamp = new Date().toISOString();
    fs.appendFileSync(LOG_FILE, `[${timestamp}] USER: ${prompt}\n`);

    res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive'
    });

    const ai = spawn('ollama', ['run', MODEL, prompt, '--stream', '--quiet']);
    let aiText = '';
    ai.stdout.on('data', (chunk) => {
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

// Offline STT
app.get('/api/listen', (req, res) => {
    const stt = spawn('python', [path.join(REPO_DIR, 'stt_offline.py')]);
    stt.stdout.on('data', (data) => {
        const text = data.toString().trim();
        if (text) res.json({ text });
    });
});

// --- RAM-only Wallet/Lightning Integration ---
function getWalletData() {
    const gpg = spawnSync('gpg', [
        '--batch', '--yes',
        '--passphrase', process.env.SERVER_PASS,
        '-d', `${REPO_DIR}/wallets/wallet.gpg`
    ], { encoding: 'utf-8' });

    if (gpg.status !== 0) throw new Error(gpg.stderr);
    return JSON.parse(gpg.stdout);
}

// Wallet balance endpoint
app.get('/api/wallet/balance', (req, res) => {
    try {
        const wallet = getWalletData();
        res.json({ balance: wallet.balance, channels: wallet.channels });
    } catch(e) {
        res.status(500).json({ error: e.message });
    }
});

// Lightning pay endpoint
app.post('/api/lightning/pay', (req, res) => {
    const invoice = req.body.invoice;
    if(!invoice) return res.status(400).json({ error: "Missing invoice" });

    try {
        const wallet = getWalletData();
        const result = `Paid invoice ${invoice} (simulation, balance ${wallet.balance})`;
        res.json({ result });
    } catch(e) {
        res.status(500).json({ error: e.message });
    }
});

// Start server
app.listen(PORT, () => {
    console.log(`[SERVER] Local AI Server running at http://localhost:${PORT}`);
    console.log(`[SERVER] Model: ${MODEL}`);
    console.log(`[SERVER] Chat log: ${LOG_FILE}`);
    console.log(`[SERVER] Wallet API enabled (RAM-only, encrypted)`);
});
