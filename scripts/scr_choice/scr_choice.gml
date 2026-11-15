/// Tela de escolha (recompensa, loja, evento) e objetos interativos das salas
/// especiais. Cada opcao e um dado: { label, desc, cost, effects }.
/// Efeitos: {type:"mod", mid} | {type:"hp", amount} | {type:"max_hp", amount}
///          | {type:"coins", amount} | {type:"random_passive"} | {type:"none"}
///          | {type:"meta_upgrade", key} | {type:"set_char", cid} | {type:"unlock_char", cid}
///          | {type:"challenge_start", rule}
/// Campos opcionais da opcao: currency "chips" (cobra fichas em vez de moedas),
/// disabled (nao pode ser escolhida), cancel (fecha sem gastar a sala).
/// _kind "meta_shop" / "meta_char": telas do lobby, remontadas apos cada compra.

function choice_open(_title, _options, _can_cancel, _keep_open, _source, _kind = "") {
    global.choice = {
        title: _title,
        kind: _kind,
        options: _options,
        index: 0,
        can_cancel: _can_cancel, // pode sair sem escolher
        keep_open: _keep_open,   // loja: continua aberta apos comprar
        source: _source          // obj_interact que abriu a tela
    };
    global.flow.state = FLOW.CHOICE;
}

function choice_close(_mark_used) {
    var _ch = global.choice;
    if (!is_undefined(_ch) && _mark_used && instance_exists(_ch.source)) {
        _ch.source.used = true;
        interact_persist_state(_ch.source);
    }
    global.choice = undefined;
    global.flow.state = FLOW.PLAY;
    with (obj_player) {
        // nenhum comando da tela vaza para o jogo
        buf_attack = 0;
        buf_jump = 0;
        buf_dodge = 0;
        buf_special = 0;
        buf_grab = 0;
    }
}

/// Chamado todo frame pelo obj_game enquanto a tela esta aberta.
function choice_update() {
    var _ch = global.choice;
    if (is_undefined(_ch)) {
        global.flow.state = FLOW.PLAY;
        return;
    }
    var _n = array_length(_ch.options);

    if (input_pressed(ACT.LEFT) || input_pressed(ACT.UP)) _ch.index = (_ch.index + _n - 1) mod _n;
    if (input_pressed(ACT.RIGHT) || input_pressed(ACT.DOWN)) _ch.index = (_ch.index + 1) mod _n;

    if (_ch.can_cancel && input_pressed(ACT.DODGE)) {
        choice_close(false);
        return;
    }

    if (input_pressed(ACT.INTERACT)) {
        var _opt = _ch.options[_ch.index];
        if (variable_struct_exists(_opt, "disabled") && _opt.disabled) return;
        var _chips = variable_struct_exists(_opt, "currency") && _opt.currency == "chips";
        if (_opt.cost > (_chips ? global.meta.chips : global.run.coins)) {
            toast_show(_chips ? "Fichas insuficientes." : "Moedas insuficientes.");
            return;
        }
        if (_chips) global.meta.chips -= _opt.cost;
        else global.run.coins -= _opt.cost;
        var _seed = instance_exists(_ch.source) ? _ch.source.seed : 0;
        for (var _i = 0; _i < array_length(_opt.effects); _i++) {
            effect_apply(_opt.effects[_i], _seed);
        }
        if (_ch.kind == "meta_shop" || _ch.kind == "meta_char") {
            // telas do lobby: a lista e refeita com os novos niveis e precos
            _ch.options = (_ch.kind == "meta_shop") ? meta_shop_options() : meta_char_options();
            _ch.index = min(_ch.index, array_length(_ch.options) - 1);
            save_write();
            return;
        }
        if (_ch.keep_open) {
            array_delete(_ch.options, _ch.index, 1); // item vendido sai da prateleira
            if (instance_exists(_ch.source)) {
                _ch.source.stock = _ch.options;
                interact_persist_state(_ch.source);
            }
            if (array_length(_ch.options) == 0) {
                choice_close(true);
            } else {
                _ch.index = min(_ch.index, array_length(_ch.options) - 1);
            }
        } else {
            choice_close(!(variable_struct_exists(_opt, "cancel") && _opt.cancel));
        }
    }
}

