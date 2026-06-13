-- ============================================================================
-- 💖 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado como parte do LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3097103233) por sua fantástica contribuição para a comunidade!
-- ============================================================================

-- PB_Init.lua
-- PoweredBuildings V2 - Main Initialization File
-- This is the entry point for the mod - loads all core systems in correct order
-- MUST be loaded first (enforced by filename alphabetical order)
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- ============================================================================
-- PHASE 0: CREATE GLOBAL NAMESPACE IMMEDIATELY
-- ============================================================================
-- CRITICAL: Must create namespace BEFORE loading any other files
-- because PZ loads files alphabetically (actions/ loads before core/)

-- Create main namespace and all sub-namespaces
PoweredBuildings = PoweredBuildings or {}
PB = PoweredBuildings  -- Short alias

PoweredBuildings.VERSION = "2.0.0-alpha"
PoweredBuildings.BUILD_DATE = "2026-02-22"
PoweredBuildings.MOD_ID = "PoweredBuildings"

-- Create all sub-namespaces upfront
PoweredBuildings.Core = PoweredBuildings.Core or {}
PoweredBuildings.Core.Runtime = PoweredBuildings.Core.Runtime or {}
PoweredBuildings.Core.StateManager = PoweredBuildings.Core.StateManager or {}
PoweredBuildings.Core.EventManager = PoweredBuildings.Core.EventManager or {}

-- ============================================================================
-- PROXY LOGGER (Phase 0)
-- ============================================================================
-- Create a proxy logger that queues messages until the real logger is ready.
-- This ensures all modules can safely call Logger.Info/Warn/Error/Debug/Trace
-- at any point during loading without crashing, even before core/ is loaded.
if not PoweredBuildings.Core.Logger or not PoweredBuildings.Core.Logger._isProxy then
    local _queue = {}
    local _real = nil
    local function dispatch(level, msg, cat)
        if _real and _real[level] then
            _real[level](msg, cat)
        else
            table.insert(_queue, {level = level, msg = tostring(msg), cat = tostring(cat or "")})
        end
    end
    PoweredBuildings.Core.Logger = {
        _isProxy = true,
        _queue = _queue,
        -- Called by PB_Core_Logger.lua to activate the real implementation
        _activate = function(realLogger)
            _real = realLogger
            -- Flush queued messages
            for _, entry in ipairs(_queue) do
                if _real[entry.level] then
                    _real[entry.level](entry.msg, entry.cat)
                else
                    print(string.format("[PB][%s][%s] %s", entry.level, entry.cat, entry.msg))
                end
            end
            _queue = {}
        end,
        Info  = function(msg, cat) dispatch("Info",  msg, cat) end,
        Warn  = function(msg, cat) dispatch("Warn",  msg, cat) end,
        Error = function(msg, cat) dispatch("Error", msg, cat) end,
        Debug = function(msg, cat) dispatch("Debug", msg, cat) end,
        Trace = function(msg, cat) dispatch("Trace", msg, cat) end,
    }
end

PoweredBuildings.Fuel = PoweredBuildings.Fuel or {}
PoweredBuildings.Fuel.Manager = PoweredBuildings.Fuel.Manager or {}
PoweredBuildings.Fuel.StrainCalculator = PoweredBuildings.Fuel.StrainCalculator or {}
PoweredBuildings.Fuel.ChunkTracker = PoweredBuildings.Fuel.ChunkTracker or {}

PoweredBuildings.Power = PoweredBuildings.Power or {}
PoweredBuildings.Power.Manager = PoweredBuildings.Power.Manager or {}
PoweredBuildings.Power.Distributor = PoweredBuildings.Power.Distributor or {}

PoweredBuildings.Building = PoweredBuildings.Building or {}
PoweredBuildings.Building.Scanner = PoweredBuildings.Building.Scanner or {}
PoweredBuildings.Building.ConsumerScanner = PoweredBuildings.Building.ConsumerScanner or {}
PoweredBuildings.Building.BorderDetector = PoweredBuildings.Building.BorderDetector or {}

PoweredBuildings.Heating = PoweredBuildings.Heating or {}
PoweredBuildings.Heating.Manager = PoweredBuildings.Heating.Manager or {}

PoweredBuildings.DebugCommands = PoweredBuildings.DebugCommands or {}

