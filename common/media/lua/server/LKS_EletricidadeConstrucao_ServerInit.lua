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

-- ARQUIVO: LKS_EletricidadeConstrucao_ServerInit.lua
-- OBJETIVO: Inicialização do lado do servidor e gerenciamento dos eventos periódicos.
-- LOCALIZAÇÃO: server

if not LKS_EletricidadeConstrucao then
    print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerInit.lua] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

if LKS_EletricidadeConstrucao.Config and not LKS_EletricidadeConstrucao.Config.ModEnabled then
    print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerInit.lua] Eletricidade realista desativada no sandbox - pulando modulo")
    return
end

-- ============================================================================
-- CARREGAMENTO DE MÓDULOS DO SERVIDOR
-- ============================================================================

local modulosServidor = {
    "server/fuel/LKS_EletricidadeConstrucao_Fuel_StrainCalculator",
    "server/fuel/LKS_EletricidadeConstrucao_Fuel_Manager",
    "server/fuel/LKS_EletricidadeConstrucao_Fuel_ChunkTracker",
    "server/building/LKS_EletricidadeConstrucao_Building_BorderDetector",
    "server/building/LKS_EletricidadeConstrucao_Building_ConsumerScanner",
    "server/building/LKS_EletricidadeConstrucao_Building_Scanner",
    "server/power/LKS_EletricidadeConstrucao_Power_Manager",
    "server/power/LKS_EletricidadeConstrucao_Power_Distributor",
    "server/LKS_EletricidadeConstrucao_ServerCommands",
}

if not LKS_EletricidadeConstrucao.Config or LKS_EletricidadeConstrucao.Config.HeatingSystemEnabled then
    table.insert(modulosServidor, "server/heating/LKS_EletricidadeConstrucao_Heating_Manager")
end

if not LKS_EletricidadeConstrucao.Config or LKS_EletricidadeConstrucao.Config.BarrelSystemEnabled then
    table.insert(modulosServidor, "server/fuel/LKS_EletricidadeConstrucao_Fuel_Barrels")
end

if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
    table.insert(modulosServidor, "server/LKS_EletricidadeConstrucao_DebugCommands")
end

for _, modulo in ipairs(modulosServidor) do
    if package and package.loaded then
        package.loaded[modulo] = nil
    end
    local sucesso, erro = pcall(require, modulo)
    if not sucesso then
        print(string.format("[LKS PATCH - LKS_EletricidadeConstrucao_ServerInit.lua] ERRO ao carregar %s: %s", modulo, tostring(erro)))
    end
end

-- ============================================================================
-- INICIALIZAÇÃO DE SISTEMAS DO SERVIDOR
-- ============================================================================

--- Inicializa todos os subsistemas do lado do servidor.
local function InicializarSistemasServidor()
    LKS_EletricidadeConstrucao.Core.Logger.Info("Inicializando sistemas do servidor...", "Core")
    
    -- Inicializa o gerenciador de estado (carrega o ModData)
    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
        if not LKS_EletricidadeConstrucao.Core.StateManager.IsInitialized() then
            LKS_EletricidadeConstrucao.Core.StateManager.Initialize()
        end
    else
        print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerInit.lua] AVISO: StateManager nao carregado")
    end
    
    -- Inicializa o sistema de combustível
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and LKS_EletricidadeConstrucao.Fuel.Manager.Initialize then
        LKS_EletricidadeConstrucao.Fuel.Manager.Initialize()
    else
        print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerInit.lua] AVISO: Fuel.Manager nao carregado")
    end
    
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.ChunkTracker and LKS_EletricidadeConstrucao.Fuel.ChunkTracker.Initialize then
        LKS_EletricidadeConstrucao.Fuel.ChunkTracker.Initialize()
    else
        print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerInit.lua] AVISO: Fuel.ChunkTracker nao carregado")
    end
    
    -- Inicializa o escaneamento de construções
    if LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner and LKS_EletricidadeConstrucao.Building.Scanner.Initialize then
        LKS_EletricidadeConstrucao.Building.Scanner.Initialize()
    else
        print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerInit.lua] AVISO: Building.Scanner nao carregado")
    end
    
    -- Inicializa a distribuição de energia
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager and LKS_EletricidadeConstrucao.Power.Manager.Initialize then
        LKS_EletricidadeConstrucao.Power.Manager.Initialize()
    else
        print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerInit.lua] AVISO: Power.Manager nao carregado")
    end
    
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.Initialize then
        LKS_EletricidadeConstrucao.Power.Distributor.Initialize()
    else
        print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerInit.lua] AVISO: Power.Distributor nao carregado")
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Sistemas do servidor inicializados", "Core")
    LKS_EletricidadeConstrucao._InitStatus.ServerSystemsInitialized = true
