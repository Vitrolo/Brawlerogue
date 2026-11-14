# Brawlerogue

Beat 'em up roguelike single-player em GameMaker LTS 2026 (runtime 2026.0.0.23).

Estado atual: **Etapas A a G escritas**. A run vai do lobby ao chefe final, com rotas ramificadas, recompensas temporárias e retorno ao lobby em vitória ou derrota. Personagens e cenários usam arte em pixel art gerada no PixelLab (portas, itens e HUD ainda são formas simples) e o balanceamento ainda não foi ajustado em jogo.

## Como abrir e jogar

1. Abra `Brawlerogue.yyp` no GameMaker LTS 2026.
2. Rode com F5 (alvo Windows, VM).
3. No lobby, ande até a porta e aperte `E` para iniciar a run.
4. Em cada sala, derrote a horda e escolha uma das portas da direita; o texto e o ícone acima da porta dizem o tipo da próxima sala.
5. Atravesse esgoto, ruas e topo dos prédios e derrote o chefe.

## Controles

O mapeamento fica todo em `scripts/scr_input` (`input_init`). Teclado e controle funcionam ao mesmo tempo. O mapeamento de controle é inicial e ainda não foi testado com um controle real.

| Ação | Teclado | Controle (layout Xbox) |
| --- | --- | --- |
| Mover (horizontal e profundidade) | W A S D ou setas | analógico esquerdo ou direcional |
| Pular | Espaço | A |
| Atacar / combo de 3 golpes / chute aéreo no pulo | J | X |
| Bloquear (segurar) | K | RB |
| Esquivar | L | B |
| Agarrar; de novo para arremessar | U | Y |
| Especial (gasta 50 de energia) | I | LB |
| Interagir (portas, baús, loja, armas no chão) | E ou Enter | RT |

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
- Ao zerar a vida, a luta para, aparece "VITORIA" com o tempo da run e o jogo volta ao lobby.

## Recompensas, armas e salas especiais

Tudo abaixo vive em `global.run` e some ao fim da run. As definições ficam em `scripts/scr_modifiers` (`mods_init`); os valores gerais em `CFG.rewards`.

- **Cura** (Lanche 30, Marmita 60): imediata, limitada à vida máxima.
- **Vida máxima** (Colete): +20 de vida máxima e cura os mesmos 20.
- **Velocidade** (Tênis leves): +12% por unidade, acumulável, com teto de 160%.
- **Passivas** (não acumulam): +20% de dano, -20% de dano recebido, cura 3 por inimigo derrotado, especial 50% mais rápido.
- **Armas** (Cano, Taco): `J` passa a dar um golpe único da arma no lugar do combo. Cada acerto gasta 1 de durabilidade; em 0 a arma quebra. Se a personagem for derrubada, a arma cai no chão e pode ser pega de novo. Algumas salas de combate têm uma arma no chão.
- **Moedas**: 5 por inimigo derrotado, usadas só na loja.

Salas especiais (interaja com o objeto do centro):

- **Descanso**: cura 30% da vida máxima, uma vez.
- **Recompensa**: escolha 1 entre 3.
- **Loja**: Marmita e até 3 itens sorteados, pagos com moedas; `L` sai.
- **Evento**: uma escolha com consequência escrita na carta, ou ignorar.

Na tela de escolha: `A`/`D` selecionam, `E` confirma. As ofertas de cada sala são fixas para a mesma seed.

## Run e salas

- A rota é um grafo em camadas gerado em `run_start` a partir da seed (mostrada no canto da tela). A mesma seed gera as mesmas salas e conexões: `run_start(12345)`.
- Cada bioma tem `CFG.run.layers_per_biome` salas visitadas (4 por padrão): entrada, duas camadas com 2 a 3 opções e saída. Com 4 camadas nenhuma sala se repete na run; a partir de 5 o conjunto atual pode repetir combates.
- `run_graph_validate` confere que toda sala existe, que as conexões só avançam, que tudo é alcançável e que toda sala leva ao chefe. Se a rota ramificada falhar, usa uma rota linear.
- Os módulos de sala ficam em `scripts/scr_rooms`: 11 no esgoto, 11 nas ruas, 10 no topo dos prédios, mais a arena final.
- Uma sala de combate tem `encounter`: gatilho, limites da arena e ondas. Ao cruzar o gatilho a câmera e os atores ficam presos; derrotadas as ondas aparece "GO" e as portas abrem.
- Todas as salas da run usam o mesmo room do GameMaker como casca (`RM_STAGE`, hoje `rm_sandbox`); a largura vem dos dados da sala.

