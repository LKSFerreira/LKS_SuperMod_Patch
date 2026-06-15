-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Fuel_ChunkTracker.lua
-- LKS_EletricidadeConstrucao V2 - Rastreamento de Carregamento/Descarregamento de Chunks
-- Rastreia o consumo de combustível ao longo do carregamento/descarregamento de chunks
-- Correções: Bug onde geradores consumiam combustível enquanto o chunk estava descarregado
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace existe
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Fuel_ChunkTracker] Namespace LKS_EletricidadeConstrucao não encontrado - pulando carregamento do módulo")
    return
end

-- ============================================================================
-- ESTADO LOCAL
-- ============================================================================

local _temposCarregamentoChunk = {}       -- chaveChunk -> timestamp
local _inicializado = false
local _atualizacoesPredioAgendadas = {}   -- idPredio -> true (evita duplicar atualizações de prédios)
local _chunksProcessados = {}             -- chaveChunk -> true (evita duplicar processamento de chunks)
local _atualizacoesPredioPendentes = {}   -- idPredio -> true (temporizador global de lote)
local _reescaneamentosGeradorPendentes = {} -- idGerador -> {x, y, z} (geradores cujo próprio quadrado precisa de reescaneamento)
local _timerLoteAtivo = false

-- B-106: O GETGLOBAL do Kahlua para `next` pode retornar nil dentro de fechamentos (closures) aninhados.
-- Usamos um auxiliar com escopo de módulo que usa `pairs` diretamente (sempre disponível).
local function tabelaPossuiEntradas(tabela)
    if not tabela then return false end
    for _ in pairs(tabela) do return true end
    return false
end

-- Auxiliar: total de minutos do mundo decorridos no tempo do jogo (espelha a definição em LKS_EletricidadeConstrucao_Fuel_Manager)
local function obterMinutosDoMundo()
    local tempoJogo = getGameTime and getGameTime()
    if tempoJogo then
        local horasMundo = tempoJogo:getWorldAgeHours() or 0
        return horasMundo * 60
    end
    return getTimestampMs() / 60000 -- fallback para tempo real se GameTime não estiver disponível
end

-- Declaração antecipada para que HandleStartupGeneratorRefresh possa chamá-la.
-- O corpo real é atribuído na seção de RESTAURAÇÃO DE DADOS MOD ISO ESTILO V1.
local tentarRestaurarDadosModIso

--- Retorna true apenas quando um quadrado de gerador precisa de uma restauração completa de IsoModData.
--- Um quadrado NÃO precisa de restauração quando seu prédio já está estabelecido no estado
--- (a entrada do prédio existe E possui pelo menos um powerConsumer registrado).
--- Isso evita que tentarRestaurarDadosModIso seja executada de forma redundante em cada
--- retorno de chunk quando Load() já hidratou tudo corretamente. (B-71)
--- @param quadrado IsoGridSquare O quadrado a ser verificado.
--- @return boolean
local function precisaRestaurarIso(quadrado)
    if not quadrado then return false end
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not gerenciadorEstado then return true end
    local objetos = quadrado:getObjects()
    if not objetos then return false end
    for indice = 0, objetos:size() - 1 do
        local objeto = objetos:get(indice)
        if objeto and instanceof(objeto, "IsoGenerator") then
            local dadosModGerador = objeto:getModData()
            local idPredio = dadosModGerador and dadosModGerador.Gen_BuildingPoolID
            if not idPredio then return true end -- sem carimbo do pool → precisa de restauração
            local predio = gerenciadorEstado.GetBuilding(idPredio)
            if not predio then return true end -- prédio ausente do estado → precisa de restauração
            -- Verifica powerConsumers via pairs (seguro para arrays com chaves string do Kahlua)
            local possuiConsumidores = false
            if predio.powerConsumers then
                for _ in pairs(predio.powerConsumers) do possuiConsumidores = true; break end
            end
            return not possuiConsumidores -- só precisa de restauração se os consumidores ainda não foram escaneados
        end
    end
    return false -- sem IsoGenerator neste quadrado
end

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

--- Inicializa o rastreador de chunks
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.Initialize()
    if _inicializado then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("Rastreador de Chunks já inicializado", "Fuel")
        return
    end
    
    -- Registra os manipuladores de eventos para carregamento/descarregamento de quadrados da grade.
    -- Nomes dos eventos confirmados a partir da documentação da API Lua do PZ 42:
    --   LoadGridsquare  - disparado após um novo quadrado ser carregado (parâmetro: IsoGridSquare)
    --   ReuseGridsquare - disparado antes de um quadrado ser descarregado  (parâmetro: IsoGridSquare)
    local eventosCarregamento = { "LoadGridsquare" }
    local eventosDescarregamento = { "ReuseGridsquare" }
    local carregamentoRegistrado, descarregamentoRegistrado = false, false
    for _, nomeEvento in ipairs(eventosCarregamento) do
        if Events[nomeEvento] then
            Events[nomeEvento].Add(LKS_EletricidadeConstrucao.Fuel.ChunkTracker.OnLoadGridsquare)
            LKS_EletricidadeConstrucao.Core.Logger.Info("ChunkTracker: registrado '" .. nomeEvento .. "'", "Fuel")
            carregamentoRegistrado = true
            break
        end
    end
    for _, nomeEvento in ipairs(eventosDescarregamento) do
        if Events[nomeEvento] then
            Events[nomeEvento].Add(LKS_EletricidadeConstrucao.Fuel.ChunkTracker.OnUnloadGridsquare)
            LKS_EletricidadeConstrucao.Core.Logger.Info("ChunkTracker: registrado '" .. nomeEvento .. "'", "Fuel")
            descarregamentoRegistrado = true
            break
        end
    end
    if not carregamentoRegistrado then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("ChunkTracker: evento LoadGridsquare não encontrado - rastreamento de combustível baseado em chunk desativado", "Fuel")
    end
    if not descarregamentoRegistrado then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("ChunkTracker: evento ReuseGridsquare não encontrado - rastreamento de combustível baseado em chunk desativado", "Fuel")
    end
    
    _inicializado = true

    -- No início/recarregamento do jogo, os chunks próximos são carregados durante a tela de carregamento ANTES
    -- do OnGameStart disparar e este manipulador ser registrado. Esse evento LoadGridsquare
    -- nunca são recebidos. Percorremos todos os geradores conhecidos agora e agendamos um
    -- ForceUpdateBuilding para cada um cujo quadrado já está na memória, usando o mesmo
    -- padrão de fechamento autolimpante no estilo V1.
    LKS_EletricidadeConstrucao.Fuel.ChunkTracker.HandleStartupGeneratorRefresh()

    LKS_EletricidadeConstrucao.Core.Logger.Info("Rastreador de Chunks inicializado", "Fuel")
end

--- Verifica se o rastreador de chunks está inicializado
--- @return boolean True se estiver inicializado
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.IsInitialized()
    return _inicializado
end

-- ============================================================================
-- B-104: PURGA DE DUPLICATAS DE PRÉDIOS OBSOLETOS
-- Extraído de HandleStartupGeneratorRefresh para evitar exceder o limite de
-- 200 variáveis locais por função do Kahlua (correção do efeito colateral de B-105).
-- ============================================================================

--- Corrige coordenadas canônicas de prédios e mescla duplicatas obsoletas do tipo bld_def_...
--- Passo 1: corrige entradas bld_X_Y_Z cujas coordenadas x/y/z armazenadas diferem do ID.
--- Passo 2: detecta pares obsoletos+canônicos através da chave connectedGenerators compartilhada,
---          mescla conexões de geradores, atualiza o ModData do IsoObject, remove o obsoleto.
--- @param gerenciadorEstado table Referência ao StateManager
--- @param mapeamentoIds table Tabela [id]=true atualizada in-place (obsoletos removidos, canônicos adicionados)
--- @param atualizacoesPendentes table Tabela [id]=true de prédios que precisam de atualização de interface
local function expurgarDuplicatasPredioObsoletas(gerenciadorEstado, mapeamentoIds, atualizacoesPendentes)
    -- Passo 1: corrige coordenadas de prédios canônicos a partir do ID.
    atualizacoesPendentes = atualizacoesPendentes or {}
    local todosPredios = gerenciadorEstado.GetAllBuildings() or {}
    for idPredio, predio in pairs(todosPredios) do
        local coordX, coordY, coordZStr = string.match(idPredio, "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if coordX then
            local coordXNum, coordYNum, coordZNum = tonumber(coordX), tonumber(coordY), tonumber(coordZStr or "0")
            if predio.x ~= coordXNum or predio.y ~= coordYNum then
                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                    "[ChunkTracker] B-104: corrigindo coordenadas de %s (%s,%s) -> (%d,%d)",
                    idPredio, tostring(predio.x), tostring(predio.y), coordXNum, coordYNum), "Fuel")
                predio.x, predio.y, predio.z = coordXNum, coordYNum, coordZNum
                gerenciadorEstado.MarkDirty()
            end
        end
    end

    -- Passo 2: indexa prédios canônicos por cada chave de gerador que eles referenciam.
    local canonicoPorGerador = {} -- chaveGerador -> idPredioCanonico
    todosPredios = gerenciadorEstado.GetAllBuildings() or {}
    for idPredio, predio in pairs(todosPredios) do
        if string.match(idPredio, "^bld_%-?%d+_%-?%d+_%-?%d+$") and predio.connectedGenerators then
            for _, chaveGerador in pairs(predio.connectedGenerators) do
                canonicoPorGerador[chaveGerador] = idPredio
            end
        end
    end

    -- Passo 2 (continuação): para cada prédio obsoleto, encontra seu parceiro canônico.
    for idPredio, predio in pairs(todosPredios) do
        if not string.match(idPredio, "^bld_%-?%d+_%-?%d+_%-?%d+$") then
            local correspondente = nil
            if predio.connectedGenerators then
                for _, chaveGerador in pairs(predio.connectedGenerators) do
                    if canonicoPorGerador[chaveGerador] then correspondente = canonicoPorGerador[chaveGerador]; break end
                end
            end
            if correspondente then
                -- Mescla connectedGenerators do obsoleto para o canônico.
                local predioCanonico = gerenciadorEstado.GetBuilding(correspondente)
                if predioCanonico and predio.connectedGenerators then
                    predioCanonico.connectedGenerators = predioCanonico.connectedGenerators or {}
                    local conjuntoChaves = {}
                    for _, chaveGerador in pairs(predioCanonico.connectedGenerators) do conjuntoChaves[chaveGerador] = true end
                    for _, chaveGerador in pairs(predio.connectedGenerators) do
                        if not conjuntoChaves[chaveGerador] then
                            table.insert(predioCanonico.connectedGenerators, chaveGerador)
                            conjuntoChaves[chaveGerador] = true
                        end
                    end
                end
                
                -- B-111-consumer-fix: Mescla powerConsumers do obsoleto para o canônico.
                -- O fallback de prédio obsoleto B-111 usa dados temporários do prédio obsoleto, mas quando
                -- Expurgar remove o prédio obsoleto, os consumidores são perdidos se não forem mesclados.
                if predioCanonico and predio.powerConsumers then
                    predioCanonico.powerConsumers = predioCanonico.powerConsumers or {}
                    for chaveConsumidor, dadosConsumidor in pairs(predio.powerConsumers) do
                        if not predioCanonico.powerConsumers[chaveConsumidor] then
                            predioCanonico.powerConsumers[chaveConsumidor] = dadosConsumidor
                        end
                    end
                    -- Recalcula os totais de carga elétrica após a mesclagem
                    local cargaTotal = 0
                    local cargaAquecimento = 0
                    for _, consumidor in pairs(predioCanonico.powerConsumers) do
                        if consumidor.powerDraw then
                            cargaTotal = cargaTotal + consumidor.powerDraw
                            if consumidor.isHeater then
                                cargaAquecimento = cargaAquecimento + consumidor.powerDraw
                            end
                        end
                    end
                    predioCanonico.totalPowerDraw = cargaTotal
                    predioCanonico.heatingPowerDraw = cargaAquecimento
                    -- Fila para atualização de interface para que a janela de informações mostre os consumidores mesclados
                    if atualizacoesPendentes then
                        atualizacoesPendentes[correspondente] = true
                    end
                end
                
                -- B-108: herda as configurações de aquecimento da entrada obsoleta quando o canônico não possui nenhuma.
                -- B-111-heating-fix: Verifica heatingSourceCount em vez de heatingEnabled,
                -- porque o canônico pode ter heatingEnabled=false (padrão do IsoObject)
                -- enquanto o obsoleto tem heatingEnabled=true + heatingSourceCount>0 (GlobalModData).
                -- Prioriza fontes de aquecimento reais sobre os padrões do IsoObject.
                if predioCanonico and predio.heatingSourceCount and predio.heatingSourceCount > 0 then
                    local canonicoSemFontes = not predioCanonico.heatingSourceCount or predioCanonico.heatingSourceCount == 0
                    if canonicoSemFontes then
                        predioCanonico.heatingEnabled = predio.heatingEnabled
                        predioCanonico.heatingSourceCount = predio.heatingSourceCount
                        predioCanonico.heatingTargetTemp = predio.heatingTargetTemp
                    end
                end
                -- Atualiza todos os geradores: reescreve ID obsoleto -> canônico.
                local celula = getCell and getCell()
                for _, dadosGerador in pairs(gerenciadorEstado.GetAllGenerators() or {}) do
                    if dadosGerador.connectedBuildings then
                        local alterado = false
                        for chave, predioId in pairs(dadosGerador.connectedBuildings) do
                            if predioId == idPredio then dadosGerador.connectedBuildings[chave] = correspondente; alterado = true end
                        end
                        if alterado then
                            -- Remove duplicatas de connectedBuildings após substituição.
                            local visualizados, reconstruido = {}, {}
                            for _, predioId in pairs(dadosGerador.connectedBuildings) do
                                if not visualizados[predioId] then visualizados[predioId] = true; table.insert(reconstruido, predioId) end
                            end
                            dadosGerador.connectedBuildings = reconstruido
                            gerenciadorEstado.AddGenerator(dadosGerador)
                            -- Grava o novo ID no IsoObject se o quadrado estiver carregado na memória.
                            if celula and dadosGerador.x and dadosGerador.y and dadosGerador.z then
                                local quadrado = celula:getGridSquare(dadosGerador.x, dadosGerador.y, dadosGerador.z)
                                if quadrado then
                                    local objetos = quadrado:getObjects()
                                    for oi = 0, objetos:size() - 1 do
                                        local objetoGerador = objetos:get(oi)
                                        if objetoGerador and instanceof(objetoGerador, "IsoGenerator") then
                                            local modDataGerador = objetoGerador:getModData()
                                            if modDataGerador and modDataGerador.Gen_BuildingPoolID == idPredio then
                                                modDataGerador.Gen_BuildingPoolID = correspondente
                                                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                                    objetoGerador:transmitModData()
                                                end
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                "[ChunkTracker] B-104: gerador=%s %s -> %s",
                                dadosGerador.id or "?", idPredio, correspondente), "Fuel")
                        end
                    end
                end
                gerenciadorEstado.RemoveBuilding(idPredio)
                gerenciadorEstado.MarkDirty()
                if mapeamentoIds then mapeamentoIds[idPredio] = nil; mapeamentoIds[correspondente] = true end
                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                    "[ChunkTracker] B-104: removido prédio obsoleto %s (mesclado em %s)",
                    idPredio, correspondente), "Fuel")
            end
        end
    end
