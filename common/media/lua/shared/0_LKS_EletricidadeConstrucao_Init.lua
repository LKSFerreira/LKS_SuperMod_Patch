-- ============================================================================
-- 💖 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado como parte do LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) por sua fantástica contribuição para a comunidade!
-- ============================================================================

-- LKS_EletricidadeConstrucao_Init.lua
-- LKS_EletricidadeConstrucao V2 - Main Initialization File
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
LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao or {}
-- Alias LKS_EletricidadeConstrucao removido: use LKS_EletricidadeConstrucao.

LKS_EletricidadeConstrucao.VERSION = "2.0.0-alpha"
LKS_EletricidadeConstrucao.BUILD_DATE = "2026-02-22"
LKS_EletricidadeConstrucao.MOD_ID = "LKSSuperModPatch"

-- Create all sub-namespaces upfront
LKS_EletricidadeConstrucao.Core = LKS_EletricidadeConstrucao.Core or {}
LKS_EletricidadeConstrucao.Core.Runtime = LKS_EletricidadeConstrucao.Core.Runtime or {}
LKS_EletricidadeConstrucao.Core.StateManager = LKS_EletricidadeConstrucao.Core.StateManager or {}
LKS_EletricidadeConstrucao.Core.EventManager = LKS_EletricidadeConstrucao.Core.EventManager or {}

