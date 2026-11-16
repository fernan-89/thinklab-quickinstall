"""Builds exploded-view wallpapers from the official hardware maintenance manuals (private use only).

Reads a specs file (library\manuals.json): per machine code {family, model, pdf, page, mode: image|render, clip, dpi}.
Pipeline: figure -> remove numbered call-outs and leader lines -> split into parts -> re-compose (spread out like the
vendor wallpapers) -> colour with the design tokens (dark / light) and an X-ray variant.
The manuals are vendor material: the output stays in the private library and is never committed.
Run with the venv python: python -I manual_art.py --lib <library> --design <design.json> [--only <code>]
"""
import argparse, json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy import ndimage as ndi
import pymupdf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from title_mark import draw_title   # vendor-style wordmark + model line (fonts in library/_tools/fonts)

W, H = 3840, 2160


def hex2rgb(h):
    h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def load_figure(spec, lib):
    doc = pymupdf.open(os.path.join(lib, spec['pdf'])); page = doc[spec['page'] - 1]
    if spec.get('mode') == 'render':
        clip = pymupdf.Rect(*spec['clip']); pix = page.get_pixmap(dpi=spec.get('dpi', 450), clip=clip)
        return Image.frombytes('RGB', (pix.width, pix.height), pix.samples).convert('L')
    best = max(page.get_images(full=True), key=lambda i: i[2] * i[3])
    pix = pymupdf.Pixmap(doc, best[0])
    if pix.alpha or (pix.colorspace and pix.colorspace.n != 3): pix = pymupdf.Pixmap(pymupdf.csRGB, pix)
    return Image.frombytes('RGB', (pix.width, pix.height), pix.samples).convert('L')


