"""Generate the complete Google Play Store asset pack for Pocket Kin.

Outputs to artifacts/play-assets/ (gitignored):

  store-listing/
    icon-512.png                       Play icon (512x512, 32-bit PNG)
    feature-graphic-1024x500.png       Feature graphic (1024x500)
    phone-1..5.png                     Phone screenshots (1080x2340, <=8 for listing)
    tablet-1..2.png                    7"/10" tablet screenshots (1600x2560)
    wear-1..3.png                      Wear OS screenshots (1024x1032, round watch)
  graphic-assets/ (Play Console "Graphic assets" task)
    logo-512.png                       512x512 logo
    banner-1000x500.png                Promo banner (tablet/TV-style slot)
    promo-1..3.png                     Promo variants (1024x500)

Usage:
    python tools/generate_play_assets.py [--out artifacts/play-assets]

Source material: game/assets/launcher-final.png + screenshots/*.png, framed on
generated Pocket Kin wallpapers.
"""

from __future__ import annotations

import argparse
import os
import random
from typing import Callable

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAUNCHER = os.path.join(ROOT, "game", "assets", "launcher-final.png")
SCREENS_DIR = os.path.join(ROOT, "screenshots")

INK = (62, 58, 46)
MUTED = (122, 109, 92)
CREAM = (250, 246, 237)

