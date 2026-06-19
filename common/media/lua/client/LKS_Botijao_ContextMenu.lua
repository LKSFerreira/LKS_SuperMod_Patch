-- ============================================================================
-- ARQUIVO: LKS_Botijao_ContextMenu.lua
-- EXTENSÃO: LKS SuperMod Patch (Menu de Contexto de Botijões de Propano)
-- OBJETIVO: Gerencia interações de instalar, trocar e desinstalar botijões
--           de propano em fogões convencionais via menu de contexto do mundo.
--           Relacionamento 1:1 com dupla validação:
--           - Clicou no fogão → lista botijões próximos para conectar
--           - Clicou no botijão → lista fogões próximos para conectar
-- AUTOR: LKS FERREIRA
-- VERSÃO: 2.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 18/06/2026
-- ============================================================================

require "LKS_Cooking_SpriteClassification"
require "TimedActions/ISBaseTimedAction"

local DISTANCIA_MAXIMA_MANGUEIRA = 2

-- ============================================================================
-- TIMED ACTION UNIFICADA: Todas as operações com botijão de propano
-- ============================================================================
-- Modos: "instalar", "trocar", "desinstalar", "pegar"
-- Todas compartilham: walkAdj + faceThisObject + agachar + barra de ação.
-- ============================================================================

---@class LKS_BotijaoAction : ISBaseTimedAction
LKS_BotijaoAction = ISBaseTimedAction:derive("LKS_BotijaoAction")

--- Referências para funções locais (registradas após definição).
--- @type function
LKS_BotijaoAction._conectar = nil
--- @type function
LKS_BotijaoAction._desconectar = nil

--- Cria a ação unificada de operação com botijão.
---
--- @param jogador IsoPlayer O jogador.
--- @param fogao IsoObject|nil O fogão alvo (nil para "pegar").
--- @param modo string "instalar"|"trocar"|"desinstalar"|"pegar".
--- @param botijaoInfo table|nil Info do botijão {item, nome, noChao} (nil para "desinstalar").
--- @return LKS_BotijaoAction A ação criada.
function LKS_BotijaoAction:new(jogador, fogao, modo, botijaoInfo)
    local o = ISBaseTimedAction.new(self, jogador)
    o.fogao = fogao
    o.modo = modo
    o.botijaoInfo = botijaoInfo
    o.maxTime = 250
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function LKS_BotijaoAction:isValid()
    if self.modo == "pegar" then
        return self.botijaoInfo and self.botijaoInfo.item
            and self.botijaoInfo.item:getSquare() ~= nil
    elseif self.modo == "desinstalar" then
        return self.fogao ~= nil
    else
        if self.botijaoInfo and not self.botijaoInfo.noChao then
            return self.fogao and self.botijaoInfo.item
                and self.character:getInventory():contains(self.botijaoInfo.item)
        end
        return self.fogao ~= nil
    end
end

function LKS_BotijaoAction:start()
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Low")
    self:setOverrideHandModels(nil, nil)
    -- Face o fogão ou o botijão conforme a operação
    if self.fogao then
        self.character:faceThisObject(self.fogao)
    elseif self.botijaoInfo and self.botijaoInfo.noChao and self.botijaoInfo.item then
        self.character:faceThisObject(self.botijaoInfo.item)
    end
end

function LKS_BotijaoAction:perform()
    if self.modo == "instalar" then
        self:executarInstalar()
    elseif self.modo == "trocar" then
        self:executarTrocar()
    elseif self.modo == "desinstalar" then
        self:executarDesinstalar()
    elseif self.modo == "pegar" then
        self:executarPegar()
    end
    ISBaseTimedAction.perform(self)
end

