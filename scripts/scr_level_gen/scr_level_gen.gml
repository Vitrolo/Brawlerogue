/// Gerador dos niveis 2D (um por bioma). So dados: nao cria instancias, nao usa
/// rooms nem sprites, para poder ser testado fora do GameMaker
/// (node tools/level_sim/level_sim.js). O preenchimento com ondas, portas e
/// objetos fica em run_level_fill (scr_route).
///
/// Duas estruturas separadas:
///   ESPACO - lv.grid[linha - lv.row_min][coluna] guarda o indice do chunk que
///            ocupa a celula, ou -1. Uma celula tem CFG.level.cell_w px de
///            largura (um tile do cenario) e uma tela de altura. A linha 0 e o
///            corredor principal; as negativas ficam acima, as positivas abaixo.
///   GRAFO  - lv.links: "walk" liga vizinhos da mesma linha (a fica a esquerda) e
///            "stairs" liga a mesma coluna em linhas vizinhas (a fica embaixo).
/// As salas (loja, tesouro, descanso, desafio) sao chunks da grade como os
/// outros: o jogador entra nelas andando pelo corredor, sem porta.
/// level_validate confere que as duas concordam antes de o nivel ser aceito.
///
/// Regras de escrita deste arquivo (o teste converte o GML para JavaScript):
/// nada de with, repeat, div, enum, #macro ou acesso a instancias.

// ------------------------------------------------------------ tipos de chunk

/// Registro dos tipos de chunk. Para um tipo novo: uma linha aqui e o conteudo
/// dele em run_level_fill (scr_route).
///   cat      - categoria (horizontal, vertical, combat, exploration, special, interior)
///   sockets  - aberturas aceitas: left, right, up, down
///   combat   - tem horda: trava a camera ao entrar
///   end_only - so pode ficar na ponta de um corredor (uma unica passagem)
///   room     - sala com objeto proprio (loja, tesouro, descanso, desafio)
///   off_grid - nao ocupa celula (nenhum tipo usa hoje; fica para nos fora da grade)
function chunk_types_init() {
    global.chunk_types = {};
    chunk_type_define("start",       { cat: "horizontal",  sockets: ["right"] });
    chunk_type_define("corridor",    { cat: "horizontal",  sockets: ["left", "right"] });
    chunk_type_define("junction",    { cat: "vertical",    sockets: ["left", "right", "up", "down"] });
    chunk_type_define("combat",      { cat: "combat",      sockets: ["left", "right"], combat: true });
    chunk_type_define("exit_combat", { cat: "combat",      sockets: ["left", "right"], combat: true });
    chunk_type_define("horde",       { cat: "combat",      sockets: ["left", "right"], combat: true, end_only: true });
    chunk_type_define("dead_end",    { cat: "exploration", sockets: ["left", "right"], end_only: true });
    chunk_type_define("boss",        { cat: "special",     sockets: ["left"], combat: true });
    // salas: celulas do corredor com o objeto da sala (banca, bau, banco, painel)
    chunk_type_define("shop",        { cat: "interior",    sockets: ["left", "right"], room: true });
    chunk_type_define("reward",      { cat: "interior",    sockets: ["left", "right"], room: true });
    chunk_type_define("rest",        { cat: "interior",    sockets: ["left", "right"], room: true });
    chunk_type_define("challenge",   { cat: "special",     sockets: ["left", "right"], room: true });
}

function chunk_type_define(_name, _def) {
    _def.name = _name;
    if (!variable_struct_exists(_def, "combat")) _def.combat = false;
    if (!variable_struct_exists(_def, "end_only")) _def.end_only = false;
    if (!variable_struct_exists(_def, "room")) _def.room = false;
    if (!variable_struct_exists(_def, "off_grid")) _def.off_grid = false;
    global.chunk_types[$ _name] = _def;
}

/// O chunk e uma sala (loja, tesouro, descanso ou desafio).
function chunk_is_room(_type) {
    var _t = chunk_type(_type);
    return !is_undefined(_t) && _t.room;
}

function chunk_type(_name) {
    if (!variable_struct_exists(global.chunk_types, _name)) return undefined;
    return global.chunk_types[$ _name];
}

// ------------------------------------------------------------ estrutura

