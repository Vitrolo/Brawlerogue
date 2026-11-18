/// Cenarios pintados, um sprite por bioma (spr_bg_<bioma>, 768x272, gerados no PixelLab).
/// Tudo aqui e apenas visual: nada gera colisao.
///
/// Cada imagem tem a parede em cima e o chao embaixo, mas a linha onde o chao comeca
/// muda de uma para outra. stage_backdrop_info diz, em pixels da imagem:
///   horizon  - linha onde o chao comeca; e alinhada com o topo do chao do jogo
///   band_y0, band_y1 - faixa de chao que se repete para baixo ate cobrir a tela.
///       Deve ser UMA fileira de piso limpa: sem pocas, reflexos, luzes ou pes de
///       objetos, senao esses detalhes aparecem duplicados no chao.
///   band_shift - quanto cada copia da faixa anda para o lado, para as rachaduras
///       nao se alinharem em colunas. Use 0 se algo vertical cruza a faixa (o
///       pilar do lobby) ou se a faixa nao chega a aparecer repetida.
/// A imagem se repete na horizontal espelhando uma copia sim, uma nao, para a emenda
/// nao aparecer. Para trocar um cenario: substitua o PNG em tools/pixellab_raw, rode
/// tools/import_pixellab.py e ajuste as tres linhas do bioma aqui.

/// Pseudoaleatorio deterministico em [0,1) que nao mexe na seed da run.
function decor_rand(_seed, _i) {
    return frac(abs(sin(_seed * 12.9898 + _i * 78.233) * 43758.5453));
}

function stage_backdrop_info(_biome) {
    switch (_biome) {
        case "sewer":    return { sprite: spr_bg_sewer,    horizon: 205, band_y0: 228, band_y1: 249, band_shift: 173 };
        case "streets":  return { sprite: spr_bg_streets,  horizon: 138, band_y0: 156, band_y1: 243, band_shift: 0 };
        case "rooftops": return { sprite: spr_bg_rooftops, horizon: 190, band_y0: 236, band_y1: 272, band_shift: 173 };
        case "boss":     return { sprite: spr_bg_boss,     horizon: 228, band_y0: 254, band_y1: 272, band_shift: 173 };
        default:         return { sprite: spr_bg_lobby,    horizon: 203, band_y0: 223, band_y1: 238, band_shift: 0 };
    }
}

/// Centro da entrada integrada dentro do tile de 768 px do cenario. Cada bioma tem
/// trechos de parede livres diferentes (sem canos, janelas ou lojas por baixo).
/// Mesma tabela de ART_CENTERS em tools/import_v2_art.py.
function stage_entrance_img_x(_biome, _kind) {
    switch (_biome) {
        case "sewer":
            switch (_kind) { case "reward": return 560; case "challenge": return 240; case "shop": return 470; default: return 32; }
        case "streets":
            return (_kind == "reward" || _kind == "shop") ? 630 : 219;
        case "rooftops":
            return (_kind == "reward" || _kind == "shop") ? 505 : 295;
    }
    return 384;
}

/// Variante de cenario que contem a entrada integrada para este tipo de local.
function stage_backdrop_entrance(_biome, _kind) {
    switch (_biome) {
        case "sewer":
            switch (_kind) {
                case "reward": return spr_bg_chunk_sewer_reward;
                case "challenge": return spr_bg_chunk_sewer_challenge;
                case "shop": return spr_bg_chunk_sewer_shop;
                case "rest": return spr_bg_chunk_sewer_rest;
            }
            break;
        case "streets":
            switch (_kind) {
                case "reward": return spr_bg_chunk_streets_reward;
                case "challenge": return spr_bg_chunk_streets_challenge;
                case "shop": return spr_bg_chunk_streets_shop;
                case "rest": return spr_bg_chunk_streets_rest;
            }
            break;
        case "rooftops":
            switch (_kind) {
                case "reward": return spr_bg_chunk_rooftops_reward;
                case "challenge": return spr_bg_chunk_rooftops_challenge;
                case "shop": return spr_bg_chunk_rooftops_shop;
                case "rest": return spr_bg_chunk_rooftops_rest;
            }
            break;
    }
    return -1;
}

