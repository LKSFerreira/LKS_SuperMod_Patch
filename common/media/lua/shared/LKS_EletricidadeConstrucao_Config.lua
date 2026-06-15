-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Config.lua
-- LKS_EletricidadeConstrucao V2 - Runtime Configuration
-- Loaded from sandbox options and manages runtime settings
-- Settings can be changed by server admin without code modification
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Config] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

local FuelConstants = LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.FUEL or {}
local BuildingConstants = LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.BUILDING or {}

-- ============================================================================
-- DEFAULT CONFIGURATION
-- ============================================================================

-- These are defaults - will be overridden by sandbox options when available
LKS_EletricidadeConstrucao.Config = {
    -- ========================================================================
    -- GENERAL SETTINGS
    -- ========================================================================
    
    ModEnabled = true,                         -- Master on/off switch
    DebugMode = false,                         -- Enable verbose logging
    ShowNotifications = true,                  -- Show player notifications
    RefrigerationEnabled = true,
    LaundryEnabled = true,
    CookingEnabled = true,
    
    -- ========================================================================
    -- FUEL CONSUMPTION SETTINGS
    -- ========================================================================
    
    FuelConsumptionEnabled = true,             -- Enable fuel consumption system
    FuelConsumptionRate = 1.0,                 -- Multiplier for fuel usage (1.0 = default)
    RealisticFuelConsumption = true,           -- Enable strain-based consumption
    ChunkReloadTracking = true,                -- Track fuel during chunk unload
    
    -- Strain system
    StrainSystemEnabled = true,                -- Enable generator strain mechanics
    StrainModifier = 0.01,                     -- Fuel multiplier per % strain (default from constants)
    StrainEfficiencyPenalty = true,            -- High strain = worse fuel efficiency
    OverloadFailureEnabled = false,            -- Generators can fail from extreme overload
    BaseLoadCapacity = FuelConstants.BASE_LOAD_CAPACITY or 120.0,
    
    -- ========================================================================
    -- BUILDING DETECTION SETTINGS
    -- ========================================================================
    
    AutoDetectBuildings = true,                -- Automatically scan for buildings
    MaxScanRadius = 50,                        -- Maximum tiles to scan (reduced from constant)
    BorderRadius = 2,                          -- Tiles around building for outdoor items
    MultiFloorSupport = true,                  -- Detect multi-story buildings
    
    -- Performance
    ScanThrottling = true,                     -- Limit scan time per frame
    MaxScansPerFrame = 5,                      -- Max concurrent scans
    MaxConsumersPerBuilding = BuildingConstants.MAX_CONSUMERS_PER_BUILDING or 500,
    MaxGeneratorsPerBuilding = BuildingConstants.MAX_GENERATORS_PER_BUILDING or 10,
    
    -- ========================================================================
    -- HEATING SYSTEM SETTINGS
    -- ========================================================================
    
    HeatingSystemEnabled = false,              -- Heating is currently intended for singleplayer use
    TargetTemperature = 18.0,                  -- Desired indoor temperature
    HeatingPowerCost = 1.0,                    -- Multiplier for heating power usage
    InsulationEnabled = true,                  -- Account for wall/roof insulation
    
    -- ========================================================================
    -- UI SETTINGS
    -- ========================================================================
    
    ShowInfoWindow = true,                     -- Enable generator info window
    ShowCoverageArea = false,                  -- Render green tiles for coverage (debug)
    RealtimeLightCount = true,                 -- Update light count in real-time
    ShowStrainIndicator = true,                -- Show strain gauge in UI
    
    UIUpdateRate = 100,                        -- UI refresh rate (milliseconds)
    ShowFuelPercentage = true,                 -- Show fuel as percentage
    ShowConsumerCount = true,                  -- Show number of powered items
    
    -- ========================================================================
    -- NETWORK SETTINGS (Multiplayer)
    -- ========================================================================
    
    NetworkSyncEnabled = true,                 -- Enable state sync to clients
    FullSyncInterval = 30,                     -- Full sync every N minutes
    DeltaSyncInterval = 1,                     -- Delta sync every N minutes
    BatchNetworkUpdates = true,                -- Group updates for efficiency
    
    -- ========================================================================
    -- COMPATIBILITY SETTINGS
    -- ========================================================================
    
    RVInteriorCompatibility = true,            -- Support RV Interior mod coordinates
    VanillaGeneratorOverride = false,          -- Replace vanilla generator behavior
    ModdedGeneratorSupport = true,             -- Detect generators from other mods
    
    -- ========================================================================
    -- BARREL SYSTEM SETTINGS
    -- ========================================================================
    
    BarrelSystemEnabled = true,                -- Enable barrel linking
    AutoRefuelFromBarrels = true,              -- Automatically transfer fuel
    MaxBarrelsPerGenerator = 10,               -- Maximum linked barrels
    BarrelRefuelRate = 10.0,                   -- Fuel units per game hour
    
    -- ========================================================================
    -- ADVANCED SETTINGS
    -- ========================================================================
    
    StateVersion = 2.0,                        -- ModData schema version
    EnableLegacyMigration = true,              -- Support V1 save migration
    PerformanceMode = false,                   -- Reduce features for performance
    
    -- Debug options
    DebugCategories = {
        FuelConsumption = false,
        BuildingDetection = false,
        NetworkSync = false,
        UIUpdates = false
    }
}