/// Nivel vazio com _cols colunas e linhas de -_max_depth a +_max_depth.
function level_new(_cols, _max_depth) {
    var _rows = _max_depth * 2 + 1;
    var _grid = array_create(_rows, 0);
    for (var _r = 0; _r < _rows; _r++) _grid[_r] = array_create(_cols, -1);
    return {
        cols: _cols,
        max_depth: _max_depth,
        row_min: -_max_depth,
        rows: _rows,
        grid: _grid,
        chunks: [],
        links: [],
        corridors: [],
        branches: [],   // corredores dos ramos (listas de indices), na ordem em que nasceram
        rooms: [],      // salas deste nivel: [tipo, onde] (onde: main, branch ou any)
        start: -1,
        boss: -1,
        linear: false
    };
}

/// Indice do chunk na celula, -1 se vazia ou -2 se fora da grade.
function level_cell(_lv, _row, _col) {
    if (_col < 0 || _col >= _lv.cols || _row < _lv.row_min || _row >= _lv.row_min + _lv.rows) return -2;
    return _lv.grid[_row - _lv.row_min][_col];
}

/// Cria um chunk na celula (linha, coluna). Tipos off_grid nao ocupam a celula.
function level_add_chunk(_lv, _type, _row, _col) {
    var _ix = array_length(_lv.chunks);
    var _on_grid = !chunk_type(_type).off_grid;
    array_push(_lv.chunks, {
        index: _ix,
        type: _type,
        row: _row,
        col: _col,
        on_grid: _on_grid,
        links: [],
        corridor: -1,
        room_kind: ""   // reservado (as salas usam o proprio tipo)
    });
    if (_on_grid) _lv.grid[_row - _lv.row_min][_col] = _ix;
    return _ix;
}

/// Liga dois chunks. Convencoes: "walk" com _a a esquerda, "stairs" com _a embaixo.
function level_link(_lv, _a, _b, _kind) {
    var _ix = array_length(_lv.links);
    array_push(_lv.links, { index: _ix, a: _a, b: _b, kind: _kind });
    array_push(_lv.chunks[_a].links, _ix);
    array_push(_lv.chunks[_b].links, _ix);
    return _ix;
}

function level_link_other(_link, _ix) {
    return (_link.a == _ix) ? _link.b : _link.a;
}

/// Direcao da abertura que o link usa no chunk _ix.
function level_link_dir(_link, _ix) {
    switch (_link.kind) {
        case "walk":   return (_ix == _link.a) ? "right" : "left";
        case "stairs": return (_ix == _link.a) ? "up" : "down";
    }
    return "";
}

function level_socket_ok(_ch, _dir) {
    var _t = chunk_type(_ch.type);
    return !is_undefined(_t) && array_contains(_t.sockets, _dir);
}

function level_link_count(_lv, _ix, _kind) {
    var _n = 0;
    var _links = _lv.chunks[_ix].links;
    for (var _k = 0; _k < array_length(_links); _k++) {
        if (_lv.links[_links[_k]].kind == _kind) _n++;
    }
    return _n;
}

/// Lado (-1 esquerda, +1 direita) da passagem de um chunk de ponta de corredor.
/// Serve tanto para o nivel gerado quanto para o mapa preenchido (mesmo formato
/// de chunks[].links e links[]).
function level_open_side(_lv, _cx) {
    var _links = _lv.chunks[_cx].links;
    for (var _k = 0; _k < array_length(_links); _k++) {
        var _l = _lv.links[_links[_k]];
        if (_l.kind == "walk") return (_l.a == _cx) ? 1 : -1;
    }
    return 1;
}

function level_has_link(_lv, _a, _b, _kind) {
    if (_a < 0 || _b < 0) return false;
    var _links = _lv.chunks[_a].links;
    for (var _k = 0; _k < array_length(_links); _k++) {
        var _l = _lv.links[_links[_k]];
        if (_l.kind == _kind && (_l.a == _b || _l.b == _b)) return true;
    }
    return false;
}

/// Embaralha no proprio array com o gerador da seed (mesma ordem na mesma seed).
function level_shuffle(_arr) {
    for (var _i = array_length(_arr) - 1; _i > 0; _i--) {
        var _j = irandom(_i);
        var _t = _arr[_i];
        _arr[_i] = _arr[_j];
        _arr[_j] = _t;
    }
    return _arr;
}

