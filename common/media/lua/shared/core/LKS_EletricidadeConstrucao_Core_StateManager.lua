-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Core_StateManager.lua
-- LKS_EletricidadeConstrucao V2 - State Manager
-- Central interface for ModData persistence and state management
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Core_StateManager] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- MODDATA KEYS
-- ============================================================================

local MODDATA_KEY = "LKS_EletricidadeConstrucaoV2"
local MODDATA_KEY_BACKUP = "LKS_EletricidadeConstrucaoV2_Backup"
local MODDATA_KEY_GEN_INDEX = "LKS_EletricidadeConstrucaoV2_GeneratorIndex"

local function NormalizeWorldId(value)
    if value == nil then return nil end

    value = tostring(value)
    if value == "" or value == "nil" then
        return nil
    end

    return value
end

-- Per-save guard: detect cross-save contamination when users hop between worlds.
-- Returns "unknown" when called too early in the boot sequence (getWorld not ready).
local function GetWorldId()
    -- Try getWorld() first (available once the world is loaded)
    local world = getWorld and getWorld()
    if world then
        if world.getWorldName then
            local name = NormalizeWorldId(world:getWorldName())
            if name then return name end
        end
        -- fallback: some PZ versions expose getDir()
        if world.getDir then
            local d = NormalizeWorldId(world:getDir())
            if d then return d end
        end
    end
    -- Dedicated servers can expose the active save slot through getServerName()
    -- even when getWorld():getWorldName() is empty.
    if getServerName then
        local serverName = NormalizeWorldId(getServerName())
        if serverName then return serverName end
    end
    -- GameTime is available earlier than getWorld() – use world age as a
    -- tiebreaker only if nothing else worked.
    return "unknown"   -- genuinely too early; caller must skip world-isolation check
end

-- Tracks the global-data load lifecycle for this session.
--   "pending"  → Initialize() ran but GlobalModData not yet read (world ID unknown).
--   "loaded"   → ConfirmAndLoadState() completed a world-verified load.
--   "fresh"    → ConfirmAndLoadState() detected a world mismatch and cleared data.
-- Save() guards against writing back while "pending" to prevent overwriting the
-- saved state with an empty snapshot before the real data has been loaded.
local _dataLoadState = "pending"

-- Legacy alias kept so Load() still compiles; not used by the new boot path.
local _loadedWithUnknownWorldId = false

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local _state = nil  -- Current runtime state
local _isDirty = false  -- Tracks if state needs saving
local _initialized = false  -- Tracks initialization status
local _genIndexCache = nil -- Cached reference to generator ModData index

-- ============================================================================
-- INTERNAL HELPERS
-- ============================================================================

-- Get or create the generator ModData index blob.
local function GetGeneratorIndex()
    if not _genIndexCache then
        _genIndexCache = ModData.getOrCreate(MODDATA_KEY_GEN_INDEX)
    end

    _genIndexCache.generators = _genIndexCache.generators or {}
    _genIndexCache.chunkIndex = _genIndexCache.chunkIndex or {}

    return _genIndexCache
end

-- Count generators in current runtime state.
local function CountGenerators()
    local count = 0
    if not _state or not _state.generators then return 0 end
    for _ in pairs(_state.generators) do
        count = count + 1
    end
    return count
end

-- Count buildings in current runtime state.
local function CountBuildings()
    local count = 0
    if not _state or not _state.buildings then return 0 end
    for _ in pairs(_state.buildings) do
        count = count + 1
    end
    return count
end

-- Add a generator to the ModData index for fast rehydration and chunk lookup.
local function IndexAddGenerator(genData)
    if not genData or not genData.id then return end
    local Geometry = LKS_EletricidadeConstrucao.Utils and LKS_EletricidadeConstrucao.Utils.Geometry
    if (not genData.chunkKey or genData.chunkKey == "") and Geometry then
        genData.chunkKey = Geometry.GetChunkKey(genData.x, genData.y)
    end

    local index = GetGeneratorIndex()
    index.generators[genData.id] = LKS_EletricidadeConstrucao.Data.Generator.Serialize(genData)

    if genData.chunkKey then
        index.chunkIndex[genData.chunkKey] = index.chunkIndex[genData.chunkKey] or {}
        local list = index.chunkIndex[genData.chunkKey]
        local exists = false
        for _, gid in ipairs(list) do
            if gid == genData.id then exists = true; break end
        end
        if not exists then
            table.insert(list, genData.id)
        end
    end
