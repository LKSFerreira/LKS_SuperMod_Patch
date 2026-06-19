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

-- ARQUIVO: LKS_EletricidadeConstrucao_Actions_ConnectBuilding.lua
-- OBJETIVO: Ação Temporizada (TimedAction) para conectar um gerador a um edifício físico.
-- DETALHE TÉCNICO: Dispara o scanner de paredes e cômodos para registrar a malha de consumidores.
-- Versão: 2.0.0-alpha
-- Data: 15 de Junho de 2026

-- Garante que o namespace principal exista
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Actions_ConnectBuilding] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- Carrega dependência nativa do jogo
require "TimedActions/ISBaseTimedAction"

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_Actions_ConnectBuilding", "2.0.0")

LKS_EletricidadeConstrucao.Actions = LKS_EletricidadeConstrucao.Actions or {}

-- ============================================================================
-- DEFINIÇÃO DA CLASSE DE AÇÃO TEMPORIZADA
-- ============================================================================

LKS_EletricidadeConstrucao_ConnectBuilding = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_ConnectBuilding")

--- Auxiliar interno para determinar se o personagem deve "falar" no console ou chat gráfico.
--- @param ambienteExecucao table O contexto técnico do mod.
--- @return boolean Retorna true se a mensagem por voz gráfica deve ser exibida.
local function DeveDizerAoPersonagem(ambienteExecucao)
    if not ambienteExecucao then return true end
    return not (ambienteExecucao.IsServer and ambienteExecucao.IsServer()
        and ambienteExecucao.IsMultiplayer and ambienteExecucao.IsMultiplayer())
end

-- ============================================================================
-- VALIDAÇÕES
-- ============================================================================

function LKS_EletricidadeConstrucao_ConnectBuilding:isValid()
    -- O gerador deve existir no mundo
    if not self.generator then return false end

    -- O gerador deve estar presente em um quadrado de mapa válido
    local quadrado = self.generator:getSquare()
    if not quadrado then return false end

    -- O gerador não pode estar conectado a uma malha elétrica de construção
    local dadosMod = self.generator:getModData()
    if dadosMod.Gen_BuildingPoolID then return false end

    return true
end

function LKS_EletricidadeConstrucao_ConnectBuilding:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

function LKS_EletricidadeConstrucao_ConnectBuilding:update()
    self.character:faceThisObject(self.generator)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

-- ============================================================================
-- ANIMAÇÃO
-- ============================================================================

function LKS_EletricidadeConstrucao_ConnectBuilding:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function LKS_EletricidadeConstrucao_ConnectBuilding:stop()
    ISBaseTimedAction.stop(self)
end

function LKS_EletricidadeConstrucao_ConnectBuilding:perform()
    ISBaseTimedAction.perform(self)
end

-- ============================================================================
-- FUNÇÕES DE SUPORTE
-- ============================================================================

--- Procura por um quadrado com definição de construção (edifício) adjacente ao gerador.
--- @param quadradoGerador any O quadrado no qual o gerador está posicionado.
--- @return any|nil Retorna o quadrado da construção adjacente ou nil.
local function LocalizarQuadradoConstrucao(quadradoGerador)
    if not quadradoGerador then return nil end

    if quadradoGerador:getBuilding() then
        return quadradoGerador
    end

    local direcoes = {
        IsoDirections.N, IsoDirections.S, IsoDirections.E, IsoDirections.W,
        IsoDirections.NE, IsoDirections.NW, IsoDirections.SE, IsoDirections.SW
    }

    for _, direcao in ipairs(direcoes) do
        local quadradoAdjacente = quadradoGerador:getAdjacentSquare(direcao)
        if quadradoAdjacente and quadradoAdjacente:getBuilding() then
            return quadradoAdjacente
        end
    end

    return nil
end

