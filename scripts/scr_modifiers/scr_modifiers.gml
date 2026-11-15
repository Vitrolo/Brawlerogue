/// Recompensas da run: cura, velocidade, vida maxima, armas e passivas.
/// Tudo e temporario: os modificadores ficam em global.run.modifiers e somem em
/// run_reset(). Para criar um novo, basta um mod_define; nenhuma outra logica muda
/// se ele usar um "stat" ja existente em run_base_stats().

/// Valores que os modificadores alteram. Jogador e combate consultam global.run.stats.
/// Os valores iniciais ja incluem a personagem e as melhorias permanentes do lobby.
function run_base_stats() {
    var _char = player_char();
    return {
        speed_mult: 1 + _char.speed_bonus,                    // velocidade de movimento
        damage_mult: 1 + 0.05 * meta_level("power"),          // dano causado
        damage_taken_mult: 1,                                 // dano recebido
        special_gain_mult: 1 + 0.15 * meta_level("focus"),    // ganho de energia do especial
        kill_heal: 0,           // vida recuperada por inimigo derrotado
        kill_special: 0,        // energia do especial por inimigo derrotado
        dodge_damage: 0,        // > 0: a esquiva vira um golpe (multiplicador do dano)
        dodge_special: 0,       // energia ganha ao esquivar de um golpe no tempo certo
        counter_mult: 0,        // > 0: o golpe seguinte a uma esquiva perfeita ganha este bonus
        block_reflect: 0,       // dano devolvido a quem acerta o bloqueio
        coin_mult: 1,           // moedas por inimigo
        shop_mult: 1            // precos da loja
    };
}

/// category: "heal" | "speed" | "max_hp" | "weapon" | "passive" | "curse"
///  curse   -> troca ruim por boa: "stats" e uma lista de { stat, amount } e
///             "max_hp" (opcional) muda a vida maxima na hora
///  heal    -> cura imediata de "amount", limitada a vida maxima
///  max_hp  -> aumenta a vida maxima em "amount" e cura o mesmo valor
///  speed / passive -> soma "amount" ao "stat" enquanto durar a run
///  weapon  -> equipa a arma "weapon"
function mod_define(_mid, _def) {
    _def.mid = _mid;
    global.mods[$ _mid] = _def;
}

function mod_get(_mid) {
    return global.mods[$ _mid];
}

