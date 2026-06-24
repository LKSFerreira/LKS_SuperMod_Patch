# Combustível Sólido e Materiais — Referência Técnica do PZ Build 42

Este documento mapeia todos os meios de fogo que aceitam combustível sólido e os sistemas de classificação de materiais de itens no Project Zomboid Build 42. Pesquisa realizada diretamente no código-fonte do jogo.

---

## 1. Meios de Fogo com Combustível Sólido

### 1.1 Visão Geral

O PZ possui **dois sistemas independentes** para detecção de objetos de fogo:

1. **`CCampfireSystem`** — Sistema global de fogueiras. Detecta objetos com `getName() == "Campfire"`.
2. **`isFireInteractionObject()`** — Método Java presente em `IsoFireplace`. Cobre lareiras, fogões a lenha, BBQs e fornos antigos.

O menu de contexto vanilla usa ambos os sistemas separadamente (`ISCampingMenu.doCampingMenu` para fogueiras, `ISBBQMenu.OnFillWorldObjectContextMenu` para fire interaction tiles). O nosso mod unifica ambos em `LKS_Menu_Fire_FuelSolid.lua`.

### 1.2 Lista Completa de Objetos

| # | Objeto (PT-BR) | Objeto (EN) | Classe Java | Container Type | Sistema de Detecção |
|---|----------------|-------------|-------------|----------------|---------------------|
| 1 | Fogueira | Campfire | `IsoObject` | `campfire` | `CCampfireSystem.getLuaObjectOnSquare()` |
| 2 | Braseiro | Brazier / Cooking Pit | `IsoObject` | `brazier` | `CCampfireSystem` (mesmo sistema da fogueira) |
| 3 | Braseiro Simples | Simple Cooking Pit | `IsoObject` | `campfire` | `CCampfireSystem` |
| 4 | Lareira | Fireplace | `IsoFireplace` | `fireplace` | `isFireInteractionObject()` |
| 5 | Fogão a Lenha | Wood Stove | `IsoFireplace` | `woodstove` | `isFireInteractionObject()` |
| 6 | Churrasqueira a Carvão | Charcoal BBQ | `IsoFireplace` | `barbecue` | `isFireInteractionObject()` + `isPropaneBBQ() == false` |
| 7 | Forno Antigo | Old Stove / Antique Oven | `IsoFireplace` | `fireplace` | `isFireInteractionObject()` |

**Excluído** (usa propano, não combustível sólido):

| Objeto | Detecção | Motivo da Exclusão |
|--------|----------|-------------------|
| Churrasqueira a Propano (Propane BBQ) | `isPropaneBBQ() == true` | Combustível líquido (propano) |

### 1.3 Diferenças entre os Sistemas

| Aspecto | CCampfireSystem (Fogueiras) | isFireInteractionObject (Tiles) |
|---------|---------------------------|-------------------------------|
| Classe base | `IsoObject` genérico | `IsoFireplace` (classe Java específica) |
| Combustível via | `campfire.fuelAmt` (tabela Lua global) | `obj:getFuelAmount()` (método Java) |
| Estado aceso | `campfire.isLit` (tabela Lua) | `obj:isLit()` (método Java) |
| Timed Action para adicionar fuel | `ISAddFuelAction` | `ISBBQAddFuel` |
| Timed Action para acender | `ISLightFromLiterature` / `ISLightFromKindle` | `ISBBQLightFromLiterature` / `ISBBQLightFromKindle` |
| Timed Action para apagar | `ISCampingMenu.onPutOutCampfire` | `ISBBQExtinguish` |

### 1.4 Tradução de `getTileName()` no Nosso Mod

O vanilla retorna nomes em inglês para `getTileName()`. O nosso mod mantém um mapa de tradução em `LKS_Menu_Fire_FuelSolid.lua`:

```lua
local TRADUCAO_TILE_NAMES = {
    ["Cooking Pit"]        = "Braseiro",
    ["Simple Cooking Pit"] = "Braseiro Simples",
}
```

Os demais (`Fireplace`, `Stove`, `Barbecue`) são traduzidos pelo sistema de `IGUI_ContainerTitle_*` do jogo.

### 1.5 Ícones de Container na Sidebar

Definidos em `ContainerButtonIcons.lua` do vanilla:

| Container Type | Ícone |
|----------------|-------|
| `campfire` | `Container_Campfire.png` |
| `brazier` | `Container_Campfire.png` (mesmo da fogueira) |
| `fireplace` | `Container_Oven.png` |
| `woodstove` | `Container_Oven.png` |
| `barbecue` | `Container_Oven.png` |
| `barbecuepropane` | `Container_Oven.png` |

---

## 2. Tabela de Combustíveis Sólidos

Definida em `media/lua/server/Camping/camping_fuel.lua`. Dois conceitos:

- **Fuel** (`campingFuelType`) — material que alimenta o fogo (mantém aceso).
- **Tinder** (`campingLightFireType`) — material que inicia o fogo (acender).

