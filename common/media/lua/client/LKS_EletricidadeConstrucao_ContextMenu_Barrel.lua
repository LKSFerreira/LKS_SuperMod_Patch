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

-- ARQUIVO: LKS_EletricidadeConstrucao_ContextMenu_Barrel.lua
-- OBJETIVO: Constrói as opções de menu de contexto (clique direito) para barris de combustível e água.
-- LOCALIZAÇÃO: client

if not LKS_EletricidadeConstrucao then return end

require "actions/LKS_EletricidadeConstrucao_Actions_LinkBarrel"

print("[LKS PATCH - LKS_EletricidadeConstrucao_ContextMenu_Barrel.lua] Carregando Menu de Contexto do Barril...")

--- Verifica se uma tabela Lua possui entradas válidas.
--- @param tabela table A tabela a ser analisada.
--- @return boolean Retorna true se a tabela contiver chaves.
local function TabelaPossuiEntradas(tabela)
    if type(tabela) ~= "table" then return false end
    for _ in pairs(tabela) do
        return true
    end
    return false
end

--- Verifica se as coordenadas informadas estão dentro da caixa delimitadora da construção.
--- @param dadosConstrucao table Os limites geométricos da construção.
--- @param coordenadaX number Coordenada X física.
--- @param coordenadaY number Coordenada Y física.
--- @return boolean Retorna true se estiver contido na área delimitada.
local function EstaDentroDaCaixaDelimitadora(dadosConstrucao, coordenadaX, coordenadaY)
    local caixaDelimitadora = dadosConstrucao and dadosConstrucao.boundingBox
    if type(caixaDelimitadora) ~= "table" then return false end

    local minimoX = tonumber(caixaDelimitadora.minX or caixaDelimitadora[1])
    local minimoY = tonumber(caixaDelimitadora.minY or caixaDelimitadora[2])
    local maximoX = tonumber(caixaDelimitadora.maxX or caixaDelimitadora[3])
    local maximoY = tonumber(caixaDelimitadora.maxY or caixaDelimitadora[4])
    if not (minimoX and minimoY and maximoX and maximoY) then
        return false
    end

    return coordenadaX >= (minimoX - 1) and coordenadaX <= (maximoX + 1)
       and coordenadaY >= (minimoY - 1) and coordenadaY <= (maximoY + 1)
end

--- Realiza busca nas proximidades por uma estrutura predial nativa da engine (IsoBuilding).
--- @param celula any A célula ativa do mapa.
--- @param quadrado any O GridSquare referenciado.
--- @param raio integer Raio de varredura.
--- @return any|nil O objeto IsoBuilding correspondente ou nil.
local function LocalizarPredioProximo(celula, quadrado, raio)
    local predioIso = quadrado and quadrado:getBuilding() or nil
    if predioIso then return predioIso end
    if not celula or not quadrado then return nil end

    local baseX, baseY, baseZ = quadrado:getX(), quadrado:getY(), quadrado:getZ()
    for r = 1, raio do
        for deslocamentoX = -r, r do
            for deslocamentoY = -r, r do
                if math.abs(deslocamentoX) == r or math.abs(deslocamentoY) == r then
                    local quadradoAdjacente = celula:getGridSquare(baseX + deslocamentoX, baseY + deslocamentoY, baseZ)
                    if quadradoAdjacente then
                        predioIso = quadradoAdjacente:getBuilding()
                        if predioIso then
                            return predioIso
                        end
                    end
                end
            end
        end
    end

    return nil
end

--- Valida se uma construção lógica do estado corresponde ao objeto físico IsoBuilding da engine.
--- @param dadosConstrucao table Os limites da construção no estado.
--- @param predioIso any O objeto IsoBuilding correspondente.
--- @param celula any A célula ativa do mapa.
--- @param fallbackZ integer Altura Z de fallback.
--- @return boolean Retorna true se houver correspondência física de quadrantes.
local function PredioCorrespondeAoIso(dadosConstrucao, predioIso, celula, fallbackZ)
    if not dadosConstrucao or not predioIso or not celula then return false end
    if dadosConstrucao.x == nil or dadosConstrucao.y == nil then return false end

    local quadradoInterruptor = celula:getGridSquare(dadosConstrucao.x, dadosConstrucao.y, dadosConstrucao.z or fallbackZ or 0)
    return quadradoInterruptor and quadradoInterruptor:getBuilding() == predioIso or false
