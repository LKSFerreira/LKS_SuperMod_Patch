-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Heating_Manager.lua
-- LKS_EletricidadeConstrucao V2 - Gerenciador de Aquecimento de Prédios (Lado do Servidor)
-- Calcula as posições de aquecimento das salas do prédio e sincroniza no ModData do gerador.
-- O cliente lê HeatingPositions e cria objetos IsoHeatSource.

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Heating_Manager] Namespace LKS_EletricidadeConstrucao não encontrado - pulando")
    return
end

LKS_EletricidadeConstrucao.Heating = LKS_EletricidadeConstrucao.Heating or {}
LKS_EletricidadeConstrucao.Heating.Manager = LKS_EletricidadeConstrucao.Heating.Manager or {}

local Heating = LKS_EletricidadeConstrucao.Heating.Manager
local Logger  = LKS_EletricidadeConstrucao.Core.Logger

-- ============================================================
-- CONSTANTES
-- ============================================================

local LIMITE_SALA_GRANDE = 50       -- blocos; acima disto usa método de cantos
local TEMPERATURA_ALVO_PADRAO = 22  -- temperatura alvo padrão de aquecimento (Celsius)

-- ============================================================
-- CÁLCULO DE POSIÇÃO
-- ============================================================

-- Calcula as posições das fontes de calor para uma única sala.
-- Salas pequenas: ponto central único.
-- Salas grandes: quatro cantos (+ centro se >200 blocos).
local function obterPosicoesDaSala(sala, zPiso)
    local retangulos = sala.getRects and sala:getRects()
    if not retangulos or retangulos:size() == 0 then return {} end

    local minimoX, minimoY, maximoX, maximoY = 999999, 999999, -999999, -999999
    local totalBlocos = 0

    for indiceRetangulo = 0, retangulos:size() - 1 do
        local retangulo = retangulos:get(indiceRetangulo)
        local xPrimeiro, xSegundo = retangulo:getX(), retangulo:getX2()
        local yPrimeiro, ySegundo = retangulo:getY(), retangulo:getY2()
        if xSegundo > xPrimeiro and ySegundo > yPrimeiro then
            minimoX = math.min(minimoX, xPrimeiro); minimoY = math.min(minimoY, yPrimeiro)
            maximoX = math.max(maximoX, xSegundo); maximoY = math.max(maximoY, ySegundo)
            totalBlocos = totalBlocos + (xSegundo - xPrimeiro) * (ySegundo - yPrimeiro)
        end
    end

    if totalBlocos <= 0 or minimoX == 999999 then return {} end

    local posicoes = {}
    local RECUO = 1

    if totalBlocos <= LIMITE_SALA_GRANDE then
        table.insert(posicoes, {
            x = math.floor(minimoX + (maximoX - minimoX) * 0.5),
            y = math.floor(minimoY + (maximoY - minimoY) * 0.5),
            z = zPiso,
        })
    else
        table.insert(posicoes, {x = minimoX + RECUO,     y = minimoY + RECUO,     z = zPiso})
        table.insert(posicoes, {x = maximoX - RECUO - 1, y = minimoY + RECUO,     z = zPiso})
        table.insert(posicoes, {x = minimoX + RECUO,     y = maximoY - RECUO - 1, z = zPiso})
        table.insert(posicoes, {x = maximoX - RECUO - 1, y = maximoY - RECUO - 1, z = zPiso})
        if totalBlocos > 200 then
            table.insert(posicoes, {
                x = math.floor(minimoX + (maximoX - minimoX) * 0.5),
                y = math.floor(minimoY + (maximoY - minimoY) * 0.5),
                z = zPiso,
            })
        end
    end

    return posicoes
end

-- Encontra o IsoBuilding a partir de dadosPredio (x/y/z = coordenadas do interruptor de luz).
local function encontrarPredioIso(dadosPredio)
    local celula = getCell()
    if not celula then return nil end

    local quadrado = celula:getGridSquare(dadosPredio.x, dadosPredio.y, dadosPredio.z)
    if quadrado then
        local predio = quadrado:getBuilding()
        if predio then return predio end
    end

    if dadosPredio.boundingBox then
        local caixaDelimitadora = dadosPredio.boundingBox
        local centroX = math.floor((caixaDelimitadora.minX + caixaDelimitadora.maxX) * 0.5)
        local centroY = math.floor((caixaDelimitadora.minY + caixaDelimitadora.maxY) * 0.5)
        local quadrado2 = celula:getGridSquare(centroX, centroY, dadosPredio.z)
        if quadrado2 then
            local predio2 = quadrado2:getBuilding()
            if predio2 then return predio2 end
        end
    end

    return nil
