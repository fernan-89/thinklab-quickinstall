"""Vendor-style title block for the exploded-view wallpapers.

Measured on a vendor 4K wallpaper:
  wordmark  cap height 61 px, the 12-letter family word 252 px wide (= 4.13 x cap), letters almost touching, first 'i'
            dotted in red, a tiny (R) on the baseline right after it
  model     light geometric capitals, cap height 21.5 px, 9 characters 164 px wide, starts 12 px after the (R),
            cap top 14 px below the wordmark cap top
  colours   both white on the matte grey; the dot is red #E2231A, as wide as the i stem
The wordmark font is squeezed horizontally so that the calibration word (`calib`, from the private spec) matches the measured
width; the same squeeze is used for every family name, so all titles share one proportion.
"""
from PIL import Image, ImageDraw, ImageFont

REF = {'cap': 61, 'ratio': 252 / 61.0, 'mcap': 21.5, 'mratio': 164 / 21.5, 'gap': 12, 'mtop': 14 / 61.0}


def cap_size(path, cap):
    f = ImageFont.truetype(path, 200); b = f.getbbox('H'); return max(4, round(200 * cap / (b[3] - b[1])))


def _squeeze(font, calib):
    w = font.getlength(calib); b = font.getbbox('H'); cap = b[3] - b[1]
    return min(1.0, REF['ratio'] * cap / w)


def draw_title(img, x, top, family, model, wm_path, model_path, cap=61, red=(226, 35, 26), white=(255, 255, 255), calib=None, mcalib='A000 AAAA'):
    k = cap / REF['cap']
    fw = ImageFont.truetype(wm_path, cap_size(wm_path, cap)); hb = fw.getbbox('H'); sx = _squeeze(fw, calib or family)
    i = family.find('i'); text = family if i < 0 else family[:i] + 'ı' + family[i + 1:]
    W = int(fw.getlength(text)) + 8; Hh = int(cap * 1.8)
    layer = Image.new('L', (W, Hh), 0); ld = ImageDraw.Draw(layer); oy = int(cap * 0.4) - hb[1]
    ld.text((0, oy), text, font=fw, fill=255)
    lw = max(1, round(W * sx)); layer = layer.resize((lw, Hh), Image.LANCZOS)
    img.paste(Image.new('RGB', layer.size, white), (int(x), int(top - cap * 0.4)), layer)
    d = ImageDraw.Draw(img)
    if i >= 0:                                                   # TrackPoint-red dot over the first i, as wide as the stem
        xi = fw.getlength(text[:i]); ib = fw.getbbox('ı'); stem = (ib[2] - ib[0]) * sx
        cx = x + (xi + (ib[0] + ib[2]) / 2) * sx; dd = stem * 0.86
        d.ellipse([cx - dd / 2, top + dd * 0.05, cx + dd / 2, top + dd * 1.05], fill=red)
    end = x + fw.getlength(text) * sx
    fr = ImageFont.truetype(wm_path, max(6, round(cap * 0.13)))
    rb = fr.getbbox('®'); d.text((end + 1 * k - rb[0], top + cap - rb[3]), '®', font=fr, fill=white)
    end += (rb[2] - rb[0]) + 1 * k
    mcap = REF['mcap'] * k
    fm = ImageFont.truetype(model_path, cap_size(model_path, mcap)); mb = fm.getbbox('H')
    natural = fm.getlength(mcalib); track = max(0.0, (REF['mratio'] * mcap - natural) / 8.0)   # 8 gaps in the 9-character calibration string
    mx = end + REF['gap'] * k; my = top + REF['mtop'] * cap - mb[1]
    for ch in model.upper():
        d.text((mx, my), ch, font=fm, fill=white); mx += fm.getlength(ch) + track
    return img