function LKS_BotijaoAction:executarInstalar()
    if not self.fogao or not self.botijaoInfo then return end

    -- Se botijão está no inventário, larga no chão primeiro
    if not self.botijaoInfo.noChao then
        local destino = self.character:getCurrentSquare()
        if not destino then return end
        local direcaoX = self.fogao:getX() - self.character:getX()
        local direcaoY = self.fogao:getY() - self.character:getY()
        local offsetX = 0.5 + (direcaoX * 0.3)
        local offsetY = 0.5 + (direcaoY * 0.3)
        self.character:getInventory():Remove(self.botijaoInfo.item)
        destino:AddWorldInventoryItem(self.botijaoInfo.item, offsetX, offsetY, 0)
        -- Atualiza referência para noChao (agora está no chão)
        self.botijaoInfo.noChao = true
    end

    LKS_BotijaoAction._conectar(self.fogao, self.character, self.botijaoInfo)
end

function LKS_BotijaoAction:executarTrocar()
    if not self.fogao or not self.botijaoInfo then return end
    LKS_BotijaoAction._desconectar(self.fogao)
    self:executarInstalar()
end

function LKS_BotijaoAction:executarDesinstalar()
    if not self.fogao then return end
    LKS_BotijaoAction._desconectar(self.fogao)
end

function LKS_BotijaoAction:executarPegar()
    if not self.botijaoInfo or not self.botijaoInfo.noChao then return end
    local objetoMundo = self.botijaoInfo.item
    local item = objetoMundo:getItem()
    if not item then return end

    -- Limpa moddata de conexão
    local dadosModItem = item:getModData()
    dadosModItem.LKS_ConectadoAoFogaoX = nil
    dadosModItem.LKS_ConectadoAoFogaoY = nil
    dadosModItem.LKS_ConectadoAoFogaoZ = nil

    -- Remove do chão e adiciona ao inventário
    self.character:getInventory():AddItem(item)
    local quadrado = objetoMundo:getSquare()
    if quadrado then
        quadrado:transmitRemoveItemFromSquare(objetoMundo)
        quadrado:removeWorldObject(objetoMundo)
    end
end

--- IDs de itens aceitos como botijão de propano (vanilla + mod).
local IDS_BOTIJAO = {
    ["Base.PropaneTank"] = true,
    ["LKS_Propano.LKS_Botijao15kg"] = true,
    ["LKS_Propano.LKS_Botijao45kg"] = true,
}

--- Itens necessários para instalação completa de um botijão.
--- Busca desacoplada via ItemTag quando possível, fallback por ID para itens específicos.
local ITENS_INSTALACAO = {
    { tags = {ItemTag.SIPHON_GAS},              quantidade = 1, nome = "Mangueira de Borracha", tipo = "material" },
    { id = "Base.Zipties",                      quantidade = 2, nome = "Enforca Gato", tipo = "material" },
    { id = "Base.DuctTape",                     quantidade = 1, nome = "Fita Isolante", tipo = "material" },
    { tags = {ItemTag.CUT_PLANT, ItemTag.SCISSORS}, quantidade = 1, nome = "Objeto Perfurocortante", tipo = "ferramenta" },
    { id = "Base.Pliers",                       quantidade = 1, nome = "Alicate", tipo = "ferramenta" },
}

--- Itens necessários para trocar um botijão (reaproveitando mangueira existente).
local ITENS_TROCA = {
    { id = "Base.Zipties",                      quantidade = 1, nome = "Enforca Gato", tipo = "material" },
    { id = "Base.Pliers",                       quantidade = 1, nome = "Alicate", tipo = "ferramenta" },
}

-- ============================================================================
-- FUNÇÕES AUXILIARES
-- ============================================================================

