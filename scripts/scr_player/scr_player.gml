/// Maquina de estados do jogador. Vida e especial ficam em global.run.

enum PS {
    IDLE,
    WALK,
    JUMP_START,
    AIR,
    AIR_ATTACK,
    LAND,
    ATTACK,
    SPECIAL,
    DODGE,
    BLOCK,
    HURT,
    KNOCKDOWN,
    GETUP,
    DEAD,
    GRAB,
    THROW,
    CLIMB,   // na escada entre duas faixas do mapa 2D (scr_level)
    COUNT
}

/// Tabela explicita do que cada estado permite.
///  can_move      anda livremente no chao
///  can_act       pode iniciar ataque, pulo, esquiva, bloqueio, especial e interagir
///  invulnerable  ignora dano durante todo o estado
/// (Esquiva e especial tem janelas de invulnerabilidade proprias, na config.)
function player_states_init() {
    var _t = array_create(PS.COUNT);
    _t[PS.IDLE]       = player_state_def("Idle",       true,  true,  false);
    _t[PS.WALK]       = player_state_def("Walk",       true,  true,  false);
    _t[PS.JUMP_START] = player_state_def("JumpStart",  false, false, false);
    _t[PS.AIR]        = player_state_def("Airborne",   false, false, false);
    _t[PS.AIR_ATTACK] = player_state_def("AirAttack",  false, false, false);
    _t[PS.LAND]       = player_state_def("Landing",    false, false, false);
    _t[PS.ATTACK]     = player_state_def("Attack",     false, false, false);
    _t[PS.SPECIAL]    = player_state_def("Special",    false, false, false);
    _t[PS.DODGE]      = player_state_def("Dodge",      false, false, false);
    _t[PS.BLOCK]      = player_state_def("Block",      false, false, false);
    _t[PS.HURT]       = player_state_def("Hurt",       false, false, false);
    _t[PS.KNOCKDOWN]  = player_state_def("KnockedDown", false, false, true);
    _t[PS.GETUP]      = player_state_def("GettingUp",  false, false, true);
    _t[PS.DEAD]       = player_state_def("Dead",       false, false, true);
    _t[PS.GRAB]       = player_state_def("Grab",       false, false, false);
    _t[PS.THROW]      = player_state_def("Throw",      false, false, false);
    _t[PS.CLIMB]      = player_state_def("Climb",      false, false, true);
    global.player_states = _t;
}

function player_state_def(_name, _can_move, _can_act, _invulnerable) {
    return { name: _name, can_move: _can_move, can_act: _can_act, invulnerable: _invulnerable };
}

function player_create() {
    var _P = CFG.player;
    actor_init(_P.hp_max, _P.body_w, _P.body_h);
    team = TEAM.PLAYER;
    state = PS.IDLE;
    pchar = player_char(); // personagem em uso: golpes e sprites (scr_meta)
    sprite_index = pchar.sprites.idle;
    counter_ready = false; // proximo golpe reforcado apos uma esquiva perfeita

    combo_index = 0;
    atk = undefined;
    atk_spawned = false;
    atk_connected = false;
    atk_weapon = false;
    buf_attack = 0;
    buf_jump = 0;
    buf_dodge = 0;
    buf_special = 0;
    buf_grab = 0;
    grab_target = noone;
    knee_count = 0;
    knee_timer = 0;
    dodge_cd = 0;
    dodge_dx = 1;
    dodge_dy = 0;
    down_timer = 0;
    anim_clock = 0;
    climb_link = -1;      // escada em uso (indice em map.links)
    climb_t = 0;          // 0 no pe, 1 no topo
    climb_moving = false;
    stairs_hold = 0;      // frames segurando cima/baixo junto a uma escada

    on_hit = function(_hit) { return player_on_hit(_hit); };
    on_hit_landed = function(_hit) { player_on_hit_landed(_hit); };
}

