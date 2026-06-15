-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Fuel_StrainCalculator.lua
-- LKS_EletricidadeConstrucao V2 - Strain Calculator
-- Calculates load-based fuel consumption modifiers
-- Version: 2.0.0-alpha
-- Date: February 22, 2026


-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Fuel_StrainCalculator] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- STRAIN CALCULATION
-- ============================================================================

-- Variant generator tuning lives in shared constants so fuel + strain stay aligned.
local GENERATOR_TYPE_MODIFIERS =
    (LKS_EletricidadeConstrucao.Constants.GENERATOR_TYPES and LKS_EletricidadeConstrucao.Constants.GENERATOR_TYPES.MODIFIERS) or {}

-- Tracks how long (in game-seconds) each generator has been in overload (>100% strain)
-- Reset when strain drops back to <= 100%
local _overloadDuration = {}  -- [generatorId] = accumulatedSeconds

-- 1 in-game hour of overload must pass before fail-chance is active
local OVERLOAD_GRACE_SECONDS = 3600  -- 1 hour (game-time)

-- Helper: get generator sprite name
local function GetGeneratorSpriteName(gen)
    if not gen then return nil end
    local sprite = gen.getSpriteName and gen:getSpriteName()
    if not sprite and gen.getSprite and gen:getSprite() then
        sprite = gen:getSprite():getName()
    end
    return sprite
end

-- Helper: diminish a bonus/malus toward 1.0 as more of the same type are present
local function ApplyDiminishing(mult, count)
    if not mult then return 1.0 end
    if mult == 1.0 or not count or count <= 1 then return mult end
    return 1.0 + ((mult - 1.0) / (2 ^ (count - 1)))
end

-- Helper: count generators with the same sprite connected across the same building pool
local function CountSameSpriteGenerators(genObj, generatorData)
    local sprite = GetGeneratorSpriteName(genObj)
    if not sprite then return 1 end

    local seen = {}
    local count = 0

    local function addIfSame(gen)
        if not gen then return end
        local key = string.format("%d,%d,%d", gen:getX(), gen:getY(), gen:getZ())
        if seen[key] then return end
        seen[key] = true
        if GetGeneratorSpriteName(gen) == sprite then
            count = count + 1
        end
    end

    addIfSame(genObj)

    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local cell = getCell()
    if cell and generatorData and generatorData.connectedBuildings and StateManager and StateManager.GetBuilding then
        -- connectedBuildings / connectedGenerators are Kahlua-deserialized (string numeric keys)
        for _, bid in pairs(generatorData.connectedBuildings) do
            local bd = StateManager.GetBuilding(bid)
            if bd and bd.connectedGenerators then
                for _, genKey in pairs(bd.connectedGenerators) do
                    local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                    if gx then
                        local sq = cell:getGridSquare(tonumber(gx), tonumber(gy), tonumber(gz))
                        if sq then
                            local objs = sq:getObjects()
                            for i = 0, objs:size() - 1 do
                                local obj = objs:get(i)
                                if obj and instanceof(obj, "IsoGenerator") then
                                    addIfSame(obj)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if count < 1 then return 1 end
    return count
end

local function CountActivePoolGeneratorsFromBuildings(poolBuildings)
    if type(poolBuildings) ~= "table" then
        return 1
    end

    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local GeneratorData = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
    if not StateManager or not StateManager.GetBuilding or not StateManager.GetGenerator
            or not GeneratorData or not GeneratorData.MakeId then
        return 1
    end

    local seenGenKeys = {}
    local activeCount = 0

    for buildingId in pairs(poolBuildings) do
        local buildingData = StateManager.GetBuilding(buildingId)
        if buildingData and buildingData.connectedGenerators then
            for _, genKey in pairs(buildingData.connectedGenerators) do
                if not seenGenKeys[genKey] then
                    seenGenKeys[genKey] = true
                    local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                    if gx then
                        local genId = GeneratorData.MakeId(tonumber(gx), tonumber(gy), tonumber(gz))
                        local genData = StateManager.GetGenerator(genId)
                        if genData and (genData.fuelAmount or 0) > 0 and genData.activated ~= false then
                            activeCount = activeCount + 1
                        end
                    end
                end
            end
        end
    end

    if activeCount < 1 then return 1 end
    return activeCount
