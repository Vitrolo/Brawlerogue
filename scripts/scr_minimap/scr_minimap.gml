/// Minimapa do mapa 2D do bioma atual, desenhado no Draw GUI (coordenadas 960x540).
///
/// Canto inferior direito (compacto): uma janela da grade em volta do jogador,
/// com cerca de 7 celulas e 3 faixas, laterais esmaecidas.
/// Segurando ACT.MAP (TAB) o quadro cresce ate o centro (expandido) e mostra a
/// grade inteira do bioma, a ordem dos biomas da run e a legenda.
///
/// Tudo vem do proprio mapa (global.run.maps, ver scr_level): cada celula
/// ocupada vira um trecho de barra na linha da faixa dela, as escadas viram
/// tracos verticais entre as faixas e as portas viram icones. Nevoa:
///   visitado (chunk.discovered)  cor do tipo e do estado do combate
///   conhecido (chunk.seen)       contorno tracejado com "?"
///   desconhecido                 nao aparece
/// Nada aqui altera o jogo.

#macro MINIMAP_W 232
#macro MINIMAP_H 96
#macro MINIMAP_MARGIN 18
#macro MINIMAP_CELL 34     // largura de uma celula no quadro do canto
#macro MINIMAP_ROW 28      // distancia entre faixas no quadro do canto
#macro MINIMAP_FADE 40     // largura das bordas esmaecidas, em pixels da interface
#macro MINIMAP_FULL_W 760
#macro MINIMAP_FULL_H 420

function minimap_state() {
    if (!variable_global_exists("minimap")) {
        global.minimap = { t: 0, surf: -1 };
    }
    return global.minimap;
}

/// Ha um mapa para mostrar (run ativa, fora do lobby).
function minimap_available() {
    if (!global.run.active) return false;
    return !is_undefined(run_current_map());
}

/// Posicao do jogador no mapa: [x do mundo, faixa (fracionada na escada), lado].
/// Dentro de uma sala interior vale a porta por onde ele entrou.
function minimap_player_pos(_map) {
    if (global.stage.kind == "main_map") {
        var _p = instance_find(obj_player, 0);
        if (_p != noone) {
            var _band = floor(_p.y / _map.band_h);
            if (_p.state == PS.CLIMB && _p.climb_link >= 0) {
                var _k = _map.links[_p.climb_link];
                _band = lerp(_map.chunks[_k.a].band, _map.chunks[_k.b].band, level_smooth(_p.climb_t));
            }
            return [_p.x, _band, _p.facing];
        }
    }
    var _ctx = global.run.return_context;
    if (!is_undefined(_ctx) && _ctx.stage_sid == _map.sid) return [_ctx.x, floor(_ctx.y / _map.band_h), _ctx.facing];
    var _st = _map.chunks[_map.start];
    return [_st.x1 + 60, _st.band, 1];
}

/// Cor de um chunk visitado: combates pelo estado, os demais pelo tipo.
function minimap_chunk_colour(_map, _ch) {
    var _blink = (current_time div 250) mod 2 == 0;
    switch (_ch.type) {
        case "combat":
        case "exit_combat":
        case "horde":
        case "boss":
            var _base = room_kind_colour("combat");
            if (_ch.type == "boss") _base = room_kind_colour("boss");
            if (_ch.type == "horde") _base = make_colour_rgb(255, 90, 60);
            var _done = (_ch.type == "boss") ? _map.completed : (_ch.state == "cleared");
            if (_done) return make_colour_rgb(84, 92, 128);
            if (_ch.state == "active") return _blink ? _base : merge_colour(_base, c_white, 0.35);
            return merge_colour(_base, c_black, 0.3);
        case "dead_end":
            return make_colour_rgb(150, 132, 210);
        case "junction":
            return make_colour_rgb(70, 150, 170);
        case "shop":
        case "reward":
        case "rest":
        case "challenge":
            // sala ja usada fica apagada
            var _rooms = global.run.special_rooms;
            if (variable_struct_exists(_rooms, _ch.sid) && _rooms[$ _ch.sid].used) return make_colour_rgb(96, 102, 136);
            return room_kind_colour(_ch.type);
    }
    return make_colour_rgb(72, 80, 112);
}

