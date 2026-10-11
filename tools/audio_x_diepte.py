"""De Diepte (spoor diepte): geluiden van De Vergeten Wachter en het zegel, en twee muzieklussen.

Geluiden: guardian_roar, guardian_charge, pillar_charge, shard_burst, phase_shift, seal_break, star_fanfare, guardian_die.
Muziek:   music_depths (sfeer in de Diepte) en music_guardian (het baasgevecht).

Een eigen ruisgenerator, zodat andere uitbreidingen deze geluiden nooit veranderen.
"""
import numpy as np


def generate(ma):
    SR = ma.SR
    rng = np.random.default_rng(2718)

    def noise(n):
        return rng.uniform(-1, 1, n)

    def highpass(x, cutoff):
        return x - ma.lowpass(x, cutoff, cutoff)

    # --- geluidseffecten ---------------------------------------------------------------------------

    def sfx_roar():
        dur = 1.7
        n = int(SR * dur)
        t = ma.tt(dur)
        f = 62 + 20 * np.sin(2 * np.pi * 6.5 * t) * np.linspace(1.0, 0.4, n) - 18 * t / dur
        phase = 2 * np.pi * np.cumsum(f) / SR
        growl = np.sign(np.sin(phase)) * 0.45 + np.sin(phase * 2) * 0.25
        rumble = ma.lowpass(noise(n), 0.1, 0.04)
        env = np.minimum(t / 0.12, 1.0) * (np.sin(np.pi * np.minimum(t / dur, 1.0)) ** 0.6)
        return (growl * 0.8 + rumble * 1.1) * env

    def sfx_charge():
        dur = 0.85
        n = int(SR * dur)
        t = ma.tt(dur)
        ramp = (t / dur) ** 1.6
        sweep = ma.chirp(110, 700, dur) * ramp
        wind = ma.lowpass(noise(n), 0.02, 0.5) * ramp
        return sweep * 0.5 + wind * 0.9

    def sfx_pillar_charge():
        dur = 0.95
        n = int(SR * dur)
        t = ma.tt(dur)
        ramp = np.minimum(t / 0.25, 1.0) * (0.4 + 0.6 * t / dur)
        shimmer = ma.chirp(500, 1900, dur) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t))
        low = np.sin(2 * np.pi * 90 * t) * 0.3
        return (shimmer * 0.6 + low) * ramp

    def sfx_shard_burst():
        out = np.zeros(int(SR * 0.6))
        for i, f in enumerate([1568.0, 2093.0, 1760.0, 2637.0, 2349.0, 3136.0]):
            ma.mix_at(out, i * 0.022, ma.note_blip(f, 0.32, "sin", 13), 0.5)
        n = int(SR * 0.12)
        crack = highpass(noise(n), 0.4) * ma.decay(n, 45)
        ma.mix_at(out, 0.0, crack, 0.9)
        ma.mix_at(out, 0.0, ma.chirp(240, 90, 0.16) * ma.decay(int(SR * 0.16), 16), 0.7)
        return out

    def sfx_phase_shift():
        out = np.zeros(int(SR * 1.8))
        boom = ma.chirp(95, 28, 1.4) * ma.decay(int(SR * 1.4), 3.2)
        ma.mix_at(out, 0.0, boom, 1.0)
        n = int(SR * 1.2)
        swell = ma.lowpass(noise(n), 0.03, 0.4) * np.sin(np.linspace(0, np.pi, n)) ** 1.5
        ma.mix_at(out, 0.1, swell, 0.7)
        for i, f in enumerate([220.0, 277.2, 329.6, 440.0, 554.4, 659.3]):
            ma.mix_at(out, 0.15 + i * 0.13, ma.note_blip(f, 1.0, "tri", 3.0), 0.45)
        return out

    def sfx_seal_break():
        out = np.zeros(int(SR * 2.0))
        n = int(SR * 0.18)
        ma.mix_at(out, 0.0, highpass(noise(n), 0.3) * ma.decay(n, 30), 1.0)
        for p in (0.12, 0.2, 0.3):  # barsten
            m = int(SR * 0.08)
            ma.mix_at(out, p, highpass(noise(m), 0.35) * ma.decay(m, 60), 0.6)
        ma.mix_at(out, 0.0, ma.chirp(80, 36, 1.6) * ma.decay(int(SR * 1.6), 3.0), 0.9)
        for i, f in enumerate([1318.5, 1568.0, 2093.0, 2637.0]):  # glazen klokjes
            chime = ma.echo(ma.note_blip(f, 0.5, "sin", 7), 0.18, 0.5, 3)
            ma.mix_at(out, 0.35 + i * 0.1, chime, 0.45)
        return out

    def sfx_star_fanfare():
        out = np.zeros(int(SR * 4.2))
        ma.mix_at(out, 0.0, ma.kick(), 0.9)
        # opgaande trompetten
        for i, name in enumerate(["G4", "C5", "E5", "G5"]):
            ma.mix_at(out, 0.1 + i * 0.16, ma.note_blip(ma.hz(name), 0.35, "sq", 5), 0.45)
        # het grote akkoord
        for name in ("C4", "G4", "C5", "E5", "G5", "C6"):
            ma.mix_at(out, 0.85, ma.note_blip(ma.hz(name), 3.2, "tri", 1.1), 0.4)
        ma.mix_at(out, 0.85, ma.kick(), 0.7)
        # sterretjes
        for i, name in enumerate(["E6", "G6", "C7", "G6", "E7", "C7", "G7"]):
            chime = ma.echo(ma.note_blip(ma.hz(name), 0.6, "sin", 5), 0.22, 0.45, 3)
            ma.mix_at(out, 1.1 + i * 0.2, chime, 0.3)
        return out

    def sfx_guardian_die():
        dur = 2.4
        n = int(SR * dur)
        t = ma.tt(dur)
        groan = np.sign(ma.chirp(260, 32, dur)) * 0.4 * ma.decay(n, 1.6)
        crumble = np.zeros(n)
        for _ in range(26):  # vallende stenen
            p = rng.uniform(0.0, dur - 0.3)
            m = int(SR * rng.uniform(0.05, 0.14))
            ma.mix_at(crumble, p, ma.lowpass(noise(m), 0.3, 0.05) * ma.decay(m, 28), rng.uniform(0.3, 0.9) * (1.2 - p / dur))
        out = groan * 0.9 + crumble
        for i, f in enumerate([1046.5, 1318.5, 1568.0]):  # de ster dooft
            ma.mix_at(out, 1.2 + i * 0.25, ma.echo(ma.note_blip(f, 0.7, "sin", 4), 0.25, 0.5, 3), 0.4)
        return out

    for name, fn, peak in [("guardian_roar", sfx_roar, 0.85), ("guardian_charge", sfx_charge, 0.8),
                           ("pillar_charge", sfx_pillar_charge, 0.7), ("shard_burst", sfx_shard_burst, 0.8),
                           ("phase_shift", sfx_phase_shift, 0.85), ("seal_break", sfx_seal_break, 0.85),
                           ("star_fanfare", sfx_star_fanfare, 0.85), ("guardian_die", sfx_guardian_die, 0.85)]:
        ma.save(name, fn(), peak)

    # --- muziek: naadloze lussen --------------------------------------------------------------------

    cm, db, ab, fm = (36, [48, 51, 55]), (37, [49, 53, 56]), (32, [44, 48, 51]), (29, [41, 44, 48])
    gdim, eb, bb, gm = (31, [43, 46, 49]), (39, [51, 55, 58]), (34, [46, 50, 53]), (31, [43, 46, 50])

    def music_depths():
        """Langzame, echoënde sfeermuziek in C mineur: een diepe zoem, galm en spaarzame klokjes."""
        chords = [cm, db, cm, gdim, ab, fm, db, gm]
        melody = [
            [("G5", 6), ("R", 2)],
            [("F5", 4), ("G5", 2), ("R", 2)],
            [("D#5", 4), ("G5", 4)],
            [("D5", 6), ("R", 2)],
            [("C6", 4), ("A#5", 2), ("G5", 2)],
            [("G#5", 3), ("F5", 3), ("R", 2)],
            [("F5", 2), ("G#5", 2), ("C6", 4)],
            [("D6", 3), ("B5", 3), ("G5", 2)],
        ]
        return ma.compose(58, chords, melody, pad_gain=0.34, pad_attack=1.2, bass_pattern=((0, 0), (4, 0)), bass_gain=0.42,
                          bass_rate=1.3, arp_pattern=(0, 2, 1, 2, 0, 2, 1, 2), arp_gain=0.12, arp_octave=24,
                          arp_echo=(0.42, 0.55, 3), lead_gain=0.28, lead_vibrato=0.22, kick_pos=(), perc_gain=0.0)

    def music_guardian():
        """Zwaar baasgevecht in C mineur: stuwende bas, trommels en een dreigend motief."""
        g7 = (31, [43, 47, 50])
        chords = [cm, cm, ab, bb, cm, cm, fm, g7] * 2
        riff_a = [("C5", 1), ("C5", 1), ("D#5", 1), ("C5", 1), ("G5", 2), ("F5", 1), ("D#5", 1)]
        riff_b = [("C5", 1), ("C5", 1), ("D#5", 1), ("C5", 1), ("A#5", 2), ("G5", 1), ("F5", 1)]
        melody = [
            riff_a, riff_b,
            [("G#5", 1), ("G#5", 1), ("C6", 1), ("G#5", 1), ("D#6", 2), ("C6", 1), ("G#5", 1)],
            [("A#5", 1), ("A#5", 1), ("D6", 1), ("A#5", 1), ("F6", 2), ("D6", 1), ("A#5", 1)],
            riff_a, [("C5", 2), ("D#5", 2), ("G5", 2), ("C6", 2)],
            [("F5", 1), ("F5", 1), ("G#5", 1), ("F5", 1), ("C6", 2), ("A#5", 1), ("G#5", 1)],
            [("G5", 2), ("B5", 2), ("D6", 2), ("G6", 2)],
        ] * 2
        return ma.compose(124, chords, melody, pad_gain=0.16, pad_attack=0.4, bass_pattern=((0, 0), (1, 0), (2, 12), (3, 0), (4, 0), (5, 0), (6, 12), (7, 7)),
                          bass_gain=0.5, bass_rate=4.5, bass_rough=0.5, arp_pattern=None, lead_gain=0.4, lead_vibrato=0.06,
                          lead_square=0.5, kick_pos=(0, 2, 4, 6), snare_pos=(2, 6), hat_pos=(0, 1, 2, 3, 4, 5, 6, 7),
                          perc_gain=0.5)

    ma.save("music_depths", music_depths(), 0.7, fade=False)
    ma.save("music_guardian", music_guardian(), 0.7, fade=False)
