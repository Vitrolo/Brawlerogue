/// Nivel 2D em jogo: corredor e faixa do jogador, limites de movimento,
/// escadas, descoberta e o desenho de depuracao (F2).
///
/// O mapa de cada bioma vem de run_level_fill (scr_route), em global.run.maps:
///   map.grid[faixa][coluna]  indice do chunk na celula, ou -1 (ESPACO)
///   map.links                conexoes walk/stairs/door (GRAFO); as escadas
///                            guardam x_foot/y_foot (pe, na parede do fundo da
///                            faixa de baixo) e x_top/y_top (topo, na beirada da
///                            frente da faixa de cima)
///   map.corridors            trechos horizontais continuos: limites de x, faixa
///                            (oy) e chao (floor_top..floor_bottom)
/// A faixa 0 do mundo e a linha mais alta usada; cada faixa tem band_h px.

function level_current_map() {
    if (is_undefined(global.stage) || global.stage.kind != "main_map" || is_undefined(global.stage_rt)) return undefined;
    var _i = global.stage_rt.map_index;
    if (_i < 0 || _i >= array_length(global.run.maps)) return undefined;
    return global.run.maps[_i];
}

/// Indice do chunk (na grade) que contem o ponto, ou -1.
function level_chunk_at(_map, _x, _y) {
    var _band = floor(_y / _map.band_h);
    var _col = floor(_x / _map.cell_w);
    if (_band < 0 || _band >= _map.bands || _col < 0 || _col >= _map.cols) return -1;
    return _map.grid[_band][_col];
}

/// Corredor que contem o ponto, ou -1. Fora das celulas (no vazio entre
/// corredores) procura o corredor da mesma faixa mais perto em x.
function level_corridor_at(_map, _x, _y) {
    var _cx = level_chunk_at(_map, _x, _y);
    if (_cx >= 0) return _map.chunks[_cx].corridor;
    var _band = floor(_y / _map.band_h);
    var _best = -1;
    var _best_d = infinity;
    for (var _i = 0; _i < array_length(_map.corridors); _i++) {
        var _c = _map.corridors[_i];
        if (_c.band != _band) continue;
        var _d = max(0, _c.x1 - _x, _x - _c.x2);
        if (_d < _best_d) {
            _best = _i;
            _best_d = _d;
        }
    }
    return _best;
}

/// Corredor em que o jogador esta (struct), ou undefined fora dos mapas 2D.
function stage_corridor() {
    var _map = level_current_map();
    if (is_undefined(_map)) return undefined;
    var _c = global.stage_rt.corridor;
    if (_c < 0 || _c >= array_length(_map.corridors)) return undefined;
    return _map.corridors[_c];
}

/// Troca o corredor atual (ao nascer e ao terminar uma escada).
function stage_set_corridor(_cor) {
    var _rt = global.stage_rt;
    _rt.corridor = _cor;
    var _map = level_current_map();
    if (is_undefined(_map) || _cor < 0) return;
    _rt.subtitle = level_corridor_label(_map.corridors[_cor]);
}

function level_corridor_label(_c) {
    if (_c.row == 0) return "CORREDOR PRINCIPAL";
    if (_c.row < 0) return (_c.row == -1) ? "NIVEL DE CIMA" : "NIVEL DE CIMA 2";
    return (_c.row == 1) ? "NIVEL DE BAIXO" : "NIVEL DE BAIXO 2";
}

/// Faixa de profundidade em que os pes podem andar. Nos mapas 2D vale o chao
/// do corredor do jogador; nas outras salas, o da definicao.
function stage_floor_top() {
    var _c = stage_corridor();
    return is_undefined(_c) ? global.stage.floor_top : _c.floor_top;
}

function stage_floor_bottom() {
    var _c = stage_corridor();
    return is_undefined(_c) ? global.stage.floor_bottom : _c.floor_bottom;
}

/// Topo do chao da faixa que contem _y (objetos de cenario de qualquer faixa).
function stage_floor_top_at(_y) {
    var _map = level_current_map();
    if (is_undefined(_map)) return global.stage.floor_top;
    return floor(_y / _map.band_h) * _map.band_h + global.stage.floor_top;
}

// ------------------------------------------------------------ escadas

/// Escada ao alcance do ponto, no corredor _cor: o pe (encostado na parede do
/// fundo) ou o topo (na beirada da frente). Retorna { link, top } ou undefined.
function level_stairs_near(_map, _cor, _x, _y) {
    var _L = CFG.level;
    for (var _i = 0; _i < array_length(_map.stairs); _i++) {
        var _k = _map.links[_map.stairs[_i]];
        if (_map.chunks[_k.a].corridor == _cor && abs(_x - _k.x_foot) <= _L.stair_zone && _y <= _k.y_foot + _L.stair_edge) {
            return { link: _k.index, top: false };
        }
        if (_map.chunks[_k.b].corridor == _cor && abs(_x - _k.x_top) <= _L.stair_zone && _y >= _k.y_top - _L.stair_edge) {
            return { link: _k.index, top: true };
        }
    }
    return undefined;
}

