#!/usr/bin/env python3
"""Rebuild the Players/Groups tab slabs from the approved mockup.

tab-active.png — grey-green chamfered slab + SYNTHETIC green glow that
fades out fully inside a padded canvas (mockup's glow was crop-clipped
and carried baked parchment).
tab-idle.png — light stone slab cut with a precise polygon so the header
slab's drop shadow (the "floating fragment") and top-right slivers can
never survive. Labels removed with a gradient-aware per-row synth.

Run from games/backyard:  python3 tools/fix-tabs.py
"""
from PIL import Image, ImageFilter, ImageDraw
import numpy as np

SRC = "design-ref/splash-mockup.png"
OUT = "public/ui/kit/"
M = Image.open(SRC).convert("RGB")
rng = np.random.default_rng(11)


def synth2(img, x0, x1, y0, y1, lw, rw):
    """Repaint the text band with a per-row LEFT->RIGHT linear blend of the
    clean window means (lw=(lx0,lx1), rw=(rx0,rx1)) + matched noise. Keeps
    the face's vertical shading AND its horizontal gradient."""
    a = np.asarray(img, dtype=np.float64)
    left = a[y0:y1, lw[0]:lw[1], :]
    right = a[y0:y1, rw[0]:rw[1], :]
    lm = left.mean(axis=1, keepdims=True)                 # (h,1,3)
    rm = right.mean(axis=1, keepdims=True)
    sigma = float(np.concatenate([left, right], axis=1).std(axis=(0, 1)).mean()) * 0.5
    h, w = y1 - y0, x1 - x0
    t = np.linspace(0.0, 1.0, w)[None, :, None]
    patch = lm * (1 - t) + rm * t + rng.normal(0, sigma, (h, w, 3))
    out = a.copy()
    out[y0:y1, x0:x1, :] = np.clip(patch, 0, 255)
    im = Image.fromarray(out.astype(np.uint8))
    pad = 3
    box = (max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad))
    im.paste(im.crop(box).filter(ImageFilter.GaussianBlur(1.0)), box[:2])
    return im


def poly_mask(size, pts, feather=1.2):
    al = Image.new("L", size, 0)
    ImageDraw.Draw(al).polygon(pts, fill=255)
    return al.filter(ImageFilter.GaussianBlur(feather))


def dilate(mask_l, px):
    m = mask_l
    for _ in range(px):
        m = m.filter(ImageFilter.MaxFilter(3))
    return m


def finish(img, name, scale=2):
    big = img.resize((img.width * scale, img.height * scale), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2))
    big.save(OUT + name, optimize=True)
    print(f"{name:16s} {big.size[0]}x{big.size[1]}")


# =================================================================== ACTIVE
# canvas (195,439)-(389,521): slab (209,453)-(375,507) centered w/ 13-14px
# of air so the synthetic glow dies inside the canvas.
AX, AY = 195, 439
act = M.crop((AX, AY, 389, 521))                       # 194 x 82
# erase "Players" (+ its drop shadow): gradient synth across the face
act = synth2(act, 37, 156, 27, 64, (24, 36), (158, 172))

slab_pts = [(24, 13.5), (170, 13.5), (180.5, 23.5), (180.5, 59),
            (170, 68.5), (26, 68.5), (13.5, 58), (13.5, 24.5)]
slab_al = poly_mask(act.size, slab_pts, feather=1.1)

hard = Image.new("L", act.size, 0)
ImageDraw.Draw(hard).polygon(slab_pts, fill=255)

# glow layers (built OUTSIDE the slab, faded well before canvas edges)
ring_band = np.asarray(dilate(hard, 2), dtype=np.int16) - np.asarray(hard, dtype=np.int16)
ring = Image.fromarray(np.clip(ring_band, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))
halo_band = np.asarray(dilate(hard, 5), dtype=np.int16) - np.asarray(hard, dtype=np.int16)
halo = Image.fromarray(np.clip(halo_band, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3.0))

ring_a = np.asarray(ring, dtype=np.float64) / 255.0
halo_a = np.asarray(halo, dtype=np.float64) / 255.0
glow_a = np.clip(ring_a * 0.95 + halo_a * 0.45, 0, 1)
# mockup's glow reads brighter under the slab than above it (baked AO from
# the header slab) — reproduce with a gentle vertical gain
vgain = np.linspace(0.82, 1.0, act.height)[:, None]
glow_a = np.clip(glow_a * vgain, 0, 1)

canvas = np.zeros((act.height, act.width, 4), dtype=np.float64)
glow_rgb = np.array([200, 246, 164], dtype=np.float64)
canvas[..., :3] = glow_rgb
canvas[..., 3] = glow_a * 255.0
glow_img = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGBA")

slab_rgba = act.convert("RGBA")
slab_rgba.putalpha(slab_al)
out = Image.alpha_composite(glow_img, slab_rgba)
finish(out, "tab-active.png")

# ===================================================================== IDLE
# canvas (380,439)-(564,521): slab (389,452)-(556,508) + painted drop
# shadow to ~512 + the right-side chip. Polygon cut = header shadow junk
# and top-right slivers cannot survive.
IX, IY = 380, 439
idl = M.crop((IX, IY, 564, 521))                       # 184 x 82
# erase "Groups" (+ shadow)
idl = synth2(idl, 47, 144, 25, 64, (22, 44), (146, 166))

idle_pts = [(9, 18), (14, 14.5), (40, 13), (156, 13), (167, 14.5),
            (176, 22), (176, 62), (168, 72), (120, 74), (40, 74),
            (15, 72), (9, 65)]
idle_al = poly_mask(idl.size, idle_pts, feather=1.2)
out = idl.convert("RGBA")
out.putalpha(idle_al)
finish(out, "tab-idle.png")

print("done ->", OUT)
