# Brawlerogue

Beat 'em up roguelike single-player em GameMaker LTS 2026 (runtime 2026.0.0.23).

Estado atual: a run vai do lobby por três mapas (esgoto, ruas e telhados). Cada mapa é uma rede 2D gerada pela seed: um corredor principal do início ao chefe e, acima e abaixo dele, corredores ligados por escadas percorríveis, com becos, hordas e salas de tesouro, desafio, loja e descanso no próprio corredor. A geração, os testes e a arte nova estão descritos em [docs/geracao_2d.md](docs/geracao_2d.md).

## Como abrir e jogar

1. Abra `Brawlerogue.yyp` no GameMaker LTS 2026.
2. Rode com F5 (alvo Windows, VM).
3. No lobby, ande até a porta e aperte `E` para iniciar a run.
4. Avance pelo corredor principal; as hordas trancam o trecho até todos os inimigos serem derrotados.
5. As setas ciano marcam escadas: no pé, encostado na parede, segure `W` para subir; no topo, na beirada da frente, segure `S` para descer. Os ramos levam a becos (arma e caixas), hordas (baú ao vencer) e salas de tesouro, desafio, loja e descanso, que ficam no próprio corredor (ícone pulsante acima do objeto).
6. Derrote o chefe no fim do corredor principal para seguir ao próximo bioma. Vencer o chefe do último mapa encerra a run. Segure `TAB` para ver o mapa inteiro do bioma.

## Controles

O mapeamento fica todo em `scripts/scr_input` (`input_init`). Teclado e controle funcionam ao mesmo tempo. O mapeamento de controle é inicial e ainda não foi testado com um controle real.

| Ação | Teclado | Controle (layout Xbox) |
| --- | --- | --- |
| Mover (horizontal e profundidade) | W A S D ou setas | analógico esquerdo ou direcional |
| Correr (segurar enquanto anda) | Shift | clicar o analógico esquerdo (segurar) |
| Pular | Espaço | A |
| Atacar / combo de 3 golpes / chute aéreo no pulo | J | X |
| Bloquear (segurar) | K | RB |
| Esquivar | L | B |
| Agarrar; de novo para arremessar | U | Y |
| Especial (gasta 50 de energia) | I | LB |
| Interagir (baús, loja, descanso, desafio, armas no chão) | E ou Enter | RT |
| Subir / descer escada (no pé ou no topo) | segurar W / S, ou E | direcional, ou RT |
| Mapa inteiro do bioma (segurar) | TAB | Select |

Regras de combate:

- **Combo:** três golpes; o terceiro derruba. Um comando fica guardado por 8 frames.
- **Bloqueio:** reduz o dano a 20% apenas para golpes vindos da frente e nunca deixa a vida abaixo de 1. Golpes não bloqueáveis (slam do chefe) passam.
- **Esquiva:** invulnerável entre os frames 2 e 13 de 18; pode cancelar a recuperação de um golpe.
- **Agarrão:** pega o inimigo mais próximo à frente. Segurando, `J` dá até 3 joelhadas e `U` arremessa na direção segurada (ou para frente). O inimigo arremessado derruba outros no caminho e leva dano ao cair. Sem comando, solta após 80 frames; levar um golpe também solta. Brutos e o chefe não podem ser agarrados.
- **Especial:** enche ao acertar (+8) e ao apanhar (+5); é invulnerável enquanto dura.
- **Dano recebido:** 45 frames de invulnerabilidade depois (a personagem pisca).

A tabela do que cada estado da personagem permite está em `player_states_init` (`scripts/scr_player`).

## Inimigos

Comportamento fixo por tipo; os números ficam em `CFG.enemies`. No máximo 2 inimigos atacam ao mesmo tempo, todo ataque é avisado com "!" e ninguém ataca de fora da tela.

