"""Draws every texture Herogram uses and writes them as BLP2 into Media/.

The files are DXT5 (BLP2 encoding 2, alpha 8, alpha encoding 7), like
Blizzard's own and every other addon's: uncompressed BLP2 (encoding 3)
shows up as scrambled stripes in the game.

Run from the repository root:  python3 tools/media.py
Pure Python (no Pillow): shapes are drawn with 4x4 supersampling.
"""
import math, os, random, struct, sys

sys.path.insert(0, os.path.dirname(__file__))
from tga2blp import png  # noqa: E402
import dxt  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "Media")
PREVIEW = os.environ.get("HEROGRAM_PREVIEW")  # a folder for PNG previews


def clamp(v, a=0.0, b=1.0):
    return a if v < a else b if v > b else v


def smooth(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def image(w, h, fn, ss=4):
    """fn(x, y) -> (r, g, b, a) in 0..1 at a sub-pixel position in pixel units."""
    rows = []
    for y in range(h):
        row = []
        for x in range(w):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(ss):
                for sx in range(ss):
                    r, g, b, a = fn(x + (sx + 0.5) / ss, y + (sy + 0.5) / ss)
                    acc[0] += r * a
                    acc[1] += g * a
                    acc[2] += b * a
                    acc[3] += a
            n = ss * ss
            a = acc[3] / n
            if a > 0:
                c = [acc[i] / acc[3] for i in range(3)]
            else:
                c = [0, 0, 0]
            row.append(tuple(int(round(clamp(v) * 255)) for v in (c[0], c[1], c[2], a)))
        rows.append(row)
    return rows


def save(name, w, h, rows):
    path = os.path.join(OUT, name + ".blp")
    levels = dxt.write(path, w, h, rows)
    d = open(path, "rb").read()
    assert d[:4] == b"BLP2" and d[8:12] == bytes((2, 8, 7, 1)), "not DXT5"
    off, size = struct.unpack("<I", d[20:24])[0], struct.unpack("<I", d[84:88])[0]
    back = dxt.decode(w, h, d[off:off + size])
    quality = dxt.psnr(rows, back, w, h)
    if PREVIEW:
        shown = []
        for (lw, lh, _, data) in levels[:4]:
            dec = dxt.decode(lw, lh, data)
            shown.append((lw, lh, b"".join(bytes((p[2], p[1], p[0], p[3])) for r in dec for p in r)))
        png(os.path.join(PREVIEW, name + ".png"), shown, zoom=max(1, 256 // w))
    print(f"{name}.blp {w}x{h} DXT5, {len(levels)} mips, PSNR {quality:.1f} dB")


WHITE = (1, 1, 1)


def glow():
    # soft round light, white; tinted and blended ADD in the game
    def f(x, y):
        dx, dy = (x - 64) / 64, (y - 64) / 64
        r = math.sqrt(dx * dx + dy * dy)
        a = math.exp(-(r * r) / (2 * 0.36 ** 2)) * (1 - smooth(0.82, 1.0, r))
        return (*WHITE, a)
    save("glow", 128, 128, image(128, 128, f, ss=1))


def vignette():
    # transparent middle, dark edges
    def f(x, y):
        dx, dy = (x - 128) / 128, (y - 128) / 128
        r = math.sqrt(dx * dx + dy * dy)
        return (0, 0, 0, smooth(0.5, 1.42, r) ** 1.3)
    save("vignette", 256, 256, image(256, 256, f, ss=1))


def ring():
    # level badge: a bold ring and a thin inner ring
    def f(x, y):
        r = math.hypot(x - 64, y - 64)
        a = 1.0 if 56 <= r <= 62 else 0.0
        if 49.5 <= r <= 51:
            a = max(a, 0.55)
        return (*WHITE, a)
    save("ring", 128, 128, image(128, 128, f))


def disc():
    # a filled circle with a soft edge (badge inside, round icon borders)
    def f(x, y):
        r = math.hypot(x - 32, y - 32)
        return (*WHITE, 1 - smooth(29, 31.5, r))
    save("disc", 64, 64, image(64, 64, f))


def seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    t = clamp(((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy))
    cx, cy = ax + vx * t, ay + vy * t
    return math.hypot(px - cx, py - cy)


def corner():
    # top-left corner ornament, mirrored in the game for the other corners
    lines = [
        (3, 3, 62, 3, 1.1), (3, 3, 3, 62, 1.1),        # outer L
        (9, 9, 40, 9, 0.55), (9, 9, 9, 40, 0.55),      # inner L
    ]

    def f(x, y):
        a = 0.0
        for ax, ay, bx, by, w in lines:
            d = seg_dist(x, y, ax, ay, bx, by)
            a = max(a, 1 - smooth(w - 0.5, w + 0.5, d))
        # a diamond sitting on the corner
        d = abs(x - 9) + abs(y - 9)
        a = max(a, 1 - smooth(5.5, 6.5, d))
        # small dots where the inner lines end
        for cx, cy in ((44, 9), (9, 44)):
            a = max(a, 1 - smooth(1.4, 2.2, math.hypot(x - cx, y - cy)))
        return (*WHITE, a)
    save("corner", 64, 64, image(64, 64, f))


def diamond():
    def f(x, y):
        d = abs(x - 16) + abs(y - 16)
        a = 1 - smooth(11, 12.5, d)
        inner = 1 - smooth(5, 6.5, d)
        return (*WHITE, max(a * 0.55, inner))
    save("diamond", 32, 32, image(32, 32, f))


def grain():
    # tileable film grain, drawn at very low alpha over the card
    rnd = random.Random(7)
    rows = []
    for y in range(128):
        row = []
        for x in range(128):
            v = rnd.random()
            row.append((255, 255, 255, int(v * v * 255)))
        rows.append(row)
    save("grain", 128, 128, rows)


# ---------------------------------------------------------------- icon --

GOLD_HI = (1.0, 0.88, 0.55)
GOLD_LO = (0.72, 0.5, 0.2)


def rounded_rect_dist(x, y, cx, cy, hw, hh, rad):
    qx, qy = abs(x - cx) - (hw - rad), abs(y - cy) - (hh - rad)
    ox, oy = max(qx, 0), max(qy, 0)
    return math.hypot(ox, oy) + min(max(qx, qy), 0) - rad


def gold(y, top, bottom):
    t = clamp((y - top) / (bottom - top))
    return tuple(GOLD_HI[i] * (1 - t) + GOLD_LO[i] * t for i in range(3))


def icon_fn(size, round_bg):
    s = size / 64.0

    def f(x, y):
        x, y = x / s, y / s
        # background: deep night with a warm light behind the card
        if round_bg:
            bg_a = 1 - smooth(30.5, 31.8, math.hypot(x - 32, y - 32))
        else:
            bg_a = 1 - smooth(-0.5, 0.5, rounded_rect_dist(x, y, 32, 32, 31.5, 31.5, 9))
        light = math.exp(-((x - 32) ** 2 + (y - 30) ** 2) / (2 * 15 ** 2))
        base = (0.06 + 0.25 * light, 0.06 + 0.17 * light, 0.1 + 0.06 * light)
        col, a = base, bg_a
        # the card: gold frame
        d = rounded_rect_dist(x, y, 32, 33, 15, 20, 3)
        frame = 1 - smooth(-0.6, 0.6, abs(d + 1.6) - 1.6)
        if d < -3.2:
            # inside: dark portrait with a hero bust in gold
            col = (0.09, 0.08, 0.12)
            head = math.hypot(x - 32, y - 28.5) - 5.2
            sh = math.hypot((x - 32) / 1.45, (y - 47) / 1.0) - 10.5
            bust = min(head, sh)
            if y > 49.5:
                bust = max(bust, y - 49.5)
            b = 1 - smooth(-0.6, 0.6, bust)
            g = gold(y, 22, 50)
            col = tuple(col[i] * (1 - b) + g[i] * b for i in range(3))
        if frame > 0:
            g = gold(y, 12, 54)
            col = tuple(col[i] * (1 - frame) + g[i] * frame for i in range(3))
        # a spark at the top right corner of the card
        sx, sy = x - 47, y - 14
        star = abs(sx) * abs(sy) * 0.9 + 0.12 * (sx * sx + sy * sy)
        st = 1 - smooth(1.6, 2.6, star)
        if st > 0:
            col = tuple(col[i] * (1 - st) + 1.0 * st for i in range(3))
            a = max(a, st)
        return (*col, a)
    return f


def icons():
    save("icon", 64, 64, image(64, 64, icon_fn(64, False)))
    save("minimap", 64, 64, image(64, 64, icon_fn(64, True)))
    if PREVIEW:
        rows = image(256, 256, icon_fn(256, False), ss=2)
        write_png(os.path.join(PREVIEW, "icon_big.png"), 256, 256, rows)


def write_png(path, w, h, rows):
    import zlib
    raw = b"".join(b"\0" + bytes(c for p in row for c in p) for row in rows)

    def ch(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                           + ch(b"IDAT", zlib.compress(raw)) + ch(b"IEND", b""))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
    glow()
    vignette()
    ring()
    disc()
    corner()
    diamond()
    grain()
    icons()
