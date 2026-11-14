/// Base comum de jogador e inimigos.
/// Convencao de espaco: x = horizontal, y = profundidade no chao (posicao dos pes),
/// z = altura acima do chao (positivo para cima). O sprite e desenhado em (x, y - z)
/// com origem nos pes; a ordenacao usa apenas y.

function actor_init(_hp_max, _body_w, _body_h) {
    z = 0;
    vz = 0;
    vx = 0;
    vy = 0;
    facing = 1;
    hp_max = _hp_max;
    hp = _hp_max;
    body_w = _body_w;
    body_h = _body_h;
    state = 0;
    state_timer = 0;
    flash = 0;
    invuln = 0;
    team = TEAM.ENEMY;
    image_speed = 0;
    draw_scale = 1;
    // Substituidos por jogador/inimigo.
    on_hit = function(_hit) { return HITRES.IGNORED; };
    on_hit_landed = function(_hit) {};
}

function actor_set_state(_state) {
    state = _state;
    state_timer = 0;
}

/// Aplica velocidade, gravidade e limites da sala. Retorna true no frame em que pousa.
function actor_physics() {
    var _landed = false;
    x += vx;
    y += vy;
    if (z > 0 || vz > 0) {
        z += vz;
        vz -= CFG.physics.gravity;
        if (z <= 0) {
            z = 0;
            vz = 0;
            _landed = true;
        }
    }
    x = clamp(x, stage_x1() + body_w, stage_x2() - body_w);
    y = clamp(y, global.stage.floor_top, global.stage.floor_bottom);
    return _landed;
}

function actor_on_ground() {
    return z <= 0 && vz <= 0;
}

function actor_anim(_sprite, _frame) {
    sprite_index = _sprite;
    image_index = _frame;
}

function actor_draw() {
    // sombra no ponto de contato com o chao
    var _s = max(0.4, 1 - z / 120) * draw_scale;
    draw_set_alpha(0.35);
    draw_set_colour(c_black);
    draw_ellipse(x - 11 * _s, y - 3 * _s, x + 11 * _s, y + 3 * _s, false);
    draw_set_alpha(1);
    draw_set_colour(c_white);

    if (sprite_index == -1) return;

    var _alpha = 1;
    if (invuln > 0 && (invuln div 3) mod 2 == 0) _alpha = 0.4; // pisca enquanto invulneravel
    if (flash > 0) gpu_set_fog(true, c_white, 0, 0);            // clarao branco ao levar golpe
    draw_sprite_ext(sprite_index, image_index, round(x), round(y - z), facing * draw_scale, draw_scale, 0, c_white, _alpha);
    if (flash > 0) gpu_set_fog(false, c_white, 0, 0);
}
