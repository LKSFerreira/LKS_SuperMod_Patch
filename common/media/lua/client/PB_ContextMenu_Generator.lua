-- ============================================================================
-- 💖 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado como parte do LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3097103233) por sua fantástica contribuição para a comunidade!
-- ============================================================================

-- ============================================================================
-- ARQUIVO: PB_ContextMenu_Generator.lua
-- MOD ORIGINAL: Generator Powered Buildings (ID Workshop: 3597471949)
-- EXTENSÃO: LKS SuperMod Patch (Build 42)
-- OBJETIVO: Menu de contexto do gerador (opções de clique direito no mundo)
--           Tradução completa de engenharia e padronização de prefixos PB_
-- AUTOR: LKSFERREIRA
-- DATA DE ATUALIZAÇÃO: 12/06/2026
-- ============================================================================

if not PoweredBuildings then
    print(
    "[LKS PATCH - PB_ContextMenu_Generator.lua] namespace PoweredBuildings não encontrado - pulando carregamento do módulo")
    return
end

print("[LKS PATCH - PB_ContextMenu_Generator.lua] Carregando Menu de Contexto do Gerador com padronização de ícones...")

PoweredBuildings.RegisterModule("PB_ContextMenu_Generator")

PoweredBuildings.ContextMenu           = PoweredBuildings.ContextMenu or {}
PoweredBuildings.ContextMenu.Generator = {}

local ContextMenu                      = PoweredBuildings.ContextMenu.Generator

-- ============================================================================
-- ⚙️ CONFIGURAÇÕES DE ASSETS E TEXTURAS (PADRÃO DE NOMENCLATURA PB)
-- ============================================================================
local TEX_ITEM_GEN                     = "media/textures/Item_Generator.png"
local TEX_PWR_ON                       = "media/ui/LKS_Pwr_On.png"
local TEX_PWR_OFF                      = "media/ui/LKS_Pwr_Off.png"
local TEX_TAKE_GEN                     = "media/ui/LKS_Take_Gen.png"
local TEX_CONNECT                      = "media/ui/LKS_Connect.png"
local TEX_DISCONNECT                   = "media/ui/LKS_Disconnect.png"
local TEX_GEN_INFO                     = "media/ui/LKS_Gen_Info.png"
local TEX_HOUSE_ELE                    = "media/ui/LKS_House_Eletricity.png"
local TEX_HOUSE_ELE_OFF                = "media/ui/LKS_House_Eletricity_Off.png"
local TEX_REP_GEN                      = "media/ui/LKS_Rep_Gen.png"
local TEX_GAS_REFUEL                   = "media/ui/LKS_Gas_Refuel.png"
local TEX_GAS_REFUEL_AL                = "media/ui/LKS_Gas_Refuel_All.png"

local _genIconCache                    = {}
local _genIconFallback                 = nil

local function GetGeneratorIcon(gen)
    _genIconFallback = _genIconFallback or getTexture(TEX_ITEM_GEN)
    if not gen then return _genIconFallback end

    local spriteName = gen.getSpriteName and gen:getSpriteName()
    if not spriteName and gen.getSprite and gen:getSprite() then
        spriteName = gen:getSprite():getName()
    end
    if not spriteName then return _genIconFallback end

    if _genIconCache[spriteName] ~= nil then
        return _genIconCache[spriteName]
    end

    local tex = getTexture("media/textures/" .. spriteName .. ".png") or _genIconFallback
    _genIconCache[spriteName] = tex
    return tex
end

--- Verifica se há alguma construção válida em um raio específico ao redor de um quadrado.
---
--- **Exemplo:**
--- ```lua
--- local temPredio = temConstrucaoNoRaio(quadrado, 20)
--- ```
---
--- @param quadrado IsoGridSquare O quadrado de grade central (gerador).
--- @param raio number O raio máximo de busca em tiles.
--- @return boolean Retorna true se encontrar algum quadrado pertencente a uma construção.
local function temConstrucaoNoRaio(quadrado, raio)
    if not quadrado then return false end
    local celulaMundo = getCell()
    if not celulaMundo then return false end

    local coordenadaX = quadrado:getX()
    local coordenadaY = quadrado:getY()
    local coordenadaZ = quadrado:getZ()
    for deslocamentoY = -raio, raio do
        for deslocamentoX = -raio, raio do
            local quadradoAlvo = celulaMundo:getGridSquare(coordenadaX + deslocamentoX, coordenadaY + deslocamentoY, coordenadaZ)
            if quadradoAlvo then
                if quadradoAlvo:getBuilding() or (quadradoAlvo.haveBuilding and quadradoAlvo:haveBuilding()) then
                    return true
                end
            end
        end
    end
    return false
