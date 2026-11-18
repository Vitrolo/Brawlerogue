"""Previa, fora do jogo, de duas faixas de um mapa 2D ligadas por uma escada.

Uso:  python tools/mock_level.py SAIDA.png [bioma ...] [--x=CAMERA_X]

Desenha como stage_draw_level (scripts/scr_backdrop): o cenario de cada faixa
recortado no proprio corredor, a laje sob o chao de cima, as paredes nas pontas,
a escada do bioma e a personagem no pe, no meio e no topo da escada. Serve para
conferir o encaixe da arte (pe no chao junto a parede, chegada na beirada do chao
de cima) sem abrir o GameMaker. Os numeros acompanham stage_backdrop_info e
stage_stairs_run.
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pngio  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INFO = {"sewer": (205, 228, 249, 173), "streets": (138, 156, 243, 0), "rooftops": (190, 236, 272, 173)}
RUN = {"sewer": 92, "streets": 76, "rooftops": 84}
BAND_H, FLOOR_TOP, FLOOR_BOTTOM, CAP_MARGIN = 270, 178, 258, 50
VIEW_W = 480


def sprite(name, index=0):
    files = sorted(glob.glob(os.path.join(ROOT, "sprites", name, "*.png")))
    with open(os.path.join(ROOT, "sprites", name, name + ".yy"), encoding="utf-8") as fh:
        yy = fh.read()
    ox = int(re.search(r'"xorigin":(-?\d+)', yy).group(1))
    oy = int(re.search(r'"yorigin":(-?\d+)', yy).group(1))
    return pngio.read_png(files[index]), ox, oy


def put(img, x, y, c):
    if 0 <= y < len(img) and 0 <= x < len(img[0]) and c[3] > 0:
        img[y][x] = c[:3] + (255,)


def blit(img, px, x, y, flip=False, cx0=None, cx1=None):
    """Cola px com o canto em (x, y) (no espelhado, x e a borda direita)."""
    h, w = len(px), len(px[0])
    for sy in range(h):
        for sx in range(w):
            dx = (x - 1 - sx) if flip else (x + sx)
            if cx0 is not None and not (cx0 <= dx < cx1):
                continue
            put(img, dx, y + sy, px[sy][sx])


def draw_corridor(img, biome, x1, x2, oy, cam_x):
    """Como stage_draw_corridor: tiles de 768 espelhados um sim, um nao."""
    hz, y0, y1, shift = INFO[biome]
    bg = sprite("spr_bg_" + biome)[0]
    w = len(bg[0])
    iy = oy + FLOOR_TOP - 8 - hz
    bottom = oy + BAND_H
    sky = bg[0][0][:3] + (255,)
    for y in range(oy, bottom):
        for x in range(max(x1, cam_x), min(x2, cam_x + VIEW_W)):
            put(img, x - cam_x, y, sky)
    for x in range(max(x1, cam_x), min(x2, cam_x + VIEW_W)):
        t = x // w
        col = (w - 1 - (x - t * w)) if t % 2 else (x - t * w)
        for y in range(oy, bottom):
            sy = y - iy
            if sy < 0:
                sy = 0
            elif sy >= y1:
                row = (sy - y1) // (y1 - y0) + 1
                xs = x + (row * shift) % w
                tt = xs // w
                col = (w - 1 - (xs - tt * w)) if tt % 2 else (xs - tt * w)
                sy = y0 + (sy - y1) % (y1 - y0)
            put(img, x - cam_x, y, bg[sy][col])


def render(biome, cam_x=120):
    img = pngio.blank(VIEW_W, BAND_H * 2, (8, 8, 12, 255))
    # faixa de cima (0) e de baixo (1), as duas comecando na coluna 0
    draw_corridor(img, biome, 0, 1536, 0, cam_x)
    draw_corridor(img, biome, 0, 1536, BAND_H, cam_x)
    slab = sprite("spr_lvl_slab_" + biome)[0]
    for x in range(cam_x, cam_x + VIEW_W):
        col = x % len(slab[0])
        for sy in range(len(slab)):
            put(img, x - cam_x, BAND_H + sy, slab[sy][col])
    cap = sprite("spr_lvl_cap_" + biome)[0]
    blit(img, cap, 0 - cam_x, 0)
    blit(img, cap, 0 - cam_x, BAND_H)
    # escada no pe x=330 da faixa de baixo, subindo para a direita
    stairs, sox, soy = sprite("spr_lvl_stairs_" + biome)
    foot_x, foot_y = 330, BAND_H + FLOOR_TOP
    top_x, top_y = foot_x + RUN[biome], FLOOR_BOTTOM
    blit(img, stairs, foot_x - sox - cam_x, foot_y - soy)
    # personagem no pe, no meio e no topo do caminho
    walk, wox, woy = sprite("spr_player_walk", 1)
    for t in (0.0, 0.5, 1.0):
        px = round(foot_x + (top_x - foot_x) * t)
        py = round(foot_y + (top_y - foot_y) * t)
        blit(img, walk, px - wox - cam_x, py - woy)
    # marcas do caminho da escada (pe e topo)
    for (mx, my) in ((foot_x, foot_y), (top_x, top_y)):
        for d in range(-3, 4):
            put(img, mx - cam_x + d, my, (255, 0, 255, 255))
            put(img, mx - cam_x, my + d, (255, 0, 255, 255))
    return img


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--x=")]
    cam = [int(a[4:]) for a in sys.argv[1:] if a.startswith("--x=")]
    out = args[0] if args else "mock_level.png"
    biomes = args[1:] or list(INFO)
    imgs = [render(b, cam[0] if cam else 120) for b in biomes]
    sheet = pngio.blank(VIEW_W * len(imgs) + 8 * (len(imgs) - 1), BAND_H * 2, (0, 0, 0, 255))
    for i, im in enumerate(imgs):
        pngio.paste(sheet, im, i * (VIEW_W + 8), 0)
    pngio.write_png(out, sheet)
    print("salvo:", out)


if __name__ == "__main__":
    main()
