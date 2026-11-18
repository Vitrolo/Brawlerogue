/// Mapas da run e estado das salas opcionais.
///
/// O mapa de cada bioma e um nivel 2D: scr_level_gen gera a grade e o grafo, e
/// run_level_fill (abaixo, em "mapas 2D") preenche com ondas, portas e objetos.
///
/// Rota antiga (run_graph_*, nao usada pelos mapas): um grafo em camadas gerado
/// a partir da seed. Cada bioma tem CFG.run.layers_per_biome camadas: a primeira
/// e a ultima tem uma sala de combate (entrada e saida do bioma); as do meio
/// oferecem 2 a 3 opcoes. As conexoes so avancam, entao nao existem ciclos nem
/// becos sem saida.

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

/// Cor de cada tipo de local (minimapa, indicadores das entradas, rotulos).
/// Tesouro amarelo, loja verde, desafio vermelho, descanso azul.
function room_kind_colour(_kind) {
    switch (_kind) {
        case "combat": return make_colour_rgb(255, 140, 60);
        case "rest":   return make_colour_rgb(80, 150, 255);
        case "reward": return make_colour_rgb(255, 210, 63);
        case "shop":   return make_colour_rgb(80, 220, 110);
        case "event":  return make_colour_rgb(255, 70, 70);
        case "challenge": return make_colour_rgb(255, 70, 70);
        case "boss":   return make_colour_rgb(200, 80, 255);
    }
    return make_colour_rgb(255, 210, 63);
}

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

// ---------------------------------------------------------------- mapas 2D

/// Gera o mapa de cada bioma: um nivel 2D (scr_level_gen) preenchido com os
/// modulos de scr_rooms. Tudo usa o gerador da seed da run, entao a mesma seed
/// reproduz os mesmos mapas.
function run_maps_build() {
    var _maps = [];
    var _used = {};
    global.run.special_rooms = {};
    for (var _b = 0; _b < array_length(global.biomes); _b++) {
        var _lv = level_build(CFG.level);
        array_push(_maps, run_level_fill(_lv, global.biomes[_b], _b, _used));
    }
    global.run.maps = _maps;
    run_maps_define_stages();
    return _maps;
}

