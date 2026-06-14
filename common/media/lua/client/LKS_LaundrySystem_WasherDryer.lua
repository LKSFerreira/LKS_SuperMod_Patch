-- ============================================================================
-- ARQUIVO: LKS_LaundrySystem_WasherDryer.lua
-- EXTENSÃO: LKS SuperMod Patch (Mecânicas, Comportamentos e Visuais de Lavanderia)
-- OBJETIVO: Gerenciamento cliente unificado para funcionamento, lógica e interface
--           de secadoras, lavadoras e combo washer dryer. Inclui suporte a
--           imagens direcionais individuais (Facing) e abas de inventário.
-- AUTOR: LKS FERREIRA & Antigravity AI
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 14/06/2026
-- ============================================================================

print("[LKS PATCH - LKS_LaundrySystem_WasherDryer.lua] Inicializando Sistema de Lavanderia e Gerenciador de Comportamento...")

-- ============================================================================
-- ⚙️ TABELA CENTRALIZADA DE CONFIGURAÇÃO DE ÍCONES DE LAVANDERIA
-- Mapeia cada tipo de máquina aos seus ícones de estados de energia, água e direção.
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
        energizado    = {
            S = "media/ui/Combo_Washer_Dryer_Gray_S.png",
            E = "media/ui/Combo_Washer_Dryer_Gray_E.png",
            N = "media/ui/Combo_Washer_Dryer_Gray_N.png",
            W = "media/ui/Combo_Washer_Dryer_Gray_W.png",
            padrao = "media/ui/Combo_Washer_Dryer_Gray.png"
        },
        desenergizado = "media/ui/Combo_Washer_Dryer_Gray_Electricity_Off.png",
        sem_agua      = "media/ui/Combo_Washer_Dryer_Gray_Water_Off.png",
    },
}

---@class LKS_LaundrySystem_WasherDryer
LKS_LaundrySystem_WasherDryer = {}

--- Retorna a textura correspondente baseada nos estados de energia, água e direção (Facing).
---
--- **Exemplo:**
--- ```lua
--- local textura = obterTexturaEstado("combo_washer_dryer", true, true, "N")
--- ```
---
--- @param chaveConfiguracao string O tipo de aparelho ("clothingdryer", "clothingwasher", "combo_washer_dryer").
--- @param temEnergia boolean Se o aparelho possui fornecimento elétrico ativo.
--- @param temAgua boolean Se o aparelho possui água disponível.
--- @param direcao string | nil A direção/facing do móvel ("N", "S", "E", "W").
--- @return Texture O objeto de textura carregado do jogo.
local function obterTexturaEstado(chaveConfiguracao, temEnergia, temAgua, direcao)
    local configuracaoIcone = LKS_ConfiguracaoIconesLavanderia[chaveConfiguracao]
    if not configuracaoIcone then return nil end

    if not temEnergia then
        return getTexture(configuracaoIcone.desenergizado)
    elseif not temAgua and configuracaoIcone.sem_agua then
        return getTexture(configuracaoIcone.sem_agua)
    else
        -- Energizado e com água suficiente
        if configuracaoIcone.energizado then
            if type(configuracaoIcone.energizado) == "table" then
                local caminhoTextura = configuracaoIcone.energizado[direcao] or configuracaoIcone.energizado.padrao
                return getTexture(caminhoTextura)
            else
                return getTexture(configuracaoIcone.energizado)
            end
        else
            return ContainerButtonIcons[chaveConfiguracao]
        end
    end
end

