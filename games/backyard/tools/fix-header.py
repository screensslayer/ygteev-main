#!/usr/bin/env python3
"""Rebuild public/ui/kit/header.png — the WEEKLY LEADERBOARD stone slab.

Fixes vs the old build-splash-assets.py pipeline:
  * text erased with a per-column vertical gradient fill (clean face refs
    above/below the lettering) + matched grain — no mirrored-band ghosts,
    no fake fracture seams
  * silhouette from contour-walked top/bottom edges + hand-measured end
    caps — flood_key nibbled the dark end facets and kept green fringe
  * greenish pixels inside the mask are neutralized (no garden bleed)

Run from games/backyard:  python3 tools/fix-header.py
Output: public/ui/kit/header.png (896x188, same box as before)
"""
from PIL import Image, ImageFilter, ImageDraw
import numpy as np

SRC = "design-ref/splash-mockup.png"
OUT = "public/ui/kit/header.png"
BOX = (162, 358, 610, 452)          # same crop box as build-splash-assets.py
rng = np.random.default_rng(11)

M = Image.open(SRC).convert("RGB")
img = M.crop(BOX)                    # 448 x 94
W, H = img.size
a = np.asarray(img, dtype=np.float64)
mean = a.mean(axis=2)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
greenish = (g > r + 8) & (g > b + 8)

# ------------------------------------------------------------- top contour
# top edge = first bright warm highlight pixel; bridge chip notches with a
# small V-dip when the highlight disappears for a few columns.
def bright_stone(y, x):
    return mean[y, x] > 160 and r[y, x] > b[y, x] + 25 and not greenish[y, x]

TOP_X0, TOP_X1 = 20, 427
yt = {}
prev = next(yy for yy in range(2, 40) if bright_stone(yy, 224))
yt[224] = prev
for xs in (range(225, TOP_X1 + 1), range(223, TOP_X0 - 1, -1)):
    prev = yt[224]
    gap = []
    for x in xs:
        found = -1
        for yy in range(max(2, prev - 2), min(50, prev + 13)):
            if bright_stone(yy, x):
                found = yy
                break
        if found >= 0:
            if gap:                       # fill the notch with a V dip
                n = len(gap)
                for i, gx in enumerate(gap):
                    depth = int(min(2.5 * (i + 1), 2.5 * (n - i), 9))
                    yt[gx] = min(prev + depth, 50)
                gap = []
            yt[x] = prev = found
        else:
            gap.append(x)
    for gx in gap:                        # trailing gap near the ends
        yt[gx] = prev

# --------------------------------------------------------- bottom contour
# the painterly bottom boundary (rail highlight, lit chip facets, glow
# bleed) defeats color rules — hand-authored anchor curve instead, with
# the two bottom chips as explicit V features.
BOT_X0, BOT_X1 = 13, 424
bx = [13, 25, 70, 78, 86, 95, 120, 160, 210, 230, 300, 330, 338, 345, 352, 360, 400, 412, 424]
by = [78, 80, 81, 82, 86, 81, 79, 78, 79, 80, 80, 82, 84, 88, 85, 84, 86, 85, 82]
xs_all = np.arange(BOT_X0, BOT_X1 + 1)
yb = {int(x): int(round(v)) for x, v in zip(xs_all, np.interp(xs_all, bx, by))}

print("yt span", min(yt.values()), max(yt.values()),
      " yb span", min(yb.values()), max(yb.values()))

# ---------------------------------------------------------------- mask
outline = [(7, 22), (19, 9)]
outline += [(x, yt[x]) for x in range(TOP_X0, TOP_X1 + 1)]
outline += [(428, 9), (438, 20), (439, 45), (438, 58), (435, 73), (430, 81)]
outline += [(x, yb[x] + 1) for x in range(BOT_X1, BOT_X0 - 1, -1)]
outline += [(12, 78), (7, 58)]
mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).polygon(outline, fill=255)
mask = mask.filter(ImageFilter.MinFilter(3))      # 1px erode: no baked fringe
mask = mask.filter(ImageFilter.GaussianBlur(1.0))

