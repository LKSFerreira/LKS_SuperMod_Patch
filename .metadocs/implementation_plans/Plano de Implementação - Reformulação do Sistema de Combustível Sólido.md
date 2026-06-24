# Plano de Implementação — Reformulação do Sistema de Combustível Sólido

## Summary

Reformulação completa do sistema de combustível sólido para os 7 meios de fogo do PZ Build 42 (Fogueira, Braseiro, Braseiro Simples, Lareira, Fogão a Lenha, Churrasqueira a Carvão, Forno Antigo). A lógica é invertida: tudo queima **exceto** itens em lista de exclusão (metal, pedra, vidro, ferramentas, armas). O botão da Loot Window ganha mecânica própria (itens dentro do container são processados via TimedAction). Mecânica de penalidade de eficiência (75%) para itens jogados diretamente no fogo sem preparação.

**Referências**:
- Combustíveis e materiais: `docs/pz_combustivel_solido_e_materiais.md`
- Design de fogões: `.metadocs/feat/mecanica_fogoes_fornos.md`
- Menu de fogo: `common/media/lua/client/LKS_Menu_Fire_FuelSolid.lua`
- Patch de combustível: `common/media/lua/client/LKS_Menu_Fire_FuelSolid_Patch.lua`
- Handler vanilla da Loot Window: `media/lua/client/ISUI/LootWindow/Handlers/AddFuelOption.lua`
- camping_fuel.lua: `media/lua/server/Camping/camping_fuel.lua`

---

## Fase 1 — Classificador de Combustível

### Objetivo

Criar módulo centralizado que determina se um item é combustível, substituindo a lógica vanilla `ISCampingMenu.isValidFuel` / `shouldBurn`. Lógica invertida: tudo queima exceto exclusões explícitas.

### Proposed Changes

#### [NEW] `common/media/lua/shared/cooking/LKS_Fire_FuelClassifier.lua`

Módulo shared com as seguintes funções:

**`LKS_ehCombustivel(item)`** — Retorna boolean. Regras:

Exclusões (NÃO queima):
- Itens favoritos ou equipados (manter vanilla)
- Itens molhados (`getWetness() > 0` em roupas — manter vanilla)
- FluidContainer com líquido (manter vanilla)
- Tags: `base:hasmetal`, `base:metalpiece`, `base:smallsheetmetal`, `base:sheetmetalsnips`, `base:stone`, `base:stonemaul`, `base:limestone`, `base:concrete`, `base:brokenglass`, `base:glass`
- Categorias: `Weapon`, `WeaponPart`, `WeaponCrafted`, `WeaponImprovised`, `Tool`, `ToolWeapon`, `VehicleMaintenance`, `VehicleMaintenanceWeapon`, `Ammo`, `Explosives`, `Security`, `ProtectiveGear`, `Fishing`, `FishingWeapon`
- Propriedade `Material` do script: `Metal_Light`, `Glass_Light`
- Lista de exceções explícitas por tipo: `PaperClip` (metal na vida real, sem tag no PZ)

Inclusões (QUEIMA — expansão sobre vanilla):
- FabricType: TUDO incluindo Leather (vanilla bloqueia Leather)
- Tags: `base:charcoal` → queima
- Categorias que queimam: `Clothing`, `Literature`, `Map`, `Junk`, `Household`, `Entertainment`, `Camping`, `Container`, `Bag`, `Accessory`, `Bandage`, `Memento`, `Generic`, `Food` (se não comestível), `Appearance`, `Cartography`, `Communications` (walkie sem bateria), etc.
- InventoryContainer (mochila, bolsa) → queima E processa conteúdo recursivamente

**`LKS_ehCombustivelRecursivo(item, listaResultado)`** — Percorre item e, se for container (mochila, bolsa, carteira), percorre recursivamente os itens dentro. Retorna lista flat de todos os combustíveis encontrados + lista de não-combustíveis.

**`LKS_calcularDuracao(item, comPenalidade)`** — Calcula duração em minutos. Se `comPenalidade == true`, aplica multiplicador de 0.75. Reutiliza `ISCampingMenu.getFuelDurationForItem` como base, mas aplica a nova classificação.

