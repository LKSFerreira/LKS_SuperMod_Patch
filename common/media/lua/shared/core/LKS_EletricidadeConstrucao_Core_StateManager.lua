---@diagnostic disable: undefined-global
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

-- ARQUIVO: LKS_EletricidadeConstrucao_Core_StateManager.lua
-- OBJETIVO: Gerenciador de estado centralizado e persistência de dados via ModData.
-- Versão: 2.0.0-alpha
-- Data: 15 de Junho de 2026

-- Garante que o namespace principal exista
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Core_StateManager] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- ============================================================================
-- CHAVES DO MODDATA
-- ============================================================================

local CHAVE_MODDATA = "LKS_EletricidadeConstrucaoV2"
local CHAVE_MODDATA_BACKUP = "LKS_EletricidadeConstrucaoV2_Backup"
local CHAVE_MODDATA_INDICE_GERADORES = "LKS_EletricidadeConstrucaoV2_GeneratorIndex"

-- ============================================================================
-- AUXILIARES DE ANÁLISE DE SALVAMENTO
-- ============================================================================

--- Normaliza o identificador do mundo removendo nulos ou vazios técnicos.
--- @param valor any O valor bruto do identificador.
--- @return string|nil O identificador normalizado ou nil.
local function NormalizarIdentificadorMundo(valor)
    if valor == nil then return nil end

    valor = tostring(valor)
    if valor == "" or valor == "nil" then
        return nil
    end

    return valor
end

--- Obtém o identificador exclusivo do mundo atual (save slot).
---
--- Esta verificação previne a contaminação cruzada de estado entre diferentes
--- arquivos de salvamento quando o jogador transita entre mundos na mesma sessão de jogo.
---
--- @return string Retorna o identificador do mundo ou "unknown" se chamado muito cedo.
local function ObterIdentificadorMundo()
    local mundo = getWorld and getWorld()
    if mundo then
        if mundo.getWorldName then
            local nomeMundo = NormalizarIdentificadorMundo(mundo:getWorldName())
            if nomeMundo then return nomeMundo end
        end
        if mundo.getDir then
            local diretorioMundo = NormalizarIdentificadorMundo(mundo:getDir())
            if diretorioMundo then return diretorioMundo end
        end
    end

    -- Servidores dedicados podem expor a pasta do slot ativo por getServerName
    if getServerName then
        local nomeServidor = NormalizarIdentificadorMundo(getServerName())
        if nomeServidor then return nomeServidor end
    end

    -- GameTime e outras estruturas ficam disponíveis antes do World, mas não servem
    -- como identificador de salvamento único.
    return "unknown"
end

-- Rastreia o ciclo de vida do carregamento de dados globais nesta sessão.
--   "pending"  -> Initialize() executado mas GlobalModData não foi lido (Mundo ainda desconhecido).
--   "loaded"   -> ConfirmAndLoadState() carregou dados validados pelo mundo ativo.
--   "fresh"    -> ConfirmAndLoadState() detectou incompatibilidade de mundo e resetou os dados.
-- O salvamento é protegido contra escrita enquanto estiver em "pending" para evitar sobrescrever
-- dados saudáveis com um snapshot vazio.
local _estadoCarregamentoDados = "pending"

-- Variável legada mantida para compatibilidade com a assinatura do carregador antigo.
local _carregadoComIdentificadorMundoDesconhecido = false

-- ============================================================================
-- ESTADO LOCAL
-- ============================================================================

local _estado = nil                  -- Estado ativo em tempo de execução
local _estaModificado = false        -- Sinaliza que há alterações que precisam de salvamento
local _inicializado = false          -- Indica se o módulo foi inicializado
local _cacheIndiceGeradores = nil    -- Referência em cache para o índice ModData de geradores

-- ============================================================================
-- UTILITÁRIOS INTERNOS
-- ============================================================================

--- Obtém ou cria a tabela de índice de geradores no ModData global do jogo.
--- @return table O índice de geradores e chaves de chunk.
local function ObterIndiceGeradores()
    if not _cacheIndiceGeradores then
        _cacheIndiceGeradores = ModData.getOrCreate(CHAVE_MODDATA_INDICE_GERADORES)
    end

    _cacheIndiceGeradores.generators = _cacheIndiceGeradores.generators or {}
    _cacheIndiceGeradores.chunkIndex = _cacheIndiceGeradores.chunkIndex or {}

    return _cacheIndiceGeradores
end

--- Conta a quantidade de geradores presentes no estado ativo.
--- @return integer A quantidade de geradores.
local function ContarGeradores()
    if not _estado or not _estado.generators then return 0 end
    local contagem = 0
    for _ in pairs(_estado.generators) do
        contagem = contagem + 1
    end
    return contagem
end

--- Conta a quantidade de construções registradas no estado ativo.
--- @return integer A quantidade de construções.
local function ContarConstrucoes()
    if not _estado or not _estado.buildings then return 0 end
    local contagem = 0
    for _ in pairs(_estado.buildings) do
        contagem = contagem + 1
    end
    return contagem
end

