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

-- ARQUIVO: LKS_EletricidadeConstrucao_ServerCommands.lua
-- OBJETIVO: Manipulador de comandos no lado do servidor.
-- LOCALIZAÇÃO: server

if not LKS_EletricidadeConstrucao then
    return
end

--- Localiza o objeto IsoGenerator nas coordenadas especificadas.
--- @param coordenadaX number Coordenada X.
--- @param coordenadaY number Coordenada Y.
--- @param coordenadaZ number Coordenada Z.
--- @return any|nil O objeto IsoGenerator encontrado ou nil.
local function LocalizarGeradorEm(coordenadaX, coordenadaY, coordenadaZ)
    local celula = getCell and getCell()
    if not celula then return nil end

    local quadrado = celula:getGridSquare(coordenadaX, coordenadaY, coordenadaZ)
    if not quadrado then return nil end

    local objetos = quadrado:getObjects()
    if not objetos then return nil end

    for indiceObjeto = 0, objetos:size() - 1 do
        local objeto = objetos:get(indiceObjeto)
        if objeto and instanceof(objeto, "IsoGenerator") then
            return objeto
        end
    end

    return nil
end

--- Verifica se o jogador está a uma distância aceitável de um GridSquare específico.
--- @param jogador any O objeto IsoPlayer.
--- @param quadrado any O GridSquare correspondente.
--- @param distanciaMaxima number|nil Distância máxima aceitável (padrão: 2).
--- @return boolean Retorna true se estiver próximo.
local function IsJogadorProximoAoQuadrado(jogador, quadrado, distanciaMaxima)
    if not jogador or not quadrado then return false end
    distanciaMaxima = distanciaMaxima or 2

    local quadradoJogador = jogador:getSquare()
    if not quadradoJogador then return false end
    if quadradoJogador:getZ() ~= quadrado:getZ() then return false end

    local diferencaX = math.abs(quadradoJogador:getX() - quadrado:getX())
    local diferencaY = math.abs(quadradoJogador:getY() - quadrado:getY())
    return diferencaX <= distanciaMaxima and diferencaY <= distanciaMaxima
end

--- Verifica se o jogador está próximo a um gerador.
--- @param jogador any O objeto IsoPlayer.
--- @param gerador any O objeto IsoGenerator.
--- @return boolean Retorna true se estiver próximo.
local function IsJogadorProximoAoGerador(jogador, gerador)
    if not jogador or not gerador then return false end
    return IsJogadorProximoAoQuadrado(jogador, gerador:getSquare(), 2)
end

--- Verifica se o jogador está próximo a uma âncora de aquecimento especificada no payload.
--- @param jogador any O objeto IsoPlayer.
--- @param argumentos table Os argumentos contendo as coordenadas da âncora.
--- @return boolean Retorna true se estiver próximo.
local function IsJogadorProximoAncoraAquecimento(jogador, argumentos)
    if not jogador or not argumentos then return false end
    if argumentos.anchorX == nil or argumentos.anchorY == nil or argumentos.anchorZ == nil then
        return false
    end

    local celula = getCell and getCell()
    if not celula then return false end

    local quadrado = celula:getGridSquare(argumentos.anchorX, argumentos.anchorY, argumentos.anchorZ)
    if not quadrado then return false end

    return IsJogadorProximoAoQuadrado(jogador, quadrado, 2)
end

--- Verifica se uma tabela Lua possui entradas.
--- @param tabela table A tabela a ser verificada.
--- @return boolean Retorna true se possuir chaves.
local function TabelaPossuiEntradas(tabela)
    if type(tabela) ~= "table" then return false end
    for _ in pairs(tabela) do
        return true
    end
    return false
end

--- Verifica se as coordenadas estão dentro da caixa delimitadora da construção.
--- @param dadosConstrucao table Os dados da construção no StateManager.
--- @param coordenadaX number Coordenada X.
--- @param coordenadaY number Coordenada Y.
--- @return boolean Retorna true se as coordenadas estiverem dentro da área da construção.
local function EstaDentroDaCaixaDelimitadora(dadosConstrucao, coordenadaX, coordenadaY)
    local caixaDelimitadora = dadosConstrucao and dadosConstrucao.boundingBox
    if type(caixaDelimitadora) ~= "table" then return false end

    local minX = tonumber(caixaDelimitadora.minX or caixaDelimitadora[1])
    local minY = tonumber(caixaDelimitadora.minY or caixaDelimitadora[2])
    local maxX = tonumber(caixaDelimitadora.maxX or caixaDelimitadora[3])
    local maxY = tonumber(caixaDelimitadora.maxY or caixaDelimitadora[4])
    if not (minX and minY and maxX and maxY) then
        return false
    end

    return coordenadaX >= (minX - 1) and coordenadaX <= (maxX + 1)
       and coordenadaY >= (minY - 1) and coordenadaY <= (maxY + 1)
end

--- Busca uma estrutura de construção física nas imediações de um quadrado.
--- @param celula any A célula ativa.
--- @param quadrado any O GridSquare central.
--- @param raio number O raio de busca em blocos.
--- @return any|nil O objeto IsoBuilding correspondente ou nil.
local function LocalizarConstrucaoIsoProxima(celula, quadrado, raio)
    local construcaoIso = quadrado and quadrado:getBuilding() or nil
    if construcaoIso then return construcaoIso end
    if not celula or not quadrado then return nil end

    local bx, by, bz = quadrado:getX(), quadrado:getY(), quadrado:getZ()
    for r = 1, raio do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local gsq = celula:getGridSquare(bx + dx, by + dy, bz)
                    if gsq then
                        construcaoIso = gsq:getBuilding()
                        if construcaoIso then
                            return construcaoIso
                        end
                    end
                end
            end
        end
    end

    return nil
