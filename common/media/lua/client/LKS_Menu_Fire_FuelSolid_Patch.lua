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
require "cooking/LKS_Fire_FuelClassifier"

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

--- Adiciona TODOS os itens de uma CATEGORIA ESPECIFICA como combustível.
--- Filtra itens por DisplayCategory antes de enfileirar.
---
--- @param jogador IsoPlayer O jogador.
--- @param alvo table O alvo (campfire/tile).
--- @param acaoTemporizada ISBaseTimedAction A timed action.
--- @param combustivelAtual number Combustível atual.
--- @param categoriaFiltro string A categoria para filtrar (DisplayCategory).
function ISCampingMenu.LKS_onAddAllFuelByCategory(jogador, alvo, acaoTemporizada, combustivelAtual, categoriaFiltro)
    local containers = ISInventoryPaneContextMenu.getContainers(jogador)
    local listaItens = ArrayList.new()
    for indice = 1, containers:size() do
        local container = containers:get(indice - 1)
        container:getAllEval(ISCampingMenu.isValidFuel, listaItens)
    end

    if listaItens:isEmpty() then return end

    -- Filtrar por categoria
    local itensFinal = ArrayList.new()
    for indice = 1, listaItens:size() do
        local item = listaItens:get(indice - 1)
        local categoriaItem = item:getDisplayCategory() or item:getCategory() or "Other"
        if categoriaItem == categoriaFiltro then
            itensFinal:add(item)
        end
    end

    if itensFinal:isEmpty() then return end

    ISCampingMenu.toPlayerInventory(jogador, itensFinal)
    if not ISCampingMenu.walkToCampfire(jogador, alvo:getSquare()) then return end

    for indice = 1, itensFinal:size() do
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
-- PATCH DO doAddFuelOption (UI melhorada + agrupamento por categoria)
-- ============================================================================

--- Mapa de categorias do PZ para rotulos agrupados no menu.
--- @type table<string, string>
local ROTULO_CATEGORIA = {
    Clothing      = getText("IGUI_ItemCat_Clothing") or "Roupas",
    Literature    = getText("IGUI_ItemCat_Literature") or "Literatura",
    Map           = getText("IGUI_ItemCat_Cartography") or "Mapas",
    Material      = getText("IGUI_ItemCat_Material") or "Materiais",
    Camping       = getText("IGUI_ItemCat_Camping") or "Camping",
    Junk          = getText("IGUI_ItemCat_Junk") or "Diversos",
    Household     = getText("IGUI_ItemCat_Household") or "Domesticos",
    Entertainment = getText("IGUI_ItemCat_Entertainment") or "Entretenimento",
    Food          = getText("IGUI_ItemCat_Food") or "Alimentos",
    Accessory     = getText("IGUI_ItemCat_Accessory") or "Acessorios",
    Container     = getText("IGUI_ItemCat_Container") or "Containers",
    Bag           = getText("IGUI_ItemCat_Bag") or "Bolsas",
}
local ROTULO_OUTROS = getText("IGUI_LKS_GrupoOutros") or "Outros"

--- Monta as opcoes Um/Metade/Tudo para um item no submenu dado.
---
--- @param subMenu ISContextMenu O submenu onde adicionar.
--- @param contexto ISContextMenu O contexto pai (para getNew).
--- @param item InventoryItem Item representativo do tipo.
--- @param quantidade number Quantidade disponivel.
--- @param alvo table Alvo do fogo.
--- @param acaoTemporizada ISBaseTimedAction Acao temporizada.
--- @param combustivelAtual number Combustivel atual.
local function montarOpcoesQuantidade(subMenu, contexto, item, quantidade, alvo, acaoTemporizada, combustivelAtual)
    local duracaoUnitaria = ISCampingMenu.getFuelDurationForItem(item)
    if duracaoUnitaria <= 0 then
        duracaoUnitaria = LKS_calcularDuracao(item, false)
    end

    local quantidadeOriginal = quantidade
    local todoCabe = true

    while (combustivelAtual + (duracaoUnitaria * quantidade)) > getCampingFuelMax() and quantidade > 1 do
        quantidade = quantidade - 1
        todoCabe = false
    end

    if quantidade > 1 then
        local rotulo = item:getName() .. " (" .. quantidadeOriginal .. ")"
        local subSubMenu = contexto:getNew(subMenu)
        local opcao = subMenu:addOption(rotulo)
        opcao.itemForTexture = item
        subMenu:addSubMenu(opcao, subSubMenu)

        -- Um (1)
        opcao = subSubMenu:addActionsOption(getText("ContextMenu_One") .. " (1)", ISCampingMenu.onAddFuel, alvo, item:getFullType(), acaoTemporizada, combustivelAtual)
        opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
        opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(duracaoUnitaria))
        if (combustivelAtual + duracaoUnitaria) > getCampingFuelMax() then
            opcao.notAvailable = true
            opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
        end

        -- Metade (N)
        local metade = math.floor(quantidade / 2)
        if metade >= 2 then
            local duracaoMetade = duracaoUnitaria * metade
            opcao = subSubMenu:addActionsOption(getText("ContextMenu_Half") .. " (" .. metade .. ")", ISCampingMenu.LKS_onAddMultipleFuel, alvo, item:getFullType(), acaoTemporizada, combustivelAtual, metade)
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
            opcao = subSubMenu:addActionsOption(getText("ContextMenu_AllWithCount", quantidade), ISCampingMenu.LKS_onAddMultipleFuel, alvo, item:getFullType(), acaoTemporizada, combustivelAtual)
        else
            opcao = subSubMenu:addActionsOption(getText("ContextMenu_AllThatFitsWithCount", quantidade), ISCampingMenu.LKS_onAddMultipleFuel, alvo, item:getFullType(), acaoTemporizada, combustivelAtual, quantidade)
        end
        opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
        opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(duracaoUnitaria * quantidade))
        if (combustivelAtual + (duracaoUnitaria * quantidade)) > getCampingFuelMax() then
            opcao.notAvailable = true
            opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
        end
    else
        local opcao = subMenu:addActionsOption(item:getName(), ISCampingMenu.onAddFuel, alvo, item:getFullType(), acaoTemporizada, combustivelAtual)
        opcao.itemForTexture = item
        opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
        opcao.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(duracaoUnitaria))
        if (combustivelAtual + duracaoUnitaria) > getCampingFuelMax() then
            opcao.notAvailable = true
            opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcao.toolTip.description = getText("ContextMenu_Fuel_Full3")
        end
    end
