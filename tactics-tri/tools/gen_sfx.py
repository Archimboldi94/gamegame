#!/usr/bin/env python3
"""Synthesize placeholder SFX/BGM as 44.1 kHz mono/stereo WAV, then encode to OGG Vorbis.

Output: res://audio/sfx/*.ogg and res://audio/bgm/*.ogg (ambience under sfx/).
Re-run anytime; safe to overwrite placeholders until real assets land.
"""

from __future__ import annotations

import math
import os
import struct
import subprocess
import sys
import wave

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
BGM_DIR = os.path.join(ROOT, "audio", "bgm")
TMP_DIR = os.path.join(ROOT, "audio", "_tmp_wav")


def clamp(x: float) -> float:
    return max(-1.0, min(1.0, x))


def env_adsr(i: int, n: int, a=0.01, d=0.08, s=0.55, r=0.2) -> float:
    t = i / max(1, n - 1)
    if t < a:
        return t / a
    if t < a + d:
        return 1.0 - (1.0 - s) * ((t - a) / d)
    if t > 1.0 - r:
        return s * (1.0 - (t - (1.0 - r)) / r)
    return s


def tone(freq: float, dur: float, amp=0.45, a=0.01, d=0.08, s=0.5, r=0.25, harm=(1.0,)) -> list[float]:
    n = max(1, int(SR * dur))
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for k, h in enumerate(harm, 1):
            v += h * math.sin(2 * math.pi * freq * k * t)
        v /= max(1.0, sum(abs(x) for x in harm))
        out.append(clamp(v * amp * env_adsr(i, n, a, d, s, r)))
    return out


def noise(dur: float, amp=0.35, a=0.005, d=0.05, s=0.3, r=0.4, color=0.0) -> list[float]:
    """color>0 softens (pinkish) via one-pole lowpass."""
    n = max(1, int(SR * dur))
    out = []
    y = 0.0
    # deterministic LCG so assets are reproducible
    state = 0xC0FFEE
    for i in range(n):
        state = (1103515245 * state + 12345) & 0x7FFFFFFF
        x = (state / 0x7FFFFFFF) * 2.0 - 1.0
        if color > 0.0:
            y = y + color * (x - y)
            x = y
        out.append(clamp(x * amp * env_adsr(i, n, a, d, s, r)))
    return out


def mix(*parts: list[float], delays: list[float] | None = None) -> list[float]:
    delays = delays or [0.0] * len(parts)
    ends = [int(d * SR) + len(p) for p, d in zip(parts, delays)]
    n = max(ends) if ends else 1
    out = [0.0] * n
    for p, d in zip(parts, delays):
        off = int(d * SR)
        for i, v in enumerate(p):
            out[off + i] = clamp(out[off + i] + v)
    return out


def fade_edges(samples: list[float], ms: float = 4.0) -> list[float]:
    n = len(samples)
    k = max(1, int(SR * ms / 1000.0))
    out = samples[:]
    for i in range(min(k, n)):
        out[i] *= i / k
        out[n - 1 - i] *= i / k
    return out


def write_wav(path: str, samples: list[float], stereo: bool = False) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = int(clamp(s) * 32767)
            if stereo:
                frames += struct.pack("<hh", v, v)
            else:
                frames += struct.pack("<h", v)
        w.writeframes(frames)


def to_ogg(wav_path: str, ogg_path: str) -> None:
    os.makedirs(os.path.dirname(ogg_path), exist_ok=True)
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", wav_path,
        "-ar", str(SR),
        "-c:a", "libvorbis", "-q:a", "4",
        ogg_path,
    ]
    subprocess.check_call(cmd)


def soft_loop(dur: float, base_freq: float, amp=0.12) -> list[float]:
    n = int(SR * dur)
    out = []
    state = 0xA11CE
    y = 0.0
    for i in range(n):
        t = i / SR
        state = (1103515245 * state + 12345) & 0x7FFFFFFF
        x = (state / 0x7FFFFFFF) * 2.0 - 1.0
        y = y + 0.02 * (x - y)
        # seamless-ish loop: envelope is flat; phase completes integer cycles
        pad = 0.55 + 0.45 * math.sin(2 * math.pi * base_freq * t)
        hum = 0.35 * math.sin(2 * math.pi * (base_freq * 0.5) * t)
        out.append(clamp((y * 0.55 + hum * 0.2) * amp * pad))
    # crossfade ends for looping
    xf = int(SR * 0.25)
    for i in range(xf):
        k = i / xf
        out[i] = out[i] * k + out[n - xf + i] * (1 - k)
    return out[: n - xf]


