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

-- ARQUIVO: LKS_EletricidadeConstrucao_Config.lua
-- OBJETIVO: Gerenciamento de preferências dinâmicas, variáveis do sandbox e persistência das opções do mod.
-- DETALHE TÉCNICO: Lê as variáveis definidas no sandbox do servidor e sincroniza com os clientes conectados via ModData.
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace principal existe
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Config] Namespace LKS_EletricidadeConstrucao nao encontrado - abortando carregamento do modulo")
    return
end

local FuelConstants = LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.FUEL or {}
local BuildingConstants = LKS_EletricidadeConstrucao.Constants and LKS_EletricidadeConstrucao.Constants.BUILDING or {}

-- ============================================================================
-- PREFERÊNCIAS E CONFIGURAÇÕES PADRÃO
-- ============================================================================
-- Estes valores servem como fallback e serão sobrescritos pelas SandboxVars do mundo.
LKS_EletricidadeConstrucao.Config = {
    -- ========================================================================
    -- PARÂMETROS GERAIS
    -- ========================================================================
    ModEnabled = true,                         -- Chave mestre de ativação do mod (Eletricidade Realista)
    DebugMode = false,                         -- Modo depuração (logs verbosos e overlays)
    ShowNotifications = true,                  -- Exibe alertas rápidos na tela do jogador
    RefrigerationEnabled = true,               -- Integração nativa do driver de refrigeração LKS
    LaundryEnabled = true,                     -- Integração nativa do driver de lavanderia LKS
    CookingEnabled = true,                     -- Integração nativa do driver de culinária LKS
    
    -- ========================================================================
    -- CONSUMO DE COMBUSTÍVEL
    -- ========================================================================
    FuelConsumptionEnabled = true,             -- Ativa o consumo de combustível customizado
    FuelConsumptionRate = 1.0,                 -- Multiplicador global de consumo de gasolina
    RealisticFuelConsumption = true,           -- Ativa a curva física de consumo baseado na sobrecarga (strain)
    ChunkReloadTracking = true,                -- Rastreia o tempo decorrido enquanto a região (chunk) esteve descarregada
    
    -- Mecânica de Sobrecarga (Strain)
    StrainSystemEnabled = true,                -- Ativa danos e penalidades de eficiência por sobrecarga
    StrainModifier = 0.01,                     -- Fator multiplicador de combustível por ponto de sobrecarga
    StrainEfficiencyPenalty = true,            -- Penaliza o rendimento em sobrecargas críticas
    OverloadFailureEnabled = false,            -- Geradores podem explodir/pegar fogo em sobrecarga contínua
    BaseLoadCapacity = FuelConstants.BASE_LOAD_CAPACITY or 120.0,
    
    -- ========================================================================
    -- VARREDURA DE CONSTRUÇÃO
    -- ========================================================================
    AutoDetectBuildings = true,                -- Varre automaticamente o mapa buscando cômodos e edifícios
    MaxScanRadius = 50,                        -- Raio máximo de quadrados para a varredura
    BorderRadius = 2,                          -- Distância fora das paredes para englobar lâmpadas externas
    MultiFloorSupport = true,                  -- Rastreia múltiplos andares do mesmo edifício
    
    -- Otimização e Desempenho (Performance Budgets)
    ScanThrottling = true,                     -- Divide a busca em vários frames para evitar travamentos de tela (stuttering)
    MaxScansPerFrame = 5,                      -- Quantidade máxima de varreduras simultâneas permitidas
    MaxConsumersPerBuilding = BuildingConstants.MAX_CONSUMERS_PER_BUILDING or 500,
    MaxGeneratorsPerBuilding = BuildingConstants.MAX_GENERATORS_PER_BUILDING or 10,
    
    -- ========================================================================
    -- SISTEMA DE AQUECIMENTO (TERMOCLIMATIZAÇÃO)
    -- ========================================================================
    HeatingSystemEnabled = false,              -- O aquecimento realista é recomendado primariamente para partidas solo (SP)
    TargetTemperature = 18.0,                  -- Temperatura de conforto desejada em ambientes fechados
    HeatingPowerCost = 1.0,                    -- Multiplicador de consumo de carga do sistema de aquecimento
    InsulationEnabled = true,                  -- Leva em conta o isolamento térmico das paredes da sala
    
    -- ========================================================================
    -- INTERFACE (UI)
    -- ========================================================================
    ShowInfoWindow = true,                     -- Habilita a janela de informações elétricas ao interagir
    ShowCoverageArea = false,                  -- Desenha indicadores visuais no chão da cobertura do gerador
    RealtimeLightCount = true,                 -- Atualiza em tempo real o contador de lâmpadas
    ShowStrainIndicator = true,                -- Exibe a barra de sobrecarga gráfica na janela
    
    UIUpdateRate = 100,                        -- Frequência de redesenho da interface (milissegundos)
    ShowFuelPercentage = true,                 -- Exibe combustível restante em porcentagem simples
    ShowConsumerCount = true,                  -- Exibe a quantidade de aparelhos ligados na rede
    
    -- ========================================================================
    -- CONFIGURAÇÕES DE REDE (MULTIPLAYER)
    -- ========================================================================
    NetworkSyncEnabled = true,                 -- Habilita a sincronização do estado com os clientes
    FullSyncInterval = 30,                     -- Intervalo para sincronização completa de dados (minutos de jogo)
    DeltaSyncInterval = 1,                     -- Intervalo para envio de alterações rápidas (minutos de jogo)
    BatchNetworkUpdates = true,                -- Agrupa atualizações para economizar pacotes de rede
    
    -- ========================================================================
    -- COMPATIBILIDADE E MODS PARCEIROS
    -- ========================================================================
    RVInteriorCompatibility = true,            -- Ativa suporte de coordenadas para o mod RV Interior
    VanillaGeneratorOverride = false,          -- Sobrescreve as mecânicas internas de geradores da própria engine do PZ
    ModdedGeneratorSupport = true,             -- Detecta geradores adicionados por outros mods da oficina
    
    -- ========================================================================
    -- BARRIS DE REABASTECIMENTO
    -- ========================================================================
    BarrelSystemEnabled = true,                -- Habilita a vinculação de barris ao reservatório
    AutoRefuelFromBarrels = true,              -- Transfere gasolina dos barris para o gerador de forma autônoma
    MaxBarrelsPerGenerator = 10,               -- Limite de barris vinculados por gerador
    BarrelRefuelRate = 10.0,                   -- Unidades de gasolina transferidas por hora de jogo
    
    -- ========================================================================
    -- SISTEMAS AVANÇADOS
    -- ========================================================================
    StateVersion = 2.0,                        -- Versão da estrutura de dados salva no ModData
    EnableLegacyMigration = true,              -- Ativa migração de banco de dados da V1 antiga
    PerformanceMode = false,                   -- Desativa lógicas pesadas visando computadores mais fracos
    
    -- Categorias de logs detalhados para desenvolvedores
    DebugCategories = {
        FuelConsumption = false,
        BuildingDetection = false,
        NetworkSync = false,
        UIUpdates = false
    }
}