# ----------------------------------------------------------- text erase
TX0, TX1, TY0, TY1 = 28, 416, 24, 64
top_ref = np.median(a[16:24, :, :], axis=0)      # clean face above lettering
bot_ref = np.median(a[63:69, :, :], axis=0)      # clean face below lettering
def hsmooth(ref, k=9):                            # kill letter-edge streaks
    kern = np.ones(k) / k
    out = ref.copy()
    for c in range(3):
        out[:, c] = np.convolve(np.pad(ref[:, c], k // 2, mode="edge"), kern, "valid")
    return out
top_ref = hsmooth(top_ref)
bot_ref = hsmooth(bot_ref)

fill_h = TY1 - TY0
t = (np.arange(fill_h)[:, None, None] + 0.5) / fill_h
grad = top_ref[None, :, :] * (1 - t) + bot_ref[None, :, :] * t
# real brush texture, quilted from the two clean face strips: each band row
# borrows a clean row (alternating strips, smooth random x-rolls to break
# repetition), high-passed so only the streaky grain transfers onto the
# gradient. Synthetic noise read as a flat speckled rectangle.
# donor rows: clean face only (x 34..410), skipping any letter shadow
rows_pool = [a[y, 34:410, :] for y in list(range(15, 24)) + list(range(63, 70))]
seg_w = rows_pool[0].shape[0]
tex = np.zeros((fill_h, W, 3))
k = 31
kern = np.ones(k) / k
for i in range(fill_h):
    row = rows_pool[int(rng.integers(0, len(rows_pool)))]
    row = np.roll(row, int(rng.integers(-60, 61)), axis=0)
    lo = np.stack([np.convolve(np.pad(row[:, c], k // 2, mode="wrap"),
                               kern, "valid") for c in range(3)], axis=1)
    hp = row - lo
    tex[i, TX0:TX1] = np.resize(hp, (TX1 - TX0, 3))
tex = np.asarray(Image.fromarray(
    np.clip(tex.mean(axis=2) * 4 + 128, 0, 255).astype(np.uint8)).filter(
    ImageFilter.GaussianBlur(0.5)), dtype=np.float64) / 4 - 32
tex = tex[..., None] * np.array([1.0, 0.97, 0.92])
# warm low-frequency staining, like the parchment-ish mottle on the face
stain = rng.normal(0, 5.5, (fill_h // 8 + 2, W // 14 + 2))
stain = np.asarray(Image.fromarray(
    np.clip(stain * 4 + 128, 0, 255).astype(np.uint8)).resize((W, fill_h), Image.BICUBIC),
    dtype=np.float64) / 4 - 32
stain = stain[..., None] * np.array([1.0, 0.72, 0.45])
patch = np.clip(grad + tex * 0.55 + stain, 0, 255)

out = a.copy()
band = out[TY0:TY1, :, :]
# per-column jittered vertical ramps — a straight horizontal blend line at
# the band boundary reads as a patch seam
ramp = 5
joff = np.asarray(Image.fromarray(
    (rng.random(W // 16 + 2) * 255).astype(np.uint8)[None, :]).resize((W, 1), Image.BICUBIC),
    dtype=np.float64)[0] / 255.0 * 2.5
yy = np.arange(fill_h)[:, None].astype(np.float64)
top_edge = joff[None, :]
bot_edge = fill_h - joff[None, :]
w_y = np.clip((yy - top_edge) / ramp, 0, 1) * np.clip((bot_edge - yy) / ramp, 0, 1)
w_x = np.zeros(W); w_x[TX0:TX1] = 1.0
for i in range(6):
    w_x[TX0 + i] = (i + 0.5) / 6
    w_x[TX1 - 1 - i] = (i + 0.5) / 6
wgt = (w_y * w_x[None, :])[..., None]
out[TY0:TY1, :, :] = band * (1 - wgt) + patch * wgt

# -------------------------------------------------- segment seam strokes
# the fill erased the faint facet seams that drop from the edge chips; the
# 3-segment read needs them. Painted back as soft fading strokes: dark
# crease + 1px catch-light on the right.
def stroke(arr, p0, p1, amp, width=1.3, n=10):
    ov = Image.new("L", (W * 3, H * 3), 0)
    dd = ImageDraw.Draw(ov)
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        fade = int(255 * (1.0 - 0.85 * t0))
        x0 = (p0[0] + (p1[0] - p0[0]) * t0) * 3
        y0 = (p0[1] + (p1[1] - p0[1]) * t0) * 3
        x1 = (p0[0] + (p1[0] - p0[0]) * t1) * 3
        y1 = (p0[1] + (p1[1] - p0[1]) * t1) * 3
        dd.line([(x0, y0), (x1, y1)], fill=fade, width=int(width * 3))
    ov = ov.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    arr += (np.asarray(ov, dtype=np.float64) / 255.0)[..., None] * amp
    return arr

out = stroke(out, (74, 15), (80, 40), -13.0)          # left chip crease
out = stroke(out, (76.5, 15), (82.5, 40), +7.0)       # its catch-light
out = stroke(out, (338, 14), (333, 38), -13.0)        # right chip crease
out = stroke(out, (340.5, 14), (335.5, 38), +7.0)
out = stroke(out, (346, 84), (342, 62), -10.0)        # up from bottom chip
out = np.clip(out, 0, 255)

# --------------------------------------- neutralize green bleed inside mask
mk = np.asarray(mask) > 8
olive = (g > b * 1.45) & (mean < 160)
gm = (greenish | olive) & mk
gray = out[..., [0, 2]].mean(axis=2)
out[gm, 1] = np.minimum(out[gm, 1], gray[gm] + 4)

im = Image.fromarray(out.astype(np.uint8)).convert("RGBA")
im.putalpha(mask)

big = im.resize((W * 2, H * 2), Image.LANCZOS)
big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2))
big.save(OUT, optimize=True)
print("saved", OUT, big.size)
