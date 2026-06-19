# Referência de Padrões Vanilla — Project Zomboid Build 42

Guia prático para consultar **antes** de implementar UI, menu de contexto, tooltip, ícones e integrações de objetos no **LKS SuperMod Patch**.

> **Escopo:** padrões observados nos scripts vanilla de `media/lua/` do Project Zomboid Build 42. Onde não houver ocorrência Lua vanilla explícita, isso é sinalizado.

---

## RULES

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

## 1. Menu de Contexto (ISContextMenu)

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `ISContextMenu:getNew(parentMenu)` | Cria uma nova instância de submenu. | Sempre que uma opção principal abrir filhos. | `ISBBQMenu.lua`: `local bbqMenu = ISContextMenu:getNew(context);` |
| `menuContexto:addSubMenu(opcaoPai, submenu)` | Vincula o submenu à opção pai. | Depois de criar a opção “raiz” do grupo. | `ISBBQMenu.lua`: `context:addSubMenu(bbqOption, bbqMenu);` |
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

## 2. Tooltip (ISToolTip)

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

---

## 3. Texturas e Sprites

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `getTexture(textureName)` | Resolve uma `Texture` por nome/path/sprite. | Sempre que precisar desenhar ícone, sprite ou imagem em menu/tooltip. | `ISBBQMenu.lua`: `getTexture(tile)` antes de gerar ícone. |
| `texture:splitIcon()` | Converte textura/sprite para ícone pequeno usável em menu. | **Obrigatório** ao usar sprite de tile como `iconTexture`. | `ISBBQMenu.lua`: `getTexture(tile):splitIcon();` |
| `object:getSprite():getName()` | Retorna o nome do sprite do objeto no mundo. | Quando a lógica depende da identidade visual/tileset real do objeto. | `MOTrap.lua`: `local spriteName = isoObject:getSprite():getName()` |
| `item:getTex()` | Obtém textura do ícone de inventário do item. | Quando o ícone vem da instância do item. | `ISInventoryPaneContextMenu.lua`: `option.iconTexture = item:getTex():splitIcon();` |
| `item:getIcon()` | Obtém o ícone definido pelo script do item. | Quando o fluxo trabalha com item selecionado/scripted icon. | `ISInventoryPaneContextMenu.lua`: `option.iconTexture = selectedItem:getIcon():splitIcon();` |

### Regra operacional

- **Sprite de mundo em menu:** `getTexture(spriteName):splitIcon()`.
- **Textura já pronta:** `tooltip:setTextureDirectly(texture)`.
- **Tooltip grande de objeto movível:** `tooltip:setTexture(moveProps.spriteName)`.

---

## 4. Objetos do Mundo (IsoObject)

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `ISMoveableSpriteProps.fromObject(object)` | Extrai metadados movíveis do objeto (nome, sprite, grid, regras). | Sempre que a lógica for de desmontagem, pickup, repair ou leitura de props movíveis. | `ISDisassembleMenu.lua`: `local moveProps = ISMoveableSpriteProps.fromObject(object);` |
| `Translator.getMoveableDisplayName(moveProps.name)` | Traduz nome humano do objeto movível. | Ao mostrar nome de fogão, armário, pia, lavadora etc. | `ISDisassembleMenu.lua`: `subMenu:addOption(Translator.getMoveableDisplayName(v.moveProps.name), ...)` |
| `moveProps.spriteName` | Nome do sprite principal do objeto movível. | Quando for usar preview visual em tooltip. | `ISDisassembleMenu.lua`: `toolTip:setTexture(v.moveProps.spriteName);` |
| `object:getModData()` | Acessa dados persistentes customizados no objeto do mapa. | Persistência de estado, combustível, armadilha, água, metadados de construção. | `TrapSystem.lua`: `local modData = isoObject:getModData()` |
| `instanceof(object, "ClassName")` | Verifica tipo Java real do objeto. | Quando o fluxo depende de classe concreta (`IsoLightSwitch`, `IsoDoor`, `IsoStove`, etc.). | `ISDisassembleMenu.lua`: `if instanceof(_v.object,"IsoLightSwitch") and _v.object:hasLightBulb() then` |
| `square:getWorldObjects()` | Retorna itens soltos no chão (`IsoWorldInventoryObject`). | Buscar botijão, pilha, item dropado ou item decorativo no tile. | `ISBBQMenu.lua`: `local wobs = square:getWorldObjects()` |
| `square:getObjects()` | Retorna todos os `IsoObject` do tile. | Varredura estrutural do quadrado: fogão, parede, porta, interruptor, etc. | `ISBBQMenu.lua`: `local object2 = square:getObjects():get(index)` |
| `getCell():getGridSquare(x, y, z)` | Busca um tile por coordenadas. | Scanner local 3x3, busca de vizinhos, adjacência ou varredura de construção. | `ISBBQMenu.lua`: `local square = getCell():getGridSquare(x, y, bbq:getZ())` |

