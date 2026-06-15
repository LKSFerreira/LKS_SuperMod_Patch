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

-- ARQUIVO: LKS_EletricidadeConstrucao_Constants.lua
-- OBJETIVO: Centralização de constantes globais, limites físicos e valores mágicos do mod.
-- DETALHE TÉCNICO: Este arquivo contém apenas dados estáticos estruturados em tabelas Lua, sem lógica executável.
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace principal existe
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Constants] Namespace LKS_EletricidadeConstrucao não encontrado - abortando carregamento do módulo")
    return
end

-- ============================================================================
-- CHAVES DE PERSISTÊNCIA (ModData)
-- ============================================================================
-- Chaves usadas para ler e gravar dados persistentes no arquivo de save do jogo.
LKS_EletricidadeConstrucao.Constants.MODDATA_KEYS = {
    -- Dados de Geradores
    GENERATOR_PREFIX = "LKS_EletricidadeConstrucao_Generator_",        -- Prefixo para as tabelas individuais de cada gerador
    GENERATOR_LIST = "LKS_EletricidadeConstrucao_GeneratorList",       -- Lista de todos os geradores cadastrados no mapa
    
    -- Dados de Construções
    BUILDING_PREFIX = "LKS_EletricidadeConstrucao_Building_",          -- Prefixo para dados de cada edifício detectado
    BUILDING_LIST = "LKS_EletricidadeConstrucao_BuildingList",         -- Lista de todos os edifícios vinculados à rede
    
    -- Dados Gerais do Estado
    STATE_VERSION = "LKS_EletricidadeConstrucao_StateVersion",         -- Versão da estrutura do banco de dados (schema)
    GLOBAL_STATE = "LKS_EletricidadeConstrucao_GlobalState",           -- Tabela de estado global do mod
    
    -- Dados Legados (Compatibilidade e migração de saves da V1)
    LEGACY_BUILDING_DATA = "ConnectedBuildingsData",
    LEGACY_CONSUMER_DATA = "PoweredConsumers"
}

-- ============================================================================
-- NOMES DOS EVENTOS CUSTOMIZADOS
-- ============================================================================
-- Identificadores textuais para os canais de disparo e escuta de eventos internos (Event Bus).
LKS_EletricidadeConstrucao.Constants.EVENTS = {
    -- Eventos Lógicos
    GENERATOR_CONNECTED = "LKS_EletricidadeConstrucao_GeneratorConnected",
    GENERATOR_DISCONNECTED = "LKS_EletricidadeConstrucao_GeneratorDisconnected",
    GENERATOR_ACTIVATED = "LKS_EletricidadeConstrucao_GeneratorActivated",
    GENERATOR_DEACTIVATED = "LKS_EletricidadeConstrucao_GeneratorDeactivated",
    GENERATOR_FUEL_CHANGED = "LKS_EletricidadeConstrucao_GeneratorFuelChanged",
    GENERATOR_FUEL_EMPTY = "LKS_EletricidadeConstrucao_GeneratorFuelEmpty",
    
    BUILDING_POWER_CHANGED = "LKS_EletricidadeConstrucao_BuildingPowerChanged",
    BUILDING_SCANNED = "LKS_EletricidadeConstrucao_BuildingScanned",
    
    CONSUMER_ADDED = "LKS_EletricidadeConstrucao_ConsumerAdded",
    CONSUMER_REMOVED = "LKS_EletricidadeConstrucao_ConsumerRemoved",
    
    -- Eventos de Rede (Comunicação Cliente/Servidor no Multiplayer)
    SERVER_CMD_SYNC_STATE = "LKS_EletricidadeConstrucao_SyncState",
    SERVER_CMD_UPDATE_FUEL = "LKS_EletricidadeConstrucao_UpdateFuel",
    SERVER_CMD_TOGGLE_POWER = "LKS_EletricidadeConstrucao_TogglePower"
}

