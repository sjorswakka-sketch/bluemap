"""Geluid voor de arena: gong, juichend publiek, hekken, fanfare, nederlaag en de strijdmuziek (music_arena.wav).

make_audio.py roept generate(ma) aan; `ma` is make_audio zelf (ma.save, ma.compose, ma.tri, ...).
Alle ruis komt uit een eigen generator met vaste startwaarde, zodat de bestanden elke keer gelijk zijn
en de geluiden van de andere uitbreidingen er niet door veranderen.
"""
import numpy as np


def generate(ma):
    rng = np.random.default_rng(31)
    sr = ma.SR

    def noise(n):
        return rng.uniform(-1, 1, n)

    def band(x, low, high):
        """Ruis tussen twee afsnijdingen (grof bandfilter): laat alleen de middentonen over."""
        return ma.lowpass(x, high, high) - ma.lowpass(x, low, low)

    # --- gong: veel onzuivere boventonen die langzaam uitsterven ------------------------------------
    def gong():
        dur = 3.4
        n = int(sr * dur)
        t = ma.tt(dur)
        out = np.zeros(n)
        # (verhouding, sterkte, uitsterfsnelheid)
        for ratio, amp, rate in [(1.0, 1.0, 1.1), (1.504, 0.8, 1.5), (2.0, 0.6, 1.9), (2.76, 0.5, 2.5),
                                 (3.38, 0.35, 3.1), (4.12, 0.3, 3.8), (5.43, 0.2, 4.6)]:
            f = 98.0 * ratio
            bloom = 1.0 - np.exp(-t * 14.0)  # een gong zwelt na de slag nog even aan
            out += amp * bloom * np.exp(-t * rate) * (np.sin(2 * np.pi * f * t) + 0.6 * np.sin(2 * np.pi * f * 1.006 * t))
        strike = ma.lowpass(noise(n), 0.6, 0.08) * ma.decay(n, 30)
        return out * 0.55 + strike * 0.9

    # --- publiek: veel stemmen door elkaar en een zee van ruis ------------------------------------------
    def crowd(dur, voices, loud):
        n = int(sr * dur)
        t = ma.tt(dur)
        swell = np.minimum(t / (0.12 * dur + 0.05), 1.0) * np.exp(-np.maximum(t - dur * 0.45, 0.0) * (3.0 / dur))
        out = band(noise(n), 0.03, 0.4) * 0.9
        flutter = 0.75 + 0.25 * np.sin(2 * np.pi * rng.uniform(5, 9) * t + rng.uniform(0, 6))
        for _ in range(voices):
            f = rng.uniform(170, 330)
            start = rng.uniform(0.0, dur * 0.4)
            length = rng.uniform(0.5, 0.8) * dur
            tv = ma.tt(length)
            glide = 1.0 + 0.1 * np.minimum(tv / 0.3, 1.0)
            vib = 0.02 * np.sin(2 * np.pi * rng.uniform(4.5, 6.5) * tv)
            ph = 2 * np.pi * np.cumsum(f * glide * (1 + vib)) / sr
            # "aaah": een beetje scherp, met extra klank rond de eerste boventonen
            v = np.sin(ph) * 0.6 + np.sin(2 * ph) * 0.45 + np.sin(3 * ph) * 0.35 + np.sin(4 * ph) * 0.2
            env = np.minimum(tv / 0.08, 1.0) * np.exp(-np.maximum(tv - length * 0.5, 0.0) * 3.0)
            ma.mix_at(out, start, v * env, loud / voices * 3.0)
        return out * swell * flutter

    # --- hek omhoog: ratelende ketting, schurend ijzer en een bons ---------------------------------------
    def gate():
        dur = 1.25
        n = int(sr * dur)
        t = ma.tt(dur)
        out = ma.lowpass(noise(n), 0.14, 0.05) * np.sin(np.linspace(0, np.pi, n)) ** 0.8 * 0.7
        out += np.sin(2 * np.pi * 52 * t) * 0.35 * np.sin(np.linspace(0, np.pi, n))
        for k in range(int(0.95 * 20)):
            tick = band(noise(int(sr * 0.03)), 0.1, 0.7) * ma.decay(int(sr * 0.03), 90)
            ma.mix_at(out, k / 20.0, tick, 0.9)
        ma.mix_at(out, 0.95, ma.chirp(140, 44, 0.3) * ma.decay(int(sr * 0.3), 12), 0.9)
        return out

    # --- fanfare: koperachtige noten, trompetten en een pauk ----------------------------------------------
    def brass(freq, dur, rate=2.0):
        t = ma.tt(dur)
        ph = 2 * np.pi * freq * t + 0.03 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / 0.3, 1.0)
        w = (2 * ((ph / (2 * np.pi)) % 1.0) - 1) * 0.55 + np.where(np.sin(ph) > 0, 1.0, -1.0) * 0.3 + np.sin(ph) * 0.4
        w = ma.lowpass(w, 0.3, 0.12)
        env = np.minimum(t / 0.035, 1.0) * np.exp(-t * rate)
        return w * env

    def fanfare():
        out = np.zeros(int(sr * 3.2))
        ma.mix_at(out, 0.0, ma.kick() * 1.5, 0.8)
        for start, note, dur in [(0.0, "C5", 0.16), (0.18, "C5", 0.16), (0.36, "C5", 0.16), (0.56, "E5", 0.4), (1.0, "G5", 0.3),
                                 (1.36, "E5", 0.14), (1.54, "G5", 0.14), (1.72, "C6", 1.35)]:
            f = ma.hz(note)
            ma.mix_at(out, start, brass(f, dur, 1.6), 0.7)
            ma.mix_at(out, start, brass(f * 0.5, dur, 1.6), 0.35)
        for note in ("E5", "G5"):  # het slotakkoord
            ma.mix_at(out, 1.72, brass(ma.hz(note), 1.35, 1.6), 0.4)
        ma.mix_at(out, 1.72, ma.kick() * 1.4, 0.7)
        return out

    # --- nederlaag: een droevige trombone ------------------------------------------------------------------
    def defeat():
        out = np.zeros(int(sr * 2.8))
        for start, note, dur in [(0.0, "E4", 0.42), (0.5, "D#4", 0.42), (1.0, "D4", 0.42)]:
            ma.mix_at(out, start, brass(ma.hz(note), dur, 2.4) * (1 + 0.3 * np.sin(2 * np.pi * 7 * ma.tt(dur))), 0.8)
        # de laatste toon zakt door de grond
        dur = 1.4
        n = int(sr * dur)
        t = ma.tt(dur)
        glide = ma.hz("C#4") * np.exp(-t * 0.55)
        ph = 2 * np.pi * np.cumsum(glide) / sr
        w = ma.lowpass(np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph), 0.25, 0.08)
        ma.mix_at(out, 1.5, w * np.minimum(t / 0.05, 1.0) * np.exp(-t * 1.6), 1.0)
        return out

    ma.save("arena_gong", gong(), 0.8)
    ma.save("arena_crowd", crowd(2.6, 14, 1.0), 0.75)
    ma.save("arena_cheer", crowd(0.75, 6, 1.0), 0.7)
    ma.save("arena_gate", gate(), 0.75)
    ma.save("arena_fanfare", fanfare(), 0.8)
    ma.save("arena_defeat", defeat(), 0.8)
    ma.save("music_arena", music_arena(ma), 0.7, fade=False)  # een naadloze lus, dus geen fade


