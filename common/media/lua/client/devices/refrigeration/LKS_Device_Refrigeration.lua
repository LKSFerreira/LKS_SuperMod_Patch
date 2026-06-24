-- ============================================================================
-- 💖 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado como parte do LKS SuperMod Patch.
-- Agradecemos imensamente a Erick (4422) pelo mod original "Fridges Off!"
-- (ID Workshop: 2853974107) por sua fantástica contribuição para a comunidade!
-- ============================================================================

-- ============================================================================
-- ARQUIVO: LKS_Device_Refrigeration.lua
-- EXTENSÃO: LKS SuperMod Patch (Módulo de Comportamento de Refrigeração)
-- OBJETIVO: Driver de comportamento e texturas para geladeiras (Fridges) e
--           congeladores (Freezers) no gerenciador LKS_ApplianceManager.
-- CRÉDITOS DO MOD ORIGINAL: Fridges Off! (ID Workshop: 2853974107) por 4422 (Erick)
-- ============================================================================

-- Inicialização defensiva do gerenciador para robustez de carregamento
LKS_ApplianceManager = LKS_ApplianceManager or {}
LKS_ApplianceManager.devices = LKS_ApplianceManager.devices or {}
LKS_ApplianceManager.containerTypeMap = LKS_ApplianceManager.containerTypeMap or {}
LKS_ApplianceManager.javaClassMap = LKS_ApplianceManager.javaClassMap or {}

if LKS_ApplianceManager.recursoAtivo and not LKS_ApplianceManager.recursoAtivo("RefrigerationEnabled", true) then
    print("[LKS PATCH - LKS_Device_Refrigeration.lua] Refrigeracao desativada no sandbox.")
    return
end

local LKS_Device_Refrigeration = {
    recipientesAceitos = {"fridge", "freezer", "geladeira_desligada", "congelador_desligado", "fridge_off", "freezer_off"},
    classesJava = {}, -- Roteamento dinâmico feito via tipo de recipiente no Appliance Manager
    brilhoInativo = "escurece35"
}

---@param text String
local function customPrint(text)
    print("LKS_Device_Refrigeration.lua: " .. text)
end

-- ============================================================================
-- ⏳ AÇÃO TEMPORIZADA DE INTERAÇÃO (TIMED ACTION)
-- ============================================================================

---@class ISToggleFridgesFreezers : ISBaseTimedAction
ISToggleFridgesFreezers = ISBaseTimedAction:derive("ISToggleFridgesFreezers");

function ISToggleFridgesFreezers:isValid()
    return true
end

function ISToggleFridgesFreezers:update()
end

function ISToggleFridgesFreezers:start()
    self.character:faceThisObject(self.object)
end

function ISToggleFridgesFreezers:stop()
    ISBaseTimedAction.stop(self)
end

function ISToggleFridgesFreezers:perform()
    if self.state == 0 then
        sendClientCommand("fridges-off", "off", {x = self.object:getX(), y = self.object:getY(), z = self.object:getZ()});
    else
        sendClientCommand("fridges-off", "on", {x = self.object:getX(), y = self.object:getY(), z = self.object:getZ()});
    end
    ISBaseTimedAction.perform(self)
end

function ISToggleFridgesFreezers:new(objPlayer, state, obj)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = objPlayer
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = 0
    o.object = obj
    o.state = state
    return o
end

-- ============================================================================
-- 🎒 EXTENSÃO DE INTERFACE DO DRIVER (INVENTÁRIO)
-- ============================================================================



-- ============================================================================
-- 🖱️ EXTENSÃO DE INTERFACE DO DRIVER (MENU DE CONTEXTO)
-- ============================================================================

--- Constrói o menu premium de tomada para geladeiras e congeladores.
---
--- @param jogadorNumero number O índice do jogador local (0 a 3).
--- @param menuContexto ISContextMenu O menu de contexto sendo preenchido.
--- @param objetosMundo table A lista de objetos físicos clicados no mundo.
--- @param objetoEletrico IsoObject O objeto elétrico clicado.
function LKS_Device_Refrigeration.construirMenuContexto(jogadorNumero, menuContexto, objetosMundo, objetoEletrico)
    local jogadorObjeto = getSpecificPlayer(jogadorNumero)
    if jogadorObjeto:isAsleep() then return end

    local containerCount = objetoEletrico:getContainerCount()
    if containerCount <= 0 then return end

    local containerType = objetoEletrico:getContainer():getType()

    local changeFridgeFreezerState = function(_, objPlayer, state, o)
        if luautils.walkAdj(objPlayer, o:getSquare()) then
            ISTimedActionQueue.add(ISToggleFridgesFreezers:new(objPlayer, state, o))
        end
    end

    if containerType == "fridge" or containerType == "freezer" then
        local optionOff = menuContexto:addOptionOnTop(getText("ContextMenu_TurnOff") or "Desligar", objetosMundo, changeFridgeFreezerState, jogadorObjeto, 0, objetoEletrico)
        optionOff.iconTexture = getTexture("media/ui/LKS_Button_Power_Off.png")
    elseif containerType == "geladeira_desligada" or containerType == "congelador_desligado" or containerType == "fridge_off" or containerType == "freezer_off" then
        local optionOn = menuContexto:addOptionOnTop(getText("ContextMenu_TurnOn") or "Ligar", objetosMundo, changeFridgeFreezerState, jogadorObjeto, 1, objetoEletrico)
        optionOn.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")
    end
