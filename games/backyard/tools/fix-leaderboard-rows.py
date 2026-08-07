#!/usr/bin/env python3
"""Rebuild the leaderboard row plaques + avatar ring from the mockup.

Techniques (improving on build-splash-assets.py):
  - plank zone: horizontal STRETCH of each row's own clean full-height
    window (keeps glow halo + bevel edges continuous — they are horizontal
    features), then re-grain with high-pass detail tiled from real donor
    planks (non-repeating: random sub-windows, flips, y-jitter).
  - cap face digit removal: per-scanline lerp between clean left/right
    face columns + low-freq painted-blotch shading + matched noise.
  - plate digit removal: per-scanline fill sampled from the clean right
    interior of the same plate (preserves rim + inner shadow structure).
  - ring: auto-detect medallion center, mask at 2x with tight feather.

Run from games/backyard:  python3 tools/fix-leaderboard-rows.py
Outputs (exact sizes preserved):
  row-gold.png 1116x184, row-stone.png 1116x188, row-wood.png 1116x184,
  row-ring.png 152x152
"""
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
import os, collections

SRC = "design-ref/splash-mockup.png"
OUT = "public/ui/kit/"
os.makedirs(OUT, exist_ok=True)
M = Image.open(SRC).convert("RGB")
rng = np.random.default_rng(11)


# ------------------------------------------------- helpers (from build kit)
def crop(box):
    return M.crop(box)


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


def finish(img, name, scale=2):
    big = img.resize((img.width * scale, img.height * scale), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2))
    big.save(OUT + name, optimize=True)
    print(f"{name:22s} {big.size[0]}x{big.size[1]}")


# ------------------------------------------------------------- new fills
def stretch_fill(img, dx0, dx1, sx0, sx1, fade=7):
    """Replace [dx0:dx1] (full height) with a horizontal LANCZOS stretch of
    the clean window [sx0:sx1]; crossfade `fade` px into the original at
    both x edges. Horizontal features (glow bands, plank bevels, grain
    lines) survive the stretch perfectly, and there is zero repetition."""
    im = img.copy()
    band = img.crop((sx0, 0, sx1, img.height))
    w = dx1 - dx0 + 2 * fade
    fill = band.resize((w, img.height), Image.LANCZOS)
    m = Image.new("L", (w, img.height), 255)
    md = ImageDraw.Draw(m)
    for i in range(fade):
        v = int(255 * i / fade)
        md.line([(i, 0), (i, img.height)], fill=v)
        md.line([(w - 1 - i, 0), (w - 1 - i, img.height)], fill=v)
    im.paste(fill, (dx0 - fade, 0), m)
    return im


def build_detail_strip(donors, width, height, seed=0):
    """High-pass grain detail strip assembled from random donor sub-windows
    (random flips + y-roll + crossfade) so nothing repeats."""
    r = np.random.default_rng(seed)
    strip = Image.new("RGB", (width + 120, height))
    pos = 0
    while pos < strip.width:
        d = donors[int(r.integers(len(donors)))]
        tw = int(r.integers(56, 96))
        tw = min(tw, d.width)
        tx = int(r.integers(0, d.width - tw + 1))
        tile = d.crop((tx, 0, tx + tw, d.height)).resize((tw, height), Image.LANCZOS)
        if r.random() < 0.5:
            tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
        roll = int(r.integers(-3, 4))
        if roll:
            ta = np.roll(np.asarray(tile), roll, axis=0)
            tile = Image.fromarray(ta)
        ov = 12
        if pos == 0:
            strip.paste(tile, (0, 0))
        else:
            m = Image.new("L", (tw, height), 255)
            md = ImageDraw.Draw(m)
            for i in range(ov):
                md.line([(i, 0), (i, height)], fill=int(255 * i / ov))
            strip.paste(tile, (pos, 0), m)
        pos += tw - ov
    strip = strip.crop((0, 0, width, height))
    a = np.asarray(strip, dtype=np.float64)
    lo = np.asarray(strip.filter(ImageFilter.GaussianBlur(4.0)), dtype=np.float64)
    return a - lo  # high-pass detail, zero-mean-ish


