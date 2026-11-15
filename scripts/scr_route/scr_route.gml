/// Rota da run: um grafo em camadas gerado a partir da seed.
/// Cada bioma tem CFG.run.layers_per_biome camadas: a primeira e a ultima tem uma
/// sala de combate (entrada e saida do bioma); as do meio oferecem 2 a 3 opcoes.
/// As conexoes so avancam, entao nao existem ciclos nem becos sem saida.

function room_kind_label(_kind) {
    switch (_kind) {
        case "combat": return "COMBATE";
        case "rest":   return "DESCANSO";
        case "reward": return "RECOMPENSA";
        case "shop":   return "LOJA";
        case "event":  return "EVENTO";
        case "challenge": return "DESAFIO";
        case "boss":   return "CHEFE";
    }
    return "";
}

function room_kind_colour(_kind) {
    switch (_kind) {
        case "combat": return make_colour_rgb(255, 90, 90);
        case "rest":   return make_colour_rgb(90, 230, 120);
        case "reward": return make_colour_rgb(255, 210, 63);
        case "shop":   return make_colour_rgb(45, 226, 230);
        case "event":  return make_colour_rgb(255, 60, 170);
        case "challenge": return make_colour_rgb(255, 60, 170);
        case "boss":   return make_colour_rgb(255, 60, 60);
    }
    return make_colour_rgb(255, 210, 63);
}

/// Sorteia um modulo ainda nao usado do bioma, com o tipo e papel pedidos.
function room_pick(_bid, _kind, _role, _used) {
    var _c = [];
    for (var _i = 0; _i < array_length(global.room_pool); _i++) {
        var _sid = global.room_pool[_i];
        var _def = stage_get(_sid);
        if (_def.biome == _bid && _def.kind == _kind && _def.role == _role && !variable_struct_exists(_used, _sid)) {
            array_push(_c, _sid);
        }
    }
    if (array_length(_c) == 0) return undefined;
    return _c[irandom(array_length(_c) - 1)];
}

/// Como room_pick, mas troca de tipo ou repete um modulo se o conjunto acabou.
function room_pick_fallback(_bid, _kind, _role, _used) {
    var _sid = room_pick(_bid, _kind, _role, _used);
    if (!is_undefined(_sid)) return _sid;
    if (_role == "mid") {
        var _order = ["combat", "reward", "rest", "event", "shop"];
        for (var _i = 0; _i < array_length(_order); _i++) {
            _sid = room_pick(_bid, _order[_i], _role, _used);
            if (!is_undefined(_sid)) return _sid;
        }
    }
    _sid = room_pick(_bid, "combat", _role, {});
    if (!is_undefined(_sid)) return _sid;
    return room_pick(_bid, "combat", "mid", {});
}

function run_pick_special_kind() {
    var _list = CFG.run.special_kinds;
    var _total = 0;
    for (var _i = 0; _i < array_length(_list); _i++) _total += _list[_i][1];
    var _r = random(_total);
    for (var _i = 0; _i < array_length(_list); _i++) {
        _r -= _list[_i][1];
        if (_r < 0) return _list[_i][0];
    }
    return _list[0][0];
}

function run_graph_link(_g, _from, _to) {
    var _next = _g.nodes[_from].next;
    if (!array_contains(_next, _to)) array_push(_next, _to);
}

/// Liga a camada anterior a nova: toda sala ganha saida e toda sala ganha entrada.
function run_graph_connect(_g, _prev, _layer) {
    var _np = array_length(_prev);
    var _nl = array_length(_layer);
    if (_np == 0 || _nl == 0) return;

    for (var _j = 0; _j < _np; _j++) {
        if (_np == 1 || _nl == 1) {
            for (var _k = 0; _k < _nl; _k++) run_graph_link(_g, _prev[_j], _layer[_k]);
        } else {
            var _t = floor(_j * _nl / _np);
            run_graph_link(_g, _prev[_j], _layer[_t]);
            if (_t + 1 < _nl && random(1) < CFG.run.extra_path_chance) {
                run_graph_link(_g, _prev[_j], _layer[_t + 1]);
            }
        }
    }

    for (var _k = 0; _k < _nl; _k++) {
        var _has_entry = false;
        for (var _j = 0; _j < _np; _j++) {
            if (array_contains(_g.nodes[_prev[_j]].next, _layer[_k])) {
                _has_entry = true;
                break;
            }
        }
        if (!_has_entry) run_graph_link(_g, _prev[min(_np - 1, floor(_k * _np / _nl))], _layer[_k]);
    }
}

