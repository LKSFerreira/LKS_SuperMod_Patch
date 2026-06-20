-- ============================================================================
-- ARQUIVO: LKS_Device_Cooking.lua
-- EXTENSÃO: LKS SuperMod Patch (Módulo de Comportamento de Culinária)
-- OBJETIVO: Driver de comportamento e texturas para fogões (Stoves) e
--           micro-ondas (Microwaves) no gerenciador LKS_ApplianceManager.
--           Suporta 3 tipos de fogão: Convencional (propano), Antigo (lenha)
--           e Indução (eletricidade). A classificação é feita por sprite
--           via LKS_Cooking_SpriteClassification.
-- AUTOR: LKS FERREIRA
-- VERSÃO: 2.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 18/06/2026
-- ============================================================================

-- Inicialização defensiva do gerenciador para robustez de carregamento
LKS_ApplianceManager = LKS_ApplianceManager or {}
LKS_ApplianceManager.devices = LKS_ApplianceManager.devices or {}
LKS_ApplianceManager.containerTypeMap = LKS_ApplianceManager.containerTypeMap or {}
LKS_ApplianceManager.javaClassMap = LKS_ApplianceManager.javaClassMap or {}

if LKS_ApplianceManager.recursoAtivo and not LKS_ApplianceManager.recursoAtivo("CookingEnabled", true) then
    print("[LKS PATCH - LKS_Device_Cooking.lua] Culinaria desativada no sandbox.")
    return
end

local ClassificacaoSprites = require("cooking/LKS_Cooking_SpriteClassification")
local SistemaPropano = require("cooking/LKS_Cooking_PropanoSystem")
local FogaoAntigo = require("devices/cooking/LKS_Device_Cooking_Antigo")

local LKS_Device_Cooking = {
    recipientesAceitos = {"stove", "microwave"},
    classesJava = {"IsoStove", "IsoMicrowave"},
    brilhoInativo = "escurece25"
}

-- ============================================================================
-- GERENCIAMENTO DE ESTADO DE FOGÕES A PROPANO
-- ============================================================================
-- Solução: marcar o tile do fogão como "energizado por gerador" via
-- chunk:addGeneratorPos(). Isso faz isPowered() retornar true nativamente,
-- e o motor Java mantém o fogão aceso sem resistência.
-- Mesmo mecanismo usado pelo LKS_EletricidadeConstrucao para prédios.
-- ============================================================================

--- Registro de fogões atualmente acesos via propano (para evitar varredura global).
--- Chave: "x_y_z", Valor: IsoStove
local _registroFogoesAcesos = {}

--- Registra um fogão como aceso via propano.
---@param fogao IsoStove
local function registrarFogaoAceso(fogao)
    if not fogao then return end
    local chave = fogao:getX() .. "_" .. fogao:getY() .. "_" .. fogao:getZ()
    _registroFogoesAcesos[chave] = fogao
end

--- Remove um fogão do registro.
---@param fogao IsoStove
local function desregistrarFogaoAceso(fogao)
    if not fogao then return end
    local chave = fogao:getX() .. "_" .. fogao:getY() .. "_" .. fogao:getZ()
    _registroFogoesAcesos[chave] = nil
end

--- Marca o tile do fogão como energizado e acende via TimedAction vanilla.
---
--- @param fogao IsoStove O fogão a acender.
--- @param jogador IsoPlayer O jogador que está acendendo.
local function acenderFogaoPropano(fogao, jogador)
    if not fogao or not jogador then return end

    local quadrado = fogao:getSquare()
    if not quadrado then return end

    local chunk = quadrado:getChunk()
    if not chunk then return end

    chunk:addGeneratorPos(fogao:getX(), fogao:getY(), fogao:getZ())
    if quadrado.RecalcAllWithNeighbours then
        quadrado:RecalcAllWithNeighbours(false)
    end

    fogao:getModData().LKS_FogaoAcesoPropano = true
    registrarFogaoAceso(fogao)
    ISTimedActionQueue.add(ISToggleStoveAction:new(jogador, fogao))
end

--- Remove a marca de energia do tile e apaga o fogão.
---
--- @param fogao IsoStove O fogão a apagar.
local function apagarFogaoPropano(fogao)
    if not fogao then return end

    local quadrado = fogao:getSquare()
    if quadrado then
        local chunk = quadrado:getChunk()
        if chunk then
            chunk:removeGeneratorPos(fogao:getX(), fogao:getY(), fogao:getZ())
            if quadrado.RecalcAllWithNeighbours then
                quadrado:RecalcAllWithNeighbours(false)
            end
        end
    end

    fogao:getModData().LKS_FogaoAcesoPropano = nil
    desregistrarFogaoAceso(fogao)
    fogao:setActivated(false)
end

local LKS_ConfiguracaoIconesCulinaria = {
    stove = {
        energizado    = nil,
    },
    microwave = {
        energizado    = nil,
    },
}

--- Retorna a textura correspondente baseada nos estados de energia e tipo de contêiner.
---
--- @param chaveConfiguracao string O tipo de aparelho ("stove", "microwave").
--- @param temEnergia boolean Se o aparelho possui fornecimento elétrico ativo.
--- @return Texture O objeto de textura carregado do jogo.
local function obterTexturaEstado(chaveConfiguracao, temEnergia)
    local configuracaoIcone = LKS_ConfiguracaoIconesCulinaria[chaveConfiguracao]
    if not configuracaoIcone then return nil end

    if configuracaoIcone.energizado then
        return getTexture(configuracaoIcone.energizado)
    else
        return ContainerButtonIcons[chaveConfiguracao]
    end
