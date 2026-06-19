-- ============================================================================
-- LKS_ContextMenu_Icons.lua — Injeção global de ícones em menus de contexto
-- ============================================================================
-- Hook pós-processamento que varre o menu de contexto do mundo APÓS o vanilla
-- construí-lo e injeta ícones LKS em opções padrão (Pegar, etc.).
-- Funciona para TODOS os objetos do jogo sem precisar tocar cada menu.
-- ============================================================================

local LKS_Icons = require("LKS_Icons")

--- Textos que identificam a ação "Pegar" no menu (PT-BR e EN).
local textosGrab = {}

--- Popula os textos de grab após o jogo carregar as traduções.
local function popularTextosGrab()
    textosGrab = {
        getText("ContextMenu_Grab") or "Grab",
        getText("ContextMenu_Grab_one") or "Grab one",
        getText("ContextMenu_Grab_half") or "Grab half",
        getText("ContextMenu_Grab_all") or "Grab all",
        getText("ContextMenu_GeneratorTake") or "Take Generator",
    }
end

--- Varre as opções do menu e injeta ícone de "Pegar" onde aplicável.
---@param jogadorIndice number Índice do jogador.
---@param menuContexto ISContextMenu O menu de contexto construído.
---@param objetosMundo table Objetos do mundo clicados.
---@param teste boolean Se true, é verificação de joypad (não injetar).
local function injetarIconesPegar(jogadorIndice, menuContexto, objetosMundo, teste)
    if teste then return end
    if not menuContexto or not menuContexto.getOptionFromName then return end

    local texturaGrab = getTexture(LKS_Icons.PEGAR)
    if not texturaGrab then return end

    for _, textoGrab in ipairs(textosGrab) do
        local opcao = menuContexto:getOptionFromName(textoGrab)
        if opcao and not opcao.iconTexture then
            opcao.iconTexture = texturaGrab
        end
    end
end

Events.OnGameStart.Add(function()
    popularTextosGrab()
end)

Events.OnFillWorldObjectContextMenu.Add(injetarIconesPegar)