/// Inimigos so iniciam ataques contra um jogador de pe.
function player_is_targetable(_p) {
    return _p.state != PS.KNOCKDOWN && _p.state != PS.GETUP && _p.state != PS.DEAD;
}

function player_step() {
    var _P = CFG.player;

    // Comandos sao guardados por alguns frames, inclusive durante o congelamento de impacto.
    if (input_pressed(ACT.ATTACK)) buf_attack = _P.buffer_frames;
    if (input_pressed(ACT.JUMP)) buf_jump = _P.buffer_frames;
    if (input_pressed(ACT.DODGE)) buf_dodge = _P.buffer_frames;
    if (input_pressed(ACT.SPECIAL)) buf_special = _P.buffer_frames;
    if (input_pressed(ACT.GRAB)) buf_grab = _P.buffer_frames;

    if (game_frozen()) return;

    state_timer++;
    anim_clock++;
    if (invuln > 0) invuln--;
    if (flash > 0) flash--;
    if (dodge_cd > 0) dodge_cd--;

    var _info = global.player_states[state];
    var _ax = input_axis_x();
    var _ay = input_axis_y();
    var _spd = global.run.stats.speed_mult;
    var _controls = (global.flow.state == FLOW.PLAY);

    if (_info.can_move) {
        // IDLE / WALK
        if (!_controls) {
            _ax = 0;
            _ay = 0;
        }
        vx = _ax * _P.speed_x * _spd;
        vy = _ay * _P.speed_y * _spd;
        if (_ax != 0) facing = sign(_ax);
        var _want = (_ax != 0 || _ay != 0) ? PS.WALK : PS.IDLE;
        if (state != _want) actor_set_state(_want);
        if (_controls && _info.can_act && !player_stairs_try(_ay)) player_try_actions();
    } else {
        switch (state) {
            case PS.CLIMB:
                player_climb_step(_controls ? _ay : 0, _spd);
                break;

            case PS.JUMP_START:
                if (state_timer >= _P.jump_start_frames) {
                    vz = _P.jump_speed;
                    actor_set_state(PS.AIR);
                }
                break;

            case PS.AIR:
                vx = _ax * _P.speed_x * _spd;
                vy = _ay * _P.speed_y * _P.air_depth_mult * _spd;
                if (_ax != 0) facing = sign(_ax);
                if (buf_attack > 0) {
                    buf_attack = 0;
                    atk = attack_get(pchar.air_attack);
                    atk_spawned = false;
                    atk_connected = false;
                    actor_set_state(PS.AIR_ATTACK);
                }
                break;

            case PS.AIR_ATTACK:
                if (!atk_spawned && state_timer > atk.startup) {
                    hitbox_spawn(id, atk, player_damage_mult());
                    atk_spawned = true;
                }
                break;

            case PS.LAND:
                vx = 0;
                vy = 0;
                if (state_timer >= _P.land_frames) actor_set_state(PS.IDLE);
                break;

            case PS.ATTACK:
            case PS.SPECIAL:
                player_attack_update(_ax);
                break;

            case PS.DODGE:
                var _k = 1 - state_timer / _P.dodge.frames; // desacelera no fim
                vx = dodge_dx * _P.dodge.speed * (0.4 + 0.6 * _k);
                vy = dodge_dy * _P.dodge.speed * 0.6 * (0.4 + 0.6 * _k);
                if (state_timer mod 3 == 0) fx_ghost(id, make_colour_rgb(45, 226, 230)); // rastro
                if (state_timer >= _P.dodge.frames) {
                    hitbox_clear(id); // fim da ombrada, se houver
                    dodge_cd = _P.dodge.cooldown;
                    vx = 0;
                    vy = 0;
                    actor_set_state(PS.IDLE);
                }
                break;

            case PS.BLOCK:
                vx *= CFG.physics.knock_friction;
                vy = 0;
                if (buf_dodge > 0 && dodge_cd <= 0) {
                    player_start_dodge();
                } else if (!input_held(ACT.BLOCK) && state_timer >= _P.block.min_frames) {
                    vx = 0;
                    actor_set_state(PS.IDLE);
                }
                break;

            case PS.HURT:
                vx *= CFG.physics.knock_friction;
                vy = 0;
                if (state_timer >= _P.hurt_frames) {
                    vx = 0;
                    actor_set_state(PS.IDLE);
                }
                break;

            case PS.KNOCKDOWN:
                vy = 0;
                if (actor_on_ground()) {
                    vx *= CFG.physics.knock_friction;
                    down_timer++;
                    if (down_timer == 1) {
                        fx_dust(x, y, 8);
                        hazard_knockdown_landed(id); // claraboia dos telhados
                    }
                    if (global.run.hp <= 0) {
                        vx = 0;
                        actor_set_state(PS.DEAD);
                        game_player_died();
                    } else if (down_timer >= _P.knockdown_frames) {
                        vx = 0;
                        actor_set_state(PS.GETUP);
                    }
                }
                break;

            case PS.GETUP:
                vx = 0;
                vy = 0;
                if (state_timer >= _P.getup_frames) {
                    invuln = _P.invuln_frames;
                    actor_set_state(PS.IDLE);
                }
                break;

            case PS.GRAB:
                player_grab_update(_ax);
                break;

            case PS.THROW:
                vx = 0;
                vy = 0;
                if (state_timer >= _P.grab.throw_frames) actor_set_state(PS.IDLE);
                break;

            case PS.DEAD:
                vx = 0;
                vy = 0;
                break;
        }
    }

    // na escada a posicao vem do segmento da escada, fora dos limites da faixa
    var _landed = (state == PS.CLIMB) ? false : actor_physics();
    if (_landed && (state == PS.AIR || state == PS.AIR_ATTACK)) {
        hitbox_clear(id);
        vx = 0;
        vy = 0;
        fx_dust(x, y, 4);
        actor_set_state(PS.LAND);
    }

    if (buf_attack > 0) buf_attack--;
    if (buf_jump > 0) buf_jump--;
    if (buf_dodge > 0) buf_dodge--;
    if (buf_special > 0) buf_special--;
    if (buf_grab > 0) buf_grab--;

    player_animate();
}