-- ============================================================================
-- PROXY LOGGER (Phase 0)
-- ============================================================================
-- Create a proxy logger that queues messages until the real logger is ready.
-- This ensures all modules can safely call Logger.Info/Warn/Error/Debug/Trace
-- at any point during loading without crashing, even before core/ is loaded.
if not LKS_EletricidadeConstrucao.Core.Logger or not LKS_EletricidadeConstrucao.Core.Logger._isProxy then
    local _queue = {}
    local _real = nil
    local function dispatch(level, msg, cat)
        if _real and _real[level] then
            _real[level](msg, cat)
        else
            table.insert(_queue, {level = level, msg = tostring(msg), cat = tostring(cat or "")})
        end
    end
    LKS_EletricidadeConstrucao.Core.Logger = {
        _isProxy = true,
        _queue = _queue,
        -- Called by LKS_EletricidadeConstrucao_Core_Logger.lua to activate the real implementation
        _activate = function(realLogger)
            _real = realLogger
            -- Flush queued messages
            for _, entry in ipairs(_queue) do
                if _real[entry.level] then
                    _real[entry.level](entry.msg, entry.cat)
                else
                    print(string.format("[LKS_EletricidadeConstrucao][%s][%s] %s", entry.level, entry.cat, entry.msg))
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

LKS_EletricidadeConstrucao.Fuel = LKS_EletricidadeConstrucao.Fuel or {}
LKS_EletricidadeConstrucao.Fuel.Manager = LKS_EletricidadeConstrucao.Fuel.Manager or {}
LKS_EletricidadeConstrucao.Fuel.StrainCalculator = LKS_EletricidadeConstrucao.Fuel.StrainCalculator or {}
LKS_EletricidadeConstrucao.Fuel.ChunkTracker = LKS_EletricidadeConstrucao.Fuel.ChunkTracker or {}

LKS_EletricidadeConstrucao.Power = LKS_EletricidadeConstrucao.Power or {}
LKS_EletricidadeConstrucao.Power.Manager = LKS_EletricidadeConstrucao.Power.Manager or {}
LKS_EletricidadeConstrucao.Power.Distributor = LKS_EletricidadeConstrucao.Power.Distributor or {}

LKS_EletricidadeConstrucao.Building = LKS_EletricidadeConstrucao.Building or {}
LKS_EletricidadeConstrucao.Building.Scanner = LKS_EletricidadeConstrucao.Building.Scanner or {}
LKS_EletricidadeConstrucao.Building.ConsumerScanner = LKS_EletricidadeConstrucao.Building.ConsumerScanner or {}
LKS_EletricidadeConstrucao.Building.BorderDetector = LKS_EletricidadeConstrucao.Building.BorderDetector or {}

LKS_EletricidadeConstrucao.Heating = LKS_EletricidadeConstrucao.Heating or {}
LKS_EletricidadeConstrucao.Heating.Manager = LKS_EletricidadeConstrucao.Heating.Manager or {}

LKS_EletricidadeConstrucao.DebugCommands = LKS_EletricidadeConstrucao.DebugCommands or {}

LKS_EletricidadeConstrucao.UI = LKS_EletricidadeConstrucao.UI or {}
LKS_EletricidadeConstrucao.Actions = LKS_EletricidadeConstrucao.Actions or {}
LKS_EletricidadeConstrucao.ContextMenu = LKS_EletricidadeConstrucao.ContextMenu or {}

LKS_EletricidadeConstrucao.Utils = LKS_EletricidadeConstrucao.Utils or {}
LKS_EletricidadeConstrucao.Data = LKS_EletricidadeConstrucao.Data or {}
LKS_EletricidadeConstrucao.Config = LKS_EletricidadeConstrucao.Config or {}
LKS_EletricidadeConstrucao.Constants = LKS_EletricidadeConstrucao.Constants or {}

LKS_EletricidadeConstrucao.Config.DebugMode = LKS_EletricidadeConstrucao.Config.DebugMode == true

if not LKS_EletricidadeConstrucao._RawPrint then
    LKS_EletricidadeConstrucao._RawPrint = print
end

local function ShouldSuppressLKS_EletricidadeConstrucaoPrint(message)
    if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
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
            or message == "LKS_EletricidadeConstrucao V2 - Initialization"
            or message == "LKS_EletricidadeConstrucao V2 Ready"
            or string.find(message, "Version:", 1, true) == 1
            or string.find(message, "Date:", 1, true) == 1
            or string.find(message, "  Mode:", 1, true) == 1
            or string.find(message, "  Server:", 1, true) == 1
            or string.find(message, "  Client:", 1, true) == 1
            or string.find(message, "  Modules:", 1, true) == 1 then
        return true
    end

    return string.find(message, "[LKS_EletricidadeConstrucao_", 1, true) == 1
        or string.find(message, "[LKS_EletricidadeConstrucao]", 1, true) == 1
        or string.find(message, "[LKS_EletricidadeConstrucao]", 1, true) == 1
end

if not LKS_EletricidadeConstrucao._PrintFilterInstalled then
    local rawPrint = LKS_EletricidadeConstrucao._RawPrint
    print = function(...)
        if select('#', ...) == 1 and ShouldSuppressLKS_EletricidadeConstrucaoPrint(select(1, ...)) then
            return
        end
        rawPrint(...)
    end
    LKS_EletricidadeConstrucao._PrintFilterInstalled = true
end

LKS_EletricidadeConstrucao._LoadedModules = LKS_EletricidadeConstrucao._LoadedModules or {}
LKS_EletricidadeConstrucao._InitStatus = LKS_EletricidadeConstrucao._InitStatus or {
    NamespaceDefined = true,
    RuntimeContextReady = false,
    ConstantsLoaded = false,
    ConfigLoaded = false,
    CoreInitialized = false,
    ClientInitialized = false,
    ServerInitialized = false
}

-- Helper functions
if not LKS_EletricidadeConstrucao.RegisterModule then
    function LKS_EletricidadeConstrucao.RegisterModule(moduleName, version)
        LKS_EletricidadeConstrucao._LoadedModules[moduleName] = {
            name = moduleName,
            version = version or "unknown",
            loadedAt = os.time()
        }
        print(string.format("[LKS_EletricidadeConstrucao] Module loaded: %s (v%s)", moduleName, version or "unknown"))
    end
end

if not LKS_EletricidadeConstrucao.Print then
    function LKS_EletricidadeConstrucao.Print(message, level)
        level = level or "INFO"
        print(string.format("[LKS_EletricidadeConstrucao][%s] %s", level, message))
    end
end

-- ============================================================================
-- PHASE 1: NAMESPACE & CORE SYSTEMS
-- ============================================================================

-- Load namespace module (now just adds helper functions)
require "core/LKS_EletricidadeConstrucao_Core_Namespace"

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Init] CRITICAL: Namespace initialization failed - skipping init")
    return
end

-- Load runtime context (game mode detection)
require "core/LKS_EletricidadeConstrucao_Core_RuntimeContext"

if not LKS_EletricidadeConstrucao._InitStatus.RuntimeContextReady then
    print("[LKS_EletricidadeConstrucao_Init] CRITICAL: Runtime context initialization failed - skipping init")
    return
end

-- ============================================================================
-- PHASE 2: CONFIGURATION & CONSTANTS
-- ============================================================================

-- Load constants (magic numbers, defaults)
require "LKS_EletricidadeConstrucao_Constants"

-- Load configuration (sandbox options)
require "LKS_EletricidadeConstrucao_Config"

if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.LoadFromSandbox then
    LKS_EletricidadeConstrucao.Config.LoadFromSandbox()
end

-- Validate configuration
if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.Validate then
    LKS_EletricidadeConstrucao.Config.Validate()
else
    print("[LKS_EletricidadeConstrucao_Init] WARNING: Config.Validate not available, using defaults")
end

-- ============================================================================
-- PHASE 3: UTILITIES (Shared code, no context-specific logic)
-- ============================================================================