end

--- Escaneia os geradores do StateManager no início do jogo e enfileira ForceUpdateBuilding
--- para qualquer um cujo quadrado no mapa já esteja carregado na memória.
--- Chamado uma vez a partir de Initialize() para cobrir a lacuna onde LoadGridsquare dispara
--- durante a tela de carregamento antes do nosso manipulador de eventos ser registrado.
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.HandleStartupGeneratorRefresh()
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
    local todosGeradores = gerenciadorEstado.GetAllGenerators()
    if not todosGeradores then return end

    -- Fallback: se nenhum gerador foi persistido (ex: salvamento falhou), reconstrói
    -- as entradas de geradores primeiro a partir do índice global de ModData, e depois
    -- a partir do connectedGenerators de quaisquer prédios conhecidos.
    local vazio = true
    for _ in pairs(todosGeradores) do vazio = false; break end
    if vazio then
        -- Tenta hidratar a partir do índice de geradores do ModData (resiliência estilo V1)
        local restauradoDoIndice = 0
        if gerenciadorEstado.HydrateGeneratorsFromIndex then
            restauradoDoIndice = gerenciadorEstado.HydrateGeneratorsFromIndex()
        end

        -- Atualiza a referência local caso a hidratação tenha populado o estado
        todosGeradores = gerenciadorEstado.GetAllGenerators()
        vazio = true
        for _ in pairs(todosGeradores) do vazio = false; break end

        -- Se ainda estiver vazio, reconstrói as entradas de geradores a partir dos prédios
        local predios = gerenciadorEstado.GetAllBuildings() or {}
        for idPredio, predio in pairs(predios) do
            if predio.connectedGenerators then
                -- connectedGenerators is Kahlua-deserialized (string numeric keys)
                for _, chaveGerador in pairs(predio.connectedGenerators) do
                    local coordX, coordY, coordZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                    if coordX then
                        coordX, coordY, coordZ = tonumber(coordX), tonumber(coordY), tonumber(coordZ)
                        local idGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(coordX, coordY, coordZ)
                        local dadosGerador = gerenciadorEstado.GetGenerator(idGerador)
                        if not dadosGerador then
                            dadosGerador = LKS_EletricidadeConstrucao.Data.Generator.New(getSquare(coordX, coordY, coordZ) or {})
                            dadosGerador.x, dadosGerador.y, dadosGerador.z = coordX, coordY, coordZ
                            dadosGerador.connectedBuildings = { idPredio }
                            gerenciadorEstado.AddGenerator(dadosGerador)
                        else
                            dadosGerador.connectedBuildings = dadosGerador.connectedBuildings or {}
                            local visto = false
                            -- connectedBuildings também pode ter chaves numéricas string do Kahlua
                            for _, existente in pairs(dadosGerador.connectedBuildings) do
                                if existente == idPredio then visto = true; break end
                            end
                            if not visto then table.insert(dadosGerador.connectedBuildings, idPredio) end
                            gerenciadorEstado.AddGenerator(dadosGerador)
                        end
                    end
                end
            end
        end
        todosGeradores = gerenciadorEstado.GetAllGenerators()

        -- Fallback final estilo V1: se TODOS os caminhos de GlobalModData se esgotarem e o estado
        -- ainda estiver vazio, realiza uma varredura espacial dos quadrados já carregados próximos ao jogador.
        -- tentarRestaurarDadosModIso lê Gen_BuildingPoolID diretamente de cada
        -- objeto IsoGenerator, por isso funciona mesmo quando todos os dados de ModData sumiram.
        vazio = true
        for _ in pairs(todosGeradores) do vazio = false; break end
        if vazio then
            LKS_EletricidadeConstrucao.Core.Logger.Info(
                "StartupGeneratorRefresh: todos os caminhos do ModData vazios – executando varredura espacial estilo V1 no objeto Iso",
                "Fuel")
            local jogador = getSpecificPlayer and getSpecificPlayer(0) or (getPlayer and getPlayer())
            if jogador then
                local jogadorX, jogadorY, jogadorZ = math.floor(jogador:getX()), math.floor(jogador:getY()), math.floor(jogador:getZ())
                local celula = getCell()
                if celula then
                    for diferencaX = -40, 40 do
                        for diferencaY = -40, 40 do
                            local quadrado = celula:getGridSquare(jogadorX + diferencaX, jogadorY + diferencaY, jogadorZ)
                            if quadrado then pcall(tentarRestaurarDadosModIso, quadrado) end
                        end
                    end
                end
            end
            todosGeradores = gerenciadorEstado.GetAllGenerators()
        end
    end

    local idsPredios = {}
    local totalEncontrados = 0
    local totalRestaurados = 0

    for _, dadosGerador in pairs(todosGeradores) do
        -- Apenas processa geradores cujo quadrado já está na memória
        local quadrado = getSquare(dadosGerador.x, dadosGerador.y, dadosGerador.z)
        if quadrado then
            totalEncontrados = totalEncontrados + 1
            
            -- CORREÇÃO CRÍTICA: Executa tentarRestaurarDadosModIso para geradores já carregados
            -- para criar entradas de prédios. Na inicialização inicial, o jogador surge no chunk
            -- de modo que LoadGridsquare nunca dispara e os prédios nunca são restaurados.
            -- Isso garante que os prédios existam antes de ForceUpdateBuilding ser chamado.
            local totalAntes = 0
            local predios = gerenciadorEstado.GetAllBuildings() or {}
            for _ in pairs(predios) do totalAntes = totalAntes + 1 end
            
            pcall(tentarRestaurarDadosModIso, quadrado)
            
            local totalDepois = 0
            predios = gerenciadorEstado.GetAllBuildings() or {}
            for _ in pairs(predios) do totalDepois = totalDepois + 1 end
            
            if totalDepois > totalAntes then
                totalRestaurados = totalRestaurados + 1
                LKS_EletricidadeConstrucao.Core.Logger.Debug(
                    string.format("Restaurado prédio para o gerador %s (%d prédios agora no estado)",
                        dadosGerador.id, totalDepois),
                    "Fuel")
            end
            
            -- connectedBuildings é desserializado pelo Kahlua após recarregamento de GlobalModData
            -- (chaves numéricas string) → ipairs não retorna nada. Use pairs.
            for _, idPredio in pairs(dadosGerador.connectedBuildings or {}) do
                idsPredios[idPredio] = true
            end
        end -- fim: if quadrado then
    end -- fim: for _, dadosGerador in pairs(todosGeradores)

    -- ── B-104: Limpeza pós-loop de prédios obsoletos ──────────────────────────
    -- Extraído para expurgarDuplicatasPredioObsoletas() para evitar o limite de 200
    -- variáveis locais do Kahlua (ArrayIndexOutOfBoundsException em LexState.new_localvar:740).
    if gerenciadorEstado.IsStateLoaded and gerenciadorEstado.IsStateLoaded() then
        local atualizacoesPendentes = {} -- Coleta prédios que precisam de atualização de interface
        expurgarDuplicatasPredioObsoletas(gerenciadorEstado, idsPredios, atualizacoesPendentes)
        -- Enfileira para ForceUpdateBuilding mais tarde no temporizador adiado
        for idPredio in pairs(atualizacoesPendentes) do
            _atualizacoesPredioPendentes[idPredio] = true
        end
    end
    -- ────────────────────────────────────────────────────────────────────────

    local _possuiIdsPredio = false
    for _ in pairs(idsPredios) do _possuiIdsPredio = true; break end
    if not _possuiIdsPredio then
        -- Nenhum quadrado de gerador estava carregado no frame 0. No entanto, os geradores ESTÃO no estado
        -- (desserializados do GlobalModData). Seus chunks serão carregados em breve, mas:
        --   (a) OnLoadGridsquare apenas chama tentarRestaurarDadosModIso no PRIMEIRO quadrado
        --       de cada chunk (através do dedup _chunksProcessados), NÃO no quadrado real do gerador –
        --       então geradores em quadrados que não são os primeiros nunca são reescaneados via eventos de chunk.
        --   (b) Mesmo se tentarRestaurarDadosModIso for executado, a otimização de consumidor obsoleto
        --       costumava retornar antes da correção de dados do consumidor abaixo.
        -- Solução: agenda uma varredura adiada de 60 ticks que chama tentarRestaurarDadosModIso
        -- no próprio quadrado de cada gerador assim que o mundo estiver estabelecido.
        local tudoVazio = true
        for _ in pairs(todosGeradores) do tudoVazio = false; break end
        if tudoVazio then
            LKS_EletricidadeConstrucao.Core.Logger.Info(
                "StartupGeneratorRefresh: nenhum gerador no estado – nada a fazer",
                "Fuel")
            return
        end

        -- Antes de desistir dos quadrados descarregados: tenta uma correspondência cruzada de GlobalModData.
        -- Quando Load() tem sucesso (prédios sob a chave canônica bld_X_Y_Z no blob do estado) mas
        -- HydrateGeneratorsFromIndex também foi executado (geradores restaurados com IDs obsoletos bld_def_...
        -- a partir do índice), os prédios existem no estado, mas estão inacessíveis porque o
        -- connectedBuildings do gerador aponta para a chave antiga.
        -- Solução: para cada gerador com um ID de prédio não resolvido, procura em todos os
        -- prédios no estado por um cujo connectedGenerators inclua este gerador.
        -- Isso funciona sem qualquer acesso a objetos Iso e corrige a incompatibilidade imediatamente.
        local referenciasCruzadasCorrigidas = 0
        local todosPrediosEstado = gerenciadorEstado.GetAllBuildings() or {}
        for _, dadosGerador in pairs(todosGeradores) do
            local chaveGenRefCruzada = string.format("%d_%d_%d", dadosGerador.x, dadosGerador.y, dadosGerador.z)
            -- connectedBuildings / connectedGenerators são desserializados pelo Kahlua (chaves numéricas string)
            for indice, idPredio in pairs(dadosGerador.connectedBuildings or {}) do
                if not gerenciadorEstado.GetBuilding(idPredio) then
                    -- Não foi possível encontrar o prédio com o ID armazenado - tenta busca reversa via connectedGenerators
                    for _, predio in pairs(todosPrediosEstado) do
                        if predio.connectedGenerators then
                            for _, chaveGerador in pairs(predio.connectedGenerators) do
                                if chaveGerador == chaveGenRefCruzada then
                                    LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                        "[StartupXref] Remapeado %s.connectedBuildings[%s]: %s -> %s",
                                        dadosGerador.id, tostring(indice), idPredio, predio.id), "Fuel")
                                    dadosGerador.connectedBuildings[indice] = predio.id
                                    gerenciadorEstado.AddGenerator(dadosGerador) -- envia ID corrigido para o índice
                                    referenciasCruzadasCorrigidas = referenciasCruzadasCorrigidas + 1
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        if referenciasCruzadasCorrigidas > 0 then
            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                "[StartupXref] Corrigidas %d referência(s) obsoleta(s) de prédios via referência cruzada", referenciasCruzadasCorrigidas), "Fuel")
        end

        -- Reconstrói idsPredios a partir do estado do gerador (potencialmente corrigido)
        todosGeradores = gerenciadorEstado.GetAllGenerators() or {}

        local totalGens = 0
        for _ in pairs(todosGeradores) do totalGens = totalGens + 1 end
        LKS_EletricidadeConstrucao.Core.Logger.Info(
            string.format("StartupGeneratorRefresh: %d gerador(es) no estado mas nenhum quadrado carregado ainda – agendando reescaneamento adiado no tick 60",
                totalGens),
            "Fuel")
        local ticksAdiados = 60
        local tentativasAdio = 0
        local MAX_TENTATIVAS_ADIO = 5
        local funcaoAdiada
        funcaoAdiada = function()
            ticksAdiados = ticksAdiados - 1
            if ticksAdiados > 0 then return end
            Events.OnTick.Remove(funcaoAdiada)
            local todosGens = gerenciadorEstado.GetAllGenerators() or {}
            local escaneados = 0
            for _, dadosGerador in pairs(todosGens) do
                local quadradoGerador = getSquare(dadosGerador.x, dadosGerador.y, dadosGerador.z)
                if quadradoGerador then
                    pcall(tentarRestaurarDadosModIso, quadradoGerador)
                    escaneados = escaneados + 1
                end
            end
            LKS_EletricidadeConstrucao.Core.Logger.Info(
                string.format("StartupGeneratorRefresh (adiado): reescaneados %d quadrado(s) de geradores", escaneados),
                "Fuel")
            -- Se ainda nenhum quadrado foi carregado, tenta novamente após mais 120 ticks (até MAX_TENTATIVAS_ADIO)
            if escaneados == 0 and tentativasAdio < MAX_TENTATIVAS_ADIO then
                tentativasAdio = tentativasAdio + 1
                ticksAdiados = 120
                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                    "StartupGeneratorRefresh (adiado): nenhum quadrado ainda, tentativa %d/%d em 120 ticks",
                    tentativasAdio, MAX_TENTATIVAS_ADIO), "Fuel")
                Events.OnTick.Add(funcaoAdiada)
                return
            end
            -- Fase 2: ForceUpdate em todos os prédios conhecidos atualmente no estado.
            -- Quando todos os geradores ainda estão fora do chunk (escaneados == 0), _state.buildings está
            -- vazio e isso é uma operação sem efeito; os prédios serão criados por tentarRestaurarDadosModIso
            -- no momento em que o chunk do jogador carregar. Quando alguns geradores foram escaneados
            -- (inicialização parcial em chunk), isso atualiza todos os prédios conhecidos em uma única passagem.
            -- O uso de ForceUpdate() (global) em vez de ForceUpdateBuilding(id) por gerador
            -- evita avisos de "Prédio não encontrado" quando connectedBuildings ainda possui um
            -- ID obsoleto bld_def_... de um salvamento anterior à migração (caso de reinicialização fora do chunk).
            local Distribuidor = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
            if Distribuidor and Distribuidor.ForceUpdate then
                Distribuidor.ForceUpdate()
                local totalPredios2 = 0
                local todosPredios2 = gerenciadorEstado.GetAllBuildings() or {}
                for _ in pairs(todosPredios2) do totalPredios2 = totalPredios2 + 1 end
                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("StartupGeneratorRefresh (adiado): ForceUpdate chamado (%d prédio(s) no estado)",
                        totalPredios2),
                    "Fuel")
            end
        end
        Events.OnTick.Add(funcaoAdiada)
        return
    end

    local totalPredios = 0
    for _ in pairs(idsPredios) do totalPredios = totalPredios + 1 end
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("StartupGeneratorRefresh: %d geradores pré-carregados encontrados, %d prédios restaurados, agendando atualização para %d prédios",
            totalEncontrados, totalRestaurados, totalPredios),
        "Fuel")

    -- Marca todos os prédios como agendados para evitar que ProcessChunkGenerators
    -- duplique a atualização de inicialização
    for idPredio in pairs(idsPredios) do
        _atualizacoesPredioAgendadas[idPredio] = true
    end

    -- Fechamento autolimpante estilo V1:
    --   Fase 1 (30 ticks) – reescaneia qualquer prédio que retornou com 0 consumidores
    --                       (os quadrados do mundo agora estão carregados; a varredura imediata no frame 0
    --                        não encontrou quase nenhum bloco porque o mundo ainda não estava estabelecido)
    --   Fase 2 (30+1 ticks) – chama ForceUpdateBuilding para que a distribuição de energia reflita
    --                         as listas de consumidores recém-populadas
    local ticksRestantes = 30
    local fase2Concluida = false
    local funcaoTimer
    funcaoTimer = function()
        ticksRestantes = ticksRestantes - 1
        if ticksRestantes > 0 then return end

        if not fase2Concluida then
            -- ---- Fase 1: reescaneamento de consumidor adiado ----------------------
            -- Prédios restaurados no frame 0 (varredura espacial estilo V1 OU GlobalModData)
            -- podem ter 0 ou muito poucos consumidores porque os quadrados do mundo não estavam
            -- carregados ainda. Agora que estamos a ~30 ticks, o mundo está estabelecido, então
            -- reexecuta ScanBuilding para qualquer prédio com 0 consumidores.
            local Escaneador = LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner
            if Escaneador and Escaneador.ScanBuilding then
                for idPredio in pairs(idsPredios) do
                    local predio = gerenciadorEstado.GetBuilding(idPredio)
                    if predio and (not predio.powerConsumers or LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(predio.powerConsumers)) then
                        -- Deriva as coordenadas do interruptor de luz.
                        -- Para IDs canônicos bld_X_Y_Z, sempre decodifica a partir do próprio ID:
                        -- as coordenadas x/y/z armazenadas podem ser de geradores obsoletos vindas de um
                        -- bloco pendente antigo (B-104), colocando a varredura fora do prédio.
                        local interruptorX, interruptorY, interruptorZ = predio.x, predio.y, predio.z
                        local coordX, coordY, coordZStr = string.match(idPredio, "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        if coordX then interruptorX, interruptorY, interruptorZ = tonumber(coordX), tonumber(coordY), tonumber(coordZStr or "0") end
                        if interruptorX and interruptorY then
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                "[ChunkTracker] StartupRescan: prédio %s possui 0 consumidores, reescaneando a partir de (%d,%d,%d)",
                                idPredio, interruptorX, interruptorY, interruptorZ or 0), "Fuel")
                            pcall(function()
                                Escaneador.ScanBuilding(interruptorX, interruptorY, interruptorZ or 0, idPredio)
                            end)
                            predio = gerenciadorEstado.GetBuilding(idPredio) or predio
                            local totalConsumidoresDepois = 0
                            if predio.powerConsumers then
                                for _ in pairs(predio.powerConsumers) do totalConsumidoresDepois = totalConsumidoresDepois + 1 end
                            end
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                "[ChunkTracker] StartupRescan: %s agora possui %d consumidores",
                                idPredio, totalConsumidoresDepois), "Fuel")
                        end
                    end
                end
            end
            -- Prepara Fase 2 no próximo tick
            fase2Concluida = true
            ticksRestantes = 1
            return
        end

        -- ---- Fase 2: ForceUpdateBuilding ------------------------------------------
        Events.OnTick.Remove(funcaoTimer)

        local Distribuidor = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
        if Distribuidor and Distribuidor.ForceUpdateBuilding then
            for idPredio in pairs(idsPredios) do
                pcall(Distribuidor.ForceUpdateBuilding, idPredio)
            end
        end

        -- Libera todos os agendamentos após a conclusão da inicialização
        for idPredio in pairs(idsPredios) do
            _atualizacoesPredioAgendadas[idPredio] = nil
        end

        LKS_EletricidadeConstrucao.Core.Logger.Info(
            "StartupGeneratorRefresh: ForceUpdateBuilding completo para " .. totalPredios .. " prédio(s)",
            "Fuel")
    end
    Events.OnTick.Add(funcaoTimer)
