-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- Notes:
--   - Runs on Events.EveryOneMinute (via LKS_EletricidadeConstrucao_ServerInit.lua).
--   - Barrels.UpdateAll() runs BEFORE fuel drain (refuel first, then calculate consumption).
--   - Fuel is authoritative on the IsoObject (gen:getFuel()/setFuel()). State fuelAmount is a cache.
--   - Each generator tracks Gen_LastCalcWorldAge in its IsoObject moddata.
--     On tick: per-generator worldAge delta drives deltaSeconds (catch-up included).
--   - No off-chunk drain: generators only drain when their chunk is loaded.
--   - Diminishing returns per identical sprite; strain multipliers via StrainCalculator.

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Fuel_Manager] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local _updateInterval = 1000  -- Update every second (in ms)
local _lastWorldMinutes = 0   -- Last processed game-minute (for stats/uptime)
local _currentWorldAge = 0    -- World age in hours at the start of the current Update() tick
local _isInitialized = false
local _eventRegistered = false
local _lastSkipLog = 0
local _poolRestoreSeen = {}   -- generatorId -> true once pool is repaired
local _missingGenWarns = {}   -- genId -> count

-- B-102: Per-tick pool calculation cache.
-- Cleared at the start of each Update() generator loop so each pool is computed once per tick.
-- _perTickPoolCache : [primaryGenId] → {totalPoolRate, poolActive}
-- _perTickGenToPool : [genId]        → primaryGenId  (which cache entry covers this gen's pool)
local _perTickPoolCache = {}
local _perTickGenToPool = {}

-- Variant generator tuning lives in shared constants so fuel + strain stay aligned.
local GENERATOR_TYPE_MODIFIERS =
    (LKS_EletricidadeConstrucao.Constants.GENERATOR_TYPES and LKS_EletricidadeConstrucao.Constants.GENERATOR_TYPES.MODIFIERS) or {}

-- Helper: get generator sprite name
local function GetGeneratorSpriteName(gen)
    if not gen then return nil end
    local sprite = gen.getSpriteName and gen:getSpriteName()
    if not sprite and gen.getSprite and gen:getSprite() then
        sprite = gen:getSprite():getName()
    end
    return sprite
end

-- Helper: total world minutes elapsed (game time, independent of real-time speed)
local function GetWorldMinutes()
    local gt = getGameTime and getGameTime()
    if gt then
        local worldHours = gt:getWorldAgeHours() or 0
        -- worldAgeHours already includes fractional minutes, so multiply once
        return worldHours * 60
    end
    return getTimestampMs() / 60000  -- fallback to real time if GameTime unavailable
end

-- Helper: diminish a bonus/malus toward 1.0 as more of the same type are present
local function ApplyDiminishing(mult, count)
    if not mult then return 1.0 end
    if mult == 1.0 or not count or count <= 1 then return mult end
    return 1.0 + ((mult - 1.0) / (2 ^ (count - 1)))
end

local function FindRestorablePoolId(StateManager, genData)
    if not StateManager or not genData or not genData.connectedBuildings then
        return nil
    end

    local genKey = string.format("%d_%d_%d", genData.x or 0, genData.y or 0, genData.z or 0)

    for _, buildingId in pairs(genData.connectedBuildings) do
        local buildingData = StateManager.GetBuilding(buildingId)
        if buildingData and buildingData.connectedGenerators then
            for _, linkedGenKey in pairs(buildingData.connectedGenerators) do
                if linkedGenKey == genKey then
                    return buildingId
                end
            end
        end
    end

    return nil
end

-- Helper: count generators with the same sprite connected across the same building pool
local function CountSameSpriteGenerators(genObj, generatorData)
    local sprite = GetGeneratorSpriteName(genObj)
    if not sprite then return 1 end

    local seen = {}
    local count = 0

    local function addIfSame(gen)
        if not gen then return end
        local key = string.format("%d,%d,%d", gen:getX(), gen:getY(), gen:getZ())
        if seen[key] then return end
        seen[key] = true
        if GetGeneratorSpriteName(gen) == sprite then
            count = count + 1
        end
    end

    addIfSame(genObj)

    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local cell = getCell()
    if cell and generatorData and generatorData.connectedBuildings and StateManager and StateManager.GetBuilding then
        -- connectedBuildings / connectedGenerators are Kahlua-deserialized (string numeric keys)
        for _, bid in pairs(generatorData.connectedBuildings) do
            local bd = StateManager.GetBuilding(bid)
            if bd and bd.connectedGenerators then
                for _, genKey in pairs(bd.connectedGenerators) do
                    local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                    if gx then
                        local sq = cell:getGridSquare(tonumber(gx), tonumber(gy), tonumber(gz))
                        if sq then
                            local objs = sq:getObjects()
                            for i = 0, objs:size() - 1 do
                                local obj = objs:get(i)
                                if obj and instanceof(obj, "IsoGenerator") then
                                    addIfSame(obj)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if count < 1 then return 1 end
    return count
end

-- Helper: count active generators in the same pool(s) so fuel can be shared
-- Made public for use by StrainCalculator (chunk-independent counting)
function LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators(generatorData)
    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not generatorData or not StateManager then return 1 end

    -- BFS over the full pool (mirrors Step-1 discovery in CalculateFuelConsumption)
    local count = 0
    local visited = {}
    local toVisit = {generatorData}

    while #toVisit > 0 do
        local currentGen = table.remove(toVisit)
        if currentGen and currentGen.id and not visited[currentGen.id] then
            visited[currentGen.id] = true

            -- Use GlobalModData instead of live IsoGenerator to make this chunk-independent
            -- A generator is considered active if it has fuel AND is not explicitly deactivated
            -- (activated field is only set to false when fuel runs out, never set to true)
            local hasFuel = (currentGen.fuelAmount or 0) > 0
            local notDeactivated = (currentGen.activated ~= false)  -- true if nil or true
            
            if hasFuel and notDeactivated then
                count = count + 1
            end

            -- Discover neighbours through ALL connected buildings (not just active gens)
            if currentGen.connectedBuildings then
                -- connectedBuildings / connectedGenerators are Kahlua-deserialized (string numeric keys)
                for i, bid in pairs(currentGen.connectedBuildings) do
                    local bd = StateManager.GetBuilding(bid)
                    -- Lazy Xref: repair stale bld_def_... IDs in-place (see CalculateFuelConsumption)
                    if not bd then
                        local genKeyLocal = string.format("%d_%d_%d",
                            currentGen.x, currentGen.y, currentGen.z)
                        local allBlds = StateManager.GetAllBuildings() or {}
                        for _, bld in pairs(allBlds) do
                            if bld and bld.connectedGenerators then
                                for _, gk in pairs(bld.connectedGenerators) do
                                    if gk == genKeyLocal then
                                        currentGen.connectedBuildings[i] = bld.id
                                        StateManager.AddGenerator(currentGen)
                                        bd = bld
                                        break
                                    end
                                end
                            end
                            if bd then break end
                        end
                    end
                    if bd and bd.connectedGenerators then
                        for _, genKey in pairs(bd.connectedGenerators) do
                            local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                            if gx then
                                local gid = LKS_EletricidadeConstrucao.Data.Generator.MakeId(tonumber(gx), tonumber(gy), tonumber(gz))
                                if not visited[gid] then
                                    local nextGen = StateManager.GetGenerator(gid)
                                    if nextGen then
                                        table.insert(toVisit, nextGen)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if count < 1 then return 1 end
    return count
end

-- Local reference for internal use (after function is defined in namespace)
local CountActivePoolGenerators = LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators

-- ============================================================================
-- HELPERS
-- ============================================================================

--- Returns the vanilla sandbox GeneratorFuelConsumption multiplier,
--- normalised so that the vanilla default (0.1) maps to 1.0.
---   sandbox 0.0 → 0.0  (infinite fuel)
---   sandbox 0.1 → 1.0  (normal / no change to V2 base rate)
---   sandbox 0.5 → 5.0  (5× faster)
---   sandbox 1.0 → 10.0 (10× faster)
function LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier()
    local ok, value = pcall(function()
        return getSandboxOptions():getOptionByName("GeneratorFuelConsumption"):getValue()
    end)
    if ok and type(value) == "number" and value >= 0 then
        -- Use sandbox value directly (0.1 = vanilla default)
        return value
    end
    print("failed to get sandbox fuel multiplier, using default 0.1")
    return 0.1  -- fallback: vanilla default
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize fuel manager
function LKS_EletricidadeConstrucao.Fuel.Manager.Initialize()
    if _isInitialized then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("Fuel Manager already initialized", "Fuel")
        return
    end
    
    local Constants = LKS_EletricidadeConstrucao.Constants
    _updateInterval = Constants.FUEL.UPDATE_INTERVAL or 1000
    _lastWorldMinutes = GetWorldMinutes()
    
    _isInitialized = true

    -- NOTE: EveryOneMinute registration is handled in LKS_EletricidadeConstrucao_ServerInit.lua
    -- Duplicate registration here could cause conflicts or double-processing
    -- Commenting out the duplicate registration
    --[[
    -- Register periodic update on EveryOneMinute for consistent fuel ticks
    if not _eventRegistered and Events and Events.EveryOneMinute then
        Events.EveryOneMinute.Add(LKS_EletricidadeConstrucao.Fuel.Manager.Update)
        _eventRegistered = true
        LKS_EletricidadeConstrucao.Core.Logger.Info("Fuel Manager registered EveryOneMinute handler", "Fuel")
        print("[LKS_EletricidadeConstrucao_Fuel] Registered EveryOneMinute handler")
    else
        LKS_EletricidadeConstrucao.Core.Logger.Warn("Fuel Manager could not register EveryOneMinute (Events missing?)", "Fuel")
        print("[LKS_EletricidadeConstrucao_Fuel] Failed to register EveryOneMinute")
    end
    --]]
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Fuel Manager initialized (interval: " .. _updateInterval .. "ms)", "Fuel")
end

--- Check if fuel manager is initialized
--- @return boolean True if initialized
function LKS_EletricidadeConstrucao.Fuel.Manager.IsInitialized()
    return _isInitialized
end

-- ============================================================================
-- UPDATE CYCLE
-- ============================================================================

--- Update all active generators
--- Called periodically to process fuel consumption
function LKS_EletricidadeConstrucao.Fuel.Manager.Update()
    if not _isInitialized then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("Fuel Manager Update called before init", "Fuel")
        return
    end
    
    local currentWorldMinutes = GetWorldMinutes()
    -- Snapshot world age (hours) for per-generator delta calculations.
    -- Each generator compares its own Gen_LastCalcWorldAge against this.
    local gt = getGameTime and getGameTime()
    _currentWorldAge = gt and (gt:getWorldAgeHours() or 0) or (currentWorldMinutes / 60)

    -- deltaMinutes is still used for uptime stats only
    local deltaMinutes = currentWorldMinutes - _lastWorldMinutes
    if deltaMinutes < 0 then deltaMinutes = 0 end
    local uptimeSeconds = deltaMinutes * 60

    -- Sync generator runtime flags from live IsoGenerators so activation/condition
    -- changes are reflected in the state before filtering for active ones. Fuel
    -- stays authoritative in state so we can override vanilla drain.
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local anyStateChange = false
    for _, genData in pairs(StateManager.GetAllGenerators()) do
        local genObj = getGeneratorFromSquare(genData.x, genData.y, genData.z)
        if genObj then
            -- Repair missing Gen_BuildingPoolID from state on reload
            local md = genObj:getModData()
            local restorablePoolId = nil
            if md and md.LKS_EletricidadeConstrucao_DisconnectSuppressed then
                restorablePoolId = nil
            elseif md and (not md.Gen_BuildingPoolID) and genData.id and not _poolRestoreSeen[genData.id] then
                restorablePoolId = FindRestorablePoolId(StateManager, genData)
            end
            -- Only restore the pool link if StateManager still has connectedBuildings.
            -- After a deliberate disconnect, buildingData.connectedGenerators no longer
            -- references this generator, so FindRestorablePoolId() returns nil and we
            -- do not re-link it from stale generator state.
            if restorablePoolId then
                local poolId = restorablePoolId
                md.Gen_BuildingPoolID = poolId
                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                    genObj:transmitModData()
                end
                anyStateChange = true
                _poolRestoreSeen[genData.id] = true
                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format("Restored Gen_BuildingPoolID=%s for %s", md.Gen_BuildingPoolID, genData.id or "?"), "Fuel")
                -- print(string.format("[LKS_EletricidadeConstrucao_Fuel] Restored pool %s to generator %s", md.Gen_BuildingPoolID, genData.id or "?"))

                -- Also ensure the building knows about this generator so Distributor can sync stats.
                if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
                    local bld = LKS_EletricidadeConstrucao.Core.StateManager.GetBuilding(poolId)
                    if bld then
                        bld.connectedGenerators = bld.connectedGenerators or {}
                        local genKey = string.format("%d_%d_%d", genData.x or 0, genData.y or 0, genData.z or 0)
                        local exists = false
                        -- connectedGenerators is Kahlua-deserialized (string numeric keys)
                        for _, k in pairs(bld.connectedGenerators) do
                            if k == genKey then exists = true; break end
                        end
                        if not exists then
                            table.insert(bld.connectedGenerators, genKey)
                            LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format("Linked generator %s back to building %s", genKey, poolId), "Fuel")
                        end
                    end
                end

                -- Persist the restored pool link even if building data was already present.
                LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
            end
            -- Sync runtime state from IsoObject
            local activated = genObj:isActivated() or false
            local cond      = genObj:getCondition() or 0
            if genData.activated ~= activated or genData.condition ~= cond then
                genData.activated   = activated
                genData.condition   = cond
                anyStateChange = true
            end
            
            -- Fuel sync: IsoObject is now authoritative.
            -- Always pull the live value into the state cache; never overwrite
            -- the IsoObject from state (UpdateGenerator is the only writer to
            -- the IsoObject and it stamps Gen_LastCalcWorldAge at the same time).
            local liveFuel    = genObj:getFuel() or 0
            local stateFuel   = genData.fuelAmount or 0
            local lastSynced  = genData.lastSyncedFuel

            if liveFuel ~= stateFuel then
                genData.fuelAmount = liveFuel
                anyStateChange = true
            end
            if lastSynced ~= nil and liveFuel > lastSynced + 0.5 then
                -- fuel went UP since our last setFuel → player manually refuelled
                LKS_EletricidadeConstrucao.Core.Logger.Debug(
                    string.format("Detected manual refuel: %.3f -> %.3f for %s", stateFuel, liveFuel, genData.id or "?"),
                    "Fuel"
                )
            end
            genData.lastSyncedFuel = liveFuel
        end
        
        -- Safety check: generator can't be activated with no fuel
        -- Fixes inconsistent state from previous runs (before continuous fuel model)
        if genData.activated and (genData.fuelAmount or 0) <= 0 then
            genData.activated = false
            anyStateChange = true
            LKS_EletricidadeConstrucao.Core.Logger.Warn(
                string.format("Generator %s was activated but has no fuel - deactivating", genData.id),
                "Fuel"
            )
            
            -- Also deactivate the live IsoObject so isBuildingPoweredInline sees false
            if genObj then
                genObj:setActivated(false)
                genData.lastSyncedFuel = 0
            end
            
            -- Update connected buildings power state immediately
            if genData.connectedBuildings and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
                -- connectedBuildings is Kahlua-deserialized (string numeric keys)
                for _, buildingId in pairs(genData.connectedBuildings) do
                    if LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding then
                        pcall(LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding, buildingId)
                    end
                end
            end
        end
    end
    if anyStateChange then
        StateManager.MarkDirty()
    end
    
    -- Update all active generators using per-generator worldAge delta.
    -- Only processes generators whose chunk is currently loaded (no off-chunk drain).
    -- On first tick after a long absence the full elapsed time is used as deltaSeconds
    -- (catch-up drain). Barrels have already been refuelled above.
    -- B-102: Clear per-tick pool cache so each pool is computed exactly once this tick.
    _perTickPoolCache = {}
    _perTickGenToPool = {}

    local activeGenerators = StateManager.GetActiveGenerators()

    if #activeGenerators > 0 then
        local updatedCount = 0
        for _, genData in ipairs(activeGenerators) do
            -- Require a loaded IsoObject: no drain while off-chunk.
            local genObject = getGeneratorFromSquare(genData.x, genData.y, genData.z)
            if genObject then
                local md = genObject:getModData()
                local lastCalcAge = md.Gen_LastCalcWorldAge  -- nil on first tick
                local genDeltaMinutes
                if lastCalcAge == nil then
                    -- First tick ever for this generator: treat as one normal minute.
                    genDeltaMinutes = 1
                else
                    genDeltaMinutes = (_currentWorldAge - lastCalcAge) * 60
                end
                if genDeltaMinutes >= 1 then
                    local genDeltaSeconds = genDeltaMinutes * 60
                    local fuelBefore = genObject:getFuel() or 0
                    local isCatchup  = genDeltaMinutes > 1.5  -- more than one normal tick = genuine catch-up
                    if isCatchup then
                        LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                            "[FuelManager][CatchUp] START gen=%s fuel=%.3f lastCalcAge=%.4fh currentAge=%.4fh delta=%.2f min (%.0fs)",
                            genData.id, fuelBefore,
                            lastCalcAge or 0, _currentWorldAge,
                            genDeltaMinutes, genDeltaSeconds), "Fuel")
                    end
                    LKS_EletricidadeConstrucao.Fuel.Manager.UpdateGenerator(genData, genDeltaSeconds)
                    if isCatchup then
                        local fuelAfter  = genData.fuelAmount or 0
                        local drained    = fuelBefore - fuelAfter
                        local drainLph   = genDeltaSeconds > 0 and (drained * 3600 / genDeltaSeconds) or 0
                        LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                            "[FuelManager][CatchUp]  END  gen=%s fuelBefore=%.3f fuelAfter=%.3f drained=%.4f (%.3f L/h equiv) pool=%d",
                            genData.id, fuelBefore, fuelAfter, drained, drainLph,
                            LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators(genData)), "Fuel")
                    end
                    updatedCount = updatedCount + 1
                end
            end
            -- off-chunk: skip silently, fuel unchanged until player returns
        end
        
        if updatedCount > 0 then
            StateManager.MarkDirty()
        end
    end
    
    -- Update stats timestamp
    _lastWorldMinutes = currentWorldMinutes
    
    -- Update uptime statistics (use unbounded delta to reflect real elapsed time)
    StateManager.UpdateUptime(uptimeSeconds)