**`LKS_EXCECOES_EXPLICITAS`** — Tabela extensível de tipos de item que não queimam apesar de não terem tags de metal.

---

## Fase 2 — Agrupamento do Menu de Contexto

### Objetivo

Quando há mais de 6 tipos de combustível no inventário, agrupar por categoria para reduzir poluição visual.

### Proposed Changes

#### [MODIFY] `common/media/lua/client/LKS_Menu_Fire_FuelSolid_Patch.lua`

Modificar `ISCampingMenu.doAddFuelOption`:

- Substituir `ISCampingMenu.isValidFuel` por `LKS_ehCombustivel`
- Quando `#fuelList > 6`: agrupar por `item:getCategory()`:
  ```
  🔥 Tudo (47)
  📦 Roupas > Todos (20), Camisa (2), Meia (2), Regata (2)...
  📦 Literatura > Todos (8), Jornal (3), Revista (5)
  📦 Materiais > Todos (4), Trapo (2), Tábua (2)
  📦 Outros > Todos (15), Carteira (1), Borracha (3)...
  ```
- Cada subitem mantém opções: Um (1) / Metade (N) / Tudo (N)
- Quando `#fuelList <= 6`: comportamento atual (lista plana)

---

## Fase 3 — Handler da Loot Window (Nova Mecânica)

### Objetivo

O botão "Transformar em Combustível" na Loot Window ganha mecânica própria: processa itens que já estão DENTRO do container do fogo.

### Proposed Changes

#### [NEW] `common/media/lua/client/LKS_Fire_LootWindowHandler.lua`

Novo handler `ISLootWindowObjectControlHandler` que substitui o vanilla `AddFuelOption`:

1. **`shouldBeVisible()`** — Visível quando o container é um meio de fogo com combustível sólido (mesmo critério atual: CCampfireSystem ou isFireInteractionObject não-propano)
2. **`perform()`** — Nova mecânica:
   - Scan dos itens dentro do container (fireplace/campfire)
   - Para cada item: verifica `LKS_ehCombustivel(item)`
   - Se for InventoryContainer (mochila/bolsa): `LKS_ehCombustivelRecursivo()`
   - Enfileira: `ISWalkToTimedAction` → agachar → `TimedAction` para cada conversão
   - Itens não-combustíveis permanecem no container
   - Itens combustíveis são removidos e convertidos em fuel amount
3. **`getControl()`** — Botão "Transformar em Combustível" com ícone correto (usar ícone de lareira, não fogão)

#### [MODIFY] Handler vanilla `AddFuelOption.lua`

Neutralizar o handler vanilla para evitar duplicata. O nosso handler assume o papel.

---

## Fase 4 — Penalidade de Eficiência (75%)

### Objetivo

Itens colocados diretamente no container aceso sem usar "Transformar em Combustível" queimam com 75% de eficiência.

### Proposed Changes

#### [NEW] Lógica em `LKS_Fire_FuelClassifier.lua` ou arquivo dedicado

- Hook em `Events.EveryTenMinutes` (ou `Events.OnTick` com throttle)
- Para cada container de fogo aceso no chunk do jogador:
  - Verifica se há itens dentro
  - Para cada item combustível: consome com `LKS_calcularDuracao(item, true)` (75%)
  - Para containers aninhados (mochila com roupas): processa recursivamente
  - Remove itens consumidos, mantém não-combustíveis
  - Primeira vez que a penalidade é aplicada: `jogador:Say("Deveria ter preparado o material antes...")` (dica implícita)
  - Não repete o Say após a primeira vez (flag em modData do container)

---

## Fase 5 — Correção de Ícone e Traduções

### Proposed Changes

#### Ícone da Loot Window

- Investigar por que o ícone mostra "fogão vermelho" em vez de lareira
- Provável causa: `ContainerButtonIcons.fireplace = t.oven` (Container_Oven.png é o ícone genérico)
- Solução: usar ícone de fogo/lareira próprio no handler LKS

#### Traduções

