-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Constants.lua
-- LKS_EletricidadeConstrucao V2 - Global Constants
-- All hardcoded values, magic numbers, and configuration defaults
-- This file contains ONLY data, no logic
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Constants] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- MOD DATA KEYS
-- ============================================================================

LKS_EletricidadeConstrucao.Constants.MODDATA_KEYS = {
    -- Generator data
    GENERATOR_PREFIX = "LKS_EletricidadeConstrucao_Generator_",        -- Prefix for generator ModData keys
    GENERATOR_LIST = "LKS_EletricidadeConstrucao_GeneratorList",       -- List of all registered generators
    
    -- Building data
    BUILDING_PREFIX = "LKS_EletricidadeConstrucao_Building_",          -- Prefix for building ModData keys
    BUILDING_LIST = "LKS_EletricidadeConstrucao_BuildingList",         -- List of all powered buildings
    
    -- State data
    STATE_VERSION = "LKS_EletricidadeConstrucao_StateVersion",         -- ModData schema version
    GLOBAL_STATE = "LKS_EletricidadeConstrucao_GlobalState",           -- Global mod state
    
    -- Legacy data (for V1 migration)
    LEGACY_BUILDING_DATA = "ConnectedBuildingsData",
    LEGACY_CONSUMER_DATA = "PoweredConsumers"
}

-- ============================================================================
-- EVENT NAMES
-- ============================================================================

LKS_EletricidadeConstrucao.Constants.EVENTS = {
    -- Custom events
    GENERATOR_CONNECTED = "LKS_EletricidadeConstrucao_GeneratorConnected",
    GENERATOR_DISCONNECTED = "LKS_EletricidadeConstrucao_GeneratorDisconnected",
    GENERATOR_ACTIVATED = "LKS_EletricidadeConstrucao_GeneratorActivated",
    GENERATOR_DEACTIVATED = "LKS_EletricidadeConstrucao_GeneratorDeactivated",
    GENERATOR_FUEL_CHANGED = "LKS_EletricidadeConstrucao_GeneratorFuelChanged",
    GENERATOR_FUEL_EMPTY = "LKS_EletricidadeConstrucao_GeneratorFuelEmpty",
    
    BUILDING_POWER_CHANGED = "LKS_EletricidadeConstrucao_BuildingPowerChanged",
    BUILDING_SCANNED = "LKS_EletricidadeConstrucao_BuildingScanned",
    
    CONSUMER_ADDED = "LKS_EletricidadeConstrucao_ConsumerAdded",
    CONSUMER_REMOVED = "LKS_EletricidadeConstrucao_ConsumerRemoved",
    
    -- Network events (server commands)
    SERVER_CMD_SYNC_STATE = "LKS_EletricidadeConstrucao_SyncState",
    SERVER_CMD_UPDATE_FUEL = "LKS_EletricidadeConstrucao_UpdateFuel",
    SERVER_CMD_TOGGLE_POWER = "LKS_EletricidadeConstrucao_TogglePower"
}

-- ============================================================================
-- FUEL CONSUMPTION
-- ============================================================================

