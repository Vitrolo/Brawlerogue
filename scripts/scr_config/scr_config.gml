/// Configuracao central do jogo. Todo o balanceamento fica aqui.
/// Tempos em frames (60 fps), velocidades em pixels por frame, na resolucao interna 480x270.

#macro CFG global.cfg
#macro VIEW_W 480
#macro VIEW_H 270

function config_init() {
    global.cfg = {
        view: {
            scale_max: 3,      // escala maxima da janela (multiplo inteiro de 480x270)
            gui_w: 960,        // a interface usa o dobro da resolucao interna para texto legivel
            gui_h: 540
        },
        camera: {
            lerp: 0.12,        // suavizacao ao seguir o jogador (1 = instantaneo)
            shake_decay: 0.8
        },
        flow: {
            defeat_frames: 150,
            victory_frames: 270
        },
        run: {
            layers_per_biome: 4,       // salas visitadas por bioma (minimo 2: entrada e saida)
            branch_min: 2,             // opcoes por camada do meio
            branch_max: 3,
            extra_combat_chance: 0.4,  // chance da 3a opcao ser combate
            extra_path_chance: 0.5,    // chance de uma sala ganhar uma segunda saida
            special_kinds: [["reward", 4], ["rest", 3], ["shop", 2], ["event", 2]], // tipo e peso
            boss_stage: "boss_arena",
            max_attempts: 5,
            door_spacing: 64,
            banner_frames: 150
        },
        feedback: {
            flash_frames: 5,
            shake_hit: 2,
            shake_hurt: 4
        },
        stage: {
            edge_margin: 6,    // distancia minima entre atores e a borda da sala/arena
        },
        physics: {
            gravity: 0.28,
            knock_friction: 0.86,
            min_launch: 2.4,   // impulso vertical minimo de um nocaute
        },
        player: {
            hp_max: 100,
            speed_x: 1.6,
            speed_y: 1.1,
            body_w: 9,         // meia largura da hurtbox
            body_h: 40,        // altura da hurtbox
            jump_start_frames: 3,
            jump_speed: 4.7,
            air_depth_mult: 0.5, // controle de profundidade no ar
            land_frames: 4,
            buffer_frames: 8,  // quanto tempo um comando fica guardado
            hurt_frames: 16,
            invuln_frames: 45, // invulnerabilidade apos dano
            knockdown_frames: 40,
            getup_frames: 18,
            combo: ["punch1", "punch2", "kick"],
            combo_requires_hit: false,     // true = so encadeia se o golpe anterior acertou
            dodge_cancels_recovery: true,  // esquiva cancela a recuperacao de um golpe
            air_attack: "air_kick",
            grab: {
                range: 24,          // alcance a frente para agarrar
                lane: 8,            // tolerancia de profundidade
                hold_frames: 80,    // tempo maximo segurando antes de soltar
                hold_offset: 16,    // distancia do inimigo segurado
                knee_attack: "grab_knee",
                knee_max: 3,        // joelhadas por agarrao
                knee_frames: 14,    // intervalo entre joelhadas
                throw_frames: 18,
                throw_speed: 5,
                throw_launch: 3.4,
                throw_damage: 14,   // dano do inimigo arremessado ao cair
                throw_attack: "thrown_body"
            },
            dodge: {
                frames: 18,
                speed: 3.2,
                iframe_start: 2,
                iframe_end: 13,
                cooldown: 20
            },
            block: {
                damage_mult: 0.2, // dano recebido ao bloquear pela frente
                pushback: 1.4,
                min_frames: 6,
                front_only: true
            },
            special: {
                attack: "special_spin",
                meter_max: 100,
                cost: 50,
                gain_on_hit: 8,
                gain_on_hurt: 5,
                invulnerable: true
            }
        },
        horde: {
            max_attackers: 2,   // inimigos que podem atacar ao mesmo tempo
            token_timeout: 180, // desiste do ataque se nao alcancar o jogador
        },
        encounter: {
            wave_delay: 45,     // pausa entre ondas
            max_wave_size: 5,   // inimigos por onda (excedente da sala e ignorado)
            go_frames: 240      // tempo em que o "GO" pisca grande
        },
        rewards: {
            rest_heal_pct: 0.3,    // descanso cura esta fracao da vida maxima
            coins_per_enemy: 5,    // moeda temporaria da run, usada so na loja
            speed_mult_cap: 1.6,   // teto do bonus de velocidade
            choices: 3,            // opcoes em uma sala de recompensa
            shop_items: 3,         // itens sorteados na loja (alem da cura fixa)
            toast_frames: 180      // duracao do aviso de recompensa
        },
        weapon_rules: {
            drop_on_knockdown: true // arma cai no chao quando o jogador e derrubado
        },
        weapons: {},
        attacks: {},
        enemies: {}
    };

    config_attacks_init();
    config_enemies_init();
}

