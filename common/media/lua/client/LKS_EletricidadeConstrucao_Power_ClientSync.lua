-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Power_ClientSync.lua
-- Multiplayer client-side reconstruction of fake generator power for loaded squares.

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Power_ClientSync] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_Power_ClientSync")

local POWER_SYNC_KEY = "LKS_EletricidadeConstrucao_BuildingPowerSync"

local function IsClientContext()
    return LKS_EletricidadeConstrucao.IsClient and LKS_EletricidadeConstrucao.IsClient()
end

local function GetSquareAt(x, y, z)
    if getSquare then
        return getSquare(x, y, z)
    end

    local cell = getCell and getCell()
    return cell and cell:getGridSquare(x, y, z) or nil
end

local function GetLocalPacket()
    local packet = ModData.get(POWER_SYNC_KEY)
    if packet then
        return packet
    end
    return ModData.getOrCreate(POWER_SYNC_KEY)
end

local function GetBuildingStates()
    local packet = GetLocalPacket()
    packet.buildings = packet.buildings or {}
    return packet, packet.buildings
end

local function ShouldAffectSquare(square, state)
    if not square or not state or not state.boundingBox then
        return false
    end

    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    local bb = state.boundingBox
    if x < bb.minX or x > bb.maxX or y < bb.minY or y > bb.maxY then
        return false
    end

    local baseZ = state.z or 0
    local minZ = math.max(0, baseZ - 3)
    local maxZ = baseZ + 10
    if z < minZ or z > maxZ then
        return false
    end

    local anchorSquare = GetSquareAt(state.x, state.y, state.z or 0)
    local anchorBuilding = anchorSquare and anchorSquare:getBuilding() or nil
    local squareBuilding = square:getBuilding()
    return not anchorBuilding or squareBuilding == nil or squareBuilding == anchorBuilding
end

local function ApplyLocalSquarePower(square, shouldPower)
    local chunk = square and square:getChunk()
    if not chunk then
        return nil
    end

    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    if shouldPower then
        chunk:addGeneratorPos(x, y, z)
    else
        chunk:removeGeneratorPos(x, y, z)
    end

    if square.RecalcAllWithNeighbours then
        square:RecalcAllWithNeighbours(false)
    end

    if chunk.recalcHashCodeObjects then
        chunk:recalcHashCodeObjects()
    end

    return chunk
end

local function ApplyLoadedBuildingState(state, shouldPower)
    if not state or not state.boundingBox then
        return 0, 0
    end

    local bb = state.boundingBox
    local minZ = math.max(0, (state.z or 0) - 3)
    local maxZ = (state.z or 0) + 10
    local tileCount = 0
    local touchedChunks = {}

    for x = bb.minX, bb.maxX do
        for y = bb.minY, bb.maxY do
            for z = minZ, maxZ do
                local square = GetSquareAt(x, y, z)
                if square and ShouldAffectSquare(square, state) then
                    local chunk = ApplyLocalSquarePower(square, shouldPower)
                    if chunk then
                        touchedChunks[tostring(chunk)] = chunk
                        tileCount = tileCount + 1
                    end
                end
            end
        end
    end

    local chunkCount = 0
    for _, chunk in pairs(touchedChunks) do
        chunkCount = chunkCount + 1
        if chunk.recalcHashCodeObjects then
            chunk:recalcHashCodeObjects()
        end
    end

    return tileCount, chunkCount
end

local function SyncFromPacket(newPacket)
    local localPacket, currentStates = GetBuildingStates()
    local nextStates = (newPacket and newPacket.buildings) or {}
    local removed = 0
    local applied = 0

    for buildingID, previousState in pairs(currentStates) do
        if previousState and not nextStates[buildingID] then
            ApplyLoadedBuildingState(previousState, false)
            removed = removed + 1
        end
    end

    localPacket.buildings = nextStates
    ModData.add(POWER_SYNC_KEY, localPacket)

    for _, state in pairs(nextStates) do
        ApplyLoadedBuildingState(state, true)
        applied = applied + 1
    end

    if applied > 0 or removed > 0 then
        print(string.format("[LKS_EletricidadeConstrucao_Power_ClientSync] synced %d powered building(s), removed %d", applied, removed))
    end
end

local function RequestState()
    if not IsClientContext() then
        return
    end
    if ModData and ModData.request then
        ModData.request(POWER_SYNC_KEY)
    end
end

local function OnInitGlobalModData()
    RequestState()
    local packet = ModData.get(POWER_SYNC_KEY)
    if packet and packet.buildings then
        SyncFromPacket(packet)
    end
end

local function OnReceiveGlobalModData(key, packet)
    if key ~= POWER_SYNC_KEY or not IsClientContext() then
        return
    end
    SyncFromPacket(packet)
end

local function OnLoadGridsquare(square)
    if not square or not IsClientContext() then
        return
    end

    local _, states = GetBuildingStates()
    for _, state in pairs(states) do
        if ShouldAffectSquare(square, state) then
            ApplyLocalSquarePower(square, true)
            return
        end
    end
end

if Events.OnInitGlobalModData then
    Events.OnInitGlobalModData.Add(OnInitGlobalModData)
end

if Events.OnReceiveGlobalModData then
    Events.OnReceiveGlobalModData.Add(OnReceiveGlobalModData)
end

if Events.LoadGridsquare then
    Events.LoadGridsquare.Add(OnLoadGridsquare)
elseif Events.OnLoadGridSquare then
    Events.OnLoadGridSquare.Add(OnLoadGridsquare)
elseif Events.OnLoadGridsquare then
    Events.OnLoadGridsquare.Add(OnLoadGridsquare)
end

if Events.OnGameStart then
    Events.OnGameStart.Add(function()
        RequestState()
        local packet = ModData.get(POWER_SYNC_KEY)
        if packet and packet.buildings then
            SyncFromPacket(packet)
        end
    end)
end

print("[LKS_EletricidadeConstrucao_Power_ClientSync] Loaded")

return true