--- Adiciona um gerador ao índice do ModData para carregamento rápido e buscas por chunk.
--- @param dadosGerador table Os dados estruturados do gerador.
local function AdicionarGeradorAoIndice(dadosGerador)
    if not dadosGerador or not dadosGerador.id then return end
    
    local Geometria = LKS_EletricidadeConstrucao.Utils and LKS_EletricidadeConstrucao.Utils.Geometry
    if (not dadosGerador.chunkKey or dadosGerador.chunkKey == "") and Geometria then
        dadosGerador.chunkKey = Geometria.GetChunkKey(dadosGerador.x, dadosGerador.y)
    end

    local indice = ObterIndiceGeradores()
    indice.generators[dadosGerador.id] = LKS_EletricidadeConstrucao.Data.Generator.Serialize(dadosGerador)

    if dadosGerador.chunkKey then
        indice.chunkIndex[dadosGerador.chunkKey] = indice.chunkIndex[dadosGerador.chunkKey] or {}
        local lista = indice.chunkIndex[dadosGerador.chunkKey]
        local existe = false
        for _, identificadorGerador in ipairs(lista) do
            if identificadorGerador == dadosGerador.id then 
                existe = true
                break 
            end
        end
        if not existe then
            table.insert(lista, dadosGerador.id)
        end
    end
end

--- Remove um gerador das tabelas de índice do ModData.
--- @param identificadorGerador string O identificador único do gerador.
--- @param chaveChunk string A chave de chunk associada (opcional).
local function RemoverGeradorDoIndice(identificadorGerador, chaveChunk)
    if not identificadorGerador then return end
    
    local indice = ObterIndiceGeradores()
    indice.generators[identificadorGerador] = nil

    if chaveChunk and indice.chunkIndex[chaveChunk] then
        local lista = indice.chunkIndex[chaveChunk]
        for indiceLoop = #lista, 1, -1 do
            if lista[indiceLoop] == identificadorGerador then
                table.remove(lista, indiceLoop)
            end
        end
        if #lista == 0 then
            indice.chunkIndex[chaveChunk] = nil
        end
    end
end

--- Tenta reconstruir a lista de geradores no estado baseado no índice do ModData.
--- @return integer A quantidade de geradores recuperados.
local function HidratarGeradoresDoIndice()
    local indice = ModData.get(CHAVE_MODDATA_INDICE_GERADORES)
    if not indice or not indice.generators then
        return 0
    end

    if not _estado then
        _estado = LKS_EletricidadeConstrucao.Data.State.New()
    end

    local geradoresRestaurados = 0
    for identificadorGerador, dadosSerializados in pairs(indice.generators) do
        local dadosGerador = LKS_EletricidadeConstrucao.Data.Generator.Deserialize(dadosSerializados)
        if dadosGerador then
            LKS_EletricidadeConstrucao.Data.State.AddGenerator(_estado, dadosGerador)
            geradoresRestaurados = geradoresRestaurados + 1
        end
    end

    if geradoresRestaurados > 0 then
        _estaModificado = true
        LKS_EletricidadeConstrucao.Print(string.format(
            "[StateManager] Restaurados %d gerador(es) a partir do índice de ModData", 
            geradoresRestaurados))
    end

    return geradoresRestaurados
end

-- ============================================================================
-- PURGA DE PRÉDIOS E CONSTRUÇÕES DUPLICADAS
-- ============================================================================

