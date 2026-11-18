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
            { x: 458, kind: "run_start", label: "SAIR PARA A RUA (iniciar run)", requires_clear: false }
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
    fx_clear();
    // RM_STAGE e apenas a casca; seus limites reais acompanham o mapa ou a sala.
    // Sem isso, o mapa (maior que o room do editor) pode parar de desenhar cedo.
    room_width = _def.width;
    room_height = variable_struct_exists(_def, "height") ? _def.height : VIEW_H;
    global.stage_rt = {
        lock_active: false,   // arena travada durante uma horda
        lock_x1: 0,
        lock_x2: _def.width,
        enc_state: (_def.kind == "main_map") ? ENC.NONE : (stage_has_encounter(_def) ? ENC.WAITING : ENC.NONE),
        enc_wave: 0,
        enc_timer: 0,
        go_timer: 0,
        map_index: (_def.kind == "main_map") ? _def.map_index : -1,
        chunk_index: -1,      // mapas 2D: chunk do combate em andamento
        corridor: -1,         // mapas 2D: corredor em que o jogador esta
        title: _def.name,
        subtitle: "",
        banner_timer: 0,
        leaving: false        // ja saindo pela direita da arena do chefe
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
    if (_def.kind == "main_map") {
        // o corredor do jogador define limites, camera e chao; um retorno que
        // caia fora dos corredores volta ao inicio do mapa
        var _spawn_map = global.run.maps[_def.map_index];
        var _cor = level_corridor_at(_spawn_map, _spawn_x, _spawn_y);
        if (_cor < 0) {
            _spawn_x = _def.player_spawn.x;
            _spawn_y = _def.player_spawn.y;
            _cor = level_corridor_at(_spawn_map, _spawn_x, _spawn_y);
        }
        stage_set_corridor(_cor);
    }
    var _player = instance_create_depth(_spawn_x, _spawn_y, 0, obj_player);
    _player.facing = _spawn_facing;
    if (_has_return) global.run.return_context = undefined;

    if (_def.kind == "main_map") {
        var _map = global.run.maps[_def.map_index];
        for (var _i = 0; _i < array_length(_map.chunks); _i++) {
            var _ch = _map.chunks[_i];
            // combate interrompido (run carregada ou sala reconstruida) volta a esperar
            if (_ch.state == "active") _ch.state = "pending";
            // sala no proprio corredor: banca, bau, banco ou painel do desafio
            if (chunk_is_room(_ch.type)) run_level_spawn_room(_ch);
            // bau de horda vencida que ainda nao foi aberto
            if (_ch.type == "horde" && _ch.state == "cleared") run_level_spawn_reward(_map, _ch);
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

        // quebraveis e perigos do corredor (os destruidos nao voltam)
        for (var _i = 0; _i < array_length(_map.props); _i++) {
            var _prop = _map.props[_i];
            if (!_prop.alive) continue;
            instance_create_depth(_prop.x, _prop.y, 0, obj_prop, {
                kind: _prop.kind,
                map_index: _def.map_index,
                prop_index: _i
            });
        }

        var _map_count = array_length(global.run.maps);
        global.stage_rt.title = _def.name + " " + string(_def.map_index + 1) + "/" + string(_map_count);
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

        interact_spawn_for_stage(_def);
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
        return array_length(_map.chunks[global.stage_rt.chunk_index].waves);
    }
    return array_length(global.stage.encounter.waves);
}

function encounter_spawn_wave(_index) {
    var _wave;
    var _ch = undefined;
    if (global.stage.kind == "main_map") {
        _ch = global.run.maps[global.stage_rt.map_index].chunks[global.stage_rt.chunk_index];
        _wave = _ch.waves[_index];
    } else {
        _wave = global.stage.encounter.waves[_index];
    }
    var _n = min(array_length(_wave), CFG.encounter.max_wave_size);
    // nos mapas os inimigos comuns entram por fora da camera, nunca de dentro de
    // uma parede do corredor; o chefe nasce no lugar dele
    var _offscreen = !is_undefined(_ch) && _ch.type != "boss";
    var _lo = 0;
    var _hi = 0;
    if (_offscreen) {
        var _cor = stage_corridor();
        var _reach = CFG.encounter.offscreen_margin + CFG.encounter.offscreen_jitter;
        _lo = max(_cor.x1 + CFG.level.spawn_wall_margin, _ch.x1 - _reach);
        _hi = min(_cor.x2 - CFG.level.spawn_wall_margin, _ch.x2 + _reach);
    }
    for (var _i = 0; _i < _n; _i++) {
        var _e = _wave[_i];
        var _elite = variable_struct_exists(_e, "elite") && _e.elite;
        if (_offscreen) {
            // tipo e elite da onda; o ponto de entrada e sorteado fora da camera
            enemy_spawn_offscreen(_e.type, _elite, _lo, _hi);
        } else {
            instance_create_depth(_e.x, _e.y, 0, obj_enemy, { enemy_type: _e.type, elite: _elite });
        }
    }
}

/// Cria um inimigo num ponto aleatorio fora da camera: lado sorteado, distancia
/// alem da borda sorteada (offscreen_margin + ate offscreen_jitter) e
/// profundidade sorteada. Ele caminha ate um ponto aleatorio dentro da tela, do
/// lado por onde entrou, e so entao comeca a agir (ES.SPAWN em scr_enemy).
/// _lo, _hi: limites fisicos do lugar; se o lado sorteado cair fora, usa o outro.
function enemy_spawn_offscreen(_type, _elite, _lo, _hi) {
    var _E = CFG.encounter;
    var _s = global.stage;
    var _rt = global.stage_rt;
    // com a arena travada a camera vai para o destino de cam_target_x
    var _cam_l = cam_target_x();
    var _cam_r = _cam_l + VIEW_W;

    var _side = irandom(1); // 0 = esquerda, 1 = direita
    var _off = _E.offscreen_margin + irandom(_E.offscreen_jitter);
    var _x = (_side == 0) ? _cam_l - _off : _cam_r + _off;
    if (_x < _lo || _x > _hi) {
        _side = 1 - _side;
        _x = (_side == 0) ? _cam_l - _off : _cam_r + _off;
    }
    // sem espaco dos dois lados (corredor curto): entra pela borda possivel
    _x = clamp(_x, _lo, _hi);
    var _y = irandom_range(stage_floor_top() + 6, stage_floor_bottom() - 6);

    // destino aleatorio dentro da tela, na parte do lado de entrada
    var _reach = VIEW_W * _E.enter_reach;
    var _enter = (_side == 0)
        ? irandom_range(_cam_l + _E.enter_inset, _cam_l + _reach)
        : irandom_range(_cam_r - _reach, _cam_r - _E.enter_inset);
    var _x1 = _rt.lock_active ? _rt.lock_x1 : 0;
    var _x2 = _rt.lock_active ? _rt.lock_x2 : _s.width;
    _enter = clamp(_enter, _x1 + _E.enter_inset, _x2 - _E.enter_inset);

    return instance_create_depth(_x, _y, 0, obj_enemy, {
        enemy_type: _type,
        elite: _elite,
        entering: true,
        enter_x: _enter
    });
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

/// Encontros dos mapas 2D. Cada chunk de combate (combate, saida, horda, chefe)
/// dispara quando o jogador esta dentro dele, entre trigger_x1 e trigger_x2, em
/// qualquer direcao: os ramos podem ser percorridos da direita para a esquerda.
function encounter_update_map() {
    var _rt = global.stage_rt;
    if (_rt.go_timer > 0) _rt.go_timer--;
    var _map = global.run.maps[_rt.map_index];

    // exploracao e saida do bioma (nao interferem nos encontros abaixo)
    var _pl = instance_find(obj_player, 0);
    if (_pl != noone) {
        run_map_update_discovery(_rt.map_index, _pl.x, _pl.y);
        var _boss = _map.chunks[_map.boss];
        if (!_rt.leaving && run_map_exit_open() && _rt.corridor == _boss.corridor
            && _pl.x >= _boss.x2 + CFG.run.boss_exit_trigger) {
            _rt.leaving = true;
            run_map_leave();
            return;
        }
    }

    if (!_rt.lock_active) {
        if (_pl == noone || _pl.state == PS.CLIMB) return;
        var _cx = level_chunk_at(_map, _pl.x, _pl.y);
        if (_cx < 0) return;
        var _ch = _map.chunks[_cx];
        if (_ch.state != "pending" || _pl.x < _ch.trigger_x1 || _pl.x > _ch.trigger_x2) return;
        _rt.chunk_index = _cx;
        _rt.enc_wave = _ch.wave_index;
        _rt.enc_timer = 0;
        _rt.enc_state = ENC.ACTIVE;
        cam_lock(_ch.lock_x1, _ch.lock_x2);
        run_map_mark_chunk(_rt.map_index, _cx, "active", _rt.enc_wave);
        encounter_spawn_wave(_rt.enc_wave);
        return;
    }

    if (_rt.enc_state == ENC.ACTIVE && enemies_alive() == 0) {
        if (_rt.enc_wave + 1 < encounter_wave_count()) {
            _rt.enc_timer = CFG.encounter.wave_delay;
            _rt.enc_state = ENC.BETWEEN;
        } else {
            var _done = _map.chunks[_rt.chunk_index];
            cam_unlock();
            _rt.enc_state = ENC.CLEARED;
            _rt.go_timer = CFG.encounter.go_frames;
            run_map_mark_chunk(_rt.map_index, _rt.chunk_index, "cleared", _rt.enc_wave);
            global.run.sections_cleared += 1;
            // o chefe nao leva mais direto ao proximo bioma: a saida a direita
            // fica liberada e o jogador precisa atravessa-la (run_map_leave)
            if (_done.type == "boss") run_map_boss_cleared();
            // horda vencida: o bau aparece no fundo do beco
            if (_done.type == "horde") run_level_spawn_reward(_map, _done);
            run_checkpoint(); // grava o progresso no slot
        }
    } else if (_rt.enc_state == ENC.BETWEEN) {
        _rt.enc_timer--;
        if (_rt.enc_timer <= 0) {
            _rt.enc_wave++;
            run_map_mark_chunk(_rt.map_index, _rt.chunk_index, "active", _rt.enc_wave);
            encounter_spawn_wave(_rt.enc_wave);
            _rt.enc_state = ENC.ACTIVE;
        }
    }
}

/// Limites horizontais validos para atores: arena travada, corredor do jogador
/// (mapas 2D, parando na frente das paredes de fim de corredor) ou sala inteira.
function stage_x1() {
    var _rt = global.stage_rt;
    var _c = stage_corridor();
    var _wall = 0;
    if (!is_undefined(_c)) _wall = _c.x1 + (_c.cap_left ? CFG.level.cap_margin : 0);
    if (_rt.lock_active) return max(_rt.lock_x1, _wall) + CFG.stage.edge_margin;
    return _wall + CFG.stage.edge_margin;
}

function stage_x2() {
    var _rt = global.stage_rt;
    var _c = stage_corridor();
    var _wall = global.stage.width;
    if (!is_undefined(_c)) _wall = _c.x2 - (_c.cap_right ? CFG.level.cap_margin : 0);
    if (_rt.lock_active) return min(_rt.lock_x2, _wall) - CFG.stage.edge_margin;
    // chefe derrotado: o jogador pode sair da tela pela direita da arena
    if (!is_undefined(_c) && _c.has_boss && run_map_exit_open()) return _c.x2 + CFG.run.boss_exit_walkout;
    return _wall - CFG.stage.edge_margin;
}
