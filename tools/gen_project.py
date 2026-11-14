"""Gera os arquivos de recurso do GameMaker (.yyp/.yy) e os sprites PLACEHOLDER.

Uso:  python tools/gen_project.py            (na raiz do projeto)

- Scripts e objetos: cria o .yy a partir dos .gml existentes em scripts/ e objects/.
- Sprites: desenha bonecos de blocos (placeholder) e grava PNG + .yy.
- Rooms e .yyp: reescritos por completo.

ATENCAO: sobrescreve .yy e .yyp. Depois que o projeto passar a ser editado pela IDE
(rooms pintados, sprites finais importados), nao rode mais sem revisar: use so como
referencia de formato ou para regenerar placeholders.
"""
import os
import struct
import uuid
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "Brawlerogue"
NS = uuid.UUID("6f1f3f0a-5a51-4c62-9a54-0b1e2d3c4f50")


def guid(*parts):
    return str(uuid.uuid5(NS, "/".join(parts)))


def write(path, text):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(text)


# --------------------------------------------------------------------- PNG

def png_bytes(w, h, px):
    """px: lista de linhas, cada uma lista de (r,g,b,a)."""
    raw = bytearray()
    for row in px:
        raw.append(0)
        for (r, g, b, a) in row:
            raw += bytes((r, g, b, a))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))


# ------------------------------------------------- bonecos placeholder

FW, FH = 64, 56          # tamanho do frame
CX, GROUND = 32, 55      # centro horizontal e linha dos pes
ORIGIN = (32, 56)        # origem no ponto de contato com o chao
OUTLINE = (12, 12, 28, 255)
CLEAR = (0, 0, 0, 0)

PAL_PLAYER = dict(hair=(226, 38, 54), skin=(244, 190, 150), top=(170, 20, 60),
                  pants=(240, 190, 50), shoes=(250, 250, 250), trim=(255, 222, 90),
                  eye=(30, 20, 40))
PAL_THUG = dict(hair=(40, 220, 200), skin=(200, 160, 130), top=(96, 60, 150),
                pants=(60, 64, 84), shoes=(30, 30, 40), trim=(200, 200, 210),
                eye=(20, 20, 30))
PAL_BOSS = dict(hair=(255, 210, 63), skin=(196, 176, 206), top=(70, 24, 104),
                pants=(34, 26, 56), shoes=(255, 60, 170), trim=(45, 226, 230),
                eye=(255, 60, 90))
PAL_RUNNER = dict(hair=(255, 60, 170), skin=(226, 180, 140), top=(240, 120, 40),
                  pants=(30, 70, 90), shoes=(240, 240, 240), trim=(255, 230, 120),
                  eye=(20, 20, 30))
PAL_BRUTE = dict(hair=(40, 44, 60), skin=(170, 140, 120), top=(70, 120, 84),
                 pants=(50, 44, 40), shoes=(20, 20, 24), trim=(190, 196, 204),
                 eye=(255, 210, 63))


