-- ============================================================================
-- ARQUIVO: LKS_Device_Laundry.lua
-- EXTENSÃO: LKS SuperMod Patch (Módulo de Comportamento de Lavanderia)
-- OBJETIVO: Driver de comportamento e texturas para secadoras, lavadoras
--           e combo washer dryer no gerenciador LKS_ApplianceManager.
-- AUTOR: LKS FERREIRA & Antigravity AI
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 14/06/2026
-- ============================================================================

-- Inicialização defensiva do gerenciador para robustez de carregamento
LKS_ApplianceManager = LKS_ApplianceManager or {}
LKS_ApplianceManager.devices = LKS_ApplianceManager.devices or {}
LKS_ApplianceManager.containerTypeMap = LKS_ApplianceManager.containerTypeMap or {}
LKS_ApplianceManager.javaClassMap = LKS_ApplianceManager.javaClassMap or {}

if LKS_ApplianceManager.recursoAtivo and not LKS_ApplianceManager.recursoAtivo("LaundryEnabled", true) then
    print("[LKS PATCH - LKS_Device_Laundry.lua] Lavanderia desativada no sandbox.")
    return
end

local LKS_Device_Laundry = {
    recipientesAceitos = {"clothingdryer", "clothingwasher"},
    classesJava = {"IsoClothingDryer", "IsoCombinationWasherDryer", "IsoClothingWasher"},
    brilhoInativo = "escurece35"
}

local LKS_ConfiguracaoIconesLavanderia = {
    clothingdryer = {
        energizado = nil,
    },
    clothingwasher = {
        energizado = "media/ui/Washing_Machine_White.png"
    },
    combo_washer_dryer = {
        energizado = "media/ui/Container_ClothingWasher.png", -- Usa o ícone padrão do jogo base (azul)
    },
}

--- Retorna a textura correspondente baseada nos estados de energia, água e direção.
---
--- @param chaveConfiguracao string O tipo de aparelho ("clothingdryer", "clothingwasher", "combo_washer_dryer").
--- @param temEnergia boolean Se o aparelho possui fornecimento elétrico ativo (ignorado no desenho base).
--- @param temAgua boolean Se o aparelho possui água disponível (ignorado no desenho base).
--- @param direcao string | nil A direção/facing do móvel (ignorado após simplificação).
--- @return Texture O objeto de textura carregado do jogo.
local function obterTexturaEstado(chaveConfiguracao, temEnergia, temAgua, direcao)
    local configuracaoIcone = LKS_ConfiguracaoIconesLavanderia[chaveConfiguracao]
    if not configuracaoIcone then return nil end

    if configuracaoIcone.energizado then
        return getTexture(configuracaoIcone.energizado)
    else
        return ContainerButtonIcons[chaveConfiguracao]
    end
end

--- Retorna a textura para a Loot Window baseada no estado de energia e água do recipiente.
---
--- @param recipiente ItemContainer O contêiner sendo desenhado.
--- @param recipienteTipo string O tipo do contêiner.
--- @param objetoPai IsoObject O objeto pai no mundo.
--- @param temEnergia boolean Se o contêiner possui energia elétrica ativa.
--- @return Texture A textura resolvida para o inventário.
function LKS_Device_Laundry.obterTexturaInventario(recipiente, recipienteTipo, objetoPai, temEnergia)
    local ehCombo = false
    local chaveConfiguracao = nil

    if recipienteTipo == "clothingdryer" then
        chaveConfiguracao = "clothingdryer"
    elseif recipienteTipo == "clothingwasher" then
        if objetoPai and instanceof(objetoPai, "IsoCombinationWasherDryer") then
            chaveConfiguracao = "combo_washer_dryer"
            ehCombo = true
        else
            chaveConfiguracao = "clothingwasher"
        end
    end

    if not chaveConfiguracao then return nil end

    local temAgua = true
    if ehCombo then
        if objetoPai and objetoPai:isModeWasher() then
            temAgua = objetoPai:getFluidAmount() > 0
        end
    elseif recipienteTipo == "clothingwasher" then
        if objetoPai then
            temAgua = objetoPai:getFluidAmount() > 0
        end
    end

    local direcao = nil
    if objetoPai then
        local propriedadesObjeto = objetoPai:getProperties()
        if propriedadesObjeto and propriedadesObjeto:has("Facing") then
            direcao = propriedadesObjeto:get("Facing")
        end
    end

    return obterTexturaEstado(chaveConfiguracao, temEnergia, temAgua, direcao)
end

