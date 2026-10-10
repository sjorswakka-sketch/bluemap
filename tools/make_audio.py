#!/usr/bin/env python3
"""Genereert alle geluiden en de muziek van het spel in assets/audio/ (16-bit mono WAV).

Gebruik:  python3 tools/make_audio.py      (numpy nodig: pip install numpy)

Alles wordt hier uit golfvormen opgebouwd, dus het is origineel en vrij te delen. Wil je andere
geluiden? Vervang gewoon de WAV-bestanden in assets/audio/ (zelfde bestandsnamen).
"""
import os
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


def mix_at(buf, start, wave, gain=1.0, wrap=False):
    i0 = int(start * SR)
    n = len(wave)
    if wrap:
        np.add.at(buf, (np.arange(n) + i0) % len(buf), wave * gain)
    else:
        end = min(i0 + n, len(buf))
        buf[i0:end] += wave[: end - i0] * gain


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


# --- muziek --------------------------------------------------------------------

BPM = 96
EIGHTH = 60.0 / BPM / 2
BAR = EIGHTH * 8

# (bas, akkoord) per maat; midi-nummers.
AM, F, C, G = (45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (43, [55, 59, 62])
DM, E = (50, [53, 57, 62]), (40, [52, 56, 59])

CHORDS = (
    [AM, F, C, G] + [AM, F, C, G] +        # A + A'
    [DM, AM, F, E] +                        # B
    [AM, F, C, G]                           # A''
)

# melodie: per maat een rij (noot, lengte in achtsten); tellen op tot 8.
MELODY = [
    # A
    [("E5", 3), ("C5", 2), ("D5", 1), ("E5", 2)],
    [("F5", 3), ("E5", 2), ("C5", 1), ("A4", 2)],
    [("G5", 3), ("E5", 2), ("D5", 1), ("C5", 2)],
    [("D5", 4), ("B4", 2), ("D5", 2)],
    # A'
    [("A5", 3), ("G5", 2), ("E5", 1), ("D5", 2)],
    [("C5", 3), ("D5", 1), ("E5", 2), ("F5", 2)],
    [("E5", 4), ("G5", 2), ("E5", 2)],
    [("D5", 3), ("E5", 1), ("D5", 2), ("B4", 2)],
    # B
    [("F5", 3), ("D5", 2), ("A4", 1), ("D5", 2)],
    [("E5", 3), ("A4", 2), ("C5", 1), ("E5", 2)],
    [("A5", 3), ("G5", 2), ("F5", 1), ("E5", 2)],
    [("E5", 2), ("G#5", 2), ("B5", 2), ("G#5", 2)],
    # A''
    [("E5", 3), ("C5", 2), ("D5", 1), ("E5", 2)],
    [("F5", 3), ("E5", 2), ("C5", 1), ("A4", 2)],
    [("G5", 3), ("E5", 2), ("D5", 1), ("C5", 2)],
    [("D5", 2), ("G5", 2), ("B5", 2), ("A5", 2)],
]


def lead(f, dur):
    tail = 0.12
    t = tt(dur + tail)
    vib = 0.12 * np.minimum(t / 0.25, 1.0) * np.sin(2 * np.pi * 5.2 * t)
    ph = 2 * np.pi * f * t + vib
    w = np.sin(ph) * 0.65 + np.sin(2 * ph) * 0.22 + np.sin(3 * ph) * 0.08
    n = len(t)
    env = np.minimum(t / 0.02, 1.0) * np.where(t < dur, 1.0, np.exp(-(t - dur) * 30)) * (0.75 + 0.25 * np.exp(-t * 4))
    return w * env[:n]


def pad(freqs, dur):
    tail = 0.5
    t = tt(dur + tail)
    w = sum(tri(f, t) * 0.5 + np.sin(2 * np.pi * f * t) * 0.5 for f in freqs) / len(freqs)
    env = np.minimum(t / 0.3, 1.0) * np.where(t < dur, 1.0, np.exp(-(t - dur) * 7))
    return w * env


def bass(f, dur):
    t = tt(dur)
    return (tri(f, t) * 0.8 + np.sin(2 * np.pi * f * t) * 0.4) * decay(len(t), 3.5, 0.006)


def pluck(f, dur=0.35):
    t = tt(dur)
    return (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t)) * decay(len(t), 10, 0.003)


def music():
    bars = len(CHORDS)
    buf = np.zeros(int(round(bars * BAR * SR)))
    for b, ((root, notes), melody) in enumerate(zip(CHORDS, MELODY)):
        t0 = b * BAR
        mix_at(buf, t0, pad([midi_hz(n) for n in notes], BAR), 0.20, wrap=True)
        for pos, off in ((0, 0), (2, 0), (4, 7), (6, 0)):
            mix_at(buf, t0 + pos * EIGHTH, bass(midi_hz(root + off), EIGHTH * 1.6), 0.45, wrap=True)
        arp = [notes[0], notes[1], notes[2], notes[1]] * 2
        for i, n in enumerate(arp):
            mix_at(buf, t0 + i * EIGHTH, pluck(midi_hz(n + 12)), 0.13, wrap=True)
        pos = 0
        for name, length in melody:
            mix_at(buf, t0 + pos * EIGHTH, lead(hz(name), length * EIGHTH * 0.92), 0.42, wrap=True)
            pos += length
        assert pos == 8, f"maat {b} heeft {pos} achtsten"
    return buf


def main():
    for name, fn in [("swing", sfx_swing), ("hit", sfx_hit), ("die", sfx_die), ("hurt", sfx_hurt),
                     ("coin", sfx_coin), ("heart", sfx_heart), ("crystal", sfx_crystal),
                     ("select", sfx_select), ("victory", sfx_victory), ("gameover", sfx_gameover)]:
        save(name, fn(), 0.8)
    save("music", music(), 0.7, fade=False)  # de muziek loopt naadloos, dus geen fade


if __name__ == "__main__":
    main()
