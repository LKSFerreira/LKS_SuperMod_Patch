-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Core_EventManager.lua
-- LKS_EletricidadeConstrucao V2 - Event Manager
-- Custom event system for mod communication
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Core_EventManager] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- EVENT REGISTRY
-- ============================================================================

local _eventHandlers = {}  -- event name -> array of handler functions
local _eventStats = {}  -- event name -> { fired: number, handlers: number }

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Initialize event statistics
--- @param eventName string Event name
local function InitEventStats(eventName)
    if not _eventStats[eventName] then
        _eventStats[eventName] = {
            fired = 0,
            handlers = 0
        }
    end
end

-- ============================================================================
-- EVENT REGISTRATION
-- ============================================================================

--- Register event handler
--- @param eventName string Event name
--- @param handler function Handler function
--- @param priority number|nil Priority (higher = earlier, default: 0)
--- @return boolean True if registered successfully
function LKS_EletricidadeConstrucao.Core.EventManager.RegisterHandler(eventName, handler, priority)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Validate inputs
    if Validation.IsEmptyString(eventName) then
        LKS_EletricidadeConstrucao.Core.Logger.Error("Event name cannot be empty", "Event")
        return false
    end
    
    if not Validation.IsFunction(handler) then
        LKS_EletricidadeConstrucao.Core.Logger.Error("Handler must be a function", "Event")
        return false
    end
    
    -- Initialize handler array
    if not _eventHandlers[eventName] then
        _eventHandlers[eventName] = {}
    end
    
    -- Create handler entry
    local entry = {
        handler = handler,
        priority = priority or 0
    }
    
    -- Insert handler
    table.insert(_eventHandlers[eventName], entry)
    
    -- Sort by priority (highest first)
    table.sort(_eventHandlers[eventName], function(a, b)
        return a.priority > b.priority
    end)
    
    -- Update stats
    InitEventStats(eventName)
    _eventStats[eventName].handlers = #_eventHandlers[eventName]
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug("Registered handler for event: " .. eventName, "Event")
    
    return true
end

--- Unregister event handler
--- @param eventName string Event name
--- @param handler function Handler function to remove
--- @return boolean True if unregistered successfully
function LKS_EletricidadeConstrucao.Core.EventManager.UnregisterHandler(eventName, handler)
    if not _eventHandlers[eventName] then
        return false
    end
    
    -- Find and remove handler
    for i = #_eventHandlers[eventName], 1, -1 do
        if _eventHandlers[eventName][i].handler == handler then
            table.remove(_eventHandlers[eventName], i)
            
            -- Update stats
            if _eventStats[eventName] then
                _eventStats[eventName].handlers = #_eventHandlers[eventName]
            end
            
            LKS_EletricidadeConstrucao.Core.Logger.Debug("Unregistered handler for event: " .. eventName, "Event")
            return true
        end
    end
    
    return false
end

--- Clear all handlers for event
--- @param eventName string Event name
function LKS_EletricidadeConstrucao.Core.EventManager.ClearHandlers(eventName)
    _eventHandlers[eventName] = nil
    
    if _eventStats[eventName] then
        _eventStats[eventName].handlers = 0
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug("Cleared all handlers for event: " .. eventName, "Event")
end

-- ============================================================================
-- EVENT TRIGGERING
-- ============================================================================

