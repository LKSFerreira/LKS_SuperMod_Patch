-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Actions_DisconnectBuilding.lua
-- TimedAction for disconnecting generator from building
-- Removes generator from power pool and clears ModData
-- LOCATION: shared/actions/

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Actions_DisconnectBuilding] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

print("[LKS_EletricidadeConstrucao_Actions_DisconnectBuilding] Loading Disconnect Building action...")

-- Load required modules
require "TimedActions/ISBaseTimedAction"

-- Register module
LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_Actions_DisconnectBuilding")

-- Create namespace
LKS_EletricidadeConstrucao.Actions = LKS_EletricidadeConstrucao.Actions or {}

-- ============================================================
-- DISCONNECT BUILDING TIMED ACTION
-- ============================================================

LKS_EletricidadeConstrucao_DisconnectBuilding = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_DisconnectBuilding")

local function ShouldSayToCharacter(runtime)
    if not runtime then return true end
    return not (runtime.IsServer and runtime.IsServer()
        and runtime.IsMultiplayer and runtime.IsMultiplayer())
end

local function TryFaceGenerator(character, generator)
    if not character or not generator then return false end
    return pcall(function()
        character:faceThisObject(generator)
    end)
end

-- ============================================================
-- VALIDATION
-- ============================================================

function LKS_EletricidadeConstrucao_DisconnectBuilding:isValid()
    -- Generator must still exist
    if not self.generator then return false end
    
    -- Generator must be at same location
    local square = self.generator:getSquare()
    if not square then return false end
    
    -- Generator must be connected
    local md = self.generator:getModData()
    if not md.Gen_BuildingPoolID then return false end
    
    return true
end

function LKS_EletricidadeConstrucao_DisconnectBuilding:waitToStart()
    if not TryFaceGenerator(self.character, self.generator) then
        return false
    end
    return self.character:shouldBeTurning()
end

function LKS_EletricidadeConstrucao_DisconnectBuilding:update()
    TryFaceGenerator(self.character, self.generator)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

-- ============================================================
-- ANIMATION
-- ============================================================

function LKS_EletricidadeConstrucao_DisconnectBuilding:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function LKS_EletricidadeConstrucao_DisconnectBuilding:stop()
    ISBaseTimedAction.stop(self)
end

function LKS_EletricidadeConstrucao_DisconnectBuilding:perform()
    ISBaseTimedAction.perform(self)
end

-- ============================================================
-- ACTION EXECUTION
-- ============================================================

function LKS_EletricidadeConstrucao_DisconnectBuilding:complete()
    local Runtime = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local isMPClient = Runtime and Runtime.IsMultiplayerClient and Runtime.IsMultiplayerClient()

    if isMPClient then
        local sq = self.generator and self.generator:getSquare()
        if sq and isClient() then
            sendClientCommand(self.character, "LKS_EletricidadeConstrucao", "DisconnectBuilding", {
                genX = sq:getX(),
                genY = sq:getY(),
                genZ = sq:getZ(),
            })
        end
        return true
    end

    -- Get generator ModData
    local md = self.generator:getModData()
    local buildingPoolID = md.Gen_BuildingPoolID
    
    if not buildingPoolID then
        LKS_EletricidadeConstrucao.Warn("[DisconnectBuilding] Generator not connected to building")
        return true
    end
    
    LKS_EletricidadeConstrucao.Print("[DisconnectBuilding] Disconnecting generator from building pool: " .. buildingPoolID)
    
    -- Deactivate generator first if active
    if self.generator:isActivated() then
        self.generator:setActivated(false)
        
        -- Remove power from building
        if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            if LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
            end
        end
    end

