-- ============================================================================
-- 🌟 LKS SUPERMOD PATCH — CRÉDITOS & AGRADECIMENTOS 🌟
-- ============================================================================
-- 💖 Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- 🛠️ Mod Original: Light My Fire (ID Workshop: 3575007347)
-- 👤 Autor Original: Eurymachus
-- 🌐 Link: https://steamcommunity.com/sharedfiles/filedetails/?id=3575007347
--
-- Este mod só é possível graças a todos os modders que vieram antes de mim.
-- Um agradecimento especial ao autor por sua contribuição incrível à comunidade!
-- ============================================================================
-- ARQUIVO: LKS_Menu_Fire_FuelSolid_Patch.lua
-- EXTENSÃO: LKS SuperMod Patch (Patch de Combustível)
-- OBJETIVO: Substitui ISCampingMenu.doAddFuelOption com handlers próprios que
--           não dependem da variável local fuelItemList do ISCampingMenu.lua.
--           Adiciona opções intermediárias (Metade) e ícone no Tudo.
-- VERSÃO: 2.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 20/06/2026
-- ============================================================================

require "Camping/ISCampingMenu"
require "TimedActions/ISTimedActionQueue"

-- ============================================================================
-- HELPERS
-- ============================================================================

--- Comparador de itens por nome para ordenação (replica vanilla).
--- @param itemA InventoryItem Primeiro item.
--- @param itemB InventoryItem Segundo item.
--- @return boolean resultado True se A vem antes de B.
local function compararItensPorNome(itemA, itemB)
    return not string.sort(itemA:getDisplayName(), itemB:getDisplayName())
end

-- ============================================================================
-- HANDLERS DE COMBUSTÍVEL (sem dependência da var local fuelItemList do vanilla)
-- ============================================================================

--- Adiciona múltiplos itens de um tipo como combustível.
--- Replica addFuel + onAddMultipleFuel vanilla sem usar fuelItemList compartilhada.
---
--- @param jogador IsoPlayer O jogador.
--- @param alvo table O alvo (campfire/tile).
--- @param tipoCombustivel string O fullType dos itens.
--- @param acaoTemporizada ISBaseTimedAction A timed action.
--- @param combustivelAtual number Combustível atual.
--- @param limiteQuantidade number|nil Máximo de itens.
function ISCampingMenu.LKS_onAddMultipleFuel(jogador, alvo, tipoCombustivel, acaoTemporizada, combustivelAtual, limiteQuantidade)
    local containers = ISInventoryPaneContextMenu.getContainers(jogador)
    local listaItens = ArrayList.new()
    for indice = 1, containers:size() do
        local container = containers:get(indice - 1)
        container:getAllTypeEval(tipoCombustivel, ISCampingMenu.isValidFuel, listaItens)
    end

    if listaItens:isEmpty() then return end
    local maximo = listaItens:size()
    if limiteQuantidade then maximo = limiteQuantidade end

    local itensFinal = ArrayList.new()
    for indice = 1, maximo do
        itensFinal:add(listaItens:get(indice - 1))
    end

    ISCampingMenu.toPlayerInventory(jogador, itensFinal)
    if not ISCampingMenu.walkToCampfire(jogador, alvo:getSquare()) then return end

    for indice = 1, maximo do
        local itemCombustivel = itensFinal:get(indice - 1)
        if jogador:isEquipped(itemCombustivel) then
            ISTimedActionQueue.add(ISUnequipAction:new(jogador, itemCombustivel, 50))
        end
        local duracaoItem = ISCampingMenu.getFuelDurationForItem(itemCombustivel)
        for uso = 1, ISCampingMenu.getFuelItemUses(itemCombustivel) do
            if (combustivelAtual + (duracaoItem * uso)) > getCampingFuelMax() then return end
            ISTimedActionQueue.add(acaoTemporizada:new(jogador, alvo, itemCombustivel, duracaoItem))
        end
    end
end

--- Adiciona TODOS os itens de combustível disponíveis.
--- Replica onAddAllFuel vanilla sem usar fuelItemList compartilhada.
---
--- @param jogador IsoPlayer O jogador.
--- @param alvo table O alvo (campfire/tile).
--- @param acaoTemporizada ISBaseTimedAction A timed action.
--- @param combustivelAtual number Combustível atual.
function ISCampingMenu.LKS_onAddAllFuel(jogador, alvo, acaoTemporizada, combustivelAtual)
    local containers = ISInventoryPaneContextMenu.getContainers(jogador)
    local listaItens = ArrayList.new()
    for indice = 1, containers:size() do
        local container = containers:get(indice - 1)
        container:getAllEval(ISCampingMenu.isValidFuel, listaItens)
    end

    if listaItens:isEmpty() then return end
    local maximo = listaItens:size()

    local itensFinal = ArrayList.new()
    for indice = 1, maximo do
        itensFinal:add(listaItens:get(indice - 1))
    end

    ISCampingMenu.toPlayerInventory(jogador, itensFinal)
    if not ISCampingMenu.walkToCampfire(jogador, alvo:getSquare()) then return end

    for indice = 1, maximo do
        local itemCombustivel = itensFinal:get(indice - 1)
        if jogador:isEquipped(itemCombustivel) then
            ISTimedActionQueue.add(ISUnequipAction:new(jogador, itemCombustivel, 50))
        end
        local duracaoItem = ISCampingMenu.getFuelDurationForItem(itemCombustivel)
        for uso = 1, ISCampingMenu.getFuelItemUses(itemCombustivel) do
            if (combustivelAtual + (duracaoItem * uso)) > getCampingFuelMax() then return end
            ISTimedActionQueue.add(acaoTemporizada:new(jogador, alvo, itemCombustivel, duracaoItem))
        end
    end
