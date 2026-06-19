-- ============================================================================
-- 🌟 LKS SUPERMOD PATCH — CRÉDITOS & AGRADECIMENTOS 🌟
-- ============================================================================
-- 💖 Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- 🛠️ Mod Original: Generator Powered Buildings (ID Workshop: 3597471949)
-- 👤 Autor Original: Beathoven
-- 🌐 Link: https://steamcommunity.com/sharedfiles/filedetails/?id=3597471949
-- 
-- Este mod só é possível graças a todos os modders que vieram antes de mi.
-- Um agradecimento especial ao autor por sua contribuição incrível à comunidade!
-- ============================================================================

-- ARQUIVO: LKS_EletricidadeConstrucao_Core_Logger.lua
-- OBJETIVO: Subsistema de logging categorizado, depuração e medição de desempenho (performance).
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace existe antes de carregar o módulo
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Core_Logger] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- ============================================================================
-- NÍVEIS DE LOG
-- ============================================================================

LKS_EletricidadeConstrucao.Core.Logger.Levels = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4,
    TRACE = 5
}

-- ============================================================================
-- CATEGORIAS DE LOG
-- ============================================================================

LKS_EletricidadeConstrucao.Core.Logger.Categories = {
    CORE = "Core",
    FUEL = "Fuel",
    POWER = "Power",
    BUILDING = "Building",
    NETWORK = "Network",
    UI = "UI",
    HEATING = "Heating",
    API = "API",
    EVENT = "Event",
    PERFORMANCE = "Performance"
}

-- ============================================================================
-- ESTADO LOCAL E CONFIGURAÇÕES
-- ============================================================================

local _nivelGlobal = LKS_EletricidadeConstrucao.Core.Logger.Levels.INFO
local _niveisCategorias = {}             -- Níveis de log por categoria específica
local _categoriasHabilitadas = {}        -- Quais categorias estão ativas para exibição
local _salvarEmArquivo = false           -- Gravar logs em arquivo de texto (funcionalidade futura)
local _exibirCarimboTempo = true         -- Exibir hora/minuto do jogo no cabeçalho do log
local _exibirCategoria = true            -- Exibir categoria do log no cabeçalho

-- Inicializa todas as categorias de log como habilitadas por padrão
for _, categoria in pairs(LKS_EletricidadeConstrucao.Core.Logger.Categories) do
    _categoriasHabilitadas[categoria] = true
end

-- ============================================================================
-- CONFIGURAÇÕES E MODIFICADORES
-- ============================================================================

--- Define o nível global de depuração.
--- @param nivel number O nível do log (1 a 5).
function LKS_EletricidadeConstrucao.Core.Logger.SetLevel(nivel)
    _nivelGlobal = nivel
end

--- Obtém o nível global de depuração atual.
--- @return number O nível do log global ativo.
function LKS_EletricidadeConstrucao.Core.Logger.GetLevel()
    return _nivelGlobal
end

--- Define o nível de depuração para uma categoria de log específica.
--- @param categoria string O nome descritivo da categoria.
--- @param nivel number O nível do log.
function LKS_EletricidadeConstrucao.Core.Logger.SetCategoryLevel(categoria, nivel)
    _niveisCategorias[categoria] = nivel
end

--- Habilita a exibição de logs para uma determinada categoria.
--- @param categoria string O nome descritivo da categoria.
function LKS_EletricidadeConstrucao.Core.Logger.EnableCategory(categoria)
    _categoriasHabilitadas[categoria] = true
end

--- Desabilita a exibição de logs para uma determinada categoria.
--- @param categoria string O nome descritivo da categoria.
function LKS_EletricidadeConstrucao.Core.Logger.DisableCategory(categoria)
    _categoriasHabilitadas[categoria] = false
end

--- Verifica se uma categoria de log está habilitada para exibição.
--- @param categoria string O nome descritivo da categoria.
--- @return boolean Retorna true se estiver habilitada.
function LKS_EletricidadeConstrucao.Core.Logger.IsCategoryEnabled(categoria)
    return _categoriasHabilitadas[categoria] == true
end

--- Define se o carimbo de data/hora do jogo deve ser impresso nos logs.
--- @param habilitado boolean True para exibir.
function LKS_EletricidadeConstrucao.Core.Logger.SetShowTimestamp(habilitado)
    _exibirCarimboTempo = habilitado
end

--- Define se a categoria correspondente deve ser impressa nos logs.
--- @param habilitado boolean True para exibir.
function LKS_EletricidadeConstrucao.Core.Logger.SetShowCategory(habilitado)
    _exibirCategoria = habilitado
end

-- ============================================================================
-- VERIFICAÇÕES DE FILTRAGEM
-- ============================================================================

