#!/usr/bin/env python3
"""Rebuild public/ui/kit/close.png (Close wood bar) from the mockup with
CONTINUOUS plank grooves — no patch seam, no ghosted/doubled lines.

Technique: the baked "Close" text (crop x ~252..346) is erased with a
per-row horizontal interpolation between the clean plank columns just
left and right of the text. All groove/bevel lines on the bar are
horizontal, so per-row interpolation keeps every line perfectly
continuous at both boundaries; where a wavy band edge sits at slightly
different heights on the two sides, the lerp drifts it smoothly across
the span like natural hand-painted waviness. Wood-grain high-frequency
detail is restored from a clean donor stretch of the same plank so the
fill doesn't read as airbrushed.

Run from games/backyard:  python3 tools/fix-close-bar.py
Output: public/ui/kit/close.png  (1152x156, RGBA)
"""
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
import collections

SRC = "design-ref/splash-mockup.png"
OUT = "public/ui/kit/close.png"
BOX = (88, 1106, 664, 1184)          # mockup crop, 576x78
TX0, TX1 = 250, 348                  # text + drop shadow span to erase (crop x)
REFW = 12                            # ref column window width each side
rng = np.random.default_rng(11)


# ---- geo_mask copied from tools/build-splash-assets.py (unchanged) ----
def geo_mask(img, draw_fn, feather=1.4):
    al = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(al)
    draw_fn(d, img.width, img.height)
    al = al.filter(ImageFilter.GaussianBlur(feather))
    out = img.convert("RGBA"); out.putalpha(al)
    return out


# ---- flood_key copied from tools/build-splash-assets.py (unchanged) ----
def flood_key(img, tol=26, feather=1.4, sides="lr", yclip=None):
    a = np.asarray(img.convert("RGB"), dtype=np.int16)
    h, w = a.shape[:2]
    bg_l = np.median(a[:, :3, :], axis=1)
    bg_r = np.median(a[:, -3:, :], axis=1)
    dist_l = np.sqrt(((a - bg_l[:, None, :]) ** 2).sum(axis=2))
    dist_r = np.sqrt(((a - bg_r[:, None, :]) ** 2).sum(axis=2))
    near_bg = (dist_l <= tol) | (dist_r <= tol)
    if "t" in sides:
        bg_t = np.median(a[:3, :, :], axis=0)
        near_bg |= np.sqrt(((a - bg_t[None, :, :]) ** 2).sum(axis=2)) <= tol
    if "b" in sides:
        bg_b = np.median(a[-3:, :, :], axis=0)
        near_bg |= np.sqrt(((a - bg_b[None, :, :]) ** 2).sum(axis=2)) <= tol
    mask = np.zeros((h, w), dtype=bool)
    q = collections.deque()
    for x in range(w):
        for y in (0, h - 1):
            if near_bg[y, x] and not mask[y, x]:
                mask[y, x] = True; q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if near_bg[y, x] and not mask[y, x]:
                mask[y, x] = True; q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not mask[ny, nx] and near_bg[ny, nx]:
                mask[ny, nx] = True; q.append((nx, ny))
    alpha = np.where(mask, 0, 255).astype(np.uint8)
    if yclip:
        alpha[:yclip[0], :] = 0
        alpha[yclip[1]:, :] = 0
    opaque = alpha > 0
    seen = np.zeros_like(opaque, dtype=bool)
    best, best_n = None, 0
    for sy in range(h):
        for sx in range(w):
            if opaque[sy, sx] and not seen[sy, sx]:
                comp = [(sx, sy)]
                seen[sy, sx] = True
                idx = 0
                while idx < len(comp):
                    cx, cy = comp[idx]; idx += 1
                    for nx, ny in ((cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)):
                        if 0 <= nx < w and 0 <= ny < h and opaque[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            comp.append((nx, ny))
                if len(comp) > best_n:
                    best_n, best = len(comp), comp
    keep = np.zeros_like(opaque)
    if best:
        for cx, cy in best:
            keep[cy, cx] = True
    alpha = np.where(keep, alpha, 0).astype(np.uint8)
    al = Image.fromarray(alpha, "L").filter(ImageFilter.MinFilter(3))
    al = al.filter(ImageFilter.GaussianBlur(feather))
    out = img.convert("RGBA"); out.putalpha(al)
    return out


def finish(img, path, scale=2):
    big = img.resize((img.width * scale, img.height * scale), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2))
    big.save(path, optimize=True)
    print(f"{path}  {big.size[0]}x{big.size[1]}")


# ------------------------------------------------------------- rebuild
M = Image.open(SRC).convert("RGB")
c = M.crop(BOX)
a = np.asarray(c, dtype=np.float64)
h, w = a.shape[:2]

