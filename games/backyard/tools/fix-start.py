#!/usr/bin/env python3
"""Rebuild public/ui/kit/start.png (START GAME parchment plate) from the
approved mockup, fixing:
  1. stray dark vertical line on the left (crop margin included the panel
     frame edge, which poisoned flood_key's left bg reference)
  2. faint text ghost / dark smear left by the old vpatch
  3. flattened facets in the patched band (old vpatch blurred them away)

Technique:
  - crop (90,950,664,1110) from design-ref/splash-mockup.png -> 574x160
  - fill the START GAME text band by VERTICALLY STRETCHING the clean bands
    above and below it (no tiling, no global blur -> grain + facet shading
    stays crisp), crossfaded where they meet
  - repaint bold low-poly facet planes over the plate interior (subtle
    +- luminance polygons with soft edges) and re-grain the fill
  - flood-key the background with per-row/col refs taken from *inside* the
    junk margins, flood from all four sides, keep largest component,
    1px erode + feather; then hard-clear the left margin columns
  - 2x lanczos + unsharp -> 1148x320

Run from games/backyard:  python3 tools/fix-start.py
"""
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
import collections

SRC = "design-ref/splash-mockup.png"
OUT = "public/ui/kit/start.png"
rng = np.random.default_rng(11)

M = Image.open(SRC).convert("RGB")
s = M.crop((90, 950, 664, 1110))          # 574 x 160
W, H = s.size

# ------------------------------------------------------------------ text fill
# text: x146..448, y ~60..114 (glyphs 64..112 + soft shadow margin)
TX0, TX1 = 143, 452
TY0, TY1 = 57, 117
TOP_BAND = (46, 57)      # clean interior below the top-rim crease
BOT_BAND = (118, 134)    # clean interior above the bottom shadow crease

