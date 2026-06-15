-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Data_State.lua
-- LKS_EletricidadeConstrucao V2 - Global State Data Model
-- Schema definition for global mod state and persistence
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Data_State] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- SCHEMA DEFINITION
-- ============================================================================

--- Global state schema
--- @class StateData
--- @field version string Mod version
--- @field generators table Map of generator ID to GeneratorData
--- @field buildings table Map of building ID to BuildingData
--- @field chunkIndex table Map of chunkKey to array of generator IDs (runtime index persisted for fast lookup)
--- @field lastFullSync number Last full sync timestamp (MP)
--- @field lastDeltaSync number Last delta sync timestamp (MP)
--- @field config table Active configuration
--- @field statistics table Runtime statistics

local StateSchema = {
    version = "2.0.0",
    generators = {},
    buildings = {},
    chunkIndex = {},
    lastFullSync = 0,
    lastDeltaSync = 0,
    config = {},
    statistics = {
        totalGenerators = 0,
        totalBuildings = 0,
        totalConsumers = 0,
        activeGenerators = 0,
        activeConsumers = 0,
        totalFuelConsumed = 0,
        uptime = 0
    }
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

--- Create new global state instance
--- @return StateData New state data
function LKS_EletricidadeConstrucao.Data.State.New()
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local data = Table.DeepCopy(StateSchema)
    
    -- Set version
    data.version = LKS_EletricidadeConstrucao.VERSION or "2.0.0"
    
    -- Set initial timestamp
    data.lastFullSync = getTimestampMs()
    data.lastDeltaSync = getTimestampMs()
    
    return data
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

--- Validate state data structure
--- @param data StateData Data to validate
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Data.State.Validate(data)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Check if table
    if not Validation.IsTable(data) then
        return false, "State data must be a table"
    end
    
    -- Validate required fields
    local valid, err = Validation.ValidateKeys(data, {
        "version", "generators", "buildings", "chunkIndex", "config", "statistics"
    }, "State data")
    
    if not valid then return false, err end
    
    -- Validate version
    valid, err = Validation.ValidateNotEmpty(data.version, "version")
    if not valid then return false, err end
    
    -- Validate tables
    if not Validation.IsTable(data.generators) then
        return false, "generators must be a table"
    end
    
    if not Validation.IsTable(data.buildings) then
        return false, "buildings must be a table"
    end
    
    if not Validation.IsTable(data.config) then
        return false, "config must be a table"
    end
    
    if not Validation.IsTable(data.statistics) then
        return false, "statistics must be a table"
    end

    if not Validation.IsTable(data.chunkIndex) then
        return false, "chunkIndex must be a table"
    end
    
    return true, nil
end

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

--- Serialize state data for ModData storage
--- @param data StateData Data to serialize
--- @return table Serialized data
function LKS_EletricidadeConstrucao.Data.State.Serialize(data)
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    
    -- Create deep copy
    local serialized = Table.DeepCopy(data)
    
    -- Serialize all generators
    local serializedGenerators = {}
    for id, genData in pairs(data.generators) do
        serializedGenerators[id] = LKS_EletricidadeConstrucao.Data.Generator.Serialize(genData)
    end
    serialized.generators = serializedGenerators
    
    -- Serialize all buildings
    local serializedBuildings = {}
    for id, bldData in pairs(data.buildings) do
        serializedBuildings[id] = LKS_EletricidadeConstrucao.Data.Building.Serialize(bldData)
    end
    serialized.buildings = serializedBuildings
    
    return serialized
end

--- Deserialize state data from ModData
--- @param serialized table Serialized data
--- @return StateData|nil Deserialized data or nil if invalid
function LKS_EletricidadeConstrucao.Data.State.Deserialize(serialized)
    if not serialized then return nil end
    
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local data = Table.DeepCopy(serialized)
    
    -- Deserialize all generators
    local deserializedGenerators = {}
    for id, genSerialized in pairs(data.generators or {}) do
        local genData = LKS_EletricidadeConstrucao.Data.Generator.Deserialize(genSerialized)
        if genData then
            deserializedGenerators[id] = genData
        else
            LKS_EletricidadeConstrucao.Warn("[State.Deserialize] Failed to deserialize generator: " .. id)
        end
    end
    data.generators = deserializedGenerators
    
    -- Deserialize all buildings
    local deserializedBuildings = {}
    for id, bldSerialized in pairs(data.buildings or {}) do
        local bldData = LKS_EletricidadeConstrucao.Data.Building.Deserialize(bldSerialized)
        if bldData then
            deserializedBuildings[id] = bldData
        else
            LKS_EletricidadeConstrucao.Warn("[State.Deserialize] Failed to deserialize building: " .. id)
        end
    end
    data.buildings = deserializedBuildings

    -- Rebuild chunk index from generators (deserialized chunkIndex may be stale or missing)
    data.chunkIndex = {}
    for genId, genData in pairs(data.generators) do
        local chunkKey = genData.chunkKey
        if not chunkKey and LKS_EletricidadeConstrucao.Utils and LKS_EletricidadeConstrucao.Utils.Geometry then
            chunkKey = LKS_EletricidadeConstrucao.Utils.Geometry.GetChunkKey(genData.x, genData.y)
            genData.chunkKey = chunkKey
        end
        if chunkKey then
            data.chunkIndex[chunkKey] = data.chunkIndex[chunkKey] or {}
            table.insert(data.chunkIndex[chunkKey], genId)
        end
    end
    
    -- Validate overall state
    local valid, err = LKS_EletricidadeConstrucao.Data.State.Validate(data)
    if not valid then
        LKS_EletricidadeConstrucao.Error("[State.Deserialize] Invalid state data: " .. err)
        return nil
    end
    
    return data
end

-- ============================================================================
-- GENERATOR OPERATIONS
-- ============================================================================

--- Add generator to state
--- @param data StateData State data
--- @param generatorData GeneratorData Generator to add
function LKS_EletricidadeConstrucao.Data.State.AddGenerator(data, generatorData)
    -- Ensure generator has a chunk key for indexing
    if (not generatorData.chunkKey or generatorData.chunkKey == "")
            and LKS_EletricidadeConstrucao.Utils and LKS_EletricidadeConstrucao.Utils.Geometry then
        generatorData.chunkKey = LKS_EletricidadeConstrucao.Utils.Geometry.GetChunkKey(generatorData.x, generatorData.y)
    end

    -- Merge connectedBuildings from existing entry so restore operations
    -- never wipe pool links that were established by ConnectBuilding.
    local existing = data.generators[generatorData.id]
    if existing then
        generatorData.connectedBuildings = generatorData.connectedBuildings or {}
        -- State is always authoritative for fuel/activation - never let a fresh
        -- IsoObject snapshot overwrite what the fuel manager has been tracking.
        generatorData.fuelAmount       = existing.fuelAmount
        generatorData.activated        = existing.activated
        generatorData.lastSyncedFuel   = existing.lastSyncedFuel
        -- Carry over any building links the incoming object doesn't already have.
        -- connectedBuildings / connectedGenerators are Kahlua-deserialized (string numeric keys)
        for _, bid in pairs(existing.connectedBuildings or {}) do
            local found = false
            for _, bid2 in pairs(generatorData.connectedBuildings) do
                if bid2 == bid then found = true; break end
            end
            if not found then
                table.insert(generatorData.connectedBuildings, bid)
            end
        end
    end

    data.generators[generatorData.id] = generatorData

    -- Maintain chunk index for fast chunk queries
    if generatorData.chunkKey then
        data.chunkIndex[generatorData.chunkKey] = data.chunkIndex[generatorData.chunkKey] or {}
        local list = data.chunkIndex[generatorData.chunkKey]
        local exists = false
        for _, gid in ipairs(list) do
            if gid == generatorData.id then exists = true; break end
        end
        if not exists then
            table.insert(list, generatorData.id)
        end
    end

    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(data)
end

--- Remove generator from state
--- @param data StateData State data
--- @param generatorId string Generator ID
--- @return GeneratorData|nil Removed generator data
function LKS_EletricidadeConstrucao.Data.State.RemoveGenerator(data, generatorId)
    local removed = data.generators[generatorId]
    data.generators[generatorId] = nil

    if removed and removed.chunkKey and data.chunkIndex[removed.chunkKey] then
        local list = data.chunkIndex[removed.chunkKey]
        for i = #list, 1, -1 do
            if list[i] == generatorId then
                table.remove(list, i)
            end
        end
        if #list == 0 then
            data.chunkIndex[removed.chunkKey] = nil
        end
    end
    
    if removed then
        LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(data)
    end
    
    return removed
end

--- Get generator by ID
--- @param data StateData State data
--- @param generatorId string Generator ID
--- @return GeneratorData|nil Generator data
function LKS_EletricidadeConstrucao.Data.State.GetGenerator(data, generatorId)
    return data.generators[generatorId]
end

--- Get all generators
--- @param data StateData State data
--- @return table Map of generator ID to GeneratorData
function LKS_EletricidadeConstrucao.Data.State.GetAllGenerators(data)
    return data.generators
end

-- ============================================================================
-- BUILDING OPERATIONS
-- ============================================================================

--- Add building to state
--- @param data StateData State data
--- @param buildingData BuildingData Building to add
function LKS_EletricidadeConstrucao.Data.State.AddBuilding(data, buildingData)
    local existing = data.buildings[buildingData.id]
    if existing and existing.connectedGenerators then
        -- pairs-safe emptiness check (Kahlua string numeric keys)
        local _hasGens = false
        for _ in pairs(existing.connectedGenerators) do _hasGens = true; break end
        if _hasGens then
            -- Merge: carry over any generator links the incoming object doesn't already have.
            -- Prevents ScanBuilding / TryRestoreFromIsoModData from wiping pool links.
            buildingData.connectedGenerators = buildingData.connectedGenerators or {}
            for _, gk in pairs(existing.connectedGenerators) do
                local found = false
                for _, gk2 in pairs(buildingData.connectedGenerators) do
                    if gk2 == gk then found = true; break end
                end
                if not found then
                    table.insert(buildingData.connectedGenerators, gk)
                end
            end
        end
    end
    data.buildings[buildingData.id] = buildingData
    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(data)
end

--- Remove building from state
--- @param data StateData State data
--- @param buildingId string Building ID
--- @return BuildingData|nil Removed building data
function LKS_EletricidadeConstrucao.Data.State.RemoveBuilding(data, buildingId)
    local removed = data.buildings[buildingId]
    data.buildings[buildingId] = nil
    
    if removed then
        LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(data)
    end
    
    return removed
end

--- Get building by ID
--- @param data StateData State data
--- @param buildingId string Building ID
--- @return BuildingData|nil Building data
function LKS_EletricidadeConstrucao.Data.State.GetBuilding(data, buildingId)
    return data.buildings[buildingId]
end

--- Get all buildings
--- @param data StateData State data
--- @return table Map of building ID to BuildingData
function LKS_EletricidadeConstrucao.Data.State.GetAllBuildings(data)
    return data.buildings
end

-- ============================================================================
-- QUERY OPERATIONS
-- ============================================================================

--- Get buildings connected to generator
--- @param data StateData State data
--- @param generatorId string Generator ID
--- @return table Array of BuildingData
function LKS_EletricidadeConstrucao.Data.State.GetGeneratorBuildings(data, generatorId)
    local results = {}
    
    for _, buildingData in pairs(data.buildings) do
        if buildingData.generatorId == generatorId then
            table.insert(results, buildingData)
        end
    end
    
    return results
end

--- Get generators in chunk
--- @param data StateData State data
--- @param chunkKey string Chunk key
--- @return table Array of GeneratorData
function LKS_EletricidadeConstrucao.Data.State.GetGeneratorsInChunk(data, chunkKey)
    local results = {}
    local chunkMap = data.chunkIndex or {}
    local genIds = chunkMap[chunkKey]

    if not genIds then
        return results
    end

    for _, genId in ipairs(genIds) do
        local genData = data.generators[genId]
        if genData then
            table.insert(results, genData)
        else
            -- Stale index entry; clean it lazily
            chunkMap[chunkKey] = chunkMap[chunkKey] or {}
        end
    end

    return results
end

--- Get all active generators
--- @param data StateData State data
--- @return table Array of GeneratorData
function LKS_EletricidadeConstrucao.Data.State.GetActiveGenerators(data)
    local results = {}
    
    for _, generatorData in pairs(data.generators) do
        if LKS_EletricidadeConstrucao.Data.Generator.IsRunning(generatorData) then
            table.insert(results, generatorData)
        end
    end
    
    return results
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

--- Update runtime statistics
--- @param data StateData State data
function LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(data)
    local stats = data.statistics
    
    -- Count generators
    local totalGens = 0
    local activeGens = 0
    for _, genData in pairs(data.generators) do
        totalGens = totalGens + 1
        if LKS_EletricidadeConstrucao.Data.Generator.IsRunning(genData) then
            activeGens = activeGens + 1
        end
    end
    stats.totalGenerators = totalGens
    stats.activeGenerators = activeGens
    
    -- Count buildings and consumers
    local totalBuildings = 0
    local totalConsumers = 0
    local activeConsumers = 0
    for _, bldData in pairs(data.buildings) do
        totalBuildings = totalBuildings + 1
        local _pc = 0
        if bldData.powerConsumers then
            for _ in pairs(bldData.powerConsumers) do _pc = _pc + 1 end
        end
        totalConsumers = totalConsumers + _pc
        activeConsumers = activeConsumers + LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(bldData)
    end
    stats.totalBuildings = totalBuildings
    stats.totalConsumers = totalConsumers
    stats.activeConsumers = activeConsumers
end

--- Record fuel consumption
--- @param data StateData State data
--- @param amount number Fuel amount consumed
function LKS_EletricidadeConstrucao.Data.State.RecordFuelConsumption(data, amount)
    data.statistics.totalFuelConsumed = data.statistics.totalFuelConsumed + amount
end

--- Update uptime
--- @param data StateData State data
--- @param deltaSeconds number Time delta in seconds
function LKS_EletricidadeConstrucao.Data.State.UpdateUptime(data, deltaSeconds)
    data.statistics.uptime = data.statistics.uptime + deltaSeconds
end

-- ============================================================================
-- SYNC OPERATIONS (Multiplayer)
-- ============================================================================

--- Mark full sync completed
--- @param data StateData State data
function LKS_EletricidadeConstrucao.Data.State.MarkFullSync(data)
    data.lastFullSync = getTimestampMs()
    data.lastDeltaSync = getTimestampMs()
end

--- Mark delta sync completed
--- @param data StateData State data
function LKS_EletricidadeConstrucao.Data.State.MarkDeltaSync(data)
    data.lastDeltaSync = getTimestampMs()
end

--- Check if full sync is needed
--- @param data StateData State data
--- @param intervalMs number Full sync interval
--- @return boolean True if needed
function LKS_EletricidadeConstrucao.Data.State.NeedsFullSync(data, intervalMs)
    local currentTime = getTimestampMs()
    return (currentTime - data.lastFullSync) >= intervalMs
end

--- Check if delta sync is needed
--- @param data StateData State data
--- @param intervalMs number Delta sync interval
--- @return boolean True if needed
function LKS_EletricidadeConstrucao.Data.State.NeedsDeltaSync(data, intervalMs)
    local currentTime = getTimestampMs()
    return (currentTime - data.lastDeltaSync) >= intervalMs
end

-- ============================================================================
-- CLEANUP OPERATIONS
-- ============================================================================

--- Clear all generators
--- @param data StateData State data
function LKS_EletricidadeConstrucao.Data.State.ClearGenerators(data)
    data.generators = {}
    data.chunkIndex = {}
    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(data)
end

--- Clear all buildings
--- @param data StateData State data
function LKS_EletricidadeConstrucao.Data.State.ClearBuildings(data)
    data.buildings = {}
    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(data)
end

--- Clear all data
--- @param data StateData State data
function LKS_EletricidadeConstrucao.Data.State.ClearAll(data)
    data.generators = {}
    data.buildings = {}
    data.chunkIndex = {}
    data.statistics.totalFuelConsumed = 0
    data.statistics.uptime = 0
    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(data)
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Get state summary string
--- @param data StateData State data
--- @return string Summary string
function LKS_EletricidadeConstrucao.Data.State.GetSummary(data)
    local stats = data.statistics
    return string.format(
        "LKS_EletricidadeConstrucao State v%s | Generators:%d(%d active) Buildings:%d Consumers:%d(%d active) Fuel:%.1f Uptime:%.1fh",
        data.version,
        stats.totalGenerators,
        stats.activeGenerators,
        stats.totalBuildings,
        stats.totalConsumers,
        stats.activeConsumers,
        stats.totalFuelConsumed,
        stats.uptime / 3600
    )
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Data.State", "2.0.0")

return LKS_EletricidadeConstrucao.Data.State
