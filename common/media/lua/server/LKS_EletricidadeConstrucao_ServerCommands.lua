-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_ServerCommands.lua
-- LKS_EletricidadeConstrucao V2 - Server-side command handler
-- Receives commands sent via sendClientCommand(...) from clients.

if not LKS_EletricidadeConstrucao then return end

local function FindGeneratorAt(x, y, z)
    local cell = getCell and getCell()
    if not cell then return nil end

    local sq = cell:getGridSquare(x, y, z)
    if not sq then return nil end

    local objs = sq:getObjects()
    if not objs then return nil end

    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj and instanceof(obj, "IsoGenerator") then
            return obj
        end
    end

    return nil
end

local function IsPlayerNearSquare(player, square, maxDistance)
    if not player or not square then return false end
    maxDistance = maxDistance or 2

    local playerSq = player:getSquare()
    if not playerSq then return false end
    if playerSq:getZ() ~= square:getZ() then return false end

    local dx = math.abs(playerSq:getX() - square:getX())
    local dy = math.abs(playerSq:getY() - square:getY())
    return dx <= maxDistance and dy <= maxDistance
end

local function IsPlayerNearGenerator(player, generator)
    if not player or not generator then return false end

    return IsPlayerNearSquare(player, generator:getSquare(), 2)
end

local function IsPlayerNearHeatingAnchor(player, args)
    if not player or not args then return false end
    if args.anchorX == nil or args.anchorY == nil or args.anchorZ == nil then
        return false
    end

    local cell = getCell and getCell()
    if not cell then return false end

    local sq = cell:getGridSquare(args.anchorX, args.anchorY, args.anchorZ)
    if not sq then return false end

    return IsPlayerNearSquare(player, sq, 2)
end

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
    local GeneratorData = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
    if GeneratorData and GeneratorData.IsRunning then
        return GeneratorData.IsRunning(generatorData)
    end

    return generatorData and (generatorData.fuelAmount or 0) > 0 and generatorData.activated ~= false
end

local function GetGeneratorBuildingMatchStrength(generatorData, buildingData, square, stateManager, livePoolId)
    if not generatorData or not buildingData then return 0 end

    local best = 0
    local targetX, targetY = buildingData.x, buildingData.y
    local squareX = square and square:getX() or nil
    local squareY = square and square:getY() or nil

    if livePoolId and livePoolId == buildingData.id then
        best = 4
    end

    for _, connectedId in pairs(generatorData.connectedBuildings or {}) do
        if connectedId == buildingData.id then
            if best < 3 then best = 3 end
        end

        local refBld = stateManager and stateManager.GetBuilding and stateManager.GetBuilding(connectedId) or nil
        if refBld then
            if targetX and targetY and refBld.x == targetX and refBld.y == targetY then
                if best < 2 then best = 2 end
            elseif refBld.x and refBld.y and IsInsideBoundingBox(buildingData, refBld.x, refBld.y) then
                if best < 1 then best = 1 end
            elseif targetX and targetY and IsInsideBoundingBox(refBld, targetX, targetY) then
                if best < 1 then best = 1 end
            elseif squareX and squareY and IsInsideBoundingBox(buildingData, squareX, squareY)
                    and IsInsideBoundingBox(refBld, squareX, squareY) then
                if best < 1 then best = 1 end
            end
        else
            local cx, cy = string.match(connectedId, "^bld_(%-?%d+)_(%-?%d+)_")
            cx = tonumber(cx)
            cy = tonumber(cy)
            if cx and cy then
                if targetX and targetY and cx == targetX and cy == targetY then
                    if best < 2 then best = 2 end
                elseif IsInsideBoundingBox(buildingData, cx, cy) then
                    if best < 1 then best = 1 end
                end
            end
        end
    end

    return best
end

local function GeneratorReferencesBuilding(generatorData, buildingData, square, stateManager)
    return GetGeneratorBuildingMatchStrength(generatorData, buildingData, square, stateManager, nil) > 0
end

