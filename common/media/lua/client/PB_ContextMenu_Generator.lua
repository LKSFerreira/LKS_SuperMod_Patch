-- ============================================================================
-- ARQUIVO: PB_ContextMenu_Generator.lua
-- MOD ORIGINAL: Generator Powered Buildings (ID Workshop: 3597471949)
-- EXTENSÃO: LKS SuperMod Patch (Build 42)
-- OBJETIVO: Menu de contexto do gerador (opções de clique direito no mundo)
--           Tradução completa de engenharia e padronização de prefixos PB_
-- AUTOR: LKSFERREIRA
-- DATA DE ATUALIZAÇÃO: 11/06/2026
-- ============================================================================

if not PoweredBuildings then
    print("[LKS PATCH - PB_ContextMenu_Generator.lua] namespace PoweredBuildings não encontrado - pulando carregamento do módulo")
    return
end

print("[LKS PATCH - PB_ContextMenu_Generator.lua] Carregando Menu de Contexto do Gerador com padronização de ícones...")

-- Registro do Módulo
PoweredBuildings.RegisterModule("PB_ContextMenu_Generator")

-- Criação do Namespace local
PoweredBuildings.ContextMenu = PoweredBuildings.ContextMenu or {}
PoweredBuildings.ContextMenu.Generator = {}

local ContextMenu = PoweredBuildings.ContextMenu.Generator

-- ============================================================================
-- ⚙️ CONFIGURAÇÕES DE ASSETS E TEXTURAS (PADRÃO DE NOMENCLATURA PB)
-- ============================================================================
local TEX_ITEM_GEN     = "media/textures/Item_Generator.png"
local TEX_PWR_ON       = "media/ui/PB_Pwr_On.png"
local TEX_PWR_OFF      = "media/ui/PB_Pwr_Off.png"
local TEX_TAKE_GEN     = "media/ui/PB_Take_Gen.png"
local TEX_CONNECT      = "media/ui/PB_Connect.png"
local TEX_DISCONNECT   = "media/ui/PB_Disconnect.png"
local TEX_GEN_INFO     = "media/ui/PB_Gen_Info.png"
local TEX_HOUSE_ELE    = "media/ui/PB_House_Eletricity.png"
local TEX_HOUSE_ELE_OFF= "media/ui/PB_House_Eletricity_Off.png"
local TEX_REP_GEN      = "media/ui/PB_Rep_Gen.png"
local TEX_GAS_REFUEL   = "media/ui/vehicles/PB_Gas_Refuel.png"
local TEX_GAS_REFUEL_AL= "media/ui/vehicles/PB_Gas_Refuel_All.png"

-- Cache local para busca de ícones baseados no sprite do gerador colocado no mundo
local _genIconCache = {}
local _genIconFallback = nil

local function GetGeneratorIcon(gen)
    _genIconFallback = _genIconFallback or getTexture(TEX_ITEM_GEN)
    if not gen then return _genIconFallback end
    local spriteName = gen.getSpriteName and gen:getSpriteName()
    if not spriteName and gen.getSprite and gen:getSprite() then
        spriteName = gen:getSprite():getName()
    end
    if not spriteName then return _genIconFallback end
    if _genIconCache[spriteName] ~= nil then return _genIconCache[spriteName] end
    local tex = getTexture("media/textures/" .. spriteName .. ".png") or _genIconFallback
    _genIconCache[spriteName] = tex
    return tex
end

-- ============================================================================
-- 🛠️ FUNÇÕES AUXILIARES DE VERIFICAÇÃO
-- ============================================================================

-- Encontra o objeto gerador nos objetos clicados no mundo
local function FindGenerator(worldobjects)
    if not worldobjects then return nil end
    for _, obj in ipairs(worldobjects) do
        if instanceof(obj, "IsoGenerator") then
            return obj
        end
    end
    return nil
end

-- Verifica se o gerador está operando no modo de construção (conectado a um prédio)
local function IsGeneratorInBuildingMode(generator)
    if not generator then return false end
    local md = generator:getModData()
    return md and md.Gen_BuildingPoolID ~= nil
end

-- Retorna a porcentagem de combustível do gerador
local function GetFuelPercentage(generator)
    if not generator then return 0 end
    local fuel = generator:getFuel()
    local maxFuel = generator:getMaxFuel()
    if maxFuel <= 0 then return 0 end
    return math.floor((fuel / maxFuel) * 100)
end

-- Retorna a porcentagem de condição mecânica do gerador
local function GetConditionPercentage(generator)
    if not generator then return 0 end
    return math.floor(generator:getCondition())
end