function mods_init() {
    global.mods = {};

    mod_define("heal_small", { name: "Lanche", desc: "Cura 30 de vida.", category: "heal", amount: 30, stackable: true, price: 15 });
    mod_define("heal_big", { name: "Marmita", desc: "Cura 60 de vida.", category: "heal", amount: 60, stackable: true, price: 30 });
    mod_define("speed_up", { name: "Tenis leves", desc: "+12% de velocidade.", category: "speed", stat: "speed_mult", amount: 0.12, stackable: true, price: 30 });
    mod_define("max_hp_up", { name: "Colete", desc: "+20 de vida maxima e cura 20.", category: "max_hp", amount: 20, stackable: true, price: 35 });
    mod_define("p_power", { name: "Punhos pesados", desc: "+20% de dano causado.", category: "passive", stat: "damage_mult", amount: 0.2, stackable: false, price: 40 });
    mod_define("p_guard", { name: "Casca grossa", desc: "-20% de dano recebido.", category: "passive", stat: "damage_taken_mult", amount: -0.2, stackable: false, price: 40 });
    mod_define("p_vamp", { name: "Adrenalina", desc: "Cura 3 de vida por inimigo derrotado.", category: "passive", stat: "kill_heal", amount: 3, stackable: false, price: 40 });
    mod_define("p_charge", { name: "Foco", desc: "Especial enche 50% mais rapido.", category: "passive", stat: "special_gain_mult", amount: 0.5, stackable: false, price: 40 });
    mod_define("w_pipe", { name: "Cano", desc: "Arma: golpe longo. Quebra apos 12 acertos.", category: "weapon", weapon: "w_pipe", stackable: true, price: 20 });
    mod_define("w_bat", { name: "Taco", desc: "Arma: golpe forte que derruba. Quebra apos 8 acertos.", category: "weapon", weapon: "w_bat", stackable: true, price: 25 });

    mod_define("p_dash_hit", { name: "Ombrada", desc: "A esquiva acerta quem estiver no caminho.", category: "passive", stat: "dodge_damage", amount: 1, stackable: false, price: 40 });
    mod_define("p_reflex", { name: "Reflexos", desc: "Esquivar de um golpe no tempo certo da +15 de especial.", category: "passive", stat: "dodge_special", amount: 15, stackable: false, price: 35 });

    // Maldicoes: uma perda e um ganho. Aparecem como opcao extra em alguns baus.
    mod_define("c_blood", { name: "Pacto de sangue", desc: "MALDICAO: -25 de vida maxima, +35% de dano.", category: "curse", max_hp: -25, stats: [{ stat: "damage_mult", amount: 0.35 }], stackable: false, price: 0 });
    mod_define("c_glass", { name: "Corpo de vidro", desc: "MALDICAO: recebe +30% de dano, especial enche 2x mais rapido.", category: "curse", stats: [{ stat: "damage_taken_mult", amount: 0.3 }, { stat: "special_gain_mult", amount: 1 }], stackable: false, price: 0 });
    mod_define("c_greed", { name: "Ganancia", desc: "MALDICAO: inimigos dao o dobro de moedas, loja 40% mais cara.", category: "curse", stats: [{ stat: "coin_mult", amount: 1 }, { stat: "shop_mult", amount: 0.4 }], stackable: false, price: 0 });

    // Ordem fixa: os sorteios por seed dependem dela.
    global.reward_pool = ["heal_small", "speed_up", "max_hp_up", "p_power", "p_guard", "p_vamp", "p_charge", "w_pipe", "w_bat", "p_dash_hit", "p_reflex"];
    global.passive_pool = ["p_power", "p_guard", "p_vamp", "p_charge", "p_dash_hit", "p_reflex"];
    global.curse_pool = ["c_blood", "c_glass", "c_greed"];

    // Sinergias: ter os dois modificadores ativa um bonus extra.
    global.synergies = [
        { sid: "comet",   a: "p_dash_hit", b: "speed_up",  name: "Cometa",       desc: "a ombrada causa o dobro de dano.",                  stat: "dodge_damage",  amount: 1 },
        { sid: "frenzy",  a: "p_vamp",     b: "p_charge",  name: "Frenesi",      desc: "cada inimigo derrotado da +12 de especial.",        stat: "kill_special",  amount: 12 },
        { sid: "wall",    a: "p_guard",    b: "max_hp_up", name: "Muralha",      desc: "bloquear devolve 8 de dano a quem bateu.",          stat: "block_reflect", amount: 8 },
        { sid: "counter", a: "p_power",    b: "p_reflex",  name: "Contra-golpe", desc: "depois de uma esquiva perfeita, o proximo golpe causa o dobro.", stat: "counter_mult", amount: 1 }
    ];
}

function synergy_get(_sid) {
    for (var _i = 0; _i < array_length(global.synergies); _i++) {
        if (global.synergies[_i].sid == _sid) return global.synergies[_i];
    }
    return undefined;
}

function run_has_mod(_mid) {
    return array_contains(global.run.modifiers, _mid);
}

function run_heal(_amount) {
    var _run = global.run;
    _run.hp = min(_run.hp_max, _run.hp + _amount);
}

/// Recalcula os stats a partir da lista de modificadores ativos.
function run_recompute_stats() {
    var _run = global.run;
    var _st = run_base_stats();
    for (var _i = 0; _i < array_length(_run.modifiers); _i++) {
        var _d = mod_get(_run.modifiers[_i]);
        if (variable_struct_exists(_d, "stat")) _st[$ _d.stat] += _d.amount;
        if (variable_struct_exists(_d, "stats")) {
            for (var _j = 0; _j < array_length(_d.stats); _j++) {
                _st[$ _d.stats[_j].stat] += _d.stats[_j].amount;
            }
        }
    }
    // sinergias: bonus extra quando os dois modificadores estao ativos
    for (var _i = 0; _i < array_length(global.synergies); _i++) {
        var _sy = global.synergies[_i];
        if (!run_has_mod(_sy.a) || !run_has_mod(_sy.b)) continue;
        _st[$ _sy.stat] += _sy.amount;
        if (!array_contains(_run.synergies, _sy.sid)) {
            array_push(_run.synergies, _sy.sid);
            toast_show("SINERGIA " + _sy.name + ": " + _sy.desc);
        }
    }
    // limites de seguranca: velocidade alta demais atrapalha camera e leitura
    _st.speed_mult = min(_st.speed_mult, CFG.rewards.speed_mult_cap);
    _st.damage_taken_mult = max(_st.damage_taken_mult, 0.4);
    _run.stats = _st;
}