| Tipo | Papel | Aviso | Golpe |
| --- | --- | --- | --- |
| Capanga | corpo a corpo básico | 28 frames | soco, 8 de dano |
| Corredor | frágil e rápido, espera mais longe e volta a atacar logo | 20 frames | jab, 5 de dano |
| Bruto | lento e resistente, não pode ser agarrado | 42 frames | pancada que derruba, 14 de dano |

O esgoto usa quase só capangas, as ruas misturam corredores e alguns brutos, e os telhados têm os três.

## Chefe final

A lógica fica em `scripts/scr_boss` e os números em `CFG.enemies.boss` (listas de dois valores são fase 1 e fase 2). O chefe usa o `obj_enemy` com `ai: "boss"`.

| Padrão | Aviso | Como evitar |
| --- | --- | --- |
| Swipe (2 golpes; 3 na fase 2) | "!" e pose por 30 frames | recuar, bloquear ou esquivar |
| Dash | faixa vermelha no chão por 42 frames | sair da faixa em profundidade ou esquivar |
| Slam | círculo no ponto de queda durante o salto | sair do círculo ou pular no impacto; não pode ser bloqueado |

- Depois de cada padrão há uma recuperação de 50 a 70 frames para contra-atacar.
- Durante avisos e golpes o chefe leva dano mas não é interrompido; após 3 golpes seguidos fora disso, ele revida.
- Com metade da vida entra na fase 2: fica invulnerável por 80 frames, chama dois capangas, encurta os avisos e repete dash e slam.
- A barra de vida central mostra a fase e uma marca no ponto da troca.
- O mesmo chefe aparece no fim do corredor principal de cada mapa. Ao vencer, a run segue para o próximo bioma; após o último chefe, aparece "VITORIA" e o jogo volta ao lobby.

## Recompensas, armas e salas especiais

Tudo abaixo vive em `global.run` e some ao fim da run. As definições ficam em `scripts/scr_modifiers` (`mods_init`); os valores gerais em `CFG.rewards`.

- **Cura** (Lanche 30, Marmita 60): imediata, limitada à vida máxima.
- **Vida máxima** (Colete): +20 de vida máxima e cura os mesmos 20.
- **Velocidade** (Tênis leves): +12% por unidade, acumulável, com teto de 160%.
- **Passivas** (não acumulam): +20% de dano, -20% de dano recebido, cura 3 por inimigo derrotado, especial 50% mais rápido.
- **Armas** (Cano, Taco): `J` passa a dar um golpe único da arma no lugar do combo. Cada acerto gasta 1 de durabilidade; em 0 a arma quebra. Se a personagem for derrubada, a arma cai no chão e pode ser pega de novo. Algumas salas de combate têm uma arma no chão.
- **Moedas**: 5 por inimigo derrotado, usadas só na loja.

Salas especiais (células do próprio corredor, com o objeto da sala no meio):

- **Descanso**: cura 30% da vida máxima, uma vez.
- **Recompensa**: escolha 1 entre 3.
- **Loja**: Marmita e até 3 itens sorteados, pagos com moedas; `L` sai.
- **Desafio**: por enquanto usa o evento existente, com uma escolha de risco/recompensa.

Na tela de escolha: `A`/`D` selecionam, `E` confirma. As ofertas de cada sala são fixas para a mesma seed.

## Run e mapas

Detalhes, diagramas e testes em [docs/geracao_2d.md](docs/geracao_2d.md).

