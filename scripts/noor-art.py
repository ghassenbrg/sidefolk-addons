#!/usr/bin/env python3
"""Draws Noor's pictures from geometry, so nothing in them is traced from a mockup and no word is baked in:
    python3 scripts/noor-art.py [--preview out.png]
Needs Pillow, on the maker's Mac only: the pack carries the pictures. Everything is an eightfold construction on one square
lattice, one line weight per picture, in the palette of Noor's design system."""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "extensions/prayer-times/assets/art"
SS = 3  # drawn this much larger, then reduced, for clean edges

def hex_rgb(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

def poly(center, radius, count, step=1, rotate=0.0):
    """Every `step`th point of a circle: step 1 an octagon, step 3 an {8/3} star as a closed outline of its own lines."""
    cx, cy = center
    points = []
    for i in range(count):
        a = rotate + 2 * math.pi * i * step / count
        points.append((cx + radius * math.cos(a), cy + radius * math.sin(a)))
    return points

def star_outline(center, outer, inner, points=8, rotate=0.0):
    cx, cy = center
    out = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = rotate + math.pi * i / points
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out

def closed(draw, points, fill, width):
    draw.line(points + [points[0], points[1]], fill=fill, width=width, joint="curve")

def pattern(width, height, tile, ground, deep, star, line, inlay, grain_seed=7, grain=3):
    """The repeat: {8/2} stars on a square lattice with a rosette in each, and a second lattice of smaller stars between, joined by
    the lines the stars themselves extend into. It repeats exactly every `tile` points, whatever the picture's size."""
    w, h, t = width * SS, height * SS, tile * SS
    image = Image.new("RGBA", (w, h), hex_rgb(ground))
    d = ImageDraw.Draw(image)
    weight = max(2, round(1.25 * SS))
    fine = max(1, round(0.7 * SS))
    columns, rows = w // t + 3, h // t + 3
    big, small = t * 0.46, t * 0.26
    # What lies under the lines first, so a line always crosses over the fills.
    for iy in range(-1, rows):
        for ix in range(-1, columns):
            a, b = (ix * t, iy * t), ((ix + 0.5) * t, (iy + 0.5) * t)
            d.polygon(star_outline(b, small * 1.02, small * 0.62), fill=hex_rgb(deep))
            d.polygon(star_outline(a, big, big * 0.62, rotate=math.pi / 8), fill=hex_rgb(star))
            d.polygon(star_outline(a, big * 0.52, big * 0.33), fill=hex_rgb(deep))
    for iy in range(-1, rows):
        for ix in range(-1, columns):
            a, b = (ix * t, iy * t), ((ix + 0.5) * t, (iy + 0.5) * t)
            closed(d, star_outline(a, big, big * 0.62, rotate=math.pi / 8), hex_rgb(line), weight)
            closed(d, star_outline(a, big * 0.52, big * 0.33), hex_rgb(inlay), fine)
            closed(d, star_outline(b, small * 1.02, small * 0.62), hex_rgb(line), weight)
            # The bands that tie each star to its neighbours: all on the lattice's diagonals and axes.
            for k in range(8):
                angle = math.pi / 8 + k * math.pi / 4
                p0 = (a[0] + big * math.cos(angle), a[1] + big * math.sin(angle))
                # Runs on until it meets its neighbour's on the line halfway between them, so the bands close into diamonds.
                reach = (t / 2) / max(abs(math.cos(angle)), abs(math.sin(angle)))
                p1 = (a[0] + reach * math.cos(angle), a[1] + reach * math.sin(angle))
                d.line([p0, p1], fill=hex_rgb(line), width=weight)
    image = image.resize((width, height), Image.LANCZOS).convert("RGB")
    if grain:
        # A satin grain so large areas don't band; low enough never to show as texture on its own.
        random.seed(grain_seed)
        noise = Image.effect_noise((width, height), 18).convert("L").filter(ImageFilter.GaussianBlur(0.4))
        overlay = Image.merge("RGB", (noise, noise, noise))
        image = Image.blend(image, overlay, grain / 100)
    return image

def lens(center, angle, inner, outer, width, steps=28):
    """A pointed oval from `inner` to `outer` along `angle`: the rosette's petal."""
    cx, cy = center
    points = []
    length = outer - inner
    for side in (1, -1):
        for i in range(steps + 1):
            t = i / steps
            u = t if side == 1 else 1 - t
            along = inner + length * u
            across = side * width * math.sin(math.pi * u)
            x = along * math.cos(angle) - across * math.sin(angle)
            y = along * math.sin(angle) + across * math.cos(angle)
            points.append((cx + x, cy + y))
    return points

def rosette(size, line, core, glow=None, simple=False):
    s = size * SS
    image = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    c = (s / 2, s / 2)
    R = s * 0.48
    weight = round(s * (0.03 if simple else 0.017))
    for k in range(8):
        angle = -math.pi / 2 + k * math.pi / 4
        # Outer petals interlace with the inner ones, half a step round.
        closed(d, lens(c, angle, R * 0.20, R, R * 0.27), hex_rgb(line), weight)
    if not simple:
        closed(d, star_outline(c, R * 0.60, R * 0.42, rotate=-math.pi / 2 + math.pi / 8), hex_rgb(line), max(1, weight - round(s * 0.006)))
    if glow:
        halo = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        hd.ellipse([c[0] - R * 0.34, c[1] - R * 0.34, c[0] + R * 0.34, c[1] + R * 0.34], fill=hex_rgb(glow, 170))
        image = Image.alpha_composite(image, halo.filter(ImageFilter.GaussianBlur(s * 0.045)))
        d = ImageDraw.Draw(image)
    d.polygon(star_outline(c, R * 0.27, R * 0.12), fill=hex_rgb(core))
    return image.resize((size, size), Image.LANCZOS)

def skyline(width, height, far, near, seed=48):
    """Hills, and a town of domes and minarets standing on them: a place of light and evening, of no real city."""
    s = SS
    w, h = width * s, height * s
    image = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    random.seed(seed)
    def hills(color, base, amp, freq, phase):
        points = [(0, h)]
        for x in range(0, w + 8, 8):
            y = base + amp * (math.sin(x * freq + phase) + 0.45 * math.sin(x * freq * 2.3 + phase * 2) + 0.2 * math.sin(x * freq * 5.1 + phase))
            points.append((x, y))
        points.append((w, h))
        d.polygon(points, fill=hex_rgb(color))
    hills(far, h * 0.42, h * 0.10, 2 * math.pi / (w * 0.42), 0.4)
    hills(near, h * 0.66, h * 0.07, 2 * math.pi / (w * 0.31), 1.9)
    # The town stands toward the far end, so words at the start stay on quiet hills.
    def dome(x, base, r):
        d.rectangle([x - r, base - r * 0.7, x + r, h], fill=hex_rgb(near))
        d.pieslice([x - r, base - r * 1.7, x + r, base - r * 0.1], 180, 360, fill=hex_rgb(near))
        d.polygon([(x - r * 0.18, base - r * 1.5), (x, base - r * 2.3), (x + r * 0.18, base - r * 1.5)], fill=hex_rgb(near))
    def minaret(x, base, tall, r):
        d.rectangle([x - r, base - tall, x + r, h], fill=hex_rgb(near))
        d.rectangle([x - r * 1.7, base - tall * 0.72, x + r * 1.7, base - tall * 0.66], fill=hex_rgb(near))
        d.pieslice([x - r * 1.05, base - tall - r * 1.2, x + r * 1.05, base - tall + r], 180, 360, fill=hex_rgb(near))
        d.polygon([(x - r * 0.5, base - tall - r * 0.6), (x, base - tall - r * 3.2), (x + r * 0.5, base - tall - r * 0.6)], fill=hex_rgb(near))
    base = h * 0.80
    x0 = w * 0.70
    unit = h * 0.11
    dome(x0, base, unit * 1.5)
    dome(x0 - unit * 2.5, base, unit * 0.95)
    dome(x0 + unit * 2.5, base, unit * 0.95)
    minaret(x0 - unit * 4.5, base, unit * 3.8, unit * 0.26)
    minaret(x0 + unit * 4.5, base, unit * 3.8, unit * 0.26)
    dome(x0 + unit * 8.0, base + unit * 0.2, unit * 0.8)
    minaret(x0 + unit * 10.0, base, unit * 2.6, unit * 0.2)
    minaret(x0 - unit * 8.0, base, unit * 2.4, unit * 0.2)
    return image.resize((width, height), Image.LANCZOS)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pattern(1800, 1400, 100, "#141735", "#1D2553", "#293C86", "#C08257", "#C9AB72").save(OUT / "pattern-dark.jpg", quality=88, subsampling=0, optimize=True)
    pattern(1800, 1400, 100, "#E9E2F4", "#F5F0ED", "#C9BEEC", "#7354B8", "#C9AB72", grain=2).save(OUT / "pattern-light.jpg", quality=90, subsampling=0, optimize=True)
    rosette(512, "#E3C98D", "#F7E7B8", glow="#F7E7B8").save(OUT / "rosette-dark.png", optimize=True)
    rosette(512, "#293C86", "#C9AB72").save(OUT / "rosette-light.png", optimize=True)
    skyline(2000, 300, "#262B62", "#191C44").save(OUT / "skyline-dark.png", optimize=True)
    skyline(2000, 300, "#C4BBE8", "#9D91D6").save(OUT / "skyline-light.png", optimize=True)
    for f in sorted(OUT.iterdir()):
        print(f.name, f.stat().st_size // 1024, "KB")

main()
