# Mecânica de Lavadoras e Secadoras — Documentação Técnica

## Visão Geral

Motor de ciclo Lua que complementa o Java (que não processa itens). Monitora máquinas ativas via `EveryOneMinute`, processa itens ao completar o ciclo e desliga automaticamente.

---

## 1. Tipos de Máquina

| Máquina | Classe Java | Container Type | Requer Água |
|---------|-------------|----------------|-------------|
| Lavadora | `IsoClothingWasher` | `clothingwasher` | Sim |
| Secadora | `IsoClothingDryer` | `clothingdryer` | Não |
| Combo | `IsoCombinationWasherDryer` | `clothingwasher` | Modo Lavagem: Sim / Modo Secagem: Não |

---

## 2. Duração dos Ciclos (Baseado no Peso)

**Lavadora:**
- Base: 60 minutos in-game (até 6kg)
- Excedente: +4 min/kg acima de 6kg
- Fórmula: `60 + max(0, pesoTotal - 6) × 4`

**Secadora:**
- Base: 30 minutos in-game (até 6kg)
- Excedente: +2 min/kg acima de 6kg
- Fórmula: `30 + max(0, pesoTotal - 6) × 2`

**Combo — Ciclo Automático:**
- Fase 1 (Lavagem): duração calculada pela fórmula da lavadora
- Fase 2 (Secagem): duração calculada pela fórmula da secadora
- Total: soma das duas fases

---

## 3. Processamento de Itens

### Lavagem (ao completar ciclo)

3 caminhos possíveis por item:

1. **`getItemAfterCleaning()` existe** — Item substituído pela versão limpa (ex: DenimStripsDirty → DenimStrips, BandageDirty → Bandage)
2. **`instanceof Clothing/InventoryContainer`** — Limpa sangue por parte (`setBlood(part, 0)`), sujeira (`setDirt(part, 0)`, `setDirtiness(0)`), aplica umidade (`setWetness(100)`)
3. **Qualquer item** — Remove sangue geral (`setBloodLevel(0)`)

### Secagem (ao completar ciclo)

- Remove umidade de todos os itens: `setWetness(0)`

### Consumo de Água (Lavadora)

- Consome `min(10, fluidAmount)` unidades de água ao final do ciclo

---

## 4. Sistema de Condição

Armazenado em `modData["LKS_Laundry_Condition"]` (0 a 100, inicia em 100).

**Desgaste:**
- Natural: -1 por ciclo completado
- Item com tag metal (`hasmetal`): -5 por item
- Item de categoria Weapon/Tool: -10 por item
- Item pesado (>5kg): -3 por item

**Efeitos:**
- Condição < 50: ciclo demora +25%
- Condição < 25: ciclo demora +50%
- Condição = 0: máquina não liga (quebrada)

**Feedback:**
- Uso inadequado: `Say("Algo não parecia certo dentro da máquina...")`
- Máquina quebrada: `Say("Esta máquina está quebrada...")`
- Ciclo completo: `Say("A máquina terminou.")`

---

## 5. Ciclo Automático (Combo)

Exclusivo para `IsoCombinationWasherDryer`. Ativação:
- Menu de contexto: opção "Ciclo Automático" com ícone `LKS_Menu_Ciclo_Automatico.png`
- Loot Window: botão [AUTO] verde à direita (com tooltip)

Fluxo:
1. Seta `modData["LKS_Laundry_AutoCycle"] = true`
2. Garante modo lavadora
3. Liga a máquina
4. Fase 1: lavagem → ao completar, muda fase para "secagem"
5. Fase 2: secagem → ao completar, desliga tudo

---

## 6. Arquivos

| Arquivo | Camada | Responsabilidade |
|---------|--------|------------------|
| `devices/laundry/LKS_Laundry_CycleEngine.lua` | Client | Motor de ciclo (EveryOneMinute), processamento, condição |
| `devices/laundry/LKS_Device_Laundry.lua` | Client | Driver de menu de contexto, ícones, toggle, ciclo automático |
| `devices/laundry/LKS_Laundry_AutoCycleHandler.lua` | Client | Handler Loot Window botão [AUTO] |

---

## 7. ModData Utilizados

| Chave | Tipo | Descrição |
|-------|------|-----------|
| `LKS_Laundry_StartTime` | number | Timestamp (minutos) de início do ciclo |
| `LKS_Laundry_AutoCycle` | boolean | Se está em ciclo automático |
| `LKS_Laundry_Phase` | string | Fase atual: "lavagem" ou "secagem" |
| `LKS_Laundry_Condition` | number | Condição da máquina (0-100) |
| `LKS_Laundry_DamageWarned` | boolean | Se já avisou sobre dano |

---

## 8. Limitações e Notas

- O Java controla `isItemAllowed()` — determina quais itens podem ser colocados no container
- O processamento é client-side (funciona em singleplayer, MP precisa validação futura)
- Reparo da máquina: stub preparado, não implementado
- PZ usa Kahlua (Lua 5.1) — não suporta `goto`/labels
- Subpastas de `client/devices/` são scaneadas pelo PZ (confirmado)
