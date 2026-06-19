-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Fuel_StrainCalculator.lua
-- LKS_EletricidadeConstrucao V2 - Calculadora de Sobrecarga
-- Calcula modificadores de consumo de combustível baseados na carga
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace existe
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Fuel_StrainCalculator] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- ============================================================================
-- CÁLCULO DE SOBRECARGA
-- ============================================================================

-- Os modificadores de tipo de gerador residem nos constantes compartilhados para manter combustível + sobrecarga alinhados.
local MODIFICADORES_TIPO_GERADOR =
    (LKS_EletricidadeConstrucao.Constants.GENERATOR_TYPES and LKS_EletricidadeConstrucao.Constants.GENERATOR_TYPES.MODIFIERS) or {}

-- Rastreia por quanto tempo (em segundos de jogo) cada gerador esteve em sobrecarga (>100% de carga)
-- Redefinido quando a sobrecarga cai para <= 100%
local _duracaoSobrecarga = {} -- [idGerador] = segundosAcumulados

-- 1 hora de sobrecarga em jogo deve passar antes que a chance de falha seja ativada
local SEGUNDOS_CARENCIA_SOBRECARGA = 3600 -- 1 hora (tempo do jogo)

-- Auxiliar: obter nome do sprite do gerador
local function obterNomeSpriteGerador(gerador)
    if not gerador then return nil end
    local nomeSprite = gerador.getSpriteName and gerador:getSpriteName()
    if not nomeSprite and gerador.getSprite and gerador:getSprite() then
        nomeSprite = gerador:getSprite():getName()
    end
    return nomeSprite
end

-- Auxiliar: diminui um bônus/malus em direção a 1.0 conforme mais geradores do mesmo tipo estão presentes
local function aplicarRetornosDecrescentes(multiplicador, quantidade)
    if not multiplicador then return 1.0 end
    if multiplicador == 1.0 or not quantidade or quantidade <= 1 then return multiplicador end
    return 1.0 + ((multiplicador - 1.0) / (2 ^ (quantidade - 1)))
end

-- Auxiliar: conta geradores com o mesmo sprite conectados no mesmo pool de prédios
local function contarGeradoresMesmoSprite(objetoGerador, dadosGerador)
    local nomeSprite = obterNomeSpriteGerador(objetoGerador)
    if not nomeSprite then return 1 end

    local visitados = {}
    local contagem = 0

    local function adicionarSeIgual(gerador)
        if not gerador then return end
        local chave = string.format("%d,%d,%d", gerador:getX(), gerador:getY(), gerador:getZ())
        if visitados[chave] then return end
        visitados[chave] = true
        if obterNomeSpriteGerador(gerador) == nomeSprite then
            contagem = contagem + 1
        end
    end

    adicionarSeIgual(objetoGerador)

    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
    local celula = getCell()
    if celula and dadosGerador and dadosGerador.connectedBuildings and gerenciadorEstado and gerenciadorEstado.GetBuilding then
        -- connectedBuildings / connectedGenerators são desserializados pelo Kahlua (chaves numéricas string)
        for _, idPredio in pairs(dadosGerador.connectedBuildings) do
            local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
            if dadosPredio and dadosPredio.connectedGenerators then
                for _, chaveGerador in pairs(dadosPredio.connectedGenerators) do
                    local coordX, coordY, coordZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                    if coordX then
                        local quadrado = celula:getGridSquare(tonumber(coordX), tonumber(coordY), tonumber(coordZ))
                        if quadrado then
                            local objetos = quadrado:getObjects()
                            for indice = 0, objetos:size() - 1 do
                                local objeto = objetos:get(indice)
                                if objeto and instanceof(objeto, "IsoGenerator") then
                                    adicionarSeIgual(objeto)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if contagem < 1 then return 1 end
    return contagem
end

