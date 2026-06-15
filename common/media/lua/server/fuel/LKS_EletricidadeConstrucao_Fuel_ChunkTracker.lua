-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Fuel_ChunkTracker.lua
-- LKS_EletricidadeConstrucao V2 - Chunk Load/Unload Tracker
-- Tracks fuel consumption across chunk loads/unloads
-- Fixes: Bug where generators consumed fuel while chunk was unloaded
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Fuel_ChunkTracker] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local _chunkLoadTimes = {}  -- chunkKey -> timestamp
local _isInitialized = false
local _scheduledBuildingUpdates = {}  -- buildingID -> true (dedup building updates)
local _processedChunks = {}  -- chunkKey -> true (dedup chunk processing)
local _pendingBuildingUpdates = {}  -- buildingID -> true (global batch timer)
local _pendingGenRescans = {}  -- genId -> {x, y, z} (generators whose own square needs rescanning)
local _batchTimerActive = false

-- B-106: Kahlua's GETGLOBAL for `next` can return nil inside nested closures.
-- Use a module-scoped helper that uses `pairs` directly (always available).
local function TableHasEntries(t)
    if not t then return false end
    for _ in pairs(t) do return true end
    return false
end

-- Helper: total world minutes elapsed in game time (mirrors LKS_EletricidadeConstrucao_Fuel_Manager definition)
local function GetWorldMinutes()
    local gt = getGameTime and getGameTime()
    if gt then
        local worldHours = gt:getWorldAgeHours() or 0
        return worldHours * 60
    end
    return getTimestampMs() / 60000  -- fallback to real time if GameTime unavailable
end

-- Forward declaration so HandleStartupGeneratorRefresh (defined below) can call it.
-- The actual body is assigned in the V1-STYLE ISO MODDATA RESTORE section.
local TryRestoreFromIsoModData

--- Return true only when a generator square needs a full IsoModData restore.
--- A square does NOT need restore when its building is already established in state
--- (building entry exists AND has at least one powerConsumer recorded).
--- This prevents TryRestoreFromIsoModData from running redundantly on every
--- chunk-return when Load() already hydrated everything correctly. (B-71)
local function NeedsIsoRestore(square)
    if not square then return false end
    local SM = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not SM then return true end
    local objs = square:getObjects()
    if not objs then return false end
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj and instanceof(obj, "IsoGenerator") then
            local genMD = obj:getModData()
            local bid   = genMD and genMD.Gen_BuildingPoolID
            if not bid then return true end  -- no pool stamp → needs restore
            local bld = SM.GetBuilding(bid)
            if not bld then return true end  -- building missing from state → needs restore
            -- Check powerConsumers via pairs (safe on Kahlua string-keyed arrays)
            local hasConsumers = false
            if bld.powerConsumers then
                for _ in pairs(bld.powerConsumers) do hasConsumers = true; break end
            end
            return not hasConsumers  -- needs restore only if consumers not yet scanned
        end
    end
    return false  -- no IsoGenerator on this square
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize chunk tracker
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.Initialize()
    if _isInitialized then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("Chunk Tracker already initialized", "Fuel")
        return
    end
    
    -- Register event handlers for grid square load/unload.
    -- Event names confirmed from PZ 42 Lua API docs:
    --   LoadGridsquare  - fired after a new square loads  (param: IsoGridSquare)
    --   ReuseGridsquare - fired before a square unloads   (param: IsoGridSquare)
    local loadEvents   = { "LoadGridsquare" }
    local unloadEvents = { "ReuseGridsquare" }
    local loadRegistered, unloadRegistered = false, false
    for _, evName in ipairs(loadEvents) do
        if Events[evName] then
            Events[evName].Add(LKS_EletricidadeConstrucao.Fuel.ChunkTracker.OnLoadGridsquare)
            LKS_EletricidadeConstrucao.Core.Logger.Info("ChunkTracker: registered '" .. evName .. "'", "Fuel")
            loadRegistered = true
            break
        end
    end
    for _, evName in ipairs(unloadEvents) do
        if Events[evName] then
            Events[evName].Add(LKS_EletricidadeConstrucao.Fuel.ChunkTracker.OnUnloadGridsquare)
            LKS_EletricidadeConstrucao.Core.Logger.Info("ChunkTracker: registered '" .. evName .. "'", "Fuel")
            unloadRegistered = true
            break
        end
    end
    if not loadRegistered then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("ChunkTracker: LoadGridsquare event not found - chunk-based fuel tracking disabled", "Fuel")
    end
    if not unloadRegistered then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("ChunkTracker: ReuseGridsquare event not found - chunk-based fuel tracking disabled", "Fuel")
    end
    
    _isInitialized = true

    -- On game-start/reload, nearby chunks load during the loading screen BEFORE
    -- OnGameStart fires and this handler gets registered.  Those LoadGridsquare
    -- events are therefore never received.  Walk all known generators now and
    -- schedule a ForceUpdateBuilding for every one whose square is already in
    -- memory, using the same V1-style self-removing closure pattern.
    LKS_EletricidadeConstrucao.Fuel.ChunkTracker.HandleStartupGeneratorRefresh()

    LKS_EletricidadeConstrucao.Core.Logger.Info("Chunk Tracker initialized", "Fuel")
end

--- Check if chunk tracker is initialized
--- @return boolean True if initialized
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.IsInitialized()
    return _isInitialized
end

-- ============================================================================
-- B-104: STALE-BUILDING DUPLICATE PURGE
-- Extracted from HandleStartupGeneratorRefresh to avoid exceeding Kahlua's
-- 200-local-variable-per-function limit (B-105 side-effect fix).
-- ============================================================================

--- Fix canonical building coordinates and merge stale bld_def_… duplicates.
--- Pass 1: correct bld_X_Y_Z entries whose stored x/y/z differs from the ID.
--- Pass 2: detect stale+canonical pairs via shared connectedGenerators key,
---          merge generator links, update IsoObject ModData, remove stale.
--- @param SM table StateManager reference
--- @param buildingIds table   [id]=true map updated in-place (stale removed, canonical added)
--- @param pendingUpdates table [id]=true map of buildings needing UI refresh
local function PurgeStaleBuildingDuplicates(SM, buildingIds, pendingUpdates)
    -- Pass 1: fix canonical building coords from ID.
    pendingUpdates = pendingUpdates or {}
    local allBlds = SM.GetAllBuildings() or {}
    for bid, bld in pairs(allBlds) do
        local bxF, byF, bzFs = string.match(bid, "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if bxF then
            local bxN, byN, bzN = tonumber(bxF), tonumber(byF), tonumber(bzFs or "0")
            if bld.x ~= bxN or bld.y ~= byN then
                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                    "[ChunkTracker] B-104: fixing %s coords (%s,%s) -> (%d,%d)",
                    bid, tostring(bld.x), tostring(bld.y), bxN, byN), "Fuel")
                bld.x, bld.y, bld.z = bxN, byN, bzN
                SM.MarkDirty()
            end
        end
    end

    -- Pass 2: index canonical buildings by each gen-key they reference.
    local canonByGen = {}  -- genKey -> canonical building ID
    allBlds = SM.GetAllBuildings() or {}
    for bid, bld in pairs(allBlds) do
        if string.match(bid, "^bld_%-?%d+_%-?%d+_%-?%d+$") and bld.connectedGenerators then
            for _, gk in pairs(bld.connectedGenerators) do
                canonByGen[gk] = bid
            end
        end
    end

    -- Pass 2 (cont): for each stale building, find its canonical partner.
    for bid, bld in pairs(allBlds) do
        if not string.match(bid, "^bld_%-?%d+_%-?%d+_%-?%d+$") then
            local matched = nil
            if bld.connectedGenerators then
                for _, gk in pairs(bld.connectedGenerators) do
                    if canonByGen[gk] then matched = canonByGen[gk]; break end
                end
            end
            if matched then
                -- Merge connectedGenerators from stale into canonical.
                local canonBld = SM.GetBuilding(matched)
                if canonBld and bld.connectedGenerators then
                    canonBld.connectedGenerators = canonBld.connectedGenerators or {}
                    local cgSet = {}
                    for _, gk in pairs(canonBld.connectedGenerators) do cgSet[gk] = true end
                    for _, gk in pairs(bld.connectedGenerators) do
                        if not cgSet[gk] then
                            table.insert(canonBld.connectedGenerators, gk)
                            cgSet[gk] = true
                        end
                    end
                end
                
                -- B-111-consumer-fix: Merge powerConsumers from stale into canonical.
                -- B-111 stale fallback uses stale building data temporarily, but when
                -- Purge removes the stale building, consumers are lost if not merged.
                if canonBld and bld.powerConsumers then
                    canonBld.powerConsumers = canonBld.powerConsumers or {}
                    for consKey, consData in pairs(bld.powerConsumers) do
                        if not canonBld.powerConsumers[consKey] then
                            canonBld.powerConsumers[consKey] = consData
                        end
                    end
                    -- Recalculate power draw totals after merge
                    local totalDraw = 0
                    local heatingDraw = 0
                    for _, cons in pairs(canonBld.powerConsumers) do
                        if cons.powerDraw then
                            totalDraw = totalDraw + cons.powerDraw
                            if cons.isHeater then
                                heatingDraw = heatingDraw + cons.powerDraw
                            end
                        end
                    end
                    canonBld.totalPowerDraw = totalDraw
                    canonBld.heatingPowerDraw = heatingDraw
                    -- Queue for UI update so info window shows merged consumers
                    if pendingUpdates then
                        pendingUpdates[matched] = true
                    end
                end
                
                -- B-108: inherit heating config from stale entry when canonical has none.
                -- B-111-heating-fix: Check heatingSourceCount instead of heatingEnabled,
                -- because canonical might have heatingEnabled=false (IsoObject default)
                -- while stale has heatingEnabled=true + heatingSourceCount>0 (GlobalModData).
                -- Prioritize actual heating sources over IsoObject defaults.
                if canonBld and bld.heatingSourceCount and bld.heatingSourceCount > 0 then
                    local canonHasNoSources = not canonBld.heatingSourceCount or canonBld.heatingSourceCount == 0
                    if canonHasNoSources then
                        canonBld.heatingEnabled     = bld.heatingEnabled
                        canonBld.heatingSourceCount = bld.heatingSourceCount
                        canonBld.heatingTargetTemp  = bld.heatingTargetTemp
                    end
                end
                -- Update all generators: rewrite stale ID -> canonical.
                local cell = getCell and getCell()
                for _, gd in pairs(SM.GetAllGenerators() or {}) do
                    if gd.connectedBuildings then
                        local changed = false
                        for k, b in pairs(gd.connectedBuildings) do
                            if b == bid then gd.connectedBuildings[k] = matched; changed = true end
                        end
                        if changed then
                            -- Dedup connectedBuildings after replacement.
                            local seen, rebuilt = {}, {}
                            for _, b in pairs(gd.connectedBuildings) do
                                if not seen[b] then seen[b] = true; table.insert(rebuilt, b) end
                            end
                            gd.connectedBuildings = rebuilt
                            SM.AddGenerator(gd)
                            -- Stamp new ID on IsoObject if square is loaded.
                            if cell and gd.x and gd.y and gd.z then
                                local sq = cell:getGridSquare(gd.x, gd.y, gd.z)
                                if sq then
                                    local objs = sq:getObjects()
                                    for oi = 0, objs:size() - 1 do
                                        local go = objs:get(oi)
                                        if go and instanceof(go, "IsoGenerator") then
                                            local gmd = go:getModData()
                                            if gmd and gmd.Gen_BuildingPoolID == bid then
                                                gmd.Gen_BuildingPoolID = matched
                                                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                                    go:transmitModData()
                                                end
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                "[ChunkTracker] B-104: gen=%s %s -> %s",
                                gd.id or "?", bid, matched), "Fuel")
                        end
                    end
                end
                SM.RemoveBuilding(bid)
                SM.MarkDirty()
                if buildingIds then buildingIds[bid] = nil; buildingIds[matched] = true end
                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                    "[ChunkTracker] B-104: removed stale building %s (merged into %s)",
                    bid, matched), "Fuel")
            end
        end
    end
