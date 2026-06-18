-- ============================================================================
-- ARQUIVO: LKS_Cooking_GasSystem.lua
-- EXTENSÃO: LKS SuperMod Patch (Sistema de Gás Encanado)
-- OBJETIVO: Gerencia o fornecimento de gás encanado como utilidade urbana
--           com corte programado (análogo à água encanada do vanilla).
--           Fornece funções de verificação de gás e fontes de calor para
--           ignição manual dos fogões convencionais.
-- AUTOR: LKS FERREIRA
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 18/06/2026
-- ============================================================================

require "LKS_Cooking_SpriteClassification"

-- ============================================================================
-- CONFIGURAÇÃO
-- ============================================================================

local CONFIGURACAO_GAS = {
    --- Dia de corte do gás encanado. -1 = mesmo dia da água.
    diaCorteGas = -1,

    --- Se o sistema de gás está habilitado globalmente.
    gasHabilitado = true,
}

-- ============================================================================
-- VERIFICAÇÃO DE GÁS ENCANADO
-- ============================================================================

--- Carrega configuração de gás do sandbox options.
---
--- @return table Configuração atualizada com valores do sandbox.
local function carregarConfiguracaoSandbox()
    local opcoesSandbox = SandboxVars and SandboxVars.LKS_EletricidadeConstrucao or nil
    if opcoesSandbox then
        if opcoesSandbox.GasShutoffDay ~= nil then
            CONFIGURACAO_GAS.diaCorteGas = opcoesSandbox.GasShutoffDay
        end
        if opcoesSandbox.GasEnabled ~= nil then
            CONFIGURACAO_GAS.gasHabilitado = opcoesSandbox.GasEnabled
        end
    end
    return CONFIGURACAO_GAS
end

--- Obtém o dia atual do mundo em jogo.
---
--- @return number O dia atual do mundo (começando em 0).
local function obterDiaMundoAtual()
    local tempoJogo = getGameTime and getGameTime()
    if not tempoJogo then return 0 end
    return tempoJogo:getNightsSurvived() or 0
end

--- Obtém o dia de corte da água encanada (utilidade vanilla).
---
--- @return number O dia em que a água é cortada (-1 se infinito).
local function obterDiaCorteAgua()
    local sucesso, valor = pcall(function()
        return getSandboxOptions():getOptionByName("WaterShutModifier"):getValue()
    end)
    if sucesso and type(valor) == "number" then
        return valor
    end
    return 30
end

--- Verifica se o gás encanado está disponível no momento atual do jogo.
---
--- A lógica segue o mesmo princípio da água encanada:
--- - Antes do dia de corte: gás disponível (ilimitado)
--- - Após o dia de corte: gás cortado (requer botijão)
--- - Se diaCorteGas == -1: usa o mesmo dia da água
--- - Se diaCorteGas == 0: gás infinito (nunca corta)
---
--- @return boolean True se o gás encanado está disponível.
local function gasEncanadoDisponivel()
    local configuracao = carregarConfiguracaoSandbox()

    if not configuracao.gasHabilitado then
        return false
    end

    local diaCorte = configuracao.diaCorteGas
    if diaCorte == -1 then
        diaCorte = obterDiaCorteAgua()
    end

    if diaCorte == 0 then
        return true
    end

    local diaAtual = obterDiaMundoAtual()
    return diaAtual < diaCorte
end

-- ============================================================================
-- VERIFICAÇÃO DE FONTE DE CALOR (IGNIÇÃO MANUAL)
-- ============================================================================

--- IDs de itens aceitos como fonte de calor para ignição manual de fogões.
--- Inclui todos os itens vanilla com tag START_FIRE e o acendedor do mod.
local FONTES_CALOR_ACEITAS = {
    "Base.Lighter",
    "Base.LighterDisposable",
    "Base.LighterBBQ",
    "Base.Lighter_Battery",
    "Base.Matches",
    "Base.Matchbox",
    "Base.MagnesiumFirestarter",
    "Base.CandleLit",
    "LKS_Utilities.LKS_AcendedorImprovisado",
}

--- Verifica se o jogador possui uma fonte de calor no inventário para acender
--- o fogão manualmente (quando não há acendedor elétrico/eletricidade).
---
--- @param jogador IsoPlayer O jogador a verificar.
--- @return boolean temFonte True se possui fonte de calor.
--- @return string|nil nomeFonte Nome do primeiro item encontrado, ou nil.
local function verificarFonteCalorInventario(jogador)
    if not jogador then return false, nil end
    local inventario = jogador:getInventory()
    if not inventario then return false, nil end

    for _, idItem in ipairs(FONTES_CALOR_ACEITAS) do
        local item = inventario:getFirstTypeRecurse(idItem)
        if item then
            return true, item:getDisplayName() or idItem
        end
    end

    return false, nil