-- Auxiliar: conta geradores ativos a partir de uma lista de prédios do pool
local function contarGeradoresPoolAtivosDosPredios(prediosPool)
    if type(prediosPool) ~= "table" then
        return 1
    end

    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local dadosClasseGerador = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
    if not gerenciadorEstado or not gerenciadorEstado.GetBuilding or not gerenciadorEstado.GetGenerator
            or not dadosClasseGerador or not dadosClasseGerador.MakeId then
        return 1
    end

    local chavesGeradoresVistas = {}
    local contagemAtivos = 0

    for idPredio in pairs(prediosPool) do
        local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
        if dadosPredio and dadosPredio.connectedGenerators then
            for _, chaveGerador in pairs(dadosPredio.connectedGenerators) do
                if not chavesGeradoresVistas[chaveGerador] then
                    chavesGeradoresVistas[chaveGerador] = true
                    local coordX, coordY, coordZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                    if coordX then
                        local idGerador = dadosClasseGerador.MakeId(tonumber(coordX), tonumber(coordY), tonumber(coordZ))
                        local dadosGerador = gerenciadorEstado.GetGenerator(idGerador)
                        if dadosGerador and (dadosGerador.fuelAmount or 0) > 0 and dadosGerador.activated ~= false then
                            contagemAtivos = contagemAtivos + 1
                        end
                    end
                end
            end
        end
    end

    if contagemAtivos < 1 then return 1 end
    return contagemAtivos
end

-- Auxiliar: resolve a contagem de geradores ativos do pool
local function resolverQuantidadePoolAtivo(dadosGerador, prediosPoolSobrescrito, ativosPoolSobrescrito)
    if type(ativosPoolSobrescrito) == "number" and ativosPoolSobrescrito >= 1 then
        return math.max(1, math.floor(ativosPoolSobrescrito + 0.5))
    end

    local tempoExecucao = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    if type(prediosPoolSobrescrito) == "table"
            and tempoExecucao and tempoExecucao.IsSingleplayer and tempoExecucao.IsSingleplayer() then
        return contarGeradoresPoolAtivosDosPredios(prediosPoolSobrescrito)
    end

    local ativosPoolGens = 1
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager
       and LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators then
        ativosPoolGens = LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators(dadosGerador)
    end

    if ativosPoolGens < 1 and type(prediosPoolSobrescrito) == "table" then
        ativosPoolGens = contarGeradoresPoolAtivosDosPredios(prediosPoolSobrescrito)
    end

    if ativosPoolGens < 1 then return 1 end
    return ativosPoolGens
end

--- Calcula o multiplicador de sobrecarga para o gerador (sistema em níveis)
--- @param generatorData GeneratorData Dados do gerador
--- @param poolBuildingsOverride table|nil Lista pré-calculada de IDs de prédios vindos do BFS do FuelManager.
--- @param activePoolOverride number|nil Contagem pré-calculada de geradores ativos do pool.
--- @return number Multiplicador de sobrecarga (1.0 = normal, >1.0 = consumo aumentado)
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData, poolBuildingsOverride, activePoolOverride)
    if not generatorData then
        return 1.0
    end

    -- Atualiza o valor de sobrecarga nos dados do gerador
    LKS_EletricidadeConstrucao.Fuel.StrainCalculator.CalculateStrain(generatorData, poolBuildingsOverride, activePoolOverride)
    
    local sobrecarga = generatorData.strain
    
    -- Sem sobrecarga = sem modificador
    if sobrecarga <= 0 then
        return 1.0
    end
    
    -- SISTEMA DE SOBRECARGA EM NÍVEIS:
    -- 0-50%: Sem consumo extra de combustível (1.0x)
    -- 51-75%: Aumento linear de 1.0x a 1.25x (1-25% extra)
    -- 76-100%: Aumento linear de 1.26x a 1.75x (26-75% extra) + danos
    -- 101-200%: Aumento linear até 3.0x + danos pesados + chance de falha
    
    local multiplicador = 1.0
    
    if sobrecarga <= 50 then
        multiplicador = 1.0
        print(string.format("[STRAIN_DEBUG] Sobrecarga %.1f%% <= 50%% -> multiplicador = 1.0 (sem penalidade)", sobrecarga))
    elseif sobrecarga <= 75 then
        local interpolacao = (sobrecarga - 50) / 25 -- 0.0 em 50%, 1.0 em 75%
        multiplicador = 1.0 + (interpolacao * 0.25)
        print(string.format("[STRAIN_DEBUG] Sobrecarga %.1f%% no intervalo 51-75%% -> interpolacao=%.3f, multiplicador = %.3f", sobrecarga, interpolacao, multiplicador))
    elseif sobrecarga <= 100 then
        local interpolacao = (sobrecarga - 75) / 25 -- 0.0 em 75%, 1.0 em 100%
        multiplicador = 1.26 + (interpolacao * 0.49)
        print(string.format("[STRAIN_DEBUG] Sobrecarga %.1f%% no intervalo 76-100%% -> interpolacao=%.3f, multiplicador = %.3f", sobrecarga, interpolacao, multiplicador))
    else
        local interpolacao = math.min((sobrecarga - 100) / 100, 1.0) -- 0.0 em 100%, 1.0 em 200%
        multiplicador = 1.75 + (interpolacao * 1.25)
        print(string.format("[STRAIN_DEBUG] Sobrecarga %.1f%% > 100%% -> interpolacao=%.3f, multiplicador = %.3f", sobrecarga, interpolacao, multiplicador))
    end
    
    -- Limita ao máximo (padrão 3.0x)
    local Constantes = LKS_EletricidadeConstrucao.Constants
    local multiplicadorMaximo = Constantes.FUEL.MAX_STRAIN_MULTIPLIER or 3.0
    if multiplicador > multiplicadorMaximo then
        multiplicador = multiplicadorMaximo
    end
    
    return multiplicador
