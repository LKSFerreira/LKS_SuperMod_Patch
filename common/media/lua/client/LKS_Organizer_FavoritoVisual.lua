-- ==========================================================================
-- LKS_Organizer_FavoritoVisual.lua
-- Botao "Favoritos" (texto) no inventario do jogador +
-- Botao estrela na barra de controles da Loot Window para cada container.
-- ==========================================================================

require "ISUI/InventoryWindow/ISInventoryWindowControlHandler"
require "ISUI/InventoryWindow/ISInventoryWindowContainerControls"
require "ISUI/LootWindow/ISLootWindowObjectControlHandler"
require "ISUI/LootWindow/ISLootWindowContainerControls"

local LKS_Organizer_Motor = require("LKS_Organizer_Motor")

--- Prefixo dos prints de debug.
local DEBUG_PREFIX = "[LKS_Organizer]"

-- ==========================================================================
-- PARTE 1: BOTAO "Favoritos" NO INVENTARIO DO JOGADOR (TEXTO)
-- ==========================================================================

ISInventoryWindowControlHandler_LKS_Favoritos = ISInventoryWindowControlHandler:derive("ISInventoryWindowControlHandler_LKS_Favoritos")
local HandlerFavoritos = ISInventoryWindowControlHandler_LKS_Favoritos

--- Visivel apenas no inventario do jogador (onCharacter).
---
--- @return boolean visivel True se deve exibir.
function HandlerFavoritos:shouldBeVisible()
    if not self.inventoryWindow then return false end
    if not self.inventoryWindow.onCharacter then return false end
    return true
end

--- Retorna botao com texto "Favoritos".
---
--- @return ISButton controle O botao configurado.
function HandlerFavoritos:getControl()
    local texto = getText("IGUI_LKS_Organizer_Favoritos_Botao")
    self.control = self:getButtonControl(texto)
    self.control.tooltip = getText("IGUI_LKS_Organizer_Favoritos_Tooltip")
    return self.control
end

--- Ao clicar, exibe modal com lista de containers favoritados.
function HandlerFavoritos:perform()
    if isGamePaused() then return end

    local jogador = getSpecificPlayer(self.playerNum)
    if not jogador then return end

    print(DEBUG_PREFIX .. " Botao 'Favoritos' clicado")

    local containersFavoritados = LKS_Organizer_Motor.scanContainersFavoritados(jogador)

    if #containersFavoritados == 0 then
        jogador:Say(getText("IGUI_LKS_Organizer_NenhumFavorito"))
        return
    end

    self:exibirModalFavoritos(jogador, containersFavoritados)
end

