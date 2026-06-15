-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Heating_Client.lua
-- LKS_EletricidadeConstrucao V2 - Heating Client (Client-side only)
-- Reads HeatingPositions from generator ModData and manages IsoHeatSource objects.

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Heating_Client] LKS_EletricidadeConstrucao namespace not found - skipping")
    return
end

-- Global accessor used by InfoWindow toggle buttons
LKS_EletricidadeConstrucao_HeatingClient = LKS_EletricidadeConstrucao_HeatingClient or {}

-- ============================================================
-- CONSTANTS AND STATE
-- ============================================================

local TEMP_OFFSET    = 7.1  -- PZ display offset: IsoHeatSource temp = target + offset
local DEFAULT_TEMP   = 22   -- default target (Celsius)
local DEFAULT_RADIUS = 20   -- default heat radius (tiles)

local _activeSources = {}   -- genKey ("x_y_z") -> list of {source=IsoHeatSource}

-- ============================================================
-- SANDBOX HELPERS
-- ============================================================

local function IsEnabled()
    local sb = SandboxVars and SandboxVars.LKS_EletricidadeConstrucao
    if sb and sb.HeatingSystemEnabled ~= nil then
        return sb.HeatingSystemEnabled
    end
    return true
end

local function GetRadius()
    local sb = SandboxVars and SandboxVars.LKS_EletricidadeConstrucao
    if sb and sb.HeatRadius then return sb.HeatRadius end
    return DEFAULT_RADIUS
end

local function AddLoadedGenerator(result, seen, generator)
    if not generator then return end
    local sq = generator:getSquare()
    if not sq then return end

    local key = sq:getX() .. "_" .. sq:getY() .. "_" .. sq:getZ()
    if seen[key] then return end

    seen[key] = true
    table.insert(result, generator)
end

local function FindLoadedGeneratorAt(x, y, z)
    local cell = getCell()
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

local function CollectActiveSourceGenerators(result, seen)
    for genKey in pairs(_activeSources) do
        local px, py, pz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            AddLoadedGenerator(result, seen, FindLoadedGeneratorAt(tonumber(px), tonumber(py), tonumber(pz)))
        end
    end
end

local function CollectWindowGenerators(result, seen)
    local UI = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow
    local instances = UI and UI.instances
    if not instances then return end

    for _, win in pairs(instances) do
        AddLoadedGenerator(result, seen, win and win.generator or nil)
    end
end