/// Registra um golpe. Campos omitidos usam os padroes abaixo.
function attack_define(_name, _fields) {
    var _d = {
        name: _name,
        startup: 6,        // frames antes da hitbox
        active: 4,         // frames com hitbox ativa
        recovery: 12,      // frames depois da hitbox
        damage: 5,
        offset_x: 2,       // inicio da hitbox a frente do centro do atacante
        reach: 24,         // comprimento horizontal da hitbox
        lane: 10,          // tolerancia de profundidade (diferenca de y dos pes)
        z_bottom: 0,       // faixa de altura, relativa a altura do atacante
        z_top: 44,
        knock_x: 1.5,
        knock_z: 0,
        knockdown: false,
        both_sides: false, // acerta dos dois lados do atacante
        unblockable: false,
        hitstop: 4,
        lunge: 0,          // avanco por frame durante o startup
        cancel_after: 2,   // frames de recuperacao antes de poder encadear o proximo golpe
        sprite: -1,        // sprite de 3 frames: preparacao, ativo, recuperacao
    };
    var _keys = variable_struct_get_names(_fields);
    for (var _i = 0; _i < array_length(_keys); _i++) {
        _d[$ _keys[_i]] = _fields[$ _keys[_i]];
    }
    CFG.attacks[$ _name] = _d;
}

function attack_get(_name) {
    return CFG.attacks[$ _name];
}