end

-- ============================================================================
-- MANIPULADORES DE EVENTOS
-- ============================================================================

--- Manipula o evento OnGameBoot (chamado uma vez ao iniciar o servidor).
local function AoIniciarJogo()
    LKS_EletricidadeConstrucao.Core.Logger.Info("Servidor iniciando...", "Core")
    
    -- Inicializa os sistemas
    InicializarSistemasServidor()

    -- Atualiza imediatamente as estatísticas de distribuição para que a interface gráfica dos clientes tenha dados no primeiro acesso
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
        LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Inicializacao do servidor concluida", "Core")
end

--- Manipula o evento EveryOneMinute (atualizações de loop periódico).
local function ACadaUmMinuto()
    -- Confirmação de segurança: garante que os sistemas estejam inicializados antes de rodar atualizações
    if not LKS_EletricidadeConstrucao._InitStatus or not LKS_EletricidadeConstrucao._InitStatus.ServerSystemsInitialized then
        return
    end

    local tempoAtual = os.time()

    -- Confirma o ID do mapa e carrega os dados globais do ModData se ainda estiver pendente do boot
    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
            and LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState then
        if LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState() then
            -- Primeiro carregamento confirmado concluído - força a distribuição imediata para a interface refletir o estado correto
            if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
                    and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
                LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
            end
        end
    end

    -- Reabastece automaticamente os geradores a partir de barris acoplados ANTES do consumo de combustível
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels and LKS_EletricidadeConstrucao.Fuel.Barrels.UpdateAll then
        LKS_EletricidadeConstrucao.Fuel.Barrels.UpdateAll()
    end

    -- Atualiza o sistema de combustível (consumo após o abastecimento do barril)
    if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and LKS_EletricidadeConstrucao.Fuel.Manager.Update then
        LKS_EletricidadeConstrucao.Fuel.Manager.Update()
    end
    
    -- Processa a fila de escaneamento de construções
    if LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner and LKS_EletricidadeConstrucao.Building.Scanner.ProcessQueue then
        LKS_EletricidadeConstrucao.Building.Scanner.ProcessQueue()
    end
    
    -- Atualiza conexões de energia (localiza geradores e valida acoplamentos)
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager and LKS_EletricidadeConstrucao.Power.Manager.Update then
        LKS_EletricidadeConstrucao.Power.Manager.Update(tempoAtual)
    end
    
    -- Atualiza a distribuição elétrica (aplica estados elétricos nos contêineres/consumidores)
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.Update then
        LKS_EletricidadeConstrucao.Power.Distributor.Update(tempoAtual)
    end

    -- Tenta executar novamente atualizações de prédios que falharam porque a construção ainda não existia no StateManager
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.ProcessRetryQueue then
        LKS_EletricidadeConstrucao.Power.Distributor.ProcessRetryQueue()
    end

    -- Atualiza o sistema de aquecimento virtual
    if LKS_EletricidadeConstrucao.Heating and LKS_EletricidadeConstrucao.Heating.Manager and LKS_EletricidadeConstrucao.Heating.Manager.Update then
        LKS_EletricidadeConstrucao.Heating.Manager.Update()
    end
end

