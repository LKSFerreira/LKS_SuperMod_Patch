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

-- ARQUIVO: LKS_EletricidadeConstrucao_Core_EventManager.lua
-- OBJETIVO: Sistema de eventos personalizado para comunicação interna e extensões.
-- Versão: 2.0.0-alpha
-- Data: 15 de Junho de 2026

-- Garante que o namespace principal exista
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Core_EventManager] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- ============================================================================
-- REGISTRO DE EVENTOS
-- ============================================================================

local _manipuladoresEventos = {} -- nomeEvento -> array contendo as funções ouvintes
local _estatisticasEventos = {}  -- nomeEvento -> { disparados: number, manipuladores: number }

-- ============================================================================
-- FUNÇÕES AUXILIARES INTERNAS
-- ============================================================================

--- Inicializa a estrutura de estatísticas de disparos para um determinado evento.
--- @param nomeEvento string O nome identificador do evento.
local function InicializarEstatisticasEvento(nomeEvento)
    if not _estatisticasEventos[nomeEvento] then
        _estatisticasEventos[nomeEvento] = {
            disparados = 0,
            manipuladores = 0
        }
    end
end

-- ============================================================================
-- MÉTODOS PÚBLICOS DE MANIPULAÇÃO DE EVENTOS
-- ============================================================================

--- Registra um manipulador/ouvinte de evento personalizado com prioridade.
--- @param nomeEvento string O nome do evento a ser escutado.
--- @param manipulador function A função callback executada quando o evento é disparado.
--- @param prioridade number|nil Prioridade de execução (valores maiores rodam antes, padrão: 0).
--- @return boolean Retorna true se o registro foi realizado com sucesso.
function LKS_EletricidadeConstrucao.Core.EventManager.RegisterHandler(nomeEvento, manipulador, prioridade)
    local Validacao = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Validação de sanidade de parâmetros
    if Validacao.IsEmptyString(nomeEvento) then
        LKS_EletricidadeConstrucao.Core.Logger.Error("O nome do evento não pode ser vazio", "Event")
        return false
    end
    
    if not Validacao.IsFunction(manipulador) then
        LKS_EletricidadeConstrucao.Core.Logger.Error("O manipulador do evento deve ser uma função válida", "Event")
        return false
    end
    
    -- Cria a fila de ouvintes caso seja o primeiro registro do evento
    if not _manipuladoresEventos[nomeEvento] then
        _manipuladoresEventos[nomeEvento] = {}
    end
    
    local entrada = {
        handler = manipulador,
        priority = prioridade or 0
    }
    
    table.insert(_manipuladoresEventos[nomeEvento], entrada)
    
    -- Ordena os ouvintes por prioridade de execução (maior prioridade executa antes)
    table.sort(_manipuladoresEventos[nomeEvento], function(manipuladorA, manipuladorB)
        return manipuladorA.priority > manipuladorB.priority
    end)
    
    -- Atualiza metadados estatísticos
    InicializarEstatisticasEvento(nomeEvento)
    _estatisticasEventos[nomeEvento].manipuladores = #_manipuladoresEventos[nomeEvento]
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug("Registrado manipulador para o evento: " .. nomeEvento, "Event")
    
    return true
end

--- Remove o registro de um manipulador de evento previamente escutado.
--- @param nomeEvento string O nome do evento associado.
--- @param manipulador function A função callback a ser desvinculada.
--- @return boolean Retorna true se o manipulador foi localizado e removido.
function LKS_EletricidadeConstrucao.Core.EventManager.UnregisterHandler(nomeEvento, manipulador)
    if not _manipuladoresEventos[nomeEvento] then
        return false
    end
    
    for indiceLoop = #_manipuladoresEventos[nomeEvento], 1, -1 do
        if _manipuladoresEventos[nomeEvento][indiceLoop].handler == manipulador then
            table.remove(_manipuladoresEventos[nomeEvento], indiceLoop)
            
            if _estatisticasEventos[nomeEvento] then
                _estatisticasEventos[nomeEvento].manipuladores = #_manipuladoresEventos[nomeEvento]
            end
            
            LKS_EletricidadeConstrucao.Core.Logger.Debug("Removido manipulador do evento: " .. nomeEvento, "Event")
            return true
        end
    end
    
    return false
