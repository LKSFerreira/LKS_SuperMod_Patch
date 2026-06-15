-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Fuel_Barrels.lua
-- LKS_EletricidadeConstrucao V2 - Fuel Barrel System (Server/Shared)
-- Links petrol barrels to building generator pools for auto-refuelling.
-- Barrels drain first, keeping generator tanks as backup reserves.
--
-- ModData key: "LKS_EletricidadeConstrucao_FuelBarrels"
--   .linkedBarrels[buildingID][barrelKey] = true
-- Barrel ModData:
--   .LKS_EletricidadeConstrucao_LinkedBuilding = buildingID  (nil = unlinked)

if not LKS_EletricidadeConstrucao then return end

LKS_EletricidadeConstrucao.Fuel = LKS_EletricidadeConstrucao.Fuel or {}
LKS_EletricidadeConstrucao.Fuel.Barrels = LKS_EletricidadeConstrucao.Fuel.Barrels or {}

local Barrels  = LKS_EletricidadeConstrucao.Fuel.Barrels
local Logger   = LKS_EletricidadeConstrucao.Core.Logger

-- ============================================================
-- CONSTANTS
-- ============================================================

-- Sprites treated as linkable petrol containers.
local LINKABLE_SPRITES = {
    ["useful_barrels_1_2"]                   = true,
    ["crafted_01_28"]                        = true,
    ["crafted_01_32"]                        = true,
    ["useful_barrels_1_0"]                   = true,
    ["carpentry_02_120"]                     = true,
    ["carpentry_02_122"]                     = true,
    ["carpentry_02_124"]                     = true,
    ["carpentry_02_54"]                      = true,
    ["industry_01_22"]                       = true,
    ["industry_01_23"]                       = true,
    ["location_military_generic_01_14"]      = true,
    ["location_military_generic_01_6"]       = true,
}

local MODDATA_KEY = "LKS_EletricidadeConstrucao_FuelBarrels"

-- ============================================================
-- HELPERS
-- ============================================================

local function BarrelKey(barrel)
    local sq = barrel:getSquare()
    return sq:getX() .. "_" .. sq:getY() .. "_" .. sq:getZ()
end

local function GetBarrelDB()
    local md = ModData.getOrCreate(MODDATA_KEY)
    if not md.linkedBarrels then md.linkedBarrels = {} end
    return md
end

local function SaveBarrelDB(md)
    ModData.add(MODDATA_KEY, md)
end

-- ============================================================
-- PETROL API
-- ============================================================

--- Check if a world object is a linkable petrol barrel.
function Barrels.IsLinkable(obj)
    if not obj then return false end
    local sp = obj:getSprite()
    if not sp then return false end
    local name = sp:getName()
    if not name then return false end
    if LINKABLE_SPRITES[name] then return true end
    -- Also accept any object that has a fluid container with petrol
    if obj.getFluidContainer then
        local ok, fc = pcall(function() return obj:getFluidContainer() end)
        if ok and fc then
            local ok2, hasPetrol = pcall(function() return fc:contains(Fluid.Petrol) end)
            if ok2 and hasPetrol then return true end
        end
    end
    return false
end

--- Get the petrol amount in a barrel (0 if empty / wrong fluid / unavailable).
function Barrels.GetPetrolAmount(barrel)
    if not barrel then return 0 end
    if not barrel.getFluidAmount then return 0 end

    -- Primary: check via FluidContainer (language-independent)
    if barrel.getFluidContainer then
        local ok, fc = pcall(function() return barrel:getFluidContainer() end)
        if ok and fc and fc.contains then
            local ok2, hasPetrol = pcall(function() return fc:contains(Fluid.Petrol) end)
            if ok2 and hasPetrol then
                local amt = barrel:getFluidAmount()
                return amt > 0 and amt or 0
            end
            return 0        -- different fluid
        end
    end

    -- Fallback: check via UI name
    if barrel.getFluidUiName then
        local fluidName = barrel:getFluidUiName()
        local petrolName = getText("Fluid_Name_Petrol")
        if string.lower(fluidName or "") == string.lower(petrolName or "") then
            local amt = barrel:getFluidAmount()
            return amt > 0 and amt or 0
        end
    end

    return 0
end