# (kind, source file, headline, subline)
SHOTS: list[tuple[str, str, str, str]] = [
    ("phone", "phone_widget.png", "At a glance, all day long", "Your pet greets you from the home-screen widget."),
    ("phone", "phone_sanctuary.png", "A friend who grows with you", "Feed, cuddle and bathe your little companion."),
    ("phone", "phone_bath.png", "Splish-splash bubble bath", "Pop bubbles into sparkling hearts."),
    ("phone", "phone_picnic.png", "Fruit picnic", "Toss treats and find their favorite fruits."),
    ("phone", "phone_walk.png", "Walk Together", "Optional steps become care and little parcels."),
    ("wear", "wear_pet_status.png", "A glance at your wrist", "Pet mood, needs and quick care."),
    ("wear", "wear_health_dashboard.png", "Health in harmony", "Steps, heartbeat rhythm and hydration."),
    ("wear", "wear_live_sync.png", "Always in sync", "Phone and watch share one cozy save."),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    base = r"C:\Windows\Fonts"
    path = os.path.join(base, "arialbd.ttf" if bold else "arial.ttf")
    if not os.path.exists(path):
        path = os.path.join(base, "segoeui.ttf")
    return ImageFont.truetype(path, size)


def center_text(draw: ImageDraw.ImageDraw, y: int, text: str, f: ImageFont.FreeTypeFont,
                fill=INK, w: int | None = None) -> None:
    if w is None:
        w = draw._image.width  # type: ignore[attr-defined]
    tw = draw.textlength(text, font=f)
    draw.text(((w - tw) / 2, y), text, font=f, fill=fill)


# ---------------------------------------------------------------- wallpapers


def wallpaper_morning(w: int, h: int, seed: int = 7) -> Image.Image:
    img = Image.new("RGB", (w, h), CREAM)
    top, mid = (252, 244, 226), (240, 228, 198)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (mid[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    d.ellipse((w * 0.70, h * 0.08, w * 0.82, h * 0.16), fill=(255, 238, 187))
    hills = [((0.0, 0.64), (1.0, 0.64), (184, 205, 160)),
             ((0.30, 0.72), (1.0, 0.72), (164, 189, 141)),
             ((0.55, 0.80), (1.0, 0.80), (146, 176, 124))]
    for (x0, y0), (x1, y1), color in hills:
        peak = ((x0 + x1) / 2, y0 - 0.05)
        d.polygon([(w * x0, h * y0), (w * peak[0], h * peak[1]), (w * x1, h * y1), (w, h), (0, h)],
                  fill=color)
    rng = random.Random(seed)
    for _ in range(9):
        x, y = rng.randrange(w), rng.randrange(int(h * 0.72), int(h * 0.92))
        r = rng.uniform(4, 10)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255))
        d.ellipse((x - r * 0.35, y - r, x + r * 0.35, y - r * 0.1), fill=(255, 252, 240))
    return img


def wallpaper_meadow(w: int, h: int, seed: int = 11) -> Image.Image:
    img = wallpaper_morning(w, h, seed)
    d = ImageDraw.Draw(img)
    rng = random.Random(seed + 1)
    for _ in range(56):
        x = rng.randrange(w)
        y = rng.randrange(int(h * 0.72), int(h * 0.94))
        s = rng.uniform(3, 7)
        color = rng.choice([(255, 196, 206), (250, 224, 137), (198, 222, 241), (255, 255, 255)])
        d.ellipse((x - s, y - s, x + s, y + s), fill=color)
        d.line((x, y + s, x, y + s * 2.2), fill=(129, 152, 106), width=2)
    return img


def wallpaper_dusk(w: int, h: int, seed: int = 3, bushes: bool = True, moon: bool = True) -> Image.Image:
    img = Image.new("RGB", (w, h), (26, 28, 44))
    top, mid, bottom = (24, 26, 46), (58, 52, 84), (104, 84, 110)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        if t < 0.55:
            u = t / 0.55
            c = tuple(int(top[i] + (mid[i] - top[i]) * u) for i in range(3))
        else:
            u = (t - 0.55) / 0.45
            c = tuple(int(mid[i] + (bottom[i] - mid[i]) * u) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    rng = random.Random(seed)
    for _ in range(140):
        x, y = rng.randrange(w), rng.randrange(int(h * 0.55))
        r = rng.uniform(0.6, 2.0)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(235, 235, 220))
    mx, my = w * 0.76, h * 0.12
    if moon:
        d.ellipse((mx - 46, my - 46, mx + 46, my + 46), fill=(245, 240, 220))
        d.ellipse((mx - 38, my - 40, mx + 38, my + 38), fill=(238, 232, 208))
    if bushes:
        for cx, cy, cr in ((w * 0.18, h * 0.80, 60), (w * 0.55, h * 0.74, 44), (w * 0.88, h * 0.84, 72)):
            d.ellipse((cx - cr, cy - cr * 0.35, cx + cr, cy + cr * 0.35), fill=(30, 34, 36))
    return img


def wallpaper_pond(w: int, h: int, seed: int = 5) -> Image.Image:
    img = wallpaper_dusk(w, h, seed)
    d = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(seed + 9)
    for _ in range(26):
        y = rng.randrange(int(h * 0.82), h - 4)
        x0 = rng.randrange(0, w - w // 6)
        ln = rng.randrange(w // 8, w // 3)
        d.line((x0, y, x0 + ln, y), fill=(210, 216, 230, 70), width=2)
    return img


WALLPAPERS: dict[str, Callable[[int, int], Image.Image]] = {
    "morning": wallpaper_morning,
    "meadow": wallpaper_meadow,
    "dusk": wallpaper_dusk,
    "pond": wallpaper_pond,
}


# ---------------------------------------------------------------- builders


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return m


def framed_shot(source: str, inner_w: int, radius: int, top: int) -> tuple[Image.Image, tuple[int, int]]:
    src = Image.open(os.path.join(SCREENS_DIR, source)).convert("RGB")
    inner_h = int(inner_w * src.height / src.width)
    shot = src.resize((inner_w, inner_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (shot.width + 24, shot.height + 24), (0, 0, 0, 0))
    canvas.paste(shot, (12, 12), rounded_mask(shot.size, radius))
    ImageDraw.Draw(canvas).rounded_rectangle((12, 12, 12 + shot.width - 1, 12 + shot.height - 1),
                                             radius=radius, outline=(90, 80, 66, 255), width=6)
    return canvas, (inner_w // 2 + 12, top + inner_h + 12)


def build_phone_screenshot(source: str, cap1: str, cap2: str) -> Image.Image:
    W, H = 1080, 2340
    canvas = wallpaper_morning(W, H).convert("RGBA")
    frame, _ = framed_shot(source, 680, 48, 0)
    canvas.alpha_composite(frame, ((W - frame.width) // 2, 400))
    d = ImageDraw.Draw(canvas)
    icon = Image.open(LAUNCHER).convert("RGBA").resize((140, 140), Image.LANCZOS)
    canvas.alpha_composite(icon, (W // 2 - 70, 170))
    center_text(d, 1990, cap1, font(64, True), INK, W)
    center_text(d, 2090, cap2, font(44), MUTED, W)
    return canvas.convert("RGB")


def build_tablet_screenshot(source: str, cap1: str, cap2: str) -> Image.Image:
    W, H = 1600, 2560
    canvas = wallpaper_meadow(W, H).convert("RGBA")
    frame, _ = framed_shot(source, 980, 56, 0)
    canvas.alpha_composite(frame, ((W - frame.width) // 2, 700))
    d = ImageDraw.Draw(canvas)
    center_text(d, 200, cap1, font(92, True), INK, W)
    center_text(d, 340, cap2, font(60), MUTED, W)
    icon = Image.open(LAUNCHER).convert("RGBA").resize((170, 170), Image.LANCZOS)
    canvas.alpha_composite(icon, (W // 2 - 85, 480))
    return canvas.convert("RGB")


def build_wear_screenshot(source: str, cap1: str, cap2: str) -> Image.Image:
    W, H = 1024, 1032
    canvas = wallpaper_dusk(W, H, bushes=False, moon=False).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    d.ellipse((60, 70, 118, 128), fill=(245, 240, 220))
    d.ellipse((72, 64, 130, 122), fill=(32, 34, 52))
    src = Image.open(os.path.join(SCREENS_DIR, source)).convert("RGB")
    watch = src.resize((430, 430), Image.LANCZOS)
    circ = Image.new("L", watch.size, 0)
    ImageDraw.Draw(circ).ellipse((0, 0, watch.width - 1, watch.height - 1), fill=255)
    cx, cy = W // 2, 510
    d.ellipse((cx - 243, cy - 243, cx + 243, cy + 243), fill=(248, 244, 234))
    canvas.paste(watch, (cx - 215, cy - 215), circ)
    d.ellipse((cx - 231, cy - 231, cx + 231, cy + 231), outline=(90, 80, 66), width=8)
    center_text(d, 80, cap1, font(52, True), (246, 242, 230), W)
    center_text(d, 158, cap2, font(38), (214, 208, 196), W)
    icon = Image.open(LAUNCHER).convert("RGBA").resize((110, 110), Image.LANCZOS)
    canvas.alpha_composite(icon, (W // 2 - 55, 850))
    return canvas.convert("RGB")


def build_feature_graphic() -> Image.Image:
    W, H = 1024, 500
    bg = wallpaper_meadow(W, H, seed=13).convert("RGBA")
    icon = Image.open(LAUNCHER).convert("RGBA").resize((280, 280), Image.LANCZOS)
    bg.alpha_composite(icon, (84, 110))
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((72, 98, 376, 402), radius=64, outline=(255, 255, 255), width=6)
    d.text((420, 140), "Pocket Kin", font=font(86, True), fill=INK)
    d.text((424, 264), "Hatch it. Care for it.", font=font(38), fill=MUTED)
    d.text((424, 320), "Walk together. Grow together.", font=font(38), fill=MUTED)
    return bg.convert("RGB")


def build_promo(variant: int) -> Image.Image:
    W, H = 1024, 500
    bg = [wallpaper_morning, wallpaper_meadow, wallpaper_pond][variant % 3](W, H).convert("RGBA")
    icon = Image.open(LAUNCHER).convert("RGBA").resize((210, 210), Image.LANCZOS)
    bg.alpha_composite(icon, (70, 145))
    d = ImageDraw.Draw(bg)
    headlines = [
        ("Hatch a cozy friend", "Six species · three mini-games · decorating"),
        ("A pocket-sized pet", "Gentle care, growth and cozy outings"),
        ("Walk together", "Optional steps become shared adventures"),
    ]
    title, sub = headlines[variant % 3]
    d.text((320, 160), title, font=font(66, True), fill=INK)
    d.text((324, 262), sub, font=font(34), fill=MUTED)
    return bg.convert("RGB")


def build_banner() -> Image.Image:
    W, H = 1000, 500
    bg = wallpaper_meadow(W, H, seed=17).convert("RGBA")
    icon = Image.open(LAUNCHER).convert("RGBA").resize((230, 230), Image.LANCZOS)
    bg.alpha_composite(icon, ((W - 230) // 2, 50))
    d = ImageDraw.Draw(bg)
    center_text(d, 320, "Pocket Kin", font(68, True), INK, W)
    return bg.convert("RGB")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "artifacts", "play-assets"))
    args = ap.parse_args()
    listing = os.path.join(args.out, "store-listing")
    graphics = os.path.join(args.out, "graphic-assets")
    os.makedirs(listing, exist_ok=True)
    os.makedirs(graphics, exist_ok=True)

    src = Image.open(LAUNCHER).convert("RGBA")
    side = min(src.size)
    left, top = (src.width - side) // 2, (src.height - side) // 2
    icon512 = src.crop((left, top, left + side, top + side)).resize((512, 512), Image.LANCZOS)
    icon512.save(os.path.join(listing, "icon-512.png"))

    build_feature_graphic().save(os.path.join(listing, "feature-graphic-1024x500.png"))

    phone_i = wear_i = 0
    for kind, source, cap1, cap2 in SHOTS:
        if kind == "phone":
            phone_i += 1
            build_phone_screenshot(source, cap1, cap2).save(os.path.join(listing, f"phone-{phone_i}.png"))
        else:
            wear_i += 1
            build_wear_screenshot(source, cap1, cap2).save(os.path.join(listing, f"wear-{wear_i}.png"))

    for i in range(2):
        _, source, cap1, cap2 = SHOTS[i]
        build_tablet_screenshot(source, cap1, cap2).save(os.path.join(listing, f"tablet-{i + 1}.png"))

    for i in range(3):
        build_promo(i).save(os.path.join(graphics, f"promo-{i + 1}.png"))
    icon512.save(os.path.join(graphics, "logo-512.png"))
    build_banner().save(os.path.join(graphics, "banner-1000x500.png"))

    print(f"Play assets written to {args.out}")


if __name__ == "__main__":
    main()
