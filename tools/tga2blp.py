"""Convert an uncompressed 32-bit TGA into an uncompressed BLP2 (BGRA8888)
with a full, precomputed mipmap chain. Usage: tga2blp.py in.tga out.blp [check.png]"""
import struct, sys, zlib


def read_tga(path):
    d = open(path, "rb").read()
    idlen, cmap, kind = d[0], d[1], d[2]
    assert cmap == 0 and kind == 2, "only uncompressed true-colour TGA"
    w, h = struct.unpack("<HH", d[12:16])
    bpp, desc = d[16], d[17]
    assert bpp in (24, 32)
    n = bpp // 8
    px = d[18 + idlen:18 + idlen + w * h * n]
    rows = []
    for y in range(h):
        row = []
        for x in range(w):
            p = px[(y * w + x) * n:(y * w + x) * n + n]
            b, g, r = p[0], p[1], p[2]
            a = p[3] if n == 4 else 255
            row.append((r, g, b, a))
        rows.append(row)
    if not desc & 0x20:  # bottom-left origin -> flip to top-left
        rows.reverse()
    return w, h, rows


def half(w, h, rows):
    """2x2 box filter with alpha weighting (no dark fringes)."""
    nw, nh = max(1, w // 2), max(1, h // 2)
    out = []
    for y in range(nh):
        row = []
        for x in range(nw):
            ps = [rows[min(h - 1, 2 * y + dy)][min(w - 1, 2 * x + dx)] for dy in (0, 1) for dx in (0, 1)]
            at = sum(p[3] for p in ps)
            if at:
                r = sum(p[0] * p[3] for p in ps) / at
                g = sum(p[1] * p[3] for p in ps) / at
                b = sum(p[2] * p[3] for p in ps) / at
            else:
                r = g = b = 0
            row.append((round(r), round(g), round(b), round(at / 4)))
        out.append(row)
    return nw, nh, out


def write_blp(path, w, h, rows):
    assert w & (w - 1) == 0 and h & (h - 1) == 0, "power of two"
    mips = []
    cw, ch, cr = w, h, rows
    while True:
        mips.append(b"".join(bytes((b, g, r, a)) for row in cr for (r, g, b, a) in row))
        if cw == 1 and ch == 1:
            break
        cw, ch, cr = half(cw, ch, cr)
    assert len(mips) <= 16
    header_size = 4 + 4 + 4 + 4 + 4 + 16 * 4 + 16 * 4 + 256 * 4  # 1172
    offsets, sizes, pos = [], [], header_size
    for m in mips:
        offsets.append(pos)
        sizes.append(len(m))
        pos += len(m)
    offsets += [0] * (16 - len(offsets))
    sizes += [0] * (16 - len(sizes))
    hdr = b"BLP2" + struct.pack("<I", 1)  # type 1 = direct / BLP2
    hdr += bytes((3, 8, 8, 1))  # encoding 3 = ARGB8888, alpha depth 8, alpha enc 8, has mips
    hdr += struct.pack("<II", w, h)
    hdr += struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes)
    hdr += b"\0" * 1024  # palette, unused
    assert len(hdr) == header_size
    open(path, "wb").write(hdr + b"".join(mips))
    return len(mips)


def read_blp(path):
    d = open(path, "rb").read()
    assert d[:4] == b"BLP2" and d[8] == 3
    w, h = struct.unpack("<II", d[12:20])
    offs = struct.unpack("<16I", d[20:84])
    sizes = struct.unpack("<16I", d[84:148])
    levels = []
    lw, lh = w, h
    for o, s in zip(offs, sizes):
        if not s:
            break
        assert s == lw * lh * 4 and o + s <= len(d)
        levels.append((lw, lh, d[o:o + s]))
        if lw == 1 and lh == 1:
            break
        lw, lh = max(1, lw // 2), max(1, lh // 2)
    return levels


def png(path, levels, zoom=4):
    """Every mip level side by side, each scaled to the base size, for eyeballing."""
    W, H = levels[0][0], levels[0][1]
    shown = levels[:4]
    out_w, out_h = W * zoom * len(shown), H * zoom
    rows = []
    for y in range(out_h):
        r = bytearray()
        for (lw, lh, data) in shown:
            for x in range(W * zoom):
                sx, sy = x * lw // (W * zoom), y * lh // out_h
                b, g, rr, a = data[(sy * lw + sx) * 4:(sy * lw + sx) * 4 + 4]
                r += bytes((rr, g, b, a))
        rows.append(bytes(r))
    raw = b"".join(b"\0" + r for r in rows)

    def ch(t, dd):
        return struct.pack(">I", len(dd)) + t + dd + struct.pack(">I", zlib.crc32(t + dd) & 0xFFFFFFFF)

    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", out_w, out_h, 8, 6, 0, 0, 0)) + ch(b"IDAT", zlib.compress(raw)) + ch(b"IEND", b""))


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    w, h, rows = read_tga(src)
    n = write_blp(dst, w, h, rows)
    levels = read_blp(dst)
    assert len(levels) == n
    # base level must equal the TGA pixels exactly
    base = levels[0][2]
    for y in range(h):
        for x in range(w):
            r, g, b, a = rows[y][x]
            assert base[(y * w + x) * 4:(y * w + x) * 4 + 4] == bytes((b, g, r, a))
    if len(sys.argv) > 3:
        png(sys.argv[3], levels)
    print(f"{dst}: {w}x{h}, {n} mip levels, {len(open(dst, 'rb').read())} bytes, base level matches TGA")