end

-- ============================================================================
-- GENERATOR UPDATE
-- ============================================================================

--- Force immediate fuel calculation for a specific generator (e.g., when heating is toggled)
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate (optional, defaults to 0)
function LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator(x, y, z)
    if not _isInitialized then return end
    z = z or 0
    
    -- Ensure _currentWorldAge is current so UpdateGenerator writes a valid
    -- Gen_LastCalcWorldAge checkpoint (avoids a huge delta on the next real tick).
    local gt = getGameTime and getGameTime()
    if gt then _currentWorldAge = gt:getWorldAgeHours() or _currentWorldAge end
    
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local genKey = x .. "_" .. y .. "_" .. z
    local genData = StateManager.GetGenerator(genKey)
    
    if genData and genData.activated ~= false then
        -- Force a minimal update (1 second) to recalculate fuel rate without consuming fuel
        LKS_EletricidadeConstrucao.Fuel.Manager.UpdateGenerator(genData, 1)
        StateManager.MarkDirty()
        LKS_EletricidadeConstrucao.Core.Logger.Debug(
            string.format("Forced fuel update for generator at %d,%d,%d", x, y, z),
            "Fuel"
        )
    end
end

-- ============================================================================
-- GENERATOR UPDATE
-- ============================================================================

--- Update single generator fuel consumption.
--- IsoObject is the authoritative fuel source: fuel is read from and written to
--- gen:getFuel()/gen:setFuel().  State fuelAmount is kept in sync as a cache for
--- off-chunk power checks (isBuildingPoweredInline) and UI.
--- Gen_LastCalcWorldAge is written to IsoObject moddata so catch-up works
--- correctly even after a GlobalModData deserialization failure.
--- @param generatorData GeneratorData Generator to update
--- @param deltaSeconds number Time delta in seconds (may be large for catch-up)
function LKS_EletricidadeConstrucao.Fuel.Manager.UpdateGenerator(generatorData, deltaSeconds)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    local Logger = LKS_EletricidadeConstrucao.Core.Logger
    
    if not generatorData then
        LKS_EletricidadeConstrucao.Core.Logger.Error("Generator data is nil", "Fuel")
        return
    end
    
    -- Check if generator is running (uses state cache fuelAmount + activated)
    if not LKS_EletricidadeConstrucao.Data.Generator.IsRunning(generatorData) then
        return
    end
    
    -- IsoObject is authoritative for fuel.  Read live value when chunk is loaded.
    local genObject = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    local chunkLoaded = (genObject ~= nil and Validation.IsGenerator(genObject))
    
    local currentFuel
    if chunkLoaded then
        -- IsoObject is the source of truth
        currentFuel = genObject:getFuel() or 0
        -- Keep state cache current so off-chunk checks stay accurate
        generatorData.fuelAmount = currentFuel
    else
        -- Off-chunk fallback to state cache (should rarely happen: Update() pre-checks)
        currentFuel = generatorData.fuelAmount or 0
    end
    
    -- Calculate fuel consumption
    local fuelConsumed = LKS_EletricidadeConstrucao.Fuel.Manager.CalculateFuelConsumption(generatorData, deltaSeconds)

    if fuelConsumed == -1 then
        -- Generator physically failed (extreme strain or condition reached 0)
        generatorData.activated = false
        if chunkLoaded then
            genObject:setActivated(false)
            genObject:sync()
            genObject:getModData().Gen_LastCalcWorldAge = _currentWorldAge
        end
        if generatorData.connectedBuildings and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            -- connectedBuildings is Kahlua-deserialized (string numeric keys)
            for _, buildingId in pairs(generatorData.connectedBuildings) do
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(buildingId)
            end
        end
        Logger.Info(string.format("Generator %s physically failed due to strain/condition damage", generatorData.id or "?"), "Fuel")
        return
    end

    if fuelConsumed <= 0 then
        -- Still stamp the checkpoint so the next delta is measured from now
        if chunkLoaded then
            genObject:getModData().Gen_LastCalcWorldAge = _currentWorldAge
        end
        Logger.Trace(string.format("[Fuel] No consumption for %s (delta=%.2fs)", generatorData.id or "?", deltaSeconds), "Fuel")
        return
    end
    
    local newFuel = math.max(0, currentFuel - fuelConsumed)
    
    -- Write authoritative fuel to IsoObject + sync state cache
    generatorData.fuelAmount = newFuel
    if chunkLoaded then
        genObject:setFuel(newFuel)
        generatorData.lastSyncedFuel = newFuel
        -- Persist the worldAge checkpoint so catch-up is correct after chunk reload
        genObject:getModData().Gen_LastCalcWorldAge = _currentWorldAge
    end
    
    if newFuel <= 0 then
        generatorData.activated = false
        if chunkLoaded then
            genObject:setActivated(false)
        end
        LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorFuelEmpty(generatorData)
        if generatorData.connectedBuildings and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            -- connectedBuildings is Kahlua-deserialized (string numeric keys)
            for _, buildingId in pairs(generatorData.connectedBuildings) do
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(buildingId)
            end
            local _bldCount = 0
            for _ in pairs(generatorData.connectedBuildings) do _bldCount = _bldCount + 1 end
            Logger.Debug(string.format("Updated %d buildings after generator %s ran out of fuel",
                _bldCount, generatorData.id), "Fuel")
        end
        Logger.Info(string.format("Generator %s ran out of fuel (chunk: %s)", generatorData.id, tostring(chunkLoaded)), "Fuel")
    end
    
    -- Record statistics
    LKS_EletricidadeConstrucao.Core.StateManager.RecordFuelConsumption(fuelConsumed)
    generatorData.lastUpdateTime = getTimestampMs()
    
    local lph = deltaSeconds > 0 and (fuelConsumed * 3600 / deltaSeconds) or 0
    Logger.Debug(string.format("Generator %s consumed %.4f fuel (%.3f L/h) (remaining: %.3f -> %.3f) [chunk: %s]",
        generatorData.id, fuelConsumed, lph, currentFuel, newFuel, tostring(chunkLoaded)), "Fuel")