--- Constrói o menu de contexto sob clique direito para secadoras, lavadoras
--- e combo washer dryer no mundo.
---
--- **Exemplo:**
--- ```lua
--- Events.OnFillWorldObjectContextMenu.Add(LKS_LaundrySystem_WasherDryer.construirMenu)
--- ```
---
--- @param jogadorNumero number O índice do jogador local (0 a 3).
--- @param menuContexto ISContextMenu O menu de contexto sendo preenchido.
--- @param objetosMundo table A lista de objetos físicos clicados no mundo.
--- @param apenasTeste boolean Se true, indica que é apenas uma verificação rápida de colisão.
function LKS_LaundrySystem_WasherDryer.construirMenu(jogadorNumero, menuContexto, objetosMundo, apenasTeste)
    if apenasTeste then return end

    local jogadorObjeto = getSpecificPlayer(jogadorNumero)
    if not jogadorObjeto or jogadorObjeto:isAsleep() then return end

    ---@type IsoObject
    local objetoEletrico = nil
    local ehSecadora = false
    local ehLavadora = false
    local ehComboLavadoraSecadora = false

    -- A Combo herda de IsoClothingWasher no Java do jogo, portanto deve ser validada ANTES
    for _, objeto in ipairs(objetosMundo) do
        if instanceof(objeto, "IsoClothingDryer") then
            objetoEletrico = objeto
            ehSecadora = true
            break
        elseif instanceof(objeto, "IsoCombinationWasherDryer") then
            objetoEletrico = objeto
            ehComboLavadoraSecadora = true
            break
        elseif instanceof(objeto, "IsoClothingWasher") then
            objetoEletrico = objeto
            ehLavadora = true
            break
        end
    end

    if not objetoEletrico then return end

    -- Determina a chave de configuração baseada no tipo de objeto
    local chaveConfiguracao = nil
    if ehSecadora then
        chaveConfiguracao = "clothingdryer"
    elseif ehComboLavadoraSecadora then
        chaveConfiguracao = "combo_washer_dryer"
    elseif ehLavadora then
        chaveConfiguracao = "clothingwasher"
    end

    ---@type Texture
    local texturaIconeMenu = nil
    local nomeObjetoTraduzido = ""

    if ehSecadora then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Secadora de Roupas"
    elseif ehComboLavadoraSecadora then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Lavadora e Secadora"
    elseif ehLavadora then
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
    if ehLavadora then
        temAgua = objetoEletrico:getFluidAmount() > 0
    elseif ehComboLavadoraSecadora then
        -- O combo só exige água se estiver no modo Lavadora (Washer)
        if objetoEletrico:isModeWasher() then
            temAgua = objetoEletrico:getFluidAmount() > 0
        end
    end

    -- Obter direção (Facing) para carregar a textura direcional correspondente no menu
    local direcao = nil
    if propriedadesObjeto and propriedadesObjeto:has("Facing") then
        direcao = propriedadesObjeto:get("Facing")
    end

    -- Seleciona a textura do ícone principal do menu com base nos estados
    texturaIconeMenu = obterTexturaEstado(chaveConfiguracao, temEnergia, temAgua, direcao)

    local estaAtivo = objetoEletrico:isActivated()

    -- Localizar e remover qualquer opção nativa obsoleta que corresponda ao nome do objeto
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
    local submenu = ISContextMenu:getNew(menuContexto)
    menuContexto:addSubMenu(opcaoMenuPai, submenu)

    -- Atribuir o ícone correspondente no menu principal
    if texturaIconeMenu then
        opcaoMenuPai.iconTexture = texturaIconeMenu
    end

    local chaveTextoLigar = getText("ContextMenu_TurnOn") or "Ligar"
    local chaveTextoDesligar = getText("ContextMenu_TurnOff") or "Desligar"

    if estaAtivo then
        -- Se o equipamento estiver funcionando, exibe a opção de Desligar com ícone Pwr_Off
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
        -- Se o equipamento estiver desligado, exibe a opção de Ligar
        if temEnergia and temAgua then
            -- Cenário energizado e abastecido: Ligar com ícone Pwr_On e callback direto
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
            -- Cenário desenergizado ou sem água: Ligar em vermelho (notAvailable)
            local opcaoLigarSemRequisitos = submenu:addOption(chaveTextoLigar, objetosMundo, nil)
            opcaoLigarSemRequisitos.notAvailable = true

            local configuracaoIcone = LKS_ConfiguracaoIconesLavanderia[chaveConfiguracao]
            if not temEnergia then
                opcaoLigarSemRequisitos.iconTexture = getTexture(configuracaoIcone.desenergizado)
            elseif not temAgua and configuracaoIcone.sem_agua then
                opcaoLigarSemRequisitos.iconTexture = getTexture(configuracaoIcone.sem_agua)
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
    if ehComboLavadoraSecadora then
        local rotuloModo = objetoEletrico:isModeWasher() and (getText("ContextMenu_ComboWasherDryer_SetModeDryer") or "Modo: Secagem") or (getText("ContextMenu_ComboWasherDryer_SetModeWasher") or "Modo: Lavadora")
        local opcaoModo = submenu:addOption(rotuloModo, objetosMundo, function()
            ISWorldObjectContextMenu.onSetComboWasherDryerMode(jogadorObjeto, objetoEletrico, objetoEletrico:isModeWasher() and "dryer" or "washer")
        end)
        -- Aplica os ícones originais correspondentes nas abas laterais para diferenciar o modo no menu
        opcaoModo.iconTexture = objetoEletrico:isModeWasher() and (ContainerButtonIcons.clothingdryer or getTexture("media/ui/Container_ClothingDryer.png")) or (ContainerButtonIcons.clothingwasher or getTexture("media/ui/Container_ClothingWasher.png"))
    end
end

Events.OnFillWorldObjectContextMenu.Add(LKS_LaundrySystem_WasherDryer.construirMenu)

-- ============================================================================
-- 🎒 EXTENSÃO VISUAL DA LOOT WINDOW (MONKEY PATCH DE INVENTÁRIO)
-- Intercepta a atribuição do ícone de abas laterais na janela de inventário
-- para substituir dinamicamente o ícone do container baseado no estado e direção.
-- Suporta: Secadora, Lavadora, Combo Washer Dryer.
-- ============================================================================

local funcaoOriginalAdicionarBotaoContainer = ISInventoryPage.addContainerButton

--- Adiciona e customiza o botão de aba lateral para contêineres na Loot Window.
---
--- Intercepta o processo padrão para injetar texturas personalizadas baseadas no
--- estado de energia e água do aparelho, bem como na direção física (Facing) dele.
---
--- @param recipiente ItemContainer O contêiner associado à aba do inventário.
--- @param textura Texture A textura de fallback original do botão.
--- @param nome string O nome amigável do contêiner.
--- @param dicaContexto string O texto de dica explicativa (tooltip).
--- @return table O botão instanciado com a imagem updated.
function ISInventoryPage:addContainerButton(recipiente, textura, nome, dicaContexto)
    local botao = funcaoOriginalAdicionarBotaoContainer(self, recipiente, textura, nome, dicaContexto)
    if not botao or not recipiente then return botao end

    local recipienteTipo = recipiente:getType()
    local objetoPai = recipiente:getParent()
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

    if not chaveConfiguracao then return botao end

    local temEnergia = recipiente:isPowered()
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

    local imagemEstado = obterTexturaEstado(chaveConfiguracao, temEnergia, temAgua, direcao)
    if imagemEstado then
        botao:setImage(imagemEstado)
    end

    return botao
end

print("[LKS PATCH - LKS_LaundrySystem_WasherDryer.lua] Carregado com sucesso!")
