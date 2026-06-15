-- ============================================================================
-- 💖 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado como parte do LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) por sua fantástica contribuição para a comunidade!
-- ============================================================================

-- ============================================================================
-- ARQUIVO: LKS_EletricidadeConstrucao_UI_DebugPanel.lua
-- MOD ORIGINAL: Generator Powered Buildings (ID Workshop: 3597471949)
-- EXTENSÃO: LKS SuperMod Patch (Build 42)
-- OBJETIVO: Interface do Painel de Debug/Desenvolvedor do Mod
--           Acesso rápido a ferramentas de mapas de regiões e validação de tiles
-- AUTOR: LKSFERREIRA
-- DATA DE ATUALIZAÇÃO: 11/06/2026
-- ============================================================================

if not LKS_EletricidadeConstrucao then
    print("[LKS PATCH - LKS_EletricidadeConstrucao_UI_DebugPanel.lua] namespace LKS_EletricidadeConstrucao não encontrado - pulando carregamento do módulo")
    return
end

print("[LKS PATCH - LKS_EletricidadeConstrucao_UI_DebugPanel.lua] Carregando Painel de Depuração de Interface...")

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_UI_DebugPanel")
LKS_EletricidadeConstrucao.UI = LKS_EletricidadeConstrucao.UI or {}

-- ============================================================================
-- ⚙️ CONFIGURAÇÕES DE DIMENSÕES E ASSETS (PADRÃO DE NOMENCLATURA LKS_EletricidadeConstrucao)
-- ============================================================================
local WIN_W         = 420   -- Largura original (280) + 140 (50%) extra para alinhamento de imagens
local WIN_H         = 200   -- Redimensionado dinamicamente no createChildren via setHeight
local IMG_COL_W     = 140   -- Largura da coluna de imagem esquerda
local IMG_H         = 80    -- Altura por slot de imagem
local MARGIN        = 10
local BTN_H         = 25
local BTN_SPACING   = 5

-- Texturas da Interface de Debug (Corrigidas para o padrão LKS de prefixos)
local TEX_QUAD      = "media/ui/LKS_Square.png"
local TEX_HOUSE     = "media/ui/LKS_House.png"

-- ============================================================================
-- CLASSE
-- ============================================================================
local LKS_EletricidadeConstrucao_DebugPanel = ISCollapsableWindow:derive("LKS_EletricidadeConstrucao_DebugPanel")

-- ============================================================================
-- CICLO DE VIDA DA INTERFACE
-- ============================================================================

function LKS_EletricidadeConstrucao_DebugPanel:initialise()
    ISCollapsableWindow.initialise(self)
end

function LKS_EletricidadeConstrucao_DebugPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(false)

    local titleH = self:titleBarHeight()
    local y0     = titleH + MARGIN           -- O conteúdo começa abaixo da barra de título
    local btnX   = IMG_COL_W + MARGIN * 2    -- Coordenada X da coluna da direita
    local btnW   = WIN_W - btnX - MARGIN     -- Largura da coluna da direita

    -- Coluna Esquerda: Texturas que serão renderizadas no método render()
    self._texQuad  = getTexture(TEX_QUAD)
    self._texHouse = getTexture(TEX_HOUSE)
    self._imgX     = MARGIN
    self._imgY0    = y0
    self._imgW     = IMG_COL_W
    self._imgH     = IMG_H * 2 + MARGIN   -- Área combinada para ambas as imagens

    -- Coluna Direita: Botões centralizados verticalmente
    local rightH     = IMG_H * 2 + MARGIN          -- Altura total do conteúdo da coluna direita
    local btnsTotalH = BTN_H * 2 + BTN_SPACING     -- Altura total consumida por ambos os botões + espaçamento
    local halfW      = math.floor(btnW / 2)
    local halfX      = btnX + math.floor((btnW - halfW) / 2)
    local y          = y0 + math.floor((rightH - btnsTotalH) / 2)

    -- Botão: Abrir Painel de Regiões Isométricas (Engine do Jogo)
    self.btnIsoRegions = self:addButtonAt("Mapa IsoRegions", halfX, halfW, y, function()
        if IsoRegionsWindow then
            IsoRegionsWindow.OnOpenPanel()
        else
            print("[LKS PATCH - LKS_EletricidadeConstrucao_UI_DebugPanel.lua] Janela IsoRegionsWindow não está disponível no cliente")
        end
    end)
    
    -- Configuração do Tooltip Informativo do Botão
    local isoTooltip = ISToolTip:new()
    isoTooltip:initialise()
    isoTooltip:setName("Mapa de Regiões Isométricas (IsoRegions)")
    isoTooltip.description = "Abre a janela de radar e malhas de IsoRegions nativa do Project Zomboid.\nMostra salas estruturais, paredes fechadas e dados de chunk em tempo real no mapa.\n\nIdêntico ao caminho do jogo: Menu de Debug ➔ Dev ➔ IsoRegions"
    self.btnIsoRegions.toolTip = isoTooltip
    y = y + BTN_H + BTN_SPACING

    -- Botão: Fechar a HUD de Debug
    self.btnClose = self:addButtonAt("Fechar Painel", halfX, halfW, y, function()
        self:close()
    end)

    self:setHeight(y0 + IMG_H * 2 + MARGIN + MARGIN)
