/// Sala de desafio: uma arena fechada com uma regra especial. Fica nas salas do
/// tipo "event" (entrada DESAFIO do corredor). O painel da sala oferece o desafio;
/// aceitar fecha a saida, traz os inimigos e liga a regra. Vencer da recompensa a
/// escolher, moedas e fichas; falhar so perde o premio.
///
/// Regras:
///  no_block - o bloqueio fica desativado
///  timer    - derrote todos antes do tempo acabar
///  no_hit   - nao leve nenhum golpe
///
/// O estado fica em global.stage_rt.challenge (some ao sair da sala).

function challenge_rule_for_seed(_seed) {
    var _rules = ["no_block", "timer", "no_hit"];
    return _rules[_seed mod array_length(_rules)];
}

function challenge_rule_text(_rule) {
    switch (_rule) {
        case "no_block": return "sem bloquear";
        case "timer":    return "contra o tempo";
        case "no_hit":   return "sem levar golpe";
    }
    return "";
}

/// Estado do desafio da sala atual, ou undefined.
function challenge_state() {
    if (is_undefined(global.stage_rt)) return undefined;
    if (!variable_struct_exists(global.stage_rt, "challenge")) return undefined;
    return global.stage_rt.challenge;
}

function challenge_active() {
    var _c = challenge_state();
    return !is_undefined(_c) && _c.state == "active";
}

/// true quando a regra ativa proibe o bloqueio.
function challenge_blocks_guard() {
    var _c = challenge_state();
    return !is_undefined(_c) && _c.state == "active" && _c.rule == "no_block";
}

/// Inimigos do desafio: mais fortes a cada bioma.
function challenge_wave() {
    switch (global.stage.biome) {
        case "sewer":   return ["thug", "thug", "runner", "shooter"];
        case "streets": return ["thug", "shield", "runner", "bomber", "brute"];
    }
    return ["brute", "shield", "shooter", "bomber", "runner"];
}

function challenge_start(_rule, _seed) {
    var _s = global.stage;
    var _types = challenge_wave();
    for (var _i = 0; _i < array_length(_types); _i++) {
        // entram pelos dois lados, espalhados na profundidade
        var _left = (_i mod 2 == 0);
        var _x = _left ? (40 + _i * 14) : (_s.width - 40 - _i * 14);
        var _y = _s.floor_top + 12 + ((_i * 23) mod (_s.floor_bottom - _s.floor_top - 20));
        instance_create_depth(_x, _y, 0, obj_enemy, { enemy_type: _types[_i] });
    }
    global.stage_rt.challenge = {
        state: "active",
        rule: _rule,
        seed: _seed,
        timer: CFG.challenge.timer_frames,
        hits_at_start: global.run.hits_taken
    };
    toast_show("DESAFIO: " + challenge_rule_text(_rule) + "!");
}

/// Chamado todo frame pelo obj_game.
function challenge_update() {
    var _c = challenge_state();
    if (is_undefined(_c) || _c.state != "active") return;
    if (global.flow.state != FLOW.PLAY) return;

    var _failed = false;
    if (_c.rule == "timer") {
        _c.timer--;
        if (_c.timer <= 0) _failed = true;
    } else if (_c.rule == "no_hit") {
        if (global.run.hits_taken > _c.hits_at_start) _failed = true;
    }

    if (_failed) {
        _c.state = "failed";
        // os inimigos vao embora: o desafio nao vira armadilha
        with (obj_enemy) {
            fx_dust(x, y, 8);
            instance_destroy();
        }
        with (obj_hitbox) instance_destroy();
        with (obj_projectile) instance_destroy();
        toast_show("Desafio falhou. Sem premio desta vez.");
        return;
    }

    if (enemies_alive() == 0) {
        _c.state = "won";
        var _C = CFG.challenge;
        global.run.coins += _C.reward_coins;
        global.meta.chips += _C.reward_chips;
        toast_show("DESAFIO VENCIDO! +" + string(_C.reward_coins) + " moedas, +" + string(_C.reward_chips) + " fichas");
        choice_open("PREMIO DO DESAFIO - escolha um", reward_options(_c.seed + 101), false, false, noone);
    }
}
