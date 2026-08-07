#!/usr/bin/env python3
"""Rebuild public/ui/kit/header-v2.png — the WEEKLY LEADERBOARD stone slab
that the live UI actually renders (ui-kit.jsx StoneSlab, lettering baked in).

The kit copy had been run through a destructive tone pass: opaque mean RGB
~51 (near-black, cool) vs the approved design-ref/header-sign-v2.png at
~144 (warm cream stone).  On device that read as a cold gray-green slab
with a heavy uniform black band along the bottom — the exact defect the
critic panel flagged.

Fix: regenerate from the approved ref with
  * per-channel gain matching the ref's clean face to the mockup slab face
    (design-ref/splash-mockup.png crop 160,356..612,454, rows above/below
    the lettering) so the stone sits in the mockup's warm palette
  * gentle low-frequency warm mottle added on the bright face only, to
    recover the mockup's painterly stain variance (mock face std ~14 vs
    ref ~7) without touching the carved letters or dark bevels
  * alpha dust below 8 zeroed; resize 1298x292 -> 1000x225 LANCZOS + mild
    unsharp (same box the component expects)

Run from games/backyard:  python3 tools/fix-header-v2.py
Output: public/ui/kit/header-v2.png (1000x225)
"""
from PIL import Image, ImageFilter
import numpy as np

REF = "design-ref/header-sign-v2.png"
MOCK = "design-ref/splash-mockup.png"
OUT = "public/ui/kit/header-v2.png"
rng = np.random.default_rng(7)

ref = Image.open(REF).convert("RGBA")
W, H = ref.size                                   # 1298 x 292
a = np.asarray(ref, dtype=np.float64)
rgb, alpha = a[..., :3], a[..., 3]

# ---------------------------------------------------------- palette match
m = np.asarray(Image.open(MOCK).convert("RGB"), dtype=np.float64)
mock_face = np.concatenate([
    m[368:380, 220:540].reshape(-1, 3),           # clean face above lettering
    m[420:432, 220:540].reshape(-1, 3),           # clean face below lettering
])
ref_face = np.concatenate([
    a[60:95, 200:1100, :3].reshape(-1, 3),
    a[200:225, 200:1100, :3].reshape(-1, 3),
])
gain = mock_face.mean(axis=0) / ref_face.mean(axis=0)
print("per-channel gain", np.round(gain, 4))
rgb = rgb * gain[None, None, :]

# ------------------------------------------------------------- face mottle
# warm painterly staining, only where the stone face is bright (leaves the
# carved letters and the dark 3D base edge alone)
lum = rgb.mean(axis=2)
face_w = np.clip((lum - 105.0) / 45.0, 0.0, 1.0) * (alpha > 128)
stain = rng.normal(0, 1.0, (H // 22 + 2, W // 22 + 2))
stain = np.asarray(Image.fromarray(
    np.clip(stain * 40 + 128, 0, 255).astype(np.uint8)).resize((W, H), Image.BICUBIC),
    dtype=np.float64)
stain = (stain - 128.0) / 40.0                    # back to ~N(0,1)
stain2 = rng.normal(0, 1.0, (H // 9 + 2, W // 9 + 2))
stain2 = np.asarray(Image.fromarray(
    np.clip(stain2 * 40 + 128, 0, 255).astype(np.uint8)).resize((W, H), Image.BICUBIC),
    dtype=np.float64)
stain2 = (stain2 - 128.0) / 40.0
mottle = (stain * 3.5 + stain2 * 1.5)[..., None] * np.array([1.0, 0.88, 0.66])
rgb = rgb + mottle * face_w[..., None]

# --------------------------------------------------- bottom band de-weight
# the critic read the base extrusion as a "heavy uniform dark shadow band":
# the mockup's band sits ~13 points lighter (about 72/76/61 vs our 59) and
# has painterly variation.  Lift the dark pixels of the lower quarter toward
# a slate gray and let the coarse stain field break up the uniformity.
lum2 = rgb.mean(axis=2)
yy = np.arange(H)[:, None] / H
band_w = np.clip((yy - 0.66) / 0.10, 0, 1) * np.clip((95.0 - lum2) / 45.0, 0, 1)
band_w = band_w * (alpha > 128)
lift = (np.array([70.0, 72.0, 68.0])[None, None, :] - rgb) * 0.38
lift = lift * (1.0 + 0.5 * stain[..., None])      # painterly unevenness
rgb = rgb + lift * band_w[..., None]

# -------------------------------------------------------- top bevel warmth
# mockup's top bevel is a creamy warm (~151/138/110, B/R 0.73); the ref's is
# brighter and cooler (~172/157/141, B/R 0.82).  Pull the bright band at the
# top of the slab toward the mockup cream.
lum_tb = rgb.mean(axis=2)
top_w = (np.clip((0.25 - yy) / 0.12, 0, 1)
         * np.clip((lum_tb - 140.0) / 30.0, 0, 1) * (alpha > 128))
bevel_gain = np.array([0.94, 0.93, 0.84])
rgb = rgb * (1 - top_w[..., None]) + (rgb * bevel_gain[None, None, :]) * top_w[..., None]

# -------------------------------------------------------- letter warm-lift
# mockup lettering is a warm carved brown (~60/42/25); the ref's is nearly
# black (~42/34/23).  Blend the dark pixels of the text band toward the
# mockup brown, keeping the carved shading.
lum3 = rgb.mean(axis=2)
txt_y = np.zeros((H, 1)); txt_y[95:200] = 1.0
txt_x = np.zeros((1, W)); txt_x[:, 100:1200] = 1.0
letter_w = np.clip((100.0 - lum3) / 50.0, 0, 1) * txt_y * txt_x * (alpha > 128)
target = np.array([62.0, 43.0, 26.0])
rgb = rgb + (target[None, None, :] - rgb) * (letter_w * 0.45)[..., None]

# --------------------------------------------------- face speckle soften
# the mockup face is soft painterly stone; the ref carries hard AI speckle
# that survives the downscale.  Blur blended only where the face is bright
# (face_w) so bevels, seams and letters stay crisp.
sm = np.asarray(Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).filter(
    ImageFilter.GaussianBlur(2.0)), dtype=np.float64)
w_sm = (face_w * 0.45)[..., None]
rgb = rgb * (1 - w_sm) + sm * w_sm

out = np.dstack([np.clip(rgb, 0, 255), alpha])
im = Image.fromarray(out.astype(np.uint8), "RGBA")

# ------------------------------------------------------- resize + sharpen
im = im.resize((1000, 225), Image.LANCZOS)
im = im.filter(ImageFilter.UnsharpMask(radius=1.6, percent=30, threshold=2))
arr = np.asarray(im).copy()
arr[..., 3][arr[..., 3] < 8] = 0                  # kill resampling dust
Image.fromarray(arr, "RGBA").save(OUT, optimize=True)
print("saved", OUT, im.size)
