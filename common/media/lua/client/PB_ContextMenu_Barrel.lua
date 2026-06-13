-- ============================================================================
-- 💖 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado como parte do LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3097103233) por sua fantástica contribuição para a comunidade!
-- ============================================================================

-- PB_ContextMenu_Barrel.lua
-- PoweredBuildings V2 - Right-click context menu for petrol barrels.
-- Shows Link / Unlink options when a linkable barrel is right-clicked
-- near a powered building.

if not PoweredBuildings then return end

require "actions/PB_Actions_LinkBarrel"

local function TableHasEntries(t)
    if type(t) ~= "table" then return false end
    for _ in pairs(t) do
        return true
    end
    return false
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

local function FindNearbyIsoBuilding(cell, square, radius)
    local isoBuilding = square and square:getBuilding() or nil
    if isoBuilding then return isoBuilding end
    if not cell or not square then return nil end

    local bx, by, bz = square:getX(), square:getY(), square:getZ()
    for r = 1, radius do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local sq2 = cell:getGridSquare(bx + dx, by + dy, bz)
                    if sq2 then
                        isoBuilding = sq2:getBuilding()
                        if isoBuilding then
                            return isoBuilding
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function BuildingMatchesIso(buildingData, isoBuilding, cell, fallbackZ)
    if not buildingData or not isoBuilding or not cell then return false end
    if buildingData.x == nil or buildingData.y == nil then return false end

    local lsSq = cell:getGridSquare(buildingData.x, buildingData.y, buildingData.z or fallbackZ or 0)
    return lsSq and lsSq:getBuilding() == isoBuilding or false
end

local function IsGeneratorRunning(generatorData)
    local GeneratorData = PoweredBuildings.Data and PoweredBuildings.Data.Generator
    if GeneratorData and GeneratorData.IsRunning then
        return GeneratorData.IsRunning(generatorData)
    end

    return generatorData and (generatorData.fuelAmount or 0) > 0 and generatorData.activated ~= false
end

local function GeneratorReferencesBuilding(generatorData, buildingData, square, stateManager)
    if not generatorData or not buildingData then return false end

    local targetX, targetY = buildingData.x, buildingData.y
    local squareX = square and square:getX() or nil
    local squareY = square and square:getY() or nil

    for _, connectedId in pairs(generatorData.connectedBuildings or {}) do
        if connectedId == buildingData.id then
            return true
        end

        local refBld = stateManager and stateManager.GetBuilding and stateManager.GetBuilding(connectedId) or nil
        if refBld then
            if targetX and targetY and refBld.x == targetX and refBld.y == targetY then
                return true
            end
            if refBld.x and refBld.y and IsInsideBoundingBox(buildingData, refBld.x, refBld.y) then
                return true
            end
            if targetX and targetY and IsInsideBoundingBox(refBld, targetX, targetY) then
                return true
            end
            if squareX and squareY and IsInsideBoundingBox(buildingData, squareX, squareY)
                    and IsInsideBoundingBox(refBld, squareX, squareY) then
                return true
            end
        else
            local cx, cy = string.match(connectedId, "^bld_(%-?%d+)_(%-?%d+)_")
            cx = tonumber(cx)
            cy = tonumber(cy)
            if cx and cy then
                if targetX and targetY and cx == targetX and cy == targetY then
                    return true
                end
                if IsInsideBoundingBox(buildingData, cx, cy) then
                    return true
                end
            end
        end
    end

    return false
end

local function GetBuildingGeneratorScore(buildingData, square, stateManager)
    if not buildingData or not stateManager then return 0 end

    local anyGenerator = false
    local GeneratorData = PoweredBuildings.Data and PoweredBuildings.Data.Generator

    if buildingData.connectedGenerators and GeneratorData and GeneratorData.MakeId and stateManager.GetGenerator then
        for _, genKey in pairs(buildingData.connectedGenerators) do
            local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if gx then
                local gxi, gyi, gzi = tonumber(gx), tonumber(gy), tonumber(gz)
                local genId = (gxi and gyi and gzi) and GeneratorData.MakeId(gxi, gyi, gzi) or nil
                local genData = genId and stateManager.GetGenerator(genId) or nil
                if genData and GeneratorReferencesBuilding(genData, buildingData, square, stateManager) then
                    anyGenerator = true
                    if IsGeneratorRunning(genData) then
                        return 2
                    end
                end
            end
        end
    end

    if stateManager.GetAllGenerators then
        for _, genData in pairs(stateManager.GetAllGenerators() or {}) do
            if GeneratorReferencesBuilding(genData, buildingData, square, stateManager) then
                anyGenerator = true
                if IsGeneratorRunning(genData) then
                    return 2
                end
            end
        end
    end

    return anyGenerator and 1 or 0
end

local function ScoreBuildingCandidate(buildingData, square, isoBuilding, radius, cell, stateManager, preferredBuildingID)
    if not buildingData or not buildingData.id then return nil end

    local bx, by = square:getX(), square:getY()
    local dx = buildingData.x ~= nil and (buildingData.x - bx) or nil
    local dy = buildingData.y ~= nil and (buildingData.y - by) or nil
    local d2 = (dx and dy) and (dx * dx + dy * dy) or nil
    local radiusSq = radius * radius
    local inside = IsInsideBoundingBox(buildingData, bx, by)
    local isoMatch = BuildingMatchesIso(buildingData, isoBuilding, cell, square:getZ())
    local withinRadius = d2 and d2 <= radiusSq or false

    if not inside and not isoMatch and not withinRadius then
        return nil
    end

    local generatorScore = GetBuildingGeneratorScore(buildingData, square, stateManager)
    if generatorScore == 0 then
        return nil
    end

    local score = 0
    if inside then score = score + 200 end
    if isoMatch then score = score + 120 end
    if withinRadius and d2 then
        score = score + math.floor((radiusSq - d2) / math.max(radius, 1))
    end
    score = score + (generatorScore == 2 and 80 or 30)
    if buildingData.isPowered then score = score + 40 end
    if preferredBuildingID and buildingData.id == preferredBuildingID then
        score = score + 5
    end

    return score