-- ============================================================================
-- CONSUMO DE COMBUSTÍVEL E CARGA ELÉTRICA (FÍSICA DO MOD)
-- ============================================================================
LKS_EletricidadeConstrucao.Constants.FUEL = {
    -- Frequências de atualização
    UPDATE_INTERVAL = 1000,                     -- Intervalo de atualização do combustível em milissegundos (1 segundo)
    CHUNK_RELOAD_MIN_HOURS = 0.033,             -- Tempo mínimo (2 minutos de jogo) para acionar o recalculo retroativo ao carregar um chunk

    -- Taxas base de consumo (L/h = Litros por hora de jogo)
    BASE_CONSUMPTION_RATE = 0.02,               -- Consumo base do motor por segundo (porcentagem do tanque)
    CONSUMPTION_RATE_PER_CONSUMER_LPH = 0.004,  -- [OBSOLETO] Substituído por taxas individuais abaixo
    
    -- Consumo do Sistema de Aquecimento (Reduzido em 4x para fins de balanceamento)
    CONSUMPTION_RATE_HEATING_PER_SOURCE_LPH = 0.002,     -- Consumo em L/h por termostato/fonte ativa a 20°C
    CONSUMPTION_RATE_HEATING_PER_DEGREE_LPH = 0.00025,    -- Consumo adicional em L/h por grau Celsius acima de 20°C (ex: 30°C = +0.005 L/h por fonte)

    -- Consumo em Standby / Inatividade
    CONSUMPTION_IDLE_LPH = 0.002,              -- Consumo em L/h do gerador ligado sem nenhum aparelho conectado

    -- Taxas de Consumo Vanilla dos Aparelhos Ativos (L/h por aparelho)
    CONSUMPTION_LIGHT_LPH = 0.002,              -- Lâmpadas, interruptores e luminárias de parede
    CONSUMPTION_RADIO_LPH = 0.01,               -- Rádio amador ou comercial ativo
    CONSUMPTION_TV_LPH = 0.03,                  -- Televisores ativos
    CONSUMPTION_STOVE_LPH = 0.045,              -- Fogões e fornos domésticos ligados
    CONSUMPTION_FRIDGE_LPH = 0.08,              -- Refrigeradores (geladeira simples)
    CONSUMPTION_FREEZER_LPH = 0.08,             -- Congeladores (freezer simples)
    CONSUMPTION_FRIDGE_FREEZER_LPH = 0.13,      -- Geladeiras duplex (geladeira + freezer combinados)
    CONSUMPTION_WASHER_LPH = 0.09,              -- Lavadoras de roupas em ciclo ativo
    CONSUMPTION_DRYER_LPH = 0.09,               -- Secadoras de roupas em ciclo ativo
    CONSUMPTION_MICROWAVE_LPH = 0.065,          -- Fornos micro-ondas ativos
    CONSUMPTION_APPLIANCE_DEFAULT_LPH = 0.04,   -- Valor genérico para aparelhos não classificados

    -- Carga Elétrica por tipo de consumidor (usada para calcular o Strain/Sobrecarga do gerador)
    POWER_DRAW_LIGHT = 1.5,                     -- Lâmpada de teto padrão
    POWER_DRAW_LAMP = 1.5,                      -- Luminária móvel ou abajur
    POWER_DRAW_APPLIANCE = 8.0,                 -- Carga padrão para aparelhos não classificados

    -- Carga de Aparelhos Específicos
    POWER_DRAW_RADIO = 8.0,                     -- Rádio
    POWER_DRAW_TV = 12.0,                       -- Televisão
    POWER_DRAW_MICROWAVE = 14.0,                -- Micro-ondas
    POWER_DRAW_STOVE = 21.0,                    -- Fogão/Forno
    POWER_DRAW_WASHER = 27.0,                   -- Máquina de lavar roupas
    POWER_DRAW_DRYER = 25.0,                    -- Secadora de roupas
    POWER_DRAW_FRIDGE = 15.0,                   -- Geladeira simples
    POWER_DRAW_FREEZER = 15.0,                  -- Freezer simples
    POWER_DRAW_FRIDGE_FREEZER = 20.0,           -- Geladeira duplex
    BASE_LOAD_CAPACITY = 120.0,                  -- Capacidade base de carga (um gerador suporta ~120 de carga antes de sobrecarga)

    -- Mecânicas de Sobrecarga (Strain) e Danos Tiered
    BASE_STRAIN_PER_LIGHT = 0.83333333333333,   -- [OBSOLETO] Espelhamento legado para BASE_LOAD_CAPACITY (100 / 120)
    STRAIN_MODIFIER = 0.01,                     -- [OBSOLETO] Substituído pelo sistema progressivo (Tiered)
    MAX_STRAIN_MULTIPLIER = 3.0,                -- Multiplicador máximo de consumo de combustível (3.0x a 200% de sobrecarga)

    -- Limites de Sobrecarga (Sistema Progressivo)
    -- 0-50%:   Eficiência perfeita. Consumo normal de combustível (1.0x).
    -- 51-75%:  Consumo de 1.0x a 1.25x (1-25% extra), sem danos ao motor.
    -- 76-100%: Consumo de 1.26x a 1.75x (26-75% extra), sem danos ao motor.
    -- 101-200%: Consumo de 1.76x a 3.0x + danos na condição do motor após 1h + risco de incêndio.
    STRAIN_SAFE_ZONE = 50,                      -- Zona de segurança (sem penalidades abaixo de 50%)
    STRAIN_THRESHOLD_LOW = 25,                  -- Sobrecarga baixa
    STRAIN_THRESHOLD_MEDIUM = 50,               -- Sobrecarga média
    STRAIN_THRESHOLD_HIGH = 75,                 -- Sobrecarga alta
    OVERLOAD_THRESHOLD = 100,                   -- Sobrecarga crítica (Overload >= 100%)

    -- Perda de Eficiência do Gerador
    EFFICIENCY_LOSS_RATE = 0.5,                 -- Perda de eficiência por ponto percentual de sobrecarga
    MIN_EFFICIENCY = 25,                        -- Eficiência mínima garantida de 25%

    -- Falha Crítica por Sobrecarga
    OVERLOAD_FAILURE_RATE = 0.01                -- 1% de chance de quebra catastrófica por ponto percentual acima de 100%
}

