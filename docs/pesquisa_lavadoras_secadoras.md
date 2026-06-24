# Pesquisa: Mecânica de Lavadoras e Secadoras — PZ Build 42

Pesquisa realizada em 24/06/2026 diretamente no código-fonte do PZ Build 42 e no código do LKS SuperMod Patch.

---

## 1. Descoberta Crítica — O Java Processa a Lavagem/Secagem

### O que as TimedActions Lua fazem

As três TimedActions vanilla (`ISToggleClothingWasher`, `ISToggleClothingDryer`, `ISToggleComboWasherDryer`) fazem **apenas toggle do estado ligado/desligado**:

```lua
-- ISToggleClothingWasher:complete()
self.object:setActivated(not self.object:isActivated())
self.object:sendObjectChange(IsoObjectChange.WASHER_STATE)
```

**Nenhuma lógica Lua** limpa sujeira, sangue ou umidade dos itens dentro da máquina. Toda a mecânica de lavagem/secagem é processada pelo **engine Java** nas classes:
- `IsoClothingWasher` (Java)
- `IsoClothingDryer` (Java)
- `IsoCombinationWasherDryer` (Java)

### O que isso significa

Quando a máquina é ativada (`setActivated(true)`), o engine Java:
1. Inicia um timer interno
2. Ao final do ciclo, processa os itens dentro do container
3. **Lavadora**: remove sangue (`setBlood(part, 0)`) e sujeira (`setDirtiness(0)`) + aplica wetness
4. **Secadora**: remove wetness (`setWetness(0)`)

**Se esse processamento Java não está funcionando, o problema pode estar em:**
- A máquina não está realmente energizada (`isPowered()`)
- A máquina não tem água (lavadora)
- O ciclo não completou (tempo insuficiente)
- Bug no engine Java do B42 específico para certos itens
- A máquina está ativada mas `sendObjectChange` não está propagando corretamente

---

## 2. Lavagem Manual em Pias (ISWashClothing)

O vanilla TEM uma mecânica funcional de lavagem que opera via Lua — mas é para **pias/fontes de água**, NÃO para máquinas de lavar.

### APIs Relevantes (do `ISWashClothing:complete()`)

```lua
-- Para Clothing:
item:setBlood(coveredPart, 0)     -- Remove sangue por parte do corpo
item:setDirt(coveredPart, 0)      -- Remove sujeira por parte do corpo
item:setDirtiness(0)              -- Remove sujeira geral (0-100)
item:setWetness(100)              -- Molha a roupa (efeito da lavagem)
item:setBloodLevel(0)             -- Remove nível de sangue geral

-- Para não-Clothing (bandages etc):
item:setBloodLevel(0)             -- Remove sangue

-- Consome água:
sink:useFluid(water)              -- Gasta água da pia
```

### Propriedades de Sujeira/Sangue dos Itens

| Propriedade | API Get | API Set | Tipo | Descrição |
|-------------|---------|---------|------|-----------|
| Sangue (por parte) | `item:getBlood(bodyPart)` | `item:setBlood(bodyPart, 0)` | float 0-1 | Sangue em parte específica do corpo |
| Sangue (geral) | `item:getBloodLevel()` | `item:setBloodLevel(0)` | float 0-1 | Nível global de sangue |
| Sujeira (por parte) | `item:getDirt(bodyPart)` | `item:setDirt(bodyPart, 0)` | float | Sujeira em parte específica |
| Sujeira (geral) | `item:getDirtiness()` | `item:setDirtiness(0)` | float 0-100 | Nível global de sujeira |
| Umidade | `item:getWetness()` | `item:setWetness(valor)` | float 0-100 | Nível de umidade |
| Partes cobertas | `BloodClothingType.getCoveredParts(item:getBloodClothingType())` | — | lista | Partes do corpo que a roupa cobre |

### Sabão

A lavagem manual usa sabão. Sem sabão a lavagem demora 5× mais.

```lua
-- Sabão: DrainableComboItem (barra) ou FluidContainer com CleaningLiquid
soaps = character:getInventory():getSoapList(nil, true)

-- Custo de sabão: 1 uso por parte com sangue
ISWashClothing.GetRequiredSoap(item) -- retorna quantidade de usos necessários

-- Custo de água: base 4 + (sangue×3) + sujeira
ISWashClothing.GetRequiredWater(item) -- retorna unidades de fluido
```

---

## 3. Classes Java das Máquinas

### IsoClothingWasher (Lavadora)

| Método | Descrição |
|--------|-----------|
| `isActivated()` / `setActivated(bool)` | Liga/desliga |
| `getFluidAmount()` | Quantidade de água no reservatório |
| `useFluid(amount)` | Consome água |
| `getContainer()` | Container de itens (tipo `clothingwasher`) |
| `isPowered()` | Se tem energia elétrica (via container) |
| `sendObjectChange(IsoObjectChange.WASHER_STATE)` | Sincroniza estado com server |

### IsoClothingDryer (Secadora)

| Método | Descrição |
|--------|-----------|
| `isActivated()` / `setActivated(bool)` | Liga/desliga |
| `getContainer()` | Container de itens (tipo `clothingdryer`) |
| `isPowered()` | Se tem energia elétrica |
| `sendObjectChange(IsoObjectChange.DRYER_STATE)` | Sincroniza |

### IsoCombinationWasherDryer (Combo)

Herda de `IsoClothingWasher`. APIs adicionais:

| Método | Descrição |
|--------|-----------|
| `isModeWasher()` | True se está em modo lavagem |
| `isModeDryer()` | True se está em modo secagem |
| `setModeWasher()` | Alterna para modo lavagem |
| `setModeDryer()` | Alterna para modo secagem |
| `sendObjectChange(IsoObjectChange.MODE)` | Sincroniza modo |

---

## 4. Estado Atual no LKS SuperMod Patch

### O que já implementamos

1. **Menu de contexto customizado** (`LKS_Device_Laundry.lua`):
   - Ícones de estado (energia, água)
   - Toggle ligar/desligar com validação de energia + água
   - Alternância de modo no Combo
   - Remoção de menus duplicados do Java

2. **Ícones na Loot Window**:
   - Ícone acumulativo (sem energia > sem água > normal)
   - Suporte para Combo com modo

3. **Validação hidráulica**:
   - Lavadora exige água
   - Combo em modo secagem dispensa água
   - Combo em modo lavagem exige água

### O que NÃO implementamos (e está quebrado)

**A mecânica de lavagem/secagem depende 100% do Java.** Nosso mod:
- Apenas faz toggle de `isActivated()` via as TimedActions vanilla
- NÃO implementa nenhuma lógica Lua para limpar sangue, sujeira ou umidade
- Se o Java não está processando os itens ao final do ciclo, nada acontece

**Hipóteses do bug:**
1. O engine Java pode exigir que a máquina fique ligada por tempo suficiente para completar o ciclo
2. O `sendObjectChange` pode não estar propagando corretamente em singleplayer
3. A máquina pode precisar estar conectada ao encanamento (plumbed) para a lavadora funcionar
4. Pode haver um bug no B42 com o processamento Java de itens

---

## 5. Loot Window Handlers Vanilla

O vanilla registra handlers na Loot Window para cada tipo de máquina:

| Handler | Arquivo | Condição de Visibilidade |
|---------|---------|-------------------------|
| `ClothingWasherToggle` | `Handlers/ClothingWasherToggle.lua` | `instanceof IsoClothingWasher` + powered + `fluidAmount > 0` |
| `ClothingDryerToggle` | `Handlers/ClothingDryerToggle.lua` | `instanceof IsoClothingDryer` + powered |
| `CombinationWasherDryerToggle` | `Handlers/CombinationWasherDryerToggle.lua` | `instanceof IsoCombinationWasherDryer` |
| `CombinationWasherDryerSetMode` | `Handlers/CombinationWasherDryerSetMode.lua` | `instanceof IsoCombinationWasherDryer` |

---

## 6. Itens Elegíveis para Lavagem/Secagem

### O que o vanilla aceita (lavagem manual em pia)

```lua
-- ISWashClothing:complete() — aceita QUALQUER item
if instanceof(item, "Clothing") or instanceof(item, "InventoryContainer") then
    -- Lava por partes do corpo (BloodClothingType)
    -- Remove sujeira geral (setDirtiness(0))
    -- Aplica wetness (setWetness(100))
else
    -- Qualquer outro item: apenas setBloodLevel(0)
end
```

O vanilla aceita na lavagem manual:
- `Clothing` — roupas (lava sangue por parte + sujeira + aplica umidade)
- `InventoryContainer` — mochilas, bolsas (mesmo tratamento de Clothing)
- **Qualquer item com `getBloodLevel() > 0`** — armas, ferramentas, tudo (apenas remove sangue)

**Confirmado:** Armas, ferramentas e qualquer item sujo de sangue PODE ser lavado manualmente na pia no vanilla. O menu é construído pelo Java e inclui todos os itens com sangue/sujeira.

---

## 7. Container Types e Restrições

| Máquina | Container Type | Java `isItemAllowed()` |
|---------|---------------|----------------------|
| Lavadora | `clothingwasher` | Controlado pelo Java — pode rejeitar itens não-Clothing |
| Secadora | `clothingdryer` | Controlado pelo Java |
| Combo | `clothingwasher` (herda) | Controlado pelo Java |

**Nota:** O `isItemAllowed()` é Java puro e determina quais itens podem ser colocados/exibidos no container. Se o Java rejeitar um item, ele não aparece na UI mesmo que esteja fisicamente presente.

---

## 8. Fontes Consultadas

| Arquivo | Conteúdo |
|---------|----------|
| `shared/TimedActions/ISToggleClothingWasher.lua` | TimedAction: apenas toggle `setActivated()` |
| `shared/TimedActions/ISToggleClothingDryer.lua` | TimedAction: apenas toggle `setActivated()` |
| `shared/TimedActions/ISToggleComboWasherDryer.lua` | TimedAction: toggle + `sendObjectChange` por modo |
| `shared/TimedActions/ISSetComboWasherDryerMode.lua` | TimedAction: alterna modo washer/dryer |
| `shared/TimedActions/ISWashClothing.lua` | Lavagem manual em pia — lógica completa de limpeza |
| `client/ISUI/ISWorldObjectContextMenu.lua` | Menu vanilla de toggle + lavagem manual |
| `client/ISUI/LootWindow/Handlers/ClothingWasherToggle.lua` | Handler Loot Window lavadora |
| `client/ISUI/LootWindow/Handlers/ClothingDryerToggle.lua` | Handler Loot Window secadora |
| `client/devices/LKS_Device_Laundry.lua` | Nosso driver de lavanderia (menus + ícones) |
| `.metadocs/walkthrough/lavadora_e_secadora.md` | Walkthrough da implementação anterior |
| `.metadocs/postmortem/funcionamento_encanamento_e_modos_combo.md` | Postmortem de encanamento e modos |
