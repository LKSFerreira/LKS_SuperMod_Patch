-- ============================================================================
-- ARQUIVO: LKS_Device_Cooking_Antigo.lua
-- EXTENSÃO: LKS SuperMod Patch (Módulo Fogão Antigo / Lenha)
-- OBJETIVO: Lógica dedicada para fogões a lenha (IsoFireplace). Gerencia
--           verificação de combustível sólido, ignição via fonte de calor +
--           material inflamável, e apagamento usando APIs nativas do fireplace.
--           NÃO usa addGeneratorPos nem ISToggleStoveAction — essas são
--           exclusivas do fogão convencional (propano).
-- AUTOR: LKS FERREIRA
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 19/06/2026
-- ============================================================================

local LKS_Device_Cooking_Antigo = {}

-- ============================================================================
-- VERIFICAÇÃO DE COMBUSTÍVEL SÓLIDO
-- ============================================================================

--- Verifica se um item individual serve como combustível sólido.
---
--- Reaproveita o mecanismo vanilla: tag IS_FIRE_FUEL ou FireFuelRatio > 0.
--- Ref: ISCampingMenu.isValidFuel() em camping_fuel.lua.
---
--- @param item InventoryItem O item a verificar.
--- @return boolean ehCombustivel True se o item é combustível válido.
local function ehItemCombustivel(item)
    if not item then return false end
    if item:hasTag(ItemTag.IS_FIRE_FUEL) then return true end
    if item.getFireFuelRatio and item:getFireFuelRatio() > 0 then return true end
    return false
end

--- Verifica se o IsoFireplace possui combustível sólido carregado.
---
--- Usa o mesmo critério do vanilla (tag IS_FIRE_FUEL ou FireFuelRatio > 0)
--- para aceitar qualquer item que o engine considere combustível.
--- Ref: docs/pesquisa_fogoes_fase1.md seção 4.
---
--- @param fireplace IsoObject O objeto IsoFireplace no mundo.
--- @return boolean temCombustivel True se há combustível disponível.
--- @return number quantidadeItens Quantidade de itens combustíveis encontrados.
local function verificarCombustivelSolido(fireplace)
    if not fireplace then return false, 0 end

    local container = fireplace:getContainer()
    if not container then return false, 0 end

    local quantidadeTotal = 0
    local itens = container:getItems()
    if not itens then return false, 0 end

    for idx = 0, itens:size() - 1 do
        local item = itens:get(idx)
        if ehItemCombustivel(item) then
            quantidadeTotal = quantidadeTotal + 1
        end
    end

    return quantidadeTotal > 0, quantidadeTotal
end

-- ============================================================================
-- ACENDER / APAGAR FOGÃO A LENHA
-- ============================================================================

--- Acende o fogão a lenha usando a mecânica nativa do IsoFireplace.
---
--- Diferente do fogão convencional que usa addGeneratorPos + ISToggleStoveAction,
--- o fogão antigo usa setActivated(true) diretamente — o engine Java do
--- IsoFireplace gerencia internamente a fumaça, brasa e consumo de combustível.
---
--- @param fireplace IsoObject O IsoFireplace a acender.
--- @param jogador IsoPlayer O jogador que está acendendo.
local function acenderFogaoAntigo(fireplace, jogador)
    if not fireplace or not jogador then return end
    if not instanceof(fireplace, "IsoFireplace") then return end

    local temCombustivel = verificarCombustivelSolido(fireplace)
    if not temCombustivel then return end

    -- IsoFireplace vanilla: setActivated(true) inicia combustão com efeitos nativos
    fireplace:setActivated(true)
    fireplace:getModData().LKS_FogaoAntigoAceso = true
end

--- Apaga o fogão a lenha usando a mecânica nativa do IsoFireplace.
---
--- @param fireplace IsoObject O IsoFireplace a apagar.
local function apagarFogaoAntigo(fireplace)
    if not fireplace then return end
    if not instanceof(fireplace, "IsoFireplace") then return end

    fireplace:setActivated(false)
    fireplace:getModData().LKS_FogaoAntigoAceso = nil
end

-- ============================================================================
-- VERIFICAÇÃO DE FONTE DE ENERGIA PARA FOGÃO ANTIGO
-- ============================================================================

--- Verifica se o fogão antigo tem combustível disponível para funcionar.
---
--- Substitui o retorno incondicional `disponivel = true` que existia
--- em LKS_Cooking_PropanoSystem.verificarFonteEnergia para tipo "antigo".
---
--- @param fireplace IsoObject O IsoFireplace.
--- @return table Resultado compatível com LKS_FonteEnergiaResultado.
function LKS_Device_Cooking_Antigo.verificarFonteEnergia(fireplace)
    local resultado = {
        tipo = "combustivel_solido",
        disponivel = false,
        requerIgnicaoManual = true,
        temIgnicaoManual = false,
        nomeFonteCalor = nil,
    }

    if not fireplace then return resultado end

    local temCombustivel = verificarCombustivelSolido(fireplace)
    resultado.disponivel = temCombustivel

    return resultado
end

-- ============================================================================
-- CONSTRUÇÃO DO SUBMENU DE IGNIÇÃO DO FOGÃO ANTIGO
-- ============================================================================

