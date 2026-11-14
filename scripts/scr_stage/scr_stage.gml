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
    // RM_STAGE e apenas a casca do mapa; seus limites reais acompanham o trecho.
    // Sem isso, o corredor (maior que o room do editor) pode parar de desenhar cedo.
    room_width = _def.width;
    room_height = VIEW_H;
    global.stage_rt = {
        lock_active: false,   // arena travada durante uma horda
        lock_x1: 0,
        lock_x2: _def.width,
        enc_state: (_def.kind == "main_map") ? ENC.NONE : (stage_has_encounter(_def) ? ENC.WAITING : ENC.NONE),
        enc_wave: 0,
        enc_timer: 0,
        go_timer: 0,
        map_index: (_def.kind == "main_map") ? _def.map_index : -1,
        section_index: -1,
        title: _def.name,
        subtitle: "",
        banner_timer: 0
    };

    // A camada Background das salas tem depth 100 e e opaca; 99 desenha o
    // cenario por cima dela, mantendo os atores (depth 0) na frente.
    instance_create_depth(0, 0, 99, obj_stage);
    var _spawn_x = _def.player_spawn.x;
    var _spawn_y = _def.player_spawn.y;
    var _spawn_facing = 1;
    var _has_return = _def.kind == "main_map" && !is_undefined(global.run.return_context)
        && global.run.return_context.stage_sid == _def.sid;
    if (_has_return) {
        _spawn_x = global.run.return_context.x;
        _spawn_y = global.run.return_context.y;
        _spawn_facing = global.run.return_context.facing;
    }
    var _player = instance_create_depth(_spawn_x, _spawn_y, 0, obj_player);
    _player.facing = _spawn_facing;
    if (_has_return) global.run.return_context = undefined;

    if (_def.kind == "main_map") {
        var _map = global.run.maps[_def.map_index];
        for (var _i = 0; _i < array_length(_map.specials); _i++) {
            var _special = _map.specials[_i];
            instance_create_depth(_special.x, _def.floor_top, 0, obj_door, {
                kind: "special",
                label: _special.label,
                requires_clear: _special.requires_clear,
                room_kind: _special.room_kind,
                target_sid: _special.target_sid
            });
        }

        for (var _i = 0; _i < array_length(_map.pickups); _i++) {
            var _pickup = _map.pickups[_i];
            if (!variable_struct_exists(_map.pickups_taken, _pickup.key)) {
                instance_create_depth(_pickup.x, _pickup.y, 0, obj_interact, {
                    kind: "weapon",
                    wid: _pickup.wid,
                    durability: weapon_def(_pickup.wid).durability,
                    persistent_key: _pickup.key,
                    map_index: _def.map_index
                });
            }
        }
        for (var _i = 0; _i < array_length(_map.ground_weapons); _i++) {
            var _drop = _map.ground_weapons[_i];
            instance_create_depth(_drop.x, _drop.y, 0, obj_interact, {
                kind: "weapon",
                wid: _drop.wid,
                durability: _drop.durability,
                map_index: _def.map_index,
                drop_key: _drop.key
            });
        }

        var _map_count = array_length(global.run.maps);
        global.stage_rt.title = _def.name + " " + string(_def.map_index + 1) + "/" + string(_map_count);
        global.stage_rt.subtitle = "CORREDOR PRINCIPAL";
        global.stage_rt.banner_timer = CFG.run.banner_frames;
    } else {
        for (var _i = 0; _i < array_length(_def.doors); _i++) {
            var _d = _def.doors[_i];
            var _door_room_kind = variable_struct_exists(_d, "room_kind") ? _d.room_kind : "";
            var _door_target_sid = variable_struct_exists(_d, "target_sid") ? _d.target_sid : "";
            instance_create_depth(_d.x, _def.floor_top, 0, obj_door, {
                kind: _d.kind,
                label: _d.label,
                requires_clear: _d.requires_clear,
                room_kind: _door_room_kind,
                target_sid: _door_target_sid
            });
        }

        if (_def.kind == "rest" || _def.kind == "reward" || _def.kind == "shop" || _def.kind == "event") {
            var _special_state = run_special_state(_def.sid);
            interact_spawn_for_stage(_def, _special_state.seed, _special_state);
            instance_create_depth(_def.width - 52, _def.floor_top, 0, obj_door, {
                kind: "return",
                label: "VOLTAR",
                requires_clear: false
            });
            global.stage_rt.title = string_upper(_def.name);
            global.stage_rt.subtitle = "";
        } else {
            interact_spawn_for_stage(_def, 0);
        }
    }

    if (_def.kind != "main_map") {
        for (var _i = 0; _i < array_length(_def.enemies); _i++) {
            var _e = _def.enemies[_i];
            instance_create_depth(_e.x, _e.y, 0, obj_enemy, { enemy_type: _e.type });
        }
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
    if (is_undefined(global.stage_rt)) return true;
    if (global.stage.kind == "main_map") return !global.stage_rt.lock_active;
    var _s = global.stage_rt.enc_state;
    return _s == ENC.NONE || _s == ENC.CLEARED;
}

