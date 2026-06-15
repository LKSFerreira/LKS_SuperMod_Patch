-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Actions_LinkBarrel.lua
-- LKS_EletricidadeConstrucao V2 - Timed action for linking / unlinking petrol barrels.
-- Duration: 3 seconds (Loot animation).
-- Usable on both client and server (shared).

require "TimedActions/ISBaseTimedAction"

LKS_EletricidadeConstrucao_LinkBarrelAction = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_LinkBarrelAction")

--- Constructor.
-- @param player    IsoPlayer  performing character
-- @param barrel    IsoObject  the barrel object
-- @param square    IsoGridSquare  barrel's square
-- @param buildingID string     the building to link/unlink
-- @param isLinking bool       true = link, false = unlink
function LKS_EletricidadeConstrucao_LinkBarrelAction:new(player, barrel, square, buildingID, isLinking)
    local o = ISBaseTimedAction.new(self, player)
    setmetatable(o, self)
    self.__index = self

    o.player      = player
    o.barrel      = barrel
    o.square      = square
    o.buildingID  = buildingID
    o.isLinking   = isLinking
    o.maxTime     = 50  -- ~3 s at normal speed

    return o
end

function LKS_EletricidadeConstrucao_LinkBarrelAction:isValid()
    if not self.square or not self.barrel then return false end
    return self.square:getObjects():contains(self.barrel)
end

function LKS_EletricidadeConstrucao_LinkBarrelAction:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function LKS_EletricidadeConstrucao_LinkBarrelAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
end

function LKS_EletricidadeConstrucao_LinkBarrelAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:reportEvent("EventLootItem")
end

function LKS_EletricidadeConstrucao_LinkBarrelAction:stop()
    ISBaseTimedAction.stop(self)
end

function LKS_EletricidadeConstrucao_LinkBarrelAction:perform()
    ISBaseTimedAction.perform(self)
end

function LKS_EletricidadeConstrucao_LinkBarrelAction:complete()
    if not self.barrel then return true end

    local Runtime = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local isMPClient = Runtime and Runtime.IsMultiplayerClient and Runtime.IsMultiplayerClient()
    local canResolveOnServer = self.isLinking and isMPClient
    local sq = self.barrel:getSquare()
    if not self.buildingID and not canResolveOnServer then
        return true
    end

    -- Server-side: perform the link/unlink directly
    if isServer() or not isClient() then
        local Barrels = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels
        local resolvedBuildingID = self.buildingID
        if not resolvedBuildingID and Barrels and Barrels.GetLinkedBuilding then
            resolvedBuildingID = Barrels.GetLinkedBuilding(self.barrel)
        end
        if not resolvedBuildingID or not Barrels then
            return true
        end

        if self.isLinking then
            local ok = Barrels.Link(self.barrel, resolvedBuildingID)
            if not ok then return true end
        else
            Barrels.Unlink(self.barrel, resolvedBuildingID)
        end

        local Dist = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
        if Dist then
            if Dist.RefreshBuildingStats then
                Dist.RefreshBuildingStats(resolvedBuildingID)
            elseif Dist.ForceUpdateBuilding then
                Dist.ForceUpdateBuilding(resolvedBuildingID)
            end
        end

        return true
    end

    -- Client-side: send command to server
    if not sq then return true end

    sendClientCommand(self.player, "LKS_EletricidadeConstrucao", "BarrelLink", {
        bx         = sq:getX(),
        by         = sq:getY(),
        bz         = sq:getZ(),
        buildingID = self.buildingID,
        linking    = self.isLinking,
    })

    return true
end

return LKS_EletricidadeConstrucao_LinkBarrelAction