--- Trigger event
--- @param eventName string Event name
--- @param ... any Event arguments
--- @return number Number of handlers executed
function LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(eventName, ...)
    -- Check if there are handlers
    if not _eventHandlers[eventName] or #_eventHandlers[eventName] == 0 then
        return 0
    end
    
    -- Update stats
    InitEventStats(eventName)
    _eventStats[eventName].fired = _eventStats[eventName].fired + 1
    
    -- Execute handlers
    local count = 0
    local args = {...}
    
    LKS_EletricidadeConstrucao.Core.Logger.Trace("Triggering event: " .. eventName .. " with " .. #_eventHandlers[eventName] .. " handlers", "Event")
    
    for _, entry in ipairs(_eventHandlers[eventName]) do
        -- Call handler with error protection
        local success, err = pcall(entry.handler, unpack(args))
        
        if not success then
            LKS_EletricidadeConstrucao.Core.Logger.Error("Error in event handler for " .. eventName .. ": " .. tostring(err), "Event")
        else
            count = count + 1
        end
    end
    
    return count
end

--- Register a vanilla game event handler
--- Returns true on success, false if the event does not exist in this Lua state
--- @param eventName string Vanilla event name
--- @param handler function Handler function
function LKS_EletricidadeConstrucao.Core.EventManager.RegisterGameEvent(eventName, handler)
    if not Events[eventName] then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("RegisterGameEvent: event '" .. tostring(eventName) .. "' does not exist in this Lua state - skipping", "Event")
        return false
    end
    Events[eventName].Add(handler)
    LKS_EletricidadeConstrucao.Core.Logger.Debug("Registered handler for game event: " .. eventName, "Event")
    return true
end

--- Unregister a vanilla game event handler
--- @param eventName string Vanilla event name
--- @param handler function Handler function
function LKS_EletricidadeConstrucao.Core.EventManager.UnregisterGameEvent(eventName, handler)
    if not Events[eventName] then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("UnregisterGameEvent: event '" .. tostring(eventName) .. "' does not exist - skipping", "Event")
        return false
    end
    Events[eventName].Remove(handler)
    LKS_EletricidadeConstrucao.Core.Logger.Debug("Unregistered handler for game event: " .. eventName, "Event")
    return true
end

-- ============================================================================
-- CUSTOM EVENT DEFINITIONS
-- ============================================================================

--- Initialize all custom events
function LKS_EletricidadeConstrucao.Core.EventManager.InitializeCustomEvents()
    -- Safe check for dependencies
    if not LKS_EletricidadeConstrucao or not LKS_EletricidadeConstrucao.Constants or not LKS_EletricidadeConstrucao.Core or not LKS_EletricidadeConstrucao.Core.Logger then
        print("[LKS_EletricidadeConstrucao_Core_EventManager] InitializeCustomEvents: Missing dependencies, skipping initialization")
        return
    end
    
    local Constants = LKS_EletricidadeConstrucao.Constants
    
    -- Initialize event statistics for all custom events
    if Constants.EVENTS then
        for _, eventName in pairs(Constants.EVENTS) do
            InitEventStats(eventName)
        end
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Initialized custom events", "Event")
end

-- ============================================================================
-- GENERATOR EVENTS
-- ============================================================================

--- Trigger generator connected event
--- @param generatorData GeneratorData Generator that was connected
--- @param buildingData BuildingData Building that was connected
function LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorConnected(generatorData, buildingData)
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.GENERATOR_CONNECTED, generatorData, buildingData)
end

--- Trigger generator disconnected event
--- @param generatorData GeneratorData Generator that was disconnected
--- @param buildingData BuildingData Building that was disconnected
function LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorDisconnected(generatorData, buildingData)
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.GENERATOR_DISCONNECTED, generatorData, buildingData)
end

--- Trigger generator activated event
--- @param generatorData GeneratorData Generator that was activated
function LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorActivated(generatorData)
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.GENERATOR_ACTIVATED, generatorData)
end

--- Trigger generator deactivated event
--- @param generatorData GeneratorData Generator that was deactivated
function LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorDeactivated(generatorData)
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.GENERATOR_DEACTIVATED, generatorData)
end

--- Trigger generator fuel empty event
--- @param generatorData GeneratorData Generator that ran out of fuel
function LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorFuelEmpty(generatorData)
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.GENERATOR_FUEL_EMPTY, generatorData)
end

-- ============================================================================
-- BUILDING EVENTS
-- ============================================================================

