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

-- ARQUIVO: LKS_EletricidadeConstrucao_Power_ClientSync.lua
-- OBJETIVO: Reconstrói no cliente a energia falsa do gerador para GridSquares carregados em multiplayer.
-- LOCALIZAÇÃO: client

if not LKS_EletricidadeConstrucao then
    print("[LKS PATCH - LKS_EletricidadeConstrucao_Power_ClientSync.lua] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_Power_ClientSync")

local CHAVE_SINCRONIZACAO_ENERGIA = "LKS_EletricidadeConstrucao_BuildingPowerSync"

--- Verifica se o contexto de execução atual é o cliente.
--- @return boolean Retorna true se for cliente.
local function IsContextoCliente()
    return LKS_EletricidadeConstrucao.IsClient and LKS_EletricidadeConstrucao.IsClient()
end

--- Obtém o GridSquare de coordenadas específicas.
--- @param coordenadaX number Coordenada X.
--- @param coordenadaY number Coordenada Y.
--- @param coordenadaZ number Coordenada Z.
--- @return any|nil O GridSquare correspondente ou nil.
local function ObterQuadradoEm(coordenadaX, coordenadaY, coordenadaZ)
    if getSquare then
        return getSquare(coordenadaX, coordenadaY, coordenadaZ)
    end

    local celula = getCell and getCell()
    return celula and celula:getGridSquare(coordenadaX, coordenadaY, coordenadaZ) or nil
end

--- Obtém a tabela de dados ModData local associada à chave de sincronismo.
--- @return table A tabela ModData de sincronização de energia.
local function ObterPacoteLocal()
    local pacote = ModData.get(CHAVE_SINCRONIZACAO_ENERGIA)
    if pacote then
        return pacote
    end
    return ModData.getOrCreate(CHAVE_SINCRONIZACAO_ENERGIA)
end

--- Obtém o pacote local e a lista de estados de construções contida nele.
--- @return table O pacote local ModData.
--- @return table A lista de estados das construções.
local function ObterEstadosConstrucoes()
    local pacote = ObterPacoteLocal()
    pacote.buildings = pacote.buildings or {}
    return pacote, pacote.buildings
end

--- Verifica se o GridSquare deve ser afetado pelo estado elétrico da construção.
--- @param quadrado any O GridSquare que está sendo avaliado.
--- @param estado table O estado da construção que possui energia.
--- @return boolean Retorna true se o quadrado deve ser energizado por esta construção.
local function DeveAfetarQuadrado(quadrado, estado)
    if not quadrado or not estado or not estado.boundingBox then
        return false
    end

    local coordenadaX = quadrado:getX()
    local coordenadaY = quadrado:getY()
    local coordenadaZ = quadrado:getZ()
    local caixaDelimitadora = estado.boundingBox

    if coordenadaX < caixaDelimitadora.minX or coordenadaX > caixaDelimitadora.maxX or coordenadaY < caixaDelimitadora.minY or coordenadaY > caixaDelimitadora.maxY then
        return false
    end

    local baseZ = estado.z or 0
    local zMinimo = math.max(0, baseZ - 3)
    local zMaximo = baseZ + 10
    if coordenadaZ < zMinimo or coordenadaZ > zMaximo then
        return false
    end

    local quadradoAncora = ObterQuadradoEm(estado.x, estado.y, estado.z or 0)
    local construcaoAncora = quadradoAncora and quadradoAncora:getBuilding() or nil
    local construcaoQuadrado = quadrado:getBuilding()

    return not construcaoAncora or construcaoQuadrado == nil or construcaoQuadrado == construcaoAncora
end

--- Adiciona ou remove a posição virtual de gerador no Chunk correspondente ao quadrado.
--- @param quadrado any O GridSquare que receberá ou perderá energia virtual.
--- @param deveEnergizar boolean Define se deve adicionar (true) ou remover (false) a energia.
--- @return any|nil O Chunk modificado ou nil se não encontrado.
local function AplicarEnergiaQuadradoLocal(quadrado, deveEnergizar)
    local pedaco = quadrado and quadrado:getChunk()
    if not pedaco then
        return nil
    end

    local coordenadaX = quadrado:getX()
    local coordenadaY = quadrado:getY()
    local coordenadaZ = quadrado:getZ()

    if deveEnergizar then
        pedaco:addGeneratorPos(coordenadaX, coordenadaY, coordenadaZ)
    else
        pedaco:removeGeneratorPos(coordenadaX, coordenadaY, coordenadaZ)
    end

    if quadrado.RecalcAllWithNeighbours then
        quadrado:RecalcAllWithNeighbours(false)
    end

    if pedaco.recalcHashCodeObjects then
        pedaco:recalcHashCodeObjects()
    end

    return pedaco
end