--- Varre e expurga registros obsoletos de construções duplicadas que compartilham coordenadas.
---
--- Esse método resolve resquícios do carregador antigo, agrupando construções por
--- coordenadas físicas e mesclando os geradores e dados elétricos na entidade canônica.
---
--- @return integer A quantidade de construções duplicadas expurgadas.
local function ExpurgarConstrucoesDuplicadas()
    if not _estado then return 0 end
    
    local todasConstrucoes = LKS_EletricidadeConstrucao.Data.State.GetAllBuildings(_estado)
    if not todasConstrucoes then return 0 end

    -- Agrupa IDs de construções pela chave de localização "x_y_z"
    local porLocalizacao = {}  -- chaveLocalizacao -> {canonical = idCanonica, stales = {idObsoleto, ...}}
    for identificadorConstrucao, dadosConstrucao in pairs(todasConstrucoes) do
        local chaveLocalizacao = (dadosConstrucao.x or 0) .. "_" .. (dadosConstrucao.y or 0) .. "_" .. (dadosConstrucao.z or 0)
        if not porLocalizacao[chaveLocalizacao] then
            porLocalizacao[chaveLocalizacao] = { canonical = nil, stales = {} }
        end
        -- O ID canônico corresponde ao padrão 'bld_X_Y_Z' (sem o prefixo legando 'def')
        if identificadorConstrucao:match("^bld_%d+_%d+_%d+$") then
            porLocalizacao[chaveLocalizacao].canonical = identificadorConstrucao
        else
            table.insert(porLocalizacao[chaveLocalizacao].stales, identificadorConstrucao)
        end
    end

    local construcoesExpurgadas = 0
    for chaveLocalizacao, entrada in pairs(porLocalizacao) do
        if entrada.canonical and #entrada.stales > 0 then
            local dadosConstrucaoCanonica = todasConstrucoes[entrada.canonical]
            for _, identificadorObsoleto in ipairs(entrada.stales) do
                local dadosConstrucaoObsoleta = todasConstrucoes[identificadorObsoleto]
                if dadosConstrucaoObsoleta then
                    -- Mescla geradores conectados da obsoleta na canônica.
                    -- Nota: Usamos pairs() em vez de ipairs() pois após a desserialização de ModData no Kahlua
                    -- (a máquina virtual Lua do PZ), tabelas numéricas podem ter chaves convertidas para strings.
                    if dadosConstrucaoObsoleta.connectedGenerators then
                        dadosConstrucaoCanonica.connectedGenerators = dadosConstrucaoCanonica.connectedGenerators or {}
                        local conjuntoGeradoresConectados = {}
                        for _, chaveGerador in pairs(dadosConstrucaoCanonica.connectedGenerators) do 
                            conjuntoGeradoresConectados[chaveGerador] = true 
                        end
                        for _, chaveGerador in pairs(dadosConstrucaoObsoleta.connectedGenerators) do
                            if not conjuntoGeradoresConectados[chaveGerador] then
                                table.insert(dadosConstrucaoCanonica.connectedGenerators, chaveGerador)
                                conjuntoGeradoresConectados[chaveGerador] = true
                            end
                        end
                    end
                    -- Mescla dados de aquecimento caso a canônica esteja zerada
                    if (not dadosConstrucaoCanonica.heatingSourceCount or dadosConstrucaoCanonica.heatingSourceCount == 0)
                        and dadosConstrucaoObsoleta.heatingSourceCount and dadosConstrucaoObsoleta.heatingSourceCount > 0 then
                        dadosConstrucaoCanonica.heatingEnabled      = dadosConstrucaoObsoleta.heatingEnabled
                        dadosConstrucaoCanonica.heatingSourceCount  = dadosConstrucaoObsoleta.heatingSourceCount
                        dadosConstrucaoCanonica.heatingTargetTemp   = dadosConstrucaoObsoleta.heatingTargetTemp
                    end
                end
                
                -- Atualiza a referência em todos os geradores associados de obsoleto para canônico
                local todosGeradores = LKS_EletricidadeConstrucao.Data.State.GetAllGenerators(_estado)
                if todosGeradores then
                    for _, dadosGerador in pairs(todosGeradores) do
                        if dadosGerador.connectedBuildings then
                            local precisaReconstruir = false
                            for _, identificadorConstrucao in pairs(dadosGerador.connectedBuildings) do
                                if identificadorConstrucao == identificadorObsoleto then 
                                    precisaReconstruir = true
                                    break 
                                end
                            end
                            if precisaReconstruir then
                                local vistos = {}
                                local reconstruidos = {}
                                for _, identificadorConstrucao in pairs(dadosGerador.connectedBuildings) do
                                    local identificadorEfetivo = (identificadorConstrucao == identificadorObsoleto) and entrada.canonical or identificadorConstrucao
                                    if not vistos[identificadorEfetivo] then
                                        vistos[identificadorEfetivo] = true
                                        table.insert(reconstruidos, identificadorEfetivo)
                                        if identificadorConstrucao == identificadorObsoleto then
                                            LKS_EletricidadeConstrucao.Print(string.format(
                                                "[StateManager.Purge] gen=%s connectedBuildings: %s -> %s",
                                                dadosGerador.id or "?", identificadorObsoleto, entrada.canonical))
                                        end
                                    end
                                end
                                dadosGerador.connectedBuildings = reconstruidos
                                
                                -- Atualiza o metadado Gen_BuildingPoolID diretamente no objeto físico Java/nativo
                                -- para que a interface de informações (UI) exiba a piscina correta.
                                if dadosGerador.x and dadosGerador.y and dadosGerador.z then
                                    local celula = getCell and getCell()
                                    if celula then
                                        local quadrado = celula:getGridSquare(dadosGerador.x, dadosGerador.y, dadosGerador.z)
                                        if quadrado then
                                            local objetos = quadrado:getObjects()
                                            for indiceObjeto = 0, objetos:size() - 1 do
                                                local objeto = objetos:get(indiceObjeto)
                                                if objeto and instanceof(objeto, "IsoGenerator") then
                                                    local dadosMod = objeto:getModData()
                                                    if dadosMod then
                                                        dadosMod.Gen_BuildingPoolID = entrada.canonical
                                                        if objeto.transmitModData then
                                                            objeto:transmitModData()
                                                        end
                                                        LKS_EletricidadeConstrucao.Print(string.format(
                                                            "[StateManager.Purge] Objeto IsoObject gen=%s Gen_BuildingPoolID -> %s",
                                                            dadosGerador.id or "?", entrada.canonical))
                                                    end
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
                
                -- Remove a construção obsoleta do estado
                LKS_EletricidadeConstrucao.Data.State.RemoveBuilding(_estado, identificadorObsoleto)
                LKS_EletricidadeConstrucao.Print(string.format(
                    "[StateManager.Purge] Removida construção duplicada obsoleta %s (duplicada de %s em %s)",
                    identificadorObsoleto, entrada.canonical, chaveLocalizacao))
                construcoesExpurgadas = construcoesExpurgadas + 1
            end
        end
    end

    if construcoesExpurgadas > 0 then
        _estaModificado = true
    end
    return construcoesExpurgadas
end

-- ============================================================================
-- MÉTODOS PÚBLICOS DO GERENCIADOR DE ESTADO
-- ============================================================================

