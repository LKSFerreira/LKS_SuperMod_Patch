-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao V2: Debug Commands
-- Purpose: Admin/debug commands for testing and troubleshooting
-- Simplified - avoids top-level namespace aliasing issues

if not LKS_EletricidadeConstrucao or not LKS_EletricidadeConstrucao.Core then
    print("[LKS_EletricidadeConstrucao_DebugCommands] LKS_EletricidadeConstrucao V2 not loaded - skipping")
    return
end
if not LKS_EletricidadeConstrucao.Core.Logger or not LKS_EletricidadeConstrucao.Core.Logger.Info then
    print("[LKS_EletricidadeConstrucao_DebugCommands] Logger not ready - skipping")
    return
end

local Logger = LKS_EletricidadeConstrucao.Core.Logger
local StateManager = LKS_EletricidadeConstrucao.Core.StateManager

-- Ensure sub-tables exist BEFORE any function definitions that index them
-- NOTE: LKS_EletricidadeConstrucao.Debug is already a FUNCTION (utility logger in LKS_EletricidadeConstrucao_Core_Namespace.lua)
-- so we use LKS_EletricidadeConstrucao.DebugCommands as the namespace for server commands
LKS_EletricidadeConstrucao.DebugCommands = LKS_EletricidadeConstrucao.DebugCommands or {}
LKS_EletricidadeConstrucao.DebugCommands.Commands = LKS_EletricidadeConstrucao.DebugCommands.Commands or {}

--------------------------------------------------------------------------------
-- COMMAND HANDLERS (local, server-only)
--------------------------------------------------------------------------------

