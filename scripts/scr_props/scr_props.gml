/// Objetos de cenario (obj_prop) e projeteis (obj_projectile).
///
/// obj_prop.kind:
///  quebraveis  "barrel" | "crate" | "bin"
///     - golpe comum: racha; no segundo, quebra e solta moedas, comida ou um cano
///     - golpe que derruba (chute, especial, taco): o objeto sai deslizando e
///       derruba os inimigos no caminho antes de quebrar
///  perigos     "toxic"    (esgoto)   poca que fere quem pisa, inclusive inimigos
///              "car"      (ruas)     carro que cruza a rua depois de um aviso
///              "skylight" (telhados) claraboia: quem cai DERRUBADO em cima atravessa
///                                    o vidro (inimigo e eliminado, jogador perde vida)
///
/// Os objetos de cada corredor sao sorteados em run_maps_build (scr_route) e
/// guardados em map.props; um quebravel destruido nao volta.
/// Quebraveis e carro usam sprites (spr_prop_*). PLACEHOLDER: poca, claraboia e
/// o tiro ainda sao desenhados com formas simples.

function prop_is_breakable(_kind) {
    return _kind == "barrel" || _kind == "crate" || _kind == "bin";
}

/// Sorteia os objetos de um trecho de combate. Retorna a lista de { kind, x, y, alive }.
/// _avoid_x: posicoes das entradas especiais; um objeto sorteado na frente de uma
/// delas e empurrado para a parte de baixo do chao, sem bloquear a porta.
function props_roll_section(_biome, _x1, _x2, _avoid_x = []) {
    var _P = CFG.props;
    var _out = [];
    var _ft = 178;
    var _fb = 258;

    var _kinds = ["barrel", "crate"];
    if (_biome == "streets") _kinds = ["bin", "crate"];
    if (_biome == "rooftops") _kinds = ["crate", "barrel"];
    var _n = irandom_range(_P.breakables_per_section[0], _P.breakables_per_section[1]);
    for (var _i = 0; _i < _n; _i++) {
        array_push(_out, {
            kind: _kinds[irandom(array_length(_kinds) - 1)],
            x: irandom_range(_x1 + 70, _x2 - 50),
            y: irandom_range(_ft + 6, _fb - 6),
            alive: true
        });
        props_clear_entrances(_out[array_length(_out) - 1], _avoid_x, _ft, _fb - 6);
    }

    if (random(1) < _P.hazard_chance) {
        var _hk = "toxic";
        if (_biome == "streets") _hk = "car";
        if (_biome == "rooftops") _hk = "skylight";
        array_push(_out, {
            kind: _hk,
            x: irandom_range(_x1 + 180, _x2 - 120),
            y: irandom_range(_ft + 24, _fb - 20),
            alive: true
        });
        props_clear_entrances(_out[array_length(_out) - 1], _avoid_x, _ft, _fb - 20);
    }
    return _out;
}

/// Afasta um objeto da frente de uma entrada (so mexe na profundidade).
function props_clear_entrances(_prop, _avoid_x, _floor_top, _y_max) {
    var _P = CFG.props;
    for (var _i = 0; _i < array_length(_avoid_x); _i++) {
        if (abs(_prop.x - _avoid_x[_i]) < _P.entrance_clear_x) {
            _prop.y = max(_prop.y, min(_y_max, _floor_top + _P.entrance_clear_depth));
            return;
        }
    }
}

// ------------------------------------------------------------------ obj_prop

function prop_create() {
    if (!variable_instance_exists(id, "kind")) kind = "crate";
    if (!variable_instance_exists(id, "map_index")) map_index = -1;
    if (!variable_instance_exists(id, "prop_index")) prop_index = -1;
    breakable = prop_is_breakable(kind);
    z = 0;
    body_w = 14;
    body_h = 36;
    hp = 2;
    flash = 0;
    kicked = false;
    vxk = 0;
    facing = 1;
    atk = attack_get("prop_kicked");
    hit_list = [];
    timer = irandom(120);
    phase = "wait";     // carro: "wait" | "warn" | "run"
    car_x = 0;
    broken = false;     // claraboia ja atravessada
    // perigos ficam no chao, atras de todos os atores
    depth = breakable ? -y : -global.stage.floor_top + 6;
}

