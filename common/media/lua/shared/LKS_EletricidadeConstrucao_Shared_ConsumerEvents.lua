-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Shared_ConsumerEvents.lua
-- LKS_EletricidadeConstrucao V2 - Shared Consumer Event Hooks
-- Placed in shared/ so these events fire in the client Lua context where PZ
-- dispatches them (singleplayer uses a single combined state, but OnObjectAdded
-- is a client-side event).
-- Version: 2.0.0-alpha

-- ============================================================================
-- HELPERS
-- ============================================================================

--- Returns true if obj is a power consumer we track.
local function IsTrackedConsumer(obj)
    if not obj then return false end
    local hasFridge  = obj.getContainerByType and obj:getContainerByType("fridge")  ~= nil
    local hasFreezer = obj.getContainerByType and obj:getContainerByType("freezer") ~= nil
    return instanceof(obj, "IsoLightSwitch")
        or instanceof(obj, "IsoLight")
        or instanceof(obj, "IsoClothingDryer")
        or instanceof(obj, "IsoClothingWasher")
        or instanceof(obj, "IsoCombinationWasherDryer")
        or instanceof(obj, "IsoStackedWasherDryer")
        or instanceof(obj, "IsoStove")
        or instanceof(obj, "IsoTelevision")
        or instanceof(obj, "IsoRadio")
        or hasFridge
        or hasFreezer
end

--- Returns true if the required V2 server modules are available.
local function HasServerModules()
    return LKS_EletricidadeConstrucao
        and LKS_EletricidadeConstrucao.Building
        and LKS_EletricidadeConstrucao.Building.ConsumerScanner
        and LKS_EletricidadeConstrucao.Building.ConsumerScanner.RescanConsumers ~= nil
        and LKS_EletricidadeConstrucao.Core
        and LKS_EletricidadeConstrucao.Core.StateManager
        and LKS_EletricidadeConstrucao.Core.StateManager.GetAllBuildings ~= nil
end

--- Rescan every known building and push updated stats to generator ModData.
--- Iterates all buildings (typically 1-2) - no tile-to-building lookup needed.
local function RescanAllBuildings()
    if not HasServerModules() then return end

    local buildings = LKS_EletricidadeConstrucao.Core.StateManager.GetAllBuildings()
    if not buildings then return end

    local count = 0
    for _, bd in pairs(buildings) do
        LKS_EletricidadeConstrucao.Building.ConsumerScanner.RescanConsumers(bd)
        if LKS_EletricidadeConstrucao.Power
        and LKS_EletricidadeConstrucao.Power.Distributor
        and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding then
            LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(bd.id)
        end
        count = count + 1
    end

    if count > 0 and LKS_EletricidadeConstrucao.Core.Logger then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(
            string.format("ConsumerEvents: rescanned %d building(s)", count),
            "Building")
    end
end

local function IsAuthoritativeRuntime()
    local Runtime = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    if not Runtime then return false end
    if Runtime.IsMultiplayerClient and Runtime.IsMultiplayerClient() then
        return false
    end
    return (Runtime.IsServer and Runtime.IsServer())
        or (Runtime.IsSingleplayer and Runtime.IsSingleplayer())
end

local function TableIsEmpty(t)
    if not t then return true end
    for _ in pairs(t) do return false end
    return true
end

local function CleanupRemovedGeneratorState(gen)
    if not gen or not instanceof(gen, "IsoGenerator") then return end
    if not IsAuthoritativeRuntime() or not HasServerModules() then return end

    local SM = LKS_EletricidadeConstrucao.Core.StateManager
    local GenData = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
    if not SM or not GenData or not GenData.MakeId then return end

    local sq = gen:getSquare()
    if not sq then return end

    local genId = GenData.MakeId(sq:getX(), sq:getY(), sq:getZ())
    local genKey = string.format("%d_%d_%d", sq:getX(), sq:getY(), sq:getZ())
    local genData = SM.GetGenerator and SM.GetGenerator(genId)
    local md = gen:getModData()
    local affectedBuildings = {}
    local changed = false

    if md and md.Gen_BuildingPoolID then
        affectedBuildings[md.Gen_BuildingPoolID] = true
    end
    if genData and genData.connectedBuildings then
        for _, bid in pairs(genData.connectedBuildings) do
            affectedBuildings[bid] = true
        end
    end

    for buildingId in pairs(affectedBuildings) do
        local bldData = SM.GetBuilding and SM.GetBuilding(buildingId)
        ---@cast bldData any
        if bldData and bldData.connectedGenerators then
            local newList = {}
            local removed = false
            for _, k in pairs(bldData.connectedGenerators) do
                if k ~= genKey then
                    table.insert(newList, k)
                else
                    removed = true
                end
            end
            if removed then
                bldData.connectedGenerators = newList
                changed = true
                if TableIsEmpty(newList) then
                    SM.RemoveBuilding(buildingId)
                else
                    SM.MarkDirty()
                end
                if LKS_EletricidadeConstrucao.Core.Logger then
                    LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                        "[ConsumerEvents] Removed stale generator link %s from building %s",
                        genKey, buildingId), "Building")
                end
            end
        end
    end

    if genData and SM.RemoveGenerator then
        SM.RemoveGenerator(genId)
        changed = true
        if LKS_EletricidadeConstrucao.Core.Logger then
            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                "[ConsumerEvents] Removed generator state for world-removed generator %s",
                genId), "Building")
        end
    end

    if changed
            and LKS_EletricidadeConstrucao.Power
            and LKS_EletricidadeConstrucao.Power.Distributor
            and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding then
        for buildingId in pairs(affectedBuildings) do
            if SM.GetBuilding and SM.GetBuilding(buildingId) then
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(buildingId)
            end
        end
    end

    if changed and SM.IsStateLoaded and SM.IsStateLoaded() and SM.Save then
        SM.Save(true, false)
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--- Fired when any ISO object is placed in the world.
local function OnObjectAdded(obj)
    if not IsTrackedConsumer(obj) then return end
    RescanAllBuildings()
