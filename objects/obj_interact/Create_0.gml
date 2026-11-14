/// Objeto interativo das salas: descanso, bau de recompensa, loja, evento ou arma no chao.
/// kind/seed/wid/durability vem de quem cria (interact_spawn_for_stage, weapon_drop).
if (!variable_instance_exists(id, "kind")) kind = "rest";
if (!variable_instance_exists(id, "seed")) seed = 0;
if (!variable_instance_exists(id, "wid")) wid = "";
if (!variable_instance_exists(id, "durability")) durability = 0;
used = false;
stock = undefined; // itens da loja, sorteados na primeira visita
bob = 0;
depth = -y;