- `run_maps_build` gera um nível 2D por bioma com a seed da run (`level_build` em `scripts/scr_level_gen`) e o preenche com os módulos de `scripts/scr_rooms` (`run_level_fill` em `scripts/scr_route`).
- O nível é uma grade de células de 768×270 (um tile do cenário por uma tela) e um grafo de ligações: passagem na mesma linha e escada entre linhas vizinhas. A validação confere que tudo é alcançável a partir do início, inclusive o chefe; se falhar 12 vezes, entra um nível linear.
- Tipos de célula: início, corredor, escada, combate, saída, horda, beco, chefe e as salas (loja, tesouro, descanso, desafio). As salas são células do corredor, sem porta: o objeto da sala fica no meio delas e o desafio trava a própria célula como arena.
- Cada faixa do mundo é uma tela de altura. O corredor do jogador define os limites de movimento, o chão e a câmera; na escada, a câmera passa de uma faixa para a outra sem trocar de room.
- O combate de cada célula dispara quando o jogador entra nela, de qualquer lado, e trava a câmera e as escadas até a última onda.
- O estado das células (combate, descoberta), dos itens no chão e das salas especiais fica em `global.run` e vai para o save. Runs salvas antes dos mapas 2D são descartadas ao continuar; o progresso permanente fica.
- O minimapa (canto e TAB) desenha a própria grade do nível, com névoa: visitado, conhecido (`?`) e desconhecido.
- Os mapas e as salas especiais usam o mesmo room do GameMaker como casca (`RM_STAGE`, hoje `rm_sandbox`), com largura e altura calculadas.
- F2 (com `CFG.debug.level_overlay_key`) mostra os limites das células, os gatilhos, as salas e as zonas das escadas.

## Como expandir

- **Tipo de célula novo (mapas 2D):** uma linha `chunk_type_define` em `chunk_types_init` (`scripts/scr_level_gen`) com categoria e aberturas, a regra de onde ele aparece em `level_generate` e o conteúdo dele em `run_level_fill` (`scripts/scr_route`). Rode `node tools/level_sim/level_sim.js` para conferir conectividade, coordenadas e alcance em centenas de seeds.
- **Formato do mapa:** tamanhos, número de ramos, profundidade, chances e limites ficam em `CFG.level` (`scripts/scr_config`).
- **Sala nova:** em `rooms_init`, uma linha `room_combat(id, bioma, nome, papel, largura, ondas)` ou `room_special(id, bioma, nome, tipo)`. Cada inimigo de uma onda é `[x, y]` (capanga) ou `[x, y, "tipo"]`; as posições precisam ficar dentro da arena (x de 125 até largura - 15, y de 178 a 258). Para uma arma no chão, `room_pickup(id, arma, x, y)`.
- **Inimigo novo:** um bloco em `config_enemies_init` copiando o do capanga, um golpe com `attack_define` e os sprites `idle`, `walk`, `telegraph`, `attack` (3 frames), `hurt`, `knockdown`, `getup`, `dead`. Um comportamento diferente pede um novo valor de `ai` e o desvio em `enemy_step`, como o chefe faz.
- **Bioma novo:** um item em `global.biomes` (id, nome, paleta), uma imagem `spr_bg_<bioma>` e módulos suficientes para papéis `start`, `mid` e `exit`, além de recompensa, evento/desafio, loja e descanso. Os mapas são percorridos na ordem da lista.
- **Modificador novo:** um `mod_define` usando um `stat` de `run_base_stats()` e a inclusão do id em `global.reward_pool`. Para um efeito inédito, crie o stat em `run_base_stats()` e consulte `global.run.stats` no ponto em que ele age.
- **Arma nova:** um item em `CFG.weapons`, um golpe com `attack_define` e um `mod_define` de categoria `weapon`.
- **Golpe novo:** `attack_define(nome, campos)`; os padrões e o significado de cada campo estão no topo de `scr_config`.
- **Controle e remapeamento:** só `input_init`; o resto do jogo consulta `ACT.*`.
- **Arte:** os sprites vêm de `tools/pixellab_raw` e são montados por `python tools/import_pixellab.py`, que define quais quadros de cada animação viram cada sprite, encosta a figura no chão e põe a origem nos pés. Para trocar um personagem, substitua os PNGs em `tools/pixellab_raw/<personagem>` e rode o importador. Se mudar o número de quadros de idle/walk, ajuste o `mod` em `player_animate`, `scr_enemy` e `scr_boss`. Cenários: um `spr_bg_<bioma>` de 768x272 por bioma; as linhas do chão de cada imagem ficam em `stage_backdrop_info` (`scripts/scr_backdrop`). Objetos (baú, banca, banco, boneco de treino, barril, caixa, lixeira, carro, armas no chão) vêm de `tools/pixellab_raw/v2` e são montados por `python tools/import_v2_art.py`; o objeto de cada sala fica no meio da célula da sala, no próprio corredor. Escadas, paredes de fim de corredor e lajes dos mapas 2D vêm de `tools/pixellab_raw/v3` e são montadas por `python tools/import_v3_level_art.py`, que encaixa as cores na paleta do cenário do bioma e imprime o deslocamento de cada escada (vai em `stage_stairs_run`). `python tools/mock_level.py saida.png` monta uma prévia de duas faixas com escada.

