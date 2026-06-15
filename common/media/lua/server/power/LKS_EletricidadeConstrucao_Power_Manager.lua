-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao V2: Power Manager
-- Purpose: Connect generators to nearby buildings and manage power distribution
-- Author: AI Assistant
-- Created: 2025

if not LKS_EletricidadeConstrucao then 
    print("[LKS_EletricidadeConstrucao_Power_Manager] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return 
end

LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao or {}
LKS_EletricidadeConstrucao.Power = LKS_EletricidadeConstrucao.Power or {}
LKS_EletricidadeConstrucao.Power.Manager = LKS_EletricidadeConstrucao.Power.Manager or {}

local Power = LKS_EletricidadeConstrucao.Power.Manager
local Logger = LKS_EletricidadeConstrucao.Core.Logger
local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
local Math = LKS_EletricidadeConstrucao.Utils.Math
local Validation = LKS_EletricidadeConstrucao.Utils.Validation

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

Power.MAX_POWER_RANGE = 30  -- Maximum distance (tiles) from generator to building
Power.CONNECTION_UPDATE_INTERVAL = 60  -- Update connections every 60 seconds
Power.DEBUG = false

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

-- Connection tracking: generatorId -> { ... }
Power.connections = {}

-- Last update timestamp
Power.lastUpdate = 0

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

--- Initialize the Power Manager
function Power.Initialize()
    Logger.Info("Power.Manager", "Initializing Power Manager...")
    
    Power.connections = {}
    Power.lastUpdate = 0
    
    Logger.Info("Power.Manager", "Power Manager initialized.")
end

--------------------------------------------------------------------------------
-- GENERATOR DETECTION
--------------------------------------------------------------------------------

--- Find all generators in loaded chunks
-- Looks up known generator positions from StateManager and returns any whose
-- IsoGenerator object is currently in memory.  This avoids chunk traversal
-- APIs (getChunkMap / getSquares) that are not reliably available in Kahlua.
-- @return table List of IsoGenerator objects
function Power.GetAllGenerators()
    local generators = {}
    local cell = getCell()

    if not cell then
        Logger.Warn("Power.Manager", "GetAllGenerators: No cell found")
        return generators
    end

    -- Iterate known generators from StateManager rather than scanning chunks.
    local allGenData = StateManager.GetAllGenerators()
    for _, genData in pairs(allGenData) do
        local sq = cell:getGridSquare(genData.x, genData.y, genData.z)
        if sq then
            local objs = sq:getObjects()
            for i = 0, objs:size() - 1 do
                local obj = objs:get(i)
                if obj and instanceof(obj, "IsoGenerator") then
                    table.insert(generators, obj)
                    break
                end
            end
        end
    end

    Logger.Debug("Power.Manager", "GetAllGenerators: Found " .. #generators .. " generators")
    return generators
end

--- Find generators near a specific building
-- @param buildingData BuildingData object
-- @param radius number Maximum search radius (optional, defaults to MAX_POWER_RANGE)
-- @return table List of IsoGenerator objects within range
function Power.FindNearbyGenerators(buildingData, radius)
    if not buildingData then
        Logger.Error("Power.Manager", "FindNearbyGenerators: buildingData is nil")
        return {}
    end
    
    radius = radius or Power.MAX_POWER_RANGE
    
    local nearbyGenerators = {}
    local allGenerators = Power.GetAllGenerators()
    
    -- Building center coordinates (some states don't store centerX/centerY).
    -- Derive from bounding box if available, otherwise fall back to anchor x/y.
    local function toNum(v, fallback)
        local n = tonumber(v)
        if n == nil then return fallback or 0 end
        return n
    end
    local buildingX = toNum(buildingData.x, 0)
    local buildingY = toNum(buildingData.y, 0)
    local buildingZ = toNum(buildingData.z, 0)
    local bb = buildingData.boundingBox
    if type(bb) == "table" then
        local minX = toNum(bb[1], buildingX)
        local minY = toNum(bb[2], buildingY)
        local maxX = toNum(bb[3], buildingX)
        local maxY = toNum(bb[4], buildingY)
        buildingX = (minX + maxX) / 2
        buildingY = (minY + maxY) / 2
    end
    
    for _, generator in ipairs(allGenerators) do
        local genSquare = generator:getSquare()
        if genSquare then
            local genX = genSquare:getX()
            local genY = genSquare:getY()
            local genZ = genSquare:getZ()
            
            -- Check same floor level
            if genZ == buildingZ then
                -- Calculate distance
                local distance = Math.Distance2D(buildingX, buildingY, genX, genY)
                
                if distance <= radius then
                    table.insert(nearbyGenerators, {
                        generator = generator,
                        distance = distance,
                        x = genX,
                        y = genY,
                        z = genZ
                    })
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(nearbyGenerators, function(a, b)
        return a.distance < b.distance
    end)
    
    Logger.Debug("Power.Manager", string.format(
        "FindNearbyGenerators: Found %d generators within %d tiles of building %s",
        #nearbyGenerators, radius, buildingData.id
    ))
    
    return nearbyGenerators
end

--------------------------------------------------------------------------------
-- CONNECTION MANAGEMENT
--------------------------------------------------------------------------------

--- Create a unique connection ID
-- @param generatorX number Generator X coordinate
-- @param generatorY number Generator Y coordinate
-- @param generatorZ number Generator Z coordinate
-- @param buildingId string Building ID
-- @return string Connection ID
function Power.CreateConnectionId(generatorX, generatorY, generatorZ, buildingId)
    return string.format("conn_%d_%d_%d_%s", generatorX, generatorY, generatorZ, buildingId)
end

local function GeneratorBelongsToBuilding(generator, buildingData)
    if not generator or not buildingData or not buildingData.id then
        return false
    end

    local square = generator:getSquare()
    if not square then
        return false
    end

    local md = generator:getModData()
    if md and md.LKS_EletricidadeConstrucao_DisconnectSuppressed then
        return false
    end

    if md and md.Gen_BuildingPoolID == buildingData.id then
        return true
    end

    local genId = LKS_EletricidadeConstrucao.Data.Generator.MakeId(square:getX(), square:getY(), square:getZ())
    local genData = StateManager.GetGenerator(genId)
    if genData and genData.connectedBuildings then
        for _, buildingId in pairs(genData.connectedBuildings) do
            if buildingId == buildingData.id then
                return true
            end
        end
    end

    return false
end

--- Connect a generator to a building
-- @param generator IsoGenerator object
-- @param buildingData BuildingData object
-- @param distance number Distance between generator and building
-- @return boolean Success
function Power.ConnectGeneratorToBuilding(generator, buildingData, distance)
    if not generator or not buildingData then
        Logger.Error("Power.Manager", "ConnectGeneratorToBuilding: Invalid parameters")
        return false
    end
    
    local square = generator:getSquare()
    if not square then
        Logger.Warn("Power.Manager", "ConnectGeneratorToBuilding: Generator has no square")
        return false
    end
    
    local genX = square:getX()
    local genY = square:getY()
    local genZ = square:getZ()

    -- Prepare building connection list and enforce pool limit (max 10)
    if not buildingData.connectedGenerators then
        buildingData.connectedGenerators = {}
    end
    local genKey = string.format("%d_%d_%d", genX, genY, genZ)
    local alreadyConnected = false
    -- connectedGenerators is Kahlua-deserialized (string numeric keys)
    for _, genCoords in pairs(buildingData.connectedGenerators) do
        if genCoords == genKey then
            alreadyConnected = true
            break
        end
    end
    local _genPoolSize = 0
    if buildingData.connectedGenerators then
        for _ in pairs(buildingData.connectedGenerators) do _genPoolSize = _genPoolSize + 1 end
    end
    local maxGenerators = (LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.BUILDING 
                          and LKS_EletricidadeConstrucao.Constants.BUILDING.MAX_GENERATORS_PER_BUILDING) or 10
    if not alreadyConnected and _genPoolSize >= maxGenerators then
        Logger.Warn("Power.Manager", string.format(
            "ConnectGeneratorToBuilding: Pool limit reached (%d). Rejecting generator at (%d,%d,%d) for building %s",
            maxGenerators, genX, genY, genZ, buildingData.id))
        return false
    end

    -- Ensure generator is registered in StateManager with a back-link to this building
    local genId = LKS_EletricidadeConstrucao.Data.Generator.MakeId(genX, genY, genZ)
    local genData = StateManager.GetGenerator(genId)
    if not genData then
        genData = LKS_EletricidadeConstrucao.Data.Generator.New(generator)
    end
    genData.connectedBuildings = genData.connectedBuildings or {}
    local genHasBuilding = false
    -- connectedBuildings is Kahlua-deserialized (string numeric keys)
    for _, bid in pairs(genData.connectedBuildings) do
        if bid == buildingData.id then genHasBuilding = true; break end
    end
    if not genHasBuilding then
        table.insert(genData.connectedBuildings, buildingData.id)
    end
    StateManager.AddGenerator(genData)

    -- Create connection ID
    local connectionId = Power.CreateConnectionId(genX, genY, genZ, buildingData.id)

    -- Check if connection already exists
    if Power.connections[connectionId] then
        Logger.Debug("Power.Manager", "ConnectGeneratorToBuilding: Connection already exists: " .. connectionId)
        return true
    end

    -- Create connection data
    local connectionData = {
        id = connectionId,
        generatorX = genX,
        generatorY = genY,
        generatorZ = genZ,
        buildingId = buildingData.id,
        distance = distance,
        createdTime = os.time(),
        lastValidated = os.time()
    }

    -- Store connection
    Power.connections[connectionId] = connectionData

    local md = generator:getModData()
    if md then
        md.LKS_EletricidadeConstrucao_DisconnectSuppressed = nil
    end

    -- Add generator coordinates to building (if not already there)
    if not alreadyConnected then
        table.insert(buildingData.connectedGenerators, genKey)
    end

    Logger.Info("Power.Manager", string.format(
        "Connected generator at (%d,%d,%d) to building %s (distance: %.1f tiles)",
        genX, genY, genZ, buildingData.id, distance
    ))

    return true
end

--- Disconnect a generator from a building
-- @param connectionId string Connection ID
-- @return boolean Success
function Power.DisconnectGeneratorFromBuilding(connectionId)
    if not connectionId then
        Logger.Error("Power.Manager", "DisconnectGeneratorFromBuilding: connectionId is nil")
        return false
    end
    
    local connection = Power.connections[connectionId]
    if not connection then
        Logger.Warn("Power.Manager", "DisconnectGeneratorFromBuilding: Connection not found: " .. connectionId)
        return false
    end
    
    -- Get building data
    local buildingData = StateManager.GetBuilding(connection.buildingId)
    local genKey = string.format("%d_%d_%d", connection.generatorX, connection.generatorY, connection.generatorZ)

    if buildingData and buildingData.connectedGenerators then
        -- Remove generator from building's connected list (Kahlua string-key safe)
        local _newGenList = {}
        for _, v in pairs(buildingData.connectedGenerators) do
            if v ~= genKey then table.insert(_newGenList, v) end
        end
        buildingData.connectedGenerators = _newGenList

        -- If no generators remain, drop the building from state
        if LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(buildingData.connectedGenerators) then
            StateManager.RemoveBuilding(connection.buildingId)
        end
    end

    -- Update generator state: clear pool link and remove building back-link
    local genId = LKS_EletricidadeConstrucao.Data.Generator.MakeId(connection.generatorX, connection.generatorY, connection.generatorZ)
    local genData = StateManager.GetGenerator(genId)
    if genData and genData.connectedBuildings then
        local _newBldList = {}
        for _, v in pairs(genData.connectedBuildings) do
            if v ~= connection.buildingId then table.insert(_newBldList, v) end
        end
        genData.connectedBuildings = _newBldList
        if LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(genData.connectedBuildings) then
            -- Clear pool marker in live IsoGenerator if loaded
            local cell = getCell()
            if cell then
                local sq = cell:getGridSquare(connection.generatorX, connection.generatorY, connection.generatorZ)
                if sq then
                    local objs = sq:getObjects()
                    for i = 0, objs:size() - 1 do
                        local o = objs:get(i)
                        if o and instanceof(o, "IsoGenerator") then
                            local md = o:getModData()
                            md.Gen_BuildingPoolID = nil
                            if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                o:transmitModData()
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    -- Remove connection
    Power.connections[connectionId] = nil
    StateManager.MarkDirty()

    Logger.Info("Power.Manager", string.format(
        "Disconnected generator at (%d,%d,%d) from building %s",
        connection.generatorX, connection.generatorY, connection.generatorZ, connection.buildingId
    ))
    
    return true
end

--------------------------------------------------------------------------------
-- CONNECTION VALIDATION
--------------------------------------------------------------------------------

--- Check if a generator still exists at the specified coordinates
-- @param x number X coordinate
-- @param y number Y coordinate
-- @param z number Z coordinate
-- @return IsoGenerator|nil Generator object if found, nil otherwise
function Power.GetGeneratorAt(x, y, z)
    local square = getCell():getGridSquare(x, y, z)
    if not square then
        return nil
    end
    
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and instanceof(obj, "IsoGenerator") then
            return obj
        end
    end
    
    return nil
end

--- Validate a connection (check if generator and building still exist)
-- @param connectionData table Connection data
-- @return boolean True if connection is valid
function Power.ValidateConnection(connectionData)
    if not connectionData then
        return false
    end
    
    -- Check if generator still exists.
    -- IMPORTANT: If the generator's chunk is unloaded, getGridSquare returns nil.
    -- We must NOT disconnect a connection just because the chunk isn't loaded —
    -- that would wipe connectedBuildings from the state and cause the catch-up
    -- calculation to treat the generator as solo (3× fuel burn bug, B-87).
    -- Only disconnect if the chunk IS loaded but contains no IsoGenerator at that tile.
    local genSquare = getCell():getGridSquare(
        connectionData.generatorX, connectionData.generatorY, connectionData.generatorZ)
    if not genSquare then
        -- Chunk unloaded — cannot verify; leave connection intact.
        return true
    end
    local generator = nil
    local _objs = genSquare:getObjects()
    for _i = 0, _objs:size() - 1 do
        local _o = _objs:get(_i)
        if _o and instanceof(_o, "IsoGenerator") then generator = _o; break end
    end
    if not generator then
        Logger.Debug("Power.Manager", "ValidateConnection: Generator no longer exists at " ..
            string.format("(%d,%d,%d)", connectionData.generatorX, connectionData.generatorY, connectionData.generatorZ))
        return false
    end
    
    -- Check if building still exists
    local buildingData = StateManager.GetBuilding(connectionData.buildingId)
    if not buildingData then
        Logger.Debug("Power.Manager", "ValidateConnection: Building no longer exists: " .. connectionData.buildingId)
        return false
    end
    
    -- Check distance (in case building was modified)
    local function toNum(v, fallback)
        local n = tonumber(v)
        if n == nil then return fallback end
        return n
    end

    -- Derive building center with fallbacks for missing fields
    local bx = toNum(buildingData.centerX, nil)
    local by = toNum(buildingData.centerY, nil)
    if not bx or not by then
        bx = toNum(buildingData.x, 0)
        by = toNum(buildingData.y, 0)
    end

    -- If still missing, try bounding box center
    local bb = buildingData.boundingBox
    if (not bx or not by) and type(bb) == "table" then
        local minX = toNum(bb[1], toNum(bb.minX, bx))
        local minY = toNum(bb[2], toNum(bb.minY, by))
        local maxX = toNum(bb[3], toNum(bb.maxX, bx))
        local maxY = toNum(bb[4], toNum(bb.maxY, by))
        if minX and minY and maxX and maxY then
            bx = (minX + maxX) / 2
            by = (minY + maxY) / 2
        end
    end

    -- Final guard: if still missing, deem connection invalid
    if not bx or not by then
        Logger.Debug("Power.Manager", "ValidateConnection: building center missing, dropping connection " .. tostring(connectionData.id))
        return false
    end

    local distance = Math.Distance2D(
        bx, by,
        connectionData.generatorX, connectionData.generatorY
    )
    
    if distance > Power.MAX_POWER_RANGE then
        Logger.Debug("Power.Manager", string.format(
            "ValidateConnection: Distance too great (%.1f > %d) for connection %s",
            distance, Power.MAX_POWER_RANGE, connectionData.id
        ))
        return false
    end
    
    -- Update distance if changed
    if math.abs(distance - connectionData.distance) > 0.1 then
        connectionData.distance = distance
    end
    
    -- Update last validated timestamp
    connectionData.lastValidated = os.time()
    
    return true
end

--- Clean invalid connections (generators/buildings that no longer exist)
-- @return number Number of connections removed
function Power.CleanInvalidConnections()
    local removedCount = 0
    local toRemove = {}
    
    for connectionId, connectionData in pairs(Power.connections) do
        if not Power.ValidateConnection(connectionData) then
            table.insert(toRemove, connectionId)
        end
    end
    
    for _, connectionId in ipairs(toRemove) do
        Power.DisconnectGeneratorFromBuilding(connectionId)
        removedCount = removedCount + 1
    end
    
    if removedCount > 0 then
        Logger.Info("Power.Manager", "CleanInvalidConnections: Removed " .. removedCount .. " invalid connections")
    end
    
    return removedCount
end

--------------------------------------------------------------------------------
-- CONNECTION UPDATES
--------------------------------------------------------------------------------

--- Update all connections (find new generators, validate existing)
function Power.UpdateConnections()
    Logger.Debug("Power.Manager", "UpdateConnections: Scanning for generators...")
    
    -- Clean invalid connections first
    Power.CleanInvalidConnections()
    
    -- Get all buildings (returns a map: buildingId -> buildingData)
    local buildings = StateManager.GetAllBuildings()
    if not buildings then
        Logger.Debug("Power.Manager", "UpdateConnections: No buildings found")
        return
    end
    -- Check if map has any entries (Kahlua does not support next())
    local hasBuildings = false
    for _ in pairs(buildings) do hasBuildings = true; break end
    if not hasBuildings then
        Logger.Debug("Power.Manager", "UpdateConnections: No buildings found")
        return
    end

    local newConnectionsCount = 0
    
    -- For each building, find nearby generators
    -- NOTE: buildings is a MAP (string keys) – must use pairs(), not ipairs()
    for _, buildingData in pairs(buildings) do
        local nearbyGenerators = Power.FindNearbyGenerators(buildingData)
        
        -- Connect each nearby generator
        for _, genInfo in ipairs(nearbyGenerators) do
            local success = false
            if GeneratorBelongsToBuilding(genInfo.generator, buildingData) then
                success = Power.ConnectGeneratorToBuilding(genInfo.generator, buildingData, genInfo.distance)
            end
            if success then
                -- Check if this is actually a new connection
                local connectionId = Power.CreateConnectionId(genInfo.x, genInfo.y, genInfo.z, buildingData.id)
                if Power.connections[connectionId] and Power.connections[connectionId].createdTime == os.time() then
                    newConnectionsCount = newConnectionsCount + 1
                end
            end
        end
    end
    
    Power.lastUpdate = os.time()
    
    Logger.Info("Power.Manager", string.format(
        "UpdateConnections: Scan complete. Total connections: %d (new: %d)",
        Power.GetConnectionCount(), newConnectionsCount
    ))
end

--- Periodic update (called from server tick)
-- @param currentTime number Current timestamp
function Power.Update(currentTime)
    currentTime = currentTime or os.time()
    
    -- Check if update interval has passed
    if currentTime - Power.lastUpdate >= Power.CONNECTION_UPDATE_INTERVAL then
        Power.UpdateConnections()
    end
end

--------------------------------------------------------------------------------
-- QUERY FUNCTIONS
--------------------------------------------------------------------------------

--- Get all connections
-- @return table Connection data table
function Power.GetAllConnections()
    return Power.connections
end

--- Get connections for a specific building
-- @param buildingId string Building ID
-- @return table List of connection data
function Power.GetBuildingConnections(buildingId)
    if not buildingId then
        return {}
    end
    
    local buildingConnections = {}
    
    for _, connectionData in pairs(Power.connections) do
        if connectionData.buildingId == buildingId then
            table.insert(buildingConnections, connectionData)
        end
    end
    
    return buildingConnections
end

--- Check if a building has any active (powered) generators
-- @param buildingId string Building ID
-- @return boolean True if building has at least one active generator
function Power.IsBuildingPowered(buildingId)
    if not buildingId then
        return false
    end
    
    local connections = Power.GetBuildingConnections(buildingId)
    
    for _, connectionData in ipairs(connections) do
        local generator = Power.GetGeneratorAt(connectionData.generatorX, connectionData.generatorY, connectionData.generatorZ)
        if generator and generator:isActivated() then
            return true
        end
    end
    
    return false
end

--- Get connection count
-- @return number Total number of connections
function Power.GetConnectionCount()
    local count = 0
    for _ in pairs(Power.connections) do
        count = count + 1
    end
    return count
end

--------------------------------------------------------------------------------
-- DEBUG FUNCTIONS
--------------------------------------------------------------------------------

--- Print all connections (debug)
function Power.PrintConnections()
    Logger.Info("Power.Manager", "=== ALL CONNECTIONS ===")
    Logger.Info("Power.Manager", string.format("Total connections: %d", Power.GetConnectionCount()))
    
    for connectionId, connectionData in pairs(Power.connections) do
        local generator = Power.GetGeneratorAt(connectionData.generatorX, connectionData.generatorY, connectionData.generatorZ)
        local isActive = generator and generator:isActivated() or false
        
        Logger.Info("Power.Manager", string.format(
            "  %s: Gen(%d,%d,%d) -> Building %s (%.1f tiles) [%s]",
            connectionId,
            connectionData.generatorX, connectionData.generatorY, connectionData.generatorZ,
            connectionData.buildingId,
            connectionData.distance,
            isActive and "POWERED" or "OFF"
        ))
    end
    
    Logger.Info("Power.Manager", "======================")
end

--- Manual scan for connections (debug/admin command)
function Power.ManualScan()
    Logger.Info("Power.Manager", "ManualScan: Forcing connection update...")
    Power.UpdateConnections()
    Power.PrintConnections()
end

--------------------------------------------------------------------------------
-- EXPORTS
--------------------------------------------------------------------------------

LKS_EletricidadeConstrucao.RegisterModule("Power.Manager", "2.0.0")

return LKS_EletricidadeConstrucao.Power.Manager
