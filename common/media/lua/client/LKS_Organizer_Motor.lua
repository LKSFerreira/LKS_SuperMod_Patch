-- ==========================================================================
-- LKS_Organizer_Motor.lua
-- Motor de lógica do Organizador de Itens: scan de containers favoritados,
-- correspondência por fullType e enfileiramento de ações de transferência.
-- ==========================================================================

local LKS_Organizer_Motor = {}

--- Raio de busca em tiles (25 em cada direção = 50x50 total).
local RAIO_BUSCA = 25

--- Chave do modData usada para marcar containers como favoritos.
LKS_Organizer_Motor.CHAVE_FAVORITO = "LKS_ContainerFavorito"

--- Prefixo dos prints de debug.
local DEBUG_PREFIX = "[LKS_Organizer]"

-- ==========================================================================
-- UTILITÁRIOS
-- ==========================================================================

--- Calcula distância Manhattan entre jogador e um quadrado.
---
--- @param jogador IsoPlayer O jogador.
--- @param quadrado IsoGridSquare O quadrado alvo.
--- @return number distancia Distância Manhattan em tiles.
local function calcularDistancia(jogador, quadrado)
    local dx = math.abs(jogador:getX() - quadrado:getX())
    local dy = math.abs(jogador:getY() - quadrado:getY())
    return dx + dy
end

--- Verifica se um item está protegido contra transferência automática.
---
--- Itens protegidos: equipados, favoritos, no hotbar, containers equipados.
---
--- @param item InventoryItem O item a verificar.
--- @param jogador IsoPlayer O jogador dono do inventário.
--- @param hotbar ISHotbar O hotbar do jogador.
--- @return boolean protegido True se o item NÃO deve ser transferido.
local function itemProtegido(item, jogador, hotbar)
    if item:isEquipped() then return true end
    if item:isFavorite() then return true end
    if hotbar and hotbar:isInHotbar(item) then return true end
    if item:getCategory() == "Container" and jogador:isEquipped(item) then return true end
    return false
end

-- ==========================================================================
-- SCAN DE CONTAINERS FAVORITADOS
-- ==========================================================================