local function GetBuildingGeneratorScore(buildingData, square, stateManager)
    if not buildingData or not stateManager then return 0 end

    local bestScore = 0
    local GeneratorData = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator

    local function ConsiderGenerator(genData, livePoolId)
        local matchStrength = GetGeneratorBuildingMatchStrength(
            genData, buildingData, square, stateManager, livePoolId)
        if matchStrength <= 0 then
            return
        end

        local score = matchStrength * 100
        if IsGeneratorRunning(genData) then
            score = score + 40
        else
            score = score + 5
        end
        if livePoolId and livePoolId == buildingData.id then
            score = score + 20
        end

        if score > bestScore then
            bestScore = score
        end
    end

    if buildingData.connectedGenerators and GeneratorData and GeneratorData.MakeId and stateManager.GetGenerator then
        for _, genKey in pairs(buildingData.connectedGenerators) do
            local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if gx then
                local gxi, gyi, gzi = tonumber(gx), tonumber(gy), tonumber(gz)
                local genId = (gxi and gyi and gzi) and GeneratorData.MakeId(gxi, gyi, gzi) or nil
                local genData = genId and stateManager.GetGenerator(genId) or nil
                local genObj = (gxi and gyi and gzi) and FindGeneratorAt(gxi, gyi, gzi) or nil
                local livePoolId = genObj and genObj:getModData() and genObj:getModData().Gen_BuildingPoolID or nil
                if genData then
                    ConsiderGenerator(genData, livePoolId)
                elseif livePoolId and livePoolId == buildingData.id then
                    local score = 420
                    if genObj and genObj:isActivated() then score = score + 40 end
                    if score > bestScore then
                        bestScore = score
                    end
                end
            end
        end
    end

    if stateManager.GetAllGenerators then
        for _, genData in pairs(stateManager.GetAllGenerators() or {}) do
            local genObj = (genData.x ~= nil and genData.y ~= nil and genData.z ~= nil)
                and FindGeneratorAt(genData.x, genData.y, genData.z) or nil
            local livePoolId = genObj and genObj:getModData() and genObj:getModData().Gen_BuildingPoolID or nil
            ConsiderGenerator(genData, livePoolId)
            if bestScore >= 440 then
                return bestScore
            end
        end
    end

    return bestScore
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
    score = score + generatorScore
    if buildingData.isPowered then score = score + 40 end
    if preferredBuildingID and buildingData.id == preferredBuildingID then
        score = score + 5
    end

    return score
end

local function ResolveBarrelBuilding(square, preferredBuildingID, radius)
    radius = radius or 20

    local stateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not stateManager or not stateManager.GetAllBuildings then return nil end

    local buildings = stateManager.GetAllBuildings()
    if not TableHasEntries(buildings) then return nil end

    local cell = getCell and getCell()
    if not cell or not square then return nil end

    local isoBuilding = FindNearbyIsoBuilding(cell, square, radius)
    local bestBuilding, bestScore = nil, nil

    for _, buildingData in pairs(buildings) do
        local score = ScoreBuildingCandidate(
            buildingData, square, isoBuilding, radius, cell, stateManager, preferredBuildingID)
        if score and (
                not bestScore
                or score > bestScore
                or (score == bestScore and bestBuilding and buildingData.id and bestBuilding.id
                    and tostring(buildingData.id) < tostring(bestBuilding.id))) then
            bestScore = score
            bestBuilding = buildingData
        end
    end

    return bestBuilding
end

local function CountMapEntries(t)
    local count = 0
    if type(t) ~= "table" then return count end
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function CopyBoundingBox(source)
    if type(source) ~= "table" then return nil end

    local minX = tonumber(source.minX or source[1])
    local minY = tonumber(source.minY or source[2])
    local maxX = tonumber(source.maxX or source[3])
    local maxY = tonumber(source.maxY or source[4])
    if not (minX and minY and maxX and maxY) then
        return nil
    end

    return {
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY,
    }
end

local function TableContainsValue(t, value)
    if type(t) ~= "table" then return false end
    for _, entry in pairs(t) do
        if entry == value then return true end
    end
    return false
end

local function ResolvePoolDataForBuilding(buildingID, generator)
    local currentMD = generator and generator.getModData and generator:getModData() or nil
    if currentMD and currentMD.LKS_EletricidadeConstrucao_PoolData then
        return currentMD.LKS_EletricidadeConstrucao_PoolData
    end

    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not StateManager or not StateManager.GetAllGenerators then
        return nil
    end

    local currentX = generator and generator.getX and generator:getX() or nil
    local currentY = generator and generator.getY and generator:getY() or nil
    local currentZ = generator and generator.getZ and generator:getZ() or nil

    for _, genData in pairs(StateManager.GetAllGenerators() or {}) do
        if genData and TableContainsValue(genData.connectedBuildings, buildingID) then
            local gx = tonumber(genData.x)
            local gy = tonumber(genData.y)
            local gz = tonumber(genData.z) or 0
            if not (gx == currentX and gy == currentY and gz == currentZ) then
                local obj = FindGeneratorAt(gx, gy, gz)
                if obj then
                    local objMD = obj:getModData()
                    if objMD and objMD.LKS_EletricidadeConstrucao_PoolData then
                        return objMD.LKS_EletricidadeConstrucao_PoolData
                    end
                end
            end
        end
    end

    return nil
