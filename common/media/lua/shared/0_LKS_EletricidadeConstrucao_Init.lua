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

-- ARQUIVO: 0_LKS_EletricidadeConstrucao_Init.lua
-- OBJETIVO: Ponto de entrada e inicialização principal do módulo LKS_EletricidadeConstrucao.
-- DETALHE DE PRECEDÊNCIA: O prefixo "0_" no nome do arquivo força alfabeticamente o carregamento
-- antes de qualquer subpasta do diretório "shared/" no motor Lua do Project Zomboid.
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- ============================================================================
-- FASE 0: CRIAÇÃO DO NAMESPACE GLOBAL E INFRAESTRUTURA BÁSICA
-- ============================================================================
-- CRÍTICO: O namespace deve existir antes que qualquer arquivo de ações ou utilitários
-- seja carregado pela engine em ordem alfabética.

-- Criação do Namespace Principal
LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao or {}

LKS_EletricidadeConstrucao.VERSION = "2.0.0-alpha"
LKS_EletricidadeConstrucao.BUILD_DATE = "2026-02-22"
LKS_EletricidadeConstrucao.MOD_ID = "LKSSuperModPatch"

-- Inicialização preventiva de sub-namespaces globais
LKS_EletricidadeConstrucao.Core = LKS_EletricidadeConstrucao.Core or {}
LKS_EletricidadeConstrucao.Core.Runtime = LKS_EletricidadeConstrucao.Core.Runtime or {}
LKS_EletricidadeConstrucao.Core.StateManager = LKS_EletricidadeConstrucao.Core.StateManager or {}
LKS_EletricidadeConstrucao.Core.EventManager = LKS_EletricidadeConstrucao.Core.EventManager or {}

-- ============================================================================
-- LOGGER PROXY (Fase 0)
-- ============================================================================
-- Cria um Logger Proxy temporário que enfileira mensagens em memória antes do
-- subsistema de logging real estar totalmente carregado. Isso evita travamentos de 
-- ponteiro nulo (nil pointer crashes) durante o bootstrap do mod.
if not LKS_EletricidadeConstrucao.Core.Logger or not LKS_EletricidadeConstrucao.Core.Logger._isProxy then
    local filaMensagens = {}
    local loggerReal = nil
    
    --- Despacha uma mensagem para o logger real ou a enfileira em memória se não estiver pronto.
    --- @param nivel string O nível do log (ex: "Info", "Warn", "Error").
    --- @param msg string A mensagem de texto a ser logada.
    --- @param categoria string A categoria ou escopo do log.
    local function despacharLog(nivel, msg, categoria)
        if loggerReal and loggerReal[nivel] then
            loggerReal[nivel](msg, categoria)
        else
            table.insert(filaMensagens, {
                level = nivel, 
                msg = tostring(msg), 
                cat = tostring(categoria or "")
            })
        end
    end
    
    LKS_EletricidadeConstrucao.Core.Logger = {
        _isProxy = true,
        _queue = filaMensagens,
        
        --- Ativa o logger real de produção e descarrega a fila de mensagens acumulada.
        --- Chamado internamente por LKS_EletricidadeConstrucao_Core_Logger.lua após carregar.
        --- @param loggerInstanciado table O módulo de logger de produção definitivo.
        _activate = function(loggerInstanciado)
            loggerReal = loggerInstanciado
            for _, entrada in ipairs(filaMensagens) do
                if loggerReal[entrada.level] then
                    loggerReal[entrada.level](entrada.msg, entrada.cat)
                else
                    print(string.format("[LKS_EletricidadeConstrucao][%s][%s] %s", entrada.level, entrada.cat, entrada.msg))
                end
            end
            filaMensagens = {}
        end,
        Info  = function(msg, cat) despacharLog("Info",  msg, cat) end,
        Warn  = function(msg, cat) despacharLog("Warn",  msg, cat) end,
        Error = function(msg, cat) despacharLog("Error", msg, cat) end,
        Debug = function(msg, cat) despacharLog("Debug", msg, cat) end,
        Trace = function(msg, cat) despacharLog("Trace", msg, cat) end,
    }
end

