#!/usr/bin/env node
const express = require('express');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
require('dotenv').config();

const app = express();
const PORT = process.env.SERVER_PORT || 3000;
const AI_USER = process.env.OLLAMA_USER || "loop";
const AI_PASS = process.env.OLLAMA_PASSWORD || "6677788";
const MODEL = process.env.OLLAMA_MODEL || "2244-1";
const REPO_DIR = process.env.REPO_DIR || path.join(__dirname, '.ai_builder');
const LOG_FILE = path.join(REPO_DIR, 'chat.log');

// Ensure log folder exists
if (!fs.existsSync(REPO_DIR)) fs.mkdirSync(REPO_DIR, { recursive: true });
if (!fs.existsSync(LOG_FILE)) fs.writeFileSync(LOG_FILE, '', { flag: 'a' });

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

// Offline TTS
function speakOffline(text) {
    if (!text) return;
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

app.listen(PORT, () => {
    console.log(`[SERVER] Local AI Server running at http://localhost:${PORT}`);
    console.log(`[SERVER] Model: ${MODEL}`);
    console.log(`[SERVER] Chat log: ${LOG_FILE}`);
});
