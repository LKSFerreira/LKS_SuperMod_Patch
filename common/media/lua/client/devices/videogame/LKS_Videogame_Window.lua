-- ============================================================================
-- LKS SUPERMOD PATCH — Videogame Funcional
-- ============================================================================
-- ARQUIVO: LKS_Videogame_Window.lua
-- OBJETIVO: Janela do videogame portátil usando a MESMA arquitetura modular
--           do Walkie-Talkie (ISCollapsableWindow + RWMElement com títulos
--           colapsáveis e subpainéis). Layout idêntico em qualidade.
-- ============================================================================

require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "RadioCom/ISUIRadio/ISLedLight"
require "RadioCom/ISUIRadio/ISBatteryStatusDisplay"
require "RadioCom/ISUIRadio/ISItemDropBox"
require "RadioCom/RadioWindowModules/RWMPanel"
require "RadioCom/RadioWindowModules/RWMElement"

---@class LKS_Videogame_Window : ISCollapsableWindow
LKS_Videogame_Window    = ISCollapsableWindow:derive("LKS_Videogame_Window")

local FONT_HGT_SMALL    = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT        = FONT_HGT_SMALL + 6
local UI_BORDER_SPACING = 10

-- ============================================================================
-- CONSTRUTOR
-- ============================================================================

---@param coordenadaX number
---@param coordenadaY number
---@param largura number
---@param altura number
---@param jogador IsoPlayer
---@param itemVideogame InventoryItem
---@return LKS_Videogame_Window
function LKS_Videogame_Window:new(coordenadaX, coordenadaY, largura, altura, jogador, itemVideogame)
    local objeto         = ISCollapsableWindow.new(self, coordenadaX, coordenadaY, largura, altura)
    objeto.character     = jogador
    objeto.playerNum     = jogador:getPlayerNum()
    objeto.itemVideogame = itemVideogame
    objeto.estaJogando   = false
    objeto.title         = getText("IGUI_LKS_VG_Titulo")
    objeto.modules       = {}
    return objeto
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

function LKS_Videogame_Window:initialise()
    ISCollapsableWindow.initialise(self)
end

function LKS_Videogame_Window:addModule(painelModulo, nomeModulo, habilitado)
    local modulo = {}
    modulo.enabled = habilitado
    modulo.element = RWMElement:new(0, 0, self.width, 0, painelModulo, nomeModulo, self)
    modulo.element:initialise()
    modulo.element:instantiate()
    table.insert(self.modules, modulo)
    self:addChild(modulo.element)
end

function LKS_Videogame_Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    print("[LKS PATCH - Videogame] createChildren: Criando módulos da janela...")

    -- Módulo: Tela (mini display de status)
    local painelTela = LKS_VG_PainelTela:new(0, 0, self.width, 0, self)
    self:addModule(painelTela, getText("IGUI_LKS_VG_Modo"), true)
    print("[LKS PATCH - Videogame] createChildren: Módulo Tela adicionado")

    -- Módulo: Energia (2 baterias + fone)
    local painelEnergia = LKS_VG_PainelEnergia:new(0, 0, self.width, 0, self)
    self:addModule(painelEnergia, getText("IGUI_LKS_VG_Energia"), true)
    print("[LKS PATCH - Videogame] createChildren: Módulo Energia adicionado")

    -- Módulo: Som (ícone alto-falante + barra indicativa + fone)
    local painelSom = LKS_VG_PainelSom:new(0, 0, self.width, 0, self)
    self:addModule(painelSom, getText("IGUI_LKS_VG_Som"), true)
    print("[LKS PATCH - Videogame] createChildren: Módulo Som adicionado")

    -- Módulo: Cartucho
    local painelCartucho = LKS_VG_PainelCartucho:new(0, 0, self.width, 0, self)
    self:addModule(painelCartucho, getText("IGUI_LKS_VG_Cartucho"), true)
    print("[LKS PATCH - Videogame] createChildren: Módulo Cartucho adicionado")

    print("[LKS PATCH - Videogame] createChildren: Janela criada com sucesso!")
end

-- ============================================================================
-- PRERENDER — Empilha módulos (igual ISRadioWindow)
-- ============================================================================

