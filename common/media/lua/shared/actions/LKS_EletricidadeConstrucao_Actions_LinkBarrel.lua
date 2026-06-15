-- ============================================================================
-- 🌟 LKS SUPERMOD PATCH — CRÉDITOS & AGRADECIMENTOS 🌟
-- ============================================================================
-- 💖 Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- 🛠️ Mod Original: Generator Powered Buildings (ID Workshop: 3597471949)
-- 👤 Autor Original: Beathoven
-- 🌐 Link: https://steamcommunity.com/sharedfiles/filedetails/?id=3597471949
-- 
-- Este mod só é possível graças a todos os modders que vieram antes de mim.
-- Um agradecimento especial ao autor por sua contribuição incrível à comunidade!
-- ============================================================================

-- ARQUIVO: LKS_EletricidadeConstrucao_Actions_LinkBarrel.lua
-- OBJETIVO: Ação temporizada para vincular ou desvincular barris de gasolina à rede de geradores.
-- Versão: 2.0.0-alpha
-- Data: 15 de Junho de 2026

require "TimedActions/ISBaseTimedAction"

--- Classe representando a ação temporizada de vínculo de barris.
--- @class LKS_EletricidadeConstrucao_LinkBarrelAction : ISBaseTimedAction
LKS_EletricidadeConstrucao_LinkBarrelAction = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_LinkBarrelAction")

--- Cria uma nova instância da ação temporizada para o jogador.
--- @param jogador IsoPlayer O personagem do jogador que executará a ação física.
--- @param barril IsoObject O objeto do barril de combustível no mundo.
--- @param quadrado IsoGridSquare O quadrado do mapa onde o barril está localizado.
--- @param identificadorConstrucao string O ID único da construção à qual o barril será vinculado.
--- @param estaVinculando boolean `true` para vincular ao reservatório, `false` para desvincular.
--- @return LKS_EletricidadeConstrucao_LinkBarrelAction A instância configurada da ação temporizada.
function LKS_EletricidadeConstrucao_LinkBarrelAction:new(jogador, barril, quadrado, identificadorConstrucao, estaVinculando)
    local objetoInstanciado = ISBaseTimedAction.new(self, jogador)
    setmetatable(objetoInstanciado, self)
    self.__index = self

    objetoInstanciado.player      = jogador
    objetoInstanciado.barrel      = barril
    objetoInstanciado.square      = quadrado
    objetoInstanciado.buildingID  = identificadorConstrucao
    objetoInstanciado.isLinking   = estaVinculando
    objetoInstanciado.maxTime     = 50  -- Cerca de 3 segundos em velocidade normal (50 ticks)

    return objetoInstanciado
end

--- Verifica se as condições para continuar a ação são válidas a cada tick.
--- @return boolean Retorna true se o quadrado e o barril existem no mundo e estão acessíveis.
function LKS_EletricidadeConstrucao_LinkBarrelAction:isValid()
    if not self.square or not self.barrel then return false end
    return self.square:getObjects():contains(self.barrel)
end

--- Gerencia o alinhamento do personagem antes do início da barra de progresso.
--- @return boolean Retorna true se o personagem ainda está rotacionando para encarar o alvo.
function LKS_EletricidadeConstrucao_LinkBarrelAction:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

--- Atualização lógica a cada tick de progresso da ação.
function LKS_EletricidadeConstrucao_LinkBarrelAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
end

--- Inicializa a ação temporizada e ativa as animações do personagem.
function LKS_EletricidadeConstrucao_LinkBarrelAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:reportEvent("EventLootItem")
end

--- Trata a interrupção prematura da ação.
function LKS_EletricidadeConstrucao_LinkBarrelAction:stop()
    ISBaseTimedAction.stop(self)
end

--- Executa as operações finais após o preenchimento da barra.
function LKS_EletricidadeConstrucao_LinkBarrelAction:perform()
    ISBaseTimedAction.perform(self)
end

--- Finaliza o ciclo da ação e aplica a lógica de negócio de rede de combustível.
--- @return boolean Retorna sempre true para indicar finalização lógica.
function LKS_EletricidadeConstrucao_LinkBarrelAction:complete()
    if not self.barrel then return true end

    local AmbienteExecucao = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local ehClienteMultiplayer = AmbienteExecucao and AmbienteExecucao.IsMultiplayerClient and AmbienteExecucao.IsMultiplayerClient()
    local podeResolverNoServidor = self.isLinking and ehClienteMultiplayer
    local quadrado = self.barrel:getSquare()
    
    if not self.buildingID and not podeResolverNoServidor then
        return true
    end

    -- ========================================================================
    -- EXECUÇÃO LADO DO SERVIDOR (OU SINGLEPLAYER)
    -- ========================================================================
    if isServer() or not isClient() then
        local Barris = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels
        local identificadorConstrucaoResolvido = self.buildingID
        
        -- Busca a construção atualmente vinculada ao barril se nenhuma foi informada
        if not identificadorConstrucaoResolvido and Barris and Barris.GetLinkedBuilding then
            identificadorConstrucaoResolvido = Barris.GetLinkedBuilding(self.barrel)
        end
        
        if not identificadorConstrucaoResolvido or not Barris then
            return true
        end

        -- Aplica o vínculo ou desvínculo
        if self.isLinking then
            local sucesso = Barris.Link(self.barrel, identificadorConstrucaoResolvido)
            if not sucesso then return true end
        else
            Barris.Unlink(self.barrel, identificadorConstrucaoResolvido)
        end

        -- Força a rede elétrica do prédio a recalcular o combustível
        local DistribuidorEnergia = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
        if DistribuidorEnergia then
            if DistribuidorEnergia.RefreshBuildingStats then
                DistribuidorEnergia.RefreshBuildingStats(identificadorConstrucaoResolvido)
            elseif DistribuidorEnergia.ForceUpdateBuilding then
                DistribuidorEnergia.ForceUpdateBuilding(identificadorConstrucaoResolvido)
            end
        end

        return true
    end

    -- ========================================================================
    -- EXECUÇÃO LADO DO CLIENTE (MULTIPLAYER)
    -- ========================================================================
    if not quadrado then return true end

    -- Transmite a solicitação ao servidor para execução coordenada
    sendClientCommand(self.player, "LKS_EletricidadeConstrucao", "BarrelLink", {
        bx         = quadrado:getX(),
        by         = quadrado:getY(),
        bz         = quadrado:getZ(),
        buildingID = self.buildingID,
        linking    = self.isLinking,
    })

    return true
end

return LKS_EletricidadeConstrucao_LinkBarrelAction
