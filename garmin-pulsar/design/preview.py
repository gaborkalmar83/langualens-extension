"""Draws mock-ups of the ten designs from the same colours and ring styles as source/Themes.mc.
Usage: python3 design/preview.py   (writes design/previews.png)"""
import math, os, re
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "..", "source", "Themes.mc")).read()
NAMES = re.findall(r'"([^"]+)"', src.split("NAMES = [")[1].split("];")[0])
ROWS = [[int(v, 16) if v.startswith("0x") else int(v) for v in re.findall(r"0x[0-9A-Fa-f]{6}|\b\d\b", r)]
        for r in re.findall(r"\[(0x[^\]]+)\]", src.split("DATA = [")[1].split("];")[0])]
ZONE3 = 0x00FF55
S = 416


def rgb(c): return ((c >> 16) & 255, (c >> 8) & 255, c & 255)


def font(size, bold=True):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.exists(p): return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def ring(d, r, w, frac, color, dim, style):
    c = S / 2
    box = [c - r - w / 2, c - r - w / 2, c + r + w / 2, c + r + w / 2]
    if style == 2:
        n, lit = 48, round(frac * 48)
        for i in range(n):
            a = 2 * math.pi * i / n - math.pi / 2
            x, y, rr = c + r * math.cos(a), c + r * math.sin(a), w / 2
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=rgb(color if i < lit else dim))
    elif style in (1, 4):
        segs, gap = (40, 3) if style == 1 else (12, 6)
        step, on = 360 / segs, round(frac * segs)
        for j in range(segs):
            d.arc(box, -90 + j * step + gap / 2, -90 + (j + 1) * step - gap / 2, fill=rgb(color if j < on else dim), width=int(w))
    elif style == 3:
        for rr in (r + w / 2 - 1, r - w / 2 + 1):
            b = [c - rr, c - rr, c + rr, c + rr]
            d.ellipse(b, outline=rgb(dim), width=3)
            d.arc(b, -90, -90 + frac * 360, fill=rgb(color), width=3)
    else:
        d.ellipse(box, outline=rgb(dim), width=int(w))
        d.arc(box, -90, -90 + frac * 360, fill=rgb(color), width=int(w))


def face(i):
    bg, pri, sec, acc, dim, txt, style = ROWS[i]
    im = Image.new("RGB", (S, S), (16, 16, 20))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, S - 1, S - 1], fill=rgb(bg))
    c, w = S / 2, 14
    r1 = S / 2 - w / 2 - 4
    ring(d, r1, w, 0.62, pri, dim, style)
    ring(d, r1 - w - 6, w, 0.71, ZONE3, dim, style)
    d.text((c, S * 0.21), "HR 152  Z3", font=font(26), fill=rgb(ZONE3), anchor="mm")
    d.text((c, S * 0.40), "24:18", font=font(84), fill=rgb(txt), anchor="mm")
    d.text((c - S * 0.19, S * 0.60), "4.31", font=font(36), fill=rgb(pri), anchor="mm")
    d.text((c - S * 0.19, S * 0.70), "KM", font=font(20), fill=rgb(sec), anchor="mm")
    d.text((c + S * 0.19, S * 0.60), "5:38", font=font(36), fill=rgb(pri), anchor="mm")
    d.text((c + S * 0.19, S * 0.70), "PACE", font=font(20), fill=rgb(sec), anchor="mm")
    d.text((c, S * 0.81), "REC  74 PTS", font=font(20), fill=rgb(txt), anchor="mm")
    return im


cols, pad, label = 5, 24, 44
sheet = Image.new("RGB", (cols * (S + pad) + pad, 2 * (S + pad + label) + pad), (16, 16, 20))
sd = ImageDraw.Draw(sheet)
for i in range(10):
    x = pad + (i % cols) * (S + pad)
    y = pad + (i // cols) * (S + pad + label)
    sheet.paste(face(i), (x, y))
    sd.text((x + S / 2, y + S + 22), "%d  %s" % (i + 1, NAMES[i]), font=font(26), fill=(230, 230, 230), anchor="mm")
out = os.path.join(HERE, "previews.png")
sheet.save(out)
print(out)
