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
        var _tile_spr = _spr;

        // Um tile inteiro do fundo e substituido pela variante que ja contem
        // a entrada. Como os pixels laterais sao os do cenario original, a
        // emenda com os tiles vizinhos continua invisivel, inclusive espelhada.
        if (_s.kind == "main_map") {
            var _map = global.run.maps[_s.map_index];
            for (var _j = 0; _j < array_length(_map.specials); _j++) {
                var _special = _map.specials[_j];
                if (floor(_special.x / _w) == _i) {
                    var _chunk = stage_backdrop_entrance(_s.biome, _special.kind);
                    if (_chunk >= 0) _tile_spr = _chunk;
                    break;
                }
            }
        }

        // parede e primeira faixa de chao
        draw_sprite_part_ext(_tile_spr, 0, 0, 0, _w, _info.band_y1, _x, _oy, _xs, 1, c_white, 1);
        // a imagem pode comecar abaixo do topo da tela: estica a primeira linha para cima
        if (_oy > -16) {
            draw_sprite_part_ext(_tile_spr, 0, 0, 0, _w, 1, _x, -16, _xs, _oy + 16, c_white, 1);
        }
    }

    // Repete a faixa de chao ate o fim da tela. Cada copia e uma tira propria,
    // espelhada tile a tile como o fundo, mas deslocada na horizontal.
    var _row = 1;
    for (var _y = _oy + _info.band_y1; _y < _bottom; _y += _band_h) {
        var _off = (_row * _info.band_shift) mod _w;
        for (var _j = -1; _j * _w - _off < _s.width + 16; _j++) {
            var _jflip = (_j mod 2 != 0);
            var _jx = _j * _w - _off + (_jflip ? _w : 0);
            draw_sprite_part_ext(_spr, 0, 0, _info.band_y0, _w, _band_h, _jx, _y, _jflip ? -1 : 1, 1, c_white, 1);
        }
        _row++;
    }
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
    var _tip_y = (_s.floor_top - 8 - stage_entrance_height(_s.biome) - _M.gap - _camy) * _ky;
    var _open = stage_exits_open();
    var _rooms = global.run.special_rooms;

    with (obj_door) {
        if (kind != "special") continue;
        var _gx = (x - _camx) * _kx;
        if (_gx < -40 || _gx > _gw + 40) continue;
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
    draw_set_alpha(1);
    draw_set_colour(c_white);
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