/// Interior fixo de cada sala especial. Evento usa o visual de desafio.
function stage_backdrop_special(_biome, _kind) {
    if (_kind == "event") _kind = "challenge";
    switch (_biome) {
        case "sewer":
            switch (_kind) {
                case "reward": return spr_interior_sewer_reward;
                case "challenge": return spr_interior_sewer_challenge;
                case "shop": return spr_interior_sewer_shop;
                case "rest": return spr_interior_sewer_rest;
            }
            break;
        case "streets":
            switch (_kind) {
                case "reward": return spr_interior_streets_reward;
                case "challenge": return spr_interior_streets_challenge;
                case "shop": return spr_interior_streets_shop;
                case "rest": return spr_interior_streets_rest;
            }
            break;
        case "rooftops":
            switch (_kind) {
                case "reward": return spr_interior_rooftops_reward;
                case "challenge": return spr_interior_rooftops_challenge;
                case "shop": return spr_interior_rooftops_shop;
                case "rest": return spr_interior_rooftops_rest;
            }
            break;
    }
    return -1;
}

function stage_draw_placeholder() {
    var _s = global.stage;
    var _special_spr = stage_backdrop_special(_s.biome, _s.kind);
    if (_special_spr >= 0) {
        // Modulos especiais ocupam exatamente a tela; a camera fica em x=0.
        draw_set_alpha(1);
        draw_set_colour(c_white);
        draw_sprite_part(_special_spr, 0, 0, 0, VIEW_W, VIEW_H, 0, 0);
        return;
    }
    if (variable_struct_exists(_s, "black_background") && _s.black_background) {
        draw_set_alpha(1);
        draw_set_colour(c_black);
        draw_rectangle(-16, -16, VIEW_W + 16, VIEW_H + 16, false);
        draw_set_colour(c_white);
        return;
    }
    var _map = level_current_map();
    if (!is_undefined(_map)) {
        stage_draw_level(_map);
        return;
    }

    // Salas de uma faixa so (lobby): o cenario cobre a largura inteira.
    var _info = stage_backdrop_info(_s.biome);
    var _spr = _info.sprite;
    var _w = sprite_get_width(_spr);
    var _floor_y = _s.floor_top - 8;            // topo do chao na tela
    var _oy = _floor_y - _info.horizon;         // deslocamento vertical da imagem
    var _band_h = _info.band_y1 - _info.band_y0;
    var _bottom = VIEW_H + 16;                  // margem para o tremor da camera

    draw_set_alpha(1);
    draw_set_colour(_s.palette.sky);
    draw_rectangle(-16, -16, _s.width + 16, _bottom, false);
    draw_set_colour(c_white);

    for (var _i = -1; _i * _w < _s.width + 16; _i++) {
        var _flip = (_i mod 2 != 0);
        var _x = _i * _w + (_flip ? _w : 0);
        var _xs = _flip ? -1 : 1;
        // parede e primeira faixa de chao
        draw_sprite_part_ext(_spr, 0, 0, 0, _w, _info.band_y1, _x, _oy, _xs, 1, c_white, 1);
        // a imagem pode comecar abaixo do topo da tela: estica a primeira linha para cima
        if (_oy > -16) {
            draw_sprite_part_ext(_spr, 0, 0, 0, _w, 1, _x, -16, _xs, _oy + 16, c_white, 1);
        }
    }

    // Repete a faixa de chao ate o fim da tela. Cada copia e uma tira propria,
    // espelhada tile a tile como o fundo, mas deslocada na horizontal.
    var _row = 1;
    for (var _y = _oy + _info.band_y1; _y < _bottom; _y += _band_h) {
        backdrop_strip(_spr, _info.band_y0, _band_h, -((_row * _info.band_shift) mod _w), _y, -16, _s.width + 16);
        _row++;
    }
}

