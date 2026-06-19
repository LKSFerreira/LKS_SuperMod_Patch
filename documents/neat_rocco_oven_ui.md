# Neat Rocco UI — NR_OvenPanel (Janela de Fogão)

Documentação técnica do mod **Neat Rocco UI** (`Neat_Rocco`) e do **NeatUI Framework** (`NeatUI_Framework`), com foco na janela de fogão `NR_OvenPanel` que substitui a `ISOvenUI` vanilla.

> **Por que documentar:** O LKS SuperMod Patch faz monkey-patch do `NR_OvenPanel` para integrar propano ao toggle de energia. Entender a hierarquia, o lifecycle e as armadilhas é essencial para manter a compatibilidade.

---

## Hierarquia de Classes

```
ISPanelJoypad (vanilla PZ)
 └── NR_BasePanel (NR_Utils/NR_BasePanel.lua)
      └── NR_OvenPanel (NR_Bake/NR_OvenPanel.lua)

ISTableLayout (vanilla PZ)
 └── NR_Header (NR_Utils/NR_Header.lua)

ISButton (vanilla PZ)
 └── NI_SquareButton (NeatUI_Framework — neatui_framework/ui/ni_squarebutton.lua)
```

---

## Arquivos-Fonte Relevantes

| Arquivo | Localização | Função |
|---|---|---|
| `NR_OvenPanel.lua` | `Neat_Rocco/42/media/lua/client/NeatRocco/NR_Bake/` | Janela do fogão — substitui `ISOvenUI` |
| `NR_BasePanel.lua` | `Neat_Rocco/42/media/lua/client/NeatRocco/NR_Utils/` | Classe-base de todos os painéis NR |
| `NR_Header.lua` | `Neat_Rocco/42/media/lua/client/NeatRocco/NR_Utils/` | Header com power button, close, minSize |
| `NR_Config.lua` | `Neat_Rocco/42/media/lua/client/NeatRocco/` | Constantes visuais (padding, buttonSize, cores) |
| `ni_squarebutton.lua` | `NeatUI_Framework/42/media/lua/client/neatui_framework/ui/` | Botão quadrado NeatUI (close, info, collapse) |

---

## NR_OvenPanel — Estrutura

### Construtor (`new`)

```lua
function NR_OvenPanel:new(x, y, width, height, oven, character)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.character      = character
    o.playerNum      = character:getPlayerNum()
    o.oven           = oven            -- IsoStove do mundo
    o.hasPowerButton = true            -- Habilita power button no header
    NR_BasePanel.initBase(o)
    return o
end
```

O campo `hasPowerButton = true` é lido pelo `NR_Header` para decidir se cria o botão de energia.

### createChildren — Lifecycle

Ordem de criação:
1. `NR_BasePanel:createChildren(self)` → cria `self.header` (NR_Header)
2. `NR_Header:createChildren()` → cria `rightButtonPanel` com `powerButton` + `closeButton`
3. `NR_OvenPanel:createChildren()` adiciona knobs (temperatura, timer) e botões °C/°F

### Métodos chave

| Método | Retorno | Descrição |
|---|---|---|
| `getHeaderPowerState()` | `"on"`, `"off"`, `"disabled"` | O header chama isso no prerender do powerButton para determinar cor e tooltip |
| `onClickPower()` | void | Chamado pelo header quando o powerButton é clicado |
| `updateButtons()` | void | Atualiza knobs de temperatura e timer a cada frame |
| `getWindowTitle()` | string | Retorna `getText("IGUI_ContainerTitle_stove")` |
| `getWindowIcon()` | Texture | Ícone do fogão no header |

---

## NR_Header — Power Button

O power button é criado como `ISButton` (NÃO `NI_SquareButton`) dentro de `NR_Header:createRightButtonPanel()`:

```lua
self.powerButton = ISButton:new(curX, buttonY, bsz * 2, bsz, "", self, NR_Header.onClickPower)
self.powerButton:initialise()
self.powerButton:setDisplayBackground(false)
```

### Prerender customizado (closure)

O NR substitui **completamente** o `prerender` do ISButton por uma closure:

```lua
self.powerButton.prerender = function(btn)
    local state = _self.parentWindow:getHeaderPowerState() or "off"
    local r, g, b, icon
    if state == "on" then
        r, g, b = 0.2, 0.7, 0.3       -- verde
        icon = iconOn
        btn.tooltip = getText("ContextMenu_Turn_Off")
    elseif state == "disabled" then
        r, g, b = NR_Config.panelBg, NR_Config.panelBg, NR_Config.panelBg  -- cinza fundo
        icon = iconOff
        btn.tooltip = nil               -- ← APAGA tooltip
    else
        r, g, b = 0.7, 0.2, 0.2       -- vermelho
        icon = iconOff
        btn.tooltip = getText("ContextMenu_Turn_On")
    end
    local alpha = btn:isMouseOver() and 0.9 or 0.7
    btn:drawTextureScaled(bgTex,  0, 0, _bsz * 2, _bsz, alpha, r, g, b)
    btn:drawTextureScaled(brdTex, 0, 0, _bsz * 2, _bsz, 1, 0.4, 0.4, 0.4)
    btn:drawTextureScaled(icon,   0, 0, _bsz * 2, _bsz, 1, 0.9, 0.9, 0.9)
end
```

