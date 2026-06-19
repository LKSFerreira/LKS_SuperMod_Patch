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

-- ARQUIVO: LKS_EletricidadeConstrucao_Data_State.lua
-- OBJETIVO: Modelo de dados (Schema) e operações para o Estado Global e Persistência do Mod.
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace existe antes de carregar o módulo
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Data_State] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- ============================================================================
-- DEFINIÇÃO DO SCHEMA
-- ============================================================================

--- Schema de dados do Estado Global.
--- @class StateData
--- @field version string Versão atual do mod
--- @field generators table Mapa contendo todos os dados dos geradores indexados por ID (GeneratorData)
--- @field buildings table Mapa contendo todos os dados dos prédios indexados por ID (BuildingData)
--- @field chunkIndex table Mapa de chunkKey para vetor de IDs de geradores (índice em runtime persistido para busca rápida)
--- @field lastFullSync number Carimbo de data/hora da última sincronização completa (Multiplayer)
--- @field lastDeltaSync number Carimbo de data/hora da última sincronização incremental (Multiplayer)
--- @field config table Configurações ativas do mod
--- @field statistics table Estatísticas de execução acumuladas em runtime

local StateSchema = {
    version = "2.0.0",
    generators = {},
    buildings = {},
    chunkIndex = {},
    lastFullSync = 0,
    lastDeltaSync = 0,
    config = {},
    statistics = {
        totalGenerators = 0,
        totalBuildings = 0,
        totalConsumers = 0,
        activeGenerators = 0,
        activeConsumers = 0,
        totalFuelConsumed = 0,
        uptime = 0
    }
}

-- ============================================================================
-- CONSTRUTOR
-- ============================================================================

--- Cria uma nova instância de dados do estado global (StateData).
--- @return StateData A nova instância populada com as configurações iniciais.
function LKS_EletricidadeConstrucao.Data.State.New()
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local dadosEstado = Table.DeepCopy(StateSchema)
    
    -- Define a versão atual do mod
    dadosEstado.version = LKS_EletricidadeConstrucao.VERSION or "2.0.0"
    
    -- Define carimbos de hora iniciais
    dadosEstado.lastFullSync = getTimestampMs()
    dadosEstado.lastDeltaSync = getTimestampMs()
    
    return dadosEstado
end

-- ============================================================================
-- VALIDAÇÃO DE INTEGRIDADE
-- ============================================================================

--- Valida se a estrutura de dados do estado global está correta.
--- @param dadosEstado StateData Os dados do estado global.
--- @return boolean, string|nil Retorna true se estiver correto, ou false com a mensagem descritiva do erro.
function LKS_EletricidadeConstrucao.Data.State.Validate(dadosEstado)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Verifica se é do tipo tabela
    if not Validation.IsTable(dadosEstado) then
        return false, "Os dados do estado devem estar estruturados em uma tabela"
    end
    
    -- Verifica chaves obrigatórias requeridas pelo Schema
    local valido, erro = Validation.ValidateKeys(dadosEstado, {
        "version", "generators", "buildings", "chunkIndex", "config", "statistics"
    }, "Dados do estado")
    
    if not valido then
        return false, erro
    end
    
    -- Valida formato do campo de versão
    valido, erro = Validation.ValidateNotEmpty(dadosEstado.version, "versão")
    if not valido then
        return false, erro
    end
    
    -- Valida se os mapas internos são tabelas
    if not Validation.IsTable(dadosEstado.generators) then
        return false, "O mapa 'generators' deve ser uma tabela"
    end
    
    if not Validation.IsTable(dadosEstado.buildings) then
        return false, "O mapa 'buildings' deve ser uma tabela"
    end
    
    if not Validation.IsTable(dadosEstado.config) then
        return false, "O mapa 'config' deve ser uma tabela"
    end
    
    if not Validation.IsTable(dadosEstado.statistics) then
        return false, "O mapa 'statistics' deve ser uma tabela"
    end

    if not Validation.IsTable(dadosEstado.chunkIndex) then
        return false, "O mapa 'chunkIndex' deve ser uma tabela"
    end
    
    return true, nil
