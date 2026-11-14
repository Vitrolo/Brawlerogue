/// Porta na parede do fundo. kind/label/requires_clear vem da definicao da sala.
if (!variable_instance_exists(id, "kind")) kind = "run_start";
if (!variable_instance_exists(id, "label")) label = "ENTRAR";
if (!variable_instance_exists(id, "requires_clear")) requires_clear = false;
if (!variable_instance_exists(id, "target_nid")) target_nid = -1; // no da rota (kind "route")
if (!variable_instance_exists(id, "room_kind")) room_kind = "";   // tipo da sala de destino
locked = false;
near = false;
bob = 0;
depth = -y + 1; // sempre atras de quem esta no chao