/// _linear = true gera uma rota sem ramificacoes (usada so se a validacao falhar).
function run_graph_generate(_linear) {
    var _R = CFG.run;
    var _layers = max(2, _R.layers_per_biome);
    var _g = { nodes: [], start: 0, boss: -1, current: -1 };
    var _used = {};
    var _prev = [];
    var _nb = array_length(global.biomes);

    for (var _b = 0; _b < _nb; _b++) {
        var _bid = global.biomes[_b].bid;
        for (var _l = 0; _l < _layers; _l++) {
            var _role = "mid";
            var _kinds = ["combat"];
            if (_l == 0) {
                _role = "start";
            } else if (_l == _layers - 1) {
                _role = "exit";
            } else if (!_linear) {
                // sempre ha pelo menos um combate e uma sala especial para escolher
                var _n = irandom_range(_R.branch_min, _R.branch_max);
                _kinds = ["combat", run_pick_special_kind()];
                while (array_length(_kinds) < _n) {
                    array_push(_kinds, (random(1) < _R.extra_combat_chance) ? "combat" : run_pick_special_kind());
                }
                _kinds = array_shuffle(_kinds);
            }

            var _layer = [];
            for (var _k = 0; _k < array_length(_kinds); _k++) {
                var _sid = room_pick_fallback(_bid, _kinds[_k], _role, _used);
                if (is_undefined(_sid)) continue;
                _used[$ _sid] = true;
                var _nid = array_length(_g.nodes);
                array_push(_g.nodes, {
                    nid: _nid,
                    biome_index: _b,
                    layer: _l,
                    kind: stage_get(_sid).kind,
                    sid: _sid,
                    next: [],
                    seed: irandom(999999), // sorteios da propria sala (recompensa, loja, evento)
                    visited: false
                });
                array_push(_layer, _nid);
            }
            run_graph_connect(_g, _prev, _layer);
            if (array_length(_layer) > 0) _prev = _layer;
        }
    }

    // o chefe fecha a rota
    _g.boss = array_length(_g.nodes);
    array_push(_g.nodes, {
        nid: _g.boss,
        biome_index: _nb,
        layer: 0,
        kind: "boss",
        sid: _R.boss_stage,
        next: [],
        seed: 0,
        visited: false
    });
    run_graph_connect(_g, _prev, [_g.boss]);
    return _g;
}

/// Confere salas existentes, conexoes validas, alcance a partir do inicio e
/// caminho ate o chefe para toda sala.
function run_graph_validate(_g) {
    var _n = array_length(_g.nodes);
    if (_n < 2 || _g.boss != _n - 1) return false;

    for (var _i = 0; _i < _n; _i++) {
        var _node = _g.nodes[_i];
        if (is_undefined(stage_get(_node.sid))) return false;
        if (_i != _g.boss && array_length(_node.next) == 0) return false;
        for (var _k = 0; _k < array_length(_node.next); _k++) {
            var _t = _node.next[_k];
            if (_t <= _i || _t >= _n) return false; // conexoes so avancam
        }
    }

    var _reach = array_create(_n, false);
    _reach[_g.start] = true;
    for (var _i = 0; _i < _n; _i++) {
        if (!_reach[_i]) continue;
        var _next = _g.nodes[_i].next;
        for (var _k = 0; _k < array_length(_next); _k++) _reach[_next[_k]] = true;
    }

    var _to_boss = array_create(_n, false);
    _to_boss[_g.boss] = true;
    for (var _i = _n - 2; _i >= 0; _i--) {
        var _next = _g.nodes[_i].next;
        for (var _k = 0; _k < array_length(_next); _k++) {
            if (_to_boss[_next[_k]]) _to_boss[_i] = true;
        }
    }

    for (var _i = 0; _i < _n; _i++) {
        if (!_reach[_i] || !_to_boss[_i]) return false;
    }
    return true;
}

/// Gera a rota da run. Deve ser chamado logo apos definir a seed.
function run_graph_build() {
    for (var _a = 0; _a < CFG.run.max_attempts; _a++) {
        var _g = run_graph_generate(false);
        if (run_graph_validate(_g)) return _g;
    }
    show_debug_message("Rota ramificada invalida; usando rota linear.");
    var _lin = run_graph_generate(true);
    if (!run_graph_validate(_lin)) show_error("Nao foi possivel gerar uma rota valida. Confira scr_rooms.", true);
    return _lin;
}

function run_node(_nid) {
    return global.run.graph.nodes[_nid];
}

