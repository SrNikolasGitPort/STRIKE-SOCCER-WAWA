#!/usr/bin/env python3
"""Sintetiza todos os SFX e músicas do jogo (áudio 100% original, sem samples de terceiros).

Saída: game/assets/audio/sfx/*.wav e game/assets/audio/music/*.wav (mono, 16 bits).
Requer numpy e scipy. Uso: python3 tools/gen_audio.py
"""
from __future__ import annotations

import shutil
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "audio"
SR = 32000
MSR = 22050
rng = np.random.default_rng(11)


def tt(d: float, sr: int = SR) -> np.ndarray:
    return np.arange(int(sr * d)) / sr


def noise(d: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(SR * d))


def expd(n: int, k: float, sr: int = SR) -> np.ndarray:
    return np.exp(-np.arange(n) / sr * k)


def lp(x, f, order=2, sr=SR):
    return signal.lfilter(*signal.butter(order, min(f, sr / 2 - 100) / (sr / 2), "low"), x)


def hp(x, f, order=2, sr=SR):
    return signal.lfilter(*signal.butter(order, f / (sr / 2), "high"), x)


def bp(x, lo, hi, order=2, sr=SR):
    return signal.lfilter(*signal.butter(order, [lo / (sr / 2), min(hi, sr / 2 - 100) / (sr / 2)], "band"), x)


def sine_sweep(d, f0, f1, sr=SR):
    t = tt(d, sr)
    f = f0 + (f1 - f0) * (t / d)
    return np.sin(2 * np.pi * np.cumsum(f) / sr)


def save(name: str, x: np.ndarray, sub="sfx", sr=SR, peak=0.9) -> None:
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    fade = min(len(x) // 20, 400)
    if fade:
        x[-fade:] *= np.linspace(1, 0, fade)
    p = OUT / sub / f"{name}.wav"
    p.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(p), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def mixin(base: np.ndarray, add: np.ndarray, at: float = 0.0, gain: float = 1.0, sr=SR) -> np.ndarray:
    i = int(at * sr)
    end = i + len(add)
    if end > len(base):
        base = np.concatenate([base, np.zeros(end - len(base))])
    base[i:end] += add * gain
    return base


# ----------------------------------------------------------------- chutes
def kick(power: float):
    d = 0.18 + 0.12 * power
    n = int(SR * d)
    body = sine_sweep(d, 160 + 80 * power, 45) * expd(n, 18 - 8 * power)
    click = hp(noise(0.03), 1500) * expd(int(SR * 0.03), 200)
    thump = lp(noise(d), 700) * expd(n, 28)
    x = body * (0.8 + 0.4 * power)
    x = mixin(x, click, 0, 0.5 + 0.4 * power)
    x = mixin(x, thump, 0, 0.5)
    return x


def gen_sfx_ball() -> None:
    save("kick_light", kick(0.2))
    save("kick_medium", kick(0.55))
    save("kick_strong", kick(1.0))
    save("pass", lp(kick(0.1), 2400))
    x = sine_sweep(0.14, 220, 90) * expd(int(SR * 0.14), 25)
    save("ball_bounce", mixin(x, hp(noise(0.02), 2000) * expd(int(SR * 0.02), 150), 0, 0.3))
    # trave: anel metálico
    d = 0.9
    t = tt(d)
    ring = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((880, 1), (1470, 0.7), (2350, 0.5), (3200, 0.3)))
    ring = ring * expd(len(t), 6)
    ring = mixin(ring, hp(noise(0.03), 1200) * expd(int(SR * 0.03), 120), 0, 1.2)
    save("post_hit", ring)
    # rede
    n = noise(0.7)
    swish = bp(n, 500, 5000) * np.linspace(0, 1, len(n)) ** 0.4 * expd(len(n), 5)
    save("net", mixin(swish, kick(0.4), 0, 0.5))
    save("tackle", mixin(lp(noise(0.25), 900) * expd(int(SR * 0.25), 14), kick(0.7), 0, 0.8))
    save("whoosh", bp(noise(0.5), 300, 4500) * np.sin(np.linspace(0, np.pi, int(SR * 0.5))) ** 1.5)
    save("dash", bp(noise(0.45), 600, 6000) * np.sin(np.linspace(0, np.pi, int(SR * 0.45))) ** 0.8 * 0.9)


