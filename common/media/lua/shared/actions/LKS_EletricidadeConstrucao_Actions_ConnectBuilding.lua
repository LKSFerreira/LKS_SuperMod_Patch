-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Actions_ConnectBuilding.lua
-- TimedAction for connecting generator to building
-- Triggers building scan and creates power pool
-- LOCATION: shared/actions/

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Actions_ConnectBuilding] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- print("[LKS_EletricidadeConstrucao_Actions_ConnectBuilding] Loading Connect Building action...")

-- Load required modules
require "TimedActions/ISBaseTimedAction"

-- Register module
LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_Actions_ConnectBuilding")

-- Create namespace
LKS_EletricidadeConstrucao.Actions = LKS_EletricidadeConstrucao.Actions or {}

-- ============================================================
-- CONNECT BUILDING TIMED ACTION
-- ============================================================

LKS_EletricidadeConstrucao_ConnectBuilding = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_ConnectBuilding")

local function ShouldSayToCharacter(runtime)
    if not runtime then return true end
    return not (runtime.IsServer and runtime.IsServer()
        and runtime.IsMultiplayer and runtime.IsMultiplayer())
end

-- ============================================================
-- VALIDATION
-- ============================================================

function LKS_EletricidadeConstrucao_ConnectBuilding:isValid()
    -- Generator must still exist
    if not self.generator then return false end

    -- Generator must be at same location
    local square = self.generator:getSquare()
    if not square then return false end

    -- Generator must not already be connected
    local md = self.generator:getModData()
    if md.Gen_BuildingPoolID then return false end

    return true
end

function LKS_EletricidadeConstrucao_ConnectBuilding:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

function LKS_EletricidadeConstrucao_ConnectBuilding:update()
    self.character:faceThisObject(self.generator)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

-- ============================================================
-- ANIMATION
-- ============================================================

function LKS_EletricidadeConstrucao_ConnectBuilding:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function LKS_EletricidadeConstrucao_ConnectBuilding:stop()
    ISBaseTimedAction.stop(self)
end

function LKS_EletricidadeConstrucao_ConnectBuilding:perform()
    ISBaseTimedAction.perform(self)
end

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Find a building-owned square adjacent to (or at) the generator square.
local function FindBuildingSquare(generatorSquare)
    if not generatorSquare then return nil end

    if generatorSquare:getBuilding() then
        return generatorSquare
    end

    local directions = {
        IsoDirections.N, IsoDirections.S, IsoDirections.E, IsoDirections.W,
        IsoDirections.NE, IsoDirections.NW, IsoDirections.SE, IsoDirections.SW
    }

    for _, dir in ipairs(directions) do
        local adj = generatorSquare:getAdjacentSquare(dir)
        if adj and adj:getBuilding() then
            return adj
        end
    end

    return nil
end

-- Search building rooms for any IsoLightSwitch.
-- Returns lsX, lsY, lsZ of the first one found, or nil.
local function FindBuildingLightSwitch(building, floorZ)
    if not building then return nil end
    local def = building.getDef and building:getDef()
    if not def then return nil end
    local rooms = def.getRooms and def:getRooms()
    if not rooms then return nil end

    local bestX, bestY, bestZ = nil, nil, nil

    local function ConsiderCandidate(x, y, z)
        if bestX == nil
                or z < bestZ
                or (z == bestZ and y < bestY)
                or (z == bestZ and y == bestY and x < bestX) then
            bestX, bestY, bestZ = x, y, z
        end
    end

    for ri = 0, rooms:size() - 1 do
        local room = rooms:get(ri)
        if room then
            for rx = room:getX(), room:getX2() do
                for ry = room:getY(), room:getY2() do
                    local sq = getCell():getGridSquare(rx, ry, floorZ)
                    if sq then
                        local objs = sq:getObjects()
                        for oi = 0, objs:size() - 1 do
                            local obj = objs:get(oi)
                            if obj and instanceof(obj, "IsoLightSwitch") then
                                ConsiderCandidate(rx, ry, floorZ)
                            end
                        end
                    end
                end
            end
        end
    end

    return bestX, bestY, bestZ
end