end

--- Verifica se o gerador está ativamente em operação no estado.
--- @param dadosGerador table Os dados estruturados do gerador.
--- @return boolean Retorna true se estiver em funcionamento ativo.
local function IsGeradorFuncionando(dadosGerador)
    local ClasseDadosGerador = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
    if ClasseDadosGerador and ClasseDadosGerador.IsRunning then
        return ClasseDadosGerador.IsRunning(dadosGerador)
    end

    return dadosGerador and (dadosGerador.fuelAmount or 0) > 0 and dadosGerador.activated ~= false
end

--- Analisa se um determinado gerador possui dependência direta ou indireta de links com a construção.
--- @param dadosGerador table Os dados do gerador.
--- @param dadosConstrucao table A construção correspondente.
--- @param quadrado any O GridSquare do barril.
--- @param gerenciadorEstado table Referência do StateManager.
--- @return boolean Retorna true se houver qualquer vínculo elétrico entre ambos.
local function GeradorReferenciaConstrucao(dadosGerador, dadosConstrucao, quadrado, gerenciadorEstado)
    if not dadosGerador or not dadosConstrucao then return false end

    local alvoX, alvoY = dadosConstrucao.x, dadosConstrucao.y
    local quadradoX = quadrado and quadrado:getX() or nil
    local quadradoY = quadrado and quadrado:getY() or nil

    for _, idConectado in pairs(dadosGerador.connectedBuildings or {}) do
        if idConectado == dadosConstrucao.id then
            return true
        end

        local construcaoReferenciada = gerenciadorEstado and gerenciadorEstado.GetBuilding and gerenciadorEstado.GetBuilding(idConectado) or nil
        if construcaoReferenciada then
            if alvoX and alvoY and construcaoReferenciada.x == alvoX and construcaoReferenciada.y == alvoY then
                return true
            end
            if construcaoReferenciada.x and construcaoReferenciada.y and EstaDentroDaCaixaDelimitadora(dadosConstrucao, construcaoReferenciada.x, construcaoReferenciada.y) then
                return true
            end
            if alvoX and alvoY and EstaDentroDaCaixaDelimitadora(construcaoReferenciada, alvoX, alvoY) then
                return true
            end
            if quadradoX and quadradoY and EstaDentroDaCaixaDelimitadora(dadosConstrucao, quadradoX, quadradoY)
                    and EstaDentroDaCaixaDelimitadora(construcaoReferenciada, quadradoX, quadradoY) then
                return true
            end
        else
            local coordenadaX, coordenadaY = string.match(idConectado, "^bld_(%-?%d+)_(%-?%d+)_")
            coordenadaX = tonumber(coordenadaX)
            coordenadaY = tonumber(coordenadaY)
            if coordenadaX and coordenadaY then
                if alvoX and alvoY and coordenadaX == alvoX and coordenadaY == alvoY then
                    return true
                end
                if EstaDentroDaCaixaDelimitadora(dadosConstrucao, coordenadaX, coordenadaY) then
                    return true
                end
            end
        end
    end

    return false
end

