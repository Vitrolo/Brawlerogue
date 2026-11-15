# Brawlerogue

Beat 'em up roguelike single-player em GameMaker LTS 2026 (runtime 2026.0.0.23).

Estado atual: a run vai do lobby por três mapas laterais largos (esgoto, ruas e telhados). Cada mapa tem quatro setores de horda, acessos fixos a tesouro, desafio, loja e descanso, e uma luta contra o chefe existente no fim do corredor. As salas opcionais são telas pretas provisórias de tamanho fixo; o progresso volta ao mesmo ponto do corredor.

## Como abrir e jogar

1. Abra `Brawlerogue.yyp` no GameMaker LTS 2026.
2. Rode com F5 (alvo Windows, VM).
3. No lobby, ande até a porta e aperte `E` para iniciar a run.
4. Avance pelo corredor lateral; as hordas bloqueiam o setor até todos os inimigos serem derrotados.
5. Depois de limpar um setor, avance ou volte. Use as passagens fixas para visitar tesouro, desafio, loja e descanso; a porta de retorno leva ao ponto de entrada.
6. Derrote o chefe no fim de cada mapa para seguir ao próximo bioma. Vencer o chefe do último mapa encerra a run.

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
- O mesmo chefe aparece no fim do corredor principal de cada mapa. Ao vencer, a run segue para o próximo bioma; após o último chefe, aparece "VITORIA" e o jogo volta ao lobby.

## Recompensas, armas e salas especiais

Tudo abaixo vive em `global.run` e some ao fim da run. As definições ficam em `scripts/scr_modifiers` (`mods_init`); os valores gerais em `CFG.rewards`.

- **Cura** (Lanche 30, Marmita 60): imediata, limitada à vida máxima.
- **Vida máxima** (Colete): +20 de vida máxima e cura os mesmos 20.
- **Velocidade** (Tênis leves): +12% por unidade, acumulável, com teto de 160%.
- **Passivas** (não acumulam): +20% de dano, -20% de dano recebido, cura 3 por inimigo derrotado, especial 50% mais rápido.
- **Armas** (Cano, Taco): `J` passa a dar um golpe único da arma no lugar do combo. Cada acerto gasta 1 de durabilidade; em 0 a arma quebra. Se a personagem for derrubada, a arma cai no chão e pode ser pega de novo. Algumas salas de combate têm uma arma no chão.
- **Moedas**: 5 por inimigo derrotado, usadas só na loja.

Salas especiais (as telas estão provisoriamente pretas e fixas em 480x270; use a porta `VOLTAR` para retornar ao corredor):

- **Descanso**: cura 30% da vida máxima, uma vez.
- **Recompensa**: escolha 1 entre 3.
- **Loja**: Marmita e até 3 itens sorteados, pagos com moedas; `L` sai.
- **Desafio**: por enquanto usa o evento existente, com uma escolha de risco/recompensa.

Na tela de escolha: `A`/`D` selecionam, `E` confirma. As ofertas de cada sala são fixas para a mesma seed.

## Run e salas

- `run_maps_build` escolhe, com a seed da run, um trecho inicial, dois trechos intermediários e um trecho final por bioma; concatena as ondas e armas desses módulos num corredor largo.
- Cada mapa tem passagens fixas para tesouro, desafio/evento, loja e descanso. As salas especiais usam a mesma sala-casca do GameMaker, sem cenário, com largura fixa de 480 unidades.
- O chefe definido pela arena `boss_arena` é instanciado no fim de cada corredor. A vitória avança o bioma; apenas o último chefe encerra a run.
- O estado dos setores, dos itens no chão e das salas especiais fica em `global.run`. Voltar a uma sala especial não reinicia hordas limpas, armas coletadas, estoque comprado ou recompensas usadas.
- Ao cruzar o gatilho de um setor, `encounter_update_map` trava os limites de movimento e a câmera sem desenhar paredes nas bordas. Quando todas as ondas acabam, o jogador pode recuar ou seguir.
- Os módulos de combate e especiais continuam em `scripts/scr_rooms`: eles fornecem layout, ondas, armas e interações para os mapas gerados.
- Os mapas e as salas especiais usam o mesmo room do GameMaker como casca (`RM_STAGE`, hoje `rm_sandbox`); o corredor usa largura calculada e as salas especiais ficam fixas na largura da tela.

## Como expandir

