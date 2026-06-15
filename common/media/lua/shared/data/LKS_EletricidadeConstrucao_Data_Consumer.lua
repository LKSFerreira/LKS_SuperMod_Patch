-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Data_Consumer.lua
-- LKS_EletricidadeConstrucao V2 - Consumer Data Model
-- Schema definition and operations for power consumer data (lights, appliances, etc.)
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Data_Consumer] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- SCHEMA DEFINITION
-- ============================================================================

--- Consumer data schema
--- @class ConsumerData
--- @field squareX number Grid square X coordinate
--- @field squareY number Grid square Y coordinate
--- @field squareZ number Grid square Z coordinate
--- @field objectType string Type of consumer ("light", "appliance", "lamp", etc.)
--- @field applianceType string|nil Specific appliance subtype ("fridge", "tv", "radio", "stove", "washer", "dryer", "freezer", "microwave")
--- @field isActive boolean Current active state (on/off)
--- @field powerDraw number Power consumption value (for strain calculation)
--- @field fuelConsumptionLph number Fuel consumption in L/h (vanilla-specific rate)
--- @field objectIndex number|nil Object index in square (for multiple objects)
--- @field sprite string|nil Sprite name for identification

local ConsumerSchema = {
    squareX = 0,
    squareY = 0,
    squareZ = 0,
    objectType = "light",
    applianceType = nil,
    isActive = false,
    powerDraw = 1,
    fuelConsumptionLph = 0.002,
    objectIndex = nil,
    sprite = nil
}

-- ============================================================================
-- CONSUMER TYPES
-- ============================================================================

