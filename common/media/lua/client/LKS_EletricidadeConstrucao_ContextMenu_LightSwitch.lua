-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_ContextMenu_LightSwitch.lua
-- Right-click on any IsoLightSwitch in a powered building
-- to open the central Building Power Info window.
-- LOCATION: client/

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_ContextMenu_LightSwitch] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

print("[LKS_EletricidadeConstrucao_ContextMenu_LightSwitch] Loading Light Switch Context Menu...")

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ContextMenu_LightSwitch")

-- ============================================================
-- HELPERS
-- ============================================================

local function GetGeneratorSelectionScore(gen, expectedBuildingId, expectedX, expectedY)
    if not gen then return nil end

    local score = 0
    local md = gen.getModData and gen:getModData() or nil
    local bid = md and md.Gen_BuildingPoolID or nil

    if expectedBuildingId and bid == expectedBuildingId then
        score = score + 300
    end

    if bid and expectedX ~= nil and expectedY ~= nil then
        local bx, by = string.match(bid, "^bld_(%-?%d+)_(%-?%d+)_")
        if bx and tonumber(bx) == expectedX and tonumber(by) == expectedY then
            score = score + 200
        end
    end

    if gen:isActivated() then
        score = score + 100
    end

    if (gen:getFuel() or 0) > 0 then
        score = score + 10
    end

    return score
end

local function IsBetterGeneratorCandidate(score, orderIdx, distance, bestScore, bestOrderIdx, bestDistance)
    if bestScore == nil or score > bestScore then
        return true
    end
    if score < bestScore then
        return false
    end
    if orderIdx ~= nil and bestOrderIdx ~= nil and orderIdx ~= bestOrderIdx then
        return orderIdx < bestOrderIdx
    end
    if distance ~= nil and bestDistance ~= nil and distance ~= bestDistance then
        return distance < bestDistance
    end
    return false
end

