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

-- ARQUIVO: LKS_EletricidadeConstrucao_Actions_DisconnectBuilding.lua
-- OBJETIVO: Ação Temporizada (TimedAction) para desconectar um gerador elétrico de uma construção.
-- Versão: 2.0.0-alpha
-- Data: 15 de Junho de 2026

-- Garante que o namespace principal exista
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Actions_DisconnectBuilding] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- Carrega dependência nativa do jogo
require "TimedActions/ISBaseTimedAction"

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_Actions_DisconnectBuilding", "2.0.0")

LKS_EletricidadeConstrucao.Actions = LKS_EletricidadeConstrucao.Actions or {}

-- ============================================================================
-- DEFINIÇÃO DA CLASSE DE AÇÃO TEMPORIZADA
-- ============================================================================

LKS_EletricidadeConstrucao_DisconnectBuilding = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_DisconnectBuilding")

--- Auxiliar interno para determinar se o personagem deve "falar" graficamente na tela.
--- @param ambienteExecucao table O contexto de execução atual.
--- @return boolean Retorna true se a mensagem deve ser dita graficamente.
local function DeveDizerAoPersonagem(ambienteExecucao)
    if not ambienteExecucao then return true end
    return not (ambienteExecucao.IsServer and ambienteExecucao.IsServer()
        and ambienteExecucao.IsMultiplayer and ambienteExecucao.IsMultiplayer())
end

--- Tenta orientar visualmente o personagem em direção ao gerador antes de operar.
--- @param personagem any O personagem do jogador (IsoPlayer).
--- @param gerador any O objeto do gerador (IsoGenerator).
--- @return boolean Retorna true se a operação de pcall ocorreu sem quebras.
local function TentarEncararGerador(personagem, gerador)
    if not personagem or not gerador then return false end
    return pcall(function()
        personagem:faceThisObject(gerador)
    end)
end

-- ============================================================================
-- VALIDAÇÕES
-- ============================================================================

function LKS_EletricidadeConstrucao_DisconnectBuilding:isValid()
    -- O gerador físico deve continuar existindo no mundo
    if not self.generator then return false end
    
    -- O gerador deve estar no mesmo quadrado
    local quadrado = self.generator:getSquare()
    if not quadrado then return false end
    
    -- O gerador deve estar conectado a uma piscina/malha ativa
    local dadosMod = self.generator:getModData()
    if not dadosMod.Gen_BuildingPoolID then return false end
    
    return true
end

function LKS_EletricidadeConstrucao_DisconnectBuilding:waitToStart()
    if not TentarEncararGerador(self.character, self.generator) then
        return false
    end
    return self.character:shouldBeTurning()
end

function LKS_EletricidadeConstrucao_DisconnectBuilding:update()
    TentarEncararGerador(self.character, self.generator)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

-- ============================================================================
-- ANIMAÇÕES
-- ============================================================================

function LKS_EletricidadeConstrucao_DisconnectBuilding:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function LKS_EletricidadeConstrucao_DisconnectBuilding:stop()
    ISBaseTimedAction.stop(self)
end

function LKS_EletricidadeConstrucao_DisconnectBuilding:perform()
    ISBaseTimedAction.perform(self)
end

-- ============================================================================
-- EXECUÇÃO DA AÇÃO
-- ============================================================================