function level_range(_n) {
    var _out = array_create(_n, 0);
    for (var _i = 0; _i < _n; _i++) _out[_i] = _i;
    return _out;
}

// ------------------------------------------------------------ geracao

/// Gera um nivel valido: tenta ate _cfg.max_attempts vezes e, se nenhuma
/// servir, usa o nivel linear (so o corredor principal, sempre valido).
function level_build(_cfg) {
    for (var _a = 0; _a < _cfg.max_attempts; _a++) {
        var _lv = level_generate(_cfg, false);
        var _err = level_validate(_lv, _cfg);
        if (_err == "") return _lv;
        show_debug_message("Nivel descartado (" + _err + "); tentando de novo.");
    }
    var _lin = level_generate(_cfg, true);
    var _lin_err = level_validate(_lin, _cfg);
    if (_lin_err != "") show_error("Nao foi possivel gerar um nivel valido: " + _lin_err, true);
    return _lin;
}

/// Uma tentativa. _linear = true gera so o corredor principal.
function level_generate(_cfg, _linear) {
    var _cols = irandom_range(_cfg.main_cells[0], _cfg.main_cells[1]);
    var _rooms = level_room_list(_cfg);
    // linear: tudo no principal (inicio, combates contando a saida, salas e chefe)
    if (_linear) _cols = max(_cols, 2 + _cfg.main_combats + array_length(_rooms));
    var _lv = level_new(_cols, _cfg.max_depth);
    _lv.linear = _linear;
    _lv.rooms = _rooms;
    level_place_main(_lv);
    if (!_linear) level_generate_branches(_lv, _cfg);
    level_assign_ends(_lv, _cfg);
    level_assign_rooms(_lv, _cfg);
    level_assign_main(_lv, _cfg);
    level_assign_branch_combats(_lv, _cfg);
    level_corridors_build(_lv);
    return _lv;
}

/// Salas do nivel: as de interiors_main no principal, as de interiors_branch de
/// preferencia nos ramos e o descanso com rest_chance. Retorna [[tipo, onde], ...].
function level_room_list(_cfg) {
    var _out = [];
    for (var _i = 0; _i < array_length(_cfg.interiors_main); _i++) array_push(_out, [_cfg.interiors_main[_i], "main"]);
    for (var _i = 0; _i < array_length(_cfg.interiors_branch); _i++) array_push(_out, [_cfg.interiors_branch[_i], "branch"]);
    if (random(1) < _cfg.rest_chance) array_push(_out, ["rest", "any"]);
    return _out;
}

/// Salas que precisam de celula no principal.
function level_main_room_count(_lv) {
    var _n = 0;
    for (var _i = 0; _i < array_length(_lv.rooms); _i++) {
        if (_lv.rooms[_i][1] == "main") _n++;
    }
    return _n;
}

/// Corredor principal na linha 0: inicio, celulas livres, saida e chefe.
function level_place_main(_lv) {
    var _prev = -1;
    for (var _c = 0; _c < _lv.cols; _c++) {
        var _ix = level_add_chunk(_lv, "corridor", 0, _c);
        if (_prev >= 0) level_link(_lv, _prev, _ix, "walk");
        _prev = _ix;
    }
    _lv.start = level_cell(_lv, 0, 0);
    _lv.boss = level_cell(_lv, 0, _lv.cols - 1);
    _lv.chunks[_lv.start].type = "start";
    _lv.chunks[_lv.boss].type = "boss";
    _lv.chunks[level_cell(_lv, 0, _lv.cols - 2)].type = "exit_combat";
}

/// Escadas que o principal comporta sem tirar lugar dos combates e das salas dele.
function level_main_junction_cap(_lv, _cfg) {
    return (_lv.cols - 3) - (_cfg.main_combats - 1) - level_main_room_count(_lv);
}

function level_main_junctions(_lv) {
    var _n = 0;
    for (var _c = 0; _c < _lv.cols; _c++) {
        var _ix = level_cell(_lv, 0, _c);
        if (_ix >= 0 && _lv.chunks[_ix].type == "junction") _n++;
    }
    return _n;
}