end

--- Scan StateManager generators at game-start and queue ForceUpdateBuilding
--- for any whose map square is already loaded into memory.
--- Called once from Initialize() to cover the gap where LoadGridsquare fires
--- during the loading screen before our event handler was registered.
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.HandleStartupGeneratorRefresh()
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local allGenerators = StateManager.GetAllGenerators()
    if not allGenerators then return end

    -- Fallback: if no generators were persisted (e.g. save missed), rebuild
    -- generator entries first from the global ModData index, then from any
    -- known buildings' connectedGenerators.
    local empty = true
    for _ in pairs(allGenerators) do empty = false; break end
    if empty then
        -- Try to hydrate from the ModData generator index (V1-style resilience)
        local restoredFromIndex = 0
        if StateManager.HydrateGeneratorsFromIndex then
            restoredFromIndex = StateManager.HydrateGeneratorsFromIndex()
        end

        -- Refresh local reference in case hydration populated state
        allGenerators = StateManager.GetAllGenerators()
        empty = true
        for _ in pairs(allGenerators) do empty = false; break end

        -- If still empty, rebuild generator entries from buildings
        local buildings = StateManager.GetAllBuildings() or {}
        for bid, bld in pairs(buildings) do
            if bld.connectedGenerators then
                -- connectedGenerators is Kahlua-deserialized (string numeric keys)
                for _, gk in pairs(bld.connectedGenerators) do
                    local gx, gy, gz = string.match(gk, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                    if gx then
                        gx, gy, gz = tonumber(gx), tonumber(gy), tonumber(gz)
                        local genId = LKS_EletricidadeConstrucao.Data.Generator.MakeId(gx, gy, gz)
                        local genData = StateManager.GetGenerator(genId)
                        if not genData then
                            genData = LKS_EletricidadeConstrucao.Data.Generator.New(getGeneratorFromSquare(gx, gy, gz) or {})
                            genData.x, genData.y, genData.z = gx, gy, gz
                            genData.connectedBuildings = { bid }
                            StateManager.AddGenerator(genData)
                        else
                            genData.connectedBuildings = genData.connectedBuildings or {}
                            local seen = false
                            -- connectedBuildings may also have Kahlua string numeric keys
                            for _, existing in pairs(genData.connectedBuildings) do
                                if existing == bid then seen = true; break end
                            end
                            if not seen then table.insert(genData.connectedBuildings, bid) end
                            StateManager.AddGenerator(genData)
                        end
                    end
                end
            end
        end
        allGenerators = StateManager.GetAllGenerators()

        -- V1-style final fallback: if ALL GlobalModData paths exhausted and state
        -- is still empty, do a spatial scan of already-loaded squares near the player.
        -- TryRestoreFromIsoModData reads Gen_BuildingPoolID directly from each
        -- IsoGenerator object, so it works even when every ModData blob is gone.
        empty = true
        for _ in pairs(allGenerators) do empty = false; break end
        if empty then
            LKS_EletricidadeConstrucao.Core.Logger.Info(
                "StartupGeneratorRefresh: all ModData paths empty – running V1-style IsoObject spatial scan",
                "Fuel")
            local player = getSpecificPlayer and getSpecificPlayer(0) or (getPlayer and getPlayer())
            if player then
                local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
                local cell = getCell()
                if cell then
                    for dx = -40, 40 do
                        for dy = -40, 40 do
                            local sq = cell:getGridSquare(px + dx, py + dy, pz)
                            if sq then pcall(TryRestoreFromIsoModData, sq) end
                        end
                    end
                end
            end
            allGenerators = StateManager.GetAllGenerators()
        end
    end

    local buildingIds = {}
    local foundCount  = 0
    local restoredCount = 0

    for _, genData in pairs(allGenerators) do
        -- Only process generators whose square is already in memory
        local sq = getSquare(genData.x, genData.y, genData.z)
        if sq then
            foundCount = foundCount + 1
            
            -- CRITICAL FIX: Run TryRestoreFromIsoModData for already-loaded generators
            -- to create building entries. On initial startup, player spawns in chunk
            -- so LoadGridsquare never fires and buildings are never restored.
            -- This ensures buildings exist before ForceUpdateBuilding is called.
            local beforeCount = 0
            local buildings = StateManager.GetAllBuildings() or {}
            for _ in pairs(buildings) do beforeCount = beforeCount + 1 end
            
            pcall(TryRestoreFromIsoModData, sq)
            
            local afterCount = 0
            buildings = StateManager.GetAllBuildings() or {}
            for _ in pairs(buildings) do afterCount = afterCount + 1 end
            
            if afterCount > beforeCount then
                restoredCount = restoredCount + 1
                LKS_EletricidadeConstrucao.Core.Logger.Debug(
                    string.format("Restored building for generator %s (%d buildings now in state)",
                        genData.id, afterCount),
                    "Fuel")
            end
            
            -- connectedBuildings is Kahlua-deserialized after GlobalModData reload
            -- (string numeric keys) → ipairs returns nothing. Use pairs.
            for _, bid in pairs(genData.connectedBuildings or {}) do
                buildingIds[bid] = true
            end
        end  -- close: if sq then
    end  -- close: for _, genData in pairs(allGenerators)

    -- ── B-104: Post-loop stale-building cleanup ──────────────────────────────
    -- Extracted to PurgeStaleBuildingDuplicates() to avoid Kahlua's 200-local
    -- limit (ArrayIndexOutOfBoundsException at LexState.new_localvar:740).
    if StateManager.IsStateLoaded and StateManager.IsStateLoaded() then
        local pendingUpdates = {}  -- Collect buildings needing UI update
        PurgeStaleBuildingDuplicates(StateManager, buildingIds, pendingUpdates)
        -- Queue for ForceUpdateBuilding later in the deferred timer
        for bid in pairs(pendingUpdates) do
            _pendingBuildingUpdates[bid] = true
        end
    end
    -- ────────────────────────────────────────────────────────────────────────

    local _hasBids = false
    for _ in pairs(buildingIds) do _hasBids = true; break end
    if not _hasBids then
        -- No generator squares were loaded at frame 0. However generators ARE in state
        -- (deserialized from GlobalModData). Their chunks will load shortly, but:
        --   (a) OnLoadGridsquare only calls TryRestoreFromIsoModData on the FIRST square
        --       of each chunk (via _processedChunks dedup), NOT on the generator's actual
        --       square – so generators on non-first squares are never rescanned via chunk events.
        --   (b) Even if TryRestoreFromIsoModData runs, the stale-consumer optimization used
        --       to return early before the consumer-data fix below.
        -- Solution: schedule a 60-tick deferred scan that calls TryRestoreFromIsoModData
        -- on every generator's own square once the world is settled.
        local allEmpty = true
        for _ in pairs(allGenerators) do allEmpty = false; break end
        if allEmpty then
            LKS_EletricidadeConstrucao.Core.Logger.Info(
                "StartupGeneratorRefresh: no generators in state – nothing to do",
                "Fuel")
            return
        end

        -- Before giving up on unloaded squares: attempt a GlobalModData cross-reference.
        -- When Load() succeeds (buildings under canonical bld_X_Y_Z in state blob) but
        -- HydrateGeneratorsFromIndex also ran (generators restored with stale bld_def_...
        -- IDs from the index), buildings exist in state but are unreachable because the
        -- generator's connectedBuildings points to the old key.
        -- Solution: for each generator with an unresolvable building ID, search all
        -- buildings in state for one whose connectedGenerators includes this generator.
        -- This works without any IsoObject access and fixes the mismatch immediately.
        local xrefFixed = 0
        local allBldState = StateManager.GetAllBuildings() or {}
        for _, gd in pairs(allGenerators) do
            local genKeyXref = string.format("%d_%d_%d", gd.x, gd.y, gd.z)
            -- connectedBuildings / connectedGenerators are Kahlua-deserialized (string numeric keys)
            for i, bid in pairs(gd.connectedBuildings or {}) do
                if not StateManager.GetBuilding(bid) then
                    -- Cannot find building under stored ID - try reverse-lookup via connectedGenerators
                    for _, bld in pairs(allBldState) do
                        if bld.connectedGenerators then
                            for _, gk in pairs(bld.connectedGenerators) do
                                if gk == genKeyXref then
                                    LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                        "[StartupXref] Remapped %s.connectedBuildings[%s]: %s -> %s",
                                        gd.id, tostring(i), bid, bld.id), "Fuel")
                                    gd.connectedBuildings[i] = bld.id
                                    StateManager.AddGenerator(gd)  -- flush corrected ID to index
                                    xrefFixed = xrefFixed + 1
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        if xrefFixed > 0 then
            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                "[StartupXref] Fixed %d stale building reference(s) via cross-reference", xrefFixed), "Fuel")
        end

        -- Rebuild buildingIds from the (potentially corrected) generator state
        allGenerators = StateManager.GetAllGenerators() or {}

        local genCount = 0
        for _ in pairs(allGenerators) do genCount = genCount + 1 end
        LKS_EletricidadeConstrucao.Core.Logger.Info(
            string.format("StartupGeneratorRefresh: %d gen(s) in state but no squares loaded yet – scheduling deferred rescan at tick 60",
                genCount),
            "Fuel")
        local deferTicks    = 60
        local deferAttempts = 0
        local MAX_DEFER_ATTEMPTS = 5
        local deferFunc
        deferFunc = function()
            deferTicks = deferTicks - 1
            if deferTicks > 0 then return end
            Events.OnTick.Remove(deferFunc)
            local allGens = StateManager.GetAllGenerators() or {}
            local scanned = 0
            for _, gd in pairs(allGens) do
                local gSq = getSquare(gd.x, gd.y, gd.z)
                if gSq then
                    pcall(TryRestoreFromIsoModData, gSq)
                    scanned = scanned + 1
                end
            end
            LKS_EletricidadeConstrucao.Core.Logger.Info(
                string.format("StartupGeneratorRefresh (deferred): rescanned %d generator square(s)", scanned),
                "Fuel")
            -- If still no squares loaded, retry after 120 more ticks (up to MAX_DEFER_ATTEMPTS)
            if scanned == 0 and deferAttempts < MAX_DEFER_ATTEMPTS then
                deferAttempts = deferAttempts + 1
                deferTicks = 120
                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                    "StartupGeneratorRefresh (deferred): no squares yet, retry %d/%d in 120 ticks",
                    deferAttempts, MAX_DEFER_ATTEMPTS), "Fuel")
                Events.OnTick.Add(deferFunc)
                return
            end
            -- Phase 2: ForceUpdate all buildings currently known in state.
            -- When all generators are still off-chunk (scanned == 0), _state.buildings is
            -- empty and this is a no-op; buildings will be created by TryRestoreFromIsoModData
            -- the moment the player's chunk loads.  When some generators were scanned
            -- (partial on-chunk boot), this refreshes all known buildings in one pass.
            -- Using ForceUpdate() (global) instead of ForceUpdateBuilding(id) per generator
            -- avoids "Building not found" warnings when connectedBuildings still holds a
            -- stale bld_def_... ID from a pre-migration save (off-chunk restart case).
            local Dist2 = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
            if Dist2 and Dist2.ForceUpdate then
                Dist2.ForceUpdate()
                local bldCount2 = 0
                local allBlds2 = StateManager.GetAllBuildings() or {}
                for _ in pairs(allBlds2) do bldCount2 = bldCount2 + 1 end
                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("StartupGeneratorRefresh (deferred): ForceUpdate called (%d building(s) in state)",
                        bldCount2),
                    "Fuel")
            end
        end
        Events.OnTick.Add(deferFunc)
        return
    end

    local bldCount = 0
    for _ in pairs(buildingIds) do bldCount = bldCount + 1 end
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("StartupGeneratorRefresh: %d pre-loaded generators found, %d buildings restored, scheduling refresh for %d buildings",
            foundCount, restoredCount, bldCount),
        "Fuel")

    -- Mark all buildings as scheduled to prevent ProcessChunkGenerators from
    -- duplicating the startup refresh
    for bid in pairs(buildingIds) do
        _scheduledBuildingUpdates[bid] = true
    end

    -- V1 self-removing closure:
    --   Phase 1 (30 ticks)  – rescan any buildings that came back with 0 consumers
    --                          (world squares are now loaded; the immediate frame-0 scan
    --                           found almost no tiles because the world wasn't settled yet)
    --   Phase 2 (30+1 ticks) – call ForceUpdateBuilding so power distribution reflects
    --                           the freshly populated consumer lists
    local ticksLeft    = 30
    local phase2Done   = false
    local timerFunc
    timerFunc = function()
        ticksLeft = ticksLeft - 1
        if ticksLeft > 0 then return end

        if not phase2Done then
            -- ---- Phase 1: deferred consumer rescan --------------------------------
            -- Buildings restored at frame 0 (V1-style spatial scan OR GlobalModData)
            -- may have 0 or very few consumers because the world squares weren't
            -- loaded yet.  Now that we are ~30 ticks in the world is settled, so
            -- re-run ScanBuilding for any building with 0 consumers.
            local Scanner = LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner
            if Scanner and Scanner.ScanBuilding then
                for bid in pairs(buildingIds) do
                    local bld = StateManager.GetBuilding(bid)
                    if bld and (not bld.powerConsumers or LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(bld.powerConsumers)) then
                        -- Derive light-switch coordinates.
                        -- For canonical bld_X_Y_Z IDs, always decode from the ID itself:
                        -- stored x/y/z may be stale generator coordinates from an old
                        -- pending-state stub (B-104), placing the scan outside the building.
                        local lsX, lsY, lsZ = bld.x, bld.y, bld.z
                        local bxR, byR, bzRs = string.match(bid, "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        if bxR then lsX, lsY, lsZ = tonumber(bxR), tonumber(byR), tonumber(bzRs or "0") end
                        if lsX and lsY then
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                "[ChunkTracker] StartupRescan: building %s has 0 consumers, rescanning from (%d,%d,%d)",
                                bid, lsX, lsY, lsZ or 0), "Fuel")
                            pcall(function()
                                Scanner.ScanBuilding(lsX, lsY, lsZ or 0, bid)
                            end)
                            bld = StateManager.GetBuilding(bid) or bld
                            local _afterCount = 0
                            if bld.powerConsumers then
                                for _ in pairs(bld.powerConsumers) do _afterCount = _afterCount + 1 end
                            end
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                "[ChunkTracker] StartupRescan: %s now has %d consumers",
                                bid, _afterCount), "Fuel")
                        end
                    end
                end
            end
            -- Prepare Phase 2 on the very next tick
            phase2Done = true
            ticksLeft  = 1
            return
        end

        -- ---- Phase 2: ForceUpdateBuilding ----------------------------------------
        Events.OnTick.Remove(timerFunc)

        local Dist = LKS_EletricidadeConstrucao.Power
                  and LKS_EletricidadeConstrucao.Power.Distributor
        if Dist and Dist.ForceUpdateBuilding then
            for bid in pairs(buildingIds) do
                pcall(Dist.ForceUpdateBuilding, bid)
            end
        end

        -- Release all reservations after startup completes
        for bid in pairs(buildingIds) do
            _scheduledBuildingUpdates[bid] = nil
        end

        LKS_EletricidadeConstrucao.Core.Logger.Info(
            "StartupGeneratorRefresh: ForceUpdateBuilding complete for " .. bldCount .. " building(s)",
            "Fuel")
    end
    Events.OnTick.Add(timerFunc)
