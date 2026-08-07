#!/usr/bin/env python3
"""Simulate the StonePanel frame with the new kit assets and put it
side-by-side with the mockup, at device scale and 2x zoom."""
from PIL import Image, ImageDraw, ImageFilter
import sys, os

N = sys.argv[1] if len(sys.argv) > 1 else "1"
S = "/private/tmp/claude-501/-Users-jimjacob-Documents-YGTeeV/1168f22e-026e-4289-b142-74885b5f04e1/scratchpad/wf/frame/"
KIT = "public/ui/kit/"
M = Image.open("design-ref/splash-mockup.png").convert("RGB")

# panel outer rect in mockup coords
PX0, PY0, PX1, PY1 = 77, 391, 690, 1190
DW, DH = (PX1 - PX0) // 2, (PY1 - PY0) // 2          # device pt panel size
PAD = 24

# per-side band thickness (device pt) — proposed component values
T_TOP, T_LEFT, T_RIGHT, T_BOT = 17, 12, 12, 13

def load(name):
    return Image.open(KIT + name).convert("RGBA")

def render_panel(scale=1):
    w, h = (DW + 2 * PAD) * scale, (DH + 2 * PAD) * scale
    cv = Image.new("RGB", (w, h), (200, 168, 126))
    px, py = PAD * scale, PAD * scale
    pw, ph = DW * scale, DH * scale
    # interior gradient
    ins = int(11 * scale)
    grad = Image.new("RGB", (1, ph - 2 * ins))
    for y in range(ph - 2 * ins):
        t = y / max(1, ph - 2 * ins - 1)
        c = tuple(int(a + (b - a) * t) for a, b in zip((210, 176, 142), (184, 148, 108)))
        grad.putpixel((0, y), c)
    cv.paste(grad.resize((pw - 2 * ins, ph - 2 * ins)), (px + ins, py + ins))
    # full-length bands
    et = load("edge-top.png").resize((pw, T_TOP * scale), Image.LANCZOS)
    eb = load("edge-bottom.png").resize((pw, T_BOT * scale), Image.LANCZOS)
    el = load("edge-left.png").resize((T_LEFT * scale, ph), Image.LANCZOS)
    er = load("edge-right.png").resize((T_RIGHT * scale, ph), Image.LANCZOS)
    cv.paste(et, (px, py), et)
    cv.paste(eb, (px, py + ph - T_BOT * scale), eb)
    cv.paste(el, (px, py), el)
    cv.paste(er, (px + pw - T_RIGHT * scale, py), er)
    # corners (offsets in device pt from panel corner)
    for name, (ox, oy), anchor, cwid in [
        ("corner-tl.png", (-9, -9), "tl", 46),
        ("corner-tr.png", (10, -10), "tr", 46),
        ("corner-bl.png", (-11, 15), "bl", 54),
        ("corner-br.png", (9, 15), "br", 61),
    ]:
        im = load(name)
        cw = cwid * scale
        ch = int(im.height / im.width * cw)
        im = im.resize((cw, ch), Image.LANCZOS)
        if anchor == "tl":
            pos = (px + ox * scale, py + oy * scale)
        elif anchor == "tr":
            pos = (px + pw + ox * scale - cw, py + oy * scale)
        elif anchor == "bl":
            pos = (px + ox * scale, py + ph + oy * scale - ch)
        else:
            pos = (px + pw + ox * scale - cw, py + ph + oy * scale - ch)
        cv.paste(im, pos, im)
    return cv

def mock_panel(scale=1):
    c = M.crop((PX0 - 2 * PAD, PY0 - 2 * PAD, PX1 + 2 * PAD, PY1 + 2 * PAD))
    return c.resize(((DW + 2 * PAD) * scale, (DH + 2 * PAD) * scale), Image.LANCZOS)

def hstack(imgs, gap=12):
    h = max(i.height for i in imgs)
    w = sum(i.width for i in imgs) + gap * (len(imgs) - 1)
    out = Image.new("RGB", (w, h), (40, 40, 40))
    x = 0
    for i in imgs:
        out.paste(i, (x, 0))
        x += i.width + gap
    return out

def vstack(imgs, gap=12):
    w = max(i.width for i in imgs)
    h = sum(i.height for i in imgs) + gap * (len(imgs) - 1)
    out = Image.new("RGB", (w, h), (40, 40, 40))
    y = 0
    for i in imgs:
        out.paste(i, (0, y))
        y += i.height + gap
    return out

sim1 = render_panel(1)
mock1 = mock_panel(1)
row1 = hstack([sim1, mock1])

# 2x zoom of the four corner regions + rail mid-sections
sim2 = render_panel(2)
mock2 = mock_panel(2)
Z = 150  # zoom window (px at 2x)
regions = {
    "tl": (0, 0), "tr": (sim2.width - Z, 0),
    "bl": (0, sim2.height - Z), "br": (sim2.width - Z, sim2.height - Z),
    "left-mid": (0, sim2.height // 2 - Z // 2),
    "right-mid": (sim2.width - Z, sim2.height // 2 - Z // 2),
    "top-mid": (sim2.width // 2 - Z // 2, 0),
    "bot-mid": (sim2.width // 2 - Z // 2, sim2.height - Z),
}
pairs = []
for k, (x, y) in regions.items():
    a = sim2.crop((x, y, x + Z, y + Z)).resize((Z * 2, Z * 2), Image.NEAREST)
    b = mock2.crop((x, y, x + Z, y + Z)).resize((Z * 2, Z * 2), Image.NEAREST)
    pairs.append(hstack([a, b], gap=4))
grid = vstack([hstack(pairs[0:2]), hstack(pairs[2:4]), hstack(pairs[4:6]), hstack(pairs[6:8])])
out = vstack([row1, grid])
out.save(S + f"compare-{N}.png")
print("saved", S + f"compare-{N}.png", out.size)