/// Desenha as linhas [_sy, _sy + _sh) da imagem repetida na horizontal (um tile
/// sim, um nao, espelhado), com os tiles comecando em _ox + k * largura, na
/// altura _dy e recortada entre _cx1 e _cx2 no mundo.
function backdrop_strip(_spr, _sy, _sh, _ox, _dy, _cx1, _cx2) {
    if (_sh <= 0 || _cx2 <= _cx1) return;
    var _w = sprite_get_width(_spr);
    var _j1 = floor((_cx1 - _ox) / _w);
    var _j2 = floor((_cx2 - 1 - _ox) / _w);
    for (var _j = _j1; _j <= _j2; _j++) {
        var _tx = _ox + _j * _w;
        var _d0 = max(_tx, _cx1);
        var _d1 = min(_tx + _w, _cx2);
        if (_d1 <= _d0) continue;
        if (_j mod 2 != 0) {
            // espelhado: a coluna d do mundo mostra a coluna (largura - 1 - (d - tx)) da imagem
            draw_sprite_part_ext(_spr, 0, _tx + _w - _d1, _sy, _d1 - _d0, _sh, _d1, _dy, -1, 1, c_white, 1);
        } else {
            draw_sprite_part_ext(_spr, 0, _d0 - _tx, _sy, _d1 - _d0, _sh, _d0, _dy, 1, 1, c_white, 1);
        }
    }
}

// ------------------------------------------------------------ mapas 2D

/// Cenario de um mapa 2D: so as faixas e tiles que a camera ve. Cada corredor
/// desenha o cenario do bioma recortado nos proprios limites (com a variante de
/// entrada nas celulas com porta). Por cima vem o que liga as faixas: laje sob
/// o chao de cima, paredes de fim de corredor, escadas e aberturas.
function stage_draw_level(_map) {
    var _s = global.stage;
    var _info = stage_backdrop_info(_s.biome);
    var _cx = camera_get_view_x(view_camera[0]);
    var _cy = camera_get_view_y(view_camera[0]);
    var _vx1 = _cx - 16;
    var _vx2 = _cx + VIEW_W + 16;
    var _vy1 = _cy - 16;
    var _vy2 = _cy + VIEW_H + 16;

    // o que nao e corredor e massa escura (so aparece durante a escada)
    draw_set_alpha(1);
    draw_set_colour(merge_colour(_s.palette.wall_dark, c_black, 0.6));
    draw_rectangle(_vx1, _vy1, _vx2, _vy2, false);
    draw_set_colour(c_white);

    var _visible = [];
    for (var _i = 0; _i < array_length(_map.corridors); _i++) {
        var _c = _map.corridors[_i];
        if (_c.oy + _map.band_h < _vy1 || _c.oy > _vy2 || _c.x2 < _vx1 || _c.x1 > _vx2) continue;
        array_push(_visible, _c);
        stage_draw_corridor(_map, _c, _info, max(_c.x1, _vx1), min(_c.x2, _vx2));
    }
    for (var _i = 0; _i < array_length(_visible); _i++) stage_draw_corridor_edges(_map, _visible[_i]);
    for (var _i = 0; _i < array_length(_map.stairs); _i++) {
        var _k = _map.links[_map.stairs[_i]];
        if (min(_k.x_foot, _k.x_top) - 80 > _vx2 || max(_k.x_foot, _k.x_top) + 80 < _vx1) continue;
        if (_k.y_top - 40 > _vy2 || _k.y_foot + 20 < _vy1) continue;
        stage_draw_stairs(_k, global.stage.biome);
    }
}