# per-row boundary references — EXACT boundary columns (tiny 3-col mean so
# the fill is C0-continuous with the untouched plank on both sides)
L = a[:, TX0 - 3:TX0, :].mean(axis=1)            # (h,3)
R = a[:, TX1:TX1 + 3, :].mean(axis=1)            # (h,3)

# The plank's horizontal band edges (top bevel, highlight bottom, bottom
# groove) sit at slightly different heights on the two sides. A plain
# color lerp would cross-dissolve those sharp edges into ghost doubles,
# so instead MORPH: find the vertical offset d that best aligns the two
# profiles, then drift the edge linearly across the span (reads as the
# painter's natural waviness, stays crisp).
def sample(v, y):
    """v: (h,3) profile, y: float array -> linear-interp rows."""
    y = np.clip(y, 0, v.shape[0] - 1)
    y0 = np.floor(y).astype(int)
    y1 = np.minimum(y0 + 1, v.shape[0] - 1)
    f = (y - y0)[:, None]
    return v[y0] * (1 - f) + v[y1] * f

rows = slice(4, h - 6)
best_d, best_err = 0, None
for d in np.arange(-5, 5.25, 0.25):
    y = np.arange(h, dtype=np.float64)
    err = np.abs(sample(L, y + d)[rows] - R[rows]).mean()
    if best_err is None or err < best_err:
        best_d, best_err = d, err
print(f"profile align: d={best_d} err={best_err:.2f}")

n = TX1 - TX0
t = (np.arange(n) + 0.5) / n                     # (n,)
y = np.arange(h, dtype=np.float64)
fill = np.empty((h, n, 3))
for i, ti in enumerate(t):
    lc = sample(L, y + ti * best_d)              # L shifted toward R
    rc = sample(R, y - (1 - ti) * best_d)        # R shifted toward L
    fill[:, i, :] = lc * (1 - ti) + rc * ti

# wood-grain high-frequency detail from a clean donor stretch of the SAME
# plank (crop x 120..250, left of the text): donor minus its horizontal
# low-pass = grain residual. Mirror-tile the residual to the fill width.
donor = a[:, 122:248, :]
lp = np.asarray(
    Image.fromarray(donor.astype(np.uint8)).filter(ImageFilter.GaussianBlur(6)),
    dtype=np.float64)
resid = donor - lp
tiles = [resid, resid[:, ::-1, :]]
grain = np.concatenate(tiles * (n // (2 * resid.shape[1]) + 2), axis=1)[:, :n, :]
# taper grain near the boundaries so it can't disturb the exact match
gw = np.minimum(1.0, np.minimum(np.arange(n) + 1, n - np.arange(n)) / 8.0)
fill += grain * 0.8 * gw[None, :, None]

patched = a.copy()
patched[:, TX0:TX1, :] = fill
patched = np.clip(patched, 0, 255)

c2 = Image.fromarray(patched.astype(np.uint8))

# The bar sits on the panel's gray stone rail with parchment behind the
# split ends — flood keying keeps shadow slabs attached to the plank
# (baked-background halo over the live garden). The silhouette is a clean
# beveled octagon, so cut it geometrically instead (measured off the
# mockup crop: plank x 20..563, y 3..67, ~11px corner bevels, lower tip
# tapers at both ends).
def bar_poly(d, w, h):
    d.polygon([
        (31, 4), (552, 4),            # top edge
        (562, 14), (562, 32),         # right upper tip + edge
        (557, 55), (547, 66),         # right lower taper + bevel
        (34, 66), (25, 58),           # bottom edge + left lower taper
        (21, 42), (21, 13),           # left edge
    ], fill=255)

# geo_mask + 1px erode before the feather so the semi-transparent rim
# never samples the parchment/rail outside the painted outline (no light
# halo over the dark garden)
al = Image.new("L", c2.size, 0)
d = ImageDraw.Draw(al)
bar_poly(d, c2.width, c2.height)
al = al.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))

# defringe (alpha decontamination): semi-transparent rim pixels must carry
# PLANK color, not the parchment/shadow that happened to sit under the
# feather — otherwise a light rim ghosts over the dark garden.
al_np = np.asarray(al, dtype=np.float64) / 255.0
rgb = np.asarray(c2, dtype=np.float64)
core = (al_np > 0.85).astype(np.float64)
blur = lambda arr: np.asarray(
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2)),
    dtype=np.float64)
wsum = blur(core * 255.0) / 255.0
csum = np.stack([blur(rgb[..., ch] * core) for ch in range(3)], axis=-1)
pull = csum / np.maximum(wsum, 1e-4)[..., None]
rim = (al_np > 0.002) & (al_np <= 0.85) & (wsum > 0.02)
out_rgb = np.where(rim[..., None], pull, rgb)
keyed = Image.fromarray(np.clip(out_rgb, 0, 255).astype(np.uint8)).convert("RGBA")
keyed.putalpha(al)
finish(keyed, OUT)