def remove_callouts(ink, wf):
    """Erase the black number/letter badges and the horizontal leader lines that run from them to the parts."""
    binary = ink > 0.5
    # badges are solid black squares with white digits: close the digits, then open with a big kernel so only solid blocks survive
    # (leader lines and part outlines are thin and vanish), which also works when a leader touches the badge
    k1 = max(5, int(0.0048 * wf)); k2 = max(9, int(0.0125 * wf))
    solid = ndi.binary_opening(ndi.binary_closing(binary, structure=np.ones((k1, k1))), structure=np.ones((k2, k2)))
    lab, n = ndi.label(solid, structure=np.ones((3, 3)))
    cand = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        h = sl[0].stop - sl[0].start; w = sl[1].stop - sl[1].start
        if 0.008 * wf < h < 0.085 * wf and w > 0.008 * wf and (lab[sl] == i + 1).sum() / float(h * w) > 0.75 and binary[sl].mean() > 0.68:
            cand.append((sl[0].start, sl[0].stop, sl[1].start, sl[1].stop))
    badges = []
    if cand:
        hs = sorted(c[1] - c[0] for c in cand); med = hs[len(hs) // 2]
        cand = sorted([c for c in cand if 0.8 * med < (c[1] - c[0]) < 1.25 * med], key=lambda c: (c[0], c[2]))
        merged = []                                            # two-digit badges come out as two pieces: merge neighbours on the same row
        for c in cand:
            if merged and abs(merged[-1][0] - c[0]) < 0.2 * med and 0 <= c[2] - merged[-1][3] < 0.35 * med:
                m0 = merged[-1]; merged[-1] = (min(m0[0], c[0]), max(m0[1], c[1]), m0[2], c[3])
            else: merged.append(c)
        badges = [(slice(c[0], c[1]), slice(c[2], c[3])) for c in merged]
    out = ink.copy()
    for sl in badges:
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        yc = (y0 + y1) // 2; pad = 3
        out[max(0, y0 - pad):y1 + pad, max(0, x0 - pad):x1 + pad] = 0
        thick = max(3, int((y1 - y0) * 0.07)); gap = max(6, int((y1 - y0) * 0.11))
        best = None; best_row = yc
        for d in (1, -1):
            xs = (x1 + pad + 1) if d == 1 else (x0 - pad - 2)
            # the leader is not always on the badge centre line: pick the row (within +-12 px) with the longest ink run
            row_best, row_len = yc, 0
            for off in range(-12, 13):
                r = yc + off; cnt = 0
                for k in range(0, min(240, (ink.shape[1] - xs) if d == 1 else xs)):
                    x = xs + d * k
                    if ink[r, x] > 0.4: cnt += 1
                if cnt > row_len: row_len, row_best = cnt, r
            if row_len < 30: continue
            r = row_best; run = []; miss = 0; started = False; x = xs
            limit = max(12, int((y1 - y0) * 0.45))
            while 0 <= x < ink.shape[1]:
                col = ink[r - 1:r + 2, x].max() > 0.4
                y0g, y1g = max(0, r - gap), min(ink.shape[0] - 1, r + gap); dx = int(round(gap * 1.73))   # 30 deg iso lines
                xl, xr = max(0, x - dx), min(ink.shape[1] - 1, x + dx)
                clear = (ink[y0g, x] < 0.3 and ink[y1g, x] < 0.3 and                       # nothing crossing vertically ...
                         ink[y0g, xl] < 0.3 and ink[y1g, xr] < 0.3 and ink[y0g, xr] < 0.3 and ink[y1g, xl] < 0.3)   # ... or along the iso axes
                if col and clear: run.append(x); miss = 0; started = True
                else:
                    miss += 1
                    if miss > (14 if started else limit): break          # jump over lines that cross the leader (they are kept)
                x += d
            if run:                                              # finish the leader up to the part edge (vertical test only)
                x = run[-1] + d
                while 0 <= x < ink.shape[1] and ink[r - 1:r + 2, x].max() > 0.4 and ink[max(0, r - thick - 2), x] < 0.3 and ink[min(ink.shape[0] - 1, r + thick + 2), x] < 0.3:
                    run.append(x); x += d
            if len(run) >= 12 and (best is None or len(run) > len(best)): best = run; best_row = r
        if best:
            best = best        # crossing lines were skipped, so the whole run is leader
            for x in best: out[max(0, best_row - thick):best_row + thick + 1, x] = 0
    remove_callouts.last = [(b[0].start, b[0].stop, b[1].start, b[1].stop) for b in badges]
    return out, len(badges)


def remove_vertical_leaders(ink, out, badges, extra=()):
    """Some figures run the leaders up/down from the badges. Trace them the same way as the horizontal ones (jumping over
    crossing lines) and erase; `extra` = badge boxes given by hand (y0, y1, x0, x1) that the detector missed."""
    Hh, Ww = ink.shape
    for (y0, y1, x0, x1) in list(badges) + [tuple(e) for e in extra]:
        hb = y1 - y0; thick = max(3, int(hb * 0.07)); gap = max(6, int(hb * 0.11)); limit = max(12, int(hb * 0.45))
        out[max(0, y0 - 3):y1 + 3, max(0, x0 - 3):x1 + 3] = 0
        for d in (1, -1):
            ys = (y1 + 4) if d == 1 else (y0 - 5)
            col_best, col_len = None, 0
            for x in range(max(1, x0), min(Ww - 1, x1)):
                cnt = 0
                for k in range(0, 240):
                    y = ys + d * k
                    if not (0 <= y < Hh): break
                    if ink[y, x] > 0.4: cnt += 1
                if cnt > col_len: col_len, col_best = cnt, x
            if col_len < 30: continue
            x = col_best; run = []; miss = 0; started = False; y = ys
            while 0 <= y < Hh:
                on = ink[y, x - 1:x + 2].max() > 0.4
                clear = ink[y, max(0, x - gap)] < 0.3 and ink[y, min(Ww - 1, x + gap)] < 0.3
                if on and clear: run.append(y); miss = 0; started = True
                else:
                    miss += 1
                    if miss > (14 if started else limit): break
                y += d
            if len(run) >= 12:
                for y in run: out[y, max(0, x - thick):x + thick + 1] = 0
    return out


def split_parts(ink, wf):
    r = max(4, int(0.0042 * wf))
    st = ndi.generate_binary_structure(2, 2)
    mask = ink > 0.3
    blob = ndi.binary_dilation(mask, structure=st, iterations=r)
    lab, n = ndi.label(blob, structure=np.ones((3, 3)))
    parts = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        region = (lab[sl] == i + 1)
        a = ink[sl] * region
        if (a > 0.5).sum() < 120: continue
        ys, xs = np.nonzero(a > 0.05)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        a = a[y0:y1, x0:x1]
        parts.append({'a': a, 'cx': sl[1].start + x0 + (x1 - x0) / 2.0, 'cy': sl[0].start + y0 + (y1 - y0) / 2.0})
    return parts


def compose(parts, spread=(1.62, 1.10), box=(0.375, 0.05, 0.935, 0.95), boost=1.55):
    mx = np.mean([p['cx'] for p in parts]); my = np.mean([p['cy'] for p in parts])
    xs0, ys0, xs1, ys1 = [], [], [], []
    for p in parts:
        p['sx'] = mx + (p['cx'] - mx) * spread[0]; p['sy'] = my + (p['cy'] - my) * spread[1]
        h, w = p['a'].shape
        xs0.append(p['sx'] - w / 2); xs1.append(p['sx'] + w / 2); ys0.append(p['sy'] - h / 2); ys1.append(p['sy'] + h / 2)
    bx0, bx1, by0, by1 = min(xs0), max(xs1), min(ys0), max(ys1)
    tw, th = (box[2] - box[0]) * W, (box[3] - box[1]) * H
    s = min(tw / (bx1 - bx0), th / (by1 - by0))
    ox = box[0] * W + (tw - (bx1 - bx0) * s) / 2 - bx0 * s; oy = box[1] * H + (th - (by1 - by0) * s) / 2 - by0 * s
    canvas = np.zeros((H, W), np.float32)
    for p in parts:
        h, w = p['a'].shape; nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
        im = Image.fromarray((p['a'] * 255).astype(np.uint8)).resize((nw, nh), Image.LANCZOS)
        a = np.asarray(im, np.float32) / 255.0
        x = int(round(ox + p['sx'] * s - nw / 2)); y = int(round(oy + p['sy'] * s - nh / 2))
        xa, ya = max(0, x), max(0, y); xb, yb = min(W, x + nw), min(H, y + nh)
        if xb > xa and yb > ya: canvas[ya:yb, xa:xb] = np.maximum(canvas[ya:yb, xa:xb], a[ya - y:yb - y, xa - x:xb - x])
    return np.clip(canvas * boost, 0, 1)


def logical_parts(ink, wf, layout, rscale):
    """Hand-defined parts. Entries with 'poly' claim the ink pixels inside the polygon first (parts that touch each other);
    entries with 'rect' take the small ink blobs whose centre lies in the rectangle (first rectangle wins)."""
    H0, W0 = ink.shape; res = [None] * len(layout); rest = ink.copy()
    # polygons work on whole strokes: a connected line goes to the polygon that holds most of it (so an edge that crosses the
    # polygon border is not cut); only strokes really shared by two parts (20-80 % inside) are split at the border
    lab0, n0 = ndi.label(ink > 0.25, structure=np.ones((3, 3)))
    sizes = ndi.sum(np.ones_like(lab0), lab0, range(1, n0 + 1)) if n0 else []
    taken = np.zeros(n0 + 1, bool)
    for k, ent in enumerate(layout):
        if 'poly' not in ent: continue
        m = Image.new('L', (W0, H0), 0); ImageDraw.Draw(m).polygon([(x * rscale, y * rscale) for x, y in ent['poly']], fill=255)
        reg = np.asarray(m) > 0
        inside = ndi.sum(reg, lab0, range(1, n0 + 1)) if n0 else []
        frac = np.zeros(n0 + 1); frac[1:] = np.asarray(inside) / np.maximum(1, np.asarray(sizes))
        whole = (frac > 0.8) & ~taken; split = (frac > 0.2) & (frac <= 0.8) & ~taken
        whole[0] = split[0] = False
        sel = ndi.binary_dilation(whole[lab0], iterations=2) | (split[lab0] & reg) | (reg & (lab0 == 0))
        taken |= whole
        mine = ink * sel * (rest > 0)
        ys, xs = np.nonzero(mine > 0.03)
        if len(ys) > 25: res[k] = mine[ys.min():ys.max() + 1, xs.min():xs.max() + 1].astype(np.float32); rest[sel] = 0
    st = ndi.generate_binary_structure(2, 2)
    lab, n = ndi.label(ndi.binary_dilation(rest > 0.3, structure=st, iterations=3), structure=np.ones((3, 3)))
    items = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        a = rest[sl] * (lab[sl] == i + 1)
        if (a > 0.5).sum() < 25: continue
        cy, cx = ndi.center_of_mass(a > 0.2); items.append((sl[0].start + cy, sl[1].start + cx, sl, a))
    for k, ent in enumerate(layout):
        if 'poly' in ent: continue
        x0, y0, x1, y1 = [v * rscale for v in ent['rect']]
        mine = [it for it in items if x0 <= it[1] <= x1 and y0 <= it[0] <= y1]
        items = [it for it in items if it not in mine]
        if not mine: continue
        ya, yb = min(m[2][0].start for m in mine), max(m[2][0].stop for m in mine); xa, xb = min(m[2][1].start for m in mine), max(m[2][1].stop for m in mine)
        a = np.zeros((yb - ya, xb - xa), np.float32)
        for m in mine:
            sl0 = (slice(m[2][0].start - ya, m[2][0].stop - ya), slice(m[2][1].start - xa, m[2][1].stop - xa)); a[sl0] = np.maximum(a[sl0], m[3])
        res[k] = a
    for k, a in enumerate(res):                                  # drop specks left by the erased leader lines
        if a is None: continue
        lb, nn = ndi.label(a > 0.25, structure=np.ones((3, 3)))
        if nn > 1:
            sizes = ndi.sum(a > 0.25, lb, range(1, nn + 1)); keep = np.isin(lb, [i + 1 for i, v in enumerate(sizes) if v >= 90])
            a = a * ndi.binary_dilation(keep, iterations=2)
        # drop stray fragments that sit apart from the part (a neighbour's clip caught by the rectangle): keep the clusters
        # (strokes grouped with a 2.5 % gap) that are close to the biggest one
        g = max(6, int(0.025 * max(a.shape)))
        cl, nc = ndi.label(ndi.binary_dilation(a > 0.25, iterations=g), structure=np.ones((3, 3)))
        if nc > 1:
            csz = ndi.sum(a > 0.25, cl, range(1, nc + 1)); big = int(np.argmax(csz)) + 1
            bs = ndi.find_objects(cl)[big - 1]; by0, by1, bx0, bx1 = bs[0].start, bs[0].stop, bs[1].start, bs[1].stop
            mh, mw = (by1 - by0) * 0.35, (bx1 - bx0) * 0.35
            keepc = [big]
            for j, sj in enumerate(ndi.find_objects(cl)):
                if j + 1 == big: continue
                cy0, cy1, cx0, cx1 = sj[0].start, sj[0].stop, sj[1].start, sj[1].stop
                near = cx1 > bx0 - mw and cx0 < bx1 + mw and cy1 > by0 - mh and cy0 < by1 + mh
                if near or csz[j] > 0.25 * csz[big - 1]: keepc.append(j + 1)
            a = a * np.isin(cl, keepc)
        ys, xs = np.nonzero(a > 0.03)
        res[k] = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1] if len(ys) else None
    return res


