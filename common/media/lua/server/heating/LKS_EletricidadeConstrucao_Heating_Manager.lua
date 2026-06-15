-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Heating_Manager.lua
-- LKS_EletricidadeConstrucao V2 - Building Heating Manager (Server-side)
-- Calculates heating positions from building rooms and syncs to generator ModData.
-- Client reads HeatingPositions and creates IsoHeatSource objects.

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Heating_Manager] LKS_EletricidadeConstrucao namespace not found - skipping")
    return
end

LKS_EletricidadeConstrucao.Heating = LKS_EletricidadeConstrucao.Heating or {}
LKS_EletricidadeConstrucao.Heating.Manager = LKS_EletricidadeConstrucao.Heating.Manager or {}

local Heating = LKS_EletricidadeConstrucao.Heating.Manager
local Logger  = LKS_EletricidadeConstrucao.Core.Logger

-- ============================================================
-- CONSTANTS
-- ============================================================

local LARGE_ROOM_THRESHOLD = 50   -- tiles; above this uses corner method
local DEFAULT_TARGET_TEMP  = 22   -- default heating target (Celsius)

-- ============================================================
-- POSITION CALCULATION
-- ============================================================

-- Calculate heat source positions for one room.
-- Small rooms: single center point.
-- Large rooms: four corners (+ center if >200 tiles).
local function PositionsForRoom(room, floorZ)
    local rects = room.getRects and room:getRects()
    if not rects or rects:size() == 0 then return {} end

    local minX, minY, maxX, maxY = 999999, 999999, -999999, -999999
    local totalTiles = 0

    for ri = 0, rects:size() - 1 do
        local r = rects:get(ri)
        local x1, x2 = r:getX(), r:getX2()
        local y1, y2 = r:getY(), r:getY2()
        if x2 > x1 and y2 > y1 then
            minX = math.min(minX, x1); minY = math.min(minY, y1)
            maxX = math.max(maxX, x2); maxY = math.max(maxY, y2)
            totalTiles = totalTiles + (x2 - x1) * (y2 - y1)
        end
    end

    if totalTiles <= 0 or minX == 999999 then return {} end

    local pos   = {}
    local INSET = 1

    if totalTiles <= LARGE_ROOM_THRESHOLD then
        table.insert(pos, {
            x = math.floor(minX + (maxX - minX) * 0.5),
            y = math.floor(minY + (maxY - minY) * 0.5),
            z = floorZ,
        })
    else
        table.insert(pos, {x = minX + INSET,     y = minY + INSET,     z = floorZ})
        table.insert(pos, {x = maxX - INSET - 1, y = minY + INSET,     z = floorZ})
        table.insert(pos, {x = minX + INSET,     y = maxY - INSET - 1, z = floorZ})
        table.insert(pos, {x = maxX - INSET - 1, y = maxY - INSET - 1, z = floorZ})
        if totalTiles > 200 then
            table.insert(pos, {
                x = math.floor(minX + (maxX - minX) * 0.5),
                y = math.floor(minY + (maxY - minY) * 0.5),
                z = floorZ,
            })
        end
    end

    return pos
end

-- Find IsoBuilding from buildingData (x/y/z = light-switch coords).
local function FindIsoBuilding(buildingData)
    local cell = getCell()
    if not cell then return nil end

    local sq = cell:getGridSquare(buildingData.x, buildingData.y, buildingData.z)
    if sq then
        local b = sq:getBuilding()
        if b then return b end
    end

    if buildingData.boundingBox then
        local bb  = buildingData.boundingBox
        local cx  = math.floor((bb.minX + bb.maxX) * 0.5)
        local cy  = math.floor((bb.minY + bb.maxY) * 0.5)
        local sq2 = cell:getGridSquare(cx, cy, buildingData.z)
        if sq2 then
            local b2 = sq2:getBuilding()
            if b2 then return b2 end
        end
    end

    return nil
end