### 2.1 Sistema Moderno (B42)

O B42 introduziu um sistema **procedural** de combustível baseado em tags e propriedades:

| Mecanismo | Como Funciona |
|-----------|---------------|
| Tag `IsFireFuel` | Item é combustível. Valor = `peso × 2/3` (padrão) ou `peso × 1/4` (roupa/literatura/mapa) |
| Tag `IsFireTinder` | Item é material de ignição (mesma fórmula de valor) |
| Propriedade `FireFuelRatio` | Multiplicador customizado aplicado ao peso. Implica `IsFireFuel` automaticamente |
| Tabela hardcoded `campingFuelType` | Backup/override — o engine usa o **menor** entre o valor hardcoded e o calculado proceduralmente |

### 2.2 Combustíveis Hardcoded (Backup)

| Combustível | Duração (horas) | Notas |
|-------------|-----------------|-------|
| Log (Tora) | 6.0 | Maior duração |
| Plank (Tábua) | 2.0 | Comum |
| PercedWood (Madeira Perfurada) | 2.0 | — |
| TreeBranch (Galho) | 1.0 | — |
| UnusableWood (Madeira Inutilizável) | 1.4 | Madeira danificada |
| GuitarAcoustic (Violão) | 1.0 | Easter egg |
| Charcoal / CharcoalCrafted | 0.5 | Carvão vegetal |
| Pinecone (Pinha) | 0.5 | — |
| WoodenStick / WoodenStick2 | 0.25 | — |
| Twigs (Gravetos) | 0.25 | — |
| DryFirestarterBlock | 0.5 | — |
| BBQStarterFluid | 0.25 | Líquido acendedor |
| LighterFluid | ~0.083 | Fluido de isqueiro |
| Phonebook (Lista Telefônica) | 0.5 | — |
| Paperback (Brochura) | ~0.17 | — |
| Sheet (Lençol) | 0.25 | — |
| RippedSheets (Trapos) | ~0.083 | — |
| ToiletPaper | 0.2 | — |
| Papel/Dinheiro/Cartões | ~0.083 | Diversos itens de papel |
| Papéis de Parede | 0.25 | 7 variantes |
| Sacos de papel/plástico | ~0.017 | Duração mínima |
| Lixo (trash_01_0 a trash_01_53) | 0.25 | 54 tiles de lixo |

### 2.3 Categorias de Combustível

| Categoria | Duração Base (horas) | Condição |
|-----------|---------------------|----------|
| Clothing (Roupas) | 0.25 | Apenas com `FabricType` definido e **não** equipado |
| Literature (Livros) | 0.25 | — |
| Map (Mapas) | 0.25 | — |

### 2.4 Restrições de Queima

- **Couro** (`FabricType == "Leather"`) → **NÃO pode** ser queimado como combustível
- **Roupas molhadas** (`getWetness() > 0`) → **NÃO podem** ser queimadas
- **Roupas sem FabricType** → **NÃO podem** ser queimadas

### 2.5 Limite de Combustível

```lua
function getCampingFuelMax()
    local max = (getSandboxOptions():getOptionByName("MaximumFireFuelHours"):getValue() * 60)
    return max
end
```

Configurável por Sandbox via `MaximumFireFuelHours`. Valor em minutos internamente.

---

## 3. Sistemas de Material no PZ B42

O PZ **não possui** um sistema unificado de material de item. Utiliza **múltiplos sistemas independentes** dependendo do contexto.

### 3.1 Material de Sprites/Objetos do Mundo

Propriedade `Material` (e `Material2`, `Material3`) definida nos tiles dos sprites. Usada pelo sistema Moveables para determinar retorno ao desmontar.

**Fonte:** `ISMoveableSpriteProps.lua` + `ISMoveableDefinitions.lua`

| Material | Descrição | Retorno ao Desmontar |
|----------|-----------|---------------------|
| **Wood** | Madeira — móveis, construções | Tábuas, Pregos |
| **Log** | Toras — objetos rústicos grandes | Toras |
| **Steel** | Aço — máquinas, estruturas metálicas | Parafusos |
| **Plumbing** | Encanamento — pias, vasos, canos | Parafusos |
| **Electric** | Elétrico — aparelhos, fiação | Parafusos |
| **Fabric** | Tecido — sofás, camas, cortinas | Linha, Trapos, Lençol |
| **Leather** | Couro — cadeiras, sofás de couro | Linha, Tiras de Couro |
| **Natural** | Natural — cestos, cercas rústicas | Galhos |
| **Brick** | Tijolo — paredes, fornos, lareiras | Tijolos |
| **Plastic** | Plástico | ⚠️ **Não implementado** (`"currently missing materials to be added later"`) |

### 3.2 FabricType (Roupas)

Propriedade de itens de vestuário. Determina o material de costura necessário para remendar.

**Fonte:** `ClothingRecipesDefinitions.lua` + scripts `clothing.txt`