/// Desenha o mapa com a coluna 0 em _ox e a faixa 0 em _oy: cada celula tem _cw
/// px de largura e cada faixa _rh px de altura. _labels escreve os tipos das
/// salas e o chefe (mapa expandido).
function minimap_draw_level(_map, _ox, _oy, _cw, _rh, _labels) {
    var _kx = _cw / _map.cell_w;
    var _half = max(3, round(_rh * 0.14));   // meia altura da barra

    // escadas: atras das barras, quando uma das pontas ja foi visitada
    for (var _i = 0; _i < array_length(_map.stairs); _i++) {
        var _k = _map.links[_map.stairs[_i]];
        var _low = _map.chunks[_k.a];
        var _up = _map.chunks[_k.b];
        if (!_low.discovered && !_up.discovered) continue;
        var _sx = round(_ox + (_k.x_foot + _k.x_top) * 0.5 * _kx);
        var _y1 = _oy + (_up.band + 0.5) * _rh + _half;
        var _y2 = _oy + (_low.band + 0.5) * _rh - _half;
        draw_set_colour(c_black);
        draw_rectangle(_sx - 2, _y1, _sx + 2, _y2, false);
        draw_set_colour(make_colour_rgb(70, 190, 210));
        draw_rectangle(_sx - 1, _y1, _sx + 1, _y2, false);
    }

    for (var _i = 0; _i < array_length(_map.chunks); _i++) {
        var _ch = _map.chunks[_i];
        if (!_ch.on_grid || !_ch.seen) continue;
        var _x1 = round(_ox + _ch.col * _cw);
        var _x2 = _x1 + _cw - 1;
        var _y = round(_oy + (_ch.band + 0.5) * _rh);

        if (!_ch.discovered) {
            // conhecido mas nao visitado: tracejado, sem revelar o conteudo
            draw_set_colour(make_colour_rgb(70, 76, 108));
            for (var _d = _x1; _d < _x2; _d += 6) {
                draw_rectangle(_d, _y - _half, min(_d + 2, _x2), _y - _half + 1, false);
                draw_rectangle(_d, _y + _half - 1, min(_d + 2, _x2), _y + _half, false);
            }
            if (_cw >= 20) {
                draw_set_halign(fa_center);
                draw_set_valign(fa_middle);
                hud_text((_x1 + _x2) * 0.5, _y, "?", make_colour_rgb(110, 118, 160));
                draw_set_valign(fa_top);
            }
            continue;
        }

        draw_set_colour(c_black);
        draw_rectangle(_x1, _y - _half - 1, _x2 + 1, _y + _half + 1, false);
        draw_set_colour(minimap_chunk_colour(_map, _ch));
        draw_rectangle(_x1 + 1, _y - _half, _x2, _y + _half, false);

        if (_ch.type == "boss") {
            // losango do chefe
            var _bx = (_x1 + _x2) * 0.5;
            var _by = _y - _half - 9;
            draw_set_colour(c_black);
            draw_triangle(_bx - 7, _by, _bx + 7, _by, _bx, _by - 8, false);
            draw_triangle(_bx - 7, _by, _bx + 7, _by, _bx, _by + 8, false);
            draw_set_colour(_map.completed ? make_colour_rgb(84, 92, 128) : room_kind_colour("boss"));
            draw_triangle(_bx - 5, _by, _bx + 5, _by, _bx, _by - 6, false);
            draw_triangle(_bx - 5, _by, _bx + 5, _by, _bx, _by + 6, false);
            if (_labels) {
                draw_set_halign(fa_center);
                hud_text(_bx, _y + _half + 2, "CHEFE", _map.completed ? make_colour_rgb(120, 128, 160) : room_kind_colour("boss"));
            }
        }

        if (chunk_is_room(_ch.type)) {
            // sala: quadradinho com a cor do tipo acima da barra
            var _col = minimap_chunk_colour(_map, _ch);
            var _rx = round(_ox + _ch.room_x * _kx);
            var _top = _y - _half - 11;
            draw_set_colour(c_black);
            draw_rectangle(_rx - 5, _top - 1, _rx + 5, _y - _half, false);
            draw_set_colour(_col);
            draw_rectangle(_rx - 4, _top, _rx + 4, _y - _half - 1, false);
            if (_labels) {
                draw_set_halign(fa_center);
                hud_text(_rx, _top - 17, room_kind_label(_ch.type), _col);
            }
        }
    }
    draw_set_colour(c_white);
}

