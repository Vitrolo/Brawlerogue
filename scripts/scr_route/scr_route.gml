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
