-- ============================================================================
-- 🌟 LKS SUPERMOD PATCH — CRÉDITOS & AGRADECIMENTOS 🌟
-- ============================================================================
-- 💖 Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- 🛠️ Mod Original: Generator Powered Buildings (ID Workshop: 3597471949)
-- 👤 Autor Original: Beathoven
-- 🌐 Link: https://steamcommunity.com/sharedfiles/filedetails/?id=3597471949
-- 
-- Este mod só é possível graças a todos os modders que vieram antes de mim.
-- Um agradecimento especial ao autor por sua contribuição incrível à comunidade!
-- ============================================================================

-- ARQUIVO: LKS_EletricidadeConstrucao_ContextMenu_Generator.lua
-- OBJETIVO: Constrói as opções do menu de contexto (clique direito) para o gerador físico no mundo.
-- LOCALIZAÇÃO: client

if not LKS_EletricidadeConstrucao then
    print("[LKS PATCH - LKS_EletricidadeConstrucao_ContextMenu_Generator.lua] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

print("[LKS PATCH - LKS_EletricidadeConstrucao_ContextMenu_Generator.lua] Carregando Menu de Contexto do Gerador...")

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ContextMenu_Generator")

LKS_EletricidadeConstrucao.ContextMenu           = LKS_EletricidadeConstrucao.ContextMenu or {}
LKS_EletricidadeConstrucao.ContextMenu.Generator = {}

local LKS_Icons = require("LKS_Icons")

local ContextMenu = LKS_EletricidadeConstrucao.ContextMenu.Generator

-- ============================================================================
-- CONFIGURAÇÕES DE ASSETS E TEXTURAS
-- ============================================================================
local TEX_ITEM_GEN      = "Item_Generator"
local TEX_PWR_ON        = LKS_Icons.LIGAR
local TEX_PWR_OFF       = LKS_Icons.DESLIGAR
local TEX_TAKE_GEN      = LKS_Icons.PEGAR
local TEX_CONNECT       = LKS_Icons.CONECTAR
local TEX_DISCONNECT    = LKS_Icons.DESCONECTAR
local TEX_GEN_INFO      = "media/ui/LKS_Generator_Info.png"
local TEX_HOUSE_ELE     = "media/ui/LKS_House_Electricity_On.png"
local TEX_HOUSE_ELE_OFF = "media/ui/LKS_House_Electricity_Off.png"
local TEX_HOUSE_INFO    = "media/ui/LKS_House_Info.png"
local TEX_REP_GEN       = "media/ui/LKS_Fix_Generator.png"
local TEX_GAS_REFUEL    = "media/ui/LKS_Gas_Refuel.png"
local TEX_GAS_REFUEL_AL = "media/ui/LKS_Gas_Refuel_All.png"

local _cacheIconesGerador = {}
local _iconeGeradorFallback = nil

--- Retorna a textura correspondente do ícone do gerador ou fallback.
--- @param gerador any O objeto IsoGenerator.
--- @return any A textura correspondente.
local function ObterIconeGerador(gerador)
    _iconeGeradorFallback = _iconeGeradorFallback or getTexture(TEX_ITEM_GEN)
    if not gerador then return _iconeGeradorFallback end

    local nomeSprite = gerador.getSpriteName and gerador:getSpriteName()
    if not nomeSprite and gerador.getSprite and gerador:getSprite() then
        nomeSprite = gerador:getSprite():getName()
    end
    if not nomeSprite then return _iconeGeradorFallback end

    if _cacheIconesGerador[nomeSprite] ~= nil then
        return _cacheIconesGerador[nomeSprite]
    end

    local textura = getTexture("media/textures/" .. nomeSprite .. ".png") or _iconeGeradorFallback
    _cacheIconesGerador[nomeSprite] = textura
    return textura
end

--- Verifica se há alguma construção válida em um raio específico ao redor de um quadrado.
--- @param quadrado any O quadrado de grade central (gerador).
--- @param raio number O raio máximo de busca em tiles.
--- @return boolean Retorna true se encontrar algum quadrado pertencente a uma construção.
local function temConstrucaoNoRaio(quadrado, raio)
    if not quadrado then return false end
    local celulaMundo = getCell()
    if not celulaMundo then return false end

    local coordenadaX = quadrado:getX()
    local coordenadaY = quadrado:getY()
    local coordenadaZ = quadrado:getZ()
    for deslocamentoY = -raio, raio do
        for deslocamentoX = -raio, raio do
            local quadradoAlvo = celulaMundo:getGridSquare(coordenadaX + deslocamentoX, coordenadaY + deslocamentoY, coordenadaZ)
            if quadradoAlvo then
                if quadradoAlvo:getBuilding() or (quadradoAlvo.haveBuilding and quadradoAlvo:haveBuilding()) then
                    return true
                end
            end
        end
    end
    return false
end

--- Procura um objeto IsoGenerator na lista de objetos interagíveis do quadrado.
--- @param objetosMundo table A lista de objetos selecionados pelo clique direito.
--- @return any|nil Retorna o objeto gerador ou nil se não encontrado.
local function LocalizarGerador(objetosMundo)
    if not objetosMundo then return nil end
    for _, objeto in ipairs(objetosMundo) do
        if instanceof(objeto, "IsoGenerator") then
            return objeto
        end
    end
    return nil
end

--- Analisa se o gerador foi mapeado e persistido no modo de alimentação realista de prédios (Modo Construção).
--- @param gerador any O gerador físico.
--- @return boolean Retorna true se estiver vinculado logicamente a uma piscina de prédio.
local function IsGeradorEmModoConstrucao(gerador)
    if not gerador then return false end
    local dadosMod = gerador:getModData()
    return dadosMod and dadosMod.Gen_BuildingPoolID ~= nil
end

--- Retorna o percentual inteiro arredondado do combustível do gerador.
--- @param gerador any O gerador analisado.
--- @return number O percentual (0 a 100).
local function ObterPercentualCombustivel(gerador)
    if not gerador then return 0 end
    local combustivel = gerador:getFuel()
    local combustivelMaximo = gerador:getMaxFuel()
    if combustivelMaximo <= 0 then return 0 end
    return math.floor((combustivel / combustivelMaximo) * 100)
end

--- Retorna a integridade física do gerador.
--- @param gerador any O gerador.
--- @return number O percentual de condição física (0 a 100).
local function ObterPercentualCondicao(gerador)
    if not gerador then return 0 end
    return math.floor(gerador:getCondition())
end

--- Verifica se o gerador cumpre todos os requisitos para ser ligado física e eletricamente.
--- @param gerador any O gerador analisado.
--- @return boolean Retorna true se puder ser ativado.
local function PodeAtivarGerador(gerador)
    if not gerador then return false end
    if gerador:isActivated() then return false end
    if gerador:getFuel() <= 0 then return false end
    if gerador:getCondition() <= 0 then return false end
    return true
end

--- Verifica o distanciamento físico máximo permitido para interagir com o aparelho.
--- @param jogador any O objeto jogador.
--- @param gerador any O gerador.
--- @return boolean Retorna true se estiver a 1 bloco de distância.
local function PodeAlcancarGerador(jogador, gerador)
    if not jogador or not gerador then return false end
    local quadradoJogador = jogador:getSquare()
    local quadradoGerador = gerador:getSquare()
    if not quadradoJogador or not quadradoGerador then return false end

    local deslocamentoX = math.abs(quadradoJogador:getX() - quadradoGerador:getX())
    local deslocamentoY = math.abs(quadradoJogador:getY() - quadradoGerador:getY())
    return deslocamentoX <= 1 and deslocamentoY <= 1
end

-- ============================================================================
-- AUXILIARES DE ÍCONE DE RECIPIENTE E INVENTÁRIO
-- ============================================================================

--- Invoca pcall segura para validar se um dado valor é da classe InventoryItem.
--- @param valor any O valor a ser avaliado.
--- @return boolean Retorna true se for um item do inventário do jogo.
local function IsItemInventario(valor)
    if not valor then return false end
    local sucesso, resultado = pcall(instanceof, valor, "InventoryItem")
    return sucesso and resultado
end

--- Varre as referências de subopções do clique direito buscando itens contendo combustível.
--- @param opcao table A opção do menu avaliada.
--- @return any|nil Retorna o item de inventário correspondente (galão) ou nil.
local function ExtrairItemRecipienteDaOpcao(opcao)
    if not opcao then return nil end

    if IsItemInventario(opcao.itemForTexture) then
        return opcao.itemForTexture
    end

    -- 1. Verifica campos diretos da opção que sejam InventoryItem (como param1, param2, item, etc.)
    for _, valor in pairs(opcao) do
        if IsItemInventario(valor) then
            return valor
        end
    end

    -- 2. Verifica tabelas que possam conter InventoryItems (listas de itens para "Adicionar Todos")
    for chave, valor in pairs(opcao) do
        if type(valor) == "table" and not IsItemInventario(valor) then
            if chave ~= "subOption" and chave ~= "parent" and chave ~= "target" then
                for _, subValor in pairs(valor) do
                    if IsItemInventario(subValor) then
                        return subValor
                    end
                end
            end
        end
    end

    return nil
end

-- ============================================================================
-- GATILHOS DE AÇÕES DO MENU DE CONTEXTO
-- ============================================================================

--- Evento disparado quando o jogador escolhe ligar o gerador.
--- @param objetosMundo table A coleção de itens no quadrado.
--- @param numeroJogador number O ID local do jogador interativo.
function ContextMenu.OnLigar(objetosMundo, numeroJogador)
    if not numeroJogador or not objetosMundo then return end
    local gerador = LocalizarGerador(objetosMundo)
    if not gerador then return end
    local jogadorObjeto = getSpecificPlayer(numeroJogador)
    if not jogadorObjeto then return end

    if not PodeAlcancarGerador(jogadorObjeto, gerador) then
        if luautils.walkAdj then
            luautils.walkAdj(jogadorObjeto, gerador:getSquare())
        end
    end

    if LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.ActivateGenerator then
        ISTimedActionQueue.add(LKS_EletricidadeConstrucao.Actions.ActivateGenerator:new(jogadorObjeto, gerador, true))
    else
        print("[LKS PATCH] ERRO: Classe LKS_EletricidadeConstrucao.Actions.ActivateGenerator nao localizada no core!")
    end
end

--- Evento disparado quando o jogador escolhe desligar o gerador.
--- @param objetosMundo table A coleção de itens no quadrado.
--- @param numeroJogador number O ID local do jogador interativo.
function ContextMenu.OnDesligar(objetosMundo, numeroJogador)
    if not numeroJogador or not objetosMundo then return end
    local gerador = LocalizarGerador(objetosMundo)
    if not gerador then return end
    local jogadorObjeto = getSpecificPlayer(numeroJogador)
    if not jogadorObjeto then return end

    if not PodeAlcancarGerador(jogadorObjeto, gerador) then
        if luautils.walkAdj then
            luautils.walkAdj(jogadorObjeto, gerador:getSquare())
        end
    end

    if LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.ActivateGenerator then
        ISTimedActionQueue.add(LKS_EletricidadeConstrucao.Actions.ActivateGenerator:new(jogadorObjeto, gerador, false))
    else
        print("[LKS PATCH] ERRO: Classe LKS_EletricidadeConstrucao.Actions.ActivateGenerator nao localizada no core!")
    end
end

--- Evento disparado quando o jogador escolhe integrar o gerador à rede da construção (Modo Realista).
--- @param objetosMundo table A coleção de itens no quadrado.
--- @param numeroJogador number O ID local do jogador.
function ContextMenu.OnConectarConstrucao(objetosMundo, numeroJogador)
    if not numeroJogador or not objetosMundo then return end
    local gerador = LocalizarGerador(objetosMundo)
    if not gerador then return end
    local jogadorObjeto = getSpecificPlayer(numeroJogador)
    if not jogadorObjeto then return end

    if not PodeAlcancarGerador(jogadorObjeto, gerador) then
        if luautils.walkAdj then
            luautils.walkAdj(jogadorObjeto, gerador:getSquare())
        end
    end

    if LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.ConnectBuilding then
        ISTimedActionQueue.add(LKS_EletricidadeConstrucao.Actions.ConnectBuilding:new(jogadorObjeto, gerador))
    else
        print("[LKS PATCH] ERRO: Classe LKS_EletricidadeConstrucao.Actions.ConnectBuilding nao localizada no core!")
    end
end

--- Evento disparado quando o jogador escolhe isolar/desvincular o gerador da rede elétrica da construção.
--- @param objetosMundo table A coleção de itens no quadrado.
--- @param numeroJogador number O ID local do jogador.
function ContextMenu.OnDesconectarConstrucao(objetosMundo, numeroJogador)
    if not numeroJogador or not objetosMundo then return end
    local gerador = LocalizarGerador(objetosMundo)
    if not gerador then return end
    local jogadorObjeto = getSpecificPlayer(numeroJogador)
    if not jogadorObjeto then return end

    if not PodeAlcancarGerador(jogadorObjeto, gerador) then
        if luautils.walkAdj then
            luautils.walkAdj(jogadorObjeto, gerador:getSquare())
        end
    end

    if LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.DisconnectBuilding then
        ISTimedActionQueue.add(LKS_EletricidadeConstrucao.Actions.DisconnectBuilding:new(jogadorObjeto, gerador))
    else
        print("[LKS PATCH] ERRO: Classe LKS_EletricidadeConstrucao.Actions.DisconnectBuilding nao localizada no core!")
    end
end

-- ============================================================================
-- CONSTRUTOR PRINCIPAL DO MENU DE CONTEXTO
-- ============================================================================

--- Constrói dinamicamente os menus de clique direito do gerador elétrico.
--- @param numeroJogador number O número do jogador interativo.
--- @param contexto table A estrutura principal de submenu nativa.
--- @param objetosMundo table A coleção de objetos selecionados pelo clique.
--- @param modoTeste boolean Se true, sinaliza apenas a disponibilidade sem instanciar a UI.
function ContextMenu.Construir(numeroJogador, contexto, objetosMundo, modoTeste)
    if not numeroJogador or not contexto or not objetosMundo then return end
    local jogadorObjeto = getSpecificPlayer(numeroJogador)
    if not jogadorObjeto then return end

    local gerador = LocalizarGerador(objetosMundo)
    if not gerador then return end
    if modoTeste then return true end

    local estaAtivado = gerador:isActivated()
    local estaEmModoConstrucao = IsGeradorEmModoConstrucao(gerador)
    local percentualCombustivel = ObterPercentualCombustivel(gerador)
    local percentualCondicao = ObterPercentualCondicao(gerador)
    local podeAtivar = PodeAtivarGerador(gerador)

    local submenuGerador = nil
    local opcaoGerador = nil

    -- Localiza se a opção nativa de gerador já existe no menu sob cliques sobrepostos
    for _, opcao in ipairs(contexto.options) do
        if opcao.name == getText("ContextMenu_Generator") then
            opcaoGerador = opcao
            submenuGerador = contexto:getSubMenu(opcaoGerador.subOption)
            break
        end
    end

    -- Cria o submenu estruturado caso não exista previamente
    if not submenuGerador then
        submenuGerador = contexto:getNew(contexto)
        opcaoGerador = contexto:addOption(getText("ContextMenu_Generator"), objetosMundo, nil, submenuGerador)
    end

    if opcaoGerador and not opcaoGerador.iconTexture then
        opcaoGerador.iconTexture = ObterIconeGerador(gerador)
    end

    if estaEmModoConstrucao then
        -- Remove opções físicas simplistas nativas que ignorariam o gerenciador realista de prédios
        pcall(function() submenuGerador:removeOptionByName(getText("ContextMenu_GeneratorPlug")) end)
        pcall(function() submenuGerador:removeOptionByName(getText("ContextMenu_GeneratorTake")) end)
        pcall(function() submenuGerador:removeOptionByName(getText("ContextMenu_Turn_Off")) end)
        pcall(function() submenuGerador:removeOptionByName(getText("IGUI_Turn_Off")) end)
        pcall(function() submenuGerador:removeOptionByName(getText("ContextMenu_Turn_On")) end)

        if estaAtivado then
            local opcaoDesligar = submenuGerador:addOption(
                getText("ContextMenu_Turn_Off") or "Desligar",
                objetosMundo,
                ContextMenu.OnDesligar,
                numeroJogador
            )
            opcaoDesligar.iconTexture = getTexture(TEX_PWR_OFF)
        else
            local opcaoLigar = submenuGerador:addOption(
                getText("ContextMenu_Turn_On") or "Ligar",
                objetosMundo,
                ContextMenu.OnLigar,
                numeroJogador
            )
            opcaoLigar.iconTexture = getTexture(TEX_PWR_ON)

            if not podeAtivar then
                opcaoLigar.notAvailable = true
                local dicaContexto = ISInventoryPaneContextMenu.addToolTip()
                if percentualCombustivel <= 0 then
                    dicaContexto:setName(getText("IGUI_Generator_NoFuel") or "Sem Combustível")
                elseif percentualCondicao <= 0 then
                    dicaContexto:setName(getText("IGUI_Generator_Broken") or "Gerador Quebrado")
                else
                    dicaContexto:setName(getText("IGUI_Generator_CannotActivate") or "Não é Possível Ativar")
                end
                opcaoLigar.toolTip = dicaContexto
            end
        end

        local opcaoDesconectar = submenuGerador:addOption(
            getText("IGUI_DisconnectFromBuilding") or "Desconectar da Construção",
            objetosMundo,
            ContextMenu.OnDesconectarConstrucao,
            numeroJogador
        )
        opcaoDesconectar.iconTexture = getTexture(TEX_HOUSE_ELE_OFF)

        local opcaoInformacao = submenuGerador:addOption(
            getText("IGUI_BuildingPowerInfoMenu") or "Informações de Energia",
            objetosMundo,
            function(objetosMundoArg, numeroJogadorArg)
                local gen = LocalizarGerador(objetosMundoArg)
                if not gen then return end
                local pObj = getSpecificPlayer(numeroJogadorArg)
                if not pObj then return end
                if LKS_EletricidadeConstrucao.Actions and LKS_EletricidadeConstrucao.Actions.OpenInfoWindow then
                    ISTimedActionQueue.add(LKS_EletricidadeConstrucao.Actions.OpenInfoWindow:new(pObj, gen))
                end
            end,
            numeroJogador
        )
        opcaoInformacao.iconTexture = getTexture(TEX_HOUSE_ELE)
    else
        local quadrado = gerador:getSquare()
        local proximoConstrucao = false

        if quadrado then
            local construcao = quadrado:getBuilding()
            if construcao then proximoConstrucao = true end

            if not proximoConstrucao and quadrado.haveBuilding and quadrado:haveBuilding() then
                proximoConstrucao = true
            end

            if not proximoConstrucao then
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local quadradoAdj = getCell():getGridSquare(quadrado:getX() + dx, quadrado:getY() + dy, quadrado:getZ())
                            if quadradoAdj then
                                if quadradoAdj:getBuilding() or (quadradoAdj.haveBuilding and quadradoAdj:haveBuilding()) then
                                    proximoConstrucao = true
                                    break
                                end
                            end
                        end
                    end
                    if proximoConstrucao then break end
                end
            end
        end

        local existeDesconectarNativo = false
        local nomeDesconectar = getText("ContextMenu_GeneratorUnplug")
        if submenuGerador and submenuGerador.options then
            for _, opcao in ipairs(submenuGerador.options) do
                if opcao.name == nomeDesconectar then
                    existeDesconectarNativo = true
                    break
                end
            end
        end

        if not existeDesconectarNativo then
            local opcaoConectar = submenuGerador:addOption(
                getText("IGUI_ConnectToBuilding") or "Conectar à Construção",
                objetosMundo,
                ContextMenu.OnConectarConstrucao,
                numeroJogador
            )
            opcaoConectar.iconTexture = getTexture(TEX_HOUSE_ELE)

            local jogadorObjeto2 = getSpecificPlayer(numeroJogador)
            if not jogadorObjeto2:isRecipeActuallyKnown("Generator") then
                opcaoConectar.notAvailable = true
                local dicaContexto = ISInventoryPaneContextMenu.addToolTip()
                dicaContexto:setName(getText("IGUI_ConnectToBuilding") or "Conectar à Construção")
                dicaContexto.description = getText("IGUI_ConnectRequiresKnowledge") or "Requer a receita de Gerador ou Elétrica Nível 3"
                opcaoConectar.toolTip = dicaContexto
            elseif not proximoConstrucao then
                opcaoConectar.notAvailable = true
                local dicaContexto = ISInventoryPaneContextMenu.addToolTip()
                dicaContexto:setName(getText("IGUI_NoBuildingNearby") or "Nenhuma construção próxima")
                dicaContexto.description = getText("IGUI_NoBuildingNearby_Desc") or "O gerador deve ser colocado ao lado de uma construção com paredes"
                opcaoConectar.toolTip = dicaContexto
            end

            -- Silencia a opção simplória vanilla "Conectar Gerador" se houver uma construção estruturada na zona elétria
            if quadrado and temConstrucaoNoRaio(quadrado, 20) then
                pcall(function() submenuGerador:removeOptionByName(getText("ContextMenu_GeneratorPlug")) end)
            end
        end
    end

    -- ============================================================================
    -- MAPEAMENTO E ASSOCIAÇÃO DE ÍCONES DO LKS PATCH
    -- ============================================================================
    local mapaIcones = {
        [getText("ContextMenu_GeneratorTake")] = TEX_TAKE_GEN,
        ["Pegar Gerador"] = TEX_TAKE_GEN,

        [getText("ContextMenu_GeneratorPlug")] = TEX_CONNECT,
        ["Conectar Gerador"] = TEX_CONNECT,

        [getText("ContextMenu_GeneratorUnplug")] = TEX_DISCONNECT,
        ["Desconectar Gerador"] = TEX_DISCONNECT,

        [getText("ContextMenu_GeneratorInfo")] = TEX_GEN_INFO,
        ["Informações do Gerador"] = TEX_GEN_INFO,
        [getText("ContextMenu_Examine")] = TEX_GEN_INFO,
        ["Examinar"] = TEX_GEN_INFO,

        [getText("IGUI_BuildingPowerInfoMenu")] = TEX_HOUSE_INFO,
        ["Informações de Energia"] = TEX_HOUSE_INFO,
        ["Informações Elétricas da Construção"] = TEX_HOUSE_INFO,

        [getText("ContextMenu_Turn_On")] = TEX_PWR_ON,
        [getText("IGUI_Turn_On")] = TEX_PWR_ON,
        ["Ligar"] = TEX_PWR_ON,

        [getText("ContextMenu_Turn_Off")] = TEX_PWR_OFF,
        [getText("IGUI_Turn_Off")] = TEX_PWR_OFF,
        ["Desligar"] = TEX_PWR_OFF,

        [getText("ContextMenu_Repair")] = TEX_REP_GEN,
        [getText("ContextMenu_GeneratorFix")] = TEX_REP_GEN,
        ["Reparar"] = TEX_REP_GEN,
        ["Reparar Gerador"] = TEX_REP_GEN,

        [getText("ContextMenu_AddFuel")] = TEX_GAS_REFUEL,
        [getText("ContextMenu_GeneratorAddFuel")] = TEX_GAS_REFUEL,
        ["Colocar Combustível"] = TEX_GAS_REFUEL,
        ["Adicionar Combustível"] = TEX_GAS_REFUEL,

        [getText("ContextMenu_AddAll")] = TEX_GAS_REFUEL_AL,
        ["Adicionar Tudo"] = TEX_GAS_REFUEL_AL,
    }

    local function isAdicionarUm(nome)
        if not nome then return false end
        local nomeMinusculo = string.lower(nome)
        return nomeMinusculo == string.lower(getText("ContextMenu_AddOne") or "")
            or nomeMinusculo == "adicionar um"
            or nomeMinusculo == "adicionar uma"
    end

    local function isAdicionarTudo(nome)
        if not nome then return false end
        local nomeMinusculo = string.lower(nome)
        return nomeMinusculo == string.lower(getText("ContextMenu_AddAll") or "")
            or nomeMinusculo == "adicionar todos"
            or nomeMinusculo == "adicionar tudo"
    end

    local function ObterSubmenuDaOpcao(objetoMenu, opcao, contextoRaiz)
        if not objetoMenu or not opcao or not opcao.subOption then
            return nil
        end

        if objetoMenu.getSubMenu then
            local sucesso, subMenu = pcall(objetoMenu.getSubMenu, objetoMenu, opcao.subOption)
            if sucesso and subMenu then
                return subMenu
            end
        end

        if contextoRaiz and contextoRaiz ~= objetoMenu and contextoRaiz.getSubMenu then
            local sucesso, subMenu = pcall(contextoRaiz.getSubMenu, contextoRaiz, opcao.subOption)
            if sucesso and subMenu then
                return subMenu
            end
        end

        if objetoMenu.subMenus and objetoMenu.subMenus[opcao.subOption] then
            return objetoMenu.subMenus[opcao.subOption]
        end

        if contextoRaiz and contextoRaiz ~= objetoMenu and contextoRaiz.subMenus and contextoRaiz.subMenus[opcao.subOption] then
            return contextoRaiz.subMenus[opcao.subOption]
        end

        if objetoMenu.subOption and objetoMenu.subOption[opcao.subOption] then
            return objetoMenu.subOption[opcao.subOption]
        end

        return nil
    end

    local function AplicarIconesRecursivo(objetoMenu, opcaoPai, itemHerdado, contextoRaiz)
        if not objetoMenu or not objetoMenu.options then return end

        for _, opcao in ipairs(objetoMenu.options) do
            if opcao and opcao.name then
                local itemAtual = nil
                if not isAdicionarTudo(opcao.name) then
                    if isAdicionarUm(opcao.name) and itemHerdado then
                        itemAtual = itemHerdado
                    else
                        itemAtual = opcao.itemForTexture or ExtrairItemRecipienteDaOpcao(opcao)
                    end
                end

                if itemAtual then
                    opcao.itemForTexture = itemAtual
                    opcao.iconTexture = nil -- Garante renderização fluida nativa do galão de gasolina
                else
                    if not opcao.iconTexture and mapaIcones[opcao.name] then
                        opcao.iconTexture = getTexture(mapaIcones[opcao.name])
                    end

                    if isAdicionarTudo(opcao.name) then
                        opcao.iconTexture = getTexture(TEX_GAS_REFUEL_AL)
                    end
                end

                local sub = ObterSubmenuDaOpcao(objetoMenu, opcao, contextoRaiz)
                if sub then
                    local proximoItemHerdado = itemAtual or itemHerdado
                    AplicarIconesRecursivo(sub, opcao, proximoItemHerdado, contextoRaiz)
                end
            end
        end
    end

    AplicarIconesRecursivo(contexto, nil, nil, contexto)
end

-- ============================================================================
-- REGISTRO DE EVENTOS GLOBAIS DO SISTEMA
-- ============================================================================
Events.OnFillWorldObjectContextMenu.Add(ContextMenu.Construir)

print("[LKS PATCH - LKS_EletricidadeConstrucao_ContextMenu_Generator.lua] Carregado com sucesso!")