### ⚠️ Armadilhas conhecidas com objetos Java no Build 42

| Armadilha | Sintoma | Causa | Solução |
|---|---|---|---|
| **Wrapper Java nulo** | `instanceof()` retorna true mas qualquer acesso a método crasha com "Object tried to call nil" | `getObjects():get(i)` pode retornar wrapper com referência interna nula (chunk descarregando, multi-tile destruído) | Validar com `pcall(function() objeto:getX() end)` ANTES de qualquer operação |
| **Getter `isActivated()` não existe em IsoStove B42** | Crash ao chamar `objeto:isActivated()` | IsoStove expõe `Activated()` (getter) e `setActivated()` (setter). `isActivated` é nil. | Usar fallback: `if objeto.Activated then objeto:Activated() elseif objeto.isActivated then objeto:isActivated() end` |
| **`addGeneratorPos` energiza o tile inteiro** | TV/rádio/lâmpada no mesmo tile do fogão a propano ficam "energizados" quando o fogão é aceso | `addGeneratorPos(x,y,z)` marca o tile como alimentado por gerador — afeta TODOS os objetos do tile, não só o fogão | Mitigação: na prática, fogões raramente compartilham tile com eletrônicos. Solução definitiva requer API Java para energizar por objeto (não existe em B42). Registrado como dívida técnica. |

---

## 4.1 Guia Definitivo: Energizar Objetos sem Rede Elétrica (B42)

Este guia documenta TODA a investigação realizada para manter IsoStove aceso com propano sem rede elétrica. Aplicável a qualquer mecânica futura que precise energizar objetos individuais.

### O Problema

O motor Java do PZ verifica `ItemContainer:isPowered()` a cada frame para objetos com container (fogão, geladeira, micro-ondas). Se retorna `false`, o motor **desativa o objeto imediatamente**. Não existe forma Lua de prevenir isso.

### APIs Investigadas e Resultado

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

### Solução: `chunk:addGeneratorPos(x, y, z)`

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

### Por que funciona

1. `addGeneratorPos` registra a posição no chunk como "alimentada por gerador"
2. `ItemContainer:isPowered()` verifica internamente se o tile tem gerador → retorna `true`
3. Motor Java vê `isPowered() = true` → mantém fogão ativado sem resistência
4. `ISToggleStoveAction` executa `Toggle()` com sucesso porque agora há "energia"
5. Sem OnTick, sem loop, sem piscar — estado mantido nativamente pelo motor

### Por que a churrasqueira (BBQ) é diferente

A churrasqueira é `IsoFireplace` (não `IsoStove`), marcada como `isFireInteractionObject() = true`. Tem APIs exclusivas (`setPropaneTank`, `addFuel`, `setFuelAmount`) que o motor Java reconhece como fontes de combustível independentes de eletricidade. **IsoStove regular não herda essas APIs.**

### Efeito Colateral

`addGeneratorPos` energiza o TILE, não o objeto. Qualquer outro objeto com container no mesmo tile (geladeira, etc.) também ficará "energizado". Na prática é raro pois fogões ocupam tile próprio.

### Quando usar este padrão

- Manter IsoStove aceso com combustível alternativo (propano, biogás futuro)
- Qualquer mecânica que precise fazer `isPowered() = true` sem rede elétrica
- NÃO usar para IsoFireplace — esse já tem APIs nativas de combustível

### Padrão canônico: procurar item no chão ao redor

```lua
for y=bbq:getY()-1,bbq:getY()+1 do
    for x=bbq:getX()-1,bbq:getX()+1 do
        local square = getCell():getGridSquare(x, y, bbq:getZ())
        if square and not square:isSomethingTo(bbq:getSquare()) then
            local wobs = square:getWorldObjects()
            -- procurar item dropado
        end
    end
end
```

Fonte vanilla: `media/lua/client/ISUI/ISBBQMenu.lua`

---

