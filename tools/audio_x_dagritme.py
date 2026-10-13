"""Uitbreiding "dagritme": achtergrondsfeer die meebeweegt met de klok, per klimaat.

Drie klimaten (bos, sneeuw, dorst) x vier dagdelen (ochtend, dag, avond, nacht) = twaalf naadloze
lussen van elk 6 seconden. De wereld kiest er een op basis van het weer van de kaart en het dagdeel
(zie Daynight.ambience en scripts/entities/atmosphere.gd).

  amb_bos_*      gematigd: vogels in de ochtend, ritselend blad overdag, krekels in avond en nacht,
                 een uil diep in de nacht
  amb_sneeuw_*   koud: wind in steeds andere golvingen; 's nachts dieper, met een verre uil
  amb_dorst_*    heet: 's middags een droge wind met insectengespin, 's avonds en 's nachts krekels

Elk geluid krijgt zijn eigen toevalsgenerator, zodat het resultaat altijd gelijk is.
"""
import numpy as np

LOOP_SECONDS = 6.0


def generate(ma):
    loops = {
        "amb_bos_ochtend": bos_ochtend, "amb_bos_dag": bos_dag,
        "amb_bos_avond": bos_avond, "amb_bos_nacht": bos_nacht,
        "amb_sneeuw_ochtend": lambda ma: sneeuw(ma, 11, 0.5, 3),   # frisse bries
        "amb_sneeuw_dag": lambda ma: sneeuw(ma, 13, 0.7, 4),       # gestage wind
        "amb_sneeuw_avond": lambda ma: sneeuw(ma, 17, 0.9, 5),     # opstekende wind
        "amb_sneeuw_nacht": lambda ma: sneeuw(ma, 19, 0.8, 3, met_uil=True),
        "amb_dorst_ochtend": dorst_ochtend, "amb_dorst_dag": dorst_dag,
        "amb_dorst_avond": dorst_avond, "amb_dorst_nacht": dorst_nacht,
    }
    for name, fn in loops.items():
        ma.save(name, fn(ma), 0.55, fade=False)  # een lus: niet in- of uitfaden


# --- bouwstenen ----------------------------------------------------------------

def _roll_quiet(out):
    """Begin de lus bij een nuldoorgang, zodat de naad onhoorbaar is (zoals bij wereld_regen)."""
    quiet = np.argmin(np.abs(out[1:]) + np.abs(out[:-1]))
    return np.roll(out, -(quiet + 1))


def wind(ma, rng, cutoff, strength, swells):
    """Wind als gefilterde ruis met een paar rustige golven per lus (naadloos door de cirkel-fft)."""
    n = int(ma.SR * LOOP_SECONDS)
    freqs = np.fft.rfftfreq(n, 1 / ma.SR)
    spectrum = np.fft.rfft(rng.standard_normal(n))
    band = 1.0 / (1.0 + (freqs / cutoff) ** 3)  # alles boven de afsnijding valt steil weg
    out = np.fft.irfft(spectrum * band, n)
    out /= np.abs(out).max()
    phase = rng.uniform(0, 2 * np.pi)
    swell = 1.0 + 0.35 * np.sin(2 * np.pi * np.arange(n) / n * swells + phase)
    return out * swell * strength


def bird(ma, rng, at):
    """Een vogelroep: twee tot vier snelle glijdende tonen, hoog en helder."""
    out = np.zeros(int(ma.SR * 0.9))
    t = 0.0
    for _ in range(rng.integers(2, 5)):
        f0 = rng.uniform(2200, 3400)
        f1 = f0 * rng.choice([0.7, 1.3, 1.5])
        dur = rng.uniform(0.07, 0.14)
        chirp = ma.chirp(f0, f1, dur) * np.sin(np.pi * np.arange(int(ma.SR * dur)) / (ma.SR * dur))
        ma.mix_at(out, t, chirp, 0.5)
        t += dur + rng.uniform(0.03, 0.09)
    return at, out


def cricket(ma, rng, at):
    """Een krekel: een hoge toon in snelle pulsen, een halve tot een hele seconde lang."""
    dur = rng.uniform(0.4, 0.9)
    n = int(ma.SR * dur)
    f = rng.uniform(3900, 4500)
    pulses = np.abs(np.sin(2 * np.pi * rng.uniform(16, 22) * np.arange(n) / ma.SR)) ** 0.4
    tone = np.sin(2 * np.pi * f * np.arange(n) / ma.SR) * pulses
    tone *= np.sin(np.pi * np.arange(n) / n)  # zacht op- en afbloeien
    return at, tone * 0.4


