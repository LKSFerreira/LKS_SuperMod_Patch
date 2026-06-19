-- ============================================================================
-- ARQUIVO: LKS_ApplianceManager.lua
-- EXTENSÃO: LKS SuperMod Patch (Gerenciador e Kernel de Dispositivos Elétricos)
-- OBJETIVO: Kernel centralizador de registro de drivers, monkey patch unificado
--           de Loot Window e roteador dinâmico de cliques em objetos do mundo.
-- AUTOR: LKS FERREIRA & Antigravity AI
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 14/06/2026
-- ============================================================================

print("[LKS PATCH - LKS_ApplianceManager.lua] Carregando Gerenciador de Dispositivos e Eletrodomesticos do Mod...")

-- Inicialização defensiva para independência de ordem de carregamento
LKS_ApplianceManager = LKS_ApplianceManager or {}
LKS_ApplianceManager.devices = LKS_ApplianceManager.devices or {}
LKS_ApplianceManager.containerTypeMap = LKS_ApplianceManager.containerTypeMap or {}
LKS_ApplianceManager.javaClassMap = LKS_ApplianceManager.javaClassMap or {}

-- Tabela centralizada de intensidades de brilho para aparelhos inativos/desligados.
-- Representa a quantidade de brilho restante (multiplicador de cor RGB).
LKS_ApplianceManager.intensidadesBrilho = {
    escurece35 = 0.65, -- Itens Claros (reduz 35% de brilho)
    escurece25 = 0.75, -- Itens Médios (reduz 25% de brilho)
    escurece15 = 0.85, -- Itens Escuros (reduz 15% de brilho)
    padrao     = 0.75, -- Fallback se não configurado
}

-- Configuração centralizada de posição e escala dos badges no menu de contexto.
-- Ajustável em tempo real pela HUD de depuração (F9).
LKS_ApplianceManager.configBadgeMenu = {
    NoPower = { offsetX = -5, offsetY = 5, escala = 1.0 },
    NoWater = { offsetX = -5, offsetY = 5, escala = 1.0 },
    padrao  = { offsetX = 0, offsetY = 0, escala = 1.0 }
}

function LKS_ApplianceManager.recursoAtivo(nomeRecurso, valorPadrao)
    local opcoesSandbox = SandboxVars and SandboxVars.LKS_EletricidadeConstrucao or nil
    if opcoesSandbox and opcoesSandbox[nomeRecurso] ~= nil then
        return opcoesSandbox[nomeRecurso] == true
    end

    local configuracaoEletricidade = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Config or nil
    if configuracaoEletricidade and configuracaoEletricidade[nomeRecurso] ~= nil then
        return configuracaoEletricidade[nomeRecurso] == true
    end

    return valorPadrao ~= false
end

--- Constrói dinamicamente os submenus baseando-se no roteamento para o driver correspondente.
---
--- @param jogadorNumero number O índice do jogador local (0 a 3).
--- @param menuContexto ISContextMenu O menu de contexto sendo preenchido.
--- @param objetosMundo table A lista de objetos físicos clicados no mundo.
--- @param apenasTeste boolean Se true, indica que é apenas uma validação rápida de colisão.
function LKS_ApplianceManager.onFillWorldObjectContextMenu(jogadorNumero, menuContexto, objetosMundo, apenasTeste)
    if apenasTeste then return end

    local jogadorObjeto = getSpecificPlayer(jogadorNumero)
    if not jogadorObjeto or jogadorObjeto:isAsleep() then return end

    ---@type IsoObject
    local objetoEletrico = nil
    local driverAtivo = nil

    -- Roteamento por classe Java cadastrada no gerenciador
    for _, objeto in ipairs(objetosMundo) do
        for classeJava, driver in pairs(LKS_ApplianceManager.javaClassMap) do
            if instanceof(objeto, classeJava) then
                objetoEletrico = objeto
                driverAtivo = driver
                break
            end
        end
        if objetoEletrico then break end

        -- Fallback: Roteamento por tipo de contêiner se o objeto possui contêineres mapeados
        if objeto:getContainerCount() > 0 then
            local tipoRecipiente = objeto:getContainer():getType()
            local driver = LKS_ApplianceManager.containerTypeMap[tipoRecipiente]
            if driver then
                objetoEletrico = objeto
                driverAtivo = driver
                break
            end
        end
    end

    if not objetoEletrico or not driverAtivo then return end

    -- Delegação de comportamento de interface para o driver específico do aparelho
    if driverAtivo.construirMenuContexto then
        driverAtivo.construirMenuContexto(jogadorNumero, menuContexto, objetosMundo, objetoEletrico)
    end
end

local algumDriverAtivo = LKS_ApplianceManager.recursoAtivo("RefrigerationEnabled", true)
    or LKS_ApplianceManager.recursoAtivo("LaundryEnabled", true)
    or LKS_ApplianceManager.recursoAtivo("CookingEnabled", true)