end

-- ============================================================================
-- SERIALIZAÇÃO E DESSERIALIZAÇÃO (PERSISTÊNCIA MODDATA)
-- ============================================================================

--- Serializa os dados do estado global para armazenamento no ModData.
--- @param dadosEstado StateData Os dados do estado global.
--- @return table Os dados estruturados prontos para serialização.
function LKS_EletricidadeConstrucao.Data.State.Serialize(dadosEstado)
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local dadosSerializados = Table.DeepCopy(dadosEstado)
    
    -- Serializa recursivamente a coleção de geradores
    local geradoresSerializados = {}
    for idGerador, dadosGerador in pairs(dadosEstado.generators) do
        geradoresSerializados[idGerador] = LKS_EletricidadeConstrucao.Data.Generator.Serialize(dadosGerador)
    end
    dadosSerializados.generators = geradoresSerializados
    
    -- Serializa recursivamente a coleção de prédios
    local prediosSerializados = {}
    for idPredio, dadosPredio in pairs(dadosEstado.buildings) do
        prediosSerializados[idPredio] = LKS_EletricidadeConstrucao.Data.Building.Serialize(dadosPredio)
    end
    dadosSerializados.buildings = prediosSerializados
    
    return dadosSerializados
end

--- Desserializa a estrutura de dados de um estado global a partir do ModData.
--- @param dadosSerializados table Os dados brutos lidos do ModData.
--- @return StateData|nil O estado desserializado ou nil se for inválido.
function LKS_EletricidadeConstrucao.Data.State.Deserialize(dadosSerializados)
    if not dadosSerializados then
        return nil
    end
    
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local dadosEstado = Table.DeepCopy(dadosSerializados)
    
    -- Desserializa a coleção de geradores
    local geradoresDesserializados = {}
    for idGerador, geradorSerializado in pairs(dadosEstado.generators or {}) do
        local dadosGerador = LKS_EletricidadeConstrucao.Data.Generator.Deserialize(geradorSerializado)
        if dadosGerador then
            geradoresDesserializados[idGerador] = dadosGerador
        else
            LKS_EletricidadeConstrucao.Warn("[State.Deserialize] Falha ao desserializar gerador: " .. idGerador)
        end
    end
    dadosEstado.generators = geradoresDesserializados
    
    -- Desserializa a coleção de prédios
    local prediosDesserializados = {}
    for idPredio, predioSerializado in pairs(dadosEstado.buildings or {}) do
        local dadosPredio = LKS_EletricidadeConstrucao.Data.Building.Deserialize(predioSerializado)
        if dadosPredio then
            prediosDesserializados[idPredio] = dadosPredio
        else
            LKS_EletricidadeConstrucao.Warn("[State.Deserialize] Falha ao desserializar prédio: " .. idPredio)
        end
    end
    dadosEstado.buildings = prediosDesserializados

    -- Reconstrói dinamicamente o índice de chunks em runtime para consistência
    dadosEstado.chunkIndex = {}
    for idGerador, dadosGerador in pairs(dadosEstado.generators) do
        local chunkKey = dadosGerador.chunkKey
        if not chunkKey and LKS_EletricidadeConstrucao.Utils and LKS_EletricidadeConstrucao.Utils.Geometry then
            chunkKey = LKS_EletricidadeConstrucao.Utils.Geometry.GetChunkKey(dadosGerador.x, dadosGerador.y)
            dadosGerador.chunkKey = chunkKey
        end
        if chunkKey then
            dadosEstado.chunkIndex[chunkKey] = dadosEstado.chunkIndex[chunkKey] or {}
            table.insert(dadosEstado.chunkIndex[chunkKey], idGerador)
        end
    end
    
    -- Valida integridade geral do estado reconstruído
    local valido, erro = LKS_EletricidadeConstrucao.Data.State.Validate(dadosEstado)
    if not valido then
        LKS_EletricidadeConstrucao.Error("[State.Deserialize] Dados de estado desserializados inválidos: " .. erro)
        return nil
    end
    
    return dadosEstado