def build_all() -> dict[str, list[float]]:
    return {
        # UI
        "ui_tap": tone(880, 0.05, 0.28, a=0.002, d=0.03, s=0.2, r=0.4, harm=(1.0, 0.25)),
        "ui_confirm": mix(
            tone(523, 0.08, 0.35, a=0.005, d=0.04, s=0.4, r=0.5, harm=(1.0, 0.4)),
            tone(784, 0.12, 0.28, a=0.01, d=0.05, s=0.35, r=0.55, harm=(1.0, 0.3)),
            delays=[0.0, 0.05],
        ),
        "ui_cancel": tone(330, 0.09, 0.3, a=0.005, d=0.05, s=0.25, r=0.55, harm=(1.0, 0.15)),
        "unit_select": mix(
            tone(660, 0.07, 0.3, a=0.005, d=0.04, s=0.35, r=0.45),
            tone(990, 0.1, 0.22, a=0.01, d=0.05, s=0.3, r=0.5),
            delays=[0.0, 0.04],
        ),
        # Footsteps
        "move_step_grass": mix(
            noise(0.07, 0.22, a=0.002, d=0.03, s=0.25, r=0.55, color=0.35),
            tone(120, 0.05, 0.12, a=0.002, d=0.02, s=0.2, r=0.6),
        ),
        "move_step_stone": mix(
            noise(0.05, 0.28, a=0.001, d=0.02, s=0.15, r=0.5, color=0.15),
            tone(180, 0.04, 0.18, a=0.001, d=0.02, s=0.2, r=0.5),
        ),
        "move_step_water": mix(
            noise(0.1, 0.2, a=0.005, d=0.04, s=0.35, r=0.5, color=0.55),
            tone(220, 0.08, 0.1, a=0.01, d=0.04, s=0.3, r=0.5),
        ),
        # Attacks
        "atk_sword": mix(
            noise(0.06, 0.25, a=0.001, d=0.02, s=0.2, r=0.4, color=0.1),
            tone(740, 0.09, 0.32, a=0.002, d=0.03, s=0.25, r=0.45, harm=(1.0, 0.5, 0.2)),
        ),
        "atk_bow": mix(
            noise(0.04, 0.18, a=0.001, d=0.02, s=0.15, r=0.4, color=0.2),
            tone(520, 0.12, 0.22, a=0.002, d=0.08, s=0.2, r=0.55, harm=(1.0, 0.3)),
            tone(180, 0.05, 0.15, a=0.001, d=0.02, s=0.2, r=0.5),
            delays=[0.0, 0.02, 0.0],
        ),
        "atk_shield": mix(
            tone(200, 0.08, 0.35, a=0.002, d=0.03, s=0.3, r=0.5, harm=(1.0, 0.6)),
            noise(0.07, 0.2, a=0.002, d=0.03, s=0.2, r=0.45, color=0.25),
        ),
        # Impacts
        "hit_flesh": mix(
            noise(0.08, 0.35, a=0.001, d=0.03, s=0.25, r=0.45, color=0.3),
            tone(140, 0.1, 0.28, a=0.002, d=0.04, s=0.3, r=0.5),
        ),
        "hit_block": mix(
            tone(260, 0.07, 0.4, a=0.001, d=0.03, s=0.25, r=0.4, harm=(1.0, 0.7, 0.3)),
            noise(0.05, 0.22, a=0.001, d=0.02, s=0.15, r=0.4, color=0.1),
        ),
        "crit": mix(
            tone(880, 0.08, 0.4, a=0.002, d=0.03, s=0.4, r=0.4, harm=(1.0, 0.5)),
            tone(1320, 0.14, 0.32, a=0.005, d=0.05, s=0.35, r=0.5, harm=(1.0, 0.4)),
            noise(0.1, 0.2, a=0.002, d=0.04, s=0.2, r=0.5, color=0.15),
            delays=[0.0, 0.04, 0.0],
        ),
        "heal": mix(
            tone(523, 0.14, 0.28, a=0.01, d=0.05, s=0.45, r=0.55, harm=(1.0, 0.35)),
            tone(659, 0.16, 0.22, a=0.02, d=0.06, s=0.4, r=0.55, harm=(1.0, 0.25)),
            tone(784, 0.18, 0.18, a=0.03, d=0.06, s=0.35, r=0.55),
            delays=[0.0, 0.04, 0.08],
        ),
        "skill_cast": mix(
            tone(392, 0.12, 0.3, a=0.02, d=0.06, s=0.5, r=0.45, harm=(1.0, 0.4, 0.2)),
            tone(588, 0.16, 0.22, a=0.03, d=0.08, s=0.4, r=0.5, harm=(1.0, 0.3)),
            noise(0.12, 0.12, a=0.02, d=0.05, s=0.3, r=0.5, color=0.4),
            delays=[0.0, 0.05, 0.02],
        ),
        "unit_down": mix(
            tone(220, 0.18, 0.35, a=0.01, d=0.08, s=0.35, r=0.6, harm=(1.0, 0.4)),
            tone(110, 0.28, 0.28, a=0.02, d=0.1, s=0.3, r=0.65),
            noise(0.2, 0.15, a=0.01, d=0.08, s=0.25, r=0.6, color=0.35),
            delays=[0.0, 0.06, 0.02],
        ),
        "turn_start_ally": mix(
            tone(523, 0.1, 0.3, a=0.01, d=0.05, s=0.4, r=0.5),
            tone(784, 0.14, 0.26, a=0.02, d=0.06, s=0.35, r=0.55),
            delays=[0.0, 0.06],
        ),
        "turn_start_enemy": mix(
            tone(349, 0.1, 0.3, a=0.01, d=0.05, s=0.4, r=0.5, harm=(1.0, 0.35)),
            tone(277, 0.14, 0.26, a=0.02, d=0.06, s=0.35, r=0.55),
            delays=[0.0, 0.06],
        ),
        "victory": mix(
            tone(523, 0.16, 0.35, a=0.01, d=0.05, s=0.5, r=0.4),
            tone(659, 0.18, 0.32, a=0.01, d=0.05, s=0.5, r=0.4),
            tone(784, 0.28, 0.34, a=0.02, d=0.08, s=0.45, r=0.5),
            tone(1046, 0.35, 0.28, a=0.03, d=0.1, s=0.4, r=0.55),
            delays=[0.0, 0.08, 0.16, 0.28],
        ),
        "defeat": mix(
            tone(392, 0.22, 0.32, a=0.02, d=0.1, s=0.4, r=0.6, harm=(1.0, 0.3)),
            tone(311, 0.3, 0.28, a=0.03, d=0.12, s=0.35, r=0.65),
            tone(233, 0.4, 0.26, a=0.04, d=0.15, s=0.3, r=0.7),
            delays=[0.0, 0.12, 0.28],
        ),
        # Soft looping beds
        "amb_night_wind": soft_loop(6.0, 0.15, amp=0.09),
        "bgm_battle_loop": mix(
            soft_loop(8.0, 0.08, amp=0.07),
            [
                clamp(
                    0.08
                    * math.sin(2 * math.pi * (110 if (i // (SR // 2)) % 4 < 2 else 146.8) * (i / SR))
                    * (0.5 + 0.5 * math.sin(2 * math.pi * 0.125 * (i / SR)))
                )
                for i in range(int(SR * 8.0))
            ],
        ),
    }


def main() -> int:
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(BGM_DIR, exist_ok=True)
    os.makedirs(TMP_DIR, exist_ok=True)
    clips = build_all()
    for name, samples in clips.items():
        samples = fade_edges(samples, 3.0)
        wav = os.path.join(TMP_DIR, f"{name}.wav")
        if name == "bgm_battle_loop":
            ogg = os.path.join(BGM_DIR, f"{name}.ogg")
        else:
            ogg = os.path.join(SFX_DIR, f"{name}.ogg")
        write_wav(wav, samples, stereo=(name in ("bgm_battle_loop", "amb_night_wind")))
        to_ogg(wav, ogg)
        print(f"wrote {os.path.relpath(ogg, ROOT)}")
    # cleanup wav temps
    for f in os.listdir(TMP_DIR):
        os.remove(os.path.join(TMP_DIR, f))
    os.rmdir(TMP_DIR)
    print(f"done: {len(clips)} clips @ {SR} Hz")
    return 0


if __name__ == "__main__":
    sys.exit(main())