end

-- Remove a generator from the ModData index.
local function IndexRemoveGenerator(generatorId, chunkKey)
    if not generatorId then return end
    local index = GetGeneratorIndex()
    index.generators[generatorId] = nil

    if chunkKey and index.chunkIndex[chunkKey] then
        local list = index.chunkIndex[chunkKey]
        for i = #list, 1, -1 do
            if list[i] == generatorId then
                table.remove(list, i)
            end
        end
        if #list == 0 then
            index.chunkIndex[chunkKey] = nil
        end
    end
end

-- Attempt to rebuild runtime state generators from the ModData index blob.
local function HydrateGeneratorsFromIndex()
    local index = ModData.get(MODDATA_KEY_GEN_INDEX)
    if not index or not index.generators then
        return 0
    end

    if not _state then
        _state = LKS_EletricidadeConstrucao.Data.State.New()
    end

    local restored = 0
    for genId, serialized in pairs(index.generators) do
        local genData = LKS_EletricidadeConstrucao.Data.Generator.Deserialize(serialized)
        if genData then
            LKS_EletricidadeConstrucao.Data.State.AddGenerator(_state, genData)
            restored = restored + 1
        end
    end

    if restored > 0 then
        _isDirty = true
        LKS_EletricidadeConstrucao.Print(string.format("[StateManager] Restored %d generator(s) from ModData index", restored))
    end

    return restored
end

-- ============================================================================
-- DUPLICATE BUILDING PURGE
-- ============================================================================

