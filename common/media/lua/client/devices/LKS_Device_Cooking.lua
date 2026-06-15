-- ============================================================================
-- ARQUIVO: LKS_Device_Cooking.lua
-- EXTENSÃO: LKS SuperMod Patch (Módulo de Comportamento de Culinária)
-- OBJETIVO: Driver de comportamento e texturas para fogões (Stoves) e
--           micro-ondas (Microwaves) no gerenciador LKS_ApplianceManager.
-- AUTOR: LKS FERREIRA & Antigravity AI
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 14/06/2026
-- ============================================================================

-- Inicialização defensiva do gerenciador para robustez de carregamento
LKS_ApplianceManager = LKS_ApplianceManager or {}
LKS_ApplianceManager.devices = LKS_ApplianceManager.devices or {}
LKS_ApplianceManager.containerTypeMap = LKS_ApplianceManager.containerTypeMap or {}
LKS_ApplianceManager.javaClassMap = LKS_ApplianceManager.javaClassMap or {}

if LKS_ApplianceManager.recursoAtivo and not LKS_ApplianceManager.recursoAtivo("CookingEnabled", true) then
    print("[LKS PATCH - LKS_Device_Cooking.lua] Culinária desativada no sandbox.")
    return
end

local LKS_Device_Cooking = {
    recipientesAceitos = {"stove", "microwave"},
    classesJava = {"IsoStove", "IsoMicrowave"}
}

local LKS_ConfiguracaoIconesCulinaria = {
    stove = {
        energizado    = nil,
        desenergizado = "media/ui/Container_Stove_Electricity_Off.png",
    },
    microwave = {
        energizado    = nil,
        desenergizado = "media/ui/Container_Microwave_Electricity_Off.png",
    },
}

--- Retorna a textura correspondente baseada nos estados de energia e tipo de contêiner.
---
--- @param chaveConfiguracao string O tipo de aparelho ("stove", "microwave").
--- @param temEnergia boolean Se o aparelho possui fornecimento elétrico ativo.
--- @return Texture O objeto de textura carregado do jogo.
local function obterTexturaEstado(chaveConfiguracao, temEnergia)
    local configuracaoIcone = LKS_ConfiguracaoIconesCulinaria[chaveConfiguracao]
    if not configuracaoIcone then return nil end

    if not temEnergia then
        return getTexture(configuracaoIcone.desenergizado)
    else
        return ContainerButtonIcons[chaveConfiguracao]
    end
end

--- Verifica se há objetos metálicos no interior do contêiner do micro-ondas.
---
--- @param containerInventario ItemContainer O contêiner de itens a inspecionar.
--- @return boolean contemMetal Retorna true se houver pelo menos um item metálico.
local function verificarPresencaMetal(containerInventario)
    if not containerInventario then return false end
    local itens = containerInventario:getItems()
    if not itens then return false end

    for indice = 0, itens:size() - 1 do
        local item = itens:get(indice)
        if item then
            -- Valida tags e propriedades de metal comuns do jogo base
            if item:isMetal() or (item:getMetalValue() and item:getMetalValue() > 0) then
                return true
            end
            -- Fallback para tipos conhecidos de latas e objetos metálicos
            local tipoItem = item:getType()
            if tipoItem == "TinCan" or tipoItem == "CannedSoup" or tipoItem == "CannedBeans" or tipoItem == "CannedPeaches" then
                return true
            end
        end
    end
    return false
end

--- Retorna a textura para a Loot Window baseada no estado de energia do recipiente.
---
--- @param recipiente ItemContainer O contêiner sendo desenhado.
--- @param recipienteTipo string O tipo do contêiner.
--- @param objetoPai IsoObject O objeto pai no mundo.
--- @param temEnergia boolean Se o contêiner possui energia elétrica ativa.
--- @return Texture A textura resolvida para o inventário.
function LKS_Device_Cooking.obterTexturaInventario(recipiente, recipienteTipo, objetoPai, temEnergia)
    local chaveConfiguracao = nil
    if recipienteTipo == "stove" then
        chaveConfiguracao = "stove"
    elseif recipienteTipo == "microwave" then
        chaveConfiguracao = "microwave"
    end

    if not chaveConfiguracao then return nil end
    return obterTexturaEstado(chaveConfiguracao, temEnergia)
end

