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

-- ============================================================================
-- ARQUIVO: LKS_EletricidadeConstrucao_Init.lua
-- OBJETIVO: Shim de compatibilidade para evitar dupla inicialização.
-- ============================================================================

-- A inicialização real fica em 0_LKS_EletricidadeConstrucao_Init.lua para garantir precedência
-- alfabética no carregamento automático do Project Zomboid.
if LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao._InitTimestamp then
    return LKS_EletricidadeConstrucao
end

local sucesso, resultado = pcall(require, "0_LKS_EletricidadeConstrucao_Init")

if sucesso then
    return resultado
end

print("[LKS_EletricidadeConstrucao_Init] WARNING: 0_LKS_EletricidadeConstrucao_Init.lua não pôde ser carregado: " .. tostring(resultado))
return LKS_EletricidadeConstrucao