--- Exibe um modal ISModalRichText listando containers favoritados.
---
--- @param jogador IsoPlayer O jogador.
--- @param containersFavoritados table Lista de containers encontrados no scan.
function HandlerFavoritos:exibirModalFavoritos(jogador, containersFavoritados)
    local objetosVistos = {}
    local listaObjetos = {}

    for _, entrada in ipairs(containersFavoritados) do
        local objeto = entrada.objeto
        if not objetosVistos[objeto] then
            objetosVistos[objeto] = true
            table.insert(listaObjetos, entrada)
        end
    end

    local linhas = {}
    table.insert(linhas, " <RGB:1,0.85,0> " .. getText("IGUI_LKS_Organizer_Favoritos_Titulo") .. " <LINE> ")
    table.insert(linhas, " <RGB:0.8,0.8,0.8> ---------------------------------------- <LINE> ")

    for indice, entrada in ipairs(listaObjetos) do
        local nomeContainer = self:obterNomeDoObjeto(entrada.objeto)
        local coordenadas = "(" .. entrada.quadrado:getX() .. ", " .. entrada.quadrado:getY() .. ")"
        local distancia = math.floor(entrada.distancia)

        table.insert(linhas, " <RGB:1,1,1> " .. indice .. ". " .. nomeContainer ..
            " <RGB:0.6,0.6,0.6> " .. coordenadas .. " - " .. distancia .. " tiles <LINE> ")
    end

    table.insert(linhas, " <LINE> <RGB:0.7,0.7,0.5> " .. getText("IGUI_LKS_Organizer_Favoritos_Instrucao"))

    local textoCompleto = table.concat(linhas, "")

    local largura = 400
    local altura = 200
    local tela = getCore():getScreenWidth()
    local telaAltura = getCore():getScreenHeight()
    local posX = (tela - largura) / 2
    local posY = (telaAltura - altura) / 2

    if self.modalFavoritos then
        self.modalFavoritos:removeFromUIManager()
    end

    local modal = ISModalRichText:new(posX, posY, largura, altura, textoCompleto, false)
    modal:initialise()
    modal.backgroundColor = {r = 0, g = 0, b = 0, a = 0.92}
    modal.chatText:paginate()
    modal:setHeightToContents()
    modal:setY((telaAltura - modal:getHeight()) / 2)
    modal:setVisible(true)
    modal:addToUIManager()

    self.modalFavoritos = modal

    print(DEBUG_PREFIX .. " Modal de favoritos exibido: " .. #listaObjetos .. " objeto(s)")
end

--- Obtem nome legivel de um objeto do mundo.
---
--- @param objeto IsoObject O objeto.
--- @return string nome Nome traduzido.
function HandlerFavoritos:obterNomeDoObjeto(objeto)
    if not objeto then return "Container" end

    local moveProps = ISMoveableSpriteProps.fromObject(objeto)
    if moveProps and moveProps.name then
        local nome = Translator.getMoveableDisplayName(moveProps.name)
        if nome and nome ~= "" then
            return nome
        end
    end

    if objeto:getContainerCount() and objeto:getContainerCount() > 0 then
        local container = objeto:getContainerByIndex(0)
        if container then
            local chave = "IGUI_ContainerTitle_" .. container:getType()
            local nome = getTextOrNull(chave)
            if nome then return nome end
        end
    end

    return "Container"
end

--- Construtor.
---
--- @return ISInventoryWindowControlHandler_LKS_Favoritos instancia
function HandlerFavoritos:new()
    local o = ISInventoryWindowControlHandler.new(self)
    return o
end

-- ==========================================================================
-- PARTE 2: BOTAO ESTRELA NA BARRA DE CONTROLES DA LOOT WINDOW
-- ==========================================================================

ISLootWindowObjectControlHandler_LKS_Favoritar = ISLootWindowObjectControlHandler:derive("ISLootWindowObjectControlHandler_LKS_Favoritar")
local HandlerLoot = ISLootWindowObjectControlHandler_LKS_Favoritar

--- Visivel quando o container selecionado tem um IsoObject pai valido.
--- Inclui: moveis com containers, IsoWorldInventoryObject (bags no chao).
---
--- @return boolean visivel True se deve exibir.
function HandlerLoot:shouldBeVisible()
    if not self.object then return false end
    if instanceof(self.object, "IsoPlayer") then return false end

    -- IsoWorldInventoryObject (bag/mochila dropada no chão) — sempre elegível
    if instanceof(self.object, "IsoWorldInventoryObject") then
        return true
    end

    -- Objeto do mundo com containers (armário, estante, etc.)
    if not self.object.getModData then return false end
    if not self.object.getContainerCount then return false end
    if self.object:getContainerCount() == 0 then return false end
    return true
end

--- Retorna botao com icone de estrela e tooltip dinamico.
---
--- @return ISButton controle O botao configurado.
function HandlerLoot:getControl()
    self.control = self:getImageButtonControl("media/ui/LKS_Menu_Favoritar.png")

    if self.object and LKS_Organizer_Motor.isFavoritado(self.object) then
        self.control.tooltip = getText("IGUI_LKS_Organizer_Desfavoritar")
    else
        self.control.tooltip = getText("IGUI_LKS_Organizer_Favoritar")
    end

    return self.control
end

--- Toggle favorito ao clicar no botao estrela.
function HandlerLoot:perform()
    if not self.object then return end

    if LKS_Organizer_Motor.isFavoritado(self.object) then
        LKS_Organizer_Motor.desfavoritar(self.object)
        if self.control then
            self.control.tooltip = getText("IGUI_LKS_Organizer_Favoritar")
        end
    else
        LKS_Organizer_Motor.favoritar(self.object)
        if self.control then
            self.control.tooltip = getText("IGUI_LKS_Organizer_Desfavoritar")
        end
    end
end

--- Construtor.
---
--- @return ISLootWindowObjectControlHandler_LKS_Favoritar instancia
function HandlerLoot:new()
    local o = ISLootWindowObjectControlHandler.new(self)
    o.altColor = true
    return o
end

-- ==========================================================================
-- REGISTRO DOS HANDLERS
-- ==========================================================================

ISInventoryWindowContainerControls.AddHandler(ISInventoryWindowControlHandler_LKS_Favoritos)
ISLootWindowContainerControls.AddHandler(ISLootWindowObjectControlHandler_LKS_Favoritar, false)

print(DEBUG_PREFIX .. " Handler 'Favoritos' (inventario) + Handler estrela (loot window) registrados")

-- ==========================================================================
-- PARTE 3: OVERLAY DE ESTRELA NO ÍCONE DO CONTAINER NA SIDEBAR DA LOOT WINDOW
-- ==========================================================================

local TEXTURA_ESTRELA = getTexture("media/ui/LKS_Menu_Favoritar.png")

local function inicializarOverlaySidebar()
    local funcaoOriginal = ISInventoryPage.addContainerButton

    function ISInventoryPage:addContainerButton(recipiente, textura, nome, dicaContexto)
        local botao = funcaoOriginal(self, recipiente, textura, nome, dicaContexto)
        if not botao or not recipiente then return botao end

        -- Só na Loot Window (lado direito)
        if self.onCharacter then return botao end

        -- NUNCA aplicar ao container "floor" (chão)
        if recipiente:getType() == "floor" then return botao end

        -- Verificar se o objeto pai é válido para favoritação
        local objetoPai = recipiente:getParent()

        -- Tentar IsoWorldInventoryObject (bags no chão)
        if not objetoPai or instanceof(objetoPai, "IsoPlayer") then
            local containingItem = recipiente:getContainingItem()
            if containingItem and containingItem:getWorldItem() then
                objetoPai = containingItem:getWorldItem()
            end
        end

        if not objetoPai then return botao end
        if instanceof(objetoPai, "IsoPlayer") then return botao end
        if not objetoPai.getModData then return botao end

        -- SEMPRE atualizar a referência do objeto pai (botões são reciclados pelo pool)
        botao.lksOrganizerObjetoPai = objetoPai

        -- Hook no render (apenas uma vez por botão)
        if not botao.lksOrganizerHooked then
            botao.lksOrganizerHooked = true
            local funcaoRenderOriginal = botao.render

            botao.render = function(self)
                if funcaoRenderOriginal then
                    funcaoRenderOriginal(self)
                end

                -- Desenhar estrela se favoritado
                if self.lksOrganizerObjetoPai and self.lksOrganizerObjetoPai.getModData then
                    local modData = self.lksOrganizerObjetoPai:getModData()
                    if modData[LKS_Organizer_Motor.CHAVE_FAVORITO] and TEXTURA_ESTRELA then
                        local tamanho = 10
                        local posX = self:getWidth() - tamanho - 1
                        local posY = self:getHeight() - tamanho - 1
                        self:drawTextureScaled(TEXTURA_ESTRELA, posX, posY, tamanho, tamanho, 1, 1, 1, 1)
                    end
                end
            end
        end

        return botao
    end

    print(DEBUG_PREFIX .. " Overlay de estrela na sidebar registrado (OnGameStart)")
end

Events.OnGameStart.Add(inicializarOverlaySidebar)