/// Transforma o nivel gerado no mapa jogavel do bioma: posicao de cada chunk no
/// mundo, corredores, escadas, portas, ondas, armas e objetos. Os indices de
/// chunks e links sao os mesmos do nivel gerado (scr_level descreve o formato).
function run_level_fill(_lv, _biome, _b, _used) {
    var _L = CFG.level;
    var _W = _L.cell_w;
    var _H = _L.band_h;
    var _sid = "map_" + _biome.bid;

    // so as linhas usadas viram faixas do mundo; a mais alta e a faixa 0
    var _top = 0;
    var _bottom = 0;
    for (var _i = 0; _i < array_length(_lv.chunks); _i++) {
        var _src = _lv.chunks[_i];
        if (!_src.on_grid) continue;
        _top = min(_top, _src.row);
        _bottom = max(_bottom, _src.row);
    }
    var _bands = _bottom - _top + 1;
    var _grid = array_create(_bands, 0);
    for (var _r = 0; _r < _bands; _r++) _grid[_r] = array_create(_lv.cols, -1);

    // 1) geometria de cada chunk (as salas interiores herdam a da porta)
    var _chunks = [];
    for (var _i = 0; _i < array_length(_lv.chunks); _i++) {
        var _src = _lv.chunks[_i];
        var _band = _src.row - _top;
        var _x1 = _src.col * _W;
        var _oy = _band * _H;
        var _links = [];
        for (var _k = 0; _k < array_length(_src.links); _k++) array_push(_links, _src.links[_k]);
        array_push(_chunks, {
            index: _i,
            type: _src.type,
            cat: chunk_type(_src.type).cat,
            on_grid: _src.on_grid,
            row: _src.row,
            col: _src.col,
            band: _band,
            x1: _x1,
            x2: _x1 + _W,
            oy: _oy,
            floor_top: _oy + 178,
            floor_bottom: _oy + 258,
            corridor: _src.corridor,
            links: _links,
            state: "cleared",       // combates: pending -> active -> cleared
            wave_index: 0,
            waves: [],
            trigger_x1: 0,          // o combate dispara com o jogador entre estes x
            trigger_x2: 0,
            lock_x1: _x1,
            lock_x2: _x1 + _W,
            sid: "",                // modulo das ondas ou sala interior
            name: "",
            room_kind: _src.room_kind,
            door: -1,               // corredor: indice da sala interior da porta
            door_x: 0,
            reward_key: "",         // horda: bau que aparece depois de limpar
            discovered: false,      // o jogador ja passou por aqui
            seen: false             // aparece no minimapa (com "?" enquanto nao visitado)
        });
        if (_src.on_grid) _grid[_band][_src.col] = _i;
    }

    // 2) links; escadas ganham o pe e o topo no mundo, portas a posicao no cenario
    var _links_out = [];
    var _stairs = [];
    for (var _l = 0; _l < array_length(_lv.links); _l++) {
        var _src_link = _lv.links[_l];
        var _link = { index: _l, a: _src_link.a, b: _src_link.b, kind: _src_link.kind };
        if (_src_link.kind == "stairs") {
            var _low = _chunks[_src_link.a];
            var _up = _chunks[_src_link.b];
            var _rise = (irandom(1) == 0) ? -1 : 1; // sobe para a esquerda ou para a direita
            var _run = stage_stairs_run(_biome.bid); // segue os degraus da arte do bioma
            var _foot = _low.x1 + _W * 0.5 - _rise * _run * 0.5 + irandom_range(-140, 140);
            // pe e topo longe das bordas da celula
            _foot = clamp(_foot, _low.x1 + 110 + max(0, -_rise * _run), _low.x2 - 110 - max(0, _rise * _run));
            _link.rise = _rise;
            _link.x_foot = round(_foot);
            _link.y_foot = _low.floor_top;
            _link.x_top = round(_foot) + _rise * _run;
            _link.y_top = _up.floor_bottom;
            array_push(_stairs, _l);
        } else if (_src_link.kind == "door") {
            var _host = _chunks[_src_link.a];
            _host.door = _src_link.b;
            _host.door_x = run_entrance_world_x(_host.col, stage_entrance_img_x(_biome.bid, _chunks[_src_link.b].room_kind), _W);
        }
        array_push(_links_out, _link);
    }

    // 3) conteudo de cada chunk
    var _pickups = [];
    var _props = [];
    for (var _i = 0; _i < array_length(_chunks); _i++) {
        var _ch = _chunks[_i];
        var _avoid = (_ch.door >= 0) ? [_ch.door_x] : [];
        switch (_ch.type) {
            case "start":
                _ch.name = "Inicio";
                break;

            case "combat":
            case "exit_combat":
            case "horde":
                var _mod_sid = run_pick_combat(_biome.bid, (_ch.type == "exit_combat") ? "exit" : "mid", _used);
                if (is_undefined(_mod_sid)) show_error("Faltam salas de combate para " + _biome.name + ".", true);
                _used[$ _mod_sid] = true;
                var _mod = stage_get(_mod_sid);
                _ch.sid = _mod_sid;
                _ch.name = _mod.name;
                _ch.state = "pending";
                _ch.waves = run_level_waves(_mod, _biome, _b, _ch);
                _ch.trigger_x1 = _ch.x1 + _L.combat_inset;
                _ch.trigger_x2 = _ch.x2 - _L.combat_inset;
                if (_ch.type == "horde") {
                    run_level_horde_extras(_ch, _biome, _b);
                    _ch.reward_key = "horde_" + _sid + "_" + string(_i);
                    global.run.special_rooms[$ _ch.reward_key] = { seed: irandom(999999), used: false, stock: undefined };
                }
                for (var _p = 0; _p < array_length(_mod.pickups); _p++) {
                    var _pk = _mod.pickups[_p];
                    array_push(_pickups, {
                        // indice do chunk na chave: um modulo repetido nao divide a arma
                        key: _mod_sid + "_" + string(_i) + "_" + string(_p),
                        wid: _pk.wid,
                        x: _ch.x1 + clamp(_pk.x, 80, _W - 80),
                        y: _ch.oy + _pk.y
                    });
                }
                run_level_add_props(_props, _biome.bid, _ch, _avoid);
                break;

            case "boss":
                // mesmo obj_enemy e mesma ficha da arena final; cada bioma tem o seu chefe
                var _boss_def = stage_get(CFG.run.boss_stage);
                var _boss_src = _boss_def.encounter.waves[0][0];
                var _boss_type = CFG.run.biome_bosses[min(_b, array_length(CFG.run.biome_bosses) - 1)];
                _ch.sid = _boss_def.sid;
                _ch.name = CFG.enemies[$ _boss_type].name;
                _ch.state = "pending";
                _ch.waves = [[{
                    type: _boss_type,
                    x: _ch.x1 + round(_boss_src.x * _W / _boss_def.width),
                    y: _ch.oy + _boss_src.y,
                    elite: false
                }]];
                _ch.trigger_x1 = _ch.x1 + _boss_def.encounter.trigger_x;
                _ch.trigger_x2 = _ch.x2;
                break;

            case "corridor":
                // corredor livre: so parte deles tem quebraveis e perigo
                if (random(1) < _L.corridor_props_chance) run_level_add_props(_props, _biome.bid, _ch, _avoid);
                break;

            case "dead_end":
                run_level_add_props(_props, _biome.bid, _ch, _avoid);
                // beco sem porta: uma arma esquecida no fundo (os quebraveis dao moedas e comida)
                if (_ch.door < 0) {
                    var _closed = -level_open_side(_lv, _i);
                    array_push(_pickups, {
                        key: "cache_" + _sid + "_" + string(_i),
                        wid: (irandom(1) == 0) ? "w_pipe" : "w_bat",
                        x: (_closed > 0) ? _ch.x2 - 150 : _ch.x1 + 150,
                        y: _ch.oy + 236
                    });
                }
                break;

            case "interior":
                // "challenge" usa os modulos de sala "event"
                var _module_kind = (_ch.room_kind == "challenge") ? "event" : _ch.room_kind;
                var _target = room_pick_fallback(_biome.bid, _module_kind, "mid", _used);
                if (is_undefined(_target)) show_error("Falta a sala opcional " + _ch.room_kind + " para " + _biome.name + ".", true);
                _used[$ _target] = true;
                global.run.special_rooms[$ _target] = { seed: irandom(999999), used: false, stock: undefined };
                _ch.sid = _target;
                _ch.name = stage_get(_target).name;
                break;
        }
    }

    // 4) corredores no mundo (limites de movimento, camera e cenario)
    var _cors = [];
    for (var _q = 0; _q < array_length(_lv.corridors); _q++) {
        var _c = _lv.corridors[_q];
        var _cband = _c.row - _top;
        var _ids = [];
        for (var _k = 0; _k < array_length(_c.chunks); _k++) array_push(_ids, _c.chunks[_k]);
        array_push(_cors, {
            index: _q,
            row: _c.row,
            band: _cband,
            c1: _c.c1,
            c2: _c.c2,
            x1: _c.c1 * _W,
            x2: (_c.c2 + 1) * _W,
            oy: _cband * _H,
            floor_top: _cband * _H + 178,
            floor_bottom: _cband * _H + 258,
            chunks: _ids,
            has_boss: array_contains(_ids, _lv.boss),
            // paredes nas pontas (a ponta direita do corredor do chefe e a saida do bioma)
            cap_left: true,
            cap_right: !array_contains(_ids, _lv.boss)
        });
    }
    // porta pintada rente a ponta de um corredor (descanso do esgoto, por exemplo):
    // essa ponta fica sem parede para a porta continuar alcancavel
    var _zone = _L.cap_margin + 30;
    for (var _i = 0; _i < array_length(_chunks); _i++) {
        var _ch = _chunks[_i];
        if (!_ch.on_grid || _ch.door < 0) continue;
        var _cor = _cors[_ch.corridor];
        if (_ch.col == _cor.c1 && _ch.door_x < _cor.x1 + _zone) _cor.cap_left = false;
        if (_ch.col == _cor.c2 && _ch.door_x > _cor.x2 - _zone) _cor.cap_right = false;
    }

    var _map = {
        version: 2,             // formato 2D (runs salvas antes disso sao descartadas)
        sid: _sid,
        biome_index: _b,
        biome: _biome.bid,
        name: _biome.name,
        cell_w: _W,
        band_h: _H,
        cols: _lv.cols,
        bands: _bands,
        row_top: _top,
        width: _lv.cols * _W,
        height: _bands * _H,
        grid: _grid,
        chunks: _chunks,
        links: _links_out,
        stairs: _stairs,        // indices dos links de escada
        corridors: _cors,
        start: _lv.start,
        boss: _lv.boss,
        pickups: _pickups,
        pickups_taken: {},
        ground_weapons: [],
        props: _props,          // quebraveis e perigos (scr_props)
        completed: false        // chefe derrotado: a saida a direita fica liberada
    };
    // o corredor principal aparece inteiro no minimapa desde o inicio, sem o conteudo
    for (var _i = 0; _i < array_length(_chunks); _i++) {
        if (_chunks[_i].on_grid && _chunks[_i].row == 0) _chunks[_i].seen = true;
    }
    level_discover(_map, _lv.start);
    return _map;
}