## Estrutura

- `scripts/scr_config` — todo o balanceamento (`CFG`): jogador, golpes, inimigos, chefe, horda, run, recompensas, câmera.
- `scripts/scr_input` — ações abstratas (`ACT.*`), teclas e botões.
- `scripts/scr_run_state` — estado temporário da run (`global.run`), início, fim e reset.
- `scripts/scr_stage` — montagem dos mapas e salas especiais, encontros, travas de horda e limites.
- `scripts/scr_rooms` — biomas e módulos de sala.
- `scripts/scr_level_gen` — tipos de célula, geração e validação dos níveis 2D (só dados; testado por `tools/level_sim`).
- `scripts/scr_level` — nível 2D em jogo: corredor e faixa do jogador, chão, escadas, descoberta e desenho de depuração (F2).
- `scripts/scr_route` — preenchimento dos mapas por bioma (ondas, salas, escadas, objetos), seleção de módulos e estado das salas opcionais.
- `scripts/scr_backdrop` — desenha o cenário de cada faixa, paredes de fim de corredor, lajes e escadas.
- `scripts/scr_minimap` — minimapa e mapa expandido da grade 2D.
- `scripts/scr_modifiers` — recompensas, stats da run, armas, moedas e avisos.
- `scripts/scr_choice` — tela de escolha, efeitos das opções e objetos interativos (`obj_interact`).
- `scripts/scr_camera` — câmera lateral, limites e trava de arena.
- `scripts/scr_actor` — base de jogador e inimigos: x, profundidade (y dos pés), altura (z), sombra, ordenação.
- `scripts/scr_combat` — hitboxes lógicas, entrega de dano e feedback, times.
- `scripts/scr_player` — máquina de estados do jogador, agarrão e arremesso.
- `scripts/scr_enemy` — IA do inimigo comum com fichas de ataque e aviso antes do golpe.
- `scripts/scr_boss` — chefe final: padrões, avisos, fases e desenho dos indicadores.
- `scripts/scr_game` — inicialização, fluxo de derrota e vitória, congelamento de impacto, efeitos, HUD.
- `objects/` — eventos finos que chamam os scripts. `obj_game` é persistente e nasce em `rm_boot`.
- `rooms/` — `rm_boot`, `rm_lobby`, `rm_sandbox`. Os rooms são cascas vazias; o conteúdo vem dos dados.
- `tools/gen_project.py` — gerou os `.yy`, o `.yyp` e os sprites placeholder iniciais. Não rode mais o script inteiro nem `gen_sprites`: ele sobrescreve o `.yyp` e troca a arte atual pelos bonecos de blocos.
- `tools/import_pixellab.py`, `tools/import_v2_art.py`, `tools/import_v3_level_art.py` e `tools/pngio.py` — importam personagens, cenários, objetos e as peças dos mapas 2D.
- `tools/level_sim/level_sim.js` — testes do gerador e do preenchimento dos mapas 2D (Node): roda o GML real em centenas de seeds.

## Novidades desta versão (ainda não testadas em jogo)

Tudo abaixo foi escrito sem compilar: o GameMaker por linha de comando não roda sem licença nesta máquina. `python tools/check_project.py` confere nomes de funções, sprites, objetos e chaves, mas não substitui rodar com F5.

