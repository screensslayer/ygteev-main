#!/usr/bin/env python3
"""Rebuild the StonePanel frame kit from the approved mockup.

Outputs (public/ui/kit/):
  corner-tl.png corner-tr.png corner-bl.png corner-br.png
  edge-left.png edge-right.png edge-top.png edge-bottom.png
  edge-h.png (copy of edge-top) edge-v.png (copy of edge-left)

Design (measured from design-ref/splash-mockup.png):
  - left rail  : dark brown wood, x77..101, real 580px run y520..1100
  - right rail : dark brown wood, x667..690, dark inner line, lit outer edge
  - top rail   : brown wood lit from the top; only short clean windows exist
                 in the mockup, so its band is the left-rail texture rotated
                 horizontal and per-row remapped to the top rail's real
                 lighting profile (window x136..152, y389..424)
  - bottom rail: gray stone ledge, dark seam on top, lit bottom lip
                 (real 410px run x180..590, y1166..1190)
  - corners    : hand-traced polygon silhouettes of the actual stones
                 (angular gray blocks on top, L-shaped elbows on bottom),
                 feather 1.5px, zero garden bleed.
Run from games/backyard:  python3 tools/fix-frame.py
"""
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
import os

SRC = "design-ref/splash-mockup.png"
OUT = "public/ui/kit/"
os.makedirs(OUT, exist_ok=True)
M = Image.open(SRC).convert("RGB")


def crop(box):
    return M.crop(box)


def finish(img, name, scale=2):
    big = img.resize((img.width * scale, img.height * scale), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2))
    big.save(OUT + name, optimize=True)
    print(f"{name:18s} {big.size[0]}x{big.size[1]}")


def poly_mask(img, polys, feather=1.5):
    """polys: list of (points, alpha). Later entries paint over earlier."""
    al = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(al)
    for pts, a in polys:
        d.polygon(pts, fill=a)
    al = al.filter(ImageFilter.GaussianBlur(feather))
    out = img.convert("RGBA")
    out.putalpha(al)
    return out


# ------------------------------------------------------------- side rails
# Long, real painted runs. Kept at native resolution — the CSS band
# squishes them down, which preserves grain instead of smearing it.
EL_BOX = (77, 520, 101, 1100)      # 24 x 580
ER_BOX = (667, 520, 690, 1100)     # 23 x 580
edge_left = crop(EL_BOX)
edge_right = crop(ER_BOX)
finish(edge_left, "edge-left.png")
finish(edge_right, "edge-right.png")

# --------------------------------------------------------------- top rail
# texture: left rail rotated horizontal; lighting: real top-rail profile.
TOP_W, TOP_H = 560, 35
tex = edge_left.transpose(Image.ROTATE_90)          # outer dark edge -> top
tex = tex.resize((TOP_W, TOP_H), Image.LANCZOS)
ta = np.asarray(tex, dtype=np.float64)

# target per-row profile from the clean window left of the header slab
win = np.asarray(crop((136, 389, 153, 424)), dtype=np.float64)  # 17 x 35
target = win.mean(axis=1)                                        # (35,3)
srcm = ta.mean(axis=1)                                           # (35,3)
top = np.clip(ta + (target - srcm)[:, None, :], 0, 255)
# soften residual cross-grain from the rotation, keep the long-axis grain
edge_top = Image.fromarray(top.astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
finish(edge_top, "edge-top.png")

# ------------------------------------------------------------ bottom rail
EB_BOX = (180, 1166, 590, 1190)    # 410 x 24, real stone ledge
edge_bottom = crop(EB_BOX)
finish(edge_bottom, "edge-bottom.png")

# back-compat copies
finish(edge_top, "edge-h.png")
finish(edge_left, "edge-v.png")


# ---------------------------------------------------------------- corners
# Absolute mockup-space silhouettes, hand-traced. Each entry:
#   crop box, [(abs polygon, alpha), ...]
def rel(pts, box):
    return [(x - box[0], y - box[1]) for x, y in pts]


# TL: chunky angular gray block, top-left of panel
TL_BOX = (58, 372, 150, 464)
TL_STONE = [(72, 378), (122, 375), (129, 382), (132, 391), (131, 414),
            (125, 421), (94, 451), (78, 454), (68, 450), (64, 441),
            (62, 401), (67, 388)]

# TR: angular gray block, top-right
TR_BOX = (618, 370, 710, 462)
TR_STONE = [(640, 378), (693, 376), (700, 382), (705, 391), (704, 413),
            (697, 442), (688, 453), (664, 455), (650, 448), (632, 422),
            (634, 398)]

# BL: L-shaped elbow with rounded end cap, bottom-left (108 x 120)
BL_BOX = (54, 1100, 162, 1220)
BL_STONE = [(66, 1105), (101, 1105), (106, 1112), (107, 1172), (112, 1179),
            (144, 1180), (152, 1184), (157, 1192), (156, 1204), (148, 1211),
            (138, 1215), (72, 1216), (62, 1211), (57, 1202), (57, 1114),
            (61, 1107)]

# BR: mirrored elbow with shadowed end cap, bottom-right (122 x 120)
BR_BOX = (586, 1100, 708, 1220)
BR_STONE = [(656, 1106), (699, 1106), (704, 1112), (704, 1204), (699, 1212),
            (690, 1216), (610, 1216), (600, 1210), (594, 1200), (595, 1189),
            (602, 1182), (616, 1181), (648, 1179), (654, 1172), (651, 1112)]

for name, box, pts in [
    ("corner-tl.png", TL_BOX, TL_STONE),
    ("corner-tr.png", TR_BOX, TR_STONE),
    ("corner-bl.png", BL_BOX, BL_STONE),
    ("corner-br.png", BR_BOX, BR_STONE),
]:
    img = crop(box)
    finish(poly_mask(img, [(rel(pts, box), 255)], feather=1.5), name)

print("done ->", OUT)