/// No da sala atual, ou undefined fora de uma run.
function run_current_node() {
    var _run = global.run;
    if (!_run.active || is_undefined(_run.graph) || _run.graph.current < 0) return undefined;
    return _run.graph.nodes[_run.graph.current];
}

function run_goto_node(_nid) {
    var _g = global.run.graph;
    _g.current = _nid;
    _g.nodes[_nid].visited = true;
    stage_goto(_g.nodes[_nid].sid);
}

function run_biome_name(_biome_index) {
    if (_biome_index >= array_length(global.biomes)) return "CHEFE";
    return global.biomes[_biome_index].name;
}

/// Texto da porta que leva a um no: tipo da sala, nome e bioma se mudar.
function route_door_label(_from, _to) {
    var _txt = room_kind_label(_to.kind) + " - " + stage_get(_to.sid).name;
    if (_to.kind != "boss" && _to.biome_index != _from.biome_index) {
        _txt = run_biome_name(_to.biome_index) + ": " + _txt;
    }
    return _txt;
}

// ---------------------------------------------------------------- mapas laterais

/// Gera um mapa largo por bioma. Os trechos de combate reaproveitam os modulos
/// existentes; os locais especiais ficam em pontos fixos do corredor principal.
function run_maps_build() {
    var _maps = [];
    var _used = {};
    var _biome_count = array_length(global.biomes);
    global.run.special_rooms = {};

    for (var _b = 0; _b < _biome_count; _b++) {
        var _biome = global.biomes[_b];
        var _selected = [];

        var _sid = room_pick_fallback(_biome.bid, "combat", "start", _used);
        if (is_undefined(_sid)) show_error("Falta uma sala inicial de combate para " + _biome.name + ".", true);
        array_push(_selected, _sid);
        _used[$ _sid] = true;

        for (var _i = 0; _i < 2; _i++) {
            _sid = room_pick_fallback(_biome.bid, "combat", "mid", _used);
            if (is_undefined(_sid)) show_error("Faltam salas intermediarias de combate para " + _biome.name + ".", true);
            array_push(_selected, _sid);
            _used[$ _sid] = true;
        }

        _sid = room_pick_fallback(_biome.bid, "combat", "exit", _used);
        if (is_undefined(_sid)) show_error("Falta uma sala final de combate para " + _biome.name + ".", true);
        array_push(_selected, _sid);
        _used[$ _sid] = true;

        var _sections = [];
        var _pickups = [];
        var _props = [];
        var _offset = 0;
        for (var _i = 0; _i < array_length(_selected); _i++) {
            var _src = stage_get(_selected[_i]);
            var _waves = [];
            for (var _w = 0; _w < array_length(_src.encounter.waves); _w++) {
                var _wave_src = _src.encounter.waves[_w];
                var _wave = [];
                for (var _e = 0; _e < array_length(_wave_src); _e++) {
                    var _enemy = _wave_src[_e];
                    array_push(_wave, {
                        type: enemy_type_variant(_enemy.type, _b),
                        x: _enemy.x + _offset,
                        y: _enemy.y,
                        elite: random(1) < CFG.elite.chance[min(_b, array_length(CFG.elite.chance) - 1)]
                    });
                }
                array_push(_waves, _wave);
            }

            array_push(_sections, {
                id: _i,
                kind: "combat",
                sid: _src.sid,
                name: _src.name,
                x1: _offset,
                x2: _offset + _src.width,
                trigger_x: _offset + _src.encounter.trigger_x,
                lock_x1: _offset + _src.encounter.lock_x1,
                lock_x2: _offset + _src.encounter.lock_x2,
                waves: _waves,
                state: "pending",
                wave_index: 0
            });

            if (variable_struct_exists(_src, "pickups")) {
                for (var _p = 0; _p < array_length(_src.pickups); _p++) {
                    var _pickup = _src.pickups[_p];
                    array_push(_pickups, {
                        key: _src.sid + "_" + string(_p),
                        wid: _pickup.wid,
                        x: _offset + _pickup.x,
                        y: _pickup.y
                    });
                }
            }
            // quebraveis e perigo do bioma neste trecho
            var _rolled = props_roll_section(_biome.bid, _offset, _offset + _src.width);
            for (var _p = 0; _p < array_length(_rolled); _p++) array_push(_props, _rolled[_p]);
            _offset += _src.width;
        }

        // O chefe usa o mesmo obj_enemy e a mesma ficha da arena final existente,
        // mas a luta acontece no fim do corredor do proprio bioma.
        var _boss_def = stage_get(CFG.run.boss_stage);
        var _boss_source = _boss_def.encounter.waves[0][0];
        // cada bioma tem o seu chefe; o ultimo e o chefe final
        var _boss_type = CFG.run.biome_bosses[min(_b, array_length(CFG.run.biome_bosses) - 1)];
        var _boss_width = _boss_def.width;
        var _boss_x1 = _offset;
        var _boss_x2 = _offset + _boss_width;
        array_push(_sections, {
            id: array_length(_sections),
            kind: "boss",
            sid: _boss_def.sid,
            name: CFG.enemies[$ _boss_type].name,
            x1: _boss_x1,
            x2: _boss_x2,
            trigger_x: _boss_x1 + _boss_def.encounter.trigger_x,
            lock_x1: _boss_x1,
            lock_x2: _boss_x2,
            waves: [[{ type: _boss_type, x: _boss_x1 + _boss_source.x, y: _boss_source.y, elite: false }]],
            state: "pending",
            wave_index: 0
        });
        _offset = _boss_x2;

        // Entradas das salas opcionais. O tipo "challenge" usa os modulos "event".
        // Variedade: cada corredor sorteia quais tipos aparecem (special_slots de 4)
        // e em que ordem. "img_x" e a posicao da entrada dentro da imagem do
        // cenario (768 px); o fundo se repete espelhando os tiles impares, entao
        // em um tile impar a entrada aparece em 768 - img_x.
        var _special_specs = [
            { kind: "reward", module_kind: "reward", label: "TESOURO", img_x: 584 },
            { kind: "challenge", module_kind: "event", label: "DESAFIO", img_x: 312 },
            { kind: "shop", module_kind: "shop", label: "LOJA", img_x: 328 },
            { kind: "rest", module_kind: "rest", label: "DESCANSO", img_x: 496 }
        ];
        array_shuffle_ext(_special_specs);
        var _tiles = [0, 1, 2, 3];
        array_shuffle_ext(_tiles);
        var _slot_count = min(CFG.run.special_slots, array_length(_special_specs));
        var _specials = [];
        for (var _i = 0; _i < _slot_count; _i++) {
            var _spec = _special_specs[_i];
            // primeiro tile livre em que a entrada cai antes da arena do chefe
            _spec.x = -1;
            for (var _t = 0; _t < array_length(_tiles); _t++) {
                var _tile = _tiles[_t];
                var _wx = _tile * 768 + ((_tile mod 2 == 0) ? _spec.img_x : 768 - _spec.img_x);
                if (_wx < _boss_x1 - 60) {
                    _spec.x = _wx;
                    array_delete(_tiles, _t, 1);
                    break;
                }
            }
            if (_spec.x < 0) continue;
            var _target_sid = room_pick_fallback(_biome.bid, _spec.module_kind, "mid", _used);
            if (is_undefined(_target_sid)) show_error("Falta a sala opcional " + _spec.label + " para " + _biome.name + ".", true);
            _used[$ _target_sid] = true;
            var _state = {
                seed: irandom(999999),
                used: false,
                stock: undefined
            };
            global.run.special_rooms[$ _target_sid] = _state;
            array_push(_specials, {
                kind: _spec.kind,
                room_kind: _spec.kind,
                label: _spec.label,
                target_sid: _target_sid,
                x: _spec.x,
                y: 178,
                requires_clear: true
            });
        }

        var _map_sid = "map_" + _biome.bid;
        var _map = {
            sid: _map_sid,
            biome_index: _b,
            biome: _biome.bid,
            name: _biome.name,
            width: _offset,
            sections: _sections,
            specials: _specials,
            pickups: _pickups,
            pickups_taken: {},
            ground_weapons: [],
            props: _props,      // quebraveis e perigos (scr_props)
            completed: false
        };
        array_push(_maps, _map);
    }

    global.run.maps = _maps;
    run_maps_define_stages();
    return _maps;
}

