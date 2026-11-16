/// Biomas e modulos de sala feitos a mao. A geracao da run so escolhe e conecta
/// estes modulos; nunca inventa geometria.
///
/// Para criar uma sala nova: acrescente uma linha room_combat/room_special no bioma.
/// Papeis (role): "exit" = ultima sala de combate do bioma, "mid" = meio.
/// O trecho inicial do corredor nao usa modulo: e um espaco vazio gerado em
/// run_maps_build (CFG.run.start_width). Por isso as antigas salas "start"
/// passaram a ser salas de meio.

// Room do GameMaker usado como casca por todas as salas da run. A largura real vem
// da definicao da sala (a camera nao depende do tamanho do room).
#macro RM_STAGE rm_sandbox

function rooms_init() {
    global.room_pool = [];
    global.biomes = [
        {
            bid: "sewer",
            name: "ESGOTO",
            palette: {
                sky: make_colour_rgb(5, 12, 16),
                wall: make_colour_rgb(15, 31, 42),
                wall_dark: make_colour_rgb(9, 21, 29),
                floor: make_colour_rgb(28, 48, 56),
                floor_dark: make_colour_rgb(20, 37, 44),
                neon: make_colour_rgb(60, 255, 180),
                accent: make_colour_rgb(255, 210, 63)
            }
        },
        {
            bid: "streets",
            name: "RUAS",
            palette: {
                sky: make_colour_rgb(10, 12, 36),
                wall: make_colour_rgb(26, 30, 68),
                wall_dark: make_colour_rgb(16, 19, 48),
                floor: make_colour_rgb(40, 42, 66),
                floor_dark: make_colour_rgb(30, 32, 52),
                neon: make_colour_rgb(255, 60, 170),
                accent: make_colour_rgb(45, 226, 230)
            }
        },
        {
            bid: "rooftops",
            name: "TOPO DOS PREDIOS",
            palette: {
                sky: make_colour_rgb(14, 10, 44),
                wall: make_colour_rgb(34, 30, 74),
                wall_dark: make_colour_rgb(22, 18, 54),
                floor: make_colour_rgb(52, 48, 84),
                floor_dark: make_colour_rgb(40, 36, 68),
                neon: make_colour_rgb(45, 226, 230),
                accent: make_colour_rgb(255, 60, 170)
            }
        }
    ];

    // ------------------------------------------------------------ ESGOTO (14)
    room_combat("sw_entry", "sewer", "Boca de lobo", "mid", 640, [
        [[440, 205], [540, 240]],
        [[150, 225], [580, 200]]
    ]);
    room_combat("sw_pipes", "sewer", "Tunel dos canos", "mid", 720, [
        [[470, 200], [560, 245]],
        [[160, 215], [620, 195], [650, 240]]
    ]);
    room_combat("sw_channel", "sewer", "Canal largo", "mid", 800, [
        [[450, 195], [540, 225], [620, 250, "runner"]],
        [[170, 210], [700, 235]]
    ]);
    room_combat("sw_grates", "sewer", "Galeria das grades", "mid", 640, [
        [[420, 200], [500, 245], [580, 220]],
        [[160, 230], [600, 205]]
    ]);
    room_combat("sw_pump", "sewer", "Casa de bombas", "mid", 720, [
        [[480, 210], [600, 240]],
        [[150, 200], [660, 230]],
        [[420, 250], [640, 195, "runner"]]
    ]);
    room_combat("sw_exit", "sewer", "Escada de saida", "exit", 720, [
        [[460, 200], [550, 240], [640, 215, "runner"]],
        [[150, 215], [600, 195], [680, 245, "runner"]]
    ]);
    room_combat("sw_sluice", "sewer", "Comporta", "mid", 720, [
        [[450, 210], [530, 245], [610, 200]],
        [[160, 225], [640, 235, "runner"]]
    ]);
    room_combat("sw_overflow", "sewer", "Galeria de transbordo", "mid", 800, [
        [[460, 200], [580, 240, "runner"]],
        [[170, 215], [650, 195], [720, 245]],
        [[420, 230], [700, 210, "runner"]]
    ]);
    room_combat("sw_junction", "sewer", "Cruzamento de tuneis", "mid", 640, [
        [[430, 205], [520, 240], [590, 215]],
        [[150, 200, "runner"], [580, 230]]
    ]);
    room_special("sw_rest", "sewer", "Sala de manutencao", "rest");
    room_special("sw_cache", "sewer", "Deposito esquecido", "reward");
    room_special("sw_cache2", "sewer", "Nicho seco", "reward");
    room_special("sw_shop", "sewer", "Barraca do catador", "shop");
    room_special("sw_event", "sewer", "Valvula emperrada", "event");

    // -------------------------------------------------------------- RUAS (14)
    room_combat("st_entry", "streets", "Beco da saida", "mid", 640, [
        [[430, 205], [520, 240], [600, 215, "runner"]],
        [[150, 225], [590, 200]]
    ]);
    room_combat("st_alley", "streets", "Beco estreito", "mid", 640, [
        [[420, 200], [520, 245, "runner"], [600, 220]],
        [[160, 230], [560, 205], [610, 250, "runner"]]
    ]);
    room_combat("st_market", "streets", "Rua das lojas", "mid", 800, [
        [[450, 195, "brute"], [560, 230], [680, 250]],
        [[160, 210], [720, 200, "runner"], [760, 240]]
    ]);
    room_combat("st_lot", "streets", "Estacionamento", "mid", 800, [
        [[430, 200], [520, 250, "runner"]],
        [[150, 215], [640, 195], [700, 240, "brute"]],
        [[400, 225], [740, 210]]
    ]);
    room_combat("st_arcade", "streets", "Fachada neon", "mid", 720, [
        [[470, 205], [560, 245], [650, 215, "runner"]],
        [[150, 200, "brute"], [620, 235], [690, 200]]
    ]);
    room_combat("st_exit", "streets", "Escada de incendio", "exit", 720, [
        [[450, 200, "brute"], [540, 240], [630, 210], [690, 250, "runner"]],
        [[150, 220], [600, 195], [670, 235, "runner"]]
    ]);
    room_combat("st_crossing", "streets", "Faixa de pedestres", "mid", 720, [
        [[460, 200], [550, 240, "runner"], [640, 215]],
        [[150, 225, "brute"], [620, 195], [680, 245]]
    ]);
    room_combat("st_backlot", "streets", "Patio dos fundos", "mid", 640, [
        [[420, 205], [510, 245], [590, 200, "runner"]],
        [[160, 220], [570, 235, "brute"]]
    ]);
    room_combat("st_subway", "streets", "Entrada do metro", "mid", 800, [
        [[450, 195], [560, 235, "runner"], [690, 215]],
        [[160, 205, "brute"], [720, 240], [760, 200, "runner"]],
        [[420, 250], [700, 220]]
    ]);
    room_special("st_rest", "streets", "Lanchonete 24h", "rest");
    room_special("st_cache", "streets", "Carga abandonada", "reward");
    room_special("st_cache2", "streets", "Vitrine quebrada", "reward");
    room_special("st_shop", "streets", "Banca de rua", "shop");
    room_special("st_event", "streets", "Telefone tocando", "event");

    // -------------------------------------------------- TOPO DOS PREDIOS (13)
    room_combat("rf_entry", "rooftops", "Parapeito", "mid", 640, [
        [[430, 205, "brute"], [520, 240], [600, 215]],
        [[150, 225], [560, 200, "runner"], [610, 245]]
    ]);
    room_combat("rf_antenna", "rooftops", "Campo de antenas", "mid", 720, [
        [[460, 200], [550, 245, "runner"], [640, 215]],
        [[150, 210, "brute"], [600, 195], [650, 240], [700, 215, "runner"]]
    ]);
    room_combat("rf_vents", "rooftops", "Dutos de ar", "mid", 800, [
        [[450, 195, "brute"], [560, 230], [680, 250]],
        [[160, 210], [700, 200], [740, 240, "runner"], [600, 225, "runner"]]
    ]);
    room_combat("rf_billboard", "rooftops", "Outdoor", "mid", 720, [
        [[480, 210], [600, 240, "runner"]],
        [[150, 200, "brute"], [660, 230], [560, 195]],
        [[420, 250], [640, 195, "brute"], [700, 225]]
    ]);
    room_combat("rf_tanks", "rooftops", "Caixas d'agua", "mid", 640, [
        [[420, 200, "brute"], [500, 245], [580, 220, "runner"], [610, 195]],
        [[160, 230], [590, 205, "runner"], [540, 250]]
    ]);
    room_combat("rf_exit", "rooftops", "Heliponto", "exit", 800, [
        [[450, 200, "brute"], [540, 240], [630, 210], [720, 250, "runner"]],
        [[150, 220, "brute"], [600, 195], [670, 235], [760, 215, "runner"]]
    ]);
    room_combat("rf_greenhouse", "rooftops", "Estufa abandonada", "mid", 720, [
        [[460, 205, "brute"], [550, 240], [640, 210, "runner"]],
        [[150, 220], [600, 195, "brute"], [680, 245]]
    ]);
    room_combat("rf_scaffold", "rooftops", "Andaime", "mid", 640, [
        [[420, 200], [500, 245, "runner"], [590, 220, "brute"]],
        [[160, 230, "runner"], [570, 205], [610, 250]]
    ]);
    room_combat("rf_crane", "rooftops", "Guindaste", "mid", 800, [
        [[450, 200, "brute"], [560, 240], [680, 210, "runner"]],
        [[160, 215], [700, 195, "brute"], [750, 240]],
        [[420, 250, "runner"], [720, 220, "brute"]]
    ]);
    room_special("rf_rest", "rooftops", "Abrigo do zelador", "rest");
    room_special("rf_cache", "rooftops", "Caixa de ferramentas", "reward");
    room_special("rf_shop", "rooftops", "Contrabandista", "shop");
    room_special("rf_event", "rooftops", "Painel piscando", "event");

    // Armas largadas em algumas salas de combate
    room_pickup("sw_pipes", "w_pipe", 300, 232);
    room_pickup("sw_pump", "w_pipe", 260, 205);
    room_pickup("st_alley", "w_pipe", 280, 240);
    room_pickup("st_lot", "w_bat", 320, 236);
    room_pickup("rf_vents", "w_pipe", 300, 210);
    room_pickup("rf_billboard", "w_bat", 290, 238);

    // ------------------------------------------------------------------ CHEFE
    // Arena final: a luta comeca ao cruzar o gatilho; vencer o chefe encerra a run.
    stage_define({
        sid: "boss_arena",
        name: "Arena final",
        biome: "boss",
        kind: "boss",
        role: "boss",
        room_asset: RM_STAGE,
        width: 640,
        floor_top: 178,
        floor_bottom: 258,
        player_spawn: { x: 60, y: 222 },
        doors: [],
        encounter: {
            trigger_x: 170,
            lock_x1: 0,
            lock_x2: 640,
            waves: [
                [{ type: "boss", x: 500, y: 220 }]
            ]
        },
        enemies: [],
        decor: 99,
        palette: {
            sky: make_colour_rgb(10, 6, 30),
            wall: make_colour_rgb(36, 20, 66),
            wall_dark: make_colour_rgb(22, 12, 44),
            floor: make_colour_rgb(50, 36, 82),
            floor_dark: make_colour_rgb(38, 26, 64),
            neon: make_colour_rgb(255, 60, 170),
            accent: make_colour_rgb(255, 210, 63)
        }
    });
}

