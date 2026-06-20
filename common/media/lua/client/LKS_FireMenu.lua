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
-- ARQUIVO: LKS_FireMenu.lua
-- EXTENSÃO: LKS SuperMod Patch (Menu Unificado de Fogo)
-- OBJETIVO: Handler unificado de menu de contexto para fogueiras, lareiras,
--           fogões a lenha e churrasqueiras. Substitui ISCampingMenu.doCampingMenu
--           e ISBBQMenu.OnFillWorldObjectContextMenu por um fluxo único sem
--           duplicatas, com ícones temáticos e tooltip informativo.
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 20/06/2026
-- ============================================================================

require "Camping/ISCampingMenu"

local CampingMenu = ISCampingMenu
if not CampingMenu then
    print("[LKS PATCH - LKS_FireMenu.lua] ERRO: ISCampingMenu nao disponivel")
    return
end

local referenciaHandlerOriginal = CampingMenu.doCampingMenu

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
    local rotulo = getText("ContextMenu_Light_fire") or "Light Fire"
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
    local rotulo = getText("ContextMenu_DestroyForFuel") or "Destroy for Fuel"
    local opcao = buscarOpcaoNoContexto(contexto, objetosMundo, rotulo)
    if opcao then definirIconeOpcao(opcao, "Base.FirewoodBundle") end
end

local function aplicarIconeRemoverFogueira(opcao)
    definirIconeOpcao(opcao, "Base.Stone2")
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
        return (getText("ContextMenu_Fire") or "Fire"), nil
    end

    if informacoesAlvo.tipo == "fogueira" then
        local rotulo = getText("IGUI_Campfire_Campfire") or "Campfire"
        local icone = (ContainerButtonIcons and ContainerButtonIcons.campfire) or nil
        return rotulo, icone
    end

    local objeto = informacoesAlvo.alvo
    local rotulo = (objeto and objeto.getTileName and objeto:getTileName()) or (getText("ContextMenu_Fire") or "Fire")

    if informacoesAlvo.tipo == "tile" then
        -- Ícone por container type
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
    print("[LKS DEBUG FireMenu] doCampingMenu chamado - apenasTeste=" .. tostring(apenasTeste))
    if apenasTeste and ISWorldObjectContextMenu.Test then return true end
    local jogador = getSpecificPlayer(jogadorNumero)
    if not jogador or (jogador.getVehicle and jogador:getVehicle()) then return end

    local informacoesAlvo = encontrarAlvoFogo(objetosMundo)
    if not informacoesAlvo then
        if apenasTeste then return end
        return
    end

    print("[LKS DEBUG FireMenu] alvo encontrado - tipo=" .. tostring(informacoesAlvo.tipo) .. " ehPropano=" .. tostring(informacoesAlvo.ehPropano))

    if apenasTeste then
        return ISWorldObjectContextMenu.setTest()
    end

    local submenu = criarSubmenuFogo(contexto, objetosMundo, informacoesAlvo)
    print("[LKS DEBUG FireMenu] submenu criado - total opcoes no contexto=" .. tostring(#contexto.options))
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
        if ContainerButtonIcons and ContainerButtonIcons.campfire then
            opcaoInfo.iconTexture = ContainerButtonIcons.campfire
        end

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
            CampingMenu.doLightFireOption(jogador, submenu, objetosMundo, temCombustivel, infosCombustivel, alvo,
                ISLightFromPetrol, ISLightFromLiterature, ISLightFromKindle)
            aplicarIconeAcender(submenu, objetosMundo)
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

    if ContainerButtonIcons then
        if ehPropano then
            opcaoInfo.iconTexture = ContainerButtonIcons.barbecuepropane
        else
            opcaoInfo.iconTexture = ContainerButtonIcons.campfire
        end
    end

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

            CampingMenu.doLightFireOption(jogador, submenu, objetosMundo, temCombustivel, infosCombustivel, alvo,
                AcenderPetroleo, AcenderLiteratura, AcenderKindling)
            aplicarIconeAcender(submenu, objetosMundo)
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
            print("[LKS DEBUG FireMenu] ISBBQMenu.OnFillWorldObjectContextMenu CHAMADO (deveria estar neutralizado!)")
        end
        print("[LKS DEBUG FireMenu] ISBBQMenu.OnFillWorldObjectContextMenu neutralizado (era " .. tostring(funcaoOriginal) .. ")")
    else
        print("[LKS DEBUG FireMenu] ISBBQMenu NAO encontrado no momento da carga")
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

    print("[LKS DEBUG FireMenu] limparDuplicatas - total opcoes=" .. #contexto.options)
    for indice, opcao in ipairs(contexto.options) do
        if type(opcao) == "table" then
            print("[LKS DEBUG FireMenu]   opcao[" .. indice .. "] name='" .. tostring(opcao.name) .. "' subOption=" .. tostring(opcao.subOption ~= nil))
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
                    print("[LKS DEBUG FireMenu]   DUPLICATA detectada: '" .. nome .. "' no indice " .. indice)
                else
                    nomesVistos[nome] = true
                end
            end
        end
    end

    print("[LKS DEBUG FireMenu] removendo " .. #indicesParaRemover .. " duplicata(s)")
    for idx = #indicesParaRemover, 1, -1 do
        table.remove(contexto.options, indicesParaRemover[idx])
    end
end

Events.OnFillWorldObjectContextMenu.Add(limparDuplicatasFireMenu)

print("[LKS PATCH - LKS_FireMenu.lua] Menu unificado de fogo carregado (substitui ISCampingMenu + ISBBQMenu)")
