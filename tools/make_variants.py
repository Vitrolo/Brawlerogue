"""Gera sprites derivados dos que ja existem, sem gastar geracoes do PixelLab.

Uso:  python tools/make_variants.py            (na raiz do projeto)

1. Agarrao e arremesso da Rubi (spr_player_grab, spr_player_throw), a partir da
   animacao "throw" em tools/pixellab_raw/player.
2. Variantes por troca de cor: segunda personagem (spr_p2_*), tres inimigos
   (spr_shooter_*, spr_shield_*, spr_bomber_*) e dois chefes (spr_bsewer_*,
   spr_bstreet_*). Cada variante copia os quadros de um personagem existente e
   troca faixas de matiz (ex.: cabelo vermelho -> azul), preservando a pele.

Rodar de novo e seguro: os sprites derivados sao reescritos por completo.
"""
import colorsys
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_project as gen          # noqa: E402
import pngio                       # noqa: E402
import import_pixellab as importer  # noqa: E402

ROOT = gen.ROOT

PLAYER_KEYS = ["idle", "walk", "run", "attack1", "attack2", "attack3", "air_attack", "special", "jump",
               "fall", "land", "hurt", "knockdown", "dead", "getup", "dodge", "block", "grab", "throw"]
ENEMY_KEYS = ["idle", "walk", "telegraph", "attack", "hurt", "knockdown", "getup", "dead"]

# Sprites extras dos chefes derivados: (sprite de origem, quadro)
BOSS_EXTRA = {"dash": ("attack", 1), "jump": ("telegraph", 0), "land": ("getup", 0)}

# Regra de cor: (matiz_min, matiz_max, saturacao_minima, novo_matiz, mult_saturacao, mult_valor)
# Matiz em graus. Se matiz_min > matiz_max a faixa cruza o zero (vermelhos).
VARIANTS = [
    dict(new="p2", src="player", keys=PLAYER_KEYS, extra={}, rules=[
        (330, 14, 0.55, 212, 0.95, 1.0),    # cabelo e blusa vermelhos -> azul
        (36, 66, 0.50, 285, 0.75, 0.9),     # calca amarela -> violeta
    ]),
    dict(new="shooter", src="runner", keys=ENEMY_KEYS, extra={}, rules=[
        (18, 52, 0.62, 128, 0.9, 0.85),     # casaco laranja -> verde
        (295, 352, 0.30, 52, 1.0, 1.0),     # cabelo rosa -> amarelo
    ]),
    dict(new="shield", src="thug", keys=ENEMY_KEYS, extra={}, rules=[
        (180, 235, 0.25, 4, 1.1, 1.0),      # cabelo azul -> vermelho
        (236, 295, 0.20, 100, 0.9, 1.05),   # colete roxo -> verde
    ]),
    dict(new="bomber", src="thug", keys=ENEMY_KEYS, extra={}, rules=[
        (180, 235, 0.25, 50, 1.2, 1.15),    # cabelo azul -> amarelo
        (236, 295, 0.20, 14, 1.3, 1.15),    # colete roxo -> laranja
    ]),
    dict(new="bsewer", src="brute", keys=ENEMY_KEYS, extra=BOSS_EXTRA, rules=[
        (60, 170, 0.20, 282, 1.1, 1.0),     # regata verde -> roxa
        (8, 40, 0.18, 98, 0.9, 0.95),       # pele e calca -> esverdeadas (mutante do esgoto)
    ]),
    dict(new="bstreet", src="runner", keys=ENEMY_KEYS, extra=BOSS_EXTRA, rules=[
        (18, 52, 0.62, 318, 1.0, 1.0),      # casaco laranja -> magenta
        (295, 352, 0.30, 182, 1.0, 1.05),   # cabelo rosa -> ciano
        (170, 215, 0.25, 268, 1.0, 0.9),    # calca azul-esverdeada -> roxa
    ]),
]


def recolor(px, rules):
    out = []
    for row in px:
        new_row = []
        for (r, g, b, a) in row:
            if a == 0:
                new_row.append((r, g, b, a))
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            deg = h * 360
            for lo, hi, smin, new_h, smul, vmul in rules:
                inside = (lo <= deg <= hi) if lo <= hi else (deg >= lo or deg <= hi)
                if inside and s >= smin:
                    nr, ng, nb = colorsys.hsv_to_rgb(new_h / 360, min(1, s * smul), min(1, v * vmul))
                    r, g, b = round(nr * 255), round(ng * 255), round(nb * 255)
                    break
            new_row.append((r, g, b, a))
        out.append(new_row)
    return out


def read_sprite(name):
    """Quadros (na ordem) e origem de um sprite ja existente no projeto."""
    folder = os.path.join(ROOT, "sprites", name)
    with open(os.path.join(folder, f"{name}.yy"), encoding="utf-8") as fh:
        text = fh.read()
    ids = re.findall(r'"\$GMSpriteFrame":"v1","%Name":"([^"]+)"', text)
    xo = int(re.search(r'"xorigin":(-?\d+)', text).group(1))
    yo = int(re.search(r'"yorigin":(-?\d+)', text).group(1))
    frames = [pngio.read_png(os.path.join(folder, f"{fid}.png")) for fid in ids]
    return frames, (xo, yo)


def make_grab_throw():
    """Agarrao (1 quadro) e arremesso (3 quadros) da personagem original."""
    char = "player"
    rot = importer.load_frame(char, "rot", 0)
    x0, _, x1, y1 = pngio.bbox(rot)
    ground = y1 + 1
    origin = ((x0 + x1 + 1) // 2, ground)
    table = {"grab": [("throw", 1)], "throw": [("throw", 2), ("throw", 3), ("throw", 4)]}
    names = []
    for key, specs in table.items():
        frames = [importer.ground_align(importer.load_frame(char, a, i), ground) for a, i in specs]
        importer.write_sprite(f"spr_{char}_{key}", frames, origin)
        names.append(f"spr_{char}_{key}")
    return names


def make_variant(v):
    names = []
    for key in v["keys"]:
        frames, origin = read_sprite(f"spr_{v['src']}_{key}")
        name = f"spr_{v['new']}_{key}"
        importer.write_sprite(name, [recolor(f, v["rules"]) for f in frames], origin)
        names.append(name)
    for key, (src_key, index) in v["extra"].items():
        frames, origin = read_sprite(f"spr_{v['src']}_{src_key}")
        name = f"spr_{v['new']}_{key}"
        importer.write_sprite(name, [recolor(frames[index], v["rules"])], origin)
        names.append(name)
    print(f"{v['new']}: {len(names)} sprites a partir de {v['src']}")
    return names


if __name__ == "__main__":
    all_names = make_grab_throw()
    for variant in VARIANTS:
        all_names += make_variant(variant)
    importer.register_in_yyp(all_names)
    print(f"{len(all_names)} sprites gravados")