--- Procura nas salas de uma construção por um interruptor de luz (IsoLightSwitch).
--- @param construcao any O objeto de construção da engine.
--- @param andarZ number O nível de andar Z correspondente.
--- @return integer|nil, integer|nil, integer|nil As coordenadas X, Y, Z do primeiro interruptor localizado.
local function LocalizarInterruptorLuzConstrucao(construcao, andarZ)
    if not construcao then return nil end
    local definicaoConstrucao = construcao.getDef and construcao:getDef()
    if not definicaoConstrucao then return nil end
    local salas = definicaoConstrucao.getRooms and definicaoConstrucao:getRooms()
    if not salas then return nil end

    local melhorX, melhorY, melhorZ = nil, nil, nil

    local function ConsiderarCandidato(coordenadaX, coordenadaY, coordenadaZ)
        if melhorX == nil
                or coordenadaZ < melhorZ
                or (coordenadaZ == melhorZ and coordenadaY < melhorY)
                or (coordenadaZ == melhorZ and coordenadaY == melhorY and coordenadaX < melhorX) then
            melhorX, melhorY, melhorZ = coordenadaX, coordenadaY, coordenadaZ
        end
    end

    for indiceSala = 0, salas:size() - 1 do
        local sala = salas:get(indiceSala)
        if sala then
            for salaX = sala:getX(), sala:getX2() do
                for salaY = sala:getY(), sala:getY2() do
                    local quadrado = getCell():getGridSquare(salaX, salaY, andarZ)
                    if quadrado then
                        local objetos = quadrado:getObjects()
                        for indiceObjeto = 0, objetos:size() - 1 do
                            local objeto = objetos:get(indiceObjeto)
                            if objeto and instanceof(objeto, "IsoLightSwitch") then
                                ConsiderarCandidato(salaX, salaY, andarZ)
                            end
                        end
                    end
                end
            end
        end
    end

    return melhorX, melhorY, melhorZ
end

--- Conta a quantidade de elementos presentes em uma tabela genérica.
--- @param tabela table|nil A tabela a avaliar.
--- @return integer A quantidade de itens na tabela.
local function ContarElementos(tabela)
    local contagem = 0
    if not tabela then return contagem end
    for _ in pairs(tabela) do
        contagem = contagem + 1
    end
    return contagem
end

--- Verifica se coordenadas específicas estão dentro dos limites da caixa delimitadora do prédio.
--- @param dadosConstrucao table Os dados de representação do prédio.
--- @param coordenadaX number Coordenada X física.
--- @param coordenadaY number Coordenada Y física.
--- @return boolean Retorna true se estiver posicionado dentro dos limites do prédio.
local function EstaDentroDaCaixaDelimitadora(dadosConstrucao, coordenadaX, coordenadaY)
    local caixaDelimitadora = dadosConstrucao and dadosConstrucao.boundingBox
    if type(caixaDelimitadora) ~= "table" then return false end

    local xMinimo = tonumber(caixaDelimitadora.minX or caixaDelimitadora[1])
    local yMinimo = tonumber(caixaDelimitadora.minY or caixaDelimitadora[2])
    local xMaximo = tonumber(caixaDelimitadora.maxX or caixaDelimitadora[3])
    local yMaximo = tonumber(caixaDelimitadora.maxY or caixaDelimitadora[4])
    if not (xMinimo and yMinimo and xMaximo and yMaximo) then
        return false
    end

    return coordenadaX >= (xMinimo - 1) and coordenadaX <= (xMaximo + 1)
       and coordenadaY >= (yMinimo - 1) and coordenadaY <= (yMaximo + 1)
end

--- Retorna o objeto de construção Java da engine a partir de suas coordenadas âncora.
--- @param dadosConstrucao table Os dados de representação do prédio.
--- @return any O objeto de construção nativo da engine.
local function ObterConstrucaoIsoDaAncora(dadosConstrucao)
    if not dadosConstrucao or dadosConstrucao.x == nil or dadosConstrucao.y == nil then
        return nil
    end

    local celula = getCell and getCell()
    if not celula then
        return nil
    end

    local quadrado = celula:getGridSquare(
        tonumber(dadosConstrucao.x),
        tonumber(dadosConstrucao.y),
        tonumber(dadosConstrucao.z) or 0
    )

    return quadrado and quadrado:getBuilding() or nil
end