# ----------------------------------------------------------------- partida
def gen_sfx_match() -> None:
    t = tt(0.7)
    vib = np.sin(2 * np.pi * 38 * t) > 0
    wh = np.sin(2 * np.pi * (2850 + 120 * np.sin(2 * np.pi * 6 * t)) * t) * (0.55 + 0.45 * vib)
    wh += 0.4 * np.sin(2 * np.pi * 3600 * t) * (0.6 + 0.4 * vib)
    save("whistle", wh * np.hanning(len(t)) ** 0.3)
    s2 = tt(1.3)
    wh2 = np.sin(2 * np.pi * (2850 + 90 * np.sin(2 * np.pi * 6 * s2)) * s2) * (0.6 + 0.4 * (np.sin(2 * np.pi * 38 * s2) > 0))
    save("whistle_long", wh2 * np.hanning(len(s2)) ** 0.2)
    # buzina de gol
    h = tt(1.6)
    horn = sum(signal.sawtooth(2 * np.pi * f * h) * a for f, a in ((233, 1), (293.7, 0.8), (349.2, 0.7), (466, 0.5)))
    horn = lp(horn, 2600) * (1 - 0.15 * np.sin(2 * np.pi * 7 * h)) * np.minimum(1, h * 20) * np.minimum(1, (1.6 - h) * 4)
    save("goal_horn", horn)
    # torcida: ruído filtrado modulado
    d = 8.0
    n = noise(d)
    crowd = bp(n, 350, 2800) * (0.6 + 0.4 * lp(noise(d), 2.0, 1))
    crowd += 0.5 * bp(noise(d), 1200, 3500) * (0.5 + 0.5 * lp(noise(d), 3.0, 1))
    k = int(SR * 0.5)
    loop = crowd[:-k].copy()
    loop[:k] = loop[:k] * np.linspace(0, 1, k) + crowd[-k:] * np.linspace(1, 0, k)
    save("crowd_loop", loop, peak=0.5)
    dd = 2.6
    ch = bp(noise(dd), 500, 3200) * (np.sin(np.linspace(0, np.pi, int(SR * dd))) ** 0.7)
    ch += 0.4 * bp(noise(dd), 1500, 4500) * np.sin(np.linspace(0, np.pi, int(SR * dd))) ** 1.2
    save("crowd_cheer", ch, peak=0.8)
    save("crowd_gasp", bp(noise(0.9), 600, 3000) * np.sin(np.linspace(0, np.pi, int(SR * 0.9))) ** 1.4, peak=0.6)
    save("countdown_beep", np.sin(2 * np.pi * 880 * tt(0.18)) * np.hanning(int(SR * 0.18)))
    save("go_beep", np.sin(2 * np.pi * 1320 * tt(0.4)) * np.hanning(int(SR * 0.4)) ** 0.5)


# ----------------------------------------------------------------- UI
def blip(f0, f1, d, vol=1.0):
    n = int(SR * d)
    return np.sin(2 * np.pi * np.cumsum(np.linspace(f0, f1, n)) / SR) * np.hanning(n) ** 0.5 * vol