--- Inicializa a infraestrutura básica do gerenciador de estado.
--- @return boolean Retorna true se inicializado com sucesso.
function LKS_EletricidadeConstrucao.Core.StateManager.Initialize()
    if _inicializado then
        LKS_EletricidadeConstrucao.Warn("[StateManager.Initialize] Gerenciador de estado ja inicializado anteriormente")
        return true
    end

    -- Cria o contêiner vazio. O carregamento dos dados reais é diferido até o mundo estar pronto.
    _estado = LKS_EletricidadeConstrucao.Data.State.New()
    _estaModificado = false
    _inicializado = true
    _estadoCarregamentoDados = "pending"

    LKS_EletricidadeConstrucao.Print("[StateManager.Initialize] Gerenciador pronto (aguardando confirmacao do mundo)")
    return true
end

--- Verifica se o gerenciador de estado foi devidamente inicializado.
--- @return boolean Retorna true se estiver inicializado.
function LKS_EletricidadeConstrucao.Core.StateManager.IsInitialized()
    return _inicializado
end

--- Expõe o identificador único do mundo atual para outros submódulos.
--- @return string O identificador ou "unknown".
function LKS_EletricidadeConstrucao.Core.StateManager.GetCurrentWorldId()
    return ObterIdentificadorMundo()
end

--- Carrega os dados persistidos no ModData do jogo.
--- @return boolean Retorna true se os dados foram desserializados com sucesso.
function LKS_EletricidadeConstrucao.Core.StateManager.Load()
    local Contexto = LKS_EletricidadeConstrucao.Core.Runtime
    
    -- Clientes em servidores multiplayer não leem o ModData físico diretamente
    if Contexto.IsMultiplayerClient and Contexto.IsMultiplayerClient() then
        LKS_EletricidadeConstrucao.Warn("[StateManager.Load] Clientes de servidores Multiplayer nao carregam diretamente do ModData, aguardando sincronizacao da rede")
        return false
    end

    local dadosMod = ModData.getOrCreate(CHAVE_MODDATA)

    -- Verifica isolamento de mundo para prevenir quebras se o jogador alternar salvamentos na mesma sessão
    local identificadorMundoAtual = ObterIdentificadorMundo()
    local identificadorMundoArmazenado = dadosMod.worldId
    
    if identificadorMundoAtual == "unknown" then
        _carregadoComIdentificadorMundoDesconhecido = true
        LKS_EletricidadeConstrucao.Print("[StateManager.Load] Identificador de mundo indisponivel (boot inicial) - pulando validacao de isolamento")
    elseif identificadorMundoArmazenado and identificadorMundoArmazenado ~= identificadorMundoAtual then
        LKS_EletricidadeConstrucao.Warn(string.format(
            "[StateManager.Load] Detectada inconsistência de mundo (salvo=%s, atual=%s) - limpando dados anteriores para este save",
            tostring(identificadorMundoArmazenado), tostring(identificadorMundoAtual)))
        dadosMod.state = nil
        dadosMod.worldId = identificadorMundoAtual
        
        -- Limpa índice de geradores para evitar problemas de links órfãos
        local indice = ModData.getOrCreate(CHAVE_MODDATA_INDICE_GERADORES)
        indice.generators = {}
        indice.chunkIndex = {}
        _carregadoComIdentificadorMundoDesconhecido = false
        return false
    else
        _carregadoComIdentificadorMundoDesconhecido = false
    end
    
    if not dadosMod or not dadosMod.state then
        -- Em caso de corrupção ou falha do salvamento nativo do PZ, tenta restaurar
        -- a partir do backup auxiliar gravado previamente.
        local dadosBackup = ModData.get(CHAVE_MODDATA_BACKUP)
        if dadosBackup and dadosBackup.state then
            LKS_EletricidadeConstrucao.Warn("[StateManager.Load] Estado principal ausente - tentando recuperar atraves do backup")
            local dadosBackupDesserializados = LKS_EletricidadeConstrucao.Data.State.Deserialize(dadosBackup.state)
            if dadosBackupDesserializados then
                _estado = dadosBackupDesserializados
                if identificadorMundoAtual ~= "unknown" then
                    dadosMod.worldId = identificadorMundoAtual
                end
                _estaModificado = true
                LKS_EletricidadeConstrucao.Warn("[StateManager.Load] Estado restaurado do backup com sucesso")
                return true
            end
            LKS_EletricidadeConstrucao.Warn("[StateManager.Load] Falha ao desserializar dados do backup")
        end
        LKS_EletricidadeConstrucao.Print("[StateManager.Load] Nenhum salvamento anterior localizado")
        return false
    end
    
    -- Desserializa o estado persistido
    local desserializado = LKS_EletricidadeConstrucao.Data.State.Deserialize(dadosMod.state)
    if not desserializado then
        LKS_EletricidadeConstrucao.Error("[StateManager.Load] Falha ao desserializar dados do estado principal")
        
        -- Segunda tentativa via backup
        local dadosBackup = ModData.get(CHAVE_MODDATA_BACKUP)
        if dadosBackup and dadosBackup.state then
            LKS_EletricidadeConstrucao.Warn("[StateManager.Load] Tentando restaurar a partir do backup")
            desserializado = LKS_EletricidadeConstrucao.Data.State.Deserialize(dadosBackup.state)
        end
        
        if not desserializado then
            return false
        end
    end
    
    _estado = desserializado
    if identificadorMundoAtual ~= "unknown" then
        dadosMod.worldId = identificadorMundoAtual
    end
    _estaModificado = false
    
    LKS_EletricidadeConstrucao.Print("[StateManager.Load] Estado carregado com sucesso")
    return true