/// Registra a sala de cada corredor a partir de global.run.maps. Separado da
/// geracao para que uma run carregada do save recrie as mesmas salas.
function run_maps_define_stages() {
    var _maps = global.run.maps;
    for (var _b = 0; _b < array_length(_maps); _b++) {
        var _map = _maps[_b];
        var _biome = biome_get(_map.biome);
        if (!variable_struct_exists(_map, "props")) _map.props = [];
        stage_define({
            sid: _map.sid,
            name: _biome.name,
            biome: _biome.bid,
            kind: "main_map",
            map_index: _b,
            room_asset: RM_STAGE,
            width: _map.width,
            floor_top: 178,
            floor_bottom: 258,
            player_spawn: { x: 60, y: 222 },
            doors: [],
            enemies: [],
            decor: _b + 1,
            palette: _biome.palette
        });
    }
}

/// Troca parte dos inimigos basicos das salas pelos tipos novos, mais a cada bioma.
function enemy_type_variant(_type, _biome_index) {
    var _r = random(1);
    var _k = clamp(_biome_index, 0, 2);
    var _shooter_chance = [0.25, 0.35, 0.4];
    var _bomber_chance = [0.08, 0.12, 0.14];
    var _shield_chance = [0, 0.16, 0.2];
    if (_type == "runner") {
        if (_r < _shooter_chance[_k]) return "shooter";
    } else if (_type == "thug") {
        if (_r < _bomber_chance[_k]) return "bomber";
        if (_r < _bomber_chance[_k] + _shield_chance[_k]) return "shield";
    }
    return _type;
}

