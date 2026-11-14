/// Objeto interativo das salas: descanso, bau de recompensa, loja, evento ou arma no chao.
/// kind/seed/wid/durability vem de quem cria (interact_spawn_for_stage, weapon_drop).
if (!variable_instance_exists(id, "kind")) kind = "rest";
if (!variable_instance_exists(id, "seed")) seed = 0;
if (!variable_instance_exists(id, "wid")) wid = "";
if (!variable_instance_exists(id, "durability")) durability = 0;
if (!variable_instance_exists(id, "used")) used = false;
if (!variable_instance_exists(id, "stock")) stock = undefined; // estoque preservado entre visitas
if (!variable_instance_exists(id, "persistence_key")) persistence_key = "";
if (!variable_instance_exists(id, "map_index")) map_index = -1;
if (!variable_instance_exists(id, "drop_key")) drop_key = "";
bob = 0;
depth = -y;
