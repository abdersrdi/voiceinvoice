#!/usr/bin/env python3
"""Draws the app icon: a company-stamp ring with a sound waveform inside.

    python tools/make_icon.py

Writes assets/icon.png (marketing copy) and the 1024px AppIcon in the asset catalog.
Drawn at 4x and scaled down for crisp edges. Colours: Burgundy background, Glacier Blue mark.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = 1024
SS = 4                      # supersampling
S = SIZE * SS

BURGUNDY_LIGHT = (154, 51, 71)
BURGUNDY = (107, 31, 46)
BURGUNDY_DEEP = (42, 10, 18)
GLACIER = (169, 208, 232)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background():
    img = Image.new("RGB", (S, S))
    px = img.load()
    # diagonal gradient light -> deep, computed on a small grid then resized for speed
    small = Image.new("RGB", (256, 256))
    sp = small.load()
    for y in range(256):
        for x in range(256):
            t = (x + y) / 510
            if t < 0.5:
                c = lerp(BURGUNDY_LIGHT, BURGUNDY, t / 0.5)
            else:
                c = lerp(BURGUNDY, BURGUNDY_DEEP, (t - 0.5) / 0.5)
            sp[x, y] = c
    return small.resize((S, S), Image.BICUBIC)


def draw_mark(layer):
    d = ImageDraw.Draw(layer)
    cx = cy = S // 2
    ink = GLACIER + (255,)

    # outer and inner stamp rings
    r_outer = int(S * 0.36)
    r_inner = int(S * 0.315)
    d.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], outline=ink, width=int(S * 0.026))
    d.ellipse([cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner], outline=ink, width=int(S * 0.010))

    # small tick marks around the ring, like a seal's edge
    for i in range(48):
        angle = 2 * math.pi * i / 48
        r1 = r_outer + int(S * 0.018)
        r2 = r_outer + int(S * 0.036)
        d.line(
            [cx + r1 * math.cos(angle), cy + r1 * math.sin(angle), cx + r2 * math.cos(angle), cy + r2 * math.sin(angle)],
            fill=ink, width=int(S * 0.008),
        )

    # waveform bars
    heights = [0.10, 0.20, 0.34, 0.50, 0.34, 0.24, 0.40, 0.18, 0.08]
    count = len(heights)
    bar_w = int(S * 0.036)
    gap = int(S * 0.026)
    total = count * bar_w + (count - 1) * gap
    x0 = cx - total // 2
    for i, h in enumerate(heights):
        bh = int(S * h * 0.62)
        x = x0 + i * (bar_w + gap)
        d.rounded_rectangle([x, cy - bh // 2, x + bar_w, cy + bh // 2], radius=bar_w // 2, fill=ink)


def main():
    base = background()

    mark = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_mark(mark)
    # a slight tilt makes it feel like a real stamp impression
    mark = mark.rotate(-12, resample=Image.BICUBIC, center=(S // 2, S // 2))

    glow = mark.filter(ImageFilter.GaussianBlur(S * 0.012))
    glow_alpha = glow.split()[3].point(lambda v: int(v * 0.45))
    glow_layer = Image.new("RGBA", (S, S), GLACIER + (0,))
    glow_layer.putalpha(glow_alpha)

    out = base.convert("RGBA")
    out.alpha_composite(glow_layer)
    out.alpha_composite(mark)
    out = out.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)

    marketing = os.path.join(ROOT, "assets", "icon.png")
    catalog = os.path.join(ROOT, "VoiceInvoice", "Resources", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")
    out.save(marketing)
    out.save(catalog)
    print("wrote", marketing, "and", catalog)


if __name__ == "__main__":
    main()
