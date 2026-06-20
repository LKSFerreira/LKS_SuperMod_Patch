-- ============================================================================
-- ARQUIVO: LKS_Cooking_Quality.lua
-- EXTENSÃO: LKS SuperMod Patch (Sistema de Qualidade de Comida)
-- OBJETIVO: Calcula qualidade da comida baseada no tipo de fogão, nível de
--           Cooking do jogador e status de limpeza do aparelho. Gerencia
--           chance de queimar para fogões antigos (lenha).
-- AUTOR: LKS FERREIRA
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 18/06/2026
-- ============================================================================

-- ============================================================================
-- NÍVEIS DE QUALIDADE
-- ============================================================================

local NIVEIS_QUALIDADE = {
    RUIM      = { id = 1, nome = "Ruim",      multiplicadorBuff = -1.0 },
    NORMAL    = { id = 2, nome = "Normal",     multiplicadorBuff = 0 },
    BOA       = { id = 3, nome = "Boa",        multiplicadorBuff = 1.0 },
    EXCELENTE = { id = 4, nome = "Excelente",  multiplicadorBuff = 2.0 },
}

-- ============================================================================
-- STATUS DE LIMPEZA
-- ============================================================================

local STATUS_LIMPEZA = {
    BRILHANDO  = { id = 1, nome = "Brilhando de tão limpo", bonusBuff = 1.0,  chanceEstragar = 0 },
    LIMPO      = { id = 2, nome = "Limpo",                  bonusBuff = 0,    chanceEstragar = 0 },
    SUJO       = { id = 3, nome = "Sujo",                   bonusBuff = -0.5, chanceEstragar = 0 },
    MUITO_SUJO = { id = 4, nome = "Muito Sujo",             bonusBuff = 0,    chanceEstragar = 15 },
    IMUNDO     = { id = 5, nome = "Imundo",                 bonusBuff = 0,    chanceEstragar = 30 },
}

-- ============================================================================
-- CHANCE DE QUEIMAR (FOGÃO ANTIGO)
-- ============================================================================

--- Calcula a chance de queimar comida no fogão antigo (lenha).
---
--- Base de 10%, reduz 1% por nível de Cooking. Zero em Cooking 10.
---
--- @param nivelCooking number O nível de Cooking do jogador (0-10).
--- @return number A chance percentual de queimar (0-10).
local function calcularChanceQueimar(nivelCooking)
    local nivel = nivelCooking or 0
    return math.max(0, 10 - nivel)
end

--- Verifica se a comida queimou com base na chance calculada.
---
--- @param nivelCooking number O nível de Cooking do jogador.
--- @return boolean queimou True se a comida queimou.
local function verificarSeQueimou(nivelCooking)
    local chance = calcularChanceQueimar(nivelCooking)
    if chance <= 0 then return false end
    return ZombRand(100) < chance
end

-- ============================================================================
-- CÁLCULO DE QUALIDADE
-- ============================================================================

--- Calcula a qualidade final da comida baseada em múltiplos fatores.
---
--- @param tipoFogao string O tipo do fogão ("convencional", "antigo", "inducao").
--- @param nivelCooking number O nível de Cooking do jogador.
--- @param statusLimpeza table|nil O status de limpeza do fogão (da tabela STATUS_LIMPEZA).
--- @return table O nível de qualidade resultante (da tabela NIVEIS_QUALIDADE).
--- @return boolean queimou Se a comida queimou no processo.
local function calcularQualidade(tipoFogao, nivelCooking, statusLimpeza)
    local nivel = nivelCooking or 0
    local limpeza = statusLimpeza or STATUS_LIMPEZA.LIMPO

    -- Fogão antigo: chance de queimar
    if tipoFogao == "antigo" then
        if verificarSeQueimou(nivel) then
            return NIVEIS_QUALIDADE.RUIM, true
        end

        -- Verifica limpeza (Muito Sujo/Imundo)
        if limpeza.chanceEstragar > 0 and ZombRand(100) < limpeza.chanceEstragar then
            return NIVEIS_QUALIDADE.RUIM, true
        end

        return NIVEIS_QUALIDADE.NORMAL, false
    end

    -- Fogão convencional: qualidade boa
    if tipoFogao == "convencional" then
        if limpeza.chanceEstragar > 0 and ZombRand(100) < limpeza.chanceEstragar then
            return NIVEIS_QUALIDADE.RUIM, true
        end
        return NIVEIS_QUALIDADE.BOA, false
    end

    -- Fogão de indução: qualidade boa a excelente
    if tipoFogao == "inducao" then
        if nivel >= 10 then
            return NIVEIS_QUALIDADE.EXCELENTE, false
        end
        return NIVEIS_QUALIDADE.BOA, false
    end

    return NIVEIS_QUALIDADE.NORMAL, false
end

-- ============================================================================
-- GERENCIAMENTO DE LIMPEZA DO FOGÃO
-- ============================================================================

--- Obtém o status de limpeza atual de um fogão via moddata.
---
--- @param fogao IsoObject O fogão a verificar.
--- @return table O status de limpeza atual.
local function obterStatusLimpeza(fogao)
    if not fogao then return STATUS_LIMPEZA.LIMPO end

    local dadosMod = fogao:getModData()
    local nivelLimpeza = dadosMod and dadosMod.LKS_LimpezaNivel or 2

    for _, status in pairs(STATUS_LIMPEZA) do
        if status.id == nivelLimpeza then
            return status
        end
    end

    return STATUS_LIMPEZA.LIMPO
end

--- Degrada o status de limpeza do fogão após um cozimento.
---
--- @param fogao IsoObject O fogão a degradar.
local function degradarLimpeza(fogao)
    if not fogao then return end

    local dadosMod = fogao:getModData()
    local nivelAtual = dadosMod.LKS_LimpezaNivel or 2

    if nivelAtual < 5 then
        dadosMod.LKS_LimpezaNivel = nivelAtual + 1
    end
end

--- Limpa o fogão restaurando o status de limpeza.
---
--- @param fogao IsoObject O fogão a limpar.
--- @param limpezaCompleta boolean Se true (tem produto de limpeza), restaura para Brilhando.
local function limparFogao(fogao, limpezaCompleta)
    if not fogao then return end

    local dadosMod = fogao:getModData()
    if limpezaCompleta then
        dadosMod.LKS_LimpezaNivel = 1
    else
        dadosMod.LKS_LimpezaNivel = 2
    end
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================

return {
    NIVEIS_QUALIDADE = NIVEIS_QUALIDADE,
    STATUS_LIMPEZA = STATUS_LIMPEZA,
    calcularChanceQueimar = calcularChanceQueimar,
    verificarSeQueimou = verificarSeQueimou,
    calcularQualidade = calcularQualidade,
    obterStatusLimpeza = obterStatusLimpeza,
    degradarLimpeza = degradarLimpeza,
    limparFogao = limparFogao,
}