--- Verifica se o jogador possui todos os itens necessários para uma operação.
--- Suporta busca por ID (campo `id`), alternativas (campo `alternativas`)
--- e busca desacoplada por ItemTag (campo `tags`).
---
--- @param jogador IsoPlayer O jogador a verificar.
--- @param listaItens table Lista de itens requeridos.
--- @return boolean temTodos True se possui todos os itens.
--- @return table itensFaltantes Lista com nomes de todos os itens faltantes.
local function verificarItensNecessarios(jogador, listaItens)
    if not jogador then return false, {} end
    local inventario = jogador:getInventory()
    if not inventario then return false, {} end

    local faltantes = {}

    for _, requisito in ipairs(listaItens) do
        local encontrado = false

        if requisito.tags then
            for _, tag in ipairs(requisito.tags) do
                if inventario:getFirstTagRecurse(tag) then
                    encontrado = true
                    break
                end
            end
        elseif requisito.alternativas then
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
            table.insert(faltantes, requisito.nome)
        end
    end

    return #faltantes == 0, faltantes
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

--- Calcula a chance de vazamento de propano com base nas skills do jogador.
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

--- Verifica se um botijão (via moddata do item) está conectado a um fogão específico.
---
--- @param dadosModItem table ModData do item do botijão.
--- @param fogaoX number Coordenada X do fogão.
--- @param fogaoY number Coordenada Y do fogão.
--- @param fogaoZ number Coordenada Z do fogão.
--- @return boolean True se o botijão está conectado a este fogão específico.
local function botijaoConectadoAEsteFogao(dadosModItem, fogaoX, fogaoY, fogaoZ)
    return dadosModItem.LKS_ConectadoAoFogaoX == fogaoX
        and dadosModItem.LKS_ConectadoAoFogaoY == fogaoY
        and dadosModItem.LKS_ConectadoAoFogaoZ == fogaoZ
end

--- Verifica se um botijão está conectado a qualquer fogão.
---
--- @param dadosModItem table ModData do item do botijão.
--- @return boolean True se o botijão está conectado a algum fogão.
local function botijaoConectadoAAlgumFogao(dadosModItem)
    return dadosModItem.LKS_ConectadoAoFogaoX ~= nil
end

--- Conecta um botijão ao fogão via moddata bidirecional.
--- Marca o fogão como conectado E registra no botijão as coordenadas do fogão.
---
--- @param fogao IsoObject O fogão a conectar.
--- @param jogador IsoPlayer O jogador realizando a ação.
--- @param botijaoInfo table|nil Informações do botijão {item, nome, noChao}.
local function conectarBotijao(fogao, jogador, botijaoInfo)
    if not fogao then return end

    local dadosModFogao = fogao:getModData()
    dadosModFogao.LKS_BotijaoConectado = true

    -- Marca o botijão com as coordenadas do fogão (link bidirecional)
    if botijaoInfo then
        local itemReal = nil
        if botijaoInfo.noChao and botijaoInfo.item.getItem then
            itemReal = botijaoInfo.item:getItem()
        elseif botijaoInfo.noChao and botijaoInfo.item.getModData then
            -- Item já é InventoryItem (dropado do inventário via TimedAction)
            itemReal = botijaoInfo.item
        else
            itemReal = botijaoInfo.item
        end
        if itemReal then
            local dadosModItem = itemReal:getModData()
            dadosModItem.LKS_ConectadoAoFogaoX = fogao:getX()
            dadosModItem.LKS_ConectadoAoFogaoY = fogao:getY()
            dadosModItem.LKS_ConectadoAoFogaoZ = fogao:getZ()
        end
    end

    if calcularRiscoVazamento(jogador) then
        dadosModFogao.LKS_VazamentoPropanoPendente = true
    end
end