end

--- Valida o identificador do mundo e dispara a desserialização definitiva de dados.
---
--- Deve ser chamado a partir dos eventos OnInitWorld ou OnGameStart quando a API do PZ está pronta.
--- @return boolean Retorna true se o carregamento foi efetuado com sucesso nesta chamada.
function LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState()
    if _estadoCarregamentoDados ~= "pending" then return false end

    local identificadorMundoAtual = ObterIdentificadorMundo()
    if identificadorMundoAtual == "unknown" then
        LKS_EletricidadeConstrucao.Debug("[StateManager.ConfirmAndLoadState] Mundo indisponivel no momento, diferindo carregamento")
        return false
    end

    LKS_EletricidadeConstrucao.Print("[StateManager.ConfirmAndLoadState] Confirmado mundo: " .. identificadorMundoAtual)

    local carregado = LKS_EletricidadeConstrucao.Core.StateManager.Load()
    if not carregado then
        LKS_EletricidadeConstrucao.Print("[StateManager.ConfirmAndLoadState] Iniciando novo estado limpo para este salvamento")
        _estado = LKS_EletricidadeConstrucao.Data.State.New()
        _estaModificado = true
        _estadoCarregamentoDados = "fresh"
    else
        -- Hidrata os geradores a partir do índice persistido caso o estado estivesse vazio
        if ContarGeradores() == 0 then
            local geradoresRestaurados = HidratarGeradoresDoIndice()
            if geradoresRestaurados > 0 then
                LKS_EletricidadeConstrucao.Print(string.format(
                    "[StateManager.ConfirmAndLoadState] Recuperados %d geradores a partir do índice ModData", 
                    geradoresRestaurados))
            end
        end
        _estadoCarregamentoDados = "loaded"
    end

    LKS_EletricidadeConstrucao.Print(string.format(
        "[StateManager.ConfirmAndLoadState] Finalizado: %d gerador(es), %d construções, estado=%s",
        ContarGeradores(), ContarConstrucoes(), _estadoCarregamentoDados))
    LKS_EletricidadeConstrucao.Debug("[StateManager] " .. LKS_EletricidadeConstrucao.Data.State.GetSummary(_estado))

    -- Aciona a atualização em massa preventiva dos geradores salvos no mapa
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.ChunkTracker
            and LKS_EletricidadeConstrucao.Fuel.ChunkTracker.HandleStartupGeneratorRefresh then
        LKS_EletricidadeConstrucao.Fuel.ChunkTracker.HandleStartupGeneratorRefresh()
    end

    return true
end

--- Atalho legado mantido para compatibilidade com outros arquivos do patch.
function LKS_EletricidadeConstrucao.Core.StateManager.ReloadIfWorldWasUnknown()
    return LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState()
end

--- Verifica se o estado já foi lido e verificado para este mundo de jogo.
--- @return boolean Retorna true se o carregamento definitivo foi concluído.
function LKS_EletricidadeConstrucao.Core.StateManager.IsStateLoaded()
    return _estadoCarregamentoDados ~= "pending"
end

--- Persiste o estado ativo de volta nas tabelas de ModData do Project Zomboid.
--- @param forcar boolean Se true, força a escrita mesmo se nenhuma alteração tiver sido registrada.
--- @param criarBackup boolean Se true, cria um snapshot de backup antes de sobrescrever (padrão: true).
--- @return boolean Retorna true se o salvamento foi gravado com sucesso.
function LKS_EletricidadeConstrucao.Core.StateManager.Save(forcar, criarBackup)
    local Contexto = LKS_EletricidadeConstrucao.Core.Runtime
    
    if not _inicializado then
        LKS_EletricidadeConstrucao.Error("[StateManager.Save] Gerenciador de estado nao inicializado")
        return false
    end

    -- Impede salvamentos acidentais enquanto o mundo não for confirmado
    if _estadoCarregamentoDados == "pending" then
        LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState()
    end
    if _estadoCarregamentoDados == "pending" then
        LKS_EletricidadeConstrucao.Warn("[StateManager.Save] Validacao do mundo pendente - gravacao cancelada para evitar perda de dados")
        return false
    end

    if not _estaModificado and not forcar then
        LKS_EletricidadeConstrucao.Debug("[StateManager.Save] Estado limpo, pulando gravacao")
        return true
    end
    
    -- Apenas o servidor ou sessões Singleplayer podem escrever dados persistentes globais
    if not Contexto.IsServer() and not Contexto.IsSingleplayer() then
        LKS_EletricidadeConstrucao.Warn("[StateManager.Save] Apenas o servidor de jogo pode gravar alteracoes globais")
        return false
    end
    
    if not _estado then
        LKS_EletricidadeConstrucao.Error("[StateManager.Save] Nenhum estado valido disponivel para gravacao")
        return false
    end
    
    -- Atualiza as estatísticas acumuladas antes de persistir
    LKS_EletricidadeConstrucao.Data.State.UpdateStatistics(_estado)
    
    -- Serializa a estrutura para gravação
    local serializado = LKS_EletricidadeConstrucao.Data.State.Serialize(_estado)
    
    -- Gerenciamento de backups rápidos
    if criarBackup == nil then criarBackup = true end
    if criarBackup then
        local dadosModAtuais = ModData.get(CHAVE_MODDATA)
        if dadosModAtuais and dadosModAtuais.state then
            local dadosBackup = ModData.getOrCreate(CHAVE_MODDATA_BACKUP)
            dadosBackup.state = dadosModAtuais.state
        end
    end
    
    -- Gravação física no ModData global
    local dadosMod = ModData.getOrCreate(CHAVE_MODDATA)
    dadosMod.state = serializado
    
    local identificadorMundo = ObterIdentificadorMundo()
    if identificadorMundo ~= "unknown" then
        dadosMod.worldId = identificadorMundo
    end

    _estaModificado = false
    LKS_EletricidadeConstrucao.Debug("[StateManager.Save] Estado salvo com sucesso" .. (criarBackup and " (com backup)" or " (sem backup)"))
    return true