local function ApplySandboxBackedConstants()
    local constants = LKS_EletricidadeConstrucao.Constants
    local config = LKS_EletricidadeConstrucao.Config
    if not constants or not config then
        return
    end

    constants.FUEL = constants.FUEL or {}
    constants.BUILDING = constants.BUILDING or {}

    constants.FUEL.BASE_LOAD_CAPACITY = config.BaseLoadCapacity
    if config.BaseLoadCapacity and config.BaseLoadCapacity > 0 then
        constants.FUEL.BASE_STRAIN_PER_LIGHT = 100 / config.BaseLoadCapacity
    end

    constants.BUILDING.MAX_CONSUMERS_PER_BUILDING = config.MaxConsumersPerBuilding
    constants.BUILDING.MAX_GENERATORS_PER_BUILDING = config.MaxGeneratorsPerBuilding
end

-- ============================================================================
-- CONFIGURATION LOADING
-- ============================================================================

--- Load configuration from sandbox options
--- Called during mod initialization
function LKS_EletricidadeConstrucao.Config.LoadFromSandbox()
    local sandboxOptions = SandboxVars
    
    if not sandboxOptions then
        LKS_EletricidadeConstrucao.Warn("Sandbox options not available, using defaults")
        return
    end
    
    local sb = sandboxOptions.LKS_EletricidadeConstrucao or {}

    if sb.EletricidadeRealistaEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.ModEnabled = sb.EletricidadeRealistaEnabled
    end

    if sb.DebugToolsEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.DebugMode = sb.DebugToolsEnabled
    end

    if sb.BarrelSystemEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.BarrelSystemEnabled = sb.BarrelSystemEnabled
        LKS_EletricidadeConstrucao.Config.AutoRefuelFromBarrels = sb.BarrelSystemEnabled
    end

    if sb.RefrigerationEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.RefrigerationEnabled = sb.RefrigerationEnabled
    end

    if sb.LaundryEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.LaundryEnabled = sb.LaundryEnabled
    end

    if sb.CookingEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.CookingEnabled = sb.CookingEnabled
    end

    if sb.HeatingSystemEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.HeatingSystemEnabled = sb.HeatingSystemEnabled
    end

    if sb.HeatRadius ~= nil then
        LKS_EletricidadeConstrucao.Config.HeatRadius = sb.HeatRadius
    end

    if sb.BaseLoadCapacity ~= nil then
        LKS_EletricidadeConstrucao.Config.BaseLoadCapacity = sb.BaseLoadCapacity
    end

    if sb.MaxConsumersPerBuilding ~= nil then
        LKS_EletricidadeConstrucao.Config.MaxConsumersPerBuilding = sb.MaxConsumersPerBuilding
    end

    if sb.MaxGeneratorsPerBuilding ~= nil then
        LKS_EletricidadeConstrucao.Config.MaxGeneratorsPerBuilding = sb.MaxGeneratorsPerBuilding
    end

    ApplySandboxBackedConstants()
    
    LKS_EletricidadeConstrucao.Print("Configuration loaded from sandbox options")
end