def gen_sfx_ui() -> None:
    save("ui_hover", blip(900, 1100, 0.05, 0.6))
    save("ui_click", mixin(blip(600, 900, 0.07), blip(1200, 1500, 0.05), 0.04, 0.6))
    save("ui_confirm", mixin(mixin(blip(660, 660, 0.09), blip(880, 880, 0.09), 0.08), blip(1320, 1320, 0.16), 0.16))
    save("ui_back", blip(700, 420, 0.12))
    save("ui_error", mixin(blip(220, 200, 0.12), blip(180, 160, 0.16), 0.1))
    notes = [880, 1108.7, 1318.5, 1760]
    x = np.zeros(int(SR * 0.6))
    for i, f in enumerate(notes):
        x = mixin(x, np.sin(2 * np.pi * f * tt(0.3)) * expd(int(SR * 0.3), 9), i * 0.06)
    save("coin", x)
    # evolução Nel: arpejo triunfal
    x = np.zeros(int(SR * 2.4))
    for i, f in enumerate([523, 659, 784, 1047, 1319, 1568, 2093]):
        x = mixin(x, (np.sin(2 * np.pi * f * tt(0.9)) + 0.4 * np.sin(2 * np.pi * 2 * f * tt(0.9))) * expd(int(SR * 0.9), 4), i * 0.1)
    x = mixin(x, bp(noise(2.0), 3000, 9000) * expd(int(SR * 2.0), 2.2), 0.7, 0.25)
    save("evolve", x)
    save("unlock", mixin(blip(500, 1000, 0.15), blip(1000, 2000, 0.3), 0.12))


# ----------------------------------------------------------------- skills
def boom(d=1.2, f0=120, f1=30):
    n = int(SR * d)
    b = sine_sweep(d, f0, f1) * expd(n, 3.5)
    r = lp(noise(d), 500) * expd(n, 5)
    return b + r * 0.7


def gen_sfx_skills() -> None:
    # Despertar: varredura ascendente + impacto + brilho
    d = 2.0
    n = int(SR * d)
    rise = sine_sweep(1.1, 120, 1600) * np.linspace(0.1, 1, int(SR * 1.1)) ** 1.5
    rise += 0.5 * bp(noise(1.1), 800, 6000) * np.linspace(0, 1, int(SR * 1.1)) ** 2
    x = np.zeros(n)
    x = mixin(x, rise, 0)
    x = mixin(x, boom(0.9, 150, 35) * 1.3, 1.1)
    x = mixin(x, bp(noise(0.9), 3000, 10000) * expd(int(SR * 0.9), 4), 1.1, 0.4)
    for i, f in enumerate([880, 1318, 1760]):
        x = mixin(x, np.sin(2 * np.pi * f * tt(0.6)) * expd(int(SR * 0.6), 6), 1.1 + i * 0.07, 0.3)
    save("awaken", x)
    save("skill_cast", mixin(bp(noise(0.5), 400, 5000) * np.sin(np.linspace(0, np.pi, int(SR * 0.5))), blip(300, 1400, 0.3), 0, 0.5))
    for i, (f0, f1, dd) in enumerate(((140, 40, 0.9), (200, 50, 1.0), (110, 28, 1.3))):
        b = boom(dd, f0, f1)
        b = mixin(b, hp(noise(0.12), 2500) * expd(int(SR * 0.12), 40), 0, 0.9)
        save(f"impact_{i + 1}", b)
    save("shockwave", mixin(boom(1.1, 90, 25), bp(noise(0.7), 100, 1800) * expd(int(SR * 0.7), 5), 0, 0.8))
    # visão: arpejo cintilante
    x = np.zeros(int(SR * 1.0))
    for i, f in enumerate([660, 880, 1100, 1320, 1760]):
        x = mixin(x, np.sin(2 * np.pi * f * tt(0.4)) * expd(int(SR * 0.4), 8), i * 0.08, 0.7)
    save("vision", x)
    save("buff", mixin(sine_sweep(0.5, 300, 900) * np.hanning(int(SR * 0.5)), bp(noise(0.4), 2000, 8000) * expd(int(SR * 0.4), 8), 0.1, 0.3))
    save("steal", mixin(blip(1200, 300, 0.2), lp(noise(0.15), 1500) * expd(int(SR * 0.15), 20), 0.05, 0.6))
    save("stun", mixin(blip(400, 800, 0.1), blip(800, 400, 0.15), 0.1))
    save("copy", mixin(blip(500, 1500, 0.2), blip(1500, 500, 0.2), 0.18))
    # Igaguri GOAT (cômico)
    t = tt(0.55)
    bonk = np.sin(2 * np.pi * np.cumsum(np.linspace(520, 130, len(t))) / SR) * expd(len(t), 7)
    save("goat_bonk", mixin(bonk, hp(noise(0.03), 1500) * expd(int(SR * 0.03), 150), 0, 0.5))
    t = tt(0.9)
    f0 = 520 + 90 * np.sin(2 * np.pi * 7 * t) - 180 * t
    bleat = signal.sawtooth(2 * np.pi * np.cumsum(f0) / SR) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * t))
    bleat = bp(bleat, 400, 2400) * np.hanning(len(t)) ** 0.5
    save("goat_bleat", bleat)
    h = tt(0.9)
    horn = (signal.square(2 * np.pi * 440 * h) + 0.8 * signal.square(2 * np.pi * 554.4 * h) + 0.6 * signal.square(2 * np.pi * 659.3 * h)) * np.minimum(1, h * 40) * np.minimum(1, (0.9 - h) * 12)
    save("goat_horn", lp(horn, 3200))
    d = 2.8
    t = tt(d)
    gong = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((110, 1), (176, 0.8), (287, 0.6), (431, 0.5), (590, 0.3))) * expd(len(t), 1.6)
    save("gong", mixin(gong, lp(noise(0.1), 800) * expd(int(SR * 0.1), 50), 0, 0.8))