-- Inicialização dos demais sub-namespaces do mod
LKS_EletricidadeConstrucao.Fuel = LKS_EletricidadeConstrucao.Fuel or {}
LKS_EletricidadeConstrucao.Fuel.Manager = LKS_EletricidadeConstrucao.Fuel.Manager or {}
LKS_EletricidadeConstrucao.Fuel.StrainCalculator = LKS_EletricidadeConstrucao.Fuel.StrainCalculator or {}
LKS_EletricidadeConstrucao.Fuel.ChunkTracker = LKS_EletricidadeConstrucao.Fuel.ChunkTracker or {}

LKS_EletricidadeConstrucao.Power = LKS_EletricidadeConstrucao.Power or {}
LKS_EletricidadeConstrucao.Power.Manager = LKS_EletricidadeConstrucao.Power.Manager or {}
LKS_EletricidadeConstrucao.Power.Distributor = LKS_EletricidadeConstrucao.Power.Distributor or {}

LKS_EletricidadeConstrucao.Building = LKS_EletricidadeConstrucao.Building or {}
LKS_EletricidadeConstrucao.Building.Scanner = LKS_EletricidadeConstrucao.Building.Scanner or {}
LKS_EletricidadeConstrucao.Building.ConsumerScanner = LKS_EletricidadeConstrucao.Building.ConsumerScanner or {}
LKS_EletricidadeConstrucao.Building.BorderDetector = LKS_EletricidadeConstrucao.Building.BorderDetector or {}

LKS_EletricidadeConstrucao.Heating = LKS_EletricidadeConstrucao.Heating or {}
LKS_EletricidadeConstrucao.Heating.Manager = LKS_EletricidadeConstrucao.Heating.Manager or {}

LKS_EletricidadeConstrucao.DebugCommands = LKS_EletricidadeConstrucao.DebugCommands or {}

LKS_EletricidadeConstrucao.UI = LKS_EletricidadeConstrucao.UI or {}
LKS_EletricidadeConstrucao.Actions = LKS_EletricidadeConstrucao.Actions or {}
LKS_EletricidadeConstrucao.ContextMenu = LKS_EletricidadeConstrucao.ContextMenu or {}

LKS_EletricidadeConstrucao.Utils = LKS_EletricidadeConstrucao.Utils or {}
LKS_EletricidadeConstrucao.Data = LKS_EletricidadeConstrucao.Data or {}
LKS_EletricidadeConstrucao.Config = LKS_EletricidadeConstrucao.Config or {}
LKS_EletricidadeConstrucao.Constants = LKS_EletricidadeConstrucao.Constants or {}

LKS_EletricidadeConstrucao.Config.DebugMode = LKS_EletricidadeConstrucao.Config.DebugMode == true

if not LKS_EletricidadeConstrucao._RawPrint then
    LKS_EletricidadeConstrucao._RawPrint = print
end

--- Verifica se uma mensagem específica de console deve ser suprimida do print nativo.
---
--- Serve para reduzir a poluição visual do console gerada por logs redundantes,
--- permitindo apenas mensagens críticas de erro/alerta, ou todas as mensagens caso o DebugMode esteja ativo.
---
--- @param message any A mensagem a ser avaliada.
--- @return boolean Retorna true se a mensagem deve ser silenciada no console.
local function ShouldSuppressLKS_EletricidadeConstrucaoPrint(message)
    if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
        return false
    end

    message = tostring(message or "")
    local upper = string.upper(message)
    if string.find(upper, "ERROR", 1, true)
            or string.find(upper, "WARN", 1, true)
            or string.find(upper, "CRITICAL", 1, true) then
        return false
    end

    if message == "========================================"
            or message == "LKS_EletricidadeConstrucao V2 - Initialization"
            or message == "LKS_EletricidadeConstrucao V2 Ready"
            or string.find(message, "Version:", 1, true) == 1
            or string.find(message, "Date:", 1, true) == 1
            or string.find(message, "  Mode:", 1, true) == 1
            or string.find(message, "  Server:", 1, true) == 1
            or string.find(message, "  Client:", 1, true) == 1
            or string.find(message, "  Modules:", 1, true) == 1 then
        return true
    end

    return string.find(message, "[LKS_EletricidadeConstrucao_", 1, true) == 1
        or string.find(message, "[LKS_EletricidadeConstrucao]", 1, true) == 1
end