## 5. Jogador e Inventário

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `getSpecificPlayer(playerNumber)` | Retorna o `IsoPlayer` do índice informado. | Entrada padrão de handlers de contexto/evento. | `ISBBQMenu.lua`: `local playerObj = getSpecificPlayer(player)` |
| `player:getInventory()` | Acessa o inventário do jogador. | Qualquer validação/busca de item antes de criar ação ou opção. | `SpawnItems.lua`: `playerObj:getInventory():getFirstTypeRecurse(...)` |
| `inventory:getFirstTypeRecurse(itemType)` | Busca item recursivamente em inventário/contêineres equipados. | Encontrar ferramenta, combustível, saco, eletrônico, munição, etc. | `ISInventoryBuildMenu.lua`: `playerObj:getInventory():getFirstTypeRecurse("Base.Gravelbag")` |
| `player:getPerkLevel(Perks.PerkName)` | Retorna nível da perícia. | Gate de ação, chance, tooltip ou desbloqueio. | `ISWorldObjectContextMenu.lua`: `if playerObj:getPerkLevel(Perks.Electricity) >= ISLightActions.perkLevel then` |
| `item:getDisplayName()` | Nome traduzido pronto para UI. | Menus, labels, tooltip, debug legível. | `ISInventoryPaneContextMenu.lua`: `local rodOption = context:addOption(fishingRod:getDisplayName());` |
| `item:getFullType()` | Tipo completo `Module.Item`. | Comparações seguras, filtros, serialização e validação de recipe/source. | `ISBBQMenu.lua`: `if o:getItem():getFullType() == "Base.PropaneTank" then` |

### Regra prática de busca

- Para item específico do mod, **prefira tipo completo**: `LKS_Modulo.Item`.
- Mesmo que o vanilla às vezes use tipo curto (`"Battery"`, `"Matches"`), para código novo do LKS o tipo completo é mais seguro.

---

## 6. Tradução e Localização

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `getText(key, ...)` | Resolve texto traduzido com placeholders opcionais. | Labels de menu, tooltip, mensagens de erro e UI dinâmica. | `ISBBQMenu.lua`: `getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(...))` |
| `ItemName_Module.ItemName` | Convenção prática de chave de nome de item usada em mods/UI lookup. | Ao criar nome traduzido de item custom e validar compatibilidade com LKS. | **Vanilla B42 atual:** em `Translate/*/ItemName.json`, o equivalente observado é a chave `"Base.PropaneTank"`; **LKS:** usa `ItemName_LKS_Propano.LKS_Botijao15kg` em `IG_UI.json`. |
| `DisplayName` no script é necessário para `getDisplayName()` funcionar | Apesar de deprecated (warning 42.13), o jogo **requer** `DisplayName` no item script para resolver nomes. Translation keys `ItemName_Module.Item` sozinhas NÃO resolvem sem ele. | Em TODOS os itens novos do mod, sempre incluir `DisplayName = NomeBase,` no script. A tradução em `IG_UI.json` sobrescreve para cada idioma. | Vanilla PropaneTank: `DisplayName = Propane Tank,` + tradução `"Botijão de Gás"` no JSON PT-BR. Sem DisplayName, `getDisplayName()` retorna ID cru. |
| `Translator.getMoveableDisplayName(name)` | Traduz nomes de objetos movíveis do mundo. | Fogão, pia, freezer, máquina de lavar, móveis movíveis. | `ISWorldObjectContextMenu.lua`: `return Translator.getMoveableDisplayName(name)` |

### Observação importante para Build 42

- **Itens vanilla base** estão centralizados em `ItemName.json` com chave `Module.Item`.
- **No ecossistema de mods e no LKS**, ainda é comum lidar com chaves `ItemName_Module.Item` em arquivos como `IG_UI.json`.
- Para objetos do mundo movíveis, **não use `getText` direto**: use `Translator.getMoveableDisplayName()`.

---

## 7. Utilitários

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `ZombRand(n)` | Sorteia inteiro de `0` até `n - 1`. | Escolha aleatória de sprite, lista, efeito ou variação. | `ISSearchManager.lua`: `local pickedIcon = iconList[ZombRand(#iconList) + 1];` |
| `getCell()` | Retorna a célula ativa do mapa. | Buscar tile por coordenada, setar drag object, scanner local. | `ISInventoryBuildMenu.lua`: `getCell():setDrag(ISNaturalFloor:new(...), playerObj:getPlayerNum());` |
| `getTextManager():MeasureStringX(font, text)` | Mede largura de texto em pixels. | Alinhamento de colunas, cálculo de tooltip/layout. | `ISDisassembleMenu.lua`: `local textWid = getTextManager():MeasureStringX(tooltipFont, t1[1].txt);` |
| `ISToolTip.GetFont()` | Retorna a fonte padrão do tooltip. | Quando a medição precisa bater com a renderização real do tooltip. | `ISDisassembleMenu.lua`: `local tooltipFont = ISToolTip.GetFont()` |

---

