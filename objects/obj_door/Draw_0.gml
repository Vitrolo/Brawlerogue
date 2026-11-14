/// PLACEHOLDER: porta desenhada com retangulos.
/// Portas de rota mostram o tipo da proxima sala por cor + forma; o texto fica na HUD.
var _bottom = y - 9;
var _top = y - 58;
var _kind_col = (room_kind != "") ? room_kind_colour(room_kind) : global.stage.palette.neon;
var _col = locked ? make_colour_rgb(120, 124, 150) : _kind_col;

draw_set_colour(_col);
draw_rectangle(x - 17, _top - 2, x + 17, _bottom, false);
draw_set_colour(make_colour_rgb(6, 8, 20));
draw_rectangle(x - 14, _top + 1, x + 14, _bottom, false);

if (locked) {
    // trancada: X dentro da porta
    draw_set_colour(_col);
    draw_line_width(x - 9, _top + 12, x + 9, _bottom - 12, 2);
    draw_line_width(x + 9, _top + 12, x - 9, _bottom - 12, 2);
}

// icone acima da porta (balanca quando a porta esta aberta)
var _iy = _top - 14 + (locked ? 0 : ((bob div 12) mod 2) * 2);
draw_set_colour(_kind_col);
switch (room_kind) {
    case "combat": // losango
        draw_triangle(x - 6, _iy, x + 6, _iy, x, _iy - 6, false);
        draw_triangle(x - 6, _iy, x + 6, _iy, x, _iy + 6, false);
        break;
    case "rest":   // cruz
        draw_rectangle(x - 1, _iy - 5, x + 1, _iy + 5, false);
        draw_rectangle(x - 5, _iy - 1, x + 5, _iy + 1, false);
        break;
    case "reward": // caixa
        draw_rectangle(x - 5, _iy - 4, x + 5, _iy + 4, false);
        draw_set_colour(make_colour_rgb(6, 8, 20));
        draw_rectangle(x - 1, _iy - 1, x + 1, _iy + 1, false);
        break;
    case "shop":   // moeda
        draw_circle(x, _iy, 5, false);
        break;
    case "event":  // triangulo para cima
        draw_triangle(x - 6, _iy + 5, x + 6, _iy + 5, x, _iy - 6, false);
        break;
    case "boss":   // coroa
        draw_rectangle(x - 7, _iy + 1, x + 7, _iy + 5, false);
        draw_triangle(x - 7, _iy + 1, x - 2, _iy + 1, x - 7, _iy - 6, false);
        draw_triangle(x - 3, _iy + 1, x + 3, _iy + 1, x, _iy - 7, false);
        draw_triangle(x + 2, _iy + 1, x + 7, _iy + 1, x + 7, _iy - 6, false);
        break;
    default:       // seta para baixo (portas do lobby e provisorias)
        if (!locked) draw_triangle(x - 6, _iy - 2, x + 6, _iy - 2, x, _iy + 5, false);
        break;
}
draw_set_colour(c_white);
