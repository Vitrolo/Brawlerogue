// GERADO por tools/weapon_anchors.py -- nao editar a mao.
// Mao da frente em cada quadro dos sprites do jogador, relativa a origem do sprite
// (olhando para a direita, sem escala). spr_p2_* usa a mesma tabela.

function weapon_hand_table() {
    static _t = {
        spr_player_air_attack: [[-1, -41]],
        spr_player_attack1: [[3, -35], [10, -38], [4, -34]],
        spr_player_attack2: [[7, -30], [21, -33], [8, -31]],
        spr_player_attack3: [[9, -44], [2, -39], [9, -43]],
        spr_player_block: [[8, -31]],
        spr_player_dead: [[18, -19]],
        spr_player_dodge: [[-9, -12]],
        spr_player_fall: [[-18, -33]],
        spr_player_getup: [[6, -29]],
        spr_player_grab: [[6, -34]],
        spr_player_hurt: [[3, -39]],
        spr_player_idle: [[-1, -24], [-1, -24], [-1, -24], [-1, -24]],
        spr_player_jump: [[-20, -39]],
        spr_player_knockdown: [[18, -19]],
        spr_player_land: [[-12, -15]],
        spr_player_run: [[5, -28], [6, -26], [-4, -24], [6, -31], [6, -29], [-9, -26]],
        spr_player_special: [[19, -18], [12, -22], [2, -31], [6, -29]],
        spr_player_throw: [[9, -28], [19, -37], [-5, -18]],
        spr_player_walk: [[-2, -23], [-2, -24], [-3, -23], [-3, -23], [6, -25], [-3, -24]],
    };
    return _t;
}

/// [dx, dy] da mao no quadro, ou undefined se o sprite nao e do jogador.
function weapon_hand_offset(_spr, _frame) {
    var _name = string_replace(sprite_get_name(_spr), "spr_p2_", "spr_player_");
    var _arr = weapon_hand_table()[$ _name];
    if (is_undefined(_arr)) return undefined;
    return _arr[clamp(floor(_frame), 0, array_length(_arr) - 1)];
}
