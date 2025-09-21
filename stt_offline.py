#!/usr/bin/env python3
"""
Offline STT via whisper.cpp (Termux/ARM)
Compatible with Local AI Server
"""

import os
import subprocess
import sys

WHISPER_CPP_BIN = os.path.expanduser("~/.repository/AI-BUILDER/whisper.cpp/build/main")
AUDIO_FILE = "/tmp/temp.wav"
DURATION = 5  # seconds
SAMPLE_RATE = 16000

# Check whisper.cpp binary
if not os.path.exists(WHISPER_CPP_BIN):
    print("[ERROR] whisper.cpp binary not found! Build it first.")
    sys.exit(1)

# Record audio via sounddevice
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
    # Fallback via Termux API
    try:
        subprocess.run(["termux-microphone-record", "-o", AUDIO_FILE, "-d", str(DURATION*1000)], check=True)
    except Exception as e2:
        print("[ERROR] Termux mic fallback failed:", e2)
        sys.exit(1)

# Run whisper.cpp
try:
    result = subprocess.run([WHISPER_CPP_BIN, "-f", AUDIO_FILE, "-m", "ggml-base.en.bin"],
                            capture_output=True, text=True)
    text = result.stdout.strip().split("\n")[-1]  # last line as transcription
    print(text)
except Exception as e:
    print("[ERROR] whisper.cpp failed:", e)
