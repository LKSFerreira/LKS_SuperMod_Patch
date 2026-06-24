# Mecânica de Combustível Sólido — Documentação Técnica

## Visão Geral

O LKS SuperMod Patch reformula completamente o sistema de combustível sólido do PZ Build 42. A lógica é **invertida**: tudo queima **exceto** itens em lista de exclusão. Expande significativamente o que pode virar combustível comparado ao vanilla.

---

## 1. Meios de Fogo Cobertos

| # | Objeto | Container Type | Classe Java | Detecção |
|---|--------|----------------|-------------|----------|
| 1 | Fogueira (Campfire) | `campfire` | IsoObject | `CCampfireSystem` |
| 2 | Braseiro (Cooking Pit) | `brazier` | IsoObject | `CCampfireSystem` |
| 3 | Braseiro Simples (Simple Cooking Pit) | `campfire` | IsoObject | `CCampfireSystem` |
| 4 | Lareira (Fireplace) | `fireplace` | IsoFireplace | `isFireInteractionObject()` |
| 5 | Fogão a Lenha (Wood Stove) | `woodstove` | IsoFireplace | `isFireInteractionObject()` |
| 6 | Churrasqueira a Carvão (Charcoal BBQ) | `barbecue` | IsoFireplace | `isFireInteractionObject() + !isPropaneBBQ()` |
| 7 | Forno Antigo (Old Stove) | `fireplace` | IsoFireplace | `isFireInteractionObject()` |

**Excluído:** Churrasqueira a Propano (`isPropaneBBQ() == true`).

---

## 2. Classificação de Combustível (Lógica Invertida)

### O que NÃO queima (lista de exclusão)

#### Por Tags (`item:getTags()`)
```
hasmetal, metalpiece, smallsheetmetal, sheetmetalsnips, lightmetalsnips,
metalsaw, metalbucket, stone, stonemaul, limestone, concrete,
brokenglass, glass, glassbottle, glassbottlesmall, carbattery,
copperore, coppersource
```

#### Por Categoria (`getDisplayCategory()` / `getCategory()`)
```
Weapon, WeaponPart, WeaponCrafted, WeaponImprovised, Tool, ToolWeapon,
VehicleMaintenance, VehicleMaintenanceWeapon, Ammo, Explosives, Security,
ProtectiveGear, Electronics, Fishing, FishingWeapon, AnimalPartWeapon,
BrokenWeapon, CookingWeapon, GardeningWeapon, HouseholdWeapon,
InstrumentWeapon, JunkWeapon, MaterialWeapon, SportsWeapon
```

#### Por Tipo Específico (exceções explícitas)
```
Paperclip, PaperclipBox, ElectronicsScrap, ScrapMetal, FishingHook,
FishingHookBox, FishingHook_Forged, Needle, Needle_Brass, Needle_Forged,
SutureNeedle, SutureNeedleHolder, Tweezers, Tweezers_Forged,
Forceps_Forged, ScissorsBlunt, ScissorsBluntMedical, Splint,
KnittingNeedles, Bell, EngineParts, CarBatteryCharger, TrapCage,
TrapMouse, Dart
```

#### Condições Especiais
- Itens **favoritos** ou **equipados** → não queimam (proteção contra destruição acidental)
- Itens com **FluidContainer** contendo líquido → não queimam

### O que QUEIMA (tudo que não está na exclusão)

Expansões significativas sobre o vanilla:
- **Couro** (`FabricType == "Leather"`) → QUEIMA (vanilla bloqueava)
- **Sapatos, chapéus, acessórios** (sem FabricType) → QUEIMAM
- **Itens misc** (carteira, borracha, dinheiro, papelada) → QUEIMAM
- **Containers** (mochilas, bolsas, sacolas) → QUEIMAM + conteúdo processado recursivamente
- **Roupas molhadas** → QUEIMAM (com penalidade de eficiência)

---

## 3. Sistema de Eficiência

### Penalidade por Umidade

Roupas molhadas queimam com eficiência reduzida proporcional à umidade:

```
multiplicador = 1.0 - (wetness / 200.0)
```

| Wetness | Eficiência | Exemplo |
|---------|------------|---------|
| 0 (seco) | 100% | Duração normal |
| 50 (meio molhado) | 75% | ¾ da duração |
| 100 (encharcado) | 50% | Metade da duração |

### Penalidade por Falta de Preparação (25%)