--- Atualiza as constantes base da física de simulação baseando-se nos valores do Sandbox.
local function ApplySandboxBackedConstants()
    local constants = LKS_EletricidadeConstrucao.Constants
    local config = LKS_EletricidadeConstrucao.Config
    if not constants or not config then
        return
    end

    constants.FUEL = constants.FUEL or {}
    constants.BUILDING = constants.BUILDING or {}

    constants.FUEL.BASE_LOAD_CAPACITY = config.BaseLoadCapacity
    if config.BaseLoadCapacity and config.BaseLoadCapacity > 0 then
        constants.FUEL.BASE_STRAIN_PER_LIGHT = 100 / config.BaseLoadCapacity
    end

    constants.BUILDING.MAX_CONSUMERS_PER_BUILDING = config.MaxConsumersPerBuilding
    constants.BUILDING.MAX_GENERATORS_PER_BUILDING = config.MaxGeneratorsPerBuilding
end

-- ============================================================================
-- SESSÃO DE MÉTODOS DE CONFIGURAÇÃO
-- ============================================================================

--- Carrega as configurações de jogo a partir das SandboxVars definidas no mundo/servidor.
---
--- Chamado no bootstrap do mod para sobrescrever os valores estáticos locais.
function LKS_EletricidadeConstrucao.Config.LoadFromSandbox()
    local sandboxOptions = SandboxVars
    
    if not sandboxOptions then
        LKS_EletricidadeConstrucao.Warn("Opções do SandboxVars indisponíveis, utilizando configurações padrão do código")
        return
    end
    
    local sb = sandboxOptions.LKS_EletricidadeConstrucao or {}

    if sb.EletricidadeRealistaEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.ModEnabled = sb.EletricidadeRealistaEnabled
    end

    if sb.DebugToolsEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.DebugMode = sb.DebugToolsEnabled
    end

    if sb.BarrelSystemEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.BarrelSystemEnabled = sb.BarrelSystemEnabled
        LKS_EletricidadeConstrucao.Config.AutoRefuelFromBarrels = sb.BarrelSystemEnabled
    end

    if sb.RefrigerationEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.RefrigerationEnabled = sb.RefrigerationEnabled
    end

    if sb.LaundryEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.LaundryEnabled = sb.LaundryEnabled
    end

    if sb.CookingEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.CookingEnabled = sb.CookingEnabled
    end

    if sb.HeatingSystemEnabled ~= nil then
        LKS_EletricidadeConstrucao.Config.HeatingSystemEnabled = sb.HeatingSystemEnabled
    end

    if sb.HeatRadius ~= nil then
        LKS_EletricidadeConstrucao.Config.HeatRadius = sb.HeatRadius
    end

    if sb.BaseLoadCapacity ~= nil then
        LKS_EletricidadeConstrucao.Config.BaseLoadCapacity = sb.BaseLoadCapacity
    end

    if sb.MaxConsumersPerBuilding ~= nil then
        LKS_EletricidadeConstrucao.Config.MaxConsumersPerBuilding = sb.MaxConsumersPerBuilding
    end

    if sb.MaxGeneratorsPerBuilding ~= nil then
        LKS_EletricidadeConstrucao.Config.MaxGeneratorsPerBuilding = sb.MaxGeneratorsPerBuilding
    end

    ApplySandboxBackedConstants()
    
    LKS_EletricidadeConstrucao.Print("Opcoes de configuracao sincronizadas com o SandboxVars")
