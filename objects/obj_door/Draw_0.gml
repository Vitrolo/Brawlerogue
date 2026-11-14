// No corredor principal, a entrada ja esta desenhada dentro do tile do cenario.
// Nas salas de fundo preto, mantemos o portal simples usado para sair/voltar.
if (!is_undefined(global.stage) && global.stage.kind != "main_map") {
    var _door_sprite = spr_door_lobby;
    switch (global.stage.biome) {
        case "sewer":    _door_sprite = spr_door_sewer; break;
        case "streets":  _door_sprite = spr_door_streets; break;
        case "rooftops": _door_sprite = spr_door_rooftops; break;
    }

    var _alpha = locked ? 0.72 : 1;
    draw_sprite_ext(_door_sprite, 0, x, y - 9, 0.6, 0.6, 0, c_white, _alpha);
    draw_set_colour(c_white);
}