PoweredBuildings.UI = PoweredBuildings.UI or {}
PoweredBuildings.Actions = PoweredBuildings.Actions or {}
PoweredBuildings.ContextMenu = PoweredBuildings.ContextMenu or {}

PoweredBuildings.Utils = PoweredBuildings.Utils or {}
PoweredBuildings.Data = PoweredBuildings.Data or {}
PoweredBuildings.Config = PoweredBuildings.Config or {}
PoweredBuildings.Constants = PoweredBuildings.Constants or {}

PoweredBuildings.Config.DebugMode = PoweredBuildings.Config.DebugMode == true

if not PoweredBuildings._RawPrint then
    PoweredBuildings._RawPrint = print
end

local function ShouldSuppressPoweredBuildingsPrint(message)
    if PoweredBuildings.Config and PoweredBuildings.Config.DebugMode then
        return false
    end

    message = tostring(message or "")
    local upper = string.upper(message)
    if string.find(upper, "ERROR", 1, true)
            or string.find(upper, "WARN", 1, true)
            or string.find(upper, "CRITICAL", 1, true) then
        return false
    end

    if message == "========================================"
            or message == "PoweredBuildings V2 - Initialization"
            or message == "PoweredBuildings V2 Ready"
            or string.find(message, "Version:", 1, true) == 1
            or string.find(message, "Date:", 1, true) == 1
            or string.find(message, "  Mode:", 1, true) == 1
            or string.find(message, "  Server:", 1, true) == 1
            or string.find(message, "  Client:", 1, true) == 1
            or string.find(message, "  Modules:", 1, true) == 1 then
        return true
    end

    return string.find(message, "[PB_", 1, true) == 1
        or string.find(message, "[PB]", 1, true) == 1
        or string.find(message, "[PoweredBuildings]", 1, true) == 1
end

if not PoweredBuildings._PrintFilterInstalled then
    local rawPrint = PoweredBuildings._RawPrint
    print = function(...)
        if select('#', ...) == 1 and ShouldSuppressPoweredBuildingsPrint(select(1, ...)) then
            return
        end
        rawPrint(...)
    end
    PoweredBuildings._PrintFilterInstalled = true
end

PoweredBuildings._LoadedModules = PoweredBuildings._LoadedModules or {}
PoweredBuildings._InitStatus = PoweredBuildings._InitStatus or {
    NamespaceDefined = true,
    RuntimeContextReady = false,
    ConstantsLoaded = false,
    ConfigLoaded = false,
    CoreInitialized = false,
    ClientInitialized = false,
    ServerInitialized = false
}

-- Helper functions
if not PoweredBuildings.RegisterModule then
    function PoweredBuildings.RegisterModule(moduleName, version)
        PoweredBuildings._LoadedModules[moduleName] = {
            name = moduleName,
            version = version or "unknown",
            loadedAt = os.time()
        }
        print(string.format("[PoweredBuildings] Module loaded: %s (v%s)", moduleName, version or "unknown"))
    end
end

if not PoweredBuildings.Print then
    function PoweredBuildings.Print(message, level)
        level = level or "INFO"
        print(string.format("[PoweredBuildings][%s] %s", level, message))
    end
end

-- ============================================================================
-- PHASE 1: NAMESPACE & CORE SYSTEMS
-- ============================================================================

-- Load namespace module (now just adds helper functions)
require "core/PB_Core_Namespace"

if not PoweredBuildings then
    print("[PB_Init] CRITICAL: Namespace initialization failed - skipping init")
    return
end

-- Load runtime context (game mode detection)
require "core/PB_Core_RuntimeContext"

if not PoweredBuildings._InitStatus.RuntimeContextReady then
    print("[PB_Init] CRITICAL: Runtime context initialization failed - skipping init")
    return
end

-- ============================================================================
-- PHASE 2: CONFIGURATION & CONSTANTS
-- ============================================================================

-- Load constants (magic numbers, defaults)
require "PB_Constants"

-- Load configuration (sandbox options)
require "PB_Config"

if PoweredBuildings.Config and PoweredBuildings.Config.LoadFromSandbox then
    PoweredBuildings.Config.LoadFromSandbox()
end

