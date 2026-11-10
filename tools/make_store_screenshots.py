#!/usr/bin/env python3
"""Turns the raw simulator screenshots into App Store marketing screenshots.

    python tools/make_store_screenshots.py <iphone Shots dir> <ipad Shots dir>

Writes store/screenshots/iphone-6.9/*.png (1320x2868) and store/screenshots/ipad-13/*.png (2064x2752):
the screen on a Burgundy gradient with a short headline. These are the sizes App Store Connect
accepts for the 6.9-inch iPhone and 13-inch iPad slots.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BURGUNDY_LIGHT = (154, 51, 71)
BURGUNDY = (107, 31, 46)
BURGUNDY_DEEP = (42, 10, 18)
GLACIER = (169, 208, 232)
WHITE = (255, 255, 255)

# (raw file, headline, sub-line)
SLIDES = [
    ("04-dictation.png", "Speak your sale", "Say the items and prices. The invoice builds itself."),
    ("05-editor.png", "Review in one tap", "Check and edit everything before you send."),
    ("03-invoice-pdf-bottom.png", "Your stamp and signature", "On every PDF, automatically."),
    ("01-invoices.png", "All your invoices in one place", "Totals, status and search at a glance."),
    ("08-counter-mode.png", "Hands-free at the counter", "Just say \u201cNew invoice\u201d."),
    ("11-team.png", "Know who is speaking", "Voice profiles for your whole team."),
    ("09-shop.png", "Invoices in 5 languages", "English, Fran\u00e7ais, Espa\u00f1ol, Italiano, \u7b80\u4f53\u4e2d\u6587."),
]

FONT_BOLD = ["C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/arialbd.ttf"]
FONT_REGULAR = ["C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"]
FONT_CJK = ["C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/simsun.ttc"]


def load_font(candidates, size):
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def gradient(size):
    w, h = size
    small = Image.new("RGB", (128, 256))
    px = small.load()
    for y in range(256):
        for x in range(128):
            t = (y / 255) * 0.75 + (x / 127) * 0.25
            if t < 0.5:
                c = tuple(int(BURGUNDY_LIGHT[i] + (BURGUNDY[i] - BURGUNDY_LIGHT[i]) * (t / 0.5)) for i in range(3))
            else:
                c = tuple(int(BURGUNDY[i] + (BURGUNDY_DEEP[i] - BURGUNDY[i]) * ((t - 0.5) / 0.5)) for i in range(3))
            px[x, y] = c
    return small.resize((w, h), Image.BICUBIC)


def wrap(draw, text, font, max_width):
    words = text.split(" ")
    lines, current = [], ""
    for word in words:
        trial = (current + " " + word).strip()
        if draw.textlength(trial, font=font) <= max_width or not current:
            current = trial
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def compose(raw_path, headline, subline, canvas_size, shot_width_ratio, top_text, title_size, sub_size, shot_top, radius):
    W, H = canvas_size
    canvas = gradient(canvas_size).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    title_font = load_font(FONT_BOLD, title_size)
    sub_font = load_font(FONT_REGULAR, sub_size)
    if any(ord(ch) > 0x2e80 for ch in subline):
        sub_font = load_font(FONT_CJK, sub_size)

    max_text = int(W * 0.86)
    y = top_text
    for line in wrap(draw, headline, title_font, max_text):
        w = draw.textlength(line, font=title_font)
        draw.text(((W - w) / 2, y), line, font=title_font, fill=WHITE)
        y += int(title_size * 1.12)
    y += int(sub_size * 0.3)
    for line in wrap(draw, subline, sub_font, max_text):
        w = draw.textlength(line, font=sub_font)
        draw.text(((W - w) / 2, y), line, font=sub_font, fill=GLACIER)
        y += int(sub_size * 1.25)

    shot = Image.open(raw_path).convert("RGBA")
    target_w = int(W * shot_width_ratio)
    target_h = int(shot.height * target_w / shot.width)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)

    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, target_w, target_h], radius=radius, fill=255)
    x = (W - target_w) // 2

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle([x, shot_top + 24, x + target_w, shot_top + target_h + 24], radius=radius, fill=150)
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(40))
    shadow.putalpha(shadow_mask)
    canvas.alpha_composite(shadow)

    canvas.paste(shot, (x, shot_top), mask)
    ImageDraw.Draw(canvas).rounded_rectangle(
        [x, shot_top, x + target_w, shot_top + target_h], radius=radius, outline=(255, 255, 255, 70), width=4
    )
    return canvas.convert("RGB")


def build(source_dir, out_dir, canvas_size, **settings):
    os.makedirs(out_dir, exist_ok=True)
    made = 0
    for index, (name, headline, subline) in enumerate(SLIDES, start=1):
        raw = os.path.join(source_dir, name)
        if not os.path.exists(raw):
            print("  missing", name)
            continue
        image = compose(raw, headline, subline, canvas_size, **settings)
        out = os.path.join(out_dir, f"{index:02d}-{os.path.splitext(name)[0].split('-', 1)[1]}.png")
        image.save(out, optimize=True)
        made += 1
    print(f"{out_dir}: {made} images at {canvas_size[0]}x{canvas_size[1]}")


def main():
    iphone_dir, ipad_dir = sys.argv[1], sys.argv[2]
    build(
        iphone_dir, os.path.join(ROOT, "store", "screenshots", "iphone-6.9"), (1320, 2868),
        shot_width_ratio=0.80, top_text=150, title_size=104, sub_size=52, shot_top=620, radius=70,
    )
    build(
        ipad_dir, os.path.join(ROOT, "store", "screenshots", "ipad-13"), (2064, 2752),
        shot_width_ratio=0.74, top_text=130, title_size=128, sub_size=62, shot_top=560, radius=60,
    )


if __name__ == "__main__":
    main()
