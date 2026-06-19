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

-- ARQUIVO: LKS_EletricidadeConstrucao_Data_Generator.lua
-- OBJETIVO: Modelo de dados (Schema) e operações para o Gerador (Generator).
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace existe antes de carregar o módulo
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Data_Generator] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- ============================================================================
-- DEFINIÇÃO DO SCHEMA
-- ============================================================================

--- Schema de dados de um Gerador.
--- @class GeneratorData
--- @field id string Identificador único (formato: gen_x_y_z)
--- @field x number Coordenada X no mundo global
--- @field y number Coordenada Y no mundo global
--- @field z number Coordenada Z no mundo global
--- @field activated boolean Estado de ativação do gerador (ligado/desligado)
--- @field fuelAmount number Quantidade atual de combustível (0 a 100)
--- @field condition number Condição de integridade do gerador (0 a 100)
--- @field connectedBuildings table Vetor contendo os IDs dos prédios conectados
--- @field strain number Carga/esforço elétrico atual do gerador (0 a 100+)
--- @field lastUpdateTime number Carimbo de data/hora da última atualização (milissegundos reais)
--- @field lastUnloadGameMinutes number|nil DESCONTINUADO - não é mais utilizado (cálculo de combustível contínuo)
--- @field chunkKey string Chave identificadora do chunk geográfico (chunk_X_Y)
--- @field customFuelRate number|nil Sobrescrita da taxa customizada de consumo de combustível
--- @field isRVInterior boolean Retorna true se o gerador estiver dentro do interior de um trailer/RV
-- Nota técnica: as chaves heatingEnabled / heatingSourceCount / heatingTargetTemp foram removidas na versão B-99.
-- A configuração de aquecimento agora pertence exclusivamente à classe IsoObject.

local GeneratorSchema = {
    id = "",
    x = 0,
    y = 0,
    z = 0,
    activated = false,
    fuelAmount = 0,
    condition = 100,
    connectedBuildings = {},
    strain = 0,
    lastUpdateTime = 0,
    chunkKey = "",
    customFuelRate = nil,
    isRVInterior = false,
}

-- ============================================================================
-- CONSTRUTOR
-- ============================================================================

--- Cria uma nova instância de dados do gerador (GeneratorData) a partir do objeto físico do jogo.
--- @param objetoGerador IsoGenerator O objeto de gerador físico (Java IsoGenerator).
--- @return GeneratorData A nova instância populada com o estado do gerador.
function LKS_EletricidadeConstrucao.Data.Generator.New(objetoGerador)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    local Geometry = LKS_EletricidadeConstrucao.Utils.Geometry
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    
    -- Validação do objeto de entrada
    Validation.AssertNotNil(objetoGerador, "O objeto de gerador não pode ser nulo")
    Validation.Assert(Validation.IsGenerator(objetoGerador), "O objeto deve ser uma instância válida de IsoGenerator")
    
    -- Obtém coordenadas do mundo
    local coordenadaX = objetoGerador:getX()
    local coordenadaY = objetoGerador:getY()
    local coordenadaZ = objetoGerador:getZ()
    
    -- Instancia a estrutura base a partir do Schema
    local dadosGerador = Table.DeepCopy(GeneratorSchema)
    
    -- Popula coordenadas e identificação
    dadosGerador.x = coordenadaX
    dadosGerador.y = coordenadaY
    dadosGerador.z = coordenadaZ
    dadosGerador.id = LKS_EletricidadeConstrucao.Data.Generator.MakeId(coordenadaX, coordenadaY, coordenadaZ)
    
    -- Popula estado a partir do objeto físico Java
    dadosGerador.activated = objetoGerador:isActivated()
    dadosGerador.fuelAmount = objetoGerador:getFuel()
    dadosGerador.condition = objetoGerador:getCondition()
    
    -- Determina chaves geográficas e propriedades de mapa
    dadosGerador.chunkKey = Geometry.GetChunkKey(coordenadaX, coordenadaY)
    dadosGerador.isRVInterior = Geometry.IsRVInteriorCoordinate(coordenadaX, coordenadaY, coordenadaZ)
    
    -- Registra carimbo de hora
    dadosGerador.lastUpdateTime = getTimestampMs()
    
    return dadosGerador
end

-- ============================================================================
-- GERAÇÃO E LEITURA DE IDENTIFICADORES (ID)
-- ============================================================================

--- Gera o ID único de texto para um gerador a partir de suas coordenadas no mundo.
--- @param coordenadaX number A coordenada X.
--- @param coordenadaY number A coordenada Y.
--- @param coordenadaZ number A coordenada Z.
--- @return string O ID correspondente (formato: gen_x_y_z).
function LKS_EletricidadeConstrucao.Data.Generator.MakeId(coordenadaX, coordenadaY, coordenadaZ)
    return string.format("gen_%d_%d_%d", coordenadaX, coordenadaY, coordenadaZ)
