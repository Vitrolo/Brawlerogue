"""Leitura e escrita de PNG em Python puro (sem PIL), para as ferramentas do projeto.

Uma imagem e uma lista de linhas; cada linha e uma lista de tuplas (r, g, b, a).
"""
import struct
import zlib


def read_png(path):
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"nao e PNG: {path}")
    pos = 8
    idat = bytearray()
    palette = None
    trns = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or interlace != 0:
                raise ValueError(f"PNG nao suportado (depth={depth}, interlace={interlace}): {path}")
        elif tag == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif tag == b"tRNS":
            trns = body
        elif tag == b"IDAT":
            idat += body
        elif tag == b"IEND":
            break
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(bytes(idat))
    stride = w * bpp
    rows = []
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        ft = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if ft == 1:
                line[i] = (line[i] + a) & 255
            elif ft == 2:
                line[i] = (line[i] + b) & 255
            elif ft == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif ft == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        prev = line
        row = []
        for x in range(w):
            px = line[x * bpp:(x + 1) * bpp]
            if ctype == 6:
                row.append(tuple(px))
            elif ctype == 2:
                row.append((px[0], px[1], px[2], 255))
            elif ctype == 0:
                row.append((px[0], px[0], px[0], 255))
            elif ctype == 4:
                row.append((px[0], px[0], px[0], px[1]))
            else:
                r, g, b2 = palette[px[0]]
                al = trns[px[0]] if trns is not None and px[0] < len(trns) else 255
                row.append((r, g, b2, al))
        rows.append(row)
    return rows


def write_png(path, px):
    h = len(px)
    w = len(px[0])
    raw = bytearray()
    for row in px:
        raw.append(0)
        for (r, g, b, a) in row:
            raw += bytes((r, g, b, a))

    def chunk(tag, body):
        c = struct.pack(">I", len(body)) + tag + body
        return c + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    out = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as fh:
        fh.write(out)


def blank(w, h, col=(0, 0, 0, 0)):
    return [[col] * w for _ in range(h)]


def bbox(px):
    """Caixa (x0, y0, x1, y1) inclusiva dos pixels nao transparentes, ou None."""
    xs = [x for row in px for x, c in enumerate(row) if c[3] > 0]
    ys = [y for y, row in enumerate(px) if any(c[3] > 0 for c in row)]
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def paste(dst, src, ox, oy):
    for y, row in enumerate(src):
        ty = y + oy
        if 0 <= ty < len(dst):
            drow = dst[ty]
            for x, c in enumerate(row):
                tx = x + ox
                if c[3] > 0 and 0 <= tx < len(drow):
                    drow[tx] = c


def scale(px, k):
    out = []
    for row in px:
        big = [c for c in row for _ in range(k)]
        for _ in range(k):
            out.append(list(big))
    return out


def contact_sheet(paths, out, k=3, bg=(60, 60, 70, 255)):
    """Junta varias imagens lado a lado, ampliadas, para conferencia visual."""
    imgs = [read_png(p) for p in paths]
    w = sum(len(i[0]) for i in imgs) + len(imgs) + 1
    h = max(len(i) for i in imgs) + 2
    sheet = blank(w, h, bg)
    x = 1
    for i in imgs:
        paste(sheet, i, x, 1)
        x += len(i[0]) + 1
    write_png(out, scale(sheet, k))


if __name__ == "__main__":
    import sys
    contact_sheet(sys.argv[2:], sys.argv[1])