def music_arena(ma):
    """Stevige strijdmuziek in d-klein: marcherend ritme, ruwe bas en een koperachtige melodie. 16 maten van 128 bpm."""
    dm, bb, c, a = (38, [50, 53, 57]), (34, [53, 58, 62]), (36, [52, 55, 60]), (45, [57, 61, 64])
    gm, f = (43, [55, 58, 62]), (41, [53, 57, 60])
    chords = [dm, dm, bb, c, dm, dm, gm, a, dm, f, bb, c, gm, bb, a, a]
    melody = [
        [("D5", 2), ("D5", 1), ("F5", 1), ("A5", 2), ("G5", 1), ("F5", 1)],
        [("E5", 2), ("E5", 1), ("G5", 1), ("A5", 2), ("F5", 2)],
        [("F5", 2), ("F5", 1), ("A#5", 1), ("D6", 2), ("C6", 2)],
        [("E5", 2), ("G5", 2), ("C6", 2), ("G5", 2)],
        [("D5", 2), ("F5", 2), ("A5", 2), ("D6", 2)],
        [("C6", 2), ("A5", 2), ("F5", 2), ("A5", 2)],
        [("G5", 2), ("A#5", 2), ("D6", 2), ("A#5", 2)],
        [("A5", 2), ("C#6", 2), ("E6", 2), ("C#6", 1), ("A5", 1)],
        [("F5", 2), ("A5", 1), ("D6", 1), ("F6", 2), ("D6", 2)],
        [("C6", 2), ("F6", 2), ("C6", 2), ("A5", 2)],
        [("D6", 2), ("F6", 2), ("D6", 1), ("C6", 1), ("A#5", 2)],
        [("C6", 1), ("E6", 1), ("G6", 2), ("E6", 2), ("C6", 2)],
        [("D6", 3), ("C6", 1), ("A#5", 2), ("G5", 2)],
        [("A#5", 2), ("D6", 2), ("F6", 4)],
        [("E6", 2), ("C#6", 2), ("A5", 2), ("C#6", 2)],
        [("A5", 4), ("E5", 2), ("A5", 2)],
    ]
    return ma.compose(128, chords, melody, pad_gain=0.14, bass_pattern=((0, 0), (1, 0), (2, 12), (3, 0), (4, 0), (5, 0), (6, 7), (7, 0)),
                      bass_gain=0.48, bass_rate=6.0, bass_rough=0.4, arp_pattern=(0, 2, 1, 2, 0, 2, 1, 2), arp_gain=0.09,
                      lead_gain=0.4, lead_vibrato=0.06, lead_square=0.55, kick_pos=(0, 3, 4), snare_pos=(2, 6),
                      hat_pos=(1, 3, 5, 7), perc_gain=0.46)