--- Valida se uma mensagem de depuração deve ser impressa de acordo com o nível e categoria.
--- @param nivel number O nível de log da mensagem específica.
--- @param categoria string|nil O nome da categoria associada.
--- @return boolean Retorna true se a mensagem deve ser impressa.
local function ShouldLog(nivel, categoria)
    -- Verifica se a categoria está desabilitada
    if categoria and not LKS_EletricidadeConstrucao.Core.Logger.IsCategoryEnabled(categoria) then
        return false
    end
    
    -- Determina o nível de corte (específico da categoria ou global)
    local nivelCorte = _nivelGlobal
    if categoria and _niveisCategorias[categoria] then
        nivelCorte = _niveisCategorias[categoria]
    end
    
    return nivel <= nivelCorte
end

-- ============================================================================
-- FORMATAÇÃO DE TEXTO
-- ============================================================================

--- Formata a mensagem de log adicionando prefixos e informações contextuais.
--- @param nivelTexto string A identificação do nível (ex: "INFO", "WARN").
--- @param categoria string|nil O nome da categoria associada.
--- @param mensagem string A mensagem descritiva principal.
--- @return string A mensagem de log formatada final.
local function FormatMessage(nivelTexto, categoria, mensagem)
    local partes = {}
    
    -- Adiciona carimbo de data/hora do jogo (pcall seguro contra boots parciais da engine)
    if _exibirCarimboTempo then
        local sucesso, tempoJogo = pcall(getGameTime)
        if sucesso and tempoJogo then
            local hora = tempoJogo:getHour()
            local minuto = tempoJogo:getMinutes()
            table.insert(partes, string.format("[%02d:%02d]", hora, minuto))
        end
    end
    
    -- Prefixo do Mod
    table.insert(partes, "[LKS_EletricidadeConstrucao]")
    
    -- Nível do log
    table.insert(partes, "[" .. nivelTexto .. "]")
    
    -- Categoria do log
    if _exibirCategoria and categoria then
        table.insert(partes, "[" .. categoria .. "]")
    end
    
    -- Mensagem descritiva
    table.insert(partes, mensagem)
    
    return table.concat(partes, " ")
end

-- ============================================================================
-- FUNÇÕES DE LOGGING CORE
-- ============================================================================

--- Grava uma mensagem de log de erro (ERROR) no console.
--- @param mensagem string A mensagem.
--- @param categoria? string A categoria (opcional).
function LKS_EletricidadeConstrucao.Core.Logger.Error(mensagem, categoria)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.ERROR, categoria) then
        return
    end
    
    local mensagemFormatada = FormatMessage("ERROR", categoria, mensagem)
    print(mensagemFormatada)
    
    -- Fallback adicional de gravação
    if isClient() then
        print(mensagemFormatada)
    end
end

--- Grava uma mensagem de log de aviso (WARN) no console.
--- @param mensagem string A mensagem.
--- @param categoria? string A categoria (opcional).
function LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem, categoria)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.WARN, categoria) then
        return
    end
    
    local mensagemFormatada = FormatMessage("WARN", categoria, mensagem)
    print(mensagemFormatada)
end

--- Grava uma mensagem de log de informação (INFO) no console.
--- @param mensagem string A mensagem.
--- @param categoria? string A categoria (opcional).
function LKS_EletricidadeConstrucao.Core.Logger.Info(mensagem, categoria)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.INFO, categoria) then
        return
    end
    
    local mensagemFormatada = FormatMessage("INFO", categoria, mensagem)
    print(mensagemFormatada)
end

--- Grava uma mensagem de log de depuração (DEBUG) no console.
--- @param mensagem string A mensagem.
--- @param categoria? string A categoria (opcional).
function LKS_EletricidadeConstrucao.Core.Logger.Debug(mensagem, categoria)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.DEBUG, categoria) then
        return
    end
    
    local mensagemFormatada = FormatMessage("DEBUG", categoria, mensagem)
    print(mensagemFormatada)
end

--- Grava uma mensagem de log de rastreamento detalhado (TRACE) no console.
--- @param mensagem string A mensagem.
--- @param categoria? string A categoria (opcional).
function LKS_EletricidadeConstrucao.Core.Logger.Trace(mensagem, categoria)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.TRACE, categoria) then
        return
    end
    
    local mensagemFormatada = FormatMessage("TRACE", categoria, mensagem)
    print(mensagemFormatada)
end

-- ============================================================================
-- ENVIOS RÁPIDOS (SHORTCUTS) POR CATEGORIA
-- ============================================================================

--- Grava mensagens específicas relacionadas a combustível de geradores.
--- @param nivel number O nível de severidade do log.
--- @param mensagem string A mensagem.
function LKS_EletricidadeConstrucao.Core.Logger.LogFuel(nivel, mensagem)
    local Levels = LKS_EletricidadeConstrucao.Core.Logger.Levels
    local categoria = LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL
    
    if nivel == Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(mensagem, categoria)
    elseif nivel == Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem, categoria)
    elseif nivel == Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(mensagem, categoria)
    elseif nivel == Levels.DEBUG then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(mensagem, categoria)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(mensagem, categoria)
    end
