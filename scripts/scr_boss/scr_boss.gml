/// Chefe final. Usa o obj_enemy com cfg.ai == "boss": enemy_create/enemy_step/
/// enemy_draw desviam para as funcoes deste script.
///
/// Padroes (todos com aviso antes do dano e uma recuperacao longa para contra-atacar):
///  swipe - chega perto, avisa e da golpes curtos a frente. Evite recuando ou bloqueando.
///  dash  - mostra uma faixa no chao e investe em linha reta. Evite saindo da faixa
///          (profundidade) ou esquivando. Cansa mais no fim: maior janela de ataque.
///  slam  - salta e mostra um circulo onde vai cair. Evite saindo do circulo ou
///          pulando no momento do impacto. Nao pode ser bloqueado.
/// Fase 2 (metade da vida): avisos mais curtos, mais repeticoes e dois capangas.
/// O chefe tem armadura durante avisos e golpes (leva dano, nao e interrompido) e
/// so reage a golpes enquanto anda ou se recupera.

enum BS {
    INTRO,
    IDLE,       // reposiciona e decide o proximo padrao
    TELEGRAPH,  // aviso parado (swipe e dash)
    SWIPE,
    DASH,
    JUMP,       // no ar, a caminho do ponto do slam
    SLAM,       // impacto
    RECOVER,    // janela de contra-ataque
    HURT,
    PHASE,      // transicao de fase, invulneravel
    DEAD
}

function boss_create() {
    state = BS.INTRO;
    draw_scale = cfg.scale;
    phase = 1;
    pattern = "";
    last_pattern = "";
    pattern_rep = 0;
    hit_index = 0;
    tele_len = 0;
    recover_len = 0;
    dash_dir = 1;
    target_x = x;
    target_y = y;
    air_frames = 1;
    hurt_chain = 0;
    facing = -1;
}

function boss_face(_p) {
    facing = (_p.x >= x) ? 1 : -1;
}

function boss_choose_pattern(_p) {
    var _near = abs(_p.x - x) < cfg.near_dist;
    var _options = _near ? cfg.near_patterns : cfg.far_patterns;
    var _pick = _options[irandom(array_length(_options) - 1)];
    if (_pick == last_pattern) _pick = _options[irandom(array_length(_options) - 1)]; // evita repetir demais
    pattern = _pick;
    last_pattern = _pick;
    pattern_rep = 0;
    hurt_chain = 0;
    boss_begin_pattern(_p, 1);
}

/// _tele_mult encurta o aviso em repeticoes do mesmo padrao.
function boss_begin_pattern(_p, _tele_mult) {
    var _ph = phase - 1;
    var _mult = cfg.tele_mult[_ph] * _tele_mult;
    boss_face(_p);
    vx = 0;
    vy = 0;
    switch (pattern) {
        case "swipe":
            hit_index = 0;
            tele_len = ceil(cfg.swipe.telegraph * _mult);
            actor_set_state(BS.TELEGRAPH);
            break;
        case "dash":
            dash_dir = facing;
            tele_len = ceil(cfg.dash.telegraph * _mult);
            actor_set_state(BS.TELEGRAPH);
            break;
        case "slam":
            // salto calculado para cair no ponto marcado depois de air_frames
            target_x = clamp(_p.x, stage_x1() + body_w, stage_x2() - body_w);
            target_y = _p.y;
            air_frames = ceil(cfg.slam.air_frames * _mult);
            vz = CFG.physics.gravity * air_frames * 0.5;
            vx = (target_x - x) / air_frames;
            vy = (target_y - y) / air_frames;
            actor_set_state(BS.JUMP);
            break;
    }
}

function boss_recover(_frames) {
    vx = 0;
    vy = 0;
    recover_len = _frames;
    actor_set_state(BS.RECOVER);
}