end

--- Verifica se há objetos metálicos no interior do contêiner do micro-ondas.
---
--- @param containerInventario ItemContainer O contêiner de itens a inspecionar.
--- @return boolean contemMetal Retorna true se houver pelo menos um item metálico.
local function verificarPresencaMetal(containerInventario)
    if not containerInventario then return false end
    local itens = containerInventario:getItems()
    if not itens then return false end

    for indice = 0, itens:size() - 1 do
        local item = itens:get(indice)
        if item then
            -- Valida tags e propriedades de metal comuns do jogo base
            if item:isMetal() or (item:getMetalValue() and item:getMetalValue() > 0) then
                return true
            end
            -- Fallback para tipos conhecidos de latas e objetos metálicos
            local tipoItem = item:getType()
            if tipoItem == "TinCan" or tipoItem == "CannedSoup" or tipoItem == "CannedBeans" or tipoItem == "CannedPeaches" then
                return true
            end
        end
    end
    return false
end

--- Retorna a textura para a Loot Window baseada no estado de energia do recipiente.
---
--- @param recipiente ItemContainer O contêiner sendo desenhado.
--- @param recipienteTipo string O tipo do contêiner.
--- @param objetoPai IsoObject O objeto pai no mundo.
--- @param temEnergia boolean Se o contêiner possui energia elétrica ativa.
--- @return Texture A textura resolvida para o inventário.
function LKS_Device_Cooking.obterTexturaInventario(recipiente, recipienteTipo, objetoPai, temEnergia)
    local chaveConfiguracao = nil
    if recipienteTipo == "stove" then
        chaveConfiguracao = "stove"
    elseif recipienteTipo == "microwave" then
        chaveConfiguracao = "microwave"
    end

    if not chaveConfiguracao then return nil end
    return obterTexturaEstado(chaveConfiguracao, temEnergia)
end

-- ============================================================================
-- BUSCA DE FONTES DE CALOR E MATERIAIS INFLAMÁVEIS (reutiliza lógica vanilla)
-- ============================================================================

--- Busca fontes de calor no inventário do jogador.
--- Reutiliza a mesma detecção do vanilla ISCampingMenu:
--- ItemTag.START_FIRE + Lighter + Matches.
---
--- @param jogador IsoPlayer O jogador.
--- @return table Lista de itens (InventoryItem) que podem iniciar fogo.
local function buscarFontesCalorInventario(jogador)
    local resultados = {}
    if not jogador then return resultados end

    local containers = ISInventoryPaneContextMenu.getContainers(jogador)
    local tiposJaAdicionados = {}

    for indice = 1, containers:size() do
        local container = containers:get(indice - 1)
        local itens = container:getItems()
        for indiceItem = 0, itens:size() - 1 do
            local item = itens:get(indiceItem)
            if item then
                local tipo = item:getType()
                local ehFonteCalor = item:hasTag(ItemTag.START_FIRE)
                    or tipo == "Lighter"
                    or tipo == "Matches"

                if ehFonteCalor and item:getCurrentUses() > 0 and not tiposJaAdicionados[tipo] then
                    table.insert(resultados, item)
                    tiposJaAdicionados[tipo] = true
                end
            end
        end
    end

    return resultados
end

--- Busca materiais inflamáveis (tinder) no inventário do jogador.
--- Reutiliza ISCampingMenu.isValidTinder() do vanilla para validação.
---
--- @param jogador IsoPlayer O jogador.
--- @return table Lista de itens (InventoryItem) válidos como material de combustão.
local function buscarMateriaisCombustao(jogador)
    local resultados = {}
    if not jogador then return resultados end

    local containers = ISInventoryPaneContextMenu.getContainers(jogador)
    local nomesJaAdicionados = {}

    for indice = 1, containers:size() do
        local container = containers:get(indice - 1)
        local itens = container:getItems()
        for indiceItem = 0, itens:size() - 1 do
            local item = itens:get(indiceItem)
            if item and ISCampingMenu.isValidTinder(item) then
                local nomeItem = item:getName()
                if not nomesJaAdicionados[nomeItem] then
                    table.insert(resultados, item)
                    nomesJaAdicionados[nomeItem] = true
                end
            end
        end
    end

    return resultados
end

