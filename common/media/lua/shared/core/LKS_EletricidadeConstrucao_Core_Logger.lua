-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Core_Logger.lua
-- LKS_EletricidadeConstrucao V2 - Logging System
-- Categorized logging with debug levels and performance optimization
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Core_Logger] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- LOG LEVELS
-- ============================================================================

LKS_EletricidadeConstrucao.Core.Logger.Levels = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4,
    TRACE = 5
}

-- ============================================================================
-- LOG CATEGORIES
-- ============================================================================

LKS_EletricidadeConstrucao.Core.Logger.Categories = {
    CORE = "Core",
    FUEL = "Fuel",
    POWER = "Power",
    BUILDING = "Building",
    NETWORK = "Network",
    UI = "UI",
    HEATING = "Heating",
    API = "API",
    EVENT = "Event",
    PERFORMANCE = "Performance"
}

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local _globalLevel = LKS_EletricidadeConstrucao.Core.Logger.Levels.INFO
local _categoryLevels = {}  -- Category-specific log levels
local _enabledCategories = {}  -- Which categories are enabled
local _logToFile = false  -- Whether to log to file (future feature)
local _showTimestamp = true  -- Show timestamp in logs
local _showCategory = true  -- Show category in logs

-- Initialize all categories as enabled
for _, category in pairs(LKS_EletricidadeConstrucao.Core.Logger.Categories) do
    _enabledCategories[category] = true
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

--- Set global log level
--- @param level number Log level (1-5)
function LKS_EletricidadeConstrucao.Core.Logger.SetLevel(level)
    _globalLevel = level
end

--- Get global log level
--- @return number Current log level
function LKS_EletricidadeConstrucao.Core.Logger.GetLevel()
    return _globalLevel
end

--- Set log level for specific category
--- @param category string Category name
--- @param level number Log level
function LKS_EletricidadeConstrucao.Core.Logger.SetCategoryLevel(category, level)
    _categoryLevels[category] = level
end

--- Enable category
--- @param category string Category name
function LKS_EletricidadeConstrucao.Core.Logger.EnableCategory(category)
    _enabledCategories[category] = true
end

--- Disable category
--- @param category string Category name
function LKS_EletricidadeConstrucao.Core.Logger.DisableCategory(category)
    _enabledCategories[category] = false
end

--- Check if category is enabled
--- @param category string Category name
--- @return boolean True if enabled
function LKS_EletricidadeConstrucao.Core.Logger.IsCategoryEnabled(category)
    return _enabledCategories[category] == true
end

--- Enable timestamp display
--- @param enabled boolean Enable state
function LKS_EletricidadeConstrucao.Core.Logger.SetShowTimestamp(enabled)
    _showTimestamp = enabled
end

--- Enable category display
--- @param enabled boolean Enable state
function LKS_EletricidadeConstrucao.Core.Logger.SetShowCategory(enabled)
    _showCategory = enabled
end

-- ============================================================================
-- LEVEL CHECKING
-- ============================================================================

--- Check if message should be logged
--- @param level number Message log level
--- @param category string|nil Category name
--- @return boolean True if should log
local function ShouldLog(level, category)
    -- Check category enabled
    if category and not LKS_EletricidadeConstrucao.Core.Logger.IsCategoryEnabled(category) then
        return false
    end
    
    -- Get effective level (category-specific or global)
    local effectiveLevel = _globalLevel
    if category and _categoryLevels[category] then
        effectiveLevel = _categoryLevels[category]
    end
    
    return level <= effectiveLevel
end

-- ============================================================================
-- FORMATTING
-- ============================================================================

--- Format log message
--- @param level string Level name
--- @param category string|nil Category name
--- @param message string Message
--- @return string Formatted message
local function FormatMessage(level, category, message)
    local parts = {}
    
    -- Add timestamp (safe: getGameTime may be nil during load phase)
    if _showTimestamp then
        local ok, gameTime = pcall(getGameTime)
        if ok and gameTime then
            local hour = gameTime:getHour()
            local minute = gameTime:getMinutes()
            table.insert(parts, string.format("[%02d:%02d]", hour, minute))
        end
    end
    
    -- Add mod prefix
    table.insert(parts, "[LKS_EletricidadeConstrucao]")
    
    -- Add level
    table.insert(parts, "[" .. level .. "]")
    
    -- Add category
    if _showCategory and category then
        table.insert(parts, "[" .. category .. "]")
    end
    
    -- Add message
    table.insert(parts, message)
    
    return table.concat(parts, " ")
