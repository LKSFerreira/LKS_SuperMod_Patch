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

-- ARQUIVO: LKS_EletricidadeConstrucao_Core_RuntimeContext.lua
-- OBJETIVO: Detecção centralizada do contexto de execução do jogo (Singleplayer, Host, Cliente ou Servidor Dedicado).
-- DETALHE TÉCNICO: Encapsula as chamadas de API nativa do Project Zomboid para fornecer verificações limpas,
-- resolvendo limitações como o retorno de isServer() em Singleplayer.
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante a existência do namespace principal
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Runtime] Namespace LKS_EletricidadeConstrucao nao encontrado - abortando carregamento do modulo")
    return
end

-- ============================================================================
-- DETECÇÃO DO CONTEXTO DE EXECUÇÃO
-- ============================================================================

--- Verifica se o código está sendo executado no contexto de servidor.
---
--- **Nota da Engine:** No Singleplayer do Project Zomboid, a função nativa `isServer()`
--- retorna `false` mesmo que a lógica do servidor esteja processando dados locais.
--- Para lidar corretamente com Singleplayer, combine esta verificação com `IsSingleplayer()`.
---
--- @return boolean Retorna true se estiver rodando em servidor dedicado ou host multiplayer.
function LKS_EletricidadeConstrucao.Core.Runtime.IsServer()
    return isServer()
end

--- Verifica se o código está rodando no cliente do jogador.
---
--- Em Singleplayer, esta função retorna `true` (já que o cliente e o servidor são integrados localmente).
--- Em Multiplayer local/dedicado, retorna `true` apenas nas máquinas dos jogadores.
---
--- @return boolean Retorna true se estiver no cliente local do jogador.
function LKS_EletricidadeConstrucao.Core.Runtime.IsClient()
    return isClient()
end

--- Obtém o modo de jogo atual de forma segura durante a inicialização (bootstrap).
---
--- Utiliza a classe nativa do Java `getWorld()` via `pcall` para evitar quebras se chamada antes 
--- do mundo ou mapa estarem carregados na memória.
---
--- @return string O nome descritivo do modo de jogo (ex: "Multiplayer", "Survival", "Loading").
function LKS_EletricidadeConstrucao.Core.Runtime.GetGameMode()
    local ok, world = pcall(getWorld)
    if ok and world then
        return world:getGameMode() or "Unknown"
    end
    return "Loading"
end

--- Verifica se o jogo atual está sendo executado no modo Multiplayer.
---
--- @return boolean Retorna true se o modo de jogo for Multiplayer local ou dedicado.
function LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer()
    local ok, world = pcall(getWorld)
    if ok and world then
        return world:getGameMode() == "Multiplayer"
    end
    return false
end

--- Verifica se o jogo atual é Singleplayer (local).
---
--- @return boolean Retorna true se for Singleplayer ou se o mundo ainda não estiver disponível.
function LKS_EletricidadeConstrucao.Core.Runtime.IsSingleplayer()
    local ok, world = pcall(getWorld)
    if ok and world then
        return world:getGameMode() ~= "Multiplayer"
    end
    return true  -- Assume Singleplayer preventivamente se o carregamento ainda estiver pendente
end

--- Verifica se está rodando em um servidor dedicado de Project Zomboid.
---
--- @return boolean Retorna true se for um servidor dedicado sem interface gráfica.
function LKS_EletricidadeConstrucao.Core.Runtime.IsDedicatedServer()
    return LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer() and LKS_EletricidadeConstrucao.Core.Runtime.IsServer()
end

--- Verifica se está rodando no cliente em uma partida multiplayer (não singleplayer).
---
--- @return boolean Retorna true se for uma máquina de cliente conectada a um servidor MP.
function LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayerClient()
    return LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer() and LKS_EletricidadeConstrucao.Core.Runtime.IsClient()
end

--- Verifica se a sincronização de dados por rede (ModData) é necessária.
---
--- Em Singleplayer retorna `false` (dispensando pacotes de rede). Em Multiplayer retorna `true`.
---
--- @return boolean Retorna true se as atualizações devem ser transmitidas via rede.
function LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync()
    return LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer()
end

-- ============================================================================
-- VALIDAÇÕES DE CONTEXTO (Auxiliares de Segurança e Debug)
-- ============================================================================

--- Garante que a execução do script ocorra exclusivamente no servidor, lançando um erro caso contrário.
---
--- Útil para travar a execução no topo de arquivos que manipulam bancos de dados e lógica física de servidor.
function LKS_EletricidadeConstrucao.Core.Runtime.RequireServer()
    if not LKS_EletricidadeConstrucao.Core.Runtime.IsServer() then
        error("[LKS_EletricidadeConstrucao_Runtime] ERRO: Este script requer contexto de servidor mas isServer() = false!")
    end
end