end

-- ============================================================================
-- OPERAÇÕES COM GERADORES
-- ============================================================================

--- Adiciona os dados de um gerador ao estado global.
--- @param dadosEstado StateData Os dados do estado global.
--- @param dadosGerador GeneratorData O gerador a ser adicionado.
function LKS_EletricidadeConstrucao.Data.State.AddGenerator(dadosEstado, dadosGerador)
    -- Garante que o gerador possui uma chave de chunk geográfico para indexação rápida
    if (not dadosGerador.chunkKey or dadosGerador.chunkKey == "")
            and LKS_EletricidadeConstrucao.Utils and LKS_EletricidadeConstrucao.Utils.Geometry then
        dadosGerador.chunkKey = LKS_EletricidadeConstrucao.Utils.Geometry.GetChunkKey(dadosGerador.x, dadosGerador.y)
    end

    -- Mescla conexões existentes de connectedBuildings para preservar links durante operações de carregamento
    local existente = dadosEstado.generators[dadosGerador.id]
    if existente then
        dadosGerador.connectedBuildings = dadosGerador.connectedBuildings or {}
        
        -- O estado persistido é autoridade máxima para nível de combustível e ativação
        dadosGerador.fuelAmount = existente.fuelAmount
        dadosGerador.activated = existente.activated
        dadosGerador.lastSyncedFuel = existente.lastSyncedFuel
        
        -- Sincroniza links de prédios conectados
        for _, idPredio in pairs(existente.connectedBuildings or {}) do
            local encontrado = false
            for _, idPredioItem in pairs(dadosGerador.connectedBuildings) do
                if idPredioItem == idPredio then
                    encontrado = true
                    break
                end
            end
            if not encontrado then
                table.insert(dadosGerador.connectedBuildings, idPredio)
            end
        end
    end

    dadosEstado.generators[dadosGerador.id] = dadosGerador

    -- Atualiza índice de chunks
    if dadosGerador.chunkKey then
        dadosEstado.chunkIndex[dadosGerador.chunkKey] = dadosEstado.chunkIndex[dadosGerador.chunkKey] or {}
        local lista = dadosEstado.chunkIndex[dadosGerador.chunkKey]
        local existe = false
        for _, idGerador in ipairs(lista) do
            if idGerador == dadosGerador.id then
                existe = true
                break
            end
        end
        if not existe then
            table.insert(lista, dadosGerador.id)
        end
    end

    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(dadosEstado)
end

--- Remove um gerador do estado global.
--- @param dadosEstado StateData Os dados do estado global.
--- @param idGerador string O ID exclusivo do gerador.
--- @return GeneratorData|nil Retorna os dados do gerador removido ou nil se não for encontrado.
function LKS_EletricidadeConstrucao.Data.State.RemoveGenerator(dadosEstado, idGerador)
    local itemRemovido = dadosEstado.generators[idGerador]
    dadosEstado.generators[idGerador] = nil

    -- Remove do índice de chunks
    if itemRemovido and itemRemovido.chunkKey and dadosEstado.chunkIndex[itemRemovido.chunkKey] then
        local lista = dadosEstado.chunkIndex[itemRemovido.chunkKey]
        for indice = #lista, 1, -1 do
            if lista[indice] == idGerador then
                table.remove(lista, indice)
            end
        end
        if #lista == 0 then
            dadosEstado.chunkIndex[itemRemovido.chunkKey] = nil
        end
    end
    
    if itemRemovido then
        LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(dadosEstado)
    end
    
    return itemRemovido
end

--- Obtém a estrutura de dados de um gerador por seu ID.
--- @param dadosEstado StateData Os dados do estado global.
--- @param idGerador string O ID exclusivo do gerador.
--- @return GeneratorData|nil Os dados do gerador correspondente ou nulo.
function LKS_EletricidadeConstrucao.Data.State.GetGenerator(dadosEstado, idGerador)
    return dadosEstado.generators[idGerador]
end