-- Fallback: group buildingData.powerConsumers by square:getRoom() (mirrors V1's
-- CalculatePlayerBuiltHeating) to handle player-built buildings with no IsoBuilding.
local function PositionsFromConsumerTiles(buildingData)
    if not buildingData then return {} end

    local cell = getCell()
    if not cell then return {} end

    -- Collect all interior positions: use powerConsumers x/y/z OR re-scan
    -- GetInteriorTiles if consumers list is empty.
    local tileSet = {}
    if buildingData.powerConsumers then
        -- powerConsumers is Kahlua-deserialized after GlobalModData load → string numeric
        -- keys. # returns 0 and ipairs iterates nothing on such tables. Use pairs().
        for _, c in pairs(buildingData.powerConsumers) do
            if c.x and c.y and c.z then
                tileSet[c.x .. "_" .. c.y .. "_" .. c.z] = {x = c.x, y = c.y, z = c.z}
            end
        end
    end

    -- Group tiles by IsoRoom object (same as V1 CalculatePlayerBuiltHeating)
    local roomGroups = {}
    local noRoomGroup = {tiles = {}, minX = 999999, minY = 999999, maxX = -1, maxY = -1,
                         z = buildingData.z}

    for _, tile in pairs(tileSet) do
        local sq = cell:getGridSquare(tile.x, tile.y, tile.z)
        if sq then
            local room = sq:getRoom()
            if room then
                if not roomGroups[room] then
                    roomGroups[room] = {tiles = {}, minX = 999999, minY = 999999,
                                        maxX = -1, maxY = -1, z = tile.z,
                                        name = (room.getName and room:getName()) or "UnknownRoom"}
                end
                local g = roomGroups[room]
                table.insert(g.tiles, tile)
                if tile.x < g.minX then g.minX = tile.x end
                if tile.y < g.minY then g.minY = tile.y end
                if tile.x > g.maxX then g.maxX = tile.x end
                if tile.y > g.maxY then g.maxY = tile.y end
            else
                table.insert(noRoomGroup.tiles, tile)
                if tile.x < noRoomGroup.minX then noRoomGroup.minX = tile.x end
                if tile.y < noRoomGroup.minY then noRoomGroup.minY = tile.y end
                if tile.x > noRoomGroup.maxX then noRoomGroup.maxX = tile.x end
                if tile.y > noRoomGroup.maxY then noRoomGroup.maxY = tile.y end
            end
        end
    end

    local result = {}
    local INSET  = 1

    local function groupToPositions(group, roomID)
        if not group or #group.tiles == 0 then return end
        local n  = #group.tiles
        local z  = group.z
        local pos = {}
        if n <= LARGE_ROOM_THRESHOLD then
            table.insert(pos, {
                x = math.floor(group.minX + (group.maxX - group.minX) * 0.5),
                y = math.floor(group.minY + (group.maxY - group.minY) * 0.5),
                z = z,
            })
        else
            table.insert(pos, {x = group.minX + INSET,     y = group.minY + INSET,     z = z})
            table.insert(pos, {x = group.maxX - INSET,     y = group.minY + INSET,     z = z})
            table.insert(pos, {x = group.minX + INSET,     y = group.maxY - INSET,     z = z})
            table.insert(pos, {x = group.maxX - INSET,     y = group.maxY - INSET,     z = z})
            if n > 200 then
                table.insert(pos, {
                    x = math.floor(group.minX + (group.maxX - group.minX) * 0.5),
                    y = math.floor(group.minY + (group.maxY - group.minY) * 0.5),
                    z = z,
                })
            end
        end
        if #pos > 0 then
            table.insert(result, {roomID = roomID, positions = pos, z = z})
        end
    end

    local idx = 0
    for _, g in pairs(roomGroups) do
        idx = idx + 1
        groupToPositions(g, g.name or ("Room_" .. idx))
    end
    if #noRoomGroup.tiles > 0 then
        groupToPositions(noRoomGroup, "OpenArea")
    end

    return result
end

