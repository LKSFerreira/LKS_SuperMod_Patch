-- ============================================================================
-- 💖 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado como parte do LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3097103233) por sua fantástica contribuição para a comunidade!
-- ============================================================================

-- PB_ClientInit.lua
print("[LKS PATCH - PB_ClientInit.lua] Carregando Inicialização de Cliente do PoweredBuildings...")
-- Client-side initialization
-- Loads UI, context menus, and input handlers
-- LOCATION: client

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
require "PB_ContextMenu_Generator"

-- Light Switch context menu (Building Power Info from any switch)
require "PB_ContextMenu_LightSwitch"

-- Install vanilla lightswitch items with preview
require "PB_ContextMenu_LightSwitchInstall"

-- TODO: Barrel context menu (Phase 5)
require "actions/PB_Actions_LinkBarrel"
require "PB_ContextMenu_Barrel"

-- ============================================================
-- LOAD UI MODULES
-- ============================================================

-- Generator Info Window
require "ui/PB_UI_GeneratorInfoWindow"

-- Debug Panel (Admin/Debug mode, toggle with "-" key)
if PoweredBuildings.Config and PoweredBuildings.Config.DebugMode then
    require "ui/PB_UI_DebugPanel"
end

-- Heating client (manages IsoHeatSource objects)
require "PB_Heating_Client"

-- Multiplayer client-side reconstruction of building power for loaded squares
require "PB_Power_ClientSync"

-- Client-side server command responses / MP action acknowledgements
require "PB_ClientCommands"

-- TODO: Range Visualization (Phase 3)
-- require "ui/PB_UI_RangeVisualization"

-- ============================================================
-- LOAD INPUT HANDLERS
-- ============================================================

-- TODO: Hotkeys (Phase 9)
-- require "input/PB_Input_Hotkeys"

-- ============================================================
-- LOAD RENDERING MODULES
-- ============================================================

-- TODO: Debug overlay (Phase 10)
-- require "rendering/PB_Render_DebugOverlay"

print("[LKS PATCH - PB_ClientInit.lua] Carregado com sucesso!")
