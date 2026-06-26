# Walkthrough: Fagocitação Nativa do Light My Fire

**Data:** 20/06/2026
**Autor:** LKS
**Status:** Estável (versão testada em jogo)

## Contexto

O mod "Light My Fire" (Eurymachus, Workshop 3575007347) unificava os menus de
contexto de fogo (campfires, fireplaces, BBQs) em um handler único. Foi absorvido
nativamente pelo LKS SuperMod Patch para eliminar a dependência do mod original.

## Arquitetura Final

### Arquivos Criados

| Arquivo | Responsabilidade |
|---------|-----------------|
| `LKS_Menu_Fire_FuelSolid.lua` | Handler unificado de menu (substitui ISCampingMenu + ISBBQMenu) |
| `LKS_Menu_Fire_FuelSolid_Patch.lua` | Patch de `doAddFuelOption` com handlers independentes |

### Mecânica de Substituição

O PZ possui **2 sistemas independentes** que criam menus para objetos de fogo:

1. **`ISCampingMenu.doCampingMenu`** — chamado por Java via `ISWorldObjectContextMenuLogic`
2. **`ISBBQMenu.OnFillWorldObjectContextMenu`** — chamado por `triggerEvent`

**Solução:**
- Sobrescrita de `ISCampingMenu.doCampingMenu` na tabela global (Java resolve por lookup)
- Neutralização de `ISBBQMenu.OnFillWorldObjectContextMenu` com função vazia

### Menu Hierárquico de Ignição

```
Acender > [Fonte de Calor]     > [Material Inflamável]
           Isqueiro (ícone)       Jornal (3) — tooltip duração
           Fósforos (ícone)       Gasolina (se disponível)
           Fricção (se disponível)
```

**Feedbacks:**
- Sem fonte de calor → tooltip "Requer uma fonte de calor..."
- Tem fonte, sem material → submenu mostra fontes (desabilitadas) com tooltip

### Patch de Combustível

**Problema descoberto:** O vanilla `onAddMultipleFuel` e `onAddAllFuel` dependem de
`fuelItemList` — uma variável `local` no topo de `ISCampingMenu.lua`. Quando o mod
sobrescreve `doAddFuelOption`, os callbacks vanilla perdem acesso a essa variável
porque são closures do arquivo original que podem ter estado compartilhado inconsistente.

**Solução:** Handlers próprios `LKS_onAddMultipleFuel` e `LKS_onAddAllFuel` que criam
`ArrayList.new()` local a cada execução — sem dependência de estado compartilhado.

**Opções de menu padronizadas:**
- Um (1) — usa `onAddFuel` vanilla (funciona, busca por tipo)
- Metade (N) — usa `LKS_onAddMultipleFuel` com limite
- Tudo (N) — usa `LKS_onAddMultipleFuel` sem limite

### Ícones

| Elemento | Ícone |
|----------|-------|
| Menu pai (submenu) | `splitIcon()` do sprite real do objeto |
| Informações | `LKS_Info.png` (renomeado de `LKS_Generator_Info.png`) |
| Tudo global | `LKS_Heat_On.png` |
| Acender | Ícone de `Base.Matches` |
| Apagar | Ícone de `Base.Extinguisher` |
| Transformar em Combustível | Ícone de `Base.FirewoodBundle` |
| Desmontar Fogueira | Ícone de `Base.Stone2` |

### Traduções PT-BR

| Key | Tradução |
|-----|----------|
| `ContextMenu_DestroyForFuel` | Transformar em Combustível |
| `ContextMenu_No_LightingMethod` | Sem Método de Ignição Disponível |
| `ContextMenu_No_Fuel` | Sem Combustível Disponível |
| `ContextMenu_Fuel_Full` | Capacidade máxima de combustível atingida. |
| `ContextMenu_Fuel_Full3` | Espaço Insuficiente |
| `ContextMenu_Half` | Metade |
| Tile "Cooking Pit" | Braseiro (via mapa Lua) |
| Tile "Simple Cooking Pit" | Braseiro Simples (via mapa Lua) |

### Fix Vanilla: DryFirestarterBlock

O bloco acendedor de fogo (`DryFirestarterBlock`) estava em `campingFuelType` mas
NÃO em `campingLightFireType` — oversight vanilla. Adicionado como tinder (30 min).

## Lições Aprendidas

1. **Não substituir callbacks vanilla por referência de ID** — o sistema de TimedActions
   do PZ espera referências consistentes durante toda a vida da ação. Buscar por tipo
   (`getFirstTypeEvalRecurse`) é mais robusto que buscar por ID.

2. **Variáveis `local` em módulos vanilla são armadilhas** — `fuelItemList` é um estado
   compartilhado invisível. Handlers que dependem dela podem falhar silenciosamente.

3. **`addActionsOption` injeta `playerObj` automaticamente** — o primeiro argumento do
   callback é sempre o jogador, não precisa ser passado explicitamente.

4. **Java resolve funções por lookup na tabela** — sobrescrever `ISCampingMenu.doCampingMenu`
   na tabela global É suficiente para interceptar chamadas Java.

5. **F12 Lua Reloader não desfaz registros** — mudanças em arrays globais ou event
   listeners só tomam efeito após restart completo do jogo.

## Incompatibilidade

Adicionado `EURY_LIGHTFIRE` à lista `incompatible` em `mod.info`.
