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

-- ARQUIVO: LKS_EletricidadeConstrucao_ContextMenu_LightSwitch.lua
-- OBJETIVO: Permite ao jogador clicar com o botão direito em interruptores de luz para consultar a carga elétrica e estado da rede de energia do prédio.
-- LOCALIZAÇÃO: client

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_ContextMenu_LightSwitch] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

print("[LKS_EletricidadeConstrucao_ContextMenu_LightSwitch] Carregando Menu de Contexto do Interruptor de Luz...")

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ContextMenu_LightSwitch")

-- ============================================================================
-- FUNÇÕES AUXILIARES
-- ============================================================================

--- Calcula a pontuação de relevância de um gerador para seleção.
--- @param gerador any O objeto IsoGenerator.
--- @param idConstrucaoEsperada string|nil O ID da construção esperada.
--- @param esperadoX number|nil A coordenada X esperada.
--- @param esperadoY number|nil A coordenada Y esperada.
--- @return number Retorna a pontuação de relevância calculada.
local function ObterPontuacaoSelecaoGerador(gerador, idConstrucaoEsperada, esperadoX, esperadoY)
    if not gerador then return 0 end

    local pontuacao = 0
    local dadosMod = gerador.getModData and gerador:getModData() or nil
    local idConstrucao = dadosMod and dadosMod.Gen_BuildingPoolID or nil

    if idConstrucaoEsperada and idConstrucao == idConstrucaoEsperada then
        pontuacao = pontuacao + 300
    end

    if idConstrucao and esperadoX ~= nil and esperadoY ~= nil then
        local baseX, baseY = string.match(idConstrucao, "^bld_(%-?%d+)_(%-?%d+)_")
        if baseX and tonumber(baseX) == esperadoX and tonumber(baseY) == esperadoY then
            pontuacao = pontuacao + 200
        end
    end

    if gerador:isActivated() then
        pontuacao = pontuacao + 100
    end

    if (gerador:getFuel() or 0) > 0 then
        pontuacao = pontuacao + 10
    end

    return pontuacao
end

--- Decide se o novo candidato a gerador é melhor do que o atual campeão.
--- @param pontuacao number Pontuação do novo gerador.
--- @param indiceOrdem number|nil Posição de carregamento original na lista.
--- @param distancia number|nil Distância geométrica.
--- @param melhorPontuacao number|nil Melhor pontuação registrada.
--- @param melhorIndiceOrdem number|nil Melhor posição de carregamento anterior.
--- @param melhorDistancia number|nil Melhor distância geométrica anterior.
--- @return boolean Retorna true se for um candidato melhor.
local function EhMelhorCandidatoGerador(pontuacao, indiceOrdem, distancia, melhorPontuacao, melhorIndiceOrdem, melhorDistancia)
    if melhorPontuacao == nil or pontuacao > melhorPontuacao then
        return true
    end
    if pontuacao < melhorPontuacao then
        return false
    end
    if indiceOrdem ~= nil and melhorIndiceOrdem ~= nil and indiceOrdem ~= melhorIndiceOrdem then
        return indiceOrdem < melhorIndiceOrdem
    end
    if distancia ~= nil and melhorDistancia ~= nil and distancia ~= melhorDistancia then
        return distancia < melhorDistancia
    end
    return false
end

