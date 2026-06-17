-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- Notes:
--   - Executa no Events.EveryOneMinute (via LKS_EletricidadeConstrucao_ServerInit.lua).
--   - Barrels.UpdateAll() executa ANTES do consumo de combustível (abastece primeiro, depois calcula consumo).
--   - O combustível é autoridade no IsoObject (gerador:getFuel()/setFuel()). O fuelAmount no estado é um cache.
--   - Cada gerador rastreia Gen_LastCalcWorldAge no moddata de seu IsoObject.
--     No tick: a variação do worldAge por gerador gera o deltaSeconds (recuperação de atraso inclusa).
--   - Sem consumo fora de chunk: geradores apenas consomem combustível quando seus chunks estão carregados.
--   - Retornos decrescentes por sprite idêntico; multiplicadores de sobrecarga via StrainCalculator.

-- Garante que o namespace existe
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Fuel_Manager] Namespace LKS_EletricidadeConstrucao não encontrado - pulando carregamento do módulo")
    return
end

-- ============================================================================
-- ESTADO LOCAL
-- ============================================================================

local _intervaloAtualizacao = 1000  -- Atualiza a cada segundo (em ms)
local _ultimosMinutosMundo = 0     -- Último minuto de jogo processado (para estatísticas/uptime)
local _idadeMundoAtual = 0         -- Idade do mundo em horas no início do tick de Update() atual
local _inicializado = false
local _eventoRegistrado = false
local _ultimoLogIgnorado = 0
local _restauracoesPoolVistas = {}   -- idGerador -> true uma vez que o pool é reparado
local _avisosGeradoresAusentes = {}  -- idGerador -> quantidade

-- B-102: Cache de cálculo de pool por tick.
-- Limpo no início de cada loop de geradores do Update() para que cada pool seja computado uma vez por tick.
-- _cachePoolPorTick : [idGeradorPrimario] → {totalPoolRate, poolActive}
-- _geradorParaPoolPorTick : [idGerador]        → idGeradorPrimario (qual entrada do cache cobre o pool deste gerador)
local _cachePoolPorTick = {}
local _geradorParaPoolPorTick = {}

-- Os ajustes de variação de geradores residem nos constantes compartilhados para que combustível + sobrecarga fiquem alinhados.
local MODIFICADORES_TIPO_GERADOR =
    (LKS_EletricidadeConstrucao.Constants.GENERATOR_TYPES and LKS_EletricidadeConstrucao.Constants.GENERATOR_TYPES.MODIFIERS) or {}

-- Auxiliar: obter nome do sprite do gerador
local function obterNomeSpriteGerador(gerador)
    if not gerador then return nil end
    local nomeSprite = gerador.getSpriteName and gerador:getSpriteName()
    if not nomeSprite and gerador.getSprite and gerador:getSprite() then
        nomeSprite = gerador:getSprite():getName()
    end
    return nomeSprite
end

-- Auxiliar: minutos do mundo decorridos (tempo de jogo, independente da velocidade do tempo real)
local function obterMinutosMundo()
    local tempoJogo = getGameTime and getGameTime()
    if tempoJogo then
        local horasMundo = tempoJogo:getWorldAgeHours() or 0
        -- worldAgeHours já inclui minutos fracionários, então multiplica uma vez
        return horasMundo * 60
    end
    return getTimestampMs() / 60000  -- fallback para tempo real se GameTime não estiver disponível
end

-- Auxiliar: diminui um bônus/malus em direção a 1.0 conforme mais geradores do mesmo tipo estão presentes
local function aplicarRetornosDecrescentes(multiplicador, quantidade)
    if not multiplicador then return 1.0 end
    if multiplicador == 1.0 or not quantidade or quantidade <= 1 then return multiplicador end
    return 1.0 + ((multiplicador - 1.0) / (2 ^ (quantidade - 1)))
end

local function encontrarIdPoolRestauravel(gerenciadorEstado, dadosGerador)
    if not gerenciadorEstado or not dadosGerador or not dadosGerador.connectedBuildings then
        return nil
    end

    local chaveGerador = string.format("%d_%d_%d", dadosGerador.x or 0, dadosGerador.y or 0, dadosGerador.z or 0)

    for _, idPredio in pairs(dadosGerador.connectedBuildings) do
        local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
        if dadosPredio and dadosPredio.connectedGenerators then
            for _, chaveGeradorVinculado in pairs(dadosPredio.connectedGenerators) do
                if chaveGeradorVinculado == chaveGerador then
                    return idPredio
                end
            end
        end
    end

    return nil
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

-- Auxiliar: conta geradores ativos no(s) mesmo(s) pool(s) para que o combustível seja compartilhado
-- Tornada pública para uso pelo StrainCalculator (contagem independente de chunk)
function LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators(generatorData)
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not generatorData or not gerenciadorEstado then return 1 end

    -- BFS sobre o pool completo (espelha a descoberta do Passo 1 em CalculateFuelConsumption)
    local contagem = 0
    local visitados = {}
    local aVisitar = {generatorData}

    while #aVisitar > 0 do
        local geradorAtual = table.remove(aVisitar)
        if geradorAtual and geradorAtual.id and not visitados[geradorAtual.id] then
            visitados[geradorAtual.id] = true

            -- Usa GlobalModData em vez do IsoGenerator ativo para tornar isso independente de chunk
            -- Um gerador é considerado ativo se tiver combustível E não estiver explicitamente desativado
            -- (o campo activated é apenas definido como false quando o combustível acaba, nunca definido como true)
            local possuiCombustivel = (geradorAtual.fuelAmount or 0) > 0
            local naoDesativado = (geradorAtual.activated ~= false)  -- true se nil ou true
            
            if possuiCombustivel and naoDesativado then
                contagem = contagem + 1
            end

            -- Descobre vizinhos através de TODOS os prédios conectados (não apenas geradores ativos)
            if geradorAtual.connectedBuildings then
                -- connectedBuildings / connectedGenerators são desserializados pelo Kahlua (chaves numéricas string)
                for indice, idPredio in pairs(geradorAtual.connectedBuildings) do
                    local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
                    -- Lazy Xref: repara IDs obsoletos bld_def_... in-place (veja CalculateFuelConsumption)
                    if not dadosPredio then
                        local chaveGeradorLocal = string.format("%d_%d_%d",
                            geradorAtual.x, geradorAtual.y, geradorAtual.z)
                        local todosPredios = gerenciadorEstado.GetAllBuildings() or {}
                        for _, predio in pairs(todosPredios) do
                            if predio and predio.connectedGenerators then
                                for _, chaveGerador in pairs(predio.connectedGenerators) do
                                    if chaveGerador == chaveGeradorLocal then
                                        geradorAtual.connectedBuildings[indice] = predio.id
                                        gerenciadorEstado.AddGenerator(geradorAtual)
                                        dadosPredio = predio
                                        break
                                    end
                                end
                            end
                            if dadosPredio then break end
                        end
                    end
                    if dadosPredio and dadosPredio.connectedGenerators then
                        for _, chaveGerador in pairs(dadosPredio.connectedGenerators) do
                            local coordX, coordY, coordZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                            if coordX then
                                local idGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(tonumber(coordX), tonumber(coordY), tonumber(coordZ))
                                if not visitados[idGerador] then
                                    local proximoGerador = gerenciadorEstado.GetGenerator(idGerador)
                                    if proximoGerador then
                                        table.insert(aVisitar, proximoGerador)
                                    end
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

-- Referência local para uso interno (após a função ser definida no namespace)
local CountActivePoolGenerators = LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators

-- ============================================================================
-- AUXILIARES DE CONFIGURAÇÃO
-- ============================================================================

--- Retorna o multiplicador de sandbox GeneratorFuelConsumption do vanilla,
--- normalizado para que o padrão vanilla (0.1) seja mapeado para 1.0.
---   sandbox 0.0 → 0.0  (combustível infinito)
---   sandbox 0.1 → 1.0  (normal / sem alteração na taxa base da V2)
---   sandbox 0.5 → 5.0  (5x mais rápido)
---   sandbox 1.0 → 10.0 (10x mais rápido)
function LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier()
    local sucesso, valor = pcall(function()
        return getSandboxOptions():getOptionByName("GeneratorFuelConsumption"):getValue()
    end)
    if sucesso and type(valor) == "number" and valor >= 0 then
        -- Usa o valor do sandbox diretamente (0.1 = padrão vanilla)
        return valor
    end
    print("falha ao obter multiplicador de combustível do sandbox, usando padrão 0.1")
    return 0.1  -- fallback: padrão vanilla
