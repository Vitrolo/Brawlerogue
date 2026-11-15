/// Estado da run. Tudo que e temporario (vida, especial, modificadores, arma)
/// vive em global.run e e apagado por run_reset(). O que sobrevive entre runs
/// fica em global.meta (scr_meta).

function run_reset() {
    var _char = player_char_def_for_reset();
    var _hp = CFG.player.hp_max + _char.hp_bonus + 10 * meta_level("vigor");
    global.run = {
        active: false,
        seed: 0,
        char: _char.cid,    // personagem fixada no inicio da run
        graph: undefined,   // rota antiga por portas (scr_route); nao usada pelos corredores
        maps: [],           // corredores por bioma e progresso persistente de setores
        map_index: -1,
        return_context: undefined,
        special_rooms: {},  // escolhas, estoque e recompensa ja usada por sala especial
        drop_seq: 0,
        hp: _hp,
        hp_max: _hp,
        special: 0,
        // Valores alterados pelos modificadores (ver scr_modifiers).
        stats: run_base_stats(),
        modifiers: [],
        synergies: [],      // sinergias ja anunciadas
        weapon: undefined,  // { wid, durability } ou undefined
        coins: 0,           // moeda temporaria da loja
        time_frames: 0,
        // estatisticas mostradas na tela de fim de run
        kills: 0,
        dmg_dealt: 0,
        dmg_taken: 0,
        hits_taken: 0,      // golpes sofridos (bloqueios nao contam)
        sections_cleared: 0,
        bosses_killed: 0
    };
}

/// run_reset roda antes de existir uma run: usa a personagem escolhida no lobby.
function player_char_def_for_reset() {
    var _cid = global.meta.char;
    if (!variable_struct_exists(global.chars, _cid)) _cid = "brawler";
    return global.chars[$ _cid];
}

function run_start(_seed = undefined) {
    run_reset();
    if (is_undefined(_seed)) {
        randomize();
        _seed = random_get_seed();
    } else {
        random_set_seed(_seed);
    }
    global.run.seed = _seed;
    global.run.active = true;

    // bonus permanentes comprados no lobby
    global.run.coins = 10 * meta_level("pockets");
    var _arsenal = meta_level("arsenal");
    if (_arsenal >= 2) weapon_equip("w_bat", CFG.weapons[$ "w_bat"].durability);
    else if (_arsenal == 1) weapon_equip("w_pipe", CFG.weapons[$ "w_pipe"].durability);
    run_recompute_stats();

    // Todos os mapas da run sao definidos uma vez, com salas e seeds estaveis.
    global.run.maps = run_maps_build();
    global.run.map_index = 0;
    save_write();
    stage_goto(global.run.maps[0].sid);
}

/// Retoma uma run lida do save, no ultimo ponto de controle.
function run_resume(_run) {
    // completa campos que um save antigo pode nao ter
    run_reset();
    var _def = global.run;
    var _names = variable_struct_get_names(_def);
    for (var _i = 0; _i < array_length(_names); _i++) {
        if (!variable_struct_exists(_run, _names[_i])) _run[$ _names[_i]] = _def[$ _names[_i]];
    }
    global.run = _run;
    run_maps_define_stages();
    run_recompute_stats();
    global.flow.state = FLOW.PLAY;
    global.flow.timer = 0;
    stage_goto(global.run.maps[global.run.map_index].sid);
}

/// Ponto de controle: guarda onde o jogador esta no corredor e grava o slot.
function run_checkpoint() {
    if (!global.run.active || is_undefined(global.stage) || global.stage.kind != "main_map") return;
    var _p = instance_find(obj_player, 0);
    if (_p != noone) {
        global.run.return_context = {
            stage_sid: global.stage.sid,
            x: _p.x,
            y: _p.y,
            facing: _p.facing
        };
    }
    run_map_snapshot_ground_weapons(global.stage_rt.map_index);
    save_write();
    // o contexto so serve para o save: em jogo ele e usado pelas salas especiais
    global.run.return_context = undefined;
}

/// Encerra a run (derrota, vitoria ou abandono) e volta ao lobby sem nada da run.
function run_end(_result) {
    global.last_run_result = _result;
    run_reset();
    global.choice = undefined;
    global.flow.state = FLOW.PLAY;
    global.flow.timer = 0;
    save_write();
    stage_goto("lobby");
}
