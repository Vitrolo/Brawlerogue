"""Conferencias estaticas do projeto (nao substitui compilar no GameMaker).

Uso:  python tools/check_project.py            (na raiz do projeto)

Verifica: funcoes duplicadas, chamadas a funcoes do jogo que nao existem,
sprites e objetos citados no GML que nao existem, chaves/parenteses desbalanceados
e recursos fora do .yyp.
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

PREFIXES = (
    "ui_", "fx_", "meta_", "save_", "run_", "challenge_", "prop_", "props_", "projectile_",
    "hazard_", "enemy_", "boss_", "player_", "stage_", "encounter_", "cam_", "choice_",
    "interact_", "hitbox_", "combat_", "vfx_", "hud_", "game_", "mod_", "mods_", "reward_",
    "weapon_", "toast_", "room_", "rooms_", "biome_", "input_", "actor_", "attack_",
    "config_", "chars_", "synergy_", "results_", "effect_", "option_", "shop_", "event_",
    "time_", "struct_merge", "decor_", "route_", "enemies_",
)
# funcoes nativas do GameMaker que comecam com um dos prefixos acima
BUILTIN = {
    "game_end", "game_set_speed", "game_restart", "room_goto", "room_restart", "room_get_name",
    "event_inherited", "event_perform", "event_user",
}


def strip(text):
    text = re.sub(r'"[^"\n]*"', '""', text)
    return re.sub(r"//[^\n]*", "", text)


def main():
    src = {}
    for path in glob.glob("scripts/*/*.gml") + glob.glob("objects/*/*.gml"):
        with open(path, encoding="utf-8") as fh:
            src[path] = fh.read()
    alltext = "\n".join(src.values())
    clean = strip(alltext)
    problems = 0

    names = re.findall(r"^function\s+(\w+)", alltext, re.M)
    defs = set(names)
    for d in sorted(defs):
        if names.count(d) > 1:
            print("funcao duplicada:", d)
            problems += 1

    calls = set(re.findall(r"\b([a-z_][a-z0-9_]*)\s*\(", clean))
    for c in sorted(calls):
        if c.startswith(PREFIXES) and c not in defs and c not in BUILTIN:
            print("chamada sem definicao:", c)
            problems += 1

    for kind, pattern in (("sprites", r"\bspr_\w+"), ("objects", r"\bobj_\w+")):
        have = set(os.listdir(kind))
        for ref in sorted(set(re.findall(pattern, clean)) - have):
            print(f"{kind[:-1]} inexistente:", ref)
            problems += 1

    for path, text in src.items():
        c = strip(text)
        for a, b in ("{}", "()", "[]"):
            if c.count(a) != c.count(b):
                print(f"desbalanceado em {path}: {a}={c.count(a)} {b}={c.count(b)}")
                problems += 1

    with open("Brawlerogue.yyp", encoding="utf-8") as fh:
        yyp = fh.read()
    for kind in ("scripts", "objects", "sprites", "rooms"):
        for n in os.listdir(kind):
            if not os.path.isfile(f"{kind}/{n}/{n}.yy"):
                print("sem .yy:", kind, n)
                problems += 1
            elif f"{kind}/{n}/{n}.yy" not in yyp:
                print("fora do .yyp:", kind, n)
                problems += 1

    print(f"{len(defs)} funcoes, {len(src)} arquivos GML, {problems} problema(s)")


if __name__ == "__main__":
    main()