end

-- Fallback: agrupa dadosPredio.powerConsumers por quadrado:getRoom() (espelha o CalculatePlayerBuiltHeating da V1)
-- para tratar prédios construídos pelo jogador que não possuem um IsoBuilding vanilla.
local function obterPosicoesDosBlocosConsumidor(dadosPredio)
    if not dadosPredio then return {} end

    local celula = getCell()
    if not celula then return {} end

    -- Coleta todas as posições internas: usa coordenadas x/y/z de powerConsumers ou reescaneia
    -- se a lista de consumidores estiver vazia.
    local conjuntoBlocos = {}
    if dadosPredio.powerConsumers then
        -- powerConsumers é desserializado pelo Kahlua após carregar GlobalModData → chaves numéricas string.
        -- O operador # retorna 0 e o ipairs não itera nada nestas tabelas. Use pairs().
        for _, consumidor in pairs(dadosPredio.powerConsumers) do
            if consumidor.x and consumidor.y and consumidor.z then
                conjuntoBlocos[consumidor.x .. "_" .. consumidor.y .. "_" .. consumidor.z] = {x = consumidor.x, y = consumidor.y, z = consumidor.z}
            end
        end
    end

    -- Agrupa blocos por objeto IsoRoom (mesmo da V1 CalculatePlayerBuiltHeating)
    local gruposSalas = {}
    local grupoSemSala = {tiles = {}, minX = 999999, minY = 999999, maxX = -1, maxY = -1, z = dadosPredio.z}

    for _, bloco in pairs(conjuntoBlocos) do
        local quadrado = celula:getGridSquare(bloco.x, bloco.y, bloco.z)
        if quadrado then
            local sala = quadrado:getRoom()
            if sala then
                if not gruposSalas[sala] then
                    gruposSalas[sala] = {tiles = {}, minX = 999999, minY = 999999,
                                        maxX = -1, maxY = -1, z = bloco.z,
                                        name = (sala.getName and sala:getName()) or "UnknownRoom"}
                end
                local grupo = gruposSalas[sala]
                table.insert(grupo.tiles, bloco)
                if bloco.x < grupo.minX then grupo.minX = bloco.x end
                if bloco.y < grupo.minY then grupo.minY = bloco.y end
                if bloco.x > grupo.maxX then grupo.maxX = bloco.x end
                if bloco.y > grupo.maxY then grupo.maxY = bloco.y end
            else
                table.insert(grupoSemSala.tiles, bloco)
                if bloco.x < grupoSemSala.minX then grupoSemSala.minX = bloco.x end
                if bloco.y < grupoSemSala.minY then grupoSemSala.minY = bloco.y end
                if bloco.x > grupoSemSala.maxX then grupoSemSala.maxX = bloco.x end
                if bloco.y > grupoSemSala.maxY then grupoSemSala.maxY = bloco.y end
            end
        end
    end

    local resultado = {}
    local RECUO = 1

    local function converterGrupoParaPosicoes(grupo, idSala)
        if not grupo or #grupo.tiles == 0 then return end
        local totalBlocos = #grupo.tiles
        local coordZ = grupo.z
        local posicoes = {}
        if totalBlocos <= LIMITE_SALA_GRANDE then
            table.insert(posicoes, {
                x = math.floor(grupo.minX + (grupo.maxX - grupo.minX) * 0.5),
                y = math.floor(grupo.minY + (grupo.maxY - grupo.minY) * 0.5),
                z = coordZ,
            })
        else
            table.insert(posicoes, {x = grupo.minX + RECUO,     y = grupo.minY + RECUO,     z = coordZ})
            table.insert(posicoes, {x = grupo.maxX - RECUO,     y = grupo.minY + RECUO,     z = coordZ})
            table.insert(posicoes, {x = grupo.minX + RECUO,     y = grupo.maxY - RECUO,     z = coordZ})
            table.insert(posicoes, {x = grupo.maxX - RECUO,     y = grupo.maxY - RECUO,     z = coordZ})
            if totalBlocos > 200 then
                table.insert(posicoes, {
                    x = math.floor(grupo.minX + (grupo.maxX - grupo.minX) * 0.5),
                    y = math.floor(grupo.minY + (grupo.maxY - grupo.minY) * 0.5),
                    z = coordZ,
                })
            end
        end
        if #posicoes > 0 then
            table.insert(resultado, {roomID = idSala, positions = posicoes, z = coordZ})
        end
    end

    local indice = 0
    for _, grupo in pairs(gruposSalas) do
        indice = indice + 1
        converterGrupoParaPosicoes(grupo, grupo.name or ("Room_" .. indice))
    end
    if #grupoSemSala.tiles > 0 then
        converterGrupoParaPosicoes(grupoSemSala, "OpenArea")
    end

    return resultado
