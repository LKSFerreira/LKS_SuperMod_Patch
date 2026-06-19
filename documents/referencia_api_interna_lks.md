# Referência da API Interna — LKS SuperMod Patch

> Documento gerado automaticamente por `python tools/auditoria_mod.py documentar-api`
> Total: **785** funções em **54** módulos
> Cobertura de documentação: **615/785** (78%)

---

## Índice

### client/
- [`LKS_ApplianceManager.lua`](#clientlksappliancemanagerlua) (2 funções)
- [`LKS_Botijao_ContextMenu.lua`](#clientlksbotijaocontextmenulua) (10 funções)
- [`LKS_Debug_Tool.lua`](#clientlksdebugtoollua) (43 funções)
- [`LKS_Debug_TooltipData.lua`](#clientlksdebugtooltipdatalua) (1 funções)
- [`LKS_EletricidadeConstrucao_ClientCommands.lua`](#clientlkseletricidadeconstrucaoclientcommandslua) (9 funções)
- [`LKS_EletricidadeConstrucao_ContextMenu_Barrel.lua`](#clientlkseletricidadeconstrucaocontextmenubarrellua) (11 funções)
- [`LKS_EletricidadeConstrucao_ContextMenu_Generator.lua`](#clientlkseletricidadeconstrucaocontextmenugeneratorlua) (15 funções)
- [`LKS_EletricidadeConstrucao_ContextMenu_LightSwitch.lua`](#clientlkseletricidadeconstrucaocontextmenulightswitchlua) (8 funções)
- [`LKS_EletricidadeConstrucao_ContextMenu_LightSwitchInstall.lua`](#clientlkseletricidadeconstrucaocontextmenulightswitchinstalllua) (11 funções)
- [`LKS_EletricidadeConstrucao_Heating_Client.lua`](#clientlkseletricidadeconstrucaoheatingclientlua) (14 funções)
- [`LKS_EletricidadeConstrucao_Power_ClientSync.lua`](#clientlkseletricidadeconstrucaopowerclientsynclua) (12 funções)
- [`LKS_Device_Cooking.lua`](#clientdeviceslksdevicecookinglua) (4 funções)
- [`LKS_Device_Laundry.lua`](#clientdeviceslksdevicelaundrylua) (3 funções)
- [`LKS_Device_Refrigeration.lua`](#clientdeviceslksdevicerefrigerationlua) (10 funções)
- [`LKS_EletricidadeConstrucao_UI_DebugPanel.lua`](#clientuilkseletricidadeconstrucaouidebugpanellua) (1 funções)
- [`LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow.lua`](#clientuilkseletricidadeconstrucaouigeneratorinfowindowlua) (51 funções)

### shared/
- [`0_LKS_EletricidadeConstrucao_Init.lua`](#shared0lkseletricidadeconstrucaoinitlua) (1 funções)
- [`LKS_Cooking_PropanoSystem.lua`](#sharedlkscookingpropanosystemlua) (6 funções)
- [`LKS_Cooking_Quality.lua`](#sharedlkscookingqualitylua) (6 funções)
- [`LKS_Cooking_SpriteClassification.lua`](#sharedlkscookingspriteclassificationlua) (2 funções)
- [`LKS_EletricidadeConstrucao_Config.lua`](#sharedlkseletricidadeconstrucaoconfiglua) (6 funções)
- [`LKS_EletricidadeConstrucao_Shared_ConsumerEvents.lua`](#sharedlkseletricidadeconstrucaosharedconsumereventslua) (11 funções)
- [`LKS_EletricidadeConstrucao_Actions_ActivateGenerator.lua`](#sharedactionslkseletricidadeconstrucaoactionsactivategeneratorlua) (17 funções)
- [`LKS_EletricidadeConstrucao_Actions_ConnectBuilding.lua`](#sharedactionslkseletricidadeconstrucaoactionsconnectbuildinglua) (16 funções)
- [`LKS_EletricidadeConstrucao_Actions_DisconnectBuilding.lua`](#sharedactionslkseletricidadeconstrucaoactionsdisconnectbuildinglua) (11 funções)
- [`LKS_EletricidadeConstrucao_Actions_LinkBarrel.lua`](#sharedactionslkseletricidadeconstrucaoactionslinkbarrellua) (8 funções)
- [`LKS_EletricidadeConstrucao_Actions_OpenInfoWindow.lua`](#sharedactionslkseletricidadeconstrucaoactionsopeninfowindowlua) (11 funções)
- [`LKS_EletricidadeConstrucao_Core_EventManager.lua`](#sharedcorelkseletricidadeconstrucaocoreeventmanagerlua) (26 funções)
- [`LKS_EletricidadeConstrucao_Core_Logger.lua`](#sharedcorelkseletricidadeconstrucaocoreloggerlua) (26 funções)
- [`LKS_EletricidadeConstrucao_Core_Namespace.lua`](#sharedcorelkseletricidadeconstrucaocorenamespacelua) (7 funções)
- [`LKS_EletricidadeConstrucao_Core_RuntimeContext.lua`](#sharedcorelkseletricidadeconstrucaocoreruntimecontextlua) (13 funções)
- [`LKS_EletricidadeConstrucao_Core_StateManager.lua`](#sharedcorelkseletricidadeconstrucaocorestatemanagerlua) (47 funções)
- [`LKS_EletricidadeConstrucao_Data_Building.lua`](#shareddatalkseletricidadeconstrucaodatabuildinglua) (22 funções)
- [`LKS_EletricidadeConstrucao_Data_Consumer.lua`](#shareddatalkseletricidadeconstrucaodataconsumerlua) (16 funções)
- [`LKS_EletricidadeConstrucao_Data_Generator.lua`](#shareddatalkseletricidadeconstrucaodatageneratorlua) (15 funções)
- [`LKS_EletricidadeConstrucao_Data_State.lua`](#shareddatalkseletricidadeconstrucaodatastatelua) (26 funções)
- [`LKS_EletricidadeConstrucao_Utils_Geometry.lua`](#sharedutilslkseletricidadeconstrucaoutilsgeometrylua) (18 funções)
- [`LKS_EletricidadeConstrucao_Utils_Math.lua`](#sharedutilslkseletricidadeconstrucaoutilsmathlua) (25 funções)
- [`LKS_EletricidadeConstrucao_Utils_Table.lua`](#sharedutilslkseletricidadeconstrucaoutilstablelua) (14 funções)
- [`LKS_EletricidadeConstrucao_Utils_Validation.lua`](#sharedutilslkseletricidadeconstrucaoutilsvalidationlua) (25 funções)

### server/
- [`LKS_Device_Refrigeration_Server.lua`](#serverlksdevicerefrigerationserverlua) (3 funções)
- [`LKS_EletricidadeConstrucao_DebugCommands.lua`](#serverlkseletricidadeconstrucaodebugcommandslua) (17 funções)
- [`LKS_EletricidadeConstrucao_ServerCommands.lua`](#serverlkseletricidadeconstrucaoservercommandslua) (24 funções)
- [`LKS_EletricidadeConstrucao_ServerInit.lua`](#serverlkseletricidadeconstrucaoserverinitlua) (6 funções)
- [`LKS_EletricidadeConstrucao_Building_BorderDetector.lua`](#serverbuildinglkseletricidadeconstrucaobuildingborderdetectorlua) (14 funções)
- [`LKS_EletricidadeConstrucao_Building_ConsumerScanner.lua`](#serverbuildinglkseletricidadeconstrucaobuildingconsumerscannerlua) (12 funções)
- [`LKS_EletricidadeConstrucao_Building_Scanner.lua`](#serverbuildinglkseletricidadeconstrucaobuildingscannerlua) (12 funções)
- [`LKS_EletricidadeConstrucao_Fuel_Barrels.lua`](#serverfuellkseletricidadeconstrucaofuelbarrelslua) (13 funções)
- [`LKS_EletricidadeConstrucao_Fuel_ChunkTracker.lua`](#serverfuellkseletricidadeconstrucaofuelchunktrackerlua) (14 funções)
- [`LKS_EletricidadeConstrucao_Fuel_Manager.lua`](#serverfuellkseletricidadeconstrucaofuelmanagerlua) (19 funções)
- [`LKS_EletricidadeConstrucao_Fuel_StrainCalculator.lua`](#serverfuellkseletricidadeconstrucaofuelstraincalculatorlua) (17 funções)
- [`LKS_EletricidadeConstrucao_Heating_Manager.lua`](#serverheatinglkseletricidadeconstrucaoheatingmanagerlua) (7 funções)
- [`LKS_EletricidadeConstrucao_Power_Distributor.lua`](#serverpowerlkseletricidadeconstrucaopowerdistributorlua) (29 funções)
- [`LKS_EletricidadeConstrucao_Power_Manager.lua`](#serverpowerlkseletricidadeconstrucaopowermanagerlua) (18 funções)

---

## `client/LKS_ApplianceManager.lua`

### 🌐 `LKS_ApplianceManager.recursoAtivo(nomeRecurso, valorPadrao)` <sub>L36</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_ApplianceManager.onFillWorldObjectContextMenu(jogadorNumero, menuContexto, objetosMundo, apenasTeste)` <sub>L56</sub>

> Constrói dinamicamente os submenus baseando-se no roteamento para o driver correspondente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogadorNumero` | `number` | O índice do jogador local (0 a 3). |
| `menuContexto` | `ISContextMenu` | O menu de contexto sendo preenchido. |
| `objetosMundo` | `table` | A lista de objetos físicos clicados no mundo. |
| `apenasTeste` | `boolean` | Se true, indica que é apenas uma validação rápida de colisão. |

---

## `client/LKS_Botijao_ContextMenu.lua`

### 🔒 `verificarItensNecessarios(jogador, listaItens)` <sub>L50</sub>

> Verifica se o jogador possui todos os itens necessários para uma operação.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogador` | `IsoPlayer` | O jogador a verificar. |
| `listaItens` | `table` | Lista de itens requeridos. |

**Retorno:**
- `boolean` `temTodos` — True se possui todos os itens.
- `table` `itensFaltantes` — Lista com nomes de todos os itens faltantes.

---

### 🔒 `fogaoTemBotijaoConectado(fogao)` <sub>L85</sub>

> Verifica se o fogão já tem um botijão conectado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `fogao` | `IsoObject` | O fogão a verificar. |

**Retorno:**
- `boolean` `conectado` — True se há botijão conectado.

---

### 🔒 `calcularRiscoVazamento(jogador)` <sub>L98</sub>

> Calcula a chance de vazamento de gás com base nas skills do jogador.
> Condições: soma de Elétrica + Mecânica + Cooking < 6 E pelo menos uma ≤ 1.
> Chance: 1% quando condições atendidas, 0% caso contrário.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogador` | `IsoPlayer` | O jogador realizando a instalação. |

**Retorno:**
- `boolean` `temRisco` — True se há risco de vazamento.

---

### 🔒 `conectarBotijao(fogao, jogador)` <sub>L119</sub>

> Conecta um botijão ao fogão via moddata.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `fogao` | `IsoObject` | O fogão a conectar. |
| `jogador` | `IsoPlayer` | O jogador realizando a ação. |

---

### 🔒 `desconectarBotijao(fogao)` <sub>L133</sub>

> Desconecta o botijão do fogão.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `fogao` | `IsoObject` | O fogão a desconectar. |

---

### 🔒 `buscarBotijoesProximos(fogao, jogador)` <sub>L151</sub>

> Busca botijões de gás nos tiles ao redor de um fogão (inventário + chão).
> Usa a mesma abordagem do vanilla ISBBQMenu.FindPropaneTank.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `fogao` | `IsoObject` | O fogão de referência. |
| `jogador` | `IsoPlayer` | O jogador (para verificar inventário). |

**Retorno:**
- `table` `Lista` — de botijões encontrados {item, origem, descricao}.

---

### 🔒 `buscarFogoesProximos(centroX, centroY, centroZ)` <sub>L211</sub>

> Busca fogões IsoStove nos tiles ao redor de um ponto.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `centroX` | `number` | Coordenada X central. |
| `centroY` | `number` | Coordenada Y central. |
| `centroZ` | `number` | Coordenada Z central. |

**Retorno:**
- `table` `Lista` — de fogões encontrados.

---

### 🔒 `montarTooltipRequisitos(jogador, listaItens, nomeSprite)` <sub>L255</sub>

> Monta tooltip de requisitos reutilizando a infraestrutura vanilla.
> Usa ISWorldObjectContextMenu.addToolTip() (pool) e o renderizador
> nativo de rich text do ISToolTip (mesmo que ISDisassembleMenu usa).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogador` | `IsoPlayer` | O jogador. |
| `listaItens` | `table` | Lista de itens requeridos. |
| `nomeSprite` | `string|nil` | Nome do sprite do objeto para exibir à esquerda. |

**Retorno:**
- `ISToolTip` `O` — tooltip formatado.

---

### 🔒 `obterTexturaItem(botijaoInfo)` <sub>L330</sub>

> Obtém a textura de um botijão para exibição no menu de contexto.
> Suporta itens no chão (IsoWorldInventoryObject) e no inventário.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `botijaoInfo` | `table` | Informações do botijão {item, nome, noChao}. |

**Retorno:**
- `Texture|nil` `textura` — A textura do item ou nil.

---

### 🔒 `adicionarOpcoesMenuBotijao(jogadorNumero, menuContexto, objetosMundo)` <sub>L355</sub>

> Handler principal do menu de contexto do mundo.
> Detecta fogões e botijões clicados e monta submenu genérico
> "Instalar" / "Trocar" / "Desinstalar" com ícones nos itens.
> Estrutura:
>   Fogão clicado (sem botijão): Instalar > [botijão1, botijão2, ...]
>   Fogão clicado (com botijão): Trocar > [botijão1, ...] + Desinstalar
>   Botijão clicado: Instalar > [fogão1, fogão2, ...]

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogadorNumero` | `number` | Índice do jogador. |
| `menuContexto` | `ISContextMenu` | O menu de contexto. |
| `objetosMundo` | `table` | Objetos clicados. |

---

## `client/LKS_Debug_Tool.lua`

### 🌐 `LKS_DebugToolWindow:initialise()` <sub>L107</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_DebugToolWindow:createChildren()` <sub>L111</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_DebugToolWindow:limparWidgetsAba()` <sub>L125</sub>

> Remove todos os widgets da aba atual antes de trocar.

---

### 🌐 `LKS_DebugToolWindow:construirAbaAtual()` <sub>L142</sub>

> Constrói os widgets da aba selecionada.

---

### 🌐 `LKS_DebugToolWindow:trocarAba(indice)` <sub>L154</sub>

> Troca para uma aba pelo índice.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `indice` | `number` | O índice da aba destino. |

---

### 🌐 `LKS_DebugToolWindow:registrarWidget(widget)` <sub>L166</sub>

> Registra um widget como pertencente à aba atual (para limpeza ao trocar).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `widget` | `ISUIElement` | O widget a rastrear. |

---

### 🌐 `LKS_DebugToolWindow:adicionarWidgetAba(widget)` <sub>L173</sub>

> Adiciona um widget filho e o registra para limpeza automática.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `widget` | `ISUIElement` | O widget a adicionar. |

---

### 🌐 `LKS_DebugToolWindow:prerender()` <sub>L178</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_DebugToolWindow:render()` <sub>L238</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_DebugToolWindow:update()` <sub>L248</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_DebugToolWindow:onMouseDown(x, y)` <sub>L258</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_DebugToolWindow:close()` <sub>L277</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_DebugToolWindow:new(posicaoX, posicaoY)` <sub>L288</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_DebugTool.registrarAba(definicaoAba)` <sub>L308</sub>

> Registra uma nova aba no sistema de debug.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `definicaoAba` | `table` | Tabela com campos: nome, criar, renderizar, atualizar, destruir. |

---

### 🌐 `LKS_DebugTool.toggle()` <sub>L316</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `abaRecarregar.criar(self, painel, posicaoY)` <sub>L347</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `abaRecarregar.alternarPainelMods(self, painel)` <sub>L513</sub>

> Alterna a exibição do painel de seleção de mods (toggle).
> Quando ativado, lista todos os mods ativos no jogo para que o usuário
> selecione quais mods participarão da filtragem e recarga.

---

### 🌐 `abaRecarregar.desenharItemMod(self, y, item, alt)` <sub>L605</sub>

> Renderizador para itens da lista de mods (checkbox visual).

---

### 🌐 `abaRecarregar.coletarArquivosDeMod(self, modId)` <sub>L664</sub>

> Coleta os arquivos Lua recarregáveis de um mod pelo seu ID.
> Utiliza as APIs nativas do debug do PZ: `getLoadedLuaCount()` e `getLoadedLua(indice)`
> para obter todos os arquivos Lua carregados pelo engine, depois filtra pelo
> diretório do mod obtido via `getModInfoByID(modId):getDir()`.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `modId` | `string` | O ID do mod (ex: "LKSSuperModPatch"). |

**Retorno:**
- `table` `arquivos` — Lista de caminhos completos para `reloadLuaFile`.

---

### 🌐 `abaRecarregar.inicializarMods(self)` <sub>L703</sub>

> Inicializa os mods disponíveis e coleta arquivos do LKS na primeira abertura.

---

### 🌐 `abaRecarregar.obterArquivosAtivos(self)` <sub>L748</sub>

> Retorna a lista de arquivos de acordo com o modo ativo.
> Modo "Todos os arquivos .lua": retorna TODOS os arquivos Lua carregados pelo
> engine, excluindo apenas arquivos de mods que foram explicitamente desmarcados.
> Modo normal: retorna apenas arquivos dos mods individualmente marcados.

**Retorno:**
- `table` `arquivos` — Lista unificada de caminhos ordenada alfabeticamente.

---

### 🌐 `abaRecarregar.obterTodosArquivosComExclusao(self)` <sub>L774</sub>

> Retorna todos os arquivos Lua carregados pelo engine, excluindo
> aqueles que pertencem a mods explicitamente desmarcados.

**Retorno:**
- `table` `arquivos` — Lista de todos os caminhos Lua, filtrada por exclusões.

---

### 🌐 `abaRecarregar.atualizarLista(self, painel)` <sub>L822</sub>

> Atualiza a lista visual com base nos mods selecionados e no filtro digitado.
> Usa `getShortenedFilename` (API nativa do PZ) para exibir nomes curtos na
> lista, enquanto armazena o caminho completo no `.item.caminho` para reload.

---

### 🌐 `abaRecarregar.desenharItemLista(self, y, item, alt)` <sub>L849</sub>

> Renderizador customizado com checkbox para cada arquivo da lista.

---

### 🌐 `abaRecarregar.verificarSegurancaReload(self, totalArquivos)` <sub>L904</sub>

> Verifica se o recarregamento em massa e seguro.
> Arquivos de um unico mod sao sempre permitidos independente da quantidade.
> O limite so se aplica quando multiplos mods ou "Todos os arquivos .lua" estao ativos.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `self` | `table` | Instancia da janela de debug. |
| `totalArquivos` | `number` | Quantidade de arquivos a recarregar. |

**Retorno:**
- `boolean` `seguro` — true se o recarregamento pode prosseguir.

---

### 🌐 `abaRecarregar.recarregarTodos(self, painel)` <sub>L925</sub>

> Recarrega TODOS os arquivos visíveis na lista (respeitando filtro e mods ativos).
> Exibe aviso de segurança quando a quantidade excede o limite seguro e multiplos mods estao ativos.

---

### 🌐 `abaRecarregar.recarregarMarcados(self, painel)` <sub>L961</sub>

> Recarrega os arquivos marcados com checkbox na lista.
> Exibe aviso de segurança quando a quantidade excede o limite seguro e multiplos mods estao ativos.

---

### 🌐 `abaRecarregar.definirStatus(self, mensagem, tipoMensagem)` <sub>L1012</sub>

> Atualiza o texto e a cor da barra de status no rodapé.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `mensagem` | `string` | Texto a exibir na barra de status. |
| `tipoMensagem` | `string` | Tipo visual: "sucesso" (verde), "erro" (vermelho), "aviso" (amarelo) ou nil (neutro). |

---

### 🌐 `abaRecarregar.atualizar(self, painel)` <sub>L1031</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `abaRecarregar.destruir(self, painel)` <sub>L1045</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `abaMenuContexto.criar(self, painel, posicaoY)` <sub>L1062</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `abaMenuContexto.capturarMenu(self, menuContexto, objetosMundo, jogadorNumero)` <sub>L1109</sub>

> Captura o menu de contexto final e tenta reconstruir o menu vanilla original.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `menuContexto` | `ISContextMenu` | O menu de contexto preenchido (com todos os mods). |
| `objetosMundo` | `table` | Os objetos clicados. |
| `jogadorNumero` | `number` | O indice do jogador. |

---

### 🌐 `abaMenuContexto.popularLista(self)` <sub>L1118</sub>

> Popula a lista de captura com os dados do menu atual e as opcoes vanilla.

---

### 🌐 `abaMenuContexto.adicionarOpcoesNaLista(self, menu, nivel, prefixo)` <sub>L1136</sub>

> Adiciona opcoes recursivamente na lista com indentacao.

---

### 🌐 `abaMenuContexto.desenharItemLista(self, y, item, alt)` <sub>L1173</sub>

> Renderizador customizado para itens da lista de captura.
> Renderiza icones quando disponveis e diferencia secoes e opcoes.

---

### 🌐 `abaMenuContexto.destruir(self, painel)` <sub>L1250</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `abaInspetorObjeto.criar(self, painel, posicaoY)` <sub>L1264</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `abaInspetorObjeto.capturarObjeto(self, objeto)` <sub>L1309</sub>

> Captura as propriedades de um objeto do mundo e organiza por seção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objeto` | `IsoObject` | O objeto do mundo a inspecionar. |

---

### 🌐 `abaInspetorObjeto.popularLista(self)` <sub>L1430</sub>

> Popula a lista visual com os dados capturados organizados por seção.

---

### 🌐 `abaInspetorObjeto.desenharItemLista(self, y, item, alt)` <sub>L1455</sub>

> Renderizador customizado para itens de propriedade.

---

### 🌐 `abaInspetorObjeto.destruir(self, painel)` <sub>L1514</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `aoPreencherMenuContextoMundo(jogadorNumero, menuContexto, objetosMundo, apenasTeste)` <sub>L1525</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `aoTeclaPressionada(tecla)` <sub>L1554</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `client/LKS_Debug_TooltipData.lua`

### 🌐 `LKS_DebugTooltipData.buscarTooltip(chavePropriedade, secaoAtual)` <sub>L474</sub>

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `chavePropriedade` | `string` | Nome da propriedade a buscar |
| `secaoAtual` | `string` | Identificador da seção onde a propriedade está (opcional) |

**Retorno:**
- `string|nil` `textoTooltip` — Descrição encontrada ou nil

---

## `client/LKS_EletricidadeConstrucao_ClientCommands.lua`

### 🔒 `LocalizarGeradorEm(coordenadaX, coordenadaY, coordenadaZ)` <sub>L29</sub>

> Busca um gerador fisico (objeto Java IsoGenerator) nas coordenadas mapeadas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `coordenadaX` | `integer` | A coordenada X do gerador. |
| `coordenadaY` | `integer` | A coordenada Y do gerador. |
| `coordenadaZ` | `integer` | A coordenada Z do gerador. |

**Retorno:**
- `any|nil` `Retorna` — o objeto IsoGenerator se encontrado, ou nil.

---

### 🔒 `LocalizarQuadradoEm(coordenadaX, coordenadaY, coordenadaZ)` <sub>L54</sub>

> Busca e retorna o quadrado fisico (GridSquare) nas coordenadas solicitadas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `coordenadaX` | `integer` | Coordenada X. |
| `coordenadaY` | `integer` | Coordenada Y. |
| `coordenadaZ` | `integer` | Coordenada Z. |

**Retorno:**
- `any|nil` `O` — GridSquare associado ou nil.

---

### 🔒 `ObterJogadorLocal()` <sub>L62</sub>

> Recupera o objeto do jogador local ativo.

**Retorno:**
- `any|nil` `O` — objeto do jogador local ou nil.

---

### 🔒 `NotificarResultado(argumentos)` <sub>L74</sub>

> Despacha e exibe na tela ou console o resultado textual da acao enviada.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `argumentos` | `table` | Os dados e chaves da mensagem a notificar. |

---

### 🔒 `AtualizarJanelaGerador(geradorX, geradorY, geradorZ, requisitarEstatisticas)` <sub>L96</sub>

> Atualiza a janela visual de estatisticas do gerador correspondente no cliente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `geradorX` | `integer` | Coordenada X do gerador. |
| `geradorY` | `integer` | Coordenada Y do gerador. |
| `geradorZ` | `integer` | Coordenada Z do gerador. |
| `requisitarEstatisticas` | `boolean` | Se true, forca a releitura de dados do lado servidor. |

---

### 🔒 `FecharJanelaGerador(geradorX, geradorY, geradorZ)` <sub>L114</sub>

> Fecha a janela grafica de informacoes do gerador informado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `geradorX` | `integer` | Coordenada X. |
| `geradorY` | `integer` | Coordenada Y. |
| `geradorZ` | `integer` | Coordenada Z. |

---

### 🔒 `AplicarResultadoAquecimento(argumentos)` <sub>L127</sub>

> Aplica localmente no cliente o resultado dos controles de aquecimento remoto.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `argumentos` | `table` | Os parametros retornados pelo servidor. |

---

### 🔒 `AbrirJanelaInformacaoDoServidor(argumentos)` <sub>L176</sub>

> Solicita a abertura da janela de informacoes do gerador ou predio.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `argumentos` | `table` | Os dados retornados pela simulacao do servidor. |

---

### 🔒 `AoReceberComandoServidor(modulo, comando, argumentos)` <sub>L211</sub>

> Callback disparada ao receber eventos de comando vindos do servidor.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `modulo` | `string` | O modulo remetente. |
| `comando` | `string` | O comando enviado. |
| `argumentos` | `table` | Os argumentos extras de payload. |

---

## `client/LKS_EletricidadeConstrucao_ContextMenu_Barrel.lua`

### 🔒 `TabelaPossuiEntradas(tabela)` <sub>L26</sub>

> Verifica se uma tabela Lua possui entradas válidas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser analisada. |

**Retorno:**
- `boolean` `Retorna` — true se a tabela contiver chaves.

---

### 🔒 `EstaDentroDaCaixaDelimitadora(dadosConstrucao, coordenadaX, coordenadaY)` <sub>L39</sub>

> Verifica se as coordenadas informadas estão dentro da caixa delimitadora da construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os limites geométricos da construção. |
| `coordenadaX` | `number` | Coordenada X física. |
| `coordenadaY` | `number` | Coordenada Y física. |

**Retorno:**
- `boolean` `Retorna` — true se estiver contido na área delimitada.

---

### 🔒 `LocalizarPredioProximo(celula, quadrado, raio)` <sub>L60</sub>

> Realiza busca nas proximidades por uma estrutura predial nativa da engine (IsoBuilding).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `celula` | `any` | A célula ativa do mapa. |
| `quadrado` | `any` | O GridSquare referenciado. |
| `raio` | `integer` | Raio de varredura. |

**Retorno:**
- `any|nil` `O` — objeto IsoBuilding correspondente ou nil.

---

### 🔒 `PredioCorrespondeAoIso(dadosConstrucao, predioIso, celula, fallbackZ)` <sub>L91</sub>

> Valida se uma construção lógica do estado corresponde ao objeto físico IsoBuilding da engine.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os limites da construção no estado. |
| `predioIso` | `any` | O objeto IsoBuilding correspondente. |
| `celula` | `any` | A célula ativa do mapa. |
| `fallbackZ` | `integer` | Altura Z de fallback. |

**Retorno:**
- `boolean` `Retorna` — true se houver correspondência física de quadrantes.

---

### 🔒 `IsGeradorFuncionando(dadosGerador)` <sub>L102</sub>

> Verifica se o gerador está ativamente em operação no estado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados estruturados do gerador. |

**Retorno:**
- `boolean` `Retorna` — true se estiver em funcionamento ativo.

---

### 🔒 `GeradorReferenciaConstrucao(dadosGerador, dadosConstrucao, quadrado, gerenciadorEstado)` <sub>L117</sub>

> Analisa se um determinado gerador possui dependência direta ou indireta de links com a construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados do gerador. |
| `dadosConstrucao` | `table` | A construção correspondente. |
| `quadrado` | `any` | O GridSquare do barril. |
| `gerenciadorEstado` | `table` | Referência do StateManager. |

**Retorno:**
- `boolean` `Retorna` — true se houver qualquer vínculo elétrico entre ambos.

---

### 🔒 `ObterPontuacaoGeradorConstrucao(dadosConstrucao, quadrado, gerenciadorEstado)` <sub>L167</sub>

> Calcula a pontuação de relevância de geradores associados a uma construção específica.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os limites da construção. |
| `quadrado` | `any` | O quadrado de origem. |
| `gerenciadorEstado` | `table` | Instância do StateManager. |

**Retorno:**
- `integer` `Retorna` — a pontuação de prioridade baseada na proximidade e no uptime elétrico.

---

### 🔒 `PontuarCandidatoConstrucao(dadosConstrucao, quadrado, predioIso, raio, celula, gerenciadorEstado, idConstrucaoPreferencial)` <sub>L213</sub>

> Pontua um candidato predial com base na distância geométrica e status da rede elétrica.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os limites prediais no estado. |
| `quadrado` | `any` | O quadrado físico do barril. |
| `predioIso` | `any` | O objeto IsoBuilding correspondente (se detectado). |
| `raio` | `number` | O raio máximo de varredura. |
| `celula` | `any` | A célula ativa do mapa. |
| `gerenciadorEstado` | `table` | Instância do StateManager. |
| `idConstrucaoPreferencial` | `string|nil` | O ID da construção preferencial já vinculada. |

**Retorno:**
- `number|nil` `Retorna` — a pontuação de prioridade final do candidato, ou nil se rejeitado.

---

### 🔒 `LocalizarConstrucaoMaisProxima(quadrado, raio, idConstrucaoPreferencial)` <sub>L254</sub>

> Localiza no estado a construção com maior adequabilidade para ser vinculada ao barril.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `any` | O GridSquare do barril. |
| `raio` | `integer` | O raio físico máximo de alcance. |
| `idConstrucaoPreferencial` | `string|nil` | O ID do prédio previamente vinculado. |

**Retorno:**
- `table|nil` `Retorna` — o registro da construção mais adequada, ou nil se nenhum candidato for aprovado.

---

### 🔒 `LocalizarIdFiltroGeradorProximo(quadrado, raio)` <sub>L285</sub>

> Localiza nas proximidades o ID da piscina elétrica de geradores nativos da engine.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `any` | O GridSquare inicial. |
| `raio` | `integer` | O raio de varredura. |

**Retorno:**
- `string|nil` `Retorna` — o ID da piscina de construções, ou nil se nenhum gerador ativo for achado.

---

### 🔒 `LocalizarBarril(objetosMundo)` <sub>L331</sub>

> Procura um barril de combustível válido na lista de objetos interagíveis do quadrado clicado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetosMundo` | `table` | A lista de objetos selecionados pelo clique direito. |

**Retorno:**
- `any|nil` `Retorna` — o objeto IsoObject do barril se for elegível, ou nil.

---

## `client/LKS_EletricidadeConstrucao_ContextMenu_Generator.lua`

### 🔒 `ObterIconeGerador(gerador)` <sub>L54</sub>

> Retorna a textura correspondente do ícone do gerador ou fallback.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerador` | `any` | O objeto IsoGenerator. |

**Retorno:**
- `any` `A` — textura correspondente.

---

### 🔒 `temConstrucaoNoRaio(quadrado, raio)` <sub>L77</sub>

> Verifica se há alguma construção válida em um raio específico ao redor de um quadrado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `any` | O quadrado de grade central (gerador). |
| `raio` | `number` | O raio máximo de busca em tiles. |

**Retorno:**
- `boolean` `Retorna` — true se encontrar algum quadrado pertencente a uma construção.

---

### 🔒 `LocalizarGerador(objetosMundo)` <sub>L101</sub>

> Procura um objeto IsoGenerator na lista de objetos interagíveis do quadrado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetosMundo` | `table` | A lista de objetos selecionados pelo clique direito. |

**Retorno:**
- `any|nil` `Retorna` — o objeto gerador ou nil se não encontrado.

---

### 🔒 `IsGeradorEmModoConstrucao(gerador)` <sub>L114</sub>

> Analisa se o gerador foi mapeado e persistido no modo de alimentação realista de prédios (Modo Construção).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerador` | `any` | O gerador físico. |

**Retorno:**
- `boolean` `Retorna` — true se estiver vinculado logicamente a uma piscina de prédio.

---

### 🔒 `ObterPercentualCombustivel(gerador)` <sub>L123</sub>

> Retorna o percentual inteiro arredondado do combustível do gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerador` | `any` | O gerador analisado. |

**Retorno:**
- `number` `O` — percentual (0 a 100).

---

### 🔒 `ObterPercentualCondicao(gerador)` <sub>L134</sub>

> Retorna a integridade física do gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerador` | `any` | O gerador. |

**Retorno:**
- `number` `O` — percentual de condição física (0 a 100).

---

### 🔒 `PodeAtivarGerador(gerador)` <sub>L142</sub>

> Verifica se o gerador cumpre todos os requisitos para ser ligado física e eletricamente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerador` | `any` | O gerador analisado. |

**Retorno:**
- `boolean` `Retorna` — true se puder ser ativado.

---

### 🔒 `PodeAlcancarGerador(jogador, gerador)` <sub>L154</sub>

> Verifica o distanciamento físico máximo permitido para interagir com o aparelho.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogador` | `any` | O objeto jogador. |
| `gerador` | `any` | O gerador. |

**Retorno:**
- `boolean` `Retorna` — true se estiver a 1 bloco de distância.

---

### 🔒 `IsItemInventario(valor)` <sub>L172</sub>

> Invoca pcall segura para validar se um dado valor é da classe InventoryItem.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser avaliado. |

**Retorno:**
- `boolean` `Retorna` — true se for um item do inventário do jogo.

---

### 🔒 `ExtrairItemRecipienteDaOpcao(opcao)` <sub>L181</sub>

> Varre as referências de subopções do clique direito buscando itens contendo combustível.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `opcao` | `table` | A opção do menu avaliada. |

**Retorno:**
- `any|nil` `Retorna` — o item de inventário correspondente (galão) ou nil.

---

### 🌐 `ContextMenu.OnLigar(objetosMundo, numeroJogador)` <sub>L218</sub>

> Evento disparado quando o jogador escolhe ligar o gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetosMundo` | `table` | A coleção de itens no quadrado. |
| `numeroJogador` | `number` | O ID local do jogador interativo. |

---

### 🌐 `ContextMenu.OnDesligar(objetosMundo, numeroJogador)` <sub>L241</sub>

> Evento disparado quando o jogador escolhe desligar o gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetosMundo` | `table` | A coleção de itens no quadrado. |
| `numeroJogador` | `number` | O ID local do jogador interativo. |

---

### 🌐 `ContextMenu.OnConectarConstrucao(objetosMundo, numeroJogador)` <sub>L264</sub>

> Evento disparado quando o jogador escolhe integrar o gerador à rede da construção (Modo Realista).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetosMundo` | `table` | A coleção de itens no quadrado. |
| `numeroJogador` | `number` | O ID local do jogador. |

---

### 🌐 `ContextMenu.OnDesconectarConstrucao(objetosMundo, numeroJogador)` <sub>L287</sub>

> Evento disparado quando o jogador escolhe isolar/desvincular o gerador da rede elétrica da construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetosMundo` | `table` | A coleção de itens no quadrado. |
| `numeroJogador` | `number` | O ID local do jogador. |

---

### 🌐 `ContextMenu.Construir(numeroJogador, contexto, objetosMundo, modoTeste)` <sub>L316</sub>

> Constrói dinamicamente os menus de clique direito do gerador elétrico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `numeroJogador` | `number` | O número do jogador interativo. |
| `contexto` | `table` | A estrutura principal de submenu nativa. |
| `objetosMundo` | `table` | A coleção de objetos selecionados pelo clique. |
| `modoTeste` | `boolean` | Se true, sinaliza apenas a disponibilidade sem instanciar a UI. |

---

## `client/LKS_EletricidadeConstrucao_ContextMenu_LightSwitch.lua`

### 🔒 `ObterPontuacaoSelecaoGerador(gerador, idConstrucaoEsperada, esperadoX, esperadoY)` <sub>L36</sub>

> Calcula a pontuação de relevância de um gerador para seleção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerador` | `any` | O objeto IsoGenerator. |
| `idConstrucaoEsperada` | `string|nil` | O ID da construção esperada. |
| `esperadoX` | `number|nil` | A coordenada X esperada. |
| `esperadoY` | `number|nil` | A coordenada Y esperada. |

**Retorno:**
- `number` `Retorna` — a pontuação de relevância calculada.

---

### 🔒 `EhMelhorCandidatoGerador(pontuacao, indiceOrdem, distancia, melhorPontuacao, melhorIndiceOrdem, melhorDistancia)` <sub>L73</sub>

> Decide se o novo candidato a gerador é melhor do que o atual campeão.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `pontuacao` | `number` | Pontuação do novo gerador. |
| `indiceOrdem` | `number|nil` | Posição de carregamento original na lista. |
| `distancia` | `number|nil` | Distância geométrica. |
| `melhorPontuacao` | `number|nil` | Melhor pontuação registrada. |
| `melhorIndiceOrdem` | `number|nil` | Melhor posição de carregamento anterior. |
| `melhorDistancia` | `number|nil` | Melhor distância geométrica anterior. |

**Retorno:**
- `boolean` `Retorna` — true se for um candidato melhor.

---

### 🔒 `LocalizarGeradorParaInterruptor(coordenadaX, coordenadaY, coordenadaZ)` <sub>L95</sub>

> Busca um gerador fisicamente conectado à construção contendo este interruptor de luz.
> Varre o ModData dos geradores próximos (raio de 20) procurando por Gen_BuildingPoolID compatível.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `coordenadaX` | `number` | Coordenada X do interruptor. |
| `coordenadaY` | `number` | Coordenada Y do interruptor. |
| `coordenadaZ` | `number` | Coordenada Z do interruptor. |

**Retorno:**
- `any|nil` `O` — gerador IsoGenerator encontrado, ou nil.

---

### 🔒 `ObterGeradorConstrucao(dadosConstrucao)` <sub>L153</sub>

> Obtém o melhor gerador físico carregado no mapa que pertence a esta construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os limites da construção. |

**Retorno:**
- `any|nil` `O` — gerador IsoGenerator ou nil.

---

### 🔒 `EstaDentroDosLimitesConstrucao(dadosConstrucao, coordenadaX, coordenadaY)` <sub>L244</sub>

> Verifica se as coordenadas estão compreendidas nos limites da construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os limites da construção. |
| `coordenadaX` | `number` | Coordenada X. |
| `coordenadaY` | `number` | Coordenada Y. |

**Retorno:**
- `boolean` `Retorna` — true se estiver contido na área delimitada.

---

### 🔒 `ConstrucaoPossuiConsumidorNoQuadrado(dadosConstrucao, quadrado)` <sub>L264</sub>

> Verifica se a construção lógica do estado possui um consumidor ativo registrado no quadrado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | A construção. |
| `quadrado` | `any` | O GridSquare consultado. |

**Retorno:**
- `boolean` `Retorna` — true se houver consumidor cadastrado nesta coordenada.

---

### 🔒 `ResolverDadosConstrucaoParaInterruptor(quadrado)` <sub>L283</sub>

> Localiza e resolve a construção lógica do estado associada a este interruptor.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `any` | O GridSquare do interruptor. |

**Retorno:**
- `table|nil` `O` — registro de dados da construção ou nil se não encontrado.

---

### 🔒 `LocalizarInterruptorLuz(objetosMundo)` <sub>L340</sub>

> Extrai o objeto Java IsoLightSwitch da lista de itens clicados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetosMundo` | `table` | A lista de objetos na coordenada do clique. |

**Retorno:**
- `any|nil` `Retorna` — o interruptor ou nil.

---

## `client/LKS_EletricidadeConstrucao_ContextMenu_LightSwitchInstall.lua`

### 🔒 `IsInterruptorLuzItem(item)` <sub>L50</sub>

> Verifica se o item informado é um interruptor de luz padrão.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `item` | `any` | O item de inventário. |

**Retorno:**
- `boolean` `Retorna` — true se corresponder a um interruptor.

---

### 🔒 `ObterDirecaoIso(constanteDirecao)` <sub>L62</sub>

> Retorna a direção direcional ISO correspondente da engine.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `constanteDirecao` | `integer` | A constante direcional. |

**Retorno:**
- `any` `A` — direção ISO.

---

### 🔒 `LocalizarParedeAdjacente(quadradoJogador)` <sub>L73</sub>

> Localiza uma parede adjacente ao jogador em qualquer direção cardeal (N, S, E, W).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadradoJogador` | `any` | O GridSquare do jogador. |

**Retorno:**
- `integer|nil` `direcao` — , any|nil O quadrado da parede.

---

### 🔒 `ObterSpriteInterruptor(direcao)` <sub>L116</sub>

> Mapeamento de Sprites nativos (Base 42):
> lighting_indoor_01_0 = Parede Norte
> lighting_indoor_01_1 = Parede Oeste
> lighting_indoor_01_2 = Parede Leste
> lighting_indoor_01_3 = Parede Sul

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `direcao` | `integer` | A constante direcional. |

**Retorno:**
- `string` `O` — nome do sprite.

---

### 🌐 `LKS_EletricidadeConstrucao_InstallLightswitchAction:isValid()` <sub>L130</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_InstallLightswitchAction:waitToStart()` <sub>L137</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_InstallLightswitchAction:update()` <sub>L142</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_InstallLightswitchAction:start()` <sub>L146</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_InstallLightswitchAction:stop()` <sub>L152</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_InstallLightswitchAction:perform()` <sub>L159</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_InstallLightswitchAction:new(personagem, item, quadrado, direcao)` <sub>L187</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `client/LKS_EletricidadeConstrucao_Heating_Client.lua`

### 🔒 `IsSistemaAtivo()` <sub>L41</sub>

> Verifica se o sistema de aquecimento está ativo nas SandboxVars.

**Retorno:**
- `boolean` `Retorna` — true se estiver ativo.

---

### 🔒 `ObterRaio()` <sub>L51</sub>

> Retorna o raio de aquecimento configurado no sandbox.

**Retorno:**
- `number` `O` — raio de calor.

---

### 🔒 `AdicionarGeradorCarregado(resultado, vistos, gerador)` <sub>L61</sub>

> Insere um gerador físico carregado nas tabelas de resultado, evitando duplicações.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `resultado` | `table` | A lista de destino. |
| `vistos` | `table` | Conjunto de controle de duplicados. |
| `gerador` | `any` | O gerador físico. |

---

### 🔒 `LocalizarGeradorCarregadoEm(coordenadaX, coordenadaY, coordenadaZ)` <sub>L78</sub>

> Busca um gerador físico no GridSquare carregado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `coordenadaX` | `number` | Coordenada X. |
| `coordenadaY` | `number` | Coordenada Y. |
| `coordenadaZ` | `number` | Coordenada Z. |

**Retorno:**
- `any|nil` `O` — gerador IsoGenerator ou nil.

---

### 🔒 `ColetarGeradoresFontesAtivas(resultado, vistos)` <sub>L101</sub>

> Coleta os geradores associados a fontes de aquecimento que estão atualmente ativas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `resultado` | `table` | A lista de destino. |
| `vistos` | `table` | Conjunto de controle de duplicados. |

---

### 🔒 `ColetarGeradoresDasJanelas(resultado, vistos)` <sub>L113</sub>

> Coleta os geradores associados a janelas gráficas abertas no cliente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `resultado` | `table` | A lista de destino. |
| `vistos` | `table` | Conjunto de controle de duplicados. |

---

### 🔒 `ColetarGeradoresProximosAoJogador(resultado, vistos, raio)` <sub>L127</sub>

> Coleta geradores carregados no mapa nas imediações dos jogadores locais.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `resultado` | `table` | A lista de destino. |
| `vistos` | `table` | Conjunto de controle de duplicados. |
| `raio` | `number|nil` | O raio de busca (padrão: 25). |

---

### 🌐 `LKS_EletricidadeConstrucao_HeatingClient.Apply(gerador)` <sub>L172</sub>

> Cria os objetos físicos IsoHeatSource nas posições radiantes associadas ao gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerador` | `any` | O gerador físico. |

**Retorno:**
- `boolean` `Retorna` — true se as fontes de calor foram aplicadas com sucesso.

---

### 🌐 `LKS_EletricidadeConstrucao_HeatingClient.Remove(chaveGerador)` <sub>L229</sub>

> Remove todas as fontes de calor IsoHeatSource ativas vinculadas ao gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `chaveGerador` | `string` | A chave identificadora do gerador. |

---

### 🌐 `LKS_EletricidadeConstrucao_HeatingClient.IsActive(chaveGerador)` <sub>L247</sub>

> Retorna true se houver fontes de calor radiante ativas para a chave do gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `chaveGerador` | `string` | A chave do gerador. |

**Retorno:**
- `boolean` `Status` — de atividade.

---

### 🌐 `LKS_EletricidadeConstrucao_HeatingClient.ClearAll()` <sub>L252</sub>

> Remove TODAS as fontes de calor ativas do mapa e limpa o rastreador.

---

### 🔒 `ObterTodosGeradoresCarregados()` <sub>L271</sub>

> Varre e retorna a lista de todos os geradores físicos relevantes carregados no cliente.

**Retorno:**
- `table` `Lista` — de geradores carregados.

---

### 🔒 `AtualizarTodos()` <sub>L309</sub>

> Avalia e sincroniza o estado elétrico de ativação física com a emissão de calor.

---

### 🔒 `AtualizarTemperaturas()` <sub>L382</sub>

> Recria preventivamente as fontes ativas no mapa para atualização do calor climático.

---

## `client/LKS_EletricidadeConstrucao_Power_ClientSync.lua`

### 🔒 `IsContextoCliente()` <sub>L28</sub>

> Verifica se o contexto de execução atual é o cliente.

**Retorno:**
- `boolean` `Retorna` — true se for cliente.

---

### 🔒 `ObterQuadradoEm(coordenadaX, coordenadaY, coordenadaZ)` <sub>L37</sub>

> Obtém o GridSquare de coordenadas específicas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `coordenadaX` | `number` | Coordenada X. |
| `coordenadaY` | `number` | Coordenada Y. |
| `coordenadaZ` | `number` | Coordenada Z. |

**Retorno:**
- `any|nil` `O` — GridSquare correspondente ou nil.

---

### 🔒 `ObterPacoteLocal()` <sub>L48</sub>

> Obtém a tabela de dados ModData local associada à chave de sincronismo.

**Retorno:**
- `table` `A` — tabela ModData de sincronização de energia.

---

### 🔒 `ObterEstadosConstrucoes()` <sub>L59</sub>

> Obtém o pacote local e a lista de estados de construções contida nele.

**Retorno:**
- `table` `O` — pacote local ModData.
- `table` `A` — lista de estados das construções.

---

### 🔒 `DeveAfetarQuadrado(quadrado, estado)` <sub>L69</sub>

> Verifica se o GridSquare deve ser afetado pelo estado elétrico da construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `any` | O GridSquare que está sendo avaliado. |
| `estado` | `table` | O estado da construção que possui energia. |

**Retorno:**
- `boolean` `Retorna` — true se o quadrado deve ser energizado por esta construção.

---

### 🔒 `AplicarEnergiaQuadradoLocal(quadrado, deveEnergizar)` <sub>L101</sub>

> Adiciona ou remove a posição virtual de gerador no Chunk correspondente ao quadrado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `any` | O GridSquare que receberá ou perderá energia virtual. |
| `deveEnergizar` | `boolean` | Define se deve adicionar (true) ou remover (false) a energia. |

**Retorno:**
- `any|nil` `O` — Chunk modificado ou nil se não encontrado.

---

### 🔒 `AplicarEstadoConstrucaoCarregada(estado, deveEnergizar)` <sub>L132</sub>

> Aplica o estado de energia nas posições da construção carregadas no mapa.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `estado` | `table` | O estado da construção que possui energia. |
| `deveEnergizar` | `boolean` | Define se deve adicionar (true) ou remover (false) a energia. |

**Retorno:**
- `number,` `number` — O total de quadrados afetados e o total de chunks recalculados.

---

### 🔒 `SincronizarAPartirDePacote(novoPacote)` <sub>L171</sub>

> Sincroniza os estados de energia locais a partir de um novo pacote ModData de sincronização.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `novoPacote` | `table` | O novo pacote ModData recebido do servidor. |

---

### 🔒 `SolicitarEstado()` <sub>L200</sub>

> Solicita o estado atual das construções energizadas para o servidor.

---

### 🔒 `AoIniciarModDataGlobal()` <sub>L210</sub>

> Inicializa e sincroniza os dados do ModData ao carregar os dados globais.

---

### 🔒 `AoReceberModDataGlobal(chave, pacote)` <sub>L221</sub>

> Executa a sincronização local ao receber a atualização de dados globais do servidor.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `chave` | `string` | A chave do ModData atualizado. |
| `pacote` | `table` | O pacote de dados recebido do servidor. |

---

### 🔒 `AoCarregarGridSquare(quadrado)` <sub>L230</sub>

> Aplica a energia local ao carregar um novo GridSquare se pertencer a uma construção energizada.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `any` | O GridSquare que foi carregado no mapa. |

---

## `client/devices/LKS_Device_Cooking.lua`

### 🔒 `obterTexturaEstado(chaveConfiguracao, temEnergia)` <sub>L48</sub>

> Retorna a textura correspondente baseada nos estados de energia e tipo de contêiner.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `chaveConfiguracao` | `string` | O tipo de aparelho ("stove", "microwave"). |
| `temEnergia` | `boolean` | Se o aparelho possui fornecimento elétrico ativo. |

**Retorno:**
- `Texture` `O` — objeto de textura carregado do jogo.

---

### 🔒 `verificarPresencaMetal(containerInventario)` <sub>L63</sub>

> Verifica se há objetos metálicos no interior do contêiner do micro-ondas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `containerInventario` | `ItemContainer` | O contêiner de itens a inspecionar. |

**Retorno:**
- `boolean` `contemMetal` — Retorna true se houver pelo menos um item metálico.

---

### 🌐 `LKS_Device_Cooking.obterTexturaInventario(recipiente, recipienteTipo, objetoPai, temEnergia)` <sub>L92</sub>

> Retorna a textura para a Loot Window baseada no estado de energia do recipiente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `recipiente` | `ItemContainer` | O contêiner sendo desenhado. |
| `recipienteTipo` | `string` | O tipo do contêiner. |
| `objetoPai` | `IsoObject` | O objeto pai no mundo. |
| `temEnergia` | `boolean` | Se o contêiner possui energia elétrica ativa. |

**Retorno:**
- `Texture` `A` — textura resolvida para o inventário.

---

### 🌐 `LKS_Device_Cooking.construirMenuContexto(jogadorNumero, menuContexto, objetosMundo, objetoEletrico)` <sub>L145</sub>

> Constrói o submenu LKS para fogões e micro-ondas no mundo.
> ## Como funciona o menu de contexto no Project Zomboid (ISContextMenu):
> O jogo dispara o evento `OnFillWorldObjectContextMenu` para cada clique-direito
> no mundo. Múltiplos handlers (vanilla + mods) adicionam opções ao mesmo `menuContexto`.
> Para aparelhos como fogões e micro-ondas, o vanilla JÁ cria um submenu agrupador
> com o nome traduzido do objeto (ex: "Fogão Vermelho"), e dentro dele coloca as
> opções "Ligar/Desligar" e "Configurações" (timer, temperatura, potência).
> ### Anatomia de uma opção (`menuContexto.options[i]`):
> - `.name`         → Texto exibido (string traduzida via getText)
> - `.onSelect`     → Callback executado ao clicar
> - `.target`       → Primeiro argumento passado ao callback
> - `.param1/.param2` → Argumentos adicionais do callback
> - `.iconTexture`  → Textura exibida à esquerda da opção
> - `.toolTip`      → Tooltip ISToolTip exibido ao passar o mouse
> - `.notAvailable` → Se true, a opção fica cinza/desabilitada
> - `.subOption`    → ID do submenu vinculado (via `addSubMenu`)
> ### Operações principais da API ISContextMenu:
> - `menuContexto:addOption(texto, alvo, callback, param1, param2)` → Adiciona opção
> - `menuContexto:addOptionOnTop(texto)` → Adiciona no topo (prioridade visual)
> - `ISContextMenu:getNew(menuPai)` → Cria submenu vinculado ao menu pai
> - `menuContexto:addSubMenu(opcaoPai, submenu)` → Vincula submenu a uma opção
> - `menuContexto:removeOptionByName(texto)` → Remove opção por nome exato
> - `menuContexto:getSubMenu(idSubmenu)` → Obtém referência ao submenu de uma opção
> ### Estratégia de sequestro do submenu vanilla:
> Em vez de criar um SEGUNDO submenu com o mesmo nome (causando duplicata),
> a abordagem correta é:
> 1. LOCALIZAR a opção vanilla existente pelo nome do objeto traduzido
> 2. OBTER o submenu vanilla já criado via `.subOption`
> 3. REMOVER apenas as opções que queremos substituir (Ligar/Desligar)
> 4. INJETAR nossas opções aprimoradas no submenu existente
> 5. PRESERVAR tudo que não tocamos (Configurações e qualquer outra)

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogadorNumero` | `number` | O índice do jogador local (0 a 3). |
| `menuContexto` | `ISContextMenu` | O menu de contexto sendo preenchido. |
| `objetosMundo` | `table` | A lista de objetos físicos clicados no mundo. |
| `objetoEletrico` | `IsoObject` | O objeto elétrico clicado. |

---

## `client/devices/LKS_Device_Laundry.lua`

### 🔒 `obterTexturaEstado(chaveConfiguracao, temEnergia, temAgua, direcao)` <sub>L47</sub>

> Retorna a textura correspondente baseada nos estados de energia, água e direção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `chaveConfiguracao` | `string` | O tipo de aparelho ("clothingdryer", "clothingwasher", "combo_washer_dryer"). |
| `temEnergia` | `boolean` | Se o aparelho possui fornecimento elétrico ativo (ignorado no desenho base). |
| `temAgua` | `boolean` | Se o aparelho possui água disponível (ignorado no desenho base). |
| `direcao` | `string` | | nil A direção/facing do móvel (ignorado após simplificação). |

**Retorno:**
- `Texture` `O` — objeto de textura carregado do jogo.

---

### 🌐 `LKS_Device_Laundry.obterTexturaInventario(recipiente, recipienteTipo, objetoPai, temEnergia)` <sub>L65</sub>

> Retorna a textura para a Loot Window baseada no estado de energia e água do recipiente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `recipiente` | `ItemContainer` | O contêiner sendo desenhado. |
| `recipienteTipo` | `string` | O tipo do contêiner. |
| `objetoPai` | `IsoObject` | O objeto pai no mundo. |
| `temEnergia` | `boolean` | Se o contêiner possui energia elétrica ativa. |

**Retorno:**
- `Texture` `A` — textura resolvida para o inventário.

---

### 🌐 `LKS_Device_Laundry.construirMenuContexto(jogadorNumero, menuContexto, objetosMundo, objetoEletrico)` <sub>L110</sub>

> Constrói o submenu premium para secadoras, lavadoras e combo washer dryer.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogadorNumero` | `number` | O índice do jogador local (0 a 3). |
| `menuContexto` | `ISContextMenu` | O menu de contexto sendo preenchido. |
| `objetosMundo` | `table` | A lista de objetos físicos clicados no mundo. |
| `objetoEletrico` | `IsoObject` | O objeto elétrico clicado. |

---

## `client/devices/LKS_Device_Refrigeration.lua`

### 🔒 `customPrint(text)` <sub>L34</sub>

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `text` | `String` |  |

---

### 🌐 `ISToggleFridgesFreezers:isValid()` <sub>L45</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `ISToggleFridgesFreezers:update()` <sub>L49</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `ISToggleFridgesFreezers:start()` <sub>L52</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `ISToggleFridgesFreezers:stop()` <sub>L56</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `ISToggleFridgesFreezers:perform()` <sub>L60</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `ISToggleFridgesFreezers:new(objPlayer, state, obj)` <sub>L69</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_Device_Refrigeration.construirMenuContexto(jogadorNumero, menuContexto, objetosMundo, objetoEletrico)` <sub>L98</sub>

> Constrói o menu premium de tomada para geladeiras e congeladores.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogadorNumero` | `number` | O índice do jogador local (0 a 3). |
| `menuContexto` | `ISContextMenu` | O menu de contexto sendo preenchido. |
| `objetosMundo` | `table` | A lista de objetos físicos clicados no mundo. |
| `objetoEletrico` | `IsoObject` | O objeto elétrico clicado. |

---

### 🔒 `onServerCommand(module, command, args)` <sub>L126</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `registrarTexturasGlobais()` <sub>L202</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `client/ui/LKS_EletricidadeConstrucao_UI_DebugPanel.lua`

### 🔒 `OnKeyPressed(key)` <sub>L20</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `client/ui/LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow.lua`

### 🔒 `FindAdjacentWalkable(targetSq, fromChar)` <sub>L96</sub>

> Encontra o quadrado caminhável mais próximo adjacente a um quadrado alvo,
> ordenado por proximidade a fromChar para que o jogador se aproxime naturalmente.
> Retorna: adjSquare, valor IsoDirections para olhar em direção a targetSq (or nil, nil).

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:initialise()` <sub>L152</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:createChildren()` <sub>L156</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:calculateLayout()` <sub>L222</sub>

> Calcula as dimensões ideais do layout com base nas strings do idioma atual.
> Retorna: { winW, barCol }

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:drawStatBar(x, y, label, value, maxValue, greenHigh, barCol)` <sub>L265</sub>

> Barra de progresso com rótulo. greenHigh=true: verde=alto é bom.

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:drawStrainBar(x, y, label, strain, barCol)` <sub>L318</sub>

> Barra de carga baseada em imagem com 10 segmentos. Verde (1-4) → laranja (5-7) → vermelho (8-10).

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:drawBarrelFuelBar(x, y, amount, maxAmount, barWidth)` <sub>L397</sub>

> Barra de combustível amarela gasolina com 6 segmentos para barris.

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:drawSection(x, y, title)` <sub>L436</sub>

> Separador fino + título da seção. Retorna o próximo Y.

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:getGeneratorIcon(gen)` <sub>L444</sub>

> Resolve uma textura para um sprite específico de gerador, com cache e fallback.

---

### 🔒 `TableContainsValue(t, value)` <sub>L466</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `TableCountEntries(t)` <sub>L474</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `IsInsideBuildingBounds(buildingData, x, y)` <sub>L483</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `FindLoadedGeneratorAt(x, y, z)` <sub>L499</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `CountBuildingConsumers(buildingData)` <sub>L519</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `IsGeneratorDataRunning(generatorData)` <sub>L559</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `BuildSyntheticGeneratorModData(generatorData, buildingData, target)` <sub>L565</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `GetGeneratorCoords(generator)` <sub>L589</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `GetLiveGeneratorObject(generator)` <sub>L604</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `GetGeneratorStateData(x, y, z)` <sub>L618</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `CreateGeneratorProxy(generatorData, buildingData)` <sub>L629</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `CreateBuildingAnchorProxy(buildingData, anchorSquare)` <sub>L701</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `GetGeneratorReferenceAt(x, y, z, buildingData)` <sub>L738</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `GetGeneratorReferenceKey(generator)` <sub>L744</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `GeneratorDataMatchesBuilding(generatorData, buildingData, anchorSquare, stateManager)` <sub>L750</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `CollectGeneratorReferencesForBuilding(buildingData, anchorSquare)` <sub>L783</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `ResolveBuildingDataFromAnchor(anchorSquare, buildingHint)` <sub>L833</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `ResolveBuildingPool(generator)` <sub>L879</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:scanAllGenerators()` <sub>L921</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:sortGeneratorsByConnectionOrder(genList)` <sub>L992</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:titleBarHeight()` <sub>L1029</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:prerender()` <sub>L1033</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:updateData()` <sub>L1086</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:onMouseDown(x, y)` <sub>L1246</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:onMouseMove(dx, dy)` <sub>L1310</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:onMouseMoveOutside(dx, dy)` <sub>L1333</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `CountHeatingSources(md)` <sub>L1343</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `SendHeatingConfig(window, enabled, targetTemp)` <sub>L1356</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `ApplyHeatingConfigLocal(window, enabled, targetTemp)` <sub>L1389</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:onHeatingSetState(enable)` <sub>L1462</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:onHeatingToggle()` <sub>L1496</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:onHeatingTempChange(delta)` <sub>L1500</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:requestFreshStats()` <sub>L1539</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:findBuildingDef()` <sub>L1600</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:applyHighlights(enabled)` <sub>L1627</sub>

> Destaca ou remove o destaque de todos os tiles de piso/parede da construção do gerador.

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:onToggleCoverage()` <sub>L1695</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:onClose()` <sub>L1707</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:render()` <sub>L1715</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:close()` <sub>L2180</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow:new(x, y, generator, playerNum, anchorSquare)` <sub>L2206</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow.Open(character, generator, anchorSquare, buildingHint)` <sub>L2223</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_GeneratorInfoWindow.CloseAll()` <sub>L2278</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `server/LKS_Device_Refrigeration_Server.lua`

### 🔒 `customPrint(text)` <sub>L37</sub>

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `text` | `String` |  |

---

### 🌐 `updateGenerators(cX, cY, cZ)` <sub>L50</sub>

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `cX` | `Integer` |  |
| `cY` | `Integer` |  |
| `cZ` | `Integer` |  |

---

### 🔒 `onClientCommand(module,command,player,args)` <sub>L90</sub>

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `module` | `String` |  |
| `command` | `String` |  |
| `player` | `IsoPlayer` |  |
| `args` | `KahluaTable` |  |

---

## `server/LKS_EletricidadeConstrucao_DebugCommands.lua`

### 🔒 `CMD_ListarGeradores(player, args)` <sub>L40</sub>

> Imprime todos os geradores registrados no console.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🔒 `CMD_ListarConstrucoes(player, args)` <sub>L70</sub>

> Imprime todas as construções registradas no console.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🔒 `CMD_ListarConexoes(player, args)` <sub>L112</sub>

> Imprime todas as conexões ativas de energia.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🔒 `CMD_InformacoesConstrucao(player, args)` <sub>L124</sub>

> Imprime informações detalhadas de uma construção específica.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Lista com o id da construção. |

---

### 🔒 `CMD_EscanearConstrucoes(player, args)` <sub>L175</sub>

> Força o escaneamento manual de todas as construções no servidor.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🔒 `CMD_AtualizarConexoes(player, args)` <sub>L190</sub>

> Força a atualização imediata das conexões de energia.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🔒 `CMD_AtualizarEnergia(player, args)` <sub>L205</sub>

> Força a atualização da distribuição de carga elétrica nas redes.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🔒 `CMD_EscanearAqui(player, args)` <sub>L220</sub>

> Escaneia a construção ao redor da posição atual do jogador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🔒 `CMD_ReescanearTudo(player, args)` <sub>L237</sub>

> Rescaneia completamente todas as construções registradas em memória.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🔒 `CMD_Estado(player, args)` <sub>L252</sub>

> Exibe estatísticas consolidadas do estado elétrico do servidor.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🔒 `CMD_SalvarEstado(player, args)` <sub>L297</sub>

> Força o salvamento manual do estado em disco.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🔒 `CMD_LimparEstado(player, args)` <sub>L306</sub>

> Limpa completamente todo o estado elétrico salvo e em memória (AÇÃO DESTRUTIVA!).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos de confirmação. |

---

### 🔒 `CMD_Ajuda(player, args)` <sub>L321</sub>

> Exibe o painel de ajuda dos comandos de depuração admin.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador executando. |
| `args` | `table` | Argumentos adicionais. |

---

### 🌐 `LKS_EletricidadeConstrucao.DebugCommands.RegisterCommands()` <sub>L343</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao.DebugCommands.Initialize()` <sub>L374</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `_LimparDadosModIsoGerador(objeto)` <sub>L394</sub>

> Zera todas as chaves do mod no ModData de um objeto físico IsoGenerator.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objeto` | `any` | O objeto IsoGenerator. |

---

### 🌐 `LKS_EletricidadeConstrucao.DebugCommands.WipeAllData()` <sub>L423</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `server/LKS_EletricidadeConstrucao_ServerCommands.lua`

### 🔒 `LocalizarGeradorEm(coordenadaX, coordenadaY, coordenadaZ)` <sub>L26</sub>

> Localiza o objeto IsoGenerator nas coordenadas especificadas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `coordenadaX` | `number` | Coordenada X. |
| `coordenadaY` | `number` | Coordenada Y. |
| `coordenadaZ` | `number` | Coordenada Z. |

**Retorno:**
- `any|nil` `O` — objeto IsoGenerator encontrado ou nil.

---

### 🔒 `IsJogadorProximoAoQuadrado(jogador, quadrado, distanciaMaxima)` <sub>L51</sub>

> Verifica se o jogador está a uma distância aceitável de um GridSquare específico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogador` | `any` | O objeto IsoPlayer. |
| `quadrado` | `any` | O GridSquare correspondente. |
| `distanciaMaxima` | `number|nil` | Distância máxima aceitável (padrão: 2). |

**Retorno:**
- `boolean` `Retorna` — true se estiver próximo.

---

### 🔒 `IsJogadorProximoAoGerador(jogador, gerador)` <sub>L68</sub>

> Verifica se o jogador está próximo a um gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogador` | `any` | O objeto IsoPlayer. |
| `gerador` | `any` | O objeto IsoGenerator. |

**Retorno:**
- `boolean` `Retorna` — true se estiver próximo.

---

### 🔒 `IsJogadorProximoAncoraAquecimento(jogador, argumentos)` <sub>L77</sub>

> Verifica se o jogador está próximo a uma âncora de aquecimento especificada no payload.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogador` | `any` | O objeto IsoPlayer. |
| `argumentos` | `table` | Os argumentos contendo as coordenadas da âncora. |

**Retorno:**
- `boolean` `Retorna` — true se estiver próximo.

---

### 🔒 `TabelaPossuiEntradas(tabela)` <sub>L95</sub>

> Verifica se uma tabela Lua possui entradas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser verificada. |

**Retorno:**
- `boolean` `Retorna` — true se possuir chaves.

---

### 🔒 `EstaDentroDaCaixaDelimitadora(dadosConstrucao, coordenadaX, coordenadaY)` <sub>L108</sub>

> Verifica se as coordenadas estão dentro da caixa delimitadora da construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados da construção no StateManager. |
| `coordenadaX` | `number` | Coordenada X. |
| `coordenadaY` | `number` | Coordenada Y. |

**Retorno:**
- `boolean` `Retorna` — true se as coordenadas estiverem dentro da área da construção.

---

### 🔒 `LocalizarConstrucaoIsoProxima(celula, quadrado, raio)` <sub>L129</sub>

> Busca uma estrutura de construção física nas imediações de um quadrado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `celula` | `any` | A célula ativa. |
| `quadrado` | `any` | O GridSquare central. |
| `raio` | `number` | O raio de busca em blocos. |

**Retorno:**
- `any|nil` `O` — objeto IsoBuilding correspondente ou nil.

---

### 🔒 `ConstrucaoCorrespondeAIso(dadosConstrucao, construcaoIso, celula, fallbackZ)` <sub>L160</sub>

> Verifica se os dados lógicos correspondem à construção física.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados lógicos da construção. |
| `construcaoIso` | `any` | A estrutura física IsoBuilding. |
| `celula` | `any` | A célula ativa. |
| `fallbackZ` | `number` | Coordenada Z de fallback. |

**Retorno:**
- `boolean` `Retorna` — true se corresponderem.

---

### 🔒 `IsGeradorFuncionando(dadosGerador)` <sub>L171</sub>

> Verifica se o gerador lógico ou físico está ativo e com combustível.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados do gerador. |

**Retorno:**
- `boolean` `Retorna` — true se estiver funcionando.

---

### 🔒 `ObterForcaCorrespondenciaGeradorConstrucao(dadosGerador, dadosConstrucao, quadrado, gerenciadorEstado, idPoolAtiva)` <sub>L187</sub>

> Retorna um score de acoplamento entre um gerador e uma construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados do gerador. |
| `dadosConstrucao` | `table` | Os dados da construção. |
| `quadrado` | `any` | O GridSquare do gerador. |
| `gerenciadorEstado` | `table` | O StateManager do mod. |
| `idPoolAtiva` | `string|nil` | O ID do pool ativo. |

**Retorno:**
- `number` `O` — peso ou força da correspondência.

---

### 🔒 `GeradorReferenciaConstrucao(dadosGerador, dadosConstrucao, quadrado, gerenciadorEstado)` <sub>L239</sub>

> Verifica se o gerador possui referência direta à construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados do gerador. |
| `dadosConstrucao` | `table` | Os dados da construção. |
| `quadrado` | `any` | O GridSquare do gerador. |
| `gerenciadorEstado` | `table` | O StateManager do mod. |

**Retorno:**
- `boolean` `Retorna` — true se houver conexão/referência.

---

### 🔒 `ObterPontuacaoGeradorConstrucao(dadosConstrucao, quadrado, gerenciadorEstado)` <sub>L248</sub>

> Calcula um score de relevância do gerador para a construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados da construção. |
| `quadrado` | `any` | O GridSquare do gerador. |
| `gerenciadorEstado` | `table` | O StateManager do mod. |

**Retorno:**
- `number` `A` — pontuação de relevância calculada.

---

### 🔒 `PontuarCandidatoConstrucao(dadosConstrucao, quadrado, construcaoIso, raio, celula, gerenciadorEstado, idConstrucaoPreferencial)` <sub>L323</sub>

> Pontua um candidato de construção a receber energia física com base no posicionamento e rede.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados da construção. |
| `quadrado` | `any` | O GridSquare avaliado. |
| `construcaoIso` | `any` | A estrutura física IsoBuilding próxima. |
| `raio` | `number` | O raio máximo. |
| `celula` | `any` | A célula ativa. |
| `gerenciadorEstado` | `table` | O StateManager do mod. |
| `idConstrucaoPreferencial` | `string|nil` | O ID da construção que tem preferência de acoplamento. |

**Retorno:**
- `number|nil` `O` — score calculado ou nil se inválido.

---

### 🔒 `ResolverConstrucaoDoBarril(quadrado, idConstrucaoPreferencial, raio)` <sub>L364</sub>

> Resolve a qual ID de construção lógica do StateManager um barril deve ser vinculado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `any` | O GridSquare do barril. |
| `idConstrucaoPreferencial` | `string|nil` | O ID da construção de preferência. |
| `raio` | `number|nil` | O raio de busca (padrão: 20). |

**Retorno:**
- `table|nil` `O` — registro da construção correspondente ou nil.

---

### 🔒 `ContarEntradasMapa(tabela)` <sub>L398</sub>

> Conta a quantidade de entradas em um dicionário/tabela Lua.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser contada. |

**Retorno:**
- `number` `A` — quantidade de chaves.

---

### 🔒 `CopiarCaixaDelimitadora(source)` <sub>L410</sub>

> Cria uma cópia profunda dos dados de Bounding Box de uma construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `source` | `table` | A tabela original. |

**Retorno:**
- `table|nil` `A` — cópia gerada ou nil.

---

### 🔒 `TabelaContemValor(tabela, valor)` <sub>L433</sub>

> Verifica se uma tabela contém um valor específico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela para busca. |
| `valor` | `any` | O valor procurado. |

**Retorno:**
- `boolean` `Retorna` — true se o valor for encontrado.

---

### 🔒 `ResolverDadosPoolParaConstrucao(idConstrucao, gerador)` <sub>L445</sub>

> Busca os dados de rede de energia salvos no ModData do gerador ou em geradores vizinhos vinculados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `idConstrucao` | `string` | O ID da construção. |
| `gerador` | `any` | O objeto IsoGenerator físico. |

**Retorno:**
- `table|nil` `Os` — dados salvos de LKS_EletricidadeConstrucao_PoolData ou nil.

---

### 🔒 `RestaurarConstrucaoDosDadosPool(idConstrucao, stateManager, dadosPool, anchorX, anchorY, anchorZ, motivo)` <sub>L489</sub>

> Reconstrói o estado lógico de uma construção no StateManager a partir dos metadados de Pool salvos no gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `idConstrucao` | `string` | O ID da construção. |
| `stateManager` | `table` | O StateManager do mod. |
| `dadosPool` | `table` | Os dados recuperados do gerador. |
| `anchorX` | `number` | Coordenada X da âncora. |
| `anchorY` | `number` | Coordenada Y da âncora. |
| `anchorZ` | `number` | Coordenada Z da âncora. |
| `motivo` | `string` | Identificador do motivo de restauração. |

**Retorno:**
- `table|nil` `A` — tabela do estado reconstruído ou nil.

---

### 🔒 `GarantirEstadoConstrucao(idConstrucao, gerador, motivo)` <sub>L535</sub>

> Garante que a construção referenciada exista no StateManager do servidor (restaura se deletada ou corrompida).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `idConstrucao` | `string` | O ID da construção. |
| `gerador` | `any` | O objeto IsoGenerator associado. |
| `motivo` | `string` | Identificador do motivo. |

**Retorno:**
- `table|nil` `O` — estado da construção garantido ou nil.

---

### 🔒 `AvisarRequisicaoInvalida(command, reason)` <sub>L646</sub>

> Imprime um aviso de requisição rejeitada no logger do servidor.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `command` | `string` | O nome do comando. |
| `reason` | `string` | O motivo de rejeição. |

---

### 🔒 `EnviarResultadoAcao(player, kind, success, args)` <sub>L657</sub>

> Envia uma notificação de resultado de ação (ActionResult) ao cliente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador destinatário. |
| `kind` | `string` | O tipo de comando. |
| `success` | `boolean` | Status de sucesso. |
| `args` | `table|nil` | Dados adicionais do payload. |

---

### 🔒 `RejeitarRequisicao(player, command, reason, args)` <sub>L672</sub>

> Rejeita a requisição e envia uma resposta com falha e mensagem legível ao jogador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `player` | `any` | O jogador destinatário. |
| `command` | `string` | O nome do comando. |
| `reason` | `string` | O motivo técnico interno. |
| `args` | `table|nil` | O payload com dados do comando. |

---

### 🔒 `AoReceberComandoCliente(module, command, player, args)` <sub>L688</sub>

> Manipula e processa os comandos enviados pelos clientes.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `module` | `string` | O módulo identificador. |
| `command` | `string` | O comando recebido. |
| `player` | `any` | O jogador que solicitou o comando. |
| `args` | `table` | Argumentos contidos na requisição. |

---

## `server/LKS_EletricidadeConstrucao_ServerInit.lua`

### 🔒 `InicializarSistemasServidor()` <sub>L70</sub>

> Inicializa todos os subsistemas do lado do servidor.

---

### 🔒 `AoIniciarJogo()` <sub>L124</sub>

> Manipula o evento OnGameBoot (chamado uma vez ao iniciar o servidor).

---

### 🔒 `ACadaUmMinuto()` <sub>L139</sub>

> Manipula o evento EveryOneMinute (atualizações de loop periódico).

---

### 🔒 `ACadaDezMinutos()` <sub>L197</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `AoDesligarServidor()` <sub>L215</sub>

> Manipula o desligamento do servidor.

---

### 🔒 `AoSalvar()` <sub>L227</sub>

> Manipula o evento OnSave regular (salvamento com proteção de backup a cada ~5 minutos).

---

## `server/building/LKS_EletricidadeConstrucao_Building_BorderDetector.lua`

### 🔒 `TemInterruptorDeLuzNoNivel(comodo, coordenadaZ)` <sub>L44</sub>

> Verifica se um nível Z específico possui pelo menos um interruptor de luz nos limites do cômodo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `comodo` | `any` | O objeto BuildingDef do cômodo. |
| `coordenadaZ` | `number` | O nível Z. |

**Retorno:**
- `boolean` `Retorna` — true se houver pelo menos um interruptor.

---

### 🔒 `TemInterruptorDeLuzNosLimites(limiteX1, limiteY1, limiteX2, limiteY2, coordenadaZ)` <sub>L76</sub>

> Verifica se um nível Z possui pelo menos um interruptor nos limites retangulares dados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `limiteX1` | `number` | Coordenada X mínima. |
| `limiteY1` | `number` | Coordenada Y mínima. |
| `limiteX2` | `number` | Coordenada X máxima. |
| `limiteY2` | `number` | Coordenada Y máxima. |
| `coordenadaZ` | `number` | O nível Z. |

**Retorno:**
- `boolean` `Retorna` — true se houver pelo menos um interruptor.

---

### 🔒 `ObterNiveisZParaEscanear(comodo, inicioZ)` <sub>L100</sub>

> Determina quais níveis Z devem ser escaneados baseando-se na presença de interruptores.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `comodo` | `any` | O objeto BuildingDef do cômodo. |
| `inicioZ` | `number` | O nível Z inicial. |

**Retorno:**
- `table` `Uma` — lista com os níveis Z para escaneamento.

---

### 🔒 `ObterNiveisZParaEscanearLimites(limiteX1, limiteY1, limiteX2, limiteY2, inicioZ)` <sub>L137</sub>

> Determina quais níveis Z devem ser escaneados baseando-se em limites geométricos (sem cômodos associados).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `limiteX1` | `number` | Coordenada X mínima. |
| `limiteY1` | `number` | Coordenada Y mínima. |
| `limiteX2` | `number` | Coordenada X máxima. |
| `limiteY2` | `number` | Coordenada Y máxima. |
| `inicioZ` | `number` | O nível Z inicial. |

**Retorno:**
- `table` `Uma` — lista com os níveis Z para escaneamento.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBorders(inicioX, inicioY, inicioZ, raio, idConstrucao)` <sub>L173</sub>

> Detecta todos os quadrados (tiles) pertencentes ao mesmo IsoBuilding do interruptor de luz.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `inicioX` | `number` | Coordenada X inicial. |
| `inicioY` | `number` | Coordenada Y inicial. |
| `inicioZ` | `number` | Coordenada Z inicial. |
| `raio` | `number` | Raio de recuo utilizado apenas em fallbacks. |
| `idConstrucao` | `string|nil` | ID opcional da construção (identifica construções feitas por jogadores). |

**Retorno:**
- `table` `Lista` — contendo os quadrados identificados.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(cx, cy, cz, r)` <sub>L357</sub>

> Varredura de fallback por raio ao redor de um ponto central.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `cx` | `number` | Centro X. |
| `cy` | `number` | Centro Y. |
| `cz` | `number` | Centro Z. |
| `r` | `number` | Raio. |

**Retorno:**
- `table` `Lista` — de quadrados identificados.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.BorderDetector.HasBarrier(x1, y1, z1, x2, y2, z2)` <sub>L385</sub>

> Verifica se há barreiras físicas (paredes/portas fechadas) entre dois quadrados adjacentes.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x1` | `number` | X de origem. |
| `y1` | `number` | Y de origem. |
| `z1` | `number` | Z de origem. |
| `x2` | `number` | X de destino. |
| `y2` | `number` | Y de destino. |
| `z2` | `number` | Z de destino. |

**Retorno:**
- `boolean` `Retorna` — true se houver barreira.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.BorderDetector.HasWallTowards(quadrado, targetX, targetY)` <sub>L401</sub>

> Verifica se o quadrado possui parede na direção do ponto de destino.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `any` | O GridSquare avaliado. |
| `targetX` | `number` | Destino X. |
| `targetY` | `number` | Destino Y. |

**Retorno:**
- `boolean` `Retorna` — true se houver parede.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.BorderDetector.HasDoorBetween(quadrado1, quadrado2, x1, y1, x2, y2)` <sub>L415</sub>

> Verifica se há uma porta conectando dois quadrados específicos.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado1` | `any` | Primeiro quadrado. |
| `quadrado2` | `any` | Segundo quadrado. |
| `x1` | `number` | X do primeiro quadrado. |
| `y1` | `number` | Y do primeiro quadrado. |
| `x2` | `number` | X do segundo quadrado. |
| `y2` | `number` | Y do segundo quadrado. |

**Retorno:**
- `boolean` `Retorna` — true se existir porta.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.BorderDetector.HasDoorTowards(quadrado, targetX, targetY)` <sub>L430</sub>

> Verifica se o quadrado possui um objeto IsoDoor na direção das coordenadas de destino.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `any` | O quadrado a ser avaliado. |
| `targetX` | `number` | Destino X. |
| `targetY` | `number` | Destino Y. |

**Retorno:**
- `boolean` `Retorna` — true se existir uma porta.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(tiles)` <sub>L461</sub>

> Remove duplicidades de uma lista de coordenadas de quadrados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tiles` | `table` | Lista com chaves x, y, z. |

**Retorno:**
- `table` `Lista` — unificada sem duplicidades.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBordersRaycast(startX, startY, startZ, raio)` <sub>L486</sub>

> Detecta limites usando algoritmo de Raycasting (mais veloz, porém menos preciso).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `startX` | `number` | Início X. |
| `startY` | `number` | Início Y. |
| `startZ` | `number` | Início Z. |
| `raio` | `number` | Raio limite. |

**Retorno:**
- `table` `Lista` — de quadrados de borda.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.BorderDetector.GetInteriorTiles(startX, startY, startZ, raio)` <sub>L532</sub>

> Coleta todas as coordenadas de interior pertencentes ao mesmo IsoBuilding.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `startX` | `number` | Início X. |
| `startY` | `number` | Início Y. |
| `startZ` | `number` | Início Z. |
| `raio` | `number` | Raio de recuo caso não encontre IsoBuilding físico. |

**Retorno:**
- `table` `Lista` — de coordenadas dos quadrados internos.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.BorderDetector.DebugBorders(x, y, z, raio)` <sub>L593</sub>

> Imprime informações de depuração do detector de limites no console.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Posição X. |
| `y` | `number` | Posição Y. |
| `z` | `number` | Posição Z. |
| `raio` | `number` | Raio. |

---

## `server/building/LKS_EletricidadeConstrucao_Building_ConsumerScanner.lua`

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.ScanConsumers(dadosConstrucao, quadradosBorda)` <sub>L32</sub>

> Escaneia a construção física em busca de consumidores de energia.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados da construção no StateManager. |
| `quadradosBorda` | `table` | A lista de quadrados pertencentes à construção. |

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.RescanConsumers(dadosConstrucao)` <sub>L227</sub>

> Reescreve e rescaneia cômodos elétricos de uma construção existente (após modificações físicas no mundo).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados da construção no StateManager. |

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerType(object)` <sub>L302</sub>

> Retorna a classificação de tipo de consumidor elétrico de um IsoObject.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `object` | `any` | O objeto físico no mundo. |

**Retorno:**
- `string|nil` `O` — tipo ("light", "lamp", "appliance") ou nil.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.IsAppliance(object)` <sub>L352</sub>

> Verifica se o objeto físico é classificado como um eletrodoméstico/aparelho consumidor.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `object` | `any` | O objeto do mundo. |

**Retorno:**
- `boolean` `Retorna` — true se for um aparelho.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceCandidateTag(object)` <sub>L413</sub>

> Retorna identificadores e dados internos de objetos suspeitos de serem aparelhos para fins de depuração.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `object` | `any` | O objeto avaliado. |

**Retorno:**
- `string|nil` `A` — string descritiva.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerPowerDraw(dadosConsumidor)` <sub>L432</sub>

> Retorna o consumo padrão de energia de um consumidor genérico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `table` | Os dados do consumidor. |

**Retorno:**
- `number` `Valor` — numérico de consumo.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceDetails(object)` <sub>L454</sub>

> Retorna os detalhes de um eletrodoméstico específico e sua respectiva taxa de queima/consumo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `object` | `any` | O objeto no mundo. |

**Retorno:**
- `string|nil` `tipoDispositivo` — A chave do tipo.
- `number` `taxaCombustivel` — O consumo vanilla por hora.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.UpdateConsumerPowerState(dadosConsumidor, energizado)` <sub>L551</sub>

> Atualiza o estado físico de consumo elétrico (ativo/inativo) no mundo real.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `table` | O registro lógico do consumidor. |
| `energizado` | `boolean` | Status elétrico desejado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.SetObjectPowerState(object, consumerType, isPowered)` <sub>L600</sub>

> Modifica o estado do objeto físico no mundo real de acordo com seu tipo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `object` | `any` | O objeto do mundo. |
| `consumerType` | `string` | O tipo de consumidor. |
| `isPowered` | `boolean` | Status elétrico. |

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.ConsumerExists(dadosConsumidor)` <sub>L637</sub>

> Verifica se o consumidor ainda existe fisicamente no quadrado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `table` | O registro do consumidor. |

**Retorno:**
- `boolean` `Retorna` — true se continuar existindo.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.CleanInvalidConsumers(dadosConstrucao)` <sub>L674</sub>

> Limpa e remove da construção os consumidores inválidos (deletados ou movidos).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados da construção. |

**Retorno:**
- `number` `Quantidade` — de consumidores removidos.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.ConsumerScanner.PrintConsumers(dadosConstrucao)` <sub>L710</sub>

> Imprime estatísticas de depuração de consumidores de uma construção específica.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados da construção. |

---

## `server/building/LKS_EletricidadeConstrucao_Building_Scanner.lua`

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.Initialize()` <sub>L38</sub>

> Inicializa o escaneador de construções.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.IsInitialized()` <sub>L53</sub>

> Verifica se o escaneador de construções está inicializado.

**Retorno:**
- `boolean` `Retorna` — true se estiver inicializado.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.OnObjectAdded(object)` <sub>L63</sub>

> Manipula o evento de adição de objetos físicos para capturar novos interruptores.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `object` | `any` | O objeto físico adicionado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.QueueScan(x, y, z, buildingIdOverride)` <sub>L94</sub>

> Enfileira uma requisição de varredura para a construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada X do interruptor. |
| `y` | `number` | Coordenada Y do interruptor. |
| `z` | `number` | Coordenada Z do interruptor. |
| `buildingIdOverride` | `string|nil` | ID opcional para sobrescrever o ID automático. |

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.ProcessQueue()` <sub>L122</sub>

> Processa os itens pendentes na fila de escaneamento.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.IsBuildingAreaLoaded(buildingData)` <sub>L152</sub>

> Verifica se todos os chunks contidos na área da construção estão devidamente carregados no mapa.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `buildingData` | `table` | Os dados da construção. |

**Retorno:**
- `boolean` `Retorna` — true se todos os pontos chave estiverem carregados.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(x, y, z, buildingIdOverride)` <sub>L184</sub>

> Escaneia a construção física a partir das coordenadas do interruptor de luz.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada X. |
| `y` | `number` | Coordenada Y. |
| `z` | `number` | Coordenada Z. |
| `buildingIdOverride` | `string|nil` | ID opcional para sobrescrever o ID automático. |

**Retorno:**
- `table|nil` `O` — estado da construção mapeado ou nil.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.RescanBuilding(idConstrucao)` <sub>L330</sub>

> Reescreve e rescaneia cômodos elétricos de uma construção existente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `idConstrucao` | `string` | O ID da construção. |

**Retorno:**
- `table|nil` `O` — estado da construção atualizado ou nil.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.RescanAllBuildings()` <sub>L353</sub>

> Rescaneia completamente todas as construções registradas em memória.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.ManualScan(x, y, z)` <sub>L378</sub>

> Realiza o escaneamento manual em coordenadas específicas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada X. |
| `y` | `number` | Coordenada Y. |
| `z` | `number` | Coordenada Z. |

**Retorno:**
- `table|nil` `Os` — dados da construção.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.ScanAllLightSwitches()` <sub>L388</sub>

> Varre o mapa carregado em busca de todos os interruptores de luz e os enfileira para escaneamento.

---

### 🌐 `LKS_EletricidadeConstrucao.Building.Scanner.PrintStatus()` <sub>L434</sub>

> Imprime estatísticas de estado do escaneador no console de depuração.

---

## `server/fuel/LKS_EletricidadeConstrucao_Fuel_Barrels.lua`

### 🔒 `ChaveDoBarril(barril)` <sub>L54</sub>

> Retorna a chave de coordenada única para um barril específico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `barril` | `any` | O objeto do barril. |

**Retorno:**
- `string` `A` — string identificadora.

---

### 🔒 `ObterBancoDadosBarris()` <sub>L61</sub>

> Recupera o banco de dados persistente no ModData do jogo.

**Retorno:**
- `table` `A` — tabela de barris vinculados.

---

### 🔒 `SalvarBancoDadosBarris(dadosMod)` <sub>L69</sub>

> Salva o banco de dados persistente no ModData do jogo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosMod` | `table` | Os dados de barris vinculados. |

---

### 🌐 `Barrels.IsLinkable(objeto)` <sub>L80</sub>

> Verifica se um objeto do mapa pode ser acoplado à rede de combustível.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objeto` | `any` | O objeto a ser avaliado. |

**Retorno:**
- `boolean` `Retorna` — true se for acoplável.

---

### 🌐 `Barrels.GetPetrolAmount(barril)` <sub>L102</sub>

> Retorna a quantidade de gasolina contida em um barril específico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `barril` | `any` | O objeto do barril. |

**Retorno:**
- `number` `A` — quantidade de combustível em litros.

---

### 🌐 `Barrels.RemoveFuel(barril, quantidade)` <sub>L136</sub>

> Retira gasolina de um barril até o limite solicitado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `barril` | `any` | O objeto do barril. |
| `quantidade` | `number` | A quantidade máxima a retirar em litros. |

**Retorno:**
- `number` `A` — quantidade real que foi drenada.

---

### 🌐 `Barrels.Link(barril, idConstrucao)` <sub>L175</sub>

> Vincula um barril físico à rede de combustível de uma construção lógica.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `barril` | `any` | O objeto físico do barril. |
| `idConstrucao` | `string` | O ID da construção correspondente. |

**Retorno:**
- `boolean,` `string` — |nil Retorna status de sucesso e mensagem de erro se falhar.

---

### 🌐 `Barrels.Unlink(barril, idConstrucao)` <sub>L215</sub>

> Desvincula um barril físico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `barril` | `any` | O objeto do barril. |
| `idConstrucao` | `string|nil` | O ID da construção associada (opcional). |

---

### 🌐 `Barrels.IsLinked(barril, idConstrucao)` <sub>L247</sub>

> Verifica se o barril está vinculado à construção específica.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `barril` | `any` | O objeto do barril. |
| `idConstrucao` | `string` | O ID da construção. |

**Retorno:**
- `boolean` `Retorna` — true se estiver vinculado.

---

### 🌐 `Barrels.GetLinkedBuilding(barril)` <sub>L256</sub>

> Retorna o ID da construção vinculada ao barril.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `barril` | `any` | O objeto do barril. |

**Retorno:**
- `string|nil` `O` — ID da construção ou nil.

---

### 🌐 `Barrels.GetLinkedBarrels(idConstrucao)` <sub>L268</sub>

> Coleta a lista de objetos de barris vinculados à construção que estão atualmente carregados no mundo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `idConstrucao` | `string` | O ID da construção. |

**Retorno:**
- `table` `A` — lista de objetos de barris físicos ativos.

---

### 🌐 `Barrels.AutoRefuel(dadosConstrucao)` <sub>L326</sub>

> Executa o abastecimento automático de combustível a partir dos barris acoplados aos geradores vinculados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados da construção lógica. |

---

### 🌐 `Barrels.UpdateAll()` <sub>L385</sub>

> Executa a rotina de reabastecimento automático em todas as construções cadastradas.

---

## `server/fuel/LKS_EletricidadeConstrucao_Fuel_ChunkTracker.lua`

### 🔒 `tabelaPossuiEntradas(tabela)` <sub>L35</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `obterMinutosDoMundo()` <sub>L42</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `precisaRestaurarIso(quadrado)` <sub>L62</sub>

> Retorna true apenas quando um quadrado de gerador precisa de uma restauração completa de IsoModData.
> Um quadrado NÃO precisa de restauração quando seu prédio já está estabelecido no estado
> (a entrada do prédio existe E possui pelo menos um powerConsumer registrado).
> Isso evita que tentarRestaurarDadosModIso seja executada de forma redundante em cada
> retorno de chunk quando Load() já hidratou tudo corretamente. (B-71)

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `IsoGridSquare` | O quadrado a ser verificado. |

**Retorno:**
- `boolean`  — 

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.ChunkTracker.Initialize()` <sub>L92</sub>

> Inicializa o rastreador de chunks

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.ChunkTracker.IsInitialized()` <sub>L142</sub>

> Verifica se o rastreador de chunks está inicializado

**Retorno:**
- `boolean` `True` — se estiver inicializado

---

### 🔒 `expurgarDuplicatasPredioObsoletas(gerenciadorEstado, mapeamentoIds, atualizacoesPendentes)` <sub>L159</sub>

> Corrige coordenadas canônicas de prédios e mescla duplicatas obsoletas do tipo bld_def_...
> Passo 1: corrige entradas bld_X_Y_Z cujas coordenadas x/y/z armazenadas diferem do ID.
> Passo 2: detecta pares obsoletos+canônicos através da chave connectedGenerators compartilhada,
>          mescla conexões de geradores, atualiza o ModData do IsoObject, remove o obsoleto.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerenciadorEstado` | `table` | Referência ao StateManager |
| `mapeamentoIds` | `table` | Tabela [id]=true atualizada in-place (obsoletos removidos, canônicos adicionados) |
| `atualizacoesPendentes` | `table` | Tabela [id]=true de prédios que precisam de atualização de interface |

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.ChunkTracker.HandleStartupGeneratorRefresh()` <sub>L311</sub>

> Escaneia os geradores do StateManager no início do jogo e enfileira ForceUpdateBuilding
> para qualquer um cujo quadrado no mapa já esteja carregado na memória.
> Chamado uma vez a partir de Initialize() para cobrir a lacuna onde LoadGridsquare dispara
> durante a tela de carregamento antes do nosso manipulador de eventos ser registrado.

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.ChunkTracker.OnLoadGridsquare(quadrado)` <sub>L1335</sub>

> Trata evento de carregamento de chunk
> OTIMIZADO: Deduplicação em nível de chunk evita processar o mesmo chunk 100 vezes redundantes

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `IsoGridSquare` | Quadrado da grade que foi carregado |

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.ChunkTracker.OnUnloadGridsquare(quadrado)` <sub>L1419</sub>

> Trata evento de descarregamento de chunk

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `IsoGridSquare` | Quadrado da grade que foi descarregado |

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.ChunkTracker.ProcessChunkGenerators(chaveChunk, coordX, coordY)` <sub>L1458</sub>

> Processa todos os geradores no chunk quando este carrega

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `chaveChunk` | `string` | Chave do chunk |
| `coordX` | `number` | Coordenada X amostral no chunk |
| `coordY` | `number` | Coordenada Y amostral no chunk |

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.ChunkTracker.IsChunkLoaded(chaveChunk)` <sub>L1871</sub>

> Verifica se um chunk está atualmente carregado

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `chaveChunk` | `string` | Chave do chunk |

**Retorno:**
- `boolean` `True` — se estiver carregado

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.ChunkTracker.GetChunkLoadTime(chaveChunk)` <sub>L1878</sub>

> Obtém o tempo de carregamento do chunk

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `chaveChunk` | `string` | Chave do chunk |

**Retorno:**
- `number|nil` `Timestamp` — do carregamento ou nil se não carregado

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.ChunkTracker.GetLoadedChunks()` <sub>L1884</sub>

> Obtém todos os chunks carregados

**Retorno:**
- `table` `Array` — contendo chaves de chunks

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.ChunkTracker.PrintStatus()` <sub>L1899</sub>

> Exibe o status do rastreador de chunks no console

---

## `server/fuel/LKS_EletricidadeConstrucao_Fuel_Manager.lua`

### 🔒 `obterNomeSpriteGerador(gerador)` <sub>L48</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `obterMinutosMundo()` <sub>L58</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `aplicarRetornosDecrescentes(multiplicador, quantidade)` <sub>L69</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `encontrarIdPoolRestauravel(gerenciadorEstado, dadosGerador)` <sub>L75</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `contarGeradoresMesmoSprite(objetoGerador, dadosGerador)` <sub>L97</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators(generatorData)` <sub>L149</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier()` <sub>L233</sub>

> Retorna o multiplicador de sandbox GeneratorFuelConsumption do vanilla,
> normalizado para que o padrão vanilla (0.1) seja mapeado para 1.0.
>   sandbox 0.0 → 0.0  (combustível infinito)
>   sandbox 0.1 → 1.0  (normal / sem alteração na taxa base da V2)
>   sandbox 0.5 → 5.0  (5x mais rápido)
>   sandbox 1.0 → 10.0 (10x mais rápido)

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.Initialize()` <sub>L250</sub>

> Inicializa o gerenciador de combustível

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.IsInitialized()` <sub>L270</sub>

> Verifica se o gerenciador de combustível está inicializado

**Retorno:**
- `boolean` `True` — se estiver inicializado

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.Update()` <sub>L280</sub>

> Atualiza todos os geradores ativos
> Chamado periodicamente para processar o consumo de combustível

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator(x, y, z)` <sub>L483</sub>

> Força cálculo imediato do combustível para um gerador específico (ex: quando o aquecimento é alternado)

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada X |
| `y` | `number` | Coordenada Y |
| `z` | `number` | Coordenada Z (opcional, padrão 0) |

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.UpdateGenerator(generatorData, deltaSeconds)` <sub>L519</sub>

> Atualiza o consumo de combustível de um único gerador.
> IsoObject é a fonte de combustível autoritativa: o valor é lido e gravado usando
> gen:getFuel()/gen:setFuel(). O fuelAmount do estado é mantido em sincronia como
> um cache para verificações de energia fora de chunk (isBuildingPoweredInline) e interface.
> Gen_LastCalcWorldAge é gravado no moddata do IsoObject para que a compensação funcione
> corretamente mesmo após uma falha de desserialização do GlobalModData.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Gerador a atualizar |
| `deltaSeconds` | `number` | Variação de tempo em segundos (pode ser grande na compensação) |

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.CalculateFuelConsumption(generatorData, deltaSeconds)` <sub>L625</sub>

> Calcula o consumo de combustível para um período de tempo

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |
| `deltaSeconds` | `number` | Variação de tempo em segundos |

**Retorno:**
- `number` `Combustível` — consumido

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.GetRemainingHours(generatorData)` <sub>L1137</sub>

> Obtém estimativa de horas de funcionamento restantes do gerador

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |

**Retorno:**
- `number` `Horas` — restantes

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.ConsumeFuel(generatorData, amount)` <sub>L1319</sub>

> Consome combustível manualmente do gerador

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |
| `amount` | `number` | Quantidade de combustível a consumir |

**Retorno:**
- `boolean` `True` — se a operação foi bem-sucedida

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.AddFuel(generatorData, amount)` <sub>L1368</sub>

> Adiciona combustível ao gerador

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |
| `amount` | `number` | Quantidade de combustível a adicionar |

**Retorno:**
- `boolean` `True` — se a operação foi bem-sucedida

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.SetCustomFuelRate(generatorData, fuelRate)` <sub>L1403</sub>

> Define uma taxa de consumo de combustível personalizada para o gerador

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |
| `fuelRate` | `number|nil` | Taxa de combustível personalizada (nil para usar padrão) |

---

### 🌐 `getGeneratorFromSquare(x, y, z)` <sub>L1429</sub>

> Obtém o objeto IsoGenerator a partir de coordenadas no mapa

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada X |
| `y` | `number` | Coordenada Y |
| `z` | `number` | Coordenada Z |

**Retorno:**
- `IsoGenerator|nil` `Objeto` — gerador

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.Manager.PrintStatus()` <sub>L1458</sub>

> Exibe o status do gerenciador de combustível no console

---

## `server/fuel/LKS_EletricidadeConstrucao_Fuel_StrainCalculator.lua`

### 🔒 `obterNomeSpriteGerador(gerador)` <sub>L36</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `aplicarRetornosDecrescentes(multiplicador, quantidade)` <sub>L46</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `contarGeradoresMesmoSprite(objetoGerador, dadosGerador)` <sub>L53</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `contarGeradoresPoolAtivosDosPredios(prediosPool)` <sub>L104</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `resolverQuantidadePoolAtivo(dadosGerador, prediosPoolSobrescrito, ativosPoolSobrescrito)` <sub>L143</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData, poolBuildingsOverride, activePoolOverride)` <sub>L173</sub>

> Calcula o multiplicador de sobrecarga para o gerador (sistema em níveis)

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |
| `poolBuildingsOverride` | `table|nil` | Lista pré-calculada de IDs de prédios vindos do BFS do FuelManager. |
| `activePoolOverride` | `number|nil` | Contagem pré-calculada de geradores ativos do pool. |

**Retorno:**
- `number` `Multiplicador` — de sobrecarga (1.0 = normal, >1.0 = consumo aumentado)

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.CalculateStrain(generatorData, poolBuildingsOverride, activePoolOverride)` <sub>L228</sub>

> Calcula a sobrecarga atual do gerador

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |
| `poolBuildingsOverride` | `table|nil` | Lista pré-calculada de prédios do pool. |
| `activePoolOverride` | `number|nil` | Contagem pré-calculada de geradores ativos para este pool. |

**Retorno:**
- `number` `Porcentagem` — de sobrecarga (0-100+)

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PowerDrawToStrain(powerDraw)` <sub>L338</sub>

> Converte carga elétrica para porcentagem de sobrecarga

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `powerDraw` | `number` | Carga elétrica total |

**Retorno:**
- `number` `Porcentagem` — de sobrecarga

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainLevel(strain)` <sub>L364</sub>

> Obtém a categoria do nível de sobrecarga

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `strain` | `number` | Porcentagem de sobrecarga |

**Retorno:**
- `string` `Nível` — de sobrecarga ("none", "low", "medium", "high", "critical")

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.IsOverloaded(generatorData)` <sub>L383</sub>

> Verifica se o gerador está em sobrecarga

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |

**Retorno:**
- `boolean` `True` — se estiver em sobrecarga

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetEfficiency(strain)` <sub>L401</sub>

> Obtém a porcentagem de eficiência com base na sobrecarga

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `strain` | `number` | Porcentagem de sobrecarga |

**Retorno:**
- `number` `Porcentagem` — de eficiência (100 = normal, <100 = eficiência reduzida)

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ShouldFailFromOverload(generatorData)` <sub>L425</sub>

> Verifica se o gerador deve falhar devido à sobrecarga

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |

**Retorno:**
- `boolean` `True` — se deve falhar
- `string|nil` `Motivo` — da falha

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetTotalPowerDraw(generatorData)` <sub>L466</sub>

> Calcula a carga elétrica total para o gerador

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |

**Retorno:**
- `number` `Carga` — elétrica total
- `number` `Quantidade` — de consumidores ativos

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetPowerBreakdown(generatorData)` <sub>L492</sub>

> Obtém o detalhamento do consumo de energia por prédio conectado

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |

**Retorno:**
- `table` `Array` — contendo tabelas {buildingId, powerDraw, consumers}

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetOptimizationSuggestions(generatorData)` <sub>L529</sub>

> Obtém sugestões de otimização para o gerador

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |

**Retorno:**
- `table` `Array` — contendo strings com sugestões

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PrintGeneratorStrain(generatorData)` <sub>L567</sub>

> Exibe informações da sobrecarga do gerador no console

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |

---

### 🌐 `LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage(generatorData, deltaSeconds)` <sub>L620</sub>

> Aplica danos de sobrecarga ao gerador
> Chamado a cada tick de consumo de combustível

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `generatorData` | `GeneratorData` | Dados do gerador |
| `deltaSeconds` | `number` | Variação de tempo desde o último cálculo |

**Retorno:**
- `boolean` `True` — se o gerador falhou catastroficamente (foi desligado)

---

## `server/heating/LKS_EletricidadeConstrucao_Heating_Manager.lua`

### 🔒 `obterPosicoesDaSala(sala, zPiso)` <sub>L38</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `encontrarPredioIso(dadosPredio)` <sub>L85</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `obterPosicoesDosBlocosConsumidor(dadosPredio)` <sub>L111</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Heating.CalculatePositions(buildingData)` <sub>L206</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Heating.SyncToGenerators(buildingData)` <sub>L267</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Heating.Update()` <sub>L378</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Heating.Initialize()` <sub>L404</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `server/power/LKS_EletricidadeConstrucao_Power_Distributor.lua`

### 🔒 `copiarCaixaDelimitadora(origem)` <sub>L30</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `sincronizarEstadoEnergiaPredio(dadosPredio, estaEnergizado)` <sub>L40</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `encontrarGeradorEm(x, y, z)` <sub>L68</sub>

> Auxiliar inline: encontra um IsoGenerator nas coordenadas do mundo (x, y, z)

---

### 🔒 `tabelaContemValor(tabela, valor)` <sub>L81</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `tabelaEstaVazia(tabela)` <sub>L91</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `geradorPertenceAoPredio(idPredio, gerador, dadosGerador)` <sub>L97</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `substituirEstadoGerador(dadosGerador)` <sub>L114</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `removerLinksGeradoresObsoletos(dadosPredio)` <sub>L124</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `predioTemEnergiaInline(dadosPredio)` <sub>L222</sub>

> Auxiliar inline: retorna true se o prédio tem pelo menos um gerador ativado.
> Utiliza dadosPredio.connectedGenerators (lista de chaves "x_y_z" configurada pela ação de conexão).

---

### 🔒 `aplicarEnergiaLadrilhos(dadosPredio, estaEnergizado)` <sub>L284</sub>

> Aplica ou remove energia de gerador de cada ladrilho (tile) na caixa delimitadora do prédio.
> Espelha a abordagem de PowerSquare / chunk:addGeneratorPos do V1: é o que o PZ usa
> internamente para marcar os quadrados como eletricamente ativos, alimentando luzes e aparelhos.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` |  |
| `estaEnergizado` | `boolean` |  |

---

### 🌐 `Distribuidor.Initialize()` <sub>L379</sub>

> Inicializa o Distribuidor de Energia

---

### 🔒 `contarGeradoresAtivosDiretos(dadosPredio)` <sub>L394</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `obterEstatisticasExibicaoGerador(dadosPredio, chaveGerador, consumoCargaFiltro, contagemAtivosFallback)` <sub>L419</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `construirInstantaneoEstatisticasBarris(dadosPredio)` <sub>L464</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `sincronizarEstatisticasPredioAoGerador(dadosPredio)` <sub>L520</sub>

> Escreve as estatísticas do prédio no ModData do gerador conectado para que o cliente
> possa exibi-las na Janela de Informações sem precisar de acesso ao estado do servidor.
> Chamado a cada ciclo de atualização da distribuição (~10 s).

---

### 🔒 `radioEstaLigado(objeto)` <sub>L660</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `obterEstadoAtivoEletrodomestico(quadrado, estaEnergizado)` <sub>L676</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Distribuidor.UpdateBuildingPower(dadosPredio, atualizarConsumidores)` <sub>L729</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Distribuidor.UpdateAllBuildings(atualizarConsumidores)` <sub>L863</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Distribuidor.Update(tempoAtual)` <sub>L909</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Distribuidor.ForceUpdate()` <sub>L944</sub>

> Força atualização imediata de energia para todos os prédios

---

### 🔒 `_atualizarEstatisticasPredio(dadosPredio, forcarAtualizacaoLadrilho)` <sub>L969</sub>

> Auxiliar interno: tenta uma atualização completa de energia para um único prédio por dados.
> NÃO enfileira uma nova tentativa em caso de falha — os chamadores decidem isso.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` |  |
| `forcarAtualizacaoLadrilho` | `boolean` |  |

**Retorno:**
- `boolean` `true` — se o prédio foi encontrado e atualizado

---

### 🔒 `_tentarAtualizarPredio(idPredio, forcarAtualizacaoLadrilho)` <sub>L984</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Distribuidor.RefreshBuildingStats(idPredio)` <sub>L995</sub>

> Atualiza consumidores ativos e Gen_Stats_* para um prédio sem forcar
> a reaplicação de energia aos ladrilhos. Use para consultas de interface e atualizações de barris/status.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `idPredio` | `string` | ID do Prédio |

**Retorno:**
- `boolean` `true` — se o prédio foi encontrado e atualizado

---

### 🌐 `Distribuidor.ForceUpdateBuilding(idPredio)` <sub>L1009</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Distribuidor.ProcessRetryQueue()` <sub>L1036</sub>

> Tenta novamente chamadas pendentes de ForceUpdateBuilding cujo prédio ainda não estava no estado.
> Chamado a partir do EveryOneMinute (LKS_EletricidadeConstrucao_ServerInit). Cada entrada recebe até 3 tentativas
> em 3 ticks de minutos consecutivos antes de ser permanentemente abandonada.

---

### 🌐 `Distribuidor.GetCachedPowerState(idPredio)` <sub>L1080</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Distribuidor.ClearCache()` <sub>L1085</sub>

> Limpa o cache do estado de energia

---

### 🌐 `Distribuidor.PrintStatus()` <sub>L1095</sub>

> Imprime o status da distribuição de energia (debug)

---

## `server/power/LKS_EletricidadeConstrucao_Power_Manager.lua`

### 🌐 `Gerenciador.Initialize()` <sub>L51</sub>

> Inicializa o Gerenciador de Energia

---

### 🌐 `Gerenciador.GetAllGenerators()` <sub>L69</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.FindNearbyGenerators(dadosPredio, raio)` <sub>L102</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.CreateConnectionId(geradorX, geradorY, geradorZ, idPredio)` <sub>L181</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `geradorPertenceAoPredio(gerador, dadosPredio)` <sub>L185</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.ConnectGeneratorToBuilding(generator, buildingData, distance)` <sub>L222</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.DisconnectGeneratorFromBuilding(idConexao)` <sub>L326</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.GetGeneratorAt(x, y, z)` <sub>L409</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.ValidateConnection(dadosConexao)` <sub>L429</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.CleanInvalidConnections()` <sub>L525</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.UpdateConnections()` <sub>L552</sub>

> Atualiza todas as conexões (procura novos geradores, valida existentes)

---

### 🌐 `Gerenciador.Update(tempoAtual)` <sub>L605</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.GetAllConnections()` <sub>L620</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.GetBuildingConnections(idPredio)` <sub>L627</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.IsBuildingPowered(idPredio)` <sub>L646</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.GetConnectionCount()` <sub>L665</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `Gerenciador.PrintConnections()` <sub>L678</sub>

> Imprime todas as conexões ativas no log (debug)

---

### 🌐 `Gerenciador.ManualScan()` <sub>L700</sub>

> Varredura manual de conexões (função de depuração/comando admin)

---

## `shared/0_LKS_EletricidadeConstrucao_Init.lua`

### 🔒 `ShouldSuppressLKS_EletricidadeConstrucaoPrint(message)` <sub>L133</sub>

> Verifica se uma mensagem específica de console deve ser suprimida do print nativo.
> Serve para reduzir a poluição visual do console gerada por logs redundantes,
> permitindo apenas mensagens críticas de erro/alerta, ou todas as mensagens caso o DebugMode esteja ativo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `message` | `any` | A mensagem a ser avaliada. |

**Retorno:**
- `boolean` `Retorna` — true se a mensagem deve ser silenciada no console.

---

## `shared/LKS_Cooking_PropanoSystem.lua`

### 🔒 `carregarConfiguracaoSandbox()` <sub>L34</sub>

> Carrega configuração de propano do sandbox options.

**Retorno:**
- `table` `Configuração` — atualizada com valores do sandbox.

---

### 🔒 `obterDiaMundoAtual()` <sub>L50</sub>

> Obtém o dia atual do mundo em jogo.

**Retorno:**
- `number` `O` — dia atual do mundo (começando em 0).

---

### 🔒 `obterDiaCorteAgua()` <sub>L59</sub>

> Obtém o dia de corte da água encanada (utilidade vanilla).

**Retorno:**
- `number` `O` — dia em que a água é cortada (-1 se infinito).

---

### 🔒 `propanoEncanadoDisponivel()` <sub>L78</sub>

> Verifica se o propano encanado está disponível no momento atual do jogo.
> A lógica segue o mesmo princípio da água encanada:
> - Antes do dia de corte: propano disponível (ilimitado)
> - Após o dia de corte: propano cortado (requer botijão)
> - Se diaCortePropano == -1: usa o mesmo dia da água
> - Se diaCortePropano == 0: propano infinito (nunca corta)

**Retorno:**
- `boolean` `True` — se o propano encanado está disponível.

---

### 🔒 `verificarFonteCalorInventario(jogador)` <sub>L122</sub>

> Verifica se o jogador possui uma fonte de calor no inventário para acender
> o fogão manualmente (quando não há acendedor elétrico/eletricidade).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogador` | `IsoPlayer` | O jogador a verificar. |

**Retorno:**
- `boolean` `temFonte` — True se possui fonte de calor.
- `string|nil` `nomeFonte` — Nome do primeiro item encontrado, ou nil.

---

### 🔒 `verificarFonteEnergia(objetoFogao, jogador, tipoFogao)` <sub>L164</sub>

> Verifica todas as fontes de energia possíveis para um fogão.
> Para fogão convencional, verifica na ordem:
> 1. Propano encanado (pré-corte) + eletricidade (acendedor automático)
> 2. Propano encanado (pré-corte) + fonte de calor manual
> 3. Botijão conectado + eletricidade (acendedor automático)
> 4. Botijão conectado + fonte de calor manual
> Para indução, verifica apenas eletricidade (isPowered).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetoFogao` | `IsoObject` | O objeto fogão no mundo. |
| `jogador` | `IsoPlayer` | O jogador interagindo. |
| `tipoFogao` | `string` | O tipo do fogão ("convencional", "inducao", "antigo"). |

**Retorno:**
- `LKS_FonteEnergiaResultado` `O` — resultado da verificação.

---

## `shared/LKS_Cooking_Quality.lua`

### 🔒 `calcularChanceQueimar(nivelCooking)` <sub>L45</sub>

> Calcula a chance de queimar comida no fogão antigo (lenha).
> Base de 10%, reduz 1% por nível de Cooking. Zero em Cooking 10.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nivelCooking` | `number` | O nível de Cooking do jogador (0-10). |

**Retorno:**
- `number` `A` — chance percentual de queimar (0-10).

---

### 🔒 `verificarSeQueimou(nivelCooking)` <sub>L54</sub>

> Verifica se a comida queimou com base na chance calculada.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nivelCooking` | `number` | O nível de Cooking do jogador. |

**Retorno:**
- `boolean` `queimou` — True se a comida queimou.

---

### 🔒 `calcularQualidade(tipoFogao, nivelCooking, statusLimpeza)` <sub>L71</sub>

> Calcula a qualidade final da comida baseada em múltiplos fatores.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tipoFogao` | `string` | O tipo do fogão ("convencional", "antigo", "inducao"). |
| `nivelCooking` | `number` | O nível de Cooking do jogador. |
| `statusLimpeza` | `table|nil` | O status de limpeza do fogão (da tabela STATUS_LIMPEZA). |

**Retorno:**
- `table` `O` — nível de qualidade resultante (da tabela NIVEIS_QUALIDADE).
- `boolean` `queimou` — Se a comida queimou no processo.

---

### 🔒 `obterStatusLimpeza(fogao)` <sub>L116</sub>

> Obtém o status de limpeza atual de um fogão via moddata.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `fogao` | `IsoObject` | O fogão a verificar. |

**Retorno:**
- `table` `O` — status de limpeza atual.

---

### 🔒 `degradarLimpeza(fogao)` <sub>L134</sub>

> Degrada o status de limpeza do fogão após um cozimento.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `fogao` | `IsoObject` | O fogão a degradar. |

---

### 🔒 `limparFogao(fogao, limpezaCompleta)` <sub>L149</sub>

> Limpa o fogão restaurando o status de limpeza.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `fogao` | `IsoObject` | O fogão a limpar. |
| `limpezaCompleta` | `boolean` | Se true (tem produto de limpeza), restaura para Brilhando. |

---

## `shared/LKS_Cooking_SpriteClassification.lua`

### 🔒 `obterTipoFogaoPorSprite(nomeSprite)` <sub>L66</sub>

> Retorna o tipo do fogão baseado no nome do sprite do objeto.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeSprite` | `string` | O nome completo do sprite (ex: "appliances_cooking_01_0"). |

**Retorno:**
- `string` `O` — tipo do fogão: "convencional" ou "inducao".

---

### 🔒 `obterTipoFogao(objetoFogao)` <sub>L80</sub>

> Retorna o tipo do fogão baseado no objeto IsoStove do mundo.
> Extrai o nome do sprite do objeto e consulta a tabela de classificação.
> Para IsoFireplace, retorna "antigo" diretamente (não depende de sprite).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetoFogao` | `IsoObject` | O objeto do fogão no mundo. |

**Retorno:**
- `string` `O` — tipo do fogão: "convencional", "inducao" ou "antigo".

---

## `shared/LKS_EletricidadeConstrucao_Config.lua`

### 🔒 `ApplySandboxBackedConstants()` <sub>L132</sub>

> Atualiza as constantes base da física de simulação baseando-se nos valores do Sandbox.

---

### 🌐 `LKS_EletricidadeConstrucao.Config.LoadFromSandbox()` <sub>L158</sub>

> Carrega as configurações de jogo a partir das SandboxVars definidas no mundo/servidor.
> Chamado no bootstrap do mod para sobrescrever os valores estáticos locais.

---

### 🌐 `LKS_EletricidadeConstrucao.Config.SaveToModData(key)` <sub>L223</sub>

> Salva as configurações locais no ModData global do mundo (Apenas no Servidor/Host).
> Sincroniza a tabela de preferências enviando pacotes ModData.transmit() para os clientes.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `key` | `string` | Opcional: A chave de configuração individual (salva apenas o valor correspondente). |

---

### 🌐 `LKS_EletricidadeConstrucao.Config.LoadFromModData()` <sub>L241</sub>

> Reconstrói e mescla as preferências locais a partir do ModData compartilhado (Clientes e Saves carregados).

---

### 🌐 `LKS_EletricidadeConstrucao.Config.ResetToDefaults()` <sub>L255</sub>

> Reseta todas as chaves de configuração locais para as definições de código estático (Defaults).

---

### 🌐 `LKS_EletricidadeConstrucao.Config.Validate()` <sub>L262</sub>

> Executa uma validação preventiva de limites físicos nas chaves numéricas da tabela de preferências.
> Clampa valores bizarros ou perigosos configurados fora da faixa suportada para evitar estouros ou crashes.

---

## `shared/LKS_EletricidadeConstrucao_Shared_ConsumerEvents.lua`

### 🔒 `EhConsumidorRastreado(objeto)` <sub>L27</sub>

> Verifica se um objeto nativo é um consumidor de energia que o mod deve rastrear.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objeto` | `any` | O objeto de mapa nativo (IsoObject). |

**Retorno:**
- `boolean` `Retorna` — true se for um aparelho rastreado.

---

### 🔒 `PossuiModulosServidor()` <sub>L48</sub>

> Verifica se todos os módulos necessários de servidor estão carregados.

**Retorno:**
- `boolean` `Retorna` — true se os submódulos de scanner e estado do core estiverem prontos.

---

### 🔒 `EscanearTodasConstrucoes()` <sub>L61</sub>

> Varre e atualiza novamente todos os aparelhos de todas as construções cadastradas.
> Recalcula o consumo elétrico e força o distribuidor a recalcular a carga da rede de cada prédio.

---

### 🔒 `EhAmbienteAutoritativo()` <sub>L87</sub>

> Verifica se o ambiente de execução atual é o host autoritativo (Servidor ou SP).

**Retorno:**
- `boolean` `Retorna` — true se for servidor dedicado ou singleplayer local.

---

### 🔒 `TabelaEstaVazia(tabela)` <sub>L102</sub>

> Verifica se uma tabela informada está vazia ou nula.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table|nil` | A tabela a testar. |

**Retorno:**
- `boolean` `Retorna` — true se estiver vazia ou for nil.

---

### 🔒 `LimparEstadoGeradorRemovido(gerador)` <sub>L110</sub>

> Remove os links de salvamento e referências de estado de um gerador removido física ou logicamente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerador` | `any` | O objeto de gerador removido (IsoGenerator). |

---

### 🔒 `AoAdicionarObjeto(objeto)` <sub>L198</sub>

> Dispara quando qualquer objeto físico é adicionado ou construído no mapa.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objeto` | `any` | O objeto adicionado. |

---

### 🔒 `TratarGeradorPrestesASerRemovido(gerador)` <sub>L208</sub>

> Gerencia a transferência de propriedade da piscina elétrica quando o gerador líder
> é recolhido pelo jogador ou destruído.
> Garante que a malha elétrica da construção permaneça operando se houver geradores secundários.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerador` | `any` | O gerador prestes a ser removido (IsoGenerator). |

---

### 🔒 `AoRemoverObjeto(objeto)` <sub>L276</sub>

> Disparado imediatamente ANTES de um objeto nativo ser excluído ou recolhido.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objeto` | `any` | O objeto a ser removido. |

---

### 🔒 `AtualizarEstadosAtivos()` <sub>L302</sub>

> Atualiza as flags de atividade (isActive) de todos os aparelhos sem refazer o scanner de paredes.

---

### 🔒 `AoProcessarTick()` <sub>L318</sub>

> Escuta de ticks gerais do PZ para rodar a atualização cronometrada de aparelhos.

---

## `shared/actions/LKS_EletricidadeConstrucao_Actions_ActivateGenerator.lua`

### 🌐 `LKS_EletricidadeConstrucao_ActivateGenerator:isValid()` <sub>L43</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ActivateGenerator:waitToStart()` <sub>L60</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ActivateGenerator:update()` <sub>L65</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ActivateGenerator:start()` <sub>L74</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ActivateGenerator:stop()` <sub>L80</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ActivateGenerator:perform()` <sub>L84</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `CopiarCaixaDelimitadora(origem)` <sub>L95</sub>

> Cria uma cópia profunda de uma tabela contendo as coordenadas da caixa delimitadora (BoundingBox).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `origem` | `table` | A tabela contendo os limites geométricos. |

**Retorno:**
- `table|nil` `Retorna` — a cópia estruturada ou nil se inválida.

---

### 🔒 `TabelaContemValor(tabela, valor)` <sub>L121</sub>

> Verifica se uma tabela genérica contém um determinado valor.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a pesquisar. |
| `valor` | `any` | O valor a localizar. |

**Retorno:**
- `boolean` `Retorna` — true se o valor estiver presente na tabela.

---

### 🔒 `ResolverDadosPoolConstrucao(identificadorPoolConstrucao, gerador)` <sub>L137</sub>

> Tenta recuperar os metadados elétricos (PoolData) vinculados a uma construção a partir dos geradores ativos do mundo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificadorPoolConstrucao` | `string` | O ID da piscina de construção. |
| `gerador` | `any` | O objeto do gerador ativo. |

**Retorno:**
- `table|nil` `O` — arquivo de estado recuperado ou nil.

---

### 🔒 `RestaurarConstrucaoDosDadosPool(identificadorPoolConstrucao, gerenciadorEstado, dadosPool, xAncora, yAncora, zAncora, motivo)` <sub>L187</sub>

> Recria uma construção no gerenciador a partir de metadados recuperados (PoolData).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificadorPoolConstrucao` | `string` | O ID da construção. |
| `gerenciadorEstado` | `table` | O gerenciador de estado. |
| `dadosPool` | `table` | Os metadados de simulação recuperados. |
| `xAncora` | `number` | Coordenada X âncora padrão. |
| `yAncora` | `number` | Coordenada Y âncora padrão. |
| `zAncora` | `number` | Coordenada Z âncora padrão. |
| `motivo` | `string` | Descritivo textual do motivo da reestruturação. |

**Retorno:**
- `table|nil` `O` — estado de dados da construção recriada.

---

### 🔒 `GarantirGeradorVinculado(dadosConstrucao, gerador, gerenciadorEstado)` <sub>L243</sub>

> Garante o vínculo físico e lógico entre um gerador ativo e a malha de uma construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados de representação do prédio. |
| `gerador` | `any` | O gerador físico. |
| `gerenciadorEstado` | `table` | O gerenciador de estado. |

**Retorno:**
- `table` `Os` — dados atualizados da construção.

---

### 🔒 `GarantirEstadoConstrucao(identificadorPoolConstrucao, gerador, motivo)` <sub>L279</sub>

> Recupera ou reconstrói o estado lógico de um edifício garantindo sua integridade estrutural.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificadorPoolConstrucao` | `string` | O ID da piscina de construção. |
| `gerador` | `any` | O objeto do gerador ativo. |
| `motivo` | `string` | Descritivo técnico do motivo da verificação. |

**Retorno:**
- `table|nil` `O` — estado da construção estruturada.

---

### 🔒 `AtualizarEnergiaConstrucao(identificadorPoolConstrucao, gerador, motivo)` <sub>L404</sub>

> Força a atualização do fornecimento elétrico de uma construção após ligar/desligar um gerador da piscina.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificadorPoolConstrucao` | `string` | O ID da piscina de construção. |
| `gerador` | `any` | O objeto do gerador. |
| `motivo` | `string` | Descritivo do motivo do disparo. |

**Retorno:**
- `table|nil` `A` — construção atualizada.

---

### 🔒 `ExecutarAtivacaoGerador(gerador, ativar)` <sub>L427</sub>

> Efetua fisicamente a ativação ou desativação lógica do gerador no mapa do Project Zomboid.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `gerador` | `any` | O objeto gerador (IsoGenerator). |
| `ativar` | `boolean` | True para ligar, false para desligar. |

**Retorno:**
- `boolean` `Retorna` — true se a operação ocorreu com sucesso.

---

### 🌐 `LKS_EletricidadeConstrucao_ActivateGenerator:complete()` <sub>L586</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ActivateGenerator:getDuration()` <sub>L610</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ActivateGenerator:new(character, generator, activate)` <sub>L618</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `shared/actions/LKS_EletricidadeConstrucao_Actions_ConnectBuilding.lua`

### 🔒 `DeveDizerAoPersonagem(ambienteExecucao)` <sub>L41</sub>

> Auxiliar interno para determinar se o personagem deve "falar" no console ou chat gráfico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `ambienteExecucao` | `table` | O contexto técnico do mod. |

**Retorno:**
- `boolean` `Retorna` — true se a mensagem por voz gráfica deve ser exibida.

---

### 🌐 `LKS_EletricidadeConstrucao_ConnectBuilding:isValid()` <sub>L51</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ConnectBuilding:waitToStart()` <sub>L66</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ConnectBuilding:update()` <sub>L71</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ConnectBuilding:start()` <sub>L80</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ConnectBuilding:stop()` <sub>L86</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ConnectBuilding:perform()` <sub>L90</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `LocalizarQuadradoConstrucao(quadradoGerador)` <sub>L101</sub>

> Procura por um quadrado com definição de construção (edifício) adjacente ao gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadradoGerador` | `any` | O quadrado no qual o gerador está posicionado. |

**Retorno:**
- `any|nil` `Retorna` — o quadrado da construção adjacente ou nil.

---

### 🔒 `LocalizarInterruptorLuzConstrucao(construcao, andarZ)` <sub>L127</sub>

> Procura nas salas de uma construção por um interruptor de luz (IsoLightSwitch).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `construcao` | `any` | O objeto de construção da engine. |
| `andarZ` | `number` | O nível de andar Z correspondente. |

**Retorno:**
- `integer|nil,` `integer` — |nil, integer|nil As coordenadas X, Y, Z do primeiro interruptor localizado.

---

### 🔒 `ContarElementos(tabela)` <sub>L171</sub>

> Conta a quantidade de elementos presentes em uma tabela genérica.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table|nil` | A tabela a avaliar. |

**Retorno:**
- `integer` `A` — quantidade de itens na tabela.

---

### 🔒 `EstaDentroDaCaixaDelimitadora(dadosConstrucao, coordenadaX, coordenadaY)` <sub>L185</sub>

> Verifica se coordenadas específicas estão dentro dos limites da caixa delimitadora do prédio.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados de representação do prédio. |
| `coordenadaX` | `number` | Coordenada X física. |
| `coordenadaY` | `number` | Coordenada Y física. |

**Retorno:**
- `boolean` `Retorna` — true se estiver posicionado dentro dos limites do prédio.

---

### 🔒 `ObterConstrucaoIsoDaAncora(dadosConstrucao)` <sub>L204</sub>

> Retorna o objeto de construção Java da engine a partir de suas coordenadas âncora.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados de representação do prédio. |

**Retorno:**
- `any` `O` — objeto de construção nativo da engine.

---

### 🔒 `LocalizarConstrucaoExistenteCorrespondente(construcao, quadradoConstrucao, identificadorConstrucaoCandidata)` <sub>L228</sub>

> Tenta localizar uma construção no estado correspondente a mesma pegada física.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `construcao` | `any` | O objeto de construção da engine. |
| `quadradoConstrucao` | `any` | O quadrado de mapa que contém as coordenadas da construção. |
| `identificadorConstrucaoCandidata` | `string` | O ID candidato para registro. |

**Retorno:**
- `string|nil,` `table` — |nil O ID e dados da construção correspondente existente.

---

### 🌐 `LKS_EletricidadeConstrucao_ConnectBuilding:complete()` <sub>L277</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ConnectBuilding:getDuration()` <sub>L560</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_ConnectBuilding:new(character, generator)` <sub>L568</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `shared/actions/LKS_EletricidadeConstrucao_Actions_DisconnectBuilding.lua`

### 🔒 `DeveDizerAoPersonagem(ambienteExecucao)` <sub>L40</sub>

> Auxiliar interno para determinar se o personagem deve "falar" graficamente na tela.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `ambienteExecucao` | `table` | O contexto de execução atual. |

**Retorno:**
- `boolean` `Retorna` — true se a mensagem deve ser dita graficamente.

---

### 🔒 `TentarEncararGerador(personagem, gerador)` <sub>L50</sub>

> Tenta orientar visualmente o personagem em direção ao gerador antes de operar.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `personagem` | `any` | O personagem do jogador (IsoPlayer). |
| `gerador` | `any` | O objeto do gerador (IsoGenerator). |

**Retorno:**
- `boolean` `Retorna` — true se a operação de pcall ocorreu sem quebras.

---

### 🌐 `LKS_EletricidadeConstrucao_DisconnectBuilding:isValid()` <sub>L61</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_DisconnectBuilding:waitToStart()` <sub>L76</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_DisconnectBuilding:update()` <sub>L83</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_DisconnectBuilding:start()` <sub>L92</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_DisconnectBuilding:stop()` <sub>L98</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_DisconnectBuilding:perform()` <sub>L102</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_DisconnectBuilding:complete()` <sub>L110</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_DisconnectBuilding:getDuration()` <sub>L327</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_DisconnectBuilding:new(character, generator)` <sub>L335</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `shared/actions/LKS_EletricidadeConstrucao_Actions_LinkBarrel.lua`

### 🌐 `LKS_EletricidadeConstrucao_LinkBarrelAction:new(jogador, barril, quadrado, identificadorConstrucao, estaVinculando)` <sub>L31</sub>

> Cria uma nova instância da ação temporizada para o jogador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `jogador` | `IsoPlayer` | O personagem do jogador que executará a ação física. |
| `barril` | `IsoObject` | O objeto do barril de combustível no mundo. |
| `quadrado` | `IsoGridSquare` | O quadrado do mapa onde o barril está localizado. |
| `identificadorConstrucao` | `string` | O ID único da construção à qual o barril será vinculado. |
| `estaVinculando` | `boolean` | `true` para vincular ao reservatório, `false` para desvincular. |

**Retorno:**
- `LKS_EletricidadeConstrucao_LinkBarrelAction` `A` — instância configurada da ação temporizada.

---

### 🌐 `LKS_EletricidadeConstrucao_LinkBarrelAction:isValid()` <sub>L48</sub>

> Verifica se as condições para continuar a ação são válidas a cada tick.

**Retorno:**
- `boolean` `Retorna` — true se o quadrado e o barril existem no mundo e estão acessíveis.

---

### 🌐 `LKS_EletricidadeConstrucao_LinkBarrelAction:waitToStart()` <sub>L55</sub>

> Gerencia o alinhamento do personagem antes do início da barra de progresso.

**Retorno:**
- `boolean` `Retorna` — true se o personagem ainda está rotacionando para encarar o alvo.

---

### 🌐 `LKS_EletricidadeConstrucao_LinkBarrelAction:update()` <sub>L61</sub>

> Atualização lógica a cada tick de progresso da ação.

---

### 🌐 `LKS_EletricidadeConstrucao_LinkBarrelAction:start()` <sub>L66</sub>

> Inicializa a ação temporizada e ativa as animações do personagem.

---

### 🌐 `LKS_EletricidadeConstrucao_LinkBarrelAction:stop()` <sub>L73</sub>

> Trata a interrupção prematura da ação.

---

### 🌐 `LKS_EletricidadeConstrucao_LinkBarrelAction:perform()` <sub>L78</sub>

> Executa as operações finais após o preenchimento da barra.

---

### 🌐 `LKS_EletricidadeConstrucao_LinkBarrelAction:complete()` <sub>L84</sub>

> Finaliza o ciclo da ação e aplica a lógica de negócio de rede de combustível.

**Retorno:**
- `boolean` `Retorna` — sempre true para indicar finalização lógica.

---

## `shared/actions/LKS_EletricidadeConstrucao_Actions_OpenInfoWindow.lua`

### 🌐 `LKS_EletricidadeConstrucao_OpenInfoWindow:isValid()` <sub>L41</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_OpenInfoWindow:waitToStart()` <sub>L52</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_OpenInfoWindow:update()` <sub>L60</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_OpenInfoWindow:start()` <sub>L71</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_OpenInfoWindow:stop()` <sub>L77</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_OpenInfoWindow:perform()` <sub>L81</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🔒 `NormalizarDicaConstrucao(dicaConstrucao)` <sub>L92</sub>

> Normaliza a dica da construção (tabela ou string) retornando apenas o seu ID.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dicaConstrucao` | `table|string` | A dica da construção. |

**Retorno:**
- `string|nil` `O` — ID normalizado ou nil.

---

### 🔒 `EnviarAberturaJanelaAoCliente(objetoJogador, gerador, quadradoAncora, dicaConstrucao)` <sub>L108</sub>

> Envia a mensagem de abertura da interface para o cliente multiplayer solicitado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetoJogador` | `any` | O jogador solicitante. |
| `gerador` | `any` | O gerador físico de referência. |
| `quadradoAncora` | `any` | O quadrado de âncora de mapa. |
| `dicaConstrucao` | `table|string` | Dica da construção associada. |

**Retorno:**
- `boolean` `Retorna` — true se a mensagem do servidor foi enviada.

---

### 🌐 `LKS_EletricidadeConstrucao_OpenInfoWindow:complete()` <sub>L142</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_OpenInfoWindow:getDuration()` <sub>L174</sub>

⚠️ *Função sem documentação EmmyLua*

---

### 🌐 `LKS_EletricidadeConstrucao_OpenInfoWindow:new(character, generator, anchorSquare, buildingHint)` <sub>L182</sub>

⚠️ *Função sem documentação EmmyLua*

---

## `shared/core/LKS_EletricidadeConstrucao_Core_EventManager.lua`

### 🔒 `InicializarEstatisticasEvento(nomeEvento)` <sub>L37</sub>

> Inicializa a estrutura de estatísticas de disparos para um determinado evento.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeEvento` | `string` | O nome identificador do evento. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.RegisterHandler(nomeEvento, manipulador, prioridade)` <sub>L55</sub>

> Registra um manipulador/ouvinte de evento personalizado com prioridade.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeEvento` | `string` | O nome do evento a ser escutado. |
| `manipulador` | `function` | A função callback executada quando o evento é disparado. |
| `prioridade` | `number|nil` | Prioridade de execução (valores maiores rodam antes, padrão: 0). |

**Retorno:**
- `boolean` `Retorna` — true se o registro foi realizado com sucesso.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.UnregisterHandler(nomeEvento, manipulador)` <sub>L99</sub>

> Remove o registro de um manipulador de evento previamente escutado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeEvento` | `string` | O nome do evento associado. |
| `manipulador` | `function` | A função callback a ser desvinculada. |

**Retorno:**
- `boolean` `Retorna` — true se o manipulador foi localizado e removido.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.ClearHandlers(nomeEvento)` <sub>L122</sub>

> Limpa permanentemente todos os manipuladores vinculados a um evento.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeEvento` | `string` | O nome do evento a limpar. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(nomeEvento, ...)` <sub>L140</sub>

> Dispara um evento personalizado executando todos os manipuladores escutas em ordem de prioridade.
> @param ... any Argumentos variáveis repassados às funções callbacks ouvintes.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeEvento` | `string` | O nome do evento disparado. |

**Retorno:**
- `integer` `A` — quantidade de manipuladores executados com sucesso (sem travar por erro).

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.RegisterGameEvent(nomeEvento, manipulador)` <sub>L175</sub>

> Vincula uma função callback a um evento nativo/vanilla do Project Zomboid (API nativa Events.X.Add).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeEvento` | `string` | O nome do evento nativo do jogo (ex: OnTick, OnGameStart, OnContainerUpdate). |
| `manipulador` | `function` | A função executada pelo evento nativo. |

**Retorno:**
- `boolean` `Retorna` — true se o vínculo com a engine foi realizado com sucesso.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.UnregisterGameEvent(nomeEvento, manipulador)` <sub>L191</sub>

> Remove o vínculo de uma função callback em relação a um evento nativo do Project Zomboid.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeEvento` | `string` | O nome do evento nativo. |
| `manipulador` | `function` | O callback ou ouvinte a desvincular. |

**Retorno:**
- `boolean` `Retorna` — true se o desvínculo foi concluído.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.InitializeCustomEvents()` <sub>L208</sub>

> Inicializa e valida as definições dos eventos personalizados configurados nas Constantes do mod.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorConnected(dadosGerador, dadosConstrucao)` <sub>L235</sub>

> Dispara evento após a conexão física de um gerador a uma construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados do gerador. |
| `dadosConstrucao` | `table` | Os dados da construção conectada. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorDisconnected(dadosGerador, dadosConstrucao)` <sub>L243</sub>

> Dispara evento após a desconexão física de um gerador em relação a uma construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados do gerador. |
| `dadosConstrucao` | `table` | Os dados da construção desconectada. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorActivated(dadosGerador)` <sub>L250</sub>

> Dispara evento de ativação física de gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados do gerador ligado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorDeactivated(dadosGerador)` <sub>L257</sub>

> Dispara evento de desativação física de gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados do gerador desligado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorFuelEmpty(dadosGerador)` <sub>L264</sub>

> Dispara evento indicando que o combustível do gerador acabou completamente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados do gerador afetado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnBuildingPowerChanged(dadosConstrucao, estaEnergizado)` <sub>L276</sub>

> Dispara evento de alteração no estado de alimentação elétrica de uma construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados da construção. |
| `estaEnergizado` | `boolean` | Novo status de energia. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnBuildingScanned(dadosConstrucao)` <sub>L283</sub>

> Dispara evento após a conclusão da varredura geométrica e de blocos de uma construção.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os dados da construção varrida. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnStateLoaded()` <sub>L293</sub>

> Dispara evento após o carregamento bem-sucedido dos dados globais ModData.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnStateSaved()` <sub>L299</sub>

> Dispara evento após a gravação persistente dos dados globais no ModData.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnStateReset()` <sub>L305</sub>

> Dispara evento após a redefinição padrão do estado do mod.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnFullSync()` <sub>L315</sub>

> Dispara evento de sincronização total solicitada/recebida no modo rede MP.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.OnDeltaSync()` <sub>L321</sub>

> Dispara evento de sincronização incremental delta solicitada/recebida no modo rede MP.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.GetStats(nomeEvento)` <sub>L333</sub>

> Retorna as estatísticas de disparos consolidadas para um ou todos os eventos.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeEvento` | `string|nil` | O nome do evento a filtrar (nil para retornar todos). |

**Retorno:**
- `table` `Tabela` — contendo estatísticas de contagem de disparo.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.GetHandlerCount(nomeEvento)` <sub>L344</sub>

> Consulta a quantidade de ouvintes/manipuladores vinculados a um evento.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeEvento` | `string` | O nome identificador do evento. |

**Retorno:**
- `integer` `Quantidade` — de ouvintes ativos.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.HasHandlers(nomeEvento)` <sub>L354</sub>

> Verifica se há ouvintes registrados escutando um evento específico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeEvento` | `string` | O nome do evento. |

**Retorno:**
- `boolean` `Retorna` — true se houver ao menos um manipulador escutando o evento.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.PrintStats()` <sub>L359</sub>

> Imprime estatísticas históricas de disparo e ouvintes cadastrados no console.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.PrintEvents()` <sub>L378</sub>

> Imprime a lista detalhada de eventos e ouvintes ordenados por prioridade no console.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.EventManager.ClearStats()` <sub>L390</sub>

> Zera o histórico acumulado de contagem de disparos dos eventos.

---

## `shared/core/LKS_EletricidadeConstrucao_Core_Logger.lua`

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.SetLevel(nivel)` <sub>L75</sub>

> Define o nível global de depuração.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nivel` | `number` | O nível do log (1 a 5). |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.GetLevel()` <sub>L81</sub>

> Obtém o nível global de depuração atual.

**Retorno:**
- `number` `O` — nível do log global ativo.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.SetCategoryLevel(categoria, nivel)` <sub>L88</sub>

> Define o nível de depuração para uma categoria de log específica.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `categoria` | `string` | O nome descritivo da categoria. |
| `nivel` | `number` | O nível do log. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.EnableCategory(categoria)` <sub>L94</sub>

> Habilita a exibição de logs para uma determinada categoria.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `categoria` | `string` | O nome descritivo da categoria. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.DisableCategory(categoria)` <sub>L100</sub>

> Desabilita a exibição de logs para uma determinada categoria.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `categoria` | `string` | O nome descritivo da categoria. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.IsCategoryEnabled(categoria)` <sub>L107</sub>

> Verifica se uma categoria de log está habilitada para exibição.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `categoria` | `string` | O nome descritivo da categoria. |

**Retorno:**
- `boolean` `Retorna` — true se estiver habilitada.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.SetShowTimestamp(habilitado)` <sub>L113</sub>

> Define se o carimbo de data/hora do jogo deve ser impresso nos logs.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `habilitado` | `boolean` | True para exibir. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.SetShowCategory(habilitado)` <sub>L119</sub>

> Define se a categoria correspondente deve ser impressa nos logs.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `habilitado` | `boolean` | True para exibir. |

---

### 🔒 `ShouldLog(nivel, categoria)` <sub>L131</sub>

> Valida se uma mensagem de depuração deve ser impressa de acordo com o nível e categoria.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nivel` | `number` | O nível de log da mensagem específica. |
| `categoria` | `string|nil` | O nome da categoria associada. |

**Retorno:**
- `boolean` `Retorna` — true se a mensagem deve ser impressa.

---

### 🔒 `FormatMessage(nivelTexto, categoria, mensagem)` <sub>L155</sub>

> Formata a mensagem de log adicionando prefixos e informações contextuais.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nivelTexto` | `string` | A identificação do nível (ex: "INFO", "WARN"). |
| `categoria` | `string|nil` | O nome da categoria associada. |
| `mensagem` | `string` | A mensagem descritiva principal. |

**Retorno:**
- `string` `A` — mensagem de log formatada final.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.Error(mensagem, categoria)` <sub>L192</sub>

> Grava uma mensagem de log de erro (ERROR) no console.
> @param categoria? string A categoria (opcional).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `mensagem` | `string` | A mensagem. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem, categoria)` <sub>L209</sub>

> Grava uma mensagem de log de aviso (WARN) no console.
> @param categoria? string A categoria (opcional).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `mensagem` | `string` | A mensagem. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.Info(mensagem, categoria)` <sub>L221</sub>

> Grava uma mensagem de log de informação (INFO) no console.
> @param categoria? string A categoria (opcional).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `mensagem` | `string` | A mensagem. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.Debug(mensagem, categoria)` <sub>L233</sub>

> Grava uma mensagem de log de depuração (DEBUG) no console.
> @param categoria? string A categoria (opcional).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `mensagem` | `string` | A mensagem. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.Trace(mensagem, categoria)` <sub>L245</sub>

> Grava uma mensagem de log de rastreamento detalhado (TRACE) no console.
> @param categoria? string A categoria (opcional).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `mensagem` | `string` | A mensagem. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.LogFuel(nivel, mensagem)` <sub>L261</sub>

> Grava mensagens específicas relacionadas a combustível de geradores.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nivel` | `number` | O nível de severidade do log. |
| `mensagem` | `string` | A mensagem. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.LogPower(nivel, mensagem)` <sub>L281</sub>

> Grava mensagens específicas relacionadas à malha e distribuição de energia.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nivel` | `number` | O nível de severidade do log. |
| `mensagem` | `string` | A mensagem. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.LogBuilding(nivel, mensagem)` <sub>L301</sub>

> Grava mensagens específicas relacionadas à simulação e escaneamento de prédios.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nivel` | `number` | O nível de severidade do log. |
| `mensagem` | `string` | A mensagem. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.LogNetwork(nivel, mensagem)` <sub>L321</sub>

> Grava mensagens específicas relacionadas à transmissão de pacotes de rede (MP).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nivel` | `number` | O nível de severidade do log. |
| `mensagem` | `string` | A mensagem. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.LogUI(nivel, mensagem)` <sub>L341</sub>

> Grava mensagens específicas relacionadas à interface de usuário (UI).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nivel` | `number` | O nível de severidade do log. |
| `mensagem` | `string` | A mensagem. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.StartTimer(nomeTimer)` <sub>L366</sub>

> Inicia a cronometragem de desempenho para um bloco de código específico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeTimer` | `string` | O nome de identificação exclusivo do cronômetro. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.EndTimer(nomeTimer, limiteMilissegundos)` <sub>L377</sub>

> Finaliza a cronometragem de desempenho de um bloco de código, imprimindo o tempo decorrido.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `nomeTimer` | `string` | O nome de identificação exclusivo do cronômetro. |
| `limiteMilissegundos` | `number|nil` | Limite de tolerância em milissegundos para disparar avisos de lentidão (opcional). |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.LogGenerator(dadosGerador, nivel)` <sub>L408</sub>

> Grava no console a representação textual dos dados de um gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | Os dados do gerador. |
| `nivel` | `number|nil` | O nível de severidade do log (padrão: DEBUG). |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.LogBuilding(dadosPredio, nivel)` <sub>L431</sub>

> Grava no console a representação textual dos dados de um prédio.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |
| `nivel` | `number|nil` | O nível de severidade do log (padrão: DEBUG). |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.LogConsumer(dadosConsumidor, nivel)` <sub>L454</sub>

> Grava no console a representação textual dos dados de um consumidor.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | Os dados do consumidor. |
| `nivel` | `number|nil` | O nível de severidade do log (padrão: TRACE). |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Logger.PrintConfig()` <sub>L479</sub>

> Print logger configuration

---

## `shared/core/LKS_EletricidadeConstrucao_Core_Namespace.lua`

### 🌐 `LKS_EletricidadeConstrucao.RegisterModule(moduleName, version)` <sub>L125</sub>

> Registra um submódulo do LKS no histórico interno de boot.
> **Exemplo:**
> ```lua
> LKS_EletricidadeConstrucao.RegisterModule("Core.Namespace", "2.0")
> ```

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `moduleName` | `string` | O nome técnico do submódulo (ex: "Core.Namespace"). |
| `version` | `string` | A versão técnica do submódulo (opcional). |

---

### 🌐 `LKS_EletricidadeConstrucao.IsModuleLoaded(moduleName)` <sub>L138</sub>

> Verifica se um determinado submódulo do LKS já foi carregado e registrado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `moduleName` | `string` | O nome técnico do submódulo a ser verificado. |

**Retorno:**
- `boolean` `Retorna` — true se o módulo já foi registrado no bootstrap.

---

### 🌐 `LKS_EletricidadeConstrucao.GetLoadedModules()` <sub>L145</sub>

> Retorna uma lista contendo os nomes de todos os submódulos registrados no mod.

**Retorno:**
- `table` `Array` — indexado de strings contendo os nomes dos submódulos carregados.

---

### 🌐 `LKS_EletricidadeConstrucao.Print(message, level)` <sub>L161</sub>

> Imprime uma mensagem formatada no console com o prefixo do mod.
> @param level? string O nível do log (ex: "INFO", "WARN", "ERROR", "DEBUG") (opcional, padrão: "INFO").

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `message` | `string` | O texto a ser impresso no log. |

---

### 🌐 `LKS_EletricidadeConstrucao.Error(message)` <sub>L169</sub>

> Imprime uma mensagem de erro no console do jogo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `message` | `string` | O texto explicativo do erro técnico. |

---

### 🌐 `LKS_EletricidadeConstrucao.Warn(message)` <sub>L176</sub>

> Imprime uma mensagem de aviso/alerta no console do jogo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `message` | `string` | O texto explicativo do aviso. |

---

### 🌐 `LKS_EletricidadeConstrucao.Debug(message)` <sub>L183</sub>

> Imprime uma mensagem de debug se o modo debug estiver ativo no sandbox do mod.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `message` | `string` | O texto a ser impresso apenas para desenvolvedores. |

---

## `shared/core/LKS_EletricidadeConstrucao_Core_RuntimeContext.lua`

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.IsServer()` <sub>L37</sub>

> Verifica se o código está sendo executado no contexto de servidor.
> **Nota da Engine:** No Singleplayer do Project Zomboid, a função nativa `isServer()`
> retorna `false` mesmo que a lógica do servidor esteja processando dados locais.
> Para lidar corretamente com Singleplayer, combine esta verificação com `IsSingleplayer()`.

**Retorno:**
- `boolean` `Retorna` — true se estiver rodando em servidor dedicado ou host multiplayer.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.IsClient()` <sub>L47</sub>

> Verifica se o código está rodando no cliente do jogador.
> Em Singleplayer, esta função retorna `true` (já que o cliente e o servidor são integrados localmente).
> Em Multiplayer local/dedicado, retorna `true` apenas nas máquinas dos jogadores.

**Retorno:**
- `boolean` `Retorna` — true se estiver no cliente local do jogador.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.GetGameMode()` <sub>L57</sub>

> Obtém o modo de jogo atual de forma segura durante a inicialização (bootstrap).
> Utiliza a classe nativa do Java `getWorld()` via `pcall` para evitar quebras se chamada antes
> do mundo ou mapa estarem carregados na memória.

**Retorno:**
- `string` `O` — nome descritivo do modo de jogo (ex: "Multiplayer", "Survival", "Loading").

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer()` <sub>L68</sub>

> Verifica se o jogo atual está sendo executado no modo Multiplayer.

**Retorno:**
- `boolean` `Retorna` — true se o modo de jogo for Multiplayer local ou dedicado.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.IsSingleplayer()` <sub>L79</sub>

> Verifica se o jogo atual é Singleplayer (local).

**Retorno:**
- `boolean` `Retorna` — true se for Singleplayer ou se o mundo ainda não estiver disponível.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.IsDedicatedServer()` <sub>L90</sub>

> Verifica se está rodando em um servidor dedicado de Project Zomboid.

**Retorno:**
- `boolean` `Retorna` — true se for um servidor dedicado sem interface gráfica.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayerClient()` <sub>L97</sub>

> Verifica se está rodando no cliente em uma partida multiplayer (não singleplayer).

**Retorno:**
- `boolean` `Retorna` — true se for uma máquina de cliente conectada a um servidor MP.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync()` <sub>L106</sub>

> Verifica se a sincronização de dados por rede (ModData) é necessária.
> Em Singleplayer retorna `false` (dispensando pacotes de rede). Em Multiplayer retorna `true`.

**Retorno:**
- `boolean` `Retorna` — true se as atualizações devem ser transmitidas via rede.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.RequireServer()` <sub>L117</sub>

> Garante que a execução do script ocorra exclusivamente no servidor, lançando um erro caso contrário.
> Útil para travar a execução no topo de arquivos que manipulam bancos de dados e lógica física de servidor.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.RequireClient()` <sub>L126</sub>

> Garante que a execução do script ocorra exclusivamente no cliente, lançando um erro caso contrário.
> Útil para arquivos de interface (UI) e menus de contexto.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.WarnIfWrongContext(expectedContext)` <sub>L135</sub>

> Emite um aviso no console se o script estiver rodando no ambiente oposto ao planejado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `expectedContext` | `string` | O contexto esperado ("server" ou "client"). |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.GetContextInfo()` <sub>L150</sub>

> Retorna uma tabela contendo todos os dados booleanos do ambiente atual.

**Retorno:**
- `table` `Tabela` — contendo chaves como isServer, isClient, gameMode, etc.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.Runtime.PrintContext()` <sub>L164</sub>

> Imprime o relatório detalhado do ambiente atual formatado no console do jogo.

---

## `shared/core/LKS_EletricidadeConstrucao_Core_StateManager.lua`

### 🔒 `NormalizarIdentificadorMundo(valor)` <sub>L40</sub>

> Normaliza o identificador do mundo removendo nulos ou vazios técnicos.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor bruto do identificador. |

**Retorno:**
- `string|nil` `O` — identificador normalizado ou nil.

---

### 🔒 `ObterIdentificadorMundo()` <sub>L57</sub>

> Obtém o identificador exclusivo do mundo atual (save slot).
> Esta verificação previne a contaminação cruzada de estado entre diferentes
> arquivos de salvamento quando o jogador transita entre mundos na mesma sessão de jogo.

**Retorno:**
- `string` `Retorna` — o identificador do mundo ou "unknown" se chamado muito cedo.

---

### 🔒 `ObterIndiceGeradores()` <sub>L107</sub>

> Obtém ou cria a tabela de índice de geradores no ModData global do jogo.

**Retorno:**
- `table` `O` — índice de geradores e chaves de chunk.

---

### 🔒 `ContarGeradores()` <sub>L120</sub>

> Conta a quantidade de geradores presentes no estado ativo.

**Retorno:**
- `integer` `A` — quantidade de geradores.

---

### 🔒 `ContarConstrucoes()` <sub>L131</sub>

> Conta a quantidade de construções registradas no estado ativo.

**Retorno:**
- `integer` `A` — quantidade de construções.

---

### 🔒 `AdicionarGeradorAoIndice(dadosGerador)` <sub>L142</sub>

> Adiciona um gerador ao índice do ModData para carregamento rápido e buscas por chunk.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados estruturados do gerador. |

---

### 🔒 `RemoverGeradorDoIndice(identificadorGerador, chaveChunk)` <sub>L172</sub>

> Remove um gerador das tabelas de índice do ModData.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificadorGerador` | `string` | O identificador único do gerador. |
| `chaveChunk` | `string` | A chave de chunk associada (opcional). |

---

### 🔒 `HidratarGeradoresDoIndice()` <sub>L193</sub>

> Tenta reconstruir a lista de geradores no estado baseado no índice do ModData.

**Retorno:**
- `integer` `A` — quantidade de geradores recuperados.

---

### 🔒 `ExpurgarConstrucoesDuplicadas()` <sub>L232</sub>

> Varre e expurga registros obsoletos de construções duplicadas que compartilham coordenadas.
> Esse método resolve resquícios do carregador antigo, agrupando construções por
> coordenadas físicas e mesclando os geradores e dados elétricos na entidade canônica.

**Retorno:**
- `integer` `A` — quantidade de construções duplicadas expurgadas.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.Initialize()` <sub>L368</sub>

> Inicializa a infraestrutura básica do gerenciador de estado.

**Retorno:**
- `boolean` `Retorna` — true se inicializado com sucesso.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.IsInitialized()` <sub>L386</sub>

> Verifica se o gerenciador de estado foi devidamente inicializado.

**Retorno:**
- `boolean` `Retorna` — true se estiver inicializado.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId()` <sub>L392</sub>

> Expõe o identificador único do mundo atual para outros submódulos.

**Retorno:**
- `string` `O` — identificador ou "unknown".

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.Load()` <sub>L398</sub>

> Carrega os dados persistidos no ModData do jogo.

**Retorno:**
- `boolean` `Retorna` — true se os dados foram desserializados com sucesso.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState()` <sub>L486</sub>

> Valida o identificador do mundo e dispara a desserialização definitiva de dados.
> Deve ser chamado a partir dos eventos OnInitWorld ou OnGameStart quando a API do PZ está pronta.

**Retorno:**
- `boolean` `Retorna` — true se o carregamento foi efetuado com sucesso nesta chamada.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.ReloadIfWorldWasUnknown()` <sub>L531</sub>

> Atalho legado mantido para compatibilidade com outros arquivos do patch.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.IsStateLoaded()` <sub>L537</sub>

> Verifica se o estado já foi lido e verificado para este mundo de jogo.

**Retorno:**
- `boolean` `Retorna` — true se o carregamento definitivo foi concluído.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.Save(forcar, criarBackup)` <sub>L545</sub>

> Persiste o estado ativo de volta nas tabelas de ModData do Project Zomboid.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `forcar` | `boolean` | Se true, força a escrita mesmo se nenhuma alteração tiver sido registrada. |
| `criarBackup` | `boolean` | Se true, cria um snapshot de backup antes de sobrescrever (padrão: true). |

**Retorno:**
- `boolean` `Retorna` — true se o salvamento foi gravado com sucesso.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()` <sub>L609</sub>

> Sinaliza que o estado sofreu alterações e precisa ser persistido na próxima oportunidade.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.IsDirty()` <sub>L615</sub>

> Verifica se o estado de tempo de execução possui dados pendentes de salvamento.

**Retorno:**
- `boolean` `Retorna` — true se houver alterações não salvas.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetState()` <sub>L625</sub>

> Retorna a tabela do estado ativo.

**Retorno:**
- `table|nil` `O` — estado de simulação ativo ou nil.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetConfig()` <sub>L635</sub>

> Retorna a tabela de parâmetros de configuração do estado ativo.

**Retorno:**
- `table` `Tabela` — de parâmetros e preferências sandbox.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.SetConfig(configuracao)` <sub>L644</sub>

> Atualiza as preferências sandbox armazenadas no estado ativo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `configuracao` | `table` | Nova tabela de parâmetros sandbox. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.AddGenerator(dadosGerador)` <sub>L659</sub>

> Registra ou atualiza um gerador nas tabelas de simulação de rede e nos índices de busca.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `table` | Os dados estruturados do gerador. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.RemoveGenerator(identificadorGerador)` <sub>L675</sub>

> Remove um gerador ativo das tabelas do estado e do índice persistente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificadorGerador` | `string` | O identificador único do gerador. |

**Retorno:**
- `table|nil` `Retorna` — os dados do gerador removido, ou nil se não encontrado.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetGenerator(identificadorGerador)` <sub>L694</sub>

> Recupera os dados estruturados de um gerador pelo seu identificador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificadorGerador` | `string` | O ID do gerador. |

**Retorno:**
- `table|nil` `Os` — dados do gerador ou nil.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetAllGenerators()` <sub>L703</sub>

> Retorna o mapa contendo todos os geradores ativos indexados por identificador.

**Retorno:**
- `table` `Mapa` — de geradores cadastrados.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetActiveGenerators()` <sub>L712</sub>

> Retorna a lista contendo apenas os geradores ligados (ativos).

**Retorno:**
- `table` `Lista` — contendo dados dos geradores ligados.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetGeneratorsInChunk(chaveChunk)` <sub>L722</sub>

> Retorna os geradores cujas coordenadas físicas coincidem com a chave de chunk informada.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `chaveChunk` | `string` | A coordenada/chave do chunk do mapa. |

**Retorno:**
- `table` `Lista` — de geradores vinculados ao chunk.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.HydrateGeneratorsFromIndex()` <sub>L731</sub>

> Força a reidratação/restauração dos geradores a partir da tabela de índice do ModData.

**Retorno:**
- `integer` `A` — quantidade de geradores recuperados.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.AddBuilding(dadosConstrucao)` <sub>L741</sub>

> Registra ou atualiza os limites geométricos de uma construção no estado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConstrucao` | `table` | Os limites e dados de consumo elétrico da construção. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.RemoveBuilding(identificadorConstrucao)` <sub>L756</sub>

> Remove os registros associados a uma construção do estado global.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificadorConstrucao` | `string` | O identificador único da construção. |

**Retorno:**
- `table|nil` `Os` — dados da construção removida, ou nil.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetBuilding(identificadorConstrucao)` <sub>L774</sub>

> Busca uma construção registrada pelo seu identificador único.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificadorConstrucao` | `string` | O ID da construção. |

**Retorno:**
- `table|nil` `Os` — dados estruturados da construção ou nil.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetAllBuildings()` <sub>L783</sub>

> Retorna todas as construções que estão cadastradas no gerenciador de rede.

**Retorno:**
- `table` `O` — mapa contendo todas as construções.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetGeneratorBuildings(identificadorGerador)` <sub>L793</sub>

> Retorna os prédios cujos circuitos elétricos estejam sob o raio de alcance de um gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificadorGerador` | `string` | O ID do gerador ativo. |

**Retorno:**
- `table` `A` — lista contendo as construções associadas.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetStatistics()` <sub>L806</sub>

> Obtém a tabela de estatísticas históricas persistida no save.

**Retorno:**
- `table` `Tabela` — contendo dados consolidados de consumo e uso.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.RecordFuelConsumption(quantidade)` <sub>L815</sub>

> Registra o consumo consolidado de combustível na simulação.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quantidade` | `number` | O volume em unidades de combustível. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.UpdateUptime(diferencaSegundos)` <sub>L822</sub>

> Acumula o tempo de funcionamento ativo (uptime) nas estatísticas de rede.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `diferencaSegundos` | `number` | Diferença de tempo físico a acumular. |

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.MarkFullSync()` <sub>L832</sub>

> Atualiza a marca de tempo indicando conclusão de transmissão total de dados de rede.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.MarkDeltaSync()` <sub>L838</sub>

> Atualiza a marca de tempo indicando sincronização delta (incremental) de rede.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.NeedsFullSync()` <sub>L845</sub>

> Verifica se o intervalo padrão para sincronização total de rede foi atingido.

**Retorno:**
- `boolean` `Retorna` — true se for necessário despachar o pacote completo.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.NeedsDeltaSync()` <sub>L854</sub>

> Verifica se o intervalo padrão para sincronização incremental delta foi atingido.

**Retorno:**
- `boolean` `Retorna` — true se for necessário despachar alterações de rede.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.ClearGenerators()` <sub>L866</sub>

> Exclui permanentemente todos os geradores cadastrados.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.ClearBuildings()` <sub>L874</sub>

> Exclui permanentemente todas as construções cadastradas.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.ClearAll()` <sub>L882</sub>

> Limpa todos os dados de rede cadastrados (Geradores e Construções).

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.Reset()` <sub>L890</sub>

> Reseta o contêiner de dados em execução de volta aos padrões originais.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.GetSummary()` <sub>L902</sub>

> Obtém a descrição compacta do volume de dados em execução.

**Retorno:**
- `string` `O` — resumo textual.

---

### 🌐 `LKS_EletricidadeConstrucao.Core.StateManager.PrintDebugInfo()` <sub>L910</sub>

> Consolida e imprime um log descritivo no console contendo as informações do gerenciador.

---

## `shared/data/LKS_EletricidadeConstrucao_Data_Building.lua`

### 🔒 `ComputeHeatingLoad(dadosPredio)` <sub>L71</sub>

> Calcula a carga extra gerada pelo aquecimento da estrutura.
> O consumo do aquecedor é tratado como carga extra apenas quando o prédio possui pelo menos
> um dispositivo elétrico consumindo ativamente. Isso evita sobrecarga com geradores ociosos.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | A tabela contendo os dados do prédio analisado. |

**Retorno:**
- `number` `O` — consumo elétrico gerado pelo aquecimento.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.New(interruptorLuz, raioBorda)` <sub>L197</sub>

> Cria uma nova instância de dados do prédio (BuildingData) a partir do interruptor físico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `interruptorLuz` | `IsoLightSwitch` | O interruptor âncora do prédio. |
| `raioBorda` | `number|nil` | O raio máximo de varredura (opcional). |

**Retorno:**
- `BuildingData` `A` — nova instância do modelo de dados populada.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.MakeId(coordenadaX, coordenadaY, coordenadaZ)` <sub>L242</sub>

> Gera o ID único de texto para um prédio a partir de suas coordenadas no mundo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `coordenadaX` | `number` | A coordenada X. |
| `coordenadaY` | `number` | A coordenada Y. |
| `coordenadaZ` | `number` | A coordenada Z. |

**Retorno:**
- `string` `O` — ID correspondente (formato: bld_x_y_z).

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.ParseId(identificador)` <sub>L249</sub>

> Realiza o parse de um ID único de prédio de volta para coordenadas numéricas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificador` | `string` | O ID gerado (formato: bld_x_y_z). |

**Retorno:**
- `number|nil,` `number` — |nil, number|nil Retorna coordenadaX, coordenadaY, coordenadaZ ou nil se for inválido.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.Validate(dadosPredio)` <sub>L269</sub>

> Valida se a estrutura de dados de um prédio está correta e dentro dos limites permitidos.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | A tabela contendo os dados do prédio. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se estiver correto, ou false com a mensagem descritiva do erro.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.Serialize(dadosPredio)` <sub>L336</sub>

> Serializa os dados do prédio para persistência no ModData do jogo.
> Remove chaves efêmeras que devem ser recalculadas dinamicamente a cada carregamento de chunk para evitar bugs de desatualização.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio a serem limpos e serializados. |

**Retorno:**
- `table` `Uma` — cópia limpa e serializável dos dados do prédio.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.Deserialize(dadosSerializados)` <sub>L353</sub>

> Desserializa a estrutura de dados de um prédio a partir dos dados do ModData do jogo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosSerializados` | `table` | Tabela de dados brutos carregados do ModData. |

**Retorno:**
- `BuildingData|nil` `Retorna` — os dados desserializados estruturados ou nil se for inválido.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.AddConsumer(dadosPredio, consumidor)` <sub>L395</sub>

> Adiciona um consumidor elétrico cadastrado à malha de dados do prédio.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |
| `consumidor` | `ConsumerData` | Os dados do consumidor elétrico a ser inserido. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.RemoveConsumer(dadosPredio, coordenadaX, coordenadaY, coordenadaZ)` <sub>L427</sub>

> Remove um consumidor elétrico cadastrado da malha de dados do prédio.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |
| `coordenadaX` | `number` | A coordenada X física do consumidor. |
| `coordenadaY` | `number` | A coordenada Y física do consumidor. |
| `coordenadaZ` | `number` | A coordenada Z física do consumidor. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.ClearConsumers(dadosPredio)` <sub>L445</sub>

> Limpa todos os consumidores de energia registrados no prédio e zera a carga.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(dadosPredio)` <sub>L452</sub>

> Recalcula a carga de energia elétrica do prédio somando o consumo dos aparelhos ativamente ligados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.SetPowered(dadosPredio, alimentado)` <sub>L487</sub>

> Define o estado atual de fornecimento de energia elétrica do prédio (ligado/desligado).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |
| `alimentado` | `boolean` | Retorna true se o prédio estiver energizado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.ConnectGenerator(dadosPredio, geradorId)` <sub>L496</sub>

> Conecta o prédio ao identificador de um gerador no ecossistema.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |
| `geradorId` | `string` | O ID exclusivo do gerador a ser conectado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.DisconnectGenerator(dadosPredio)` <sub>L504</sub>

> Desconecta o prédio de qualquer gerador, zerando seu estado elétrico (desliga energia).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.MarkScanned(dadosPredio)` <sub>L515</sub>

> Registra a data/hora real de conclusão do último escaneamento de contorno realizado no prédio.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.NeedsRescan(dadosPredio, intervaloMilissegundos)` <sub>L523</sub>

> Verifica se o intervalo de tempo configurado já passou e o prédio precisa ser escaneado novamente.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |
| `intervaloMilissegundos` | `number` | O intervalo de re-escaneamento em milissegundos. |

**Retorno:**
- `boolean` `Retorna` — true se for necessário rodar um novo escaneamento.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.SetBoundingBox(dadosPredio, minimoX, minimoY, maximoX, maximoY)` <sub>L534</sub>

> Define as coordenadas geográficas limites da caixa delimitadora física (Bounding Box) do prédio.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |
| `minimoX` | `number` | Coordenada X mínima. |
| `minimoY` | `number` | Coordenada Y mínima. |
| `maximoX` | `number` | Coordenada X máxima. |
| `maximoY` | `number` | Coordenada Y máxima. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.IsConnected(dadosPredio)` <sub>L550</sub>

> Verifica se o prédio está ativamente vinculado/conectado a um gerador no ecossistema.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |

**Retorno:**
- `boolean` `Retorna` — true se houver gerador conectado.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(dadosPredio)` <sub>L557</sub>

> Obtém a quantidade total de consumidores elétricos atualmente ligados no prédio.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |

**Retorno:**
- `number` `Quantidade` — de consumidores ativos.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.GetTotalConsumerCount(dadosPredio)` <sub>L570</sub>

> Obtém o total acumulado de consumidores (ligados e desligados) cadastrados na malha do prédio.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |

**Retorno:**
- `number` `Quantidade` — total de consumidores elétricos.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.ShouldProvidePower(dadosPredio, dadosGerador)` <sub>L582</sub>

> Verifica se o prédio deve ou não estar energizado com base no estado operacional do gerador conectado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio. |
| `dadosGerador` | `GeneratorData|nil` | Dados operacionais do gerador associado (opcional). |

**Retorno:**
- `boolean` `Retorna` — true se o gerador estiver ativo e fornecendo energia.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Building.ToString(dadosPredio)` <sub>L603</sub>

> Converte o estado operacional do prédio em uma string descritiva legível para fins de depuração.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosPredio` | `BuildingData` | Os dados do prédio analisado. |

**Retorno:**
- `string` `Representação` — descritiva formatada.

---

## `shared/data/LKS_EletricidadeConstrucao_Data_Consumer.lua`

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.New(quadrado, tipoObjeto, indiceObjeto)` <sub>L74</sub>

> Cria uma nova instância de dados de um consumidor (ConsumerData) em um determinado quadrado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `IsoGridSquare` | O quadrado da grade contendo o consumidor. |
| `tipoObjeto` | `string` | O tipo do consumidor elétrico. |
| `indiceObjeto` | `number|nil` | O índice do objeto no quadrado (opcional). |

**Retorno:**
- `ConsumerData` `A` — nova instância populada com o estado do consumidor.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.Validate(dadosConsumidor)` <sub>L109</sub>

> Valida se a estrutura de dados de um consumidor está correta e com valores válidos.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | A tabela de dados do consumidor. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se estiver correto, ou false com a mensagem descritiva do erro.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.Serialize(dadosConsumidor)` <sub>L160</sub>

> Serializa os dados do consumidor em um formato de tabela limpa para armazenamento no ModData.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | A estrutura de dados do consumidor. |

**Retorno:**
- `table` `Uma` — cópia limpa e serializável dos dados do consumidor.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.Deserialize(dadosSerializados)` <sub>L168</sub>

> Desserializa a estrutura de dados de um consumidor a partir dos dados lidos do ModData.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosSerializados` | `table` | Tabela de dados brutos carregados do ModData. |

**Retorno:**
- `ConsumerData|nil` `Retorna` — os dados desserializados ou nil se for inválido.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.GetApplianceStateFromSquare(quadrado)` <sub>L194</sub>

> Detecta se o eletrodoméstico está ligado fisicamente avaliando os objetos Java no grid.
> Ignora validações de fornecimento de energia (ligado/desligado geral do prédio) para obter o estado definido pelo jogador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `IsoGridSquare` | O quadrado de grade onde o consumidor está instalado. |

**Retorno:**
- `boolean` `Retorna` — true se o eletrodoméstico reconhecido estiver ligado.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.UpdateFromSquare(dadosConsumidor, quadrado)` <sub>L245</sub>

> Sincroniza e atualiza o estado operacional e de consumo do dispositivo a partir de seu quadrado físico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | A tabela contendo os dados locais do consumidor. |
| `quadrado` | `IsoGridSquare` | O quadrado físico no grid do mapa. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.CalculatePowerDraw(dadosConsumidor, quadrado)` <sub>L268</sub>

> Calcula o consumo elétrico desenhado pelo consumidor de acordo com o seu tipo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | Os dados do consumidor. |
| `quadrado` | `IsoGridSquare|nil` | O quadrado físico de grade (opcional). |

**Retorno:**
- `number` `O` — consumo elétrico correspondente do dispositivo.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.SetActive(dadosConsumidor, ativo)` <sub>L314</sub>

> Define o estado de ativação operacional do consumidor elétrico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | Os dados do consumidor. |
| `ativo` | `boolean` | Retorna true para ligar o consumidor. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.Toggle(dadosConsumidor)` <sub>L320</sub>

> Inverte (alterna) o estado operacional ativo atual do consumidor elétrico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | Os dados do consumidor. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.DetectType(quadrado)` <sub>L331</sub>

> Detecta o tipo de consumidor elétrico instalado em um quadrado de grade do mapa.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `quadrado` | `IsoGridSquare` | O quadrado a ser inspecionado. |

**Retorno:**
- `string` `O` — tipo de consumidor identificado.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.IsSame(consumidor1, consumidor2)` <sub>L370</sub>

> Verifica se dois consumidores compartilham a mesma posição geográfica e índice no grid.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `consumidor1` | `ConsumerData` | O primeiro consumidor. |
| `consumidor2` | `ConsumerData` | O segundo consumidor. |

**Retorno:**
- `boolean` `Retorna` — true se forem o mesmo dispositivo físico.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.MakeKey(dadosConsumidor)` <sub>L380</sub>

> Gera uma chave descritiva única de texto para indexação do consumidor elétrico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | Os dados do consumidor. |

**Retorno:**
- `string` `A` — chave única gerada.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.GetSquare(dadosConsumidor)` <sub>L397</sub>

> Obtém o quadrado da grade física do mapa associado ao consumidor elétrico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | Os dados do consumidor. |

**Retorno:**
- `IsoGridSquare|nil` `O` — quadrado físico IsoGridSquare ou nulo se descarregado.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.IsValid(dadosConsumidor)` <sub>L404</sub>

> Verifica se o consumidor está atualmente em um quadrado físico carregado na memória do jogo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | Os dados do consumidor. |

**Retorno:**
- `boolean` `Retorna` — true se o quadrado estiver carregado e acessível.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.GetCurrentPower(dadosConsumidor)` <sub>L412</sub>

> Obtém a demanda real instantânea de consumo elétrico do consumidor (retorna zero se inativo).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | Os dados do consumidor. |

**Retorno:**
- `number` `O` — consumo elétrico instantâneo correspondente.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Consumer.ToString(dadosConsumidor)` <sub>L427</sub>

> Converte o estado operacional do consumidor em uma string descritiva formatada.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosConsumidor` | `ConsumerData` | Os dados do consumidor analisado. |

**Retorno:**
- `string` `Representação` — descritiva.

---

## `shared/data/LKS_EletricidadeConstrucao_Data_Generator.lua`

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.New(objetoGerador)` <sub>L70</sub>

> Cria uma nova instância de dados do gerador (GeneratorData) a partir do objeto físico do jogo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objetoGerador` | `IsoGenerator` | O objeto de gerador físico (Java IsoGenerator). |

**Retorno:**
- `GeneratorData` `A` — nova instância populada com o estado do gerador.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.MakeId(coordenadaX, coordenadaY, coordenadaZ)` <sub>L117</sub>

> Gera o ID único de texto para um gerador a partir de suas coordenadas no mundo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `coordenadaX` | `number` | A coordenada X. |
| `coordenadaY` | `number` | A coordenada Y. |
| `coordenadaZ` | `number` | A coordenada Z. |

**Retorno:**
- `string` `O` — ID correspondente (formato: gen_x_y_z).

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.ParseId(identificador)` <sub>L124</sub>

> Realiza o parse de um ID único de gerador de volta para coordenadas numéricas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `identificador` | `string` | O ID gerado (formato: gen_x_y_z). |

**Retorno:**
- `number|nil,` `number` — |nil, number|nil Retorna coordenadaX, coordenadaY, coordenadaZ ou nil se for inválido.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.Validate(dadosGerador)` <sub>L144</sub>

> Valida se a estrutura de dados de um gerador está correta e dentro dos limites permitidos.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | A tabela de dados do gerador. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se estiver correto, ou false com a mensagem descritiva do erro.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.Serialize(dadosGerador)` <sub>L210</sub>

> Serializa os dados do gerador em um formato de tabela limpa para armazenamento no ModData do jogo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | A estrutura de dados do gerador. |

**Retorno:**
- `table` `Uma` — cópia limpa e serializável dos dados do gerador.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.Deserialize(dadosSerializados)` <sub>L218</sub>

> Desserializa a estrutura de dados de um gerador a partir dos dados do ModData.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosSerializados` | `table` | Tabela de dados crus lidos do ModData. |

**Retorno:**
- `GeneratorData|nil` `Retorna` — os dados desserializados ou nil se for inválido.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.UpdateFromObject(dadosGerador, objetoGerador)` <sub>L266</sub>

> Sincroniza e atualiza os dados locais a partir do estado atual de um objeto de gerador físico (Java).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | A tabela de dados do gerador a ser atualizada. |
| `objetoGerador` | `IsoGenerator` | O gerador físico Java de onde ler os dados. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.CalculateStrain(dadosGerador, mapaDadosPredios)` <sub>L283</sub>

> Calcula a carga/esforço elétrico (strain) atual do gerador com base na demanda de prédios conectados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | O gerador sendo analisado. |
| `mapaDadosPredios` | `table` | O mapa contendo todos os dados dos prédios indexados por ID. |

**Retorno:**
- `number` `O` — percentual calculado da carga de strain elétrica (0 a 100+).

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.IsRunning(dadosGerador)` <sub>L308</sub>

> Verifica se o gerador está ativamente em funcionamento (ligado e contendo combustível).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | O gerador analisado. |

**Retorno:**
- `boolean` `Retorna` — true se estiver em operação ativa.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.NeedsRefuel(dadosGerador, limiteMinimo)` <sub>L318</sub>

> Verifica se o nível de combustível está abaixo de um limite mínimo específico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | O gerador analisado. |
| `limiteMinimo` | `number|nil` | O limite mínimo crítico de combustível (padrão: 10). |

**Retorno:**
- `boolean` `Retorna` — true se for necessário reabastecer.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.GetRemainingHours(dadosGerador, taxaCombustivel)` <sub>L327</sub>

> Obtém a quantidade estimada de horas de funcionamento restantes sob a taxa de consumo atual.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | O gerador analisado. |
| `taxaCombustivel` | `number` | A taxa base de consumo de combustível por hora do gerador. |

**Retorno:**
- `number` `A` — quantidade de horas estimadas restantes de autonomia.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.AddBuilding(dadosGerador, predioId)` <sub>L376</sub>

> Vincula um prédio conectado aos dados de carregamento do gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | O gerador analisado. |
| `predioId` | `string` | O ID do prédio a ser adicionado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding(dadosGerador, predioId)` <sub>L392</sub>

> Remove a conexão de um prédio dos dados de carregamento do gerador.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | O gerador analisado. |
| `predioId` | `string` | O ID do prédio a ser removido. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.ClearBuildings(dadosGerador)` <sub>L405</sub>

> Remove as conexões de todos os prédios e zera a carga de esforço elétrico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | O gerador analisado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.Generator.ToString(dadosGerador)` <sub>L417</sub>

> Converte o estado atual do gerador em uma string descritiva legível para fins de depuração.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosGerador` | `GeneratorData` | O gerador analisado. |

**Retorno:**
- `string` `Representação` — descritiva formatada.

---

## `shared/data/LKS_EletricidadeConstrucao_Data_State.lua`

### 🌐 `LKS_EletricidadeConstrucao.Data.State.New()` <sub>L64</sub>

> Cria uma nova instância de dados do estado global (StateData).

**Retorno:**
- `StateData` `A` — nova instância populada com as configurações iniciais.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.Validate(dadosEstado)` <sub>L85</sub>

> Valida se a estrutura de dados do estado global está correta.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se estiver correto, ou false com a mensagem descritiva do erro.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.Serialize(dadosEstado)` <sub>L139</sub>

> Serializa os dados do estado global para armazenamento no ModData.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

**Retorno:**
- `table` `Os` — dados estruturados prontos para serialização.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.Deserialize(dadosSerializados)` <sub>L163</sub>

> Desserializa a estrutura de dados de um estado global a partir do ModData.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosSerializados` | `table` | Os dados brutos lidos do ModData. |

**Retorno:**
- `StateData|nil` `O` — estado desserializado ou nil se for inválido.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.AddGenerator(dadosEstado, dadosGerador)` <sub>L226</sub>

> Adiciona os dados de um gerador ao estado global.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `dadosGerador` | `GeneratorData` | O gerador a ser adicionado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.RemoveGenerator(dadosEstado, idGerador)` <sub>L283</sub>

> Remove um gerador do estado global.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `idGerador` | `string` | O ID exclusivo do gerador. |

**Retorno:**
- `GeneratorData|nil` `Retorna` — os dados do gerador removido ou nil se não for encontrado.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.GetGenerator(dadosEstado, idGerador)` <sub>L311</sub>

> Obtém a estrutura de dados de um gerador por seu ID.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `idGerador` | `string` | O ID exclusivo do gerador. |

**Retorno:**
- `GeneratorData|nil` `Os` — dados do gerador correspondente ou nulo.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.GetAllGenerators(dadosEstado)` <sub>L318</sub>

> Obtém todos os geradores vinculados ao estado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

**Retorno:**
- `table` `Mapa` — de IDs para estruturas GeneratorData.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.AddBuilding(dadosEstado, dadosPredio)` <sub>L329</sub>

> Adiciona os dados de um prédio ao estado global.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `dadosPredio` | `BuildingData` | O prédio a ser adicionado. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.RemoveBuilding(dadosEstado, idPredio)` <sub>L362</sub>

> Remove um prédio do estado global.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `idPredio` | `string` | O ID exclusivo do prédio. |

**Retorno:**
- `BuildingData|nil` `Retorna` — os dados do prédio removido ou nulo.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.GetBuilding(dadosEstado, idPredio)` <sub>L377</sub>

> Obtém a estrutura de dados de um prédio por seu ID.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `idPredio` | `string` | O ID exclusivo do prédio. |

**Retorno:**
- `BuildingData|nil` `Os` — dados do prédio correspondente ou nulo.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.GetAllBuildings(dadosEstado)` <sub>L384</sub>

> Obtém todos os prédios vinculados ao estado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

**Retorno:**
- `table` `Mapa` — de IDs para estruturas BuildingData.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.GetGeneratorBuildings(dadosEstado, idGerador)` <sub>L396</sub>

> Obtém todos os prédios conectados a um gerador específico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `idGerador` | `string` | O ID exclusivo do gerador. |

**Retorno:**
- `table` `Vetor` — contendo dados das estruturas BuildingData conectadas.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.GetGeneratorsInChunk(dadosEstado, chunkKey)` <sub>L412</sub>

> Obtém todos os geradores registrados em um determinado chunk geográfico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `chunkKey` | `string` | A chave de chunk identificadora (chunk_X_Y). |

**Retorno:**
- `table` `Vetor` — contendo as estruturas GeneratorData presentes no chunk.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.GetActiveGenerators(dadosEstado)` <sub>L437</sub>

> Obtém a lista contendo todos os geradores ativamente em funcionamento.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

**Retorno:**
- `table` `Vetor` — contendo os geradores em operação.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(dadosEstado)` <sub>L455</sub>

> Sincroniza e atualiza estatísticas de runtime globais.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.RecordFuelConsumption(dadosEstado, quantidade)` <sub>L493</sub>

> Registra o consumo de combustível acumulado nas estatísticas globais do mod.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `quantidade` | `number` | Volume de combustível consumido. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.UpdateUptime(dadosEstado, segundosDecorridos)` <sub>L500</sub>

> Atualiza o tempo acumulado de funcionamento contínuo do mod.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `segundosDecorridos` | `number` | A diferença de tempo transcorrida em segundos reais. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.MarkFullSync(dadosEstado)` <sub>L510</sub>

> Marca o carimbo de conclusão de uma sincronização completa de dados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.MarkDeltaSync(dadosEstado)` <sub>L517</sub>

> Marca o carimbo de conclusão de uma sincronização incremental (delta) de dados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.NeedsFullSync(dadosEstado, intervaloMilissegundos)` <sub>L525</sub>

> Verifica se é necessário realizar uma sincronização completa baseado no intervalo de tempo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `intervaloMilissegundos` | `number` | O intervalo configurado. |

**Retorno:**
- `boolean` `Retorna` — true se a sincronização for requerida.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.NeedsDeltaSync(dadosEstado, intervaloMilissegundos)` <sub>L534</sub>

> Verifica se é necessário realizar uma sincronização incremental baseado no intervalo de tempo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |
| `intervaloMilissegundos` | `number` | O intervalo configurado. |

**Retorno:**
- `boolean` `Retorna` — true se a sincronização for requerida.

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.ClearGenerators(dadosEstado)` <sub>L545</sub>

> Limpa todos os geradores registrados no estado global.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.ClearBuildings(dadosEstado)` <sub>L553</sub>

> Limpa todos os prédios registrados no estado global.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.ClearAll(dadosEstado)` <sub>L560</sub>

> Zera por completo todos os dados operacionais e estatísticas registradas no mod.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData` | Os dados do estado global. |

---

### 🌐 `LKS_EletricidadeConstrucao.Data.State.GetSummary(dadosEstado)` <sub>L576</sub>

> Obtém a string de resumo com dados estatísticos estruturados do estado do mod.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `dadosEstado` | `StateData|nil` | Os dados do estado global analisado. |

**Retorno:**
- `string` `A` — string de resumo correspondente.

---

## `shared/utils/LKS_EletricidadeConstrucao_Utils_Geometry.lua`

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.ManhattanDistance(x1, y1, x2, y2)` <sub>L35</sub>

> Calcula a distância Manhattan entre dois blocos na grade do jogo (soma das diferenças absolutas dos eixos).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x1` | `number` | Coordenada X do primeiro bloco. |
| `y1` | `number` | Coordenada Y do primeiro bloco. |
| `x2` | `number` | Coordenada X do segundo bloco. |
| `y2` | `number` | Coordenada Y do segundo bloco. |

**Retorno:**
- `number` `A` — distância Manhattan calculada.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.EuclideanDistance(x1, y1, x2, y2)` <sub>L46</sub>

> Calcula a distância Euclidiana simples entre dois blocos na grade do jogo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x1` | `number` | Coordenada X do primeiro bloco. |
| `y1` | `number` | Coordenada Y do primeiro bloco. |
| `x2` | `number` | Coordenada X do segundo bloco. |
| `y2` | `number` | Coordenada Y do segundo bloco. |

**Retorno:**
- `number` `A` — distância linear calculada.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.ChebyshevDistance(x1, y1, x2, y2)` <sub>L57</sub>

> Calcula a distância de Chebyshev entre dois blocos na grade (máximo das distâncias dos eixos individuais).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x1` | `number` | Coordenada X do primeiro bloco. |
| `y1` | `number` | Coordenada Y do primeiro bloco. |
| `x2` | `number` | Coordenada X do segundo bloco. |
| `y2` | `number` | Coordenada Y do segundo bloco. |

**Retorno:**
- `number` `A` — distância de Chebyshev calculada.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.IsAdjacent(x1, y1, x2, y2)` <sub>L68</sub>

> Verifica se dois blocos (tiles) na grade do jogo são adjacentes (incluindo diagonais).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x1` | `number` | Coordenada X do primeiro bloco. |
| `y1` | `number` | Coordenada Y do primeiro bloco. |
| `x2` | `number` | Coordenada X do segundo bloco. |
| `y2` | `number` | Coordenada Y do segundo bloco. |

**Retorno:**
- `boolean` `Retorna` — true se os blocos estiverem encostados.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.IsWithinRadius(x, y, centerX, centerY, radius)` <sub>L80</sub>

> Verifica se um bloco específico está dentro do raio circular a partir do centro (Euclidiano).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada X do bloco a testar. |
| `y` | `number` | Coordenada Y do bloco a testar. |
| `centerX` | `number` | Coordenada X do centro do raio. |
| `centerY` | `number` | Coordenada Y do centro do raio. |
| `radius` | `number` | Raio de busca linear. |

**Retorno:**
- `boolean` `Retorna` — true se o bloco estiver dentro do círculo delimitado.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.IsValidCoordinate(x, y, z)` <sub>L96</sub>

> Verifica se as coordenadas informadas são seguras e válidas no mapa de Project Zomboid.
> Compatível com o mod RV Interior (que gera coordenadas especiais entre -100000 e 200000).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada X. |
| `y` | `number` | Coordenada Y. |
| `z` | `number` | Coordenada Z (andares de 0 a 8) (opcional). |

**Retorno:**
- `boolean` `Retorna` — true se as coordenadas estiverem dentro das faixas válidas e lógicas do mapa.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.IsRVInteriorCoordinate(x, y)` <sub>L129</sub>

> Verifica se as coordenadas informadas pertencem ao mapa especial de Interiores de RV (RV Interior).
> **Detalhe Técnico:** O mod RV Interior tipicamente instancia seus cômodos fictícios em
> coordenadas negativas no plano cartesiano do mapa do PZ.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada X. |
| `y` | `number` | Coordenada Y. |

**Retorno:**
- `boolean` `Retorna` — true se a coordenada representar uma sala do RV Interior.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.GetBoundingBox(coordinates)` <sub>L141</sub>

> Cria uma Bounding Box (caixa de enquadramento) bidimensional a partir de uma lista de coordenadas de tiles.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `coordinates` | `table` | Lista indexada contendo tabelas no formato {x, y} ou {x, y, z}. |

**Retorno:**
- `table` `Tabela` — contendo minX, minY, maxX, maxY, width e height, ou nil se a lista estiver vazia.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.IsInsideBBox(x, y, bbox)` <sub>L177</sub>

> Verifica se uma determinada coordenada de bloco está contida dentro de uma Bounding Box.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada X do bloco. |
| `y` | `number` | Coordenada Y do bloco. |
| `bbox` | `table` | A tabela de Bounding Box contendo minX, minY, maxX e maxY. |

**Retorno:**
- `boolean` `Retorna` — true se o bloco estiver localizado dentro dos limites do envoltório.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.ExpandBBox(bbox, margin)` <sub>L187</sub>

> Expande os limites de uma Bounding Box adicionando uma margem em quadrados para todas as direções.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `bbox` | `table` | A Bounding Box de origem. |
| `margin` | `number` | Margem em quadrados (tiles) a ser adicionada. |

**Retorno:**
- `table` `A` — nova Bounding Box expandida.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.GetTilesInRadius(centerX, centerY, radius)` <sub>L208</sub>

> Obtém as coordenadas de todos os blocos contidos em um raio circular a partir do centro.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `centerX` | `number` | Coordenada X do centro. |
| `centerY` | `number` | Coordenada Y do centro. |
| `radius` | `number` | Raio em blocos. |

**Retorno:**
- `table` `Lista` — contendo tabelas no formato {x, y}.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.GetBorderTiles(structureTiles, borderRadius)` <sub>L228</sub>

> Obtém todos os blocos de borda (contorno) ao redor de uma estrutura.
> Muito mais preciso que Bounding Box simples para edifícios complexos ou em formato de L.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `structureTiles` | `table` | Lista contendo as coordenadas {x, y, z} da construção. |
| `borderRadius` | `number` | Espessura da borda a ser gerada ao redor do prédio (em tiles). |

**Retorno:**
- `table` `Lista` — contendo as coordenadas {x, y, z} dos blocos da borda.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.GetDirection(x1, y1, x2, y2)` <sub>L269</sub>

> Obtém o vetor de direção normalizado (direção de vetor unitário) partindo do ponto 1 para o ponto 2.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x1` | `number` | X do ponto de origem. |
| `y1` | `number` | Y do ponto de origem. |
| `x2` | `number` | X do ponto de destino. |
| `y2` | `number` | Y do ponto de destino. |

**Retorno:**
- `number,` `number` — O vetor normalizado (dx, dy).

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.GetAngle(x1, y1, x2, y2)` <sub>L288</sub>

> Obtém o ângulo em graus (0° a 360°) partindo do ponto 1 para o ponto 2.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x1` | `number` | X do ponto de origem. |
| `y1` | `number` | Y do ponto de origem. |
| `x2` | `number` | X do ponto de destino. |
| `y2` | `number` | Y do ponto de destino. |

**Retorno:**
- `number` `O` — ângulo em graus trigonométricos.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.WorldToChunk(x, y)` <sub>L313</sub>

> Converte coordenadas globais do mapa do jogo para coordenadas de Chunks.
> **Nota da Engine:** No Project Zomboid, cada Chunk (região básica de carregamento)
> corresponde a um grid quadrado de exatamente 10x10 tiles.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada global X. |
| `y` | `number` | Coordenada global Y. |

**Retorno:**
- `number,` `number` — A coordenada do Chunk (ChunkX, ChunkY).

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.GetChunkKey(x, y)` <sub>L322</sub>

> Gera uma chave textual única para identificação do Chunk.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada global X. |
| `y` | `number` | Coordenada global Y. |

**Retorno:**
- `string` `A` — chave de chunk formatada como "cx,cy".

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.ParseTileKey(key)` <sub>L331</sub>

> Converte uma chave de tile "x,y,z" de volta para coordenadas numéricas individuais.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `key` | `string` | A chave textual do tile. |

**Retorno:**
- `number,` `number` — , number As coordenadas numéricas X, Y e Z de volta.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Geometry.MakeTileKey(x, y, z)` <sub>L345</sub>

> Cria uma chave textual única a partir de coordenadas espaciais informadas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x` | `number` | Coordenada X. |
| `y` | `number` | Coordenada Y. |
| `z` | `number` | Coordenada Z (andar). |

**Retorno:**
- `string` `A` — chave textual formatada como "x,y,z".

---

## `shared/utils/LKS_EletricidadeConstrucao_Utils_Math.lua`

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Clamp(value, min, max)` <sub>L40</sub>

> Clampa um número limitando-o a um valor mínimo e máximo.
> **Exemplo:**
> ```lua
> local valor = LKS_EletricidadeConstrucao.Utils.Math.Clamp(150, 0, 100)
> print(valor) -- Output: 100
> ```

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O valor de entrada a ser avaliado. |
| `min` | `number` | O limite mínimo permitido. |
| `max` | `number` | O limite máximo permitido. |

**Retorno:**
- `number` `O` — valor clampado.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.InRange(value, min, max)` <sub>L52</sub>

> Verifica se um determinado número está dentro do intervalo (inclusivo).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O número a ser testado. |
| `min` | `number` | O valor mínimo do intervalo. |
| `max` | `number` | O valor máximo do intervalo. |

**Retorno:**
- `boolean` `Retorna` — true se o valor estiver na faixa especificada.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Normalize(value, min, max)` <sub>L62</sub>

> Normaliza um valor de uma escala [min, max] para uma escala decimal [0, 1].

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O valor a ser normalizado. |
| `min` | `number` | O valor mínimo do intervalo de entrada. |
| `max` | `number` | O valor máximo do intervalo de entrada. |

**Retorno:**
- `number` `O` — valor normalizado entre 0.0 e 1.0.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Lerp(a, b, t)` <sub>L73</sub>

> Realiza uma interpolação linear (Lerp) entre dois números baseado em um fator alfa.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `a` | `number` | O valor inicial (quando t = 0). |
| `b` | `number` | O valor final (quando t = 1). |
| `t` | `number` | O fator de interpolação decimal (0.0 a 1.0). |

**Retorno:**
- `number` `O` — valor interpolado resultante.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Remap(value, inMin, inMax, outMin, outMax)` <sub>L92</sub>

> Remapeia um número de um intervalo de entrada para um novo intervalo de saída desejado.
> **Exemplo:**
> ```lua
> -- Remapeia 5 de uma escala de 0-10 para uma nova escala de 0-100
> local resultado = LKS_EletricidadeConstrucao.Utils.Math.Remap(5, 0, 10, 0, 100)
> print(resultado) -- Output: 50
> ```

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O valor de entrada a ser remapeado. |
| `inMin` | `number` | O limite mínimo do intervalo de entrada original. |
| `inMax` | `number` | O limite máximo do intervalo de entrada original. |
| `outMin` | `number` | O limite mínimo do novo intervalo de saída. |
| `outMax` | `number` | O limite máximo do novo intervalo de saída. |

**Retorno:**
- `number` `O` — valor remapeado correspondente na nova escala.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Round(value)` <sub>L105</sub>

> Arredonda um número para o inteiro mais próximo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O valor decimal de entrada. |

**Retorno:**
- `number` `O` — número arredondado.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.RoundTo(value, decimals)` <sub>L114</sub>

> Arredonda um número para uma quantidade específica de casas decimais.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O valor decimal de entrada. |
| `decimals` | `number` | A quantidade de casas decimais desejadas (ex: 2 para centavos/porcentagem). |

**Retorno:**
- `number` `O` — número arredondado com as casas decimais configuradas.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Floor(value)` <sub>L123</sub>

> Arredonda um número sempre para baixo (piso).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O número de entrada. |

**Retorno:**
- `number` `O` — inteiro arredondado para baixo.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Ceil(value)` <sub>L131</sub>

> Arredonda um número sempre para cima (teto).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O número de entrada. |

**Retorno:**
- `number` `O` — inteiro arredondado para cima.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Sign(value)` <sub>L143</sub>

> Retorna o sinal algébrico de um número (-1, 0 ou 1).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O número a ser testado. |

**Retorno:**
- `number` `Retorna` — -1 se negativo, 0 se nulo, ou 1 se positivo.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Abs(value)` <sub>L153</sub>

> Retorna o valor absoluto de um número (remove o sinal negativo se houver).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O número de entrada. |

**Retorno:**
- `number` `O` — valor absoluto.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Min(a, b)` <sub>L166</sub>

> Retorna o menor valor entre dois números informados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `a` | `number` | O primeiro número. |
| `b` | `number` | O segundo número. |

**Retorno:**
- `number` `O` — menor dos dois números.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Max(a, b)` <sub>L175</sub>

> Retorna o maior valor entre dois números informados.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `a` | `number` | O primeiro número. |
| `b` | `number` | O segundo número. |

**Retorno:**
- `number` `O` — maior dos dois números.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.MinOf(...)` <sub>L183</sub>

> Retorna o menor número contido em uma lista dinâmica de argumentos.
> @param ... number Argumentos numéricos sequenciais.

**Retorno:**
- `number` `O` — menor número da sequência.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.MaxOf(...)` <sub>L198</sub>

> Retorna o maior número contido em uma lista dinâmica de argumentos.
> @param ... number Argumentos numéricos sequenciais.

**Retorno:**
- `number` `O` — maior número da sequência.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Average(...)` <sub>L217</sub>

> Calcula a média aritmética simples de uma lista de números informados como argumentos.
> @param ... number Números a serem calculados na média.

**Retorno:**
- `number` `A` — média aritmética calculada.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.WeightedAverage(values, weights)` <sub>L233</sub>

> Calcula a média ponderada de uma lista de valores multiplicada por pesos correspondentes.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `values` | `table` | Array indexado de valores numéricos. |
| `weights` | `table` | Array indexado de pesos (deve possuir o mesmo tamanho do array de valores). |

**Retorno:**
- `number` `A` — média ponderada resultante.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.ToPercentage(value)` <sub>L258</sub>

> Converte um valor decimal em porcentagem simples (ex: 0.5 → 50%).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O valor decimal de entrada (0.0 a 1.0). |

**Retorno:**
- `number` `O` — valor percentual de 0 a 100.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.FromPercentage(value)` <sub>L266</sub>

> Converte um valor de porcentagem simples de volta para decimal (ex: 50% → 0.5).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O valor percentual de 0 a 100. |

**Retorno:**
- `number` `O` — valor decimal entre 0.0 e 1.0.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.PercentOf(part, total)` <sub>L275</sub>

> Calcula qual é a porcentagem que uma parte representa de um valor total.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `part` | `number` | A parte a ser calculada. |
| `total` | `number` | O total de referência. |

**Retorno:**
- `number` `A` — porcentagem resultante (0 a 100).

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.ApproxEqual(a, b, epsilon)` <sub>L290</sub>

> Compara se dois números de ponto flutuante são aproximadamente iguais levando em conta um épsilon.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `a` | `number` | O primeiro número. |
| `b` | `number` | O segundo número. |
| `epsilon` | `number` | O limite de tolerância (opcional, padrão: 0.0001). |

**Retorno:**
- `boolean` `Retorna` — true se a diferença for menor que a tolerância definida.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.ApproxZero(value, epsilon)` <sub>L300</sub>

> Verifica se um número de ponto flutuante é aproximadamente zero (próximo de zero).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `value` | `number` | O valor a ser testado. |
| `epsilon` | `number` | O limite de tolerância (opcional, padrão: 0.0001). |

**Retorno:**
- `boolean` `Retorna` — true se o valor for menor que a tolerância do erro.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.SmoothStep(edge0, edge1, x)` <sub>L315</sub>

> Executa uma interpolação SmoothStep (suavização Hermite de entrada e saída acelerada).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `edge0` | `number` | O limite inicial inferior da escala. |
| `edge1` | `number` | O limite final superior da escala. |
| `x` | `number` | O ponto de entrada a ser suavizado. |

**Retorno:**
- `number` `O` — valor suavizado decimal final (0.0 a 1.0).

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.Distance2D(x1, y1, x2, y2)` <sub>L327</sub>

> Calcula a distância euclidiana simples entre dois pontos em um plano bi-dimensional (2D).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x1` | `number` | Coordenada X do ponto inicial. |
| `y1` | `number` | Coordenada Y do ponto inicial. |
| `x2` | `number` | Coordenada X do ponto final. |
| `y2` | `number` | Coordenada Y do ponto final. |

**Retorno:**
- `number` `A` — distância linear calculada.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Math.DistanceSquared2D(x1, y1, x2, y2)` <sub>L342</sub>

> Calcula a distância quadrática entre dois pontos 2D (mais rápido para fins de ordenação ou checagem de raio).
> Dispensa a operação pesada de raiz quadrada (`math.sqrt`), servindo idealmente para varreduras de laço rápido.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `x1` | `number` | Coordenada X do ponto inicial. |
| `y1` | `number` | Coordenada Y do ponto inicial. |
| `x2` | `number` | Coordenada X do ponto final. |
| `y2` | `number` | Coordenada Y do ponto final. |

**Retorno:**
- `number` `A` — distância quadrada calculada.

---

## `shared/utils/LKS_EletricidadeConstrucao_Utils_Table.lua`

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.ShallowCopy(tabela)` <sub>L31</sub>

> Realiza uma cópia rasa (shallow copy) de uma tabela (apenas o primeiro nível).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser copiada. |

**Retorno:**
- `table` `A` — nova tabela contendo a cópia rasa.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.DeepCopy(tabela, visitados)` <sub>L47</sub>

> Realiza uma cópia profunda (deep copy) de uma tabela de forma recursiva, tratando referências circulares.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser copiada. |
| `visitados` | `table|nil` | Uso interno para rastreamento de referências circulares. |

**Retorno:**
- `table` `A` — nova tabela contendo a cópia profunda.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.Merge(destino, origem)` <sub>L77</sub>

> Mescla duas tabelas (cópia rasa), modificando a tabela de destino no local.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `destino` | `table` | A tabela que receberá os novos valores. |
| `origem` | `table` | A tabela que contém os valores a serem copiados. |

**Retorno:**
- `table` `A` — tabela de destino modificada.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.DeepMerge(destino, origem)` <sub>L88</sub>

> Mescla profundamente (deep merge) duas tabelas de forma recursiva.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `destino` | `table` | A tabela que receberá as alterações. |
| `origem` | `table` | A tabela que contém os novos valores. |

**Retorno:**
- `table` `A` — tabela de destino modificada.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.Count(tabela)` <sub>L106</sub>

> Conta a quantidade total de elementos em uma tabela (funciona para índices numéricos e associativos).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser contada. |

**Retorno:**
- `number` `O` — número total de elementos.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(tabela)` <sub>L118</sub>

> Verifica se uma tabela está vazia.
> Nota: A engine Kahlua do Project Zomboid não possui a função global next(). Por isso, usamos pairs().

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser verificada. |

**Retorno:**
- `boolean` `Retorna` — true se a tabela estiver vazia, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.Contains(tabela, valorDesejado)` <sub>L129</sub>

> Verifica se a tabela contém um valor específico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser pesquisada. |
| `valorDesejado` | `any` | O valor a ser encontrado na tabela. |

**Retorno:**
- `boolean` `Retorna` — true se o valor for encontrado, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.IndexOf(tabela, valorDesejado)` <sub>L142</sub>

> Procura a primeira ocorrência de um valor em um vetor/array e retorna seu índice numérico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A lista onde a pesquisa será realizada. |
| `valorDesejado` | `any` | O valor a ser localizado. |

**Retorno:**
- `number|nil` `O` — índice da primeira ocorrência, ou nil caso não seja encontrado.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.Filter(tabela, predicado)` <sub>L159</sub>

> Filtra os elementos de uma tabela usando uma função predicado de callback.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser filtrada. |
| `predicado` | `function` | A função de validação com assinatura (valor, chave) -> boolean. |

**Retorno:**
- `table` `Uma` — nova tabela apenas com os elementos que passaram no predicado.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.Map(tabela, transformador)` <sub>L173</sub>

> Mapeia e transforma os elementos de uma tabela aplicando uma função de callback em cada um.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser mapeada. |
| `transformador` | `function` | A função transformadora com assinatura (valor, chave) -> novoValor. |

**Retorno:**
- `table` `Uma` — nova tabela contendo os elementos transformados.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.Find(tabela, predicado)` <sub>L185</sub>

> Procura pelo primeiro elemento na tabela que satisfaça a função predicado de callback.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser pesquisada. |
| `predicado` | `function` | A função de busca com assinatura (valor, chave) -> boolean. |

**Retorno:**
- `any,` `any` — O valor e a chave do primeiro elemento correspondente, ou nil, nil.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.Keys(tabela)` <sub>L201</sub>

> Retorna todas as chaves (keys) presentes na tabela como um vetor numérico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela para extrair as chaves. |

**Retorno:**
- `table` `Um` — vetor contendo todas as chaves.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.Values(tabela)` <sub>L212</sub>

> Retorna todos os valores (values) presentes na tabela como um vetor numérico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela para extrair os valores. |

**Retorno:**
- `table` `Um` — vetor contendo todos os valores.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Table.ToString(tabela, profundidadeMaxima, profundidadeAtual)` <sub>L225</sub>

> Converte uma tabela em uma representação textual estruturada (usado para depuração).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser serializada para texto. |
| `profundidadeMaxima` | `number|nil` | O limite máximo de recursão estrutural (padrão: 3). |
| `profundidadeAtual` | `number|nil` | Rastreamento interno da profundidade atual de execução. |

**Retorno:**
- `string` `A` — representação em texto estruturado da tabela.

---

## `shared/utils/LKS_EletricidadeConstrucao_Utils_Validation.lua`

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsNil(valor)` <sub>L31</sub>

> Verifica se o valor fornecido é nulo (nil).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser avaliado. |

**Retorno:**
- `boolean` `Retorna` — true se o valor for nil, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsNotNil(valor)` <sub>L38</sub>

> Verifica se o valor fornecido não é nulo (not nil).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser avaliado. |

**Retorno:**
- `boolean` `Retorna` — true se o valor não for nil, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.OrDefault(valor, valorPadrao)` <sub>L46</sub>

> Retorna o valor original ou um valor padrão caso o original seja nulo (nil).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser validado. |
| `valorPadrao` | `any` | O valor alternativo retornado caso o primeiro seja nulo. |

**Retorno:**
- `any` `O` — valor original ou o valor padrão.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(valor)` <sub>L60</sub>

> Verifica se o valor fornecido é um número.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser avaliado. |

**Retorno:**
- `boolean` `Retorna` — true se for um número, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsString(valor)` <sub>L67</sub>

> Verifica se o valor fornecido é uma string (texto).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser avaliado. |

**Retorno:**
- `boolean` `Retorna` — true se for uma string, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsBoolean(valor)` <sub>L74</sub>

> Verifica se o valor fornecido é um booleano (verdadeiro/falso).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser avaliado. |

**Retorno:**
- `boolean` `Retorna` — true se for um booleano, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsTable(valor)` <sub>L81</sub>

> Verifica se o valor fornecido é uma tabela.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser avaliado. |

**Retorno:**
- `boolean` `Retorna` — true se for uma tabela, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsFunction(valor)` <sub>L88</sub>

> Verifica se o valor fornecido é uma função.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser avaliado. |

**Retorno:**
- `boolean` `Retorna` — true se for uma função, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.GetType(valor)` <sub>L95</sub>

> Retorna o tipo em formato texto do valor avaliado.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser avaliado. |

**Retorno:**
- `string` `O` — nome do tipo retornado pela engine (ex: "table", "string", "number").

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.ValidateRange(valor, limiteMinimo, limiteMaximo, nomeVariavel)` <sub>L109</sub>

> Valida se um número está contido dentro de um intervalo inclusivo.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `number` | O número a ser validado. |
| `limiteMinimo` | `number` | O valor mínimo aceitável. |
| `limiteMaximo` | `number` | O valor máximo aceitável. |
| `nomeVariavel` | `string|nil` | O nome descritivo da variável para enriquecer a mensagem de erro. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se estiver no intervalo, ou false acompanhado de uma mensagem de erro estruturada.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.ValidatePositive(valor, nomeVariavel)` <sub>L128</sub>

> Valida se um número é estritamente maior que zero (positivo).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `number` | O número a ser validado. |
| `nomeVariavel` | `string|nil` | O nome descritivo da variável para enriquecer a mensagem de erro. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se for positivo, ou false com a mensagem de erro correspondente.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.ValidateNonNegative(valor, nomeVariavel)` <sub>L146</sub>

> Valida se um número é maior ou igual a zero (não-negativo).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `number` | O número a ser validado. |
| `nomeVariavel` | `string|nil` | O nome descritivo da variável para enriquecer a mensagem de erro. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se for não-negativo, ou false com a mensagem de erro correspondente.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsEmptyString(texto)` <sub>L167</sub>

> Verifica se uma string está vazia ou consiste apenas de espaços em branco.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `texto` | `string` | O texto a ser avaliado. |

**Retorno:**
- `boolean` `Retorna` — true se estiver vazio ou com espaços em branco, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.ValidateNotEmpty(texto, nomeVariavel)` <sub>L178</sub>

> Valida se uma string é válida e não está vazia.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `texto` | `string` | O texto a ser validado. |
| `nomeVariavel` | `string|nil` | O nome descritivo da variável para enriquecer a mensagem de erro. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se for válida e populada, ou false com a mensagem de erro.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.ValidateLength(texto, comprimentoMinimo, comprimentoMaximo, nomeVariavel)` <sub>L198</sub>

> Valida se o comprimento de um texto está contido em um intervalo de tamanho específico.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `texto` | `string` | O texto a ser avaliado. |
| `comprimentoMinimo` | `number` | O comprimento de caracteres mínimo aceitável. |
| `comprimentoMaximo` | `number` | O comprimento de caracteres máximo aceitável. |
| `nomeVariavel` | `string|nil` | O nome descritivo da variável para enriquecer a mensagem de erro. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se estiver no intervalo de comprimento, ou false com a mensagem de erro.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.ValidateNotEmptyTable(tabela, nomeVariavel)` <sub>L223</sub>

> Valida se uma tabela existe e não está vazia.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser validada. |
| `nomeVariavel` | `string|nil` | O nome descritivo da variável para enriquecer a mensagem de erro. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se a tabela for populada, ou false com a mensagem de erro correspondente.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.ValidateKeys(tabela, chavesObrigatorias, nomeVariavel)` <sub>L242</sub>

> Valida se uma tabela contém todas as chaves obrigatórias requeridas.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `tabela` | `table` | A tabela a ser validada. |
| `chavesObrigatorias` | `table` | Um vetor contendo os nomes de chaves requeridas na tabela. |
| `nomeVariavel` | `string|nil` | O nome descritivo da tabela para a mensagem de erro. |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se todas as chaves estiverem presentes, ou false com a mensagem de erro identificando a chave faltante.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.ValidateCoordinates(coordenadaX, coordenadaY, coordenadaZ)` <sub>L267</sub>

> Valida se os valores das coordenadas espaciais informadas são números aceitáveis e válidos.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `coordenadaX` | `number` | A coordenada no eixo X. |
| `coordenadaY` | `number` | A coordenada no eixo Y. |
| `coordenadaZ` | `number|nil` | A coordenada no eixo Z (opcional). |

**Retorno:**
- `boolean,` `string` — |nil Retorna true se as coordenadas forem numéricas e válidas dentro dos limites do jogo, ou false com a mensagem correspondente.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsGenerator(objeto)` <sub>L295</sub>

> Valida se o objeto fornecido é uma instância Java da classe de Gerador do jogo (IsoGenerator).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objeto` | `any` | O objeto Java a ser verificado. |

**Retorno:**
- `boolean` `Retorna` — true se for uma instância de IsoGenerator, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsLightSwitch(objeto)` <sub>L305</sub>

> Valida se o objeto fornecido é uma instância Java da classe de Interruptor de Luz do jogo (IsoLightSwitch).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objeto` | `any` | O objeto Java a ser verificado. |

**Retorno:**
- `boolean` `Retorna` — true se for uma instância de IsoLightSwitch, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsGridSquare(objeto)` <sub>L315</sub>

> Valida se o objeto fornecido é uma instância Java da classe de Quadrado da Grade (Tile) do jogo (IsoGridSquare).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objeto` | `any` | O objeto Java a ser verificado. |

**Retorno:**
- `boolean` `Retorna` — true se for uma instância de IsoGridSquare, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.IsIsoObject(objeto)` <sub>L325</sub>

> Valida se o objeto fornecido é uma instância Java da classe base de Objeto do Mundo do jogo (IsoObject).

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `objeto` | `any` | O objeto Java a ser verificado. |

**Retorno:**
- `boolean` `Retorna` — true se for uma instância de IsoObject, caso contrário false.

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.AssertNotNil(valor, mensagemErro)` <sub>L339</sub>

> Garante que um valor não é nulo, disparando um erro caso seja.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser avaliado. |
| `mensagemErro` | `string|nil` | A mensagem de erro customizada caso a asserção falhe. |

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.Assert(condicao, mensagemErro)` <sub>L348</sub>

> Garante que uma condição booleana é verdadeira, disparando um erro caso seja falsa.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `condicao` | `boolean` | A condição lógica a ser testada. |
| `mensagemErro` | `string|nil` | A mensagem de erro customizada caso a asserção falhe. |

---

### 🌐 `LKS_EletricidadeConstrucao.Utils.Validation.AssertType(valor, tipoEsperado, nomeVariavel)` <sub>L358</sub>

> Garante que um valor pertence ao tipo de dado esperado em Lua, disparando um erro caso contrário.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `valor` | `any` | O valor a ser verificado. |
| `tipoEsperado` | `string` | O nome do tipo Lua esperado (ex: "string", "table"). |
| `nomeVariavel` | `string|nil` | O nome descritivo da variável analisada. |

---
