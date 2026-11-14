/// Cenarios PLACEHOLDER desenhados com retangulos, um estilo por bioma.
/// Tudo aqui e apenas visual: nada gera colisao. A semente "decor" de cada modulo
/// de sala fixa a posicao dos detalhes, entao a mesma sala e igual em toda run.
/// Trocar por tilesets/sprites finais: substitua stage_draw_placeholder por camadas
/// do room (fundo distante, fundo medio, chao, primeiro plano).

/// Pseudoaleatorio deterministico em [0,1) que nao mexe na seed da run.
function decor_rand(_seed, _i) {
    return frac(abs(sin(_seed * 12.9898 + _i * 78.233) * 43758.5453));
}

function stage_draw_placeholder() {
    var _s = global.stage;
    var _pal = _s.palette;
    var _ft = _s.floor_top;
    var _x0 = -16;             // margem para o tremor da camera
    var _x1 = _s.width + 16;

    draw_set_alpha(1);
    draw_set_colour(_pal.sky);
    draw_rectangle(_x0, -16, _x1, VIEW_H + 16, false);

    switch (_s.biome) {
        case "sewer":    backdrop_sewer(_s, _x0, _x1); break;
        case "streets":  backdrop_streets(_s, _x0, _x1); break;
        case "rooftops": backdrop_rooftops(_s, _x0, _x1); break;
        case "boss":     backdrop_boss(_s, _x0, _x1); break;
        default:         backdrop_lobby(_s, _x0, _x1); break;
    }

    // chao (comum a todos)
    draw_set_colour(_pal.floor);
    draw_rectangle(_x0, _ft - 8, _x1, VIEW_H + 16, false);
    draw_set_colour(_pal.floor_dark);
    for (var _y = _ft - 8; _y < VIEW_H; _y += 18) {
        draw_rectangle(_x0, _y, _x1, _y, false);
    }
    draw_set_colour(_pal.neon);
    draw_rectangle(_x0, _ft - 9, _x1, _ft - 9, false);
    draw_set_colour(c_white);
}

function backdrop_wall(_s, _x0, _x1, _top) {
    var _pal = _s.palette;
    draw_set_colour(_pal.wall);
    draw_rectangle(_x0, _top, _x1, _s.floor_top - 9, false);
    draw_set_colour(_pal.wall_dark);
    draw_rectangle(_x0, _top, _x1, _top + 3, false);
}

function backdrop_lobby(_s, _x0, _x1) {
    var _pal = _s.palette;
    backdrop_wall(_s, _x0, _x1, 36);
    draw_set_colour(_pal.wall_dark);
    for (var _i = 0; _i < _s.width; _i += 96) {
        draw_rectangle(_i, 36, _i + 3, _s.floor_top - 9, false);
    }
    draw_set_colour(_pal.neon);
    draw_rectangle(_x0, 58, _x1, 59, false);
    draw_set_colour(_pal.accent);
    for (var _i = 40; _i < _s.width; _i += 192) {
        draw_rectangle(_i, 76, _i + 46, 78, false);
    }
}