function biome_get(_bid) {
    for (var _i = 0; _i < array_length(global.biomes); _i++) {
        if (global.biomes[_i].bid == _bid) return global.biomes[_i];
    }
    return undefined;
}

/// Registra um modulo no conjunto de salas, completando os campos comuns.
function room_module_add(_def) {
    _def.room_asset = RM_STAGE;
    _def.floor_top = 178;
    _def.floor_bottom = 258;
    _def.player_spawn = { x: 60, y: 222 };  // entrada pela esquerda
    _def.doors = [];                         // as saidas vem das conexoes da rota
    _def.enemies = [];
    _def.pickups = [];                       // armas no chao (room_pickup)
    _def.palette = biome_get(_def.biome).palette;
    _def.decor = array_length(global.room_pool) + 1; // semente fixa do cenario do modulo
    stage_define(_def);
    array_push(global.room_pool, _def.sid);
}

/// Sala de combate. _waves: lista de ondas; cada inimigo e [x, y] ou [x, y, tipo].
/// As posicoes devem ficar dentro da arena (lock_x1..largura).
function room_combat(_sid, _bid, _name, _role, _width, _waves) {
    var _lock_x1 = (_width >= 640) ? 110 : 0;
    var _built = [];
    for (var _w = 0; _w < array_length(_waves); _w++) {
        var _wave = [];
        for (var _i = 0; _i < array_length(_waves[_w]); _i++) {
            var _e = _waves[_w][_i];
            array_push(_wave, {
                type: (array_length(_e) > 2) ? _e[2] : "thug",
                x: _e[0],
                y: _e[1]
            });
        }
        array_push(_built, _wave);
    }
    room_module_add({
        sid: _sid,
        name: _name,
        biome: _bid,
        kind: "combat",
        role: _role,
        width: _width,
        encounter: {
            trigger_x: _lock_x1 + 100,
            lock_x1: _lock_x1,
            lock_x2: _width,
            waves: _built
        }
    });
}

function room_pickup(_sid, _wid, _x, _y) {
    array_push(stage_get(_sid).pickups, { wid: _wid, x: _x, y: _y });
}

/// Sala sem combate (descanso, recompensa, loja, evento).
function room_special(_sid, _bid, _name, _kind) {
    room_module_add({
        sid: _sid,
        name: _name,
        biome: _bid,
        kind: _kind,
        role: "mid",
        width: VIEW_W,
        black_background: true
    });
}
