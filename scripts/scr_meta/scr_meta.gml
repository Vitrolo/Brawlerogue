/// Progresso permanente (meta-progressao), personagens jogaveis e slots de save.
///
/// global.meta guarda o que sobrevive entre runs: fichas, melhorias compradas no
/// lobby, personagens liberados e totais. Cada slot e um arquivo JSON
/// (save_slot_N.json na pasta de dados do jogo) com { meta, run }. "run" so existe
/// quando ha uma run em andamento; ela e gravada nos pontos de controle
/// (inicio da run, trecho limpo, chefe derrotado) e retomada pelo CONTINUAR.

#macro SAVE_SLOTS 3
#macro SAVE_VERSION 1

// ------------------------------------------------------------ personagens

function chars_init() {
    global.chars = {};
    global.char_order = ["brawler", "striker"];

    global.chars[$ "brawler"] = {
        cid: "brawler",
        name: "RUBI",
        desc: "Equilibrada. Combo de 3 golpes e giro que acerta dos dois lados.",
        unlock_cost: 0,
        hp_bonus: 0,
        speed_bonus: 0,
        combo: ["punch1", "punch2", "kick"],
        air_attack: "air_kick",
        special: "special_spin",
        dodge_attack: "dodge_strike",
        sprites: {
            idle: spr_player_idle, walk: spr_player_walk, jump: spr_player_jump,
            fall: spr_player_fall, land: spr_player_land, dodge: spr_player_dodge,
            block: spr_player_block, hurt: spr_player_hurt, knockdown: spr_player_knockdown,
            getup: spr_player_getup, dead: spr_player_dead,
            grab: spr_player_grab, knee: spr_player_attack3, throw_spr: spr_player_throw
        }
    };

    global.chars[$ "striker"] = {
        cid: "striker",
        name: "SAFIRA",
        desc: "Rapida e fragil. Combo de 4 golpes curtos e investida que atravessa a horda.",
        unlock_cost: 40,
        hp_bonus: -20,
        speed_bonus: 0.15,
        combo: ["s_jab1", "s_jab2", "s_jab3", "s_kick"],
        air_attack: "s_air",
        special: "s_rush",
        dodge_attack: "dodge_strike",
        sprites: {
            idle: spr_p2_idle, walk: spr_p2_walk, jump: spr_p2_jump,
            fall: spr_p2_fall, land: spr_p2_land, dodge: spr_p2_dodge,
            block: spr_p2_block, hurt: spr_p2_hurt, knockdown: spr_p2_knockdown,
            getup: spr_p2_getup, dead: spr_p2_dead,
            grab: spr_p2_grab, knee: spr_p2_attack3, throw_spr: spr_p2_throw
        }
    };
}

/// Personagem em uso (o da run em andamento, ou o escolhido no lobby).
function player_char() {
    var _cid = global.meta.char;
    // global.run ainda nao existe na primeira chamada (run_reset dentro de game_init)
    if (variable_global_exists("run") && global.run.active && variable_struct_exists(global.run, "char")) _cid = global.run.char;
    if (!variable_struct_exists(global.chars, _cid)) _cid = "brawler";
    return global.chars[$ _cid];
}

// -------------------------------------------------------------- melhorias

/// Melhorias permanentes compradas com fichas no lobby.
function meta_upgrades_init() {
    global.meta_upgrades = [
        { key: "vigor",   name: "Vigor",    desc: "+10 de vida maxima por nivel.",           max_level: 5, base_cost: 10 },
        { key: "power",   name: "Forca",    desc: "+5% de dano por nivel.",                  max_level: 5, base_cost: 12 },
        { key: "focus",   name: "Foco",     desc: "Especial enche 15% mais rapido por nivel.", max_level: 3, base_cost: 12 },
        { key: "pockets", name: "Bolsos",   desc: "Comeca a run com +10 moedas por nivel.",  max_level: 3, base_cost: 8 },
        { key: "arsenal", name: "Arsenal",  desc: "Nivel 1: comeca com Cano. Nivel 2: comeca com Taco.", max_level: 2, base_cost: 25 }
    ];
}

function meta_level(_key) {
    if (!variable_struct_exists(global.meta.upgrades, _key)) return 0;
    return global.meta.upgrades[$ _key];
}

function meta_upgrade_cost(_up) {
    return _up.base_cost * (meta_level(_up.key) + 1);
}