/// Ondas de um modulo de combate para o chunk: tipos e elites sorteados mais os
/// inimigos extras de CFG.encounter.enemy_count_mult. No corredor os inimigos
/// entram por fora da camera; a posicao do modulo so fica de reserva.
function run_level_waves(_mod, _biome, _b, _ch) {
    var _elite_chance = CFG.elite.chance[min(_b, array_length(CFG.elite.chance) - 1)];
    var _waves = [];
    for (var _w = 0; _w < array_length(_mod.encounter.waves); _w++) {
        var _src = _mod.encounter.waves[_w];
        var _wave = [];
        for (var _e = 0; _e < array_length(_src); _e++) {
            array_push(_wave, {
                type: enemy_type_variant(_src[_e].type, _b),
                x: _ch.x1 + clamp(_src[_e].x, 60, _ch.x2 - _ch.x1 - 60),
                y: _ch.oy + _src[_e].y,
                elite: random(1) < _elite_chance
            });
        }
        run_wave_add_extras(_wave, _biome, _b, _ch.x1, _ch.x2, _ch.floor_top + 6, _ch.floor_bottom - 6);
        array_push(_waves, _wave);
    }
    return _waves;
}

/// Horda (ponta de ramo): a ultima onda ganha CFG.level.horde_extra_enemies
/// inimigos do bioma. Vencer libera um bau (run_level_spawn_reward).
function run_level_horde_extras(_ch, _biome, _b) {
    var _last = _ch.waves[array_length(_ch.waves) - 1];
    var _pool = _biome.enemy_pool;
    var _elite_chance = CFG.elite.chance[min(_b, array_length(CFG.elite.chance) - 1)];
    for (var _i = 0; _i < CFG.level.horde_extra_enemies; _i++) {
        array_push(_last, {
            type: enemy_type_variant(_pool[irandom(array_length(_pool) - 1)], _b),
            x: irandom_range(_ch.x1 + 60, _ch.x2 - 60),
            y: irandom_range(_ch.floor_top + 6, _ch.floor_bottom - 6),
            elite: random(1) < _elite_chance
        });
    }
}