function run_current_map() {
    if (!global.run.active) return undefined;
    var _i = global.run.map_index;
    if (_i < 0 || _i >= array_length(global.run.maps)) return undefined;
    return global.run.maps[_i];
}

function run_map_write(_map_index, _map) {
    global.run.maps[_map_index] = _map;
}

function run_map_mark_section(_map_index, _section_index, _state, _wave_index = undefined) {
    if (_map_index < 0 || _map_index >= array_length(global.run.maps)) return;
    var _map = global.run.maps[_map_index];
    if (_section_index < 0 || _section_index >= array_length(_map.sections)) return;
    var _section = _map.sections[_section_index];
    _section.state = _state;
    if (!is_undefined(_wave_index)) _section.wave_index = _wave_index;
    _map.sections[_section_index] = _section;
    run_map_write(_map_index, _map);
}

function run_map_save_pickup(_map_index, _key) {
    if (_map_index < 0 || _map_index >= array_length(global.run.maps)) return;
    var _map = global.run.maps[_map_index];
    _map.pickups_taken[$ _key] = true;
    run_map_write(_map_index, _map);
}

function run_map_new_drop_key() {
    global.run.drop_seq++;
    return "drop_" + string(global.run.drop_seq);
}

/// Guarda armas largadas que ainda estao no chao antes de abrir uma sala opcional.
function run_map_snapshot_ground_weapons(_map_index) {
    if (_map_index < 0 || _map_index >= array_length(global.run.maps)) return;
    var _ground = [];
    var _count = instance_number(obj_interact);
    for (var _i = 0; _i < _count; _i++) {
        var _item = instance_find(obj_interact, _i);
        if (_item.kind != "weapon" || _item.map_index != _map_index || _item.persistent_key != "") continue;
        array_push(_ground, {
            key: _item.drop_key,
            wid: _item.wid,
            durability: _item.durability,
            x: _item.x,
            y: _item.y
        });
    }
    var _map = global.run.maps[_map_index];
    _map.ground_weapons = _ground;
    run_map_write(_map_index, _map);
}

function run_special_state(_sid) {
    if (!variable_struct_exists(global.run.special_rooms, _sid)) {
        global.run.special_rooms[$ _sid] = { seed: 0, used: false, stock: undefined };
    }
    return global.run.special_rooms[$ _sid];
}

function run_special_state_save(_sid, _used, _stock) {
    if (_sid == "" || is_undefined(_sid)) return;
    var _state = run_special_state(_sid);
    _state.used = _used;
    _state.stock = _stock;
    global.run.special_rooms[$ _sid] = _state;
}

function run_enter_special(_target_sid) {
    var _p = instance_find(obj_player, 0);
    if (_p == noone || !global.run.active) return;
    if (global.stage.kind == "main_map") run_map_snapshot_ground_weapons(global.stage_rt.map_index);
    global.run.return_context = {
        stage_sid: global.stage.sid,
        x: _p.x,
        y: _p.y,
        facing: _p.facing
    };
    stage_goto(_target_sid);
}

function run_return_from_special() {
    if (is_undefined(global.run.return_context)) {
        stage_goto("lobby");
        return;
    }
    stage_goto(global.run.return_context.stage_sid);
}

function run_map_boss_cleared() {
    var _map = run_current_map();
    if (is_undefined(_map) || _map.completed) return;
    var _map_index = global.run.map_index;
    _map.completed = true;
    run_map_write(_map_index, _map);
    global.run.bosses_killed += 1;

    if (_map_index + 1 < array_length(global.run.maps)) {
        global.run.map_index = _map_index + 1;
        save_write(); // ponto de controle: inicio do proximo bioma
        stage_goto(global.run.maps[global.run.map_index].sid);
    } else {
        game_victory();
    }
}