### Bug crítico: `updateTooltip()` nunca é chamado

O `ISButton:prerender()` vanilla (linha 176 de `ISButton.lua`) chama `self:updateTooltip()` — é essa função que cria e exibe o `ISToolTip` quando hover + tooltip != nil.

**Ao substituir o prerender inteiro por uma closure, o NR perde a chamada a `updateTooltip()`.** Consequência: `btn.tooltip` é atribuído mas nunca processado — tooltip nunca aparece no hover, em NENHUM estado (nem "Turn On"/"Turn Off").

**Solução LKS:** No wrapper de prerender do `LKS_Device_Cooking.lua`, chamar `btn:updateTooltip()` no final:

```lua
self.header.powerButton.prerender = function(btn)
    prerenderOriginal(btn)
    if painelRef._lksTooltipPropano then
        btn.tooltip = painelRef._lksTooltipPropano
    end
    btn:updateTooltip()  -- Restaura chamada perdida pelo NR
end
```

---

## NI_SquareButton vs ISButton

O `NI_SquareButton` (NeatUI Framework) herda de `ISButton` mas:

- **Usa `render()` para renderização visual** (não `prerender`)
- Implementa hover interno via `self:isMouseOver()` no `render()`
- Não sobrescreve `prerender` → `updateTooltip()` continua funcionando normalmente
- Suporta estados `isActive` com cores customizáveis

**Conclusão:** Botões `NI_SquareButton` (close, info, collapse) mostram hover e tooltip normalmente. O `powerButton` (`ISButton` com prerender customizado) não mostra porque `updateTooltip()` foi suprimido.

---

## Botões °C e °F

Criados como `ISButton` no `NR_OvenPanel:createChildren()` com prerender customizado similar:

```lua
local function makeUnitBtnPrerender(label, isCelsiusBtn)
    return function(btn)
        local active = (isCelsiusBtn == getCore():isCelsius())
        local hover  = btn:isMouseOver()
        -- Cor laranja quando ativo, cinza quando inativo
        -- Usa texturas Background.png e Boarder.png do NeatUI
        btn:drawTextureScaled(bgTex,  0, 0, bsz, bsz, 0.8, r, g, b)
        btn:drawTextureScaled(brdTex, 0, 0, bsz, bsz, 1, 0.4, 0.4, 0.4)
        btn:drawText(label, ...)
    end
end
```

O LKS substitui esses prerender para usar labels traduzidos (`IGUI_Oven_Celsius` / `IGUI_Oven_Fahrenheit` → "°C"/"°F") e usar `btn:getWidth()` em vez do hardcoded `bsz`.

---

## Knobs (ISKnob)

| Knob | Range | Valores | Função |
|---|---|---|---|
| `tempKnob` | 0-270° | 0, 50, 100, 150, 200, 250, 300 (temperatura) | Define `oven:setMaxTemperature()` |
| `timerKnob` | 0-270° | 0, 1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50, 60, 90, 120 (minutos) | Define `oven:setTimer()` |

Os knobs são widgets vanilla `ISKnob` com texturas de fundo para Celsius/Fahrenheit:
- `KnobBGCelciusOvenTemp.png` (note: typo "Celcius" é do vanilla)
- `KnobBGFarhenOvenTemp.png` (note: typo "Farhen" é do vanilla)
- `KnobBGOvenTimer.png`

---

## Fluxo de Dados

```
[Jogador clica powerButton]
    → NR_Header:onClickPower()
        → NR_OvenPanel:onClickPower()
            → (LKS) executarTogglePropano(oven, character)
                → acenderFogaoPropano() ou apagarFogaoPropano()
            → (fallback) sendClientCommand('stove', 'setOvenParamsAndToggle')

[Cada frame — prerender do powerButton]
    → (LKS override) NR_OvenPanel:getHeaderPowerState()
        → determinarEstadoFogaoPropano(oven, character)
            → retorna "on"/"off"/"sem_combustivel"/"sem_calor"/"eletricidade"
        → seta self._lksTooltipPropano = motivo
        → retorna "on"/"off"/"disabled" para o NR
    → Prerender renderiza com cor/ícone correspondente
    → (LKS) btn:updateTooltip() exibe tooltip quando hover
```

---

## Constantes Visuais (NR_Config)

| Constante | Uso |
|---|---|
| `NR_Config.headerHeight` | Altura do header (onde ficam os botões) |
| `NR_Config.padding` | Espaçamento entre elementos |
| `NR_Config.buttonSize` | Tamanho dos botões quadrados |
| `NR_Config.panelBg` | Cor de fundo dos painéis (usada como cor "disabled" do powerButton) |
| `NR_Config.headerBg` | Cor de fundo do header |
| `NR_Config.bgAlpha` | Alpha do fundo |

---

## Melhorias Futuras Identificadas

- **Hover visual no powerButton disabled:** Quando o powerButton está "disabled", a cor é `NR_Config.panelBg` (mesma do fundo), tornando o botão quase invisível. Considerar usar uma cor mais distinguível para o estado disabled com propano.
- **Tooltip nos knobs de temperatura:** Investigar se é possível adicionar tooltips aos knobs mostrando a temperatura em °C e °F simultaneamente.
