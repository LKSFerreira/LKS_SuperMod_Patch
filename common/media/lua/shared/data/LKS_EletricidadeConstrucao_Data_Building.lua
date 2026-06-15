-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Data_Building.lua
-- LKS_EletricidadeConstrucao V2 - Building Data Model
-- Schema definition and operations for building data
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Data_Building] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- SCHEMA DEFINITION
-- ============================================================================

--- Building data schema
--- @class BuildingData
--- @field id string Unique identifier (x_y_z format)
--- @field x number World X coordinate (typically light switch position)
--- @field y number World Y coordinate
--- @field z number World Z coordinate
--- @field generatorId string|nil Connected generator ID
--- @field powerConsumers table Array of consumer data
--- @field totalPowerDraw number Total power consumption
--- @field isPowered boolean Current power state
--- @field borderRadius number Scan radius for this building
--- @field lastScanTime number Last scan timestamp
--- @field boundingBox table|nil Bounding box {minX, minY, maxX, maxY}
--- @field isRVInterior boolean True if building is in RV interior
--- @field heatingPowerDraw number Additional draw from active heating
--- @field heatingEnabled boolean True if heating is active for this building (pool-level fuel calc)
--- @field heatingSourceCount number Number of heating positions for this building (pool-level fuel calc)
--- @field heatingTargetTemp number Heating target temperature in °C (pool-level fuel calc)

local BuildingSchema = {
    id = "",
    x = 0,
    y = 0,
    z = 0,
    generatorId = nil,
    powerConsumers = {},
    totalPowerDraw = 0,
    heatingPowerDraw = 0,
    isPowered = false,
    borderRadius = 0,
    lastScanTime = 0,
    boundingBox = nil,
    isRVInterior = false,
    -- Heating state cached for chunk-independent pool fuel calculation.
    -- Set by Heating.SyncToGenerators; read by CalculateFuelConsumption.
    heatingEnabled = false,
    heatingSourceCount = 0,
    heatingTargetTemp = 22,
}

