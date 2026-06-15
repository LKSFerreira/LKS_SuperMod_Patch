-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Building_BorderDetector.lua
-- LKS_EletricidadeConstrucao V2 - Building Border Detector
-- Detects building boundaries using tile-by-tile wall/door scanning
-- Version: 2.0.0-alpha
-- Date: February 22, 2026


-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Building_BorderDetector] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- Initialize sub-namespace
LKS_EletricidadeConstrucao.Building = LKS_EletricidadeConstrucao.Building or {}
LKS_EletricidadeConstrucao.Building.BorderDetector = LKS_EletricidadeConstrucao.Building.BorderDetector or {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local DIRECTIONS = {
    {x =  0, y = -1},  -- North
    {x =  1, y =  0},  -- East
    {x =  0, y =  1},  -- South
    {x = -1, y =  0}   -- West
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Check if a specific Z-level has at least one light switch in the given room bounds
--- @param room BuildingDef Room definition
--- @param z number Z-level to check
--- @return boolean True if at least one light switch exists on this level
local function HasLightSwitchOnLevel(room, z)
    local rx1 = room:getX() - 2
    local ry1 = room:getY() - 2
    local rx2 = room:getX2() + 2
    local ry2 = room:getY2() + 2
    
    for x = rx1, rx2 do
        for y = ry1, ry2 do
            local sq = getSquare(x, y, z)
            if sq then
                local objects = sq:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj and instanceof(obj, "IsoLightSwitch") then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

--- Check if a Z-level has at least one light switch in the given rectangular bounds
--- @param x1 number Min X coordinate
--- @param y1 number Min Y coordinate
--- @param x2 number Max X coordinate
--- @param y2 number Max Y coordinate
--- @param z number Z-level to check
--- @return boolean True if at least one light switch exists on this level
local function HasLightSwitchInBounds(x1, y1, x2, y2, z)
    for x = x1, x2 do
        for y = y1, y2 do
            local sq = getSquare(x, y, z)
            if sq then
                local objects = sq:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj and instanceof(obj, "IsoLightSwitch") then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

--- Determine which Z-levels to scan based on light switch presence.
--- Starts at startZ (ground floor), scans basement levels downward,
--- then scans upward until a level without light switches is found (early termination).
--- @param room BuildingDef Room definition
--- @param startZ number Starting Z-level (light switch position)
--- @return table Array of Z-levels to scan
local function GetZLevelsToScan(room, startZ)
    local rx1 = room:getX() - 2
    local ry1 = room:getY() - 2
    local rx2 = room:getX2() + 2
    local ry2 = room:getY2() + 2
    
    local zLevels = {}
    
    -- Always scan ground floor (Z=0)
    table.insert(zLevels, startZ)
    
    -- Scan basement levels (downward from -1 to -3)
    for z = -1, -3, -1 do
        if HasLightSwitchInBounds(rx1, ry1, rx2, ry2, z) then
            table.insert(zLevels, z)
        end
    end
    
    -- Scan upper levels (upward from +1 to +10)
    -- STOP at first level without light switch (early termination)
    for z = 1, 10 do
        if HasLightSwitchInBounds(rx1, ry1, rx2, ry2, z) then
            table.insert(zLevels, z)
        else
            -- No light switch on this level → stop scanning upward
            break
        end
    end
    
    return zLevels
end

--- Get Z-levels to scan for bounds-based detection (no rooms).
--- @param x1 number Min X bound
--- @param y1 number Min Y bound
--- @param x2 number Max X bound
--- @param y2 number Max Y bound
--- @param startZ number Starting Z-level
--- @return table Array of Z-levels to scan
local function GetZLevelsToScanBounds(x1, y1, x2, y2, startZ)
    local zLevels = {}
    
    -- Always scan ground floor
    table.insert(zLevels, startZ)
    
    -- Scan basement levels (downward)
    for z = -1, -3, -1 do
        if HasLightSwitchInBounds(x1, y1, x2, y2, z) then
            table.insert(zLevels, z)
        end
    end
    
    -- Scan upper levels (upward with early termination)
    for z = 1, 10 do
        if HasLightSwitchInBounds(x1, y1, x2, y2, z) then
            table.insert(zLevels, z)
        else
            break
        end
    end
    
    return zLevels
end

-- ============================================================================
-- BORDER DETECTION
-- ============================================================================

--- Detect ALL tiles belonging to the same IsoBuilding as the light switch.
--- Returns every floor tile so the consumer scanner finds appliances anywhere
--- in the building, not just on the perimeter.
--- @param startX     number  Starting X coordinate (light switch position)
--- @param startY     number  Starting Y coordinate
--- @param startZ     number  Starting Z coordinate
--- @param radius     number  Kept for API compatibility; used only in fallback
--- @param buildingId string  Optional building ID – used to identify player-built
---                           structures ("bld_X_Y_Z") and skip nearby-building search
--- @return table  Array of tiles {x, y, z, type}
function LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBorders(startX, startY, startZ, radius, buildingId)
    LKS_EletricidadeConstrucao.Core.Logger.StartTimer("BorderDetection")

    local startSq       = getSquare(startX, startY, startZ)
    local startBuilding = startSq and startSq:getBuilding()

    -- Detect player-built buildings by their coordinate-based ID ("bld_X_Y_Z").
    -- Player-placed tiles never belong to an IsoBuilding, so we must not scan
    -- nearby vanilla buildings – they are unrelated and would produce wrong consumer data.
    local isPlayerBuilt = buildingId and string.match(buildingId, "^bld_%-?%d+_%-?%d+_%-?%d+$") ~= nil

    if not startBuilding then
        if isPlayerBuilt then
            -- Player-built: no IsoBuilding expected. Use the stored border radius
            -- directly so we scan only the actual footprint of the player structure.
            local fallbackRadius = radius or 30
            print(string.format(
                "[LKS_EletricidadeConstrucao_BorderDetect] Player-built building %s at (%d,%d,%d) – using radius %d fallback",
                buildingId or "?", startX, startY, startZ, fallbackRadius))
            local fallback = LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(
                startX, startY, startZ, fallbackRadius)
            LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BorderDetection", 100)
            return fallback
        end

        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("BorderDetector: no IsoBuilding at (%d,%d,%d), searching nearby buildings...",
                startX, startY, startZ),
            "Building"
        )
        
        -- Search for IsoBuildings in nearby area (light switch might be in garage/annex)
        local nearbyBuildings = {}
        local searchRadius = 10
        for dx = -searchRadius, searchRadius do
            for dy = -searchRadius, searchRadius do
                local sq = getSquare(startX + dx, startY + dy, startZ)
                if sq then
                    local bld = sq:getBuilding()
                    if bld and not nearbyBuildings[bld] then
                        nearbyBuildings[bld] = true
                        print(string.format("[LKS_EletricidadeConstrucao_BorderDetect] Found nearby building at offset (%d,%d)", dx, dy))
                    end
                end
            end
        end
        
        -- If we found buildings, scan all their rooms
        local nearbyBuildingCount = 0
        for bld in pairs(nearbyBuildings) do
            nearbyBuildingCount = nearbyBuildingCount + 1
        end
        
        if nearbyBuildingCount > 0 then
            print(string.format("[LKS_EletricidadeConstrucao_BorderDetect] Found %d nearby building(s), scanning their rooms...", nearbyBuildingCount))
            
            local tiles = {}
            
            for bld in pairs(nearbyBuildings) do
                local def = bld:getDef()
                if def then
                    local rooms = def:getRooms()
                    if rooms and rooms:size() > 0 then
                        for roomIdx = 0, rooms:size() - 1 do
                            local room = rooms:get(roomIdx)
                            if room then
                                local rx1 = room:getX()
                                local ry1 = room:getY()
                                local rx2 = room:getX2()
                                local ry2 = room:getY2()
                                
                                -- Get Z-levels to scan with early termination
                                local zLevels = GetZLevelsToScan(room, startZ)
                                
                                for _, z in ipairs(zLevels) do
                                    for x = rx1 - 2, rx2 + 2 do
                                        for y = ry1 - 2, ry2 + 2 do
                                            table.insert(tiles, {x = x, y = y, z = z, type = "interior"})
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            if #tiles > 0 then
                tiles = LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(tiles)
                print(string.format("[LKS_EletricidadeConstrucao_BorderDetect] Nearby building scan: %d tiles from %d buildings", 
                    #tiles, nearbyBuildingCount))
                LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BorderDetection", 100)
                return tiles
            end
        end
        
        -- Final fallback: use radius scan
        print("[LKS_EletricidadeConstrucao_BorderDetect] No nearby buildings with rooms, using radius fallback")
        local fallback = LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(
            startX, startY, startZ, radius or 80)
        LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BorderDetection", 100)
        return fallback
    end

    -- Use building definition bounds (with a small exterior border) and scan a tall Z range
    -- to mirror the stable V1 Singleplayer behaviour that found lights/appliances across floors.
    local def = startBuilding:getDef()
    if not def then
        local fallback = LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(startX, startY, startZ, radius or 30)
        LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BorderDetection", 100)
        return fallback
    end

    -- For complex buildings (fire stations, malls, etc.), scan ALL rooms in the BuildingDef
    -- instead of just using the overall bounds which may be inaccurate
    local tiles = {}
    
    local rooms = def:getRooms()
    if rooms and rooms:size() > 0 then

        -- Scan every tile in every room with early termination (stops upward at first level without light switch)
        for roomIdx = 0, rooms:size() - 1 do
            local room = rooms:get(roomIdx)
            if room then
                local rx1 = room:getX()
                local ry1 = room:getY()
                local rx2 = room:getX2()
                local ry2 = room:getY2()
                
                -- Get Z-levels to scan with early termination
                local zLevels = GetZLevelsToScan(room, startZ)
                
                for _, z in ipairs(zLevels) do
                    -- Add 2-tile border around each room to catch exterior wall fixtures
                    for x = rx1 - 2, rx2 + 2 do
                        for y = ry1 - 2, ry2 + 2 do
                            local sq = getSquare(x, y, z)
                            if sq then
                                local sqBuilding = sq:getBuilding()
                                if sqBuilding == startBuilding or sqBuilding == nil then
                                    table.insert(tiles, {x = x, y = y, z = z, type = "interior"})
                                end
                            end
                        end
                    end
                end
            end
        end
        
        tiles = LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(tiles)
    else
        -- Fallback to bounds-based scan if no rooms found
        local bx = def:getX()
        local by = def:getY()
        local bw = def:getW()
        local bh = def:getH()
        local borderSize = 2
        local extendedX = bx - borderSize
        local extendedY = by - borderSize
        local extendedW = bw + (borderSize * 2)
        local extendedH = bh + (borderSize * 2)

        -- Get Z-levels to scan with early termination
        local zLevels = GetZLevelsToScanBounds(extendedX, extendedY, extendedX + extendedW - 1, extendedY + extendedH - 1, startZ)
        
        for _, z in ipairs(zLevels) do
            for x = extendedX, extendedX + extendedW - 1 do
                for y = extendedY, extendedY + extendedH - 1 do
                    local sq = getSquare(x, y, z)
                    if sq then
                        local inBuilding = (sq:getBuilding() == startBuilding)
                        local inBorder = (x < bx or x >= bx + bw or y < by or y >= by + bh)
                        if inBuilding or (inBorder and sq:getBuilding() == nil) then
                            table.insert(tiles, {x = x, y = y, z = z, type = "interior"})
                        end
                    end
                end
            end
        end

        tiles = LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(tiles)
    end

    LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BorderDetection", 100)
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("BorderDetector: found %d tiles via bounds scan", #tiles),
        "Building"
    )

    return tiles
end

function LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(cx, cy, cz, r)
    local tiles = {}
    local radius = r or 45  -- enlarged fallback for detached/porch switches
    local zMin   = math.max(0, cz - 3)
    local zMax   = cz + 10  -- Limited to Z+10 to prevent data overflow
    for dz = zMin, zMax do
        for dx = -radius, radius do
            for dy = -radius, radius do
                local sx, sy, sz = cx + dx, cy + dy, dz
                local sq = getSquare(sx, sy, sz)
                if sq then
                    table.insert(tiles, {x = sx, y = sy, z = sz, type = "interior"})
                end
            end
        end
    end
    return tiles
end
--- Check if there is a barrier (wall/door) between two adjacent squares.
--- Uses IsoBuilding membership: squares sharing the same IsoBuilding reference
--- have no wall between them; a nil-vs-building or different-building mismatch
--- means a wall/perimeter boundary exists.
--- @param x1 number From X
--- @param y1 number From Y
--- @param z1 number From Z
--- @param x2 number To X
--- @param y2 number To Y
--- @param z2 number To Z
--- @return boolean True if barrier exists
function LKS_EletricidadeConstrucao.Building.BorderDetector.HasBarrier(x1, y1, z1, x2, y2, z2)
    local square1 = getSquare(x1, y1, z1)
    local square2 = getSquare(x2, y2, z2)

    if not square1 or not square2 then
        return true  -- Missing squares = treat as barrier
    end

    return square1:getBuilding() ~= square2:getBuilding()
end

--- Check if square has a wall/boundary towards target position.
--- Uses IsoBuilding membership comparison.
--- @param square IsoGridSquare Square to check
--- @param targetX number Target X coordinate
--- @param targetY number Target Y coordinate
--- @return boolean True if boundary exists
function LKS_EletricidadeConstrucao.Building.BorderDetector.HasWallTowards(square, targetX, targetY)
    local targetSquare = getSquare(targetX, targetY, square:getZ())
    if not targetSquare then return true end
    return square:getBuilding() ~= targetSquare:getBuilding()
end

--- Check if there's a door between two squares
--- @param square1 IsoGridSquare First square
--- @param square2 IsoGridSquare Second square
--- @param x1 number First X
--- @param y1 number First Y
--- @param x2 number Second X
--- @param y2 number Second Y
--- @return boolean True if door exists
function LKS_EletricidadeConstrucao.Building.BorderDetector.HasDoorBetween(square1, square2, x1, y1, x2, y2)
    -- Check for door on square1
    if LKS_EletricidadeConstrucao.Building.BorderDetector.HasDoorTowards(square1, x2, y2) then
        return true
    end
    
    -- Check for door on square2
    if LKS_EletricidadeConstrucao.Building.BorderDetector.HasDoorTowards(square2, x1, y1) then
        return true
    end
    
    return false
end

--- Check if square has door towards target position
--- @param square IsoGridSquare Square to check
--- @param targetX number Target X coordinate
--- @param targetY number Target Y coordinate
--- @return boolean True if door exists
function LKS_EletricidadeConstrucao.Building.BorderDetector.HasDoorTowards(square, targetX, targetY)
    local objects = square:getObjects()
    
    if not objects then
        return false
    end
    
    local squareX = square:getX()
    local squareY = square:getY()
    
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        
        if obj and instanceof(obj, "IsoDoor") then
            -- Check door orientation
            local north = obj:getNorth()
            
            -- North-facing door blocks north/south movement
            if north then
                if targetY ~= squareY then
                    return true
                end
            else
                -- East-facing door blocks east/west movement
                if targetX ~= squareX then
                    return true
                end
            end
        end
    end
    
    return false
end

--- Remove duplicate tiles from border list
--- @param tiles table Array of {x, y, z, type} tiles
--- @return table Unique tiles
function LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(tiles)
    local seen = {}
    local unique = {}
    
    for _, tile in ipairs(tiles) do
        local key = string.format("%d_%d_%d", tile.x, tile.y, tile.z)
        
        if not seen[key] then
            seen[key] = true
            table.insert(unique, tile)
        end
    end
    
    return unique
end

-- ============================================================================
-- ALTERNATIVE DETECTION METHODS
-- ============================================================================

--- Detect borders using raycast method (faster but less accurate)
--- @param startX number Starting X coordinate
--- @param startY number Starting Y coordinate
--- @param startZ number Starting Z coordinate
--- @param radius number Maximum search radius
--- @return table Array of border tiles
function LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBordersRaycast(startX, startY, startZ, radius)
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Using raycast border detection at (%d,%d,%d) radius=%d",
            startX, startY, startZ, radius),
        "Building"
    )
    
    local borderTiles = {}
    local step = 1  -- Check every tile
    
    -- Cast rays in all directions
    for angle = 0, 359, 15 do  -- 24 rays
        local radians = math.rad(angle)
        local dx = math.cos(radians)
        local dy = math.sin(radians)
        
        -- March along ray until we hit a barrier or radius
        for distance = 1, radius, step do
            local x = math.floor(startX + (dx * distance) + 0.5)
            local y = math.floor(startY + (dy * distance) + 0.5)
            
            local square = getSquare(x, y, startZ)
            
            if not square then
                break
            end
            
            -- Check if this square has a wall in the direction we came from
            local hasWall = LKS_EletricidadeConstrucao.Building.BorderDetector.HasWallTowards(square, startX, startY)
            
            if hasWall then
                table.insert(borderTiles, {
                    x = x,
                    y = y,
                    z = startZ,
                    type = "wall"
                })
                break
            end
        end
    end
    
    return LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(borderTiles)
end

--- Get all tiles inside the same IsoBuilding as the given position.
--- Uses BFS bounded by IsoBuilding object identity (no radius cap).
--- @param startX number  X coordinate (light switch / generator adjacent sq)
--- @param startY number  Y coordinate
--- @param startZ number  Z coordinate
--- @param radius  number Fallback radius when no IsoBuilding is found
--- @return table  Array of {x, y, z} tiles
function LKS_EletricidadeConstrucao.Building.BorderDetector.GetInteriorTiles(startX, startY, startZ, radius)
    local startSq       = getSquare(startX, startY, startZ)
    local startBuilding = startSq and startSq:getBuilding()

    if not startBuilding then
        -- No building: radius fallback
        return LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(
            startX, startY, startZ, radius or 30)
    end

    local def = startBuilding:getDef()
    if not def then
        return LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(startX, startY, startZ, radius or 30)
    end

    local bx = def:getX()
    local by = def:getY()
    local bw = def:getW()
    local bh = def:getH()
    local borderSize = 2
    local extendedX = bx - borderSize
    local extendedY = by - borderSize
    local extendedW = bw + (borderSize * 2)
    local extendedH = bh + (borderSize * 2)

    -- Get Z-levels to scan with early termination
    local zLevels = GetZLevelsToScanBounds(extendedX, extendedY, extendedX + extendedW - 1, extendedY + extendedH - 1, startZ)

    local tiles = {}
    for _, z in ipairs(zLevels) do
        for x = extendedX, extendedX + extendedW - 1 do
            for y = extendedY, extendedY + extendedH - 1 do
                local sq = getSquare(x, y, z)
                if sq then
                    local inBuilding = (sq:getBuilding() == startBuilding)
                    local inBorder = (x < bx or x >= bx + bw or y < by or y >= by + bh)
                    if inBuilding or inBorder then
                        table.insert(tiles, {x = x, y = y, z = z})
                    end
                end
            end
        end
    end

    tiles = LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(tiles)

    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("GetInteriorTiles: found %d tiles via bounds scan", #tiles),
        "Building"
    )

    return tiles
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Print border detection debug info
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate
--- @param radius number Radius
function LKS_EletricidadeConstrucao.Building.BorderDetector.DebugBorders(x, y, z, radius)
    LKS_EletricidadeConstrucao.Print("=== Border Detection Debug ===")
    LKS_EletricidadeConstrucao.Print(string.format("Position: (%d,%d,%d)", x, y, z))
    LKS_EletricidadeConstrucao.Print("Radius: " .. radius)
    
    local borders = LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBorders(x, y, z, radius)
    
    LKS_EletricidadeConstrucao.Print("Border tiles: " .. #borders)
    
    for i = 1, math.min(10, #borders) do
        local tile = borders[i]
        LKS_EletricidadeConstrucao.Print(string.format("  [%d] (%d,%d,%d) type=%s",
            i, tile.x, tile.y, tile.z, tile.type))
    end
    
    if #borders > 10 then
        LKS_EletricidadeConstrucao.Print("  ... " .. (#borders - 10) .. " more")
    end
    
    local interior = LKS_EletricidadeConstrucao.Building.BorderDetector.GetInteriorTiles(x, y, z, radius)
    LKS_EletricidadeConstrucao.Print("Interior tiles: " .. #interior)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Building.BorderDetector", "2.0.0")

return LKS_EletricidadeConstrucao.Building.BorderDetector