Novas chaves em `IG_UI.json` (PT-BR e EN):
- `IGUI_LKS_TransformarCombustivel` — "Transformar em Combustível"
- `IGUI_LKS_SemItensParaConverter` — "Nenhum item convertível no container"
- `IGUI_LKS_PenalidadeEficiencia` — "Deveria ter preparado o material antes..."
- `IGUI_LKS_GrupoRoupas` — "Roupas"
- `IGUI_LKS_GrupoLiteratura` — "Literatura"
- `IGUI_LKS_GrupoMateriais` — "Materiais"
- `IGUI_LKS_GrupoOutros` — "Outros"

---

## Fase 6 — Stub para Dano a Não-Combustíveis (Futuro)

### Proposed Changes

#### [ADD] Em `LKS_Fire_FuelClassifier.lua`

```lua
--- Flag global para habilitar dano a não-combustíveis em containers de fogo acesos.
--- FUTURO: quando habilitado, itens não-combustíveis dentro de containers acesos
--- sofrerão dano progressivo (perda de condição, derretimento de plástico com
--- emissão de gás tóxico similar ao gerador em ambiente fechado).
LKS_FIRE_DAMAGE_ENABLED = false

--- Stub: aplica dano por calor a um item não-combustível dentro de container aceso.
--- @param item InventoryItem O item não-combustível.
--- @param container ItemContainer O container do fogo.
function LKS_aplicarDanoCalor(item, container)
    if not LKS_FIRE_DAMAGE_ENABLED then return end
    -- FUTURO: implementar dano progressivo
    -- Plástico: emissão de gás tóxico (reutilizar mecânica de gerador em ambiente fechado)
    -- Metal: aquecimento (dano de queimadura ao pegar sem luvas)
    -- Vidro: derretimento parcial (reduz condição)
end
```

---

## Notas Técnicas

### Processamento Recursivo de Containers

Cenários cobertos:
1. Saco de lixo com 100 roupas → saco + roupas = tudo vira combustível
2. Mochila com wood + pé de cabra + clips → wood e mochila viram combustível, pé de cabra e clips sobram
3. Carteira com documento + dinheiro + chiclete → tudo vira combustível (carteira também)
4. Pochete com blocos de papel + canetas + clips de papel → papel e canetas queimam, clips sobram

### Sobre itens sem tag que são metal na vida real

Lista de exceções explícitas (`LKS_EXCECOES_EXPLICITAS`):
- `PaperClip` — clips de papel (metal, sem tag `hasmetal` no PZ)
- Lista extensível para cenários futuros

### Sobre FabricType Leather

O vanilla bloqueia couro (`getFabricType() == "Leather"`) como combustível. Nossa mecânica DESBLOQUEIA — couro pega fogo como qualquer outro tecido. Jaqueta de couro dentro da lareira = queima.

### Sobre a penalidade de eficiência

- 100% eficiência: usar "Transformar em Combustível" (menu ou botão da Loot Window)
- 75% eficiência: jogar itens diretamente no container aceso sem preparar
- Feedback: `jogador:Say()` na primeira ocorrência (dica implícita para o jogador)
- A penalidade incentiva gameplay consciente sem punir severamente

### Sobre caneta/lápis/borracha

- Caneta: categoria `Junk` ou `Household` → QUEIMA (plástico no PZ não tem tag exclusiva)
- Lápis: madeira + grafite → QUEIMA
- Borracha: categoria `Junk` → QUEIMA
- Sapato: categoria `Clothing` com FabricType → QUEIMA (desbloqueado)
- Chapéu: `Accessory` → QUEIMA

### Prioridade de Implementação

1. `fuel-classifier` — Classificador (base de tudo)
2. `fuel-menu-grouping` — Menu de contexto com agrupamento (depende de 1)
3. `fuel-loot-handler` — Handler Loot Window com nova mecânica (depende de 1)
4. `fuel-efficiency-penalty` — Penalidade de eficiência (depende de 1)
5. `fuel-translations` — Traduções PT-BR e EN (depende de 2 e 3)
6. `fuel-icon-fix` — Correção de ícone (independente)
7. `fuel-damage-stub` — Stub de dano futuro (depende de 1)