end

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

--- Inicializa o gerenciador de combustível
function LKS_EletricidadeConstrucao.Fuel.Manager.Initialize()
    if _inicializado then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("Gerenciador de Combustível já inicializado", "Fuel")
        return
    end
    
    local Constantes = LKS_EletricidadeConstrucao.Constants
    _intervaloAtualizacao = Constantes.FUEL.UPDATE_INTERVAL or 1000
    _ultimosMinutosMundo = obterMinutosMundo()
    
    _inicializado = true

    -- NOTE: O registro do EveryOneMinute é manipulado em LKS_EletricidadeConstrucao_ServerInit.lua
    -- O registro duplicado aqui poderia causar conflitos ou processamento duplo
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Gerenciador de Combustível inicializado (intervalo: " .. _intervaloAtualizacao .. "ms)", "Fuel")
end

--- Verifica se o gerenciador de combustível está inicializado
--- @return boolean True se estiver inicializado
function LKS_EletricidadeConstrucao.Fuel.Manager.IsInitialized()
    return _inicializado
end

-- ============================================================================
-- CICLO DE ATUALIZAÇÃO
-- ============================================================================

--- Atualiza todos os geradores ativos
--- Chamado periodicamente para processar o consumo de combustível
function LKS_EletricidadeConstrucao.Fuel.Manager.Update()
    if not _inicializado then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("Update do Gerenciador de Combustível chamado antes da inicialização", "Fuel")
        return
    end
    
    local minutosMundoAtuais = obterMinutosMundo()
    -- Captura a idade do mundo (horas) para cálculos de delta por gerador.
    -- Cada gerador compara seu próprio Gen_LastCalcWorldAge contra isto.
    local tempoJogo = getGameTime and getGameTime()
    _idadeMundoAtual = tempoJogo and (tempoJogo:getWorldAgeHours() or 0) or (minutosMundoAtuais / 60)

    -- deltaMinutes ainda é usado apenas para estatísticas de tempo ativo (uptime)
    local variacaoMinutos = minutosMundoAtuais - _ultimosMinutosMundo
    if variacaoMinutos < 0 then variacaoMinutos = 0 end
    local segundosAtivo = variacaoMinutos * 60

    -- Sincroniza sinalizadores de execução dos geradores ativos a partir dos IsoGenerators reais
    -- para que mudanças de ativação/condição sejam refletidas no estado antes de filtrar os ativos.
    -- O combustível permanece autoridade no estado para podermos sobrepor a drenagem vanilla.
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
    local qualquerAlteracaoEstado = false
    for _, dadosGerador in pairs(gerenciadorEstado.GetAllGenerators()) do
        local objetoGerador = getGeneratorFromSquare(dadosGerador.x, dadosGerador.y, dadosGerador.z)
        if objetoGerador then
            -- Repara Gen_BuildingPoolID ausente do estado ao recarregar
            local modDataObj = objetoGerador:getModData()
            local idPoolRestauravel = nil
            if modDataObj and modDataObj.LKS_EletricidadeConstrucao_DisconnectSuppressed then
                idPoolRestauravel = nil
            elseif modDataObj and (not modDataObj.Gen_BuildingPoolID) and dadosGerador.id and not _restauracoesPoolVistas[dadosGerador.id] then
                idPoolRestauravel = encontrarIdPoolRestauravel(gerenciadorEstado, dadosGerador)
            end
            -- Apenas restaura a conexão do pool se o StateManager ainda possuir connectedBuildings.
            -- Após uma desconexão deliberada, buildingData.connectedGenerators não referencia mais
            -- este gerador, de modo que encontrarIdPoolRestauravel() retorna nil e nós
            -- não o reconectamos a partir de um estado de gerador obsoleto.
            if idPoolRestauravel then
                local idPool = idPoolRestauravel
                modDataObj.Gen_BuildingPoolID = idPool
                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                    objetoGerador:transmitModData()
                end
                qualquerAlteracaoEstado = true
                _restauracoesPoolVistas[dadosGerador.id] = true
                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format("Restaurado Gen_BuildingPoolID=%s para %s", modDataObj.Gen_BuildingPoolID, dadosGerador.id or "?"), "Fuel")

                -- Garante também que o prédio saiba desse gerador para o Distributor sincronizar estatísticas.
                if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
                    local predio = LKS_EletricidadeConstrucao.Core.StateManager.GetBuilding(idPool)
                    if predio then
                        predio.connectedGenerators = predio.connectedGenerators or {}
                        local chaveGerador = string.format("%d_%d_%d", dadosGerador.x or 0, dadosGerador.y or 0, dadosGerador.z or 0)
                        local existe = false
                        -- connectedGenerators é desserializado pelo Kahlua (chaves numéricas string)
                        for _, chaveG in pairs(predio.connectedGenerators) do
                            if chaveG == chaveGerador then existe = true; break end
                        end
                        if not existe then
                            table.insert(predio.connectedGenerators, chaveGerador)
                            LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format("Vinculado gerador %s de volta ao prédio %s", chaveGerador, idPool), "Fuel")
                        end
                    end
                end

                -- Persiste a conexão do pool restaurada mesmo se os dados do prédio já estivessem presentes.
                LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
            end
            -- Sincroniza estado de execução do IsoObject
            local ativo = objetoGerador:isActivated() or false
            local condicao = objetoGerador:getCondition() or 0
            if dadosGerador.activated ~= ativo or dadosGerador.condition ~= condicao then
                dadosGerador.activated = ativo
                dadosGerador.condition = condicao
                qualquerAlteracaoEstado = true
            end
            
            -- Sincronia de combustível: IsoObject agora é autoridade.
            -- Sempre extrai o valor em tempo real para o cache do estado; nunca sobrescreve
            -- o IsoObject a partir do estado (UpdateGenerator é o único escritor do
            -- IsoObject e grava o Gen_LastCalcWorldAge ao mesmo tempo).
            local combustivelReal = objetoGerador:getFuel() or 0
            local combustivelEstado = dadosGerador.fuelAmount or 0
            local ultimoSincronizado = dadosGerador.lastSyncedFuel

            if combustivelReal ~= combustivelEstado then
                dadosGerador.fuelAmount = combustivelReal
                qualquerAlteracaoEstado = true
            end
            if ultimoSincronizado ~= nil and combustivelReal > ultimoSincronizado + 0.5 then
                -- o combustível subiu desde a nossa última sincronização → jogador reabasteceu manualmente
                LKS_EletricidadeConstrucao.Core.Logger.Debug(
                    string.format("Reabastecimento manual detectado: %.3f -> %.3f para %s", combustivelEstado, combustivelReal, dadosGerador.id or "?"),
                    "Fuel"
                )
            end
            dadosGerador.lastSyncedFuel = combustivelReal
        end
        
        -- Verificação de segurança: o gerador não pode funcionar sem combustível
        -- Corrige estados inconsistentes de execuções anteriores (antes do modelo de combustível contínuo)
        if dadosGerador.activated and (dadosGerador.fuelAmount or 0) <= 0 then
            dadosGerador.activated = false
            qualquerAlteracaoEstado = true
            LKS_EletricidadeConstrucao.Core.Logger.Warn(
                string.format("Gerador %s estava ativado mas está sem combustível - desativando", dadosGerador.id),
                "Fuel"
            )
            
            -- Desativa também o IsoObject real para que isBuildingPoweredInline retorne false
            if objetoGerador then
                objetoGerador:setActivated(false)
                dadosGerador.lastSyncedFuel = 0
            end
            
            -- Atualiza o estado de energia dos prédios conectados imediatamente
            if dadosGerador.connectedBuildings and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
                -- connectedBuildings é desserializado pelo Kahlua (chaves numéricas string)
                for _, idPredio in pairs(dadosGerador.connectedBuildings) do
                    if LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding then
                        pcall(LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding, idPredio)
                    end
                end
            end
        end
    end
    if qualquerAlteracaoEstado then
        gerenciadorEstado.MarkDirty()
    end
    
    -- Atualiza todos os geradores ativos usando a variação de worldAge de cada gerador.
    -- Apenas processa geradores cujo chunk esteja atualmente carregado (sem consumo fora de chunk).
    -- No primeiro tick após uma longa ausência, o tempo decorrido total é usado como variacaoSegundos
    -- (consumo de compensação). Os barris já foram reabastecidos acima.
    -- B-102: Limpa o cache de pool por tick para que cada pool seja computado exatamente uma vez neste tick.
    _cachePoolPorTick = {}
    _geradorParaPoolPorTick = {}

    local geradoresAtivos = gerenciadorEstado.GetActiveGenerators()

    if #geradoresAtivos > 0 then
        local totalAtualizados = 0
        for _, dadosGerador in ipairs(geradoresAtivos) do
            -- Exige o IsoObject carregado: sem drenagem fora de chunk.
            local objetoGerador = getGeneratorFromSquare(dadosGerador.x, dadosGerador.y, dadosGerador.z)
            if objetoGerador then
                local modDataObj = objetoGerador:getModData()
                local idadeUltimoCalculo = modDataObj.Gen_LastCalcWorldAge  -- nil no primeiro tick
                local minutosDeltaGerador
                if idadeUltimoCalculo == nil then
                    -- Primeiro tick deste gerador: trata como um minuto normal.
                    minutosDeltaGerador = 1
                else
                    minutosDeltaGerador = (_idadeMundoAtual - idadeUltimoCalculo) * 60
                end
                if minutosDeltaGerador >= 1 then
                    local segundosDeltaGerador = minutosDeltaGerador * 60
                    local combustivelAntes = objetoGerador:getFuel() or 0
                    local ehCompensacao = minutosDeltaGerador > 1.5 -- mais de um tick normal = compensação real
                    if ehCompensacao then
                        LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                            "[FuelManager][Compensacao] INICIO gen=%s combustivel=%.3f idadeUltimoCalculo=%.4fh idadeAtual=%.4fh delta=%.2f min (%.0fs)",
                            dadosGerador.id, combustivelAntes,
                            idadeUltimoCalculo or 0, _idadeMundoAtual,
                            minutosDeltaGerador, segundosDeltaGerador), "Fuel")
                    end
                    LKS_EletricidadeConstrucao.Fuel.Manager.UpdateGenerator(dadosGerador, segundosDeltaGerador)
                    if ehCompensacao then
                        local combustivelDepois = dadosGerador.fuelAmount or 0
                        local drenado = combustivelAntes - combustivelDepois
                        local taxaLph = segundosDeltaGerador > 0 and (drenado * 3600 / segundosDeltaGerador) or 0
                        LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                            "[FuelManager][Compensacao] FIM gen=%s combustivelAntes=%.3f combustivelDepois=%.3f drenado=%.4f (equivalente a %.3f L/h) pool=%d",
                            dadosGerador.id, combustivelAntes, combustivelDepois, drenado, taxaLph,
                            LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators(dadosGerador)), "Fuel")
                    end
                    totalAtualizados = totalAtualizados + 1
                end
            end
            -- fora de chunk: pula silenciosamente, combustível inalterado até o jogador retornar
        end
        
        if totalAtualizados > 0 then
            gerenciadorEstado.MarkDirty()
        end
    end
    
    -- Atualiza carimbo de estatísticas
    _ultimosMinutosMundo = minutosMundoAtuais
    
    -- Atualiza estatísticas de tempo ativo (usa variação ilimitada para refletir o tempo real decorrido)
    gerenciadorEstado.UpdateUptime(segundosAtivo)