--- Remove up to `amount` petrol from a barrel.
--- Returns the amount actually removed (may be less if barrel was low).
function Barrels.RemoveFuel(barrel, amount)
    if not barrel or amount <= 0 then return 0 end
    if not barrel.getFluidAmount then return 0 end

    local sq = barrel:getSquare()
    if not sq or not sq:getChunk() then return 0 end

    -- Must contain petrol
    if barrel.getFluidContainer then
        local ok, fc = pcall(function() return barrel:getFluidContainer() end)
        if not ok or not fc then return 0 end
        local ok2, hasPetrol = pcall(function() return fc:contains(Fluid.Petrol) end)
        if not ok2 or not hasPetrol then return 0 end
    end

    local current = barrel:getFluidAmount()
    if current <= 0 then return 0 end

    local remove = math.min(amount, current)
    local keep   = current - remove

    barrel:emptyFluid()
    if keep > 0 then
        if not sq:getChunk() then return remove end
        barrel:addFluid(FluidType.Petrol, keep)
    end
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        barrel:transmitModData()
    end
    return remove
end

-- ============================================================
-- LINK / UNLINK
-- ============================================================

--- Link a barrel to a building's fuel pool.
--- Returns true on success, false + error message on failure.
function Barrels.Link(barrel, buildingID)
    if not barrel or not buildingID then
        return false, "nil argument"
    end
    if not Barrels.IsLinkable(barrel) then
        return false, "not a linkable barrel"
    end

    local key = BarrelKey(barrel)
    local bmd = barrel:getModData()
    local previousBuildingID = bmd.LKS_EletricidadeConstrucao_LinkedBuilding

    local db = GetBarrelDB()
    if previousBuildingID and previousBuildingID ~= buildingID and db.linkedBarrels[previousBuildingID] then
        db.linkedBarrels[previousBuildingID][key] = nil
        local _anyLeft = false
        for _ in pairs(db.linkedBarrels[previousBuildingID]) do _anyLeft = true; break end
        if not _anyLeft then db.linkedBarrels[previousBuildingID] = nil end
    end

    -- Barrel ModData (per-object)
    bmd.LKS_EletricidadeConstrucao_LinkedBuilding = buildingID
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        barrel:transmitModData()
    end

    -- Global ModData (per-game)
    if not db.linkedBarrels[buildingID] then
        db.linkedBarrels[buildingID] = {}
    end
    db.linkedBarrels[buildingID][key] = true
    SaveBarrelDB(db)

    Logger.Info(string.format("Linked barrel %s to building %s", key, buildingID), "Fuel.Barrels")
    return true
end

--- Unlink a barrel from its building.
function Barrels.Unlink(barrel, buildingID)
    if not barrel then return end

    local key = BarrelKey(barrel)
    local bid = buildingID or barrel:getModData().LKS_EletricidadeConstrucao_LinkedBuilding

    -- Clear barrel ModData
    local bmd = barrel:getModData()
    bmd.LKS_EletricidadeConstrucao_LinkedBuilding = nil
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        barrel:transmitModData()
    end

    if not bid then return end

    -- Remove from global DB
    local db = GetBarrelDB()
    if db.linkedBarrels[bid] then
        db.linkedBarrels[bid][key] = nil
        -- Clean empty entry (next() not available in Kahlua)
        local _anyLeft = false
        for _ in pairs(db.linkedBarrels[bid]) do _anyLeft = true; break end
        if not _anyLeft then db.linkedBarrels[bid] = nil end
    end
    SaveBarrelDB(db)

    Logger.Info(string.format("Unlinked barrel %s from building %s", key, bid), "Fuel.Barrels")
end

--- Check if a barrel is currently linked to a specific building.
function Barrels.IsLinked(barrel, buildingID)
    if not barrel or not buildingID then return false end
    local bmd = barrel:getModData()
    return bmd.LKS_EletricidadeConstrucao_LinkedBuilding == buildingID
end

--- Return the buildingID this barrel is linked to (or nil).
function Barrels.GetLinkedBuilding(barrel)
    if not barrel then return nil end
    return barrel:getModData().LKS_EletricidadeConstrucao_LinkedBuilding
end

-- ============================================================
-- QUERY LINKED BARRELS
-- ============================================================