--- Aplica o estado de energia nas posições da construção carregadas no mapa.
--- @param estado table O estado da construção que possui energia.
--- @param deveEnergizar boolean Define se deve adicionar (true) ou remover (false) a energia.
--- @return number, number O total de quadrados afetados e o total de chunks recalculados.
local function AplicarEstadoConstrucaoCarregada(estado, deveEnergizar)
    if not estado or not estado.boundingBox then
        return 0, 0
    end

    local caixaDelimitadora = estado.boundingBox
    local zMinimo = math.max(0, (estado.z or 0) - 3)
    local zMaximo = (estado.z or 0) + 10
    local totalQuadrados = 0
    local pedacosAfetados = {}

    for coordenadaX = caixaDelimitadora.minX, caixaDelimitadora.maxX do
        for coordenadaY = caixaDelimitadora.minY, caixaDelimitadora.maxY do
            for coordenadaZ = zMinimo, zMaximo do
                local quadrado = ObterQuadradoEm(coordenadaX, coordenadaY, coordenadaZ)
                if quadrado and DeveAfetarQuadrado(quadrado, estado) then
                    local pedaco = AplicarEnergiaQuadradoLocal(quadrado, deveEnergizar)
                    if pedaco then
                        pedacosAfetados[tostring(pedaco)] = pedaco
                        totalQuadrados = totalQuadrados + 1
                    end
                end
            end
        end
    end

    local totalPedacos = 0
    for _, pedaco in pairs(pedacosAfetados) do
        totalPedacos = totalPedacos + 1
        if pedaco.recalcHashCodeObjects then
            pedaco:recalcHashCodeObjects()
        end
    end

    return totalQuadrados, totalPedacos
end

--- Sincroniza os estados de energia locais a partir de um novo pacote ModData de sincronização.
--- @param novoPacote table O novo pacote ModData recebido do servidor.
local function SincronizarAPartirDePacote(novoPacote)
    local pacoteLocal, estadosAtuais = ObterEstadosConstrucoes()
    local proximosEstados = (novoPacote and novoPacote.buildings) or {}
    local removidos = 0
    local aplicados = 0

    -- Remove energia das construções que não estão mais presentes no novo pacote
    for idConstrucao, estadoAnterior in pairs(estadosAtuais) do
        if estadoAnterior and not proximosEstados[idConstrucao] then
            AplicarEstadoConstrucaoCarregada(estadoAnterior, false)
            removidos = removidos + 1
        end
    end

    pacoteLocal.buildings = proximosEstados
    ModData.add(CHAVE_SINCRONIZACAO_ENERGIA, pacoteLocal)

    -- Aplica a energia para as construções presentes no novo pacote
    for _, estado in pairs(proximosEstados) do
        AplicarEstadoConstrucaoCarregada(estado, true)
        aplicados = aplicados + 1
    end

    if aplicados > 0 or removidos > 0 then
        print(string.format("[LKS PATCH - LKS_EletricidadeConstrucao_Power_ClientSync.lua] Sincronizadas %d construções energizadas, %d removidas", aplicados, removidos))
    end
end

--- Solicita o estado atual das construções energizadas para o servidor.
local function SolicitarEstado()
    if not IsContextoCliente() then
        return
    end
    if ModData and ModData.request then
        ModData.request(CHAVE_SINCRONIZACAO_ENERGIA)
    end
end

--- Inicializa e sincroniza os dados do ModData ao carregar os dados globais.
local function AoIniciarModDataGlobal()
    SolicitarEstado()
    local pacote = ModData.get(CHAVE_SINCRONIZACAO_ENERGIA)
    if pacote and pacote.buildings then
        SincronizarAPartirDePacote(pacote)
    end
end

--- Executa a sincronização local ao receber a atualização de dados globais do servidor.
--- @param chave string A chave do ModData atualizado.
--- @param pacote table O pacote de dados recebido do servidor.
local function AoReceberModDataGlobal(chave, pacote)
    if chave ~= CHAVE_SINCRONIZACAO_ENERGIA or not IsContextoCliente() then
        return
    end
    SincronizarAPartirDePacote(pacote)
end

--- Aplica a energia local ao carregar um novo GridSquare se pertencer a uma construção energizada.
--- @param quadrado any O GridSquare que foi carregado no mapa.
local function AoCarregarGridSquare(quadrado)
    if not quadrado or not IsContextoCliente() then
        return
    end

    local _, estados = ObterEstadosConstrucoes()
    for _, estado in pairs(estados) do
        if DeveAfetarQuadrado(quadrado, estado) then
            AplicarEnergiaQuadradoLocal(quadrado, true)
            return
        end
    end
end

if Events.OnInitGlobalModData then
    Events.OnInitGlobalModData.Add(AoIniciarModDataGlobal)
end

if Events.OnReceiveGlobalModData then
    Events.OnReceiveGlobalModData.Add(AoReceberModDataGlobal)
end

if Events.LoadGridsquare then
    Events.LoadGridsquare.Add(AoCarregarGridSquare)
elseif Events.OnLoadGridSquare then
    Events.OnLoadGridSquare.Add(AoCarregarGridSquare)
elseif Events.OnLoadGridsquare then
    Events.OnLoadGridsquare.Add(AoCarregarGridSquare)
end

if Events.OnGameStart then
    Events.OnGameStart.Add(function()
        SolicitarEstado()
        local pacote = ModData.get(CHAVE_SINCRONIZACAO_ENERGIA)
        if pacote and pacote.buildings then
            SincronizarAPartirDePacote(pacote)
        end
    end)
end

print("[LKS PATCH - LKS_EletricidadeConstrucao_Power_ClientSync.lua] Carregado com sucesso!")

return true