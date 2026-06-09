-- PB_ClientInit.lua
-- Client-side initialization
-- Loads UI, context menus, and input handlers
-- LOCATION: client/

if not PoweredBuildings then
    print("[PB_ClientInit] PoweredBuildings namespace not found - skipping module load")
    return
end

-- Register module
PoweredBuildings.RegisterModule("PB_ClientInit")

-- ============================================================
-- LOAD CONTEXT MENUS
-- ============================================================

-- Generator context menu
require "client/PB_ContextMenu_Generator"

-- Light Switch context menu (Building Power Info from any switch)
require "client/PB_ContextMenu_LightSwitch"

-- Install vanilla lightswitch items with preview
require "client/PB_ContextMenu_LightSwitchInstall"

-- TODO: Barrel context menu (Phase 5)
require "shared/actions/PB_Actions_LinkBarrel"
require "client/PB_ContextMenu_Barrel"

-- ============================================================
-- LOAD UI MODULES
-- ============================================================

-- Generator Info Window
require "client/ui/PB_UI_GeneratorInfoWindow"

-- Debug Panel (Admin/Debug mode, toggle with "-" key)
if PoweredBuildings.Config and PoweredBuildings.Config.DebugMode then
    require "client/ui/PB_UI_DebugPanel"
end

-- Heating client (manages IsoHeatSource objects)
require "client/PB_Heating_Client"

-- Multiplayer client-side reconstruction of building power for loaded squares
require "client/PB_Power_ClientSync"

-- Client-side server command responses / MP action acknowledgements
require "client/PB_ClientCommands"

-- TODO: Range Visualization (Phase 3)
-- require "client/ui/PB_UI_RangeVisualization"

-- ============================================================
-- LOAD INPUT HANDLERS
-- ============================================================

-- TODO: Hotkeys (Phase 9)
-- require "client/input/PB_Input_Hotkeys"

-- ============================================================
-- LOAD RENDERING MODULES
-- ============================================================

-- TODO: Debug overlay (Phase 10)
-- require "client/rendering/PB_Render_DebugOverlay"
