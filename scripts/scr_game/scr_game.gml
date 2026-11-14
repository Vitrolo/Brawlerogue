/// Inicializacao, fluxo (jogo/derrota), congelamento de impacto, efeitos e HUD.

enum FLOW {
    PLAY,
    DEFEAT,
    VICTORY,
    CHOICE   // tela de escolha aberta: o jogo espera a decisao
}

function game_init() {
    game_set_speed(60, gamespeed_fps);
    gpu_set_texfilter(false);

    config_init();
    mods_init();
    input_init();
    player_states_init();
    stage_defs_init();
    cam_init();
    run_reset();

    global.hitstop = 0;
    global.prompt = "";
    global.vfx = [];
    global.choice = undefined;
    global.toast = { text: "", timer: 0 };
    global.last_run_result = "";
    global.flow = { state: FLOW.PLAY, timer: 0 };

    display_set_gui_size(CFG.view.gui_w, CFG.view.gui_h);
    var _scale = clamp(floor((display_get_height() - 80) / VIEW_H), 1, CFG.view.scale_max);
    window_set_size(VIEW_W * _scale, VIEW_H * _scale);
}

/// Atores e hitboxes param enquanto o congelamento de impacto esta ativo.
function game_frozen() {
    return global.hitstop > 0;
}

function game_hitstop(_frames) {
    global.hitstop = max(global.hitstop, _frames);
}

/// Begin Step do obj_game.
function game_begin_step() {
    input_update();
    global.prompt = "";
    if (global.hitstop > 0) global.hitstop--;

    if (global.run.active) global.run.time_frames++;
    encounter_update();
    if (global.toast.timer > 0) global.toast.timer--;
    if (global.flow.state == FLOW.CHOICE) choice_update();

    if (global.flow.state == FLOW.DEFEAT || global.flow.state == FLOW.VICTORY) {
        global.flow.timer--;
        if (global.flow.timer <= 0) run_end(global.flow.state == FLOW.VICTORY ? "victory" : "defeat");
    }
}

function game_player_died() {
    if (global.flow.state != FLOW.PLAY) return;
    global.flow.state = FLOW.DEFEAT;
    global.flow.timer = CFG.flow.defeat_frames;
}

/// Chefe derrotado: interrompe a luta, mostra a vitoria e volta ao lobby.
function game_victory() {
    if (global.flow.state == FLOW.DEFEAT || global.flow.state == FLOW.VICTORY) return;
    global.choice = undefined;
    global.flow.state = FLOW.VICTORY;
    global.flow.timer = CFG.flow.victory_frames;
    global.run.active = false; // para o relogio da run
}

// ---------------------------------------------------------------- efeitos

function vfx_spark(_x, _y, _blocked) {
    array_push(global.vfx, { x: _x, y: _y, life: 8, blocked: _blocked });
}

function vfx_update() {
    for (var _i = array_length(global.vfx) - 1; _i >= 0; _i--) {
        global.vfx[_i].life--;
        if (global.vfx[_i].life <= 0) array_delete(global.vfx, _i, 1);
    }
}

function vfx_draw() {
    for (var _i = 0; _i < array_length(global.vfx); _i++) {
        var _f = global.vfx[_i];
        var _r = 2 + (8 - _f.life);
        // acerto = estrela dourada; bloqueio = losango ciano (forma e cor diferentes)
        if (_f.blocked) {
            draw_set_colour(make_colour_rgb(45, 226, 230));
            draw_line_width(_f.x - _r, _f.y, _f.x, _f.y - _r, 1);
            draw_line_width(_f.x, _f.y - _r, _f.x + _r, _f.y, 1);
            draw_line_width(_f.x + _r, _f.y, _f.x, _f.y + _r, 1);
            draw_line_width(_f.x, _f.y + _r, _f.x - _r, _f.y, 1);
        } else {
            draw_set_colour(make_colour_rgb(255, 210, 63));
            draw_line_width(_f.x - _r, _f.y, _f.x + _r, _f.y, 1);
            draw_line_width(_f.x, _f.y - _r, _f.x, _f.y + _r, 1);
            draw_set_colour(c_white);
            draw_line_width(_f.x - _r * 0.6, _f.y - _r * 0.6, _f.x + _r * 0.6, _f.y + _r * 0.6, 1);
            draw_line_width(_f.x - _r * 0.6, _f.y + _r * 0.6, _f.x + _r * 0.6, _f.y - _r * 0.6, 1);
        }
    }
    draw_set_colour(c_white);
}

// -------------------------------------------------------------------- HUD