-- Validate configuration
if PoweredBuildings.Config and PoweredBuildings.Config.Validate then
    PoweredBuildings.Config.Validate()
else
    print("[PB_Init] WARNING: Config.Validate not available, using defaults")
end

-- ============================================================================
-- PHASE 3: UTILITIES (Shared code, no context-specific logic)
-- ============================================================================

-- Load utility modules
require "utils/PB_Utils_Math"
require "utils/PB_Utils_Geometry"
require "utils/PB_Utils_Table"
require "utils/PB_Utils_Validation"

-- ============================================================================
-- PHASE 4: DATA MODELS & CORE INFRASTRUCTURE
-- ============================================================================

-- Load data model definitions
require "data/PB_Data_Generator"
require "data/PB_Data_Building"
require "data/PB_Data_Consumer"
require "data/PB_Data_State"

-- Load core infrastructure
require "core/PB_Core_Logger"
require "core/PB_Core_StateManager"
require "core/PB_Core_EventManager"

-- Initialize core systems
if PoweredBuildings.Core and PoweredBuildings.Core.EventManager and PoweredBuildings.Core.EventManager.InitializeCustomEvents then
    PoweredBuildings.Core.EventManager.InitializeCustomEvents()
else
    print("[PB_Init] ERROR: EventManager.InitializeCustomEvents not available!")
    print("[PB_Init] PoweredBuildings.Core exists: " .. tostring(PoweredBuildings.Core ~= nil))
    print("[PB_Init] PoweredBuildings.Core.EventManager exists: " .. tostring(PoweredBuildings.Core and PoweredBuildings.Core.EventManager ~= nil))
end

if PoweredBuildings.Core and PoweredBuildings.Core.StateManager and PoweredBuildings.Core.StateManager.Initialize then
    PoweredBuildings.Core.StateManager.Initialize()
else
    print("[PB_Init] ERROR: StateManager.Initialize not available!")
end

-- ============================================================================
-- PHASE 5: CONTEXT-SPECIFIC INITIALIZATION
-- ============================================================================

-- Print current runtime context
PoweredBuildings.Core.Runtime.PrintContext()

-- ========================================
-- SHARED: TIMED ACTIONS (Both client and server)
-- ========================================
require "actions/PB_ActionsInit"

-- ========================================
-- CLIENT/SERVER INITIALIZATION
-- ========================================
-- NOTE: Do NOT require client/ or server/ files from shared/!
-- PZ loads client/ files only in the client Lua state (where isClient()=true),
-- and server/ files only in the server Lua state (where isServer()=true).
-- Calling require "client/..." from a shared/ file would run client code in
-- the server state, breaking isClient() guards.
-- PZ itself will load PB_ClientInit.lua and PB_ServerInit.lua automatically.
PoweredBuildings._InitStatus.ClientInitialized = false  -- Set by PB_ClientInit.lua
PoweredBuildings._InitStatus.ServerInitialized = false  -- Set by PB_ServerInit.lua

-- ============================================================================
-- PHASE 6: PUBLIC API
-- ============================================================================

-- TODO: Load API modules
-- require "api/PB_API_Generator"
-- require "api/PB_API_Consumer"
-- require "api/PB_API_Events"

-- ============================================================================
-- INITIALIZATION COMPLETE
-- ============================================================================

PoweredBuildings._InitStatus.CoreInitialized = true

-- Print loaded modules
local loadedModules = PoweredBuildings.GetLoadedModules()
PoweredBuildings.Print(string.format("Initialization complete - %d modules loaded", #loadedModules))

if PoweredBuildings.Config.DebugMode then
    PoweredBuildings.Print("Loaded modules:")
    for _, moduleName in ipairs(loadedModules) do
        PoweredBuildings.Print("  - " .. moduleName)
    end
end

-- Print summary
print("========================================")
print("PoweredBuildings V2 Ready")
print(string.format("  Mode: %s", PoweredBuildings.Core.Runtime.GetGameMode()))
print(string.format("  Server: %s", tostring(PoweredBuildings.IsServer())))
print(string.format("  Client: %s", tostring(PoweredBuildings.IsClient())))
print(string.format("  Modules: %d", #loadedModules))
print("========================================")

-- Save init timestamp
PoweredBuildings._InitTimestamp = os.time()

return PoweredBuildings