--- Obtém todos os geradores vinculados ao estado.
--- @param dadosEstado StateData Os dados do estado global.
--- @return table Mapa de IDs para estruturas GeneratorData.
function LKS_EletricidadeConstrucao.Data.State.GetAllGenerators(dadosEstado)
    return dadosEstado.generators
end

-- ============================================================================
-- OPERAÇÕES COM PRÉDIOS/ESTRUTURAS
-- ============================================================================

--- Adiciona os dados de um prédio ao estado global.
--- @param dadosEstado StateData Os dados do estado global.
--- @param dadosPredio BuildingData O prédio a ser adicionado.
function LKS_EletricidadeConstrucao.Data.State.AddBuilding(dadosEstado, dadosPredio)
    local existente = dadosEstado.buildings[dadosPredio.id]
    if existente and existente.connectedGenerators then
        local possuiGeradores = false
        for _ in pairs(existente.connectedGenerators) do
            possuiGeradores = true
            break
        end
        if possuiGeradores then
            -- Preserva os links de geradores da malha ativa para evitar wipes no escaneamento de chunks
            dadosPredio.connectedGenerators = dadosPredio.connectedGenerators or {}
            for _, chaveGerador in pairs(existente.connectedGenerators) do
                local encontrado = false
                for _, chaveGeradorItem in pairs(dadosPredio.connectedGenerators) do
                    if chaveGeradorItem == chaveGerador then
                        encontrado = true
                        break
                    end
                end
                if not encontrado then
                    table.insert(dadosPredio.connectedGenerators, chaveGerador)
                end
            end
        end
    end
    dadosEstado.buildings[dadosPredio.id] = dadosPredio
    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(dadosEstado)
end

--- Remove um prédio do estado global.
--- @param dadosEstado StateData Os dados do estado global.
--- @param idPredio string O ID exclusivo do prédio.
--- @return BuildingData|nil Retorna os dados do prédio removido ou nulo.
function LKS_EletricidadeConstrucao.Data.State.RemoveBuilding(dadosEstado, idPredio)
    local itemRemovido = dadosEstado.buildings[idPredio]
    dadosEstado.buildings[idPredio] = nil
    
    if itemRemovido then
        LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(dadosEstado)
    end
    
    return itemRemovido
end

--- Obtém a estrutura de dados de um prédio por seu ID.
--- @param dadosEstado StateData Os dados do estado global.
--- @param idPredio string O ID exclusivo do prédio.
--- @return BuildingData|nil Os dados do prédio correspondente ou nulo.
function LKS_EletricidadeConstrucao.Data.State.GetBuilding(dadosEstado, idPredio)
    return dadosEstado.buildings[idPredio]
end

--- Obtém todos os prédios vinculados ao estado.
--- @param dadosEstado StateData Os dados do estado global.
--- @return table Mapa de IDs para estruturas BuildingData.
function LKS_EletricidadeConstrucao.Data.State.GetAllBuildings(dadosEstado)
    return dadosEstado.buildings
end

-- ============================================================================
-- OPERAÇÕES DE CONSULTA (QUERIES)
-- ============================================================================

--- Obtém todos os prédios conectados a um gerador específico.
--- @param dadosEstado StateData Os dados do estado global.
--- @param idGerador string O ID exclusivo do gerador.
--- @return table Vetor contendo dados das estruturas BuildingData conectadas.
function LKS_EletricidadeConstrucao.Data.State.GetGeneratorBuildings(dadosEstado, idGerador)
    local resultados = {}
    
    for _, dadosPredio in pairs(dadosEstado.buildings) do
        if dadosPredio.generatorId == idGerador then
            table.insert(resultados, dadosPredio)
        end
    end
    
    return resultados
end

