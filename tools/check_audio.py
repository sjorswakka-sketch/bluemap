#!/usr/bin/env python3
"""Controleert de geluiden in assets/audio/ op cijfers: clipping, naad van de muzieklussen, stilte en een paar noten."""
import os
import sys
import wave

import numpy as np

DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio"))
problems = []


def load(name):
    with wave.open(os.path.join(DIR, name + ".wav")) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2") / 32768.0, w.getframerate()


def dominant(x, sr, lo, hi, t0, dur):
    seg = x[int(t0 * sr):int((t0 + dur) * sr)]
    seg = seg * np.hanning(len(seg))
    spec = np.abs(np.fft.rfft(seg, 1 << 17))
    freqs = np.fft.rfftfreq(1 << 17, 1 / sr)
    band = (freqs > lo) & (freqs < hi)
    return freqs[band][np.argmax(spec[band])]


for fname in sorted(os.listdir(DIR)):
    if not fname.endswith(".wav"):
        continue
    name = fname[:-4]
    x, sr = load(name)
    peak = float(np.abs(x).max())
    clip = int((np.abs(x) > 0.999).sum())
    rms = float(np.sqrt((x ** 2).mean()))
    line = f"{name:15s} {len(x) / sr:6.2f}s  piek {peak:.2f}  rms {rms:.3f}"
    if clip:
        problems.append(f"{name}: {clip} samples clippen")
    if peak < 0.2:
        problems.append(f"{name}: te zacht")
    if name.startswith("music_"):
        steps = np.abs(np.diff(x))
        step = float(np.percentile(steps, 99.5))  # de grootste "gewone" sprongen elders in het stuk
        seam = abs(float(x[-1] - x[0]))
        line += f"  naad {seam:.3f} (grootste sprong elders {step:.3f})"
        if seam > max(step * 1.5, 0.05):
            problems.append(f"{name}: hoorbare tik op de naad van de lus ({seam:.3f})")
        block = int(sr * 1.0)
        blocks = [np.sqrt((x[i:i + block] ** 2).mean()) for i in range(0, len(x) - block, block)]
        silent = sum(1 for b in blocks if b < 0.01)
        if silent > len(blocks) * 0.1:
            problems.append(f"{name}: {silent} van de {len(blocks)} seconden zijn (bijna) stil")
    else:
        if abs(float(x[-1])) > 0.02:
            problems.append(f"{name}: eindigt abrupt ({x[-1]:.3f})")
    print(line)

# Noten die we verwachten (eerste melodienoot van elk stuk)
eighth = lambda bpm: 60 / bpm / 2
checks = [("music_forest", 96, 659.3, "E5"), ("music_village", 104, 659.3, "E5"), ("music_boss", 150, 659.3, "E5"),
          ("music_temple", 80, 659.3, "E5"), ("music_ending", 84, 659.3, "E5")]
for name, bpm, expect, label in checks:
    x, sr = load(name)
    f = dominant(x, sr, 500, 1400, 0.05, 1.5 * eighth(bpm))
    ok = abs(f - expect) < 12
    print(f"  {name}: eerste melodienoot {f:.0f} Hz (verwacht {label} = {expect:.0f} Hz) {'ok' if ok else 'FOUT'}")
    if not ok:
        problems.append(f"{name}: eerste noot klopt niet")

for p in problems:
    print("PROBLEEM:", p)
print("AUDIO OK" if not problems else f"{len(problems)} probleem/problemen")
sys.exit(1 if problems else 0)