--- Print all registered generators
local function CMD_ListGenerators(player, args)
    Logger.Info("Debug", "=== GENERATOR LIST ===")
    
    local generators = StateManager.GetAllGenerators()
    if not generators or #generators == 0 then
        Logger.Info("Debug", "No generators registered")
        return
    end
    
    Logger.Info("Debug", string.format("Total generators: %d", #generators))
    
    for _, genData in ipairs(generators) do
        Logger.Info("Debug", string.format(
            "  Generator %s at (%d,%d,%d): %s, Fuel: %.1f%%, Load: %.1f/%.1f, Efficiency: %.1f%%",
            genData.id,
            genData.x, genData.y, genData.z,
            genData.isActive and "ON" or "OFF",
            genData.fuelLevel * 100,
            genData.currentLoad,
            genData.maxLoad,
            genData.efficiency * 100
        ))
    end
    
    Logger.Info("Debug", "======================")
end

--- Print all registered buildings
local function CMD_ListBuildings(player, args)
    Logger.Info("Debug", "=== BUILDING LIST ===")
    
    local buildings = StateManager.GetAllBuildings()
    -- GetAllBuildings() returns a hash-map; # operator always returns 0 for hash-maps
    local _anyBld2 = false
    for _ in pairs(buildings or {}) do _anyBld2 = true; break end
    if not buildings or not _anyBld2 then
        Logger.Info("Debug", "No buildings registered")
        return
    end
    
    local _bldCount2 = 0
    for _ in pairs(buildings) do _bldCount2 = _bldCount2 + 1 end
    Logger.Info("Debug", string.format("Total buildings: %d", _bldCount2))
    
    for _, buildingData in pairs(buildings) do
        local consumerCount = 0
        if buildingData.powerConsumers then
            for _ in pairs(buildingData.powerConsumers) do consumerCount = consumerCount + 1 end
        end
        local genCount = 0
        if buildingData.connectedGenerators then
            for _ in pairs(buildingData.connectedGenerators) do genCount = genCount + 1 end
        end
        
        Logger.Info("Debug", string.format(
            "  Building %s at (%d,%d,%d): %s, Consumers: %d, Power: %.1f, Generators: %d",
            buildingData.id,
            buildingData.centerX, buildingData.centerY, buildingData.z,
            buildingData.isPowered and "POWERED" or "UNPOWERED",
            consumerCount,
            buildingData.totalPowerDraw or 0,
            genCount
        ))
    end
    
    Logger.Info("Debug", "=====================")
end

--- Print all power connections
local function CMD_ListConnections(player, args)
    Logger.Info("Debug", "=== POWER CONNECTIONS ===")
    if not LKS_EletricidadeConstrucao.Power or not LKS_EletricidadeConstrucao.Power.Manager then
        Logger.Warn("Debug", "Power Manager not loaded")
        return
    end
    LKS_EletricidadeConstrucao.Power.Manager.PrintConnections()
end

--- Print detailed building info
local function CMD_BuildingInfo(player, args)
    local buildingId = args[1]
    
    if not buildingId then
        Logger.Warn("Debug", "Usage: /pbbuilding <buildingId>")
        return
    end
    
    local buildingData = StateManager.GetBuilding(buildingId)
    if not buildingData then
        Logger.Warn("Debug", "Building not found: " .. buildingId)
        return
    end
    
    Logger.Info("Debug", "=== BUILDING INFO ===")
    Logger.Info("Debug", "ID: " .. buildingData.id)
    Logger.Info("Debug", string.format("Position: (%d,%d,%d)", buildingData.centerX, buildingData.centerY, buildingData.z))
    Logger.Info("Debug", string.format("Bounding Box: (%d,%d) to (%d,%d)", 
        buildingData.minX, buildingData.minY, buildingData.maxX, buildingData.maxY))
    Logger.Info("Debug", "Powered: " .. tostring(buildingData.isPowered))
    Logger.Info("Debug", string.format("Power Draw: %.1f", buildingData.totalPowerDraw or 0))
    
    if buildingData.powerConsumers then
        local _consCount = 0
        for _ in pairs(buildingData.powerConsumers) do _consCount = _consCount + 1 end
        Logger.Info("Debug", string.format("Consumers: %d", _consCount))
        local _ci = 0
        for _, consumer in pairs(buildingData.powerConsumers) do
            _ci = _ci + 1
            Logger.Info("Debug", string.format("  %d. %s at (%d,%d,%d) - Draw: %.1f",
                _ci, consumer.objectType, consumer.squareX, consumer.squareY, consumer.squareZ, consumer.powerDraw))
        end
    end
    
    if buildingData.connectedGenerators then
        local _genCount = 0
        for _ in pairs(buildingData.connectedGenerators) do _genCount = _genCount + 1 end
        Logger.Info("Debug", string.format("Connected Generators: %d", _genCount))
        local _gi = 0
        for _, genKey in pairs(buildingData.connectedGenerators) do
            _gi = _gi + 1
            Logger.Info("Debug", string.format("  %d. %s", _gi, genKey))
        end
    end
    
    Logger.Info("Debug", "====================")
end

--- Scan for buildings manually
local function CMD_ScanBuildings(player, args)
    Logger.Info("Debug", "Scanning for light switches...")
    if not LKS_EletricidadeConstrucao.Building or not LKS_EletricidadeConstrucao.Building.Scanner then
        Logger.Warn("Debug", "Building Scanner not loaded")
        return
    end
    if LKS_EletricidadeConstrucao.Building.Scanner.ScanAllLightSwitches then
        LKS_EletricidadeConstrucao.Building.Scanner.ScanAllLightSwitches()
    end
    Logger.Info("Debug", "Scan complete.")
end

--- Force power connection update
local function CMD_UpdateConnections(player, args)
    Logger.Info("Debug", "Forcing power connection update...")
    if not LKS_EletricidadeConstrucao.Power or not LKS_EletricidadeConstrucao.Power.Manager then
        Logger.Warn("Debug", "Power Manager not loaded")
        return
    end
    if LKS_EletricidadeConstrucao.Power.Manager.UpdateConnections then
        LKS_EletricidadeConstrucao.Power.Manager.UpdateConnections()
    end
    Logger.Info("Debug", "Connection update complete.")
end

--- Force power distribution update
local function CMD_UpdatePower(player, args)
    Logger.Info("Debug", "Forcing power distribution update...")
    if not LKS_EletricidadeConstrucao.Power or not LKS_EletricidadeConstrucao.Power.Distributor then
        Logger.Warn("Debug", "Power Distributor not loaded")
        return
    end
    if LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate then
        LKS_EletricidadeConstrucao.Power.Distributor.ForceUpdate()
    end
    Logger.Info("Debug", "Power distribution update complete.")
end

--- Scan building at player's position
local function CMD_ScanHere(player, args)
    if not player then return end
    local square = player:getSquare()
    if not square then return end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    Logger.Info("Debug", string.format("Scanning at (%d,%d,%d)...", x, y, z))
    if LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner and LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding then
        LKS_EletricidadeConstrucao.Building.Scanner.ScanBuilding(x, y, z)
    else
        Logger.Warn("Debug", "Building Scanner not loaded")
    end
    Logger.Info("Debug", "Scan complete.")
end

--- Rescan all buildings
local function CMD_RescanAll(player, args)
    Logger.Info("Debug", "Rescanning all registered buildings...")
    if not LKS_EletricidadeConstrucao.Building or not LKS_EletricidadeConstrucao.Building.Scanner then
        Logger.Warn("Debug", "Building Scanner not loaded")
        return
    end
    if LKS_EletricidadeConstrucao.Building.Scanner.RescanAllBuildings then
        LKS_EletricidadeConstrucao.Building.Scanner.RescanAllBuildings()
    end
    Logger.Info("Debug", "Rescan complete.")
end

--- Print system status
local function CMD_Status(player, args)
    Logger.Info("Debug", "=== LKS_EletricidadeConstrucao STATUS ===")
    
    -- Generators
    local generators = StateManager.GetAllGenerators()
    local genCount = generators and #generators or 0
    local activeGens = 0
    for _, gen in ipairs(generators or {}) do
        if gen.isActive then activeGens = activeGens + 1 end
    end
    Logger.Info("Debug", string.format("Generators: %d total, %d active", genCount, activeGens))
    
    -- Buildings
    local buildings = StateManager.GetAllBuildings()
    -- GetAllBuildings() returns a hash-map; # operator always returns 0 for hash-maps
    local buildingCount = 0
    local LKS_EletricidadeConstrucao = 0
    local totalConsumers = 0
    for _, building in pairs(buildings or {}) do
        buildingCount = buildingCount + 1
        if building.isPowered then LKS_EletricidadeConstrucao = LKS_EletricidadeConstrucao + 1 end
        if building.powerConsumers then
            local _pc = 0
            for _ in pairs(building.powerConsumers) do _pc = _pc + 1 end
            totalConsumers = totalConsumers + _pc
        end
    end
    Logger.Info("Debug", string.format("Buildings: %d total, %d powered, %d consumers", 
        buildingCount, LKS_EletricidadeConstrucao, totalConsumers))
    
    -- Connections
    local connectionCount = 0
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager and LKS_EletricidadeConstrucao.Power.Manager.GetConnectionCount then
        connectionCount = LKS_EletricidadeConstrucao.Power.Manager.GetConnectionCount()
    end
    Logger.Info("Debug", string.format("Power Connections: %d", connectionCount))
    Logger.Info("Debug", "Fuel Manager: " .. (LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and "Active" or "Not loaded"))
    Logger.Info("Debug", "Building Scanner: " .. (LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner and "Active" or "Not loaded"))
    Logger.Info("Debug", "Power Distribution: " .. (LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor and "Active" or "Not loaded"))
    
    Logger.Info("Debug", "==============================")
end

--- Save state manually
local function CMD_SaveState(player, args)
    Logger.Info("Debug", "Forcing state save...")
    StateManager.Save(true)
    Logger.Info("Debug", "State saved successfully.")
end

--- Clear all state (dangerous!)
local function CMD_ClearState(player, args)
    local confirm = args and args[1]
    if confirm ~= "CONFIRM" then
        Logger.Warn("Debug", "Usage: /pbclear CONFIRM - Wipes ALL GlobalModData and in-memory state")
        Logger.Warn("Debug", "This will delete: LKS_EletricidadeConstrucaoV2, LKS_EletricidadeConstrucaoV2_GeneratorIndex, LKS_EletricidadeConstrucaoV2_Backup")
        return
    end

    -- Delegate to WipeAllData which also clears IsoGenerator ModData (incl. heating).
    LKS_EletricidadeConstrucao.DebugCommands.WipeAllData()
    Logger.Info("Debug", "/pbclear CONFIRM complete — see console output for details.")
end

--- Print help
local function CMD_Help(player, args)
    Logger.Info("Debug", "=== LKS_EletricidadeConstrucao DEBUG COMMANDS ===")
    Logger.Info("Debug", "/pbstatus - Show system status")
    Logger.Info("Debug", "/pbgenerators - List all generators")
    Logger.Info("Debug", "/pbbuildings - List all buildings")
    Logger.Info("Debug", "/pbconnections - List power connections")
    Logger.Info("Debug", "/pbbuilding <id> - Show building details")
    Logger.Info("Debug", "/pbscan - Scan all light switches")
    Logger.Info("Debug", "/pbscanhere - Scan building at player position")
    Logger.Info("Debug", "/pbrescan - Rescan all buildings")
    Logger.Info("Debug", "/pbupdatecon - Force connection update")
    Logger.Info("Debug", "/pbupdatepower - Force power update")
    Logger.Info("Debug", "/pbsave - Force state save")
    Logger.Info("Debug", "/pbclear CONFIRM - Wipe ALL GlobalModData (dangerous!)")
    Logger.Info("Debug", "/pbhelp - Show this help")
    Logger.Info("Debug", "=======================================")
end

--------------------------------------------------------------------------------
-- COMMAND REGISTRATION
--------------------------------------------------------------------------------

function LKS_EletricidadeConstrucao.DebugCommands.RegisterCommands()
    -- Only skip on pure multiplayer clients (not on singleplayer or servers)
    if isClient() and not isServer() then 
        Logger.Info("Debug", "Skipping command registration on MP client")
        return 
    end
    
    Logger.Info("Debug", "Registering debug commands...")
    
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= "LKS_EletricidadeConstrucao" then return end
        
        if     command == "status"      then CMD_Status(player, args)
        elseif command == "generators"  then CMD_ListGenerators(player, args)
        elseif command == "buildings"   then CMD_ListBuildings(player, args)
        elseif command == "connections" then CMD_ListConnections(player, args)
        elseif command == "building"    then CMD_BuildingInfo(player, args)
        elseif command == "scan"        then CMD_ScanBuildings(player, args)
        elseif command == "scanhere"    then CMD_ScanHere(player, args)
        elseif command == "rescan"      then CMD_RescanAll(player, args)
        elseif command == "updatecon"   then CMD_UpdateConnections(player, args)
        elseif command == "updatepower" then CMD_UpdatePower(player, args)
        elseif command == "save"        then CMD_SaveState(player, args)
        elseif command == "clear"       then CMD_ClearState(player, args)
        elseif command == "help"        then CMD_Help(player, args)
        end
    end)
    
    Logger.Info("Debug", "Debug commands registered.")
end

function LKS_EletricidadeConstrucao.DebugCommands.Initialize()
    LKS_EletricidadeConstrucao.DebugCommands.RegisterCommands()
end

-- Client-side command senders (SP: isServer()=false during load → block runs)
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

-- Direct Lua console commands (works in singleplayer)
--- Nil out all LKS_EletricidadeConstrucao-owned keys on a live IsoGenerator object.
local function _WipeGeneratorIsoModData(obj)
    local md = obj:getModData()
    md.Gen_BuildingPoolID         = nil
    md.LKS_EletricidadeConstrucao_WorldId                 = nil
    md.LKS_EletricidadeConstrucao_PoolData                = nil
    md.Gen_LastCalcWorldAge       = nil
    md.Gen_Stats_Consumers        = nil
    md.Gen_Stats_ActiveConsumers  = nil
    md.Gen_Stats_Lights           = nil
    md.Gen_Stats_ActiveLights     = nil
    md.Gen_Stats_Lamps            = nil
    md.Gen_Stats_ActiveLamps      = nil
    md.Gen_Stats_Appliances       = nil
    md.Gen_Stats_ActiveAppliances = nil
    md.Gen_Stats_PowerDraw        = nil
    md.Gen_Stats_Strain           = nil
    md.Gen_Stats_FuelRateLph      = nil
    md.Gen_Stats_Powered          = nil
    -- Heating state lives on the IsoObject, not in GlobalModData.
    -- Must be wiped here so a fresh pool does not inherit old heating config.
    md.HeatingEnabled             = nil
    md.HeatingPositions           = nil
    md.HeatingTargetTemp          = nil
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        obj:transmitModData()
    end
end

function LKS_EletricidadeConstrucao.DebugCommands.WipeAllData()
    print("=== WIPING ALL LKS_EletricidadeConstrucao DATA ===")

    -- 1. Clear runtime power manager connections
    if LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager then
        LKS_EletricidadeConstrucao.Power.Manager.connections = {}
        print("Cleared: runtime power connections")
    end

    -- 1b. Clear LKS_EletricidadeConstrucao keys from all live IsoGenerator objects BEFORE state is wiped.
    --     GlobalModData is cleared in step 2, but IsoGenerator ModData is stored on
    --     the IsoObject itself and is NOT touched by ClearAll/Save.  Without this step,
    --     generators retain Gen_BuildingPoolID, HeatingPositions, HeatingEnabled etc.
    --     and will re-establish stale pool links on the next chunk load.
    local cell = getCell and getCell()
    local _genWipeCount = 0
    if cell and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
        local allGens = LKS_EletricidadeConstrucao.Core.StateManager.GetAllGenerators()
        if allGens then
            for _, genData in pairs(allGens) do
                -- genId format: "gen_X_Y_Z"
                local px, py, pz = string.match(genData.id or "",
                    "^gen_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                if px then
                    local sq = cell:getGridSquare(tonumber(px), tonumber(py), tonumber(pz))
                    if sq then
                        local objs = sq:getObjects()
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            if obj and instanceof(obj, "IsoGenerator") then
                                _WipeGeneratorIsoModData(obj)
                                _genWipeCount = _genWipeCount + 1
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    print("Cleared: IsoGenerator ModData for " .. _genWipeCount .. " loaded generators (incl. heating)")

    -- 1c. Flush the client-side _activeSources table so IsoHeatSource objects from the
    --     old pool are removed immediately.  Without this step, old heat sources linger
    --     in the world until the next UpdateAll tick (up to 600 ticks / ~1 game-minute)
    --     even after the generator ModData has been wiped.  In SP both server and client
    --     live in the same Lua context, so we can call LKS_EletricidadeConstrucao_HeatingClient directly.
    if LKS_EletricidadeConstrucao_HeatingClient and LKS_EletricidadeConstrucao_HeatingClient.ClearAll then
        LKS_EletricidadeConstrucao_HeatingClient.ClearAll()
        print("Cleared: active heating sources via LKS_EletricidadeConstrucao_HeatingClient.ClearAll()")
    end

    -- 2. Clear in-memory state via StateManager (touches the real _state table)
    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
        LKS_EletricidadeConstrucao.Core.StateManager.ClearAll()
        print("Cleared: in-memory state")

        -- 3. Flush the now-empty state to ModData immediately
        LKS_EletricidadeConstrucao.Core.StateManager.Save(true)
        print("Saved: empty state written to LKS_EletricidadeConstrucaoV2.state")
    else
        print("WARNING: StateManager not available, skipping in-memory clear")
    end

    -- 4. Wipe index and backup entries (not managed by Save)
    ModData.remove("LKS_EletricidadeConstrucaoV2_GeneratorIndex")
    ModData.remove("LKS_EletricidadeConstrucaoV2_Backup")
    ModData.add("LKS_EletricidadeConstrucaoV2_GeneratorIndex", {})
    print("Cleared: LKS_EletricidadeConstrucaoV2_GeneratorIndex and LKS_EletricidadeConstrucaoV2_Backup")

    print("=== WIPE COMPLETE ===")
end

LKS_EletricidadeConstrucao.RegisterModule("Debug.Commands", "2.0.0")
print("[LKS_EletricidadeConstrucao_DebugCommands] Loaded OK")
return LKS_EletricidadeConstrucao.DebugCommands
