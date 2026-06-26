# Plano de Implementação — Correção e Melhoria das Máquinas de Lavar e Secar

## Summary

O Java do PZ B42 deveria processar a lavagem/secagem de itens quando a máquina está ativada, mas não está funcionando (itens permanecem sujos após o ciclo). A solução é implementar um **hook Lua complementar** que monitora máquinas ativas e executa o processamento de limpeza/secagem usando as mesmas APIs que o vanilla usa na lavagem manual em pia (`setBlood`, `setDirtiness`, `setWetness`). Sem duplicar lógica — apenas complementar o que o Java deveria fazer mas não faz.

**Referências:**
- Pesquisa: `docs/pesquisa_lavadoras_secadoras.md`
- Driver atual: `common/media/lua/client/devices/LKS_Device_Laundry.lua`
- Walkthrough anterior: `.metadocs/walkthrough/lavadora_e_secadora.md`
- Postmortem: `.metadocs/postmortem/funcionamento_encanamento_e_modos_combo.md`
- ISWashClothing (referência): `media/lua/shared/TimedActions/ISWashClothing.lua`

---

## Fase 1 — Motor de Processamento de Ciclo (Hook Lua)

### Objetivo

Criar hook que monitora máquinas ativas e processa itens quando o ciclo completa.

### Proposed Changes

#### [NEW] `common/media/lua/client/devices/laundry/LKS_Laundry_CycleEngine.lua`

**Conceito de Ciclo:**
- Quando a máquina é ativada (`isActivated() == true`), registrar timestamp de início no `modData`
- A cada tick do evento (`EveryOneMinute` = ~1.6s real), verificar máquinas ativas:
  - Se `tempoAtual - timestampInicio >= duracaoCiclo` → ciclo completo → processar itens
  - Após processar → desligar a máquina automaticamente (`setActivated(false)`)

**Durações de ciclo (em minutos in-game):**
- Lavadora: 60 minutos (1h in-game)
- Secadora: 45 minutos
- Combo (lavagem): 60 minutos
- Combo (secagem): 45 minutos
- Combo (ciclo automático): 105 minutos (60 + 45)

**Processamento da LAVADORA (ciclo completo):**
```lua
-- Para cada item dentro do container:
if instanceof(item, "Clothing") or instanceof(item, "InventoryContainer") then
    -- Limpar sangue por parte
    local coveredParts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
    if coveredParts then
        for j = 0, coveredParts:size() - 1 do
            item:setBlood(coveredParts:get(j), 0)
            item:setDirt(coveredParts:get(j), 0)
        end
    end
    item:setDirtiness(0)
    item:setWetness(100)  -- Roupas saem molhadas da lavadora
end
item:setBloodLevel(0)
-- Consumir água do reservatório
```

**Processamento da SECADORA (ciclo completo):**
```lua
-- Para cada item dentro do container:
item:setWetness(0)
```

**Processamento do COMBO (ciclo automático):**
- Fase 1 (0–60min): Lavagem → aplica lógica da lavadora
- Fase 2 (60–105min): Secagem → aplica lógica da secadora
- Resultado final: itens limpos E secos

---

## Fase 2 — Elegibilidade de Itens

### Objetivo

Expandir quais itens podem ser lavados/secos nas máquinas (além do que o Java permite).

### Regras de Elegibilidade

**LAVADORA — O que pode ser lavado:**
- Roupas (`Clothing`) — qualquer FabricType, incluindo couro
- InventoryContainer (mochilas, bolsas, pochetes, sacolas)
- Sapatos, chapéus, acessórios (tudo que é wearable)
- Itens com `getBloodLevel() > 0` (qualquer item sujo de sangue)
- Itens com `getDirtiness() > 0`
- Tecidos/panos (RippedSheets, DenimStrips, etc.)

**LAVADORA — O que NÃO deveria ser lavado (mas pode, com consequência):**
- Armas (machado, faca, bastão) → lava mas danifica a máquina
- Ferramentas pesadas (martelo, pé de cabra) → lava mas danifica a máquina
- Itens de metal sem tecido → lava mas danifica significativamente

**SECADORA — O que pode ser secado:**
- Qualquer item com `getWetness() > 0`

