-- ============================================================================
-- ARQUIVO: LKS_Laundry_AutoCycleHandler.lua
-- EXTENSAO: LKS SuperMod Patch (Handler Loot Window — Ciclo Automatico)
-- OBJETIVO: Botao [AUTO] na Loot Window do Combo Washer Dryer que inicia
--           ciclo automatico (lavagem + secagem) com um clique.
-- AUTOR: LKS FERREIRA
-- VERSAO: 1.0 (Project Zomboid Build 42)
-- DATA DA ULTIMA MODIFICACAO: 24/06/2026
-- ============================================================================

require "ISUI/LootWindow/ISLootWindowObjectControlHandler"

LKS_LootWindowHandler_LaundryAutoCycle = ISLootWindowObjectControlHandler:derive("LKS_LootWindowHandler_LaundryAutoCycle")
local Handler = LKS_LootWindowHandler_LaundryAutoCycle

--- Visivel apenas para IsoCombinationWasherDryer energizado com agua e desligado.
function Handler:shouldBeVisible()
    if not self.object then return false end
    if not instanceof(self.object, "IsoCombinationWasherDryer") then return false end
    if not self.container then return false end
    if not self.container:isPowered() then return false end
    if self.object:getFluidAmount() <= 0 then return false end
    if self.object:isActivated() then return false end
    return true
end

--- Botao com texto AUTO e cor verde (altColor).
function Handler:getControl()
    self.control = self:getButtonControl("AUTO")
    self.control.tooltip = getText("IGUI_LKS_Laundry_AutoTooltip") or "Ciclo Automatico: lava e seca em sequencia sem intervencao."
    self.control.textColor = {r = 0.0, g = 0.8, b = 0.0, a = 1.0}
    return self.control
end

function Handler:handleJoypadContextMenu(context)
    self:perform()
end

--- Inicia ciclo automatico: seta flags e liga a maquina.
function Handler:perform()
    if isGamePaused() then return end
    if not self.object then return end

    local container = self.object:getContainer()
    if not container or container:isEmpty() then
        self.playerObj:Say(getText("IGUI_LKS_Laundry_SemItens") or "Nenhum item dentro da maquina.")
        return
    end

    local modData = self.object:getModData()
    if modData then
        modData["LKS_Laundry_AutoCycle"] = true
        modData["LKS_Laundry_Phase"] = "lavagem"
    end

    -- Garantir modo lavadora antes de ligar
    if not self.object:isModeWasher() then
        ISWorldObjectContextMenu.onSetComboWasherDryerMode(self.playerObj, self.object, "washer")
    end

    -- Ligar a maquina
    ISWorldObjectContextMenu.onToggleComboWasherDryer(self.playerObj, self.object)
end

function Handler:new()
    local o = ISLootWindowObjectControlHandler.new(self)
    o.altColor = true
    return o
end

-- Registrar handler (alinhado a direita, ao lado do OFF)
ISLootWindowContainerControls.AddHandler(LKS_LootWindowHandler_LaundryAutoCycle, true)

print("[LKS PATCH - LKS_Laundry_AutoCycleHandler.lua] Carregado com sucesso!")
