#!/usr/bin/env python3
"""Gera todas as texturas PNG do jogo (arte 100% original/procedural).

Saída em game/assets/textures/. Requer Pillow e numpy.
Uso: python3 tools/gen_art.py
"""
from __future__ import annotations

import colorsys
import math
import random
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import roster  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "textures"
FONT_DIR = ROOT / "game" / "assets" / "fonts"
INTER = Path("/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf")
CJK = Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc")
RARITY_COLORS = {"raro": "#2F80ED", "epico": "#9B51E0", "lendario": "#F2C94C", "mitico": "#EB5757", "world_class": "#FFFFFF"}
rng = random.Random(7)
nrng = np.random.default_rng(7)


def hexc(h: str, a: int = 255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


def save(img: Image.Image, rel: str) -> None:
    p = OUT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    img.save(p, optimize=True)


def font(path: Path, size: int, index: int = 0):
    return ImageFont.truetype(str(path), size, index=index)


# ------------------------------------------------------------------ campo e bola
def tileable_noise(size: int, octaves: int = 5) -> np.ndarray:
    total = np.zeros((size, size))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        n = 2 ** (o + 2)
        small = nrng.random((n, n))
        img = Image.fromarray((small * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        total += np.asarray(img, dtype=float) / 255.0 * amp
        norm += amp
        amp *= 0.55
    return total / norm


def gen_field() -> None:
    size = 512
    n = tileable_noise(size)
    blades = nrng.random((size, size)) * 0.5
    v = np.clip(0.62 + (n - 0.5) * 0.55 + (blades - 0.25) * 0.18, 0, 1)
    rgb = np.stack([v * 0.82, v * 1.0, v * 0.78], axis=-1)
    save(Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).convert("RGBA"), "field/grass.png")

    # Concreto/arquibancada escura para o entorno
    c = np.clip(0.28 + (tileable_noise(256, 4) - 0.5) * 0.25, 0, 1)
    save(Image.fromarray((np.stack([c * 0.8, c * 0.85, c, np.ones_like(c)], -1) * 255).astype(np.uint8), "RGBA"), "field/concrete.png")

    # Bola: campo equirretangular com "gomos" escuros
    w, h = 512, 256
    img = Image.new("RGBA", (w, h), (246, 246, 246, 255))
    d = ImageDraw.Draw(img)
    pts = [(0.12, 0.5), (0.37, 0.5), (0.62, 0.5), (0.87, 0.5), (0.25, 0.15), (0.75, 0.15), (0.25, 0.85), (0.75, 0.85), (0.5, 0.1), (0.5, 0.9)]
    for ux, vy in pts:
        cx, cy, r = ux * w, vy * h, 26
        poly = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(-90, 270, 72)]
        d.polygon(poly, fill=(22, 26, 40, 255))
        for (px, py) in poly:
            d.line([(px, py), (cx + (px - cx) * 1.9, cy + (py - cy) * 1.9)], fill=(70, 74, 90, 255), width=3)
    save(img.filter(ImageFilter.GaussianBlur(0.8)), "field/ball.png")


# ------------------------------------------------------------------ uniformes
def gen_kits() -> None:
    for kid, k in roster.KITS.items():
        main, sec = hexc(k["main"]), hexc(k["sec"])
        img = Image.new("RGBA", (128, 128), main)
        d = ImageDraw.Draw(img)
        pat = k["pattern"]
        if pat == "stripes":
            for x in range(0, 128, 32):
                d.rectangle([x + 10, 0, x + 21, 128], fill=sec)
        elif pat == "hoops":
            for y in range(0, 128, 32):
                d.rectangle([0, y + 10, 128, y + 21], fill=sec)
        elif pat == "sash":
            d.polygon([(0, 30), (128, 78), (128, 108), (0, 60)], fill=sec)
        d.rectangle([0, 0, 128, 10], fill=sec)
        arr = np.asarray(img, dtype=float) / 255.0
        shade = 0.92 + 0.08 * tileable_noise(128, 3)[..., None]
        arr[..., :3] = np.clip(arr[..., :3] * shade, 0, 1)
        save(Image.fromarray((arr * 255).astype(np.uint8), "RGBA"), f"kits/kit_{kid}.png")


# --------------------------------------------------------------------- rostos
def draw_face(d: ImageDraw.ImageDraw, w: int, h: int, c: dict) -> None:
    eyes, eyes2 = hexc(c["eyes"]), hexc(c.get("eyes2") or c["eyes"])
    hair = hexc(c["hc"])
    ew, eh = w * 0.20, h * 0.46
    for side, col in ((-1, eyes), (1, eyes2)):
        cx, cy = w / 2 + side * w * 0.22, h * 0.55
        d.ellipse([cx - ew / 2, cy - eh / 2, cx + ew / 2, cy + eh / 2], fill=(250, 250, 250, 255), outline=(20, 20, 30, 255), width=max(2, w // 64))
        ir = ew * 0.40
        d.ellipse([cx - ir, cy - eh * 0.38, cx + ir, cy + eh * 0.38], fill=col)
        d.ellipse([cx - ir * 0.45, cy - eh * 0.2, cx + ir * 0.45, cy + eh * 0.2], fill=(15, 15, 25, 255))
        d.ellipse([cx - ir * 0.15 - ir * 0.5, cy - eh * 0.28, cx - ir * 0.15, cy - eh * 0.08], fill=(255, 255, 255, 230))
        by = cy - eh * 0.72
        d.line([(cx - ew * 0.62, by + side * 2), (cx + ew * 0.62, by - side * 2 + 2)], fill=hair, width=max(3, w // 34))
    d.arc([w * 0.42, h * 0.78, w * 0.58, h * 1.0], 10, 170, fill=(120, 50, 50, 255), width=max(2, w // 64))
    if c.get("glasses"):
        for side in (-1, 1):
            cx = w / 2 + side * w * 0.22
            d.ellipse([cx - ew * 0.8, h * 0.55 - eh * 0.62, cx + ew * 0.8, h * 0.55 + eh * 0.62], outline=(30, 30, 40, 255), width=max(2, w // 50))
        d.line([(w / 2 - w * 0.22 + ew * 0.8, h * 0.55), (w / 2 + w * 0.22 - ew * 0.8, h * 0.55)], fill=(30, 30, 40, 255), width=max(2, w // 50))


def gen_faces(chars: list[dict]) -> None:
    for c in chars:
        img = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
        draw_face(ImageDraw.Draw(img), 256, 128, c)
        save(img, f"faces/face_{c['id']}.png")


# -------------------------------------------------------------------- retratos
def draw_hair(d: ImageDraw.ImageDraw, style: str, col, acc, cx: float, cy: float, r: float) -> None:
    def cap(extra=0.0):
        d.ellipse([cx - r * 1.08, cy - r * 1.18 - extra, cx + r * 1.08, cy + r * 0.25], fill=col)
    if style == "bald":
        d.ellipse([cx - r * 0.4, cy - r * 0.95, cx - r * 0.1, cy - r * 0.7], fill=(255, 255, 255, 90))
        return
    if style in ("short", "bob", "long", "ponytail"):
        cap()
        d.polygon([(cx - r * 1.05, cy - r * 0.1), (cx - r * 0.3, cy - r * 0.55), (cx + r * 0.25, cy - r * 0.2), (cx + r * 1.05, cy - r * 0.55),
                   (cx + r * 1.08, cy - r * 0.1), (cx, cy - r * 0.78)], fill=col)
    if style == "bob":
        d.polygon([(cx - r * 1.1, cy - r * 0.4), (cx - r * 1.2, cy + r * 0.75), (cx - r * 0.75, cy + r * 0.7), (cx - r * 0.8, cy - r * 0.3)], fill=col)
        d.polygon([(cx + r * 1.1, cy - r * 0.4), (cx + r * 1.2, cy + r * 0.75), (cx + r * 0.75, cy + r * 0.7), (cx + r * 0.8, cy - r * 0.3)], fill=col)
    if style == "long":
        d.polygon([(cx - r * 1.1, cy - r * 0.4), (cx - r * 1.3, cy + r * 2.0), (cx - r * 0.7, cy + r * 1.7), (cx - r * 0.8, cy - r * 0.3)], fill=col)
        d.polygon([(cx + r * 1.1, cy - r * 0.4), (cx + r * 1.3, cy + r * 2.0), (cx + r * 0.7, cy + r * 1.7), (cx + r * 0.8, cy - r * 0.3)], fill=col)
    if style == "ponytail":
        d.polygon([(cx + r * 0.9, cy - r * 0.7), (cx + r * 1.9, cy - r * 0.2), (cx + r * 1.7, cy + r * 1.6), (cx + r * 1.2, cy + r * 0.2)], fill=col)
    if style in ("spiky", "wild"):
        n = 9 if style == "wild" else 7
        for i in range(n):
            a = math.radians(200 + i * (140 / (n - 1)))
            tipr = r * (1.75 if style == "wild" else 1.5) * (0.85 + 0.3 * ((i * 37) % 10) / 10)
            bx1, by1 = cx + r * 0.95 * math.cos(a - 0.2), cy + r * 0.95 * math.sin(a - 0.2)
            bx2, by2 = cx + r * 0.95 * math.cos(a + 0.2), cy + r * 0.95 * math.sin(a + 0.2)
            d.polygon([(bx1, by1), (cx + tipr * math.cos(a), cy + tipr * math.sin(a)), (bx2, by2)], fill=col)
        d.ellipse([cx - r * 1.02, cy - r * 1.05, cx + r * 1.02, cy + r * 0.2], fill=col)
    if style == "pompadour":
        d.ellipse([cx - r * 1.08, cy - r * 1.18, cx + r * 1.08, cy + r * 0.25], fill=col)
        d.polygon([(cx - r * 0.9, cy - r * 0.9), (cx - r * 0.5, cy - r * 1.9), (cx + r * 0.8, cy - r * 1.7), (cx + r * 1.05, cy - r * 0.6)], fill=col)
    if acc:
        a = hexc(acc)
        for off in (-0.45, 0.0, 0.45):
            d.line([(cx + off * r, cy - r * 1.05), (cx + off * r * 1.15, cy - r * 0.3)], fill=a, width=max(3, int(r * 0.09)))


def gradient(w: int, h: int, top, bottom) -> Image.Image:
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    for y in range(h):
        arr[y, :, :] = mix(top, bottom, y / (h - 1))
    return Image.fromarray(arr, "RGBA")


def gen_portraits(chars: list[dict]) -> None:
    W, H = 256, 320
    for c in chars:
        rc = hexc(RARITY_COLORS[c["rarity"]])
        dark = tuple(int(v * 0.28) for v in rc[:3]) + (255,)
        light = mix(dark, rc, 0.55)
        img = gradient(W, H, light, dark)
        d = ImageDraw.Draw(img, "RGBA")
        for i in range(-H, W, 34):
            d.polygon([(i, H), (i + 14, H), (i + 14 + H, 0), (i + H, 0)], fill=(255, 255, 255, 16))
        glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([30, 60, 226, 256], fill=hexc(c["aura"], 120))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(26)))
        d = ImageDraw.Draw(img, "RGBA")
        kit = c["kit"]
        main, sec = hexc(kit["main"]), hexc(kit["sec"])
        skin = hexc(c["skin"])
        cx, cy, r = W / 2, 150, 58
        if c["hair"] == "long":
            draw_hair(d, "long", hexc(c["hc"]), "", cx, cy, r)
        d.polygon([(30, H), (50, 235), (cx - 40, 218), (cx + 40, 218), (W - 50, 235), (W - 30, H)], fill=main)
        d.polygon([(cx - 40, 218), (cx, 252), (cx + 40, 218), (cx + 22, 214), (cx, 238), (cx - 22, 214)], fill=sec)
        d.rectangle([cx - 20, 190, cx + 20, 224], fill=skin)
        d.ellipse([cx - r, cy - r * 1.05, cx + r, cy + r * 1.05], fill=skin)
        d.ellipse([cx - r - 9, cy - 6, cx - r + 9, cy + 20], fill=skin)
        d.ellipse([cx + r - 9, cy - 6, cx + r + 9, cy + 20], fill=skin)
        style = "short" if c["hair"] == "long" else c["hair"]
        draw_hair(d, style, hexc(c["hc"]), c.get("hc2", ""), cx, cy, r)
        face = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
        draw_face(ImageDraw.Draw(face), 256, 128, c)
        face = face.resize((int(r * 1.7), int(r * 0.85)), Image.LANCZOS)
        img.alpha_composite(face, (int(cx - face.width / 2), int(cy - r * 0.18)))
        d = ImageDraw.Draw(img, "RGBA")
        f = font(INTER, 22)
        d.text((W - 16, H - 14), str(c["num"]), font=f, fill=(255, 255, 255, 220), anchor="rb", stroke_width=3, stroke_fill=(0, 0, 0, 200))
        save(img, f"portraits/{c['id']}.png")


# ---------------------------------------------------------------- molduras
def gen_frames() -> None:
    W, H = 256, 340
    for rid, col in RARITY_COLORS.items():
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        c = hexc(col)
        if rid == "world_class":
            for t in range(10):
                for side in range(4):
                    pass
            border = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            for y in range(H):
                for x in range(0, W, 1):
                    pass
            hue = np.zeros((H, W, 4), dtype=np.uint8)
            for y in range(H):
                for x in range(W):
                    r, g, b = colorsys.hsv_to_rgb(((x + y) / (W + H)) % 1.0, 0.35, 1.0)
                    hue[y, x] = (int(r * 255), int(g * 255), int(b * 255), 255)
            grad = Image.fromarray(hue, "RGBA")
            mask = Image.new("L", (W, H), 0)
            md = ImageDraw.Draw(mask)
            md.rounded_rectangle([0, 0, W - 1, H - 1], radius=22, fill=255)
            md.rounded_rectangle([10, 10, W - 11, H - 11], radius=14, fill=0)
            img.paste(grad, (0, 0), mask)
            d = ImageDraw.Draw(img)
            for sx, sy in ((30, 28), (W - 36, 60), (40, H - 50), (W - 44, H - 34)):
                d.polygon([(sx, sy - 9), (sx + 3, sy - 3), (sx + 9, sy), (sx + 3, sy + 3), (sx, sy + 9), (sx - 3, sy + 3), (sx - 9, sy), (sx - 3, sy - 3)], fill=(255, 255, 255, 240))
        else:
            d.rounded_rectangle([0, 0, W - 1, H - 1], radius=22, outline=c, width=10)
            d.rounded_rectangle([10, 10, W - 11, H - 11], radius=14, outline=mix(c, (255, 255, 255, 255), 0.5), width=2)
        # faixa inferior para o nome
        band = Image.new("RGBA", (W, 64), (0, 0, 0, 0))
        ImageDraw.Draw(band).rectangle([0, 0, W, 64], fill=(8, 10, 20, 205))
        img.alpha_composite(band, (0, H - 74))
        save(img, f"cards/frame_{rid}.png")


# ------------------------------------------------------------------- ícones
def gen_icons() -> None:
    cols = {"shot": "#FF9F43", "pass": "#4DA3FF", "dash": "#6BE675", "evade": "#B79CFF", "steal": "#FF5C7A", "shockwave": "#FFD166",
            "buff": "#F2C94C", "zone": "#5CC8FF", "block": "#9AA7C0", "vision": "#2AE0C9", "mark": "#EB5757", "rest": "#7CFFB0",
            "copy": "#C792EA", "dashshot": "#FF7A3D", "multishot": "#FFB347"}
    for name, col in cols.items():
        S = 128
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        c = hexc(col)
        d.ellipse([4, 4, S - 4, S - 4], fill=(12, 16, 30, 235), outline=c, width=6)
        w = (255, 255, 255, 255)
        m = S / 2
        if name in ("shot", "dashshot", "multishot"):
            d.ellipse([34, 54, 62, 82], fill=w)
            d.polygon([(64, 58), (96, 68), (64, 78)], fill=c)
            if name == "multishot":
                d.ellipse([24, 40, 38, 54], fill=c); d.ellipse([24, 84, 38, 98], fill=c)
            if name == "dashshot":
                d.line([(18, 50), (40, 50)], fill=c, width=6); d.line([(14, 76), (34, 76)], fill=c, width=6)
        elif name == "pass":
            d.ellipse([22, 74, 44, 96], fill=w); d.ellipse([84, 32, 106, 54], fill=c)
            d.line([(40, 78), (86, 52)], fill=w, width=6)
        elif name == "dash":
            for i in range(3):
                d.polygon([(26 + i * 24, 40), (50 + i * 24, 64), (26 + i * 24, 88), (36 + i * 24, 64)], fill=c if i else w)
        elif name == "evade":
            d.arc([26, 26, 102, 102], 200, 20, fill=w, width=8)
            d.polygon([(92, 40), (106, 62), (80, 58)], fill=c)
        elif name == "steal":
            d.ellipse([34, 34, 94, 94], outline=w, width=7); d.ellipse([54, 54, 74, 74], fill=c)
        elif name == "shockwave":
            for r in (14, 28, 42):
                d.ellipse([m - r, m - r, m + r, m + r], outline=c if r > 14 else w, width=6)
        elif name == "buff":
            d.polygon([(m, 22), (78, 62), (92, 62), (m, 108), (36, 62), (50, 62)], fill=c)
            d.polygon([(m, 34), (72, 62), (56, 62)], fill=w)
        elif name == "zone":
            for a in range(0, 360, 40):
                d.arc([22, 22, 106, 106], a, a + 22, fill=w, width=8)
            d.ellipse([54, 54, 74, 74], fill=c)
        elif name == "block":
            d.polygon([(m, 20), (96, 36), (92, 74), (m, 108), (36, 74), (32, 36)], fill=w, outline=c)
            d.polygon([(m, 34), (82, 44), (80, 70), (m, 94), (48, 70), (46, 44)], fill=c)
        elif name == "vision":
            d.ellipse([20, 40, 108, 88], outline=w, width=7); d.ellipse([48, 48, 80, 80], fill=c); d.ellipse([58, 58, 70, 70], fill=(10, 10, 20, 255))
        elif name == "mark":
            d.ellipse([30, 30, 98, 98], outline=w, width=6)
            d.line([(m, 14), (m, 114)], fill=c, width=6); d.line([(14, m), (114, m)], fill=c, width=6)
        elif name == "rest":
            d.rectangle([54, 28, 74, 100], fill=w); d.rectangle([28, 54, 100, 74], fill=c)
        elif name == "copy":
            d.rectangle([28, 28, 80, 80], outline=w, width=6); d.rectangle([48, 48, 100, 100], fill=c, outline=w, width=4)
        save(img, f"icons/skill_{name}.png")


# ----------------------------------------------------------------------- UI
def gen_ui() -> None:
    # Fundo do menu: estádio noturno com feixes de luz
    W, H = 1280, 720
    img = gradient(W, H, (10, 16, 44, 255), (4, 6, 18, 255))
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    for x, a in ((180, 70), (520, 60), (860, 60), (1120, 70)):
        od.polygon([(x - 10, 0), (x + 10, 0), (x + 220, H), (x - 220, H)], fill=(180, 210, 255, a // 4))
    img.alpha_composite(ov.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, int(H * 0.72), W, H], fill=(14, 70, 32, 255))
    for i in range(0, W, 120):
        d.polygon([(i, int(H * 0.72)), (i + 60, int(H * 0.72)), (i + 160, H), (i + 40, H)], fill=(18, 88, 40, 255))
    d.line([(0, int(H * 0.72)), (W, int(H * 0.72))], fill=(255, 255, 255, 70), width=3)
    for _ in range(260):
        x, y = rng.randint(0, W), rng.randint(0, int(H * 0.5))
        s = rng.choice((1, 1, 2))
        d.ellipse([x, y, x + s, y + s], fill=(255, 255, 255, rng.randint(60, 200)))
    ball = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(ball).ellipse([1020, 520, 1180, 680], fill=(245, 245, 250, 255))
    img.alpha_composite(ball.filter(ImageFilter.GaussianBlur(1.2)))
    save(img, "ui/menu_bg.png")

    # Logo
    lw, lh = 1100, 260
    logo = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    ld = ImageDraw.Draw(logo)
    size1 = 150
    f1 = font(INTER, size1)
    while f1.getlength("STRIKE SOCCER") > lw - 70:  # ajusta o corpo do texto para caber na imagem
        size1 -= 4
        f1 = font(INTER, size1)
    f2 = font(INTER, 82)
    for off, col in (((7, 8), (0, 0, 0, 200)),):
        ld.text((lw // 2 + off[0], 82 + off[1]), "STRIKE SOCCER", font=f1, fill=col, anchor="mm", stroke_width=10, stroke_fill=col)
    ld.text((lw // 2, 82), "STRIKE SOCCER", font=f1, fill=(255, 255, 255, 255), anchor="mm", stroke_width=10, stroke_fill=(20, 30, 80, 255))
    ld.text((lw // 2, 196), "WAWA", font=f2, fill=(255, 214, 80, 255), anchor="mm", stroke_width=8, stroke_fill=(120, 40, 0, 255))
    save(logo, "ui/logo.png")

    # Meio-tom (halftone) para as cenas de skill
    S = 256
    ht = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(ht)
    for gy in range(0, S, 16):
        for gx in range(0, S, 16):
            off = 8 if (gy // 16) % 2 else 0
            r = 2 + 5 * (gy / S)
            hd.ellipse([gx + off - r, gy - r, gx + off + r, gy + r], fill=(0, 0, 0, 255))
    save(ht, "ui/halftone.png")

    # Vinheta e brilho suave
    v = np.zeros((256, 256, 4), dtype=np.uint8)
    yy, xx = np.mgrid[0:256, 0:256]
    dist = np.sqrt((xx - 128) ** 2 + (yy - 128) ** 2) / 181.0
    v[..., 3] = np.clip((dist - 0.45) * 1.9, 0, 1) * 235
    save(Image.fromarray(v, "RGBA"), "ui/vignette.png")


# ----------------------------------------------------------------------- VFX
def gen_vfx() -> None:
    def radial(size: int, power: float, color=(255, 255, 255)) -> Image.Image:
        yy, xx = np.mgrid[0:size, 0:size]
        dist = np.sqrt((xx - size / 2) ** 2 + (yy - size / 2) ** 2) / (size / 2)
        a = np.clip(1 - dist, 0, 1) ** power
        arr = np.zeros((size, size, 4), dtype=np.uint8)
        arr[..., 0], arr[..., 1], arr[..., 2] = color
        arr[..., 3] = (a * 255).astype(np.uint8)
        return Image.fromarray(arr, "RGBA")

    save(radial(128, 2.2), "vfx/glow.png")
    save(radial(128, 1.0), "vfx/soft.png")
    smoke = radial(128, 1.4)
    n = (tileable_noise(128, 4) * 0.7 + 0.3)
    sa = np.asarray(smoke, dtype=float)
    sa[..., 3] *= n
    save(Image.fromarray(sa.astype(np.uint8), "RGBA"), "vfx/smoke.png")
    # estrela de 4 pontas
    st = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    ImageDraw.Draw(st).polygon([(64, 2), (74, 54), (126, 64), (74, 74), (64, 126), (54, 74), (2, 64), (54, 54)], fill=(255, 255, 255, 255))
    save(st.filter(ImageFilter.GaussianBlur(1.2)), "vfx/star.png")
    # anel de onda de choque
    ring = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    for i, a in enumerate((255, 160, 80, 40)):
        rd.ellipse([8 + i * 3, 8 + i * 3, 248 - i * 3, 248 - i * 3], outline=(255, 255, 255, a), width=10 - i * 2)
    save(ring.filter(ImageFilter.GaussianBlur(1.5)), "vfx/ring.png")
    # linhas de velocidade radiais (overlay de tela cheia)
    W, H = 1280, 720
    sl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sl)
    cx, cy = W / 2, H / 2
    for _ in range(190):
        a = rng.uniform(0, math.tau)
        r0 = rng.uniform(260, 470)
        r1 = r0 + rng.uniform(260, 700)
        wdt = rng.uniform(1.5, 5.5)
        p1 = (cx + r0 * math.cos(a), cy + r0 * 0.78 * math.sin(a))
        p2 = (cx + r1 * math.cos(a), cy + r1 * 0.78 * math.sin(a))
        sd.line([p1, p2], fill=(255, 255, 255, rng.randint(150, 255)), width=int(wdt))
    save(sl.filter(ImageFilter.GaussianBlur(0.6)), "vfx/speedlines.png")
    # rastro diagonal
    sh = Image.new("RGBA", (512, 64), (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([(0, 32), (460, 4), (512, 32), (460, 60)], fill=(255, 255, 255, 255))
    save(sh.filter(ImageFilter.GaussianBlur(3)), "vfx/slash.png")


# -------------------------------------------------------------- onomatopeias
def gen_ono() -> None:
    kana = {"don": "ドン", "go": "ゴッ", "ba": "バッ", "zudon": "ズドン", "shu": "シュッ", "dododo": "ドドド", "kiin": "キィン",
            "gogogo": "ゴゴゴ", "baki": "バキッ", "paan": "パァン", "hyu": "ヒュッ", "zaa": "ザァ"}
    latin = {"bonk": "BONK!", "gong": "GONG!"}
    for key, txt in list(kana.items()) + list(latin.items()):
        f = font(CJK, 230, 0) if key in kana else font(INTER, 190)
        img = Image.new("RGBA", (1024, 420), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.text((512, 210), txt, font=f, fill=(0, 0, 0, 255), anchor="mm", stroke_width=34, stroke_fill=(0, 0, 0, 255))
        d.text((512, 210), txt, font=f, fill=(255, 255, 255, 255), anchor="mm", stroke_width=6, stroke_fill=(255, 255, 255, 255))
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)
        save(img, f"ono/{key}.png")


# -------------------------------------------------------- ícones do aplicativo
def gen_app_icons() -> None:
    def ball_icon(size: int, bg: bool) -> Image.Image:
        img = gradient(size, size, (20, 36, 96, 255), (6, 10, 30, 255)) if bg else Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        r = size * (0.30 if not bg else 0.34)
        cx = cy = size / 2
        if bg:
            d.polygon([(0, size * 0.78), (size, size * 0.62), (size, size), (0, size)], fill=(18, 96, 44, 255))
            return img
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(250, 250, 252, 255), outline=(20, 26, 50, 255), width=max(3, size // 60))
        pr = r * 0.42
        d.polygon([(cx + pr * math.cos(math.radians(a)), cy + pr * math.sin(math.radians(a))) for a in range(-90, 270, 72)], fill=(22, 26, 40, 255))
        for a in range(-90, 270, 72):
            px, py = cx + pr * math.cos(math.radians(a)), cy + pr * math.sin(math.radians(a))
            d.line([(px, py), (cx + r * 0.95 * math.cos(math.radians(a)), cy + r * 0.95 * math.sin(math.radians(a)))], fill=(22, 26, 40, 255), width=max(3, size // 70))
        f = font(INTER, int(size * 0.14))
        d.text((cx, cy + r + size * 0.12), "STRIKE", font=f, fill=(255, 255, 255, 255), anchor="mm", stroke_width=max(2, size // 90), stroke_fill=(20, 30, 80, 255))
        return img
    fg, bgi = ball_icon(432, False), ball_icon(432, True)
    save(fg, "app/adaptive_fg_432.png")
    save(bgi, "app/adaptive_bg_432.png")
    full = bgi.copy()
    full.alpha_composite(fg)
    save(full.resize((192, 192), Image.LANCZOS), "app/main_192.png")
    save(full.resize((512, 512), Image.LANCZOS), "app/icon_512.png")
    full.resize((128, 128), Image.LANCZOS).save(ROOT / "game" / "icon.png")


def main() -> int:
    for p in (OUT,):
        if p.exists():
            shutil.rmtree(p)
    chars, _, _ = roster.build_all()
    flat = []
    for c in chars:
        v = c["visual"]
        flat.append(dict(id=c["id"], rarity=c["rarity"], hair=v["hair"], hc=v["hair_color"], hc2=v["hair_accent"], eyes=v["eye_color"],
                         eyes2=v["eye_color2"], skin=v["skin"], aura=v["aura"], glasses=v["glasses"], kit=v["kit"], num=c["number"]))
    gen_field(); gen_kits(); gen_faces(flat); gen_portraits(flat); gen_frames(); gen_icons(); gen_ui(); gen_vfx(); gen_ono(); gen_app_icons()
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    if INTER.exists():
        shutil.copy(INTER, FONT_DIR / "Inter-ExtraBold.otf")
    n = sum(1 for _ in OUT.rglob("*.png"))
    size = sum(p.stat().st_size for p in OUT.rglob("*.png")) / 1e6
    print(f"OK: {n} texturas, {size:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
