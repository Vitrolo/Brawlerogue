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
        ui: {
            splash_frames: 240     // duracao da tela de carregamento (ESPACO pula)
        },
        meta: {
            // fichas (moeda permanente) ganhas ao fim de cada run
            chips_per_kill: 0.5,
            chips_per_section: 2,
            chips_per_boss: 10,
            chips_victory: 25
        },
        elite: {
            chance: [0.06, 0.12, 0.18], // chance por inimigo, por bioma
            hp_mult: 1.8,
            damage_mult: 1.35,
            coin_mult: 4
        },
        props: {
            breakables_per_section: [1, 3], // minimo e maximo por trecho de combate
            entrance_clear_x: 44,           // objetos a menos disto de uma entrada...
            entrance_clear_depth: 44,       // ...vao para longe da parede (y >= chao + isto)
            hazard_chance: 0.7,             // chance de um trecho ter um perigo do bioma
            coin_drop: [3, 8],
            food_chance: 0.25,
            food_heal: 15,
            kicked_speed: 5.5,
            kicked_frames: 38,
            toxic_interval: 36,             // frames entre danos da poca
            car_cycle: 420,                 // frames entre passagens do carro
            car_warn: 80,
            car_speed: 8,
            skylight_player_damage: 18
        },
        challenge: {
            timer_frames: 2700,             // 45 s no desafio contra o tempo
            reward_coins: 40,
            reward_chips: 3
        },
        run: {
            layers_per_biome: 4,       // salas visitadas por bioma (minimo 2: entrada e saida)
            branch_min: 2,             // opcoes por camada do meio
            branch_max: 3,
            extra_combat_chance: 0.4,  // chance da 3a opcao ser combate
            extra_path_chance: 0.5,    // chance de uma sala ganhar uma segunda saida
            special_kinds: [["reward", 4], ["rest", 3], ["shop", 2], ["event", 2]], // tipo e peso
            boss_stage: "boss_arena",
            biome_bosses: ["boss_sewer", "boss_streets", "boss"], // chefe do fim de cada corredor
            special_slots: 3,          // (rota antiga) entradas especiais por corredor
            // Corredor de cada bioma: inicio vazio + trechos de meio + saida + chefe.
            sections_per_biome: 10,    // total de trechos, contando inicio e arena do chefe
            start_width: 640,          // largura do trecho inicial (sem conteudo)
            // Entradas especiais: loja, tesouro e desafio sempre; descanso com chance.
            special_required: ["shop", "reward", "challenge"],
            rest_chance: 0.5,
            special_edge_margin: 320,  // distancia minima do fim do inicio e do comeco da arena
            special_min_gap: 900,      // distancia minima entre duas entradas
            special_place_attempts: 8, // ordens de tiles tentadas antes de relaxar a distancia
            boss_exit_walkout: 56,     // depois do chefe, quanto o jogador anda alem da borda direita
            boss_exit_trigger: 36,     // passar width + isto leva ao proximo bioma (ou a vitoria)
            max_attempts: 5,
            door_spacing: 64,
            banner_frames: 150
        },
        // Indicador acima das entradas especiais do corredor (desenhado no HUD).
        entrance_marker: {
            gap: 6,            // espaco entre o topo da porta e a ponta da seta (pixels do mundo)
            radius: 12,        // raio do icone (pixels da interface)
            arrow: 7,          // tamanho da seta
            pulse_speed: 0.004,// velocidade da pulsacao (radianos por ms)
            pulse_scale: 0.08, // variacao de escala
            bob: 3             // deslocamento vertical da pulsacao (pixels da interface)
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
            max_wave_size: 10,  // inimigos por onda (excedente e ignorado); cabe a onda dobrada
            go_frames: 240,     // tempo em que o "GO" pisca grande
            // Quantidade de inimigos comuns por onda na geracao do corredor: a onda
            // desenhada a mao ganha (mult - 1) vezes o seu tamanho em inimigos extras,
            // de tipos sorteados do bioma (biome.enemy_pool). Chefes nunca.
            // Os desafios tambem usam este multiplicador.
            enemy_count_mult: 2,
            // Entrada dos inimigos: cada um surge num ponto aleatorio fora da camera
            // (lado, distancia e profundidade sorteados) e caminha ate um ponto
            // aleatorio dentro da tela antes de agir.
            offscreen_margin: 28,   // distancia minima alem da borda da camera
            offscreen_jitter: 72,   // distancia extra sorteada alem da margem
            enter_inset: 36,        // ponto de chegada fica ao menos isto dentro da tela
            enter_reach: 0.45,      // ate que fracao da tela o inimigo avanca a partir do lado em que entrou
            enter_timeout: 300      // frames: se nao chegar, comeca a agir mesmo assim
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
        rush: 0,           // avanco por frame enquanto a hitbox esta ativa (investidas)
        guard_break: false, // passa pelo escudo do Escudeiro
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
    attack_define("special_spin", { startup: 5, active: 10, recovery: 16, damage: 16, reach: 38, lane: 18, both_sides: true, knock_x: 3.6, knock_z: 3.6, knockdown: true, hitstop: 8, guard_break: true, sprite: spr_player_special });

    // Safira (segunda personagem): golpes curtos e rapidos, especial de investida
    attack_define("s_jab1", { startup: 3, active: 2, recovery: 7, damage: 4, reach: 24, knock_x: 0.8, lunge: 0.5, cancel_after: 1, hitstop: 3, sprite: spr_p2_attack1 });
    attack_define("s_jab2", { startup: 3, active: 2, recovery: 8, damage: 4, reach: 24, knock_x: 0.8, lunge: 0.5, cancel_after: 1, hitstop: 3, sprite: spr_p2_attack2 });
    attack_define("s_jab3", { startup: 3, active: 3, recovery: 9, damage: 5, reach: 26, knock_x: 1.2, lunge: 0.6, cancel_after: 1, hitstop: 3, sprite: spr_p2_attack1 });
    attack_define("s_kick", { startup: 5, active: 4, recovery: 15, damage: 10, reach: 30, knock_x: 3, knock_z: 3, knockdown: true, hitstop: 6, lunge: 1.2, sprite: spr_p2_attack3 });
    attack_define("s_air", { startup: 3, active: 40, recovery: 0, damage: 8, reach: 26, knock_x: 2.4, knock_z: 2.6, knockdown: true, z_bottom: -34, z_top: 16, sprite: spr_p2_air_attack });
    attack_define("s_rush", { startup: 4, active: 14, recovery: 14, damage: 14, reach: 30, lane: 14, knock_x: 3.2, knock_z: 3, knockdown: true, hitstop: 5, rush: 5.5, guard_break: true, sprite: spr_p2_air_attack });

    // Golpes criados por modificadores
    attack_define("dodge_strike", { startup: 0, active: 14, recovery: 0, damage: 6, offset_x: -4, reach: 20, lane: 10, knock_x: 1.6, hitstop: 2 });
    attack_define("reflect", { damage: 0, knock_x: 1.2, hitstop: 2 });

    // Agarrao: joelhada no inimigo segurado e corpo arremessado que derruba outros
    attack_define("grab_knee", { damage: 5, knock_x: 0, hitstop: 4 });
    attack_define("thrown_body", { startup: 0, active: 45, recovery: 0, damage: 10, reach: 14, lane: 10, z_bottom: -10, both_sides: true, knock_x: 2.5, knock_z: 2.8, knockdown: true, hitstop: 5, guard_break: true });

    // Armas: um golpe unico que substitui o combo enquanto a arma durar
    attack_define("weapon_pipe", { startup: 6, active: 4, recovery: 14, damage: 14, reach: 42, knock_x: 2.4, hitstop: 6, lunge: 0.5, sprite: spr_player_attack1 });
    attack_define("weapon_bat", { startup: 9, active: 4, recovery: 18, damage: 20, reach: 36, knock_x: 3.4, knock_z: 3.2, knockdown: true, hitstop: 8, lunge: 0.8, guard_break: true, sprite: spr_player_attack2 });
    CFG.weapons[$ "w_pipe"] = { name: "Cano", attack: "weapon_pipe", durability: 12, length: 20, colour: make_colour_rgb(170, 180, 190), sprite: spr_weapon_pipe };
    CFG.weapons[$ "w_bat"] = { name: "Taco", attack: "weapon_bat", durability: 8, length: 16, colour: make_colour_rgb(200, 150, 90), sprite: spr_weapon_bat };

    attack_define("runner_jab", { startup: 3, active: 3, recovery: 10, damage: 5, reach: 20, lane: 8, knock_x: 1.2, lunge: 1.4, hitstop: 3, sprite: spr_runner_attack });
    attack_define("brute_smash", { startup: 6, active: 5, recovery: 22, damage: 14, reach: 30, lane: 10, knock_x: 3, knock_z: 3, knockdown: true, hitstop: 7, lunge: 0.6, sprite: spr_brute_attack });

    // Inimigos novos: tiro (o projetil usa reach/lane/z como volume), escudo e explosao
    attack_define("shooter_shot", { startup: 6, active: 1, recovery: 24, damage: 7, offset_x: -5, reach: 10, lane: 7, z_bottom: -12, z_top: 12, knock_x: 1.5, hitstop: 3, sprite: spr_shooter_attack });
    attack_define("shield_bash", { startup: 5, active: 4, recovery: 16, damage: 9, reach: 24, lane: 8, knock_x: 2.4, lunge: 1.0, sprite: spr_shield_attack });
    attack_define("bomber_blast", { startup: 2, active: 1, recovery: 0, damage: 16, reach: 36, lane: 20, z_top: 50, both_sides: true, knock_x: 3, knock_z: 3.4, knockdown: true, hitstop: 6, guard_break: true, sprite: spr_bomber_attack });

    // Cenario: perigos e objetos chutados
    attack_define("hazard_toxic", { damage: 4, knock_x: 0, hitstop: 0 });
    attack_define("hazard_car", { damage: 16, reach: 24, lane: 9, z_top: 30, both_sides: true, knock_x: 3.5, knock_z: 3.4, knockdown: true, hitstop: 6, guard_break: true });
    attack_define("hazard_skylight", { damage: 18, knock_x: 0, hitstop: 4, unblockable: true });
    attack_define("prop_kicked", { damage: 10, reach: 12, lane: 9, z_top: 30, both_sides: true, knock_x: 2.6, knock_z: 2.8, knockdown: true, hitstop: 4, guard_break: true });

    // Chefes dos dois primeiros biomas (mesmos padroes do chefe final, com outro peso)
    attack_define("bsewer_swipe", { startup: 10, active: 5, recovery: 14, damage: 12, reach: 40, lane: 12, z_top: 60, knock_x: 2.8, lunge: 1.0, hitstop: 6, sprite: spr_bsewer_attack });
    attack_define("bstreet_swipe", { startup: 6, active: 4, recovery: 10, damage: 9, reach: 38, lane: 12, z_top: 60, knock_x: 2.0, lunge: 1.6, hitstop: 5, sprite: spr_bstreet_attack });

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

    // Atirador: fica longe, alinha na profundidade e atira. Fragil de perto.
    CFG.enemies[$ "shooter"] = {
        name: "Atirador",
        ai: "basic",
        scale: 1,
        grabbable: true,
        hp_max: 16,
        speed_x: 1.0,
        speed_y: 0.8,
        body_w: 8,
        body_h: 40,
        attack: "shooter_shot",
        projectile: { speed: 3.4, z: 24, life: 110 },
        attack_range: 150,    // distancia de tiro
        lane_ok: 5,
        circle_dist: 175,
        spawn_frames: 30,
        telegraph_frames: 36,
        recover_frames: 50,
        think_min: 40,
        think_max: 110,
        hurt_frames: 18,
        knockdown_frames: 45,
        getup_frames: 18,
        dead_frames: 50,
        sprites: {
            idle: spr_shooter_idle, walk: spr_shooter_walk, telegraph: spr_shooter_telegraph, attack: spr_shooter_attack,
            hurt: spr_shooter_hurt, knockdown: spr_shooter_knockdown, getup: spr_shooter_getup, dead: spr_shooter_dead
        }
    };

    // Escudeiro: bloqueia golpes pela frente. Agarre, acerte por tras ou use
    // golpes que quebram a guarda (especial, corpo arremessado, taco, explosao).
    CFG.enemies[$ "shield"] = {
        name: "Escudeiro",
        ai: "basic",
        scale: 1,
        grabbable: true,
        shield: true,
        hp_max: 34,
        speed_x: 0.7,
        speed_y: 0.5,
        body_w: 9,
        body_h: 40,
        attack: "shield_bash",
        attack_range: 24,
        lane_ok: 6,
        circle_dist: 56,
        spawn_frames: 30,
        telegraph_frames: 30,
        recover_frames: 46,
        think_min: 35,
        think_max: 100,
        hurt_frames: 18,
        knockdown_frames: 50,
        getup_frames: 20,
        dead_frames: 50,
        sprites: {
            idle: spr_shield_idle, walk: spr_shield_walk, telegraph: spr_shield_telegraph, attack: spr_shield_attack,
            hurt: spr_shield_hurt, knockdown: spr_shield_knockdown, getup: spr_shield_getup, dead: spr_shield_dead
        }
    };

    // Homem-bomba: corre ate o jogador, avisa e explode. Tambem explode ao morrer,
    // e a explosao acerta outros inimigos.
    CFG.enemies[$ "bomber"] = {
        name: "Homem-bomba",
        ai: "basic",
        scale: 1,
        grabbable: true,
        explode: true,
        hp_max: 14,
        speed_x: 1.2,
        speed_y: 0.85,
        body_w: 9,
        body_h: 40,
        attack: "bomber_blast",
        attack_range: 18,
        lane_ok: 10,
        circle_dist: 70,
        spawn_frames: 30,
        telegraph_frames: 44,
        recover_frames: 10,
        think_min: 20,
        think_max: 70,
        hurt_frames: 16,
        knockdown_frames: 40,
        getup_frames: 16,
        dead_frames: 36,
        sprites: {
            idle: spr_bomber_idle, walk: spr_bomber_walk, telegraph: spr_bomber_telegraph, attack: spr_bomber_attack,
            hurt: spr_bomber_hurt, knockdown: spr_bomber_knockdown, getup: spr_bomber_getup, dead: spr_bomber_dead
        }
    };

    // Chefe final: tres padroes com aviso e duas fases (ver scr_boss).
    // Listas de dois valores = [fase 1, fase 2].
    CFG.enemies[$ "boss"] = {
        name: "O CHEFE",
        ai: "boss",
        grabbable: false,
        hp_max: 260,
        speed_x: 1.0,
        speed_y: 0.7,
        body_w: 13,
        body_h: 56,
        scale: 1,              // escala inteira: ampliar por 1.25 deformava os pixels
        think_min: 0,          // lidos pela criacao comum de inimigos; o chefe nao usa
        think_max: 0,
        intro_frames: 90,
        keep_dist: 60,         // distancia que tenta manter enquanto decide
        near_dist: 80,         // abaixo disso prefere o swipe
        near_patterns: ["swipe", "swipe", "slam"], // sorteio do padrao com o jogador perto
        far_patterns: ["dash", "slam", "dash"],    // e com o jogador longe
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

    // Chefe do esgoto: lento e pesado, vive do slam e chama um homem-bomba.
    CFG.enemies[$ "boss_sewer"] = struct_merge(CFG.enemies[$ "boss"], {
        name: "REI DO ESGOTO",
        hp_max: 150,
        speed_x: 0.75,
        speed_y: 0.55,
        body_w: 14,
        body_h: 56,
        scale: 1,
        near_patterns: ["swipe", "slam", "slam"],
        far_patterns: ["slam", "dash", "slam"],
        summon: ["thug", "bomber"],
        swipe: { attack: "bsewer_swipe", telegraph: 36, hits: [1, 2], recover: 60 },
        dash: { attack: "boss_dash", telegraph: 50, speed: 4, repeats: [1, 1], recover: 80 },
        slam: { attack: "boss_slam", air_frames: 54, land_frames: 14, repeats: [1, 3], recover: 60 },
        sprites: {
            idle: spr_bsewer_idle, walk: spr_bsewer_walk, telegraph: spr_bsewer_telegraph, attack: spr_bsewer_attack,
            dash: spr_bsewer_dash, jump: spr_bsewer_jump, land: spr_bsewer_land, hurt: spr_bsewer_hurt, dead: spr_bsewer_dead
        }
    });

    // Chefe das ruas: rapida, emenda investidas e chama corredores.
    CFG.enemies[$ "boss_streets"] = struct_merge(CFG.enemies[$ "boss"], {
        name: "RAINHA DO NEON",
        hp_max: 190,
        speed_x: 1.4,
        speed_y: 1.0,
        body_w: 11,
        body_h: 52,
        scale: 1,
        think_frames: [45, 28],
        near_patterns: ["swipe", "swipe", "dash"],
        far_patterns: ["dash", "dash", "slam"],
        summon: ["runner", "runner"],
        swipe: { attack: "bstreet_swipe", telegraph: 24, hits: [3, 4], recover: 46 },
        dash: { attack: "boss_dash", telegraph: 34, speed: 6.5, repeats: [2, 3], recover: 70 },
        slam: { attack: "boss_slam", air_frames: 44, land_frames: 12, repeats: [1, 1], recover: 56 },
        sprites: {
            idle: spr_bstreet_idle, walk: spr_bstreet_walk, telegraph: spr_bstreet_telegraph, attack: spr_bstreet_attack,
            dash: spr_bstreet_dash, jump: spr_bstreet_jump, land: spr_bstreet_land, hurt: spr_bstreet_hurt, dead: spr_bstreet_dead
        }
    });
}

/// Copia rasa de _base com os campos de _over por cima.
function struct_merge(_base, _over) {
    var _out = {};
    var _names = variable_struct_get_names(_base);
    for (var _i = 0; _i < array_length(_names); _i++) _out[$ _names[_i]] = _base[$ _names[_i]];
    _names = variable_struct_get_names(_over);
    for (var _i = 0; _i < array_length(_names); _i++) _out[$ _names[_i]] = _over[$ _names[_i]];
    return _out;
}