end

--- Salva as configurações locais no ModData global do mundo (Apenas no Servidor/Host).
---
--- Sincroniza a tabela de preferências enviando pacotes ModData.transmit() para os clientes.
---
--- @param key string Opcional: A chave de configuração individual (salva apenas o valor correspondente).
function LKS_EletricidadeConstrucao.Config.SaveToModData(key)
    if not LKS_EletricidadeConstrucao.IsServer() then
        LKS_EletricidadeConstrucao.Warn("Config.SaveToModData requisitada em um cliente local - ignorando")
        return
    end
    
    if key then
        ModData.add("LKS_EletricidadeConstrucao_Config_" .. key, LKS_EletricidadeConstrucao.Config[key])
    else
        ModData.add("LKS_EletricidadeConstrucao_ConfigData", LKS_EletricidadeConstrucao.Config)
    end
    
    if LKS_EletricidadeConstrucao.IsMP() then
        ModData.transmit("LKS_EletricidadeConstrucao_ConfigData")
    end
end

--- Reconstrói e mescla as preferências locais a partir do ModData compartilhado (Clientes e Saves carregados).
function LKS_EletricidadeConstrucao.Config.LoadFromModData()
    local savedConfig = ModData.get("LKS_EletricidadeConstrucao_ConfigData")
    
    if savedConfig then
        for key, value in pairs(savedConfig) do
            if LKS_EletricidadeConstrucao.Config[key] ~= nil then
                LKS_EletricidadeConstrucao.Config[key] = value
            end
        end
        LKS_EletricidadeConstrucao.Print("Opcoes de configuracao mescladas a partir do ModData")
    end
