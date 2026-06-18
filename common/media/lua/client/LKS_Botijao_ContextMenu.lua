-- ============================================================================
-- ARQUIVO: LKS_Botijao_ContextMenu.lua
-- EXTENSÃO: LKS SuperMod Patch (Menu de Contexto de Botijões de Gás)
-- OBJETIVO: Gerencia interações de instalar, trocar e desinstalar botijões
--           de gás em fogões convencionais via menu de contexto do mundo.
--           Relacionamento 1:1 com dupla validação:
--           - Clicou no fogão → lista botijões próximos para conectar
--           - Clicou no botijão → lista fogões próximos para conectar
-- AUTOR: LKS FERREIRA
-- VERSÃO: 2.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 18/06/2026
-- ============================================================================

require "LKS_Cooking_SpriteClassification"

local DISTANCIA_MAXIMA_MANGUEIRA = 2

--- IDs de itens aceitos como botijão de gás (vanilla + mod).
local IDS_BOTIJAO = {
    ["Base.PropaneTank"] = true,
    ["LKS_Gas.LKS_Botijao15kg"] = true,
    ["LKS_Gas.LKS_Botijao45kg"] = true,
}

--- Itens necessários para instalação completa de um botijão.
local ITENS_INSTALACAO = {
    { id = "Base.RubberHose",      quantidade = 1, nome = "Mangueira de Borracha" },
    { id = "Base.HoseClamp",       quantidade = 2, nome = "Enforca-gato", alternativas = {"Base.HoseClamp", "Base.HoseClamb"} },
    { id = "Base.DuctTape",        quantidade = 1, nome = "Fita Isolante" },
    { id = "Base.HuntingKnife",    quantidade = 1, nome = "Ferramenta de Corte", alternativas = {"Base.KitchenKnife", "Base.HuntingKnife", "Base.Scissors"} },
    { id = "Base.Pliers",          quantidade = 1, nome = "Alicate" },
}

--- Itens necessários para trocar um botijão (reaproveitando mangueira existente).
local ITENS_TROCA = {
    { id = "Base.HoseClamp",       quantidade = 1, nome = "Enforca-gato", alternativas = {"Base.HoseClamp", "Base.HoseClamb"} },
    { id = "Base.Pliers",          quantidade = 1, nome = "Alicate" },
}

-- ============================================================================
-- FUNÇÕES AUXILIARES
-- ============================================================================

--- Verifica se o jogador possui todos os itens necessários para uma operação.
---
--- @param jogador IsoPlayer O jogador a verificar.
--- @param listaItens table Lista de itens requeridos.
--- @return boolean temTodos True se possui todos os itens.
--- @return string|nil itemFaltante Nome do primeiro item faltante.
local function verificarItensNecessarios(jogador, listaItens)
    if not jogador then return false, nil end
    local inventario = jogador:getInventory()
    if not inventario then return false, nil end

    for _, requisito in ipairs(listaItens) do
        local encontrado = false

        if requisito.alternativas then
            for _, alternativaId in ipairs(requisito.alternativas) do
                if inventario:getFirstTypeRecurse(alternativaId) then
                    encontrado = true
                    break
                end
            end
        else
            if inventario:getFirstTypeRecurse(requisito.id) then
                encontrado = true
            end
        end

        if not encontrado then
            return false, requisito.nome
        end
    end

    return true, nil
end

--- Verifica se o fogão já tem um botijão conectado.
---
--- @param fogao IsoObject O fogão a verificar.
--- @return boolean conectado True se há botijão conectado.
local function fogaoTemBotijaoConectado(fogao)
    if not fogao then return false end
    local dadosMod = fogao:getModData()
    return dadosMod and dadosMod.LKS_BotijaoConectado == true or false
end

