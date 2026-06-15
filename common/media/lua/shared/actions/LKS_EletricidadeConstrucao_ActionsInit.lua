-- ============================================================================
-- 💖 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado como parte do LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) por sua fantástica contribuição para a comunidade!
-- ============================================================================

-- LKS_EletricidadeConstrucao_ActionsInit.lua
-- Shared actions initialization
-- Loads all TimedActions (run on both client and server)
-- LOCATION: shared/actions/

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_ActionsInit] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

print("[LKS_EletricidadeConstrucao_ActionsInit] ========================================")
print("[LKS_EletricidadeConstrucao_ActionsInit] Loading TimedActions...")
print("[LKS_EletricidadeConstrucao_ActionsInit] ========================================")

-- Register module
LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ActionsInit")

-- ============================================================
-- LOAD TIMED ACTIONS
-- ============================================================

-- Generator actions
require "actions/LKS_EletricidadeConstrucao_Actions_ActivateGenerator"
require "actions/LKS_EletricidadeConstrucao_Actions_ConnectBuilding"
require "actions/LKS_EletricidadeConstrucao_Actions_DisconnectBuilding"
require "actions/LKS_EletricidadeConstrucao_Actions_OpenInfoWindow"

-- TODO: Barrel actions (Phase 5)
-- require "actions/LKS_EletricidadeConstrucao_Actions_LinkBarrel"

-- TODO: Light Switch actions (Phase 6)
-- require "actions/LKS_EletricidadeConstrucao_Actions_InstallLightSwitch"

-- ============================================================
-- ACTIONS INITIALIZATION COMPLETE
-- ============================================================

print("[LKS_EletricidadeConstrucao_ActionsInit] ========================================")
print("[LKS_EletricidadeConstrucao_ActionsInit] TimedActions loaded successfully")
print("[LKS_EletricidadeConstrucao_ActionsInit] Available actions:")
print("[LKS_EletricidadeConstrucao_ActionsInit]   - ActivateGenerator")
print("[LKS_EletricidadeConstrucao_ActionsInit]   - ConnectBuilding")
print("[LKS_EletricidadeConstrucao_ActionsInit]   - DisconnectBuilding")
print("[LKS_EletricidadeConstrucao_ActionsInit]   - OpenInfoWindow")
print("[LKS_EletricidadeConstrucao_ActionsInit] ========================================")
