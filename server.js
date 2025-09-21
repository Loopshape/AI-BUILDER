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

// Ensure repo dir & log file exist
if (!fs.existsSync(REPO_DIR)) fs.mkdirSync(REPO_DIR, { recursive: true });
if (!fs.existsSync(LOG_FILE)) fs.writeFileSync(LOG_FILE, '', { flag: 'a' });

// -----------------------------
// Basic Auth
// -----------------------------
app.use((req, res, next) => {
    const auth = { login: AI_USER, password: AI_PASS };
    const b64auth = (req.headers.authorization || '').split(' ')[1] || '';
    const [login, password] = Buffer.from(b64auth, 'base64').toString().split(':');
    if (login && password && login === auth.login && password === auth.password) return next();
    res.set('WWW-Authenticate', 'Basic realm="Local AI"');
    res.status(401).send('Authentication required.');
});

// -----------------------------
// Serve frontend
// -----------------------------
app.use(express.static(path.join(__dirname, 'public')));

// -----------------------------
// Chat log endpoint
// -----------------------------
app.get('/api/log', (req, res) => {
    if (!fs.existsSync(LOG_FILE)) return res.send("No chat log found.");
    res.send(fs.readFileSync(LOG_FILE, 'utf8'));
});

// -----------------------------
// Offline TTS
// -----------------------------
function speakOffline(text) {
    const espeak = spawn('espeak', [text]);
    espeak.on('error', (err) => console.warn('[TTS ERROR]', err));
}

// -----------------------------
// AI streaming endpoint
// -----------------------------
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

    const ai = spawn('ollama', ['run', MODEL, prompt, '--stream', '--quiet'], {
        env: { ...process.env, PATH: `${process.env.HOME}/env/bin:${process.env.PATH}` }
    });

    let aiText = '';
    ai.stdout.on('data', (chunk) => {
        const text = chunk.toString();
        aiText += text;
        res.write(`data: ${text}\n\n`);
    });

    ai.stderr.on('data', (chunk) => console.error('[AI STDERR]', chunk.toString()));

    ai.on('close', () => {
        fs.appendFileSync(LOG_FILE, `[${timestamp}] AI: ${aiText.trim()}\n\n`);
        speakOffline(aiText);
        res.write(`event: end\ndata: [DONE]\n\n`);
        res.end();
    });
});

// -----------------------------
// Offline STT endpoint
// -----------------------------
app.get('/api/listen', (req, res) => {
    const stt = spawn('python', [path.join(REPO_DIR, 'stt_offline.py')], {
        env: { ...process.env, PATH: `${process.env.HOME}/env/bin:${process.env.PATH}` }
    });

    stt.stdout.on('data', (data) => {
        const text = data.toString().trim();
        if (text) res.json({ text });
    });

    stt.stderr.on('data', (err) => console.error('[STT ERROR]', err.toString()));
});

// -----------------------------
// Start server
// -----------------------------
app.listen(PORT, () => {
    console.log(`[SERVER] Local AI Server running at http://localhost:${PORT}`);
    console.log(`[SERVER] Model: ${MODEL}`);
    console.log(`[SERVER] Chat log: ${LOG_FILE}`);
});