-- Instalador do filtro de console para print nativo
if not LKS_EletricidadeConstrucao._PrintFilterInstalled then
    local rawPrint = LKS_EletricidadeConstrucao._RawPrint
    print = function(...)
        if select('#', ...) == 1 and ShouldSuppressLKS_EletricidadeConstrucaoPrint(select(1, ...)) then
            return
        end
        rawPrint(...)
    end
    LKS_EletricidadeConstrucao._PrintFilterInstalled = true
end

LKS_EletricidadeConstrucao._LoadedModules = LKS_EletricidadeConstrucao._LoadedModules or {}
LKS_EletricidadeConstrucao._InitStatus = LKS_EletricidadeConstrucao._InitStatus or {
    NamespaceDefined = true,
    RuntimeContextReady = false,
    ConstantsLoaded = false,
    ConfigLoaded = false,
    CoreInitialized = false,
    ClientInitialized = false,
    ServerInitialized = false
}

-- Funções utilitárias globais do namespace elétrico
if not LKS_EletricidadeConstrucao.RegisterModule then
    --- Registra um módulo recém-carregado no namespace elétrico.
    --- @param moduleName string O nome descritivo do módulo.
    --- @param version string A versão técnica do módulo (opcional).
    function LKS_EletricidadeConstrucao.RegisterModule(moduleName, version)
        LKS_EletricidadeConstrucao._LoadedModules[moduleName] = {
            name = moduleName,
            version = version or "unknown",
            loadedAt = os.time()
        }
        LKS_EletricidadeConstrucao.Print(string.format("Modulo carregado: %s (v%s)", moduleName, version or "unknown"))
    end
end

if not LKS_EletricidadeConstrucao.Print then
    --- Função de logging padrão e padronizada para o console.
    --- @param message string O texto do log.
    --- @param level string O nível do log (opcional, padrão: "INFO").
    function LKS_EletricidadeConstrucao.Print(message, level)
        level = level or "INFO"
        print(string.format("[LKS_EletricidadeConstrucao][%s] %s", level, message))
    end
end

-- ============================================================================
-- FASE 1: SUBSISTEMAS BASE & DETECÇÃO DE AMBIENTE
-- ============================================================================

-- Carrega o módulo base de namespace
require "core/LKS_EletricidadeConstrucao_Core_Namespace"

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Init] CRITICO: Falha na inicializacao do Namespace - abortando boot")
    return
end

-- Carrega o contexto de execução (Singleplayer, Servidor Dedicado, Cliente Multiplayer)
require "core/LKS_EletricidadeConstrucao_Core_RuntimeContext"

if not LKS_EletricidadeConstrucao._InitStatus.RuntimeContextReady then
    print("[LKS_EletricidadeConstrucao_Init] CRITICO: Falha na inicializacao do Runtime Context - abortando boot")
    return
end

-- ============================================================================
-- FASE 2: CONSTANTES & CONFIGURAÇÕES DE SANDBOX
-- ============================================================================

-- Carrega números mágicos, limites físicos e constantes matemáticas
require "LKS_EletricidadeConstrucao_Constants"

-- Carrega o arquivo de configuração e preferências
require "LKS_EletricidadeConstrucao_Config"

-- Carrega e sincroniza as opções baseadas nas variáveis de Sandbox do servidor/mundo
if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.LoadFromSandbox then
    LKS_EletricidadeConstrucao.Config.LoadFromSandbox()
end

-- Executa validação de sanidade das configurações carregadas
if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.Validate then
    LKS_EletricidadeConstrucao.Config.Validate()
else
    print("[LKS_EletricidadeConstrucao_Init] AVISO: Config.Validate indisponivel, usando configuracoes padrao")
end

-- ============================================================================
-- FASE 3: BIBLIOTECAS UTILITÁRIAS (Códigos matemáticos/lógicos puros)
-- ============================================================================

require "utils/LKS_EletricidadeConstrucao_Utils_Math"
require "utils/LKS_EletricidadeConstrucao_Utils_Geometry"
require "utils/LKS_EletricidadeConstrucao_Utils_Table"
require "utils/LKS_EletricidadeConstrucao_Utils_Validation"

-- ============================================================================
-- FASE 4: ESTRUTURAS DE DADOS & GERENCIADORES CORE
-- ============================================================================