--- Find all live barrel objects linked to a building.
--- Silently discards stale entries whose chunk is no longer loaded.
function Barrels.GetLinkedBarrels(buildingID)
    if not buildingID then return {} end
    local db = GetBarrelDB()
    if not db.linkedBarrels or not db.linkedBarrels[buildingID] then return {} end

    local cell    = getCell()
    if not cell then return {} end

    local result  = {}
    local stale   = {}

    for key, _ in pairs(db.linkedBarrels[buildingID]) do
        local px, py, pz = string.match(key, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            local sq = cell:getGridSquare(tonumber(px), tonumber(py), tonumber(pz))
            if sq and sq:getChunk() then
                local objs = sq:getObjects()
                local found = false
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if obj and Barrels.IsLinkable(obj) then
                        local linkedBuildingID = obj:getModData().LKS_EletricidadeConstrucao_LinkedBuilding
                        if linkedBuildingID == buildingID then
                            table.insert(result, obj)
                            found = true
                            break
                        end
                    end
                end
                if not found then
                    table.insert(stale, key)
                end
            end
            -- chunk not loaded: skip silently (not stale, just unloaded)
        end
    end

    -- Prune keys where the barrel was actually removed from the world
    if #stale > 0 then
        for _, k in ipairs(stale) do
            db.linkedBarrels[buildingID][k] = nil
        end
        local _anyRemain = false
        for _ in pairs(db.linkedBarrels[buildingID]) do _anyRemain = true; break end
        if not _anyRemain then
            db.linkedBarrels[buildingID] = nil
        end
        SaveBarrelDB(db)
    end

    return result
end

-- ============================================================
-- AUTO-REFUEL
-- ============================================================

--- Top up all generators for a building from linked barrels.
--- Draws petrol from barrels and distributes it proportionally.
function Barrels.AutoRefuel(buildingData)
    if not buildingData then return end
    if not buildingData.connectedGenerators
       or LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(buildingData.connectedGenerators) then return end

    local barrels = Barrels.GetLinkedBarrels(buildingData.id)
    if #barrels == 0 then return end

    local Power = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager
    if not Power then return end

    -- Collect generators that need fuel
    local generators = {}
    local fuelNeeded = 0

    -- connectedGenerators is Kahlua-deserialized (string numeric keys); use pairs
    for _, genKey in pairs(buildingData.connectedGenerators) do
        local px, py, pz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            local gen = Power.GetGeneratorAt(tonumber(px), tonumber(py), tonumber(pz))
            if gen then
                local maxFuel  = gen:getMaxFuel()
                local curFuel  = gen:getFuel()
                local needed   = maxFuel - curFuel
                if needed > 0.01 then
                    table.insert(generators, {gen=gen, needed=needed})
                    fuelNeeded = fuelNeeded + needed
                end
            end
        end
    end

    if fuelNeeded <= 0 or #generators == 0 then return end

    -- Draw from barrels (stop once we have what we need)
    local fuelDrawn = 0
    for _, barrel in ipairs(barrels) do
        if fuelDrawn >= fuelNeeded then break end
        local draw   = math.min(Barrels.GetPetrolAmount(barrel), fuelNeeded - fuelDrawn)
        local actual = Barrels.RemoveFuel(barrel, draw)
        fuelDrawn = fuelDrawn + actual
    end

    if fuelDrawn <= 0 then return end

    -- Distribute proportionally
    for _, entry in ipairs(generators) do
        local share = fuelDrawn * (entry.needed / fuelNeeded)
        local cur   = entry.gen:getFuel()
        entry.gen:setFuel(cur + share)
        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
            entry.gen:transmitModData()
        end
    end

    Logger.Info("Fuel.Barrels", string.format(
        "AutoRefuel building %s: drew %.1f L from %d barrels for %d generators",
        tostring(buildingData.id), fuelDrawn, #barrels, #generators))
end

--- Run AutoRefuel for all buildings. Called every 10 minutes.
function Barrels.UpdateAll()
    local SM = LKS_EletricidadeConstrucao.Core.StateManager
    if not SM then return end
    local buildings = SM.GetAllBuildings()
    if not buildings then return end
    -- GetAllBuildings() returns a hash-map (pairs, not ipairs)
    for _, bd in pairs(buildings) do
        if bd.connectedGenerators and not LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(bd.connectedGenerators) then
            Barrels.AutoRefuel(bd)
        end
    end
end

LKS_EletricidadeConstrucao.RegisterModule("Fuel.Barrels", "2.0.0")
return Barrels
