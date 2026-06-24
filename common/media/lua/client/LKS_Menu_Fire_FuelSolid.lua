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
-- ARQUIVO: LKS_Menu_Fire_FuelSolid.lua
-- EXTENSÃO: LKS SuperMod Patch (Menu Unificado de Fogo)
-- OBJETIVO: Handler unificado de menu de contexto para fogueiras, lareiras,
--           fogões a lenha e churrasqueiras. Substitui ISCampingMenu.doCampingMenu
--           e ISBBQMenu.OnFillWorldObjectContextMenu por um fluxo único sem
--           duplicatas, com ícones temáticos e tooltip informativo.
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 20/06/2026
-- ============================================================================

require "Camping/ISCampingMenu"
require "cooking/LKS_Fire_FuelClassifier"

local CampingMenu = ISCampingMenu
if not CampingMenu then
    print("[LKS PATCH - LKS_Menu_Fire_FuelSolid.lua] ERRO: ISCampingMenu nao disponivel")
    return
end

-- Fix vanilla: DryFirestarterBlock é fuel mas não tinder (oversight)
if campingLightFireType and not campingLightFireType["DryFirestarterBlock"] then
    campingLightFireType["DryFirestarterBlock"] = 30/60.0
end

local referenciaHandlerOriginal = CampingMenu.doCampingMenu

local TEX_INFO = "media/ui/LKS_Info.png"

--- Mapa de tradução para nomes de tile que o vanilla não traduz em PT-BR.
local TRADUCAO_TILE_NAMES = {
    ["Cooking Pit"]        = "Braseiro",
    ["Simple Cooking Pit"] = "Braseiro Simples",
}

-- ============================================================================
-- DETECÇÃO DE TARGET DE FOGO
-- ============================================================================

