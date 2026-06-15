-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Building_Scanner.lua
-- LKS_EletricidadeConstrucao V2 - Building Scanner
-- Scans buildings from light switches to detect powered areas
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Building_Scanner] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- Initialize sub-namespace
LKS_EletricidadeConstrucao.Building = LKS_EletricidadeConstrucao.Building or {}
LKS_EletricidadeConstrucao.Building.Scanner = LKS_EletricidadeConstrucao.Building.Scanner or {}

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local _isInitialized = false
local _scanQueue = {}  -- Queue of pending scans
local _activeScan = nil  -- Currently active scan

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize building scanner
function LKS_EletricidadeConstrucao.Building.Scanner.Initialize()
    if _isInitialized then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("Building Scanner already initialized", "Building")
        return
    end
    
    -- Register event handlers for light switch detection
    LKS_EletricidadeConstrucao.Core.EventManager.RegisterGameEvent("OnObjectAdded", LKS_EletricidadeConstrucao.Building.Scanner.OnObjectAdded)
    
    _isInitialized = true
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Building Scanner initialized", "Building")
end

--- Check if building scanner is initialized
--- @return boolean True if initialized
function LKS_EletricidadeConstrucao.Building.Scanner.IsInitialized()
    return _isInitialized
end

-- ============================================================================
-- OBJECT DETECTION
-- ============================================================================

--- Handle object added event (detects new light switches)
--- @param object IsoObject Object that was added
function LKS_EletricidadeConstrucao.Building.Scanner.OnObjectAdded(object)
    if not object then
        return
    end
    
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Check if object is a light switch
    if not Validation.IsLightSwitch(object) then
        return
    end
    
    -- Get coordinates
    local x = object:getX()
    local y = object:getY()
    local z = object:getZ()
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Light switch detected at (%d,%d,%d)", x, y, z),
        "Building"
    )
    
    -- Queue scan for this building
    LKS_EletricidadeConstrucao.Building.Scanner.QueueScan(x, y, z)
end

-- ============================================================================
-- SCAN QUEUE MANAGEMENT
-- ============================================================================

--- Queue a building scan
--- @param x number X coordinate of light switch
--- @param y number Y coordinate of light switch
--- @param z number Z coordinate of light switch
--- @param buildingIdOverride string|nil Optional canonical building ID (overrides coord-derived ID)
function LKS_EletricidadeConstrucao.Building.Scanner.QueueScan(x, y, z, buildingIdOverride)
    local buildingId = buildingIdOverride or LKS_EletricidadeConstrucao.Data.Building.MakeId(x, y, z)
    
    -- Check if already queued
    for _, scan in ipairs(_scanQueue) do
        if scan.buildingId == buildingId then
            LKS_EletricidadeConstrucao.Core.Logger.Trace(
                string.format("Scan already queued for %s", buildingId),
                "Building"
            )
            return
        end
    end
    
    -- Add to queue
    table.insert(_scanQueue, {
        buildingId = buildingId,
        x = x,
        y = y,
        z = z,
        queuedTime = getTimestampMs()
    })
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Queued scan for building %s (%d in queue)", buildingId, #_scanQueue),
        "Building"
    )
end

--- Process scan queue (called periodically)
function LKS_EletricidadeConstrucao.Building.Scanner.ProcessQueue()
    if not _isInitialized then
        return
    end
    
    -- Check if scan is already active
    if _activeScan then
        return
    end
    
    -- Check if queue is empty
    if #_scanQueue == 0 then
        return
    end
    
    -- Get next scan
    local scan = table.remove(_scanQueue, 1)
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Starting scan for building %s", scan.buildingId),
        "Building"
    )
    
    -- Execute scan (pass stored buildingId as override so the ID survives the queue)
    LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(scan.x, scan.y, scan.z, scan.buildingId)
end

-- ============================================================================
-- CHUNK-LOAD SAFETY HELPERS
-- ============================================================================