/// Tenta iniciar uma acao a partir de um estado neutro. Retorna true se mudou de estado.
function player_try_actions() {
    var _sp = CFG.player.special;
    if (buf_special > 0 && global.run.special >= _sp.cost) {
        buf_special = 0;
        global.run.special -= _sp.cost;
        atk = attack_get(pchar.special);
        atk_spawned = false;
        atk_connected = false;
        vx = 0;
        vy = 0;
        actor_set_state(PS.SPECIAL);
        return true;
    }
    if (buf_dodge > 0 && dodge_cd <= 0) {
        player_start_dodge();
        return true;
    }
    if (buf_grab > 0) {
        buf_grab = 0;
        var _target = player_find_grab_target();
        if (_target != noone) {
            player_start_grab(_target);
            return true;
        }
    }
    if (buf_attack > 0) {
        player_start_attack(0);
        return true;
    }
    if (buf_jump > 0) {
        buf_jump = 0;
        actor_set_state(PS.JUMP_START);
        return true;
    }
    if (input_held(ACT.BLOCK) && !challenge_blocks_guard()) {
        vx = 0;
        vy = 0;
        actor_set_state(PS.BLOCK);
        return true;
    }
    return false;
}

/// Multiplicador de dano do proximo golpe. Gasta o bonus do contra-golpe.
function player_damage_mult() {
    var _m = global.run.stats.damage_mult;
    if (counter_ready) {
        counter_ready = false;
        _m *= 1 + global.run.stats.counter_mult;
    }
    return _m;
}

