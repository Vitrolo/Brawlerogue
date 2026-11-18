bob++;
locked = (requires_clear && !stage_exits_open()) || challenge_active();
near = false;

var _p = instance_find(obj_player, 0);
if (_p == noone) exit;

// a porta fica no topo do chao da propria faixa (y); nos mapas 2D o jogador
// pode estar em outra faixa na mesma coluna
near = abs(_p.x - x) < 20 && _p.y >= y - 2 && _p.y <= y + 16 && _p.z <= 0;
if (!near) exit;

if (locked) {
    global.prompt = "TRANCADA - derrote os inimigos";
    exit;
}

global.prompt = "[" + input_action_label(ACT.INTERACT) + "] " + label;
if (input_pressed(ACT.INTERACT) && global.flow.state == FLOW.PLAY && global.player_states[_p.state].can_act) {
    switch (kind) {
        case "run_start":   run_start(); break;
        case "route":       run_goto_node(target_nid); break;
        case "special":     run_enter_special(target_sid); break;
        case "return":      run_return_from_special(); break;
    }
}
