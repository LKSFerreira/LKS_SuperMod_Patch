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
-- ARQUIVO: LKS_FireMenu_FuelPatch.lua
-- EXTENSÃO: LKS SuperMod Patch (Patch de Combustível por ID)
-- OBJETIVO: Corrige bug vanilla onde a seleção de combustível por referência
--           direta causa consumo do item errado quando há duplicatas.
--           Substitui ISCampingMenu.doAddFuelOption para resolver items por ID.
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 20/06/2026
-- ============================================================================

require "Camping/ISCampingMenu"
require "TimedActions/ISTimedActionQueue"

-- ============================================================================
-- HELPERS
-- ============================================================================

--- Converte valor para número de forma segura.
--- @param valor any Valor a converter.
--- @return number|nil numero O número, ou nil se impossível.
local function paraNumero(valor)
    if valor == nil then return nil end
    if type(valor) == "number" then return valor end
    return tonumber(valor)
end

--- Obtém os containers acessíveis do jogador.
--- @param jogador IsoPlayer O jogador.
--- @return ArrayList|nil containers Lista de containers.
local function obterContainersJogador(jogador)
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getContainers then
        return ISInventoryPaneContextMenu.getContainers(jogador)
    end
    return nil
end

--- Busca um item específico por ID em todos os containers do jogador.
--- @param containers ArrayList Lista de containers.
--- @param idItem number ID do item a buscar.
--- @return InventoryItem|nil item O item encontrado, ou nil.
local function buscarItemPorId(containers, idItem)
    if not containers or idItem == nil then return nil end
    for indice = 0, containers:size() - 1 do
        local container = containers:get(indice)
        if container and container.getItemById then
            local item = container:getItemById(idItem)
            if item then return item end
        end
    end
    return nil
end