end

-- ============================================================================
-- V1-STYLE ISO MODDATA RESTORE
-- ============================================================================

--- V1-style: scan a single grid square for IsoGenerators whose Gen_BuildingPoolID
--- is set, and rebuild StateManager entries from their ModData if they are missing.
--- OPTIMIZED: Skips full building scan if generator already has valid links.
--- @param square IsoGridSquare Grid square to scan
TryRestoreFromIsoModData = function(square)
    if not square then return end
    local objects = square:getObjects()
    if not objects then return end

    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not StateManager then return end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and instanceof(obj, "IsoGenerator") then
            local md = obj:getModData()
            if md and md.Gen_BuildingPoolID then
                -- ----------------------------------------------------------------
                -- CROSS-SAVE ISOLATION: validate LKS_EletricidadeConstrucao_WorldId before trusting any
                -- pool data stamped on this IsoGenerator object.  If the world ID
                -- doesn't match the current save, this data belongs to another
                -- save and must be cleared before it can pollute the runtime state.
                -- ----------------------------------------------------------------
                local currentWid = StateManager.GetCurrentWorldId and StateManager.GetCurrentWorldId()
                if currentWid and currentWid ~= "unknown" and md.LKS_EletricidadeConstrucao_WorldId
                    and md.LKS_EletricidadeConstrucao_WorldId ~= "unknown" and md.LKS_EletricidadeConstrucao_WorldId ~= currentWid then
                    LKS_EletricidadeConstrucao.Core.Logger.Warn(string.format(
                        "[ChunkTracker] Stale generator ModData detected (stored world=%s, current=%s) - clearing",
                        md.LKS_EletricidadeConstrucao_WorldId, currentWid), "Fuel")
                    -- Wipe all LKS_EletricidadeConstrucao pool keys so this generator starts fresh in the new save
                    md.Gen_BuildingPoolID           = nil
                    md.LKS_EletricidadeConstrucao_WorldId                   = nil
                    md.LKS_EletricidadeConstrucao_PoolData                  = nil
                    md.Gen_Stats_Consumers          = nil
                    md.Gen_Stats_ActiveConsumers    = nil
                    md.Gen_Stats_Lights             = nil
                    md.Gen_Stats_ActiveLights       = nil
                    md.Gen_Stats_Lamps              = nil
                    md.Gen_Stats_ActiveLamps        = nil
                    md.Gen_Stats_Appliances         = nil
                    md.Gen_Stats_ActiveAppliances   = nil
                    md.Gen_Stats_PowerDraw          = nil
                    md.Gen_Stats_Strain             = nil
                    md.Gen_Stats_FuelRateLph        = nil
                    md.Gen_Stats_Powered            = nil
                    -- Heating state must also be wiped on cross-save stale detection
                    -- so the generator does not carry old heating config into the new save.
                    md.HeatingEnabled               = nil
                    md.HeatingPositions             = nil
                    md.HeatingTargetTemp            = nil
                    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                        obj:transmitModData()
                    end
                    -- Skip this generator - no valid pool data
                else

                if currentWid and currentWid ~= "unknown" and md.LKS_EletricidadeConstrucao_WorldId ~= currentWid then
                    md.LKS_EletricidadeConstrucao_WorldId = currentWid
                    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                        obj:transmitModData()
                    end
                end

                local gx = square:getX()
                local gy = square:getY()
                local gz = square:getZ()
                local genId = LKS_EletricidadeConstrucao.Data.Generator.MakeId(gx, gy, gz)

                local genData = StateManager.GetGenerator(genId)
                -- Option A (B-99): powerConsumers are never saved to GlobalModData, so
                -- bldData.powerConsumers is always empty at boot.  needScan (below) is
                -- therefore true on the first chunk load of each session.  Within a
                -- session the short-circuit (consumers present → skip) is correct and
                -- prevents redundant rescans on repeated visits to the same chunk.

                local buildingPoolID = md.Gen_BuildingPoolID
                -- B-111: Save original building ID BEFORE any migrations/recoveries modify it.
                -- This allows stale building lookup fallback to find data under the old ID.
                local originalBuildingID = buildingPoolID

                -- ── ID MIGRATION ──────────────────────────────────────────────────────
                -- Legacy V1 saves stored player-built buildings under a `bld_def_XXXXX`
                -- ID inherited from the vanilla IsoBuilding definition instead of the
                -- actual light-switch coordinates.  The canonical V2 format is `bld_X_Y_Z`.
                -- When LKS_EletricidadeConstrucao_PoolData carries the light-switch position, reconstruct the
                -- correct ID so that BorderDetector's `isPlayerBuilt` check, the
                -- RadiusFallback, and all GlobalModData lookups all work correctly.
                if md.LKS_EletricidadeConstrucao_PoolData and md.LKS_EletricidadeConstrucao_PoolData.x and md.LKS_EletricidadeConstrucao_PoolData.y
                        and not string.match(buildingPoolID, "^bld_%-?%d+_%-?%d+_%-?%d+$") then
                    local lsX0 = md.LKS_EletricidadeConstrucao_PoolData.x
                    local lsY0 = md.LKS_EletricidadeConstrucao_PoolData.y
                    local lsZ0 = md.LKS_EletricidadeConstrucao_PoolData.z or gz
                    local canonicalId = LKS_EletricidadeConstrucao.Data.Building.MakeId(lsX0, lsY0, lsZ0)
                    LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                        "[ChunkTracker] ID migration: %s → %s (player-built, from LKS_EletricidadeConstrucao_PoolData)",
                        buildingPoolID, canonicalId), "Fuel")
                    -- Migrate existing GlobalModData entry (if any) to the canonical key
                    local oldEntry = StateManager.GetBuilding(buildingPoolID)
                    if oldEntry then
                        oldEntry.id = canonicalId
                        StateManager.RemoveBuilding(buildingPoolID)
                        StateManager.AddBuilding(oldEntry)
                    end
                    -- Persist canonical ID on the IsoObject so future boots skip migration
                    md.Gen_BuildingPoolID = canonicalId
                    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                        obj:transmitModData()
                    end
                    -- Fix any existing generator connectedBuildings list that still uses the old ID
                    if genData and genData.connectedBuildings then
                        -- connectedBuildings is Kahlua-deserialized (string numeric keys); use pairs
                        for i, b in pairs(genData.connectedBuildings) do
                            if b == buildingPoolID then
                                genData.connectedBuildings[i] = canonicalId
                            end
                        end
                    end
                    buildingPoolID = canonicalId
                end
                -- ─────────────────────────────────────────────────────────────────────

                -- ── SECONDARY CANONICAL LOOKUP ────────────────────────────────────────
                -- B-109: If the migration above did NOT run (LKS_EletricidadeConstrucao_PoolData is nil) and
                -- buildingPoolID is still a legacy bld_def_... ID, attempt to recover
                -- the canonical bld_X_Y_Z ID from:
                --   1. current genData.connectedBuildings (written by prior Purge/Lazy-Xref)
                --   2. StateManager's existing stale building (if it was already created
                --      by another generator in a different chunk and later migrated)
                --   3. ANY canonical building in state that shares generators with the
                --      same stale ID (cross-chunk duplicate detection)
                --
                -- This prevents multi-chunk generator pools from splitting when chunks
                -- load in different order (pool owner loads after non-owners, so
                -- non-owners create stale building before owner migrates to canonical).
                if not string.match(buildingPoolID, "^bld_%-?%d+_%-?%d+_%-?%d+$") then
                    local canonFound = nil
                    -- Try 1: Check current genData (if exists)
                    if genData and genData.connectedBuildings then
                        for _, existingBid in pairs(genData.connectedBuildings) do
                            if string.match(existingBid, "^bld_%-?%d+_%-?%d+_%-?%d+$")
                                    and StateManager.GetBuilding(existingBid) then
                                canonFound = existingBid
                                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                    "[ChunkTracker] B-109 Canonical recovery: %s → %s (from genData.connectedBuildings)",
                                    buildingPoolID, existingBid), "Fuel")
                                break
                            end
                        end
                    end
                    -- Try 2: Check if stale building already exists and was migrated to canonical
                    if not canonFound then
                        local staleEntry = StateManager.GetBuilding(buildingPoolID)
                        if staleEntry and staleEntry.id ~= buildingPoolID
                                and string.match(staleEntry.id, "^bld_%-?%d+_%-?%d+_%-?%d+$") then
                            -- Stale entry was renamed to canonical by prior ID migration
                            canonFound = staleEntry.id
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                "[ChunkTracker] B-109 Canonical recovery: %s → %s (stale entry was migrated)",
                                buildingPoolID, canonFound), "Fuel")
                        end
                    end
                    -- Try 3: Search all canonical buildings for one that contains OTHER generators
                    -- with the SAME stale buildingPoolID. This handles cross-chunk splits where
                    -- Chunk A's pool-owner migrated bld_def_X → bld_canonical, and Chunk B's
                    -- non-owners haven't migrated yet but should link to the same canonical building.
                    if not canonFound then
                        local allGens = StateManager.GetAllGenerators() or {}
                        local genKeysWithSameStaleId = {}  -- [genKey] = true for gens sharing this stale ID
                        for gid, gd in pairs(allGens) do
                            if gd.connectedBuildings then
                                for _, gbid in pairs(gd.connectedBuildings) do
                                    if gbid == buildingPoolID then
                                        local gk2 = gd.id and string.match(gd.id, "gen_([%d_]+)$")
                                        if gk2 then genKeysWithSameStaleId[gk2] = true end
                                    end
                                end
                            end
                        end
                        -- Now search all canonical buildings for one that owns any of those generators
                        local allBlds = StateManager.GetAllBuildings() or {}
                        for cBid, cBld in pairs(allBlds) do
                            if string.match(cBid, "^bld_%-?%d+_%-?%d+_%-?%d+$") and cBld.connectedGenerators then
                                for _, cgk in pairs(cBld.connectedGenerators) do
                                    if genKeysWithSameStaleId[cgk] then
                                        canonFound = cBid
                                        LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                            "[ChunkTracker] B-109 Canonical recovery: %s → %s (cross-chunk match via gen %s)",
                                            buildingPoolID, cBid, cgk), "Fuel")
                                        break
                                    end
                                end
                                if canonFound then break end
                            end
                        end
                    end
                    -- Apply recovered canonical ID
                    if canonFound then
                        md.Gen_BuildingPoolID = canonFound
                        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                            obj:transmitModData()
                        end
                        buildingPoolID = canonFound
                    end
                end
                -- ─────────────────────────────────────────────────────────────────────

                local genKey = string.format("%d_%d_%d", gx, gy, gz)

                -- Create / refresh the generator entry in StateManager
                if not genData then
                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                        string.format("[ChunkTracker] V1-restore: %s → pool %s missing from state, rebuilding", genId, buildingPoolID),
                        "Fuel")

                    local ok, gd = pcall(LKS_EletricidadeConstrucao.Data.Generator.New, obj)
                    if ok and gd then
                        genData = gd
                    else
                        genData = {
                            id = genId, x = gx, y = gy, z = gz,
                            activated = obj:isActivated(),
                            fuelAmount = obj:getFuel() or 0,
                            condition  = obj:getCondition() or 100,
                            chunkKey = LKS_EletricidadeConstrucao.Utils.Geometry.GetChunkKey(gx, gy),
                            lastUpdateTime = getTimestampMs(),
                        }
                    end
                    genData.connectedBuildings = { buildingPoolID }
                    StateManager.AddGenerator(genData)
                else
                    -- Generator already tracked – just ensure the building back-link is present
                    genData.connectedBuildings = genData.connectedBuildings or {}
                    local seen = false
                    -- NOTE: pairs() is required here, not ipairs().  After GlobalModData
                    -- deserialization in Kahlua (PZ's Lua VM) array-style tables may carry
                    -- string numeric keys ("1", "2", …) instead of integer keys.  ipairs()
                    -- stops at the first hole / string key and would return nothing,
                    -- leaving seen=false on every chunk-return and inserting duplicates. (B-71)
                    for _, b in pairs(genData.connectedBuildings) do
                        if b == buildingPoolID then seen = true; break end
                    end
                    if not seen then
                        table.insert(genData.connectedBuildings, buildingPoolID)
                    end
                    -- ALWAYS flush genData back to the generator index so that the
                    -- post-B-49-migration connectedBuildings (now canonical bld_X_Y_Z)
                    -- is persisted.  Previously only MarkDirty() was called here, which
                    -- updated the main state blob but left the generator index stale.
                    -- On the next startup Load()+HydrateGeneratorsFromIndex would then
                    -- restore generators with the OLD bld_def_... IDs, causing
                    -- "Building not found" failures for every ForceUpdateBuilding call.
                    StateManager.AddGenerator(genData)
                end

                -- ----------------------------------------------------------
                -- Run the same building-scan flow as ConnectBuilding so that
                -- powerConsumers is populated with real data, not a stub.
                -- ----------------------------------------------------------
                local Scanner = LKS_EletricidadeConstrucao.Building
                                 and LKS_EletricidadeConstrucao.Building.Scanner
                -- B-111: After B-109 ID recovery, the building might still exist under the
                -- STALE ID (B-107 Purge hasn't run yet). Check both canonical and stale IDs
                -- to avoid creating an empty stub when good data exists under the old ID.
                local bldData  = StateManager.GetBuilding(buildingPoolID)
                
                -- If canonical not found AND we recovered a different ID (B-109 changed it),
                -- check the ORIGINAL stale ID from IsoObject before creating an empty stub.
                if not bldData and originalBuildingID and originalBuildingID ~= buildingPoolID then
                    local staleBld = StateManager.GetBuilding(originalBuildingID)
                    if staleBld and staleBld.powerConsumers and not LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(staleBld.powerConsumers) then
                        -- B-111-consumer-fix: Create canonical building immediately as copy of stale.
                        -- Don't just reference stale, because Purge will delete it later and
                        -- generators would be linked to deleted building. Copy data now.
                        -- CRITICAL: Deep copy powerConsumers, not just reference it!
                        local copiedConsumers = {}
                        for consKey, consData in pairs(staleBld.powerConsumers) do
                            copiedConsumers[consKey] = consData
                        end
                        
                        bldData = {
                            id = buildingPoolID,  -- Use canonical ID
                            x = staleBld.x,
                            y = staleBld.y,
                            z = staleBld.z,
                            connectedGenerators = {},  -- Will be populated below
                            isPowered = staleBld.isPowered,
                            powerConsumers = copiedConsumers,  -- Deep copy, not reference
                            totalPowerDraw = staleBld.totalPowerDraw,
                            heatingPowerDraw = staleBld.heatingPowerDraw,
                            heatingEnabled = staleBld.heatingEnabled,
                            heatingSourceCount = staleBld.heatingSourceCount,
                            heatingTargetTemp = staleBld.heatingTargetTemp,
                        }
                        StateManager.AddBuilding(bldData)
                        _pendingBuildingUpdates[buildingPoolID] = true  -- Queue for UI update
                        local consCount = 0
                        if staleBld.powerConsumers then
                            for _ in pairs(staleBld.powerConsumers) do consCount = consCount + 1 end
                        end
                        LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                            "[ChunkTracker] B-111: Created canonical %s with %d consumers from stale %s",
                            buildingPoolID, consCount, originalBuildingID), "Fuel")
                    end
                end
                
                local needScan = not bldData
                              or not bldData.powerConsumers
                              or LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(bldData.powerConsumers)

                -- ── PENDING-STATE SCAN GUARD ──────────────────────────────────────────
                -- When ConfirmAndLoadState() hasn't run yet (state still "pending"),
                -- world squares may not all be settled (server not fully started, some
                -- chunks still streaming in).  Running ScanBuilding now could produce a
                -- partial consumer count for buildings that span multiple chunks.
                -- Fix: create a minimal stub; ConfirmAndLoadState() calls
                -- HandleStartupGeneratorRefresh() after Load(), which re-enters this
                -- path with state = "loaded" and needScan = true (Option A / B-99:
                -- powerConsumers are never saved so the building always starts empty),
                -- triggering a full scan once the world is stable.
                if needScan and StateManager.IsStateLoaded and not StateManager.IsStateLoaded() then
                    LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                        "[ChunkTracker] State pending – deferring scan for %s (ConfirmAndLoadState will supply full data)",
                        buildingPoolID), "Fuel")
                    if not bldData then
                        -- B-104: Decode building origin from the canonical ID instead of
                        -- using generator coords.  Generator squares are outside the
                        -- building walls so scanning from gx/gy never finds a light switch.
                        local bx0, by0, bz0s = string.match(buildingPoolID, "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        bldData = {
                            id = buildingPoolID,
                            x = bx0 and tonumber(bx0) or gx,
                            y = by0 and tonumber(by0) or gy,
                            z = bz0s and tonumber(bz0s) or gz,
                            connectedGenerators = {},
                            isPowered = false,
                            powerConsumers = {},
                            totalPowerDraw = 0,
                            heatingPowerDraw = 0,
                        }
                        StateManager.AddBuilding(bldData)
                    end
                    needScan = false  -- defer to GlobalModData load
                end
                -- ─────────────────────────────────────────────────────────────────────

                if needScan and Scanner and Scanner.ScanBuilding then
                    -- Find a nearby building square (generator sits outside walls)
                    local bldSq = nil
                    if square:getBuilding() then
                        bldSq = square
                    else
                        local dirs = {
                            IsoDirections.N, IsoDirections.S, IsoDirections.E, IsoDirections.W,
                            IsoDirections.NE, IsoDirections.NW, IsoDirections.SE, IsoDirections.SW,
                        }
                        for _, dir in ipairs(dirs) do
                            local adj = square:getAdjacentSquare(dir)
                            if adj and adj:getBuilding() then bldSq = adj; break end
                        end
                    end

                    if bldSq then
                        local building = bldSq:getBuilding()
                        local def = building and building.getDef and building:getDef()
                        local rooms = def and def.getRooms and def:getRooms()
                        local lsX, lsY, lsZ

                        -- Search rooms for a light switch (identical to ConnectBuilding)
                        if rooms then
                            for ri = 0, rooms:size() - 1 do
                                local room = rooms:get(ri)
                                if room and not lsX then
                                    for rx = room:getX(), room:getX2() do
                                        for ry = room:getY(), room:getY2() do
                                            local sq2 = getCell():getGridSquare(rx, ry, gz)
                                            if sq2 then
                                                local objs2 = sq2:getObjects()
                                                for oi = 0, objs2:size() - 1 do
                                                    local o2 = objs2:get(oi)
                                                    if o2 and instanceof(o2, "IsoLightSwitch") then
                                                        lsX, lsY, lsZ = rx, ry, gz
                                                        break
                                                    end
                                                end
                                            end
                                            if lsX then break end
                                        end
                                        if lsX then break end
                                    end
                                end
                                if lsX then break end
                            end
                        end

                        if lsX then
                            -- ── CANONICAL ID MIGRATION FROM LIGHT-SWITCH ────────────
                            -- Only migrate stale IDs (bld_def_... or other legacy formats).
                            -- If buildingPoolID is already canonical (bld_X_Y_Z), do NOT
                            -- trust the room-scan's lsX: a generator between two buildings
                            -- may find the adjacent building's light switch first, producing
                            -- a wrong derivedCanonicalId that would overwrite the correct
                            -- saved ID.  For canonical IDs, override lsX/Y/Z with the
                            -- coordinates encoded in the ID itself so the scan targets the
                            -- correct building regardless of which adjacent square PZ
                            -- happened to return first.
                            local isStaleId = not string.match(buildingPoolID, "^bld_%-?%d+_%-?%d+_%-?%d+$")
                            if not isStaleId then
                                -- Already canonical – re-anchor lsX/Y/Z from the ID
                                local bx, by, bz = string.match(buildingPoolID, "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                                if bx then
                                    lsX, lsY, lsZ = tonumber(bx), tonumber(by), tonumber(bz)
                                end
                            end
                            local derivedCanonicalId = LKS_EletricidadeConstrucao.Data.Building.MakeId(lsX, lsY, lsZ)
                            if isStaleId and derivedCanonicalId ~= buildingPoolID then
                                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                    "[ChunkTracker] LS-migration: gen=%s stale=%s → canonical=%s",
                                    genId, buildingPoolID, derivedCanonicalId), "Fuel")

                                -- Stamp the canonical ID on the IsoObject
                                md.Gen_BuildingPoolID = derivedCanonicalId
                                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                    obj:transmitModData()
                                end

                                -- Update genData.connectedBuildings
                                if genData and genData.connectedBuildings then
                                    for i, bid in pairs(genData.connectedBuildings) do
                                        if bid == buildingPoolID then
                                            genData.connectedBuildings[i] = derivedCanonicalId
                                        end
                                    end
                                    StateManager.AddGenerator(genData)
                                end

                                -- Transfer heatingEnabled/sourceCount/targetTemp from stale
                                -- building entry to canonical (if canonical lacks them and
                                -- stale has them) so the next heating sync finds correct data.
                                -- B-111-heating-fix: Check heatingSourceCount instead of heatingEnabled,
                                -- because canonical might have heatingEnabled=false (IsoObject default)
                                -- while stale has heatingEnabled=true + heatingSourceCount>0 (GlobalModData).
                                local staleEntry = StateManager.GetBuilding(buildingPoolID)
                                local canonEntry = StateManager.GetBuilding(derivedCanonicalId)
                                if staleEntry and canonEntry then
                                    local canonHasNoSources = not canonEntry.heatingSourceCount or canonEntry.heatingSourceCount == 0
                                    local staleHasSources = staleEntry.heatingSourceCount and staleEntry.heatingSourceCount > 0
                                    if canonHasNoSources and staleHasSources then
                                        canonEntry.heatingEnabled     = staleEntry.heatingEnabled
                                        canonEntry.heatingSourceCount = staleEntry.heatingSourceCount
                                        canonEntry.heatingTargetTemp  = staleEntry.heatingTargetTemp
                                    end
                                    -- Move connectedGenerators from stale to canonical
                                    if staleEntry.connectedGenerators then
                                        canonEntry.connectedGenerators = canonEntry.connectedGenerators or {}
                                        for _, gk in pairs(staleEntry.connectedGenerators) do
                                            local exists = false
                                            for _, ek in pairs(canonEntry.connectedGenerators) do
                                                if ek == gk then exists = true; break end
                                            end
                                            if not exists then
                                                table.insert(canonEntry.connectedGenerators, gk)
                                            end
                                        end
                                    end
                                    -- B-111-consumer-fix: Merge powerConsumers from stale to canonical
                                    if staleEntry.powerConsumers then
                                        canonEntry.powerConsumers = canonEntry.powerConsumers or {}
                                        for consKey, consData in pairs(staleEntry.powerConsumers) do
                                            if not canonEntry.powerConsumers[consKey] then
                                                canonEntry.powerConsumers[consKey] = consData
                                            end
                                        end
                                        -- Recalculate power draw totals after merge
                                        local totalDraw = 0
                                        local heatingDraw = 0
                                        for _, cons in pairs(canonEntry.powerConsumers) do
                                            if cons.powerDraw then
                                                totalDraw = totalDraw + cons.powerDraw
                                                if cons.isHeater then
                                                    heatingDraw = heatingDraw + cons.powerDraw
                                                end
                                            end
                                        end
                                        canonEntry.totalPowerDraw = totalDraw
                                        canonEntry.heatingPowerDraw = heatingDraw
                                        -- Queue for UI update
                                        _pendingBuildingUpdates[derivedCanonicalId] = true
                                    end
                                    StateManager.RemoveBuilding(buildingPoolID)
                                end

                                buildingPoolID = derivedCanonicalId
                            end
                            -- ─────────────────────────────────────────────────────────

                            -- B-111-consumer-fix: After migration, check if canonical building
                            -- now has consumers (merged from stale). If so, skip scan to avoid
                            -- overwriting merged data with fresh empty building.
                            local canonicalBldData = StateManager.GetBuilding(buildingPoolID)
                            local alreadyHasConsumers = canonicalBldData
                                                     and canonicalBldData.powerConsumers
                                                     and not LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(canonicalBldData.powerConsumers)
                            
                            if alreadyHasConsumers then
                                bldData = canonicalBldData  -- Use canonical with merged consumers
                            end
                            
                            if not alreadyHasConsumers then
                                LKS_EletricidadeConstrucao.Core.Logger.Debug(string.format("[ChunkTracker] V1-restore: scanning building %s from light-switch (%d,%d,%d)",
                                    buildingPoolID, lsX, lsY, lsZ), "Fuel")
                                local scanned = pcall(function()
                                    bldData = Scanner.ScanBuilding(lsX, lsY, lsZ, buildingPoolID)
                                end)
                                if bldData then
                                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                                        string.format("[ChunkTracker] V1-restore: scan complete for %s (%d consumers)",
                                            buildingPoolID, bldData.powerConsumers and #bldData.powerConsumers or 0),
                                        "Fuel")
                                end
                            else
                                LKS_EletricidadeConstrucao.Core.Logger.Info(
                                    string.format("[ChunkTracker] V1-restore: skipping scan for %s (already has %d consumers from merge)",
                                        buildingPoolID, bldData.powerConsumers and #bldData.powerConsumers or 0),
                                    "Fuel")
                            end
                        else
                            -- No light switch found – ensure at least a basic stub exists
                            if not bldData then
                                bldData = {
                                    id = buildingPoolID,
                                    x = gx, y = gy, z = gz,
                                    connectedGenerators = {},
                                    isPowered = false,
                                    powerConsumers = {},
                                    totalPowerDraw = 0,
                                    heatingPowerDraw = 0,
                                }
                                StateManager.AddBuilding(bldData)
                            end
                        end
                    else
                        -- No adjacent IsoBuilding found.
                        -- This is normal for player-built structures: getBuilding() always
                        -- returns nil for player-placed tiles, so the room-scan path above
                        -- never finds a light switch.
                        -- Use the light-switch coordinates stored in LKS_EletricidadeConstrucao_PoolData (written by
                        -- StateManager.Save()) to run a direct ScanBuilding instead.
                        local lsX2, lsY2, lsZ2

                        -- 1) LKS_EletricidadeConstrucao_PoolData.x/y/z is the light switch anchor saved on the owner gen
                        if md.LKS_EletricidadeConstrucao_PoolData and md.LKS_EletricidadeConstrucao_PoolData.x and md.LKS_EletricidadeConstrucao_PoolData.y and md.LKS_EletricidadeConstrucao_PoolData.z then
                            lsX2 = md.LKS_EletricidadeConstrucao_PoolData.x
                            lsY2 = md.LKS_EletricidadeConstrucao_PoolData.y
                            lsZ2 = md.LKS_EletricidadeConstrucao_PoolData.z
                        end

                        -- 2) Fallback: parse coordinates from bld_X_Y_Z ID format
                        if not lsX2 then
                            local bx, by, bz = string.match(buildingPoolID, "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                            if bx then
                                lsX2, lsY2, lsZ2 = tonumber(bx), tonumber(by), tonumber(bz)
                            end
                        end

                                -- B-111-consumer-fix: Check if CANONICAL building has consumers before
                        -- scanning. bldData might be the stale reference, so check canonical ID.
                        local canonicalBldData = StateManager.GetBuilding(buildingPoolID)
                        local alreadyHasConsumers = canonicalBldData
                                                 and canonicalBldData.powerConsumers
                                                 and not LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(canonicalBldData.powerConsumers)
                        if alreadyHasConsumers then
                            bldData = canonicalBldData  -- Use canonical, not stale
                        end

                        if lsX2 and Scanner and Scanner.ScanBuilding and not alreadyHasConsumers then
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                "[ChunkTracker] V1-restore (player-built): scanning %s from stored light-switch (%d,%d,%d)",
                                buildingPoolID, lsX2, lsY2, lsZ2), "Fuel")
                            local ok2 = pcall(function()
                                bldData = Scanner.ScanBuilding(lsX2, lsY2, lsZ2, buildingPoolID)
                            end)
                            if bldData then
                                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                    "[ChunkTracker] V1-restore (player-built): scan complete for %s (%d consumers)",
                                    buildingPoolID, bldData.powerConsumers and #bldData.powerConsumers or 0), "Fuel")
                            end
                        elseif not bldData then
                            -- Last resort: create a stub so at least the building exists in state
                            bldData = {
                                id = buildingPoolID,
                                x = lsX2 or gx, y = lsY2 or gy, z = lsZ2 or gz,
                                connectedGenerators = {},
                                isPowered = false,
                                powerConsumers = {},
                                totalPowerDraw = 0,
                                heatingPowerDraw = 0,
                            }
                            StateManager.AddBuilding(bldData)
                        end
                    end
                elseif not bldData then
                    -- Scanner not available or consumers already populated – ensure entry exists
                    bldData = {
                        id = buildingPoolID,
                        x = gx, y = gy, z = gz,
                        connectedGenerators = {},
                        isPowered = false,
                        powerConsumers = {},
                        totalPowerDraw = 0,
                        heatingPowerDraw = 0,
                    }
                    StateManager.AddBuilding(bldData)
                end

                -- Re-fetch (ScanBuilding may have replaced the table reference)
                bldData = StateManager.GetBuilding(buildingPoolID) or bldData

                -- ── HEATING SYNC: IsoObject → in-memory (Option A / B-99) ─────────────
                -- B-110: Only apply IsoObject heating state when the building's heating
                -- config is uninitialized (nil). Once the building has heating state
                -- (from GlobalModData or first generator in a multi-gen pool), don't let
                -- subsequent generators' IsoObject values overwrite it.
                --
                -- Multi-gen issue: Gen1 loads with md.HeatingEnabled=true, sets building
                -- to true. Gen2 loads later with md.HeatingEnabled=false, would overwrite
                -- to false. But heatingSourceCount (from GlobalModData) is already set to
                -- 3, creating inconsistent state (heating OFF, sources ON). Fix: first
                -- generator to load wins, subsequent generators are ignored.
                if bldData then
                    if bldData.heatingEnabled == nil then
                        -- Building has no heating state yet, populate from IsoObject
                        if md.HeatingEnabled ~= nil then
                            bldData.heatingEnabled    = md.HeatingEnabled
                            bldData.heatingTargetTemp = md.HeatingTargetTemp or 22.0
                        else
                            -- IsoObject has no heating stamp → fresh generator, default to off
                            bldData.heatingEnabled    = false
                            bldData.heatingTargetTemp = 22.0
                        end
                    end
                    -- else: building already has heating state (from GlobalModData or
                    -- prior generator), don't overwrite from this generator's IsoObject
                end
                -- ─────────────────────────────────────────────────────────────────────

                -- Ensure bidirectional link: building.connectedGenerators → genKey
                if bldData then
                    bldData.connectedGenerators = bldData.connectedGenerators or {}
                    local alreadyLinked = false
                    -- connectedGenerators is Kahlua-deserialized (string numeric keys); use pairs
                    for _, k in pairs(bldData.connectedGenerators) do
                        if k == genKey then alreadyLinked = true; break end
                    end
                    if not alreadyLinked then
                        table.insert(bldData.connectedGenerators, genKey)
                    end
                end

                -- Option A (B-99): LKS_EletricidadeConstrucao_PoolData seeding removed.  Building geometry
                -- (boundingBox, borderRadius, isRVInterior) is supplied by ScanBuilding
                -- and does not need to be back-filled from IsoObject secondary storage.

                StateManager.MarkDirty()
                end -- close else (world ID valid path)
            end -- close if md.Gen_BuildingPoolID
        end
    end