--- Constrói o submenu de acender/apagar específico do fogão a lenha.
---
--- Hierarquia: "Acender" > [fonte de calor] > [material inflamável]
--- O material inflamável é consumido na ignição; o combustível sólido no container
--- é consumido ao longo do tempo pelo engine vanilla.
---
--- @param submenu ISContextMenu O submenu do aparelho (já criado pelo facade).
--- @param fireplace IsoObject O IsoFireplace.
--- @param jogador IsoPlayer O jogador.
--- @param objetosMundo table Referência dos objetos do mundo (param vanilla).
--- @param fontesCalor table Lista de itens fonte de calor do inventário.
--- @param materiaisCombustao table Lista de itens inflamáveis do inventário.
function LKS_Device_Cooking_Antigo.construirSubmenuIgnicao(submenu, fireplace, jogador, objetosMundo, fontesCalor, materiaisCombustao)
    if not submenu or not fireplace or not jogador then return end

    local estaAtivo = fireplace.isActivated and fireplace:isActivated()
        or (fireplace.Activated and fireplace:Activated())
        or false

    local verboAcender = getText("IGUI_LKS_Acender") or "Acender"
    local verboApagar = getText("IGUI_LKS_Apagar") or "Apagar"

    if estaAtivo then
        local opcaoApagar = submenu:addOptionOnTop(verboApagar, objetosMundo, function()
            apagarFogaoAntigo(fireplace)
        end)
        opcaoApagar.iconTexture = getTexture("media/ui/LKS_Button_Power_Off.png")
        return
    end

    -- Verificar combustível no interior
    local temCombustivel = verificarCombustivelSolido(fireplace)
    if not temCombustivel then
        local opcaoSemCombustivel = submenu:addOptionOnTop(verboAcender, objetosMundo, nil)
        opcaoSemCombustivel.notAvailable = true
        opcaoSemCombustivel.iconTexture = getTexture("media/ui/LKS_Menu_Fuel_Off.png")
        local tooltipSemCombustivel = ISWorldObjectContextMenu.addToolTip()
        tooltipSemCombustivel.description = getText("IGUI_LKS_RequerCombustivelSolido")
            or "Requer combustível sólido (lenha, tábuas) no interior."
        opcaoSemCombustivel.toolTip = tooltipSemCombustivel
        return
    end

    -- Sem fontes de calor no inventário
    if #fontesCalor == 0 then
        local opcaoSemCalor = submenu:addOptionOnTop(verboAcender, objetosMundo, nil)
        opcaoSemCalor.notAvailable = true
        opcaoSemCalor.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")
        local tooltipSemCalor = ISWorldObjectContextMenu.addToolTip()
        tooltipSemCalor.description = getText("IGUI_LKS_RequerFonteCalor")
            or "Requer uma fonte de calor (isqueiro, fósforos, etc.) para acender."
        opcaoSemCalor.toolTip = tooltipSemCalor
        return
    end

    -- Fonte de calor disponível: submenu de ignição
    local opcaoAcender = submenu:addOptionOnTop(verboAcender, objetosMundo, nil)
    opcaoAcender.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")
    local submenuIgnicao = ISContextMenu:getNew(submenu)
    submenu:addSubMenu(opcaoAcender, submenuIgnicao)

    -- Sem material inflamável: fontes de calor desabilitadas com tooltip
    if #materiaisCombustao == 0 then
        local tooltipPaiSemTinder = ISWorldObjectContextMenu.addToolTip()
        tooltipPaiSemTinder.description = getText("IGUI_LKS_RequerMaterialInflamavel")
            or "Requer material inflamável (papel, pano, álcool) para iniciar a combustão."
        opcaoAcender.toolTip = tooltipPaiSemTinder

        for _, fonteCalorItem in ipairs(fontesCalor) do
            local opcaoFonte = submenuIgnicao:addOption(
                fonteCalorItem:getDisplayName(), objetosMundo, nil)
            opcaoFonte.iconTexture = fonteCalorItem:getTex()
            opcaoFonte.notAvailable = true
            local tooltipFonte = ISWorldObjectContextMenu.addToolTip()
            tooltipFonte.description = getText("IGUI_LKS_RequerMaterialInflamavel")
                or "Requer material inflamável (papel, pano, álcool) para iniciar a combustão."
            opcaoFonte.toolTip = tooltipFonte
        end
        return
    end

    -- Completo: fonte de calor > submenu de materiais inflamáveis
    for _, fonteCalorItem in ipairs(fontesCalor) do
        local opcaoFonte = submenuIgnicao:addOption(
            fonteCalorItem:getDisplayName(), objetosMundo, nil)
        opcaoFonte.iconTexture = fonteCalorItem:getTex()
        local submenuTinder = ISContextMenu:getNew(submenuIgnicao)
        submenuIgnicao:addSubMenu(opcaoFonte, submenuTinder)

        for _, materialItem in ipairs(materiaisCombustao) do
            local opcaoMaterial = submenuTinder:addOption(
                materialItem:getDisplayName(), objetosMundo, function()
                    acenderFogaoAntigo(fireplace, jogador)
                end)
            opcaoMaterial.iconTexture = materialItem:getTex()
        end
    end
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================

LKS_Device_Cooking_Antigo.acenderFogaoAntigo = acenderFogaoAntigo
LKS_Device_Cooking_Antigo.apagarFogaoAntigo = apagarFogaoAntigo
LKS_Device_Cooking_Antigo.verificarCombustivelSolido = verificarCombustivelSolido

return LKS_Device_Cooking_Antigo