--- Return true if every chunk covered by the building's bounding box is currently
--- loaded (i.e. getSquare() returns non-nil for every corner and the center).
--- Used as a pre-flight guard before ClearConsumers + rescan so that consumers
--- in unloaded adjacent chunks are not permanently lost.
--- @param buildingData BuildingData Building to check
--- @return boolean True if the whole area is accessible
function LKS_EletricidadeConstrucao.Building.Scanner.IsBuildingAreaLoaded(buildingData)
    if not buildingData then return false end
    local bb = buildingData.boundingBox
    if not bb then
        -- No bounding box recorded yet (first scan). We cannot check, so allow scan.
        return true
    end
    local z = buildingData.z or 0
    -- Sample all four corners plus centre. Each corner belongs to a potentially
    -- distinct 10×10 chunk, so five samples cover the entire bounding box reliably.
    local pts = {
        {x = bb.minX,                                y = bb.minY},
        {x = bb.maxX,                                y = bb.minY},
        {x = bb.minX,                                y = bb.maxY},
        {x = bb.maxX,                                y = bb.maxY},
        {x = math.floor((bb.minX + bb.maxX) * 0.5), y = math.floor((bb.minY + bb.maxY) * 0.5)},
    }
    for _, p in ipairs(pts) do
        if not getSquare(p.x, p.y, z) then
            return false
        end
    end
    return true
end

-- ============================================================================
-- BUILDING SCANNING
-- ============================================================================