function effect_apply(_e, _seed) {
    var _run = global.run;
    switch (_e.type) {
        case "mod":
            mod_grant(_e.mid);
            break;
        case "hp":
            _run.hp = clamp(_run.hp + _e.amount, 1, _run.hp_max); // eventos nunca matam
            break;
        case "max_hp":
            _run.hp_max = max(20, _run.hp_max + _e.amount);
            _run.hp = min(_run.hp, _run.hp_max);
            break;
        case "coins":
            _run.coins = max(0, _run.coins + _e.amount);
            break;
        case "random_passive":
            var _got = reward_roll(global.passive_pool, 1, _seed + 31);
            if (array_length(_got) > 0) {
                mod_grant(_got[0]);
            } else {
                _run.coins += 20;
                toast_show("Voce ja tem todas as passivas: +20 moedas.");
            }
            break;
        case "meta_upgrade":
            global.meta.upgrades[$ _e.key] = meta_level(_e.key) + 1;
            run_reset(); // a vida mostrada no lobby ja reflete a melhoria
            toast_show("Melhoria comprada!");
            break;
        case "unlock_char":
            if (!array_contains(global.meta.chars, _e.cid)) array_push(global.meta.chars, _e.cid);
            global.meta.char = _e.cid;
            run_reset();
            with (obj_player) pchar = player_char(); // troca na hora, ainda no lobby
            toast_show(global.chars[$ _e.cid].name + " liberada!");
            break;
        case "set_char":
            global.meta.char = _e.cid;
            run_reset();
            with (obj_player) pchar = player_char(); // troca na hora, ainda no lobby
            toast_show("Personagem: " + global.chars[$ _e.cid].name);
            break;
        case "challenge_start":
            challenge_start(_e.rule, _seed);
            break;
    }
}

function option_from_mod(_mid, _with_price) {
    var _d = mod_get(_mid);
    return {
        label: _d.name,
        desc: _d.desc,
        cost: _with_price ? round(_d.price * global.run.stats.shop_mult) : 0,
        effects: [{ type: "mod", mid: _mid }]
    };
}

function reward_options(_seed) {
    var _ids = reward_roll(global.reward_pool, CFG.rewards.choices, _seed);
    var _opts = [];
    for (var _i = 0; _i < array_length(_ids); _i++) array_push(_opts, option_from_mod(_ids[_i], false));
    // metade dos baus oferece tambem uma maldicao
    if (decor_rand(_seed, 55) < 0.5) {
        var _curse = reward_roll(global.curse_pool, 1, _seed + 13);
        if (array_length(_curse) > 0) array_push(_opts, option_from_mod(_curse[0], false));
    }
    return _opts;
}

function shop_options(_seed) {
    var _ids = reward_roll(global.reward_pool, CFG.rewards.shop_items, _seed + 7);
    var _opts = [option_from_mod("heal_big", true)];
    for (var _i = 0; _i < array_length(_ids); _i++) {
        if (_ids[_i] != "heal_big") array_push(_opts, option_from_mod(_ids[_i], true));
    }
    return _opts;
}

/// Sala de desafio: a regra e fixa pela seed da sala (ver scr_challenge).
function event_options(_seed) {
    var _rule = challenge_rule_for_seed(_seed);
    var _C = CFG.challenge;
    return [
        {
            label: "Aceitar",
            desc: "Arena fechada. Regra: " + challenge_rule_text(_rule) + ". Premio: recompensa a escolher, " + string(_C.reward_coins) + " moedas e " + string(_C.reward_chips) + " fichas.",
            cost: 0,
            effects: [{ type: "challenge_start", rule: _rule }]
        },
        { label: "Recusar", desc: "Nada acontece. Voce pode voltar depois.", cost: 0, effects: [{ type: "none" }], cancel: true }
    ];
}