function LKS_Videogame_Window:prerender()
    self:stayOnSplitScreen()
    ISCollapsableWindow.prerender(self)

    local posicaoY = self:titleBarHeight() + 1
    for i = 1, #self.modules do
        if self.modules[i].enabled then
            self.modules[i].element:setY(posicaoY)
            self.modules[i].element:setVisible(true)
            posicaoY = posicaoY + self.modules[i].element:getHeight() + 1
        else
            self.modules[i].element:setVisible(false)
        end
    end
    self:setHeight(posicaoY + 10)
end

function LKS_Videogame_Window:stayOnSplitScreen()
    ISUIElement.stayOnSplitScreen(self, self.playerNum)
end

-- ============================================================================
-- UPDATE
-- ============================================================================

function LKS_Videogame_Window:update()
    ISCollapsableWindow.update(self)

    if self:getIsVisible() then
        if self.character and self.itemVideogame then
            local mao1 = self.character:getPrimaryHandItem()
            local mao2 = self.character:getSecondaryHandItem()
            if mao1 ~= self.itemVideogame and mao2 ~= self.itemVideogame then
                self:close()
                return
            end
        end
    end
end

-- ============================================================================
-- CLOSE
-- ============================================================================

function LKS_Videogame_Window:close()
    if self.estaJogando then
        self.estaJogando = false
        if self.character then
            ISTimedActionQueue.clear(self.character)
        end
    end
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end

-- ============================================================================
-- UTILITÁRIOS
-- ============================================================================

---@return boolean
function LKS_Videogame_Window:temBateriaDisponivel()
    local modData = self.itemVideogame:getModData()
    return ((modData["LKS_VG_bateria1_carga"] or 0) > 0) and ((modData["LKS_VG_bateria2_carga"] or 0) > 0)
end

-- ============================================================================
-- SINGLETON
-- ============================================================================

LKS_Videogame_Window.instancias = {}

---@param jogador IsoPlayer
---@param itemVideogame InventoryItem
---@return LKS_Videogame_Window
function LKS_Videogame_Window.abrir(jogador, itemVideogame)
    local playerNum = jogador:getPlayerNum()

    if LKS_Videogame_Window.instancias[playerNum] then
        local janela = LKS_Videogame_Window.instancias[playerNum]
        janela.itemVideogame = itemVideogame
        janela:addToUIManager()
        janela:setVisible(true)
        return janela
    end

    local largura = 320 + (getCore():getOptionFontSizeReal() * 40)
    local altura = 420
    local coordenadaX = getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - largura) / 2
    local coordenadaY = getPlayerScreenTop(playerNum) + (getPlayerScreenHeight(playerNum) - altura) / 2

    local janela = LKS_Videogame_Window:new(coordenadaX, coordenadaY, largura, altura, jogador, itemVideogame)
    janela:initialise()
    janela:instantiate()

    if playerNum == 0 then
        ISLayoutManager.RegisterWindow('lks_videogame', ISCollapsableWindow, janela)
    end

    janela:addToUIManager()
    janela:setVisible(true)

    LKS_Videogame_Window.instancias[playerNum] = janela
    return janela
end

-- ############################################################################
-- MÓDULO: TELA (mini display de status + botões Auto/Jogar)
-- ############################################################################

---@class LKS_VG_PainelTela : RWMPanel
LKS_VG_PainelTela = RWMPanel:derive("LKS_VG_PainelTela")

function LKS_VG_PainelTela:new(x, y, largura, altura, janelaVG)
    local o = RWMPanel:new(x, y, largura, altura)
    setmetatable(o, self)
    self.__index = self
    o.janelaVG = janelaVG
    return o
end

