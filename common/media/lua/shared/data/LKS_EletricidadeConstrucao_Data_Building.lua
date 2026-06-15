-- ============================================================================
-- 🌟 LKS SUPERMOD PATCH — CRÉDITOS & AGRADECIMENTOS 🌟
-- ============================================================================
-- 💖 Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- 🛠️ Mod Original: Generator Powered Buildings (ID Workshop: 3597471949)
-- 👤 Autor Original: Beathoven
-- 🌐 Link: https://steamcommunity.com/sharedfiles/filedetails/?id=3597471949
-- 
-- Este mod só é possível graças a todos os modders que vieram antes de mi.
-- Um agradecimento especial ao autor por sua contribuição incrível à comunidade!
-- ============================================================================

-- ARQUIVO: LKS_EletricidadeConstrucao_Data_Building.lua
-- OBJETIVO: Modelo de dados (Schema) e operações para Prédios/Estruturas (Building).
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace existe antes de carregar o módulo
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Data_Building] Namespace LKS_EletricidadeConstrucao não encontrado - pulando carregamento do módulo")
    return
end

-- ============================================================================
-- DEFINIÇÃO DO SCHEMA
-- ============================================================================

--- Schema de dados de um Prédio/Estrutura.
--- @class BuildingData
--- @field id string Identificador único (formato: bld_x_y_z)
--- @field x number Coordenada X no mundo global (geralmente do interruptor de ancoragem)
--- @field y number Coordenada Y no mundo global
--- @field z number Coordenada Z no mundo global
--- @field generatorId string|nil ID do gerador conectado
--- @field powerConsumers table Vetor contendo os dados dos consumidores de energia
--- @field totalPowerDraw number Consumo total de energia do prédio
--- @field isPowered boolean Estado atual de fornecimento de energia (ligado/desligado)
--- @field borderRadius number Raio de varredura/escaneamento de limite deste prédio
--- @field lastScanTime number Carimbo de data/hora do último escaneamento realizado
--- @field boundingBox table|nil Caixa delimitadora física {minX, minY, maxX, maxY}
--- @field isRVInterior boolean Retorna true se o prédio estiver no interior de um trailer/RV
--- @field heatingPowerDraw number Carga elétrica extra adicionada pelo aquecedor ativo
--- @field heatingEnabled boolean Retorna true se o aquecimento do prédio estiver ativado (cálculo de combustível)
--- @field heatingSourceCount number Quantidade de pontos de aquecimento neste prédio (cálculo de combustível)
--- @field heatingTargetTemp number Temperatura alvo configurada para o aquecimento (cálculo de combustível)

local BuildingSchema = {
    id = "",
    x = 0,
    y = 0,
    z = 0,
    generatorId = nil,
    powerConsumers = {},
    totalPowerDraw = 0,
    heatingPowerDraw = 0,
    isPowered = false,
    borderRadius = 0,
    lastScanTime = 0,
    boundingBox = nil,
    isRVInterior = false,
    heatingEnabled = false,
    heatingSourceCount = 0,
    heatingTargetTemp = 22,
}