--- Varre área ao redor do jogador buscando containers com modData favorito.
---
--- Opera em um raio de RAIO_BUSCA tiles (padrão 25 = 50x50 total).
--- Retorna lista de tabelas {objeto, container, quadrado, distancia}.
---
--- @param jogador IsoPlayer O jogador como centro do scan.
--- @return table containersFavoritados Lista ordenada por distância.
function LKS_Organizer_Motor.scanContainersFavoritados(jogador)
    local jogadorX = math.floor(jogador:getX())
    local jogadorY = math.floor(jogador:getY())
    local jogadorZ = math.floor(jogador:getZ())

    local resultados = {}

    print(DEBUG_PREFIX .. " Scan iniciado: raio " .. RAIO_BUSCA .. ", jogador em (" .. jogadorX .. ", " .. jogadorY .. ", " .. jogadorZ .. ")")

    -- Varrer todos os andares (0 a 7) para encontrar containers em casas com múltiplos pisos
    local nivelMinimo = 0
    local nivelMaximo = 7

    for nivel = nivelMinimo, nivelMaximo do
        for dy = -RAIO_BUSCA, RAIO_BUSCA do
            for dx = -RAIO_BUSCA, RAIO_BUSCA do
                local quadrado = getCell():getGridSquare(jogadorX + dx, jogadorY + dy, nivel)
                if quadrado then
                    -- 1. Objetos fixos do mundo (armários, estantes, fogões, etc.)
                    local objetos = quadrado:getObjects()
                    for i = 0, objetos:size() - 1 do
                        local objeto = objetos:get(i)
                        if objeto and objeto:getContainerCount() and objeto:getContainerCount() > 0 then
                            local modData = objeto:getModData()
                            if modData[LKS_Organizer_Motor.CHAVE_FAVORITO] then
                                for ci = 0, objeto:getContainerCount() - 1 do
                                    local container = objeto:getContainerByIndex(ci)
                                    if container then
                                        local distancia = calcularDistancia(jogador, quadrado)
                                        table.insert(resultados, {
                                            objeto = objeto,
                                            container = container,
                                            quadrado = quadrado,
                                            distancia = distancia
                                        })
                                        print(DEBUG_PREFIX .. " -> Encontrado: Z=" .. nivel ..
                                            " pos=(" .. quadrado:getX() .. "," .. quadrado:getY() .. ")" ..
                                            " tipo=" .. container:getType() ..
                                            " itens=" .. container:getItems():size())
                                    end
                                end
                            end
                        end
                    end

                    -- 2. Itens no chão (mochilas, bags, bolsas dropadas — IsoWorldInventoryObject)
                    local objetosMundo = quadrado:getWorldObjects()
                    for i = 0, objetosMundo:size() - 1 do
                        local worldObject = objetosMundo:get(i)
                        if worldObject and worldObject:getModData() then
                            local modData = worldObject:getModData()
                            if modData[LKS_Organizer_Motor.CHAVE_FAVORITO] then
                                local item = worldObject:getItem()
                                if item and item:getInventory() then
                                    local container = item:getInventory()
                                    local distancia = calcularDistancia(jogador, quadrado)
                                    table.insert(resultados, {
                                        objeto = worldObject,
                                        container = container,
                                        quadrado = quadrado,
                                        distancia = distancia
                                    })
                                    print(DEBUG_PREFIX .. " -> Encontrado (chao): Z=" .. nivel ..
                                        " pos=(" .. quadrado:getX() .. "," .. quadrado:getY() .. ")" ..
                                        " bag=" .. item:getDisplayName() ..
                                        " itens=" .. container:getItems():size())
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Ordenar por distância (mais perto primeiro)
    table.sort(resultados, function(a, b)
        return a.distancia < b.distancia
    end)

    print(DEBUG_PREFIX .. " Scan completo: " .. #resultados .. " container(s) favoritado(s) encontrado(s)")

    return resultados
end

-- ==========================================================================
-- CORRESPONDÊNCIA DE ITENS
-- ==========================================================================

--- Coleta os fullTypes presentes em um container.
---
--- @param container ItemContainer O container a analisar.
--- @return table tiposPresentes Set {[fullType] = true} dos tipos no container.
local function coletarTiposDoContainer(container)
    local tipos = {}
    local itens = container:getItems()
    if not itens then return tipos end

    for i = 0, itens:size() - 1 do
        local item = itens:get(i)
        if item then
            tipos[item:getFullType()] = true
        end
    end

    return tipos
end

--- Encontra itens do inventário do jogador que correspondem aos tipos de um container.
---
--- @param jogador IsoPlayer O jogador.
--- @param tiposContainer table Set de fullTypes presentes no container destino.
--- @param hotbar ISHotbar O hotbar do jogador.
--- @return table itensCorrespondentes Lista de InventoryItem elegíveis.
local function encontrarItensCorrespondentes(jogador, tiposContainer, hotbar)
    local resultado = {}
    local inventarioPrincipal = jogador:getInventory()
    local itensPrincipal = inventarioPrincipal:getItems()

    -- 1. Itens no inventário principal (não são mochilas)
    for i = 0, itensPrincipal:size() - 1 do
        local item = itensPrincipal:get(i)
        if item then
            -- Pular containers (mochilas) — vamos entrar neles separadamente
            if item:getCategory() ~= "Container" then
                if tiposContainer[item:getFullType()] then
                    if not itemProtegido(item, jogador, hotbar) then
                        table.insert(resultado, item)
                    end
                end
            end
        end
    end

    -- 2. Itens DENTRO de mochilas equipadas (FONTE de itens para guardar)
    for i = 0, itensPrincipal:size() - 1 do
        local item = itensPrincipal:get(i)
        if item and item:getCategory() == "Container" then
            local equipada = jogador:isEquipped(item)
            local subInventario = item:getInventory()
            local qtdItens = subInventario and subInventario:getItems():size() or 0

            print(DEBUG_PREFIX .. "   Mochila [" .. i .. "] " .. item:getDisplayName() ..
                " equipada=" .. tostring(equipada) .. " itens=" .. qtdItens)

            -- Só buscar itens em mochilas EQUIPADAS (vestidas no corpo)
            if equipada and subInventario and qtdItens > 0 then
                local subItens = subInventario:getItems()
                for j = 0, subItens:size() - 1 do
                    local subItem = subItens:get(j)
                    if subItem and subItem:getCategory() ~= "Container" then
                        if tiposContainer[subItem:getFullType()] then
                            if not itemProtegido(subItem, jogador, hotbar) then
                                table.insert(resultado, subItem)
                            end
                        end
                    end
                end
            end
        end
    end

    return resultado
end

-- ==========================================================================
-- ENFILEIRAMENTO DE AÇÕES
-- ==========================================================================

--- Monta o plano de transferência: para cada container favoritado, identifica
--- quais itens do inventário serão transferidos.
---
--- @param jogador IsoPlayer O jogador.
--- @param containersFavoritados table Resultado de scanContainersFavoritados().
--- @return table plano Lista de {container, quadrado, objeto, itens}.
--- @return number totalItens Total de itens a transferir.
function LKS_Organizer_Motor.montarPlano(jogador, containersFavoritados)
    local hotbar = getPlayerHotbar(jogador:getPlayerNum())
    local plano = {}
    local totalItens = 0
    local itensJaAlocados = {}

    -- Debug: listar itens no inventário do jogador + mochilas
    local inventarioJogador = jogador:getInventory()
    local itensInventario = inventarioJogador:getItems()
    print(DEBUG_PREFIX .. " Inventario principal: " .. itensInventario:size() .. " item(ns)")
    local totalEmMochilas = 0
    for i = 0, itensInventario:size() - 1 do
        local item = itensInventario:get(i)
        if item then
            local equipado = item:isEquipped() and " [EQUIP]" or ""
            local favorito = item:isFavorite() and " [FAV]" or ""
            if i < 10 then
                print(DEBUG_PREFIX .. "   [" .. i .. "] " .. item:getFullType() .. equipado .. favorito)
            end
            -- Contar itens em mochilas equipadas
            if item:getCategory() == "Container" and jogador:isEquipped(item) then
                local subInv = item:getInventory()
                if subInv then
                    local qtdSub = subInv:getItems():size()
                    totalEmMochilas = totalEmMochilas + qtdSub
                    print(DEBUG_PREFIX .. "   [" .. i .. "] MOCHILA: " .. item:getDisplayName() .. " contendo " .. qtdSub .. " itens")
                end
            end
        end
    end
    if totalEmMochilas > 0 then
        print(DEBUG_PREFIX .. " Total em mochilas equipadas: " .. totalEmMochilas .. " item(ns)")
    end

    for _, entrada in ipairs(containersFavoritados) do
        local tiposContainer = coletarTiposDoContainer(entrada.container)

        -- Debug: listar tipos no container
        local contadorTipos = 0
        for tipo, _ in pairs(tiposContainer) do
            contadorTipos = contadorTipos + 1
        end
        print(DEBUG_PREFIX .. " Container em (" .. entrada.quadrado:getX() .. "," ..
            entrada.quadrado:getY() .. "," .. entrada.quadrado:getZ() ..
            ") possui " .. contadorTipos .. " tipo(s) distintos")

        local itensCorrespondentes = encontrarItensCorrespondentes(jogador, tiposContainer, hotbar)

        print(DEBUG_PREFIX .. "   Correspondencias encontradas: " .. #itensCorrespondentes)

        -- Filtrar itens já alocados para outro container
        local itensFiltrados = {}
        for _, item in ipairs(itensCorrespondentes) do
            if not itensJaAlocados[item] then
                table.insert(itensFiltrados, item)
                itensJaAlocados[item] = true
            end
        end

        if #itensFiltrados > 0 then
            table.insert(plano, {
                container = entrada.container,
                quadrado = entrada.quadrado,
                objeto = entrada.objeto,
                itens = itensFiltrados,
                distancia = entrada.distancia
            })
            totalItens = totalItens + #itensFiltrados

            print(DEBUG_PREFIX .. " Container favoritado em (" ..
                entrada.quadrado:getX() .. ", " .. entrada.quadrado:getY() .. ", " .. entrada.quadrado:getZ() ..
                ") — " .. #itensFiltrados .. " item(ns) correspondente(s)")
        end
    end

    print(DEBUG_PREFIX .. " Plano montado: " .. #plano .. " container(s), " .. totalItens .. " item(ns) total")

    return plano, totalItens
end

--- Executa o plano enfileirando ações no ISTimedActionQueue.
---
--- Para cada container no plano: pathfind até tile adjacente, depois transferir itens.
---
--- @param jogador IsoPlayer O jogador.
--- @param plano table Resultado de montarPlano().
function LKS_Organizer_Motor.executarPlano(jogador, plano)
    if #plano == 0 then
        print(DEBUG_PREFIX .. " Plano vazio, nada a executar")
        return
    end

    print(DEBUG_PREFIX .. " Executando plano: " .. #plano .. " parada(s)")

    local algumEnfileirado = false

    for indice, parada in ipairs(plano) do
        local quadrado = parada.quadrado

        -- Tentar encontrar tile adjacente SEM validar alcance do jogador (ele vai caminhar)
        -- Primeiro tenta com jogador (preferido), se falhar tenta sem
        local adjacente = AdjacentFreeTileFinder.Find(quadrado, jogador)

        if not adjacente then
            -- Fallback: tentar tiles ao redor manualmente
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        local tentativa = getCell():getGridSquare(quadrado:getX() + dx, quadrado:getY() + dy, quadrado:getZ())
                        if tentativa and tentativa:isFree(false) and not tentativa:isBlockedTo(quadrado) then
                            adjacente = tentativa
                            break
                        end
                    end
                end
                if adjacente then break end
            end
        end

        if adjacente then
            print(DEBUG_PREFIX .. " [" .. indice .. "] Enfileirando: walk ate (" ..
                adjacente:getX() .. ", " .. adjacente:getY() .. ", " .. adjacente:getZ() .. ")")

            -- Caminhar até tile adjacente ao container
            ISTimedActionQueue.add(ISWalkToTimedAction:new(jogador, adjacente))

            -- Transferir cada item usando o srcContainer REAL do item
            for _, item in ipairs(parada.itens) do
                local containerOrigem = item:getContainer()
                if not containerOrigem then
                    containerOrigem = jogador:getInventory()
                end

                print(DEBUG_PREFIX .. " [" .. indice .. "] Enfileirando: transferir " ..
                    item:getFullType() .. " (" .. item:getDisplayName() .. ")" ..
                    " de " .. containerOrigem:getType() .. " para " .. parada.container:getType())

                local acaoTransferir = ISInventoryTransferAction:new(
                    jogador,
                    item,
                    containerOrigem,
                    parada.container
                )
                ISTimedActionQueue.add(acaoTransferir)
            end

            algumEnfileirado = true
        else
            print(DEBUG_PREFIX .. " [" .. indice .. "] Container INACESSIVEL em (" ..
                quadrado:getX() .. ", " .. quadrado:getY() .. ", " .. quadrado:getZ() .. "), pulando")
            jogador:Say(getText("IGUI_LKS_Organizer_ContainerInacessivel"))
        end
    end

    if algumEnfileirado then
        print(DEBUG_PREFIX .. " Fila completa: acoes enfileiradas com sucesso")
    else
        print(DEBUG_PREFIX .. " NENHUMA acao enfileirada - todos os containers inacessiveis")
        jogador:Say(getText("IGUI_LKS_Organizer_ContainerInacessivel"))
    end
end

-- ==========================================================================
-- API PÚBLICA: FAVORITAR / DESFAVORITAR
-- ==========================================================================

--- Marca um objeto do mundo como container favorito.
---
--- @param objeto IsoObject O objeto do mundo (armário, estante, etc.)
function LKS_Organizer_Motor.favoritar(objeto)
    if not objeto then return end
    local modData = objeto:getModData()
    modData[LKS_Organizer_Motor.CHAVE_FAVORITO] = true
    print(DEBUG_PREFIX .. " Favoritado: objeto em (" ..
        objeto:getX() .. ", " .. objeto:getY() .. ", " .. objeto:getZ() .. ")")
end

--- Remove a marcação de favorito de um objeto.
---
--- @param objeto IsoObject O objeto do mundo.
function LKS_Organizer_Motor.desfavoritar(objeto)
    if not objeto then return end
    local modData = objeto:getModData()
    modData[LKS_Organizer_Motor.CHAVE_FAVORITO] = nil
    print(DEBUG_PREFIX .. " Desfavoritado: objeto em (" ..
        objeto:getX() .. ", " .. objeto:getY() .. ", " .. objeto:getZ() .. ")")
end

--- Verifica se um objeto está favoritado.
---
--- @param objeto IsoObject O objeto do mundo.
--- @return boolean favoritado True se o objeto está marcado como favorito.
function LKS_Organizer_Motor.isFavoritado(objeto)
    if not objeto then return false end
    local modData = objeto:getModData()
    return modData[LKS_Organizer_Motor.CHAVE_FAVORITO] == true
end

return LKS_Organizer_Motor
