-- ============================================================================
-- ARQUIVO: LKS_Laundry_CycleEngine.lua
-- EXTENSAO: LKS SuperMod Patch (Motor de Ciclo de Lavanderia)
-- OBJETIVO: Complementa o Java que nao processa itens nas maquinas de lavar
--           e secar. Monitora maquinas ativas via EveryOneMinute, processa
--           itens ao completar o ciclo e desliga automaticamente.
-- AUTOR: LKS FERREIRA
-- VERSAO: 1.0 (Project Zomboid Build 42)
-- DATA DA ULTIMA MODIFICACAO: 24/06/2026
-- ============================================================================

-- ============================================================================
-- CONFIGURACAO
-- ============================================================================

--- Duracao dos ciclos em minutos in-game.
local DURACAO_CICLO = {
    lavadoraBase = 60,
    lavadoraPorKg = 4,
    secadoraBase = 30,
    secadoraPorKg = 2,
    pesoBase = 6,
}

--- Chaves de modData usadas pelo sistema.
local MODDATA = {
    timestampInicio   = "LKS_Laundry_StartTime",
    cicloAutomatico   = "LKS_Laundry_AutoCycle",
    faseAtual         = "LKS_Laundry_Phase",
    condicao          = "LKS_Laundry_Condition",
    jaAvisouDano      = "LKS_Laundry_DamageWarned",
}

--- Penalidade de condicao por tipo de item inadequado.
local PENALIDADE_CONDICAO = {
    metal    = 5,
    arma     = 10,
    pesado   = 3,
}

--- Peso minimo para ser considerado "pesado" na maquina.
local PESO_LIMITE_PESADO = 5.0

--- Tags que indicam item metalico.
local TAGS_METAL = {
    ["hasmetal"]         = true,
    ["metalpiece"]       = true,
    ["smallsheetmetal"]  = true,
    ["sheetmetalsnips"]  = true,
    ["metalsaw"]         = true,
    ["metalbucket"]      = true,
}

--- Categorias de armas/ferramentas que danificam a maquina.
local CATEGORIAS_INADEQUADAS = {
    ["Weapon"]           = true,
    ["WeaponPart"]       = true,
    ["WeaponCrafted"]    = true,
    ["WeaponImprovised"] = true,
    ["Tool"]             = true,
    ["ToolWeapon"]       = true,
}

-- ============================================================================
-- FUNCOES AUXILIARES
-- ============================================================================

--- Retorna o tempo atual em minutos in-game.
--- @return number minutosJogo Minutos desde o inicio do jogo.
local function obterTempoAtualMinutos()
    return getGameTime():getWorldAgeHours() * 60
end

--- Verifica se um item tem tag de metal.
--- @param item InventoryItem O item a verificar.
--- @return boolean ehMetal True se o item contem metal.
local function temTagMetal(item)
    local sucesso, tags = pcall(function()
        return item:getTags():toArray()
    end)
    if not sucesso or not tags then return false end

    for _, tagStr in ipairs(tags) do
        if tagStr then
            local sufixo = tostring(tagStr):match(":(.+)") or tostring(tagStr)
            if TAGS_METAL[sufixo] then
                return true
            end
        end
    end
    return false
end

--- Verifica se um item eh inadequado para a maquina e retorna a penalidade.
--- @param item InventoryItem O item a verificar.
--- @return number penalidade Valor de penalidade (0 se adequado).
local function calcularPenalidadeItem(item)
    if temTagMetal(item) then
        return PENALIDADE_CONDICAO.metal
    end

    local categoria = item:getDisplayCategory() or item:getCategory()
    if categoria and CATEGORIAS_INADEQUADAS[categoria] then
        return PENALIDADE_CONDICAO.arma
    end

    if item:getActualWeight() > PESO_LIMITE_PESADO then
        return PENALIDADE_CONDICAO.pesado
    end

    return 0
end

--- Obtem ou inicializa a condicao da maquina.
--- @param modData table O modData do objeto.
--- @return number condicao Valor entre 0 e 100.
local function obterCondicao(modData)
    if not modData[MODDATA.condicao] then
        modData[MODDATA.condicao] = 100
    end
    return modData[MODDATA.condicao]
end

