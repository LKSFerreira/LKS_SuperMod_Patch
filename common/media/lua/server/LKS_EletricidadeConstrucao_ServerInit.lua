-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_ServerInit.lua
-- LKS_EletricidadeConstrucao V2 - Server Initialization
-- Loads and initializes all server-side modules
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_ServerInit] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

if LKS_EletricidadeConstrucao.Config and not LKS_EletricidadeConstrucao.Config.ModEnabled then
    print("[LKS_EletricidadeConstrucao_ServerInit] Eletricidade realista desativada no sandbox - pulando módulo")
    return
end

-- ============================================================================
-- LOAD SERVER MODULES
-- ============================================================================

-- Force-reload all server modules (they may have early-returned during
-- PZ's initial scan pass before shared/0_LKS_EletricidadeConstrucao_Init.lua had run).
-- Clearing package.loaded ensures require() re-executes each file.
local serverModules = {
    "server/fuel/LKS_EletricidadeConstrucao_Fuel_StrainCalculator",
    "server/fuel/LKS_EletricidadeConstrucao_Fuel_Manager",
    "server/fuel/LKS_EletricidadeConstrucao_Fuel_ChunkTracker",
    "server/building/LKS_EletricidadeConstrucao_Building_BorderDetector",
    "server/building/LKS_EletricidadeConstrucao_Building_ConsumerScanner",
    "server/building/LKS_EletricidadeConstrucao_Building_Scanner",
    "server/power/LKS_EletricidadeConstrucao_Power_Manager",
    "server/power/LKS_EletricidadeConstrucao_Power_Distributor",
    "server/LKS_EletricidadeConstrucao_ServerCommands",
}

if not LKS_EletricidadeConstrucao.Config or LKS_EletricidadeConstrucao.Config.HeatingSystemEnabled then
    table.insert(serverModules, "server/heating/LKS_EletricidadeConstrucao_Heating_Manager")
end

if not LKS_EletricidadeConstrucao.Config or LKS_EletricidadeConstrucao.Config.BarrelSystemEnabled then
    table.insert(serverModules, "server/fuel/LKS_EletricidadeConstrucao_Fuel_Barrels")
end

if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
    table.insert(serverModules, "server/LKS_EletricidadeConstrucao_DebugCommands")
end

for _, mod in ipairs(serverModules) do
    if package and package.loaded then
        package.loaded[mod] = nil
    end
    local ok, err = pcall(require, mod)
    if not ok then
        print(string.format("[LKS_EletricidadeConstrucao_ServerInit] ERROR loading %s: %s", mod, tostring(err)))
    end
end

-- TODO: Load other server modules
-- require "server/heating/LKS_EletricidadeConstrucao_Heating_Manager"

-- ============================================================================
-- INITIALIZE SERVER SYSTEMS
-- ============================================================================

--- Initialize all server systems
local function InitializeServerSystems()
    LKS_EletricidadeConstrucao.Core.Logger.Info("Initializing server systems...", "Core")
    
    -- Initialize state manager (loads ModData)
    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
        if not LKS_EletricidadeConstrucao.Core.StateManager.IsInitialized() then
            LKS_EletricidadeConstrucao.Core.StateManager.Initialize()
        end
    else
        print("[LKS_EletricidadeConstrucao_ServerInit] WARNING: StateManager not loaded")
    end
    
    -- Initialize fuel system
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and LKS_EletricidadeConstrucao.Fuel.Manager.Initialize then
        LKS_EletricidadeConstrucao.Fuel.Manager.Initialize()
    else
        print("[LKS_EletricidadeConstrucao_ServerInit] WARNING: Fuel.Manager not loaded")
    end
    
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.ChunkTracker and LKS_EletricidadeConstrucao.Fuel.ChunkTracker.Initialize then
        LKS_EletricidadeConstrucao.Fuel.ChunkTracker.Initialize()
    else
        print("[LKS_EletricidadeConstrucao_ServerInit] WARNING: Fuel.ChunkTracker not loaded")
    end
    
    -- Initialize building detection
    if LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner and LKS_EletricidadeConstrucao.Building.Scanner.Initialize then
        LKS_EletricidadeConstrucao.Building.Scanner.Initialize()
    else
        print("[LKS_EletricidadeConstrucao_ServerInit] WARNING: Building.Scanner not loaded")
    end
    
    -- Initialize power distribution
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager and LKS_EletricidadeConstrucao.Power.Manager.Initialize then
        LKS_EletricidadeConstrucao.Power.Manager.Initialize()
    else
        print("[LKS_EletricidadeConstrucao_ServerInit] WARNING: Power.Manager not loaded")
    end
    
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.Initialize then
        LKS_EletricidadeConstrucao.Power.Distributor.Initialize()
    else
        print("[LKS_EletricidadeConstrucao_ServerInit] WARNING: Power.Distributor not loaded")
    end
    
    -- TODO: Initialize other server systems
    -- LKS_EletricidadeConstrucao.Heating.Manager.Initialize()
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Server systems initialized", "Core")
    LKS_EletricidadeConstrucao._InitStatus.ServerSystemsInitialized = true
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--- Handle OnGameBoot event (called once when server starts)
local function OnGameBoot()
    LKS_EletricidadeConstrucao.Core.Logger.Info("Server booting...", "Core")
    
    -- Initialize systems
    InitializeServerSystems()

    -- Immediately refresh distribution stats so client UI has data on first open
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
        LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Server boot complete", "Core")
end

--- Handle EveryOneMinute event (periodic updates)
local function EveryOneMinute()
    -- Safety check: ensure systems are initialized before running updates
    if not LKS_EletricidadeConstrucao._InitStatus or not LKS_EletricidadeConstrucao._InitStatus.ServerSystemsInitialized then
        return
    end

    local currentTime = os.time()

    -- Confirm world ID and load GlobalModData if still pending from boot.
    -- ConfirmAndLoadState() is a no-op (returns false) after the first success,
    -- so this block has zero overhead in normal steady-state operation.
    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
            and LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState then
        if LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState() then
            -- First confirmed load just completed - force distribution so the UI
            -- reflects the now-correct state immediately.
            if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
                    and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
            end
        end
    end

    -- Auto-refuel generators from linked barrels BEFORE fuel drain.
    -- Must run first so barrels top up generators before the drain tick
    -- calculates how much fuel was consumed.
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels and LKS_EletricidadeConstrucao.Fuel.Barrels.UpdateAll then
        LKS_EletricidadeConstrucao.Fuel.Barrels.UpdateAll()
    end

    -- Update fuel system (drain after barrel refuel)
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and LKS_EletricidadeConstrucao.Fuel.Manager.Update then
        LKS_EletricidadeConstrucao.Fuel.Manager.Update()
    end
    
    -- Process building scan queue
    if LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner and LKS_EletricidadeConstrucao.Building.Scanner.ProcessQueue then
        LKS_EletricidadeConstrucao.Building.Scanner.ProcessQueue()
    end
    
    -- Update power connections (finds generators, validates connections)
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager and LKS_EletricidadeConstrucao.Power.Manager.Update then
        LKS_EletricidadeConstrucao.Power.Manager.Update(currentTime)
    end
    
    -- Update power distribution (applies power states to consumers)
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.Update then
        LKS_EletricidadeConstrucao.Power.Distributor.Update(currentTime)
    end

    -- Retry any ForceUpdateBuilding calls that failed because the building was not
    -- yet in StateManager (e.g. right after teleporting close to a building).
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.ProcessRetryQueue then
        LKS_EletricidadeConstrucao.Power.Distributor.ProcessRetryQueue()
    end

    -- Update heating positions
    if LKS_EletricidadeConstrucao.Heating and LKS_EletricidadeConstrucao.Heating.Manager and LKS_EletricidadeConstrucao.Heating.Manager.Update then
        LKS_EletricidadeConstrucao.Heating.Manager.Update()
    end
end

--- Handle EveryTenMinutes event (auto-save with 2-minute interval)
local _lastAutoSave = 0
local function EveryTenMinutes()
    local currentTime = os.time()
    
    -- Auto-save every 2 minutes (120 seconds) instead of every minute
    -- Reduces save frequency from 60/hour to 30/hour (-50%)
    if currentTime - _lastAutoSave >= 120 then
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
            if LKS_EletricidadeConstrucao.Core.StateManager.IsDirty and LKS_EletricidadeConstrucao.Core.StateManager.IsDirty() then
                -- Auto-saves without backup (frequent, low importance)
                -- OnSave and OnServerShutdown still create backups
                if LKS_EletricidadeConstrucao.Core.StateManager.Save then
                    LKS_EletricidadeConstrucao.Core.StateManager.Save(false, false)
                end
                _lastAutoSave = currentTime
            end
        end
    end
end

--- Handle OnServerShutdown event
local function OnServerShutdown()
    LKS_EletricidadeConstrucao.Core.Logger.Info("Server shutting down - saving state...", "Core")
    
    -- Force save state WITH backup (critical save)
    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager and LKS_EletricidadeConstrucao.Core.StateManager.Save then
        LKS_EletricidadeConstrucao.Core.StateManager.Save(true, true)
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Server shutdown complete", "Core")
end

--- Handle OnSave event (backup-protected save)
local function OnSave()
    -- OnSave fires every ~5 minutes - these saves get backup protection
    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager and LKS_EletricidadeConstrucao.Core.StateManager.Save then
        LKS_EletricidadeConstrucao.Core.StateManager.Save(true, true)
        LKS_EletricidadeConstrucao.Core.Logger.Debug("OnSave: State saved with backup", "Core")
    end
end

-- ============================================================================
-- REGISTER EVENT HANDLERS
-- ============================================================================

-- Register events safely (only events that exist in both SP and dedicated server)
if Events.OnGameBoot then Events.OnGameBoot.Add(OnGameBoot) end
if Events.EveryOneMinute then Events.EveryOneMinute.Add(EveryOneMinute) end
if Events.EveryTenMinutes then Events.EveryTenMinutes.Add(EveryTenMinutes) end
if Events.OnServerShutdown then Events.OnServerShutdown.Add(OnServerShutdown) end
-- OnSave fires immediately before PZ serializes GlobalModData (SP + MP).
-- This ensures LKS_EletricidadeConstrucao state is flushed even if the session ends
-- before the first EveryOneMinute tick and OnServerShutdown is absent.
if Events.OnSave then Events.OnSave.Add(OnSave) end
-- NOTE: OnObjectAdded / OnObjectAboutToBeRemoved are registered in
--       shared/LKS_EletricidadeConstrucao_Shared_ConsumerEvents.lua so they fire in the client Lua
--       context (where PZ actually dispatches these events in singleplayer).

-- Also register OnGameStart for singleplayer (OnGameBoot may not fire in SP)
if Events.OnGameStart then
    Events.OnGameStart.Add(function()
        if not LKS_EletricidadeConstrucao._InitStatus.ServerSystemsInitialized then
            LKS_EletricidadeConstrucao.Core.Logger.Info("OnGameStart - initializing server systems...", "Core")
            InitializeServerSystems()
        end

        -- OnGameBoot booted with empty state because getWorld() was unavailable.
        -- Try to confirm and load now; if the world ID is still unavailable,
        -- EveryOneMinute will keep retrying once a minute until it succeeds.
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                and LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState then
            local loaded = LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState()
            if loaded then
                -- Load completed immediately (world was ready at OnGameStart).
                if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
                        and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
                    LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
                end
            end
        end

        -- Schedule deferred ForceUpdates after game start so consumer active
        -- states are refreshed once the world has settled.
        --   Pass 1 at  5 s: catches nearby buildings (player spawn area).
        --   Pass 2 at 15 s: catches buildings whose chunks loaded a bit later
        --                   (e.g. player walked toward their base during load).
        local _t1 = getTimestampMs() + 5000
        local _t2 = getTimestampMs() + 15000
        local _pass1done = false
        local function _startupRefresh()
            local now = getTimestampMs()
            if not _pass1done and now >= _t1 then
                _pass1done = true
                if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
                    LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
                    LKS_EletricidadeConstrucao.Core.Logger.Info("Startup consumer state refresh (pass 1) complete", "Core")
                end
            end
            if _pass1done and now >= _t2 then
                Events.OnTick.Remove(_startupRefresh)
                if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
                    LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
                    LKS_EletricidadeConstrucao.Core.Logger.Info("Startup consumer state refresh (pass 2) complete", "Core")
                end
            end
        end
        Events.OnTick.Add(_startupRefresh)
    end)
end

LKS_EletricidadeConstrucao.Core.Logger.Info("Server event handlers registered", "Core")

-- ============================================================================
-- INITIALIZATION COMPLETE
-- ============================================================================

LKS_EletricidadeConstrucao._InitStatus.ServerModulesLoaded = true

print("[LKS_EletricidadeConstrucao_ServerInit] Server initialization complete")

return true
