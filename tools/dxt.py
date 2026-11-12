"""BLP2 with DXT5 (BC3) compression, the format Blizzard and Questie use.

  dxt.py in.blp|in.tga out.blp [preview.png]

Input: an uncompressed BLP2 (encoding 3) or a 32-bit TGA. Output: BLP2,
encoding 2, alpha depth 8, alpha encoding 7 (DXT5), full mip chain.
The output is decoded again and compared with the source (PSNR printed).
"""
import math, struct, sys, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tga2blp import read_tga, half, png  # noqa: E402


def read_blp3(path):
    d = open(path, "rb").read()
    assert d[:4] == b"BLP2" and d[8] == 3, "need an uncompressed BLP2"
    w, h = struct.unpack("<II", d[12:20])
    off = struct.unpack("<16I", d[20:84])[0]
    raw = d[off:off + w * h * 4]
    rows = []
    for y in range(h):
        row = []
        for x in range(w):
            b, g, r, a = raw[(y * w + x) * 4:(y * w + x) * 4 + 4]
            row.append((r, g, b, a))
        rows.append(row)
    return w, h, rows


def to565(c):
    r, g, b = (max(0, min(255, int(round(v)))) for v in c)
    return ((r * 31 + 127) // 255) << 11 | ((g * 63 + 127) // 255) << 5 | ((b * 31 + 127) // 255)


def from565(v):
    r, g, b = (v >> 11) & 31, (v >> 5) & 63, v & 31
    return ((r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2))


def palette(c0, c1):
    a, b = from565(c0), from565(c1)
    return [a, b,
            tuple((2 * a[i] + b[i] + 1) // 3 for i in range(3)),
            tuple((a[i] + 2 * b[i] + 1) // 3 for i in range(3))]


def dist(p, q):
    return sum((p[i] - q[i]) ** 2 for i in range(3))


def color_block(px):
    """px: 16 (r,g,b,a). 4-colour mode, endpoints along the main axis,
    then a few least-squares refinements."""
    pts = [p[:3] for p in px if p[3] > 8] or [p[:3] for p in px]
    n = len(pts)
    mean = [sum(p[i] for p in pts) / n for i in range(3)]
    # principal axis by power iteration on the covariance
    cov = [[sum((p[i] - mean[i]) * (p[j] - mean[j]) for p in pts) for j in range(3)] for i in range(3)]
    axis = [1.0, 1.0, 1.0]
    for _ in range(8):
        nv = [sum(cov[i][j] * axis[j] for j in range(3)) for i in range(3)]
        m = math.sqrt(sum(v * v for v in nv))
        if m < 1e-9:
            break
        axis = [v / m for v in nv]
    proj = [sum((p[i] - mean[i]) * axis[i] for i in range(3)) for p in pts]
    lo, hi = min(proj), max(proj)
    e0 = [mean[i] + axis[i] * hi for i in range(3)]
    e1 = [mean[i] + axis[i] * lo for i in range(3)]
    best = None
    for _ in range(4):
        c0, c1 = to565(e0), to565(e1)
        if c0 < c1:
            c0, c1 = c1, c0
        if c0 == c1:
            # keep 4-colour mode readable everywhere: c0 > c1
            if c0 > 0:
                c1 = c0 - 1
            else:
                c0 = 1
        pal = palette(c0, c1)
        idx = [min(range(4), key=lambda k: dist(p[:3], pal[k])) for p in px]
        err = sum(dist(px[i][:3], pal[idx[i]]) for i in range(16) if px[i][3] > 8)
        if best is None or err < best[0]:
            best = (err, c0, c1, idx)
        # least squares refit of the endpoints for these indices
        wts = {0: (1, 0), 1: (0, 1), 2: (2 / 3, 1 / 3), 3: (1 / 3, 2 / 3)}
        aa = bb = ab = 0.0
        ax = [0.0] * 3
        bx = [0.0] * 3
        for i, p in enumerate(px):
            if p[3] <= 8:
                continue
            wa, wb = wts[idx[i]]
            aa += wa * wa
            bb += wb * wb
            ab += wa * wb
            for c in range(3):
                ax[c] += wa * p[c]
                bx[c] += wb * p[c]
        det = aa * bb - ab * ab
        if abs(det) < 1e-9:
            break
        pa = from565(c0)
        e0 = [(ax[c] * bb - bx[c] * ab) / det for c in range(3)]
        e1 = [(bx[c] * aa - ax[c] * ab) / det for c in range(3)]
    _, c0, c1, idx = best
    bits = 0
    for i, k in enumerate(idx):
        bits |= k << (2 * i)
    return struct.pack("<HHI", c0, c1, bits)


def alpha_palette(a0, a1):
    if a0 > a1:
        return [a0, a1] + [((7 - k) * a0 + k * a1 + 3) // 7 for k in range(1, 7)]
    return [a0, a1] + [((5 - k) * a0 + k * a1 + 2) // 5 for k in range(1, 5)] + [0, 255]


def alpha_block(px):
    al = [p[3] for p in px]
    lo, hi = min(al), max(al)
    cands = []
    if hi > lo:
        cands.append((hi, lo))  # 8 values between
    inner = [a for a in al if 0 < a < 255]
    if inner:
        cands.append((min(inner), max(inner)))  # 6 values + exact 0 and 255
    else:
        cands.append((lo, lo) if hi == lo else (0, 255))
    best = None
    for a0, a1 in cands:
        pal = alpha_palette(a0, a1)
        idx = [min(range(8), key=lambda k: abs(a - pal[k])) for a in al]
        err = sum(abs(al[i] - pal[idx[i]]) for i in range(16))
        if best is None or err < best[0]:
            best = (err, a0, a1, idx)
    _, a0, a1, idx = best
    bits = 0
    for i, k in enumerate(idx):
        bits |= k << (3 * i)
    return bytes((a0, a1)) + bits.to_bytes(6, "little")


def encode(w, h, rows):
    out = bytearray()
    for by in range(0, max(h, 4), 4):
        for bx in range(0, max(w, 4), 4):
            px = []
            for y in range(4):
                for x in range(4):
                    px.append(rows[min(h - 1, by + y)][min(w - 1, bx + x)])
            out += alpha_block(px) + color_block(px)
    return bytes(out)


def decode(w, h, data):
    rows = [[None] * w for _ in range(h)]
    bw = max(1, (w + 3) // 4)
    for bi in range(len(data) // 16):
        blk = data[bi * 16:bi * 16 + 16]
        bx, by = (bi % bw) * 4, (bi // bw) * 4
        apal = alpha_palette(blk[0], blk[1])
        abits = int.from_bytes(blk[2:8], "little")
        c0, c1, cbits = struct.unpack("<HHI", blk[8:16])
        pal = palette(c0, c1)
        for i in range(16):
            x, y = bx + i % 4, by + i // 4
            if x < w and y < h:
                rows[y][x] = (*pal[(cbits >> (2 * i)) & 3], apal[(abits >> (3 * i)) & 7])
    return rows


def write(path, w, h, rows):
    levels, cw, ch, cr = [], w, h, rows
    while True:
        levels.append((cw, ch, cr, encode(cw, ch, cr)))
        if cw == 1 and ch == 1:
            break
        cw, ch, cr = half(cw, ch, cr)
    header = 1172
    offs, sizes, pos = [], [], header
    for lv in levels:
        offs.append(pos)
        sizes.append(len(lv[3]))
        pos += len(lv[3])
    offs += [0] * (16 - len(offs))
    sizes += [0] * (16 - len(sizes))
    hdr = b"BLP2" + struct.pack("<I", 1) + bytes((2, 8, 7, 1)) + struct.pack("<II", w, h)
    hdr += struct.pack("<16I", *offs) + struct.pack("<16I", *sizes) + b"\0" * 1024
    open(path, "wb").write(hdr + b"".join(lv[3] for lv in levels))
    return levels


def psnr(a, b, w, h):
    se, n = 0, 0
    for y in range(h):
        for x in range(w):
            p, q = a[y][x], b[y][x]
            al = p[3] / 255
            se += sum(((p[i] - q[i]) * al) ** 2 for i in range(3)) + (p[3] - q[3]) ** 2
            n += 4
    return 99 if se == 0 else 10 * math.log10(255 * 255 / (se / n))


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    w, h, rows = read_tga(src) if src.lower().endswith(".tga") else read_blp3(src)
    levels = write(dst, w, h, rows)
    # check: header and the base level decode back close to the source
    d = open(dst, "rb").read()
    assert d[:4] == b"BLP2" and d[8:12] == bytes((2, 8, 7, 1))
    off, size = struct.unpack("<I", d[20:24])[0], struct.unpack("<I", d[84:88])[0]
    back = decode(w, h, d[off:off + size])
    print(f"{dst}: {w}x{h}, {len(levels)} mips, {len(d)} bytes, PSNR {psnr(rows, back, w, h):.1f} dB")
    if len(sys.argv) > 3:
        shown = []
        for (lw, lh, _, data) in levels[:4]:
            dec = decode(lw, lh, data)
            shown.append((lw, lh, b"".join(bytes((p[2], p[1], p[0], p[3])) for r in dec for p in r)))
        png(sys.argv[3], shown)
