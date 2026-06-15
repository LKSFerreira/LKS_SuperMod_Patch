-- ============================================================================
-- 💖 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado como parte do LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) por sua fantástica contribuição para a comunidade!
-- ============================================================================

-- LKS_EletricidadeConstrucao_ClientInit.lua
print("[LKS PATCH - LKS_EletricidadeConstrucao_ClientInit.lua] Carregando Inicialização de Cliente do LKS_EletricidadeConstrucao...")
-- Client-side initialization
-- Loads UI, context menus, and input handlers
-- LOCATION: client

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_ClientInit] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

if LKS_EletricidadeConstrucao.Config and not LKS_EletricidadeConstrucao.Config.ModEnabled then
    print("[LKS_EletricidadeConstrucao_ClientInit] Eletricidade realista desativada no sandbox - pulando módulo")
    return
end

-- Register module
LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ClientInit")

-- ============================================================
-- LOAD CONTEXT MENUS
-- ============================================================

-- Generator context menu
require "LKS_EletricidadeConstrucao_ContextMenu_Generator"

-- Light Switch context menu (Building Power Info from any switch)
require "LKS_EletricidadeConstrucao_ContextMenu_LightSwitch"

-- Install vanilla lightswitch items with preview
require "LKS_EletricidadeConstrucao_ContextMenu_LightSwitchInstall"

-- TODO: Barrel context menu (Phase 5)
if not LKS_EletricidadeConstrucao.Config or LKS_EletricidadeConstrucao.Config.BarrelSystemEnabled then
    require "actions/LKS_EletricidadeConstrucao_Actions_LinkBarrel"
    require "LKS_EletricidadeConstrucao_ContextMenu_Barrel"
end

-- ============================================================
-- LOAD UI MODULES
-- ============================================================

-- Generator Info Window
require "ui/LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow"

-- Debug Panel (Admin/Debug mode, toggle with "-" key)
if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
    require "ui/LKS_EletricidadeConstrucao_UI_DebugPanel"
end

-- Heating client (manages IsoHeatSource objects)
if not LKS_EletricidadeConstrucao.Config or LKS_EletricidadeConstrucao.Config.HeatingSystemEnabled then
    require "LKS_EletricidadeConstrucao_Heating_Client"
end

-- Multiplayer client-side reconstruction of building power for loaded squares
require "LKS_EletricidadeConstrucao_Power_ClientSync"

-- Client-side server command responses / MP action acknowledgements
require "LKS_EletricidadeConstrucao_ClientCommands"

-- TODO: Range Visualization (Phase 3)
-- require "ui/LKS_EletricidadeConstrucao_UI_RangeVisualization"

-- ============================================================
-- LOAD INPUT HANDLERS
-- ============================================================

-- TODO: Hotkeys (Phase 9)
-- require "input/LKS_EletricidadeConstrucao_Input_Hotkeys"

-- ============================================================
-- LOAD RENDERING MODULES
-- ============================================================

-- TODO: Debug overlay (Phase 10)
-- require "rendering/LKS_EletricidadeConstrucao_Render_DebugOverlay"

print("[LKS PATCH - LKS_EletricidadeConstrucao_ClientInit.lua] Carregado com sucesso!")