## 8. Eventos

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `Events.OnFillWorldObjectContextMenu.Add(fn)` | Injeta opções no menu de clique direito do mundo. | Menus de fogão, luz, botijão, gerador, construção, etc. | `corpseStorageCheck.lua`: `Events.OnFillWorldObjectContextMenu.Add(corpseStorageCheck.worldObjectContext)` |
| `Events.OnGameStart.Add(fn)` | Executa inicialização quando o jogo termina de carregar. | Registrar cache, popular dados, montar UI persistente, pós-load. | `SpawnItems.lua`: `Events.OnGameStart.Add(SpawnItems.onNewGame);` |
| `Events.EveryOneMinute.Add(fn)` | Tick a cada minuto do jogo. | Sincronização leve, manutenção periódica, lazy init, auditoria contínua. | `ISPerkLog.lua`: `if isClient() then Events.EveryOneMinute.Add(ISPerkLog.init); end;` |
| `Events.OnReceiveGlobalModData.Add(fn)` | Recebe atualização de `GlobalModData` no client. | Sincronia client/server de estado global do mod. | **Ocorrência Lua vanilla não localizada** nos scripts vanilla B42 analisados; tratar como evento de API disponível e seguir o mesmo padrão de registro quando necessário. |

---

## 9. ISOvenUI — Janela de Configuração do Fogão (Vanilla)

A janela com knobs de Temperatura e Temporizador é **100% vanilla**, definida em `media/lua/client/ISUI/Fireplace/ISOvenUI.lua`.

| Componente | Classe | Função |
|---|---|---|
| `ISOvenUI` | `ISPanelJoypad:derive` | Janela principal com knobs e botões |
| `ISKnob` | Widget vanilla | Knob rotativo para temperatura (0-300) e timer (0-120min) |
| `StoveSettings.lua` | `ISLootWindowObjectControlHandler` | Botão "Configurações" na sidebar do inventário |
| `StoveToggle.lua` | `ISLootWindowObjectControlHandler` | Botão "Ligar/Desligar" na sidebar do inventário |

### Arquivo: `ISOvenUI.lua`

```lua
-- Criação dos knobs
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

### Handlers da Loot Window

```lua
-- StoveSettings.lua e StoveToggle.lua usam o mesmo guard:
function Handler:shouldBeVisible()
    return instanceof(self.object, "IsoStove")
        and (self.container ~= nil) and self.container:isPowered()
end
```

### Opção "Configurações" no menu de contexto

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

### ⚠️ Armadilha: Monkey-patch no load-time

`ISOvenUI` **não existe** quando os arquivos de mod carregam. Um `if ISOvenUI then` no corpo do arquivo sempre avalia `false`. Usar `Events.OnGameStart.Add()` para garantir que a classe já foi carregada antes de sobrescrever métodos.

---

## 10. TimedActions — Animações e Interações Físicas

### Padrão canônico para ação com animação

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

### Caminhada até o objeto + ação enfileirada

```lua
-- walkAdj faz o jogador caminhar até ficar adjacente ao quadrado
-- A TimedAction é enfileirada e só executa após chegar
if luautils.walkAdj(jogador, objeto:getSquare()) then
    ISTimedActionQueue.add(MinhaAction:new(jogador, objeto))
end
```

### Dropar item no chão com offset direcional

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

## 11. Moddata Bidirecional — Padrão de Vínculo entre Objetos

Quando dois objetos do mundo precisam de referência mútua (ex: botijão ↔ fogão), usar moddata em AMBOS os lados com coordenadas como chave de vínculo.

### Padrão

```lua
-- CONECTAR: marca ambos
local dadosFogao = fogao:getModData()
dadosFogao.LKS_BotijaoConectado = true

local dadosBotijao = botijao:getModData()
dadosBotijao.LKS_ConectadoAoFogaoX = fogao:getX()
dadosBotijao.LKS_ConectadoAoFogaoY = fogao:getY()
dadosBotijao.LKS_ConectadoAoFogaoZ = fogao:getZ()

-- DESCONECTAR: limpa ambos (escaneia raio para encontrar o par)
dadosFogao.LKS_BotijaoConectado = nil
dadosBotijao.LKS_ConectadoAoFogaoX = nil
-- ...

-- VALIDAÇÃO DEFENSIVA: no acesso ao menu, confirma que o par físico existe
-- Se moddata diz conectado mas o objeto sumiu → auto-limpa
```

### Vantagens sobre referência unidirecional

- Exclusividade 1:1 garantida (botijão só serve 1 fogão)
- Limpeza automática quando qualquer lado é removido (pickup, destruição, despawn)
- Funciona em multiplayer (moddata é sincronizado pelo engine)
- Botijão no inventário com moddata residual → limpar automaticamente (impossível estar conectado se está no inventário)

### Quando usar

- Qualquer mecânica de conexão física entre objetos do mundo (botijão↔fogão, mangueira↔barril, etc.)
- NÃO usar para relações transitórias (apenas para estado persistente)

---

## Checklist rápido antes de implementar UI/menu no LKS

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