function LKS_VG_PainelTela:createChildren()
    local posicaoY = UI_BORDER_SPACING

    -- Mini tela
    local telaAltura = math.floor(FONT_HGT_SMALL * 2.5)
    local telaLargura = self.width - UI_BORDER_SPACING * 2
    self.telaX = UI_BORDER_SPACING
    self.telaY = posicaoY
    self.telaLargura = telaLargura
    self.telaAltura = telaAltura
    posicaoY = posicaoY + telaAltura + UI_BORDER_SPACING

    -- Botões [Auto] e [Jogar]
    local larguraBotao = math.floor((self.width - UI_BORDER_SPACING * 3) / 2)

    self.botaoAuto = ISButton:new(UI_BORDER_SPACING, posicaoY, larguraBotao, BUTTON_HGT, getText("IGUI_LKS_VG_Auto"),
        self, LKS_VG_PainelTela.onClickAuto)
    self.botaoAuto:initialise()
    self.botaoAuto.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    self.botaoAuto.backgroundColorMouseOver = { r = 1.0, g = 1.0, b = 1.0, a = 0.1 }
    self.botaoAuto.borderColor = { r = 1.0, g = 1.0, b = 1.0, a = 0.3 }
    self:addChild(self.botaoAuto)

    self.botaoJogar = ISButton:new(UI_BORDER_SPACING * 2 + larguraBotao, posicaoY, larguraBotao, BUTTON_HGT,
        getText("IGUI_LKS_VG_Jogar"), self, LKS_VG_PainelTela.onClickJogar)
    self.botaoJogar:initialise()
    self.botaoJogar.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    self.botaoJogar.backgroundColorMouseOver = { r = 1.0, g = 1.0, b = 1.0, a = 0.1 }
    self.botaoJogar.borderColor = { r = 1.0, g = 1.0, b = 1.0, a = 0.3 }
    self:addChild(self.botaoJogar)

    posicaoY = posicaoY + BUTTON_HGT + UI_BORDER_SPACING
    self:setHeight(posicaoY)
end

function LKS_VG_PainelTela:prerender()
    ISPanel.prerender(self)

    -- Moldura da tela
    self:drawRect(self.telaX - 1, self.telaY - 1, self.telaLargura + 2, self.telaAltura + 2, 1, 0.04, 0.04, 0.04)

    local jogando = self.janelaVG and self.janelaVG.estaJogando
    local temBateria = self.janelaVG and self.janelaVG:temBateriaDisponivel()

    -- Fundo da tela
    local corR, corG, corB = 0.04, 0.05, 0.04
    if jogando then corR, corG, corB = 0.015, 0.06, 0.015 end
    self:drawRect(self.telaX, self.telaY, self.telaLargura, self.telaAltura, 1, corR, corG, corB)

    if jogando then
        self:desenharAnimacaoJogando()
    elseif temBateria then
        local texto = "READY"
        local textoLargura = getTextManager():MeasureStringX(UIFont.Small, texto)
        self:drawText(texto, self.telaX + (self.telaLargura - textoLargura) / 2,
            self.telaY + (self.telaAltura - FONT_HGT_SMALL) / 2, 0.3, 0.55, 0.2, 1, UIFont.Small)
    else
        local texto = "OFF"
        local textoLargura = getTextManager():MeasureStringX(UIFont.Small, texto)
        self:drawText(texto, self.telaX + (self.telaLargura - textoLargura) / 2,
            self.telaY + (self.telaAltura - FONT_HGT_SMALL) / 2, 0.2, 0.2, 0.2, 1, UIFont.Small)
    end
end

--- Animação sofisticada para modo jogando
function LKS_VG_PainelTela:desenharAnimacaoJogando()
    -- Frame counter para animação (usa getTimestamp para sincronizar)
    local tempo = getTimestampMs()
    local frame = math.floor(tempo / 500) % 4
    local frameLento = math.floor(tempo / 200) % 8

    local centroX = self.telaX + self.telaLargura / 2
    local centroY = self.telaY + self.telaAltura / 2

    -- Cor base do texto (verde Game Boy com variação de brilho)
    local brilho = 0.7 + math.sin(tempo / 300) * 0.15
    local corTextoR = 0.4 * brilho
    local corTextoG = 0.85 * brilho
    local corTextoB = 0.15 * brilho

    -- Texto "PLAYING" centralizado com setas animadas
    local setas = {">>>", ">> ", ">  ", "   "}
    local setaEsquerda = setas[frame + 1]
    local setaDireita = string.reverse(setaEsquerda)
    local textoCompleto = setaEsquerda .. " PLAYING " .. setaDireita
    local textoLargura = getTextManager():MeasureStringX(UIFont.Small, textoCompleto)
    self:drawText(textoCompleto, centroX - textoLargura / 2,
        centroY - FONT_HGT_SMALL / 2 - 2,
        corTextoR, corTextoG, corTextoB, 1, UIFont.Small)

    -- Barra de atividade animada na parte inferior da tela
    local barraY = self.telaY + self.telaAltura - 6
    local barraLargura = self.telaLargura - 20
    local barraX = self.telaX + 10
    local numSegmentos = 12
    local segLargura = math.floor(barraLargura / numSegmentos) - 1

    for i = 0, numSegmentos - 1 do
        local ativo = ((i + frameLento) % numSegmentos) < 6
        local segX = barraX + i * (segLargura + 1)
        if ativo then
            local intensidade = 1.0 - (((i + frameLento) % 6) / 6.0) * 0.5
            self:drawRect(segX, barraY, segLargura, 4, 0.9, 0.2 * intensidade, 0.7 * intensidade, 0.1 * intensidade)
        else
            self:drawRect(segX, barraY, segLargura, 4, 0.3, 0.08, 0.08, 0.08)
        end
    end

    -- Scanline sutil (efeito CRT)
    local scanlineY = self.telaY + (math.floor(tempo / 50) % self.telaAltura)
    self:drawRect(self.telaX, scanlineY, self.telaLargura, 1, 0.08, 0.3, 0.6, 0.2)