function choice_draw() {
    var _ch = global.choice;
    if (is_undefined(_ch)) return;
    var _gw = CFG.view.gui_w;
    var _gh = CFG.view.gui_h;
    var _gold = make_colour_rgb(255, 210, 63);
    var _n = array_length(_ch.options);
    var _gap = 16;
    var _cw = min(200, floor((_gw - 40 - (_n - 1) * _gap) / _n)); // muitas opcoes: cartoes mais estreitos
    var _chh = 170;
    var _x0 = (_gw - (_n * _cw + (_n - 1) * _gap)) * 0.5;
    var _y0 = 190;

    draw_set_alpha(0.6);
    draw_set_colour(c_black);
    draw_rectangle(0, 0, _gw, _gh, false);
    draw_set_alpha(1);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_text_transformed_colour(_gw * 0.5, 130, _ch.title, 2, 2, 0, _gold, _gold, _gold, _gold, 1);

    for (var _i = 0; _i < _n; _i++) {
        var _opt = _ch.options[_i];
        var _x = _x0 + _i * (_cw + _gap);
        var _sel = (_i == _ch.index);
        draw_set_colour(_sel ? make_colour_rgb(44, 50, 96) : make_colour_rgb(20, 24, 52));
        draw_rectangle(_x, _y0, _x + _cw, _y0 + _chh, false);
        draw_set_colour(_sel ? _gold : make_colour_rgb(90, 96, 140));
        draw_rectangle(_x, _y0, _x + _cw, _y0 + _chh, true);
        if (_sel) {
            // selecao: moldura dupla + seta (nao so cor)
            draw_rectangle(_x - 2, _y0 - 2, _x + _cw + 2, _y0 + _chh + 2, true);
            draw_triangle(_x + _cw * 0.5 - 8, _y0 - 16, _x + _cw * 0.5 + 8, _y0 - 16, _x + _cw * 0.5, _y0 - 6, false);
        }
        var _off = variable_struct_exists(_opt, "disabled") && _opt.disabled;
        draw_set_colour(_off ? make_colour_rgb(120, 124, 150) : (_sel ? _gold : c_white));
        draw_text_ext(_x + _cw * 0.5, _y0 + 10, _opt.label, 16, _cw - 12);
        draw_set_colour(_off ? make_colour_rgb(120, 124, 150) : c_white);
        draw_text_ext(_x + _cw * 0.5, _y0 + 50, _opt.desc, 18, _cw - 24);
        if (_opt.cost > 0) {
            var _chips = variable_struct_exists(_opt, "currency") && _opt.currency == "chips";
            var _ok = (_opt.cost <= (_chips ? global.meta.chips : global.run.coins));
            draw_set_colour(_ok ? _gold : make_colour_rgb(255, 90, 90));
            draw_text(_x + _cw * 0.5, _y0 + _chh - 26, string(_opt.cost) + (_chips ? " fichas" : " moedas") + (_ok ? "" : " (falta)"));
        }
    }
    if (_ch.kind == "meta_shop" || _ch.kind == "meta_char") {
        draw_set_colour(make_colour_rgb(45, 226, 230));
        draw_text(_gw * 0.5, 166, "Fichas: " + string(global.meta.chips));
    }

    draw_set_colour(c_white);
    var _hint = "[" + input_action_label(ACT.LEFT) + "/" + input_action_label(ACT.RIGHT) + "] escolher   [" + input_action_label(ACT.INTERACT) + "] confirmar";
    if (_ch.can_cancel) _hint += "   [" + input_action_label(ACT.DODGE) + "] sair";
    draw_text(_gw * 0.5, _y0 + _chh + 22, _hint);
    draw_set_halign(fa_left);
}

// ------------------------------------------------------ objetos interativos