function meta_default() {
    return {
        version: SAVE_VERSION,
        slot: -1,
        chips: 0,
        upgrades: { vigor: 0, power: 0, focus: 0, pockets: 0, arsenal: 0 },
        chars: ["brawler"],
        char: "brawler",
        totals: { runs: 0, wins: 0, kills: 0, best_time: 0 }
    };
}

function meta_init() {
    chars_init();
    meta_upgrades_init();
    global.meta = meta_default();
}

/// Opcoes da tela de melhorias (saco de pancada no lobby).
function meta_shop_options() {
    var _opts = [];
    for (var _i = 0; _i < array_length(global.meta_upgrades); _i++) {
        var _up = global.meta_upgrades[_i];
        var _lv = meta_level(_up.key);
        if (_lv >= _up.max_level) {
            array_push(_opts, { label: _up.name + " MAX", desc: _up.desc, cost: 0, currency: "chips", effects: [{ type: "none" }], disabled: true });
        } else {
            array_push(_opts, {
                label: _up.name + " " + string(_lv) + "/" + string(_up.max_level),
                desc: _up.desc,
                cost: meta_upgrade_cost(_up),
                currency: "chips",
                effects: [{ type: "meta_upgrade", key: _up.key }]
            });
        }
    }
    return _opts;
}

/// Opcoes do armario (trocar ou liberar personagem).
function meta_char_options() {
    var _opts = [];
    for (var _i = 0; _i < array_length(global.char_order); _i++) {
        var _c = global.chars[$ global.char_order[_i]];
        var _owned = array_contains(global.meta.chars, _c.cid);
        var _current = (global.meta.char == _c.cid);
        if (_owned) {
            array_push(_opts, {
                label: _c.name + (_current ? " (em uso)" : ""),
                desc: _c.desc,
                cost: 0,
                currency: "chips",
                effects: [{ type: "set_char", cid: _c.cid }]
            });
        } else {
            array_push(_opts, {
                label: _c.name + " (bloqueada)",
                desc: _c.desc,
                cost: _c.unlock_cost,
                currency: "chips",
                effects: [{ type: "unlock_char", cid: _c.cid }]
            });
        }
    }
    return _opts;
}

// ------------------------------------------------------------------ saves

function save_filename(_slot) {
    return "save_slot_" + string(_slot + 1) + ".json";
}

function save_exists(_slot) {
    return file_exists(save_filename(_slot));
}

/// json_parse devolve "null" como ponteiro; o jogo usa undefined. Corrige em profundidade.
function save_fix_nulls(_v) {
    if (is_struct(_v)) {
        var _names = variable_struct_get_names(_v);
        for (var _i = 0; _i < array_length(_names); _i++) {
            var _c = _v[$ _names[_i]];
            if (is_ptr(_c)) {
                _v[$ _names[_i]] = undefined;
            } else if (is_struct(_c) || is_array(_c)) {
                save_fix_nulls(_c);
            }
        }
    } else if (is_array(_v)) {
        for (var _i = 0; _i < array_length(_v); _i++) {
            var _c = _v[_i];
            if (is_ptr(_c)) {
                _v[_i] = undefined;
            } else if (is_struct(_c) || is_array(_c)) {
                save_fix_nulls(_c);
            }
        }
    }
    return _v;
}

/// Le um slot. Retorna { meta, run } ou undefined se nao existir ou estiver corrompido.
function save_read(_slot) {
    var _fn = save_filename(_slot);
    if (!file_exists(_fn)) return undefined;
    var _data = undefined;
    try {
        var _b = buffer_load(_fn);
        var _s = buffer_read(_b, buffer_text);
        buffer_delete(_b);
        _data = json_parse(_s);
    } catch (_err) {
        return undefined;
    }
    if (!is_struct(_data) || !variable_struct_exists(_data, "meta") || !is_struct(_data.meta)) return undefined;
    save_fix_nulls(_data);
    if (!variable_struct_exists(_data, "run")) _data.run = undefined;

    // completa campos que versoes antigas do save nao tinham
    var _def = meta_default();
    var _names = variable_struct_get_names(_def);
    for (var _i = 0; _i < array_length(_names); _i++) {
        if (!variable_struct_exists(_data.meta, _names[_i])) _data.meta[$ _names[_i]] = _def[$ _names[_i]];
    }
    return _data;
}

