/// Recompensas da run: cura, velocidade, vida maxima, armas e passivas.
/// Tudo e temporario: os modificadores ficam em global.run.modifiers e somem em
/// run_reset(). Para criar um novo, basta um mod_define; nenhuma outra logica muda
/// se ele usar um "stat" ja existente em run_base_stats().

/// Valores que os modificadores alteram. Jogador e combate consultam global.run.stats.
function run_base_stats() {
    return {
        speed_mult: 1,          // velocidade de movimento
        damage_mult: 1,         // dano causado
        damage_taken_mult: 1,   // dano recebido
        special_gain_mult: 1,   // ganho de energia do especial
        kill_heal: 0            // vida recuperada por inimigo derrotado
    };
}

/// category: "heal" | "speed" | "max_hp" | "weapon" | "passive"
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

    // Ordem fixa: os sorteios por seed dependem dela.
    global.reward_pool = ["heal_small", "speed_up", "max_hp_up", "p_power", "p_guard", "p_vamp", "p_charge", "w_pipe", "w_bat"];
    global.passive_pool = ["p_power", "p_guard", "p_vamp", "p_charge"];
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
        default:
            array_push(_run.modifiers, _mid);
            break;
    }
    run_recompute_stats();
    toast_show(_d.name + ": " + _d.desc);
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
    instance_create_depth(_x, _y, 0, obj_interact, { kind: "weapon", wid: _wp.wid, durability: _wp.durability });
    global.run.weapon = undefined;
}

// ----------------------------------------------------------- moeda e abates

/// Moeda temporaria da run (so para a loja); some em run_reset().
function run_enemy_killed() {
    var _run = global.run;
    if (!_run.active) return;
    _run.coins += CFG.rewards.coins_per_enemy;
    if (_run.stats.kill_heal > 0) run_heal(_run.stats.kill_heal);
}

// ------------------------------------------------------------------ avisos

function toast_show(_text) {
    global.toast.text = _text;
    global.toast.timer = CFG.rewards.toast_frames;
}
