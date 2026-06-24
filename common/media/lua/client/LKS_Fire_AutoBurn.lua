-- ============================================================================
-- ARQUIVO: LKS_Fire_AutoBurn.lua
-- EXTENSAO: LKS SuperMod Patch (Consumo Automatico de Itens no Fogo)
-- OBJETIVO: Quando itens sao colocados diretamente dentro de um container de
--           fogo aceso sem usar "Transformar em Combustivel", eles sao
--           consumidos automaticamente com penalidade de 25% na eficiencia.
-- AUTOR: LKS FERREIRA
-- VERSAO: 1.0 (Project Zomboid Build 42)
-- DATA DA ULTIMA MODIFICACAO: 24/06/2026
-- ============================================================================

require "Camping/ISCampingMenu"
require "cooking/LKS_Fire_FuelClassifier"

-- ============================================================================
-- CONFIGURACAO
-- ============================================================================

--- Intervalo entre verificacoes (usa EveryTenMinutes do PZ = ~6s real).
--- O sistema verifica containers de fogo acesos a cada tick do evento.
local MODDATA_JA_AVISOU = "LKS_FirePenaltyWarned"

-- ============================================================================
-- PROCESSAMENTO DE CONTAINERS DE FOGO ACESOS
-- ============================================================================

--- Processa itens dentro de um container de fogo aceso.
--- Itens combustiveis sao consumidos com penalidade de 25%.
--- Itens nao-combustiveis permanecem intactos.
---
--- @param container ItemContainer O container do fogo.
--- @param objetoFogo IsoObject O objeto de fogo (IsoFireplace ou IsoObject campfire).
--- @param fogueira table|nil Tabela Lua da fogueira (se campfire).
--- @param jogador IsoPlayer|nil O jogador mais proximo (para Say).
local function processarContainerAceso(container, objetoFogo, fogueira, jogador)
    if not container then return end

    local itens = container:getItems()
    if not itens or itens:size() == 0 then return end

    local combustiveis = {}
    local naoCombustiveis = {}

    -- Coletar itens (de tras para frente para remocao segura)
    for indice = itens:size() - 1, 0, -1 do
        local item = itens:get(indice)
        if item then
            if instanceof(item, "InventoryContainer") then
                LKS_ehCombustivelRecursivo(item, combustiveis, naoCombustiveis, true)
            elseif LKS_ehCombustivel(item, true) then
                table.insert(combustiveis, item)
            else
                table.insert(naoCombustiveis, item)
            end
        end
    end

    if #combustiveis == 0 then return end

    -- Calcular combustivel a adicionar (com penalidade de 25%)
    local combustivelGanho = 0
    local combustivelAtual = 0

    if fogueira then
        combustivelAtual = fogueira.fuelAmt or 0
    elseif objetoFogo.getFuelAmount then
        combustivelAtual = objetoFogo:getFuelAmount()
    end

    local limiteMaximo = getCampingFuelMax()

    for _, item in ipairs(combustiveis) do
        local duracao = LKS_calcularDuracao(item, true)

        if (combustivelAtual + combustivelGanho + duracao) > limiteMaximo then
            break
        end

        combustivelGanho = combustivelGanho + duracao

        -- Remover item do container
        local containerPai = item:getContainer()
        if containerPai then
            containerPai:Remove(item)
        end
    end

    -- Adicionar combustivel ao fogo
    if combustivelGanho > 0 then
        if fogueira then
            fogueira.fuelAmt = (fogueira.fuelAmt or 0) + combustivelGanho
        elseif objetoFogo.setFuelAmount then
            objetoFogo:setFuelAmount(combustivelAtual + combustivelGanho)
        end

        -- Feedback via Say (dica implicita, apenas na primeira vez por container)
        if jogador then
            local modData = objetoFogo:getModData()
            if modData and not modData[MODDATA_JA_AVISOU] then
                jogador:Say(getText("IGUI_LKS_PenalidadeEficiencia") or "Deveria ter preparado o material antes...")
                modData[MODDATA_JA_AVISOU] = true
            end
        end

        -- Aplicar stub de dano a nao-combustiveis (futuro)
        for _, item in ipairs(naoCombustiveis) do
            LKS_aplicarDanoCalor(item, container)
        end

        print("[LKS_Fire] AutoBurn: " .. #combustiveis .. " item(ns) consumidos com penalidade, "
            .. string.format("%.1f", combustivelGanho) .. " min adicionados (75% eficiencia)")
    end
end

-- ============================================================================
-- EVENTO PERIODICO
-- ============================================================================

--- Verifica containers de fogo acesos na area do jogador e processa itens.
--- Roda a cada EveryTenMinutes (~6s real).
local function verificarContainersAcesos()
    for jogadorIndice = 0, getNumActivePlayers() - 1 do
        local jogador = getSpecificPlayer(jogadorIndice)
        if jogador and jogador:isAlive() then
            local posX = jogador:getX()
            local posY = jogador:getY()
            local posZ = jogador:getZ()

            -- Verificar area 20x20 ao redor do jogador (range razoavel)
            local raio = 10
            for tilePosX = posX - raio, posX + raio do
                for tilePosY = posY - raio, posY + raio do
                    local quadrado = getCell():getGridSquare(tilePosX, tilePosY, posZ)
                    if quadrado then
                        local objetos = quadrado:getObjects()
                        if objetos then
                            for indice = 0, objetos:size() - 1 do
                                local objeto = objetos:get(indice)
                                if objeto and objeto.isFireInteractionObject and objeto:isFireInteractionObject()
                                    and not (objeto.isPropaneBBQ and objeto:isPropaneBBQ())
                                    and objeto.isLit and objeto:isLit()
                                    and objeto.getContainer then

                                    local container = objeto:getContainer()
                                    if container and not container:isEmpty() then
                                        processarContainerAceso(container, objeto, nil, jogador)
                                    end
                                end
                            end
                        end

                        -- Verificar fogueiras (CCampfireSystem)
                        if CCampfireSystem and CCampfireSystem.instance then
                            local fogueira = CCampfireSystem.instance:getLuaObjectOnSquare(quadrado)
                            if fogueira and fogueira.isLit then
                                local isoObjeto = fogueira:getIsoObject()
                                if isoObjeto and isoObjeto.getContainer then
                                    local container = isoObjeto:getContainer()
                                    if container and not container:isEmpty() then
                                        processarContainerAceso(container, isoObjeto, fogueira, jogador)
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

Events.EveryTenMinutes.Add(verificarContainersAcesos)

print("[LKS PATCH - LKS_Fire_AutoBurn.lua] Sistema de consumo automatico carregado")
