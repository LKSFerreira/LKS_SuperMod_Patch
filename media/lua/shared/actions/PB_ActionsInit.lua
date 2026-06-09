-- PB_ActionsInit.lua
-- Shared actions initialization
-- Loads all TimedActions (run on both client and server)
-- LOCATION: shared/actions/

if not PoweredBuildings then
    print("[PB_ActionsInit] PoweredBuildings namespace not found - skipping module load")
    return
end

print("[PB_ActionsInit] ========================================")
print("[PB_ActionsInit] Loading TimedActions...")
print("[PB_ActionsInit] ========================================")

-- Register module
PoweredBuildings.RegisterModule("PB_ActionsInit")

-- ============================================================
-- LOAD TIMED ACTIONS
-- ============================================================

-- Generator actions
require "actions/PB_Actions_ActivateGenerator"
require "actions/PB_Actions_ConnectBuilding"
require "actions/PB_Actions_DisconnectBuilding"
require "actions/PB_Actions_OpenInfoWindow"

-- TODO: Barrel actions (Phase 5)
-- require "actions/PB_Actions_LinkBarrel"

-- TODO: Light Switch actions (Phase 6)
-- require "actions/PB_Actions_InstallLightSwitch"

-- ============================================================
-- ACTIONS INITIALIZATION COMPLETE
-- ============================================================

print("[PB_ActionsInit] ========================================")
print("[PB_ActionsInit] TimedActions loaded successfully")
print("[PB_ActionsInit] Available actions:")
print("[PB_ActionsInit]   - ActivateGenerator")
print("[PB_ActionsInit]   - ConnectBuilding")
print("[PB_ActionsInit]   - DisconnectBuilding")
print("[PB_ActionsInit]   - OpenInfoWindow")
print("[PB_ActionsInit] ========================================")
