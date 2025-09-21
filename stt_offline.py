#!/usr/bin/env python3
# stt_offline.py
# Offline STT using Vosk 0.15 in Termux/Proot (Python 3.11)

import sys
import os
import json
import queue
import sounddevice as sd
from vosk import Model, KaldiRecognizer

# Pfad zu deinem Vosk-Modell
MODEL_PATH = "/home/loop/.repository/AI-BUILDER/vosk-model-small-en-us-0.15"

if not os.path.exists(MODEL_PATH):
    print(f"Model not found at {MODEL_PATH}", file=sys.stderr)
    sys.exit(1)

# Lade Modell
model = Model(MODEL_PATH)

# Sample rate (gängig für Termux)
RATE = 16000
CHANNELS = 1

q = queue.Queue()

def callback(indata, frames, time, status):
    if status:
        print(status, file=sys.stderr)
    q.put(bytes(indata))

# Erstelle Recognizer
rec = KaldiRecognizer(model, RATE)

try:
    with sd.InputStream(samplerate=RATE, channels=CHANNELS, dtype='int16', callback=callback):
        print("Listening... Speak now!")
        sys.stdout.flush()
        while True:
            data = q.get()
            if rec.AcceptWaveform(data):
                res = json.loads(rec.Result())
                if res.get("text"):
                    print(res["text"])
                    sys.stdout.flush()
            else:
                # Zwischenergebnisse
                partial = json.loads(rec.PartialResult())
                # optional: print(partial["partial"])
except KeyboardInterrupt:
    print("\nStopped by user")
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