/// Uma celula do principal pode receber escada: livre, entre o inicio e a
/// saida, e sem outra escada encostada (duas escadas seguidas confundem).
function level_can_be_main_junction(_lv, _c) {
    if (_c < 1 || _c > _lv.cols - 3) return false;
    var _ix = level_cell(_lv, 0, _c);
    if (_ix < 0 || _lv.chunks[_ix].type != "corridor") return false;
    for (var _d = -1; _d <= 1; _d += 2) {
        var _nb = level_cell(_lv, 0, _c + _d);
        if (_nb >= 0 && _lv.chunks[_nb].type == "junction") return false;
    }
    return true;
}

/// Procura onde abrir um corredor de _len celulas na linha _row cobrindo a
/// coluna _anchor, deixando uma celula vazia de folga em cada ponta (dois
/// corredores da mesma linha nunca se encostam). Retorna [c1, c2] ou undefined.
function level_fit_corridor(_lv, _row, _anchor, _len) {
    if (_row < _lv.row_min || _row >= _lv.row_min + _lv.rows) return undefined;
    var _starts = [];
    for (var _s = _anchor - _len + 1; _s <= _anchor; _s++) array_push(_starts, _s);
    level_shuffle(_starts);
    for (var _i = 0; _i < array_length(_starts); _i++) {
        var _c1 = _starts[_i];
        var _c2 = _c1 + _len - 1;
        if (_c1 < 0 || _c2 >= _lv.cols) continue;
        var _free = true;
        for (var _c = _c1 - 1; _c <= _c2 + 1; _c++) {
            if (level_cell(_lv, _row, _c) >= 0) {
                _free = false;
                break;
            }
        }
        if (_free) return [_c1, _c2];
    }
    return undefined;
}

/// Cria o corredor [_c1, _c2] na linha _row. Retorna os indices, da esquerda
/// para a direita.
function level_build_corridor(_lv, _row, _c1, _c2) {
    var _prev = -1;
    var _ids = [];
    for (var _c = _c1; _c <= _c2; _c++) {
        var _ix = level_add_chunk(_lv, "corridor", _row, _c);
        if (_prev >= 0) level_link(_lv, _prev, _ix, "walk");
        array_push(_ids, _ix);
        _prev = _ix;
    }
    return _ids;
}

/// Escada entre dois chunks da mesma coluna; _lower fica na linha de baixo.
function level_add_stairs(_lv, _lower, _upper) {
    _lv.chunks[_lower].type = "junction";
    _lv.chunks[_upper].type = "junction";
    level_link(_lv, _lower, _upper, "stairs");
}

/// Abre um ramo a partir do chunk _from para a linha vizinha (_dir = -1 acima,
/// +1 abaixo), ligado por escada. Retorna os indices do novo corredor ou
/// undefined se nao couber.
function level_grow_branch(_lv, _from, _dir, _cfg) {
    var _src = _lv.chunks[_from];
    var _row = _src.row + _dir;
    if (abs(_row) > _lv.max_depth) return undefined;
    var _want = irandom_range(_cfg.branch_cells[0], _cfg.branch_cells[1]);
    for (var _len = _want; _len >= _cfg.branch_cells[0]; _len--) {
        var _span = level_fit_corridor(_lv, _row, _src.col, _len);
        if (is_undefined(_span)) continue;
        var _ids = level_build_corridor(_lv, _row, _span[0], _span[1]);
        var _to = level_cell(_lv, _row, _src.col);
        if (_dir < 0) level_add_stairs(_lv, _from, _to);
        else level_add_stairs(_lv, _to, _from);
        return _ids;
    }
    return undefined;
}

