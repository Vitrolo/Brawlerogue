"""Gera scripts/scr_weapon_hand/scr_weapon_hand.gml: a posicao da mao da frente em cada
quadro dos sprites do jogador, para desenhar a arma segurada (cano, taco) sem sprites novos.

A mao e achada pela cor da luva (marrom-escuro). Os quadros em que a deteccao erra
(olho, sapato) ficam em OVERRIDES, conferidos a olho numa folha ampliada.
A Safira (spr_p2_*) e troca de cor da Rubi, entao usa a mesma tabela.

Uso: python tools/weapon_anchors.py
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import pngio  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scripts", "scr_weapon_hand", "scr_weapon_hand.gml")
GLOVE = {(47, 34, 34), (60, 44, 45)}
Y_MIN, Y_MAX = 27, 58  # altura dos bracos (fora: olhos e sapatos)

# (sprite, quadro) -> (x, y) no sprite, onde a deteccao automatica pega olho ou sapato
OVERRIDES = {
    ("spr_player_fall", 0): (23, 39),
    ("spr_player_land", 0): (29, 57),
    ("spr_player_dodge", 0): (32, 60),
    ("spr_player_jump", 0): (21, 33),
    ("spr_player_air_attack", 0): (40, 31),
    ("spr_player_attack3", 1): (43, 33),
}


def sprite_frames(name):
    yy = open(os.path.join(ROOT, "sprites", name, name + ".yy"), encoding="utf8").read()
    ids = re.findall(r'"name":"([0-9a-f-]{36})","resourceType":"GMSpriteFrame"', yy)
    if not ids:
        ids = re.findall(r'\{"\$GMSpriteFrame":"[^"]*","%Name":"([0-9a-f-]{36})"', yy)
    xo = int(re.search(r'"xorigin":(-?\d+)', yy).group(1))
    yo = int(re.search(r'"yorigin":(-?\d+)', yy).group(1))
    return [pngio.read_png(os.path.join(ROOT, "sprites", name, i + ".png")) for i in ids], (xo, yo)


def glove_clusters(img):
    pts = {(x, y) for y, row in enumerate(img) for x, p in enumerate(row)
           if p[3] and p[:3] in GLOVE and Y_MIN <= y <= Y_MAX}
    out = []
    while pts:
        stack, cl = [pts.pop()], []
        while stack:
            q = stack.pop()
            cl.append(q)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (q[0] + dx, q[1] + dy)
                    if n in pts:
                        pts.remove(n)
                        stack.append(n)
        out.append(cl)
    return out


def front_hand(img):
    """Centro do grupo de luva mais a frente (os sprites olham para a direita)."""
    cls = [c for c in glove_clusters(img) if len(c) >= 3]
    if not cls:
        return None
    c = max(cls, key=lambda c: sum(p[0] for p in c) / len(c))
    return (round(sum(p[0] for p in c) / len(c)), round(sum(p[1] for p in c) / len(c)))


def main():
    names = sorted(os.path.basename(p) for p in glob.glob(os.path.join(ROOT, "sprites", "spr_player_*")))
    lines = []
    for name in names:
        imgs, (xo, yo) = sprite_frames(name)
        offs = []
        for i, img in enumerate(imgs):
            hand = OVERRIDES.get((name, i)) or front_hand(img) or (xo + 6, yo - 30)
            offs.append(f"[{hand[0] - xo}, {hand[1] - yo}]")
        lines.append(f"        {name}: [{', '.join(offs)}],")
    gml = (
        "// GERADO por tools/weapon_anchors.py -- nao editar a mao.\n"
        "// Mao da frente em cada quadro dos sprites do jogador, relativa a origem do sprite\n"
        "// (olhando para a direita, sem escala). spr_p2_* usa a mesma tabela.\n\n"
        "function weapon_hand_table() {\n"
        "    static _t = {\n" + "\n".join(lines) + "\n    };\n"
        "    return _t;\n"
        "}\n\n"
        "/// [dx, dy] da mao no quadro, ou undefined se o sprite nao e do jogador.\n"
        "function weapon_hand_offset(_spr, _frame) {\n"
        "    var _name = string_replace(sprite_get_name(_spr), \"spr_p2_\", \"spr_player_\");\n"
        "    var _arr = weapon_hand_table()[$ _name];\n"
        "    if (is_undefined(_arr)) return undefined;\n"
        "    return _arr[clamp(floor(_frame), 0, array_length(_arr) - 1)];\n"
        "}\n"
    )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf8", newline="\n") as fh:
        fh.write(gml)
    print(f"{len(names)} sprites -> {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
