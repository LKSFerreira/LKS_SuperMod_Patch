-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Core_RuntimeContext.lua
-- LKS_EletricidadeConstrucao V2 - Runtime Context Detection
-- Provides centralized game mode detection and execution context helpers
-- Wraps isServer(), isClient(), getGameMode() for cleaner code
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Runtime] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- EXECUTION CONTEXT DETECTION
-- ============================================================================

--- Check if code is running in server context
--- NOTE: In PZ Singleplayer, isServer() returns FALSE even in the server Lua state.
---       Use IsSingleplayer() in combination to handle SP correctly.
--- In Singleplayer: Returns FALSE (PZ limitation — use IsSingleplayer() too)
--- In Multiplayer Server: Returns true
--- In Multiplayer Client: Returns false
--- @return boolean True if server context
function LKS_EletricidadeConstrucao.Core.Runtime.IsServer()
    return isServer()
end

--- Check if code is running in client context
--- In Singleplayer: Returns true (integrated client)
--- In Multiplayer Server: Returns false
--- In Multiplayer Client: Returns true
--- @return boolean True if client context
function LKS_EletricidadeConstrucao.Core.Runtime.IsClient()
    return isClient()
end

--- Get current game mode string (safe for load phase)
--- @return string Game mode ("Multiplayer", "Survival", "Sandbox", "Loading", etc.)
function LKS_EletricidadeConstrucao.Core.Runtime.GetGameMode()
    local ok, world = pcall(getWorld)
    if ok and world then
        return world:getGameMode() or "Unknown"
    end
    return "Loading"
end

--- Check if current mode is Multiplayer
--- @return boolean True if multiplayer mode (server or client)
function LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer()
    local ok, world = pcall(getWorld)
    if ok and world then
        return world:getGameMode() == "Multiplayer"
    end
    return false
end

--- Check if current mode is Singleplayer
--- @return boolean True if singleplayer mode
function LKS_EletricidadeConstrucao.Core.Runtime.IsSingleplayer()
    local ok, world = pcall(getWorld)
    if ok and world then
        return world:getGameMode() ~= "Multiplayer"
    end
    return true  -- assume singleplayer if world not available yet
end

--- Check if running on dedicated multiplayer server
--- @return boolean True if dedicated MP server (not SP integrated server)
function LKS_EletricidadeConstrucao.Core.Runtime.IsDedicatedServer()
    return LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer() and LKS_EletricidadeConstrucao.Core.Runtime.IsServer()
end

--- Check if running on multiplayer client
--- @return boolean True if MP client (not SP integrated client)
function LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayerClient()
    return LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer() and LKS_EletricidadeConstrucao.Core.Runtime.IsClient()
end

--- Check if network synchronization is required
--- In Singleplayer: Returns false (no network)
--- In Multiplayer: Returns true (need ModData.transmit())
--- @return boolean True if network sync needed
function LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync()
    return LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer()
end

-- ============================================================================
-- CONTEXT VALIDATION (Development/Debug Helpers)
-- ============================================================================

--- Ensure code is running in server context, error if not
--- Use at start of server-only files: LKS_EletricidadeConstrucao.Core.Runtime.RequireServer()
function LKS_EletricidadeConstrucao.Core.Runtime.RequireServer()
    if not LKS_EletricidadeConstrucao.Core.Runtime.IsServer() then
        error("[LKS_EletricidadeConstrucao_Runtime] This code requires server context but isServer() = false!")
    end
end

--- Ensure code is running in client context, error if not
--- Use at start of client-only files: LKS_EletricidadeConstrucao.Core.Runtime.RequireClient()
function LKS_EletricidadeConstrucao.Core.Runtime.RequireClient()
    if not LKS_EletricidadeConstrucao.Core.Runtime.IsClient() then
        error("[LKS_EletricidadeConstrucao_Runtime] This code requires client context but isClient() = false!")
    end
end

--- Warn if code is running in unexpected context (for debugging)
--- @param expectedContext string "server" or "client"
function LKS_EletricidadeConstrucao.Core.Runtime.WarnIfWrongContext(expectedContext)
    if expectedContext == "server" and not LKS_EletricidadeConstrucao.Core.Runtime.IsServer() then
        LKS_EletricidadeConstrucao.Warn("Code expected server context but running on client!")
    elseif expectedContext == "client" and not LKS_EletricidadeConstrucao.Core.Runtime.IsClient() then
        LKS_EletricidadeConstrucao.Warn("Code expected client context but running on server!")
    end
end

-- ============================================================================
-- CONTEXT INFORMATION
-- ============================================================================

--- Get detailed context information (for logging/debugging)
--- @return table Context info with isServer, isClient, gameMode, etc.
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

--- Print current runtime context (for debugging)
function LKS_EletricidadeConstrucao.Core.Runtime.PrintContext()
    local info = LKS_EletricidadeConstrucao.Core.Runtime.GetContextInfo()
    LKS_EletricidadeConstrucao.Print("=== Runtime Context ===")
    LKS_EletricidadeConstrucao.Print(string.format("  Game Mode: %s", info.gameMode))
    LKS_EletricidadeConstrucao.Print(string.format("  Is Server: %s", tostring(info.isServer)))
    LKS_EletricidadeConstrucao.Print(string.format("  Is Client: %s", tostring(info.isClient)))
    LKS_EletricidadeConstrucao.Print(string.format("  Is Singleplayer: %s", tostring(info.isSingleplayer)))
    LKS_EletricidadeConstrucao.Print(string.format("  Is Multiplayer: %s", tostring(info.isMultiplayer)))
    LKS_EletricidadeConstrucao.Print(string.format("  Requires Network Sync: %s", tostring(info.requiresNetworkSync)))
    LKS_EletricidadeConstrucao.Print("======================")
end

-- ============================================================================
-- CONVENIENCE ALIASES (Shorter names for common checks)
-- ============================================================================

-- Short aliases for frequent checks
LKS_EletricidadeConstrucao.IsServer = LKS_EletricidadeConstrucao.Core.Runtime.IsServer
LKS_EletricidadeConstrucao.IsClient = LKS_EletricidadeConstrucao.Core.Runtime.IsClient
LKS_EletricidadeConstrucao.IsMP = LKS_EletricidadeConstrucao.Core.Runtime.IsMultiplayer
LKS_EletricidadeConstrucao.IsSP = LKS_EletricidadeConstrucao.Core.Runtime.IsSingleplayer

-- ============================================================================
-- INITIALIZATION COMPLETE
-- ============================================================================

LKS_EletricidadeConstrucao._InitStatus.RuntimeContextReady = true
LKS_EletricidadeConstrucao.RegisterModule("Core.RuntimeContext", "2.0.0")

-- Print context on load (helpful for debugging)
if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
    LKS_EletricidadeConstrucao.Core.Runtime.PrintContext()
else
    -- Always print basic context info
    local info = LKS_EletricidadeConstrucao.Core.Runtime.GetContextInfo()
    LKS_EletricidadeConstrucao.Print(string.format("Runtime context: %s (Server=%s, Client=%s)", 
        info.gameMode, tostring(info.isServer), tostring(info.isClient)))
end

return LKS_EletricidadeConstrucao.Core.Runtime
