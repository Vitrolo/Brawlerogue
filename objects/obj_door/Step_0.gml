bob++;
locked = requires_clear && !stage_exits_open();
near = false;

var _p = instance_find(obj_player, 0);
if (_p == noone) exit;

near = abs(_p.x - x) < 20 && _p.y <= global.stage.floor_top + 16 && _p.z <= 0;
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
    }
}
