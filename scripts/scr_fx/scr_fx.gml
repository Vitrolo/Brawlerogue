/// Efeitos visuais leves: particulas, poeira, rastro da esquiva e numeros de dano.
/// Tudo vive em listas de structs em global.fx; nada aqui afeta o gameplay.
/// Particulas e rastros sao desenhados no mundo (Draw do obj_game); os numeros
/// sao desenhados na interface (hud_draw) para o texto ficar legivel.

function fx_init() {
    global.fx = {
        parts: [],   // { x, y, vx, vy, grav, life, life_max, col, size }
        ghosts: [],  // { sprite, frame, x, y, xscale, scale, col, life, life_max }
        nums: []     // { x, y, text, col, life, life_max }
    };
}

function fx_clear() {
    global.fx.parts = [];
    global.fx.ghosts = [];
    global.fx.nums = [];
}

/// Explosao de faiscas: _n particulas saindo de (_x, _y).
function fx_burst(_x, _y, _n, _col, _speed = 2.2, _grav = 0.12) {
    var _list = global.fx.parts;
    if (array_length(_list) > 240) return; // teto de seguranca
    for (var _i = 0; _i < _n; _i++) {
        var _a = random(360);
        var _s = random_range(_speed * 0.4, _speed);
        var _life = irandom_range(10, 20);
        array_push(_list, {
            x: _x, y: _y,
            vx: lengthdir_x(_s, _a),
            vy: lengthdir_y(_s, _a) - 0.6,
            grav: _grav,
            life: _life, life_max: _life,
            col: _col,
            size: choose(1, 1, 2)
        });
    }
}

/// Poeira rasteira (pouso, queda, objeto quebrando).
function fx_dust(_x, _y, _n = 6) {
    var _list = global.fx.parts;
    if (array_length(_list) > 240) return;
    for (var _i = 0; _i < _n; _i++) {
        var _life = irandom_range(12, 22);
        array_push(_list, {
            x: _x + random_range(-6, 6), y: _y - random(2),
            vx: random_range(-1.1, 1.1),
            vy: random_range(-0.5, -0.1),
            grav: -0.01,
            life: _life, life_max: _life,
            col: make_colour_rgb(190, 190, 200),
            size: choose(1, 2, 2)
        });
    }
}

/// Copia fantasma de um ator (rastro da esquiva e do dash).
function fx_ghost(_inst, _col) {
    if (_inst.sprite_index == -1) return;
    array_push(global.fx.ghosts, {
        sprite: _inst.sprite_index,
        frame: _inst.image_index,
        x: round(_inst.x),
        y: round(_inst.y - _inst.z),
        xscale: _inst.facing * _inst.draw_scale,
        scale: _inst.draw_scale,
        col: _col,
        life: 12, life_max: 12
    });
}

/// Numero flutuante em coordenadas do mundo (dano, cura, moedas).
function fx_number(_x, _y, _text, _col) {
    var _list = global.fx.nums;
    if (array_length(_list) > 40) array_delete(_list, 0, 1);
    array_push(_list, {
        x: _x + random_range(-4, 4), y: _y,
        text: string(_text),
        col: _col,
        life: 40, life_max: 40
    });
}

function fx_update() {
    var _p = global.fx.parts;
    for (var _i = array_length(_p) - 1; _i >= 0; _i--) {
        var _f = _p[_i];
        _f.x += _f.vx;
        _f.y += _f.vy;
        _f.vy += _f.grav;
        _f.vx *= 0.94;
        _f.life--;
        if (_f.life <= 0) array_delete(_p, _i, 1);
    }
    var _g = global.fx.ghosts;
    for (var _i = array_length(_g) - 1; _i >= 0; _i--) {
        _g[_i].life--;
        if (_g[_i].life <= 0) array_delete(_g, _i, 1);
    }
    var _n = global.fx.nums;
    for (var _i = array_length(_n) - 1; _i >= 0; _i--) {
        _n[_i].y -= 0.45;
        _n[_i].life--;
        if (_n[_i].life <= 0) array_delete(_n, _i, 1);
    }
}

/// Desenho no mundo (particulas e rastros).
function fx_draw_world() {
    var _g = global.fx.ghosts;
    gpu_set_fog(true, c_white, 0, 0);
    for (var _i = 0; _i < array_length(_g); _i++) {
        var _f = _g[_i];
        draw_sprite_ext(_f.sprite, _f.frame, _f.x, _f.y, _f.xscale, _f.scale, 0, _f.col, 0.45 * _f.life / _f.life_max);
    }
    gpu_set_fog(false, c_white, 0, 0);

    var _p = global.fx.parts;
    for (var _i = 0; _i < array_length(_p); _i++) {
        var _f = _p[_i];
        draw_set_alpha(min(1, 2 * _f.life / _f.life_max));
        draw_set_colour(_f.col);
        draw_rectangle(_f.x, _f.y, _f.x + _f.size - 1, _f.y + _f.size - 1, false);
    }
    draw_set_alpha(1);
    draw_set_colour(c_white);
}

/// Desenho na interface (numeros), convertendo mundo -> GUI.
function fx_draw_gui() {
    var _n = global.fx.nums;
    if (array_length(_n) == 0) return;
    var _sx = CFG.view.gui_w / VIEW_W;
    var _sy = CFG.view.gui_h / VIEW_H;
    var _camx = round(global.cam.x);
    var _camy = round(global.cam.y);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    for (var _i = 0; _i < array_length(_n); _i++) {
        var _f = _n[_i];
        var _gx = (_f.x - _camx) * _sx;
        var _gy = (_f.y - _camy) * _sy;
        draw_set_alpha(min(1, 3 * _f.life / _f.life_max));
        draw_set_colour(c_black);
        draw_text(_gx + 1, _gy + 1, _f.text);
        draw_set_colour(_f.col);
        draw_text(_gx, _gy, _f.text);
    }
    draw_set_alpha(1);
    draw_set_colour(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}