/// Golpe do jogador em um quebravel. Roda no escopo do obj_prop.
function prop_hit(_atk, _dir) {
    if (kicked) return;
    game_hitstop(2);
    vfx_spark(x, y - body_h * 0.6, false);
    flash = 5;
    if (_atk.knockdown) {
        kicked = true;
        facing = _dir;
        vxk = _dir * CFG.props.kicked_speed;
        timer = CFG.props.kicked_frames;
        hit_list = [];
    } else {
        hp--;
        fx_burst(x, y - body_h * 0.5, 4, make_colour_rgb(180, 130, 80), 1.6);
        if (hp <= 0) prop_break();
    }
}

/// Quebra o objeto e entrega o que havia dentro.
function prop_break() {
    var _P = CFG.props;
    fx_dust(x, y, 8);
    fx_burst(x, y - body_h * 0.5, 12, make_colour_rgb(170, 120, 70), 2.6);
    cam_shake(1.5);

    if (global.run.active) {
        var _roll = random(1);
        if (_roll < _P.food_chance) {
            run_heal(_P.food_heal);
            fx_number(x, y - 24, "+" + string(_P.food_heal) + " vida", make_colour_rgb(90, 230, 120));
        } else if (_roll < _P.food_chance + 0.08 && is_undefined(global.run.weapon)) {
            instance_create_depth(x, y, 0, obj_interact, {
                kind: "weapon",
                wid: "w_pipe",
                durability: weapon_def("w_pipe").durability,
                map_index: map_index,
                drop_key: (map_index >= 0) ? run_map_new_drop_key() : ""
            });
        } else {
            var _coins = round(irandom_range(_P.coin_drop[0], _P.coin_drop[1]) * global.run.stats.coin_mult);
            global.run.coins += _coins;
            fx_number(x, y - 24, "+" + string(_coins), make_colour_rgb(255, 210, 63));
        }
        // um objeto destruido nao volta ao reentrar no corredor
        if (map_index >= 0 && prop_index >= 0) global.run.maps[map_index].props[prop_index].alive = false;
    }
    instance_destroy();
}

function prop_step() {
    if (game_frozen()) return;
    if (flash > 0) flash--;

    switch (kind) {
        case "barrel":
        case "crate":
        case "bin":
            if (!kicked) break;
            // deslizando: derruba inimigos no caminho e quebra no fim
            x += vxk;
            timer--;
            depth = -y;
            if (timer mod 4 == 0) fx_dust(x, y, 2);
            var _me = id;
            var _targets = [];
            with (obj_enemy) {
                if (array_contains(_me.hit_list, id)) continue;
                if (combat_overlap(_me, id)) array_push(_targets, id);
            }
            for (var _i = 0; _i < array_length(_targets); _i++) {
                array_push(hit_list, _targets[_i]);
                if (!instance_exists(_targets[_i])) continue;
                combat_deliver(_targets[_i], {
                    atk: atk,
                    damage: atk.damage * global.run.stats.damage_mult,
                    dir: facing,
                    attacker: noone
                }, noone);
            }
            if (timer <= 0 || x <= stage_x1() + 4 || x >= stage_x2() - 4) prop_break();
            break;

        case "toxic":
            timer++;
            if (timer mod 20 == 0) fx_burst(x + random_range(-20, 20), y + random_range(-6, 6), 1, make_colour_rgb(120, 255, 120), 0.6, -0.02);
            if (timer mod CFG.props.toxic_interval != 0) break;
            var _px = x;
            var _py = y;
            var _victims = [];
            with (obj_actor) {
                if (z > 0) continue;
                var _dx = (x - _px) / 28;
                var _dy = (y - _py) / 10;
                if (_dx * _dx + _dy * _dy <= 1) array_push(_victims, id);
            }
            var _tox = attack_get("hazard_toxic");
            for (var _i = 0; _i < array_length(_victims); _i++) {
                if (!instance_exists(_victims[_i])) continue;
                combat_deliver(_victims[_i], { atk: _tox, damage: _tox.damage, dir: 1, attacker: noone }, noone);
            }
            break;

        case "car":
            prop_car_step();
            break;
    }
}