end

function LKS_VG_PainelTela:update()
    ISPanel.update(self)
    local temBateria = self.janelaVG and self.janelaVG:temBateriaDisponivel()
    local modData = self.janelaVG and self.janelaVG.itemVideogame:getModData()
    local temCartucho = modData and modData["LKS_VG_cartuchoInserido"] ~= nil

    if self.botaoAuto then
        self.botaoAuto:setEnable(temBateria or false)
        if self.janelaVG and self.janelaVG.estaJogando then
            self.botaoAuto:setTitle(getText("IGUI_LKS_VG_Parar"))
        else
            self.botaoAuto:setTitle(getText("IGUI_LKS_VG_Auto"))
        end
    end
    if self.botaoJogar then
        self.botaoJogar:setEnable((temBateria and temCartucho) or false)
    end
end

function LKS_VG_PainelTela:onClickAuto()
    local janelaVG = self.janelaVG
    if not janelaVG then return end
    if not janelaVG:temBateriaDisponivel() then return end

    if janelaVG.estaJogando then
        janelaVG.estaJogando = false
        ISTimedActionQueue.clear(janelaVG.character)
    else
        janelaVG.estaJogando = true
        if LKS_Videogame_iniciarAcaoJogar then
            LKS_Videogame_iniciarAcaoJogar(janelaVG.character, janelaVG.itemVideogame)
        end
    end
end

function LKS_VG_PainelTela:onClickJogar()
    -- Futuro: abrir tela de minijogo
end

-- ############################################################################
-- MÓDULO: ENERGIA (LED + DropBox bateria + Barra % — x2 + Fone)
-- ############################################################################

---@class LKS_VG_PainelEnergia : RWMPanel
LKS_VG_PainelEnergia = RWMPanel:derive("LKS_VG_PainelEnergia")

function LKS_VG_PainelEnergia:new(x, y, largura, altura, janelaVG)
    local o = RWMPanel:new(x, y, largura, altura)
    setmetatable(o, self)
    self.__index = self
    o.janelaVG = janelaVG
    return o
end

