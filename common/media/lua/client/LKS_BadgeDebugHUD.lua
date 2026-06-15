-- ============================================================================
-- ARQUIVO: LKS_BadgeDebugHUD.lua
-- EXTENSÃO: LKS SuperMod Patch (Ferramenta de Depuração de Badges)
-- OBJETIVO: HUD interativa para ajuste fino de posição (X, Y) e escala dos
--           badges de status (NoPower/NoWater) na renderização do menu de
--           contexto. Ferramenta de desenvolvimento — remover em produção.
-- AUTOR: LKS FERREIRA & Antigravity AI
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- ATALHO: F9 para abrir/fechar
-- ============================================================================

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISLabel"

LKS_BadgeDebugHUD = ISPanel:derive("LKS_BadgeDebugHUD")
LKS_BadgeDebugHUD.instance = nil

function LKS_BadgeDebugHUD:initialise()
    ISPanel.initialise(self)
end

function LKS_BadgeDebugHUD:createChildren()
    ISPanel.createChildren(self)

    local margemEsquerda = 15
    local colunaControles = 110
    local alturaBotao = 24
    local larguraBotao = 28
    local larguraInput = 65
    local posicaoY = 10

    -- Carrega estado inicial baseado na badge NoPower
    local config = LKS_ApplianceManager and LKS_ApplianceManager.configBadgeMenu and
    LKS_ApplianceManager.configBadgeMenu.NoPower or { offsetX = 0, offsetY = 0, escala = 1.0 }
    self.offsetX = config.offsetX or 0
    self.offsetY = config.offsetY or 0
    self.escala = config.escala or 1.0
    self.caminhoBadgeAtual = "media/ui/LKS_Badge_NoPower.png"
    self.nomeBadgeAtual = "NoPower (Raio)"

    -- Título
    self.rotuloTitulo = ISLabel:new(margemEsquerda, posicaoY, 25, "LKS Badge Debug", 1, 1, 0.6, 1, UIFont.Medium, true)
    self:addChild(self.rotuloTitulo)

    -- Botão fechar
    self.botaoFechar = ISButton:new(self.width - 35, 8, 25, 20, "X", self, LKS_BadgeDebugHUD.aoFechar)
    self.botaoFechar:initialise()
    self.botaoFechar.backgroundColor = { r = 0.6, g = 0.1, b = 0.1, a = 0.8 }
    self:addChild(self.botaoFechar)

    posicaoY = posicaoY + 40

    -- ======================== Offset X ========================
    self.rotuloX = ISLabel:new(margemEsquerda, posicaoY + 3, 20, "Offset X:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.rotuloX)

    self.botaoXMenos = ISButton:new(colunaControles, posicaoY, larguraBotao, alturaBotao, "<", self,
        LKS_BadgeDebugHUD.aoAjustarValor, "offsetX", -1)
    self.botaoXMenos:initialise()
    self:addChild(self.botaoXMenos)

    self.entradaX = ISTextEntryBox:new(tostring(math.floor(self.offsetX)), colunaControles + larguraBotao + 4, posicaoY,
        larguraInput, alturaBotao)
    self.entradaX:initialise()
    self:addChild(self.entradaX)

    self.botaoXMais = ISButton:new(colunaControles + larguraBotao + larguraInput + 8, posicaoY, larguraBotao, alturaBotao,
        ">", self, LKS_BadgeDebugHUD.aoAjustarValor, "offsetX", 1)
    self.botaoXMais:initialise()
    self:addChild(self.botaoXMais)

    posicaoY = posicaoY + 32

    -- ======================== Offset Y ========================
    self.rotuloY = ISLabel:new(margemEsquerda, posicaoY + 3, 20, "Offset Y:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.rotuloY)

    self.botaoYMenos = ISButton:new(colunaControles, posicaoY, larguraBotao, alturaBotao, "^", self,
        LKS_BadgeDebugHUD.aoAjustarValor, "offsetY", -1)
    self.botaoYMenos:initialise()
    self:addChild(self.botaoYMenos)

    self.entradaY = ISTextEntryBox:new(tostring(math.floor(self.offsetY)), colunaControles + larguraBotao + 4, posicaoY,
        larguraInput, alturaBotao)
    self.entradaY:initialise()
    self:addChild(self.entradaY)

    self.botaoYMais = ISButton:new(colunaControles + larguraBotao + larguraInput + 8, posicaoY, larguraBotao, alturaBotao,
        "v", self, LKS_BadgeDebugHUD.aoAjustarValor, "offsetY", 1)
    self.botaoYMais:initialise()
    self:addChild(self.botaoYMais)

    posicaoY = posicaoY + 32

    -- ======================== Escala ========================
    self.rotuloEscala = ISLabel:new(margemEsquerda, posicaoY + 3, 20, "Escala:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.rotuloEscala)

    self.botaoEscalaMenos = ISButton:new(colunaControles, posicaoY, larguraBotao, alturaBotao, "-", self,
        LKS_BadgeDebugHUD.aoAjustarValor, "escala", -0.05)
    self.botaoEscalaMenos:initialise()
    self:addChild(self.botaoEscalaMenos)

    self.entradaEscala = ISTextEntryBox:new(string.format("%.2f", self.escala), colunaControles + larguraBotao + 4,
        posicaoY, larguraInput, alturaBotao)
    self.entradaEscala:initialise()
    self:addChild(self.entradaEscala)

    self.botaoEscalaMais = ISButton:new(colunaControles + larguraBotao + larguraInput + 8, posicaoY, larguraBotao,
        alturaBotao, "+", self, LKS_BadgeDebugHUD.aoAjustarValor, "escala", 0.05)
    self.botaoEscalaMais:initialise()
    self:addChild(self.botaoEscalaMais)

    posicaoY = posicaoY + 38

    -- ======================== Trocar Badge ========================
    self.botaoTrocarBadge = ISButton:new(margemEsquerda, posicaoY, self.width - 30, alturaBotao, "Badge: NoPower (Raio)",
        self, LKS_BadgeDebugHUD.aoTrocarBadge)
    self.botaoTrocarBadge:initialise()
    self:addChild(self.botaoTrocarBadge)

    posicaoY = posicaoY + 32

    -- Área de preview
    self.previewInicioY = posicaoY

    posicaoY = posicaoY + 175

    -- Botão copiar valores
    self.botaoAplicar = ISButton:new(margemEsquerda, posicaoY, self.width - 30, alturaBotao,
        "Imprimir Valores no Console", self, LKS_BadgeDebugHUD.aoAplicar)
    self.botaoAplicar:initialise()
    self.botaoAplicar.backgroundColor = { r = 0.1, g = 0.4, b = 0.15, a = 0.8 }
    self:addChild(self.botaoAplicar)
end

--- Callback unificado para ajustar qualquer valor numérico da HUD.
---
--- @param botao ISButton O botão pressionado.
--- @param campo string O nome do campo a ajustar ("offsetX", "offsetY", "escala").
--- @param delta number O incremento/decremento a aplicar.
function LKS_BadgeDebugHUD:aoAjustarValor(botao, campo, delta)
    if campo == "escala" then
        self.escala = math.max(0.1, self.escala + delta)
        self.escala = math.floor(self.escala * 100 + 0.5) / 100
        self.entradaEscala:setText(string.format("%.2f", self.escala))
    elseif campo == "offsetX" then
        self.offsetX = self.offsetX + delta
        self.entradaX:setText(tostring(math.floor(self.offsetX)))
    elseif campo == "offsetY" then
        self.offsetY = self.offsetY + delta
        self.entradaY:setText(tostring(math.floor(self.offsetY)))
    end
end

function LKS_BadgeDebugHUD:aoTrocarBadge()
    -- Salva os valores correntes da badge antiga antes de alternar
    local chaveAntiga = "NoPower"
    if self.nomeBadgeAtual == "NoWater (Gota)" then
        chaveAntiga = "NoWater"
    end
    LKS_ApplianceManager.configBadgeMenu[chaveAntiga] = {
        offsetX = self.offsetX,
        offsetY = self.offsetY,
        escala = self.escala
    }

    if self.nomeBadgeAtual == "NoPower (Raio)" then
        self.caminhoBadgeAtual = "media/ui/LKS_Badge_NoWater.png"
        self.nomeBadgeAtual = "NoWater (Gota)"
    else
        self.caminhoBadgeAtual = "media/ui/LKS_Badge_NoPower.png"
        self.nomeBadgeAtual = "NoPower (Raio)"
    end
    self.botaoTrocarBadge:setTitle("Badge: " .. self.nomeBadgeAtual)

    -- Carrega os valores da nova badge
    local chaveNova = "NoPower"
    if self.nomeBadgeAtual == "NoWater (Gota)" then
        chaveNova = "NoWater"
    end
    local config = LKS_ApplianceManager.configBadgeMenu[chaveNova] or LKS_ApplianceManager.configBadgeMenu.padrao
    self.offsetX = config.offsetX or 0
    self.offsetY = config.offsetY or 0
    self.escala = config.escala or 1.0

    self.entradaX:setText(tostring(math.floor(self.offsetX)))
    self.entradaY:setText(tostring(math.floor(self.offsetY)))
    self.entradaEscala:setText(string.format("%.2f", self.escala))
end

function LKS_BadgeDebugHUD:aoFechar()
    self:setVisible(false)
    self:removeFromUIManager()
    LKS_BadgeDebugHUD.instance = nil
end

function LKS_BadgeDebugHUD:aoAplicar()
    local key = "NoPower"
    if self.nomeBadgeAtual == "NoWater (Gota)" then
        key = "NoWater"
    end

    local mensagem = string.format(
        "[LKS Badge Debug] %s -> offsetX = %d, offsetY = %d, escala = %.2f",
        key, self.offsetX, self.offsetY, self.escala
    )
    print(mensagem)

    LKS_ApplianceManager = LKS_ApplianceManager or {}
    LKS_ApplianceManager.configBadgeMenu = LKS_ApplianceManager.configBadgeMenu or {}
    LKS_ApplianceManager.configBadgeMenu[key] = {
        offsetX = self.offsetX,
        offsetY = self.offsetY,
        escala = self.escala
    }

    print("[LKS Badge Debug] Valores salvos em LKS_ApplianceManager.configBadgeMenu[" .. key .. "]")
end

function LKS_BadgeDebugHUD:prerender()
    ISPanel.prerender(self)

    -- Sincroniza valores digitados manualmente nos campos de texto
    local valorX = tonumber(self.entradaX:getText())
    local valorY = tonumber(self.entradaY:getText())
    local valorEscala = tonumber(self.entradaEscala:getText())

    if valorX then self.offsetX = valorX end
    if valorY then self.offsetY = valorY end
    if valorEscala and valorEscala > 0 then self.escala = valorEscala end
end

function LKS_BadgeDebugHUD:render()
    ISPanel.render(self)

    local areaX = 15
    local areaY = self.previewInicioY
    local areaLargura = self.width - 30
    local areaAltura = 130

    -- Fundo da área de preview
    self:drawRect(areaX, areaY, areaLargura, areaAltura, 0.4, 0.08, 0.08, 0.12)
    self:drawRectBorder(areaX, areaY, areaLargura, areaAltura, 0.7, 0.4, 0.4, 0.5)

    local centroX = areaX + areaLargura / 2
    local centroY = areaY + areaAltura / 2

    -- Crosshair de referência central
    self:drawRect(centroX - 1, areaY + 5, 2, areaAltura - 10, 0.15, 1, 1, 1)
    self:drawRect(areaX + 5, centroY - 1, areaLargura - 10, 2, 0.15, 1, 1, 1)

    -- Ícone de referência (container) no centro com opacidade reduzida
    local texReferencia = getTexture("media/ui/Container_ClothingWasher.png")
    if texReferencia then
        local refLargura = texReferencia:getWidth()
        local refAltura = texReferencia:getHeight()
        self:drawTexture(texReferencia, centroX - refLargura / 2, centroY - refAltura / 2, 0.4, 1, 1, 1)
    end

    -- Desenha o badge com offset e escala aplicados
    local texBadge = getTexture(self.caminhoBadgeAtual)
    if texBadge then
        local badgeLarguraOriginal = texBadge:getWidth()
        local badgeAlturaOriginal = texBadge:getHeight()
        local badgeLarguraEscalada = badgeLarguraOriginal * self.escala
        local badgeAlturaEscalada = badgeAlturaOriginal * self.escala
        local desenhoX = centroX - badgeLarguraEscalada / 2 + self.offsetX
        local desenhoY = centroY - badgeAlturaEscalada / 2 + self.offsetY

        self:drawTextureScaledAspect(texBadge, desenhoX, desenhoY, badgeLarguraEscalada, badgeAlturaEscalada, 1.0, 1, 1,
            1)
    end

    -- Valores atuais abaixo do preview
    local infoTexto = string.format("X: %d   Y: %d   Escala: %.2f", self.offsetX, self.offsetY, self.escala)
    self:drawText(infoTexto, areaX + 5, areaY + areaAltura + 4, 0.7, 0.8, 1, 0.8, UIFont.Small)
end

function LKS_BadgeDebugHUD:new(posicaoX, posicaoY)
    local largura = 280
    local altura = 400
    local objeto = ISPanel:new(posicaoX, posicaoY, largura, altura)
    setmetatable(objeto, self)
    self.__index = self
    objeto.backgroundColor = { r = 0.06, g = 0.06, b = 0.12, a = 0.92 }
    objeto.borderColor = { r = 0.3, g = 0.3, b = 0.5, a = 1 }
    objeto.moveWithMouse = true
    return objeto
end

function LKS_BadgeDebugHUD.toggle()
    if LKS_BadgeDebugHUD.instance then
        LKS_BadgeDebugHUD.instance:aoFechar()
    else
        local larguraTela = getCore():getScreenWidth()
        local alturaTela = getCore():getScreenHeight()
        local hudInstancia = LKS_BadgeDebugHUD:new(larguraTela / 2 - 140, alturaTela / 2 - 200)
        hudInstancia:initialise()
        hudInstancia:addToUIManager()
        LKS_BadgeDebugHUD.instance = hudInstancia
    end
end

-- Atalho F9 para abrir/fechar a HUD de depuração de badges
local function aoTeclaPressionada(tecla)
    if tecla == Keyboard.KEY_F12 then
        LKS_BadgeDebugHUD.toggle()
    end
end

Events.OnKeyPressed.Add(aoTeclaPressionada)

print("[LKS PATCH - LKS_BadgeDebugHUD.lua] HUD de depuracao de badges carregada (F9 para abrir).")
