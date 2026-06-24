# Walkthrough: Motor de Ciclo de Lavanderia

**Data:** 24/06/2026
**Autor:** LKS
**Status:** Funcional (testado em jogo — lavagem confirmada)

## Contexto

O Java do PZ B42 deveria processar itens dentro de lavadoras/secadoras quando ativadas, mas não funciona (itens permanecem sujos após ciclo). Implementação de motor de ciclo Lua complementar que monitora máquinas ativas e executa o processamento.

## Problema Original

- Jogador liga a máquina → Java faz toggle `setActivated(true)` → nada acontece com os itens
- TimedActions vanilla (`ISToggleClothingWasher` etc.) apenas fazem toggle, sem lógica de limpeza
- Toda a mecânica de lavagem/secagem deveria ser Java puro, mas está quebrada no B42

## Solução

Hook `EveryOneMinute` que:
1. Escaneia máquinas ativas ao redor do jogador (raio 7 tiles)
2. Registra timestamp de início ao detectar máquina ligada
3. Calcula duração baseada no peso dos itens (60min base + 4min/kg excedente)
4. Ao completar: processa itens (remove sangue/sujeira, substitui itens dirty, aplica wetness)
5. Desliga a máquina automaticamente

## Arquivos Criados

| Arquivo | Responsabilidade |
|---------|------------------|
| `devices/laundry/LKS_Laundry_CycleEngine.lua` | Motor de ciclo, processamento, condição |
| `devices/laundry/LKS_Laundry_AutoCycleHandler.lua` | Handler Loot Window botão [AUTO] |

## Arquivos Modificados

| Arquivo | Mudança |
|---------|---------|
| `devices/laundry/LKS_Device_Laundry.lua` | Movido de `devices/`, adicionado Ciclo Automático no menu |
| `devices/cooking/LKS_Device_Cooking_Antigo.lua` | Adicionado print de carregamento |
| `devices/cooking/LKS_Device_Cooking.lua` | Movido de `devices/` |
| `devices/refrigeration/LKS_Device_Refrigeration.lua` | Movido de `devices/` |
| Traduções PT-BR/EN | 6 novas chaves de lavanderia |

## Reorganização Estrutural

```
devices/ (antes)           devices/ (depois)
├── LKS_Device_Cooking.lua     ├── cooking/
├── LKS_Device_Laundry.lua     │   ├── LKS_Device_Cooking.lua
├── LKS_Device_Refrigeration.lua│   └── LKS_Device_Cooking_Antigo.lua
└── cooking/                    ├── laundry/
    └── LKS_Device_Cooking_Antigo.lua│   ├── LKS_Device_Laundry.lua
                                │   ├── LKS_Laundry_CycleEngine.lua
                                │   └── LKS_Laundry_AutoCycleHandler.lua
                                └── refrigeration/
                                    └── LKS_Device_Refrigeration.lua
```

## Problemas Encontrados e Soluções

### 1. Arquivo não carregava
**Causa:** Subpasta `laundry/` não existia quando o arquivo foi criado.
**Diagnóstico:** Nenhum print `[LKS PATCH]` no console.
**Solução:** Teste com arquivo dummy confirmou que subpastas de `devices/` SÃO carregadas pelo PZ.

### 2. Erro de sintaxe `goto`
**Causa:** PZ usa Kahlua (Lua 5.1) que NÃO suporta `goto`/labels (feature do Lua 5.2+).
**Solução:** Reescrita de todos os `goto`/`::label::` para estrutura `if/then/end`.

### 3. Itens DenimStripsDirty não lavavam
**Causa:** Itens com `getItemAfterCleaning()` precisam ser substituídos (não apenas limpos).
**Solução:** Adicionado Caso 1 no processarLavagem que remove o item sujo e adiciona a versão limpa.

## Validação

- ✅ Motor carrega (`[LKS PATCH - LKS_Laundry_CycleEngine.lua]` no console)
- ✅ Ciclo monitora minuto a minuto (log `Monitorando: tipo=lavadora decorrido=X/60 min`)
- ✅ DenimStripsDirty → DenimStrips (25 itens substituídos com sucesso)
- ✅ Máquina desliga automaticamente ao final do ciclo
- ✅ Botão [AUTO] aparece na Loot Window do Combo
- ✅ Opção "Ciclo Automático" com ícone no menu de contexto