--- Remove stale duplicate building entries that share coordinates with a canonical
--- bld_X_Y_Z entry (legacy bld_def_... IDs created by TryRestoreFromIsoModData).
--- For each duplicated location:
---   1. The canonical (non-bld_def_) building is kept.
---   2. The stale building's connectedGenerators are merged into the canonical one.
---   3. Every generator whose connectedBuildings listed the stale ID is updated to
---      point at the canonical ID instead.
---   4. The stale building entry is removed from state.
--- Returns the number of stale entries purged.
local function PurgeDuplicateBuildings()
    if not _state then return 0 end
    local SM = LKS_EletricidadeConstrucao.Core.StateManager
    local allBlds = LKS_EletricidadeConstrucao.Data.State.GetAllBuildings(_state)
    if not allBlds then return 0 end

    -- Group building IDs by "x_y_z" coordinate key
    local byLoc = {}  -- locKey -> {canonical=id, stales={id,...}}
    for bid, bd in pairs(allBlds) do
        local locKey = (bd.x or 0) .. "_" .. (bd.y or 0) .. "_" .. (bd.z or 0)
        if not byLoc[locKey] then
            byLoc[locKey] = { canonical = nil, stales = {} }
        end
        -- A canonical ID matches the bld_X_Y_Z pattern (no "def")
        if bid:match("^bld_%d+_%d+_%d+$") then
            byLoc[locKey].canonical = bid
        else
            table.insert(byLoc[locKey].stales, bid)
        end
    end

    local purged = 0
    for locKey, entry in pairs(byLoc) do
        if entry.canonical and #entry.stales > 0 then
            local canonBd = allBlds[entry.canonical]
            for _, staleId in ipairs(entry.stales) do
                local staleBd = allBlds[staleId]
                if staleBd then
                    -- Merge connectedGenerators from stale into canonical.
                    -- Use pairs() not ipairs(): after GlobalModData deserialization in
                    -- Kahlua (PZ's Lua VM) array-style tables may have string numeric
                    -- keys, making ipairs() return nothing and silently losing data.
                    if staleBd.connectedGenerators then
                        canonBd.connectedGenerators = canonBd.connectedGenerators or {}
                        local cgSet = {}
                        for _, gk in pairs(canonBd.connectedGenerators) do cgSet[gk] = true end
                        for _, gk in pairs(staleBd.connectedGenerators) do
                            if not cgSet[gk] then
                                table.insert(canonBd.connectedGenerators, gk)
                                cgSet[gk] = true
                            end
                        end
                    end
                    -- Merge heatingSourceCount if canonical has none
                    if (not canonBd.heatingSourceCount or canonBd.heatingSourceCount == 0)
                        and staleBd.heatingSourceCount and staleBd.heatingSourceCount > 0 then
                        canonBd.heatingEnabled      = staleBd.heatingEnabled
                        canonBd.heatingSourceCount  = staleBd.heatingSourceCount
                        canonBd.heatingTargetTemp   = staleBd.heatingTargetTemp
                    end
                end
                -- Rewrite all generator connectedBuildings: stale -> canonical.
                -- Combined with dedup in a single pass to avoid a second full scan.
                -- Uses pairs() for safe iteration over deserialized Kahlua tables,
                -- and rebuilds a clean Lua array regardless of the input key type.
                -- CRITICAL: must NOT run on generators unrelated to this duplicate —
                -- only rewrite entries that actually contain the stale ID.
                local allGens = LKS_EletricidadeConstrucao.Data.State.GetAllGenerators(_state)
                if allGens then
                    for _, gd in pairs(allGens) do
                        if gd.connectedBuildings then
                            local needRebuild = false
                            -- Check whether this generator references the stale ID at all
                            for _, bid in pairs(gd.connectedBuildings) do
                                if bid == staleId then needRebuild = true; break end
                            end
                            if needRebuild then
                                local seen = {}
                                local rebuilt = {}
                                for _, bid in pairs(gd.connectedBuildings) do
                                    local effective = (bid == staleId) and entry.canonical or bid
                                    if not seen[effective] then
                                        seen[effective] = true
                                        table.insert(rebuilt, effective)
                                        if bid == staleId then
                                            LKS_EletricidadeConstrucao.Print(string.format(
                                                "[StateManager.Purge] gen=%s connectedBuildings: %s -> %s",
                                                gd.id or "?", staleId, entry.canonical))
                                        end
                                    end
                                end
                                gd.connectedBuildings = rebuilt
                                -- Stamp canonical Gen_BuildingPoolID on the IsoObject so that
                                -- scanAllGenerators() in the UI finds the correct pool after purge.
                                -- Without this, generators that referenced the stale bld_def_... ID
                                -- keep it on their IsoObject permanently, causing the UI pool count
                                -- to flip 3 -> 1 when the info window refreshes. (B-70)
                                if gd.x and gd.y and gd.z then
                                    local cell = getCell and getCell()
                                    if cell then
                                        local sq = cell:getGridSquare(gd.x, gd.y, gd.z)
                                        if sq then
                                            local objs = sq:getObjects()
                                            for oi = 0, objs:size() - 1 do
                                                local obj = objs:get(oi)
                                                if obj and instanceof(obj, "IsoGenerator") then
                                                    local md = obj:getModData()
                                                    if md then
                                                        md.Gen_BuildingPoolID = entry.canonical
                                                        if obj.transmitModData then
                                                            obj:transmitModData()
                                                        end
                                                        LKS_EletricidadeConstrucao.Print(string.format(
                                                            "[StateManager.Purge] IsoObject gen=%s Gen_BuildingPoolID -> %s",
                                                            gd.id or "?", entry.canonical))
                                                    end
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                -- Remove the stale building entry
                LKS_EletricidadeConstrucao.Data.State.RemoveBuilding(_state, staleId)
                LKS_EletricidadeConstrucao.Print(string.format(
                    "[StateManager.Purge] Removed stale building %s (dup of %s at %s)",
                    staleId, entry.canonical, locKey))
                purged = purged + 1
            end
        end
    end

    if purged > 0 then
        _isDirty = true
    end
    return purged
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize state manager
--- @return boolean True if successful
function LKS_EletricidadeConstrucao.Core.StateManager.Initialize()
    if _initialized then
        LKS_EletricidadeConstrucao.Warn("[StateManager.Initialize] Already initialized")
        return true
    end

    -- Boot with completely empty state.  GetWorldId() returns "unknown" during
    -- OnGameBoot, so reading GlobalModData here is unsafe: we cannot verify
    -- world isolation and would load stale data from the previous save.
    -- ConfirmAndLoadState() will do the real load once GetWorldId() is valid.
    _state         = LKS_EletricidadeConstrucao.Data.State.New()
    _isDirty       = false
    _initialized   = true
    _dataLoadState = "pending"

    LKS_EletricidadeConstrucao.Print("[StateManager.Initialize] State manager ready (world confirmation pending)")
    return true
end

--- Check if state manager is initialized
--- @return boolean True if initialized
function LKS_EletricidadeConstrucao.Core.StateManager.IsInitialized()
    return _initialized
end

--- Expose the current world ID for other modules (Distributor, ChunkTracker, actions).
--- Returns "unknown" when the world is not yet available (early boot).
function LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId()
    return GetWorldId()
end

-- ============================================================================
-- MODDATA OPERATIONS
-- ============================================================================

--- Load state from ModData
--- @return boolean True if loaded successfully
function LKS_EletricidadeConstrucao.Core.StateManager.Load()
    local Runtime = LKS_EletricidadeConstrucao.Core.Runtime
    
    -- Get ModData (server-side or singleplayer)
    local modData = nil
    -- In singleplayer, isServer() is false even in the server Lua state, so allow
    -- loads when the game mode is not multiplayer. Block only true MP clients.
    if Runtime.IsMultiplayerClient and Runtime.IsMultiplayerClient() then
        LKS_EletricidadeConstrucao.Warn("[StateManager.Load] Multiplayer client cannot load directly, waiting for sync")
        return false
    end

    modData = ModData.getOrCreate(MODDATA_KEY)

    -- World-isolation check: if ModData belongs to a different save, discard it.
    -- IMPORTANT: only wipe when both IDs are known. During OnGameBoot, getWorld()
    -- is not yet available so GetWorldId() returns "unknown" -- we must NOT treat
    -- that as a mismatch or we destroy the state on every normal game restart.
    local currentWorldId = GetWorldId()
    local storedWorldId = modData.worldId
    if currentWorldId == "unknown" then
        -- World not fully initialised yet; skip the guard and remember to re-check
        -- once OnGameStart fires and getWorld() is available.
        _loadedWithUnknownWorldId = true
        LKS_EletricidadeConstrucao.Print("[StateManager.Load] World ID not available yet (early boot) - skipping isolation check")
    elseif storedWorldId and storedWorldId ~= currentWorldId then
        LKS_EletricidadeConstrucao.Warn(string.format("[StateManager.Load] Detected world mismatch (stored=%s, current=%s) - resetting LKS_EletricidadeConstrucao state for this save", tostring(storedWorldId), tostring(currentWorldId)))
        modData.state = nil
        modData.worldId = currentWorldId
        -- Clear generator index to avoid leaking pool links across saves
        local idx = ModData.getOrCreate(MODDATA_KEY_GEN_INDEX)
        idx.generators = {}
        idx.chunkIndex = {}
        _loadedWithUnknownWorldId = false
        return false
    else
        _loadedWithUnknownWorldId = false
    end
    
    if not modData or not modData.state then
        -- Main state blob is nil (e.g. PZ failed to persist it across game exit).
        -- The backup key is written first in Save() so it often survives when the
        -- main key doesn't.  Try it before giving up entirely.
        local backup = ModData.get(MODDATA_KEY_BACKUP)
        if backup and backup.state then
            LKS_EletricidadeConstrucao.Warn("[StateManager.Load] Main state missing – attempting restore from backup")
            local backupDeserialized = LKS_EletricidadeConstrucao.Data.State.Deserialize(backup.state)
            if backupDeserialized then
                _state = backupDeserialized
                if currentWorldId ~= "unknown" then
                    modData.worldId = currentWorldId
                end
                -- Mark dirty so the next Save() repopulates the main key from
                -- the restored state, closing the window where main is still nil.
                _isDirty = true
                LKS_EletricidadeConstrucao.Warn("[StateManager.Load] State restored from backup successfully")
                return true
            end
            LKS_EletricidadeConstrucao.Warn("[StateManager.Load] Backup deserialization failed")
        end
        LKS_EletricidadeConstrucao.Print("[StateManager.Load] No saved state found")
        return false
    end
    
    -- Deserialize state
    local deserialized = LKS_EletricidadeConstrucao.Data.State.Deserialize(modData.state)
    
    if not deserialized then
        LKS_EletricidadeConstrucao.Error("[StateManager.Load] Failed to deserialize state")
        
        -- Try backup
        local backup = ModData.get(MODDATA_KEY_BACKUP)
        if backup and backup.state then
            LKS_EletricidadeConstrucao.Warn("[StateManager.Load] Attempting to restore from backup")
            deserialized = LKS_EletricidadeConstrucao.Data.State.Deserialize(backup.state)
        end
        
        if not deserialized then
            return false
        end
    end
    
    _state = deserialized
    -- Only stamp worldId if we actually know it; leave the stored value intact
    -- when getWorld() wasn't ready so a later reload can verify it properly.
    if currentWorldId ~= "unknown" then
        modData.worldId = currentWorldId
    end
    _isDirty = false
    
    LKS_EletricidadeConstrucao.Print("[StateManager.Load] State loaded successfully")
    return true
end

--- Confirm the current world ID and load GlobalModData into state.
--- Call this from OnGameStart and EveryOneMinute until it returns true.
--- Fires exactly once per session; subsequent calls are no-ops (return false).
--- Returns true the first time the load (or fresh-world wipe) completes.
function LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState()
    if _dataLoadState ~= "pending" then return false end

    local currentWorldId = GetWorldId()
    if currentWorldId == "unknown" then
        LKS_EletricidadeConstrucao.Debug("[StateManager.ConfirmAndLoadState] World ID still unavailable, retrying later")
        return false
    end

    LKS_EletricidadeConstrucao.Print("[StateManager.ConfirmAndLoadState] World confirmed (" .. currentWorldId .. ") - loading state")

    -- ConfirmAndLoadState is the only caller of Load() in the new boot path.
    -- getWorld() is ready now, so the isolation check inside Load() works correctly.
    local loaded = LKS_EletricidadeConstrucao.Core.StateManager.Load()

    if not loaded then
        -- No data or world-mismatch wipe (Load() cleared GlobalModData internally).
        LKS_EletricidadeConstrucao.Print("[StateManager.ConfirmAndLoadState] No state loaded - starting fresh for this world")
        _state = LKS_EletricidadeConstrucao.Data.State.New()
        _isDirty = true
        _dataLoadState = "fresh"
    else
        -- Hydrate from generator index if the state blob had no generators.
        if CountGenerators() == 0 then
            local restored = HydrateGeneratorsFromIndex()
            if restored > 0 then
                LKS_EletricidadeConstrucao.Print(string.format(
                    "[StateManager.ConfirmAndLoadState] Hydrated %d generator(s) from index", restored))
            end
        end
        -- Option A (B-99): PurgeDuplicateBuildings() removed.  powerConsumers is
        -- never saved so stale duplicates cannot accumulate across saves.  Legacy
        -- bld_def_ ID migration is handled per-generator in TryRestoreFromIsoModData.
        _dataLoadState = "loaded"
    end

    LKS_EletricidadeConstrucao.Print(string.format(
        "[StateManager.ConfirmAndLoadState] Complete: %d generator(s), %d building(s), state=%s",
        CountGenerators(), CountBuildings(), _dataLoadState))
    LKS_EletricidadeConstrucao.Debug("[StateManager] " .. LKS_EletricidadeConstrucao.Data.State.GetSummary(_state))

    -- Trigger startup generator refresh: scans squares of generators already in
    -- state so their buildings are populated before the player walks to them.
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.ChunkTracker
            and LKS_EletricidadeConstrucao.Fuel.ChunkTracker.HandleStartupGeneratorRefresh then
        LKS_EletricidadeConstrucao.Fuel.ChunkTracker.HandleStartupGeneratorRefresh()
    end

    return true
end

--- Legacy alias kept for backward compatibility.
--- Forwards to ConfirmAndLoadState(); old callers continue to work unchanged.
function LKS_EletricidadeConstrucao.Core.StateManager.ReloadIfWorldWasUnknown()
    return LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState()
end

--- Return true when the world-verified state load has completed for this session.
function LKS_EletricidadeConstrucao.Core.StateManager.IsStateLoaded()
    return _dataLoadState ~= "pending"
end

--- Save state to ModData
--- @param force boolean Force save even if not dirty
--- @param createBackup boolean Create backup before saving (default: true)
--- @return boolean True if saved successfully
function LKS_EletricidadeConstrucao.Core.StateManager.Save(force, createBackup)
    local Runtime = LKS_EletricidadeConstrucao.Core.Runtime
    
    if not _initialized then
        LKS_EletricidadeConstrucao.Error("[StateManager.Save] Not initialized")
        return false
    end

    -- Guard: never write back while state is still pending world confirmation.
    -- An early-boot Save() (e.g. from OnSave firing before ConfirmAndLoadState)
    -- would overwrite GlobalModData with an empty snapshot, destroying the saved
    -- consumer/heating data for the current save.
    if _dataLoadState == "pending" then
        LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState()
    end
    if _dataLoadState == "pending" then
        LKS_EletricidadeConstrucao.Warn("[StateManager.Save] World confirmation still pending - skipping save to prevent data loss")
        return false
    end

    if not _isDirty and not force then
        LKS_EletricidadeConstrucao.Debug("[StateManager.Save] State is clean, skipping save")
        return true
    end
    
    -- In PZ singleplayer, isServer() returns false even in the server Lua state.
    -- Allow saves if: dedicated server (isServer()=true) OR singleplayer (SP host).
    -- Block ONLY on a true multiplayer client.
    if not Runtime.IsServer() and not Runtime.IsSingleplayer() then
        LKS_EletricidadeConstrucao.Warn("[StateManager.Save] Only server can save state")
        return false
    end
    
    if not _state then
        LKS_EletricidadeConstrucao.Error("[StateManager.Save] No state to save")
        return false
    end
    
    -- Update statistics before saving
    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(_state)
    
    -- Serialize state
    local serialized = LKS_EletricidadeConstrucao.Data.State.Serialize(_state)
    
    -- Create backup of current state (default: true, can be disabled for frequent auto-saves)
    if createBackup == nil then createBackup = true end
    if createBackup then
        local currentModData = ModData.get(MODDATA_KEY)
        if currentModData and currentModData.state then
            local backupData = ModData.getOrCreate(MODDATA_KEY_BACKUP)
            backupData.state = currentModData.state
        end
    end
    
    -- Save new state
    local modData = ModData.getOrCreate(MODDATA_KEY)
    modData.state = serialized
    -- Only write worldId when getWorld() is available; don't overwrite a correct
    -- world name with "unknown" from an early-boot Save() call.
    local wid = GetWorldId()
    if wid ~= "unknown" then
        modData.worldId = wid
    end

    -- Option A (B-99): LKS_EletricidadeConstrucao_PoolData IsoObject writes removed.  Building geometry
    -- (boundingBox, borderRadius, isRVInterior, light-switch coords) is derived
    -- fresh on every chunk load by ScanBuilding.  The secondary IsoObject storage
    -- was the original source of the bld_def_ / stale-consumer drift bugs.

    _isDirty = false

    LKS_EletricidadeConstrucao.Debug("[StateManager.Save] State saved successfully" .. (createBackup and " (with backup)" or " (no backup)"))
    return true
end

--- Mark state as dirty (needs saving)
function LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    _isDirty = true
end

--- Check if state is dirty
--- @return boolean True if dirty
function LKS_EletricidadeConstrucao.Core.StateManager.IsDirty()
    return _isDirty
end

-- ============================================================================
-- STATE ACCESS
-- ============================================================================

--- Get current state
--- @return StateData|nil Current state or nil if not initialized
function LKS_EletricidadeConstrucao.Core.StateManager.GetState()
    if not _initialized then
        LKS_EletricidadeConstrucao.Error("[StateManager.GetState] Not initialized")
        return nil
    end
    
    return _state
end

--- Get state configuration
--- @return table Configuration table
function LKS_EletricidadeConstrucao.Core.StateManager.GetConfig()
    if not _state then
        return {}
    end
    
    return _state.config
end

--- Update state configuration
--- @param config table New configuration
function LKS_EletricidadeConstrucao.Core.StateManager.SetConfig(config)
    if not _state then
        LKS_EletricidadeConstrucao.Error("[StateManager.SetConfig] No state")
        return
    end
    
    _state.config = config
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
end

-- ============================================================================
-- GENERATOR OPERATIONS
-- ============================================================================

--- Add or update generator
--- @param generatorData GeneratorData Generator data to add
function LKS_EletricidadeConstrucao.Core.StateManager.AddGenerator(generatorData)
    if not _state then
        LKS_EletricidadeConstrucao.Error("[StateManager.AddGenerator] No state")
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.AddGenerator(_state, generatorData)
    IndexAddGenerator(generatorData)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Debug("[StateManager] Added generator: " .. generatorData.id)
end

--- Remove generator
--- @param generatorId string Generator ID
--- @return GeneratorData|nil Removed generator data
function LKS_EletricidadeConstrucao.Core.StateManager.RemoveGenerator(generatorId)
    if not _state then
        LKS_EletricidadeConstrucao.Error("[StateManager.RemoveGenerator] No state")
        return nil
    end
    
    local removed = LKS_EletricidadeConstrucao.Data.State.RemoveGenerator(_state, generatorId)
    
    if removed then
        IndexRemoveGenerator(generatorId, removed.chunkKey)
        LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
        LKS_EletricidadeConstrucao.Debug("[StateManager] Removed generator: " .. generatorId)
    end
    
    return removed
end

--- Get generator by ID
--- @param generatorId string Generator ID
--- @return GeneratorData|nil Generator data
function LKS_EletricidadeConstrucao.Core.StateManager.GetGenerator(generatorId)
    if not _state then
        return nil
    end
    
    return LKS_EletricidadeConstrucao.Data.State.GetGenerator(_state, generatorId)
end

--- Get all generators
--- @return table Map of generator ID to GeneratorData
function LKS_EletricidadeConstrucao.Core.StateManager.GetAllGenerators()
    if not _state then
        return {}
    end
    
    return LKS_EletricidadeConstrucao.Data.State.GetAllGenerators(_state)
end

--- Get active generators
--- @return table Array of GeneratorData
function LKS_EletricidadeConstrucao.Core.StateManager.GetActiveGenerators()
    if not _state then
        return {}
    end
    
    return LKS_EletricidadeConstrucao.Data.State.GetActiveGenerators(_state)
end

--- Get generators in chunk
--- @param chunkKey string Chunk key
--- @return table Array of GeneratorData
function LKS_EletricidadeConstrucao.Core.StateManager.GetGeneratorsInChunk(chunkKey)
    if not _state then
        return {}
    end
    
    return LKS_EletricidadeConstrucao.Data.State.GetGeneratorsInChunk(_state, chunkKey)
end

--- Rehydrate generators from the ModData index (V1-style resilience)
--- @return number Number of generators restored
function LKS_EletricidadeConstrucao.Core.StateManager.HydrateGeneratorsFromIndex()
    return HydrateGeneratorsFromIndex()
end

-- ============================================================================
-- BUILDING OPERATIONS
-- ============================================================================

--- Add or update building
--- @param buildingData BuildingData Building data to add
function LKS_EletricidadeConstrucao.Core.StateManager.AddBuilding(buildingData)
    if not _state then
        LKS_EletricidadeConstrucao.Error("[StateManager.AddBuilding] No state")
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.AddBuilding(_state, buildingData)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Debug("[StateManager] Added building: " .. buildingData.id)
end

--- Remove building
--- @param buildingId string Building ID
--- @return BuildingData|nil Removed building data
function LKS_EletricidadeConstrucao.Core.StateManager.RemoveBuilding(buildingId)
    if not _state then
        LKS_EletricidadeConstrucao.Error("[StateManager.RemoveBuilding] No state")
        return nil
    end
    
    local removed = LKS_EletricidadeConstrucao.Data.State.RemoveBuilding(_state, buildingId)
    
    if removed then
        LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
        LKS_EletricidadeConstrucao.Debug("[StateManager] Removed building: " .. buildingId)
    end
    
    return removed
end

--- Get building by ID
--- @param buildingId string Building ID
--- @return BuildingData|nil Building data
function LKS_EletricidadeConstrucao.Core.StateManager.GetBuilding(buildingId)
    if not _state then
        return nil
    end
    
    return LKS_EletricidadeConstrucao.Data.State.GetBuilding(_state, buildingId)
end

--- Get all buildings
--- @return table Map of building ID to BuildingData
function LKS_EletricidadeConstrucao.Core.StateManager.GetAllBuildings()
    if not _state then
        return {}
    end
    
    return LKS_EletricidadeConstrucao.Data.State.GetAllBuildings(_state)
end

--- Get buildings connected to generator
--- @param generatorId string Generator ID
--- @return table Array of BuildingData
function LKS_EletricidadeConstrucao.Core.StateManager.GetGeneratorBuildings(generatorId)
    if not _state then
        return {}
    end
    
    return LKS_EletricidadeConstrucao.Data.State.GetGeneratorBuildings(_state, generatorId)
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

--- Get runtime statistics
--- @return table Statistics table
function LKS_EletricidadeConstrucao.Core.StateManager.GetStatistics()
    if not _state then
        return {}
    end
    
    return _state.statistics
end

--- Record fuel consumption
--- @param amount number Fuel amount
function LKS_EletricidadeConstrucao.Core.StateManager.RecordFuelConsumption(amount)
    if not _state then
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.RecordFuelConsumption(_state, amount)
    -- Don't mark dirty for statistics (saved on next regular save)
end

--- Update uptime
--- @param deltaSeconds number Time delta
function LKS_EletricidadeConstrucao.Core.StateManager.UpdateUptime(deltaSeconds)
    if not _state then
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.UpdateUptime(_state, deltaSeconds)
    -- Don't mark dirty for statistics
end

-- ============================================================================
-- SYNC OPERATIONS (Multiplayer)
-- ============================================================================

--- Mark full sync completed
function LKS_EletricidadeConstrucao.Core.StateManager.MarkFullSync()
    if not _state then
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.MarkFullSync(_state)
end

--- Mark delta sync completed
function LKS_EletricidadeConstrucao.Core.StateManager.MarkDeltaSync()
    if not _state then
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.MarkDeltaSync(_state)
end

--- Check if full sync is needed
--- @return boolean True if needed
function LKS_EletricidadeConstrucao.Core.StateManager.NeedsFullSync()
    if not _state then
        return false
    end
    
    local Constants = LKS_EletricidadeConstrucao.Constants
    local interval = Constants.NETWORK.FULL_SYNC_INTERVAL or 60000
    
    return LKS_EletricidadeConstrucao.Data.State.NeedsFullSync(_state, interval)
end

--- Check if delta sync is needed
--- @return boolean True if needed
function LKS_EletricidadeConstrucao.Core.StateManager.NeedsDeltaSync()
    if not _state then
        return false
    end
    
    local Constants = LKS_EletricidadeConstrucao.Constants
    local interval = Constants.NETWORK.DELTA_SYNC_INTERVAL or 5000
    
    return LKS_EletricidadeConstrucao.Data.State.NeedsDeltaSync(_state, interval)
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

--- Clear all generators
function LKS_EletricidadeConstrucao.Core.StateManager.ClearGenerators()
    if not _state then
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.ClearGenerators(_state)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Print("[StateManager] Cleared all generators")
end

--- Clear all buildings
function LKS_EletricidadeConstrucao.Core.StateManager.ClearBuildings()
    if not _state then
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.ClearBuildings(_state)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Print("[StateManager] Cleared all buildings")
end

--- Clear all data
function LKS_EletricidadeConstrucao.Core.StateManager.ClearAll()
    if not _state then
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.ClearAll(_state)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Print("[StateManager] Cleared all data")
end

--- Reset state to defaults
function LKS_EletricidadeConstrucao.Core.StateManager.Reset()
    _state = LKS_EletricidadeConstrucao.Data.State.New()
    -- Config is stored separately in LKS_EletricidadeConstrucao.Config, no need to copy
    _isDirty = true
    
    LKS_EletricidadeConstrucao.Print("[StateManager] State reset to defaults")
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Get state summary
--- @return string Summary string
function LKS_EletricidadeConstrucao.Core.StateManager.GetSummary()
    if not _state then
        return "StateManager: Not initialized"
    end
    
    return LKS_EletricidadeConstrucao.Data.State.GetSummary(_state)
end

--- Print debug information
function LKS_EletricidadeConstrucao.Core.StateManager.PrintDebugInfo()
    if not _state then
        LKS_EletricidadeConstrucao.Print("StateManager: Not initialized")
        return
    end
    
    LKS_EletricidadeConstrucao.Print("=== LKS_EletricidadeConstrucao State Manager ===")
    LKS_EletricidadeConstrucao.Print("Initialized: " .. tostring(_initialized))
    LKS_EletricidadeConstrucao.Print("Dirty: " .. tostring(_isDirty))
    LKS_EletricidadeConstrucao.Print(LKS_EletricidadeConstrucao.Data.State.GetSummary(_state))
    
    local stats = _state.statistics
    LKS_EletricidadeConstrucao.Print("  Generators: " .. stats.totalGenerators .. " (" .. stats.activeGenerators .. " active)")
    LKS_EletricidadeConstrucao.Print("  Buildings: " .. stats.totalBuildings)
    LKS_EletricidadeConstrucao.Print("  Consumers: " .. stats.totalConsumers .. " (" .. stats.activeConsumers .. " active)")
    LKS_EletricidadeConstrucao.Print("  Fuel Consumed: " .. stats.totalFuelConsumed)
    LKS_EletricidadeConstrucao.Print("  Uptime: " .. string.format("%.1f", stats.uptime / 3600) .. " hours")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Core.StateManager", "2.0.0")

return LKS_EletricidadeConstrucao.Core.StateManager