--- Tenta localizar uma construção no estado correspondente a mesma pegada física.
--- @param construcao any O objeto de construção da engine.
--- @param quadradoConstrucao any O quadrado de mapa que contém as coordenadas da construção.
--- @param identificadorConstrucaoCandidata string O ID candidato para registro.
--- @return string|nil, table|nil O ID e dados da construção correspondente existente.
local function LocalizarConstrucaoExistenteCorrespondente(construcao, quadradoConstrucao, identificadorConstrucaoCandidata)
    local GerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not GerenciadorEstado or not GerenciadorEstado.GetAllBuildings or not quadradoConstrucao then
        return nil
    end

    local todasConstrucoes = GerenciadorEstado.GetAllBuildings()
    if not todasConstrucoes then
        return nil
    end

    local buscaX, buscaY = quadradoConstrucao:getX(), quadradoConstrucao:getY()
    local definicaoConstrucao = construcao and construcao.getDef and construcao:getDef()
    local construcaoIsoCandidata = quadradoConstrucao:getBuilding() or construcao
    local origemX = definicaoConstrucao and definicaoConstrucao.getX and definicaoConstrucao:getX() or nil
    local origemY = definicaoConstrucao and definicaoConstrucao.getY and definicaoConstrucao:getY() or nil
    
    local identificadorReserva, dadosReserva = nil, nil

    for identificadorConstrucao, dadosConstrucao in pairs(todasConstrucoes) do
        if identificadorConstrucao ~= identificadorConstrucaoCandidata then
            local construcaoIsoExistente = ObterConstrucaoIsoDaAncora(dadosConstrucao)

            if construcaoIsoCandidata and construcaoIsoExistente then
                if construcaoIsoExistente == construcaoIsoCandidata then
                    return identificadorConstrucao, dadosConstrucao
                end
            elseif EstaDentroDaCaixaDelimitadora(dadosConstrucao, buscaX, buscaY) then
                return identificadorConstrucao, dadosConstrucao
            end

            if origemX and origemY and LKS_EletricidadeConstrucao.Data
                    and LKS_EletricidadeConstrucao.Data.Building
                    and LKS_EletricidadeConstrucao.Data.Building.ParseId then
                local construcaoX, construcaoY = LKS_EletricidadeConstrucao.Data.Building.ParseId(identificadorConstrucao)
                if construcaoX == origemX and construcaoY == origemY then
                    identificadorReserva, dadosReserva = identificadorConstrucao, dadosConstrucao
                end
            end
        end
    end

    return identificadorReserva, dadosReserva
end

-- ============================================================================
-- EXECUÇÃO DA AÇÃO
-- ============================================================================