end

-- Calcula a tabela de HeatingPositions completa de um prédio.
-- Retorna: {{roomID="...", positions=[{x,y,z},...], z=N}, ...}
function Heating.CalculatePositions(buildingData)
    if not buildingData then return {} end

    local predioIso = encontrarPredioIso(buildingData)

    if not predioIso then
        -- Sem IsoBuilding vanilla (construído por jogador ou área ao ar livre).
        -- Agrupa os consumidores de energia já escaneados por sala — mesma abordagem do
        -- CalculatePlayerBuiltHeating() da V1 — para um posicionamento de calor preciso por sala.
        local fallback = obterPosicoesDosBlocosConsumidor(buildingData)
        if fallback and #fallback > 0 then return fallback end

        -- Último recurso: ponto único no centro da caixa delimitadora
        if buildingData.boundingBox then
            local caixaDelimitadora = buildingData.boundingBox
            return {{
                roomID    = "Fallback",
                positions = {{
                    x = math.floor((caixaDelimitadora.minX + caixaDelimitadora.maxX) * 0.5),
                    y = math.floor((caixaDelimitadora.minY + caixaDelimitadora.maxY) * 0.5),
                    z = buildingData.z,
                }},
                z = buildingData.z,
            }}
        end
        return {}
    end

    local definicao = predioIso.getDef and predioIso:getDef()
    if not definicao then return {} end
    local salas = definicao.getRooms and definicao:getRooms()
    if not salas or salas:size() == 0 then return {} end

    local resultado = {}

    for indice = 0, salas:size() - 1 do
        local sala = salas:get(indice)
        if sala then
            -- getRooms() retorna objetos RoomDef, os quais possuem getZ() -> int diretamente.
            -- z=0 (piso térreo) salas usam buildingData.z como fallback de segurança.
            local zPiso = tonumber(sala:getZ()) or buildingData.z

            local posicoes = obterPosicoesDaSala(sala, zPiso)
            if #posicoes > 0 then
                local nomeSala = (sala.getName and sala:getName()) or ("Room_" .. indice)
                table.insert(resultado, {
                    roomID    = tostring(nomeSala),
                    positions = posicoes,
                    z         = zPiso,
                })
            end
        end
    end

    return resultado
end

-- ============================================================
-- SINCRONIZAÇÃO PARA GERADORES
-- ============================================================

