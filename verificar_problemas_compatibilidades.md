# Relatório de Problemas e Compatibilidades

> **Data:** 16/06/2026
> **Build do Jogo:** 42.19.0
> **Fonte:** Logs `console_sanitizado.txt` e `console_erros.txt`

---

## ⚠️ Problema Crítico: Espaço em Disco Insuficiente

```
Disk info: 118.24 Gb, free space: 1.60 Gb, usable space: 1.60 Gb
```

O sistema possui apenas **1.60 GB de espaço livre**. O Project Zomboid precisa de espaço para:
- Saves de mundo (podem ultrapassar 1 GB)
- Cache de texturas e chunks
- Logs do console

**Risco:** O crash pode ter sido causado por falta de espaço ao tentar salvar ou alocar memória. Não há stack trace Java nem Lua no log, o que reforça a hipótese de falha silenciosa do sistema operacional.

**Ação:** Liberar espaço em disco. Mínimo recomendado: 10 GB livres.

---

## 🔴 PoweredBuildings V2 (buildinggenpowerv2) — Conflito de Fagocitação

O mod original `PoweredBuildings V2` **ainda está carregado** junto com o LKS SuperMod Patch, que já absorveu toda a funcionalidade dele. Isso gera **17 warnings** de `require` falhando porque nosso mod renomeou todos os arquivos `PB_*` para `LKS_*`:

```
WARN: PB_ClientInit.lua > require("client/PB_ContextMenu_Generator") failed
WARN: PB_ClientInit.lua > require("client/PB_ContextMenu_LightSwitch") failed
WARN: PB_ClientInit.lua > require("client/PB_ContextMenu_LightSwitchInstall") failed
WARN: PB_ClientInit.lua > require("shared/actions/PB_Actions_LinkBarrel") failed
WARN: PB_ClientInit.lua > require("client/PB_ContextMenu_Barrel") failed
WARN: PB_ClientInit.lua > require("client/ui/PB_UI_GeneratorInfoWindow") failed
WARN: PB_ClientInit.lua > require("client/PB_Heating_Client") failed
WARN: PB_ClientInit.lua > require("client/PB_Power_ClientSync") failed
WARN: PB_ClientInit.lua > require("client/PB_ClientCommands") failed
... (+ 8 warnings em shared/actions)
```

Além disso, o StateManager detecta **dupla inicialização**:
```
[PoweredBuildings][WARN] [StateManager.Initialize] Already initialized
```

**Causa:** O `mod.info` do LKS declara incompatibilidade via `incompatible=`, mas o mod original ainda está na lista de mods ativos do save/servidor.

**Ação:** Desativar o mod `buildinggenpowerv2` na lista de mods. Ambos não podem coexistir — nosso mod substitui completamente o original.

---

## 🟡 Warnings Vanilla (Não-Bloqueantes)

Estes são warnings do **jogo base** (Build 42.19.0), não do nosso mod. Não requerem ação mas devem ser monitorados:

| Warning | Origem | Impacto |
|---------|--------|---------|
| `require("ISUI/ISInventoryPaneContextMenu") failed` | Vanilla (`corpseStorageCheck`) | Baixo — lazy-load falhando na fase de init |
| `require("ISUI/ISVehicleMenu") failed` | Vanilla (`corpseStorageCheck`) | Baixo — mesmo padrão |
| `require("ISUI/ISContextMenu") failed` | Vanilla (`corpseStorageCheck`) | Baixo — carregamento fora de ordem |
| `require("Camping/CCampfireSystem") failed` | Vanilla (`ISCampingMenu`) | Baixo — sistema de camping não carregado ainda |
| `require("TimedActions/ISInventoryTransferAction") failed` | Vanilla | Baixo — carregamento antecipado |
| `namedColorToTable color not found: ProgressYellow` | Vanilla (`env.lua`) | Cosmético — cor ausente na paleta |

**Nota:** Estes warnings aparecem em qualquer instalação do B42 com ou sem mods. São bugs conhecidos do engine.

---

## 🟡 Warnings de Outros Mods (Não-Nossos)

| Mod | Warning | Impacto |
|-----|---------|---------|
| TwisTonFire QoL | `require("BuildingObjects/ISMoveableCursor") failed` | Baixo — incompatibilidade com CleanUI detectada e tratada pelo próprio mod |
| MDFT | `require("CharacterCreationProfession") failed` | Baixo — carregamento fora de ordem |

---

## 🟡 Erros de Dados do Jogo (Não-Nossos)

```
ERROR: FluidContainerScript.load > Sanitizing container name 'Large Bucket', name may not contain whitespaces.
ERROR: FluidContainerScript.load > Sanitizing container name 'Fuel Pump', name may not contain whitespaces.
```

**Origem:** Mod `UsefulBarrelsMP` ou jogo base. Nomes de containers com espaços são sanitizados automaticamente pelo engine. Não causa crash.

```
Couldn't find item _Baking_Pan
Couldn't find item _Baking_Tray
Couldn't find item _Cooking_Pot
Couldn't find item _Fine_Butter_Knives
Couldn't find item _Fine_Forks
```

**Origem:** Itens referenciados sem prefixo de módulo (falta `Base.` ou outro namespace). Provavelmente de um mod de culinária ou do jogo base. Não causa crash.

---

## 🟡 Ícones Ausentes

```
WARN: XuiSkin > Could not find icon: Build_AnvilStone, script = Bigorna de Pedra
WARN: XuiSkin > Could not find icon: recreational_01_13, script = Piano
```

**Origem:** Ícones de crafting/construção não encontrados. Pode ser do jogo base ou de um mod de crafting. Repetido 4 vezes (uma por cada tela de jogo). Impacto apenas visual.

---

## ✅ LKS SuperMod Patch — Status de Carregamento

Todos os módulos do nosso mod carregaram **sem erros**:

```
✅ 0_LKS_EletricidadeConstrucao_Init.lua
✅ LKS_Device_Cooking.lua
✅ LKS_Device_Laundry.lua
✅ LKS_Device_Refrigeration.lua
✅ LKS_ApplianceManager.lua
✅ LKS_Debug_Tool.lua
✅ LKS_EletricidadeConstrucao_ClientInit.lua
✅ LKS_EletricidadeConstrucao_ContextMenu_Generator.lua
✅ LKS_EletricidadeConstrucao_ContextMenu_Barrel.lua
✅ LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow.lua
✅ LKS_EletricidadeConstrucao_Power_ClientSync.lua
✅ LKS_EletricidadeConstrucao_UI_DebugPanel.lua (redirecionado)
```

---

## Resumo de Ações

| Prioridade | Ação | Tipo |
|------------|------|------|
| 🔴 URGENTE | Liberar espaço em disco (mínimo 10 GB livres) | Sistema |
| 🔴 URGENTE | Desativar o mod `buildinggenpowerv2` da lista de mods | Configuração |
| 🟡 FUTURO | Monitorar se os warnings vanilla desaparecem em updates do B42 | Observação |
| 🟡 FUTURO | Auditar colisão com `UsefulBarrelsMP` (dívida técnica do roadmap) | Desenvolvimento |
