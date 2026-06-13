-- ============================================================================
-- ARQUIVO: LKS_ContextMenu_WasherDryer.lua
-- EXTENSÃO: LKS SuperMod Patch (Aprimoramentos Elétricos e Visuais)
-- OBJETIVO: Gerenciamento cliente para ligar/desligar secadoras e lavadoras.
-- ============================================================================

print("[LKS PATCH - LKS_ContextMenu_WasherDryer.lua] Carregando Menu de Contexto e Interfaces de Secadoras e Lavadoras...")


---@class LKS_ContextMenu_WasherDryer
LKS_ContextMenu_WasherDryer = {}

--- Constrói o menu de contexto sob clique direito para secadoras e lavadoras de roupas.
---
--- Esta função intercepta a criação de menus de contexto do mundo para ajustar a lógica
--- de energia de aparelhos e atualizar os ícones de tomada e inventário.
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
    local eSecadora = false
    local eLavadora = false

    for _, objeto in ipairs(objetosMundo) do
        if instanceof(objeto, "IsoClothingDryer") then
            objetoEletrico = objeto
            eSecadora = true
            break
        elseif instanceof(objeto, "IsoClothingWasher") then
            objetoEletrico = objeto
            eLavadora = true
            break
        end
    end

    if not objetoEletrico then return end

    ---@type Texture
    local texturaIconeMenu = nil
    local texturaIconeDesligadoSemEnergia = nil
    local nomeObjetoTraduzido = ""

    if eSecadora then
        texturaIconeMenu = ContainerButtonIcons.clothingdryer or getTexture("media/ui/Container_ClothingDryer.png")
        texturaIconeDesligadoSemEnergia = "media/ui/LKS_Container_ClothingDryer_Eletricity_Off.png"
        nomeObjetoTraduzido = objetoEletrico:getName() or "Secadora de Roupas"
    elseif eLavadora then
        texturaIconeMenu = ContainerButtonIcons.clothingwasher or getTexture("media/ui/Container_ClothingWasher.png")
        texturaIconeDesligadoSemEnergia = "media/ui/LKS_Container_ClothingWasher_Eletricity_Off.png"
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

    -- Lavadoras de roupas exigem fornecimento de água no reservatório para funcionar no PZ B42
    local temAgua = true
    if eLavadora then
        temAgua = objetoEletrico:getFluidAmount() > 0
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

    -- Atribuir o ícone 32x32 correspondente ao inventário no menu principal
    if texturaIconeMenu then
        opcaoMenuPai.iconTexture = texturaIconeMenu
    end

    local chaveTextoLigar = getText("ContextMenu_TurnOn") or "Ligar"
    local chaveTextoDesligar = getText("ContextMenu_TurnOff") or "Desligar"

    if estaAtivo then
        -- Se o equipamento estiver funcionando, exibe a opção de Desligar com ícone Pwr_Off
        local opcaoDesligar = subMenu:addOption(chaveTextoDesligar, objetosMundo, function()
            if eSecadora then
                ISWorldObjectContextMenu.onToggleClothingDryer(objetosMundo, objetoEletrico, jogadorNumero)
            elseif eLavadora then
                ISWorldObjectContextMenu.onToggleClothingWasher(objetosMundo, objetoEletrico, jogadorNumero)
            end
        end)
        opcaoDesligar.iconTexture = getTexture("media/ui/LKS_Pwr_Off.png")
    else
        -- Se o equipamento estiver desligado, exibe a opção de Ligar
        if temEnergia and temAgua then
            -- Cenário energizado e abastecido: Ligar com ícone Pwr_On e callback direto
            local opcaoLigar = subMenu:addOption(chaveTextoLigar, objetosMundo, function()
                if eSecadora then
                    ISWorldObjectContextMenu.onToggleClothingDryer(objetosMundo, objetoEletrico, jogadorNumero)
                elseif eLavadora then
                    ISWorldObjectContextMenu.onToggleClothingWasher(objetosMundo, objetoEletrico, jogadorNumero)
                end
            end)
            opcaoLigar.iconTexture = getTexture("media/ui/LKS_Pwr_On.png")
        else
            -- Cenário desenergizado ou sem água: Ligar em vermelho (notAvailable)
            local opcaoLigarSemRequisitos = subMenu:addOption(chaveTextoLigar, objetosMundo, nil)
            opcaoLigarSemRequisitos.notAvailable = true

            if not temEnergia then
                opcaoLigarSemRequisitos.iconTexture = getTexture(texturaIconeDesligadoSemEnergia)
            else
                opcaoLigarSemRequisitos.iconTexture = getTexture("media/ui/LKS_Pwr_On.png")
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
end

Events.OnFillWorldObjectContextMenu.Add(LKS_ContextMenu_WasherDryer.Build)

-- ============================================================================
-- 🎒 EXTENSÃO VISUAL DA LOOT WINDOW (MONKEY PATCH DE INVENTÁRIO)
-- Intercepta a atribuição do ícone de abas laterais na janela de inventário
-- para substituir dinamicamente o ícone do container se estiver sem energia.
-- ============================================================================

local originalAdicionarBotaoContainer = ISInventoryPage.addContainerButton

--- Adiciona e customiza o botão de aba lateral para contêineres na Loot Window.
---
--- Intercepta o processo padrão para injetar texturas personalizadas desenergizadas
--- caso o recipiente seja uma secadora ou lavadora de roupas sem energia.
---
--- **Exemplo:**
--- ```lua
--- local botao = ISInventoryPage:addContainerButton(recipiente, textura, "Secadora", nil)
--- ```
---
--- @param recipiente ItemContainer O contêiner associado à aba do inventário.
--- @param textura Texture A textura de fallback original do botão.
--- @param nome string O nome amigável do contêiner.
--- @param dicaContexto string O texto de dica explicativa (tooltip).
--- @return table O botão instanciado com a imagem atualizada.
function ISInventoryPage:addContainerButton(recipiente, textura, nome, dicaContexto)
    local botao = originalAdicionarBotaoContainer(self, recipiente, textura, nome, dicaContexto)
    if botao and recipiente then
        local recipienteTipo = recipiente:getType()
        if recipienteTipo == "clothingdryer" or recipienteTipo == "clothingwasher" then
            if not recipiente:isPowered() then
                local imagemDesativada
                if recipienteTipo == "clothingdryer" then
                    imagemDesativada = getTexture("media/ui/LKS_Container_ClothingDryer_Eletricity_Off.png")
                else
                    imagemDesativada = getTexture("media/ui/LKS_Container_ClothingWasher_Eletricity_Off.png")
                end
                if imagemDesativada then
                    botao:setImage(imagemDesativada)
                end
            end
        end
    end
    return botao
end

print("[LKS PATCH - LKS_ContextMenu_WasherDryer.lua] Carregado com sucesso!")


