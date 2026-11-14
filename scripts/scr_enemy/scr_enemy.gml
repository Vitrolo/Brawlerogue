/// IA dos inimigos comuns. O comportamento e fixo por tipo; os numeros vem de
/// CFG.enemies[tipo]. Um inimigo so ataca com uma "ficha" de ataque: no maximo
/// CFG.horde.max_attackers inimigos tem ficha ao mesmo tempo, os outros esperam
/// a distancia.

enum ES {
    SPAWN,
    MOVE,       // aproxima (com ficha) ou cerca a distancia (sem ficha)
    TELEGRAPH,  // aviso visivel antes do golpe
    ATTACK,
    RECOVER,
    HURT,
    KNOCKDOWN,
    GETUP,
    DEAD,
    GRABBED,    // segurado pelo jogador
    THROWN      // arremessado, no ar
}

function enemy_create() {
    if (!variable_instance_exists(id, "enemy_type")) enemy_type = "thug";
    cfg = CFG.enemies[$ enemy_type];
    actor_init(cfg.hp_max, cfg.body_w, cfg.body_h);
    team = TEAM.ENEMY;
    state = ES.SPAWN;
    sprite_index = cfg.sprites.idle;

    atk = undefined;
    atk_spawned = false;
    has_token = false;
    token_timer = 0;
    think_timer = irandom_range(cfg.think_min, cfg.think_max);
    side = 1;
    lane_offset = irandom_range(-22, 22);
    down_timer = 0;
    grabber = noone;
    draw_scale = cfg.scale;
    anim_clock = irandom(30);

    on_hit = function(_hit) { return (cfg.ai == "boss") ? boss_on_hit(_hit) : enemy_on_hit(_hit); };
    if (cfg.ai == "boss") boss_create();
}

function enemy_tokens_in_use() {
    var _n = 0;
    with (obj_enemy) {
        if (has_token) _n++;
    }
    return _n;
}

function enemy_on_screen() {
    return x > global.cam.x + 8 && x < global.cam.x + VIEW_W - 8;
}

function enemy_move_towards(_tx, _ty) {
    var _dx = _tx - x;
    var _dy = _ty - y;
    vx = (abs(_dx) > 0.5) ? sign(_dx) * min(abs(_dx), cfg.speed_x) : 0;
    vy = (abs(_dy) > 0.5) ? sign(_dy) * min(abs(_dy), cfg.speed_y) : 0;
}

/// Empurra levemente para longe de inimigos sobrepostos.
function enemy_separate() {
    var _me = id;
    var _px = 0;
    var _py = 0;
    with (obj_enemy) {
        if (id == _me || hp <= 0) continue;
        if (abs(x - _me.x) < 16 && abs(y - _me.y) < 8) {
            _px += (_me.x >= x) ? 0.3 : -0.3;
            _py += (_me.y >= y) ? 0.2 : -0.2;
        }
    }
    vx += _px;
    vy += _py;
}

function enemy_step() {
    if (cfg.ai == "boss") {
        boss_step();
        return;
    }
    if (game_frozen()) return;

    state_timer++;
    anim_clock++;
    if (flash > 0) flash--;

    var _p = instance_find(obj_player, 0);
    var _p_ok = (_p != noone) && player_is_targetable(_p);

    switch (state) {
        case ES.SPAWN:
            vx = 0;
            vy = 0;
            if (state_timer >= cfg.spawn_frames) actor_set_state(ES.MOVE);
            break;

        case ES.MOVE:
            if (_p == noone) {
                vx = 0;
                vy = 0;
                break;
            }
            facing = (_p.x >= x) ? 1 : -1;
            if (abs(_p.x - x) > 4) side = (x >= _p.x) ? 1 : -1; // fica do lado em que ja esta

            if (think_timer > 0) think_timer--;
            if (!_p_ok) has_token = false;
            if (!has_token && _p_ok && think_timer <= 0 && enemy_tokens_in_use() < CFG.horde.max_attackers) {
                has_token = true;
                token_timer = 0;
            }

            var _tx, _ty;
            if (has_token) {
                token_timer++;
                _tx = _p.x + side * cfg.attack_range;
                _ty = _p.y;
                if (token_timer > CFG.horde.token_timeout) {
                    has_token = false;
                    think_timer = cfg.think_min;
                }
            } else {
                _tx = _p.x + side * cfg.circle_dist;
                _ty = _p.y + lane_offset;
            }
            _tx = clamp(_tx, stage_x1() + body_w, stage_x2() - body_w);
            _ty = clamp(_ty, global.stage.floor_top, global.stage.floor_bottom);
            enemy_move_towards(_tx, _ty);

            // so ataca em posicao, na mesma faixa de profundidade e dentro da tela
            if (has_token && abs(x - _tx) <= 3 && abs(y - _p.y) <= cfg.lane_ok && enemy_on_screen()) {
                vx = 0;
                vy = 0;
                actor_set_state(ES.TELEGRAPH);
            } else {
                enemy_separate();
            }
            break;

        case ES.TELEGRAPH:
            vx = 0;
            vy = 0;
            if (state_timer >= cfg.telegraph_frames) {
                atk = attack_get(cfg.attack);
                atk_spawned = false;
                actor_set_state(ES.ATTACK);
            }
            break;

        case ES.ATTACK:
            vy = 0;
            vx = (state_timer <= atk.startup) ? facing * atk.lunge : 0;
            if (!atk_spawned && state_timer > atk.startup) {
                hitbox_spawn(id, atk);
                atk_spawned = true;
            }
            if (state_timer >= atk.startup + atk.active + atk.recovery) {
                has_token = false;
                actor_set_state(ES.RECOVER);
            }
            break;

        case ES.RECOVER:
            vx = 0;
            vy = 0;
            if (state_timer >= cfg.recover_frames) {
                think_timer = irandom_range(cfg.think_min, cfg.think_max);
                actor_set_state(ES.MOVE);
            }
            break;

        case ES.HURT:
            vx *= CFG.physics.knock_friction;
            vy = 0;
            if (state_timer >= cfg.hurt_frames) {
                vx = 0;
                think_timer = max(think_timer, 20);
                actor_set_state(ES.MOVE);
            }
            break;

        case ES.KNOCKDOWN:
            vy = 0;
            if (actor_on_ground()) {
                vx *= CFG.physics.knock_friction;
                down_timer++;
                if (hp <= 0) {
                    vx = 0;
                    actor_set_state(ES.DEAD);
                } else if (down_timer >= cfg.knockdown_frames) {
                    vx = 0;
                    actor_set_state(ES.GETUP);
                }
            }
            break;

        case ES.GETUP:
            vx = 0;
            vy = 0;
            if (state_timer >= cfg.getup_frames) {
                think_timer = cfg.think_min;
                actor_set_state(ES.MOVE);
            }
            break;

        case ES.GRABBED:
            vx = 0;
            vy = 0;
            if (!instance_exists(grabber) || grabber.state != PS.GRAB) {
                grabber = noone;
                think_timer = max(think_timer, 30);
                actor_set_state(ES.HURT);
            } else {
                x = grabber.x + grabber.facing * CFG.player.grab.hold_offset;
                y = grabber.y;
                facing = -grabber.facing;
            }
            break;

        case ES.THROWN:
            vy = 0;
            if (actor_on_ground()) {
                // caiu: leva o dano do arremesso e fica derrubado
                hitbox_clear(id);
                var _was_alive = (hp > 0);
                hp = max(0, hp - CFG.player.grab.throw_damage * global.run.stats.damage_mult);
                if (_was_alive && hp <= 0) run_enemy_killed();
                flash = CFG.feedback.flash_frames;
                cam_shake(CFG.feedback.shake_hit);
                down_timer = 0;
                actor_set_state(ES.KNOCKDOWN);
            }
            break;

        case ES.DEAD:
            vx = 0;
            vy = 0;
            if (state_timer >= cfg.dead_frames) instance_destroy();
            break;
    }

    actor_physics();
    enemy_animate();
}