end

local function ResolveActivePoolCount(generatorData, poolBuildingsOverride, activePoolOverride)
    if type(activePoolOverride) == "number" and activePoolOverride >= 1 then
        return math.max(1, math.floor(activePoolOverride + 0.5))
    end

    local Runtime = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    if type(poolBuildingsOverride) == "table"
            and Runtime and Runtime.IsSingleplayer and Runtime.IsSingleplayer() then
        return CountActivePoolGeneratorsFromBuildings(poolBuildingsOverride)
    end

    local activePoolGens = 1
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager
       and LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators then
        activePoolGens = LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators(generatorData)
    end

    if activePoolGens < 1 and type(poolBuildingsOverride) == "table" then
        activePoolGens = CountActivePoolGeneratorsFromBuildings(poolBuildingsOverride)
    end

    if activePoolGens < 1 then return 1 end
    return activePoolGens
end

--- Calculate strain multiplier for generator (tiered system)
--- @param generatorData GeneratorData Generator data
--- @param poolBuildingsOverride table|nil Pre-computed set of buildingIDs from FuelManager BFS.
---   When provided, CalculateStrain skips its own BFS and uses this set directly, which avoids
---   the stale-ID divergence and eliminates redundant traversal (B-102 / B-103 fix).
--- @param activePoolOverride number|nil Pre-computed active generator count for this pool.
--- @return number Strain multiplier (1.0 = normal, >1.0 = increased consumption)
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData, poolBuildingsOverride, activePoolOverride)
    if not generatorData then
        return 1.0
    end

    -- Update strain value in generator data (caching handled internally)
    LKS_EletricidadeConstrucao.Fuel.StrainCalculator.CalculateStrain(generatorData, poolBuildingsOverride, activePoolOverride)
    
    local strain = generatorData.strain
    
    -- No strain = no modifier
    if strain <= 0 then
        return 1.0
    end
    
    -- TIERED STRAIN SYSTEM:
    -- 0-50%: No extra fuel consumption (1.0x)
    -- 51-75%: Linear increase from 1.0x to 1.25x (1-25% extra)
    -- 76-100%: Linear increase from 1.26x to 1.75x (26-75% extra) + damage
    -- 101-200%: Linear increase up to 3.0x + heavy damage + fail chance
    
    local multiplier = 1.0
    
    if strain <= 50 then
        -- No penalty in safe zone
        multiplier = 1.0
        print(string.format("[STRAIN_DEBUG] Strain %.1f%% <= 50%% -> multiplier = 1.0 (no penalty)", strain))
    elseif strain <= 75 then
        -- 51-75%: Linear interpolation from 1.0 to 1.25
        local t = (strain - 50) / 25  -- 0.0 at 50%, 1.0 at 75%
        multiplier = 1.0 + (t * 0.25)
        print(string.format("[STRAIN_DEBUG] Strain %.1f%% in 51-75%% range -> t=%.3f, multiplier = %.3f", strain, t, multiplier))
    elseif strain <= 100 then
        -- 76-100%: Linear interpolation from 1.26 to 1.75
        local t = (strain - 75) / 25  -- 0.0 at 75%, 1.0 at 100%
        multiplier = 1.26 + (t * 0.49)
        print(string.format("[STRAIN_DEBUG] Strain %.1f%% in 76-100%% range -> t=%.3f, multiplier = %.3f", strain, t, multiplier))
    else
        -- 101-200%: Linear interpolation from 1.75 to 3.0
        local t = math.min((strain - 100) / 100, 1.0)  -- 0.0 at 100%, 1.0 at 200%
        multiplier = 1.75 + (t * 1.25)
        print(string.format("[STRAIN_DEBUG] Strain %.1f%% > 100%% -> t=%.3f, multiplier = %.3f", strain, t, multiplier))
    end
    
    -- Cap at maximum (default 3.0x)
    local Constants = LKS_EletricidadeConstrucao.Constants
    local maxMultiplier = Constants.FUEL.MAX_STRAIN_MULTIPLIER or 3.0
    if multiplier > maxMultiplier then
        multiplier = maxMultiplier
    end
    
    return multiplier