local function CollectNearbyPlayerGenerators(result, seen, radius)
    local cell = getCell()
    if not cell then return end

    radius = radius or 25
    for i = 0, 3 do
        local player = getSpecificPlayer and getSpecificPlayer(i) or nil
        if player then
            local psq = player:getSquare()
            if psq then
                local px, py, pz = psq:getX(), psq:getY(), psq:getZ()
                local zLevels = { pz }
                if pz ~= 0 then zLevels[#zLevels + 1] = 0 end

                for _, searchZ in ipairs(zLevels) do
                    for dx = -radius, radius do
                        for dy = -radius, radius do
                            local sq = cell:getGridSquare(px + dx, py + dy, searchZ)
                            if sq then
                                local objs = sq:getObjects()
                                if objs then
                                    for oi = 0, objs:size() - 1 do
                                        local obj = objs:get(oi)
                                        if obj and instanceof(obj, "IsoGenerator") then
                                            AddLoadedGenerator(result, seen, obj)
                                            break
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

-- ============================================================
-- CORE: APPLY / REMOVE
-- ============================================================

--- Create IsoHeatSource objects for the given generator.
function LKS_EletricidadeConstrucao_HeatingClient.Apply(generator)
    if not generator then return false end
    if not IsEnabled() then return false end
    if isServer() and not isClient() then return false end

    local sq = generator:getSquare()
    if not sq then return false end
    local genKey = sq:getX() .. "_" .. sq:getY() .. "_" .. sq:getZ()

    local md  = generator:getModData()
    local pos = md.HeatingPositions
    if not pos or type(pos) ~= "table" then return false end
    -- NOTE: HeatingPositions is saved/loaded through IsoObject ModData which Kahlua
    -- deserializes with string numeric keys ("1","2",...). # returns 0 on such tables.
    -- Use a pairs-based emptiness check.
    local _hasPos = false
    for _ in pairs(pos) do _hasPos = true; break end
    if not _hasPos then return false end

    LKS_EletricidadeConstrucao_HeatingClient.Remove(genKey)

    local cell = getCell()
    if not cell then return false end

    local actualTemp = (md.HeatingTargetTemp or DEFAULT_TEMP) + TEMP_OFFSET
    local radius     = GetRadius()
    local sources    = {}
    local sourceCount = 0

    -- Both pos and roomData.positions may have Kahlua string numeric keys; use pairs.
    for _, roomData in pairs(pos) do
        if roomData.positions then
            for _, p in pairs(roomData.positions) do
                local ok, hs = pcall(function()
                    local src = IsoHeatSource.new(p.x, p.y, p.z, radius, actualTemp)
                    src:setTemperature(actualTemp)
                    src:setRadius(radius)
                    cell:addHeatSource(src)
                    return src
                end)
                if ok and hs then
                    table.insert(sources, {source = hs, x = p.x, y = p.y, z = p.z})
                    sourceCount = sourceCount + 1
                end
            end
        end
    end

    _activeSources[genKey] = sources

    LKS_EletricidadeConstrucao.Print(string.format(
        "[Heating] Applied %d sources (target %dC) for generator %s",
        sourceCount, md.HeatingTargetTemp or DEFAULT_TEMP, genKey))

    return true
end

--- Remove all IsoHeatSource objects for the given generator key.
function LKS_EletricidadeConstrucao_HeatingClient.Remove(genKey)
    if not genKey then return end
    local sources = _activeSources[genKey]
    if not sources then return end

    local cell = getCell()
    if cell then
        for _, sd in ipairs(sources) do
            pcall(function() cell:removeHeatSource(sd.source) end)
        end
    end

    _activeSources[genKey] = nil
end

--- Returns true when heat sources are currently active for this genKey.
function LKS_EletricidadeConstrucao_HeatingClient.IsActive(genKey)
    return _activeSources[genKey] ~= nil and #_activeSources[genKey] > 0
end

--- Remove ALL active heat sources from every tracked generator.
--- Called by WipeAllData (debug wipe) so old heat sources don't linger
--- after a state clear + new-pool creation.
function LKS_EletricidadeConstrucao_HeatingClient.ClearAll()
    local cell = getCell()
    for key, sources in pairs(_activeSources) do
        if cell then
            for _, sd in ipairs(sources) do
                pcall(function() cell:removeHeatSource(sd.source) end)
            end
        end
        _activeSources[key] = nil
    end
    LKS_EletricidadeConstrucao.Print("[Heating] ClearAll: all active heat sources removed.")
end

-- ============================================================
-- GENERATOR SCAN
-- ============================================================

local function GetAllLoadedGenerators()
    local result = {}
    local seen   = {}
    local cell   = getCell()
    if not cell then return result end

    -- Use StateManager building data: all generator positions are already known.
    -- This avoids any chunk-map iteration API that differs between PZ versions.
    local SM = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local buildings = SM and SM.GetAllBuildings and SM.GetAllBuildings() or nil

    -- Primary: local StateManager snapshot when it exists.
    for _, bd in pairs(buildings or {}) do
        if bd.connectedGenerators then
            for _, genKey in pairs(bd.connectedGenerators) do
                local px, py, pz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                if px then
                    AddLoadedGenerator(result, seen, FindLoadedGeneratorAt(tonumber(px), tonumber(py), tonumber(pz)))
                end
            end
        end
    end

    -- MP fallback: keep already-active sources and any open generator windows alive even
    -- when the client-side StateManager has not received a reliable building snapshot yet.
    CollectActiveSourceGenerators(result, seen)
    CollectWindowGenerators(result, seen)

    -- Last resort: discover loaded generators around local players directly from the world.
    if #result == 0 then
        CollectNearbyPlayerGenerators(result, seen, 25)
    end

    return result
end

-- ============================================================
-- UPDATE LOOP
-- ============================================================

local function UpdateAll()
    if not IsEnabled() then
        for key in pairs(_activeSources) do
            LKS_EletricidadeConstrucao_HeatingClient.Remove(key)
        end
        return
    end

    local generators = GetAllLoadedGenerators()

    -- Build the set of currently-connected generator keys so we can detect
    -- disconnected generators (they still exist physically but are no longer
    -- in any building's connectedGenerators list after DisconnectBuilding runs).
    local connectedKeys = {}
    for _, gen in ipairs(generators) do
        local sq = gen:getSquare()
        if sq then
            connectedKeys[sq:getX() .. "_" .. sq:getY() .. "_" .. sq:getZ()] = true
        end
    end

    -- Cleanup: remove sources for generators that are no longer connected
    -- (disconnected, building removed from state) OR physically destroyed.
    for key in pairs(_activeSources) do
        if not connectedKeys[key] then
            LKS_EletricidadeConstrucao_HeatingClient.Remove(key)
        end
    end

    -- Process each generator
    for _, gen in ipairs(generators) do
        local sq = gen:getSquare()
        if sq then
            local key = sq:getX() .. "_" .. sq:getY() .. "_" .. sq:getZ()
            local md  = gen:getModData()

            -- Auto-enable on first valid activation
            -- NOTE: HeatingPositions from IsoObject ModData is Kahlua-deserialized
            -- after save/load → string numeric keys, # always 0. Use pairs.
            local _hasPosForAutoEnable = false
            if md.HeatingPositions and type(md.HeatingPositions) == "table" then
                for _ in pairs(md.HeatingPositions) do _hasPosForAutoEnable = true; break end
            end
            -- Explicit default: HeatingEnabled=false when unset.
            -- SyncToGenerators (server) writes false on first encounter, but guard here
            -- too so the client never silently auto-enables heating on initial pool creation
            -- or after a reload that drops the persisted false boolean.
            if md.HeatingEnabled == nil and _hasPosForAutoEnable then
                md.HeatingEnabled = false
                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                    gen:transmitModData()
                end
            end

            local _hasPos = false
            if md.HeatingPositions and type(md.HeatingPositions) == "table" then
                for _ in pairs(md.HeatingPositions) do _hasPos = true; break end
            end
            local wantHeat = gen:isActivated()
                and (md.HeatingEnabled == true)
                and _hasPos

            if wantHeat then
                if not LKS_EletricidadeConstrucao_HeatingClient.IsActive(key) then
                    LKS_EletricidadeConstrucao_HeatingClient.Apply(gen)
                end
            else
                if LKS_EletricidadeConstrucao_HeatingClient.IsActive(key) then
                    LKS_EletricidadeConstrucao_HeatingClient.Remove(key)
                end
            end
        end
    end
end

-- ============================================================
-- PERIODIC TEMPERATURE REFRESH (re-apply every 10 min)
-- ============================================================

local function RefreshTemperatures()
    local cell = getCell()
    if not cell then return end

    for key in pairs(_activeSources) do
        local px, py, pz = string.match(key, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            local sq = cell:getGridSquare(tonumber(px), tonumber(py), tonumber(pz))
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if obj and instanceof(obj, "IsoGenerator") then
                        LKS_EletricidadeConstrucao_HeatingClient.Remove(key)
                        LKS_EletricidadeConstrucao_HeatingClient.Apply(obj)
                        break
                    end
                end
            end
        end
    end
end

-- ============================================================
-- EVENTS
-- ============================================================

local _tickCount    = 0
local _refreshCount = 0

Events.OnTick.Add(function()
    _tickCount    = _tickCount    + 1
    _refreshCount = _refreshCount + 1

    if _tickCount >= 600 then
        _tickCount = 0
        UpdateAll()
    end

    if _refreshCount >= 36000 then
        _refreshCount = 0
        RefreshTemperatures()
    end
end)

LKS_EletricidadeConstrucao.RegisterModule("Heating.Client", "2.0.0")

print("[LKS_EletricidadeConstrucao_Heating_Client] Loaded")