--- Obtém todos os geradores registrados em um determinado chunk geográfico.
--- @param dadosEstado StateData Os dados do estado global.
--- @param chunkKey string A chave de chunk identificadora (chunk_X_Y).
--- @return table Vetor contendo as estruturas GeneratorData presentes no chunk.
function LKS_EletricidadeConstrucao.Data.State.GetGeneratorsInChunk(dadosEstado, chunkKey)
    local resultados = {}
    local mapaChunks = dadosEstado.chunkIndex or {}
    local idsGeradores = mapaChunks[chunkKey]

    if not idsGeradores then
        return resultados
    end

    for _, idGerador in ipairs(idsGeradores) do
        local dadosGerador = dadosEstado.generators[idGerador]
        if dadosGerador then
            table.insert(resultados, dadosGerador)
        else
            -- Limpeza lazy de registros órfãos ou desatualizados no índice
            mapaChunks[chunkKey] = mapaChunks[chunkKey] or {}
        end
    end

    return resultados
end

--- Obtém a lista contendo todos os geradores ativamente em funcionamento.
--- @param dadosEstado StateData Os dados do estado global.
--- @return table Vetor contendo os geradores em operação.
function LKS_EletricidadeConstrucao.Data.State.GetActiveGenerators(dadosEstado)
    local resultados = {}
    
    for _, dadosGerador in pairs(dadosEstado.generators) do
        if LKS_EletricidadeConstrucao.Data.Generator.IsRunning(dadosGerador) then
            table.insert(resultados, dadosGerador)
        end
    end
    
    return resultados
end

-- ============================================================================
-- ATUALIZAÇÃO E ESTATÍSTICAS
-- ============================================================================

--- Sincroniza e atualiza estatísticas de runtime globais.
--- @param dadosEstado StateData Os dados do estado global.
function LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(dadosEstado)
    local estatisticas = dadosEstado.statistics
    
    -- Contabiliza geradores
    local totalGeradores = 0
    local geradoresAtivos = 0
    for _, dadosGerador in pairs(dadosEstado.generators) do
        totalGeradores = totalGeradores + 1
        if LKS_EletricidadeConstrucao.Data.Generator.IsRunning(dadosGerador) then
            geradoresAtivos = geradoresAtivos + 1
        end
    end
    estatisticas.totalGenerators = totalGeradores
    estatisticas.activeGenerators = geradoresAtivos
    
    -- Contabiliza prédios e consumidores elétricos ativos
    local totalPredios = 0
    local totalConsumidores = 0
    local consumidoresAtivos = 0
    for _, dadosPredio in pairs(dadosEstado.buildings) do
        totalPredios = totalPredios + 1
        local consumidoresPredio = 0
        if dadosPredio.powerConsumers then
            for _ in pairs(dadosPredio.powerConsumers) do
                consumidoresPredio = consumidoresPredio + 1
            end
        end
        totalConsumidores = totalConsumidores + consumidoresPredio
        consumidoresAtivos = consumidoresAtivos + LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(dadosPredio)
    end
    estatisticas.totalBuildings = totalPredios
    estatisticas.totalConsumers = totalConsumidores
    estatisticas.activeConsumers = consumidoresAtivos
end

--- Registra o consumo de combustível acumulado nas estatísticas globais do mod.
--- @param dadosEstado StateData Os dados do estado global.
--- @param quantidade number Volume de combustível consumido.
function LKS_EletricidadeConstrucao.Data.State.RecordFuelConsumption(dadosEstado, quantidade)
    dadosEstado.statistics.totalFuelConsumed = dadosEstado.statistics.totalFuelConsumed + quantidade
end

--- Atualiza o tempo acumulado de funcionamento contínuo do mod.
--- @param dadosEstado StateData Os dados do estado global.
--- @param segundosDecorridos number A diferença de tempo transcorrida em segundos reais.
function LKS_EletricidadeConstrucao.Data.State.UpdateUptime(dadosEstado, segundosDecorridos)
    dadosEstado.statistics.uptime = dadosEstado.statistics.uptime + segundosDecorridos
end

-- ============================================================================
-- CONTROLE DE SINCRONIZAÇÃO EM MULTIPLAYER (MP)
-- ============================================================================

--- Marca o carimbo de conclusão de uma sincronização completa de dados.
--- @param dadosEstado StateData Os dados do estado global.
function LKS_EletricidadeConstrucao.Data.State.MarkFullSync(dadosEstado)
    dadosEstado.lastFullSync = getTimestampMs()
    dadosEstado.lastDeltaSync = getTimestampMs()
