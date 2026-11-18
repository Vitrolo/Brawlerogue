"""Importa a arte dos mapas 2D: escadas, paredes de fim de corredor e lajes.

Uso:  python tools/import_v3_level_art.py            (na raiz do projeto)

Entrada (tools/pixellab_raw/v3), uma peca de cada por bioma, geradas no PixelLab
(create_image_pixen; as descricoes estao em docs/geracao_2d.md):
  stairs_<bioma>.png   escada reta subindo da esquerda para a direita, fundo transparente
  cap_<bioma>.png      parede que fecha a ponta de um corredor (64 px de largura)
  slab_<bioma>.png     laje entre duas faixas (768 px de largura); sem ela, usa
                       slab.png, uma laje neutra que recebe a paleta de cada bioma

Saida (sprites do projeto):
  spr_lvl_stairs_<bioma>   origem no pe da escada (no chao, junto a parede do fundo)
  spr_lvl_cap_<bioma>      parede da esquerda; a da direita e desenhada espelhada
  spr_lvl_slab_<bioma>     tira desenhada logo abaixo do chao da faixa de cima

As cores de cada peca sao encaixadas na paleta do cenario do mesmo bioma
(tools/pixellab_raw/bg_<bioma>.png): nenhuma cor nova entra no jogo.

Para cada escada o script mede na arte a linha dos degraus e imprime o
deslocamento horizontal entre o pe e o topo (190 px acima). Esse numero vai em
stage_stairs_run (scripts/scr_backdrop), que a geracao usa para posicionar o topo.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_project as gen           # noqa: E402
import pngio                        # noqa: E402
import import_pixellab as importer  # noqa: E402

ROOT = gen.ROOT
RAW = os.path.join(ROOT, "tools", "pixellab_raw")
V3 = os.path.join(RAW, "v3")
BIOMES = ("sewer", "streets", "rooftops")
RISE = 190      # chao de baixo (floor_top) ate a beirada do chao de cima (floor_bottom)
BAND_H = 270    # altura de uma faixa (uma tela)
SLAB_H = 16     # altura da laje no jogo


def biome_palette(biome):
    colours = set()
    for row in pngio.read_png(os.path.join(RAW, f"bg_{biome}.png")):
        colours.update(c[:3] for c in row if c[3] > 0)
    return sorted(colours)


def snap_palette(px, palette):
    """Troca cada cor pela mais proxima da paleta (mantem a transparencia)."""
    cache = {}

    def snap(c):
        if c not in cache:
            cache[c] = min(palette, key=lambda p: (p[0] - c[0]) ** 2 + 2 * (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2)
        return cache[c]

    return [[(snap(c[:3]) + (255,)) if c[3] > 0 else (0, 0, 0, 0) for c in row] for row in px]


def stairs_geometry(px):
    """Pe e deslocamento da escada. A borda direita da arte (pontas dos degraus,
    sem o corrimao) e uma reta; o pe fica 6 px para dentro dela, na ultima linha
    da arte. Retorna (pe_x, pe_y, run)."""
    h = len(px)
    rows = []
    for y in range(h):
        xs = [x for x, c in enumerate(px[y]) if c[3] > 0]
        if xs:
            rows.append((y, max(xs)))
    y_top, y_bottom = rows[0][0], rows[-1][0]
    span = y_bottom - y_top
    # trecho do meio: fora do topo (que pode encostar na borda da imagem) e do pe
    mid = [(y, x) for y, x in rows if y_top + span * 0.2 <= y <= y_top + span * 0.9]
    n = len(mid)
    my = sum(y for y, _ in mid) / n
    mx = sum(x for _, x in mid) / n
    b = sum((y - my) * (x - mx) for y, x in mid) / sum((y - my) ** 2 for y, _ in mid)
    right_at = lambda y: mx + b * (y - my)  # noqa: E731
    foot_x = round(right_at(y_bottom) - 6)
    run = round(-b * RISE)
    return foot_x, y_bottom, run


def import_stairs(biome, palette):
    px = pngio.read_png(os.path.join(V3, f"stairs_{biome}.png"))
    px = snap_palette(px, palette)
    foot_x, foot_y, run = stairs_geometry(px)
    name = f"spr_lvl_stairs_{biome}"
    importer.write_sprite(name, [px], (foot_x, foot_y))
    print(f"{name}: {len(px[0])}x{len(px)}  pe ({foot_x}, {foot_y})  run {run}")
    return name, run


def import_cap(biome, palette):
    px = pngio.read_png(os.path.join(V3, f"cap_{biome}.png"))
    px = [[(r, g, b, 255) for (r, g, b, _) in row] for row in px][:BAND_H]
    px = snap_palette(px, palette)
    name = f"spr_lvl_cap_{biome}"
    importer.write_sprite(name, [px], (0, 0))
    print(f"{name}: {len(px[0])}x{len(px)}")
    return name


def import_slab(biome, palette):
    # uma laje por bioma, ou a laje neutra (slab.png) com a paleta de cada bioma
    src = os.path.join(V3, f"slab_{biome}.png")
    if not os.path.isfile(src):
        src = os.path.join(V3, "slab.png")
    if not os.path.isfile(src):
        print(f"laje ausente para {biome} (o jogo usa o desenho provisorio)")
        return None
    px = pngio.read_png(src)
    # faixa do meio da tira gerada, com a altura da laje no jogo
    y0 = max(0, (len(px) - SLAB_H) // 2)
    px = [[(r, g, b, 255) for (r, g, b, _) in row] for row in px[y0:y0 + SLAB_H]]
    px = snap_palette(px, palette)
    name = f"spr_lvl_slab_{biome}"
    importer.write_sprite(name, [px], (0, 0))
    print(f"{name}: {len(px[0])}x{len(px)}")
    return name


def main():
    names = []
    runs = {}
    for biome in BIOMES:
        palette = biome_palette(biome)
        name, run = import_stairs(biome, palette)
        names.append(name)
        runs[biome] = run
        names.append(import_cap(biome, palette))
        slab = import_slab(biome, palette)
        if slab:
            names.append(slab)
    importer.register_in_yyp(names)
    print("stage_stairs_run:", ", ".join(f"{b} {r}" for b, r in runs.items()))


if __name__ == "__main__":
    main()
