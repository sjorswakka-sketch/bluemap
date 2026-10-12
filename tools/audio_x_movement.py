"""Zachte voetstappen per ondergrond, volledig gesynthetiseerd en vrij te delen."""
import numpy as np


def step(ma, surface, seed):
    rng = np.random.default_rng(seed)
    t = ma.tt(0.19)
    n = len(t)
    noise = rng.uniform(-1, 1, n)
    soft = ma.lowpass(noise, 0.12, 0.025)
    grit = noise - ma.lowpass(noise, 0.5, 0.3)
    impact = np.sin(2 * np.pi * 110 * t) * np.exp(-t * 70)
    heel = np.minimum(t / 0.003, 1.0) * np.exp(-t * 34)
    scuff = np.sin(np.minimum(t / 0.18, 1.0) * np.pi) ** 2
    if surface == "grass":
        return impact * 0.2 * heel + soft * 0.8 * heel + grit * 0.15 * scuff
    if surface == "path":
        return impact * 0.45 * heel + noise * 0.7 * heel + grit * 0.2 * scuff
    if surface == "sand":
        return soft * 1.2 * scuff + grit * 0.18 * scuff + impact * 0.12 * heel
    if surface == "wood":
        resonance = (np.sin(2 * np.pi * 240 * t) + 0.4 * np.sin(2 * np.pi * 620 * t)) * heel
        return resonance * 0.3 + noise * heel * 0.4
    if surface == "cloth":
        return soft * heel + impact * heel * 0.18
    if surface == "snow":
        # knarsende sneeuw: veel korrel, zachte aanzet
        crunch = grit * heel * 0.9 + soft * 0.7 * heel
        squeak = np.sin(2 * np.pi * 900 * t) * np.exp(-t * 90) * 0.08
        return crunch + squeak
    return impact * heel * 0.5 + noise * np.exp(-t * 100) + grit * heel * 0.1


def generate(ma):
    for i, surface in enumerate(("grass", "path", "sand", "wood", "stone", "cloth", "snow")):
        ma.save("step_" + surface, step(ma, surface, 810 + i), 0.45)


if __name__ == "__main__":
    import make_audio
    generate(make_audio)