function Heating.SyncToGenerators(buildingData)
    if not buildingData or not buildingData.connectedGenerators then return end

    local celula = getCell()
    if not celula then return end

    local posicoes = Heating.CalculatePositions(buildingData)
    if not posicoes or #posicoes == 0 then return end

    -- Calcula quantidade de fontes de aquecimento para persistência no GlobalModData
    local quantidadeFontes = 0
    for _, grupo in ipairs(posicoes) do
        if type(grupo.positions) == "table" then
            quantidadeFontes = quantidadeFontes + #grupo.positions
        end
    end

    -- Rastreia o estado de aquecimento do prédio a partir do primeiro gerador que conseguimos ler.
    -- Todos os geradores no mesmo pool compartilham as configurações de aquecimento do prédio,
    -- logo, o ModData do primeiro gerador é a autoridade para o prédio.
    local aquecimentoPredioAtivo = false
    local temperaturaAlvoPredio = TEMPERATURA_ALVO_PADRAO

    -- NOTA: connectedGenerators pode ser uma tabela desserializada pelo Kahlua com chaves numéricas string
    -- em vez de inteiras – o ipairs() não retornaria nada nesse caso.
    -- Use pairs() para visitar todos os geradores independentemente do tipo de chave.
    for _, chaveGerador in pairs(buildingData.connectedGenerators) do
        local coordX, coordY, coordZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if coordX then
            coordX, coordY, coordZ = tonumber(coordX), tonumber(coordY), tonumber(coordZ)
            local quadrado = celula:getGridSquare(coordX, coordY, coordZ)
            if quadrado then
                local objetos = quadrado:getObjects()
                for indice = 0, objetos:size() - 1 do
                    local gerador = objetos:get(indice)
                    if gerador and instanceof(gerador, "IsoGenerator") then
                        local modDataObj = gerador:getModData()
                        modDataObj.HeatingPositions = posicoes
                        -- Inicializa explicitamente HeatingEnabled=false no primeiro contato.
                        -- Nunca ative automaticamente; o aquecimento deve ser ligado intencionalmente pelo jogador.
                        -- Isso impede que a verificação de nulo no cliente ative o aquecimento automaticamente.
                        if modDataObj.HeatingEnabled == nil then
                            modDataObj.HeatingEnabled = false
                            if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                                gerador:transmitModData()
                            end
                        end
                        if modDataObj.HeatingTargetTemp == nil then
                            modDataObj.HeatingTargetTemp = TEMPERATURA_ALVO_PADRAO
                        end

                        -- Captura valores em nível de prédio a partir do moddata deste gerador
                        if modDataObj.HeatingEnabled == true then
                            aquecimentoPredioAtivo = true
                        end
                        temperaturaAlvoPredio = tonumber(modDataObj.HeatingTargetTemp) or TEMPERATURA_ALVO_PADRAO

                        -- Sincroniza config de aquecimento para o GeneratorData (GlobalModData) para cálculo independente de chunk
                        local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
                        if gerenciadorEstado then
                            local idGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(coordX, coordY, coordZ)
                            local dadosGerador = gerenciadorEstado.GetGenerator(idGerador)
                            if dadosGerador then
                                dadosGerador.heatingEnabled = (modDataObj.HeatingEnabled == true)
                                dadosGerador.heatingSourceCount = quantidadeFontes
                                dadosGerador.heatingTargetTemp = tonumber(modDataObj.HeatingTargetTemp) or TEMPERATURA_ALVO_PADRAO
                            end
                        end
                        
                        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                            gerador:transmitModData()
                        end
                        break
                    end
                end
            end
        end
    end

    -- Persiste o estado do aquecimento no próprio prédio.
    -- O aquecimento é um atributo do prédio/pool; CalculateFuelConsumption lê dele
    -- para que pools multi-geradores não contem o aquecimento duas vezes.
    --
    -- IMPORTANTE: Apenas sobrescreve buildingData.heatingEnabled quando de fato encontramos
    -- pelo menos um IsoGenerator no chunk. Se o chunk não estiver carregado na memória,
    -- o laço interno nunca é executado e não devemos sobrescrever os dados restaurados.
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
    if quantidadeFontes > 0 then
        -- As posições foram calculadas com sucesso → ambos os campos são renovados.
        buildingData.heatingEnabled      = aquecimentoPredioAtivo
        buildingData.heatingSourceCount  = quantidadeFontes
        buildingData.heatingTargetTemp   = temperaturaAlvoPredio
    else
        -- Não foi possível calcular posições (prédio ainda fora de chunk).
        -- Preserva o que estava armazenado no GlobalModData para não perturbar o consumo de combustível.
        if aquecimentoPredioAtivo then
            buildingData.heatingEnabled = true
        end
        if temperaturaAlvoPredio ~= TEMPERATURA_ALVO_PADRAO or buildingData.heatingTargetTemp == nil then
            buildingData.heatingTargetTemp = temperaturaAlvoPredio
        end
    end
    if gerenciadorEstado then
        gerenciadorEstado.MarkDirty()
    end
end

-- ============================================================
-- CICLO DE ATUALIZAÇÃO (chamado de EveryOneMinute em ServerInit)
-- ============================================================

function Heating.Update()
    if isClient() and not isServer() then return end

    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
    if not gerenciadorEstado then return end
    local predios = gerenciadorEstado.GetAllBuildings()
    if not predios then return end

    -- GetAllBuildings() retorna um hash-map indexado pelo ID do prédio – deve usar pairs()
    for _, buildingData in pairs(predios) do
        -- NOTE: connectedGenerators é um hash-map desserializado pelo Kahlua pós-recarregamento.
        -- O operador # retorna 0 para hash-maps. Use pairs() para testar não-vazio.
        if buildingData.connectedGenerators then
            local _possuiGeradores = false
            for _ in pairs(buildingData.connectedGenerators) do _possuiGeradores = true; break end
            if _possuiGeradores then
                Heating.SyncToGenerators(buildingData)
            end
        end
    end
end

-- ============================================================
-- INICIALIZAÇÃO
-- ============================================================

function Heating.Initialize()
    Logger.Info("Heating.Manager", "Gerenciador de Aquecimento inicializado.")
end

LKS_EletricidadeConstrucao.RegisterModule("Heating.Manager", "2.0.0")

return Heating