--- Desconecta o botijão do fogão, limpando moddata de ambos os lados.
--- Escaneia o raio para encontrar o botijão fisicamente conectado e limpar
--- seu moddata. Cobre cenários de pickup, destruição e multiplayer.
---
--- @param fogao IsoObject O fogão a desconectar.
local function desconectarBotijao(fogao)
    if not fogao then return end

    local fogaoX = fogao:getX()
    local fogaoY = fogao:getY()
    local fogaoZ = fogao:getZ()

    -- Escaneia raio para encontrar e limpar o moddata do botijão conectado
    local celula = getCell()
    if celula then
        for deslocY = -DISTANCIA_MAXIMA_MANGUEIRA, DISTANCIA_MAXIMA_MANGUEIRA do
            for deslocX = -DISTANCIA_MAXIMA_MANGUEIRA, DISTANCIA_MAXIMA_MANGUEIRA do
                local quadrado = celula:getGridSquare(fogaoX + deslocX, fogaoY + deslocY, fogaoZ)
                if quadrado then
                    local objetosChao = quadrado:getWorldObjects()
                    if objetosChao then
                        for idx = 0, objetosChao:size() - 1 do
                            local obj = objetosChao:get(idx)
                            if obj and obj:getItem() then
                                local tipoCompleto = obj:getItem():getFullType()
                                if IDS_BOTIJAO[tipoCompleto] then
                                    local dadosModItem = obj:getItem():getModData()
                                    if botijaoConectadoAEsteFogao(dadosModItem, fogaoX, fogaoY, fogaoZ) then
                                        dadosModItem.LKS_ConectadoAoFogaoX = nil
                                        dadosModItem.LKS_ConectadoAoFogaoY = nil
                                        dadosModItem.LKS_ConectadoAoFogaoZ = nil
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local dadosModFogao = fogao:getModData()
    dadosModFogao.LKS_BotijaoConectado = nil
    dadosModFogao.LKS_VazamentoPropanoPendente = nil
end

-- Registra referências para a TimedAction unificada acessar funções locais
LKS_BotijaoAction._desconectar = desconectarBotijao
LKS_BotijaoAction._conectar = conectarBotijao

-- ============================================================================
-- BUSCA DE OBJETOS PRÓXIMOS (mesma abordagem do ISBBQMenu vanilla)
-- ============================================================================

