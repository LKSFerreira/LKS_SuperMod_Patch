-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Data_Generator.lua
-- LKS_EletricidadeConstrucao V2 - Generator Data Model
-- Schema definition and operations for generator data
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Data_Generator] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- SCHEMA DEFINITION
-- ============================================================================

--- Generator data schema
--- @class GeneratorData
--- @field id string Unique identifier (x_y_z format)
--- @field x number World X coordinate
--- @field y number World Y coordinate
--- @field z number World Z coordinate
--- @field activated boolean Generator activated state
--- @field fuelAmount number Current fuel amount (0-100)
--- @field condition number Generator condition (0-100)
--- @field connectedBuildings table Array of building IDs
--- @field strain number Current load strain (0-100+)
--- @field lastUpdateTime number Last update timestamp (real-world ms, for logging)
--- @field lastUnloadGameMinutes number|nil DEPRECATED - no longer used (fuel calc runs continuously)
--- @field chunkKey string Chunk key for tracking (chunk_X_Y)
--- @field customFuelRate number|nil Custom fuel consumption rate override
--- @field isRVInterior boolean True if generator is in RV interior
-- Note: heatingEnabled / heatingSourceCount / heatingTargetTemp removed in B-99.
-- Heating config is now IsoObject-only (TryRestoreFromIsoModData Phase B populates
-- bldData.heatingEnabled directly from md.HeatingEnabled on every chunk load).

