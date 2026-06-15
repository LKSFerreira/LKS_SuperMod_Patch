-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Utils_Geometry.lua
-- LKS_EletricidadeConstrucao V2 - Geometric/Spatial Utility Functions
-- Tile calculations, distance, borders, etc.
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Utils_Geometry] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- TILE DISTANCE & PROXIMITY
-- ============================================================================

--- Calculate Manhattan distance between two tiles
--- @param x1 number First tile X
--- @param y1 number First tile Y
--- @param x2 number Second tile X
--- @param y2 number Second tile Y
--- @return number Manhattan distance (sum of abs differences)
function LKS_EletricidadeConstrucao.Utils.Geometry.ManhattanDistance(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end

--- Calculate Euclidean distance between two tiles
--- @param x1 number First tile X
--- @param y1 number First tile Y
--- @param x2 number Second tile X
--- @param y2 number Second tile Y
--- @return number Euclidean distance
function LKS_EletricidadeConstrucao.Utils.Geometry.EuclideanDistance(x1, y1, x2, y2)
    return LKS_EletricidadeConstrucao.Utils.Math.Distance2D(x1, y1, x2, y2)
end

--- Calculate Chebyshev distance (max of axis distances)
--- @param x1 number First tile X
--- @param y1 number First tile Y
--- @param x2 number Second tile X
--- @param y2 number Second tile Y
--- @return number Chebyshev distance
function LKS_EletricidadeConstrucao.Utils.Geometry.ChebyshevDistance(x1, y1, x2, y2)
    return math.max(math.abs(x2 - x1), math.abs(y2 - y1))
end

--- Check if two tiles are adjacent (including diagonals)
--- @param x1 number First tile X
--- @param y1 number First tile Y
--- @param x2 number Second tile X
--- @param y2 number Second tile Y
--- @return boolean True if adjacent
function LKS_EletricidadeConstrucao.Utils.Geometry.IsAdjacent(x1, y1, x2, y2)
    return LKS_EletricidadeConstrucao.Utils.Geometry.ChebyshevDistance(x1, y1, x2, y2) == 1
end

--- Check if tile is within radius of center
--- @param x number Tile X
--- @param y number Tile Y
--- @param centerX number Center X
--- @param centerY number Center Y
--- @param radius number Radius (Euclidean)
--- @return boolean True if within radius
function LKS_EletricidadeConstrucao.Utils.Geometry.IsWithinRadius(x, y, centerX, centerY, radius)
    local distSq = LKS_EletricidadeConstrucao.Utils.Math.DistanceSquared2D(x, y, centerX, centerY)
    return distSq <= (radius * radius)
end

-- ============================================================================
-- COORDINATE VALIDATION
-- ============================================================================

--- Check if coordinates are valid (RV Interior compatible)
--- RV Interior uses range -100000 to 200000
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate (optional)
--- @return boolean True if valid
function LKS_EletricidadeConstrucao.Utils.Geometry.IsValidCoordinate(x, y, z)
    if not x or not y then return false end
    
    local constants = LKS_EletricidadeConstrucao.Constants.BUILDING
    
    -- Check X coordinate
    if x < constants.RV_INTERIOR_MIN_COORD or x > constants.RV_INTERIOR_MAX_COORD then
        return false
    end
    
    -- Check Y coordinate
    if y < constants.RV_INTERIOR_MIN_COORD or y > constants.RV_INTERIOR_MAX_COORD then
        return false
    end
    
    -- Check Z coordinate if provided
    if z then
        if z < constants.MIN_Z_LEVEL or z > constants.MAX_Z_LEVEL then
            return false
        end
    end
    
    return true
end

--- Check if coordinate is in RV Interior range
--- @param x number X coordinate
--- @param y number Y coordinate
--- @return boolean True if RV Interior coordinate
function LKS_EletricidadeConstrucao.Utils.Geometry.IsRVInteriorCoordinate(x, y)
    -- RV Interior typically uses negative coordinates
    return x < 0 or y < 0
end

-- ============================================================================
-- BOUNDING BOX
-- ============================================================================

--- Create bounding box from list of coordinates
--- @param coordinates table Array of {x, y} or {x, y, z} tables
--- @return table Bounding box {minX, minY, maxX, maxY} or nil if empty
function LKS_EletricidadeConstrucao.Utils.Geometry.GetBoundingBox(coordinates)
    if not coordinates or #coordinates == 0 then
        return nil
    end
    
    local minX = coordinates[1][1] or coordinates[1].x
    local minY = coordinates[1][2] or coordinates[1].y
    local maxX = minX
    local maxY = minY
    
    for i = 2, #coordinates do
        local x = coordinates[i][1] or coordinates[i].x
        local y = coordinates[i][2] or coordinates[i].y
        
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end
    
    return {
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY,
        width = maxX - minX + 1,
        height = maxY - minY + 1
    }
end

--- Check if point is inside bounding box
--- @param x number Point X
--- @param y number Point Y
--- @param bbox table Bounding box {minX, minY, maxX, maxY}
--- @return boolean True if inside
function LKS_EletricidadeConstrucao.Utils.Geometry.IsInsideBBox(x, y, bbox)
    return x >= bbox.minX and x <= bbox.maxX and
           y >= bbox.minY and y <= bbox.maxY
end

--- Expand bounding box by margin
--- @param bbox table Bounding box {minX, minY, maxX, maxY}
--- @param margin number Margin to add on all sides
--- @return table Expanded bounding box
function LKS_EletricidadeConstrucao.Utils.Geometry.ExpandBBox(bbox, margin)
    return {
        minX = bbox.minX - margin,
        minY = bbox.minY - margin,
        maxX = bbox.maxX + margin,
        maxY = bbox.maxY + margin,
        width = bbox.width + (margin * 2),
        height = bbox.height + (margin * 2)
    }
end

-- ============================================================================
-- BORDER DETECTION
-- ============================================================================

--- Get all tiles in radius around center (circular)
--- @param centerX number Center X
--- @param centerY number Center Y
--- @param radius number Radius
--- @return table Array of {x, y} coordinates
function LKS_EletricidadeConstrucao.Utils.Geometry.GetTilesInRadius(centerX, centerY, radius)
    local tiles = {}
    
    for x = centerX - radius, centerX + radius do
        for y = centerY - radius, centerY + radius do
            if LKS_EletricidadeConstrucao.Utils.Geometry.IsWithinRadius(x, y, centerX, centerY, radius) then
                table.insert(tiles, {x = x, y = y})
            end
        end
    end
    
    return tiles
end

--- Get border tiles around a structure (tile-by-tile approach)
--- More accurate than bounding box for L-shaped buildings
--- @param structureTiles table Array of {x, y, z} structure tiles
--- @param borderRadius number Border width in tiles
--- @return table Array of {x, y, z} border tiles
function LKS_EletricidadeConstrucao.Utils.Geometry.GetBorderTiles(structureTiles, borderRadius)
    local borderTiles = {}
    local processedTiles = {}  -- Avoid duplicates
    
    -- For each structure tile, get surrounding tiles
    for _, tile in ipairs(structureTiles) do
        local x = tile.x or tile[1]
        local y = tile.y or tile[2]
        local z = tile.z or tile[3] or 0
        
        -- Check tiles in square around this tile
        for offsetX = -borderRadius, borderRadius do
            for offsetY = -borderRadius, borderRadius do
                -- Skip center tile (0,0) as it's the structure itself
                if offsetX ~= 0 or offsetY ~= 0 then
                    local borderX = x + offsetX
                    local borderY = y + offsetY
                    local key = borderX .. "," .. borderY .. "," .. z
                    
                    -- Only add if not already processed
                    if not processedTiles[key] then
                        processedTiles[key] = true
                        table.insert(borderTiles, {x = borderX, y = borderY, z = z})
                    end
                end
            end
        end
    end
    
    return borderTiles
end

-- ============================================================================
-- DIRECTION & ANGLE
-- ============================================================================

--- Get direction from tile1 to tile2 (normalized vector)
--- @param x1 number First tile X
--- @param y1 number First tile Y
--- @param x2 number Second tile X
--- @param y2 number Second tile Y
--- @return number, number Normalized direction (dx, dy)
function LKS_EletricidadeConstrucao.Utils.Geometry.GetDirection(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    
    if length == 0 then
        return 0, 0
    end
    
    return dx / length, dy / length
end

--- Get angle in degrees from tile1 to tile2
--- @param x1 number First tile X
--- @param y1 number First tile Y
--- @param x2 number Second tile X
--- @param y2 number Second tile Y
--- @return number Angle in degrees (0-360)
function LKS_EletricidadeConstrucao.Utils.Geometry.GetAngle(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local radians = math.atan2(dy, dx)
    local degrees = math.deg(radians)
    
    -- Normalize to 0-360
    if degrees < 0 then
        degrees = degrees + 360
    end
    
    return degrees
end

-- ============================================================================
-- GRID HELPERS
-- ============================================================================

--- Convert world coordinates to chunk coordinates
--- @param x number World X
--- @param y number World Y
--- @return number, number Chunk X, Chunk Y
function LKS_EletricidadeConstrucao.Utils.Geometry.WorldToChunk(x, y)
    -- PZ chunks are 10x10 tiles
    return math.floor(x / 10), math.floor(y / 10)
end

--- Get chunk key string from coordinates
--- @param x number World X
--- @param y number World Y
--- @return string Chunk key "cx,cy"
function LKS_EletricidadeConstrucao.Utils.Geometry.GetChunkKey(x, y)
    local cx, cy = LKS_EletricidadeConstrucao.Utils.Geometry.WorldToChunk(x, y)
    return cx .. "," .. cy
end

--- Parse tile key "x,y,z" into coordinates
--- @param key string Tile key
--- @return number, number, number X, Y, Z coordinates
function LKS_EletricidadeConstrucao.Utils.Geometry.ParseTileKey(key)
    local parts = {}
    for part in string.gmatch(key, "[^,]+") do
        table.insert(parts, tonumber(part))
    end
    return parts[1], parts[2], parts[3] or 0
end

--- Create tile key from coordinates
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate
--- @return string Tile key "x,y,z"
function LKS_EletricidadeConstrucao.Utils.Geometry.MakeTileKey(x, y, z)
    z = z or 0
    return x .. "," .. y .. "," .. z
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Utils.Geometry", "2.0.0")

return LKS_EletricidadeConstrucao.Utils.Geometry
