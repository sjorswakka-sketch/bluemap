#!/usr/bin/env python3
"""Genereert alle geluiden en de muziek van het spel in assets/audio/ (16-bit mono WAV).

Gebruik:  python3 tools/make_audio.py      (numpy nodig: pip install numpy)

Alles wordt hier uit golfvormen opgebouwd, dus het is origineel en vrij te delen. Wil je andere
geluiden? Vervang gewoon de WAV-bestanden in assets/audio/ (zelfde bestandsnamen).
Muziek: music_<naam>.wav (village, forest, ruins, cave, boss, temple, ending).
"""
import glob
import importlib.util
import os
import sys
import wave

import numpy as np

SR = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "audio"))
RNG = np.random.default_rng(7)


# --- bouwstenen ----------------------------------------------------------------

def tt(dur):
    return np.arange(int(SR * dur)) / SR


def hz(note_name):
    """'A4' of 'G#5' -> frequentie in Hz."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = names[note_name[0]]
    rest = note_name[1:]
    if rest.startswith("#"):
        n += 1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + n
    return 440.0 * 2 ** ((midi - 69) / 12)


def midi_hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def tri(f, t):
    return 2 * np.abs(2 * ((f * t) % 1.0) - 1) - 1


def square(f, t, duty=0.5):
    return np.where((f * t) % 1.0 < duty, 1.0, -1.0)


def saw(f, t):
    return 2 * ((f * t) % 1.0) - 1


def chirp(f0, f1, dur):
    """Sinus die van f0 naar f1 glijdt (exponentieel)."""
    t = tt(dur)
    k = np.log(f1 / f0) / dur
    return np.sin(2 * np.pi * f0 * (np.exp(k * t) - 1) / k)


def decay(n, rate, attack=0.004):
    t = np.arange(n) / SR
    return np.minimum(t / attack, 1.0) * np.exp(-t * rate)


def lowpass(x, c0, c1):
    """Eenvoudig laagdoorlaatfilter waarvan de afsnijding van c0 naar c1 loopt (0..1)."""
    out = np.zeros_like(x)
    y = 0.0
    for i, v in enumerate(x):
        a = c0 + (c1 - c0) * i / len(x)
        y += a * (v - y)
        out[i] = y
    return out


def seq(parts):
    return np.concatenate(parts)


def mix_at(buf, start, wave_, gain=1.0, wrap=False):
    i0 = int(round(start * SR))
    n = len(wave_)
    if wrap:
        np.add.at(buf, (np.arange(n) + i0) % len(buf), wave_ * gain)
    else:
        end = min(i0 + n, len(buf))
        if end > i0:
            buf[i0:end] += wave_[: end - i0] * gain


def echo(wave_, delay, gain, repeats):
    """Voegt galm toe door vertraagde, zachtere kopieën bij te mengen."""
    pad = int(SR * delay * repeats)
    out = np.concatenate([wave_, np.zeros(pad)])
    for r in range(1, repeats + 1):
        start = int(SR * delay * r)
        out[start:start + len(wave_)] += wave_ * (gain ** r)
    return out


def save(name, samples, peak=0.85, fade=True):
    s = np.asarray(samples, dtype=np.float64)
    s = s / (np.max(np.abs(s)) or 1.0) * peak
    if fade:  # korte in- en uitfade tegen tikjes aan begin en einde
        n_in, n_out = int(SR * 0.002), int(SR * 0.012)
        s[:n_in] *= np.linspace(0, 1, n_in)
        s[-n_out:] *= np.linspace(1, 0, n_out)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((s * 32767).astype("<i2").tobytes())
    print(f"assets/audio/{name}.wav  {len(s) / SR:.2f}s")


# --- geluidseffecten -----------------------------------------------------------

def sfx_swing():
    n = int(SR * 0.2)
    x = lowpass(RNG.uniform(-1, 1, n), 0.05, 0.5)
    env = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return x * env


def sfx_hit():
    n = int(SR * 0.12)
    thump = chirp(260, 70, 0.12) * decay(n, 18)
    crack = lowpass(RNG.uniform(-1, 1, n), 0.5, 0.1) * decay(n, 40)
    return thump * 0.8 + crack * 0.6


def sfx_die():
    n = int(SR * 0.35)
    body = np.sign(chirp(420, 55, 0.35)) * 0.5 * decay(n, 7)
    pop = lowpass(RNG.uniform(-1, 1, n), 0.4, 0.05) * decay(n, 14)
    return body + pop * 0.6


def sfx_hurt():
    n = int(SR * 0.3)
    t = tt(0.3)
    wob = 1 + 0.04 * np.sin(2 * np.pi * 28 * t)
    return np.sign(chirp(340, 100, 0.3) * wob) * 0.6 * decay(n, 6)


def note_blip(f, dur, kind="tri", rate=10.0):
    t = tt(dur)
    wave_ = tri(f, t) if kind == "tri" else square(f, t, 0.5) * 0.5 if kind == "sq" else np.sin(2 * np.pi * f * t)
    return wave_ * decay(len(t), rate)


def sfx_coin():
    return seq([note_blip(hz("B5"), 0.06, "sq", 8), note_blip(hz("E6"), 0.22, "sq", 14)])


def sfx_heart():
    return seq([note_blip(hz(n), 0.08, "tri", 7) for n in ("C5", "E5", "G5")]
               + [note_blip(hz("C6"), 0.22, "tri", 9)])


def sfx_crystal():
    notes = ["E5", "G5", "A5", "C6", "D6", "E6", "G6"]
    out = np.zeros(int(SR * 1.0))
    for i, n in enumerate(notes):
        w = note_blip(hz(n), 0.45, "sin", 6) + 0.4 * note_blip(hz(n) * 2, 0.45, "sin", 8)
        mix_at(out, i * 0.06, w, 1.0)
    return out


def sfx_select():
    return seq([note_blip(hz("E5"), 0.045, "tri", 5), note_blip(hz("A5"), 0.08, "tri", 12)])


def sfx_victory():
    out = np.zeros(int(SR * 2.4))
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        mix_at(out, i * 0.16, note_blip(hz(n), 0.4, "sq", 5), 0.5)
    for n in ("C5", "E5", "G5", "C6"):
        mix_at(out, 0.7, note_blip(hz(n), 1.6, "tri", 2.2), 0.55)
    return out


def sfx_gameover():
    out = np.zeros(int(SR * 2.2))
    for i, n in enumerate(["A4", "F4", "D4"]):
        mix_at(out, i * 0.3, note_blip(hz(n), 0.5, "tri", 4), 0.8)
    mix_at(out, 0.9, note_blip(hz("A3"), 1.2, "tri", 2.5), 1.0)
    mix_at(out, 0.9, note_blip(hz("E3"), 1.2, "tri", 2.5), 0.6)
    return out


def sfx_dodge():
    n = int(SR * 0.16)
    x = lowpass(RNG.uniform(-1, 1, n), 0.5, 0.06)
    return x * (np.linspace(1, 0, n) ** 0.7)


def sfx_arrow():
    n = int(SR * 0.14)
    twang = chirp(900, 380, 0.14) * decay(n, 22)
    tick = lowpass(RNG.uniform(-1, 1, n), 0.7, 0.2) * decay(n, 70)
    return twang * 0.8 + tick * 0.4


def sfx_chest():
    creak = chirp(110, 210, 0.14) * decay(int(SR * 0.14), 9) * 0.5
    sparkle = np.zeros(int(SR * 0.5))
    for i, n in enumerate(["G5", "B5", "D6"]):
        mix_at(sparkle, i * 0.07, note_blip(hz(n), 0.3, "sin", 8), 0.9)
    return seq([creak, sparkle])


def sfx_buy():
    out = np.zeros(int(SR * 0.6))
    for i, n in enumerate(["B5", "E6", "B5", "E6", "G6"]):
        mix_at(out, i * 0.07, note_blip(hz(n), 0.18, "sq", 12), 0.6)
    return out


def sfx_save():
    out = np.zeros(int(SR * 1.2))
    for n in ("E5", "G5", "B5", "E6"):
        w = note_blip(hz(n), 1.1, "sin", 3.2) + 0.3 * note_blip(hz(n) * 2, 1.1, "sin", 5)
        mix_at(out, 0.0, w, 0.5)
    return out


def sfx_door():
    n = int(SR * 0.3)
    swoosh = lowpass(RNG.uniform(-1, 1, n), 0.3, 0.04) * np.sin(np.linspace(0, np.pi, n)) ** 1.2
    thud = np.sin(2 * np.pi * 90 * tt(0.3)) * decay(n, 14)
    return swoosh * 0.6 + thud * 0.8


def sfx_boss():
    dur = 1.5
    n = int(SR * dur)
    t = tt(dur)
    f = 62 + 14 * np.sin(2 * np.pi * 9 * t) * np.linspace(1, 0.3, n)
    growl = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.5
    rumble = lowpass(RNG.uniform(-1, 1, n), 0.15, 0.05)
    env = np.minimum(t / 0.1, 1.0) * np.exp(-t * 1.4)
    return (growl + rumble * 0.9) * env


def sfx_error():
    return seq([note_blip(hz("E3"), 0.1, "sq", 6), note_blip(hz("C3"), 0.18, "sq", 8)])


def sfx_quest():
    out = np.zeros(int(SR * 1.2))
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        mix_at(out, i * 0.11, note_blip(hz(n), 0.5, "tri", 4), 0.7)
    for n in ("G5", "C6", "E6"):
        mix_at(out, 0.5, note_blip(hz(n), 0.7, "sin", 3.5), 0.45)
    return out


def sfx_upgrade():
    out = np.zeros(int(SR * 1.4))
    clang = lowpass(RNG.uniform(-1, 1, int(SR * 0.1)), 0.7, 0.2) * decay(int(SR * 0.1), 40)
    mix_at(out, 0.0, clang, 0.8)
    for f in (880, 1320, 1760, 2200):
        mix_at(out, 0.0, np.sin(2 * np.pi * f * tt(0.6)) * decay(int(SR * 0.6), 7), 0.3)
    for i, n in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        mix_at(out, 0.3 + i * 0.09, note_blip(hz(n), 0.5, "sin", 5), 0.6)
    return out


def sfx_slam():
    n = int(SR * 0.4)
    boom = chirp(130, 38, 0.4) * decay(n, 7)
    crash = lowpass(RNG.uniform(-1, 1, n), 0.3, 0.03) * decay(n, 9)
    return boom * 0.9 + crash * 0.8


def sfx_drink():
    out = np.zeros(int(SR * 0.5))
    for i in range(2):
        mix_at(out, i * 0.12, chirp(420, 250, 0.1) * decay(int(SR * 0.1), 18), 0.8)
    mix_at(out, 0.28, note_blip(hz("E6"), 0.2, "sin", 12), 0.4)
    mix_at(out, 0.33, note_blip(hz("A6"), 0.2, "sin", 12), 0.35)
    return out


# --- instrumenten ----------------------------------------------------------------

def lead(f, dur, vibrato=0.12, square_mix=0.0):
    tail = 0.12
    t = tt(dur + tail)
    vib = vibrato * np.minimum(t / 0.25, 1.0) * np.sin(2 * np.pi * 5.2 * t)
    ph = 2 * np.pi * f * t + vib
    w = np.sin(ph) * 0.65 + np.sin(2 * ph) * 0.22 + np.sin(3 * ph) * 0.08
    if square_mix:
        w = w * (1 - square_mix) + square(f, t, 0.4) * 0.5 * square_mix
    n = len(t)
    env = np.minimum(t / 0.02, 1.0) * np.where(t < dur, 1.0, np.exp(-(t - dur) * 30)) * (0.75 + 0.25 * np.exp(-t * 4))
    return w * env[:n]


def pad(freqs, dur, attack=0.3):
    tail = 0.5
    t = tt(dur + tail)
    w = sum(tri(f, t) * 0.5 + np.sin(2 * np.pi * f * t) * 0.5 for f in freqs) / len(freqs)
    env = np.minimum(t / attack, 1.0) * np.where(t < dur, 1.0, np.exp(-(t - dur) * 7))
    return w * env


def bass(f, dur, rate=3.5, rough=0.0):
    t = tt(dur)
    base = tri(f, t) * 0.8 + np.sin(2 * np.pi * f * t) * 0.4
    if rough:
        base = base * (1 - rough) + saw(f, t) * 0.5 * rough
    return base * decay(len(t), rate, 0.006)


def pluck(f, dur=0.35, rate=10.0):
    t = tt(dur)
    return (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t)) * decay(len(t), rate, 0.003)


def kick():
    n = int(SR * 0.22)
    return chirp(150, 45, 0.22) * decay(n, 20)


def snare():
    n = int(SR * 0.2)
    noise = lowpass(RNG.uniform(-1, 1, n), 0.5, 0.9) * decay(n, 22)
    body = tri(190, tt(0.2)) * decay(n, 30) * 0.5
    return noise * 0.8 + body


def hat():
    n = int(SR * 0.06)
    x = RNG.uniform(-1, 1, n)
    x = x - lowpass(x, 0.3, 0.3)
    return x * decay(n, 70)


# --- muziek: een kleine "componist" ----------------------------------------------------------

def compose(bpm, chords, melody, *, pad_gain=0.2, bass_pattern=((0, 0), (2, 0), (4, 7), (6, 0)), bass_gain=0.45,
            bass_rate=3.5, bass_rough=0.0, arp_pattern=(0, 1, 2, 1, 0, 1, 2, 1), arp_gain=0.13, arp_octave=12,
            arp_echo=None, lead_gain=0.42, lead_vibrato=0.12, lead_square=0.0, kick_pos=(), snare_pos=(), hat_pos=(),
            perc_gain=0.35, pad_attack=0.3, rest_every=None):
    eighth = 60.0 / bpm / 2
    bar = eighth * 8
    bars = len(chords)
    buf = np.zeros(int(round(bars * bar * SR)))
    for b, ((root, notes), mel) in enumerate(zip(chords, melody)):
        t0 = b * bar
        if pad_gain:
            mix_at(buf, t0, pad([midi_hz(n) for n in notes], bar, pad_attack), pad_gain, wrap=True)
        for pos, off in bass_pattern:
            mix_at(buf, t0 + pos * eighth, bass(midi_hz(root + off), eighth * 1.7, bass_rate, bass_rough), bass_gain, wrap=True)
        if arp_pattern:
            for i, idx in enumerate(arp_pattern):
                w = pluck(midi_hz(notes[idx % len(notes)] + arp_octave))
                if arp_echo:
                    w = echo(w, *arp_echo)
                mix_at(buf, t0 + i * eighth, w, arp_gain, wrap=True)
        pos = 0
        for name, length in mel:
            if name != "R":
                mix_at(buf, t0 + pos * eighth, lead(hz(name), length * eighth * 0.92, lead_vibrato, lead_square), lead_gain, wrap=True)
            pos += length
        assert pos == 8, f"maat {b} heeft {pos} achtsten"
        for p in kick_pos:
            mix_at(buf, t0 + p * eighth, kick(), perc_gain, wrap=True)
        for p in snare_pos:
            mix_at(buf, t0 + p * eighth, snare(), perc_gain * 0.8, wrap=True)
        for p in hat_pos:
            mix_at(buf, t0 + p * eighth, hat(), perc_gain * 0.45, wrap=True)
    return buf


AM, F, C, G = (45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (43, [55, 59, 62])
DM, E = (50, [53, 57, 62]), (40, [52, 56, 59])


def music_forest():
    chords = [AM, F, C, G] * 2 + [DM, AM, F, E] + [AM, F, C, G]
    melody = [
        [("E5", 3), ("C5", 2), ("D5", 1), ("E5", 2)],
        [("F5", 3), ("E5", 2), ("C5", 1), ("A4", 2)],
        [("G5", 3), ("E5", 2), ("D5", 1), ("C5", 2)],
        [("D5", 4), ("B4", 2), ("D5", 2)],
        [("A5", 3), ("G5", 2), ("E5", 1), ("D5", 2)],
        [("C5", 3), ("D5", 1), ("E5", 2), ("F5", 2)],
        [("E5", 4), ("G5", 2), ("E5", 2)],
        [("D5", 3), ("E5", 1), ("D5", 2), ("B4", 2)],
        [("F5", 3), ("D5", 2), ("A4", 1), ("D5", 2)],
        [("E5", 3), ("A4", 2), ("C5", 1), ("E5", 2)],
        [("A5", 3), ("G5", 2), ("F5", 1), ("E5", 2)],
        [("E5", 2), ("G#5", 2), ("B5", 2), ("G#5", 2)],
        [("E5", 3), ("C5", 2), ("D5", 1), ("E5", 2)],
        [("F5", 3), ("E5", 2), ("C5", 1), ("A4", 2)],
        [("G5", 3), ("E5", 2), ("D5", 1), ("C5", 2)],
        [("D5", 2), ("G5", 2), ("B5", 2), ("A5", 2)],
    ]
    return compose(96, chords, melody)


def music_village():
    cC, cG, cAm, cF = (48, [60, 64, 67]), (43, [55, 59, 62]), (45, [57, 60, 64]), (41, [53, 57, 60])
    chords = [cC, cG, cAm, cF, cC, cG, cF, cG, cAm, cF, cC, cG, cF, cG, cC, cC]
    melody = [
        [("E5", 2), ("G5", 2), ("E5", 1), ("D5", 1), ("C5", 2)],
        [("D5", 2), ("G5", 2), ("B4", 2), ("D5", 2)],
        [("C5", 2), ("E5", 2), ("A5", 2), ("G5", 2)],
        [("A5", 2), ("F5", 2), ("C5", 2), ("A4", 2)],
        [("G5", 2), ("E5", 2), ("C5", 2), ("E5", 2)],
        [("D5", 1), ("E5", 1), ("D5", 2), ("B4", 2), ("G4", 2)],
        [("A4", 2), ("C5", 2), ("F5", 2), ("E5", 2)],
        [("D5", 4), ("R", 2), ("B4", 1), ("D5", 1)],
        [("E5", 2), ("A5", 2), ("G5", 2), ("E5", 2)],
        [("F5", 2), ("A5", 2), ("G5", 2), ("F5", 2)],
        [("E5", 2), ("G5", 2), ("C6", 2), ("G5", 2)],
        [("B5", 2), ("A5", 2), ("G5", 2), ("D5", 2)],
        [("A5", 3), ("G5", 1), ("F5", 2), ("C5", 2)],
        [("G5", 2), ("F5", 1), ("E5", 1), ("D5", 2), ("B4", 2)],
        [("C5", 2), ("E5", 2), ("G5", 2), ("E5", 2)],
        [("C5", 4), ("R", 4)],
    ]
    return compose(104, chords, melody, bass_pattern=((0, 0), (3, 7), (4, 0), (7, 7)), lead_gain=0.4,
                   arp_pattern=(0, 1, 2, 1, 2, 1, 0, 1), kick_pos=(0, 4), hat_pos=(2, 6), perc_gain=0.22, lead_vibrato=0.08)


def music_ruins():
    dm, bb, gm, a = (38, [50, 53, 57]), (34, [53, 58, 62]), (43, [55, 58, 62]), (45, [57, 61, 64])
    chords = [dm, bb, gm, a] * 3
    melody = [
        [("A4", 4), ("F4", 2), ("A4", 2)], [("D5", 4), ("C5", 2), ("A#4", 2)], [("G4", 2), ("A#4", 2), ("D5", 4)], [("E5", 4), ("C#5", 2), ("A4", 2)],
        [("F5", 4), ("E5", 2), ("D5", 2)], [("D5", 2), ("F5", 2), ("A#4", 4)], [("D5", 4), ("G5", 2), ("F5", 2)], [("E5", 2), ("C#5", 2), ("R", 4)],
        [("A4", 6), ("R", 2)], [("A#4", 4), ("D5", 4)], [("G4", 4), ("D5", 4)], [("C#5", 4), ("A4", 4)],
    ]
    return compose(72, chords, melody, pad_gain=0.22, bass_pattern=((0, 0), (4, 7)), bass_gain=0.5, bass_rate=2.2,
                   arp_pattern=(0, 2, 1, 2, 0, 2, 1, 2), arp_gain=0.16, arp_octave=12, arp_echo=(0.33, 0.55, 3),
                   lead_gain=0.34, lead_vibrato=0.2, pad_attack=0.8, kick_pos=(0,), perc_gain=0.28)


def music_temple():
    am, f, c, e = (45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (40, [52, 56, 59])
    g, dm = (43, [55, 59, 62]), (50, [53, 57, 62])
    chords = [am, f, c, e, am, f, g, e, dm, f, e, am]
    melody = [
        [("E5", 4), ("C5", 2), ("E5", 2)], [("F5", 4), ("A5", 2), ("F5", 2)], [("G5", 4), ("E5", 2), ("G5", 2)], [("G#5", 4), ("B5", 2), ("G#5", 2)],
        [("A5", 4), ("E5", 2), ("C5", 2)], [("A5", 2), ("C6", 2), ("A5", 2), ("F5", 2)], [("B5", 4), ("D6", 2), ("B5", 2)], [("G#5", 2), ("E5", 2), ("B4", 4)],
        [("F5", 4), ("A5", 2), ("D6", 2)], [("C6", 4), ("A5", 2), ("F5", 2)], [("B5", 4), ("G#5", 2), ("E5", 2)], [("A5", 8)],
    ]
    return compose(80, chords, melody, pad_gain=0.3, pad_attack=0.9, bass_pattern=((0, 0), (4, 0)), bass_gain=0.5, bass_rate=1.6,
                   arp_pattern=(0, 1, 2, 1, 0, 1, 2, 1), arp_gain=0.14, arp_octave=12, arp_echo=(0.28, 0.5, 2),
                   lead_gain=0.4, lead_vibrato=0.16, kick_pos=(0,), perc_gain=0.4)


def music_boss():
    em, c, d, f, b = (40, [52, 55, 59]), (36, [48, 52, 55]), (38, [50, 54, 57]), (41, [53, 57, 60]), (35, [47, 51, 54])
    chords = [em, em, c, d, em, em, f, b] * 2
    riff1 = [("E5", 1), ("E5", 1), ("G5", 1), ("E5", 1), ("B5", 2), ("A5", 1), ("G5", 1)]
    riff1b = [("E5", 1), ("E5", 1), ("G5", 1), ("E5", 1), ("D6", 2), ("B5", 1), ("A5", 1)]
    melody = [
        riff1, riff1b,
        [("G5", 1), ("G5", 1), ("C6", 1), ("G5", 1), ("E6", 2), ("D6", 1), ("C6", 1)],
        [("F#5", 1), ("F#5", 1), ("A5", 1), ("F#5", 1), ("D6", 2), ("C#6", 1), ("A5", 1)],
        riff1, [("E5", 2), ("G5", 2), ("B5", 2), ("E6", 2)],
        [("F5", 1), ("F5", 1), ("A5", 1), ("F5", 1), ("C6", 2), ("A#5", 1), ("A5", 1)],
        [("B5", 2), ("A#5", 2), ("B5", 2), ("D#6", 2)],
    ] * 2
    return compose(150, chords, melody, pad_gain=0.12, bass_pattern=((0, 0), (1, 0), (2, 12), (3, 0), (4, 0), (5, 0), (6, 12), (7, 7)),
                   bass_gain=0.5, bass_rate=5.0, bass_rough=0.5, arp_pattern=None, lead_gain=0.4, lead_vibrato=0.05, lead_square=0.45,
                   kick_pos=(0, 2, 4, 6), snare_pos=(2, 6), hat_pos=(0, 1, 2, 3, 4, 5, 6, 7), perc_gain=0.5)


def music_ending():
    cC, cG, cAm, cEm = (48, [60, 64, 67]), (43, [55, 59, 62]), (45, [57, 60, 64]), (40, [52, 55, 59])
    cF, cDm = (41, [53, 57, 60]), (50, [53, 57, 62])
    chords = [cC, cG, cAm, cEm, cF, cC, cF, cG, cC, cG, cAm, cF, cDm, cG, cC, cC]
    melody = [
        [("E5", 2), ("G5", 2), ("C6", 4)], [("B5", 2), ("A5", 2), ("G5", 4)], [("A5", 2), ("C6", 2), ("E6", 4)], [("E6", 2), ("D6", 2), ("B5", 4)],
        [("C6", 2), ("A5", 2), ("F5", 4)], [("G5", 2), ("E5", 2), ("C5", 4)], [("A5", 2), ("C6", 2), ("F6", 4)], [("D6", 4), ("B5", 2), ("G5", 2)],
        [("E5", 2), ("G5", 2), ("C6", 2), ("E6", 2)], [("D6", 2), ("B5", 2), ("G5", 4)], [("C6", 2), ("E6", 2), ("A5", 4)], [("A5", 2), ("C6", 2), ("F5", 4)],
        [("D6", 2), ("A5", 2), ("F5", 4)], [("B5", 2), ("D6", 2), ("G5", 4)], [("C6", 4), ("G5", 2), ("E5", 2)], [("C6", 8)],
    ]
    return compose(84, chords, melody, pad_gain=0.26, pad_attack=0.7, bass_pattern=((0, 0), (4, 7)), bass_gain=0.4, bass_rate=2.5,
                   arp_pattern=(0, 1, 2, 1, 0, 1, 2, 1), arp_gain=0.15, arp_octave=12, lead_gain=0.4, lead_vibrato=0.14)


def music_cave():
    """Donkere sfeermuziek zonder maat: een zware zoem, een langzame golf en druppels.
    Alle frequenties hebben een heel aantal golven in 32 seconden, zodat de lus geen tik geeft."""
    dur = 32.0
    n = int(SR * dur)
    t = np.arange(n) / SR

    def loopf(f):
        return round(f * dur) / dur

    buf = np.zeros(n)
    for f, g in ((41.2, 0.5), (61.7, 0.3), (82.4, 0.25)):
        f = loopf(f)
        phase = 2 * np.pi * f * t + 0.8 * np.sin(2 * np.pi * t / 16.0 + f)  # periodiek: kleine golving in de toon
        buf += (np.sin(phase) * 0.8 + saw(f, t + (0.17 + 0.31 * f % 1.0) / f) * 0.15) * g  # zaagtanden springen niet tegelijk
    swell = np.sin(np.pi * t / 16.0) ** 2  # twee golven in 32 seconden: loopt netjes rond
    for f in (164.8, 196.0, 246.9):  # E-minor akkoord, hoog en ijl
        buf += np.sin(2 * np.pi * loopf(f) * t) * swell * 0.07
        buf += np.sin(2 * np.pi * loopf(f * 1.004) * t) * swell * 0.05
    rnd = np.random.default_rng(5)
    for _ in range(15):
        f = rnd.choice([659.3, 784.0, 987.8, 1174.7, 880.0])
        start = rnd.uniform(0.0, dur - 3.0)
        drip = echo(np.sin(2 * np.pi * f * tt(0.5)) * decay(int(SR * 0.5), 14), 0.45, 0.45, 4)
        mix_at(buf, start, drip, 0.16, wrap=True)
    return buf


def main():
    for name, fn in [("swing", sfx_swing), ("hit", sfx_hit), ("die", sfx_die), ("hurt", sfx_hurt),
                     ("coin", sfx_coin), ("heart", sfx_heart), ("crystal", sfx_crystal),
                     ("select", sfx_select), ("victory", sfx_victory), ("gameover", sfx_gameover),
                     ("dodge", sfx_dodge), ("arrow", sfx_arrow), ("chest", sfx_chest), ("buy", sfx_buy),
                     ("save", sfx_save), ("door", sfx_door), ("boss", sfx_boss), ("error", sfx_error),
                     ("quest", sfx_quest), ("upgrade", sfx_upgrade), ("slam", sfx_slam), ("drink", sfx_drink)]:
        save(name, fn(), 0.8)
    for name, fn in [("village", music_village), ("forest", music_forest), ("ruins", music_ruins), ("cave", music_cave),
                     ("boss", music_boss), ("temple", music_temple), ("ending", music_ending)]:
        save("music_" + name, fn(), 0.7, fade=False)  # de muziek loopt naadloos, dus geen fade


def run_extensions():
    """Uitbreidingen: tools/audio_x_<naam>.py met een functie generate(ma). `ma` is deze module (save, tri, compose...)."""
    for path in sorted(glob.glob(os.path.join(HERE, "audio_x_*.py"))):
        spec = importlib.util.spec_from_file_location(os.path.basename(path)[:-3], path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.generate(sys.modules[__name__])


if __name__ == "__main__":
    main()
    run_extensions()
