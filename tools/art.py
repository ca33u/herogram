"""Herogram art from one picture.

    python3 tools/art.py /path/to/picture.png

Writes, like the other addicted addons:
  Media/logo.png       1024x1024 (CurseForge / Wago / GitHub)
  Media/thumbnail.png  512x512
  Media/icon.blp       64x64 DXT5 (addon list icon)
  Media/minimap.blp    64x64 DXT5 (minimap button; the game rounds it)

Resizing is done by macOS `sips` (no Pillow needed); the BLPs go through
tools/dxt.py, the same DXT5 writer as every other texture.
"""
import os, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dxt  # noqa: E402

MEDIA = os.path.join(HERE, "..", "Media")


def sips(src, dst, size, fmt):
    subprocess.run(["sips", "-s", "format", fmt, "-z", str(size), str(size), src, "--out", dst],
                   check=True, stdout=subprocess.DEVNULL)


def read_tga(path):
    """Uncompressed or RLE true-colour TGA (24/32 bit) -> w, h, RGBA rows (top first)."""
    d = open(path, "rb").read()
    idlen, cmap, kind = d[0], d[1], d[2]
    assert cmap == 0 and kind in (2, 10), "true-colour TGA only"
    w, h = struct.unpack("<HH", d[12:16])
    n, desc = d[16] // 8, d[17]
    assert n in (3, 4)
    p, px = 18 + idlen, []

    def one(o):
        b, g, r = d[o], d[o + 1], d[o + 2]
        return (r, g, b, d[o + 3] if n == 4 else 255)
    while len(px) < w * h:
        if kind == 2:
            px.append(one(p))
            p += n
        else:
            head = d[p]
            p += 1
            count = (head & 0x7F) + 1
            if head & 0x80:
                px.extend([one(p)] * count)
                p += n
            else:
                for _ in range(count):
                    px.append(one(p))
                    p += n
    rows = [px[y * w:(y + 1) * w] for y in range(h)]
    if not desc & 0x20:
        rows.reverse()
    return w, h, rows


def blp(src, name):
    with tempfile.TemporaryDirectory() as tmp:
        tga = os.path.join(tmp, name + ".tga")
        sips(src, tga, 64, "tga")
        w, h, rows = read_tga(tga)
    path = os.path.join(MEDIA, name + ".blp")
    levels = dxt.write(path, w, h, rows)
    d = open(path, "rb").read()
    off, size = struct.unpack("<I", d[20:24])[0], struct.unpack("<I", d[84:88])[0]
    back = dxt.decode(w, h, d[off:off + size])
    print(f"Media/{name}.blp 64x64 DXT5, {len(levels)} mips, PSNR {dxt.psnr(rows, back, w, h):.1f} dB")


def main():
    if len(sys.argv) != 2 or not os.path.isfile(sys.argv[1]):
        sys.exit(__doc__)
    src = sys.argv[1]
    os.makedirs(MEDIA, exist_ok=True)
    sips(src, os.path.join(MEDIA, "logo.png"), 1024, "png")
    print("Media/logo.png 1024x1024")
    sips(src, os.path.join(MEDIA, "thumbnail.png"), 512, "png")
    print("Media/thumbnail.png 512x512")
    blp(src, "icon")
    blp(src, "minimap")


if __name__ == "__main__":
    main()
