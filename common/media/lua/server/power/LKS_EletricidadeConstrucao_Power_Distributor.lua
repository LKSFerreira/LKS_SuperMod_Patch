-- ============================================================================
-- 🌟 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL 🌟
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) por sua excelente contribuição à comunidade de Project Zomboid.
-- ============================================================================

-- LKS_EletricidadeConstrucao V2: Distribuidor de Energia (Power Distributor)
-- Objetivo: Distribuir energia de geradores ativos para os prédios conectados
-- Autor: Assistente de IA
-- Criado em: 2025

if not LKS_EletricidadeConstrucao then 
    print("[LKS_EletricidadeConstrucao_Power_Distributor] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return 
end

LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao or {}
LKS_EletricidadeConstrucao.Power = LKS_EletricidadeConstrucao.Power or {}
LKS_EletricidadeConstrucao.Power.Distributor = LKS_EletricidadeConstrucao.Power.Distributor or {}

local Distribuidor = LKS_EletricidadeConstrucao.Power.Distributor
local Registrador = LKS_EletricidadeConstrucao.Core.Logger
local GerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
-- NOTA: LKS_EletricidadeConstrucao.Power.Manager é carregado DEPOIS deste arquivo em ordem alfabética (Distributor=D < Manager=M),
-- por isso não podemos capturá-lo como uma variável local no carregamento do módulo. Use auxiliares inline.
local EscaneadorConsumidores = LKS_EletricidadeConstrucao.Building.ConsumerScanner
local CHAVE_SINCRONIZACAO_ENERGIA = "LKS_EletricidadeConstrucao_BuildingPowerSync"

local function copiarCaixaDelimitadora(origem)
    if not origem then return nil end
    return {
        minX = origem.minX,
        minY = origem.minY,
        maxX = origem.maxX,
        maxY = origem.maxY
    }
end

local function sincronizarEstadoEnergiaPredio(dadosPredio, estaEnergizado)
    if not LKS_EletricidadeConstrucao.IsMP or not LKS_EletricidadeConstrucao.IsMP() then
        return
    end
    if not dadosPredio or not dadosPredio.id or not dadosPredio.boundingBox then
        return
    end

    local pacote = ModData.getOrCreate(CHAVE_SINCRONIZACAO_ENERGIA)
    pacote.buildings = pacote.buildings or {}

    if estaEnergizado then
        pacote.buildings[dadosPredio.id] = {
            id = dadosPredio.id,
            x = dadosPredio.x,
            y = dadosPredio.y,
            z = dadosPredio.z or 0,
            boundingBox = copiarCaixaDelimitadora(dadosPredio.boundingBox)
        }
    else
        pacote.buildings[dadosPredio.id] = nil
    end

    ModData.add(CHAVE_SINCRONIZACAO_ENERGIA, pacote)
    ModData.transmit(CHAVE_SINCRONIZACAO_ENERGIA)
end

--- Auxiliar inline: encontra um IsoGenerator nas coordenadas do mundo (x, y, z)
local function encontrarGeradorEm(x, y, z)
    local celula = getCell()
    if not celula then return nil end
    local quadrado = celula:getGridSquare(x, y, z)
    if not quadrado then return nil end
    local objetos = quadrado:getObjects()
    for indice = 0, objetos:size() - 1 do
        local objeto = objetos:get(indice)
        if objeto and instanceof(objeto, "IsoGenerator") then return objeto end
    end
    return nil
end

local function tabelaContemValor(tabela, valor)
    if not tabela then return false end
    for _, v in pairs(tabela) do
        if v == valor then
            return true
        end
    end
    return false
end

local function tabelaEstaVazia(tabela)
    if not tabela then return true end
    for _ in pairs(tabela) do return false end
    return true
end

local function geradorPertenceAoPredio(idPredio, gerador, dadosGerador)
    if not idPredio then return false end

    if gerador then
        local dadosMod = gerador:getModData()
        if dadosMod and dadosMod.LKS_EletricidadeConstrucao_DisconnectSuppressed then
            return false
        end
        if dadosMod and dadosMod.Gen_BuildingPoolID == idPredio then
            return true
        end
    end

    return dadosGerador and dadosGerador.connectedBuildings
        and tabelaContemValor(dadosGerador.connectedBuildings, idPredio) or false
end

local function substituirEstadoGerador(dadosGerador)
    if not dadosGerador or not dadosGerador.id or not GerenciadorEstado then return end
    if GerenciadorEstado.RemoveGenerator then
        GerenciadorEstado.RemoveGenerator(dadosGerador.id)
    end
    if GerenciadorEstado.AddGenerator then
        GerenciadorEstado.AddGenerator(dadosGerador)
    end
end

local function removerLinksGeradoresObsoletos(dadosPredio)
    if not dadosPredio or not dadosPredio.connectedGenerators then
        return false
    end

    local celula = getCell()
    local alterado = false
    local quantidadeRemovidos = 0
    local reconstruido = {}
    local estadoCarregado = GerenciadorEstado and GerenciadorEstado.IsStateLoaded and GerenciadorEstado.IsStateLoaded()

    for _, chaveGerador in pairs(dadosPredio.connectedGenerators) do
        local manter = true
        local px, py, pz = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")

        if px then
            local gxi, gyi, gzi = tonumber(px), tonumber(py), tonumber(pz)
            if gxi and gyi and gzi then
                local idGerador = LKS_EletricidadeConstrucao.Data
                    and LKS_EletricidadeConstrucao.Data.Generator
                    and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                    and LKS_EletricidadeConstrucao.Data.Generator.MakeId(gxi, gyi, gzi)
                local dadosGerador = idGerador and GerenciadorEstado and GerenciadorEstado.GetGenerator and GerenciadorEstado.GetGenerator(idGerador) or nil
                local gerador = encontrarGeradorEm(gxi, gyi, gzi)
                local quadrado = celula and celula:getGridSquare(gxi, gyi, gzi) or nil

                if gerador then
                    manter = geradorPertenceAoPredio(dadosPredio.id, gerador, dadosGerador)
                    if not manter and dadosGerador and dadosGerador.connectedBuildings
                            and tabelaContemValor(dadosGerador.connectedBuildings, dadosPredio.id)
                            and LKS_EletricidadeConstrucao.Data
                            and LKS_EletricidadeConstrucao.Data.Generator
                            and LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding then
                        LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding(dadosGerador, dadosPredio.id)
                        substituirEstadoGerador(dadosGerador)
                    end
                elseif quadrado then
                    manter = false
                    if dadosGerador and dadosGerador.connectedBuildings
                            and tabelaContemValor(dadosGerador.connectedBuildings, dadosPredio.id)
                            and LKS_EletricidadeConstrucao.Data
                            and LKS_EletricidadeConstrucao.Data.Generator
                            and LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding then
                        LKS_EletricidadeConstrucao.Data.Generator.RemoveBuilding(dadosGerador, dadosPredio.id)
                    end
                    if dadosGerador then
                        if not dadosGerador.connectedBuildings or tabelaEstaVazia(dadosGerador.connectedBuildings) then
                            if GerenciadorEstado.RemoveGenerator and idGerador then
                                GerenciadorEstado.RemoveGenerator(idGerador)
                            end
                        else
                            substituirEstadoGerador(dadosGerador)
                        end
                    end
                elseif estadoCarregado and not dadosGerador then
                    manter = false
                elseif estadoCarregado and dadosGerador and not geradorPertenceAoPredio(dadosPredio.id, nil, dadosGerador) then
                    manter = false
                end
            end
        end

        if manter then
            table.insert(reconstruido, chaveGerador)
        else
            alterado = true
            quantidadeRemovidos = quantidadeRemovidos + 1
        end
    end

    if not alterado then
        return false
    end

    dadosPredio.connectedGenerators = reconstruido
    dadosPredio._syncWarningLogged = false

    if tabelaEstaVazia(reconstruido) then
        if GerenciadorEstado and GerenciadorEstado.RemoveBuilding then
            GerenciadorEstado.RemoveBuilding(dadosPredio.id)
        end
        Registrador.Info(string.format(
            "[SyncBuildingStats] Removido prédio obsoleto %s após podar %d link(s) de gerador",
            dadosPredio.id, quantidadeRemovidos), "Power")
        return true
    end

    if GerenciadorEstado and GerenciadorEstado.MarkDirty then
        GerenciadorEstado.MarkDirty()
    end
    Registrador.Warn(string.format(
        "[SyncBuildingStats] Podado(s) %d link(s) de gerador obsoleto(s) do prédio %s",
        quantidadeRemovidos, dadosPredio.id), "Power")
    return false
end

--- Auxiliar inline: retorna true se o prédio tem pelo menos um gerador ativado.
--- Utiliza dadosPredio.connectedGenerators (lista de chaves "x_y_z" configurada pela ação de conexão).
local function predioTemEnergiaInline(dadosPredio)
    if not dadosPredio or not dadosPredio.connectedGenerators then return false end
    local celula = getCell()
    if not celula then return false end
    -- Fallback do GerenciadorEstado para geradores fora de chunks carregados.
    -- Quando o chunk de um gerador não está carregado, celula:getGridSquare retorna nil e o
    -- IsoGenerator ativo fica inacessível. Sem um fallback, ForceUpdateBuilding chamado
    -- enquanto os geradores estão fora de chunks carregados retorna isPowered=false, o que desativa
    -- todos os consumidores de luz e remove a energia do ladrilho mesmo que os geradores ESTEJAM funcionando (correção do bug B-59).
    local SM = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    -- connectedGenerators é desserializado pelo Kahlua (chaves numéricas em string)
    for _, gk in pairs(dadosPredio.connectedGenerators) do
        local gx, gy, gz = string.match(gk, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if gx then
            local gxi, gyi, gzi = tonumber(gx), tonumber(gy), tonumber(gz)
            if gxi and gyi and gzi then
                local idGerador = LKS_EletricidadeConstrucao.Data
                          and LKS_EletricidadeConstrucao.Data.Generator
                          and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                          and LKS_EletricidadeConstrucao.Data.Generator.MakeId(gxi, gyi, gzi)
                local dadosGerador = idGerador and SM and SM.GetGenerator and SM.GetGenerator(idGerador) or nil
                -- Primário: objeto IsoGenerator ativo no jogo (autoritativo quando no chunk carregado)
                local quadrado = celula:getGridSquare(gxi, gyi, gzi)
                if quadrado then
                    local objetos = quadrado:getObjects()
                    for indice = 0, objetos:size() - 1 do
                        local objeto = objetos:get(indice)
                        if objeto and instanceof(objeto, "IsoGenerator") and objeto:isActivated()
                                and geradorPertenceAoPredio(dadosPredio.id, objeto, dadosGerador) then
                            return true
                        end
                    end
                    -- Quadrado carregado mas nenhum gerador ativo encontrado → não energizado por este gerador
                else
                    -- Quadrado não carregado (gerador fora do chunk carregado): recorre ao estado em GlobalModData.
                    -- dadosGerador.activated é definido como false apenas quando o combustível acaba; nil significa ativo.
                    if SM then
                        local idGeradorParaMod = LKS_EletricidadeConstrucao.Data
                                  and LKS_EletricidadeConstrucao.Data.Generator
                                  and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                                  and LKS_EletricidadeConstrucao.Data.Generator.MakeId(gxi, gyi, gzi)
                        if idGeradorParaMod then
                            if dadosGerador
                               and geradorPertenceAoPredio(dadosPredio.id, nil, dadosGerador)
                               and (dadosGerador.activated ~= false)
                               and (dadosGerador.fuelAmount or 0) > 0 then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

--- Aplica ou remove energia de gerador de cada ladrilho (tile) na caixa delimitadora do prédio.
--- Espelha a abordagem de PowerSquare / chunk:addGeneratorPos do V1: é o que o PZ usa
--- internamente para marcar os quadrados como eletricamente ativos, alimentando luzes e aparelhos.
--- @param dadosPredio BuildingData
--- @param estaEnergizado boolean
local function aplicarEnergiaLadrilhos(dadosPredio, estaEnergizado)
    local bb = dadosPredio.boundingBox
    if not bb then return end

    local quadradoAncora = getSquare(dadosPredio.x, dadosPredio.y, dadosPredio.z or 0)
    local predioAncora = quadradoAncora and quadradoAncora:getBuilding() or nil

    local baseZ = dadosPredio.z
    local minZ  = math.max(0, baseZ - 3)
    local maxZ  = baseZ + 10
    local tamanhoChunk = getChunkSizeInSquares and getChunkSizeInSquares() or 10

    local totalLadrilhos = 0
    local chunksAfetados = {}
    for tx = bb.minX, bb.maxX do
        for ty = bb.minY, bb.maxY do
            for tz = minZ, maxZ do
                local quadrado = getSquare(tx, ty, tz)
                if quadrado then
                    local predioQuadrado = quadrado:getBuilding()
                    if not predioAncora or predioQuadrado == nil or predioQuadrado == predioAncora then
                        local chunk = quadrado:getChunk()
                        if chunk then
                            if estaEnergizado then
                                chunk:addGeneratorPos(tx, ty, tz)
                            else
                                chunk:removeGeneratorPos(tx, ty, tz)
                            end

                            if quadrado.RecalcAllWithNeighbours then
                                quadrado:RecalcAllWithNeighbours(false)
                            end

                            local chaveChunk = math.floor(tx / tamanhoChunk) .. "," .. math.floor(ty / tamanhoChunk)
                            chunksAfetados[chaveChunk] = chunk
                            totalLadrilhos = totalLadrilhos + 1
                        end
                    end
                end
            end
        end
    end

    local quantidadeChunksAfetados = 0
    for _, chunk in pairs(chunksAfetados) do
        quantidadeChunksAfetados = quantidadeChunksAfetados + 1
        if chunk.recalcHashCodeObjects then
            chunk:recalcHashCodeObjects()
        end
        if isServer() and chunk.transmitCompleteChunk then
            chunk:transmitCompleteChunk()
        end
    end

    sincronizarEstadoEnergiaPredio(dadosPredio, estaEnergizado)

    Registrador.Info(string.format("aplicarEnergiaLadrilhos: %s %d ladrilhos em %d chunks para o predio %s",
        estaEnergizado and "energizou" or "desenergizou", totalLadrilhos, quantidadeChunksAfetados, dadosPredio.id), "Power")
end

--------------------------------------------------------------------------------
-- CONSTANTES
--------------------------------------------------------------------------------

Distribuidor.UPDATE_INTERVAL = 10  -- Atualiza o estado da energia a cada 10 segundos
-- Reescaneia se o consumidor está ativo (isActive) via getSquare() a cada N segundos reais.
-- Este é o loop pesado com 94 chamadas à ponte Java (getSquare + getObjects por consumidor).
-- Só precisamos dele na frequência de exibição da interface, não a cada verificação de energia.
-- Mudanças no estado de energia (stateChanged==true) sempre forçam um reescaneamento completo.
Distribuidor.CONSUMER_REFRESH_INTERVAL = 60
Distribuidor.DEBUG = false

--------------------------------------------------------------------------------
-- ESTADO
--------------------------------------------------------------------------------

-- Timestamp da última atualização
Distribuidor.lastUpdate = 0

-- Última vez que os estados isActive dos consumidores foram atualizados via getSquare() / getObjects()
Distribuidor.lastConsumerRefresh = 0

-- Cache do estado da energia: buildingId -> isPowered
Distribuidor.powerStateCache = {}

-- Fila de tentativas: buildingId -> retriesLeft (para ForceUpdateBuilding quando o prédio não está no estado ainda)
-- Preenchida quando o prédio não é encontrado na primeira tentativa (ex: logo após teleporte/carregamento de chunk).
-- Esvaziada por ProcessRetryQueue() que é chamada a cada tick do EveryOneMinute.
Distribuidor._retryQueue = {}

--------------------------------------------------------------------------------
-- INICIALIZAÇÃO
--------------------------------------------------------------------------------

--- Inicializa o Distribuidor de Energia
function Distribuidor.Initialize()
    Registrador.Info("Inicializando Distribuidor de Energia...", "Power")
    
    Distribuidor.powerStateCache = {}
    Distribuidor.lastUpdate = 0
    Distribuidor.lastConsumerRefresh = 0
    Distribuidor._retryQueue = {}
    
    Registrador.Info("Distribuidor de Energia inicializado.", "Power")
end

--------------------------------------------------------------------------------
-- SINCRONIZAÇÃO DE ESTATÍSTICAS AO MODDATA DO GERADOR (lido pela interface do cliente)
--------------------------------------------------------------------------------

local function contarGeradoresAtivosDiretos(dadosPredio)
    local ativosContagem = 0

    for _, chaveGerador in pairs(dadosPredio and dadosPredio.connectedGenerators or {}) do
        local px, py, pz = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            local gxi, gyi, gzi = tonumber(px), tonumber(py), tonumber(pz)
            if gxi and gyi and gzi then
                local gerador = encontrarGeradorEm(gxi, gyi, gzi)
                local idGerador = LKS_EletricidadeConstrucao.Data
                          and LKS_EletricidadeConstrucao.Data.Generator
                          and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                          and LKS_EletricidadeConstrucao.Data.Generator.MakeId(gxi, gyi, gzi)
                local dadosGerador = idGerador and GerenciadorEstado and GerenciadorEstado.GetGenerator and GerenciadorEstado.GetGenerator(idGerador) or nil
                if gerador and gerador:isActivated() and (gerador:getFuel() or 0) > 0
                        and geradorPertenceAoPredio(dadosPredio.id, gerador, dadosGerador) then
                    ativosContagem = ativosContagem + 1
                end
            end
        end
    end

    return ativosContagem
end

local function obterEstatisticasExibicaoGerador(dadosPredio, chaveGerador, consumoCargaFiltro, contagemAtivosFallback)
    local geradoresAtivosPool = contagemAtivosFallback or 1
    local sobrecarga = 0

    local px, py, pz = string.match(chaveGerador or "", "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
    local gxi = px and tonumber(px) or nil
    local gyi = py and tonumber(py) or nil
    local gzi = pz and tonumber(pz) or nil
    if gxi and gyi and gzi and GerenciadorEstado and LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator then
        local idGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(gxi, gyi, gzi)
        local gd = GerenciadorEstado.GetGenerator(idGerador)
        if gd then
            local geradoresAtivosContados = 0
            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators then
                geradoresAtivosContados = LKS_EletricidadeConstrucao.Fuel.Manager.CountActivePoolGenerators(gd) or 0
            end
            if geradoresAtivosContados < 1 then
                geradoresAtivosContados = gd["cachedPoolActive"] or 0
            end
            if geradoresAtivosContados > 0 then
                geradoresAtivosPool = geradoresAtivosContados
            end

            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.StrainCalculator and LKS_EletricidadeConstrucao.Fuel.StrainCalculator.CalculateStrain then
                sobrecarga = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.CalculateStrain(gd, nil, geradoresAtivosPool) or 0
            end
        end
    end

    if geradoresAtivosPool < 1 then geradoresAtivosPool = 1 end

    local cargaCompartilhada = consumoCargaFiltro / geradoresAtivosPool

    if sobrecarga <= 0
       and cargaCompartilhada > 0
       and LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.StrainCalculator
       and LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PowerDrawToStrain then
        sobrecarga = LKS_EletricidadeConstrucao.Fuel.StrainCalculator.PowerDrawToStrain(cargaCompartilhada) or 0
    end

    if sobrecarga < 0.5 then sobrecarga = 0 end

    return cargaCompartilhada, math.max(0, math.floor(sobrecarga + 0.5))
end

local function construirInstantaneoEstatisticasBarris(dadosPredio)
    local dadosBarris = {}
    local contagemBarris = 0
    local combustivelTotal = 0
    local Barris = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels

    if not dadosPredio or not dadosPredio.id or not Barris or not Barris.GetLinkedBarrels then
        return dadosBarris, contagemBarris, combustivelTotal
    end

    local sucesso, barrisConectados = pcall(Barris.GetLinkedBarrels, dadosPredio.id)
    if not sucesso or type(barrisConectados) ~= "table" then
        return dadosBarris, contagemBarris, combustivelTotal
    end

    for _, barril in ipairs(barrisConectados) do
        local quadrado = barril and barril.getSquare and barril:getSquare() or nil
        if quadrado then
            local quantidade = Barris.GetPetrolAmount and (Barris.GetPetrolAmount(barril) or 0) or 0
            local capacidadeMaxima = 25
            if barril.getFluidContainer then
                local okFc, fc = pcall(function() return barril:getFluidContainer() end)
                if okFc and fc then
                    local okCap, cap = pcall(function() return fc:getCapacity() end)
                    if okCap and cap and cap > 0 then
                        capacidadeMaxima = cap
                    end
                end
            end

            local nomeSprite = nil
            local okSprite, sprite = pcall(function()
                if barril.getSpriteName then return barril:getSpriteName() end
                if barril.getSprite and barril:getSprite() then return barril:getSprite():getName() end
            end)
            if okSprite then nomeSprite = sprite end

            contagemBarris = contagemBarris + 1
            combustivelTotal = combustivelTotal + quantidade
            dadosBarris[contagemBarris] = {
                x = quadrado:getX(),
                y = quadrado:getY(),
                z = quadrado:getZ(),
                amount = quantidade,
                maxAmount = capacidadeMaxima,
                sprite = nomeSprite,
            }
        end
    end

    return dadosBarris, contagemBarris, combustivelTotal
end

--- Escreve as estatísticas do prédio no ModData do gerador conectado para que o cliente
--- possa exibi-las na Janela de Informações sem precisar de acesso ao estado do servidor.
--- Chamado a cada ciclo de atualização da distribuição (~10 s).
local function sincronizarEstatisticasPredioAoGerador(dadosPredio)
    if not dadosPredio then return end

    -- Conta consumidores por tipo (total + ativo)
    local contagemConsumidores       = 0
    local contagemLuzes              = 0  -- inclui luzes fixas e lâmpadas portáteis (mescladas)
    local contagemAparelhos          = 0
    local contagemLuzesAtivas        = 0
    local contagemAparelhosAtivos    = 0
    local consumoEnergia             = dadosPredio.totalPowerDraw or 0

    -- Para o cálculo de sobrecarga, usa o consumo de carga em cache para que fique consistente fora do chunk
    -- (quando desligado da energia, totalPowerDraw encolhe conforme os consumidores ficam inativos)
    local consumoCargaFiltro         = dadosPredio.strainTotalPowerDraw or consumoEnergia

    if dadosPredio.powerConsumers then
        -- powerConsumers é desserializado pelo Kahlua (chaves numéricas em string); pairs necessário
        for _, c in pairs(dadosPredio.powerConsumers) do
            contagemConsumidores = contagemConsumidores + 1
            local t = c.objectType or ""
            if t == "light" or t == "lamp" then
                -- "lamp" (lâmpadas portáteis de chão/mesa) é tratada de forma idêntica a
                -- "light" (luminárias fixas de teto/parede) porque ambas usam a mesma taxa
                -- de combustível e a interface as exibe juntas como "Luzes".
                contagemLuzes = contagemLuzes + 1
                if c.isActive then contagemLuzesAtivas = contagemLuzesAtivas + 1 end
            elseif t == "appliance" then
                contagemAparelhos = contagemAparelhos + 1
                if c.isActive then contagemAparelhosAtivos = contagemAparelhosAtivos + 1 end
            end
        end
    end

    if removerLinksGeradoresObsoletos(dadosPredio) then
        return
    end

    if not dadosPredio.connectedGenerators or tabelaEstaVazia(dadosPredio.connectedGenerators) then
        return
    end

    local fallbackGeradoresAtivos = contarGeradoresAtivosDiretos(dadosPredio)
    if fallbackGeradoresAtivos < 1 then fallbackGeradoresAtivos = 1 end
    local dadosBarris, contagemBarris, combustivelTotalBarris = construirInstantaneoEstatisticasBarris(dadosPredio)

    -- Encontra geradores conectados através da lista em tempo de execução connectedGenerators (chaves "x_y_z")
    if not dadosPredio.connectedGenerators then return end

    -- Lê a taxa de combustível de todo o pool a partir do primeiro gerador ATIVO (ou 0 se nenhum estiver ativo).
    -- Todos os geradores do pool devem mostrar a mesma taxa, independentemente do seu estado ativo individual.
    local taxaCombustivelPoolLph = 0
    -- connectedGenerators é desserializado pelo Kahlua (chaves numéricas em string)
    for _, chaveGerador in pairs(dadosPredio.connectedGenerators) do
        local px, py, pz = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            local gerador = encontrarGeradorEm(tonumber(px), tonumber(py), tonumber(pz))
            if gerador and gerador:isActivated() then
                taxaCombustivelPoolLph = gerador:getModData().Gen_Stats_FuelRateLph or 0
                break  -- Usa a taxa do primeiro gerador ativo para todo o pool
            end
        end
    end

    -- Escreve as estatísticas do pool em TODOS os geradores (ativos ou inativos)
    local quantidadeSincronizados = 0
    local quantidadePulados = 0
    for _, chaveGerador in pairs(dadosPredio.connectedGenerators) do
        local px, py, pz = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if px then
            local gerador = encontrarGeradorEm(tonumber(px), tonumber(py), tonumber(pz))
            if gerador then
                local md = gerador:getModData()
                local cargaCompartilhada, sobrecargaInt = obterEstatisticasExibicaoGerador(
                    dadosPredio,
                    chaveGerador,
                    consumoCargaFiltro,
                    fallbackGeradoresAtivos)
                
                -- Usa a taxa de combustível do pool (de qualquer gerador ativo no pool)
                md.Gen_Stats_Consumers          = contagemConsumidores
                md.Gen_Stats_ActiveConsumers    = dadosPredio.activeConsumerCount or 0
                md.Gen_Stats_Lights             = contagemLuzes   -- inclui lâmpadas portáteis (mescladas)
                md.Gen_Stats_ActiveLights       = contagemLuzesAtivas
                md.Gen_Stats_Lamps              = nil             -- descontinuado; mesclado em Lights
                md.Gen_Stats_ActiveLamps        = nil
                md.Gen_Stats_Appliances         = contagemAparelhos
                md.Gen_Stats_ActiveAppliances   = contagemAparelhosAtivos
                md.Gen_Stats_PowerDraw          = cargaCompartilhada
                md.Gen_Stats_Strain             = sobrecargaInt
                md.Gen_Stats_FuelRateLph        = taxaCombustivelPoolLph  -- Mesmo valor de pool para todos
                md.Gen_Stats_Powered            = dadosPredio.isPowered or false
                md.Gen_Stats_BarrelCount        = contagemBarris
                md.Gen_Stats_BarrelTotalFuel    = combustivelTotalBarris
                md.Gen_Stats_BarrelData         = contagemBarris > 0 and dadosBarris or nil
                md.Gen_BuildingPoolID           = dadosPredio.id  -- carimbo para busca na interface do cliente
                local idMundoAtual = LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId and
                                     LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId() or nil
                if idMundoAtual and idMundoAtual ~= "unknown" then
                    md.LKS_EletricidadeConstrucao_WorldId = idMundoAtual
                end
                
                -- Sincroniza com os clientes no MP (sem efeito no SP)
                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                    gerador:transmitModData()
                end
                quantidadeSincronizados = quantidadeSincronizados + 1
            else
                quantidadePulados = quantidadePulados + 1
                -- Avisa apenas no primeiro salto para não inundar os logs
                if not dadosPredio._syncWarningLogged then
                    Registrador.Warn(string.format(
                        "[SyncBuildingStats] Gerador em %s não encontrado (chunk não carregado?) - prédio %s tem %d consumidores aguardando",
                        chaveGerador, dadosPredio.id, contagemConsumidores), "Power")
                    dadosPredio._syncWarningLogged = true
                end
            end
        end
    end
    
    -- Loga apenas se geradores foram pulados (caso problemático) ou se for a primeira sincronização bem-sucedida após falhas
    if quantidadePulados > 0 then
        Registrador.Warn(string.format(
            "[SyncBuildingStats] Prédio %s: sincronizou %d/%d geradores - %d geradores inalcançáveis (chunk não carregado)",
            dadosPredio.id, quantidadeSincronizados, quantidadeSincronizados + quantidadePulados, quantidadePulados), "Power")
    elseif quantidadeSincronizados > 0 and dadosPredio._syncWarningLogged then
        -- Primeira sincronização bem-sucedida após falhas anteriores - loga o sucesso
        Registrador.Info(string.format(
            "[SyncBuildingStats] Prédio %s: TODOS os geradores agora estão acessíveis - sincronizou %d consumidores com sucesso",
            dadosPredio.id, contagemConsumidores), "Power")
        dadosPredio._syncWarningLogged = false
    end
end

--------------------------------------------------------------------------------
-- DISTRIBUIÇÃO DE ENERGIA
--------------------------------------------------------------------------------

-- Lê o estado ligado/desligado de IsoRadio / IsoTelevision através da API DeviceData do PZ 42.
-- Tanto TVs geradas pelo mundo (IsoRadio com IsTelevision=true) quanto TVs portáteis
-- (IsoTelevision) armazenam seu estado ligado em DeviceData:getIsTurnedOn().
local function radioEstaLigado(objeto)
    if objeto.getDeviceData then
        local dadosDispositivo = objeto:getDeviceData()
        if dadosDispositivo and dadosDispositivo.getIsTurnedOn then
            return dadosDispositivo:getIsTurnedOn()
        end
    end
    return false
end

-- Verifica se um aparelho específico em um quadrado está ativo (ligado pelo usuário).
-- Geladeiras/freezers estão sempre ativos quando alimentados; TVs, fogões e rádios
-- expõem um estado ligado/desligado através da API do PZ.
-- @param quadrado IsoGridSquare Quadrado onde o aparelho está localizado
-- @param estaEnergizado boolean Se o prédio tem energia no momento
-- @return boolean
local function obterEstadoAtivoEletrodomestico(quadrado, estaEnergizado)
    if not estaEnergizado then return false end
    if not quadrado then return estaEnergizado end
    local objetos = quadrado:getObjects()
    if not objetos then return estaEnergizado end
    for indice = 0, objetos:size() - 1 do
        local objeto = objetos:get(indice)
        if objeto then
            -- Televisão: estado ligado/desligado (IsoTelevision portátil)
            if instanceof(objeto, "IsoTelevision") then
                return radioEstaLigado(objeto)
            end
            -- Rádio / TV gerada pelo mundo (IsoRadio com IsTelevision=true)
            if instanceof(objeto, "IsoRadio") then
                return radioEstaLigado(objeto)
            end
            -- Fogão: ativo se qualquer queimador estiver funcionando no momento
            if instanceof(objeto, "IsoStove") then
                if objeto.Activated then
                    return objeto:Activated()
                end
                return estaEnergizado
            end
            -- Máquina de lavar / secadora: ativa quando o ciclo está rodando (API setActivated/isActivated)
            if instanceof(objeto, "IsoClothingDryer")
            or instanceof(objeto, "IsoClothingWasher")
            or instanceof(objeto, "IsoCombinationWasherDryer")
            or instanceof(objeto, "IsoStackedWasherDryer") then
                return objeto.isActivated and objeto:isActivated() or false
            end
            -- Secadora/lavadora gerada pelo mundo: IsoThumpable com container clothingdryer/clothingwasher
            if objeto.getContainerByType then
                if objeto:getContainerByType("clothingdryer")  ~= nil
                or objeto:getContainerByType("clothingwasher") ~= nil then
                    return objeto.isActivated and objeto:isActivated() or false
                end
                -- Geladeira / freezer: sempre ativos quando energizados
                if objeto:getContainerByType("fridge")  ~= nil
                or objeto:getContainerByType("freezer") ~= nil then
                    return true
                end
            end
        end
    end
    return estaEnergizado  -- fallback para aparelhos apenas com sprite ou desconhecidos
end

--- Atualiza o estado da energia para um único prédio
-- @param dadosPredio BuildingData objeto
-- @param atualizarConsumidores boolean Quando true, reescaneia o isActive dos consumidores via getSquare()/getObjects().
--   Definido como true periodicamente (CONSUMER_REFRESH_INTERVAL) ou sempre em mudanças de estado de energia.
--   Ignorado (false) durante atualizações rápidas em estado estável para evitar 94 chamadas de ponte Java por tick.
-- @return boolean True se o estado de energia foi alterado
function Distribuidor.UpdateBuildingPower(dadosPredio, atualizarConsumidores)
    if not dadosPredio then
        Registrador.Error("UpdateBuildingPower: dadosPredio e nil", "Power")
        return false
    end
    
    -- Verifica se o prédio tem energia (inline: evita dependência de ordem de carregamento com LKS_EletricidadeConstrucao.Power.Manager)
    local estaEnergizado = predioTemEnergiaInline(dadosPredio)
    
    -- Obtém estado de energia em cache
    local estadoEmCache = Distribuidor.powerStateCache[dadosPredio.id]
    
    -- Verifica se o estado de energia mudou
    local estadoMudou = (estadoEmCache ~= estaEnergizado)
    
    -- Loga apenas transições significativas (não nil -> X)
    if estadoMudou and estadoEmCache ~= nil then
        Registrador.Info(string.format(
            "Estado de energia do prédio %s mudou: %s -> %s",
            dadosPredio.id,
            tostring(estadoEmCache),
            tostring(estaEnergizado)
        ), "Power")
    end
    
    -- Aplica eletricidade no nível do ladrilho através da API de chunk do PZ (espelha PowerSquare do V1).
    -- É isso que realmente alimenta luzes e aparelhos no mundo do jogo.
    -- Aplica apenas quando o estado mudar para evitar escritas redundantes em chunks a cada tick.
    if estadoMudou then
        aplicarEnergiaLadrilhos(dadosPredio, estaEnergizado)
    end

    -- Atualiza as flags isActive dos consumidores para a interface (luzes/contagem/sobrecarga).
    -- Isso NÃO altera os objetos do mundo; apenas atualiza nosso rastreamento interno.
    -- Ignorado quando o estado de energia não mudou e atualizarConsumidores=false para evitar
    -- disparar 94 chamadas getSquare()/getObjects() na ponte Java a cada tick de 10 segundos.
    -- atualizarConsumidores é definido como true a cada CONSUMER_REFRESH_INTERVAL (60 s) para manter as
    -- estatísticas precisas para a interface. Mudanças no estado de energia sempre forçam um reescaneamento completo.
    if dadosPredio.powerConsumers and (estadoMudou or atualizarConsumidores) then
        local quantidadeAtualizados = 0
        -- Rastreia se pelo menos um quadrado estava carregado neste ciclo de atualização.
        -- Usado após o loop para armazenar strainTotalPowerDraw em cache apenas quando dentro do chunk carregado
        -- (atualizações fora do chunk devem preservar o último valor correto em cache).
        local qualquerQuadradoCarregado = false
        
        -- powerConsumers é desserializado pelo Kahlua (chaves numéricas em string); pairs necessário
        for _, dadosConsumidor in pairs(dadosPredio.powerConsumers) do
            -- Atualiza isActive: verifica o estado real do IsoLightSwitch para
            -- consumidores de luz para que a ativação do interruptor seja refletida no activeConsumerCount.
            local quadrado = getSquare(dadosConsumidor.squareX, dadosConsumidor.squareY, dadosConsumidor.squareZ)
            if quadrado then
                qualquerQuadradoCarregado = true
                if estaEnergizado and dadosConsumidor.objectType == "light" then
                    -- Percorre objetos no quadrado deste consumidor:
                    --   IsoLightSwitch → ativo apenas se o interruptor estiver ligado
                    --   IsoLight (luminária de teto) → sempre ativo quando o prédio tem energia
                    --   Ladrilho de cômodo apenas sprite → assume ativo quando energizado
                    local luzAtiva = true   -- padrão: ligada quando energizado
                    local objetos = quadrado:getObjects()
                    if objetos then
                        for indice = 0, objetos:size() - 1 do
                            local objeto = objetos:get(indice)
                            if objeto then
                                if instanceof(objeto, "IsoLightSwitch") then
                                    -- Interruptor encontrado: respeita seu estado real ligado/desligado
                                    luzAtiva = objeto.isActivated and objeto:isActivated() or false
                                    break
                                end
                            end
                        end
                    end
                    dadosConsumidor.isActive = luzAtiva
                elseif dadosConsumidor.objectType == "appliance" then
                    -- Verifica o estado real de ligado/desligado do eletrodoméstico
                    dadosConsumidor.isActive = obterEstadoAtivoEletrodomestico(quadrado, estaEnergizado)
                else
                    -- Lâmpadas / outros: ativos sempre que o prédio tem energia
                    dadosConsumidor.isActive = estaEnergizado
                end
            else
                -- Quadrado não carregado na memória (chunk descarregado ou limite de chunk).
                -- Aplica padrões seguros para que as estatísticas não fiquem silenciosamente erradas:
                --   Luzes / lâmpadas: vincula diretamente a se o prédio tem energia.
                --   Eletrodomesticos: preserva o último valor isActive persistido para que
                --                     ex: geladeiras (sempre true) e fogões desligados (false)
                --                     fiquem corretos até o chunk carregar e uma verificação
                --                     apropriada rodar através do próximo ForceUpdateBuilding.
                if dadosConsumidor.objectType == "light" or dadosConsumidor.objectType == "lamp" then
                    dadosConsumidor.isActive = estaEnergizado
                end
                -- objectType == "appliance": deixado inalterado intencionalmente (mantém estado salvo)
            end
            quantidadeAtualizados = quantidadeAtualizados + 1
        end

        -- Atualiza totalPowerDraw e activeConsumerCount após atualizar isActive
        LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(dadosPredio)

        -- Armazena o consumo de carga autorizado em cache para cálculos de sobrecarga fora do chunk.
        -- Atualiza apenas quando os quadrados do chunk estavam acessíveis neste ciclo (qualquerQuadradoCarregado)
        -- para que os ticks fora do chunk preservem o último valor correto dentro do chunk em vez
        -- de acidentalmente voltarem ao consumo base bruto da varredura inicial (todos os consumidores no consumo base).
        if estaEnergizado and qualquerQuadradoCarregado and (dadosPredio.totalPowerDraw or 0) > 0 then
            dadosPredio.strainTotalPowerDraw = dadosPredio.totalPowerDraw
        end
        
        if Distribuidor.DEBUG or estadoMudou then
            local pc = 0
            if dadosPredio.powerConsumers then
                for _ in pairs(dadosPredio.powerConsumers) do pc = pc + 1 end
            end
            Registrador.Debug(string.format(
                "Atualizados %d/%d consumidores no prédio %s (energizado: %s)",
                quantidadeAtualizados,
                pc,
                dadosPredio.id,
                tostring(estaEnergizado)
            ), "Power")
        end
    end
    
    -- Atualiza o campo isPowered do prédio
    dadosPredio.isPowered = estaEnergizado
    
    -- Update cache
    Distribuidor.powerStateCache[dadosPredio.id] = estaEnergizado
    
    return estadoMudou
end

--- Atualiza a distribuição de energia para todos os prédios
-- @param atualizarConsumidores boolean Quando true, reescaneia o isActive de cada consumidor via busca no mundo.
--   Deve ser true na primeira chamada, após um ForceUpdate ou quando CONSUMER_REFRESH_INTERVAL expirar.
-- @return table Estatísticas: { totalBuildings, LKS_EletricidadeConstrucao, unLKS_EletricidadeConstrucao, stateChanges, consumersUpdated }
function Distribuidor.UpdateAllBuildings(atualizarConsumidores)
    local estatisticas = {
        totalBuildings = 0,
        LKS_EletricidadeConstrucao = 0,
        unLKS_EletricidadeConstrucao = 0,
        stateChanges = 0,
        consumersUpdated = 0
    }
    
    -- Obtém todos os prédios (retorna um mapa: buildingId -> buildingData)
    local predios = GerenciadorEstado.GetAllBuildings()
    if not predios then
        Registrador.Warn("UpdateAllBuildings: Nenhum predio encontrado", "Power")
        return estatisticas
    end
    
    -- Atualiza cada prédio (usa pairs - predios é um mapa, não um array)
    for _, dadosPredio in pairs(predios) do
        estatisticas.totalBuildings = estatisticas.totalBuildings + 1
        local estadoMudou = Distribuidor.UpdateBuildingPower(dadosPredio, atualizarConsumidores)
        
        if estadoMudou then
            estatisticas.stateChanges = estatisticas.stateChanges + 1
        end
        
        if dadosPredio.isPowered then
            estatisticas.LKS_EletricidadeConstrucao = estatisticas.LKS_EletricidadeConstrucao + 1
        else
            estatisticas.unLKS_EletricidadeConstrucao = estatisticas.unLKS_EletricidadeConstrucao + 1
        end
        
        if dadosPredio.powerConsumers then
            local pc = 0
            for _ in pairs(dadosPredio.powerConsumers) do pc = pc + 1 end
            estatisticas.consumersUpdated = estatisticas.consumersUpdated + pc
        end

        -- Sincroniza estatísticas com o ModData do gerador para que a interface do cliente possa lê-las
        sincronizarEstatisticasPredioAoGerador(dadosPredio)
    end

    return estatisticas
end

--- Atualização periódica (chamada a partir do tick do servidor)
-- @param tempoAtual number Timestamp atual
function Distribuidor.Update(tempoAtual)
    tempoAtual = tempoAtual or os.time()
    
    -- Verifica se o intervalo de atualização passou
    if tempoAtual - Distribuidor.lastUpdate >= Distribuidor.UPDATE_INTERVAL then
        -- B-98: Apenas reescaneia o isActive (getSquare/getObjects) dos consumidores a cada CONSUMER_REFRESH_INTERVAL.
        -- No estado estável (prédio energizado, sem mudança) isso evita ~94 chamadas de ponte Java por tick de 10s.
        local atualizarConsumidores = (tempoAtual - Distribuidor.lastConsumerRefresh >= Distribuidor.CONSUMER_REFRESH_INTERVAL)

        local estatisticas = Distribuidor.UpdateAllBuildings(atualizarConsumidores)

        if atualizarConsumidores then
            Distribuidor.lastConsumerRefresh = tempoAtual
        end
        
        if Distribuidor.DEBUG or estatisticas.stateChanges > 0 then
            Registrador.Info(string.format(
                "Atualização da distribuição de energia: %d prédios (%d energizados, %d sem energia), %d mudanças de estado, %d consumidores atualizados",
                estatisticas.totalBuildings,
                estatisticas.LKS_EletricidadeConstrucao,
                estatisticas.unLKS_EletricidadeConstrucao,
                estatisticas.stateChanges,
                estatisticas.consumersUpdated
            ), "Power")
        end
        
        Distribuidor.lastUpdate = tempoAtual
    end
end

--------------------------------------------------------------------------------
-- OPERAÇÕES MANUAIS
--------------------------------------------------------------------------------

--- Força atualização imediata de energia para todos os prédios
function Distribuidor.ForceUpdate()
    Registrador.Info("ForceUpdate: Forcando atualizacao imediata da distribuicao de energia...", "Power")
    
    -- Sempre atualiza o isActive dos consumidores em uma atualização forçada para que a interface veja o estado atualizado
    local estatisticas = Distribuidor.UpdateAllBuildings(true)
    
    Registrador.Info(string.format(
        "ForceUpdate concluído: %d prédios (%d energizados, %d sem energia), %d mudanças de estado, %d consumidores atualizados",
        estatisticas.totalBuildings,
        estatisticas.LKS_EletricidadeConstrucao,
        estatisticas.unLKS_EletricidadeConstrucao,
        estatisticas.stateChanges,
        estatisticas.consumersUpdated
    ), "Power")
    
    local agora = os.time()
    Distribuidor.lastUpdate = agora
    Distribuidor.lastConsumerRefresh = agora
end

--- Auxiliar interno: tenta uma atualização completa de energia para um único prédio por dados.
--- NÃO enfileira uma nova tentativa em caso de falha — os chamadores decidem isso.
--- @param dadosPredio BuildingData
--- @param forcarAtualizacaoLadrilho boolean
--- @return boolean true se o prédio foi encontrado e atualizado
local function _atualizarEstatisticasPredio(dadosPredio, forcarAtualizacaoLadrilho)
    if not dadosPredio then return false end

    -- ForceUpdateBuilding usa isso para forçar a reaplicação da energia do ladrilho após
    -- mudanças de conexão / desconexão / ativação. Atualizações passivas de interface não
    -- devem limpar o cache, caso contrário, cada consulta pareceria uma transição de estado.
    if forcarAtualizacaoLadrilho then
        Distribuidor.powerStateCache[dadosPredio.id] = nil
    end

    Distribuidor.UpdateBuildingPower(dadosPredio, true)
    sincronizarEstatisticasPredioAoGerador(dadosPredio)
    return true
end

local function _tentarAtualizarPredio(idPredio, forcarAtualizacaoLadrilho)
    local dadosPredio = GerenciadorEstado.GetBuilding(idPredio)
    if not dadosPredio then return false end

    return _atualizarEstatisticasPredio(dadosPredio, forcarAtualizacaoLadrilho == true)
end

--- Atualiza consumidores ativos e Gen_Stats_* para um prédio sem forcar
--- a reaplicação de energia aos ladrilhos. Use para consultas de interface e atualizações de barris/status.
--- @param idPredio string ID do Prédio
--- @return boolean true se o prédio foi encontrado e atualizado
function Distribuidor.RefreshBuildingStats(idPredio)
    if not idPredio then
        Registrador.Error("RefreshBuildingStats: idPredio e nil", "Power")
        return false
    end

    return _tentarAtualizarPredio(idPredio, false)
end

--- Força a atualização de energia para um prédio específico.
--- Se o prédio ainda não estiver no GerenciadorEstado (ex: chunk acabou de carregar após teleporte),
--- a solicitação é enfileirada para até 3 tentativas nos ticks EveryOneMinute subsequentes.
--- ProcessRetryQueue() deve ser chamado a cada minuto (feito por LKS_EletricidadeConstrucao_ServerInit).
-- @param idPredio string ID do Prédio
function Distribuidor.ForceUpdateBuilding(idPredio)
    if not idPredio then
        Registrador.Error("ForceUpdateBuilding: idPredio e nil", "Power")
        return
    end

    -- Auto-correção: _retryQueue pode ser nil se Initialize() rodou antes deste campo existir
    if not Distribuidor._retryQueue then Distribuidor._retryQueue = {} end

    if _tentarAtualizarPredio(idPredio, true) then
        -- Sucesso — limpa qualquer entrada de tentativa antiga para este prédio
        Distribuidor._retryQueue[idPredio] = nil
        return
    end

    -- Prédio ainda não está no estado. Enfileira para tentar novamente em vez de descartar silenciosamente.
    if not Distribuidor._retryQueue[idPredio] then
        Registrador.Warn(string.format(
            "ForceUpdateBuilding: Prédio não encontrado: %s - enfileirado para tentar novamente (até 3x no EveryOneMinute)",
            idPredio), "Power")
        Distribuidor._retryQueue[idPredio] = 3
    end
end

--- Tenta novamente chamadas pendentes de ForceUpdateBuilding cujo prédio ainda não estava no estado.
--- Chamado a partir do EveryOneMinute (LKS_EletricidadeConstrucao_ServerInit). Cada entrada recebe até 3 tentativas
--- em 3 ticks de minutos consecutivos antes de ser permanentemente abandonada.
function Distribuidor.ProcessRetryQueue()
    -- Auto-correção: _retryQueue pode ser nil se Initialize() rodou antes deste campo existir
    local fila = Distribuidor._retryQueue
    if not fila then
        Distribuidor._retryQueue = {}
        return
    end

    -- NOTA: next() não está disponível no Kahlua (VM Lua do PZ) - usa pairs para verificar se está vazia
    local possuiEntradas = false
    for _ in pairs(fila) do possuiEntradas = true; break end
    if not possuiEntradas then return end  -- saída rápida se vazia

    local paraRemover = {}
    for idPredio, tentativasRestantes in pairs(fila) do
        if _tentarAtualizarPredio(idPredio, true) then
            Registrador.Info(string.format(
                "ProcessRetryQueue: Prédio %s restaurado - ForceUpdate adiado aplicado", idPredio), "Power")
            table.insert(paraRemover, idPredio)
        else
            local restantes = tentativasRestantes - 1
            if restantes <= 0 then
                Registrador.Warn(string.format(
                    "ProcessRetryQueue: Prédio %s ainda não encontrado após todas as tentativas - abandonando", idPredio), "Power")
                table.insert(paraRemover, idPredio)
            else
                Registrador.Debug(string.format(
                    "ProcessRetryQueue: Prédio %s não encontrado, %d tentativas restantes", idPredio, restantes), "Power")
                Distribuidor._retryQueue[idPredio] = restantes
            end
        end
    end
    for _, idPredio in ipairs(paraRemover) do
        Distribuidor._retryQueue[idPredio] = nil
    end
end

--------------------------------------------------------------------------------
-- FUNÇÕES DE CONSULTA
--------------------------------------------------------------------------------

--- Obtém o estado de energia em cache para um prédio
-- @param idPredio string ID do Prédio
-- @return boolean|nil Estado de energia em cache (nil se não estiver no cache)
function Distribuidor.GetCachedPowerState(idPredio)
    return Distribuidor.powerStateCache[idPredio]
end

--- Limpa o cache do estado de energia
function Distribuidor.ClearCache()
    Registrador.Info("Limpando o cache do estado de energia...", "Power")
    Distribuidor.powerStateCache = {}
end

--------------------------------------------------------------------------------
-- FUNÇÕES DE DEPURAÇÃO (DEBUG)
--------------------------------------------------------------------------------

--- Imprime o status da distribuição de energia (debug)
function Distribuidor.PrintStatus()
    Registrador.Info("=== STATUS DA DISTRIBUICAO DE ENERGIA ===", "Power")
    
    local predios = GerenciadorEstado.GetAllBuildings()
    if not predios then
        Registrador.Info("Nenhum predio encontrado", "Power")
        return
    end
    
    -- GetAllBuildings() retorna uma tabela hash (mapa); o operador # sempre retorna 0 para tabelas hash
    local contagemPredios = 0
    for _ in pairs(predios) do contagemPredios = contagemPredios + 1 end
    Registrador.Info(string.format("Total de predios: %d", contagemPredios), "Power")
    
    local quantidadeEnergizados = 0
    local quantidadeSemEnergia = 0
    
    for _, dadosPredio in pairs(predios) do
        local estaEnergizado = predioTemEnergiaInline(dadosPredio)
        local contagemConsumidores = 0
        if dadosPredio.powerConsumers then
            for _ in pairs(dadosPredio.powerConsumers) do contagemConsumidores = contagemConsumidores + 1 end
        end
        local consumoEnergia = dadosPredio.totalPowerDraw or 0
        
        if estaEnergizado then
            quantidadeEnergizados = quantidadeEnergizados + 1
        else
            quantidadeSemEnergia = quantidadeSemEnergia + 1
        end
        
        Registrador.Info(string.format(
            "  Prédio %s: %s (%d consumidores, %.1f de consumo)",
            dadosPredio.id,
            estaEnergizado and "ENERGIZADO" or "SEM ENERGIA",
            contagemConsumidores,
            consumoEnergia
        ), "Power")
    end
    
    Registrador.Info(string.format(
        "Resumo: %d energizados, %d sem energia",
        quantidadeEnergizados,
        quantidadeSemEnergia
    ), "Power")
    
    Registrador.Info("=========================================", "Power")
end

--------------------------------------------------------------------------------
-- EXPORTAÇÕES
--------------------------------------------------------------------------------

LKS_EletricidadeConstrucao.RegisterModule("Power.Distributor", "2.0.0")

return LKS_EletricidadeConstrucao.Power.Distributor