--- Find a generator connected to the building containing this light switch.
--- CLIENT-SIDE: Scans nearby generators' ModData for Gen_BuildingPoolID.
--- Returns any generator within 20 tiles that has a building pool ID set.
--- @param x number Light switch X coordinate
--- @param y number Light switch Y coordinate  
--- @param z number Light switch Z coordinate
--- @return IsoGenerator|nil Generator object or nil if not found
local function FindGeneratorForLightSwitch(x, y, z)
    local cell = getCell()
    if not cell then return nil end

    local bestGenerator = nil
    local bestScore = nil
    local bestDistance = nil

    -- Search at the clicked z AND at z=0 (canonical floor).
    -- Buildings are registered under the ground-floor light switch (z=0).
    -- A click on a z=1 switch must still find the generator at z=0.
    local zLevels = {z}
    if z ~= 0 then zLevels[#zLevels + 1] = 0 end

    for _, searchZ in ipairs(zLevels) do
        local expectedBuildingId = LKS_EletricidadeConstrucao.Data.Building.MakeId(x, y, searchZ)
        for radius = 0, 20 do
            for dx = -radius, radius do
                for dy = -radius, radius do
                    -- Only check perimeter at this radius (interior already checked)
                    if math.abs(dx) == radius or math.abs(dy) == radius or radius == 0 then
                        local sq = cell:getGridSquare(x + dx, y + dy, searchZ)
                        if sq then
                            local objs = sq:getObjects()
                            if objs then
                                for i = 0, objs:size() - 1 do
                                    local obj = objs:get(i)
                                    if obj and instanceof(obj, "IsoGenerator") then
                                        local md = obj:getModData()
                                        local bid = md.Gen_BuildingPoolID

                                        if bid then
                                            local dist = math.abs(dx) + math.abs(dy)

                                            local score = GetGeneratorSelectionScore(obj, expectedBuildingId, x, y)
                                            if score then
                                                score = score - dist
                                                if IsBetterGeneratorCandidate(score, nil, dist, bestScore, nil, bestDistance) then
                                                    bestGenerator = obj
                                                    bestScore = score
                                                    bestDistance = dist
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestGenerator
end

--- Get the best loaded generator from a building's connected generators list.
--- Primary path: iterate buildingData.connectedGenerators (fast, set by server).
--- Fallback (B-105): when connectedGenerators is empty or all squares are
--- unloaded, reverse-scan StateManager.GetAllGenerators() for any generator
--- whose connectedBuildings references the same physical building (by ID or by
--- stored x/y coordinates when IDs are mismatched due to stale↔canonical drift).
--- @param buildingData BuildingData Building data
--- @return IsoGenerator|nil Generator object or nil
local function GetBuildingGenerator(buildingData)
    if not buildingData then return nil end
    local cell = getCell()
    if not cell then return nil end
    local bid_main = buildingData.id
    local bx, by = buildingData.x, buildingData.y
    local bestGenerator = nil
    local bestScore = nil
    local bestOrderIdx = nil

    local function considerGenerator(gen, orderIdx)
        if not (gen and instanceof(gen, "IsoGenerator")) then return end
        local score = GetGeneratorSelectionScore(gen, bid_main, bx, by)
        if not score then return end
        if IsBetterGeneratorCandidate(score, orderIdx, nil, bestScore, bestOrderIdx, nil) then
            bestGenerator = gen
            bestScore = score
            bestOrderIdx = orderIdx
        end
    end

    -- ── Primary: connectedGenerators fast path ────────────────────────────────
    -- NOTE: connectedGenerators is Kahlua-deserialized after GlobalModData reload
    -- (string numeric keys). # always returns 0; use pairs() to iterate all keys.
    if buildingData.connectedGenerators then
        for idx, genKey in pairs(buildingData.connectedGenerators) do
            local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if gx then
                local sq = cell:getGridSquare(tonumber(gx), tonumber(gy), tonumber(gz))
                if sq then
                    local objs = sq:getObjects()
                    if objs then
                        for i = 0, objs:size() - 1 do
                            local gen = objs:get(i)
                            considerGenerator(gen, tonumber(idx) or math.huge)
                        end
                    end
                end
            end
        end
    end

    -- ── Fallback (B-105): StateManager reverse-lookup ─────────────────────────
    -- Covers three failure modes:
    --   1. connectedGenerators is empty (canonical building freshly created this
    --      session, gen-keys not yet propagated via B-104 pass-2).
    --   2. connectedGenerators has stale gen-key for a generator whose square
    --      is already loaded under the correct coords but wasn't found above.
    --   3. Generator entries reference the building by a different ID (stale
    --      bld_def_… vs. canonical bld_X_Y_Z drift).
    local SM = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if SM and SM.GetAllGenerators then
        for _, gd in pairs(SM.GetAllGenerators() or {}) do
            local found = false
            for _, gbid in pairs(gd.connectedBuildings or {}) do
                if gbid == bid_main then
                    found = true; break
                end
                -- Coord-based match: handles stale ↔ canonical ID drift.
                -- 1) Canonical ID bld_X_Y_Z – decode coords from the key itself.
                if bx and by then
                    local cx, cy = string.match(gbid, "^bld_(%-?%d+)_(%-?%d+)_")
                    if cx and tonumber(cx) == bx and tonumber(cy) == by then
                        found = true; break
                    end
                    -- 2) Non-canonical (bld_def_…) – look up the building and
                    --    compare its stored x/y to our building's coordinates.
                    local refBld = SM.GetBuilding(gbid)
                    if refBld and refBld.x == bx and refBld.y == by then
                        found = true; break
                    end
                end
            end
            if found then
                local sq = cell:getGridSquare(gd.x, gd.y, gd.z)
                if sq then
                    local objs = sq:getObjects()
                    if objs then
                        for i = 0, objs:size() - 1 do
                            local gen = objs:get(i)
                            considerGenerator(gen, nil)
                        end
                    end
                end
            end
        end
    end
    -- ─────────────────────────────────────────────────────────────────────────
    return bestGenerator
end

local function IsInsideBuildingBounds(buildingData, x, y)
    local bb = buildingData and buildingData.boundingBox
    if not bb then return false end

    local minX = tonumber(bb.minX or bb[1])
    local minY = tonumber(bb.minY or bb[2])
    local maxX = tonumber(bb.maxX or bb[3])
    local maxY = tonumber(bb.maxY or bb[4])

    if not (minX and minY and maxX and maxY) then
        return false
    end

    return x >= minX and x <= maxX and y >= minY and y <= maxY
end