function config_attacks_init() {
    // Jogador
    attack_define("punch1", { startup: 4, active: 3, recovery: 10, damage: 6, reach: 26, knock_x: 1.2, lunge: 0.6, cancel_after: 1, sprite: spr_player_attack1 });
    attack_define("punch2", { startup: 5, active: 3, recovery: 12, damage: 7, reach: 28, knock_x: 1.4, lunge: 0.6, cancel_after: 1, sprite: spr_player_attack2 });
    attack_define("kick", { startup: 7, active: 4, recovery: 18, damage: 12, reach: 32, knock_x: 3.2, knock_z: 3.2, knockdown: true, hitstop: 7, lunge: 1.0, sprite: spr_player_attack3 });
    attack_define("air_kick", { startup: 3, active: 40, recovery: 0, damage: 9, reach: 26, knock_x: 2.6, knock_z: 2.8, knockdown: true, z_bottom: -34, z_top: 16, sprite: spr_player_air_attack });
    attack_define("special_spin", { startup: 5, active: 10, recovery: 16, damage: 16, reach: 38, lane: 18, both_sides: true, knock_x: 3.6, knock_z: 3.6, knockdown: true, hitstop: 8, sprite: spr_player_special });

    // Agarrao: joelhada no inimigo segurado e corpo arremessado que derruba outros
    attack_define("grab_knee", { damage: 5, knock_x: 0, hitstop: 4 });
    attack_define("thrown_body", { startup: 0, active: 45, recovery: 0, damage: 10, reach: 14, lane: 10, z_bottom: -10, both_sides: true, knock_x: 2.5, knock_z: 2.8, knockdown: true, hitstop: 5 });

    // Armas: um golpe unico que substitui o combo enquanto a arma durar
    attack_define("weapon_pipe", { startup: 6, active: 4, recovery: 14, damage: 14, reach: 42, knock_x: 2.4, hitstop: 6, lunge: 0.5, sprite: spr_player_attack1 });
    attack_define("weapon_bat", { startup: 9, active: 4, recovery: 18, damage: 20, reach: 36, knock_x: 3.4, knock_z: 3.2, knockdown: true, hitstop: 8, lunge: 0.8, sprite: spr_player_attack2 });
    CFG.weapons[$ "w_pipe"] = { name: "Cano", attack: "weapon_pipe", durability: 12, length: 20, colour: make_colour_rgb(170, 180, 190) };
    CFG.weapons[$ "w_bat"] = { name: "Taco", attack: "weapon_bat", durability: 8, length: 16, colour: make_colour_rgb(200, 150, 90) };

    attack_define("runner_jab", { startup: 3, active: 3, recovery: 10, damage: 5, reach: 20, lane: 8, knock_x: 1.2, lunge: 1.4, hitstop: 3, sprite: spr_runner_attack });
    attack_define("brute_smash", { startup: 6, active: 5, recovery: 22, damage: 14, reach: 30, lane: 10, knock_x: 3, knock_z: 3, knockdown: true, hitstop: 7, lunge: 0.6, sprite: spr_brute_attack });

    // Chefe (os avisos ficam na config do chefe)
    attack_define("boss_swipe", { startup: 8, active: 4, recovery: 12, damage: 12, reach: 44, lane: 12, z_top: 60, knock_x: 2.4, lunge: 1.2, hitstop: 6, sprite: spr_boss_attack });
    attack_define("boss_dash", { startup: 0, active: 46, recovery: 0, damage: 16, offset_x: -6, reach: 30, lane: 11, z_top: 60, knock_x: 3.5, knock_z: 3, knockdown: true, hitstop: 8 });
    // z_top baixo: pular no momento do impacto evita o slam
    attack_define("boss_slam", { startup: 0, active: 5, recovery: 0, damage: 18, reach: 48, lane: 24, z_top: 14, both_sides: true, unblockable: true, knock_x: 3, knock_z: 3.6, knockdown: true, hitstop: 8 });

    // Inimigos (o aviso/telegraph vem antes do startup e fica na config do inimigo)
    attack_define("thug_punch", { startup: 4, active: 4, recovery: 14, damage: 8, reach: 24, lane: 8, knock_x: 1.8, lunge: 0.8, sprite: spr_thug_attack });
}

