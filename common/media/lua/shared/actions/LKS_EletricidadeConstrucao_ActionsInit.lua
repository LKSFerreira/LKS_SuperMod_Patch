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

-- ARQUIVO: LKS_EletricidadeConstrucao_ActionsInit.lua
-- OBJETIVO: Inicialização e carregamento das Ações Temporizadas (TimedActions) compartilhadas.
-- Versão: 2.0.0-alpha
-- Data: 15 de Junho de 2026

-- Garante que o namespace principal exista
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_ActionsInit] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ActionsInit", "2.0.0")

-- ============================================================================
-- CARREGAMENTO DAS AÇÕES TEMPORIZADAS (TIMED ACTIONS)
-- ============================================================================

-- Ações de controle e conexão de geradores
require "actions/LKS_EletricidadeConstrucao_Actions_ActivateGenerator"
require "actions/LKS_EletricidadeConstrucao_Actions_ConnectBuilding"
require "actions/LKS_EletricidadeConstrucao_Actions_DisconnectBuilding"
require "actions/LKS_EletricidadeConstrucao_Actions_OpenInfoWindow"

-- Ações de vinculação de barris auxiliares de combustível
require "actions/LKS_EletricidadeConstrucao_Actions_LinkBarrel"

if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
    LKS_EletricidadeConstrucao.Print("Ações temporizadas (TimedActions) carregadas com sucesso:")
    LKS_EletricidadeConstrucao.Print("  - ActivateGenerator")
    LKS_EletricidadeConstrucao.Print("  - ConnectBuilding")
    LKS_EletricidadeConstrucao.Print("  - DisconnectBuilding")
    LKS_EletricidadeConstrucao.Print("  - OpenInfoWindow")
    LKS_EletricidadeConstrucao.Print("  - LinkBarrel")
end