- **Sala nova:** em `rooms_init`, uma linha `room_combat(id, bioma, nome, papel, largura, ondas)` ou `room_special(id, bioma, nome, tipo)`. Cada inimigo de uma onda é `[x, y]` (capanga) ou `[x, y, "tipo"]`; as posições precisam ficar dentro da arena (x de 125 até largura - 15, y de 178 a 258). Para uma arma no chão, `room_pickup(id, arma, x, y)`.
- **Inimigo novo:** um bloco em `config_enemies_init` copiando o do capanga, um golpe com `attack_define` e os sprites `idle`, `walk`, `telegraph`, `attack` (3 frames), `hurt`, `knockdown`, `getup`, `dead`. Um comportamento diferente pede um novo valor de `ai` e o desvio em `enemy_step`, como o chefe faz.
- **Bioma novo:** um item em `global.biomes` (id, nome, paleta), uma imagem `spr_bg_<bioma>` e módulos suficientes para papéis `start`, `mid` e `exit`, além de recompensa, evento/desafio, loja e descanso. Os mapas são percorridos na ordem da lista.
- **Modificador novo:** um `mod_define` usando um `stat` de `run_base_stats()` e a inclusão do id em `global.reward_pool`. Para um efeito inédito, crie o stat em `run_base_stats()` e consulte `global.run.stats` no ponto em que ele age.
- **Arma nova:** um item em `CFG.weapons`, um golpe com `attack_define` e um `mod_define` de categoria `weapon`.
- **Golpe novo:** `attack_define(nome, campos)`; os padrões e o significado de cada campo estão no topo de `scr_config`.
- **Controle e remapeamento:** só `input_init`; o resto do jogo consulta `ACT.*`.
- **Arte:** os sprites vêm de `tools/pixellab_raw` e são montados por `python tools/import_pixellab.py`, que define quais quadros de cada animação viram cada sprite, encosta a figura no chão e põe a origem nos pés. Para trocar um personagem, substitua os PNGs em `tools/pixellab_raw/<personagem>` e rode o importador. Se mudar o número de quadros de idle/walk, ajuste o `mod` em `player_animate`, `scr_enemy` e `scr_boss`. Cenários: um `spr_bg_<bioma>` de 768x272 por bioma; as linhas do chão de cada imagem ficam em `stage_backdrop_info` (`scripts/scr_backdrop`). As entradas dos mapas são variantes completas desses fundos, montadas por `python tools/import_entrance_chunks.py` com as quatro posições fixas do corredor.

## Estrutura

- `scripts/scr_config` — todo o balanceamento (`CFG`): jogador, golpes, inimigos, chefe, horda, run, recompensas, câmera.
- `scripts/scr_input` — ações abstratas (`ACT.*`), teclas e botões.
- `scripts/scr_run_state` — estado temporário da run (`global.run`), início, fim e reset.
- `scripts/scr_stage` — montagem dos corredores e salas especiais, encontros, travas de horda e limites.
- `scripts/scr_rooms` — biomas e módulos de sala.
- `scripts/scr_route` — geração dos mapas por bioma, seleção de módulos e estado das salas opcionais.
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
- `tools/import_pixellab.py`, `tools/import_entrance_chunks.py` e `tools/pngio.py` — importam os cenários e montam os trechos integrados de entrada.

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
- As entradas do corredor fazem parte de variantes completas do cenário, com bordas idênticas ao fundo original; os nomes aparecem no aviso de interação. Portais simples continuam nas telas pretas de sala especial. As travas de combate permanecem invisíveis; objetos interativos ainda usam formas provisórias. Os interiores das salas opcionais são pretos até receberem arte própria.
- A fonte é a padrão do GameMaker.
- Não há som.

## Decisões provisórias e limites conhecidos

- Resolução interna 480x270, janela em múltiplo inteiro (até 3x), 60 fps.
- Salas definidas em GML e montadas em tempo de execução; spawns e portas ficam no código, não no editor de rooms.
- As ondas dos módulos são fixas; a seed escolhe módulos e ofertas, e não muda a composição das ondas.
- Os limites invisíveis da horda prendem o jogador ao setor ativo; fora do combate, ele pode percorrer o corredor de ponta a ponta.
- Inimigos nascem dentro da arena, piscando, em vez de entrar pelas laterais.
- Não há pausa nem tela de opções.