end
-- ============================================================================

--- Handle chunk load event
--- OPTIMIZED: Chunk-level deduplication prevents processing same chunk 100 times
--- @param square IsoGridSquare Grid square that was loaded
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.OnLoadGridsquare(square)
    if not square then
        return
    end

    -- Safety check: ensure required modules are loaded
    if not LKS_EletricidadeConstrucao.Core or not LKS_EletricidadeConstrucao.Core.StateManager then
        return
    end

    local Geometry = LKS_EletricidadeConstrucao.Utils.Geometry
    local x = square:getX()
    local y = square:getY()
    
    -- Get chunk key
    local chunkKey = Geometry.GetChunkKey(x, y)
    
    -- OPTIMIZATION: Chunk-level deduplication (OnLoadGridsquare fires 100 times per 10x10 chunk)
    if _processedChunks[chunkKey] then
        return  -- Already processed this chunk
    end
    _processedChunks[chunkKey] = true
    
    -- Record load time
    _chunkLoadTimes[chunkKey] = getTimestampMs()
    
    LKS_EletricidadeConstrucao.Core.Logger.Trace(
        string.format("Chunk loaded: %s at (%d,%d)", chunkKey, x, y),
        "Fuel"
    )
    
    -- V1-style: restore generator → building links from IsoObject ModData.
    -- IMPORTANT (B-55): We must scan ALL squares in the chunk, not just the first one.
    -- The chunk dedup guard above fires on whichever square happens to arrive first –
    -- that square is almost never the one a generator sits on.  If neither generator
    -- is on the first-processed square then TryRestoreFromIsoModData finds no
    -- IsoGenerator, the building is never added to state, and ForceUpdateBuilding
    -- later fails with "Building not found" → building stays unpowered.
    --
    -- Strategy: scan the first square immediately (covers the common case of a
    -- generator AT that square with zero extra cost), then walk all 100 squares
    -- in the chunk and call TryRestoreFromIsoModData only on squares that
    -- actually contain an IsoGenerator.  IsoGenerators are rare so the inner
    -- instanceof check exits fast for the vast majority of squares.
    -- Only restore if building isn't already established (skip on healthy chunk-returns)
    if NeedsIsoRestore(square) then
        pcall(TryRestoreFromIsoModData, square)
    end

    do
        local chunkBaseX = math.floor(x / 10) * 10
        local chunkBaseY = math.floor(y / 10) * 10
        local z          = square:getZ()
        local cell       = getCell and getCell()
        if cell then
            for dx = 0, 9 do
                for dy = 0, 9 do
                    local sq2 = cell:getGridSquare(chunkBaseX + dx, chunkBaseY + dy, z)
                    if sq2 and sq2 ~= square then
                        local objs2 = sq2:getObjects()
                        if objs2 then
                            for oi = 0, objs2:size() - 1 do
                                local o2 = objs2:get(oi)
                                if o2 and instanceof(o2, "IsoGenerator") then
                                    -- Guard: skip if building already healthy in state (B-71)
                                    if NeedsIsoRestore(sq2) then
                                        pcall(TryRestoreFromIsoModData, sq2)
                                    end
                                    break  -- Only one call per square needed
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Check for generators in this chunk
    LKS_EletricidadeConstrucao.Fuel.ChunkTracker.ProcessChunkGenerators(chunkKey, x, y)
