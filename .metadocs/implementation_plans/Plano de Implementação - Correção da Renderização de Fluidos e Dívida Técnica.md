# Plano de Implementação - Correção da Renderização de Fluidos e Dívida Técnica

Este documento detalha o plano técnico para corrigir o bug visual no menu de contexto do gerador (`PB_ContextMenu_Generator.lua`), onde recipientes com fluidos (como o balde com gasolina) usavam o ícone estático do recipiente vazio em vez da representação dinâmica com líquido do inventário. Também registra a criação do arquivo `ROADMAP.md` para documentar dívidas técnicas.

## User Review Required

> [!NOTE]
> Esta alteração aproveita o suporte nativo do Project Zomboid Build 42 para renderização dinâmica de itens nos menus de contexto através do atributo `itemForTexture`. Ao atribuir o próprio item do inventário a `itemForTexture` e limpar `iconTexture`, o jogo renderizará o recipiente com a cor e overlay do fluido correto.

## Proposed Changes

---

### Menu de Contexto do Gerador

#### [MODIFY] [PB_ContextMenu_Generator.lua](file:///c:/Users/LKSFERREIRA/Zomboid/mods/LKS_SuperMod_Patch/common/media/lua/client/PB_ContextMenu_Generator.lua)

Propomos as seguintes alterações estruturais:

1. **Substituição de Extração de Textura por Item (`ExtractContainerItemFromOption`)**:
   - Renomear `ExtractContainerTextureFromOption` para `ExtractContainerItemFromOption`.
   - Em vez de retornar a textura estática (`item:getTex()`), retornar a própria instância de `InventoryItem` encontrada na opção do menu.

2. **Ajuste na Lógica de Renderização em `applyIconsDeep`**:
   - Mudar a propagação de `inheritedIcon` (string de textura) para `inheritedItem` (instância de `InventoryItem`).
   - Se a opção for correspondente a um item específico do inventário (determinado por `itemForTexture` ou extraído via `ExtractContainerItemFromOption`):
     - Atribuir `opt.itemForTexture = currentItem`.
     - Definir `opt.iconTexture = nil` para garantir que a renderização dinâmica do motor do PZ não seja contornada pela textura estática vazia.
   - Se a opção for do tipo "Adicionar Um" (`isAddOne`), herdar o item do pai (`opt.itemForTexture = inheritedItem`) e definir `opt.iconTexture = nil`.
   - Manter ícones estáticos padrão mapeados em `iconMap` apenas para opções de controle e gerais (ex: "Ligar", "Desconectar", "Adicionar Tudo").

---

### Documentação de Dívidas Técnicas

#### [NEW] [ROADMAP.md](file:///c:/Users/LKSFERREIRA/Zomboid/mods/LKS_SuperMod_Patch/ROADMAP.md)

Criar o arquivo `ROADMAP.md` na raiz do repositório para documentar a dívida técnica solicitada:
- A tradução da categoria de recipientes contendo líquidos não-água deve ser alterada de "Recipiente de Água" para "Recipiente de Líquido" para melhor precisão conceitual.

---

## Verification Plan

### Automated Tests
- Não se aplica, pois o comportamento é puramente de renderização visual no motor do Project Zomboid.

### Manual Verification
1. No jogo, adicione ao inventário do personagem um "Balde com Gasolina" (Bucket containing gasoline) e um "Galão com Gasolina".
2. Clique com o botão direito em um gerador e navegue até a opção "Gerador" -> "Colocar Combustível".
3. Verifique se o menu renderiza o ícone do Balde com o líquido amarelo (gasolina) em vez do balde de metal vazio.
4. Abra o submenu de "Balde com Gasolina (2)" (se houver mais de um) e verifique se a opção "Adicionar Um" renderiza com o mesmo ícone do balde com líquido.
5. Verifique se a opção "Adicionar Tudo" continua renderizando com o ícone vermelho de reabastecimento geral (`PB_Gas_Refuel_All.png`).
6. Verifique se o arquivo [ROADMAP.md](file:///c:/Users/LKSFERREIRA/Zomboid/mods/LKS_SuperMod_Patch/ROADMAP.md) foi criado com a pendência de tradução devidamente registrada.