end

--- Realiza o parse de um ID único de gerador de volta para coordenadas numéricas.
--- @param identificador string O ID gerado (formato: gen_x_y_z).
--- @return number|nil, number|nil, number|nil Retorna coordenadaX, coordenadaY, coordenadaZ ou nil se for inválido.
function LKS_EletricidadeConstrucao.Data.Generator.ParseId(identificador)
    if not identificador then
        return nil, nil, nil
    end
    
    local coordenadaX, coordenadaY, coordenadaZ = identificador:match("gen_(-?%d+)_(-?%d+)_(-?%d+)")
    if not coordenadaX then
        return nil, nil, nil
    end
    
    return tonumber(coordenadaX), tonumber(coordenadaY), tonumber(coordenadaZ)
end

-- ============================================================================
-- VALIDAÇÃO DE INTEGRIDADE
-- ============================================================================

--- Valida se a estrutura de dados de um gerador está correta e dentro dos limites permitidos.
--- @param dadosGerador GeneratorData A tabela de dados do gerador.
--- @return boolean, string|nil Retorna true se estiver correto, ou false com a mensagem descritiva do erro.
function LKS_EletricidadeConstrucao.Data.Generator.Validate(dadosGerador)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Verifica se é do tipo tabela
    if not Validation.IsTable(dadosGerador) then
        return false, "Os dados do gerador devem estar estruturados em uma tabela"
    end
    
    -- Verifica chaves obrigatórias requeridas pelo Schema
    local valido, erro = Validation.ValidateKeys(dadosGerador, {
        "id", "x", "y", "z", "activated", "fuelAmount", "condition",
        "connectedBuildings", "strain", "lastUpdateTime", "chunkKey"
    }, "Dados do gerador")
    
    if not valido then
        return false, erro
    end
    
    -- Valida formato do identificador único
    valido, erro = Validation.ValidateNotEmpty(dadosGerador.id, "ID do Gerador")
    if not valido then
        return false, erro
    end
    
    -- Valida se as coordenadas são numéricas e válidas
    valido, erro = Validation.ValidateCoordinates(dadosGerador.x, dadosGerador.y, dadosGerador.z)
    if not valido then
        return false, erro
    end
    
    -- Valida o tipo do estado de ativação
    if not Validation.IsBoolean(dadosGerador.activated) then
        return false, "O campo 'activated' deve ser um valor booleano"
    end
    
    -- Valida intervalos numéricos aceitáveis
    valido, erro = Validation.ValidateRange(dadosGerador.fuelAmount, 0, 100, "fuelAmount")
    if not valido then
        return false, erro
    end
    
    valido, erro = Validation.ValidateRange(dadosGerador.condition, 0, 100, "condition")
    if not valido then
        return false, erro
    end
    
    valido, erro = Validation.ValidateNonNegative(dadosGerador.strain, "strain")
    if not valido then
        return false, erro
    end
    
    -- Valida se a lista de prédios conectados é uma tabela válida
    if not Validation.IsTable(dadosGerador.connectedBuildings) then
        return false, "O campo 'connectedBuildings' deve ser uma tabela"
    end
    
    return true, nil
end

-- ============================================================================
-- SERIALIZAÇÃO E DESSERIALIZAÇÃO (PERSISTÊNCIA MODDATA)
-- ============================================================================

--- Serializa os dados do gerador em um formato de tabela limpa para armazenamento no ModData do jogo.
--- @param dadosGerador GeneratorData A estrutura de dados do gerador.
--- @return table Uma cópia limpa e serializável dos dados do gerador.
function LKS_EletricidadeConstrucao.Data.Generator.Serialize(dadosGerador)
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    return Table.DeepCopy(dadosGerador)
end