end

--- Limpa permanentemente todos os manipuladores vinculados a um evento.
--- @param nomeEvento string O nome do evento a limpar.
function LKS_EletricidadeConstrucao.Core.EventManager.ClearHandlers(nomeEvento)
    _manipuladoresEventos[nomeEvento] = nil
    
    if _estatisticasEventos[nomeEvento] then
        _estatisticasEventos[nomeEvento].manipuladores = 0
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug("Todos os ouvintes do evento foram limpos: " .. nomeEvento, "Event")
end

-- ============================================================================
-- DISPARADOR DE EVENTOS
-- ============================================================================

--- Dispara um evento personalizado executando todos os manipuladores escutas em ordem de prioridade.
--- @param nomeEvento string O nome do evento disparado.
--- @param ... any Argumentos variáveis repassados às funções callbacks ouvintes.
--- @return integer A quantidade de manipuladores executados com sucesso (sem travar por erro).
function LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(nomeEvento, ...)
    if not _manipuladoresEventos[nomeEvento] or #_manipuladoresEventos[nomeEvento] == 0 then
        return 0
    end
    
    InicializarEstatisticasEvento(nomeEvento)
    _estatisticasEventos[nomeEvento].disparados = _estatisticasEventos[nomeEvento].disparados + 1
    
    local contagemSucessos = 0
    local argumentos = {...}
    
    LKS_EletricidadeConstrucao.Core.Logger.Trace(string.format(
        "Disparando evento: %s com %d manipuladores na fila", 
        nomeEvento, #_manipuladoresEventos[nomeEvento]), "Event")
    
    for _, entrada in ipairs(_manipuladoresEventos[nomeEvento]) do
        -- Protege a execução de callbacks em ambiente isolado pcall para não derrubar a engine por erros de mods terceiros
        local sucesso, erro = pcall(entrada.handler, unpack(argumentos))
        
        if not sucesso then
            LKS_EletricidadeConstrucao.Core.Logger.Error(string.format(
                "Falha técnica na execução do callback do evento %s: %s", 
                nomeEvento, tostring(erro)), "Event")
        else
            contagemSucessos = contagemSucessos + 1
        end
    end
    
    return contagemSucessos
end

--- Vincula uma função callback a um evento nativo/vanilla do Project Zomboid (API nativa Events.X.Add).
--- @param nomeEvento string O nome do evento nativo do jogo (ex: OnTick, OnGameStart, OnContainerUpdate).
--- @param manipulador function A função executada pelo evento nativo.
--- @return boolean Retorna true se o vínculo com a engine foi realizado com sucesso.
function LKS_EletricidadeConstrucao.Core.EventManager.RegisterGameEvent(nomeEvento, manipulador)
    if not Events[nomeEvento] then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(string.format(
            "RegisterGameEvent: O evento nativo '%s' não existe nesta VM Lua do jogo - pulando registro", 
            tostring(nomeEvento)), "Event")
        return false
    end
    Events[nomeEvento].Add(manipulador)
    LKS_EletricidadeConstrucao.Core.Logger.Debug("Registrado vínculo com evento nativo: " .. nomeEvento, "Event")
    return true
end

--- Remove o vínculo de uma função callback em relação a um evento nativo do Project Zomboid.
--- @param nomeEvento string O nome do evento nativo.
--- @param manipulador function O callback ou ouvinte a desvincular.
--- @return boolean Retorna true se o desvínculo foi concluído.
function LKS_EletricidadeConstrucao.Core.EventManager.UnregisterGameEvent(nomeEvento, manipulador)
    if not Events[nomeEvento] then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(string.format(
            "UnregisterGameEvent: O evento nativo '%s' não existe - pulando desregistramento", 
            tostring(nomeEvento)), "Event")
        return false
    end
    Events[nomeEvento].Remove(manipulador)
    LKS_EletricidadeConstrucao.Core.Logger.Debug("Removido vínculo com evento nativo: " .. nomeEvento, "Event")
    return true
end

-- ============================================================================
-- DEFINIÇÕES DE EVENTOS CUSTOMIZADOS DO SISTEMA ELÉTRICO
-- ============================================================================

--- Inicializa e valida as definições dos eventos personalizados configurados nas Constantes do mod.
function LKS_EletricidadeConstrucao.Core.EventManager.InitializeCustomEvents()
    if not LKS_EletricidadeConstrucao 
            or not LKS_EletricidadeConstrucao.Constants 
            or not LKS_EletricidadeConstrucao.Core 
            or not LKS_EletricidadeConstrucao.Core.Logger then
        print("[LKS_EletricidadeConstrucao_Core_EventManager] InitializeCustomEvents: Dependencias internas indisponiveis!")
        return
    end
    
    local Constantes = LKS_EletricidadeConstrucao.Constants
    
    if Constantes.EVENTS then
        for _, nomeEvento in pairs(Constantes.EVENTS) do
            InicializarEstatisticasEvento(nomeEvento)
        end
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Eventos personalizados do sistema elétrico inicializados", "Event")
end

-- ============================================================================
-- ENTRADAS DE GATILHOS (GERADORES)
-- ============================================================================

--- Dispara evento após a conexão física de um gerador a uma construção.
--- @param dadosGerador table Os dados do gerador.
--- @param dadosConstrucao table Os dados da construção conectada.
function LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorConnected(dadosGerador, dadosConstrucao)
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.GENERATOR_CONNECTED, dadosGerador, dadosConstrucao)
end

--- Dispara evento após a desconexão física de um gerador em relação a uma construção.
--- @param dadosGerador table Os dados do gerador.
--- @param dadosConstrucao table Os dados da construção desconectada.
function LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorDisconnected(dadosGerador, dadosConstrucao)
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.GENERATOR_DISCONNECTED, dadosGerador, dadosConstrucao)
end

