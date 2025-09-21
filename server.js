#!/usr/bin/env node
const express = require('express');
const path = require('path');
const { spawn } = require('child_process');
require('dotenv').config();

const app = express();
const PORT = process.env.SERVER_PORT || 8080;
const MODEL = process.env.OLLAMA_MODEL || "2244-1";
const PUBLIC = path.join(__dirname, 'public');

app.use(express.static(PUBLIC));

app.get('/api/stream', (req, res) => {
  const prompt = req.query.prompt || '';
  if (!prompt) return res.status(400).json({ error: 'Missing prompt' });

  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive'
  });

  const ai = spawn('ollama', ['run', MODEL, prompt, '--stream', '--quiet']);
  ai.stdout.on('data', chunk => {
    const text = chunk.toString();
    res.write(`data: ${text}\n\n`);
  });

  ai.on('close', () => {
    res.write(`data: [DONE]\n\n`);
    res.end();
  });
});

app.listen(PORT, () => {
  console.log(`[SERVER] Listening http://localhost:${PORT} (model=${MODEL})`);
});