local function CountEntries(t)
    local count = 0
    if not t then return count end
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function IsInsideBoundingBox(buildingData, x, y)
    local bb = buildingData and buildingData.boundingBox
    if type(bb) ~= "table" then return false end

    local minX = tonumber(bb.minX or bb[1])
    local minY = tonumber(bb.minY or bb[2])
    local maxX = tonumber(bb.maxX or bb[3])
    local maxY = tonumber(bb.maxY or bb[4])
    if not (minX and minY and maxX and maxY) then
        return false
    end

    return x >= (minX - 1) and x <= (maxX + 1)
       and y >= (minY - 1) and y <= (maxY + 1)
end

local function GetAnchorIsoBuilding(buildingData)
    if not buildingData or buildingData.x == nil or buildingData.y == nil then
        return nil
    end

    local cell = getCell and getCell()
    if not cell then
        return nil
    end

    local sq = cell:getGridSquare(
        tonumber(buildingData.x),
        tonumber(buildingData.y),
        tonumber(buildingData.z) or 0
    )

    return sq and sq:getBuilding() or nil
end

-- Reuse an already-scanned building pool for the same physical footprint even
-- when another floor has a different light switch anchor.
local function FindExistingBuildingMatch(building, buildingSquare, candidateBuildingId)
    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not StateManager or not StateManager.GetAllBuildings or not buildingSquare then
        return nil
    end

    local allBuildings = StateManager.GetAllBuildings()
    if not allBuildings then
        return nil
    end

    local bx, by = buildingSquare:getX(), buildingSquare:getY()
    local def = building and building.getDef and building:getDef()
    local candidateIsoBuilding = buildingSquare:getBuilding() or building
    local defX = def and def.getX and def:getX() or nil
    local defY = def and def.getY and def:getY() or nil
    local fallbackId, fallbackData = nil, nil

    for buildingId, buildingData in pairs(allBuildings) do
        if buildingId ~= candidateBuildingId then
            local existingIsoBuilding = GetAnchorIsoBuilding(buildingData)

            if candidateIsoBuilding and existingIsoBuilding then
                if existingIsoBuilding == candidateIsoBuilding then
                    return buildingId, buildingData
                end
            elseif IsInsideBoundingBox(buildingData, bx, by) then
                return buildingId, buildingData
            end

            if defX and defY and LKS_EletricidadeConstrucao.Data
                    and LKS_EletricidadeConstrucao.Data.Building
                    and LKS_EletricidadeConstrucao.Data.Building.ParseId then
                local bldX, bldY = LKS_EletricidadeConstrucao.Data.Building.ParseId(buildingId)
                if bldX == defX and bldY == defY then
                    fallbackId, fallbackData = buildingId, buildingData
                end
            end
        end
    end

    return fallbackId, fallbackData
end

-- ============================================================
-- ACTION EXECUTION
-- ============================================================

