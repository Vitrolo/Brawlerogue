"""Build integrated map entrance chunks from the project's biome backgrounds.

Usage: python tools/import_entrance_chunks.py

Each result is a full 768x272 backdrop tile. The surrounding pixels stay
identical to the source art, so the modified tile joins cleanly to its neighbors.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import import_pixellab as importer  # noqa: E402
import pngio  # noqa: E402


HORIZONS = {"sewer": 205, "streets": 138, "rooftops": 190}
BIOMES = tuple(HORIZONS)
KINDS = ("reward", "challenge", "shop", "rest")

# Fixed doorway centers in the repeated background tile. Odd map tiles are
# mirrored by GameMaker, so their art center is reflected here as well.
ART_CENTERS = {"reward": 584, "challenge": 311, "shop": 328, "rest": 495}

PALETTES = {
    "sewer": {
        "outline": (19, 22, 17, 255), "shadow": (29, 31, 24, 255),
        "base": (61, 56, 41, 255), "mid": (91, 79, 54, 255),
        "light": (127, 113, 77, 255), "hi": (163, 145, 101, 255),
        "moss": (75, 94, 48, 255), "inside": (5, 10, 10, 255),
        "deep": (13, 24, 21, 255),
    },
    "streets": {
        "outline": (20, 22, 29, 255), "shadow": (38, 35, 41, 255),
        "base": (74, 54, 49, 255), "mid": (115, 70, 59, 255),
        "light": (151, 91, 68, 255), "hi": (181, 123, 85, 255),
        "moss": (61, 88, 83, 255), "inside": (5, 7, 12, 255),
        "deep": (17, 22, 29, 255),
    },
    "rooftops": {
        "outline": (19, 18, 30, 255), "shadow": (35, 34, 48, 255),
        "base": (61, 59, 72, 255), "mid": (91, 87, 103, 255),
        "light": (126, 119, 137, 255), "hi": (162, 154, 166, 255),
        "moss": (65, 120, 145, 255), "inside": (5, 6, 13, 255),
        "deep": (18, 22, 34, 255),
    },
}

ACCENTS = {
    "reward": (232, 184, 83, 255),
    "challenge": (218, 91, 72, 255),
    "shop": (93, 198, 162, 255),
    "rest": (125, 157, 210, 255),
}


def rect(px, x0, y0, x1, y1, color):
    h, w = len(px), len(px[0])
    for y in range(max(0, y0), min(h, y1 + 1)):
        row = px[y]
        for x in range(max(0, x0), min(w, x1 + 1)):
            row[x] = color


def hline(px, x0, x1, y, color):
    rect(px, x0, y, x1, y, color)


def vline(px, x, y0, y1, color):
    rect(px, x, y0, x, y1, color)


def point(px, x, y, color):
    if 0 <= y < len(px) and 0 <= x < len(px[0]):
        px[y][x] = color


def draw_icon(px, cx, y, kind, accent, pal):
    """A small fixture on the entrance itself identifies its destination."""
    dark = pal["outline"]
    if kind == "reward":
        # A cut gem, mounted in a stone/metal socket.
        rect(px, cx - 8, y - 2, cx + 8, y + 8, dark)
        rect(px, cx - 6, y, cx + 6, y + 6, pal["base"])
        for dx, dy in ((0, 0), (-2, 2), (2, 2), (0, 4)):
            point(px, cx + dx, y + dy, accent)
        point(px, cx - 1, y + 1, pal["hi"])
    elif kind == "challenge":
        # A warning plate with a bold, readable zig-zag.
        rect(px, cx - 11, y - 2, cx + 11, y + 8, dark)
        rect(px, cx - 9, y, cx + 9, y + 6, pal["base"])
        for dx in (-6, 2):
            hline(px, cx + dx, cx + dx + 3, y + 1, accent)
            vline(px, cx + dx + 3, y + 1, y + 4, accent)
            hline(px, cx + dx, cx + dx + 3, y + 4, accent)
    elif kind == "shop":
        # A compact awning and coin medallion, built into the lintel.
        rect(px, cx - 12, y - 1, cx + 12, y + 7, dark)
        rect(px, cx - 10, y, cx + 10, y + 4, accent)
        for dx in (-6, 2):
            rect(px, cx + dx, y, cx + dx + 3, y + 4, pal["hi"])
        rect(px, cx - 4, y + 5, cx + 4, y + 7, pal["base"])
    else:
        # Rest point: a shaded lantern with a soft, restrained blue light.
        rect(px, cx - 7, y - 2, cx + 7, y + 9, dark)
        hline(px, cx - 5, cx + 5, y - 1, pal["light"])
        rect(px, cx - 4, y + 1, cx + 4, y + 6, accent)
        hline(px, cx - 3, cx + 3, y + 2, pal["hi"])
        hline(px, cx - 5, cx + 5, y + 8, pal["base"])


def draw_arch_portal(px, cx, floor_y, kind, pal):
    """Stone passage whose pixels sit directly in the painted wall."""
    top = floor_y - 102
    outer_r = 39
    inner_r = 27
    outer_center_y = top + outer_r
    inner_center_y = top + 37
    inner_top = inner_center_y - inner_r

    # Cut out the background object under the entrance, then build a deep,
    # black passage. The silhouette is sampled to the original tile's pixels.
    for y in range(top - 2, floor_y + 1):
        outer_half = outer_r if y >= outer_center_y else int(max(0, outer_r ** 2 - (y - outer_center_y) ** 2) ** 0.5)
        outer_half += 2
        inner_half = -1
        if y >= inner_top:
            inner_half = inner_r if y >= inner_center_y else int(max(0, inner_r ** 2 - (y - inner_center_y) ** 2) ** 0.5)
        for dx in range(-outer_half, outer_half + 1):
            x = cx + dx
            if y < 0 or y >= len(px) or x < 0 or x >= len(px[0]):
                continue
            adx = abs(dx)
            if adx <= inner_half and y < floor_y - 4:
                # The back wall falls into near-black green/brown shadow.
                if adx < 8 and y < floor_y - 24:
                    px[y][x] = pal["deep"]
                else:
                    px[y][x] = pal["inside"]
            elif adx <= outer_half - 2:
                if adx < inner_half + 4 or y < outer_center_y:
                    px[y][x] = pal["mid"]
                else:
                    px[y][x] = pal["base"]
            else:
                px[y][x] = pal["outline"]

    # Inner reveal and a shallow floor lip make the threshold read as depth.
    for y in range(inner_top + 2, floor_y - 7):
        point(px, cx - inner_r + 2, y, pal["shadow"])
        point(px, cx + inner_r - 2, y, pal["outline"])
    rect(px, cx - inner_r + 2, floor_y - 13, cx + inner_r - 2, floor_y - 8, pal["deep"])
    hline(px, cx - outer_r - 1, cx + outer_r + 1, floor_y - 4, pal["outline"])
    hline(px, cx - outer_r + 1, cx + outer_r - 1, floor_y - 3, pal["hi"])
    hline(px, cx - outer_r + 5, cx + outer_r - 5, floor_y - 2, pal["mid"])
    hline(px, cx - outer_r + 8, cx + outer_r - 8, floor_y - 1, pal["shadow"])

    # Block joints follow the arch and the two side columns.
    for yy in (floor_y - 89, floor_y - 73, floor_y - 57, floor_y - 41, floor_y - 25):
        inset = 0 if yy >= outer_center_y else max(0, outer_r - int(max(0, outer_r ** 2 - (yy - outer_center_y) ** 2) ** 0.5))
        left = cx - outer_r + inset
        right = cx + outer_r - inset
        hline(px, left + 2, cx - inner_r - 2, yy, pal["shadow"])
        hline(px, cx + inner_r + 2, right - 2, yy + 3, pal["shadow"])
        point(px, left + 2, yy - 1, pal["light"])
        point(px, right - 2, yy + 2, pal["light"])

    # Moss/iron accents on the lower jambs tie into sewer or masonry palettes.
    for xx, yy in ((cx - 33, floor_y - 15), (cx - 35, floor_y - 18), (cx + 31, floor_y - 22), (cx + 34, floor_y - 24)):
        point(px, xx, yy, pal["moss"] if kind == "rest" else pal["light"])

    # Destination badge is attached to the masonry cap rather than floating in
    # the room. Its tiny silhouette remains distinct at the game's normal scale.
    draw_icon(px, cx, top - 13, kind, ACCENTS[kind], pal)


def draw_square_portal(px, cx, floor_y, kind, pal):
    """Industrial or storefront opening with square, built-in jambs."""
    top = floor_y - 110
    half = 33
    inside_half = 22
    # Keep the casing narrow so the existing storefront/wall remains visible
    # around it. The entrance replaces only the opening and its brick jambs.
    rect(px, cx - half - 2, top - 2, cx + half + 2, floor_y - 3, pal["outline"])
    rect(px, cx - half, top, cx - inside_half - 2, floor_y - 5, pal["base"])
    rect(px, cx + inside_half + 2, top, cx + half, floor_y - 5, pal["base"])
    rect(px, cx - inside_half - 2, top, cx + inside_half + 2, top + 12, pal["mid"])
    rect(px, cx - inside_half, top + 14, cx + inside_half, floor_y - 9, pal["inside"])
    rect(px, cx - 10, top + 27, cx + 9, floor_y - 17, pal["deep"])
    rect(px, cx - 6, top + 33, cx + 5, floor_y - 20, pal["inside"])

    # Uneven brick courses echo the painted facades in the street background.
    for row, yy in enumerate(range(top + 18, floor_y - 18, 16)):
        seam = pal["shadow"] if row % 2 == 0 else pal["outline"]
        if row % 2 == 0:
            hline(px, cx - half + 2, cx - inside_half - 3, yy, seam)
            hline(px, cx + inside_half + 3, cx + half - 2, yy + 5, seam)
        else:
            hline(px, cx - half + 2, cx - inside_half - 3, yy + 5, seam)
            hline(px, cx + inside_half + 3, cx + half - 2, yy, seam)
        point(px, cx - half + 4, yy - 1, pal["light"])
        point(px, cx + half - 4, yy + 2, pal["light"])

    hline(px, cx - half - 4, cx + half + 4, top + 1, pal["hi"])
    hline(px, cx - half - 1, cx + half + 1, top + 5, pal["shadow"])

    if kind == "shop":
        # Only the shop gets a short fabric awning, attached to the facade.
        hline(px, cx - half - 2, cx + half + 2, top - 3, pal["outline"])
        for x in range(cx - half, cx + half + 1, 8):
            rect(px, x, top - 2, min(x + 3, cx + half), top + 2, ACCENTS[kind] if ((x - (cx - half)) // 8) % 2 == 0 else pal["mid"])
    elif kind == "rest":
        # Small wall lantern is fixed to the left jamb.
        rect(px, cx - half - 8, top + 15, cx - half - 3, top + 28, pal["outline"])
        rect(px, cx - half - 7, top + 17, cx - half - 4, top + 24, ACCENTS[kind])
        hline(px, cx - half - 9, cx - half - 2, top + 14, pal["light"])
    elif kind == "challenge":
        # Two warning marks are set into the lintel, not above the scene.
        point(px, cx - 5, top + 5, ACCENTS[kind])
        point(px, cx + 5, top + 5, ACCENTS[kind])
        point(px, cx - 4, top + 6, pal["hi"])
        point(px, cx + 6, top + 6, pal["hi"])
    else:
        draw_icon(px, cx, top - 3, kind, ACCENTS[kind], pal)

    # Threshold is only a few pixels deep, so the continuous floor remains.
    hline(px, cx - half - 1, cx + half + 1, floor_y - 4, pal["outline"])
    hline(px, cx - half + 3, cx + half - 3, floor_y - 3, pal["hi"])
    hline(px, cx - half + 7, cx + half - 7, floor_y - 2, pal["shadow"])


def draw_rooftop_portal(px, cx, floor_y, kind, pal):
    """Roof-access bulkhead emerging from the parapet, not a floating door."""
    top = floor_y - 102
    left, right = cx - 39, cx + 39
    # Low utility housing with a sloped roof and masonry foot attached to the
    # parapet. The door itself is inset into the housing.
    rect(px, left + 5, top + 8, right - 5, floor_y - 5, pal["outline"])
    for dx in range(0, 6):
        hline(px, left + 6 + dx, right - 6 - dx, top + dx, pal["shadow"] if dx < 2 else pal["base"])
    rect(px, left + 10, top + 15, right - 10, floor_y - 8, pal["mid"])
    rect(px, cx - 27, top + 29, cx + 27, floor_y - 8, pal["outline"])
    rect(px, cx - 23, top + 33, cx + 23, floor_y - 11, pal["inside"])
    rect(px, cx - 10, top + 43, cx + 9, floor_y - 18, pal["deep"])
    vline(px, left + 11, top + 17, floor_y - 10, pal["light"])
    vline(px, right - 12, top + 17, floor_y - 10, pal["shadow"])
    hline(px, left + 3, right - 3, floor_y - 5, pal["outline"])
    hline(px, left + 9, right - 9, floor_y - 4, pal["hi"])
    hline(px, left + 15, right - 15, floor_y - 3, pal["shadow"])

    # Vent ribs and rivets make the housing read as rooftop machinery.
    for xx in range(left + 17, right - 11, 8):
        vline(px, xx, top + 18, top + 24, pal["shadow"])
    for bx in (left + 11, right - 11):
        point(px, bx, top + 30, pal["hi"])
        point(px, bx, floor_y - 15, ACCENTS[kind])
    draw_icon(px, cx, top + 10, kind, ACCENTS[kind], pal)


def build_chunk(biome, kind, center_x):
    source = os.path.join(importer.RAW, f"bg_{biome}.png")
    px = pngio.read_png(source)
    h, w = len(px), len(px[0])
    if (w, h) != (768, 272):
        raise ValueError(f"{source}: esperado 768x272, recebido {w}x{h}")
    px = [[(r, g, b, 255) for (r, g, b, _) in row] for row in px]
    pal = PALETTES[biome]
    floor_y = HORIZONS[biome]
    if biome == "sewer":
        draw_arch_portal(px, center_x, floor_y, kind, pal)
    elif biome == "rooftops":
        draw_rooftop_portal(px, center_x, floor_y, kind, pal)
    else:
        draw_square_portal(px, center_x, floor_y, kind, pal)
    return px


def main():
    names = []
    for biome in BIOMES:
        for kind in KINDS:
            name = f"spr_bg_chunk_{biome}_{kind}"
            pixels = build_chunk(biome, kind, ART_CENTERS[kind])
            importer.write_sprite(name, [pixels], (0, 0))
            names.append(name)
            print(f"{name}: 768x272, centro {ART_CENTERS[kind]}")
    importer.register_in_yyp(names)
    print(f"Registrados {len(names)} trechos integrados de entrada.")


if __name__ == "__main__":
    main()