end

--- Reseta todas as chaves de configuração locais para as definições de código estático (Defaults).
function LKS_EletricidadeConstrucao.Config.ResetToDefaults()
    LKS_EletricidadeConstrucao.Warn("Resetando preferências de configuração para os padrões estáticos")
    require("LKS_EletricidadeConstrucao_Config")
end

--- Executa uma validação preventiva de limites físicos nas chaves numéricas da tabela de preferências.
--- Clampa valores bizarros ou perigosos configurados fora da faixa suportada para evitar estouros ou crashes.
function LKS_EletricidadeConstrucao.Config.Validate()
    local config = LKS_EletricidadeConstrucao.Config
    local warnings = 0
    
    if config.FuelConsumptionRate < 0.1 or config.FuelConsumptionRate > 10.0 then
        LKS_EletricidadeConstrucao.Warn("FuelConsumptionRate fora dos limites seguros (0.1 a 10.0), clampando")
        config.FuelConsumptionRate = math.max(0.1, math.min(10.0, config.FuelConsumptionRate))
        warnings = warnings + 1
    end
    
    if config.MaxScanRadius < 10 or config.MaxScanRadius > 200 then
        LKS_EletricidadeConstrucao.Warn("MaxScanRadius fora dos limites seguros (10 a 200), clampando")
        config.MaxScanRadius = math.max(10, math.min(200, config.MaxScanRadius))
        warnings = warnings + 1
    end
    
    if config.TargetTemperature < -20 or config.TargetTemperature > 40 then
        LKS_EletricidadeConstrucao.Warn("TargetTemperature fora dos limites seguros (-20 a 40), clampando")
        config.TargetTemperature = math.max(-20, math.min(40, config.TargetTemperature))
        warnings = warnings + 1
    end

    if config.BaseLoadCapacity < 20 or config.BaseLoadCapacity > 500 then
        LKS_EletricidadeConstrucao.Warn("BaseLoadCapacity fora dos limites seguros (20 a 500), clampando")
        config.BaseLoadCapacity = math.max(20, math.min(500, config.BaseLoadCapacity))
        warnings = warnings + 1
    end

    if config.MaxConsumersPerBuilding < 50 or config.MaxConsumersPerBuilding > 5000 then
        LKS_EletricidadeConstrucao.Warn("MaxConsumersPerBuilding fora dos limites seguros (50 a 5000), clampando")
        config.MaxConsumersPerBuilding = math.max(50, math.min(5000, config.MaxConsumersPerBuilding))
        warnings = warnings + 1
    end

    if config.MaxGeneratorsPerBuilding < 1 or config.MaxGeneratorsPerBuilding > 50 then
        LKS_EletricidadeConstrucao.Warn("MaxGeneratorsPerBuilding fora dos limites seguros (1 a 50), clampando")
        config.MaxGeneratorsPerBuilding = math.max(1, math.min(50, config.MaxGeneratorsPerBuilding))
        warnings = warnings + 1
    end

    ApplySandboxBackedConstants()
    
    if warnings > 0 then
        LKS_EletricidadeConstrucao.Warn(string.format("Validador de Configuração encontrou %d aviso(s) de ajuste", warnings))
    else
        LKS_EletricidadeConstrucao.Debug("Validador de Configuração executado com sucesso e zero inconformidades")
    end
end

-- ============================================================================
-- CONCLUSÃO DA INICIALIZAÇÃO
-- ============================================================================

LKS_EletricidadeConstrucao._InitStatus.ConfigLoaded = true
LKS_EletricidadeConstrucao.RegisterModule("Config", "2.0.0")

LKS_EletricidadeConstrucao.Config.Validate()

LKS_EletricidadeConstrucao.Print("Modulo de Configuracao inicializado")

return LKS_EletricidadeConstrucao.Config
