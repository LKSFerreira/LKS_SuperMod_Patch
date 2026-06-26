-- ============================================================================
-- LKS SUPERMOD PATCH — Videogame Funcional
-- ============================================================================
-- ARQUIVO: LKS_Videogame_Handler.lua
-- OBJETIVO: Integração de eventos — context menu do inventário, EveryOneMinute
--           para consumo de bateria, e registro global de handlers.
-- ============================================================================

require "ISUI/ISInventoryPaneContextMenu"

-- ============================================================================
-- CONTEXT MENU
-- ============================================================================

--- Adiciona opções de videogame no menu de contexto do inventário
---@param playerNum number Índice do jogador
---@param context ISContextMenu Menu de contexto
---@param items table Itens selecionados
local function LKS_Videogame_onContextMenu(playerNum, context, items)
    local jogador = getSpecificPlayer(playerNum)
    if not jogador then return end

    -- Encontrar o item videogame na seleção
    local itemVideogame = nil
    for _, itemOuStack in ipairs(items) do
        local item = itemOuStack
        if type(itemOuStack) == "table" then
            item = itemOuStack.items[1]
        end
        if item and item:getFullType() == LKS_VIDEOGAME.itemFullType then
            itemVideogame = item
            break
        end
    end

    if not itemVideogame then return end

    -- Verificar se está equipado nas mãos
    local equipado = (jogador:getPrimaryHandItem() == itemVideogame)
        or (jogador:getSecondaryHandItem() == itemVideogame)

    -- Opção "Ligar Videogame" — funciona equipado ou não
    local opcaoLigar = context:addOption(getText("IGUI_LKS_VG_LigarVideogame"), jogador, function()
        if not equipado then
            -- Equipar nas duas mãos antes de abrir
            ISTimedActionQueue.add(ISEquipWeaponAction:new(jogador, itemVideogame, 50, true, true))
        end
        -- Abrir janela (se não estava equipado, abre após a animação de equipar terminar)
        -- Usamos um timer curto para garantir que o equip terminou
        if not equipado then
            local tempoEspera = 600
            local function tentarAbrir()
                tempoEspera = tempoEspera - 1
                if jogador:getPrimaryHandItem() == itemVideogame
                    or jogador:getSecondaryHandItem() == itemVideogame then
                    LKS_Videogame_Window.abrir(jogador, itemVideogame)
                    Events.OnTick.Remove(tentarAbrir)
                elseif tempoEspera <= 0 then
                    Events.OnTick.Remove(tentarAbrir)
                end
            end
            Events.OnTick.Add(tentarAbrir)
        else
            LKS_Videogame_Window.abrir(jogador, itemVideogame)
        end
    end)
    opcaoLigar.iconTexture = getTexture("Item_VideoGame")
end

-- ============================================================================
-- EVERYYONEMINUTE — CONSUMO DE BATERIA
-- ============================================================================

--- Chamado a cada minuto de jogo para drenar bateria de videogames ligados
local function LKS_Videogame_atualizarBateria()
    -- Iterar sobre todos os jogadores locais
    for playerNum = 0, getNumActivePlayers() - 1 do
        local jogador = getSpecificPlayer(playerNum)
        if jogador and not jogador:isDead() then
            -- Verificar se tem videogame equipado
            local itemMaoDireita = jogador:getPrimaryHandItem()
            local itemMaoEsquerda = jogador:getSecondaryHandItem()

            local itemVideogame = nil
            if itemMaoDireita and itemMaoDireita:getFullType() == LKS_VIDEOGAME.itemFullType then
                itemVideogame = itemMaoDireita
            elseif itemMaoEsquerda and itemMaoEsquerda:getFullType() == LKS_VIDEOGAME.itemFullType then
                itemVideogame = itemMaoEsquerda
            end

            if itemVideogame then
                local modData = itemVideogame:getModData()
                local estaJogando = modData["LKS_VG_jogando"]

                if estaJogando then
                    local config = LKS_VIDEOGAME
                    local consumoPorMinuto = config.consumoBateriaPorMinuto

                    -- Consumo proporcional ao volume: base * (volume/100) * pesoVolumeNaBateria
                    local volume = (modData["LKS_VG_volume"] or config.volumeInicial) / 100.0
                    local mutado = modData["LKS_VG_mutado"]
                    if mutado then volume = 0 end
                    consumoPorMinuto = consumoPorMinuto * volume * config.pesoVolumeNaBateria

                    -- Economia com fone (multiplicativo)
                    local temFone = LKS_Videogame_verificarFone(jogador)
                    if temFone then
                        consumoPorMinuto = consumoPorMinuto * config.economiaFone
                    end

                    -- Drenar AMBAS baterias simultaneamente (metade do consumo cada)
                    local carga1 = modData["LKS_VG_bateria1_carga"] or 0
                    local carga2 = modData["LKS_VG_bateria2_carga"] or 0
                    local consumoPorBateria = consumoPorMinuto / 2

                    if carga1 > 0 then
                        carga1 = math.max(0, carga1 - consumoPorBateria)
                        modData["LKS_VG_bateria1_carga"] = carga1
                    end
                    if carga2 > 0 then
                        carga2 = math.max(0, carga2 - consumoPorBateria)
                        modData["LKS_VG_bateria2_carga"] = carga2
                    end

                    -- Se ambas zeradas: desligar
                    if carga1 <= 0 and carga2 <= 0 then
                        modData["LKS_VG_jogando"] = nil
                        modData["LKS_VG_ligado"] = nil

                        -- Cancelar TimedAction
                        ISTimedActionQueue.clear(jogador)

                        -- Atualizar janela se aberta
                        if LKS_Videogame_Window and LKS_Videogame_Window.instancias[playerNum] then
                            local janela = LKS_Videogame_Window.instancias[playerNum]
                            janela.estaJogando = false
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- UTILITÁRIOS GLOBAIS
-- ============================================================================

---@param jogador IsoPlayer Jogador a verificar
---@return boolean temFone Se o videogame equipado tem fone inserido
function LKS_Videogame_verificarFone(jogador)
    if not jogador then return false end
    local itemMaoDireita = jogador:getPrimaryHandItem()
    local itemMaoEsquerda = jogador:getSecondaryHandItem()
    local itemVideogame = nil
    if itemMaoDireita and itemMaoDireita:getFullType() == LKS_VIDEOGAME.itemFullType then
        itemVideogame = itemMaoDireita
    elseif itemMaoEsquerda and itemMaoEsquerda:getFullType() == LKS_VIDEOGAME.itemFullType then
        itemVideogame = itemMaoEsquerda
    end
    if not itemVideogame then return false end
    local modData = itemVideogame:getModData()
    return modData["LKS_VG_fone_tipo"] ~= nil
end

-- ============================================================================
-- REGISTRO DE EVENTOS
-- ============================================================================

Events.OnFillInventoryObjectContextMenu.Add(LKS_Videogame_onContextMenu)
Events.EveryOneMinute.Add(LKS_Videogame_atualizarBateria)

print("[LKS PATCH - LKS_Videogame_Handler.lua] Carregado com sucesso!")
