-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_ClientCommands.lua
-- Handles server -> client acknowledgements for multiplayer action requests.

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_ClientCommands] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ClientCommands")

local function FindGeneratorAt(x, y, z)
    local cell = getCell and getCell()
    if not cell then return nil end

    local sq = cell:getGridSquare(x, y, z)
    if not sq then return nil end

    local objs = sq:getObjects()
    if not objs then return nil end

    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj and instanceof(obj, "IsoGenerator") then
            return obj
        end
    end

    return nil
end

local function FindSquareAt(x, y, z)
    local cell = getCell and getCell()
    if not cell then return nil end
    return cell:getGridSquare(x, y, z)
end

local function GetLocalPlayer()
    if getSpecificPlayer then
        for i = 0, 3 do
            local player = getSpecificPlayer(i)
            if player then return player end
        end
    end
    return nil
end

local function NotifyResult(args)
    if not args then return end

    local message = args.message
    if (not message or message == "") and args.messageKey then
        message = getText(args.messageKey)
    end
    if not message or message == "" then return end

    local player = GetLocalPlayer()
    if player and player.Say then
        player:Say(message)
    else
        print("[LKS_EletricidadeConstrucao_ClientCommands] " .. tostring(message))
    end
end

local function RefreshGeneratorWindow(genX, genY, genZ, requestStats)
    local UI = LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow
    if not UI or not UI.instances then return end

    local key = tostring(genX) .. "," .. tostring(genY) .. "," .. tostring(genZ)
    local win = UI.instances[key]
    if not win then return end

    win.lastUpdate = 0
    if requestStats and win.requestFreshStats then
        win:requestFreshStats()
    end
end

local function CloseGeneratorWindow(genX, genY, genZ)
    local UI = LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow
    if not UI or not UI.instances then return end

    local key = tostring(genX) .. "," .. tostring(genY) .. "," .. tostring(genZ)
    local win = UI.instances[key]
    if win and win.close then
        win:close()
    end
end

local function ApplyHeatingResult(args)
    local gen = FindGeneratorAt(args.genX, args.genY, args.genZ)
    local UI = LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow
    local win = UI and UI.instances and UI.instances[tostring(args.genX) .. "," .. tostring(args.genY) .. "," .. tostring(args.genZ)]
    if not gen then
        if win then
            if args.heatingEnabled ~= nil then
                win._heatingEnabled = args.heatingEnabled == true
            end
            if args.heatingTargetTemp ~= nil then
                win._heatingTemp = args.heatingTargetTemp
            end
        end
        RefreshGeneratorWindow(args.genX, args.genY, args.genZ, true)
        return
    end

    local md = gen:getModData()
    if args.heatingEnabled ~= nil then
        md.HeatingEnabled = args.heatingEnabled == true
    end
    if args.heatingTargetTemp ~= nil then
        md.HeatingTargetTemp = args.heatingTargetTemp
    end
    if win then
        win._heatingEnabled = md.HeatingEnabled == true
        win._heatingTemp = md.HeatingTargetTemp or win._heatingTemp
    end

    if LKS_EletricidadeConstrucao_HeatingClient then
        local sq = gen:getSquare()
        if sq then
            local genKey = sq:getX() .. "_" .. sq:getY() .. "_" .. sq:getZ()
            if md.HeatingEnabled == true and gen:isActivated() then
                LKS_EletricidadeConstrucao_HeatingClient.Remove(genKey)
                LKS_EletricidadeConstrucao_HeatingClient.Apply(gen)
            else
                LKS_EletricidadeConstrucao_HeatingClient.Remove(genKey)
            end
        end
    end

    RefreshGeneratorWindow(args.genX, args.genY, args.genZ, true)
end

local function OpenInfoWindowFromServer(args)
    local UI = LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow
    if not UI or not UI.Open then
        print("[LKS_EletricidadeConstrucao_ClientCommands] GeneratorInfoWindow UI is unavailable")
        return
    end

    local player = GetLocalPlayer()
    if not player then
        print("[LKS_EletricidadeConstrucao_ClientCommands] No local player available for OpenInfoWindow")
        return
    end

    local generator = nil
    if args.genX ~= nil and args.genY ~= nil and args.genZ ~= nil then
        generator = FindGeneratorAt(args.genX, args.genY, args.genZ)
    end

    local anchorSquare = nil
    if args.anchorX ~= nil and args.anchorY ~= nil and args.anchorZ ~= nil then
        anchorSquare = FindSquareAt(args.anchorX, args.anchorY, args.anchorZ)
    end

    if not generator and not anchorSquare then
        print("[LKS_EletricidadeConstrucao_ClientCommands] OpenInfoWindow target is not loaded on client")
        return
    end

    UI.Open(player, generator, anchorSquare, args.buildingID)
end

local function OnServerCommand(module, command, args)
    if module ~= "LKS_EletricidadeConstrucao" or command ~= "ActionResult" then return end
    if not args or not args.kind then return end

    if args.kind == "OpenInfoWindow" then
        if args.success == false then
            NotifyResult(args)
            return
        end
        OpenInfoWindowFromServer(args)
        return
    elseif args.kind == "HeatingToggle" then
        ApplyHeatingResult(args)
    elseif args.kind == "DisconnectBuilding"
            and args.success == true
            and args.genX ~= nil and args.genY ~= nil and args.genZ ~= nil then
        CloseGeneratorWindow(args.genX, args.genY, args.genZ)
    elseif args.genX ~= nil and args.genY ~= nil and args.genZ ~= nil then
        RefreshGeneratorWindow(args.genX, args.genY, args.genZ, args.success == true)
    end

    if args.success == false then
        NotifyResult(args)
        return
    end

    if (args.kind == "BarrelLink"
            or args.kind == "ConnectBuilding"
            or args.kind == "DisconnectBuilding")
            and (args.message or args.messageKey) then
        NotifyResult(args)
    end
end

if Events.OnServerCommand then
    Events.OnServerCommand.Add(OnServerCommand)
    print("[LKS_EletricidadeConstrucao_ClientCommands] Loaded")
else
    print("[LKS_EletricidadeConstrucao_ClientCommands] WARNING: OnServerCommand event not available")
end

return true