function LKS_VG_PainelEnergia:createChildren()
    print("[LKS PATCH - Videogame] PainelEnergia: createChildren iniciado")
    local posicaoY = UI_BORDER_SPACING
    local jogador = self.janelaVG.character
    local offsetX = 0

    -- === BATERIA 1: [LED] [DropBox] [Barra %] ===
    self.led1 = ISLedLight:new(UI_BORDER_SPACING + 1, posicaoY + (BUTTON_HGT - UI_BORDER_SPACING * 2) / 2,
        UI_BORDER_SPACING * 2, UI_BORDER_SPACING * 2)
    self.led1:initialise()
    self.led1:setLedColor(1, 0, 1, 0)
    self.led1:setLedColorOff(1, 0, 0.3, 0)
    self:addChild(self.led1)
    offsetX = self.led1:getX() + self.led1:getWidth()

    self.drop1 = ISItemDropBox:new(offsetX + UI_BORDER_SPACING, posicaoY, BUTTON_HGT, BUTTON_HGT, false, self,
        LKS_VG_PainelEnergia.addBat1, LKS_VG_PainelEnergia.removeBat1, LKS_VG_PainelEnergia.verifyBat, nil)
    self.drop1:initialise()
    self.drop1.player = jogador
    self.drop1:setBackDropTex(getTexture("Item_Battery"), 0.4, 1, 1, 1)
    self.drop1:setDoBackDropTex(true)
    self.drop1:setToolTip(true, getText("IGUI_LKS_VG_ArrasteBateria"))
    self:addChild(self.drop1)
    offsetX = self.drop1:getX() + self.drop1:getWidth()

    self.barra1 = ISBatteryStatusDisplay:new(offsetX + UI_BORDER_SPACING, posicaoY,
        self.width - (offsetX + UI_BORDER_SPACING * 2), BUTTON_HGT, true)
    self.barra1:initialise()
    self.barra1:createChildren()
    self:addChild(self.barra1)

    posicaoY = posicaoY + BUTTON_HGT + 2

    -- === BATERIA 2: [LED] [DropBox] [Barra %] + [DropBox Fone] no final ===
    self.led2 = ISLedLight:new(UI_BORDER_SPACING + 1, posicaoY + (BUTTON_HGT - UI_BORDER_SPACING * 2) / 2,
        UI_BORDER_SPACING * 2, UI_BORDER_SPACING * 2)
    self.led2:initialise()
    self.led2:setLedColor(1, 0, 1, 0)
    self.led2:setLedColorOff(1, 0, 0.3, 0)
    self:addChild(self.led2)

    self.drop2 = ISItemDropBox:new(self.drop1:getX(), posicaoY, BUTTON_HGT, BUTTON_HGT, false, self,
        LKS_VG_PainelEnergia.addBat2, LKS_VG_PainelEnergia.removeBat2, LKS_VG_PainelEnergia.verifyBat, nil)
    self.drop2:initialise()
    self.drop2.player = jogador
    self.drop2:setBackDropTex(getTexture("Item_Battery"), 0.4, 1, 1, 1)
    self.drop2:setDoBackDropTex(true)
    self.drop2:setToolTip(true, getText("IGUI_LKS_VG_ArrasteBateria"))
    self:addChild(self.drop2)

    self.barra2 = ISBatteryStatusDisplay:new(self.barra1:getX(), posicaoY, self.barra1:getWidth(), BUTTON_HGT, true)
    self.barra2:initialise()
    self.barra2:createChildren()
    self:addChild(self.barra2)

    posicaoY = posicaoY + BUTTON_HGT + UI_BORDER_SPACING
    self:setHeight(posicaoY)
    print("[LKS PATCH - Videogame] PainelEnergia: createChildren concluído, altura=" .. tostring(posicaoY))
end

function LKS_VG_PainelEnergia:update()
    ISPanel.update(self)
    if not self.janelaVG or not self.janelaVG.itemVideogame then return end

    local modData = self.janelaVG.itemVideogame:getModData()
    local carga1 = (modData["LKS_VG_bateria1_carga"] or 0) / 100.0
    local carga2 = (modData["LKS_VG_bateria2_carga"] or 0) / 100.0
    local temBat1 = (modData["LKS_VG_bateria1_carga"] or 0) > 0 or modData["LKS_VG_bateria1_id"] ~= nil
    local temBat2 = (modData["LKS_VG_bateria2_carga"] or 0) > 0 or modData["LKS_VG_bateria2_id"] ~= nil

    self.barra1:setPower(carga1)
    self.led1:setLedIsOn(temBat1 and carga1 > 0)
    self.drop1:setStoredItemFake(temBat1 and getTexture("Item_Battery") or nil)
    self.drop1.boxOccupied = temBat1

    self.barra2:setPower(carga2)
    self.led2:setLedIsOn(temBat2 and carga2 > 0)
    self.drop2:setStoredItemFake(temBat2 and getTexture("Item_Battery") or nil)
    self.drop2.boxOccupied = temBat2
end

-- Callbacks bateria
function LKS_VG_PainelEnergia:verifyBat(item)
    return item:getFullType() == "Base.Battery"
end

function LKS_VG_PainelEnergia:addBat1(items)
    self:inserirBateria(1, items)
end

function LKS_VG_PainelEnergia:removeBat1()
    self:removerBateria(1)
end

function LKS_VG_PainelEnergia:addBat2(items)
    self:inserirBateria(2, items)
end

function LKS_VG_PainelEnergia:removeBat2()
    self:removerBateria(2)
end