# ------------------------------------------------------------------ música
def midi(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


class Track:
    def __init__(self, seconds: float, tail: float = 1.5) -> None:
        self.loop_len = int(MSR * seconds)
        self.buf = np.zeros(self.loop_len + int(MSR * tail))

    def add(self, start: float, x: np.ndarray, gain: float = 1.0) -> None:
        i = int(start * MSR)
        e = min(len(self.buf), i + len(x))
        if i < len(self.buf):
            self.buf[i:e] += x[: e - i] * gain

    def render(self) -> np.ndarray:
        out = self.buf[: self.loop_len].copy()
        tail = self.buf[self.loop_len:]
        out[: len(tail)] += tail
        return out


def tone(freq: float, d: float, kind="saw", a=0.01, r=0.1, sustain=0.7) -> np.ndarray:
    t = np.arange(int(MSR * d)) / MSR
    if kind == "saw":
        w = signal.sawtooth(2 * np.pi * freq * t)
    elif kind == "square":
        w = signal.square(2 * np.pi * freq * t, 0.4)
    else:
        w = np.sin(2 * np.pi * freq * t)
    env = np.minimum(1, t / a) * np.where(t > d - r, np.maximum(0, (d - t) / r), 1.0) * (sustain + (1 - sustain) * np.exp(-t * 8))
    return w * env


def kick_m() -> np.ndarray:
    n = int(MSR * 0.25)
    t = np.arange(n) / MSR
    return np.sin(2 * np.pi * np.cumsum(np.linspace(150, 45, n)) / MSR) * np.exp(-t * 14)


def snare_m() -> np.ndarray:
    n = int(MSR * 0.2)
    t = np.arange(n) / MSR
    return (rng.uniform(-1, 1, n) * np.exp(-t * 22)) * 0.8 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 28) * 0.5


def hat_m(open_=False) -> np.ndarray:
    n = int(MSR * (0.18 if open_ else 0.05))
    t = np.arange(n) / MSR
    return signal.lfilter(*signal.butter(2, 6000 / (MSR / 2), "high"), rng.uniform(-1, 1, n)) * np.exp(-t * (14 if open_ else 60))