end

-- ============================================================================
-- VERIFICAÇÃO UNIFICADA DE ENERGIA/COMBUSTÍVEL
-- ============================================================================

--- Resultado da verificação de fonte de energia de um fogão.
---
--- @class LKS_FonteEnergiaResultado
--- @field tipo string "eletricidade"|"gas_encanado"|"botijao"|"nenhuma"
--- @field disponivel boolean Se a fonte está ativa e funcional.
--- @field requerIgnicaoManual boolean Se precisa de fonte de calor manual.
--- @field temIgnicaoManual boolean Se o jogador possui fonte de calor.
--- @field nomeFonteCalor string|nil Nome da fonte de calor encontrada.

--- Verifica todas as fontes de energia possíveis para um fogão.
---
--- Para fogão convencional, verifica na ordem:
--- 1. Gás encanado (pré-corte) + eletricidade (acendedor automático)
--- 2. Gás encanado (pré-corte) + fonte de calor manual
--- 3. Botijão conectado + eletricidade (acendedor automático)
--- 4. Botijão conectado + fonte de calor manual
---
--- Para indução, verifica apenas eletricidade (isPowered).
---
--- @param objetoFogao IsoObject O objeto fogão no mundo.
--- @param jogador IsoPlayer O jogador interagindo.
--- @param tipoFogao string O tipo do fogão ("convencional", "inducao", "antigo").
--- @return LKS_FonteEnergiaResultado O resultado da verificação.
local function verificarFonteEnergia(objetoFogao, jogador, tipoFogao)
    local resultado = {
        tipo = "nenhuma",
        disponivel = false,
        requerIgnicaoManual = false,
        temIgnicaoManual = false,
        nomeFonteCalor = nil,
    }

    if not objetoFogao then return resultado end

    -- Indução: eletricidade OU modo emergência (baterias)
    if tipoFogao == "inducao" then
        local containerFogao = objetoFogao:getContainer()
        if containerFogao and containerFogao:isPowered() then
            resultado.tipo = "eletricidade"
            resultado.disponivel = true
            return resultado
        end

        -- Modo emergência: verifica se há conjunto bateria+inversor+transformador conectado
        local dadosMod = objetoFogao:getModData()
        if dadosMod and dadosMod.LKS_ModoBateriaAtivo == true then
            local cargaRestante = dadosMod.LKS_BateriaCargaRestante or 0
            if cargaRestante > 0 then
                resultado.tipo = "bateria_emergencia"
                resultado.disponivel = true
                return resultado
            end
        end

        return resultado
    end

    -- Antigo (lenha): não usa este sistema — gerenciado pelo IsoFireplace vanilla
    if tipoFogao == "antigo" then
        resultado.tipo = "combustivel_solido"
        resultado.disponivel = true
        return resultado
    end

    -- Convencional (gás): verifica múltiplas fontes
    local containerFogao = objetoFogao:getContainer()
    local temEletricidade = containerFogao and containerFogao:isPowered() or false
    local temGasEncanado = gasEncanadoDisponivel()

    -- Verificar botijão conectado via moddata
    local dadosMod = objetoFogao:getModData()
    local temBotijao = dadosMod and dadosMod.LKS_BotijaoConectado == true or false

    -- Verificar fonte de calor manual do jogador
    local temCalorManual, nomeCalor = verificarFonteCalorInventario(jogador)

    if temGasEncanado then
        resultado.tipo = "gas_encanado"
        if temEletricidade then
            resultado.disponivel = true
            resultado.requerIgnicaoManual = false
        elseif temCalorManual then
            resultado.disponivel = true
            resultado.requerIgnicaoManual = true
            resultado.temIgnicaoManual = true
            resultado.nomeFonteCalor = nomeCalor
        else
            resultado.disponivel = false
            resultado.requerIgnicaoManual = true
            resultado.temIgnicaoManual = false
        end
        return resultado
    end

    if temBotijao then
        resultado.tipo = "botijao"
        if temEletricidade then
            resultado.disponivel = true
            resultado.requerIgnicaoManual = false
        elseif temCalorManual then
            resultado.disponivel = true
            resultado.requerIgnicaoManual = true
            resultado.temIgnicaoManual = true
            resultado.nomeFonteCalor = nomeCalor
        else
            resultado.disponivel = false
            resultado.requerIgnicaoManual = true
            resultado.temIgnicaoManual = false
        end
        return resultado
    end

    return resultado
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================

return {
    gasEncanadoDisponivel = gasEncanadoDisponivel,
    verificarFonteCalorInventario = verificarFonteCalorInventario,
    verificarFonteEnergia = verificarFonteEnergia,
    carregarConfiguracaoSandbox = carregarConfiguracaoSandbox,
    FONTES_CALOR_ACEITAS = FONTES_CALOR_ACEITAS,
}