function encounter_wave_count() {
    if (global.stage.kind == "main_map") {
        var _map = global.run.maps[global.stage_rt.map_index];
        var _section = _map.sections[global.stage_rt.section_index];
        return array_length(_section.waves);
    }
    return array_length(global.stage.encounter.waves);
}

function encounter_spawn_wave(_index) {
    var _wave;
    if (global.stage.kind == "main_map") {
        var _map = global.run.maps[global.stage_rt.map_index];
        var _section = _map.sections[global.stage_rt.section_index];
        _wave = _section.waves[_index];
    } else {
        _wave = global.stage.encounter.waves[_index];
    }
    var _n = min(array_length(_wave), CFG.encounter.max_wave_size);
    for (var _i = 0; _i < _n; _i++) {
        var _e = _wave[_i];
        instance_create_depth(_e.x, _e.y, 0, obj_enemy, { enemy_type: _e.type });
    }
}

/// Chamado todo frame pelo obj_game.
function encounter_update() {
    if (is_undefined(global.stage)) return;
    if (global.stage.kind == "main_map") {
        encounter_update_map();
        return;
    }
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

function encounter_update_map() {
    var _rt = global.stage_rt;
    if (_rt.go_timer > 0) _rt.go_timer--;

    if (!_rt.lock_active) {
        var _map = global.run.maps[_rt.map_index];
        var _player = instance_find(obj_player, 0);
        if (_player == noone) return;

        // Dispara apenas o primeiro setor ainda pendente cuja entrada foi cruzada.
        for (var _i = 0; _i < array_length(_map.sections); _i++) {
            var _section = _map.sections[_i];
            if (_section.state != "pending" || _player.x < _section.trigger_x) continue;
            _rt.section_index = _i;
            _rt.enc_wave = _section.wave_index;
            _rt.enc_timer = 0;
            _rt.enc_state = ENC.ACTIVE;
            cam_lock(_section.lock_x1, _section.lock_x2);
            run_map_mark_section(_rt.map_index, _i, "active", _rt.enc_wave);
            encounter_spawn_wave(_rt.enc_wave);
            return;
        }
        return;
    }

    if (_rt.enc_state == ENC.ACTIVE && enemies_alive() == 0) {
        if (_rt.enc_wave + 1 < encounter_wave_count()) {
            _rt.enc_timer = CFG.encounter.wave_delay;
            _rt.enc_state = ENC.BETWEEN;
        } else {
            var _map = global.run.maps[_rt.map_index];
            var _section = _map.sections[_rt.section_index];
            cam_unlock();
            _rt.enc_state = ENC.CLEARED;
            _rt.go_timer = CFG.encounter.go_frames;
            run_map_mark_section(_rt.map_index, _rt.section_index, "cleared", _rt.enc_wave);
            if (_section.kind == "boss") run_map_boss_cleared();
        }
    } else if (_rt.enc_state == ENC.BETWEEN) {
        _rt.enc_timer--;
        if (_rt.enc_timer <= 0) {
            _rt.enc_wave++;
            run_map_mark_section(_rt.map_index, _rt.section_index, "active", _rt.enc_wave);
            encounter_spawn_wave(_rt.enc_wave);
            _rt.enc_state = ENC.ACTIVE;
        }
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