def render_rgb(spec, lib):
    doc = pymupdf.open(os.path.join(lib, spec['pdf'])); page = doc[spec['page'] - 1]
    pix = page.get_pixmap(dpi=spec.get('dpi', 450), clip=pymupdf.Rect(*spec['clip']))
    return np.asarray(Image.frombytes('RGB', (pix.width, pix.height), pix.samples), np.float32)


def base_ink(spec, lib):
    """Ink of a vendor figure that has COLOURED call-outs (red circles, numbers and leader lines): drop everything red."""
    rgb = render_rgb(spec, lib); r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    red = ((r - g) > 60) & ((r - b) > 60) & (r > 120)
    red = ndi.binary_dilation(red, iterations=3)
    ink = (255.0 - rgb.min(axis=2)) / 255.0
    ink[red] = 0
    return ink


def blob_parts(ink, rects, rscale):
    """Small ink blobs whose centre lies in each rectangle -> (alpha crop, centre x, centre y) in source pixels; first rectangle wins."""
    st = ndi.generate_binary_structure(2, 2)
    lab, n = ndi.label(ndi.binary_dilation(ink > 0.3, structure=st, iterations=3), structure=np.ones((3, 3)))
    items = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        a = ink[sl] * (lab[sl] == i + 1)
        if (a > 0.5).sum() < 25: continue
        cy, cx = ndi.center_of_mass(a > 0.2); items.append((sl[0].start + cy, sl[1].start + cx, sl, a))
    out = []
    for r in rects:
        x0, y0, x1, y1 = [v * rscale for v in r]
        mine = [it for it in items if x0 <= it[1] <= x1 and y0 <= it[0] <= y1]; items = [it for it in items if it not in mine]
        if not mine: out.append(None); continue
        ya, yb = min(m[2][0].start for m in mine), max(m[2][0].stop for m in mine); xa, xb = min(m[2][1].start for m in mine), max(m[2][1].stop for m in mine)
        a = np.zeros((yb - ya, xb - xa), np.float32)
        for m in mine:
            sl0 = (slice(m[2][0].start - ya, m[2][0].stop - ya), slice(m[2][1].start - xa, m[2][1].stop - xa)); a[sl0] = np.maximum(a[sl0], m[3])
        out.append((a, (xa + xb) / 2.0, (ya + yb) / 2.0))
    return out


