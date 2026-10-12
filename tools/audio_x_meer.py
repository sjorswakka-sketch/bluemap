"""Uitbreiding "meer" (het Zilvermeer): geluiden voor het vissen en de bibliotheek, en de rustige muziek van het meer.

make_audio.py laadt dit bestand vanzelf en roept generate(ma) aan; `ma` is make_audio zelf (save, tri, compose...).
De ruis komt uit een eigen generator, zodat de bestaande geluiden niet kunnen veranderen.
"""
import numpy as np


def generate(ma):
    rng = np.random.default_rng(1138)
    sr = ma.SR

    def noise(n):
        return rng.uniform(-1, 1, n)

    def highpass(x, c):
        return x - ma.lowpass(x, c, c)

    def plip(f0, f1, dur, rate):
        """Een kort waterdruppelgeluid: een toon die snel omhoog glijdt."""
        return ma.chirp(f0, f1, dur) * ma.decay(int(sr * dur), rate)

    # --- vissen ---------------------------------------------------------------------------------------

    def sfx_plons():
        """Dobber valt in het water: gespetter en een luchtbel."""
        out = np.zeros(int(sr * 0.55))
        n = len(out)
        out += ma.lowpass(noise(n), 0.4, 0.04) * ma.decay(n, 9) * 0.9
        ma.mix_at(out, 0.02, plip(160, 520, 0.2, 13), 0.8)
        ma.mix_at(out, 0.2, plip(260, 700, 0.12, 20), 0.35)
        return out

    def sfx_beet():
        """De dobber schiet omlaag: twee plopjes en een helder belletje."""
        out = np.zeros(int(sr * 0.6))
        ma.mix_at(out, 0.0, plip(380, 800, 0.09, 16), 0.8)
        ma.mix_at(out, 0.1, plip(420, 900, 0.09, 16), 0.8)
        for f in ("E6", "B6"):
            ma.mix_at(out, 0.2, ma.note_blip(ma.hz(f), 0.38, "sin", 9), 0.5)
        return out

    def sfx_haspel():
        """De molen van de hengel: een rij snelle klikjes (kort genoeg om te herhalen)."""
        out = np.zeros(int(sr * 0.36))
        for i in range(8):
            t0 = i * 0.042
            click = highpass(noise(int(sr * 0.012)), 0.3) * ma.decay(int(sr * 0.012), 160)
            tick = np.sin(2 * np.pi * (1500 - i * 40) * ma.tt(0.014)) * ma.decay(int(sr * 0.014), 140)
            ma.mix_at(out, t0, click, 0.8)
            ma.mix_at(out, t0, tick, 0.5)
        ma.mix_at(out, 0.0, ma.lowpass(noise(len(out)), 0.05, 0.05) * 0.12, 1.0)
        return out

    def sfx_vangst():
        """Gevangen! Een plons gevolgd door een vrolijk deuntje."""
        out = np.zeros(int(sr * 1.3))
        ma.mix_at(out, 0.0, ma.lowpass(noise(int(sr * 0.3)), 0.4, 0.05) * ma.decay(int(sr * 0.3), 12), 0.7)
        ma.mix_at(out, 0.0, plip(200, 600, 0.15, 14), 0.6)
        for i, name in enumerate(["C5", "E5", "G5", "C6"]):
            ma.mix_at(out, 0.18 + i * 0.1, ma.note_blip(ma.hz(name), 0.4, "tri", 5), 0.65)
        for name in ("G5", "C6", "E6"):
            ma.mix_at(out, 0.6, ma.note_blip(ma.hz(name), 0.7, "sin", 3.5), 0.4)
        return out

    def sfx_ontsnapt():
        """De vis schiet weg: een dalende plons."""
        out = np.zeros(int(sr * 0.5))
        ma.mix_at(out, 0.0, ma.chirp(700, 150, 0.3) * ma.decay(int(sr * 0.3), 9), 0.7)
        n = int(sr * 0.25)
        ma.mix_at(out, 0.05, ma.lowpass(noise(n), 0.3, 0.05) * ma.decay(n, 14), 0.5)
        return out

    # --- bibliotheek ----------------------------------------------------------------------------------

    def sfx_blad():
        """Een bladzijde die omslaat: ruis die zachtjes zwelt en dan afbreekt."""
        n = int(sr * 0.3)
        t = np.linspace(0, 1, n)
        swish = ma.lowpass(highpass(noise(n), 0.15), 0.6, 0.25) * (np.sin(np.pi * np.minimum(t * 1.4, 1.0)) ** 2) * (1 - t) ** 0.6
        out = np.zeros(n)
        out += swish
        ma.mix_at(out, 0.2, highpass(noise(int(sr * 0.03)), 0.3) * ma.decay(int(sr * 0.03), 90), 0.35)
        return out

    def sfx_kast():
        """De geheime kast schuift opzij: steen over steen, een bons en een belletje."""
        out = np.zeros(int(sr * 1.9))
        n = int(sr * 1.0)
        t = np.linspace(0, 1, n)
        rumble = ma.lowpass(noise(n), 0.07, 0.04) * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * t)) * np.sin(np.pi * t) ** 0.7
        ma.mix_at(out, 0.0, rumble, 1.0)
        ma.mix_at(out, 1.0, ma.chirp(120, 45, 0.3) * ma.decay(int(sr * 0.3), 9), 0.9)
        for i, name in enumerate(["B5", "E6"]):
            ma.mix_at(out, 1.15 + i * 0.12, ma.note_blip(ma.hz(name), 0.7, "sin", 4.0), 0.5)
        return out

    for name, fn in [("meer_plons", sfx_plons), ("meer_beet", sfx_beet), ("meer_haspel", sfx_haspel),
                     ("meer_vangst", sfx_vangst), ("meer_ontsnapt", sfx_ontsnapt),
                     ("meer_blad", sfx_blad), ("meer_kast", sfx_kast)]:
        ma.save(name, fn(), 0.8)

    # --- muziek: rustige lus voor het Zilvermeer --------------------------------------------------------

    g, em, c, d, am = (43, [55, 59, 62, 66]), (40, [52, 55, 59, 62]), (48, [52, 55, 59, 60]), (38, [54, 57, 62, 64]), (45, [57, 60, 64, 67])
    chords = [g, em, c, d, g, em, am, d, c, g, am, d]
    melody = [
        [("B4", 3), ("D5", 1), ("G5", 4)],
        [("E5", 2), ("D5", 2), ("B4", 4)],
        [("G4", 2), ("C5", 2), ("E5", 4)],
        [("F#5", 3), ("E5", 1), ("D5", 2), ("R", 2)],
        [("D5", 2), ("G5", 2), ("B5", 2), ("A5", 2)],
        [("G5", 3), ("E5", 1), ("D5", 4)],
        [("C5", 2), ("E5", 2), ("A5", 4)],
        [("G5", 2), ("F#5", 2), ("D5", 4)],
        [("E5", 2), ("G5", 2), ("E5", 2), ("C5", 2)],
        [("B4", 2), ("D5", 2), ("G5", 4)],
        [("A4", 2), ("C5", 2), ("E5", 2), ("D5", 2)],
        [("D5", 4), ("F#5", 2), ("R", 2)],
    ]
    music = ma.compose(70, chords, melody, pad_gain=0.28, pad_attack=1.0, bass_pattern=((0, 0), (4, 7)), bass_gain=0.38,
                       bass_rate=2.0, arp_pattern=(0, 1, 2, 3, 2, 1, 2, 3), arp_gain=0.12, arp_octave=12,
                       arp_echo=(0.3, 0.5, 3), lead_gain=0.34, lead_vibrato=0.1)
    ma.save("music_lake", music, 0.7, fade=False)