--- Determina o tipo de maquina.
--- @param objeto IsoObject O objeto da maquina.
--- @return string|nil tipo "lavadora", "secadora", "combo" ou nil.
local function determinarTipoMaquina(objeto)
    if instanceof(objeto, "IsoCombinationWasherDryer") then
        return "combo"
    elseif instanceof(objeto, "IsoClothingDryer") then
        return "secadora"
    elseif instanceof(objeto, "IsoClothingWasher") then
        return "lavadora"
    end
    return nil
end

--- Calcula o peso total dos itens dentro do container.
--- @param container ItemContainer O container da maquina.
--- @return number pesoTotal Peso total em kg.
local function calcularPesoContainer(container)
    if not container then return 0 end
    local itens = container:getItems()
    if not itens then return 0 end

    local pesoTotal = 0
    for indice = 0, itens:size() - 1 do
        local item = itens:get(indice)
        if item then
            pesoTotal = pesoTotal + item:getActualWeight()
        end
    end
    return pesoTotal
end

--- Calcula duracao de lavagem baseado no peso.
--- Base: 60min ate 6kg, +4min por kg excedente.
--- @param pesoTotal number Peso total dos itens em kg.
--- @return number duracaoMinutos Duracao em minutos in-game.
local function calcularDuracaoLavagem(pesoTotal)
    local excedente = math.max(0, pesoTotal - DURACAO_CICLO.pesoBase)
    return DURACAO_CICLO.lavadoraBase + (excedente * DURACAO_CICLO.lavadoraPorKg)
end

--- Calcula duracao de secagem baseado no peso.
--- Base: 30min ate 6kg, +2min por kg excedente.
--- @param pesoTotal number Peso total dos itens em kg.
--- @return number duracaoMinutos Duracao em minutos in-game.
local function calcularDuracaoSecagem(pesoTotal)
    local excedente = math.max(0, pesoTotal - DURACAO_CICLO.pesoBase)
    return DURACAO_CICLO.secadoraBase + (excedente * DURACAO_CICLO.secadoraPorKg)
end

--- Determina a duracao do ciclo baseado no tipo, modo e peso dos itens.
--- @param objeto IsoObject O objeto da maquina.
--- @param modData table O modData do objeto.
--- @return number duracaoMinutos Duracao em minutos in-game.
local function obterDuracaoCiclo(objeto, modData)
    local container = objeto:getContainer()
    local pesoTotal = calcularPesoContainer(container)

    local tipo = determinarTipoMaquina(objeto)
    local faseAtual = modData[MODDATA.faseAtual]

    if modData[MODDATA.cicloAutomatico] then
        if faseAtual == "secagem" then
            return calcularDuracaoSecagem(pesoTotal)
        else
            return calcularDuracaoLavagem(pesoTotal)
        end
    end

    if tipo == "secadora" then
        return calcularDuracaoSecagem(pesoTotal)
    elseif tipo == "combo" then
        if objeto:isModeWasher() then
            return calcularDuracaoLavagem(pesoTotal)
        else
            return calcularDuracaoSecagem(pesoTotal)
        end
    end

    return calcularDuracaoLavagem(pesoTotal)
end

-- ============================================================================
-- PROCESSAMENTO DE CICLO
-- ============================================================================

--- Processa lavagem: remove sangue, sujeira, aplica umidade.
--- Itens com getItemAfterCleaning() sao substituidos pela versao limpa.
--- @param container ItemContainer O container da maquina.
--- @return number penalidadeTotal Penalidade acumulada por itens inadequados.
local function processarLavagem(container)
    local penalidadeTotal = 0
    local itens = container:getItems()
    if not itens then return 0 end

    local itensParaRemover = {}
    local itensParaAdicionar = {}

    for indice = itens:size() - 1, 0, -1 do
        local item = itens:get(indice)
        if item then
            penalidadeTotal = penalidadeTotal + calcularPenalidadeItem(item)

            if item.getItemAfterCleaning and item:getItemAfterCleaning() then
                local novoTipo = item:getItemAfterCleaning()
                table.insert(itensParaRemover, item)
                table.insert(itensParaAdicionar, novoTipo)
                print("[LKS_Laundry] Substituindo: " .. tostring(item:getDisplayName()) .. " -> " .. tostring(novoTipo))
            else
                if instanceof(item, "Clothing") or instanceof(item, "InventoryContainer") then
                    local tipoSangue = item:getBloodClothingType()
                    if tipoSangue then
                        local partesCobertas = BloodClothingType.getCoveredParts(tipoSangue)
                        if partesCobertas then
                            for j = 0, partesCobertas:size() - 1 do
                                item:setBlood(partesCobertas:get(j), 0)
                                item:setDirt(partesCobertas:get(j), 0)
                            end
                        end
                    end
                    if item.setDirtiness then
                        item:setDirtiness(0)
                    end
                    if item.setWetness then
                        item:setWetness(100)
                    end
                    print("[LKS_Laundry] Lavado (Clothing): " .. tostring(item:getDisplayName()))
                end

                if item.setBloodLevel then
                    item:setBloodLevel(0)
                end

                if item.synchWithVisual then
                    item:synchWithVisual()
                end
            end
        end
    end

    -- Executar substituicoes (itens com getItemAfterCleaning)
    for _, item in ipairs(itensParaRemover) do
        container:Remove(item)
    end
    for _, novoTipo in ipairs(itensParaAdicionar) do
        local novoItem = container:AddItem(novoTipo)
        if novoItem and novoItem.setWetness then
            novoItem:setWetness(100)
        end
    end

    return penalidadeTotal