function LKS_VG_PainelEnergia:inserirBateria(indiceSlot, items)
    local item = nil
    for _, candidato in ipairs(items) do
        if instanceof(candidato, "InventoryItem") then
            item = candidato
            break
        elseif type(candidato) == "table" and candidato.items then
            for idx, subItem in ipairs(candidato.items) do
                if idx ~= 1 and instanceof(subItem, "InventoryItem") then
                    item = subItem
                    break
                end
            end
            if item then break end
        end
    end
    if not item then return end

    local modData = self.janelaVG.itemVideogame:getModData()
    modData["LKS_VG_bateria" .. indiceSlot .. "_carga"] = item:getCurrentUsesFloat() * 100.0
    modData["LKS_VG_bateria" .. indiceSlot .. "_id"] = item:getID()
    self.janelaVG.character:getInventory():Remove(item)
end

function LKS_VG_PainelEnergia:removerBateria(indiceSlot)
    local modData = self.janelaVG.itemVideogame:getModData()
    local chaveCarga = "LKS_VG_bateria" .. indiceSlot .. "_carga"
    local chaveId = "LKS_VG_bateria" .. indiceSlot .. "_id"
    local carga = modData[chaveCarga]
    if carga and carga > 0 then
        local novaBateria = self.janelaVG.character:getInventory():AddItem("Base.Battery")
        if novaBateria then
            novaBateria:setUsedDelta(carga / 100.0)
        end
    end
    modData[chaveCarga] = nil
    modData[chaveId] = nil
end

-- ############################################################################
-- MÓDULO: SOM (ícone alto-falante + indicador + drop fone)
-- Layout idêntico ao RWMVolume do Walkie-Talkie
-- ############################################################################

---@class LKS_VG_PainelSom : RWMPanel
LKS_VG_PainelSom = RWMPanel:derive("LKS_VG_PainelSom")

function LKS_VG_PainelSom:new(x, y, largura, altura, janelaVG)
    local o = RWMPanel:new(x, y, largura, altura)
    setmetatable(o, self)
    self.__index = self
    o.janelaVG = janelaVG
    return o
end

function LKS_VG_PainelSom:createChildren()
    self:setHeight(UI_BORDER_SPACING * 2 + BUTTON_HGT + 2)
    local jogador = self.janelaVG.character

    -- Ícone de alto-falante (clicável — mute/unmute)
    self.iconeAltoFalante = ISButton:new(UI_BORDER_SPACING + 1, UI_BORDER_SPACING + 1, BUTTON_HGT, BUTTON_HGT, "", self, LKS_VG_PainelSom.onClickMute)
    self.iconeAltoFalante:initialise()
    self.iconeAltoFalante.backgroundColor = {r = 0, g = 0, b = 0, a = 0}
    self.iconeAltoFalante.backgroundColorMouseOver = {r = 1, g = 1, b = 1, a = 0.1}
    self.iconeAltoFalante.borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 0.5}
    self.iconeAltoFalante:setImage(getTexture("media/ui/LKS_Icone_Som_Ativo.png"))
    self.iconeAltoFalante.tooltip = getText("IGUI_LKS_VG_TooltipMute")
    self:addChild(self.iconeAltoFalante)

    -- Área da barra de volume (desenhada manualmente no prerender, clicável)
    local barraX = UI_BORDER_SPACING + BUTTON_HGT + UI_BORDER_SPACING + 1
    local foneX = self.width - BUTTON_HGT - UI_BORDER_SPACING - 1
    self.barraVolumeX = barraX
    self.barraVolumeY = UI_BORDER_SPACING + 3
    self.barraVolumeLargura = foneX - barraX - UI_BORDER_SPACING
    self.barraVolumeAltura = BUTTON_HGT - 4

    -- DropBox de fone no final da linha
    self.dropFone = ISItemDropBox:new(foneX, UI_BORDER_SPACING + 1, BUTTON_HGT, BUTTON_HGT, false, self,
        LKS_VG_PainelSom.addFone, LKS_VG_PainelSom.removeFone, LKS_VG_PainelSom.verifyFone, nil)
    self.dropFone:initialise()
    self.dropFone.player = jogador
    self.dropFone:setBackDropTex(getTexture("Item_Headphones"), 0.4, 1, 1, 1)
    self.dropFone:setDoBackDropTex(true)
    self.dropFone:setToolTip(true, getText("IGUI_LKS_VG_ArrasteFone"))
    self:addChild(self.dropFone)

    -- Inicializar volume no modData se não existir
    local modData = self.janelaVG.itemVideogame:getModData()
    if not modData["LKS_VG_volume"] then
        modData["LKS_VG_volume"] = LKS_VIDEOGAME.volumeInicial
    end
