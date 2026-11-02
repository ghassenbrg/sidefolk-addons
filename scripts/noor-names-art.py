#!/usr/bin/env python3
"""What the Names and Qibla pages cut from the painted square frame, so it is all one material. Usage: noor-names-art.py <assets/art>
spandrel-*: the thin lattice under one curve with an inlaid edge, top right; a page flips it for the top left.
frame-name-*: the same frame with its window quiet out to the arch, as P06 has it (the frame itself keeps lattice up to the compass, as P05 does).
names-arch-* isn't here: it was generated from a crop of F04 with its words removed, and a light version of that."""
import sys
from PIL import Image, ImageDraw, ImageFilter

art = sys.argv[1]
S, ss = 240, 3

def curve(n=120):
    # From the top to the far side, bulging to the corner: what stays dark is an arch's shoulder.
    p0, p1, p2, p3 = (0.02, 0.0), (0.58, 0.02), (0.98, 0.38), (1.0, 1.0)
    for i in range(n + 1):
        t = i / n; u = 1 - t
        yield tuple((u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d) * S * ss for a, b, c, d in zip(p0, p1, p2, p3))

for look, edge in (("d", (226, 142, 92, 255)), ("l", (201, 171, 114, 255))):
    frame = Image.open(f"{art}/frame-square-{look}.jpg").convert("RGB")
    # The corner between the frame's edge and its arch, all lattice.
    tile = frame.crop((36, 36, 276, 276)).resize((S, S), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (S * ss, S * ss), 0)
    line = list(curve())
    ImageDraw.Draw(mask).polygon(line + [(S * ss, 0)], fill=255)
    tile.putalpha(mask.resize((S, S), Image.LANCZOS))
    stroke = Image.new("RGBA", (S * ss, S * ss), (0, 0, 0, 0))
    ImageDraw.Draw(stroke).line(line, fill=edge, width=int(2.4 * ss), joint="curve")
    tile.alpha_composite(stroke.resize((S, S), Image.LANCZOS))
    tile.save(f"{art}/spandrel-{look}.png", optimize=True)

# The window, in the frame's own pixels (1254 across, symmetrical about the middle): under the small dome's arch, out to the gold line, round the foils at the foot.
half = [(627, 66), (590, 92), (500, 136), (410, 192), (368, 232), (346, 272), (338, 302), (262, 322), (190, 372), (142, 436), (122, 520), (120, 948),
        (172, 982), (208, 1040), (222, 1092), (272, 1124), (306, 1170), (326, 1218)]
window = half + [(1254 - x, y) for x, y in reversed(half)]
for look, ground in (("d", (11, 13, 46)), ("l", (250, 247, 252))):
    frame = Image.open(f"{art}/frame-square-{look}.jpg").convert("RGB")
    mask = Image.new("L", frame.size, 0)
    ImageDraw.Draw(mask).polygon(window, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(3))
    # A ghost of the lattice stays, as the boards have it.
    quiet = Image.blend(Image.new("RGB", frame.size, ground), frame, 0.09)
    Image.composite(quiet, frame, mask).save(f"{art}/frame-name-{look}.jpg", quality=86, optimize=True, progressive=True)