--- Manipula o evento EveryTenMinutes (salvamento automático com intervalo personalizado de 2 minutos).
local _ultimoSalvamentoAutomatico = 0
local function ACadaDezMinutos()
    local tempoAtual = os.time()
    
    -- Realiza o salvamento automático a cada 2 minutos (120 segundos) em vez de a cada minuto
    if tempoAtual - _ultimoSalvamentoAutomatico >= 120 then
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
            if LKS_EletricidadeConstrucao.Core.StateManager.IsDirty and LKS_EletricidadeConstrucao.Core.StateManager.IsDirty() then
                -- Salva sem criar backups redundantes
                if LKS_EletricidadeConstrucao.Core.StateManager.Save then
                    LKS_EletricidadeConstrucao.Core.StateManager.Save(false, false)
                end
                _ultimoSalvamentoAutomatico = tempoAtual
            end
        end
    end
end

--- Manipula o desligamento do servidor.
local function AoDesligarServidor()
    LKS_EletricidadeConstrucao.Core.Logger.Info("Servidor desligando - salvando estado...", "Core")
    
    -- Força o salvamento crítico com proteção de backup
    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager and LKS_EletricidadeConstrucao.Core.StateManager.Save then
        LKS_EletricidadeConstrucao.Core.StateManager.Save(true, true)
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.Info("Desligamento do servidor concluido", "Core")
end

--- Manipula o evento OnSave regular (salvamento com proteção de backup a cada ~5 minutos).
local function AoSalvar()
    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager and LKS_EletricidadeConstrucao.Core.StateManager.Save then
        LKS_EletricidadeConstrucao.Core.StateManager.Save(true, true)
        LKS_EletricidadeConstrucao.Core.Logger.Debug("AoSalvar: Estado salvo com backup", "Core")
    end
end

-- ============================================================================
-- REGISTRO DE MANIPULADORES DE EVENTOS
-- ============================================================================

if Events.OnGameBoot then Events.OnGameBoot.Add(AoIniciarJogo) end
if Events.EveryOneMinute then Events.EveryOneMinute.Add(ACadaUmMinuto) end
if Events.EveryTenMinutes then Events.EveryTenMinutes.Add(ACadaDezMinutos) end
if Events.OnServerShutdown then Events.OnServerShutdown.Add(AoDesligarServidor) end
if Events.OnSave then Events.OnSave.Add(AoSalvar) end

-- Suporte para Singleplayer (onde OnGameBoot pode não disparar)
if Events.OnGameStart then
    Events.OnGameStart.Add(function()
        if not LKS_EletricidadeConstrucao._InitStatus.ServerSystemsInitialized then
            LKS_EletricidadeConstrucao.Core.Logger.Info("OnGameStart - inicializando sistemas do servidor...", "Core")
            InicializarSistemasServidor()
        end

        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
                and LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState then
            local carregado = LKS_EletricidadeConstrucao.Core.StateManager.ConfirmAndLoadState()
            if carregado then
                if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
                        and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
                    LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
                end
            end
        end

        -- Agenda atualizações pós-inicialização para garantir que os estados ativos dos consumidores se assentem no mapa
        local _tempoLimite1 = getTimestampMs() + 5000
        local _tempoLimite2 = getTimestampMs() + 15000
        local _etapa1Concluida = false
        
        local function _atualizacaoInicial()
            local agora = getTimestampMs()
            if not _etapa1Concluida and agora >= _tempoLimite1 then
                _etapa1Concluida = true
                if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
                    LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
                    LKS_EletricidadeConstrucao.Core.Logger.Info("Atualizacao inicial do estado dos consumidores (etapa 1) concluida", "Core")
                end
            end
            if _etapa1Concluida and agora >= _tempoLimite2 then
                Events.OnTick.Remove(_atualizacaoInicial)
                if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
                    LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
                    LKS_EletricidadeConstrucao.Core.Logger.Info("Atualizacao inicial do estado dos consumidores (etapa 2) concluida", "Core")
                end
            end
        end
        Events.OnTick.Add(_atualizacaoInicial)
    end)
end

LKS_EletricidadeConstrucao.Core.Logger.Info("Manipuladores de eventos do servidor registrados", "Core")

-- ============================================================================
-- FINALIZAÇÃO
-- ============================================================================

LKS_EletricidadeConstrucao._InitStatus.ServerModulesLoaded = true

print("[LKS PATCH - LKS_EletricidadeConstrucao_ServerInit.lua] Inicializacao do servidor concluida com sucesso!")

return true