/// Grava o slot atual: progresso permanente e, se houver, a run em andamento.
function save_write() {
    var _slot = global.meta.slot;
    if (_slot < 0) return;
    var _run = undefined;
    if (global.run.active && global.flow.state != FLOW.DEFEAT && global.flow.state != FLOW.VICTORY) _run = global.run;
    var _s = json_stringify({ meta: global.meta, run: _run });
    var _b = buffer_create(string_byte_length(_s), buffer_fixed, 1);
    buffer_write(_b, buffer_text, _s);
    buffer_save(_b, save_filename(_slot));
    buffer_delete(_b);
}

function save_delete(_slot) {
    if (file_exists(save_filename(_slot))) file_delete(save_filename(_slot));
}

/// Resumo de cada slot para a tela de saves.
function save_slot_infos() {
    var _infos = [];
    for (var _i = 0; _i < SAVE_SLOTS; _i++) {
        var _d = save_read(_i);
        if (is_undefined(_d)) {
            array_push(_infos, { used: false, line1: "VAZIO", line2: "" });
            continue;
        }
        var _m = _d.meta;
        var _cname = variable_struct_exists(global.chars, _m.char) ? global.chars[$ _m.char].name : "?";
        var _l1 = _cname + "   Fichas: " + string(_m.chips) + "   Runs: " + string(_m.totals.runs) + "   Vitorias: " + string(_m.totals.wins);
        var _l2 = "No lobby";
        if (is_struct(_d.run) && _d.run.active) {
            var _mi = clamp(_d.run.map_index, 0, array_length(global.biomes) - 1);
            _l2 = run_save_compatible(_d.run)
                ? "Run em andamento: " + global.biomes[_mi].name
                : "Run antiga (mapa no formato anterior): sera descartada";
        }
        array_push(_infos, { used: true, line1: _l1, line2: _l2 });
    }
    return _infos;
}

/// Comeca um save novo no slot e vai para o lobby.
function save_new_game(_slot) {
    global.meta = meta_default();
    global.meta.slot = _slot;
    run_reset();
    save_write();
    stage_goto("lobby");
}

/// Carrega o slot. Se havia uma run em andamento, volta ao ultimo ponto de controle.
function save_continue(_slot) {
    var _d = save_read(_slot);
    if (is_undefined(_d)) return false;
    global.meta = _d.meta;
    global.meta.slot = _slot;
    run_reset();
    if (is_struct(_d.run) && _d.run.active) {
        if (run_save_compatible(_d.run)) {
            run_resume(_d.run);
            return true;
        }
        // run salva antes dos mapas 2D: o progresso permanente fica, a run nao
        save_write();
        toast_show("Run antiga descartada: o formato dos mapas mudou.");
    }
    stage_goto("lobby");
    return true;
}

// ---------------------------------------------------------- fim da run

/// Fecha a contabilidade da run: fichas ganhas e totais. Retorna o resumo mostrado
/// na tela de resultados.
function meta_finish_run(_result) {
    var _run = global.run;
    var _R = CFG.meta;
    var _chips = _run.kills * _R.chips_per_kill
        + _run.sections_cleared * _R.chips_per_section
        + _run.bosses_killed * _R.chips_per_boss
        + ((_result == "victory") ? _R.chips_victory : 0);
    _chips = floor(_chips);

    var _m = global.meta;
    _m.chips += _chips;
    _m.totals.runs += 1;
    _m.totals.kills += _run.kills;
    if (_result == "victory") {
        _m.totals.wins += 1;
        if (_m.totals.best_time == 0 || _run.time_frames < _m.totals.best_time) _m.totals.best_time = _run.time_frames;
    }

    var _mi = clamp(_run.map_index, 0, array_length(global.biomes) - 1);
    return {
        result: _result,
        chips: _chips,
        time_frames: _run.time_frames,
        kills: _run.kills,
        dmg_dealt: round(_run.dmg_dealt),
        dmg_taken: round(_run.dmg_taken),
        sections: _run.sections_cleared,
        bosses: _run.bosses_killed,
        coins: _run.coins,
        biome: global.biomes[_mi].name,
        seed: _run.seed
    };
}

function time_text(_frames) {
    var _secs = _frames div 60;
    var _ss = string(_secs mod 60);
    if (string_length(_ss) < 2) _ss = "0" + _ss;
    return string(_secs div 60) + ":" + _ss;
}
