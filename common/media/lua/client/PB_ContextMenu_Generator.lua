-- PB_ContextMenu_Generator.lua
-- Generator context menu (right-click options)
-- Turn On/Off, Info, Connect/Disconnect Building
-- LOCATION: client/

if not PoweredBuildings then
    print("[PB_ContextMenu_Generator] PoweredBuildings namespace not found - skipping module load")
    return
end

print("[PB_ContextMenu_Generator] Loading Generator Context Menu...")

-- Register module
PoweredBuildings.RegisterModule("PB_ContextMenu_Generator")

-- Create namespace
PoweredBuildings.ContextMenu = PoweredBuildings.ContextMenu or {}
PoweredBuildings.ContextMenu.Generator = {}

local ContextMenu = PoweredBuildings.ContextMenu.Generator

-- Sprite-based icon lookup with cache (mirrors PB_UI_GeneratorInfoWindow:getGeneratorIcon)
-- Used for per-row icons in submenus (raw texture, small size is fine there).
local _genIconCache = {}
local _genIconFallback = nil
local function GetGeneratorIcon(gen)
    _genIconFallback = _genIconFallback or getTexture("media/textures/Item_Generator.png")
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

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Find generator in world objects
local function FindGenerator(worldobjects)
    if not worldobjects then return nil end
    
    for _, obj in ipairs(worldobjects) do
        if instanceof(obj, "IsoGenerator") then
            return obj
        end
    end
    
    return nil
end

-- Check if generator is in building mode (connected to building)
local function IsGeneratorInBuildingMode(generator)
    if not generator then return false end
    
    local md = generator:getModData()
    return md and md.Gen_BuildingPoolID ~= nil
end

-- Get generator fuel percentage
local function GetFuelPercentage(generator)
    if not generator then return 0 end
    
    local fuel = generator:getFuel()
    local maxFuel = generator:getMaxFuel()
    
    if maxFuel <= 0 then return 0 end
    
    return math.floor((fuel / maxFuel) * 100)
end

-- Get generator condition percentage
local function GetConditionPercentage(generator)
    if not generator then return 0 end
    
    return math.floor(generator:getCondition())
end

-- Check if generator can be activated
local function CanActivateGenerator(generator)
    if not generator then return false end
    if generator:isActivated() then return false end
    if generator:getFuel() <= 0 then return false end
    if generator:getCondition() <= 0 then return false end
    
    return true
end

-- Check if player can reach generator
local function CanReachGenerator(player, generator)
    if not player or not generator then return false end
    
    local playerSquare = player:getSquare()
    local generatorSquare = generator:getSquare()
    
    if not playerSquare or not generatorSquare then return false end
    
    -- Check if adjacent
    local dx = math.abs(playerSquare:getX() - generatorSquare:getX())
    local dy = math.abs(playerSquare:getY() - generatorSquare:getY())
    
    return dx <= 1 and dy <= 1
end

-- ============================================================
-- MENU OPTION HANDLERS
-- ============================================================

-- Turn On Generator
function ContextMenu.OnTurnOn(worldobjects, player)
    if not player or not worldobjects then return end
    
    local generator = FindGenerator(worldobjects)
    if not generator then return end
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    -- Walk to generator if needed
    if not CanReachGenerator(playerObj, generator) then
        if luautils.walkAdj then
            luautils.walkAdj(playerObj, generator:getSquare())
        end
    end
    
    -- Queue activation action
    if PoweredBuildings.Actions and PoweredBuildings.Actions.ActivateGenerator then
        ISTimedActionQueue.add(PoweredBuildings.Actions.ActivateGenerator:new(playerObj, generator, true))
    else
        print("[PB_ContextMenu_Generator] ERROR: PoweredBuildings.Actions.ActivateGenerator not found!")
    end
end

