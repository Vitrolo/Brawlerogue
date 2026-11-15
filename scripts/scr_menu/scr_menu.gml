/// Telas fora do gameplay: splash de carregamento, menu principal, slots de save,
/// pausa e resultados da run. Todas sao desenhadas na interface (GUI) por cima do
/// jogo; enquanto uma esta aberta, global.flow.state sai de FLOW.PLAY e o jogador
/// nao recebe comandos.
///
/// global.ui.screen: "splash" | "menu" | "slots" | "pause" | "results" | "none"

function ui_init() {
    global.ui = {
        screen: "splash",
        timer: 0,
        index: 0,
        mode: "new",        // "new" ou "continue" (tela de slots)
        slots: [],
        confirm: "",        // "" | "overwrite" | "delete"
        message: "",
        message_timer: 0,
        results: undefined
    };
    global.flow.state = FLOW.MENU;
}

function ui_open(_screen) {
    var _ui = global.ui;
    _ui.screen = _screen;
    _ui.timer = 0;
    _ui.index = 0;
    _ui.confirm = "";
    if (_screen == "slots") _ui.slots = save_slot_infos();
}

function ui_message(_text) {
    global.ui.message = _text;
    global.ui.message_timer = 120;
}

function ui_confirm_pressed() {
    return input_pressed(ACT.INTERACT) || input_pressed(ACT.JUMP) || input_pressed(ACT.ATTACK);
}

function ui_back_pressed() {
    return input_pressed(ACT.DODGE) || input_pressed(ACT.PAUSE);
}

/// Move a selecao de uma lista de _n itens. Retorna o novo indice.
function ui_navigate(_index, _n) {
    if (input_pressed(ACT.UP) || input_pressed(ACT.LEFT)) _index = (_index + _n - 1) mod _n;
    if (input_pressed(ACT.DOWN) || input_pressed(ACT.RIGHT)) _index = (_index + 1) mod _n;
    return _index;
}

function ui_any_save() {
    for (var _i = 0; _i < SAVE_SLOTS; _i++) {
        if (save_exists(_i)) return true;
    }
    return false;
}

/// Itens da pausa: mudam se ha uma run em andamento.
function ui_pause_items() {
    if (global.run.active) return ["CONTINUAR", "ABANDONAR RUN", "SALVAR E IR AO MENU"];
    return ["CONTINUAR", "MENU PRINCIPAL", "SAIR DO JOGO"];
}

/// Fecha qualquer tela e devolve o controle ao jogo.
function ui_close() {
    global.ui.screen = "none";
    global.flow.state = FLOW.PLAY;
    // a tecla que confirmou o menu nao pode virar pulo ou golpe neste mesmo frame
    for (var _a = 0; _a < ACT.COUNT; _a++) global.input.pressed[_a] = false;
    with (obj_player) {
        buf_attack = 0;
        buf_jump = 0;
        buf_dodge = 0;
        buf_special = 0;
        buf_grab = 0;
    }
}

/// Chamado no inicio de cada frame. Retorna true quando uma tela consumiu o frame
/// (o resto do jogo nao deve atualizar).
function ui_update() {
    var _ui = global.ui;
    _ui.timer++;
    if (_ui.message_timer > 0) _ui.message_timer--;

    switch (_ui.screen) {
        case "none":
            // abrir a pausa
            if (input_pressed(ACT.PAUSE) && global.flow.state == FLOW.PLAY) {
                ui_open("pause");
                global.flow.state = FLOW.PAUSE;
                return true;
            }
            return false;

        case "splash":
            if (_ui.timer >= CFG.ui.splash_frames || (input_pressed(ACT.JUMP) && _ui.timer > 10)) {
                ui_open("menu");
            }
            return true;

        case "menu":
            _ui.index = ui_navigate(_ui.index, 3);
            if (ui_confirm_pressed() && _ui.timer > 8) {
                switch (_ui.index) {
                    case 0:
                        _ui.mode = "new";
                        ui_open("slots");
                        break;
                    case 1:
                        if (ui_any_save()) {
                            _ui.mode = "continue";
                            ui_open("slots");
                        } else {
                            ui_message("Nenhum save encontrado.");
                        }
                        break;
                    case 2:
                        game_end();
                        break;
                }
            }
            return true;

        case "slots":
            ui_update_slots();
            return true;

        case "pause":
            var _items = ui_pause_items();
            _ui.index = ui_navigate(_ui.index, array_length(_items));
            if (ui_back_pressed() && _ui.timer > 8) {
                ui_close();
                return true;
            }
            if (ui_confirm_pressed() && _ui.timer > 8) {
                var _run_active = global.run.active;
                switch (_ui.index) {
                    case 0:
                        ui_close();
                        break;
                    case 1:
                        if (_run_active) {
                            // abandonar conta como derrota e mostra os resultados
                            results_open("abandon");
                        } else {
                            save_write();
                            ui_goto_menu();
                        }
                        break;
                    case 2:
                        if (_run_active) {
                            // a run fica guardada no ultimo ponto de controle
                            ui_goto_menu();
                        } else {
                            save_write();
                            game_end();
                        }
                        break;
                }
            }
            return true;

        case "results":
            if (ui_confirm_pressed() && _ui.timer > 40) {
                var _res = _ui.results.result;
                _ui.results = undefined;
                _ui.screen = "none";
                run_end(_res);
            }
            return true;
    }
    return false;
}