function LKS_EletricidadeConstrucao_DisconnectBuilding:complete()
    local AmbienteExecucao = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local ehClienteMultiplayer = AmbienteExecucao and AmbienteExecucao.IsMultiplayerClient and AmbienteExecucao.IsMultiplayerClient()

    if ehClienteMultiplayer then
        local quadrado = self.generator and self.generator:getSquare()
        if quadrado and isClient() then
            sendClientCommand(self.character, "LKS_EletricidadeConstrucao", "DisconnectBuilding", {
                genX = quadrado:getX(),
                genY = quadrado:getY(),
                genZ = quadrado:getZ(),
            })
        end
        return true
    end

    local dadosMod = self.generator:getModData()
    local identificadorPoolConstrucao = dadosMod.Gen_BuildingPoolID
    
    if not identificadorPoolConstrucao then
        LKS_EletricidadeConstrucao.Warn("[DisconnectBuilding] O gerador não está acoplado a nenhuma construção")
        return true
    end
    
    LKS_EletricidadeConstrucao.Print("[DisconnectBuilding] Desconectando gerador eletrico da construcao: " .. identificadorPoolConstrucao)
    
    -- Desliga o gerador preventivamente antes de soltar a fiação elétrica
    if self.generator:isActivated() then
        self.generator:setActivated(false)
        
        -- Atualiza a rede elétrica
        if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            if LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
            end
        end
    end

    local quadrado = self.generator:getSquare()

    -- Remove as fontes térmicas vinculadas de imediato
    if LKS_EletricidadeConstrucao_HeatingClient and LKS_EletricidadeConstrucao_HeatingClient.Remove and quadrado then
        LKS_EletricidadeConstrucao_HeatingClient.Remove(quadrado:getX() .. "_" .. quadrado:getY() .. "_" .. quadrado:getZ())
    end
    
    local xGerador = quadrado and quadrado:getX() or 0
    local yGerador = quadrado and quadrado:getY() or 0
    local zGerador = quadrado and quadrado:getZ() or 0
    local chaveGerador = string.format("%d_%d_%d", xGerador, yGerador, zGerador)

    -- Se este gerador for o dono do pool (possuir LKS_EletricidadeConstrucao_PoolData) e houver outros
    -- geradores na piscina, transfere os metadados elétricos para o próximo gerador ativo
    if dadosMod.LKS_EletricidadeConstrucao_PoolData then
        local GerenciadorEstadoPre = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
        local dadosConstrucaoPre = GerenciadorEstadoPre and GerenciadorEstadoPre.GetBuilding and GerenciadorEstadoPre.GetBuilding(identificadorPoolConstrucao)
        if dadosConstrucaoPre and dadosConstrucaoPre.connectedGenerators then
            local celula = getCell and getCell()
            if celula then
                for _, chave in pairs(dadosConstrucaoPre.connectedGenerators) do
                    if chave ~= chaveGerador then
                        local coordenadaX, coordenadaY, coordenadaZ = string.match(chave, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        if coordenadaX then
                            local quadradoVizinho = celula:getGridSquare(tonumber(coordenadaX), tonumber(coordenadaY), tonumber(coordenadaZ))
                            if quadradoVizinho then
                                local objetosVizinho = quadradoVizinho:getObjects()
                                for indiceObjeto = 0, objetosVizinho:size() - 1 do
                                    local objetoVizinho = objetosVizinho:get(indiceObjeto)
                                    if objetoVizinho and instanceof(objetoVizinho, "IsoGenerator") then
                                        local dadosModVizinho = objetoVizinho:getModData()
                                        local proximoIdentificadorMundo = dadosMod.LKS_EletricidadeConstrucao_WorldId
                                        if not proximoIdentificadorMundo or proximoIdentificadorMundo == "unknown" then
                                            proximoIdentificadorMundo = LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId and
                                                                          LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId() or nil
                                        end
                                        if proximoIdentificadorMundo == "unknown" then
                                            proximoIdentificadorMundo = nil
                                        end
                                        dadosModVizinho.LKS_EletricidadeConstrucao_PoolData = dadosMod.LKS_EletricidadeConstrucao_PoolData
                                        dadosModVizinho.LKS_EletricidadeConstrucao_WorldId  = proximoIdentificadorMundo
                                        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                            objetoVizinho:transmitModData()
                                        end
                                        LKS_EletricidadeConstrucao.Print(string.format(
                                            "[DisconnectBuilding] Posse da malha elétrica transferida de %s para %s",
                                            chaveGerador, chave))
                                        break
                                    end
                                end
                            end
                        end
                        break -- Transfere ao primeiro gerador substituto
                    end
                end
            end
        end
    end

    -- Limpa todos os metadados elétricos associados à malha do ModData do gerador
    dadosMod.Gen_BuildingPoolID           = nil
    dadosMod.Gen_Stats_Consumers          = nil
    dadosMod.Gen_Stats_ActiveConsumers    = nil
    dadosMod.Gen_Stats_Lights             = nil
    dadosMod.Gen_Stats_ActiveLights       = nil
    dadosMod.Gen_Stats_Lamps              = nil
    dadosMod.Gen_Stats_ActiveLamps        = nil
    dadosMod.Gen_Stats_Appliances         = nil
    dadosMod.Gen_Stats_ActiveAppliances   = nil
    dadosMod.Gen_Stats_PowerDraw          = nil
    dadosMod.Gen_Stats_Strain             = nil
    dadosMod.Gen_Stats_FuelRateLph        = nil
    dadosMod.Gen_Stats_Powered            = nil
    dadosMod.LKS_EletricidadeConstrucao_DisconnectSuppressed      = true
    dadosMod.LKS_EletricidadeConstrucao_WorldId                   = nil
    dadosMod.LKS_EletricidadeConstrucao_PoolData                  = nil
    
    -- Transmite atualização aos clientes em Multiplayer
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        self.generator:transmitModData()
        if isServer() then
            self.generator:sync()
        end
    end

    local identificadorGerador = nil
    local GerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if GerenciadorEstado then
        identificadorGerador = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
                and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                and LKS_EletricidadeConstrucao.Data.Generator.MakeId(xGerador, yGerador, zGerador)

        -- Desvincula o gerador no gerenciador de estado antes de gravar o banco de dados
        local dadosGerador = identificadorGerador and GerenciadorEstado.GetGenerator(identificadorGerador)
        if not dadosGerador and LKS_EletricidadeConstrucao.Data
                and LKS_EletricidadeConstrucao.Data.Generator
                and LKS_EletricidadeConstrucao.Data.Generator.New then
            dadosGerador = LKS_EletricidadeConstrucao.Data.Generator.New(self.generator)
        end
        if dadosGerador then
            if LKS_EletricidadeConstrucao.Data
                    and LKS_EletricidadeConstrucao.Data.Generator
                    and LKS_EletricidadeConstrucao.Data.Generator.UpdateFromObject then
                LKS_EletricidadeConstrucao.Data.Generator.UpdateFromObject(dadosGerador, self.generator)
            end
            if LKS_EletricidadeConstrucao.Data
                    and LKS_EletricidadeConstrucao.Data.Generator
                    and LKS_EletricidadeConstrucao.Data.Generator.ClearBuildings then
                LKS_EletricidadeConstrucao.Data.Generator.ClearBuildings(dadosGerador)
            else
                dadosGerador.connectedBuildings = {}
                dadosGerador.strain = 0
            end
            if GerenciadorEstado.AddGenerator then
                if GerenciadorEstado.RemoveGenerator and dadosGerador.id then
                    GerenciadorEstado.RemoveGenerator(dadosGerador.id)
                end
                GerenciadorEstado.AddGenerator(dadosGerador)
            end
            GerenciadorEstado.MarkDirty()
        end
        
        -- Remove a chave do gerador na tabela connectedGenerators da construção
        local dadosConstrucao = GerenciadorEstado.GetBuilding(identificadorPoolConstrucao)
        if dadosConstrucao and dadosConstrucao.connectedGenerators then
            local novaLista = {}
            for _, valor in pairs(dadosConstrucao.connectedGenerators) do
                if valor ~= chaveGerador then 
                    table.insert(novaLista, valor) 
                end
            end
            dadosConstrucao.connectedGenerators = novaLista
            GerenciadorEstado.MarkDirty()
        end
    end

    -- Atualiza as lógicas de carga no distribuidor elétrico do mod
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
        if LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding then
            LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(identificadorPoolConstrucao)
        elseif LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
            LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
        end
    end

    -- Remove a conexão do gerenciador físico de fiações elétricas em tempo de execução
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager and quadrado then
        local identificadorConexao = LKS_EletricidadeConstrucao.Power.Manager.CreateConnectionId(xGerador, yGerador, zGerador, identificadorPoolConstrucao)
        if LKS_EletricidadeConstrucao.Power.Manager.DisconnectGeneratorFromBuilding then
            LKS_EletricidadeConstrucao.Power.Manager.DisconnectGeneratorFromBuilding(identificadorConexao)
        elseif LKS_EletricidadeConstrucao.Power.Manager.DisconnectGenerator then
            LKS_EletricidadeConstrucao.Power.Manager.DisconnectGenerator(identificadorConexao)
        end
    end

    -- Apaga a construção do banco de dados caso ela não possua nenhum gerador restante acoplado
    local GerenciadorEstadoAux = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if GerenciadorEstadoAux then
        local dadosConstrucaoAux = GerenciadorEstadoAux.GetBuilding(identificadorPoolConstrucao)
        if dadosConstrucaoAux and dadosConstrucaoAux.connectedGenerators and #dadosConstrucaoAux.connectedGenerators == 0 then
            GerenciadorEstadoAux.RemoveBuilding(identificadorPoolConstrucao)
            GerenciadorEstadoAux.MarkDirty()
        end
        
        -- Salva de imediato o novo estado no save
        GerenciadorEstadoAux.Save(true, true)
    end
    
    if DeveDizerAoPersonagem(AmbienteExecucao) then
        self.character:Say(getText("IGUI_DisconnectedFromBuilding") or "Desconectado do edifício")
    end
    
    return true
end

-- ============================================================================
-- DURAÇÃO E CONSTRUTOR
-- ============================================================================

function LKS_EletricidadeConstrucao_DisconnectBuilding:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    -- Desconectar leva em torno de 5 segundos físicos (50 ticks)
    return 50
end

function LKS_EletricidadeConstrucao_DisconnectBuilding:new(character, generator)
    local objetoInstanciado = ISBaseTimedAction.new(self, character)
    objetoInstanciado.character = character
    objetoInstanciado.generator = generator
    objetoInstanciado.stopOnWalk = true
    objetoInstanciado.stopOnRun = true
    objetoInstanciado.maxTime = objetoInstanciado:getDuration()
    return objetoInstanciado
end

-- ============================================================================
-- EXPORTAÇÃO PARA O NAMESPACE
-- ============================================================================

LKS_EletricidadeConstrucao.Actions.DisconnectBuilding = LKS_EletricidadeConstrucao_DisconnectBuilding

LKS_EletricidadeConstrucao.Print("Acao DisconnectBuilding carregada no namespace")