end

--- Grava mensagens específicas relacionadas à malha e distribuição de energia.
--- @param nivel number O nível de severidade do log.
--- @param mensagem string A mensagem.
function LKS_EletricidadeConstrucao.Core.Logger.LogPower(nivel, mensagem)
    local Levels = LKS_EletricidadeConstrucao.Core.Logger.Levels
    local categoria = LKS_EletricidadeConstrucao.Core.Logger.Categories.POWER
    
    if nivel == Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(mensagem, categoria)
    elseif nivel == Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem, categoria)
    elseif nivel == Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(mensagem, categoria)
    elseif nivel == Levels.DEBUG then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(mensagem, categoria)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(mensagem, categoria)
    end
end

--- Grava mensagens específicas relacionadas à simulação e escaneamento de prédios.
--- @param nivel number O nível de severidade do log.
--- @param mensagem string A mensagem.
function LKS_EletricidadeConstrucao.Core.Logger.LogBuilding(nivel, mensagem)
    local Levels = LKS_EletricidadeConstrucao.Core.Logger.Levels
    local categoria = LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING
    
    if nivel == Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(mensagem, categoria)
    elseif nivel == Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem, categoria)
    elseif nivel == Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(mensagem, categoria)
    elseif nivel == Levels.DEBUG then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(mensagem, categoria)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(mensagem, categoria)
    end
end

--- Grava mensagens específicas relacionadas à transmissão de pacotes de rede (MP).
--- @param nivel number O nível de severidade do log.
--- @param mensagem string A mensagem.
function LKS_EletricidadeConstrucao.Core.Logger.LogNetwork(nivel, mensagem)
    local Levels = LKS_EletricidadeConstrucao.Core.Logger.Levels
    local categoria = LKS_EletricidadeConstrucao.Core.Logger.Categories.NETWORK
    
    if nivel == Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(mensagem, categoria)
    elseif nivel == Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem, categoria)
    elseif nivel == Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(mensagem, categoria)
    elseif nivel == Levels.DEBUG then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(mensagem, categoria)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(mensagem, categoria)
    end
end

--- Grava mensagens específicas relacionadas à interface de usuário (UI).
--- @param nivel number O nível de severidade do log.
--- @param mensagem string A mensagem.
function LKS_EletricidadeConstrucao.Core.Logger.LogUI(nivel, mensagem)
    local Levels = LKS_EletricidadeConstrucao.Core.Logger.Levels
    local categoria = LKS_EletricidadeConstrucao.Core.Logger.Categories.UI
    
    if nivel == Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(mensagem, categoria)
    elseif nivel == Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem, categoria)
    elseif nivel == Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(mensagem, categoria)
    elseif nivel == Levels.DEBUG then
        LKS_EletricidadeConstrucao.Core.Logger.Debug(mensagem, categoria)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(mensagem, categoria)
    end
end

-- ============================================================================
-- DIAGNÓSTICO DE DESEMPENHO (PERFORMANCE TIMERS)
-- ============================================================================

local _cronometrosPerformance = {}

--- Inicia a cronometragem de desempenho para um bloco de código específico.
--- @param nomeTimer string O nome de identificação exclusivo do cronômetro.
function LKS_EletricidadeConstrucao.Core.Logger.StartTimer(nomeTimer)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.DEBUG, LKS_EletricidadeConstrucao.Core.Logger.Categories.PERFORMANCE) then
        return
    end
    
    _cronometrosPerformance[nomeTimer] = getTimestampMs()
end

--- Finaliza a cronometragem de desempenho de um bloco de código, imprimindo o tempo decorrido.
--- @param nomeTimer string O nome de identificação exclusivo do cronômetro.
--- @param limiteMilissegundos number|nil Limite de tolerância em milissegundos para disparar avisos de lentidão (opcional).
function LKS_EletricidadeConstrucao.Core.Logger.EndTimer(nomeTimer, limiteMilissegundos)
    if not ShouldLog(LKS_EletricidadeConstrucao.Core.Logger.Levels.DEBUG, LKS_EletricidadeConstrucao.Core.Logger.Categories.PERFORMANCE) then
        return
    end
    
    local tempoInicio = _cronometrosPerformance[nomeTimer]
    if not tempoInicio then
        LKS_EletricidadeConstrucao.Core.Logger.Warn("O cronometro '" .. nomeTimer .. "' nao foi iniciado", LKS_EletricidadeConstrucao.Core.Logger.Categories.PERFORMANCE)
        return
    end
    
    local tempoDecorrido = getTimestampMs() - tempoInicio
    _cronometrosPerformance[nomeTimer] = nil
    
    local mensagem = string.format("%s levou %.2f ms", nomeTimer, tempoDecorrido)
    
    -- Dispara aviso caso exceda o limite crítico
    if limiteMilissegundos and tempoDecorrido > limiteMilissegundos then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem .. " (excedeu o limite tolerado: " .. limiteMilissegundos .. " ms)", LKS_EletricidadeConstrucao.Core.Logger.Categories.PERFORMANCE)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Debug(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.PERFORMANCE)
    end