-- Turn Off Generator
function ContextMenu.OnTurnOff(worldobjects, player)
    if not player or not worldobjects then return end
    
    local generator = FindGenerator(worldobjects)
    if not generator then return end
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    -- Walk to generator if needed
    if not CanReachGenerator(playerObj, generator) then
        if luautils.walkAdj then
            luautils.walkAdj(playerObj, generator:getSquare())
        end
    end
    
    -- Queue deactivation action
    if PoweredBuildings.Actions and PoweredBuildings.Actions.ActivateGenerator then
        ISTimedActionQueue.add(PoweredBuildings.Actions.ActivateGenerator:new(playerObj, generator, false))
    else
        print("[PB_ContextMenu_Generator] ERROR: PoweredBuildings.Actions.ActivateGenerator not found!")
    end
end

-- Connect Generator to Building
function ContextMenu.OnConnectBuilding(worldobjects, player)
    if not player or not worldobjects then return end
    
    local generator = FindGenerator(worldobjects)
    if not generator then return end
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    -- Walk to generator if needed
    if not CanReachGenerator(playerObj, generator) then
        if luautils.walkAdj then
            luautils.walkAdj(playerObj, generator:getSquare())
        end
    end
    
    -- Queue connect action
    if PoweredBuildings.Actions and PoweredBuildings.Actions.ConnectBuilding then
        ISTimedActionQueue.add(PoweredBuildings.Actions.ConnectBuilding:new(playerObj, generator))
    else
        print("[PB_ContextMenu_Generator] ERROR: PoweredBuildings.Actions.ConnectBuilding not found!")
    end
end

-- Disconnect Generator from Building
function ContextMenu.OnDisconnectBuilding(worldobjects, player)
    if not player or not worldobjects then return end
    
    local generator = FindGenerator(worldobjects)
    if not generator then return end
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    -- Walk to generator if needed
    if not CanReachGenerator(playerObj, generator) then
        if luautils.walkAdj then
            luautils.walkAdj(playerObj, generator:getSquare())
        end
    end
    
    -- Queue disconnect action
    if PoweredBuildings.Actions and PoweredBuildings.Actions.DisconnectBuilding then
        ISTimedActionQueue.add(PoweredBuildings.Actions.DisconnectBuilding:new(playerObj, generator))
    else
        print("[PB_ContextMenu_Generator] ERROR: PoweredBuildings.Actions.DisconnectBuilding not found!")
    end
end

-- ============================================================
-- MAIN CONTEXT MENU BUILDER
-- ============================================================

