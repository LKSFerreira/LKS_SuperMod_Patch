-- ============================================================================
-- ARQUIVO: LKS_Cooking_SpriteClassification.lua
-- EXTENSÃO: LKS SuperMod Patch (Classificação de Fogões por Sprite)
-- OBJETIVO: Tabela de mapeamento que classifica sprites de IsoStove do jogo
--           base nos tipos do mod (convencional ou indução). Sprites vanilla
--           modernos selecionados manualmente são reclassificados como indução.
--           Resistência elétrica NÃO é tipo separado — é variante visual do
--           tipo Indução com exatamente a mesma mecânica.
-- AUTOR: LKS FERREIRA
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 18/06/2026
-- ============================================================================
--
-- ## COMO USAR:
--
-- 1. Identifique o nome do sprite do fogão no jogo (ex: "appliances_cooking_01_12")
-- 2. Adicione o sprite na tabela LKS_Cooking_TiposPorSprite com o tipo "inducao"
-- 3. Fogões com sprites NÃO listados são tratados como Convencional (gás)
--
-- ## TIPOS DISPONÍVEIS:
--
-- "convencional" → Gás encanado ou botijão. Ignição manual/elétrica.
-- "inducao"      → Só eletricidade. Só panela de metal. Qualidade superior.
--                   (Engloba tanto sprites vanilla reclassificados quanto item craftável)
--
-- O tipo "antigo" (lenha) é identificado pela classe Java IsoFireplace,
-- não por sprite — não precisa estar nesta tabela.
--
-- ============================================================================

--- Mapeamento de sprites vanilla de IsoStove para tipos de fogão do mod.
---
--- Sprites listados aqui são reclassificados de "convencional" (padrão) para "inducao".
--- A resistência elétrica é apenas uma variante visual do tipo Indução — mesma mecânica:
--- só eletricidade, só panela de metal, colocável em balcão, qualidade superior.
---
--- Sprites NÃO listados permanecem como Convencional (gás).
---
--- Para adicionar um sprite: identifique o nome completo do sprite no jogo
--- (use a Debug Tool → Inspetor de Objetos → campo "Sprite") e adicione aqui.
---
--- @type table<string, string>
LKS_Cooking_TiposPorSprite = {
    -- =========================================================================
    -- FOGÕES DE INDUÇÃO (sprites vanilla modernos — seleção manual)
    -- =========================================================================
    -- Adicione aqui os sprites que deseja reclassificar como indução.
    -- Formato: ["nome_completo_do_sprite"] = "inducao",
    --
    -- Exemplos (PLACEHOLDERS — substituir pelos sprites reais após seleção):
    -- ["appliances_cooking_01_12"] = "inducao",
    -- ["appliances_cooking_01_13"] = "inducao",
    -- ["appliances_cooking_01_14"] = "inducao",
    -- ["appliances_cooking_01_15"] = "inducao",
    -- =========================================================================
}

--- Tipo padrão para qualquer IsoStove cujo sprite não esteja mapeado acima.
--- Todos os fogões não reclassificados são tratados como Convencional (gás).
LKS_Cooking_TipoPadrao = "convencional"

--- Retorna o tipo do fogão baseado no nome do sprite do objeto.
---
--- @param nomeSprite string O nome completo do sprite (ex: "appliances_cooking_01_0").
--- @return string O tipo do fogão: "convencional" ou "inducao".
local function obterTipoFogaoPorSprite(nomeSprite)
    if not nomeSprite then
        return LKS_Cooking_TipoPadrao
    end
    return LKS_Cooking_TiposPorSprite[nomeSprite] or LKS_Cooking_TipoPadrao
end

--- Retorna o tipo do fogão baseado no objeto IsoStove do mundo.
---
--- Extrai o nome do sprite do objeto e consulta a tabela de classificação.
--- Para IsoFireplace, retorna "antigo" diretamente (não depende de sprite).
---
--- @param objetoFogao IsoObject O objeto do fogão no mundo.
--- @return string O tipo do fogão: "convencional", "inducao" ou "antigo".
local function obterTipoFogao(objetoFogao)
    if not objetoFogao then
        return LKS_Cooking_TipoPadrao
    end

    if instanceof(objetoFogao, "IsoFireplace") then
        return "antigo"
    end

    local sprite = objetoFogao:getSprite()
    local nomeSprite = sprite and sprite:getName() or nil

    return obterTipoFogaoPorSprite(nomeSprite)
end

return {
    TiposPorSprite = LKS_Cooking_TiposPorSprite,
    TipoPadrao = LKS_Cooking_TipoPadrao,
    obterTipoFogaoPorSprite = obterTipoFogaoPorSprite,
    obterTipoFogao = obterTipoFogao,
}