/// Cenario de um corredor entre _dx1 e _dx2 (ja recortado na camera), preso a
/// faixa dele: a imagem nao vaza para a faixa de cima nem para a de baixo.
function stage_draw_corridor(_map, _c, _info, _dx1, _dx2) {
    var _s = global.stage;
    var _spr = level_band_sprite(_s.biome, _c.row, _info.sprite);
    var _w = sprite_get_width(_spr);
    var _top = _c.oy;
    var _bottom = _c.oy + _map.band_h;
    var _iy = _c.floor_top - 8 - _info.horizon;   // y do topo da imagem no mundo
    var _strip_h = _info.band_y1 - _info.band_y0;

    draw_set_colour(_s.palette.sky);
    draw_rectangle(_dx1, _top, _dx2, _bottom, false);
    draw_set_colour(c_white);

    // parede e primeira faixa de chao: um tile por celula (tile = coluna da grade)
    var _src_y0 = max(0, _top - _iy);
    var _src_y1 = min(_info.band_y1, _bottom - _iy);
    for (var _t = max(_c.c1, floor(_dx1 / _w)); _t <= min(_c.c2, floor((_dx2 - 1) / _w)); _t++) {
        var _flip = (_t mod 2 != 0);
        var _x = _t * _w + (_flip ? _w : 0);
        var _xs = _flip ? -1 : 1;
        var _tile_spr = _spr;
        var _cell = _map.grid[_c.band][_t];
        if (_cell >= 0 && _map.chunks[_cell].door >= 0) {
            var _variant = stage_backdrop_entrance(_s.biome, _map.chunks[_map.chunks[_cell].door].room_kind);
            if (_variant >= 0) _tile_spr = _variant;
        }
        if (_src_y1 > _src_y0) {
            draw_sprite_part_ext(_tile_spr, 0, 0, _src_y0, _w, _src_y1 - _src_y0, _x, _iy + _src_y0, _xs, 1, c_white, 1);
        }
        // a imagem comeca abaixo do topo da faixa: estica a primeira linha para cima
        if (_iy > _top) draw_sprite_part_ext(_tile_spr, 0, 0, 0, _w, 1, _x, _top, _xs, _iy - _top, c_white, 1);
    }

    // chao repetido ate a base da faixa, cada tira deslocada para as rachaduras
    // nao formarem colunas
    var _row = 1;
    var _x1 = max(_dx1, _c.x1);
    var _x2 = min(_dx2, _c.x2);
    for (var _y = _iy + _info.band_y1; _y < _bottom; _y += _strip_h) {
        backdrop_strip(_spr, _info.band_y0, min(_strip_h, _bottom - _y), -((_row * _info.band_shift) mod _w), _y, _x1, _x2);
        _row++;
    }
}

/// Bordas de um corredor: laje onde ha outro corredor logo acima (o chao dele
/// visto de baixo) e paredes nas pontas. A ponta direita do corredor do chefe e
/// a saida do bioma e fica aberta.
function stage_draw_corridor_edges(_map, _c) {
    var _biome = global.stage.biome;
    var _pal = global.stage.palette;
    if (_c.band > 0) {
        for (var _i = 0; _i < array_length(_map.corridors); _i++) {
            var _u = _map.corridors[_i];
            if (_u.band != _c.band - 1) continue;
            var _lx1 = max(_c.x1, _u.x1);
            var _lx2 = min(_c.x2, _u.x2);
            if (_lx2 > _lx1) stage_draw_slab(_lx1, _lx2, _c.oy, _biome, _pal);
        }
    }
    if (_c.cap_left) stage_draw_cap(_c.x1, -1, _c, _map.band_h, _biome, _pal);
    if (_c.cap_right) stage_draw_cap(_c.x2, 1, _c, _map.band_h, _biome, _pal);
}

// ------------------------------------------------------------ pecas de ligacao
// Cada peca usa a arte do bioma quando ela existe (level_art) e, sem ela, um
// desenho provisorio de formas simples na paleta do bioma.

