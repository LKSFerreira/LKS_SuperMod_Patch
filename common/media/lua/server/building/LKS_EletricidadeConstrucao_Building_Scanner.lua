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

-- ARQUIVO: LKS_EletricidadeConstrucao_Building_Scanner.lua
-- OBJETIVO: Escaneia construções a partir de interruptores de luz para mapear áreas de alimentação.
-- LOCALIZAÇÃO: server/building

if not LKS_EletricidadeConstrucao then
    print("[LKS PATCH - LKS_EletricidadeConstrucao_Building_Scanner.lua] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

LKS_EletricidadeConstrucao.Building = LKS_EletricidadeConstrucao.Building or {}
LKS_EletricidadeConstrucao.Building.Scanner = LKS_EletricidadeConstrucao.Building.Scanner or {}

-- ============================================================================
-- ESTADO LOCAL
-- ============================================================================

local _inicializado = false
local _filaEscaneamento = {}
local _escaneamentoAtivo = nil

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

--- Inicializa o escaneador de construções.
function LKS_EletricidadeConstrucao.Building.Scanner.Initialize()
    if _inicializado then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("Escaneador de Construção já inicializado", "Building")
        return
    end
    
    LKS_EletricidadeConstrucao.Core.EventManager.RegisterGameEvent("OnObjectAdded", LKS_EletricidadeConstrucao.Building.Scanner.OnObjectAdded)
    
    _inicializado = true
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Escaneador de Construção inicializado com sucesso", "Building")
end

--- Verifica se o escaneador de construções está inicializado.
--- @return boolean Retorna true se estiver inicializado.
function LKS_EletricidadeConstrucao.Building.Scanner.IsInitialized()
    return _inicializado
end

-- ============================================================================
-- DETECÇÃO DE OBJETOS
-- ============================================================================

--- Manipula o evento de adição de objetos físicos para capturar novos interruptores.
--- @param object any O objeto físico adicionado.
function LKS_EletricidadeConstrucao.Building.Scanner.OnObjectAdded(object)
    if not object then
        return
    end
    
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    if not Validation.IsLightSwitch(object) then
        return
    end
    
    local x = object:getX()
    local y = object:getY()
    local z = object:getZ()
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Interruptor de luz detectado em (%d,%d,%d)", x, y, z),
        "Building"
    )
    
    LKS_EletricidadeConstrucao.Building.Scanner.QueueScan(x, y, z)
end

-- ============================================================================
-- GERENCIAMENTO DA FILA DE ESCANEAMENTO
-- ============================================================================

--- Enfileira uma requisição de varredura para a construção.
--- @param x number Coordenada X do interruptor.
--- @param y number Coordenada Y do interruptor.
--- @param z number Coordenada Z do interruptor.
--- @param buildingIdOverride string|nil ID opcional para sobrescrever o ID automático.
function LKS_EletricidadeConstrucao.Building.Scanner.QueueScan(x, y, z, buildingIdOverride)
    local idConstrucao = buildingIdOverride or LKS_EletricidadeConstrucao.Data.Building.MakeId(x, y, z)
    
    for _, escaneamento in ipairs(_filaEscaneamento) do
        if escaneamento.buildingId == idConstrucao then
            LKS_EletricidadeConstrucao.Core.Logger.Trace(
                string.format("Escaneamento já enfileirado para %s", idConstrucao),
                "Building"
            )
            return
        end
    end
    
    table.insert(_filaEscaneamento, {
        buildingId = idConstrucao,
        x = x,
        y = y,
        z = z,
        queuedTime = getTimestampMs()
    })
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Escaneamento enfileirado para a construção %s (%d na fila)", idConstrucao, #_filaEscaneamento),
        "Building"
    )
end

--- Processa os itens pendentes na fila de escaneamento.
function LKS_EletricidadeConstrucao.Building.Scanner.ProcessQueue()
    if not _inicializado then
        return
    end
    
    if _escaneamentoAtivo then
        return
    end
    
    if #_filaEscaneamento == 0 then
        return
    end
    
    local escaneamento = table.remove(_filaEscaneamento, 1)
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Iniciando escaneamento para a construção %s", escaneamento.buildingId),
        "Building"
    )
    
    LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(escaneamento.x, escaneamento.y, escaneamento.z, escaneamento.buildingId)