end

local function FindGenerator(worldobjects)
    if not worldobjects then return nil end
    for _, obj in ipairs(worldobjects) do
        if instanceof(obj, "IsoGenerator") then
            return obj
        end
    end
    return nil
end

local function IsGeneratorInBuildingMode(generator)
    if not generator then return false end
    local md = generator:getModData()
    return md and md.Gen_BuildingPoolID ~= nil
end

local function GetFuelPercentage(generator)
    if not generator then return 0 end
    local fuel = generator:getFuel()
    local maxFuel = generator:getMaxFuel()
    if maxFuel <= 0 then return 0 end
    return math.floor((fuel / maxFuel) * 100)
end

local function GetConditionPercentage(generator)
    if not generator then return 0 end
    return math.floor(generator:getCondition())
end

local function CanActivateGenerator(generator)
    if not generator then return false end
    if generator:isActivated() then return false end
    if generator:getFuel() <= 0 then return false end
    if generator:getCondition() <= 0 then return false end
    return true
end

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
-- 🔎 AUXILIARES DE ÍCONE DE RECIPIENTE
-- ============================================================================

local function IsInventoryItem(val)
    if not val then return false end
    local ok, res = pcall(instanceof, val, "InventoryItem")
    return ok and res
end

local function ExtractContainerItemFromOption(opt)
    if not opt then return nil end

    if IsInventoryItem(opt.itemForTexture) then
        return opt.itemForTexture
    end

    -- 1. Verifica campos diretos do opt que sejam InventoryItem (como param1, param2, item, etc.)
    for k, v in pairs(opt) do
        if IsInventoryItem(v) then
            return v
        end
    end

    -- 2. Verifica tabelas que possam conter InventoryItems (listas de itens para "Adicionar Todos")
    for k, v in pairs(opt) do
        if type(v) == "table" and not IsInventoryItem(v) then
            if k ~= "subOption" and k ~= "parent" and k ~= "target" then
                for _, subVal in pairs(v) do
                    if IsInventoryItem(subVal) then
                        return subVal
                    end
                end
            end
        end
    end

    return nil
end

-- ============================================================================
-- ⚡ GATILHOS DE AÇÕES DO MENU DE CONTEXTO
-- ============================================================================

function ContextMenu.OnTurnOn(worldobjects, player)
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

    if PoweredBuildings.Actions and PoweredBuildings.Actions.ActivateGenerator then
        ISTimedActionQueue.add(PoweredBuildings.Actions.ActivateGenerator:new(playerObj, generator, true))
    else
        print(
        "[LKS PATCH - PB_ContextMenu_Generator.lua] ERRO: PoweredBuildings.Actions.ActivateGenerator não encontrado!")
    end
end

function ContextMenu.OnTurnOff(worldobjects, player)
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

    if PoweredBuildings.Actions and PoweredBuildings.Actions.ActivateGenerator then
        ISTimedActionQueue.add(PoweredBuildings.Actions.ActivateGenerator:new(playerObj, generator, false))
    else
        print(
        "[LKS PATCH - PB_ContextMenu_Generator.lua] ERRO: PoweredBuildings.Actions.ActivateGenerator não encontrado!")
    end
end

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
        print(
        "[LKS PATCH - PB_ContextMenu_Generator.lua] ERRO: PoweredBuildings.Actions.ConnectBuilding não encontrado!")
    end