Itens jogados diretamente dentro de um container de fogo **aceso** sem usar "Transformar em Combustível":

```
eficiência = 75% (multiplicador 0.75)
```

- Feedback: `jogador:Say("Deveria ter preparado o material antes...")` na primeira vez
- Flag `LKS_FirePenaltyWarned` no modData do container evita repetição

### Combinação de Penalidades

Penalidades são **multiplicativas**:
- Roupa molhada (wetness=100) + sem preparação = 50% × 75% = **37.5%** de eficiência

---

## 4. Processamento Recursivo de Containers

Quando um InventoryContainer (mochila, bolsa, carteira, sacola) é processado como combustível:

1. Percorre todos os itens DENTRO do container
2. Para cada item interno: classifica como combustível ou não-combustível
3. Se o item interno é outro container → recursão (aninhamento ilimitado)
4. Itens combustíveis → consumidos como combustível
5. Itens não-combustíveis → permanecem no container
6. O container em si → classificado separadamente (queima se não tiver FluidContainer com líquido)

### Cenários

| Cenário | Resultado |
|---------|-----------|
| Saco de lixo com 100 roupas | Tudo vira combustível (saco + roupas) |
| Mochila com tábuas + pé de cabra + clips | Tábuas e mochila queimam; pé de cabra e clips sobram |
| Carteira com documento + dinheiro | Tudo queima (carteira + conteúdo) |
| Mochila de hidratação com água (0.8L) | Mochila NÃO queima (FluidContainer); itens dentro são processados |

---

## 5. Interfaces de Usuário

### Menu de Contexto

- **<=6 tipos** de combustível: lista plana (comportamento anterior)
- **>6 tipos**: agrupado por categoria:
  ```
  🔥 Tudo (131)
  Acessório (37) > Todos (37), Item A (5), Item B (3)...
  Vestuário (67) > Todos (67), Camisa (10), Meia (8)...
  Container (5) > ...
  Miscelânea (4) > ...
  ```
- Cada item individual: Um (1) / Metade (N) / Tudo (N)
- "Tudo" por categoria: consome apenas itens daquela categoria

### Botão da Loot Window ("Transformar em Combustível")

Mecânica diferente do menu de contexto:
1. Jogador coloca itens DENTRO do container de fogo
2. Clica "Transformar em Combustível" (alinhado à direita)
3. Personagem anda até o container → TimedAction por item
4. Processamento recursivo de bags/mochilas dentro do container
5. Não-combustíveis permanecem no container

### Consumo Automático (AutoBurn)

- Verifica containers de fogo **acesos** a cada `EveryTenMinutes` (~6s real)
- Raio de 10 tiles ao redor do jogador
- Consome itens dentro com 75% de eficiência (penalidade)
- Processamento recursivo (mochila com roupas → tudo dentro consumido)
- Não-combustíveis intactos

---

## 6. Limitação Conhecida — Renderização Java

O engine Java (`ItemContainer.isItemAllowed`) pode impedir a **exibição visual** de certos itens dentro de containers de fogo, mesmo que estejam fisicamente presentes (peso do container muda).

**Impacto:** Itens que o Java não considera válidos não aparecem na UI do container, mas:
- São processados normalmente pelo AutoBurn
- São processados pelo botão "Transformar em Combustível"
- O peso do container confirma sua presença

**Status:** Limitação do engine, não do mod. Não há workaround via Lua.

---

## 7. Fórmula de Duração

```lua
-- Itens reconhecidos pelo vanilla (tag IsFireFuel ou na tabela campingFuelType):
duração = min(valor_hardcoded, peso × razão) × 60 minutos

-- Itens novos (expandidos pelo LKS):
duração = peso × razão × 60 minutos

-- Razão por tipo:
-- Itens normais: 2/3
-- Roupas, containers, livros, mapas: 1/4
-- Item com FireFuelRatio customizado: usa o ratio definido
```

---

## 8. Preparação para Mecânicas Futuras

### Dano a Não-Combustíveis (flag desabilitada)

```lua
LKS_FIRE_DAMAGE_ENABLED = false  -- ativar quando implementar
LKS_aplicarDanoCalor(item, container)  -- stub sem implementação
```

Intenção futura:
- Plástico: emissão de gás tóxico (reutilizar mecânica de gerador em ambiente fechado)
- Metal: aquecimento (dano de queimadura ao pegar sem luvas)
- Vidro: derretimento parcial (reduz condição)
