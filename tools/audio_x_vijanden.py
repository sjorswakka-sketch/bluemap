"""Uitbreiding 'vijanden': geluiden voor de Magiër en de Slijmspuwer (namen staan in scripts/data/ext/vijanden.gd).

  mage_teleport   verdwijnen en weer verschijnen (zwiep omhoog, plop met belletjes)
  mage_charge     de aanloop: een stijgende, trillende toon van een halve seconde
  mage_orb        de arcane bol vertrekt
  mage_orb_pop    de bol wordt stukgeslagen
  spitter_spit    de Slijmspuwer spuugt een waaier slijmballen
  spitter_hop     de Slijmspuwer hupt weg
"""
import numpy as np


def generate(ma):
    # Eigen ruisgenerator: zo hangen deze geluiden niet af van andere uitbreidingen en blijven bestaande geluiden gelijk.
    rng = np.random.default_rng(31)
    sr = ma.SR

    def noise(n):
        return rng.uniform(-1, 1, n)

    def bell(f, dur, rate):
        return np.sin(2 * np.pi * f * ma.tt(dur)) * ma.decay(int(sr * dur), rate)

    def teleport():
        out = np.zeros(int(sr * 0.55))
        # verdwijnen: een zwiep omhoog met ruis die opengaat
        n = int(sr * 0.22)
        up = ma.chirp(260, 1900, 0.22) * np.sin(np.linspace(0, np.pi, n)) ** 0.8
        hiss = ma.lowpass(noise(n), 0.08, 0.7) * np.linspace(0.2, 1.0, n) * np.linspace(1.0, 0.1, n)
        ma.mix_at(out, 0.0, up * 0.7 + hiss * 0.5)
        # verschijnen: een plop omlaag en een paar belletjes
        n2 = int(sr * 0.16)
        ma.mix_at(out, 0.2, ma.chirp(1500, 420, 0.16) * ma.decay(n2, 14), 0.8)
        ma.mix_at(out, 0.2, ma.lowpass(noise(n2), 0.5, 0.1) * ma.decay(n2, 30), 0.45)
        for i, note in enumerate(["E6", "C#7", "A6", "E7"]):
            ma.mix_at(out, 0.26 + i * 0.05, bell(ma.hz(note), 0.2, 16), 0.3)
        return out

    def charge():
        dur = 0.5
        n = int(sr * dur)
        t = ma.tt(dur)
        # de toonhoogte loopt op van E4 naar B5; een snelle trilling maakt het "elektrisch"
        freq = np.geomspace(ma.hz("E4"), ma.hz("B5"), n)
        phase = 2 * np.pi * np.cumsum(freq) / sr
        tone = np.sin(phase) * 0.7 + np.sin(2 * phase) * 0.25
        tremolo = 0.65 + 0.35 * np.sin(2 * np.pi * 26 * t)
        env = np.minimum(t / 0.08, 1.0) * (0.35 + 0.65 * (t / dur) ** 1.4) * np.where(t > dur - 0.06, (dur - t) / 0.06, 1.0)
        out = tone * tremolo * env
        for start, note in ((0.14, "E6"), (0.26, "G#6"), (0.37, "B6"), (0.45, "E7")):
            ma.mix_at(out, start, bell(ma.hz(note), 0.14, 24), 0.18)
        return out

    def orb():
        dur = 0.32
        n = int(sr * dur)
        t = ma.tt(dur)
        freq = np.geomspace(1500, 420, n)
        phase = 2 * np.pi * np.cumsum(freq) / sr
        zap = np.sin(phase + 1.4 * np.sin(2 * np.pi * 55 * t)) * ma.decay(n, 9)
        puff = ma.lowpass(noise(n), 0.45, 0.05) * ma.decay(n, 22)
        sparkle = bell(ma.hz("A6"), dur, 18) * 0.25
        return zap * 0.85 + puff * 0.5 + sparkle

    def pop():
        dur = 0.22
        n = int(sr * dur)
        crack = ma.lowpass(noise(n), 0.7, 0.2) * ma.decay(n, 70)
        return bell(ma.hz("A6"), dur, 22) * 0.7 + bell(ma.hz("E7"), dur, 30) * 0.45 + crack * 0.45

    def spit():
        dur = 0.38
        n = int(sr * dur)
        t = ma.tt(dur)
        # nat gespetter: ruis die dichtgaat en een bubbel die omlaag glijdt
        splat = ma.lowpass(noise(n), 0.6, 0.06) * ma.decay(n, 11)
        freq = np.geomspace(720, 190, n)
        phase = 2 * np.pi * np.cumsum(freq) / sr
        bubble = np.sin(phase) * (0.6 + 0.4 * np.sin(2 * np.pi * 38 * t)) * ma.decay(n, 8)
        out = splat * 0.8 + bubble * 0.7
        for start, f in ((0.12, 520), (0.2, 400)):
            m = int(sr * 0.08)
            ma.mix_at(out, start, ma.chirp(f, f * 0.55, 0.08) * ma.decay(m, 30), 0.35)
        return out

    def hop():
        dur = 0.26
        n = int(sr * dur)
        t = ma.tt(dur)
        freq = np.concatenate([np.geomspace(150, 430, n // 2), np.geomspace(430, 240, n - n // 2)])
        phase = 2 * np.pi * np.cumsum(freq) / sr
        boing = np.sin(phase + 0.9 * np.sin(2 * np.pi * 21 * t)) * ma.decay(n, 7)
        squelch = ma.lowpass(noise(n), 0.4, 0.05) * ma.decay(n, 30)
        return boing * 0.9 + squelch * 0.35

    for name, fn in (("mage_teleport", teleport), ("mage_charge", charge), ("mage_orb", orb),
                     ("mage_orb_pop", pop), ("spitter_spit", spit), ("spitter_hop", hop)):
        ma.save(name, fn(), 0.8)