end

-- ============================================================================
-- PATCH DO doAddFuelOption (UI melhorada + handlers sem fuelItemList)
-- ============================================================================

---@diagnostic disable-next-line: duplicate-set-field
function ISCampingMenu.doAddFuelOption(contexto, objetosMundo, combustivelAtual, infosCombustivel, alvo, acaoTemporizada, jogador)
    local opcao = contexto:addOption(campingText.addFuel, objetosMundo, nil)
    if combustivelAtual >= getCampingFuelMax() then
        opcao.notAvailable = true
        opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
        opcao.toolTip.description = getText("ContextMenu_Fuel_Full")
        return false
    end

    if table.isempty(infosCombustivel.fuelList) then
        opcao.notAvailable = true
        opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
        opcao.toolTip.description = getText("ContextMenu_No_Fuel")
        return false
    end

    local submenuCombustivel = ISContextMenu:getNew(contexto)
    contexto:addSubMenu(opcao, submenuCombustivel)

    -- Opção "Tudo" global (aparece com 1+ materiais)
    local totalItens = 0
    local duracaoTotal = 0
    for _, item in ipairs(infosCombustivel.fuelList) do
        local quantidade = infosCombustivel.itemCount[item:getName()]
        duracaoTotal = duracaoTotal + (ISCampingMenu.getFuelDurationForItem(item) or 0.0) * quantidade
        totalItens = totalItens + quantidade
    end
    if totalItens > 1 then
        opcao = submenuCombustivel:addActionsOption(getText("ContextMenu_AllWithCount", totalItens), ISCampingMenu.LKS_onAddAllFuel, alvo, acaoTemporizada, combustivelAtual)
        opcao.iconTexture = getTexture("media/ui/LKS_Heat_On.png")
        opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
        opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(duracaoTotal))
        if (combustivelAtual + duracaoTotal) > getCampingFuelMax() then
            opcao.notAvailable = true
            opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
        end
    end

    table.sort(infosCombustivel.fuelList, compararItensPorNome)

    for _, item in ipairs(infosCombustivel.fuelList) do
        local rotulo = item:getName()
        local quantidade = infosCombustivel.itemCount[item:getName()]
        local quantidadeOriginal = quantidade
        local todoCabe = true

        while (combustivelAtual + (ISCampingMenu.getFuelDurationForItem(item) * quantidade)) > getCampingFuelMax() and quantidade > 1 do
            quantidade = quantidade - 1
            todoCabe = false
        end

        if quantidade > 1 then
            rotulo = rotulo .. ' (' .. quantidadeOriginal .. ')'
            local subMenu = contexto:getNew(submenuCombustivel)
            opcao = submenuCombustivel:addOption(rotulo)
            opcao.itemForTexture = item
            submenuCombustivel:addSubMenu(opcao, subMenu)

            -- Um (1)
            opcao = subMenu:addActionsOption(getText("ContextMenu_One") .. " (1)", ISCampingMenu.onAddFuel, alvo, item:getFullType(), acaoTemporizada, combustivelAtual)
            opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(ISCampingMenu.getFuelDurationForItem(item)))
            if (combustivelAtual + ISCampingMenu.getFuelDurationForItem(item)) > getCampingFuelMax() then
                opcao.notAvailable = true
                opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
                opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
            end

            -- Metade (N)
            local metade = math.floor(quantidade / 2)
            if metade >= 2 then
                local duracaoMetade = ISCampingMenu.getFuelDurationForItem(item) * metade
                opcao = subMenu:addActionsOption(getText("ContextMenu_Half") .. " (" .. metade .. ")", ISCampingMenu.LKS_onAddMultipleFuel, alvo, item:getFullType(), acaoTemporizada, combustivelAtual, metade)
                opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
                opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(duracaoMetade))
                if (combustivelAtual + duracaoMetade) > getCampingFuelMax() then
                    opcao.notAvailable = true
                    opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
                    opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
                end
            end

            -- Tudo (N)
            if todoCabe then
                opcao = subMenu:addActionsOption(getText("ContextMenu_AllWithCount", quantidade), ISCampingMenu.LKS_onAddMultipleFuel, alvo, item:getFullType(), acaoTemporizada, combustivelAtual)
            else
                opcao = subMenu:addActionsOption(getText("ContextMenu_AllThatFitsWithCount", quantidade), ISCampingMenu.LKS_onAddMultipleFuel, alvo, item:getFullType(), acaoTemporizada, combustivelAtual, quantidade)
            end

            opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(ISCampingMenu.getFuelDurationForItem(item) * quantidade))
            if (combustivelAtual + (ISCampingMenu.getFuelDurationForItem(item) * quantidade)) > getCampingFuelMax() then
                opcao.notAvailable = true
                opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
                opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
            end
        else
            -- Entrada única (vanilla por tipo)
            opcao = submenuCombustivel:addActionsOption(rotulo, ISCampingMenu.onAddFuel, alvo, item:getFullType(), acaoTemporizada, combustivelAtual)
            opcao.itemForTexture = item
            opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(ISCampingMenu.getFuelDurationForItem(item)))
            if (combustivelAtual + ISCampingMenu.getFuelDurationForItem(item)) > getCampingFuelMax() then
                opcao.notAvailable = true
                opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
                opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
            end
        end
    end

    return true
end

print("[LKS PATCH - LKS_Menu_Fire_FuelSolid_Patch.lua] Patch de combustivel carregado")