--- Calcula a pontuação de relevância de geradores associados a uma construção específica.
--- @param dadosConstrucao table Os limites da construção.
--- @param quadrado any O quadrado de origem.
--- @param gerenciadorEstado table Instância do StateManager.
--- @return integer Retorna a pontuação de prioridade baseada na proximidade e no uptime elétrico.
local function ObterPontuacaoGeradorConstrucao(dadosConstrucao, quadrado, gerenciadorEstado)
    if not dadosConstrucao or not gerenciadorEstado then return 0 end

    local possuiQualquerGerador = false
    local ClasseDadosGerador = LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator

    if dadosConstrucao.connectedGenerators and ClasseDadosGerador and ClasseDadosGerador.MakeId and gerenciadorEstado.GetGenerator then
        for _, chaveGerador in pairs(dadosConstrucao.connectedGenerators) do
            local geradorX, geradorY, geradorZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if geradorX then
                local geradorXInt, geradorYInt, geradorZInt = tonumber(geradorX), tonumber(geradorY), tonumber(geradorZ)
                local idGerador = (geradorXInt and geradorYInt and geradorZInt) and ClasseDadosGerador.MakeId(geradorXInt, geradorYInt, geradorZInt) or nil
                local dadosGerador = idGerador and gerenciadorEstado.GetGenerator(idGerador) or nil
                if dadosGerador and GeradorReferenciaConstrucao(dadosGerador, dadosConstrucao, quadrado, gerenciadorEstado) then
                    possuiQualquerGerador = true
                    if IsGeradorFuncionando(dadosGerador) then
                        return 2
                    end
                end
            end
        end
    end

    if gerenciadorEstado.GetAllGenerators then
        for _, dadosGerador in pairs(gerenciadorEstado.GetAllGenerators() or {}) do
            if GeradorReferenciaConstrucao(dadosGerador, dadosConstrucao, quadrado, gerenciadorEstado) then
                possuiQualquerGerador = true
                if IsGeradorFuncionando(dadosGerador) then
                    return 2
                end
            end
        end
    end

    return possuiQualquerGerador and 1 or 0
end

--- Pontua um candidato predial com base na distância geométrica e status da rede elétrica.
--- @param dadosConstrucao table Os limites prediais no estado.
--- @param quadrado any O quadrado físico do barril.
--- @param predioIso any O objeto IsoBuilding correspondente (se detectado).
--- @param raio number O raio máximo de varredura.
--- @param celula any A célula ativa do mapa.
--- @param gerenciadorEstado table Instância do StateManager.
--- @param idConstrucaoPreferencial string|nil O ID da construção preferencial já vinculada.
--- @return number|nil Retorna a pontuação de prioridade final do candidato, ou nil se rejeitado.
local function PontuarCandidatoConstrucao(dadosConstrucao, quadrado, predioIso, raio, celula, gerenciadorEstado, idConstrucaoPreferencial)
    if not dadosConstrucao or not dadosConstrucao.id then return nil end

    local baseX, baseY = quadrado:getX(), quadrado:getY()
    local deslocamentoX = dadosConstrucao.x ~= nil and (dadosConstrucao.x - baseX) or nil
    local deslocamentoY = dadosConstrucao.y ~= nil and (dadosConstrucao.y - baseY) or nil
    local distanciaAoQuadrado = (deslocamentoX and deslocamentoY) and (deslocamentoX * deslocamentoX + deslocamentoY * deslocamentoY) or nil
    local raioAoQuadrado = raio * raio
    local estaDentro = EstaDentroDaCaixaDelimitadora(dadosConstrucao, baseX, baseY)
    local correspondeIso = PredioCorrespondeAoIso(dadosConstrucao, predioIso, celula, quadrado:getZ())
    local dentroDoRaio = distanciaAoQuadrado and distanciaAoQuadrado <= raioAoQuadrado or false

    if not estaDentro and not correspondeIso and not dentroDoRaio then
        return nil
    end

    local pontuacaoGerador = ObterPontuacaoGeradorConstrucao(dadosConstrucao, quadrado, gerenciadorEstado)
    if pontuacaoGerador == 0 then
        return nil
    end

    local pontuacao = 0
    if estaDentro then pontuacao = pontuacao + 200 end
    if correspondeIso then pontuacao = pontuacao + 120 end
    if dentroDoRaio and distanciaAoQuadrado then
        pontuacao = pontuacao + math.floor((raioAoQuadrado - distanciaAoQuadrado) / math.max(raio, 1))
    end
    pontuacao = pontuacao + (pontuacaoGerador == 2 and 80 or 30)
    if dadosConstrucao.isPowered then pontuacao = pontuacao + 40 end
    if idConstrucaoPreferencial and dadosConstrucao.id == idConstrucaoPreferencial then
        pontuacao = pontuacao + 5
    end

    return pontuacao
