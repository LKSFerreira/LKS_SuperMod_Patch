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

-- ARQUIVO: LKS_EletricidadeConstrucao_Heating_Client.lua
-- OBJETIVO: Lê as posições de aquecimento do ModData dos geradores e gerencia os objetos físicos IsoHeatSource no cliente.
-- LOCALIZAÇÃO: client

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Heating_Client] Namespace LKS_EletricidadeConstrucao não encontrado - pulando carregamento do módulo")
    return
end

-- Acesso global utilizado pelos botões de alternação da interface (InfoWindow)
LKS_EletricidadeConstrucao_HeatingClient = LKS_EletricidadeConstrucao_HeatingClient or {}

-- ============================================================================
-- CONSTANTES E ESTADO INTERNO
-- ============================================================================

local DESLOCAMENTO_TEMPERATURA = 7.1  -- Correção visual do PZ: IsoHeatSource temperatura = alvo + deslocamento
local TEMPERATURA_PADRAO       = 22   -- Temperatura padrão em graus Celsius
local RAIO_PADRAO              = 20   -- Raio padrão de aquecimento em blocos (tiles)

local _fontesAtivas = {}   -- chaveGerador ("x_y_z") -> lista de {source = IsoHeatSource}

-- ============================================================================
-- AUXILIARES DE SANDBOX
-- ============================================================================

--- Verifica se o sistema de aquecimento está ativo nas SandboxVars.
--- @return boolean Retorna true se estiver ativo.
local function IsSistemaAtivo()
    local preferenciasSandbox = SandboxVars and SandboxVars.LKS_EletricidadeConstrucao
    if preferenciasSandbox and preferenciasSandbox.HeatingSystemEnabled ~= nil then
        return preferenciasSandbox.HeatingSystemEnabled
    end
    return true
end

--- Retorna o raio de aquecimento configurado no sandbox.
--- @return number O raio de calor.
local function ObterRaio()
    local preferenciasSandbox = SandboxVars and SandboxVars.LKS_EletricidadeConstrucao
    if preferenciasSandbox and preferenciasSandbox.HeatRadius then return preferenciasSandbox.HeatRadius end
    return RAIO_PADRAO
end

--- Insere um gerador físico carregado nas tabelas de resultado, evitando duplicações.
--- @param resultado table A lista de destino.
--- @param vistos table Conjunto de controle de duplicados.
--- @param gerador any O gerador físico.
local function AdicionarGeradorCarregado(resultado, vistos, gerador)
    if not gerador then return end
    local quadrado = gerador:getSquare()
    if not quadrado then return end

    local chave = quadrado:getX() .. "_" .. quadrado:getY() .. "_" .. quadrado:getZ()
    if vistos[chave] then return end

    vistos[chave] = true
    table.insert(resultado, gerador)
end

--- Busca um gerador físico no GridSquare carregado.
--- @param coordenadaX number Coordenada X.
--- @param coordenadaY number Coordenada Y.
--- @param coordenadaZ number Coordenada Z.
--- @return any|nil O gerador IsoGenerator ou nil.
local function LocalizarGeradorCarregadoEm(coordenadaX, coordenadaY, coordenadaZ)
    local celula = getCell()
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

--- Coleta os geradores associados a fontes de aquecimento que estão atualmente ativas.
--- @param resultado table A lista de destino.
--- @param vistos table Conjunto de controle de duplicados.
local function ColetarGeradoresFontesAtivas(resultado, vistos)
    for chaveGerador in pairs(_fontesAtivas) do
        local coordenadaX, coordenadaY, coordenadaZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if coordenadaX then
            AdicionarGeradorCarregado(resultado, vistos, LocalizarGeradorCarregadoEm(tonumber(coordenadaX), tonumber(coordenadaY), tonumber(coordenadaZ)))
        end
    end
end

--- Coleta os geradores associados a janelas gráficas abertas no cliente.
--- @param resultado table A lista de destino.
--- @param vistos table Conjunto de controle de duplicados.
local function ColetarGeradoresDasJanelas(resultado, vistos)
    local InterfaceGrafica = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow
    local instancias = InterfaceGrafica and InterfaceGrafica.instances
    if not instancias then return end

    for _, janela in pairs(instancias) do
        AdicionarGeradorCarregado(resultado, vistos, janela and janela.generator or nil)
    end