function ui_update_slots() {
    var _ui = global.ui;

    // confirmacao pendente (sobrescrever ou apagar)
    if (_ui.confirm != "") {
        if (input_pressed(ACT.INTERACT)) {
            if (_ui.confirm == "overwrite") {
                save_delete(_ui.index);
                _ui.confirm = "";
                ui_start_slot(_ui.index, true);
            } else {
                save_delete(_ui.index);
                _ui.confirm = "";
                _ui.slots = save_slot_infos();
                ui_message("Save apagado.");
            }
        } else if (ui_back_pressed()) {
            _ui.confirm = "";
        }
        return;
    }

    _ui.index = ui_navigate(_ui.index, SAVE_SLOTS);

    if (ui_back_pressed() && _ui.timer > 8) {
        ui_open("menu");
        return;
    }

    var _info = _ui.slots[_ui.index];
    if (input_pressed(ACT.GRAB) && _info.used) {
        _ui.confirm = "delete";
        return;
    }

    if (ui_confirm_pressed() && _ui.timer > 8) {
        if (_ui.mode == "new") {
            if (_info.used) {
                _ui.confirm = "overwrite";
            } else {
                ui_start_slot(_ui.index, true);
            }
        } else {
            if (_info.used) {
                ui_start_slot(_ui.index, false);
            } else {
                ui_message("Este slot esta vazio.");
            }
        }
    }
}

function ui_start_slot(_slot, _new) {
    ui_close();
    global.last_run_result = "";
    if (_new) {
        save_new_game(_slot);
    } else if (!save_continue(_slot)) {
        // arquivo corrompido: volta para a lista em vez de travar
        ui_open("slots");
        global.flow.state = FLOW.MENU;
        ui_message("Nao foi possivel ler este save.");
    }
}

/// Volta ao menu principal. A sala do lobby fica por baixo como fundo.
function ui_goto_menu() {
    global.choice = undefined;
    run_reset();
    global.meta = meta_default();
    ui_open("menu");
    global.flow.state = FLOW.MENU;
    stage_goto("lobby");
}

/// Abre a tela de resultados (derrota, vitoria ou abandono).
function results_open(_result) {
    global.choice = undefined;
    global.run.active = false; // para o relogio e impede novo save da run
    global.ui.results = meta_finish_run(_result);
    ui_open("results");
    global.flow.state = FLOW.RESULTS;
}

// ------------------------------------------------------------------ desenho

function ui_draw_backdrop(_alpha) {
    draw_set_alpha(_alpha);
    draw_set_colour(make_colour_rgb(6, 6, 18));
    draw_rectangle(0, 0, CFG.view.gui_w, CFG.view.gui_h, false);
    draw_set_alpha(1);
}

function ui_draw_title(_y, _scale) {
    var _gw = CFG.view.gui_w;
    var _pink = make_colour_rgb(255, 60, 170);
    var _cyan = make_colour_rgb(45, 226, 230);
    var _gold = make_colour_rgb(255, 210, 63);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text_transformed_colour(_gw * 0.5 + 4, _y + 4, "BRAWLEROGUE", _scale, _scale, 0, c_black, c_black, c_black, c_black, 1);
    draw_text_transformed_colour(_gw * 0.5 - 2, _y, "BRAWLEROGUE", _scale, _scale, 0, _cyan, _cyan, _cyan, _cyan, 0.8);
    draw_text_transformed_colour(_gw * 0.5 + 2, _y, "BRAWLEROGUE", _scale, _scale, 0, _pink, _pink, _pink, _pink, 0.8);
    draw_text_transformed_colour(_gw * 0.5, _y, "BRAWLEROGUE", _scale, _scale, 0, _gold, _gold, c_white, c_white, 1);
    draw_set_valign(fa_top);
}