if algumDriverAtivo then
    Events.OnFillWorldObjectContextMenu.Add(LKS_ApplianceManager.onFillWorldObjectContextMenu)
end

-- ============================================================================
-- 🎛️ EXTENSÃO VISUAL DO MENU DE CONTEXTO (MONKEY PATCH DE ISCRONTEXTMENU)
-- NOTA DE ARQUITETURA: Esta abordagem foi comentada e descontinuada porque a
-- manipulação dinâmica de escala/posição de texturas em tempo real degradava a
-- qualidade visual dos ícones renderizados no menu de contexto do Zomboid.
-- Em seu lugar, adotou-se o uso de imagens estáticas dedicadas pré-montadas,
-- como LKS_Menu_Electricity_Off.png e LKS_Menu_Water_Off.png diretamente nos drivers.
-- ============================================================================

--[[
if algumDriverAtivo then
    local funcaoOriginalRenderContexto = ISContextMenu.render

    function ISContextMenu:render()
        -- Oculta badges LKS do render padrão para evitar dupla renderização
        local opcoesComBadge = {}
        for _, opcao in ipairs(self.options) do
            local tex = opcao.iconTexture
            if tex then
                local isBadge = false
                local badgeKey = opcao.lksBadgeKey
                if not badgeKey then
                    local ok, name = pcall(function() return tex:getName() end)
                    if ok and name then
                        if string.find(name, "LKS_Badge_NoPower") then
                            badgeKey = "NoPower"
                        elseif string.find(name, "LKS_Badge_NoWater") then
                            badgeKey = "NoWater"
                        end
                    end
                end
                if badgeKey then
                    opcao.lksBadgeKey = badgeKey
                    opcao.lksBadgeTextura = tex
                    isBadge = true
                end
            end
            if opcao.lksBadgeTextura then
                table.insert(opcoesComBadge, opcao)
                opcao._lksIconBackup = opcao.iconTexture
                opcao.iconTexture = nil
            end
        end

        funcaoOriginalRenderContexto(self)

        -- Renderiza badges LKS com offset e escala configuráveis
        if #opcoesComBadge > 0 then
            local scrollY = self:getYScroll() or 0
            local alturaItem = self.itemHgt or 24

            for _, opcao in ipairs(opcoesComBadge) do
                opcao.iconTexture = opcao._lksIconBackup
                opcao._lksIconBackup = nil

                local texBadge = opcao.lksBadgeTextura
                if texBadge then
                    local indiceOpcao = 0
                    for indice, opcaoLista in ipairs(self.options) do
                        if opcaoLista == opcao then
                            indiceOpcao = indice - 1
                            break
                        end
                    end

                    local key = opcao.lksBadgeKey or "padrao"
                    local config = LKS_ApplianceManager.configBadgeMenu[key] or
                        LKS_ApplianceManager.configBadgeMenu.padrao
                    local escala = config.escala
                    local larguraEscalada = texBadge:getWidth() * escala
                    local alturaEscalada = texBadge:getHeight() * escala

                    local baseX = 5
                    local baseY = scrollY + indiceOpcao * alturaItem

                    local drawX = baseX + config.offsetX
                    local drawY = baseY + (alturaItem - alturaEscalada) / 2 + config.offsetY

                    self:drawTextureScaledAspect(texBadge, drawX, drawY, larguraEscalada, alturaEscalada, 1.0, 1, 1, 1)
                end
            end
        end
    end
end
--]]

-- ============================================================================
-- 🎒 EXTENSÃO VISUAL DA LOOT WINDOW (MONKEY PATCH DE INVENTÁRIO UNIFICADO)
-- Intercepta a atribuição do ícone de abas laterais na janela de inventário
-- para substituir dinamicamente o ícone do container baseado no estado e direção.
-- ============================================================================