end

--- Sinaliza que o estado sofreu alterações e precisa ser persistido na próxima oportunidade.
function LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    _estaModificado = true
end

--- Verifica se o estado de tempo de execução possui dados pendentes de salvamento.
--- @return boolean Retorna true se houver alterações não salvas.
function LKS_EletricidadeConstrucao.Core.StateManager.IsDirty()
    return _estaModificado
end

-- ============================================================================
-- LEITURA E CONFIGURAÇÕES
-- ============================================================================

--- Retorna a tabela do estado ativo.
--- @return table|nil O estado de simulação ativo ou nil.
function LKS_EletricidadeConstrucao.Core.StateManager.GetState()
    if not _inicializado then
        LKS_EletricidadeConstrucao.Error("[StateManager.GetState] Gerenciador de estado nao inicializado")
        return nil
    end
    return _estado
end

--- Retorna a tabela de parâmetros de configuração do estado ativo.
--- @return table Tabela de parâmetros e preferências sandbox.
function LKS_EletricidadeConstrucao.Core.StateManager.GetConfig()
    if not _estado then
        return {}
    end
    return _estado.config
end

--- Atualiza as preferências sandbox armazenadas no estado ativo.
--- @param configuracao table Nova tabela de parâmetros sandbox.
function LKS_EletricidadeConstrucao.Core.StateManager.SetConfig(configuracao)
    if not _estado then
        LKS_EletricidadeConstrucao.Error("[StateManager.SetConfig] Nenhum estado ativo para configuracao")
        return
    end
    _estado.config = configuracao
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
end

-- ============================================================================
-- OPERAÇÕES DE GERADORES
-- ============================================================================

--- Registra ou atualiza um gerador nas tabelas de simulação de rede e nos índices de busca.
--- @param dadosGerador table Os dados estruturados do gerador.
function LKS_EletricidadeConstrucao.Core.StateManager.AddGenerator(dadosGerador)
    if not _estado then
        LKS_EletricidadeConstrucao.Error("[StateManager.AddGenerator] Estado ausente")
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.AddGenerator(_estado, dadosGerador)
    AdicionarGeradorAoIndice(dadosGerador)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Debug("[StateManager] Gerador indexado: " .. dadosGerador.id)
end

--- Remove um gerador ativo das tabelas do estado e do índice persistente.
--- @param identificadorGerador string O identificador único do gerador.
--- @return table|nil Retorna os dados do gerador removido, ou nil se não encontrado.
function LKS_EletricidadeConstrucao.Core.StateManager.RemoveGenerator(identificadorGerador)
    if not _estado then
        LKS_EletricidadeConstrucao.Error("[StateManager.RemoveGenerator] Estado ausente")
        return nil
    end
    
    local geradorRemovido = LKS_EletricidadeConstrucao.Data.State.RemoveGenerator(_estado, identificadorGerador)
    if geradorRemovido then
        RemoverGeradorDoIndice(identificadorGerador, geradorRemovido.chunkKey)
        LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
        LKS_EletricidadeConstrucao.Debug("[StateManager] Gerador desvinculado: " .. identificadorGerador)
    end
    
    return geradorRemovido
end

--- Recupera os dados estruturados de um gerador pelo seu identificador.
--- @param identificadorGerador string O ID do gerador.
--- @return table|nil Os dados do gerador ou nil.
function LKS_EletricidadeConstrucao.Core.StateManager.GetGenerator(identificadorGerador)
    if not _estado then
        return nil
    end
    return LKS_EletricidadeConstrucao.Data.State.GetGenerator(_estado, identificadorGerador)
end

--- Retorna o mapa contendo todos os geradores ativos indexados por identificador.
--- @return table Mapa de geradores cadastrados.
function LKS_EletricidadeConstrucao.Core.StateManager.GetAllGenerators()
    if not _estado then
        return {}
    end
    return LKS_EletricidadeConstrucao.Data.State.GetAllGenerators(_estado)
end

--- Retorna a lista contendo apenas os geradores ligados (ativos).
--- @return table Lista contendo dados dos geradores ligados.
function LKS_EletricidadeConstrucao.Core.StateManager.GetActiveGenerators()
    if not _estado then
        return {}
    end
    return LKS_EletricidadeConstrucao.Data.State.GetActiveGenerators(_estado)
