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

-- ARQUIVO: LKS_EletricidadeConstrucao_Core_Namespace.lua
-- OBJETIVO: Declaração das tabelas e sub-namespaces globais que compõem o mod.
-- DETALHE TÉCNICO: Este arquivo inicializa a estrutura hierárquica do mod antes do carregamento
-- dos arquivos funcionais subsequentes.
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- ============================================================================
-- INICIALIZAÇÃO DO NAMESPACE GLOBAL
-- ============================================================================

-- Garante que o namespace principal não seja sobrescrito se já instanciado
LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao or {}

LKS_EletricidadeConstrucao.VERSION = "2.0.0-alpha"
LKS_EletricidadeConstrucao.BUILD_DATE = "2026-02-22"
LKS_EletricidadeConstrucao.MOD_ID = "LKSSuperModPatch"

-- ============================================================================
-- ESTRUTURA DOS SUB-NAMESPACES
-- ============================================================================

-- Módulos de Infraestrutura e Core
LKS_EletricidadeConstrucao.Core = LKS_EletricidadeConstrucao.Core or {}
LKS_EletricidadeConstrucao.Core.Runtime = LKS_EletricidadeConstrucao.Core.Runtime or {}
LKS_EletricidadeConstrucao.Core.Events = LKS_EletricidadeConstrucao.Core.Events or {}
LKS_EletricidadeConstrucao.Core.EventManager = LKS_EletricidadeConstrucao.Core.EventManager or {}
LKS_EletricidadeConstrucao.Core.State = LKS_EletricidadeConstrucao.Core.State or {}
LKS_EletricidadeConstrucao.Core.StateManager = LKS_EletricidadeConstrucao.Core.StateManager or {}
LKS_EletricidadeConstrucao.Core.Modules = LKS_EletricidadeConstrucao.Core.Modules or {}
LKS_EletricidadeConstrucao.Core.Logger = LKS_EletricidadeConstrucao.Core.Logger or {}

-- Módulos Lado Servidor (Física e Simulação da Rede)
LKS_EletricidadeConstrucao.Fuel = LKS_EletricidadeConstrucao.Fuel or {}
LKS_EletricidadeConstrucao.Fuel.Manager = LKS_EletricidadeConstrucao.Fuel.Manager or {}
LKS_EletricidadeConstrucao.Fuel.ChunkTracker = LKS_EletricidadeConstrucao.Fuel.ChunkTracker or {}
LKS_EletricidadeConstrucao.Fuel.StrainCalculator = LKS_EletricidadeConstrucao.Fuel.StrainCalculator or {}

LKS_EletricidadeConstrucao.Power = LKS_EletricidadeConstrucao.Power or {}
LKS_EletricidadeConstrucao.Power.Manager = LKS_EletricidadeConstrucao.Power.Manager or {}
LKS_EletricidadeConstrucao.Power.Distributor = LKS_EletricidadeConstrucao.Power.Distributor or {}

LKS_EletricidadeConstrucao.Building = LKS_EletricidadeConstrucao.Building or {}
LKS_EletricidadeConstrucao.Building.Scanner = LKS_EletricidadeConstrucao.Building.Scanner or {}
LKS_EletricidadeConstrucao.Building.BorderDetector = LKS_EletricidadeConstrucao.Building.BorderDetector or {}

LKS_EletricidadeConstrucao.Heating = LKS_EletricidadeConstrucao.Heating or {}
LKS_EletricidadeConstrucao.Heating.Manager = LKS_EletricidadeConstrucao.Heating.Manager or {}

-- Módulos Lado Cliente (Interface Gráfica e Input)
LKS_EletricidadeConstrucao.UI = LKS_EletricidadeConstrucao.UI or {}
LKS_EletricidadeConstrucao.Render = LKS_EletricidadeConstrucao.Render or {}
LKS_EletricidadeConstrucao.Input = LKS_EletricidadeConstrucao.Input or {}

-- Módulos Utilitários Compartilhados (Shared)
LKS_EletricidadeConstrucao.Utils = LKS_EletricidadeConstrucao.Utils or {}
LKS_EletricidadeConstrucao.Utils.Math = LKS_EletricidadeConstrucao.Utils.Math or {}
LKS_EletricidadeConstrucao.Utils.Geometry = LKS_EletricidadeConstrucao.Utils.Geometry or {}
LKS_EletricidadeConstrucao.Utils.Table = LKS_EletricidadeConstrucao.Utils.Table or {}
LKS_EletricidadeConstrucao.Utils.String = LKS_EletricidadeConstrucao.Utils.String or {}
LKS_EletricidadeConstrucao.Utils.Validation = LKS_EletricidadeConstrucao.Utils.Validation or {}

-- Classes e Modelos de Dados OOP
LKS_EletricidadeConstrucao.Data = LKS_EletricidadeConstrucao.Data or {}
LKS_EletricidadeConstrucao.Data.Generator = LKS_EletricidadeConstrucao.Data.Generator or {}
LKS_EletricidadeConstrucao.Data.Building = LKS_EletricidadeConstrucao.Data.Building or {}
LKS_EletricidadeConstrucao.Data.Consumer = LKS_EletricidadeConstrucao.Data.Consumer or {}
LKS_EletricidadeConstrucao.Data.State = LKS_EletricidadeConstrucao.Data.State or {}