end

--- Processa secagem: remove umidade.
--- @param container ItemContainer O container da maquina.
--- @return number penalidadeTotal Penalidade acumulada por itens inadequados.
local function processarSecagem(container)
    local penalidadeTotal = 0
    local itens = container:getItems()
    if not itens then return 0 end

    for indice = 0, itens:size() - 1 do
        local item = itens:get(indice)
        if item then
            penalidadeTotal = penalidadeTotal + calcularPenalidadeItem(item)
            if item.setWetness then
                item:setWetness(0)
            end
        end
    end

    return penalidadeTotal
end

--- Processa o ciclo completo de uma maquina.
--- @param objeto IsoObject A maquina.
--- @param modData table O modData do objeto.
--- @param jogador IsoPlayer|nil Jogador proximo para feedback.
local function processarCicloCompleto(objeto, modData, jogador)
    local container = objeto:getContainer()
    if not container then return end

    local tipo = determinarTipoMaquina(objeto)
    local ehCicloAutomatico = modData[MODDATA.cicloAutomatico] == true
    local faseAtual = modData[MODDATA.faseAtual] or "lavagem"
    local penalidadeTotal = 0

    if ehCicloAutomatico then
        if faseAtual == "lavagem" then
            penalidadeTotal = processarLavagem(container)
            modData[MODDATA.faseAtual] = "secagem"
            modData[MODDATA.timestampInicio] = obterTempoAtualMinutos()
            print("[LKS_Laundry] Ciclo automatico: lavagem concluida, iniciando secagem")
        else
            penalidadeTotal = processarSecagem(container)
            objeto:setActivated(false)
            objeto:sendObjectChange(IsoObjectChange.DRYER_STATE)
            modData[MODDATA.cicloAutomatico] = nil
            modData[MODDATA.faseAtual] = nil
            modData[MODDATA.timestampInicio] = nil
            print("[LKS_Laundry] Ciclo automatico: completo")
        end
    elseif tipo == "secadora" or (tipo == "combo" and not objeto:isModeWasher()) then
        penalidadeTotal = processarSecagem(container)
        objeto:setActivated(false)
        objeto:sendObjectChange(IsoObjectChange.DRYER_STATE)
        modData[MODDATA.timestampInicio] = nil
        print("[LKS_Laundry] Secagem concluida")
    else
        penalidadeTotal = processarLavagem(container)
        if objeto.useFluid then
            local aguaNecessaria = math.min(10, objeto:getFluidAmount())
            if aguaNecessaria > 0 then
                objeto:useFluid(aguaNecessaria)
            end
        end
        objeto:setActivated(false)
        objeto:sendObjectChange(IsoObjectChange.WASHER_STATE)
        modData[MODDATA.timestampInicio] = nil
        print("[LKS_Laundry] Lavagem concluida")
    end

    -- Aplicar desgaste de condicao
    local condicaoAtual = obterCondicao(modData)
    local desgasteTotal = 1 + penalidadeTotal
    condicaoAtual = math.max(0, condicaoAtual - desgasteTotal)
    modData[MODDATA.condicao] = condicaoAtual

    -- Feedback ao jogador
    if jogador then
        if penalidadeTotal > 0 and not modData[MODDATA.jaAvisouDano] then
            jogador:Say(getText("IGUI_LKS_Laundry_DanoDetectado") or "Algo nao parecia certo dentro da maquina...")
            modData[MODDATA.jaAvisouDano] = true
        else
            jogador:Say(getText("IGUI_LKS_Laundry_CicloCompleto") or "A maquina terminou.")
        end
    end

    if penalidadeTotal > 0 then
        print("[LKS_Laundry] Penalidade: -" .. desgasteTotal .. " (condicao: " .. condicaoAtual .. ")")
    end