end

--- Retorna os geradores cujas coordenadas físicas coincidem com a chave de chunk informada.
--- @param chaveChunk string A coordenada/chave do chunk do mapa.
--- @return table Lista de geradores vinculados ao chunk.
function LKS_EletricidadeConstrucao.Core.StateManager.GetGeneratorsInChunk(chaveChunk)
    if not _estado then
        return {}
    end
    return LKS_EletricidadeConstrucao.Data.State.GetGeneratorsInChunk(_estado, chaveChunk)
end

--- Força a reidratação/restauração dos geradores a partir da tabela de índice do ModData.
--- @return integer A quantidade de geradores recuperados.
function LKS_EletricidadeConstrucao.Core.StateManager.HydrateGeneratorsFromIndex()
    return HidratarGeradoresDoIndice()
end

-- ============================================================================
-- OPERAÇÕES DE CONSTRUÇÕES
-- ============================================================================

--- Registra ou atualiza os limites geométricos de uma construção no estado.
--- @param dadosConstrucao table Os limites e dados de consumo elétrico da construção.
function LKS_EletricidadeConstrucao.Core.StateManager.AddBuilding(dadosConstrucao)
    if not _estado then
        LKS_EletricidadeConstrucao.Error("[StateManager.AddBuilding] Estado ausente")
        return
    end
    
    LKS_EletricidadeConstrucao.Data.State.AddBuilding(_estado, dadosConstrucao)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    
    LKS_EletricidadeConstrucao.Debug("[StateManager] Construcao vinculada: " .. dadosConstrucao.id)
end

--- Remove os registros associados a uma construção do estado global.
--- @param identificadorConstrucao string O identificador único da construção.
--- @return table|nil Os dados da construção removida, ou nil.
function LKS_EletricidadeConstrucao.Core.StateManager.RemoveBuilding(identificadorConstrucao)
    if not _estado then
        LKS_EletricidadeConstrucao.Error("[StateManager.RemoveBuilding] Estado ausente")
        return nil
    end
    
    local geradorRemovido = LKS_EletricidadeConstrucao.Data.State.RemoveBuilding(_estado, identificadorConstrucao)
    if geradorRemovido then
        LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
        LKS_EletricidadeConstrucao.Debug("[StateManager] Construcao desvinculada: " .. identificadorConstrucao)
    end
    
    return geradorRemovido
end

--- Busca uma construção registrada pelo seu identificador único.
--- @param identificadorConstrucao string O ID da construção.
--- @return table|nil Os dados estruturados da construção ou nil.
function LKS_EletricidadeConstrucao.Core.StateManager.GetBuilding(identificadorConstrucao)
    if not _estado then
        return nil
    end
    return LKS_EletricidadeConstrucao.Data.State.GetBuilding(_estado, identificadorConstrucao)
end

--- Retorna todas as construções que estão cadastradas no gerenciador de rede.
--- @return table O mapa contendo todas as construções.
function LKS_EletricidadeConstrucao.Core.StateManager.GetAllBuildings()
    if not _estado then
        return {}
    end
    return LKS_EletricidadeConstrucao.Data.State.GetAllBuildings(_estado)
end

--- Retorna os prédios cujos circuitos elétricos estejam sob o raio de alcance de um gerador.
--- @param identificadorGerador string O ID do gerador ativo.
--- @return table A lista contendo as construções associadas.
function LKS_EletricidadeConstrucao.Core.StateManager.GetGeneratorBuildings(identificadorGerador)
    if not _estado then
        return {}
    end
    return LKS_EletricidadeConstrucao.Data.State.GetGeneratorBuildings(_estado, identificadorGerador)
end

-- ============================================================================
-- ESTATÍSTICAS DO SISTEMA
-- ============================================================================

--- Obtém a tabela de estatísticas históricas persistida no save.
--- @return table Tabela contendo dados consolidados de consumo e uso.
function LKS_EletricidadeConstrucao.Core.StateManager.GetStatistics()
    if not _estado then
        return {}
    end
    return _estado.statistics
end

--- Registra o consumo consolidado de combustível na simulação.
--- @param quantidade number O volume em unidades de combustível.
function LKS_EletricidadeConstrucao.Core.StateManager.RecordFuelConsumption(quantidade)
    if not _estado then return end
    LKS_EletricidadeConstrucao.Data.State.RecordFuelConsumption(_estado, quantidade)
end

--- Acumula o tempo de funcionamento ativo (uptime) nas estatísticas de rede.
--- @param diferencaSegundos number Diferença de tempo físico a acumular.
function LKS_EletricidadeConstrucao.Core.StateManager.UpdateUptime(diferencaSegundos)
    if not _estado then return end
    LKS_EletricidadeConstrucao.Data.State.UpdateUptime(_estado, diferencaSegundos)
end

-- ============================================================================
-- SINCRONIZAÇÃO DE REDE (MULTIPLAYER)
-- ============================================================================

--- Atualiza a marca de tempo indicando conclusão de transmissão total de dados de rede.
function LKS_EletricidadeConstrucao.Core.StateManager.MarkFullSync()
    if not _estado then return end
    LKS_EletricidadeConstrucao.Data.State.MarkFullSync(_estado)