end

--- Handle chunk unload event
--- @param square IsoGridSquare Grid square that was unloaded
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.OnUnloadGridsquare(square)
    if not square then
        return
    end
    
    local Geometry = LKS_EletricidadeConstrucao.Utils.Geometry
    local x = square:getX()
    local y = square:getY()
    
    -- Get chunk key
    local chunkKey = Geometry.GetChunkKey(x, y)
    
    -- OPTIMIZATION: Chunk-level deduplication for unload (only process once)
    if not _processedChunks[chunkKey] then
        return  -- Never processed this chunk on load, skip unload
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Trace(
        string.format("Chunk unloading: %s at (%d,%d)", chunkKey, x, y),
        "Fuel"
    )
    
    -- NOTE: Fuel consumption continues on GlobalModData regardless of chunk load status.
    -- No need to track unload time or catch up on reload - fuel is always up to date.
    
    -- Remove chunk from tracking
    _chunkLoadTimes[chunkKey] = nil
    _processedChunks[chunkKey] = nil
end

-- ============================================================================
-- GENERATOR PROCESSING
-- ============================================================================

--- Process all generators in chunk when it loads
--- @param chunkKey string Chunk key
--- @param x number Sample X coordinate in chunk
--- @param y number Sample Y coordinate in chunk
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.ProcessChunkGenerators(chunkKey, x, y)
    -- Safety check: ensure required modules are loaded
    if not LKS_EletricidadeConstrucao.Core or not LKS_EletricidadeConstrucao.Core.StateManager then
        return
    end
    if not LKS_EletricidadeConstrucao.Config then
        return
    end

    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local Config = LKS_EletricidadeConstrucao.Config

    -- Get all generators in this chunk (needed for both fuel and UI refresh)
    if not StateManager.GetGeneratorsInChunk then
        return
    end
    local generators = StateManager.GetGeneratorsInChunk(chunkKey)
    if #generators == 0 then return end

    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Processing %d generators in chunk %s", #generators, chunkKey),
        "Fuel"
    )

    -- Sync IsoObject fuel with GlobalModData (which is continuously updated regardless of chunk status)
    -- No catch-up needed: fuel calculation runs on GlobalModData even when chunk is unloaded
    local needsPowerUpdate = false
    local affectedBuildings = {}  -- Track buildings that need power refresh
    
    for _, genData in ipairs(generators) do
        local genObject = getGeneratorFromSquare(genData.x, genData.y, genData.z)
        if genObject then
            local stateFuel = genData.fuelAmount or 0
            local liveFuel = genObject:getFuel() or 0
            -- B-111: Don't treat activated=nil as false. Per B-36, nil means "implicitly active"
            -- (only explicit false means deactivated). This prevents random generators from being
            -- turned off during off-chunk restoration when they have nil activation state.
            local stateActivated = genData.activated  -- nil, true, or false
            local liveActivated = genObject:isActivated() or false
            
            -- Sync fuel state to IsoObject for UI display (state is always authoritative)
            -- Also reset lastSyncedFuel so Update()'s refuel-detection sees the correct baseline.
            if liveFuel ~= stateFuel then
                genObject:setFuel(stateFuel)
                LKS_EletricidadeConstrucao.Core.Logger.Debug(
                    string.format("Chunk-load fuel sync: generator %s %.3f -> %.3f", 
                        genData.id, liveFuel, stateFuel),
                    "Fuel"
                )
            end
            genData.lastSyncedFuel = stateFuel

            -- If generator has no fuel, force-deactivate the IsoObject regardless of live state.
            -- This ensures isBuildingPoweredInline returns false immediately after chunk loads.
            if stateFuel <= 0 and liveActivated then
                genObject:setActivated(false)
                genData.activated = false
                needsPowerUpdate = true
                if genData.connectedBuildings then
                    -- connectedBuildings is Kahlua-deserialized (string numeric keys)
                    for _, bid in pairs(genData.connectedBuildings) do
                        affectedBuildings[bid] = true
                    end
                end
                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("Chunk-load: force-deactivated generator %s (no fuel)", genData.id),
                    "Fuel"
                )
            end
            
            -- B-111: Only sync activation when state is EXPLICITLY set to false (not nil)
            -- AND generator has fuel. If generator has fuel but state says false, it might
            -- be stale (ran out of fuel off-chunk, got refueled, but activated flag wasn't
            -- reset). Trust the IsoObject in that case.
            if stateActivated == false and stateFuel > 0 and liveActivated then
                -- State says deactivated, but generator has fuel and IsoObject says active.
                -- This suggests the generator ran dry off-chunk (activated→false) then was
                -- refueled, but activated flag wasn't reset. Trust IsoObject, fix state.
                genData.activated = true
                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("Chunk-load: generator %s has fuel (%.2f) and IsoObject active, correcting stale activated=false in state",
                        genData.id, stateFuel),
                    "Fuel"
                )
            elseif stateActivated ~= nil and stateActivated ~= liveActivated then
                -- State is explicitly set (not nil) and differs from IsoObject.
                -- Only sync if generator has no fuel OR state says activate.
                if stateFuel <= 0 or stateActivated == true then
                    genObject:setActivated(stateActivated)
                    needsPowerUpdate = true
                end
                
                -- Add all connected buildings to refresh list
                if genData.connectedBuildings then
                    -- connectedBuildings is Kahlua-deserialized (string numeric keys)
                    for _, bid in pairs(genData.connectedBuildings) do
                        affectedBuildings[bid] = true
                    end
                end
                
                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("Chunk-load activation sync: generator %s %s -> %s (fuel: %.2f)", 
                        genData.id, tostring(liveActivated), tostring(stateActivated), stateFuel),
                    "Fuel"
                )
            end
        end
    end
    
    -- If any generator changed activation state, immediately update power distribution
    -- for affected buildings. This ensures ApplyTilePower runs NOW that chunk is loaded.
    if needsPowerUpdate then
        local Dist = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
        if Dist and Dist.ForceUpdateBuilding then
            local updateCount = 0
            for bid in pairs(affectedBuildings) do
                pcall(Dist.ForceUpdateBuilding, bid)
                updateCount = updateCount + 1
            end
            LKS_EletricidadeConstrucao.Core.Logger.Info(
                string.format("Updated power for %d buildings after generator state sync", updateCount),
                "Fuel"
            )
        end
    end

    -- Defer the ForceUpdateBuilding calls by ~30 ticks (~2 s at 15 fps) so that
    -- adjacent chunks containing the building's interior squares have time to
    -- load before we try to read appliance/light isActive state.
    -- V1 pattern: create a self-removing local closure per chunk-load event.
    -- Never register a persistent module-level OnTick handler (causes nil-call
    -- crashes in Kahlua when the module reference isn't fully resolved yet).
    local buildingIds = {}
    for _, genData in ipairs(generators) do
        -- connectedBuildings is Kahlua-deserialized after GlobalModData reload
        -- (string numeric keys). ipairs returns nothing on such tables. Use pairs.
        for _, bid in pairs(genData.connectedBuildings or {}) do
            buildingIds[bid] = true   -- dedup
        end
    end

    local _hasBids2 = false
    for _ in pairs(buildingIds) do _hasBids2 = true; break end
    if _hasBids2 then
        -- Collect this chunk's generator coordinates for the deferred rescan.
        -- We capture them NOW while the data is in scope; the batch timer drains them.
        for _, genData in ipairs(generators) do
            _pendingGenRescans[genData.id] = { x = genData.x, y = genData.y, z = genData.z }
        end

        -- OPTIMIZATION: Use global batch timer instead of creating per-chunk timer closures
        -- Add buildings to pending batch
        -- B-111-offchunk-resync: Always add buildings when their generator chunks load,
        -- even if they were processed at startup. At startup, generators might not have
        -- been reachable (getSquare returned nil), so stats never got synced to ModData.
        -- Now that chunks are loaded, we need to retry the sync.
        local addedCount = 0
        for bid in pairs(buildingIds) do
            if not _pendingBuildingUpdates[bid] then
                _pendingBuildingUpdates[bid] = true
                -- Don't check _scheduledBuildingUpdates - allow reprocessing
                addedCount = addedCount + 1
                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("[ChunkLoad] Added building %s to batch queue (generator chunk loaded)", bid),
                    "Fuel")
            end
        end

        -- Start global batch timer if not already running
        if addedCount > 0 and not _batchTimerActive then
            _batchTimerActive = true
            local ticksLeft = 30  -- ~2 s delay
            local timerFunc
            timerFunc = function()
                ticksLeft = ticksLeft - 1
                if ticksLeft > 0 then return end

                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("[ChunkTracker] Batch timer fired after 30 ticks"),
                    "Fuel")
                Events.OnTick.Remove(timerFunc)
                _batchTimerActive = false

                -- Phase 1a: run TryRestoreFromIsoModData on each generator's own
                -- square so that StateManager links and building stubs exist
                -- before the consumer rescan below runs.
                --
                -- B-101: Only clear _pendingGenRescans entries whose squares are
                -- actually loaded.  Previously the entry was always cleared even when
                -- getSquare() returned nil (chunk not yet streamed in), permanently
                -- abandoning that generator -- its IsoObject moddata was never updated
                -- to the canonical bld_X_Y_Z ID, causing the info window and
                -- requestFreshStats to use a stale bld_def_... ID against a StateManager
                -- entry that no longer existed under that key.
                local rescanCount = 0
                local processedGenIds = {}
                for genId, coord in pairs(_pendingGenRescans) do
                    local gSq = getSquare(coord.x, coord.y, coord.z)
                    if gSq then
                        -- Guard: skip TryRestore if building already established (B-71)
                        if NeedsIsoRestore(gSq) then
                            pcall(TryRestoreFromIsoModData, gSq)
                            rescanCount = rescanCount + 1
                        end
                        processedGenIds[genId] = true
                        _pendingGenRescans[genId] = nil  -- only remove when square was loaded
                    end
                    -- If gSq is nil the entry is kept so the next batch cycle retries it.
                end
                if rescanCount > 0 then
                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                        string.format("[ChunkTracker] Batch rescan: rescanned %d generator square(s) before ForceUpdate",
                            rescanCount), "Fuel")
                end

                -- B-107: Multi-generator building duplicate cleanup after chunk-load rescan.
                -- TryRestoreFromIsoModData may create stale bld_def_... entries if a generator's
                -- IsoObject wasn't updated by PurgeStaleBuildingDuplicates at startup (generator
                -- was in an unloads chunk). Run Purge here to merge any new duplicates before
                -- Phase 1b scans them, ensuring the canonical building gets the consumer data.
                local SM_p1 = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                if SM_p1 and SM_p1.IsStateLoaded and SM_p1.IsStateLoaded() then
                    -- Collect all building IDs that need potential cleanup
                    local allBuildingIds = {}
                    for bid in pairs(_pendingBuildingUpdates) do
                        allBuildingIds[bid] = true
                    end
                    PurgeStaleBuildingDuplicates(SM_p1, allBuildingIds, _pendingBuildingUpdates)
                    -- Update _pendingBuildingUpdates to canonical IDs after purge
                    _pendingBuildingUpdates = allBuildingIds
                end

                -- Phase 1a-post: refresh _pendingBuildingUpdates with post-migration
                -- canonical IDs. TryRestoreFromIsoModData may have renamed bld_def_XXXX
                -- keys to bld_X_Y_Z; _pendingBuildingUpdates was populated before that
                -- migration so it still holds the old keys. Rebuild it now so Phase 1b
                -- and Phase 2 operate on valid, resolvable building IDs.
                -- B-111-offchunk-fix: Process ALL generators, not just rescanned ones,
                -- because generators restored from GlobalModData might not have been rescanned
                -- but still need their building links updated.
                local SM_p1a = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                if SM_p1a then
                    -- Collect canonical IDs from ALL generators in StateManager
                    local canonicalBids = {}
                    for _, gd in pairs(SM_p1a.GetAllGenerators() or {}) do
                        if gd and gd.connectedBuildings then
                            -- connectedBuildings is Kahlua-deserialized (string numeric keys); use pairs
                            for _, bid in pairs(gd.connectedBuildings) do
                                if SM_p1a.GetBuilding(bid) then
                                    canonicalBids[bid] = true
                                end
                            end
                        end
                    end
                    -- Rebuild: keep valid existing entries, drop stale ones, add canonical ones
                    local newPending = {}
                    for bid in pairs(_pendingBuildingUpdates) do
                        if SM_p1a.GetBuilding(bid) then
                            newPending[bid] = true
                        end
                        -- else: stale (e.g. bld_def_... was migrated away) - silently drop
                    end
                    for bid in pairs(canonicalBids) do
                        newPending[bid] = true
                        _scheduledBuildingUpdates[bid] = true
                    end
                    _pendingBuildingUpdates = newPending
                end

                -- Phase 1b: Always re-run ScanBuilding for every pending building
                -- whose light-switch square is now loaded.
                -- TryRestoreFromIsoModData skips ScanBuilding when powerConsumers
                -- is non-empty, so stale consumers (all isActive=false set by the
                -- off-chunk ForceUpdateBuilding) would persist without this step.
                -- A fresh scan is cheap (border detection + object walk) and
                -- ensures strain, UI consumer counts, and fuel rate are all
                -- recalculated from live world state the moment the chunk loads.
                --
                -- B-83: Only call ScanBuilding when the ENTIRE building area is
                -- loaded.  Large buildings span multiple chunks; if any chunk is
                -- still unloaded getSquare() returns nil for its tiles and
                -- ClearConsumers + ScanConsumers would permanently lose those
                -- consumers.  IsBuildingAreaLoaded checks all bounding-box
                -- corners (5 samples) – cheap and sufficient.
                local Scanner = LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner
                local SM = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                if Scanner and Scanner.ScanBuilding and SM then
                    local bldRescanCount = 0
                    local bldSkipCount   = 0
                    for bid in pairs(_pendingBuildingUpdates) do
                        local bld = SM.GetBuilding(bid)
                        if bld and bld.x and bld.y then
                            local lsX, lsY, lsZ = bld.x, bld.y, bld.z or 0
                            local lsSq = getSquare(lsX, lsY, lsZ)
                            if lsSq then
                                -- Only rescan when every chunk in the building footprint is loaded.
                                local areaLoaded = (not Scanner.IsBuildingAreaLoaded)
                                    or Scanner.IsBuildingAreaLoaded(bld)
                                if areaLoaded then
                                    -- Square is loaded and area is fully loaded - rescan to get fresh consumer list
                                    local ok = pcall(function()
                                        Scanner.ScanBuilding(lsX, lsY, lsZ, bid)
                                    end)
                                    if ok then
                                        bldRescanCount = bldRescanCount + 1
                                    end
                                else
                                    -- Building area partially unloaded – skip rescan, keep saved consumer list.
                                    bldSkipCount = bldSkipCount + 1
                                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                                        string.format("[ChunkTracker] Skipping rescan for %s – partial area load",
                                            bid), "Fuel")
                                end
                            end
                        end
                    end
                    if bldRescanCount > 0 then
                        LKS_EletricidadeConstrucao.Core.Logger.Info(
                            string.format("[ChunkTracker] Chunk re-entry rescan: rebuilt consumers for %d building(s) (skipped %d partial)",
                                bldRescanCount, bldSkipCount), "Fuel")
                    end
                end

                -- Phase 2: Process all pending buildings in one batch
                local Dist = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
                local SM_p2 = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                if Dist and Dist.ForceUpdateBuilding and SM_p2 then
                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                        string.format("[ChunkTracker] Starting Phase 2: %d buildings in queue",
                            (function() local n=0; for _ in pairs(_pendingBuildingUpdates) do n=n+1 end; return n end)()),
                        "Fuel")
                    local batchCount = 0
                    local skippedCount = 0
                    for bid in pairs(_pendingBuildingUpdates) do
                        -- B-111-offchunk-fix: Verify building exists before updating.
                        -- After Purge, stale IDs might remain in queue but building was merged.
                        local bld = SM_p2.GetBuilding(bid)
                        if bld then
                            -- Log consumer count before ForceUpdateBuilding
                            local consCountBefore = 0
                            if bld.powerConsumers then
                                for _ in pairs(bld.powerConsumers) do consCountBefore = consCountBefore + 1 end
                            end
                            LKS_EletricidadeConstrucao.Core.Logger.Info(
                                string.format("[ChunkTracker] Phase 2: ForceUpdateBuilding for %s (%d consumers)", bid, consCountBefore),
                                "Fuel")
                            pcall(Dist.ForceUpdateBuilding, bid)
                            batchCount = batchCount + 1
                        else
                            skippedCount = skippedCount + 1
                            LKS_EletricidadeConstrucao.Core.Logger.Warn(
                                string.format("[ChunkTracker] Batch Phase 2: building %s not found in StateManager, skipping ForceUpdate", bid),
                                "Fuel")
                        end
                    end
                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                        string.format("[ChunkTracker] Batch Phase 2 complete: updated %d buildings (skipped %d missing)", batchCount, skippedCount),
                        "Fuel")
                end

                -- Clear batch (but don't clear _scheduledBuildingUpdates - it's no longer used)
                _pendingBuildingUpdates = {}

                -- B-101: If any generator squares were not loaded (getSquare()
                -- returned nil above), their entries still live in _pendingGenRescans.
                -- Restart a secondary timer so they are retried once the player's
                -- movement streams in the missing chunk(s).
                if TableHasEntries(_pendingGenRescans) then  -- B-106: pairs-based check (next() can be nil in Kahlua)
                    local retryCount = 0
                    for _ in pairs(_pendingGenRescans) do retryCount = retryCount + 1 end
                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                        string.format("[ChunkTracker] Batch retry queued: %d generator(s) pending (squares not yet loaded)",
                            retryCount), "Fuel")
                    _batchTimerActive = true
                    local retryTicks = 120  -- ~8 s
                    local retryFunc
                    retryFunc = function()
                        retryTicks = retryTicks - 1
                        if retryTicks > 0 then return end
                        Events.OnTick.Remove(retryFunc)
                        _batchTimerActive = false
                        local retryProcessed = 0
                        for genId, coord in pairs(_pendingGenRescans) do
                            local gSq2 = getSquare(coord.x, coord.y, coord.z)
                            if gSq2 then
                                if NeedsIsoRestore(gSq2) then
                                    pcall(TryRestoreFromIsoModData, gSq2)
                                    retryProcessed = retryProcessed + 1
                                end
                                _pendingGenRescans[genId] = nil
                            end
                        end
                        if retryProcessed > 0 then
                            LKS_EletricidadeConstrucao.Core.Logger.Info(
                                string.format("[ChunkTracker] Batch retry complete: processed %d generator(s)",
                                    retryProcessed), "Fuel")
                        end
                        if TableHasEntries(_pendingGenRescans) then  -- B-106
                            LKS_EletricidadeConstrucao.Core.Logger.Info(
                                "[ChunkTracker] Batch retry: generators still pending after retry (remote chunks?)", "Fuel")
                        end
                    end
                    Events.OnTick.Add(retryFunc)
                end
            end
            Events.OnTick.Add(timerFunc)
        end
    end
