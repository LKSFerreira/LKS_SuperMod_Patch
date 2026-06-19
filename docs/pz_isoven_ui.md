# ISOvenUI — Janela de Configuração do Fogão Vanilla — Project Zomboid Build 42

Referência técnica da janela vanilla de configuração de fogão (`ISOvenUI`), incluindo knobs, botões, handlers da Loot Window e armadilhas de monkey-patch.

**Arquivo-fonte:** `media/lua/client/ISUI/Fireplace/ISOvenUI.lua`

---

## Componentes

| Componente | Classe | Função |
|---|---|---|
| `ISOvenUI` | `ISPanelJoypad:derive` | Janela principal com knobs e botões |
| `ISKnob` | Widget vanilla | Knob rotativo para temperatura (0-300) e timer (0-120min) |
| `StoveSettings.lua` | `ISLootWindowObjectControlHandler` | Botão "Configurações" na sidebar do inventário |
| `StoveToggle.lua` | `ISLootWindowObjectControlHandler` | Botão "Ligar/Desligar" na sidebar do inventário |

---

## Criação dos knobs

```lua
self.tempKnob = ISKnob:new(x, y, knobTex, bgTex, getText("IGUI_Temperature"), character)
self.timerKnob = ISKnob:new(x, y, knobTex, bgTex, getText("IGUI_Timer"), character)

-- Toggle C/F via tradução: chaves IGUI_Oven_Celsius e IGUI_Oven_Fahrenheit
-- Override no mod: trocar "Celsius"/"Fahrenheit" por "°C"/"°F" no IG_UI.json

-- Botão Ligar/Desligar: self.ok (internal = "OK")
-- Botão Fechar: self.close (internal = "CLOSE")

-- updateButtons() roda a cada frame — controla estado do botão:
self.ok:setEnable(self.oven:getContainer() and self.oven:getContainer():isPowered())
-- Para propano: monkey-patch via Events.OnGameStart.Add() (ISOvenUI não existe no load-time)

-- onClick com internal "OK" envia comando server-side:
sendClientCommand(self.character, 'stove', 'setOvenParamsAndToggle', args)
```

---

## Handlers da Loot Window

```lua
-- StoveSettings.lua e StoveToggle.lua usam o mesmo guard:
function Handler:shouldBeVisible()
    return instanceof(self.object, "IsoStove")
        and (self.container ~= nil) and self.container:isPowered()
end
```

---

## Opção "Configurações" no menu de contexto

Criada por `ISInventoryPaneContextMenu.lua` (linha ~988), **NÃO** pelo world context menu:

```lua
-- Vanilla só mostra quando isPowered():
if instanceof(stove, "IsoStove") and stove:getContainer() and stove:getContainer():isPowered() then
    context:addOption(getText("ContextMenu_StoveSetting"), nil,
        ISWorldObjectContextMenu.onStoveSetting, stove, playerNum)
end

-- Para exibir sem energia: injetar manualmente no submenu sequestrado
-- verificando getText("ContextMenu_StoveSetting") e adicionando se ausente
```

---

## Armadilha: monkey-patch no load-time

`ISOvenUI` **não existe** quando os arquivos de mod carregam. Um `if ISOvenUI then` no corpo do arquivo sempre avalia `false`. Usar `Events.OnGameStart.Add()` para garantir que a classe já foi carregada antes de sobrescrever métodos.