end

-- ============================================================================
-- VERIFICAÇÃO DE CHUNKS CARREGADOS
-- ============================================================================

--- Verifica se todos os chunks contidos na área da construção estão devidamente carregados no mapa.
--- @param buildingData table Os dados da construção.
--- @return boolean Retorna true se todos os pontos chave estiverem carregados.
function LKS_EletricidadeConstrucao.Building.Scanner.IsBuildingAreaLoaded(buildingData)
    if not buildingData then return false end
    local bb = buildingData.boundingBox
    if not bb then
        return true
    end
    local z = buildingData.z or 0
    local pontos = {
        {x = bb.minX,                                y = bb.minY},
        {x = bb.maxX,                                y = bb.minY},
        {x = bb.minX,                                y = bb.maxY},
        {x = bb.maxX,                                y = bb.maxY},
        {x = math.floor((bb.minX + bb.maxX) * 0.5), y = math.floor((bb.minY + bb.maxY) * 0.5)},
    }
    for _, ponto in ipairs(pontos) do
        if not getSquare(ponto.x, ponto.y, z) then
            return false
        end
    end
    return true
end

-- ============================================================================
-- EXECUÇÃO DO ESCANEAMENTO DA CONSTRUÇÃO
-- ============================================================================

--- Escaneia a construção física a partir das coordenadas do interruptor de luz.
--- @param x number Coordenada X.
--- @param y number Coordenada Y.
--- @param z number Coordenada Z.
--- @param buildingIdOverride string|nil ID opcional para sobrescrever o ID automático.
--- @return table|nil O estado da construção mapeado ou nil.
function LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(x, y, z, buildingIdOverride)
    local Config = LKS_EletricidadeConstrucao.Config
    local Constants = LKS_EletricidadeConstrucao.Constants
    
    LKS_EletricidadeConstrucao.Core.Logger.StartTimer("BuildingScan")
    
    local quadrado = getSquare(x, y, z)
    if not quadrado then
        LKS_EletricidadeConstrucao.Core.Logger.Error(
            string.format("Quadrado não encontrado em (%d,%d,%d)", x, y, z),
            "Building"
        )
        return nil
    end
    
    local lightSwitch = nil
    local objetos = quadrado:getObjects()
    if objetos then
        for i = 0, objetos:size() - 1 do
            local obj = objetos:get(i)
            if obj and instanceof(obj, "IsoLightSwitch") then
                lightSwitch = obj
                break
            end
        end
    end
    
    if not lightSwitch then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("Interruptor de luz não encontrado em (%d,%d,%d)", x, y, z),
            "Building"
        )
        return nil
    end
    
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local idConstrucao = buildingIdOverride or LKS_EletricidadeConstrucao.Data.Building.MakeId(x, y, z)
    local buildingData = StateManager.GetBuilding(idConstrucao)
    
    local eReescaneamento = (buildingData ~= nil)
    print(string.format("[LKS PATCH - SCAN] %s construção %s a partir do interruptor (%d,%d,%d)",
        eReescaneamento and "REESCANEANDO" or "NOVO ESCANEAMENTO", idConstrucao, x, y, z))
    
    if not buildingData then
        local raio = Config.BorderRadius or Constants.BUILDING.DEFAULT_BORDER_RADIUS or 10
        buildingData = LKS_EletricidadeConstrucao.Data.Building.New(lightSwitch, raio)
        if buildingIdOverride then
            buildingData.id = buildingIdOverride
        end
        StateManager.AddBuilding(buildingData)
    else
        print(string.format("[LKS PATCH - SCAN] Construção já registrada - consumidores atuais: %d, consumo atual: %.1f",
            buildingData.totalConsumers or 0, buildingData.totalPowerDraw or 0))
    end
    
    local scanRadius = buildingData.borderRadius
    local construidoPeloJogador = idConstrucao and string.match(idConstrucao, "^bld_%-?%d+_%-?%d+_%-?%d+$") ~= nil
    if construidoPeloJogador and buildingData.boundingBox then
        local bb = buildingData.boundingBox
        local metadeLargura = math.ceil((bb.maxX - bb.minX) / 2) + 3
        local metadeAltura = math.ceil((bb.maxY - bb.minY) / 2) + 3
        scanRadius = math.max(metadeLargura, metadeAltura, scanRadius or 2)
        print(string.format("[LKS PATCH - SCAN] Construída pelo jogador %s: raio de varredura derivado da caixa %d", idConstrucao, scanRadius))
    elseif construidoPeloJogador then
        scanRadius = math.max(scanRadius or 2, 30)
    end

    local quadradosBorda = LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBorders(x, y, z, scanRadius, idConstrucao)
    if #quadradosBorda == 0 then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("Nenhum quadrado de borda para a construção %s", idConstrucao),
            "Building"
        )
        return buildingData
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Encontrados %d quadrados de borda para a construção %s", #quadradosBorda, idConstrucao),
        "Building"
    )
    print(string.format("[LKS PATCH - SCAN] Encontrados %d quadrados de borda", #quadradosBorda))
    
    local minimoX, minimoY, maximoX, maximoY = 999999, 999999, -999999, -999999
    for _, tile in ipairs(quadradosBorda) do
        if tile.x < minimoX then minimoX = tile.x end
        if tile.y < minimoY then minimoY = tile.y end
        if tile.x > maximoX then maximoX = tile.x end
        if tile.y > maximoY then maximoY = tile.y end
    end
    
    LKS_EletricidadeConstrucao.Data.Building.SetBoundingBox(buildingData, minimoX, minimoY, maximoX, maximoY)
    
    local totalConsumidoresAntigo = buildingData.totalConsumers or 0
    local consumoEnergiaAntigo = buildingData.totalPowerDraw or 0
    print(string.format("[LKS PATCH - SCAN] ANTES da varredura: %d consumidores, consumo de %.1f", totalConsumidoresAntigo, consumoEnergiaAntigo))

    if eReescaneamento and (buildingData.totalConsumers or 0) > 0 then
        local Scanner = LKS_EletricidadeConstrucao.Building.Scanner
        if not Scanner.IsBuildingAreaLoaded(buildingData) then
            LKS_EletricidadeConstrucao.Core.Logger.Info(
                string.format("EscanearConstrucao: carregamento parcial de chunk detectado para %s – pulando reescaneamento e mantendo dados salvos",
                    idConstrucao),
                "Building")
            LKS_EletricidadeConstrucao.Data.Building.MarkScanned(buildingData)
            LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
            LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BuildingScan", 50)
            return buildingData
        end
    end

    LKS_EletricidadeConstrucao.Data.Building.ClearConsumers(buildingData)
    print("[LKS PATCH - SCAN] Consumidores limpos, reescaneando...")
    
    LKS_EletricidadeConstrucao.Building.ConsumerScanner.ScanConsumers(buildingData, quadradosBorda)
    
    LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(buildingData)
    
    print(string.format("[LKS PATCH - SCAN] DEPOIS da varredura: %d consumidores, consumo de %.1f (diferença: %+d consumidores, %+.1f consumo)",
        buildingData.totalConsumers or 0, buildingData.totalPowerDraw or 0,
        (buildingData.totalConsumers or 0) - totalConsumidoresAntigo,
        (buildingData.totalPowerDraw or 0) - consumoEnergiaAntigo))
    
    LKS_EletricidadeConstrucao.Data.Building.MarkScanned(buildingData)
    
    LKS_EletricidadeConstrucao.Core.EventManager.OnBuildingScanned(buildingData)
    
    StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BuildingScan", 50)
    
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("Construção %s escaneada: %d consumidores, consumo de %.1f",
            idConstrucao, #buildingData.powerConsumers, buildingData.totalPowerDraw),
        "Building"
    )
    
    return buildingData
end

-- ============================================================================
-- OPERAÇÕES DE REESCANEAMENTO
-- ============================================================================

--- Reescreve e rescaneia cômodos elétricos de uma construção existente.
--- @param idConstrucao string O ID da construção.
--- @return table|nil O estado da construção atualizado ou nil.
function LKS_EletricidadeConstrucao.Building.Scanner.RescanBuilding(idConstrucao)
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local buildingData = StateManager.GetBuilding(idConstrucao)
    
    if not buildingData then
        LKS_EletricidadeConstrucao.Core.Logger.Error(
            string.format("Construção %s não encontrada para reescaneamento", idConstrucao),
            "Building"
        )
        return nil
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Reescaneando a construção %s", idConstrucao),
        "Building"
    )
    
    LKS_EletricidadeConstrucao.Data.Building.ClearConsumers(buildingData)
    
    return LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(buildingData.x, buildingData.y, buildingData.z)
end

--- Rescaneia completamente todas as construções registradas em memória.
function LKS_EletricidadeConstrucao.Building.Scanner.RescanAllBuildings()
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local construcoes = StateManager.GetAllBuildings()
    
    local total = 0
    for idConstrucao, _ in pairs(construcoes) do
        LKS_EletricidadeConstrucao.Building.Scanner.RescanBuilding(idConstrucao)
        total = total + 1
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("Reescaneadas %d construções", total),
        "Building"
    )