end

-- ============================================================================
-- CHUNK STATE QUERIES
-- ============================================================================

--- Check if chunk is currently loaded
--- @param chunkKey string Chunk key
--- @return boolean True if loaded
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.IsChunkLoaded(chunkKey)
    return _chunkLoadTimes[chunkKey] ~= nil
end

--- Get chunk load time
--- @param chunkKey string Chunk key
--- @return number|nil Load timestamp or nil if not loaded
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.GetChunkLoadTime(chunkKey)
    return _chunkLoadTimes[chunkKey]
end

--- Get all loaded chunks
--- @return table Array of chunk keys
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.GetLoadedChunks()
    local chunks = {}
    
    for chunkKey, _ in pairs(_chunkLoadTimes) do
        table.insert(chunks, chunkKey)
    end
    
    return chunks
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Print chunk tracker status
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.PrintStatus()
    LKS_EletricidadeConstrucao.Print("=== Chunk Tracker Status ===")
    LKS_EletricidadeConstrucao.Print("Initialized: " .. tostring(_isInitialized))
    
    local loadedChunks = LKS_EletricidadeConstrucao.Fuel.ChunkTracker.GetLoadedChunks()
    LKS_EletricidadeConstrucao.Print("Loaded Chunks: " .. #loadedChunks)
    
    for _, chunkKey in ipairs(loadedChunks) do
        local loadTime = _chunkLoadTimes[chunkKey]
        local generators = LKS_EletricidadeConstrucao.Core.StateManager.GetGeneratorsInChunk(chunkKey)
        LKS_EletricidadeConstrucao.Print(string.format("  %s: loaded at %d, %d generators",
            chunkKey, loadTime, #generators))
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Fuel.ChunkTracker", "2.0.0")

return LKS_EletricidadeConstrucao.Fuel.ChunkTracker