function LKS_EletricidadeConstrucao_ConnectBuilding:complete()
    local AmbienteExecucao = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local ehClienteMultiplayer = AmbienteExecucao and AmbienteExecucao.IsMultiplayerClient and AmbienteExecucao.IsMultiplayerClient()

    if ehClienteMultiplayer then
        local quadrado = self.generator and self.generator:getSquare()
        if quadrado and isClient() then
            sendClientCommand(self.character, "LKS_EletricidadeConstrucao", "ConnectBuilding", {
                genX = quadrado:getX(),
                genY = quadrado:getY(),
                genZ = quadrado:getZ(),
            })
        end
        return true
    end

    local quadradoGerador = self.generator:getSquare()
    if not quadradoGerador then
        LKS_EletricidadeConstrucao.Error("[ConnectBuilding] Quadrado do gerador nao localizado")
        return true
    end

    local quadradoConstrucao = LocalizarQuadradoConstrucao(quadradoGerador)
    if not quadradoConstrucao then
        if DeveDizerAoPersonagem(AmbienteExecucao) then
            self.character:Say(getText("IGUI_NoBuildingNearby") or "Nenhuma construção próxima")
        end
        return true
    end

    local construcao = quadradoConstrucao:getBuilding()
    if not construcao then
        LKS_EletricidadeConstrucao.Error("[ConnectBuilding] Objeto de construcao da engine nao encontrado")
        return true
    end

    -- Cria um ID de pool de rede estável usando a coordenada âncora canônica bld_X_Y_Z
    local definicaoConstrucao = construcao.getDef and construcao:getDef()
    local interruptorX0, interruptorY0, interruptorZ0 = LocalizarInterruptorLuzConstrucao(construcao, quadradoConstrucao:getZ())

    local identificadorConstrucao
    if interruptorX0 then
        identificadorConstrucao = string.format("bld_%d_%d_%d", interruptorX0, interruptorY0, interruptorZ0)
        LKS_EletricidadeConstrucao.Print("[ConnectBuilding] ID canonico obtido do interruptor: " .. identificadorConstrucao)
    elseif definicaoConstrucao and definicaoConstrucao.getX and definicaoConstrucao.getY then
        identificadorConstrucao = string.format("bld_%d_%d_%d", definicaoConstrucao:getX(), definicaoConstrucao:getY(), quadradoConstrucao:getZ())
        LKS_EletricidadeConstrucao.Print("[ConnectBuilding] ID de reserva obtido da origem da construcao: " .. identificadorConstrucao)
    else
        identificadorConstrucao = string.format("bld_%d_%d_%d", quadradoConstrucao:getX(), quadradoConstrucao:getY(), quadradoConstrucao:getZ())
        LKS_EletricidadeConstrucao.Warn("[ConnectBuilding] ID de emergencia obtido de buildingSquare: " .. identificadorConstrucao)
    end

    local GerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local dadosConstrucao = GerenciadorEstado and GerenciadorEstado.GetBuilding(identificadorConstrucao)

    local quantidadeGeradoresPool = ContarElementos(dadosConstrucao and dadosConstrucao.connectedGenerators)
    if not dadosConstrucao or quantidadeGeradoresPool == 0 then
        local identificadorConstrucaoExistente, dadosConstrucaoExistente = LocalizarConstrucaoExistenteCorrespondente(
            construcao,
            quadradoConstrucao,
            identificadorConstrucao
        )

        if identificadorConstrucaoExistente and dadosConstrucaoExistente then
            if dadosConstrucao and quantidadeGeradoresPool == 0 and identificadorConstrucao ~= identificadorConstrucaoExistente
                    and GerenciadorEstado and GerenciadorEstado.RemoveBuilding then
                GerenciadorEstado.RemoveBuilding(identificadorConstrucao)
            end

            identificadorConstrucao = identificadorConstrucaoExistente
            dadosConstrucao = dadosConstrucaoExistente
            LKS_EletricidadeConstrucao.Print(string.format(
                "[ConnectBuilding] Reaproveitando construção existente %s para pegada física coincidente (consumidores: %d, consumo: %.1f)",
                identificadorConstrucao, dadosConstrucao.totalConsumers or 0, dadosConstrucao.totalPowerDraw or 0))
        end
    end

    -- Vincula o identificador do pool ao gerador
    local dadosMod = self.generator:getModData()
    dadosMod.Gen_BuildingPoolID = identificadorConstrucao
    dadosMod.LKS_EletricidadeConstrucao_DisconnectSuppressed = nil

    -- Valida capacidade do pool antes de prosseguir (limite máximo de 10 geradores por prédio)
    if dadosConstrucao and dadosConstrucao.connectedGenerators then
        local quadradoGeradorAux = self.generator:getSquare()
        local chaveGerador = quadradoGeradorAux and string.format("%d_%d_%d", 
            quadradoGeradorAux:getX(), quadradoGeradorAux:getY(), quadradoGeradorAux:getZ()) or nil
        
        local tamanhoPool = 0
        local jaEstaNoPool = false
        for _, chave in pairs(dadosConstrucao.connectedGenerators) do
            tamanhoPool = tamanhoPool + 1
            if chave == chaveGerador then
                jaEstaNoPool = true
            end
        end
        
        local maximoGeradores = (LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.BUILDING 
                              and LKS_EletricidadeConstrucao.Constants.BUILDING.MAX_GENERATORS_PER_BUILDING) or 10
        
        if not jaEstaNoPool and tamanhoPool >= maximoGeradores then
            dadosMod.Gen_BuildingPoolID = nil -- Desfaz o vínculo
            if DeveDizerAoPersonagem(AmbienteExecucao) then
                self.character:Say(string.format("Piscina cheia (%d/%d geradores)", tamanhoPool, maximoGeradores))
            end
            LKS_EletricidadeConstrucao.Warn(string.format(
                "[ConnectBuilding] Limite de piscina atingido: %d/%d geradores na construção %s",
                tamanhoPool, maximoGeradores, identificadorConstrucao))
            return true
        end
    end

    -- Registra o identificador do mundo atual para compatibilidade e isolamento de saves
    if GerenciadorEstado and GerenciadorEstado.GetCurrentWorldId then
        local identificadorMundoAtual = GerenciadorEstado.GetCurrentWorldId()
        if identificadorMundoAtual and identificadorMundoAtual ~= "unknown" then
            dadosMod.LKS_EletricidadeConstrucao_WorldId = identificadorMundoAtual
        end
    end

    -- Caso a construção ainda não esteja no banco de dados, realiza o scan completo de salas e consumidores
    if not dadosConstrucao and LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner
            and LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding then

        local interruptorX, interruptorY, interruptorZ = interruptorX0, interruptorY0, interruptorZ0
        if not interruptorX then
            interruptorX, interruptorY, interruptorZ = LocalizarInterruptorLuzConstrucao(construcao, quadradoConstrucao:getZ())
        end

        if interruptorX and interruptorY and interruptorZ then
            dadosConstrucao = LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(
                interruptorX, interruptorY, interruptorZ, identificadorConstrucao)
        end
    end

    if not dadosConstrucao and GerenciadorEstado and GerenciadorEstado.GetBuilding then
        dadosConstrucao = GerenciadorEstado.GetBuilding(identificadorConstrucao)
    end

    -- Garante que o gerador esteja devidamente indexado no gerenciador de estado
    local quadradoGeradorFisico = self.generator:getSquare()
    if quadradoGeradorFisico and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
            and LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator then
        local xGerador, yGerador, zGerador = quadradoGeradorFisico:getX(), quadradoGeradorFisico:getY(), quadradoGeradorFisico:getZ()
        local identificadorGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(xGerador, yGerador, zGerador)
        local dadosGerador = LKS_EletricidadeConstrucao.Core.StateManager.GetGenerator(identificadorGerador)
        if not dadosGerador then
            dadosGerador = LKS_EletricidadeConstrucao.Data.Generator.New(self.generator)
        end
        dadosGerador.connectedBuildings = dadosGerador.connectedBuildings or {}
        if LKS_EletricidadeConstrucao.Data.Generator.AddBuilding then
            LKS_EletricidadeConstrucao.Data.Generator.AddBuilding(dadosGerador, identificadorConstrucao)
        else
            local possuiConstrucaoID = false
            for _, chaveConstrucao in pairs(dadosGerador.connectedBuildings) do
                if chaveConstrucao == identificadorConstrucao then 
                    possuiConstrucaoID = true
                    break 
                end
            end
            if not possuiConstrucaoID then
                table.insert(dadosGerador.connectedBuildings, identificadorConstrucao)
            end
        end
        LKS_EletricidadeConstrucao.Core.StateManager.AddGenerator(dadosGerador)
    end

    -- Adiciona a chave deste gerador à lista de geradores conectados da construção
    if dadosConstrucao then
        if quadradoGeradorFisico then
            local chaveGerador = string.format("%d_%d_%d",
                quadradoGeradorFisico:getX(), quadradoGeradorFisico:getY(), quadradoGeradorFisico:getZ())
            dadosConstrucao.connectedGenerators = dadosConstrucao.connectedGenerators or {}
            local jaEstaVinculado = false
            for _, chave in pairs(dadosConstrucao.connectedGenerators) do
                if chave == chaveGerador then 
                    jaEstaVinculado = true
                    break 
                end
            end
            if not jaEstaVinculado then
                table.insert(dadosConstrucao.connectedGenerators, chaveGerador)
            end
        end
    end

    if dadosConstrucao then
        -- Força a atualização do circuito de alimentação
        if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
                and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding then
            LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(identificadorConstrucao)
        end

        -- Sincroniza dados de aquecimento térmico
        if LKS_EletricidadeConstrucao.Heating and LKS_EletricidadeConstrucao.Heating.Manager
                and LKS_EletricidadeConstrucao.Heating.Manager.SyncToGenerators then
            LKS_EletricidadeConstrucao.Heating.Manager.SyncToGenerators(dadosConstrucao)
        end

        -- Salva o estado elétrico no banco de dados ModData imediatamente
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                and LKS_EletricidadeConstrucao.Core.StateManager.Save then
            LKS_EletricidadeConstrucao.Core.StateManager.Save(true, true)
        end

        -- Eleger este gerador como dono do pool caso nenhum outro gerador a possua no ModData
        local quadradoGeradorAux = self.generator:getSquare()
        if quadradoGeradorAux then
            local chaveGerador = string.format("%d_%d_%d", quadradoGeradorAux:getX(), quadradoGeradorAux:getY(), quadradoGeradorAux:getZ())
            local celula = getCell and getCell()
            local existeDonoPool = false
            if celula then
                for _, chave in pairs(dadosConstrucao.connectedGenerators or {}) do
                    if chave ~= chaveGerador then
                        local xOutro, yOutro, zOutro = string.match(chave, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        if xOutro then
                            local quadradoOutro = celula:getGridSquare(tonumber(xOutro), tonumber(yOutro), tonumber(zOutro))
                            if quadradoOutro then
                                local objetosOutro = quadradoOutro:getObjects()
                                for indiceObjeto = 0, objetosOutro:size() - 1 do
                                    local objetoOutro = objetosOutro:get(indiceObjeto)
                                    if objetoOutro and instanceof(objetoOutro, "IsoGenerator") then
                                        if objetoOutro:getModData().LKS_EletricidadeConstrucao_PoolData then
                                            existeDonoPool = true
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if existeDonoPool then break end
                end
            end
            if not existeDonoPool then
                dadosMod.LKS_EletricidadeConstrucao_PoolData = {
                    id           = dadosConstrucao.id,
                    x            = dadosConstrucao.x,
                    y            = dadosConstrucao.y,
                    z            = dadosConstrucao.z,
                    boundingBox  = dadosConstrucao.boundingBox,
                    borderRadius = dadosConstrucao.borderRadius or 0,
                    isRVInterior = dadosConstrucao.isRVInterior or false,
                }
            end
        end
    else
        LKS_EletricidadeConstrucao.Warn("[ConnectBuilding] Varredura falhou ou interruptor ausente - a deteccao de aparelhos requer um interruptor de luz interno")
    end

    -- Transmite atualização aos clientes se em Multiplayer
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        self.generator:transmitModData()
        if isServer() then
            self.generator:sync()
        end
    end

    -- Exibe o status da conexão
    local quantidadeConectados = 0
    if dadosConstrucao and dadosConstrucao.connectedGenerators then
        for _ in pairs(dadosConstrucao.connectedGenerators) do
            quantidadeConectados = quantidadeConectados + 1
        end
    end
    
    local maximoGeradores = (LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.BUILDING 
                          and LKS_EletricidadeConstrucao.Constants.BUILDING.MAX_GENERATORS_PER_BUILDING) or 10
    local mensagem = string.format("%s (%d/%d)", 
        getText("IGUI_ConnectedToBuilding") or "Conectado ao edifício",
        quantidadeConectados, maximoGeradores)
        
    if DeveDizerAoPersonagem(AmbienteExecucao) then
        self.character:Say(mensagem)
    end

    return true
end

-- ============================================================================
-- DURAÇÃO E CONSTRUTOR
-- ============================================================================

function LKS_EletricidadeConstrucao_ConnectBuilding:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    -- Ação de conexão leva aproximadamente 10 segundos físicos (100 ticks)
    return 100
end

function LKS_EletricidadeConstrucao_ConnectBuilding:new(character, generator)
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

LKS_EletricidadeConstrucao.Actions.ConnectBuilding = LKS_EletricidadeConstrucao_ConnectBuilding

LKS_EletricidadeConstrucao.Print("Acao ConnectBuilding carregada no namespace")