end

-- ============================================================================
-- 📡 SINCRONIZAÇÃO DE REDE DO CLIENTE (SERVER COMMAND REACTION)
-- ============================================================================

local function onServerCommand(module, command, args)
    if module == "fridges-off" and command == "sync" then
        local gridSquare = getWorld():getCell():getGridSquare(args.x, args.y, args.z)
        if gridSquare == nil then
            customPrint(getText("IGUI_LKS_EletricidadeConstrucao_Debug_DesyncSquare") or "Não foi possível encontrar este quadrado, provável dessincronização")
            return
        end

        local objects = gridSquare:getObjects()
        if objects ~= nil then
            ---@type IsoObject
            local object

            for i = 0, objects:size() - 1, 1 do
                if objects:get(i):getContainerCount() > 0 then
                    if objects:get(i):getContainerByEitherType("fridge", "freezer") or objects:get(i):getContainerByEitherType("geladeira_desligada", "congelador_desligado") or objects:get(i):getContainerByEitherType("fridge_off", "freezer_off") then
                        object = objects:get(i)
                        break
                    end
                end
            end

            if object ~= nil then
                if args.fridge == "on" then
                    if object:getContainerByType("geladeira_desligada") ~= nil then
                        object:getContainerByType("geladeira_desligada"):setType("fridge")
                    elseif object:getContainerByType("fridge_off") ~= nil then
                        object:getContainerByType("fridge_off"):setType("fridge")
                    end
                elseif args.fridge == "off" then
                    if object:getContainerByType("fridge") ~= nil then
                        object:getContainerByType("fridge"):setType("geladeira_desligada")
                    end
                end

                if args.freezer == "on" then
                    if object:getContainerByType("congelador_desligado") ~= nil then
                        object:getContainerByType("congelador_desligado"):setType("freezer")
                    elseif object:getContainerByType("freezer_off") ~= nil then
                        object:getContainerByType("freezer_off"):setType("freezer")
                    end
                elseif args.freezer == "off" then
                    if object:getContainerByType("freezer") ~= nil then
                        object:getContainerByType("freezer"):setType("congelador_desligado")
                    end
                end

                -- Força a atualização do gerador no mapa
                IsoGenerator.updateGenerator(object:getSquare())

                -- Recalcula se o objeto tem eletricidade após a transição
                object:checkHaveElectricity()

                local playerData = getPlayerData(getPlayer():getPlayerNum())
                if playerData ~= nil then
                    playerData.playerInventory:refreshBackpacks()
                    playerData.lootInventory:refreshBackpacks()
                end
            end
        else
            customPrint(getText("IGUI_LKS_EletricidadeConstrucao_Debug_DesyncObject") or "Não foi possível encontrar nenhum objeto neste quadrado, provável dessincronização")
        end
    end
end

-- ============================================================================
-- ⚙️ REGISTRO E CYCLE DE INICIALIZAÇÃO DO DRIVER
-- ============================================================================

-- Registro dinâmico no Appliance Manager
table.insert(LKS_ApplianceManager.devices, LKS_Device_Refrigeration)
for _, tipo in ipairs(LKS_Device_Refrigeration.recipientesAceitos) do
    LKS_ApplianceManager.containerTypeMap[tipo] = LKS_Device_Refrigeration
end

-- Garante suporte e retrocompatibilidade de texturas na tabela global
local function registrarTexturasGlobais()
    local texFridge = ContainerButtonIcons.fridge or getTexture("media/ui/Container_Fridge.png")
    local texFreezer = ContainerButtonIcons.freezer or getTexture("media/ui/Container_Freezer.png")
    ContainerButtonIcons.geladeira_desligada = texFridge
    ContainerButtonIcons.congelador_desligado = texFreezer
    ContainerButtonIcons.fridge_off = texFridge
    ContainerButtonIcons.freezer_off = texFreezer
end

Events.OnGameBoot.Add(registrarTexturasGlobais)
Events.OnServerCommand.Add(onServerCommand)

print("[LKS PATCH - LKS_Device_Refrigeration.lua] Carregado com sucesso!")
