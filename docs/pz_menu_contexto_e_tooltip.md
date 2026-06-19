# Menu de Contexto e Tooltip — Project Zomboid Build 42

Referência de padrões vanilla para menus de contexto (`ISContextMenu`) e tooltips (`ISToolTip`) no PZ B42.

> **Escopo:** padrões observados nos scripts vanilla de `media/lua/` do Project Zomboid Build 42.

---

## Regras Obrigatórias

1. **SEMPRE verificar se já existe padrão vanilla antes de criar lógica custom.** Procure primeiro em `ISWorldObjectContextMenu.lua`, `ISDisassembleMenu.lua`, `ISBBQMenu.lua`, `ISInventoryPaneContextMenu.lua` e `ISFarmingMenu.lua`.
2. **NUNCA instanciar `ISToolTip` manualmente em menu de contexto do mundo para código novo do mod.** Use `ISWorldObjectContextMenu.addToolTip()` e reutilize o pool vanilla. Existem trechos legados vanilla com `ISToolTip:new()`, mas eles **não devem ser copiados** para implementação nova.
3. **SEMPRE usar `splitIcon()` ao usar sprite/tile como ícone de menu.** Sem isso, o sprite do mundo não vira um ícone 32x32 adequado.
4. **SEMPRE usar `Translator.getMoveableDisplayName()` para nome de objeto do mundo movível.** Não confiar em nome cru de sprite/propriedade.
5. **PREFERIR reutilizar sobre reimplementar.** Se o vanilla já faz submenu, tooltip, highlight, busca de tile, tradução ou validação de item, reaproveite o mesmo fluxo.

---

## Arquivos vanilla-canônicos para copiar padrão

- `media/lua/client/ISUI/ISWorldObjectContextMenu.lua`
- `media/lua/client/ISUI/ISDisassembleMenu.lua`
- `media/lua/client/ISUI/ISBBQMenu.lua`
- `media/lua/client/ISUI/ISInventoryPaneContextMenu.lua`
- `media/lua/client/Farming/ISUI/ISFarmingMenu.lua`
- `media/lua/client/BuildingObjects/ISUI/ISInventoryBuildMenu.lua`

---

## Menu de Contexto (ISContextMenu)

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `ISContextMenu:getNew(parentMenu)` | Cria uma nova instância de submenu. | Sempre que uma opção principal abrir filhos. | `ISBBQMenu.lua`: `local bbqMenu = ISContextMenu:getNew(context);` |
| `menuContexto:addSubMenu(opcaoPai, submenu)` | Vincula o submenu à opção pai. | Depois de criar a opção "raiz" do grupo. | `ISBBQMenu.lua`: `context:addSubMenu(bbqOption, bbqMenu);` |
| `option.iconTexture` | Define ícone à esquerda da opção. | Quando a ação precisa identificação visual imediata. | `ISBBQMenu.lua`: `bbqOption.iconTexture = getTexture(tile):splitIcon();` |
| `option.toolTip` | Associa um tooltip à opção. | Quando a opção precisa explicar estado, requisito ou resultado. | `ISWorldObjectContextMenu.lua`: `removeOption.toolTip = tooltip` após preencher carga da bateria. |
| `option.notAvailable` | Desabilita a opção e a deixa vermelha. | Requisito ausente, skill insuficiente, estado inválido. | `ISFarmingMenu.lua`: `option.notAvailable = true;` quando o jogador está com as mãos feridas. |
| `option.onHighlight` | Callback disparado ao destacar a opção. | Quando destacar menu deve iluminar objeto(s) do mundo. | `ISDisassembleMenu.lua`: `option.onHighlight = function(...) ... _object:setHighlighted(...) end` |
| `Events.OnFillWorldObjectContextMenu.Add(handler)` | Registra handler global do menu do mundo. | Sempre que o mod injeta opções de clique direito em objeto do mapa. | `ISInventoryBuildMenu.lua`: `Events.OnFillWorldObjectContextMenu.Add(ISInventoryBuildMenu.doBuildMenu);` |

### Snippet-canônico de submenu

```lua
local bbqOption = context:addOption(bbq:getTileName(), worldobjects, nil)
local bbqMenu = ISContextMenu:getNew(context)
context:addSubMenu(bbqOption, bbqMenu)
```

Fonte vanilla: `media/lua/client/ISUI/ISBBQMenu.lua`

---