if algumDriverAtivo then
    local funcaoOriginalAdicionarBotaoContainer = ISInventoryPage.addContainerButton

    -- Helper para validar se o recipiente e seu objeto pai pertencem a um eletrodoméstico do mod
    local function isAparelhoValido(recipiente, recipienteTipo, objetoPai)
        if not recipiente or not recipienteTipo then return false end
        if not objetoPai or instanceof(objetoPai, "IsoPlayer") or instanceof(objetoPai, "IsoGridSquare") then
            return false
        end

        local driver = LKS_ApplianceManager.containerTypeMap[recipienteTipo]
        if not driver then return false end

        -- Verifica por classes Java mapeadas
        for classeJava, _ in pairs(LKS_ApplianceManager.javaClassMap) do
            if instanceof(objetoPai, classeJava) then
                return true
            end
        end

        -- Suporte a geladeiras/congeladores que usam contêineres padrões sem classe Java própria
        if recipienteTipo == "fridge" or recipienteTipo == "freezer" or 
           recipienteTipo == "geladeira_desligada" or recipienteTipo == "congelador_desligado" or 
           recipienteTipo == "fridge_off" or recipienteTipo == "freezer_off" then
            if objetoPai:getContainerCount() > 0 then
                return true
            end
        end

        return false
    end

    --- Adiciona e customiza o botão de aba lateral para contêineres na Loot Window.
    ---
    --- Intercepta o processo padrão para injetar texturas personalizadas baseadas no
    --- estado de energia e água do aparelho despachando a lógica ao driver registrado.
    ---
    --- @param recipiente ItemContainer O contêiner associado à aba do inventário.
    --- @param textura Texture A textura de fallback original do botão.
    --- @param nome string O nome amigável do contêiner.
    --- @param dicaContexto string O texto de dica explicativa (tooltip).
    --- @return table O botão instanciado com a imagem atualizada.
    function ISInventoryPage:addContainerButton(recipiente, textura, nome, dicaContexto)
        local botao = funcaoOriginalAdicionarBotaoContainer(self, recipiente, textura, nome, dicaContexto)
        if not botao or not recipiente then return botao end

        local recipienteTipo = recipiente:getType()
        local driverAtivo = LKS_ApplianceManager.containerTypeMap[recipienteTipo]
        local objetoPai = recipiente:getParent()

        if not driverAtivo or not isAparelhoValido(recipiente, recipienteTipo, objetoPai) then
            botao.lksRecipiente = nil
            botao.lksRecipienteTipo = nil
            botao.lksObjetoPai = nil
            return botao
        end

        local temEnergia = recipiente:isPowered()

        if driverAtivo.obterTexturaInventario then
            local imagemEstado = driverAtivo.obterTexturaInventario(recipiente, recipienteTipo, objetoPai, temEnergia)
            if imagemEstado then
                botao:setImage(imagemEstado)
            end
        end

        -- Injeta referências de dados no botão para renderização dinâmica
        botao.lksRecipiente = recipiente
        botao.lksRecipienteTipo = recipienteTipo
        botao.lksObjetoPai = objetoPai

        if not botao.lksHooked then
            botao.lksHooked = true
            local funcaoOriginalRender = botao.render
            botao.render = function(self)
                local recipienteObj = self.lksRecipiente
                local parentObj = self.lksObjetoPai
                local tipoRecipiente = self.lksRecipienteTipo

                if not recipienteObj or not isAparelhoValido(recipienteObj, tipoRecipiente, parentObj) then
                    funcaoOriginalRender(self)
                    return
                end

                local powered = recipienteObj:isPowered()

                -- Se tiver energia, verifica se requer água e está sem água
                local precisaAgua = false
                local temAgua = true
                if tipoRecipiente == "clothingwasher" then
                    precisaAgua = true
                    if parentObj then
                        if instanceof(parentObj, "IsoCombinationWasherDryer") then
                            if parentObj.isModeWasher and parentObj:isModeWasher() then
                                temAgua = parentObj:getFluidAmount() > 0
                            end
                        else
                            temAgua = parentObj:getFluidAmount() > 0
                        end
                    end
                end

                local escurecer = not powered or (precisaAgua and not temAgua)
                local imgOriginal = self.image

                if escurecer and imgOriginal then
                    self.image = nil
                end

                -- Renderiza o fundo do botão e outros elementos nativos
                funcaoOriginalRender(self)

                if escurecer and imgOriginal then
                    self.image = imgOriginal
                    local imgW = imgOriginal:getWidth()
                    local imgH = imgOriginal:getHeight()
                    local drawX = (self.width - imgW) / 2
                    local drawY = (self.height - imgH) / 2
                    -- Resolve o driver ativo do recipiente para buscar sua configuração de escurecimento
                    local driverAtivo = LKS_ApplianceManager.containerTypeMap[tipoRecipiente]
                    local categoriaBrilho = driverAtivo and driverAtivo.brilhoInativo or "padrao"
                    local brilho = LKS_ApplianceManager.intensidadesBrilho[categoriaBrilho] or
                        LKS_ApplianceManager.intensidadesBrilho.padrao
                    -- Desenha a imagem base modulada com o fator de brilho configurado no driver
                    self:drawTexture(imgOriginal, drawX, drawY, 1.0, brilho, brilho, brilho)
                end

                -- Se estiver sem energia, desenha o badge de falta de energia no canto em brilho total
                if not powered then
                    local texRaio = getTexture("media/ui/LKS_Badge_NoPower.png")
                    if texRaio then
                        self:drawTexture(texRaio, (self.width - 32) / 2, (self.height - 32) / 2, 1.0, 1, 1, 1)
                    end
                elseif precisaAgua and not temAgua then
                    -- Se tiver energia, mas estiver sem água, desenha o badge de falta de água em brilho total
                    local texGota = getTexture("media/ui/LKS_Badge_NoWater.png")
                    if texGota then
                        self:drawTexture(texGota, (self.width - 32) / 2, (self.height - 32) / 2, 1.0, 1, 1, 1)
                    end
                end
            end
        end

        return botao
    end
end

print("[LKS PATCH - LKS_ApplianceManager.lua] Carregado com sucesso!")
