-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Core_Namespace.lua
-- LKS_EletricidadeConstrucao V2 - Core Namespace Definition
-- This file creates the global LKS_EletricidadeConstrucao namespace and initializes all sub-namespaces
-- MUST be loaded FIRST before any other LKS_EletricidadeConstrucao files
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- ============================================================================
-- GLOBAL NAMESPACE INITIALIZATION
-- ============================================================================

-- Create main namespace if it doesn't exist
LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao or {}

-- Version information
LKS_EletricidadeConstrucao.VERSION = "2.0.0-alpha"
LKS_EletricidadeConstrucao.BUILD_DATE = "2026-02-22"
LKS_EletricidadeConstrucao.MOD_ID = "LKSSuperModPatch"

-- ============================================================================
-- SUB-NAMESPACE STRUCTURE
-- ============================================================================

-- Core systems
LKS_EletricidadeConstrucao.Core = LKS_EletricidadeConstrucao.Core or {}
LKS_EletricidadeConstrucao.Core.Runtime = LKS_EletricidadeConstrucao.Core.Runtime or {}
LKS_EletricidadeConstrucao.Core.Events = LKS_EletricidadeConstrucao.Core.Events or {}
LKS_EletricidadeConstrucao.Core.EventManager = LKS_EletricidadeConstrucao.Core.EventManager or {}
LKS_EletricidadeConstrucao.Core.State = LKS_EletricidadeConstrucao.Core.State or {}
LKS_EletricidadeConstrucao.Core.StateManager = LKS_EletricidadeConstrucao.Core.StateManager or {}
LKS_EletricidadeConstrucao.Core.Modules = LKS_EletricidadeConstrucao.Core.Modules or {}
LKS_EletricidadeConstrucao.Core.Logger = LKS_EletricidadeConstrucao.Core.Logger or {}

-- Domain namespaces (server-side)
LKS_EletricidadeConstrucao.Fuel = LKS_EletricidadeConstrucao.Fuel or {}
LKS_EletricidadeConstrucao.Fuel.Manager = LKS_EletricidadeConstrucao.Fuel.Manager or {}
LKS_EletricidadeConstrucao.Fuel.ChunkTracker = LKS_EletricidadeConstrucao.Fuel.ChunkTracker or {}
LKS_EletricidadeConstrucao.Fuel.StrainCalculator = LKS_EletricidadeConstrucao.Fuel.StrainCalculator or {}

LKS_EletricidadeConstrucao.Power = LKS_EletricidadeConstrucao.Power or {}
LKS_EletricidadeConstrucao.Power.Manager = LKS_EletricidadeConstrucao.Power.Manager or {}
LKS_EletricidadeConstrucao.Power.Distributor = LKS_EletricidadeConstrucao.Power.Distributor or {}

LKS_EletricidadeConstrucao.Building = LKS_EletricidadeConstrucao.Building or {}
LKS_EletricidadeConstrucao.Building.Scanner = LKS_EletricidadeConstrucao.Building.Scanner or {}
LKS_EletricidadeConstrucao.Building.BorderDetector = LKS_EletricidadeConstrucao.Building.BorderDetector or {}

LKS_EletricidadeConstrucao.Heating = LKS_EletricidadeConstrucao.Heating or {}
LKS_EletricidadeConstrucao.Heating.Manager = LKS_EletricidadeConstrucao.Heating.Manager or {}

-- UI namespace (client-side)
LKS_EletricidadeConstrucao.UI = LKS_EletricidadeConstrucao.UI or {}
LKS_EletricidadeConstrucao.Render = LKS_EletricidadeConstrucao.Render or {}
LKS_EletricidadeConstrucao.Input = LKS_EletricidadeConstrucao.Input or {}

-- Utility namespaces (shared)
LKS_EletricidadeConstrucao.Utils = LKS_EletricidadeConstrucao.Utils or {}
LKS_EletricidadeConstrucao.Utils.Math = LKS_EletricidadeConstrucao.Utils.Math or {}
LKS_EletricidadeConstrucao.Utils.Geometry = LKS_EletricidadeConstrucao.Utils.Geometry or {}
LKS_EletricidadeConstrucao.Utils.Table = LKS_EletricidadeConstrucao.Utils.Table or {}
LKS_EletricidadeConstrucao.Utils.String = LKS_EletricidadeConstrucao.Utils.String or {}
LKS_EletricidadeConstrucao.Utils.Validation = LKS_EletricidadeConstrucao.Utils.Validation or {}

