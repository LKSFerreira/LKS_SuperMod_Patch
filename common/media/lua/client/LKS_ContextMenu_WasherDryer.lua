-- ============================================================================
-- ARQUIVO: LKS_ContextMenu_WasherDryer.lua
-- EXTENSÃO: LKS SuperMod Patch (Aprimoramentos Elétricos e Visuais)
-- OBJETIVO: Gerenciamento cliente para ligar/desligar secadoras, lavadoras
--           e combo washer dryer. Inclui monkey patch de ícones da Loot Window.
-- ============================================================================

print("[LKS PATCH - LKS_ContextMenu_WasherDryer.lua] Carregando Menu de Contexto e Interfaces de Secadoras e Lavadoras...")

-- ============================================================================
-- ⚙️ TABELA CENTRALIZADA DE CONFIGURAÇÃO DE ÍCONES DE LAVANDERIA
-- Mapeia cada tipo de máquina aos seus ícones de estados de energia e água.
-- ============================================================================
local LKS_ConfiguracaoIconesLavanderia = {
    clothingdryer = {
        energizado    = nil,
        desenergizado = "media/ui/LKS_Container_ClothingDryer_Electricity_Off.png",
    },
    clothingwasher = {
        energizado    = nil,
        desenergizado = "media/ui/LKS_Container_ClothingWasher_Electricity_Off.png",
        sem_agua      = "media/ui/LKS_Container_ClothingWasher_Water_Off.png",
    },
    combo_washer_dryer = {
        energizado    = "media/ui/Combo_Washer_Dryer_Gray.png",
        desenergizado = "media/ui/Combo_Washer_Dryer_Gray_Electricity_Off.png",
        sem_agua      = "media/ui/Combo_Washer_Dryer_Gray_Water_Off.png",
    },
}

---@class LKS_ContextMenu_WasherDryer
LKS_ContextMenu_WasherDryer = {}

