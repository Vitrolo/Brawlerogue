"""Importa a arte gerada no PixelLab para os sprites do GameMaker.

Uso:  python tools/import_pixellab.py            (na raiz do projeto)

Entrada: tools/pixellab_raw/<personagem>/Idle/{rotations,animations}/... (ZIP do PixelLab
ja extraido, so a direcao east) e tools/pixellab_raw/bg_<bioma>.png (cenarios).

Saida: PNGs e .yy dos sprites spr_<personagem>_* e spr_bg_<bioma>, e as entradas dos
cenarios no .yyp. Os nomes dos sprites dos personagens nao mudam; so os quadros.

Cada quadro e encostado no chao (a base da figura vai para a linha dos pes), porque o
jogo ja aplica a altura do pulo (z) no desenho. A origem fica nos pes, no centro do corpo.
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_project as gen          # noqa: E402  (formato .yy e guid)
import pngio                       # noqa: E402

ROOT = gen.ROOT
RAW = os.path.join(ROOT, "tools", "pixellab_raw")

# quadro = (animacao, indice). "rot" e a pose parada; "breath" e a pose parada com o
# tronco 1 px mais baixo (respiracao barata para quem nao tem animacao de idle).
ENEMY = {
    "idle": [("rot", 0), ("breath", 0)],
    "walk": [("walk", i) for i in range(6)],
    "telegraph": [("attack", 3)],
    "attack": [("attack", 4), ("attack", 5), ("attack", 1)],
    "hurt": [("fall", 2)],
    "knockdown": [("fall", 6)],
    "getup": [("fall", 4)],
    "dead": [("fall", 6)],
}

CHARACTERS = {
    "player": {
        "idle": [("idle", i) for i in range(4)],
        "walk": [("walk", i) for i in range(6)],
        "attack1": [("jab", 0), ("jab", 1), ("jab", 2)],
        "attack2": [("cross", 3), ("cross", 5), ("cross", 1)],
        "attack3": [("kick", 2), ("kick", 3), ("kick", 5)],
        "air_attack": [("flykick", 3)],
        "special": [("spin", i) for i in range(4)],
        "jump": [("jump", 4)],
        "fall": [("jump", 5)],
        "land": [("jump", 2)],
        "hurt": [("hurt", 2)],
        "knockdown": [("fall", 6)],
        "dead": [("fall", 6)],
        "getup": [("getup", 2)],
        "dodge": [("slide", 1)],
        "block": [("cross", 0)],
    },
    "thug": ENEMY,
    "runner": ENEMY,
    "brute": ENEMY,
    "boss": dict(ENEMY, jump=[("jump", 4)], land=[("jump", 2)], dash=[("attack", 5)]),
}

BACKGROUNDS = ["lobby", "sewer", "streets", "rooftops", "boss"]


def char_dir(char):
    return os.path.join(RAW, char, "Idle")


# Personagens que saem do PixelLab sem contorno e com cores que variam de uma
# animacao para outra. Para ficarem no padrao dos inimigos, cada quadro passa por
# restyle(): as cores sao trazidas para a paleta da pose parada + andar + idle e a
# silhueta ganha o contorno escuro de 1 px que os outros personagens ja tem.
RESTYLED = {"player"}
OUTLINE = (11, 9, 9, 255)
_palette_cache = {}


def reference_palette(char):
    if char not in _palette_cache:
        base = char_dir(char)
        files = [os.path.join(base, "rotations", "east.png")]
        for anim in ("walk", "idle"):
            folder = os.path.join(base, "animations", anim, "east")
            files += [os.path.join(folder, f) for f in sorted(os.listdir(folder))]
        colours = set()
        for f in files:
            for row in pngio.read_png(f):
                colours.update(c[:3] for c in row if c[3] > 0)
        _palette_cache[char] = sorted(colours)
    return _palette_cache[char]


def restyle(px, palette):
    h, w = len(px), len(px[0])
    nearest = {}

    def snap(c):
        if c not in nearest:
            # distancia em RGB mais a diferenca de saturacao, para pele clara nao virar branco
            sat = max(c) - min(c)
            nearest[c] = min(palette, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2
                             + 3 * ((max(p) - min(p)) - sat) ** 2)
        return nearest[c]

    out = [[(snap(c[:3]) + (255,)) if c[3] > 0 else (0, 0, 0, 0) for c in row] for row in px]
    solid = [[c[3] > 0 for c in row] for row in px]
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                continue
            if ((x > 0 and solid[y][x - 1]) or (x < w - 1 and solid[y][x + 1])
                    or (y > 0 and solid[y - 1][x]) or (y < h - 1 and solid[y + 1][x])):
                out[y][x] = OUTLINE
    return out


def load_frame(char, anim, index):
    base = char_dir(char)
    if anim in ("rot", "breath"):
        px = pngio.read_png(os.path.join(base, "rotations", "east.png"))
    else:
        px = pngio.read_png(os.path.join(base, "animations", anim, "east", f"frame_{index:03d}.png"))
    if char in RESTYLED:
        px = restyle(px, reference_palette(char))
    return breathe(px) if anim == "breath" else px


def breathe(px):
    """Desce 1 px tudo que esta acima da cintura."""
    x0, y0, x1, y1 = pngio.bbox(px)
    waist = y0 + int((y1 - y0) * 0.55)
    out = [row[:] for row in px]
    for y in range(waist, y0 - 1, -1):
        out[y] = px[y - 1][:] if y - 1 >= 0 else out[y]
    return out


def ground_align(px, ground):
    """Desloca o quadro na vertical para a base da figura ficar na linha `ground`."""
    box = pngio.bbox(px)
    if box is None:
        return px
    dy = (ground - 1) - box[3]
    if dy == 0:
        return px
    out = pngio.blank(len(px[0]), len(px))
    pngio.paste(out, px, 0, dy)
    return out


def write_sprite(name, frames, origin):
    h, w = len(frames[0]), len(frames[0][0])
    folder = os.path.join(ROOT, "sprites", name)
    if os.path.isdir(folder):
        shutil.rmtree(folder)
    layer_id = gen.guid(name, "layer")
    frame_ids = [gen.guid(name, "frame", str(i)) for i in range(len(frames))]
    for fid, px in zip(frame_ids, frames):
        for rel in (f"{fid}.png", os.path.join("layers", fid, f"{layer_id}.png")):
            full = os.path.join(folder, rel)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            pngio.write_png(full, px)
    gen.FW, gen.FH, gen.ORIGIN = w, h, origin
    gen.write(f"sprites/{name}/{name}.yy", gen.sprite_yy(name, frame_ids, layer_id))


def import_character(char, table):
    rot = load_frame(char, "rot", 0)
    x0, _, x1, y1 = pngio.bbox(rot)
    ground = y1 + 1
    origin = ((x0 + x1 + 1) // 2, ground)
    for key, specs in sorted(table.items()):
        frames = [ground_align(load_frame(char, a, i), ground) for a, i in specs]
        write_sprite(f"spr_{char}_{key}", frames, origin)
    print(f"{char}: {len(table)} sprites, quadro {len(rot[0])}x{len(rot)}, origem {origin}")


def import_backgrounds():
    names = []
    for biome in BACKGROUNDS:
        src = os.path.join(RAW, f"bg_{biome}.png")
        if not os.path.isfile(src):
            print(f"cenario ausente: {src}")
            continue
        px = pngio.read_png(src)
        px = [[(r, g, b, 255) for (r, g, b, _) in row] for row in px]
        name = f"spr_bg_{biome}"
        write_sprite(name, [px], (0, 0))
        names.append(name)
        print(f"{name}: {len(px[0])}x{len(px)}")
    return names


def register_in_yyp(names):
    """Acrescenta os sprites novos no fim da lista de recursos do .yyp."""
    path = os.path.join(ROOT, f"{gen.PROJECT}.yyp")
    with open(path, encoding="utf-8", newline="") as fh:
        text = fh.read()
    nl = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(nl)
    start = next(i for i, l in enumerate(lines) if l.strip().startswith('"resources"')) + 1
    end = next(i for i in range(start, len(lines)) if lines[i].strip() == "],")
    entries = lines[start:end]
    for n in names:
        line = f'    {{"id":{{"name":"{n}","path":"sprites/{n}/{n}.yy",}},}},'
        if line not in entries:
            entries.append(line)
    if entries == lines[start:end]:
        return
    lines[start:end] = entries
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(nl.join(lines))


if __name__ == "__main__":
    for char, table in CHARACTERS.items():
        if os.path.isdir(char_dir(char)):
            import_character(char, table)
        else:
            print(f"personagem ausente: {char}")
    register_in_yyp(import_backgrounds())