-- Verifica se o gerador possui os requisitos mínimos para ser ligado
local function CanActivateGenerator(generator)
    if not generator then return false end
    if generator:isActivated() then return false end
    if generator:getFuel() <= 0 then return false end
    if generator:getCondition() <= 0 then return false end
    return true
end

-- Verifica se o jogador está perto o suficiente para interagir com o gerador
local function CanReachGenerator(player, generator)
    if not player or not generator then return false end
    local playerSquare = player:getSquare()
    local generatorSquare = generator:getSquare()
    if not playerSquare or not generatorSquare then return false end
    
    local dx = math.abs(playerSquare:getX() - generatorSquare:getX())
    local dy = math.abs(playerSquare:getY() - generatorSquare:getY())
    return dx <= 1 and dy <= 1
end

-- ============================================================================
-- ⚡ GATILHOS DE AÇÕES DO MENU DE CONTEXTO
-- ============================================================================

-- Ação: Ligar o Gerador
function ContextMenu.OnTurnOn(worldobjects, player)
    if not player or not worldobjects then return end
    local generator = FindGenerator(worldobjects)
    if not generator then return end
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    -- Caminha até o gerador se estiver longe
    if not CanReachGenerator(playerObj, generator) then
        if luautils.walkAdj then
            luautils.walkAdj(playerObj, generator:getSquare())
        end
    end
    
    -- Adiciona a ação na fila cronometrada do jogador
    if PoweredBuildings.Actions and PoweredBuildings.Actions.ActivateGenerator then
        ISTimedActionQueue.add(PoweredBuildings.Actions.ActivateGenerator:new(playerObj, generator, true))
    else
        print("[LKS PATCH - PB_ContextMenu_Generator.lua] ERRO: PoweredBuildings.Actions.ActivateGenerator não encontrado!")
    end
end

-- Ação: Desligar o Gerador
function ContextMenu.OnTurnOff(worldobjects, player)
    if not player or not worldobjects then return end
    local generator = FindGenerator(worldobjects)
    if not generator then return end
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    -- Caminha até o gerador se estiver longe
    if not CanReachGenerator(playerObj, generator) then
        if luautils.walkAdj then
            luautils.walkAdj(playerObj, generator:getSquare())
        end
    end
    
    -- Adiciona a ação na fila cronometrada do jogador
    if PoweredBuildings.Actions and PoweredBuildings.Actions.ActivateGenerator then
        ISTimedActionQueue.add(PoweredBuildings.Actions.ActivateGenerator:new(playerObj, generator, false))
    else
        print("[LKS PATCH - PB_ContextMenu_Generator.lua] ERRO: PoweredBuildings.Actions.ActivateGenerator não encontrado!")
    end
end

-- Ação: Conectar Gerador à Rede da Construção
function ContextMenu.OnConnectBuilding(worldobjects, player)
    if not player or not worldobjects then return end
    local generator = FindGenerator(worldobjects)
    if not generator then return end
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    if not CanReachGenerator(playerObj, generator) then
        if luautils.walkAdj then
            luautils.walkAdj(playerObj, generator:getSquare())
        end
    end
    
    if PoweredBuildings.Actions and PoweredBuildings.Actions.ConnectBuilding then
        ISTimedActionQueue.add(PoweredBuildings.Actions.ConnectBuilding:new(playerObj, generator))
    else
        print("[LKS PATCH - PB_ContextMenu_Generator.lua] ERRO: PoweredBuildings.Actions.ConnectBuilding não encontrado!")
    end
end

-- Ação: Desconectar Gerador da Rede da Construção
function ContextMenu.OnDisconnectBuilding(worldobjects, player)
    if not player or not worldobjects then return end
    local generator = FindGenerator(worldobjects)
    if not generator then return end
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    if not CanReachGenerator(playerObj, generator) then
        if luautils.walkAdj then
            luautils.walkAdj(playerObj, generator:getSquare())
        end
    end
    
    if PoweredBuildings.Actions and PoweredBuildings.Actions.DisconnectBuilding then
        ISTimedActionQueue.add(PoweredBuildings.Actions.DisconnectBuilding:new(playerObj, generator))
    else
        print("[LKS PATCH - PB_ContextMenu_Generator.lua] ERRO: PoweredBuildings.Actions.DisconnectBuilding não encontrado!")
    end
end

-- ============================================================================
-- 🧭 CONSTRUTOR PRINCIPAL DO MENU DE CONTEXTO
-- ============================================================================