end

--- Calcula a sobrecarga atual do gerador
--- @param generatorData GeneratorData Dados do gerador
--- @param poolBuildingsOverride table|nil Lista pré-calculada de prédios do pool.
--- @param activePoolOverride number|nil Contagem pré-calculada de geradores ativos para este pool.
--- @return number Porcentagem de sobrecarga (0-100+)
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.CalculateStrain(generatorData, poolBuildingsOverride, activePoolOverride)
    if not generatorData then
        return 0
    end

    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager

    -- Coleta TODOS os prédios alcançáveis através do pool de geradores.
    -- Se o FuelManager já tiver feito essa busca BFS, reutiliza o resultado.
    local prediosPool
    if poolBuildingsOverride then
        prediosPool = poolBuildingsOverride
    else
        prediosPool = {}
        do
            local aVisitar = {generatorData}
            local visitados = {}
            while #aVisitar > 0 do
                local geradorC = table.remove(aVisitar)
                if geradorC and geradorC.id and not visitados[geradorC.id] then
                    visitados[geradorC.id] = true
                    if geradorC.connectedBuildings then
                        for _, idPredio in pairs(geradorC.connectedBuildings) do
                            prediosPool[idPredio] = true
                            local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
                            if dadosPredio and dadosPredio.connectedGenerators then
                                for _, chaveGerador in pairs(dadosPredio.connectedGenerators) do
                                    local coordX, coordY, coordZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                                    if coordX then
                                        local idGerador2 = LKS_EletricidadeConstrucao.Data.Generator.MakeId(tonumber(coordX), tonumber(coordY), tonumber(coordZ))
                                        if not visitados[idGerador2] then
                                            local proximoGen = gerenciadorEstado.GetGenerator(idGerador2)
                                            if proximoGen then table.insert(aVisitar, proximoGen) end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Conta geradores ativos no pool de forma independente de chunk
    local ativosPoolGens = resolverQuantidadePoolAtivo(generatorData, poolBuildingsOverride, activePoolOverride)

    -- Soma a carga de energia total de todos os prédios do pool
    local cargaTotalPool = 0
    local _localizacoesVistasSobrecarga = {}
    for idPredio, _ in pairs(prediosPool) do
        local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
        if dadosPredio then
            local chaveLocalizacao = (dadosPredio.x or 0) .. "_" .. (dadosPredio.y or 0) .. "_" .. (dadosPredio.z or 0)
            if not _localizacoesVistasSobrecarga[chaveLocalizacao] then
                _localizacoesVistasSobrecarga[chaveLocalizacao] = true
                local carga = dadosPredio.strainTotalPowerDraw
                           or dadosPredio.totalPowerDraw
                           or 0
                cargaTotalPool = cargaTotalPool + carga
            end
        end
    end
    local cargaCompartilhada = cargaTotalPool / ativosPoolGens

    if cargaCompartilhada <= 0 then
        generatorData.strain = 0
        return 0
    end

    -- Converte a carga compartilhada para porcentagem de sobrecarga
    local sobrecarga = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PowerDrawToStrain(cargaCompartilhada)

    -- Aplica capacidade de sobrecarga específica por tipo (menor = tolera mais carga)
    local objetoGerador = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    local multSobrecarga = 1.0
    
    if objetoGerador then
        local sprite = obterNomeSpriteGerador(objetoGerador)
        generatorData.cachedSprite = sprite
        
        local modificadores = MODIFICADORES_TIPO_GERADOR[sprite or ""]
        if modificadores and modificadores.strain then
            multSobrecarga = modificadores.strain
        end
        generatorData.cachedStrainMult = multSobrecarga
        
        -- Diminui o bônus/malus ao agrupar múltiplos do mesmo sprite
        local quantidadeMesmo = contarGeradoresMesmoSprite(objetoGerador, generatorData)
        multSobrecarga = aplicarRetornosDecrescentes(multSobrecarga, quantidadeMesmo)
    else
        multSobrecarga = generatorData.cachedStrainMult or 1.0
    end

    sobrecarga = sobrecarga * multSobrecarga

    -- Ignora ruídos ínfimos abaixo de 0.5%
    if sobrecarga < 0.5 then
        sobrecarga = 0
    end
    
    -- Atualiza os dados do gerador
    generatorData.strain = sobrecarga
    
    return sobrecarga