end

function LKS_VG_PainelSom:onClickMute()
    if not self.janelaVG or not self.janelaVG.itemVideogame then return end
    local modData = self.janelaVG.itemVideogame:getModData()
    if modData["LKS_VG_mutado"] then
        modData["LKS_VG_mutado"] = nil
    else
        modData["LKS_VG_mutado"] = true
    end
end

function LKS_VG_PainelSom:onMouseDown(coordenadaX, coordenadaY)
    ISPanel.onMouseDown(self, coordenadaX, coordenadaY)
    -- Verificar clique na barra de volume
    if coordenadaX >= self.barraVolumeX and coordenadaX <= self.barraVolumeX + self.barraVolumeLargura
        and coordenadaY >= self.barraVolumeY and coordenadaY <= self.barraVolumeY + self.barraVolumeAltura then
        local posicaoRelativa = (coordenadaX - self.barraVolumeX) / self.barraVolumeLargura
        local novoVolume = math.floor(posicaoRelativa * 100)
        novoVolume = math.max(0, math.min(100, novoVolume))
        local modData = self.janelaVG.itemVideogame:getModData()
        modData["LKS_VG_volume"] = novoVolume
        modData["LKS_VG_mutado"] = nil
    end
end

function LKS_VG_PainelSom:prerender()
    ISPanel.prerender(self)
    if not self.janelaVG or not self.janelaVG.itemVideogame then return end

    local modData = self.janelaVG.itemVideogame:getModData()
    local volume = (modData["LKS_VG_volume"] or LKS_VIDEOGAME.volumeInicial) / 100.0
    local mutado = modData["LKS_VG_mutado"]
    if mutado then volume = 0 end

    local bx = self.barraVolumeX
    local by = self.barraVolumeY
    local bw = self.barraVolumeLargura
    local bh = self.barraVolumeAltura

    -- Fundo da barra
    self:drawRect(bx, by, bw, bh, 0.8, 0.04, 0.04, 0.04)
    self:drawRectBorder(bx, by, bw, bh, 0.5, 0.25, 0.25, 0.25)

    -- Preenchimento gradiente (verde→amarelo→vermelho)
    local preenchimento = math.floor((bw - 2) * volume)
    if preenchimento > 0 then
        for i = 0, preenchimento - 1 do
            local proporcao = i / (bw - 2)
            local segR = math.min(1.0, proporcao * 2.5)
            local segG = math.min(1.0, (1.0 - proporcao) * 2.0)
            self:drawRect(bx + 1 + i, by + 1, 1, bh - 2, 0.9, segR, segG, 0.05)
        end
    end

    -- Texto de percentual centralizado
    local pctTexto = tostring(math.floor(volume * 100)) .. "%"
    local textoLargura = getTextManager():MeasureStringX(UIFont.Small, pctTexto)
    self:drawText(pctTexto, bx + (bw - textoLargura) / 2, by + (bh - FONT_HGT_SMALL) / 2, 1, 1, 1, 1, UIFont.Small)
end

function LKS_VG_PainelSom:update()
    ISPanel.update(self)
    if not self.janelaVG or not self.janelaVG.itemVideogame then return end
    local modData = self.janelaVG.itemVideogame:getModData()
    local mutado = modData["LKS_VG_mutado"]

    -- Alternar ícone
    if mutado then
        self.iconeAltoFalante:setImage(getTexture("media/ui/LKS_Icone_Som_Mutado.png"))
    else
        self.iconeAltoFalante:setImage(getTexture("media/ui/LKS_Icone_Som_Ativo.png"))
    end

    -- Atualizar fone (usar textura real do item inserido)
    local fone = modData["LKS_VG_fone_tipo"]
    if fone then
        -- Obter textura do item pelo fullType (ex: "Base.Earbuds" → "Item_Earbuds")
        local nomeIcone = string.match(fone, "%.(.+)$")
        local texturaFone = getTexture("Item_" .. (nomeIcone or "Headphones"))
        if not texturaFone then
            texturaFone = getTexture("Item_Headphones")
        end
        self.dropFone:setStoredItemFake(texturaFone)
        self.dropFone.boxOccupied = true
    else
        self.dropFone:setStoredItemFake(nil)
        self.dropFone.boxOccupied = false
    end