end

-- ============================================================================
-- OPERAÇÕES MANUAIS DO JOGADOR
-- ============================================================================

--- Força cálculo imediato do combustível para um gerador específico (ex: quando o aquecimento é alternado)
--- @param x number Coordenada X
--- @param y number Coordenada Y
--- @param z number Coordenada Z (opcional, padrão 0)
function LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator(x, y, z)
    if not _inicializado then return end
    z = z or 0
    
    -- Garante que _idadeMundoAtual esteja atualizado para que o UpdateGenerator grave um
    -- ponto de verificação Gen_LastCalcWorldAge válido (evita um salto enorme no próximo tick real).
    local tempoJogo = getGameTime and getGameTime()
    if tempoJogo then _idadeMundoAtual = tempoJogo:getWorldAgeHours() or _idadeMundoAtual end
    
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
    local chaveGerador = x .. "_" .. y .. "_" .. z
    local dadosGerador = gerenciadorEstado.GetGenerator(chaveGerador)
    
    if dadosGerador and dadosGerador.activated ~= false then
        -- Força uma atualização mínima (1 segundo) para recalcular a taxa de consumo sem drenar combustível
        LKS_EletricidadeConstrucao.Fuel.Manager.UpdateGenerator(dadosGerador, 1)
        gerenciadorEstado.MarkDirty()
        LKS_EletricidadeConstrucao.Core.Logger.Debug(
            string.format("Atualização de combustível forçada para gerador em %d,%d,%d", x, y, z),
            "Fuel"
        )
    end
end

-- ============================================================================
-- ATUALIZAÇÃO DO GERADOR
-- ============================================================================

--- Atualiza o consumo de combustível de um único gerador.
--- IsoObject é a fonte de combustível autoritativa: o valor é lido e gravado usando
--- gen:getFuel()/gen:setFuel(). O fuelAmount do estado é mantido em sincronia como
--- um cache para verificações de energia fora de chunk (isBuildingPoweredInline) e interface.
--- Gen_LastCalcWorldAge é gravado no moddata do IsoObject para que a compensação funcione
--- corretamente mesmo após uma falha de desserialização do GlobalModData.
--- @param generatorData GeneratorData Gerador a atualizar
--- @param deltaSeconds number Variação de tempo em segundos (pode ser grande na compensação)
function LKS_EletricidadeConstrucao.Fuel.Manager.UpdateGenerator(generatorData, deltaSeconds)
    local Validacao = LKS_EletricidadeConstrucao.Utils.Validation
    local Logger = LKS_EletricidadeConstrucao.Core.Logger
    
    if not generatorData then
        LKS_EletricidadeConstrucao.Core.Logger.Error("Dados do gerador são nulos", "Fuel")
        return
    end
    
    -- Verifica se o gerador está funcionando (usa cache do estado de fuelAmount + activated)
    if not LKS_EletricidadeConstrucao.Data.Generator.IsRunning(generatorData) then
        return
    end
    
    -- IsoObject é autoritativo para o combustível. Lê o valor em tempo real se o chunk estiver carregado.
    local objetoGerador = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    local chunkCarregado = (objetoGerador ~= nil and Validacao.IsGenerator(objetoGerador))
    
    local combustivelAtual
    if chunkCarregado then
        -- IsoObject é a fonte da verdade
        combustivelAtual = objetoGerador:getFuel() or 0
        -- Mantém cache do estado atualizado para verificações fora de chunk ficarem corretas
        generatorData.fuelAmount = combustivelAtual
    else
        -- Fallback fora de chunk para cache do estado (deve ocorrer raramente devido a pré-verificações no Update)
        combustivelAtual = generatorData.fuelAmount or 0
    end
    
    -- Calcula consumo de combustível
    local combustivelConsumido = LKS_EletricidadeConstrucao.Fuel.Manager.CalculateFuelConsumption(generatorData, deltaSeconds)

    if combustivelConsumido == -1 then
        -- Gerador falhou fisicamente (sobrecarga extrema ou integridade atingiu 0)
        generatorData.activated = false
        if chunkCarregado then
            objetoGerador:setActivated(false)
            objetoGerador:sync()
            objetoGerador:getModData().Gen_LastCalcWorldAge = _idadeMundoAtual
        end
        if generatorData.connectedBuildings and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            -- connectedBuildings é desserializado pelo Kahlua (chaves numéricas string)
            for _, idPredio in pairs(generatorData.connectedBuildings) do
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(idPredio)
            end
        end
        Logger.Info(string.format("Gerador %s falhou fisicamente devido a danos de sobrecarga/integridade", generatorData.id or "?"), "Fuel")
        return
    end

    if combustivelConsumido <= 0 then
        -- Ainda assim grava o ponto de verificação para o próximo cálculo partir de agora
        if chunkCarregado then
            objetoGerador:getModData().Gen_LastCalcWorldAge = _idadeMundoAtual
        end
        Logger.Trace(string.format("[Fuel] Sem consumo para %s (delta=%.2fs)", generatorData.id or "?", deltaSeconds), "Fuel")
        return
    end
    
    local novoCombustivel = math.max(0, combustivelAtual - combustivelConsumido)
    
    -- Grava combustível autoritativo no IsoObject + sincroniza cache do estado
    generatorData.fuelAmount = novoCombustivel
    if chunkCarregado then
        objetoGerador:setFuel(novoCombustivel)
        generatorData.lastSyncedFuel = novoCombustivel
        -- Persiste o ponto de verificação de worldAge para a compensação ficar correta após recarregar o chunk
        objetoGerador:getModData().Gen_LastCalcWorldAge = _idadeMundoAtual
    end
    
    if novoCombustivel <= 0 then
        generatorData.activated = false
        if chunkCarregado then
            objetoGerador:setActivated(false)
        end
        LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorFuelEmpty(generatorData)
        if generatorData.connectedBuildings and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            -- connectedBuildings é desserializado pelo Kahlua (chaves numéricas string)
            for _, idPredio in pairs(generatorData.connectedBuildings) do
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(idPredio)
            end
            local totalPredios = 0
            for _ in pairs(generatorData.connectedBuildings) do totalPredios = totalPredios + 1 end
            Logger.Debug(string.format("Atualizados %d prédio(s) após o gerador %s ficar sem combustível",
                totalPredios, generatorData.id), "Fuel")
        end
        Logger.Info(string.format("Gerador %s ficou sem combustível (chunk carregado: %s)", generatorData.id, tostring(chunkCarregado)), "Fuel")
    end
    
    -- Registra estatísticas
    LKS_EletricidadeConstrucao.Core.StateManager.RecordFuelConsumption(combustivelConsumido)
    generatorData.lastUpdateTime = getTimestampMs()
    
    local lph = deltaSeconds > 0 and (combustivelConsumido * 3600 / deltaSeconds) or 0
    Logger.Debug(string.format("Gerador %s consumiu %.4f de combustível (%.3f L/h) (restante: %.3f -> %.3f) [chunk: %s]",
        generatorData.id, combustivelConsumido, lph, combustivelAtual, novoCombustivel, tostring(chunkCarregado)), "Fuel")
