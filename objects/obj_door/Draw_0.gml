// As portas nao desenham sprite proprio: no corredor e nas salas especiais a
// entrada e a saida ja estao pintadas no cenario. So a saida do lobby, que fica
// na borda direita da sala, ganha uma seta para indicar o caminho.
if (kind == "run_start") {
    var _ax = x + 6 + ((bob div 12) mod 2) * 2;
    var _ay = y - 40;
    draw_set_colour(c_black);
    draw_triangle(_ax - 5, _ay - 8, _ax - 5, _ay + 8, _ax + 9, _ay, false);
    draw_set_colour(make_colour_rgb(255, 210, 63));
    draw_triangle(_ax - 4, _ay - 6, _ax - 4, _ay + 6, _ax + 7, _ay, false);
    draw_set_colour(c_white);
}