end

-- ============================================================================
-- FUEL CALCULATION
-- ============================================================================

--- Calculate fuel consumption for a time period
--- @param generatorData GeneratorData Generator data
--- @param deltaSeconds number Time delta in seconds
--- @return number Fuel consumed
function LKS_EletricidadeConstrucao.Fuel.Manager.CalculateFuelConsumption(generatorData, deltaSeconds)
    local Config    = LKS_EletricidadeConstrucao.Config
    local Constants = LKS_EletricidadeConstrucao.Constants
    local Logger    = LKS_EletricidadeConstrucao.Core.Logger

    -- Sum type-specific fuel consumption from all active consumers
    local baseIdleRate = Constants.FUEL.BASE_CONSUMPTION_RATE or 0.0001  -- baseline per-second drain
    local baseFuelRate = 0.0
    local activeCount = 0  -- Track count for logging
    
    -- Sum fuel consumption from ALL buildings in the pool (not just this generator's buildings)
    -- This ensures equal fuel sharing across all generators in the same pool
    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    
    -- Step 1: Recursively discover ALL generators in this pool
    local poolGenerators = {}  -- Set of all generator IDs in the pool
    local poolBuildings = {}   -- Set of all building IDs in the pool
    -- Flag set when PoolFallback is used: CountActivePoolGenerators would fail BFS for the
    -- same reason (buildings not in state yet), so we skip it and use cachedPoolActive instead.
    local usedPoolFallback = false

    -- ── B-102: Per-tick pool cache fast path ──────────────────────────────────
    -- If a sibling generator in this pool already computed the pool load this tick,
    -- reuse the cached result instead of repeating the full BFS + consumer scan.
    do
        local cacheKey = _perTickGenToPool[generatorData.id]
        if cacheKey then
            local cached = _perTickPoolCache[cacheKey]
            if cached then
                local poolActive2 = cached.poolActive
                local perGenRate  = cached.totalPoolRate / poolActive2

                -- Per-gen sprite modifier (mirrors the cache-miss path below)
                local genObjC = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
                local fuelMultC = 1.0
                if genObjC then
                    local spriteC = genObjC.getSpriteName and genObjC:getSpriteName()
                        or (genObjC.getSprite and genObjC:getSprite() and genObjC:getSprite():getName())
                    generatorData.cachedSprite = spriteC
                    local modsC = GENERATOR_TYPE_MODIFIERS[spriteC or ""]
                    if modsC then
                        fuelMultC = modsC.fuel or 1.0
                        generatorData.cachedFuelMult   = fuelMultC
                        generatorData.cachedStrainMult = modsC.strain or 1.0
                    end
                    local sameSpriteC = CountSameSpriteGenerators(genObjC, generatorData)
                    fuelMultC = ApplyDiminishing(fuelMultC, sameSpriteC)
                else
                    fuelMultC = generatorData.cachedFuelMult or 1.0
                end

                if generatorData.customFuelRate then
                    perGenRate = generatorData.customFuelRate
                end

                local strainMultC = 1.0
                if Config.StrainSystemEnabled then
                    -- B-103: pass the pool's building set from cache so StrainCalculator
                    -- uses the same topology as the primary BFS and avoids stale-ID divergence.
                    strainMultC = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData, cached.poolBuildings, poolActive2)
                end

                local effectiveRateC = perGenRate * fuelMultC * strainMultC
                local fuelConsumedC  = effectiveRateC * deltaSeconds

                if genObjC then
                    local gmdC = genObjC:getModData()
                    gmdC.Gen_Stats_FuelRateLph = effectiveRateC * poolActive2 * 3600
                    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                        genObjC:transmitModData()
                    end
                end

                Logger.Debug(string.format(
                    "[FuelCalc][Cached] gen=%s poolActive=%d perGen=%.6f fuelMult=%.3f strainMult=%.3f eff=%.6f consumed=%.6f",
                    generatorData.id or "?", poolActive2, perGenRate, fuelMultC, strainMultC,
                    effectiveRateC, fuelConsumedC), "Fuel")

                if Config.StrainSystemEnabled and LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage then
                    local failedC = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage(generatorData, deltaSeconds)
                    if failedC then return -1 end
                end

                return fuelConsumedC
            end
        end
    end
    -- ─────────────────────────────────────────────────────────────────────────

    if StateManager then
        local function RepairMissingPoolLinks(currentGen)
            if not currentGen or currentGen.x == nil or currentGen.y == nil or currentGen.z == nil then
                return false
            end

            local genObj = getGeneratorFromSquare(currentGen.x, currentGen.y, currentGen.z)
            local genMD = genObj and genObj:getModData() or nil
            local genKey = string.format("%d_%d_%d", currentGen.x, currentGen.y, currentGen.z)

            local function Attach(buildingId, buildingData)
                if not buildingId or not buildingData then return false end

                currentGen.connectedBuildings = currentGen.connectedBuildings or {}
                if LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
                        and LKS_EletricidadeConstrucao.Data.Generator.AddBuilding then
                    LKS_EletricidadeConstrucao.Data.Generator.AddBuilding(currentGen, buildingId)
                else
                    local hasBid = false
                    for _, bid in pairs(currentGen.connectedBuildings) do
                        if bid == buildingId then hasBid = true; break end
                    end
                    if not hasBid then
                        table.insert(currentGen.connectedBuildings, buildingId)
                    end
                end

                buildingData.connectedGenerators = buildingData.connectedGenerators or {}
                local hasGen = false
                for _, gk in pairs(buildingData.connectedGenerators) do
                    if gk == genKey then hasGen = true; break end
                end
                if not hasGen then
                    table.insert(buildingData.connectedGenerators, genKey)
                end

                StateManager.AddGenerator(currentGen)
                if StateManager.MarkDirty then
                    StateManager.MarkDirty()
                end

                Logger.Info(string.format(
                    "[PoolBFS] Repaired missing pool back-link: %s -> %s",
                    currentGen.id or "?", buildingId), "Fuel")
                return true
            end

            local livePoolId = genMD and genMD.Gen_BuildingPoolID or nil
            if livePoolId then
                local liveBuilding = StateManager.GetBuilding and StateManager.GetBuilding(livePoolId) or nil
                if liveBuilding and Attach(livePoolId, liveBuilding) then
                    return true
                end
            end

            local buildingCount = 0
            for bid, buildingData in pairs(StateManager.GetAllBuildings() or {}) do
                buildingCount = buildingCount + 1
                if buildingData and buildingData.connectedGenerators then
                    for _, gk in pairs(buildingData.connectedGenerators) do
                        if gk == genKey then
                            if genMD and not genMD.Gen_BuildingPoolID then
                                genMD.Gen_BuildingPoolID = bid
                                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                    genObj:transmitModData()
                                end
                            end
                            return Attach(bid, buildingData)
                        end
                    end
                end
            end

            local debugKey = tostring(livePoolId) .. "|" .. tostring(buildingCount)
            if currentGen._poolRepairDebugKey ~= debugKey then
                currentGen._poolRepairDebugKey = debugKey
                Logger.Warn(string.format(
                    "[PoolBFS] Repair failed for gen=%s livePool=%s buildingsInState=%d",
                    currentGen.id or "?", tostring(livePoolId), buildingCount), "Fuel")
            end

            return false
        end

        -- Repair the starting generator before falling back to a solo pool.
        if not generatorData.connectedBuildings or LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(generatorData.connectedBuildings) then
            RepairMissingPoolLinks(generatorData)
        end
        if not generatorData.connectedBuildings or LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(generatorData.connectedBuildings) then
            Logger.Warn(string.format(
                "[PoolBFS] gen=%s has no connectedBuildings - pool will be computed as solo",
                generatorData.id), "Fuel")
        end
        
        local toVisit = {generatorData}  -- Start with the current generator data directly
        local visited = {}
        
        while #toVisit > 0 do
            local currentGen = table.remove(toVisit)
            if currentGen and currentGen.id and not visited[currentGen.id] then
                visited[currentGen.id] = true
                poolGenerators[currentGen.id] = true
                
                -- Process this generator's connected buildings
                if currentGen.connectedBuildings then
                    for i, bid in pairs(currentGen.connectedBuildings) do
                        local bd = StateManager.GetBuilding(bid)

                        -- ── Lazy Xref: fix stale bld_def_... IDs on the fly ────────────
                        -- If the building is not found under the stored ID (common with
                        -- legacy bld_def_XXXXXX keys that were never migrated), do a
                        -- reverse lookup: scan all buildings for one whose
                        -- connectedGenerators list includes this generator's X_Y_Z key.
                        -- Repair the ID in connectedBuildings immediately so subsequent
                        -- fuel ticks find it without re-scanning.
                        if not bd then
                            local genKeyLocal = string.format("%d_%d_%d",
                                currentGen.x, currentGen.y, currentGen.z)
                            local allBlds = StateManager.GetAllBuildings() or {}
                            for _, bld in pairs(allBlds) do
                                if bld and bld.connectedGenerators then
                                    for _, gk in pairs(bld.connectedGenerators) do
                                        if gk == genKeyLocal then
                                            Logger.Info(string.format(
                                                "[PoolBFS] Lazy-Xref: %s connectedBuildings[%d] %s → %s",
                                                currentGen.id, i, bid, bld.id), "Fuel")
                                            currentGen.connectedBuildings[i] = bld.id
                                            StateManager.AddGenerator(currentGen)
                                            bd = bld
                                            break
                                        end
                                    end
                                end
                                if bd then break end
                            end
                        end
                        -- ────────────────────────────────────────────────────────────────

                        if bd and bd.connectedGenerators then
                            -- Add all generators from this building to visit queue
                            for _, genKey in pairs(bd.connectedGenerators) do
                                local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                                if gx then
                                    local gid = LKS_EletricidadeConstrucao.Data.Generator.MakeId(tonumber(gx), tonumber(gy), tonumber(gz))
                                    if not visited[gid] then
                                        local nextGen = StateManager.GetGenerator(gid)
                                        if nextGen then
                                            table.insert(toVisit, nextGen)
                                        end
                                    end
                                end
                            end
                        elseif not bd then
                            -- Building not in state - pool BFS cannot traverse; will cause pool split
                            Logger.Warn(string.format(
                                "[PoolBFS] gen=%s: building %s not in state - pool traversal broken",
                                currentGen.id, bid), "Fuel")
                        end
                    end
                end
            end
        end
        
        -- DEBUG: Log discovered pool
        local genCount = 0
        for _ in pairs(poolGenerators) do genCount = genCount + 1 end
        -- print(string.format("[PoolDebug] gen=%s discovered %d generators in pool", generatorData.id, genCount))
        
        -- Step 2: Collect buildings from ALL generators in pool (active OR inactive).
        -- When a generator is deactivated, the remaining active generator(s) must
        -- carry the full pool load – so we count ALL buildings, then divide by
        -- the number of currently-active generators (poolActive, done below).
        -- Deduplicate by physical location (x_y_z): if the same building exists under
        -- both a canonical (bld_X_Y_Z) and a stale legacy (bld_def_...) ID, only count
        -- it once to avoid doubling appliance/heating/strain calculations.
        local _poolBuildingLocations = {}  -- "x_y_z" -> true  (dedup guard)
        for genId, _ in pairs(poolGenerators) do
            local gd = StateManager.GetGenerator(genId)
            if gd and gd.connectedBuildings then
                -- connectedBuildings is Kahlua-deserialized (string numeric keys)
                for _, bid in pairs(gd.connectedBuildings) do
                    local bd = StateManager.GetBuilding(bid)
                    if bd then
                        local locKey = (bd.x or 0) .. "_" .. (bd.y or 0) .. "_" .. (bd.z or 0)
                        if not _poolBuildingLocations[locKey] then
                            _poolBuildingLocations[locKey] = true
                            poolBuildings[bid] = true
                        end
                    else
                        poolBuildings[bid] = true  -- location unknown, include anyway
                    end
                end
            end
        end
        
        local bldCount = 0
        for _ in pairs(poolBuildings) do bldCount = bldCount + 1 end
        -- print(string.format("[PoolDebug] gen=%s: total %d poolBuildings collected", generatorData.id, bldCount))
        
        -- Step 3: Sum consumers across all pool buildings from active generators
        local anyBuildingFound = false
        for poolBid, _ in pairs(poolBuildings) do
            local bd = StateManager.GetBuilding(poolBid)
            if bd then
                anyBuildingFound = true
                if bd.powerConsumers then
                -- powerConsumers is Kahlua-deserialized (string numeric keys); pairs required
                for _, c in pairs(bd.powerConsumers) do
                    if c.isActive then
                        -- Use type-specific rate (L/h), convert to L/s
                        local rateLph = c.fuelConsumptionLph or Constants.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH
                        -- print(string.format("[PoolConsumers] gen=%s consumer type=%s fuelLph=%.6f isActive=%s", 
                        --     generatorData.id, c.applianceType or "unknown", rateLph, tostring(c.isActive)))
                        baseFuelRate = baseFuelRate + (rateLph / 3600)
                        activeCount = activeCount + 1
                    end
                end
                end
            end
        end

        -- Compute pool heating from BUILDINGS (pool-level attribute, not per-generator).
        -- Heating sources (space heaters, radiators) belong to a building, so a single
        -- building's sourceCount is authoritative for the whole pool – no double-counting
        -- across generators in the same pool.
        -- Falls back to per-generator fields (heatingEnabled/heatingSourceCount) for saves
        -- that pre-date the building-level heating fields (backward compat).
        local totalHeatingLoad   = 0
        local heatingPerSource   = (Constants.FUEL.CONSUMPTION_RATE_HEATING_PER_SOURCE_LPH or 0.02)  / 3600
        local heatingPerDegree   = (Constants.FUEL.CONSUMPTION_RATE_HEATING_PER_DEGREE_LPH or 0.002) / 3600
        local buildingHeatingFound = false

        for poolBid, _ in pairs(poolBuildings) do
            local bd = StateManager.GetBuilding(poolBid)
            if bd and bd.heatingEnabled and bd.heatingSourceCount and bd.heatingSourceCount > 0 then
                buildingHeatingFound = true
                local targetTemp  = bd.heatingTargetTemp or 22
                local ratePerSrc  = heatingPerSource + heatingPerDegree * math.max(0, targetTemp - 20)
                local bldHeating  = ratePerSrc * bd.heatingSourceCount
                totalHeatingLoad  = totalHeatingLoad + bldHeating
                Logger.Debug(
                    string.format("[PoolHeating] building=%s sources=%d temp=%.1f heating=%.8f L/s (%.4f L/h)",
                        poolBid, bd.heatingSourceCount, targetTemp, bldHeating, bldHeating * 3600),
                    "Fuel"
                )
            end
        end

        -- Backward-compat: if no building-level heating data found, fall back to
        -- per-generator heatingSourceCount (written by pre-B58 Heating.SyncToGenerators).
        -- Risk of double-counting is avoided because this path is only used when buildings
        -- don't yet have the heatingSourceCount field (cold migration from older saves).
        if not buildingHeatingFound then
            for genId, _ in pairs(poolGenerators) do
                local gd = StateManager.GetGenerator(genId)
                if gd and gd.heatingEnabled and gd.heatingSourceCount and gd.heatingSourceCount > 0 then
                    local targetTemp = gd.heatingTargetTemp or 22
                    local ratePerSrc = heatingPerSource + heatingPerDegree * math.max(0, targetTemp - 20)
                    local genHeating = ratePerSrc * gd.heatingSourceCount
                    totalHeatingLoad = totalHeatingLoad + genHeating
                    Logger.Debug(
                        string.format("[PoolHeating][GenFallback] gen=%s sources=%d temp=%.1f heating=%.8f L/s (%.4f L/h)",
                            gd.id, gd.heatingSourceCount, targetTemp, genHeating, genHeating * 3600),
                        "Fuel"
                    )
                end
            end
        end

        -- Full pool total = appliances (baseFuelRate) + heating
        local fullPoolTotal = baseFuelRate + totalHeatingLoad

        -- PoolFallback: if buildings were expected (poolBuildings not empty) but NONE were
        -- found in state, use the cached pool total from the last live session.
        -- The cache stores appliances + heating together so the fallback is complete.
        -- NOTE: next() is not available in Kahlua (PZ's Lua VM) - use pairs to check emptiness
        local anyBuildingsExpected = false
        for _ in pairs(poolBuildings) do anyBuildingsExpected = true; break end
        if not anyBuildingFound and anyBuildingsExpected and generatorData.cachedRealPoolTotalLps then
            Logger.Info(
                string.format("[PoolFallback] gen=%s buildings not in state yet – using cached pool total %.8f L/s (%.4f L/h), cachedPoolActive=%d",
                    generatorData.id, generatorData.cachedRealPoolTotalLps, generatorData.cachedRealPoolTotalLps * 3600,
                    generatorData.cachedPoolActive or 1),
                "Fuel")
            baseFuelRate = generatorData.cachedRealPoolTotalLps
            usedPoolFallback = true  -- skip CountActivePoolGenerators below (it would also fail BFS)
        else
            -- Use the freshly computed total and persist it for future restarts.
            baseFuelRate = fullPoolTotal

            -- Cache the FULL pool total (appliances + heating) so PoolFallback on the next
            -- restart includes both components.  Flush via AddGenerator (not just MarkDirty)
            -- to write into LKS_EletricidadeConstrucaoV2_GeneratorIndex, the only GlobalModData key
            -- that reliably survives PZ exit.
            if anyBuildingFound or totalHeatingLoad > 0 then
                local newCache = fullPoolTotal
                local oldCache = generatorData.cachedRealPoolTotalLps or 0
                generatorData.cachedRealPoolTotalLps = newCache
                if math.abs(newCache - oldCache) / math.max(oldCache, 1e-9) > 0.05 then
                    StateManager.AddGenerator(generatorData)
                else
                    StateManager.MarkDirty()
                end
            end
        end
    end
    
    -- Minimum: idle motor consumption when running but no active consumers.
    -- Use the dedicated idle constant (0.0002 L/h), NOT the appliance default,
    -- to avoid inflating low-load buildings (e.g. 1 light = 0.002 L/h, not 0.04).
    local idleRatePerSec = (Constants.FUEL.CONSUMPTION_IDLE_LPH or 0.0002) / 3600
    if baseFuelRate < idleRatePerSec then
        baseFuelRate = idleRatePerSec
    end

    -- Heating and appliances were already summed inside the StateManager block above.
    -- baseFuelRate now contains the full pool total (appliances + heating) or the
    -- PoolFallback cached value, whichever applied.

    Logger.Debug(
        string.format("[PoolTotal] gen=%s appliances+heating=%.8f L/s (%.4f L/h) before pool division",
            generatorData.id, baseFuelRate, baseFuelRate * 3600),
        "Fuel"
    )
    
    -- NOW divide the total pool load (appliances + heating) by active generators.
    -- When PoolFallback fired, CountActivePoolGenerators would fail BFS for the same reason
    -- (buildings not in state yet) and return 1, charging each generator the full pool rate.
    -- Use cachedPoolActive (saved from the last in-chunk tick) instead.
    local poolActive
    if usedPoolFallback then
        poolActive = generatorData.cachedPoolActive or 1
    else
        poolActive = CountActivePoolGenerators(generatorData)
        -- Persist the live pool size so it's available if a restart happens off-chunk.
        -- (anyBuildingFound is block-scoped inside `if StateManager then`; if we reached
        --  this branch, PoolFallback did NOT fire, meaning fresh BFS data was used.)
        if StateManager and poolActive >= 1 then
            if (generatorData.cachedPoolActive or 0) ~= poolActive then
                generatorData.cachedPoolActive = poolActive
                StateManager.MarkDirty()
            end
        end
    end
    -- B-102: Capture pool-level total before per-gen division; store in tick cache so
    -- sibling generators can skip their own BFS + consumer scan this tick.
    local totalPoolRate_ForCache = baseFuelRate
    baseFuelRate = baseFuelRate / poolActive

    _perTickPoolCache[generatorData.id] = {
        totalPoolRate = totalPoolRate_ForCache,
        poolActive    = poolActive,
        poolBuildings = poolBuildings,  -- B-103: shared with StrainCalculator to avoid stale-ID BFS
    }
    for gid in pairs(poolGenerators) do
        _perTickGenToPool[gid] = generatorData.id
    end

    Logger.Debug(
        string.format("[PoolDivision] gen=%s poolActive=%d afterDivision=%.8f L/s (%.4f L/h)",
            generatorData.id, poolActive, baseFuelRate, baseFuelRate * 3600),
        "Fuel"
    )

    -- Sprite-specific fuel/strain modifiers
    -- Cache sprite data in generatorData for chunk-independent calculations
    local genObj = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    local fuelMult = 1.0
    local strainMultType = 1.0
    local sameSpriteCount = 1
    
    if genObj then
        -- Chunk is loaded - get fresh sprite data and cache it
        local sprite = genObj.getSpriteName and genObj:getSpriteName() or (genObj.getSprite() and genObj:getSprite() and genObj:getSprite():getName())
        generatorData.cachedSprite = sprite
        
        local mods = GENERATOR_TYPE_MODIFIERS[sprite or ""]
        if mods then
            fuelMult = mods.fuel or fuelMult
            strainMultType = mods.strain or strainMultType
        end
        
        -- Cache base multipliers (before diminishing) for offchunk use
        generatorData.cachedFuelMult = fuelMult
        generatorData.cachedStrainMult = strainMultType
        
        -- Apply diminishing returns for multiple generators of the same sprite
        sameSpriteCount = CountSameSpriteGenerators(genObj, generatorData)
        fuelMult = ApplyDiminishing(fuelMult, sameSpriteCount)
        strainMultType = ApplyDiminishing(strainMultType, sameSpriteCount)
    else
        -- Chunk not loaded - use cached values (no diminishing, we don't know sameSpriteCount offchunk)
        fuelMult = generatorData.cachedFuelMult or 1.0
        strainMultType = generatorData.cachedStrainMult or 1.0
    end

    if generatorData.customFuelRate then
        baseFuelRate = generatorData.customFuelRate
    end

    -- Strain multiplier (caching handled internally by StrainCalculator)
    -- Pass poolBuildings so StrainCalculator uses the same lazy-Xref-repaired topology
    -- instead of doing its own BFS (which would diverge for generators with stale IDs).
    local strainMultiplier = 1.0
    if Config.StrainSystemEnabled then
        strainMultiplier = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData, poolBuildings, poolActive)
    end

    local effectiveFuelRate = baseFuelRate * fuelMult * strainMultiplier
    local fuelConsumed = effectiveFuelRate * deltaSeconds
    local fuelRateLph = effectiveFuelRate * 3600

    -- Calculate TOTAL pool consumption including all multipliers
    -- effectiveFuelRate is per-generator after division, so multiply by poolActive to get pool total
    -- This gives an accurate total if all generators are identical, or an average-based total if they differ
    local poolTotalRateLph = effectiveFuelRate * poolActive * 3600

    -- Write TOTAL pool consumption to ModData for UI display (NOT per-generator rate)
    -- This shows the total fuel consumption of the entire pool, regardless of how many generators are active
    if genObj then
        local gmd = genObj:getModData()
        gmd.Gen_Stats_FuelRateLph = poolTotalRateLph
        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
            genObj:transmitModData()
        end
    end

    Logger.Debug(
        string.format("[FuelCalc] gen=%s poolActive=%d base=%.6f fuelMult=%.3f strainMult=%.3f eff=%.6f effLph=%.3f poolTotalLph=%.3f consumed=%.6f",
            generatorData.id or "?", poolActive, baseFuelRate, fuelMult, strainMultiplier, effectiveFuelRate, fuelRateLph, poolTotalRateLph, fuelConsumed),
        "Fuel"
    )
    --print(calcMsg)

    -- Apply strain-based condition damage to generator (>100% overload only)
    if Config.StrainSystemEnabled and LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage then
        local failed = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage(generatorData, deltaSeconds)
        if failed then
            -- Generator physically failed — return -1 sentinel so UpdateGenerator can
            -- update state, deactivate IsoObject, and trigger ForceUpdateBuilding
            return -1
        end
    end

    return fuelConsumed
end

--- Compute the current effective fuel rate for a generator and write it to its
--- ModData immediately.  Called by the Distributor on ForceUpdateBuilding so
--- the Info Window shows a value the very first time it opens.
--- @param generatorData GeneratorData
--[[ DEPRECATED: Gen_Stats_FuelRateLph is now written directly in CalculateFuelConsumption()
       from the actual calculated fuel rate. This separate calculation was error-prone
       and only worked in loaded chunks (getGeneratorFromSquare).
function LKS_EletricidadeConstrucao.Fuel.Manager.WriteCurrentFuelRate(generatorData)
    if not generatorData then return end
    local Constants = LKS_EletricidadeConstrucao.Constants
    local Config    = LKS_EletricidadeConstrucao.Config
    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not StateManager then return end

    -- Reuse GetRemainingHours to compute the effective rate (it already has full
    -- pool + heating + strain logic).  We just need the rate, not the hours.
    -- Temporarily ensure fuelAmount is set so IsRunning passes.
    local genObj = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    if not genObj or not genObj:isActivated() then return end

    -- Quick-compute: replicate baseFuelRate from pool consumers (same as
    -- CalculateFuelConsumption but read-only, no side effects).
    local poolBuildings = {}
    local poolGenCoords = {}
    local _rhBuildingLocations = {}  -- "x_y_z" -> true  (dedup guard)
    do
        local toVisit = {generatorData}
        local visited = {}
        while #toVisit > 0 do
            local cg = table.remove(toVisit)
            if cg and cg.id and not visited[cg.id] then
                visited[cg.id] = true
                table.insert(poolGenCoords, {x=cg.x, y=cg.y, z=cg.z})
                if cg.connectedBuildings then
                    for _, bid in pairs(cg.connectedBuildings) do
                        local bd = StateManager.GetBuilding(bid)
                        if bd then
                            local locKey = (bd.x or 0) .. "_" .. (bd.y or 0) .. "_" .. (bd.z or 0)
                            if not _rhBuildingLocations[locKey] then
                                _rhBuildingLocations[locKey] = true
                                poolBuildings[bid] = true
                            end
                        else
                            poolBuildings[bid] = true
                        end
                        if bd and bd.connectedGenerators then
                            for _, gk in pairs(bd.connectedGenerators) do
                                local gx2, gy2, gz2 = string.match(gk, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                                if gx2 then
                                    local gid2 = LKS_EletricidadeConstrucao.Data.Generator.MakeId(tonumber(gx2), tonumber(gy2), tonumber(gz2))
                                    if not visited[gid2] then
                                        local ng = StateManager.GetGenerator(gid2)
                                        if ng then table.insert(toVisit, ng) end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local activePoolGens = 0
    for _, coords in ipairs(poolGenCoords) do
        local go2 = getGeneratorFromSquare(coords.x, coords.y, coords.z)
        if go2 and go2:isActivated() and (go2:getFuel() or 0) > 0 then
            activePoolGens = activePoolGens + 1
        end
    end
    if activePoolGens < 1 then activePoolGens = 1 end

    local baseFuelRate = 0.0
    for bid, _ in pairs(poolBuildings) do
        local bd = StateManager.GetBuilding(bid)
        if bd and bd.powerConsumers then
            -- powerConsumers is Kahlua-deserialized (string numeric keys); pairs required
            for _, c in pairs(bd.powerConsumers) do
                if c.isActive then
                    local rateLph = c.fuelConsumptionLph or Constants.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH
                    baseFuelRate = baseFuelRate + (rateLph / 3600)
                end
            end
        end
    end
    if baseFuelRate < (Constants.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH / 3600) then
        baseFuelRate = Constants.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH / 3600
    end

    -- Collect heating from ACTIVE generators in pool only
    -- Heating is a pool-wide cost, not divided per-generator
    local heatingPerSource = (Constants.FUEL.CONSUMPTION_RATE_HEATING_PER_SOURCE_LPH or 0.02) / 3600
    local heatingPerDegree = (Constants.FUEL.CONSUMPTION_RATE_HEATING_PER_DEGREE_LPH or 0.002) / 3600
    local totalHeatingLoad = 0.0
    
    for _, coords in ipairs(poolGenCoords) do
        local go2 = getGeneratorFromSquare(coords.x, coords.y, coords.z)
        if go2 and go2:isActivated() then
            local gmd2 = go2:getModData()
            if gmd2 and gmd2.HeatingEnabled == true and type(gmd2.HeatingPositions) == "table" then
                local srcCount = 0
                for _, grp in ipairs(gmd2.HeatingPositions) do
                    if type(grp.positions) == "table" then srcCount = srcCount + #grp.positions end
                end
                if srcCount > 0 then
                    local targetTemp = tonumber(gmd2.HeatingTargetTemp) or 22
                    local ratePerSrc = heatingPerSource + heatingPerDegree * math.max(0, targetTemp - 20)
                    totalHeatingLoad = totalHeatingLoad + (ratePerSrc * srcCount)
                end
            end
        end
    end

    -- Calculate TOTAL pool consumption by summing each generator's actual consumption
    -- This mirrors the logic in CalculateFuelConsumption: (appliances + heating) / activeGens * multipliers
    local basePoolRate = baseFuelRate + totalHeatingLoad  -- Appliances + heating (before division)
    local totalPoolLph = 0.0
    
    -- Sum each active generator's share of total load (appliances + heating) with their multipliers
    for _, coords in ipairs(poolGenCoords) do
        local go2 = getGeneratorFromSquare(coords.x, coords.y, coords.z)
        if go2 and go2:isActivated() and (go2:getFuel() or 0) > 0 then
            local gd2 = StateManager.GetGenerator(LKS_EletricidadeConstrucao.Data.Generator.MakeId(coords.x, coords.y, coords.z))
            if gd2 then
                -- Each active generator's share of total pool load (appliances + heating divided)
                local genBaseShare = basePoolRate / activePoolGens
                
                -- Get sprite-specific modifiers for this generator
                local genFuelMult = 1.0
                local genStrainMultType = 1.0
                local sprite = go2.getSpriteName and go2:getSpriteName() or (go2.getSprite() and go2:getSprite() and go2:getSprite():getName())
                local mods = GENERATOR_TYPE_MODIFIERS[sprite or ""]
                if mods then
                    genFuelMult = mods.fuel or genFuelMult
                    genStrainMultType = mods.strain or genStrainMultType
                end

                -- Apply diminishing returns
                local sameSpriteCount = CountSameSpriteGenerators(go2, gd2)
                genFuelMult = ApplyDiminishing(genFuelMult, sameSpriteCount)
                genStrainMultType = ApplyDiminishing(genStrainMultType, sameSpriteCount)

                -- Get strain multiplier
                local genStrainMult = 1.0
                if Config.StrainSystemEnabled then
                    genStrainMult = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(gd2, nil, activePoolGens)
                end

                -- Calculate this generator's actual consumption with multipliers
                local genEffective = genBaseShare * genFuelMult * genStrainMult
                local genLph = genEffective * 3600
                totalPoolLph = totalPoolLph + genLph
            end
        end
    end
    
    -- Store TOTAL pool rate for UI display
    local gmd = genObj:getModData()
    gmd.Gen_Stats_FuelRateLph = totalPoolLph

    -- Sync to clients in MP (no-op in SP)
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        genObj:transmitModData()
    end
end
--]]

--- Get estimated remaining runtime for generator
--- @param generatorData GeneratorData Generator data
--- @return number Hours remaining
function LKS_EletricidadeConstrucao.Fuel.Manager.GetRemainingHours(generatorData)
    local Config = LKS_EletricidadeConstrucao.Config
    local Constants = LKS_EletricidadeConstrucao.Constants
    
    if not LKS_EletricidadeConstrucao.Data.Generator.IsRunning(generatorData) then
        return 0
    end

    -- Sum type-specific fuel consumption from all active consumers
    local baseIdleRate = Constants.FUEL.BASE_CONSUMPTION_RATE or 0.0001
    local baseFuelRate = 0.0
    
    -- Sum fuel consumption from ALL buildings in the pool (recursively discover all generators)
    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    
    -- Step 1: Recursively discover ALL generators in this pool
    local poolGenerators = {}
    local poolBuildings = {}
    
    if StateManager then
        local toVisit = {generatorData}  -- Start with current generator data directly
        local visited = {}
        
        while #toVisit > 0 do
            local currentGen = table.remove(toVisit)
            if currentGen and currentGen.id and not visited[currentGen.id] then
                visited[currentGen.id] = true
                poolGenerators[currentGen.id] = true
                
                if currentGen.connectedBuildings then
                    for _, bid in pairs(currentGen.connectedBuildings) do
                        local bd = StateManager.GetBuilding(bid)
                        if bd and bd.connectedGenerators then
                            for _, genKey in pairs(bd.connectedGenerators) do
                                local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                                if gx then
                                    local gid = LKS_EletricidadeConstrucao.Data.Generator.MakeId(tonumber(gx), tonumber(gy), tonumber(gz))
                                    if not visited[gid] then
                                        local nextGen = StateManager.GetGenerator(gid)
                                        if nextGen then
                                            table.insert(toVisit, nextGen)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Step 2: Collect buildings from ACTIVE generators only.
        -- Deduplicate by physical location to avoid counting the same building twice
        -- when it exists under both a canonical and a stale bld_def_... ID.
        local _cbLocations = {}  -- "x_y_z" -> true  (dedup guard)
        for genId, _ in pairs(poolGenerators) do
            local gd = StateManager.GetGenerator(genId)
            if gd and LKS_EletricidadeConstrucao.Data.Generator.IsRunning(gd) and gd.connectedBuildings then
                for _, bid in pairs(gd.connectedBuildings) do
                    local bd = StateManager.GetBuilding(bid)
                    if bd then
                        local locKey = (bd.x or 0) .. "_" .. (bd.y or 0) .. "_" .. (bd.z or 0)
                        if not _cbLocations[locKey] then
                            _cbLocations[locKey] = true
                            poolBuildings[bid] = true
                        end
                    else
                        poolBuildings[bid] = true
                    end
                end
            end
        end
        
        -- Step 3: Sum consumers across all pool buildings from active generators
        for poolBid, _ in pairs(poolBuildings) do
            local bd = StateManager.GetBuilding(poolBid)
            if bd and bd.powerConsumers then
                -- powerConsumers is Kahlua-deserialized (string numeric keys); pairs required
                for _, c in pairs(bd.powerConsumers) do
                    if c.isActive then
                        -- Use type-specific rate (L/h), convert to L/s
                        local rateLph = c.fuelConsumptionLph or Constants.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH
                        baseFuelRate = baseFuelRate + (rateLph / 3600)
                    end
                end
            end
        end
    end
    
    -- Minimum: ensure generator uses some fuel even if no active consumers
    if baseFuelRate < (Constants.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH / 3600) then
        baseFuelRate = Constants.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH / 3600
    end

    -- Add heating consumption: per placed heat source, scaled by target temperature
    local heatingPerSource2  = (Constants.FUEL.CONSUMPTION_RATE_HEATING_PER_SOURCE_LPH or 0.02)  / 3600
    local heatingPerDegree2  = (Constants.FUEL.CONSUMPTION_RATE_HEATING_PER_DEGREE_LPH or 0.002) / 3600
    local genObj2 = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    if genObj2 then
        local gmd2 = genObj2:getModData()
        if gmd2.HeatingEnabled == true then
            local targetTemp2  = tonumber(gmd2.HeatingTargetTemp) or 22
            local ratePerSrc2  = heatingPerSource2 + heatingPerDegree2 * math.max(0, targetTemp2 - 20)
            local srcCount2 = 0
            if type(gmd2.HeatingPositions) == "table" then
                for _, grp in ipairs(gmd2.HeatingPositions) do
                    if type(grp.positions) == "table" then srcCount2 = srcCount2 + #grp.positions end
                end
            end
            if srcCount2 < 1 then srcCount2 = 1 end
            baseFuelRate = baseFuelRate + ratePerSrc2 * srcCount2
        end
    end

    if generatorData.customFuelRate then
        baseFuelRate = generatorData.customFuelRate
    end

    -- Share load across all active generators in the same pool (matches CalculateFuelConsumption)
    local poolActive = CountActivePoolGenerators(generatorData)
    baseFuelRate = baseFuelRate / poolActive

    -- Sprite-specific fuel/strain modifiers (must match CalculateFuelConsumption)
    -- Use cached values if chunk not loaded
    local fuelMult = 1.0
    local strainMultType = 1.0
    
    if genObj2 then
        -- Chunk loaded - get and cache sprite data
        local sprite = genObj2.getSpriteName and genObj2:getSpriteName() or (genObj2.getSprite() and genObj2:getSprite() and genObj2:getSprite():getName())
        generatorData.cachedSprite = sprite
        
        local mods = GENERATOR_TYPE_MODIFIERS[sprite or ""]
        if mods then
            fuelMult = mods.fuel or fuelMult
            strainMultType = mods.strain or strainMultType
        end
        
        generatorData.cachedFuelMult = fuelMult
        generatorData.cachedStrainMult = strainMultType
        
        -- Apply diminishing returns
        local sameSpriteCount = CountSameSpriteGenerators(genObj2, generatorData)
        fuelMult = ApplyDiminishing(fuelMult, sameSpriteCount)
        strainMultType = ApplyDiminishing(strainMultType, sameSpriteCount)
    else
        -- Chunk not loaded - use cached values
        fuelMult = generatorData.cachedFuelMult or 1.0
        strainMultType = generatorData.cachedStrainMult or 1.0
    end

    -- Strain multiplier (caching handled internally by StrainCalculator)
    local strainMultiplier = 1.0
    if Config.StrainSystemEnabled then
        strainMultiplier = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData, nil, poolActive)
    end

    local effectiveFuelRate = baseFuelRate * fuelMult * strainMultiplier

    if effectiveFuelRate <= 0 then
        return 999999  -- Infinite
    end

    local fuelRatePerHour = effectiveFuelRate * 3600

    -- Write rate to ModData immediately so the UI doesn't show 0 before the
    -- first CalculateFuelConsumption tick (which only runs every game minute).
    local genObjRH = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    if genObjRH then
        local mdRH = genObjRH:getModData()
        if (mdRH.Gen_Stats_FuelRateLph or 0) == 0 then
            mdRH.Gen_Stats_FuelRateLph = fuelRatePerHour
            if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                genObjRH:transmitModData()
            end
        end
    end

    return generatorData.fuelAmount / fuelRatePerHour
end

-- ============================================================================
-- MANUAL OPERATIONS
-- ============================================================================

--- Manually consume fuel from generator
--- @param generatorData GeneratorData Generator data
--- @param amount number Fuel amount to consume
--- @return boolean True if successful
function LKS_EletricidadeConstrucao.Fuel.Manager.ConsumeFuel(generatorData, amount)
    if amount <= 0 then
        return false
    end
    
    local genObject = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    
    if not genObject then
        return false
    end
    
    local newFuel = genObject:getFuel() - amount
    
    if newFuel < 0 then
        newFuel = 0
    end
    
    genObject:setFuel(newFuel)
    generatorData.fuelAmount = newFuel
    generatorData.lastSyncedFuel = newFuel
    
    -- Record statistics
    LKS_EletricidadeConstrucao.Core.StateManager.RecordFuelConsumption(amount)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    if newFuel <= 0 and generatorData.activated then
        genObject:setActivated(false)
        generatorData.activated = false
        LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorFuelEmpty(generatorData)
        
        -- Immediately update power state for all connected buildings
        if generatorData.connectedBuildings and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            local _updCount = 0
            for _, buildingId in pairs(generatorData.connectedBuildings) do
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(buildingId)
                _updCount = _updCount + 1
            end
            Logger.Debug(string.format("Updated %d buildings after fuel removed from generator %s",
                _updCount, generatorData.id), "Fuel")
        end
    end
    
    return true
end

--- Add fuel to generator
--- @param generatorData GeneratorData Generator data
--- @param amount number Fuel amount to add
--- @return boolean True if successful
function LKS_EletricidadeConstrucao.Fuel.Manager.AddFuel(generatorData, amount)
    if amount <= 0 then
        return false
    end
    
    local genObject = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    
    if not genObject then
        return false
    end
    
    local newFuel = genObject:getFuel() + amount
    
    if newFuel > 100 then
        newFuel = 100
    end
    
    genObject:setFuel(newFuel)
    generatorData.fuelAmount = newFuel
    generatorData.lastSyncedFuel = newFuel
    
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Added %.2f fuel to generator %s (total: %.2f)", 
            amount, generatorData.id, newFuel),
        "Fuel"
    )
    
    return true