end

--- Converte carga elétrica para porcentagem de sobrecarga
--- @param powerDraw number Carga elétrica total
--- @return number Porcentagem de sobrecarga
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PowerDrawToStrain(powerDraw)
    if powerDraw <= 0 then
        return 0
    end
    
    local Constantes = LKS_EletricidadeConstrucao.Constants
    local constantesCombustivel = Constantes.FUEL or {}
    local capacidadeCargaBase = constantesCombustivel.BASE_LOAD_CAPACITY

    if type(capacidadeCargaBase) ~= "number" or capacidadeCargaBase <= 0 then
        local sobrecargaBaseLegada = constantesCombustivel.BASE_STRAIN_PER_LIGHT or 1.0
        if type(sobrecargaBaseLegada) == "number" and sobrecargaBaseLegada > 0 then
            capacidadeCargaBase = 100 / sobrecargaBaseLegada
        else
            capacidadeCargaBase = 100.0
        end
    end

    local sobrecarga = (powerDraw / capacidadeCargaBase) * 100
    
    return sobrecarga
end

--- Obtém a categoria do nível de sobrecarga
--- @param strain number Porcentagem de sobrecarga
--- @return string Nível de sobrecarga ("none", "low", "medium", "high", "critical")
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainLevel(strain)
    local Constantes = LKS_EletricidadeConstrucao.Constants
    
    if strain <= 0 then
        return "none"
    elseif strain < (Constantes.FUEL.STRAIN_THRESHOLD_LOW or 25) then
        return "low"
    elseif strain < (Constantes.FUEL.STRAIN_THRESHOLD_MEDIUM or 50) then
        return "medium"
    elseif strain < (Constantes.FUEL.STRAIN_THRESHOLD_HIGH or 75) then
        return "high"
    else
        return "critical"
    end
end

--- Verifica se o gerador está em sobrecarga
--- @param generatorData GeneratorData Dados do gerador
--- @return boolean True se estiver em sobrecarga
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.IsOverloaded(generatorData)
    if not generatorData then
        return false
    end
    
    local Constantes = LKS_EletricidadeConstrucao.Constants
    local limiteSobrecarga = Constantes.FUEL.OVERLOAD_THRESHOLD or 100
    
    return generatorData.strain >= limiteSobrecarga
end

-- ============================================================================
-- EFEITOS DA SOBRECARGA
-- ============================================================================

--- Obtém a porcentagem de eficiência com base na sobrecarga
--- @param strain number Porcentagem de sobrecarga
--- @return number Porcentagem de eficiência (100 = normal, <100 = eficiência reduzida)
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetEfficiency(strain)
    if strain <= 0 then
        return 100
    end
    
    local Constantes = LKS_EletricidadeConstrucao.Constants
    
    -- A eficiência diminui linearmente com a sobrecarga
    local perdaEficiencia = strain * (Constantes.FUEL.EFFICIENCY_LOSS_RATE or 0.5)
    local eficiencia = 100 - perdaEficiencia
    
    -- Eficiência mínima permitida
    local eficienciaMinima = Constantes.FUEL.MIN_EFFICIENCY or 25
    if eficiencia < eficienciaMinima then
        eficiencia = eficienciaMinima
    end
    
    return eficiencia
end