end

local function FindNearestBuilding(square, radius, preferredBuildingID)
    radius = radius or 20

    local stateManager = PoweredBuildings.Core and PoweredBuildings.Core.StateManager
    if not stateManager or not stateManager.GetAllBuildings then return nil end

    local buildings = stateManager.GetAllBuildings()
    if not TableHasEntries(buildings) then return nil end

    local cell = getCell()
    if not cell or not square then return nil end

    local isoBuilding = FindNearbyIsoBuilding(cell, square, radius)
    local bestBuilding, bestScore = nil, nil

    for _, buildingData in pairs(buildings) do
        local score = ScoreBuildingCandidate(
            buildingData, square, isoBuilding, radius, cell, stateManager, preferredBuildingID)
        if score and (not bestScore or score > bestScore) then
            bestScore = score
            bestBuilding = buildingData
        end
    end

    return bestBuilding
end

local function FindNearbyGeneratorPoolID(square, radius)
    if not square then return nil end

    radius = radius or 20
    local cell = getCell()
    if not cell then return nil end

    local bestPoolID = nil
    local bestScore = nil
    local bx, by, bz = square:getX(), square:getY(), square:getZ()

    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = cell:getGridSquare(bx + dx, by + dy, bz)
            if sq then
                local objs = sq:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj and instanceof(obj, "IsoGenerator") then
                            local md = obj:getModData()
                            local poolID = md and md.Gen_BuildingPoolID or nil
                            if poolID then
                                local dist = math.abs(dx) + math.abs(dy)
                                local score = dist
                                if obj:isActivated() then
                                    score = score - 100
                                end
                                if bestScore == nil or score < bestScore then
                                    bestScore = score
                                    bestPoolID = poolID
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestPoolID
end

local function FindBarrel(worldobjects)
    if not worldobjects then return nil end
    local Barrels = PoweredBuildings.Fuel and PoweredBuildings.Fuel.Barrels
    if not Barrels then return nil end
    -- worldobjects is a plain Lua table in B42 (not a Java ArrayList)
    for _, obj in ipairs(worldobjects) do
        if obj and Barrels.IsLinkable(obj) then return obj end
    end
    return nil
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
    local Barrels = PoweredBuildings.Fuel and PoweredBuildings.Fuel.Barrels
    if not Barrels then return end
    local Runtime = PoweredBuildings.Core and PoweredBuildings.Core.Runtime
    local isMPClient = Runtime and Runtime.IsMultiplayerClient and Runtime.IsMultiplayerClient()

    local barrel = FindBarrel(worldobjects)
    if not barrel then return end

    if test then return true end  -- signal: we'd add an option

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local sq        = barrel:getSquare()
    if not sq then return end
    local stateManager = PoweredBuildings.Core and PoweredBuildings.Core.StateManager
    local linkedBuildingID = Barrels.GetLinkedBuilding and Barrels.GetLinkedBuilding(barrel) or nil
    local buildingData = linkedBuildingID and stateManager and stateManager.GetBuilding
        and stateManager.GetBuilding(linkedBuildingID) or nil
    local generatorPoolID = nil
    if not buildingData then
        buildingData = FindNearestBuilding(sq, 20, linkedBuildingID)
    end
    if not buildingData then
        generatorPoolID = FindNearbyGeneratorPoolID(sq, 20)
        if generatorPoolID and stateManager and stateManager.GetBuilding then
            buildingData = stateManager.GetBuilding(generatorPoolID)
        end
    end
    local linked = linkedBuildingID ~= nil
    local allowServerResolvedLink = isMPClient and not linked
    local resolvedBuildingID = (buildingData and buildingData.id) or generatorPoolID or nil
    local canLink = resolvedBuildingID ~= nil or allowServerResolvedLink

    if linked then
        -- Unlink option
        local opt = context:addOption(
            getText("IGUI_PB_UnlinkBarrel") or "Desvincular do Reservatório de Combustível",
            worldobjects,
            function()
                ISTimedActionQueue.add(
                    PB_LinkBarrelAction:new(player, barrel, sq, linkedBuildingID, false))
            end
        )
        _ = opt  -- used
    else
        -- Link option
        local opt = context:addOption(
            getText("IGUI_PB_LinkBarrel") or "Vincular ao Reservatório de Combustível",
            worldobjects,
            function()
                if not canLink then
                    player:Say(getText("IGUI_PB_BarrelNoBuildingNearby") or "Nenhum edifício energizado por perto")
                    return
                end
                ISTimedActionQueue.add(
                    PB_LinkBarrelAction:new(player, barrel, sq, resolvedBuildingID, true))
            end
        )
        if not canLink then
            opt.notAvailable = true
            local tip = ISToolTip:new()
            tip:initialise()
            tip:setVisible(false)
            tip:setName(getText("IGUI_PB_BarrelNoBuildingNearby") or "Nenhum edifício energizado por perto")
            opt.toolTip = tip
        end
    end
end)