--- Desserializa a estrutura de dados de um gerador a partir dos dados do ModData.
--- @param dadosSerializados table Tabela de dados crus lidos do ModData.
--- @return GeneratorData|nil Retorna os dados desserializados ou nil se for inválido.
function LKS_EletricidadeConstrucao.Data.Generator.Deserialize(dadosSerializados)
    if not dadosSerializados then
        return nil
    end
    
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local Geometry = LKS_EletricidadeConstrucao.Utils.Geometry
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    local dadosGerador = Table.DeepCopy(dadosSerializados)

    -- Retrocompatibilidade: preenche chaves ausentes com valores padrão do Schema atual
    for campo, valorPadrao in pairs(GeneratorSchema) do
        if dadosGerador[campo] == nil then
            dadosGerador[campo] = valorPadrao
        end
    end
    
    -- Log de depuração interna
    print(string.format("[LKS_EletricidadeConstrucao_DESERIALIZE] gen=%s fuelAmount=%.2f (obtido do ModData)", 
        dadosGerador.id or "?", dadosGerador.fuelAmount or 0))
        
    -- Reconstrói a chave geográfica do chunk caso ausente
    if (not dadosGerador.chunkKey or dadosGerador.chunkKey == "") and Geometry then
        dadosGerador.chunkKey = Geometry.GetChunkKey(dadosGerador.x or 0, dadosGerador.y or 0)
    end
    
    -- Garante que a estrutura de conexões é uma tabela
    if not (Validation and Validation.IsTable and Validation.IsTable(dadosGerador.connectedBuildings)) then
        dadosGerador.connectedBuildings = {}
    end

    -- Realiza validação final dos dados lidos
    local valido, erro = LKS_EletricidadeConstrucao.Data.Generator.Validate(dadosGerador)
    if not valido then
        LKS_EletricidadeConstrucao.Error("[Generator.Deserialize] Estrutura de dados invalida: " .. erro)
        return nil
    end
    
    return dadosGerador
end

-- ============================================================================
-- OPERAÇÕES DE ATUALIZAÇÃO
-- ============================================================================

--- Sincroniza e atualiza os dados locais a partir do estado atual de um objeto de gerador físico (Java).
--- @param dadosGerador GeneratorData A tabela de dados do gerador a ser atualizada.
--- @param objetoGerador IsoGenerator O gerador físico Java de onde ler os dados.
function LKS_EletricidadeConstrucao.Data.Generator.UpdateFromObject(dadosGerador, objetoGerador)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    Validation.AssertNotNil(dadosGerador, "Os dados do gerador não podem ser nulos")
    Validation.AssertNotNil(objetoGerador, "O objeto de gerador físico não pode ser nulo")
    
    -- Sincroniza estado de ativação, combustível e integridade física
    dadosGerador.activated = objetoGerador:isActivated()
    dadosGerador.fuelAmount = objetoGerador:getFuel()
    dadosGerador.condition = objetoGerador:getCondition()
    dadosGerador.lastUpdateTime = getTimestampMs()
end

--- Calcula a carga/esforço elétrico (strain) atual do gerador com base na demanda de prédios conectados.
--- @param dadosGerador GeneratorData O gerador sendo analisado.
--- @param mapaDadosPredios table O mapa contendo todos os dados dos prédios indexados por ID.
--- @return number O percentual calculado da carga de strain elétrica (0 a 100+).
function LKS_EletricidadeConstrucao.Data.Generator.CalculateStrain(dadosGerador, mapaDadosPredios)
    local potenciaTotal = 0
    
    -- Acumula a demanda de potência de cada prédio vinculado
    for _, predioId in pairs(dadosGerador.connectedBuildings) do
        local dadosPredio = mapaDadosPredios[predioId]
        if dadosPredio then
            potenciaTotal = potenciaTotal + (dadosPredio.totalPowerDraw or 0)
        end
    end
    
    -- Converte a demanda bruta para um percentual de esforço elétrico
    local Constants = LKS_EletricidadeConstrucao.Constants
    local esforcoPorLuz = Constants.FUEL.BASE_STRAIN_PER_LIGHT or 1.0
    
    return potenciaTotal * esforcoPorLuz
end

-- ============================================================================
-- FUNÇÕES AUXILIARES DE SUPORTE
-- ============================================================================

--- Verifica se o gerador está ativamente em funcionamento (ligado e contendo combustível).
--- @param dadosGerador GeneratorData O gerador analisado.
--- @return boolean Retorna true se estiver em operação ativa.
function LKS_EletricidadeConstrucao.Data.Generator.IsRunning(dadosGerador)
    local possuiCombustivel = (dadosGerador.fuelAmount or 0) > 0
    local naoDesativado = (dadosGerador.activated ~= false)
    return possuiCombustivel and naoDesativado
end

--- Verifica se o nível de combustível está abaixo de um limite mínimo específico.
--- @param dadosGerador GeneratorData O gerador analisado.
--- @param limiteMinimo number|nil O limite mínimo crítico de combustível (padrão: 10).
--- @return boolean Retorna true se for necessário reabastecer.
function LKS_EletricidadeConstrucao.Data.Generator.NeedsRefuel(dadosGerador, limiteMinimo)
    limiteMinimo = limiteMinimo or 10
    return dadosGerador.fuelAmount < limiteMinimo
end

