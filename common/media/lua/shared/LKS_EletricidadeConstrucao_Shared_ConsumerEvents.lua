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

-- ARQUIVO: LKS_EletricidadeConstrucao_Shared_ConsumerEvents.lua
-- OBJETIVO: Escutas e gatilhos de eventos compartilhados para aparelhos consumidores de energia.
-- DETALHE TÉCNICO: Posicionado na pasta 'shared/' para rodar tanto no escopo de simulação
-- do servidor quanto nos eventos gráficos (como OnObjectAdded) que disparam prioritariamente no cliente.
-- Versão: 2.0.0-alpha
-- Data: 15 de Junho de 2026

-- ============================================================================
-- AUXILIARES INTERNOS
-- ============================================================================

--- Verifica se um objeto nativo é um consumidor de energia que o mod deve rastrear.
--- @param objeto any O objeto de mapa nativo (IsoObject).
--- @return boolean Retorna true se for um aparelho rastreado.
local function EhConsumidorRastreado(objeto)
    if not objeto then return false end
    
    local possuiGeladeira  = objeto.getContainerByType and objeto:getContainerByType("fridge")  ~= nil
    local possuiCongelador = objeto.getContainerByType and objeto:getContainerByType("freezer") ~= nil
    
    return instanceof(objeto, "IsoLightSwitch")
        or instanceof(objeto, "IsoLight")
        or instanceof(objeto, "IsoClothingDryer")
        or instanceof(objeto, "IsoClothingWasher")
        or instanceof(objeto, "IsoCombinationWasherDryer")
        or instanceof(objeto, "IsoStackedWasherDryer")
        or instanceof(objeto, "IsoStove")
        or instanceof(objeto, "IsoTelevision")
        or instanceof(objeto, "IsoRadio")
        or possuiGeladeira
        or possuiCongelador
end

--- Verifica se todos os módulos necessários de servidor estão carregados.
--- @return boolean Retorna true se os submódulos de scanner e estado do core estiverem prontos.
local function PossuiModulosServidor()
    return LKS_EletricidadeConstrucao
        and LKS_EletricidadeConstrucao.Building
        and LKS_EletricidadeConstrucao.Building.ConsumerScanner
        and LKS_EletricidadeConstrucao.Building.ConsumerScanner.RescanConsumers ~= nil
        and LKS_EletricidadeConstrucao.Core
        and LKS_EletricidadeConstrucao.Core.StateManager
        and LKS_EletricidadeConstrucao.Core.StateManager.GetAllBuildings ~= nil
end

--- Varre e atualiza novamente todos os aparelhos de todas as construções cadastradas.
---
--- Recalcula o consumo elétrico e força o distribuidor a recalcular a carga da rede de cada prédio.
local function EscanearTodasConstrucoes()
    if not PossuiModulosServidor() then return end

    local construcoes = LKS_EletricidadeConstrucao.Core.StateManager.GetAllBuildings()
    if not construcoes then return end

    local contagemConstrucoes = 0
    for _, dadosConstrucao in pairs(construcoes) do
        LKS_EletricidadeConstrucao.Building.ConsumerScanner.RescanConsumers(dadosConstrucao)
        if LKS_EletricidadeConstrucao.Power
                and LKS_EletricidadeConstrucao.Power.Distributor
                and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding then
            LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(dadosConstrucao.id)
        end
        contagemConstrucoes = contagemConstrucoes + 1
    end

    if contagemConstrucoes > 0 and LKS_EletricidadeConstrucao.Core.Logger then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(
            string.format("ConsumerEvents: Re-escaneadas %d construcao(oes)", contagemConstrucoes),
            "Building")
    end
end

--- Verifica se o ambiente de execução atual é o host autoritativo (Servidor ou SP).
--- @return boolean Retorna true se for servidor dedicado ou singleplayer local.
local function EhAmbienteAutoritativo()
    local AmbienteExecucao = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    if not AmbienteExecucao then return false end
    
    if AmbienteExecucao.IsMultiplayerClient and AmbienteExecucao.IsMultiplayerClient() then
        return false
    end
    
    return (AmbienteExecucao.IsServer and AmbienteExecucao.IsServer())
        or (AmbienteExecucao.IsSingleplayer and AmbienteExecucao.IsSingleplayer())
end

--- Verifica se uma tabela informada está vazia ou nula.
--- @param tabela table|nil A tabela a testar.
--- @return boolean Retorna true se estiver vazia ou for nil.
local function TabelaEstaVazia(tabela)
    if not tabela then return true end
    for _ in pairs(tabela) do return false end
    return true
end

