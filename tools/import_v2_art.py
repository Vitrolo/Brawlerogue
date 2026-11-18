"""Importa a segunda leva de arte do PixelLab: objetos das salas e do cenario.

Uso:  python tools/import_v2_art.py            (na raiz do projeto)

Entrada (tools/pixellab_raw/v2):
  sheet_rooms.png      bau, banca, banco e boneco de treino lado a lado
  sheet_props.png      barril, caixa, lixeira, cano e taco lado a lado
  car.png              carro das ruas

Saida (sprites do projeto, substituindo os antigos de mesmo nome):
  spr_obj_chest/stall/bench/dummy      objeto de cada tipo de sala (no proprio
                                       corredor dos mapas 2D)
  spr_prop_barrel/crate/bin/car        quebraveis e o carro
  spr_weapon_pipe/bat                  armas no chao (reduzidas pela metade)

As antigas salas internas e entradas do corredor (room_<bioma>.png,
door_<bioma>.png) nao sao mais usadas: as salas viraram celulas do mapa 2D.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_project as gen           # noqa: E402
import pngio                        # noqa: E402
import import_pixellab as importer  # noqa: E402

ROOT = gen.ROOT
RAW = os.path.join(ROOT, "tools", "pixellab_raw", "v2")


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

    importer.register_in_yyp(names)
    print(f"{len(names)} sprites gravados")


if __name__ == "__main__":
    main()