/// Laje entre duas faixas, de _x1 a _x2, logo abaixo da linha _y (topo da faixa
/// de baixo): e o chao da faixa de cima visto por baixo.
function stage_draw_slab(_x1, _x2, _y, _biome, _pal) {
    var _spr = level_art(_biome, "slab");
    if (_spr >= 0) {
        backdrop_strip(_spr, 0, sprite_get_height(_spr), 0, _y, _x1, _x2);
        return;
    }
    draw_set_colour(merge_colour(_pal.floor_dark, c_black, 0.35));
    draw_rectangle(_x1, _y, _x2, _y + 14, false);
    draw_set_colour(_pal.floor);
    draw_rectangle(_x1, _y, _x2, _y + 2, false);
    draw_set_colour(c_white);
}

/// Parede de fim de corredor em _x. _side -1: a parede fecha a esquerda;
/// +1: fecha a direita (a parede fica para dentro do corredor).
function stage_draw_cap(_x, _side, _c, _band_h, _biome, _pal) {
    var _spr = level_art(_biome, "cap");
    if (_spr >= 0) {
        // a arte e da parede da esquerda; a da direita e espelhada
        if (_side < 0) draw_sprite_ext(_spr, 0, _x, _c.oy, 1, 1, 0, c_white, 1);
        else draw_sprite_ext(_spr, 0, _x, _c.oy, -1, 1, 0, c_white, 1);
        return;
    }
    var _w = 20;
    var _x1 = (_side < 0) ? _x : _x - _w;
    var _x2 = _x1 + _w;
    draw_set_colour(merge_colour(_pal.wall_dark, c_black, 0.25));
    draw_rectangle(_x1, _c.oy, _x2, _c.oy + _band_h, false);
    draw_set_colour(_pal.wall);
    for (var _y = _c.oy + 6; _y < _c.oy + _band_h; _y += 12) {
        draw_line(_x1, _y, _x2, _y);
        var _jx = ((_y div 12) mod 2 == 0) ? _x1 + 7 : _x1 + 14;
        draw_line(_jx, _y, _jx, _y + 12);
    }
    // aresta voltada para o corredor
    draw_set_colour(merge_colour(_pal.wall, c_white, 0.25));
    var _edge = (_side < 0) ? _x2 : _x1;
    draw_line(_edge, _c.oy, _edge, _c.oy + _band_h);
    draw_set_colour(c_white);
}

/// Escada: do pe (na parede do fundo da faixa de baixo) ao topo (na beirada da
/// frente da faixa de cima), com a abertura no chao de cima.
function stage_draw_stairs(_k, _biome) {
    var _pal = global.stage.palette;
    var _spr = level_art(_biome, "stairs");
    if (_spr >= 0) {
        // a arte sobe para a direita, com origem no pe; espelhada se subir para a
        // esquerda. O topo dela passa da beirada do chao de cima: e a chegada.
        draw_sprite_ext(_spr, 0, _k.x_foot, _k.y_foot, _k.rise, 1, 0, c_white, 1);
        return;
    } else {
        var _dark = merge_colour(_pal.wall_dark, c_black, 0.4);
        var _metal = merge_colour(_pal.floor, c_white, 0.15);
        // vigas laterais
        draw_set_colour(_dark);
        draw_line_width(_k.x_foot - 9, _k.y_foot + 2, _k.x_top - 9, _k.y_top + 2, 4);
        draw_line_width(_k.x_foot + 9, _k.y_foot + 2, _k.x_top + 9, _k.y_top + 2, 4);
        // degraus a cada 10 px de subida
        var _steps = max(1, floor((_k.y_foot - _k.y_top) / 10));
        for (var _i = 0; _i <= _steps; _i++) {
            var _t = _i / _steps;
            var _sx = lerp(_k.x_foot, _k.x_top, _t);
            var _sy = lerp(_k.y_foot, _k.y_top, _t);
            draw_set_colour(_dark);
            draw_rectangle(_sx - 11, _sy - 1, _sx + 11, _sy + 3, false);
            draw_set_colour(_metal);
            draw_line(_sx - 10, _sy - 1, _sx + 10, _sy - 1);
        }
        // corrimao
        draw_set_colour(_metal);
        draw_line_width(_k.x_foot + 9, _k.y_foot - 26, _k.x_top + 9, _k.y_top - 26, 2);
    }
    stage_draw_stairs_opening(_k, _biome, _pal);
    draw_set_colour(c_white);
}

