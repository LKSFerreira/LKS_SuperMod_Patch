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

-- ARQUIVO: LKS_EletricidadeConstrucao_ClientCommands.lua
-- OBJETIVO: Gerencia as respostas do servidor enviadas ao cliente em sessões multiplayer.
-- LOCALIZAÇÃO: client

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_ClientCommands] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ClientCommands")

--- Busca um gerador fisico (objeto Java IsoGenerator) nas coordenadas mapeadas.
--- @param coordenadaX integer A coordenada X do gerador.
--- @param coordenadaY integer A coordenada Y do gerador.
--- @param coordenadaZ integer A coordenada Z do gerador.
--- @return any|nil Retorna o objeto IsoGenerator se encontrado, ou nil.
local function LocalizarGeradorEm(coordenadaX, coordenadaY, coordenadaZ)
    local celula = getCell and getCell()
    if not celula then return nil end

    local quadrado = celula:getGridSquare(coordenadaX, coordenadaY, coordenadaZ)
    if not quadrado then return nil end

    local objetos = quadrado:getObjects()
    if not objetos then return nil end

    for indiceObjeto = 0, objetos:size() - 1 do
        local objeto = objetos:get(indiceObjeto)
        if objeto and instanceof(objeto, "IsoGenerator") then
            return objeto
        end
    end

    return nil
end

--- Busca e retorna o quadrado fisico (GridSquare) nas coordenadas solicitadas.
--- @param coordenadaX integer Coordenada X.
--- @param coordenadaY integer Coordenada Y.
--- @param coordenadaZ integer Coordenada Z.
--- @return any|nil O GridSquare associado ou nil.
local function LocalizarQuadradoEm(coordenadaX, coordenadaY, coordenadaZ)
    local celula = getCell and getCell()
    if not celula then return nil end
    return celula:getGridSquare(coordenadaX, coordenadaY, coordenadaZ)
end

--- Recupera o objeto do jogador local ativo.
--- @return any|nil O objeto do jogador local ou nil.
local function ObterJogadorLocal()
    if getSpecificPlayer then
        for indiceJogador = 0, 3 do
            local jogador = getSpecificPlayer(indiceJogador)
            if jogador then return jogador end
        end
    end
    return nil
end

--- Despacha e exibe na tela ou console o resultado textual da acao enviada.
--- @param argumentos table Os dados e chaves da mensagem a notificar.
local function NotificarResultado(argumentos)
    if not argumentos then return end

    local mensagem = argumentos.message
    if (not mensagem or mensagem == "") and argumentos.messageKey then
        mensagem = getText(argumentos.messageKey)
    end
    if not mensagem or mensagem == "" then return end

    local jogador = ObterJogadorLocal()
    if jogador and jogador.Say then
        jogador:Say(mensagem)
    else
        print("[LKS_EletricidadeConstrucao_ClientCommands] " .. tostring(mensagem))
    end
end

--- Atualiza a janela visual de estatisticas do gerador correspondente no cliente.
--- @param geradorX integer Coordenada X do gerador.
--- @param geradorY integer Coordenada Y do gerador.
--- @param geradorZ integer Coordenada Z do gerador.
--- @param requisitarEstatisticas boolean Se true, forca a releitura de dados do lado servidor.
local function AtualizarJanelaGerador(geradorX, geradorY, geradorZ, requisitarEstatisticas)
    local UI = LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow
    if not UI or not UI.instances then return end

    local chave = tostring(geradorX) .. "," .. tostring(geradorY) .. "," .. tostring(geradorZ)
    local janela = UI.instances[chave]
    if not janela then return end

    janela.lastUpdate = 0
    if requisitarEstatisticas and janela.requestFreshStats then
        janela:requestFreshStats()
    end
end

--- Fecha a janela grafica de informacoes do gerador informado.
--- @param geradorX integer Coordenada X.
--- @param geradorY integer Coordenada Y.
--- @param geradorZ integer Coordenada Z.
local function FecharJanelaGerador(geradorX, geradorY, geradorZ)
    local UI = LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow
    if not UI or not UI.instances then return end

    local chave = tostring(geradorX) .. "," .. tostring(geradorY) .. "," .. tostring(geradorZ)
    local janela = UI.instances[chave]
    if janela and janela.close then
        janela:close()
    end
end