function config_enemies_init() {
    // Capanga: corpo a corpo basico. Aproxima, avisa, soca, recua.
    CFG.enemies[$ "thug"] = {
        name: "Capanga",
        ai: "basic",
        scale: 1,
        grabbable: true,
        hp_max: 30,
        speed_x: 0.8,
        speed_y: 0.55,
        body_w: 9,
        body_h: 40,
        attack: "thug_punch",
        attack_range: 24,     // distancia horizontal em que para para atacar
        lane_ok: 6,           // diferenca de profundidade aceita para atacar
        circle_dist: 62,      // distancia em que espera a vez
        spawn_frames: 30,
        telegraph_frames: 28, // aviso antes do golpe
        recover_frames: 40,
        think_min: 30,        // espera entre ataques
        think_max: 100,
        hurt_frames: 18,
        knockdown_frames: 50,
        getup_frames: 20,
        dead_frames: 50,
        sprites: {
            idle: spr_thug_idle,
            walk: spr_thug_walk,
            telegraph: spr_thug_telegraph,
            attack: spr_thug_attack,
            hurt: spr_thug_hurt,
            knockdown: spr_thug_knockdown,
            getup: spr_thug_getup,
            dead: spr_thug_dead
        }
    };

    // Corredor: fragil e rapido. Aviso curto, golpe fraco, volta a atacar logo.
    CFG.enemies[$ "runner"] = {
        name: "Corredor",
        ai: "basic",
        scale: 1,
        grabbable: true,
        hp_max: 18,
        speed_x: 1.35,
        speed_y: 0.9,
        body_w: 8,
        body_h: 40,
        attack: "runner_jab",
        attack_range: 20,
        lane_ok: 6,
        circle_dist: 84,
        spawn_frames: 30,
        telegraph_frames: 20,
        recover_frames: 26,
        think_min: 20,
        think_max: 60,
        hurt_frames: 16,
        knockdown_frames: 40,
        getup_frames: 16,
        dead_frames: 50,
        sprites: {
            idle: spr_runner_idle,
            walk: spr_runner_walk,
            telegraph: spr_runner_telegraph,
            attack: spr_runner_attack,
            hurt: spr_runner_hurt,
            knockdown: spr_runner_knockdown,
            getup: spr_runner_getup,
            dead: spr_runner_dead
        }
    };

    // Bruto: lento e resistente. Aviso longo, golpe que derruba, recuperacao longa.
    // Pesado demais para ser agarrado.
    CFG.enemies[$ "brute"] = {
        name: "Bruto",
        ai: "basic",
        scale: 1,
        grabbable: false,
        hp_max: 60,
        speed_x: 0.55,
        speed_y: 0.4,
        body_w: 12,
        body_h: 48,
        attack: "brute_smash",
        attack_range: 28,
        lane_ok: 6,
        circle_dist: 50,
        spawn_frames: 30,
        telegraph_frames: 42,
        recover_frames: 60,
        think_min: 50,
        think_max: 120,
        hurt_frames: 12,
        knockdown_frames: 60,
        getup_frames: 26,
        dead_frames: 50,
        sprites: {
            idle: spr_brute_idle,
            walk: spr_brute_walk,
            telegraph: spr_brute_telegraph,
            attack: spr_brute_attack,
            hurt: spr_brute_hurt,
            knockdown: spr_brute_knockdown,
            getup: spr_brute_getup,
            dead: spr_brute_dead
        }
    };

    // Chefe final: tres padroes com aviso e duas fases (ver scr_boss).
    // Listas de dois valores = [fase 1, fase 2].
    CFG.enemies[$ "boss"] = {
        name: "CHEFE",
        ai: "boss",
        grabbable: false,
        hp_max: 260,
        speed_x: 1.0,
        speed_y: 0.7,
        body_w: 13,
        body_h: 56,
        scale: 1.25,           // sprite de 64 px ampliado para ficar maior que o bruto
        think_min: 0,          // lidos pela criacao comum de inimigos; o chefe nao usa
        think_max: 0,
        intro_frames: 90,
        keep_dist: 60,         // distancia que tenta manter enquanto decide
        near_dist: 80,         // abaixo disso prefere o swipe
        think_frames: [55, 35],
        tele_mult: [1, 0.75],  // duracao dos avisos
        hurt_frames: 10,
        max_hurt_chain: 3,     // apos tantos golpes seguidos, revida com armadura
        phase2_at: 0.5,
        phase_frames: 80,
        summon: ["thug", "thug"],
        dead_frames: 150,
        swipe: { attack: "boss_swipe", telegraph: 30, hits: [2, 3], recover: 50 },
        dash: { attack: "boss_dash", telegraph: 42, speed: 5, repeats: [1, 2], recover: 70 },
        slam: { attack: "boss_slam", air_frames: 50, land_frames: 14, repeats: [1, 2], recover: 60 },
        sprites: {
            idle: spr_boss_idle,
            walk: spr_boss_walk,
            telegraph: spr_boss_telegraph,
            attack: spr_boss_attack,
            dash: spr_boss_dash,
            jump: spr_boss_jump,
            land: spr_boss_land,
            hurt: spr_boss_hurt,
            dead: spr_boss_dead
        }
    };
}