end

--- Set custom fuel consumption rate for generator
--- @param generatorData GeneratorData Generator data
--- @param fuelRate number|nil Custom fuel rate (nil to use default)
function LKS_EletricidadeConstrucao.Fuel.Manager.SetCustomFuelRate(generatorData, fuelRate)
    generatorData.customFuelRate = fuelRate
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    if fuelRate then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(
            string.format("Set custom fuel rate for %s: %.6f", generatorData.id, fuelRate),
            "Fuel"
        )
    else
        LKS_EletricidadeConstrucao.Core.Logger.Debug(
            string.format("Cleared custom fuel rate for %s", generatorData.id),
            "Fuel"
        )
    end
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Get generator object from coordinates
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate
--- @return IsoGenerator|nil Generator object
function getGeneratorFromSquare(x, y, z)
    local square = getSquare(x, y, z)
    
    if not square then
        return nil
    end
    
    -- Check for generator on square
    local objects = square:getObjects()
    
    if not objects then
        return nil
    end
    
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and instanceof(obj, "IsoGenerator") then
            return obj
        end
    end
    
    return nil
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Print fuel manager status
function LKS_EletricidadeConstrucao.Fuel.Manager.PrintStatus()
    LKS_EletricidadeConstrucao.Print("=== Fuel Manager Status ===")
    LKS_EletricidadeConstrucao.Print("Initialized: " .. tostring(_isInitialized))
    LKS_EletricidadeConstrucao.Print("Update Interval: " .. _updateInterval .. "ms")
    LKS_EletricidadeConstrucao.Print("Last Update: " .. _lastUpdateTime .. "ms")
    
    local activeGenerators = LKS_EletricidadeConstrucao.Core.StateManager.GetActiveGenerators()
    LKS_EletricidadeConstrucao.Print("Active Generators: " .. #activeGenerators)
    
    for _, genData in ipairs(activeGenerators) do
        local hours = LKS_EletricidadeConstrucao.Fuel.Manager.GetRemainingHours(genData)
        LKS_EletricidadeConstrucao.Print(string.format("  %s: %.2f fuel, %.1fh remaining, %.1f%% strain",
            genData.id, genData.fuelAmount, hours, genData.strain))
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Fuel.Manager", "2.0.0")

return LKS_EletricidadeConstrucao.Fuel.Manager
