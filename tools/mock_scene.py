"""Monta, fora do jogo, uma imagem de como stage_draw_placeholder desenha um cenario.

Uso:  python tools/mock_scene.py SAIDA.png BIOMA [x_da_camera] [sprite_do_tile=indice ...]
Serve para conferir emendas, faixas de chao e posicao de portas sem abrir o GameMaker.
Os numeros de INFO devem acompanhar stage_backdrop_info (scripts/scr_backdrop).
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pngio  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# bioma: (horizon, band_y0, band_y1, band_shift)
INFO = {"sewer": (205, 228, 249, 173), "streets": (138, 156, 243, 0), "rooftops": (190, 236, 272, 173),
        "boss": (228, 254, 272, 173), "lobby": (203, 223, 238, 0)}
VIEW_W, VIEW_H, FLOOR_Y = 480, 270, 170


def sprite_frame(name, index=0):
    files = sorted(glob.glob(os.path.join(ROOT, "sprites", name, "*.png")))
    return pngio.read_png(files[index])


def backdrop(biome, cam_x=0, tile_sprites=None):
    hz, y0, y1, shift = INFO[biome]
    base = sprite_frame(f"spr_bg_{biome}")
    tiles = {i: sprite_frame(n) for i, n in (tile_sprites or {}).items()}
    w = len(base[0])
    oy = FLOOR_Y - hz
    img = pngio.blank(VIEW_W, VIEW_H, (0, 0, 0, 255))
    for sy in range(VIEW_H):
        iy = sy - oy
        src_tiles = tiles
        off = 0
        if iy < 0:
            iy = 0
        elif iy >= y1:
            # cada copia da faixa e deslocada na horizontal para nao repetir o desenho
            k, r = divmod(iy - y1, y1 - y0)
            iy = y0 + r
            off = ((k + 1) * shift) % w
            src_tiles = {}  # a repeticao usa sempre o cenario base
        for sx in range(VIEW_W):
            wx = sx + cam_x + off
            t = wx // w
            ix = wx % w
            if t % 2 != 0:
                ix = w - 1 - ix
            r, g, b, _ = src_tiles.get(t, base)[iy][ix]
            img[sy][sx] = (r, g, b, 255)
    return img


def draw(img, name, x, y, index=0, flip=False, cam_x=0):
    """Desenha um sprite pela origem (lida do .yy), como draw_sprite."""
    with open(os.path.join(ROOT, "sprites", name, f"{name}.yy"), encoding="utf-8") as fh:
        text = fh.read()
    xo = int(re.search(r'"xorigin":(-?\d+)', text).group(1))
    yo = int(re.search(r'"yorigin":(-?\d+)', text).group(1))
    px = sprite_frame(name, index)
    if flip:
        px = [list(reversed(r)) for r in px]
        xo = len(px[0]) - xo
    pngio.paste(img, px, x - cam_x - xo, y - yo)


if __name__ == "__main__":
    out, biome = sys.argv[1], sys.argv[2]
    cam = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    tiles = {}
    for arg in sys.argv[4:]:
        n, i = arg.split("=")
        tiles[int(i)] = n
    scene = backdrop(biome, cam, tiles)
    pngio.write_png(out, pngio.scale(scene, 2))
