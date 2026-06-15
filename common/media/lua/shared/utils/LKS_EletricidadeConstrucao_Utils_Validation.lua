-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Utils_Validation.lua
-- LKS_EletricidadeConstrucao V2 - Input Validation Utilities
-- Type checking, nil checking, range validation, etc.
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Utils_Validation] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- NIL CHECKING
-- ============================================================================

--- Check if value is nil
--- @param value any Value to check
--- @return boolean True if nil
function LKS_EletricidadeConstrucao.Utils.Validation.IsNil(value)
    return value == nil
end

--- Check if value is not nil
--- @param value any Value to check
--- @return boolean True if not nil
function LKS_EletricidadeConstrucao.Utils.Validation.IsNotNil(value)
    return value ~= nil
end

--- Get value or default if nil
--- @param value any Value to check
--- @param default any Default value if nil
--- @return any Value or default
function LKS_EletricidadeConstrucao.Utils.Validation.OrDefault(value, default)
    if value == nil then
        return default
    end
    return value
end

-- ============================================================================
-- TYPE CHECKING
-- ============================================================================

--- Check if value is a number
--- @param value any Value to check
--- @return boolean True if number
function LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(value)
    return type(value) == "number"
end

--- Check if value is a string
--- @param value any Value to check
--- @return boolean True if string
function LKS_EletricidadeConstrucao.Utils.Validation.IsString(value)
    return type(value) == "string"
end

--- Check if value is a boolean
--- @param value any Value to check
--- @return boolean True if boolean
function LKS_EletricidadeConstrucao.Utils.Validation.IsBoolean(value)
    return type(value) == "boolean"
end

--- Check if value is a table
--- @param value any Value to check
--- @return boolean True if table
function LKS_EletricidadeConstrucao.Utils.Validation.IsTable(value)
    return type(value) == "table"
end

--- Check if value is a function
--- @param value any Value to check
--- @return boolean True if function
function LKS_EletricidadeConstrucao.Utils.Validation.IsFunction(value)
    return type(value) == "function"
end

--- Get type name of value
--- @param value any Value to check
--- @return string Type name
function LKS_EletricidadeConstrucao.Utils.Validation.GetType(value)
    return type(value)
end

-- ============================================================================
-- RANGE VALIDATION
-- ============================================================================

--- Validate number is within range
--- @param value number Value to validate
--- @param min number Minimum value
--- @param max number Maximum value
--- @param varName string Variable name for error message
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateRange(value, min, max, varName)
    varName = varName or "value"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(value) then
        return false, varName .. " must be a number"
    end
    
    if value < min or value > max then
        return false, string.format("%s must be between %s and %s (got %s)", 
            varName, tostring(min), tostring(max), tostring(value))
    end
    
    return true, nil
end

--- Validate number is positive
--- @param value number Value to validate
--- @param varName string Variable name for error message
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Utils.Validation.ValidatePositive(value, varName)
    varName = varName or "value"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(value) then
        return false, varName .. " must be a number"
    end
    
    if value <= 0 then
        return false, varName .. " must be positive (got " .. tostring(value) .. ")"
    end
    
    return true, nil
end

--- Validate number is non-negative
--- @param value number Value to validate
--- @param varName string Variable name for error message
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateNonNegative(value, varName)
    varName = varName or "value"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(value) then
        return false, varName .. " must be a number"
    end
    
    if value < 0 then
        return false, varName .. " must be non-negative (got " .. tostring(value) .. ")"
    end
    
    return true, nil
end

-- ============================================================================
-- STRING VALIDATION
-- ============================================================================

--- Check if string is empty or whitespace
--- @param str string String to check
--- @return boolean True if empty/whitespace
function LKS_EletricidadeConstrucao.Utils.Validation.IsEmptyString(str)
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsString(str) then
        return true
    end
    return str == "" or str:match("^%s*$") ~= nil
end

--- Validate string is not empty
--- @param str string String to validate
--- @param varName string Variable name for error message
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateNotEmpty(str, varName)
    varName = varName or "string"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsString(str) then
        return false, varName .. " must be a string"
    end
    
    if LKS_EletricidadeConstrucao.Utils.Validation.IsEmptyString(str) then
        return false, varName .. " cannot be empty"
    end
    
    return true, nil
end