end

-- ============================================================================
-- CÁLCULO DE COMBUSTÍVEL
-- ============================================================================

--- Calcula o consumo de combustível para um período de tempo
--- @param generatorData GeneratorData Dados do gerador
--- @param deltaSeconds number Variação de tempo em segundos
--- @return number Combustível consumido
function LKS_EletricidadeConstrucao.Fuel.Manager.CalculateFuelConsumption(generatorData, deltaSeconds)
    local Config = LKS_EletricidadeConstrucao.Config
    local Constantes = LKS_EletricidadeConstrucao.Constants
    local Logger = LKS_EletricidadeConstrucao.Core.Logger

    -- Soma consumo de combustível específico por tipo a partir de todos os consumidores ativos
    local taxaConsumoInativo = Constantes.FUEL.BASE_CONSUMPTION_RATE or 0.0001 -- consumo por segundo de base inativa
    local taxaBaseCombustivel = 0.0
    local contagemAtivos = 0 -- Rastreia quantidade para logs
    
    -- Soma consumo de combustível de TODOS os prédios no pool (não apenas dos prédios deste gerador)
    -- Isso garante o compartilhamento igual de combustível por todos os geradores no mesmo pool
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    
    -- Passo 1: Descobre recursivamente TODOS os geradores neste pool
    local geradoresPool = {} -- Conjunto de todos os IDs de geradores no pool
    local prediosPool = {}   -- Conjunto de todos os IDs de prédios no pool
    -- Sinalizador ativado se o PoolFallback foi usado (BFS falharia pelo mesmo motivo - prédios sem estado ainda)
    local utilizouPoolFallback = false

    -- ── B-102: Atalho do cache do pool por tick ───────────────────────────────
    -- Se um gerador irmão neste pool já computou a carga do pool neste tick,
    -- reutiliza o resultado em cache em vez de repetir a busca BFS + varredura de consumidores.
    do
        local chaveCache = _geradorParaPoolPorTick[generatorData.id]
        if chaveCache then
            local emCache = _cachePoolPorTick[chaveCache]
            if emCache then
                local ativosPool = emCache.poolActive
                local taxaPorGerador = emCache.totalPoolRate / ativosPool

                -- Multiplicador por tipo de gerador (espelha o caminho de falha de cache abaixo)
                local objetoGeradorCache = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
                local multCombustivelC = 1.0
                if objetoGeradorCache then
                    local spriteC = objetoGeradorCache.getSpriteName and objetoGeradorCache:getSpriteName()
                        or (objetoGeradorCache.getSprite and objetoGeradorCache:getSprite() and objetoGeradorCache:getSprite():getName())
                    generatorData.cachedSprite = spriteC
                    local modificadoresC = MODIFICADORES_TIPO_GERADOR[spriteC or ""]
                    if modificadoresC then
                        multCombustivelC = modificadoresC.fuel or 1.0
                        generatorData.cachedFuelMult = multCombustivelC
                        generatorData.cachedStrainMult = modificadoresC.strain or 1.0
                    end
                    local mesmoSpriteC = contarGeradoresMesmoSprite(objetoGeradorCache, generatorData)
                    multCombustivelC = aplicarRetornosDecrescentes(multCombustivelC, mesmoSpriteC)
                else
                    multCombustivelC = generatorData.cachedFuelMult or 1.0
                end

                if generatorData.customFuelRate then
                    taxaPorGerador = generatorData.customFuelRate
                end

                local multSobrecargaC = 1.0
                if Config.StrainSystemEnabled then
                    -- B-103: passa a lista de prédios do pool a partir do cache para o StrainCalculator
                    -- usar a mesma topologia do BFS primário e evitar divergências de ID obsoleto.
                    multSobrecargaC = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData, emCache.poolBuildings, ativosPool)
                end

                local taxaEfetivaC = taxaPorGerador * multCombustivelC * multSobrecargaC
                local combustivelConsumidoC = taxaEfetivaC * deltaSeconds

                if objetoGeradorCache then
                    local modDataCache = objetoGeradorCache:getModData()
                    modDataCache.Gen_Stats_FuelRateLph = taxaEfetivaC * ativosPool * 3600
                    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                        objetoGeradorCache:transmitModData()
                    end
                end

                Logger.Debug(string.format(
                    "[FuelCalc][Cache] gen=%s ativosPool=%d porGerador=%.6f multCombustivel=%.3f multSobrecarga=%.3f efetivo=%.6f consumido=%.6f",
                    generatorData.id or "?", ativosPool, taxaPorGerador, multCombustivelC, multSobrecargaC,
                    taxaEfetivaC, combustivelConsumidoC), "Fuel")

                if Config.StrainSystemEnabled and LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage then
                    local falhouC = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage(generatorData, deltaSeconds)
                    if falhouC then return -1 end
                end

                return combustivelConsumidoC
            end
        end
    end
    -- ─────────────────────────────────────────────────────────────────────────

    if gerenciadorEstado then
        local function RepararConexoesPoolAusentes(geradorAtual)
            if not geradorAtual or geradorAtual.x == nil or geradorAtual.y == nil or geradorAtual.z == nil then
                return false
            end

            local objetoGerador = getGeneratorFromSquare(geradorAtual.x, geradorAtual.y, geradorAtual.z)
            local modDataGen = objetoGerador and objetoGerador:getModData() or nil
            local chaveGerador = string.format("%d_%d_%d", geradorAtual.x, geradorAtual.y, geradorAtual.z)

            local function Vincular(buildingId, buildingData)
                if not buildingId or not buildingData then return false end

                geradorAtual.connectedBuildings = geradorAtual.connectedBuildings or {}
                if LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
                        and LKS_EletricidadeConstrucao.Data.Generator.AddBuilding then
                    LKS_EletricidadeConstrucao.Data.Generator.AddBuilding(geradorAtual, buildingId)
                else
                    local possuiBid = false
                    for _, bid in pairs(geradorAtual.connectedBuildings) do
                        if bid == buildingId then possuiBid = true; break end
                    end
                    if not possuiBid then
                        table.insert(geradorAtual.connectedBuildings, buildingId)
                    end
                end

                buildingData.connectedGenerators = buildingData.connectedGenerators or {}
                local possuiGen = false
                for _, gk in pairs(buildingData.connectedGenerators) do
                    if gk == chaveGerador then possuiGen = true; break end
                end
                if not possuiGen then
                    table.insert(buildingData.connectedGenerators, chaveGerador)
                end

                gerenciadorEstado.AddGenerator(geradorAtual)
                if gerenciadorEstado.MarkDirty then
                    gerenciadorEstado.MarkDirty()
                end

                Logger.Info(string.format(
                    "[PoolBFS] Reparada conexao ausente de pool: %s -> %s",
                    geradorAtual.id or "?", buildingId), "Fuel")
                return true
            end

            local idPoolAtivo = modDataGen and modDataGen.Gen_BuildingPoolID or nil
            if idPoolAtivo then
                local predioAtivo = gerenciadorEstado.GetBuilding and gerenciadorEstado.GetBuilding(idPoolAtivo) or nil
                if predioAtivo and Vincular(idPoolAtivo, predioAtivo) then
                    return true
                end
            end

            local totalPredios = 0
            for bid, buildingData in pairs(gerenciadorEstado.GetAllBuildings() or {}) do
                totalPredios = totalPredios + 1
                if buildingData and buildingData.connectedGenerators then
                    for _, gk in pairs(buildingData.connectedGenerators) do
                        if gk == chaveGerador then
                            if modDataGen and not modDataGen.Gen_BuildingPoolID then
                                modDataGen.Gen_BuildingPoolID = bid
                                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                    objetoGerador:transmitModData()
                                end
                            end
                            return Vincular(bid, buildingData)
                        end
                    end
                end
            end

            local chaveDepuracao = tostring(idPoolAtivo) .. "|" .. tostring(totalPredios)
            if geradorAtual._chaveDepuracaoReparoPool ~= chaveDepuracao then
                geradorAtual._chaveDepuracaoReparoPool = chaveDepuracao
                Logger.Warn(string.format(
                    "[PoolBFS] Falha ao reparar para gen=%s poolAtivo=%s prediosNoEstado=%d",
                    geradorAtual.id or "?", tostring(idPoolAtivo), totalPredios), "Fuel")
            end

            return false
        end

        -- Repara o gerador inicial antes de fazer o fallback para um pool solo.
        if not generatorData.connectedBuildings or LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(generatorData.connectedBuildings) then
            RepararConexoesPoolAusentes(generatorData)
        end
        if not generatorData.connectedBuildings or LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(generatorData.connectedBuildings) then
            Logger.Warn(string.format(
                "[PoolBFS] gen=%s nao possui connectedBuildings - pool sera calculado como solo",
                generatorData.id), "Fuel")
        end
        
        local aVisitar = {generatorData} -- Começa com dados do gerador atual diretamente
        local visitados = {}
        
        while #aVisitar > 0 do
            local geradorAtual = table.remove(aVisitar)
            if geradorAtual and geradorAtual.id and not visitados[geradorAtual.id] then
                visitados[geradorAtual.id] = true
                geradoresPool[geradorAtual.id] = true
                
                -- Processa prédios conectados desse gerador
                if geradorAtual.connectedBuildings then
                    for indice, idPredio in pairs(geradorAtual.connectedBuildings) do
                        local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)

                        -- ── Lazy Xref: corrige IDs obsoletos bld_def_... em tempo de execução ──
                        -- Se o prédio não for encontrado com o ID armazenado (comum em chaves legadas
                        -- bld_def_XXXXXX que nunca foram migradas), faz uma busca reversa: escaneia todos
                        -- os prédios por um cuja lista connectedGenerators inclua a chave X_Y_Z deste gerador.
                        -- Repara o ID no connectedBuildings imediatamente para que os ticks subsequentes
                        -- o encontrem sem reescaneamento.
                        if not dadosPredio then
                            local chaveGeradorLocal = string.format("%d_%d_%d",
                                geradorAtual.x, geradorAtual.y, geradorAtual.z)
                            local todosPredios = gerenciadorEstado.GetAllBuildings() or {}
                            for _, predio in pairs(todosPredios) do
                                if predio and predio.connectedGenerators then
                                    for _, chaveGerador in pairs(predio.connectedGenerators) do
                                        if chaveGerador == chaveGeradorLocal then
                                            Logger.Info(string.format(
                                                "[PoolBFS] Lazy-Xref: %s connectedBuildings[%d] %s → %s",
                                                geradorAtual.id, indice, idPredio, predio.id), "Fuel")
                                            geradorAtual.connectedBuildings[indice] = predio.id
                                            gerenciadorEstado.AddGenerator(geradorAtual)
                                            dadosPredio = predio
                                            break
                                        end
                                    end
                                end
                                if dadosPredio then break end
                            end
                        end
                        -- ────────────────────────────────────────────────────────────────

                        if dadosPredio and dadosPredio.connectedGenerators then
                            -- Adiciona todos os geradores deste prédio à fila de visitas
                            for _, chaveGerador in pairs(dadosPredio.connectedGenerators) do
                                local coordX, coordY, coordZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                                if coordX then
                                    local idGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(tonumber(coordX), tonumber(coordY), tonumber(coordZ))
                                    if not visitados[idGerador] then
                                        local proximoGerador = gerenciadorEstado.GetGenerator(idGerador)
                                        if proximoGerador then
                                            table.insert(aVisitar, proximoGerador)
                                        end
                                    end
                                end
                            end
                        elseif not dadosPredio then
                            -- Prédio não está no estado - BFS de pool não consegue atravessar; causará divisão de pool
                            Logger.Warn(string.format(
                                "[PoolBFS] gen=%s: prédio %s não está no estado - travessia de pool interrompida",
                                geradorAtual.id, idPredio), "Fuel")
                        end
                    end
                end
            end
        end
        
        -- Passo 2: Coleta prédios de TODOS os geradores no pool (ativos OU inativos).
        -- Quando um gerador é desativado, o(s) gerador(es) ativos restantes devem assumir
        -- a carga total do pool – portanto, contamos TODOS os prédios, então dividimos pelo
        -- número de geradores ativos atualmente (ativosPool, feito abaixo).
        -- Deduplica por localização física (x_y_z): se o mesmo prédio existe sob um ID canônico
        -- (bld_X_Y_Z) e um ID obsoleto legado (bld_def_...), apenas o conta uma vez para evitar
        -- duplicar cálculos de aparelhos/aquecimento/sobrecarga.
        local _localizacoesPrediosPool = {} -- "x_y_z" -> true (guarda de dedup)
        for idGerador, _ in pairs(geradoresPool) do
            local dadosGen = gerenciadorEstado.GetGenerator(idGerador)
            if dadosGen and dadosGen.connectedBuildings then
                -- connectedBuildings é desserializado pelo Kahlua (chaves numéricas string)
                for _, idPredio in pairs(dadosGen.connectedBuildings) do
                    local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
                    if dadosPredio then
                        local chaveLocalizacao = (dadosPredio.x or 0) .. "_" .. (dadosPredio.y or 0) .. "_" .. (dadosPredio.z or 0)
                        if not _localizacoesPrediosPool[chaveLocalizacao] then
                            _localizacoesPrediosPool[chaveLocalizacao] = true
                            prediosPool[idPredio] = true
                        end
                    else
                        prediosPool[idPredio] = true -- localização desconhecida, inclui mesmo assim
                    end
                end
            end
        end
        
        -- Passo 3: Soma consumidores em todos os prédios do pool vindos de geradores ativos
        local algumPredioEncontrado = false
        for idPredioPool, _ in pairs(prediosPool) do
            local dadosPredio = gerenciadorEstado.GetBuilding(idPredioPool)
            if dadosPredio then
                algumPredioEncontrado = true
                if dadosPredio.powerConsumers then
                    -- powerConsumers é desserializado pelo Kahlua (chaves numéricas string); exige pairs
                    for _, consumidor in pairs(dadosPredio.powerConsumers) do
                        if consumidor.isActive then
                            -- Usa consumo específico por tipo (L/h), converte para L/s
                            local taxaLph = consumidor.fuelConsumptionLph or Constantes.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH
                            taxaBaseCombustivel = taxaBaseCombustivel + (taxaLph / 3600)
                            contagemAtivos = contagemAtivos + 1
                        end
                    end
                end
            end
        end

        -- Computa aquecimento do pool a partir dos PRÉDIOS (atributo em nível de pool, não por gerador).
        -- Fontes de aquecimento pertencem a um prédio, portanto a contagem de fontes de um único prédio
        -- é autoridade para o pool inteiro – sem dupla contagem em geradores no mesmo pool.
        -- Fallback para campos individuais de geradores (heatingEnabled/heatingSourceCount) para
        -- salvamentos anteriores à criação desses campos em nível de prédio (compatibilidade reversa).
        local cargaAquecimentoTotal = 0
        local aquecimentoPorFonte = (Constantes.FUEL.CONSUMPTION_RATE_HEATING_PER_SOURCE_LPH or 0.02) / 3600
        local aquecimentoPorGrau = (Constantes.FUEL.CONSUMPTION_RATE_HEATING_PER_DEGREE_LPH or 0.002) / 3600
        local aquecimentoPredioEncontrado = false

        for idPredioPool, _ in pairs(prediosPool) do
            local dadosPredio = gerenciadorEstado.GetBuilding(idPredioPool)
            if dadosPredio and dadosPredio.heatingEnabled and dadosPredio.heatingSourceCount and dadosPredio.heatingSourceCount > 0 then
                aquecimentoPredioEncontrado = true
                local tempAlvo = dadosPredio.heatingTargetTemp or 22
                local taxaPorFonte = aquecimentoPorFonte + aquecimentoPorGrau * math.max(0, tempAlvo - 20)
                local aquecimentoPredio = taxaPorFonte * dadosPredio.heatingSourceCount
                cargaAquecimentoTotal = cargaAquecimentoTotal + aquecimentoPredio
                Logger.Debug(
                    string.format("[PoolHeating] prédio=%s fontes=%d temp=%.1f aquecimento=%.8f L/s (%.4f L/h)",
                        idPredioPool, dadosPredio.heatingSourceCount, tempAlvo, aquecimentoPredio, aquecimentoPredio * 3600),
                    "Fuel"
                )
            end
        end

        -- Compatibilidade reversa: se não houver dados de aquecimento em nível de prédio,
        -- recai sobre heatingSourceCount por gerador (gravado por Heating.SyncToGenerators da V1).
        -- O risco de contagem dupla é evitado porque este caminho é usado apenas quando prédios
        -- não possuem o campo heatingSourceCount (migração fria de salvamentos antigos).
        if not aquecimentoPredioEncontrado then
            for idGerador, _ in pairs(geradoresPool) do
                local dadosGen = gerenciadorEstado.GetGenerator(idGerador)
                if dadosGen and dadosGen.heatingEnabled and dadosGen.heatingSourceCount and dadosGen.heatingSourceCount > 0 then
                    local tempAlvo = dadosGen.heatingTargetTemp or 22
                    local taxaPorFonte = aquecimentoPorFonte + aquecimentoPorGrau * math.max(0, tempAlvo - 20)
                    local aquecimentoGerador = taxaPorFonte * dadosGen.heatingSourceCount
                    cargaAquecimentoTotal = cargaAquecimentoTotal + aquecimentoGerador
                    Logger.Debug(
                        string.format("[PoolHeating][GenFallback] gen=%s fontes=%d temp=%.1f aquecimento=%.8f L/s (%.4f L/h)",
                            dadosGen.id, dadosGen.heatingSourceCount, tempAlvo, aquecimentoGerador, aquecimentoGerador * 3600),
                        "Fuel"
                    )
                end
            end
        end

        -- Total do pool completo = aparelhos (taxaBaseCombustivel) + aquecimento
        local totalPoolCompleto = taxaBaseCombustivel + cargaAquecimentoTotal

        -- PoolFallback: se prédios era esperado (prediosPool não vazio) mas NENHUM foi
        -- encontrado no estado, usa o total do pool em cache da última sessão em tempo real.
        -- O cache armazena aparelhos + aquecimento juntos para que o fallback seja completo.
        local algumPredioEsperado = false
        for _ in pairs(prediosPool) do algumPredioEsperado = true; break end
        if not algumPredioEncontrado and algumPredioEsperado and generatorData.cachedRealPoolTotalLps then
            Logger.Info(
                string.format("[PoolFallback] gen=%s prédios não estão no estado ainda – usando total de pool em cache %.8f L/s (%.4f L/h), cachedPoolActive=%d",
                    generatorData.id, generatorData.cachedRealPoolTotalLps, generatorData.cachedRealPoolTotalLps * 3600,
                    generatorData.cachedPoolActive or 1),
                "Fuel")
            taxaBaseCombustivel = generatorData.cachedRealPoolTotalLps
            utilizouPoolFallback = true -- pula CountActivePoolGenerators abaixo (também falharia no BFS)
        else
            -- Usa o total recém-calculado e persiste-o para reinicializações futuras.
            taxaBaseCombustivel = totalPoolCompleto

            -- Salva em cache o total COMPLETO do pool (aparelhos + aquecimento) para que o PoolFallback na próxima
            -- inicialização inclua ambos os componentes. Envia via AddGenerator (not just MarkDirty)
            -- para gravar em LKS_EletricidadeConstrucaoV2_GeneratorIndex, o único ModData global
            -- que sobrevive confiavelmente à saída do PZ.
            if algumPredioEncontrado or cargaAquecimentoTotal > 0 then
                local novoCache = totalPoolCompleto
                local antigoCache = generatorData.cachedRealPoolTotalLps or 0
                generatorData.cachedRealPoolTotalLps = novoCache
                if math.abs(novoCache - antigoCache) / math.max(antigoCache, 1e-9) > 0.05 then
                    gerenciadorEstado.AddGenerator(generatorData)
                else
                    gerenciadorEstado.MarkDirty()
                end
            end
        end
    end
    
    -- Mínimo: consumo do motor ocioso quando funcionando mas sem consumidores ativos.
    -- Usa a constante dedicada para inatividade (0.0002 L/h) para não inflar prédios leves.
    local taxaOciosoPorSegundo = (Constantes.FUEL.CONSUMPTION_IDLE_LPH or 0.0002) / 3600
    if taxaBaseCombustivel < taxaOciosoPorSegundo then
        taxaBaseCombustivel = taxaOciosoPorSegundo
    end

    Logger.Debug(
        string.format("[PoolTotal] gen=%s aparelhos+aquecimento=%.8f L/s (%.4f L/h) antes da divisão do pool",
            generatorData.id, taxaBaseCombustivel, taxaBaseCombustivel * 3600),
        "Fuel"
    )
    
    -- AGORA divide a carga total do pool (aparelhos + aquecimento) pelos geradores ativos.
    -- Se o PoolFallback disparou, CountActivePoolGenerators falharia no BFS pelo mesmo motivo
    -- (prédios sem estado ainda) e retornaria 1, cobrando de cada gerador a taxa total do pool.
    -- Usa cachedPoolActive (salvo do último tick em chunk) como alternativa.
    local ativosPool
    if utilizouPoolFallback then
        ativosPool = generatorData.cachedPoolActive or 1
    else
        ativosPool = CountActivePoolGenerators(generatorData)
        -- Persiste a quantidade de ativos do pool para ficar disponível caso uma reinicialização ocorra fora de chunk.
        if gerenciadorEstado and ativosPool >= 1 then
            if (generatorData.cachedPoolActive or 0) ~= ativosPool then
                generatorData.cachedPoolActive = ativosPool
                gerenciadorEstado.MarkDirty()
            end
        end
    end
    -- B-102: Captura o total em nível de pool antes da divisão por gerador; armazena no cache do tick
    -- para os geradores irmãos pularem seu próprio BFS + varredura de consumidores neste tick.
    local totalTaxaPoolParaCache = taxaBaseCombustivel
    taxaBaseCombustivel = taxaBaseCombustivel / ativosPool

    _cachePoolPorTick[generatorData.id] = {
        totalPoolRate = totalTaxaPoolParaCache,
        poolActive = ativosPool,
        poolBuildings = prediosPool, -- B-103: compartilhado com StrainCalculator para evitar BFS com IDs obsoletos
    }
    for gid in pairs(geradoresPool) do
        _geradorParaPoolPorTick[gid] = generatorData.id
    end

    Logger.Debug(
        string.format("[PoolDivision] gen=%s ativosPool=%d depoisDivisao=%.8f L/s (%.4f L/h)",
            generatorData.id, ativosPool, taxaBaseCombustivel, taxaBaseCombustivel * 3600),
        "Fuel"
    )

    -- Multiplicadores de combustível/sobrecarga específicos por sprite
    -- Salva dados de sprite no cache de generatorData para cálculos fora de chunk
    local objetoGerador = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    local multCombustivel = 1.0
    local multSobrecargaTipo = 1.0
    local quantidadeMesmoSprite = 1
    
    if objetoGerador then
        -- Chunk carregado - obtém dados do sprite em tempo real e os salva em cache
        local sprite = objetoGerador.getSpriteName and objetoGerador:getSpriteName() or (objetoGerador.getSprite() and objetoGerador:getSprite() and objetoGerador:getSprite():getName())
        generatorData.cachedSprite = sprite
        
        local modificadores = MODIFICADORES_TIPO_GERADOR[sprite or ""]
        if modificadores then
            multCombustivel = modificadores.fuel or multCombustivel
            multSobrecargaTipo = modificadores.strain or multSobrecargaTipo
        end
        
        -- Salva multiplicadores base (antes dos retornos decrescentes) para uso fora de chunk
        generatorData.cachedFuelMult = multCombustivel
        generatorData.cachedStrainMult = multSobrecargaTipo
        
        -- Aplica retornos decrescentes para múltiplos geradores com o mesmo sprite
        quantidadeMesmoSprite = contarGeradoresMesmoSprite(objetoGerador, generatorData)
        multCombustivel = aplicarRetornosDecrescentes(multCombustivel, quantidadeMesmoSprite)
        multSobrecargaTipo = aplicarRetornosDecrescentes(multSobrecargaTipo, quantidadeMesmoSprite)
    else
        -- Chunk não carregado - usa valores em cache (sem retornos decrescentes, não sabemos a quantidade fora de chunk)
        multCombustivel = generatorData.cachedFuelMult or 1.0
        multSobrecargaTipo = generatorData.cachedStrainMult or 1.0
    end

    if generatorData.customFuelRate then
        taxaBaseCombustivel = generatorData.customFuelRate
    end

    -- Multiplicador de sobrecarga (cache gerenciado internamente pelo StrainCalculator)
    local multiplicadorSobrecarga = 1.0
    if Config.StrainSystemEnabled then
        multiplicadorSobrecarga = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData, prediosPool, ativosPool)
    end

    local taxaCombustivelEfetiva = taxaBaseCombustivel * multCombustivel * multiplicadorSobrecarga
    local combustivelConsumido = taxaCombustivelEfetiva * deltaSeconds
    local taxaLph = taxaCombustivelEfetiva * 3600

    -- Calcula o consumo TOTAL do pool incluindo todos os multiplicadores
    -- taxaCombustivelEfetiva é por gerador após divisão, então multiplica por ativosPool para obter o total do pool
    local taxaTotalPoolLph = taxaCombustivelEfetiva * ativosPool * 3600

    -- Grava o consumo TOTAL do pool no ModData para exibição de interface (NÃO a taxa por gerador)
    -- Isso exibe o consumo total de combustível do pool completo, independentemente de quantos geradores estejam ativos
    if objetoGerador then
        local modDataObj = objetoGerador:getModData()
        modDataObj.Gen_Stats_FuelRateLph = taxaTotalPoolLph
        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
            objetoGerador:transmitModData()
        end
    end

    Logger.Debug(
        string.format("[FuelCalc] gen=%s ativosPool=%d base=%.6f multCombustivel=%.3f multSobrecarga=%.3f efetivo=%.6f efetivoLph=%.3f totalPoolLph=%.3f consumido=%.6f",
            generatorData.id or "?", ativosPool, taxaBaseCombustivel, multCombustivel, multiplicadorSobrecarga, taxaCombustivelEfetiva, taxaLph, taxaTotalPoolLph, combustivelConsumido),
        "Fuel"
    )

    -- Aplica danos à integridade baseados em sobrecarga (>100% de sobrecarga apenas)
    if Config.StrainSystemEnabled and LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage then
        local falhou = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.ApplyStrainDamage(generatorData, deltaSeconds)
        if falhou then
            -- Gerador falhou fisicamente — retorna sentinela -1 para UpdateGenerator tratar
            return -1
        end
    end

    return combustivelConsumido