--- Remove os links de salvamento e referências de estado de um gerador removido física ou logicamente.
--- @param gerador any O objeto de gerador removido (IsoGenerator).
local function LimparEstadoGeradorRemovido(gerador)
    if not gerador or not instanceof(gerador, "IsoGenerator") then return end
    if not EhAmbienteAutoritativo() or not PossuiModulosServidor() then return end

    local GerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
    local DadosGerador = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
    if not GerenciadorEstado or not DadosGerador or not DadosGerador.MakeId then return end

    local quadrado = gerador:getSquare()
    if not quadrado then return end

    local identificadorGerador = DadosGerador.MakeId(quadrado:getX(), quadrado:getY(), quadrado:getZ())
    local chaveGerador = string.format("%d_%d_%d", quadrado:getX(), quadrado:getY(), quadrado:getZ())
    local dadosGerador = GerenciadorEstado.GetGenerator and GerenciadorEstado.GetGenerator(identificadorGerador)
    local dadosMod = gerador:getModData()
    local construcoesAfetadas = {}
    local houveAlteracao = false

    if dadosMod and dadosMod.Gen_BuildingPoolID then
        construcoesAfetadas[dadosMod.Gen_BuildingPoolID] = true
    end
    if dadosGerador and dadosGerador.connectedBuildings then
        for _, identificadorConstrucao in pairs(dadosGerador.connectedBuildings) do
            construcoesAfetadas[identificadorConstrucao] = true
        end
    end

    for identificadorConstrucao in pairs(construcoesAfetadas) do
        local dadosConstrucao = GerenciadorEstado.GetBuilding and GerenciadorEstado.GetBuilding(identificadorConstrucao)
        if dadosConstrucao and dadosConstrucao.connectedGenerators then
            local novaLista = {}
            local removido = false
            for _, chave in pairs(dadosConstrucao.connectedGenerators) do
                if chave ~= chaveGerador then
                    table.insert(novaLista, chave)
                else
                    removido = true
                end
            end
            if removido then
                dadosConstrucao.connectedGenerators = novaLista
                houveAlteracao = true
                if TabelaEstaVazia(novaLista) then
                    GerenciadorEstado.RemoveBuilding(identificadorConstrucao)
                else
                    GerenciadorEstado.MarkDirty()
                end
                if LKS_EletricidadeConstrucao.Core.Logger then
                    LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                        "[ConsumerEvents] Removido link órfão do gerador %s na construção %s",
                        chaveGerador, identificadorConstrucao), "Building")
                end
            end
        end
    end

    if dadosGerador and GerenciadorEstado.RemoveGenerator then
        GerenciadorEstado.RemoveGenerator(identificadorGerador)
        houveAlteracao = true
        if LKS_EletricidadeConstrucao.Core.Logger then
            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                "[ConsumerEvents] Removidos dados do gerador desinstalado no mundo %s",
                identificadorGerador), "Building")
        end
    end

    if houveAlteracao
            and LKS_EletricidadeConstrucao.Power
            and LKS_EletricidadeConstrucao.Power.Distributor
            and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding then
        for identificadorConstrucao in pairs(construcoesAfetadas) do
            if GerenciadorEstado.GetBuilding and GerenciadorEstado.GetBuilding(identificadorConstrucao) then
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(identificadorConstrucao)
            end
        end
    end

    if houveAlteracao and GerenciadorEstado.IsStateLoaded and GerenciadorEstado.IsStateLoaded() and GerenciadorEstado.Save then
        GerenciadorEstado.Save(true, false)
    end
end

-- ============================================================================
-- MANIPULADORES DOS EVENTOS DA ENGINE
-- ============================================================================

--- Dispara quando qualquer objeto físico é adicionado ou construído no mapa.
--- @param objeto any O objeto adicionado.
local function AoAdicionarObjeto(objeto)
    if not EhConsumidorRastreado(objeto) then return end
    EscanearTodasConstrucoes()
end