--- Verifica se o gerador deve falhar devido à sobrecarga
--- @param generatorData GeneratorData Dados do gerador
--- @return boolean True se deve falhar
--- @return string|nil Motivo da falha
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ShouldFailFromOverload(generatorData)
    if not generatorData then
        return false, nil
    end
    
    local Config = LKS_EletricidadeConstrucao.Config
    
    -- Verifica se a falha por sobrecarga está ativada
    if not Config.OverloadFailureEnabled then
        return false, nil
    end
    
    -- Verifica se está em sobrecarga crítica
    if not LKS_EletricidadeConstrucao.Fuel.StrainCalculator.IsOverloaded(generatorData) then
        return false, nil
    end
    
    local Constantes = LKS_EletricidadeConstrucao.Constants
    
    -- Chance randômica de falha baseada no nível de sobrecarga
    local chanceFalha = (generatorData.strain - 100) * (Constantes.FUEL.OVERLOAD_FAILURE_RATE or 0.01)
    
    if chanceFalha > 0 then
        local jogadaDados = ZombRand(10000) / 100 -- 0-100 com precisão de 2 decimais
        
        if jogadaDados < chanceFalha then
            return true, "Falha por sobrecarga"
        end
    end
    
    return false, nil
end

-- ============================================================================
-- ANÁLISE DE PRÉDIO
-- ============================================================================

--- Calcula a carga elétrica total para o gerador
--- @param generatorData GeneratorData Dados do gerador
--- @return number Carga elétrica total
--- @return number Quantidade de consumidores ativos
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetTotalPowerDraw(generatorData)
    if not generatorData then
        return 0, 0
    end
    
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
    local cargaTotal = 0
    local consumidoresAtivos = 0
    
    -- connectedBuildings é desserializado pelo Kahlua (chaves numéricas string); use pairs
    for _, idPredio in pairs(generatorData.connectedBuildings) do
        local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
        
        if dadosPredio then
            local carga = dadosPredio.strainTotalPowerDraw or dadosPredio.totalPowerDraw or 0
            cargaTotal = cargaTotal + carga
            consumidoresAtivos = consumidoresAtivos + LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(dadosPredio)
        end
    end
    
    return cargaTotal, consumidoresAtivos
end

--- Obtém o detalhamento do consumo de energia por prédio conectado
--- @param generatorData GeneratorData Dados do gerador
--- @return table Array contendo tabelas {buildingId, powerDraw, consumers}
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetPowerBreakdown(generatorData)
    if not generatorData then
        return {}
    end
    
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
    local detalhamento = {}
    
    -- connectedBuildings é desserializado pelo Kahlua (chaves numéricas string); use pairs
    for _, idPredio in pairs(generatorData.connectedBuildings) do
        local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
        
        if dadosPredio then
            table.insert(detalhamento, {
                buildingId = idPredio,
                powerDraw = dadosPredio.strainTotalPowerDraw or dadosPredio.totalPowerDraw or 0,
                consumers = LKS_EletricidadeConstrucao.Data.Building.GetActiveConsumerCount(dadosPredio),
                totalConsumers = LKS_EletricidadeConstrucao.Data.Building.GetTotalConsumerCount(dadosPredio)
            })
        end
    end
    
    -- Ordena por carga elétrica (maior primeiro)
    table.sort(detalhamento, function(elementoA, elementoB)
        return elementoA.powerDraw > elementoB.powerDraw
    end)
    
    return detalhamento
end

-- ============================================================================
-- SUGESTÕES DE OTIMIZAÇÃO
-- ============================================================================

--- Obtém sugestões de otimização para o gerador
--- @param generatorData GeneratorData Dados do gerador
--- @return table Array contendo strings com sugestões
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetOptimizationSuggestions(generatorData)
    if not generatorData then
        return {}
    end
    
    local sugestoes = {}
    local sobrecarga = generatorData.strain
    local nivelSobrecarga = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainLevel(sobrecarga)
    
    if nivelSobrecarga == "critical" then
        table.insert(sugestoes, "CRITICO: O gerador esta severamente sobrecarregado!")
        table.insert(sugestoes, "Considere adicionar mais geradores ou reduzir o consumo de energia")
    elseif nivelSobrecarga == "high" then
        table.insert(sugestoes, "O gerador esta muito carregado - o consumo de combustivel aumentou em " .. 
            string.format("%.0f%%", (LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData) - 1.0) * 100))
        table.insert(sugestoes, "Desligue luzes desnecessarias para reduzir a carga")
    elseif nivelSobrecarga == "medium" then
        table.insert(sugestoes, "A carga do gerador esta moderada")
    elseif nivelSobrecarga == "low" then
        table.insert(sugestoes, "A carga do gerador esta leve - operando com eficiencia")
    else
        table.insert(sugestoes, "O gerador esta ocioso - sem consumo de energia")
    end
    
    -- Adiciona sugestões específicas de combustível
    if LKS_EletricidadeConstrucao.Data.Generator.NeedsRefuel(generatorData, 20) then
        table.insert(sugestoes, "Nivel de combustivel baixo - reabastecer em breve")
    end
    
    return sugestoes