end

-- ============================================================================
-- CORE LOGGING FUNCTIONS
-- ============================================================================

--- Log error message
--- @param message string Message to log
--- @param category string|nil Category
function LKS_EletricidadeConstrucao.Core.Logger.Error(message, category)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.ERROR, category) then
        return
    end
    
    local formatted = FormatMessage("ERROR", category, message)
    print(formatted)
    
    -- Also log to game console
    if isClient() then
        -- Avoid using DebugLog as it may not be available
        print(formatted)
    end
end

--- Log warning message
--- @param message string Message to log
--- @param category string|nil Category
function LKS_EletricidadeConstrucao.Core.Logger.Warn(message, category)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.WARN, category) then
        return
    end
    
    local formatted = FormatMessage("WARN", category, message)
    print(formatted)
end

--- Log info message
--- @param message string Message to log
--- @param category string|nil Category
function LKS_EletricidadeConstrucao.Core.Logger.Info(message, category)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.INFO, category) then
        return
    end
    
    local formatted = FormatMessage("INFO", category, message)
    print(formatted)
end

--- Log debug message
--- @param message string Message to log
--- @param category string|nil Category
function LKS_EletricidadeConstrucao.Core.Logger.Debug(message, category)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.DEBUG, category) then
        return
    end
    
    local formatted = FormatMessage("DEBUG", category, message)
    print(formatted)
end

--- Log trace message (very detailed)
--- @param message string Message to log
--- @param category string|nil Category
function LKS_EletricidadeConstrucao.Core.Logger.Trace(message, category)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.TRACE, category) then
        return
    end
    
    local formatted = FormatMessage("TRACE", category, message)
    print(formatted)
end

-- ============================================================================
-- CATEGORY-SPECIFIC SHORTCUTS
-- ============================================================================

--- Log fuel-related message
--- @param level number Log level
--- @param message string Message
function LKS_EletricidadeConstrucao.Core.Logger.LogFuel(level, message)
    local Levels = LKS_EletricidadeConstrucao.Core.Logger.Levels
    local category = LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL
    
    if level == Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(message, category)
    elseif level == Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(message, category)
    elseif level == Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(message, category)
    elseif level == Levels.DEBUG then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(message, category)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(message, category)
    end
end

--- Log power-related message
--- @param level number Log level
--- @param message string Message
function LKS_EletricidadeConstrucao.Core.Logger.LogPower(level, message)
    local Levels = LKS_EletricidadeConstrucao.Core.Logger.Levels
    local category = LKS_EletricidadeConstrucao.Core.Logger.Categories.POWER
    
    if level == Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(message, category)
    elseif level == Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(message, category)
    elseif level == Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(message, category)
    elseif level == Levels.DEBUG then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(message, category)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(message, category)
    end
end

--- Log building-related message
--- @param level number Log level
--- @param message string Message
function LKS_EletricidadeConstrucao.Core.Logger.LogBuilding(level, message)
    local Levels = LKS_EletricidadeConstrucao.Core.Logger.Levels
    local category = LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING
    
    if level == Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(message, category)
    elseif level == Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(message, category)
    elseif level == Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(message, category)
    elseif level == Levels.DEBUG then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(message, category)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(message, category)
    end
end

--- Log network-related message
--- @param level number Log level
--- @param message string Message
function LKS_EletricidadeConstrucao.Core.Logger.LogNetwork(level, message)
    local Levels = LKS_EletricidadeConstrucao.Core.Logger.Levels
    local category = LKS_EletricidadeConstrucao.Core.Logger.Categories.NETWORK
    
    if level == Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(message, category)
    elseif level == Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(message, category)
    elseif level == Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(message, category)
    elseif level == Levels.DEBUG then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(message, category)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(message, category)
    end
end

--- Log UI-related message
--- @param level number Log level
--- @param message string Message
function LKS_EletricidadeConstrucao.Core.Logger.LogUI(level, message)
    local Levels = LKS_EletricidadeConstrucao.Core.Logger.Levels
    local category = LKS_EletricidadeConstrucao.Core.Logger.Categories.UI
    
    if level == Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(message, category)
    elseif level == Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(message, category)
    elseif level == Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(message, category)
    elseif level == Levels.DEBUG then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(message, category)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(message, category)
    end
end

-- ============================================================================
-- PERFORMANCE LOGGING
-- ============================================================================

local _performanceTimers = {}