def art_ink(spec, lib):
    """Line art from a finished wallpaper (white lines on black, e.g. the Padgriffin series) or from a manual figure.
    Returns (ink 0..1, red mask) cropped to the parts area; the title/signature area is left out by spec['crop'] (fractions)."""
    if spec.get('src'):
        im = Image.open(os.path.join(lib, spec['src'])).convert('RGBA'); a = np.asarray(im, np.float32)
        rgb = a[:, :, :3] * (a[:, :, 3:4] / 255.0)              # transparent pixels count as background
        x0, y0, x1, y1 = [int(v * d) for v, d in zip(spec.get('crop', [0, 0, 1, 1]), [im.width, im.height, im.width, im.height])]
        rgb = rgb[y0:y1, x0:x1]
        r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
        red = ((r - g) > 70) & ((r - b) > 70) & (r > 130)
        ink = np.clip((rgb.max(axis=2) - 20.0) / 200.0, 0, 1)
        ink[red] = 0
        return ink, red
    im = load_figure(spec, lib); ink = (255.0 - np.asarray(im, np.float32)) / 255.0
    clean, _ = remove_callouts(ink, im.width)
    if spec.get('vertical_leaders'): clean = remove_vertical_leaders(ink, clean, remove_callouts.last, spec.get('extra_badges', []))
    return clean, np.zeros(clean.shape, bool)


