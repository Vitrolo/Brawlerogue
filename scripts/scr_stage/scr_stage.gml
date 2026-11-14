/// Salas ("stages") descritas por dados. Cada definicao aponta para um room do
/// GameMaker (room_asset) e declara chao, spawns, portas e inimigos.
/// O obj_game monta a sala no Room Start chamando stage_build().

function stage_define(_def) {
    global.stages[$ _def.sid] = _def;
}

function stage_get(_sid) {
    return global.stages[$ _sid];
}

function stage_defs_init() {
    global.stages = {};
    global.stage_next_id = "lobby";
    global.stage = undefined;
    global.stage_rt = undefined;

    stage_define({
        sid: "lobby",
        name: "LOBBY",
        biome: "lobby",
        kind: "lobby",
        room_asset: rm_lobby,
        width: 480,
        floor_top: 178,      // faixa de profundidade em que os pes podem andar
        floor_bottom: 258,
        player_spawn: { x: 90, y: 222 },
        doors: [
            { x: 380, kind: "run_start", label: "INICIAR RUN", requires_clear: false }
        ],
        enemies: [],
        decor: 0,
        palette: {
            sky: make_colour_rgb(8, 10, 28),
            wall: make_colour_rgb(20, 28, 58),
            wall_dark: make_colour_rgb(13, 18, 42),
            floor: make_colour_rgb(35, 42, 77),
            floor_dark: make_colour_rgb(27, 33, 62),
            neon: make_colour_rgb(45, 226, 230),
            accent: make_colour_rgb(255, 60, 170)
        }
    });

    rooms_init();
}

function stage_goto(_sid) {
    var _def = stage_get(_sid);
    global.stage_next_id = _sid;
    if (room == _def.room_asset) {
        room_restart();
    } else {
        room_goto(_def.room_asset);
    }
}

/// Monta a sala atual a partir da definicao.
function stage_build() {
    var _def = stage_get(global.stage_next_id);
    global.stage = _def;
    global.stage_rt = {
        lock_active: false,   // arena travada durante uma horda
        lock_x1: 0,
        lock_x2: _def.width,
        enc_state: stage_has_encounter(_def) ? ENC.WAITING : ENC.NONE,
        enc_wave: 0,
        enc_timer: 0,
        go_timer: 0,
        title: _def.name,
        subtitle: "",
        banner_timer: 0
    };

    // A camada Background das salas tem depth 100 e e opaca; 99 desenha o
    // cenario por cima dela, mantendo os atores (depth 0) na frente.
    instance_create_depth(0, 0, 99, obj_stage);
    instance_create_depth(_def.player_spawn.x, _def.player_spawn.y, 0, obj_player);

    for (var _i = 0; _i < array_length(_def.doors); _i++) {
        var _d = _def.doors[_i];
        instance_create_depth(_d.x, _def.floor_top, 0, obj_door, {
            kind: _d.kind,
            label: _d.label,
            requires_clear: _d.requires_clear
        });
    }

    for (var _i = 0; _i < array_length(_def.enemies); _i++) {
        var _e = _def.enemies[_i];
        instance_create_depth(_e.x, _e.y, 0, obj_enemy, { enemy_type: _e.type });
    }

    // Saidas da rota: uma porta por conexao valida do no atual.
    var _node = run_current_node();
    interact_spawn_for_stage(_def, is_undefined(_node) ? 0 : _node.seed);
    if (!is_undefined(_node) && _node.sid == _def.sid) {
        var _n = array_length(_node.next);
        for (var _i = 0; _i < _n; _i++) {
            var _t = run_node(_node.next[_i]);
            instance_create_depth(_def.width - 50 - (_n - 1 - _i) * CFG.run.door_spacing, _def.floor_top, 0, obj_door, {
                kind: "route",
                label: route_door_label(_node, _t),
                requires_clear: true,
                target_nid: _t.nid,
                room_kind: _t.kind
            });
        }
        var _rt = global.stage_rt;
        if (_node.kind == "boss") {
            _rt.title = "CHEFE";
        } else {
            _rt.title = run_biome_name(_node.biome_index) + " " + string(_node.layer + 1) + "/" + string(max(2, CFG.run.layers_per_biome)) + " - " + room_kind_label(_node.kind);
        }
        _rt.subtitle = _def.name;
        if (_node.layer == 0) _rt.banner_timer = CFG.run.banner_frames; // entrou em um bioma novo
    }

    cam_room_start();
}

// --------------------------------------------------------------- encontros

enum ENC {
    NONE,     // sala sem horda
    WAITING,  // jogador ainda nao cruzou o gatilho
    ACTIVE,   // onda em combate, arena travada
    BETWEEN,  // pausa curta antes da proxima onda
    CLEARED   // horda derrotada, saidas liberadas
}

function stage_has_encounter(_def) {
    return variable_struct_exists(_def, "encounter") && is_struct(_def.encounter);
}

/// Saidas ficam abertas em salas sem horda ou com a horda derrotada.
function stage_exits_open() {
    var _s = global.stage_rt.enc_state;
    return _s == ENC.NONE || _s == ENC.CLEARED;
}

function encounter_wave_count() {
    return array_length(global.stage.encounter.waves);
}

function encounter_spawn_wave(_index) {
    var _wave = global.stage.encounter.waves[_index];
    var _n = min(array_length(_wave), CFG.encounter.max_wave_size);
    for (var _i = 0; _i < _n; _i++) {
        var _e = _wave[_i];
        instance_create_depth(_e.x, _e.y, 0, obj_enemy, { enemy_type: _e.type });
    }
}

/// Chamado todo frame pelo obj_game.
function encounter_update() {
    if (is_undefined(global.stage)) return;
    var _rt = global.stage_rt;
    if (_rt.go_timer > 0) _rt.go_timer--;

    switch (_rt.enc_state) {
        case ENC.WAITING:
            var _enc = global.stage.encounter;
            var _p = instance_find(obj_player, 0);
            if (_p != noone && _p.x >= _enc.trigger_x) {
                cam_lock(_enc.lock_x1, _enc.lock_x2);
                _rt.enc_wave = 0;
                encounter_spawn_wave(0);
                _rt.enc_state = ENC.ACTIVE;
            }
            break;

        case ENC.ACTIVE:
            if (enemies_alive() == 0) {
                if (_rt.enc_wave + 1 < encounter_wave_count()) {
                    _rt.enc_timer = CFG.encounter.wave_delay;
                    _rt.enc_state = ENC.BETWEEN;
                } else {
                    cam_unlock();
                    _rt.enc_state = ENC.CLEARED;
                    if (global.stage.kind == "boss") {
                        game_victory(); // derrotar o chefe encerra a run
                    } else {
                        _rt.go_timer = CFG.encounter.go_frames;
                    }
                }
            }
            break;

        case ENC.BETWEEN:
            _rt.enc_timer--;
            if (_rt.enc_timer <= 0) {
                _rt.enc_wave++;
                encounter_spawn_wave(_rt.enc_wave);
                _rt.enc_state = ENC.ACTIVE;
            }
            break;
    }
}

/// Limites horizontais validos para atores (arena travada ou sala inteira).
function stage_x1() {
    var _rt = global.stage_rt;
    return (_rt.lock_active ? _rt.lock_x1 : 0) + CFG.stage.edge_margin;
}

function stage_x2() {
    var _rt = global.stage_rt;
    return (_rt.lock_active ? _rt.lock_x2 : global.stage.width) - CFG.stage.edge_margin;
}
