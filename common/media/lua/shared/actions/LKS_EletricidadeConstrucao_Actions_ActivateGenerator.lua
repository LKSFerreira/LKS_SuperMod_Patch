-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Actions_ActivateGenerator.lua
-- TimedAction for activating/deactivating generators
-- Works with both building-connected and standalone generators
-- LOCATION: shared/actions/

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Actions_ActivateGenerator] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

print("[LKS_EletricidadeConstrucao_Actions_ActivateGenerator] Loading Activate Generator action...")

-- Load required modules
require "TimedActions/ISBaseTimedAction"

-- Register module
LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_Actions_ActivateGenerator")

-- Create namespace
LKS_EletricidadeConstrucao.Actions = LKS_EletricidadeConstrucao.Actions or {}

-- ============================================================
-- ACTIVATE GENERATOR TIMED ACTION
-- ============================================================

LKS_EletricidadeConstrucao_ActivateGenerator = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_ActivateGenerator")

-- ============================================================
-- VALIDATION
-- ============================================================

function LKS_EletricidadeConstrucao_ActivateGenerator:isValid()
    -- Generator must still exist
    if not self.generator then return false end
    
    -- Generator must be at same location
    local square = self.generator:getSquare()
    if not square then return false end
    
    -- If activating, check fuel and condition
    if self.activate then
        if self.generator:getFuel() <= 0 then return false end
        if self.generator:getCondition() <= 0 then return false end
    end
    
    return true
end

function LKS_EletricidadeConstrucao_ActivateGenerator:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

function LKS_EletricidadeConstrucao_ActivateGenerator:update()
    self.character:faceThisObject(self.generator)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

-- ============================================================
-- ANIMATION
-- ============================================================

function LKS_EletricidadeConstrucao_ActivateGenerator:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function LKS_EletricidadeConstrucao_ActivateGenerator:stop()
    ISBaseTimedAction.stop(self)
end

function LKS_EletricidadeConstrucao_ActivateGenerator:perform()
    ISBaseTimedAction.perform(self)
end

-- ============================================================
-- ACTION EXECUTION
-- ============================================================

local function CopyBoundingBox(source)
    if type(source) ~= "table" then
        return nil
    end

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
    if type(t) ~= "table" then
        return false
    end
    for _, entry in pairs(t) do
        if entry == value then
            return true
        end
    end
    return false
end