end

--- Calculate current strain for generator
--- @param generatorData GeneratorData Generator data
--- @param poolBuildingsOverride table|nil Pre-computed {[buildingId]=true} set from FuelManager.
---   When supplied, the internal BFS is skipped entirely so CalculateStrain uses the same
---   (lazy-Xref-repaired) pool topology that FuelManager already discovered this tick.
--- @param activePoolOverride number|nil Pre-computed active generator count for this pool.
--- @return number Strain percentage (0-100+)
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.CalculateStrain(generatorData, poolBuildingsOverride, activePoolOverride)
    if not generatorData then
        return 0
    end

    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager

    -- Collect ALL buildings reachable through the full generator pool.
    -- If FuelManager already did this BFS (and repaired stale IDs via lazy Xref), use its
    -- result directly to guarantee consistent pool topology and avoid duplicate traversal.
    local poolBuildings
    if poolBuildingsOverride then
        poolBuildings = poolBuildingsOverride  -- B-103: skip BFS, use caller's set
    else
        poolBuildings = {}  -- set of buildingIDs
        do
            local toVisit = {generatorData}
            local visited = {}
            while #toVisit > 0 do
                local cg = table.remove(toVisit)
                if cg and cg.id and not visited[cg.id] then
                    visited[cg.id] = true
                    if cg.connectedBuildings then
                        for _, bid in pairs(cg.connectedBuildings) do
                            poolBuildings[bid] = true
                            local bd = StateManager.GetBuilding(bid)
                            if bd and bd.connectedGenerators then
                                for _, gk in pairs(bd.connectedGenerators) do
                                    local gx2, gy2, gz2 = string.match(gk, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                                    if gx2 then
                                        local gid2 = LKS_EletricidadeConstrucao.Data.Generator.MakeId(tonumber(gx2), tonumber(gy2), tonumber(gz2))
                                        if not visited[gid2] then
                                            local ng = StateManager.GetGenerator(gid2)
                                            if ng then table.insert(toVisit, ng) end
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

    -- Count active generators pool-wide using chunk-independent GlobalModData
    -- Uses the same logic as fuel calculation (CountActivePoolGenerators)
    local activePoolGens = ResolveActivePoolCount(generatorData, poolBuildingsOverride, activePoolOverride)

    -- Sum total power draw across ALL pool buildings using cached powered value.
    -- When offchunk the building becomes "unpowered" and consumers go inactive,
    -- reducing totalPowerDraw. strainTotalPowerDraw preserves the last powered state.
    -- Deduplicate by physical location to avoid double-counting when the same building
    -- exists under both a canonical (bld_X_Y_Z) and a stale legacy (bld_def_...) ID.
    local totalPoolDraw = 0
    local _seenStrainLocations = {}  -- "x_y_z" -> true  (dedup guard)
    for bid, _ in pairs(poolBuildings) do
        local buildingData = StateManager.GetBuilding(bid)
        if buildingData then
            local locKey = (buildingData.x or 0) .. "_" .. (buildingData.y or 0) .. "_" .. (buildingData.z or 0)
            if not _seenStrainLocations[locKey] then
                _seenStrainLocations[locKey] = true
                local draw = buildingData.strainTotalPowerDraw
                          or buildingData.totalPowerDraw
                          or 0
                totalPoolDraw = totalPoolDraw + draw
            end
        end
    end
    local sharedPowerDraw = totalPoolDraw / activePoolGens

    if sharedPowerDraw <= 0 then
        generatorData.strain = 0
        return 0
    end

    -- Convert shared power draw to strain percentage
    local strain = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PowerDrawToStrain(sharedPowerDraw)

    -- Apply sprite-specific strain capacity (lower = can handle more before % climbs)
    -- Use cached values if chunk not loaded (chunk-independent)
    local genObj = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    local strainMult = 1.0
    
    if genObj then
        -- Chunk loaded - get and cache sprite data
        local sprite = GetGeneratorSpriteName(genObj)
        generatorData.cachedSprite = sprite
        
        local mods = GENERATOR_TYPE_MODIFIERS[sprite or ""]
        if mods and mods.strain then
            strainMult = mods.strain
        end
        generatorData.cachedStrainMult = strainMult
        
        -- Diminish bonus/malus when stacking multiple of the same sprite
        local sameCount = CountSameSpriteGenerators(genObj, generatorData)
        strainMult = ApplyDiminishing(strainMult, sameCount)
    else
        -- Chunk not loaded - use cached base value (no diminishing, we don't know count offchunk)
        strainMult = generatorData.cachedStrainMult or 1.0
    end

    strain = strain * strainMult

    -- Clamp tiny values to zero to avoid lingering 1% noise
    if strain < 0.5 then
        strain = 0
    end
    
    -- Update generator data
    generatorData.strain = strain
    
    return strain
end

--- Convert power draw to strain percentage
--- @param powerDraw number Total power draw
--- @return number Strain percentage
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PowerDrawToStrain(powerDraw)
    if powerDraw <= 0 then
        return 0
    end
    
    local Constants = LKS_EletricidadeConstrucao.Constants
    
    local fuelConstants = Constants.FUEL or {}
    local baseLoadCapacity = fuelConstants.BASE_LOAD_CAPACITY

    if type(baseLoadCapacity) ~= "number" or baseLoadCapacity <= 0 then
        local legacyBaseStrain = fuelConstants.BASE_STRAIN_PER_LIGHT or 1.0
        if type(legacyBaseStrain) == "number" and legacyBaseStrain > 0 then
            baseLoadCapacity = 100 / legacyBaseStrain
        else
            baseLoadCapacity = 100.0
        end
    end

    -- Example: 120 load at 120 capacity = 100% strain
    local strain = (powerDraw / baseLoadCapacity) * 100
    
    return strain
end

--- Get strain level category
--- @param strain number Strain percentage
--- @return string Strain level ("none", "low", "medium", "high", "critical")
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainLevel(strain)
    local Constants = LKS_EletricidadeConstrucao.Constants
    
    if strain <= 0 then
        return "none"
    elseif strain < (Constants.FUEL.STRAIN_THRESHOLD_LOW or 25) then
        return "low"
    elseif strain < (Constants.FUEL.STRAIN_THRESHOLD_MEDIUM or 50) then
        return "medium"
    elseif strain < (Constants.FUEL.STRAIN_THRESHOLD_HIGH or 75) then
        return "high"
    else
        return "critical"
    end
end

--- Check if generator is overloaded
--- @param generatorData GeneratorData Generator data
--- @return boolean True if overloaded
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.IsOverloaded(generatorData)
    if not generatorData then
        return false
    end
    
    local Constants = LKS_EletricidadeConstrucao.Constants
    local overloadThreshold = Constants.FUEL.OVERLOAD_THRESHOLD or 100
    
    return generatorData.strain >= overloadThreshold
end

-- ============================================================================
-- STRAIN EFFECTS
-- ============================================================================

--- Get efficiency percentage based on strain
--- @param strain number Strain percentage
--- @return number Efficiency percentage (100 = normal, <100 = reduced efficiency)
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetEfficiency(strain)
    if strain <= 0 then
        return 100
    end
    
    local Constants = LKS_EletricidadeConstrucao.Constants
    
    -- Efficiency decreases with strain
    -- Example: 50% strain = 75% efficiency
    local efficiencyLoss = strain * (Constants.FUEL.EFFICIENCY_LOSS_RATE or 0.5)
    local efficiency = 100 - efficiencyLoss
    
    -- Minimum efficiency
    local minEfficiency = Constants.FUEL.MIN_EFFICIENCY or 25
    if efficiency < minEfficiency then
        efficiency = minEfficiency
    end
    
    return efficiency
end

--- Check if generator should fail due to overload
--- @param generatorData GeneratorData Generator data
--- @return boolean True if should fail
--- @return string|nil Failure reason
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ShouldFailFromOverload(generatorData)
    if not generatorData then
        return false, nil
    end
    
    local Config = LKS_EletricidadeConstrucao.Config
    
    -- Check if overload failure is enabled
    if not Config.OverloadFailureEnabled then
        return false, nil
    end
    
    -- Check if critically overloaded
    if not LKS_EletricidadeConstrucao.Fuel.StrainCalculator.IsOverloaded(generatorData) then
        return false, nil
    end
    
    local Constants = LKS_EletricidadeConstrucao.Constants
    
    -- Random chance of failure based on strain level
    local failureChance = (generatorData.strain - 100) * (Constants.FUEL.OVERLOAD_FAILURE_RATE or 0.01)
    
    if failureChance > 0 then
        local roll = ZombRand(10000) / 100  -- 0-100 with 2 decimal precision
        
        if roll < failureChance then
            return true, "Overload failure"
        end
    end
    
    return false, nil
end

-- ============================================================================
-- BUILDING ANALYSIS
-- ============================================================================

--- Calculate total power draw for generator
--- @param generatorData GeneratorData Generator data
--- @return number Total power draw
--- @return number Active consumers count
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetTotalPowerDraw(generatorData)
    if not generatorData then
        return 0, 0
    end
    
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local totalPowerDraw = 0
    local activeConsumers = 0
    
    -- connectedBuildings is Kahlua-deserialized (string numeric keys); use pairs
    for _, buildingId in pairs(generatorData.connectedBuildings) do
        local buildingData = StateManager.GetBuilding(buildingId)
        
        if buildingData then
            -- Use cached powered draw so strain damage doesn't drop offchunk
            local draw = buildingData.strainTotalPowerDraw or buildingData.totalPowerDraw or 0
            totalPowerDraw = totalPowerDraw + draw
            activeConsumers = activeConsumers + LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(buildingData)
        end
    end
    
    return totalPowerDraw, activeConsumers
end

--- Get breakdown of power consumption by building
--- @param generatorData GeneratorData Generator data
--- @return table Array of {buildingId, powerDraw, consumers}
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetPowerBreakdown(generatorData)
    if not generatorData then
        return {}
    end
    
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local breakdown = {}
    
    -- connectedBuildings is Kahlua-deserialized (string numeric keys); use pairs
    for _, buildingId in pairs(generatorData.connectedBuildings) do
        local buildingData = StateManager.GetBuilding(buildingId)
        
        if buildingData then
            table.insert(breakdown, {
                buildingId = buildingId,
                powerDraw = buildingData.strainTotalPowerDraw or buildingData.totalPowerDraw or 0,
                consumers = LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(buildingData),
                totalConsumers = LKS_EletricidadeConstrucao.Data.Building.GetTotalConsumerCount(buildingData)
            })
        end
    end
    
    -- Sort by power draw (highest first)
    table.sort(breakdown, function(a, b)
        return a.powerDraw > b.powerDraw
    end)
    
    return breakdown
end

-- ============================================================================
-- OPTIMIZATION SUGGESTIONS
-- ============================================================================

--- Get optimization suggestions for generator
--- @param generatorData GeneratorData Generator data
--- @return table Array of suggestion strings
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetOptimizationSuggestions(generatorData)
    if not generatorData then
        return {}
    end
    
    local suggestions = {}
    local strain = generatorData.strain
    local strainLevel = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainLevel(strain)
    
    if strainLevel == "critical" then
        table.insert(suggestions, "CRITICAL: Generator is severely overloaded!")
        table.insert(suggestions, "Consider adding more generators or reducing power consumption")
    elseif strainLevel == "high" then
        table.insert(suggestions, "Generator is heavily loaded - fuel consumption increased by " .. 
            string.format("%.0f%%", (LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData) - 1.0) * 100))
        table.insert(suggestions, "Turn off unnecessary lights to reduce load")
    elseif strainLevel == "medium" then
        table.insert(suggestions, "Generator load is moderate")
    elseif strainLevel == "low" then
        table.insert(suggestions, "Generator load is light - operating efficiently")
    else
        table.insert(suggestions, "Generator is idle - no power consumption")
    end
    
    -- Add fuel-specific suggestions
    if LKS_EletricidadeConstrucao.Data.Generator.NeedsRefuel(generatorData, 20) then
        table.insert(suggestions, "Fuel level low - refuel soon")
    end
    
    return suggestions
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Print strain calculator status for generator
--- @param generatorData GeneratorData Generator data
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PrintGeneratorStrain(generatorData)
    if not generatorData then
        LKS_EletricidadeConstrucao.Print("No generator data provided")
        return
    end
    
    local powerDraw, consumers = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetTotalPowerDraw(generatorData)
    local strain = generatorData.strain
    local multiplier = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData)
    local efficiency = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetEfficiency(strain)
    local strainLevel = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainLevel(strain)
    
    LKS_EletricidadeConstrucao.Print("=== Generator Strain: " .. generatorData.id .. " ===")
    LKS_EletricidadeConstrucao.Print("Power Draw: " .. powerDraw)
    LKS_EletricidadeConstrucao.Print("Active Consumers: " .. consumers)
    LKS_EletricidadeConstrucao.Print("Strain: " .. string.format("%.1f%%", strain) .. " (" .. strainLevel .. ")")
    LKS_EletricidadeConstrucao.Print("Fuel Multiplier: " .. string.format("%.2fx", multiplier))
    LKS_EletricidadeConstrucao.Print("Efficiency: " .. string.format("%.0f%%", efficiency))
    local _cbCount = 0
    if generatorData.connectedBuildings then
        for _ in pairs(generatorData.connectedBuildings) do _cbCount = _cbCount + 1 end
    end
    LKS_EletricidadeConstrucao.Print("Buildings Connected: " .. _cbCount)
    
    -- Print breakdown
    local breakdown = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetPowerBreakdown(generatorData)
    if #breakdown > 0 then
        LKS_EletricidadeConstrucao.Print("Power Breakdown:")
        for i, entry in ipairs(breakdown) do
            LKS_EletricidadeConstrucao.Print(string.format("  %d. %s: %.1f power, %d/%d consumers active",
                i, entry.buildingId, entry.powerDraw, entry.consumers, entry.totalConsumers))
        end
    end
    
    -- Print suggestions
    local suggestions = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetOptimizationSuggestions(generatorData)
    if #suggestions > 0 then
        LKS_EletricidadeConstrucao.Print("Suggestions:")
        for _, suggestion in ipairs(suggestions) do
            LKS_EletricidadeConstrucao.Print("  - " .. suggestion)
        end
    end