def owl(ma, rng, at):
    """Een uil: twee zachte, lage roepen met een beetje trilling."""
    out = np.zeros(int(ma.SR * 1.4))
    for i, dur in enumerate([0.28, 0.5]):
        n = int(ma.SR * dur)
        f = rng.uniform(330, 390)
        vib = 1.0 + 0.012 * np.sin(2 * np.pi * 5.5 * np.arange(n) / ma.SR)
        tone = np.sin(2 * np.pi * f * np.cumsum(vib) / ma.SR)
        tone *= np.sin(np.pi * np.arange(n) / n) ** 0.7
        ma.mix_at(out, i * 0.55, tone, 0.5)
    return at, out


def shimmer(ma, rng):
    """Insectengespin op het heetst van de dag: een hoge, fladderende ruis."""
    n = int(ma.SR * LOOP_SECONDS)
    freqs = np.fft.rfftfreq(n, 1 / ma.SR)
    spectrum = np.fft.rfft(rng.standard_normal(n))
    band = 1.0 / (1.0 + (5000.0 / np.maximum(freqs, 1.0)) ** 6) / (1.0 + (freqs / 9000.0) ** 2)
    out = np.fft.irfft(spectrum * band, n)
    out /= np.abs(out).max()
    flutter = np.abs(np.sin(2 * np.pi * 9 * np.arange(n) / ma.SR)) ** 0.5 * 0.7 + 0.3
    return out * flutter * 0.35


def sprinkle(ma, base, makers):
    """Meng losse geluidjes (vogels, krekels, uilen) door de lus, ook over de naad heen."""
    for at, sig in makers:
        ma.mix_at(base, at, sig, 1.0, wrap=True)
    return base


# --- bos (gematigd klimaat) ------------------------------------------------------

def bos_ochtend(ma):
    rng = np.random.default_rng(101)
    base = wind(ma, rng, 500, 0.5, 2)
    makers = [bird(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(6)]
    return _roll_quiet(sprinkle(ma, base, makers))


def bos_dag(ma):
    rng = np.random.default_rng(103)
    base = wind(ma, rng, 900, 0.75, 3)  # meer bladgeritsel
    makers = [bird(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(2)]
    return _roll_quiet(sprinkle(ma, base, makers))


def bos_avond(ma):
    rng = np.random.default_rng(107)
    base = wind(ma, rng, 450, 0.45, 2)
    makers = [cricket(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(3)]
    makers.append(bird(ma, rng, rng.uniform(0, LOOP_SECONDS)))
    return _roll_quiet(sprinkle(ma, base, makers))


def bos_nacht(ma):
    rng = np.random.default_rng(109)
    base = wind(ma, rng, 300, 0.35, 2)
    makers = [cricket(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(4)]
    makers.append(owl(ma, rng, rng.uniform(0, LOOP_SECONDS)))
    return _roll_quiet(sprinkle(ma, base, makers))


# --- sneeuw (koud klimaat) ---------------------------------------------------------

def sneeuw(ma, seed, strength, swells, met_uil=False):
    rng = np.random.default_rng(seed)
    base = wind(ma, rng, 380 if not met_uil else 220, strength, swells)
    makers = [owl(ma, rng, rng.uniform(0, LOOP_SECONDS))] if met_uil else []
    for at, sig in makers:  # de uil klinkt ver weg
        ma.mix_at(base, at, sig, 0.4, wrap=True)
    return _roll_quiet(base)


# --- dorst (heet klimaat) -----------------------------------------------------------

def dorst_ochtend(ma):
    rng = np.random.default_rng(131)
    base = wind(ma, rng, 600, 0.4, 2)
    makers = [bird(ma, rng, rng.uniform(0, LOOP_SECONDS))]
    return _roll_quiet(sprinkle(ma, base, makers))


def dorst_dag(ma):
    rng = np.random.default_rng(137)
    base = wind(ma, rng, 1400, 0.55, 3)  # droge, schrale wind
    return _roll_quiet(base + shimmer(ma, rng))


def dorst_avond(ma):
    rng = np.random.default_rng(139)
    base = wind(ma, rng, 500, 0.4, 2)
    makers = [cricket(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(3)]
    return _roll_quiet(sprinkle(ma, base, makers))


def dorst_nacht(ma):
    rng = np.random.default_rng(149)
    base = wind(ma, rng, 260, 0.3, 2)
    makers = [cricket(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(2)]
    return _roll_quiet(sprinkle(ma, base, makers))
