#!/usr/bin/env python3
"""Build the splash-menu UI kit from the approved mockup art.

Pipeline per element (design-ref/splash-mockup.png, 768x1376):
  1. crop the element
  2. erase baked text/numbers/avatars with the technique that suits the
     surface:
       - hpatch: mirror-tile a WIDE clean horizontal window (wood planks)
       - vpatch: fill the text band from the clean bands above/below it
         (stone slabs, parchment — keeps vertical seams/facets continuous)
       - synth:  per-row mean color + matched noise (smooth dark faces:
         pill interiors, score plates)
  3. key the background (flood with fixed per-row bg reference), or a
     geometric mask where the element sits over the busy garden
  4. 2x lanczos upscale + mild sharpen -> public/ui/kit/

Run from games/backyard:  python3 tools/build-splash-assets.py
"""
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
import os, collections

SRC = "design-ref/splash-mockup.png"
OUT = "public/ui/kit/"
os.makedirs(OUT, exist_ok=True)
M = Image.open(SRC).convert("RGB")
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- helpers
def crop(box):
    return M.crop(box)


def hpatch(img, dx0, dx1, sx0, sx1, source_img=None):
    """Mirror-tile the clean window [sx0:sx1] across [dx0:dx1] with a soft
    crossfade. The window must be WIDE (>=60px) or repetition shows."""
    src = source_img or img
    band = src.crop((sx0, 0, sx1, img.height))
    if band.height != img.height:
        band = band.resize((band.width, img.height), Image.LANCZOS)
    bw = band.width
    ov = max(8, bw // 5)
    strip = Image.new("RGB", (dx1 - dx0 + bw, img.height))
    fade = Image.new("L", (bw, img.height), 255)
    fd = ImageDraw.Draw(fade)
    for i in range(ov):
        fd.line([(i, 0), (i, img.height)], fill=int(255 * i / ov))
    pos, flip = 0, False
    while pos < strip.width:
        b = band.transpose(Image.FLIP_LEFT_RIGHT) if flip else band
        strip.paste(b, (pos, 0), fade if pos else None)
        pos += bw - ov
        flip = not flip
    im = img.copy()
    im.paste(strip.crop((0, 0, dx1 - dx0, img.height)), (dx0, 0))
    return im


def vpatch(img, x0, x1, ty0, ty1, top_band, bot_band):
    """Fill the text band (x0..x1, ty0..ty1) from mirrored copies of the
    clean bands above and below, crossfaded where they meet."""
    im = img.copy()
    w = x1 - x0
    th = ty1 - ty0
    tb = img.crop((x0, top_band[0], x1, top_band[1])).transpose(Image.FLIP_TOP_BOTTOM)
    bb = img.crop((x0, bot_band[0], x1, bot_band[1])).transpose(Image.FLIP_TOP_BOTTOM)
    half = th // 2 + 4
    def stack(band, height):
        out = Image.new("RGB", (w, height))
        y, flip = 0, False
        while y < height:
            b = band.transpose(Image.FLIP_TOP_BOTTOM) if flip else band
            out.paste(b, (0, y))
            y += band.height
            flip = not flip
        return out
    top_fill = stack(tb, half)
    bot_fill = stack(bb.transpose(Image.FLIP_TOP_BOTTOM), half)
    fill = Image.new("RGB", (w, th))
    fill.paste(top_fill.crop((0, 0, w, th - half)), (0, 0)) if th > half else None
    # assemble with crossfade in the middle
    meet = th // 2
    fill.paste(top_fill.crop((0, 0, w, meet)), (0, 0))
    fill.paste(bot_fill.crop((0, half - (th - meet), w, half)), (0, meet))
    # feather the seam, then soften band-stacking artifacts across the fill
    seam = fill.crop((0, max(0, meet - 5), w, min(th, meet + 5))).filter(ImageFilter.GaussianBlur(2.2))
    fill.paste(seam, (0, max(0, meet - 5)))
    fill = fill.filter(ImageFilter.GaussianBlur(1.3))
    im.paste(fill, (x0, ty0))
    return im


def synth(img, x0, x1, y0, y1, sx0, sx1):
    """Repaint (x0..x1, y0..y1) with the per-row mean color of the clean
    column window [sx0:sx1], plus matched gaussian noise."""
    a = np.asarray(img, dtype=np.float64)
    src = a[y0:y1, sx0:sx1, :]
    row_mean = src.mean(axis=1, keepdims=True)          # (h,1,3)
    sigma = float(src.std(axis=(0, 1)).mean()) * 0.55
    h, w = y1 - y0, x1 - x0
    noise = rng.normal(0, sigma, (h, w, 3))
    patch = np.clip(row_mean + noise, 0, 255)
    out = a.copy()
    out[y0:y1, x0:x1, :] = patch
    im = Image.fromarray(out.astype(np.uint8))
    # soften the patch borders
    pad = 3
    bx0, by0 = max(0, x0 - pad), max(0, y0 - pad)
    bx1, by1 = min(im.width, x1 + pad), min(im.height, y1 + pad)
    region = im.crop((bx0, by0, bx1, by1)).filter(ImageFilter.GaussianBlur(1.1))
    im.paste(region, (bx0, by0))
    return im


def tone_transfer(band, ref_swatch):
    b = np.asarray(band, dtype=np.float64)
    r = np.asarray(ref_swatch, dtype=np.float64)
    out = np.zeros_like(b)
    for ch in range(3):
        bs = b[..., ch].std() or 1.0
        out[..., ch] = (b[..., ch] - b[..., ch].mean()) * (r[..., ch].std() / bs) + r[..., ch].mean()
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def flood_key(img, tol=26, feather=1.4, sides="lr", yclip=None):
    """Remove background connected to the border. Per-row references for the
    left/right margins (and per-column top/bottom refs with sides='lrtb').
    yclip=(y0,y1) additionally hard-clears everything outside that band."""
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
    # keep only the largest opaque component — floating keyed-out junk
    # (garden blobs, stray fringes) cannot survive
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
    al = Image.fromarray(alpha, "L").filter(ImageFilter.MinFilter(3))  # 1px erode: kills fringe
    al = al.filter(ImageFilter.GaussianBlur(feather))
    out = img.convert("RGBA"); out.putalpha(al)
    return out


def geo_mask(img, draw_fn, feather=1.4):
    al = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(al)
    draw_fn(d, img.width, img.height)
    al = al.filter(ImageFilter.GaussianBlur(feather))
    out = img.convert("RGBA"); out.putalpha(al)
    return out


def octagon(c=18, inset=3):
    def f(d, w, h):
        i = inset
        d.polygon([(i + c, i), (w - i - c, i), (w - i, i + c), (w - i, h - i - c),
                   (w - i - c, h - i), (i + c, h - i), (i, h - i - c), (i, i + c)], fill=255)
    return f


def punch_hole(img, cx, cy, r):
    al = img.getchannel("A")
    hole = Image.new("L", img.size, 0)
    hd = ImageDraw.Draw(hole)
    hd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    hole = hole.filter(ImageFilter.GaussianBlur(0.8))
    al = Image.fromarray(np.clip(np.asarray(al, dtype=np.int16) - np.asarray(hole, dtype=np.int16), 0, 255).astype(np.uint8))
    img.putalpha(al)
    return img


def finish(img, name, scale=2):
    big = img.resize((img.width * scale, img.height * scale), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2))
    big.save(OUT + name, optimize=True)
    print(f"{name:22s} {big.size[0]}x{big.size[1]}")


