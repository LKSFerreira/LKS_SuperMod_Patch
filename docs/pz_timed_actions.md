# TimedActions — Animações e Interações Físicas — Project Zomboid Build 42

Referência de padrões vanilla para ações temporizadas (`ISBaseTimedAction`) com animação do personagem.

---

## Padrão canônico para ação com animação

```lua
require "TimedActions/ISBaseTimedAction"

MinhaAction = ISBaseTimedAction:derive("MinhaAction")

function MinhaAction:new(jogador, ...)
    local o = ISBaseTimedAction.new(self, jogador)
    o.maxTime = 250           -- ~2.5 segundos
    o.stopOnWalk = true       -- Cancela se jogador andar
    o.stopOnRun = true        -- Cancela se jogador correr
    return o
end

function MinhaAction:start()
    self:setActionAnim("Loot")                    -- Animação de agachar
    self:setAnimVariable("LootPosition", "Low")   -- Posição baixa (chão)
    self:setOverrideHandModels(nil, nil)           -- Esconde itens das mãos
    self.character:faceThisObject(self.alvo)       -- Vira para o objeto
end

function MinhaAction:perform()
    -- Lógica executada ao completar a barra de ação
    ISBaseTimedAction.perform(self)  -- OBRIGATÓRIO no final
end

function MinhaAction:isValid()
    return self.alvo ~= nil  -- Validação contínua durante a ação
end
```

---

## Caminhada até o objeto + ação enfileirada

```lua
-- walkAdj faz o jogador caminhar até ficar adjacente ao quadrado
-- A TimedAction é enfileirada e só executa após chegar
if luautils.walkAdj(jogador, objeto:getSquare()) then
    ISTimedActionQueue.add(MinhaAction:new(jogador, objeto))
end
```

---

## Dropar item no chão com offset direcional

```lua
-- AddWorldInventoryItem(item, offsetX, offsetY, offsetZ)
-- Offsets 0.0-1.0 controlam posição dentro do tile
-- Offset 0.2/0.4 dá bom resultado visual (ao lado do jogador)
local direcaoX = alvo:getX() - jogador:getX()
local direcaoY = alvo:getY() - jogador:getY()
local offsetX = 0.5 + (direcaoX * 0.3)
local offsetY = 0.5 + (direcaoY * 0.3)
quadrado:AddWorldInventoryItem(item, offsetX, offsetY, 0)
```

---

## Ações nativas do Combo Washer Dryer

O Combo Washer Dryer possui timed actions exclusivas que diferem das lavadoras e secadoras individuais:

| Ação | Classe | Callback |
|---|---|---|
| Ativação (Ligar/Desligar) | `ISToggleComboWasherDryer` | `onToggleComboWasherDryer` |
| Alternância de Modo | `ISSetComboWasherDryerMode` | `onSetComboWasherDryerMode` |
| Lavadora comum | `ISToggleClothingWasher` | `onToggleClothingWasher` |
| Secadora comum | `ISToggleClothingDryer` | `onToggleClothingDryer` |

**Armadilha:** Usar a action errada (ex: `ISToggleClothingWasher` no Combo) resulta em falha silenciosa.
