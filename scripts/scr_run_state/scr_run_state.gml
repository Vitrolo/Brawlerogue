/// Estado da run. Tudo que e temporario (vida, especial, modificadores, arma)
/// vive em global.run e e apagado por run_reset().

function run_reset() {
    global.run = {
        active: false,
        seed: 0,
        graph: undefined,   // rota gerada em run_start (scr_route)
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
    // A rota inteira e sorteada agora, antes de qualquer outro uso do gerador
    // aleatorio: a mesma seed sempre produz as mesmas salas e conexoes.
    global.run.graph = run_graph_build();
    run_goto_node(global.run.graph.start);
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
