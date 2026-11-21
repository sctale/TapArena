# -*- coding: utf-8 -*-
"""TapArena 攻击音效合成器 —— 25 位英雄各一条普攻音效。

规矩（AGENTS.md §102）：音效必须自制或运行时合成，不引第三方素材。
这里全部用 numpy 现场合成，输出 48kHz / 单声道 / 16-bit PCM。

音色按武器与角色体型分七类：
  slash  利爪/刀刃挥空（虎、猫、狼）        thud   重击闷响（熊、龟）
  wood   竹木敲击（团团）                  magic  法杖光弹（灵灵、朵朵、咕咕、绒绒、小白）
  water  水弹/水鞭（泡泡、绒绒备选）        bow    弓弦弹射（尖尖、角角）
  fire   火焰斩（火火）                    stab   快速刺击（刺刺）
"""
import math
import pathlib
import shutil
import struct
import wave

import numpy as np

SR = 48000
OUT = pathlib.Path(__file__).resolve().parent / "atk"
ASSETS = pathlib.Path(__file__).resolve().parents[2] / "godot" / "assets" / "audio" / "atk"


def _env(n, attack=0.004, decay=6.0):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / max(attack, 1e-4))
    return a * np.exp(-t * decay)


def _band_noise(n, lo, hi, rng):
    spec = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    mask = (freqs >= lo) & (freqs <= hi)
    spec[~mask] = 0
    out = np.fft.irfft(spec, n)
    m = np.max(np.abs(out)) or 1.0
    return out / m


def slash(rng, dur=0.26, lo=1800, hi=7200, tone=0.18):
    n = int(SR * dur)
    body = _band_noise(n, lo, hi, rng) * _env(n, 0.003, 16)
    swoosh = _band_noise(n, 400, 1600, rng) * _env(n, 0.012, 9) * 0.55
    click = np.zeros(n)
    k = int(SR * 0.004)
    click[:k] = rng.standard_normal(k) * np.linspace(1, 0, k) * tone
    x = body + swoosh + click
    return x