--- Aplica localmente no cliente o resultado dos controles de aquecimento remoto.
--- @param argumentos table Os parametros retornados pelo servidor.
local function AplicarResultadoAquecimento(argumentos)
    local gerador = LocalizarGeradorEm(argumentos.genX, argumentos.genY, argumentos.genZ)
    local UI = LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow
    local chaveJanela = tostring(argumentos.genX) .. "," .. tostring(argumentos.genY) .. "," .. tostring(argumentos.genZ)
    local janela = UI and UI.instances and UI.instances[chaveJanela]
    
    if not gerador then
        if janela then
            if argumentos.heatingEnabled ~= nil then
                janela._heatingEnabled = argumentos.heatingEnabled == true
            end
            if argumentos.heatingTargetTemp ~= nil then
                janela._heatingTemp = argumentos.heatingTargetTemp
            end
        end
        AtualizarJanelaGerador(argumentos.genX, argumentos.genY, argumentos.genZ, true)
        return
    end

    local dadosMod = gerador:getModData()
    if argumentos.heatingEnabled ~= nil then
        dadosMod.HeatingEnabled = argumentos.heatingEnabled == true
    end
    if argumentos.heatingTargetTemp ~= nil then
        dadosMod.HeatingTargetTemp = argumentos.heatingTargetTemp
    end
    if janela then
        janela._heatingEnabled = dadosMod.HeatingEnabled == true
        janela._heatingTemp = dadosMod.HeatingTargetTemp or janela._heatingTemp
    end

    if LKS_EletricidadeConstrucao_HeatingClient then
        local quadrado = gerador:getSquare()
        if quadrado then
            local chaveGerador = quadrado:getX() .. "_" .. quadrado:getY() .. "_" .. quadrado:getZ()
            if dadosMod.HeatingEnabled == true and gerador:isActivated() then
                LKS_EletricidadeConstrucao_HeatingClient.Remove(chaveGerador)
                LKS_EletricidadeConstrucao_HeatingClient.Apply(gerador)
            else
                LKS_EletricidadeConstrucao_HeatingClient.Remove(chaveGerador)
            end
        end
    end

    AtualizarJanelaGerador(argumentos.genX, argumentos.genY, argumentos.genZ, true)
end

--- Solicita a abertura da janela de informacoes do gerador ou predio.
--- @param argumentos table Os dados retornados pela simulacao do servidor.
local function AbrirJanelaInformacaoDoServidor(argumentos)
    local UI = LKS_EletricidadeConstrucao.UI and LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow
    if not UI or not UI.Open then
        print("[LKS_EletricidadeConstrucao_ClientCommands] Interface GeneratorInfoWindow indisponivel no cliente")
        return
    end

    local jogador = ObterJogadorLocal()
    if not jogador then
        print("[LKS_EletricidadeConstrucao_ClientCommands] Nenhum jogador local encontrado para abrir a janela de informacoes")
        return
    end

    local gerador = nil
    if argumentos.genX ~= nil and argumentos.genY ~= nil and argumentos.genZ ~= nil then
        gerador = LocalizarGeradorEm(argumentos.genX, argumentos.genY, argumentos.genZ)
    end

    local quadradoAncora = nil
    if argumentos.anchorX ~= nil and argumentos.anchorY ~= nil and argumentos.anchorZ ~= nil then
        quadradoAncora = LocalizarQuadradoEm(argumentos.anchorX, argumentos.anchorY, argumentos.anchorZ)
    end

    if not gerador and not quadradoAncora then
        print("[LKS_EletricidadeConstrucao_ClientCommands] Alvo de informacoes (gerador/quadrado) nao esta carregado no cliente")
        return
    end

    UI.Open(jogador, gerador, quadradoAncora, argumentos.buildingID)
end

--- Callback disparada ao receber eventos de comando vindos do servidor.
--- @param modulo string O modulo remetente.
--- @param comando string O comando enviado.
--- @param argumentos table Os argumentos extras de payload.
local function AoReceberComandoServidor(modulo, comando, argumentos)
    if modulo ~= "LKS_EletricidadeConstrucao" or comando ~= "ActionResult" then return end
    if not argumentos or not argumentos.kind then return end

    if argumentos.kind == "OpenInfoWindow" then
        if argumentos.success == false then
            NotificarResultado(argumentos)
            return
        end
        AbrirJanelaInformacaoDoServidor(argumentos)
        return
    elseif argumentos.kind == "HeatingToggle" then
        AplicarResultadoAquecimento(argumentos)
    elseif argumentos.kind == "DisconnectBuilding"
            and argumentos.success == true
            and argumentos.genX ~= nil and argumentos.genY ~= nil and argumentos.genZ ~= nil then
        FecharJanelaGerador(argumentos.genX, argumentos.genY, argumentos.genZ)
    elseif argumentos.genX ~= nil and argumentos.genY ~= nil and argumentos.genZ ~= nil then
        AtualizarJanelaGerador(argumentos.genX, argumentos.genY, argumentos.genZ, argumentos.success == true)
    end

    if argumentos.success == false then
        NotificarResultado(argumentos)
        return
    end

    if (argumentos.kind == "BarrelLink"
            or argumentos.kind == "ConnectBuilding"
            or argumentos.kind == "DisconnectBuilding")
            and (argumentos.message or argumentos.messageKey) then
        NotificarResultado(argumentos)
    end
end

-- Registra a escuta do evento de rede do Project Zomboid
if Events.OnServerCommand then
    Events.OnServerCommand.Add(AoReceberComandoServidor)
    print("[LKS_EletricidadeConstrucao_ClientCommands] Eventos de comandos de rede registrados com sucesso.")
else
    print("[LKS_EletricidadeConstrucao_ClientCommands] AVISO: Evento OnServerCommand indisponivel no ambiente de execucao.")
end

return true