end

--- Handle pool ownership transfer when the pool-owner generator is picked up or
--- destroyed.  Fires while the IsoObject is still in the world so ModData is
--- readable.  The first remaining generator in connectedGenerators inherits
--- LKS_EletricidadeConstrucao_PoolData so the building survives without a full rescan.
local function HandleGeneratorAboutToBeRemoved(gen)
    if not gen or not instanceof(gen, "IsoGenerator") then return end
    local md = gen:getModData()
    -- Only act on connected generators that are the pool owner (have LKS_EletricidadeConstrucao_PoolData)
    if not (md and md.Gen_BuildingPoolID and md.LKS_EletricidadeConstrucao_PoolData) then return end

    local SM = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not SM then return end

    local buildingPoolID = md.Gen_BuildingPoolID
    local sq = gen:getSquare()
    if not sq then return end
    local ownKey = string.format("%d_%d_%d", sq:getX(), sq:getY(), sq:getZ())

    local bldData = SM.GetBuilding and SM.GetBuilding(buildingPoolID)
    ---@cast bldData any
    if not bldData then return end

    -- Find a successor generator (any other generator still linked to this building)
    local cell = getCell and getCell()
    if not cell then return end

    -- connectedGenerators is Kahlua-deserialized (string numeric keys); use pairs
    for _, k in pairs(bldData.connectedGenerators or {}) do
        if k ~= ownKey then
            local nx, ny, nz = string.match(k, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if nx then
                local nSq = cell:getGridSquare(tonumber(nx), tonumber(ny), tonumber(nz))
                if nSq then
                    local nObjs = nSq:getObjects()
                    for ni = 0, nObjs:size() - 1 do
                        local nObj = nObjs:get(ni)
                        if nObj and instanceof(nObj, "IsoGenerator") then
                            local nMd = nObj:getModData()
                            local nextWorldId = md.LKS_EletricidadeConstrucao_WorldId
                            if not nextWorldId or nextWorldId == "unknown" then
                                nextWorldId = LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId and
                                              LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId() or nil
                            end
                            if nextWorldId == "unknown" then
                                nextWorldId = nil
                            end
                            nMd.LKS_EletricidadeConstrucao_PoolData = md.LKS_EletricidadeConstrucao_PoolData  -- transfer pool ownership
                            nMd.LKS_EletricidadeConstrucao_WorldId  = nextWorldId
                            if LKS_EletricidadeConstrucao.Core.Runtime
                            and LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync
                            and LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                nObj:transmitModData()
                            end
                            if LKS_EletricidadeConstrucao.Core.Logger then
                                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                    "[ConsumerEvents] Pool ownership transferred %s → %s for building %s",
                                    ownKey, k, buildingPoolID), "Building")
                            end
                            break
                        end
                    end
                end
            end
            break  -- transfer to first available successor only
        end
    end
end

--- Fired just BEFORE an ISO object is removed.
--- Delays one tick so the object is fully gone before the rescan counts consumers.
local function OnObjectAboutToBeRemoved(obj)
    -- Handle generator pool ownership transfer while the object is still present
    if instanceof(obj, "IsoGenerator") then
        HandleGeneratorAboutToBeRemoved(obj)
        CleanupRemovedGeneratorState(obj)
    end

    if not IsTrackedConsumer(obj) then return end
    local function delayedRescan()
        Events.OnTick.Remove(delayedRescan)
        RescanAllBuildings()
    end
    Events.OnTick.Add(delayedRescan)
end

-- ============================================================================
-- LIGHT SWITCH ACTIVE-STATE POLL (every ~1 seconds)
-- ============================================================================
-- Toggling a vanilla light switch fires no mod event.  Poll on OnTick at a
-- throttled rate so the InfoWindow reflects switch changes within ~1 seconds.

local _lastActiveStateCheck = 0
local ACTIVE_POLL_INTERVAL  = 1    -- seconds

--- Re-evaluate every consumer's isActive state and sync to generator ModData.
--- Does NOT rescan building geometry; only refreshes the active flag on known
--- consumers and pushes updated stats.  Very cheap per building.
local function RefreshActiveStates()
    if not HasServerModules() then return end
    local Dist = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
    local refreshFn = Dist and (Dist.RefreshBuildingStats or Dist.ForceUpdateBuilding)
    if not refreshFn then return end

    local buildings = LKS_EletricidadeConstrucao.Core.StateManager.GetAllBuildings()
    if not buildings then return end

    for _, bd in pairs(buildings) do
        -- Refresh active states without forcing tile power to be re-applied.
        refreshFn(bd.id)
    end
end

local function OnTick()
    local now = os.time()
    if now - _lastActiveStateCheck >= ACTIVE_POLL_INTERVAL then
        _lastActiveStateCheck = now
        RefreshActiveStates()
    end
end

-- ============================================================================
-- REGISTER
-- ============================================================================

if Events.OnObjectAdded then
    Events.OnObjectAdded.Add(OnObjectAdded)
end
if Events.OnObjectAboutToBeRemoved then
    Events.OnObjectAboutToBeRemoved.Add(OnObjectAboutToBeRemoved)
end
Events.OnTick.Add(OnTick)