end

--- Localiza no estado a construção com maior adequabilidade para ser vinculada ao barril.
--- @param quadrado any O GridSquare do barril.
--- @param raio integer O raio físico máximo de alcance.
--- @param idConstrucaoPreferencial string|nil O ID do prédio previamente vinculado.
--- @return table|nil Retorna o registro da construção mais adequada, ou nil se nenhum candidato for aprovado.
local function LocalizarConstrucaoMaisProxima(quadrado, raio, idConstrucaoPreferencial)
    raio = raio or 20

    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not gerenciadorEstado or not gerenciadorEstado.GetAllBuildings then return nil end

    local construcoes = gerenciadorEstado.GetAllBuildings()
    if not TabelaPossuiEntradas(construcoes) then return nil end

    local celula = getCell()
    if not celula or not quadrado then return nil end

    local predioIso = LocalizarPredioProximo(celula, quadrado, raio)
    local melhorConstrucao, melhorPontuacao = nil, nil

    for _, dadosConstrucao in pairs(construcoes) do
        local pontuacao = PontuarCandidatoConstrucao(
            dadosConstrucao, quadrado, predioIso, raio, celula, gerenciadorEstado, idConstrucaoPreferencial)
        if pontuacao and (not melhorPontuacao or pontuacao > melhorPontuacao) then
            melhorPontuacao = pontuacao
            melhorConstrucao = dadosConstrucao
        end
    end

    return melhorConstrucao
end

--- Localiza nas proximidades o ID da piscina elétrica de geradores nativos da engine.
--- @param quadrado any O GridSquare inicial.
--- @param raio integer O raio de varredura.
--- @return string|nil Retorna o ID da piscina de construções, ou nil se nenhum gerador ativo for achado.
local function LocalizarIdFiltroGeradorProximo(quadrado, raio)
    if not quadrado then return nil end

    raio = raio or 20
    local celula = getCell()
    if not celula then return nil end

    local melhorIdGrupo = nil
    local melhorPontuacao = nil
    local baseX, baseY, baseZ = quadrado:getX(), quadrado:getY(), quadrado:getZ()

    for deslocamentoX = -raio, raio do
        for deslocamentoY = -raio, raio do
            local quadradoAlvo = celula:getGridSquare(baseX + deslocamentoX, baseY + deslocamentoY, baseZ)
            if quadradoAlvo then
                local objetos = quadradoAlvo:getObjects()
                if objetos then
                    for indiceObjeto = 0, objetos:size() - 1 do
                        local objeto = objetos:get(indiceObjeto)
                        if objeto and instanceof(objeto, "IsoGenerator") then
                            local dadosMod = objeto:getModData()
                            local idGrupo = dadosMod and dadosMod.Gen_BuildingPoolID or nil
                            if idGrupo then
                                local distancia = math.abs(deslocamentoX) + math.abs(deslocamentoY)
                                local pontuacao = distancia
                                if objeto:isActivated() then
                                    pontuacao = pontuacao - 100
                                end
                                if melhorPontuacao == nil or pontuacao < melhorPontuacao then
                                    melhorPontuacao = pontuacao
                                    melhorIdGrupo = idGrupo
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return melhorIdGrupo
end

--- Procura um barril de combustível válido na lista de objetos interagíveis do quadrado clicado.
--- @param objetosMundo table A lista de objetos selecionados pelo clique direito.
--- @return any|nil Retorna o objeto IsoObject do barril se for elegível, ou nil.
local function LocalizarBarril(objetosMundo)
    if not objetosMundo then return nil end
    local ClasseBarris = LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels
    if not ClasseBarris then return nil end
    
    -- No B42, objetosMundo é uma tabela padrão Lua em vez de um ArrayList Java.
    for _, objeto in ipairs(objetosMundo) do
        if objeto and ClasseBarris.IsLinkable(objeto) then return objeto end
    end
    return nil