-- API Pública para integração de outros mods
LKS_EletricidadeConstrucao.API = LKS_EletricidadeConstrucao.API or {}
LKS_EletricidadeConstrucao.API.Generator = LKS_EletricidadeConstrucao.API.Generator or {}
LKS_EletricidadeConstrucao.API.Consumer = LKS_EletricidadeConstrucao.API.Consumer or {}
LKS_EletricidadeConstrucao.API.Events = LKS_EletricidadeConstrucao.API.Events or {}

-- Tabelas de Configuração e Constantes
LKS_EletricidadeConstrucao.Config = LKS_EletricidadeConstrucao.Config or {}
LKS_EletricidadeConstrucao.Constants = LKS_EletricidadeConstrucao.Constants or {}

-- ============================================================================
-- RASTREAMENTO DO ESTADO DE INICIALIZAÇÃO
-- ============================================================================

-- Rastreio interno de quais módulos foram requisitados
LKS_EletricidadeConstrucao._LoadedModules = LKS_EletricidadeConstrucao._LoadedModules or {}

-- Estados de bootstrap dos arquivos principais
LKS_EletricidadeConstrucao._InitStatus = LKS_EletricidadeConstrucao._InitStatus or {
    NamespaceDefined = false,
    RuntimeContextReady = false,
    ConstantsLoaded = false,
    ConfigLoaded = false,
    CoreInitialized = false,
    ClientInitialized = false,
    ServerInitialized = false
}

LKS_EletricidadeConstrucao._InitStatus.NamespaceDefined = true

-- ============================================================================
-- REGISTRO DE MÓDULOS
-- ============================================================================

--- Registra um submódulo do LKS no histórico interno de boot.
---
--- **Exemplo:**
--- ```lua
--- LKS_EletricidadeConstrucao.RegisterModule("Core.Namespace", "2.0")
--- ```
---
--- @param moduleName string O nome técnico do submódulo (ex: "Core.Namespace").
--- @param version string A versão técnica do submódulo (opcional).
function LKS_EletricidadeConstrucao.RegisterModule(moduleName, version)
    LKS_EletricidadeConstrucao._LoadedModules[moduleName] = {
        name = moduleName,
        version = version or "unknown",
        loadedAt = os.time()
    }
    print(string.format("[LKS_EletricidadeConstrucao] Módulo carregado: %s (v%s)", moduleName, version or "unknown"))
end

--- Verifica se um determinado submódulo do LKS já foi carregado e registrado.
---
--- @param moduleName string O nome técnico do submódulo a ser verificado.
--- @return boolean Retorna true se o módulo já foi registrado no bootstrap.
function LKS_EletricidadeConstrucao.IsModuleLoaded(moduleName)
    return LKS_EletricidadeConstrucao._LoadedModules[moduleName] ~= nil
end

--- Retorna uma lista contendo os nomes de todos os submódulos registrados no mod.
---
--- @return table Array indexado de strings contendo os nomes dos submódulos carregados.
function LKS_EletricidadeConstrucao.GetLoadedModules()
    local modules = {}
    for name, _ in pairs(LKS_EletricidadeConstrucao._LoadedModules) do
        table.insert(modules, name)
    end
    return modules
end

-- ============================================================================
-- FUNÇÕES DE SAÍDA DE LOG (LOGGER INTERNO)
-- ============================================================================

--- Imprime uma mensagem formatada no console com o prefixo do mod.
---
--- @param message string O texto a ser impresso no log.
--- @param level? string O nível do log (ex: "INFO", "WARN", "ERROR", "DEBUG") (opcional, padrão: "INFO").
function LKS_EletricidadeConstrucao.Print(message, level)
    level = level or "INFO"
    print(string.format("[LKS_EletricidadeConstrucao][%s] %s", level, message))
end

--- Imprime uma mensagem de erro no console do jogo.
---
--- @param message string O texto explicativo do erro técnico.
function LKS_EletricidadeConstrucao.Error(message)
    LKS_EletricidadeConstrucao.Print(message, "ERROR")
end

--- Imprime uma mensagem de aviso/alerta no console do jogo.
---
--- @param message string O texto explicativo do aviso.
function LKS_EletricidadeConstrucao.Warn(message)
    LKS_EletricidadeConstrucao.Print(message, "WARN")
end

--- Imprime uma mensagem de debug se o modo debug estiver ativo no sandbox do mod.
---
--- @param message string O texto a ser impresso apenas para desenvolvedores.
function LKS_EletricidadeConstrucao.Debug(message)
    if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
        LKS_EletricidadeConstrucao.Print(message, "DEBUG")
    end
end

-- ============================================================================
-- CONCLUSÃO DA INICIALIZAÇÃO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Core.Namespace", LKS_EletricidadeConstrucao.VERSION)
LKS_EletricidadeConstrucao.Print(string.format("Namespace inicializado - Versão %s (%s)", 
    LKS_EletricidadeConstrucao.VERSION, LKS_EletricidadeConstrucao.BUILD_DATE))

return LKS_EletricidadeConstrucao
