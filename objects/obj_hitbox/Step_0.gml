if (game_frozen()) exit;
if (!instance_exists(owner)) {
    instance_destroy();
    exit;
}
x = owner.x;
y = owner.y;
z = owner.z;
hitbox_check();
life--;
if (life <= 0) instance_destroy();