function hud_text(_x, _y, _str, _col = c_white) {
    draw_set_colour(c_black);
    draw_text(_x + 1, _y + 1, _str);
    draw_set_colour(_col);
    draw_text(_x, _y, _str);
}

function hud_bar(_x, _y, _w, _h, _ratio, _col) {
    _ratio = clamp(_ratio, 0, 1);
    draw_set_colour(c_black);
    draw_rectangle(_x - 2, _y - 2, _x + _w + 2, _y + _h + 2, false);
    draw_set_colour(make_colour_rgb(40, 44, 70));
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    if (_ratio > 0) {
        draw_set_colour(_col);
        draw_rectangle(_x, _y, _x + _w * _ratio, _y + _h, false);
    }
    draw_set_colour(c_white);
    draw_rectangle(_x - 2, _y - 2, _x + _w + 2, _y + _h + 2, true);
}

function hud_draw() {
    if (is_undefined(global.stage)) return;

    var _gw = CFG.view.gui_w;
    var _gh = CFG.view.gui_h;
    var _run = global.run;
    var _gold = make_colour_rgb(255, 210, 63);
    var _cyan = make_colour_rgb(45, 226, 230);

    draw_set_font(-1);
    draw_set_alpha(1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // vida
    hud_bar(18, 18, 260, 16, _run.hp / _run.hp_max, make_colour_rgb(255, 60, 90));
    hud_text(24, 18, "HP " + string(ceil(_run.hp)) + "/" + string(_run.hp_max));

    // especial
    var _sp = CFG.player.special;
    var _ready = _run.special >= _sp.cost;
    hud_bar(18, 46, 160, 8, _run.special / _sp.meter_max, _ready ? _gold : _cyan);
    hud_text(188, 40, _ready ? "ESPECIAL PRONTO [" + input_action_label(ACT.SPECIAL) + "]" : "ESPECIAL", _ready ? _gold : c_white);

    // moedas, arma e modificadores ativos (so durante a run)
    if (_run.active) {
        var _ly = 64;
        hud_text(18, _ly, "MOEDAS: " + string(_run.coins), _gold);
        _ly += 18;
        if (!is_undefined(_run.weapon)) {
            hud_text(18, _ly, "ARMA: " + weapon_def(_run.weapon.wid).name + " (" + string(_run.weapon.durability) + ")", _cyan);
            _ly += 18;
        }
        var _seen = [];
        for (var _i = 0; _i < array_length(_run.modifiers); _i++) {
            var _mid = _run.modifiers[_i];
            if (array_contains(_seen, _mid)) continue;
            array_push(_seen, _mid);
            var _count = 0;
            for (var _j = 0; _j < array_length(_run.modifiers); _j++) {
                if (_run.modifiers[_j] == _mid) _count++;
            }
            hud_text(18, _ly, "+ " + mod_get(_mid).name + (_count > 1 ? " x" + string(_count) : ""), make_colour_rgb(170, 180, 220));
            _ly += 16;
        }
    }

    // sala e progresso do encontro
    var _rt = global.stage_rt;
    draw_set_halign(fa_right);
    hud_text(_gw - 18, 16, _rt.title);
    if (_rt.subtitle != "") hud_text(_gw - 18, 34, _rt.subtitle, make_colour_rgb(170, 180, 220));
    var _boss = boss_find();
    if (_boss != noone) {
        // vida do chefe: barra central com marca da mudanca de fase
        var _bx = _gw * 0.5 - 200;
        hud_bar(_bx, 74, 400, 10, _boss.hp / _boss.hp_max, make_colour_rgb(255, 60, 170));
        draw_set_colour(c_white);
        draw_rectangle(_bx + 400 * _boss.cfg.phase2_at, 70, _bx + 400 * _boss.cfg.phase2_at + 1, 88, false);
        draw_set_halign(fa_center);
        hud_text(_gw * 0.5, 52, _boss.cfg.name + "  -  FASE " + string(_boss.phase), _gold);
        draw_set_halign(fa_right);
    } else if (_rt.enc_state == ENC.ACTIVE || _rt.enc_state == ENC.BETWEEN) {
        hud_text(_gw - 18, 54, "ONDA " + string(_rt.enc_wave + 1) + "/" + string(encounter_wave_count()) + "   INIMIGOS: " + string(enemies_alive()), _gold);
    } else if (_rt.enc_state == ENC.CLEARED && global.stage.kind != "boss") {
        hud_text(_gw - 18, 54, "SAIDA LIBERADA", _cyan);
        // "GO" grande piscando com seta, no canto direito e fora da area de luta
        if (_rt.go_timer > 0 && (_rt.go_timer div 15) mod 2 == 0) {
            draw_text_transformed_colour(_gw - 64, 78, "GO", 3, 3, 0, _gold, _gold, _gold, _gold, 1);
            draw_set_colour(_gold);
            draw_triangle(_gw - 54, 86, _gw - 54, 114, _gw - 26, 100, false);
        }
    }
    if (global.run.seed != 0) hud_text(_gw - 18, _gh - 24, "SEED " + string(global.run.seed), make_colour_rgb(120, 128, 170));

    // Nas salas escuras a identificacao continua sobre o portal. No corredor,
    // o jogador ve o tipo no aviso de interacao, sem texto pairando no cenario.
    if (global.stage.kind != "main_map") {
        draw_set_halign(fa_center);
        var _open = stage_exits_open();
        var _camx = round(global.cam.x);
        var _sx = _gw / VIEW_W;
        var _sy = _gh / VIEW_H;
        with (obj_door) {
            if (room_kind == "") continue;
            var _col = _open ? room_kind_colour(room_kind) : make_colour_rgb(120, 124, 150);
            hud_text((x - _camx) * _sx, (y - 96) * _sy, room_kind_label(room_kind), _col);
        }
    }

    // faixa ao entrar em um bioma
    if (_rt.banner_timer > 0) {
        _rt.banner_timer--;
        draw_set_valign(fa_middle);
        draw_text_transformed_colour(_gw * 0.5, 110, _rt.title, 2, 2, 0, _cyan, _cyan, _cyan, _cyan, min(1, _rt.banner_timer / 30));
        draw_set_valign(fa_top);
    }

    // aviso de interacao
    draw_set_halign(fa_center);
    if (global.prompt != "" && global.flow.state == FLOW.PLAY) {
        hud_text(_gw * 0.5, _gh - 70, global.prompt, _gold);
    }

    // ajuda de controles no lobby
    if (global.stage.kind == "lobby") {
        draw_set_halign(fa_left);
        var _l = function(_a) { return input_action_label(_a); };
        hud_text(18, _gh - 44, "Mover: WASD   Pular: " + _l(ACT.JUMP) + "   Atacar: " + _l(ACT.ATTACK) + "   Bloquear: " + _l(ACT.BLOCK) + " (segurar)");
        hud_text(18, _gh - 24, "Esquivar: " + _l(ACT.DODGE) + "   Especial: " + _l(ACT.SPECIAL) + "   Agarrar/arremessar: " + _l(ACT.GRAB) + "   Interagir: " + _l(ACT.INTERACT) + "   -  va ate a porta para iniciar a run");
        draw_set_halign(fa_center);
        if (global.last_run_result == "defeat") hud_text(_gw * 0.5, 80, "Ultima run: derrota", make_colour_rgb(255, 60, 170));
        if (global.last_run_result == "victory") hud_text(_gw * 0.5, 80, "Ultima run: VITORIA", _gold);
    }

    // aviso curto de recompensa
    if (global.toast.timer > 0) {
        draw_set_halign(fa_center);
        hud_text(_gw * 0.5, 112, global.toast.text, _gold);
    }

    choice_draw();

    // derrota
    if (global.flow.state == FLOW.DEFEAT) {
        draw_set_alpha(0.55);
        draw_set_colour(c_black);
        draw_rectangle(0, 0, _gw, _gh, false);
        draw_set_alpha(1);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text_transformed_colour(_gw * 0.5, _gh * 0.45, "DERROTA", 3, 3, 0, c_red, c_red, c_red, c_red, 1);
        hud_text(_gw * 0.5, _gh * 0.45 + 50, "Voltando ao lobby...");
    }

    // vitoria
    if (global.flow.state == FLOW.VICTORY) {
        draw_set_alpha(0.55);
        draw_set_colour(c_black);
        draw_rectangle(0, 0, _gw, _gh, false);
        draw_set_alpha(1);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text_transformed_colour(_gw * 0.5, _gh * 0.4, "VITORIA", 3, 3, 0, _gold, _gold, _gold, _gold, 1);
        var _secs = _run.time_frames div 60;
        var _ss = string(_secs mod 60);
        if (string_length(_ss) < 2) _ss = "0" + _ss;
        hud_text(_gw * 0.5, _gh * 0.4 + 50, "Chefe derrotado em " + string(_secs div 60) + ":" + _ss);
        hud_text(_gw * 0.5, _gh * 0.4 + 74, "Voltando ao lobby...");
    }

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
    draw_set_alpha(1);
}