| FabricType | Material de Reparo | Material Sujo |
|------------|-------------------|---------------|
| **Cotton** | `Base.RippedSheets` (Trapos) | `Base.RippedSheetsDirty` |
| **Denim** | `Base.DenimStrips` (Tiras de Jeans) | `Base.DenimStripsDirty` |
| **Leather** | `Base.LeatherStrips` (Tiras de Couro) | `Base.LeatherStripsDirty` |

**Nota:** Denim e Leather possuem `noSheetRope = true` (não servem para fazer corda de lençol).

### 3.3 Tags de Material (Itens Individuais)

Tags definidas nos scripts de item (`Tags = base:hasmetal;base:glass;...`). Não são categorias exclusivas — um item pode ter múltiplas tags.

| Tag | Significado | Exemplo de Uso |
|-----|------------|----------------|
| `base:hasmetal` | Item contém metal | Detecção para reciclagem |
| `base:metalpiece` | Peça metálica | Componente de craft |
| `base:smallsheetmetal` | Placa de metal pequena | Material de construção |
| `base:glass` | Feito de vidro | — |
| `base:brokenglass` | Vidro quebrado | — |
| `base:stone` | Feito de pedra | — |
| `base:limestone` | Calcário | Material de construção |
| `base:charcoal` | Carvão vegetal | Combustível |
| `base:woodhandle` | Cabo de madeira | Componente de ferramenta |
| `base:concrete` | Concreto | Material de construção |

### 3.4 Propriedade `Material` em Scripts de Itens

Usada raramente em itens individuais (não confundir com Material de sprites).

| Valor | Descrição | Itens Típicos |
|-------|-----------|---------------|
| `Glass_Light` | Vidro leve | Lâmpadas, itens frágeis de vidro |
| `Metal_Light` | Metal leve | Componentes eletrônicos pequenos |

### 3.5 Tags de Combustível

| Tag | Significado | Método de Verificação |
|-----|------------|----------------------|
| `IsFireFuel` | Item serve como combustível | `item:hasTag(ItemTag.IS_FIRE_FUEL)` |
| `IsFireTinder` | Item serve como material de ignição | `item:hasTag(ItemTag.IS_FIRE_TINDER)` |
| `IsFireFuelSingleUse` | Combustível de uso único (não divisível) | `item:hasTag(ItemTag.IS_FIRE_FUEL_SINGLE_USE)` |

### 3.6 Propriedade `FireFuelRatio`

Multiplicador customizado aplicado ao peso do item para calcular valor de combustível. Quando `FireFuelRatio > 0`, o item é automaticamente considerado `IsFireFuel`.

```
Valor de combustível = peso × FireFuelRatio
```

Fórmula padrão (sem FireFuelRatio):
- Itens normais: `peso × 2/3`
- Roupas, livros, mapas: `peso × 1/4`

---

## 4. Resumo dos Sistemas

```
MATERIAL NO PZ B42
│
├── Sprites/Tiles (propriedade "Material")
│   └── Wood, Log, Steel, Plumbing, Electric, Fabric, Leather, Natural, Brick, Plastic*
│
├── Roupas (propriedade "FabricType")
│   └── Cotton, Denim, Leather
│
├── Itens (Tags individuais)
│   ├── Materiais: hasmetal, glass, stone, charcoal, concrete, etc.
│   └── Combustível: IsFireFuel, IsFireTinder, IsFireFuelSingleUse
│
├── Scripts de Itens (propriedade "Material")
│   └── Glass_Light, Metal_Light (uso raro)
│
└── Combustível (tabela hardcoded + sistema procedural)
    ├── campingFuelType → valor em horas por tipo de item
    ├── campingFuelCategory → valor em horas por categoria
    ├── campingLightFireType → materiais de ignição
    └── FireFuelRatio → multiplicador customizado por item

* Plastic está declarado mas não implementado no B42.
```

---

## 5. Fontes Consultadas

| Arquivo | Conteúdo |
|---------|----------|
| `media/lua/server/Camping/camping_fuel.lua` | Tabelas `campingFuelType`, `campingLightFireType`, `campingFuelCategory` |
| `media/lua/shared/Camping/ISCampingMenu.lua` | Lógica de detecção de combustível, FabricType, tags |
| `media/lua/client/ISUI/ISBBQMenu.lua` | Detecção de `isFireInteractionObject()`, propano |
| `media/lua/client/Camping/CCampfireSystem.lua` | Validação de campfire (`getName() == "Campfire"`) |
| `media/lua/shared/Definitions/ContainerButtonIcons.lua` | Mapa de ícones por container type |
| `media/lua/shared/Definitions/ClothingRecipesDefinitions.lua` | Definições de FabricType |
| `media/lua/shared/Moveables/ISMoveableSpriteProps.lua` | Leitura de Material de sprites |
| `docs/data/referencia_ferramentas_materiais_pz.yaml` | Materiais de desmonte e retornos |
| `media/scripts/generated/items/normal.txt` | Tags e propriedades de itens |
| `media/scripts/generated/items/clothing.txt` | FabricType em roupas |