end

--- Verifica se os dados lógicos correspondem à construção física.
--- @param dadosConstrucao table Os dados lógicos da construção.
--- @param construcaoIso any A estrutura física IsoBuilding.
--- @param celula any A célula ativa.
--- @param fallbackZ number Coordenada Z de fallback.
--- @return boolean Retorna true se corresponderem.
local function ConstrucaoCorrespondeAIso(dadosConstrucao, construcaoIso, celula, fallbackZ)
    if not dadosConstrucao or not construcaoIso or not celula then return false end
    if dadosConstrucao.x == nil or dadosConstrucao.y == nil then return false end

    local gsq = celula:getGridSquare(dadosConstrucao.x, dadosConstrucao.y, dadosConstrucao.z or fallbackZ or 0)
    return gsq and gsq:getBuilding() == construcaoIso or false
end

--- Verifica se o gerador lógico ou físico está ativo e com combustível.
--- @param dadosGerador table Os dados do gerador.
--- @return boolean Retorna true se estiver funcionando.
local function IsGeradorFuncionando(dadosGerador)
    local GeneratorData = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
    if GeneratorData and GeneratorData.IsRunning then
        return GeneratorData.IsRunning(dadosGerador)
    end

    return dadosGerador and (dadosGerador.fuelAmount or 0) > 0 and dadosGerador.activated ~= false
end

--- Retorna um score de acoplamento entre um gerador e uma construção.
--- @param dadosGerador table Os dados do gerador.
--- @param dadosConstrucao table Os dados da construção.
--- @param quadrado any O GridSquare do gerador.
--- @param gerenciadorEstado table O StateManager do mod.
--- @param idPoolAtiva string|nil O ID do pool ativo.
--- @return number O peso ou força da correspondência.
local function ObterForcaCorrespondenciaGeradorConstrucao(dadosGerador, dadosConstrucao, quadrado, gerenciadorEstado, idPoolAtiva)
    if not dadosGerador or not dadosConstrucao then return 0 end

    local melhorScore = 0
    local alvoX, alvoY = dadosConstrucao.x, dadosConstrucao.y
    local quadradoX = quadrado and quadrado:getX() or nil
    local quadradoY = quadrado and quadrado:getY() or nil

    if idPoolAtiva and idPoolAtiva == dadosConstrucao.id then
        melhorScore = 4
    end

    for _, idConectado in pairs(dadosGerador.connectedBuildings or {}) do
        if idConectado == dadosConstrucao.id then
            if melhorScore < 3 then melhorScore = 3 end
        end

        local refBld = gerenciadorEstado and gerenciadorEstado.GetBuilding and gerenciadorEstado.GetBuilding(idConectado) or nil
        if refBld then
            if alvoX and alvoY and refBld.x == alvoX and refBld.y == alvoY then
                if melhorScore < 2 then melhorScore = 2 end
            elseif refBld.x and refBld.y and EstaDentroDaCaixaDelimitadora(dadosConstrucao, refBld.x, refBld.y) then
                if melhorScore < 1 then melhorScore = 1 end
            elseif alvoX and alvoY and EstaDentroDaCaixaDelimitadora(refBld, alvoX, alvoY) then
                if melhorScore < 1 then melhorScore = 1 end
            elseif quadradoX and quadradoY and EstaDentroDaCaixaDelimitadora(dadosConstrucao, quadradoX, quadradoY)
                    and EstaDentroDaCaixaDelimitadora(refBld, quadradoX, quadradoY) then
                if melhorScore < 1 then melhorScore = 1 end
            end
        else
            local cx, cy = string.match(idConectado, "^bld_(%-?%d+)_(%-?%d+)_")
            cx = tonumber(cx)
            cy = tonumber(cy)
            if cx and cy then
                if alvoX and alvoY and cx == alvoX and cy == alvoY then
                    if melhorScore < 2 then melhorScore = 2 end
                elseif EstaDentroDaCaixaDelimitadora(dadosConstrucao, cx, cy) then
                    if melhorScore < 1 then melhorScore = 1 end
                end
            end
        end
    end

    return melhorScore
end

--- Verifica se o gerador possui referência direta à construção.
--- @param dadosGerador table Os dados do gerador.
--- @param dadosConstrucao table Os dados da construção.
--- @param quadrado any O GridSquare do gerador.
--- @param gerenciadorEstado table O StateManager do mod.
--- @return boolean Retorna true se houver conexão/referência.
local function GeradorReferenciaConstrucao(dadosGerador, dadosConstrucao, quadrado, gerenciadorEstado)
    return ObterForcaCorrespondenciaGeradorConstrucao(dadosGerador, dadosConstrucao, quadrado, gerenciadorEstado, nil) > 0
end

