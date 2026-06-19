# Pesquisa Fase 1 — Fogões e Fornos (Levantamento Técnico)

Documento de pesquisa com todas as descobertas sobre o estado atual do Project Zomboid Build 42 em relação a fogões, fornos, combustíveis e mecânicas de culinária.

**Data**: 18/06/2026
**Status**: ✅ Pesquisa concluída

---

## 1. Classes Java de Aparelhos de Cozinha

O PZ diferencia dois tipos de objetos no engine:

| Classe Java | Container type | Uso | Notas |
|---|---|---|---|
| `IsoStove` | `stove` | Fogões elétricos/gás de cozinha | Controlado por timer + temperatura |
| `IsoFireplace` | `woodstove` / `fireplace` | Fogões a lenha, lareiras, fogueiras | Controlado por combustível sólido |

**Conclusão**: O jogo **já diferencia** fogões elétricos/gás (`IsoStove`) de fogões a lenha (`IsoFireplace`). Não precisamos inventar a separação — ela existe no engine.

---

## 2. Sprites e Tilesets

### Fogões elétricos/gás (`IsoStove`)

- **Tileset**: `appliances_cooking_01`
- **Total de tiles**: ~81 sprites
- **Todas as variações** usam `IsoType = IsoStove` + `container = stove`
- O PZ **não** diferencia visualmente fogão elétrico de fogão a gás — todos são `IsoStove`
- **Implicação**: Precisaremos decidir quais sprites representam cada tipo (convencional vs indução) por aparência visual ou criar novos sprites

### Fogões a lenha / Lareiras (`IsoFireplace`)

- **Tileset**: incluídos em vários tilesets (furniture, appliances)
- **Total de tiles**: ~38 sprites com `container = woodstove` ou `IsoType = IsoFireplace`
- **Propriedades**: `MaterialType = Metal`, `PickUpWeight = 400`, requer `Hammer` para mover
- **Conclusão**: Já existe a categoria "Antigo" implementada nativamente como `IsoFireplace`

---

## 3. API do IsoStove (Fogão Elétrico/Gás)

### Ativação e controle

```lua
-- Server-side: ClientCommands.lua:1063-1076
Commands.stove.setOvenParamsAndToggle = function(player, args)
    -- Encontra IsoStove no quadrado
    -- Define timer (args.timer) e temperatura máxima (args.maxTemp)
    -- Chama obj:Toggle()
end
```

### Condição para uso

```lua
-- Só mostra opções se o fogão tem energia:
stove:getContainer():isPowered()
```

### Interface (UI)

- `ISOvenUI.lua` — UI de configuração do forno (temperatura, timer)
- `StoveToggle.lua` — Toggle ligar/desligar
- `StoveSettings.lua` — Configurações do forno
- Todas verificam `isPowered()` antes de mostrar controles

### Conclusão sobre IsoStove

O `IsoStove` vanilla **requer eletricidade** (`isPowered()`). Não há mecânica nativa de propano encanado/botijão para `IsoStove`. Nossa mecânica de propano precisará **override** do check de `isPowered()` ou uma fonte alternativa de "poder".

---

## 4. API do IsoFireplace (Fogão a Lenha)

### Combustível sólido

Definido em `camping_fuel.lua:14-180`:

**Combustíveis aceitos (itens vanilla)**:

| Item | Categoria | Notas |
|---|---|---|
| `Log` | Combustível sólido | Lenha — duração longa |
| `Plank` | Combustível sólido | Tábua — duração moderada |
| `Charcoal` | Combustível sólido | Carvão |
| `RippedSheets` | Tinder/kindling | Panos rasgados |
| `Sheet` | Tinder/kindling | Lençol |
| `ToiletPaper` | Tinder/kindling | Papel higiênico |
| `Paperbag_*` | Tinder/kindling | Sacos de papel |
| `LighterFluid` | Acelerante líquido | Fluido de isqueiro |
| `Twigs` | Tinder | Galhos pequenos |

### Ignição

O sistema verifica `ItemTag.START_FIRE` ou tipos `"Lighter"` / `"Matches"` no inventário.

### Controle server-side

```lua
Commands.fireplace.setFuel  -- Define combustível adicionado
```

### Conclusão sobre IsoFireplace

A mecânica de **fogão antigo (lenha) já existe completa** no vanilla. Precisamos apenas:
- Garantir que nosso mod reconhece `IsoFireplace` como tipo "Antigo"
- Adicionar a mecânica de qualidade de comida / chance de queimar sobre o sistema existente

---

## 5. PropaneTank (Botijão de Gás)

### Definição no jogo

