-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Actions_OpenInfoWindow.lua
-- TimedAction for opening Generator Info Window
-- Opens UI showing generator and building stats
-- LOCATION: shared/actions/

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Actions_OpenInfoWindow] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

print("[LKS_EletricidadeConstrucao_Actions_OpenInfoWindow] Loading Open Info Window action...")

-- Load required modules
require "TimedActions/ISBaseTimedAction"

-- Register module
LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_Actions_OpenInfoWindow")

-- Create namespace
LKS_EletricidadeConstrucao.Actions = LKS_EletricidadeConstrucao.Actions or {}

-- ============================================================
-- OPEN INFO WINDOW TIMED ACTION
-- ============================================================

LKS_EletricidadeConstrucao_OpenInfoWindow = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_OpenInfoWindow")

-- ============================================================
-- VALIDATION
-- ============================================================

function LKS_EletricidadeConstrucao_OpenInfoWindow:isValid()
    -- Generator must still exist
    if not self.generator then return false end
    
    -- Generator must be at same location
    local square = self.generator:getSquare()
    if not square then return false end
    
    return true
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:waitToStart()
    local sq = self.anchorSquare or (self.generator and self.generator:getSquare())
    if sq then
        self.character:faceLocation(sq:getX(), sq:getY())
    end
    return self.character:shouldBeTurning()
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:update()
    local sq = self.anchorSquare or (self.generator and self.generator:getSquare())
    if sq then
        self.character:faceLocation(sq:getX(), sq:getY())
    end
end

-- ============================================================
-- ANIMATION
-- ============================================================

function LKS_EletricidadeConstrucao_OpenInfoWindow:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:stop()
    ISBaseTimedAction.stop(self)
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:perform()
    ISBaseTimedAction.perform(self)
end

-- ============================================================
-- ACTION EXECUTION
-- ============================================================

local function NormalizeBuildingHint(buildingHint)
    if type(buildingHint) == "table" then
        return buildingHint.id
    end
    if type(buildingHint) == "string" then
        return buildingHint
    end
    return nil
end

local function SendOpenInfoWindowToClient(playerObj, generator, anchorSquare, buildingHint)
    if not playerObj or not sendServerCommand then
        return false
    end

    local genSquare = generator and generator:getSquare()
    if not genSquare then
        return false
    end

    local payload = {
        kind = "OpenInfoWindow",
        success = true,
        genX = genSquare:getX(),
        genY = genSquare:getY(),
        genZ = genSquare:getZ(),
    }

    local sq = anchorSquare or genSquare
    if sq then
        payload.anchorX = sq:getX()
        payload.anchorY = sq:getY()
        payload.anchorZ = sq:getZ()
    end

    local buildingID = NormalizeBuildingHint(buildingHint)
    if buildingID then
        payload.buildingID = buildingID
    end

    sendServerCommand(playerObj, "LKS_EletricidadeConstrucao", "ActionResult", payload)
    return true
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:complete()
    -- Dedicated server has no UI; ask the requesting client to open it locally.
    if isServer() and not isClient() then
        if not SendOpenInfoWindowToClient(self.character, self.generator, self.anchorSquare, self.buildingHint) then
            LKS_EletricidadeConstrucao.Warn("[OpenInfoWindow] Dedicated server could not send client open request")
        end
        return true
    end
    
    -- Check if UI module loaded
    if not LKS_EletricidadeConstrucao.UI or not LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow then
        LKS_EletricidadeConstrucao.Error("[OpenInfoWindow] LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow not loaded!")
        return true
    end
    
    -- Open info window
    LKS_EletricidadeConstrucao.Print("[OpenInfoWindow] Opening generator info window")
    
    if LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow.Open then
        LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow.Open(self.character, self.generator, self.anchorSquare, self.buildingHint)
    else
        LKS_EletricidadeConstrucao.Error("[OpenInfoWindow] LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow.Open not found!")
    end
    
    return true
end

-- ============================================================
-- DURATION & CONSTRUCTOR
-- ============================================================

function LKS_EletricidadeConstrucao_OpenInfoWindow:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    
    -- Opening window is fast (~1 second)
    return 10
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:new(character, generator, anchorSquare, buildingHint)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.generator = generator
    o.anchorSquare = anchorSquare
    o.buildingHint = NormalizeBuildingHint(buildingHint)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

-- ============================================================
-- EXPORT TO NAMESPACE
-- ============================================================

LKS_EletricidadeConstrucao.Actions.OpenInfoWindow = LKS_EletricidadeConstrucao_OpenInfoWindow

print("[LKS_EletricidadeConstrucao_Actions_OpenInfoWindow] Open Info Window action loaded successfully")
