-- ==========================================================================
-- LKS_Organizer_Handler.lua
-- Handler do botão "Guardar Itens" no painel de inventário do jogador.
-- Usa o sistema ISInventoryWindowContainerControls.AddHandler do B42.
-- ==========================================================================

require "ISUI/InventoryWindow/ISInventoryWindowControlHandler"
require "ISUI/InventoryWindow/ISInventoryWindowContainerControls"

local LKS_Organizer_Motor = require("LKS_Organizer_Motor")

--- Prefixo dos prints de debug.
local DEBUG_PREFIX = "[LKS_Organizer]"

-- ==========================================================================
-- DEFINIÇÃO DO HANDLER
-- ==========================================================================

ISInventoryWindowControlHandler_LKS_GuardarItens = ISInventoryWindowControlHandler:derive("ISInventoryWindowControlHandler_LKS_GuardarItens")
local Handler = ISInventoryWindowControlHandler_LKS_GuardarItens

--- Determina quando o botão deve aparecer.
---
--- Visível apenas no inventário do jogador (onCharacter), quando há pelo
--- menos 1 container favoritado na área e o inventário não está vazio.
---
--- @return boolean visivel True se o botão deve ser exibido.
function Handler:shouldBeVisible()
    if not self.inventoryWindow then return false end

    -- Só aparece no painel do jogador (esquerdo), não na Loot Window
    if not self.inventoryWindow.onCharacter then return false end

    -- Verificar se o inventário tem itens
    local jogador = getSpecificPlayer(self.playerNum)
    if not jogador then return false end

    local inventario = jogador:getInventory()
    if not inventario or inventario:isEmpty() then return false end

    return true
end

--- Retorna o controle ISButton com o texto traduzido.
---
--- @return ISButton controle O botão configurado.
function Handler:getControl()
    local textoGuardar = getText("IGUI_LKS_Organizer_GuardarItens")
    self.control = self:getButtonControl(textoGuardar)
    self.altColor = true
    return self.control
end

--- Executa a lógica de "Guardar Itens" ao clicar no botão.
---
--- Fluxo: scan → plano → enfileirar ações.
function Handler:perform()
    if isGamePaused() then return end

    local jogador = getSpecificPlayer(self.playerNum)
    if not jogador then return end

    print(DEBUG_PREFIX .. " Botao 'Guardar Itens' clicado pelo jogador " .. self.playerNum)

    -- 1. Scan de containers favoritados
    local containersFavoritados = LKS_Organizer_Motor.scanContainersFavoritados(jogador)

    if #containersFavoritados == 0 then
        -- Feedback: nenhum favorito
        local mensagem = getText("IGUI_LKS_Organizer_NenhumFavorito")
        jogador:Say(mensagem)
        print(DEBUG_PREFIX .. " Abortado: nenhum container favoritado encontrado")
        return
    end

    -- 2. Montar plano de transferência
    local plano, totalItens = LKS_Organizer_Motor.montarPlano(jogador, containersFavoritados)

    if totalItens == 0 then
        -- Feedback: nenhum item corresponde
        local mensagem = getText("IGUI_LKS_Organizer_NenhumItem")
        jogador:Say(mensagem)
        print(DEBUG_PREFIX .. " Abortado: nenhum item correspondente nos containers favoritados")
        return
    end

    -- 3. Limpar fila atual e executar plano
    ISTimedActionQueue.clear(jogador)
    LKS_Organizer_Motor.executarPlano(jogador, plano)

    print(DEBUG_PREFIX .. " Plano enviado para execucao: " .. totalItens .. " item(ns) para " .. #plano .. " container(s)")
end

--- Construtor do handler.
---
--- @return ISInventoryWindowControlHandler_LKS_GuardarItens instancia Nova instância.
function Handler:new()
    local o = ISInventoryWindowControlHandler.new(self)
    o.altColor = true
    return o
end

-- ==========================================================================
-- REGISTRO DO HANDLER
-- ==========================================================================

ISInventoryWindowContainerControls.AddHandler(ISInventoryWindowControlHandler_LKS_GuardarItens)

print(DEBUG_PREFIX .. " Handler 'Guardar Itens' registrado em ISInventoryWindowContainerControls")
