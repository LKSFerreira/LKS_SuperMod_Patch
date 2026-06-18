-- ============================================================================
-- ARQUIVO: LKS_Botijao_ContextMenu.lua
-- EXTENSÃO: LKS SuperMod Patch (Menu de Contexto de Botijões de Gás)
-- OBJETIVO: Gerencia interações de instalar, trocar e desinstalar botijões
--           de gás em fogões convencionais via menu de contexto do mundo.
-- AUTOR: LKS FERREIRA
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 18/06/2026
-- ============================================================================

local DISTANCIA_MAXIMA_MANGUEIRA = 2

--- Itens necessários para instalação completa de um botijão.
local ITENS_INSTALACAO = {
    { id = "Base.RubberHose",      quantidade = 1, nome = "Mangueira de Borracha" },
    { id = "Base.HoseClamb",       quantidade = 2, nome = "Enforca-gato" },
    { id = "Base.DuctTape",        quantidade = 1, nome = "Fita Isolante" },
    { id = "Base.HuntingKnife",    quantidade = 1, nome = "Ferramenta de Corte", alternativas = {"Base.KitchenKnife", "Base.HuntingKnife", "Base.Scissors"} },
    { id = "Base.Pliers",          quantidade = 1, nome = "Alicate" },
}

--- Itens necessários para trocar um botijão (reaproveitando mangueira existente).
local ITENS_TROCA = {
    { id = "Base.HoseClamb",       quantidade = 1, nome = "Enforca-gato" },
    { id = "Base.Pliers",          quantidade = 1, nome = "Alicate" },
}

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
            local item = inventario:getFirstTypeRecurse(requisito.id)
            if item then
                encontrado = true
            end
        end

        if not encontrado then
            return false, requisito.nome
        end
    end

    return true, nil
end

--- Verifica se um fogão convencional está na distância permitida do botijão.
---
--- @param botijao IsoObject O botijão no mundo.
--- @param fogao IsoObject O fogão no mundo.
--- @return boolean dentroDoAlcance True se a distância é ≤ 2 tiles.
local function dentroDoAlcanceMangueira(botijao, fogao)
    if not botijao or not fogao then return false end

    local distanciaX = math.abs(botijao:getX() - fogao:getX())
    local distanciaY = math.abs(botijao:getY() - fogao:getY())
    local distanciaZ = math.abs(botijao:getZ() - fogao:getZ())

    return distanciaX <= DISTANCIA_MAXIMA_MANGUEIRA
        and distanciaY <= DISTANCIA_MAXIMA_MANGUEIRA
        and distanciaZ == 0
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
--- @param botijao IsoObject O botijão sendo conectado.
--- @param jogador IsoPlayer O jogador realizando a ação.
local function conectarBotijao(fogao, botijao, jogador)
    if not fogao or not botijao then return end

    local dadosModFogao = fogao:getModData()
    dadosModFogao.LKS_BotijaoConectado = true
    dadosModFogao.LKS_BotijaoX = botijao:getX()
    dadosModFogao.LKS_BotijaoY = botijao:getY()
    dadosModFogao.LKS_BotijaoZ = botijao:getZ()

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
    dadosModFogao.LKS_BotijaoX = nil
    dadosModFogao.LKS_BotijaoY = nil
    dadosModFogao.LKS_BotijaoZ = nil
    dadosModFogao.LKS_VazamentoGasPendente = nil
end

--- Constrói as opções do menu de contexto para botijões.
---
--- @param jogadorNumero number Índice do jogador.
--- @param menuContexto ISContextMenu O menu de contexto.
--- @param objetosMundo table Objetos clicados.
local function adicionarOpcoesMenuBotijao(jogadorNumero, menuContexto, objetosMundo)
    local jogador = getSpecificPlayer(jogadorNumero)
    if not jogador then return end

    for _, objetoMundo in ipairs(objetosMundo) do
        local tipoObjeto = objetoMundo:getType() or ""
        local ehBotijao = tipoObjeto == "LKS_Botijao15kg" or tipoObjeto == "LKS_Botijao45kg"
            or tipoObjeto == "PropaneTank"

        if not ehBotijao then
            local nomeSprite = objetoMundo:getSpriteName() or ""
            ehBotijao = nomeSprite:find("PropaneTank") or nomeSprite:find("LKS_Botijao")
        end

        if ehBotijao then
            local quadradoBotijao = objetoMundo:getSquare()
            if not quadradoBotijao then return end

            -- Busca fogões próximos
            local celula = getCell()
            if not celula then return end

            for deslocamentoX = -DISTANCIA_MAXIMA_MANGUEIRA, DISTANCIA_MAXIMA_MANGUEIRA do
                for deslocamentoY = -DISTANCIA_MAXIMA_MANGUEIRA, DISTANCIA_MAXIMA_MANGUEIRA do
                    local quadrado = celula:getGridSquare(
                        quadradoBotijao:getX() + deslocamentoX,
                        quadradoBotijao:getY() + deslocamentoY,
                        quadradoBotijao:getZ()
                    )
                    if quadrado then
                        local objetos = quadrado:getObjects()
                        if objetos then
                            for indice = 0, objetos:size() - 1 do
                                local objeto = objetos:get(indice)
                                if objeto and instanceof(objeto, "IsoStove") then
                                    local fogao = objeto
                                    local temConexao = fogaoTemBotijaoConectado(fogao)
                                    local nomeFogao = fogao:getName() or getText("IGUI_LKS_Fogao") or "Fogão"

                                    if temConexao then
                                        -- Opção: Trocar botijão
                                        local temItensTroca, faltanteTroca = verificarItensNecessarios(jogador, ITENS_TROCA)
                                        local opcaoTrocar = menuContexto:addOption(
                                            getText("IGUI_LKS_TrocarBotijao") or "Trocar Botijão → " .. nomeFogao,
                                            objetosMundo,
                                            function()
                                                desconectarBotijao(fogao)
                                                conectarBotijao(fogao, objetoMundo, jogador)
                                            end
                                        )
                                        if not temItensTroca then
                                            opcaoTrocar.notAvailable = true
                                            local tooltipFalta = ISWorldObjectContextMenu.addToolTip()
                                            tooltipFalta.description = (getText("IGUI_LKS_FaltaItem") or "Falta: ") .. (faltanteTroca or "?")
                                            opcaoTrocar.toolTip = tooltipFalta
                                        end

                                        -- Opção: Desinstalar botijão
                                        menuContexto:addOption(
                                            getText("IGUI_LKS_DesinstalarBotijao") or "Desinstalar Botijão ← " .. nomeFogao,
                                            objetosMundo,
                                            function()
                                                desconectarBotijao(fogao)
                                            end
                                        )
                                    else
                                        -- Opção: Instalar botijão
                                        local temItensInstalacao, faltanteInstalacao = verificarItensNecessarios(jogador, ITENS_INSTALACAO)
                                        local opcaoInstalar = menuContexto:addOption(
                                            getText("IGUI_LKS_InstalarBotijao") or "Instalar Botijão → " .. nomeFogao,
                                            objetosMundo,
                                            function()
                                                conectarBotijao(fogao, objetoMundo, jogador)
                                            end
                                        )
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
                    end
                end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(adicionarOpcoesMenuBotijao)
