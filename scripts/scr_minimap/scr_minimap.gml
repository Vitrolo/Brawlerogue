/// Minimapa do corredor do bioma atual, desenhado no Draw GUI (coordenadas 960x540).
///
/// Canto inferior direito: uma "camera" propria que mostra so os arredores do
/// jogador (MINIMAP_SPAN pixels do mundo), com as laterais esmaecidas e borradas.
/// Segurando ACT.MAP (TAB) o quadro cresce ate o centro da tela e mostra todos
/// os corredores da run, do inicio ao chefe.
///
/// Tudo vem de global.run.maps: trechos de combate (pending/active/cleared), as
/// entradas das salas especiais e o chefe no fim. Nada aqui altera o jogo.

#macro MINIMAP_W 232
#macro MINIMAP_H 60
#macro MINIMAP_MARGIN 18
#macro MINIMAP_SPAN 1500   // largura do mundo visivel no minimapa do canto
#macro MINIMAP_FADE 48     // largura das bordas esmaecidas, em pixels da interface

function minimap_state() {
    if (!variable_global_exists("minimap")) {
        global.minimap = { t: 0, surf: -1 };
    }
    return global.minimap;
}

/// Ha um corredor para mostrar (run ativa, fora do lobby e da arena final).
function minimap_available() {
    if (!global.run.active) return false;
    return !is_undefined(run_current_map());
}

/// Posicao do jogador no corredor. Dentro de uma sala especial vale a porta
/// por onde ele entrou.
function minimap_player_x(_map) {
    if (global.stage.kind == "main_map") {
        var _p = instance_find(obj_player, 0);
        if (_p != noone) return _p.x;
    }
    var _ctx = global.run.return_context;
    if (!is_undefined(_ctx) && _ctx.stage_sid == _map.sid) return _ctx.x;
    return 0;
}

function minimap_player_facing() {
    var _p = instance_find(obj_player, 0);
    if (global.stage.kind == "main_map" && _p != noone) return _p.facing;
    return 1;
}

