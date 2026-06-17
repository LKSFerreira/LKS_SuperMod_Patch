-- ============================================================================
-- ARQUIVO: LKS_EletricidadeConstrucao_UI_DebugPanel.lua
-- EXTENSÃO: LKS SuperMod Patch (Build 42)
-- OBJETIVO: REDIRECIONAMENTO — Este arquivo foi absorvido pela ferramenta
--           unificada LKS_Debug_Tool.lua (F12). Mantido apenas para
--           compatibilidade de carregamento. Funcionalidade de IsoRegions
--           será migrada como aba futura na ferramenta unificada.
-- AUTOR: LKSFERREIRA
-- DATA DE ATUALIZAÇÃO: 16/06/2026
-- ============================================================================

if not LKS_EletricidadeConstrucao then
    return
end

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_UI_DebugPanel")

-- A funcionalidade deste painel foi absorvida pelo LKS_Debug_Tool.lua (F12).
-- A tecla '-' agora também abre a ferramenta unificada como atalho alternativo.
local function OnKeyPressed(key)
    if key == 12 or key == 74 then
        if LKS_DebugTool and LKS_DebugTool.toggle then
            LKS_DebugTool.toggle()
        end
    end
end

Events.OnKeyPressed.Add(OnKeyPressed)

print("[LKS PATCH - LKS_EletricidadeConstrucao_UI_DebugPanel.lua] Redirecionado para LKS_Debug_Tool.lua (F12 ou tecla '-').")
