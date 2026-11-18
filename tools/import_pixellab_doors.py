"""Importa a porta de saida do lobby (spr_door_lobby) do PixelLab.

As portas dos biomas eram as entradas das salas internas, que viraram celulas
do mapa 2D; os PNGs delas ficaram em tools/pixellab_raw/doors, sem uso.

Uso: python tools/import_pixellab_doors.py
Entrada: tools/pixellab_raw/doors/door_<bioma>.png
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import import_pixellab as importer  # noqa: E402
import pngio  # noqa: E402


BIOMES = ("lobby",)
names = []

for biome in BIOMES:
    source = os.path.join(importer.RAW, "doors", f"door_{biome}.png")
    if not os.path.isfile(source):
        raise FileNotFoundError(f"arte de porta ausente: {source}")

    pixels = pngio.read_png(source)
    height, width = len(pixels), len(pixels[0])
    name = f"spr_door_{biome}"
    importer.write_sprite(name, [pixels], (width // 2, height - 1))
    names.append(name)
    print(f"{name}: {width}x{height}, origem {(width // 2, height - 1)}")

importer.register_in_yyp(names)
print(f"Registrados {len(names)} sprites de porta no projeto.")
