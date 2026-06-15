-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_ContextMenu_LightSwitchInstall.lua
-- Install vanilla lightswitch items back onto walls.
-- V1 placement logic (VanillaLightswitchPlacement.lua) ported to V2 module system.
-- Runs on client / host only (not dedicated server).

if isClient() or not isServer() then
    -- client or local host: continue
else
    return -- dedicated server: skip
end

if LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.RegisterModule then
    LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ContextMenu_LightSwitchInstall", "2.0.0")
end

-- ============================================================================
-- CONSTANTS / HELPERS
-- ============================================================================

local LIGHTSWITCH_ITEMS = {
    "Base.lighting_indoor_01_0",
    "Base.lighting_indoor_01_1",
    "Base.lighting_indoor_01_2",
    "Base.lighting_indoor_01_3",
    "Base.lighting_indoor_01_4",
    "Base.lighting_indoor_01_5",
    "Base.lighting_indoor_01_6",
    "Base.lighting_indoor_01_7",
}

local DIR_N = 0
local DIR_S = 4
local DIR_E = 6
local DIR_W = 2

-- Check if item is a vanilla lightswitch
local function isLightswitch(item)
    if not item then return false end
    local fullType = item:getFullType()
    for _, lightswitchType in ipairs(LIGHTSWITCH_ITEMS) do
        if fullType == lightswitchType then return true end
    end
    return false
end

local function getIsoDirection(dirConstant)
    if dirConstant == DIR_N then return IsoDirections.N
    elseif dirConstant == DIR_S then return IsoDirections.S
    elseif dirConstant == DIR_E then return IsoDirections.E
    elseif dirConstant == DIR_W then return IsoDirections.W end
    return IsoDirections.N
end

-- Find adjacent wall in any direction (N, S, E, W)
-- Returns: direction, wallSquare (or nil if no wall found)
local function findAdjacentWall(playerSquare)
    if not playerSquare then return nil, nil end

    -- Check north wall on player's square
    local northWall = playerSquare:getWall(true)
    if northWall then
        return DIR_N, playerSquare
    end

    -- Check south wall (on square to south, facing north)
    local southSquare = playerSquare:getAdjacentSquare(getIsoDirection(DIR_S))
    if southSquare then
        local southWall = southSquare:getWall(true)
        if southWall then
            return DIR_S, playerSquare
        end
    end

    -- Check west wall on player's square
    local westWall = playerSquare:getWall(false)
    if westWall then
        return DIR_W, playerSquare
    end

    -- Check east wall (on square to east, facing west)
    local eastSquare = playerSquare:getAdjacentSquare(getIsoDirection(DIR_E))
    if eastSquare then
        local eastWall = eastSquare:getWall(false)
        if eastWall then
            return DIR_E, playerSquare
        end
    end

    return nil, nil
end

-- Sprite mapping (from V1 testing):
-- lighting_indoor_01_0 = North wall
-- lighting_indoor_01_1 = West wall
-- lighting_indoor_01_2 = East wall
-- lighting_indoor_01_3 = South wall
local function getLightswitchSprite(direction)
    if direction == DIR_N then return "lighting_indoor_01_0" end
    if direction == DIR_S then return "lighting_indoor_01_3" end
    if direction == DIR_W then return "lighting_indoor_01_1" end
    if direction == DIR_E then return "lighting_indoor_01_2" end
    return "lighting_indoor_01_0"
end

-- ============================================================================
-- TIMED ACTION (V1 logic)
-- ============================================================================

ISInstallLightswitch = ISBaseTimedAction:derive("ISInstallLightswitch")

function ISInstallLightswitch:isValid()
    return self.item ~= nil and
           self.square ~= nil and
           self.direction ~= nil and
           self.character:getInventory():contains(self.item)
end

function ISInstallLightswitch:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function ISInstallLightswitch:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
end

function ISInstallLightswitch:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.sound = self.character:playSound("BuildWoodenStructure")
end

function ISInstallLightswitch:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function ISInstallLightswitch:perform()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end

    -- Remove item from inventory
    self.character:getInventory():Remove(self.item)

    -- Get correct sprite
    local spriteName = getLightswitchSprite(self.direction)
    local sprite = IsoSpriteManager.instance:getSprite(spriteName)
    if not sprite then
        ISBaseTimedAction.perform(self)
        return
    end

    -- Create IsoLightSwitch on the square
    local lightswitch = IsoLightSwitch.new(getCell(), self.square, sprite, 0)
    if lightswitch then
        lightswitch:addLightSourceFromSprite()
        self.square:AddSpecialObject(lightswitch)
        lightswitch:transmitCompleteItemToServer()
        local md = lightswitch:getModData()
        md.isVanillaLightSwitch = true
    end

    ISBaseTimedAction.perform(self)
end

function ISInstallLightswitch:new(character, item, square, direction)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.item = item
    o.square = square
    o.direction = direction
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 100 -- ~10 seconds
    return o
end

-- ============================================================================
-- INVENTORY CONTEXT MENU (V1 item iteration pattern)
-- ============================================================================

Events.OnFillInventoryObjectContextMenu.Add(function(player, context, items)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    -- Find a lightswitch item in selection (V1 pattern: handle bare items and container entries)
    local lightswitchItem = nil
    if items and #items > 0 then
        for _, item in ipairs(items) do
            local realItem = item
            if type(item) == "table" and item.items then
                realItem = item.items[1]
            end
            if isLightswitch(realItem) then
                lightswitchItem = realItem
                break
            end
        end
    end
    if not lightswitchItem then return end

    local playerSquare = playerObj:getSquare()
    if not playerSquare then return end

    local direction, wallSquare = findAdjacentWall(playerSquare)
    if direction and wallSquare then
        -- Wall found - add installation option
        local option = context:addOption(
            getText("ContextMenu_InstallLightswitch") or "Install Lightswitch",
            playerObj,
            function()
                ISTimedActionQueue.add(ISInstallLightswitch:new(playerObj, lightswitchItem, wallSquare, direction))
            end
        )

        local directionText = ""
        if direction == DIR_N then directionText = "North"
        elseif direction == DIR_S then directionText = "South"
        elseif direction == DIR_W then directionText = "West"
        elseif direction == DIR_E then directionText = "East"
        end

        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip:setName(getText("ContextMenu_InstallLightswitch") or "Install Lightswitch")
        tooltip.description = "Install lightswitch on " .. directionText .. " wall" ..
                              "\nTime: ~10 seconds" ..
                              "\nLightbulb included"
        option.toolTip = tooltip
    else
        -- No wall found - disabled option with explanation
        local option = context:addOption(
            getText("ContextMenu_InstallLightswitch") or "Install Lightswitch",
            nil,
            nil
        )
        option.notAvailable = true
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip:setName(getText("ContextMenu_InstallLightswitch") or "Install Lightswitch")
        tooltip.description = "No wall nearby" ..
                              "\nMove next to a wall to install"
        option.toolTip = tooltip
    end
end)
