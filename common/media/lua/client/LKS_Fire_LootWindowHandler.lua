-- ============================================================================
-- ARQUIVO: LKS_Fire_LootWindowHandler.lua
-- EXTENSAO: LKS SuperMod Patch (Handler de Combustivel na Loot Window)
-- OBJETIVO: Substitui o handler vanilla AddFuelOption na Loot Window por
--           mecanica propria: processa itens que ja estao DENTRO do container
--           de fogo via TimedAction (andar, agachar, converter).
-- AUTOR: LKS FERREIRA
-- VERSAO: 1.0 (Project Zomboid Build 42)
-- DATA DA ULTIMA MODIFICACAO: 24/06/2026
-- ============================================================================

require "ISUI/LootWindow/ISLootWindowObjectControlHandler"
require "Camping/ISCampingMenu"
require "cooking/LKS_Fire_FuelClassifier"

-- ============================================================================
-- HANDLER: TRANSFORMAR EM COMBUSTIVEL (Loot Window)
-- ============================================================================

LKS_LootWindowHandler_TransformarCombustivel = ISLootWindowObjectControlHandler:derive("LKS_LootWindowHandler_TransformarCombustivel")
local Handler = LKS_LootWindowHandler_TransformarCombustivel

--- Verifica se o botao deve ser visivel.
--- Visivel quando o container eh um meio de fogo com combustivel solido.
---
--- @return boolean visivel True se deve mostrar o botao.
function Handler:shouldBeVisible()
    if not self.object then return false end

    -- Fogueira (CCampfireSystem)
    if CCampfireSystem.instance:isValidIsoObject(self.object) then
        local fogueira = CCampfireSystem.instance:getLuaObjectOnSquare(self.object:getSquare())
        if fogueira then return true end
        return false
    end

    -- Tiles de interacao com fogo (lareira, fogao a lenha, BBQ carvao)
    if self.object:isFireInteractionObject() and (not self.object:isPropaneBBQ()) then
        return true
    end

    return false
end

--- Retorna o controle (botao) do handler.
---
--- @return ISButton controle O botao na barra de controles.
function Handler:getControl()
    self.control = self:getButtonControl(getText("ContextMenu_DestroyForFuel") or "Transformar em Combustivel")
    return self.control
end

--- Escaneia itens dentro do container do fogo e separa combustiveis de nao-combustiveis.
---
--- @return table combustiveis Lista de itens que podem virar combustivel.
--- @return table naoCombustiveis Lista de itens que NAO viram combustivel.
--- @return number duracaoTotal Duracao total estimada em minutos.
function Handler:escanearItensNoContainer()
    local combustiveis = {}
    local naoCombustiveis = {}
    local duracaoTotal = 0

    if not self.container then return combustiveis, naoCombustiveis, duracaoTotal end

    local itens = self.container:getItems()
    if not itens or itens:size() == 0 then return combustiveis, naoCombustiveis, duracaoTotal end

    for indice = itens:size() - 1, 0, -1 do
        local item = itens:get(indice)
        if item then
            -- Processar recursivamente (mochilas, bolsas dentro do container)
            if instanceof(item, "InventoryContainer") then
                LKS_ehCombustivelRecursivo(item, combustiveis, naoCombustiveis, true)
            elseif LKS_ehCombustivel(item, true) then
                table.insert(combustiveis, item)
            else
                table.insert(naoCombustiveis, item)
            end
        end
    end

    -- Calcular duracao total
    for _, item in ipairs(combustiveis) do
        duracaoTotal = duracaoTotal + LKS_calcularDuracao(item, false)
    end

    return combustiveis, naoCombustiveis, duracaoTotal
end

--- Handler para joypad.
---
--- @param context ISContextMenu O contexto do joypad.
function Handler:handleJoypadContextMenu(context)
    self:perform()
end