-- Compute the full HeatingPositions table for a building.
-- Returns: {{roomID="...", positions=[{x,y,z},...], z=N}, ...}
function Heating.CalculatePositions(buildingData)
    if not buildingData then return {} end

    local isoBuilding = FindIsoBuilding(buildingData)

    if not isoBuilding then
        -- No vanilla IsoBuilding (player-built or open-air area).
        -- Group the already-scanned powerConsumers by room — same approach as V1's
        -- CalculatePlayerBuiltHeating() — for accurate per-room heat placement.
        local fallback = PositionsFromConsumerTiles(buildingData)
        if fallback and #fallback > 0 then return fallback end

        -- Last resort: single point at bounding box center
        if buildingData.boundingBox then
            local bb = buildingData.boundingBox
            return {{
                roomID    = "Fallback",
                positions = {{
                    x = math.floor((bb.minX + bb.maxX) * 0.5),
                    y = math.floor((bb.minY + bb.maxY) * 0.5),
                    z = buildingData.z,
                }},
                z = buildingData.z,
            }}
        end
        return {}
    end

    local def = isoBuilding.getDef and isoBuilding:getDef()
    if not def then return {} end
    local rooms = def.getRooms and def:getRooms()
    if not rooms or rooms:size() == 0 then return {} end

    local result = {}

    for i = 0, rooms:size() - 1 do
        local room = rooms:get(i)
        if room then
            -- def:getRooms() returns RoomDef objects, which have getZ() -> int directly.
            -- z=0 (ground floor) rooms use buildingData.z as safe fallback.
            local floorZ = tonumber(room:getZ()) or buildingData.z

            local positions = PositionsForRoom(room, floorZ)
            if #positions > 0 then
                local roomName = (room.getName and room:getName()) or ("Room_" .. i)
                table.insert(result, {
                    roomID    = tostring(roomName),
                    positions = positions,
                    z         = floorZ,
                })
            end
        end
    end

    return result
end

-- ============================================================
-- SYNC TO GENERATORS
-- ============================================================