end

-- ============================================================================
-- HOOK DE INICIO
-- ============================================================================

--- Registra o timestamp de inicio quando uma maquina eh ativada.
--- @param objeto IsoObject A maquina que foi ativada.
local function registrarInicioCiclo(objeto)
    if not objeto or not objeto:isActivated() then return end

    local modData = objeto:getModData()
    if not modData then return end

    local condicao = obterCondicao(modData)
    if condicao <= 0 then
        objeto:setActivated(false)
        local jogador = getClosestPlayer(objeto:getX(), objeto:getY(), objeto:getZ())
        if jogador then
            jogador:Say(getText("IGUI_LKS_Laundry_MaquinaQuebrada") or "Esta maquina esta quebrada...")
        end
        return
    end

    if not modData[MODDATA.timestampInicio] then
        modData[MODDATA.timestampInicio] = obterTempoAtualMinutos()
        if modData[MODDATA.cicloAutomatico] then
            modData[MODDATA.faseAtual] = "lavagem"
        end
        print("[LKS_Laundry] Ciclo iniciado (t=" .. modData[MODDATA.timestampInicio] .. ")")
    end
end

-- ============================================================================
-- HOOK DE MONITORAMENTO (EveryOneMinute)
-- ============================================================================

local function monitorarMaquinasAtivas()
    for jogadorIndice = 0, getNumActivePlayers() - 1 do
        local jogador = getSpecificPlayer(jogadorIndice)
        if jogador and jogador:isAlive() then
            local posX = math.floor(jogador:getX())
            local posY = math.floor(jogador:getY())
            local posZ = math.floor(jogador:getZ())
            local tempoAtual = obterTempoAtualMinutos()

            local raio = 7
            for tilePosX = posX - raio, posX + raio do
                for tilePosY = posY - raio, posY + raio do
                    local quadrado = getCell():getGridSquare(tilePosX, tilePosY, posZ)
                    if quadrado then
                        local objetos = quadrado:getObjects()
                        if objetos then
                            for indice = 0, objetos:size() - 1 do
                                local objeto = objetos:get(indice)
                                if objeto then
                                    local tipo = determinarTipoMaquina(objeto)
                                    if tipo and objeto:isActivated() then
                                        local modData = objeto:getModData()
                                        if modData then
                                            if not modData[MODDATA.timestampInicio] then
                                                registrarInicioCiclo(objeto)
                                            else
                                                local duracaoCiclo = obterDuracaoCiclo(objeto, modData)
                                                local condicao = obterCondicao(modData)
                                                if condicao < 25 then
                                                    duracaoCiclo = duracaoCiclo * 1.5
                                                elseif condicao < 50 then
                                                    duracaoCiclo = duracaoCiclo * 1.25
                                                end

                                                local tempoDecorrido = tempoAtual - modData[MODDATA.timestampInicio]
                                                print("[LKS_Laundry] Monitorando: tipo=" .. tostring(tipo) .. " decorrido=" .. string.format("%.1f", tempoDecorrido) .. "/" .. string.format("%.1f", duracaoCiclo) .. " min")
                                                if tempoDecorrido >= duracaoCiclo then
                                                    processarCicloCompleto(objeto, modData, jogador)
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
    end
end

-- ============================================================================
-- REGISTRO DE EVENTOS
-- ============================================================================

Events.EveryOneMinute.Add(monitorarMaquinasAtivas)

-- ============================================================================
-- API PUBLICA
-- ============================================================================

LKS_Laundry = LKS_Laundry or {}
LKS_Laundry.MODDATA = MODDATA
LKS_Laundry.DURACAO_CICLO = DURACAO_CICLO
LKS_Laundry.obterCondicao = obterCondicao
LKS_Laundry.determinarTipoMaquina = determinarTipoMaquina
LKS_Laundry.registrarInicioCiclo = registrarInicioCiclo

print("[LKS PATCH - LKS_Laundry_CycleEngine.lua] Motor de ciclo de lavanderia carregado")