/// Abertura no chao de cima, onde a escada chega (beirada da frente).
function stage_draw_stairs_opening(_k, _biome, _pal) {
    var _spr = level_art(_biome, "opening");
    if (_spr >= 0) {
        draw_sprite_ext(_spr, 0, _k.x_top, _k.y_top + 12, 1, 1, 0, c_white, 1);
        return;
    }
    draw_set_colour(c_black);
    draw_rectangle(_k.x_top - 22, _k.y_top - 2, _k.x_top + 22, _k.y_top + 12, false);
    draw_set_colour(merge_colour(_pal.floor, c_white, 0.2));
    draw_rectangle(_k.x_top - 24, _k.y_top - 4, _k.x_top + 24, _k.y_top - 2, false);
    // guarda-corpo nas laterais da abertura
    draw_line_width(_k.x_top - 24, _k.y_top - 4, _k.x_top - 24, _k.y_top - 22, 2);
    draw_line_width(_k.x_top + 24, _k.y_top - 4, _k.x_top + 24, _k.y_top - 22, 2);
    draw_line_width(_k.x_top - 24, _k.y_top - 22, _k.x_top - 10, _k.y_top - 22, 2);
    draw_line_width(_k.x_top + 10, _k.y_top - 22, _k.x_top + 24, _k.y_top - 22, 2);
    draw_set_colour(c_white);
}

/// Arte das pecas dos mapas 2D por bioma (tools/import_v3_level_art.py):
///   stairs - escada reta subindo para a direita, origem no pe
///   cap    - parede que fecha a ponta esquerda de um corredor (a direita e espelhada)
///   slab   - laje desenhada logo abaixo do chao da faixa de cima
/// -1 quando a peca nao existe (o desenho provisorio entra no lugar). As
/// referencias precisam ser diretas: o projeto remove sprites sem uso.
function level_art(_biome, _piece) {
    switch (_piece) {
        case "stairs":
            switch (_biome) {
                case "sewer":    return spr_lvl_stairs_sewer;
                case "streets":  return spr_lvl_stairs_streets;
                case "rooftops": return spr_lvl_stairs_rooftops;
            }
            break;
        case "cap":
            switch (_biome) {
                case "sewer":    return spr_lvl_cap_sewer;
                case "streets":  return spr_lvl_cap_streets;
                case "rooftops": return spr_lvl_cap_rooftops;
            }
            break;
        case "slab":
            switch (_biome) {
                case "sewer":    return spr_lvl_slab_sewer;
                case "streets":  return spr_lvl_slab_streets;
                case "rooftops": return spr_lvl_slab_rooftops;
            }
            break;
    }
    return -1;
}

/// Deslocamento horizontal entre o pe e o topo da escada de cada bioma (190 px
/// de subida), medido na arte por tools/import_v3_level_art.py. A geracao usa
/// este numero para o caminho do jogador seguir os degraus desenhados.
function stage_stairs_run(_biome) {
    switch (_biome) {
        case "sewer":    return 92;
        case "streets":  return 76;
        case "rooftops": return 84;
    }
    return CFG.level.stair_run;
}

/// Cenario de uma faixa fora do principal. Sem variante propria, usa o do bioma.
function level_band_sprite(_biome, _row, _default) {
    return _default;
}

// ------------------------------------------------- indicadores das entradas

/// Altura da porta pintada no cenario acima da linha do chao, em pixels do mundo
/// (altura da arte menos o quanto ela afunda no chao). Mesmos numeros de
/// tools/import_v2_art.py: porta sem o cano do esgoto (77 - 7), ruas (65 - 2),
/// telhados (54 - 2).
function stage_entrance_height(_biome) {
    switch (_biome) {
        case "sewer":    return 70;
        case "streets":  return 63;
        case "rooftops": return 52;
    }
    return 64;
}

