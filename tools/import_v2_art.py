"""Importa a segunda leva de arte do PixelLab: salas internas, entradas e objetos.

Uso:  python tools/import_v2_art.py            (na raiz do projeto)

Entrada (tools/pixellab_raw/v2):
  room_<bioma>.png     interior pintado, 480x272
  door_<bioma>.png     porta do bioma, 64x80, fundo transparente
  sheet_rooms.png      bau, banca, banco e boneco de treino lado a lado
  sheet_props.png      barril, caixa, lixeira, cano e taco lado a lado
  car.png              carro das ruas

Saida (sprites do projeto, substituindo os antigos de mesmo nome):
  spr_obj_chest/stall/bench/dummy      objeto de cada tipo de sala especial
  spr_prop_barrel/crate/bin/car        quebraveis e o carro
  spr_weapon_pipe/bat                  armas no chao (reduzidas pela metade)
  spr_interior_<bioma>_<tipo>          sala interna: parede do interior, chao
                                       refeito ate a base da tela e a porta de
                                       saida do bioma na direita
  spr_bg_chunk_<bioma>_<tipo>          tile do corredor com a MESMA porta do
                                       bioma, num trecho livre da parede

Assim a entrada no corredor, a saida dentro da sala e o objeto da sala usam a
mesma arte. Substitui import_room_interiors.py e import_entrance_chunks.py.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_project as gen           # noqa: E402
import pngio                        # noqa: E402
import import_pixellab as importer  # noqa: E402

ROOT = gen.ROOT
RAW = os.path.join(ROOT, "tools", "pixellab_raw", "v2")
BIOMES = ("sewer", "streets", "rooftops")
KINDS = ("reward", "challenge", "shop", "rest")
VIEW_W, VIEW_H, FLOOR_Y = 480, 272, 170


# Centro da entrada dentro do tile de 768 px, por bioma (os mesmos de
# stage_entrance_img_x). Cada um cai num trecho da parede sem canos, janelas
# ou lojas por baixo, para a porta nao ficar sobreposta ao cenario.
ART_CENTERS = {
    "sewer":    {"reward": 560, "challenge": 240, "shop": 470, "rest": 32},
    "streets":  {"reward": 630, "challenge": 219, "shop": 630, "rest": 219},
    "rooftops": {"reward": 505, "challenge": 295, "shop": 505, "rest": 295},
}
# Antes de colar a porta, cobre o que sobraria do cenario dos lados dela copiando
# pixels de `dy` linhas abaixo: (x0, x1, y0, y1, dy). Nas ruas, o toldo da loja
# amarela apareceria nas bordas da porta.
CHUNK_PATCH = {("streets", 630): (596, 664, 80, 101, 22)}
# Linha do cenario do corredor onde o chao comeca (stage_backdrop_info.horizon).
CORRIDOR_HORIZON = {"sewer": 205, "streets": 138, "rooftops": 190}
# Quantos pixels a base da porta invade o chao (a do esgoto tem um caminho de terra).
DOOR_SINK = {"sewer": 7, "streets": 2, "rooftops": 2}

# Interior: linha onde o chao comeca na imagem e a faixa limpa de piso usada para
# refazer o chao (x0, x1, y0, y1). O chao do jogo precisa de 100 px; as imagens tem menos.
ROOMS = {
    "sewer":    dict(horizon=202, band=(0, 320, 203, 227), shift=97),
    "streets":  dict(horizon=200, band=(0, 480, 201, 243), shift=173),
    "rooftops": dict(horizon=243, band=(0, 480, 244, 272), shift=173),
}
EXIT_X = 428  # centro da porta de saida (obj_door "return" fica em width - 52)


def opaque(px):
    return [[(r, g, b, 255) for (r, g, b, _) in row] for row in px]


def crop(px, x0, y0, x1, y1):
    return [row[x0:x1 + 1] for row in px[y0:y1 + 1]]


def components(px):
    """Separa os objetos de uma folha: grupos de pixels opacos ligados entre si,
    da esquerda para a direita. Sobras com menos de 40 pixels sao descartadas."""
    h, w = len(px), len(px[0])
    seen = [[False] * w for _ in range(h)]
    found = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or px[sy][sx][3] == 0:
                continue
            stack = [(sx, sy)]
            seen[sy][sx] = True
            pts = []
            while stack:
                x, y = stack.pop()
                pts.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[ny][nx][3] > 0:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if len(pts) < 40:
                continue
            x0 = min(p[0] for p in pts)
            x1 = max(p[0] for p in pts)
            y0 = min(p[1] for p in pts)
            y1 = max(p[1] for p in pts)
            img = pngio.blank(x1 - x0 + 1, y1 - y0 + 1)
            for x, y in pts:
                img[y - y0][x - x0] = px[y][x]
            found.append((x0, img))
    found.sort(key=lambda f: f[0])
    return [img for _, img in found]


def half(px):
    """Reduz pela metade mantendo pixels inteiros (um a cada dois)."""
    out = []
    for y in range(0, len(px) - 1, 2):
        row = []
        for x in range(0, len(px[0]) - 1, 2):
            block = [px[y][x], px[y][x + 1], px[y + 1][x], px[y + 1][x + 1]]
            solid = [c for c in block if c[3] > 0]
            row.append(solid[0] if len(solid) >= 2 else (0, 0, 0, 0))
        out.append(row)
    return out


def pad_even(px):
    """Sprites com largura e altura pares evitam meia origem."""
    w = len(px[0]) + (len(px[0]) % 2)
    h = len(px) + (len(px) % 2)
    out = pngio.blank(w, h)
    pngio.paste(out, px, 0, h - len(px))
    return out


def stamp_bottom(dst, src, cx, bottom):
    """Cola src com a base da figura em `bottom` e o centro em `cx`."""
    x0, y0, x1, y1 = pngio.bbox(src)
    fig = crop(src, x0, y0, x1, y1)
    pngio.paste(dst, fig, cx - len(fig[0]) // 2, bottom - len(fig))


def load_objects():
    rooms = components(pngio.read_png(os.path.join(RAW, "sheet_rooms.png")))
    props = components(pngio.read_png(os.path.join(RAW, "sheet_props.png")))
    if len(rooms) != 4 or len(props) != 5:
        raise ValueError(f"folhas com contagem inesperada: {len(rooms)} e {len(props)} objetos")
    car = pngio.read_png(os.path.join(RAW, "car.png"))
    cb = pngio.bbox(car)
    return {
        "obj_chest": rooms[0], "obj_stall": rooms[1], "obj_bench": rooms[2], "obj_dummy": rooms[3],
        "prop_barrel": props[0], "prop_crate": props[1], "prop_bin": props[2],
        "weapon_pipe": half(props[3]), "weapon_bat": half(props[4]),
        "prop_car": crop(car, *cb),
    }


def strip_door(biome, door):
    """Tira o cano cinza que vem colado na porta do esgoto: ele nao combina com
    os canos do cenario e ficava parecendo um objeto solto ao lado da entrada."""
    if biome != "sewer":
        return door
    out = [row[:] for row in door]
    for y, row in enumerate(out):
        for x in range(len(row)):
            if x >= 56 or (x >= 44 and y < 24):
                row[x] = (0, 0, 0, 0)
    return out


def build_room(biome, door):
    """Interior 480x272: parede da imagem acima da linha do chao do jogo, chao
    refeito com a faixa limpa (cada fileira deslocada) e a porta de saida."""
    cfg = ROOMS[biome]
    src = opaque(pngio.read_png(os.path.join(RAW, f"room_{biome}.png")))
    bx0, bx1, by0, by1 = cfg["band"]
    bw, bh = bx1 - bx0, by1 - by0
    out = pngio.blank(VIEW_W, VIEW_H, (0, 0, 0, 255))
    for y in range(VIEW_H):
        if y < FLOOR_Y:
            sy = max(0, y + cfg["horizon"] - FLOOR_Y)
            out[y] = list(src[sy])
            continue
        k, r = divmod(y - FLOOR_Y, bh)
        for x in range(VIEW_W):
            # tira espelhada a cada copia para a emenda horizontal nao aparecer
            t, ix = divmod(x + k * cfg["shift"], bw)
            if t % 2:
                ix = bw - 1 - ix
            out[y][x] = src[by0 + r][bx0 + ix]
    stamp_bottom(out, door, EXIT_X, FLOOR_Y + DOOR_SINK[biome])
    return out


def build_chunk(biome, kind, door):
    """Tile do corredor com a porta do bioma num trecho livre da parede."""
    px = opaque(pngio.read_png(os.path.join(ROOT, "tools", "pixellab_raw", f"bg_{biome}.png")))
    cx = ART_CENTERS[biome][kind]
    patch = CHUNK_PATCH.get((biome, cx))
    if patch:
        x0, x1, y0, y1, dy = patch
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px[y][x] = px[y + dy][x]
    stamp_bottom(px, door, cx, CORRIDOR_HORIZON[biome] + DOOR_SINK[biome])
    return px


def main():
    names = []
    objects = load_objects()
    for key, px in objects.items():
        px = pad_even(px)
        w, h = len(px[0]), len(px)
        # armas: origem no centro (ficam deitadas no chao); o resto: base ao centro
        origin = (w // 2, h // 2) if key.startswith("weapon_") else (w // 2, h)
        importer.write_sprite(f"spr_{key}", [px], origin)
        names.append(f"spr_{key}")
        print(f"spr_{key}: {w}x{h}")

    for biome in BIOMES:
        door = strip_door(biome, pngio.read_png(os.path.join(RAW, f"door_{biome}.png")))
        room = build_room(biome, door)
        for kind in KINDS:
            name = f"spr_interior_{biome}_{kind}"
            importer.write_sprite(name, [room], (0, 0))
            names.append(name)
            name = f"spr_bg_chunk_{biome}_{kind}"
            importer.write_sprite(name, [build_chunk(biome, kind, door)], (0, 0))
            names.append(name)
        print(f"{biome}: sala interna e 4 entradas")
    importer.register_in_yyp(names)
    print(f"{len(names)} sprites gravados")


if __name__ == "__main__":
    main()
