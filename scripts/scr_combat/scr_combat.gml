/// Hitboxes, dano e reacoes. As hitboxes sao volumes logicos (x, profundidade, altura)
/// independentes da arte e das mascaras de colisao dos sprites.

enum TEAM {
    PLAYER,
    ENEMY
}

enum HITRES {
    IGNORED,  // invulneravel ou fora de alcance logico
    BLOCKED,
    HIT
}

/// Cria a hitbox de um golpe. Ela segue o dono e so acerta cada alvo uma vez.
function hitbox_spawn(_owner, _atk, _dmg_mult = 1) {
    return instance_create_depth(_owner.x, _owner.y, 0, obj_hitbox, {
        owner: _owner.id,
        atk: _atk,
        team: _owner.team,
        facing: _owner.facing,
        life: _atk.active,
        dmg_mult: _dmg_mult
    });
}

/// Remove as hitboxes de um ator (ao ser interrompido, pousar etc.).
function hitbox_clear(_owner_id) {
    with (obj_hitbox) {
        if (owner == _owner_id) instance_destroy();
    }
}

function combat_overlap(_hb, _t) {
    var _a = _hb.atk;
    var _x1, _x2;
    if (_a.both_sides) {
        _x1 = _hb.x - _a.reach;
        _x2 = _hb.x + _a.reach;
    } else if (_hb.facing > 0) {
        _x1 = _hb.x + _a.offset_x;
        _x2 = _x1 + _a.reach;
    } else {
        _x2 = _hb.x - _a.offset_x;
        _x1 = _x2 - _a.reach;
    }
    if (_t.x + _t.body_w < _x1 || _t.x - _t.body_w > _x2) return false;
    if (abs(_t.y - _hb.y) > _a.lane) return false;
    var _zb = _hb.z + _a.z_bottom;
    var _zt = _hb.z + _a.z_top;
    if (_t.z + _t.body_h < _zb || _t.z > _zt) return false;
    return true;
}

/// Verifica os alvos de uma hitbox neste frame. Roda no escopo do obj_hitbox.
function hitbox_check() {
    var _hb = id;
    with (obj_actor) {
        if (team == _hb.team) continue;
        if (array_contains(_hb.hit_list, id)) continue;
        if (!combat_overlap(_hb, id)) continue;
        combat_resolve_hit(_hb, id);
    }
}

function combat_resolve_hit(_hb, _target) {
    var _a = _hb.atk;
    // O alvo entra na lista mesmo se ignorar o golpe: uma esquiva nao pode ser
    // atingida pelo mesmo ataque quando a invulnerabilidade acaba.
    array_push(_hb.hit_list, _target);

    var _dir = _hb.facing;
    if (_a.both_sides) _dir = (_target.x >= _hb.x) ? 1 : -1;

    var _hit = {
        atk: _a,
        damage: _a.damage * _hb.dmg_mult,
        dir: _dir,
        attacker: _hb.owner
    };

    combat_deliver(_target, _hit, _hb.owner);
}

/// Entrega um golpe ao alvo e dispara o feedback (congelamento, faisca, tremor).
/// Usado pelas hitboxes e por golpes diretos (joelhada do agarrao).
function combat_deliver(_target, _hit, _owner) {
    var _res = _target.on_hit(_hit);
    if (_res == HITRES.IGNORED) return _res;

    var _fx_y = _target.y - _target.z - _target.body_h * 0.6;
    if (_res == HITRES.BLOCKED) {
        game_hitstop(2);
        vfx_spark(_target.x - _hit.dir * 6, _fx_y, true);
    } else {
        game_hitstop(_hit.atk.hitstop);
        vfx_spark(_target.x, _fx_y, false);
        cam_shake(_target.team == TEAM.PLAYER ? CFG.feedback.shake_hurt : CFG.feedback.shake_hit);
        if (instance_exists(_owner)) _owner.on_hit_landed(_hit);
    }
    return _res;
}

/// Golpe sem hitbox, aplicado direto em um alvo ja definido.
function combat_direct_hit(_attacker, _target, _atk, _dmg_mult = 1) {
    return combat_deliver(_target, {
        atk: _atk,
        damage: _atk.damage * _dmg_mult,
        dir: _attacker.facing,
        attacker: _attacker.id
    }, _attacker.id);
}

/// Inimigos ainda em combate (mortos aguardando sumir nao contam).
function enemies_alive() {
    var _n = 0;
    with (obj_enemy) {
        if (hp > 0) _n++;
    }
    return _n;
}