-- Carrega os modelos de dados (estruturas OOP e classes de simulação)
require "data/LKS_EletricidadeConstrucao_Data_Generator"
require "data/LKS_EletricidadeConstrucao_Data_Building"
require "data/LKS_EletricidadeConstrucao_Data_Consumer"
require "data/LKS_EletricidadeConstrucao_Data_State"

-- Carrega o Logger real, o Gerenciador de Estado e Eventos customizados
require "core/LKS_EletricidadeConstrucao_Core_Logger"
require "core/LKS_EletricidadeConstrucao_Core_StateManager"
require "core/LKS_EletricidadeConstrucao_Core_EventManager"

-- Inicializa os manipuladores de eventos e do ModData persistente do mundo
if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.EventManager and LKS_EletricidadeConstrucao.Core.EventManager.InitializeCustomEvents then
    LKS_EletricidadeConstrucao.Core.EventManager.InitializeCustomEvents()
else
    print("[LKS_EletricidadeConstrucao_Init] ERRO: EventManager.InitializeCustomEvents indisponivel!")
end

if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager and LKS_EletricidadeConstrucao.Core.StateManager.Initialize then
    LKS_EletricidadeConstrucao.Core.StateManager.Initialize()
else
    print("[LKS_EletricidadeConstrucao_Init] ERRO: StateManager.Initialize indisponivel!")
end

-- ============================================================================
-- FASE 5: INICIALIZAÇÃO DE CONTEXTOS COMPARTILHADOS E TIMED ACTIONS
-- ============================================================================

-- Imprime o modo de jogo detectado (Singleplayer / Multiplayer Client / Server)
LKS_EletricidadeConstrucao.Core.Runtime.PrintContext()

-- Carrega as Ações Temporizadas comuns a Cliente e Servidor
require "actions/LKS_EletricidadeConstrucao_ActionsInit"

-- AVISO CRÍTICO: Não dê require em arquivos das pastas "client/" ou "server/"
-- diretamente de arquivos na pasta "shared/". O PZ se encarrega de carregar
-- automaticamente LKS_EletricidadeConstrucao_ClientInit.lua ou
-- LKS_EletricidadeConstrucao_ServerInit.lua nos respectivos ambientes isolados de execução Lua.
LKS_EletricidadeConstrucao._InitStatus.ClientInitialized = false  -- Preenchido por LKS_EletricidadeConstrucao_ClientInit.lua
LKS_EletricidadeConstrucao._InitStatus.ServerInitialized = false  -- Preenchido por LKS_EletricidadeConstrucao_ServerInit.lua

-- ============================================================================
-- FASE 6: CONCLUSÃO DO PROCESSO DE BOOTSTRAP
-- ============================================================================

LKS_EletricidadeConstrucao._InitStatus.CoreInitialized = true

-- Resumo dos módulos carregados com sucesso
local modulosCarregados = LKS_EletricidadeConstrucao.GetLoadedModules()
LKS_EletricidadeConstrucao.Print(string.format("Inicializacao concluida - %d modulos registrados", #modulosCarregados))

if LKS_EletricidadeConstrucao.Config.DebugMode then
    LKS_EletricidadeConstrucao.Print("Modulos carregados em ordem:")
    for _, nomeModulo in ipairs(modulosCarregados) do
        LKS_EletricidadeConstrucao.Print("  - " .. nomeModulo)
    end
end

-- Cabeçalho detalhado no log final de carregamento
print("========================================")
print("LKS_EletricidadeConstrucao V2 Pronto")
print(string.format("  Modo de Jogo: %s", LKS_EletricidadeConstrucao.Core.Runtime.GetGameMode()))
print(string.format("  Servidor: %s", tostring(LKS_EletricidadeConstrucao.IsServer())))
print(string.format("  Cliente: %s", tostring(LKS_EletricidadeConstrucao.IsClient())))
print(string.format("  Módulos: %d", #modulosCarregados))
print("========================================")

-- Salva carimbo de data/hora do boot
LKS_EletricidadeConstrucao._InitTimestamp = os.time()

print("[LKS PATCH - 0_LKS_EletricidadeConstrucao_Init.lua] Carregado com sucesso!")

return LKS_EletricidadeConstrucao