function Heating.SyncToGenerators(buildingData)
    if not buildingData or not buildingData.connectedGenerators then return end

    local cell = getCell()
    if not cell then return end

    local positions = Heating.CalculatePositions(buildingData)
    if not positions or #positions == 0 then return end

    -- Calculate heating source count for GlobalModData persistence
    local sourceCount = 0
    for _, grp in ipairs(positions) do
        if type(grp.positions) == "table" then
            sourceCount = sourceCount + #grp.positions
        end
    end

    -- Track building-level heating state from the first generator we can read.
    -- All generators in the same pool share the same building heating config,
    -- so the first generator's ModData is authoritative for the building.
    local buildingHeatingEnabled = false
    local buildingTargetTemp     = DEFAULT_TARGET_TEMP

    -- NOTE: connectedGenerators may be a Kahlua-deserialized table with string numeric
    -- keys ("1", "2", …) instead of integer keys – ipairs() returns nothing in that case.
    -- Use pairs() so all generators are visited regardless of key type.
    for _, genKey in pairs(buildingData.connectedGenerators) do
        local px, py, pz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            px, py, pz = tonumber(px), tonumber(py), tonumber(pz)
            local sq = cell:getGridSquare(px, py, pz)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local gen = objs:get(i)
                    if gen and instanceof(gen, "IsoGenerator") then
                        local md = gen:getModData()
                        md.HeatingPositions = positions
                        -- Explicitly initialize HeatingEnabled=false when first seen.
                        -- Never auto-enable; heating must be turned on intentionally by the player.
                        -- This also prevents the client-side nil-check from auto-enabling on
                        -- initial pool creation or after a ModData reload that drops false values.
                        if md.HeatingEnabled == nil then
                            md.HeatingEnabled = false
                            if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                gen:transmitModData()
                            end
                        end
                        if md.HeatingTargetTemp == nil then
                            md.HeatingTargetTemp = DEFAULT_TARGET_TEMP
                        end

                        -- Capture building-level values from this generator's moddata
                        if md.HeatingEnabled == true then
                            buildingHeatingEnabled = true
                        end
                        buildingTargetTemp = tonumber(md.HeatingTargetTemp) or DEFAULT_TARGET_TEMP

                        -- Sync heating config to GeneratorData (GlobalModData) for chunk-independent fuel calculation
                        local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
                        if StateManager then
                            local genId = LKS_EletricidadeConstrucao.Data.Generator.MakeId(px, py, pz)
                            local genData = StateManager.GetGenerator(genId)
                            if genData then
                                genData.heatingEnabled = (md.HeatingEnabled == true)
                                genData.heatingSourceCount = sourceCount
                                genData.heatingTargetTemp = tonumber(md.HeatingTargetTemp) or DEFAULT_TARGET_TEMP
                            end
                        end
                        
                        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                            gen:transmitModData()
                        end
                        break
                    end
                end
            end
        end
    end

    -- Persist heating state on the building itself.
    -- Heating is a building/pool attribute; CalculateFuelConsumption reads from here
    -- so that multi-generator pools don't double-count heating (one entry per building,
    -- not one entry per generator).  The StateManager.MarkDirty() ensures persistence.
    --
    -- IMPORTANT: Only overwrite buildingData.heatingEnabled when we actually found at
    -- least one IsoGenerator in the chunk.  If the chunk is not yet loaded, the inner
    -- loop never executes; `buildingHeatingEnabled` stays false; we must NOT overwrite
    -- the value that was restored from GlobalModData save — that would clear heating
    -- state every time SyncToGenerators runs at startup before the chunk loads.
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local foundAnyGen  = (sourceCount > 0) -- sourceCount > 0 only when CalculatePositions returned data (requires IsoBuilding access)
    -- Use a more reliable indicator: track whether the generator loop found any IsoObj.
    -- Re-derive: if buildingHeatingEnabled is true we definitely found a generator.
    -- If false, we might have found generators with HeatingEnabled=false OR found nothing.
    -- Check sourceCount: it is recalculated from CalculatePositions which requires the
    -- isoBuilding to be accessible — if 0, positions could not be computed (off-chunk).
    if sourceCount > 0 then
        -- Positions were successfully calculated → both heatingEnabled and temp are fresh.
        buildingData.heatingEnabled      = buildingHeatingEnabled
        buildingData.heatingSourceCount  = sourceCount
        buildingData.heatingTargetTemp   = buildingTargetTemp
    else
        -- Could not compute positions (building not in chunk yet).  Preserve whatever
        -- was stored in GlobalModData so fuel calculation is not disrupted.
        -- Only update heatingTargetTemp if we actually found a generator with a temp value.
        if buildingHeatingEnabled then
            buildingData.heatingEnabled = true
        end
        if buildingTargetTemp ~= DEFAULT_TARGET_TEMP or buildingData.heatingTargetTemp == nil then
            buildingData.heatingTargetTemp = buildingTargetTemp
        end
        -- Do not touch heatingSourceCount – keep whatever was saved.
    end
    if StateManager then
        StateManager.MarkDirty()
    end
end

-- ============================================================
-- UPDATE LOOP  (called from EveryOneMinute in ServerInit)
-- ============================================================

function Heating.Update()
    if isClient() and not isServer() then return end

    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    if not StateManager then return end
    local buildings = StateManager.GetAllBuildings()
    if not buildings then return end

    -- GetAllBuildings() returns a hash-map keyed by building ID – must use pairs()
    for _, buildingData in pairs(buildings) do
        -- NOTE: connectedGenerators is a Kahlua-deserialized hash-map after reload;
        -- the # operator returns 0 for hash-maps.  Use pairs() to test non-emptiness.
        if buildingData.connectedGenerators then
            local _hasGens = false
            for _ in pairs(buildingData.connectedGenerators) do _hasGens = true; break end
            if _hasGens then
                Heating.SyncToGenerators(buildingData)
            end
        end
    end
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

function Heating.Initialize()
    Logger.Info("Heating.Manager", "Heating Manager initialized.")
end

LKS_EletricidadeConstrucao.RegisterModule("Heating.Manager", "2.0.0")

return Heating