function player_start_attack(_index) {
    buf_attack = 0;
    combo_index = _index;
    atk = attack_get(pchar.combo[_index]);
    atk_weapon = false;
    var _wp = global.run.weapon;
    if (_index == 0 && !is_undefined(_wp)) {
        // WeaponAttack: golpe unico da arma no lugar do combo
        atk = attack_get(weapon_def(_wp.wid).attack);
        atk_weapon = true;
        combo_index = array_length(pchar.combo) - 1; // nao encadeia
    }
    atk_spawned = false;
    atk_connected = false;
    var _ax = input_axis_x();
    if (_ax != 0) facing = sign(_ax);
    vy = 0;
    actor_set_state(PS.ATTACK);
}

function player_start_dodge() {
    buf_dodge = 0;
    hitbox_clear(id);
    var _ax = input_axis_x();
    var _ay = input_axis_y();
    if (_ax == 0 && _ay == 0) _ax = facing; // sem direcao: esquiva para frente
    dodge_dx = _ax;
    dodge_dy = _ay;
    if (_ax != 0) facing = sign(_ax);
    actor_set_state(PS.DODGE);
    // Ombrada: com o modificador, a esquiva carrega uma hitbox
    if (global.run.stats.dodge_damage > 0) {
        hitbox_spawn(id, attack_get(pchar.dodge_attack), global.run.stats.dodge_damage * global.run.stats.damage_mult);
    }
}

/// Ataque de chao e especial: preparacao -> hitbox ativa -> recuperacao.
function player_attack_update(_ax) {
    var _P = CFG.player;
    var _active_end = atk.startup + atk.active;
    var _total = _active_end + atk.recovery;

    vy = 0;
    // avanco na preparacao (lunge) e, em investidas, durante a hitbox ativa (rush)
    if (state_timer <= atk.startup) vx = facing * atk.lunge;
    else if (state_timer <= _active_end) vx = facing * atk.rush;
    else vx = 0;
    if (atk.rush > 0 && state_timer > atk.startup && state_timer <= _active_end && state_timer mod 2 == 0) {
        fx_ghost(id, make_colour_rgb(255, 60, 170));
    }

    if (!atk_spawned && state_timer > atk.startup) {
        hitbox_spawn(id, atk, player_damage_mult());
        atk_spawned = true;
    }

    if (state == PS.ATTACK && state_timer > _active_end) {
        // esquiva cancela a recuperacao
        if (_P.dodge_cancels_recovery && buf_dodge > 0 && dodge_cd <= 0) {
            player_start_dodge();
            return;
        }
        // proximo golpe do combo
        var _can_chain = combo_index < array_length(pchar.combo) - 1
            && state_timer >= _active_end + atk.cancel_after
            && (!_P.combo_requires_hit || atk_connected);
        if (_can_chain && buf_attack > 0) {
            player_start_attack(combo_index + 1);
            return;
        }
    }

    if (state_timer >= _total) {
        combo_index = 0;
        vx = 0;
        actor_set_state(PS.IDLE);
    }
}