end

-- ============================================================================
-- DEPURAR / DEBUG
-- ============================================================================

--- Exibe informações da sobrecarga do gerador no console
--- @param generatorData GeneratorData Dados do gerador
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PrintGeneratorStrain(generatorData)
    if not generatorData then
        LKS_EletricidadeConstrucao.Print("Nenhum dado de gerador fornecido")
        return
    end
    
    local cargaEletrica, consumidores = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetTotalPowerDraw(generatorData)
    local sobrecarga = generatorData.strain
    local multiplicador = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData)
    local eficiencia = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetEfficiency(sobrecarga)
    local nivelSobrecarga = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainLevel(sobrecarga)
    
    LKS_EletricidadeConstrucao.Print("=== Sobrecarga do Gerador: " .. generatorData.id .. " ===")
    LKS_EletricidadeConstrucao.Print("Carga Eletrica: " .. cargaEletrica)
    LKS_EletricidadeConstrucao.Print("Consumidores Ativos: " .. consumidores)
    LKS_EletricidadeConstrucao.Print("Sobrecarga: " .. string.format("%.1f%%", sobrecarga) .. " (" .. nivelSobrecarga .. ")")
    LKS_EletricidadeConstrucao.Print("Multiplicador de Combustivel: " .. string.format("%.2fx", multiplicador))
    LKS_EletricidadeConstrucao.Print("Eficiencia: " .. string.format("%.0f%%", eficiencia))
    local totalPredios = 0
    if generatorData.connectedBuildings then
        for _ in pairs(generatorData.connectedBuildings) do totalPredios = totalPredios + 1 end
    end
    LKS_EletricidadeConstrucao.Print("Predios Conectados: " .. totalPredios)
    
    -- Exibe detalhamento
    local detalhamento = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetPowerBreakdown(generatorData)
    if #detalhamento > 0 then
        LKS_EletricidadeConstrucao.Print("Detalhamento de Carga:")
        for indice, entrada in ipairs(detalhamento) do
            LKS_EletricidadeConstrucao.Print(string.format("  %d. %s: %.1f energia, %d/%d consumidores ativos",
                indice, entrada.buildingId, entrada.powerDraw, entrada.consumers, entrada.totalConsumers))
        end
    end
    
    -- Exibe sugestões
    local sugestoes = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetOptimizationSuggestions(generatorData)
    if #sugestoes > 0 then
        LKS_EletricidadeConstrucao.Print("Sugestoes:")
        for _, sugestao in ipairs(sugestoes) do
            LKS_EletricidadeConstrucao.Print("  - " .. sugestao)
        end
    end
end

-- ============================================================================
-- SISTEMA DE DANOS POR SOBRECARGA
-- ============================================================================

