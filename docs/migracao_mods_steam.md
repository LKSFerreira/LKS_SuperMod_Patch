# Migração de Mods — Hydra → Steam Workshop

> **Data:** 2026-06-26
> **Contexto:** Migração da versão pirata (Hydra Launcher) para a versão oficial Steam.
> Todos os mods abaixo estavam instalados manualmente em `C:\Users\LKSFERREIRA\Zomboid\mods\`.
> Após assinar pela Workshop, as pastas manuais podem ser removidas.

---

## 🎮 Mods de Interface (UI/HUD)

| # | Nome do Mod | ID do Mod | Pasta Local |
|---|-------------|-----------|-------------|
| 1 | CleanHotBar | `CleanHotBar` | `CleanHotBar/` |
| 2 | CleanUI [B42.12] | `CleanUI` | `CleanUI/` |
| 3 | NeatUI Framework | `NeatUI_Framework` | `NeatUI_Framework/` |
| 4 | Neat Building [B42.12] | `Neat_Building` | `Neat_Building/` |
| 5 | Neat Building – XP & Mod Display [B42.12] | `Neat_Building_AddonXP` | `NeatBuilding_XP/` |
| 6 | Neat Crafting [B42.12] | `Neat_Crafting` | `Neat_Crafting/` |
| 7 | Neat Crafting – XP & Mod Display [B42.12] | `Neat_Crafting_AddonXP` | `NeatCrafting_XP/` |
| 8 | Neat Rocco's UI | `Neat_Rocco` | `Neat_Rocco/` |
| 9 | Lua Digital Watch UI | `LuaDigitalWatchUI` | `LuaDigitalWatch/` |
| 10 | RYG Progress Indicator | `RYGProgressIndicator` | `RYGProgressIndicator/` |
| 11 | RYG Segmented Progress Indicator | `RYGProgressIndicatorSegmented` | `RYGProgressIndicatorSegmented/` |

## 📊 Mods de Informação

| # | Nome do Mod | ID do Mod | Pasta Local |
|---|-------------|-----------|-------------|
| 12 | Better Clothing Info | `EURY_CLOTHINGINFO` | `BetterClothingInfo/` |
| 13 | More Description for Traits [42.13] | `MoreDescriptionForTraits4213` | `MoreDescriptionForTraits4213/` |
| 14 | More Description for Traits [42.17] – Unofficial Fix | _(sem mod.info)_ | `More Desriptions for Traits [42.17] - Unofficial Fix/` |
| 15 | More Item Information | `MoreItemInformation` | `MoreItemInformation/` |
| 16 | Eu Tenho Esse Livro | `EuTenhoEsseLivro` | `EuTenhoEsseLivro/` |
| 17 | Named Skill VHS Tapes | `NamedSkillVHSTapes` | `Named skill VHS tapes/` |
| 18 | RuneExp | `RUNE-EXP` | `RuneExp/` |

## ⚙️ TwisTonFire — Pacote QoL

| # | Nome do Mod | ID do Mod | Pasta Local |
|---|-------------|-----------|-------------|
| 19 | TwisTonFire – QoL Modpack | `twistresting` | `TwisTonFire - QoL Modpack/` |
| 20 | TwisTonFire – Blacklist | `twistonfireblacklist` | `TwisTonFire - Blacklist/` |
| 21 | TwisTonFire – Calories | `twistcalories` | `TwisTonFire - CALORIES/` |
| 22 | TwisTonFire – Proximity Inventory | `twistonfireinventory` | `TwisTonFire - Inventory/` |
| 23 | TwisTonFire – Map Improvements | `twistmapimprovements` | `TwisTonFire - MapImprovements/` |
| 24 | TwisTonFire – Minimap | `twistminimap` | `TwisTonFire - Minimap/` |
| 25 | TwisTonFire – Orderly Chaos | `twistorderlychaos` | `twistonfire - orderly chaos/` |
| 26 | TwisTonFire – RESTING MOD | `twistrestingmodonly` | `TwisTonFire - RESTINGMOD/` |
| 27 | TwisTonFire – STATS | `twistonfirestats` | `TwisTonFire - Stats/` |

## 🔧 Mods de Gameplay / Mecânicas

| # | Nome do Mod | ID do Mod | Pasta Local |
|---|-------------|-----------|-------------|
| 28 | Auto Mechanics | `AutoMechanics` | `AutoMechanics/` |
| 29 | Fridges Off! | `fridgesoff` | `Fridges Off!/` |
| 30 | PoweredBuildings V2 | `buildinggenpowerv2` | `GeneratorPlus2/` |
| 31 | Light My Fire | `EURY_LIGHTFIRE` | `Light My Fire/` |
| 32 | Realistic Temperature B42.12 | `RC_RealisticColdMod` | `RealisticTemperature/` |
| 33 | [B42] Useful Barrels | `UsefulBarrelsMP` | `UsefulBarrelsMP/` |
| 34 | Every Texture Optimized – Performance mode | `Performance` | `Every Texture Optimized Performance mode/` |

## 🛠️ Mods de Debug / Desenvolvimento

| # | Nome do Mod | ID do Mod | Pasta Local |
|---|-------------|-----------|-------------|
| 35 | Cheat Menu: Reloaded [B42 Fixed] | `CheatMenuReloaded` | `CheatMenuReloaded/` |
| 36 | Just Hide Debug Menu | `JustHideDebugMenu` | `JustHideDebugMenu/` |

## 🌐 Tradução

| # | Nome do Mod | ID do Mod | Pasta Local |
|---|-------------|-----------|-------------|
| 37 | Tradução do Zomboid B42 | `PTBRB42` | `Traducao/` |

## 🧪 Mods Próprios (NÃO migrar — manter manuais)

| # | Nome do Mod | ID do Mod | Pasta Local |
|---|-------------|-----------|-------------|
| 38 | **LKS SuperMod Patch** | `LKSSuperModPatch` | `LKS_SuperMod_Patch/` |
| 39 | LKS Revive | `LKS_Revive` | `LKS_Revive/` |

---

## 📝 Notas de Migração

### Mods fagocitados pelo LKS SuperMod Patch
Os mods abaixo tiveram mecânicas incorporadas ao SuperMod Patch. Após migrar para a Workshop,
verificar se ainda são necessários como dependência ou se podem ser desativados:

- **Fridges Off!** (`fridgesoff`) — mecânica de geladeiras incorporada
- **PoweredBuildings V2** (`buildinggenpowerv2`) — mecânica de construções energizadas incorporada
- **Light My Fire** (`EURY_LIGHTFIRE`) — mecânica de acender fogo incorporada

### Como migrar
1. Abrir Steam → PZ Workshop → pesquisar cada mod pelo **nome exato** da coluna "Nome do Mod"
2. Clicar em "Inscrever-se" (Subscribe)
3. Após o Steam baixar, o mod aparece automaticamente no menu de mods do jogo
4. Remover a pasta manual correspondente de `C:\Users\LKSFERREIRA\Zomboid\mods\`
5. Testar se o save carrega sem erros

### Atenção
- **NÃO remover** as pastas dos mods próprios (LKS_SuperMod_Patch, LKS_Revive)
- Migrar **um por vez** para identificar conflitos
- O mod "More Description for Traits [42.17] - Unofficial Fix" não tem `mod.info` — pode ser uma versão corrompida ou fork