## Tooltip (ISToolTip)

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `ISWorldObjectContextMenu.addToolTip()` | Factory com pool de tooltip reutilizável. | **Padrão obrigatório** para tooltips de menu do mundo. | `ISWorldObjectContextMenu.lua`: `local tooltip = ISWorldObjectContextMenu.addToolTip()` em opções de bateria/luz. |
| `tooltip:setTexture(spriteName)` | Exibe sprite/imagem grande à esquerda do tooltip. | Quando o tooltip precisa mostrar o objeto do mundo ou item resultante. | `ISDisassembleMenu.lua`: `toolTip:setTexture(v.moveProps.spriteName);` |
| `tooltip:setTextureDirectly(texture)` | Usa um objeto `Texture` já resolvido. | Quando você já tem a textura pronta e não quer resolver por nome. | `ISInventoryPaneContextMenu.lua`: `tooltip:setTextureDirectly(recipeTexture);` |
| `tooltip.description` | Texto rico com tags (`<RGB>`, `<SETX>`, `<INDENT>`, `<LINE>`). | Para tooltips com múltiplas linhas, requisitos, colunas e cores de feedback. | `ISWorldObjectContextMenu.lua`: `tooltip.description = getText("IGUI_RemainingPercent", ...)` e `ISDisassembleMenu.lua` com colunas alinhadas. |
| Padrão `ISDisassembleMenu` com `<SETX>` + `<INDENT>` | Alinha colunas em tooltip rico. | Quando precisar de label/valor alinhados visualmente sem UI custom. | `ISDisassembleMenu.lua`: `string.format("%s <SETX:%d> <INDENT:%d> ...", ...)` |

### Factory/pool vanilla

```lua
ISWorldObjectContextMenu.addToolTip = function()
    local pool = ISWorldObjectContextMenu.tooltipPool
    if #pool == 0 then
        table.insert(pool, ISToolTip:new())
    end
    local tooltip = table.remove(pool, #pool)
    tooltip:reset()
    table.insert(ISWorldObjectContextMenu.tooltipsUsed, tooltip)
    return tooltip
end
```

Fonte vanilla: `media/lua/client/ISUI/ISWorldObjectContextMenu.lua`

### Padrão canônico de colunas alinhadas

```lua
local tooltipFont = ISToolTip.GetFont()
local textWid = getTextManager():MeasureStringX(tooltipFont, t1[1].txt)
column2 = math.max(column2, textWid + 10)
toolTip.description = string.format(
    "%s <SETX:%d> <INDENT:%d> <RGB:%.2f,%.2f,%.2f> %s",
    toolTip.description, column2, column2, t1[2].r / 255, t1[2].g / 255, t1[2].b / 255, t1[2].txt
)
toolTip.description = toolTip.description .. " <LINE> <INDENT:0> "
```

Fonte vanilla: `media/lua/client/ISUI/ISDisassembleMenu.lua`

### Tooltip em ISButton (fora de menu de contexto)

O `ISButton` vanilla processa tooltips no método `updateTooltip()`, chamado pelo `ISButton:prerender()` (linha 176 de `ISButton.lua`). Se um botão tem o `prerender` substituído por closure customizada, `updateTooltip()` nunca é chamado e tooltips não aparecem.

```lua
-- ISButton:updateTooltip() — verifica hover e exibe ISToolTip
if (self:isMouseOver() or self.joypadFocused) and self.tooltip then
    if not self.tooltipUI then
        self.tooltipUI = ISToolTip:new()
        self.tooltipUI:setOwner(self)
        self.tooltipUI:setAlwaysOnTop(true)
    end
    self.tooltipUI.description = self.tooltip
    self.tooltipUI:setDesiredPosition(getMouseX(), self:getAbsoluteY() + self:getHeight() + 8)
end
```

**Armadilha:** Mods que substituem `ISButton.prerender` (como Neat Rocco UI) perdem a chamada a `updateTooltip()`. Solução: chamar `btn:updateTooltip()` manualmente no final do prerender customizado.

---

## Checklist rápido antes de implementar UI/menu

1. **Existe menu vanilla parecido?** Procure primeiro por domínio: churrasqueira, farming, disassemble, inventory pane, world object.
2. **O nome vem de item ou de objeto do mundo?**
   - Item: `item:getDisplayName()` / tradução de item.
   - Objeto movível: `Translator.getMoveableDisplayName(...)`.
3. **O ícone vem de sprite de tile?** Use `getTexture(spriteName):splitIcon()`.
4. **Vai ter tooltip em menu do mundo?** Use `ISWorldObjectContextMenu.addToolTip()`.
5. **Precisa destacar objeto ao passar mouse?** Use `option.onHighlight` com `setHighlighted`/`setOutlineHighlight`.
6. **Precisa varrer quadrados vizinhos?** Use `getCell():getGridSquare(x, y, z)` + `square:getObjects()` / `square:getWorldObjects()`.
7. **Precisa bloquear opção?** Use `option.notAvailable = true` + tooltip explicando o motivo.

---

## Pós-processamento: injetar ícones em opções vanilla

O evento `OnFillWorldObjectContextMenu` dispara APÓS o vanilla (incluindo código Java de `ISWorldObjectContextMenuLogic.createMenuEntries`) construir o menu. É possível registrar um handler que varre o menu pronto e injeta ícones em opções existentes.