end

-- ============================================================================
-- EVENTO DE INJEÇÃO DO MENU DE CONTEXTO DO JOGO
-- ============================================================================

Events.OnFillWorldObjectContextMenu.Add(function(numeroJogador, contexto, objetosMundo, modoTeste)
    local ClasseBarris = LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels
    if not ClasseBarris then return end
    
    local ClasseRuntime = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local ehClienteMultiplayer = ClasseRuntime and ClasseRuntime.IsMultiplayerClient and ClasseRuntime.IsMultiplayerClient()

    local barril = LocalizarBarril(objetosMundo)
    if not barril then return end

    -- Sinaliza para a engine que pretendemos adicionar opções
    if modoTeste then return true end

    local jogador = getSpecificPlayer(numeroJogador)
    if not jogador then return end

    local quadrado = barril:getSquare()
    if not quadrado then return end
    
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local idConstrucaoVinculada = ClasseBarris.GetLinkedBuilding and ClasseBarris.GetLinkedBuilding(barril) or nil
    local dadosConstrucao = idConstrucaoVinculada and gerenciadorEstado and gerenciadorEstado.GetBuilding
        and gerenciadorEstado.GetBuilding(idConstrucaoVinculada) or nil
    
    local idGrupoGeradores = nil
    if not dadosConstrucao then
        dadosConstrucao = LocalizarConstrucaoMaisProxima(quadrado, 20, idConstrucaoVinculada)
    end
    if not dadosConstrucao then
        idGrupoGeradores = LocalizarIdFiltroGeradorProximo(quadrado, 20)
        if idGrupoGeradores and gerenciadorEstado and gerenciadorEstado.GetBuilding then
            dadosConstrucao = gerenciadorEstado.GetBuilding(idGrupoGeradores)
        end
    end
    
    local estaVinculado = idConstrucaoVinculada ~= nil
    local permitirVinculoResolvidoPeloServidor = ehClienteMultiplayer and not estaVinculado
    local idConstrucaoResolvida = (dadosConstrucao and dadosConstrucao.id) or idGrupoGeradores or nil
    local podeVincular = idConstrucaoResolvida ~= nil or permitirVinculoResolvidoPeloServidor

    if estaVinculado then
        -- Opção de Desvincular Barril
        local opcao = contexto:addOption(
            getText("IGUI_LKS_EletricidadeConstrucao_UnlinkBarrel") or "Desvincular do Reservatório de Combustível",
            objetosMundo,
            function()
                ISTimedActionQueue.add(
                    LKS_EletricidadeConstrucao_LinkBarrelAction:new(jogador, barril, quadrado, idConstrucaoVinculada, false))
            end
        )
        _ = opcao
    else
        -- Opção de Vincular Barril
        local opcao = contexto:addOption(
            getText("IGUI_LKS_EletricidadeConstrucao_LinkBarrel") or "Vincular ao Reservatório de Combustível",
            objetosMundo,
            function()
                if not podeVincular then
                    jogador:Say(getText("IGUI_LKS_EletricidadeConstrucao_BarrelNoBuildingNearby") or "Nenhuma construção energizada por perto")
                    return
                end
                ISTimedActionQueue.add(
                    LKS_EletricidadeConstrucao_LinkBarrelAction:new(jogador, barril, quadrado, idConstrucaoResolvida, true))
            end
        )
        if not podeVincular then
            opcao.notAvailable = true
            local dicaContexto = ISToolTip:new()
            dicaContexto:initialise()
            dicaContexto:setVisible(false)
            dicaContexto:setName(getText("IGUI_LKS_EletricidadeConstrucao_BarrelNoBuildingNearby") or "Nenhuma construção energizada por perto")
            opcao.toolTip = dicaContexto
        end
    end
end)

print("[LKS PATCH - LKS_EletricidadeConstrucao_ContextMenu_Barrel.lua] Carregado com sucesso!")
