-- ==========================================================================
-- LKS_Organizer_ContextMenu.lua
-- Menu de contexto para Favoritar/Desfavoritar containers do mundo.
-- Injeta opção via OnFillWorldObjectContextMenu em qualquer IsoObject com container.
-- ==========================================================================

local LKS_Organizer_Motor = require("LKS_Organizer_Motor")

--- Prefixo dos prints de debug.
local DEBUG_PREFIX = "[LKS_Organizer]"

--- Ícone da estrela de favoritar.
local ICONE_FAVORITAR = getTexture("media/ui/LKS_Menu_Favoritar.png")

-- ==========================================================================
-- HANDLER DO MENU DE CONTEXTO
-- ==========================================================================

--- Verifica se um objeto do mundo é elegível para favoritação.
---
--- Um objeto é elegível se possui pelo menos 1 container acessível,
--- não é o jogador e não é um IsoGridSquare diretamente.
---
--- @param objeto IsoObject O objeto a verificar.
--- @param jogador IsoPlayer O jogador.
--- @return boolean elegivel True se pode ser favoritado.
local function objetoElegivel(objeto, jogador)
    if not objeto then return false end
    if instanceof(objeto, "IsoPlayer") then return false end
    if instanceof(objeto, "IsoGridSquare") then return false end
    if not objeto.getContainerCount then return false end
    if objeto:getContainerCount() == 0 then return false end

    -- Verificar se não está trancado
    if instanceof(objeto, "IsoThumpable") and objeto:isLockedToCharacter(jogador) then
        return false
    end

    return true
end

--- Obtém o nome legível do container para exibição no menu.
---
--- @param objeto IsoObject O objeto do mundo.
--- @return string nome Nome traduzido do objeto.
local function obterNomeContainer(objeto)
    if not objeto then return "Container" end

    -- Tentar nome movível
    local moveProps = ISMoveableSpriteProps.fromObject(objeto)
    if moveProps and moveProps.name then
        local nome = Translator.getMoveableDisplayName(moveProps.name)
        if nome and nome ~= "" then
            return nome
        end
    end

    -- Fallback: tipo do primeiro container
    if objeto:getContainerCount() > 0 then
        local container = objeto:getContainerByIndex(0)
        if container then
            local chave = "IGUI_ContainerTitle_" .. container:getType()
            local nome = getTextOrNull(chave)
            if nome then return nome end
        end
    end

    return "Container"
end

--- Callback executado ao clicar em "Favoritar".
---
--- @param objetosMundo table Objetos do mundo selecionados.
--- @param jogador IsoPlayer O jogador.
--- @param objeto IsoObject O objeto a favoritar.
local function onFavoritar(objetosMundo, jogador, objeto)
    LKS_Organizer_Motor.favoritar(objeto)
end

--- Callback executado ao clicar em "Desfavoritar".
---
--- @param objetosMundo table Objetos do mundo selecionados.
--- @param jogador IsoPlayer O jogador.
--- @param objeto IsoObject O objeto a desfavoritar.
local function onDesfavoritar(objetosMundo, jogador, objeto)
    LKS_Organizer_Motor.desfavoritar(objeto)
end

--- Handler principal do menu de contexto.
---
--- Registrado em OnFillWorldObjectContextMenu. Detecta objetos com containers
--- no clique e injeta a opção de Favoritar/Desfavoritar.
---
--- @param playerNum number Índice do jogador.
--- @param contexto ISContextMenu O menu de contexto sendo construído.
--- @param objetosMundo table Lista de IsoObjects no clique.
--- @param teste boolean Se true, é apenas teste de existência (não adicionar opções).
local function onFillWorldObjectContextMenu(playerNum, contexto, objetosMundo, teste)
    if teste then return end

    local jogador = getSpecificPlayer(playerNum)
    if not jogador then return end

    -- Procurar o primeiro objeto elegível nos objetos clicados
    local objetoAlvo = nil

    for _, objetoMundo in ipairs(objetosMundo) do
        if objetoElegivel(objetoMundo, jogador) then
            objetoAlvo = objetoMundo
            break
        end

        -- Verificar sub-objetos do quadrado
        if instanceof(objetoMundo, "IsoGridSquare") then
            local objetos = objetoMundo:getObjects()
            for i = 0, objetos:size() - 1 do
                local subObjeto = objetos:get(i)
                if objetoElegivel(subObjeto, jogador) then
                    objetoAlvo = subObjeto
                    break
                end
            end
            if objetoAlvo then break end
        end
    end

    if not objetoAlvo then return end

    -- Determinar estado atual
    local favoritado = LKS_Organizer_Motor.isFavoritado(objetoAlvo)
    local nomeContainer = obterNomeContainer(objetoAlvo)

    if favoritado then
        -- Opção: Desfavoritar
        local textoOpcao = getText("IGUI_LKS_Organizer_Desfavoritar")
        local opcao = contexto:addOption(textoOpcao, objetosMundo, onDesfavoritar, jogador, objetoAlvo)
        if ICONE_FAVORITAR then
            opcao.iconTexture = ICONE_FAVORITAR
        end

        print(DEBUG_PREFIX .. " Menu: mostrando 'Desfavoritar' para " .. nomeContainer)
    else
        -- Opção: Favoritar
        local textoOpcao = getText("IGUI_LKS_Organizer_Favoritar")
        local opcao = contexto:addOption(textoOpcao, objetosMundo, onFavoritar, jogador, objetoAlvo)
        if ICONE_FAVORITAR then
            opcao.iconTexture = ICONE_FAVORITAR
        end

        print(DEBUG_PREFIX .. " Menu: mostrando 'Favoritar' para " .. nomeContainer)
    end
end

-- ==========================================================================
-- REGISTRO DO EVENTO
-- ==========================================================================

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

print(DEBUG_PREFIX .. " ContextMenu registrado em OnFillWorldObjectContextMenu")