end

local function RestoreBuildingFromPoolData(buildingID, stateManager, poolData, anchorX, anchorY, anchorZ, reason)
    if not poolData then return nil end

    local buildingX = poolData.x
    local buildingY = poolData.y
    local buildingZ = poolData.z
    if buildingX == nil then buildingX = anchorX end
    if buildingY == nil then buildingY = anchorY end
    if buildingZ == nil then buildingZ = anchorZ or 0 end
    if buildingX == nil or buildingY == nil then return nil end

    local buildingData = {
        id = buildingID,
        x = buildingX,
        y = buildingY,
        z = buildingZ,
        generatorId = nil,
        powerConsumers = {},
        totalPowerDraw = 0,
        heatingPowerDraw = 0,
        isPowered = false,
        borderRadius = tonumber(poolData.borderRadius) or 30,
        lastScanTime = getTimestampMs(),
        boundingBox = CopyBoundingBox(poolData.boundingBox),
        isRVInterior = poolData.isRVInterior == true,
        heatingEnabled = false,
        heatingSourceCount = 0,
        heatingTargetTemp = 22,
        connectedGenerators = {},
    }
    stateManager.AddBuilding(buildingData)

    LKS_EletricidadeConstrucao.Core.Logger.Warn(
        string.format("[StateRepair] %s: restored building %s from LKS_EletricidadeConstrucao_PoolData%s",
            tostring(reason or "unknown"), tostring(buildingID),
            buildingData.boundingBox and " with bounding box" or ""),
        "ServerCommands")

    return stateManager.GetBuilding and stateManager.GetBuilding(buildingID) or buildingData
end

local function EnsureBuildingState(buildingID, generator, reason)
    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not StateManager or not buildingID then return nil end

    local existing = StateManager.GetBuilding and StateManager.GetBuilding(buildingID) or nil
    local poolData = ResolvePoolDataForBuilding(buildingID, generator)
    local restoredBoundingBox = CopyBoundingBox(poolData and poolData.boundingBox)

    if existing then
        local repaired = false
        if restoredBoundingBox and not existing.boundingBox then
            existing.boundingBox = restoredBoundingBox
            repaired = true
        end
        if poolData then
            if existing.x == nil and poolData.x ~= nil then existing.x = poolData.x; repaired = true end
            if existing.y == nil and poolData.y ~= nil then existing.y = poolData.y; repaired = true end
            if existing.z == nil and poolData.z ~= nil then existing.z = poolData.z; repaired = true end
            if (not existing.borderRadius or existing.borderRadius <= 0) and poolData.borderRadius ~= nil then
                existing.borderRadius = tonumber(poolData.borderRadius) or existing.borderRadius
                repaired = true
            end
        end
        if repaired and StateManager.MarkDirty then
            StateManager.MarkDirty()
        end
        return existing
    end

    local bx, by, bz = string.match(tostring(buildingID), "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
    bx, by, bz = tonumber(bx), tonumber(by), tonumber(bz)

    if not (bx and by) and poolData and poolData.x ~= nil and poolData.y ~= nil then
        bx = poolData.x
        by = poolData.y
        bz = poolData.z or bz or (generator and generator:getZ()) or 0
    end

    if poolData then
        existing = RestoreBuildingFromPoolData(buildingID, StateManager, poolData, bx, by, bz, reason)
    end

    local Scanner = LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner
    if bx and by and bz and Scanner and Scanner.ScanBuilding then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("[StateRepair] %s: verifying building %s from anchor (%d,%d,%d)",
                tostring(reason or "unknown"), tostring(buildingID), bx, by, bz),
            "ServerCommands")
        local ok, scanned = pcall(Scanner.ScanBuilding, bx, by, bz, buildingID)
        if ok and scanned then
            existing = scanned
        else
            existing = StateManager.GetBuilding and StateManager.GetBuilding(buildingID) or existing
        end
        if existing then
            return existing
        end
    end

    if bx and by and bz and LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Building then
        local placeholder = {
            id = buildingID,
            x = bx,
            y = by,
            z = bz,
            generatorId = nil,
            powerConsumers = {},
            totalPowerDraw = 0,
            heatingPowerDraw = 0,
            isPowered = false,
            borderRadius = 30,
            lastScanTime = getTimestampMs(),
            boundingBox = nil,
            isRVInterior = false,
            heatingEnabled = false,
            heatingSourceCount = 0,
            heatingTargetTemp = 22,
            connectedGenerators = {},
        }
        StateManager.AddBuilding(placeholder)
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("[StateRepair] %s: created placeholder building state for %s",
                tostring(reason or "unknown"), tostring(buildingID)),
            "ServerCommands")
        existing = StateManager.GetBuilding and StateManager.GetBuilding(buildingID) or placeholder
    end

    if existing and generator and generator.getSquare then
        local sq = generator:getSquare()
        if sq then
            local genKey = string.format("%d_%d_%d", sq:getX(), sq:getY(), sq:getZ())
            existing.connectedGenerators = existing.connectedGenerators or {}
            local hasGen = false
            for _, gk in pairs(existing.connectedGenerators) do
                if gk == genKey then hasGen = true; break end
            end
            if not hasGen then
                table.insert(existing.connectedGenerators, genKey)
                if StateManager.MarkDirty then
                    StateManager.MarkDirty()
                end
            end
        end
    end

    return existing