def add_detail(img, detail, x0, y0, amp=0.9, vfade=4, hfade=8):
    """Add high-pass detail onto img at (x0,y0) with feathered borders."""
    h, w = detail.shape[:2]
    mask = np.ones((h, w), dtype=np.float64)
    for i in range(vfade):
        mask[i, :] *= i / vfade
        mask[h - 1 - i, :] *= i / vfade
    for i in range(hfade):
        mask[:, i] *= i / hfade
        mask[:, w - 1 - i] *= i / hfade
    a = np.asarray(img, dtype=np.float64)
    a[y0:y0 + h, x0:x0 + w, :] += detail * amp * mask[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def scanline_fill(img, x0, x1, y0, y1, lwin, rwin, seed=0, blotch=5.0,
                  noise_k=0.55, edge_blur=1.0):
    """Repaint (x0..x1, y0..y1): each scanline lerps between the mean color
    of the clean left window `lwin`=(lx0,lx1) and right window
    `rwin`=(rx0,rx1) sampled AT THAT SCANLINE (preserves vertical structure
    like rims / gradients), plus low-frequency painted-blotch shading and
    matched fine noise."""
    r = np.random.default_rng(seed)
    a = np.asarray(img, dtype=np.float64)
    h, w = y1 - y0, x1 - x0
    lm = a[y0:y1, lwin[0]:lwin[1], :].mean(axis=1)          # (h,3)
    rm = a[y0:y1, rwin[0]:rwin[1], :].mean(axis=1)
    t = np.linspace(0, 1, w)[None, :, None]
    base = lm[:, None, :] * (1 - t) + rm[:, None, :] * t
    # smooth the per-scanline means a touch so text-shadow speckle in the
    # windows can't streak across
    k = np.array([1, 2, 3, 2, 1], dtype=np.float64); k /= k.sum()
    for ch in range(3):
        for arr in (lm, rm):
            pass
    sigma = float(np.concatenate([a[y0:y1, lwin[0]:lwin[1], :],
                                  a[y0:y1, rwin[0]:rwin[1], :]], axis=1).std(axis=(0, 1)).mean())
    # low-freq blotches (painted-facet feel)
    small = r.normal(0, 1, (max(2, h // 12), max(2, w // 12), 1))
    bl = np.asarray(Image.fromarray(
        np.clip(small[..., 0] * 40 + 128, 0, 255).astype(np.uint8), "L")
        .resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(3)),
        dtype=np.float64)
    bl = (bl - bl.mean()) / (bl.std() or 1.0) * blotch
    fine = r.normal(0, sigma * noise_k, (h, w, 3))
    patch = np.clip(base + bl[..., None] + fine, 0, 255)
    out = a.copy()
    out[y0:y1, x0:x1, :] = patch
    im = Image.fromarray(out.astype(np.uint8))
    pad = 2
    bx0, by0 = max(0, x0 - pad), max(0, y0 - pad)
    bx1, by1 = min(im.width, x1 + pad), min(im.height, y1 + pad)
    region = im.crop((bx0, by0, bx1, by1)).filter(ImageFilter.GaussianBlur(edge_blur))
    im.paste(region, (bx0, by0))
    return im


# --------------------------------------------------------------- the rows
# crop-local geometry: cap face 38..92 (digit 52..84), medallion 105..175,
# name text 176..455, plate 468..556 (digits ~477..515), right end 556..572.
ROWS = {
    "row-gold.png": dict(box=(90, 516, 662, 608), clean=(398, 452),
                         interior=(17, 70), seed=21),
    "row-stone.png": dict(box=(90, 606, 662, 700), clean=(352, 438),
                          interior=(14, 67), seed=22),
    "row-wood.png": dict(box=(90, 700, 662, 792), clean=(300, 452),
                         interior=(5, 57), seed=23),
}
row4 = crop((90, 792, 662, 884))
donor_row4 = row4.crop((352, 2, 456, 46))               # clean row4 interior
row3 = crop((90, 700, 662, 792))
donor_row3 = row3.crop((300, 7, 452, 55))               # clean row3 interior

for name, cfg in ROWS.items():
    r = crop(cfg["box"])
    hh = r.height
    # 1. plank zone: stretch own clean window across cap-end..plate-start
    r = stretch_fill(r, 96, 460, cfg["clean"][0], cfg["clean"][1], fade=7)
    # 2. re-grain the plank interior with real (non-repeating) detail
    iy0, iy1 = cfg["interior"]
    det = build_detail_strip([donor_row4, donor_row3], 364, iy1 - iy0,
                             seed=cfg["seed"])
    r = add_detail(r, det, 96, iy0, amp=0.85)
    # 3. cap face digit -> per-scanline lerp of the face's own sides
    r = scanline_fill(r, 50, 86, 16, hh - 22, (40, 50), (85, 91),
                      seed=cfg["seed"] + 100, blotch=4.5, noise_k=0.5)
    # 4. plate digits -> per-scanline fill from clean right plate interior
    r = scanline_fill(r, 474, 519, 16, hh - 20, (520, 545), (520, 545),
                      seed=cfg["seed"] + 200, blotch=2.5, noise_k=0.5)
    keyed = flood_key(r, tol=24, yclip=(3, hh - 3))
    finish(keyed.crop((12, 0, keyed.width - 2, keyed.height)), name)

# ---------------------------------------------------------------- the ring
# detect the true medallion center on row 3 (cream ring on dark plank)
reg = np.asarray(M.crop((180, 694, 285, 792)), dtype=np.float64)
mn, mx = reg.min(axis=2), reg.max(axis=2)
ringm = (mn > 148) & (mx - mn < 52)
ys, xs = np.nonzero(ringm)
cx, cy = 180 + xs.mean(), 694 + ys.mean()
d = np.sqrt((xs - xs.mean()) ** 2 + (ys - ys.mean()) ** 2)
r_out = np.percentile(d, 97)
r_in = np.percentile(d, 8)
print(f"medallion center ({cx:.1f},{cy:.1f}) r_out {r_out:.1f} r_in {r_in:.1f}")

# work at 2x for a crisp mask
R = 42
big = M.crop((int(round(cx)) - R, int(round(cy)) - R,
              int(round(cx)) + R, int(round(cy)) + R))
big = big.resize((R * 4, R * 4), Image.LANCZOS)            # 2x scale, 168px
big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=70, threshold=2))
big = big.crop((R * 2 - 76, R * 2 - 76, R * 2 + 76, R * 2 + 76))  # 152x152
al = Image.new("L", big.size, 0)
ad = ImageDraw.Draw(al)
ro = min(74.0, r_out * 2 + 2)
ad.ellipse([76 - ro, 76 - ro, 76 + ro, 76 + ro], fill=255)
al = al.filter(ImageFilter.GaussianBlur(0.9))
ring = big.convert("RGBA"); ring.putalpha(al)
# punch the avatar hole at the ring's inner rim
hole = Image.new("L", ring.size, 0)
hd = ImageDraw.Draw(hole)
ri = max(50.0, r_in * 2 - 2)
hd.ellipse([76 - ri, 76 - ri, 76 + ri, 76 + ri], fill=255)
hole = hole.filter(ImageFilter.GaussianBlur(0.7))
a2 = np.clip(np.asarray(ring.getchannel("A"), dtype=np.int16)
             - np.asarray(hole, dtype=np.int16), 0, 255).astype(np.uint8)
ring.putalpha(Image.fromarray(a2, "L"))
ring.save(OUT + "row-ring.png", optimize=True)
print(f"{'row-ring.png':22s} {ring.size[0]}x{ring.size[1]}")

print("done ->", OUT)
