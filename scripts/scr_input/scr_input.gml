/// Entrada por acoes abstratas. O gameplay so consulta ACT.*, nunca teclas ou botoes.
/// Para remapear, altere apenas input_init. Teclado e controle valem ao mesmo tempo.

enum ACT {
    LEFT,
    RIGHT,
    UP,
    DOWN,
    JUMP,
    ATTACK,
    BLOCK,
    DODGE,
    GRAB,
    SPECIAL,
    INTERACT,
    PAUSE,
    COUNT
}

function input_init() {
    global.input = {
        binds: array_create(ACT.COUNT),      // teclas por acao
        pad_binds: array_create(ACT.COUNT),  // botoes de controle por acao
        labels: array_create(ACT.COUNT, "?"),
        held: array_create(ACT.COUNT, false),
        pressed: array_create(ACT.COUNT, false),
        released: array_create(ACT.COUNT, false),
        pad: -1,            // indice do controle em uso (-1 = nenhum)
        pad_deadzone: 0.35
    };

    //          acao          teclas                 botoes do controle          texto na tela
    input_bind(ACT.LEFT,     [ord("A"), vk_left],   [gp_padl],                  "A");
    input_bind(ACT.RIGHT,    [ord("D"), vk_right],  [gp_padr],                  "D");
    input_bind(ACT.UP,       [ord("W"), vk_up],     [gp_padu],                  "W");
    input_bind(ACT.DOWN,     [ord("S"), vk_down],   [gp_padd],                  "S");
    input_bind(ACT.JUMP,     [vk_space],            [gp_face1],                 "ESPACO");
    input_bind(ACT.ATTACK,   [ord("J")],            [gp_face3],                 "J");
    input_bind(ACT.BLOCK,    [ord("K")],            [gp_shoulderr],             "K");
    input_bind(ACT.DODGE,    [ord("L")],            [gp_face2],                 "L");
    input_bind(ACT.GRAB,     [ord("U")],            [gp_face4],                 "U");
    input_bind(ACT.SPECIAL,  [ord("I")],            [gp_shoulderl],             "I");
    input_bind(ACT.INTERACT, [ord("E"), vk_enter],  [gp_shoulderrb],            "E");
    input_bind(ACT.PAUSE,    [vk_escape, ord("P")], [gp_start],                 "ESC");
}

function input_bind(_action, _keys, _pad_buttons, _label) {
    global.input.binds[_action] = _keys;
    global.input.pad_binds[_action] = _pad_buttons;
    global.input.labels[_action] = _label;
}

/// Primeiro controle conectado, ou -1.
function input_find_pad() {
    var _count = gamepad_get_device_count();
    for (var _i = 0; _i < _count; _i++) {
        if (gamepad_is_connected(_i)) return _i;
    }
    return -1;
}

/// Chamado uma vez por frame (Begin Step do obj_game).
function input_update() {
    var _in = global.input;
    if (_in.pad < 0 || !gamepad_is_connected(_in.pad)) _in.pad = input_find_pad();
    var _pad = _in.pad;

    // analogico esquerdo vale como direcional
    var _sx = 0;
    var _sy = 0;
    if (_pad >= 0) {
        _sx = gamepad_axis_value(_pad, gp_axislh);
        _sy = gamepad_axis_value(_pad, gp_axislv);
    }

    for (var _a = 0; _a < ACT.COUNT; _a++) {
        var _down = false;

        var _keys = _in.binds[_a];
        for (var _k = 0; _k < array_length(_keys); _k++) {
            if (keyboard_check(_keys[_k])) {
                _down = true;
                break;
            }
        }

        if (!_down && _pad >= 0) {
            var _btns = _in.pad_binds[_a];
            for (var _k = 0; _k < array_length(_btns); _k++) {
                if (gamepad_button_check(_pad, _btns[_k])) {
                    _down = true;
                    break;
                }
            }
            switch (_a) {
                case ACT.LEFT:  if (_sx < -_in.pad_deadzone) _down = true; break;
                case ACT.RIGHT: if (_sx > _in.pad_deadzone) _down = true; break;
                case ACT.UP:    if (_sy < -_in.pad_deadzone) _down = true; break;
                case ACT.DOWN:  if (_sy > _in.pad_deadzone) _down = true; break;
            }
        }

        _in.pressed[_a] = _down && !_in.held[_a];
        _in.released[_a] = !_down && _in.held[_a];
        _in.held[_a] = _down;
    }
}

function input_held(_action) {
    return global.input.held[_action];
}

function input_pressed(_action) {
    return global.input.pressed[_action];
}

function input_released(_action) {
    return global.input.released[_action];
}

function input_axis_x() {
    return real(input_held(ACT.RIGHT)) - real(input_held(ACT.LEFT));
}

function input_axis_y() {
    return real(input_held(ACT.DOWN)) - real(input_held(ACT.UP));
}

function input_action_label(_action) {
    return global.input.labels[_action];
}