function ContextMenu.Build(player, context, worldobjects, test)
    if not player or not context or not worldobjects then return end
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    local generator = FindGenerator(worldobjects)
    if not generator then return end
    if test then return true end -- Modo de teste rápido do jogo para validar clique
    
    local isActivated = generator:isActivated()
    local isInBuildingMode = IsGeneratorInBuildingMode(generator)
    local fuelPercent = GetFuelPercentage(generator)
    local conditionPercent = GetConditionPercentage(generator)
    local canActivate = CanActivateGenerator(generator)
    
    -- Procura se o submenu padrão "Gerador" do próprio jogo já existe no clique
    local generatorSubmenu = nil
    local generatorOption = nil
    
    for _, option in ipairs(context.options) do
        if option.name == getText("ContextMenu_Generator") then
            generatorOption = option
            generatorSubmenu = context:getSubMenu(generatorOption.subOption)
            break
        end
    end
    
    -- Se o menu não existir (ex: gerador desligado da tomada vanilla), cria um novo
    if not generatorSubmenu then
        generatorSubmenu = context:getNew(context)
        generatorOption = context:addOption(getText("ContextMenu_Generator"), worldobjects, nil, generatorSubmenu)
    end
   
    -- ========================================================================
    -- MODO: GERADOR EM REDE DE CONSTRUÇÃO (MODDED)
    -- ========================================================================
    if isInBuildingMode then
        -- Remove as opções vanilla do jogo para evitar conflitos de script
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_GeneratorPlug")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_GeneratorTake")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_Turn_Off")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("IGUI_Turn_Off")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_Turn_On")) end)
        
        -- Opção: Desligar
        if isActivated then
            local turnOffOption = generatorSubmenu:addOption(
                getText("ContextMenu_Turn_Off") or "Desligar",
                worldobjects,
                ContextMenu.OnTurnOff,
                player
            )
            turnOffOption.iconTexture = getTexture(TEX_PWR_OFF)
        -- Opção: Ligar
        else
            local turnOnOption = generatorSubmenu:addOption(
                getText("ContextMenu_Turn_On") or "Ligar",
                worldobjects,
                ContextMenu.OnTurnOn,
                player
            )
            turnOnOption.iconTexture = getTexture(TEX_PWR_ON)
            
            -- Bloqueia o botão se o maquinário estiver quebrado ou sem combustível
            if not canActivate then
                turnOnOption.notAvailable = true
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                if fuelPercent <= 0 then
                    tooltip:setName(getText("IGUI_Generator_NoFuel") or "Sem Combustível")
                elseif conditionPercent <= 0 then
                    tooltip:setName(getText("IGUI_Generator_Broken") or "Gerador Quebrado")
                else
                    tooltip:setName(getText("IGUI_Generator_CannotActivate") or "Não é Possível Ativar")
                end
                turnOnOption.toolTip = tooltip
            end
        end
        
        -- Opção: Desconectar do Prédio
        local disconnectOption = generatorSubmenu:addOption(
            getText("IGUI_DisconnectFromBuilding") or "Desconectar da Construção",
            worldobjects,
            ContextMenu.OnDisconnectBuilding,
            player
        )
        disconnectOption.iconTexture = getTexture(TEX_HOUSE_ELE_OFF)

        -- Opção: Informações de Energia da Construção (HUD Principal)
        local infoOption = generatorSubmenu:addOption(
            getText("IGUI_BuildingPowerInfoMenu") or "Informações de Energia",
            worldobjects,
            function(worldobjectsArg, playerArg)
                local gen = FindGenerator(worldobjectsArg)
                if not gen then return end
                local pObj = getSpecificPlayer(playerArg)
                if not pObj then return end
                if PoweredBuildings.Actions and PoweredBuildings.Actions.OpenInfoWindow then
                    ISTimedActionQueue.add(PoweredBuildings.Actions.OpenInfoWindow:new(pObj, gen))
                end
            end,
            player
        )
        infoOption.iconTexture = getTexture(TEX_HOUSE_ELE)

    -- ========================================================================
    -- MODO: GERADOR ISOLADO / INDEPENDENTE (VANILLA)
    -- ========================================================================
    else
        local square = generator:getSquare()
        local nearBuilding = false
        
        if square then
            local building = square:getBuilding()
            if building then nearBuilding = true end
            
            if not nearBuilding and square.haveBuilding and square:haveBuilding() then
                nearBuilding = true
            end
            
            -- Varredura de segurança nos quadrados adjacentes para validação de paredes
            if not nearBuilding then
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local adjSquare = getCell():getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
                            if adjSquare then
                                if adjSquare:getBuilding() or (adjSquare.haveBuilding and adjSquare:haveBuilding()) then
                                    nearBuilding = true
                                    break
                                end
                            end
                        end
                    end
                    if nearBuilding then break end
                end
            end
        end
        
        -- Oculta a opção de conectar caso o gerador já esteja plugado no modo vanilla convencional
        local vanillaUnplugExists = false
        local unplugName = getText("ContextMenu_GeneratorUnplug")
        if generatorSubmenu and generatorSubmenu.options then
            for _, opt in ipairs(generatorSubmenu.options) do
                if opt.name == unplugName then
                    vanillaUnplugExists = true
                    break
                end
            end
        end

        if not vanillaUnplugExists then
            local connectOption = generatorSubmenu:addOption(
                getText("IGUI_ConnectToBuilding") or "Conectar à Construção",
                worldobjects,
                ContextMenu.OnConnectBuilding,
                player
            )
            connectOption.iconTexture = getTexture(TEX_HOUSE_ELE)

            -- Validação de Requisito Técnico: Eletricidade Nível 3 + Receita aprendida
            local playerObj = getSpecificPlayer(player)
            local knowsRecipe = playerObj:isRecipeActuallyKnown("Generator")
            if not knowsRecipe then
                connectOption.notAvailable = true
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                tooltip:setName(getText("IGUI_ConnectToBuilding") or "Conectar à Construção")
                tooltip.description = getText("IGUI_ConnectRequiresKnowledge") or "Requer a receita de Gerador (Eletricidade nível 3)"
                connectOption.toolTip = tooltip
            -- Validação de Posicionamento: O gerador precisa estar encostado na estrutura
            elseif not nearBuilding then
                connectOption.notAvailable = true
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                tooltip:setName(getText("IGUI_NoBuildingNearby") or "Nenhuma construção próxima")
                tooltip.description = getText("IGUI_NoBuildingNearby_Desc") or "O gerador deve ser colocado ao lado de uma construção com paredes"
                connectOption.toolTip = tooltip
            end
        end
    end

    -- ========================================================================
    -- MAPEAMENTO E INJEÇÃO AUTOMÁTICA DE ÍCONES (SISTEMA FILTRADO)
    -- ========================================================================
    local iconMap = {
        [getText("ContextMenu_GeneratorTake")    or "Pegar Gerador"]                    = TEX_TAKE_GEN,
        [getText("ContextMenu_GeneratorPlug")    or "Conectar Gerador"]                 = TEX_CONNECT,
        [getText("ContextMenu_GeneratorUnplug")  or "Desconectar Gerador"]              = TEX_DISCONNECT,
        [getText("ContextMenu_GeneratorInfo")    or "Informações do Gerador"]           = TEX_GEN_INFO,
        [getText("ContextMenu_Examine")          or "Examinar"]                         = TEX_GEN_INFO,
        [getText("IGUI_BuildingPowerInfoMenu")   or "Informações de Energia da Construção"] = TEX_HOUSE_ELE,
        [getText("ContextMenu_Turn_On")          or "Ligar"]                            = TEX_PWR_ON,
        [getText("IGUI_Turn_On")                 or "Ligar"]                            = TEX_PWR_ON,
        [getText("ContextMenu_Turn_Off")         or "Desligar"]                         = TEX_PWR_OFF,
        [getText("IGUI_Turn_Off")                or "Desligar"]                         = TEX_PWR_OFF,
        [getText("ContextMenu_Repair")           or "Reparar"]                          = TEX_REP_GEN,
        [getText("ContextMenu_GeneratorAddFuel") or "Adicionar Combustível"]            = TEX_GAS_REFUEL,
        [getText("ContextMenu_AddAll")           or "Adicionar Tudo"]                   = TEX_GAS_REFUEL_AL,
        [getText("ContextMenu_GeneratorFix")     or "Reparar Gerador"]                = TEX_REP_GEN,
    }

    local function applyIcons(optList)
        if not optList then return end
        for _, opt in ipairs(optList) do
            if not opt.iconTexture and opt.name and iconMap[opt.name] then
                opt.iconTexture = getTexture(iconMap[opt.name])
            end
        end
    end

    -- Aplica os ícones tanto no submenu modded quanto nas opções injetadas no menu global
    if generatorSubmenu then applyIcons(generatorSubmenu.options) end
    applyIcons(context.options)
end

-- ============================================================================
-- REGISTRO DE EVENTOS GLOBAIS DO SISTEMA
-- ============================================================================
Events.OnFillWorldObjectContextMenu.Add(ContextMenu.Build)

print("[LKS PATCH - PB_ContextMenu_Generator.lua] Carregado com sucesso!")