--- Garante que a execução do script ocorra exclusivamente no cliente, lançando um erro caso contrário.
---
--- Útil para arquivos de interface (UI) e menus de contexto.
function LKS_EletricidadeConstrucao.Core.Runtime.RequireClient()
    if not LKS_EletricidadeConstrucao.Core.Runtime.IsClient() then
        error("[LKS_EletricidadeConstrucao_Runtime] ERRO: Este script requer contexto de cliente mas isClient() = false!")
    end
end

--- Emite um aviso no console se o script estiver rodando no ambiente oposto ao planejado.
---
--- @param expectedContext string O contexto esperado ("server" ou "client").
function LKS_EletricidadeConstrucao.Core.Runtime.WarnIfWrongContext(expectedContext)
    if expectedContext == "server" and not LKS_EletricidadeConstrucao.Core.Runtime.IsServer() then
        LKS_EletricidadeConstrucao.Warn("Codigo esperava rodar no Servidor, mas esta rodando no Cliente!")
    elseif expectedContext == "client" and not LKS_EletricidadeConstrucao.Core.Runtime.IsClient() then
        LKS_EletricidadeConstrucao.Warn("Codigo esperava rodar no Cliente, mas esta rodando no Servidor!")
    end
end

-- ============================================================================
-- INFORMAÇÕES E RELATÓRIO DO CONTEXTO
-- ============================================================================

--- Retorna uma tabela contendo todos os dados booleanos do ambiente atual.
---
--- @return table Tabela contendo chaves como isServer, isClient, gameMode, etc.
function LKS_EletricidadeConstrucao.Core.Runtime.GetContextInfo()
    return {
        isServer = LKS_EletricidadeConstrucao.Core.Runtime.IsServer(),
        isClient = LKS_EletricidadeConstrucao.Core.Runtime.IsClient(),
        gameMode = LKS_EletricidadeConstrucao.Core.Runtime.GetGameMode(),
        isMultiplayer = LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer(),
        isSingleplayer = LKS_EletricidadeConstrucao.Core.Runtime.IsSingleplayer(),
        isDedicatedServer = LKS_EletricidadeConstrucao.Core.Runtime.IsDedicatedServer(),
        isMultiplayerClient = LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayerClient(),
        requiresNetworkSync = LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync()
    }
end

--- Imprime o relatório detalhado do ambiente atual formatado no console do jogo.
function LKS_EletricidadeConstrucao.Core.Runtime.PrintContext()
    local info = LKS_EletricidadeConstrucao.Core.Runtime.GetContextInfo()
    LKS_EletricidadeConstrucao.Print("=== Relatorio de Ambiente ===")
    LKS_EletricidadeConstrucao.Print(string.format("  Modo de Jogo: %s", info.gameMode))
    LKS_EletricidadeConstrucao.Print(string.format("  Servidor (isServer): %s", tostring(info.isServer)))
    LKS_EletricidadeConstrucao.Print(string.format("  Cliente (isClient): %s", tostring(info.isClient)))
    LKS_EletricidadeConstrucao.Print(string.format("  Partida Solo (SP): %s", tostring(info.isSingleplayer)))
    LKS_EletricidadeConstrucao.Print(string.format("  Partida em Rede (MP): %s", tostring(info.isMultiplayer)))
    LKS_EletricidadeConstrucao.Print(string.format("  Sincronizacao de Rede: %s", tostring(info.requiresNetworkSync)))
    LKS_EletricidadeConstrucao.Print("=============================")
end

-- ============================================================================
-- ALIASES E ATALHOS CONVENIENTES
-- ============================================================================

LKS_EletricidadeConstrucao.IsServer = LKS_EletricidadeConstrucao.Core.Runtime.IsServer
LKS_EletricidadeConstrucao.IsClient = LKS_EletricidadeConstrucao.Core.Runtime.IsClient
LKS_EletricidadeConstrucao.IsMP = LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer
LKS_EletricidadeConstrucao.IsSP = LKS_EletricidadeConstrucao.Core.Runtime.IsSingleplayer

-- ============================================================================
-- CONCLUSÃO DA INICIALIZAÇÃO
-- ============================================================================

LKS_EletricidadeConstrucao._InitStatus.RuntimeContextReady = true
LKS_EletricidadeConstrucao.RegisterModule("Core.RuntimeContext", "2.0.0")

-- Emite o relatório de ambiente no carregamento baseado nas preferências do Sandbox
if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
    LKS_EletricidadeConstrucao.Core.Runtime.PrintContext()
else
    local info = LKS_EletricidadeConstrucao.Core.Runtime.GetContextInfo()
    LKS_EletricidadeConstrucao.Print(string.format("Contexto ativo: %s (Servidor=%s, Cliente=%s)", 
        info.gameMode, tostring(info.isServer), tostring(info.isClient)))
end

return LKS_EletricidadeConstrucao.Core.Runtime