end

--- Obtém estimativa de horas de funcionamento restantes do gerador
--- @param generatorData GeneratorData Dados do gerador
--- @return number Horas restantes
function LKS_EletricidadeConstrucao.Fuel.Manager.GetRemainingHours(generatorData)
    local Config = LKS_EletricidadeConstrucao.Config
    local Constantes = LKS_EletricidadeConstrucao.Constants
    
    if not LKS_EletricidadeConstrucao.Data.Generator.IsRunning(generatorData) then
        return 0
    end

    -- Soma consumo de combustível de todos os consumidores ativos
    local taxaConsumoInativo = Constantes.FUEL.BASE_CONSUMPTION_RATE or 0.0001
    local taxaBaseCombustivel = 0.0
    
    -- Soma consumo de combustível de TODOS os prédios no pool
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    
    -- Passo 1: Descobre todos os geradores neste pool
    local geradoresPool = {}
    local prediosPool = {}
    
    if gerenciadorEstado then
        local aVisitar = {generatorData}
        local visitados = {}
        
        while #aVisitar > 0 do
            local geradorAtual = table.remove(aVisitar)
            if geradorAtual and geradorAtual.id and not visitados[geradorAtual.id] then
                visitados[geradorAtual.id] = true
                geradoresPool[geradorAtual.id] = true
                
                if geradorAtual.connectedBuildings then
                    for _, idPredio in pairs(geradorAtual.connectedBuildings) do
                        local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
                        if dadosPredio and dadosPredio.connectedGenerators then
                            for _, chaveGerador in pairs(dadosPredio.connectedGenerators) do
                                local coordX, coordY, coordZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                                if coordX then
                                    local idGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(tonumber(coordX), tonumber(coordY), tonumber(coordZ))
                                    if not visitados[idGerador] then
                                        local proximoGerador = gerenciadorEstado.GetGenerator(idGerador)
                                        if proximoGerador then
                                            table.insert(aVisitar, proximoGerador)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Passo 2: Coleta prédios apenas de geradores ATIVOS.
        -- Deduplica por localização física para evitar contar o mesmo prédio duas vezes
        local _localizacoesVistas = {}
        for idGerador, _ in pairs(geradoresPool) do
            local dadosGen = gerenciadorEstado.GetGenerator(idGerador)
            if dadosGen and LKS_EletricidadeConstrucao.Data.Generator.IsRunning(dadosGen) and dadosGen.connectedBuildings then
                for _, idPredio in pairs(dadosGen.connectedBuildings) do
                    local dadosPredio = gerenciadorEstado.GetBuilding(idPredio)
                    if dadosPredio then
                        local chaveLocalizacao = (dadosPredio.x or 0) .. "_" .. (dadosPredio.y or 0) .. "_" .. (dadosPredio.z or 0)
                        if not _localizacoesVistas[chaveLocalizacao] then
                            _localizacoesVistas[chaveLocalizacao] = true
                            prediosPool[idPredio] = true
                        end
                    else
                        prediosPool[idPredio] = true
                    end
                end
            end
        end
        
        -- Passo 3: Soma consumidores em todos os prédios do pool vindos de geradores ativos
        for idPredioPool, _ in pairs(prediosPool) do
            local dadosPredio = gerenciadorEstado.GetBuilding(idPredioPool)
            if dadosPredio and dadosPredio.powerConsumers then
                for _, consumidor in pairs(dadosPredio.powerConsumers) do
                    if consumidor.isActive then
                        local taxaLph = consumidor.fuelConsumptionLph or Constantes.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH
                        taxaBaseCombustivel = taxaBaseCombustivel + (taxaLph / 3600)
                    end
                end
            end
        end
    end
    
    -- Mínimo: garante que o gerador gaste combustível mesmo se não houver consumidores ativos
    if taxaBaseCombustivel < (Constantes.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH / 3600) then
        taxaBaseCombustivel = Constantes.FUEL.CONSUMPTION_APPLIANCE_DEFAULT_LPH / 3600
    end

    -- Adiciona consumo de aquecimento: por fonte instalada, escalado pela temperatura alvo
    local aquecimentoPorFonte = (Constantes.FUEL.CONSUMPTION_RATE_HEATING_PER_SOURCE_LPH or 0.02) / 3600
    local aquecimentoPorGrau = (Constantes.FUEL.CONSUMPTION_RATE_HEATING_PER_DEGREE_LPH or 0.002) / 3600
    local objetoGerador2 = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    if objetoGerador2 then
        local modDataObj2 = objetoGerador2:getModData()
        if modDataObj2.HeatingEnabled == true then
            local tempAlvo = tonumber(modDataObj2.HeatingTargetTemp) or 22
            local taxaPorFonte = aquecimentoPorFonte + aquecimentoPorGrau * math.max(0, tempAlvo - 20)
            local totalFontes = 0
            if type(modDataObj2.HeatingPositions) == "table" then
                for _, grupo in ipairs(modDataObj2.HeatingPositions) do
                    if type(grupo.positions) == "table" then totalFontes = totalFontes + #grupo.positions end
                end
            end
            if totalFontes < 1 then totalFontes = 1 end
            taxaBaseCombustivel = taxaBaseCombustivel + taxaPorFonte * totalFontes
        end
    end

    if generatorData.customFuelRate then
        taxaBaseCombustivel = generatorData.customFuelRate
    end

    -- Divide a carga por todos os geradores ativos no mesmo pool
    local ativosPool = CountActivePoolGenerators(generatorData)
    taxaBaseCombustivel = taxaBaseCombustivel / ativosPool

    -- Multiplicadores de combustível/sobrecarga por sprite (deve corresponder ao CalculateFuelConsumption)
    local multCombustivel = 1.0
    local multSobrecargaTipo = 1.0
    
    if objetoGerador2 then
        local sprite = objetoGerador2.getSpriteName and objetoGerador2:getSpriteName() or (objetoGerador2.getSprite() and objetoGerador2:getSprite() and objetoGerador2:getSprite():getName())
        generatorData.cachedSprite = sprite
        
        local modificadores = MODIFICADORES_TIPO_GERADOR[sprite or ""]
        if modificadores then
            multCombustivel = modificadores.fuel or multCombustivel
            multSobrecargaTipo = modificadores.strain or multSobrecargaTipo
        end
        
        generatorData.cachedFuelMult = multCombustivel
        generatorData.cachedStrainMult = multSobrecargaTipo
        
        -- Aplica retornos decrescentes
        local quantidadeMesmoSprite = contarGeradoresMesmoSprite(objetoGerador2, generatorData)
        multCombustivel = aplicarRetornosDecrescentes(multCombustivel, quantidadeMesmoSprite)
        multSobrecargaTipo = aplicarRetornosDecrescentes(multSobrecargaTipo, quantidadeMesmoSprite)
    else
        multCombustivel = generatorData.cachedFuelMult or 1.0
        multSobrecargaTipo = generatorData.cachedStrainMult or 1.0
    end

    -- Multiplicador de sobrecarga
    local multiplicadorSobrecarga = 1.0
    if Config.StrainSystemEnabled then
        multiplicadorSobrecarga = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.GetStrainMultiplier(generatorData, nil, ativosPool)
    end

    local taxaCombustivelEfetiva = taxaBaseCombustivel * multCombustivel * multiplicadorSobrecarga

    if taxaCombustivelEfetiva <= 0 then
        return 999999 -- Infinito
    end

    local taxaCombustivelPorHora = taxaCombustivelEfetiva * 3600

    -- Grava a taxa no ModData imediatamente para que a interface não mostre 0 antes do primeiro tick
    local objetoGeradorRH = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    if objetoGeradorRH then
        local modDataRH = objetoGeradorRH:getModData()
        if (modDataRH.Gen_Stats_FuelRateLph or 0) == 0 then
            modDataRH.Gen_Stats_FuelRateLph = taxaCombustivelPorHora
            if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                objetoGeradorRH:transmitModData()
            end
        end
    end

    return generatorData.fuelAmount / taxaCombustivelPorHora
