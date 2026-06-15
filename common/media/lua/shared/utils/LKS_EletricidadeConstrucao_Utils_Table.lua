-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Utils_Table.lua
-- LKS_EletricidadeConstrucao V2 - Table Utility Functions
-- Deep copy, merge, count, search, etc.
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Utils_Table] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- COPYING
-- ============================================================================

--- Shallow copy table (1 level deep)
--- @param tbl table Table to copy
--- @return table Shallow copy
function LKS_EletricidadeConstrucao.Utils.Table.ShallowCopy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    
    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = value
    end
    return copy
end

--- Deep copy table (recursive)
--- @param tbl table Table to copy
--- @param seen table Internal - tracks circular references
--- @return table Deep copy
function LKS_EletricidadeConstrucao.Utils.Table.DeepCopy(tbl, seen)
    if type(tbl) ~= "table" then
        return tbl
    end
    
    -- Avoid infinite recursion on circular references
    seen = seen or {}
    if seen[tbl] then
        return seen[tbl]
    end
    
    local copy = {}
    seen[tbl] = copy
    
    for key, value in pairs(tbl) do
        copy[LKS_EletricidadeConstrucao.Utils.Table.DeepCopy(key, seen)] = 
            LKS_EletricidadeConstrucao.Utils.Table.DeepCopy(value, seen)
    end
    
    return copy
end

-- ============================================================================
-- MERGING
-- ============================================================================

--- Merge two tables (shallow, dest modified in place)
--- @param dest table Destination table
--- @param src table Source table
--- @return table Modified destination table
function LKS_EletricidadeConstrucao.Utils.Table.Merge(dest, src)
    for key, value in pairs(src) do
        dest[key] = value
    end
    return dest
end

--- Deep merge two tables (recursive)
--- @param dest table Destination table
--- @param src table Source table
--- @return table Modified destination table
function LKS_EletricidadeConstrucao.Utils.Table.DeepMerge(dest, src)
    for key, value in pairs(src) do
        if type(value) == "table" and type(dest[key]) == "table" then
            LKS_EletricidadeConstrucao.Utils.Table.DeepMerge(dest[key], value)
        else
            dest[key] = value
        end
    end
    return dest
end

-- ============================================================================
-- COUNTING & CHECKING
-- ============================================================================

--- Count elements in table (works for both arrays and dictionaries)
--- @param tbl table Table to count
--- @return number Number of elements
function LKS_EletricidadeConstrucao.Utils.Table.Count(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

--- Check if table is empty
--- @param tbl table Table to check
--- @return boolean True if empty
function LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(tbl)
    -- next() is not available in Kahlua; use pairs-loop instead
    for _ in pairs(tbl) do return false end
    return true
end

--- Check if table contains value
--- @param tbl table Table to search
--- @param value any Value to find
--- @return boolean True if found
function LKS_EletricidadeConstrucao.Utils.Table.Contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

--- Find index of value in array
--- @param tbl table Array to search
--- @param value any Value to find
--- @return number Index or nil if not found
function LKS_EletricidadeConstrucao.Utils.Table.IndexOf(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

-- ============================================================================
-- FILTERING & MAPPING
-- ============================================================================

--- Filter table elements by predicate function
--- @param tbl table Table to filter
--- @param predicate function Function(value, key) returns true to keep
--- @return table Filtered table
function LKS_EletricidadeConstrucao.Utils.Table.Filter(tbl, predicate)
    local result = {}
    for key, value in pairs(tbl) do
        if predicate(value, key) then
            result[key] = value
        end
    end
    return result
end

--- Map table elements through transform function
--- @param tbl table Table to map
--- @param transform function Function(value, key) returns new value
--- @return table Transformed table
function LKS_EletricidadeConstrucao.Utils.Table.Map(tbl, transform)
    local result = {}
    for key, value in pairs(tbl) do
        result[key] = transform(value, key)
    end
    return result
end

--- Find first element matching predicate
--- @param tbl table Table to search
--- @param predicate function Function(value, key) returns true for match
--- @return any, any Value and key of first match, or nil
function LKS_EletricidadeConstrucao.Utils.Table.Find(tbl, predicate)
    for key, value in pairs(tbl) do
        if predicate(value, key) then
            return value, key
        end
    end
    return nil, nil
end

-- ============================================================================
-- KEYS & VALUES
-- ============================================================================

--- Get all keys from table
--- @param tbl table Table to extract keys from
--- @return table Array of keys
function LKS_EletricidadeConstrucao.Utils.Table.Keys(tbl)
    local keys = {}
    for key, _ in pairs(tbl) do
        table.insert(keys, key)
    end
    return keys
end

--- Get all values from table
--- @param tbl table Table to extract values from
--- @return table Array of values
function LKS_EletricidadeConstrucao.Utils.Table.Values(tbl)
    local values = {}
    for _, value in pairs(tbl) do
        table.insert(values, value)
    end
    return values
end

--- Convert table to string (for debugging, shallow)
--- @param tbl table Table to convert
--- @param maxDepth number Max recursion depth (default 3)
--- @param currentDepth number Internal recursion tracker
--- @return string String representation
function LKS_EletricidadeConstrucao.Utils.Table.ToString(tbl, maxDepth, currentDepth)
    maxDepth = maxDepth or 3
    currentDepth = currentDepth or 0
    
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    
    if currentDepth >= maxDepth then
        return "{...}"
    end
    
    local parts = {}
    for key, value in pairs(tbl) do
        local keyStr = tostring(key)
        local valueStr
        
        if type(value) == "table" then
            valueStr = LKS_EletricidadeConstrucao.Utils.Table.ToString(value, maxDepth, currentDepth + 1)
        else
            valueStr = tostring(value)
        end
        
        table.insert(parts, keyStr .. " = " .. valueStr)
    end
    
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Utils.Table", "2.0.0")

return LKS_EletricidadeConstrucao.Utils.Table
