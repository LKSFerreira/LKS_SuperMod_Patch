-- ============================================================================
-- ARQUIVO: LKS_ApplianceManager.lua
-- EXTENSÃO: LKS SuperMod Patch (Gerenciador e Kernel de Dispositivos Elétricos)
-- OBJETIVO: Kernel centralizador de registro de drivers, monkey patch unificado
--           de Loot Window e roteador dinâmico de cliques em objetos do mundo.
-- AUTOR: LKS FERREIRA & Antigravity AI
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 14/06/2026
-- ============================================================================

print("[LKS PATCH - LKS_ApplianceManager.lua] Carregando Gerenciador de Dispositivos e Eletrodomésticos do Mod...")

-- Inicialização defensiva para independência de ordem de carregamento
LKS_ApplianceManager = LKS_ApplianceManager or {}
LKS_ApplianceManager.devices = LKS_ApplianceManager.devices or {}
LKS_ApplianceManager.containerTypeMap = LKS_ApplianceManager.containerTypeMap or {}
LKS_ApplianceManager.javaClassMap = LKS_ApplianceManager.javaClassMap or {}

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

Events.OnFillWorldObjectContextMenu.Add(LKS_ApplianceManager.onFillWorldObjectContextMenu)

-- ============================================================================
-- 🎒 EXTENSÃO VISUAL DA LOOT WINDOW (MONKEY PATCH DE INVENTÁRIO UNIFICADO)
-- Intercepta a atribuição do ícone de abas laterais na janela de inventário
-- para substituir dinamicamente o ícone do container baseado no estado e direção.
-- ============================================================================

local funcaoOriginalAdicionarBotaoContainer = ISInventoryPage.addContainerButton

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
    if not driverAtivo then return botao end

    local objetoPai = recipiente:getParent()
    local temEnergia = recipiente:isPowered()

    if driverAtivo.obterTexturaInventario then
        local imagemEstado = driverAtivo.obterTexturaInventario(recipiente, recipienteTipo, objetoPai, temEnergia)
        if imagemEstado then
            botao:setImage(imagemEstado)
        end
    end

    return botao
end

print("[LKS PATCH - LKS_ApplianceManager.lua] Carregado com sucesso!")