--- Calcula um score de relevância do gerador para a construção.
--- @param dadosConstrucao table Os dados da construção.
--- @param quadrado any O GridSquare do gerador.
--- @param gerenciadorEstado table O StateManager do mod.
--- @return number A pontuação de relevância calculada.
local function ObterPontuacaoGeradorConstrucao(dadosConstrucao, quadrado, gerenciadorEstado)
    if not dadosConstrucao or not gerenciadorEstado then return 0 end

    local melhorScore = 0
    local GeneratorData = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator

    local function ConsiderarGerador(dadosGerador, idPoolAtiva)
        local forcaCorrespondencia = ObterForcaCorrespondenciaGeradorConstrucao(
            dadosGerador, dadosConstrucao, quadrado, gerenciadorEstado, idPoolAtiva)
        if forcaCorrespondencia <= 0 then
            return
        end

        local score = forcaCorrespondencia * 100
        if IsGeradorFuncionando(dadosGerador) then
            score = score + 40
        else
            score = score + 5
        end
        if idPoolAtiva and idPoolAtiva == dadosConstrucao.id then
            score = score + 20
        end

        if score > melhorScore then
            melhorScore = score
        end
    end

    if dadosConstrucao.connectedGenerators and GeneratorData and GeneratorData.MakeId and gerenciadorEstado.GetGenerator then
        for _, chaveGerador in pairs(dadosConstrucao.connectedGenerators) do
            local gx, gy, gz = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if gx then
                local geradorX, geradorY, geradorZ = tonumber(gx), tonumber(gy), tonumber(gz)
                local idGerador = (geradorX and geradorY and geradorZ) and GeneratorData.MakeId(geradorX, geradorY, geradorZ) or nil
                local dadosGerador = idGerador and gerenciadorEstado.GetGenerator(idGerador) or nil
                local objetoGerador = (geradorX and geradorY and geradorZ) and LocalizarGeradorEm(geradorX, geradorY, geradorZ) or nil
                local idPoolAtiva = objetoGerador and objetoGerador:getModData() and objetoGerador:getModData().Gen_BuildingPoolID or nil
                
                if dadosGerador then
                    ConsiderarGerador(dadosGerador, idPoolAtiva)
                elseif idPoolAtiva and idPoolAtiva == dadosConstrucao.id then
                    local score = 420
                    if objetoGerador and objetoGerador:isActivated() then score = score + 40 end
                    if score > melhorScore then
                        melhorScore = score
                    end
                end
            end
        end
    end

    if gerenciadorEstado.GetAllGenerators then
        for _, dadosGerador in pairs(gerenciadorEstado.GetAllGenerators() or {}) do
            local objetoGerador = (dadosGerador.x ~= nil and dadosGerador.y ~= nil and dadosGerador.z ~= nil)
                and LocalizarGeradorEm(dadosGerador.x, dadosGerador.y, dadosGerador.z) or nil
            local idPoolAtiva = objetoGerador and objetoGerador:getModData() and objetoGerador:getModData().Gen_BuildingPoolID or nil
            ConsiderarGerador(dadosGerador, idPoolAtiva)
            if melhorScore >= 440 then
                return melhorScore
            end
        end
    end

    return melhorScore
end

--- Pontua um candidato de construção a receber energia física com base no posicionamento e rede.
--- @param dadosConstrucao table Os dados da construção.
--- @param quadrado any O GridSquare avaliado.
--- @param construcaoIso any A estrutura física IsoBuilding próxima.
--- @param raio number O raio máximo.
--- @param celula any A célula ativa.
--- @param gerenciadorEstado table O StateManager do mod.
--- @param idConstrucaoPreferencial string|nil O ID da construção que tem preferência de acoplamento.
--- @return number|nil O score calculado ou nil se inválido.
local function PontuarCandidatoConstrucao(dadosConstrucao, quadrado, construcaoIso, raio, celula, gerenciadorEstado, idConstrucaoPreferencial)
    if not dadosConstrucao or not dadosConstrucao.id then return nil end

    local bx, by = quadrado:getX(), quadrado:getY()
    local dx = dadosConstrucao.x ~= nil and (dadosConstrucao.x - bx) or nil
    local dy = dadosConstrucao.y ~= nil and (dadosConstrucao.y - by) or nil
    local d2 = (dx and dy) and (dx * dx + dy * dy) or nil
    local raioSq = raio * raio
    local inside = EstaDentroDaCaixaDelimitadora(dadosConstrucao, bx, by)
    local isoMatch = ConstrucaoCorrespondeAIso(dadosConstrucao, construcaoIso, celula, quadrado:getZ())
    local withinRadius = d2 and d2 <= raioSq or false

    if not inside and not isoMatch and not withinRadius then
        return nil
    end

    local generatorScore = ObterPontuacaoGeradorConstrucao(dadosConstrucao, quadrado, gerenciadorEstado)
    if generatorScore == 0 then
        return nil
    end

    local score = 0
    if inside then score = score + 200 end
    if isoMatch then score = score + 120 end
    if withinRadius and d2 then
        score = score + math.floor((raioSq - d2) / math.max(raio, 1))
    end
    score = score + generatorScore
    if dadosConstrucao.isPowered then score = score + 40 end
    if idConstrucaoPreferencial and dadosConstrucao.id == idConstrucaoPreferencial then
        score = score + 5
    end

    return score
end

--- Resolve a qual ID de construção lógica do StateManager um barril deve ser vinculado.
--- @param quadrado any O GridSquare do barril.
--- @param idConstrucaoPreferencial string|nil O ID da construção de preferência.
--- @param raio number|nil O raio de busca (padrão: 20).
--- @return table|nil O registro da construção correspondente ou nil.
local function ResolverConstrucaoDoBarril(quadrado, idConstrucaoPreferencial, raio)
    raio = raio or 20

    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not gerenciadorEstado or not gerenciadorEstado.GetAllBuildings then return nil end

    local construcoes = gerenciadorEstado.GetAllBuildings()
    if not TabelaPossuiEntradas(construcoes) then return nil end

    local celula = getCell and getCell()
    if not celula or not quadrado then return nil end

    local construcaoIso = LocalizarConstrucaoIsoProxima(celula, quadrado, raio)
    local melhorConstrucao, melhorScore = nil, nil

    for _, dadosConstrucao in pairs(construcoes) do
        local score = PontuarCandidatoConstrucao(
            dadosConstrucao, quadrado, construcaoIso, raio, celula, gerenciadorEstado, idConstrucaoPreferencial)
        if score and (
                not melhorScore
                or score > melhorScore
                or (score == melhorScore and melhorConstrucao and dadosConstrucao.id and melhorConstrucao.id
                    and tostring(dadosConstrucao.id) < tostring(melhorConstrucao.id))) then
            melhorScore = score
            melhorConstrucao = dadosConstrucao
        end
    end

    return melhorConstrucao