/// Desenha um corredor na faixa [_x, _x + _w] x [_y, _y + _h], mostrando o
/// trecho do mundo entre _wx0 e _wx1. _labels escreve o tipo de cada entrada.
/// _here: este e o corredor em que o jogador esta (desenha o marcador dele).
function minimap_draw_corridor(_map, _x, _y, _w, _h, _wx0, _wx1, _labels, _here) {
    var _k = _w / (_wx1 - _wx0);
    var _line_y = round(_y + _h * 0.62);
    var _blink = (current_time div 250) mod 2 == 0;

    // chao do corredor
    var _lx0 = max(_x, _x + (0 - _wx0) * _k);
    var _lx1 = min(_x + _w, _x + (_map.width - _wx0) * _k);
    if (_lx1 > _lx0) {
        draw_set_colour(make_colour_rgb(58, 64, 96));
        draw_rectangle(_lx0, _line_y - 1, _lx1, _line_y + 1, false);
    }

    // trechos de combate e chefe
    for (var _i = 0; _i < array_length(_map.sections); _i++) {
        var _s = _map.sections[_i];
        var _sx0 = _x + (_s.x1 - _wx0) * _k + 2;
        var _sx1 = _x + (_s.x2 - _wx0) * _k - 2;
        if (_sx1 < _x || _sx0 > _x + _w) continue;
        _sx0 = max(_sx0, _x);
        _sx1 = min(_sx1, _x + _w);

        var _boss = (_s.kind == "boss");
        var _done = _boss ? _map.completed : (_s.state == "cleared");
        var _base = room_kind_colour(_boss ? "boss" : "combat");
        var _col;
        if (_done) _col = make_colour_rgb(84, 92, 128);
        else if (_s.state == "active") _col = _blink ? _base : merge_colour(_base, c_white, 0.35);
        else _col = merge_colour(_base, c_black, 0.45);
        draw_set_colour(_col);
        draw_rectangle(_sx0, _line_y - 3, _sx1, _line_y + 3, false);

        if (_boss) {
            // losango do chefe no meio da arena
            var _bx = _x + ((_s.x1 + _s.x2) * 0.5 - _wx0) * _k;
            if (_bx > _x - 8 && _bx < _x + _w + 8) {
                var _by = _line_y - 12;
                draw_set_colour(c_black);
                draw_triangle(_bx - 7, _by, _bx + 7, _by, _bx, _by - 8, false);
                draw_triangle(_bx - 7, _by, _bx + 7, _by, _bx, _by + 8, false);
                draw_set_colour(_done ? make_colour_rgb(84, 92, 128) : _base);
                draw_triangle(_bx - 5, _by, _bx + 5, _by, _bx, _by - 6, false);
                draw_triangle(_bx - 5, _by, _bx + 5, _by, _bx, _by + 6, false);
                if (_labels) {
                    draw_set_halign(fa_center);
                    hud_text(_bx, _line_y + 8, "CHEFE", _done ? make_colour_rgb(120, 128, 160) : _base);
                }
            }
        }
    }

    // entradas das salas especiais: portinhas acima do chao
    for (var _i = 0; _i < array_length(_map.specials); _i++) {
        var _sp = _map.specials[_i];
        var _dx = round(_x + (_sp.x - _wx0) * _k);
        if (_dx < _x - 6 || _dx > _x + _w + 6) continue;
        var _rooms = global.run.special_rooms;
        var _used = variable_struct_exists(_rooms, _sp.target_sid) && _rooms[$ _sp.target_sid].used;
        var _col = _used ? make_colour_rgb(96, 102, 136) : room_kind_colour(_sp.room_kind);
        draw_set_colour(c_black);
        draw_rectangle(_dx - 5, _line_y - 16, _dx + 5, _line_y - 3, false);
        draw_set_colour(_col);
        draw_rectangle(_dx - 4, _line_y - 15, _dx + 4, _line_y - 4, false);
        draw_set_colour(c_black);
        draw_rectangle(_dx - 2, _line_y - 12, _dx + 2, _line_y - 4, false);
        if (_labels) {
            draw_set_halign(fa_center);
            hud_text(_dx, _line_y - 34, room_kind_label(_sp.room_kind), _col);
        }
    }

    // jogador
    if (_here) {
        var _px = round(_x + (minimap_player_x(_map) - _wx0) * _k);
        if (_px >= _x - 4 && _px <= _x + _w + 4) {
            var _gold = make_colour_rgb(255, 210, 63);
            var _r = 5 + ((current_time div 120) mod 4);
            draw_set_colour(_gold);
            draw_set_alpha(draw_get_alpha() * 0.5);
            draw_circle(_px, _line_y, _r, true);
            draw_set_alpha(draw_get_alpha() * 2);
            draw_set_colour(c_black);
            draw_circle(_px, _line_y, 4, false);
            draw_set_colour(c_white);
            draw_circle(_px, _line_y, 3, false);
            // seta para o lado que ele olha
            var _f = minimap_player_facing();
            draw_set_colour(_gold);
            draw_triangle(_px + _f * 5, _line_y - 3, _px + _f * 5, _line_y + 3, _px + _f * 9, _line_y, false);
        }
    }
    draw_set_colour(c_white);
}

/// Fundo e moldura dos quadros do mapa.
function minimap_frame(_x, _y, _w, _h, _alpha) {
    draw_set_alpha(0.78 * _alpha);
    draw_set_colour(make_colour_rgb(10, 12, 26));
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_alpha(_alpha);
    draw_set_colour(make_colour_rgb(45, 226, 230));
    draw_rectangle(_x, _y, _x + _w, _y + _h, true);
    draw_set_colour(make_colour_rgb(20, 70, 90));
    draw_rectangle(_x + 2, _y + 2, _x + _w - 2, _y + _h - 2, true);
    draw_set_colour(c_white);
}

