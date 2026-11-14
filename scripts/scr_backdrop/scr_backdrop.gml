/// Cenarios pintados, um sprite por bioma (spr_bg_<bioma>, 768x272, gerados no PixelLab).
/// Tudo aqui e apenas visual: nada gera colisao.
///
/// Cada imagem tem a parede em cima e o chao embaixo, mas a linha onde o chao comeca
/// muda de uma para outra. stage_backdrop_info diz, em pixels da imagem:
///   horizon  - linha onde o chao comeca; e alinhada com o topo do chao do jogo
///   band_y0, band_y1 - faixa de chao que se repete para baixo ate cobrir a tela
/// A imagem se repete na horizontal espelhando uma copia sim, uma nao, para a emenda
/// nao aparecer. Para trocar um cenario: substitua o PNG em tools/pixellab_raw, rode
/// tools/import_pixellab.py e ajuste as tres linhas do bioma aqui.

/// Pseudoaleatorio deterministico em [0,1) que nao mexe na seed da run.
function decor_rand(_seed, _i) {
    return frac(abs(sin(_seed * 12.9898 + _i * 78.233) * 43758.5453));
}

function stage_backdrop_info(_biome) {
    switch (_biome) {
        case "sewer":    return { sprite: spr_bg_sewer,    horizon: 205, band_y0: 207, band_y1: 262 };
        case "streets":  return { sprite: spr_bg_streets,  horizon: 138, band_y0: 156, band_y1: 243 };
        case "rooftops": return { sprite: spr_bg_rooftops, horizon: 190, band_y0: 192, band_y1: 272 };
        case "boss":     return { sprite: spr_bg_boss,     horizon: 228, band_y0: 230, band_y1: 272 };
        default:         return { sprite: spr_bg_lobby,    horizon: 203, band_y0: 204, band_y1: 238 };
    }
}

function stage_draw_placeholder() {
    var _s = global.stage;
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

        // parede e primeira faixa de chao
        draw_sprite_part_ext(_spr, 0, 0, 0, _w, _info.band_y1, _x, _oy, _xs, 1, c_white, 1);
        // a imagem pode comecar abaixo do topo da tela: estica a primeira linha para cima
        if (_oy > -16) {
            draw_sprite_part_ext(_spr, 0, 0, 0, _w, 1, _x, -16, _xs, _oy + 16, c_white, 1);
        }
        // repete a faixa de chao ate o fim da tela
        for (var _y = _oy + _info.band_y1; _y < _bottom; _y += _band_h) {
            draw_sprite_part_ext(_spr, 0, 0, _info.band_y0, _w, _band_h, _x, _y, _xs, 1, c_white, 1);
        }
    }
}