LKS_EletricidadeConstrucao.Data.Consumer.Types = {
    LIGHT = "light",
    LAMP = "lamp",
    APPLIANCE = "appliance",
    UNKNOWN = "unknown"
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

--- Create new consumer data instance
--- @param square IsoGridSquare Grid square containing consumer
--- @param objectType string Type of consumer
--- @param objectIndex number|nil Object index (optional)
--- @return ConsumerData New consumer data
function LKS_EletricidadeConstrucao.Data.Consumer.New(square, objectType, objectIndex)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    
    -- Validate input
    Validation.AssertNotNil(square, "Grid square cannot be nil")
    Validation.Assert(Validation.IsGridSquare(square), "Object must be IsoGridSquare")
    
    -- Create data instance
    local data = Table.DeepCopy(ConsumerSchema)
    
    -- Set coordinates
    data.squareX = square:getX()
    data.squareY = square:getY()
    data.squareZ = square:getZ()
    
    -- Set type
    data.objectType = objectType or LKS_EletricidadeConstrucao.Data.Consumer.Types.UNKNOWN
    
    -- Set object index
    data.objectIndex = objectIndex
    
    -- Detect initial state and power draw
    LKS_EletricidadeConstrucao.Data.Consumer.UpdateFromSquare(data, square)
    
    return data
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

--- Validate consumer data structure
--- @param data ConsumerData Data to validate
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Data.Consumer.Validate(data)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Check if table
    if not Validation.IsTable(data) then
        return false, "Consumer data must be a table"
    end
    
    -- Validate required fields
    local valid, err = Validation.ValidateKeys(data, {
        "squareX", "squareY", "squareZ", "objectType", 
        "isActive", "powerDraw"
    }, "Consumer data")
    
    if not valid then return false, err end
    
    -- Validate coordinates
    valid, err = Validation.ValidateCoordinates(data.squareX, data.squareY, data.squareZ)
    if not valid then return false, err end
    
    -- Validate object type
    valid, err = Validation.ValidateNotEmpty(data.objectType, "objectType")
    if not valid then return false, err end
    
    -- Validate boolean
    if not Validation.IsBoolean(data.isActive) then
        return false, "isActive must be boolean"
    end
    
    -- Validate power draw
    valid, err = Validation.ValidateNonNegative(data.powerDraw, "powerDraw")
    if not valid then return false, err end
    
    return true, nil
end

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

--- Serialize consumer data for ModData storage
--- @param data ConsumerData Data to serialize
--- @return table Serialized data
function LKS_EletricidadeConstrucao.Data.Consumer.Serialize(data)
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    return Table.DeepCopy(data)
end

--- Deserialize consumer data from ModData
--- @param serialized table Serialized data
--- @return ConsumerData|nil Deserialized data or nil if invalid
function LKS_EletricidadeConstrucao.Data.Consumer.Deserialize(serialized)
    if not serialized then return nil end
    
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local data = Table.DeepCopy(serialized)
    
    -- Validate deserialized data
    local valid, err = LKS_EletricidadeConstrucao.Data.Consumer.Validate(data)
    if not valid then
        LKS_EletricidadeConstrucao.Error("[Consumer.Deserialize] Invalid data: " .. err)
        return nil
    end
    
    return data
end

-- ============================================================================
-- UPDATE OPERATIONS
-- ============================================================================

--- Detect the active (user-on) state of an appliance directly from the ISO
--- objects on a grid square without requiring a powered building check.
--- Mirrors the logic in LKS_EletricidadeConstrucao_Power_Distributor.GetApplianceActiveState so that
--- newly-scanned consumers start with the correct state even before ForceUpdate.
--- @param square IsoGridSquare Grid square to inspect
--- @return boolean True if any recognised appliance on the square is on
function LKS_EletricidadeConstrucao.Data.Consumer.GetApplianceStateFromSquare(square)
    if not square then return false end
    local objects = square:getObjects()
    if not objects then return false end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            -- Television / world-gen TV (IsoRadio)
            if instanceof(obj, "IsoTelevision") or instanceof(obj, "IsoRadio") then
                if obj.getDeviceData then
                    local dev = obj:getDeviceData()
                    if dev and dev.getIsTurnedOn then
                        return dev:getIsTurnedOn()
                    end
                end
                return false
            end
            -- Stove
            if instanceof(obj, "IsoStove") then
                return obj.Activated and obj:Activated() or false
            end
            -- Moveable washer / dryer
            if instanceof(obj, "IsoClothingDryer")
            or instanceof(obj, "IsoClothingWasher")
            or instanceof(obj, "IsoCombinationWasherDryer")
            or instanceof(obj, "IsoStackedWasherDryer") then
                return obj.isActivated and obj:isActivated() or false
            end
            -- World-gen containers (fridge, freezer, washer, dryer)
            if obj.getContainerByType then
                if obj:getContainerByType("clothingdryer")  ~= nil
                or obj:getContainerByType("clothingwasher") ~= nil then
                    return obj.isActivated and obj:isActivated() or false
                end
                if obj:getContainerByType("fridge")   ~= nil
                or obj:getContainerByType("freezer")  ~= nil then
                    return true   -- fridges are always active when powered
                end
            end
        end
    end
    return false   -- sprite-only / unknown appliance: default inactive
end

--- Update consumer data from grid square
--- @param data ConsumerData Consumer data
--- @param square IsoGridSquare Grid square
function LKS_EletricidadeConstrucao.Data.Consumer.UpdateFromSquare(data, square)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    Validation.AssertNotNil(square, "Grid square cannot be nil")
    
    -- NOTE: square:haveElectricity() checks vanilla PZ power, NOT generator power.
    -- This mod manages its own power state, so we derive isActive differently:
    --   • Appliances: inspect the actual ISO object's on/off state right now.
    --   • Lights / lamps: default to active (true); the Distributor will correct
    --     this on the next UpdateBuildingPower pass for light-switches.
    if data.objectType == LKS_EletricidadeConstrucao.Data.Consumer.Types.APPLIANCE then
        data.isActive = LKS_EletricidadeConstrucao.Data.Consumer.GetApplianceStateFromSquare(square)
    else
        data.isActive = true   -- lights / lamps: assume on until proven otherwise
    end
    
    -- Always recalculate power draw from type.
    data.powerDraw = LKS_EletricidadeConstrucao.Data.Consumer.CalculatePowerDraw(data, square)
end

--- Calculate power draw for consumer
--- @param data ConsumerData Consumer data
--- @param square IsoGridSquare|nil Grid square (optional)
--- @return number Power draw value
function LKS_EletricidadeConstrucao.Data.Consumer.CalculatePowerDraw(data, square)
    local Constants = LKS_EletricidadeConstrucao.Constants.FUEL
    
    -- Base power draw by type
    if data.objectType == LKS_EletricidadeConstrucao.Data.Consumer.Types.LIGHT then
        return Constants.POWER_DRAW_LIGHT or 1
    elseif data.objectType == LKS_EletricidadeConstrucao.Data.Consumer.Types.LAMP then
        return Constants.POWER_DRAW_LAMP or 1
    elseif data.objectType == LKS_EletricidadeConstrucao.Data.Consumer.Types.APPLIANCE then
        -- Use appliance-specific power draw if available
        if data.applianceType then
            if data.applianceType == "fridge" then
                return Constants.POWER_DRAW_FRIDGE or 10
            elseif data.applianceType == "freezer" then
                return Constants.POWER_DRAW_FREEZER or 10
            elseif data.applianceType == "fridgeFreezer" then
                return Constants.POWER_DRAW_FRIDGE_FREEZER or 15
            elseif data.applianceType == "stove" then
                return Constants.POWER_DRAW_STOVE or 6
            elseif data.applianceType == "microwave" then
                return Constants.POWER_DRAW_MICROWAVE or 5
            elseif data.applianceType == "washer" then
                return Constants.POWER_DRAW_WASHER or 7
            elseif data.applianceType == "dryer" then
                return Constants.POWER_DRAW_DRYER or 7
            elseif data.applianceType == "tv" then
                return Constants.POWER_DRAW_TV or 3
            elseif data.applianceType == "radio" then
                return Constants.POWER_DRAW_RADIO or 2
            end
        end
        -- Default appliance power draw
        return Constants.POWER_DRAW_APPLIANCE or 2
    else
        return 1 -- Default
    end
end

-- ============================================================================
-- STATE OPERATIONS
-- ============================================================================

--- Set consumer active state
--- @param data ConsumerData Consumer data
--- @param active boolean Active state
function LKS_EletricidadeConstrucao.Data.Consumer.SetActive(data, active)
    data.isActive = active
end

--- Toggle consumer active state
--- @param data ConsumerData Consumer data
function LKS_EletricidadeConstrucao.Data.Consumer.Toggle(data)
    data.isActive = not data.isActive
end

-- ============================================================================
-- TYPE DETECTION
-- ============================================================================

--- Detect consumer type from grid square
--- @param square IsoGridSquare Grid square to analyze
--- @return string Consumer type
function LKS_EletricidadeConstrucao.Data.Consumer.DetectType(square)
    if not square then
        return LKS_EletricidadeConstrucao.Data.Consumer.Types.UNKNOWN
    end
    
    -- Check for lamp objects
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj then
                local sprite = obj:getSprite()
                if sprite then
                    local spriteName = sprite:getName()
                    if spriteName and spriteName:contains("lamp") then
                        return LKS_EletricidadeConstrucao.Data.Consumer.Types.LAMP
                    end
                end
            end
        end
    end
    
    -- Check if square can have lights
    if square:canHaveLight() then
        return LKS_EletricidadeConstrucao.Data.Consumer.Types.LIGHT
    end
    
    -- Check for appliances (stove, fridge, etc.)
    -- This would require more sophisticated detection
    -- For now, default to light
    return LKS_EletricidadeConstrucao.Data.Consumer.Types.LIGHT
end

-- ============================================================================
-- COMPARISON
-- ============================================================================

--- Check if two consumers are the same
--- @param consumer1 ConsumerData First consumer
--- @param consumer2 ConsumerData Second consumer
--- @return boolean True if same position
function LKS_EletricidadeConstrucao.Data.Consumer.IsSame(consumer1, consumer2)
    return consumer1.squareX == consumer2.squareX
        and consumer1.squareY == consumer2.squareY
        and consumer1.squareZ == consumer2.squareZ
        and consumer1.objectIndex == consumer2.objectIndex
end

--- Generate unique key for consumer
--- @param data ConsumerData Consumer data
--- @return string Unique key
function LKS_EletricidadeConstrucao.Data.Consumer.MakeKey(data)
    if data.objectIndex then
        return string.format("%d_%d_%d_%d", 
            data.squareX, data.squareY, data.squareZ, data.objectIndex)
    else
        return string.format("%d_%d_%d", 
            data.squareX, data.squareY, data.squareZ)
    end
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Get grid square for consumer
--- @param data ConsumerData Consumer data
--- @return IsoGridSquare|nil Grid square or nil if not found
function LKS_EletricidadeConstrucao.Data.Consumer.GetSquare(data)
    local square = getSquare(data.squareX, data.squareY, data.squareZ)
    return square
end

--- Check if consumer is valid (grid square exists)
--- @param data ConsumerData Consumer data
--- @return boolean True if valid
function LKS_EletricidadeConstrucao.Data.Consumer.IsValid(data)
    local square = LKS_EletricidadeConstrucao.Data.Consumer.GetSquare(data)
    return square ~= nil
end

--- Get current power contribution
--- @param data ConsumerData Consumer data
--- @return number Power contribution (0 if inactive)
function LKS_EletricidadeConstrucao.Data.Consumer.GetCurrentPower(data)
    if data.isActive then
        return data.powerDraw
    else
        return 0
    end
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Convert consumer data to string for debugging
--- @param data ConsumerData Consumer data
--- @return string String representation
function LKS_EletricidadeConstrucao.Data.Consumer.ToString(data)
    local indexStr = data.objectIndex and string.format("[%d]", data.objectIndex) or ""
    
    return string.format(
        "Consumer%s at (%d,%d,%d) | Type:%s Active:%s Power:%.1f",
        indexStr,
        data.squareX, data.squareY, data.squareZ,
        data.objectType,
        tostring(data.isActive),
        data.powerDraw
    )
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Data.Consumer", "2.0.0")

return LKS_EletricidadeConstrucao.Data.Consumer