--- Scan building from light switch
--- @param x number Light switch X coordinate
--- @param y number Light switch Y coordinate
--- @param z number Light switch Z coordinate
--- @param buildingIdOverride string|nil Optional canonical building ID (overrides coord-derived ID)
--- @return BuildingData|nil Building data or nil if failed
function LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(x, y, z, buildingIdOverride)
    local Config = LKS_EletricidadeConstrucao.Config
    local Constants = LKS_EletricidadeConstrucao.Constants
    
    LKS_EletricidadeConstrucao.Core.Logger.StartTimer("BuildingScan")
    
    -- Get light switch object
    local square = getSquare(x, y, z)
    
    if not square then
        LKS_EletricidadeConstrucao.Core.Logger.Error(
            string.format("Square not found at (%d,%d,%d)", x, y, z),
            "Building"
        )
        return nil
    end
    
    -- Find light switch object
    local lightSwitch = nil
    local objects = square:getObjects()
    
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj and instanceof(obj, "IsoLightSwitch") then
                lightSwitch = obj
                break
            end
        end
    end
    
    if not lightSwitch then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("Light switch not found at (%d,%d,%d)", x, y, z),
            "Building"
        )
        return nil
    end
    
    -- Create or get building data
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local buildingId = buildingIdOverride or LKS_EletricidadeConstrucao.Data.Building.MakeId(x, y, z)
    local buildingData = StateManager.GetBuilding(buildingId)
    
    local isRescan = (buildingData ~= nil)
    print(string.format("[LKS_EletricidadeConstrucao_SCAN] %s building %s from light switch (%d,%d,%d)",
        isRescan and "RE-SCANNING" or "NEW SCAN", buildingId, x, y, z))
    
    if not buildingData then
        -- Create new building data
        local radius = Config.BorderRadius or Constants.BUILDING.DEFAULT_BORDER_RADIUS or 10
        buildingData = LKS_EletricidadeConstrucao.Data.Building.New(lightSwitch, radius)
        -- Apply the canonical override ID before registering so StateManager,
        -- connectedGenerators, and ForceUpdateBuilding all use the same key.
        if buildingIdOverride then
            buildingData.id = buildingIdOverride
        end
        StateManager.AddBuilding(buildingData)
    else
        print(string.format("[LKS_EletricidadeConstrucao_SCAN] Building already exists - current consumers: %d, current power: %.1f",
            buildingData.totalConsumers or 0, buildingData.totalPowerDraw or 0))
    end
    
    -- For player-built buildings, derive a proper scan radius from bounding box (if known)
    -- so RadiusFallback covers the entire footprint even when borderRadius is tiny (2).
    local scanRadius = buildingData.borderRadius
    local isPlayerBuilt = buildingId and string.match(buildingId, "^bld_%-?%d+_%-?%d+_%-?%d+$") ~= nil
    if isPlayerBuilt and buildingData.boundingBox then
        local bb = buildingData.boundingBox
        local halfW = math.ceil((bb.maxX - bb.minX) / 2) + 3
        local halfH = math.ceil((bb.maxY - bb.minY) / 2) + 3
        scanRadius = math.max(halfW, halfH, scanRadius or 2)
        print(string.format("[LKS_EletricidadeConstrucao_SCAN] Player-built %s: bbox-derived scan radius %d", buildingId, scanRadius))
    elseif isPlayerBuilt then
        -- No bounding box yet (fresh connection) – use a generous default
        scanRadius = math.max(scanRadius or 2, 30)
    end

    -- Detect building borders (pass buildingId so player-built structures skip nearby-building search)
    local borderTiles = LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBorders(x, y, z, scanRadius, buildingId)
    
    if #borderTiles == 0 then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("No border tiles found for building %s", buildingId),
            "Building"
        )
        return buildingData
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Found %d border tiles for building %s", #borderTiles, buildingId),
        "Building"
    )
    print(string.format("[LKS_EletricidadeConstrucao_SCAN] Found %d border tiles", #borderTiles))
    
    -- Calculate bounding box
    local minX, minY, maxX, maxY = 999999, 999999, -999999, -999999
    
    for _, tile in ipairs(borderTiles) do
        if tile.x < minX then minX = tile.x end
        if tile.y < minY then minY = tile.y end
        if tile.x > maxX then maxX = tile.x end
        if tile.y > maxY then maxY = tile.y end
    end
    
    LKS_EletricidadeConstrucao.Data.Building.SetBoundingBox(buildingData, minX, minY, maxX, maxY)
    
    -- Clear existing consumers before scanning to prevent duplicates
    -- (can happen when multiple generators scan the same building)
    local oldConsumerCount = buildingData.totalConsumers or 0
    local oldPowerDraw = buildingData.totalPowerDraw or 0
    print(string.format("[LKS_EletricidadeConstrucao_SCAN] BEFORE scan: %d consumers, %.1f power draw", oldConsumerCount, oldPowerDraw))

    -- B-83: Guard against partial chunk loads.
    -- For rescans (building already exists with consumer data), verify every chunk
    -- covering the bounding box is loaded before clearing the consumer list.
    -- If any chunk is unloaded, getSquare() returns nil for its tiles and the
    -- (correct, GlobalModData-saved) consumers would be permanently lost.
    if isRescan and (buildingData.totalConsumers or 0) > 0 then
        local Scanner = LKS_EletricidadeConstrucao.Building.Scanner
        if not Scanner.IsBuildingAreaLoaded(buildingData) then
            LKS_EletricidadeConstrucao.Core.Logger.Info(
                string.format("ScanBuilding: partial chunk load detected for %s " ..
                    "(%d consumers at risk) – skipping rescan, keeping GlobalModData data",
                    buildingId, buildingData.totalConsumers),
                "Building")
            -- Still call MarkScanned / MarkDirty so the caller gets a consistent return value.
            LKS_EletricidadeConstrucao.Data.Building.MarkScanned(buildingData)
            LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
            LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BuildingScan", 50)
            return buildingData
        end
    end

    LKS_EletricidadeConstrucao.Data.Building.ClearConsumers(buildingData)
    print("[LKS_EletricidadeConstrucao_SCAN] Consumers cleared, now rescanning...")
    
    -- Scan for consumers within border tiles
    LKS_EletricidadeConstrucao.Building.ConsumerScanner.ScanConsumers(buildingData, borderTiles)
    
    -- Recalculate total power draw
    LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(buildingData)
    
    print(string.format("[LKS_EletricidadeConstrucao_SCAN] AFTER scan: %d consumers, %.1f power draw (delta: %+d consumers, %+.1f power)",
        buildingData.totalConsumers or 0, buildingData.totalPowerDraw or 0,
        (buildingData.totalConsumers or 0) - oldConsumerCount,
        (buildingData.totalPowerDraw or 0) - oldPowerDraw))
    
    -- Mark as scanned
    LKS_EletricidadeConstrucao.Data.Building.MarkScanned(buildingData)
    
    -- Trigger event
    LKS_EletricidadeConstrucao.Core.EventManager.OnBuildingScanned(buildingData)
    
    -- Mark state as dirty
    StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BuildingScan", 50)  -- Warn if > 50ms
    
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("Scanned building %s: %d consumers, %.1f power draw",
            buildingId, #buildingData.powerConsumers, buildingData.totalPowerDraw),
        "Building"
    )
    
    return buildingData
end

-- ============================================================================
-- RESCAN OPERATIONS
-- ============================================================================

--- Rescan existing building
--- @param buildingId string Building ID
--- @return BuildingData|nil Updated building data
function LKS_EletricidadeConstrucao.Building.Scanner.RescanBuilding(buildingId)
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local buildingData = StateManager.GetBuilding(buildingId)
    
    if not buildingData then
        LKS_EletricidadeConstrucao.Core.Logger.Error(
            string.format("Building %s not found for rescan", buildingId),
            "Building"
        )
        return nil
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Rescanning building %s", buildingId),
        "Building"
    )
    
    -- Clear existing consumers
    LKS_EletricidadeConstrucao.Data.Building.ClearConsumers(buildingData)
    
    -- Rescan
    return LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(buildingData.x, buildingData.y, buildingData.z)
end

--- Rescan all buildings
function LKS_EletricidadeConstrucao.Building.Scanner.RescanAllBuildings()
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local buildings = StateManager.GetAllBuildings()
    
    local count = 0
    for buildingId, _ in pairs(buildings) do
        LKS_EletricidadeConstrucao.Building.Scanner.RescanBuilding(buildingId)
        count = count + 1
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("Rescanned %d buildings", count),
        "Building"
    )