end

--- Atualiza a marca de tempo indicando sincronização delta (incremental) de rede.
function LKS_EletricidadeConstrucao.Core.StateManager.MarkDeltaSync()
    if not _estado then return end
    LKS_EletricidadeConstrucao.Data.State.MarkDeltaSync(_estado)
end

--- Verifica se o intervalo padrão para sincronização total de rede foi atingido.
--- @return boolean Retorna true se for necessário despachar o pacote completo.
function LKS_EletricidadeConstrucao.Core.StateManager.NeedsFullSync()
    if not _estado then return false end
    local Constantes = LKS_EletricidadeConstrucao.Constants
    local intervalo = Constantes.NETWORK.FULL_SYNC_INTERVAL or 60000
    return LKS_EletricidadeConstrucao.Data.State.NeedsFullSync(_estado, intervalo)
end

--- Verifica se o intervalo padrão para sincronização incremental delta foi atingido.
--- @return boolean Retorna true se for necessário despachar alterações de rede.
function LKS_EletricidadeConstrucao.Core.StateManager.NeedsDeltaSync()
    if not _estado then return false end
    local Constantes = LKS_EletricidadeConstrucao.Constants
    local intervalo = Constantes.NETWORK.DELTA_SYNC_INTERVAL or 5000
    return LKS_EletricidadeConstrucao.Data.State.NeedsDeltaSync(_estado, intervalo)
end

-- ============================================================================
-- OPERAÇÕES DE REDEFINIÇÃO E RESET
-- ============================================================================

--- Exclui permanentemente todos os geradores cadastrados.
function LKS_EletricidadeConstrucao.Core.StateManager.ClearGenerators()
    if not _estado then return end
    LKS_EletricidadeConstrucao.Data.State.ClearGenerators(_estado)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    LKS_EletricidadeConstrucao.Print("[StateManager] Registros de geradores limpos permanentemente")
end

--- Exclui permanentemente todas as construções cadastradas.
function LKS_EletricidadeConstrucao.Core.StateManager.ClearBuildings()
    if not _estado then return end
    LKS_EletricidadeConstrucao.Data.State.ClearBuildings(_estado)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    LKS_EletricidadeConstrucao.Print("[StateManager] Registros de construcoes limpos permanentemente")
end

--- Limpa todos os dados de rede cadastrados (Geradores e Construções).
function LKS_EletricidadeConstrucao.Core.StateManager.ClearAll()
    if not _estado then return end
    LKS_EletricidadeConstrucao.Data.State.ClearAll(_estado)
    LKS_EletricidadeConstrucao.Core.StateManager.MarkDirty()
    LKS_EletricidadeConstrucao.Print("[StateManager] Todos os registros eletricos foram removidos")
end

--- Reseta o contêiner de dados em execução de volta aos padrões originais.
function LKS_EletricidadeConstrucao.Core.StateManager.Reset()
    _estado = LKS_EletricidadeConstrucao.Data.State.New()
    _estaModificado = true
    LKS_EletricidadeConstrucao.Print("[StateManager] Estado redefinido com sucesso")
end

-- ============================================================================
-- AUDITORIA E DEBUG
-- ============================================================================

--- Obtém a descrição compacta do volume de dados em execução.
--- @return string O resumo textual.
function LKS_EletricidadeConstrucao.Core.StateManager.GetSummary()
    if not _estado then
        return "StateManager: Módulo não inicializado"
    end
    return LKS_EletricidadeConstrucao.Data.State.GetSummary(_estado)
end

--- Consolida e imprime um log descritivo no console contendo as informações do gerenciador.
function LKS_EletricidadeConstrucao.Core.StateManager.PrintDebugInfo()
    if not _estado then
        LKS_EletricidadeConstrucao.Print("StateManager: Modulo nao inicializado")
        return
    end
    
    LKS_EletricidadeConstrucao.Print("=== LKS_EletricidadeConstrucao State Manager ===")
    LKS_EletricidadeConstrucao.Print("Inicializado: " .. tostring(_inicializado))
    LKS_EletricidadeConstrucao.Print("Modificado (Dirty): " .. tostring(_estaModificado))
    LKS_EletricidadeConstrucao.Print(LKS_EletricidadeConstrucao.Data.State.GetSummary(_estado))
    
    local estatisticas = _estado.statistics
    LKS_EletricidadeConstrucao.Print("  Geradores: " .. estatisticas.totalGenerators .. " (" .. estatisticas.activeGenerators .. " ativos)")
    LKS_EletricidadeConstrucao.Print("  Construcoes: " .. estatisticas.totalBuildings)
    LKS_EletricidadeConstrucao.Print("  Consumidores: " .. estatisticas.totalConsumers .. " (" .. estatisticas.activeConsumers .. " ativos)")
    LKS_EletricidadeConstrucao.Print("  Combustivel Consumido: " .. estatisticas.totalFuelConsumed)
    LKS_EletricidadeConstrucao.Print("  Tempo Ativo (Uptime): " .. string.format("%.1f", estatisticas.uptime / 3600) .. " horas")
end

-- ============================================================================
-- CONCLUSÃO DA INICIALIZAÇÃO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Core.StateManager", "2.0.0")

return LKS_EletricidadeConstrucao.Core.StateManager