end

-- Callbacks fone
function LKS_VG_PainelSom:verifyFone(item)
    for _, tipoFone in ipairs(LKS_VIDEOGAME.fonesAceitos) do
        if item:getFullType() == tipoFone then return true end
    end
    return false
end

function LKS_VG_PainelSom:addFone(items)
    local item = nil
    for _, candidato in ipairs(items) do
        if instanceof(candidato, "InventoryItem") then
            item = candidato
            break
        end
    end
    if not item then return end

    local estaJogando = self.janelaVG and self.janelaVG.estaJogando
    local modData = self.janelaVG.itemVideogame:getModData()
    modData["LKS_VG_fone_tipo"] = item:getFullType()
    self.janelaVG.character:getInventory():Remove(item)

    -- Re-iniciar ação se estava jogando (inventário mudou → PZ cancela a TimedAction)
    if estaJogando then
        self.janelaVG.estaJogando = true
        modData["LKS_VG_jogando"] = true
        if LKS_Videogame_iniciarAcaoJogar then
            LKS_Videogame_iniciarAcaoJogar(self.janelaVG.character, self.janelaVG.itemVideogame)
        end
    end
end

function LKS_VG_PainelSom:removeFone()
    local modData = self.janelaVG.itemVideogame:getModData()
    local tipo = modData["LKS_VG_fone_tipo"]
    if not tipo then return end

    local estaJogando = self.janelaVG and self.janelaVG.estaJogando
    self.janelaVG.character:getInventory():AddItem(tipo)
    modData["LKS_VG_fone_tipo"] = nil

    -- Re-iniciar ação se estava jogando
    if estaJogando then
        self.janelaVG.estaJogando = true
        modData["LKS_VG_jogando"] = true
        if LKS_Videogame_iniciarAcaoJogar then
            LKS_Videogame_iniciarAcaoJogar(self.janelaVG.character, self.janelaVG.itemVideogame)
        end
    end
end

-- ############################################################################
-- MÓDULO: CARTUCHO
-- ############################################################################

---@class LKS_VG_PainelCartucho : RWMPanel
LKS_VG_PainelCartucho = RWMPanel:derive("LKS_VG_PainelCartucho")

function LKS_VG_PainelCartucho:new(x, y, largura, altura, janelaVG)
    local o = RWMPanel:new(x, y, largura, altura)
    setmetatable(o, self)
    self.__index = self
    o.janelaVG = janelaVG
    return o
end

function LKS_VG_PainelCartucho:createChildren()
    local posicaoY = UI_BORDER_SPACING

    self.dropCartucho = ISItemDropBox:new(UI_BORDER_SPACING, posicaoY, BUTTON_HGT, BUTTON_HGT, false, self, nil, nil, nil,
        nil)
    self.dropCartucho:initialise()
    self.dropCartucho.player = self.janelaVG.character
    self.dropCartucho:setBackDropTex(getTexture("Item_VideoGame"), 0.3, 1, 1, 1)
    self.dropCartucho:setDoBackDropTex(true)
    self.dropCartucho:setToolTip(true, getText("IGUI_LKS_VG_ArrasteCartucho"))
    self.dropCartucho.mouseEnabled = false
    self:addChild(self.dropCartucho)

    self.labelCartucho = ISLabel:new(UI_BORDER_SPACING + BUTTON_HGT + UI_BORDER_SPACING, posicaoY + 3, FONT_HGT_SMALL,
        getText("IGUI_LKS_VG_SemCartucho"), 0.4, 0.4, 0.4, 1, UIFont.Small, true)
    self.labelCartucho:initialise()
    self:addChild(self.labelCartucho)

    posicaoY = posicaoY + BUTTON_HGT + UI_BORDER_SPACING
    self:setHeight(posicaoY)
end

function LKS_VG_PainelCartucho:update()
    ISPanel.update(self)
end

print("[LKS PATCH - LKS_Videogame_Window.lua] Carregado com sucesso!")
