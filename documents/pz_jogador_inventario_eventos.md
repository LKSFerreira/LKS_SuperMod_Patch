# Jogador, Inventário, Tradução e Eventos — Project Zomboid Build 42

Referência de APIs vanilla para jogador, inventário, tradução e sistema de eventos.

---

## Jogador e Inventário

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `getSpecificPlayer(playerNumber)` | Retorna o `IsoPlayer` do índice informado. | Entrada padrão de handlers de contexto/evento. | `ISBBQMenu.lua`: `local playerObj = getSpecificPlayer(player)` |
| `player:getInventory()` | Acessa o inventário do jogador. | Qualquer validação/busca de item antes de criar ação ou opção. | `SpawnItems.lua`: `playerObj:getInventory():getFirstTypeRecurse(...)` |
| `inventory:getFirstTypeRecurse(itemType)` | Busca item recursivamente em inventário/contêineres equipados. | Encontrar ferramenta, combustível, saco, eletrônico, munição, etc. | `ISInventoryBuildMenu.lua`: `playerObj:getInventory():getFirstTypeRecurse("Base.Gravelbag")` |
| `player:getPerkLevel(Perks.PerkName)` | Retorna nível da perícia. | Gate de ação, chance, tooltip ou desbloqueio. | `ISWorldObjectContextMenu.lua`: `if playerObj:getPerkLevel(Perks.Electricity) >= ISLightActions.perkLevel then` |
| `item:getDisplayName()` | Nome traduzido pronto para UI. | Menus, labels, tooltip, debug legível. | `ISInventoryPaneContextMenu.lua`: `local rodOption = context:addOption(fishingRod:getDisplayName());` |
| `item:getFullType()` | Tipo completo `Module.Item`. | Comparações seguras, filtros, serialização e validação de recipe/source. | `ISBBQMenu.lua`: `if o:getItem():getFullType() == "Base.PropaneTank" then` |

### Regra prática de busca

- Para item específico do mod, **prefira tipo completo**: `LKS_Modulo.Item`.
- Mesmo que o vanilla às vezes use tipo curto (`"Battery"`, `"Matches"`), para código novo do LKS o tipo completo é mais seguro.

---

## Tradução e Localização

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `getText(key, ...)` | Resolve texto traduzido com placeholders opcionais. | Labels de menu, tooltip, mensagens de erro e UI dinâmica. | `ISBBQMenu.lua`: `getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(...))` |
| `ItemName_Module.ItemName` | Convenção prática de chave de nome de item usada em mods/UI lookup. | Ao criar nome traduzido de item custom e validar compatibilidade com LKS. | **Vanilla B42 atual:** em `Translate/*/ItemName.json`, o equivalente observado é a chave `"Base.PropaneTank"`; **LKS:** usa `ItemName_LKS_Propano.LKS_Botijao15kg` em `IG_UI.json`. |
| `DisplayName` no script é necessário para `getDisplayName()` funcionar | Apesar de deprecated (warning 42.13), o jogo **requer** `DisplayName` no item script para resolver nomes. Translation keys `ItemName_Module.Item` sozinhas NÃO resolvem sem ele. | Em TODOS os itens novos do mod, sempre incluir `DisplayName = NomeBase,` no script. A tradução em `IG_UI.json` sobrescreve para cada idioma. | Vanilla PropaneTank: `DisplayName = Propane Tank,` + tradução `"Botijão de Gás"` no JSON PT-BR. Sem DisplayName, `getDisplayName()` retorna ID cru. |
| `Translator.getMoveableDisplayName(name)` | Traduz nomes de objetos movíveis do mundo. | Fogão, pia, freezer, máquina de lavar, móveis movíveis. | `ISWorldObjectContextMenu.lua`: `return Translator.getMoveableDisplayName(name)` |

### Observação importante para Build 42

- **Itens vanilla base** estão centralizados em `ItemName.json` com chave `Module.Item`.
- **No ecossistema de mods e no LKS**, ainda é comum lidar com chaves `ItemName_Module.Item` em arquivos como `IG_UI.json`.
- Para objetos do mundo movíveis, **não use `getText` direto**: use `Translator.getMoveableDisplayName()`.

---

## Utilitários

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `ZombRand(n)` | Sorteia inteiro de `0` até `n - 1`. | Escolha aleatória de sprite, lista, efeito ou variação. | `ISSearchManager.lua`: `local pickedIcon = iconList[ZombRand(#iconList) + 1];` |
| `getCell()` | Retorna a célula ativa do mapa. | Buscar tile por coordenada, setar drag object, scanner local. | `ISInventoryBuildMenu.lua`: `getCell():setDrag(ISNaturalFloor:new(...), playerObj:getPlayerNum());` |
| `getTextManager():MeasureStringX(font, text)` | Mede largura de texto em pixels. | Alinhamento de colunas, cálculo de tooltip/layout. | `ISDisassembleMenu.lua`: `local textWid = getTextManager():MeasureStringX(tooltipFont, t1[1].txt);` |
| `ISToolTip.GetFont()` | Retorna a fonte padrão do tooltip. | Quando a medição precisa bater com a renderização real do tooltip. | `ISDisassembleMenu.lua`: `local tooltipFont = ISToolTip.GetFont()` |

---

## Eventos

| Padrão | O que faz | Quando usar | Exemplo vanilla |
|---|---|---|---|
| `Events.OnFillWorldObjectContextMenu.Add(fn)` | Injeta opções no menu de clique direito do mundo. | Menus de fogão, luz, botijão, gerador, construção, etc. | `corpseStorageCheck.lua`: `Events.OnFillWorldObjectContextMenu.Add(corpseStorageCheck.worldObjectContext)` |
| `Events.OnGameStart.Add(fn)` | Executa inicialização quando o jogo termina de carregar. | Registrar cache, popular dados, montar UI persistente, pós-load. | `SpawnItems.lua`: `Events.OnGameStart.Add(SpawnItems.onNewGame);` |
| `Events.EveryOneMinute.Add(fn)` | Tick a cada minuto do jogo. | Sincronização leve, manutenção periódica, lazy init, auditoria contínua. | `ISPerkLog.lua`: `if isClient() then Events.EveryOneMinute.Add(ISPerkLog.init); end;` |
| `Events.OnReceiveGlobalModData.Add(fn)` | Recebe atualização de `GlobalModData` no client. | Sincronia client/server de estado global do mod. | **Ocorrência Lua vanilla não localizada** nos scripts vanilla B42 analisados; tratar como evento de API disponível e seguir o mesmo padrão de registro quando necessário. |