/// Carro das ruas: espera, avisa a faixa e cruza a tela da esquerda para a direita.
function prop_car_step() {
    var _P = CFG.props;
    var _cam = global.cam.x;
    // so funciona quando o trecho dele esta na tela
    var _near = abs((_cam + VIEW_W * 0.5) - x) < 420;

    switch (phase) {
        case "wait":
            if (!_near) break;
            timer++;
            if (timer >= _P.car_cycle) {
                timer = 0;
                phase = "warn";
            }
            break;

        case "warn":
            timer++;
            if (timer >= _P.car_warn) {
                timer = 0;
                phase = "run";
                car_x = _cam - 60;
                hit_list = [];
            }
            break;

        case "run":
            car_x += _P.car_speed;
            if (timer mod 3 == 0) fx_dust(car_x - 24, y, 1);
            timer++;
            var _car = attack_get("hazard_car");
            var _vol = { x: car_x, y: y, z: 0, facing: 1, atk: _car };
            var _me = id;
            var _targets = [];
            with (obj_actor) {
                if (array_contains(_me.hit_list, id)) continue;
                if (combat_overlap(_vol, id)) array_push(_targets, id);
            }
            for (var _i = 0; _i < array_length(_targets); _i++) {
                array_push(hit_list, _targets[_i]);
                if (!instance_exists(_targets[_i])) continue;
                combat_deliver(_targets[_i], { atk: _car, damage: _car.damage, dir: 1, attacker: noone }, noone);
            }
            if (car_x > _cam + VIEW_W + 80) {
                timer = 0;
                phase = "wait";
            }
            break;
    }
}

/// Chamado quando um ator derrubado toca o chao (jogador e inimigos).
/// Claraboia: quem cai em cima atravessa o vidro.
function hazard_knockdown_landed(_inst) {
    var _hit_prop = noone;
    with (obj_prop) {
        if (kind != "skylight") continue;
        if (abs(_inst.x - x) <= 30 && abs(_inst.y - y) <= 13) _hit_prop = id;
    }
    if (_hit_prop == noone) return;

    with (_hit_prop) {
        if (!broken) {
            broken = true;
            fx_burst(x, y, 24, make_colour_rgb(160, 240, 255), 3.4);
            cam_shake(3);
        }
    }
    fx_dust(_inst.x, _inst.y, 10);

    if (_inst.object_index == obj_player) {
        var _dmg = min(global.run.hp, CFG.props.skylight_player_damage * global.run.stats.damage_taken_mult);
        global.run.hp -= _dmg;
        global.run.dmg_taken += _dmg;
        fx_number(_inst.x, _inst.y - 40, round(_dmg), make_colour_rgb(255, 90, 90));
        toast_show("Voce atravessou a claraboia!");
    } else if (_inst.cfg.ai != "boss" && _inst.hp > 0) {
        // inimigo comum: cai do predio
        global.run.dmg_dealt += _inst.hp;
        _inst.hp = 0;
        fx_number(_inst.x, _inst.y - 40, "QUEDA!", make_colour_rgb(160, 240, 255));
        run_enemy_killed(_inst.elite ? CFG.elite.coin_mult : 1, _inst.x, _inst.y - 56);
    }
}