LKS_EletricidadeConstrucao.Constants.FUEL = {
    -- Update intervals
    UPDATE_INTERVAL = 1000,                     -- Fuel update interval in milliseconds (1 second)
    CHUNK_RELOAD_MIN_HOURS = 0.033,             -- Minimum time (2 minutes) before chunk reload catch-up
    
    -- Base consumption rates (per second as percentage of fuel tank)
    BASE_CONSUMPTION_RATE = 0.02,             -- Base fuel consumption per second (0.01% per second)
    CONSUMPTION_RATE_PER_CONSUMER_LPH = 0.004,  -- DEPRECATED: Use type-specific rates below
    -- Heating: quartered base rates (was 0.02 / 0.002) to reduce L/h cost
    CONSUMPTION_RATE_HEATING_PER_SOURCE_LPH = 0.002,     -- Fuel L/h per placed heat source at 20 C baseline
    CONSUMPTION_RATE_HEATING_PER_DEGREE_LPH = 0.00025,    -- Additional L/h per source per degree above 20 C (e.g. 30 C = +0.005 L/h per source)
    
    -- Idle consumption: running motor with no consumers (very small, matches vanilla idle)
    CONSUMPTION_IDLE_LPH = 0.002,              -- Generator idle L/h when running but nothing is powered

    -- Vanilla fuel consumption rates (L/h per active consumer) - matches vanilla PZ behavior
    CONSUMPTION_LIGHT_LPH = 0.002,              -- Standard lights and lamps
    CONSUMPTION_RADIO_LPH = 0.01,               -- Radio
    CONSUMPTION_TV_LPH = 0.03,                  -- Television
    CONSUMPTION_STOVE_LPH = 0.045,              -- Stove/oven
    CONSUMPTION_FRIDGE_LPH = 0.08,              -- Refrigerator (fridge only)
    CONSUMPTION_FREEZER_LPH = 0.08,             -- Freezer (freezer only)
    CONSUMPTION_FRIDGE_FREEZER_LPH = 0.13,      -- Combination fridge/freezer unit
    CONSUMPTION_WASHER_LPH = 0.09,              -- Washing machine
    CONSUMPTION_DRYER_LPH = 0.09,               -- Clothes dryer
    CONSUMPTION_MICROWAVE_LPH = 0.065,          -- Microwave (between stove and fridge)
    CONSUMPTION_APPLIANCE_DEFAULT_LPH = 0.04,   -- Default for unclassified appliances
    
    -- Power draw per consumer type (for strain calculation)
    POWER_DRAW_LIGHT = 1.5,                     -- Standard light (doubled for realistic strain)
    POWER_DRAW_LAMP = 1.5,                      -- Portable lamp
    POWER_DRAW_APPLIANCE = 8.0,                 -- Default for unclassified appliances
    
    -- Appliance-specific power draw (scaled to reflect electrical load)
    POWER_DRAW_RADIO = 8.0,                     -- Radio
    POWER_DRAW_TV = 12.0,                       -- Television
    POWER_DRAW_MICROWAVE = 14.0,                -- Microwave
    POWER_DRAW_STOVE = 21.0,                    -- Stove/oven
    POWER_DRAW_WASHER = 27.0,                   -- Washing machine
    POWER_DRAW_DRYER = 25.0,                    -- Clothes dryer
    POWER_DRAW_FRIDGE = 15.0,                   -- Refrigerator (fridge only)
    POWER_DRAW_FREEZER = 15.0,                  -- Freezer (freezer only)
    POWER_DRAW_FRIDGE_FREEZER = 20.0,           -- Combination fridge/freezer unit
    BASE_LOAD_CAPACITY = 120.0,                  -- One generator handles ~120 load before reaching 100% strain
    
    -- Strain system (tiered fuel consumption and damage)
    BASE_STRAIN_PER_LIGHT = 0.83333333333333,   -- DEPRECATED legacy mirror for BASE_LOAD_CAPACITY (100 / 120)
    STRAIN_MODIFIER = 0.01,                     -- [DEPRECATED] Use tiered system instead
    MAX_STRAIN_MULTIPLIER = 3.0,                -- Maximum 3x fuel consumption at 200% strain
    
    -- Strain thresholds (tiered system)
    -- 0-50%:   No extra fuel consumption (1.0x)
    -- 51-75%:  1.0x to 1.25x fuel (1-25% extra), no damage
    -- 76-100%: 1.26x to 1.75x fuel (26-75% extra), no damage
    -- 101-200%: 1.75x to 3.0x fuel + 1x-5x condition damage after 1hr grace + fail chance
    STRAIN_SAFE_ZONE = 50,                      -- No penalty below 50%
    STRAIN_THRESHOLD_LOW = 25,                  -- Low strain < 25%
    STRAIN_THRESHOLD_MEDIUM = 50,               -- Medium strain 25-50%
    STRAIN_THRESHOLD_HIGH = 75,                 -- High strain 50-75%
    OVERLOAD_THRESHOLD = 100,                   -- Overload >= 100%
    
    -- Efficiency system
    EFFICIENCY_LOSS_RATE = 0.5,                 -- Efficiency loss per % strain
    MIN_EFFICIENCY = 25,                        -- Minimum 25% efficiency
    
    -- Overload failure
    OVERLOAD_FAILURE_RATE = 0.01                -- 1% chance per % over 100%
}