/// Esgoto: tijolos, canos, grades, luz industrial e canal de agua verde escura.
function backdrop_sewer(_s, _x0, _x1) {
    var _pal = _s.palette;
    var _ft = _s.floor_top;
    var _seed = _s.decor;
    backdrop_wall(_s, _x0, _x1, 24);

    // juntas de tijolo
    draw_set_colour(_pal.wall_dark);
    for (var _y = 40; _y < _ft - 30; _y += 16) {
        draw_rectangle(_x0, _y, _x1, _y, false);
    }

    // canos horizontais com emendas
    var _py = 56 + floor(decor_rand(_seed, 1) * 16);
    draw_set_colour(make_colour_rgb(40, 62, 70));
    draw_rectangle(_x0, _py, _x1, _py + 7, false);
    draw_rectangle(_x0, _py + 30, _x1, _py + 34, false);
    draw_set_colour(make_colour_rgb(70, 100, 108));
    draw_rectangle(_x0, _py + 1, _x1, _py + 1, false);
    draw_set_colour(_pal.wall_dark);
    for (var _i = 30 + floor(decor_rand(_seed, 2) * 60); _i < _s.width; _i += 110) {
        draw_rectangle(_i, _py - 2, _i + 5, _py + 9, false);
    }

    // grades e lampadas industriais
    for (var _i = 0; _i * 150 < _s.width; _i++) {
        var _gx = _i * 150 + 30 + floor(decor_rand(_seed, 10 + _i) * 70);
        draw_set_colour(make_colour_rgb(4, 10, 12));
        draw_rectangle(_gx, 112, _gx + 26, 134, false);
        draw_set_colour(make_colour_rgb(56, 80, 86));
        for (var _b = 4; _b < 26; _b += 6) {
            draw_rectangle(_gx + _b, 112, _gx + _b, 134, false);
        }
        var _lx = _gx + 60;
        draw_set_colour(_pal.accent);
        draw_rectangle(_lx, 40, _lx + 5, 43, false);
        draw_set_alpha(0.12);
        draw_triangle(_lx + 2, 44, _lx - 18, 100, _lx + 22, 100, false);
        draw_set_alpha(1);
    }

    // canal de agua
    draw_set_colour(make_colour_rgb(14, 52, 38));
    draw_rectangle(_x0, _ft - 26, _x1, _ft - 9, false);
    draw_set_colour(_pal.neon);
    draw_set_alpha(0.35);
    for (var _i = 0; _i * 46 < _s.width; _i++) {
        var _wx = _i * 46 + floor(decor_rand(_seed, 40 + _i) * 30);
        draw_rectangle(_wx, _ft - 20 + (_i mod 3) * 4, _wx + 12, _ft - 20 + (_i mod 3) * 4, false);
    }
    draw_set_alpha(1);
}

/// Ruas: skyline ao fundo, fachadas com janelas, toldos e letreiros neon.
function backdrop_streets(_s, _x0, _x1) {
    var _pal = _s.palette;
    var _ft = _s.floor_top;
    var _seed = _s.decor;

    backdrop_skyline(_s, _x0, _x1, 26, make_colour_rgb(18, 20, 52), 64);
    backdrop_wall(_s, _x0, _x1, 52);

    // janelas: apagadas, ciano, magenta ou douradas
    for (var _i = 0; _i * 34 < _s.width; _i++) {
        for (var _r = 0; _r < 2; _r++) {
            var _v = decor_rand(_seed, 100 + _i * 2 + _r);
            var _c = _pal.wall_dark;
            if (_v > 0.82) _c = make_colour_rgb(255, 210, 63);
            else if (_v > 0.64) _c = _pal.neon;
            else if (_v > 0.46) _c = _pal.accent;
            draw_set_colour(_c);
            draw_rectangle(_i * 34 + 8, 62 + _r * 26, _i * 34 + 24, 78 + _r * 26, false);
        }
    }

    // lojas: vitrine, toldo e letreiro
    for (var _i = 0; _i * 170 < _s.width; _i++) {
        var _sx = _i * 170 + 20 + floor(decor_rand(_seed, 200 + _i) * 50);
        draw_set_colour(make_colour_rgb(8, 10, 26));
        draw_rectangle(_sx, 124, _sx + 70, _ft - 10, false);
        draw_set_colour((_i mod 2 == 0) ? _pal.neon : _pal.accent);
        draw_rectangle(_sx - 4, 118, _sx + 74, 124, false);
        draw_rectangle(_sx + 10, 104, _sx + 52, 112, false);
        draw_set_colour(_pal.wall_dark);
        for (var _b = 6; _b < 74; _b += 14) {
            draw_rectangle(_sx - 4 + _b, 118, _sx + _b, 124, false);
        }
    }

    // escada de incendio
    var _fx = 110 + floor(decor_rand(_seed, 300) * (_s.width - 220));
    draw_set_colour(make_colour_rgb(70, 76, 110));
    draw_rectangle(_fx, 56, _fx + 1, 118, false);
    draw_rectangle(_fx + 14, 56, _fx + 15, 118, false);
    for (var _y = 60; _y < 118; _y += 8) {
        draw_rectangle(_fx, _y, _fx + 15, _y, false);
    }
}