--- Start performance timer
--- @param name string Timer name
function LKS_EletricidadeConstrucao.Core.Logger.StartTimer(name)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.DEBUG, LKS_EletricidadeConstrucao.Core.Logger.Categories.PERFORMANCE) then
        return
    end
    
    _performanceTimers[name] = getTimestampMs()
end

--- End performance timer and log
--- @param name string Timer name
--- @param threshold number|nil Warning threshold in ms (optional)
function LKS_EletricidadeConstrucao.Core.Logger.EndTimer(name, threshold)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.DEBUG, LKS_EletricidadeConstrucao.Core.Logger.Categories.PERFORMANCE) then
        return
    end
    
    local startTime = _performanceTimers[name]
    if not startTime then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("Timer '" .. name .. "' was not started", LKS_EletricidadeConstrucao.Core.Logger.Categories.PERFORMANCE)
        return
    end
    
    local elapsed = getTimestampMs() - startTime
    _performanceTimers[name] = nil
    
    local message = string.format("%s took %.2f ms", name, elapsed)
    
    -- Check threshold
    if threshold and elapsed > threshold then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(message .. " (exceeded threshold: " .. threshold .. " ms)", LKS_EletricidadeConstrucao.Core.Logger.Categories.PERFORMANCE)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Debug(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.PERFORMANCE)
    end
end

-- ============================================================================
-- OBJECT LOGGING
-- ============================================================================

--- Log generator data
--- @param generatorData GeneratorData Generator to log
--- @param level number|nil Log level (default: DEBUG)
function LKS_EletricidadeConstrucao.Core.Logger.LogGenerator(generatorData, level)
    level = level or LKS_EletricidadeConstrucao.Core.Logger.Levels.DEBUG
    
    if not ShouldLog(level, LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL) then
        return
    end
    
    local message = LKS_EletricidadeConstrucao.Data.Generator.ToString(generatorData)
    
    if level == LKS_EletricidadeConstrucao.Core.Logger.Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL)
    elseif level == LKS_EletricidadeConstrucao.Core.Logger.Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL)
    elseif level == LKS_EletricidadeConstrucao.Core.Logger.Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Debug(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL)
    end
end

--- Log building data
--- @param buildingData BuildingData Building to log
--- @param level number|nil Log level (default: DEBUG)
function LKS_EletricidadeConstrucao.Core.Logger.LogBuilding(buildingData, level)
    level = level or LKS_EletricidadeConstrucao.Core.Logger.Levels.DEBUG
    
    if not ShouldLog(level, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING) then
        return
    end
    
    local message = LKS_EletricidadeConstrucao.Data.Building.ToString(buildingData)
    
    if level == LKS_EletricidadeConstrucao.Core.Logger.Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    elseif level == LKS_EletricidadeConstrucao.Core.Logger.Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    elseif level == LKS_EletricidadeConstrucao.Core.Logger.Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Debug(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    end
end

--- Log consumer data
--- @param consumerData ConsumerData Consumer to log
--- @param level number|nil Log level (default: TRACE)
function LKS_EletricidadeConstrucao.Core.Logger.LogConsumer(consumerData, level)
    level = level or LKS_EletricidadeConstrucao.Core.Logger.Levels.TRACE
    
    if not ShouldLog(level, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING) then
        return
    end
    
    local message = LKS_EletricidadeConstrucao.Data.Consumer.ToString(consumerData)
    
    if level == LKS_EletricidadeConstrucao.Core.Logger.Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    elseif level == LKS_EletricidadeConstrucao.Core.Logger.Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    elseif level == LKS_EletricidadeConstrucao.Core.Logger.Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(message, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    end
end

-- ============================================================================
-- DEBUG UTILITIES
-- ============================================================================

--- Print logger configuration
function LKS_EletricidadeConstrucao.Core.Logger.PrintConfig()
    LKS_EletricidadeConstrucao.Print("=== Logger Configuration ===")
    LKS_EletricidadeConstrucao.Print("Global Level: " .. _globalLevel)
    LKS_EletricidadeConstrucao.Print("Show Timestamp: " .. tostring(_showTimestamp))
    LKS_EletricidadeConstrucao.Print("Show Category: " .. tostring(_showCategory))
    
    LKS_EletricidadeConstrucao.Print("Enabled Categories:")
    for category, enabled in pairs(_enabledCategories) do
        local level = _categoryLevels[category] or "default"
        LKS_EletricidadeConstrucao.Print("  " .. category .. ": " .. tostring(enabled) .. " (level: " .. tostring(level) .. ")")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Core.Logger", "2.0.0")

return LKS_EletricidadeConstrucao.Core.Logger