end

-- ============================================================================
-- OPERAÇÕES MANUAIS DO JOGADOR
-- ============================================================================

--- Consome combustível manualmente do gerador
--- @param generatorData GeneratorData Dados do gerador
--- @param amount number Quantidade de combustível a consumir
--- @return boolean True se a operação foi bem-sucedida
function LKS_EletricidadeConstrucao.Fuel.Manager.ConsumeFuel(generatorData, amount)
    if amount <= 0 then
        return false
    end
    
    local objetoGerador = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    
    if not objetoGerador then
        return false
    end
    
    local novoCombustivel = objetoGerador:getFuel() - amount
    
    if novoCombustivel < 0 then
        novoCombustivel = 0
    end
    
    objetoGerador:setFuel(novoCombustivel)
    generatorData.fuelAmount = novoCombustivel
    generatorData.lastSyncedFuel = novoCombustivel
    
    -- Registra estatísticas
    LKS_EletricidadeConstrucao.Core.StateManager.RecordFuelConsumption(amount)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    if novoCombustivel <= 0 and generatorData.activated then
        objetoGerador:setActivated(false)
        generatorData.activated = false
        LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorFuelEmpty(generatorData)
        
        -- Atualiza imediatamente o estado de energia para todos os prédios conectados
        if generatorData.connectedBuildings and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            local totalAtualizados = 0
            for _, idPredio in pairs(generatorData.connectedBuildings) do
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdateBuilding(idPredio)
                totalAtualizados = totalAtualizados + 1
            end
            Logger.Debug(string.format("Atualizados %d prédio(s) após remoção de combustível do gerador %s",
                totalAtualizados, generatorData.id), "Fuel")
        end
    end
    
    return true