local sq = self.generator:getSquare()

    -- Remove heat sources immediately (don't wait for the 600-tick UpdateAll cycle).
    -- LKS_EletricidadeConstrucao_HeatingClient is client-only; the guard keeps this a no-op on dedicated server.
    if LKS_EletricidadeConstrucao_HeatingClient and LKS_EletricidadeConstrucao_HeatingClient.Remove and sq then
        LKS_EletricidadeConstrucao_HeatingClient.Remove(sq:getX() .. "_" .. sq:getY() .. "_" .. sq:getZ())
    end
    local genX = sq and sq:getX() or 0
    local genY = sq and sq:getY() or 0
    local genZ = sq and sq:getZ() or 0
    local genKey = string.format("%d_%d_%d", genX, genY, genZ)

    -- If this generator is the pool owner (holds LKS_EletricidadeConstrucao_PoolData) and other generators
    -- remain in the pool, transfer ownership to the next available generator before
    -- wiping our own data.
    if md.LKS_EletricidadeConstrucao_PoolData then
        local SM_pre = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
        local bldPre = SM_pre and SM_pre.GetBuilding and SM_pre.GetBuilding(buildingPoolID)
        if bldPre and bldPre.connectedGenerators then
            local cell = getCell and getCell()
            if cell then
                -- connectedGenerators is Kahlua-deserialized (string numeric keys); use pairs
                for _, k in pairs(bldPre.connectedGenerators) do
                    if k ~= genKey then
                        local nx, ny, nz = string.match(k, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        if nx then
                            local nSq = cell:getGridSquare(tonumber(nx), tonumber(ny), tonumber(nz))
                            if nSq then
                                local nObjs = nSq:getObjects()
                                for ni = 0, nObjs:size()-1 do
                                    local nObj = nObjs:get(ni)
                                    if nObj and instanceof(nObj, "IsoGenerator") then
                                        local nMd = nObj:getModData()
                                        local nextWorldId = md.LKS_EletricidadeConstrucao_WorldId
                                        if not nextWorldId or nextWorldId == "unknown" then
                                            nextWorldId = LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId and
                                                          LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId() or nil
                                        end
                                        if nextWorldId == "unknown" then
                                            nextWorldId = nil
                                        end
                                        nMd.LKS_EletricidadeConstrucao_PoolData = md.LKS_EletricidadeConstrucao_PoolData  -- transfer ownership
                                        nMd.LKS_EletricidadeConstrucao_WorldId  = nextWorldId
                                        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                            nObj:transmitModData()
                                        end
                                        LKS_EletricidadeConstrucao.Print(string.format(
                                            "[DisconnectBuilding] Pool ownership transferred from %s to %s",
                                            genKey, k))
                                        break
                                    end
                                end
                            end
                        end
                        break  -- transfer to first available other generator only
                    end
                end
            end
        end
    end

    -- 1. Wipe the pool link AND all cached stats from IsoGenerator ModData.
    --    If left in place, Gen_Stats_* values persist on the IsoObject and
    --    are read back by the Info Window as if the building was still connected.
    md.Gen_BuildingPoolID           = nil
    md.Gen_Stats_Consumers          = nil
    md.Gen_Stats_ActiveConsumers    = nil
    md.Gen_Stats_Lights             = nil
    md.Gen_Stats_ActiveLights       = nil
    md.Gen_Stats_Lamps              = nil
    md.Gen_Stats_ActiveLamps        = nil
    md.Gen_Stats_Appliances         = nil
    md.Gen_Stats_ActiveAppliances   = nil
    md.Gen_Stats_PowerDraw          = nil
    md.Gen_Stats_Strain             = nil
    md.Gen_Stats_FuelRateLph        = nil
    md.Gen_Stats_Powered            = nil
    md.LKS_EletricidadeConstrucao_DisconnectSuppressed      = true
    md.LKS_EletricidadeConstrucao_WorldId                   = nil
    md.LKS_EletricidadeConstrucao_PoolData                  = nil
    
    -- Sync to clients in MP (no-op in SP)
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        self.generator:transmitModData()
        if isServer() then
            self.generator:sync()
        end
    end

    -- 2. Get the generator ID for cleanup operations
    local genId = nil
    local SM = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if SM then
        genId = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
                and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                and LKS_EletricidadeConstrucao.Data.Generator.MakeId(genX, genY, genZ)

        -- Clear stale generator back-links before save so periodic recovery
        -- code cannot reattach an intentionally disconnected pre-reload generator.
        local genData = genId and SM.GetGenerator(genId)
        if not genData and LKS_EletricidadeConstrucao.Data
                and LKS_EletricidadeConstrucao.Data.Generator
                and LKS_EletricidadeConstrucao.Data.Generator.New then
            genData = LKS_EletricidadeConstrucao.Data.Generator.New(self.generator)
        end
        if genData then
            if LKS_EletricidadeConstrucao.Data
                    and LKS_EletricidadeConstrucao.Data.Generator
                    and LKS_EletricidadeConstrucao.Data.Generator.UpdateFromObject then
                LKS_EletricidadeConstrucao.Data.Generator.UpdateFromObject(genData, self.generator)
            end
            if LKS_EletricidadeConstrucao.Data
                    and LKS_EletricidadeConstrucao.Data.Generator
                    and LKS_EletricidadeConstrucao.Data.Generator.ClearBuildings then
                LKS_EletricidadeConstrucao.Data.Generator.ClearBuildings(genData)
            else
                genData.connectedBuildings = {}
                genData.strain = 0
            end
            if SM.AddGenerator then
                if SM.RemoveGenerator and genData.id then
                    SM.RemoveGenerator(genData.id)
                end
                SM.AddGenerator(genData)
            end
            SM.MarkDirty()
        end
        
        -- 3. Strip the generator from buildingData.connectedGenerators and
        --    turn consumers off BEFORE removing the building from state so the
        --    distributor can still find it when it tries to power everything down.
        local bldData = SM.GetBuilding(buildingPoolID)
        if bldData and bldData.connectedGenerators then
            -- Remove genKey (Kahlua string-key safe)
            local _newList = {}
            for _, v in pairs(bldData.connectedGenerators) do
                if v ~= genKey then table.insert(_newList, v) end
            end
            bldData.connectedGenerators = _newList
            SM.MarkDirty()
        end
    end

    -- 4. Force distributor to turn off all consumers WHILE building is still in state
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
        if LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding then
            LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(buildingPoolID)
        elseif LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
            LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
        end
    end

    -- 5. Remove from runtime power manager connection table
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager and sq then
        local connId = LKS_EletricidadeConstrucao.Power.Manager.CreateConnectionId(genX, genY, genZ, buildingPoolID)
        if LKS_EletricidadeConstrucao.Power.Manager.DisconnectGeneratorFromBuilding then
            LKS_EletricidadeConstrucao.Power.Manager.DisconnectGeneratorFromBuilding(connId)
        elseif LKS_EletricidadeConstrucao.Power.Manager.DisconnectGenerator then
            LKS_EletricidadeConstrucao.Power.Manager.DisconnectGenerator(connId)
        end
    end

    -- 6. NOW remove the building from state if no generators remain
    local SM2 = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if SM2 then
        local bldData2 = SM2.GetBuilding(buildingPoolID)
        if bldData2 and bldData2.connectedGenerators and #bldData2.connectedGenerators == 0 then
            SM2.RemoveBuilding(buildingPoolID)
            SM2.MarkDirty()
        end
        
        -- 7. Keep the generator in StateManager as a disconnected generator.
        --    Removing it here persists an empty LKS_EletricidadeConstrucao snapshot on the next restart
        --    if the user disconnects before reconnecting it elsewhere.

        -- 8. Save immediately so the cleared state survives reload
        SM2.Save(true, true)
    end
    
    if ShouldSayToCharacter(Runtime) then
        self.character:Say(getText("IGUI_DisconnectedFromBuilding") or "Disconnected from building")
    end
    
    return true
end

-- ============================================================
-- DURATION & CONSTRUCTOR
-- ============================================================

function LKS_EletricidadeConstrucao_DisconnectBuilding:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    
    -- Disconnection takes ~5 seconds (50 ticks)
    return 50
end

function LKS_EletricidadeConstrucao_DisconnectBuilding:new(character, generator)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.generator = generator
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

-- ============================================================
-- EXPORT TO NAMESPACE
-- ============================================================

LKS_EletricidadeConstrucao.Actions.DisconnectBuilding = LKS_EletricidadeConstrucao_DisconnectBuilding

print("[LKS_EletricidadeConstrucao_Actions_DisconnectBuilding] Disconnect Building action loaded successfully")