--- Constrói o submenu premium para fogões e micro-ondas no mundo.
---
--- @param jogadorNumero number O índice do jogador local (0 a 3).
--- @param menuContexto ISContextMenu O menu de contexto sendo preenchido.
--- @param objetosMundo table A lista de objetos físicos clicados no mundo.
--- @param objetoEletrico IsoObject O objeto elétrico clicado.
function LKS_Device_Cooking.construirMenuContexto(jogadorNumero, menuContexto, objetosMundo, objetoEletrico)
    local ehFogao = instanceof(objetoEletrico, "IsoStove")
    local ehMicroondas = instanceof(objetoEletrico, "IsoMicrowave")

    local chaveConfiguracao = nil
    if ehFogao then
        chaveConfiguracao = "stove"
    elseif ehMicroondas then
        chaveConfiguracao = "microwave"
    end

    local nomeObjetoTraduzido = ""
    if ehFogao then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Fogão"
    elseif ehMicroondas then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Micro-ondas"
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

    local texturaIconeMenu = obterTexturaEstado(chaveConfiguracao, temEnergia)
    local estaAtivo = false
    if objetoEletrico.isActivated then
        estaAtivo = objetoEletrico:isActivated()
    elseif objetoEletrico.Activated then
        estaAtivo = objetoEletrico:Activated()
    end

    -- Remove as opções nativas obsoletas para fogão ou micro-ondas
    for indice = #menuContexto.options, 1, -1 do
        local opcao = menuContexto.options[indice]
        local nomeOpcao = opcao and opcao.name and string.lower(opcao.name) or nil
        if nomeOpcao and (string.find(nomeOpcao, "fogão") or string.find(nomeOpcao, "fogao") or string.find(nomeOpcao, "micro") or string.find(nomeOpcao, "oven") or string.find(nomeOpcao, "stove") or string.find(nomeOpcao, "microwave")) then
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
            if ehFogao then
                ISWorldObjectContextMenu.onToggleStove(objetosMundo, objetoEletrico, jogadorNumero)
            elseif ehMicroondas then
                ISWorldObjectContextMenu.onToggleMicrowave(objetosMundo, objetoEletrico, jogadorNumero)
            end
        end)
        opcaoDesligar.iconTexture = getTexture("media/ui/LKS_Button_Power_Off.png")

        if ehFogao then
            local tooltipInfo = ISWorldObjectContextMenu.addToolTip()
            tooltipInfo:setName(nomeObjetoTraduzido)
            local temperaturaAtual = objetoEletrico:getCurrentTemperature()
            local textoTemperatura = string.format(getText("IGUI_LKS_TemperaturaAtual") or "Temperatura Atual: %.1f°C", temperaturaAtual)
            local textoAlerta = " <RGB:1,0,0> " .. (getText("IGUI_LKS_AlertaEquipamentoAquecido") or "⚠️ CUIDADO: Equipamento aquecido! Risco de incêndio se deixado sem supervisão.")
            tooltipInfo.description = textoTemperatura .. "\n" .. textoAlerta
            opcaoDesligar.toolTip = tooltipInfo
        end
    else
        if temEnergia then
            local opcaoLigar = submenu:addOption(chaveTextoLigar, objetosMundo, function()
                if ehFogao then
                    ISWorldObjectContextMenu.onToggleStove(objetosMundo, objetoEletrico, jogadorNumero)
                elseif ehMicroondas then
                    ISWorldObjectContextMenu.onToggleMicrowave(objetosMundo, objetoEletrico, jogadorNumero)
                end
            end)
            opcaoLigar.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")

            if ehMicroondas and verificarPresencaMetal(containerInventario) then
                local tooltipAviso = ISWorldObjectContextMenu.addToolTip()
                tooltipAviso:setName(nomeObjetoTraduzido)
                tooltipAviso.description = " <RGB:1,1,0> " .. (getText("IGUI_LKS_AvisoMetalMicroondas") or "⚠️ AVISO: Contém objetos metálicos no interior! Risco de faíscas e incêndio.")
                opcaoLigar.toolTip = tooltipAviso
            end
        else
            local opcaoLigarSemRequisitos = submenu:addOption(chaveTextoLigar, objetosMundo, nil)
            opcaoLigarSemRequisitos.notAvailable = true

            local configuracaoIcone = LKS_ConfiguracaoIconesCulinaria[chaveConfiguracao]
            opcaoLigarSemRequisitos.iconTexture = getTexture(configuracaoIcone.desenergizado)

            local tooltipErro = ISWorldObjectContextMenu.addToolTip()
            tooltipErro:setName(nomeObjetoTraduzido)
            tooltipErro.description = getText("IGUI_LKS_RequerEnergiaProxima") or "Requer uma fonte de energia próxima."
            opcaoLigarSemRequisitos.toolTip = tooltipErro
        end
    end

    -- ============================================================================
    -- TODO: 💥 MECÂNICA AVANÇADA DE FÍSICA DE METAL NO MICRO-ONDAS
    -- Desenvolver nas próximas etapas os seguintes comportamentos para o micro-ondas:
    -- 1. Detecção de funcionamento ativo com metais no interior.
    -- 2. Após 2 segundos ligado, iniciar efeitos visuais/sonoros de faíscas ("pipocos" e "estalos").
    -- 3. Atingir o ápice de faíscas aos 5 segundos de funcionamento.
    -- 4. Consequências físicas aplicadas ao final do ciclo ou interrupção:
    --    - Redução progressiva de integridade do micro-ondas (25% de dano por ciclo).
    --    - Estragar qualquer tipo de comida no interior.
    --    - Danificar e quebrar utensílios não-preparados (ex: rádios de pilha, eletrônicos).
    -- 5. Sistema de filtragem fina de contêiner para permitir itens plausíveis
    --    (como roupas, calçados, tecidos) e rejeitar itens impossíveis (pneus, cadeiras).
    -- ============================================================================
end

-- Registro dinâmico no Appliance Manager
table.insert(LKS_ApplianceManager.devices, LKS_Device_Cooking)
for _, tipo in ipairs(LKS_Device_Cooking.recipientesAceitos) do
    LKS_ApplianceManager.containerTypeMap[tipo] = LKS_Device_Cooking
end
for _, classe in ipairs(LKS_Device_Cooking.classesJava) do
    LKS_ApplianceManager.javaClassMap[classe] = LKS_Device_Cooking
end

print("[LKS PATCH - LKS_Device_Cooking.lua] Carregado com sucesso!")
