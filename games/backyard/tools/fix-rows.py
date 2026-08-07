#!/usr/bin/env python3
"""Rebuild the three leaderboard row plaques + avatar ring from the mockup.

Fixes over build-splash-assets.py output:
  - baked drop shadows / neighbor-row bleed removed: alpha is limited by the
    plank's measured top/bottom edge lines (per column), a rounded-octagon
    cap mask and an end-block mask — shadows below the groove cannot survive
  - stone cap's dark backing spill removed (outside the cap octagon)
  - plank fill: multi-donor quilting with per-window VERTICAL ALIGNMENT
    (each donor window is rescaled/shifted so its plank edges land on the
    destination row's edge lines) — no pale smears, no repetition
  - donor windows stop at x435 (the score plate's left bevel starts ~x440)
  - painterly grain streaks + low-frequency tonal drift overlaid
  - cap faces: digit erased with per-row L/R interpolation + facet break
  - score plates: digit erased from the plate's own left interior + inset
    shading so the plate face isn't flat
  - gold row keeps its warm rim glow (wider alpha band + softer feather)
  - ring: annulus with enhanced metallic shading (top-lit, rim-shaded)

Run from games/backyard:  python3 tools/fix-rows.py
Only writes: public/ui/kit/row-{gold,stone,wood,ring}.png
"""
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
import os, collections

SRC = "design-ref/splash-mockup.png"
OUT = "public/ui/kit/"
M = Image.open(SRC).convert("RGB")
rng = np.random.default_rng(11)


# ---------------------------------------------------------------- helpers
def crop(box):
    return M.crop(box)


def line_at(p, x):
    """p = (y_at_115, y_at_430) -> linear interp/extrapolation."""
    y0, y1 = p
    return y0 + (y1 - y0) * (x - 115.0) / (430.0 - 115.0)