def fit_variants(ink, red, variants, box=(0.4925, 0.08, 0.89, 0.925), boost=1.0):
    """Place the art into the vendor parts area (x 985-1780, y 90-1040 of a 2000x1125 wallpaper). Each variant moves the parts
    toward (factor < 1) or away from (factor > 1) their common centre."""
    parts = split_parts(ink, ink.shape[1])
    lab_red, nr = ndi.label(red)
    reds = [(sl, ndi.center_of_mass(red[sl])) for sl in ndi.find_objects(lab_red)] if nr else []
    mx = np.mean([p['cx'] for p in parts]); my = np.mean([p['cy'] for p in parts])
    h0, w0 = ink.shape; tw, th = (box[2] - box[0]) * W, (box[3] - box[1]) * H
    s = min(tw / w0, th / h0)
    out = []
    for v in variants:
        fx, fy = v.get('fx', 1.0), v.get('fy', 1.0)

        def pos(cx, cy): return mx + (cx - mx) * fx, my + (cy - my) * fy
        xs = [pos(p['cx'], p['cy'])[0] for p in parts]; ys = [pos(p['cx'], p['cy'])[1] for p in parts]
        bx0 = min(x - p['a'].shape[1] / 2 for x, p in zip(xs, parts)); bx1 = max(x + p['a'].shape[1] / 2 for x, p in zip(xs, parts))
        by0 = min(y - p['a'].shape[0] / 2 for y, p in zip(ys, parts)); by1 = max(y + p['a'].shape[0] / 2 for y, p in zip(ys, parts))
        sv = min(s, tw / (bx1 - bx0), th / (by1 - by0)) * v.get('fw', 1.0)
        ox = box[0] * W + (tw - (bx1 - bx0) * sv) / 2 - bx0 * sv; oy = box[1] * H + (th - (by1 - by0) * sv) / 2 - by0 * sv
        canvas = np.zeros((H, W), np.float32); redc = np.zeros((H, W), bool)

        def put(arr, cx, cy, target, is_bool=False):
            hh, ww = arr.shape; nw, nh = max(1, int(round(ww * sv))), max(1, int(round(hh * sv)))
            q = np.asarray(Image.fromarray((arr * 255).astype(np.uint8)).resize((nw, nh), Image.LANCZOS), np.float32) / 255.0
            x = int(round(ox + cx * sv - nw / 2)); y = int(round(oy + cy * sv - nh / 2))
            xa, ya = max(0, x), max(0, y); xb, yb = min(W, x + nw), min(H, y + nh)
            if xb <= xa or yb <= ya: return
            if is_bool: target[ya:yb, xa:xb] |= q[ya - y:yb - y, xa - x:xb - x] > 0.4
            else: target[ya:yb, xa:xb] = np.maximum(target[ya:yb, xa:xb], q[ya - y:yb - y, xa - x:xb - x])
        for p, x, y in zip(parts, xs, ys): put(p['a'], x, y, canvas)
        for sl, (ry, rx) in reds:                                 # each red dot (TrackPoint, logo) moves with the nearest part
            gx, gy = sl[1].start + rx, sl[0].start + ry
            k = int(np.argmin([(p['cx'] - gx) ** 2 + (p['cy'] - gy) ** 2 for p in parts])); p = parts[k]
            nx, ny = pos(p['cx'], p['cy'])
            put(red[sl].astype(np.float32), nx + (sl[1].start + sl[1].stop) / 2 - p['cx'], ny + (sl[0].start + sl[0].stop) / 2 - p['cy'], redc, True)
        out.append((v.get('suffix', ''), np.clip(canvas * boost, 0, 1), redc))
    return out


def contact_sheet(parts, layout, path):
    cell = 360; cols = 6; rows = (len(parts) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * cell, rows * (cell + 40)), 'white'); d = ImageDraw.Draw(sheet); f = font(28, True)
    for k, (a, e) in enumerate(zip(parts, layout)):
        x, y = (k % cols) * cell, (k // cols) * (cell + 40)
        d.text((x + 8, y + 4), f"{k} {e.get('name','')}", font=f, fill=(200, 0, 0))
        if a is None: d.text((x + 8, y + 60), 'EMPTY', font=f, fill=(200, 0, 0)); continue
        im = Image.fromarray(((1 - a) * 255).astype(np.uint8)); im.thumbnail((cell - 16, cell - 16)); sheet.paste(im.convert('RGB'), (x + 8, y + 40))
    sheet.save(path)


def compose_layout(parts, layout, boost=1.35):
    """Place each part at its target (coordinates of a 2000x1125 reference wallpaper) with a target width."""
    k = W / 2000.0; canvas = np.zeros((H, W), np.float32)
    for a, ent in zip(parts, layout):
        if a is None: continue
        h, w = a.shape; s = ent['w'] * k / w; nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
        im = Image.fromarray((a * 255).astype(np.uint8)).resize((nw, nh), Image.LANCZOS)
        if ent.get('rot'): im = im.rotate(ent['rot'], expand=True, resample=Image.BICUBIC); nw, nh = im.size
        arr = np.asarray(im, np.float32) / 255.0
        x = int(round(ent['at'][0] * k - nw / 2)); y = int(round(ent['at'][1] * k - nh / 2))
        xa, ya = max(0, x), max(0, y); xb, yb = min(W, x + nw), min(H, y + nh)
        if xb > xa and yb > ya: canvas[ya:yb, xa:xb] = np.maximum(canvas[ya:yb, xa:xb], arr[ya - y:yb - y, xa - x:xb - x])
    return np.clip(canvas * boost, 0, 1)


FONT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'library', '_tools', 'fonts')


def font(size, bold=True, face=None):
    """face: 'title' (condensed semi-bold like the vendor wallpapers), 'model' (light), 'mono'. Falls back to Bahnschrift."""
    pick = {'title': 'BarlowCondensed-SemiBold.ttf', 'model': 'BarlowCondensed-Light.ttf', 'mono': 'IBMPlexMono-SemiBold.ttf'}.get(face)
    if pick and os.path.exists(os.path.join(FONT_DIR, pick)): return ImageFont.truetype(os.path.join(FONT_DIR, pick), size)
    try:
        f = ImageFont.truetype(r'C:\Windows\Fontsahnschrift.ttf', size)
        try: f.set_variation_by_axes([600 if bold else 300, 75 if bold else 100])
        except Exception: pass
        return f
    except Exception:
        return ImageFont.load_default()


def halftone(img, rgb, strength=26):
    d = ImageDraw.Draw(img, 'RGBA')
    for yy in range(12, H, 28):
        for xx in range(12, W, 28):
            f = max(0.0, (xx / W) * 0.8 + (1 - yy / H) * 0.5 - 0.35); r = 1.0 + 2.2 * min(1.0, f)
            d.ellipse([xx - r, yy - r, xx + r, yy + r], fill=rgb + (strength,))