--- Dispara evento de ativação física de gerador.
--- @param dadosGerador table Os dados do gerador ligado.
function LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorActivated(dadosGerador)
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.GENERATOR_ACTIVATED, dadosGerador)
end

--- Dispara evento de desativação física de gerador.
--- @param dadosGerador table Os dados do gerador desligado.
function LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorDeactivated(dadosGerador)
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.GENERATOR_DEACTIVATED, dadosGerador)
end

--- Dispara evento indicando que o combustível do gerador acabou completamente.
--- @param dadosGerador table Os dados do gerador afetado.
function LKS_EletricidadeConstrucao.Core.EventManager.OnGeneratorFuelEmpty(dadosGerador)
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.GENERATOR_FUEL_EMPTY, dadosGerador)
end

-- ============================================================================
-- ENTRADAS DE GATILHOS (CONSTRUÇÕES)
-- ============================================================================

--- Dispara evento de alteração no estado de alimentação elétrica de uma construção.
--- @param dadosConstrucao table Os dados da construção.
--- @param estaEnergizado boolean Novo status de energia.
function LKS_EletricidadeConstrucao.Core.EventManager.OnBuildingPowerChanged(dadosConstrucao, estaEnergizado)
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.BUILDING_POWER_CHANGED, dadosConstrucao, estaEnergizado)
end

--- Dispara evento após a conclusão da varredura geométrica e de blocos de uma construção.
--- @param dadosConstrucao table Os dados da construção varrida.
function LKS_EletricidadeConstrucao.Core.EventManager.OnBuildingScanned(dadosConstrucao)
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.BUILDING_SCANNED, dadosConstrucao)
end

-- ============================================================================
-- ENTRADAS DE GATILHOS (ESTADO DO MOD)
-- ============================================================================

--- Dispara evento após o carregamento bem-sucedido dos dados globais ModData.
function LKS_EletricidadeConstrucao.Core.EventManager.OnStateLoaded()
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.STATE_LOADED)
end

--- Dispara evento após a gravação persistente dos dados globais no ModData.
function LKS_EletricidadeConstrucao.Core.EventManager.OnStateSaved()
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.STATE_SAVED)
end

--- Dispara evento após a redefinição padrão do estado do mod.
function LKS_EletricidadeConstrucao.Core.EventManager.OnStateReset()
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.STATE_RESET)
end

-- ============================================================================
-- ENTRADAS DE GATILHOS (MULTIPLAYER)
-- ============================================================================