function ContextMenu.Build(player, context, worldobjects, test)
    -- Validate inputs
    if not player or not context or not worldobjects then return end
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    -- Find generator
    local generator = FindGenerator(worldobjects)
    if not generator then return end
    
    -- Test mode (check if menu should appear)
    if test then return true end
    
    -- Get generator state
    local isActivated = generator:isActivated()
    local isInBuildingMode = IsGeneratorInBuildingMode(generator)
    local fuelPercent = GetFuelPercentage(generator)
    local conditionPercent = GetConditionPercentage(generator)
    local canActivate = CanActivateGenerator(generator)
    
    -- Find or create vanilla "Generator" submenu
    local generatorSubmenu = nil
    local generatorOption = nil
    
    for _, option in ipairs(context.options) do
        if option.name == getText("ContextMenu_Generator") then
            generatorOption = option
            generatorSubmenu = context:getSubMenu(generatorOption.subOption)
            break
        end
    end
    
    -- Create submenu if doesn't exist
    if not generatorSubmenu then
        generatorSubmenu = context:getNew(context)
        generatorOption = context:addOption(getText("ContextMenu_Generator"), worldobjects, nil, generatorSubmenu)
    end
   
    -- ========================================
    -- BUILDING MODE GENERATOR
    -- ========================================
    if isInBuildingMode then
        -- Remove vanilla options (we override them)
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_GeneratorPlug")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_GeneratorTake")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_Turn_Off")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("IGUI_Turn_Off")) end)
        pcall(function() generatorSubmenu:removeOptionByName(getText("ContextMenu_Turn_On")) end)
        
        -- Turn On/Off
        if isActivated then
            local turnOffOption = generatorSubmenu:addOption(
                getText("ContextMenu_Turn_Off") or "Turn Off",
                worldobjects,
                ContextMenu.OnTurnOff,
                player
            )
            turnOffOption.iconTexture = getTexture("media/ui/pwr_off.png")
        else
            local turnOnOption = generatorSubmenu:addOption(
                getText("ContextMenu_Turn_On") or "Turn On",
                worldobjects,
                ContextMenu.OnTurnOn,
                player
            )
            
            -- Add icon
            turnOnOption.iconTexture = getTexture("media/ui/pwr_on.png")
            
            -- Disable if can't activate
            if not canActivate then
                turnOnOption.notAvailable = true
                
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                if fuelPercent <= 0 then
                    tooltip:setName(getText("IGUI_Generator_NoFuel") or "No Fuel")
                elseif conditionPercent <= 0 then
                    tooltip:setName(getText("IGUI_Generator_Broken") or "Generator Broken")
                else
                    tooltip:setName(getText("IGUI_Generator_CannotActivate") or "Cannot Activate")
                end
                turnOnOption.toolTip = tooltip
            end
        end
        
        -- Disconnect from Building
        local disconnectOption = generatorSubmenu:addOption(
            getText("IGUI_DisconnectFromBuilding") or "Disconnect from Building",
            worldobjects,
            ContextMenu.OnDisconnectBuilding,
            player
        )
        
        -- Add icon
        disconnectOption.iconTexture = getTexture("media/ui/house_electricity_off.png")

        -- Building Power Info (Gebäudestrominfo)
        local infoOption = generatorSubmenu:addOption(
            getText("IGUI_BuildingPowerInfoMenu") or "Geb\195\164udestrominfo",
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
        infoOption.iconTexture = getTexture("media/ui/house_electricity.png")

    -- ========================================
    -- STANDALONE GENERATOR (not connected)
    -- ========================================
    else
        -- Check if generator is near a building
        local square = generator:getSquare()
        local nearBuilding = false
        
        if square then
            -- Check generator square first
            local building = square:getBuilding()
            if building then
                print("[PB_ContextMenu_Generator] Building found on generator square")
                nearBuilding = true
            end
            
            -- Also check for haveBuilding() method
            if not nearBuilding and square.haveBuilding and square:haveBuilding() then
                print("[PB_ContextMenu_Generator] Building detected via haveBuilding()")
                nearBuilding = true
            end
            
            -- Check adjacent squares
            if not nearBuilding then
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local adjSquare = getCell():getGridSquare(
                                square:getX() + dx,
                                square:getY() + dy,
                                square:getZ()
                            )
                            if adjSquare then
                                -- Try getBuilding()
                                if adjSquare:getBuilding() then
                                    print(string.format("[PB_ContextMenu_Generator] Building found at adjacent square (%d, %d)", dx, dy))
                                    nearBuilding = true
                                    break
                                end
                                -- Try haveBuilding()
                                if adjSquare.haveBuilding and adjSquare:haveBuilding() then
                                    print(string.format("[PB_ContextMenu_Generator] Building detected via haveBuilding() at (%d, %d)", dx, dy))
                                    nearBuilding = true
                                    break
                                end
                            end
                        end
                    end
                    if nearBuilding then break end
                end
            end
            
            if not nearBuilding then
                print("[PB_ContextMenu_Generator] No building found near generator")
            end
        end
        
        -- Hide "Connect to Building" if vanilla GeneratorUnplug is already present
        -- (vanilla plug system is active; our building-mode connect doesn't apply)
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
                getText("IGUI_ConnectToBuilding") or "Connect to Building",
                worldobjects,
                ContextMenu.OnConnectBuilding,
                player
            )
            connectOption.iconTexture = getTexture("media/ui/house_electricity.png")

            -- Require "Generator" recipe (unlocked at Electrical level 3)
            local knowsRecipe = playerObj:isRecipeActuallyKnown("Generator")
            if not knowsRecipe then
                connectOption.notAvailable = true
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                tooltip:setName(getText("IGUI_ConnectToBuilding") or "Connect to Building")
                tooltip.description = getText("IGUI_ConnectRequiresKnowledge")
                    or "Requires the Generator recipe (Electrical level 3)"
                connectOption.toolTip = tooltip
            elseif not nearBuilding then
                -- Recipe known but no building in range
                connectOption.notAvailable = true
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                tooltip:setName(getText("IGUI_NoBuildingNearby") or "No building nearby")
                tooltip.description = getText("IGUI_NoBuildingNearby_Desc")
                    or "Generator must be placed next to a building with walls"
                connectOption.toolTip = tooltip
            end
        end
    end
    -- =========================================================
    -- ICON PASS: assign icons to any option that still has none.
    -- NOTE: Some vanilla options (Add Fuel, Fix) are added to the
    -- top-level `context`, not the generator submenu, so we scan both.
    -- =========================================================
    local iconMap = {
        -- Vanilla generator options (submenu)
        [getText("ContextMenu_GeneratorTake")   or "Take Generator"]        = "media/ui/take_gen.png",
        [getText("ContextMenu_GeneratorPlug")   or "Connect Generator"]     = "media/ui/connect.png",
        [getText("ContextMenu_GeneratorUnplug") or "Disconnect Generator"]  = "media/ui/disconnect.png",
        [getText("ContextMenu_GeneratorInfo")   or "Generator Info"]        = "media/ui/gen_info.png",
        [getText("ContextMenu_Examine")         or "Examine"]               = "media/ui/gen_info.png",
        [getText("IGUI_BuildingPowerInfoMenu")  or "Building Power Info"]   = "media/ui/house_electricity.png",
        -- Vanilla turn on/off (standalone mode; building mode overrides these above)
        [getText("ContextMenu_Turn_On")         or "Turn On"]               = "media/ui/pwr_on.png",
        [getText("IGUI_Turn_On")                or "Turn On"]               = "media/ui/pwr_on.png",
        [getText("ContextMenu_Turn_Off")        or "Turn Off"]              = "media/ui/pwr_off.png",
        [getText("IGUI_Turn_Off")               or "Turn Off"]              = "media/ui/pwr_off.png",
        -- Repair (B42 appliance repair option)
        [getText("ContextMenu_Repair")          or "Repair"]                = "media/ui/rep_gen.png",
        -- Vanilla options added to top-level context (not the submenu)
        [getText("ContextMenu_GeneratorAddFuel")or "Add Fuel"]              = "media/ui/vehicles/gas_refuel.png",
        [getText("ContextMenu_AddAll")          or "Add All"]               = "media/ui/vehicles/gas_refuel_all.png", -- not working, icon not displayed
        [getText("ContextMenu_GeneratorFix")    or "Fix Generator"]         = "media/ui/rep_gen.png",

    }
    local function applyIcons(optList)
        if not optList then return end
        for _, opt in ipairs(optList) do
            if not opt.iconTexture and opt.name and iconMap[opt.name] then
                opt.iconTexture = getTexture(iconMap[opt.name])
            end
        end
    end
    -- Submenu options (Turn On/Off, Take, Connect, Examine …)
    if generatorSubmenu then applyIcons(generatorSubmenu.options) end
    -- Top-level context options (Add Fuel, Fix Generator …)
    applyIcons(context.options)
end

-- ============================================================
-- EVENT REGISTRATION
-- ============================================================

-- Register context menu event
Events.OnFillWorldObjectContextMenu.Add(ContextMenu.Build)

print("[PB_ContextMenu_Generator] Generator Context Menu loaded successfully")
