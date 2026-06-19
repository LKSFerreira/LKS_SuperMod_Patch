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

-- ARQUIVO: LKS_EletricidadeConstrucao_DebugCommands.lua
-- OBJETIVO: Comandos de administração e depuração do sistema elétrico.
-- LOCALIZAÇÃO: server

if not LKS_EletricidadeConstrucao or not LKS_EletricidadeConstrucao.Core then
    print("[LKS PATCH - LKS_EletricidadeConstrucao_DebugCommands.lua] Namespace LKS_EletricidadeConstrucao ou Core nao encontrado - pulando carregamento do modulo")
    return
end

if not LKS_EletricidadeConstrucao.Core.Logger or not LKS_EletricidadeConstrucao.Core.Logger.Info then
    print("[LKS PATCH - LKS_EletricidadeConstrucao_DebugCommands.lua] Logger nao inicializado - pulando carregamento do modulo")
    return
end

local Logger = LKS_EletricidadeConstrucao.Core.Logger
local StateManager = LKS_EletricidadeConstrucao.Core.StateManager

LKS_EletricidadeConstrucao.DebugCommands = LKS_EletricidadeConstrucao.DebugCommands or {}
LKS_EletricidadeConstrucao.DebugCommands.Commands = LKS_EletricidadeConstrucao.DebugCommands.Commands or {}

-- ============================================================================
-- MANIPULADORES DE COMANDOS (EXCLUSIVOS DO SERVIDOR)
-- ============================================================================