**SECADORA — O que NÃO deveria ser secado (com consequência):**
- Mesma lógica: itens duros/metálicos danificam a máquina

### Implementação

**Abordagem:** NÃO filtrar pela elegibilidade para IMPEDIR o jogador de colocar itens — o vanilla Java controla `isItemAllowed()` no container. Em vez disso, após o processamento do ciclo, verificar se havia itens inadequados e aplicar penalidade de condição à máquina.

---

## Fase 3 — Sistema de Condição da Máquina

### Objetivo

Máquinas perdem condição com uso. Uso inadequado (itens metálicos/pesados) acelera o desgaste.

### Proposed Changes

**Condição armazenada em `modData`:**
```lua
modData["LKS_MachineCondition"] = 100  -- 0 a 100
```

**Desgaste natural:**
- A cada ciclo completado: -1 de condição (uso normal)

**Desgaste por uso inadequado:**
- Item com tag `hasmetal`: -5 por item
- Item de categoria `Weapon`/`Tool`: -10 por item
- Item pesado (>5kg): -3 por item

**Efeitos da condição baixa:**
- Condição < 50: ciclo demora 25% a mais
- Condição < 25: ciclo demora 50% a mais + chance de 10% de não completar
- Condição = 0: máquina não liga (quebrada)

**Reparo (futuro — apenas stub):**
- Flag `LKS_MACHINE_REPAIR_ENABLED = false`
- Quando habilitado: usar ferramentas + peças para restaurar condição

---

## Fase 4 — Botão "Ciclo Automático" no Combo

### Objetivo

Apenas para `IsoCombinationWasherDryer`: botão que executa lavagem + secagem em sequência sem intervenção.

### Proposed Changes

#### [MODIFY] `common/media/lua/client/devices/LKS_Device_Laundry.lua`

Adicionar opção no submenu do Combo:
- "Ciclo Automático" — ativa a máquina em modo especial
- `modData["LKS_CicloAutomatico"] = true`
- O motor de ciclo detecta essa flag e executa: Lavagem (60min) → Secagem (45min) → Desliga

#### [NEW] Handler da Loot Window para Combo

Botão "Ciclo Automático" visível apenas quando:
- É `IsoCombinationWasherDryer`
- Tem energia
- Tem água
- Não está ativada
- Tem itens dentro

---

## Fase 5 — Feedback Visual e Sonoro

### Objetivo

Informar o jogador sobre o progresso e resultado do ciclo.

### Proposed Changes

- Ao ligar: tooltip no container mostra "Ciclo: XX min restantes"
- Ao completar: `jogador:Say("A máquina terminou.")` se o jogador estiver próximo
- Se houve dano por uso inadequado: `jogador:Say("Algo não parecia certo dentro da máquina...")`
- Som de conclusão (se disponível na API)

---

## Fase 6 — Traduções

Novas chaves PT-BR e EN:
- Ciclo em progresso
- Ciclo completo
- Máquina quebrada
- Uso inadequado detectado
- Ciclo Automático (botão)

---

## Notas Técnicas

### Sobre não duplicar lógica

- Mantemos o toggle vanilla (`ISToggleClothingWasher` etc.) — nosso hook COMPLEMENTA
- Se o Java algum dia corrigir o processamento, nosso hook detecta itens já limpos e não reprocessa (verifica `getBloodLevel() == 0 && getDirtiness() == 0` antes de agir)
- A elegibilidade de colocar itens no container continua controlada pelo Java (`isItemAllowed`)

### Sobre o evento periódico

- `EveryOneMinute` (~1.6s real) é suficiente para verificar máquinas
- Scan: apenas tiles no chunk carregado do jogador (performance)
- Alternativamente: registrar máquinas ativas em tabela global e verificar apenas essas

### Sobre sincronização multiplayer

- `modData` persiste automaticamente
- `sendObjectChange` sincroniza estado entre clients
- Processamento no client que ligou a máquina (evita duplicação em MP)

### Prioridade de implementação

1. Motor de ciclo (core — faz funcionar)
2. Botão Ciclo Automático (Combo)
3. Sistema de condição (consequência)
4. Feedback visual
5. Traduções