function boss_step() {
    if (game_frozen()) return;

    state_timer++;
    anim_clock++;
    if (flash > 0) flash--;

    var _ph = phase - 1;
    var _p = instance_find(obj_player, 0);
    var _fight = (_p != noone) && global.flow.state != FLOW.DEFEAT && global.flow.state != FLOW.VICTORY && _p.state != PS.DEAD;

    switch (state) {
        case BS.INTRO:
            vx = 0;
            vy = 0;
            if (state_timer >= cfg.intro_frames) actor_set_state(BS.IDLE);
            break;

        case BS.IDLE:
            if (!_fight) {
                vx = 0;
                vy = 0;
                break;
            }
            boss_face(_p);
            enemy_move_towards(_p.x - facing * cfg.keep_dist, _p.y);
            if (state_timer >= cfg.think_frames[_ph]) boss_choose_pattern(_p);
            break;

        case BS.TELEGRAPH:
            vx = 0;
            vy = 0;
            if (state_timer >= tele_len) {
                if (pattern == "swipe") {
                    atk = attack_get(cfg.swipe.attack);
                    atk_spawned = false;
                    actor_set_state(BS.SWIPE);
                } else {
                    atk = attack_get(cfg.dash.attack);
                    hitbox_spawn(id, atk);
                    actor_set_state(BS.DASH);
                }
            }
            break;

        case BS.SWIPE:
            vy = 0;
            vx = (state_timer <= atk.startup) ? facing * atk.lunge : 0;
            if (!atk_spawned && state_timer > atk.startup) {
                hitbox_spawn(id, atk);
                atk_spawned = true;
            }
            if (state_timer >= atk.startup + atk.active + atk.recovery) {
                hit_index++;
                if (hit_index < cfg.swipe.hits[_ph] && _fight) {
                    boss_face(_p); // cada golpe da sequencia pode virar
                    atk_spawned = false;
                    actor_set_state(BS.SWIPE);
                } else {
                    boss_recover(cfg.swipe.recover);
                }
            }
            break;

        case BS.DASH:
            vy = 0;
            vx = dash_dir * cfg.dash.speed;
            if (state_timer mod 3 == 0) fx_ghost(id, make_colour_rgb(255, 60, 90));
            var _edge = (dash_dir > 0) ? (stage_x2() - body_w) : (stage_x1() + body_w);
            if (state_timer >= atk.active || abs(x - _edge) < 2) {
                hitbox_clear(id);
                pattern_rep++;
                if (pattern_rep < cfg.dash.repeats[_ph] && _fight) {
                    boss_begin_pattern(_p, 0.6);
                } else {
                    boss_recover(cfg.dash.recover);
                }
            }
            break;

        case BS.JUMP:
            // o pouso e tratado depois da fisica
            break;

        case BS.SLAM:
            vx = 0;
            vy = 0;
            if (state_timer >= cfg.slam.land_frames) {
                pattern_rep++;
                if (pattern_rep < cfg.slam.repeats[_ph] && _fight) {
                    boss_begin_pattern(_p, 0.8);
                } else {
                    boss_recover(cfg.slam.recover);
                }
            }
            break;

        case BS.RECOVER:
            vx = 0;
            vy = 0;
            if (state_timer >= recover_len) {
                hurt_chain = 0;
                actor_set_state(BS.IDLE);
            }
            break;

        case BS.HURT:
            vx *= CFG.physics.knock_friction;
            vy = 0;
            if (state_timer >= cfg.hurt_frames) {
                vx = 0;
                if (hurt_chain >= cfg.max_hurt_chain && _fight) {
                    boss_choose_pattern(_p); // nao fica preso em uma sequencia infinita
                } else {
                    actor_set_state(BS.IDLE);
                }
            }
            break;

        case BS.PHASE:
            vx = 0;
            vy = 0;
            if (state_timer >= cfg.phase_frames) {
                // reforcos entram pelas bordas da arena
                for (var _i = 0; _i < array_length(cfg.summon); _i++) {
                    var _sx = (_i mod 2 == 0) ? stage_x1() + 30 : stage_x2() - 30;
                    instance_create_depth(_sx, global.stage.floor_top + 20 + _i * 30, 0, obj_enemy, { enemy_type: cfg.summon[_i] });
                }
                actor_set_state(BS.IDLE);
            }
            break;

        case BS.DEAD:
            vy = 0;
            if (actor_on_ground()) vx *= CFG.physics.knock_friction;
            if (state_timer >= cfg.dead_frames) instance_destroy();
            break;
    }

    var _landed = actor_physics();
    if (_landed && state == BS.JUMP) {
        vx = 0;
        vy = 0;
        hitbox_spawn(id, attack_get(cfg.slam.attack));
        cam_shake(6);
        fx_dust(x, y, 14);
        actor_set_state(BS.SLAM);
    }

    boss_animate();
}

function boss_on_hit(_hit) {
    if (state == BS.INTRO || state == BS.PHASE || state == BS.DEAD) return HITRES.IGNORED;

    hp = max(0, hp - _hit.damage);
    flash = CFG.feedback.flash_frames;

    if (hp <= 0) {
        run_enemy_killed(4, x, y - z - body_h - 18);
        fx_burst(x, y - z - body_h * 0.5, 30, make_colour_rgb(255, 210, 63), 4);
        hitbox_clear(id);
        vx = _hit.dir * 2;
        vy = 0;
        vz = max(vz, 3);
        actor_set_state(BS.DEAD);
        // a luta acaba: os reforcos caem junto
        with (obj_enemy) {
            if (cfg.ai != "boss" && hp > 0) {
                hp = 0;
                has_token = false;
                hitbox_clear(id);
                vz = CFG.physics.min_launch;
                down_timer = 0;
                actor_set_state(ES.KNOCKDOWN);
            }
        }
        return HITRES.HIT;
    }

    if (phase == 1 && hp <= hp_max * cfg.phase2_at) {
        phase = 2;
        hitbox_clear(id);
        vx = 0;
        vy = 0;
        cam_shake(6);
        toast_show("FASE 2 - o chefe ficou mais rapido!");
        actor_set_state(BS.PHASE);
        return HITRES.HIT;
    }

    // so reage a golpes fora de avisos e ataques
    if (state == BS.IDLE || state == BS.RECOVER || state == BS.HURT) {
        hurt_chain++;
        vx = _hit.dir * _hit.atk.knock_x * 0.5;
        actor_set_state(BS.HURT);
    }
    return HITRES.HIT;
}