end

--- Marca o carimbo de conclusão de uma sincronização incremental (delta) de dados.
--- @param dadosEstado StateData Os dados do estado global.
function LKS_EletricidadeConstrucao.Data.State.MarkDeltaSync(dadosEstado)
    dadosEstado.lastDeltaSync = getTimestampMs()
end

--- Verifica se é necessário realizar uma sincronização completa baseado no intervalo de tempo.
--- @param dadosEstado StateData Os dados do estado global.
--- @param intervaloMilissegundos number O intervalo configurado.
--- @return boolean Retorna true se a sincronização for requerida.
function LKS_EletricidadeConstrucao.Data.State.NeedsFullSync(dadosEstado, intervaloMilissegundos)
    local tempoAtual = getTimestampMs()
    return (tempoAtual - dadosEstado.lastFullSync) >= intervaloMilissegundos
end

--- Verifica se é necessário realizar uma sincronização incremental baseado no intervalo de tempo.
--- @param dadosEstado StateData Os dados do estado global.
--- @param intervaloMilissegundos number O intervalo configurado.
--- @return boolean Retorna true se a sincronização for requerida.
function LKS_EletricidadeConstrucao.Data.State.NeedsDeltaSync(dadosEstado, intervaloMilissegundos)
    local tempoAtual = getTimestampMs()
    return (tempoAtual - dadosEstado.lastDeltaSync) >= intervaloMilissegundos
end

-- ============================================================================
-- OPERAÇÕES DE LIMPEZA E ZERAMENTO
-- ============================================================================

--- Limpa todos os geradores registrados no estado global.
--- @param dadosEstado StateData Os dados do estado global.
function LKS_EletricidadeConstrucao.Data.State.ClearGenerators(dadosEstado)
    dadosEstado.generators = {}
    dadosEstado.chunkIndex = {}
    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(dadosEstado)
end

--- Limpa todos os prédios registrados no estado global.
--- @param dadosEstado StateData Os dados do estado global.
function LKS_EletricidadeConstrucao.Data.State.ClearBuildings(dadosEstado)
    dadosEstado.buildings = {}
    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(dadosEstado)
end

--- Zera por completo todos os dados operacionais e estatísticas registradas no mod.
--- @param dadosEstado StateData Os dados do estado global.
function LKS_EletricidadeConstrucao.Data.State.ClearAll(dadosEstado)
    dadosEstado.generators = {}
    dadosEstado.buildings = {}
    dadosEstado.chunkIndex = {}
    dadosEstado.statistics.totalFuelConsumed = 0
    dadosEstado.statistics.uptime = 0
    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(dadosEstado)
end

-- ============================================================================
-- DEPURAÇÃO
-- ============================================================================

--- Obtém a string de resumo com dados estatísticos estruturados do estado do mod.
--- @param dadosEstado StateData|nil Os dados do estado global analisado.
--- @return string A string de resumo correspondente.
function LKS_EletricidadeConstrucao.Data.State.GetSummary(dadosEstado)
    if not dadosEstado then
        return "Estado: Inativo (Não carregado)"
    end
    local estatisticas = dadosEstado.statistics or {}
    return string.format(
        "Estado LKS_EletricidadeConstrucao v%s | Geradores:%d(%d ativos) Prédios:%d Consumidores:%d(%d ativos) Combustível:%.1f Funcionamento:%.1fh",
        dadosEstado.version or "unknown",
        estatisticas.totalGenerators or 0,
        estatisticas.activeGenerators or 0,
        estatisticas.totalBuildings or 0,
        estatisticas.totalConsumers or 0,
        estatisticas.activeConsumers or 0,
        estatisticas.totalFuelConsumed or 0,
        (estatisticas.uptime or 0) / 3600
    )
end

-- ============================================================================
-- INICIALIZAÇÃO E REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Data.State", "2.0.0")

return LKS_EletricidadeConstrucao.Data.State
