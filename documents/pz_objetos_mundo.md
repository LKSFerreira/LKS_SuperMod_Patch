# Objetos do Mundo (IsoObject) — Project Zomboid Build 42

Referência de padrões vanilla para interação com objetos do mundo no PZ B42.

---

## APIs Principais

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

---

## Texturas e Sprites

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

## Armadilhas com objetos Java no Build 42

| Armadilha | Sintoma | Causa | Solução |
|---|---|---|---|
| **Wrapper Java nulo** | `instanceof()` retorna true mas qualquer acesso a método crasha com "Object tried to call nil" | `getObjects():get(i)` pode retornar wrapper com referência interna nula (chunk descarregando, multi-tile destruído) | Validar com `pcall(function() objeto:getX() end)` ANTES de qualquer operação |
| **Getter `isActivated()` não existe em IsoStove B42** | Crash ao chamar `objeto:isActivated()` | IsoStove expõe `Activated()` (getter) e `setActivated()` (setter). `isActivated` é nil. | Usar fallback: `if objeto.Activated then objeto:Activated() elseif objeto.isActivated then objeto:isActivated() end` |
| **`addGeneratorPos` energiza o tile inteiro** | TV/rádio/lâmpada no mesmo tile do fogão a propano ficam "energizados" quando o fogão é aceso | `addGeneratorPos(x,y,z)` marca o tile como alimentado por gerador — afeta TODOS os objetos do tile, não só o fogão | Ver documento dedicado: `pz_energizacao_sem_rede.md` |

---

## Padrão canônico: procurar item no chão ao redor

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