end

--- Adiciona combustível ao gerador
--- @param generatorData GeneratorData Dados do gerador
--- @param amount number Quantidade de combustível a adicionar
--- @return boolean True se a operação foi bem-sucedida
function LKS_EletricidadeConstrucao.Fuel.Manager.AddFuel(generatorData, amount)
    if amount <= 0 then
        return false
    end
    
    local objetoGerador = getGeneratorFromSquare(generatorData.x, generatorData.y, generatorData.z)
    
    if not objetoGerador then
        return false
    end
    
    local novoCombustivel = objetoGerador:getFuel() + amount
    
    if novoCombustivel > 100 then
        novoCombustivel = 100
    end
    
    objetoGerador:setFuel(novoCombustivel)
    generatorData.fuelAmount = novoCombustivel
    generatorData.lastSyncedFuel = novoCombustivel
    
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Adicionado %.2f de combustível ao gerador %s (total: %.2f)", 
            amount, generatorData.id, novoCombustivel),
        "Fuel"
    )
    
    return true
end

--- Define uma taxa de consumo de combustível personalizada para o gerador
--- @param generatorData GeneratorData Dados do gerador
--- @param fuelRate number|nil Taxa de combustível personalizada (nil para usar padrão)
function LKS_EletricidadeConstrucao.Fuel.Manager.SetCustomFuelRate(generatorData, fuelRate)
    generatorData.customFuelRate = fuelRate
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    if fuelRate then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(
            string.format("Definida taxa de combustível personalizada para %s: %.6f", generatorData.id, fuelRate),
            "Fuel"
        )
    else
        LKS_EletricidadeConstrucao.Core.Logger.Debug(
            string.format("Limpa taxa de combustível personalizada para %s", generatorData.id),
            "Fuel"
        )
    end