function enemy_on_hit(_hit) {
    // derrubado, levantando ou morto nao recebe dano
    if (state == ES.KNOCKDOWN || state == ES.GETUP || state == ES.DEAD || state == ES.THROWN) return HITRES.IGNORED;

    hp = max(0, hp - _hit.damage);
    if (hp <= 0) run_enemy_killed();
    has_token = false;
    hitbox_clear(id);
    flash = CFG.feedback.flash_frames;
    vy = 0;

    // segurado: leva o dano sem sair da pegada
    if (state == ES.GRABBED && hp > 0) return HITRES.HIT;

    if (hp <= 0 || _hit.atk.knockdown) {
        vx = _hit.dir * max(_hit.atk.knock_x, 1.5);
        vz = max(_hit.atk.knock_z, CFG.physics.min_launch);
        down_timer = 0;
        actor_set_state(ES.KNOCKDOWN);
    } else {
        vx = _hit.dir * _hit.atk.knock_x;
        actor_set_state(ES.HURT);
    }
    return HITRES.HIT;
}

function enemy_animate() {
    var _s = cfg.sprites;
    switch (state) {
        case ES.SPAWN:
        case ES.RECOVER:
            actor_anim(_s.idle, (anim_clock div 24) mod 2);
            break;
        case ES.MOVE:
            if (abs(vx) > 0.1 || abs(vy) > 0.1) actor_anim(_s.walk, (anim_clock div 7) mod 6);
            else actor_anim(_s.idle, (anim_clock div 24) mod 2);
            break;
        case ES.TELEGRAPH: actor_anim(_s.telegraph, 0); break;
        case ES.ATTACK:    actor_anim(_s.attack, attack_anim_frame(atk, state_timer)); break;
        case ES.HURT:      actor_anim(_s.hurt, 0); break;
        case ES.KNOCKDOWN: actor_anim(actor_on_ground() ? _s.knockdown : _s.hurt, 0); break;
        case ES.GETUP:     actor_anim(_s.getup, 0); break;
        case ES.DEAD:      actor_anim(_s.dead, 0); break;
        case ES.GRABBED:
        case ES.THROWN:
            actor_anim(_s.hurt, 0);
            break;
    }
}

function enemy_draw() {
    if (cfg.ai == "boss") {
        boss_draw();
        return;
    }
    // morto pisca antes de sumir
    if (state == ES.DEAD && (state_timer div 4) mod 2 == 1) return;
    // recem-chegado pisca enquanto ainda nao age
    if (state == ES.SPAWN && (state_timer div 3) mod 2 == 1) return;
    actor_draw();
    // aviso de ataque: "!" acima da cabeca (forma + cor)
    if (state == ES.TELEGRAPH) {
        var _yy = y - z - body_h - 16 - ((state_timer div 4) mod 2);
        draw_set_colour(make_colour_rgb(255, 210, 63));
        draw_rectangle(x - 1, _yy, x + 1, _yy + 7, false);
        draw_rectangle(x - 1, _yy + 10, x + 1, _yy + 12, false);
        draw_set_colour(c_white);
    }
}