-- Data models (shared)
LKS_EletricidadeConstrucao.Data = LKS_EletricidadeConstrucao.Data or {}
LKS_EletricidadeConstrucao.Data.Generator = LKS_EletricidadeConstrucao.Data.Generator or {}
LKS_EletricidadeConstrucao.Data.Building = LKS_EletricidadeConstrucao.Data.Building or {}
LKS_EletricidadeConstrucao.Data.Consumer = LKS_EletricidadeConstrucao.Data.Consumer or {}
LKS_EletricidadeConstrucao.Data.State = LKS_EletricidadeConstrucao.Data.State or {}

-- Public API for other mods
LKS_EletricidadeConstrucao.API = LKS_EletricidadeConstrucao.API or {}
LKS_EletricidadeConstrucao.API.Generator = LKS_EletricidadeConstrucao.API.Generator or {}
LKS_EletricidadeConstrucao.API.Consumer = LKS_EletricidadeConstrucao.API.Consumer or {}
LKS_EletricidadeConstrucao.API.Events = LKS_EletricidadeConstrucao.API.Events or {}

-- Configuration (populated by LKS_EletricidadeConstrucao_Config.lua)
LKS_EletricidadeConstrucao.Config = LKS_EletricidadeConstrucao.Config or {}

-- Constants (populated by LKS_EletricidadeConstrucao_Constants.lua)
LKS_EletricidadeConstrucao.Constants = LKS_EletricidadeConstrucao.Constants or {}

-- ============================================================================
-- INITIALIZATION STATE TRACKING
-- ============================================================================

-- Track which modules have been loaded
LKS_EletricidadeConstrucao._LoadedModules = LKS_EletricidadeConstrucao._LoadedModules or {}

-- Track initialization status
LKS_EletricidadeConstrucao._InitStatus = LKS_EletricidadeConstrucao._InitStatus or {
    NamespaceDefined = false,
    RuntimeContextReady = false,
    ConstantsLoaded = false,
    ConfigLoaded = false,
    CoreInitialized = false,
    ClientInitialized = false,
    ServerInitialized = false
}

-- Mark namespace as defined
LKS_EletricidadeConstrucao._InitStatus.NamespaceDefined = true

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

--- Register a module as loaded
--- @param moduleName string The name of the module (e.g., "Core.RuntimeContext")
--- @param version string Optional version string
function LKS_EletricidadeConstrucao.RegisterModule(moduleName, version)
    LKS_EletricidadeConstrucao._LoadedModules[moduleName] = {
        name = moduleName,
        version = version or "unknown",
        loadedAt = os.time()
    }
    print(string.format("[LKS_EletricidadeConstrucao] Module loaded: %s (v%s)", moduleName, version or "unknown"))
end

--- Check if a module is loaded
--- @param moduleName string The module name to check
--- @return boolean True if module is loaded
function LKS_EletricidadeConstrucao.IsModuleLoaded(moduleName)
    return LKS_EletricidadeConstrucao._LoadedModules[moduleName] ~= nil
end

--- Get list of all loaded modules
--- @return table Array of loaded module names
function LKS_EletricidadeConstrucao.GetLoadedModules()
    local modules = {}
    for name, _ in pairs(LKS_EletricidadeConstrucao._LoadedModules) do
        table.insert(modules, name)
    end
    return modules
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Safe print with mod prefix
--- @param message string The message to print
--- @param level string Optional log level ("INFO", "WARN", "ERROR", "DEBUG")
function LKS_EletricidadeConstrucao.Print(message, level)
    level = level or "INFO"
    print(string.format("[LKS_EletricidadeConstrucao][%s] %s", level, message))
end

--- Print error message
--- @param message string The error message
function LKS_EletricidadeConstrucao.Error(message)
    LKS_EletricidadeConstrucao.Print(message, "ERROR")
end

--- Print warning message
--- @param message string The warning message
function LKS_EletricidadeConstrucao.Warn(message)
    LKS_EletricidadeConstrucao.Print(message, "WARN")
end

--- Print debug message (only if debug mode enabled)
--- @param message string The debug message
function LKS_EletricidadeConstrucao.Debug(message)
    if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
        LKS_EletricidadeConstrucao.Print(message, "DEBUG")
    end
end

-- ============================================================================
-- INITIALIZATION COMPLETE
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Core.Namespace", LKS_EletricidadeConstrucao.VERSION)
LKS_EletricidadeConstrucao.Print(string.format("Namespace initialized - Version %s (%s)", 
    LKS_EletricidadeConstrucao.VERSION, LKS_EletricidadeConstrucao.BUILD_DATE))

-- Anti-pollution: Return namespace (allows require() pattern)
return LKS_EletricidadeConstrucao