--- Gerencia a transferência de propriedade da piscina elétrica quando o gerador líder
--- é recolhido pelo jogador ou destruído.
---
--- Garante que a malha elétrica da construção permaneça operando se houver geradores secundários.
--- @param gerador any O gerador prestes a ser removido (IsoGenerator).
local function TratarGeradorPrestesASerRemovido(gerador)
    if not gerador or not instanceof(gerador, "IsoGenerator") then return end
    local dadosMod = gerador:getModData()
    
    -- Apenas geradores que representavam a propriedade do pool transferem seus dados
    if not (dadosMod and dadosMod.Gen_BuildingPoolID and dadosMod.LKS_EletricidadeConstrucao_PoolData) then return end

    local GerenciadorEstado = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not GerenciadorEstado then return end

    local identificadorPoolConstrucao = dadosMod.Gen_BuildingPoolID
    local quadrado = gerador:getSquare()
    if not quadrado then return end
    
    local chavePropria = string.format("%d_%d_%d", quadrado:getX(), quadrado:getY(), quadrado:getZ())
    local dadosConstrucao = GerenciadorEstado.GetBuilding and GerenciadorEstado.GetBuilding(identificadorPoolConstrucao)
    if not dadosConstrucao then return end

    local celula = getCell and getCell()
    if not celula then return end

    -- Percorre outros geradores conectados a esta construção para eleger um sucessor
    for _, chave in pairs(dadosConstrucao.connectedGenerators or {}) do
        if chave ~= chavePropria then
            local coordenadaX, coordenadaY, coordenadaZ = string.match(chave, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if coordenadaX then
                local quadradoVizinho = celula:getGridSquare(tonumber(coordenadaX), tonumber(coordenadaY), tonumber(coordenadaZ))
                if quadradoVizinho then
                    local objetosVizinhos = quadradoVizinho:getObjects()
                    for indiceObjeto = 0, objetosVizinhos:size() - 1 do
                        local objetoVizinho = objetosVizinhos:get(indiceObjeto)
                        if objetoVizinho and instanceof(objetoVizinho, "IsoGenerator") then
                            local dadosModVizinho = objetoVizinho:getModData()
                            local proximoIdentificadorMundo = dadosMod.LKS_EletricidadeConstrucao_WorldId
                            if not proximoIdentificadorMundo or proximoIdentificadorMundo == "unknown" then
                                proximoIdentificadorMundo = GerenciadorEstado.GetCurrentWorldId and GerenciadorEstado.GetCurrentWorldId() or nil
                            end
                            if proximoIdentificadorMundo == "unknown" then
                                proximoIdentificadorMundo = nil
                            end
                            
                            -- Transfere a propriedade do pool e seu ID do mundo
                            dadosModVizinho.LKS_EletricidadeConstrucao_PoolData = dadosMod.LKS_EletricidadeConstrucao_PoolData
                            dadosModVizinho.LKS_EletricidadeConstrucao_WorldId  = proximoIdentificadorMundo
                            
                            if LKS_EletricidadeConstrucao.Core.Runtime
                                    and LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync
                                    and LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                objetoVizinho:transmitModData()
                            end
                            
                            if LKS_EletricidadeConstrucao.Core.Logger then
                                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                    "[ConsumerEvents] Posse da malha elétrica transferida: %s -> %s para a construção %s",
                                    chavePropria, chave, identificadorPoolConstrucao), "Building")
                            end
                            break
                        end
                    end
                end
            end
            break -- Transfere ao primeiro sucessor válido disponível
        end
    end
end

--- Disparado imediatamente ANTES de um objeto nativo ser excluído ou recolhido.
--- @param objeto any O objeto a ser removido.
local function AoRemoverObjeto(objeto)
    if instanceof(objeto, "IsoGenerator") then
        TratarGeradorPrestesASerRemovido(objeto)
        LimparEstadoGeradorRemovido(objeto)
    end

    if not EhConsumidorRastreado(objeto) then return end
    
    -- Agenda a varredura para o próximo tick, garantindo que o objeto físico já tenha sumido do grid do PZ
    local function varreduraAtrasada()
        Events.OnTick.Remove(varreduraAtrasada)
        EscanearTodasConstrucoes()
    end
    Events.OnTick.Add(varreduraAtrasada)
end

-- ============================================================================
-- MONITORAMENTO CONTÍNUO DE INTERRUPTORES E ESTADOS ATIVOS
-- ============================================================================
-- Interruptores de iluminação nativos do PZ não disparam eventos de mod ao serem ativados.
-- Monitoramos periodicamente no OnTick para atualizar o InfoWindow dinamicamente.

local _ultimoHorarioVerificacaoEstadoAtivo = 0
local INTERVALO_VERIFICACAO_ESTADO_ATIVO  = 1    -- Em segundos físicos

--- Atualiza as flags de atividade (isActive) de todos os aparelhos sem refazer o scanner de paredes.
local function AtualizarEstadosAtivos()
    if not PossuiModulosServidor() then return end
    
    local DistribuidorEnergia = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
    local funcaoAtualizacao = DistribuidorEnergia and (DistribuidorEnergia.RefreshBuildingStats or DistribuidorEnergia.ForceUpdateBuilding)
    if not funcaoAtualizacao then return end

    local construcoes = LKS_EletricidadeConstrucao.Core.StateManager.GetAllBuildings()
    if not construcoes then return end

    for _, dadosConstrucao in pairs(construcoes) do
        funcaoAtualizacao(dadosConstrucao.id)
    end
end

--- Escuta de ticks gerais do PZ para rodar a atualização cronometrada de aparelhos.
local function AoProcessarTick()
    local agora = os.time()
    if agora - _ultimoHorarioVerificacaoEstadoAtivo >= INTERVALO_VERIFICACAO_ESTADO_ATIVO then
        _ultimoHorarioVerificacaoEstadoAtivo = agora
        AtualizarEstadosAtivos()
    end
end

-- ============================================================================
-- VÍNCULOS COM A ENGINE DO JOGO (EVENTS)
-- ============================================================================

if Events.OnObjectAdded then
    Events.OnObjectAdded.Add(AoAdicionarObjeto)
end
if Events.OnObjectAboutToBeRemoved then
    Events.OnObjectAboutToBeRemoved.Add(AoRemoverObjeto)
end
Events.OnTick.Add(AoProcessarTick)
