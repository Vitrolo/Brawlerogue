/// Estado da run. Tudo que e temporario (vida, especial, modificadores, arma)
/// vive em global.run e e apagado por run_reset().

function run_reset() {
    global.run = {
        active: false,
        seed: 0,
        graph: undefined,   // rota gerada em run_start (scr_route)
        maps: [],           // corredores por bioma e progresso persistente de setores
        map_index: -1,
        return_context: undefined,
        special_rooms: {},  // escolhas, estoque e recompensa ja usada por sala especial
        drop_seq: 0,
        hp: CFG.player.hp_max,
        hp_max: CFG.player.hp_max,
        special: 0,
        // Valores alterados pelos modificadores (ver scr_modifiers).
        stats: run_base_stats(),
        modifiers: [],
        weapon: undefined,  // { wid, durability } ou undefined
        coins: 0,           // moeda temporaria da loja
        time_frames: 0
    };
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
    // Todos os mapas da run sao definidos uma vez, com salas e seeds estaveis.
    global.run.maps = run_maps_build();
    global.run.map_index = 0;
    stage_goto(global.run.maps[0].sid);
}

/// Encerra a run (derrota, vitoria ou abandono) e volta ao lobby sem nada da run.
function run_end(_result) {
    global.last_run_result = _result;
    run_reset();
    global.choice = undefined;
    global.flow.state = FLOW.PLAY;
    global.flow.timer = 0;
    stage_goto("lobby");
}
