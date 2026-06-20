# Documentação de Referência — Light My Fire (Mod Original)

Este documento descreve o funcionamento do mod **Light My Fire** (Workshop ID: `3575007347`, Mod ID: `EURY_LIGHTFIRE`) desenvolvido por **Eurymachus**.

---

## O que o Mod Faz

Restaura e unifica as entradas de menu de contexto para fogueiras (campfire kits), lareiras/fogões a lenha (IsoFireplace/woodstove) e churrasqueiras (BBQ propane/charcoal) que foram quebradas ou duplicadas na Build 42.

O vanilla B42 criava entradas duplicadas porque `ISCampingMenu.doCampingMenu` e `ISBBQMenu.OnFillWorldObjectContextMenu` rodam independentemente para o mesmo objeto `IsoFireplace`. O LMF substitui ambos por um handler unificado.

---

## Arquitetura

| Arquivo | Propósito |
|---|---|
| `LMF.lua` (~375 linhas) | Handler unificado de menu de contexto para todos os objetos de fogo |
| `AddFuel_IDPatch.lua` (~280 linhas) | Patch de seleção de combustível por ID (corrige bug vanilla de duplicação) |

---

## Mecânica Principal (`LMF.lua`)

### Detecção de Target

`findFireTarget(worldobjects)` varre objetos no tile clicado:
1. **Campfire kit** — detecta via `CCampfireSystem.instance:getLuaObjectOnSquare(sq)`
2. **Fire-interaction tile** — detecta via `obj:isFireInteractionObject()` (IsoFireplace, BBQ, woodstove)

Retorna tabela `{ kind, target, square, currentFuel, isPropane }`.

### Construção do Menu

`CampingMenu.doCampingMenu` (sobrescrita) cria um submenu unificado:

**Para Campfire Kit:**
- Informações (com tooltip de combustível/estado)
- Acender / Apagar
- Adicionar Combustível (submenu)
- Remover Fogueira

**Para Fire-Interaction Tile (fireplace/woodstove/BBQ charcoal):**
- Informações (tooltip com combustível/estado)
- Acender (`doLightFireOption` vanilla) / Apagar (`ISBBQExtinguish`)
- Adicionar Combustível (submenu)

**Para BBQ Propane:**
- Informações
- Ligar / Desligar
- Inserir / Remover Tanque de Propano

### Ícones

Usa `ScriptManager.instance:getItem(fullType):getIcon()` para resolver ícones temáticos:
- Fósforos para "Acender"
- Extintor para "Apagar"
- Lenha para "Destruir para Virar Combustível"
- Propano para ações de tanque

### Remoção de Duplicatas

Remove o handler original `old_doCampingMenu` do evento e registra a sobrescrita. O `ISBBQMenu.OnFillWorldObjectContextMenu` fica efetivamente morto porque o LMF trata BBQs dentro do `doCampingMenu` antes do `ISBBQMenu` ter chance de rodar (usa a mesma detecção `isFireInteractionObject`).

---

## Patch de Combustível (`AddFuel_IDPatch.lua`)

### Problema resolvido

O vanilla usa referências diretas ao objeto de item ao construir opções de menu. Quando há múltiplos itens com mesmo `fullType` e `getName()`, o vanilla pode consumir o item errado ao clicar.

### Solução

Substitui `ISCampingMenu.doAddFuelOption` por versão que:
1. Armazena `item:getID()` na opção do menu
2. Ao executar, resolve o item por ID via `container:getItemById(id)`
3. Para "Tudo", monta lista de IDs com `buildIdListForMenuEntry`

### Funções expostas

- `ISCampingMenu.onAddFuelById(playerObj, target, itemId, timedAction, currentFuel)`
- `ISCampingMenu.onAddMultipleFuelByIds(playerObj, target, itemIds, timedAction, currentFuel, count)`

---

## Integração com nosso mod

O LKS SuperMod Patch já removeu `IsoFireplace` do registro do `LKS_ApplianceManager` para não criar entradas duplicadas. A incorporação nativa do LMF permite:
1. Garantir menu unificado sem dependência externa
2. Traduzir para PT-BR
3. Integrar com futuras mecânicas LKS do fogão antigo (Fase 3)
4. Remover o menu vanilla duplicado que ainda aparecia

---

## Créditos

- **Mod Original**: Light My Fire
- **Autor**: Eurymachus
- **Workshop ID**: 3575007347
- **Link**: https://steamcommunity.com/sharedfiles/filedetails/?id=3575007347
