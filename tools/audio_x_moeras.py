"""Uitbreiding "moeras": achtergrondsfeer voor Het Kruipmoeras, per dagdeel.

Vier naadloze lussen van 6 seconden (amb_moeras_ochtend/dag/avond/nacht). De wereld kiest er een
op basis van het weer "swamp" en het dagdeel (zie Daynight.ambience en scripts/entities/atmosphere.gd).

  ochtend  zacht watergekabbel, een enkele vogel, de eerste kikkers
  dag      insectengespin boven het drijfmest, kikkers op de achtergrond
  avond    krekels en volle kikkerkoortjes
  nacht    diepe kikkerbastonen tussen de krekels, ver kabbelend water

Hergebruikt de bouwstenen van audio_x_dagritme (wind, cricket, bird, sprinkle, _roll_quiet).
Elk geluid krijgt zijn eigen toevalsgenerator, zodat het resultaat altijd gelijk is.
"""
import numpy as np

from audio_x_dagritme import LOOP_SECONDS, _roll_quiet, bird, cricket, sprinkle, wind


def generate(ma):
    loops = {
        "amb_moeras_ochtend": moeras_ochtend,
        "amb_moeras_dag": moeras_dag,
        "amb_moeras_avond": moeras_avond,
        "amb_moeras_nacht": moeras_nacht,
    }
    for name, fn in loops.items():
        ma.save(name, fn(ma), 0.55, fade=False)  # een lus: niet in- of uitfaden


# --- bouwstenen ----------------------------------------------------------------

def kikker(ma, rng, at, laag=False):
    """Een kikkerkwaak: een lage, brommende toon, vaak twee keer achter elkaar ("kwa-kwa")."""
    f = rng.uniform(120, 220) if laag else rng.uniform(180, 320)
    reps = int(rng.integers(1, 4))
    out = np.zeros(int(ma.SR * (reps * 0.34 + 0.2)))
    t = 0.0
    for _ in range(reps):
        dur = rng.uniform(0.14, 0.24)
        n = int(ma.SR * dur)
        # bromming: amplitudemodulatie op een glijdende sinus
        brom = 0.55 + 0.45 * np.sin(2 * np.pi * rng.uniform(28, 40) * np.arange(n) / ma.SR)
        tone = ma.chirp(f, f * rng.uniform(0.75, 0.9), dur) * brom
        tone *= np.sin(np.pi * np.arange(n) / n) ** 0.6  # zacht op- en afbloeien
        ma.mix_at(out, t, tone, 0.5)
        t += dur + rng.uniform(0.06, 0.12)
    return at, out


def kabbel(ma, rng, cutoff=240, strength=0.4, swells=2):
    """Laag watergekabbel: diep gefilterde ruis met langzame golven, plus een paar belletjes."""
    base = wind(ma, rng, cutoff, strength, swells)
    n = int(ma.SR * LOOP_SECONDS)
    for _ in range(rng.integers(2, 5)):
        f0 = rng.uniform(500, 900)
        dur = rng.uniform(0.03, 0.07)
        plop = ma.chirp(f0, f0 * 0.45, dur)
        plop *= np.sin(np.pi * np.arange(int(ma.SR * dur)) / (ma.SR * dur)) ** 1.5
        ma.mix_at(base, rng.uniform(0, LOOP_SECONDS), plop, 0.25, wrap=True)
    return base[:n]


def insect(ma, rng):
    """Zoemende insecten boven het drijfmest: een middelhoge, langzaam fladderende toonlaag."""
    n = int(ma.SR * LOOP_SECONDS)
    t = np.arange(n) / ma.SR
    f = 320.0
    zoem = np.sin(2 * np.pi * f * t) * 0.5 + np.sin(2 * np.pi * f * 1.5 * t) * 0.25
    fladder = np.abs(np.sin(2 * np.pi * 13 * t)) ** 0.7 * 0.6 + 0.25
    langzaam = 1.0 + 0.3 * np.sin(2 * np.pi * t / LOOP_SECONDS * 3 + rng.uniform(0, 2 * np.pi))
    return zoem * fladder * langzaam * 0.16


# --- de vier dagdelen ------------------------------------------------------------

def moeras_ochtend(ma):
    rng = np.random.default_rng(211)
    base = kabbel(ma, rng, 260, 0.45, 2)
    makers = [kikker(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(2)]
    makers.append(bird(ma, rng, rng.uniform(0, LOOP_SECONDS)))
    return _roll_quiet(sprinkle(ma, base, makers))


def moeras_dag(ma):
    rng = np.random.default_rng(223)
    base = kabbel(ma, rng, 300, 0.4, 3) + insect(ma, rng)
    makers = [kikker(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(3)]
    return _roll_quiet(sprinkle(ma, base, makers))


def moeras_avond(ma):
    rng = np.random.default_rng(227)
    base = kabbel(ma, rng, 220, 0.35, 2)
    makers = [cricket(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(3)]
    makers += [kikker(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(4)]
    return _roll_quiet(sprinkle(ma, base, makers))


def moeras_nacht(ma):
    rng = np.random.default_rng(229)
    base = kabbel(ma, rng, 180, 0.3, 2)
    makers = [cricket(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(3)]
    makers += [kikker(ma, rng, rng.uniform(0, LOOP_SECONDS)) for _ in range(3)]
    makers += [kikker(ma, rng, rng.uniform(0, LOOP_SECONDS), laag=True) for _ in range(2)]
    return _roll_quiet(sprinkle(ma, base, makers))