LKS_EletricidadeConstrucao.Constants.GENERATOR_TYPES = {
    MODIFIERS = {
        appliances_misc_01_12 = { fuel = 0.95, strain = 1.00 },
        appliances_misc_01_8  = { fuel = 1.05, strain = 0.90 },
        appliances_misc_01_4  = { fuel = 1.20, strain = 0.80 },
    }
}

-- ============================================================================
-- BUILDING DETECTION
-- ============================================================================

LKS_EletricidadeConstrucao.Constants.BUILDING = {
    -- Scanning parameters
    MAX_SCAN_RADIUS = 100,                     -- Maximum tiles to scan from generator
    BORDER_DETECTION_RADIUS = 2,               -- Tiles around structure to check for consumers
    MAX_ROOMS_PER_BUILDING = 250,               -- Safety limit for room count
    
    -- Performance limits
    MAX_CONSUMERS_PER_BUILDING = 500,          -- Maximum powered items per building
    MAX_GENERATORS_PER_BUILDING = 10,          -- Maximum generators per building
    SCAN_THROTTLE_MS = 50,                     -- Max milliseconds per scan operation
    
    -- Z-level handling
    MIN_Z_LEVEL = 0,                           -- Ground level
    MAX_Z_LEVEL = 8,                           -- Maximum supported floor
    
    -- RV Interior mod compatibility
    RV_INTERIOR_MIN_COORD = -100000,           -- RV Interior starts at -100k
    RV_INTERIOR_MAX_COORD = 200000             -- Extended range for RV Interior
}

-- ============================================================================
-- UI CONFIGURATION
-- ============================================================================

LKS_EletricidadeConstrucao.Constants.UI = {
    -- Window dimensions
    INFO_WINDOW_WIDTH = 400,
    INFO_WINDOW_HEIGHT = 350,
    INFO_WINDOW_MIN_WIDTH = 300,
    INFO_WINDOW_MIN_HEIGHT = 250,
    
    -- Update frequencies
    UI_UPDATE_INTERVAL_MS = 100,               -- How often to refresh UI (milliseconds)
    REALTIME_LIGHT_UPDATE_MS = 100,            -- Real-time light count update interval
    
    -- Colors (RGB 0-1 range)
    COLOR_NORMAL = {r=1.0, g=1.0, b=1.0, a=1.0},
    COLOR_WARNING = {r=1.0, g=0.8, b=0.0, a=1.0},
    COLOR_CRITICAL = {r=1.0, g=0.2, b=0.0, a=1.0},
    COLOR_SUCCESS = {r=0.0, g=1.0, b=0.0, a=1.0},
    COLOR_DISABLED = {r=0.5, g=0.5, b=0.5, a=0.7}
}

-- ============================================================================
-- NETWORK SYNC (Multiplayer)
-- ============================================================================

LKS_EletricidadeConstrucao.Constants.NETWORK = {
    -- Module name for server commands
    MODULE_NAME = "LKS_EletricidadeConstrucao",
    
    -- Sync intervals (in game minutes)
    FULL_SYNC_INTERVAL = 30,                   -- Full state sync every 30 minutes
    DELTA_SYNC_INTERVAL = 1,                   -- Delta updates every minute
    
    -- Batch sizes (for performance)
    MAX_SYNC_BATCH_SIZE = 50,                  -- Max items per network packet
    SYNC_THROTTLE_MS = 100                     -- Delay between batch sends
}