function player_on_hit(_hit) {
    var _P = CFG.player;
    var _run = global.run;

    if (global.flow.state == FLOW.VICTORY) return HITRES.IGNORED; // a luta acabou
    if (global.player_states[state].invulnerable || invuln > 0) return HITRES.IGNORED;
    if (state == PS.DODGE && state_timer >= _P.dodge.iframe_start && state_timer <= _P.dodge.iframe_end) {
        // esquiva perfeita: cada golpe so chega aqui uma vez
        if (_run.stats.dodge_special > 0) {
            _run.special = min(_P.special.meter_max, _run.special + _run.stats.dodge_special);
            fx_number(x, y - z - body_h - 8, "ESQUIVA!", make_colour_rgb(45, 226, 230));
        }
        if (_run.stats.counter_mult > 0) counter_ready = true;
        return HITRES.IGNORED;
    }
    if (state == PS.SPECIAL && _P.special.invulnerable) return HITRES.IGNORED;

    // Bloqueio: reduz o dano de golpes vindos da frente; nao protege as costas.
    if (state == PS.BLOCK && !_hit.atk.unblockable) {
        var _from_front = (_hit.dir != facing);
        if (_from_front || !_P.block.front_only) {
            var _chip = min(_run.hp - 1, _hit.damage * _run.stats.damage_taken_mult * _P.block.damage_mult); // bloqueio nunca mata
            _run.hp -= _chip;
            _run.dmg_taken += _chip;
            vx = _hit.dir * _P.block.pushback;
            // Muralha: devolve dano a quem bateu (golpes a distancia nao tem dono)
            if (_run.stats.block_reflect > 0 && instance_exists(_hit.attacker) && _hit.attacker.team != team) {
                combat_deliver(_hit.attacker, {
                    atk: attack_get("reflect"),
                    damage: _run.stats.block_reflect,
                    dir: -_hit.dir,
                    attacker: id
                }, id);
            }
            return HITRES.BLOCKED;
        }
    }

    var _dmg = min(_run.hp, _hit.damage * _run.stats.damage_taken_mult);
    _run.hp -= _dmg;
    _run.dmg_taken += _dmg;
    _run.hits_taken += 1;
    _run.special = min(_P.special.meter_max, _run.special + _P.special.gain_on_hurt * _run.stats.special_gain_mult);
    hitbox_clear(id);
    player_release_grab(); // apanhar solta o inimigo segurado
    flash = CFG.feedback.flash_frames;
    combo_index = 0;
    vy = 0;

    if (_run.hp <= 0 || _hit.atk.knockdown) {
        vx = _hit.dir * max(_hit.atk.knock_x, 1.5);
        vz = max(_hit.atk.knock_z, CFG.physics.min_launch);
        down_timer = 0;
        if (CFG.weapon_rules.drop_on_knockdown) weapon_drop(x, y);
        actor_set_state(PS.KNOCKDOWN);
    } else {
        vx = _hit.dir * _hit.atk.knock_x;
        if (z > 0) {
            // atingido no ar: cai derrubado para nao ficar em estado sem chao
            vz = max(vz, 1.5);
            down_timer = 0;
            actor_set_state(PS.KNOCKDOWN);
        } else {
            invuln = _P.hurt_frames + _P.invuln_frames;
            actor_set_state(PS.HURT);
        }
    }
    return HITRES.HIT;
}

function player_on_hit_landed(_hit) {
    atk_connected = true;
    if (state == PS.ATTACK && atk_weapon) weapon_use();
    if (state != PS.SPECIAL) {
        var _sp = CFG.player.special;
        global.run.special = min(_sp.meter_max, global.run.special + _sp.gain_on_hit * global.run.stats.special_gain_mult);
    }
}

/// Fase do golpe para sprites de 3 frames: 0 preparacao, 1 ativo, 2 recuperacao.
function attack_anim_frame(_atk, _timer) {
    if (_timer <= _atk.startup) return 0;
    if (_timer <= _atk.startup + _atk.active) return 1;
    return 2;
}

function player_animate() {
    var _S = pchar.sprites;
    switch (state) {
        case PS.IDLE:       actor_anim(_S.idle, (anim_clock div 10) mod 4); break;
        case PS.WALK:       actor_anim(_S.walk, (anim_clock div 6) mod 6); break;
        case PS.JUMP_START: actor_anim(_S.land, 0); break;
        case PS.AIR:        actor_anim(vz > 0 ? _S.jump : _S.fall, 0); break;
        case PS.AIR_ATTACK: actor_anim(atk.sprite, 0); break;
        case PS.LAND:       actor_anim(_S.land, 0); break;
        case PS.ATTACK:     actor_anim(atk.sprite, attack_anim_frame(atk, state_timer)); break;
        case PS.SPECIAL:    actor_anim(atk.sprite, (state_timer div 3) mod sprite_get_number(atk.sprite)); break;
        case PS.DODGE:      actor_anim(_S.dodge, 0); break;
        case PS.BLOCK:      actor_anim(_S.block, 0); break;
        case PS.HURT:       actor_anim(_S.hurt, 0); break;
        case PS.KNOCKDOWN:  actor_anim(actor_on_ground() ? _S.knockdown : _S.hurt, 0); break;
        case PS.GETUP:      actor_anim(_S.getup, 0); break;
        case PS.DEAD:       actor_anim(_S.dead, 0); break;
        // segurando: bracos estendidos; joelhada reaproveita a preparacao do chute
        case PS.GRAB:
            if (knee_timer > 0) actor_anim(_S.knee, 0);
            else actor_anim(_S.grab, 0);
            break;
        // arremesso: os quadros do sprite tocam ao longo do estado
        case PS.THROW:
            var _n = sprite_get_number(_S.throw_spr);
            actor_anim(_S.throw_spr, min(_n - 1, (state_timer * _n) div CFG.player.grab.throw_frames));
            break;
        // escada: os degraus sao uma diagonal, entao o andar serve
        case PS.CLIMB:
            if (climb_moving) actor_anim(_S.walk, (anim_clock div 6) mod 6);
            else actor_anim(_S.idle, 0);
            break;
    }
}