end

local function WarnInvalidRequest(command, reason)
    LKS_EletricidadeConstrucao.Core.Logger.Warn(
        string.format("%s rejected: %s", tostring(command), tostring(reason)),
        "ServerCommands")
end

local function SendActionResult(player, kind, success, args)
    if not player or not sendServerCommand then return end

    local payload = args or {}
    payload.kind = kind
    payload.success = success == true

    sendServerCommand(player, "LKS_EletricidadeConstrucao", "ActionResult", payload)
end

local function RejectRequest(player, command, reason, args)
    WarnInvalidRequest(command, reason)
    args = args or {}
    args.message = args.message or tostring(reason)
    SendActionResult(player, command, false, args)
end

local function OnClientCommand(module, command, player, args)
    if module ~= "LKS_EletricidadeConstrucao" then return end

    if command == "ActivateGenerator" then
        if not args or args.genX == nil or args.genY == nil or args.genZ == nil then
            RejectRequest(player, command, "missing generator coordinates", {
                message = "Invalid generator request",
            })
            return
        end

        local generator = FindGeneratorAt(args.genX, args.genY, args.genZ)
        if not generator then
            RejectRequest(player, command, "generator not found", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Generator not available",
            })
            return
        end
        if not IsPlayerNearGenerator(player, generator) then
            RejectRequest(player, command, "player not near generator", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Move closer to the generator",
            })
            return
        end

        local actionClass = LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.ActivateGenerator
        if not actionClass or not actionClass.Execute or not actionClass.new then
            RejectRequest(player, command, "activate action not loaded", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Generator action is unavailable",
            })
            return
        end

        local activate = args.activate == true
        local action = actionClass:new(player, generator, activate)
        if action.isValid and not action:isValid() then
            RejectRequest(player, command, "generator action is not valid", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = activate and "Generator cannot be turned on" or "Generator cannot be turned off",
            })
            return
        end

        local ok, err = pcall(function()
            actionClass.Execute(generator, activate)
        end)
        if not ok then
            RejectRequest(player, command, err, {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Generator action failed",
            })
            return
        end

        local success = generator:isActivated() == activate
        SendActionResult(player, command, success, {
            genX = args.genX,
            genY = args.genY,
            genZ = args.genZ,
            activate = activate,
            message = success and nil or "Generator state did not change",
        })
    elseif command == "ConnectBuilding" then
        if not args or args.genX == nil or args.genY == nil or args.genZ == nil then
            RejectRequest(player, command, "missing generator coordinates", {
                message = "Invalid generator request",
            })
            return
        end

        local generator = FindGeneratorAt(args.genX, args.genY, args.genZ)
        if not generator then
            RejectRequest(player, command, "generator not found", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Generator not available",
            })
            return
        end
        if not IsPlayerNearGenerator(player, generator) then
            RejectRequest(player, command, "player not near generator", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Move closer to the generator",
            })
            return
        end

        local actionClass = LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.ConnectBuilding
        if not actionClass or not actionClass.new then
            RejectRequest(player, command, "connect action not loaded", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Connect action is unavailable",
            })
            return
        end

        local action = actionClass:new(player, generator)
        if action.isValid and not action:isValid() then
            RejectRequest(player, command, "connect action is not valid", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Generator is already connected",
            })
            return
        end

        local ok, err = pcall(function()
            action:complete()
        end)
        if not ok then
            RejectRequest(player, command, err, {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Could not connect generator",
            })
            return
        end

        local buildingID = generator:getModData().Gen_BuildingPoolID
        local repairedBuilding = buildingID and EnsureBuildingState(buildingID, generator, "ConnectBuilding") or nil
        local genSquare = generator:getSquare()
        if genSquare and buildingID then
            local genKey = string.format("%d_%d_%d", genSquare:getX(), genSquare:getY(), genSquare:getZ())
            local genId = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
                and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                and LKS_EletricidadeConstrucao.Data.Generator.MakeId(genSquare:getX(), genSquare:getY(), genSquare:getZ())
            local genData = genId and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                and LKS_EletricidadeConstrucao.Core.StateManager.GetGenerator and LKS_EletricidadeConstrucao.Core.StateManager.GetGenerator(genId) or nil
            local bldGenCount = CountMapEntries(repairedBuilding and repairedBuilding.connectedGenerators)
            local genBldCount = CountMapEntries(genData and genData.connectedBuildings)
            LKS_EletricidadeConstrucao.Core.Logger.Warn(
                string.format("[ConnectDebug] gen=%s pool=%s stateBuilding=%s building.connectedGenerators=%d gen.connectedBuildings=%d",
                    tostring(genId or genKey), tostring(buildingID), tostring(repairedBuilding ~= nil), bldGenCount, genBldCount),
                "ServerCommands")
        end
        SendActionResult(player, command, buildingID ~= nil, {
            genX = args.genX,
            genY = args.genY,
            genZ = args.genZ,
            buildingID = buildingID,
            message = buildingID and nil or "Could not connect generator to a building",
            messageKey = buildingID and "IGUI_ConnectedToBuilding" or nil,
        })
    elseif command == "DisconnectBuilding" then
        if not args or args.genX == nil or args.genY == nil or args.genZ == nil then
            RejectRequest(player, command, "missing generator coordinates", {
                message = "Invalid generator request",
            })
            return
        end

        local generator = FindGeneratorAt(args.genX, args.genY, args.genZ)
        if not generator then
            RejectRequest(player, command, "generator not found", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Generator not available",
            })
            return
        end
        if not IsPlayerNearGenerator(player, generator) then
            RejectRequest(player, command, "player not near generator", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Move closer to the generator",
            })
            return
        end

        local actionClass = LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.DisconnectBuilding
        if not actionClass or not actionClass.new then
            RejectRequest(player, command, "disconnect action not loaded", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Disconnect action is unavailable",
            })
            return
        end

        local action = actionClass:new(player, generator)
        if action.isValid and not action:isValid() then
            RejectRequest(player, command, "disconnect action is not valid", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Generator is not connected to a building",
            })
            return
        end

        local ok, err = pcall(function()
            action:complete()
        end)
        if not ok then
            RejectRequest(player, command, err, {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Could not disconnect generator",
            })
            return
        end

        local buildingID = generator:getModData().Gen_BuildingPoolID
        SendActionResult(player, command, buildingID == nil, {
            genX = args.genX,
            genY = args.genY,
            genZ = args.genZ,
            message = (buildingID == nil) and nil or "Generator is still connected",
            messageKey = (buildingID == nil) and "IGUI_DisconnectedFromBuilding" or nil,
        })
    elseif command == "BarrelLink" then
        print(string.format("[LKS_EletricidadeConstrucao_BarrelLink] request bx=%s by=%s bz=%s buildingID=%s linking=%s",
            tostring(args and args.bx), tostring(args and args.by), tostring(args and args.bz),
            tostring(args and args.buildingID), tostring(args and args.linking == true)))
        if not args or not args.bx then
            RejectRequest(player, command, "missing barrel coordinates", {
                message = "Invalid barrel request",
            })
            return
        end
        local Barrels = LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels
        if not Barrels then
            RejectRequest(player, command, "barrel system not loaded", {
                message = "Fuel barrel system is unavailable",
            })
            return
        end

        local sq = getCell():getGridSquare(args.bx, args.by, args.bz)
        if not sq then
            RejectRequest(player, command, "barrel square not found", {
                bx = args.bx,
                by = args.by,
                bz = args.bz,
                message = "Barrel is not loaded",
            })
            return
        end
        if not IsPlayerNearSquare(player, sq, 2) then
            RejectRequest(player, command, "player not near barrel", {
                bx = args.bx,
                by = args.by,
                bz = args.bz,
                message = "Move closer to the barrel",
            })
            return
        end

        -- Find barrel on square
        local barrel = nil
        local objs   = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if obj and Barrels.IsLinkable(obj) then
                barrel = obj
                break
            end
        end

        if not barrel then
            RejectRequest(player, command, "no linkable barrel on square", {
                bx = args.bx,
                by = args.by,
                bz = args.bz,
                message = "No linkable barrel found",
            })
            return
        end

        local resolvedBuildingID = nil
        if args.linking then
            local buildingData = ResolveBarrelBuilding(sq, nil, 20)
            if not buildingData then
                local repaired = nil
                local cell = getCell and getCell()
                if cell then
                    for dx = -20, 20 do
                        for dy = -20, 20 do
                            local gsq = cell:getGridSquare(args.bx + dx, args.by + dy, args.bz)
                            if gsq then
                                local objs = gsq:getObjects()
                                if objs then
                                    for i = 0, objs:size() - 1 do
                                        local obj = objs:get(i)
                                        if obj and instanceof(obj, "IsoGenerator") then
                                            local poolId = obj:getModData() and obj:getModData().Gen_BuildingPoolID or nil
                                            if poolId then
                                                repaired = EnsureBuildingState(poolId, obj, "BarrelLink")
                                                if repaired then break end
                                            end
                                        end
                                    end
                                end
                            end
                            if repaired then break end
                        end
                        if repaired then break end
                    end
                end
                if repaired then
                    buildingData = ResolveBarrelBuilding(sq, repaired.id, 20)
                end
            end
            if not buildingData then
                local stateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                local buildingCount = stateManager and stateManager.GetAllBuildings and CountMapEntries(stateManager.GetAllBuildings() or {}) or 0
                LKS_EletricidadeConstrucao.Core.Logger.Warn(
                    string.format("No building resolved for barrel (%d,%d,%d); buildingsInState=%d",
                        args.bx, args.by, args.bz, buildingCount),
                    "ServerCommands")
                RejectRequest(player, command, "building not found for barrel link", {
                    bx = args.bx,
                    by = args.by,
                    bz = args.bz,
                    message = "No valid generator pool found for this barrel",
                })
                return
            end
            resolvedBuildingID = buildingData.id
        else
            resolvedBuildingID = (Barrels.GetLinkedBuilding and Barrels.GetLinkedBuilding(barrel)) or args.buildingID
        end

        if args.linking then
            local ok, err = Barrels.Link(barrel, resolvedBuildingID)
            if not ok then
                RejectRequest(player, command, err, {
                    bx = args.bx,
                    by = args.by,
                    bz = args.bz,
                    message = "Could not link barrel",
                })
                return
            end
        else
            Barrels.Unlink(barrel, resolvedBuildingID)
        end

        local Dist = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
        if Dist and resolvedBuildingID then
            pcall(function()
                if Dist.RefreshBuildingStats then
                    Dist.RefreshBuildingStats(resolvedBuildingID)
                elseif Dist.ForceUpdateBuilding then
                    Dist.ForceUpdateBuilding(resolvedBuildingID)
                elseif Dist.ForceUpdate then
                    Dist.ForceUpdate()
                end
            end)
        end

        SendActionResult(player, command, true, {
            bx = args.bx,
            by = args.by,
            bz = args.bz,
            buildingID = resolvedBuildingID,
            linking = args.linking == true,
            messageKey = args.linking and "IGUI_LKS_EletricidadeConstrucao_BarrelLinked" or "IGUI_LKS_EletricidadeConstrucao_BarrelUnlinked",
        })
    elseif command == "ForceDist" then
        -- Force a one-shot distributor pass to refresh Gen_Stats_* and active consumers
        local Dist = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
        if not Dist or not args then return end
        if args.buildingID then
            EnsureBuildingState(args.buildingID, nil, "ForceDist")
        end
        if args.buildingID and Dist.RefreshBuildingStats then
            Dist.RefreshBuildingStats(args.buildingID)
        elseif args.buildingID and Dist.ForceUpdateBuilding then
            Dist.ForceUpdateBuilding(args.buildingID)
        elseif Dist.ForceUpdate then
            Dist.ForceUpdate()
        end
    elseif command == "HeatingToggle" then
        -- Sync HeatingEnabled to GeneratorData (GlobalModData) and BuildingData immediately
        -- when toggled in UI.  Both must be updated together so CalculateFuelConsumption
        -- (which reads buildingData.heatingEnabled) and the FuelManager fallback path
        -- (which reads genData.heatingEnabled) both reflect the change without waiting
        -- for the next EveryOneMinute Heating.SyncToGenerators pass.
        if not args or not args.genX then
            RejectRequest(player, command, "missing generator coordinates", {
                message = "Invalid heating request",
            })
            return
        end
        local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
        local GenData      = LKS_EletricidadeConstrucao.Data.Generator
        if not StateManager or not GenData then return end

        local generator = FindGeneratorAt(args.genX, args.genY, args.genZ)
        if not generator then
            RejectRequest(player, command, "generator not found", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Generator not available",
            })
            return
        end
        if not IsPlayerNearHeatingAnchor(player, args)
                and not IsPlayerNearGenerator(player, generator) then
            RejectRequest(player, command, "player not near generator", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Move closer to the building switch or generator",
            })
            return
        end

        local genId   = GenData.MakeId(args.genX, args.genY, args.genZ)
        local genData = StateManager.GetGenerator(genId)
        if not genData then
            RejectRequest(player, command, "generator not found in state", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Heating data is unavailable",
            })
            return
        end

        local enabled    = (args.enabled == true)
        local srcCount   = math.max(0, tonumber(args.sourceCount) or 0)
        local targetTemp = math.max(15, math.min(30, tonumber(args.targetTemp) or 22))

        -- 1. Update GeneratorData (used by FuelManager off-chunk fallback)
        genData.heatingEnabled    = enabled
        genData.heatingSourceCount = srcCount
        genData.heatingTargetTemp  = targetTemp

        -- 2. Update every BuildingData connected to this generator so
        --    CalculateFuelConsumption picks up the change immediately.
        --    connectedBuildings is a Kahlua-deserialized table → use pairs.
        if genData.connectedBuildings then
            for _, buildingId in pairs(genData.connectedBuildings) do
                local bd = StateManager.GetBuilding(buildingId)
                if bd then
                    bd.heatingEnabled    = enabled
                    bd.heatingSourceCount = math.max(bd.heatingSourceCount or 0, srcCount)
                    bd.heatingTargetTemp  = targetTemp
                end
            end
        end

        StateManager.MarkDirty()

        -- 3. Write HeatingEnabled + HeatingTargetTemp directly to the IsoObject.
        --    The info window reads md.HeatingEnabled directly (singleplayer: same Lua
        --    state, multiplayer: client reads its local copy from transmitModData).
        --    Without this write, the IsoObject carries the stale value from the
        --    previous session and the UI shows wrong heating state after a restart
        --    (even when GlobalModData is correct).
        local _md = generator:getModData()
        _md.HeatingEnabled    = enabled
        _md.HeatingTargetTemp = targetTemp
        if LKS_EletricidadeConstrucao.Core.Runtime and LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync
                and LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
            generator:transmitModData()
        end

        LKS_EletricidadeConstrucao.Core.Logger.Info(
            string.format("[HeatingToggle] Generator %s: enabled=%s sources=%d temp=%.1f",
                genId, tostring(enabled), srcCount, targetTemp),
            "Heating"
        )

        SendActionResult(player, command, true, {
            genX = args.genX,
            genY = args.genY,
            genZ = args.genZ,
            heatingEnabled = enabled,
            heatingTargetTemp = targetTemp,
        })
    end
end

if Events.OnClientCommand then
    Events.OnClientCommand.Add(OnClientCommand)
    print("[LKS_EletricidadeConstrucao_ServerCommands] Loaded")
else
    print("[LKS_EletricidadeConstrucao_ServerCommands] WARNING: OnClientCommand event not available")
end

return true