--- Obtém a quantidade estimada de horas de funcionamento restantes sob a taxa de consumo atual.
--- @param dadosGerador GeneratorData O gerador analisado.
--- @param taxaCombustivel number A taxa base de consumo de combustível por hora do gerador.
--- @return number A quantidade de horas estimadas restantes de autonomia.
function LKS_EletricidadeConstrucao.Data.Generator.GetRemainingHours(dadosGerador, taxaCombustivel)
    if not dadosGerador.activated or dadosGerador.fuelAmount <= 0 then
        return 0
    end
    
    -- Aplica o modificador de esforço (strain) estruturado
    local multiplicadorStrain = 1.0
    if dadosGerador.strain > 0 then
        local strain = dadosGerador.strain
        
        -- SISTEMA DE MULTIPLICADOR DE DEMANDA:
        -- 0-50% de Strain: Sem consumo adicional (1.0x)
        -- 51-75% de Strain: Escala de 1.0x a 1.25x
        -- 76-100% de Strain: Escala de 1.26x a 1.75x
        -- 101-200% de Strain: Escala de 1.75x a 3.0x
        
        if strain <= 50 then
            multiplicadorStrain = 1.0
        elseif strain <= 75 then
            local fatorStrain = (strain - 50) / 25
            multiplicadorStrain = 1.0 + (fatorStrain * 0.25)
        elseif strain <= 100 then
            local fatorStrain = (strain - 75) / 25
            multiplicadorStrain = 1.26 + (fatorStrain * 0.49)
        else
            local fatorStrain = math.min((strain - 100) / 100, 1.0)
            multiplicadorStrain = 1.75 + (fatorStrain * 1.25)
        end
        
        -- Limita o multiplicador ao teto configurado
        local Constants = LKS_EletricidadeConstrucao.Constants
        local multiplicadorMaximo = Constants.FUEL.MAX_STRAIN_MULTIPLIER or 3.0
        if multiplicadorStrain > multiplicadorMaximo then
            multiplicadorStrain = multiplicadorMaximo
        end
    end
    
    local taxaEfetiva = taxaCombustivel * multiplicadorStrain
    
    if taxaEfetiva <= 0 then
        return 999999 -- Autonomia infinita
    end
    
    return dadosGerador.fuelAmount / taxaEfetiva
end

--- Vincula um prédio conectado aos dados de carregamento do gerador.
--- @param dadosGerador GeneratorData O gerador analisado.
--- @param predioId string O ID do prédio a ser adicionado.
function LKS_EletricidadeConstrucao.Data.Generator.AddBuilding(dadosGerador, predioId)
    local jaConectado = false
    for _, valorId in pairs(dadosGerador.connectedBuildings) do
        if valorId == predioId then
            jaConectado = true
            break
        end
    end
    if not jaConectado then
        table.insert(dadosGerador.connectedBuildings, predioId)
    end
end

--- Remove a conexão de um prédio dos dados de carregamento do gerador.
--- @param dadosGerador GeneratorData O gerador analisado.
--- @param predioId string O ID do prédio a ser removido.
function LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding(dadosGerador, predioId)
    -- Recria a lista de prédios conectados excluindo o ID alvo
    local novaLista = {}
    for _, valorId in pairs(dadosGerador.connectedBuildings) do
        if valorId ~= predioId then
            table.insert(novaLista, valorId)
        end
    end
    dadosGerador.connectedBuildings = novaLista
end

--- Remove as conexões de todos os prédios e zera a carga de esforço elétrico.
--- @param dadosGerador GeneratorData O gerador analisado.
function LKS_EletricidadeConstrucao.Data.Generator.ClearBuildings(dadosGerador)
    dadosGerador.connectedBuildings = {}
    dadosGerador.strain = 0
end

-- ============================================================================
-- DEPURAÇÃO
-- ============================================================================

--- Converte o estado atual do gerador em uma string descritiva legível para fins de depuração.
--- @param dadosGerador GeneratorData O gerador analisado.
--- @return string Representação descritiva formatada.
function LKS_EletricidadeConstrucao.Data.Generator.ToString(dadosGerador)
    local quantidadePredios = 0
    if dadosGerador.connectedBuildings then
        for _ in pairs(dadosGerador.connectedBuildings) do
            quantidadePredios = quantidadePredios + 1
        end
    end
    return string.format(
        "Gerador[%s] em (%d,%d,%d) | Ligado:%s Combustivel:%.1f Integridade:%d Esforco:%.1f Predios:%d",
        dadosGerador.id,
        dadosGerador.x, dadosGerador.y, dadosGerador.z,
        tostring(dadosGerador.activated),
        dadosGerador.fuelAmount,
        dadosGerador.condition,
        dadosGerador.strain,
        quantidadePredios
    )
end

-- ============================================================================
-- INICIALIZAÇÃO E REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Data.Generator", "2.0.0")

return LKS_EletricidadeConstrucao.Data.Generator