/// Topo dos predios: ceu aberto, skyline em duas camadas, mureta, antenas e dutos.
function backdrop_rooftops(_s, _x0, _x1) {
    var _pal = _s.palette;
    var _ft = _s.floor_top;
    var _seed = _s.decor;

    backdrop_skyline(_s, _x0, _x1, 60, make_colour_rgb(20, 16, 58), 90);
    backdrop_skyline(_s, _x0, _x1, 100, make_colour_rgb(28, 24, 70), 56);

    // antenas e equipamentos atras da mureta
    for (var _i = 0; _i * 120 < _s.width; _i++) {
        var _ax = _i * 120 + 20 + floor(decor_rand(_seed, 400 + _i) * 70);
        if (decor_rand(_seed, 420 + _i) > 0.45) {
            var _h = 50 + floor(decor_rand(_seed, 440 + _i) * 40);
            draw_set_colour(make_colour_rgb(90, 96, 130));
            draw_rectangle(_ax, _ft - 22 - _h, _ax + 1, _ft - 22, false);
            draw_rectangle(_ax - 6, _ft - 22 - _h + 10, _ax + 7, _ft - 22 - _h + 10, false);
            draw_set_colour(make_colour_rgb(255, 60, 60));
            draw_rectangle(_ax - 1, _ft - 24 - _h, _ax + 2, _ft - 22 - _h, false);
        } else {
            draw_set_colour(make_colour_rgb(60, 62, 96));
            draw_rectangle(_ax, _ft - 46, _ax + 30, _ft - 22, false);
            draw_set_colour(_pal.wall_dark);
            for (var _b = 4; _b < 30; _b += 6) {
                draw_rectangle(_ax + _b, _ft - 42, _ax + _b + 2, _ft - 28, false);
            }
        }
    }

    // mureta com luz de borda
    draw_set_colour(_pal.wall);
    draw_rectangle(_x0, _ft - 22, _x1, _ft - 9, false);
    draw_set_colour(_pal.accent);
    draw_rectangle(_x0, _ft - 23, _x1, _ft - 23, false);
}

/// Arena final: colunas, capiteis dourados e faixas neon verticais.
function backdrop_boss(_s, _x0, _x1) {
    var _pal = _s.palette;
    var _ft = _s.floor_top;
    backdrop_wall(_s, _x0, _x1, 0);
    for (var _i = 20; _i < _s.width; _i += 88) {
        draw_set_colour(_pal.wall_dark);
        draw_rectangle(_i, 8, _i + 22, _ft - 9, false);
        draw_set_colour(_pal.accent);
        draw_rectangle(_i - 3, 8, _i + 25, 13, false);
        draw_rectangle(_i - 3, _ft - 15, _i + 25, _ft - 10, false);
        draw_set_colour(((_i div 88) mod 2 == 0) ? _pal.neon : make_colour_rgb(45, 226, 230));
        draw_rectangle(_i + 48, 20, _i + 50, _ft - 30, false);
    }
}

/// Faixa de predios distantes com janelas acesas.
function backdrop_skyline(_s, _x0, _x1, _base_top, _col, _max_h) {
    var _seed = _s.decor + _base_top;
    var _bottom = _s.floor_top - 9;
    for (var _i = -1; _i * 44 < _s.width + 44; _i++) {
        var _h = floor(decor_rand(_seed, 500 + _i) * _max_h);
        var _bx = _i * 44;
        draw_set_colour(_col);
        draw_rectangle(_bx, _base_top + (_max_h - _h), _bx + 40, _bottom, false);
        // janelas pontuais
        draw_set_colour(make_colour_rgb(255, 210, 63));
        draw_set_alpha(0.5);
        for (var _w = 0; _w < 3; _w++) {
            if (decor_rand(_seed, 600 + _i * 3 + _w) > 0.5) {
                var _wy = _base_top + (_max_h - _h) + 6 + _w * 9;
                if (_wy < _bottom - 4) draw_rectangle(_bx + 6 + _w * 10, _wy, _bx + 8 + _w * 10, _wy + 2, false);
            }
        }
        draw_set_alpha(1);
    }
}