end

--- Coleta geradores carregados no mapa nas imediações dos jogadores locais.
--- @param resultado table A lista de destino.
--- @param vistos table Conjunto de controle de duplicados.
--- @param raio number|nil O raio de busca (padrão: 25).
local function ColetarGeradoresProximosAoJogador(resultado, vistos, raio)
    local celula = getCell()
    if not celula then return end

    raio = raio or 25
    for indiceJogador = 0, 3 do
        local jogador = getSpecificPlayer and getSpecificPlayer(indiceJogador) or nil
        if jogador then
            local quadradoJogador = jogador:getSquare()
            if quadradoJogador then
                local coordenadaX, coordenadaY, coordenadaZ = quadradoJogador:getX(), quadradoJogador:getY(), quadradoJogador:getZ()
                local niveisZ = { coordenadaZ }
                if coordenadaZ ~= 0 then niveisZ[#niveisZ + 1] = 0 end

                for _, zPesquisa in ipairs(niveisZ) do
                    for deslocamentoX = -raio, raio do
                        for deslocamentoY = -raio, raio do
                            local quadrado = celula:getGridSquare(coordenadaX + deslocamentoX, coordenadaY + deslocamentoY, zPesquisa)
                            if quadrado then
                                local objetos = quadrado:getObjects()
                                if objetos then
                                    for indiceObjeto = 0, objetos:size() - 1 do
                                        local objeto = objetos:get(indiceObjeto)
                                        if objeto and instanceof(objeto, "IsoGenerator") then
                                            AdicionarGeradorCarregado(resultado, vistos, objeto)
                                            break
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

-- ============================================================================
-- APLICAÇÃO E REMOÇÃO DE FONTES DE CALOR (ISOHEATSOURCE)
-- ============================================================================

--- Cria os objetos físicos IsoHeatSource nas posições radiantes associadas ao gerador.
--- @param gerador any O gerador físico.
--- @return boolean Retorna true se as fontes de calor foram aplicadas com sucesso.
function LKS_EletricidadeConstrucao_HeatingClient.Apply(gerador)
    if not gerador then return false end
    if not IsSistemaAtivo() then return false end
    if isServer() and not isClient() then return false end

    local quadrado = gerador:getSquare()
    if not quadrado then return false end
    local chaveGerador = quadrado:getX() .. "_" .. quadrado:getY() .. "_" .. quadrado:getZ()

    local dadosMod = gerador:getModData()
    local posicoes = dadosMod.HeatingPositions
    if not posicoes or type(posicoes) ~= "table" then return false end
    
    -- Verifica se a tabela possui posições (chaves numéricas Kahlua tratadas como strings)
    local _possuiPosicoes = false
    for _ in pairs(posicoes) do _possuiPosicoes = true; break end
    if not _possuiPosicoes then return false end

    LKS_EletricidadeConstrucao_HeatingClient.Remove(chaveGerador)

    local celula = getCell()
    if not celula then return false end

    local temperaturaReal = (dadosMod.HeatingTargetTemp or TEMPERATURA_PADRAO) + DESLOCAMENTO_TEMPERATURA
    local raio            = ObterRaio()
    local fontes          = {}
    local quantidadeFontes = 0

    for _, dadosQuarto in pairs(posicoes) do
        if dadosQuarto.positions then
            for _, posicao in pairs(dadosQuarto.positions) do
                local sucesso, fonteCalor = pcall(function()
                    local fonte = IsoHeatSource.new(posicao.x, posicao.y, posicao.z, raio, temperaturaReal)
                    fonte:setTemperature(temperaturaReal)
                    fonte:setRadius(raio)
                    celula:addHeatSource(fonte)
                    return fonte
                end)
                if sucesso and fonteCalor then
                    table.insert(fontes, {source = fonteCalor, x = posicao.x, y = posicao.y, z = posicao.z})
                    quantidadeFontes = quantidadeFontes + 1
                end
            end
        end
    end

    _fontesAtivas[chaveGerador] = fontes

    LKS_EletricidadeConstrucao.Print(string.format(
        "[Heating] Aplicadas %d fontes de calor (alvo: %dC) para o gerador %s",
        quantidadeFontes, dadosMod.HeatingTargetTemp or TEMPERATURA_PADRAO, chaveGerador))

    return true
end

--- Remove todas as fontes de calor IsoHeatSource ativas vinculadas ao gerador.
--- @param chaveGerador string A chave identificadora do gerador.
function LKS_EletricidadeConstrucao_HeatingClient.Remove(chaveGerador)
    if not chaveGerador then return end
    local fontes = _fontesAtivas[chaveGerador]
    if not fontes then return end

    local celula = getCell()
    if celula then
        for _, dadosFonte in ipairs(fontes) do
            pcall(function() celula:removeHeatSource(dadosFonte.source) end)
        end
    end

    _fontesAtivas[chaveGerador] = nil
end

--- Retorna true se houver fontes de calor radiante ativas para a chave do gerador.
--- @param chaveGerador string A chave do gerador.
--- @return boolean Status de atividade.
function LKS_EletricidadeConstrucao_HeatingClient.IsActive(chaveGerador)
    return _fontesAtivas[chaveGerador] ~= nil and #_fontesAtivas[chaveGerador] > 0
end

--- Remove TODAS as fontes de calor ativas do mapa e limpa o rastreador.
function LKS_EletricidadeConstrucao_HeatingClient.ClearAll()
    local celula = getCell()
    for chave, fontes in pairs(_fontesAtivas) do
        if celula then
            for _, dadosFonte in ipairs(fontes) do
                pcall(function() celula:removeHeatSource(dadosFonte.source) end)
            end
        end
        _fontesAtivas[chave] = nil
    end
    LKS_EletricidadeConstrucao.Print("[Heating] ClearAll: todas as fontes de calor ativas foram removidas.")
end

-- ============================================================================
-- RASTREAMENTO E MAPEAMENTO DE GERADORES
-- ============================================================================

--- Varre e retorna a lista de todos os geradores físicos relevantes carregados no cliente.
--- @return table Lista de geradores carregados.
local function ObterTodosGeradoresCarregados()
    local resultado = {}
    local vistos   = {}
    local celula   = getCell()
    if not celula then return resultado end

    local gerenciadorEstado = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local construcoes = gerenciadorEstado and gerenciadorEstado.GetAllBuildings and gerenciadorEstado.GetAllBuildings() or nil

    -- 1. Varre geradores conhecidos através do banco de dados elétrico do StateManager
    for _, dadosConstrucao in pairs(construcoes or {}) do
        if dadosConstrucao.connectedGenerators then
            for _, chaveGerador in pairs(dadosConstrucao.connectedGenerators) do
                local coordenadaX, coordenadaY, coordenadaZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                if coordenadaX then
                    AdicionarGeradorCarregado(resultado, vistos, LocalizarGeradorCarregadoEm(tonumber(coordenadaX), tonumber(coordenadaY), tonumber(coordenadaZ)))
                end
            end
        end
    end

    -- 2. Mantém geradores com janelas abertas ou fontes já ativas mesmo sob boots lentos de sincronização multiplayer
    ColetarGeradoresFontesAtivas(resultado, vistos)
    ColetarGeradoresDasJanelas(resultado, vistos)

    -- 3. Caso limite: varredura direta no mundo ao redor de jogadores locais
    if #resultado == 0 then
        ColetarGeradoresProximosAoJogador(resultado, vistos, 25)
    end

    return resultado
end

-- ============================================================================
-- LOOP DE PROCESSAMENTO (TICK)
-- ============================================================================

--- Avalia e sincroniza o estado elétrico de ativação física com a emissão de calor.
local function AtualizarTodos()
    if not IsSistemaAtivo() then
        for chave in pairs(_fontesAtivas) do
            LKS_EletricidadeConstrucao_HeatingClient.Remove(chave)
        end
        return
    end

    local geradores = ObterTodosGeradoresCarregados()

    -- Monta a lista de geradores atualmente vinculados para rastrear desvinculações ou destruições
    local chavesConectadas = {}
    for _, gerador in ipairs(geradores) do
        local quadrado = gerador:getSquare()
        if quadrado then
            chavesConectadas[quadrado:getX() .. "_" .. quadrado:getY() .. "_" .. quadrado:getZ()] = true
        end
    end

    -- Remove fontes de geradores destruídos ou desconectados
    for chave in pairs(_fontesAtivas) do
        if not chavesConectadas[chave] then
            LKS_EletricidadeConstrucao_HeatingClient.Remove(chave)
        end
    end

    -- Atualiza ou remove fontes baseando-se no estado de ativação
    for _, gerador in ipairs(geradores) do
        local quadrado = gerador:getSquare()
        if quadrado then
            local chave = quadrado:getX() .. "_" .. quadrado:getY() .. "_" .. quadrado:getZ()
            local dadosMod  = gerador:getModData()

            -- Configura o valor padrão explícito HeatingEnabled=false no primeiro boot do gerador
            local _possuiPosicoesParaAutoAtivacao = false
            if dadosMod.HeatingPositions and type(dadosMod.HeatingPositions) == "table" then
                for _ in pairs(dadosMod.HeatingPositions) do _possuiPosicoesParaAutoAtivacao = true; break end
            end
            
            if dadosMod.HeatingEnabled == nil and _possuiPosicoesParaAutoAtivacao then
                dadosMod.HeatingEnabled = false
                if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
                    gerador:transmitModData()
                end
            end

            local _possuiPosicoes = false
            if dadosMod.HeatingPositions and type(dadosMod.HeatingPositions) == "table" then
                for _ in pairs(dadosMod.HeatingPositions) do _possuiPosicoes = true; break end
            end
            
            local desejaAquecimento = gerador:isActivated()
                and (dadosMod.HeatingEnabled == true)
                and _possuiPosicoes

            if desejaAquecimento then
                if not LKS_EletricidadeConstrucao_HeatingClient.IsActive(chave) then
                    LKS_EletricidadeConstrucao_HeatingClient.Apply(gerador)
                end
            else
                if LKS_EletricidadeConstrucao_HeatingClient.IsActive(chave) then
                    LKS_EletricidadeConstrucao_HeatingClient.Remove(chave)
                end
            end
        end
    end
end

-- ============================================================================
-- LOOP DE ATUALIZAÇÃO DE TEMPERATURAS (A CADA 10 MINUTOS)
-- ============================================================================

--- Recria preventivamente as fontes ativas no mapa para atualização do calor climático.
local function AtualizarTemperaturas()
    local celula = getCell()
    if not celula then return end

    for chave in pairs(_fontesAtivas) do
        local coordenadaX, coordenadaY, coordenadaZ = string.match(chave, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if coordenadaX then
            local quadrado = celula:getGridSquare(tonumber(coordenadaX), tonumber(coordenadaY), tonumber(coordenadaZ))
            if quadrado then
                local objetos = quadrado:getObjects()
                for indiceObjeto = 0, objetos:size() - 1 do
                    local objeto = objetos:get(indiceObjeto)
                    if objeto and instanceof(objeto, "IsoGenerator") then
                        LKS_EletricidadeConstrucao_HeatingClient.Remove(chave)
                        LKS_EletricidadeConstrucao_HeatingClient.Apply(objeto)
                        break
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- INSCRIÇÃO DE EVENTOS DE TICK DO JOGO
-- ============================================================================

local _contadorTicks        = 0
local _contadorAtualizacao  = 0

Events.OnTick.Add(function()
    _contadorTicks       = _contadorTicks       + 1
    _contadorAtualizacao = _contadorAtualizacao + 1

    -- Atualiza geradores físicos carregados a cada ~10 segundos (600 ticks)
    if _contadorTicks >= 600 then
        _contadorTicks = 0
        AtualizarTodos()
    end

    -- Atualiza o gradiente de calor radiante a cada ~10 minutos (36000 ticks)
    if _contadorAtualizacao >= 36000 then
        _contadorAtualizacao = 0
        AtualizarTemperaturas()
    end
end)

LKS_EletricidadeConstrucao.RegisterModule("Heating.Client", "2.0.0")

print("[LKS_EletricidadeConstrucao_Heating_Client] Módulo de aquecimento do cliente carregado com sucesso.")