```
item PropaneTank {
    DisplayCategory = Material,
    ItemType = base:drainable,
    Weight = 10.0,
    WeightEmpty = 5.0,
    Icon = PropaneTank,
    UseDelta = 0.0002,
    UseWhileEquipped = false,
    UseWorldItem = true,
    cantBeConsolided = true,
    WorldStaticModel = PropaneTank,
    KeepOnDeplete = true,
    Tags = base:hasmetal;base:smeltablesteellarge,
}
```

### Mecânica existente

- **Usado em**: Churrasqueira a gás (`ISBBQMenu.lua`)
- **API disponível**:
  - `hasPropaneTank()` — verifica se aparelho tem tanque
  - `getAttachedPropaneTank()` — obtém o tanque
  - `setAttachedPropaneTank(tank)` — conecta tanque
  - `FindPropaneTank` — busca no inventário
  - `onInsertPropaneTank` / `onRemovePropaneTank` — ações de inserir/remover
- **Tipo**: `Drainable` com `UseDelta = 0.0002` (drena muito lentamente)
- **Peso**: 10kg cheio, 5kg vazio
- **Cabe no inventário**: ✅ Sim (peso 10 é carregável)

### Conclusão sobre PropaneTank

O **botijão vanilla É o nosso "Botijão Vanilla (Pequeno)"** — já existe, pesa 10kg, cabe no inventário. A API `hasPropaneTank()` / `setAttachedPropaneTank()` pode ser reutilizada para conectar botijões aos fogões. Precisamos criar:
- Botijão de 15kg (não cabe no inventário — `UseWorldItem = true` com peso impeditivo ou flag)
- Botijão de 45kg (mesma abordagem com mecânica de arrasto)

---

## 6. Fontes de Calor / Ignição (Vanilla)

### Itens confirmados no jogo base

| Item ID | Nome | Tag | Tipo | Peso | Durabilidade |
|---|---|---|---|---|---|
| `Lighter` | Isqueiro (Zippo) | — | Drainable | 0.1 | `ticksPerEquipUse = 130` |
| `LighterDisposable` | Isqueiro descartável | — | Drainable | 0.1 | `ticksPerEquipUse = 110` |
| `LighterBBQ` | Isqueiro de churrasco | — | Drainable | 0.3 | `ticksPerEquipUse = 110` |
| `Lighter_Battery` | Isqueiro craftado (pilha) | `startfire` | Drainable | 0.1 | `UseDelta = 0.05` |
| `Matches` | Fósforos | `startfire` | Drainable | 0.1 | `UseDelta = 0.1` (10 usos) |
| `MagnesiumFirestarter` | Acendedor de magnésio | `startfire` | Drainable | 0.1 | `UseDelta = 0.02` (50 usos) |
| `CandleLit` | Vela acesa | — | — | — | Fonte de fogo ativa |

### Detecção de fonte de calor

O jogo usa **duas formas** para detectar:
1. `ItemTag.START_FIRE` — tag genérica para itens que acendem fogo
2. Verificação de tipo: `"Lighter"` ou `"Matches"`

### Item especial: `Lighter_Battery`

**Já existe no vanilla** um isqueiro craftável com pilha! Tags: `base:hasmetal;base:lighter;base:startfire`. Receita `MakeImprovisedLighter` desbloqueada por Burglar, Electrician e Engineer. Funciona como isqueiro reutilizável.

### Pilha + Palha de Aço (item novo do mod)

Reutilizamos a **mecânica base** do `Lighter_Battery` (tag `startfire`, tipo `Drainable`), mas o item é completamente diferente:

| Aspecto | `Lighter_Battery` (vanilla) | Pilha + Palha de Aço (mod) |
|---|---|---|
| Uso | Reutilizável | Consumível (uso único) |
| Sprite | Isqueiro craftado | **Novo** — pilha encostada na palha de aço |
| Som | `UseLighter` (click de isqueiro) | **Novo** — ignição rápida, palha queimando (*fssshh*) |
| Nome | Improvised Lighter | **Acendedor Improvisado** |
| Resultado | Pilha perde carga | Palha consumida + pilha perde 20% |

**Assets necessários**:
- [ ] Sprite/ícone do item (PNG para inventário)
- [ ] Modelo 3D ou sprite de mundo (WorldStaticModel)
- [ ] Efeito sonoro de ignição (curto, agressivo — som de curto-circuito + palha pegando fogo)

---

## 7. Baterias

### Tipos existentes

| Item ID | Nome | Peso | UseDelta | Notas |
|---|---|---|---|---|
| `Battery` | Pilha comum | 0.1 | 0.007 | Para lanternas, rádios |
| `CarBattery1` | Bateria de carro (tipo 1) | 5.0 | 0.00001 | `VehicleType = 1` |
| `CarBattery2` | Bateria de carro (tipo 2) | 5.0 | 0.00001 | `VehicleType = 2` |
| `CarBattery3` | Bateria de carro (tipo 3) | 5.0 | 0.00001 | `VehicleType = 3` |