// ------------------------------------------------------------------ escadas

/// Escadas dos mapas 2D. No pe (encostado na parede do fundo), segurar para
/// cima sobe; no topo (na beirada da frente do chao de cima), segurar para baixo
/// desce. Interagir tambem usa a escada. Trancada durante uma horda.
/// Retorna true se o jogador entrou na escada neste frame.
function player_stairs_try(_ay) {
    var _map = level_current_map();
    if (is_undefined(_map) || z > 0) {
        stairs_hold = 0;
        return false;
    }
    var _near = level_stairs_near(_map, global.stage_rt.corridor, x, y);
    if (is_undefined(_near)) {
        stairs_hold = 0;
        return false;
    }
    if (!stage_exits_open()) {
        global.prompt = "TRANCADA - derrote os inimigos";
        stairs_hold = 0;
        return false;
    }
    var _toward = _near.top ? 1 : -1; // eixo y que empurra para dentro da escada
    global.prompt = _near.top
        ? "[" + input_action_label(ACT.DOWN) + "] DESCER"
        : "[" + input_action_label(ACT.UP) + "] SUBIR";
    stairs_hold = (_ay == _toward) ? stairs_hold + 1 : 0;
    if (stairs_hold < CFG.level.stair_hold && !input_pressed(ACT.INTERACT)) return false;

    stairs_hold = 0;
    climb_link = _near.link;
    climb_t = _near.top ? 1 : 0;
    climb_moving = false;
    vx = 0;
    vy = 0;
    actor_set_state(PS.CLIMB);
    return true;
}

/// Anda pelo segmento da escada (cima = sobe). Ao chegar a uma ponta, volta ao
/// chao no corredor daquela ponta.
function player_climb_step(_ay, _spd) {
    var _map = level_current_map();
    if (is_undefined(_map) || climb_link < 0) {
        actor_set_state(PS.IDLE);
        return;
    }
    var _k = _map.links[climb_link];
    var _len = max(1, point_distance(_k.x_foot, _k.y_foot, _k.x_top, _k.y_top));
    var _dir = -_ay; // cima = +1
    climb_t = clamp(climb_t + _dir * CFG.level.climb_speed * _spd / _len, 0, 1);
    climb_moving = (_dir != 0);
    x = lerp(_k.x_foot, _k.x_top, climb_t);
    y = lerp(_k.y_foot, _k.y_top, climb_t);
    vx = 0;
    vy = 0;
    z = 0;
    vz = 0;
    if (_dir != 0) facing = sign(_k.x_top - _k.x_foot) * _dir;

    if (climb_t >= 1 && _dir > 0) player_stairs_leave(_map, _k, true);
    else if (climb_t <= 0 && _dir < 0) player_stairs_leave(_map, _k, false);
}