--- Dispara evento de sincronização total solicitada/recebida no modo rede MP.
function LKS_EletricidadeConstrucao.Core.EventManager.OnFullSync()
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.FULL_SYNC)
end

--- Dispara evento de sincronização incremental delta solicitada/recebida no modo rede MP.
function LKS_EletricidadeConstrucao.Core.EventManager.OnDeltaSync()
    local Constantes = LKS_EletricidadeConstrucao.Constants
    LKS_EletricidadeConstrucao.Core.EventManager.TriggerEvent(Constantes.EVENTS.DELTA_SYNC)
end

-- ============================================================================
-- CONSULTAS E AUDITORIA
-- ============================================================================

--- Retorna as estatísticas de disparos consolidadas para um ou todos os eventos.
--- @param nomeEvento string|nil O nome do evento a filtrar (nil para retornar todos).
--- @return table Tabela contendo estatísticas de contagem de disparo.
function LKS_EletricidadeConstrucao.Core.EventManager.GetStats(nomeEvento)
    if nomeEvento then
        return _estatisticasEventos[nomeEvento] or { disparados = 0, manipuladores = 0 }
    else
        return _estatisticasEventos
    end
end

--- Consulta a quantidade de ouvintes/manipuladores vinculados a um evento.
--- @param nomeEvento string O nome identificador do evento.
--- @return integer Quantidade de ouvintes ativos.
function LKS_EletricidadeConstrucao.Core.EventManager.GetHandlerCount(nomeEvento)
    if not _manipuladoresEventos[nomeEvento] then
        return 0
    end
    return #_manipuladoresEventos[nomeEvento]
end

--- Verifica se há ouvintes registrados escutando um evento específico.
--- @param nomeEvento string O nome do evento.
--- @return boolean Retorna true se houver ao menos um manipulador escutando o evento.
function LKS_EletricidadeConstrucao.Core.EventManager.HasHandlers(nomeEvento)
    return LKS_EletricidadeConstrucao.Core.EventManager.GetHandlerCount(nomeEvento) > 0
end

--- Imprime estatísticas históricas de disparo e ouvintes cadastrados no console.
function LKS_EletricidadeConstrucao.Core.EventManager.PrintStats()
    LKS_EletricidadeConstrucao.Print("=== Estatísticas do Gerenciador de Eventos ===")
    
    local totalDisparados = 0
    local totalManipuladores = 0
    
    for nomeEvento, estatisticas in pairs(_estatisticasEventos) do
        LKS_EletricidadeConstrucao.Print(string.format("  %s: disparados=%d manipuladores=%d", 
            nomeEvento, estatisticas.disparados, estatisticas.manipuladores))
        
        totalDisparados = totalDisparados + estatisticas.disparados
        totalManipuladores = totalManipuladores + estatisticas.manipuladores
    end
    
    LKS_EletricidadeConstrucao.Print(string.format("Total: %d disparos de eventos efetuados, %d manipuladores registrados", 
        totalDisparados, totalManipuladores))
end

--- Imprime a lista detalhada de eventos e ouvintes ordenados por prioridade no console.
function LKS_EletricidadeConstrucao.Core.EventManager.PrintEvents()
    LKS_EletricidadeConstrucao.Print("=== Eventos Customizados Registrados ===")
    
    for nomeEvento, manipuladores in pairs(_manipuladoresEventos) do
        LKS_EletricidadeConstrucao.Print(string.format("  %s: %d manipuladores", nomeEvento, #manipuladores))
        for indice, entrada in ipairs(manipuladores) do
            LKS_EletricidadeConstrucao.Print(string.format("    [%d] Prioridade: %d", indice, entrada.priority))
        end
    end
end

--- Zera o histórico acumulado de contagem de disparos dos eventos.
function LKS_EletricidadeConstrucao.Core.EventManager.ClearStats()
    for _, estatisticas in pairs(_estatisticasEventos) do
        estatisticas.disparados = 0
    end
    LKS_EletricidadeConstrucao.Core.Logger.Debug("Estatísticas de disparos de eventos zeradas", "Event")
end

-- ============================================================================
-- CONCLUSÃO DO REGISTRO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Core.EventManager", "2.0.0")

return LKS_EletricidadeConstrucao.Core.EventManager