/// Marcador do jogador: circulo branco com halo e seta para o lado em que olha.
function minimap_draw_player(_px, _py, _facing) {
    var _gold = make_colour_rgb(255, 210, 63);
    var _r = 5 + ((current_time div 120) mod 4);
    var _a = draw_get_alpha();
    draw_set_colour(_gold);
    draw_set_alpha(_a * 0.5);
    draw_circle(_px, _py, _r, true);
    draw_set_alpha(_a);
    draw_set_colour(c_black);
    draw_circle(_px, _py, 4, false);
    draw_set_colour(c_white);
    draw_circle(_px, _py, 3, false);
    draw_set_colour(_gold);
    draw_triangle(_px + _facing * 5, _py - 3, _px + _facing * 5, _py + 3, _px + _facing * 9, _py, false);
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

/// Quadro do canto: a grade e desenhada numa surface com o jogador no centro e
/// copiada em tiras verticais; perto das laterais as tiras ficam transparentes e
/// misturam colunas vizinhas (borda esmaecida da "camera").
function minimap_draw_corner(_map, _alpha) {
    if (_alpha <= 0) return;
    var _st = minimap_state();
    var _gw = CFG.view.gui_w;
    var _gh = CFG.view.gui_h;
    var _x = _gw - MINIMAP_MARGIN - MINIMAP_W;
    var _y = _gh - MINIMAP_MARGIN - MINIMAP_H;

    if (surface_exists(_st.surf) && (surface_get_width(_st.surf) != MINIMAP_W || surface_get_height(_st.surf) != MINIMAP_H)) {
        surface_free(_st.surf);
    }
    if (!surface_exists(_st.surf)) _st.surf = surface_create(MINIMAP_W, MINIMAP_H);
    var _pp = minimap_player_pos(_map);
    var _ox = MINIMAP_W * 0.5 - _pp[0] / _map.cell_w * MINIMAP_CELL;
    var _oy = MINIMAP_H * 0.5 + 8 - (_pp[1] + 0.5) * MINIMAP_ROW;
    surface_set_target(_st.surf);
    draw_clear_alpha(c_black, 0);
    draw_set_alpha(1);
    minimap_draw_level(_map, _ox, _oy, MINIMAP_CELL, MINIMAP_ROW, false);
    minimap_draw_player(MINIMAP_W * 0.5, MINIMAP_H * 0.5 + 8, _pp[2]);
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

    // nome do bioma, nivel atual e dica do mapa expandido
    draw_set_alpha(_alpha);
    draw_set_halign(fa_left);
    hud_text(_x + 6, _y + 3, _map.name, make_colour_rgb(170, 180, 220));
    draw_set_halign(fa_right);
    hud_text(_x + MINIMAP_W - 6, _y + 3, "[" + input_action_label(ACT.MAP) + "]", make_colour_rgb(120, 128, 170));
    draw_set_alpha(1);
}

/// Mapa expandido: a grade inteira do bioma atual, a ordem dos biomas da run e
/// a legenda.
function minimap_draw_full(_x, _y, _w, _h, _alpha) {
    var _map = run_current_map();
    var _gold = make_colour_rgb(255, 210, 63);
    var _dim = make_colour_rgb(120, 128, 160);

    draw_set_alpha(_alpha);
    draw_set_halign(fa_center);
    hud_text(_x + _w * 0.5, _y + 10, "MAPA - " + _map.name, make_colour_rgb(45, 226, 230));

    // biomas da run: concluidos, atual e os proximos sem nome
    var _parts = [];
    for (var _i = 0; _i < array_length(global.run.maps); _i++) {
        var _m = global.run.maps[_i];
        var _txt = (_i > global.run.map_index) ? "???" : _m.name;
        if (_m.completed && _i != global.run.map_index) _txt += " (ok)";
        array_push(_parts, [_txt, (_i == global.run.map_index) ? _gold : ((_i < global.run.map_index) ? _dim : make_colour_rgb(80, 86, 116))]);
    }
    var _total = 0;
    for (var _i = 0; _i < array_length(_parts); _i++) _total += string_width(_parts[_i][0]) + ((_i > 0) ? string_width("  >  ") : 0);
    var _bx = _x + (_w - _total) * 0.5;
    draw_set_halign(fa_left);
    for (var _i = 0; _i < array_length(_parts); _i++) {
        if (_i > 0) {
            hud_text(_bx, _y + 30, "  >  ", _dim);
            _bx += string_width("  >  ");
        }
        hud_text(_bx, _y + 30, _parts[_i][0], _parts[_i][1]);
        _bx += string_width(_parts[_i][0]);
    }

    // grade do bioma, centralizada na area livre
    var _ax = _x + 24;
    var _ay = _y + 70;
    var _aw = _w - 48;
    var _ah = _h - 70 - 56;
    var _cw = min(64, floor(_aw / _map.cols));
    var _rh = min(64, floor(_ah / _map.bands));
    var _ox = _ax + (_aw - _cw * _map.cols) * 0.5;
    var _oy = _ay + (_ah - _rh * _map.bands) * 0.5;
    minimap_draw_level(_map, _ox, _oy, _cw, _rh, true);
    var _pp = minimap_player_pos(_map);
    minimap_draw_player(_ox + _pp[0] / _map.cell_w * _cw, _oy + (_pp[1] + 0.5) * _rh, _pp[2]);

    // legenda (quebra em duas linhas se precisar)
    var _items = [
        [room_kind_colour("combat"), "COMBATE"], [make_colour_rgb(255, 90, 60), "HORDA"],
        [make_colour_rgb(150, 132, 210), "BECO"], [make_colour_rgb(70, 190, 210), "ESCADA"],
        [room_kind_colour("reward"), "TESOURO"], [room_kind_colour("challenge"), "DESAFIO"],
        [room_kind_colour("shop"), "LOJA"], [room_kind_colour("rest"), "DESCANSO"],
        [room_kind_colour("boss"), "CHEFE"]
    ];
    var _lx = _x + 24;
    var _ly = _y + _h - 46;
    draw_set_halign(fa_left);
    for (var _i = 0; _i < array_length(_items); _i++) {
        var _iw = 26 + string_width(_items[_i][1]);
        if (_lx + _iw > _x + _w - 24) {
            _lx = _x + 24;
            _ly += 20;
        }
        draw_set_colour(_items[_i][0]);
        draw_rectangle(_lx, _ly + 4, _lx + 9, _ly + 13, false);
        hud_text(_lx + 14, _ly, _items[_i][1], c_white);
        _lx += _iw;
    }
    draw_set_colour(c_white);
    draw_circle(_lx + 4, _ly + 8, 4, false);
    hud_text(_lx + 14, _ly, "VOCE  ? = conhecido, nao visitado", _gold);
    draw_set_halign(fa_left);
    draw_set_alpha(1);
}

/// Chamado pelo hud_draw. Segurar ACT.MAP abre o mapa expandido com uma
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

    var _fx = (_gw - MINIMAP_FULL_W) * 0.5;
    var _fy = (_gh - MINIMAP_FULL_H) * 0.5;
    var _cx = _gw - MINIMAP_MARGIN - MINIMAP_W;
    var _cy = _gh - MINIMAP_MARGIN - MINIMAP_H;

    // escurece o jogo por tras
    draw_set_alpha(0.55 * _e);
    draw_set_colour(c_black);
    draw_rectangle(0, 0, _gw, _gh, false);

    var _x = lerp(_cx, _fx, _e);
    var _y = lerp(_cy, _fy, _e);
    var _w = lerp(MINIMAP_W, MINIMAP_FULL_W, _e);
    var _h = lerp(MINIMAP_H, MINIMAP_FULL_H, _e);
    minimap_frame(_x, _y, _w, _h, 1);
    if (_e > 0.6) minimap_draw_full(_x, _y, _w, _h, (_e - 0.6) / 0.4);

    draw_set_alpha(1);
    draw_set_colour(c_white);
    draw_set_halign(fa_left);
}