# ------------------------------------------------------------ header slab
# text spans x 36..408, y 30..58; clean stone above/below; keeps the slab's
# segment seams continuous.
h = crop((162, 358, 610, 452))
h = vpatch(h, 32, 412, 26, 62, (8, 26), (62, 80))
finish(flood_key(h, tol=24, sides="lr"), "header.png")

# ------------------------------------------------------------------- tabs
t = crop((196, 446, 386, 520))
t = vpatch(t, 38, 152, 22, 52, (10, 22), (52, 62))
finish(flood_key(t, tol=18, feather=1.1), "tab-active.png")

t = crop((386, 446, 574, 518))
t = vpatch(t, 38, 150, 22, 52, (10, 22), (52, 62))
finish(flood_key(t, tol=22), "tab-idle.png")

# ------------------------------------------------------------------- rows
# crop-local: cap face 38..92 (digit 52..84), medallion+name 92..300+,
# clean planks 300..462 (wood) / 348..462 (stone), plate 468..556
# (digits 494..546), right end 556..572.
ROW_BOXES = {
    "row-gold.png":  (90, 516, 662, 608),
    "row-stone.png": (90, 606, 662, 700),
    "row-wood.png":  (90, 700, 662, 792),
}
row_imgs = {name: crop(box) for name, box in ROW_BOXES.items()}
# donor plank band from ROW 4 ("#4 Buggyr" is short; stop before the plate)
row4 = crop((90, 792, 662, 884))
wood_band = row4.crop((352, 0, 456, row4.height))
for name, r in row_imgs.items():
    hh = r.height
    if name == "row-gold.png":
        swatch = r.crop((456, 10, 468, hh - 12))
        band = tone_transfer(wood_band.resize((wood_band.width, hh), Image.LANCZOS), swatch)
        src = Image.new("RGB", (r.width, hh))
        src.paste(band, (302, 0))
        r = hpatch(r, 92, 462, 302, 302 + band.width, source_img=src)
    elif name == "row-stone.png":
        r = hpatch(r, 92, 462, 350, 440)
    else:
        band = wood_band.resize((wood_band.width, hh), Image.LANCZOS)
        src = Image.new("RGB", (r.width, hh))
        src.paste(band, (302, 0))
        r = hpatch(r, 92, 462, 302, 302 + band.width, source_img=src)
    r = synth(r, 52, 88, 18, hh - 24, 38, 50)               # cap digit (face column)
    r = synth(r, 478, 552, 16, hh - 20, 462, 477)           # plate digits
    keyed = flood_key(r, tol=24, yclip=(3, hh - 3))
    # trim the leading transparent margin so the painted cap starts at the
    # element's left edge in border-image renders
    finish(keyed.crop((12, 0, keyed.width - 2, keyed.height)), name)