-- Modificadores de Consumo de Geradores customizados/importados de outros mods
LKS_EletricidadeConstrucao.Constants.GENERATOR_TYPES = {
    MODIFIERS = {
        appliances_misc_01_12 = { fuel = 0.95, strain = 1.00 },
        appliances_misc_01_8  = { fuel = 1.05, strain = 0.90 },
        appliances_misc_01_4  = { fuel = 1.20, strain = 0.80 },
    }
}

-- ============================================================================
-- VARREDURA E DETECÇÃO DE EDIFÍCIOS
-- ============================================================================
LKS_EletricidadeConstrucao.Constants.BUILDING = {
    -- Parâmetros geométricos
    MAX_SCAN_RADIUS = 100,                     -- Raio máximo em quadrados (tiles) para associar geradores a paredes
    BORDER_DETECTION_RADIUS = 2,               -- Margem em quadrados fora das paredes para detectar luzes externas do prédio
    MAX_ROOMS_PER_BUILDING = 250,               -- Limite máximo de salas por construção para evitar loops infinitos em mega-bases
    
    -- Limites de desempenho (performance budgets)
    MAX_CONSUMERS_PER_BUILDING = 500,          -- Quantidade máxima de aparelhos rastreados em um único prédio
    MAX_GENERATORS_PER_BUILDING = 10,          -- Quantidade máxima de geradores associados ao mesmo prédio
    SCAN_THROTTLE_MS = 50,                     -- Tempo limite em milissegundos para concluir uma varredura por frame de jogo
    
    -- Limites de andares (Z-level)
    MIN_Z_LEVEL = 0,                           -- Térreo
    MAX_Z_LEVEL = 8,                           -- Nível máximo de andares suportado pelo PZ
    
    -- Compatibilidade com o mod "RV Interior"
    RV_INTERIOR_MIN_COORD = -100000,           -- Coordenada inicial do mapa de interiores de trailers
    RV_INTERIOR_MAX_COORD = 200000             -- Coordenada final do mapa de interiores
}