end

-- ============================================================================
-- FUNÇÕES AUXILIARES PÚBLICAS
-- ============================================================================

--- Obtém o objeto IsoGenerator a partir de coordenadas no mapa
--- @param x number Coordenada X
--- @param y number Coordenada Y
--- @param z number Coordenada Z
--- @return IsoGenerator|nil Objeto gerador
function getGeneratorFromSquare(x, y, z)
    local quadrado = getSquare(x, y, z)
    
    if not quadrado then
        return nil
    end
    
    -- Verifica por gerador no quadrado
    local objetos = quadrado:getObjects()
    
    if not objetos then
        return nil
    end
    
    for indice = 0, objetos:size() - 1 do
        local objeto = objetos:get(indice)
        if objeto and instanceof(objeto, "IsoGenerator") then
            return objeto
        end
    end
    
    return nil
end

-- ============================================================================
-- DEPURAR / DEBUG
-- ============================================================================

--- Exibe o status do gerenciador de combustível no console
function LKS_EletricidadeConstrucao.Fuel.Manager.PrintStatus()
    LKS_EletricidadeConstrucao.Print("=== Status do Gerenciador de Combustível ===")
    LKS_EletricidadeConstrucao.Print("Inicializado: " .. tostring(_inicializado))
    LKS_EletricidadeConstrucao.Print("Intervalo de Atualização: " .. _intervaloAtualizacao .. "ms")
    
    local geradoresAtivos = LKS_EletricidadeConstrucao.Core.StateManager.GetActiveGenerators()
    LKS_EletricidadeConstrucao.Print("Geradores Ativos: " .. #geradoresAtivos)
    
    for _, dadosGerador in ipairs(geradoresAtivos) do
        local horasRestantes = LKS_EletricidadeConstrucao.Fuel.Manager.GetRemainingHours(dadosGerador)
        LKS_EletricidadeConstrucao.Print(string.format("  %s: %.2f combustível, %.1fh restantes, %.1f%% sobrecarga",
            dadosGerador.id, dadosGerador.fuelAmount, horasRestantes, dadosGerador.strain))
    end
end

-- ============================================================================
-- REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Fuel.Manager", "2.0.0")

return LKS_EletricidadeConstrucao.Fuel.Manager