--- Busca botijões de propano nos tiles ao redor de um fogão (chão + inventário).
--- Botijões no chão dentro do raio de 2 tiles são elegíveis diretamente.
--- Botijões no inventário são elegíveis via TimedAction (caminhar + largar + conectar).
--- Filtra botijões já conectados a OUTROS fogões (exclusividade 1:1).
---
--- @param fogao IsoObject O fogão de referência.
--- @param jogador IsoPlayer O jogador (para verificar inventário).
--- @return table Lista de botijões encontrados {item, nome, noChao, conectadoAEsteFogao}.
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
                                local dadosModItem = objetoMundo:getItem():getModData()
                                local ehConectadoAqui = botijaoConectadoAEsteFogao(dadosModItem, fogaoX, fogaoY, fogaoZ)
                                local ehConectadoOutro = not ehConectadoAqui and botijaoConectadoAAlgumFogao(dadosModItem)

                                -- Exclui botijões conectados a OUTROS fogões
                                if not ehConectadoOutro then
                                    table.insert(resultados, {
                                        item = objetoMundo,
                                        nome = objetoMundo:getItem():getDisplayName() or tipoCompleto,
                                        noChao = true,
                                        conectadoAEsteFogao = ehConectadoAqui,
                                    })
                                end
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
                    local dadosModItem = item:getModData()
                    -- Botijão no inventário: conexão física impossível — limpa moddata residual
                    if botijaoConectadoAAlgumFogao(dadosModItem) then
                        dadosModItem.LKS_ConectadoAoFogaoX = nil
                        dadosModItem.LKS_ConectadoAoFogaoY = nil
                        dadosModItem.LKS_ConectadoAoFogaoZ = nil
                    end
                    table.insert(resultados, {
                        item = item,
                        nome = item:getDisplayName() or idBotijao,
                        noChao = false,
                        conectadoAEsteFogao = false,
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
                            local moveProps = ISMoveableSpriteProps.fromObject(objeto)
                            local nomeFogao = moveProps
                                and Translator.getMoveableDisplayName(moveProps.name)
                                or getText("IGUI_LKS_Fogao") or "Fogão"
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
-- TOOLTIP (reutiliza ISWorldObjectContextMenu.addToolTip + ISToolTip nativo)
-- ============================================================================

--- Monta tooltip de requisitos reutilizando a infraestrutura vanilla.
--- Usa ISWorldObjectContextMenu.addToolTip() (pool) e o renderizador
--- nativo de rich text do ISToolTip (mesmo que ISDisassembleMenu usa).
---
--- @param jogador IsoPlayer O jogador.
--- @param listaItens table Lista de itens requeridos.
--- @param nomeSprite string|nil Nome do sprite do objeto para exibir à esquerda.
--- @return ISToolTip O tooltip formatado.
local function montarTooltipRequisitos(jogador, listaItens, nomeSprite)
    local tooltip = ISWorldObjectContextMenu.addToolTip()

    if nomeSprite then
        tooltip:setTexture(nomeSprite)
    end

    local inventario = jogador and jogador:getInventory() or nil
    local tooltipFont = ISToolTip.GetFont()

    -- Calcula largura da coluna de labels (mesma técnica do ISDisassembleMenu)
    local labelMaterial = getText("IGUI_LKS_Material") or "Material:"
    local labelFerramenta = getText("IGUI_LKS_Ferramenta") or "Ferramenta:"
    local coluna2 = math.max(
        getTextManager():MeasureStringX(tooltipFont, labelMaterial),
        getTextManager():MeasureStringX(tooltipFont, labelFerramenta)
    ) + 12

    -- Header
    tooltip.description = string.format("<RGB:0.80,0.80,1.00> %s <LINE> <INDENT:0> ",
        getText("IGUI_LKS_MateriaisNecessarios") or "Materiais necessários:")

    -- Cada requisito: label só na primeira ocorrência de cada tipo (sem repetição)
    local ultimoTipo = nil
    for _, requisito in ipairs(listaItens) do
        local encontrado = false
        if inventario then
            if requisito.tags then
                for _, tag in ipairs(requisito.tags) do
                    if inventario:getFirstTagRecurse(tag) then
                        encontrado = true
                        break
                    end
                end
            elseif requisito.alternativas then
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
        end

        local quantidade = requisito.quantidade or 1
        local r = encontrado and 0.0 or 1.0
        local g = encontrado and 1.0 or 0.0
        local tipoAtual = requisito.tipo or "material"
        local textoQuantidade = quantidade > 1 and (" (x" .. quantidade .. ")") or ""
        local nomeComQuantidade = requisito.nome .. textoQuantidade

        if tipoAtual ~= ultimoTipo then
            -- Primeira ocorrência do tipo: mostra label
            local label = tipoAtual == "ferramenta" and labelFerramenta or labelMaterial
            tooltip.description = string.format(
                "%s <RGB:1.00,1.00,1.00> %s <SETX:%d> <INDENT:%d> <RGB:%.2f,%.2f,0.00> %s <LINE> <INDENT:0> ",
                tooltip.description, label, coluna2, coluna2, r, g, nomeComQuantidade)
            ultimoTipo = tipoAtual
        else
            -- Mesma categoria: só valor indentado (sem repetir label)
            tooltip.description = string.format(
                "%s <SETX:%d> <INDENT:%d> <RGB:%.2f,%.2f,0.00> %s <LINE> <INDENT:0> ",
                tooltip.description, coluna2, coluna2, r, g, nomeComQuantidade)
        end
    end

    return tooltip
end

-- ============================================================================
-- ÍCONE DO ITEM NO MENU
-- ============================================================================

--- Obtém a textura de um botijão para exibição no menu de contexto.
--- Suporta itens no chão (IsoWorldInventoryObject) e no inventário.
---
--- @param botijaoInfo table Informações do botijão {item, nome, noChao}.
--- @return Texture|nil textura A textura do item ou nil.
local function obterTexturaItem(botijaoInfo)
    if botijaoInfo.noChao then
        local itemObjeto = botijaoInfo.item and botijaoInfo.item:getItem()
        return itemObjeto and itemObjeto:getTex() or nil
    else
        return botijaoInfo.item and botijaoInfo.item:getTex() or nil
    end
end

-- ============================================================================
-- MENU DE CONTEXTO — DUPLA VALIDAÇÃO COM SUBMENU
-- ============================================================================

--- Handler principal do menu de contexto do mundo.
--- Detecta fogões e botijões clicados e monta submenu genérico
--- "Instalar" / "Trocar" / "Desinstalar" com ícones nos itens.
---
--- Estrutura:
---   Fogão clicado (sem botijão): Instalar > [botijão1, botijão2, ...]
---   Fogão clicado (com botijão): Trocar > [botijão1, ...] + Desinstalar
---   Botijão clicado: Instalar > [fogão1, fogão2, ...]
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
            local objetos = quadrado:getObjects()
            if objetos then
                for indice = 0, objetos:size() - 1 do
                    local objeto = objetos:get(indice)
                    if objeto and instanceof(objeto, "IsoStove") and not fogaoClicado then
                        fogaoClicado = objeto
                    end
                end
            end

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

    -- CAMINHO 1: Clicou num fogão → "Instalar" / "Trocar" + "Desinstalar"
    if fogaoClicado then
        local temConexao = fogaoTemBotijaoConectado(fogaoClicado)
        local botijoesProximos = buscarBotijoesProximos(fogaoClicado, jogador)
        local spriteFogao = fogaoClicado:getSprite()
        local nomeSpriteFogao = spriteFogao and spriteFogao:getName() or nil

        if temConexao then
            -- Trocar: precisa de pelo menos 1 botijão NÃO conectado a este fogão
            local textoTrocar = getText("IGUI_LKS_Trocar") or "Trocar"
            local opcaoPai = menuContexto:addOption(textoTrocar, objetosMundo, nil)
            opcaoPai.iconTexture = getTexture("media/ui/LKS_Swap.png")

            -- Filtra: exclui o botijão já instalado neste fogão
            local botijoesParaTroca = {}
            for _, botijaoInfo in ipairs(botijoesProximos) do
                if not botijaoInfo.conectadoAEsteFogao then
                    table.insert(botijoesParaTroca, botijaoInfo)
                end
            end

            if #botijoesParaTroca > 0 then
                local submenu = ISContextMenu:getNew(menuContexto)
                menuContexto:addSubMenu(opcaoPai, submenu)

                for _, botijaoInfo in ipairs(botijoesParaTroca) do
                    local temItens = verificarItensNecessarios(jogador, ITENS_TROCA)
                    local opcao = submenu:addOption(botijaoInfo.nome, objetosMundo, function()
                        if luautils.walkAdj(jogador, fogaoClicado:getSquare()) then
                            ISTimedActionQueue.add(
                                LKS_BotijaoAction:new(jogador, fogaoClicado, "trocar", botijaoInfo)
                            )
                        end
                    end)
                    opcao.iconTexture = obterTexturaItem(botijaoInfo)
                    if not temItens then
                        opcao.notAvailable = true
                    end
                    opcao.toolTip = montarTooltipRequisitos(jogador, ITENS_TROCA, nomeSpriteFogao)
                end
            else
                -- Só há 1 botijão (o próprio instalado) — não há candidato para troca
                opcaoPai.notAvailable = true
                local tooltipSemTroca = ISWorldObjectContextMenu.addToolTip()
                tooltipSemTroca.description = getText("IGUI_LKS_RequerOutroBotijao") or "Necessário outro botijão de gás próximo para realizar a troca."
                opcaoPai.toolTip = tooltipSemTroca
            end

            -- Desinstalar: caminhar + agachar + desconectar
            -- Busca nome do botijão instalado para exibição dinâmica
            local nomeBotijaoInstalado = ""
            for _, botijaoInfo in ipairs(botijoesProximos) do
                if botijaoInfo.conectadoAEsteFogao then
                    nomeBotijaoInstalado = " " .. botijaoInfo.nome
                    break
                end
            end
            local textoDesinstalar = (getText("IGUI_LKS_Desinstalar") or "Desinstalar") .. nomeBotijaoInstalado
            local opcaoDesinstalar = menuContexto:addOption(textoDesinstalar, objetosMundo, function()
                if luautils.walkAdj(jogador, fogaoClicado:getSquare()) then
                    ISTimedActionQueue.add(
                        LKS_BotijaoAction:new(jogador, fogaoClicado, "desinstalar", nil)
                    )
                end
            end)
            opcaoDesinstalar.iconTexture = getTexture("media/ui/LKS_Disconnect.png")
        else
            -- Instalar: submenu listando cada botijão próximo com ícone
            if #botijoesProximos > 0 then
                local textoInstalar = getText("IGUI_LKS_Instalar") or "Instalar"
                local opcaoPai = menuContexto:addOption(textoInstalar, objetosMundo, nil)
                opcaoPai.iconTexture = getTexture("media/ui/LKS_Connect.png")
                local submenu = ISContextMenu:getNew(menuContexto)
                menuContexto:addSubMenu(opcaoPai, submenu)

                for _, botijaoInfo in ipairs(botijoesProximos) do
                    local temItens = verificarItensNecessarios(jogador, ITENS_INSTALACAO)
                    local opcao = submenu:addOption(botijaoInfo.nome, objetosMundo, function()
                        if luautils.walkAdj(jogador, fogaoClicado:getSquare()) then
                            ISTimedActionQueue.add(
                                LKS_BotijaoAction:new(jogador, fogaoClicado, "instalar", botijaoInfo)
                            )
                        end
                    end)
                    opcao.iconTexture = obterTexturaItem(botijaoInfo)
                    if not temItens then
                        opcao.notAvailable = true
                    end
                    opcao.toolTip = montarTooltipRequisitos(jogador, ITENS_INSTALACAO, nomeSpriteFogao)
                end
            end
        end
    end

    -- CAMINHO 2: Clicou num botijão → mesma lógica espelhada com fogões como destino
    if botijaoClicado then
        local botijaoX = botijaoClicado:getX()
        local botijaoY = botijaoClicado:getY()
        local botijaoZ = botijaoClicado:getZ()

        -- Verifica se este botijão já está conectado a algum fogão
        local itemBotijao = botijaoClicado:getItem()
        local dadosModBotijao = itemBotijao and itemBotijao:getModData() or nil
        local botijaoJaConectado = dadosModBotijao and botijaoConectadoAAlgumFogao(dadosModBotijao) or false
        local botijaoItemInfo = { item = botijaoClicado, noChao = true }

        local fogoesProximos = buscarFogoesProximos(botijaoX, botijaoY, botijaoZ)

        if #fogoesProximos > 0 then
            -- Separa fogões por estado (com/sem botijão conectado)
            local fogoesSemBotijao = {}
            local fogoesComBotijao = {}
            for _, fogaoInfo in ipairs(fogoesProximos) do
                if fogaoTemBotijaoConectado(fogaoInfo.fogao) then
                    table.insert(fogoesComBotijao, fogaoInfo)
                else
                    table.insert(fogoesSemBotijao, fogaoInfo)
                end
            end

            -- Instalar: fogões que ainda não têm botijão (só se este botijão estiver livre)
            if #fogoesSemBotijao > 0 then
                local textoInstalar = getText("IGUI_LKS_Instalar") or "Instalar"
                local opcaoPai = menuContexto:addOption(textoInstalar, objetosMundo, nil)
                opcaoPai.iconTexture = getTexture("media/ui/LKS_Connect.png")

                if botijaoJaConectado then
                    -- Botijão já conectado a outro fogão — desabilita com tooltip
                    opcaoPai.notAvailable = true
                    local tooltipJaConectado = ISWorldObjectContextMenu.addToolTip()
                    tooltipJaConectado.description = getText("IGUI_LKS_BotijaoJaConectado") or "Este botijao ja esta conectado a outro fogao. Desinstale-o primeiro."
                    opcaoPai.toolTip = tooltipJaConectado
                else
                    local submenu = ISContextMenu:getNew(menuContexto)
                    menuContexto:addSubMenu(opcaoPai, submenu)

                    for _, fogaoInfo in ipairs(fogoesSemBotijao) do
                        local temItens = verificarItensNecessarios(jogador, ITENS_INSTALACAO)
                        local spriteFogao = fogaoInfo.fogao:getSprite()
                        local nomeSpriteFogao = spriteFogao and spriteFogao:getName() or nil
                        local texturaFogao = nomeSpriteFogao and getTexture(nomeSpriteFogao) or nil
                        local opcao = submenu:addOption(fogaoInfo.nome, objetosMundo, function()
                            if luautils.walkAdj(jogador, fogaoInfo.fogao:getSquare()) then
                                ISTimedActionQueue.add(
                                    LKS_BotijaoAction:new(jogador, fogaoInfo.fogao, "instalar", botijaoItemInfo)
                                )
                            end
                        end)
                        opcao.iconTexture = texturaFogao and texturaFogao:splitIcon() or nil
                        if not temItens then
                            opcao.notAvailable = true
                        end
                        opcao.toolTip = montarTooltipRequisitos(jogador, ITENS_INSTALACAO, nomeSpriteFogao)
                    end
                end
            end

            -- Trocar: fogões que já possuem botijão conectado (só se este botijão estiver livre)
            if #fogoesComBotijao > 0 and not botijaoJaConectado then
                local textoTrocar = getText("IGUI_LKS_Trocar") or "Trocar"
                local opcaoPai = menuContexto:addOption(textoTrocar, objetosMundo, nil)
                opcaoPai.iconTexture = getTexture("media/ui/LKS_Swap.png")
                local submenu = ISContextMenu:getNew(menuContexto)
                menuContexto:addSubMenu(opcaoPai, submenu)

                for _, fogaoInfo in ipairs(fogoesComBotijao) do
                    local temItens = verificarItensNecessarios(jogador, ITENS_TROCA)
                    local spriteFogao = fogaoInfo.fogao:getSprite()
                    local nomeSpriteFogao = spriteFogao and spriteFogao:getName() or nil
                    local texturaFogao = nomeSpriteFogao and getTexture(nomeSpriteFogao) or nil
                    local opcao = submenu:addOption(fogaoInfo.nome, objetosMundo, function()
                        if luautils.walkAdj(jogador, fogaoInfo.fogao:getSquare()) then
                            ISTimedActionQueue.add(
                                LKS_BotijaoAction:new(jogador, fogaoInfo.fogao, "trocar", botijaoItemInfo)
                            )
                        end
                    end)
                    opcao.iconTexture = texturaFogao and texturaFogao:splitIcon() or nil
                    if not temItens then
                        opcao.notAvailable = true
                    end
                    opcao.toolTip = montarTooltipRequisitos(jogador, ITENS_TROCA, nomeSpriteFogao)
                end
            end
        end

        -- Pegar: recolher botijão do chão com animação
        local textoPegar = getText("ContextMenu_Grab") or "Pegar"
        local botijaoInfoPegar = { item = botijaoClicado, noChao = true }
        local opcaoPegar = menuContexto:addOption(textoPegar, objetosMundo, function()
            if luautils.walkAdj(jogador, botijaoClicado:getSquare()) then
                ISTimedActionQueue.add(
                    LKS_BotijaoAction:new(jogador, nil, "pegar", botijaoInfoPegar)
                )
            end
        end)
        local texturaBotijao = itemBotijao and itemBotijao:getTex() or nil
        opcaoPegar.iconTexture = texturaBotijao
    end
end

Events.OnFillWorldObjectContextMenu.Add(adicionarOpcoesMenuBotijao)
