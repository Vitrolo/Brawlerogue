# Pipeline de assets visuais

Regras permanentes para qualquer trabalho de arte do Brawlerogue (definidas em 18/11/2026).

## 1. Ferramentas e responsabilidades

| Ferramenta | Uso |
|---|---|
| **Retro Diffusion** (MCP `retro-diffusion`) | Sprites, tilesets, animações, variações de cenário, elementos de interface e edição de pixel art. |
| **PixelLab** (MCP `pixellab`) | Sprites, animações e tiles que exigem mais controle da composição pixel a pixel (personagens com id salvo, estados, rotações). |
| **Higgsfield** (MCP `higgsfield`) | Exploração conceitual, referências visuais e propostas de novos ambientes. Não gera asset final do jogo. |

## 2. Antes de gerar qualquer asset

1. Analisar os assets que já existem no projeto: resolução, dimensões, paleta, estilo, proporções.
2. Usar imagens existentes como referência sempre que possível (`input_image` / `reference_images` no Retro Diffusion; personagem salvo no PixelLab).
3. Consultar os estilos do Retro Diffusion (`list_available_styles`) e escolher o mais próximo do caso (ex.: `platformer` para cenário lateral).
4. Estimar o custo com as ferramentas gratuitas (`estimate_inference_cost`, `estimate_edit_tool_cost`, `get_balance`).
5. Não gerar assets redundantes nem incompatíveis com o projeto.

**Nenhuma geração paga sem autorização explícita para aquela tarefa.** O fluxo é: estimar, apresentar custo e plano, esperar o "sim".

## 3. Padrões técnicos atuais do projeto

| Tipo | Tamanho | Origem | Exemplo |
|---|---|---|---|
| Personagem (jogador, inimigos) | 80 × 80 px por quadro | 41, 72 (pés) | `spr_player_run`, `spr_player_idle` |
| Fundo de bioma / célula do nível | 768 × 272 px | 0, 0 | `spr_bg_sewer` |

Cada célula do nível mede 768 × 270 px (ver [geracao_2d.md](geracao_2d.md)). Novos assets seguem esses tamanhos ou justificam a exceção.

## 4. Uma imagem gerada não está pronta

Antes de importar no GameMaker, conferir:

- tamanho exato e grade de pixels nativa (sem upscale borrado; `fix_pixel_art` se precisar);
- fundo transparente onde deve haver transparência;
- origem coerente com os sprites do mesmo tipo;
- número de quadros e layout da tira/folha;
- paleta compatível com o bioma (`tools/import_v3_level_art.py` ajusta as cores à paleta do fundo);
- importação pelos scripts de `tools/` e checagem com `tools/check_project.py`.

## 5. Prioridades

Consistência visual, modularidade e reaproveitamento: preferir derivar variações de um asset base (edição, troca de paleta) a gerar do zero.

## 6. Contas (18/11/2026)

- **Retro Diffusion:** 50 créditos, 2 jobs simultâneos. RD Lite US$ 0,05/imagem (padrão para sprites), RD Core US$ 0,10, RD Pro US$ 0,18; edições US$ 0,001 a 0,12.
- **PixelLab:** plano trial, cota diária de bônus, 1 job por vez. Pendente: sprites de armas, ver [sprites_armas.md](sprites_armas.md).