--- Trigger building power changed event
--- @param buildingData BuildingData Building with changed power state
--- @param isPowered boolean New power state
function LKS_EletricidadeConstrucao.Core.EventManager.OnBuildingPowerChanged(buildingData, isPowered)
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.BUILDING_POWER_CHANGED, buildingData, isPowered)
end

--- Trigger building scanned event
--- @param buildingData BuildingData Building that was scanned
function LKS_EletricidadeConstrucao.Core.EventManager.OnBuildingScanned(buildingData)
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.BUILDING_SCANNED, buildingData)
end

-- ============================================================================
-- STATE EVENTS
-- ============================================================================

--- Trigger state loaded event
function LKS_EletricidadeConstrucao.Core.EventManager.OnStateLoaded()
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.STATE_LOADED)
end

--- Trigger state saved event
function LKS_EletricidadeConstrucao.Core.EventManager.OnStateSaved()
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.STATE_SAVED)
end

--- Trigger state reset event
function LKS_EletricidadeConstrucao.Core.EventManager.OnStateReset()
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.STATE_RESET)
end

-- ============================================================================
-- NETWORK EVENTS (Multiplayer)
-- ============================================================================

--- Trigger full sync event
function LKS_EletricidadeConstrucao.Core.EventManager.OnFullSync()
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.FULL_SYNC)
end

--- Trigger delta sync event
function LKS_EletricidadeConstrucao.Core.EventManager.OnDeltaSync()
    local Constants = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constants.EVENTS.DELTA_SYNC)
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

--- Get event statistics
--- @param eventName string|nil Event name (nil for all events)
--- @return table Statistics
function LKS_EletricidadeConstrucao.Core.EventManager.GetStats(eventName)
    if eventName then
        return _eventStats[eventName] or { fired = 0, handlers = 0 }
    else
        return _eventStats
    end
end

--- Get handler count for event
--- @param eventName string Event name
--- @return number Handler count
function LKS_EletricidadeConstrucao.Core.EventManager.GetHandlerCount(eventName)
    if not _eventHandlers[eventName] then
        return 0
    end
    
    return #_eventHandlers[eventName]
end

--- Check if event has handlers
--- @param eventName string Event name
--- @return boolean True if has handlers
function LKS_EletricidadeConstrucao.Core.EventManager.HasHandlers(eventName)
    return LKS_EletricidadeConstrucao.Core.EventManager.GetHandlerCount(eventName) > 0
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Print event statistics
function LKS_EletricidadeConstrucao.Core.EventManager.PrintStats()
    LKS_EletricidadeConstrucao.Print("=== Event Manager Statistics ===")
    
    local totalFired = 0
    local totalHandlers = 0
    
    for eventName, stats in pairs(_eventStats) do
        LKS_EletricidadeConstrucao.Print(string.format("  %s: fired=%d handlers=%d", 
            eventName, stats.fired, stats.handlers))
        
        totalFired = totalFired + stats.fired
        totalHandlers = totalHandlers + stats.handlers
    end
    
    LKS_EletricidadeConstrucao.Print(string.format("Total: %d events fired, %d handlers registered", 
        totalFired, totalHandlers))
end

--- Print registered events
function LKS_EletricidadeConstrucao.Core.EventManager.PrintEvents()
    LKS_EletricidadeConstrucao.Print("=== Registered Events ===")
    
    for eventName, handlers in pairs(_eventHandlers) do
        LKS_EletricidadeConstrucao.Print("  " .. eventName .. ": " .. #handlers .. " handler(s)")
        
        for i, entry in ipairs(handlers) do
            LKS_EletricidadeConstrucao.Print(string.format("    [%d] Priority: %d", i, entry.priority))
        end
    end
end

--- Clear all event statistics
function LKS_EletricidadeConstrucao.Core.EventManager.ClearStats()
    for eventName, stats in pairs(_eventStats) do
        stats.fired = 0
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug("Cleared event statistics", "Event")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Core.EventManager", "2.0.0")

return LKS_EletricidadeConstrucao.Core.EventManager