-- Load utility modules
require "utils/LKS_EletricidadeConstrucao_Utils_Math"
require "utils/LKS_EletricidadeConstrucao_Utils_Geometry"
require "utils/LKS_EletricidadeConstrucao_Utils_Table"
require "utils/LKS_EletricidadeConstrucao_Utils_Validation"

-- ============================================================================
-- PHASE 4: DATA MODELS & CORE INFRASTRUCTURE
-- ============================================================================

-- Load data model definitions
require "data/LKS_EletricidadeConstrucao_Data_Generator"
require "data/LKS_EletricidadeConstrucao_Data_Building"
require "data/LKS_EletricidadeConstrucao_Data_Consumer"
require "data/LKS_EletricidadeConstrucao_Data_State"

-- Load core infrastructure
require "core/LKS_EletricidadeConstrucao_Core_Logger"
require "core/LKS_EletricidadeConstrucao_Core_StateManager"
require "core/LKS_EletricidadeConstrucao_Core_EventManager"

-- Initialize core systems
if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.EventManager and LKS_EletricidadeConstrucao.Core.EventManager.InitializeCustomEvents then
    LKS_EletricidadeConstrucao.Core.EventManager.InitializeCustomEvents()
else
    print("[LKS_EletricidadeConstrucao_Init] ERROR: EventManager.InitializeCustomEvents not available!")
    print("[LKS_EletricidadeConstrucao_Init] LKS_EletricidadeConstrucao.Core exists: " .. tostring(LKS_EletricidadeConstrucao.Core ~= nil))
    print("[LKS_EletricidadeConstrucao_Init] LKS_EletricidadeConstrucao.Core.EventManager exists: " .. tostring(LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.EventManager ~= nil))
end

if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager and LKS_EletricidadeConstrucao.Core.StateManager.Initialize then
    LKS_EletricidadeConstrucao.Core.StateManager.Initialize()
else
    print("[LKS_EletricidadeConstrucao_Init] ERROR: StateManager.Initialize not available!")
end

-- ============================================================================
-- PHASE 5: CONTEXT-SPECIFIC INITIALIZATION
-- ============================================================================

-- Print current runtime context
LKS_EletricidadeConstrucao.Core.Runtime.PrintContext()

-- ========================================
-- SHARED: TIMED ACTIONS (Both client and server)
-- ========================================
require "actions/LKS_EletricidadeConstrucao_ActionsInit"

-- ========================================
-- CLIENT/SERVER INITIALIZATION
-- ========================================
-- NOTE: Do NOT require client/ or server/ files from shared/!
-- PZ loads client/ files only in the client Lua state (where isClient()=true),
-- and server/ files only in the server Lua state (where isServer()=true).
-- Calling require "client/..." from a shared/ file would run client code in
-- the server state, breaking isClient() guards.
-- PZ itself will load LKS_EletricidadeConstrucao_ClientInit.lua and LKS_EletricidadeConstrucao_ServerInit.lua automatically.
LKS_EletricidadeConstrucao._InitStatus.ClientInitialized = false  -- Set by LKS_EletricidadeConstrucao_ClientInit.lua
LKS_EletricidadeConstrucao._InitStatus.ServerInitialized = false  -- Set by LKS_EletricidadeConstrucao_ServerInit.lua

-- ============================================================================
-- PHASE 6: PUBLIC API
-- ============================================================================

-- TODO: Load API modules
-- require "api/LKS_EletricidadeConstrucao_API_Generator"
-- require "api/LKS_EletricidadeConstrucao_API_Consumer"
-- require "api/LKS_EletricidadeConstrucao_API_Events"

-- ============================================================================
-- INITIALIZATION COMPLETE
-- ============================================================================

LKS_EletricidadeConstrucao._InitStatus.CoreInitialized = true

-- Print loaded modules
local loadedModules = LKS_EletricidadeConstrucao.GetLoadedModules()
LKS_EletricidadeConstrucao.Print(string.format("Initialization complete - %d modules loaded", #loadedModules))

if LKS_EletricidadeConstrucao.Config.DebugMode then
    LKS_EletricidadeConstrucao.Print("Loaded modules:")
    for _, moduleName in ipairs(loadedModules) do
        LKS_EletricidadeConstrucao.Print("  - " .. moduleName)
    end
end

-- Print summary
print("========================================")
print("LKS_EletricidadeConstrucao V2 Ready")
print(string.format("  Mode: %s", LKS_EletricidadeConstrucao.Core.Runtime.GetGameMode()))
print(string.format("  Server: %s", tostring(LKS_EletricidadeConstrucao.IsServer())))
print(string.format("  Client: %s", tostring(LKS_EletricidadeConstrucao.IsClient())))
print(string.format("  Modules: %d", #loadedModules))
print("========================================")

-- Save init timestamp
LKS_EletricidadeConstrucao._InitTimestamp = os.time()

return LKS_EletricidadeConstrucao