--- Calcula a carga extra gerada pelo aquecimento da estrutura.
--- O consumo do aquecedor é tratado como carga extra apenas quando o prédio possui pelo menos
--- um dispositivo elétrico consumindo ativamente. Isso evita sobrecarga com geradores ociosos.
--- @param dadosPredio BuildingData A tabela contendo os dados do prédio analisado.
--- @return number O consumo elétrico gerado pelo aquecimento.
local function ComputeHeatingLoad(dadosPredio)
    local Constants = LKS_EletricidadeConstrucao.Constants

    -- Requer pelo menos um consumidor elétrico ativo e um gerador conectado
    if not dadosPredio or (dadosPredio.activeConsumerCount or 0) <= 0 then
        return 0
    end

    -- Nota: após a leitura do ModData, connectedGenerators pode ser desserializada como dicionário Kahlua
    -- contendo chaves textuais indexadas ("1", "2"). Logo, o operador # retorna zero. Usamos pairs().
    if not dadosPredio.connectedGenerators then
        return 0
    end
    
    local possuiGeradores = false
    for _ in pairs(dadosPredio.connectedGenerators) do
        possuiGeradores = true
        break
    end
    if not possuiGeradores then
        return 0
    end

    -- Caminho prioritário: a flag heatingEnabled em nível de prédio é escrita pelo Heating.SyncToGenerators
    -- e persistida no GlobalModData. Usamos diretamente para evitar acessar IsoObject (o que falha se o chunk estiver descarregado).
    if dadosPredio.heatingEnabled and dadosPredio.heatingSourceCount and dadosPredio.heatingSourceCount > 0 then
        local cargaBase = (Constants.HEATING and Constants.HEATING.HEATING_POWER_PER_ROOM) or 0.5
        local cargaPorGrau = cargaBase * 0.10
        local temperaturaAlvo = dadosPredio.heatingTargetTemp or 22
        local diferencaTemperatura = temperaturaAlvo - 20
        local cargaPorFonte = cargaBase + cargaPorGrau * diferencaTemperatura
        return cargaPorFonte * dadosPredio.heatingSourceCount
    end

    -- Fallback: sem dados de aquecimento em nível de prédio (primeira sessão).
    -- Lê diretamente dos ModData do IsoObject físico. Requer que o chunk esteja carregado.
    local celulaMundo = getCell()
    if not celulaMundo then
        return 0
    end

    -- Obtém configurações de aquecimento de qualquer gerador ativo no pool.
    local configuracaoAquecimento = nil
    local cargaBase = (Constants.HEATING and Constants.HEATING.HEATING_POWER_PER_ROOM) or 0.5
    local cargaPorGrau = cargaBase * 0.10
    local temperaturaReferencia = 20

    -- connectedGenerators pode conter chaves textuais (Kahlua), por isso usamos pairs()
    for _, chaveGerador in pairs(dadosPredio.connectedGenerators) do
        local geradorX, geradorY, geradorZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if geradorX then
            local quadrado = celulaMundo:getGridSquare(tonumber(geradorX), tonumber(geradorY), tonumber(geradorZ))
            if quadrado then
                local listaObjetos = quadrado:getObjects()
                if listaObjetos then
                    for indice = 0, listaObjetos:size() - 1 do
                        local objetoGerador = listaObjetos:get(indice)
                        if objetoGerador and instanceof(objetoGerador, "IsoGenerator") then
                            local dadosModGerador = objetoGerador:getModData()
                            -- Se o gerador possui aquecimento ativado, usa suas configurações
                            if dadosModGerador and dadosModGerador.HeatingEnabled == true and objetoGerador:isActivated() and type(dadosModGerador.HeatingPositions) == "table" then
                                local quantidadeFontes = 0
                                for _, grupo in pairs(dadosModGerador.HeatingPositions) do
                                    if type(grupo.positions) == "table" then
                                        local quantidadePosicoes = 0
                                        for _ in pairs(grupo.positions) do
                                            quantidadePosicoes = quantidadePosicoes + 1
                                        end
                                        quantidadeFontes = quantidadeFontes + quantidadePosicoes
                                    end
                                end
                                if quantidadeFontes > 0 then
                                    local temperaturaAlvo = tonumber(dadosModGerador.HeatingTargetTemp) or 22
                                    local diferencaTemperatura = temperaturaAlvo - temperaturaReferencia
                                    local cargaPorFonte = cargaBase + cargaPorGrau * diferencaTemperatura
                                    configuracaoAquecimento = {
                                        load = cargaPorFonte * quantidadeFontes,
                                        target = temperaturaAlvo,
                                        sources = quantidadeFontes
                                    }
                                    break
                                end
                            -- Se estiver desligado mas com aquecimento ativado, guarda como fallback
                            elseif dadosModGerador and dadosModGerador.HeatingEnabled == true and not configuracaoAquecimento and type(dadosModGerador.HeatingPositions) == "table" then
                                local quantidadeFontes = 0
                                for _, grupo in pairs(dadosModGerador.HeatingPositions) do
                                    if type(grupo.positions) == "table" then
                                        local quantidadePosicoes = 0
                                        for _ in pairs(grupo.positions) do
                                            quantidadePosicoes = quantidadePosicoes + 1
                                        end
                                        quantidadeFontes = quantidadeFontes + quantidadePosicoes
                                    end
                                end
                                if quantidadeFontes > 0 then
                                    local temperaturaAlvo = tonumber(dadosModGerador.HeatingTargetTemp) or 22
                                    local diferencaTemperatura = temperaturaAlvo - temperaturaReferencia
                                    local cargaPorFonte = cargaBase + cargaPorGrau * diferencaTemperatura
                                    configuracaoAquecimento = {
                                        load = cargaPorFonte * quantidadeFontes,
                                        target = temperaturaAlvo,
                                        sources = quantidadeFontes
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
        if configuracaoAquecimento and configuracaoAquecimento.load then
            break
        end
    end

    return configuracaoAquecimento and configuracaoAquecimento.load or 0
end

-- ============================================================================
-- CONSTRUTOR
-- ============================================================================

--- Cria uma nova instância de dados do prédio (BuildingData) a partir do interruptor físico.
--- @param interruptorLuz IsoLightSwitch O interruptor âncora do prédio.
--- @param raioBorda number|nil O raio máximo de varredura (opcional).
--- @return BuildingData A nova instância do modelo de dados populada.
function LKS_EletricidadeConstrucao.Data.Building.New(interruptorLuz, raioBorda)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    local Geometry = LKS_EletricidadeConstrucao.Utils.Geometry
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    
    -- Validação do objeto de entrada
    Validation.AssertNotNil(interruptorLuz, "O interruptor de luz não pode ser nulo")
    Validation.Assert(Validation.IsLightSwitch(interruptorLuz), "O objeto deve ser uma instância válida de IsoLightSwitch")
    
    -- Coleta coordenadas
    local coordenadaX = interruptorLuz:getX()
    local coordenadaY = interruptorLuz:getY()
    local coordenadaZ = interruptorLuz:getZ()
    
    -- Clona a estrutura do Schema
    local dadosPredio = Table.DeepCopy(BuildingSchema)
    
    -- Define coordenadas e ID único
    dadosPredio.x = coordenadaX
    dadosPredio.y = coordenadaY
    dadosPredio.z = coordenadaZ
    dadosPredio.id = LKS_EletricidadeConstrucao.Data.Building.MakeId(coordenadaX, coordenadaY, coordenadaZ)
    
    -- Define raio de varredura
    local Constants = LKS_EletricidadeConstrucao.Constants
    dadosPredio.borderRadius = raioBorda or Constants.BUILDING.DEFAULT_BORDER_RADIUS or 10
    
    -- Detecta se pertence ao interior de um trailer/RV
    dadosPredio.isRVInterior = Geometry.IsRVInteriorCoordinate(coordenadaX, coordenadaY, coordenadaZ)
    
    -- Registra carimbo de hora
    dadosPredio.lastScanTime = getTimestampMs()
    
    return dadosPredio
end

-- ============================================================================
-- GERAÇÃO E LEITURA DE IDENTIFICADORES (ID)
-- ============================================================================

--- Gera o ID único de texto para um prédio a partir de suas coordenadas no mundo.
--- @param coordenadaX number A coordenada X.
--- @param coordenadaY number A coordenada Y.
--- @param coordenadaZ number A coordenada Z.
--- @return string O ID correspondente (formato: bld_x_y_z).
function LKS_EletricidadeConstrucao.Data.Building.MakeId(coordenadaX, coordenadaY, coordenadaZ)
    return string.format("bld_%d_%d_%d", coordenadaX, coordenadaY, coordenadaZ)
end

--- Realiza o parse de um ID único de prédio de volta para coordenadas numéricas.
--- @param identificador string O ID gerado (formato: bld_x_y_z).
--- @return number|nil, number|nil, number|nil Retorna coordenadaX, coordenadaY, coordenadaZ ou nil se for inválido.
function LKS_EletricidadeConstrucao.Data.Building.ParseId(identificador)
    if not identificador then
        return nil, nil, nil
    end
    
    local coordenadaX, coordenadaY, coordenadaZ = identificador:match("bld_(-?%d+)_(-?%d+)_(-?%d+)")
    if not coordenadaX then
        return nil, nil, nil
    end
    
    return tonumber(coordenadaX), tonumber(coordenadaY), tonumber(coordenadaZ)
end

-- ============================================================================
-- VALIDAÇÃO DE INTEGRIDADE
-- ============================================================================

--- Valida se a estrutura de dados de um prédio está correta e dentro dos limites permitidos.
--- @param dadosPredio BuildingData A tabela contendo os dados do prédio.
--- @return boolean, string|nil Retorna true se estiver correto, ou false com a mensagem descritiva do erro.
function LKS_EletricidadeConstrucao.Data.Building.Validate(dadosPredio)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Verifica se é do tipo tabela
    if not Validation.IsTable(dadosPredio) then
        return false, "Os dados do prédio devem estar estruturados em uma tabela"
    end
    
    -- Valida chaves obrigatórias requeridas pelo Schema
    local valido, erro = Validation.ValidateKeys(dadosPredio, {
        "id", "x", "y", "z", "powerConsumers", "totalPowerDraw",
        "heatingPowerDraw", "isPowered", "borderRadius", "lastScanTime"
    }, "Dados do prédio")
    
    if not valido then
        return false, erro
    end
    
    -- Valida formato do identificador único
    valido, erro = Validation.ValidateNotEmpty(dadosPredio.id, "ID do Prédio")
    if not valido then
        return false, erro
    end
    
    -- Valida se as coordenadas são numéricas e válidas
    valido, erro = Validation.ValidateCoordinates(dadosPredio.x, dadosPredio.y, dadosPredio.z)
    if not valido then
        return false, erro
    end
    
    -- Valida o tipo do estado elétrico
    if not Validation.IsBoolean(dadosPredio.isPowered) then
        return false, "O campo 'isPowered' deve ser um valor booleano"
    end
    
    -- Valida intervalos numéricos aceitáveis
    valido, erro = Validation.ValidateNonNegative(dadosPredio.totalPowerDraw, "totalPowerDraw")
    if not valido then
        return false, erro
    end
    
    valido, erro = Validation.ValidatePositive(dadosPredio.borderRadius, "borderRadius")
    if not valido then
        return false, erro
    end
    
    -- Valida se a tabela de consumidores está no formato correto
    if not Validation.IsTable(dadosPredio.powerConsumers) then
        return false, "O campo 'powerConsumers' deve ser uma tabela"
    end
    
    -- Valida gerador associado caso esteja preenchido
    if dadosPredio.generatorId ~= nil and not Validation.IsString(dadosPredio.generatorId) then
        return false, "O campo 'generatorId' deve ser do tipo texto (string) ou nulo"
    end
    
    return true, nil
end

-- ============================================================================
-- SERIALIZAÇÃO E DESSERIALIZAÇÃO (PERSISTÊNCIA MODDATA)
-- ============================================================================

--- Serializa os dados do prédio para persistência no ModData do jogo.
--- Remove chaves efêmeras que devem ser recalculadas dinamicamente a cada carregamento de chunk para evitar bugs de desatualização.
--- @param dadosPredio BuildingData Os dados do prédio a serem limpos e serializados.
--- @return table Uma cópia limpa e serializável dos dados do prédio.
function LKS_EletricidadeConstrucao.Data.Building.Serialize(dadosPredio)
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local copia = Table.DeepCopy(dadosPredio)
    
    -- Campos temporários e voláteis recalculados dinamicamente no carregamento (ScanBuilding)
    copia.powerConsumers = nil
    copia.heatingEnabled = nil
    copia.heatingSourceCount = nil
    copia.heatingTargetTemp = nil
    copia.heatingPowerDraw = nil
    
    return copia
end

--- Desserializa a estrutura de dados de um prédio a partir dos dados do ModData do jogo.
--- @param dadosSerializados table Tabela de dados brutos carregados do ModData.
--- @return BuildingData|nil Retorna os dados desserializados estruturados ou nil se for inválido.
function LKS_EletricidadeConstrucao.Data.Building.Deserialize(dadosSerializados)
    if not dadosSerializados then
        return nil
    end
    
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local dadosPredio = Table.DeepCopy(dadosSerializados)

    -- Restaura campos de simulação locais e dinâmicos não persistidos
    if dadosPredio.powerConsumers == nil then
        dadosPredio.powerConsumers = {}
    end
    if dadosPredio.heatingPowerDraw == nil then
        dadosPredio.heatingPowerDraw = 0
    end
    if dadosPredio.heatingEnabled == nil then
        dadosPredio.heatingEnabled = false
    end
    if dadosPredio.heatingSourceCount == nil then
        dadosPredio.heatingSourceCount = 0
    end
    if dadosPredio.heatingTargetTemp == nil then
        dadosPredio.heatingTargetTemp = 22
    end
    
    -- Valida os dados carregados do prédio
    local valido, erro = LKS_EletricidadeConstrucao.Data.Building.Validate(dadosPredio)
    if not valido then
        LKS_EletricidadeConstrucao.Error("[Building.Deserialize] Dados desserializados do prédio inválidos: " .. erro)
        return nil
    end
    
    return dadosPredio
end

-- ============================================================================
-- OPERAÇÕES COM CONSUMIDORES DE ENERGIA
-- ============================================================================

--- Adiciona um consumidor elétrico cadastrado à malha de dados do prédio.
--- @param dadosPredio BuildingData Os dados do prédio.
--- @param consumidor ConsumerData Os dados do consumidor elétrico a ser inserido.
function LKS_EletricidadeConstrucao.Data.Building.AddConsumer(dadosPredio, consumidor)
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local maximoConsumidores = ((LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.BUILDING)
        and LKS_EletricidadeConstrucao.Constants.BUILDING.MAX_CONSUMERS_PER_BUILDING) or 500

    local consumidoresContados = 0
    for _ in pairs(dadosPredio.powerConsumers) do
        consumidoresContados = consumidoresContados + 1
    end

    if consumidoresContados >= maximoConsumidores then
        return
    end
    
    -- Verifica se o consumidor já está registrado por sua coordenada física
    local existe = Table.Find(dadosPredio.powerConsumers, function(consumidorItem)
        return consumidorItem.squareX == consumidor.squareX 
            and consumidorItem.squareY == consumidor.squareY 
            and consumidorItem.squareZ == consumidor.squareZ
    end)
    
    if not existe then
        table.insert(dadosPredio.powerConsumers, consumidor)
        LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(dadosPredio)
    end
end

--- Remove um consumidor elétrico cadastrado da malha de dados do prédio.
--- @param dadosPredio BuildingData Os dados do prédio.
--- @param coordenadaX number A coordenada X física do consumidor.
--- @param coordenadaY number A coordenada Y física do consumidor.
--- @param coordenadaZ number A coordenada Z física do consumidor.
function LKS_EletricidadeConstrucao.Data.Building.RemoveConsumer(dadosPredio, coordenadaX, coordenadaY, coordenadaZ)
    local novosConsumidores = {}
    
    -- Filtra a lista de consumidores excluindo o alvo correspondente à coordenada
    for _, consumidor in pairs(dadosPredio.powerConsumers) do
        if not (consumidor.squareX == coordenadaX
           and consumidor.squareY == coordenadaY
           and consumidor.squareZ == coordenadaZ) then
            table.insert(novosConsumidores, consumidor)
        end
    end
    dadosPredio.powerConsumers = novosConsumidores
    
    LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(dadosPredio)
end

--- Limpa todos os consumidores de energia registrados no prédio e zera a carga.
--- @param dadosPredio BuildingData Os dados do prédio.
function LKS_EletricidadeConstrucao.Data.Building.ClearConsumers(dadosPredio)
    dadosPredio.powerConsumers = {}
    dadosPredio.totalPowerDraw = 0
end

--- Recalcula a carga de energia elétrica do prédio somando o consumo dos aparelhos ativamente ligados.
--- @param dadosPredio BuildingData Os dados do prédio.
function LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(dadosPredio)
    local potenciaTotal = 0
    local consumidoresAtivos = 0

    -- Percorre a lista de consumidores elétricos ativos
    for _, consumidor in pairs(dadosPredio.powerConsumers) do
        if consumidor.isActive then
            potenciaTotal = potenciaTotal + (consumidor.powerDraw or 1)
            consumidoresAtivos = consumidoresAtivos + 1
        end
    end

    -- Calcula e adiciona a carga extra de aquecimento se houver consumo ativo
    local cargaAquecedor = ComputeHeatingLoad(dadosPredio)
    dadosPredio.heatingPowerDraw = cargaAquecedor
    potenciaTotal = potenciaTotal + cargaAquecedor

    -- Atualiza as variáveis de controle de carga no modelo de dados
    dadosPredio.totalPowerDraw = potenciaTotal
    dadosPredio.activeConsumerCount = consumidoresAtivos
    
    local totalConsumidores = 0
    for _ in pairs(dadosPredio.powerConsumers) do
        totalConsumidores = totalConsumidores + 1
    end
    dadosPredio.totalConsumers = totalConsumidores
end

-- ============================================================================
-- OPERAÇÕES DE ESTADO DE FORNECIMENTO ELÉTRICO
-- ============================================================================

--- Define o estado atual de fornecimento de energia elétrica do prédio (ligado/desligado).
--- @param dadosPredio BuildingData Os dados do prédio.
--- @param alimentado boolean Retorna true se o prédio estiver energizado.
function LKS_EletricidadeConstrucao.Data.Building.SetPowered(dadosPredio, alimentado)
    if dadosPredio.isPowered ~= alimentado then
        dadosPredio.isPowered = alimentado
    end
end

--- Conecta o prédio ao identificador de um gerador no ecossistema.
--- @param dadosPredio BuildingData Os dados do prédio.
--- @param geradorId string O ID exclusivo do gerador a ser conectado.
function LKS_EletricidadeConstrucao.Data.Building.ConnectGenerator(dadosPredio, geradorId)
    if dadosPredio.generatorId ~= geradorId then
        dadosPredio.generatorId = geradorId
    end
end

--- Desconecta o prédio de qualquer gerador, zerando seu estado elétrico (desliga energia).
--- @param dadosPredio BuildingData Os dados do prédio.
function LKS_EletricidadeConstrucao.Data.Building.DisconnectGenerator(dadosPredio)
    dadosPredio.generatorId = nil
    LKS_EletricidadeConstrucao.Data.Building.SetPowered(dadosPredio, false)
end

-- ============================================================================
-- OPERAÇÕES DE ESCANEAMENTO (VARREDURA)
-- ============================================================================

--- Registra a data/hora real de conclusão do último escaneamento de contorno realizado no prédio.
--- @param dadosPredio BuildingData Os dados do prédio.
function LKS_EletricidadeConstrucao.Data.Building.MarkScanned(dadosPredio)
    dadosPredio.lastScanTime = getTimestampMs()
end

--- Verifica se o intervalo de tempo configurado já passou e o prédio precisa ser escaneado novamente.
--- @param dadosPredio BuildingData Os dados do prédio.
--- @param intervaloMilissegundos number O intervalo de re-escaneamento em milissegundos.
--- @return boolean Retorna true se for necessário rodar um novo escaneamento.
function LKS_EletricidadeConstrucao.Data.Building.NeedsRescan(dadosPredio, intervaloMilissegundos)
    local tempoAtual = getTimestampMs()
    return (tempoAtual - dadosPredio.lastScanTime) >= intervaloMilissegundos
end

--- Define as coordenadas geográficas limites da caixa delimitadora física (Bounding Box) do prédio.
--- @param dadosPredio BuildingData Os dados do prédio.
--- @param minimoX number Coordenada X mínima.
--- @param minimoY number Coordenada Y mínima.
--- @param maximoX number Coordenada X máxima.
--- @param maximoY number Coordenada Y máxima.
function LKS_EletricidadeConstrucao.Data.Building.SetBoundingBox(dadosPredio, minimoX, minimoY, maximoX, maximoY)
    dadosPredio.boundingBox = {
        minX = minimoX,
        minY = minimoY,
        maxX = maximoX,
        maxY = maximoY
    }
end

-- ============================================================================
-- FUNÇÕES AUXILIARES DE SUPORTE
-- ============================================================================

--- Verifica se o prédio está ativamente vinculado/conectado a um gerador no ecossistema.
--- @param dadosPredio BuildingData Os dados do prédio.
--- @return boolean Retorna true se houver gerador conectado.
function LKS_EletricidadeConstrucao.Data.Building.IsConnected(dadosPredio)
    return dadosPredio.generatorId ~= nil
end

--- Obtém a quantidade total de consumidores elétricos atualmente ligados no prédio.
--- @param dadosPredio BuildingData Os dados do prédio.
--- @return number Quantidade de consumidores ativos.
function LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(dadosPredio)
    local consumidoresAtivos = 0
    for _, consumidor in pairs(dadosPredio.powerConsumers) do
        if consumidor.isActive then
            consumidoresAtivos = consumidoresAtivos + 1
        end
    end
    return consumidoresAtivos
end

--- Obtém o total acumulado de consumidores (ligados e desligados) cadastrados na malha do prédio.
--- @param dadosPredio BuildingData Os dados do prédio.
--- @return number Quantidade total de consumidores elétricos.
function LKS_EletricidadeConstrucao.Data.Building.GetTotalConsumerCount(dadosPredio)
    local totalConsumidores = 0
    for _ in pairs(dadosPredio.powerConsumers) do
        totalConsumidores = totalConsumidores + 1
    end
    return totalConsumidores
end

--- Verifica se o prédio deve ou não estar energizado com base no estado operacional do gerador conectado.
--- @param dadosPredio BuildingData Os dados do prédio.
--- @param dadosGerador GeneratorData|nil Dados operacionais do gerador associado (opcional).
--- @return boolean Retorna true se o gerador estiver ativo e fornecendo energia.
function LKS_EletricidadeConstrucao.Data.Building.ShouldProvidePower(dadosPredio, dadosGerador)
    if not dadosPredio.generatorId then
        return false
    end
    
    if dadosGerador then
        -- Retorna true se o gerador estiver rodando ativamente com combustível
        return LKS_EletricidadeConstrucao.Data.Generator.IsRunning(dadosGerador)
    end
    
    -- Suposição padrão: assume energizado caso haja vínculo e o gerador físico não tenha sido avaliado
    return true
end

-- ============================================================================
-- DEPURAÇÃO
-- ============================================================================

--- Converte o estado operacional do prédio em uma string descritiva legível para fins de depuração.
--- @param dadosPredio BuildingData Os dados do prédio analisado.
--- @return string Representação descritiva formatada.
function LKS_EletricidadeConstrucao.Data.Building.ToString(dadosPredio)
    return string.format(
        "Predio[%s] em (%d,%d,%d) | Gerador:%s Alimentado:%s Consumidores:%d/%d Carga:%.1f Raio:%d",
        dadosPredio.id,
        dadosPredio.x, dadosPredio.y, dadosPredio.z,
        dadosPredio.generatorId or "nenhum",
        tostring(dadosPredio.isPowered),
        LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(dadosPredio),
        (function() 
            local contadorLoop = 0 
            for _ in pairs(dadosPredio.powerConsumers) do 
                contadorLoop = contadorLoop + 1 
            end 
            return contadorLoop 
        end)(),
        dadosPredio.totalPowerDraw,
        dadosPredio.borderRadius
    )
end

-- ============================================================================
-- INICIALIZAÇÃO E REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Data.Building", "2.0.0")

return LKS_EletricidadeConstrucao.Data.Building