-- Heating load is treated as an extra power consumer that only applies when
-- the building actually has an active consumer (lights/appliances on). This
-- prevents idle heating stress when nothing is drawing power.
local function ComputeHeatingLoad(buildingData)
    local Constants = LKS_EletricidadeConstrucao.Constants

    -- Require at least one active consumer and a connected generator
    if not buildingData or (buildingData.activeConsumerCount or 0) <= 0 then
        return 0
    end

    -- NOTE: connectedGenerators is a Kahlua-deserialized hash-map after GlobalModData
    -- reload → string numeric keys ("1","2",...).  # always returns 0 on such tables;
    -- use a pairs-based emptiness check instead.
    if not buildingData.connectedGenerators then return 0 end
    local _hasGens = false
    for _ in pairs(buildingData.connectedGenerators) do _hasGens = true; break end
    if not _hasGens then return 0 end

    -- Fast path: building-level heatingEnabled is the authoritative flag written by
    -- Heating.SyncToGenerators and persisted in GlobalModData.  Use it directly so
    -- we don't need IsoObject access (which fails off-chunk) and avoid Kahlua issues.
    if buildingData.heatingEnabled and buildingData.heatingSourceCount
       and buildingData.heatingSourceCount > 0 then
        local baseLoad  = (Constants.HEATING and Constants.HEATING.HEATING_POWER_PER_ROOM) or 0.5
        local perDegree = baseLoad * 0.10
        local targetT   = buildingData.heatingTargetTemp or 22
        local delta     = targetT - 20
        local loadPerSrc = baseLoad + perDegree * delta
        return loadPerSrc * buildingData.heatingSourceCount
    end

    -- Fallback: no building-level heating data yet (first session after upgrade),
    -- read live from IsoObject ModData.  Requires chunk to be loaded.
    local cell = getCell()
    if not cell then return 0 end

    -- Collect heating configuration from ANY active generator in the pool.
    -- This ensures heating continues working even if the primary generator
    -- is deactivated and a backup generator takes over (pool failover).
    local heatingConfig = nil
    -- Fallback-path constants (fast-path returned above if building-level data was present)
    local baseLoad  = (Constants.HEATING and Constants.HEATING.HEATING_POWER_PER_ROOM) or 0.5
    local perDegree = baseLoad * 0.10
    local baselineT = 20

    -- Use pairs: Kahlua-deserialized connectedGenerators has string numeric keys.
    for _, genKey in pairs(buildingData.connectedGenerators) do
        local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if gx then
            local sq = cell:getGridSquare(tonumber(gx), tonumber(gy), tonumber(gz))
            if sq then
                local objs = sq:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local gen = objs:get(i)
                        if gen and instanceof(gen, "IsoGenerator") then
                            local gmd = gen:getModData()
                            -- If this generator has heating enabled and is active, use its config
                            if gmd and gmd.HeatingEnabled == true and gen:isActivated() and type(gmd.HeatingPositions) == "table" then
                                local srcCount = 0
                                for _, grp in pairs(gmd.HeatingPositions) do
                                    if type(grp.positions) == "table" then
                                        -- grp.positions may also be Kahlua-deserialized
                                        local posCount = 0
                                        for _ in pairs(grp.positions) do posCount = posCount + 1 end
                                        srcCount = srcCount + posCount
                                    end
                                end
                                if srcCount > 0 then
                                    local target = tonumber(gmd.HeatingTargetTemp) or 22
                                    -- Allow delta to be negative (temps below baseline reduce load)
                                    local delta = target - baselineT
                                    local loadPerSrc = baseLoad + perDegree * delta
                                    heatingConfig = {
                                        load = loadPerSrc * srcCount,
                                        target = target,
                                        sources = srcCount
                                    }
                                    -- Found an active generator with heating - use this config
                                    break
                                end
                            -- If generator is inactive but has heating config, store as fallback
                            elseif gmd and gmd.HeatingEnabled == true and not heatingConfig and type(gmd.HeatingPositions) == "table" then
                                local srcCount = 0
                                for _, grp in pairs(gmd.HeatingPositions) do
                                    if type(grp.positions) == "table" then
                                        local posCount = 0
                                        for _ in pairs(grp.positions) do posCount = posCount + 1 end
                                        srcCount = srcCount + posCount
                                    end
                                end
                                if srcCount > 0 then
                                    local target = tonumber(gmd.HeatingTargetTemp) or 22
                                    local delta = target - baselineT
                                    local loadPerSrc = baseLoad + perDegree * delta
                                    heatingConfig = {
                                        load = loadPerSrc * srcCount,
                                        target = target,
                                        sources = srcCount
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
        -- If we found an active generator with heating, stop searching
        if heatingConfig and heatingConfig.load then
            break
        end
    end

    -- Return the heating load from active generator, or fallback to inactive generator config
    return heatingConfig and heatingConfig.load or 0
end

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

--- Create new building data instance
--- @param lightSwitch IsoLightSwitch The light switch object (building anchor)
--- @param radius number Border scan radius
--- @return BuildingData New building data
function LKS_EletricidadeConstrucao.Data.Building.New(lightSwitch, radius)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    local Geometry = LKS_EletricidadeConstrucao.Utils.Geometry
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    
    -- Validate input
    Validation.AssertNotNil(lightSwitch, "Light switch object cannot be nil")
    Validation.Assert(Validation.IsLightSwitch(lightSwitch), "Object must be IsoLightSwitch")
    
    -- Get coordinates
    local x = lightSwitch:getX()
    local y = lightSwitch:getY()
    local z = lightSwitch:getZ()
    
    -- Create data instance
    local data = Table.DeepCopy(BuildingSchema)
    
    -- Set coordinates
    data.x = x
    data.y = y
    data.z = z
    data.id = LKS_EletricidadeConstrucao.Data.Building.MakeId(x, y, z)
    
    -- Set radius
    local Constants = LKS_EletricidadeConstrucao.Constants
    data.borderRadius = radius or Constants.BUILDING.DEFAULT_BORDER_RADIUS or 10
    
    -- Detect RV interior
    data.isRVInterior = Geometry.IsRVInteriorCoordinate(x, y, z)
    
    -- Set timestamp
    data.lastScanTime = getTimestampMs()
    
    return data
end

-- ============================================================================
-- ID GENERATION
-- ============================================================================

--- Generate building ID from coordinates
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate
--- @return string Building ID
function LKS_EletricidadeConstrucao.Data.Building.MakeId(x, y, z)
    return string.format("bld_%d_%d_%d", x, y, z)
end

--- Parse building ID to coordinates
--- @param id string Building ID
--- @return number|nil, number|nil, number|nil X, Y, Z or nil if invalid
function LKS_EletricidadeConstrucao.Data.Building.ParseId(id)
    if not id then return nil, nil, nil end
    
    local x, y, z = id:match("bld_(-?%d+)_(-?%d+)_(-?%d+)")
    if not x then return nil, nil, nil end
    
    return tonumber(x), tonumber(y), tonumber(z)
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

--- Validate building data structure
--- @param data BuildingData Data to validate
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Data.Building.Validate(data)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Check if table
    if not Validation.IsTable(data) then
        return false, "Building data must be a table"
    end
    
    -- Validate required fields
    local valid, err = Validation.ValidateKeys(data, {
        "id", "x", "y", "z", "powerConsumers", "totalPowerDraw",
        "heatingPowerDraw", "isPowered", "borderRadius", "lastScanTime"
    }, "Building data")
    
    if not valid then return false, err end
    
    -- Validate ID
    valid, err = Validation.ValidateNotEmpty(data.id, "Building ID")
    if not valid then return false, err end
    
    -- Validate coordinates
    valid, err = Validation.ValidateCoordinates(data.x, data.y, data.z)
    if not valid then return false, err end
    
    -- Validate boolean fields
    if not Validation.IsBoolean(data.isPowered) then
        return false, "isPowered must be boolean"
    end
    
    -- Validate numeric fields
    valid, err = Validation.ValidateNonNegative(data.totalPowerDraw, "totalPowerDraw")
    if not valid then return false, err end
    
    valid, err = Validation.ValidatePositive(data.borderRadius, "borderRadius")
    if not valid then return false, err end
    
    -- Validate consumers is table
    if not Validation.IsTable(data.powerConsumers) then
        return false, "powerConsumers must be a table"
    end
    
    -- Validate generatorId if set
    if data.generatorId ~= nil and not Validation.IsString(data.generatorId) then
        return false, "generatorId must be string or nil"
    end
    
    return true, nil
end

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

--- Serialize building data for ModData storage
--- @param data BuildingData Data to serialize
--- @return table Serialized data
function LKS_EletricidadeConstrucao.Data.Building.Serialize(data)
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local copy = Table.DeepCopy(data)
    -- Option A (B-99): powerConsumers and heating config are ephemeral — never persisted.
    --   powerConsumers  : always rebuilt by ScanBuilding on each chunk load; saving them
    --                     was the root cause of B-87 through B-97 (stale consumer counts).
    --   heatingEnabled / heatingTargetTemp / heatingSourceCount / heatingPowerDraw:
    --                     always read from IsoObject ModData on chunk load (TryRestore
    --                     Phase B); persisting them recreated the sync bug fixed by B-97A.
    copy.powerConsumers     = nil
    copy.heatingEnabled     = nil
    copy.heatingSourceCount = nil
    copy.heatingTargetTemp  = nil
    copy.heatingPowerDraw   = nil
    return copy
end

--- Deserialize building data from ModData
--- @param serialized table Serialized data
--- @return BuildingData|nil Deserialized data or nil if invalid
function LKS_EletricidadeConstrucao.Data.Building.Deserialize(serialized)
    if not serialized then return nil end
    
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local data = Table.DeepCopy(serialized)

    -- B-99 stopped persisting ephemeral consumer/heating scan results.
    -- Older/newer saves therefore need these runtime-only fields restored here.
    if data.powerConsumers == nil then data.powerConsumers = {} end
    -- Backward compatibility: older saves may lack heating fields
    if data.heatingPowerDraw  == nil then data.heatingPowerDraw  = 0     end
    if data.heatingEnabled    == nil then data.heatingEnabled    = false  end
    if data.heatingSourceCount == nil then data.heatingSourceCount = 0   end
    if data.heatingTargetTemp  == nil then data.heatingTargetTemp  = 22  end
    
    -- Validate deserialized data
    local valid, err = LKS_EletricidadeConstrucao.Data.Building.Validate(data)
    if not valid then
        LKS_EletricidadeConstrucao.Error("[Building.Deserialize] Invalid data: " .. err)
        return nil
    end
    
    return data
end

-- ============================================================================
-- CONSUMER OPERATIONS
-- ============================================================================

--- Add power consumer to building
--- @param data BuildingData Building data
--- @param consumer ConsumerData Consumer data to add
function LKS_EletricidadeConstrucao.Data.Building.AddConsumer(data, consumer)
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local maxConsumers = ((LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.BUILDING)
        and LKS_EletricidadeConstrucao.Constants.BUILDING.MAX_CONSUMERS_PER_BUILDING) or 500

    local consumerCount = 0
    for _ in pairs(data.powerConsumers) do
        consumerCount = consumerCount + 1
    end

    if consumerCount >= maxConsumers then
        return
    end
    
    -- Check if already exists
    local exists = Table.Find(data.powerConsumers, function(c)
        return c.squareX == consumer.squareX 
            and c.squareY == consumer.squareY 
            and c.squareZ == consumer.squareZ
    end)
    
    if not exists then
        table.insert(data.powerConsumers, consumer)
        LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(data)
    end
end

--- Remove power consumer from building
--- @param data BuildingData Building data
--- @param squareX number Consumer X coordinate
--- @param squareY number Consumer Y coordinate
--- @param squareZ number Consumer Z coordinate
function LKS_EletricidadeConstrucao.Data.Building.RemoveConsumer(data, squareX, squareY, squareZ)
    -- Rebuild list excluding matching consumer.
    -- Cannot use reverse-index loop: after GlobalModData deserialization Kahlua
    -- assigns string numeric keys so #data.powerConsumers == 0 and the loop body
    -- would never execute.
    local newConsumers = {}
    for _, consumer in pairs(data.powerConsumers) do
        if not (consumer.squareX == squareX
           and consumer.squareY == squareY
           and consumer.squareZ == squareZ) then
            table.insert(newConsumers, consumer)
        end
    end
    data.powerConsumers = newConsumers
    
    LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(data)
end

--- Clear all power consumers
--- @param data BuildingData Building data
function LKS_EletricidadeConstrucao.Data.Building.ClearConsumers(data)
    data.powerConsumers = {}
    data.totalPowerDraw = 0
end

--- Recalculate total power draw
--- Sums ALL consumers unconditionally - power draw represents what the building
--- WOULD consume when powered (matches V1 behaviour).
--- isActive is tracked separately for the "X/Y active" UI display.
--- @param data BuildingData Building data
function LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(data)
    local total = 0
    local activeCount = 0

    -- powerConsumers is Kahlua-deserialized (string numeric keys); pairs required
    for _, consumer in pairs(data.powerConsumers) do
        -- Only count active consumers for power draw and strain calculation
        if consumer.isActive then
            total = total + (consumer.powerDraw or 1)
            activeCount = activeCount + 1
        end
    end

    -- Heating adds dynamic load based on target temp; only while something is on.
    local heatingLoad = ComputeHeatingLoad(data)
    data.heatingPowerDraw = heatingLoad

    total = total + heatingLoad

    data.totalPowerDraw = total
    data.activeConsumerCount = activeCount
    -- pairs-count: powerConsumers may be Kahlua-deserialized (string numeric keys)
    local _tc = 0
    for _ in pairs(data.powerConsumers) do _tc = _tc + 1 end
    data.totalConsumers = _tc
end

-- ============================================================================
-- POWER STATE OPERATIONS
-- ============================================================================

--- Set building power state
--- @param data BuildingData Building data
--- @param powered boolean Power state
function LKS_EletricidadeConstrucao.Data.Building.SetPowered(data, powered)
    if data.isPowered ~= powered then
        data.isPowered = powered
        -- Event will be triggered by caller
    end
end

--- Connect building to generator
--- @param data BuildingData Building data
--- @param generatorId string Generator ID
function LKS_EletricidadeConstrucao.Data.Building.ConnectGenerator(data, generatorId)
    if data.generatorId ~= generatorId then
        data.generatorId = generatorId
        -- Event will be triggered by caller
    end
end

--- Disconnect building from generator
--- @param data BuildingData Building data
function LKS_EletricidadeConstrucao.Data.Building.DisconnectGenerator(data)
    data.generatorId = nil
    LKS_EletricidadeConstrucao.Data.Building.SetPowered(data, false)
end

-- ============================================================================
-- SCAN OPERATIONS
-- ============================================================================

--- Update last scan time
--- @param data BuildingData Building data
function LKS_EletricidadeConstrucao.Data.Building.MarkScanned(data)
    data.lastScanTime = getTimestampMs()
end

--- Check if building needs rescan
--- @param data BuildingData Building data
--- @param intervalMs number Scan interval in milliseconds
--- @return boolean True if needs rescan
function LKS_EletricidadeConstrucao.Data.Building.NeedsRescan(data, intervalMs)
    local currentTime = getTimestampMs()
    return (currentTime - data.lastScanTime) >= intervalMs
end

--- Set bounding box for building
--- @param data BuildingData Building data
--- @param minX number Minimum X
--- @param minY number Minimum Y
--- @param maxX number Maximum X
--- @param maxY number Maximum Y
function LKS_EletricidadeConstrucao.Data.Building.SetBoundingBox(data, minX, minY, maxX, maxY)
    data.boundingBox = {
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY
    }
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Check if building is connected to a generator
--- @param data BuildingData Building data
--- @return boolean True if connected
function LKS_EletricidadeConstrucao.Data.Building.IsConnected(data)
    return data.generatorId ~= nil
end

--- Get number of active consumers
--- @param data BuildingData Building data
--- @return number Count of active consumers
function LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(data)
    local count = 0
    -- powerConsumers is Kahlua-deserialized (string numeric keys); pairs required
    for _, consumer in pairs(data.powerConsumers) do
        if consumer.isActive then
            count = count + 1
        end
    end
    return count
end

--- Get total consumer count
--- @param data BuildingData Building data
--- @return number Total consumers
function LKS_EletricidadeConstrucao.Data.Building.GetTotalConsumerCount(data)
    local count = 0
    for _ in pairs(data.powerConsumers) do count = count + 1 end
    return count
end

--- Check if building should provide power based on generator state
--- @param data BuildingData Building data
--- @param generatorData GeneratorData|nil Generator data (optional)
--- @return boolean True if should provide power
function LKS_EletricidadeConstrucao.Data.Building.ShouldProvidePower(data, generatorData)
    if not data.generatorId then
        return false
    end
    
    if generatorData then
        -- Check if generator is actually running
        return LKS_EletricidadeConstrucao.Data.Generator.IsRunning(generatorData)
    end
    
    -- Assume powered if connected (generator state unknown)
    return true
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Convert building data to string for debugging
--- @param data BuildingData Building data
--- @return string String representation
function LKS_EletricidadeConstrucao.Data.Building.ToString(data)
    return string.format(
        "Building[%s] at (%d,%d,%d) | Gen:%s Powered:%s Consumers:%d/%d Power:%.1f Radius:%d",
        data.id,
        data.x, data.y, data.z,
        data.generatorId or "none",
        tostring(data.isPowered),
        LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(data),
        (function() local n=0; for _ in pairs(data.powerConsumers) do n=n+1 end; return n end)(),
        data.totalPowerDraw,
        data.borderRadius
    )
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Data.Building", "2.0.0")

return LKS_EletricidadeConstrucao.Data.Building
