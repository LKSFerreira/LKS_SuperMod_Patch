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
PoweredBuildings.Core.Logger = PoweredBuildings.Core.Logger or {}
PoweredBuildings.Core.StateManager = PoweredBuildings.Core.StateManager or {}
PoweredBuildings.Core.EventManager = PoweredBuildings.Core.EventManager or {}

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
-- SHARED: TIMED ACTIONS (Both client and server)
-- ========================================
require "actions/PB_ActionsInit"

-- ========================================
-- CLIENT-SIDE INITIALIZATION
-- ========================================
if PoweredBuildings.IsClient() then
    -- Load client init (UI, context menus, input handlers)
    require "client/PB_ClientInit"
    
    PoweredBuildings._InitStatus.ClientInitialized = true
    PoweredBuildings.Print("Client initialization complete")
end

-- ========================================
-- SERVER-SIDE INITIALIZATION  
-- ========================================
if PoweredBuildings.IsServer() then
    -- Load server init (which loads all server modules)
    require "server/PB_ServerInit"
    
    PoweredBuildings._InitStatus.ServerInitialized = true
    PoweredBuildings.Print("Server initialization complete")
end

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