function run_level_add_props(_props, _bid, _ch, _avoid) {
    var _rolled = props_roll_section(_bid, _ch.x1, _ch.x2, _avoid, _ch.oy);
    for (var _p = 0; _p < array_length(_rolled); _p++) array_push(_props, _rolled[_p]);
}

/// Bau da horda: aparece no fundo do beco depois que a horda cai e volta a
/// aparecer enquanto nao for aberto.
function run_level_spawn_reward(_map, _ch) {
    if (_ch.reward_key == "") return;
    var _state = run_special_state(_ch.reward_key);
    if (_state.used) return;
    var _closed = -level_open_side(_map, _ch.index);
    instance_create_depth((_closed > 0) ? _ch.x2 - 140 : _ch.x1 + 140, _ch.floor_top + 12, 0, obj_interact, {
        kind: "chest",
        seed: _state.seed,
        used: false,
        persistence_key: _ch.reward_key
    });
}

/// Runs salvas antes dos mapas 2D nao podem continuar: o formato do mapa mudou.
function run_save_compatible(_run) {
    if (!is_struct(_run) || !variable_struct_exists(_run, "maps") || !is_array(_run.maps) || array_length(_run.maps) == 0) return false;
    for (var _i = 0; _i < array_length(_run.maps); _i++) {
        var _m = _run.maps[_i];
        if (!is_struct(_m) || !variable_struct_exists(_m, "version") || _m.version != 2) return false;
    }
    return true;
}