--- Identifica o objeto de fogo principal no tile clicado.
---
--- Retorna tabela com tipo ("campfire" ou "tile"), referência ao objeto,
--- quantidade de combustível atual e se é propano.
---
--- @param objetosMundo table Lista de objetos no tile clicado.
--- @return table|nil informacoesAlvo Dados do alvo encontrado, ou nil.
local function encontrarAlvoFogo(objetosMundo)
    if not (objetosMundo and #objetosMundo > 0) then return nil end

    for _, objeto in ipairs(objetosMundo) do
        local quadrado = objeto and objeto.getSquare and objeto:getSquare()
        if quadrado then
            -- Fogueira vanilla (CCampfireSystem)
            local fogueira = CCampfireSystem.instance and CCampfireSystem.instance:getLuaObjectOnSquare(quadrado) or nil
            if fogueira then
                return { tipo = "fogueira", alvo = fogueira, quadrado = quadrado, combustivelAtual = 0, ehPropano = false }
            end

            -- Tiles de interação com fogo (lareira, fogão a lenha, BBQ)
            local objetos = quadrado:getObjects()
            if objetos and objetos:size() > 0 then
                for indice = 0, objetos:size() - 1 do
                    local obj = objetos:get(indice)
                    if obj and obj.isFireInteractionObject and obj:isFireInteractionObject() then
                        local ehPropano = (obj.isPropaneBBQ and obj:isPropaneBBQ()) or false
                        local combustivel = (obj.getFuelAmount and obj:getFuelAmount()) or 0
                        return { tipo = "tile", alvo = obj, quadrado = quadrado, combustivelAtual = combustivel, ehPropano = ehPropano }
                    end
                end
            end
        end
    end
    return nil
end

-- ============================================================================
-- FUNÇÕES AUXILIARES DE ÍCONE
-- ============================================================================

--- Tenta obter o ícone de um item pelo seu fullType via ScriptManager.
---
--- @param tipoCompleto string O fullType do item (ex: "Base.Matches").
--- @return Texture|nil textura A textura do ícone, ou nil.
local function obterIconePorTipo(tipoCompleto)
    local script = ScriptManager.instance and ScriptManager.instance:getItem(tipoCompleto) or nil
    if script and script.getIcon then
        local nomeIcone = script:getIcon()
        if nomeIcone and nomeIcone ~= "" then
            return getTexture("Item_" .. nomeIcone .. ".png")
        end
    end
    return nil
end

--- Define o ícone de uma opção de menu baseado no fullType de um item.
---
--- @param opcao table A opção de menu (ISContextMenu option).
--- @param tipoCompleto string O fullType do item para buscar ícone.
local function definirIconeOpcao(opcao, tipoCompleto)
    if not opcao then return end
    local textura = obterIconePorTipo(tipoCompleto)
    if textura then opcao.iconTexture = textura end
end

--- Busca uma opção existente no menu de contexto pelo nome e target.
---
--- @param contexto ISContextMenu O menu de contexto.
--- @param objetosMundo table O target original da opção.
--- @param rotulo string O nome da opção a buscar.
--- @return table|nil opcao A opção encontrada, ou nil.
local function buscarOpcaoNoContexto(contexto, objetosMundo, rotulo)
    for indice = #contexto.options, 1, -1 do
        local opcao = contexto.options[indice]
        if type(opcao) == "table"
            and opcao.name == rotulo
            and opcao.target == objetosMundo
            and opcao.subOption ~= nil then
            return opcao
        end
    end
end

-- ============================================================================
-- ÍCONES TEMÁTICOS
-- ============================================================================

local function aplicarIconeAcender(contexto, objetosMundo)
    local rotulo = getText("ContextMenu_Light_fire") or "Acender"
    local opcao = buscarOpcaoNoContexto(contexto, objetosMundo, rotulo)
    if opcao then definirIconeOpcao(opcao, "Base.Matches") end
end

local function aplicarIconeApagar(opcao)
    definirIconeOpcao(opcao, "Base.Extinguisher")
end

local function aplicarIconePropano(opcao)
    definirIconeOpcao(opcao, "Base.PropaneTank")
end

local function aplicarIconeDestruirParaCombustivel(contexto, objetosMundo)
    local rotulo = getText("ContextMenu_DestroyForFuel") or "Transformar em Combustível"
    -- Busca opção com ou sem submenu (notAvailable não cria submenu)
    local opcao = buscarOpcaoNoContexto(contexto, objetosMundo, rotulo)
    if not opcao then
        for indice = #contexto.options, 1, -1 do
            local op = contexto.options[indice]
            if type(op) == "table" and op.name == rotulo and op.target == objetosMundo then
                opcao = op
                break
            end
        end
    end
    if not opcao then return end

    if opcao.notAvailable then
        opcao.iconTexture = getTexture("media/ui/LKS_Fuel_Disabled.png")
    else
        definirIconeOpcao(opcao, "Base.FirewoodBundle")
    end
end

local function aplicarIconeRemoverFogueira(opcao)
    definirIconeOpcao(opcao, "Base.Stone2")
end

-- ============================================================================
-- MENU HIERÁRQUICO DE ACENDER (Fonte de Calor → Material Inflamável)
-- ============================================================================

--- Constrói o menu hierárquico "Acender" para objetos a lenha/fogo.
---
--- Fluxo: Acender > [Fonte de Calor] > [Material Inflamável]
--- Requer pelo menos 1 fonte de calor E 1 material inflamável (ou petróleo).
--- Se faltar algo, exibe dica informativa.
---
--- @param jogador IsoPlayer O jogador.
--- @param submenu ISContextMenu O submenu de fogo onde adicionar a opção.
--- @param objetosMundo table Os objetos do mundo.
--- @param temCombustivel boolean Se o alvo já tem combustível.
--- @param infosCombustivel table Resultado de getNearbyFuelInfo.
--- @param alvo table O alvo do fogo (campfire Lua ou IsoObject).
--- @param acaoPetroleo ISBaseTimedAction Ação de acender com petróleo.
--- @param acaoTinder ISBaseTimedAction Ação de acender com tinder.
--- @param acaoKindling ISBaseTimedAction Ação de acender com fricção.
local function montarMenuAcender(jogador, submenu, objetosMundo, temCombustivel, infosCombustivel, alvo, acaoPetroleo, acaoTinder, acaoKindling)
    local fontesCalor = infosCombustivel.starters or {}
    local materiaisInflamaveis = infosCombustivel.tinder or {}
    local petrol = infosCombustivel.petrol
    local percedWood = infosCombustivel.percedWood
    local stick = infosCombustivel.stick or infosCombustivel.branch

    local temFonteCalor = #fontesCalor > 0
    local temTinder = #materiaisInflamaveis > 0
    local temPetrol = temCombustivel and petrol ~= nil
    local temFriccao = percedWood ~= nil and stick ~= nil and temCombustivel

    local temMetodoValido = (temFonteCalor and (temTinder or temPetrol)) or temFriccao

    local rotuloAcender = getText("ContextMenu_Light_fire") or "Acender"

    -- Sem nenhuma fonte de calor NEM fricção: opção desabilitada diretamente
    if not temFonteCalor and not temFriccao then
        local opcao = submenu:addOption(rotuloAcender, objetosMundo, nil)
        definirIconeOpcao(opcao, "Base.Matches")
        opcao.notAvailable = true
        opcao.toolTip = ISWorldObjectContextMenu.addToolTip()
        opcao.toolTip.description = getText("IGUI_LKS_RequerFonteCalor")
        return
    end

    -- Tem fontes de calor mas sem material inflamável: mostra fontes + dica do que falta
    if temFonteCalor and not temTinder and not temPetrol and not temFriccao then
        local opcaoAcender = submenu:addOption(rotuloAcender, objetosMundo, nil)
        definirIconeOpcao(opcaoAcender, "Base.Matches")
        local submenuFontes = ISContextMenu:getNew(submenu)
        submenu:addSubMenu(opcaoAcender, submenuFontes)

        for _, fonteCalor in ipairs(fontesCalor) do
            local opcaoFonte = submenuFontes:addOption(fonteCalor:getDisplayName(), objetosMundo, nil)
            opcaoFonte.iconTexture = fonteCalor:getTex()
            opcaoFonte.notAvailable = true
            opcaoFonte.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcaoFonte.toolTip.description = getText("IGUI_LKS_RequerMaterialInflamavel")
        end
        return
    end

    -- Criar opção "Acender" com submenu de fontes de calor
    local opcaoAcender = submenu:addOption(rotuloAcender, objetosMundo, nil)
    definirIconeOpcao(opcaoAcender, "Base.Matches")
    local submenuFontes = ISContextMenu:getNew(submenu)
    submenu:addSubMenu(opcaoAcender, submenuFontes)

    -- Ordenar fontes e materiais
    table.sort(fontesCalor, function(a, b)
        return not string.sort(a:getDisplayName(), b:getDisplayName())
    end)
    if temTinder then
        table.sort(materiaisInflamaveis, function(a, b)
            return not string.sort(a:getDisplayName(), b:getDisplayName())
        end)
    end

    -- Para cada fonte de calor: submenu com materiais inflamáveis
    for _, fonteCalor in ipairs(fontesCalor) do
        local nomeFonte = fonteCalor:getDisplayName()

        if temTinder or temPetrol then
            local opcaoFonte = submenuFontes:addOption(nomeFonte, objetosMundo, nil)
            opcaoFonte.iconTexture = fonteCalor:getTex()
            local submenuTinder = ISContextMenu:getNew(submenuFontes)
            submenuFontes:addSubMenu(opcaoFonte, submenuTinder)

            -- Materiais inflamáveis (tinder)
            for _, tinder in ipairs(materiaisInflamaveis) do
                local rotuloTinder = tinder:getName()
                local quantidade = infosCombustivel.itemCount[tinder:getName()] or 1
                if quantidade > 1 then
                    rotuloTinder = rotuloTinder .. " (" .. quantidade .. ")"
                end
                local duracao = ISCampingMenu.getFuelDurationForItem(tinder) or 0

                local opcaoTinder = submenuTinder:addActionsOption(rotuloTinder,
                    ISCampingMenu.onLightFromLiterature, tinder:getFullType(), fonteCalor, alvo, acaoTinder)
                opcaoTinder.itemForTexture = tinder
                opcaoTinder.toolTip = ISWorldObjectContextMenu.addToolTip()
                opcaoTinder.toolTip.description = getText("IGUI_BBQ_FuelAmount",
                    ISCampingMenu.timeString(luautils.round(duracao, 2)))
            end

            -- Gasolina como acelerante (se disponível e há combustível no alvo)
            if temPetrol then
                local opcaoPetrol = submenuTinder:addActionsOption(petrol:getName(),
                    ISCampingMenu.onLightFromPetrol, fonteCalor, petrol, alvo, acaoPetroleo)
                opcaoPetrol.itemForTexture = petrol
            end
        else
            -- Fonte disponível mas sem material inflamável (feedback)
            local opcaoFonte = submenuFontes:addOption(nomeFonte, objetosMundo, nil)
            opcaoFonte.iconTexture = fonteCalor:getTex()
            opcaoFonte.notAvailable = true
            opcaoFonte.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcaoFonte.toolTip.description = getText("IGUI_LKS_RequerMaterialInflamavel")
        end
    end

    -- Fricção (percedWood + stick) — método alternativo sem fonte de calor
    if temFriccao then
        if jogador:getStats():get(CharacterStat.ENDURANCE) > 0 then
            local rotuloFriccao = percedWood:getName() .. " + " .. stick:getName()
            local opcaoFriccao = submenuFontes:addActionsOption(rotuloFriccao,
                ISCampingMenu.onLightFromKindle, percedWood, stick, alvo, acaoKindling)
            opcaoFriccao.itemForTexture = percedWood
        else
            local opcaoFriccao = submenuFontes:addOption(percedWood:getName(), objetosMundo, nil)
            opcaoFriccao.itemForTexture = percedWood
            opcaoFriccao.notAvailable = true
            opcaoFriccao.toolTip = ISWorldObjectContextMenu.addToolTip()
            opcaoFriccao.toolTip.description = getText("Tooltip_lightFireNoEndurance")
        end
    end
end

-- ============================================================================
-- CONSTRUÇÃO DO CABEÇALHO E SUBMENU
-- ============================================================================

--- Resolve o rótulo e ícone para a entrada-pai do submenu de fogo.
---
--- @param informacoesAlvo table Resultado de encontrarAlvoFogo.
--- @return string rotulo Nome da opção-pai.
--- @return Texture|nil icone Textura do ícone.
local function obterCabecalhoMenu(informacoesAlvo)
    if not informacoesAlvo then
        return (getText("ContextMenu_Fire") or "Fogo"), nil
    end

    if informacoesAlvo.tipo == "fogueira" then
        local rotulo = getText("IGUI_Campfire_Campfire") or "Fogueira"
        local isoObjeto = informacoesAlvo.alvo and informacoesAlvo.alvo.getIsoObject
            and informacoesAlvo.alvo:getIsoObject()
        if isoObjeto then
            local spriteObjeto = isoObjeto:getSprite()
            if spriteObjeto then
                local texturaSplit = getTexture(spriteObjeto:getName())
                if texturaSplit then
                    return rotulo, texturaSplit:splitIcon()
                end
            end
        end
        return rotulo, (ContainerButtonIcons and ContainerButtonIcons.campfire) or nil
    end

    local objeto = informacoesAlvo.alvo
    local nomeOriginal = (objeto and objeto.getTileName and objeto:getTileName()) or (getText("ContextMenu_Fire") or "Fogo")
    local rotulo = TRADUCAO_TILE_NAMES[nomeOriginal] or nomeOriginal

    if informacoesAlvo.tipo == "tile" then
        -- Sprite real do objeto via splitIcon()
        local spriteObjeto = objeto and objeto.getSprite and objeto:getSprite()
        if spriteObjeto then
            local texturaSplit = getTexture(spriteObjeto:getName())
            if texturaSplit then
                return rotulo, texturaSplit:splitIcon()
            end
        end
        -- Fallback: ícone por container type
        if ContainerButtonIcons and objeto.getContainer then
            local container = objeto:getContainer()
            local tipoContainer = container and container.getType and container:getType() or nil
            if tipoContainer and ContainerButtonIcons[tipoContainer] then
                return rotulo, ContainerButtonIcons[tipoContainer]
            end
        end
        if informacoesAlvo.ehPropano then
            return rotulo, (ContainerButtonIcons and ContainerButtonIcons.barbecuepropane) or nil
        end
        return rotulo, (ContainerButtonIcons and ContainerButtonIcons.campfire) or nil
    end

    return rotulo, nil
end

--- Cria a entrada-pai e o submenu no menu de contexto.
---
--- @param contexto ISContextMenu O menu de contexto principal.
--- @param objetosMundo table Os objetos do mundo.
--- @param informacoesAlvo table Resultado de encontrarAlvoFogo.
--- @return ISContextMenu submenu O submenu criado.
local function criarSubmenuFogo(contexto, objetosMundo, informacoesAlvo)
    local rotulo, icone = obterCabecalhoMenu(informacoesAlvo)

    local opcaoPai = contexto:addOption(rotulo, objetosMundo, nil)
    if icone then opcaoPai.iconTexture = icone end

    local submenu = ISContextMenu:getNew(contexto)
    contexto:addSubMenu(opcaoPai, submenu)
    return submenu
end

-- ============================================================================
-- APAGAR FOGO (tiles não-fogueira)
-- ============================================================================

--- Apaga fogo em tiles de interação (lareira, BBQ).
---
--- @param objetosMundo table Objetos do mundo.
--- @param jogadorNumero number Índice do jogador.
--- @param tile IsoObject O tile com fogo.
local function apagarFogoTile(objetosMundo, jogadorNumero, tile)
    local jogador = getSpecificPlayer(jogadorNumero)
    if not jogador or not tile then return end
    if luautils.walkAdj(jogador, tile:getSquare()) then
        local ISBBQMenuRef = rawget(_G, "ISBBQMenu")
        local funcaoApagar = (ISBBQMenuRef and ISBBQMenuRef.onExtinguish) or nil
        if funcaoApagar then
            funcaoApagar(objetosMundo, jogadorNumero, tile)
        else
            ISTimedActionQueue.add(ISBBQExtinguish:new(jogador, tile))
        end
    end
end

-- ============================================================================
-- HANDLER PRINCIPAL (substitui ISCampingMenu.doCampingMenu)
-- ============================================================================

---@diagnostic disable-next-line: duplicate-set-field
CampingMenu.doCampingMenu = function(jogadorNumero, contexto, objetosMundo, apenasTeste)
    if apenasTeste and ISWorldObjectContextMenu.Test then return true end
    local jogador = getSpecificPlayer(jogadorNumero)
    if not jogador or (jogador.getVehicle and jogador:getVehicle()) then return end

    local informacoesAlvo = encontrarAlvoFogo(objetosMundo)
    if not informacoesAlvo then
        if apenasTeste then return end
        return
    end


    if apenasTeste then
        return ISWorldObjectContextMenu.setTest()
    end

    local submenu = criarSubmenuFogo(contexto, objetosMundo, informacoesAlvo)
    local alvo = informacoesAlvo.alvo
    local combustivelAtual = informacoesAlvo.combustivelAtual or 0
    local infosCombustivel = CampingMenu.getNearbyFuelInfo(jogador)

    -- =========================================================================
    -- FOGUEIRA (Campfire Kit)
    -- =========================================================================
    if informacoesAlvo.tipo == "fogueira" then
        local objetoFogueira = alvo:getIsoObject()
        local distancia = jogador:DistToSquared(objetoFogueira:getX() + 0.5, objetoFogueira:getY() + 0.5)

        -- Informações
        local opcaoInfo = submenu:addOption(getText("ContextMenu_CampfireInfo"), objetosMundo,
            CampingMenu.onDisplayInfo, jogador, objetoFogueira, alvo)
        opcaoInfo.iconTexture = getTexture(TEX_INFO)

        if distancia < 4 then
            opcaoInfo.toolTip = ISToolTip:new()
            opcaoInfo.toolTip:initialise()
            opcaoInfo.toolTip:setVisible(false)
            opcaoInfo.toolTip:setName(getText("IGUI_Campfire_Campfire"))
            local textoEstado = alvo.isLit and getText("IGUI_Fireplace_Burning") or getText("IGUI_Fireplace_Unlit")
            opcaoInfo.toolTip.description = getText("IGUI_BBQ_FuelAmount", CampingMenu.timeString(luautils.round(alvo.fuelAmt or 0)))
                .. " (" .. textoEstado .. ")"
        end

        -- Acender / Apagar
        if alvo.isLit then
            local opcaoApagar = submenu:addOption(getText("ContextMenu_Put_out_fire"), objetosMundo,
                CampingMenu.onPutOutCampfire, jogador, alvo)
            aplicarIconeApagar(opcaoApagar)
        else
            local temCombustivel = (alvo.fuelAmt or 0) > 0
            montarMenuAcender(jogador, submenu, objetosMundo, temCombustivel, infosCombustivel, alvo,
                ISLightFromPetrol, ISLightFromLiterature, ISLightFromKindle)
        end

        -- Adicionar Combustível + Remover Fogueira
        CampingMenu.doAddFuelOption(submenu, objetosMundo, (alvo.fuelAmt or 0), infosCombustivel, alvo, ISAddFuelAction, jogador)
        aplicarIconeDestruirParaCombustivel(submenu, objetosMundo)

        local opcaoRemover = submenu:addOption(campingText.removeCampfire, objetosMundo, CampingMenu.onRemoveCampfire, jogador, alvo)
        aplicarIconeRemoverFogueira(opcaoRemover)
        return
    end

    -- =========================================================================
    -- TILE DE INTERAÇÃO COM FOGO (lareira, fogão a lenha, BBQ)
    -- =========================================================================
    local ehPropano = informacoesAlvo.ehPropano or false
    local posicaoX, posicaoY = alvo:getX(), alvo:getY()
    local distancia = jogador:DistToSquared((posicaoX or 0) + 0.5, (posicaoY or 0) + 0.5)

    -- Informações
    local ISBBQMenuRef = rawget(_G, "ISBBQMenu")
    local rotuloInfo = getText("ContextMenu_Info")
    local opcaoInfo

    if ISBBQMenuRef and ISBBQMenuRef.onDisplayInfo and alvo.isFireInteractionObject and alvo:isFireInteractionObject() then
        opcaoInfo = submenu:addOption(rotuloInfo, objetosMundo, ISBBQMenuRef.onDisplayInfo, jogadorNumero, alvo)
    else
        opcaoInfo = submenu:addOption(rotuloInfo, objetosMundo, function() end)
    end

    opcaoInfo.iconTexture = getTexture(TEX_INFO)

    if distancia < 4 then
        local textoEstado
        if alvo.isLit and alvo:isLit() then
            textoEstado = getText("IGUI_Fireplace_Burning")
        elseif alvo.isSmouldering and alvo:isSmouldering() then
            textoEstado = getText("IGUI_Fireplace_Smouldering")
        else
            textoEstado = getText("IGUI_Fireplace_Unlit")
        end
        local combustivelSegundos = (alvo.getFuelAmount and alvo:getFuelAmount()) or combustivelAtual or 0
        local descricao = getText("IGUI_BBQ_FuelAmount", CampingMenu.timeString(luautils.round(combustivelSegundos))) .. " (" .. textoEstado .. ")"

        if ehPropano and alvo.hasPropaneTank and not alvo:hasPropaneTank() then
            descricao = descricao .. " <LINE> <RGB:1,0,0> " .. getText("IGUI_BBQ_NeedsPropaneTank")
        end

        opcaoInfo.toolTip = ISToolTip:new()
        opcaoInfo.toolTip:initialise()
        opcaoInfo.toolTip:setVisible(false)
        opcaoInfo.toolTip.description = descricao
    end

    -- Branch por tipo de BBQ
    if ehPropano then
        -- BBQ a Propano
        if alvo.hasFuel and alvo:hasFuel() then
            if alvo.isLit and alvo:isLit() then
                submenu:addOption(getText("ContextMenu_Turn_Off"), objetosMundo, ISBBQMenuRef.onToggle, jogadorNumero, alvo)
            else
                submenu:addOption(getText("ContextMenu_Turn_On"), objetosMundo, ISBBQMenuRef.onToggle, jogadorNumero, alvo)
            end
        end

        local tanque = ISBBQMenuRef and ISBBQMenuRef.FindPropaneTank and ISBBQMenuRef.FindPropaneTank(jogador, alvo)
        local opcaoTanque
        if tanque then
            opcaoTanque = submenu:addOption(getText("ContextMenu_Insert_Propane_Tank"), objetosMundo, ISBBQMenuRef.onInsertPropaneTank, jogadorNumero, alvo, tanque)
        end
        if alvo.hasPropaneTank and alvo:hasPropaneTank() then
            opcaoTanque = submenu:addOption(getText("ContextMenu_Remove_Propane_Tank"), objetosMundo, ISBBQMenuRef.onRemovePropaneTank, jogadorNumero, alvo)
        end
        if opcaoTanque then aplicarIconePropano(opcaoTanque) end
    else
        -- BBQ Carvão / Lareira / Fogão a Lenha
        local estaAceso = (alvo.isLit and alvo:isLit()) or false
        local temCombustivel = (alvo.hasFuel and alvo:hasFuel()) or (combustivelAtual > 0)

        if estaAceso then
            local opcaoApagar = submenu:addOption(getText("ContextMenu_Put_out_fire"), objetosMundo, apagarFogoTile, jogadorNumero, alvo)
            aplicarIconeApagar(opcaoApagar)
        else
            local AcenderPetroleo = rawget(_G, "ISBBQLightFromPetrol") or ISLightFromPetrol
            local AcenderLiteratura = rawget(_G, "ISBBQLightFromLiterature") or ISLightFromLiterature
            local AcenderKindling = rawget(_G, "ISBBQLightFromKindle") or ISLightFromKindle

            montarMenuAcender(jogador, submenu, objetosMundo, temCombustivel, infosCombustivel, alvo,
                AcenderPetroleo, AcenderLiteratura, AcenderKindling)
        end

        -- Adicionar Combustível
        local AcaoAdicionarCombustivel = rawget(_G, "ISBBQAddFuel") or ISAddFuelAction
        CampingMenu.doAddFuelOption(submenu, objetosMundo, combustivelAtual, infosCombustivel, alvo, AcaoAdicionarCombustivel, jogador)
        aplicarIconeDestruirParaCombustivel(submenu, objetosMundo)
    end
end

-- ============================================================================
-- NEUTRALIZAÇÃO DOS HANDLERS VANILLA
-- ============================================================================

do
    local ISBBQMenuRef = rawget(_G, "ISBBQMenu")
    if ISBBQMenuRef then
        local funcaoOriginal = ISBBQMenuRef.OnFillWorldObjectContextMenu
        ISBBQMenuRef.OnFillWorldObjectContextMenu = function(...)
        end
    else
    end
end

-- ============================================================================
-- LIMPEZA DE DUPLICATAS PÓS-MENU
-- ============================================================================
-- Outros mods (CleanUI, Loot Window handlers) podem criar entradas duplicadas
-- para o mesmo objeto IsoFireplace. Este handler roda APÓS todos os outros
-- e remove entradas com o mesmo nome, mantendo apenas a primeira (a nossa).
-- ============================================================================

local function limparDuplicatasFireMenu(jogadorNumero, contexto, objetosMundo, apenasTeste)
    if apenasTeste then return end
    if not contexto or not contexto.options then return end

    for indice, opcao in ipairs(contexto.options) do
        if type(opcao) == "table" then
        end
    end

    local nomesVistos = {}
    local indicesParaRemover = {}

    for indice, opcao in ipairs(contexto.options) do
        if type(opcao) == "table" and opcao.subOption then
            local nome = opcao.name
            if nome then
                if nomesVistos[nome] then
                    table.insert(indicesParaRemover, indice)
                else
                    nomesVistos[nome] = true
                end
            end
        end
    end

    for idx = #indicesParaRemover, 1, -1 do
        table.remove(contexto.options, indicesParaRemover[idx])
    end
end

Events.OnFillWorldObjectContextMenu.Add(limparDuplicatasFireMenu)

print("[LKS PATCH - LKS_Menu_Fire_FuelSolid.lua] Menu unificado de fogo carregado (substitui ISCampingMenu + ISBBQMenu)")