--- Constrói o submenu LKS para fogões e micro-ondas no mundo.
---
--- ## Como funciona o menu de contexto no Project Zomboid (ISContextMenu):
---
--- O jogo dispara o evento `OnFillWorldObjectContextMenu` para cada clique-direito
--- no mundo. Múltiplos handlers (vanilla + mods) adicionam opções ao mesmo `menuContexto`.
--- Para aparelhos como fogões e micro-ondas, o vanilla JÁ cria um submenu agrupador
--- com o nome traduzido do objeto (ex: "Fogão Vermelho"), e dentro dele coloca as
--- opções "Ligar/Desligar" e "Configurações" (timer, temperatura, potência).
---
--- ### Anatomia de uma opção (`menuContexto.options[i]`):
--- - `.name`         → Texto exibido (string traduzida via getText)
--- - `.onSelect`     → Callback executado ao clicar
--- - `.target`       → Primeiro argumento passado ao callback
--- - `.param1/.param2` → Argumentos adicionais do callback
--- - `.iconTexture`  → Textura exibida à esquerda da opção
--- - `.toolTip`      → Tooltip ISToolTip exibido ao passar o mouse
--- - `.notAvailable` → Se true, a opção fica cinza/desabilitada
--- - `.subOption`    → ID do submenu vinculado (via `addSubMenu`)
---
--- ### Operações principais da API ISContextMenu:
--- - `menuContexto:addOption(texto, alvo, callback, param1, param2)` → Adiciona opção
--- - `menuContexto:addOptionOnTop(texto)` → Adiciona no topo (prioridade visual)
--- - `ISContextMenu:getNew(menuPai)` → Cria submenu vinculado ao menu pai
--- - `menuContexto:addSubMenu(opcaoPai, submenu)` → Vincula submenu a uma opção
--- - `menuContexto:removeOptionByName(texto)` → Remove opção por nome exato
--- - `menuContexto:getSubMenu(idSubmenu)` → Obtém referência ao submenu de uma opção
---
--- ### Estratégia de sequestro do submenu vanilla:
--- Em vez de criar um SEGUNDO submenu com o mesmo nome (causando duplicata),
--- a abordagem correta é:
--- 1. LOCALIZAR a opção vanilla existente pelo nome do objeto traduzido
--- 2. OBTER o submenu vanilla já criado via `.subOption`
--- 3. REMOVER apenas as opções que queremos substituir (Ligar/Desligar)
--- 4. INJETAR nossas opções aprimoradas no submenu existente
--- 5. PRESERVAR tudo que não tocamos (Configurações e qualquer outra)
---
--- @param jogadorNumero number O índice do jogador local (0 a 3).
--- @param menuContexto ISContextMenu O menu de contexto sendo preenchido.
--- @param objetosMundo table A lista de objetos físicos clicados no mundo.
--- @param objetoEletrico IsoObject O objeto elétrico clicado.
function LKS_Device_Cooking.construirMenuContexto(jogadorNumero, menuContexto, objetosMundo, objetoEletrico)
    local ehFogao = instanceof(objetoEletrico, "IsoStove")
    local ehMicroondas = instanceof(objetoEletrico, "IsoMicrowave")
    local ehFireplace = instanceof(objetoEletrico, "IsoFireplace")

    print("[LKS DEBUG Cooking] construirMenuContexto chamado - ehFogao=" .. tostring(ehFogao) .. " ehMicroondas=" .. tostring(ehMicroondas) .. " ehFireplace=" .. tostring(ehFireplace))

    local chaveConfiguracao = nil
    if ehFogao then
        chaveConfiguracao = "stove"
    elseif ehMicroondas then
        chaveConfiguracao = "microwave"
    end

    -- Resolução do nome traduzido do aparelho via propriedades do sprite
    local nomeObjetoTraduzido = ""
    if ehFogao then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Fogão"
    elseif ehMicroondas then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Micro-ondas"
    end

    local propriedadesObjeto = objetoEletrico:getProperties()
    if propriedadesObjeto then
        local nomeGrupo = propriedadesObjeto:has("GroupName") and propriedadesObjeto:get("GroupName") or nil
        local nomeCustomizado = propriedadesObjeto:has("CustomName") and propriedadesObjeto:get("CustomName") or nil
        if nomeGrupo and nomeCustomizado then
            nomeObjetoTraduzido = Translator.getMoveableDisplayName(nomeGrupo .. " " .. nomeCustomizado)
        elseif nomeCustomizado then
            nomeObjetoTraduzido = Translator.getMoveableDisplayName(nomeCustomizado)
        end
    end

    -- Identifica o tipo de fogão por sprite (convencional, inducao ou antigo)
    local tipoFogao = nil
    if ehFogao or ehFireplace then
        tipoFogao = ClassificacaoSprites.obterTipoFogao(objetoEletrico)
    end

    print("[LKS DEBUG Cooking] tipoFogao=" .. tostring(tipoFogao) .. " nomeObjeto=" .. tostring(nomeObjetoTraduzido))

    -- Detecta fonte de energia usando o sistema unificado
    local jogador = getSpecificPlayer(jogadorNumero)
    local fonteEnergia = nil
    local temEnergia = false
    local containerInventario = objetoEletrico:getContainer()

    if tipoFogao then
        if tipoFogao == "antigo" then
            fonteEnergia = FogaoAntigo.verificarFonteEnergia(objetoEletrico)
        else
            fonteEnergia = SistemaPropano.verificarFonteEnergia(objetoEletrico, jogador, tipoFogao)
        end
        temEnergia = fonteEnergia.disponivel
        print("[LKS DEBUG Cooking] fonteEnergia.tipo=" .. tostring(fonteEnergia.tipo) .. " disponivel=" .. tostring(fonteEnergia.disponivel))
    else
        -- Micro-ondas: mantém lógica original (só eletricidade)
        if containerInventario and containerInventario:isPowered() then
            temEnergia = true
        end
    end

    local texturaIconeMenu = obterTexturaEstado(chaveConfiguracao, temEnergia)
    local estaAtivo = false
    if objetoEletrico.isActivated then
        estaAtivo = objetoEletrico:isActivated()
    elseif objetoEletrico.Activated then
        estaAtivo = objetoEletrico:Activated()
    end

    -- =========================================================================
    -- PASSO 1: LOCALIZAR O SUBMENU VANILLA EXISTENTE
    -- =========================================================================
    -- O jogo base já cria uma opção-pai com o nome do aparelho (ex: "Fogão Vermelho")
    -- e vincula um submenu a ela contendo "Ligar" e "Configurações".
    -- Para IsoFireplace, o vanilla cria até 2 entradas (ISCampingMenu + ISBBQMenu).
    -- Precisamos ENCONTRAR a primeira existente para sequestrar seu submenu e
    -- REMOVER todas as duplicatas — mantendo apenas a nossa entrada unificada.
    -- =========================================================================
    local opcaoVanillaEncontrada = nil
    local submenuVanilla = nil
    local indicesParaRemover = {}

    print("[LKS DEBUG Cooking] Passo 1: buscando opcoes vanilla com nome='" .. tostring(nomeObjetoTraduzido) .. "' total_opcoes=" .. tostring(#menuContexto.options))

    for indice, opcao in ipairs(menuContexto.options) do
        if opcao.name == nomeObjetoTraduzido and opcao.subOption then
            if not opcaoVanillaEncontrada then
                opcaoVanillaEncontrada = opcao
                submenuVanilla = menuContexto:getSubMenu(opcao.subOption)
                print("[LKS DEBUG Cooking] Passo 1: sequestrou opcao vanilla indice=" .. indice)
            else
                table.insert(indicesParaRemover, indice)
                print("[LKS DEBUG Cooking] Passo 1: marcou duplicata para remocao indice=" .. indice)
            end
        end
    end

    -- Remove entradas duplicadas do vanilla (de trás para frente para não invalidar índices)
    print("[LKS DEBUG Cooking] Passo 1: removendo " .. #indicesParaRemover .. " duplicata(s)")
    for idx = #indicesParaRemover, 1, -1 do
        table.remove(menuContexto.options, indicesParaRemover[idx])
    end

    -- =========================================================================
    -- PASSO 2: DECIDIR SE SEQUESTRA O VANILLA OU CRIA UM NOVO
    -- =========================================================================
    -- Se o vanilla já criou o submenu, reutilizamos ele.
    -- Se não (caso de mods que alteram a ordem ou fogões sem submenu vanilla),
    -- criamos o nosso normalmente como fallback.
    -- =========================================================================
    local submenu = nil
    local opcaoMenuPai = nil

    if submenuVanilla then
        submenu = submenuVanilla
        opcaoMenuPai = opcaoVanillaEncontrada
        print("[LKS DEBUG Cooking] Passo 2: sequestrou submenu vanilla (opcoes=" .. tostring(submenu.options and #submenu.options or 0) .. ")")
    else
        opcaoMenuPai = menuContexto:addOptionOnTop(nomeObjetoTraduzido)
        submenu = ISContextMenu:getNew(menuContexto)
        menuContexto:addSubMenu(opcaoMenuPai, submenu)
        print("[LKS DEBUG Cooking] Passo 2: criou submenu proprio (fallback)")

        -- No fallback, usa o sprite real do objeto via splitIcon()
        local spriteObjeto = objetoEletrico:getSprite()
        if spriteObjeto then
            local texturaSplit = getTexture(spriteObjeto:getName())
            if texturaSplit then
                opcaoMenuPai.iconTexture = texturaSplit:splitIcon()
            end
        end
    end

    -- =========================================================================
    -- PASSO 3: LIMPAR OPÇÕES VANILLA DO SUBMENU
    -- =========================================================================
    -- Para IsoStove/IsoMicrowave: remove apenas toggle (Ligar/Desligar).
    -- Para IsoFireplace: o submenu vem do ISCampingMenu/ISBBQMenu com opções
    -- próprias (Acender, Destruir para Virar Combustível, Informações, etc.).
    -- Limpamos TUDO e reconstruímos do zero com nossas opções.
    -- =========================================================================
    if submenu and submenu.options then
        if tipoFogao == "antigo" then
            -- Fogão antigo: NÃO limpa o submenu vanilla — as opções de
            -- combustível sólido, acender e destruir já são gerenciadas
            -- pelo ISCampingMenu/ISBBQMenu nativamente.
            print("[LKS DEBUG Cooking] Passo 3: mantendo opcoes vanilla do submenu (tipo antigo, " .. #submenu.options .. " opcoes)")
        else
            local textoLigarVanilla = getText("ContextMenu_TurnOn")
            local textoDesligarVanilla = getText("ContextMenu_TurnOff")
            if submenu.removeOptionByName then
                pcall(function() submenu:removeOptionByName(textoLigarVanilla) end)
                pcall(function() submenu:removeOptionByName(textoDesligarVanilla) end)
            end
        end
    end

    -- =========================================================================
    -- PASSO 4: INJETAR NOSSAS OPÇÕES APRIMORADAS NO SUBMENU
    -- =========================================================================
    -- Adicionamos nossa versão de Ligar/Desligar com:
    -- - Ícones customizados (LKS_Button_Power_On/Off)
    -- - Tooltips com temperatura atual em °C (fogão)
    -- - Alertas de segurança coloridos (equipamento aquecido, metal no micro-ondas)
    -- - Estado desabilitado visual quando não há energia
    --
    -- Estas opções são inseridas NO TOPO do submenu via `addOptionOnTop` para
    -- que apareçam antes de "Configurações" (hierarquia: energia > ajustes).
    -- =========================================================================
    -- =========================================================================
    -- PASSO 4: CONSTRUIR OPÇÃO DE ACENDER/LIGAR COM SUBMENU DE IGNIÇÃO
    -- =========================================================================
    -- Comportamento diferenciado por tipo:
    --   Convencional (propano): "Acender" > [fontes de calor] (sem tinder)
    --   Antigo (lenha):     "Acender" > [fontes de calor] > [material inflamável]
    --   Indução/Micro:      "Ligar" direto (sem submenu de ignição)
    -- =========================================================================

    -- Determina verbo e ícone baseado no tipo
    local verboAcender, verboApagar, iconeDesligado
    if tipoFogao == "convencional" then
        verboAcender = getText("IGUI_LKS_Acender") or "Acender"
        verboApagar = getText("IGUI_LKS_Apagar") or "Apagar"
        iconeDesligado = "media/ui/LKS_Menu_Propano_Off.png"
    elseif tipoFogao == "antigo" then
        -- Fogão antigo: o vanilla já gerencia acender/apagar via ISCampingMenu.
        -- Não injetamos nossas opções — apenas garantimos entrada única no menu.
        print("[LKS DEBUG Cooking] Passo 4: tipo antigo - usando opcoes vanilla intactas")
    else
        verboAcender = getText("ContextMenu_TurnOn") or "Ligar"
        verboApagar = getText("ContextMenu_TurnOff") or "Desligar"
        iconeDesligado = "media/ui/LKS_Menu_Electricity_Off.png"
    end

    if tipoFogao ~= "antigo" then

    if estaAtivo then
        -- Apagar/Desligar: comportamento diferenciado
        local opcaoApagar = submenu:addOptionOnTop(verboApagar, objetosMundo, function()
            if ehFogao and tipoFogao == "convencional" then
                apagarFogaoPropano(objetoEletrico)
            elseif ehFogao then
                ISWorldObjectContextMenu.onToggleStove(objetosMundo, objetoEletrico, jogadorNumero)
            elseif ehMicroondas then
                ISWorldObjectContextMenu.onToggleMicrowave(objetosMundo, objetoEletrico, jogadorNumero)
            end
        end)
        opcaoApagar.iconTexture = getTexture("media/ui/LKS_Button_Power_Off.png")
    else
        if temEnergia then
            if tipoFogao == "convencional" then
                -- Fogão convencional: submenu com fontes de calor do inventário
                local fontesCalor = buscarFontesCalorInventario(jogador)

                if #fontesCalor > 0 then
                    local opcaoAcender = submenu:addOptionOnTop(verboAcender, objetosMundo, nil)
                    opcaoAcender.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")
                    local submenuIgnicao = ISContextMenu:getNew(submenu)
                    submenu:addSubMenu(opcaoAcender, submenuIgnicao)

                    for _, fonteCalorItem in ipairs(fontesCalor) do
                        local opcaoFonte = submenuIgnicao:addOption(
                            fonteCalorItem:getDisplayName(), objetosMundo, function()
                                acenderFogaoPropano(objetoEletrico, jogador)
                            end)
                        opcaoFonte.iconTexture = fonteCalorItem:getTex()
                    end
                else
                    -- Sem fontes de calor no inventário
                    local opcaoAcender = submenu:addOptionOnTop(verboAcender, objetosMundo, nil)
                    opcaoAcender.notAvailable = true
                    opcaoAcender.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")
                    local tooltipSemFonte = ISWorldObjectContextMenu.addToolTip()
                    tooltipSemFonte.description = getText("IGUI_LKS_RequerFonteCalor") or "Requer uma fonte de calor (isqueiro, fósforos, etc.) para acender."
                    opcaoAcender.toolTip = tooltipSemFonte
                end
            else
                -- Indução/Micro-ondas: "Ligar" direto (eletricidade faz tudo)
                local opcaoLigar = submenu:addOptionOnTop(verboAcender, objetosMundo, function()
                    if ehFogao then
                        ISWorldObjectContextMenu.onToggleStove(objetosMundo, objetoEletrico, jogadorNumero)
                    elseif ehMicroondas then
                        ISWorldObjectContextMenu.onToggleMicrowave(objetosMundo, objetoEletrico, jogadorNumero)
                    end
                end)
                opcaoLigar.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")

                if ehMicroondas and verificarPresencaMetal(containerInventario) then
                    local tooltipAviso = ISWorldObjectContextMenu.addToolTip()
                    tooltipAviso:setName(nomeObjetoTraduzido)
                    tooltipAviso.description = " <RGB:1,1,0> " .. (getText("IGUI_LKS_AvisoMetalMicroondas") or "⚠️ AVISO: Contém objetos metálicos no interior!")
                    opcaoLigar.toolTip = tooltipAviso
                end
            end
        else
            -- Sem combustível/energia: opção desabilitada com tooltip explicativo
            local opcaoSemEnergia = submenu:addOptionOnTop(verboAcender, objetosMundo, nil)
            opcaoSemEnergia.notAvailable = true
            opcaoSemEnergia.iconTexture = getTexture(iconeDesligado)

            local tooltipErro = ISWorldObjectContextMenu.addToolTip()
            tooltipErro:setName(nomeObjetoTraduzido)

            if tipoFogao == "convencional" then
                tooltipErro.description = getText("IGUI_LKS_RequerGasOuBotijao") or "Requer gás encanado ou botijão de gás conectado."
            elseif tipoFogao == "inducao" then
                tooltipErro.description = getText("IGUI_LKS_RequerEletricidade") or "Requer eletricidade (rede elétrica ou gerador)."
            else
                tooltipErro.description = getText("IGUI_LKS_RequerEnergiaProxima") or "Requer uma fonte de energia próxima."
            end

            opcaoSemEnergia.toolTip = tooltipErro
        end
    end

    end -- fim do guard tipoFogao ~= "antigo"

    -- =========================================================================
    -- PASSO 5: GARANTIR OPÇÃO "CONFIGURAÇÕES" E APLICAR ÍCONE
    -- =========================================================================
    -- O vanilla só adiciona "Configurações" quando isPowered() é true.
    -- Para fogões a propano desligados (sem addGeneratorPos ativo), isPowered()
    -- é false e o vanilla não cria a opção. Injetamos manualmente para que o
    -- jogador sempre possa ajustar temperatura e timer independente do estado.
    -- Também aplicamos o ícone LKS_Menu_Settings em qualquer opção sem ícone.
    -- =========================================================================
    local textoConfiguracoes = getText("ContextMenu_StoveSetting") or "Configurações"
    local jaTemConfiguracoes = false

    if submenu and submenu.options then
        for _, opcao in ipairs(submenu.options) do
            if opcao.name == textoConfiguracoes then
                jaTemConfiguracoes = true
                if not opcao.iconTexture then
                    opcao.iconTexture = getTexture("media/ui/LKS_Menu_Settings.png")
                end
            end
        end
    end

    if not jaTemConfiguracoes and ehFogao and submenu then
        local opcaoConfig = submenu:addOption(textoConfiguracoes, objetosMundo, function()
            ISWorldObjectContextMenu.onStoveSetting(objetosMundo, objetoEletrico, jogadorNumero)
        end)
        opcaoConfig.iconTexture = getTexture("media/ui/LKS_Menu_Settings.png")
    elseif not jaTemConfiguracoes and ehMicroondas and submenu then
        local opcaoConfig = submenu:addOption(textoConfiguracoes, objetosMundo, function()
            ISWorldObjectContextMenu.onMicrowaveSetting(objetosMundo, objetoEletrico, jogadorNumero)
        end)
        opcaoConfig.iconTexture = getTexture("media/ui/LKS_Menu_Settings.png")
    end

    -- ============================================================================
    -- TODO: 💥 MECÂNICA AVANÇADA DE FÍSICA DE METAL NO MICRO-ONDAS
    -- Desenvolver nas próximas etapas os seguintes comportamentos para o micro-ondas:
    -- 1. Detecção de funcionamento ativo com metais no interior.
    -- 2. Após 2 segundos ligado, iniciar efeitos visuais/sonoros de faíscas ("pipocos" e "estalos").
    -- 3. Atingir o ápice de faíscas aos 5 segundos de funcionamento.
    -- 4. Consequências físicas aplicadas ao final do ciclo ou interrupção:
    --    - Redução progressiva de integridade do micro-ondas (25% de dano por ciclo).
    --    - Estragar qualquer tipo de comida no interior.
    --    - Danificar e quebrar utensílios não-preparados (ex: rádios de pilha, eletrônicos).
    -- 5. Sistema de filtragem fina de contêiner para permitir itens plausíveis
    --    (como roupas, calçados, tecidos) e rejeitar itens impossíveis (pneus, cadeiras).
    -- ============================================================================
end

-- Registro dinâmico no Appliance Manager
table.insert(LKS_ApplianceManager.devices, LKS_Device_Cooking)
for _, tipo in ipairs(LKS_Device_Cooking.recipientesAceitos) do
    LKS_ApplianceManager.containerTypeMap[tipo] = LKS_Device_Cooking
end
for _, classe in ipairs(LKS_Device_Cooking.classesJava) do
    LKS_ApplianceManager.javaClassMap[classe] = LKS_Device_Cooking
end

-- ============================================================================
-- MONKEY-PATCH: UI do Fogão — Sincroniza toggle com mecânica de propano
-- ============================================================================
-- Detecta qual UI está ativa (NR_OvenPanel do Neat Rocco ou ISOvenUI vanilla)
-- e aplica o patch correspondente. Nosso mod é o último a carregar, então
-- qualquer sobrescrita será definitiva.
--
-- NR_OvenPanel: getHeaderPowerState + onClickPower
-- ISOvenUI:     updateButtons + onClick
-- ============================================================================

--- Lógica compartilhada: determina estado do fogão para propano.
--- Reutilizada por ambos os patches (NR e vanilla).
---
--- @param fogao IsoObject O fogão.
--- @param jogador IsoPlayer O jogador.
--- @return string estado "on"|"off"|"sem_combustivel"|"sem_calor"|"eletricidade"
--- @return string|nil motivo Tooltip explicativo quando desabilitado.
local function determinarEstadoFogaoPropano(fogao, jogador)
    if not fogao or not instanceof(fogao, "IsoStove") then
        return "eletricidade", nil
    end

    local tipoFogao = ClassificacaoSprites.obterTipoFogao(fogao)
    if tipoFogao ~= "convencional" then
        return "eletricidade", nil
    end

    local estaAtivo = fogao.Activated and fogao:Activated() or false
    if estaAtivo then
        return "on", nil
    end

    local fonteEnergia = SistemaPropano.verificarFonteEnergia(fogao, jogador, tipoFogao)
    if not fonteEnergia.disponivel then
        local motivo = getText("IGUI_LKS_RequerGasOuBotijao") or "Requer gás encanado ou botijão de gás conectado."
        return "sem_combustivel", motivo
    end

    local fontesCalor = buscarFontesCalorInventario(jogador)
    if #fontesCalor == 0 then
        return "sem_calor", getText("IGUI_LKS_RequerFonteCalor") or "Requer uma fonte de calor."
    end

    return "off", nil
end

--- Lógica compartilhada: executa toggle do fogão com propano.
---
--- @param fogao IsoObject O fogão.
--- @param jogador IsoPlayer O jogador.
--- @return boolean tratado True se o propano tratou a ação (não precisa do vanilla).
local function executarTogglePropano(fogao, jogador)
    if not fogao or not instanceof(fogao, "IsoStove") then
        return false
    end

    local dadosMod = fogao:getModData()
    if dadosMod.LKS_FogaoAcesoPropano == true then
        apagarFogaoPropano(fogao)
        return true
    end

    local containerFogao = fogao:getContainer()
    local temEletricidade = containerFogao and containerFogao:isPowered() or false
    local estaAtivo = fogao.Activated and fogao:Activated() or false

    if not temEletricidade and not estaAtivo then
        local tipoFogao = ClassificacaoSprites.obterTipoFogao(fogao)
        if tipoFogao == "convencional" then
            local fonteEnergia = SistemaPropano.verificarFonteEnergia(fogao, jogador, tipoFogao)
            if fonteEnergia.disponivel then
                local fontesCalor = buscarFontesCalorInventario(jogador)
                if #fontesCalor > 0 then
                    acenderFogaoPropano(fogao, jogador)
                end
            end
            return true
        end
    end

    return false
end

local function aplicarPatchUIFogao()
    -- =========================================================================
    -- PRIORIDADE 1: NR_OvenPanel (Neat Rocco's UI)
    -- Se instalado, o vanilla ISOvenUI nunca é instanciado — patchear o NR.
    -- =========================================================================
    if NR_OvenPanel then
        local nrGetHeaderPowerState = NR_OvenPanel.getHeaderPowerState
        local nrOnClickPower = NR_OvenPanel.onClickPower

        function NR_OvenPanel:getHeaderPowerState()
            local estado, motivo = determinarEstadoFogaoPropano(self.oven, self.character)
            self._lksTooltipPropano = motivo
            if estado == "eletricidade" then
                return nrGetHeaderPowerState(self)
            elseif estado == "on" then
                return "on"
            elseif estado == "off" then
                return "off"
            else
                return "disabled"
            end
        end

        function NR_OvenPanel:onClickPower()
            if executarTogglePropano(self.oven, self.character) then
                return
            end
            nrOnClickPower(self)
        end

        -- Corrige labels C/F para °C/°F nos botões de unidade de temperatura.
        -- O NR hardcoda "C" e "F" numa closure local de createChildren.
        -- Interceptamos createChildren para substituir o prerender dos botões
        -- após a execução original, reutilizando as texturas já criadas.
        local nrCreateChildren = NR_OvenPanel.createChildren

        function NR_OvenPanel:createChildren()
            nrCreateChildren(self)

            -- Intercepta prerender do powerButton para injetar tooltip de propano.
            -- O NR substitui o prerender inteiro do ISButton por uma closure que
            -- nunca chama updateTooltip(), impedindo a exibicao de qualquer tooltip.
            -- Nosso wrapper restaura essa chamada apos ajustar o campo tooltip.
            if self.header and self.header.powerButton then
                local prerenderOriginal = self.header.powerButton.prerender
                local painelRef = self
                self.header.powerButton.prerender = function(btn)
                    prerenderOriginal(btn)
                    if painelRef._lksTooltipPropano then
                        btn.tooltip = painelRef._lksTooltipPropano
                    end
                    btn:updateTooltip()
                end
            end

            -- Reconstrói prerender com °C/°F usando as dimensões reais do botão
            if self.celsiusBtn then
                local btnOriginal = self.celsiusBtn
                btnOriginal.prerender = function(btn)
                    local ativo = getCore():isCelsius()
                    local hover = btn:isMouseOver()
                    local r, g, b2
                    if ativo then
                        r, g, b2 = 0.95, 0.5, 0.1
                        if hover then r, g, b2 = math.min(r*1.2,1), math.min(g*1.2,1), math.min(b2*1.2,1) end
                    else
                        local v = hover and 0.3 or 0.2
                        r, g, b2 = v, v, v
                    end
                    local tamanho = btn:getWidth()
                    btn:drawRect(0, 0, tamanho, tamanho, 0.8, r, g, b2)
                    btn:drawRectBorder(0, 0, tamanho, tamanho, 1, 0.4, 0.4, 0.4)
                    local label = getText("IGUI_Oven_Celsius") or "C"
                    local fh = getTextManager():getFontHeight(UIFont.Small)
                    local fw = getTextManager():MeasureStringX(UIFont.Small, label)
                    btn:drawText(label, math.floor((tamanho - fw) / 2), math.floor((tamanho - fh) / 2), 1, 1, 1, 1, UIFont.Small)
                end
            end

            if self.fahrenheitBtn then
                local btnOriginal = self.fahrenheitBtn
                btnOriginal.prerender = function(btn)
                    local ativo = not getCore():isCelsius()
                    local hover = btn:isMouseOver()
                    local r, g, b2
                    if ativo then
                        r, g, b2 = 0.95, 0.5, 0.1
                        if hover then r, g, b2 = math.min(r*1.2,1), math.min(g*1.2,1), math.min(b2*1.2,1) end
                    else
                        local v = hover and 0.3 or 0.2
                        r, g, b2 = v, v, v
                    end
                    local tamanho = btn:getWidth()
                    btn:drawRect(0, 0, tamanho, tamanho, 0.8, r, g, b2)
                    btn:drawRectBorder(0, 0, tamanho, tamanho, 1, 0.4, 0.4, 0.4)
                    local label = getText("IGUI_Oven_Fahrenheit") or "F"
                    local fh = getTextManager():getFontHeight(UIFont.Small)
                    local fw = getTextManager():MeasureStringX(UIFont.Small, label)
                    btn:drawText(label, math.floor((tamanho - fw) / 2), math.floor((tamanho - fh) / 2), 1, 1, 1, 1, UIFont.Small)
                end
            end
        end

        print("[LKS PATCH - LKS_Device_Cooking.lua] Monkey-patch NR_OvenPanel aplicado (Neat Rocco detectado)")
        return
    end

    -- =========================================================================
    -- PRIORIDADE 2: ISOvenUI (vanilla)
    -- Fallback quando Neat Rocco não está instalado.
    -- =========================================================================
    if not ISOvenUI then
        pcall(function() require("ISUI/Fireplace/ISOvenUI") end)
    end

    if not ISOvenUI then
        print("[LKS PATCH - LKS_Device_Cooking.lua] Nenhuma UI de fogao encontrada, patch ignorado")
        return
    end

    local vanillaUpdateButtons = ISOvenUI.updateButtons
    local vanillaOnClick = ISOvenUI.onClick

    function ISOvenUI:updateButtons()
        vanillaUpdateButtons(self)

        local estado, motivo = determinarEstadoFogaoPropano(self.oven, self.character)
        if estado == "eletricidade" then return end

        if estado == "on" then
            self.ok:setTitle(getText("IGUI_LKS_Apagar") or "Apagar")
            self.ok:setEnable(true)
            self.ok.tooltip = nil
        elseif estado == "off" then
            self.ok:setTitle(getText("IGUI_LKS_Acender") or "Acender")
            self.ok:setEnable(true)
            self.ok.tooltip = nil
        else
            self.ok:setTitle(getText("IGUI_LKS_Acender") or "Acender")
            self.ok:setEnable(false)
            self.ok.tooltip = motivo
        end
    end

    function ISOvenUI:onClick(button)
        if button.internal == "OK" then
            if executarTogglePropano(self.oven, self.character) then
                return
            end
        end
        vanillaOnClick(self, button)
    end

    print("[LKS PATCH - LKS_Device_Cooking.lua] Monkey-patch ISOvenUI vanilla aplicado")
end

Events.OnGameStart.Add(aplicarPatchUIFogao)

-- ============================================================================
-- SISTEMA DE CONSUMO DE PROPANO DO BOTIJÃO
-- ============================================================================
-- Tick client-side que drena o botijão conectado enquanto o fogão está aceso.
-- Regra: se LKS_FogaoAcesoPropano + LKS_BotijaoConectado → consome.
-- Gás encanado sem botijão: não consome.
-- Botijão vazio: apaga o fogão automaticamente.
-- ============================================================================

--- Multiplicador de consumo aplicado ao UseDelta do item por minuto de jogo.
--- Quanto maior, mais rápido o botijão se esvazia.
--- Com valor 8: botijão 15kg dura ~20h, 45kg dura ~42h de fogo contínuo.
local MULTIPLICADOR_CONSUMO_PROPANO = 8

--- IDs de botijão aceitos para busca no raio.
local IDS_BOTIJAO_CONSUMO = {
    ["Base.PropaneTank"] = true,
    ["LKS_Propano.LKS_Botijao15kg"] = true,
    ["LKS_Propano.LKS_Botijao45kg"] = true,
}

--- Busca o botijão fisicamente conectado a um fogão no raio.
---@param fogao IsoStove
---@return InventoryItem|nil itemBotijao O item do botijão, ou nil.
local function buscarBotijaoConectado(fogao)
    local fogaoX = fogao:getX()
    local fogaoY = fogao:getY()
    local fogaoZ = fogao:getZ()
    local celula = getCell()
    if not celula then return nil end

    local RAIO = 2
    for deslocY = -RAIO, RAIO do
        for deslocX = -RAIO, RAIO do
            local quadrado = celula:getGridSquare(fogaoX + deslocX, fogaoY + deslocY, fogaoZ)
            if quadrado then
                local objetosChao = quadrado:getWorldObjects()
                if objetosChao then
                    for idx = 0, objetosChao:size() - 1 do
                        local obj = objetosChao:get(idx)
                        if obj and obj:getItem() then
                            local tipo = obj:getItem():getFullType()
                            if IDS_BOTIJAO_CONSUMO[tipo] then
                                local dadosItem = obj:getItem():getModData()
                                if dadosItem.LKS_ConectadoAoFogaoX == fogaoX
                                    and dadosItem.LKS_ConectadoAoFogaoY == fogaoY
                                    and dadosItem.LKS_ConectadoAoFogaoZ == fogaoZ then
                                    return obj:getItem()
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

--- Tick de consumo: drena botijões conectados a fogões acesos.
local function tickConsumoPropano()
    for chave, fogao in pairs(_registroFogoesAcesos) do
        local dadosMod = fogao:getModData()

        -- Validação: fogão ainda existe e está aceso?
        if not dadosMod or dadosMod.LKS_FogaoAcesoPropano ~= true then
            _registroFogoesAcesos[chave] = nil
        elseif dadosMod.LKS_BotijaoConectado == true then
            local itemBotijao = buscarBotijaoConectado(fogao)
            if itemBotijao then
                local consumoPorMinuto = itemBotijao:getUseDelta() * MULTIPLICADOR_CONSUMO_PROPANO
                local deltaAtual = itemBotijao:getCurrentUsesFloat()
                local novoDelta = deltaAtual - consumoPorMinuto

                if novoDelta <= 0 then
                    itemBotijao:setUsedDelta(0)
                    apagarFogaoPropano(fogao)
                    _registroFogoesAcesos[chave] = nil
                else
                    itemBotijao:setUsedDelta(novoDelta)
                end
            else
                -- Botijão sumiu (pickup, destruição) — apaga fogão
                apagarFogaoPropano(fogao)
                _registroFogoesAcesos[chave] = nil
            end
        end
        -- Se não tem botijão conectado (gás encanado puro), não consome
    end
end

Events.EveryOneMinute.Add(tickConsumoPropano)

print("[LKS PATCH - LKS_Device_Cooking.lua] Carregado com sucesso!")