end

--- Conta a quantidade de entradas em um dicionário/tabela Lua.
--- @param tabela table A tabela a ser contada.
--- @return number A quantidade de chaves.
local function ContarEntradasMapa(tabela)
    local contagem = 0
    if type(tabela) ~= "table" then return contagem end
    for _ in pairs(tabela) do
        contagem = contagem + 1
    end
    return contagem
end

--- Cria uma cópia profunda dos dados de Bounding Box de uma construção.
--- @param source table A tabela original.
--- @return table|nil A cópia gerada ou nil.
local function CopiarCaixaDelimitadora(source)
    if type(source) ~= "table" then return nil end

    local minX = tonumber(source.minX or source[1])
    local minY = tonumber(source.minY or source[2])
    local maxX = tonumber(source.maxX or source[3])
    local maxY = tonumber(source.maxY or source[4])
    if not (minX and minY and maxX and maxY) then
        return nil
    end

    return {
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY,
    }
end

--- Verifica se uma tabela contém um valor específico.
--- @param tabela table A tabela para busca.
--- @param valor any O valor procurado.
--- @return boolean Retorna true se o valor for encontrado.
local function TabelaContemValor(tabela, valor)
    if type(tabela) ~= "table" then return false end
    for _, item in pairs(tabela) do
        if item == valor then return true end
    end
    return false
end

--- Busca os dados de rede de energia salvos no ModData do gerador ou em geradores vizinhos vinculados.
--- @param idConstrucao string O ID da construção.
--- @param gerador any O objeto IsoGenerator físico.
--- @return table|nil Os dados salvos de LKS_EletricidadeConstrucao_PoolData ou nil.
local function ResolverDadosPoolParaConstrucao(idConstrucao, gerador)
    local dadosModAtual = gerador and gerador.getModData and gerador:getModData() or nil
    if dadosModAtual and dadosModAtual.LKS_EletricidadeConstrucao_PoolData then
        return dadosModAtual.LKS_EletricidadeConstrucao_PoolData
    end

    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not StateManager or not StateManager.GetAllGenerators then
        return nil
    end

    local generatorX = gerador and gerador.getX and gerador:getX() or nil
    local generatorY = gerador and gerador.getY and gerador:getY() or nil
    local generatorZ = gerador and gerador.getZ and gerador:getZ() or nil

    for _, dadosGerador in pairs(StateManager.GetAllGenerators() or {}) do
        if dadosGerador and TabelaContemValor(dadosGerador.connectedBuildings, idConstrucao) then
            local gx = tonumber(dadosGerador.x)
            local gy = tonumber(dadosGerador.y)
            local gz = tonumber(dadosGerador.z) or 0
            if not (gx == generatorX and gy == generatorY and gz == generatorZ) then
                local objeto = LocalizarGeradorEm(gx, gy, gz)
                if objeto then
                    local dadosModObjeto = objeto:getModData()
                    if dadosModObjeto and dadosModObjeto.LKS_EletricidadeConstrucao_PoolData then
                        return dadosModObjeto.LKS_EletricidadeConstrucao_PoolData
                    end
                end
            end
        end
    end

    return nil
end

--- Reconstrói o estado lógico de uma construção no StateManager a partir dos metadados de Pool salvos no gerador.
--- @param idConstrucao string O ID da construção.
--- @param stateManager table O StateManager do mod.
--- @param dadosPool table Os dados recuperados do gerador.
--- @param anchorX number Coordenada X da âncora.
--- @param anchorY number Coordenada Y da âncora.
--- @param anchorZ number Coordenada Z da âncora.
--- @param motivo string Identificador do motivo de restauração.
--- @return table|nil A tabela do estado reconstruído ou nil.
local function RestaurarConstrucaoDosDadosPool(idConstrucao, stateManager, dadosPool, anchorX, anchorY, anchorZ, motivo)
    if not dadosPool then return nil end

    local buildingX = dadosPool.x
    local buildingY = dadosPool.y
    local buildingZ = dadosPool.z
    if buildingX == nil then buildingX = anchorX end
    if buildingY == nil then buildingY = anchorY end
    if buildingZ == nil then buildingZ = anchorZ or 0 end
    if buildingX == nil or buildingY == nil then return nil end

    local dadosConstrucao = {
        id = idConstrucao,
        x = buildingX,
        y = buildingY,
        z = buildingZ,
        generatorId = nil,
        powerConsumers = {},
        totalPowerDraw = 0,
        heatingPowerDraw = 0,
        isPowered = false,
        borderRadius = tonumber(dadosPool.borderRadius) or 30,
        lastScanTime = getTimestampMs(),
        boundingBox = CopiarCaixaDelimitadora(dadosPool.boundingBox),
        isRVInterior = dadosPool.isRVInterior == true,
        heatingEnabled = false,
        heatingSourceCount = 0,
        heatingTargetTemp = 22,
        connectedGenerators = {},
    }
    stateManager.AddBuilding(dadosConstrucao)

    LKS_EletricidadeConstrucao.Core.Logger.Warn(
        string.format("[StateRepair] %s: restaurada construcao %s a partir de LKS_EletricidadeConstrucao_PoolData%s",
            tostring(motivo or "desconhecido"), tostring(idConstrucao),
            dadosConstrucao.boundingBox and " com caixa delimitadora" or ""),
        "ServerCommands")

    return stateManager.GetBuilding and stateManager.GetBuilding(idConstrucao) or dadosConstrucao