end

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

    -- Calcular totais
    local totalItens = 0
    local duracaoTotal = 0
    for _, item in ipairs(infosCombustivel.fuelList) do
        local quantidade = infosCombustivel.itemCount[item:getName()]
        local duracao = ISCampingMenu.getFuelDurationForItem(item) or 0.0
        if duracao <= 0 then duracao = LKS_calcularDuracao(item, false) end
        duracaoTotal = duracaoTotal + duracao * quantidade
        totalItens = totalItens + quantidade
    end

    -- Opcao "Tudo" global
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

    local totalTipos = #infosCombustivel.fuelList

    -- Agrupamento por categoria quando >6 tipos
    if totalTipos > 6 then
        local gruposPorCategoria = {}
        local ordemCategorias = {}

        for _, item in ipairs(infosCombustivel.fuelList) do
            local categoria = item:getDisplayCategory() or item:getCategory() or "Other"
            if not gruposPorCategoria[categoria] then
                gruposPorCategoria[categoria] = {}
                table.insert(ordemCategorias, categoria)
            end
            table.insert(gruposPorCategoria[categoria], item)
        end

        for _, categoria in ipairs(ordemCategorias) do
            local itensGrupo = gruposPorCategoria[categoria]
            local rotuloCategoria = ROTULO_CATEGORIA[categoria] or ROTULO_OUTROS

            -- Contar total do grupo
            local totalGrupo = 0
            for _, item in ipairs(itensGrupo) do
                totalGrupo = totalGrupo + (infosCombustivel.itemCount[item:getName()] or 1)
            end

            if #itensGrupo == 1 then
                -- Categoria com 1 tipo: mostrar diretamente sem submenu de categoria
                local item = itensGrupo[1]
                local quantidade = infosCombustivel.itemCount[item:getName()] or 1
                montarOpcoesQuantidade(submenuCombustivel, contexto, item, quantidade, alvo, acaoTemporizada, combustivelAtual)
            else
                -- Categoria com multiplos tipos: submenu de categoria
                local rotuloCat = rotuloCategoria .. " (" .. totalGrupo .. ")"
                local opcaoCat = submenuCombustivel:addOption(rotuloCat)
                local subMenuCat = ISContextMenu:getNew(submenuCombustivel)
                submenuCombustivel:addSubMenu(opcaoCat, subMenuCat)

                -- Opcao "Todos" da categoria
                if totalGrupo > 1 then
                    local duracaoCat = 0
                    for _, item in ipairs(itensGrupo) do
                        local qtd = infosCombustivel.itemCount[item:getName()] or 1
                        local dur = ISCampingMenu.getFuelDurationForItem(item) or 0
                        if dur <= 0 then dur = LKS_calcularDuracao(item, false) end
                        duracaoCat = duracaoCat + dur * qtd
                    end

                    local opcaoTodosCat = subMenuCat:addActionsOption(
                        getText("ContextMenu_AllWithCount", totalGrupo),
                        ISCampingMenu.LKS_onAddAllFuelByCategory, alvo, acaoTemporizada, combustivelAtual, categoria)
                    opcaoTodosCat.iconTexture = getTexture("media/ui/LKS_Heat_On.png")
                    opcaoTodosCat.toolTip = ISWorldObjectContextMenu.addToolTip()
                    opcaoTodosCat.toolTip.description = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(duracaoCat))
                end

                -- Cada item da categoria
                for _, item in ipairs(itensGrupo) do
                    local quantidade = infosCombustivel.itemCount[item:getName()] or 1
                    montarOpcoesQuantidade(subMenuCat, contexto, item, quantidade, alvo, acaoTemporizada, combustivelAtual)
                end
            end
        end
    else
        -- Lista plana (<=6 tipos) - comportamento anterior
        for _, item in ipairs(infosCombustivel.fuelList) do
            local quantidade = infosCombustivel.itemCount[item:getName()] or 1
            montarOpcoesQuantidade(submenuCombustivel, contexto, item, quantidade, alvo, acaoTemporizada, combustivelAtual)
        end
    end

    return true
end

print("[LKS PATCH - LKS_Menu_Fire_FuelSolid_Patch.lua] Patch de combustivel carregado")