/// Lista vertical com seta e moldura no item selecionado.
function ui_draw_list(_items, _index, _x, _y, _step, _disabled = undefined) {
    var _gold = make_colour_rgb(255, 210, 63);
    draw_set_halign(fa_center);
    for (var _i = 0; _i < array_length(_items); _i++) {
        var _yy = _y + _i * _step;
        var _off = !is_undefined(_disabled) && _disabled[_i];
        var _col = _off ? make_colour_rgb(100, 104, 130) : c_white;
        if (_i == _index) {
            _col = _off ? make_colour_rgb(150, 150, 170) : _gold;
            draw_set_colour(_col);
            draw_triangle(_x - 150, _yy + 2, _x - 150, _yy + 22, _x - 134, _yy + 12, false);
            draw_rectangle(_x - 124, _yy - 6, _x + 124, _yy + 30, true);
        }
        draw_text_transformed_colour(_x, _yy, _items[_i], 1.5, 1.5, 0, _col, _col, _col, _col, 1);
    }
    draw_set_colour(c_white);
}

function ui_draw() {
    var _ui = global.ui;
    if (_ui.screen == "none") return;
    var _gw = CFG.view.gui_w;
    var _gh = CFG.view.gui_h;
    var _gold = make_colour_rgb(255, 210, 63);
    var _cyan = make_colour_rgb(45, 226, 230);
    var _grey = make_colour_rgb(170, 180, 220);
    var _key = function(_a) { return "[" + input_action_label(_a) + "]"; };

    draw_set_font(-1);
    draw_set_alpha(1);
    draw_set_valign(fa_top);

    switch (_ui.screen) {
        case "splash":
            ui_draw_backdrop(1);
            // fundo: cenario das ruas escurecido, rolando devagar
            draw_sprite_ext(spr_bg_streets, 0, -((_ui.timer * 0.6) mod 200), 0, 2, 2, 0, make_colour_rgb(70, 70, 110), 1);
            ui_draw_backdrop(0.45);
            ui_draw_title(_gh * 0.36, 6);
            draw_set_halign(fa_center);
            hud_text(_gw * 0.5, _gh * 0.36 + 62, "beat 'em up roguelike", _cyan);

            // barra de carregamento
            var _k = clamp(_ui.timer / CFG.ui.splash_frames, 0, 1);
            var _bw = 420;
            var _bx = (_gw - _bw) * 0.5;
            var _by = _gh * 0.72;
            hud_bar(_bx, _by, _bw, 12, _k, make_colour_rgb(255, 60, 170));
            hud_text(_gw * 0.5, _by + 22, "CARREGANDO " + string(floor(_k * 100)) + "%");
            if ((_ui.timer div 20) mod 2 == 0) hud_text(_gw * 0.5, _gh - 46, _key(ACT.JUMP) + " pular", _grey);
            break;

        case "menu":
            ui_draw_backdrop(1);
            draw_sprite_ext(spr_bg_lobby, 0, 0, 0, 2, 2, 0, make_colour_rgb(80, 80, 120), 1);
            ui_draw_backdrop(0.5);
            ui_draw_title(120, 5);
            ui_draw_list(["NOVO JOGO", "CONTINUAR", "SAIR"], _ui.index, _gw * 0.5, 250, 60, [false, !ui_any_save(), false]);
            draw_set_halign(fa_center);
            hud_text(_gw * 0.5, _gh - 40, "[W/S] escolher   " + _key(ACT.INTERACT) + " confirmar", _grey);
            break;

        case "slots":
            ui_draw_backdrop(1);
            draw_sprite_ext(spr_bg_lobby, 0, 0, 0, 2, 2, 0, make_colour_rgb(60, 60, 100), 1);
            ui_draw_backdrop(0.6);
            draw_set_halign(fa_center);
            draw_text_transformed_colour(_gw * 0.5, 50, (_ui.mode == "new") ? "NOVO JOGO - escolha um slot" : "CONTINUAR - escolha um slot", 2, 2, 0, _gold, _gold, _gold, _gold, 1);
            for (var _i = 0; _i < SAVE_SLOTS; _i++) {
                var _info = _ui.slots[_i];
                var _x = 180;
                var _y = 130 + _i * 110;
                var _sel = (_i == _ui.index);
                draw_set_colour(_sel ? make_colour_rgb(44, 50, 96) : make_colour_rgb(20, 24, 52));
                draw_rectangle(_x, _y, _gw - _x, _y + 90, false);
                draw_set_colour(_sel ? _gold : make_colour_rgb(90, 96, 140));
                draw_rectangle(_x, _y, _gw - _x, _y + 90, true);
                if (_sel) {
                    draw_rectangle(_x - 2, _y - 2, _gw - _x + 2, _y + 92, true);
                    draw_triangle(_x - 26, _y + 33, _x - 26, _y + 57, _x - 8, _y + 45, false);
                }
                draw_set_halign(fa_left);
                hud_text(_x + 20, _y + 12, "SLOT " + string(_i + 1), _sel ? _gold : c_white);
                hud_text(_x + 20, _y + 38, _info.line1, _info.used ? c_white : make_colour_rgb(120, 124, 150));
                hud_text(_x + 20, _y + 60, _info.line2, _cyan);
            }
            draw_set_halign(fa_center);
            if (_ui.confirm == "overwrite") {
                hud_text(_gw * 0.5, _gh - 66, "Este slot ja tem um save. Sobrescrever?", make_colour_rgb(255, 90, 90));
                hud_text(_gw * 0.5, _gh - 40, _key(ACT.INTERACT) + " sim   " + _key(ACT.DODGE) + " nao", _gold);
            } else if (_ui.confirm == "delete") {
                hud_text(_gw * 0.5, _gh - 66, "Apagar este save para sempre?", make_colour_rgb(255, 90, 90));
                hud_text(_gw * 0.5, _gh - 40, _key(ACT.INTERACT) + " sim   " + _key(ACT.DODGE) + " nao", _gold);
            } else {
                hud_text(_gw * 0.5, _gh - 40, "[W/S] escolher   " + _key(ACT.INTERACT) + " confirmar   " + _key(ACT.GRAB) + " apagar   " + _key(ACT.DODGE) + " voltar", _grey);
            }
            break;

        case "pause":
            ui_draw_backdrop(0.7);
            draw_set_halign(fa_center);
            draw_text_transformed_colour(_gw * 0.5, 110, "PAUSA", 3, 3, 0, _gold, _gold, _gold, _gold, 1);
            ui_draw_list(ui_pause_items(), _ui.index, _gw * 0.5, 220, 56);
            draw_set_halign(fa_center);
            hud_text(_gw * 0.5, _gh - 70, "Fichas: " + string(global.meta.chips), _cyan);
            hud_text(_gw * 0.5, _gh - 40, "[W/S] escolher   " + _key(ACT.INTERACT) + " confirmar   " + _key(ACT.PAUSE) + " voltar", _grey);
            break;

        case "results":
            var _r = _ui.results;
            ui_draw_backdrop(0.85);
            draw_set_halign(fa_center);
            var _title = "DERROTA";
            var _tcol = make_colour_rgb(255, 60, 90);
            if (_r.result == "victory") {
                _title = "VITORIA";
                _tcol = _gold;
            } else if (_r.result == "abandon") {
                _title = "RUN ABANDONADA";
                _tcol = _grey;
            }
            draw_text_transformed_colour(_gw * 0.5, 50, _title, 3, 3, 0, _tcol, _tcol, _tcol, _tcol, 1);

            var _lines = [
                ["Tempo", time_text(_r.time_frames)],
                ["Chegou ate", _r.biome],
                ["Trechos limpos", string(_r.sections)],
                ["Chefes derrotados", string(_r.bosses)],
                ["Inimigos derrotados", string(_r.kills)],
                ["Dano causado", string(_r.dmg_dealt)],
                ["Dano recebido", string(_r.dmg_taken)],
                ["Moedas nao gastas", string(_r.coins)]
            ];
            var _shown = min(array_length(_lines), _ui.timer div 6); // as linhas entram uma a uma
            for (var _i = 0; _i < _shown; _i++) {
                var _ly = 150 + _i * 30;
                draw_set_halign(fa_right);
                hud_text(_gw * 0.5 - 12, _ly, _lines[_i][0], _grey);
                draw_set_halign(fa_left);
                hud_text(_gw * 0.5 + 12, _ly, _lines[_i][1]);
            }
            draw_set_halign(fa_center);
            if (_ui.timer > 54) {
                draw_text_transformed_colour(_gw * 0.5, 404, "+" + string(_r.chips) + " FICHAS", 2, 2, 0, _cyan, _cyan, _cyan, _cyan, 1);
                hud_text(_gw * 0.5, 444, "Total: " + string(global.meta.chips) + "  -  gaste no saco de pancada do lobby", _grey);
            }
            if (_ui.timer > 40 && (_ui.timer div 20) mod 2 == 0) hud_text(_gw * 0.5, _gh - 40, _key(ACT.INTERACT) + " voltar ao lobby", _gold);
            break;
    }

    if (_ui.message_timer > 0) {
        draw_set_halign(fa_center);
        hud_text(_gw * 0.5, _gh - 96, _ui.message, make_colour_rgb(255, 90, 90));
    }

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
    draw_set_alpha(1);
}