end

-- ============================================================================
-- RESTAURAÇÃO DE DADOS MOD ISO ESTILO V1
-- ============================================================================

--- Estilo V1: escaneia um único quadrado da grade em busca de IsoGenerators cujo Gen_BuildingPoolID
--- está definido, e reconstrói as entradas do StateManager a partir do seu ModData se estiverem ausentes.
--- OTIMIZADO: Pula a varredura completa do prédio se o gerador já possuir conexões válidas.
--- @param quadrado IsoGridSquare O quadrado da grade a ser escaneado.
tentarRestaurarDadosModIso = function(quadrado)
    if not quadrado then return end
    local objetos = quadrado:getObjects()
    if not objetos then return end

    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not gerenciadorEstado then return end

    for indice = 0, objetos:size() - 1 do
        local objeto = objetos:get(indice)
        if objeto and instanceof(objeto, "IsoGenerator") then
            local modDataObj = objeto:getModData()
            if modDataObj and modDataObj.Gen_BuildingPoolID then
                -- ----------------------------------------------------------------
                -- ISOLAMENTO DE SALVAMENTO CRUZADO (CROSS-SAVE): valida LKS_EletricidadeConstrucao_WorldId
                -- antes de confiar em qualquer dado de pool gravado neste objeto IsoGenerator.
                -- Se o ID do mundo não corresponder ao salvamento atual, estes dados pertencem
                -- a outro salvamento e devem ser limpos antes de poluir o estado de execução.
                -- ----------------------------------------------------------------
                local idMundoAtual = gerenciadorEstado.GetCurrentWorldId and gerenciadorEstado.GetCurrentWorldId()
                if idMundoAtual and idMundoAtual ~= "unknown" and modDataObj.LKS_EletricidadeConstrucao_WorldId
                    and modDataObj.LKS_EletricidadeConstrucao_WorldId ~= "unknown" and modDataObj.LKS_EletricidadeConstrucao_WorldId ~= idMundoAtual then
                    LKS_EletricidadeConstrucao.Core.Logger.Warn(string.format(
                        "[ChunkTracker] ModData do gerador obsoleto detectado (mundo armazenado=%s, atual=%s) - limpando",
                        modDataObj.LKS_EletricidadeConstrucao_WorldId, idMundoAtual), "Fuel")
                    -- Limpa todas as chaves de pool do LKS_EletricidadeConstrucao para que este gerador comece do zero no novo salvamento
                    modDataObj.Gen_BuildingPoolID = nil
                    modDataObj.LKS_EletricidadeConstrucao_WorldId = nil
                    modDataObj.LKS_EletricidadeConstrucao_PoolData = nil
                    modDataObj.Gen_Stats_Consumers = nil
                    modDataObj.Gen_Stats_ActiveConsumers = nil
                    modDataObj.Gen_Stats_Lights = nil
                    modDataObj.Gen_Stats_ActiveLights = nil
                    modDataObj.Gen_Stats_Lamps = nil
                    modDataObj.Gen_Stats_ActiveLamps = nil
                    modDataObj.Gen_Stats_Appliances = nil
                    modDataObj.Gen_Stats_ActiveAppliances = nil
                    modDataObj.Gen_Stats_PowerDraw = nil
                    modDataObj.Gen_Stats_Strain = nil
                    modDataObj.Gen_Stats_FuelRateLph = nil
                    modDataObj.Gen_Stats_Powered = nil
                    -- O estado de aquecimento também deve ser limpo na detecção de dados obsoletos de salvamento cruzado
                    -- para que o gerador não carregue configurações de aquecimento antigas para o novo salvamento.
                    modDataObj.HeatingEnabled = nil
                    modDataObj.HeatingPositions = nil
                    modDataObj.HeatingTargetTemp = nil
                    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                        objeto:transmitModData()
                    end
                    -- Pula este gerador - dados de pool inválidos
                else

                if idMundoAtual and idMundoAtual ~= "unknown" and modDataObj.LKS_EletricidadeConstrucao_WorldId ~= idMundoAtual then
                    modDataObj.LKS_EletricidadeConstrucao_WorldId = idMundoAtual
                    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                        objeto:transmitModData()
                    end
                end

                local coordX = quadrado:getX()
                local coordY = quadrado:getY()
                local coordZ = quadrado:getZ()
                local idGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(coordX, coordY, coordZ)

                local dadosGerador = gerenciadorEstado.GetGenerator(idGerador)
                -- Opção A (B-99): powerConsumers nunca são salvos no GlobalModData, por isso
                -- bldData.powerConsumers sempre está vazio na inicialização. needScan (abaixo)
                -- é, portanto, true no primeiro carregamento de chunk de cada sessão.
                -- Dentro de uma sessão, o curto-circuito (consumidores presentes → pula) está correto
                -- e evita reescaneamentos redundantes em visitas repetidas ao mesmo chunk.

                local idPoolPredio = modDataObj.Gen_BuildingPoolID
                -- B-111: Salva o ID original do prédio ANTES que qualquer migração/recuperação o modifique.
                -- Isso permite que a busca reversa por ID de prédio obsoleto encontre dados sob o ID antigo.
                local idPredioOriginal = idPoolPredio

                -- ── MIGRAÇÃO DE ID ───────────────────────────────────────────────────
                -- Salvamentos legados da V1 armazenavam prédios construídos pelo jogador sob um ID `bld_def_XXXXX`
                -- herdado da definição vanilla de IsoBuilding em vez das coordenadas reais do interruptor de luz.
                -- O formato canônico da V2 é `bld_X_Y_Z`.
                -- Quando LKS_EletricidadeConstrucao_PoolData carrega a posição do interruptor de luz, reconstrói o
                -- ID correto para que a verificação `isPlayerBuilt` do BorderDetector, o
                -- RadiusFallback e todas as buscas no GlobalModData funcionem corretamente.
                if modDataObj.LKS_EletricidadeConstrucao_PoolData and modDataObj.LKS_EletricidadeConstrucao_PoolData.x and modDataObj.LKS_EletricidadeConstrucao_PoolData.y
                        and not string.match(idPoolPredio, "^bld_%-?%d+_%-?%d+_%-?%d+$") then
                    local switchX = modDataObj.LKS_EletricidadeConstrucao_PoolData.x
                    local switchY = modDataObj.LKS_EletricidadeConstrucao_PoolData.y
                    local switchZ = modDataObj.LKS_EletricidadeConstrucao_PoolData.z or coordZ
                    local idCanonico = LKS_EletricidadeConstrucao.Data.Building.MakeId(switchX, switchY, switchZ)
                    LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                        "[ChunkTracker] Migração de ID: %s → %s (construído por jogador, a partir de LKS_EletricidadeConstrucao_PoolData)",
                        idPoolPredio, idCanonico), "Fuel")
                    -- Migra a entrada existente do GlobalModData (se houver) para a chave canônica
                    local entradaAntiga = gerenciadorEstado.GetBuilding(idPoolPredio)
                    if entradaAntiga then
                        entradaAntiga.id = idCanonico
                        gerenciadorEstado.RemoveBuilding(idPoolPredio)
                        gerenciadorEstado.AddBuilding(entradaAntiga)
                    end
                    -- Persiste o ID canônico no IsoObject para que inicializações futuras pulem a migração
                    modDataObj.Gen_BuildingPoolID = idCanonico
                    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                        objeto:transmitModData()
                    end
                    -- Corrige qualquer lista connectedBuildings de geradores existentes que ainda usem o ID antigo
                    if dadosGerador and dadosGerador.connectedBuildings then
                        -- connectedBuildings is desserializado pelo Kahlua (chaves numéricas string); use pairs
                        for chave, predioId in pairs(dadosGerador.connectedBuildings) do
                            if predioId == idPoolPredio then
                                dadosGerador.connectedBuildings[chave] = idCanonico
                            end
                        end
                    end
                    idPoolPredio = idCanonico
                end
                -- ─────────────────────────────────────────────────────────────────────

                -- ── BUSCA CANÔNICA SECUNDÁRIA ────────────────────────────────────────
                -- B-109: Se a migração acima NÃO foi executada (LKS_EletricidadeConstrucao_PoolData é nulo) e
                -- idPoolPredio ainda for um ID legado bld_def_..., tenta recuperar
                -- o ID canônico bld_X_Y_Z a partir de:
                --   1. dadosGerador.connectedBuildings atual (gravado por Expurgar/Referência Cruzada Adiada anterior)
                --   2. Prédio obsoleto existente no StateManager (se já tiver sido criado
                --      por outro gerador em um chunk diferente e migrado posteriormente)
                --   3. QUALQUER prédio canônico no estado que compartilhe geradores com o
                --      mesmo idPoolPredio obsoleto (detecção de duplicatas entre chunks)
                --
                -- Isso evita que pools de geradores que abrangem múltiplos chunks se dividam quando
                -- os chunks são carregados em ordens diferentes (o dono do pool carrega depois dos não-donos,
                -- fazendo com que os não-donos criem prédios obsoletos antes que o dono migre para o canônico).
                if not string.match(idPoolPredio, "^bld_%-?%d+_%-?%d+_%-?%d+$") then
                    local canonicoEncontrado = nil
                    -- Tentativa 1: Verifica os prédios conectados rastreados no estado do gerador
                    if dadosGerador and dadosGerador.connectedBuildings then
                        for _, idPredioExistente in pairs(dadosGerador.connectedBuildings) do
                            if string.match(idPredioExistente, "^bld_%-?%d+_%-?%d+_%-?%d+$")
                                    and gerenciadorEstado.GetBuilding(idPredioExistente) then
                                canonicoEncontrado = idPredioExistente
                                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                    "[ChunkTracker] B-109 Recuperação Canônica: %s → %s (a partir de dadosGerador.connectedBuildings)",
                                    idPoolPredio, idPredioExistente), "Fuel")
                                break
                            end
                        end
                    end
                    -- Tentativa 2: Verifica se o prédio obsoleto já existe e foi migrado para o canônico
                    if not canonicoEncontrado then
                        local entradaObsoleta = gerenciadorEstado.GetBuilding(idPoolPredio)
                        if entradaObsoleta and entradaObsoleta.id ~= idPoolPredio
                                and string.match(entradaObsoleta.id, "^bld_%-?%d+_%-?%d+_%-?%d+$") then
                            -- A entrada obsoleta foi renomeada para canônica por migração de ID anterior
                            canonicoEncontrado = entradaObsoleta.id
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                "[ChunkTracker] B-109 Recuperação Canônica: %s → %s (entrada obsoleta foi migrada)",
                                idPoolPredio, canonicoEncontrado), "Fuel")
                        end
                    end
                    -- Tentativa 3: Procura em todos os prédios canônicos por um que contenha OUTROS geradores
                    -- com o MESMO idPoolPredio obsoleto. Isso lida com divisões entre chunks onde o
                    -- dono do pool do Chunk A migrou bld_def_X → bld_canonico, e os não-donos do
                    -- Chunk B ainda não migraram, mas devem se conectar ao mesmo prédio canônico.
                    if not canonicoEncontrado then
                        local todosGens = gerenciadorEstado.GetAllGenerators() or {}
                        local chavesGenComMesmoIdObsoleto = {} -- [chaveGerador] = true para geradores que compartilham este ID obsoleto
                        for _, dadosGen in pairs(todosGens) do
                            if dadosGen.connectedBuildings then
                                for _, predioId in pairs(dadosGen.connectedBuildings) do
                                    if predioId == idPoolPredio then
                                        local chaveGerador2 = dadosGen.id and string.match(dadosGen.id, "gen_([%d_]+)$")
                                        if chaveGerador2 then chavesGenComMesmoIdObsoleto[chaveGerador2] = true end
                                    end
                                end
                            end
                        end
                        -- Agora procura em todos os prédios canônicos por um que possua qualquer um desses geradores
                        local todosPredios = gerenciadorEstado.GetAllBuildings() or {}
                        for idPredioC, predioC in pairs(todosPredios) do
                            if string.match(idPredioC, "^bld_%-?%d+_%-?%d+_%-?%d+$") and predioC.connectedGenerators then
                                for _, chaveGenC in pairs(predioC.connectedGenerators) do
                                    if chavesGenComMesmoIdObsoleto[chaveGenC] then
                                        canonicoEncontrado = idPredioC
                                        LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                            "[ChunkTracker] B-109 Recuperação Canônica: %s → %s (correspondência entre chunks via gerador %s)",
                                            idPoolPredio, idPredioC, chaveGenC), "Fuel")
                                        break
                                    end
                                end
                                if canonicoEncontrado then break end
                            end
                        end
                    end
                    -- Aplica o ID canônico recuperado
                    if canonicoEncontrado then
                        modDataObj.Gen_BuildingPoolID = canonicoEncontrado
                        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                            objeto:transmitModData()
                        end
                        idPoolPredio = canonicoEncontrado
                    end
                end
                -- ─────────────────────────────────────────────────────────────────────

                local chaveGerador = string.format("%d_%d_%d", coordX, coordY, coordZ)

                -- Cria / atualiza a entrada do gerador no StateManager
                if not dadosGerador then
                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                        string.format("[ChunkTracker] Restauração V1: %s → pool %s ausente do estado, reconstruindo", idGerador, idPoolPredio),
                        "Fuel")

                    local sucesso, dadosNovos = pcall(LKS_EletricidadeConstrucao.Data.Generator.New, objeto)
                    if sucesso and dadosNovos then
                        dadosGerador = dadosNovos
                    else
                        dadosGerador = {
                            id = idGerador, x = coordX, y = coordY, z = coordZ,
                            activated = objeto:isActivated(),
                            fuelAmount = objeto:getFuel() or 0,
                            condition = objeto:getCondition() or 100,
                            chunkKey = LKS_EletricidadeConstrucao.Utils.Geometry.GetChunkKey(coordX, coordY),
                            lastUpdateTime = getTimestampMs(),
                        }
                    end
                    dadosGerador.connectedBuildings = { idPoolPredio }
                    gerenciadorEstado.AddGenerator(dadosGerador)
                else
                    -- Gerador já sendo rastreado – apenas garante que o vínculo reverso ao prédio esteja presente
                    dadosGerador.connectedBuildings = dadosGerador.connectedBuildings or {}
                    local visto = false
                    -- NOTA: pairs() é obrigatório aqui, não ipairs(). Após a desserialização de
                    -- GlobalModData no Kahlua (PZ's Lua VM) tabelas do tipo array podem conter
                    -- chaves numéricas string ("1", "2", ...) em vez de chaves inteiras. O ipairs()
                    -- para no primeiro buraco / chave string e não retornaria nada,
                    -- deixando visto=false em cada retorno de chunk e inserindo duplicatas. (B-71)
                    for _, predioId in pairs(dadosGerador.connectedBuildings) do
                        if predioId == idPoolPredio then visto = true; break end
                    end
                    if not visto then
                        table.insert(dadosGerador.connectedBuildings, idPoolPredio)
                    end
                    -- SEMPRE envia dadosGerador de volta ao índice de geradores para que a lista
                    -- connectedBuildings pós-migração-B-49 (agora canônica bld_X_Y_Z) seja persistida.
                    -- Anteriormente, apenas MarkDirty() era chamado aqui, o que atualizava o blob principal
                    -- de estado mas deixava o índice de geradores obsoleto.
                    -- Na inicialização seguinte, Load()+HydrateGeneratorsFromIndex restauraria geradores
                    -- com os IDs bld_def_... ANTIGOS, causando falhas de "Prédio não encontrado"
                    -- para cada chamada do ForceUpdateBuilding.
                    gerenciadorEstado.AddGenerator(dadosGerador)
                end

                -- ----------------------------------------------------------
                -- Executa o mesmo fluxo de escaneamento de prédios que ConnectBuilding
                -- para que powerConsumers seja populado com dados reais, não um esboço vazio.
                -- ----------------------------------------------------------
                local Escaneador = LKS_EletricidadeConstrucao.Building
                                 and LKS_EletricidadeConstrucao.Building.Scanner
                -- B-111: Após a recuperação de ID B-109, o prédio ainda pode existir sob o ID
                -- OBSOLETO (a purga B-107 ainda não foi executada). Verifica os IDs canônico e obsoleto
                -- para evitar criar um esboço vazio quando dados válidos já existem sob o ID antigo.
                local dadosPredio = gerenciadorEstado.GetBuilding(idPoolPredio)
                
                -- Se o canônico não for encontrado E recuperamos um ID diferente (B-109 alterou-o),
                -- verifica o ID obsoleto ORIGINAL a partir do IsoObject antes de criar um esboço vazio.
                if not dadosPredio and idPredioOriginal and idPredioOriginal ~= idPoolPredio then
                    local predioObsoleto = gerenciadorEstado.GetBuilding(idPredioOriginal)
                    if predioObsoleto and predioObsoleto.powerConsumers and not LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(predioObsoleto.powerConsumers) then
                        -- B-111-consumer-fix: Cria o prédio canônico imediatamente como cópia do obsoleto.
                        -- Não referencie apenas o obsoleto, pois a purga irá deletá-lo mais tarde e
                        -- os geradores ficariam vinculados a um prédio deletado. Copie os dados agora.
                        -- CRÍTICO: Cópia profunda (deep copy) de powerConsumers, não apenas referência!
                        local consumidoresCopiados = {}
                        for chaveConsumidor, dadosConsumidor in pairs(predioObsoleto.powerConsumers) do
                            consumidoresCopiados[chaveConsumidor] = dadosConsumidor
                        end
                        
                        dadosPredio = {
                            id = idPoolPredio, -- Usa ID canônico
                            x = predioObsoleto.x,
                            y = predioObsoleto.y,
                            z = predioObsoleto.z,
                            connectedGenerators = {}, -- Será populado abaixo
                            isPowered = predioObsoleto.isPowered,
                            powerConsumers = consumidoresCopiados, -- Cópia profunda
                            totalPowerDraw = predioObsoleto.totalPowerDraw,
                            heatingPowerDraw = predioObsoleto.heatingPowerDraw,
                            heatingEnabled = predioObsoleto.heatingEnabled,
                            heatingSourceCount = predioObsoleto.heatingSourceCount,
                            heatingTargetTemp = predioObsoleto.heatingTargetTemp,
                        }
                        gerenciadorEstado.AddBuilding(dadosPredio)
                        _atualizacoesPredioPendentes[idPoolPredio] = true -- Fila para atualização de interface
                        local totalConsumidoresAntigos = 0
                        if predioObsoleto.powerConsumers then
                            for _ in pairs(predioObsoleto.powerConsumers) do totalConsumidoresAntes = totalConsumidoresAntes + 1 end
                        end
                        LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                            "[ChunkTracker] B-111: Criado canônico %s com %d consumidores a partir do obsoleto %s",
                            idPoolPredio, totalConsumidoresAntigos, idPredioOriginal), "Fuel")
                    end
                end
                
                local precisaEscanear = not dadosPredio
                              or not dadosPredio.powerConsumers
                              or LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(dadosPredio.powerConsumers)

                -- ── GUARDA DE VARREDURA EM ESTADO PENDENTE ───────────────────────────
                -- Quando ConfirmAndLoadState() ainda não foi executado (estado ainda "pendente"),
                -- os quadrados do mundo podem não estar todos estabelecidos (servidor não totalmente iniciado,
                -- alguns chunks ainda carregando). Executar ScanBuilding agora poderia produzir uma contagem
                -- parcial de consumidores para prédios que se estendem por múltiplos chunks.
                -- Correção: cria um esboço minimalista; ConfirmAndLoadState() chama
                -- HandleStartupGeneratorRefresh() após o carregamento, que reentra neste caminho
                -- com estado = "carregado" e precisaEscanear = true (Opção A / B-99:
                -- powerConsumers nunca são salvos, fazendo com que o prédio sempre comece vazio),
                -- disparando uma varredura completa assim que o mundo estiver estável.
                if precisaEscanear and gerenciadorEstado.IsStateLoaded and not gerenciadorEstado.IsStateLoaded() then
                    LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                        "[ChunkTracker] Estado pendente – adiando varredura para %s (ConfirmAndLoadState fornecerá os dados completos)",
                        idPoolPredio), "Fuel")
                    if not dadosPredio then
                        -- B-104: Decodifica a origem do prédio a partir do ID canônico em vez de
                        -- usar as coordenadas do gerador. Os quadrados dos geradores ficam fora das paredes
                        -- do prédio, então escanear a partir de gx/gy nunca encontra um interruptor de luz.
                        local coordBX, coordBY, coordBZStr = string.match(idPoolPredio, "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        dadosPredio = {
                            id = idPoolPredio,
                            x = coordBX and tonumber(coordBX) or coordX,
                            y = coordBY and tonumber(coordBY) or coordY,
                            z = coordBZStr and tonumber(coordBZStr) or coordZ,
                            connectedGenerators = {},
                            isPowered = false,
                            powerConsumers = {},
                            totalPowerDraw = 0,
                            heatingPowerDraw = 0,
                        }
                        gerenciadorEstado.AddBuilding(dadosPredio)
                    end
                    precisaEscanear = false -- adia para o carregamento do GlobalModData
                end
                -- ─────────────────────────────────────────────────────────────────────

                if precisaEscanear and Escaneador and Escaneador.ScanBuilding then
                    -- Encontra um quadrado de prédio próximo (o gerador fica fora das paredes)
                    local quadradoPredio = nil
                    if quadrado:getBuilding() then
                        quadradoPredio = quadrado
                    else
                        local direcoes = {
                            IsoDirections.N, IsoDirections.S, IsoDirections.E, IsoDirections.W,
                            IsoDirections.NE, IsoDirections.NW, IsoDirections.SE, IsoDirections.SW,
                        }
                        for _, direcao in ipairs(direcoes) do
                            local adjacente = quadrado:getAdjacentSquare(direcao)
                            if adjacente and adjacente:getBuilding() then quadradoPredio = adjacente; break end
                        end
                    end

                    if quadradoPredio then
                        local objetoPredio = quadradoPredio:getBuilding()
                        local definicaoPredio = objetoPredio and objetoPredio.getDef and objetoPredio:getDef()
                        local salas = definicaoPredio and definicaoPredio.getRooms and definicaoPredio:getRooms()
                        local switchX, switchY, switchZ

                        -- Procura interruptores de luz nas salas (idêntico ao ConnectBuilding)
                        if salas then
                            for ri = 0, salas:size() - 1 do
                                local sala = salas:get(ri)
                                if sala and not switchX then
                                    for rx = sala:getX(), sala:getX2() do
                                        for ry = sala:getY(), sala:getY2() do
                                            local quadradoSala = getCell():getGridSquare(rx, ry, coordZ)
                                            if quadradoSala then
                                                local objetosSala = quadradoSala:getObjects()
                                                for oi = 0, objetosSala:size() - 1 do
                                                    local objSala = objetosSala:get(oi)
                                                    if objSala and instanceof(objSala, "IsoLightSwitch") then
                                                        switchX, switchY, switchZ = rx, ry, coordZ
                                                        break
                                                    end
                                                end
                                            end
                                            if switchX then break end
                                        end
                                        if switchX then break end
                                    end
                                end
                                if switchX then break end
                            end
                        end

                        if switchX then
                            -- ── MIGRAÇÃO DE ID CANÔNICO A PARTIR DO INTERRUPTOR ──
                            -- Apenas migra IDs obsoletos (bld_def_... ou outros formatos legados).
                            -- Se idPoolPredio já for canônico (bld_X_Y_Z), NÃO confie no switchX da varredura
                            -- de salas: um gerador posicionado entre dois prédios pode encontrar o interruptor
                            -- do prédio adjacente primeiro, produzindo um idCanonicoDerivado incorreto que
                            -- sobrescreveria o ID correto gravado. Para IDs canônicos, força switchX/Y/Z com as
                            -- coordenadas decodificadas do próprio ID para que a varredura atinja o prédio
                            -- correto independentemente de qual quadrado adjacente o PZ retorne primeiro.
                            local ehIdObsoleto = not string.match(idPoolPredio, "^bld_%-?%d+_%-?%d+_%-?%d+$")
                            if not ehIdObsoleto then
                                -- Já é canônico – reancora switchX/Y/Z a partir do ID
                                local bx, by, bz = string.match(idPoolPredio, "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                                if bx then
                                    switchX, switchY, switchZ = tonumber(bx), tonumber(by), tonumber(bz)
                                end
                            end
                            local idCanonicoDerivado = LKS_EletricidadeConstrucao.Data.Building.MakeId(switchX, switchY, switchZ)
                            if ehIdObsoleto and idCanonicoDerivado ~= idPoolPredio then
                                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                    "[ChunkTracker] Migração LS: gerador=%s obsoleto=%s → canônico=%s",
                                    idGerador, idPoolPredio, idCanonicoDerivado), "Fuel")

                                -- Grava o ID canônico no IsoObject
                                modDataObj.Gen_BuildingPoolID = idCanonicoDerivado
                                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                    objeto:transmitModData()
                                end

                                -- Update dadosGerador.connectedBuildings
                                if dadosGerador and dadosGerador.connectedBuildings then
                                    for chave, predioId in pairs(dadosGerador.connectedBuildings) do
                                        if predioId == idPoolPredio then
                                            dadosGerador.connectedBuildings[chave] = idCanonicoDerivado
                                        end
                                    end
                                    gerenciadorEstado.AddGenerator(dadosGerador)
                                end

                                -- Transfere as configurações de aquecimento da entrada obsoleta para a canônica
                                -- (se o canônico não as possuir e o obsoleto sim) para que a próxima sincronização
                                -- de aquecimento encontre os dados corretos.
                                -- B-111-heating-fix: Verifica heatingSourceCount em vez de heatingEnabled,
                                -- porque o canônico pode ter heatingEnabled=false (padrão do IsoObject)
                                -- enquanto o obsoleto tem heatingEnabled=true + heatingSourceCount>0 (GlobalModData).
                                local entradaObsoleta = gerenciadorEstado.GetBuilding(idPoolPredio)
                                local entradaCanonica = gerenciadorEstado.GetBuilding(idCanonicoDerivado)
                                if entradaObsoleta and entradaCanonica then
                                    local canonicoSemFontes = not entradaCanonica.heatingSourceCount or entradaCanonica.heatingSourceCount == 0
                                    local obsoletoComFontes = entradaObsoleta.heatingSourceCount and entradaObsoleta.heatingSourceCount > 0
                                    if canonicoSemFontes and obsoletoComFontes then
                                        entradaCanonica.heatingEnabled = entradaObsoleta.heatingEnabled
                                        entradaCanonica.heatingSourceCount = entradaObsoleta.heatingSourceCount
                                        entradaCanonica.heatingTargetTemp = entradaObsoleta.heatingTargetTemp
                                    end
                                    -- Move connectedGenerators do obsoleto para o canônico
                                    if entradaObsoleta.connectedGenerators then
                                        entradaCanonica.connectedGenerators = entradaCanonica.connectedGenerators or {}
                                        for _, chaveGerador in pairs(entradaObsoleta.connectedGenerators) do
                                            local existe = false
                                            for _, chaveExistente in pairs(entradaCanonica.connectedGenerators) do
                                                if chaveExistente == chaveGerador then existe = true; break end
                                            end
                                            if not existe then
                                                table.insert(entradaCanonica.connectedGenerators, chaveGerador)
                                            end
                                        end
                                    end
                                    -- B-111-consumer-fix: Mescla powerConsumers do obsoleto para o canônico
                                    if entradaObsoleta.powerConsumers then
                                        entradaCanonica.powerConsumers = entradaCanonica.powerConsumers or {}
                                        for chaveConsumidor, dadosConsumidor in pairs(entradaObsoleta.powerConsumers) do
                                            if not entradaCanonica.powerConsumers[chaveConsumidor] then
                                                entradaCanonica.powerConsumers[chaveConsumidor] = dadosConsumidor
                                            end
                                        end
                                        -- Recalcula os totais de carga elétrica após a mesclagem
                                        local cargaTotal = 0
                                        local cargaAquecimento = 0
                                        for _, consumidor in pairs(entradaCanonica.powerConsumers) do
                                            if consumidor.powerDraw then
                                                cargaTotal = cargaTotal + consumidor.powerDraw
                                                if consumidor.isHeater then
                                                    cargaAquecimento = cargaAquecimento + consumidor.powerDraw
                                                end
                                            end
                                        end
                                        entradaCanonica.totalPowerDraw = cargaTotal
                                        entradaCanonica.heatingPowerDraw = cargaAquecimento
                                        -- Enfileira para atualização de interface
                                        _atualizacoesPredioPendentes[idCanonicoDerivado] = true
                                    end
                                    gerenciadorEstado.RemoveBuilding(idPoolPredio)
                                end

                                idPoolPredio = idCanonicoDerivado
                            end
                            -- ─────────────────────────────────────────────────────────

                            -- B-111-consumer-fix: Após a migração, verifica se o prédio canônico
                            -- agora possui consumidores (mesclados a partir do obsoleto). Se sim, pula o escaneamento
                            -- para evitar sobrescrever os dados mesclados com um prédio recém-criado vazio.
                            local dadosPredioCanonico = gerenciadorEstado.GetBuilding(idPoolPredio)
                            local jaPossuiConsumidores = dadosPredioCanonico
                                                     and dadosPredioCanonico.powerConsumers
                                                     and not LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(dadosPredioCanonico.powerConsumers)
                            
                            if jaPossuiConsumidores then
                                dadosPredio = dadosPredioCanonico -- Usa o canônico com consumidores mesclados
                            end
                            
                            if not jaPossuiConsumidores then
                                LKS_EletricidadeConstrucao.Core.Logger.Debug(string.format("[ChunkTracker] Restauração V1: escaneando prédio %s a partir do interruptor de luz (%d,%d,%d)",
                                    idPoolPredio, switchX, switchY, switchZ), "Fuel")
                                local sucessoEscaneamento = pcall(function()
                                    dadosPredio = Escaneador.ScanBuilding(switchX, switchY, switchZ, idPoolPredio)
                                end)
                                if dadosPredio then
                                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                                        string.format("[ChunkTracker] Restauração V1: varredura concluída para %s (%d consumidores)",
                                            idPoolPredio, dadosPredio.powerConsumers and #dadosPredio.powerConsumers or 0),
                                        "Fuel")
                                end
                            else
                                LKS_EletricidadeConstrucao.Core.Logger.Info(
                                    string.format("[ChunkTracker] Restauração V1: pulando varredura para %s (já possui %d consumidores da mesclagem)",
                                        idPoolPredio, dadosPredio.powerConsumers and #dadosPredio.powerConsumers or 0),
                                    "Fuel")
                            end
                        else
                            -- Nenhum interruptor de luz encontrado – garante ao menos um esboço básico
                            if not dadosPredio then
                                dadosPredio = {
                                    id = idPoolPredio,
                                    x = coordX, y = coordY, z = coordZ,
                                    connectedGenerators = {},
                                    isPowered = false,
                                    powerConsumers = {},
                                    totalPowerDraw = 0,
                                    heatingPowerDraw = 0,
                                }
                                gerenciadorEstado.AddBuilding(dadosPredio)
                            end
                        end
                    else
                        -- Nenhum IsoBuilding adjacente encontrado.
                        -- Isso é normal para estruturas construídas por jogadores: getBuilding() sempre
                        -- retorna nil para blocos colocados por jogadores, de modo que o caminho de salas acima
                        -- nunca encontra um interruptor de luz.
                        -- Em vez disso, usa as coordenadas de interruptor salvas em LKS_EletricidadeConstrucao_PoolData (gravadas por
                        -- StateManager.Save()) para rodar uma varredura direta ScanBuilding.
                        local switchX2, switchY2, switchZ2

                        -- 1) LKS_EletricidadeConstrucao_PoolData.x/y/z é o interruptor âncora salvo no gerador dono
                        if modDataObj.LKS_EletricidadeConstrucao_PoolData and modDataObj.LKS_EletricidadeConstrucao_PoolData.x and modDataObj.LKS_EletricidadeConstrucao_PoolData.y and modDataObj.LKS_EletricidadeConstrucao_PoolData.z then
                            switchX2 = modDataObj.LKS_EletricidadeConstrucao_PoolData.x
                            switchY2 = modDataObj.LKS_EletricidadeConstrucao_PoolData.y
                            switchZ2 = modDataObj.LKS_EletricidadeConstrucao_PoolData.z
                        end

                        -- 2) Fallback: analisa coordenadas a partir do formato do ID bld_X_Y_Z
                        if not switchX2 then
                            local bx, by, bz = string.match(idPoolPredio, "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                            if bx then
                                switchX2, switchY2, switchZ2 = tonumber(bx), tonumber(by), tonumber(bz)
                            end
                        end

                        -- B-111-consumer-fix: Verifica se o prédio CANÔNICO possui consumidores antes de
                        -- escanear. dadosPredio pode ser a referência obsoleta, por isso verifica com ID canônico.
                        local dadosPredioCanonico = gerenciadorEstado.GetBuilding(idPoolPredio)
                        local jaPossuiConsumidores = dadosPredioCanonico
                                                 and dadosPredioCanonico.powerConsumers
                                                 and not LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(dadosPredioCanonico.powerConsumers)
                        if jaPossuiConsumidores then
                            dadosPredio = dadosPredioCanonico -- Usa o canônico, não o obsoleto
                        end

                        if switchX2 and Escaneador and Escaneador.ScanBuilding and not jaPossuiConsumidores then
                            LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                "[ChunkTracker] Restauração V1 (construído por jogador): escaneando %s a partir do interruptor salvo (%d,%d,%d)",
                                idPoolPredio, switchX2, switchY2, switchZ2), "Fuel")
                            local sucesso2 = pcall(function()
                                dadosPredio = Escaneador.ScanBuilding(switchX2, switchY2, switchZ2, idPoolPredio)
                            end)
                            if dadosPredio then
                                LKS_EletricidadeConstrucao.Core.Logger.Info(string.format(
                                    "[ChunkTracker] Restauração V1 (construído por jogador): varredura concluída para %s (%d consumidores)",
                                    idPoolPredio, dadosPredio.powerConsumers and #dadosPredio.powerConsumers or 0), "Fuel")
                            end
                        elseif not dadosPredio then
                            -- Último recurso: cria um esboço para que pelo menos o prédio exista no estado
                            dadosPredio = {
                                id = idPoolPredio,
                                x = switchX2 or coordX, y = switchY2 or coordY, z = switchZ2 or coordZ,
                                connectedGenerators = {},
                                isPowered = false,
                                powerConsumers = {},
                                totalPowerDraw = 0,
                                heatingPowerDraw = 0,
                            }
                            gerenciadorEstado.AddBuilding(dadosPredio)
                        end
                    end
                elseif not dadosPredio then
                    -- Escaneador não disponível ou consumidores já populados – garante que a entrada exista
                    dadosPredio = {
                        id = idPoolPredio,
                        x = coordX, y = coordY, z = coordZ,
                        connectedGenerators = {},
                        isPowered = false,
                        powerConsumers = {},
                        totalPowerDraw = 0,
                        heatingPowerDraw = 0,
                    }
                    gerenciadorEstado.AddBuilding(dadosPredio)
                end

                -- Busca novamente (ScanBuilding pode ter substituído a referência da tabela)
                dadosPredio = gerenciadorEstado.GetBuilding(idPoolPredio) or dadosPredio

                -- ── HEATING SYNC: IsoObject → memória (Opção A / B-99) ────────────────
                -- B-110: Apenas aplica o estado de aquecimento do IsoObject quando a
                -- configuração de aquecimento do prédio não estiver inicializada (nil).
                -- Uma vez que o prédio tenha estado de aquecimento (de GlobalModData ou do
                -- primeiro gerador carregado em um pool multi-gen), não permite que valores
                -- subsequentes dos IsoObjects dos geradores o sobrescrevam.
                --
                -- Problema multi-gen: Gerador1 carrega com HeatingEnabled=true, define o prédio
                -- como true. Gerador2 carrega depois com HeatingEnabled=false, sobrescreveria
                -- para false. Mas heatingSourceCount (de GlobalModData) já está definido como 3,
                -- criando estado inconsistente (aquecimento DESLIGADO, fontes LIGADAS).
                -- Correção: o primeiro gerador a carregar vence, geradores subsequentes são ignorados.
                if dadosPredio then
                    if dadosPredio.heatingEnabled == nil then
                        -- Prédio ainda não possui estado de aquecimento, popula do IsoObject
                        if modDataObj.HeatingEnabled ~= nil then
                            dadosPredio.heatingEnabled = modDataObj.HeatingEnabled
                            dadosPredio.heatingTargetTemp = modDataObj.HeatingTargetTemp or 22.0
                        else
                            -- IsoObject não possui marcação de aquecimento → gerador novo, padrão desativado
                            dadosPredio.heatingEnabled = false
                            dadosPredio.heatingTargetTemp = 22.0
                        end
                    end
                    -- senão: o prédio já possui estado de aquecimento (de GlobalModData ou
                    -- gerador anterior), não sobrescreve a partir do IsoObject deste gerador
                end
                -- ─────────────────────────────────────────────────────────────────────

                -- Garante vínculo bidirecional: predio.connectedGenerators → chaveGerador
                if dadosPredio then
                    dadosPredio.connectedGenerators = dadosPredio.connectedGenerators or {}
                    local jaVinculado = false
                    -- connectedGenerators é desserializado pelo Kahlua (chaves numéricas string); use pairs
                    for _, chaveG in pairs(dadosPredio.connectedGenerators) do
                        if chaveG == chaveGerador then jaVinculado = true; break end
                    end
                    if not jaVinculado then
                        table.insert(dadosPredio.connectedGenerators, chaveGerador)
                    end
                end

                -- Opção A (B-99): Semeadura de LKS_EletricidadeConstrucao_PoolData removida. A geometria do prédio
                -- (boundingBox, borderRadius, isRVInterior) é fornecida por ScanBuilding
                -- e não precisa ser preenchida a partir do armazenamento secundário do IsoObject.

                gerenciadorEstado.MarkDirty()
                end -- fim do else (caminho de ID de mundo válido)
            end -- fim do if modDataObj.Gen_BuildingPoolID
        end
    end
end
-- ============================================================================

--- Trata evento de carregamento de chunk
--- OTIMIZADO: Deduplicação em nível de chunk evita processar o mesmo chunk 100 vezes redundantes
--- @param quadrado IsoGridSquare Quadrado da grade que foi carregado
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.OnLoadGridsquare(quadrado)
    if not quadrado then
        return
    end

    -- Verificação de segurança: garante que módulos necessários estão carregados
    if not LKS_EletricidadeConstrucao.Core or not LKS_EletricidadeConstrucao.Core.StateManager then
        return
    end

    local Geometria = LKS_EletricidadeConstrucao.Utils.Geometry
    local coordX = quadrado:getX()
    local coordY = quadrado:getY()
    
    -- Obtém a chave do chunk
    local chaveChunk = Geometria.GetChunkKey(coordX, coordY)
    
    -- OTIMIZAÇÃO: Deduplicação em nível de chunk (OnLoadGridsquare dispara 100 vezes por chunk 10x10)
    if _chunksProcessados[chaveChunk] then
        return -- Já processou este chunk
    end
    _chunksProcessados[chaveChunk] = true
    
    -- Registra o tempo de carregamento
    _temposCarregamentoChunk[chaveChunk] = getTimestampMs()
    
    LKS_EletricidadeConstrucao.Core.Logger.Trace(
        string.format("Chunk carregado: %s em (%d,%d)", chaveChunk, coordX, coordY),
        "Fuel"
    )
    
    -- Estilo V1: restaura gerador → vínculos de prédios do ModData do IsoObject.
    -- IMPORTANTE (B-55): Devemos escanear TODOS os quadrados no chunk, não apenas o primeiro.
    -- A guarda de dedup de chunk acima dispara em qualquer quadrado que chegue primeiro –
    -- esse quadrado quase nunca é o quadrado onde reside o gerador. Se nenhum gerador
    -- estiver no primeiro quadrado processado, tentarRestaurarDadosModIso não encontra
    -- IsoGenerator, o prédio nunca é adicionado ao estado, e ForceUpdateBuilding
    -- falha mais tarde com "Prédio não encontrado" → o prédio permanece sem energia.
    --
    -- Estratégia: escaneia o primeiro quadrado imediatamente (cobre o caso comum de um
    -- gerador NESSE quadrado com custo extra zero), então percorre todos os 100 quadrados
    -- no chunk e chama tentarRestaurarDadosModIso apenas em quadrados que de fato
    -- contenham um IsoGenerator. IsoGenerators são raros então a verificação instanceof
    -- sai rápido para a vasta maioria dos quadrados.
    -- Apenas restaura se o prédio não estiver estabelecido no estado (pula em retornos saudáveis de chunk)
    if precisaRestaurarIso(quadrado) then
        pcall(tentarRestaurarDadosModIso, quadrado)
    end

    do
        local chunkBaseX = math.floor(coordX / 10) * 10
        local chunkBaseY = math.floor(coordY / 10) * 10
        local coordZ = quadrado:getZ()
        local celula = getCell and getCell()
        if celula then
            for dx = 0, 9 do
                for dy = 0, 9 do
                    local quadrado2 = celula:getGridSquare(chunkBaseX + dx, chunkBaseY + dy, coordZ)
                    if quadrado2 and quadrado2 ~= quadrado then
                        local objetos2 = quadrado2:getObjects()
                        if objetos2 then
                            for oi = 0, objetos2:size() - 1 do
                                local objeto2 = objetos2:get(oi)
                                if objeto2 and instanceof(objeto2, "IsoGenerator") then
                                    -- Guarda: pula se prédio já saudável no estado (B-71)
                                    if precisaRestaurarIso(quadrado2) then
                                        pcall(tentarRestaurarDadosModIso, quadrado2)
                                    end
                                    break -- Apenas uma chamada por quadrado necessária
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Verifica geradores neste chunk
    LKS_EletricidadeConstrucao.Fuel.ChunkTracker.ProcessChunkGenerators(chaveChunk, coordX, coordY)
end

--- Trata evento de descarregamento de chunk
--- @param quadrado IsoGridSquare Quadrado da grade que foi descarregado
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.OnUnloadGridsquare(quadrado)
    if not quadrado then
        return
    end
    
    local Geometria = LKS_EletricidadeConstrucao.Utils.Geometry
    local coordX = quadrado:getX()
    local coordY = quadrado:getY()
    
    -- Obtém a chave do chunk
    local chaveChunk = Geometria.GetChunkKey(coordX, coordY)
    
    -- OTIMIZAÇÃO: Deduplicação em nível de chunk para descarregamento (só processa uma vez)
    if not _chunksProcessados[chaveChunk] then
        return -- Nunca processou este chunk no carregamento, pula descarregamento
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Trace(
        string.format("Chunk descarregando: %s em (%d,%d)", chaveChunk, coordX, coordY),
        "Fuel"
    )
    
    -- NOTA: O consumo de combustível continua no GlobalModData independentemente do status do chunk.
    -- Não há necessidade de rastrear tempos de descarregamento ou recuperar atrasos no recarregamento -
    -- o combustível está sempre atualizado.
    
    -- Remove o chunk do rastreamento
    _temposCarregamentoChunk[chaveChunk] = nil
    _chunksProcessados[chaveChunk] = nil
end

-- ============================================================================
-- PROCESSAMENTO DE GERADOR
-- ============================================================================

--- Processa todos os geradores no chunk quando este carrega
--- @param chaveChunk string Chave do chunk
--- @param coordX number Coordenada X amostral no chunk
--- @param coordY number Coordenada Y amostral no chunk
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.ProcessChunkGenerators(chaveChunk, coordX, coordY)
    -- Verificação de segurança: garante que módulos necessários estão carregados
    if not LKS_EletricidadeConstrucao.Core or not LKS_EletricidadeConstrucao.Core.StateManager then
        return
    end
    if not LKS_EletricidadeConstrucao.Config then
        return
    end

    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
    local Config = LKS_EletricidadeConstrucao.Config

    -- Obtém todos os geradores neste chunk (necessário tanto para combustível quanto para interface)
    if not gerenciadorEstado.GetGeneratorsInChunk then
        return
    end
    local geradores = gerenciadorEstado.GetGeneratorsInChunk(chaveChunk)
    if #geradores == 0 then return end

    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Processando %d geradores no chunk %s", #geradores, chaveChunk),
        "Fuel"
    )

    -- Sincroniza o combustível do IsoObject com o GlobalModData (que é continuamente atualizado)
    local precisaAtualizarEnergia = false
    local prediosAfetados = {} -- Rastreia prédios que precisam de atualização de energia
    
    for _, dadosGerador in ipairs(geradores) do
        local objetoGerador = getGeneratorFromSquare(dadosGerador.x, dadosGerador.y, dadosGerador.z)
        if objetoGerador then
            local combustivelEstado = dadosGerador.fuelAmount or 0
            local combustivelAtual = objetoGerador:getFuel() or 0
            -- B-111: Não trata activated=nil como false. Conforme B-36, nil significa "implicitamente ativo"
            -- (apenas false explícito significa desativado). Isso impede que geradores aleatórios sejam
            -- desligados durante restauração fora de chunk quando possuem estado de ativação nil.
            local ativacaoEstado = dadosGerador.activated -- nil, true, ou false
            local ativacaoAtual = objetoGerador:isActivated() or false
            
            -- Sincroniza estado do combustível para o IsoObject para exibição de interface (estado é sempre autoridade)
            -- Também redefine lastSyncedFuel para que a detecção de reabastecimento de Update() veja a base correta.
            if combustivelAtual ~= combustivelEstado then
                objetoGerador:setFuel(combustivelEstado)
                LKS_EletricidadeConstrucao.Core.Logger.Debug(
                    string.format("Sincronia de combustível pós-carregamento: gerador %s %.3f -> %.3f", 
                        dadosGerador.id, combustivelAtual, combustivelEstado),
                    "Fuel"
                )
            end
            dadosGerador.lastSyncedFuel = combustivelEstado

            -- Se o gerador não possui combustível, força a desativação do IsoObject independentemente do estado atual.
            -- Isso garante que isBuildingPoweredInline retorne false imediatamente após o carregamento do chunk.
            if combustivelEstado <= 0 and ativacaoAtual then
                objetoGerador:setActivated(false)
                dadosGerador.activated = false
                precisaAtualizarEnergia = true
                if dadosGerador.connectedBuildings then
                    -- connectedBuildings é desserializado pelo Kahlua (chaves numéricas string)
                    for _, predioId in pairs(dadosGerador.connectedBuildings) do
                        prediosAfetados[predioId] = true
                    end
                end
                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("Carga de chunk: desativado gerador %s de força (sem combustível)", dadosGerador.id),
                    "Fuel"
                )
            end
            
            -- B-111: Apenas sincroniza ativação quando o estado é EXPLICITAMENTE definido como false (não nil)
            -- E o gerador tem combustível. Se o gerador tem combustível mas o estado diz false, ele pode ser
            -- obsoleto (ficou sem combustível fora do chunk, foi reabastecido, mas o sinalizador ativo não foi
            -- redefinido). Confia no IsoObject neste caso.
            if ativacaoEstado == false and combustivelEstado > 0 and ativacaoAtual then
                -- Estado diz desativado, mas o gerador possui combustível e o IsoObject diz ativo.
                -- Isso sugere que o gerador secou fora de chunk (ativo→false) e então foi reabastecido,
                -- mas o sinalizador de ativo não foi redefinido. Confia no IsoObject, corrige o estado.
                dadosGerador.activated = true
                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("Carga de chunk: gerador %s possui combustível (%.2f) e IsoObject ativo, corrigindo ativacao=false obsoleta no estado",
                        dadosGerador.id, combustivelEstado),
                    "Fuel"
                )
            elseif ativacaoEstado ~= nil and ativacaoEstado ~= ativacaoAtual then
                -- O estado está explicitamente definido (não nil) e difere do IsoObject.
                -- Apenas sincroniza se o gerador não possui combustível OU o estado disser ativo.
                if combustivelEstado <= 0 or ativacaoEstado == true then
                    objetoGerador:setActivated(ativacaoEstado)
                    precisaAtualizarEnergia = true
                end
                
                -- Adiciona todos os prédios conectados à lista de atualização
                if dadosGerador.connectedBuildings then
                    -- connectedBuildings é desserializado pelo Kahlua (chaves numéricas string)
                    for _, predioId in pairs(dadosGerador.connectedBuildings) do
                        prediosAfetados[predioId] = true
                    end
                end
                
                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("Sincronia de ativação pós-carregamento: gerador %s %s -> %s (combustível: %.2f)", 
                        dadosGerador.id, tostring(ativacaoAtual), tostring(ativacaoEstado), combustivelEstado),
                    "Fuel"
                )
            end
        end
    end
    
    -- Se qualquer gerador alterou o estado de ativação, atualiza imediatamente a distribuição de energia
    -- para os prédios afetados. Isso garante que ApplyTilePower seja executado AGORA que o chunk foi carregado.
    if precisaAtualizarEnergia then
        local Distribuidor = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
        if Distribuidor and Distribuidor.ForceUpdateBuilding then
            local totalAtualizados = 0
            for predioId in pairs(prediosAfetados) do
                pcall(Distribuidor.ForceUpdateBuilding, predioId)
                totalAtualizados = totalAtualizados + 1
            end
            LKS_EletricidadeConstrucao.Core.Logger.Info(
                string.format("Energia atualizada para %d prédio(s) após sincronia de estado de geradores", totalAtualizados),
                "Fuel"
            )
        end
    end

    -- Adia as chamadas de ForceUpdateBuilding por ~30 ticks (~2 s a 15 fps) para que
    -- chunks adjacentes que contenham os quadrados internos do prédio tenham tempo de
    -- carregar antes de tentarmos ler o estado isActive de aparelhos/luzes.
    -- Padrão V1: cria um fechamento local autolimpante por evento de carregamento de chunk.
    -- Nunca registra um manipulador OnTick persistente no escopo do módulo (causa falhas
    -- de chamada nula no Kahlua quando a referência do módulo não está totalmente resolvida).
    local idsPredios = {}
    for _, dadosGerador in ipairs(geradores) do
        -- connectedBuildings é desserializado pelo Kahlua após recarregamento de GlobalModData
        -- (chaves numéricas string). ipairs não retorna nada nestas tabelas. Use pairs.
        for _, predioId in pairs(dadosGerador.connectedBuildings or {}) do
            idsPredios[predioId] = true -- dedup
        end
    end

    local _possuiIdsPredio2 = false
    for _ in pairs(idsPredios) do _possuiIdsPredio2 = true; break end
    if _possuiIdsPredio2 then
        -- Coleta as coordenadas dos geradores deste chunk para o reescaneamento adiado.
        -- Capturamos agora enquanto os dados estão no escopo; o temporizador de lote os consome.
        for _, dadosGerador in ipairs(geradores) do
            _reescaneamentosGeradorPendentes[dadosGerador.id] = { x = dadosGerador.x, y = dadosGerador.y, z = dadosGerador.z }
        end

        -- OTIMIZAÇÃO: Usa temporizador de lote global em vez de criar temporizadores locais por chunk
        -- Adiciona prédios à fila do lote
        -- B-111-offchunk-resync: Sempre adiciona os prédios quando os chunks de seus geradores carregam,
        -- mesmo se já processados na inicialização. Na inicialização, geradores podem não ter sido
        -- alcançáveis (getSquare retornando nil), então estatísticas nunca foram gravadas no ModData.
        -- Agora que os chunks carregaram, precisamos tentar sincronizar.
        local totalAdicionados = 0
        for predioId in pairs(idsPredios) do
            if not _atualizacoesPredioPendentes[predioId] then
                _atualizacoesPredioPendentes[predioId] = true
                -- Não verifica _atualizacoesPredioAgendadas - permite reprocessamento
                totalAdicionados = totalAdicionados + 1
                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("[ChunkLoad] Prédio %s adicionado à fila do lote (chunk do gerador carregado)", predioId),
                    "Fuel")
            end
        end

        -- Inicia o temporizador de lote global se não estiver ativo
        if totalAdicionados > 0 and not _timerLoteAtivo then
            _timerLoteAtivo = true
            local ticksAdiados = 30 -- atraso de ~2 s
            local funcaoTimer
            funcaoTimer = function()
                ticksAdiados = ticksAdiados - 1
                if ticksAdiados > 0 then return end

                LKS_EletricidadeConstrucao.Core.Logger.Info(
                    string.format("[ChunkTracker] Temporizador do lote disparado após 30 ticks"),
                    "Fuel")
                Events.OnTick.Remove(funcaoTimer)
                _timerLoteAtivo = false

                -- Fase 1a: executa tentarRestaurarDadosModIso em cada quadrado de gerador
                -- para que as ligações do StateManager e esboços de prédios existam
                -- antes da execução da varredura de consumidores abaixo.
                --
                -- B-101: Apenas limpa entradas de _reescaneamentosGeradorPendentes cujos quadrados estão
                -- de fato carregados. Anteriormente a entrada era sempre limpa mesmo quando
                -- getSquare() retornava nil (chunk ainda não carregado), abandonando permanentemente
                -- aquele gerador -- seu moddata de IsoObject nunca era atualizado para o ID canônico
                -- bld_X_Y_Z, fazendo com que a janela e o requestFreshStats usassem o ID obsoleto
                -- bld_def_... contra uma entrada do StateManager que não existia mais sob aquela chave.
                local totalReescaneados = 0
                local idsGensProcessados = {}
                for idGerador, coordenadas in pairs(_reescaneamentosGeradorPendentes) do
                    local quadradoGerador = getSquare(coordenadas.x, coordenadas.y, coordenadas.z)
                    if quadradoGerador then
                        -- Guarda: pula se prédio já saudável no estado (B-71)
                        if precisaRestaurarIso(quadradoGerador) then
                            pcall(tentarRestaurarDadosModIso, quadradoGerador)
                            totalReescaneados = totalReescaneados + 1
                        end
                        idsGensProcessados[idGerador] = true
                        _reescaneamentosGeradorPendentes[idGerador] = nil -- apenas remove se o quadrado carregou
                    end
                    -- Se o quadrado for nulo, a entrada é mantida para que o próximo ciclo tente novamente.
                end
                if totalReescaneados > 0 then
                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                        string.format("[ChunkTracker] Reescaneamento lote: reescaneados %d quadrado(s) de geradores antes de ForceUpdate",
                            totalReescaneados), "Fuel")
                end

                -- B-107: Limpeza de duplicatas de prédios multi-geradores pós-varredura de carregamento de chunk.
                -- tentarRestaurarDadosModIso pode criar entradas obsoletas bld_def_... se um gerador
                -- de IsoObject não foi atualizado por expurgarDuplicatasPredioObsoletas na inicialização (gerador
                -- estava em chunk descarregado). Executa Purge aqui para mesclar quaisquer novas duplicatas antes
                -- que a Fase 1b faça o escaneamento, garantindo que o prédio canônico receba os dados de consumidores.
                local gerenciadorEstado1 = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                if gerenciadorEstado1 and gerenciadorEstado1.IsStateLoaded and gerenciadorEstado1.IsStateLoaded() then
                    -- Coleta todos os IDs de prédios que precisam de limpeza potencial
                    local todosIdsPredio = {}
                    for predioId in pairs(_atualizacoesPredioPendentes) do
                        todosIdsPredio[predioId] = true
                    end
                    expurgarDuplicatasPredioObsoletas(gerenciadorEstado1, todosIdsPredio, _atualizacoesPredioPendentes)
                    -- Atualiza _atualizacoesPredioPendentes para IDs canônicos após purga
                    _atualizacoesPredioPendentes = todosIdsPredio
                end

                -- Fase 1a-pos: atualiza _atualizacoesPredioPendentes com IDs canônicos pós-migração.
                -- tentarRestaurarDadosModIso pode ter renomeado chaves bld_def_XXXX para bld_X_Y_Z;
                -- _atualizacoesPredioPendentes foi populado antes dessa migração e ainda contém as chaves antigas.
                -- Reconstrói agora para que a Fase 1b e Fase 2 operem em IDs de prédio válidos e resolvíveis.
                -- B-111-offchunk-fix: Processa TODOS os geradores, não apenas os reescaneados,
                -- porque geradores restaurados de GlobalModData podem não ter sido reescaneados
                -- mas ainda precisam de seus links de prédios atualizados.
                local gerenciadorEstado1a = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                if gerenciadorEstado1a then
                    -- Coleta IDs canônicos de TODOS os geradores no StateManager
                    local idsCanonicos = {}
                    for _, dadosGen in pairs(gerenciadorEstado1a.GetAllGenerators() or {}) do
                        if dadosGen and dadosGen.connectedBuildings then
                            -- connectedBuildings é desserializado pelo Kahlua (chaves numéricas string); use pairs
                            for _, predioId in pairs(dadosGen.connectedBuildings) do
                                if gerenciadorEstado1a.GetBuilding(predioId) then
                                    idsCanonicos[predioId] = true
                                end
                            end
                        end
                    end
                    -- Reconstrói: mantém entradas válidas existentes, descarta obsoletas e adiciona canônicas
                    local pendentesNovos = {}
                    for predioId in pairs(_atualizacoesPredioPendentes) do
                        if gerenciadorEstado1a.GetBuilding(predioId) then
                            pendentesNovos[predioId] = true
                        end
                        -- senão: obsoleto (ex: bld_def_... migrado) - descarta silenciosamente
                    end
                    for predioId in pairs(idsCanonicos) do
                        pendentesNovos[predioId] = true
                        _atualizacoesPredioAgendadas[predioId] = true
                    end
                    _atualizacoesPredioPendentes = pendentesNovos
                end

                -- Fase 1b: Sempre reexecuta ScanBuilding para cada prédio pendente
                -- cujo quadrado de interruptor de luz esteja agora carregado na memória.
                -- tentarRestaurarDadosModIso pula ScanBuilding quando powerConsumers
                -- está populado, de modo que consumidores obsoletos (todos isActive=false definidos
                -- pelo ForceUpdateBuilding fora de chunk) persistiriam sem esta etapa.
                -- Uma varredura nova é barata (detecção de borda + busca de objeto) e
                -- garante que sobrecarga, contagem de consumidores na interface e consumo de combustível
                -- sejam recalculados a partir do estado do mundo real no instante do carregamento do chunk.
                --
                -- B-83: Apenas chama ScanBuilding quando TODA a área do prédio está carregada.
                -- Prédios grandes abrangem múltiplos chunks; se qualquer chunk ainda estiver descarregado,
                -- getSquare() retorna nil para seus blocos e ClearConsumers + ScanConsumers perderia
                -- permanentemente aqueles consumidores. IsBuildingAreaLoaded verifica todos os cantos
                -- do retângulo envolvente (5 amostras) – barato e suficiente.
                local Escaneador = LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner
                local gerenciadorEstado2 = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                if Escaneador and Escaneador.ScanBuilding and gerenciadorEstado2 then
                    local totalVarridosPredio = 0
                    local totalPuladosPredio = 0
                    for predioId in pairs(_atualizacoesPredioPendentes) do
                        local predio = gerenciadorEstado2.GetBuilding(predioId)
                        if predio and predio.x and predio.y then
                            local switchX, switchY, switchZ = predio.x, predio.y, predio.z or 0
                            local quadradoSwitch = getSquare(switchX, switchY, switchZ)
                            if quadradoSwitch then
                                -- Apenas reescaneia quando todos os chunks do prédio estiverem carregados.
                                local areaCarregada = (not Escaneador.IsBuildingAreaLoaded)
                                    or Escaneador.IsBuildingAreaLoaded(predio)
                                if areaCarregada then
                                    -- Quadrado carregado e área totalmente carregada - escaneia para obter lista atualizada
                                    local sucesso = pcall(function()
                                        Escaneador.ScanBuilding(switchX, switchY, switchZ, predioId)
                                    end)
                                    if sucesso then
                                        totalVarridosPredio = totalVarridosPredio + 1
                                    end
                                else
                                    -- Área do prédio parcialmente descarregada – pula varredura, mantém lista salva.
                                    totalPuladosPredio = totalPuladosPredio + 1
                                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                                        string.format("[ChunkTracker] Pulando varredura para %s – área parcialmente carregada",
                                            predioId), "Fuel")
                                end
                            end
                        end
                    end
                    if totalVarridosPredio > 0 then
                        LKS_EletricidadeConstrucao.Core.Logger.Info(
                            string.format("[ChunkTracker] Revarredura por entrada de chunk: reconstruídos consumidores para %d prédio(s) (pulados %d parciais)",
                                totalVarridosPredio, totalPuladosPredio), "Fuel")
                    end
                end

                -- Fase 2: Processa todos os prédios pendentes em um único lote
                local Distribuidor = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
                local gerenciadorEstado3 = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                if Distribuidor and Distribuidor.ForceUpdateBuilding and gerenciadorEstado3 then
                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                        string.format("[ChunkTracker] Iniciando Fase 2: %d prédios na fila",
                            (function() local n=0; for _ in pairs(_atualizacoesPredioPendentes) do n=n+1 end; return n end)()),
                        "Fuel")
                    local totalLote = 0
                    local totalPulados = 0
                    for predioId in pairs(_atualizacoesPredioPendentes) do
                        -- B-111-offchunk-fix: Verifica se o prédio existe antes de atualizar.
                        -- Após Purge, IDs obsoletos podem permanecer na fila mas o prédio foi mesclado.
                        local predio = gerenciadorEstado3.GetBuilding(predioId)
                        if predio then
                            -- Registra contagem de consumidores antes de ForceUpdateBuilding
                            local totalConsumidoresAntes = 0
                            if predio.powerConsumers then
                                for _ in pairs(predio.powerConsumers) do totalConsumidoresAntes = totalConsumidoresAntes + 1 end
                            end
                            LKS_EletricidadeConstrucao.Core.Logger.Info(
                                string.format("[ChunkTracker] Fase 2: ForceUpdateBuilding para %s (%d consumidores)", predioId, totalConsumidoresAntes),
                                "Fuel")
                            pcall(Distribuidor.ForceUpdateBuilding, predioId)
                            totalLote = totalLote + 1
                        else
                            totalPulados = totalPulados + 1
                            LKS_EletricidadeConstrucao.Core.Logger.Warn(
                                string.format("[ChunkTracker] Lote Fase 2: prédio %s não encontrado no StateManager, pulando ForceUpdate", predioId),
                                "Fuel")
                        end
                    end
                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                        string.format("[ChunkTracker] Lote Fase 2 concluído: atualizados %d prédios (pulados %d ausentes)", totalLote, totalPulados),
                        "Fuel")
                end

                -- Limpa o lote (mas mantém _atualizacoesPredioAgendadas intocada)
                _atualizacoesPredioPendentes = {}

                -- B-101: Se quaisquer quadrados de gerador não estavam carregados (getSquare()
                -- retornou nil acima), suas entradas continuam em _reescaneamentosGeradorPendentes.
                -- Reinicia um temporizador secundário para que sejam tentados quando o jogador
                -- se movimentar e carregar o(s) chunk(s) ausente(s).
                if tabelaPossuiEntradas(_reescaneamentosGeradorPendentes) then -- B-106: pairs-based check
                    local totalRepeticoes = 0
                    for _ in pairs(_reescaneamentosGeradorPendentes) do totalRepeticoes = totalRepeticoes + 1 end
                    LKS_EletricidadeConstrucao.Core.Logger.Info(
                        string.format("[ChunkTracker] Repetição lote agendada: %d gerador(es) pendentes (quadrados ainda não carregados)",
                            totalRepeticoes), "Fuel")
                    _timerLoteAtivo = true
                    local ticksRepeticao = 120 -- ~8 s
                    local funcaoRepeticao
                    funcaoRepeticao = function()
                        ticksRepeticao = ticksRepeticao - 1
                        if ticksRepeticao > 0 then return end
                        Events.OnTick.Remove(funcaoRepeticao)
                        _timerLoteAtivo = false
                        local totalProcessadosRepeticao = 0
                        for idGerador, coordenadas in pairs(_reescaneamentosGeradorPendentes) do
                            local quadradoGerador2 = getSquare(coordenadas.x, coordenadas.y, coordenadas.z)
                            if quadradoGerador2 then
                                if precisaRestaurarIso(quadradoGerador2) then
                                    pcall(tentarRestaurarDadosModIso, quadradoGerador2)
                                    totalProcessadosRepeticao = totalProcessadosRepeticao + 1
                                end
                                _reescaneamentosGeradorPendentes[idGerador] = nil
                            end
                        end
                        if totalProcessadosRepeticao > 0 then
                            LKS_EletricidadeConstrucao.Core.Logger.Info(
                                string.format("[ChunkTracker] Repetição lote concluída: processados %d gerador(es)",
                                    totalProcessadosRepeticao), "Fuel")
                        end
                        if tabelaPossuiEntradas(_reescaneamentosGeradorPendentes) then -- B-106
                            LKS_EletricidadeConstrucao.Core.Logger.Info(
                                "[ChunkTracker] Repetição lote: geradores continuam pendentes após repetição (chunks distantes?)", "Fuel")
                        end
                    end
                    Events.OnTick.Add(funcaoRepeticao)
                end
            end
            Events.OnTick.Add(funcaoTimer)
        end
    end