- **Splash e menu:** o jogo abre em uma tela de carregamento (ESPAÇO pula) e depois no menu com NOVO JOGO, CONTINUAR e SAIR (`scripts/scr_menu`).
- **Saves:** 3 slots (`save_slot_N.json` na pasta de dados do jogo). Guardam o progresso permanente e a run em andamento, gravada ao iniciar a run, ao limpar um trecho e ao derrotar um chefe. Na tela de slots, `U` apaga (`scripts/scr_meta`).
- **Pausa:** `ESC` ou `P` (Start no controle). Permite abandonar a run ou voltar ao menu.
- **Fim de run:** tela de resultados com tempo, abates, dano e fichas ganhas.
- **Meta-progressão:** fichas compram melhorias permanentes no saco de pancada do lobby; o armário troca de personagem. Números em `CFG.meta` e `meta_upgrades_init`.
- **Segunda personagem:** Safira (40 fichas), mais rápida e frágil, combo de 4 golpes e especial de investida. Os sprites são a Rubi com outras cores.
- **Inimigos novos:** Atirador (tiro à distância), Escudeiro (bloqueia pela frente; agarre, acerte por trás ou use especial/arremesso/taco) e Homem-bomba (explode ao atacar e ao morrer, ferindo também inimigos). Entram nas ondas por sorteio em `enemy_type_variant`.
- **Elites:** inimigos dourados com mais vida e dano, valem 4x moedas (`CFG.elite`).
- **Chefes:** um por bioma (Rei do Esgoto, Rainha do Neon, O Chefe), com pesos de padrão próprios em `CFG.enemies`.
- **Cenário:** barris, caixas e lixeiras quebráveis (golpe que derruba faz o objeto deslizar e derrubar inimigos); poça tóxica no esgoto, carro nas ruas e claraboia nos telhados (`scripts/scr_props`, números em `CFG.props`).
- **Desafio:** a sala DESAFIO é uma arena com regra (sem bloquear, contra o tempo ou sem levar golpe) e prêmio maior (`scripts/scr_challenge`).
- **Maldições e sinergias:** metade dos baús oferece uma maldição; quatro pares de modificadores ativam um bônus extra (`mods_init`).
- **Corredor:** cada bioma sorteia 3 dos 4 tipos de sala especial e a ordem em que aparecem.
- **Efeitos:** faíscas, poeira, rastro da esquiva e números de dano (`scripts/scr_fx`).
- **Agarrão e arremesso** têm quadros próprios.

Limites conhecidos: os inimigos novos, os dois chefes novos e a Safira são trocas de cor de sprites existentes (`python tools/make_variants.py`); objetos de cenário, carro, escudo e tiro são desenhados com retângulos; a arma na mão continua sendo uma barra; não há som.

## Placeholders

- Inimigos não têm animação própria de idle nem de levantar: o idle é a pose parada com o tronco 1 px mais baixo e o levantar é um quadro da queda.
- Agarrão e arremesso reaproveitam frames de ataque; a arma na mão é uma barra desenhada por cima da personagem.
- As salas usam o cenário do bioma com o objeto da sala; as antigas entradas, interiores e salas separadas foram removidas. As travas de combate permanecem invisíveis.
- A fonte é a padrão do GameMaker.
- Não há som.

## Decisões provisórias e limites conhecidos

- Resolução interna 480x270, janela em múltiplo inteiro (até 3x), 60 fps.
- Salas definidas em GML e montadas em tempo de execução; spawns e portas ficam no código, não no editor de rooms.
- As ondas dos módulos são fixas; a seed escolhe módulos e ofertas, e não muda a composição das ondas.
- Os limites invisíveis da horda prendem o jogador ao setor ativo; fora do combate, ele pode percorrer o corredor de ponta a ponta.
- Inimigos nascem dentro da arena, piscando, em vez de entrar pelas laterais.
- Não há pausa nem tela de opções.