-- ============================================================================
-- HEATING SYSTEM
-- ============================================================================

LKS_EletricidadeConstrucao.Constants.HEATING = {
    -- Temperature targets (Celsius)
    TARGET_TEMPERATURE = 18.0,                 -- Comfortable temperature
    MIN_TEMPERATURE = -10.0,                   -- Coldest outdoor temperature
    MAX_TEMPERATURE = 35.0,                    -- Hottest outdoor temperature
    
    -- Power consumption (per room per hour)
    HEATING_POWER_PER_ROOM = 0.5,              -- Base heating power cost
    
    -- Insulation factors
    INSULATION_NONE = 0.5,                     -- No insulation (50% efficiency)
    INSULATION_BASIC = 0.75,                   -- Basic walls (75% efficiency)
    INSULATION_GOOD = 1.0,                     -- Good insulation (100% efficiency)
    INSULATION_EXCELLENT = 1.25                -- Excellent insulation (125% efficiency)
}

-- ============================================================================
-- FILE SIZE GUIDELINES
-- ============================================================================

LKS_EletricidadeConstrucao.Constants.DEVELOPMENT = {
    -- Code quality guidelines (not enforced, just documentation)
    TARGET_FILE_SIZE_LINES = 300,              -- Target lines per file
    WARNING_FILE_SIZE_LINES = 400,             -- Review if exceeds this
    CRITICAL_FILE_SIZE_LINES = 500,            -- Strong indicator to split
    
    -- Performance budgets
    MAX_FRAME_TIME_MS = 1.0,                   -- Max time per operation
    MAX_SCAN_TIME_MS = 50.0                    -- Max time for building scan
}

-- ============================================================================
-- ITEM TYPES (for consumer detection)
-- ============================================================================

LKS_EletricidadeConstrucao.Constants.ITEM_TYPES = {
    -- Light sources
    LIGHTS = {
        "IsoLightSwitch"                       -- Standard light switches
        -- More added dynamically during scan
    },
    
    -- Appliances
    APPLIANCES = {
        "IsoStove",
        "IsoWaterDispenser",
        "IsoWaveSignal",
        "IsoRadio",
        "IsoTelevision",
        "(IsoClothingWasher|Dryer)",          -- Regex for washer/dryer variants
        "IsoClothingWasher",
        "IsoClothingDryer"
         -- More added dynamically during scan (fridges/freezers are detected by container type, not specific items)
    },
    
    -- Barrels
    BARRELS = {
        "BarrelGreen",
        "BarrelYard",
        "BarrelIndustrial"
    }
}

-- ============================================================================
-- DEBUG SETTINGS
-- ============================================================================

LKS_EletricidadeConstrucao.Constants.DEBUG = {
    -- Debug logging categories (can be toggled individually)
    LOG_FUEL_CONSUMPTION = false,
    LOG_BUILDING_SCAN = false,
    LOG_CHUNK_RELOAD = false,
    LOG_NETWORK_SYNC = false,
    LOG_UI_UPDATES = false,
    LOG_STATE_CHANGES = false,
    
    -- Debug visualization
    SHOW_COVERAGE_AREA = false,                -- Render green tiles for coverage
    SHOW_CHUNK_BOUNDARIES = false,             -- Render chunk grid
    SHOW_SCAN_RADIUS = false                   -- Render scan radius circles
}

-- ============================================================================
-- INITIALIZATION COMPLETE
-- ============================================================================

LKS_EletricidadeConstrucao._InitStatus.ConstantsLoaded = true
LKS_EletricidadeConstrucao.RegisterModule("Constants", "2.0.0")
LKS_EletricidadeConstrucao.Print(string.format("Constants loaded (%d categories)", 12))

return LKS_EletricidadeConstrucao.Constants