end

-- ============================================================================
-- STRAIN-BASED DAMAGE SYSTEM
-- ============================================================================

--- Apply strain-based damage to generator
--- Called each fuel consumption tick
--- @param generatorData GeneratorData Generator data
--- @param deltaSeconds number Time delta since last update
--- @return boolean True if generator failed (turned off)
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage(generatorData, deltaSeconds)
    if not generatorData or not generatorData.strain or generatorData.strain <= 100 then
        -- Reset overload timer if strain is at or below 100% (no damage below overload)
        -- 76-100% strain only incurs the fuel consumption penalty, NOT condition damage.
        if generatorData and generatorData.id then
            _overloadDuration[generatorData.id] = nil
        end
        return false  -- No damage below 100% overload threshold
    end
    
    local genObj = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    if not genObj then
        return false
    end
    
    local strain = generatorData.strain
    local damageMultiplier = 0
    local failChance = 0
    
    -- DAMAGE TIERS:
    -- 0-100%:  No condition damage (only fuel multiplier applies)
    -- 101-200% (grace active, < 1 hr overload): 1x vanilla damage, no fail chance
    -- 101-200% (grace expired):                 1x to 5x vanilla damage + fail chance
    
    -- Accumulate overload time; damage AND fail chance only after grace period
    -- Cap accumulation to prevent instant grace expiry during catch-up periods.
    -- After being offchunk for hours, deltaSeconds might be 7200+ seconds, which would
    -- instantly expire the 3600-second grace period even if overload just started.
    local currentElapsed = _overloadDuration[generatorData.id] or 0
    local incrementCapped = math.min(deltaSeconds, 600)  -- Max 10 minutes per tick
    local elapsed = currentElapsed + incrementCapped
    _overloadDuration[generatorData.id] = elapsed

    -- 101-200%: Linear from 1x to 5x damage
    local t = math.min((strain - 100) / 100, 1.0)  -- 0.0 at 100%, 1.0 at 200%

    if elapsed >= OVERLOAD_GRACE_SECONDS then
        -- Grace expired: scaled penalty (1x-5x) + fail chance
        damageMultiplier = 1.0 + (t * 4.0)

        -- Fail chance increases from 0% at 101% to 10% per minute at 200%
        -- Cap per-tick fail chance to prevent instant failure during catch-up periods.
        -- At 200% strain, max 5% chance per check regardless of deltaSeconds.
        local failChancePerMinute = t * 0.10  -- 0% at 101%, 10% at 200%
        local failChanceUncapped = failChancePerMinute * (deltaSeconds / 60)
        failChance = math.min(failChanceUncapped, t * 0.05)  -- Cap at 5% per tick at 200% strain
    else
        -- Grace period active: minimal vanilla damage rate (1x), no fail chance
        damageMultiplier = 1.0
    end
    
    -- Base condition loss per game-hour under overload.
    -- deltaSeconds is game-seconds (derived from getWorldAgeHours() × 3600), so this
    -- rate is independent of the sandbox time-multiplier / real-world clock.
    -- At 1x (101% overload, grace expired): 0.02 condition per game-hour → breaks after ~5000 game-hours.
    -- At 5x (200% overload, grace expired): 0.10 condition per game-hour → breaks after ~1000 game-hours.
    local vanillaDamagePerHour = 0.02
    local strainDamagePerHour = vanillaDamagePerHour * damageMultiplier
    local damage = strainDamagePerHour * (deltaSeconds / 3600)
    
    -- Apply damage
    local currentCondition = genObj:getCondition()
    local newCondition = math.max(0, currentCondition - damage)
    genObj:setCondition(newCondition)
    
    -- Log damage if significant
    if damage > 0.001 then
        local overloadInfo = ""
        if elapsed < OVERLOAD_GRACE_SECONDS then
            overloadInfo = string.format(" [grace: %.0f/3600s]", elapsed)
        else
            overloadInfo = " [grace: EXPIRED]"
        end
        LKS_EletricidadeConstrucao.Print(string.format(
            "[StrainDamage] gen=%s strain=%.1f%% damage=%.4f (%.1fx) condition: %.1f -> %.1f%s",
            generatorData.id, strain, damage, damageMultiplier, currentCondition, newCondition, overloadInfo))
    end
    
    -- Check for catastrophic failure at extreme strain
    if failChance > 0 then
        local roll = ZombRand(10000) / 10000  -- 0.0000 to 0.9999
        if roll < failChance then
            LKS_EletricidadeConstrucao.Print(string.format(
                "[StrainFailure] gen=%s FAILED due to extreme strain (%.1f%%)! Generator shut down.",
                generatorData.id, strain))
            return true
        end
    end
    
    -- If condition reaches 0, generator breaks
    if newCondition <= 0 then
        LKS_EletricidadeConstrucao.Print(string.format(
            "[StrainFailure] gen=%s BROKEN due to strain damage! Condition: 0",
            generatorData.id))
        return true
    end
    
    return false
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Fuel.StrainCalculator", "2.0.0")

return LKS_EletricidadeConstrucao.Fuel.StrainCalculator