class Canvas:
    def __init__(self):
        self.px = [[CLEAR] * FW for _ in range(FH)]

    def rect(self, x, y, w, h, col):
        col = tuple(col) + (255,) if len(col) == 3 else col
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if 0 <= xx < FW and 0 <= yy < FH:
                    self.px[yy][xx] = col

    def outline(self):
        out = [row[:] for row in self.px]
        for y in range(FH):
            for x in range(FW):
                if self.px[y][x][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < FW and 0 <= ny < FH and self.px[ny][nx][3] != 0:
                            out[y][x] = OUTLINE
                            break
        self.px = out

    def lie_down(self):
        """Gira a figura em pe para deitada de costas, cabeca para tras."""
        pts = [(x, y, self.px[y][x]) for y in range(FH) for x in range(FW) if self.px[y][x][3]]
        xmin = min(p[0] for p in pts)
        ymin = min(p[1] for p in pts)
        ymax = max(p[1] for p in pts)
        x0 = CX - (ymax - ymin + 1) // 2
        self.px = [[CLEAR] * FW for _ in range(FH)]
        for x, y, c in pts:
            nx, ny = x0 + (y - ymin), GROUND - (x - xmin)
            if 0 <= nx < FW and 0 <= ny < FH:
                self.px[ny][nx] = c

    def mirror(self):
        self.px = [list(reversed(row)) for row in self.px]


def figure(pal, style, crouch=0, lean=0, legs=(0, 0), lift=(0, 0), kick=False,
           arm="guard", lying=False, mirror=False):
    """Desenha um lutador de blocos virado para a direita."""
    c = Canvas()
    tw = {"player": 12, "thug": 15, "boss": 19, "runner": 11, "brute": 18}[style]
    leg_len = 18 - crouch
    hip = GROUND - leg_len + 1
    tx = CX - tw // 2 + lean
    ty = hip - 16
    sh = ty + 2

    # pernas (tras, frente)
    bx, fx = CX - 6 + legs[0], CX + 1 + legs[1]
    c.rect(bx, hip, 5, leg_len - lift[0], pal["pants"])
    c.rect(bx, GROUND - lift[0] - 2, 6, 3, pal["shoes"])
    if kick:
        c.rect(CX + lean, hip, 20, 5, pal["pants"])
        c.rect(CX + lean + 18, hip - 1, 4, 7, pal["shoes"])
    else:
        c.rect(fx, hip, 5, leg_len - lift[1], pal["pants"])
        c.rect(fx, GROUND - lift[1] - 2, 6, 3, pal["shoes"])

    # tronco
    c.rect(tx, ty, tw, 16, pal["top"])
    c.rect(tx, hip - 2, tw, 2, pal["trim"])

    # cabeca e cabelo
    hx = tx + tw // 2 - 4 + (1 if lean > 0 else 0)
    c.rect(hx, ty - 10, 10, 10, pal["skin"])
    c.rect(hx + 7, ty - 6, 1, 2, pal["eye"])
    if style == "player":
        c.rect(hx - 1, ty - 12, 11, 4, pal["hair"])   # franja
        c.rect(hx - 3, ty - 11, 4, 17, pal["hair"])   # rabo de cavalo
    elif style == "boss":
        c.rect(hx - 1, ty - 12, 12, 2, pal["hair"])   # coroa
        for sx in (hx - 1, hx + 4, hx + 9):
            c.rect(sx, ty - 15, 2, 3, pal["hair"])
        c.rect(tx - 3, ty + 1, 4, 26 - crouch, pal["trim"])  # capa
    elif style == "runner":
        c.rect(hx - 1, ty - 9, 11, 3, pal["hair"])    # bandana
        c.rect(hx - 5, ty - 8, 4, 2, pal["hair"])
    elif style == "brute":
        c.rect(hx, ty - 5, 10, 5, pal["hair"])        # mascara
        c.rect(tx - 2, ty, tw + 4, 4, pal["trim"])    # ombreiras
    else:
        c.rect(hx + 2, ty - 14, 5, 5, pal["hair"])    # moicano

    # braco da frente
    ax = tx + tw - 2
    if arm == "down":
        c.rect(ax - 1, sh, 4, 12, pal["skin"])
        c.rect(ax - 1, sh + 9, 4, 3, pal["trim"])
    elif arm == "guard":
        c.rect(ax, sh + 1, 6, 4, pal["skin"])
        c.rect(ax + 3, sh - 4, 4, 6, pal["trim"])
    elif arm == "punch":
        c.rect(ax, sh, 15, 4, pal["skin"])
        c.rect(ax + 13, sh - 1, 5, 6, pal["trim"])
    elif arm == "punch_low":
        c.rect(ax, sh + 5, 16, 4, pal["skin"])
        c.rect(ax + 14, sh + 4, 5, 6, pal["trim"])
    elif arm == "back":
        c.rect(tx - 6, sh + 2, 8, 4, pal["skin"])
        c.rect(tx - 8, sh + 1, 4, 6, pal["trim"])
    elif arm == "up":
        c.rect(ax, sh - 9, 4, 12, pal["skin"])
        c.rect(ax - 1, sh - 12, 6, 4, pal["trim"])
    elif arm == "block":
        c.rect(ax + 2, sh - 7, 4, 15, pal["skin"])
        c.rect(ax + 1, sh - 9, 6, 5, pal["trim"])

    if lying:
        c.lie_down()
    if mirror:
        c.mirror()
    c.outline()
    return c.px


def character_sprites(prefix, pal, style):
    f = lambda **kw: figure(pal, style, **kw)
    walk = [f(legs=(-3, 3)), f(lift=(0, 2)), f(legs=(3, -3)), f(lift=(2, 0))]
    common = {
        "idle": [f(), f(crouch=1)],
        "walk": walk,
        "hurt": [f(lean=-3, arm="up")],
        "knockdown": [f(lying=True, arm="down")],
        "getup": [f(crouch=8, lean=2, arm="down")],
        "dead": [f(lying=True, arm="down")],
    }
    if style == "player":
        common.update({
            "jump": [f(lift=(4, 6), arm="up")],
            "fall": [f(lift=(2, 3), arm="guard")],
            "land": [f(crouch=5, arm="down")],
            "attack1": [f(lean=-1, arm="back"), f(lean=2, arm="punch"), f(lean=1)],
            "attack2": [f(lean=-1, arm="back", crouch=1), f(lean=3, arm="punch_low", crouch=2), f(lean=1, crouch=1)],
            "attack3": [f(lean=-2, crouch=2), f(lean=-3, kick=True), f(crouch=1)],
            "air_attack": [f(lean=-2, kick=True, lift=(5, 0))],
            "dodge": [f(crouch=9, lean=4, arm="down")],
            "block": [f(lean=-1, arm="block")],
            "special": [f(kick=True, arm="punch"), f(kick=True, arm="punch", mirror=True)],
        })
    else:
        common.update({
            "telegraph": [f(lean=-3, arm="back", crouch=1)],
            "attack": [f(lean=-2, arm="back"), f(lean=3, arm="punch"), f(lean=1)],
        })
    if style == "boss":
        common.update({
            "jump": [f(lift=(4, 6), arm="up")],
            "land": [f(crouch=6, arm="down")],
            "dash": [f(crouch=5, lean=5, arm="punch_low")],
        })
    return {f"spr_{prefix}_{k}": v for k, v in common.items()}


# ------------------------------------------------------------ recursos .yy

def sprite_yy(name, frame_ids, layer_id):
    path = f"sprites/{name}/{name}.yy"
    frames = "\n".join(
        f'    {{"$GMSpriteFrame":"v1","%Name":"{fid}","name":"{fid}","resourceType":"GMSpriteFrame","resourceVersion":"2.0",}},'
        for fid in frame_ids)
    keys = "\n".join(
        f'            {{"$Keyframe<SpriteFrameKeyframe>":"","Channels":{{\n'
        f'                "0":{{"$SpriteFrameKeyframe":"","Id":{{"name":"{fid}","path":"{path}",}},"resourceType":"SpriteFrameKeyframe","resourceVersion":"2.0",}},\n'
        f'              }},"Disabled":false,"id":"{guid(name, fid, "key")}","IsCreationKey":false,"Key":{float(i)},"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>","resourceVersion":"2.0","Stretch":false,}},'
        for i, fid in enumerate(frame_ids))
    return f'''{{
  "$GMSprite":"v2",
  "%Name":"{name}",
  "bboxMode":0,
  "bbox_bottom":{FH - 1},
  "bbox_left":0,
  "bbox_right":{FW - 1},
  "bbox_top":0,
  "collisionKind":1,
  "collisionTolerance":0,
  "DynamicTexturePage":false,
  "edgeFiltering":false,
  "For3D":false,
  "frames":[
{frames}
  ],
  "gridX":0,
  "gridY":0,
  "height":{FH},
  "HTile":false,
  "layers":[
    {{"$GMImageLayer":"","%Name":"{layer_id}","blendMode":0,"displayName":"default","isLocked":false,"name":"{layer_id}","opacity":100.0,"resourceType":"GMImageLayer","resourceVersion":"2.0","visible":true,}},
  ],
  "name":"{name}",
  "nineSlice":null,
  "origin":9,
  "parent":{{
    "name":"Sprites",
    "path":"folders/Sprites.yy",
  }},
  "preMultiplyAlpha":false,
  "resourceType":"GMSprite",
  "resourceVersion":"2.0",
  "sequence":{{
    "$GMSequence":"v1",
    "%Name":"{name}",
    "autoRecord":true,
    "backdropHeight":768,
    "backdropImageOpacity":0.5,
    "backdropImagePath":"",
    "backdropWidth":1366,
    "backdropXOffset":0.0,
    "backdropYOffset":0.0,
    "events":{{
      "$KeyframeStore<MessageEventKeyframe>":"",
      "Keyframes":[],
      "resourceType":"KeyframeStore<MessageEventKeyframe>",
      "resourceVersion":"2.0",
    }},
    "eventStubScript":null,
    "eventToFunction":{{}},
    "length":{float(len(frame_ids))},
    "lockOrigin":false,
    "moments":{{
      "$KeyframeStore<MomentsEventKeyframe>":"",
      "Keyframes":[],
      "resourceType":"KeyframeStore<MomentsEventKeyframe>",
      "resourceVersion":"2.0",
    }},
    "name":"{name}",
    "playback":1,
    "playbackSpeed":10.0,
    "playbackSpeedType":0,
    "resourceType":"GMSequence",
    "resourceVersion":"2.0",
    "showBackdrop":true,
    "showBackdropImage":false,
    "timeUnits":1,
    "tracks":[
      {{"$GMSpriteFramesTrack":"","builtinName":0,"events":[],"inheritsTrackColour":true,"interpolation":1,"isCreationTrack":false,"keyframes":{{"$KeyframeStore<SpriteFrameKeyframe>":"","Keyframes":[
{keys}
          ],"resourceType":"KeyframeStore<SpriteFrameKeyframe>","resourceVersion":"2.0",}},"modifiers":[],"name":"frames","resourceType":"GMSpriteFramesTrack","resourceVersion":"2.0","spriteId":null,"trackColour":0,"tracks":[],"traits":0,}},
    ],
    "visibleRange":null,
    "volume":1.0,
    "xorigin":{ORIGIN[0]},
    "yorigin":{ORIGIN[1]},
  }},
  "swatchColours":null,
  "swfPrecision":2.525,
  "textureGroupId":{{
    "name":"Default",
    "path":"texturegroups/Default",
  }},
  "type":0,
  "VTile":false,
  "width":{FW},
}}'''


def gen_sprites(only_prefix=None):
    """only_prefix: gera so os sprites cujo nome comeca com o prefixo (ex.: "spr_boss_")."""
    names = []
    sprites = {}
    sprites.update(character_sprites("player", PAL_PLAYER, "player"))
    sprites.update(character_sprites("thug", PAL_THUG, "thug"))
    sprites.update(character_sprites("boss", PAL_BOSS, "boss"))
    sprites.update(character_sprites("runner", PAL_RUNNER, "runner"))
    sprites.update(character_sprites("brute", PAL_BRUTE, "brute"))
    for name, frames in sorted(sprites.items()):
        if only_prefix and not name.startswith(only_prefix):
            continue
        layer_id = guid(name, "layer")
        frame_ids = [guid(name, "frame", str(i)) for i in range(len(frames))]
        for fid, px in zip(frame_ids, frames):
            data = png_bytes(FW, FH, px)
            for rel in (f"sprites/{name}/{fid}.png", f"sprites/{name}/layers/{fid}/{layer_id}.png"):
                full = os.path.join(ROOT, rel)
                os.makedirs(os.path.dirname(full), exist_ok=True)
                with open(full, "wb") as fh:
                    fh.write(data)
        write(f"sprites/{name}/{name}.yy", sprite_yy(name, frame_ids, layer_id))
        names.append(name)
    return names


def script_yy(name):
    return f'''{{
  "$GMScript":"v1",
  "%Name":"{name}",
  "isCompatibility":false,
  "isDnD":false,
  "name":"{name}",
  "parent":{{
    "name":"Scripts",
    "path":"folders/Scripts.yy",
  }},
  "resourceType":"GMScript",
  "resourceVersion":"2.0",
}}'''


def gen_scripts():
    names = sorted(d for d in os.listdir(os.path.join(ROOT, "scripts"))
                   if os.path.isfile(os.path.join(ROOT, "scripts", d, d + ".gml")))
    for n in names:
        write(f"scripts/{n}/{n}.yy", script_yy(n))
    return names


EVENT_TYPES = {"Create": 0, "Destroy": 1, "Alarm": 2, "Step": 3, "Collision": 4, "Keyboard": 5,
               "Mouse": 6, "Other": 7, "Draw": 8, "KeyPress": 9, "KeyRelease": 10, "CleanUp": 12}

# sprite inicial, objeto pai e persistencia de cada objeto
OBJECT_META = {
    "obj_game": dict(persistent=True),
    "obj_actor": dict(),
    "obj_player": dict(parent="obj_actor", sprite="spr_player_idle"),
    "obj_enemy": dict(parent="obj_actor", sprite="spr_thug_idle"),
    "obj_hitbox": dict(),
    "obj_door": dict(),
    "obj_stage": dict(),
}


def ref(kind, name):
    if name is None:
        return "null"
    return f'{{"name":"{name}","path":"{kind}/{name}/{name}.yy",}}'


def object_yy(name, meta, events):
    ev = "\n".join(
        f'    {{"$GMEvent":"v1","%Name":"","collisionObjectId":null,"eventNum":{num},"eventType":{typ},"isDnD":false,"name":"","resourceType":"GMEvent","resourceVersion":"2.0",}},'
        for typ, num in events)
    return f'''{{
  "$GMObject":"",
  "%Name":"{name}",
  "eventList":[
{ev}
  ],
  "managed":true,
  "name":"{name}",
  "overriddenProperties":[],
  "parent":{{
    "name":"Objects",
    "path":"folders/Objects.yy",
  }},
  "parentObjectId":{ref("objects", meta.get("parent"))},
  "persistent":{"true" if meta.get("persistent") else "false"},
  "physicsAngularDamping":0.1,
  "physicsDensity":0.5,
  "physicsFriction":0.2,
  "physicsGroup":1,
  "physicsKinematic":false,
  "physicsLinearDamping":0.1,
  "physicsObject":false,
  "physicsRestitution":0.1,
  "physicsSensor":false,
  "physicsShape":1,
  "physicsShapePoints":[],
  "physicsStartAwake":true,
  "properties":[],
  "resourceType":"GMObject",
  "resourceVersion":"2.0",
  "solid":false,
  "spriteId":{ref("sprites", meta.get("sprite"))},
  "spriteMaskId":null,
  "visible":true,
}}'''


def gen_objects():
    names = sorted(d for d in os.listdir(os.path.join(ROOT, "objects"))
                   if os.path.isdir(os.path.join(ROOT, "objects", d)))
    for n in names:
        events = []
        for fn in sorted(os.listdir(os.path.join(ROOT, "objects", n))):
            if fn.endswith(".gml"):
                kind, num = fn[:-4].rsplit("_", 1)
                events.append((EVENT_TYPES[kind], int(num)))
        events.sort()
        write(f"objects/{n}/{n}.yy", object_yy(n, OBJECT_META.get(n, {}), events))
    return names


def room_yy(name, w, h, instances):
    """instances: lista de (objeto, x, y)."""
    inst_lines, order_lines = [], []
    for i, (obj, x, y) in enumerate(instances):
        iname = "inst_" + guid(name, obj, str(i)).replace("-", "")[:8].upper()
        inst_lines.append(
            f'        {{"$GMRInstance":"v1","%Name":"{iname}","colour":4294967295,"frozen":false,"hasCreationCode":false,"ignore":false,"imageIndex":0,"imageSpeed":1.0,"inheritCode":false,"inheritedItemId":null,"inheritItemSettings":false,"isDnd":false,"name":"{iname}","objectId":{ref("objects", obj)},"properties":[],"resourceType":"GMRInstance","resourceVersion":"2.0","rotation":0.0,"scaleX":1.0,"scaleY":1.0,"x":{float(x)},"y":{float(y)},}},')
        order_lines.append(f'    {{"name":"{iname}","path":"rooms/{name}/{name}.yy",}},')
    insts = ("[\n" + "\n".join(inst_lines) + "\n      ]") if inst_lines else "[]"
    order = ("[\n" + "\n".join(order_lines) + "\n  ]") if order_lines else "[]"

    def view(visible):
        return (f'    {{"hborder":32,"hport":{VIEW_H},"hspeed":-1,"hview":{VIEW_H},"inherit":false,"objectId":null,"vborder":32,'
                f'"visible":{"true" if visible else "false"},"vspeed":-1,"wport":{VIEW_W},"wview":{VIEW_W},"xport":0,"xview":0,"yport":0,"yview":0,}},')

    views = "\n".join(view(i == 0) for i in range(8))
    return f'''{{
  "$GMRoom":"v1",
  "%Name":"{name}",
  "creationCodeFile":"",
  "inheritCode":false,
  "inheritCreationOrder":false,
  "inheritLayers":false,
  "instanceCreationOrder":{order},
  "isDnd":false,
  "layers":[
    {{"$GMRInstanceLayer":"","%Name":"Instances","depth":0,"effectEnabled":true,"effectType":null,"gridX":16,"gridY":16,"hierarchyFrozen":false,"inheritLayerDepth":false,"inheritLayerSettings":false,"inheritSubLayers":true,"inheritVisibility":true,"instances":{insts},"layers":[],"name":"Instances","properties":[],"resourceType":"GMRInstanceLayer","resourceVersion":"2.0","userdefinedDepth":false,"visible":true,}},
    {{"$GMRBackgroundLayer":"","%Name":"Background","animationFPS":15.0,"animationSpeedType":0,"colour":4278190080,"depth":100,"effectEnabled":true,"effectType":null,"gridX":16,"gridY":16,"hierarchyFrozen":false,"hspeed":0.0,"htiled":false,"inheritLayerDepth":false,"inheritLayerSettings":false,"inheritSubLayers":true,"inheritVisibility":true,"layers":[],"name":"Background","properties":[],"resourceType":"GMRBackgroundLayer","resourceVersion":"2.0","spriteId":null,"stretch":false,"userdefinedAnimFPS":false,"userdefinedDepth":false,"visible":true,"vspeed":0.0,"vtiled":false,"x":0,"y":0,}},
  ],
  "name":"{name}",
  "parent":{{
    "name":"Rooms",
    "path":"folders/Rooms.yy",
  }},
  "parentRoom":null,
  "physicsSettings":{{
    "inheritPhysicsSettings":false,
    "PhysicsWorld":false,
    "PhysicsWorldGravityX":0.0,
    "PhysicsWorldGravityY":10.0,
    "PhysicsWorldPixToMetres":0.1,
  }},
  "resourceType":"GMRoom",
  "resourceVersion":"2.0",
  "roomSettings":{{
    "Height":{h},
    "inheritRoomSettings":false,
    "persistent":false,
    "Width":{w},
  }},
  "sequenceId":null,
  "views":[
{views}
  ],
  "viewSettings":{{
    "clearDisplayBuffer":true,
    "clearViewBackground":false,
    "enableViews":true,
    "inheritViewSettings":false,
  }},
  "volume":1.0,
}}'''


VIEW_W, VIEW_H = 480, 270

# A largura de cada room deve bater com "width" da sala em scr_stage.
ROOMS = [
    ("rm_boot", 480, 270, [("obj_game", 0, 0)]),   # primeiro room: so cria o controlador
    ("rm_lobby", 480, 270, []),
    ("rm_sandbox", 720, 270, []),
]


def gen_rooms():
    for name, w, h, inst in ROOMS:
        write(f"rooms/{name}/{name}.yy", room_yy(name, w, h, inst))
    return [r[0] for r in ROOMS]


def gen_yyp(sprites, scripts, objects, rooms):
    res = []
    for kind, names in (("objects", objects), ("rooms", rooms), ("scripts", scripts), ("sprites", sprites)):
        for n in names:
            res.append((n, f"{kind}/{n}/{n}.yy"))
    res.sort(key=lambda r: r[0].lower())
    res_lines = "\n".join(f'    {{"id":{{"name":"{n}","path":"{p}",}},}},' for n, p in res)
    folders = "\n".join(
        f'    {{"$GMFolder":"","%Name":"{f}","folderPath":"folders/{f}.yy","name":"{f}","resourceType":"GMFolder","resourceVersion":"2.0",}},'
        for f in ("Objects", "Rooms", "Scripts", "Sprites"))
    room_nodes = "\n".join(f'    {{"roomId":{{"name":"{r}","path":"rooms/{r}/{r}.yy",}},}},' for r in rooms)
    write(f"{PROJECT}.yyp", f'''{{
  "$GMProject": "",
  "%Name": "{PROJECT}",
  "AudioGroups": [
    {{"$GMAudioGroup":"","%Name":"audiogroup_default","name":"audiogroup_default","resourceType":"GMAudioGroup","resourceVersion":"2.0","targets":-1,}},
  ],
  "configs": {{
    "children": [],
    "name": "Default",
  }},
  "defaultScriptType": 0,
  "Folders": [
{folders}
  ],
  "IncludedFiles": [],
  "isEcma": false,
  "LibraryEmitters": [],
  "MetaData": {{
    "IDEVersion":"2023.200.0.299",
  }},
  "name": "{PROJECT}",
  "resources": [
{res_lines}
  ],
  "resourceType": "GMProject",
  "resourceVersion": "2.0",
  "RoomOrderNodes": [
{room_nodes}
  ],
  "templateType": null,
  "TextureGroups": [
    {{"$GMTextureGroup":"","%Name":"Default","autocrop":true,"border":2,"compressFormat":"bz2","customOptions":"","directory":"","groupParent":null,"isScaled":true,"loadType":"default","mipsToGenerate":0,"name":"Default","resourceType":"GMTextureGroup","resourceVersion":"2.0","targets":-1,}},
  ],
}}''')
    write(f"{PROJECT}.resource_order", '{\n  "FolderOrderSettings": [],\n  "ResourceOrderSettings": [],\n}')


if __name__ == "__main__":
    sprites = gen_sprites()
    scripts = gen_scripts()
    objects = gen_objects()
    rooms = gen_rooms()
    gen_yyp(sprites, scripts, objects, rooms)
    print(f"{len(sprites)} sprites, {len(scripts)} scripts, {len(objects)} objetos, {len(rooms)} rooms")