end

--- Garante que a construção referenciada exista no StateManager do servidor (restaura se deletada ou corrompida).
--- @param idConstrucao string O ID da construção.
--- @param gerador any O objeto IsoGenerator associado.
--- @param motivo string Identificador do motivo.
--- @return table|nil O estado da construção garantido ou nil.
local function GarantirEstadoConstrucao(idConstrucao, gerador, motivo)
    local StateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not StateManager or not idConstrucao then return nil end

    local existente = StateManager.GetBuilding and StateManager.GetBuilding(idConstrucao) or nil
    local dadosPool = ResolverDadosPoolParaConstrucao(idConstrucao, gerador)
    local caixaDelimitadoraRestaurada = CopiarCaixaDelimitadora(dadosPool and dadosPool.boundingBox)

    if existente then
        local reparado = false
        if caixaDelimitadoraRestaurada and not existente.boundingBox then
            existente.boundingBox = caixaDelimitadoraRestaurada
            reparado = true
        end
        if dadosPool then
            if existente.x == nil and dadosPool.x ~= nil then existente.x = dadosPool.x; reparado = true end
            if existente.y == nil and dadosPool.y ~= nil then existente.y = dadosPool.y; reparado = true end
            if existente.z == nil and dadosPool.z ~= nil then existente.z = dadosPool.z; reparado = true end
            if (not existente.borderRadius or existente.borderRadius <= 0) and dadosPool.borderRadius ~= nil then
                existente.borderRadius = tonumber(dadosPool.borderRadius) or existente.borderRadius
                reparado = true
            end
        end
        if reparado and StateManager.MarkDirty then
            StateManager.MarkDirty()
        end
        return existente
    end

    local bx, by, bz = string.match(tostring(idConstrucao), "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
    bx, by, bz = tonumber(bx), tonumber(by), tonumber(bz)

    if not (bx and by) and dadosPool and dadosPool.x ~= nil and dadosPool.y ~= nil then
        bx = dadosPool.x
        by = dadosPool.y
        bz = dadosPool.z or bz or (gerador and gerador:getZ()) or 0
    end

    if dadosPool then
        existente = RestaurarConstrucaoDosDadosPool(idConstrucao, StateManager, dadosPool, bx, by, bz, motivo)
    end

    local Scanner = LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner
    if bx and by and bz and Scanner and Scanner.ScanBuilding then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("[StateRepair] %s: verificando construcao %s a partir da ancora (%d,%d,%d)",
                tostring(motivo or "desconhecido"), tostring(idConstrucao), bx, by, bz),
            "ServerCommands")
        local ok, escaneado = pcall(Scanner.ScanBuilding, bx, by, bz, idConstrucao)
        if ok and escaneado then
            existente = escaneado
        else
            existente = StateManager.GetBuilding and StateManager.GetBuilding(idConstrucao) or existente
        end
        if existente then
            return existente
        end
    end

    if bx and by and bz and LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Building then
        local dadosProvisorios = {
            id = idConstrucao,
            x = bx,
            y = by,
            z = bz,
            generatorId = nil,
            powerConsumers = {},
            totalPowerDraw = 0,
            heatingPowerDraw = 0,
            isPowered = false,
            borderRadius = 30,
            lastScanTime = getTimestampMs(),
            boundingBox = nil,
            isRVInterior = false,
            heatingEnabled = false,
            heatingSourceCount = 0,
            heatingTargetTemp = 22,
            connectedGenerators = {},
        }
        StateManager.AddBuilding(dadosProvisorios)
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("[StateRepair] %s: criado estado provisorio de construcao para %s",
                tostring(motivo or "desconhecido"), tostring(idConstrucao)),
            "ServerCommands")
        existente = StateManager.GetBuilding and StateManager.GetBuilding(idConstrucao) or dadosProvisorios
    end

    if existente and gerador and gerador.getSquare then
        local quadrado = gerador:getSquare()
        if quadrado then
            local genKey = string.format("%d_%d_%d", quadrado:getX(), quadrado:getY(), quadrado:getZ())
            existente.connectedGenerators = existente.connectedGenerators or {}
            local hasGen = false
            for _, gk in pairs(existente.connectedGenerators) do
                if gk == genKey then hasGen = true; break end
            end
            if not hasGen then
                table.insert(existente.connectedGenerators, genKey)
                if StateManager.MarkDirty then
                    StateManager.MarkDirty()
                end
            end
        end
    end

    return existente
end

--- Imprime um aviso de requisição rejeitada no logger do servidor.
--- @param command string O nome do comando.
--- @param reason string O motivo de rejeição.
local function AvisarRequisicaoInvalida(command, reason)
    LKS_EletricidadeConstrucao.Core.Logger.Warn(
        string.format("Comando %s rejeitado: %s", tostring(command), tostring(reason)),
        "ServerCommands")
end

--- Envia uma notificação de resultado de ação (ActionResult) ao cliente.
--- @param player any O jogador destinatário.
--- @param kind string O tipo de comando.
--- @param success boolean Status de sucesso.
--- @param args table|nil Dados adicionais do payload.
local function EnviarResultadoAcao(player, kind, success, args)
    if not player or not sendServerCommand then return end

    local payload = args or {}
    payload.kind = kind
    payload.success = success == true

    sendServerCommand(player, "LKS_EletricidadeConstrucao", "ActionResult", payload)