end

-- ============================================================================
-- OPERAÇÕES DE ESCANEAMENTO MANUAL
-- ============================================================================

--- Realiza o escaneamento manual em coordenadas específicas.
--- @param x number Coordenada X.
--- @param y number Coordenada Y.
--- @param z number Coordenada Z.
--- @return table|nil Os dados da construção.
function LKS_EletricidadeConstrucao.Building.Scanner.ManualScan(x, y, z)
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("Escaneamento manual solicitado em (%d,%d,%d)", x, y, z),
        "Building"
    )
    
    return LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(x, y, z)
end

--- Varre o mapa carregado em busca de todos os interruptores de luz e os enfileira para escaneamento.
function LKS_EletricidadeConstrucao.Building.Scanner.ScanAllLightSwitches()
    LKS_EletricidadeConstrucao.Core.Logger.Info("Escaneando todos os interruptores de luz nos chunks carregados...", "Building")
    
    local total = 0
    local chunksCarregados = LKS_EletricidadeConstrucao.Fuel.ChunkTracker.GetLoadedChunks()
    
    for _, chaveChunk in ipairs(chunksCarregados) do
        local chunkX, chunkY = chaveChunk:match("chunk_(-?%d+)_(-?%d+)")
        
        if chunkX and chunkY then
            chunkX = tonumber(chunkX)
            chunkY = tonumber(chunkY)
            
            for x = chunkX * 10, (chunkX * 10) + 9 do
                for y = chunkY * 10, (chunkY * 10) + 9 do
                    for z = 0, 7 do
                        local quadrado = getSquare(x, y, z)
                        if quadrado then
                            local objetos = quadrado:getObjects()
                            if objetos then
                                for i = 0, objetos:size() - 1 do
                                    local obj = objetos:get(i)
                                    if obj and instanceof(obj, "IsoLightSwitch") then
                                        LKS_EletricidadeConstrucao.Building.Scanner.QueueScan(x, y, z)
                                        total = total + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("Encontrados %d interruptores de luz, enfileirados para escaneamento", total),
        "Building"
    )
end

-- ============================================================================
-- DEPURAÇÃO
-- ============================================================================

--- Imprime estatísticas de estado do escaneador no console de depuração.
function LKS_EletricidadeConstrucao.Building.Scanner.PrintStatus()
    LKS_EletricidadeConstrucao.Print("=== Estado do Escaneador de Construção ===")
    LKS_EletricidadeConstrucao.Print("Inicializado: " .. tostring(_inicializado))
    LKS_EletricidadeConstrucao.Print("Escaneamentos na Fila: " .. #_filaEscaneamento)
    LKS_EletricidadeConstrucao.Print("Escaneamento Ativo: " .. tostring(_escaneamentoAtivo ~= nil))
    
    local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
    local construcoes = StateManager.GetAllBuildings()
    local total = 0
    
    for _, _ in pairs(construcoes) do
        total = total + 1
    end
    
    LKS_EletricidadeConstrucao.Print("Total de Construções: " .. total)
end

-- ============================================================================
-- REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Building.Scanner", "2.0.0")

return LKS_EletricidadeConstrucao.Building.Scanner