end

function LKS_EletricidadeConstrucao_DebugPanel:render()
    ISCollapsableWindow.render(self)

    local x = self._imgX
    local y = self._imgY0
    local w = self._imgW
    local h = self._imgH

    -- O retângulo de fundo (Quad) preenche a área total estipulada
    if self._texQuad then
        self:drawTextureScaled(self._texQuad, x, y, w, h, 1, 1, 1, 1)
    end

    -- O ícone da casa é desenhado centralizado por cima do fundo, sendo 20% menor para dar respiro visual
    if self._texHouse then
        local hw = w * 0.8
        local hh = h * 0.8
        local hx = x + (w - hw) / 2
        local hy = y + (h - hh) / 2
        self:drawTextureScaled(self._texHouse, hx, hy, hw, hh, 1, 1, 1, 1)
    end
end

function LKS_EletricidadeConstrucao_DebugPanel:addButtonAt(text, x, w, y, onClick)
    local btn = ISButton:new(x, y, w, BTN_H, text, self, onClick)
    btn:initialise()
    btn:instantiate()
    btn.borderColor = {r=1, g=1, b=1, a=0.2}
    self:addChild(btn)
    return btn
end

function LKS_EletricidadeConstrucao_DebugPanel:close()
    self:removeFromUIManager()
    LKS_EletricidadeConstrucao_DebugPanel.instance = nil
end

function LKS_EletricidadeConstrucao_DebugPanel:new(x, y)
    local o = ISCollapsableWindow:new(x, y, WIN_W, WIN_H)
    setmetatable(o, self)
    self.__index = self
    o.title = "Painel de Depuração LKS_EletricidadeConstrucao"
    o.moveWithMouse = true
    o.isCollapsed = false
    o.collapseCounter = 0
    o.resizable = false
    o.drawFrame = true
    o.backgroundColor = {r=0, g=0, b=0, a=0.9}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    return o
end

-- ============================================================================
-- 🔘 GERENCIAMENTO JOGADOR / MODO DE ATIVAÇÃO ALTERNADA (TOGGLE)
-- ============================================================================

function LKS_EletricidadeConstrucao_DebugPanel.Toggle()
    local player = getSpecificPlayer(0)
    if not player then return end
    
    local accessLevel = player:getAccessLevel()
    local isAdmin     = accessLevel ~= "None"
    local isDebug     = getDebug()
    
    -- Bloqueio de segurança: impede que jogadores normais usem o painel em servidores multiplayer
    if not isAdmin and not isDebug then
        player:Say("Acesso Negado: O painel de depuração requer modo Admin ou modo de Inicialização -Debug ativo.")
        return
    end
    
    if LKS_EletricidadeConstrucao_DebugPanel.instance then
        LKS_EletricidadeConstrucao_DebugPanel.instance:close()
        LKS_EletricidadeConstrucao_DebugPanel.instance = nil
    else
        local x = getCore():getScreenWidth() / 2 - WIN_W / 2
        local y = 50
        LKS_EletricidadeConstrucao_DebugPanel.instance = LKS_EletricidadeConstrucao_DebugPanel:new(x, y)
        LKS_EletricidadeConstrucao_DebugPanel.instance:initialise()
        LKS_EletricidadeConstrucao_DebugPanel.instance:addToUIManager()
    end
end

-- ============================================================================
-- ⌨️ SISTEMA DE ESCUTA DE TECLAS (HOTKEY CAPTURE)
-- ============================================================================

local function OnKeyPressed(key)
    -- Tecla Meno s (-) no teclado principal (Keyboard.KEY_MINUS = 12)
    -- Tecla Menos (-) no teclado numérico (Keyboard.KEY_SUBTRACT = 74)
    if key == 12 or key == 74 then
        LKS_EletricidadeConstrucao_DebugPanel.Toggle()
    end
end

Events.OnKeyPressed.Add(OnKeyPressed)

print("[LKS PATCH - LKS_EletricidadeConstrucao_UI_DebugPanel.lua] Interface de Debug carregada com sucesso!")
print("[LKS PATCH - LKS_EletricidadeConstrucao_UI_DebugPanel.lua] Use a tecla '-' (Teclado principal ou NumPad) para abrir/fechar (Apenas Admins/Modo Debug).")