end

-- ============================================================================
-- MANUAL SCAN OPERATIONS
-- ============================================================================

--- Manually scan building at coordinates
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate
--- @return BuildingData|nil Building data
function LKS_EletricidadeConstrucao.Building.Scanner.ManualScan(x, y, z)
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("Manual scan requested at (%d,%d,%d)", x, y, z),
        "Building"
    )
    
    return LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(x, y, z)
end

--- Scan all light switches in loaded chunks
function LKS_EletricidadeConstrucao.Building.Scanner.ScanAllLightSwitches()
    LKS_EletricidadeConstrucao.Core.Logger.Info("Scanning all light switches in loaded chunks...", "Building")
    
    local scannedCount = 0
    local loadedChunks = LKS_EletricidadeConstrucao.Fuel.ChunkTracker.GetLoadedChunks()
    
    for _, chunkKey in ipairs(loadedChunks) do
        -- Parse chunk coordinates
        local chunkX, chunkY = chunkKey:match("chunk_(-?%d+)_(-?%d+)")
        
        if chunkX and chunkY then
            chunkX = tonumber(chunkX)
            chunkY = tonumber(chunkY)
            
            -- Scan chunk for light switches
            -- Each chunk is 10x10 tiles
            for x = chunkX * 10, (chunkX * 10) + 9 do
                for y = chunkY * 10, (chunkY * 10) + 9 do
                    for z = 0, 7 do  -- Check all levels
                        local square = getSquare(x, y, z)
                        
                        if square then
                            local objects = square:getObjects()
                            
                            if objects then
                                for i = 0, objects:size() - 1 do
                                    local obj = objects:get(i)
                                    if obj and instanceof(obj, "IsoLightSwitch") then
                                        LKS_EletricidadeConstrucao.Building.Scanner.QueueScan(x, y, z)
                                        scannedCount = scannedCount + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("Found %d light switches, queued for scanning", scannedCount),
        "Building"
    )
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Print scanner status
function LKS_EletricidadeConstrucao.Building.Scanner.PrintStatus()
    LKS_EletricidadeConstrucao.Print("=== Building Scanner Status ===")
    LKS_EletricidadeConstrucao.Print("Initialized: " .. tostring(_isInitialized))
    LKS_EletricidadeConstrucao.Print("Queued Scans: " .. #_scanQueue)
    LKS_EletricidadeConstrucao.Print("Active Scan: " .. tostring(_activeScan ~= nil))
    
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local buildings = StateManager.GetAllBuildings()
    local count = 0
    
    for _, _ in pairs(buildings) do
        count = count + 1
    end
    
    LKS_EletricidadeConstrucao.Print("Total Buildings: " .. count)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Building.Scanner", "2.0.0")

return LKS_EletricidadeConstrucao.Building.Scanner