/// Acrescenta a uma onda os inimigos extras de CFG.encounter.enemy_count_mult:
/// tipos sorteados de biome.enemy_pool (com as variantes e elites do bioma), em
/// posicoes sorteadas da arena. Faz parte da geracao, entao segue a seed da run.
function run_wave_add_extras(_wave, _biome, _biome_index, _x1, _x2, _y1, _y2) {
    var _pool = _biome.enemy_pool;
    var _extra = array_length(_wave) * (max(1, CFG.encounter.enemy_count_mult) - 1);
    var _elite_chance = CFG.elite.chance[min(_biome_index, array_length(CFG.elite.chance) - 1)];
    for (var _i = 0; _i < _extra; _i++) {
        array_push(_wave, {
            type: enemy_type_variant(_pool[irandom(array_length(_pool) - 1)], _biome_index),
            x: irandom_range(_x1 + 40, _x2 - 40),
            y: irandom_range(_y1, _y2),
            elite: random(1) < _elite_chance
        });
    }
}

/// Modulo de combate do bioma ainda nao usado nesta run. Se o conjunto acabar,
/// repete um modulo do mesmo papel (nunca troca por uma sala especial).
function run_pick_combat(_bid, _role, _used) {
    var _sid = room_pick(_bid, "combat", _role, _used);
    if (is_undefined(_sid)) _sid = room_pick(_bid, "combat", _role, {});
    if (is_undefined(_sid)) _sid = room_pick(_bid, "combat", "mid", {});
    return _sid;
}

/// Posicao de uma entrada no mundo quando ela cai no tile _tile do cenario. Os
/// tiles impares sao espelhados, entao neles a entrada fica em largura - img_x.
function run_entrance_world_x(_tile, _img_x, _tile_w) {
    return _tile * _tile_w + ((_tile mod 2 == 0) ? _img_x : _tile_w - _img_x);
}

function run_special_label(_kind) {
    switch (_kind) {
        case "reward":    return "TESOURO";
        case "challenge": return "DESAFIO";
        case "shop":      return "LOJA";
        case "rest":      return "DESCANSO";
    }
    return string_upper(_kind);
}

/// Registra a sala de cada corredor a partir de global.run.maps. Separado da
/// geracao para que uma run carregada do save recrie as mesmas salas.
function run_maps_define_stages() {
    var _maps = global.run.maps;
    for (var _b = 0; _b < array_length(_maps); _b++) {
        var _map = _maps[_b];
        var _biome = biome_get(_map.biome);
        var _start = _map.chunks[_map.start];
        stage_define({
            sid: _map.sid,
            name: _biome.name,
            biome: _biome.bid,
            kind: "main_map",
            map_index: _b,
            room_asset: RM_STAGE,
            width: _map.width,
            height: _map.height,
            // chao dentro de cada faixa; em jogo vale stage_floor_top()/bottom()
            floor_top: 178,
            floor_bottom: 258,
            player_spawn: { x: _start.x1 + 60, y: _start.oy + 222 },
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

/// Estado do combate de um chunk (pending, active, cleared) e a onda atual.
function run_map_mark_chunk(_map_index, _cx, _state, _wave_index = undefined) {
    if (_map_index < 0 || _map_index >= array_length(global.run.maps)) return;
    var _map = global.run.maps[_map_index];
    if (_cx < 0 || _cx >= array_length(_map.chunks)) return;
    var _ch = _map.chunks[_cx];
    _ch.state = _state;
    if (!is_undefined(_wave_index)) _ch.wave_index = _wave_index;
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

/// Chefe do corredor derrotado. A luta acaba, mas o jogador continua na arena:
/// a saida a direita fica liberada (run_map_exit_open) e so atravessa-la leva ao
/// proximo bioma ou, no ultimo, a vitoria (run_map_leave).
function run_map_boss_cleared() {
    var _map = run_current_map();
    if (is_undefined(_map) || _map.completed) return;
    _map.completed = true;
    run_map_write(global.run.map_index, _map);
    global.run.bosses_killed += 1;
}

/// true quando o jogador esta no corredor atual com o chefe ja derrotado.
function run_map_exit_open() {
    if (is_undefined(global.stage) || global.stage.kind != "main_map") return false;
    if (!global.run.active) return false;
    var _map = run_current_map();
    return !is_undefined(_map) && _map.completed && _map.sid == global.stage.sid;
}

/// O jogador saiu pela direita da arena do chefe.
function run_map_leave() {
    var _next = global.run.map_index + 1;
    if (_next < array_length(global.run.maps)) {
        global.run.map_index = _next;
        global.run.return_context = undefined;
        save_write(); // ponto de controle: inicio do proximo bioma
        stage_goto(global.run.maps[_next].sid);
    } else {
        game_victory();
    }
}