local function BuildingHasConsumerAtSquare(buildingData, square)
    if not (buildingData and buildingData.powerConsumers and square) then return false end

    local sx, sy, sz = square:getX(), square:getY(), square:getZ()
    for _, consumer in pairs(buildingData.powerConsumers) do
        local cx = tonumber(consumer and (consumer.squareX or consumer.x))
        local cy = tonumber(consumer and (consumer.squareY or consumer.y))
        local cz = tonumber(consumer and (consumer.squareZ or consumer.z))
        if cx == sx and cy == sy and (cz == nil or cz == sz) then
            return true
        end
    end

    return false
end

local function ResolveBuildingDataForLightSwitch(square)
    if not square then return nil end

    local SM = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not SM then return nil end

    local ax, ay, az = square:getX(), square:getY(), square:getZ()
    local directId = LKS_EletricidadeConstrucao.Data.Building.MakeId(ax, ay, az)
    local directBuilding = SM.GetBuilding and SM.GetBuilding(directId) or nil
    if directBuilding then
        return directBuilding
    end

    local cell = getCell()
    local clickedIsoBuilding = cell and square:getBuilding() or nil
    local bestBuilding = nil
    local bestScore = nil

    if SM.GetAllBuildings then
        for _, bd in pairs(SM.GetAllBuildings() or {}) do
            local score = 0

            if bd.x == ax and bd.y == ay then
                score = score + 300
                if bd.z == az then
                    score = score + 25
                end
            end

            if BuildingHasConsumerAtSquare(bd, square) then
                score = score + 250
            end

            if clickedIsoBuilding and cell and bd.x and bd.y and bd.z then
                local bdSq = cell:getGridSquare(bd.x, bd.y, bd.z)
                if bdSq and bdSq:getBuilding() == clickedIsoBuilding then
                    score = score + 200
                end
            end

            if IsInsideBuildingBounds(bd, ax, ay) then
                score = score + 100
            end

            if score > 0 and (not bestScore or score > bestScore) then
                bestScore = score
                bestBuilding = bd
            end
        end
    end

    return bestBuilding
end

--- Return the first IsoLightSwitch found in worldobjects, or nil.
local function FindLightSwitch(worldobjects)
    if not worldobjects then return nil end
    for _, obj in ipairs(worldobjects) do
        if instanceof(obj, "IsoLightSwitch") then
            return obj
        end
    end
    return nil
end

-- ============================================================
-- CONTEXT MENU HOOK
-- ============================================================

Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local lightSwitch = FindLightSwitch(worldobjects)
    if not lightSwitch then return end

    local square = lightSwitch:getSquare()
    if not square then return end

    local generator = nil
    local buildingData = ResolveBuildingDataForLightSwitch(square)
    if buildingData then
        generator = GetBuildingGenerator(buildingData)
    end

    -- FALLBACK: proximity scan for player-built buildings (no IsoBuilding).
    if not generator and not buildingData then
        generator = FindGeneratorForLightSwitch(
            square:getX(), square:getY(), square:getZ())
    end

    if not generator and not buildingData then return end

    -- test mode: signal that we would add an option
    if test then return true end

    -- --------------------------------------------------------
    -- Add "Building Power Info" option
    -- --------------------------------------------------------
    local buildingPowerInfoOption = context:addOption(
        getText("IGUI_BuildingPowerInfoMenu") or "Building Power Info",
        nil,
        function()
            -- Walk to an adjacent square only when not already there.
            -- NOTE: luautils.walkAdj returns nil (falsy) when the player is
            -- already adjacent, so we must NOT gate the open call on its
            -- return value -- we just let it queue a walk if needed.
            luautils.walkAdj(playerObj, square)

            if LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow then
                -- Open directly from the light-switch context so off-chunk and
                -- state-backed fallbacks do not depend on the timed-action path.
                LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow.Open(playerObj, generator, square, buildingData)
            elseif generator and LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.OpenInfoWindow then
                ISTimedActionQueue.add(
                    LKS_EletricidadeConstrucao.Actions.OpenInfoWindow:new(
                        playerObj,
                        generator,
                        square,
                        buildingData and buildingData.id or nil))
            else
                LKS_EletricidadeConstrucao.Warn("[LightSwitchMenu] GeneratorInfoWindow not loaded")
            end
        end
    )
    buildingPowerInfoOption.iconTexture = getTexture("media/ui/LKS_House_Electricity_On.png")
end)

print("[LKS_EletricidadeConstrucao_ContextMenu_LightSwitch] Light Switch Context Menu loaded successfully")