--- Calcula a chance de vazamento de gás com base nas skills do jogador.
---
--- Condições: soma de Elétrica + Mecânica + Cooking < 6 E pelo menos uma ≤ 1.
--- Chance: 1% quando condições atendidas, 0% caso contrário.
---
--- @param jogador IsoPlayer O jogador realizando a instalação.
--- @return boolean temRisco True se há risco de vazamento.
local function calcularRiscoVazamento(jogador)
    if not jogador then return false end

    local nivelEletrica = jogador:getPerkLevel(Perks.Electricity) or 0
    local nivelMecanica = jogador:getPerkLevel(Perks.Mechanics) or 0
    local nivelCooking = jogador:getPerkLevel(Perks.Cooking) or 0

    local soma = nivelEletrica + nivelMecanica + nivelCooking
    local algumaBaixa = (nivelEletrica <= 1) or (nivelMecanica <= 1) or (nivelCooking <= 1)

    if soma < 6 and algumaBaixa then
        return ZombRand(100) < 1
    end

    return false
end

--- Conecta um botijão ao fogão via moddata.
---
--- @param fogao IsoObject O fogão a conectar.
--- @param jogador IsoPlayer O jogador realizando a ação.
local function conectarBotijao(fogao, jogador)
    if not fogao then return end

    local dadosModFogao = fogao:getModData()
    dadosModFogao.LKS_BotijaoConectado = true

    if calcularRiscoVazamento(jogador) then
        dadosModFogao.LKS_VazamentoGasPendente = true
    end
end

--- Desconecta o botijão do fogão.
---
--- @param fogao IsoObject O fogão a desconectar.
local function desconectarBotijao(fogao)
    if not fogao then return end

    local dadosModFogao = fogao:getModData()
    dadosModFogao.LKS_BotijaoConectado = nil
    dadosModFogao.LKS_VazamentoGasPendente = nil
end

-- ============================================================================
-- BUSCA DE OBJETOS PRÓXIMOS (mesma abordagem do ISBBQMenu vanilla)
-- ============================================================================