### API de carga

- Baterias são `Drainable` — usam `getUsedDelta()` / `setUsedDelta()` para carga
- `UseDelta` controla quanto drena por uso
- `CarBattery` tem `ConditionMax = 100` e `ChanceToSpawnDamaged = 30`

### Conclusão

Baterias de carro existem e têm API de drenagem. O "modo emergência" do fogão de indução pode usar `CarBattery1/2/3` drenando via `setUsedDelta()`.

---

## 8. Componentes Eletrônicos (Bobina, Inversor, Transformador)

### Pesquisa no vanilla

| Item procurado | Existe? | Alternativa vanilla |
|---|---|---|
| Bobina / Coil | ❌ **Não existe** | — |
| Inversor / Inverter | ❌ **Não existe** | — |
| Transformador / Transformer | ❌ **Não existe** | — |
| ElectronicsScrap | ✅ Existe | Sucata eletrônica genérica (peso 0.1) |
| MotionSensor | ✅ Existe | Sensor de movimento |

### Conclusão

**Bobina, Inversor e Transformador são itens novos** que o mod precisará criar. `ElectronicsScrap` pode ser componente intermediário para craft desses itens.

---

## 9. Sistema de Cooking (Qualidade de Comida)

### Como funciona

- Comidas usam propriedades em `food.txt`:
  - `IsCookable` — pode ser cozida
  - `MinutesToCook` — tempo de cozimento
  - `MinutesToBurn` — tempo para queimar após cozido
  - `GoodHot` — bônus quando quente
  - `RemoveUnhappinessWhenCooked` — remove unhappiness ao cozinhar
  - `DangerousUncooked` — perigoso cru (food poisoning)
  - `OnCooked` — callback ao finalizar cozimento

### Transição de estados

O engine Java controla a transição: `Uncooked → Cooked → Burned`
- A Lua não faz a transição diretamente — é o engine que monitora `MinutesToBurn` após `MinutesToCook`
- O cooking skill **não afeta** diretamente a chance de queimar no vanilla — isso é baseado em tempo no forno

### Receitas

Formato em `recipes_cooking.txt`:
```
craftRecipe NomeDaReceita {
    timedAction = ...,
    time = ...,
    category = Cooking,
    xpAward = Cooking:3,
    inputs { ... },
    outputs { ... }
}
```

### Conclusão

O vanilla **não tem** sistema de qualidade progressiva (Normal/Boa/Excelente). A comida é: crua, cozida ou queimada. Nossa mecânica de qualidade será **inteiramente nova** — uma camada adicional sobre o sistema existente.

---

## 10. Resumo de Decisões para Implementação

### O que podemos reutilizar diretamente

| Mecânica | Status | Como usar |
|---|---|---|
| `IsoFireplace` + combustível sólido | ✅ Pronto no vanilla | Fogão Antigo = `IsoFireplace` nativo |
| `PropaneTank` + API `hasPropaneTank()` | ✅ Pronto no vanilla | Base para botijões |
| `ItemTag.START_FIRE` | ✅ Pronto no vanilla | Validação de fontes de calor |
| `isPowered()` para IsoStove | ✅ Pronto no vanilla | Check de eletricidade |
| Baterias com `UsedDelta` | ✅ Pronto no vanilla | Modo emergência indução |

### O que precisamos criar do zero

| Item/Mecânica | Tipo | Prioridade |
|---|---|---|
| Botijão 15kg | Item novo (não-inventário) | Fase 5 |
| Botijão 45kg | Item novo (arrasto) | Fase 5 |
| Sistema de propano encanado | Lógica nova (baseada em água) | Fase 2 |
| Fogão de indução | Item craftável novo | Fase 4 |
| Bobina | Item novo | Fase 4 |
| Inversor de corrente | Item novo | Fase 9 |
| Mini transformador | Item novo | Fase 9 |
| Sistema de qualidade de comida | Lógica nova | Fase 6 |
| Manual do Fogão (easter egg) | Item lore | Fase 6+ |
| Revista de elétrica (receita indução) | Item de skill | Fase 4 |

### O que o PZ já NÃO diferencia (e nós faremos)

| Aspecto | Vanilla | Nossa proposta |
|---|---|---|
| Fogão a gás vs elétrico | Mesmo `IsoStove` | Separar por sprite ou moddata |
| Qualidade da comida | Binário (cozido/queimado) | 4 níveis (Ruim/Normal/Boa/Excelente) |
| Gás como utilidade | Não existe | Novo recurso com corte programado |
| Limpeza do fogão | Não existe | Status progressivo de sujeira |