/// Cria os interativos da sala atual (chamado por stage_build).
function interact_spawn_for_stage(_def, _seed, _persist = undefined) {
    var _cx = _def.width * 0.5;
    var _cy = _def.floor_top + 26;
    var _used = !is_undefined(_persist) && _persist.used;
    var _stock = is_undefined(_persist) ? undefined : _persist.stock;
    switch (_def.kind) {
        case "rest":   instance_create_depth(_cx, _cy, 0, obj_interact, { kind: "rest", seed: _seed, used: _used, persistence_key: _def.sid }); break;
        case "reward": instance_create_depth(_cx, _cy, 0, obj_interact, { kind: "chest", seed: _seed, used: _used, persistence_key: _def.sid }); break;
        case "shop":   instance_create_depth(_cx, _cy, 0, obj_interact, { kind: "shop", seed: _seed, used: _used, stock: _stock, persistence_key: _def.sid }); break;
        case "event":  instance_create_depth(_cx, _cy, 0, obj_interact, { kind: "event", seed: _seed, used: _used, persistence_key: _def.sid }); break;
        case "lobby":
            // encostados na parede, sobre o saco de pancada e os armarios do cenario
            instance_create_depth(105, _def.floor_top + 8, 0, obj_interact, { kind: "meta_shop" });
            instance_create_depth(245, _def.floor_top + 8, 0, obj_interact, { kind: "char" });
            break;
    }
    if (variable_struct_exists(_def, "pickups")) {
        for (var _i = 0; _i < array_length(_def.pickups); _i++) {
            var _pk = _def.pickups[_i];
            instance_create_depth(_pk.x, _pk.y, 0, obj_interact, {
                kind: "weapon",
                wid: _pk.wid,
                durability: weapon_def(_pk.wid).durability
            });
        }
    }
}

function interact_step() {
    bob++;
    if (used || global.flow.state != FLOW.PLAY) return;
    var _p = instance_find(obj_player, 0);
    if (_p == noone) return;
    if (abs(_p.x - x) > 26 || abs(_p.y - y) > 18 || _p.z > 0) return;

    var _key = "[" + input_action_label(ACT.INTERACT) + "] ";
    switch (kind) {
        case "rest":   global.prompt = _key + "DESCANSAR (cura " + string(ceil(global.run.hp_max * CFG.rewards.rest_heal_pct)) + ")"; break;
        case "chest":  global.prompt = _key + "ABRIR RECOMPENSA"; break;
        case "shop":   global.prompt = _key + "VER LOJA (" + string(global.run.coins) + " moedas)"; break;
        case "event":  global.prompt = _key + "DESAFIO"; break;
        case "meta_shop": global.prompt = _key + "TREINAR (melhorias permanentes - " + string(global.meta.chips) + " fichas)"; break;
        case "char":   global.prompt = _key + "ARMARIO (trocar personagem)"; break;
        case "weapon": global.prompt = _key + "PEGAR " + string_upper(weapon_def(wid).name) + " (" + string(durability) + " usos)"; break;
    }

    if (!input_pressed(ACT.INTERACT) || !global.player_states[_p.state].can_act) return;

    switch (kind) {
        case "rest":
            var _amount = ceil(global.run.hp_max * CFG.rewards.rest_heal_pct);
            run_heal(_amount);
            toast_show("Descanso: +" + string(_amount) + " de vida.");
            used = true;
            interact_persist_state(id);
            break;
        case "chest":
            choice_open("RECOMPENSA - escolha uma", reward_options(seed), false, false, id);
            break;
        case "shop":
            if (is_undefined(stock)) stock = shop_options(seed);
            choice_open("LOJA", stock, true, true, id);
            break;
        case "event":
            choice_open("DESAFIO - " + global.stage.name, event_options(seed), false, false, id);
            break;
        case "meta_shop":
            choice_open("TREINO", meta_shop_options(), true, true, id, "meta_shop");
            break;
        case "char":
            choice_open("PERSONAGEM", meta_char_options(), true, true, id, "meta_char");
            break;
        case "weapon":
            // troca: a arma que estava na mao fica no chao
            var _old = global.run.weapon;
            weapon_equip(wid, durability);
            toast_show("Pegou: " + weapon_def(wid).name);
            if (persistent_key != "" && map_index >= 0) {
                run_map_save_pickup(map_index, persistent_key);
                if (!is_undefined(_old)) {
                    persistent_key = "";
                    drop_key = run_map_new_drop_key();
                }
            }
            if (is_undefined(_old)) {
                instance_destroy();
            } else {
                wid = _old.wid;
                durability = _old.durability;
            }
            break;
    }
}