local GeneratorSchema = {
    id = "",
    x = 0,
    y = 0,
    z = 0,
    activated = false,
    fuelAmount = 0,
    condition = 100,
    connectedBuildings = {},
    strain = 0,
    lastUpdateTime = 0,
    -- lastUnloadGameMinutes removed - no longer needed with continuous fuel calc
    chunkKey = "",
    customFuelRate = nil,
    isRVInterior = false,
    -- heatingEnabled / heatingSourceCount / heatingTargetTemp removed in B-99 (Option A):
    -- these were kept for off-chunk fuel calc but FuelManager already reads
    -- bldData.heatingEnabled (set from IsoObject on chunk load) which is correct.
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

--- Create new generator data instance
--- @param generator IsoGenerator The generator object
--- @return GeneratorData New generator data
function LKS_EletricidadeConstrucao.Data.Generator.New(generator)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    local Geometry = LKS_EletricidadeConstrucao.Utils.Geometry
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    
    -- Validate input
    Validation.AssertNotNil(generator, "Generator object cannot be nil")
    Validation.Assert(Validation.IsGenerator(generator), "Object must be IsoGenerator")
    
    -- Get coordinates
    local x = generator:getX()
    local y = generator:getY()
    local z = generator:getZ()
    
    -- Create data instance
    local data = Table.DeepCopy(GeneratorSchema)
    
    -- Set coordinates
    data.x = x
    data.y = y
    data.z = z
    data.id = LKS_EletricidadeConstrucao.Data.Generator.MakeId(x, y, z)
    
    -- Set initial state from generator object
    data.activated = generator:isActivated()
    data.fuelAmount = generator:getFuel()
    data.condition = generator:getCondition()
    
    -- Set chunk key
    data.chunkKey = Geometry.GetChunkKey(x, y)
    
    -- Detect RV interior
    data.isRVInterior = Geometry.IsRVInteriorCoordinate(x, y, z)
    
    -- Set timestamp
    data.lastUpdateTime = getTimestampMs()
    
    return data
end

-- ============================================================================
-- ID GENERATION
-- ============================================================================

--- Generate generator ID from coordinates
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate
--- @return string Generator ID
function LKS_EletricidadeConstrucao.Data.Generator.MakeId(x, y, z)
    return string.format("gen_%d_%d_%d", x, y, z)
end

--- Parse generator ID to coordinates
--- @param id string Generator ID
--- @return number|nil, number|nil, number|nil X, Y, Z or nil if invalid
function LKS_EletricidadeConstrucao.Data.Generator.ParseId(id)
    if not id then return nil, nil, nil end
    
    local x, y, z = id:match("gen_(-?%d+)_(-?%d+)_(-?%d+)")
    if not x then return nil, nil, nil end
    
    return tonumber(x), tonumber(y), tonumber(z)
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

--- Validate generator data structure
--- @param data GeneratorData Data to validate
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Data.Generator.Validate(data)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Check if table
    if not Validation.IsTable(data) then
        return false, "Generator data must be a table"
    end
    
    -- Validate required fields
    local valid, err = Validation.ValidateKeys(data, {
        "id", "x", "y", "z", "activated", "fuelAmount", "condition",
        "connectedBuildings", "strain", "lastUpdateTime", "chunkKey"
    }, "Generator data")
    
    if not valid then return false, err end
    
    -- Validate ID
    valid, err = Validation.ValidateNotEmpty(data.id, "Generator ID")
    if not valid then return false, err end
    
    -- Validate coordinates
    valid, err = Validation.ValidateCoordinates(data.x, data.y, data.z)
    if not valid then return false, err end
    
    -- Validate boolean fields
    if not Validation.IsBoolean(data.activated) then
        return false, "activated must be boolean"
    end
    
    -- Validate numeric ranges
    valid, err = Validation.ValidateRange(data.fuelAmount, 0, 100, "fuelAmount")
    if not valid then return false, err end
    
    valid, err = Validation.ValidateRange(data.condition, 0, 100, "condition")
    if not valid then return false, err end
    
    valid, err = Validation.ValidateNonNegative(data.strain, "strain")
    if not valid then return false, err end
    
    -- Validate connected buildings is table
    if not Validation.IsTable(data.connectedBuildings) then
        return false, "connectedBuildings must be a table"
    end
    
    return true, nil
end

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

--- Serialize generator data for ModData storage
--- @param data GeneratorData Data to serialize
--- @return table Serialized data
function LKS_EletricidadeConstrucao.Data.Generator.Serialize(data)
    -- Generator data is already in simple table format
    -- Just create a clean copy
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    return Table.DeepCopy(data)
end

--- Deserialize generator data from ModData
--- @param serialized table Serialized data
--- @return GeneratorData|nil Deserialized data or nil if invalid
function LKS_EletricidadeConstrucao.Data.Generator.Deserialize(serialized)
    if not serialized then return nil end
    
    local Table       = LKS_EletricidadeConstrucao.Utils.Table
    local Geometry    = LKS_EletricidadeConstrucao.Utils.Geometry
    local Validation  = LKS_EletricidadeConstrucao.Utils.Validation
    local data        = Table.DeepCopy(serialized)

    -- Backward compatibility: older saves may miss new fields (e.g., lastUpdateTime).
    -- Merge with the current schema defaults before validating.
    for k, v in pairs(GeneratorSchema) do
        if data[k] == nil then
            data[k] = v
        end
    end
    
    -- Debug: log which fuel amount was loaded from ModData
    print(string.format("[LKS_EletricidadeConstrucao_DESERIALIZE] gen=%s fuelAmount=%.2f (from ModData)", 
        data.id or "?", data.fuelAmount or 0))
    -- Rebuild chunkKey if absent.
    if (not data.chunkKey or data.chunkKey == "") and Geometry then
        data.chunkKey = Geometry.GetChunkKey(data.x or 0, data.y or 0)
    end
    -- Ensure connectedBuildings is a table.
    if not (Validation and Validation.IsTable and Validation.IsTable(data.connectedBuildings)) then
        data.connectedBuildings = {}
    end

    -- Validate deserialized data
    local valid, err = LKS_EletricidadeConstrucao.Data.Generator.Validate(data)
    if not valid then
        LKS_EletricidadeConstrucao.Error("[Generator.Deserialize] Invalid data: " .. err)
        return nil
    end
    
    return data
end

-- ============================================================================
-- UPDATE OPERATIONS
-- ============================================================================

--- Update generator data from generator object
--- @param data GeneratorData Data to update
--- @param generator IsoGenerator Generator object
function LKS_EletricidadeConstrucao.Data.Generator.UpdateFromObject(data, generator)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    Validation.AssertNotNil(data, "Generator data cannot be nil")
    Validation.AssertNotNil(generator, "Generator object cannot be nil")
    
    -- Update state
    data.activated = generator:isActivated()
    data.fuelAmount = generator:getFuel()
    data.condition = generator:getCondition()
    data.lastUpdateTime = getTimestampMs()
end

--- Calculate current strain based on connected buildings
--- @param data GeneratorData Generator data
--- @param buildingDataMap table Map of building ID to building data
--- @return number Calculated strain (0-100+)
function LKS_EletricidadeConstrucao.Data.Generator.CalculateStrain(data, buildingDataMap)
    local totalPower = 0
    
    -- Sum power from all connected buildings
    -- connectedBuildings is Kahlua-deserialized (string numeric keys); use pairs
    for _, buildingId in pairs(data.connectedBuildings) do
        local buildingData = buildingDataMap[buildingId]
        if buildingData then
            totalPower = totalPower + (buildingData.totalPowerDraw or 0)
        end
    end
    
    -- Convert to strain percentage
    -- Base: 1 light = 1%, configurable via constants
    local Constants = LKS_EletricidadeConstrucao.Constants
    local baseStrain = Constants.FUEL.BASE_STRAIN_PER_LIGHT or 1.0
    
    return totalPower * baseStrain
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Check if generator is running (activated and has fuel)
--- @param data GeneratorData Generator data
--- @return boolean True if running
function LKS_EletricidadeConstrucao.Data.Generator.IsRunning(data)
    -- Generator is running if it has fuel AND is not explicitly deactivated
    -- (activated == false means explicitly deactivated, nil or true means active)
    local hasFuel = (data.fuelAmount or 0) > 0
    local notDeactivated = (data.activated ~= false)  -- true if nil or true
    return hasFuel and notDeactivated
end

--- Check if generator needs refuel
--- @param data GeneratorData Generator data
--- @param threshold number Fuel threshold (default: 10)
--- @return boolean True if needs refuel
function LKS_EletricidadeConstrucao.Data.Generator.NeedsRefuel(data, threshold)
    threshold = threshold or 10
    return data.fuelAmount < threshold
end

--- Get remaining runtime in hours
--- @param data GeneratorData Generator data
--- @param fuelRate number Fuel consumption rate per hour
--- @return number Hours remaining
function LKS_EletricidadeConstrucao.Data.Generator.GetRemainingHours(data, fuelRate)
    if not data.activated or data.fuelAmount <= 0 then
        return 0
    end
    
    -- Apply tiered strain modifier
    local strainMultiplier = 1.0
    if data.strain > 0 then
        local strain = data.strain
        
        -- TIERED STRAIN SYSTEM (matches server-side StrainCalculator):
        -- 0-50%: No extra fuel (1.0x)
        -- 51-75%: 1.0x to 1.25x
        -- 76-100%: 1.26x to 1.75x
        -- 101-200%: 1.75x to 3.0x
        
        if strain <= 50 then
            strainMultiplier = 1.0
        elseif strain <= 75 then
            local t = (strain - 50) / 25
            strainMultiplier = 1.0 + (t * 0.25)
        elseif strain <= 100 then
            local t = (strain - 75) / 25
            strainMultiplier = 1.26 + (t * 0.49)
        else
            local t = math.min((strain - 100) / 100, 1.0)
            strainMultiplier = 1.75 + (t * 1.25)
        end
        
        -- Cap at maximum
        local Constants = LKS_EletricidadeConstrucao.Constants
        local maxMultiplier = Constants.FUEL.MAX_STRAIN_MULTIPLIER or 3.0
        if strainMultiplier > maxMultiplier then
            strainMultiplier = maxMultiplier
        end
    end
    
    local effectiveRate = fuelRate * strainMultiplier
    
    if effectiveRate <= 0 then
        return 999999 -- Infinite
    end
    
    return data.fuelAmount / effectiveRate
end

--- Add connected building
--- @param data GeneratorData Generator data
--- @param buildingId string Building ID to add
function LKS_EletricidadeConstrucao.Data.Generator.AddBuilding(data, buildingId)
    -- connectedBuildings may be Kahlua-deserialized (string numeric keys); use pairs
    local already = false
    for _, v in pairs(data.connectedBuildings) do
        if v == buildingId then already = true; break end
    end
    if not already then
        table.insert(data.connectedBuildings, buildingId)
    end
end

--- Remove connected building
--- @param data GeneratorData Generator data
--- @param buildingId string Building ID to remove
function LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding(data, buildingId)
    -- Rebuild list excluding target: cannot use index-based remove on Kahlua
    -- string-key tables where #t == 0 and integer indices don't exist.
    local newList = {}
    for _, v in pairs(data.connectedBuildings) do
        if v ~= buildingId then table.insert(newList, v) end
    end
    data.connectedBuildings = newList
end

--- Clear all connected buildings
--- @param data GeneratorData Generator data
function LKS_EletricidadeConstrucao.Data.Generator.ClearBuildings(data)
    data.connectedBuildings = {}
    data.strain = 0
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Convert generator data to string for debugging
--- @param data GeneratorData Generator data
--- @return string String representation
function LKS_EletricidadeConstrucao.Data.Generator.ToString(data)
    local _n = 0
    if data.connectedBuildings then
        for _ in pairs(data.connectedBuildings) do _n = _n + 1 end
    end
    return string.format(
        "Generator[%s] at (%d,%d,%d) | Active:%s Fuel:%.1f Condition:%d Strain:%.1f Buildings:%d",
        data.id,
        data.x, data.y, data.z,
        tostring(data.activated),
        data.fuelAmount,
        data.condition,
        data.strain,
        _n
    )
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Data.Generator", "2.0.0")

return LKS_EletricidadeConstrucao.Data.Generator