local function ResolvePoolDataForBuilding(buildingPoolID, generator)
    local LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao
    local stateManager = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local currentMD = generator and generator:getModData() or nil
    if currentMD and currentMD.LKS_EletricidadeConstrucao_PoolData then
        return currentMD.LKS_EletricidadeConstrucao_PoolData
    end
    if not stateManager or not stateManager.GetAllGenerators then
        return nil
    end

    local currentX = generator and generator.getX and generator:getX() or nil
    local currentY = generator and generator.getY and generator:getY() or nil
    local currentZ = generator and generator.getZ and generator:getZ() or nil

    for _, genData in pairs(stateManager.GetAllGenerators() or {}) do
        if genData and TableContainsValue(genData.connectedBuildings, buildingPoolID) then
            local gx = tonumber(genData.x)
            local gy = tonumber(genData.y)
            local gz = tonumber(genData.z) or 0
            if not (gx == currentX and gy == currentY and gz == currentZ) then
                local sq = getSquare(gx, gy, gz)
                if sq then
                    local objects = sq:getObjects()
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj and instanceof(obj, "IsoGenerator") then
                            local objMD = obj:getModData()
                            if objMD and objMD.LKS_EletricidadeConstrucao_PoolData then
                                return objMD.LKS_EletricidadeConstrucao_PoolData
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function RestoreBuildingFromPoolData(buildingPoolID, stateManager, poolData, anchorX, anchorY, anchorZ, reason)
    if not poolData then
        return nil
    end

    local buildingX = poolData.x
    local buildingY = poolData.y
    local buildingZ = poolData.z
    if buildingX == nil then buildingX = anchorX end
    if buildingY == nil then buildingY = anchorY end
    if buildingZ == nil then buildingZ = anchorZ or 0 end
    if buildingX == nil or buildingY == nil then
        return nil
    end

    local buildingData = {
        id = buildingPoolID,
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

    if stateManager.AddBuilding then
        stateManager.AddBuilding(buildingData)
    end

    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Logger and LKS_EletricidadeConstrucao.Core.Logger.Warn then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(string.format(
            "[ActivateGenerator] %s: restored building %s from LKS_EletricidadeConstrucao_PoolData%s",
            tostring(reason or "update"),
            tostring(buildingPoolID),
            buildingData.boundingBox and " with bounding box" or ""
        ), "Power")
    end

    return stateManager.GetBuilding and stateManager.GetBuilding(buildingPoolID) or buildingData
end

local function EnsureGeneratorLinked(buildingData, generator, stateManager)
    if not (buildingData and generator and generator.getSquare) then
        return buildingData
    end

    local sq = generator:getSquare()
    if not sq then
        return buildingData
    end

    local genKey = string.format("%d_%d_%d", sq:getX(), sq:getY(), sq:getZ())
    buildingData.connectedGenerators = buildingData.connectedGenerators or {}

    local hasGenerator = false
    for _, existingKey in pairs(buildingData.connectedGenerators) do
        if existingKey == genKey then
            hasGenerator = true
            break
        end
    end

    if not hasGenerator then
        table.insert(buildingData.connectedGenerators, genKey)
        if stateManager and stateManager.MarkDirty then
            stateManager.MarkDirty()
        end
    end

    return buildingData
end

local function EnsureBuildingState(buildingPoolID, generator, reason)
    local LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao
    local StateManager = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not StateManager or not buildingPoolID then
        return nil
    end

    local md = generator and generator:getModData() or nil
    local poolData = ResolvePoolDataForBuilding(buildingPoolID, generator)
    local buildingData = StateManager.GetBuilding and StateManager.GetBuilding(buildingPoolID) or nil
    local restoredBoundingBox = CopyBoundingBox(poolData and poolData.boundingBox)

    if buildingData then
        local repaired = false
        if restoredBoundingBox and not buildingData.boundingBox then
            buildingData.boundingBox = restoredBoundingBox
            repaired = true
        end
        if poolData then
            if buildingData.x == nil and poolData.x ~= nil then
                buildingData.x = poolData.x
                repaired = true
            end
            if buildingData.y == nil and poolData.y ~= nil then
                buildingData.y = poolData.y
                repaired = true
            end
            if buildingData.z == nil and poolData.z ~= nil then
                buildingData.z = poolData.z
                repaired = true
            end
            if (not buildingData.borderRadius or buildingData.borderRadius <= 0)
                    and poolData.borderRadius ~= nil then
                buildingData.borderRadius = tonumber(poolData.borderRadius) or buildingData.borderRadius
                repaired = true
            end
        end
        if repaired and StateManager.MarkDirty then
            StateManager.MarkDirty()
        end
    end

    if buildingData and buildingData.boundingBox then
        return EnsureGeneratorLinked(buildingData, generator, StateManager)
    elseif buildingData and restoredBoundingBox then
        buildingData.boundingBox = restoredBoundingBox
        if StateManager.MarkDirty then
            StateManager.MarkDirty()
        end
        return EnsureGeneratorLinked(buildingData, generator, StateManager)
    elseif buildingData then
        return EnsureGeneratorLinked(buildingData, generator, StateManager)
    end

    local anchorX, anchorY, anchorZ = nil, nil, nil

    if poolData and poolData.x ~= nil and poolData.y ~= nil then
        anchorX = poolData.x
        anchorY = poolData.y
        anchorZ = poolData.z or (generator and generator:getZ()) or 0
    else
        local bx, by, bz = string.match(tostring(buildingPoolID), "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        anchorX, anchorY, anchorZ = tonumber(bx), tonumber(by), tonumber(bz)
    end

    if not buildingData and poolData then
        buildingData = RestoreBuildingFromPoolData(
            buildingPoolID,
            StateManager,
            poolData,
            anchorX,
            anchorY,
            anchorZ,
            reason
        )
    end

    local Scanner = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner
    if anchorX ~= nil and anchorY ~= nil and Scanner and Scanner.ScanBuilding then
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Logger and LKS_EletricidadeConstrucao.Core.Logger.Warn then
            LKS_EletricidadeConstrucao.Core.Logger.Warn(string.format(
                "[ActivateGenerator] %s: verifying building %s from anchor (%d,%d,%d)",
                tostring(reason or "update"), tostring(buildingPoolID), anchorX, anchorY, anchorZ or 0
            ), "Power")
        end

        local ok, scanned = pcall(Scanner.ScanBuilding, anchorX, anchorY, anchorZ or 0, buildingPoolID)
        if ok and scanned then
            buildingData = scanned
        else
            buildingData = StateManager.GetBuilding and StateManager.GetBuilding(buildingPoolID) or buildingData
        end
    end

    if not buildingData and anchorX ~= nil and anchorY ~= nil then
        buildingData = {
            id = buildingPoolID,
            x = anchorX,
            y = anchorY,
            z = anchorZ or 0,
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
        if StateManager.AddBuilding then
            StateManager.AddBuilding(buildingData)
        end
    end

    return EnsureGeneratorLinked(buildingData, generator, StateManager)
end

local function RefreshBuildingPower(buildingPoolID, generator, reason)
    if not buildingPoolID then
        return nil
    end

    local LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao
    local buildingData = EnsureBuildingState(buildingPoolID, generator, reason)
    local Distributor = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
    if Distributor then
        if Distributor.ForceUpdateBuilding then
            Distributor.ForceUpdateBuilding(buildingPoolID)
        elseif Distributor.ForceUpdate then
            Distributor.ForceUpdate()
        end
    end

    return buildingData
end

local function ExecuteActivateGenerator(generator, activate)
    if not generator then return false end

    -- Get generator ModData
    local md = generator:getModData()
    local buildingPoolID = md.Gen_BuildingPoolID
    local isInBuildingMode = buildingPoolID ~= nil

    if activate then
        -- ========================================
        -- ACTIVATE GENERATOR
        -- ========================================

        -- Set generator state
        generator:setActivated(true)

        -- Update GeneratorData for chunk-independent pool counting
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
            local SM = LKS_EletricidadeConstrucao.Core.StateManager
            local gid = LKS_EletricidadeConstrucao.Data.Generator.MakeId(
                generator:getX(), generator:getY(), generator:getZ())
            local gd = SM.GetGenerator(gid)
            if gd then
                gd.activated = true
                SM.MarkDirty()
            end
        end

        -- Sync immediately BEFORE updating other generators so they see this one as active
        -- In SP: No network sync needed. In MP: transmit to clients.
        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
            generator:transmitModData()
            if isServer() then
                generator:sync()
            end
        end

        -- Apply heat sources immediately on activation if heating is enabled.
        -- LKS_EletricidadeConstrucao_HeatingClient.UpdateAll() only runs every 600 ticks (~60 s); without
        -- this call the building would stay cold for up to a minute after the
        -- generator is turned back on.  LKS_EletricidadeConstrucao_HeatingClient is client-only (nil on
        -- dedicated server), so the guard keeps this safe in MP.
        if LKS_EletricidadeConstrucao_HeatingClient and LKS_EletricidadeConstrucao_HeatingClient.Apply then
            local _md = generator:getModData()
            if _md.HeatingEnabled == true then
                LKS_EletricidadeConstrucao_HeatingClient.Apply(generator)
            end
        end

        -- If in building mode, apply power to building
        if isInBuildingMode and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            -- Check if other generators in the pool are already active.
            -- Immediately recalculate their fuel rate so the Info Window reflects
            -- the new pool size (one more active generator).
            local hasOtherActiveGen = false
            if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
                local buildingData = EnsureBuildingState(buildingPoolID, generator, "activation")
                if buildingData and buildingData.connectedGenerators then
                    for _, genKey in pairs(buildingData.connectedGenerators) do
                        local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        if gx and gy and gz then
                            gx, gy, gz = tonumber(gx), tonumber(gy), tonumber(gz)
                            local sq = getSquare(gx, gy, gz)
                            if sq then
                                local objects = sq:getObjects()
                                for i = 0, objects:size() - 1 do
                                    local obj = objects:get(i)
                                    if obj and instanceof(obj, "IsoGenerator") and obj ~= generator then
                                        if obj:isActivated() then
                                            hasOtherActiveGen = true
                                            -- Directly recalculate rate for this generator (no 0-flash)
                                            local ogx, ogy, ogz = obj:getX(), obj:getY(), obj:getZ()
                                            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager
                                               and LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator then
                                                LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator(ogx, ogy, ogz)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Activation only affects this pool. Repair missing state first, then
            -- re-apply power to the specific building instead of relying on a global pass.
            RefreshBuildingPower(buildingPoolID, generator, hasOtherActiveGen and "activation-pool" or "activation-first-generator")

            -- Update fuel rate for this generator immediately (avoids empty display on first open)
            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager
               and LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator then
                LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator(
                    generator:getX(), generator:getY(), generator:getZ())
            end
        end

        LKS_EletricidadeConstrucao.Print("[ActivateGenerator] Generator activated at " ..
            generator:getX() .. "," .. generator:getY() .. "," .. generator:getZ())
    else
        -- ========================================
        -- DEACTIVATE GENERATOR
        -- ========================================

        -- Set generator state
        generator:setActivated(false)

        -- Update GeneratorData for chunk-independent pool counting
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
            local SM = LKS_EletricidadeConstrucao.Core.StateManager
            local gid = LKS_EletricidadeConstrucao.Data.Generator.MakeId(
                generator:getX(), generator:getY(), generator:getZ())
            local gd = SM.GetGenerator(gid)
            if gd then
                gd.activated = false
                SM.MarkDirty()
            end
        end

        -- Sync immediately BEFORE updating other generators so they see this one as inactive
        -- In SP: No network sync needed. In MP: transmit to clients.
        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
            generator:transmitModData()
            if isServer() then
                generator:sync()
            end
        end

        -- Remove heat sources immediately on deactivation.
        -- LKS_EletricidadeConstrucao_HeatingClient.UpdateAll() only runs every 600 ticks (~60 s); without
        -- this call the building stays warm for up to a minute after shutdown.
        if LKS_EletricidadeConstrucao_HeatingClient and LKS_EletricidadeConstrucao_HeatingClient.Remove then
            local _sq = generator:getSquare()
            if _sq then
                LKS_EletricidadeConstrucao_HeatingClient.Remove(_sq:getX() .. "_" .. _sq:getY() .. "_" .. _sq:getZ())
            end
        end

        -- If in building mode, remove power from building
        if isInBuildingMode and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            -- Check if other generators in the pool are still active.
            -- Immediately recalculate their fuel rate so the Info Window reflects
            -- the new pool size (one fewer active generator) without a 0-flash.
            local hasOtherActiveGen = false
            if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
                local buildingData = EnsureBuildingState(buildingPoolID, generator, "deactivation")
                if buildingData and buildingData.connectedGenerators then
                    for _, genKey in pairs(buildingData.connectedGenerators) do
                        local gx, gy, gz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        if gx and gy and gz then
                            gx, gy, gz = tonumber(gx), tonumber(gy), tonumber(gz)
                            local sq = getSquare(gx, gy, gz)
                            if sq then
                                local objects = sq:getObjects()
                                for i = 0, objects:size() - 1 do
                                    local obj = objects:get(i)
                                    if obj and instanceof(obj, "IsoGenerator") and obj ~= generator then
                                        if obj:isActivated() then
                                            hasOtherActiveGen = true
                                            -- Directly recalculate rate for this generator (no 0-flash)
                                            local ogx, ogy, ogz = obj:getX(), obj:getY(), obj:getZ()
                                            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager
                                               and LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator then
                                                LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator(ogx, ogy, ogz)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            RefreshBuildingPower(buildingPoolID, generator, hasOtherActiveGen and "deactivation-pool" or "deactivation-last-generator")
        end

        LKS_EletricidadeConstrucao.Print("[ActivateGenerator] Generator deactivated at " ..
            generator:getX() .. "," .. generator:getY() .. "," .. generator:getZ())
    end

    return true
end

function LKS_EletricidadeConstrucao_ActivateGenerator:complete()
    local Runtime = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local isMPClient = Runtime and Runtime.IsMultiplayerClient and Runtime.IsMultiplayerClient()

    if isMPClient then
        local sq = self.generator and self.generator:getSquare()
        if sq and isClient() then
            sendClientCommand(self.character, "LKS_EletricidadeConstrucao", "ActivateGenerator", {
                genX = sq:getX(),
                genY = sq:getY(),
                genZ = sq:getZ(),
                activate = self.activate == true,
            })
        end
        return true
    end

    return ExecuteActivateGenerator(self.generator, self.activate)
end

-- ============================================================
-- DURATION & CONSTRUCTOR
-- ============================================================

function LKS_EletricidadeConstrucao_ActivateGenerator:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    
    -- Activation takes ~5 seconds (50 ticks)
    return 50
end

function LKS_EletricidadeConstrucao_ActivateGenerator:new(character, generator, activate)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.generator = generator
    o.activate = activate
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

-- ============================================================
-- EXPORT TO NAMESPACE
-- ============================================================

LKS_EletricidadeConstrucao_ActivateGenerator.Execute = ExecuteActivateGenerator
LKS_EletricidadeConstrucao.Actions.ActivateGenerator = LKS_EletricidadeConstrucao_ActivateGenerator

print("[LKS_EletricidadeConstrucao_Actions_ActivateGenerator] Activate Generator action loaded successfully")