--- Save configuration to ModData (for persistence)
--- @param key string Optional config key to save (nil = save all)
function LKS_EletricidadeConstrucao.Config.SaveToModData(key)
    if not LKS_EletricidadeConstrucao.IsServer() then
        LKS_EletricidadeConstrucao.Warn("Config.SaveToModData called on client - ignoring")
        return
    end
    
    if key then
        -- Save specific config value
        ModData.add("LKS_EletricidadeConstrucao_Config_" .. key, LKS_EletricidadeConstrucao.Config[key])
    else
        -- Save entire config
        ModData.add("LKS_EletricidadeConstrucao_ConfigData", LKS_EletricidadeConstrucao.Config)
    end
    
    if LKS_EletricidadeConstrucao.IsMP() then
        ModData.transmit("LKS_EletricidadeConstrucao_ConfigData")
    end
end

--- Load configuration from ModData (on client sync or save load)
function LKS_EletricidadeConstrucao.Config.LoadFromModData()
    local savedConfig = ModData.get("LKS_EletricidadeConstrucao_ConfigData")
    
    if savedConfig then
        -- Merge saved config with defaults (preserve new defaults)
        for key, value in pairs(savedConfig) do
            if LKS_EletricidadeConstrucao.Config[key] ~= nil then
                LKS_EletricidadeConstrucao.Config[key] = value
            end
        end
        LKS_EletricidadeConstrucao.Print("Configuration loaded from ModData")
    end
end

--- Reset configuration to defaults
function LKS_EletricidadeConstrucao.Config.ResetToDefaults()
    LKS_EletricidadeConstrucao.Warn("Resetting configuration to defaults")
    -- Reload this file (simple approach - in production, store defaults separately)
    require("LKS_EletricidadeConstrucao_Config")
end

--- Validate configuration values (ensure sane ranges)
function LKS_EletricidadeConstrucao.Config.Validate()
    local config = LKS_EletricidadeConstrucao.Config
    local warnings = 0
    
    -- Validate numeric ranges
    if config.FuelConsumptionRate < 0.1 or config.FuelConsumptionRate > 10.0 then
        LKS_EletricidadeConstrucao.Warn("FuelConsumptionRate out of range (0.1-10), clamping")
        config.FuelConsumptionRate = math.max(0.1, math.min(10.0, config.FuelConsumptionRate))
        warnings = warnings + 1
    end
    
    if config.MaxScanRadius < 10 or config.MaxScanRadius > 200 then
        LKS_EletricidadeConstrucao.Warn("MaxScanRadius out of range (10-200), clamping")
        config.MaxScanRadius = math.max(10, math.min(200, config.MaxScanRadius))
        warnings = warnings + 1
    end
    
    if config.TargetTemperature < -20 or config.TargetTemperature > 40 then
        LKS_EletricidadeConstrucao.Warn("TargetTemperature out of range (-20-40), clamping")
        config.TargetTemperature = math.max(-20, math.min(40, config.TargetTemperature))
        warnings = warnings + 1
    end

    if config.BaseLoadCapacity < 20 or config.BaseLoadCapacity > 500 then
        LKS_EletricidadeConstrucao.Warn("BaseLoadCapacity out of range (20-500), clamping")
        config.BaseLoadCapacity = math.max(20, math.min(500, config.BaseLoadCapacity))
        warnings = warnings + 1
    end

    if config.MaxConsumersPerBuilding < 50 or config.MaxConsumersPerBuilding > 5000 then
        LKS_EletricidadeConstrucao.Warn("MaxConsumersPerBuilding out of range (50-5000), clamping")
        config.MaxConsumersPerBuilding = math.max(50, math.min(5000, config.MaxConsumersPerBuilding))
        warnings = warnings + 1
    end

    if config.MaxGeneratorsPerBuilding < 1 or config.MaxGeneratorsPerBuilding > 50 then
        LKS_EletricidadeConstrucao.Warn("MaxGeneratorsPerBuilding out of range (1-50), clamping")
        config.MaxGeneratorsPerBuilding = math.max(1, math.min(50, config.MaxGeneratorsPerBuilding))
        warnings = warnings + 1
    end

    ApplySandboxBackedConstants()
    
    if warnings > 0 then
        LKS_EletricidadeConstrucao.Warn(string.format("Configuration validation found %d issue(s)", warnings))
    else
        LKS_EletricidadeConstrucao.Debug("Configuration validation passed")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao._InitStatus.ConfigLoaded = true
LKS_EletricidadeConstrucao.RegisterModule("Config", "2.0.0")

-- Validate config on load
LKS_EletricidadeConstrucao.Config.Validate()

LKS_EletricidadeConstrucao.Print("Configuration initialized with defaults")

return LKS_EletricidadeConstrucao.Config