/// Ramos a partir do principal, ramos de ramos e no maximo um atalho.
function level_generate_branches(_lv, _cfg) {
    var _want = irandom_range(_cfg.branches[0], _cfg.branches[1]);
    var _cap = level_main_junction_cap(_lv, _cfg);
    var _cands = [];
    for (var _c = 1; _c <= _lv.cols - 3; _c++) array_push(_cands, _c);
    level_shuffle(_cands);

    // 1) ramos do principal, alternando cima e baixo
    var _dir = (irandom(1) == 0) ? -1 : 1;
    for (var _i = 0; _i < array_length(_cands); _i++) {
        if (array_length(_lv.branches) >= _want || level_main_junctions(_lv) >= _cap) break;
        var _c = _cands[_i];
        if (!level_can_be_main_junction(_lv, _c)) continue;
        var _from = level_cell(_lv, 0, _c);
        var _ids = level_grow_branch(_lv, _from, _dir, _cfg);
        if (is_undefined(_ids)) {
            _ids = level_grow_branch(_lv, _from, -_dir, _cfg);
            if (is_undefined(_ids)) continue;
        } else {
            _dir = -_dir;
        }
        array_push(_lv.branches, _ids);
    }

    // 2) ramos de ramos, um nivel mais longe na mesma direcao
    var _n = array_length(_lv.branches);
    for (var _i = 0; _i < _n; _i++) {
        if (random(1) >= _cfg.sub_branch_chance) continue;
        var _ids = _lv.branches[_i];
        var _row = _lv.chunks[_ids[0]].row;
        var _out = (_row < 0) ? -1 : 1;
        if (abs(_row + _out) > _lv.max_depth) continue;
        var _opts = [];
        for (var _k = 0; _k < array_length(_ids); _k++) {
            if (_lv.chunks[_ids[_k]].type == "corridor") array_push(_opts, _ids[_k]);
        }
        level_shuffle(_opts);
        for (var _k = 0; _k < array_length(_opts); _k++) {
            var _sub = level_grow_branch(_lv, _opts[_k], _out, _cfg);
            if (!is_undefined(_sub)) {
                array_push(_lv.branches, _sub);
                break;
            }
        }
    }

    // 3) atalho: segunda escada entre um ramo vizinho e o principal (fecha um ciclo)
    if (random(1) < _cfg.shortcut_chance && level_main_junctions(_lv) < _cap) {
        level_try_shortcut(_lv);
    }
}

function level_try_shortcut(_lv) {
    var _order = level_shuffle(level_range(array_length(_lv.branches)));
    for (var _i = 0; _i < array_length(_order); _i++) {
        var _ids = _lv.branches[_order[_i]];
        var _row = _lv.chunks[_ids[0]].row;
        if (abs(_row) != 1) continue;
        var _cells = level_shuffle(level_range(array_length(_ids)));
        for (var _k = 0; _k < array_length(_cells); _k++) {
            var _ix = _ids[_cells[_k]];
            var _ch = _lv.chunks[_ix];
            if (_ch.type != "corridor" || !level_can_be_main_junction(_lv, _ch.col)) continue;
            var _main = level_cell(_lv, 0, _ch.col);
            if (_row < 0) level_add_stairs(_lv, _main, _ix);
            else level_add_stairs(_lv, _ix, _main);
            return true;
        }
    }
    return false;
}

/// Combates do principal: main_combats contando a saida, espalhados pelas
/// celulas livres entre o inicio e a saida.
function level_assign_main(_lv, _cfg) {
    var _free = [];
    for (var _c = 1; _c <= _lv.cols - 3; _c++) {
        var _ix = level_cell(_lv, 0, _c);
        if (_lv.chunks[_ix].type == "corridor") array_push(_free, _ix);
    }
    var _nf = array_length(_free);
    var _need = min(_cfg.main_combats - 1, _nf);
    for (var _k = 0; _k < _need; _k++) {
        var _lo = floor(_k * _nf / _need);
        var _hi = floor((_k + 1) * _nf / _need) - 1;
        _lv.chunks[_free[irandom_range(_lo, _hi)]].type = "combat";
    }
}

/// Pontas dos ramos viram becos ou hordas (a primeira beco, a segunda horda,
/// as demais por sorteio).
function level_assign_ends(_lv, _cfg) {
    var _ends = [];
    for (var _i = 0; _i < array_length(_lv.chunks); _i++) {
        var _ch = _lv.chunks[_i];
        if (!_ch.on_grid || _ch.row == 0 || _ch.type != "corridor") continue;
        if (level_link_count(_lv, _i, "walk") == 1) array_push(_ends, _i);
    }
    level_shuffle(_ends);
    for (var _k = 0; _k < array_length(_ends); _k++) {
        var _type = "dead_end";
        if (_k == 1 || (_k > 1 && random(1) < _cfg.horde_chance)) _type = "horde";
        _lv.chunks[_ends[_k]].type = _type;
    }
}