def thud(rng, dur=0.42, f0=78.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    sweep = f0 * (1.0 + 0.9 * np.exp(-t * 26))
    thump = np.sin(2 * np.pi * np.cumsum(sweep) / SR) * np.exp(-t * 9)
    grit = _band_noise(n, 120, 900, rng) * np.exp(-t * 22) * 0.45
    return thump + grit


def wood(rng, dur=0.22):
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f, g, d in ((880.0, 1.0, 26), (1320.0, 0.55, 34), (2480.0, 0.25, 44)):
        x += g * np.sin(2 * np.pi * f * t) * np.exp(-t * d)
    x += _band_noise(n, 1500, 6000, rng) * np.exp(-t * 40) * 0.3
    return x


def magic(rng, dur=0.34, base=760.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * base * 3.1 * t) * 2.4 * np.exp(-t * 7)
    x = np.sin(2 * np.pi * base * t + mod) * np.exp(-t * 8)
    x += _band_noise(n, 3000, 11000, rng) * np.exp(-t * 14) * 0.35
    return x


def water(rng, dur=0.30):
    n = int(SR * dur)
    t = np.arange(n) / SR
    bubble = _band_noise(n, 300, 3000, rng)
    am = 0.5 + 0.5 * np.sin(2 * np.pi * 26 * t)
    return bubble * am * np.exp(-t * 11)


def bow(rng, dur=0.30, f0=196.0):
    n = int(SR * dur)
    # Karplus-Strong 拨弦
    buf = rng.standard_normal(int(SR / f0))
    out = np.zeros(n)
    idx = 0
    for i in range(n):
        out[i] = buf[idx]
        buf[idx] = 0.5 * (buf[idx] + buf[(idx + 1) % len(buf)]) * 0.996
        idx = (idx + 1) % len(buf)
    out *= np.exp(-np.arange(n) / SR * 7)
    out += _band_noise(n, 2000, 9000, rng) * np.exp(-np.arange(n) / SR * 26) * 0.5
    return out


def fire(rng, dur=0.34):
    n = int(SR * dur)
    t = np.arange(n) / SR
    body = _band_noise(n, 200, 4200, rng) * np.exp(-t * 6)
    crack = np.zeros(n)
    for _ in range(9):
        p = rng.integers(0, n - 400)
        crack[p:p + 320] += rng.standard_normal(320) * np.exp(-np.arange(320) / 60) * 0.5
    return body + crack


def stab(rng, dur=0.18):
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = _band_noise(n, 4000, 14000, rng) * np.exp(-t * 34)
    x += np.sin(2 * np.pi * 1900 * t) * np.exp(-t * 40) * 0.3
    return x


# hero_id -> (音色, 参数)
RECIPES = {
    "tiger":     ("slash", dict(lo=1500, hi=6500, tone=0.22)),
    "fox":       ("magic", dict(base=820.0)),
    "rabbit":    ("magic", dict(base=1040.0)),
    "bear":      ("thud", dict(f0=62.0)),
    "frog":      ("water", {}),
    "cat":       ("slash", dict(lo=2600, hi=9500, tone=0.3)),
    "panda":     ("wood", {}),
    "owl":       ("slash", dict(lo=900, hi=3600, tone=0.12)),
    "axolotl":   ("water", {}),
    "deer":      ("bow", dict(f0=220.0)),
    "turtle":    ("thud", dict(f0=52.0)),
    "hedgehog":  ("stab", {}),
    "redpanda":  ("fire", {}),
    "wolf":      ("slash", dict(lo=1200, hi=5200, tone=0.2)),
    "crane":     ("slash", dict(lo=2000, hi=8000, tone=0.1)),
    "monkey":    ("slash", dict(lo=1200, hi=6000, tone=0.2)),
    "elephant":  ("thud", dict(f0=48.0)),
    "penguin":   ("magic", dict(base=1180.0)),
    "sheep":     ("magic", dict(base=660.0)),
    "bat":       ("slash", dict(lo=3000, hi=12000, tone=0.12)),
    "croc":      ("thud", dict(f0=58.0)),
    "giraffe":   ("magic", dict(base=930.0)),
    "raccoon":   ("slash", dict(lo=2200, hi=8800, tone=0.16)),
    "koala":     ("wood", {}),
    "peacock":   ("magic", dict(base=1120.0)),
}

FUNCS = {"slash": slash, "thud": thud, "wood": wood, "magic": magic,
         "water": water, "bow": bow, "fire": fire, "stab": stab}


def write_wav(path: pathlib.Path, x: np.ndarray):
    peak = float(np.max(np.abs(x))) or 1.0
    x = x / peak * 0.70  # 留 3 dB 余量，游戏内统一走总线增益
    n = len(x)
    fade = min(int(SR * 0.004), n // 4)
    if fade > 0:
        ramp = np.linspace(0, 1, fade)
        x[:fade] *= ramp
        x[-fade:] *= ramp[::-1]
    data = np.clip(x, -1, 1)
    pcm = (data * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lines = []
    for i, (hid, (kind, kw)) in enumerate(RECIPES.items()):
        rng = np.random.default_rng(1000 + i)
        x = FUNCS[kind](rng, **kw)
        p = OUT / f"atk_{hid}.wav"
        write_wav(p, x)
        lines.append(f"  {p.name:22s} {kind:6s} {len(x)/SR:.2f}s")
    print("\n".join(lines))
    print(f"共 {len(RECIPES)} 条 → {OUT}")
    # 直接覆盖游戏资产，避免生成在 tools/audio/atk 却忘记拷贝。
    ASSETS.mkdir(parents=True, exist_ok=True)
    for wav in OUT.glob("atk_*.wav"):
        shutil.copy2(wav, ASSETS / wav.name)
    print(f"已同步游戏资产 {ASSETS}")


if __name__ == "__main__":
    main()