function prop_draw() {
    var _warn = make_colour_rgb(255, 60, 90);

    switch (kind) {
        case "barrel":
        case "crate":
        case "bin":
            draw_set_alpha(0.3);
            draw_set_colour(c_black);
            draw_ellipse(x - 17, y - 4, x + 17, y + 4, false);
            draw_set_alpha(1);
            var _pspr = spr_prop_crate;
            if (kind == "barrel") _pspr = spr_prop_barrel;
            if (kind == "bin") _pspr = spr_prop_bin;
            // rachado depois do primeiro golpe: escurece; clarao branco ao ser atingido
            var _ptint = (hp < 2) ? make_colour_rgb(190, 150, 140) : c_white;
            if (flash > 0) gpu_set_fog(true, c_white, 0, 0);
            draw_sprite_ext(_pspr, 0, round(x), round(y) + 2, facing, 1, 0, _ptint, 1);
            if (flash > 0) gpu_set_fog(false, c_white, 0, 0);
            break;

        case "toxic":
            draw_set_alpha(0.55);
            draw_set_colour(make_colour_rgb(40, 150, 60));
            draw_ellipse(x - 28, y - 10, x + 28, y + 10, false);
            draw_set_alpha(0.8);
            draw_set_colour(make_colour_rgb(120, 255, 120));
            draw_ellipse(x - 28, y - 10, x + 28, y + 10, true);
            draw_ellipse(x - 12 + (timer div 12) mod 6, y - 3, x - 4 + (timer div 12) mod 6, y + 1, true);
            draw_set_alpha(1);
            break;

        case "skylight":
            if (broken) {
                draw_set_colour(make_colour_rgb(4, 4, 12));
                draw_rectangle(x - 30, y - 13, x + 30, y + 13, false);
                draw_set_colour(make_colour_rgb(160, 240, 255));
                draw_rectangle(x - 30, y - 13, x - 24, y - 9, false);
                draw_rectangle(x + 22, y + 8, x + 30, y + 13, false);
            } else {
                draw_set_alpha(0.45);
                draw_set_colour(make_colour_rgb(90, 200, 230));
                draw_rectangle(x - 30, y - 13, x + 30, y + 13, false);
                draw_set_alpha(1);
                draw_set_colour(make_colour_rgb(200, 245, 255));
                draw_line(x - 20, y - 9, x - 8, y - 9);
            }
            draw_set_colour(make_colour_rgb(70, 78, 92));
            draw_rectangle(x - 30, y - 13, x + 30, y + 13, true);
            draw_rectangle(x - 31, y - 14, x + 31, y + 14, true);
            if (!broken) {
                draw_line(x, y - 13, x, y + 13);
                draw_line(x - 30, y, x + 30, y);
            }
            break;

        case "car":
            var _lane = attack_get("hazard_car").lane;
            var _cam = global.cam.x;
            if (phase == "warn") {
                // faixa piscando em toda a largura da tela + seta na borda de entrada
                var _blink = ((timer div 5) mod 2 == 0);
                draw_set_colour(_warn);
                draw_set_alpha(_blink ? 0.32 : 0.14);
                draw_rectangle(_cam - 16, y - _lane, _cam + VIEW_W + 16, y + _lane, false);
                draw_set_alpha(1);
                draw_rectangle(_cam - 16, y - _lane, _cam + VIEW_W + 16, y + _lane, true);
                if (_blink) draw_triangle(_cam + 6, y - 8, _cam + 6, y + 8, _cam + 20, y, false);
            } else if (phase == "run") {
                var _cx = round(car_x);
                draw_set_alpha(0.35);
                draw_set_colour(c_black);
                draw_ellipse(_cx - 40, y - 4, _cx + 40, y + 4, false);
                draw_set_alpha(1);
                draw_sprite(spr_prop_car, 0, _cx, y + 3);
            }
            break;
    }
    draw_set_alpha(1);
    draw_set_colour(c_white);
}

// ------------------------------------------------------------ obj_projectile

/// Cria o tiro de um inimigo a distancia. _pcfg = { speed, z, life }.
function projectile_spawn(_owner, _atk, _pcfg, _dmg_mult = 1) {
    return instance_create_depth(_owner.x + _owner.facing * 12, _owner.y, 0, obj_projectile, {
        team: _owner.team,
        atk: _atk,
        facing: _owner.facing,
        spd: _pcfg.speed,
        z: _pcfg.z,
        life: _pcfg.life,
        dmg_mult: _dmg_mult
    });
}

function projectile_step() {
    if (game_frozen()) return;
    x += facing * spd;
    life--;
    depth = -y;

    var _me = id;
    var _targets = [];
    with (obj_actor) {
        if (team == _me.team) continue;
        if (array_contains(_me.hit_list, id)) continue;
        if (combat_overlap(_me, id)) array_push(_targets, id);
    }
    for (var _i = 0; _i < array_length(_targets); _i++) {
        var _t = _targets[_i];
        array_push(hit_list, _t);
        if (!instance_exists(_t)) continue;
        var _res = combat_deliver(_t, {
            atk: atk,
            damage: atk.damage * dmg_mult,
            dir: facing,
            attacker: noone
        }, noone);
        // esquivado: o tiro segue; acertou ou foi bloqueado: some
        if (_res != HITRES.IGNORED) {
            instance_destroy();
            return;
        }
    }

    if (life <= 0 || x < stage_x1() - 24 || x > stage_x2() + 24) instance_destroy();
}

function projectile_draw() {
    draw_set_alpha(0.3);
    draw_set_colour(c_black);
    draw_ellipse(x - 4, y - 1, x + 4, y + 1, false);
    draw_set_alpha(1);
    var _py = y - z;
    draw_set_colour(make_colour_rgb(255, 120, 60));
    draw_rectangle(x - facing * 9, _py - 1, x, _py, false);
    draw_set_colour(make_colour_rgb(255, 240, 150));
    draw_rectangle(x - 3, _py - 2, x + 3, _py + 1, false);
    draw_set_colour(c_white);
}