function interact_persist_state(_inst) {
    if (!instance_exists(_inst)) return;
    if (_inst.persistence_key != "") {
        run_special_state_save(_inst.persistence_key, _inst.used, _inst.stock);
    }
}

/// PLACEHOLDER: interativos desenhados com retangulos.
function interact_draw() {
    var _gold = make_colour_rgb(255, 210, 63);
    var _dark = make_colour_rgb(6, 8, 20);
    var _col = used ? make_colour_rgb(90, 94, 120) : room_kind_colour(kind == "chest" ? "reward" : kind);

    // os interativos do lobby ja estao pintados no cenario: so o marcador aparece
    if (kind != "meta_shop" && kind != "char") {
        draw_set_alpha(0.3);
        draw_set_colour(c_black);
        draw_ellipse(x - 14, y - 3, x + 14, y + 3, false);
        draw_set_alpha(1);
    }

    switch (kind) {
        case "rest": // banco
            draw_set_colour(_col);
            draw_rectangle(x - 16, y - 12, x + 16, y - 8, false);
            draw_rectangle(x - 14, y - 8, x - 11, y, false);
            draw_rectangle(x + 11, y - 8, x + 14, y, false);
            break;
        case "chest": // bau
            draw_set_colour(_col);
            draw_rectangle(x - 12, y - 16, x + 12, y, false);
            draw_set_colour(_dark);
            draw_rectangle(x - 12, y - 10, x + 12, y - 9, false);
            draw_rectangle(x - 2, y - 12, x + 2, y - 6, false);
            break;
        case "shop": // banca com toldo
            draw_set_colour(make_colour_rgb(60, 62, 96));
            draw_rectangle(x - 20, y - 14, x + 20, y, false);
            draw_set_colour(_col);
            draw_rectangle(x - 22, y - 34, x + 22, y - 28, false);
            draw_rectangle(x - 20, y - 28, x - 18, y - 14, false);
            draw_rectangle(x + 18, y - 28, x + 20, y - 14, false);
            break;
        case "event": // painel
            draw_set_colour(make_colour_rgb(60, 62, 96));
            draw_rectangle(x - 8, y - 26, x + 8, y, false);
            draw_set_colour(_col);
            draw_rectangle(x - 5, y - 23, x + 5, y - 14, false);
            break;
        case "weapon": // arma no chao
            var _w = weapon_def(wid);
            draw_set_colour(_w.colour);
            draw_rectangle(x - _w.length * 0.5, y - 4, x + _w.length * 0.5, y - 2, false);
            break;
    }

    // marcador de interacao disponivel
    if (!used) {
        var _iy = y - 46 + ((bob div 12) mod 2) * 2;
        if (kind == "weapon") _iy = y - 18 + ((bob div 12) mod 2) * 2;
        draw_set_colour(_gold);
        draw_triangle(x - 5, _iy, x + 5, _iy, x, _iy + 6, false);
    }
    draw_set_colour(c_white);
}

/// Arma na mao do jogador (placeholder: uma barra). Desenhada pelo obj_game.
function player_draw_weapon() {
    var _wp = global.run.weapon;
    if (is_undefined(_wp)) return;
    var _w = weapon_def(_wp.wid);
    with (obj_player) {
        if (state == PS.KNOCKDOWN || state == PS.DEAD || state == PS.GETUP) continue;
        var _hx = round(x) + facing * 9;
        var _hy = round(y - z) - 27;
        draw_set_colour(_w.colour);
        if (state == PS.ATTACK && atk_weapon && attack_anim_frame(atk, state_timer) == 1) {
            draw_rectangle(min(_hx, _hx + facing * (_w.length + 12)), _hy - 1, max(_hx, _hx + facing * (_w.length + 12)), _hy + 1, false);
        } else {
            draw_rectangle(_hx - 1, _hy - _w.length, _hx + 1, _hy + 2, false);
        }
    }
    draw_set_colour(c_white);
}