/// Celulas livres que sobram nos ramos podem virar combate.
function level_assign_branch_combats(_lv, _cfg) {
    for (var _i = 0; _i < array_length(_lv.chunks); _i++) {
        var _ch = _lv.chunks[_i];
        if (_ch.on_grid && _ch.row != 0 && _ch.type == "corridor" && random(1) < _cfg.branch_combat_chance) {
            _ch.type = "combat";
        }
    }
}

/// Salas do nivel (lv.rooms): cada uma toma uma celula do corredor. As do
/// principal ficam no principal; as dos ramos preferem o fundo de um beco; o
/// descanso ("any") prefere os ramos. Uma sala de ramo so cai no principal se
/// sobrar celula alem dos combates dele.
function level_assign_rooms(_lv, _cfg) {
    for (var _i = 0; _i < array_length(_lv.rooms); _i++) {
        var _kind = _lv.rooms[_i][0];
        var _where = _lv.rooms[_i][1];
        var _host = -1;
        if (_where == "main") {
            _host = level_pick_room_host(_lv, "main");
        } else {
            _host = level_pick_room_host(_lv, "branch");
            if (_host < 0 && level_main_free(_lv) > _cfg.main_combats - 1 + level_main_rooms_left(_lv, _i)) {
                _host = level_pick_room_host(_lv, "main");
            }
        }
        if (_host < 0) continue; // a validacao recusa o nivel se faltar uma sala obrigatoria
        _lv.chunks[_host].type = _kind;
    }
}

/// Celulas livres (corredor) do principal, entre o inicio e a saida.
function level_main_free(_lv) {
    var _n = 0;
    for (var _c = 1; _c <= _lv.cols - 3; _c++) {
        if (_lv.chunks[level_cell(_lv, 0, _c)].type == "corridor") _n++;
    }
    return _n;
}

/// Salas do principal que ainda vao ser colocadas depois da sala _i.
function level_main_rooms_left(_lv, _i) {
    var _n = 0;
    for (var _k = _i + 1; _k < array_length(_lv.rooms); _k++) {
        if (_lv.rooms[_k][1] == "main") _n++;
    }
    return _n;
}

/// Celula sorteada para uma sala: corredor livre ou beco, em "main" ou "branch"
/// (uma sala no fundo de um beco vira o fim daquele caminho).
function level_pick_room_host(_lv, _where) {
    var _order = level_shuffle(level_range(array_length(_lv.chunks)));
    for (var _i = 0; _i < array_length(_order); _i++) {
        var _ix = _order[_i];
        var _ch = _lv.chunks[_ix];
        if (!_ch.on_grid || (_ch.type != "corridor" && _ch.type != "dead_end")) continue;
        var _main = (_ch.row == 0);
        if (_where == "main" && !_main) continue;
        if (_where == "branch" && _main) continue;
        return _ix;
    }
    return -1;
}

/// Corredores: sequencias de chunks da mesma linha ligados por "walk".
function level_corridors_build(_lv) {
    _lv.corridors = [];
    for (var _r = 0; _r < _lv.rows; _r++) {
        var _cur = undefined;
        for (var _c = 0; _c < _lv.cols; _c++) {
            var _ix = _lv.grid[_r][_c];
            if (_ix < 0) {
                _cur = undefined;
                continue;
            }
            if (is_undefined(_cur) || !level_has_link(_lv, _lv.grid[_r][_c - 1], _ix, "walk")) {
                _cur = { index: array_length(_lv.corridors), row: _r + _lv.row_min, c1: _c, c2: _c, chunks: [] };
                array_push(_lv.corridors, _cur);
            }
            _cur.c2 = _c;
            array_push(_cur.chunks, _ix);
            _lv.chunks[_ix].corridor = _cur.index;
        }
    }
}

// ------------------------------------------------------------ validacao

/// Busca em largura por todos os links. Retorna um array de booleanos.
function level_reach(_lv, _from) {
    var _n = array_length(_lv.chunks);
    var _seen = array_create(_n, false);
    var _queue = [_from];
    _seen[_from] = true;
    var _head = 0;
    while (_head < array_length(_queue)) {
        var _ix = _queue[_head];
        _head++;
        var _links = _lv.chunks[_ix].links;
        for (var _k = 0; _k < array_length(_links); _k++) {
            var _o = level_link_other(_lv.links[_links[_k]], _ix);
            if (!_seen[_o]) {
                _seen[_o] = true;
                array_push(_queue, _o);
            }
        }
    }
    return _seen;
}

