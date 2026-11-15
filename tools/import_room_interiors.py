"""Import PixelLab fixed-room interiors into the GameMaker project.

Input: tools/pixellab_raw/interiors/interior_<biome>_<kind>.png
Output: one 480x272 sprite for each of 3 biomes x 4 room kinds.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import gen_project as gen  # noqa: E402
import pngio  # noqa: E402
import import_pixellab as importer  # noqa: E402


ROOT = gen.ROOT
RAW = os.path.join(ROOT, "tools", "pixellab_raw", "interiors")
BIOMES = ("sewer", "streets", "rooftops")
KINDS = ("reward", "challenge", "shop", "rest")


def import_interiors():
    names = []
    for biome in BIOMES:
        for kind in KINDS:
            source = os.path.join(RAW, f"interior_{biome}_{kind}.png")
            if not os.path.isfile(source):
                raise FileNotFoundError(f"Missing PixelLab interior: {source}")
            pixels = pngio.read_png(source)
            if len(pixels) != 272 or len(pixels[0]) != 480:
                raise ValueError(f"Expected 480x272 image, got {len(pixels[0])}x{len(pixels)}: {source}")
            # Interiors are full-screen opaque backgrounds, not transparent props.
            pixels = [[(r, g, b, 255) for r, g, b, _a in row] for row in pixels]
            name = f"spr_interior_{biome}_{kind}"
            importer.write_sprite(name, [pixels], (0, 0))
            names.append(name)
            print(f"{name}: 480x272")
    importer.register_in_yyp(names)


if __name__ == "__main__":
    import_interiors()
