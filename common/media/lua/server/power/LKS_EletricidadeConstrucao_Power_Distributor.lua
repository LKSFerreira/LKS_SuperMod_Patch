-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao V2: Power Distributor
-- Purpose: Distribute power from active generators to connected buildings
-- Author: AI Assistant
-- Created: 2025

if not LKS_EletricidadeConstrucao then 
    print("[LKS_EletricidadeConstrucao_Power_Distributor] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return 
end

LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao or {}
LKS_EletricidadeConstrucao.Power = LKS_EletricidadeConstrucao.Power or {}
LKS_EletricidadeConstrucao.Power.Distributor = LKS_EletricidadeConstrucao.Power.Distributor or {}

local Distributor = LKS_EletricidadeConstrucao.Power.Distributor
local Logger = LKS_EletricidadeConstrucao.Core.Logger
local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
-- NOTE: LKS_EletricidadeConstrucao.Power.Manager loads AFTER this file alphabetically (Distributor=D < Manager=M),
-- so we cannot capture it as a local at module-load time.  Use inline helpers instead.
local ConsumerScanner = LKS_EletricidadeConstrucao.Building.ConsumerScanner
local POWER_SYNC_KEY = "LKS_EletricidadeConstrucao_BuildingPowerSync"

local function CopyBoundingBox(source)
    if not source then return nil end
    return {
        minX = source.minX,
        minY = source.minY,
        maxX = source.maxX,
        maxY = source.maxY
    }
end

local function SyncBuildingPowerState(buildingData, isPowered)
    if not LKS_EletricidadeConstrucao.IsMP or not LKS_EletricidadeConstrucao.IsMP() then
        return
    end
    if not buildingData or not buildingData.id or not buildingData.boundingBox then
        return
    end

    local packet = ModData.getOrCreate(POWER_SYNC_KEY)
    packet.buildings = packet.buildings or {}

    if isPowered then
        packet.buildings[buildingData.id] = {
            id = buildingData.id,
            x = buildingData.x,
            y = buildingData.y,
            z = buildingData.z or 0,
            boundingBox = CopyBoundingBox(buildingData.boundingBox)
        }
    else
        packet.buildings[buildingData.id] = nil
    end

    ModData.add(POWER_SYNC_KEY, packet)
    ModData.transmit(POWER_SYNC_KEY)
end

--- Inline helper: find an IsoGenerator at world coordinates (x,y,z)
local function findGeneratorAt(x, y, z)
    local cell = getCell()
    if not cell then return nil end
    local sq = cell:getGridSquare(x, y, z)
    if not sq then return nil end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if o and instanceof(o, "IsoGenerator") then return o end
    end
    return nil
end

local function TableContainsValue(t, value)
    if not t then return false end
    for _, v in pairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

local function TableIsEmpty(t)
    if not t then return true end
    for _ in pairs(t) do return false end
    return true
end

local function GeneratorBelongsToBuilding(buildingId, gen, genData)
    if not buildingId then return false end

    if gen then
        local md = gen:getModData()
        if md and md.LKS_EletricidadeConstrucao_DisconnectSuppressed then
            return false
        end
        if md and md.Gen_BuildingPoolID == buildingId then
            return true
        end
    end

    return genData and genData.connectedBuildings
        and TableContainsValue(genData.connectedBuildings, buildingId) or false
end

local function ReplaceGeneratorState(genData)
    if not genData or not genData.id or not StateManager then return end
    if StateManager.RemoveGenerator then
        StateManager.RemoveGenerator(genData.id)
    end
    if StateManager.AddGenerator then
        StateManager.AddGenerator(genData)
    end
end

local function PruneStaleGeneratorLinks(buildingData)
    if not buildingData or not buildingData.connectedGenerators then
        return false
    end

    local cell = getCell()
    local changed = false
    local prunedCount = 0
    local rebuilt = {}
    local stateLoaded = StateManager and StateManager.IsStateLoaded and StateManager.IsStateLoaded()

    for _, genKey in pairs(buildingData.connectedGenerators) do
        local keep = true
        local px, py, pz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")

        if px then
            local gxi, gyi, gzi = tonumber(px), tonumber(py), tonumber(pz)
            if gxi and gyi and gzi then
                local genId = LKS_EletricidadeConstrucao.Data
                    and LKS_EletricidadeConstrucao.Data.Generator
                    and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                    and LKS_EletricidadeConstrucao.Data.Generator.MakeId(gxi, gyi, gzi)
                local genData = genId and StateManager and StateManager.GetGenerator and StateManager.GetGenerator(genId) or nil
                local gen = findGeneratorAt(gxi, gyi, gzi)
                local sq = cell and cell:getGridSquare(gxi, gyi, gzi) or nil

                if gen then
                    keep = GeneratorBelongsToBuilding(buildingData.id, gen, genData)
                    if not keep and genData and genData.connectedBuildings
                            and TableContainsValue(genData.connectedBuildings, buildingData.id)
                            and LKS_EletricidadeConstrucao.Data
                            and LKS_EletricidadeConstrucao.Data.Generator
                            and LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding then
                        LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding(genData, buildingData.id)
                        ReplaceGeneratorState(genData)
                    end
                elseif sq then
                    keep = false
                    if genData and genData.connectedBuildings
                            and TableContainsValue(genData.connectedBuildings, buildingData.id)
                            and LKS_EletricidadeConstrucao.Data
                            and LKS_EletricidadeConstrucao.Data.Generator
                            and LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding then
                        LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding(genData, buildingData.id)
                    end
                    if genData then
                        if not genData.connectedBuildings or TableIsEmpty(genData.connectedBuildings) then
                            if StateManager.RemoveGenerator and genId then
                                StateManager.RemoveGenerator(genId)
                            end
                        else
                            ReplaceGeneratorState(genData)
                        end
                    end
                elseif stateLoaded and not genData then
                    keep = false
                elseif stateLoaded and genData and not GeneratorBelongsToBuilding(buildingData.id, nil, genData) then
                    keep = false
                end
            end
        end

        if keep then
            table.insert(rebuilt, genKey)
        else
            changed = true
            prunedCount = prunedCount + 1
        end
    end

    if not changed then
        return false
    end

    buildingData.connectedGenerators = rebuilt
    buildingData._syncWarningLogged = false

    if TableIsEmpty(rebuilt) then
        if StateManager and StateManager.RemoveBuilding then
            StateManager.RemoveBuilding(buildingData.id)
        end
        Logger.Info(string.format(
            "[SyncBuildingStats] Removed stale building %s after pruning %d generator link(s)",
            buildingData.id, prunedCount), "Power")
        return true
    end

    if StateManager and StateManager.MarkDirty then
        StateManager.MarkDirty()
    end
    Logger.Warn(string.format(
        "[SyncBuildingStats] Pruned %d stale generator link(s) from building %s",
        prunedCount, buildingData.id), "Power")
    return false
end

--- Inline helper: returns true if the building has at least one activated generator.
--- Uses buildingData.connectedGenerators ("x_y_z" key list set by the connect action).
local function isBuildingPoweredInline(buildingData)
    if not buildingData or not buildingData.connectedGenerators then return false end
    local cell = getCell()
    if not cell then return false end
    -- StateManager fallback for off-chunk generators.
    -- When a generator's chunk is not loaded, cell:getGridSquare returns nil and the
    -- live IsoGenerator is inaccessible.  Without a fallback, ForceUpdateBuilding called
    -- while generators are off-chunk returns isPowered=false, which deactivates all light
    -- consumers and removes tile power even though the generators ARE running (B-59 fix).
    local SM = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    -- connectedGenerators is Kahlua-deserialized (string numeric keys)
    for _, gk in pairs(buildingData.connectedGenerators) do
        local gx, gy, gz = string.match(gk, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if gx then
            local gxi, gyi, gzi = tonumber(gx), tonumber(gy), tonumber(gz)
            if gxi and gyi and gzi then
                local genId = LKS_EletricidadeConstrucao.Data
                          and LKS_EletricidadeConstrucao.Data.Generator
                          and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                          and LKS_EletricidadeConstrucao.Data.Generator.MakeId(gxi, gyi, gzi)
                local genData = genId and SM and SM.GetGenerator and SM.GetGenerator(genId) or nil
                -- Primary: live IsoGenerator object (authoritative when in-chunk)
                local sq = cell:getGridSquare(gxi, gyi, gzi)
                if sq then
                    local objs = sq:getObjects()
                    for i = 0, objs:size() - 1 do
                        local o = objs:get(i)
                        if o and instanceof(o, "IsoGenerator") and o:isActivated()
                                and GeneratorBelongsToBuilding(buildingData.id, o, genData) then
                            return true
                        end
                    end
                    -- Square loaded but no active generator found → not powered via this gen
                else
                    -- Square not loaded (generator is off-chunk): fall back to GlobalModData state.
                    -- genData.activated is set to false only when fuel runs out; nil means active.
                    if SM then
                        local genId = LKS_EletricidadeConstrucao.Data
                                  and LKS_EletricidadeConstrucao.Data.Generator
                                  and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                                  and LKS_EletricidadeConstrucao.Data.Generator.MakeId(gxi, gyi, gzi)
                        if genId then
                            if genData
                               and GeneratorBelongsToBuilding(buildingData.id, nil, genData)
                               and (genData.activated ~= false)
                               and (genData.fuelAmount or 0) > 0 then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

--- Apply or remove generator electricity from every tile in the building's bounding box.
--- Mirrors V1's PowerSquare / chunk:addGeneratorPos approach: this is what PZ uses
--- internally to mark squares as electrically active, powering lights and appliances.
--- @param buildingData BuildingData
--- @param isPowered boolean
local function ApplyTilePower(buildingData, isPowered)
    local bb = buildingData.boundingBox
    if not bb then return end

    local anchorSquare = getSquare(buildingData.x, buildingData.y, buildingData.z or 0)
    local anchorBuilding = anchorSquare and anchorSquare:getBuilding() or nil

    local baseZ = buildingData.z
    local minZ  = math.max(0, baseZ - 3)
    local maxZ  = baseZ + 10
    local chunkSize = getChunkSizeInSquares and getChunkSizeInSquares() or 10

    local tileCount = 0
    local touchedChunks = {}
    for tx = bb.minX, bb.maxX do
        for ty = bb.minY, bb.maxY do
            for tz = minZ, maxZ do
                local sq = getSquare(tx, ty, tz)
                if sq then
                    local sqBuilding = sq:getBuilding()
                    if not anchorBuilding or sqBuilding == nil or sqBuilding == anchorBuilding then
                        local chunk = sq:getChunk()
                        if chunk then
                            if isPowered then
                                chunk:addGeneratorPos(tx, ty, tz)
                            else
                                chunk:removeGeneratorPos(tx, ty, tz)
                            end

                            if sq.RecalcAllWithNeighbours then
                                sq:RecalcAllWithNeighbours(false)
                            end

                            local chunkKey = math.floor(tx / chunkSize) .. "," .. math.floor(ty / chunkSize)
                            touchedChunks[chunkKey] = chunk
                            tileCount = tileCount + 1
                        end
                    end
                end
            end
        end
    end

    local touchedChunkCount = 0
    for _, chunk in pairs(touchedChunks) do
        touchedChunkCount = touchedChunkCount + 1
        if chunk.recalcHashCodeObjects then
            chunk:recalcHashCodeObjects()
        end
        if isServer() and chunk.transmitCompleteChunk then
            chunk:transmitCompleteChunk()
        end
    end

    SyncBuildingPowerState(buildingData, isPowered)

    Logger.Info(string.format("ApplyTilePower: %s %d tiles across %d chunks for building %s",
        isPowered and "powered" or "unpowered", tileCount, touchedChunkCount, buildingData.id), "Power")
end

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

Distributor.UPDATE_INTERVAL = 10  -- Update power states every 10 seconds
-- Refresh consumer isActive / getSquare() scan every N real seconds.
-- This is the expensive 94-call Java bridge loop (getSquare + getObjects per consumer).
-- We only need it to run at UI-display frequency, not every power-state check.
-- Power state changes (stateChanged==true) always trigger a refresh regardless.
Distributor.CONSUMER_REFRESH_INTERVAL = 60
Distributor.DEBUG = false

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

-- Last update timestamp
Distributor.lastUpdate = 0

-- Last time consumer isActive states were refreshed via getSquare() / getObjects()
Distributor.lastConsumerRefresh = 0

-- Power state cache: buildingId -> isPowered
Distributor.powerStateCache = {}

-- Retry queue: buildingId -> retriesLeft (for ForceUpdateBuilding when building not yet in state)
-- Populated when building is not found on first attempt (e.g. right after teleport/chunk load).
-- Drained by ProcessRetryQueue() which is called every EveryOneMinute tick.
Distributor._retryQueue = {}

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

--- Initialize the Power Distributor
function Distributor.Initialize()
    Logger.Info("Initializing Power Distributor...", "Power")
    
    Distributor.powerStateCache = {}
    Distributor.lastUpdate = 0
    Distributor.lastConsumerRefresh = 0
    Distributor._retryQueue = {}
    
    Logger.Info("Power Distributor initialized.", "Power")
end

--------------------------------------------------------------------------------
-- STATS SYNC TO GENERATOR MODDATA (read by client UI)
--------------------------------------------------------------------------------

local function CountDirectActiveGenerators(buildingData)
    local activeCount = 0

    for _, genKey in pairs(buildingData and buildingData.connectedGenerators or {}) do
        local px, py, pz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            local gxi, gyi, gzi = tonumber(px), tonumber(py), tonumber(pz)
            if gxi and gyi and gzi then
                local gen = findGeneratorAt(gxi, gyi, gzi)
                local genId = LKS_EletricidadeConstrucao.Data
                          and LKS_EletricidadeConstrucao.Data.Generator
                          and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                          and LKS_EletricidadeConstrucao.Data.Generator.MakeId(gxi, gyi, gzi)
                local genData = genId and StateManager and StateManager.GetGenerator and StateManager.GetGenerator(genId) or nil
                if gen and gen:isActivated() and (gen:getFuel() or 0) > 0
                        and GeneratorBelongsToBuilding(buildingData.id, gen, genData) then
                    activeCount = activeCount + 1
                end
            end
        end
    end

    return activeCount
end

local function GetGeneratorDisplayStats(buildingData, genKey, strainPowerDraw, fallbackActiveCount)
    local activePoolGens = fallbackActiveCount or 1
    local strain = 0

    local px, py, pz = string.match(genKey or "", "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
    local gxi = px and tonumber(px) or nil
    local gyi = py and tonumber(py) or nil
    local gzi = pz and tonumber(pz) or nil
    if gxi and gyi and gzi and StateManager and LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator then
        local genId = LKS_EletricidadeConstrucao.Data.Generator.MakeId(gxi, gyi, gzi)
        local gd = StateManager.GetGenerator(genId)
        if gd then
            local countedPoolGens = 0
            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators then
                countedPoolGens = LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators(gd) or 0
            end
            if countedPoolGens < 1 then
                countedPoolGens = gd["cachedPoolActive"] or 0
            end
            if countedPoolGens > 0 then
                activePoolGens = countedPoolGens
            end

            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.StrainCalculator and LKS_EletricidadeConstrucao.Fuel.StrainCalculator.CalculateStrain then
                strain = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.CalculateStrain(gd, nil, activePoolGens) or 0
            end
        end
    end

    if activePoolGens < 1 then activePoolGens = 1 end

    local sharedPowerDraw = strainPowerDraw / activePoolGens

    if strain <= 0
       and sharedPowerDraw > 0
       and LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.StrainCalculator
       and LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PowerDrawToStrain then
        strain = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PowerDrawToStrain(sharedPowerDraw) or 0
    end

    if strain < 0.5 then strain = 0 end

    return sharedPowerDraw, math.max(0, math.floor(strain + 0.5))
end

local function BuildBarrelStatsSnapshot(buildingData)
    local barrelData = {}
    local barrelCount = 0
    local totalFuel = 0
    local Barrels = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels

    if not buildingData or not buildingData.id or not Barrels or not Barrels.GetLinkedBarrels then
        return barrelData, barrelCount, totalFuel
    end

    local ok, linkedBarrels = pcall(Barrels.GetLinkedBarrels, buildingData.id)
    if not ok or type(linkedBarrels) ~= "table" then
        return barrelData, barrelCount, totalFuel
    end

    for _, barrel in ipairs(linkedBarrels) do
        local sq = barrel and barrel.getSquare and barrel:getSquare() or nil
        if sq then
            local amount = Barrels.GetPetrolAmount and (Barrels.GetPetrolAmount(barrel) or 0) or 0
            local maxAmount = 25
            if barrel.getFluidContainer then
                local okFc, fc = pcall(function() return barrel:getFluidContainer() end)
                if okFc and fc then
                    local okCap, cap = pcall(function() return fc:getCapacity() end)
                    if okCap and cap and cap > 0 then
                        maxAmount = cap
                    end
                end
            end

            local spriteName = nil
            local okSprite, sprite = pcall(function()
                if barrel.getSpriteName then return barrel:getSpriteName() end
                if barrel.getSprite and barrel:getSprite() then return barrel:getSprite():getName() end
            end)
            if okSprite then spriteName = sprite end

            barrelCount = barrelCount + 1
            totalFuel = totalFuel + amount
            barrelData[barrelCount] = {
                x = sq:getX(),
                y = sq:getY(),
                z = sq:getZ(),
                amount = amount,
                maxAmount = maxAmount,
                sprite = spriteName,
            }
        end
    end

    return barrelData, barrelCount, totalFuel
end

--- Write building stats into the connected generator's ModData so the client
--- can display them in the Info Window without needing server-side state access.
--- Called every distribution update cycle (~10 s).
local function SyncBuildingStatsToGenerator(buildingData)
    if not buildingData then return end

    -- Count consumers by type (total + active)
    local consumerCount       = 0
    local lightCount          = 0  -- includes both fixed lights and moveable lamps (merged)
    local applianceCount      = 0
    local activeLightCount    = 0
    local activeApplianceCount = 0
    local powerDraw           = buildingData.totalPowerDraw or 0

    -- For strain calculation use the cached powered draw so it stays consistent offchunk
    -- (when unpowered, totalPowerDraw shrinks as consumers go inactive)
    local strainPowerDraw     = buildingData.strainTotalPowerDraw or powerDraw

    if buildingData.powerConsumers then
        -- powerConsumers is Kahlua-deserialized (string numeric keys); pairs required
        for _, c in pairs(buildingData.powerConsumers) do
            consumerCount = consumerCount + 1
            local t = c.objectType or ""
            if t == "light" or t == "lamp" then
                -- "lamp" (moveable floor/desk/table lamps) is treated identically to
                -- "light" (fixed ceiling/wall fixtures) because both use the same fuel
                -- rate and the UI shows them as a single "Lights" row.
                lightCount = lightCount + 1
                if c.isActive then activeLightCount = activeLightCount + 1 end
            elseif t == "appliance" then
                applianceCount = applianceCount + 1
                if c.isActive then activeApplianceCount = activeApplianceCount + 1 end
            end
        end
    end

    if PruneStaleGeneratorLinks(buildingData) then
        return
    end

    if not buildingData.connectedGenerators or TableIsEmpty(buildingData.connectedGenerators) then
        return
    end

    local fallbackActiveGens = CountDirectActiveGenerators(buildingData)
    if fallbackActiveGens < 1 then fallbackActiveGens = 1 end
    local barrelData, barrelCount, barrelTotalFuel = BuildBarrelStatsSnapshot(buildingData)

    -- Find connected generators via runtime connectedGenerators list ("x_y_z" keys)
    if not buildingData.connectedGenerators then return end

    -- Read the pool-wide fuel rate from the first ACTIVE generator (or 0 if none active).
    -- All generators in the pool should show the same rate regardless of their individual active state.
    local poolFuelRateLph = 0
    -- connectedGenerators is Kahlua-deserialized (string numeric keys)
    for _, genKey in pairs(buildingData.connectedGenerators) do
        local px, py, pz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            local gen = findGeneratorAt(tonumber(px), tonumber(py), tonumber(pz))
            if gen and gen:isActivated() then
                poolFuelRateLph = gen:getModData().Gen_Stats_FuelRateLph or 0
                break  -- Use first active generator's rate for entire pool
            end
        end
    end

    -- Write pool-wide stats to ALL generators (active or inactive)
    local syncedCount = 0
    local skippedCount = 0
    for _, genKey in pairs(buildingData.connectedGenerators) do
        local px, py, pz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            local gen = findGeneratorAt(tonumber(px), tonumber(py), tonumber(pz))
            if gen then
                local md = gen:getModData()
                local sharedPowerDraw, strainInt = GetGeneratorDisplayStats(
                    buildingData,
                    genKey,
                    strainPowerDraw,
                    fallbackActiveGens)
                
                -- Use pool-wide fuel rate (from any active generator in the pool)
                md.Gen_Stats_Consumers          = consumerCount
                md.Gen_Stats_ActiveConsumers    = buildingData.activeConsumerCount or 0
                md.Gen_Stats_Lights             = lightCount   -- includes lamps (merged)
                md.Gen_Stats_ActiveLights       = activeLightCount
                md.Gen_Stats_Lamps              = nil           -- retired; merged into Lights
                md.Gen_Stats_ActiveLamps        = nil
                md.Gen_Stats_Appliances         = applianceCount
                md.Gen_Stats_ActiveAppliances   = activeApplianceCount
                md.Gen_Stats_PowerDraw          = sharedPowerDraw
                md.Gen_Stats_Strain             = strainInt
                md.Gen_Stats_FuelRateLph        = poolFuelRateLph  -- Same pool-wide value for all
                md.Gen_Stats_Powered            = buildingData.isPowered or false
                md.Gen_Stats_BarrelCount        = barrelCount
                md.Gen_Stats_BarrelTotalFuel    = barrelTotalFuel
                md.Gen_Stats_BarrelData         = barrelCount > 0 and barrelData or nil
                md.Gen_BuildingPoolID           = buildingData.id  -- stamp for client UI lookup
                local currentWorldId = LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId and
                                       LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId() or nil
                if currentWorldId and currentWorldId ~= "unknown" then
                    md.LKS_EletricidadeConstrucao_WorldId = currentWorldId
                end
                
                -- Sync to clients in MP (no-op in SP)
                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                    gen:transmitModData()
                end
                syncedCount = syncedCount + 1
                -- Logger.Debug(string.format("[Sync] wrote Gen_Stats to generator %s for building %s", genKey, buildingData.id), "Power")
            else
                skippedCount = skippedCount + 1
                -- Only warn on first skip - don't spam logs
                if not buildingData._syncWarningLogged then
                    Logger.Warn(string.format(
                        "[SyncBuildingStats] Generator at %s not found (chunk not loaded?) - building %s has %d consumers waiting",
                        genKey, buildingData.id, consumerCount), "Power")
                    buildingData._syncWarningLogged = true
                end
            end
        end
    end
    
    -- Only log if generators were skipped (problematic case) or if this is the first successful sync
    if skippedCount > 0 then
        Logger.Warn(string.format(
            "[SyncBuildingStats] Building %s: synced %d/%d generators - %d generators unreachable (chunk not loaded)",
            buildingData.id, syncedCount, syncedCount + skippedCount, skippedCount), "Power")
    elseif syncedCount > 0 and buildingData._syncWarningLogged then
        -- First successful sync after previous failures - log success
        Logger.Info(string.format(
            "[SyncBuildingStats] Building %s: ALL generators now reachable - synced %d consumers successfully",
            buildingData.id, consumerCount), "Power")
        buildingData._syncWarningLogged = false
    end
end

--------------------------------------------------------------------------------
-- POWER DISTRIBUTION
--------------------------------------------------------------------------------

--- Read IsoRadio / IsoTelevision on-state via PZ 42 DeviceData API.
--- Both world-gen TVs (IsoRadio with IsTelevision=true) and moveable TVs
--- (IsoTelevision) store their on-state in DeviceData:getIsTurnedOn().
local function radioIsOn(o)
    if o.getDeviceData then
        local dev = o:getDeviceData()
        if dev and dev.getIsTurnedOn then
            return dev:getIsTurnedOn()
        end
    end
    return false
end

--- Check whether a specific appliance on a square is currently active (user-on).
--- Fridges/freezers are always active when powered; TVs, stoves, and radios
--- expose an on/off state via PZ API.
--- @param sq IsoGridSquare Square the appliance sits on
--- @param isPowered boolean Whether the building has power at all
--- @return boolean
local function GetApplianceActiveState(sq, isPowered)
    if not isPowered then return false end
    if not sq then return isPowered end
    local objects = sq:getObjects()
    if not objects then return isPowered end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            -- Television: on/off state (moveable IsoTelevision)
            if instanceof(obj, "IsoTelevision") then
                return radioIsOn(obj)
            end
            -- Radio / world-gen TV (IsoRadio with IsTelevision=true)
            if instanceof(obj, "IsoRadio") then
                return radioIsOn(obj)
            end
            -- Stove: active if any burner is currently running
            if instanceof(obj, "IsoStove") then
                if obj.Activated then
                    return obj:Activated()
                end
                return isPowered
            end
            -- Washer / dryer: active when the cycle is running (setActivated/isActivated API)
            if instanceof(obj, "IsoClothingDryer")
            or instanceof(obj, "IsoClothingWasher")
            or instanceof(obj, "IsoCombinationWasherDryer")
            or instanceof(obj, "IsoStackedWasherDryer") then
                return obj.isActivated and obj:isActivated() or false
            end
            -- World-gen washer/dryer: IsoThumpable with clothingdryer/clothingwasher container
            if obj.getContainerByType then
                if obj:getContainerByType("clothingdryer")  ~= nil
                or obj:getContainerByType("clothingwasher") ~= nil then
                    return obj.isActivated and obj:isActivated() or false
                end
                -- Fridge / freezer: always active when powered
                if obj:getContainerByType("fridge")  ~= nil
                or obj:getContainerByType("freezer") ~= nil then
                    return true
                end
            end
        end
    end
    return isPowered  -- fallback for sprite-only / unknown appliances
end

--- Update power state for a single building
-- @param buildingData BuildingData object
-- @param refreshConsumers boolean When true, re-scan consumer isActive via getSquare()/getObjects().
--   Set to true on a periodic basis (CONSUMER_REFRESH_INTERVAL) or always on power state changes.
--   Skip (false) during rapid steady-state updates to avoid 94× Java bridge calls per tick.
-- @return boolean True if power state changed
function Distributor.UpdateBuildingPower(buildingData, refreshConsumers)
    if not buildingData then
        Logger.Error("UpdateBuildingPower: buildingData is nil", "Power")
        return false
    end
    
    -- Check if building has power (inline: avoids load-order dependency on LKS_EletricidadeConstrucao.Power.Manager)
    local isPowered = isBuildingPoweredInline(buildingData)
    
    -- Get cached power state
    local cachedState = Distributor.powerStateCache[buildingData.id]
    
    -- Check if power state changed
    local stateChanged = (cachedState ~= isPowered)
    
    -- Only log meaningful transitions (not nil -> X)
    if stateChanged and cachedState ~= nil then
        Logger.Info(string.format(
            "Building %s power state changed: %s -> %s",
            buildingData.id,
            tostring(cachedState),
            tostring(isPowered)
        ), "Power")
    end
    
    -- Apply tile-level electricity via the PZ chunk API (mirrors V1 PowerSquare).
    -- This is what actually powers lights and appliances in the world.
    -- Only re-apply when state changes to avoid redundant chunk writes every tick.
    if stateChanged then
        ApplyTilePower(buildingData, isPowered)
    end

    -- Update consumer isActive flags for UI display (lights/count/strain).
    -- This does NOT touch world objects; it only updates our internal tracking.
    -- B-98: Skipped when power state is unchanged and refreshConsumers=false to avoid
    --   firing 94× getSquare()/getObjects() Java bridge calls every 10-second tick.
    --   refreshConsumers is set true every CONSUMER_REFRESH_INTERVAL (60 s) so stats
    --   stay accurate for the UI.  Power-state changes always force a full re-scan.
    if buildingData.powerConsumers and (stateChanged or refreshConsumers) then
        local updatedCount = 0
        -- Track whether at least one square was loaded this update cycle.
        -- Used post-loop to only cache strainTotalPowerDraw when in-chunk
        -- (off-chunk updates must preserve the last correct cached value).
        local anySquareLoaded = false
        
        -- powerConsumers is Kahlua-deserialized (string numeric keys); pairs required
        for _, consumerData in pairs(buildingData.powerConsumers) do
            -- Refresh isActive: checks actual IsoLightSwitch activation state for
            -- light consumers so flipping a switch is reflected in activeConsumerCount.
            local sq = getSquare(consumerData.squareX, consumerData.squareY, consumerData.squareZ)
            if sq then
                anySquareLoaded = true
                if isPowered and consumerData.objectType == "light" then
                    -- Walk objects on this consumer's square:
                    --   IsoLightSwitch → active only if the switch is turned on
                    --   IsoLight (ceiling fixture) → always active when building is powered
                    --   Sprite-only room tile → assume active when powered
                    local isLightActive = true   -- default: on when powered
                    local objects = sq:getObjects()
                    if objects then
                        for i = 0, objects:size() - 1 do
                            local obj = objects:get(i)
                            if obj then
                                if instanceof(obj, "IsoLightSwitch") then
                                    -- Switch found: honour its actual on/off state
                                    isLightActive = obj.isActivated and obj:isActivated() or false
                                    break
                                end
                                -- IsoLight present → stays true (powered = active)
                            end
                        end
                    end
                    consumerData.isActive = isLightActive
                elseif consumerData.objectType == "appliance" then
                    -- Check the actual appliance's on/off state
                    consumerData.isActive = GetApplianceActiveState(sq, isPowered)
                else
                    -- Lamps / other: active whenever building has power
                    consumerData.isActive = isPowered
                end
            else
                -- Square not yet loaded into memory (chunk unloaded or chunk boundary).
                -- Apply safe defaults so stats are not silently wrong:
                --   Lights / lamps: tie directly to whether the building is powered.
                --   Appliances:     preserve the last persisted isActive value so that
                --                   e.g. fridges (always true) and off-stoves (false)
                --                   stay correct until the chunk is loaded and a proper
                --                   re-check can run via the next ForceUpdateBuilding.
                if consumerData.objectType == "light" or consumerData.objectType == "lamp" then
                    consumerData.isActive = isPowered
                end
                -- objectType == "appliance": intentionally left unchanged (keep saved state)
            end
            updatedCount = updatedCount + 1
        end

        -- Refresh totalPowerDraw and activeConsumerCount after updating isActive
        LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(buildingData)

        -- Cache authoritative powered draw for off-chunk strain calculations.
        -- Only update when chunk squares were accessible this cycle (anySquareLoaded)
        -- so that off-chunk ticks preserve the last correct in-chunk value instead
        -- of accidentally snapping to the raw-scan total (all consumers at base power).
        if isPowered and anySquareLoaded and (buildingData.totalPowerDraw or 0) > 0 then
            buildingData.strainTotalPowerDraw = buildingData.totalPowerDraw
        end
        
        if Distributor.DEBUG or stateChanged then
            local _pc = 0
            if buildingData.powerConsumers then
                for _ in pairs(buildingData.powerConsumers) do _pc = _pc + 1 end
            end
            Logger.Debug(string.format(
                "Updated %d/%d consumers in building %s (powered: %s)",
                updatedCount,
                _pc,
                buildingData.id,
                tostring(isPowered)
            ), "Power")
        end
    end
    
    -- Update building's isPowered field
    buildingData.isPowered = isPowered
    
    -- Update cache
    Distributor.powerStateCache[buildingData.id] = isPowered
    
    return stateChanged
end

--- Update power distribution for all buildings
-- @param refreshConsumers boolean When true, re-scan every consumer's isActive via world lookups.
--   Should be true on first call, after a ForceUpdate, or when CONSUMER_REFRESH_INTERVAL elapses.
-- @return table Stats: { totalBuildings, LKS_EletricidadeConstrucao, unLKS_EletricidadeConstrucao, stateChanges, consumersUpdated }
function Distributor.UpdateAllBuildings(refreshConsumers)
    local stats = {
        totalBuildings = 0,
        LKS_EletricidadeConstrucao = 0,
        unLKS_EletricidadeConstrucao = 0,
        stateChanges = 0,
        consumersUpdated = 0
    }
    
    -- Get all buildings (returns a map: buildingId -> buildingData)
    local buildings = StateManager.GetAllBuildings()
    if not buildings then
        Logger.Warn("UpdateAllBuildings: No buildings found", "Power")
        return stats
    end
    
    -- Update each building (use pairs - buildings is a map, not an array)
    for _, buildingData in pairs(buildings) do
        stats.totalBuildings = stats.totalBuildings + 1
        local stateChanged = Distributor.UpdateBuildingPower(buildingData, refreshConsumers)
        
        if stateChanged then
            stats.stateChanges = stats.stateChanges + 1
        end
        
        if buildingData.isPowered then
            stats.LKS_EletricidadeConstrucao = stats.LKS_EletricidadeConstrucao + 1
        else
            stats.unLKS_EletricidadeConstrucao = stats.unLKS_EletricidadeConstrucao + 1
        end
        
        if buildingData.powerConsumers then
            local _pc = 0
            for _ in pairs(buildingData.powerConsumers) do _pc = _pc + 1 end
            stats.consumersUpdated = stats.consumersUpdated + _pc
        end

        -- Sync stats to generator ModData so client UI can read them
        SyncBuildingStatsToGenerator(buildingData)
    end

    return stats
end

--- Periodic update (called from server tick)
-- @param currentTime number Current timestamp
function Distributor.Update(currentTime)
    currentTime = currentTime or os.time()
    
    -- Check if update interval has passed
    if currentTime - Distributor.lastUpdate >= Distributor.UPDATE_INTERVAL then
        -- B-98: Only re-scan consumer isActive (getSquare/getObjects) every CONSUMER_REFRESH_INTERVAL.
        -- In steady state (building powered, no change) this skips ~94 Java bridge calls per 10s tick.
        local refreshConsumers = (currentTime - Distributor.lastConsumerRefresh >= Distributor.CONSUMER_REFRESH_INTERVAL)

        local stats = Distributor.UpdateAllBuildings(refreshConsumers)

        if refreshConsumers then
            Distributor.lastConsumerRefresh = currentTime
        end
        
        if Distributor.DEBUG or stats.stateChanges > 0 then
            Logger.Info(string.format(
                "Power distribution update: %d buildings (%d powered, %d unpowered), %d state changes, %d consumers updated",
                stats.totalBuildings,
                stats.LKS_EletricidadeConstrucao,
                stats.unLKS_EletricidadeConstrucao,
                stats.stateChanges,
                stats.consumersUpdated
            ), "Power")
        end
        
        Distributor.lastUpdate = currentTime
    end
end

--------------------------------------------------------------------------------
-- MANUAL OPERATIONS
--------------------------------------------------------------------------------

--- Force immediate power update for all buildings
function Distributor.ForceUpdate()
    Logger.Info("ForceUpdate: Forcing immediate power distribution update...", "Power")
    
    -- Always refresh consumer isActive on a forced update so UI sees fresh state
    local stats = Distributor.UpdateAllBuildings(true)
    
    Logger.Info(string.format(
        "ForceUpdate complete: %d buildings (%d powered, %d unpowered), %d state changes, %d consumers updated",
        stats.totalBuildings,
        stats.LKS_EletricidadeConstrucao,
        stats.unLKS_EletricidadeConstrucao,
        stats.stateChanges,
        stats.consumersUpdated
    ), "Power")
    
    local now = os.time()
    Distributor.lastUpdate = now
    Distributor.lastConsumerRefresh = now
end

--- Internal helper: attempt a full power update for a single building by ID.
--- Does NOT enqueue a retry on failure — callers decide that.
--- @param buildingId string
--- @return boolean true if building was found and updated, false if not in state yet
local function _RefreshBuildingStats(buildingData, forceTileRefresh)
    if not buildingData then return false end

    -- ForceUpdateBuilding uses this to intentionally re-apply tile power after
    -- connect / disconnect / activation changes. Passive UI refreshes must not
    -- clear the cache, otherwise every poll looks like a state transition.
    if forceTileRefresh then
        Distributor.powerStateCache[buildingData.id] = nil
    end

    Distributor.UpdateBuildingPower(buildingData, true)
    SyncBuildingStatsToGenerator(buildingData)
    return true
end

local function _AttemptBuildingUpdate(buildingId, forceTileRefresh)
    local buildingData = StateManager.GetBuilding(buildingId)
    if not buildingData then return false end

    return _RefreshBuildingStats(buildingData, forceTileRefresh == true)
end

--- Refresh active consumers and Gen_Stats_* for a building without forcing
--- tile-power reapplication. Use this for UI polling and barrel/stat updates.
--- @param buildingId string Building ID
--- @return boolean true if building was found and refreshed
function Distributor.RefreshBuildingStats(buildingId)
    if not buildingId then
        Logger.Error("RefreshBuildingStats: buildingId is nil", "Power")
        return false
    end

    return _AttemptBuildingUpdate(buildingId, false)
end

--- Force power update for a specific building.
--- If the building is not yet in StateManager (e.g. chunk just loaded after teleport),
--- the request is enqueued for up to 3 retries on subsequent EveryOneMinute ticks.
--- ProcessRetryQueue() must be called each minute (done by LKS_EletricidadeConstrucao_ServerInit).
-- @param buildingId string Building ID
function Distributor.ForceUpdateBuilding(buildingId)
    if not buildingId then
        Logger.Error("ForceUpdateBuilding: buildingId is nil", "Power")
        return
    end

    -- Self-heal: _retryQueue may be nil if Initialize() ran before this field existed
    if not Distributor._retryQueue then Distributor._retryQueue = {} end

    if _AttemptBuildingUpdate(buildingId, true) then
        -- Success — also clear any stale retry entry for this building
        Distributor._retryQueue[buildingId] = nil
        return
    end

    -- Building not in state yet. Queue for retry instead of silently discarding.
    if not Distributor._retryQueue[buildingId] then
        Logger.Warn(string.format(
            "ForceUpdateBuilding: Building not found: %s - queued for retry (up to 3x on EveryOneMinute)",
            buildingId), "Power")
        Distributor._retryQueue[buildingId] = 3
    end
end

--- Retry pending ForceUpdateBuilding calls whose building was not yet in state.
--- Called from EveryOneMinute (LKS_EletricidadeConstrucao_ServerInit). Each entry gets up to 3 attempts
--- across 3 consecutive minute ticks before being permanently abandoned.
function Distributor.ProcessRetryQueue()
    -- Self-heal: _retryQueue may be nil if Initialize() ran before this field existed
    local queue = Distributor._retryQueue
    if not queue then
        Distributor._retryQueue = {}
        return
    end

    -- NOTE: next() is not available in Kahlua (PZ's Lua VM) - use pairs to check emptiness
    local hasEntries = false
    for _ in pairs(queue) do hasEntries = true; break end
    if not hasEntries then return end  -- fast-exit if empty

    local toRemove = {}
    for buildingId, retriesLeft in pairs(queue) do
        if _AttemptBuildingUpdate(buildingId, true) then
            Logger.Info(string.format(
                "ProcessRetryQueue: Building %s restored - deferred ForceUpdate applied", buildingId), "Power")
            table.insert(toRemove, buildingId)
        else
            local remaining = retriesLeft - 1
            if remaining <= 0 then
                Logger.Warn(string.format(
                    "ProcessRetryQueue: Building %s still not found after all retries - abandoning", buildingId), "Power")
                table.insert(toRemove, buildingId)
            else
                Logger.Debug(string.format(
                    "ProcessRetryQueue: Building %s not found, %d retries left", buildingId, remaining), "Power")
                Distributor._retryQueue[buildingId] = remaining
            end
        end
    end
    for _, bid in ipairs(toRemove) do
        Distributor._retryQueue[bid] = nil
    end
end

--------------------------------------------------------------------------------
-- QUERY FUNCTIONS
--------------------------------------------------------------------------------

--- Get cached power state for a building
-- @param buildingId string Building ID
-- @return boolean|nil Cached power state (nil if not cached)
function Distributor.GetCachedPowerState(buildingId)
    return Distributor.powerStateCache[buildingId]
end

--- Clear power state cache
function Distributor.ClearCache()
    Logger.Info("Clearing power state cache...", "Power")
    Distributor.powerStateCache = {}
end

--------------------------------------------------------------------------------
-- DEBUG FUNCTIONS
--------------------------------------------------------------------------------

--- Print power distribution status (debug)
function Distributor.PrintStatus()
    Logger.Info("=== POWER DISTRIBUTION STATUS ===", "Power")
    
    local buildings = StateManager.GetAllBuildings()
    if not buildings then
        Logger.Info("No buildings found", "Power")
        return
    end
    
    -- GetAllBuildings() returns a hash-map; # operator always returns 0 for hash-maps
    local _bldCount = 0
    for _ in pairs(buildings) do _bldCount = _bldCount + 1 end
    Logger.Info(string.format("Total buildings: %d", _bldCount), "Power")
    
    local poweredCount = 0
    local unpoweredCount = 0
    
    for _, buildingData in pairs(buildings) do
        local isPowered = isBuildingPoweredInline(buildingData)
        local consumerCount = 0
        if buildingData.powerConsumers then
            for _ in pairs(buildingData.powerConsumers) do consumerCount = consumerCount + 1 end
        end
        local powerDraw = buildingData.totalPowerDraw or 0
        
        if isPowered then
            poweredCount = poweredCount + 1
        else
            unpoweredCount = unpoweredCount + 1
        end
        
        Logger.Info(string.format(
            "  Building %s: %s (%d consumers, %.1f draw)",
            buildingData.id,
            isPowered and "POWERED" or "UNPOWERED",
            consumerCount,
            powerDraw
        ), "Power")
    end
    
    Logger.Info(string.format(
        "Summary: %d powered, %d unpowered",
        poweredCount,
        unpoweredCount
    ), "Power")
    
    Logger.Info("================================", "Power")
end

--------------------------------------------------------------------------------
-- EXPORTS
--------------------------------------------------------------------------------

LKS_EletricidadeConstrucao.RegisterModule("Power.Distributor", "2.0.0")

return LKS_EletricidadeConstrucao.Power.Distributor