--- Monta lista de IDs de itens que correspondem ao mesmo fullType e nome do item representativo.
--- @param jogador IsoPlayer O jogador.
--- @param itemRepresentativo InventoryItem O item usado como representante no menu.
--- @return table listaIds Lista de IDs numéricos.
local function montarListaIdsPorEntrada(jogador, itemRepresentativo)
    if not jogador or not itemRepresentativo then return {} end

    local containers = obterContainersJogador(jogador)
    if not containers then return {} end

    local tipoRepresentativo = itemRepresentativo:getFullType()
    local nomeRepresentativo = itemRepresentativo:getName()

    local listaIds = {}
    local listaTemporaria = ArrayList.new()

    for indice = 0, containers:size() - 1 do
        local container = containers:get(indice)
        if container and container.getAllTypeEval then
            container:getAllTypeEval(tipoRepresentativo, ISCampingMenu.isValidFuel, listaTemporaria)

            for indiceItem = 0, listaTemporaria:size() - 1 do
                local item = listaTemporaria:get(indiceItem)
                if item and item.getName and item:getName() == nomeRepresentativo then
                    local id = item.getID and item:getID()
                    if id then
                        listaIds[#listaIds + 1] = id
                    end
                end
            end

            listaTemporaria:clear()
        end
    end

    return listaIds
end

--- Comparador de itens por nome para ordenação (replica vanilla).
--- @param itemA InventoryItem Primeiro item.
--- @param itemB InventoryItem Segundo item.
--- @return boolean resultado True se A vem antes de B.
local function compararItensPorNome(itemA, itemB)
    return not string.sort(itemA:getDisplayName(), itemB:getDisplayName())
end

-- ============================================================================
-- HANDLERS DE COMBUSTÍVEL POR ID
-- ============================================================================

--- Adiciona um único item de combustível identificado por ID.
---
--- @param jogador IsoPlayer O jogador.
--- @param alvo table O alvo (campfire/tile).
--- @param idItem number ID do item de combustível.
--- @param acaoTemporizada ISBaseTimedAction A timed action a executar.
--- @param combustivelAtual number Combustível atual no alvo.
function ISCampingMenu.onAddFuelById(jogador, alvo, idItem, acaoTemporizada, combustivelAtual)
    local id = paraNumero(idItem)
    if not id then return end
    if not acaoTemporizada then return end

    local containers = obterContainersJogador(jogador)
    if not containers then return end

    local itemCombustivel = buscarItemPorId(containers, id)
    if not itemCombustivel then return end

    if not ISCampingMenu.isValidFuel(itemCombustivel) then return end

    local quantidadeCombustivel = ISCampingMenu.getFuelDurationForItem(itemCombustivel)

    ISCampingMenu.toPlayerInventory(jogador, itemCombustivel)
    if not ISCampingMenu.walkToCampfire(jogador, alvo:getSquare()) then return end

    ISTimedActionQueue.add(acaoTemporizada:new(jogador, alvo, itemCombustivel, quantidadeCombustivel))
end

--- Adiciona múltiplos itens de combustível identificados por lista de IDs.
---
--- @param jogador IsoPlayer O jogador.
--- @param alvo table O alvo (campfire/tile).
--- @param listaIds table Lista de IDs numéricos.
--- @param acaoTemporizada ISBaseTimedAction A timed action a executar.
--- @param combustivelAtual number Combustível atual no alvo.
--- @param limiteQuantidade number|nil Máximo de itens a adicionar.
function ISCampingMenu.onAddMultipleFuelByIds(jogador, alvo, listaIds, acaoTemporizada, combustivelAtual, limiteQuantidade)
    if type(listaIds) ~= "table" or not jogador then return end
    if not acaoTemporizada then return end

    local containers = obterContainersJogador(jogador)
    if not containers then return end

    local maximoItens = paraNumero(limiteQuantidade)
    local maximoCombustivel = getCampingFuelMax()

    local itensValidos = ArrayList.new()
    local adicionados = 0

    for _, idCru in ipairs(listaIds) do
        if maximoItens and adicionados >= maximoItens then break end

        local id = paraNumero(idCru)
        if id then
            local item = buscarItemPorId(containers, id)
            if item and ISCampingMenu.isValidFuel(item) then
                itensValidos:add(item)
                adicionados = adicionados + 1
            end
        end
    end

    if itensValidos:isEmpty() then return end

    ISCampingMenu.toPlayerInventory(jogador, itensValidos)
    if not ISCampingMenu.walkToCampfire(jogador, alvo:getSquare()) then return end

    for indice = 0, itensValidos:size() - 1 do
        local itemCombustivel = itensValidos:get(indice)
        local quantidadeCombustivel = ISCampingMenu.getFuelDurationForItem(itemCombustivel)

        local usos = ISCampingMenu.getFuelItemUses(itemCombustivel)
        for uso = 1, usos do
            if (combustivelAtual + (quantidadeCombustivel * uso)) > maximoCombustivel then
                return
            end
            ISTimedActionQueue.add(acaoTemporizada:new(jogador, alvo, itemCombustivel, quantidadeCombustivel))
        end

        combustivelAtual = combustivelAtual + (quantidadeCombustivel * usos)
    end
end

-- ============================================================================
-- PATCH DO doAddFuelOption (UI preservada, callbacks substituídos por ID)
-- ============================================================================

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
        opcao.notAvailable = true
    end

    local submenuCombustivel = ISContextMenu:getNew(contexto)
    contexto:addSubMenu(opcao, submenuCombustivel)

    -- Opção "Tudo" quando há mais de 1 tipo de combustível
    if #infosCombustivel.fuelList > 1 then
        local totalItens = 0
        local duracaoTotal = 0
        for _, item in ipairs(infosCombustivel.fuelList) do
            local quantidade = infosCombustivel.itemCount[item:getName()]
            duracaoTotal = duracaoTotal + (ISCampingMenu.getFuelDurationForItem(item) or 0.0) * quantidade
            totalItens = totalItens + quantidade
        end
        if totalItens > 1 then
            opcao = submenuCombustivel:addActionsOption(getText("ContextMenu_AllWithCount", totalItens), ISCampingMenu.onAddAllFuel, alvo, acaoTemporizada, combustivelAtual)
            opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(duracaoTotal))
            if (combustivelAtual + duracaoTotal) > getCampingFuelMax() then
                opcao.notAvailable = true
                opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
                opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
            end
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

            -- Um (por ID)
            opcao = subMenu:addActionsOption(getText("ContextMenu_One"), ISCampingMenu.onAddFuelById, alvo, item:getID(), acaoTemporizada, combustivelAtual)
            opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(ISCampingMenu.getFuelDurationForItem(item)))
            if (combustivelAtual + ISCampingMenu.getFuelDurationForItem(item)) > getCampingFuelMax() then
                opcao.notAvailable = true
                opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
                opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
            end

            -- Tudo (lista de IDs)
            local listaIds = montarListaIdsPorEntrada(jogador, item)

            if todoCabe then
                opcao = subMenu:addActionsOption(getText("ContextMenu_AllWithCount", quantidade), ISCampingMenu.onAddMultipleFuelByIds, alvo, listaIds, acaoTemporizada, combustivelAtual)
            else
                opcao = subMenu:addActionsOption(getText("ContextMenu_AllThatFitsWithCount", quantidade), ISCampingMenu.onAddMultipleFuelByIds, alvo, listaIds, acaoTemporizada, combustivelAtual, quantidade)
            end

            opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(ISCampingMenu.getFuelDurationForItem(item) * quantidade))
            if (combustivelAtual + (ISCampingMenu.getFuelDurationForItem(item) * quantidade)) > getCampingFuelMax() then
                opcao.notAvailable = true
                opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
                opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
            end
        else
            -- Entrada única (por ID)
            opcao = submenuCombustivel:addActionsOption(rotulo, ISCampingMenu.onAddFuelById, alvo, item:getID(), acaoTemporizada, combustivelAtual)
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

print("[LKS PATCH - LKS_FireMenu_FuelPatch.lua] Patch de combustivel por ID carregado")