--- Aplica danos de sobrecarga ao gerador
--- Chamado a cada tick de consumo de combustível
--- @param generatorData GeneratorData Dados do gerador
--- @param deltaSeconds number Variação de tempo desde o último cálculo
--- @return boolean True se o gerador falhou catastroficamente (foi desligado)
function LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage(generatorData, deltaSeconds)
    if not generatorData or not generatorData.strain or generatorData.strain <= 100 then
        -- Redefine o temporizador de sobrecarga se a carga estiver abaixo de 100% (sem danos abaixo de 100%)
        if generatorData and generatorData.id then
            _duracaoSobrecarga[generatorData.id] = nil
        end
        return false -- Sem danos abaixo do limite de 100% de sobrecarga
    end
    
    local objetoGerador = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    if not objetoGerador then
        return false
    end
    
    local sobrecarga = generatorData.strain
    local multiplicadorDano = 0
    local chanceFalha = 0
    
    -- NÍVEIS DE DANOS:
    -- 0-100%:   Sem danos à integridade (apenas multiplicador de consumo se aplica)
    -- 101-200% (com carência ativa, < 1 hora): 1x dano vanilla, sem chance de falha catastrófica
    -- 101-200% (carência expirada):            1x a 5x dano vanilla + chance de falha catastrófica
    
    -- Acumula tempo de sobrecarga; dano AND chance de falha apenas após o período de carência.
    -- Limita o incremento para evitar expiração instantânea da carência durante compensações longas.
    local decorridoAtual = _duracaoSobrecarga[generatorData.id] or 0
    local incrementoLimitado = math.min(deltaSeconds, 600) -- Máximo de 10 minutos por tick
    local decorrido = decorridoAtual + incrementoLimitado
    _duracaoSobrecarga[generatorData.id] = decorrido

    -- 101-200%: Linear de 1x a 5x dano
    local interpolacao = math.min((sobrecarga - 100) / 100, 1.0) -- 0.0 em 100%, 1.0 em 200%

    if decorrido >= SEGUNDOS_CARENCIA_SOBRECARGA then
        -- Carência expirada: dano escalado (1x-5x) + chance de falha catastrófica
        multiplicadorDano = 1.0 + (interpolacao * 4.0)

        -- Chance de falha aumenta de 0% em 101% para 10% por minuto em 200% de carga
        -- Limita a chance por tick para evitar desligamentos instantâneos pós-compensações.
        local chanceFalhaPorMinuto = interpolacao * 0.10 -- 0% em 101%, 10% em 200%
        local chanceFalhaSemLimite = chanceFalhaPorMinuto * (deltaSeconds / 60)
        chanceFalha = math.min(chanceFalhaSemLimite, interpolacao * 0.05) -- Máximo de 5% por tick em 200%
    else
        -- Período de carência ativo: danos mínimos equivalentes ao vanilla (1x), sem chance de falha
        multiplicadorDano = 1.0
    end
    
    -- Perda de integridade base por hora de jogo sob sobrecarga.
    -- Taxa independente do multiplicador de tempo da sandbox.
    -- Em 1x (101% sobrecarga, carência expirada): 0.02 de dano por hora de jogo → quebra em ~5000 horas de jogo.
    -- Em 5x (200% sobrecarga, carência expirada): 0.10 de dano por hora de jogo → quebra em ~1000 horas de jogo.
    local danoVanillaPorHora = 0.02
    local danoSobrecargaPorHora = danoVanillaPorHora * multiplicadorDano
    local dano = danoSobrecargaPorHora * (deltaSeconds / 3600)
    
    -- Aplica o dano à integridade do gerador
    local condicaoAtual = objetoGerador:getCondition()
    local novaCondicao = math.max(0, condicaoAtual - dano)
    objetoGerador:setCondition(novaCondicao)
    
    -- Registra danos significativos no log
    if dano > 0.001 then
        local infoCarencia = ""
        if decorrido < SEGUNDOS_CARENCIA_SOBRECARGA then
            infoCarencia = string.format(" [carencia: %.0f/3600s]", decorrido)
        else
            infoCarencia = " [carencia: EXPIRADA]"
        end
        LKS_EletricidadeConstrucao.Print(string.format(
            "[StrainDamage] gen=%s sobrecarga=%.1f%% dano=%.4f (%.1fx) integridade: %.1f -> %.1f%s",
            generatorData.id, sobrecarga, dano, multiplicadorDano, condicaoAtual, novaCondicao, infoCarencia))
    end
    
    -- Verifica por falha catastrófica sob sobrecarga extrema
    if chanceFalha > 0 then
        local rolarDados = ZombRand(10000) / 10000 -- 0.0000 a 0.9999
        if rolarDados < chanceFalha then
            LKS_EletricidadeConstrucao.Print(string.format(
                "[StrainFailure] gen=%s FALHOU devido a sobrecarga extrema (%.1f%%)! Gerador desligado.",
                generatorData.id, sobrecarga))
            return true
        end
    end
    
    -- Se a integridade chegar a 0, o gerador quebra definitivamente
    if novaCondicao <= 0 then
        LKS_EletricidadeConstrucao.Print(string.format(
            "[StrainFailure] gen=%s QUEBROU devido a danos de sobrecarga! Condicao: 0",
            generatorData.id))
        return true
    end
    
    return false
end

-- ============================================================================
-- REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Fuel.StrainCalculator", "2.0.0")

return LKS_EletricidadeConstrucao.Fuel.StrainCalculator