/// Desenha, no Draw GUI, um icone pulsante com seta acima de cada entrada
/// especial do corredor. E so desenho: nao tem colisao nem mexe na porta.
/// Fica no HUD (nao no cenario), entao nunca sai espelhado.
function stage_entrance_indicators_draw() {
    var _s = global.stage;
    if (is_undefined(_s) || _s.kind != "main_map") return;
    var _M = CFG.entrance_marker;
    var _gw = CFG.view.gui_w;
    var _kx = _gw / VIEW_W;
    var _ky = CFG.view.gui_h / VIEW_H;
    var _camx = camera_get_view_x(view_camera[0]);
    var _camy = camera_get_view_y(view_camera[0]);
    // a porta fica no topo do chao da propria faixa (y da instancia)
    var _lift = 8 + stage_entrance_height(_s.biome) + _M.gap;
    var _open = stage_exits_open();
    var _rooms = global.run.special_rooms;

    with (obj_door) {
        if (kind != "special") continue;
        var _gx = (x - _camx) * _kx;
        var _tip_y = (y - _lift - _camy) * _ky;
        if (_gx < -40 || _gx > _gw + 40 || _tip_y < -60 || _tip_y > CFG.view.gui_h + 60) continue;
        var _used = variable_struct_exists(_rooms, target_sid) && _rooms[$ target_sid].used;
        var _col = _used ? make_colour_rgb(110, 116, 150) : room_kind_colour(room_kind);
        // pulsacao suave; uma fase por porta para nao pulsarem em sincronia
        var _ph = current_time * _M.pulse_speed + x * 0.01;
        var _active = !_used && _open;
        var _scale = _active ? 1 + _M.pulse_scale * sin(_ph) : 1;
        var _bob = _active ? _M.bob * sin(_ph) : 0;
        var _alpha = _open ? (_active ? 0.85 + 0.15 * sin(_ph) : 0.7) : 0.45;
        stage_entrance_indicator(_gx, _tip_y + _bob, room_kind, _col, _scale, _alpha);
    }
    stage_stairs_indicators_draw(_camx, _camy, _kx, _ky, _open);
    draw_set_alpha(1);
    draw_set_colour(c_white);
}

/// Setas das escadas no HUD: para cima sobre o pe e para baixo sobre o topo,
/// so na faixa em que o jogador esta. Ficam apagadas durante uma horda.
function stage_stairs_indicators_draw(_camx, _camy, _kx, _ky, _open) {
    var _map = level_current_map();
    if (is_undefined(_map)) return;
    var _cor = global.stage_rt.corridor;
    var _col = _open ? make_colour_rgb(45, 226, 230) : make_colour_rgb(110, 116, 150);
    var _bob = _open ? 3 * sin(current_time * 0.006) : 0;
    draw_set_alpha(_open ? 0.9 : 0.45);
    for (var _i = 0; _i < array_length(_map.stairs); _i++) {
        var _k = _map.links[_map.stairs[_i]];
        if (_map.chunks[_k.a].corridor == _cor) {
            // pe: seta para cima, acima da cabeca de quem esta ao pe da escada
            var _gx = (_k.x_foot - _camx) * _kx;
            var _gy = (_k.y_foot - 70 - _camy) * _ky + _bob;
            stage_stairs_arrow(_gx, _gy, -1, _col);
        }
        if (_map.chunks[_k.b].corridor == _cor) {
            // topo: seta para baixo, na beirada da frente
            var _tx = (_k.x_top - _camx) * _kx;
            var _ty = (_k.y_top - 46 - _camy) * _ky - _bob;
            stage_stairs_arrow(_tx, _ty, 1, _col);
        }
    }
    draw_set_alpha(1);
}