-- ============================================================================
-- INTERFACE GRÁFICA (UI)
-- ============================================================================
LKS_EletricidadeConstrucao.Constants.UI = {
    -- Tamanhos padrões das janelas
    INFO_WINDOW_WIDTH = 400,
    INFO_WINDOW_HEIGHT = 350,
    INFO_WINDOW_MIN_WIDTH = 300,
    INFO_WINDOW_MIN_HEIGHT = 250,
    
    -- Taxas de atualização de frames
    UI_UPDATE_INTERVAL_MS = 100,               -- Frequência de atualização de dados da janela (milissegundos)
    REALTIME_LIGHT_UPDATE_MS = 100,            -- Frequência de atualização do contador de lâmpadas ativas
    
    -- Cores da Interface (Formatadas em escalas RGBA de 0.0 a 1.0)
    COLOR_NORMAL = {r=1.0, g=1.0, b=1.0, a=1.0},
    COLOR_WARNING = {r=1.0, g=0.8, b=0.0, a=1.0},
    COLOR_CRITICAL = {r=1.0, g=0.2, b=0.0, a=1.0},
    COLOR_SUCCESS = {r=0.0, g=1.0, b=0.0, a=1.0},
    COLOR_DISABLED = {r=0.5, g=0.5, b=0.5, a=0.7}
}

-- ============================================================================
-- SINCRONIZAÇÃO DE REDE (MULTIPLAYER)
-- ============================================================================
LKS_EletricidadeConstrucao.Constants.NETWORK = {
    MODULE_NAME = "LKS_EletricidadeConstrucao", -- Nome identificador do canal de rede cliente/servidor
    
    -- Intervalos de sincronização (Minutos de jogo)
    FULL_SYNC_INTERVAL = 30,                   -- Sincronização completa de ModData a cada 30 minutos de jogo
    DELTA_SYNC_INTERVAL = 1,                   -- Envio de pequenas deltas (mudanças rápidas) a cada 1 minuto de jogo
    
    -- Limitação de banda (performance de conexões móveis ou instáveis)
    MAX_SYNC_BATCH_SIZE = 50,                  -- Quantidade máxima de itens por pacote de rede enviado
    SYNC_THROTTLE_MS = 100                     -- Atraso em milissegundos entre o envio de lotes de pacotes
}

-- ============================================================================
-- SISTEMA DE AQUECIMENTO E TERMOCLIMATIZAÇÃO
-- ============================================================================
LKS_EletricidadeConstrucao.Constants.HEATING = {
    -- Temperaturas base (Celsius)
    TARGET_TEMPERATURE = 18.0,                 -- Temperatura considerada agradável/confortável
    MIN_TEMPERATURE = -10.0,                   -- Limite inferior de temperatura externa para cálculos
    MAX_TEMPERATURE = 35.0,                    -- Limite superior de temperatura externa para cálculos
    
    -- Consumo elétrico (por sala/quarto de edifício por hora de jogo)
    HEATING_POWER_PER_ROOM = 0.5,              -- Carga elétrica padrão necessária para aquecer uma sala de tamanho normal
    
    -- Fatores de Isolamento Térmico (Baseados em paredes, tetos e janelas do cômodo)
    INSULATION_NONE = 0.5,                     -- Sem isolamento/Paredes abertas (50% de eficiência)
    INSULATION_BASIC = 0.75,                   -- Cabanas de madeira simples/Paredes improvisadas (75% de eficiência)
    INSULATION_GOOD = 1.0,                     -- Casas suburbanas com paredes pintadas e rebocadas (100% de eficiência)
    INSULATION_EXCELLENT = 1.25                -- Edifícios fortificados ou salas sem janelas externas (125% de eficiência)
}