function boss_animate() {
    var _s = cfg.sprites;
    switch (state) {
        case BS.INTRO:
        case BS.RECOVER:
            actor_anim(_s.idle, (anim_clock div 20) mod 2);
            break;
        case BS.IDLE:
            if (abs(vx) > 0.1 || abs(vy) > 0.1) actor_anim(_s.walk, (anim_clock div 7) mod 6);
            else actor_anim(_s.idle, (anim_clock div 20) mod 2);
            break;
        case BS.TELEGRAPH: actor_anim(_s.telegraph, 0); break;
        case BS.SWIPE:     actor_anim(_s.attack, attack_anim_frame(atk, state_timer)); break;
        case BS.DASH:      actor_anim(_s.dash, 0); break;
        case BS.JUMP:      actor_anim(_s.jump, 0); break;
        case BS.SLAM:      actor_anim(_s.land, 0); break;
        case BS.HURT:      actor_anim(_s.hurt, 0); break;
        case BS.PHASE:     actor_anim(((state_timer div 6) mod 2 == 0) ? _s.telegraph : _s.jump, 0); break;
        case BS.DEAD:      actor_anim(actor_on_ground() ? _s.dead : _s.hurt, 0); break;
    }
}

function boss_draw() {
    var _warn = make_colour_rgb(255, 60, 90);
    var _gold = make_colour_rgb(255, 210, 63);
    var _blink = ((state_timer div 4) mod 2 == 0);

    // aviso do dash: faixa no chao ate a borda da arena (contorno + preenchimento)
    if (state == BS.TELEGRAPH && pattern == "dash") {
        var _lane = attack_get(cfg.dash.attack).lane;
        var _ex = (dash_dir > 0) ? stage_x2() : stage_x1();
        draw_set_colour(_warn);
        draw_set_alpha(_blink ? 0.35 : 0.18);
        draw_rectangle(min(x, _ex), y - _lane, max(x, _ex), y + _lane, false);
        draw_set_alpha(1);
        draw_rectangle(min(x, _ex), y - _lane, max(x, _ex), y + _lane, true);
    }

    // aviso do slam: circulo no ponto de queda, enchendo ate o impacto
    if (state == BS.JUMP) {
        var _a = attack_get(cfg.slam.attack);
        var _k = clamp(state_timer / air_frames, 0, 1);
        draw_set_colour(_warn);
        draw_set_alpha(0.3);
        draw_ellipse(target_x - _a.reach * _k, target_y - _a.lane * _k, target_x + _a.reach * _k, target_y + _a.lane * _k, false);
        draw_set_alpha(1);
        draw_ellipse(target_x - _a.reach, target_y - _a.lane, target_x + _a.reach, target_y + _a.lane, true);
    }

    // transicao de fase: aneis pulsando
    if (state == BS.PHASE) {
        var _r = 20 + (state_timer mod 30);
        draw_set_colour(_gold);
        draw_ellipse(x - _r * 1.6, y - _r * 0.5, x + _r * 1.6, y + _r * 0.5, true);
    }

    draw_set_alpha(1);
    draw_set_colour(c_white);

    // derrotado: pisca no fim antes de sumir
    if (state == BS.DEAD && state_timer > cfg.dead_frames - 50 && _blink) return;

    // aura no chao: destaca o chefe sem ampliar o sprite (escala quebrada deforma os pixels)
    if (state != BS.DEAD && z <= 0) {
        var _pulse = 2 * sin(anim_clock / 14);
        draw_set_colour((phase == 2) ? _warn : make_colour_rgb(255, 60, 170));
        draw_set_alpha(0.5);
        draw_ellipse(x - 20 - _pulse, y - 6, x + 20 + _pulse, y + 6, true);
        draw_ellipse(x - 16 - _pulse, y - 4, x + 16 + _pulse, y + 4, true);
        draw_set_alpha(1);
        draw_set_colour(c_white);
    }
    actor_draw();

    // "!" acima da cabeca durante avisos parados
    if (state == BS.TELEGRAPH) {
        var _yy = y - z - body_h - 22 - (_blink ? 1 : 0);
        draw_set_colour(_gold);
        draw_rectangle(x - 2, _yy, x + 2, _yy + 9, false);
        draw_rectangle(x - 2, _yy + 12, x + 2, _yy + 15, false);
        draw_set_colour(c_white);
    }
}

/// Chefe vivo na sala, ou noone.
function boss_find() {
    var _b = noone;
    with (obj_enemy) {
        if (cfg.ai == "boss" && hp > 0) _b = id;
    }
    return _b;
}