--- Imprime todos os geradores registrados no console.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_ListarGeradores(player, args)
    Logger.Info("Debug", "=== LISTA DE GERADORES ===")
    
    local geradores = StateManager.GetAllGenerators()
    if not geradores or #geradores == 0 then
        Logger.Info("Debug", "Nenhum gerador registrado")
        return
    end
    
    Logger.Info("Debug", string.format("Total de geradores: %d", #geradores))
    
    for _, dadosGerador in ipairs(geradores) do
        Logger.Info("Debug", string.format(
            "  Gerador %s em (%d,%d,%d): %s, Combustível: %.1f%%, Carga: %.1f/%.1f, Eficiência: %.1f%%",
            dadosGerador.id,
            dadosGerador.x, dadosGerador.y, dadosGerador.z,
            dadosGerador.isActive and "LIGADO" or "DESLIGADO",
            dadosGerador.fuelLevel * 100,
            dadosGerador.currentLoad,
            dadosGerador.maxLoad,
            dadosGerador.efficiency * 100
        ))
    end
    
    Logger.Info("Debug", "======================")
end

--- Imprime todas as construções registradas no console.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_ListarConstrucoes(player, args)
    Logger.Info("Debug", "=== LISTA DE CONSTRUCOES ===")
    
    local construcoes = StateManager.GetAllBuildings()
    local _qualquerConstrucao = false
    for _ in pairs(construcoes or {}) do _qualquerConstrucao = true; break end
    if not construcoes or not _qualquerConstrucao then
        Logger.Info("Debug", "Nenhuma construcao registrada")
        return
    end
    
    local _totalConstrucoes = 0
    for _ in pairs(construcoes) do _totalConstrucoes = _totalConstrucoes + 1 end
    Logger.Info("Debug", string.format("Total de construcoes: %d", _totalConstrucoes))
    
    for _, dadosConstrucao in pairs(construcoes) do
        local totalConsumidores = 0
        if dadosConstrucao.powerConsumers then
            for _ in pairs(dadosConstrucao.powerConsumers) do totalConsumidores = totalConsumidores + 1 end
        end
        local totalGeradores = 0
        if dadosConstrucao.connectedGenerators then
            for _ in pairs(dadosConstrucao.connectedGenerators) do totalGeradores = totalGeradores + 1 end
        end
        
        Logger.Info("Debug", string.format(
            "  Construção %s em (%d,%d,%d): %s, Consumidores: %d, Energia: %.1f, Geradores: %d",
            dadosConstrucao.id,
            dadosConstrucao.centerX, dadosConstrucao.centerY, dadosConstrucao.z,
            dadosConstrucao.isPowered and "ENERGIZADA" or "SEM_ENERGIA",
            totalConsumidores,
            dadosConstrucao.totalPowerDraw or 0,
            totalGeradores
        ))
    end
    
    Logger.Info("Debug", "=====================")
end

--- Imprime todas as conexões ativas de energia.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_ListarConexoes(player, args)
    Logger.Info("Debug", "=== CONEXOES DE ENERGIA ===")
    if not LKS_EletricidadeConstrucao.Power or not LKS_EletricidadeConstrucao.Power.Manager then
        Logger.Warn("Debug", "Gerenciador de Energia nao carregado")
        return
    end
    LKS_EletricidadeConstrucao.Power.Manager.PrintConnections()
end

--- Imprime informações detalhadas de uma construção específica.
--- @param player any O jogador executando.
--- @param args table Lista com o id da construção.
local function CMD_InformacoesConstrucao(player, args)
    local idConstrucao = args[1]
    
    if not idConstrucao then
        Logger.Warn("Debug", "Uso: /pbbuilding <idConstrucao>")
        return
    end
    
    local dadosConstrucao = StateManager.GetBuilding(idConstrucao)
    if not dadosConstrucao then
        Logger.Warn("Debug", "Construcao nao encontrada: " .. idConstrucao)
        return
    end
    
    Logger.Info("Debug", "=== INFORMACOES DA CONSTRUCAO ===")
    Logger.Info("Debug", "ID: " .. dadosConstrucao.id)
    Logger.Info("Debug", string.format("Posicao: (%d,%d,%d)", dadosConstrucao.centerX, dadosConstrucao.centerY, dadosConstrucao.z))
    Logger.Info("Debug", string.format("Caixa Delimitadora: (%d,%d) a (%d,%d)", 
        dadosConstrucao.minX, dadosConstrucao.minY, dadosConstrucao.maxX, dadosConstrucao.maxY))
    Logger.Info("Debug", "Energizada: " .. tostring(dadosConstrucao.isPowered))
    Logger.Info("Debug", string.format("Consumo de Energia: %.1f", dadosConstrucao.totalPowerDraw or 0))
    
    if dadosConstrucao.powerConsumers then
        local _totalConsumidores = 0
        for _ in pairs(dadosConstrucao.powerConsumers) do _totalConsumidores = _totalConsumidores + 1 end
        Logger.Info("Debug", string.format("Consumidores: %d", _totalConsumidores))
        local _indiceConsumidor = 0
        for _, consumidor in pairs(dadosConstrucao.powerConsumers) do
            _indiceConsumidor = _indiceConsumidor + 1
            Logger.Info("Debug", string.format("  %d. %s em (%d,%d,%d) - Consumo: %.1f",
                _indiceConsumidor, consumidor.objectType, consumidor.squareX, consumidor.squareY, consumidor.squareZ, consumidor.powerDraw))
        end
    end
    
    if dadosConstrucao.connectedGenerators then
        local _indiceGerador = 0
        for _ in pairs(dadosConstrucao.connectedGenerators) do _indiceGerador = _indiceGerador + 1 end
        Logger.Info("Debug", string.format("Geradores Conectados: %d", _indiceGerador))
        local _gi = 0
        for _, chaveGerador in pairs(dadosConstrucao.connectedGenerators) do
            _gi = _gi + 1
            Logger.Info("Debug", string.format("  %d. %s", _gi, chaveGerador))
        end
    end
    
    Logger.Info("Debug", "====================")
end

--- Força o escaneamento manual de todas as construções no servidor.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_EscanearConstrucoes(player, args)
    Logger.Info("Debug", "Escaneando por interruptores de luz...")
    if not LKS_EletricidadeConstrucao.Building or not LKS_EletricidadeConstrucao.Building.Scanner then
        Logger.Warn("Debug", "Escaneador de Construcao nao carregado")
        return
    end
    if LKS_EletricidadeConstrucao.Building.Scanner.ScanAllLightSwitches then
        LKS_EletricidadeConstrucao.Building.Scanner.ScanAllLightSwitches()
    end
    Logger.Info("Debug", "Escaneamento concluido.")
end

--- Força a atualização imediata das conexões de energia.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_AtualizarConexoes(player, args)
    Logger.Info("Debug", "Forcando atualizacao de conexao de energia...")
    if not LKS_EletricidadeConstrucao.Power or not LKS_EletricidadeConstrucao.Power.Manager then
        Logger.Warn("Debug", "Gerenciador de Energia nao carregado")
        return
    end
    if LKS_EletricidadeConstrucao.Power.Manager.UpdateConnections then
        LKS_EletricidadeConstrucao.Power.Manager.UpdateConnections()
    end
    Logger.Info("Debug", "Atualizacao de conexao concluida.")
end

--- Força a atualização da distribuição de carga elétrica nas redes.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_AtualizarEnergia(player, args)
    Logger.Info("Debug", "Forcando atualizacao da distribuicao de energia...")
    if not LKS_EletricidadeConstrucao.Power or not LKS_EletricidadeConstrucao.Power.Distributor then
        Logger.Warn("Debug", "Distribuidor de Energia nao carregado")
        return
    end
    if LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
        LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
    end
    Logger.Info("Debug", "Atualizacao da distribuicao de energia concluida.")
end

--- Escaneia a construção ao redor da posição atual do jogador.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_EscanearAqui(player, args)
    if not player then return end
    local quadrado = player:getSquare()
    if not quadrado then return end
    local coordenadaX, coordenadaY, coordenadaZ = quadrado:getX(), quadrado:getY(), quadrado:getZ()
    Logger.Info("Debug", string.format("Escaneando em (%d,%d,%d)...", coordenadaX, coordenadaY, coordenadaZ))
    if LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner and LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding then
        LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(coordenadaX, coordenadaY, coordenadaZ)
    else
        Logger.Warn("Debug", "Escaneador de Construcao nao carregado")
    end
    Logger.Info("Debug", "Escaneamento concluido.")
end

--- Rescaneia completamente todas as construções registradas em memória.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_ReescanearTudo(player, args)
    Logger.Info("Debug", "Reescaneando todas as construcoes registradas...")
    if not LKS_EletricidadeConstrucao.Building or not LKS_EletricidadeConstrucao.Building.Scanner then
        Logger.Warn("Debug", "Escaneador de Construcao nao carregado")
        return
    end
    if LKS_EletricidadeConstrucao.Building.Scanner.RescanAllBuildings then
        LKS_EletricidadeConstrucao.Building.Scanner.RescanAllBuildings()
    end
    Logger.Info("Debug", "Reescaneamento concluido.")
end

--- Exibe estatísticas consolidadas do estado elétrico do servidor.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_Estado(player, args)
    Logger.Info("Debug", "=== ESTADO DO LKS_EletricidadeConstrucao ===")
    
    -- Geradores
    local geradores = StateManager.GetAllGenerators()
    local totalGeradores = geradores and #geradores or 0
    local geradoresAtivos = 0
    for _, gerador in ipairs(geradores or {}) do
        if gerador.isActive then geradoresAtivos = geradoresAtivos + 1 end
    end
    Logger.Info("Debug", string.format("Geradores: %d no total, %d ativos", totalGeradores, geradoresAtivos))
    
    -- Construções
    local construcoes = StateManager.GetAllBuildings()
    local totalConstrucoes = 0
    local construcoesEnergizadas = 0
    local totalConsumidores = 0
    for _, construcao in pairs(construcoes or {}) do
        totalConstrucoes = totalConstrucoes + 1
        if construcao.isPowered then construcoesEnergizadas = construcoesEnergizadas + 1 end
        if construcao.powerConsumers then
            local _contagemConsumidores = 0
            for _ in pairs(construcao.powerConsumers) do _contagemConsumidores = _contagemConsumidores + 1 end
            totalConsumidores = totalConsumidores + _contagemConsumidores
        end
    end
    Logger.Info("Debug", string.format("Construcoes: %d no total, %d energizadas, %d consumidores", 
        totalConstrucoes, construcoesEnergizadas, totalConsumidores))
    
    -- Conexões
    local totalConexoes = 0
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager and LKS_EletricidadeConstrucao.Power.Manager.GetConnectionCount then
        totalConexoes = LKS_EletricidadeConstrucao.Power.Manager.GetConnectionCount()
    end
    Logger.Info("Debug", string.format("Conexoes de Energia: %d", totalConexoes))
    Logger.Info("Debug", "Gerenciador de Combustivel: " .. (LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and "Ativo" or "Nao carregado"))
    Logger.Info("Debug", "Escaneador de Construcao: " .. (LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner and "Ativo" or "Nao carregado"))
    Logger.Info("Debug", "Distribuicao de Energia: " .. (LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and "Ativa" or "Nao carregada"))
    
    Logger.Info("Debug", "==============================")
end

--- Força o salvamento manual do estado em disco.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_SalvarEstado(player, args)
    Logger.Info("Debug", "Forcando salvamento do estado...")
    StateManager.Save(true)
    Logger.Info("Debug", "Estado salvo com sucesso.")
end

--- Limpa completamente todo o estado elétrico salvo e em memória (AÇÃO DESTRUTIVA!).
--- @param player any O jogador executando.
--- @param args table Argumentos de confirmação.
local function CMD_LimparEstado(player, args)
    local confirmacao = args and args[1]
    if confirmacao ~= "CONFIRM" then
        Logger.Warn("Debug", "Uso: /pbclear CONFIRM - Limpa TODO o GlobalModData e o estado em memoria")
        Logger.Warn("Debug", "Isso excluira: LKS_EletricidadeConstrucaoV2, LKS_EletricidadeConstrucaoV2_GeneratorIndex, LKS_EletricidadeConstrucaoV2_Backup")
        return
    end

    LKS_EletricidadeConstrucao.DebugCommands.WipeAllData()
    Logger.Info("Debug", "/pbclear CONFIRM concluido — consulte a saida do console para detalhes.")
end

--- Exibe o painel de ajuda dos comandos de depuração admin.
--- @param player any O jogador executando.
--- @param args table Argumentos adicionais.
local function CMD_Ajuda(player, args)
    Logger.Info("Debug", "=== LKS_EletricidadeConstrucao DEBUG COMMANDS ===")
    Logger.Info("Debug", "/pbstatus - Exibe o status consolidado do sistema")
    Logger.Info("Debug", "/pbgenerators - Lista todos os geradores registrados")
    Logger.Info("Debug", "/pbbuildings - Lista todas as construcoes registradas")
    Logger.Info("Debug", "/pbconnections - Lista as conexoes ativas de rede de fiacao")
    Logger.Info("Debug", "/pbbuilding <id> - Detalha uma construcao especifica")
    Logger.Info("Debug", "/pbscan - Escaneia interruptores carregados no mapa")
    Logger.Info("Debug", "/pbscanhere - Escaneia a construcao ao redor do jogador")
    Logger.Info("Debug", "/pbrescan - Recarrega e reavalia todas as construcoes")
    Logger.Info("Debug", "/pbupdatecon - Forca a atualizacao do acoplamento eletrico")
    Logger.Info("Debug", "/pbupdatepower - Forca o recalculo do consumo de energia")
    Logger.Info("Debug", "/pbsave - Salva o estado eletrico atual em disco")
    Logger.Info("Debug", "/pbclear CONFIRM - Wipa completamente todos os dados salvos do mod")
    Logger.Info("Debug", "/pbhelp - Exibe este guia de ajuda")
    Logger.Info("Debug", "=======================================")
end

-- ============================================================================
-- REGISTRO DOS COMANDOS
-- ============================================================================

function LKS_EletricidadeConstrucao.DebugCommands.RegisterCommands()
    -- Evita o registro dos handlers se for um cliente multiplayer puro
    if isClient() and not isServer() then 
        Logger.Info("Debug", "Ignorando registro de comandos no cliente MP")
        return 
    end
    
    Logger.Info("Debug", "Registrando comandos de depuracao eletricos...")
    
    Events.OnClientCommand.Add(function(modulo, comando, player, args)
        if modulo ~= "LKS_EletricidadeConstrucao" then return end
        
        if     comando == "status"      then CMD_Estado(player, args)
        elseif comando == "generators"  then CMD_ListarGeradores(player, args)
        elseif comando == "buildings"   then CMD_ListarConstrucoes(player, args)
        elseif comando == "connections" then CMD_ListarConexoes(player, args)
        elseif comando == "building"    then CMD_InformacoesConstrucao(player, args)
        elseif comando == "scan"        then CMD_EscanearConstrucoes(player, args)
        elseif comando == "scanhere"    then CMD_EscanearAqui(player, args)
        elseif comando == "rescan"      then CMD_ReescanearTudo(player, args)
        elseif comando == "updatecon"   then CMD_AtualizarConexoes(player, args)
        elseif comando == "updatepower" then CMD_AtualizarEnergia(player, args)
        elseif comando == "save"        then CMD_SalvarEstado(player, args)
        elseif comando == "clear"       then CMD_LimparEstado(player, args)
        elseif comando == "help"        then CMD_Ajuda(player, args)
        end
    end)
    
    Logger.Info("Debug", "Comandos de depuracao registrados com sucesso.")
end

function LKS_EletricidadeConstrucao.DebugCommands.Initialize()
    LKS_EletricidadeConstrucao.DebugCommands.RegisterCommands()
end

-- Envio dos comandos pelo cliente (SP)
if not isServer() then
    local C = LKS_EletricidadeConstrucao.DebugCommands.Commands
    function C.Status()      sendClientCommand("LKS_EletricidadeConstrucao", "status",     {}) end
    function C.Generators()  sendClientCommand("LKS_EletricidadeConstrucao", "generators", {}) end
    function C.Buildings()   sendClientCommand("LKS_EletricidadeConstrucao", "buildings",  {}) end
    function C.Connections() sendClientCommand("LKS_EletricidadeConstrucao", "connections",{}) end
    function C.ScanHere()    sendClientCommand("LKS_EletricidadeConstrucao", "scanhere",   {}) end
    function C.Save()        sendClientCommand("LKS_EletricidadeConstrucao", "save",       {}) end
    function C.Clear()       sendClientCommand("LKS_EletricidadeConstrucao", "clear",      {"CONFIRM"}) end
    function C.Help()        sendClientCommand("LKS_EletricidadeConstrucao", "help",       {}) end
end

-- Comandos diretos de console Lua
--- Zera todas as chaves do mod no ModData de um objeto físico IsoGenerator.
--- @param objeto any O objeto IsoGenerator.
local function _LimparDadosModIsoGerador(objeto)
    local dadosMod = objeto:getModData()
    dadosMod.Gen_BuildingPoolID         = nil
    dadosMod.LKS_EletricidadeConstrucao_WorldId                 = nil
    dadosMod.LKS_EletricidadeConstrucao_PoolData                = nil
    dadosMod.Gen_LastCalcWorldAge       = nil
    dadosMod.Gen_Stats_Consumers        = nil
    dadosMod.Gen_Stats_ActiveConsumers  = nil
    dadosMod.Gen_Stats_Lights           = nil
    dadosMod.Gen_Stats_ActiveLights     = nil
    dadosMod.Gen_Stats_Lamps            = nil
    dadosMod.Gen_Stats_ActiveLamps      = nil
    dadosMod.Gen_Stats_Appliances       = nil
    dadosMod.Gen_Stats_ActiveAppliances = nil
    dadosMod.Gen_Stats_PowerDraw        = nil
    dadosMod.Gen_Stats_Strain           = nil
    dadosMod.Gen_Stats_FuelRateLph      = nil
    dadosMod.Gen_Stats_Powered          = nil
    
    -- Limpa também o estado do aquecedor integrado
    dadosMod.HeatingEnabled             = nil
    dadosMod.HeatingPositions           = nil
    dadosMod.HeatingTargetTemp          = nil
    
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        objeto:transmitModData()
    end
end

function LKS_EletricidadeConstrucao.DebugCommands.WipeAllData()
    print("=== WIPING ALL LKS_EletricidadeConstrucao DATA ===")

    -- 1. Limpa as conexões elétricas em memória do Power Manager
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager then
        LKS_EletricidadeConstrucao.Power.Manager.connections = {}
        print("Limpo: conexões elétricas de runtime do Power.Manager")
    end

    -- 2. Limpa os ModData dos IsoGenerators ativos carregados no mapa
    local celula = getCell and getCell()
    local _totalGeradoresLimpos = 0
    if celula and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
        local todosGeradores = LKS_EletricidadeConstrucao.Core.StateManager.GetAllGenerators()
        if todosGeradores then
            for _, dadosGerador in pairs(todosGeradores) do
                local px, py, pz = string.match(dadosGerador.id or "", "^gen_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                if px then
                    local quadrado = celula:getGridSquare(tonumber(px), tonumber(py), tonumber(pz))
                    if quadrado then
                        local objetos = quadrado:getObjects()
                        for i = 0, objetos:size() - 1 do
                            local objeto = objetos:get(i)
                            if objeto and instanceof(objeto, "IsoGenerator") then
                                _LimparDadosModIsoGerador(objeto)
                                _totalGeradoresLimpos = _totalGeradoresLimpos + 1
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    print("Limpo: ModData do IsoGenerator para " .. _totalGeradoresLimpos .. " geradores carregados (incluindo aquecimento)")

    -- 3. Limpa a tabela de aquecedores ativos do cliente para cessar a radiação de calor física imediatamente
    if LKS_EletricidadeConstrucao_HeatingClient and LKS_EletricidadeConstrucao_HeatingClient.ClearAll then
        LKS_EletricidadeConstrucao_HeatingClient.ClearAll()
        print("Limpo: fontes de calor ativas no mapa via LKS_EletricidadeConstrucao_HeatingClient.ClearAll()")
    end

    -- 4. Limpa os estados em memória e wipa o StateManager
    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
        LKS_EletricidadeConstrucao.Core.StateManager.ClearAll()
        print("Limpo: estado do StateManager em memória")

        -- Escreve o estado vazio no disco para persistência
        LKS_EletricidadeConstrucao.Core.StateManager.Save(true)
        print("Salvo: estado vazio gravado no arquivo de estado")
    else
        print("AVISO: StateManager não disponível - pulando limpeza de estado em memória")
    end

    -- 5. Remove os índices globais extras e backups salvos no ModData do jogo
    ModData.remove("LKS_EletricidadeConstrucaoV2_GeneratorIndex")
    ModData.remove("LKS_EletricidadeConstrucaoV2_Backup")
    ModData.add("LKS_EletricidadeConstrucaoV2_GeneratorIndex", {})
    print("Limpo: LKS_EletricidadeConstrucaoV2_GeneratorIndex e LKS_EletricidadeConstrucaoV2_Backup no ModData do jogo")

    print("=== WIPE COMPLETE ===")
end

LKS_EletricidadeConstrucao.RegisterModule("Debug.Commands", "2.0.0")
print("[LKS PATCH - LKS_EletricidadeConstrucao_DebugCommands.lua] Modulo de comandos de depuracao carregado com sucesso!")
return LKS_EletricidadeConstrucao.DebugCommands
