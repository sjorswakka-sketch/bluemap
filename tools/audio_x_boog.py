"""Uitbreiding "boog": het geluid van de pijl die wordt afgeschoten en van een raak doelwit."""
import numpy as np


def sfx_twang(ma):
    """Een gespannen pees die loslaat: een korte klap, een zakkende toon met boventonen en een zachte zoef van de pijl."""
    rng = np.random.default_rng(31)
    dur = 0.34
    n = int(ma.SR * dur)
    t = ma.tt(dur)
    # De toon begint wat hoger en zakt snel (de pees komt tot rust).
    freq = 175.0 * (1.0 + 0.22 * np.exp(-t / 0.045))
    phase = 2 * np.pi * np.cumsum(freq) / ma.SR
    string = (np.sin(phase) + 0.55 * np.sin(2 * phase) + 0.3 * np.sin(3 * phase) + 0.15 * np.sin(5 * phase)) * ma.decay(n, 13.0, 0.002)
    slap = ma.lowpass(rng.uniform(-1, 1, n), 0.85, 0.2) * ma.decay(n, 90.0, 0.0005)
    whoosh_env = np.sin(np.clip(t / 0.22, 0.0, 1.0) * np.pi) ** 1.5 * (t < 0.22)
    whoosh = ma.lowpass(rng.uniform(-1, 1, n), 0.06, 0.45) * whoosh_env
    return string * 0.8 + slap * 0.55 + whoosh * 0.28


def sfx_target(ma):
    """Een houten klap met een heldere pling erachteraan: raak!"""
    rng = np.random.default_rng(32)
    dur = 0.8
    n = int(ma.SR * dur)
    t = ma.tt(dur)
    thock = ma.chirp(330, 110, 0.12) * ma.decay(int(ma.SR * 0.12), 22.0)
    crack = ma.lowpass(rng.uniform(-1, 1, int(ma.SR * 0.06)), 0.5, 0.15) * ma.decay(int(ma.SR * 0.06), 60.0)
    out = np.zeros(n)
    out[:len(thock)] += thock * 0.9
    out[:len(crack)] += crack * 0.5
    # De pling: een klokje met onzuivere boventonen, een tel na de klap.
    ring = np.zeros(n)
    for ratio, gain, rate in ((1.0, 1.0, 5.5), (2.76, 0.45, 9.0), (5.4, 0.22, 16.0)):
        ring += np.sin(2 * np.pi * ma.hz("E6") * ratio * t) * gain * np.exp(-t * rate)
    ma.mix_at(out, 0.025, ring[:n - int(0.025 * ma.SR)] * np.minimum(t[:n - int(0.025 * ma.SR)] / 0.003, 1.0), 0.75)
    return out


def generate(ma):
    ma.save("boog_twang", sfx_twang(ma), 0.8)
    ma.save("boog_target", sfx_target(ma), 0.8)