/// Minimapa do canto: o corredor e desenhado numa surface e copiado em tiras
/// verticais. Perto das laterais as tiras ficam transparentes e misturam
/// colunas vizinhas, o que esmaece e borra a borda da "camera".
function minimap_draw_corner(_map, _alpha) {
    if (_alpha <= 0) return;
    var _st = minimap_state();
    var _gw = CFG.view.gui_w;
    var _gh = CFG.view.gui_h;
    var _x = _gw - MINIMAP_MARGIN - MINIMAP_W;
    var _y = _gh - MINIMAP_MARGIN - MINIMAP_H;

    if (!surface_exists(_st.surf)) _st.surf = surface_create(MINIMAP_W, MINIMAP_H);
    var _cx = minimap_player_x(_map);
    surface_set_target(_st.surf);
    draw_clear_alpha(c_black, 0);
    draw_set_alpha(1);
    minimap_draw_corridor(_map, 0, 0, MINIMAP_W, MINIMAP_H,
        _cx - MINIMAP_SPAN * 0.5, _cx + MINIMAP_SPAN * 0.5, false, true);
    surface_reset_target();

    minimap_frame(_x, _y, MINIMAP_W, MINIMAP_H, _alpha);

    var _step = 2;
    for (var _sx = 0; _sx < MINIMAP_W; _sx += _step) {
        var _edge = min(_sx, MINIMAP_W - _sx - _step);
        var _t = clamp(_edge / MINIMAP_FADE, 0, 1);
        if (_t >= 1) {
            draw_surface_part_ext(_st.surf, _sx, 0, _step, MINIMAP_H, _x + _sx, _y, 1, 1, c_white, _alpha);
            continue;
        }
        // borda: mistura colunas vizinhas (borrao) e some aos poucos
        var _a = _alpha * _t * _t;
        var _r = round((1 - _t) * 4);
        var _sl = clamp(_sx - _r, 0, MINIMAP_W - _step);
        var _sr = clamp(_sx + _r, 0, MINIMAP_W - _step);
        draw_surface_part_ext(_st.surf, _sx, 0, _step, MINIMAP_H, _x + _sx, _y, 1, 1, c_white, _a * 0.4);
        draw_surface_part_ext(_st.surf, _sl, 0, _step, MINIMAP_H, _x + _sx, _y - 1, 1, 1, c_white, _a * 0.3);
        draw_surface_part_ext(_st.surf, _sr, 0, _step, MINIMAP_H, _x + _sx, _y + 1, 1, 1, c_white, _a * 0.3);
    }

    // nome do bioma e dica do mapa completo
    draw_set_alpha(_alpha);
    draw_set_halign(fa_left);
    hud_text(_x + 6, _y + 3, _map.name, make_colour_rgb(170, 180, 220));
    draw_set_halign(fa_right);
    hud_text(_x + MINIMAP_W - 6, _y + 3, "[" + input_action_label(ACT.MAP) + "]", make_colour_rgb(120, 128, 170));
    draw_set_alpha(1);
}