def finish(img, pal, family, model):
    d = ImageDraw.Draw(img)
    fam_f, mod_f = font(74, True), font(50, False)
    d.text((150, H - 190), family, font=fam_f, fill=hex2rgb(pal['onSurface']))
    wfam = d.textlength(family, font=fam_f)
    d.text((150 + wfam + 14, H - 178), model.upper(), font=mod_f, fill=hex2rgb(pal['onSurfaceVariant']))
    d.ellipse([118, H - 142, 136, H - 124], fill=hex2rgb(pal['nub']))
    d.rectangle([W - 100, H - 580, W, H - 220], fill=hex2rgb(pal['seed-brand']))
    tab = Image.new('RGBA', (360, 100), (0, 0, 0, 0)); td = ImageDraw.Draw(tab)
    tf = font(54, True); tw = td.textlength('ThinkLab', font=tf); td.text(((360 - tw) / 2, 22), 'ThinkLab', font=tf, fill=(255, 255, 255, 255))
    img.paste(tab.rotate(90, expand=True), (W - 100, H - 580), tab.rotate(90, expand=True))
    return img


def render_variant(alpha, pal, family, model, style):
    bg = np.array(hex2rgb(pal['background']), np.float32); ln = np.array(hex2rgb(pal['onSurface']), np.float32)
    if style == 'xray':
        dark = pal['_scheme'] == 'dark'
        top = np.array(hex2rgb('#04101C' if dark else '#EAF4FB'), np.float32); bot = np.array(hex2rgb('#0B2036' if dark else '#D5E8F6'), np.float32)
        t = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
        base = top[None, None, :] * (1 - t) + bot[None, None, :] * t; base = np.repeat(base, W, axis=1)
        core = np.array(hex2rgb('#CFF6FF' if dark else '#0A3F8F'), np.float32); glowc = np.array(hex2rgb('#2FD2FF' if dark else '#2B8CFF'), np.float32)
        g1 = ndi.gaussian_filter(alpha, 5); g2 = ndi.gaussian_filter(alpha, 22)
        glow = np.clip(g1 * 1.5 + g2 * 2.4, 0, 1)[:, :, None]
        out = base * (1 - glow * (0.8 if dark else 0.45)) + glowc[None, None, :] * glow * (0.8 if dark else 0.45)
        out = out * (1 - alpha[:, :, None] * 0.95) + core[None, None, :] * alpha[:, :, None] * 0.95
        img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
        pal = dict(pal); pal['onSurface'] = '#E6F7FF' if dark else '#0A2A5E'; pal['onSurfaceVariant'] = '#7FB8D6' if dark else '#3A5C86'
        return finish(img, pal, family, model)
    img = Image.new('RGB', (W, H), tuple(int(v) for v in bg)); halftone(img, hex2rgb(pal['onSurface']))
    arr = np.asarray(img, np.float32)
    out = arr * (1 - alpha[:, :, None] * 0.93) + ln[None, None, :] * alpha[:, :, None] * 0.93
    return finish(Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)), pal, family, model)


def render_lenovo(alpha, family, model, tab_text='', calib=None, mcalib='A000 AAAA'):
    """Replica of the vendor's own wallpaper look: matte grey, thin white lines, family + model bottom left, red tab at the right edge."""
    bg = np.array(hex2rgb('#2E2E2E'), np.float32); ln = np.array(hex2rgb('#F2F2F2'), np.float32)
    out = bg[None, None, :] * (1 - alpha[:, :, None]) + ln[None, None, :] * alpha[:, :, None]
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(img)
    draw_title(img, 160, 1936, family, model, os.path.join(FONT_DIR, 'LeagueGothic.ttf'), os.path.join(FONT_DIR, 'Montserrat-300.ttf'), cap=61, calib=calib, mcalib=mcalib)
    tx0, ty0, tx1, ty1 = W - 96, 1738, W, 2016
    d.rectangle([tx0, ty0, tx1, ty1], fill=hex2rgb('#E2231A'))
    tab = Image.new('RGBA', (ty1 - ty0, tx1 - tx0), (0, 0, 0, 0)); td = ImageDraw.Draw(tab)
    tf = font(78, True, 'title'); td.text(((ty1 - ty0) / 2, (tx1 - tx0) / 2 + 1), tab_text, font=tf, fill=(255, 255, 255, 255), anchor='mm')
    rot = tab.rotate(90, expand=True); img.paste(rot, (tx0, ty0), rot)
    return img


def paste_tab(img, sp, lib):
    """Brand tab at the right edge: copied pixel for pixel from a reference wallpaper when the private spec gives one
    (tab_image = {src, box}); otherwise a plain red tab with the spec's tab text."""
    ti = sp.get('tab_image')
    if ti and os.path.exists(os.path.join(lib, ti['src'])):
        ref = Image.open(os.path.join(lib, ti['src'])).convert('RGB'); k = img.width / ref.width
        x0, y0, x1, y1 = ti['box']; blk = ref.crop((x0, y0, x1, y1))
        if abs(k - 1) > 1e-6: blk = blk.resize((round((x1 - x0) * k), round((y1 - y0) * k)), Image.LANCZOS)
        img.paste(blk, (img.width - blk.width, round(y0 * k))); return img
    d = ImageDraw.Draw(img); tx0, ty0, tx1, ty1 = W - 96, 1738, W, 2016
    d.rectangle([tx0, ty0, tx1, ty1], fill=hex2rgb('#E2231A'))
    tab = Image.new('RGBA', (ty1 - ty0, tx1 - tx0), (0, 0, 0, 0)); td = ImageDraw.Draw(tab)
    td.text(((ty1 - ty0) / 2, (tx1 - tx0) / 2 + 1), sp.get('tab', ''), font=font(78, True, 'title'), fill=(255, 255, 255, 255), anchor='mm')
    rot = tab.rotate(90, expand=True); img.paste(rot, (tx0, ty0), rot); return img