## Como expandir

- **Sala nova:** em `rooms_init`, uma linha `room_combat(id, bioma, nome, papel, largura, ondas)` ou `room_special(id, bioma, nome, tipo)`. Cada inimigo de uma onda é `[x, y]` (capanga) ou `[x, y, "tipo"]`; as posições precisam ficar dentro da arena (x de 125 até largura - 15, y de 178 a 258). Para uma arma no chão, `room_pickup(id, arma, x, y)`.
- **Inimigo novo:** um bloco em `config_enemies_init` copiando o do capanga, um golpe com `attack_define` e os sprites `idle`, `walk`, `telegraph`, `attack` (3 frames), `hurt`, `knockdown`, `getup`, `dead`. Um comportamento diferente pede um novo valor de `ai` e o desvio em `enemy_step`, como o chefe faz.
- **Bioma novo:** um item em `global.biomes` (id, nome, paleta), uma função `backdrop_*` em `scr_backdrop` e de 10 a 11 salas com papéis `start`, `mid` e `exit`. A rota percorre os biomas na ordem da lista.
- **Modificador novo:** um `mod_define` usando um `stat` de `run_base_stats()` e a inclusão do id em `global.reward_pool`. Para um efeito inédito, crie o stat em `run_base_stats()` e consulte `global.run.stats` no ponto em que ele age.
- **Arma nova:** um item em `CFG.weapons`, um golpe com `attack_define` e um `mod_define` de categoria `weapon`.
- **Golpe novo:** `attack_define(nome, campos)`; os padrões e o significado de cada campo estão no topo de `scr_config`.
- **Controle e remapeamento:** só `input_init`; o resto do jogo consulta `ACT.*`.
- **Arte:** os sprites vêm de `tools/pixellab_raw` e são montados por `python tools/import_pixellab.py`, que define quais quadros de cada animação viram cada sprite, encosta a figura no chão e põe a origem nos pés. Para trocar um personagem, substitua os PNGs em `tools/pixellab_raw/<personagem>` e rode o script. Se mudar o número de quadros de idle/walk, ajuste o `mod` em `player_animate`, `scr_enemy` e `scr_boss`. Cenários: um `spr_bg_<bioma>` de 768x272 por bioma; as linhas do chão de cada imagem ficam em `stage_backdrop_info` (`scripts/scr_backdrop`).

## Estrutura

- `scripts/scr_config` — todo o balanceamento (`CFG`): jogador, golpes, inimigos, chefe, horda, run, recompensas, câmera.
- `scripts/scr_input` — ações abstratas (`ACT.*`), teclas e botões.
- `scripts/scr_run_state` — estado temporário da run (`global.run`), início, fim e reset.
- `scripts/scr_stage` — montagem da sala a partir dos dados, encontros (ondas e trava de arena) e limites.
- `scripts/scr_rooms` — biomas e módulos de sala.
- `scripts/scr_route` — geração, validação e navegação da rota.
- `scripts/scr_backdrop` — desenha o cenário pintado de cada bioma.
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
- `tools/import_pixellab.py` e `tools/pngio.py` — importam a arte do PixelLab (`tools/pixellab_raw`) para os sprites.

## Placeholders

- Inimigos não têm animação própria de idle nem de levantar: o idle é a pose parada com o tronco 1 px mais baixo e o levantar é um quadro da queda.
- Agarrão e arremesso reaproveitam frames de ataque; a arma na mão é uma barra desenhada por cima da personagem.
- Portas e objetos interativos são desenhados com retângulos. O cenário é o mesmo em todas as salas de um bioma.
- A fonte é a padrão do GameMaker.
- Não há som.

## Decisões provisórias e limites conhecidos

- Resolução interna 480x270, janela em múltiplo inteiro (até 3x), 60 fps.
- Salas definidas em GML e montadas em tempo de execução; spawns e portas ficam no código, não no editor de rooms.
- As ondas de cada sala são fixas; a seed varia a rota e as salas, não a composição dentro da sala.
- Não há paredes ou obstáculos dentro das salas: os limites são as bordas da sala e da arena.
- Inimigos nascem dentro da arena, piscando, em vez de entrar pelas laterais.
- Não há pausa nem tela de opções.
