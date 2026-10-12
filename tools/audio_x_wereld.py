"""Uitbreiding "wereld": regen (een lus), een slaapliedje, een prestatie-geluidje, snel reizen en een ontdekt altaar.

  wereld_regen       zachte regen, een naadloze lus van 6 seconden
  wereld_slapen      kort slaapliedje op een speeldoos
  wereld_prestatie   vrolijk deuntje bij een behaalde prestatie
  wereld_reis        zoevend geluid bij snel reizen
  wereld_altaar      heldere klank als je een altaar voor het eerst gebruikt

Elk geluid krijgt zijn eigen toevalsgenerator, zodat het resultaat altijd gelijk is, ook als andere uitbreidingen
of volgordes veranderen.
"""
import numpy as np

LOOP_SECONDS = 6.0


def generate(ma):
    ma.save("wereld_regen", rain_loop(ma), 0.7, fade=False)  # een lus: niet in- of uitfaden
    ma.save("wereld_slapen", lullaby(ma), 0.7)
    ma.save("wereld_prestatie", achievement(ma), 0.8)
    ma.save("wereld_reis", travel(ma), 0.8)
    ma.save("wereld_altaar", altar(ma), 0.8)


def rain_loop(ma):
    """Ruis die met een filter in de frequentieruimte tot regen wordt gevormd. Omdat het filter de hele lus als
    een cirkel behandelt, sluiten begin en einde precies op elkaar aan."""
    rng = np.random.default_rng(31)
    n = int(ma.SR * LOOP_SECONDS)
    freqs = np.fft.rfftfreq(n, 1 / ma.SR)
    spectrum = np.fft.rfft(rng.standard_normal(n))
    # Een zachte band tussen ongeveer 700 Hz en 8 kHz, naar hoge tonen toe wat zachter (zoals echte regen).
    band = 1.0 / (1.0 + (700.0 / np.maximum(freqs, 1.0)) ** 3) / (1.0 + (freqs / 8000.0) ** 4)
    hiss = np.fft.irfft(spectrum * band / np.sqrt(np.maximum(freqs, 300.0) / 300.0), n)
    hiss /= np.abs(hiss).max()
    # Een diepe, rustige ruis eronder, als regen op bladeren in de verte.
    low_spec = np.fft.rfft(rng.standard_normal(n)) / (1.0 + (freqs / 220.0) ** 2) * (freqs / 90.0) ** 2 / (1.0 + (freqs / 90.0) ** 2)
    low = np.fft.irfft(low_spec, n)
    low /= np.abs(low).max()
    # Losse druppels: heel korte tikjes met wisselende hoogte en sterkte, ook over de naad heen.
    drops = np.zeros(n)
    for _ in range(int(LOOP_SECONDS * 140)):
        start = rng.uniform(0, LOOP_SECONDS)
        length = int(ma.SR * rng.uniform(0.002, 0.006))
        tick = rng.standard_normal(length) * np.exp(-np.arange(length) / (length / 3.0))
        ma.mix_at(drops, start, tick, rng.uniform(0.05, 0.4) ** 1.5, wrap=True)
    swell = 1.0 + 0.12 * np.sin(2 * np.pi * np.arange(n) / n * 3 + 1.0)  # drie rustige golven per lus
    out = (hiss * 0.55 + low * 0.2 + drops * 0.5) * swell
    # Begin de lus bij een nuldoorgang, zodat het laatste monster bijna stil is (check_audio let daarop).
    quiet = np.argmin(np.abs(out[1:]) + np.abs(out[:-1]))
    return np.roll(out, -(quiet + 1))


def lullaby(ma):
    """Een speeldoos: vijf zachte noten die wiegen, en een lange laatste klank."""
    out = np.zeros(int(ma.SR * 3.4))
    notes = [("E5", 0.0), ("G5", 0.42), ("C6", 0.84), ("G5", 1.34), ("E5", 1.76)]
    for name, at in notes:
        f = ma.hz(name)
        tone = ma.note_blip(f, 0.9, "sin", 4.5) + 0.35 * ma.note_blip(f * 2, 0.9, "sin", 7) + 0.12 * ma.note_blip(f * 3, 0.9, "sin", 10)
        ma.mix_at(out, at, tone, 0.5)
    for name in ("C4", "E4", "G4"):
        ma.mix_at(out, 2.2, ma.note_blip(ma.hz(name), 1.2, "tri", 2.2), 0.3)
    ma.mix_at(out, 2.2, ma.note_blip(ma.hz("C6"), 1.2, "sin", 3.0), 0.25)
    return out


def achievement(ma):
    """Een vrolijk stijgend akkoord met glinsteringen erachter."""
    out = np.zeros(int(ma.SR * 1.8))
    for i, name in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        ma.mix_at(out, i * 0.075, ma.note_blip(ma.hz(name), 0.5, "sq", 9), 0.34)
        ma.mix_at(out, i * 0.075, ma.note_blip(ma.hz(name), 0.7, "sin", 5), 0.45)
    for name in ("C5", "G5", "C6", "E6", "G6"):
        ma.mix_at(out, 0.42, ma.note_blip(ma.hz(name), 1.2, "tri", 2.6), 0.32)
    for i, name in enumerate(["C7", "G6", "E7", "C7"]):
        ma.mix_at(out, 0.7 + i * 0.1, ma.echo(ma.note_blip(ma.hz(name), 0.2, "sin", 14), 0.12, 0.45, 3), 0.22)
    return out


def travel(ma):
    """Een zoevend 'verdwijnen': ruis die stijgt, een glijdende toon en een helder klokje bij aankomst."""
    rng = np.random.default_rng(47)
    n = int(ma.SR * 0.9)
    t = np.arange(n) / ma.SR
    noise = ma.lowpass(rng.uniform(-1, 1, n), 0.04, 0.5) * np.sin(np.pi * np.minimum(t / 0.9, 1.0)) ** 1.5
    glide = ma.chirp(220, 1320, 0.9) * np.sin(np.pi * np.minimum(t / 0.9, 1.0)) ** 1.2
    out = noise * 0.7 + glide * 0.5
    out = np.concatenate([out, np.zeros(int(ma.SR * 0.5))])
    for i, name in enumerate(["E6", "B6"]):
        ma.mix_at(out, 0.7 + i * 0.09, ma.note_blip(ma.hz(name), 0.5, "sin", 7), 0.55)
    return out


def altar(ma):
    """Een heldere kristalklank, een beetje als het opslaan, maar hoger en met een galm."""
    out = np.zeros(int(ma.SR * 1.6))
    for i, name in enumerate(["E5", "B5", "E6", "G#6"]):
        tone = ma.note_blip(ma.hz(name), 0.9, "sin", 4) + 0.3 * ma.note_blip(ma.hz(name) * 2, 0.9, "sin", 7)
        ma.mix_at(out, i * 0.14, ma.echo(tone, 0.16, 0.4, 3), 0.42)
    return out