--- Constrói o menu de contexto sob clique direito para secadoras, lavadoras
--- e combo washer dryer.
---
--- **Exemplo:**
--- ```lua
--- Events.OnFillWorldObjectContextMenu.Add(LKS_ContextMenu_WasherDryer.Build)
--- ```
---
--- @param jogadorNumero number O índice do jogador local (0 a 3).
--- @param menuContexto ISContextMenu O menu de contexto sendo preenchido.
--- @param objetosMundo table A lista de objetos físicos clicados no mundo.
--- @param apenasTeste boolean Se true, indica que é apenas uma verificação de colisão/ação rápida.
function LKS_ContextMenu_WasherDryer.Build(jogadorNumero, menuContexto, objetosMundo, apenasTeste)
    if apenasTeste then return end

    local jogadorObjeto = getSpecificPlayer(jogadorNumero)
    if not jogadorObjeto or jogadorObjeto:isAsleep() then return end

    ---@type IsoObject
    local objetoEletrico = nil
    local isSecadora = false
    local isLavadora = false
    local isComboLavadoraSecadora = false

    -- A Combo herda de IsoClothingWasher no Java, então deve ser verificada ANTES
    for _, objeto in ipairs(objetosMundo) do
        if instanceof(objeto, "IsoClothingDryer") then
            objetoEletrico = objeto
            isSecadora = true
            break
        elseif instanceof(objeto, "IsoCombinationWasherDryer") then
            objetoEletrico = objeto
            isComboLavadoraSecadora = true
            break
        elseif instanceof(objeto, "IsoClothingWasher") then
            objetoEletrico = objeto
            isLavadora = true
            break
        end
    end

    if not objetoEletrico then return end

    -- Determina a chave de configuração baseada no tipo de objeto
    local chaveConfig = nil
    if isSecadora then
        chaveConfig = "clothingdryer"
    elseif isComboLavadoraSecadora then
        chaveConfig = "combo_washer_dryer"
    elseif isLavadora then
        chaveConfig = "clothingwasher"
    end

    local configIcone = LKS_ConfiguracaoIconesLavanderia[chaveConfig]

    ---@type Texture
    local texturaIconeMenu = nil
    local nomeObjetoTraduzido = ""

    if isSecadora then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Secadora de Roupas"
    elseif isComboLavadoraSecadora then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Lavadora e Secadora"
    elseif isLavadora then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Lavadora de Roupas"
    end

    -- Obter o nome de exibição traduzido e amigável baseado em propriedades móveis do objeto
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

    -- Verificar o fornecimento de eletricidade próximo ao aparelho
    local temEnergia = false
    local containerInventario = objetoEletrico:getContainer()
    if containerInventario and containerInventario:isPowered() then
        temEnergia = true
    end

    -- Validar a disponibilidade de água baseada no tipo de máquina e no modo atual
    local temAgua = true
    if isLavadora then
        temAgua = objetoEletrico:getFluidAmount() > 0
    elseif isComboLavadoraSecadora then
        -- O combo só exige água se estiver no modo Lavadora (Washer)
        if objetoEletrico:isModeWasher() then
            temAgua = objetoEletrico:getFluidAmount() > 0
        end
    end

    -- Seleciona a textura do ícone principal do menu com base nos estados de energia e água
    if not temEnergia then
        texturaIconeMenu = getTexture(configIcone.desenergizado)
    elseif not temAgua and configIcone.sem_agua then
        texturaIconeMenu = getTexture(configIcone.sem_agua)
    else
        if configIcone.energizado then
            texturaIconeMenu = getTexture(configIcone.energizado)
        else
            texturaIconeMenu = ContainerButtonIcons[chaveConfig]
        end
    end

    local estaAtivo = objetoEletrico:isActivated()

    -- Localizar e remover qualquer opção nativa que corresponda ao nome do objeto
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

    -- Criar nova opção no menu principal no topo (UX prioritária) e associar um submenu limpo e exclusivo
    local opcaoMenuPai = menuContexto:addOptionOnTop(nomeObjetoTraduzido)
    local subMenu = ISContextMenu:getNew(menuContexto)
    menuContexto:addSubMenu(opcaoMenuPai, subMenu)

    -- Atribuir o ícone 32x32 correspondente no menu principal
    if texturaIconeMenu then
        opcaoMenuPai.iconTexture = texturaIconeMenu
    end

    local chaveTextoLigar = getText("ContextMenu_TurnOn") or "Ligar"
    local chaveTextoDesligar = getText("ContextMenu_TurnOff") or "Desligar"

    if estaAtivo then
        -- Se o equipamento estiver funcionando, exibe a opção de Desligar com ícone Pwr_Off
        local opcaoDesligar = subMenu:addOption(chaveTextoDesligar, objetosMundo, function()
            if isSecadora then
                ISWorldObjectContextMenu.onToggleClothingDryer(objetosMundo, objetoEletrico, jogadorNumero)
            elseif isComboLavadoraSecadora then
                ISWorldObjectContextMenu.onToggleComboWasherDryer(jogadorObjeto, objetoEletrico)
            elseif isLavadora then
                ISWorldObjectContextMenu.onToggleClothingWasher(objetosMundo, objetoEletrico, jogadorNumero)
            end
        end)
        opcaoDesligar.iconTexture = getTexture("media/ui/LKS_Button_Power_Off.png")
    else
        -- Se o equipamento estiver desligado, exibe a opção de Ligar
        if temEnergia and temAgua then
            -- Cenário energizado e abastecido: Ligar com ícone Pwr_On e callback direto
            local opcaoLigar = subMenu:addOption(chaveTextoLigar, objetosMundo, function()
                if isSecadora then
                    ISWorldObjectContextMenu.onToggleClothingDryer(objetosMundo, objetoEletrico, jogadorNumero)
                elseif isComboLavadoraSecadora then
                    ISWorldObjectContextMenu.onToggleComboWasherDryer(jogadorObjeto, objetoEletrico)
                elseif isLavadora then
                    ISWorldObjectContextMenu.onToggleClothingWasher(objetosMundo, objetoEletrico, jogadorNumero)
                end
            end)
            opcaoLigar.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")
        else
            -- Cenário desenergizado ou sem água: Ligar em vermelho (notAvailable)
            local opcaoLigarSemRequisitos = subMenu:addOption(chaveTextoLigar, objetosMundo, nil)
            opcaoLigarSemRequisitos.notAvailable = true

            if not temEnergia then
                opcaoLigarSemRequisitos.iconTexture = getTexture(configIcone.desenergizado)
            elseif not temAgua and configIcone.sem_agua then
                opcaoLigarSemRequisitos.iconTexture = getTexture(configIcone.sem_agua)
            else
                opcaoLigarSemRequisitos.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")
            end

            -- Tooltip explicativo listando os requisitos faltantes (energia, água ou ambos)
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

    -- Se for Combo Washer Dryer, adiciona a opção de alternar entre os modos
    if isComboLavadoraSecadora then
        local labelModo = objetoEletrico:isModeWasher() and (getText("ContextMenu_ComboWasherDryer_SetModeDryer") or "Modo: Secadora") or (getText("ContextMenu_ComboWasherDryer_SetModeWasher") or "Modo: Lavadora")
        local opcaoModo = subMenu:addOption(labelModo, objetosMundo, function()
            ISWorldObjectContextMenu.onSetComboWasherDryerMode(jogadorObjeto, objetoEletrico, objetoEletrico:isModeWasher() and "dryer" or "washer")
        end)
        -- Aplica os ícones originais correspondentes nas abas laterais para diferenciar o modo no menu
        opcaoModo.iconTexture = objetoEletrico:isModeWasher() and (ContainerButtonIcons.clothingdryer or getTexture("media/ui/Container_ClothingDryer.png")) or (ContainerButtonIcons.clothingwasher or getTexture("media/ui/Container_ClothingWasher.png"))
    end