--- Busca um gerador fisicamente conectado à construção contendo este interruptor de luz.
--- Varre o ModData dos geradores próximos (raio de 20) procurando por Gen_BuildingPoolID compatível.
--- @param coordenadaX number Coordenada X do interruptor.
--- @param coordenadaY number Coordenada Y do interruptor.
--- @param coordenadaZ number Coordenada Z do interruptor.
--- @return any|nil O gerador IsoGenerator encontrado, ou nil.
local function LocalizarGeradorParaInterruptor(coordenadaX, coordenadaY, coordenadaZ)
    local celula = getCell()
    if not celula then return nil end

    local melhorGerador = nil
    local melhorPontuacao = nil
    local melhorDistancia = nil

    -- Pesquisa no nível clicado e no nível Z=0 (térreo canônico).
    -- Construções lógicas e seus interruptores principais são catalogados em Z=0.
    local niveisZ = {coordenadaZ}
    if coordenadaZ ~= 0 then niveisZ[#niveisZ + 1] = 0 end

    for _, zPesquisa in ipairs(niveisZ) do
        local idConstrucaoEsperada = LKS_EletricidadeConstrucao.Data.Building.MakeId(coordenadaX, coordenadaY, zPesquisa)
        for raio = 0, 20 do
            for deslocamentoX = -raio, raio do
                for deslocamentoY = -raio, raio do
                    -- Varre apenas o perímetro externo deste raio (o centro já foi checado)
                    if math.abs(deslocamentoX) == raio or math.abs(deslocamentoY) == raio or raio == 0 then
                        local quadrado = celula:getGridSquare(coordenadaX + deslocamentoX, coordenadaY + deslocamentoY, zPesquisa)
                        if quadrado then
                            local objetos = quadrado:getObjects()
                            if objetos then
                                for indiceObjeto = 0, objetos:size() - 1 do
                                    local objeto = objetos:get(indiceObjeto)
                                    if objeto and instanceof(objeto, "IsoGenerator") then
                                        local dadosMod = objeto:getModData()
                                        local idConstrucao = dadosMod.Gen_BuildingPoolID

                                        if idConstrucao then
                                            local distancia = math.abs(deslocamentoX) + math.abs(deslocamentoY)
                                            local pontuacao = ObterPontuacaoSelecaoGerador(objeto, idConstrucaoEsperada, coordenadaX, coordenadaY)
                                            if pontuacao then
                                                pontuacao = pontuacao - distancia
                                                if EhMelhorCandidatoGerador(pontuacao, nil, distancia, melhorPontuacao, nil, melhorDistancia) then
                                                    melhorGerador = objeto
                                                    melhorPontuacao = pontuacao
                                                    melhorDistancia = distancia
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
        end
    end

    return melhorGerador
end

--- Obtém o melhor gerador físico carregado no mapa que pertence a esta construção.
--- @param dadosConstrucao table Os limites da construção.
--- @return any|nil O gerador IsoGenerator ou nil.
local function ObterGeradorConstrucao(dadosConstrucao)
    if not dadosConstrucao then return nil end
    local celula = getCell()
    if not celula then return nil end

    local idConstrucaoPrincipal = dadosConstrucao.id
    local baseX, baseY = dadosConstrucao.x, dadosConstrucao.y
    local melhorGerador = nil
    local melhorPontuacao = nil
    local melhorIndiceOrdem = nil

    local function considerarGerador(gerador, indiceOrdem)
        if not (gerador and instanceof(gerador, "IsoGenerator")) then return end
        local pontuacao = ObterPontuacaoSelecaoGerador(gerador, idConstrucaoPrincipal, baseX, baseY)
        if not pontuacao then return end
        if EhMelhorCandidatoGerador(pontuacao, indiceOrdem, nil, melhorPontuacao, melhorIndiceOrdem, nil) then
            melhorGerador = gerador
            melhorPontuacao = pontuacao
            melhorIndiceOrdem = indiceOrdem
        end
    end

    -- 1. Caminho Rápido: connectedGenerators
    -- Nota: connectedGenerators é desserializado do Kahlua no ModData e possui chaves de strings numéricas.
    if dadosConstrucao.connectedGenerators then
        for indice, chaveGerador in pairs(dadosConstrucao.connectedGenerators) do
            local geradorX, geradorY, geradorZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if geradorX then
                local quadrado = celula:getGridSquare(tonumber(geradorX), tonumber(geradorY), tonumber(geradorZ))
                if quadrado then
                    local objetos = quadrado:getObjects()
                    if objetos then
                        for indiceObjeto = 0, objetos:size() - 1 do
                            local gerador = objetos:get(indiceObjeto)
                            considerarGerador(gerador, tonumber(indice) or math.huge)
                        end
                    end
                end
            end
        end
    end

    -- 2. Caminho Secundário/Fallback: Varredura reversa no StateManager
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if gerenciadorEstado and gerenciadorEstado.GetAllGenerators then
        for _, dadosGerador in pairs(gerenciadorEstado.GetAllGenerators() or {}) do
            local encontrado = false
            for _, idConstrucaoGerador in pairs(dadosGerador.connectedBuildings or {}) do
                if idConstrucaoGerador == idConstrucaoPrincipal then
                    encontrado = true
                    break
                end
                
                -- Casamento por coordenadas para evitar problemas de drift de IDs salvos
                if baseX and baseY then
                    local coordenadaX, coordenadaY = string.match(idConstrucaoGerador, "^bld_(%-?%d+)_(%-?%d+)_")
                    if coordenadaX and tonumber(coordenadaX) == baseX and tonumber(coordenadaY) == baseY then
                        encontrado = true
                        break
                    end
                    local construcaoReferenciada = gerenciadorEstado.GetBuilding(idConstrucaoGerador)
                    if construcaoReferenciada and construcaoReferenciada.x == baseX and construcaoReferenciada.y == baseY then
                        encontrado = true
                        break
                    end
                end
            end

            if encontrado then
                local quadrado = celula:getGridSquare(dadosGerador.x, dadosGerador.y, dadosGerador.z)
                if quadrado then
                    local objetos = quadrado:getObjects()
                    if objetos then
                        for indiceObjeto = 0, objetos:size() - 1 do
                            local gerador = objetos:get(indiceObjeto)
                            considerarGerador(gerador, nil)
                        end
                    end
                end
            end
        end
    end

    return melhorGerador
end

--- Verifica se as coordenadas estão compreendidas nos limites da construção.
--- @param dadosConstrucao table Os limites da construção.
--- @param coordenadaX number Coordenada X.
--- @param coordenadaY number Coordenada Y.
--- @return boolean Retorna true se estiver contido na área delimitada.
local function EstaDentroDosLimitesConstrucao(dadosConstrucao, coordenadaX, coordenadaY)
    local caixaDelimitadora = dadosConstrucao and dadosConstrucao.boundingBox
    if not caixaDelimitadora then return false end

    local minimoX = tonumber(caixaDelimitadora.minX or caixaDelimitadora[1])
    local minimoY = tonumber(caixaDelimitadora.minY or caixaDelimitadora[2])
    local maximoX = tonumber(caixaDelimitadora.maxX or caixaDelimitadora[3])
    local maximoY = tonumber(caixaDelimitadora.maxY or caixaDelimitadora[4])

    if not (minimoX and minimoY and maximoX and maximoY) then
        return false
    end

    return coordenadaX >= minimoX and coordenadaX <= maximoX and coordenadaY >= minimoY and coordenadaY <= maximoY
end

--- Verifica se a construção lógica do estado possui um consumidor ativo registrado no quadrado.
--- @param dadosConstrucao table A construção.
--- @param quadrado any O GridSquare consultado.
--- @return boolean Retorna true se houver consumidor cadastrado nesta coordenada.
local function ConstrucaoPossuiConsumidorNoQuadrado(dadosConstrucao, quadrado)
    if not (dadosConstrucao and dadosConstrucao.powerConsumers and quadrado) then return false end

    local quadradoX, quadradoY, quadradoZ = quadrado:getX(), quadrado:getY(), quadrado:getZ()
    for _, consumidor in pairs(dadosConstrucao.powerConsumers) do
        local consumidorX = tonumber(consumidor and (consumidor.squareX or consumidor.x))
        local consumidorY = tonumber(consumidor and (consumidor.squareY or consumidor.y))
        local consumidorZ = tonumber(consumidor and (consumidor.squareZ or consumidor.z))
        if consumidorX == quadradoX and consumidorY == quadradoY and (consumidorZ == nil or consumidorZ == quadradoZ) then
            return true
        end
    end

    return false
end

--- Localiza e resolve a construção lógica do estado associada a este interruptor.
--- @param quadrado any O GridSquare do interruptor.
--- @return table|nil O registro de dados da construção ou nil se não encontrado.
local function ResolverDadosConstrucaoParaInterruptor(quadrado)
    if not quadrado then return nil end

    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not gerenciadorEstado then return nil end

    local ancoraX, ancoraY, ancoraZ = quadrado:getX(), quadrado:getY(), quadrado:getZ()
    local idDireto = LKS_EletricidadeConstrucao.Data.Building.MakeId(ancoraX, ancoraY, ancoraZ)
    local construcaoDireta = gerenciadorEstado.GetBuilding and gerenciadorEstado.GetBuilding(idDireto) or nil
    if construcaoDireta then
        return construcaoDireta
    end

    local celula = getCell()
    local predioIsoClicado = celula and quadrado:getBuilding() or nil
    local melhorConstrucao = nil
    local melhorPontuacao = nil

    if gerenciadorEstado.GetAllBuildings then
        for _, dadosConstrucao in pairs(gerenciadorEstado.GetAllBuildings() or {}) do
            local pontuacao = 0

            if dadosConstrucao.x == ancoraX and dadosConstrucao.y == ancoraY then
                pontuacao = pontuacao + 300
                if dadosConstrucao.z == ancoraZ then
                    pontuacao = pontuacao + 25
                end
            end

            if ConstrucaoPossuiConsumidorNoQuadrado(dadosConstrucao, quadrado) then
                pontuacao = pontuacao + 250
            end

            if predioIsoClicado and celula and dadosConstrucao.x and dadosConstrucao.y and dadosConstrucao.z then
                local quadradoConstrucao = celula:getGridSquare(dadosConstrucao.x, dadosConstrucao.y, dadosConstrucao.z)
                if quadradoConstrucao and quadradoConstrucao:getBuilding() == predioIsoClicado then
                    pontuacao = pontuacao + 200
                end
            end

            if EstaDentroDosLimitesConstrucao(dadosConstrucao, ancoraX, ancoraY) then
                pontuacao = pontuacao + 100
            end

            if pontuacao > 0 and (not melhorPontuacao or pontuacao > melhorPontuacao) then
                melhorPontuacao = pontuacao
                melhorConstrucao = dadosConstrucao
            end
        end
    end

    return melhorConstrucao
end

--- Extrai o objeto Java IsoLightSwitch da lista de itens clicados.
--- @param objetosMundo table A lista de objetos na coordenada do clique.
--- @return any|nil Retorna o interruptor ou nil.
local function LocalizarInterruptorLuz(objetosMundo)
    if not objetosMundo then return nil end
    for _, objeto in ipairs(objetosMundo) do
        if instanceof(objeto, "IsoLightSwitch") then
            return objeto
        end
    end
    return nil
end

-- ============================================================================
-- EVENTO DE INJEÇÃO DO MENU DE CONTEXTO DO JOGO
-- ============================================================================

Events.OnFillWorldObjectContextMenu.Add(function(numeroJogador, contexto, objetosMundo, modoTeste)
    local jogadorObjeto = getSpecificPlayer(numeroJogador)
    if not jogadorObjeto then return end

    local interruptorLuz = LocalizarInterruptorLuz(objetosMundo)
    if not interruptorLuz then return end

    local quadrado = interruptorLuz:getSquare()
    if not quadrado then return end

    local gerador = nil
    local dadosConstrucao = ResolverDadosConstrucaoParaInterruptor(quadrado)
    if dadosConstrucao then
        gerador = ObterGeradorConstrucao(dadosConstrucao)
    end

    -- Escaneia proximidades caso seja uma construção fabricada por players sem IsoBuilding estruturado
    if not gerador and not dadosConstrucao then
        gerador = LocalizarGeradorParaInterruptor(quadrado:getX(), quadrado:getY(), quadrado:getZ())
    end

    if not gerador and not dadosConstrucao then return end

    -- Sinaliza apenas a presença das opções em modo teste
    if modoTeste then return true end

    -- Adiciona a opção "Informações de Energia"
    local opcaoInfoEnergiaConstrucao = contexto:addOption(
        getText("IGUI_BuildingPowerInfoMenu") or "Informações de Energia",
        nil,
        function()
            -- Força a aproximação física do jogador ao quadrado
            luautils.walkAdj(jogadorObjeto, quadrado)

            if LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow then
                LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow.Open(jogadorObjeto, gerador, quadrado, dadosConstrucao)
            elseif gerador and LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.OpenInfoWindow then
                ISTimedActionQueue.add(
                    LKS_EletricidadeConstrucao.Actions.OpenInfoWindow:new(
                        jogadorObjeto,
                        gerador,
                        quadrado,
                        dadosConstrucao and dadosConstrucao.id or nil))
            else
                LKS_EletricidadeConstrucao.Warn("[LightSwitchMenu] Interface GeneratorInfoWindow não carregada!")
            end
        end
    )
    opcaoInfoEnergiaConstrucao.iconTexture = getTexture("media/ui/LKS_House_Electricity_On.png")
end)

print("[LKS_EletricidadeConstrucao_ContextMenu_LightSwitch] Menu de contexto do interruptor carregado com sucesso.")