/// Suaviza o inicio e o fim de uma interpolacao (0..1).
function level_smooth(_t) {
    _t = clamp(_t, 0, 1);
    return _t * _t * (3 - 2 * _t);
}

// ------------------------------------------------------------ descoberta

/// Marca como visitado o chunk em que o jogador esta. Os vizinhos dele no grafo
/// (inclusive a outra ponta de uma escada e a sala de uma porta) ficam
/// conhecidos: o minimapa os mostra com "?".
function run_map_update_discovery(_map_index, _x, _y) {
    var _map = global.run.maps[_map_index];
    var _cx = level_chunk_at(_map, _x, _y);
    if (_cx < 0) return;
    var _ch = _map.chunks[_cx];
    if (_ch.discovered) return;
    level_discover(_map, _cx);
}

function level_discover(_map, _cx) {
    var _ch = _map.chunks[_cx];
    _ch.discovered = true;
    _ch.seen = true;
    for (var _k = 0; _k < array_length(_ch.links); _k++) {
        var _l = _map.links[_ch.links[_k]];
        _map.chunks[(_l.a == _cx) ? _l.b : _l.a].seen = true;
    }
}

// ------------------------------------------------------------ depuracao

/// F2 (com CFG.debug.level_overlay_key): limites e tipo de cada chunk, corredores,
/// ligacoes e zonas das escadas. Desenhado no mundo, por cima de tudo.
function level_debug_update() {
    if (!variable_global_exists("level_debug")) global.level_debug = false;
    if (CFG.debug.level_overlay_key && keyboard_check_pressed(vk_f2)) global.level_debug = !global.level_debug;
}

function level_debug_draw() {
    if (!variable_global_exists("level_debug") || !global.level_debug) return;
    var _map = level_current_map();
    if (is_undefined(_map)) return;
    var _L = CFG.level;
    draw_set_alpha(1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    for (var _i = 0; _i < array_length(_map.chunks); _i++) {
        var _ch = _map.chunks[_i];
        if (!_ch.on_grid) continue;
        var _col = (_ch.state == "pending") ? c_orange : ((_ch.state == "active") ? c_red : c_lime);
        draw_set_colour(_col);
        draw_rectangle(_ch.x1 + 1, _ch.oy + 1, _ch.x2 - 2, _ch.oy + _map.band_h - 2, true);
        draw_set_colour(c_yellow);
        draw_line(_ch.x1, _ch.floor_top, _ch.x2, _ch.floor_top);
        draw_line(_ch.x1, _ch.floor_bottom, _ch.x2, _ch.floor_bottom);
        if (_ch.trigger_x2 > _ch.trigger_x1) {
            draw_set_colour(c_red);
            draw_line(_ch.trigger_x1, _ch.floor_top, _ch.trigger_x1, _ch.floor_bottom);
            draw_line(_ch.trigger_x2, _ch.floor_top, _ch.trigger_x2, _ch.floor_bottom);
        }
        draw_set_colour(c_white);
        draw_text(_ch.x1 + 6, _ch.oy + 6, string(_i) + " " + _ch.type + " c" + string(_ch.corridor)
            + (_ch.discovered ? " V" : (_ch.seen ? " ?" : "")));
        if (_ch.door >= 0) {
            draw_set_colour(c_aqua);
            draw_line(_ch.door_x, _ch.floor_top - 60, _ch.door_x, _ch.floor_top);
        }
    }
    for (var _i = 0; _i < array_length(_map.stairs); _i++) {
        var _k = _map.links[_map.stairs[_i]];
        draw_set_colour(c_fuchsia);
        draw_line_width(_k.x_foot, _k.y_foot, _k.x_top, _k.y_top, 2);
        draw_rectangle(_k.x_foot - _L.stair_zone, _k.y_foot - 4, _k.x_foot + _L.stair_zone, _k.y_foot + _L.stair_edge, true);
        draw_rectangle(_k.x_top - _L.stair_zone, _k.y_top - _L.stair_edge, _k.x_top + _L.stair_zone, _k.y_top + 4, true);
    }
    var _rt = global.stage_rt;
    if (_rt.lock_active) {
        draw_set_colour(c_red);
        draw_rectangle(_rt.lock_x1, stage_floor_top() - 2, _rt.lock_x2, stage_floor_bottom() + 2, true);
    }
    draw_set_colour(c_white);
}
