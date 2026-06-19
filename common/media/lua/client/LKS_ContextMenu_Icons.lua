-- ============================================================================
-- LKS_ContextMenu_Icons.lua — Injeção global de ícones em menus de contexto
-- ============================================================================
-- Hook pós-processamento que varre o menu de contexto do mundo APÓS o vanilla
-- construí-lo e injeta ícones LKS em opções padrão (Pegar, etc.).
-- Também remove botijões do "Pegar" vanilla (tratados pelo menu LKS dedicado).
-- ============================================================================

local LKS_Icons = require("LKS_Icons")

--- IDs de botijão para remoção do "Pegar" vanilla.
local IDS_BOTIJAO_REMOVER = {
    ["Base.PropaneTank"] = true,
    ["LKS_Propano.LKS_Botijao15kg"] = true,
    ["LKS_Propano.LKS_Botijao45kg"] = true,
}

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

--- Remove entradas de botijão do submenu "Pegar" vanilla.
---@param menuContexto ISContextMenu
local function removerBotijoesDoGrabVanilla(menuContexto)
    local textoGrab = getText("ContextMenu_Grab") or "Grab"
    local opcaoGrab = menuContexto:getOptionFromName(textoGrab)
    if not opcaoGrab then return end

    if opcaoGrab.subOption then
        local submenuGrab = menuContexto:getSubMenu(opcaoGrab.subOption)
        if submenuGrab then
            -- Remove por nome traduzido (mesmo approach do gerador)
            pcall(function() submenuGrab:removeOptionByName(getText("ItemName_Base.PropaneTank") or "Propane Tank") end)
            pcall(function() submenuGrab:removeOptionByName(getText("ItemName_LKS_Propano.LKS_Botijao15kg") or "Gas Tank 15kg") end)
            pcall(function() submenuGrab:removeOptionByName(getText("ItemName_LKS_Propano.LKS_Botijao45kg") or "Gas Tank 45kg") end)
            -- Fallbacks em caso de DisplayName cru
            pcall(function() submenuGrab:removeOptionByName("Propane Tank") end)
            pcall(function() submenuGrab:removeOptionByName("Gas Tank 15kg") end)
            pcall(function() submenuGrab:removeOptionByName("Gas Tank 45kg") end)
            pcall(function() submenuGrab:removeOptionByName("Botijão de Gás") end)
            pcall(function() submenuGrab:removeOptionByName("Botijão de Gás 15kg") end)
            pcall(function() submenuGrab:removeOptionByName("Botijão de Gás 45kg") end)

            -- Se o submenu ficou vazio, remove "Pegar" inteiro
            if submenuGrab.numOptions and submenuGrab.numOptions <= 1 then
                menuContexto:removeOptionByName(textoGrab)
            end
        end
    else
        -- "Pegar" sem submenu — verifica se o nome é de botijão
        pcall(function() menuContexto:removeOptionByName(textoGrab) end)
    end
end

--- Varre as opções do menu e injeta ícone de "Pegar" onde aplicável.
---@param jogadorIndice number Índice do jogador.
---@param menuContexto ISContextMenu O menu de contexto construído.
---@param objetosMundo table Objetos do mundo clicados.
---@param teste boolean Se true, é verificação de joypad (não injetar).
local function injetarIconesPegar(jogadorIndice, menuContexto, objetosMundo, teste)
    if teste then return end
    if not menuContexto or not menuContexto.getOptionFromName then return end

    -- Remove botijões do "Pegar" vanilla (nosso menu LKS trata)
    removerBotijoesDoGrabVanilla(menuContexto)

    -- Injeta ícone LKS_Take nas opções "Pegar" restantes
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
