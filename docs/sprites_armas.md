# Sprites de segurar arma (cano e taco)

> **Status:** feito sem gerar imagens (custo zero). A arma segurada usa o próprio sprite do item (`spr_weapon_pipe`, `spr_weapon_bat`), preso na mão da frente de cada quadro. O plano antigo com o PixelLab (cerca de 28 gerações) ficou abaixo como alternativa, caso se queira poses dedicadas no futuro.

## Como funciona

- `tools/weapon_anchors.py` acha a mão da frente em cada quadro dos sprites `spr_player_*` pela cor da luva e gera `scripts/scr_weapon_hand/scr_weapon_hand.gml` (tabela de offsets). Os quadros em que a detecção pega olho ou sapato ficam em `OVERRIDES`. A Safira (`spr_p2_*`) usa a mesma tabela.
- `player_draw_weapon` (`scripts/scr_choice`) é chamada por `actor_draw` logo depois do corpo do jogador: respeita profundidade, transparência e clarão de dano, espelha pelo lado e acompanha a inclinação da corrida.
- No golpe com arma, o sprite gira: +70° na preparação (para trás), −40° no acerto (horizontal), −65° na recuperação (para baixo).
- A empunhadura de cada arma fica em `grip` na config (`scripts/scr_config`, `CFG.weapons`).
- Uma arma nova só precisa de um sprite de item apontando para cima e para a frente (~40°) e do `grip`. Se os sprites do jogador mudarem, rode `python tools/weapon_anchors.py` de novo.

## Plano alternativo (PixelLab, não executado)

### Personagem no PixelLab

- Rubi: `Brawlerogue Player`, id `b1c6ba2c-c9f2-445f-8fca-752b5572b6bc`, 80×80, vista lateral, 4 direções. O jogo usa só `east`.
- A Safira (`spr_p2_*`) sai por troca de cor em `tools/make_variants.py`, sem gastar gerações.

### Ordem das gerações (cerca de 28)

| # | O quê | Ferramenta | Custo |
| --- | --- | --- | --- |
| 1 | Estado "segurando cano" | `create_character_state`, `edit_description`: "holding a rusty metal pipe in the right hand, ready to swing", `state_name`: "Pipe", `use_color_palette_from_reference`: true | 10 |
| 2 | Parado com cano | `animate_character` no id do estado novo, `template_animation_id`: `breathing-idle`, `directions`: `["east"]` | 1 |
| 3 | Andando com cano | idem, `walking-6-frames` | 1 |
| 4 | Correndo com cano | idem, `running-6-frames` | 1 |
| 5 | Golpe com cano | `animate_character` modo v3, `action_description`: "swinging a pipe overhead in a downward strike", `directions`: `["east"]`, 8 quadros | 1–2 |
| 6–10 | O mesmo para o taco | estado "holding a wooden baseball bat in both hands, ready to swing", `state_name`: "Bat" | cerca de 14 |

Cada passo cabe numa cota diária, e o estado (10 gerações) precisa da cota de dois dias acumulada. Se um resultado vier ruim (arma sumindo, outra pessoa), apague a animação e refaça antes de seguir.

### Depois das gerações

1. **Importar:**
   - Baixe o ZIP do personagem (`/mcp/characters/<id>/download`).
   - Copie os quadros `east` para `tools/pixellab_raw/player_pipe/Idle/...` e `player_bat/...`, no mesmo formato de `tools/pixellab_raw/player`.
   - Acrescente as entradas em `CHARACTERS` de `tools/import_pixellab.py`: `pipe_idle`, `pipe_walk`, `pipe_run`, `pipe_attack`, e o mesmo para `bat`.
2. **Safira:** acrescente as mesmas chaves em `PLAYER_KEYS` de `tools/make_variants.py`.
3. **Código:**
   - Em `chars_init` (`scripts/scr_meta`), cada personagem ganha `sprites.weapons[$ wid] = { idle, walk, run, attack }`, com referências diretas: o projeto remove sprites sem uso.
   - `player_animate` usa o conjunto da arma em `global.run.weapon` quando ele existe.
   - Os golpes `weapon_pipe` e `weapon_bat` (`scr_config`) passam a usar o sprite de golpe.
   - `player_draw_weapon` deixa de desenhar a barra quando há sprite.
