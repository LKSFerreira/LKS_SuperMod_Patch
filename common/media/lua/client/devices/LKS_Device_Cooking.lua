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

local ClassificacaoSprites = require("LKS_Cooking_SpriteClassification")
local SistemaPropano = require("LKS_Cooking_PropanoSystem")

local LKS_Device_Cooking = {
    recipientesAceitos = {"stove", "microwave", "woodstove", "fireplace"},
    classesJava = {"IsoStove", "IsoMicrowave", "IsoFireplace"},
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

--- Marca o tile do fogão como energizado e acende via TimedAction vanilla.
---
--- @param fogao IsoStove O fogão a acender.
--- @param jogador IsoPlayer O jogador que está acendendo.
local function acenderFogaoPropano(fogao, jogador)
    if not fogao or not jogador then return end

    -- Diagnóstico: verifica se o fogão suporta API nativa de propane
    local temSetPropane = fogao.setPropaneTank ~= nil
    local temHasPropane = fogao.hasPropaneTank ~= nil
    local temIsPropaneBBQ = fogao.isPropaneBBQ ~= nil
    local temIsFireInteraction = fogao.isFireInteractionObject and fogao:isFireInteractionObject() or false
    print("[LKS_PROPANO_DIAG] setPropaneTank=" .. tostring(temSetPropane)
        .. " hasPropaneTank=" .. tostring(temHasPropane)
        .. " isPropaneBBQ=" .. tostring(temIsPropaneBBQ)
        .. " isFireInteractionObject=" .. tostring(temIsFireInteraction)
        .. " classe=" .. tostring(fogao:getClass()))

    -- Testa valores reais dos métodos que existem
    if temHasPropane then
        print("[LKS_PROPANO_DIAG] hasPropaneTank() = " .. tostring(fogao:hasPropaneTank()))
    end
    if temIsPropaneBBQ then
        print("[LKS_PROPANO_DIAG] isPropaneBBQ() = " .. tostring(fogao:isPropaneBBQ()))
    end

    -- Verifica setters alternativos
    print("[LKS_PROPANO_DIAG] setAttachedPropaneTank=" .. tostring(fogao.setAttachedPropaneTank ~= nil)
        .. " addFuel=" .. tostring(fogao.addFuel ~= nil)
        .. " setFuelAmount=" .. tostring(fogao.setFuelAmount ~= nil)
        .. " hasFuel=" .. tostring(fogao.hasFuel ~= nil)
        .. " getFuelAmount=" .. tostring(fogao.getFuelAmount ~= nil))

    local quadrado = fogao:getSquare()
    if not quadrado then return end

    local chunk = quadrado:getChunk()
    if not chunk then return end

    chunk:addGeneratorPos(fogao:getX(), fogao:getY(), fogao:getZ())
    if quadrado.RecalcAllWithNeighbours then
        quadrado:RecalcAllWithNeighbours(false)
    end

    fogao:getModData().LKS_FogaoAcesoPropano = true
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
    if ehFogao then
        tipoFogao = ClassificacaoSprites.obterTipoFogao(objetoEletrico)
    end

    -- Detecta fonte de energia usando o sistema unificado
    local jogador = getSpecificPlayer(jogadorNumero)
    local fonteEnergia = nil
    local temEnergia = false
    local containerInventario = objetoEletrico:getContainer()

    if ehFogao and tipoFogao then
        fonteEnergia = SistemaPropano.verificarFonteEnergia(objetoEletrico, jogador, tipoFogao)
        temEnergia = fonteEnergia.disponivel
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
    -- Precisamos ENCONTRAR essa opção existente para sequestrar seu submenu,
    -- em vez de criar um duplicado.
    --
    -- A busca é feita por nome exato (`opcao.name == nomeObjetoTraduzido`) e
    -- verificando se a opção possui um submenu vinculado (`.subOption` preenchido).
    -- =========================================================================
    local opcaoVanillaEncontrada = nil
    local submenuVanilla = nil

    for _, opcao in ipairs(menuContexto.options) do
        if opcao.name == nomeObjetoTraduzido and opcao.subOption then
            opcaoVanillaEncontrada = opcao
            submenuVanilla = menuContexto:getSubMenu(opcao.subOption)
            break
        end
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
        -- Sequestro: reutiliza o submenu vanilla existente
        submenu = submenuVanilla
        opcaoMenuPai = opcaoVanillaEncontrada
        -- NÃO sobrescreve iconTexture: vanilla já define o sprite correto do objeto
    else
        -- Fallback: cria submenu próprio (caso o vanilla não tenha criado um)
        opcaoMenuPai = menuContexto:addOptionOnTop(nomeObjetoTraduzido)
        submenu = ISContextMenu:getNew(menuContexto)
        menuContexto:addSubMenu(opcaoMenuPai, submenu)

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
    -- PASSO 3: REMOVER OPÇÃO VANILLA DE LIGAR/DESLIGAR DO SUBMENU
    -- =========================================================================
    -- Remove apenas a opção de toggle do submenu vanilla (que substituiremos
    -- pela nossa versão aprimorada com tooltips). A opção "Configurações" e
    -- qualquer outra permanecem intactas.
    --
    -- Usamos `removeOptionByName` que é o método nativo do ISContextMenu para
    -- remoção segura por nome exato — sem necessidade de manipulação manual
    -- de índices da tabela `options`.
    -- =========================================================================
    local textoLigarVanilla = getText("ContextMenu_TurnOn")
    local textoDesligarVanilla = getText("ContextMenu_TurnOff")

    if submenu and submenu.removeOptionByName then
        pcall(function() submenu:removeOptionByName(textoLigarVanilla) end)
        pcall(function() submenu:removeOptionByName(textoDesligarVanilla) end)
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
        iconeDesligado = "media/ui/LKS_Menu_Gas_Off.png"
    elseif tipoFogao == "antigo" then
        verboAcender = getText("IGUI_LKS_Acender") or "Acender"
        verboApagar = getText("IGUI_LKS_Apagar") or "Apagar"
        iconeDesligado = "media/ui/LKS_Menu_Fuel_Off.png"
    else
        verboAcender = getText("ContextMenu_TurnOn") or "Ligar"
        verboApagar = getText("ContextMenu_TurnOff") or "Desligar"
        iconeDesligado = "media/ui/LKS_Menu_Electricity_Off.png"
    end

    if estaAtivo then
        -- Apagar/Desligar: comportamento diferenciado
        local opcaoApagar = submenu:addOptionOnTop(verboApagar, objetosMundo, function()
            if ehFogao and (tipoFogao == "convencional" or tipoFogao == "antigo") then
                apagarFogaoPropano(objetoEletrico)
            elseif ehFogao then
                ISWorldObjectContextMenu.onToggleStove(objetosMundo, objetoEletrico, jogadorNumero)
            elseif ehMicroondas then
                ISWorldObjectContextMenu.onToggleMicrowave(objetosMundo, objetoEletrico, jogadorNumero)
            end
        end)
        opcaoApagar.iconTexture = getTexture("media/ui/LKS_Button_Power_Off.png")

        if ehFogao then
            local tooltipInfo = ISWorldObjectContextMenu.addToolTip()
            tooltipInfo:setName(nomeObjetoTraduzido)
            local temperaturaAtual = objetoEletrico:getCurrentTemperature()
            local textoTemperatura = string.format(getText("IGUI_LKS_TemperaturaAtual") or "Temperatura Atual: %.1f°C", temperaturaAtual)
            local textoAlerta = " <RGB:1,0,0> " .. (getText("IGUI_LKS_AlertaEquipamentoAquecido") or "⚠️ CUIDADO: Equipamento aquecido!")
            tooltipInfo.description = textoTemperatura .. " <LINE> " .. textoAlerta
            opcaoApagar.toolTip = tooltipInfo
        end
    else
        if temEnergia then
            if (tipoFogao == "convencional" or tipoFogao == "antigo") then
                -- Fogão a combustão: submenu com fontes de calor do inventário
                local fontesCalor = buscarFontesCalorInventario(jogador)

                if #fontesCalor > 0 then
                    local opcaoAcender = submenu:addOptionOnTop(verboAcender, objetosMundo, nil)
                    opcaoAcender.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")
                    local submenuIgnicao = ISContextMenu:getNew(submenu)
                    submenu:addSubMenu(opcaoAcender, submenuIgnicao)

                    -- Para fogão antigo, busca tinder uma vez (evita repetição no loop)
                    local materiaisCombustao = nil
                    if tipoFogao == "antigo" then
                        materiaisCombustao = buscarMateriaisCombustao(jogador)
                        -- Tooltip no parent quando não há material inflamável
                        if #materiaisCombustao == 0 then
                            local tooltipPaiSemTinder = ISWorldObjectContextMenu.addToolTip()
                            tooltipPaiSemTinder.description = getText("IGUI_LKS_RequerMaterialInflamavel") or "Requer material inflamável (papel, pano, álcool) para iniciar a combustão."
                            opcaoAcender.toolTip = tooltipPaiSemTinder
                        end
                    end

                    for _, fonteCalorItem in ipairs(fontesCalor) do
                        if tipoFogao == "antigo" then
                            -- Fogão antigo: fonte de calor > submenu de materiais inflamáveis
                            if #materiaisCombustao > 0 then
                                local opcaoFonte = submenuIgnicao:addOption(
                                    fonteCalorItem:getDisplayName(), objetosMundo, nil)
                                opcaoFonte.iconTexture = fonteCalorItem:getTex()
                                local submenuTinder = ISContextMenu:getNew(submenuIgnicao)
                                submenuIgnicao:addSubMenu(opcaoFonte, submenuTinder)

                                for _, materialItem in ipairs(materiaisCombustao) do
                                    local opcaoMaterial = submenuTinder:addOption(
                                        materialItem:getDisplayName(), objetosMundo, function()
                                            acenderFogaoPropano(objetoEletrico, jogador)
                                        end)
                                    opcaoMaterial.iconTexture = materialItem:getTex()
                                end
                            else
                                -- Tem fonte de calor mas sem material inflamável
                                local opcaoFonte = submenuIgnicao:addOption(
                                    fonteCalorItem:getDisplayName(), objetosMundo, nil)
                                opcaoFonte.iconTexture = fonteCalorItem:getTex()
                                opcaoFonte.notAvailable = true
                                local tooltipSemTinder = ISWorldObjectContextMenu.addToolTip()
                                tooltipSemTinder.description = getText("IGUI_LKS_RequerMaterialInflamavel") or "Requer material inflamável (papel, pano, álcool) para iniciar a combustão."
                                opcaoFonte.toolTip = tooltipSemTinder
                            end
                        else
                            -- Fogão convencional: fonte de calor acende direto (propano é volátil)
                            local opcaoFonte = submenuIgnicao:addOption(
                                fonteCalorItem:getDisplayName(), objetosMundo, function()
                                    acenderFogaoPropano(objetoEletrico, jogador)
                                end)
                            opcaoFonte.iconTexture = fonteCalorItem:getTex()
                        end
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
            elseif tipoFogao == "antigo" then
                tooltipErro.description = getText("IGUI_LKS_RequerCombustivelSolido") or "Requer combustível sólido (lenha, tábuas) no interior."
            elseif tipoFogao == "inducao" then
                tooltipErro.description = getText("IGUI_LKS_RequerEletricidade") or "Requer eletricidade (rede elétrica ou gerador)."
            else
                tooltipErro.description = getText("IGUI_LKS_RequerEnergiaProxima") or "Requer uma fonte de energia próxima."
            end

            opcaoSemEnergia.toolTip = tooltipErro
        end
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

print("[LKS PATCH - LKS_Device_Cooking.lua] Carregado com sucesso!")