function LKS_EletricidadeConstrucao_ConnectBuilding:complete()
    local Runtime = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local isMPClient = Runtime and Runtime.IsMultiplayerClient and Runtime.IsMultiplayerClient()

    if isMPClient then
        local sq = self.generator and self.generator:getSquare()
        if sq and isClient() then
            sendClientCommand(self.character, "LKS_EletricidadeConstrucao", "ConnectBuilding", {
                genX = sq:getX(),
                genY = sq:getY(),
                genZ = sq:getZ(),
            })
        end
        return true
    end

    local generatorSquare = self.generator:getSquare()
    if not generatorSquare then
        LKS_EletricidadeConstrucao.Error("[ConnectBuilding] Generator square not found")
        return true
    end

    local buildingSquare = FindBuildingSquare(generatorSquare)
    if not buildingSquare then
        if ShouldSayToCharacter(Runtime) then
            self.character:Say(getText("IGUI_NoBuildingNearby") or "No building nearby")
        end
        -- LKS_EletricidadeConstrucao.Print("[ConnectBuilding] No building found near generator")
        return true
    end

    local building = buildingSquare:getBuilding()
    if not building then
        LKS_EletricidadeConstrucao.Error("[ConnectBuilding] Building object not found")
        return true
    end

    -- Derive a stable pool ID using the building's canonical coordinate format
    -- (bld_X_Y_Z) matching LKS_EletricidadeConstrucao_Data_Building.MakeId. Priority:
    --   1. Light switch position (canonical - matches ScanBuilding's stored key)
    --   2. BuildingDef origin (stable for all walls, same physical building)
    --   3. buildingSquare fallback (shouldn't happen)
    local def = building.getDef and building:getDef()

    -- Try to find light switch first for canonical ID
    local lsX0, lsY0, lsZ0 = FindBuildingLightSwitch(building, buildingSquare:getZ())

    local buildingID
    if lsX0 then
        -- Canonical ID from light switch - matches what ScanBuilding stores
        buildingID = string.format("bld_%d_%d_%d", lsX0, lsY0, lsZ0)
        LKS_EletricidadeConstrucao.Print(string.format(
            "[ConnectBuilding] Canonical ID from light switch: %s", buildingID))
    elseif def and def.getX and def.getY then
        -- No light switch yet - use BuildingDef's stable origin coordinates.
        -- All generators on the same building share the same def origin, so
        -- this prevents pool split even without a light switch.
        buildingID = string.format("bld_%d_%d_%d",
            def:getX(), def:getY(), buildingSquare:getZ())
        LKS_EletricidadeConstrucao.Print(string.format(
            "[ConnectBuilding] Fallback ID from def origin: %s (no light switch found)",
            buildingID))
    else
        -- Last resort: use building square coords
        buildingID = string.format("bld_%d_%d_%d",
            buildingSquare:getX(), buildingSquare:getY(), buildingSquare:getZ())
        LKS_EletricidadeConstrucao.Warn(string.format(
            "[ConnectBuilding] FALLBACK: Using buildingSquare coords: %s",
            buildingID))
    end

    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local buildingData = StateManager and StateManager.GetBuilding(buildingID)

    local currentPoolCount = CountEntries(buildingData and buildingData.connectedGenerators)
    if not buildingData or currentPoolCount == 0 then
        local existingBuildingId, existingBuildingData = FindExistingBuildingMatch(
            building,
            buildingSquare,
            buildingID
        )

        if existingBuildingId and existingBuildingData then
            if buildingData and currentPoolCount == 0 and buildingID ~= existingBuildingId
                    and StateManager and StateManager.RemoveBuilding then
                StateManager.RemoveBuilding(buildingID)
            end

            buildingID = existingBuildingId
            buildingData = existingBuildingData
            LKS_EletricidadeConstrucao.Print(string.format(
                "[ConnectBuilding] Reusing existing building %s for overlapping footprint - adding generator to pool (consumers: %d, power: %.1f)",
                buildingID, buildingData.totalConsumers or 0, buildingData.totalPowerDraw or 0))
        end
    end

    -- Tag the generator with the shared pool ID
    local md = self.generator:getModData()
    md.Gen_BuildingPoolID = buildingID
    md.LKS_EletricidadeConstrucao_DisconnectSuppressed = nil

    -- Check pool capacity BEFORE proceeding (prevent exceeding 10 generator limit)
    if buildingData and buildingData.connectedGenerators then
        local genSquare = self.generator:getSquare()
        local genKey = genSquare and string.format("%d_%d_%d", 
            genSquare:getX(), genSquare:getY(), genSquare:getZ()) or nil
        
        local poolSize = 0
        local alreadyInPool = false
        for _, k in pairs(buildingData.connectedGenerators) do
            poolSize = poolSize + 1
            if k == genKey then
                alreadyInPool = true
            end
        end
        
        local maxGenerators = (LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.BUILDING 
                              and LKS_EletricidadeConstrucao.Constants.BUILDING.MAX_GENERATORS_PER_BUILDING) or 10
        
        if not alreadyInPool and poolSize >= maxGenerators then
            -- Pool is full - reject connection
            md.Gen_BuildingPoolID = nil  -- Clear the tag we just set
            if ShouldSayToCharacter(Runtime) then
                self.character:Say(string.format("Pool full (%d/%d generators)", poolSize, maxGenerators))
            end
            LKS_EletricidadeConstrucao.Warn(string.format(
                "[ConnectBuilding] Pool full: %d/%d generators already connected to building %s",
                poolSize, maxGenerators, buildingID))
            return true
        end
    end

    -- Stamp the world ID immediately so TryRestoreFromIsoModData can validate
    -- this entry belongs to the current save (cross-save isolation).
    local SM = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if SM and SM.GetCurrentWorldId then
        local currentWorldId = SM.GetCurrentWorldId()
        if currentWorldId and currentWorldId ~= "unknown" then
            md.LKS_EletricidadeConstrucao_WorldId = currentWorldId
        end
    end

    -- LKS_EletricidadeConstrucao.Print("[ConnectBuilding] Connected generator to building pool: " .. buildingID)

    -- Check if building already exists in state (avoid unnecessary rescans)
    
    -- Only scan if building doesn't exist yet
    if not buildingData and LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner
            and LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding then

        -- Reuse lsX0/lsY0/lsZ0 found during ID derivation above (avoids redundant search)
        local lsX, lsY, lsZ = lsX0, lsY0, lsZ0
        if not lsX then
            lsX, lsY, lsZ = FindBuildingLightSwitch(building, buildingSquare:getZ())
        end

        if lsX and lsY and lsZ then
            -- LKS_EletricidadeConstrucao.Print(string.format(
            --     "[ConnectBuilding] First generator for building %s - scanning from light switch (%d,%d,%d)...",
            --     buildingID, lsX, lsY, lsZ))

            -- Pass buildingID as override so the scanner stores the building
            -- data under the same key across all generator connections.
            buildingData = LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(lsX, lsY, lsZ, buildingID)

            if buildingData then
                -- LKS_EletricidadeConstrucao.Print("[ConnectBuilding] Building scan complete.")
            end
        end
    else
        -- LKS_EletricidadeConstrucao.Print(string.format(
        --     "[ConnectBuilding] Building %s already exists (consumers: %d, power: %.1f) - skipping rescan",
        --     buildingID, buildingData and buildingData.totalConsumers or 0,
        --     buildingData and buildingData.totalPowerDraw or 0))
    end

    if not buildingData and StateManager and StateManager.GetBuilding then
        buildingData = StateManager.GetBuilding(buildingID)
    end

    -- Always rebuild the generator back-link immediately. A reconnect can stamp
    -- Gen_BuildingPoolID before the live building entry is fully available, and
    -- fuel / barrel resolution must not wait for a restart-time repair pass.
    local genSquare = self.generator:getSquare()
    if genSquare and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
            and LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator then
        local genX, genY, genZ = genSquare:getX(), genSquare:getY(), genSquare:getZ()
        local genId = LKS_EletricidadeConstrucao.Data.Generator.MakeId(genX, genY, genZ)
        local genData = LKS_EletricidadeConstrucao.Core.StateManager.GetGenerator(genId)
        if not genData then
            genData = LKS_EletricidadeConstrucao.Data.Generator.New(self.generator)
        end
        genData.connectedBuildings = genData.connectedBuildings or {}
        if LKS_EletricidadeConstrucao.Data.Generator.AddBuilding then
            LKS_EletricidadeConstrucao.Data.Generator.AddBuilding(genData, buildingID)
        else
            local hasBid = false
            for _, bid in pairs(genData.connectedBuildings) do
                if bid == buildingID then hasBid = true; break end
            end
            if not hasBid then
                table.insert(genData.connectedBuildings, buildingID)
            end
        end
        LKS_EletricidadeConstrucao.Core.StateManager.AddGenerator(genData)
    end

    -- Register the generator in the building's connected list (whether new or existing)
    if buildingData then
        if genSquare then
            local genKey = string.format("%d_%d_%d",
                genSquare:getX(), genSquare:getY(), genSquare:getZ())
            buildingData.connectedGenerators = buildingData.connectedGenerators or {}
            local alreadyLinked = false
            -- connectedGenerators is Kahlua-deserialized (string numeric keys); use pairs
            for _, k in pairs(buildingData.connectedGenerators) do
                if k == genKey then alreadyLinked = true; break end
            end
            if not alreadyLinked then
                table.insert(buildingData.connectedGenerators, genKey)
                -- LKS_EletricidadeConstrucao.Print(string.format(
                --     "[ConnectBuilding] Generator %s linked to building %s",
                --     genKey, buildingID))
            end
        end
    end

    -- Register the generator in StateManager before forcing a stats refresh.
    -- Otherwise the distributor still sees the old pool topology for this tick.
    if buildingData then
        -- Force an immediate stats sync now that the generator is visible in
        -- StateManager, so the Info Window reflects the full active pool.
        if LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
                and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding then
            LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(buildingID)
        end

        -- Force an immediate heating sync for the same reason.
        if LKS_EletricidadeConstrucao.Heating and LKS_EletricidadeConstrucao.Heating.Manager
                and LKS_EletricidadeConstrucao.Heating.Manager.SyncToGenerators then
            LKS_EletricidadeConstrucao.Heating.Manager.SyncToGenerators(buildingData)
        end

        -- Persist immediately so the building/generator linkage survives
        -- short sessions where EveryOneMinute/OnServerShutdown might not fire.
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                and LKS_EletricidadeConstrucao.Core.StateManager.Save then
            LKS_EletricidadeConstrucao.Core.StateManager.Save(true, true)
        end

        -- Set this generator as pool owner if no other generator in the pool already
        -- holds LKS_EletricidadeConstrucao_PoolData.  The owner stores stable building geometry so that on
        -- reload we can restore the building without a full scan.
        local genSq = self.generator:getSquare()
        if genSq then
            local genKey = string.format("%d_%d_%d", genSq:getX(), genSq:getY(), genSq:getZ())
            local cell = getCell and getCell()
            local ownerExists = false
            if cell then
                -- connectedGenerators is Kahlua-deserialized (string numeric keys); use pairs
                for _, k in pairs(buildingData.connectedGenerators or {}) do
                    if k ~= genKey then
                        local ox, oy, oz = string.match(k, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        if ox then
                            local oSq = cell:getGridSquare(tonumber(ox), tonumber(oy), tonumber(oz))
                            if oSq then
                                local oObjs = oSq:getObjects()
                                for oi = 0, oObjs:size()-1 do
                                    local oObj = oObjs:get(oi)
                                    if oObj and instanceof(oObj, "IsoGenerator") then
                                        if oObj:getModData().LKS_EletricidadeConstrucao_PoolData then
                                            ownerExists = true
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if ownerExists then break end
                end
            end
            if not ownerExists then
                -- This generator becomes the pool owner (holds stable building data)
                md.LKS_EletricidadeConstrucao_PoolData = {
                    id           = buildingData.id,
                    x            = buildingData.x,
                    y            = buildingData.y,
                    z            = buildingData.z,
                    boundingBox  = buildingData.boundingBox,
                    borderRadius = buildingData.borderRadius or 0,
                    isRVInterior = buildingData.isRVInterior or false,
                }
            end
        end
    else
        LKS_EletricidadeConstrucao.Warn("[ConnectBuilding] Building scan failed or no light switch found - consumer detection requires a light switch inside the building")
    end

    -- Power.Manager.UpdateConnections() runs every 60 s and automatically pairs
    -- all generators within MAX_POWER_RANGE to any known building in StateManager,
    -- so no manual ConnectGenerator call is needed here.

    -- Sync to clients in MP (no-op in SP)
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        self.generator:transmitModData()
        if isServer() then
            self.generator:sync()
        end
    end

    -- Show connection status with generator count (X/10)
    local connectedCount = 0
    if buildingData and buildingData.connectedGenerators then
        -- Count generators using pairs() for Kahlua compatibility
        for _ in pairs(buildingData.connectedGenerators) do
            connectedCount = connectedCount + 1
        end
    end
    
    local maxGenerators = (LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.BUILDING 
                          and LKS_EletricidadeConstrucao.Constants.BUILDING.MAX_GENERATORS_PER_BUILDING) or 10
    local message = string.format("%s (%d/%d)", 
        getText("IGUI_ConnectedToBuilding") or "Connected to building",
        connectedCount, maxGenerators)
    if ShouldSayToCharacter(Runtime) then
        self.character:Say(message)
    end

    return true
end

-- ============================================================
-- DURATION & CONSTRUCTOR
-- ============================================================

function LKS_EletricidadeConstrucao_ConnectBuilding:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 100
end

function LKS_EletricidadeConstrucao_ConnectBuilding:new(character, generator)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.generator = generator
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

-- ============================================================
-- EXPORT TO NAMESPACE
-- ============================================================

LKS_EletricidadeConstrucao.Actions.ConnectBuilding = LKS_EletricidadeConstrucao_ConnectBuilding

-- print("[LKS_EletricidadeConstrucao_Actions_ConnectBuilding] Connect Building action loaded successfully")