/// Confere o nivel. Retorna "" se estiver valido, ou o motivo do problema.
function level_validate(_lv, _cfg) {
    var _n = array_length(_lv.chunks);
    if (_n == 0) return "nivel vazio";

    // 1) grade e chunks contam a mesma historia (nada sobreposto)
    for (var _r = 0; _r < _lv.rows; _r++) {
        for (var _c = 0; _c < _lv.cols; _c++) {
            var _gx = _lv.grid[_r][_c];
            if (_gx == -1) continue;
            if (_gx < 0 || _gx >= _n) return "grade aponta para chunk inexistente";
            var _gch = _lv.chunks[_gx];
            if (!_gch.on_grid || _gch.row != _r + _lv.row_min || _gch.col != _c) return "grade e chunk " + string(_gx) + " discordam";
        }
    }
    var _cells = 0;
    for (var _i = 0; _i < _n; _i++) {
        var _ch = _lv.chunks[_i];
        var _t = chunk_type(_ch.type);
        if (is_undefined(_t)) return "tipo desconhecido: " + string(_ch.type);
        if (_t.off_grid == _ch.on_grid) return "chunk " + string(_i) + " dentro/fora da grade errado";
        if (!_ch.on_grid) continue;
        _cells++;
        if (abs(_ch.row) > _lv.max_depth) return "chunk " + string(_i) + " fora das linhas permitidas";
        if (level_cell(_lv, _ch.row, _ch.col) != _i) return "chunk " + string(_i) + " sobreposto";
    }

    // 2) cada link: indices, simetria, geometria e aberturas permitidas
    var _walk_stairs = 0;
    for (var _l = 0; _l < array_length(_lv.links); _l++) {
        var _k = _lv.links[_l];
        if (_k.a < 0 || _k.a >= _n || _k.b < 0 || _k.b >= _n || _k.a == _k.b) return "link " + string(_l) + " invalido";
        var _A = _lv.chunks[_k.a];
        var _B = _lv.chunks[_k.b];
        if (!array_contains(_A.links, _l) || !array_contains(_B.links, _l)) return "link " + string(_l) + " nao e simetrico";
        switch (_k.kind) {
            case "walk":
                if (!_A.on_grid || !_B.on_grid || _A.row != _B.row || _B.col != _A.col + 1) return "passagem " + string(_l) + " fora de vizinhos";
                _walk_stairs++;
                break;
            case "stairs":
                if (!_A.on_grid || !_B.on_grid || _A.col != _B.col || _B.row != _A.row - 1) return "escada " + string(_l) + " fora de linhas vizinhas";
                if (_A.type != "junction" || _B.type != "junction") return "escada " + string(_l) + " fora de junction";
                _walk_stairs++;
                break;
            default:
                return "link " + string(_l) + " de tipo desconhecido";
        }
        if (!level_socket_ok(_A, level_link_dir(_k, _k.a))) return "abertura " + level_link_dir(_k, _k.a) + " nao permitida em " + _A.type;
        if (!level_socket_ok(_B, level_link_dir(_k, _k.b))) return "abertura " + level_link_dir(_k, _k.b) + " nao permitida em " + _B.type;
    }

    // 3) regras por chunk
    for (var _i = 0; _i < _n; _i++) {
        var _ch = _lv.chunks[_i];
        if (!_ch.on_grid) return "chunk " + string(_i) + " fora da grade";
        var _right = level_cell(_lv, _ch.row, _ch.col + 1);
        if (_right >= 0 && !level_has_link(_lv, _i, _right, "walk")) return "corredores encostados sem passagem";
        var _stairs = level_link_count(_lv, _i, "stairs");
        if ((_ch.type == "junction") != (_stairs == 1)) return "escada e junction nao combinam no chunk " + string(_i);
        if (chunk_type(_ch.type).end_only && level_link_count(_lv, _i, "walk") != 1) return _ch.type + " fora da ponta";
        if (_ch.type == "junction" && _ch.row == 0) {
            var _nb = level_cell(_lv, 0, _ch.col + 1);
            if (_nb >= 0 && _lv.chunks[_nb].type == "junction") return "escadas encostadas no principal";
        }
    }

    // 4) principal completo: inicio, saida e chefe nos lugares certos
    for (var _c = 0; _c < _lv.cols; _c++) {
        var _mx = level_cell(_lv, 0, _c);
        if (_mx < 0) return "principal interrompido na coluna " + string(_c);
        if (_c > 0 && !level_has_link(_lv, level_cell(_lv, 0, _c - 1), _mx, "walk")) return "principal sem passagem";
    }
    if (_lv.start != level_cell(_lv, 0, 0) || _lv.chunks[_lv.start].type != "start") return "inicio fora do lugar";
    if (_lv.boss != level_cell(_lv, 0, _lv.cols - 1) || _lv.chunks[_lv.boss].type != "boss") return "chefe fora do lugar";
    if (_lv.chunks[level_cell(_lv, 0, _lv.cols - 2)].type != "exit_combat") return "saida fora do lugar";

    // 5) tudo alcancavel a partir do inicio (inclusive o chefe)
    var _seen = level_reach(_lv, _lv.start);
    for (var _i = 0; _i < _n; _i++) {
        if (!_seen[_i]) return "chunk " + string(_i) + " inalcancavel";
    }

    // 6) limites que evitam mapas confusos
    if (_cells > _cfg.max_cells) return "celulas demais (" + string(_cells) + ")";
    if (_walk_stairs - _cells + 1 > 1) return "mais de um ciclo";
    var _main_combats = 0;
    for (var _c = 0; _c < _lv.cols; _c++) {
        var _mt = _lv.chunks[level_cell(_lv, 0, _c)].type;
        if (_mt == "combat" || _mt == "exit_combat") _main_combats++;
    }
    if (_main_combats != _cfg.main_combats) return "principal com " + string(_main_combats) + " combates";
    for (var _q = 0; _q < array_length(_lv.corridors); _q++) {
        var _cor = _lv.corridors[_q];
        if (_cor.row == 0) continue;
        var _len = _cor.c2 - _cor.c1 + 1;
        if (_len < _cfg.branch_cells[0] || _len > _cfg.branch_cells[1]) return "ramo com " + string(_len) + " celulas";
    }
    if (!_lv.linear) {
        var _roots = [];
        for (var _l = 0; _l < array_length(_lv.links); _l++) {
            var _k = _lv.links[_l];
            if (_k.kind != "stairs") continue;
            var _A = _lv.chunks[_k.a];
            var _B = _lv.chunks[_k.b];
            var _far = -1;
            if (_A.row == 0) _far = _B.corridor;
            else if (_B.row == 0) _far = _A.corridor;
            if (_far >= 0 && !array_contains(_roots, _far)) array_push(_roots, _far);
        }
        if (array_length(_roots) < _cfg.branches[0] || array_length(_roots) > _cfg.branches[1]) return "ramos: " + string(array_length(_roots));
    }

    // 7) salas obrigatorias, uma de cada; descanso no maximo uma
    var _need = [];
    for (var _i = 0; _i < array_length(_cfg.interiors_main); _i++) array_push(_need, _cfg.interiors_main[_i]);
    for (var _i = 0; _i < array_length(_cfg.interiors_branch); _i++) array_push(_need, _cfg.interiors_branch[_i]);
    for (var _q = 0; _q < array_length(_need); _q++) {
        var _count = 0;
        for (var _i = 0; _i < _n; _i++) {
            var _ch = _lv.chunks[_i];
            if (_ch.type == _need[_q]) _count++;
        }
        if (_count != 1) return "sala " + _need[_q] + " aparece " + string(_count) + " vezes";
    }
    for (var _i = 0; _i < array_length(_cfg.interiors_main); _i++) {
        var _kind = _cfg.interiors_main[_i];
        for (var _j = 0; _j < _n; _j++) {
            var _ch = _lv.chunks[_j];
            if (_ch.type == _kind && _ch.row != 0) return "sala " + _kind + " fora do principal";
        }
    }
    var _rests = 0;
    for (var _i = 0; _i < _n; _i++) if (_lv.chunks[_i].type == "rest") _rests++;
    if (_rests > 1) return "descanso repetido";
    return "";
}