end

--- Rejeita a requisição e envia uma resposta com falha e mensagem legível ao jogador.
--- @param player any O jogador destinatário.
--- @param command string O nome do comando.
--- @param reason string O motivo técnico interno.
--- @param args table|nil O payload com dados do comando.
local function RejeitarRequisicao(player, command, reason, args)
    AvisarRequisicaoInvalida(command, reason)
    args = args or {}
    args.message = args.message or tostring(reason)
    EnviarResultadoAcao(player, command, false, args)
end

-- ============================================================================
-- PROCESSAMENTO DE COMANDOS DE REDE (MULTIPLAYER)
-- ============================================================================

--- Manipula e processa os comandos enviados pelos clientes.
--- @param module string O módulo identificador.
--- @param command string O comando recebido.
--- @param player any O jogador que solicitou o comando.
--- @param args table Argumentos contidos na requisição.
local function AoReceberComandoCliente(module, command, player, args)
    if module ~= "LKS_EletricidadeConstrucao" then return end

    if command == "ActivateGenerator" then
        if not args or args.genX == nil or args.genY == nil or args.genZ == nil then
            RejeitarRequisicao(player, command, "coordenadas do gerador ausentes", {
                message = "Requisição de gerador inválida",
            })
            return
        end

        local gerador = LocalizarGeradorEm(args.genX, args.genY, args.genZ)
        if not gerador then
            RejeitarRequisicao(player, command, "gerador não encontrado", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Gerador não disponível",
            })
            return
        end
        if not IsJogadorProximoAoGerador(player, gerador) then
            RejeitarRequisicao(player, command, "jogador não está próximo ao gerador", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Aproxime-se do gerador",
            })
            return
        end

        local actionClass = LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.ActivateGenerator
        if not actionClass or not actionClass.Execute or not actionClass.new then
            RejeitarRequisicao(player, command, "ação de ativação não carregada", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Ação do gerador indisponível",
            })
            return
        end

        local activate = args.activate == true
        local action = actionClass:new(player, gerador, activate)
        if action.isValid and not action:isValid() then
            RejeitarRequisicao(player, command, "ação do gerador inválida", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = activate and "O gerador não pode ser ligado" or "O gerador não pode ser desligado",
            })
            return
        end

        local ok, err = pcall(function()
            actionClass.Execute(gerador, activate)
        end)
        if not ok then
            RejeitarRequisicao(player, command, err, {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Ação do gerador falhou",
            })
            return
        end

        local sucesso = gerador:isActivated() == activate
        EnviarResultadoAcao(player, command, sucesso, {
            genX = args.genX,
            genY = args.genY,
            genZ = args.genZ,
            activate = activate,
            message = sucesso and nil or "O estado do gerador não foi alterado",
        })
    elseif command == "ConnectBuilding" then
        if not args or args.genX == nil or args.genY == nil or args.genZ == nil then
            RejeitarRequisicao(player, command, "coordenadas do gerador ausentes", {
                message = "Requisição de gerador inválida",
            })
            return
        end

        local gerador = LocalizarGeradorEm(args.genX, args.genY, args.genZ)
        if not gerador then
            RejeitarRequisicao(player, command, "gerador não encontrado", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Gerador não disponível",
            })
            return
        end
        if not IsJogadorProximoAoGerador(player, gerador) then
            RejeitarRequisicao(player, command, "jogador não está próximo ao gerador", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Aproxime-se do gerador",
            })
            return
        end

        local actionClass = LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.ConnectBuilding
        if not actionClass or not actionClass.new then
            RejeitarRequisicao(player, command, "ação de conexão não carregada", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Ação de conexão indisponível",
            })
            return
        end

        local action = actionClass:new(player, gerador)
        if action.isValid and not action:isValid() then
            RejeitarRequisicao(player, command, "ação de conexão inválida", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "O gerador já está conectado",
            })
            return
        end

        local ok, err = pcall(function()
            action:complete()
        end)
        if not ok then
            RejeitarRequisicao(player, command, err, {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Não foi possível conectar o gerador",
            })
            return
        end

        local buildingID = gerador:getModData().Gen_BuildingPoolID
        local repairedBuilding = buildingID and GarantirEstadoConstrucao(buildingID, gerador, "ConnectBuilding") or nil
        local genSquare = gerador:getSquare()
        if genSquare and buildingID then
            local genKey = string.format("%d_%d_%d", genSquare:getX(), genSquare:getY(), genSquare:getZ())
            local genId = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
                and LKS_EletricidadeConstrucao.Data.Generator.MakeId
                and LKS_EletricidadeConstrucao.Data.Generator.MakeId(genSquare:getX(), genSquare:getY(), genSquare:getZ())
            local genData = genId and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                and LKS_EletricidadeConstrucao.Core.StateManager.GetGenerator and LKS_EletricidadeConstrucao.Core.StateManager.GetGenerator(genId) or nil
            local bldGenCount = ContarEntradasMapa(repairedBuilding and repairedBuilding.connectedGenerators)
            local genBldCount = ContarEntradasMapa(genData and genData.connectedBuildings)
            LKS_EletricidadeConstrucao.Core.Logger.Warn(
                string.format("[ConnectDebug] gerador=%s pool=%s estadoConstrucaoValido=%s building.connectedGenerators=%d gen.connectedBuildings=%d",
                    tostring(genId or genKey), tostring(buildingID), tostring(repairedBuilding ~= nil), bldGenCount, genBldCount),
                "ServerCommands")
        end
        EnviarResultadoAcao(player, command, buildingID ~= nil, {
            genX = args.genX,
            genY = args.genY,
            genZ = args.genZ,
            buildingID = buildingID,
            message = buildingID and nil or "Não foi possível conectar o gerador a uma construção",
            messageKey = buildingID and "IGUI_ConnectedToBuilding" or nil,
        })
    elseif command == "DisconnectBuilding" then
        if not args or args.genX == nil or args.genY == nil or args.genZ == nil then
            RejeitarRequisicao(player, command, "coordenadas do gerador ausentes", {
                message = "Requisição de gerador inválida",
            })
            return
        end

        local gerador = LocalizarGeradorEm(args.genX, args.genY, args.genZ)
        if not gerador then
            RejeitarRequisicao(player, command, "gerador não encontrado", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Gerador não disponível",
            })
            return
        end
        if not IsJogadorProximoAoGerador(player, gerador) then
            RejeitarRequisicao(player, command, "jogador não está próximo ao gerador", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Aproxime-se do gerador",
            })
            return
        end

        local actionClass = LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.DisconnectBuilding
        if not actionClass or not actionClass.new then
            RejeitarRequisicao(player, command, "ação de desconexão não carregada", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Ação de desconexão indisponível",
            })
            return
        end

        local action = actionClass:new(player, gerador)
        if action.isValid and not action:isValid() then
            RejeitarRequisicao(player, command, "ação de desconexão inválida", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "O gerador não está conectado a uma construção",
            })
            return
        end

        local ok, err = pcall(function()
            action:complete()
        end)
        if not ok then
            RejeitarRequisicao(player, command, err, {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Não foi possível desconectar o gerador",
            })
            return
        end

        local buildingID = gerador:getModData().Gen_BuildingPoolID
        EnviarResultadoAcao(player, command, buildingID == nil, {
            genX = args.genX,
            genY = args.genY,
            genZ = args.genZ,
            message = (buildingID == nil) and nil or "O gerador ainda está conectado",
            messageKey = (buildingID == nil) and "IGUI_DisconnectedFromBuilding" or nil,
        })
    elseif command == "BarrelLink" then
        print(string.format("[LKS_EletricidadeConstrucao_BarrelLink] requisicao bx=%s by=%s bz=%s buildingID=%s vinculando=%s",
            tostring(args and args.bx), tostring(args and args.by), tostring(args and args.bz),
            tostring(args and args.buildingID), tostring(args and args.linking == true)))
        if not args or not args.bx then
            RejeitarRequisicao(player, command, "coordenadas do barril ausentes", {
                message = "Requisição de barril inválida",
            })
            return
        end
        local Barris = LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels
        if not Barris then
            RejeitarRequisicao(player, command, "sistema de barris não carregado", {
                message = "O sistema de barris de combustível está indisponível",
            })
            return
        end

        local quadrado = getCell():getGridSquare(args.bx, args.by, args.bz)
        if not quadrado then
            RejeitarRequisicao(player, command, "quadrado do barril não encontrado", {
                bx = args.bx,
                by = args.by,
                bz = args.bz,
                message = "O barril não está carregado",
            })
            return
        end
        if not IsJogadorProximoAoQuadrado(player, quadrado, 2) then
            RejeitarRequisicao(player, command, "jogador não está próximo ao barril", {
                bx = args.bx,
                by = args.by,
                bz = args.bz,
                message = "Aproxime-se do barril",
            })
            return
        end

        local barril = nil
        local objetos = quadrado:getObjects()
        for i = 0, objetos:size() - 1 do
            local objeto = objetos:get(i)
            if objeto and Barris.IsLinkable(objeto) then
                barril = objeto
                break
            end
        end

        if not barril then
            RejeitarRequisicao(player, command, "nenhum barril conectável no quadrado", {
                bx = args.bx,
                by = args.by,
                bz = args.bz,
                message = "Nenhum barril conectável encontrado",
            })
            return
        end

        local idConstrucaoResolvida = nil
        if args.linking then
            local dadosConstrucao = ResolverConstrucaoDoBarril(quadrado, nil, 20)
            if not dadosConstrucao then
                local reparado = nil
                local celula = getCell and getCell()
                if celula then
                    for dx = -20, 20 do
                        for dy = -20, 20 do
                            local gsq = celula:getGridSquare(args.bx + dx, args.by + dy, args.bz)
                            if gsq then
                                local objs = gsq:getObjects()
                                if objs then
                                    for i = 0, objs:size() - 1 do
                                        local obj = objs:get(i)
                                        if obj and instanceof(obj, "IsoGenerator") then
                                            local poolId = obj:getModData() and obj:getModData().Gen_BuildingPoolID or nil
                                            if poolId then
                                                reparado = GarantirEstadoConstrucao(poolId, obj, "BarrelLink")
                                                if reparado then break end
                                            end
                                        end
                                    end
                                end
                            end
                            if reparado then break end
                        end
                        if reparado then break end
                    end
                end
                if reparado then
                    dadosConstrucao = ResolverConstrucaoDoBarril(quadrado, reparado.id, 20)
                end
            end
            if not dadosConstrucao then
                local stateManager = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                local totalConstrucoes = stateManager and stateManager.GetAllBuildings and ContarEntradasMapa(stateManager.GetAllBuildings() or {}) or 0
                LKS_EletricidadeConstrucao.Core.Logger.Warn(
                    string.format("Nenhuma construcao associada para o barril (%d,%d,%d); construcoesNoEstado=%d",
                        args.bx, args.by, args.bz, totalConstrucoes),
                    "ServerCommands")
                RejeitarRequisicao(player, command, "construção não encontrada para o link do barril", {
                    bx = args.bx,
                    by = args.by,
                    bz = args.bz,
                    message = "Nenhuma rede de gerador válida encontrada para este barril",
                })
                return
            end
            idConstrucaoResolvida = dadosConstrucao.id
        else
            idConstrucaoResolvida = (Barris.GetLinkedBuilding and Barris.GetLinkedBuilding(barril)) or args.buildingID
        end

        if args.linking then
            local ok, err = Barris.Link(barril, idConstrucaoResolvida)
            if not ok then
                RejeitarRequisicao(player, command, err, {
                    bx = args.bx,
                    by = args.by,
                    bz = args.bz,
                    message = "Não foi possível conectar o barril",
                })
                return
            end
        else
            Barris.Unlink(barril, idConstrucaoResolvida)
        end

        local Distribuidor = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
        if Distribuidor and idConstrucaoResolvida then
            pcall(function()
                if Distribuidor.RefreshBuildingStats then
                    Distribuidor.RefreshBuildingStats(idConstrucaoResolvida)
                elseif Distribuidor.ForceUpdateBuilding then
                    Distribuidor.ForceUpdateBuilding(idConstrucaoResolvida)
                elseif Distribuidor.ForceUpdate then
                    Distribuidor.ForceUpdate()
                end
            end)
        end

        EnviarResultadoAcao(player, command, true, {
            bx = args.bx,
            by = args.by,
            bz = args.bz,
            buildingID = idConstrucaoResolvida,
            linking = args.linking == true,
            messageKey = args.linking and "IGUI_LKS_EletricidadeConstrucao_BarrelLinked" or "IGUI_LKS_EletricidadeConstrucao_BarrelUnlinked",
        })
    elseif command == "ForceDist" then
        local Distribuidor = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
        if not Distribuidor or not args then return end
        if args.buildingID then
            GarantirEstadoConstrucao(args.buildingID, nil, "ForceDist")
        end
        if args.buildingID and Distribuidor.RefreshBuildingStats then
            Distribuidor.RefreshBuildingStats(args.buildingID)
        elseif args.buildingID and Distribuidor.ForceUpdateBuilding then
            Distribuidor.ForceUpdateBuilding(args.buildingID)
        elseif Distribuidor.ForceUpdate then
            Distribuidor.ForceUpdate()
        end
    elseif command == "HeatingToggle" then
        if not args or not args.genX then
            RejeitarRequisicao(player, command, "coordenadas do gerador ausentes", {
                message = "Requisição de aquecimento inválida",
            })
            return
        end
        local StateManager = LKS_EletricidadeConstrucao.Core.StateManager
        local GenData      = LKS_EletricidadeConstrucao.Data.Generator
        if not StateManager or not GenData then return end

        local gerador = LocalizarGeradorEm(args.genX, args.genY, args.genZ)
        if not gerador then
            RejeitarRequisicao(player, command, "gerador não encontrado", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Gerador não disponível",
            })
            return
        end
        if not IsJogadorProximoAncoraAquecimento(player, args)
                and not IsJogadorProximoAoGerador(player, gerador) then
            RejeitarRequisicao(player, command, "jogador não está próximo ao gerador", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Aproxime-se do interruptor do prédio ou do gerador",
            })
            return
        end

        local genId   = GenData.MakeId(args.genX, args.genY, args.genZ)
        local genData = StateManager.GetGenerator(genId)
        if not genData then
            RejeitarRequisicao(player, command, "gerador não encontrado no estado", {
                genX = args.genX,
                genY = args.genY,
                genZ = args.genZ,
                message = "Os dados de aquecimento estão indisponíveis",
            })
            return
        end

        local enabled    = (args.enabled == true)
        local srcCount   = math.max(0, tonumber(args.sourceCount) or 0)
        local targetTemp = math.max(15, math.min(30, tonumber(args.targetTemp) or 22))

        -- 1. Atualiza dados lógicos do gerador
        genData.heatingEnabled    = enabled
        genData.heatingSourceCount = srcCount
        genData.heatingTargetTemp  = targetTemp

        -- 2. Atualiza todas as construções vinculadas a este gerador
        if genData.connectedBuildings then
            for _, idConstrucao in pairs(genData.connectedBuildings) do
                local bd = StateManager.GetBuilding(idConstrucao)
                if bd then
                    bd.heatingEnabled    = enabled
                    bd.heatingSourceCount = math.max(bd.heatingSourceCount or 0, srcCount)
                    bd.heatingTargetTemp  = targetTemp
                end
            end
        end

        StateManager.MarkDirty()

        -- 3. Aplica o estado físico diretamente no IsoGenerator
        local dadosModGerador = gerador:getModData()
        dadosModGerador.HeatingEnabled    = enabled
        dadosModGerador.HeatingTargetTemp = targetTemp
        if LKS_EletricidadeConstrucao.Core.Runtime and LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync
                and LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
            gerador:transmitModData()
        end

        LKS_EletricidadeConstrucao.Core.Logger.Info(
            string.format("[HeatingToggle] Gerador %s: enabled=%s fontes=%d temp=%.1f",
                genId, tostring(enabled), srcCount, targetTemp),
            "Heating"
        )

        EnviarResultadoAcao(player, command, true, {
            genX = args.genX,
            genY = args.genY,
            genZ = args.genZ,
            heatingEnabled = enabled,
            heatingTargetTemp = targetTemp,
        })
    end
end

if Events.OnClientCommand then
    Events.OnClientCommand.Add(AoReceberComandoCliente)
    print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerCommands.lua] Modulo de comandos de rede carregado com sucesso!")
else
    print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerCommands.lua] AVISO: Evento OnClientCommand nao disponivel")
end

return true