--- Executa a acao de transformar itens do container em combustivel.
--- Enfileira: andar ate o container -> agachar -> TimedAction por item.
function Handler:perform()
    if isGamePaused() then return end
    if not self.object or not self.container then return end

    local combustiveis, naoCombustiveis, duracaoTotal = self:escanearItensNoContainer()

    if #combustiveis == 0 then
        self.playerObj:Say(getText("IGUI_LKS_SemItensParaConverter") or "Nao tem nada aqui que de para queimar...")
        return
    end

    -- Determinar alvo (campfire ou IsoFireplace)
    local fogueira = CCampfireSystem.instance:getLuaObjectOnSquare(self.object:getSquare())
    local alvo = fogueira or self.object
    local combustivelAtual = 0

    if fogueira then
        combustivelAtual = fogueira.fuelAmt or 0
    elseif self.object.getFuelAmount then
        combustivelAtual = self.object:getFuelAmount()
    end

    -- Verificar se o fogo esta cheio
    if combustivelAtual >= getCampingFuelMax() then
        self.playerObj:Say(getText("ContextMenu_Fuel_Full") or "Ja esta cheio de combustivel.")
        return
    end

    -- Andar ate o container
    local quadrado = self.object:getSquare()
    if not quadrado then return end

    if not ISCampingMenu.walkToCampfire(self.playerObj, quadrado) then
        self.playerObj:Say(getText("IGUI_LKS_CaminhoInacessivel") or "Nao consigo chegar la...")
        return
    end

    -- Determinar acao temporizada correta
    local acaoTemporizada
    if fogueira then
        acaoTemporizada = ISAddFuelAction
    else
        acaoTemporizada = rawget(_G, "ISBBQAddFuel") or ISAddFuelAction
    end

    -- Enfileirar conversao de cada item combustivel
    local itensConvertidos = 0
    for _, item in ipairs(combustiveis) do
        if (combustivelAtual + LKS_calcularDuracao(item, false)) > getCampingFuelMax() then
            break
        end

        -- Desequipar se necessario (nao deve acontecer dentro de container, mas por seguranca)
        if self.playerObj:isEquipped(item) then
            ISTimedActionQueue.add(ISUnequipAction:new(self.playerObj, item, 50))
        end

        -- Transferir para inventario do jogador primeiro (necessario para as timed actions vanilla)
        ISCampingMenu.toPlayerInventory(self.playerObj, item)

        local duracaoItem = LKS_calcularDuracao(item, false)
        for uso = 1, ISCampingMenu.getFuelItemUses(item) do
            if (combustivelAtual + (duracaoItem * uso)) > getCampingFuelMax() then break end
            ISTimedActionQueue.add(acaoTemporizada:new(self.playerObj, alvo, item, duracaoItem))
        end

        combustivelAtual = combustivelAtual + duracaoItem
        itensConvertidos = itensConvertidos + 1
    end

    if itensConvertidos > 0 then
        print("[LKS_Fire] Loot Window: " .. itensConvertidos .. " item(ns) enfileirados para conversao, "
            .. #naoCombustiveis .. " nao-combustivel(is) permanecem no container")
    end
end

--- Construtor do handler.
---
--- @return table instancia Nova instancia do handler.
function Handler:new()
    local o = ISLootWindowObjectControlHandler.new(self)
    o.altColor = true
    return o
end

-- ============================================================================
-- REGISTRO DO HANDLER
-- ============================================================================

-- Registrar como handler da Loot Window (substitui o vanilla AddFuelOption)
-- displayToRight = true para alinhar a direita (junto com Acender/Apagar)
ISLootWindowContainerControls.AddHandler(LKS_LootWindowHandler_TransformarCombustivel, true)

-- Neutralizar handler vanilla para evitar duplicata
local handlerVanillaRef = rawget(_G, "ISLootWindowObjectControlHandler_AddFuelOption")
if handlerVanillaRef then
    handlerVanillaRef.shouldBeVisible = function() return false end
end

print("[LKS PATCH - LKS_Fire_LootWindowHandler.lua] Handler de combustivel na Loot Window carregado")