# medallion ring from row 3 — tight, centered, hole punched for avatars
ring = crop((192, 704, 268, 780))
ring = geo_mask(ring, lambda d, w, h: d.ellipse([1, 1, w - 2, h - 2], fill=255), feather=1.2)
ring = punch_hole(ring, ring.width / 2, ring.height / 2, ring.width * 0.36)
finish(ring, "row-ring.png")

# ------------------------------------------------------------ START plate
# text x 150..440, y 64..112; parchment clean above/below.
s = crop((90, 950, 664, 1110))
s = vpatch(s, 146, 448, 60, 116, (34, 60), (116, 140))
finish(flood_key(s, tol=22), "start.png")

# -------------------------------------------------------------- close bar
# "Close" x 258..338; clean planks 120..252 and 340..456.
c = crop((88, 1106, 664, 1184))
c = hpatch(c, 250, 345, 348, 452)
finish(flood_key(c, tol=24), "close.png")

# ------------------------------------------------------------------ pills
p = crop((120, 32, 254, 110))
coin = p.crop((24, 20, 62, 60))
p2 = synth(p, 20, 112, 14, 64, 104, 111)
finish(flood_key(p2, tol=20), "pill.png")

finish(geo_mask(coin, lambda d, w, h: d.ellipse([1, 1, w - 2, h - 2], fill=255), feather=1.0), "icon-coin.png")

sp = crop((256, 30, 410, 110))
spark = sp.crop((26, 16, 74, 64))
def spark_mask(d, w, h):
    cx, cy = w / 2, h / 2
    d.polygon([(cx, 1), (cx * 1.28, cy * 0.72), (w - 1, cy), (cx * 1.28, cy * 1.28),
               (cx, h - 1), (cx * 0.72, cy * 1.28), (1, cy), (cx * 0.72, cy * 0.72)], fill=255)
finish(geo_mask(spark, spark_mask, feather=1.0), "icon-spark.png")

# --------------------------------------------------------- big medallion
md = crop((634, 8, 768, 150))
def med_mask(d, w, h):
    import math
    cx, cy, r, s = 66, 71, 53, 12
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    for ang in (0, 90, 180, 270):
        px = cx + math.sin(math.radians(ang)) * (r + 2)
        py = cy - math.cos(math.radians(ang)) * (r + 2)
        pts = [(px + math.cos(math.radians(cr + 45)) * s * 1.35,
                py + math.sin(math.radians(cr + 45)) * s * 1.35) for cr in (0, 90, 180, 270)]
        d.polygon(pts, fill=255)
med = geo_mask(md, med_mask, feather=1.3)
med = punch_hole(med, 66, 71, 44)
finish(med, "medallion-ring.png")

# --------------------------------------------------------------- X button
x = crop((12, 20, 122, 124))
finish(geo_mask(x, lambda d, w, h: d.rounded_rectangle([8, 8, w - 9, h - 9], radius=26, fill=255), feather=1.6), "x-button.png")

# ------------------------------------------------------------ panel frame
# 4 corner-stone sprites (octagon-masked, tight) + repeatable edge bands.
for name, box in {
    "corner-tl.png": (42, 418, 134, 510),
    "corner-tr.png": (606, 416, 698, 508),
    "corner-bl.png": (42, 1116, 134, 1208),
    "corner-br.png": (606, 1114, 698, 1206),
}.items():
    finish(geo_mask(crop(box), octagon(c=20, inset=5), feather=1.5), name)

# the mockup panel has a subtle perspective tilt, so the vertical band is
# derived from the (clean) horizontal one instead of sampled directly
edge_h = crop((134, 423, 166, 462))
finish(edge_h.convert("RGBA"), "edge-h.png")
finish(edge_h.rotate(90, expand=True).convert("RGBA"), "edge-v.png")

print("done ->", OUT)