/// Mapa completo: um corredor por bioma, de cima para baixo, com legenda.
function minimap_draw_full(_x, _y, _w, _h, _alpha) {
    var _maps = global.run.maps;
    var _cur = global.run.map_index;
    var _n = array_length(_maps);
    var _gold = make_colour_rgb(255, 210, 63);
    var _dim = make_colour_rgb(120, 128, 160);

    draw_set_alpha(_alpha);
    draw_set_halign(fa_center);
    hud_text(_x + _w * 0.5, _y + 12, "MAPA DA RUN", make_colour_rgb(45, 226, 230));

    var _row_h = 72;
    var _top = _y + 44;
    var _name_w = 130;
    var _sx = _x + 20 + _name_w;
    var _sw = _w - 40 - _name_w;
    for (var _i = 0; _i < _n; _i++) {
        var _m = _maps[_i];
        var _ry = _top + _i * _row_h;
        var _here = (_i == _cur);
        var _future = (_i > _cur);

        draw_set_halign(fa_left);
        hud_text(_x + 20, _ry + 26, _m.name, _here ? _gold : (_future ? make_colour_rgb(80, 86, 116) : _dim));
        if (_m.completed) hud_text(_x + 20, _ry + 44, "concluido", _dim);
        else if (_here) hud_text(_x + 20, _ry + 44, "voce esta aqui", _gold);

        if (_future) {
            // corredores ainda nao visitados: so a linha, sem revelar o conteudo
            draw_set_colour(make_colour_rgb(46, 50, 76));
            for (var _d = 0; _d < _sw; _d += 12) {
                draw_rectangle(_sx + _d, _ry + 44, _sx + min(_d + 6, _sw), _ry + 46, false);
            }
            draw_set_halign(fa_center);
            hud_text(_sx + _sw * 0.5, _ry + 22, "???", make_colour_rgb(80, 86, 116));
            continue;
        }
        draw_set_alpha(_alpha * (_m.completed && !_here ? 0.55 : 1));
        minimap_draw_corridor(_m, _sx, _ry, _sw, _row_h, 0, _m.width, _here, _here);
        draw_set_alpha(_alpha);
    }

    // legenda
    var _ly = _y + _h - 30;
    var _items = [
        ["combat", "COMBATE"], ["reward", "TESOURO"], ["challenge", "DESAFIO"],
        ["shop", "LOJA"], ["rest", "DESCANSO"], ["boss", "CHEFE"]
    ];
    var _ix = _x + 24;
    draw_set_halign(fa_left);
    for (var _i = 0; _i < array_length(_items); _i++) {
        draw_set_colour(room_kind_colour(_items[_i][0]));
        draw_rectangle(_ix, _ly + 4, _ix + 9, _ly + 13, false);
        hud_text(_ix + 14, _ly, _items[_i][1], c_white);
        _ix += 26 + string_width(_items[_i][1]);
    }
    draw_set_colour(c_white);
    draw_circle(_ix + 4, _ly + 8, 4, false);
    hud_text(_ix + 14, _ly, "VOCE", _gold);
    draw_set_halign(fa_left);
    draw_set_alpha(1);
}

/// Chamado pelo hud_draw. Segurar ACT.MAP abre o mapa completo com uma
/// transicao: o quadro do canto cresce ate o centro da tela.
function minimap_draw() {
    var _st = minimap_state();
    if (!minimap_available()) {
        _st.t = 0;
        return;
    }
    var _map = run_current_map();
    var _open = input_held(ACT.MAP) && global.flow.state == FLOW.PLAY;
    _st.t = clamp(_st.t + (_open ? 0.12 : -0.16), 0, 1);
    var _e = _st.t * _st.t * (3 - 2 * _st.t); // suaviza o inicio e o fim

    var _gw = CFG.view.gui_w;
    var _gh = CFG.view.gui_h;

    // minimapa do canto some enquanto o quadro cresce
    minimap_draw_corner(_map, 1 - min(1, _e * 3));
    if (_e <= 0) return;

    var _n = array_length(global.run.maps);
    var _fw = 760;
    var _fh = 44 + _n * 72 + 44;
    var _fx = (_gw - _fw) * 0.5;
    var _fy = (_gh - _fh) * 0.5;
    var _cx = _gw - MINIMAP_MARGIN - MINIMAP_W;
    var _cy = _gh - MINIMAP_MARGIN - MINIMAP_H;

    // escurece o jogo por tras
    draw_set_alpha(0.55 * _e);
    draw_set_colour(c_black);
    draw_rectangle(0, 0, _gw, _gh, false);

    var _x = lerp(_cx, _fx, _e);
    var _y = lerp(_cy, _fy, _e);
    var _w = lerp(MINIMAP_W, _fw, _e);
    var _h = lerp(MINIMAP_H, _fh, _e);
    minimap_frame(_x, _y, _w, _h, 1);
    if (_e > 0.6) minimap_draw_full(_x, _y, _w, _h, (_e - 0.6) / 0.4);

    draw_set_alpha(1);
    draw_set_colour(c_white);
    draw_set_halign(fa_left);
}