/// Seta de escada (no HUD): _dir -1 aponta para cima, +1 para baixo.
function stage_stairs_arrow(_x, _y, _dir, _col) {
    if (_x < -30 || _x > CFG.view.gui_w + 30 || _y < -30 || _y > CFG.view.gui_h + 30) return;
    draw_set_colour(c_black);
    draw_triangle(_x - 11, _y - _dir * 6, _x + 11, _y - _dir * 6, _x, _y + _dir * 10, false);
    draw_rectangle(_x - 5, _y - _dir * 6, _x + 5, _y - _dir * 18, false);
    draw_set_colour(_col);
    draw_triangle(_x - 9, _y - _dir * 5, _x + 9, _y - _dir * 5, _x, _y + _dir * 8, false);
    draw_rectangle(_x - 3, _y - _dir * 5, _x + 3, _y - _dir * 16, false);
}

/// Seta para baixo com a ponta em (_x, _tip_y) e o icone do tipo acima dela.
function stage_entrance_indicator(_x, _tip_y, _kind, _col, _scale, _alpha) {
    var _M = CFG.entrance_marker;
    var _r = _M.radius * _scale;
    var _a = _M.arrow * _scale;
    var _cy = _tip_y - _a - _r - 2;
    var _dark = make_colour_rgb(16, 18, 34);
    draw_set_alpha(_alpha);

    // seta
    draw_set_colour(c_black);
    draw_triangle(_x - _a - 2, _tip_y - _a - 2, _x + _a + 2, _tip_y - _a - 2, _x, _tip_y + 2, false);
    draw_set_colour(_col);
    draw_triangle(_x - _a, _tip_y - _a - 1, _x + _a, _tip_y - _a - 1, _x, _tip_y, false);

    // medalha
    draw_set_colour(c_black);
    draw_circle(_x, _cy, _r + 2, false);
    draw_set_colour(_col);
    draw_circle(_x, _cy, _r, false);
    draw_set_colour(merge_colour(_col, c_white, 0.45));
    draw_circle(_x, _cy, _r, true);

    // icone do tipo (formas simples, em tom escuro sobre a cor da categoria)
    var _u = _r / 12; // unidade: o desenho foi pensado para raio 12
    draw_set_colour(_dark);
    switch (_kind) {
        case "reward": // bau
            draw_rectangle(_x - 7 * _u, _cy - 1 * _u, _x + 7 * _u, _cy + 6 * _u, false);
            draw_rectangle(_x - 7 * _u, _cy - 6 * _u, _x + 7 * _u, _cy - 3 * _u, false);
            draw_set_colour(_col);
            draw_rectangle(_x - 1 * _u, _cy - 3 * _u, _x + 1 * _u, _cy + 1 * _u, false);
            break;
        case "shop": // moeda com cifrao
            draw_circle(_x, _cy, 7 * _u, false);
            draw_set_colour(_col);
            draw_set_halign(fa_center);
            draw_set_valign(fa_middle);
            draw_text_transformed(_x, _cy, "$", _u, _u, 0);
            draw_set_valign(fa_top);
            draw_set_halign(fa_left);
            break;
        case "challenge": // espadas cruzadas
        case "event":
            draw_line_width(_x - 6 * _u, _cy - 6 * _u, _x + 6 * _u, _cy + 6 * _u, 3 * _u);
            draw_line_width(_x + 6 * _u, _cy - 6 * _u, _x - 6 * _u, _cy + 6 * _u, 3 * _u);
            draw_line_width(_x - 7 * _u, _cy + 2 * _u, _x - 2 * _u, _cy + 7 * _u, 2 * _u);
            draw_line_width(_x + 7 * _u, _cy + 2 * _u, _x + 2 * _u, _cy + 7 * _u, 2 * _u);
            break;
        case "rest": // lua (crescente)
            draw_circle(_x - 1 * _u, _cy, 7 * _u, false);
            draw_set_colour(_col);
            draw_circle(_x + 2 * _u, _cy - 2 * _u, 6 * _u, false);
            break;
        default:
            draw_circle(_x, _cy, 4 * _u, false);
            break;
    }
    draw_set_alpha(1);
    draw_set_colour(c_white);
}