--- Busca botijões de gás nos tiles ao redor de um fogão (inventário + chão).
--- Usa a mesma abordagem do vanilla ISBBQMenu.FindPropaneTank.
---
--- @param fogao IsoObject O fogão de referência.
--- @param jogador IsoPlayer O jogador (para verificar inventário).
--- @return table Lista de botijões encontrados {item, origem, descricao}.
local function buscarBotijoesProximos(fogao, jogador)
    local resultados = {}
    if not fogao then return resultados end

    local fogaoX = fogao:getX()
    local fogaoY = fogao:getY()
    local fogaoZ = fogao:getZ()
    local celula = getCell()
    if not celula then return resultados end

    for deslocamentoY = -DISTANCIA_MAXIMA_MANGUEIRA, DISTANCIA_MAXIMA_MANGUEIRA do
        for deslocamentoX = -DISTANCIA_MAXIMA_MANGUEIRA, DISTANCIA_MAXIMA_MANGUEIRA do
            local quadrado = celula:getGridSquare(fogaoX + deslocamentoX, fogaoY + deslocamentoY, fogaoZ)
            if quadrado then
                local objetosMundoNoQuadrado = quadrado:getWorldObjects()
                if objetosMundoNoQuadrado then
                    for indice = 0, objetosMundoNoQuadrado:size() - 1 do
                        local objetoMundo = objetosMundoNoQuadrado:get(indice)
                        if objetoMundo and objetoMundo:getItem() then
                            local tipoCompleto = objetoMundo:getItem():getFullType()
                            if IDS_BOTIJAO[tipoCompleto] then
                                table.insert(resultados, {
                                    item = objetoMundo,
                                    nome = objetoMundo:getItem():getDisplayName() or tipoCompleto,
                                    noChao = true,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    -- Verifica inventário do jogador
    if jogador then
        local inventario = jogador:getInventory()
        if inventario then
            for idBotijao, _ in pairs(IDS_BOTIJAO) do
                local item = inventario:getFirstTypeRecurse(idBotijao)
                if item then
                    table.insert(resultados, {
                        item = item,
                        nome = item:getDisplayName() or idBotijao,
                        noChao = false,
                    })
                end
            end
        end
    end

    return resultados
end

--- Busca fogões IsoStove nos tiles ao redor de um ponto.
---
--- @param centroX number Coordenada X central.
--- @param centroY number Coordenada Y central.
--- @param centroZ number Coordenada Z central.
--- @return table Lista de fogões encontrados.
local function buscarFogoesProximos(centroX, centroY, centroZ)
    local resultados = {}
    local celula = getCell()
    if not celula then return resultados end

    for deslocamentoY = -DISTANCIA_MAXIMA_MANGUEIRA, DISTANCIA_MAXIMA_MANGUEIRA do
        for deslocamentoX = -DISTANCIA_MAXIMA_MANGUEIRA, DISTANCIA_MAXIMA_MANGUEIRA do
            local quadrado = celula:getGridSquare(centroX + deslocamentoX, centroY + deslocamentoY, centroZ)
            if quadrado then
                local objetos = quadrado:getObjects()
                if objetos then
                    for indice = 0, objetos:size() - 1 do
                        local objeto = objetos:get(indice)
                        if objeto and instanceof(objeto, "IsoStove") then
                            local nomeFogao = objeto:getName() or getText("IGUI_LKS_Fogao") or "Fogão"
                            table.insert(resultados, {
                                fogao = objeto,
                                nome = nomeFogao,
                            })
                        end
                    end
                end
            end
        end
    end

    return resultados
end

-- ============================================================================
-- MENU DE CONTEXTO — DUPLA VALIDAÇÃO
-- ============================================================================

--- Handler principal do menu de contexto do mundo.
--- Detecta fogões e botijões clicados e oferece opções de conexão.
---
--- @param jogadorNumero number Índice do jogador.
--- @param menuContexto ISContextMenu O menu de contexto.
--- @param objetosMundo table Objetos clicados.
local function adicionarOpcoesMenuBotijao(jogadorNumero, menuContexto, objetosMundo)
    local jogador = getSpecificPlayer(jogadorNumero)
    if not jogador then return end

    local fogaoClicado = nil
    local botijaoClicado = nil

    -- Identifica o que foi clicado
    for _, objetoMundo in ipairs(objetosMundo) do
        local quadrado = objetoMundo:getSquare()
        if quadrado then
            -- Procura IsoStove no quadrado clicado
            local objetos = quadrado:getObjects()
            if objetos then
                for indice = 0, objetos:size() - 1 do
                    local objeto = objetos:get(indice)
                    if objeto and instanceof(objeto, "IsoStove") and not fogaoClicado then
                        fogaoClicado = objeto
                    end
                end
            end

            -- Procura botijões no chão do quadrado clicado
            local objetosNoChao = quadrado:getWorldObjects()
            if objetosNoChao then
                for indice = 0, objetosNoChao:size() - 1 do
                    local objetoChao = objetosNoChao:get(indice)
                    if objetoChao and objetoChao:getItem() then
                        local tipoCompleto = objetoChao:getItem():getFullType()
                        if IDS_BOTIJAO[tipoCompleto] and not botijaoClicado then
                            botijaoClicado = objetoChao
                        end
                    end
                end
            end
        end
    end

    -- CAMINHO 1: Clicou num fogão → mostra botijões próximos
    if fogaoClicado then
        local temConexao = fogaoTemBotijaoConectado(fogaoClicado)

        if temConexao then
            -- Opções: Trocar ou Desinstalar
            local botijoesProximos = buscarBotijoesProximos(fogaoClicado, jogador)

            if #botijoesProximos > 0 then
                for _, botijaoInfo in ipairs(botijoesProximos) do
                    local temItensTroca, faltanteTroca = verificarItensNecessarios(jogador, ITENS_TROCA)
                    local textoOpcao = (getText("IGUI_LKS_TrocarBotijao") or "Trocar Botijão") .. " ← " .. botijaoInfo.nome
                    local opcaoTrocar = menuContexto:addOption(textoOpcao, objetosMundo, function()
                        desconectarBotijao(fogaoClicado)
                        conectarBotijao(fogaoClicado, jogador)
                    end)
                    if not temItensTroca then
                        opcaoTrocar.notAvailable = true
                        local tooltipFalta = ISWorldObjectContextMenu.addToolTip()
                        tooltipFalta.description = (getText("IGUI_LKS_FaltaItem") or "Falta: ") .. (faltanteTroca or "?")
                        opcaoTrocar.toolTip = tooltipFalta
                    end
                end
            end

            local opcaoDesinstalar = menuContexto:addOption(
                getText("IGUI_LKS_DesinstalarBotijao") or "Desinstalar Botijão",
                objetosMundo,
                function() desconectarBotijao(fogaoClicado) end
            )
        else
            -- Opção: Instalar botijão
            local botijoesProximos = buscarBotijoesProximos(fogaoClicado, jogador)

            if #botijoesProximos > 0 then
                for _, botijaoInfo in ipairs(botijoesProximos) do
                    local temItensInstalacao, faltanteInstalacao = verificarItensNecessarios(jogador, ITENS_INSTALACAO)
                    local textoOpcao = (getText("IGUI_LKS_InstalarBotijao") or "Instalar Botijão") .. " ← " .. botijaoInfo.nome
                    local opcaoInstalar = menuContexto:addOption(textoOpcao, objetosMundo, function()
                        conectarBotijao(fogaoClicado, jogador)
                    end)
                    if not temItensInstalacao then
                        opcaoInstalar.notAvailable = true
                        local tooltipFalta = ISWorldObjectContextMenu.addToolTip()
                        tooltipFalta.description = (getText("IGUI_LKS_FaltaItem") or "Falta: ") .. (faltanteInstalacao or "?")
                        opcaoInstalar.toolTip = tooltipFalta
                    end
                end
            end
        end
    end

    -- CAMINHO 2: Clicou num botijão → mostra fogões próximos
    if botijaoClicado then
        local botijaoX = botijaoClicado:getX()
        local botijaoY = botijaoClicado:getY()
        local botijaoZ = botijaoClicado:getZ()

        local fogoesProximos = buscarFogoesProximos(botijaoX, botijaoY, botijaoZ)

        for _, fogaoInfo in ipairs(fogoesProximos) do
            local temConexao = fogaoTemBotijaoConectado(fogaoInfo.fogao)

            if temConexao then
                local temItensTroca, faltanteTroca = verificarItensNecessarios(jogador, ITENS_TROCA)
                local textoOpcao = (getText("IGUI_LKS_TrocarBotijao") or "Trocar Botijão") .. " → " .. fogaoInfo.nome
                local opcaoTrocar = menuContexto:addOption(textoOpcao, objetosMundo, function()
                    desconectarBotijao(fogaoInfo.fogao)
                    conectarBotijao(fogaoInfo.fogao, jogador)
                end)
                if not temItensTroca then
                    opcaoTrocar.notAvailable = true
                    local tooltipFalta = ISWorldObjectContextMenu.addToolTip()
                    tooltipFalta.description = (getText("IGUI_LKS_FaltaItem") or "Falta: ") .. (faltanteTroca or "?")
                    opcaoTrocar.toolTip = tooltipFalta
                end
            else
                local temItensInstalacao, faltanteInstalacao = verificarItensNecessarios(jogador, ITENS_INSTALACAO)
                local textoOpcao = (getText("IGUI_LKS_InstalarBotijao") or "Instalar Botijão") .. " → " .. fogaoInfo.nome
                local opcaoInstalar = menuContexto:addOption(textoOpcao, objetosMundo, function()
                    conectarBotijao(fogaoInfo.fogao, jogador)
                end)
                if not temItensInstalacao then
                    opcaoInstalar.notAvailable = true
                    local tooltipFalta = ISWorldObjectContextMenu.addToolTip()
                    tooltipFalta.description = (getText("IGUI_LKS_FaltaItem") or "Falta: ") .. (faltanteInstalacao or "?")
                    opcaoInstalar.toolTip = tooltipFalta
                end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(adicionarOpcoesMenuBotijao)
