/// Camera: segue o jogador no eixo x, presa aos limites do corredor, da sala ou
/// da arena travada. Nos mapas 2D o eixo y fica na faixa do corredor atual e,
/// na escada, passa suavemente de uma faixa para a outra.

function cam_init() {
    global.cam = {
        cam_id: camera_create_view(0, 0, VIEW_W, VIEW_H),
        x: 0,
        y: 0,
        shake: 0
    };
}

function cam_room_start() {
    view_enabled = true;
    view_visible[0] = true;
    view_camera[0] = global.cam.cam_id;
    view_xport[0] = 0;
    view_yport[0] = 0;
    view_wport[0] = VIEW_W;
    view_hport[0] = VIEW_H;
    if (surface_exists(application_surface)) {
        surface_resize(application_surface, VIEW_W, VIEW_H);
    }
    global.cam.shake = 0;
    global.cam.x = cam_target_x();
    global.cam.y = cam_target_y();
    camera_set_view_pos(global.cam.cam_id, round(global.cam.x), round(global.cam.y));
}

/// Limites [x1, x2] para a camera fora da trava de arena: o corredor indicado
/// nos mapas 2D ou a sala inteira.
function cam_bounds_x(_cor) {
    var _map = level_current_map();
    if (!is_undefined(_map) && _cor >= 0) {
        var _c = _map.corridors[_cor];
        return [_c.x1, _c.x2];
    }
    return [0, global.stage.width];
}

function cam_clamp_x(_tx, _b) {
    return clamp(_tx, _b[0], max(_b[0], _b[1] - VIEW_W));
}

/// Jogador na escada: { low, up, t } com os corredores de baixo e de cima e o
/// avanco (0 no pe, 1 no topo). undefined fora da escada.
function cam_climb_info(_p) {
    if (_p == noone || _p.state != PS.CLIMB || _p.climb_link < 0) return undefined;
    var _map = level_current_map();
    if (is_undefined(_map)) return undefined;
    var _k = _map.links[_p.climb_link];
    return {
        low: _map.chunks[_k.a].corridor,
        up: _map.chunks[_k.b].corridor,
        t: level_smooth(_p.climb_t)
    };
}

function cam_target_x() {
    var _rt = global.stage_rt;
    var _tx = global.cam.x;
    var _p = instance_find(obj_player, 0);
    if (_p != noone) _tx = _p.x - VIEW_W * 0.5;
    if (_rt.lock_active) return cam_clamp_x(_tx, [_rt.lock_x1, _rt.lock_x2]);
    var _climb = cam_climb_info(_p);
    if (!is_undefined(_climb)) {
        // na escada, mistura os limites dos dois corredores conforme a subida
        var _a = cam_clamp_x(_tx, cam_bounds_x(_climb.low));
        var _b = cam_clamp_x(_tx, cam_bounds_x(_climb.up));
        return lerp(_a, _b, _climb.t);
    }
    return cam_clamp_x(_tx, cam_bounds_x(_rt.corridor));
}

function cam_target_y() {
    var _map = level_current_map();
    if (is_undefined(_map)) return 0;
    var _climb = cam_climb_info(instance_find(obj_player, 0));
    if (!is_undefined(_climb)) {
        return lerp(_map.corridors[_climb.low].oy, _map.corridors[_climb.up].oy, _climb.t);
    }
    var _c = stage_corridor();
    return is_undefined(_c) ? 0 : _c.oy;
}

function cam_update() {
    var _c = global.cam;
    _c.x = lerp(_c.x, cam_target_x(), CFG.camera.lerp);
    _c.y = lerp(_c.y, cam_target_y(), CFG.camera.lerp_y);
    if (abs(_c.y - cam_target_y()) < 0.5) _c.y = cam_target_y();
    var _sx = 0;
    var _sy = 0;
    if (_c.shake > 0.3) {
        _sx = irandom_range(-ceil(_c.shake), ceil(_c.shake));
        _sy = irandom_range(-ceil(_c.shake), ceil(_c.shake));
        _c.shake *= CFG.camera.shake_decay;
    } else {
        _c.shake = 0;
    }
    camera_set_view_pos(_c.cam_id, round(_c.x) + _sx, round(_c.y) + _sy);
}

function cam_shake(_amount) {
    global.cam.shake = max(global.cam.shake, _amount);
}

/// Trava a camera e os atores entre _x1 e _x2 (arena de horda).
function cam_lock(_x1, _x2) {
    var _rt = global.stage_rt;
    _rt.lock_active = true;
    _rt.lock_x1 = _x1;
    _rt.lock_x2 = _x2;
}

function cam_unlock() {
    global.stage_rt.lock_active = false;
}
