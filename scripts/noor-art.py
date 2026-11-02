#!/usr/bin/env python3
"""Noor's pictures, from what scripts/noor-art-briefs.py generated (not kept here: `raw`) to what the pack ships.
Frames and grounds stay as painted. Ornaments painted on flat black or white lose that ground; the dial's parts are drawn here."""
import math, os, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

raw, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)

def load(name): return Image.open(f"{raw}/{name}.png").convert("RGB")

def jpg(name, to, width, crop=None, q=86):
    im = load(name)
    if crop:
        w, h = im.size
        im = im.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))
    if im.width > width: im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    im.save(f"{out}/{to}.jpg", quality=q, optimize=True, progressive=True)

def cut(name, to, ground, width, trim=True):
    """Whatever touches the corners in the flat ground colour goes; the rest stays whole, its edge softened."""
    im = load(name)
    if im.width > width: im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    w, h = im.size
    flat = Image.new("RGB", (w, h), ground)
    diff = ImageChops.difference(im, flat).convert("L").point(lambda v: 255 if v > 30 else 0)
    mask = diff.copy()
    for corner in [(0, h - 1), (w - 1, h - 1), (0, 0), (w - 1, 0)]:
        if mask.getpixel(corner) == 0: ImageDraw.floodfill(mask, corner, 128)
    alpha = mask.point(lambda v: 0 if v == 128 else 255).filter(ImageFilter.GaussianBlur(0.8))
    im.putalpha(alpha)
    if trim: im = im.crop(alpha.getbbox())
    im.save(f"{out}/{to}.png", optimize=True)

for look, d in (("dark", "d"), ("light", "l")):
    jpg(f"frame-dial-{look}", f"frame-dial-{d}", 1400)
    jpg(f"frame-square-{look}", f"frame-square-{d}", 1254)
    jpg(f"frame-portrait-{look}", f"frame-portrait-{d}", 1074)
    jpg(f"lattice-{look}", f"lattice-{d}", 1400, q=80)
    jpg(f"tonight-{look}", f"tonight-{d}", 1536, crop=(0, 0.42, 1, 0.92))
    jpg(f"hero-{look}", f"hero-{d}", 1536, crop=(0, 0.30, 1, 0.84))
    jpg(f"ground-{look}", f"ground-{d}", 1536, q=78)
    cut(f"pendant-{look}", f"pendant-{d}", (0, 0, 0) if look == "dark" else (255, 255, 255), 1400)
    cut(f"corner-{look}", f"corner-{d}", (0, 0, 0) if look == "dark" else (255, 255, 255), 720, trim=False)
jpg("ramadan-arch", "ramadan-arch-d", 560)
jpg("ramadan-arch-light", "ramadan-arch-l", 560)
jpg("preview-dark", "preview", 800)
jpg("prefs-pane", "prefs-pane", 500)
cut("rosette-gold", "rosette-d", (0, 0, 0), 420)
cut("rosette-ink", "rosette-l", (255, 255, 255), 420)

# The dial's parts. Painted at twice their largest size on a page.
SIDE = 1000

def radial(inner, outer, power=1.0):
    im = Image.new("L", (SIDE, SIDE)); px = im.load(); c = SIDE / 2
    for y in range(SIDE):
        for x in range(SIDE):
            t = min(1, math.hypot(x - c, y - c) / c) ** power
            px[x, y] = round(inner + (outer - inner) * t)
    return im

def disc(side=SIDE):
    m = Image.new("L", (side * 2, side * 2)); ImageDraw.Draw(m).ellipse((0, 0, side * 2 - 1, side * 2 - 1), fill=255)
    return m.resize((side, side), Image.LANCZOS)

rosette = load("rosette-gold").resize((SIDE, SIDE), Image.LANCZOS).convert("L")
def face(to, inner, outer, line, strength):
    a, b = Image.new("RGB", (SIDE, SIDE), inner), Image.new("RGB", (SIDE, SIDE), outer)
    im = Image.composite(b, a, radial(0, 255, 1.6))
    im = Image.composite(Image.new("RGB", (SIDE, SIDE), line), im, rosette.point(lambda v: min(255, int(v * strength))))
    im.putalpha(disc())
    im.resize((640, 640), Image.LANCZOS).save(f"{out}/{to}.png", optimize=True)
face("dial-face-d", (20, 24, 62), (10, 12, 38), (58, 66, 140), 0.16)
face("dial-face-l", (255, 255, 255), (246, 242, 252), (206, 196, 232), 0.20)

# The ring's grain and bevel: light and shade only, over whatever colours the day gives it.
big = SIDE * 2
ring = Image.new("RGBA", (big, big), (0, 0, 0, 0)); dr = ImageDraw.Draw(ring); c = big / 2; R, r = c - 2, c * 0.86
for i in range(0, 720):
    a = math.radians(i / 2); ca, sa = math.cos(a), math.sin(a)
    dr.line((c + r * ca, c + r * sa, c + R * ca, c + R * sa), fill=(255, 255, 255, 13 if i % 2 else 0), width=2)
dr.ellipse((c - R, c - R, c + R, c + R), outline=(255, 255, 255, 70), width=4)
dr.ellipse((c - R + 12, c - R + 12, c + R - 12, c + R - 12), outline=(0, 0, 0, 90), width=10)
dr.ellipse((c - r, c - r, c + r, c + r), outline=(0, 0, 0, 130), width=12)
dr.ellipse((c - r - 8, c - r - 8, c + r + 8, c + r + 8), outline=(255, 255, 255, 70), width=4)
ring.resize((800, 800), Image.LANCZOS).save(f"{out}/dial-ring.png", optimize=True)

# A soft light to tint.
g = radial(255, 0, 0.55).point(lambda v: min(255, int(v * 1.0)))
glow = Image.new("RGBA", (SIDE, SIDE), (255, 255, 255, 0)); glow.putalpha(g)
glow.resize((128, 128), Image.LANCZOS).save(f"{out}/glow.png", optimize=True)

# The pack's icon, rounded as macOS does, under the limit a manifest's icon has.
icon = load("icon").resize((512, 512), Image.LANCZOS)
m = Image.new("L", (2048, 2048)); ImageDraw.Draw(m).rounded_rectangle((0, 0, 2047, 2047), radius=460, fill=255)
icon.putalpha(m.resize((512, 512), Image.LANCZOS))
icon.quantize(colors=200, method=Image.FASTOCTREE, dither=Image.NONE).save(f"{out}/../../icon.png", optimize=True)
