# Suporte Completo de Ícones de Inventário para Lavanderia

Corrigir e expandir a lógica de ícones de inventário (Loot Window) para os 3 tipos de máquinas de lavanderia do PZ B42, incluindo o suporte à Combo Washer Dryer que atualmente não tem tratamento no código.

## Contexto

O jogo tem 3 tipos de máquinas de lavanderia:

| Tipo Java | Container Type | Ícone energizado | Ícone sem energia |
|:---|:---|:---|:---|
| `IsoClothingDryer` | `clothingdryer` | Original do jogo | `LKS_Container_ClothingDryer_Electricity_Off.png` |
| `IsoClothingWasher` | `clothingwasher` | Original do jogo | `LKS_Container_ClothingWasher_Electricity_Off.png` |
| `IsoCombinationWasherDryer` | `clothingwasher` (!) | **Não tem** (reusa lavadora azul) | `Combo_Washer_Dryer_Gray_Electricity_Off.png` |

> [!IMPORTANT]
> A Combo Washer Dryer herda `IsoClothingWasher` no Java e usa o container type `clothingwasher`. Portanto, o `instanceof(objeto, "IsoClothingWasher")` pega AMBAS. Precisamos checar `IsoCombinationWasherDryer` **antes** de `IsoClothingWasher` para diferenciá-las.

## Proposed Changes

### Menu de Contexto e Monkey Patch da Loot Window

#### [MODIFY] [LKS_ContextMenu_WasherDryer.lua](common/media/lua/client/LKS_ContextMenu_WasherDryer.lua)

**1. Tabela centralizada de configuração de ícones (topo do arquivo)**

Criar uma tabela `LKS_ConfiguracaoIconesLavanderia` que mapeia cada tipo de máquina aos seus ícones energizado e desenergizado. Isso desacopla os caminhos de assets da lógica, facilitando futura adição da variante branca.

```lua
local LKS_ConfiguracaoIconesLavanderia = {
    clothingdryer = {
        energizado    = nil,  -- nil = usa ícone original do jogo (ContainerButtonIcons)
        desenergizado = "media/ui/LKS_Container_ClothingDryer_Electricity_Off.png",
    },
    clothingwasher = {
        energizado    = nil,  -- nil = usa ícone original do jogo
        desenergizado = "media/ui/LKS_Container_ClothingWasher_Electricity_Off.png",
    },
    combo_washer_dryer = {
        energizado    = "media/ui/Combo_Washer_Dryer_Gray.png",
        desenergizado = "media/ui/Combo_Washer_Dryer_Gray_Electricity_Off.png",
    },
}
```

**2. Detecção da Combo Washer Dryer no loop de objetos do menu de contexto**

Adicionar `IsoCombinationWasherDryer` **antes** de `IsoClothingWasher` no `for` de detecção, e criar a flag `eComboLavadoraSecadora`:

```lua
local eSecadora = false
local eLavadora = false
local eComboLavadoraSecadora = false

for _, objeto in ipairs(objetosMundo) do
    if instanceof(objeto, "IsoClothingDryer") then
        objetoEletrico = objeto
        eSecadora = true
        break
    elseif instanceof(objeto, "IsoCombinationWasherDryer") then
        objetoEletrico = objeto
        eComboLavadoraSecadora = true
        break
    elseif instanceof(objeto, "IsoClothingWasher") then
        objetoEletrico = objeto
        eLavadora = true
        break
    end
end
```

**3. Seleção de ícone/textura baseada na config centralizada**

Substituir os blocos `if eSecadora ... elseif eLavadora` pelo mapeamento via tabela:

```lua
local chaveConfig = nil
if eSecadora then
    chaveConfig = "clothingdryer"
elseif eComboLavadoraSecadora then
    chaveConfig = "combo_washer_dryer"
elseif eLavadora then
    chaveConfig = "clothingwasher"
end

local configIcone = LKS_ConfiguracaoIconesLavanderia[chaveConfig]

if configIcone.energizado then
    texturaIconeMenu = getTexture(configIcone.energizado)
else
    -- fallback para ícone nativo do jogo
    texturaIconeMenu = ContainerButtonIcons[chaveConfig == "combo_washer_dryer" and "clothingwasher" or chaveConfig]
                       or getTexture("media/ui/Container_ClothingDryer.png")
end
texturaIconeDesligadoSemEnergia = configIcone.desenergizado
```

**4. Monkey Patch da Loot Window (addContainerButton)**

Expandir a lógica para detectar a Combo (via `instanceof` no objeto pai do container) e aplicar os ícones corretos:

```lua
function ISInventoryPage:addContainerButton(recipiente, textura, nome, dicaContexto)
    local botao = originalAdicionarBotaoContainer(self, recipiente, textura, nome, dicaContexto)
    if not botao or not recipiente then return botao end

    local recipienteTipo = recipiente:getType()
    local objetoPai = recipiente:getParent()

    -- Determina a chave de configuração baseada no tipo de objeto
    local chaveConfig = nil
    if recipienteTipo == "clothingdryer" then
        chaveConfig = "clothingdryer"
    elseif recipienteTipo == "clothingwasher" then
        if objetoPai and instanceof(objetoPai, "IsoCombinationWasherDryer") then
            chaveConfig = "combo_washer_dryer"
        else
            chaveConfig = "clothingwasher"
        end
    end

    if not chaveConfig then return botao end

    local configIcone = LKS_ConfiguracaoIconesLavanderia[chaveConfig]

    if recipiente:isPowered() then
        -- Energizado: aplica ícone customizado se existir (caso da Combo)
        if configIcone.energizado then
            local imagemEnergizada = getTexture(configIcone.energizado)
            if imagemEnergizada then botao:setImage(imagemEnergizada) end
        end
    else
        -- Desenergizado: aplica ícone off correspondente
        if configIcone.desenergizado then
            local imagemDesativada = getTexture(configIcone.desenergizado)
            if imagemDesativada then botao:setImage(imagemDesativada) end
        end
    end

    return botao
end
```

## Open Questions

> [!IMPORTANT]
> **Detecção da Combo via `getParent()`**: O método `recipiente:getParent()` retorna o `IsoObject` pai do container. Preciso confirmar se `instanceof(objetoPai, "IsoCombinationWasherDryer")` funciona corretamente nesse contexto. Se `getParent()` não existir na API do B42, uma alternativa é inspecionar o sprite name do objeto (ex: verificar se contém `"appliances_laundry_01_0"`).

> [!NOTE]
> **Variante branca da lavadora**: O plano já deixa a tabela preparada. Quando você criar o ícone `LKS_Container_ClothingWasher_White_Electricity_Off.png`, basta adicionar uma entrada `clothingwasher_white` na tabela e expandir a detecção para diferenciar pela cor do sprite.

## Verification Plan

### Automated
```bash
python tools/LKS_Tools.py -a
python tools/auditoria_mod.py validar-sintaxe
```

### Manual
1. **Secadora** (Dryer): Verificar ícone original com energia e `LKS_Container_ClothingDryer_Electricity_Off.png` sem energia
2. **Lavadora** (Washer branca/azul): Verificar ícone original com energia e `LKS_Container_ClothingWasher_Electricity_Off.png` sem energia
3. **Combo Washer Dryer**: Verificar `Combo_Washer_Dryer_Gray.png` com energia e `Combo_Washer_Dryer_Gray_Electricity_Off.png` sem energia
4. **Menu de contexto**: Verificar que as 3 máquinas exibem ícone correto no submenu e tooltips de erro