def song(bpm: int, bars: int, prog: list[int], minor_key: int, lead_pattern: list[int], drums: bool, intense: bool) -> np.ndarray:
    beat = 60.0 / bpm
    total = bars * 4 * beat
    tr = Track(total)
    scale = [0, 2, 3, 5, 7, 8, 10]  # menor natural
    for bar in range(bars):
        root = minor_key + prog[(bar // 2) % len(prog)]
        t0 = bar * 4 * beat
        # baixo
        for b in range(8 if intense else 4):
            step = 0.5 if intense else 1
            tr.add(t0 + b * beat * step, tone(midi(root - 12), beat * step * 0.9, "square", r=0.05) * 0.55, 0.6)
        # acorde (pad)
        for iv in (0, 3, 7):
            tr.add(t0, tone(midi(root + iv), 4 * beat, "saw", a=0.08, r=0.4, sustain=0.9), 0.09)
        # lead
        for i, s in enumerate(lead_pattern):
            deg = scale[s % 7] + 12 * (s // 7)
            tr.add(t0 + i * beat * (0.5 if intense else 1.0), tone(midi(root + 12 + deg), beat * 0.45, "square", r=0.05), 0.11)
        if drums:
            for b in range(4):
                tr.add(t0 + b * beat, kick_m(), 0.9 if b % 2 == 0 else 0.0)
                tr.add(t0 + (b + 0.5) * beat, hat_m(), 0.35)
                if b % 2 == 1:
                    tr.add(t0 + b * beat, snare_m(), 0.7)
            if intense:
                tr.add(t0 + 1.75 * beat, kick_m(), 0.6)
                tr.add(t0 + 3.5 * beat, hat_m(True), 0.4)
    return tr.render()


def song2(bpm: int, bars: int, prog: list[int], key: int, motif: list[tuple[float, int, float]], *, drums: int = 2,
          arp: float = 0.5, sections: bool = True, swing: float = 0.0, lead_kind: str = "saw", sub: bool = True) -> np.ndarray:
    """Música com seções (intro / corpo / quebra), arpejo, baixo sub, melodia com variação a cada 4 compassos,
    bateria com fills. motif = [(tempo_em_beats, grau, duração_beats)] dentro de 1 compasso."""
    beat = 60.0 / bpm
    tr = Track(bars * 4 * beat)
    scale = [0, 2, 3, 5, 7, 8, 10]
    chord = (0, 3, 7, 12)
    for bar in range(bars):
        root = key + prog[(bar // 2) % len(prog)]
        t0 = bar * 4 * beat
        sec = "body"
        if sections:
            sec = "intro" if bar < 4 else ("break" if bar >= bars - 4 else "body")
        # pad
        for iv in chord[:3]:
            tr.add(t0, tone(midi(root + iv), 4 * beat, "saw", a=0.25, r=0.5, sustain=0.9), 0.07 if sec != "break" else 0.1)
        # sub + baixo
        if sec != "break":
            for b in range(8):
                if sub and b % 2 == 0:
                    tr.add(t0 + b * beat * 0.5, tone(midi(root - 24), beat * 0.45, "sine", r=0.05) * 0.9, 0.6)
                if drums >= 2 and sec == "body" and b % 4 in (1, 3):
                    tr.add(t0 + b * beat * 0.5, tone(midi(root - 12 + (7 if b % 4 == 3 else 0)), beat * 0.4, "square", r=0.05), 0.28)
        # arpejo
        if arp > 0 and sec != "intro" or (arp > 0 and bar % 2 == 1):
            steps = int(4 / arp)
            for i in range(steps):
                iv = chord[(i * 2 + (i // 4)) % 4] + (12 if (i % 8) >= 4 else 0)
                tr.add(t0 + i * beat * arp, tone(midi(root + 12 + iv), beat * arp * 0.8, "square", a=0.004, r=0.04), 0.07)
        # melodia (variação por frase: 0 base, 1 oitava acima, 2 inversão rítmica, 3 resposta)
        if sec == "body" or (sec == "break" and bar % 2 == 0):
            phrase = (bar // 4) % 4
            for (bt, deg, du) in motif:
                dg = deg + (2 if phrase == 3 else 0)
                note = root + 12 + scale[dg % 7] + 12 * (dg // 7) + (12 if phrase == 1 else 0)
                off = swing * beat * 0.5 if (int(bt * 2) % 2 == 1) else 0.0
                tr.add(t0 + bt * beat + off, tone(midi(note), du * beat * 0.95, lead_kind, a=0.01, r=0.08, sustain=0.75), 0.12)
        # bateria
        if drums and sec != "intro":
            for b in range(4):
                if sec != "break" or bar % 2 == 1:
                    tr.add(t0 + b * beat, kick_m(), 0.95 if b % 2 == 0 else 0.0)
                    tr.add(t0 + (b + 0.5) * beat, hat_m(b % 2 == 1), 0.3)
                    if b % 2 == 1:
                        tr.add(t0 + b * beat, snare_m(), 0.75)
            if drums >= 2:
                tr.add(t0 + 1.75 * beat, kick_m(), 0.5)
                tr.add(t0 + 2.5 * beat, kick_m(), 0.45)
                for k in range(8):
                    tr.add(t0 + k * beat * 0.5 + beat * 0.25, hat_m(), 0.18)
            if bar % 4 == 3:  # fill de caixa
                for k in range(8):
                    tr.add(t0 + 3 * beat + k * beat * 0.125, snare_m(), 0.25 + 0.06 * k)
        if sec == "break" and bar == bars - 1:  # riser para o loop
            n = int(MSR * 4 * beat)
            t = np.arange(n) / MSR
            riser = lp(rng.uniform(-1, 1, n) * (t / t[-1]) ** 2, 5000, 2, MSR)
            tr.add(t0, riser, 0.25)
    return tr.render()


def gen_music() -> None:
    # menu: épico calmo, arpejo suave e melodia lírica
    menu = song2(96, 16, [0, 8, 3, 10], 57, [(0, 4, 1.5), (1.5, 2, 0.5), (2, 4, 1.0), (3, 5, 1.0)], drums=0, arp=0.5, sections=True, lead_kind="sine")
    save("menu_theme", lp(menu, 7000, 2, MSR), "music", MSR, 0.8)
    # partida: batida acelerada, melodia em saw
    match = song2(156, 24, [0, 8, 3, 10], 52, [(0, 4, 0.5), (0.5, 5, 0.5), (1, 7, 1.0), (2, 5, 0.5), (2.5, 4, 0.5), (3, 2, 1.0)], drums=2, arp=0.25, sections=True, lead_kind="saw")
    save("match_theme", lp(match, 8000, 2, MSR), "music", MSR, 0.8)
    # despertar: mais rápido, grave pesado, melodia aguda
    awake = song2(172, 16, [0, 3, 8, 10], 50, [(0, 7, 0.5), (0.5, 9, 0.5), (1, 11, 0.5), (1.5, 9, 0.5), (2, 7, 1.0), (3, 8, 1.0)], drums=2, arp=0.25, sections=False, lead_kind="saw")
    save("awaken_theme", lp(awake, 9000, 2, MSR), "music", MSR, 0.85)
    # vitória: maior, brilhante
    vic = song2(120, 8, [0, 5, 7, 5], 60, [(0, 4, 0.5), (0.5, 6, 0.5), (1, 7, 1.0), (2, 6, 0.5), (2.5, 7, 0.5), (3, 9, 1.0)], drums=1, arp=0.5, sections=False, lead_kind="square")
    save("victory_theme", lp(vic, 8000, 2, MSR), "music", MSR, 0.8)


def main() -> int:
    if OUT.exists():
        shutil.rmtree(OUT)
    gen_sfx_ball(); gen_sfx_match(); gen_sfx_ui(); gen_sfx_skills(); gen_music()
    files = list(OUT.rglob("*.wav"))
    print(f"OK: {len(files)} arquivos de áudio, {sum(f.stat().st_size for f in files) / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
