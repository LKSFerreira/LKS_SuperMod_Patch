# Energização de Objetos sem Rede Elétrica — Project Zomboid Build 42

Guia definitivo documentando TODA a investigação para manter `IsoStove` aceso com propano sem rede elétrica. Aplicável a qualquer mecânica futura que precise energizar objetos individuais.

---

## O Problema

O motor Java do PZ verifica `ItemContainer:isPowered()` a cada frame para objetos com container (fogão, geladeira, micro-ondas). Se retorna `false`, o motor **desativa o objeto imediatamente**. Não existe forma Lua de prevenir isso.

---

## APIs Investigadas e Resultado

| API | Existe em IsoStove? | Funciona? | Notas |
|-----|-------|----------|-------|
| `setActivated(true)` | ✅ Sim | ❌ Motor desativa no frame seguinte | Setter existe mas engine sobreescreve |
| `Toggle()` | ✅ Sim | ❌ Só funciona via `ISToggleStoveAction` (TimedAction) | Chamada direta é ignorada |
| `setPropaneTank(item)` | ❌ Não existe | — | Exclusivo de `IsoFireplace` (BBQ) |
| `setFuelAmount(n)` | ❌ Não existe | — | Exclusivo de `IsoFireplace` |
| `addFuel(n)` | ❌ Não existe | — | Exclusivo de `IsoFireplace` |
| `hasPropaneTank()` | ✅ Getter existe | Retorna `false` | Sem setter, inútil para fogões |
| `isPropaneBBQ()` | ✅ Getter existe | Retorna `false` | Fogão normal não é classificado como BBQ |
| `chunk:addGeneratorPos(x,y,z)` | ✅ | ✅ **FUNCIONA** | Marca tile como energizado → `isPowered()` retorna true |

---

## Solução: `chunk:addGeneratorPos(x, y, z)`

```lua
-- ACENDER: marca tile como energizado, depois usa TimedAction vanilla
local quadrado = fogao:getSquare()
local chunk = quadrado:getChunk()
chunk:addGeneratorPos(fogao:getX(), fogao:getY(), fogao:getZ())
quadrado:RecalcAllWithNeighbours(false)
ISTimedActionQueue.add(ISToggleStoveAction:new(jogador, fogao))

-- APAGAR: remove marca e desativa
chunk:removeGeneratorPos(fogao:getX(), fogao:getY(), fogao:getZ())
quadrado:RecalcAllWithNeighbours(false)
fogao:setActivated(false)
```

---

## Por que funciona

1. `addGeneratorPos` registra a posição no chunk como "alimentada por gerador"
2. `ItemContainer:isPowered()` verifica internamente se o tile tem gerador → retorna `true`
3. Motor Java vê `isPowered() = true` → mantém fogão ativado sem resistência
4. `ISToggleStoveAction` executa `Toggle()` com sucesso porque agora há "energia"
5. Sem OnTick, sem loop, sem piscar — estado mantido nativamente pelo motor

---

## Por que a churrasqueira (BBQ) é diferente

A churrasqueira é `IsoFireplace` (não `IsoStove`), marcada como `isFireInteractionObject() = true`. Tem APIs exclusivas (`setPropaneTank`, `addFuel`, `setFuelAmount`) que o motor Java reconhece como fontes de combustível independentes de eletricidade. **IsoStove regular não herda essas APIs.**

---

## Efeito Colateral

`addGeneratorPos` energiza o TILE, não o objeto. Qualquer outro objeto com container no mesmo tile (geladeira, etc.) também ficará "energizado". Na prática é raro pois fogões ocupam tile próprio. Registrado como dívida técnica no roadmap — solução definitiva requer API Java para energizar por objeto (inexistente em B42).

---

## Quando usar este padrão

- Manter IsoStove aceso com combustível alternativo (propano, biogás futuro)
- Qualquer mecânica que precise fazer `isPowered() = true` sem rede elétrica
- NÃO usar para IsoFireplace — esse já tem APIs nativas de combustível