def stretch_fill(img):
    """Fill the text zone as low-freq ramp + high-freq texture.

    Low frequency: per-column linear interpolation between the rows just
    above and just below the zone -> the fill's tone matches all four
    borders exactly (no rectangular seam).
    High frequency: grain/detail from the vertically stretched clean bands
    (their own low freq removed), so parchment texture stays crisp.
    """
    a = np.asarray(img, float)
    w = TX1 - TX0
    th = TY1 - TY0
    # --- low-freq ramp between border rows (each averaged over a few rows,
    # smoothed horizontally so glyph-edge noise can't streak down)
    top_row = a[TY0 - 6:TY0, TX0:TX1].mean(axis=0)          # (w,3)
    bot_row = a[TY1:TY1 + 6, TX0:TX1].mean(axis=0)
    k = 31
    ker = np.ones(k) / k
    for c in range(3):
        top_row[:, c] = np.convolve(np.pad(top_row[:, c], k // 2, mode="edge"), ker, "valid")
        bot_row[:, c] = np.convolve(np.pad(bot_row[:, c], k // 2, mode="edge"), ker, "valid")
    t = (np.arange(th, dtype=float) + 0.5)[:, None, None] / th
    ramp = top_row[None] * (1 - t) + bot_row[None] * t       # (th,w,3)
    # --- high-freq texture from stretched clean bands
    half = th // 2
    top_b = img.crop((TX0, TOP_BAND[0], TX1, TOP_BAND[1])).resize((w, half + 8), Image.LANCZOS)
    bot_b = img.crop((TX0, BOT_BAND[0], TX1, BOT_BAND[1])).resize((w, th - half + 8), Image.LANCZOS)
    tex = Image.new("RGB", (w, th))
    tex.paste(top_b.crop((0, 0, w, half + 4)), (0, 0))
    tex.paste(bot_b.crop((0, 4, w, 8 + th - half)), (0, half - 4))
    hi = np.asarray(tex, float) - np.asarray(tex.filter(ImageFilter.GaussianBlur(6)), float)
    a[TY0:TY1, TX0:TX1] = np.clip(ramp + hi * 0.9, 0, 255)
    return Image.fromarray(a.astype(np.uint8))

s = stretch_fill(s)

# ------------------------------------------------------- low-poly facet planes
# Bold facet planes over the plate interior, spanning across the fill borders
# so no rectangular seam can read. Values are luminance offsets.
FACETS = [
    # (polygon points, lum offset) — large diagonal planes mimicking the
    # mockup's shallow creases; they extend past the fill-zone borders so
    # no plane edge can align with (and reveal) the patch rectangle
    ([(128, 88), (310, 58), (458, 84), (452, 102), (300, 96), (132, 116)], -7),
    ([(300, 96), (452, 102), (458, 122), (340, 124), (246, 120)], +6),
    ([(132, 52), (240, 50), (310, 58), (128, 88)], +4),
    ([(310, 58), (400, 52), (458, 64), (458, 84)], +6),
]

def facet_overlay(img):
    a = np.asarray(img, float)
    lay = Image.new("L", img.size, 128)               # 128 = zero offset
    d = ImageDraw.Draw(lay)
    for pts, off in FACETS:
        d.polygon(pts, fill=128 + off)
    lay = lay.filter(ImageFilter.GaussianBlur(0.7))   # crisp plane edges
    off = np.asarray(lay, float)[..., None] - 128.0
    return Image.fromarray(np.clip(a + off, 0, 255).astype(np.uint8))

s = facet_overlay(s)

# re-grain the filled band so it matches surrounding parchment noise
def regrain(img, x0, x1, y0, y1, sigma=2.2):
    a = np.asarray(img, float)
    n = rng.normal(0, sigma, (y1 - y0, x1 - x0, 1))
    a[y0:y1, x0:x1] = np.clip(a[y0:y1, x0:x1] + n, 0, 255)
    return Image.fromarray(a.astype(np.uint8))

s = regrain(s, TX0, TX1, TY0, TY1)

# ------------------------------------------------------------------- keying
def flood_key_fixed(img, tol=24, feather=1.5, lm=6,
                    hard_clear_x=8, hard_clear_xr=562):
    """flood_key with margin-safe references: the left refs come from just
    inside the dark frame line (cols lm..lm+3), and seeds start there too.
    Floods from all four sides; largest component; morphological opening to
    shave ragged shadow tendrils; graded edge alpha; erode+feather."""
    a = np.asarray(img.convert("RGB"), dtype=np.int16)
    h, w = a.shape[:2]
    bg_l = np.median(a[:, lm:lm + 4, :], axis=1)
    bg_r = np.median(a[:, -4:, :], axis=1)
    bg_t = np.median(a[:3, :, :], axis=0)
    bg_b = np.median(a[-3:, :, :], axis=0)
    d_l = np.sqrt(((a - bg_l[:, None, :]) ** 2).sum(2))
    d_r = np.sqrt(((a - bg_r[:, None, :]) ** 2).sum(2))
    d_t = np.sqrt(((a - bg_t[None, :, :]) ** 2).sum(2))
    d_b = np.sqrt(((a - bg_b[None, :, :]) ** 2).sum(2))
    dist = np.minimum(np.minimum(d_l, d_r), np.minimum(d_t, d_b))
    near = dist <= tol
    mask = np.zeros((h, w), dtype=bool)
    q = collections.deque()
    def seed(x, y):
        if near[y, x] and not mask[y, x]:
            mask[y, x] = True
            q.append((x, y))
    for x in range(w):
        seed(x, 0); seed(x, h - 1)
    for y in range(h):
        seed(lm, y); seed(w - 1, y)
    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not mask[ny, nx] and near[ny, nx]:
                mask[ny, nx] = True
                q.append((nx, ny))
    alpha = np.where(mask, 0, 255).astype(np.uint8)
    alpha[:, :hard_clear_x] = 0                     # kills the frame line
    alpha[:, hard_clear_xr:] = 0                    # junk right of stones
    # opening: shave thin ragged shadow tendrils — but only in the outer
    # stone columns; applied globally it also destroys the thin painted
    # crevice shadow between the stones and the plate edge
    opened = np.asarray(
        Image.fromarray(alpha, "L").filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5))
    )
    open_zone = np.zeros_like(alpha, dtype=bool)
    open_zone[:, :100] = True
    open_zone[:, 478:] = True
    alpha = np.where(open_zone, opened, alpha).astype(np.uint8)
    # ---- geometric corner stones ---------------------------------------
    # The painted drop shadows around the four stones key raggedly (doughnut
    # gaps, puddles).  Inside the left/right columns the silhouette is taken
    # from exact octagons instead; flood alpha survives there only for
    # bright gold pixels (the plate's notched ends) so the plate wedges
    # between the stones are preserved.
    STONES = [
        (26, 13, 102, 81, 15),    # TL gold  (meets BL: contiguous crevice
        (474, 10, 561, 79, 15),   # TR gold   shadow like the mockup, no
        (17, 80, 104, 153, 14),   # BL grey   floating band between stones)
        (477, 78, 561, 151, 14),  # BR grey
    ]
    geo = Image.new("L", (w, h), 0)
    gd = ImageDraw.Draw(geo)
    for x0, y0, x1, y1, c in STONES:
        gd.polygon([(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c),
                    (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)], fill=255)
    geo = np.asarray(geo)
    zone = np.zeros((h, w), dtype=bool)
    zone[:, :104] = True    # stop short of the stone-to-plate crevices so
    zone[:, 474:] = True    # their painted dark shadow survives (flood alpha)
    goldish = (a[..., 0] - a[..., 2] >= 60) & (a.mean(axis=2) >= 125)
    # very dark pixels are the painted crevice shadow hugging the plate's
    # notched ends — keep them (the mid-grey outer puddles stay excluded)
    darkish = a.mean(axis=2) <= 92
    flood_in_zone = np.where(goldish | darkish, alpha, 0)
    alpha = np.where(zone, np.maximum(geo, flood_in_zone), alpha).astype(np.uint8)
    # The flood boundary along the plate's top rim is ragged (pale rim vs
    # pale panel bg).  The mockup's top edge is two straight segments —
    # clip alpha above that polyline for a clean silhouette.
    P0, P1, P2 = (106, 20.5), (300, 19.5), (474, 20.5)
    for x in range(106, 474):
        if x < P1[0]:
            yl = P0[1] + (P1[1] - P0[1]) * (x - P0[0]) / (P1[0] - P0[0])
        else:
            yl = P1[1] + (P2[1] - P1[1]) * (x - P1[0]) / (P2[0] - P1[0])
        alpha[:int(round(yl)), x] = 0
    # drop small floating components (the stones are separate components
    # from the plate, so "largest only" would delete them — keep everything
    # above a size threshold instead)
    opaque = alpha > 0
    seen = np.zeros_like(opaque)
    keep = np.zeros_like(opaque)
    for sy in range(h):
        for sx in range(w):
            if opaque[sy, sx] and not seen[sy, sx]:
                comp = [(sx, sy)]
                seen[sy, sx] = True
                i = 0
                while i < len(comp):
                    cx, cy = comp[i]; i += 1
                    for nx, ny in ((cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)):
                        if 0 <= nx < w and 0 <= ny < h and opaque[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            comp.append((nx, ny))
                if len(comp) >= 400:
                    for cx, cy in comp:
                        keep[cy, cx] = True
    alpha = np.where(keep, alpha, 0).astype(np.uint8)
    # graded alpha on the kept boundary ring: fade by color-distance to bg so
    # trimmed shadows dissolve instead of ending in a hard torn edge
    ring = keep & ~np.asarray(
        Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))
    ).astype(bool)
    grade = np.clip((dist - 16) * (255.0 / 40.0), 0, 255)
    alpha = np.where(ring, np.minimum(alpha, grade).astype(np.uint8), alpha)
    al = Image.fromarray(alpha, "L").filter(ImageFilter.MinFilter(3))
    al = al.filter(ImageFilter.GaussianBlur(feather))
    out = img.convert("RGBA")
    out.putalpha(al)
    return out

keyed = flood_key_fixed(s)

big = keyed.resize((W * 2, H * 2), Image.LANCZOS)
big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2))
assert big.size == (1148, 320), big.size
big.save(OUT, optimize=True)
print("wrote", OUT, big.size)