end

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
        print(
        "[LKS PATCH - PB_ContextMenu_Generator.lua] ERRO: PoweredBuildings.Actions.DisconnectBuilding não encontrado!")
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
    if test then return true end

    local isActivated = generator:isActivated()
    local isInBuildingMode = IsGeneratorInBuildingMode(generator)
    local fuelPercent = GetFuelPercentage(generator)
    local conditionPercent = GetConditionPercentage(generator)
    local canActivate = CanActivateGenerator(generator)

    local generatorSubmenu = nil
    local generatorOption = nil

    for _, option in ipairs(context.options) do
        if option.name == getText("ContextMenu_Generator") then
            generatorOption = option
            generatorSubmenu = context:getSubMenu(generatorOption.subOption)
            break
        end
    end

    if not generatorSubmenu then
        generatorSubmenu = context:getNew(context)
        generatorOption = context:addOption(getText("ContextMenu_Generator"), worldobjects, nil, generatorSubmenu)
    end

    if generatorOption and not generatorOption.iconTexture then
        generatorOption.iconTexture = GetGeneratorIcon(generator)
    end

    if isInBuildingMode then
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_GeneratorPlug")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_GeneratorTake")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_Turn_Off")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("IGUI_Turn_Off")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_Turn_On")) end)

        if isActivated then
            local turnOffOption = generatorSubmenu:addOption(
                getText("ContextMenu_Turn_Off") or "Desligar",
                worldobjects,
                ContextMenu.OnTurnOff,
                player
            )
            turnOffOption.iconTexture = getTexture(TEX_PWR_OFF)
        else
            local turnOnOption = generatorSubmenu:addOption(
                getText("ContextMenu_Turn_On") or "Ligar",
                worldobjects,
                ContextMenu.OnTurnOn,
                player
            )
            turnOnOption.iconTexture = getTexture(TEX_PWR_ON)

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

        local disconnectOption = generatorSubmenu:addOption(
            getText("IGUI_DisconnectFromBuilding") or "Desconectar da Construção",
            worldobjects,
            ContextMenu.OnDisconnectBuilding,
            player
        )
        disconnectOption.iconTexture = getTexture(TEX_HOUSE_ELE_OFF)

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
    else
        local square = generator:getSquare()
        local nearBuilding = false

        if square then
            local building = square:getBuilding()
            if building then nearBuilding = true end

            if not nearBuilding and square.haveBuilding and square:haveBuilding() then
                nearBuilding = true
            end

            if not nearBuilding then
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local adjSquare = getCell():getGridSquare(square:getX() + dx, square:getY() + dy,
                                square:getZ())
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

            local playerObj2 = getSpecificPlayer(player)
            if not playerObj2:isRecipeActuallyKnown("Generator") then
                connectOption.notAvailable = true
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                tooltip:setName(getText("IGUI_ConnectToBuilding") or "Conectar à Construção")
                tooltip.description = getText("IGUI_ConnectRequiresKnowledge") or
                    "Requer a receita de Gerador ou Elétrica Nível 3)"
                connectOption.toolTip = tooltip
            elseif not nearBuilding then
                connectOption.notAvailable = true
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                tooltip:setName(getText("IGUI_NoBuildingNearby") or "Nenhuma construção próxima")
                tooltip.description = getText("IGUI_NoBuildingNearby_Desc") or
                    "O gerador deve ser colocado ao lado de uma construção com paredes"
                connectOption.toolTip = tooltip
            end

            -- Se existir alguma construção no raio de 20x20, remove a opção vanilla "Conectar Gerador"
            if square and temConstrucaoNoRaio(square, 20) then
                pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_GeneratorPlug")) end)
            end
        end
    end

    -- ============================================================================
    -- MAPEAMENTO DE ÍCONES
    -- ============================================================================
    local iconMap = {
        [getText("ContextMenu_GeneratorTake")] = TEX_TAKE_GEN,
        ["Pegar Gerador"] = TEX_TAKE_GEN,

        [getText("ContextMenu_GeneratorPlug")] = TEX_CONNECT,
        ["Conectar Gerador"] = TEX_CONNECT,

        [getText("ContextMenu_GeneratorUnplug")] = TEX_DISCONNECT,
        ["Desconectar Gerador"] = TEX_DISCONNECT,

        [getText("ContextMenu_GeneratorInfo")] = TEX_GEN_INFO,
        ["Informações do Gerador"] = TEX_GEN_INFO,
        [getText("ContextMenu_Examine")] = TEX_GEN_INFO,
        ["Examinar"] = TEX_GEN_INFO,

        [getText("IGUI_BuildingPowerInfoMenu")] = TEX_HOUSE_ELE,
        ["Informações de Energia"] = TEX_HOUSE_ELE,
        ["Informações Elétricas da Construção"] = TEX_HOUSE_ELE,

        [getText("ContextMenu_Turn_On")] = TEX_PWR_ON,
        [getText("IGUI_Turn_On")] = TEX_PWR_ON,
        ["Ligar"] = TEX_PWR_ON,

        [getText("ContextMenu_Turn_Off")] = TEX_PWR_OFF,
        [getText("IGUI_Turn_Off")] = TEX_PWR_OFF,
        ["Desligar"] = TEX_PWR_OFF,

        [getText("ContextMenu_Repair")] = TEX_REP_GEN,
        [getText("ContextMenu_GeneratorFix")] = TEX_REP_GEN,
        ["Reparar"] = TEX_REP_GEN,
        ["Reparar Gerador"] = TEX_REP_GEN,

        [getText("ContextMenu_AddFuel")] = TEX_GAS_REFUEL,
        [getText("ContextMenu_GeneratorAddFuel")] = TEX_GAS_REFUEL,
        ["Colocar Combustível"] = TEX_GAS_REFUEL,
        ["Adicionar Combustível"] = TEX_GAS_REFUEL,

        [getText("ContextMenu_AddAll")] = TEX_GAS_REFUEL_AL,
        ["Adicionar Tudo"] = TEX_GAS_REFUEL_AL,
    }

    local function isAddOne(name)
        if not name then return false end
        local nameLower = string.lower(name)
        return nameLower == string.lower(getText("ContextMenu_AddOne") or "")
            or nameLower == "adicionar um"
            or nameLower == "adicionar uma"
    end

    local function isAddAll(name)
        if not name then return false end
        local nameLower = string.lower(name)
        return nameLower == string.lower(getText("ContextMenu_AddAll") or "")
            or nameLower == "adicionar todos"
            or nameLower == "adicionar tudo"
    end

    local function getSubMenuFromOption(menuObj, opt, rootContext)
        if not menuObj or not opt or not opt.subOption then
            return nil
        end

        if menuObj.getSubMenu then
            local ok, sub = pcall(menuObj.getSubMenu, menuObj, opt.subOption)
            if ok and sub then
                return sub
            end
        end

        if rootContext and rootContext ~= menuObj and rootContext.getSubMenu then
            local ok, sub = pcall(rootContext.getSubMenu, rootContext, opt.subOption)
            if ok and sub then
                return sub
            end
        end

        if menuObj.subMenus and menuObj.subMenus[opt.subOption] then
            return menuObj.subMenus[opt.subOption]
        end

        if rootContext and rootContext ~= menuObj and rootContext.subMenus and rootContext.subMenus[opt.subOption] then
            return rootContext.subMenus[opt.subOption]
        end

        if menuObj.subOption and menuObj.subOption[opt.subOption] then
            return menuObj.subOption[opt.subOption]
        end

        return nil
    end

    local function applyIconsDeep(menuObj, parentOpt, inheritedItem, rootContext)
        if not menuObj or not menuObj.options then return end

        for _, opt in ipairs(menuObj.options) do
            if opt and opt.name then
                local currentItem = nil
                if not isAddAll(opt.name) then
                    if isAddOne(opt.name) and inheritedItem then
                        currentItem = inheritedItem
                    else
                        currentItem = opt.itemForTexture or ExtractContainerItemFromOption(opt)
                    end
                end

                if currentItem then
                    opt.itemForTexture = currentItem
                    opt.iconTexture = nil -- Garante a renderização dinâmica do fluido no motor do PZ
                else
                    if not opt.iconTexture and iconMap[opt.name] then
                        opt.iconTexture = getTexture(iconMap[opt.name])
                    end

                    if isAddAll(opt.name) then
                        opt.iconTexture = getTexture(TEX_GAS_REFUEL_AL)
                    end
                end

                local subMenu = getSubMenuFromOption(menuObj, opt, rootContext)
                if subMenu then
                    local nextInheritedItem = currentItem or inheritedItem
                    applyIconsDeep(subMenu, opt, nextInheritedItem, rootContext)
                end
            end
        end
    end

    applyIconsDeep(context, nil, nil, context)
end

-- ============================================================================
-- REGISTRO DE EVENTOS GLOBAIS DO SISTEMA
-- ============================================================================
Events.OnFillWorldObjectContextMenu.Add(ContextMenu.Build)

print("[LKS PATCH - PB_ContextMenu_Generator.lua] Carregado com sucesso!")
