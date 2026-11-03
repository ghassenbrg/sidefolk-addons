#!/usr/bin/env python3
"""Noor's night strip (prayer-night-l/d.jpg), from the pack's own hero pictures. Tonight's boards have hills from edge to edge, the mosque past the
middle and words on quiet ground, so the hero's hills go on past it both ways as mirrored copies of its own left part, and sky and foot melt into the
strip's ground: a scene can place the mosque anywhere with no edge to fade out.
prayer-rim-left/right-*: P02's two ends of the strip, its lattice cut along the window's edge with the inlay on it. As tall as the strip. Usage: noor-night-art.py <assets/art>"""
import sys
from PIL import Image, ImageDraw

art = sys.argv[1]
W, H = 3000, 500
HERO_W = 1080                     # the hero's share of the width
MOSQUE_AT, FOOT_AT = 0.60, 0.68   # where the mosque stands and where everything ends: `PrayerPage.nightArt` knows these


def clamp(x):
    return max(0.0, min(1.0, x))


def strip(name, ground, hills, melt):
    hero = Image.open(f"{art}/hero-{name}.jpg").convert("RGB")
    hero = hero.resize((HERO_W, round(hero.height * HERO_W / hero.width)), Image.LANCZOS)
    x0, foot = round(W * MOSQUE_AT - HERO_W * 0.86), round(H * FOOT_AT)
    y0 = foot - hero.height
    left = hero.crop((0, 0, round(HERO_W * 0.6), hero.height))
    flipped = left.transpose(Image.FLIP_LEFT_RIGHT)
    canvas = Image.new("RGB", (W, H), ground)
    # Outwards from the hero, each copy the mirror of the last, so the hills run on without a step.
    for x, step in ((x0 - left.width, -left.width), (x0 + HERO_W - 50, left.width)):
        use = flipped
        while -left.width < x < W:
            canvas.paste(use, (x, y0))
            x += step
            use = left if use is flipped else flipped
    # The hero itself, its right edge melted into what follows.
    edge = Image.new("L", (HERO_W, 1))
    edge.putdata([round(255 * clamp((HERO_W - x) / 50)) for x in range(HERO_W)])
    canvas.paste(hero, (x0, y0), edge.resize(hero.size))
    # How much of the picture stays at each height: none at the top, the hills held down, none past the foot where the words stand.
    hill_top = (foot - hero.height * 0.32) / H
    keep = []
    for y in range(H):
        t = y / H
        k = clamp((t - (hill_top - 0.3)) / 0.36)
        k = hills * k * k * (3 - 2 * k)
        keep.append(round(255 * k * clamp((FOOT_AT + 0.01 - t) / melt)))
    mask = Image.new("L", (1, H))
    mask.putdata(keep)
    Image.composite(canvas, Image.new("RGB", (W, H), ground), mask.resize((W, H))).save(f"{art}/prayer-night-{name}.jpg", quality=86, optimize=True)


strip("d", (14, 18, 52), 0.6, 0.14)
# The light hero's foot has lattice drawn in it: only its far hills stay.
strip("l", (247, 243, 251), 0.65, 0.30)


def bezier(points, n=40):
    # Cubic pieces as [start, c1, c2, end, c1, c2, end, ...].
    out = []
    for i in range(0, len(points) - 1, 3):
        p0, p1, p2, p3 = points[i:i + 4]
        for k in range(n + 1):
            s = k / n; u = 1 - s
            out.append(tuple(u**3 * a + 3 * u * u * s * b + 3 * u * s * s * c + s**3 * d for a, b, c, d in zip(p0, p1, p2, p3)))
    return out


# The window's edge in shares of the strip's height, from the boards.
RIGHT = (0.73, [(0, 0), (0.10, 0.02), (0.17, 0.09), (0.225, 0.175), (0.30, 0.19), (0.44, 0.19), (0.53, 0.225), (0.58, 0.25), (0.61, 0.29), (0.61, 0.35),
                (0.61, 0.5), (0.61, 0.62), (0.61, 0.76), (0.61, 0.87), (0.46, 0.96), (0.30, 1.0)], [(0.73, 1), (0.73, 0)])
LEFT = (0.30, [(0, 0.20), (0.07, 0.24), (0.20, 0.33), (0.28, 0.45), (0.20, 0.52), (0.15, 0.62), (0.16, 0.74), (0.165, 0.84), (0.18, 0.92), (0.20, 1.0)], [(0, 1)])


def rim(side, shape, name, edge):
    width, curve, rest = shape
    H, ss = 420, 3
    w = round(H * width)
    plate = Image.open(f"{art}/prayer-lattice-{name}.jpg").convert("RGB")
    # Half the plate's height, so its cells are the board's size on a strip this short.
    plate = plate.crop((0, 0, round(plate.height * width / 2), plate.height // 2)).resize((w, H), Image.LANCZOS).convert("RGBA")
    line = [(x * H * ss, y * H * ss) for x, y in bezier(curve)]
    mask = Image.new("L", (w * ss, H * ss), 0)
    ImageDraw.Draw(mask).polygon(line + [(x * H * ss, y * H * ss) for x, y in rest], fill=255)
    plate.putalpha(mask.resize((w, H), Image.LANCZOS))
    stroke = Image.new("RGBA", (w * ss, H * ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(stroke)
    draw.line(line, fill=edge, width=int(2.2 * ss), joint="curve")
    # The inlay's second, thinner line, just inside the lattice.
    step = 6 * ss * (1 if side == "right" else -1)
    draw.line([(x + step, y) for x, y in line], fill=edge[:3] + (150,), width=int(1 * ss), joint="curve")
    plate.alpha_composite(stroke.resize((w, H), Image.LANCZOS))
    plate.save(f"{art}/prayer-rim-{side}-{name}.png", optimize=True)


for side, shape in (("right", RIGHT), ("left", LEFT)):
    rim(side, shape, "d", (217, 130, 110, 255))
    rim(side, shape, "l", (201, 171, 114, 255))