end

-- ============================================================================
-- CONSULTAS DE ESTADO DE CHUNKS
-- ============================================================================

--- Verifica se um chunk está atualmente carregado
--- @param chaveChunk string Chave do chunk
--- @return boolean True se estiver carregado
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.IsChunkLoaded(chaveChunk)
    return _temposCarregamentoChunk[chaveChunk] ~= nil
end

--- Obtém o tempo de carregamento do chunk
--- @param chaveChunk string Chave do chunk
--- @return number|nil Timestamp do carregamento ou nil se não carregado
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.GetChunkLoadTime(chaveChunk)
    return _temposCarregamentoChunk[chaveChunk]
end

--- Obtém todos os chunks carregados
--- @return table Array contendo chaves de chunks
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.GetLoadedChunks()
    local chunks = {}
    
    for chaveChunk, _ in pairs(_temposCarregamentoChunk) do
        table.insert(chunks, chaveChunk)
    end
    
    return chunks
end

-- ============================================================================
-- DEPURAR / DEBUG
-- ============================================================================

--- Exibe o status do rastreador de chunks no console
function LKS_EletricidadeConstrucao.Fuel.ChunkTracker.PrintStatus()
    LKS_EletricidadeConstrucao.Print("=== Status do Rastreador de Chunks ===")
    LKS_EletricidadeConstrucao.Print("Inicializado: " .. tostring(_inicializado))
    
    local chunksCarregados = LKS_EletricidadeConstrucao.Fuel.ChunkTracker.GetLoadedChunks()
    LKS_EletricidadeConstrucao.Print("Chunks Carregados: " .. #chunksCarregados)
    
    for _, chaveChunk in ipairs(chunksCarregados) do
        local tempoCarga = _temposCarregamentoChunk[chaveChunk]
        local geradores = LKS_EletricidadeConstrucao.Core.StateManager.GetGeneratorsInChunk(chaveChunk)
        LKS_EletricidadeConstrucao.Print(string.format("  %s: carregado em %d, %d geradores",
            chaveChunk, tempoCarga, #geradores))
    end
end

-- ============================================================================
-- REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Fuel.ChunkTracker", "2.0.0")

return LKS_EletricidadeConstrucao.Fuel.ChunkTracker