def palette(design, scheme):
    pal = dict(design['base'][scheme]); pal.update(design['interfaces'].get('desktop', {}).get(scheme, {}))
    for k, v in design['seed'].items(): pal['seed-' + k] = v
    pal['_scheme'] = scheme
    return pal


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--lib', required=True); ap.add_argument('--design', required=True)
    ap.add_argument('--specs'); ap.add_argument('--only'); ap.add_argument('--debug', action='store_true')
    a = ap.parse_args()
    specs = json.load(open(a.specs or os.path.join(a.lib, 'manuals.json'), encoding='utf-8')); design = json.load(open(a.design, encoding='utf-8'))
    for code, sp in specs.items():
        if a.only and code != a.only: continue
        im = load_figure(sp, a.lib); arr = np.asarray(im, np.float32); ink = (255.0 - arr) / 255.0
        clean, nb = remove_callouts(ink, im.width)
        parts = split_parts(clean, im.width)
        print(f'{code}: figure {im.width}x{im.height}, callouts removed {nb}, parts {len(parts)}')
        if a.debug: Image.fromarray(((1 - clean) * 255).astype(np.uint8)).save(os.path.join(a.lib, f'_download/manuals/_pg/clean_{code}.png'))
        if a.debug:                                           # numbered overlay: which index is which part (for hand-made layouts)
            dbg = Image.fromarray(((1 - clean) * 255).astype(np.uint8)).convert('RGB'); dd = ImageDraw.Draw(dbg); fd = font(46, True)
            for k, pt in enumerate(parts): dd.text((pt['cx'], pt['cy']), str(k), font=fd, fill=(220, 0, 0), anchor='mm')
            dbg.save(os.path.join(a.lib, f'_download/manuals/_pg/parts_{code}.png'))
        alpha = compose(parts)
        outdir = os.path.join(a.lib, 'wallpapers', code); os.makedirs(outdir, exist_ok=True)
        label = sp.get('label', code)
        for scheme in ('dark', 'light'):
            pal = palette(design, scheme)
            for style, tag in (('line', 'Manual'), ('xray', 'XRay')):
                render_variant(alpha, pal, sp['family'], sp['model'], style).save(os.path.join(outdir, f'ThinkLab-{label}-{tag}-{scheme.capitalize()}.png'))
        # vendor-look replica (dark grey, red tab): parts placed like the vendor's own wallpaper
        if sp.get('art'):                                        # finished line art or manual figure -> vendor-style wallpapers
            ink_, red_ = art_ink(sp['art'], a.lib)
            outdir = os.path.join(a.lib, 'wallpapers', code); os.makedirs(outdir, exist_ok=True)
            lbl = sp.get('label', code)
            for suffix, al, rc in fit_variants(ink_, red_, [{}] + sp.get('variants', []), boost=sp['art'].get('boost', 1.0)):
                bg = np.array(hex2rgb('#2E2E2E'), np.float32); ln = np.array([238, 238, 238], np.float32)
                arr = bg[None, None, :] * (1 - al[:, :, None] * 0.96) + ln[None, None, :] * al[:, :, None] * 0.96
                arr[rc] = hex2rgb('#E2231A')
                img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
                draw_title(img, 160, 1936, sp['family'], sp['model'], os.path.join(FONT_DIR, 'LeagueGothic.ttf'), os.path.join(FONT_DIR, 'Montserrat-300.ttf'), cap=61, calib=sp.get('calib'), mcalib=sp.get('mcalib', 'A000 AAAA'))
                paste_tab(img, sp, a.lib)
                tag = 'Original' + suffix
                img.save(os.path.join(outdir, f'{sp.get("prefix", "Vendor")}-{lbl}-{tag}.png')); img.resize((1920, 1080), Image.LANCZOS).save(os.path.join(outdir, f'{sp.get("prefix", "Vendor")}-{lbl}-{tag}-FHD.png'))
                print(f'  art {tag}')
            continue
        if sp.get('edits'):                                      # edit the vendor wallpaper: erase what this machine lacks, drop its own parts in place
            lp_all = logical_parts(clean, im.width, sp['layout'], sp.get('rect_scale', 1.0))
            byname = {e['name']: p_ for e, p_ in zip(sp['layout'], lp_all) if p_ is not None}
            for ex in sp.get('extras', []):
                imx = load_figure(ex, a.lib); inkx = (255.0 - np.asarray(imx, np.float32)) / 255.0; cleanx, _ = remove_callouts(inkx, imx.width)
                for e, p_ in zip(ex['parts'], logical_parts(cleanx, imx.width, ex['parts'], ex.get('rect_scale', 1.0))):
                    if p_ is not None: byname[e['name']] = p_
            outdir = os.path.join(a.lib, 'wallpapers', code); os.makedirs(outdir, exist_ok=True)
            for ed in sp['edits']:
                base = Image.open(os.path.join(a.lib, ed['base'])).convert('RGB'); orig = np.asarray(base, np.float32).copy(); arr = orig.copy()
                kk = base.width / 2000.0; bgc = np.median(arr[20:80, 20:80].reshape(-1, 3), axis=0)
                for r in ed['erase']: arr[int(r[1] * kk):int(r[3] * kk), int(r[0] * kk):int(r[2] * kk)] = bgc
                if ed.get('protect'):                           # restore kept vendor parts by whole strokes (not cut at the polygon edge)
                    lum = orig.mean(axis=2); bink = (lum - float(bgc.mean())) > 22
                    blab, bn = ndi.label(bink, structure=np.ones((3, 3))); bsz = ndi.sum(bink, blab, range(1, bn + 1))
                    for poly in ed['protect']:
                        m = Image.new('L', base.size, 0); ImageDraw.Draw(m).polygon([(x * kk, y * kk) for x, y in poly], fill=255); mm = np.asarray(m) > 0
                        fr = np.zeros(bn + 1); fr[1:] = np.asarray(ndi.sum(mm, blab, range(1, bn + 1))) / np.maximum(1, bsz)
                        sel = ndi.binary_dilation((fr > 0.5)[blab], iterations=2) | mm
                        arr[sel] = orig[sel]
                use, full = [], []
                for nm, sl_ in ed['slots'].items():
                    if nm in byname: use.append(byname[nm]); full.append({'name': nm, 'at': sl_[:2], 'w': sl_[2]})
                    else: print('  missing part', nm)
                base_arr = arr
                # variants: the same parts pulled together (condensed) or spread out around the composition centre
                for var in [{}] + ed.get('variants', []):
                    cxv, cyv = var.get('centre', ed.get('centre', [1430, 600])); fx, fy, fw = var.get('fx', 1.0), var.get('fy', 1.0), var.get('fw', 1.0)
                    fv = [{'name': f_['name'], 'at': [cxv + (f_['at'][0] - cxv) * fx, cyv + (f_['at'][1] - cyv) * fy], 'w': f_['w'] * fw} for f_ in full]
                    al = compose_layout(use, fv, boost=ed.get('boost', 1.3))
                    if al.shape[:2] != base_arr.shape[:2]: al = np.asarray(Image.fromarray((al * 255).astype(np.uint8)).resize((base_arr.shape[1], base_arr.shape[0]), Image.LANCZOS), np.float32) / 255.0
                    ln = np.array(ed.get('line', [238, 238, 238]), np.float32)
                    out = base_arr * (1 - al[:, :, None] * 0.96) + ln[None, None, :] * al[:, :, None] * 0.96
                    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
                    draw_title(img, 160 * kk / 1.92, 1936 * kk / 1.92, sp['family'], sp['model'], os.path.join(FONT_DIR, 'LeagueGothic.ttf'), os.path.join(FONT_DIR, 'Montserrat-300.ttf'), cap=61 * kk / 1.92, calib=sp.get('calib'), mcalib=sp.get('mcalib', 'A000 AAAA'))
                    tag = ed.get('tag', 'Original') + var.get('suffix', '')
                    img.save(os.path.join(outdir, f'{sp.get("prefix", "Vendor")}-{label}-{tag}.png')); img.resize((1920, 1080), Image.LANCZOS).save(os.path.join(outdir, f'{sp.get("prefix", "Vendor")}-{label}-{tag}-FHD.png'))
                    print(f'  edit {tag}: parts', len(use))
                if a.debug: contact_sheet(use, full, os.path.join(a.lib, f'_download/manuals/_pg/sheet_{code}_{ed.get("tag","Original")}.png'))
            continue
        elif sp.get('layout'):
            lp = logical_parts(clean, im.width, sp['layout'], sp.get('rect_scale', 1.0)); full = list(sp['layout'])
            for ex in sp.get('extras', []):                         # accessories borrowed from sibling manuals
                imx = load_figure(ex, a.lib); inkx = (255.0 - np.asarray(imx, np.float32)) / 255.0
                cleanx, _ = remove_callouts(inkx, imx.width)
                lp += logical_parts(cleanx, imx.width, ex['parts'], ex.get('rect_scale', 1.0)); full += ex['parts']
            la = compose_layout(lp, full)
            print('  layout parts', sum(1 for x in lp if x is not None), '/', len(lp))
            if a.debug: contact_sheet(lp, full, os.path.join(a.lib, f'_download/manuals/_pg/sheet_{code}.png'))
        else:
            la = compose(parts, spread=(1.22, 1.04), box=(0.4925, 0.075, 0.892, 0.925), boost=1.35)
        lim = render_lenovo(la, sp['family'], sp['model'], sp.get('tab', ''), sp.get('calib'), sp.get('mcalib', 'A000 AAAA'))
        lim.save(os.path.join(outdir, f'{sp.get("prefix", "Vendor")}-{label}-Original.png'))                                   # 3840x2160
        lim.resize((1920, 1080), Image.LANCZOS).save(os.path.join(outdir, f'{sp.get("prefix", "Vendor")}-{label}-Original-FHD.png'))   # 1920x1080
        print('  ->', outdir)


if __name__ == '__main__':
    main()