end

Events.OnFillWorldObjectContextMenu.Add(LKS_ContextMenu_WasherDryer.Build)

-- ============================================================================
-- 🎒 EXTENSÃO VISUAL DA LOOT WINDOW (MONKEY PATCH DE INVENTÁRIO)
-- Intercepta a atribuição do ícone de abas laterais na janela de inventário
-- para substituir dinamicamente o ícone do container baseado no estado elétrico.
-- Suporta: Secadora, Lavadora, Combo Washer Dryer.
-- ============================================================================

local originalAdicionarBotaoContainer = ISInventoryPage.addContainerButton

--- Adiciona e customiza o botão de aba lateral para contêineres na Loot Window.
---
--- Intercepta o processo padrão para injetar texturas personalizadas baseadas no
--- estado de energia do aparelho. Diferencia Combo Washer Dryer da lavadora comum
--- verificando a classe Java do objeto pai do container.
---
--- @param recipiente ItemContainer O contêiner associado à aba do inventário.
--- @param textura Texture A textura de fallback original do botão.
--- @param nome string O nome amigável do contêiner.
--- @param dicaContexto string O texto de dica explicativa (tooltip).
--- @return table O botão instanciado com a imagem atualizada.
function ISInventoryPage:addContainerButton(recipiente, textura, nome, dicaContexto)
    local botao = originalAdicionarBotaoContainer(self, recipiente, textura, nome, dicaContexto)
    if not botao or not recipiente then return botao end

    local recipienteTipo = recipiente:getType()

    -- Determina a chave de configuração baseada no tipo de contêiner e classe do objeto pai
    local chaveConfig = nil
    local objetoPai = recipiente:getParent()
    local isCombo = false

    if recipienteTipo == "clothingdryer" then
        chaveConfig = "clothingdryer"
    elseif recipienteTipo == "clothingwasher" then
        if objetoPai and instanceof(objetoPai, "IsoCombinationWasherDryer") then
            chaveConfig = "combo_washer_dryer"
            isCombo = true
        else
            chaveConfig = "clothingwasher"
        end
    end

    if not chaveConfig then return botao end

    local configIcone = LKS_ConfiguracaoIconesLavanderia[chaveConfig]

    if recipiente:isPowered() then
        -- Energizado: verifica se requer água e se tem água
        local temAgua = true
        if isCombo then
            if objetoPai and objetoPai:isModeWasher() then
                temAgua = objetoPai:getFluidAmount() > 0
            end
        elseif recipienteTipo == "clothingwasher" then
            if objetoPai then
                temAgua = objetoPai:getFluidAmount() > 0
            end
        end

        if not temAgua and configIcone.sem_agua then
            local imagemSemAgua = getTexture(configIcone.sem_agua)
            if imagemSemAgua then botao:setImage(imagemSemAgua) end
        elseif configIcone.energizado then
            local imagemEnergizada = getTexture(configIcone.energizado)
            if imagemEnergizada then botao:setImage(imagemEnergizada) end
        end
    else
        -- Desenergizado: aplica ícone off correspondente
        if configIcone.desenergizado then
            local imagemDesativada = getTexture(configIcone.desenergizado)
            if imagemDesativada then botao:setImage(imagemDesativada) end
        end
    end

    return botao
end

print("[LKS PATCH - LKS_ContextMenu_WasherDryer.lua] Carregado com sucesso!")