-- ============================================================================
-- DIRETRIZES DE DESENVOLVIMENTO (INFORMAÇÕES DE MÉTRICAS)
-- ============================================================================
LKS_EletricidadeConstrucao.Constants.DEVELOPMENT = {
    -- Diretrizes de tamanho de arquivo (Métricas ideais do projeto)
    TARGET_FILE_SIZE_LINES = 300,              -- Quantidade de linhas sugerida por arquivo Lua
    WARNING_FILE_SIZE_LINES = 400,             -- Arquivo grande, requer atenção
    CRITICAL_FILE_SIZE_LINES = 500,            -- Recomenda-se fortemente dividir em sub-arquivos
    
    -- Orçamento de tempo máximo por frame de jogo
    MAX_FRAME_TIME_MS = 1.0,                   -- Tempo máximo permitido para execução das lógicas de update
    MAX_SCAN_TIME_MS = 50.0                    -- Tempo máximo permitido para conclusão do scan de construções grandes
}

-- ============================================================================
-- CLASSES E OBJETOS RECONHECIDOS NA VARREDURA (CONSUMIDORES)
-- ============================================================================
LKS_EletricidadeConstrucao.Constants.ITEM_TYPES = {
    -- Fontes de luz internas e externas
    LIGHTS = {
        "IsoLightSwitch"                       -- Interruptores de luz nativos do mapa
    },
    
    -- Eletrodomésticos estruturais
    APPLIANCES = {
        "IsoStove",
        "IsoWaterDispenser",
        "IsoWaveSignal",
        "IsoRadio",
        "IsoTelevision",
        "(IsoClothingWasher|Dryer)",          -- Regex para identificar combos de lavanderia
        "IsoClothingWasher",
        "IsoClothingDryer"
        -- Nota: Contêineres de geladeiras e freezers são detectados dinamicamente via inventário (ContainerType),
        -- não dependendo diretamente das strings Java listadas aqui.
    },
    
    -- Barris de Gasolina reconhecidos no mundo
    BARRELS = {
        "BarrelGreen",
        "BarrelYard",
        "BarrelIndustrial"
    }
}

-- ============================================================================
-- CONFIGURAÇÕES DE DEPURADOR (DEBUG)
-- ============================================================================
LKS_EletricidadeConstrucao.Constants.DEBUG = {
    -- Categorias de logs verbosos no console
    LOG_FUEL_CONSUMPTION = false,
    LOG_BUILDING_SCAN = false,
    LOG_CHUNK_RELOAD = false,
    LOG_NETWORK_SYNC = false,
    LOG_UI_UPDATES = false,
    LOG_STATE_CHANGES = false,
    
    -- Renderizações e representações visuais em tela
    SHOW_COVERAGE_AREA = false,                -- Desenha blocos verdes indicando a área sob cobertura de energia
    SHOW_CHUNK_BOUNDARIES = false,             -- Desenha a grelha de limites dos chunks (10x10 tiles)
    SHOW_SCAN_RADIUS = false                   -- Desenha círculos indicando o raio de varredura do gerador
}

-- ============================================================================
-- CONCLUSÃO DA INICIALIZAÇÃO
-- ============================================================================

LKS_EletricidadeConstrucao._InitStatus.ConstantsLoaded = true
LKS_EletricidadeConstrucao.RegisterModule("Constants", "2.0.0")

LKS_EletricidadeConstrucao.Print(string.format("Constantes carregadas (%d categorias)", 12))

return LKS_EletricidadeConstrucao.Constants