end

-- ============================================================================
-- LOGGING DE ESTRUTURAS E MODELOS DE DADOS
-- ============================================================================

--- Grava no console a representação textual dos dados de um gerador.
--- @param dadosGerador GeneratorData Os dados do gerador.
--- @param nivel number|nil O nível de severidade do log (padrão: DEBUG).
function LKS_EletricidadeConstrucao.Core.Logger.LogGenerator(dadosGerador, nivel)
    nivel = nivel or LKS_EletricidadeConstrucao.Core.Logger.Levels.DEBUG
    
    if not ShouldLog(nivel, LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL) then
        return
    end
    
    local mensagem = LKS_EletricidadeConstrucao.Data.Generator.ToString(dadosGerador)
    
    if nivel == LKS_EletricidadeConstrucao.Core.Logger.Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL)
    elseif nivel == LKS_EletricidadeConstrucao.Core.Logger.Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL)
    elseif nivel == LKS_EletricidadeConstrucao.Core.Logger.Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Debug(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.FUEL)
    end
end

--- Grava no console a representação textual dos dados de um prédio.
--- @param dadosPredio BuildingData Os dados do prédio.
--- @param nivel number|nil O nível de severidade do log (padrão: DEBUG).
function LKS_EletricidadeConstrucao.Core.Logger.LogBuilding(dadosPredio, nivel)
    nivel = nivel or LKS_EletricidadeConstrucao.Core.Logger.Levels.DEBUG
    
    if not ShouldLog(nivel, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING) then
        return
    end
    
    local mensagem = LKS_EletricidadeConstrucao.Data.Building.ToString(dadosPredio)
    
    if nivel == LKS_EletricidadeConstrucao.Core.Logger.Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    elseif nivel == LKS_EletricidadeConstrucao.Core.Logger.Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    elseif nivel == LKS_EletricidadeConstrucao.Core.Logger.Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Debug(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    end
end

--- Grava no console a representação textual dos dados de um consumidor.
--- @param dadosConsumidor ConsumerData Os dados do consumidor.
--- @param nivel number|nil O nível de severidade do log (padrão: TRACE).
function LKS_EletricidadeConstrucao.Core.Logger.LogConsumer(dadosConsumidor, nivel)
    nivel = nivel or LKS_EletricidadeConstrucao.Core.Logger.Levels.TRACE
    
    if not ShouldLog(nivel, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING) then
        return
    end
    
    local mensagem = LKS_EletricidadeConstrucao.Data.Consumer.ToString(dadosConsumidor)
    
    if nivel == LKS_EletricidadeConstrucao.Core.Logger.Levels.ERROR then
        LKS_EletricidadeConstrucao.Core.Logger.Error(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    elseif nivel == LKS_EletricidadeConstrucao.Core.Logger.Levels.WARN then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    elseif nivel == LKS_EletricidadeConstrucao.Core.Logger.Levels.INFO then
        LKS_EletricidadeConstrucao.Core.Logger.Info(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    else
        LKS_EletricidadeConstrucao.Core.Logger.Trace(mensagem, LKS_EletricidadeConstrucao.Core.Logger.Categories.BUILDING)
    end
end

-- ============================================================================
-- UTILITÁRIOS DE DEPURAÇÃO
-- ============================================================================

--- Print logger configuration
function LKS_EletricidadeConstrucao.Core.Logger.PrintConfig()
    LKS_EletricidadeConstrucao.Print("=== Configuracoes do Logger ===")
    LKS_EletricidadeConstrucao.Print("Nivel Global: " .. _nivelGlobal)
    LKS_EletricidadeConstrucao.Print("Exibir Carimbo de Tempo: " .. tostring(_exibirCarimboTempo))
    LKS_EletricidadeConstrucao.Print("Exibir Categorias: " .. tostring(_exibirCategoria))
    
    LKS_EletricidadeConstrucao.Print("Categorias Habilitadas:")
    for categoria, habilitada in pairs(_categoriasHabilitadas) do
        local nivel = _niveisCategorias[categoria] or "padrão"
        LKS_EletricidadeConstrucao.Print("  " .. categoria .. ": " .. tostring(habilitada) .. " (nivel: " .. tostring(nivel) .. ")")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Core.Logger", "2.0.0")

return LKS_EletricidadeConstrucao.Core.Logger