--- Validate string length
--- @param str string String to validate
--- @param minLen number Minimum length
--- @param maxLen number Maximum length
--- @param varName string Variable name for error message
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateLength(str, minLen, maxLen, varName)
    varName = varName or "string"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsString(str) then
        return false, varName .. " must be a string"
    end
    
    local len = string.len(str)
    
    if len < minLen or len > maxLen then
        return false, string.format("%s length must be between %d and %d (got %d)",
            varName, minLen, maxLen, len)
    end
    
    return true, nil
end

-- ============================================================================
-- TABLE VALIDATION
-- ============================================================================

--- Validate table is not empty
--- @param tbl table Table to validate
--- @param varName string Variable name for error message
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateNotEmptyTable(tbl, varName)
    varName = varName or "table"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsTable(tbl) then
        return false, varName .. " must be a table"
    end
    
    if LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(tbl) then
        return false, varName .. " cannot be empty"
    end
    
    return true, nil
end

--- Validate table has required keys
--- @param tbl table Table to validate
--- @param requiredKeys table Array of required key names
--- @param varName string Variable name for error message
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateKeys(tbl, requiredKeys, varName)
    varName = varName or "table"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsTable(tbl) then
        return false, varName .. " must be a table"
    end
    
    for _, key in ipairs(requiredKeys) do
        if tbl[key] == nil then
            return false, varName .. " missing required key: " .. tostring(key)
        end
    end
    
    return true, nil
end

-- ============================================================================
-- COORDINATE VALIDATION
-- ============================================================================

--- Validate coordinates are valid numbers
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate (optional)
--- @return boolean, string True if valid, or false with error message
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateCoordinates(x, y, z)
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(x) then
        return false, "X coordinate must be a number"
    end
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(y) then
        return false, "Y coordinate must be a number"
    end
    
    if z ~= nil and not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(z) then
        return false, "Z coordinate must be a number"
    end
    
    -- Use geometry utils for range validation
    if not LKS_EletricidadeConstrucao.Utils.Geometry.IsValidCoordinate(x, y, z) then
        return false, "Coordinates out of valid range"
    end
    
    return true, nil
end

-- ============================================================================
-- OBJECT VALIDATION (PZ Objects)
-- ============================================================================

--- Validate object is IsoGenerator
--- @param obj any Object to validate
--- @return boolean True if valid IsoGenerator
function LKS_EletricidadeConstrucao.Utils.Validation.IsGenerator(obj)
    if not obj then return false end
    return instanceof(obj, "IsoGenerator")
end

--- Validate object is IsoLightSwitch
--- @param obj any Object to validate
--- @return boolean True if valid IsoLightSwitch
function LKS_EletricidadeConstrucao.Utils.Validation.IsLightSwitch(obj)
    if not obj then return false end
    return instanceof(obj, "IsoLightSwitch")
end

--- Validate object is IsoGridSquare
--- @param obj any Object to validate
--- @return boolean True if valid IsoGridSquare
function LKS_EletricidadeConstrucao.Utils.Validation.IsGridSquare(obj)
    if not obj then return false end
    return instanceof(obj, "IsoGridSquare")
end

--- Validate object is IsoObject
--- @param obj any Object to validate
--- @return boolean True if valid IsoObject
function LKS_EletricidadeConstrucao.Utils.Validation.IsIsoObject(obj)
    if not obj then return false end
    return instanceof(obj, "IsoObject")
end

-- ============================================================================
-- ASSERTION HELPERS
-- ============================================================================

--- Assert value is not nil, error otherwise
--- @param value any Value to check
--- @param message string Error message
function LKS_EletricidadeConstrucao.Utils.Validation.AssertNotNil(value, message)
    if value == nil then
        error(message or "Value cannot be nil")
    end
end

--- Assert condition is true, error otherwise
--- @param condition boolean Condition to check
--- @param message string Error message
function LKS_EletricidadeConstrucao.Utils.Validation.Assert(condition, message)
    if not condition then
        error(message or "Assertion failed")
    end
end

--- Assert value is expected type, error otherwise
--- @param value any Value to check
--- @param expectedType string Expected type name
--- @param varName string Variable name for error message
function LKS_EletricidadeConstrucao.Utils.Validation.AssertType(value, expectedType, varName)
    local actualType = type(value)
    if actualType ~= expectedType then
        error(string.format("%s must be %s (got %s)", 
            varName or "value", expectedType, actualType))
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Utils.Validation", "2.0.0")

return LKS_EletricidadeConstrucao.Utils.Validation