/// Sai da escada pelo topo (_top) ou pelo pe, ja dentro do chao daquela faixa.
function player_stairs_leave(_map, _k, _top) {
    var _ch = _map.chunks[_top ? _k.b : _k.a];
    x = _top ? _k.x_top : _k.x_foot;
    y = _top ? _ch.floor_bottom - 2 : _ch.floor_top + 2;
    stage_set_corridor(_ch.corridor);
    level_discover(_map, _ch.index);
    climb_link = -1;
    climb_moving = false;
    actor_set_state(PS.IDLE);
}

// ------------------------------------------------------- agarrao e arremesso

/// Inimigo agarravel mais proximo a frente, no chao e na mesma faixa de profundidade.
function player_find_grab_target() {
    var _G = CFG.player.grab;
    var _me = id;
    var _best = noone;
    var _best_d = _G.range + 1;
    with (obj_enemy) {
        if (!cfg.grabbable || hp <= 0 || z > 0) continue;
        if (state == ES.KNOCKDOWN || state == ES.GETUP || state == ES.DEAD || state == ES.GRABBED || state == ES.THROWN) continue;
        var _d = (x - _me.x) * _me.facing;
        if (_d < 0 || _d > _G.range || abs(y - _me.y) > _G.lane) continue;
        if (_d < _best_d) {
            _best_d = _d;
            _best = id;
        }
    }
    return _best;
}

function player_start_grab(_target) {
    grab_target = _target;
    knee_count = 0;
    knee_timer = 0;
    vx = 0;
    vy = 0;
    with (_target) {
        hitbox_clear(id);
        has_token = false;
        grabber = other.id;
        vx = 0;
        vy = 0;
        actor_set_state(ES.GRABBED);
    }
    actor_set_state(PS.GRAB);
}

/// Segurando: ataque = joelhada (ate knee_max), agarrar de novo = arremesso
/// (na direcao segurada ou para frente). Sem comando, solta apos hold_frames.
function player_grab_update(_ax) {
    var _G = CFG.player.grab;
    vx = 0;
    vy = 0;
    if (!instance_exists(grab_target) || grab_target.state != ES.GRABBED) {
        grab_target = noone;
        actor_set_state(PS.IDLE);
        return;
    }
    if (knee_timer > 0) knee_timer--;

    if (buf_grab > 0) {
        buf_grab = 0;
        var _dir = (_ax != 0) ? sign(_ax) : facing;
        facing = _dir;
        var _thrown = grab_target;
        grab_target = noone;
        with (_thrown) {
            grabber = noone;
            vx = _dir * _G.throw_speed;
            vy = 0;
            vz = _G.throw_launch;
            actor_set_state(ES.THROWN);
        }
        // o corpo arremessado derruba outros inimigos no caminho
        var _hb = instance_create_depth(_thrown.x, _thrown.y, 0, obj_hitbox, {
            owner: _thrown,
            atk: attack_get(_G.throw_attack),
            team: TEAM.PLAYER,
            facing: _dir,
            life: attack_get(_G.throw_attack).active,
            dmg_mult: global.run.stats.damage_mult
        });
        _hb.hit_list = [_thrown]; // nao acerta a si mesmo
        actor_set_state(PS.THROW);
        return;
    }

    if (buf_attack > 0 && knee_timer <= 0 && knee_count < _G.knee_max) {
        buf_attack = 0;
        knee_count++;
        knee_timer = _G.knee_frames;
        combat_direct_hit(id, grab_target, attack_get(_G.knee_attack), global.run.stats.damage_mult);
        return;
    }

    if (state_timer >= _G.hold_frames) {
        player_release_grab();
        actor_set_state(PS.IDLE);
    }
}

/// Solta o inimigo segurado, se houver (tempo esgotado ou jogador atingido).
function player_release_grab() {
    if (grab_target == noone) return;
    var _dir = facing;
    if (instance_exists(grab_target)) {
        with (grab_target) {
            if (state == ES.GRABBED) {
                grabber = noone;
                vx = _dir * 1.5;
                think_timer = max(think_timer, 30);
                actor_set_state(ES.HURT);
            }
        }
    }
    grab_target = noone;
}
