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
            -- Trocar: submenu listando cada botijão próximo com ícone
            if #botijoesProximos > 0 then
                local textoTrocar = getText("IGUI_LKS_Trocar") or "Trocar"
                local opcaoPai = menuContexto:addOption(textoTrocar, objetosMundo, nil)
                opcaoPai.iconTexture = getTexture("media/ui/LKS_Connect.png")
                local submenu = ISContextMenu:getNew(menuContexto)
                menuContexto:addSubMenu(opcaoPai, submenu)

                for _, botijaoInfo in ipairs(botijoesProximos) do
                    local temItens = verificarItensNecessarios(jogador, ITENS_TROCA)
                    local opcao = submenu:addOption(botijaoInfo.nome, objetosMundo, function()
                        desconectarBotijao(fogaoClicado)
                        conectarBotijao(fogaoClicado, jogador)
                    end)
                    opcao.iconTexture = obterTexturaItem(botijaoInfo)
                    if not temItens then
                        opcao.notAvailable = true
                    end
                    opcao.toolTip = montarTooltipRequisitos(jogador, ITENS_TROCA, nomeSpriteFogao)
                end
            end

            -- Desinstalar: opção direta com ícone (sem submenu)
            local textoDesinstalar = getText("IGUI_LKS_Desinstalar") or "Desinstalar"
            local opcaoDesinstalar = menuContexto:addOption(textoDesinstalar, objetosMundo, function()
                desconectarBotijao(fogaoClicado)
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
                        conectarBotijao(fogaoClicado, jogador)
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

            -- Instalar: fogões que ainda não têm botijão
            if #fogoesSemBotijao > 0 then
                local textoInstalar = getText("IGUI_LKS_Instalar") or "Instalar"
                local opcaoPai = menuContexto:addOption(textoInstalar, objetosMundo, nil)
                opcaoPai.iconTexture = getTexture("media/ui/LKS_Connect.png")
                local submenu = ISContextMenu:getNew(menuContexto)
                menuContexto:addSubMenu(opcaoPai, submenu)

                for _, fogaoInfo in ipairs(fogoesSemBotijao) do
                    local temItens = verificarItensNecessarios(jogador, ITENS_INSTALACAO)
                    local spriteFogao = fogaoInfo.fogao:getSprite()
                    local nomeSpriteFogao = spriteFogao and spriteFogao:getName() or nil
                    local texturaFogao = nomeSpriteFogao and getTexture(nomeSpriteFogao) or nil
                    local opcao = submenu:addOption(fogaoInfo.nome, objetosMundo, function()
                        conectarBotijao(fogaoInfo.fogao, jogador)
                    end)
                    opcao.iconTexture = texturaFogao and texturaFogao:splitIcon() or nil
                    if not temItens then
                        opcao.notAvailable = true
                    end
                    opcao.toolTip = montarTooltipRequisitos(jogador, ITENS_INSTALACAO, nomeSpriteFogao)
                end
            end

            -- Trocar: fogões que já possuem botijão conectado
            if #fogoesComBotijao > 0 then
                local textoTrocar = getText("IGUI_LKS_Trocar") or "Trocar"
                local opcaoPai = menuContexto:addOption(textoTrocar, objetosMundo, nil)
                opcaoPai.iconTexture = getTexture("media/ui/LKS_Connect.png")
                local submenu = ISContextMenu:getNew(menuContexto)
                menuContexto:addSubMenu(opcaoPai, submenu)

                for _, fogaoInfo in ipairs(fogoesComBotijao) do
                    local temItens = verificarItensNecessarios(jogador, ITENS_TROCA)
                    local spriteFogao = fogaoInfo.fogao:getSprite()
                    local nomeSpriteFogao = spriteFogao and spriteFogao:getName() or nil
                    local texturaFogao = nomeSpriteFogao and getTexture(nomeSpriteFogao) or nil
                    local opcao = submenu:addOption(fogaoInfo.nome, objetosMundo, function()
                        desconectarBotijao(fogaoInfo.fogao)
                        conectarBotijao(fogaoInfo.fogao, jogador)
                    end)
                    opcao.iconTexture = texturaFogao and texturaFogao:splitIcon() or nil
                    if not temItens then
                        opcao.notAvailable = true
                    end
                    opcao.toolTip = montarTooltipRequisitos(jogador, ITENS_TROCA, nomeSpriteFogao)
                end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(adicionarOpcoesMenuBotijao)
