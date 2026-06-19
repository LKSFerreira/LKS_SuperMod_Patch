-- ============================================================================
-- LKS_Icons.lua — Registro centralizado de ícones do LKS SuperMod Patch
-- ============================================================================
-- Módulo shared que expõe os caminhos de texturas de ícones usados nos menus
-- de contexto e UI do mod. Todos os arquivos que precisam de ícones devem
-- referenciar este módulo em vez de hardcodar paths localmente.
--
-- Uso:
--   local Icones = require("shared/LKS_Icons")
--   opcao.iconTexture = getTexture(Icones.PEGAR)
-- ============================================================================

local LKS_Icons = {
    PEGAR           = "media/ui/LKS_Take.png",
    CONECTAR        = "media/ui/LKS_Connect.png",
    DESCONECTAR     = "media/ui/LKS_Disconnect.png",
    LIGAR           = "media/ui/LKS_Button_Power_On.png",
    DESLIGAR        = "media/ui/LKS_Button_Power_Off.png",
}

return LKS_Icons