--- Constrói o submenu premium para secadoras, lavadoras e combo washer dryer.
---
--- @param jogadorNumero number O índice do jogador local (0 a 3).
--- @param menuContexto ISContextMenu O menu de contexto sendo preenchido.
--- @param objetosMundo table A lista de objetos físicos clicados no mundo.
--- @param objetoEletrico IsoObject O objeto elétrico clicado.
function LKS_Device_Laundry.construirMenuContexto(jogadorNumero, menuContexto, objetosMundo, objetoEletrico)
    local jogadorObjeto = getSpecificPlayer(jogadorNumero)
    local ehSecadora = instanceof(objetoEletrico, "IsoClothingDryer")
    local ehComboLavadoraSecadora = instanceof(objetoEletrico, "IsoCombinationWasherDryer")
    local ehLavadora = instanceof(objetoEletrico, "IsoClothingWasher") and not ehComboLavadoraSecadora

    local chaveConfiguracao = nil
    if ehSecadora then
        chaveConfiguracao = "clothingdryer"
    elseif ehComboLavadoraSecadora then
        chaveConfiguracao = "combo_washer_dryer"
    elseif ehLavadora then
        chaveConfiguracao = "clothingwasher"
    end

    local nomeObjetoTraduzido = ""
    if ehSecadora then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Secadora de Roupas"
    elseif ehComboLavadoraSecadora then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Lavadora e Secadora"
    elseif ehLavadora then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Lavadora de Roupas"
    end

    local propriedadesObjeto = objetoEletrico:getProperties()
    if propriedadesObjeto then
        local nomeGrupo = propriedadesObjeto:has("GroupName") and propriedadesObjeto:get("GroupName") or nil
        local nomeCustomizado = propriedadesObjeto:has("CustomName") and propriedadesObjeto:get("CustomName") or nil
        if nomeGrupo and nomeCustomizado then
            nomeObjetoTraduzido = Translator.getMoveableDisplayName(nomeGrupo .. " " .. nomeCustomizado)
        elseif nomeCustomizado then
            nomeObjetoTraduzido = Translator.getMoveableDisplayName(nomeCustomizado)
        end
    end

    local temEnergia = false
    local containerInventario = objetoEletrico:getContainer()
    if containerInventario and containerInventario:isPowered() then
        temEnergia = true
    end

    local temAgua = true
    if ehLavadora then
        temAgua = objetoEletrico:getFluidAmount() > 0
    elseif ehComboLavadoraSecadora then
        if objetoEletrico:isModeWasher() then
            temAgua = objetoEletrico:getFluidAmount() > 0
        end
    end

    local direcao = nil
    if propriedadesObjeto and propriedadesObjeto:has("Facing") then
        direcao = propriedadesObjeto:get("Facing")
    end

    local texturaIconeMenu = obterTexturaEstado(chaveConfiguracao, temEnergia, temAgua, direcao)
    local estaAtivo = objetoEletrico:isActivated()

    -- Remove as opções nativas legadas do menu
    local nomeObjetoMinusculo = string.lower(nomeObjetoTraduzido)
    for indice = #menuContexto.options, 1, -1 do
        local opcao = menuContexto.options[indice]
        if opcao and opcao.name and string.lower(opcao.name) == nomeObjetoMinusculo then
            table.insert(menuContexto.optionPool, opcao)
            for j = indice + 1, #menuContexto.options do
                menuContexto.options[j-1] = menuContexto.options[j]
                menuContexto.options[j-1].id = j-1
            end
            menuContexto.options[#menuContexto.options] = nil
            menuContexto.numOptions = menuContexto.numOptions - 1
        end
    end
    menuContexto:calcHeight()

    local opcaoMenuPai = menuContexto:addOptionOnTop(nomeObjetoTraduzido)
    local submenu = ISContextMenu:getNew(menuContexto)
    menuContexto:addSubMenu(opcaoMenuPai, submenu)

    if texturaIconeMenu then
        opcaoMenuPai.iconTexture = texturaIconeMenu
    end

    local chaveTextoLigar = getText("ContextMenu_TurnOn") or "Ligar"
    local chaveTextoDesligar = getText("ContextMenu_TurnOff") or "Desligar"

    if estaAtivo then
        local opcaoDesligar = submenu:addOption(chaveTextoDesligar, objetosMundo, function()
            if ehSecadora then
                ISWorldObjectContextMenu.onToggleClothingDryer(objetosMundo, objetoEletrico, jogadorNumero)
            elseif ehComboLavadoraSecadora then
                ISWorldObjectContextMenu.onToggleComboWasherDryer(jogadorObjeto, objetoEletrico)
            elseif ehLavadora then
                ISWorldObjectContextMenu.onToggleClothingWasher(objetosMundo, objetoEletrico, jogadorNumero)
            end
        end)
        opcaoDesligar.iconTexture = getTexture("media/ui/LKS_Button_Power_Off.png")
    else
        if temEnergia and temAgua then
            local opcaoLigar = submenu:addOption(chaveTextoLigar, objetosMundo, function()
                if ehSecadora then
                    ISWorldObjectContextMenu.onToggleClothingDryer(objetosMundo, objetoEletrico, jogadorNumero)
                elseif ehComboLavadoraSecadora then
                    ISWorldObjectContextMenu.onToggleComboWasherDryer(jogadorObjeto, objetoEletrico)
                elseif ehLavadora then
                    ISWorldObjectContextMenu.onToggleClothingWasher(objetosMundo, objetoEletrico, jogadorNumero)
                end
            end)
            opcaoLigar.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")
        else
            local opcaoLigarSemRequisitos = submenu:addOption(chaveTextoLigar, objetosMundo, nil)
            opcaoLigarSemRequisitos.notAvailable = true

            if not temEnergia then
                opcaoLigarSemRequisitos.iconTexture = getTexture("media/ui/LKS_Menu_Electricity_Off.png")
            elseif not temAgua then
                opcaoLigarSemRequisitos.iconTexture = getTexture("media/ui/LKS_Menu_Water_Off.png")
            else
                opcaoLigarSemRequisitos.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")
            end

            local tooltipErro = ISWorldObjectContextMenu.addToolTip()
            tooltipErro:setName(nomeObjetoTraduzido)

            local mensagensErro = {}
            if not temEnergia then
                table.insert(mensagensErro, getText("IGUI_LKS_RequerEnergiaProxima") or "Requer uma fonte de energia próxima.")
            end
            if not temAgua then
                table.insert(mensagensErro, getText("IGUI_RequiresWaterSupply") or "Requer fornecimento de água.")
            end

            tooltipErro.description = table.concat(mensagensErro, "\n")
            opcaoLigarSemRequisitos.toolTip = tooltipErro
        end
    end

    if ehComboLavadoraSecadora then
        local rotuloModo = objetoEletrico:isModeWasher() and (getText("ContextMenu_ComboWasherDryer_SetModeDryer") or "Modo: Secagem") or (getText("ContextMenu_ComboWasherDryer_SetModeWasher") or "Modo: Lavadora")
        local opcaoModo = submenu:addOption(rotuloModo, objetosMundo, function()
            ISWorldObjectContextMenu.onSetComboWasherDryerMode(jogadorObjeto, objetoEletrico, objetoEletrico:isModeWasher() and "dryer" or "washer")
        end)
        opcaoModo.iconTexture = objetoEletrico:isModeWasher() and (ContainerButtonIcons.clothingdryer or getTexture("media/ui/Container_ClothingDryer.png")) or (ContainerButtonIcons.clothingwasher or getTexture("media/ui/Container_ClothingWasher.png"))

        -- Ciclo Automatico: lava + seca sem intervencao
        if not estaAtivo and temEnergia and temAgua then
            local containerMaquina = objetoEletrico:getContainer()
            local temItens = containerMaquina and not containerMaquina:isEmpty()
            local rotuloCicloAuto = getText("IGUI_LKS_Laundry_CicloAutomatico") or "Ciclo Automatico"
            local opcaoCicloAuto = submenu:addOption(rotuloCicloAuto, objetosMundo, function()
                local modData = objetoEletrico:getModData()
                if modData then
                    modData["LKS_Laundry_AutoCycle"] = true
                    modData["LKS_Laundry_Phase"] = "lavagem"
                end
                if ehComboLavadoraSecadora and not objetoEletrico:isModeWasher() then
                    ISWorldObjectContextMenu.onSetComboWasherDryerMode(jogadorObjeto, objetoEletrico, "washer")
                end
                ISWorldObjectContextMenu.onToggleComboWasherDryer(jogadorObjeto, objetoEletrico)
            end)
            opcaoCicloAuto.iconTexture = getTexture("media/ui/LKS_Menu_Ciclo_Automatico.png")
            if not temItens then
                opcaoCicloAuto.notAvailable = true
                opcaoCicloAuto.toolTip = ISWorldObjectContextMenu.addToolTip()
                opcaoCicloAuto.toolTip.description = getText("IGUI_LKS_Laundry_SemItens") or "Nenhum item dentro da maquina."
            end
        end
    end
end

-- Registro dinâmico no Appliance Manager
table.insert(LKS_ApplianceManager.devices, LKS_Device_Laundry)
for _, tipo in ipairs(LKS_Device_Laundry.recipientesAceitos) do
    LKS_ApplianceManager.containerTypeMap[tipo] = LKS_Device_Laundry
end
for _, classe in ipairs(LKS_Device_Laundry.classesJava) do
    LKS_ApplianceManager.javaClassMap[classe] = LKS_Device_Laundry
end

print("[LKS PATCH - LKS_Device_Laundry.lua] Carregado com sucesso!")