def smooth_rows(prof, sigma=2.0):
    k = int(sigma * 3) * 2 + 1
    xs = np.arange(k) - k // 2
    g = np.exp(-(xs ** 2) / (2 * sigma ** 2))
    g /= g.sum()
    out = np.empty_like(prof)
    for c in range(prof.shape[2]):
        col = prof[:, 0, c]
        pad = np.pad(col, k // 2, mode="edge")
        out[:, 0, c] = np.convolve(pad, g, mode="valid")
    return out


def profile_transfer(band_np, target_prof, donor_span, target_span, contrast=1.0):
    """Move a donor band onto the target's per-row mean profile: keeps donor
    texture detail, adopts the target's vertical shading + hue. The target
    profile is warped so target plank rows (target_span) map onto donor
    plank rows (donor_span)."""
    own = smooth_rows(band_np.mean(axis=1, keepdims=True), 2.0)
    detail = (band_np - own) * contrast
    dh = band_np.shape[0]
    th = target_prof.shape[0]
    d0, d1 = donor_span
    t0, t1 = target_span
    tp = np.empty((dh, 1, 3))
    for y in range(dh):
        # map donor row -> target row via plank spans (linear)
        ty = t0 + (y - d0) * (t1 - t0) / max(1e-6, (d1 - d0))
        ty = min(max(ty, 0), th - 1)
        y0i = int(ty)
        y1i = min(y0i + 1, th - 1)
        f = ty - y0i
        tp[y, 0] = target_prof[y0i, 0] * (1 - f) + target_prof[y1i, 0] * f
    return np.clip(detail + tp, 0, 255)


def aligned_window(donor, sx0, ww, dest_top, dest_bot, out_h):
    """Extract donor window [sx0:sx0+ww] and rescale its plank rows so the
    donor's top/bot edge lines land on dest_top/dest_bot. Rows outside are
    edge-padded (they get alpha-cut anyway)."""
    arr, dx0, dx1, tline, bline = donor
    xm = sx0 + ww / 2.0
    st = line_at(tline, xm)
    sb = line_at(bline, xm)
    pad = 5
    y0 = max(0, int(round(st - pad)))
    y1 = min(arr.shape[0], int(round(sb + pad)))
    win = arr[y0:y1, sx0:sx0 + ww, :]
    # destination row range for the same pad
    dt, db = dest_top - pad, dest_bot + pad
    dh = max(4, int(round(db - dt)))
    im = Image.fromarray(win.astype(np.uint8)).resize((ww, dh), Image.LANCZOS)
    win = np.asarray(im, dtype=np.float64)
    out = np.empty((out_h, ww, 3), dtype=np.float64)
    ty0 = int(round(dt))
    for y in range(out_h):
        sy = y - ty0
        sy = min(max(sy, 0), dh - 1)
        out[y] = win[sy]
    return out


def quilt_aligned(donors, weights, x_start, x_end, dest_tline, dest_bline,
                  out_h, ov=14, win_lo=52, win_hi=92):
    width = x_end - x_start
    canvas = np.zeros((out_h, width + win_hi, 3), dtype=np.float64)
    wsum = np.zeros((1, width + win_hi, 1), dtype=np.float64)
    # target tonal level: weighted mean of the donors' plank rows, so every
    # window sits at the same level (no window-to-window tonal jumps)
    xm0 = (x_start + x_end) / 2.0
    dt0, db0 = line_at(dest_tline, xm0), line_at(dest_bline, xm0)
    means = []
    for d in donors:
        wball = aligned_window(d, d[1], d[2] - d[1], dt0, db0, out_h)
        means.append(wball[int(dt0 + 4):int(db0 - 3), :, :].mean(axis=(0, 1)))
    target_mean = np.average(np.array(means), axis=0, weights=weights)
    pos = 0
    while pos < width:
        di = rng.choice(len(donors), p=weights)
        d = donors[di]
        avail = d[2] - d[1]
        wmax = min(win_hi, avail)
        wlo = min(win_lo, wmax - 1)
        ww = int(rng.integers(wlo, wmax)) if wmax > wlo else wmax
        sx0 = d[1] + int(rng.integers(0, avail - ww + 1))
        xm_dest = x_start + pos + ww / 2.0
        dt = line_at(dest_tline, xm_dest)
        db = line_at(dest_bline, xm_dest)
        patch = aligned_window(d, sx0, ww, dt, db, out_h)
        if rng.random() < 0.5:
            patch = patch[:, ::-1, :]
        pmean = patch[int(dt + 4):int(db - 3), :, :].mean(axis=(0, 1))
        patch = np.clip(patch + (target_mean - pmean)[None, None, :] * 0.85, 0, 255)
        ramp = np.ones((1, ww, 1))
        r = min(ov, ww // 3)
        ramp[0, :r, 0] = np.linspace(0.05, 1, r)
        ramp[0, -r:, 0] = np.linspace(1, 0.05, r)
        canvas[:, pos:pos + ww, :] += patch * ramp
        wsum[:, pos:pos + ww, :] += ramp
        pos += ww - r
    return canvas[:, :width, :] / np.maximum(wsum[:, :width, :], 1e-6)


def add_grain(a, x0, x1, tline, bline, n_streaks=12, drift_amp=4.0, seed_shift=0):
    """Painterly horizontal grain streaks + low-frequency tonal drift,
    confined between the plank edge lines."""
    h, w = a.shape[:2]
    r2 = np.random.default_rng(23 + seed_shift)
    yy, xx = np.mgrid[0:h, 0:w]
    tl = line_at(tline, xx.astype(float))
    bl = line_at(bline, xx.astype(float))
    band = ((xx >= x0) & (xx < x1) & (yy > tl + 5) & (yy < bl - 5)).astype(float)
    xs = np.arange(w, dtype=np.float64)
    drift = np.zeros(w)
    for _ in range(3):
        f = r2.uniform(1.0, 2.6)
        ph = r2.uniform(0, 6.28)
        drift += np.sin(xs / (x1 - x0) * 3.1415 * f + ph)
    drift = drift / 3.0 * drift_amp
    ov = drift[None, :] * band
    img = Image.new("F", (w, h), 0.0)
    d = ImageDraw.Draw(img)
    for _ in range(n_streaks):
        sx = r2.uniform(x0, x1 - 60)
        ln = r2.uniform(60, 220)
        ex = min(x1 - 2, sx + ln)
        xm = (sx + ex) / 2
        yt, yb = line_at(tline, xm), line_at(bline, xm)
        sy = r2.uniform(yt + 7, yb - 7)
        amp = r2.uniform(5, 11) * (1 if r2.random() < 0.5 else -1)
        th = int(r2.integers(2, 4))
        wob = r2.uniform(-2.0, 2.0)
        pts = []
        for i in range(7):
            t = i / 6
            pts.append((sx + (ex - sx) * t,
                        sy + wob * np.sin(t * 3.1415) + r2.uniform(-0.5, 0.5)))
        d.line(pts, fill=float(amp), width=th)
    st = np.asarray(img, dtype=np.float64)
    enc = Image.fromarray(np.clip(st * 4 + 128, 0, 255).astype(np.uint8), "L")
    enc = enc.filter(ImageFilter.GaussianBlur(1.1))
    st = (np.asarray(enc, dtype=np.float64) - 128) / 4.0
    ov += st * band
    return np.clip(a + ov[:, :, None] * np.array([1.0, 0.92, 0.8])[None, None, :], 0, 255)


def column_wash(a, orig, tline, bline, fill_x, meas_x=(192, 435), ref_x=(400, 435),
                sigma=25.0):
    """The mockup planks carry a horizontal light wash (strongest on the gold
    row, from its rim glow). The quilted fill is built from a single vertical
    profile, so re-apply the original's per-column gain inside the fill zone.
    Gain is measured on ORIG rows near the plank edges (text-free bands)."""
    h, w = a.shape[:2]
    prof = np.zeros((w, 3))
    for x in range(meas_x[0], meas_x[1]):
        t = line_at(tline, x)
        rows = list(range(int(t + 3), int(t + 10)))   # top band: text-free,
        prof[x] = np.median(orig[rows, x, :], axis=0)  # tracks the light wash
    prof[:meas_x[0]] = prof[meas_x[0]]
    prof[meas_x[1]:] = prof[meas_x[1] - 1]
    # smooth along x
    k = int(sigma * 3) * 2 + 1
    xs = np.arange(k) - k // 2
    g = np.exp(-(xs ** 2) / (2 * sigma ** 2)); g /= g.sum()
    for c in range(3):
        prof[:, c] = np.convolve(np.pad(prof[:, c], k // 2, mode="edge"), g, "valid")
    ref = prof[ref_x[0]:ref_x[1]].mean(axis=0)
    gain = np.clip(prof / np.maximum(ref[None, :], 1e-6), 0.82, 1.4)
    out = a.copy()
    for x in range(*fill_x):
        t = line_at(tline, x)
        b = line_at(bline, x)
        y0, y1 = max(0, int(t - 2)), min(h, int(b + 4))
        out[y0:y1, x, :] = np.clip(a[y0:y1, x, :] * gain[x][None, :], 0, 255)
    return out


def hinterp_fill(a, x0, x1, y0, y1, lx0, lx1, rx0, rx1, noise_scale=0.5):
    left = a[y0:y1, lx0:lx1, :].mean(axis=1, keepdims=True)
    right = a[y0:y1, rx0:rx1, :].mean(axis=1, keepdims=True)
    w = x1 - x0
    t = np.linspace(0, 1, w)[None, :, None]
    fill = left * (1 - t) + right * t
    sigma = float(np.concatenate([a[y0:y1, lx0:lx1, :], a[y0:y1, rx0:rx1, :]],
                                 axis=1).std(axis=(0, 1)).mean()) * noise_scale
    fill = fill + rng.normal(0, sigma, fill.shape)
    a = a.copy()
    a[y0:y1, x0:x1, :] = np.clip(fill, 0, 255)
    return a


def soften(img, x0, y0, x1, y1, rad=1.0, pad=3):
    bx0, by0 = max(0, x0 - pad), max(0, y0 - pad)
    bx1, by1 = min(img.width, x1 + pad), min(img.height, y1 + pad)
    region = img.crop((bx0, by0, bx1, by1)).filter(ImageFilter.GaussianBlur(rad))
    img.paste(region, (bx0, by0))
    return img


def flood_bg_mask(a, tol=24):
    """Boolean mask of border-connected background pixels. Only the RIGHT
    margin is used as the background reference — the left margin contains
    the panel frame, whose brown is too close to the plank wood."""
    h, w = a.shape[:2]
    bg_r = np.median(a[:, -4:, :], axis=1)
    near_bg = np.sqrt(((a - bg_r[:, None, :]) ** 2).sum(axis=2)) <= tol
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
    return mask


def largest_component(opaque):
    h, w = opaque.shape
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
    return keep


def row_alpha(img, cfg):
    """flood key + geometric silhouette limits."""
    a = np.asarray(img.convert("RGB"), dtype=np.int16)
    h, w = a.shape[:2]
    bgmask = flood_bg_mask(a, tol=cfg.get("tol", 24))
    alpha = np.where(bgmask, 0, 255).astype(np.uint8)
    # geometric keep-mask
    keep = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(keep)
    ex = cfg.get("expand", 0)          # gold glow allowance
    exb = cfg.get("expand_bot", ex)
    # cap octagon
    cx0, cx1, cy0, cy1, cc = cfg["cap"]
    cx0, cy0, cx1, cy1 = cx0 - ex, cy0 - ex, cx1 + ex, cy1 + exb
    d.polygon([(cx0 + cc, cy0), (cx1 - cc, cy0), (cx1, cy0 + cc), (cx1, cy1 - cc),
               (cx1 - cc, cy1), (cx0 + cc, cy1), (cx0, cy1 - cc), (cx0, cy0 + cc)],
              fill=255)
    # body between edge lines
    tline, bline = cfg["top"], cfg["bot"]
    bx0, bx1 = cfg["body_x"]
    poly = [(x, line_at(tline, x) - 1.5 - ex) for x in range(bx0, bx1 + 1, 8)]
    bpad = 1.8 if exb else 0.6
    poly += [(x, line_at(bline, x) + bpad + exb) for x in range(bx1, bx0 - 1, -8)]
    d.polygon(poly, fill=255)
    # end block
    ex0, ex1, ey0, ey1 = cfg["end"]
    d.rounded_rectangle([ex0, ey0 - ex, ex1 + ex, ey1 + exb], radius=6, fill=255)
    keep_np = np.asarray(keep) > 0
    alpha = np.where(keep_np, alpha, 0).astype(np.uint8)
    alpha[:, :cfg["left_lim"]] = 0
    alpha[:, cfg.get("right_lim", 566):] = 0
    alpha = np.where(largest_component(alpha > 0), alpha, 0).astype(np.uint8)
    al = Image.fromarray(alpha, "L").filter(ImageFilter.MinFilter(3))
    al = al.filter(ImageFilter.GaussianBlur(cfg.get("feather", 1.2)))
    out = img.convert("RGBA")
    out.putalpha(al)
    return out


def defringe(img, thresh=200, iters=5):
    """Recolor semi-transparent edge pixels with the nearest opaque color so
    the feather band never shows baked background/shadow tints when the
    asset is composited over something that isn't parchment tan."""
    a = np.asarray(img, dtype=np.float64)
    rgb, al = a[..., :3].copy(), a[..., 3]
    solid = al >= thresh
    for _ in range(iters):
        grow = np.zeros_like(solid)
        acc = np.zeros_like(rgb)
        cnt = np.zeros(solid.shape)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(np.roll(solid, dy, 0), dx, 1)
            rgbsh = np.roll(np.roll(rgb, dy, 0), dx, 1)
            m = sh & ~solid
            acc[m] += rgbsh[m]
            cnt[m] += 1
            grow |= m
        m = cnt > 0
        rgb[m] = acc[m] / cnt[m][:, None]
        solid |= grow
    out = np.concatenate([rgb, al[..., None]], axis=2)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def finish(img, name, scale=2):
    big = img.resize((img.width * scale, img.height * scale), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2))
    big.save(OUT + name, optimize=True)
    print(f"{name:22s} {big.size[0]}x{big.size[1]}")
    return big


# ------------------------------------------------------------------- rows
ROW_BOXES = {
    "row-gold.png":  (90, 516, 662, 608),
    "row-stone.png": (90, 606, 662, 700),
    "row-wood.png":  (90, 700, 662, 792),
}
row_rgb = {n: np.asarray(crop(b), dtype=np.float64) for n, b in ROW_BOXES.items()}
row4 = np.asarray(crop((90, 792, 662, 884)), dtype=np.float64)

# plank edge lines per source, (y@x115, y@x430), measured from the mockup
LINES = {
    "gold":  ((13.0, 9.0),  (79.0, 77.0)),
    "stone": ((11.0, 6.0),  (74.0, 76.0)),
    "wood":  ((7.0, 3.0),   (66.0, 64.0)),
    "row4":  ((5.0, 2.0),   (58.0, 56.0)),
}
# donors: (array, clean_x0, clean_x1, top_line, bot_line) — stop before the
# score plate bevel (~x440)
DONORS = {
    "gold_own":  (row_rgb["row-gold.png"],  403, 435, *LINES["gold"]),
    "stone_own": (row_rgb["row-stone.png"], 356, 435, *LINES["stone"]),
    "wood_own":  (row_rgb["row-wood.png"],  290, 435, *LINES["wood"]),
    "row4":      (row4, 305, 435, *LINES["row4"]),
}

CFG = {
    "row-gold.png": dict(
        lines=LINES["gold"],
        fill=(100, 407), prof_win=(405, 435),
        donors=["gold_own", "row4", "wood_own"], weights=[0.4, 0.32, 0.28],
        transfer=[False, True, True], contrast=0.85,
        grain_n=10, drift=3.2,
        cap=(14, 100, 4, 79, 14), cap_fill=(56, 83, 22, 60),
        body_x=(96, 552), end=(548, 561, 6, 80),
        plate_fill_y=(19, 70), left_lim=13,
        expand=7, expand_bot=11, feather=2.2, tol=26,
    ),
    "row-stone.png": dict(
        lines=LINES["stone"],
        fill=(100, 360), prof_win=(358, 435),
        donors=["stone_own", "row4"], weights=[0.72, 0.28],
        transfer=[False, True], contrast=0.9,
        grain_n=11, drift=3.8,
        cap=(12, 101, 6, 83, 16), cap_fill=(56, 83, 26, 64),
        body_x=(96, 548), end=(534, 562, 3, 88),
        plate_fill_y=(15, 72), left_lim=12,
        expand=0, feather=1.2, tol=24,
    ),
    "row-wood.png": dict(
        lines=LINES["wood"],
        fill=(100, 294), prof_win=(292, 435),
        donors=["wood_own", "row4"], weights=[0.6, 0.4],
        transfer=[False, True], contrast=1.0,
        grain_n=12, drift=3.8,
        cap=(13, 99, 2, 79, 12), cap_fill=(56, 83, 16, 55),
        body_x=(96, 548), end=(534, 561, 1, 80),
        plate_fill_y=(11, 60), left_lim=13,
        expand=0, feather=1.2, tol=24,
    ),
}

for si, (name, cfg) in enumerate(CFG.items()):
    a = row_rgb[name].copy()
    h = a.shape[0]
    tline, bline = cfg["lines"]
    cfg["top"], cfg["bot"] = tline, bline
    # target vertical profile from this row's own clean plank window
    px0, px1 = cfg["prof_win"]
    # profile over plank rows only
    prof = smooth_rows(a[:, px0:px1, :].mean(axis=1, keepdims=True), 2.2)
    donors = []
    for key, tr in zip(cfg["donors"], cfg["transfer"]):
        arr, dx0, dx1, dt, db = DONORS[key]
        if tr:
            arr = arr.copy()
            xm = (dx0 + dx1) / 2.0
            dspan = (line_at(dt, xm), line_at(db, xm))
            tspan = (line_at(tline, xm), line_at(bline, xm))
            band = profile_transfer(arr[:, dx0:dx1, :], prof, dspan, tspan,
                                    contrast=cfg["contrast"])
            arr[:, dx0:dx1, :] = band
        donors.append((arr, dx0, dx1, dt, db))
    fx0, fx1 = cfg["fill"]
    strip = quilt_aligned(donors, np.array(cfg["weights"]) / sum(cfg["weights"]),
                          fx0, fx1, tline, bline, h)
    edge = 8
    t = np.linspace(0, 1, edge)[None, :, None]
    strip[:, :edge, :] = a[:, fx0:fx0 + edge, :] * (1 - t) + strip[:, :edge, :] * t
    strip[:, -edge:, :] = strip[:, -edge:, :] * (1 - t) + a[:, fx1 - edge:fx1, :] * t
    # the medallion arcs poke above/below the plank: replace those rows with
    # clean background copied from further right BEFORE pasting the strip
    for x in range(98, 192):
        tl = line_at(tline, x) - 2
        bl = line_at(bline, x) + 3
        for y in range(h):
            if y < tl or y > bl:
                a[y, x] = a[y, x + 118]
    # paste strip only between the plank edge lines (donor rows outside the
    # plank carry junk from THEIR crop surroundings)
    for xi, x in enumerate(range(fx0, fx1)):
        tl = line_at(tline, x) - 2
        bl = line_at(bline, x) + 3
        for y in range(h):
            if tl <= y <= bl:
                a[y, x] = strip[y, xi]
    # restore the original's horizontal light wash inside the fill zone
    a = column_wash(a, row_rgb[name], tline, bline, fill_x=(fx0, fx1))
    a = add_grain(a, fx0 - 4, 440, tline, bline,
                  n_streaks=cfg["grain_n"], drift_amp=cfg["drift"], seed_shift=si * 7)
    # soften the fill/original boundary between the plank edge lines
    img_t = Image.fromarray(a.astype(np.uint8))
    bt = int(min(line_at(tline, fx1), line_at(tline, fx0)))
    bb = int(max(line_at(bline, fx1), line_at(bline, fx0)))
    img_t = soften(img_t, fx1 - 6, bt + 2, fx1 + 6, bb - 1, rad=1.3, pad=0)
    a = np.asarray(img_t, dtype=np.float64)
    # cap digit erase
    cx0, cx1, cy0, cy1 = cfg["cap_fill"]
    a = hinterp_fill(a, cx0, cx1, cy0, cy1, 45, 55, 84, 91, noise_scale=0.55)
    # subtle facet break on the freshly filled face
    yy, xx = np.mgrid[0:h, 0:a.shape[1]]
    fxm = (cx0 + cx1) // 2
    diag = (xx - fxm) + (yy - (cy0 + cy1) / 2) * 0.35
    fb = (xx >= cx0) & (xx < cx1) & (yy >= cy0) & (yy < cy1)
    a = np.clip(a + np.where(fb & (diag < 0), 2.5, 0)[:, :, None]
                  - np.where(fb & (diag >= 0), 2.5, 0)[:, :, None], 0, 255)
    # plate digit erase: fill from the plate's own left interior (per-row)
    py0, py1 = cfg["plate_fill_y"]
    left = a[py0:py1, 452:474, :].mean(axis=1, keepdims=True)
    sigma = float(a[py0:py1, 452:474, :].std(axis=(0, 1)).mean()) * 0.5
    fillw = 551 - 476
    fill = np.repeat(left, fillw, axis=1) + rng.normal(0, sigma, (py1 - py0, fillw, 3))
    a[py0:py1, 476:551, :] = np.clip(fill, 0, 255)
    # inset shading on the whole plate interior
    inx0, inx1 = 448, 551
    inplate = (xx >= inx0) & (xx < inx1) & (yy >= py0) & (yy < py1)
    topfade = np.clip(1 - (yy - py0) / 8.0, 0, 1) * 9.0
    sheen = np.exp(-(((xx - (inx0 + inx1) / 2) / 36.0) ** 2 +
                     ((yy - (py0 + py1 * 2) / 3) / 15.0) ** 2)) * 5.0
    a = np.clip(a - (topfade * inplate)[:, :, None] + (sheen * inplate)[:, :, None], 0, 255)
    img = Image.fromarray(a.astype(np.uint8))
    img = soften(img, cx0, cy0, cx1, cy1, rad=0.9)
    img = soften(img, 476, py0, 551, py1, rad=0.9)
    keyed = row_alpha(img, cfg)
    if cfg.get("expand", 0) == 0:
        keyed = defringe(keyed, thresh=235, iters=6)  # gold keeps glow as-is
    final = keyed.crop((12, 0, keyed.width - 2, keyed.height))
    finish(final, name)

# ------------------------------------------------------------------- ring
# The mockup medallion crop is too contaminated by the portrait to sample an
# annulus from directly (it grabbed the blue backdrop). Paint the ring at
# asset scale (152px) using the mockup ring's palette: cream band, dark
# painted contour, top-left light, bottom shadow, hand-painted wobble.
S = 152
cx = cy = S / 2.0
yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
ang = np.arctan2(yy - cy, xx - cx)
rr = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
# hand-painted wobble on the radius (low-frequency angular harmonics)
wob = (1.6 * np.sin(3 * ang + 0.7) + 1.1 * np.sin(5 * ang + 2.1)
       + 0.7 * np.sin(8 * ang + 4.0))
rw = rr + wob * 0.55
R_OUT, R_IN = 73.0, 55.0        # hole r = 55 ≈ 36% of 152
# base cream, directional light toward top-left
lit = np.cos(ang + 3 * np.pi / 4)
base = np.zeros((S, S, 3))
cream_hi = np.array([248, 242, 228])
cream_lo = np.array([186, 172, 155])
t = (lit + 1) / 2.0             # 1 at top-left, 0 at bottom-right
for c in range(3):
    base[..., c] = cream_lo[c] + (cream_hi[c] - cream_lo[c]) * t
# radial profile: bright crown in the middle of the band, darker at lips
mid = (R_IN + R_OUT) / 2.0
crown = np.exp(-((rw - mid) ** 2) / (2 * 5.5 ** 2)) * 24.0
base += crown[..., None]
# painterly angular tone variation
tone = (np.sin(7 * ang + 1.3) + 0.6 * np.sin(13 * ang + 3.7)) * 5.0
base += tone[..., None]
# inner lip shadow + outer painted contour
inner_lip = np.clip(1 - np.abs(rw - (R_IN + 2.2)) / 3.0, 0, 1)
base = base * (1 - 0.28 * inner_lip[..., None])
contour = np.clip(1 - np.abs(rw - (R_OUT - 1.8)) / 3.2, 0, 1)
contour = contour * (0.55 + 0.45 * (1 - t))   # contour darker toward bottom-right
dark = np.array([96, 82, 70])
base = base * (1 - contour[..., None]) + dark[None, None, :] * contour[..., None]
# specular arc top-left, mid-band
spec = np.exp(-((rw - mid) ** 2) / 9.0) * np.exp(-((ang + 3 * np.pi / 4) ** 2) / 0.35) * 26.0
base += spec[..., None]
# gentle grain
base += rng.normal(0, 2.2, base.shape)
base = np.clip(base, 0, 255)
alpha = np.minimum(np.clip((R_OUT + 0.8 - rw) * 255 / 2.2, 0, 255),
                   np.clip((rw - R_IN) * 255 / 2.0, 0, 255)).astype(np.uint8)
ring_rgba = Image.fromarray(base.astype(np.uint8)).convert("RGBA")
ring_rgba.putalpha(Image.fromarray(alpha, "L"))
ring_rgba = ring_rgba.filter(ImageFilter.GaussianBlur(0.6))
finish(ring_rgba, "row-ring.png", scale=1)

print("done ->", OUT)
