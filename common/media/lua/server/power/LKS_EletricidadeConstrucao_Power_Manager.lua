-- ============================================================================
-- 🌟 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL 🌟
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) por sua excelente contribuição à comunidade de Project Zomboid.
-- ============================================================================

-- LKS_EletricidadeConstrucao V2: Gerenciador de Conexões de Energia (Power Manager)
-- Objetivo: Conectar geradores a prédios próximos e gerenciar a distribuição de energia
-- Autor: Assistente de IA
-- Criado em: 2025

if not LKS_EletricidadeConstrucao then 
    print("[LKS_EletricidadeConstrucao_Power_Manager] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return 
end

LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao or {}
LKS_EletricidadeConstrucao.Power = LKS_EletricidadeConstrucao.Power or {}
LKS_EletricidadeConstrucao.Power.Manager = LKS_EletricidadeConstrucao.Power.Manager or {}

local Gerenciador = LKS_EletricidadeConstrucao.Power.Manager
local Registrador = LKS_EletricidadeConstrucao.Core.Logger
local GerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
local Matematica = LKS_EletricidadeConstrucao.Utils.Math
local Validacao = LKS_EletricidadeConstrucao.Utils.Validation

--------------------------------------------------------------------------------
-- CONSTANTES
--------------------------------------------------------------------------------

Gerenciador.MAX_POWER_RANGE = 30  -- Distância máxima (em ladrilhos) do gerador ao prédio
Gerenciador.CONNECTION_UPDATE_INTERVAL = 60  -- Atualiza as conexões a cada 60 segundos
Gerenciador.DEBUG = false

--------------------------------------------------------------------------------
-- ESTADO
--------------------------------------------------------------------------------

-- Rastreamento de conexões: generatorId -> { ... }
Gerenciador.connections = {}

-- Timestamp da última atualização
Gerenciador.lastUpdate = 0

--------------------------------------------------------------------------------
-- INICIALIZAÇÃO
--------------------------------------------------------------------------------

--- Inicializa o Gerenciador de Energia
function Gerenciador.Initialize()
    Registrador.Info("Power.Manager", "Inicializando Gerenciador de Energia...")
    
    Gerenciador.connections = {}
    Gerenciador.lastUpdate = 0
    
    Registrador.Info("Power.Manager", "Gerenciador de Energia inicializado.")
end

--------------------------------------------------------------------------------
-- DETECÇÃO DE GERADORES
--------------------------------------------------------------------------------

--- Encontra todos os geradores nos chunks carregados
-- Busca as posições de geradores conhecidos do GerenciadorEstado e retorna os que têm
-- o objeto IsoGenerator na memória. Isso evita APIs de varredura de chunks
-- (getChunkMap / getSquares) que não estão sempre disponíveis de forma confiável no Kahlua.
-- @return table Lista de objetos IsoGenerator
function Gerenciador.GetAllGenerators()
    local geradores = {}
    local celula = getCell()

    if not celula then
        Registrador.Warn("Power.Manager", "GetAllGenerators: Nenhuma celula do mundo encontrada")
        return geradores
    end

    -- Percorre os geradores conhecidos no GerenciadorEstado em vez de escanear os chunks.
    local todosDadosGeradores = GerenciadorEstado.GetAllGenerators()
    for _, dadosGerador in pairs(todosDadosGeradores) do
        local quadrado = celula:getGridSquare(dadosGerador.x, dadosGerador.y, dadosGerador.z)
        if quadrado then
            local objetos = quadrado:getObjects()
            for indice = 0, objetos:size() - 1 do
                local objeto = objetos:get(indice)
                if objeto and instanceof(objeto, "IsoGenerator") then
                    table.insert(geradores, objeto)
                    break
                end
            end
        end
    end

    Registrador.Debug("Power.Manager", "GetAllGenerators: Encontrados " .. #geradores .. " geradores")
    return geradores
end

--- Encontra geradores próximos a um prédio específico
-- @param dadosPredio BuildingData objeto
-- @param raio number Raio máximo de busca (opcional, padrão MAX_POWER_RANGE)
-- @return table Lista de objetos IsoGenerator dentro do raio de alcance
function Gerenciador.FindNearbyGenerators(dadosPredio, raio)
    if not dadosPredio then
        Registrador.Error("Power.Manager", "FindNearbyGenerators: dadosPredio e nil")
        return {}
    end
    
    raio = raio or Gerenciador.MAX_POWER_RANGE
    
    local geradoresProximos = {}
    local todosGeradores = Gerenciador.GetAllGenerators()
    
    -- Coordenadas centrais do prédio (alguns estados não armazenam centerX/centerY).
    -- Obtém a partir da caixa delimitadora se disponível, caso contrário usa a âncora x/y.
    local function paraNumero(valor, fallback)
        local num = tonumber(valor)
        if num == nil then return fallback or 0 end
        return num
    end
    local predioX = paraNumero(dadosPredio.x, 0)
    local predioY = paraNumero(dadosPredio.y, 0)
    local predioZ = paraNumero(dadosPredio.z, 0)
    local bb = dadosPredio.boundingBox
    if type(bb) == "table" then
        local minX = paraNumero(bb[1], predioX)
        local minY = paraNumero(bb[2], predioY)
        local maxX = paraNumero(bb[3], predioX)
        local maxY = paraNumero(bb[4], predioY)
        predioX = (minX + maxX) / 2
        predioY = (minY + maxY) / 2
    end
    
    for _, gerador in ipairs(todosGeradores) do
        local quadradoGerador = gerador:getSquare()
        if quadradoGerador then
            local gx = quadradoGerador:getX()
            local gy = quadradoGerador:getY()
            local gz = quadradoGerador:getZ()
            
            -- Verifica se está no mesmo andar
            if gz == predioZ then
                -- Calcula a distância
                local distancia = Matematica.Distance2D(predioX, predioY, gx, gy)
                
                if distancia <= raio then
                    table.insert(geradoresProximos, {
                        generator = gerador,
                        distance = distancia,
                        x = gx,
                        y = gy,
                        z = gz
                    })
                end
            end
        end
    end
    
    -- Ordena pela distância (mais próximo primeiro)
    table.sort(geradoresProximos, function(a, b)
        return a.distance < b.distance
    end)
    
    Registrador.Debug("Power.Manager", string.format(
        "FindNearbyGenerators: Encontrados %d geradores dentro de %d ladrilhos do prédio %s",
        #geradoresProximos, raio, dadosPredio.id
    ))
    
    return geradoresProximos
end

--------------------------------------------------------------------------------
-- GERENCIAMENTO DE CONEXÕES
--------------------------------------------------------------------------------

--- Cria um ID de conexão único
-- @param geradorX number Coordenada X do gerador
-- @param geradorY number Coordenada Y do gerador
-- @param geradorZ number Coordenada Z do gerador
-- @param idPredio string ID do Prédio
-- @return string ID da Conexão
function Gerenciador.CreateConnectionId(geradorX, geradorY, geradorZ, idPredio)
    return string.format("conn_%d_%d_%d_%s", geradorX, geradorY, geradorZ, idPredio)
end

local function geradorPertenceAoPredio(gerador, dadosPredio)
    if not gerador or not dadosPredio or not dadosPredio.id then
        return false
    end

    local quadrado = gerador:getSquare()
    if not quadrado then
        return false
    end

    local dadosMod = gerador:getModData()
    if dadosMod and dadosMod.LKS_EletricidadeConstrucao_DisconnectSuppressed then
        return false
    end

    if dadosMod and dadosMod.Gen_BuildingPoolID == dadosPredio.id then
        return true
    end

    local idGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(quadrado:getX(), quadrado:getY(), quadrado:getZ())
    local dadosGerador = GerenciadorEstado.GetGenerator(idGerador)
    if dadosGerador and dadosGerador.connectedBuildings then
        for _, idPredioConectado in pairs(dadosGerador.connectedBuildings) do
            if idPredioConectado == dadosPredio.id then
                return true
            end
        end
    end

    return false
end

--- Conecta um gerador a um prédio
-- @param generator IsoGenerator objeto
-- @param buildingData BuildingData objeto
-- @param distance number Distância entre o gerador e o prédio
-- @return boolean Sucesso
function Gerenciador.ConnectGeneratorToBuilding(generator, buildingData, distance)
    if not generator or not buildingData then
        Registrador.Error("Power.Manager", "ConnectGeneratorToBuilding: Parametros invalidos")
        return false
    end
    
    local quadrado = generator:getSquare()
    if not quadrado then
        Registrador.Warn("Power.Manager", "ConnectGeneratorToBuilding: Gerador nao possui um quadrado associado")
        return false
    end
    
    local gx = quadrado:getX()
    local gy = quadrado:getY()
    local gz = quadrado:getZ()

    -- Prepara a lista de conexões do prédio e aplica limite do pool (máximo 10)
    if not buildingData.connectedGenerators then
        buildingData.connectedGenerators = {}
    end
    local chaveGerador = string.format("%d_%d_%d", gx, gy, gz)
    local jaConectado = false
    -- connectedGenerators é desserializado pelo Kahlua (chaves numéricas em string)
    for _, coordsGerador in pairs(buildingData.connectedGenerators) do
        if coordsGerador == chaveGerador then
            jaConectado = true
            break
        end
    end
    local tamanhoPoolGeradores = 0
    if buildingData.connectedGenerators then
        for _ in pairs(buildingData.connectedGenerators) do tamanhoPoolGeradores = tamanhoPoolGeradores + 1 end
    end
    local geradoresMaximo = (LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.BUILDING 
                            and LKS_EletricidadeConstrucao.Constants.BUILDING.MAX_GENERATORS_PER_BUILDING) or 10
    if not jaConectado and tamanhoPoolGeradores >= geradoresMaximo then
        Registrador.Warn("Power.Manager", string.format(
            "ConnectGeneratorToBuilding: Limite de pool atingido (%d). Rejeitando gerador em (%d,%d,%d) para o prédio %s",
            geradoresMaximo, gx, gy, gz, buildingData.id))
        return false
    end

    -- Garante que o gerador está registrado no GerenciadorEstado com referência de volta a este prédio
    local idGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(gx, gy, gz)
    local dadosGerador = GerenciadorEstado.GetGenerator(idGerador)
    if not dadosGerador then
        dadosGerador = LKS_EletricidadeConstrucao.Data.Generator.New(generator)
    end
    dadosGerador.connectedBuildings = dadosGerador.connectedBuildings or {}
    local geradorTemPredio = false
    -- connectedBuildings é desserializado pelo Kahlua (chaves numéricas em string)
    for _, bid in pairs(dadosGerador.connectedBuildings) do
        if bid == buildingData.id then geradorTemPredio = true; break end
    end
    if not geradorTemPredio then
        table.insert(dadosGerador.connectedBuildings, buildingData.id)
    end
    GerenciadorEstado.AddGenerator(dadosGerador)

    -- Cria o ID de conexão
    local idConexao = Gerenciador.CreateConnectionId(gx, gy, gz, buildingData.id)

    -- Verifica se a conexão já existe
    if Gerenciador.connections[idConexao] then
        Registrador.Debug("Power.Manager", "ConnectGeneratorToBuilding: Conexao ja existe: " .. idConexao)
        return true
    end

    -- Cria os dados da conexão
    local dadosConexao = {
        id = idConexao,
        generatorX = gx,
        generatorY = gy,
        generatorZ = gz,
        buildingId = buildingData.id,
        distance = distance,
        createdTime = os.time(),
        lastValidated = os.time()
    }

    -- Armazena a conexão
    Gerenciador.connections[idConexao] = dadosConexao

    local dadosMod = generator:getModData()
    if dadosMod then
        dadosMod.LKS_EletricidadeConstrucao_DisconnectSuppressed = nil
    end

    -- Adiciona coordenadas do gerador ao prédio (se ainda não estiver lá)
    if not jaConectado then
        table.insert(buildingData.connectedGenerators, chaveGerador)
    end

    Registrador.Info("Power.Manager", string.format(
        "Gerador conectado em (%d,%d,%d) ao prédio %s (distância: %.1f ladrilhos)",
        gx, gy, gz, buildingData.id, distance
    ))

    return true
end

--- Desconecta um gerador de um prédio
-- @param idConexao string ID da Conexão
-- @return boolean Sucesso
function Gerenciador.DisconnectGeneratorFromBuilding(idConexao)
    if not idConexao then
        Registrador.Error("Power.Manager", "DisconnectGeneratorFromBuilding: idConexao e nil")
        return false
    end
    
    local conexao = Gerenciador.connections[idConexao]
    if not conexao then
        Registrador.Warn("Power.Manager", "DisconnectGeneratorFromBuilding: Conexao nao encontrada: " .. idConexao)
        return false
    end
    
    -- Obtém dados do prédio
    local dadosPredio = GerenciadorEstado.GetBuilding(conexao.buildingId)
    local chaveGerador = string.format("%d_%d_%d", conexao.generatorX, conexao.generatorY, conexao.generatorZ)

    if dadosPredio and dadosPredio.connectedGenerators then
        -- Remove o gerador da lista de conexões do prédio (seguro com chaves strings do Kahlua)
        local novaListaGeradores = {}
        for _, valor in pairs(dadosPredio.connectedGenerators) do
            if valor ~= chaveGerador then table.insert(novaListaGeradores, valor) end
        end
        dadosPredio.connectedGenerators = novaListaGeradores

        -- Se não sobrarem geradores conectados, remove o prédio do estado
        if LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(dadosPredio.connectedGenerators) then
            GerenciadorEstado.RemoveBuilding(conexao.buildingId)
        end
    end

    -- Atualiza o estado do gerador: limpa a ligação do pool e remove a referência do prédio
    local idGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(conexao.generatorX, conexao.generatorY, conexao.generatorZ)
    local dadosGerador = GerenciadorEstado.GetGenerator(idGerador)
    if dadosGerador and dadosGerador.connectedBuildings then
        local novaListaPredios = {}
        for _, valor in pairs(dadosGerador.connectedBuildings) do
            if valor ~= conexao.buildingId then table.insert(novaListaPredios, valor) end
        end
        dadosGerador.connectedBuildings = novaListaPredios
        if LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(dadosGerador.connectedBuildings) then
            -- Limpa o carimbo do pool no IsoGenerator do jogo se estiver carregado
            local celula = getCell()
            if celula then
                local quadrado = celula:getGridSquare(conexao.generatorX, conexao.generatorY, conexao.generatorZ)
                if quadrado then
                    local objetos = quadrado:getObjects()
                    for indice = 0, objetos:size() - 1 do
                        local objeto = objetos:get(indice)
                        if objeto and instanceof(objeto, "IsoGenerator") then
                            local md = objeto:getModData()
                            md.Gen_BuildingPoolID = nil
                            if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                objeto:transmitModData()
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    -- Remove a conexão
    Gerenciador.connections[idConexao] = nil
    GerenciadorEstado.MarkDirty()

    Registrador.Info("Power.Manager", string.format(
        "Gerador desconectado em (%d,%d,%d) do prédio %s",
        conexao.generatorX, conexao.generatorY, conexao.generatorZ, conexao.buildingId
    ))
    
    return true
end

--------------------------------------------------------------------------------
-- VALIDAÇÃO DE CONEXÕES
--------------------------------------------------------------------------------

--- Verifica se um gerador ainda existe nas coordenadas especificadas
-- @param x number Coordenada X
-- @param y number Coordenada Y
-- @param z number Coordenada Z
-- @return IsoGenerator|nil Objeto do Gerador se encontrado, senão nil
function Gerenciador.GetGeneratorAt(x, y, z)
    local quadrado = getCell():getGridSquare(x, y, z)
    if not quadrado then
        return nil
    end
    
    local objetos = quadrado:getObjects()
    for indice = 0, objetos:size() - 1 do
        local objeto = objetos:get(indice)
        if objeto and instanceof(objeto, "IsoGenerator") then
            return objeto
        end
    end
    
    return nil
end

--- Valida uma conexão (verifica se o gerador e o prédio ainda existem)
-- @param dadosConexao table Dados da conexão
-- @return boolean True se a conexão for válida
function Gerenciador.ValidateConnection(dadosConexao)
    if not dadosConexao then
        return false
    end
    
    -- Verifica se o gerador ainda existe.
    -- IMPORTANTE: Se o chunk do gerador não estiver carregado, getGridSquare retorna nil.
    -- NÃO devemos desligar uma conexão simplesmente porque o chunk não está carregado —
    -- isso removeria connectedBuildings do estado e faria com que o cálculo de compensação
    -- tratasse o gerador como solo (bug do consumo de combustível 3x maior, B-87).
    -- Só desconsidere se o chunk ESTIVER carregado mas não houver IsoGenerator nesse ladrilho.
    local quadradoGerador = getCell():getGridSquare(
        dadosConexao.generatorX, dadosConexao.generatorY, dadosConexao.generatorZ)
    if not quadradoGerador then
        -- Chunk não carregado — impossível verificar; mantém conexão intacta.
        return true
    end
    local gerador = nil
    local objetos = quadradoGerador:getObjects()
    for indice = 0, objetos:size() - 1 do
        local objeto = objetos:get(indice)
        if objeto and instanceof(objeto, "IsoGenerator") then gerador = objeto; break end
    end
    if not gerador then
        Registrador.Debug("Power.Manager", "ValidateConnection: Gerador nao existe mais em " ..
            string.format("(%d,%d,%d)", dadosConexao.generatorX, dadosConexao.generatorY, dadosConexao.generatorZ))
        return false
    end
    
    -- Verifica se o prédio ainda existe no estado
    local dadosPredio = GerenciadorEstado.GetBuilding(dadosConexao.buildingId)
    if not dadosPredio then
        Registrador.Debug("Power.Manager", "ValidateConnection: Predio nao existe mais: " .. dadosConexao.buildingId)
        return false
    end
    
    -- Verifica a distância (caso o prédio tenha sido modificado)
    local function paraNumero(valor, fallback)
        local num = tonumber(valor)
        if num == nil then return fallback end
        return num
    end

    -- Obtém o centro do prédio com fallbacks para campos ausentes
    local px = paraNumero(dadosPredio.centerX, nil)
    local py = paraNumero(dadosPredio.centerY, nil)
    if not px or not py then
        px = paraNumero(dadosPredio.x, 0)
        py = paraNumero(dadosPredio.y, 0)
    end

    -- Se ainda faltar, tenta calcular pelo centro da caixa delimitadora
    local bb = dadosPredio.boundingBox
    if (not px or not py) and type(bb) == "table" then
        local minX = paraNumero(bb[1], paraNumero(bb.minX, px))
        local minY = paraNumero(bb[2], paraNumero(bb.minY, py))
        local maxX = paraNumero(bb[3], paraNumero(bb.maxX, px))
        local maxY = paraNumero(bb[4], paraNumero(bb.maxY, py))
        if minX and minY and maxX and maxY then
            px = (minX + maxX) / 2
            py = (minY + maxY) / 2
        end
    end

    -- Proteção final: se ainda assim não tiver, considera conexão inválida
    if not px or not py then
        Registrador.Debug("Power.Manager", "ValidateConnection: Centro do predio ausente, descartando conexao " .. tostring(dadosConexao.id))
        return false
    end

    local distancia = Matematica.Distance2D(
        px, py,
        dadosConexao.generatorX, dadosConexao.generatorY
    )
    
    if distancia > Gerenciador.MAX_POWER_RANGE then
        Registrador.Debug("Power.Manager", string.format(
            "ValidateConnection: Distância muito grande (%.1f > %d) para conexão %s",
            distancia, Gerenciador.MAX_POWER_RANGE, dadosConexao.id
        ))
        return false
    end
    
    -- Updates distance if changed
    if math.abs(distancia - dadosConexao.distance) > 0.1 then
        dadosConexao.distance = distancia
    end
    
    -- Updates last validated timestamp
    dadosConexao.lastValidated = os.time()
    
    return true
end

--- Remove conexões inválidas (geradores/prédios que não existem mais)
-- @return number Quantidade de conexões removidas
function Gerenciador.CleanInvalidConnections()
    local quantidadeRemovidos = 0
    local paraRemover = {}
    
    for idConexao, dadosConexao in pairs(Gerenciador.connections) do
        if not Gerenciador.ValidateConnection(dadosConexao) then
            table.insert(paraRemover, idConexao)
        end
    end
    
    for _, idConexao in ipairs(paraRemover) do
        Gerenciador.DisconnectGeneratorFromBuilding(idConexao)
        quantidadeRemovidos = quantidadeRemovidos + 1
    end
    
    if quantidadeRemovidos > 0 then
        Registrador.Info("Power.Manager", "CleanInvalidConnections: Removidas " .. quantidadeRemovidos .. " conexoes invalidas")
    end
    
    return quantidadeRemovidos
end

--------------------------------------------------------------------------------
-- ATUALIZAÇÃO DE CONEXÕES
--------------------------------------------------------------------------------

--- Atualiza todas as conexões (procura novos geradores, valida existentes)
function Gerenciador.UpdateConnections()
    Registrador.Debug("Power.Manager", "UpdateConnections: Escaneando geradores...")
    
    -- Limpa as conexões inválidas primeiro
    Gerenciador.CleanInvalidConnections()
    
    -- Obtém todos os prédios (retorna um mapa: buildingId -> buildingData)
    local predios = GerenciadorEstado.GetAllBuildings()
    if not predios then
        Registrador.Debug("Power.Manager", "UpdateConnections: Nenhum predio encontrado")
        return
    end
    -- Verifica se o mapa possui entradas (Kahlua não suporta next())
    local possuiPredios = false
    for _ in pairs(predios) do possuiPredios = true; break end
    if not possuiPredios then
        Registrador.Debug("Power.Manager", "UpdateConnections: Nenhum predio encontrado")
        return
    end

    local novasConexoesContagem = 0
    
    -- Para cada prédio, encontra geradores próximos
    -- NOTA: predios é um MAPA (chaves do tipo string) – deve usar pairs(), não ipairs()
    for _, dadosPredio in pairs(predios) do
        local geradoresProximos = Gerenciador.FindNearbyGenerators(dadosPredio)
        
        -- Conecta cada gerador próximo
        for _, infoGerador in ipairs(geradoresProximos) do
            local sucesso = false
            if geradorPertenceAoPredio(infoGerador.generator, dadosPredio) then
                sucesso = Gerenciador.ConnectGeneratorToBuilding(infoGerador.generator, dadosPredio, infoGerador.distance)
            end
            if sucesso then
                -- Verifica se esta é uma nova conexão de fato
                local idConexao = Gerenciador.CreateConnectionId(infoGerador.x, infoGerador.y, infoGerador.z, dadosPredio.id)
                if Gerenciador.connections[idConexao] and Gerenciador.connections[idConexao].createdTime == os.time() then
                    novasConexoesContagem = novasConexoesContagem + 1
                end
            end
        end
    end
    
    Gerenciador.lastUpdate = os.time()
    
    Registrador.Info("Power.Manager", string.format(
        "UpdateConnections: Varredura concluída. Total de conexões: %d (novas: %d)",
        Gerenciador.GetConnectionCount(), novasConexoesContagem
    ))
end

--- Periodic update (called from server tick)
-- @param tempoAtual number Timestamp atual
function Gerenciador.Update(tempoAtual)
    tempoAtual = tempoAtual or os.time()
    
    -- Check if update interval has passed
    if tempoAtual - Gerenciador.lastUpdate >= Gerenciador.CONNECTION_UPDATE_INTERVAL then
        Gerenciador.UpdateConnections()
    end
end

--------------------------------------------------------------------------------
-- FUNÇÕES DE CONSULTA
--------------------------------------------------------------------------------

--- Obtém todas as conexões ativas
-- @return table Tabela com os dados das conexões
function Gerenciador.GetAllConnections()
    return Gerenciador.connections
end

--- Obtém as conexões de um prédio específico
-- @param idPredio string ID do Prédio
-- @return table Lista com os dados de conexões do prédio
function Gerenciador.GetBuildingConnections(idPredio)
    if not idPredio then
        return {}
    end
    
    local conexoesPredio = {}
    
    for _, dadosConexao in pairs(Gerenciador.connections) do
        if dadosConexao.buildingId == idPredio then
            table.insert(conexoesPredio, dadosConexao)
        end
    end
    
    return conexoesPredio
end

--- Verifica se um prédio tem geradores ativos (ligados)
-- @param idPredio string ID do Prédio
-- @return boolean True se o prédio tiver pelo menos um gerador ativo
function Gerenciador.IsBuildingPowered(idPredio)
    if not idPredio then
        return false
    end
    
    local conexoes = Gerenciador.GetBuildingConnections(idPredio)
    
    for _, dadosConexao in ipairs(conexoes) do
        local gerador = Gerenciador.GetGeneratorAt(dadosConexao.generatorX, dadosConexao.generatorY, dadosConexao.generatorZ)
        if gerador and gerador:isActivated() then
            return true
        end
    end
    
    return false
end

--- Obtém o total de conexões registradas
-- @return number Quantidade de conexões
function Gerenciador.GetConnectionCount()
    local contagem = 0
    for _ in pairs(Gerenciador.connections) do
        contagem = contagem + 1
    end
    return contagem
end

--------------------------------------------------------------------------------
-- FUNÇÕES DE DEPURAÇÃO (DEBUG)
--------------------------------------------------------------------------------

--- Imprime todas as conexões ativas no log (debug)
function Gerenciador.PrintConnections()
    Registrador.Info("Power.Manager", "=== TODAS AS CONEXOES EM EXECUCAO ===")
    Registrador.Info("Power.Manager", string.format("Total de conexoes: %d", Gerenciador.GetConnectionCount()))
    
    for idConexao, dadosConexao in pairs(Gerenciador.connections) do
        local gerador = Gerenciador.GetGeneratorAt(dadosConexao.generatorX, dadosConexao.generatorY, dadosConexao.generatorZ)
        local ativo = gerador and gerador:isActivated() or false
        
        Registrador.Info("Power.Manager", string.format(
            "  %s: Gerador(%d,%d,%d) -> Prédio %s (%.1f ladrilhos) [%s]",
            idConexao,
            dadosConexao.generatorX, dadosConexao.generatorY, dadosConexao.generatorZ,
            dadosConexao.buildingId,
            dadosConexao.distance,
            ativo and "ENERGIZADO" or "DESLIGADO"
        ))
    end
    
    Registrador.Info("Power.Manager", "=====================================")
end

--- Varredura manual de conexões (função de depuração/comando admin)
function Gerenciador.ManualScan()
    Registrador.Info("Power.Manager", "ManualScan: Forcando atualizacao de conexoes...")
    Gerenciador.UpdateConnections()
    Gerenciador.PrintConnections()
end

--------------------------------------------------------------------------------
-- EXPORTAÇÕES
--------------------------------------------------------------------------------

LKS_EletricidadeConstrucao.RegisterModule("Power.Manager", "2.0.0")

return LKS_EletricidadeConstrucao.Power.Manager