/// Entrega uma recompensa ao jogador e mostra o aviso.
function mod_grant(_mid) {
    var _d = mod_get(_mid);
    var _run = global.run;
    switch (_d.category) {
        case "heal":
            run_heal(_d.amount);
            break;
        case "max_hp":
            _run.hp_max += _d.amount;
            run_heal(_d.amount);
            array_push(_run.modifiers, _mid);
            break;
        case "weapon":
            weapon_equip(_d.weapon, CFG.weapons[$ _d.weapon].durability);
            break;
        case "curse":
            if (variable_struct_exists(_d, "max_hp")) {
                _run.hp_max = max(20, _run.hp_max + _d.max_hp);
                _run.hp = min(_run.hp, _run.hp_max);
            }
            array_push(_run.modifiers, _mid);
            break;
        default:
            array_push(_run.modifiers, _mid);
            break;
    }
    // o aviso da recompensa vem antes: se ela ativar uma sinergia, o aviso da
    // sinergia (dentro de run_recompute_stats) fica por cima
    toast_show(_d.name + ": " + _d.desc);
    run_recompute_stats();
}

/// Recompensas que ainda fazem sentido (passivas nao acumulam).
function reward_candidates(_pool) {
    var _c = [];
    for (var _i = 0; _i < array_length(_pool); _i++) {
        var _d = mod_get(_pool[_i]);
        if (_d.stackable || !run_has_mod(_pool[_i])) array_push(_c, _pool[_i]);
    }
    return _c;
}

/// Sorteia ate _count recompensas distintas, de forma fixa para a mesma seed.
function reward_roll(_pool, _count, _seed) {
    var _c = reward_candidates(_pool);
    var _out = [];
    for (var _k = 0; _k < _count && array_length(_c) > 0; _k++) {
        var _idx = floor(decor_rand(_seed, 700 + _k) * array_length(_c));
        array_push(_out, _c[_idx]);
        array_delete(_c, _idx, 1);
    }
    return _out;
}

// ------------------------------------------------------------------ armas

/// Regra inicial: a arma substitui o combo por um golpe unico, perde 1 de
/// durabilidade por acerto, quebra em 0 e cai no chao se o jogador for derrubado.
function weapon_equip(_wid, _durability) {
    global.run.weapon = { wid: _wid, durability: _durability };
}

function weapon_def(_wid) {
    return CFG.weapons[$ _wid];
}

/// Chamado a cada acerto com a arma.
function weapon_use() {
    var _wp = global.run.weapon;
    if (is_undefined(_wp)) return;
    _wp.durability--;
    if (_wp.durability <= 0) {
        toast_show(weapon_def(_wp.wid).name + " quebrou!");
        global.run.weapon = undefined;
    }
}

/// Solta a arma no chao como item (ao ser derrubado).
function weapon_drop(_x, _y) {
    var _wp = global.run.weapon;
    if (is_undefined(_wp)) return;
    var _map_index = (global.stage.kind == "main_map") ? global.stage_rt.map_index : -1;
    var _drop_key = (_map_index >= 0) ? run_map_new_drop_key() : "";
    instance_create_depth(_x, _y, 0, obj_interact, {
        kind: "weapon",
        wid: _wp.wid,
        durability: _wp.durability,
        map_index: _map_index,
        drop_key: _drop_key
    });
    global.run.weapon = undefined;
}

// ----------------------------------------------------------- moeda e abates

/// Moeda temporaria da run (so para a loja); some em run_reset().
/// _coin_mult: elites valem mais. _x/_y: onde mostrar o numero de moedas.
function run_enemy_killed(_coin_mult = 1, _x = undefined, _y = undefined) {
    var _run = global.run;
    if (!_run.active) return;
    var _coins = round(CFG.rewards.coins_per_enemy * _coin_mult * _run.stats.coin_mult);
    _run.coins += _coins;
    _run.kills += 1;
    if (!is_undefined(_x)) fx_number(_x, _y, "+" + string(_coins), make_colour_rgb(255, 210, 63));
    if (_run.stats.kill_heal > 0) run_heal(_run.stats.kill_heal);
    if (_run.stats.kill_special > 0) {
        _run.special = min(CFG.player.special.meter_max, _run.special + _run.stats.kill_special);
    }
}

// ------------------------------------------------------------------ avisos

function toast_show(_text) {
    global.toast.text = _text;
    global.toast.timer = CFG.rewards.toast_frames;
}
