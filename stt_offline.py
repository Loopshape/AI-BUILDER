#!/usr/bin/env python3
import sys
import queue
import sounddevice as sd
import vosk
import json

# Vosk Model path
MODEL_PATH = "/home/loop/.repository/AI-BUILDER/vosk-model-small-en-us-0.22"

try:
    model = vosk.Model(MODEL_PATH)
except Exception as e:
    print(f"ERROR: Could not load Vosk model: {e}", file=sys.stderr)
    sys.exit(1)

q = queue.Queue()

# Audio callback
def callback(indata, frames, time, status):
    if status:
        print(status, file=sys.stderr)
    q.put(bytes(indata))

# Record & recognize
try:
    with sd.RawInputStream(samplerate=16000, blocksize = 8000, dtype='int16',
                           channels=1, callback=callback):
        rec = vosk.KaldiRecognizer(model, 16000)
        while True:
            data = q.get()
            if rec.AcceptWaveform(data):
                result = rec.Result()
                text = json.loads(result).get("text", "")
                if text:
                    print(text)
                    sys.stdout.flush()
                    break
except KeyboardInterrupt:
    print("\n[INFO] Stopped by user")
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