**Armadilha:** Opções criadas pelo Java (como "Pegar" para itens no chão) não são acessíveis via `ipairs(context.options)` de forma confiável. Usar o método vanilla `context:getOptionFromName(texto)` que funciona independente de como a opção foi criada.

```lua
-- Padrão correto para injeção pós-processamento:
local function injetarIcones(jogador, contexto, objetosMundo, teste)
    if teste then return end
    local opcao = contexto:getOptionFromName(getText("ContextMenu_Grab"))
    if opcao and not opcao.iconTexture then
        opcao.iconTexture = getTexture("media/ui/MeuIcone.png")
    end
end
Events.OnFillWorldObjectContextMenu.Add(injetarIcones)
```

## Detectar IsoWorldInventoryObject de item no chão via menu vanilla

Items dropados no chão (`IsoWorldInventoryObject`) têm hitbox minúscula na visão isométrica. A detecção direta via `objetosMundo` só funciona clicando no pixel exato do item. Para detectar de forma confiável:

**Solução:** Extrair a referência do objeto da opção "Posicionamento 3D Estendido" (`ContextMenu_ExtendedPlacement`), que é criada pelo Java com detecção precisa via `IsoObjectPicker`.

```lua
-- A opção vanilla "Posicionamento 3D Estendido" armazena:
--   target = IsoWorldInventoryObject (o item no chão)
--   param1 = IsoPlayer (o jogador)
-- ATENÇÃO: target e param1 estão INVERTIDOS do que se espera!

local textoPlacement = getText("ContextMenu_ExtendedPlacement")
local opcaoPlacement = menuContexto:getOptionFromName(textoPlacement)
if opcaoPlacement and opcaoPlacement.subOption then
    local submenu = menuContexto:getSubMenu(opcaoPlacement.subOption)
    if submenu then
        local opcaoItem = submenu:getOptionFromName(nomeDoItem)
        if opcaoItem and opcaoItem.target then
            local worldItem = opcaoItem.target  -- IsoWorldInventoryObject
            local item = worldItem:getItem()    -- InventoryItem
        end
    end
end
```

**Por que funciona:** O Java `ISWorldObjectContextMenuLogic.createMenuEntries` usa `IsoObjectPicker` internamente para detectar items com projeção 3D→2D precisa. A opção é criada ANTES do evento `OnFillWorldObjectContextMenu` disparar, então sempre está disponível no menu quando nosso handler roda.

**Por que `ipairs(options)` não funciona:** Opções criadas pelo Java podem usar indexação diferente. Usar `getOptionFromName(nome)` é seguro e testado pelo vanilla.

**Armadilha:** O campo `param1` contém o **IsoPlayer**, NÃO o item. O item está em `target`. Verificado via debug em 19/06/2026.

---

## Módulo LKS_Icons — Ícones centralizados do mod

Arquivo: `common/media/lua/shared/LKS_Icons.lua`

Registro único de paths de ícones. Toda referência a textura de menu deve usar este módulo:

```lua
local LKS_Icons = require("LKS_Icons")

-- Em menus customizados do mod:
opcao.iconTexture = getTexture(LKS_Icons.PEGAR)
opcao.iconTexture = getTexture(LKS_Icons.CONECTAR)
opcao.iconTexture = getTexture(LKS_Icons.DESCONECTAR)
opcao.iconTexture = getTexture(LKS_Icons.LIGAR)
opcao.iconTexture = getTexture(LKS_Icons.DESLIGAR)
```

### Hook global automático (`LKS_ContextMenu_Icons.lua`)

O arquivo `LKS_ContextMenu_Icons.lua` registra um handler em `OnFillWorldObjectContextMenu` que **automaticamente** injeta `LKS_Icons.PEGAR` em qualquer opção vanilla com texto "Pegar" / "Grab" (inclui variantes: Grab_one, Grab_half, Grab_all, GeneratorTake).

**Não é necessário código adicional** para objetos vanilla — o hook já cobre todos. Só usar `LKS_Icons` manualmente quando criar opções de "Pegar" em menus LKS customizados (ex: botijão).

---

## Resumo operacional

Se a implementação envolver **menu + sprite + tooltip + objeto do mundo**, o fluxo vanilla mais seguro é:

1. detectar objeto com `square:getObjects()` / `instanceof()`;
2. montar opção raiz com `context:addOption(...)`;
3. criar submenu com `ISContextMenu:getNew(...)` + `addSubMenu(...)`;
4. definir `iconTexture` com `getTexture(...):splitIcon()` quando vier de tile;
5. criar tooltip com `ISWorldObjectContextMenu.addToolTip()`;
6. usar `Translator.getMoveableDisplayName()` para nome de objeto movível;
7. usar `option.notAvailable` + tooltip para requisitos;
8. registrar tudo em `Events.OnFillWorldObjectContextMenu.Add(...)`.
