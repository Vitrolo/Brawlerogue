/// Camera lateral: segue o jogador no eixo x, presa aos limites da sala
/// ou da arena travada.

function cam_init() {
    global.cam = {
        cam_id: camera_create_view(0, 0, VIEW_W, VIEW_H),
        x: 0,
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
    camera_set_view_pos(global.cam.cam_id, round(global.cam.x), 0);
}

function cam_target_x() {
    var _rt = global.stage_rt;
    var _x1 = _rt.lock_active ? _rt.lock_x1 : 0;
    var _x2 = _rt.lock_active ? _rt.lock_x2 : global.stage.width;
    var _tx = global.cam.x;
    var _p = instance_find(obj_player, 0);
    if (_p != noone) {
        _tx = _p.x - VIEW_W * 0.5;
    }
    return clamp(_tx, _x1, max(_x1, _x2 - VIEW_W));
}

function cam_update() {
    var _c = global.cam;
    _c.x = lerp(_c.x, cam_target_x(), CFG.camera.lerp);
    var _sx = 0;
    var _sy = 0;
    if (_c.shake > 0.3) {
        _sx = irandom_range(-ceil(_c.shake), ceil(_c.shake));
        _sy = irandom_range(-ceil(_c.shake), ceil(_c.shake));
        _c.shake *= CFG.camera.shake_decay;
    } else {
        _c.shake = 0;
    }
    camera_set_view_pos(_c.cam_id, round(_c.x) + _sx, _sy);
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
