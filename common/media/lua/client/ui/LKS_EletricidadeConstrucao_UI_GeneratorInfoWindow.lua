-- ============================================================================
-- 💖 HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado como parte do LKS SuperMod Patch.
-- Agradecemos imensamente a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) por sua fantástica contribuição para a comunidade!
-- ============================================================================

-- ============================================================================
-- ARQUIVO: LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow.lua
-- MOD ORIGINAL: Generator Powered Buildings (ID Workshop: 3597471949)
-- EXTENSÃO: LKS SuperMod Patch (Build 42)
-- OBJETIVO: Correção de alinhamento visual, UX/UI e tradução adaptativa
-- AUTOR: LKSFERREIRA
-- DATA DE ATUALIZAÇÃO: 10/06/2026
-- ============================================================================
-- Descrição: Janela de Informações Elétricas da Construção - Painel de status
-- central acessível de qualquer interruptor de luz.
-- Recursos: Barras de Combustível/Condição, estimativa de duração, detalhamento
-- de consumidores, contagem de Eletrodomésticos/Luzes, aviso de carga, botão
-- Mostrar Alcance, clique para caminhar até o gerador.
-- Fonte de dados: generator:get*() + Gen_Stats_* ModData (sincronizado ~10s)
-- ============================================================================

if not LKS_EletricidadeConstrucao then
    print(
        "[LKS PATCH - LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow.lua] namespace LKS_EletricidadeConstrucao não encontrado - pulando carregamento do módulo")
    return
end

print("[LKS PATCH - LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow.lua] Carregando Janela de Informacoes do Gerador com correcoes de HUD...")

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow")
LKS_EletricidadeConstrucao.UI    = LKS_EletricidadeConstrucao.UI or {}

-- ============================================================================
-- ⚙️ CONFIGURAÇÕES DE LAYOUT E DESIGN (MANUTENÇÃO DE INTERFACE)
-- ============================================================================
local MIN_WIN_W        = 485 -- Largura ampliada para evitar quebra de textos por extenso
local MARGIN           = 14  -- Espaçamento das bordas internas da janela
local BAR_W            = 140 -- Largura padrão das barras de status
local BAR_H            = 11  -- Altura padrão das barras de status
local LINE_H           = 22  -- Altura da linha para garantir respiro vertical na interface
local FONT_S           = UIFont.Small
local FONT_M           = UIFont.Medium

-- ============================================================================
-- 🖼️ CAMINHOS DE TEXTURAS E ASSETS NATIVOS/MODDED
-- ============================================================================
local GEN_ICON_PATH    = "Item_Generator" -- Busca o ícone vanilla nativo do jogo
local WARN_TEX_PATH    = "media/ui/LKS_Warning.png"
local OVERL_TEX_PATH   = "media/ui/LKS_Overload.png"
local THERM_UP_PATH    = "media/ui/LKS_Therm_Up.png"
local THERM_DOWN_PATH  = "media/ui/LKS_Therm_Down.png"
local HEAT_ON_PATH     = "media/ui/LKS_Heat_On.png"            -- Ícone de chama (termostato ativo)
local HEAT_OFF_PATH    = "media/ui/LKS_Heat_Standby.png"           -- Ícone de floco de neve (termostato inativo)
local STRAIN_SEG_PATH  = "media/ui/LKS_Progressbar_Strain.png" -- Textura de um único segmento da barra

-- ============================================================================
-- 🎯 TABELA DE CALIBRAÇÃO DE PIXELS (MÉTODO DE AJUSTE FINO LKS)
-- Eixo X: + Move Direita, - Move Esquerda
-- Eixo Y: + Move Cima,    - Move Baixo
-- ============================================================================
local HUD_Offsets      = {
    iconGenerator         = { x = 0, y = -6 },
    iconGallon            = { x = 0, y = 0 },
    barGas                = { x = 0, y = 0 },
    valueAmountGas        = { x = 0, y = 4 },
    barStrain             = { x = -4, y = -8 },
    valuePorcentageStrain = { x = 0, y = 0 },
    arrowAndColdIcon      = { x = 0, y = -5 },
    arrowAndHotIcon       = { x = 0, y = -5 },
    labelStandby          = { x = 0, y = 6 },
    labelActive           = { x = 0, y = 6 }
}

-- ============================================================================
-- 🎨 AJUSTE DE OPACIDADE DO DESTAQUE DO TERMOSTATO (0% a 100%)
-- Segue o modelo padrão do canal alfa RGBA:
-- 100 = 100% Opaco (alfa = 1.0, cor sólida)
-- 0   = 0% Opaco / Totalmente Transparente (alfa = 0.0, invisível)
-- ============================================================================
local Thermostat_Alpha = {
    activeHighlight = 20 -- Opacidade do realce do botão selecionado (0% a 100%)
}

-- ============================================================================
-- AUXILIARES
-- ============================================================================

--- Encontra o quadrado caminhável mais próximo adjacente a um quadrado alvo,
--- ordenado por proximidade a fromChar para que o jogador se aproxime naturalmente.
--- Retorna: adjSquare, valor IsoDirections para olhar em direção a targetSq (or nil, nil).
local function FindAdjacentWalkable(targetSq, fromChar)
    if not targetSq then return nil, nil end
    local tx, ty, tz = targetSq:getX(), targetSq:getY(), targetSq:getZ()
    local cell = getCell()
    if not cell then return nil, nil end
    -- {dx, dy, direção para olhar ao ficar no quadrado adjacente olhando de volta para o barril}
    local offsets = {
        { 1,  0,  IsoDirections.W }, -- fique a Leste,  olhe para Oeste
        { -1, 0,  IsoDirections.E }, -- fique a Oeste, olhe para Leste
        { 0,  1,  IsoDirections.N }, -- fique ao Sul, olhe para Norte
        { 0,  -1, IsoDirections.S }, -- fique ao Norte, olhe para Sul
    }
    -- Ordena por distância até o personagem para escolher a aproximação mais próxima
    local cx, cy = fromChar:getX(), fromChar:getY()
    table.sort(offsets, function(a, b)
        local da = (tx + a[1] - cx) ^ 2 + (ty + a[2] - cy) ^ 2
        local db = (tx + b[1] - cx) ^ 2 + (ty + b[2] - cy) ^ 2
        return da < db
    end)
    for _, o in ipairs(offsets) do
        local sq = cell:getGridSquare(tx + o[1], ty + o[2], tz)
        if sq and sq:isFree(false) then
            return sq, o[3]
        end
    end
    return nil, nil
end

-- ============================================================
-- CLASSE
-- ============================================================

local LKS_EletricidadeConstrucao_GeneratorInfoWindow = ISCollapsableWindow:derive("LKS_EletricidadeConstrucao_GeneratorInfoWindow")
LKS_EletricidadeConstrucao_GeneratorInfoWindow.instances = {}

-- Registro de destaque em nível de módulo.
-- Preenchido por applyHighlights(true), limpo por applyHighlights(false) ou ao fechar.
-- OnRenderTick dispara ANTES dos tiles do mundo serem desenhados, então os destaques estão sempre atualizados.
local _activeHighlights = nil

Events.OnRenderTick.Add(function()
    if not _activeHighlights then return end
    for _, obj in ipairs(_activeHighlights) do
        pcall(function()
            if obj.setHighlightColor then
                obj:setHighlightColor(0.10, 0.80, 1.00, 0.75)
            end
            obj:setHighlighted(true)
        end)
    end
end)

-- ============================================================
-- CICLO DE VIDA
-- ============================================================

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(false)

    -- Botão "Mostrar Alcance"
    local btnW, btnH = 135, 25
    self.coverageBtn = ISButton:new(
        MARGIN, 999,
        btnW, btnH,
        getText("IGUI_ShowCoverage") or "Mostrar Alcance",
        self, LKS_EletricidadeConstrucao_GeneratorInfoWindow.onToggleCoverage
    )
    self.coverageBtn:initialise()
    self.coverageBtn:instantiate()
    self.coverageBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.15 }
    self:addChild(self.coverageBtn)
    self.showCoverage = false

    -- Botão Fechar (a posição será atualizada em render)
    local closeBtnW = 90
    self.closeBtn = ISButton:new(
        MIN_WIN_W - MARGIN - closeBtnW, 999,
        closeBtnW, btnH,
        getText("UI_Close") or "Fechar",
        self, LKS_EletricidadeConstrucao_GeneratorInfoWindow.onClose
    )
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self.closeBtn.borderColor = { r = 0.70, g = 0.15, b = 0.15, a = 1.0 }
    self.closeBtn.backgroundColor = { r = 0.55, g = 0.10, b = 0.10, a = 1.0 }
    self.closeBtn.backgroundColorMouseOver = { r = 0.90, g = 0.10, b = 0.10, a = 1.0 }
    self:addChild(self.closeBtn)

    -- Dados em cache (atualizados a cada 1 segundo)
    self.cachedData        = {
        fuel = 0,
        maxFuel = 10,
        condition = 0,
        isActivated = false,
        buildingID = nil,
        consumerCount = 0,
        lightCount = 0,
        lampCount = 0,
        applianceCount = 0,
        powerDraw = 0,
        strain = 0,
        isPowered = false,
        totalFuel = 0,
        totalMaxFuel = 0,
    }
    self.lastUpdate        = 0
    self.allGenerators     = {}
    self._genClickAreas    = {} -- {y1, y2, gen} por linha de gerador
    self._hoveredGenIdx    = nil
    self._barrelClickAreas = {} -- {y1, y2, sq} por linha de barril
    self._hoveredBarrelIdx = nil
    self._genTexCache      = {}
    self._hadBuildingLink  = false
end

-- ============================================================
-- AUXILIARES
-- ============================================================

--- Calcula as dimensões ideais do layout com base nas strings do idioma atual.
--- Retorna: { winW, barCol }
function LKS_EletricidadeConstrucao_GeneratorInfoWindow:calculateLayout()
    local textMgr = getTextManager()
    local maxLabelW = 0

    local labels = {
        getText("IGUI_LKS_EletricidadeConstrucao_PoolFuel") or "Combustível do Reservatório",
        getText("IGUI_LKS_EletricidadeConstrucao_PowerDraw") or "Consumo Elétrico",
        getText("IGUI_LKS_EletricidadeConstrucao_FuelRate") or "Consumo de Combustível",
        getText("IGUI_EstRuntime") or "Duração Estimada",
        getText("IGUI_SystemStrain") or "Carga da Rede Elétrica",
        getText("IGUI_LKS_EletricidadeConstrucao_Consumers") or "Aparelhos Conectados",
        getText("IGUI_Lights") or "Luzes",
        getText("IGUI_LKS_EletricidadeConstrucao_Lamps") or "Lâmpadas",
        getText("IGUI_LKS_EletricidadeConstrucao_Appliances") or "Eletrodomésticos",
        getText("IGUI_LKS_EletricidadeConstrucao_TargetTemp") or "Ajustar Temperatura",
    }

    for _, lbl in ipairs(labels) do
        local cleanLbl = string.gsub(lbl, ":%s*$", "")
        local w = textMgr:MeasureStringX(FONT_S, cleanLbl .. ":")
        if w > maxLabelW then maxLabelW = w end
    end

    local barCol = maxLabelW + 12

    local maxValueW = 0
    local sampleValues = {
        "213.5 " .. (getText("IGUI_LKS_EletricidadeConstrucao_UnitsPerGen") or "Unidades por gerador"),
        "0.288 " .. (getText("IGUI_LKS_EletricidadeConstrucao_LitresPerHour") or "Litros por hora"),
        "~1" .. (getText("IGUI_LKS_EletricidadeConstrucao_Days") or " dias") .. " 9" .. (getText("IGUI_LKS_EletricidadeConstrucao_Hours") or " horas")
    }
    for _, val in ipairs(sampleValues) do
        local w = textMgr:MeasureStringX(FONT_S, val)
        if w > maxValueW then maxValueW = w end
    end

    -- Largura Dinâmica Absoluta: Margem + Coluna Rótulos + Coluna Valores + Margem Direita + Margem de Segurança
    local winW = math.max(MIN_WIN_W, MARGIN + barCol + maxValueW + MARGIN + 24)

    return { winW = winW, barCol = barCol }
end

--- Barra de progresso com rótulo. greenHigh=true: verde=alto é bom.
function LKS_EletricidadeConstrucao_GeneratorInfoWindow:drawStatBar(x, y, label, value, maxValue, greenHigh, barCol)
    value      = value or 0
    maxValue   = maxValue or 100
    local opts = nil
    if type(greenHigh) == "table" then
        opts = greenHigh
        greenHigh = opts.greenHigh
    end
    local pct = maxValue > 0 and math.max(0, math.min(1, value / maxValue)) or 0

    -- ITEM 1: Impede duplicação de dois pontos na renderização
    local cleanLbl = string.gsub(label or "", ":%s*$", "")
    self:drawText(cleanLbl .. ":", x, y + math.floor((LINE_H - 12) / 2), 1, 1, 1, 0.8, FONT_S)

    local barW = (opts and opts.width) or BAR_W
    local bx = x + (barCol or 90)
    local by = y + math.floor((LINE_H - BAR_H) / 2)
    self:drawRect(bx, by, barW, BAR_H, 0.9, 0.10, 0.10, 0.10)

    local r, g, b
    if opts and opts.color then
        r, g, b = opts.color[1] or 1, opts.color[2] or 1, opts.color[3] or 0.6
    elseif greenHigh then
        if pct >= 0.5 then
            r, g, b = 0.15, 0.80, 0.25
        elseif pct >= 0.25 then
            r, g, b = 0.90, 0.78, 0.08
        else
            r, g, b = 0.90, 0.22, 0.18
        end
    else
        if pct < 0.25 then
            r, g, b = 0.15, 0.80, 0.25
        elseif pct < 0.5 then
            r, g, b = 0.90, 0.78, 0.08
        elseif pct < 0.75 then
            r, g, b = 1.00, 0.50, 0.10
        else
            r, g, b = 0.90, 0.22, 0.18
        end
    end

    self:drawRect(bx, by, math.max(2, math.floor(barW * pct)), BAR_H, 0.9, r, g, b)
    self:drawRectBorder(bx, by, barW, BAR_H, 0.65, 0.40, 0.40, 0.40)
    if not opts or opts.showPct ~= false then
        self:drawText(string.format("%.0f%%", pct * 100), bx + barW + 4, y + math.floor((LINE_H - 12) / 2), r, g, b, 1,
            FONT_S)
    end

    return y + LINE_H
end

--- Barra de carga baseada em imagem com 10 segmentos. Verde (1-4) → laranja (5-7) → vermelho (8-10).
function LKS_EletricidadeConstrucao_GeneratorInfoWindow:drawStrainBar(x, y, label, strain, barCol)
    strain         = strain or 0
    local pct      = math.max(0, math.min(1, strain / 100))
    local segValue = pct * 10
    local fullSegs = math.floor(segValue)
    local partial  = segValue - fullSegs

    -- ITEM 1: Mantém apenas um único dois pontos limpo na tela
    local cleanLbl = string.gsub(label or "Carga da Rede Elétrica", ":%s*$", "")
    self:drawText(cleanLbl .. ":", x, y + 5, 1, 1, 1, 0.8, FONT_S)

    -- Carrega a textura do segmento sob demanda
    self._strainSegTex = self._strainSegTex or getTexture(STRAIN_SEG_PATH)

    local SEG_COUNT    = 10
    local SEG_GAP      = 1
    local segW         = math.floor((BAR_W - SEG_GAP * (SEG_COUNT - 1)) / SEG_COUNT)
    local bx           = x + (barCol or 90)

    -- Posição vertical padrão da barra de blocos
    local by_base      = y + 5

    -- Aplicação das cores por posição do segmento (1-4 verde, 5-7 laranja, 8-10 vermelho)
    local function segRGB(i)
        if i <= 4 then
            return 0.15, 0.80, 0.25
        elseif i <= 7 then
            return 1.00, 0.55, 0.10
        else
            return 0.90, 0.22, 0.18
        end
    end

    -- Loop de renderização dos 10 blocos da barra
    for i = 1, SEG_COUNT do
        -- Cálculo da posição X padrão de cada bloco
        local sx_base = bx + (i - 1) * (segW + SEG_GAP)

        -- INJEÇÃO DE VARIÁVEIS (barStrain): Aplica seus offsets X e Y nos blocos
        local sx_final = sx_base + HUD_Offsets.barStrain.x
        local by_final = by_base - HUD_Offsets.barStrain.y

        -- Desenha o fundo escuro do slot do bloco
        self:drawRect(sx_final, by_final, segW, BAR_H, 0.85, 0.08, 0.08, 0.08)

        local r, g, b = segRGB(i)
        if i <= fullSegs then
            -- Segmento cheio
            if self._strainSegTex then
                self:drawTextureScaled(self._strainSegTex, sx_final, by_final, segW, BAR_H, 0.95, r, g, b)
            else
                self:drawRect(sx_final, by_final, segW, BAR_H, 0.95, r, g, b)
            end
        elseif i == fullSegs + 1 and partial > 0 then
            -- Preenchimento parcial do bloco
            local partW = math.max(2, math.floor(segW * partial))
            if self._strainSegTex then
                self:drawTextureScaled(self._strainSegTex, sx_final, by_final, partW, BAR_H, 0.95, r, g, b)
            else
                self:drawRect(sx_final, by_final, partW, BAR_H, 0.95, r, g, b)
            end
        end
    end

    -- Posição padrão do texto de porcentagem (ex: 27%)
    local textX_base = bx + BAR_W + 4
    local textY_base = y + 5

    -- INJEÇÃO DE VARIÁVEIS (valuePorcentageStrain): Aplica seus offsets X e Y no texto da porcentagem
    local textX_final = textX_base + HUD_Offsets.valuePorcentageStrain.x
    local textY_final = textY_base - HUD_Offsets.valuePorcentageStrain.y

    local lr, lg, lb = segRGB(math.max(1, math.min(SEG_COUNT, math.ceil(segValue))))
    self:drawText(string.format("%.0f%%", math.max(0, strain)), textX_final, textY_final, lr, lg, lb, 1, FONT_S)

    return y + LINE_H
end

--- Barra de combustível amarela gasolina com 6 segmentos para barris.
function LKS_EletricidadeConstrucao_GeneratorInfoWindow:drawBarrelFuelBar(x, y, amount, maxAmount, barWidth)
    amount             = amount or 0
    maxAmount          = maxAmount or 25
    barWidth           = barWidth or math.floor(BAR_W * 0.7)

    local pct          = maxAmount > 0 and math.max(0, math.min(1, amount / maxAmount)) or 0
    local SEG_COUNT    = 6
    local SEG_GAP      = 2
    local segW         = math.floor((barWidth - SEG_GAP * (SEG_COUNT - 1)) / SEG_COUNT)
    local by           = y + math.floor((LINE_H - BAR_H) / 2)

    local vermelho, verde, azul = 0.97, 0.93, 0.55 -- cor do segmento cheio
    self._strainSegTex = self._strainSegTex or getTexture(STRAIN_SEG_PATH)

    local segValue     = pct * SEG_COUNT
    local fullSegs     = math.floor(segValue)
    local partial      = segValue - fullSegs

    for i = 1, SEG_COUNT do
        local sx = x + (i - 1) * (segW + SEG_GAP)
        self:drawRect(sx, by, segW, BAR_H, 0.85, 0.08, 0.08, 0.08)
        if i <= fullSegs then
            if self._strainSegTex then
                self:drawTextureScaled(self._strainSegTex, sx, by, segW, BAR_H, 0.95, vermelho, verde, azul)
            else
                self:drawRect(sx, by, segW, BAR_H, 0.95, vermelho, verde, azul)
            end
        elseif i == fullSegs + 1 and partial > 0 then
            local partW = math.max(2, math.floor(segW * partial))
            if self._strainSegTex then
                self:drawTextureScaled(self._strainSegTex, sx, by, partW, BAR_H, 0.95, vermelho, verde, azul)
            else
                self:drawRect(sx, by, partW, BAR_H, 0.95, vermelho, verde, azul)
            end
        end
    end
end

--- Separador fino + título da seção. Retorna o próximo Y.
function LKS_EletricidadeConstrucao_GeneratorInfoWindow:drawSection(x, y, title)
    self:drawRect(x, y, self.width - MARGIN * 2, 1, 0.55, 0.30, 0.30, 0.30)
    y = y + 5
    self:drawText(title, x, y, 0.50, 0.78, 1.0, 1, FONT_M)
    return y + 22
end

--- Resolve uma textura para um sprite específico de gerador, com cache e fallback.
function LKS_EletricidadeConstrucao_GeneratorInfoWindow:getGeneratorIcon(gen)
    self._genIconTex = self._genIconTex or getTexture(GEN_ICON_PATH)
    if not gen then return self._genIconTex end

    local spriteName = gen.getSpriteName and gen:getSpriteName()
    if not spriteName and gen.getSprite and gen:getSprite() then
        spriteName = gen:getSprite():getName()
    end
    if not spriteName then return self._genIconTex end

    if self._genTexCache and self._genTexCache[spriteName] ~= nil then
        return self._genTexCache[spriteName]
    end

    local tex = getTexture("media/textures/" .. spriteName .. ".png")
    if not tex then tex = self._genIconTex end

    self._genTexCache = self._genTexCache or {}
    self._genTexCache[spriteName] = tex
    return tex
end

local function TableContainsValue(t, value)
    if type(t) ~= "table" then return false end
    for _, entry in pairs(t) do
        if entry == value then return true end
    end
    return false
end

local function TableCountEntries(t)
    local count = 0
    if type(t) ~= "table" then return count end
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function IsInsideBuildingBounds(buildingData, x, y)
    local bb = buildingData and buildingData.boundingBox
    if type(bb) ~= "table" then return false end

    local minX = tonumber(bb.minX or bb[1])
    local minY = tonumber(bb.minY or bb[2])
    local maxX = tonumber(bb.maxX or bb[3])
    local maxY = tonumber(bb.maxY or bb[4])
    if not (minX and minY and maxX and maxY) then
        return false
    end

    return x >= (minX - 1) and x <= (maxX + 1)
        and y >= (minY - 1) and y <= (maxY + 1)
end

local function FindLoadedGeneratorAt(x, y, z)
    local cell = getCell()
    if not cell then return nil end

    local sq = cell:getGridSquare(x, y, z)
    if not sq then return nil end

    local objs = sq:getObjects()
    if not objs then return nil end

    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj and instanceof(obj, "IsoGenerator") then
            return obj
        end
    end

    return nil
end

local function CountBuildingConsumers(buildingData)
    local stats = {
        consumerCount = 0,
        activeConsumerCount = tonumber(buildingData and buildingData.activeConsumerCount) or 0,
        lightCount = 0,
        activeLightCount = 0,
        applianceCount = 0,
        activeApplianceCount = 0,
    }

    if not buildingData or type(buildingData.powerConsumers) ~= "table" then
        return stats
    end

    for _, consumer in pairs(buildingData.powerConsumers) do
        stats.consumerCount = stats.consumerCount + 1

        local objectType = consumer and consumer.objectType or nil
        local isActive = consumer and consumer.isActive == true or false

        if objectType == "light" or objectType == "lamp" then
            stats.lightCount = stats.lightCount + 1
            if isActive then
                stats.activeLightCount = stats.activeLightCount + 1
            end
        elseif objectType == "appliance" then
            stats.applianceCount = stats.applianceCount + 1
            if isActive then
                stats.activeApplianceCount = stats.activeApplianceCount + 1
            end
        end
    end

    if stats.activeConsumerCount <= 0 then
        stats.activeConsumerCount = stats.activeLightCount + stats.activeApplianceCount
    end

    return stats
end

local function IsGeneratorDataRunning(generatorData)
    return generatorData
        and (tonumber(generatorData.fuelAmount) or 0) > 0
        and generatorData.activated ~= false
end

local function BuildSyntheticGeneratorModData(generatorData, buildingData, target)
    local md = target or {}
    local stats = CountBuildingConsumers(buildingData)
    local cachedPoolRate = tonumber(generatorData and generatorData.cachedRealPoolTotalLps) or 0

    md.Gen_BuildingPoolID = buildingData and buildingData.id or md.Gen_BuildingPoolID
    md.Gen_Stats_Consumers = stats.consumerCount
    md.Gen_Stats_ActiveConsumers = stats.activeConsumerCount
    md.Gen_Stats_Lights = stats.lightCount
    md.Gen_Stats_ActiveLights = stats.activeLightCount
    md.Gen_Stats_Lamps = nil
    md.Gen_Stats_ActiveLamps = nil
    md.Gen_Stats_Appliances = stats.applianceCount
    md.Gen_Stats_ActiveAppliances = stats.activeApplianceCount
    md.Gen_Stats_PowerDraw = tonumber(buildingData and buildingData.totalPowerDraw) or 0
    md.Gen_Stats_Strain = tonumber(generatorData and generatorData.strain) or 0
    md.Gen_Stats_FuelRateLph = cachedPoolRate > 0 and cachedPoolRate * 3600 or 0
    md.Gen_Stats_Powered = buildingData and buildingData.isPowered or IsGeneratorDataRunning(generatorData)
    md.HeatingEnabled = buildingData and buildingData.heatingEnabled == true or false
    md.HeatingTargetTemp = buildingData and (tonumber(buildingData.heatingTargetTemp) or 22) or 22

    return md
end

local function GetGeneratorCoords(generator)
    if not generator or not generator.getX or not generator.getY or not generator.getZ then
        return nil, nil, nil
    end

    local ok, x, y, z = pcall(function()
        return generator:getX(), generator:getY(), generator:getZ()
    end)
    if not ok then
        return nil, nil, nil
    end

    return x, y, z
end

local function GetLiveGeneratorObject(generator)
    if not generator then return nil end
    if generator.getLiveObject then
        return generator:getLiveObject()
    end

    local ok, sq = pcall(function() return generator:getSquare() end)
    if ok and sq ~= nil then
        return generator
    end

    return nil
end

local function GetGeneratorStateData(x, y, z)
    local SM = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local GeneratorData = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
    if not (SM and SM.GetGenerator and GeneratorData and GeneratorData.MakeId) then
        return nil
    end

    local generatorId = GeneratorData.MakeId(x, y, z)
    return generatorId and SM.GetGenerator(generatorId) or nil
end

local function CreateGeneratorProxy(generatorData, buildingData)
    if not generatorData then return nil end

    local proxy = {
        _generatorData = generatorData,
        _buildingData = buildingData,
        _syntheticModData = {},
    }

    function proxy:getLiveObject()
        local gd = self._generatorData
        if not gd then return nil end
        return FindLoadedGeneratorAt(gd.x, gd.y, gd.z)
    end

    function proxy:getX() return self._generatorData.x or 0 end

    function proxy:getY() return self._generatorData.y or 0 end

    function proxy:getZ() return self._generatorData.z or 0 end

    function proxy:getFuel()
        local live = self:getLiveObject()
        if live and live.getFuel then return live:getFuel() or 0 end
        return tonumber(self._generatorData.fuelAmount) or 0
    end

    function proxy:getMaxFuel()
        local live = self:getLiveObject()
        if live and live.getMaxFuel then return live:getMaxFuel() or 100 end
        return 100
    end

    function proxy:getCondition()
        local live = self:getLiveObject()
        if live and live.getCondition then return live:getCondition() or 0 end
        return tonumber(self._generatorData.condition) or 0
    end

    function proxy:isActivated()
        local live = self:getLiveObject()
        if live and live.isActivated then return live:isActivated() or false end
        return IsGeneratorDataRunning(self._generatorData)
    end

    function proxy:getModData()
        local live = self:getLiveObject()
        if live and live.getModData then return live:getModData() end
        return BuildSyntheticGeneratorModData(self._generatorData, self._buildingData, self._syntheticModData)
    end

    function proxy:getSquare()
        local live = self:getLiveObject()
        if live and live.getSquare then return live:getSquare() end
        return nil
    end

    function proxy:getSpriteName()
        local live = self:getLiveObject()
        if live and live.getSpriteName then return live:getSpriteName() end
        return self._generatorData.cachedSprite
    end

    function proxy:getSprite()
        local live = self:getLiveObject()
        if live and live.getSprite then return live:getSprite() end
        return nil
    end

    return proxy
end

local function CreateBuildingAnchorProxy(buildingData, anchorSquare)
    if not buildingData then return nil end

    local proxy = {
        _pbBuildingAnchorProxy = true,
        _buildingData = buildingData,
        _anchorSquare = anchorSquare,
        _syntheticModData = {},
    }

    function proxy:getLiveObject() return nil end

    function proxy:getX() return self._anchorSquare and self._anchorSquare:getX() or self._buildingData.x or 0 end

    function proxy:getY() return self._anchorSquare and self._anchorSquare:getY() or self._buildingData.y or 0 end

    function proxy:getZ() return self._anchorSquare and self._anchorSquare:getZ() or self._buildingData.z or 0 end

    function proxy:getFuel() return 0 end

    function proxy:getMaxFuel() return 100 end

    function proxy:getCondition() return 0 end

    function proxy:isActivated() return false end

    function proxy:getModData() return BuildSyntheticGeneratorModData(nil, self._buildingData, self._syntheticModData) end

    function proxy:getSquare() return nil end

    function proxy:getSpriteName() return nil end

    function proxy:getSprite() return nil end

    return proxy
end

local function GetGeneratorReferenceAt(x, y, z, buildingData)
    local live = FindLoadedGeneratorAt(x, y, z)
    if live then return live end
    return CreateGeneratorProxy(GetGeneratorStateData(x, y, z), buildingData)
end

local function GetGeneratorReferenceKey(generator)
    local x, y, z = GetGeneratorCoords(generator)
    if x == nil then return nil end
    return tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(z)
end

local function GeneratorDataMatchesBuilding(generatorData, buildingData, anchorSquare, stateManager)
    if not generatorData or not buildingData then return false end

    local targetX, targetY = buildingData.x, buildingData.y
    local squareX = anchorSquare and anchorSquare:getX() or nil
    local squareY = anchorSquare and anchorSquare:getY() or nil

    for _, connectedId in pairs(generatorData.connectedBuildings or {}) do
        if connectedId == buildingData.id then return true end

        local refBld = stateManager and stateManager.GetBuilding and stateManager.GetBuilding(connectedId) or nil
        if refBld then
            if targetX and targetY and refBld.x == targetX and refBld.y == targetY then return true end
            if refBld.x and refBld.y and IsInsideBuildingBounds(buildingData, refBld.x, refBld.y) then return true end
            if targetX and targetY and IsInsideBuildingBounds(refBld, targetX, targetY) then return true end
            if squareX and squareY and IsInsideBuildingBounds(buildingData, squareX, squareY)
                and IsInsideBuildingBounds(refBld, squareX, squareY) then
                return true
            end
        else
            local cx, cy = string.match(connectedId, "^bld_(%-?%d+)_(%-?%d+)_")
            cx = tonumber(cx)
            cy = tonumber(cy)
            if cx and cy then
                if targetX and targetY and cx == targetX and cy == targetY then return true end
                if IsInsideBuildingBounds(buildingData, cx, cy) then return true end
            end
        end
    end

    return false
end

local function CollectGeneratorReferencesForBuilding(buildingData, anchorSquare)
    if not buildingData then return {} end

    local refs = {}
    local seen = {}
    local SM = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager

    local function addReference(generator, orderIdx)
        local key = GetGeneratorReferenceKey(generator)
        if not key or seen[key] then return end
        seen[key] = true
        table.insert(refs, { generator = generator, orderIdx = orderIdx or math.huge })
    end

    if buildingData.connectedGenerators then
        for idx, genKey in pairs(buildingData.connectedGenerators) do
            local px, py, pz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if px then
                addReference(GetGeneratorReferenceAt(tonumber(px), tonumber(py), tonumber(pz), buildingData),
                    tonumber(idx) or math.huge)
            end
        end
    end

    if SM and SM.GetAllGenerators then
        for _, gd in pairs(SM.GetAllGenerators() or {}) do
            if GeneratorDataMatchesBuilding(gd, buildingData, anchorSquare, SM) then
                addReference(GetGeneratorReferenceAt(gd.x, gd.y, gd.z, buildingData), math.huge)
            end
        end
    end

    table.sort(refs, function(a, b)
        local aActive = a.generator:isActivated() or false
        local bActive = b.generator:isActivated() or false
        if aActive ~= bActive then return aActive end
        if a.orderIdx ~= b.orderIdx then return a.orderIdx < b.orderIdx end

        local ax, ay, az = GetGeneratorCoords(a.generator)
        local bx, by, bz = GetGeneratorCoords(b.generator)
        if ax ~= bx then return ax < bx end
        if ay ~= by then return ay < by end
        return (az or 0) < (bz or 0)
    end)

    local out = {}
    for _, entry in ipairs(refs) do table.insert(out, entry.generator) end
    return out
end

local function ResolveBuildingDataFromAnchor(anchorSquare, buildingHint)
    local SM = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not SM then return nil end

    if type(buildingHint) == "table" and buildingHint.id then return buildingHint end

    if type(buildingHint) == "string" and SM.GetBuilding then
        local hintedBuilding = SM.GetBuilding(buildingHint)
        if hintedBuilding then return hintedBuilding end
    end

    if not anchorSquare then return nil end

    local ax, ay, az = anchorSquare:getX(), anchorSquare:getY(), anchorSquare:getZ()
    local bldId = LKS_EletricidadeConstrucao.Data.Building.MakeId(ax, ay, az)
    local bldData = SM.GetBuilding and SM.GetBuilding(bldId) or nil
    if bldData then return bldData end

    local cell = getCell()
    local clickedIsoBuilding = anchorSquare:getBuilding()
    if clickedIsoBuilding and cell and SM.GetAllBuildings then
        for _, bd in pairs(SM.GetAllBuildings() or {}) do
            if bd.x and bd.y and bd.z then
                local bdSq = cell:getGridSquare(bd.x, bd.y, bd.z)
                if bdSq and bdSq:getBuilding() == clickedIsoBuilding then return bd end
            end
        end
    end

    local bestBuilding = nil
    local bestScore = nil
    if SM.GetAllBuildings then
        for _, bd in pairs(SM.GetAllBuildings() or {}) do
            local score = 0
            if bd.x == ax and bd.y == ay then score = score + 200 end
            if IsInsideBuildingBounds(bd, ax, ay) then score = score + 100 end
            if score > 0 and (not bestScore or score > bestScore) then
                bestScore = score
                bestBuilding = bd
            end
        end
    end

    return bestBuilding
end

local function ResolveBuildingPool(generator)
    if not generator then return nil, nil end

    local md = generator:getModData()
    local currentPoolId = md and md.Gen_BuildingPoolID or nil
    local SM = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not SM or not SM.GetAllBuildings then return currentPoolId, nil end

    local buildings = SM.GetAllBuildings()
    if not buildings then return currentPoolId, nil end

    local sq = generator:getSquare()
    local gx = sq and sq:getX() or generator:getX()
    local gy = sq and sq:getY() or generator:getY()
    local gz = sq and sq:getZ() or generator:getZ()
    local genKey = tostring(gx) .. "_" .. tostring(gy) .. "_" .. tostring(gz)

    local bestId, bestData, bestScore = nil, nil, nil
    for buildingId, buildingData in pairs(buildings) do
        local hasGenerator = TableContainsValue(buildingData.connectedGenerators, genKey)
        local generatorInside = gx ~= nil and gy ~= nil and IsInsideBuildingBounds(buildingData, gx, gy)
        local matchesCurrent = currentPoolId ~= nil and buildingId == currentPoolId

        if hasGenerator or generatorInside or matchesCurrent then
            local score = 0
            if hasGenerator then score = score + 700 end
            if generatorInside then score = score + 100 end
            if matchesCurrent then score = score + 25 end
            score = score + math.min(TableCountEntries(buildingData.connectedGenerators) * 20, 80)
            score = score + math.min(tonumber(buildingData.activeConsumerCount) or 0, 60)
            score = score + math.min(math.floor(tonumber(buildingData.totalPowerDraw) or 0), 60)

            if not bestScore or score > bestScore or (score == bestScore and tostring(buildingId) < tostring(bestId)) then
                bestId, bestData, bestScore = buildingId, buildingData, score
            end
        end
    end

    if bestId then return bestId, bestData end
    return currentPoolId, currentPoolId and SM.GetBuilding and SM.GetBuilding(currentPoolId) or nil
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:scanAllGenerators()
    if not self.generator then return {} end
    local poolID, poolData = ResolveBuildingPool(self.generator)
    local anchorSquare = nil
    if self.anchorX ~= nil and self.anchorY ~= nil and self.anchorZ ~= nil then
        local cell = getCell()
        anchorSquare = cell and cell:getGridSquare(self.anchorX, self.anchorY, self.anchorZ) or nil
    end
    local knownBuilding = poolData or self.buildingData
    if knownBuilding then
        local refs = CollectGeneratorReferencesForBuilding(knownBuilding, anchorSquare)
        if #refs > 0 then return refs end
    end
    if not poolID then return { self.generator } end

    local found = {}
    local seen  = {}

    if poolData and poolData.connectedGenerators then
        for _, genKey in pairs(poolData.connectedGenerators) do
            local px, py, pz = string.match(genKey, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if px then
                local obj = FindLoadedGeneratorAt(tonumber(px), tonumber(py), tonumber(pz))
                if obj then
                    local key = obj:getX() .. "," .. obj:getY() .. "," .. obj:getZ()
                    if not seen[key] then
                        seen[key] = true
                        table.insert(found, obj)
                    end
                end
            end
        end
    end

    if #found > 0 then return found end

    local sq = self.generator:getSquare()
    if not sq then return { self.generator } end
    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()
    local cell = getCell()

    local zMin = math.max(0, cz - 3)
    local zMax = math.min(15, cz + 10)

    for dz = zMin, zMax do
        for dx = -60, 60 do
            for dy = -60, 60 do
                local s = cell:getGridSquare(cx + dx, cy + dy, dz)
                if s then
                    local objs = s:getObjects()
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if instanceof(obj, "IsoGenerator") then
                            local m = obj:getModData()
                            if m and m.Gen_BuildingPoolID == poolID then
                                local key = obj:getX() .. "," .. obj:getY() .. "," .. obj:getZ()
                                if not seen[key] then
                                    seen[key] = true
                                    table.insert(found, obj)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return #found > 0 and found or { self.generator }
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:sortGeneratorsByConnectionOrder(genList)
    local order = {}
    local SM = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if SM and SM.GetAllBuildings then
        local buildings = SM.GetAllBuildings()
        if buildings then
            local poolID = ResolveBuildingPool(self.generator)
            for bid, bdata in pairs(buildings) do
                if bid == poolID and bdata.connectedGenerators then
                    for idx, gk in pairs(bdata.connectedGenerators) do order[gk] = tonumber(idx) or idx end
                    break
                end
            end
        end
    end

    table.sort(genList, function(a, b)
        local aActive = a:isActivated() or false
        local bActive = b:isActivated() or false
        if aActive ~= bActive then return aActive end

        local ka = a:getX() .. "_" .. a:getY() .. "_" .. a:getZ()
        local kb = b:getX() .. "_" .. b:getY() .. "_" .. b:getZ()
        local ia = order[ka]
        local ib = order[kb]
        if ia and ib then return ia < ib end
        if ia then return true end
        if ib then return false end
        if a:getX() ~= b:getX() then return a:getX() < b:getX() end
        return a:getY() < b:getY()
    end)
end

-- ============================================================
-- ATUALIZAÇÃO
-- ============================================================

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:titleBarHeight()
    return 26
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:prerender()
    local titleText = self.title
    self.title = ""
    ISCollapsableWindow.prerender(self)
    self.title = titleText

    local th = self:titleBarHeight()
    local fontH = getTextManager():getFontHeight(FONT_M)
    local titleY = math.floor((th - fontH) / 2) - 1
    local titleWidth = getTextManager():MeasureStringX(FONT_M, titleText)
    local titleX = math.floor((self.width - titleWidth) / 2)
    self:drawText(titleText, titleX, titleY, 1, 1, 1, 1, FONT_M)

    local genValid = false
    if self.generator then
        local liveGenerator = GetLiveGeneratorObject(self.generator)
        if liveGenerator then
            self.generator = liveGenerator
            genValid = true
        else
            local gx, gy, gz = GetGeneratorCoords(self.generator)
            if gx ~= nil then
                self.generator = GetGeneratorReferenceAt(gx, gy, gz, self.buildingData) or self.generator
                genValid = select(1, GetGeneratorCoords(self.generator)) ~= nil
            end
        end
    end
    if not genValid then
        self:close()
        return
    end
    if self.anchorX and self.anchorY and self.anchorZ then
        local playerObj = getSpecificPlayer(self.playerNum or 0)
        local psq = playerObj and playerObj:getSquare()
        if not psq then
            self:close()
            return
        end
        local dx = psq:getX() - self.anchorX
        local dy = psq:getY() - self.anchorY
        local dz = psq:getZ() - self.anchorZ
        if dz ~= 0 or (dx * dx + dy * dy) >= 100 then
            self:close()
            return
        end
    end
    local now = getTimestampMs()
    if now - self.lastUpdate >= 1000 then
        self.lastUpdate = now
        self:updateData()
    end
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:updateData()
    if not self.generator then return end
    local md                                       = self.generator:getModData()
    local d                                        = self.cachedData
    local resolvedBuildingID, resolvedBuildingData = ResolveBuildingPool(self.generator)
    if resolvedBuildingData then self.buildingData = resolvedBuildingData end

    d.fuel       = self.generator:getFuel() or 0
    d.maxFuel    = self.generator:getMaxFuel() or 10
    d.condition  = self.generator:getCondition() or 0
    d.buildingID = resolvedBuildingID or (self.buildingData and self.buildingData.id) or md.Gen_BuildingPoolID
    if d.buildingID then
        self._hadBuildingLink = true
    elseif self._hadBuildingLink then
        self:close()
        return
    end
    if resolvedBuildingID and md.Gen_BuildingPoolID ~= resolvedBuildingID then md.Gen_BuildingPoolID = resolvedBuildingID end

    self.allGenerators = self:scanAllGenerators()
    self:sortGeneratorsByConnectionOrder(self.allGenerators)
    local statsMd = md
    local bestStatsScore = -1
    for _, g in ipairs(self.allGenerators) do
        local gmd = g and g.getModData and g:getModData() or nil
        if gmd then
            local score = 0
            if d.buildingID and gmd.Gen_BuildingPoolID == d.buildingID then score = score + 50 end
            if type(gmd.Gen_Stats_BarrelData) == "table" then score = score + 40 end
            local barrelCount = tonumber(gmd.Gen_Stats_BarrelCount)
            if barrelCount and barrelCount > 0 then score = score + 30 end
            if gmd.Gen_Stats_Consumers ~= nil then score = score + 10 end
            if g:isActivated() then score = score + 5 end
            if score > bestStatsScore then
                bestStatsScore = score
                statsMd = gmd
            end
        end
    end
    local totalFuel = 0
    local totalMax  = 0
    local anyActive = false
    for _, g in ipairs(self.allGenerators) do
        if g:isActivated() then
            totalFuel = totalFuel + (g:getFuel() or 0)
            totalMax  = totalMax + (g:getMaxFuel() or 0)
            anyActive = true
        end
    end
    d.totalFuel         = totalFuel
    d.totalMaxFuel      = totalMax
    d.isActivated       = anyActive
    local buildingStats = CountBuildingConsumers(self.buildingData)

    if d.buildingID then
        d.consumerCount        = statsMd.Gen_Stats_Consumers or buildingStats.consumerCount or 0
        d.lightCount           = statsMd.Gen_Stats_Lights or buildingStats.lightCount or 0
        d.activeLightCount     = statsMd.Gen_Stats_ActiveLights or buildingStats.activeLightCount or 0
        d.lampCount            = statsMd.Gen_Stats_Lamps or 0
        d.activeLampCount      = statsMd.Gen_Stats_ActiveLamps or 0
        d.applianceCount       = statsMd.Gen_Stats_Appliances or buildingStats.applianceCount or 0
        d.activeApplianceCount = statsMd.Gen_Stats_ActiveAppliances or buildingStats.activeApplianceCount or 0
        d.powerDraw            = statsMd.Gen_Stats_PowerDraw or
            tonumber(self.buildingData and self.buildingData.totalPowerDraw) or 0
        d.strain               = statsMd.Gen_Stats_Strain or 0
        d.fuelRateLph          = statsMd.Gen_Stats_FuelRateLph or 0
        d.isPowered            = anyActive or (self.buildingData and self.buildingData.isPowered == true) or false
    else
        d.consumerCount, d.lightCount, d.activeLightCount = 0, 0, 0
        d.lampCount, d.activeLampCount                    = 0, 0
        d.applianceCount, d.activeApplianceCount          = 0, 0
        d.powerDraw, d.strain, d.fuelRateLph              = 0, 0, 0
        d.isPowered                                       = anyActive
    end

    self._heatingEnabled = (md.HeatingEnabled == true)
    self._heatingTemp    = md.HeatingTargetTemp or 22
    local _hasHeatPos    = false
    if type(md.HeatingPositions) == "table" then
        for _ in pairs(md.HeatingPositions) do
            _hasHeatPos = true; break
        end
    end
    self._heatingHasData           = _hasHeatPos

    local previousBarrelData       = self._barrelData or {}
    local previousBarrelTotalFuel  = self._barrelTotalFuel or 0
    local previousBarrelBuildingID = self._barrelBuildingID

    self._barrelData               = {}
    self._barrelTotalFuel          = 0
    self._barrelBuildingID         = d.buildingID
    local Barrels_ud               = LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Barrels
    local snapshotBarrels          = statsMd.Gen_Stats_BarrelData
    local authoritativeBarrelCount = tonumber(statsMd.Gen_Stats_BarrelCount)

    local function sortBarrelData()
        table.sort(self._barrelData, function(a, b)
            local az, bz = a.z or 0, b.z or 0
            if az ~= bz then return az < bz end
            local ay, by = a.y or 0, b.y or 0
            if ay ~= by then return ay < by end
            return (a.x or 0) < (b.x or 0)
        end)
    end

    local function addBarrelData(amount, maxAmt, spriteName, bx, by, bz)
        table.insert(self._barrelData, {
            amount = amount,
            maxAmount = maxAmt,
            sprite = spriteName,
            x = bx,
            y = by,
            z = bz,
        })
        self._barrelTotalFuel = self._barrelTotalFuel + amount
    end

    if type(snapshotBarrels) == "table" then
        for _, entry in pairs(snapshotBarrels) do
            addBarrelData(tonumber(entry.amount) or 0, tonumber(entry.maxAmount) or 25, entry.sprite, tonumber(entry.x),
                tonumber(entry.y), tonumber(entry.z))
        end
        sortBarrelData()
    elseif authoritativeBarrelCount ~= nil and authoritativeBarrelCount <= 0 then
    elseif previousBarrelBuildingID == d.buildingID and #previousBarrelData > 0 then
        self._barrelData = previousBarrelData
        self._barrelTotalFuel = previousBarrelTotalFuel
    elseif Barrels_ud and d.buildingID and Barrels_ud.GetLinkedBarrels then
        local ok_b, barrels_list = pcall(Barrels_ud.GetLinkedBarrels, d.buildingID)
        if ok_b and barrels_list then
            for _, barrel in ipairs(barrels_list) do
                local amount = Barrels_ud.GetPetrolAmount(barrel) or 0
                local maxAmt = 25
                local ok2, fc = pcall(function() return barrel:getFluidContainer() end)
                if ok2 and fc then
                    local ok3, cap = pcall(function() return fc:getCapacity() end)
                    if ok3 and cap and cap > 0 then maxAmt = cap end
                end
                local spriteName = nil
                local ok4, sn = pcall(function()
                    if barrel.getSpriteName then return barrel:getSpriteName() end
                    if barrel.getSprite and barrel:getSprite() then return barrel:getSprite():getName() end
                end)
                if ok4 then spriteName = sn end
                local bsq = barrel:getSquare()
                local bsx = bsq and bsq:getX()
                local bsy = bsq and bsq:getY()
                local bsz = bsq and bsq:getZ()
                addBarrelData(amount, maxAmt, spriteName, bsx, bsy, bsz)
            end
            sortBarrelData()
        end
    end
end

-- ============================================================
-- INTERAÇÃO DO MOUSE
-- ============================================================

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:onMouseDown(x, y)
    ISCollapsableWindow.onMouseDown(self, x, y)
    local playerObj = getSpecificPlayer(self.playerNum or 0)
    if not playerObj then return end
    if self._genClickAreas then
        for _, area in ipairs(self._genClickAreas) do
            if y >= area.y1 and y <= area.y2 then
                local sq = area.gen:getSquare()
                if sq then ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, sq)) end
                return
            end
        end
    end

    if self._barrelClickAreas then
        for _, area in ipairs(self._barrelClickAreas) do
            if y >= area.y1 and y <= area.y2 then
                if area.x then
                    local barrelSq = getCell():getGridSquare(area.x, area.y_coord, area.z)
                    if barrelSq then
                        local adjSq, faceDir = FindAdjacentWalkable(barrelSq, playerObj)
                        local walkSq = adjSq or barrelSq
                        ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, walkSq))
                        if adjSq and faceDir then
                            local _dir = faceDir
                            local faceAction = ISBaseTimedAction:new(playerObj)
                            faceAction.maxTime = 1
                            function faceAction:isValid() return true end

                            function faceAction:perform()
                                self.character:faceDirection(_dir)
                                self:forceComplete()
                            end

                            ISTimedActionQueue.add(faceAction)
                        end
                    end
                end
                return
            end
        end
    end

    if self._heatOnBtnArea and y >= self._heatOnBtnArea.y1 and y <= self._heatOnBtnArea.y2 and x >= self._heatOnBtnArea.x1 and x <= self._heatOnBtnArea.x2 then
        self:onHeatingSetState(true)
        return
    end

    if self._heatOffBtnArea and y >= self._heatOffBtnArea.y1 and y <= self._heatOffBtnArea.y2 and x >= self._heatOffBtnArea.x1 and x <= self._heatOffBtnArea.x2 then
        self:onHeatingSetState(false)
        return
    end

    if self._heatMinusArea and y >= self._heatMinusArea.y1 and y <= self._heatMinusArea.y2 and x >= self._heatMinusArea.x1 and x <= self._heatMinusArea.x2 then
        self:onHeatingTempChange(-1)
        return
    end

    if self._heatPlusArea and y >= self._heatPlusArea.y1 and y <= self._heatPlusArea.y2 and x >= self._heatPlusArea.x1 and x <= self._heatPlusArea.x2 then
        self:onHeatingTempChange(1)
        return
    end
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:onMouseMove(dx, dy)
    ISCollapsableWindow.onMouseMove(self, dx, dy)
    local my = self:getMouseY()
    self._hoveredGenIdx = nil
    if self._genClickAreas then
        for i, area in ipairs(self._genClickAreas) do
            if my >= area.y1 and my <= area.y2 then
                self._hoveredGenIdx = i
                break
            end
        end
    end
    self._hoveredBarrelIdx = nil
    if self._barrelClickAreas then
        for i, area in ipairs(self._barrelClickAreas) do
            if my >= area.y1 and my <= area.y2 then
                self._hoveredBarrelIdx = i
                break
            end
        end
    end
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:onMouseMoveOutside(dx, dy)
    ISCollapsableWindow.onMouseMoveOutside(self, dx, dy)
    self._hoveredGenIdx    = nil
    self._hoveredBarrelIdx = nil
end

-- ============================================================
-- MANIPULADORES DE AQUECIMENTO (TERMOSTATO)
-- ============================================================

local function CountHeatingSources(md)
    local sourceCount = 0
    if not md or type(md.HeatingPositions) ~= "table" then return 0 end
    for _, grp in pairs(md.HeatingPositions) do
        if type(grp.positions) == "table" then
            local count = 0
            for _ in pairs(grp.positions) do count = count + 1 end
            sourceCount = sourceCount + count
        end
    end
    return sourceCount
end

local function SendHeatingConfig(window, enabled, targetTemp)
    if not window or not window.generator then return end
    local gx, gy, gz = GetGeneratorCoords(window.generator)
    if gx == nil then return end

    local md = window.generator:getModData()
    local sourceCount = CountHeatingSources(md)
    if sourceCount <= 0 and window.buildingData then sourceCount = tonumber(window.buildingData.heatingSourceCount) or 0 end
    local payload = {
        genX = gx,
        genY = gy,
        genZ = gz,
        enabled = enabled == true,
        sourceCount = sourceCount,
        targetTemp = math.max(15, math.min(30, tonumber(targetTemp) or 22)),
    }
    local buildingID = ResolveBuildingPool(window.generator)
    if buildingID then
        payload.buildingID = buildingID
    elseif window.buildingData and window.buildingData.id then
        payload.buildingID = window.buildingData.id
    elseif md and md.Gen_BuildingPoolID then
        payload.buildingID = md.Gen_BuildingPoolID
    end
    if window.anchorX ~= nil and window.anchorY ~= nil and window.anchorZ ~= nil then
        payload.anchorX = window.anchorX
        payload.anchorY = window.anchorY
        payload.anchorZ = window.anchorZ
    end

    sendClientCommand("LKS_EletricidadeConstrucao", "HeatingToggle", payload)
end

local function ApplyHeatingConfigLocal(window, enabled, targetTemp)
    if not window or not window.generator then return nil, nil end

    local generator = GetLiveGeneratorObject(window.generator) or window.generator
    local md = generator and generator.getModData and generator:getModData() or nil
    local resolvedTemp = math.max(15, math.min(30, tonumber(targetTemp) or 22))
    local sourceCount = CountHeatingSources(md)
    if sourceCount <= 0 and window.buildingData then sourceCount = tonumber(window.buildingData.heatingSourceCount) or 0 end

    local StateManager = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local GeneratorData = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Generator
    local BuildingData = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Data and LKS_EletricidadeConstrucao.Data.Building

    local buildingID = ResolveBuildingPool(window.generator)
    if not buildingID and window.buildingData then buildingID = window.buildingData.id end
    if not buildingID and md then buildingID = md.Gen_BuildingPoolID end

    local gx, gy, gz = GetGeneratorCoords(generator)
    local genData = nil
    if gx ~= nil and StateManager and StateManager.GetGenerator and GeneratorData and GeneratorData.MakeId then
        genData = StateManager.GetGenerator(GeneratorData.MakeId(gx, gy, gz))
    end

    local function updateBuildingData(buildingData)
        if not buildingData then return end
        buildingData.heatingEnabled = enabled == true
        if sourceCount > 0 then
            buildingData.heatingSourceCount = math.max(
                tonumber(buildingData.heatingSourceCount) or 0, sourceCount)
        end
        buildingData.heatingTargetTemp = resolvedTemp
        if BuildingData and BuildingData.RecalculatePower then BuildingData.RecalculatePower(buildingData) end
    end

    local function updateGeneratorState(generatorState)
        if not generatorState then return end
        generatorState.heatingEnabled = enabled == true
        generatorState.heatingSourceCount = sourceCount
        generatorState.heatingTargetTemp = resolvedTemp
    end

    if genData then
        updateGeneratorState(genData)
        if genData.connectedBuildings and StateManager and StateManager.GetBuilding then
            for _, connectedBuildingId in pairs(genData.connectedBuildings) do
                local buildingData = StateManager.GetBuilding(connectedBuildingId)
                if buildingData then
                    updateBuildingData(buildingData)
                    if not buildingID then buildingID = connectedBuildingId end
                end
            end
        end
    end

    if buildingID and StateManager and StateManager.GetBuilding then
        updateBuildingData(StateManager.GetBuilding(
            buildingID))
    end
    updateBuildingData(window.buildingData)

    if md then
        md.HeatingEnabled = enabled == true
        md.HeatingTargetTemp = resolvedTemp
        local runtime = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
        if generator.transmitModData and runtime and runtime.RequiresNetworkSync and runtime.RequiresNetworkSync() then
            generator:transmitModData()
        end
    end

    if StateManager and StateManager.MarkDirty then StateManager.MarkDirty() end
    return generator, md
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:onHeatingSetState(enable)
    if not self.generator then return end
    local Runtime = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local isMPClient = Runtime and Runtime.IsMultiplayerClient and Runtime.IsMultiplayerClient()
    local liveGenerator = GetLiveGeneratorObject(self.generator)
    local md = self.generator:getModData()
    if (md.HeatingEnabled == true) == enable then return end
    self._heatingEnabled = enable

    SendHeatingConfig(self, enable, tonumber(md.HeatingTargetTemp) or 22)

    if isMPClient then
        self.lastUpdate = 0
        self:requestFreshStats()
        return
    end

    liveGenerator, md = ApplyHeatingConfigLocal(self, enable, tonumber(md.HeatingTargetTemp) or 22)
    local liveHeatingGenerator = GetLiveGeneratorObject(liveGenerator)

    if LKS_EletricidadeConstrucao_HeatingClient then
        local sq = liveHeatingGenerator and liveHeatingGenerator:getSquare() or nil
        if sq then
            local key = sq:getX() .. "_" .. sq:getY() .. "_" .. sq:getZ()
            if enable and liveHeatingGenerator and liveHeatingGenerator:isActivated() then
                LKS_EletricidadeConstrucao_HeatingClient.Apply(liveHeatingGenerator)
            else
                LKS_EletricidadeConstrucao_HeatingClient.Remove(key)
            end
        end
    end
    self:requestFreshStats()
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:onHeatingToggle()
    self:onHeatingSetState(not (self._heatingEnabled == true))
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:onHeatingTempChange(delta)
    if not self.generator then return end
    local Runtime       = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local isMPClient    = Runtime and Runtime.IsMultiplayerClient and Runtime.IsMultiplayerClient()
    local liveGenerator = GetLiveGeneratorObject(self.generator)
    local md            = self.generator:getModData()
    local currentTemp   = self._heatingTemp or md.HeatingTargetTemp or 22
    local temp          = math.max(15, math.min(30, currentTemp + delta))
    self._heatingTemp   = temp

    SendHeatingConfig(self, (self._heatingEnabled == true) or (md.HeatingEnabled == true), temp)

    if isMPClient then
        self.lastUpdate = 0
        self:requestFreshStats()
        return
    end

    liveGenerator, md = ApplyHeatingConfigLocal(self, (self._heatingEnabled == true) or (md.HeatingEnabled == true), temp)
    local liveHeatingGenerator = GetLiveGeneratorObject(liveGenerator)

    if LKS_EletricidadeConstrucao_HeatingClient and md and md.HeatingEnabled == true then
        local sq = liveHeatingGenerator and liveHeatingGenerator:getSquare() or nil
        if sq then
            local key = sq:getX() .. "_" .. sq:getY() .. "_" .. sq:getZ()
            LKS_EletricidadeConstrucao_HeatingClient.Remove(key)
            if liveHeatingGenerator and liveHeatingGenerator:isActivated() then
                LKS_EletricidadeConstrucao_HeatingClient.Apply(
                    liveHeatingGenerator)
            end
        end
    end
    self:requestFreshStats()
end

-- ============================================================
-- AUXILIAR DE ATUALIZAÇÃO DE ESTATÍSTICAS
-- ============================================================

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:requestFreshStats()
    if not self.generator then return end
    local md = self.generator:getModData()
    local buildingID = ResolveBuildingPool(self.generator)
    if not buildingID then buildingID = self.buildingData and self.buildingData.id or nil end
    if not buildingID then buildingID = md and md.Gen_BuildingPoolID end

    local SM_ui = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    local idIsStale = buildingID and SM_ui and SM_ui.GetBuilding and not SM_ui.GetBuilding(buildingID)
    if (not buildingID or idIsStale) and SM_ui and SM_ui.GetAllBuildings then
        local genKey = self.generator:getX() .. "_" .. self.generator:getY() .. "_" .. self.generator:getZ()
        local buildings = SM_ui.GetAllBuildings()
        local resolved = nil
        if buildings then
            for bid, bdata in pairs(buildings) do
                if bdata.connectedGenerators then
                    for _, gk in pairs(bdata.connectedGenerators) do
                        if gk == genKey then
                            resolved = bid; break
                        end
                    end
                end
                if resolved then break end
            end
        end
        if resolved then
            buildingID = resolved
            if md then md.Gen_BuildingPoolID = resolved end
        end
    end

    if not buildingID then return end

    if isClient() then
        sendClientCommand("LKS_EletricidadeConstrucao", "ForceDist", { buildingID = buildingID })
    else
        local Dist = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
        if Dist then
            if Dist.RefreshBuildingStats then
                Dist.RefreshBuildingStats(buildingID)
            elseif Dist.ForceUpdateBuilding then
                Dist.ForceUpdateBuilding(buildingID)
            elseif Dist.ForceUpdate then
                Dist.ForceUpdate()
            end
        else
            LKS_EletricidadeConstrucao.Core.Logger.Warn("requestFreshStats: Distributor indisponivel", "UI")
        end

        local FuelMgr = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager
        if FuelMgr and FuelMgr.ForceUpdateGenerator and not self.generator._pbBuildingAnchorProxy then
            FuelMgr.ForceUpdateGenerator(self.generator:getX(), self.generator:getY(), self.generator:getZ())
        end
    end
    self.lastUpdate = 0
end

-- ============================================================
-- MANIPULADORES DE BOTÃO
-- ============================================================

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:findBuildingDef()
    local gen = self.generator
    if not gen then return nil end
    local sq = gen:getSquare()
    if not sq then return nil end
    local gx, gy, gz = sq:getX(), sq:getY(), sq:getZ()

    for r = 0, 5 do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r or r == 0 then
                    local s = getCell():getGridSquare(gx + dx, gy + dy, gz)
                    if s then
                        local b = s:getBuilding()
                        if b then
                            local def = b:getDef() and b:getDef() or b
                            if def then return def end
                        end
                    end
                end
            end
        end
    end
    return nil
end

--- Destaca ou remove o destaque de todos os tiles de piso/parede da construção do gerador.
function LKS_EletricidadeConstrucao_GeneratorInfoWindow:applyHighlights(enabled)
    self.highlightedFloors = self.highlightedFloors or {}

    if not enabled then
        for _, obj in ipairs(self.highlightedFloors) do pcall(function() obj:setHighlighted(false) end) end
        self.highlightedFloors = {}
        _activeHighlights = nil
        return
    end

    local buildingDef = self:findBuildingDef()
    if not buildingDef then
        print("[InfoWindow] Nenhuma construção encontrada perto do gerador para exibir alcance")
        return
    end

    local gen   = self.generator
    local gz    = self.anchorZ or gen:getZ()
    local rooms = buildingDef:getRooms()
    local seen  = {}
    local count = 0

    local function tryHighlightSquare(x, y)
        local key = x .. "," .. y
        if seen[key] then return end
        seen[key] = true
        local s = getCell():getGridSquare(x, y, gz)
        if not s then return end

        local fl = s:getFloor()
        if fl then
            pcall(function()
                if fl.setHighlightColor then fl:setHighlightColor(0.10, 0.80, 1.00, 0.75) end
                fl:setHighlighted(true)
                table.insert(self.highlightedFloors, fl)
                count = count + 1
            end)
        end

        local objs = s:getObjects()
        if objs then
            for i = 0, objs:size() - 1 do
                local obj = objs:get(i)
                if obj and obj ~= fl and instanceof(obj, "IsoThumpable") and not instanceof(obj, "IsoMovingObject") then
                    pcall(function()
                        if obj.setHighlightColor then obj:setHighlightColor(0.10, 0.80, 1.00, 0.75) end
                        obj:setHighlighted(true)
                        table.insert(self.highlightedFloors, obj)
                        count = count + 1
                    end)
                end
            end
        end
    end

    for i = 0, rooms:size() - 1 do
        local room = rooms:get(i)
        local x1, x2 = room:getX(), room:getX2()
        local y1, y2 = room:getY(), room:getY2()
        for x = x1 - 1, x2 + 1 do
            for y = y1 - 1, y2 + 1 do tryHighlightSquare(x, y) end
        end
    end

    _activeHighlights = self.highlightedFloors
    print("[InfoWindow] Alcance: destacado " .. count .. " objetos em " .. rooms:size() .. " cômodos")
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:onToggleCoverage()
    self.showCoverage = not self.showCoverage
    if self.showCoverage then
        self.coverageBtn:setTitle(getText("IGUI_HideCoverage") or "Ocultar Alcance")
        self:applyHighlights(true)
    else
        self.coverageBtn:setTitle(getText("IGUI_ShowCoverage") or "Mostrar Alcance")
        self:applyHighlights(false)
        _activeHighlights = nil
    end
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:onClose()
    self:close()
end

-- ============================================================
-- RENDER
-- ============================================================

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:render()
    ISCollapsableWindow.render(self)
    if not self.generator then return end

    local layout = self:calculateLayout()
    local barCol = layout.barCol

    if math.abs(self.width - layout.winW) > 1 then
        self:setWidth(layout.winW)
        if self.closeBtn then self.closeBtn:setX(self.width - MARGIN - self.closeBtn.width) end
    end

    local d             = self.cachedData
    local x0            = MARGIN
    local y             = 22

    self._genIconTex    = self._genIconTex or getTexture(GEN_ICON_PATH)

    local titleText     = getText("IGUI_BuildingPowerInfo") or "Informações Elétricas da Construção"
    local titleWidth    = getTextManager():MeasureStringX(FONT_M, titleText)
    local titleX        = math.floor((self.width - titleWidth) / 2)
    y                   = y + 6

    y                   = self:drawSection(x0, y, getText("IGUI_LKS_EletricidadeConstrucao_SectionGenerator") or "GERADOR")

    -- Lista por gerador
    self._genClickAreas = {}
    for idx, gen in ipairs(self.allGenerators) do
        local gFuel    = gen:getFuel() or 0
        local gMaxFuel = gen:getMaxFuel() or 10
        local gCond    = gen:getCondition() or 0
        local gActive  = gen:isActivated() or false
        local fPct     = gMaxFuel > 0 and (gFuel / gMaxFuel * 100) or 0

        local iconTex  = self:getGeneratorIcon(gen)
        local iconSize = 16

        -- INJEÇÃO DE VARIÁVEIS (iconGenerator): Deslocamento do ícone do gerador
        local genIconX = x0 + HUD_Offsets.iconGenerator.x
        local genIconY = y + 6 - HUD_Offsets.iconGenerator.y
        local genTextY = y + 5

        if iconTex then self:drawTextureScaled(iconTex, genIconX, genIconY, iconSize, iconSize, 1, 1, 1, 1) end
        local textX = x0 + iconSize + 4

        if self._hoveredGenIdx == idx then
            self:drawRect(x0 - 2, y, self.width - MARGIN * 2 + 4, LINE_H, 0.15, 1, 1, 1)
        end

        local statusText = gActive and (getText("IGUI_LKS_EletricidadeConstrucao_On") or "LIGADO") or (getText("IGUI_LKS_EletricidadeConstrucao_Off") or "DESLIGADO")
        local statusFullText = "#" .. idx .. " " .. statusText .. " "
        self:drawText(statusFullText, textX, genTextY, gActive and 0.20 or 1.00, gActive and 0.90 or 0.1,
            gActive and 0.28 or 0.1, 1, FONT_S)

        local fr, fg2, fb
        if fPct >= 50 then
            fr, fg2, fb = 0.20, 0.85, 0.30
        elseif fPct >= 25 then
            fr, fg2, fb = 0.90, 0.78, 0.08
        else
            fr, fg2, fb = 0.90, 0.22, 0.18
        end
        local fuelText = (getText("IGUI_LKS_EletricidadeConstrucao_Fuel") or "Combustível") .. ": " .. string.format("%3.0f%%", fPct)
        local fuelWidth = getTextManager():MeasureStringX(FONT_S, fuelText)
        local rowW = self.width - MARGIN * 2
        local fuelX = x0 + math.floor((rowW - fuelWidth) / 2)
        self:drawText(fuelText, fuelX, genTextY, fr, fg2, fb, 1, FONT_S)

        local cr2, cg2, cb2
        if gCond >= 60 then
            cr2, cg2, cb2 = 0.20, 0.90, 0.28
        elseif gCond >= 30 then
            cr2, cg2, cb2 = 0.90, 0.78, 0.08
        else
            cr2, cg2, cb2 = 0.90, 0.22, 0.18
        end
        local condText = (getText("IGUI_LKS_EletricidadeConstrucao_Condition") or "Condição") .. ": " .. string.format("%3.0f%%", gCond)
        local condWidth = getTextManager():MeasureStringX(FONT_S, condText)
        local condX = x0 + rowW - condWidth
        self:drawText(condText, condX, genTextY, cr2, cg2, cb2, 1, FONT_S)

        table.insert(self._genClickAreas, { y1 = y, y2 = y + LINE_H, gen = gen })
        y = y + LINE_H
    end
    y                 = y + 4

    local poolFuel    = d.totalFuel or 0
    local poolMaxFuel = d.totalMaxFuel or 0
    if poolMaxFuel > 0 then
        local fuelBarOpts = { width = math.floor(BAR_W * 0.8), color = { 0.95, 0.92, 0.60 }, greenHigh = true, showPct = false }

        local iconSize = 16
        local iconTex = getTexture("Item_Petrol")
        if not iconTex then iconTex = getTexture("Item_PetrolCan") end
        if iconTex then
            -- INJEÇÃO DE VARIÁVEIS (iconGallon, barGas, valueAmountGas)
            local poolIconX = x0 + HUD_Offsets.iconGallon.x
            local poolIconY = y + 6 - HUD_Offsets.iconGallon.y

            local barX = x0 + iconSize + 4 + HUD_Offsets.barGas.x
            local barH = 12
            local barY = y + 8 - HUD_Offsets.barGas.y

            local textX = barX + fuelBarOpts.width + 4 + HUD_Offsets.valueAmountGas.x
            local textY = y + 5 - HUD_Offsets.valueAmountGas.y

            self:drawTextureScaled(iconTex, poolIconX, poolIconY, iconSize, iconSize, 1, 1, 1, 1)

            local poolBarW = fuelBarOpts.width
            local pct = poolMaxFuel > 0 and math.max(0, math.min(1, poolFuel / poolMaxFuel)) or 0

            self:drawRect(barX, barY, poolBarW, barH, 0.9, 0.10, 0.10, 0.10)
            local r, g, b = fuelBarOpts.color[1], fuelBarOpts.color[2], fuelBarOpts.color[3]
            self:drawRect(barX, barY, math.max(2, math.floor(poolBarW * pct)), barH, 0.9, r, g, b)
            self:drawRectBorder(barX, barY, poolBarW, barH, 0.65, 0.40, 0.40, 0.40)

            local numStr = string.format("%.1f / %.1f", poolFuel, poolMaxFuel)
            self:drawText(numStr, textX, textY, 0.80, 0.80, 0.55, 1, FONT_S)
            y = y + LINE_H
        end
        y = y + 6
    end

    do
        local barrelList = self._barrelData or {}
        local totalFuel  = self._barrelTotalFuel or 0
        local totalStr   = #barrelList > 0 and string.format("%.1f L", totalFuel) or ""
        local secTitle   = getText("IGUI_LKS_EletricidadeConstrucao_SectionBarrels") or "BARRIS"
        self:drawRect(x0, y, self.width - MARGIN * 2, 1, 0.55, 0.30, 0.30, 0.30)
        y = y + 5
        self:drawText(secTitle, x0, y, 0.50, 0.78, 1.0, 1, FONT_M)
        if totalStr ~= "" then
            local tw = getTextManager():MeasureStringX(FONT_S, totalStr)
            self:drawText(totalStr, x0 + (self.width - MARGIN * 2) - tw, y + 3, 0.97, 0.93, 0.55, 1, FONT_S)
        end
        y = y + 22

        if #barrelList == 0 then
            self:drawText(getText("IGUI_LKS_EletricidadeConstrucao_NoBarrels") or "Nenhum barril conectado", x0, y + 5, 0.50, 0.50, 0.50, 1,
                FONT_S)
            y = y + LINE_H
        else
            local iconSize = LINE_H - 2
            local lblSample = "999.9 L"
            local lblW = getTextManager():MeasureStringX(FONT_S, lblSample)
            local rightEdge = x0 + (self.width - MARGIN * 2)
            self._barrelClickAreas = {}
            for bidx, bdata in ipairs(barrelList) do
                if self._hoveredBarrelIdx == bidx then
                    self:drawRect(x0 - 2, y, self.width - MARGIN * 2 + 4, LINE_H, 0.15, 1, 1, 1)
                end
                self._barrelIconCache = self._barrelIconCache or {}
                local spriteKey = bdata.sprite or "__default"
                local iconTex
                if self._barrelIconCache[spriteKey] ~= nil then
                    iconTex = self._barrelIconCache[spriteKey]
                else
                    if bdata.sprite then
                        iconTex = getTexture("media/textures/" .. bdata.sprite .. ".png")
                        if not iconTex then iconTex = getTexture(bdata.sprite) end
                    end
                    if not iconTex then iconTex = getTexture("Item_Petrol") end
                    if not iconTex then iconTex = getTexture("Item_Petrol") end
                    self._barrelIconCache[spriteKey] = iconTex or false
                end
                if iconTex then self:drawTextureScaled(iconTex, x0 + 8, y + 5, iconSize, iconSize, 1, 1, 1, 1) end
                local bx2    = x0 + 8 + iconSize + 4
                local bBarW2 = rightEdge - lblW - 6 - bx2
                self:drawBarrelFuelBar(bx2, y, bdata.amount, bdata.maxAmount, bBarW2)
                local lStr = string.format("%.1f L", bdata.amount)
                local lw   = getTextManager():MeasureStringX(FONT_S, lStr)
                self:drawText(lStr, rightEdge - lw, y + 5, 0.97, 0.93, 0.55, 1, FONT_S)
                table.insert(self._barrelClickAreas,
                    { y1 = y, y2 = y + LINE_H, x = bdata.x, y_coord = bdata.y, z = bdata.z })
                y = y + LINE_H
            end
        end
        y = y + 4
    end

    y = self:drawSection(x0, y, getText("IGUI_LKS_EletricidadeConstrucao_SectionBuilding") or "CONSTRUÇÃO")

    if d.buildingID then
        if d.isPowered then
            self:drawText("[+] " .. (getText("IGUI_LKS_EletricidadeConstrucao_Powered") or "Energizado"), x0, y + 5, 0.20, 0.90, 0.28, 1, FONT_S)
        else
            self:drawText("[-] " .. (getText("IGUI_LKS_EletricidadeConstrucao_Unpowered") or "Sem Energia"), x0, y + 5, 0.85, 0.48, 0.15, 1,
                FONT_S)
        end
        y = y + LINE_H + 2

        local drawLabel = getText("IGUI_LKS_EletricidadeConstrucao_Consumers") or "Total"
        drawLabel = string.gsub(drawLabel, ":%s*$", "")
        self:drawText(drawLabel .. ":", x0, y + 5, 1, 1, 1, 0.80, FONT_S)
        self:drawText(tostring(d.consumerCount), x0 + barCol, y + 5, 0.80, 0.90, 1.0, 1, FONT_S)
        y = y + LINE_H

        drawLabel = getText("IGUI_Lights") or "Luzes"
        drawLabel = string.gsub(drawLabel, ":%s*$", "")
        self:drawText(drawLabel .. ":", x0 + 8, y + 5, 1, 1, 1, 0.60, FONT_S)
        self:drawText(d.activeLightCount .. " / " .. d.lightCount, x0 + barCol, y + 5, 0.80, 0.90, 1.0, 1, FONT_S)
        y = y + LINE_H

        drawLabel = getText("IGUI_LKS_EletricidadeConstrucao_Appliances") or "Eletrodomésticos"
        drawLabel = string.gsub(drawLabel, ":%s*$", "")
        self:drawText(drawLabel .. ":", x0 + 8, y + 5, 1, 1, 1, 0.60, FONT_S)
        self:drawText(d.activeApplianceCount .. " / " .. d.applianceCount, x0 + barCol, y + 5, 0.80, 0.90, 1.0, 1, FONT_S)
        y = y + LINE_H + 2

        if d.powerDraw > 0 then
            drawLabel = getText("IGUI_LKS_EletricidadeConstrucao_PowerDraw") or "Consumo Elétrico"
            drawLabel = string.gsub(drawLabel, ":%s*$", "")
            self:drawText(drawLabel .. ":", x0, y + 5, 1, 1, 1, 0.80, FONT_S)

            local unitsStr = getText("IGUI_LKS_EletricidadeConstrucao_UnitsPerGen") or "unidades por gerador"
            self:drawText(string.format("%.1f " .. unitsStr, d.powerDraw), x0 + barCol, y + 5, 0.78, 0.95, 0.78, 1,
                FONT_S)
            y = y + LINE_H

            drawLabel = getText("IGUI_LKS_EletricidadeConstrucao_FuelRate") or "Consumo de Combustível"
            drawLabel = string.gsub(drawLabel, ":%s*$", "")
            self:drawText(drawLabel .. ":", x0, y + 5, 1, 1, 1, 0.80, FONT_S)
            local lphStr = getText("IGUI_LKS_EletricidadeConstrucao_LitresPerHour") or "Litros por hora"
            self:drawText(string.format("%.3f " .. lphStr, d.fuelRateLph or 0), x0 + barCol, y + 5, 0.78, 0.95, 0.78, 1,
                FONT_S)
            y = y + LINE_H

            drawLabel = getText("IGUI_EstRuntime") or "Duração Estimada"
            drawLabel = string.gsub(drawLabel, ":%s*$", "")

            local actualLph = d.fuelRateLph or 0
            local rtFuel = (d.totalFuel or 0) > 0 and d.totalFuel or d.fuel
            if rtFuel > 0 and actualLph > 0 then
                local hrs     = rtFuel / actualLph
                local days    = math.floor(hrs / 24)
                local hh      = math.floor(hrs % 24)
                local dayStr  = getText("IGUI_LKS_EletricidadeConstrucao_Days") or " dias"
                local hourStr = getText("IGUI_LKS_EletricidadeConstrucao_Hours") or " horas"
                local ts      = days > 0 and (days .. dayStr .. " " .. hh .. hourStr) or (hh .. hourStr)

                self:drawText(drawLabel .. ":", x0, y + 5, 1, 1, 1, 0.80, FONT_S)
                self:drawText("~" .. ts, x0 + barCol, y + 5, 0.70, 1.00, 1.00, 1, FONT_S)
                y = y + LINE_H
            end
            y = y + 2
        end

        y = self:drawStrainBar(x0, y, getText("IGUI_SystemStrain") or "Carga da Rede Elétrica", d.strain, barCol)

        local iconY = y + 7
        local textY = y + 5

        if d.strain > 50 and d.strain < 76 then
            self._warnTex = self._warnTex or getTexture(WARN_TEX_PATH)
            if self._warnTex then
                self:drawTextureScaled(self._warnTex, x0, iconY, 16, 16, 1, 1, 1, 1)
                self:drawText(getText("IGUI_StrainWarning") or "Consumo moderado de combustível", x0 + 20, textY, 1.0,
                    0.75, 0.10, 1, FONT_S)
            end
            y = y + LINE_H + 2
        end

        if d.strain >= 76 and d.strain < 100 then
            self._warnTex = self._warnTex or getTexture(WARN_TEX_PATH)
            if self._warnTex then
                self:drawTextureScaled(self._warnTex, x0, iconY, 16, 16, 1, 1, 1, 1)
                self:drawText(getText("IGUI_StrainWarning2") or "Consumo alto de combustível", x0 + 20, textY, 1.0, 0.45,
                    0.10, 1, FONT_S)
            end
            y = y + LINE_H + 2
        end

        if d.strain >= 100 then
            self._overlTex = self._overlTex or getTexture(OVERL_TEX_PATH)
            local wt = #self.allGenerators <= 1 and
                (getText("IGUI_StrainWarning_Overload_Single") or "SOBRECARGA - Risco de fogo e explosão no gerador !") or
                (getText("IGUI_StrainWarning_Overload_Multiple") or "SOBRECARGA - Risco de fogo e explosão nos geradores !!!")

            if self._overlTex then
                self:drawTextureScaled(self._overlTex, x0, iconY, 16, 16, 1, 1, 1, 1)
                self:drawText(wt, x0 + 20, textY, 1.0, 0.0, 0.0, 1, FONT_S)
            end
            y = y + LINE_H + 2
        end

        y                = y + 12 -- Espaçamentro entre o final do CONSTRUCAO e o início do SISTEMA DE CLIMATIZAÇÃO
        y                = self:drawSection(x0, y, getText("IGUI_LKS_EletricidadeConstrucao_SectionHeating") or "SISTEMA DE CLIMATIZAÇÃO")

        self._heatOnTex  = self._heatOnTex or getTexture(HEAT_ON_PATH)
        self._heatOffTex = self._heatOffTex or getTexture(HEAT_OFF_PATH)

        if not self._heatingHasData then
            self:drawText(getText("IGUI_LKS_EletricidadeConstrucao_HeatingNA") or "Sem Dados do termostato", x0, y + 5, 0.55, 0.55, 0.55, 1,
                FONT_S)
            y                    = y + LINE_H
            self._heatOnBtnArea  = nil; self._heatOffBtnArea = nil; self._heatMinusArea = nil; self._heatPlusArea = nil
        else
            y                    = y + 26
            local labelStandby   = getText("IGUI_LKS_EletricidadeConstrucao_HeatingStandby") or "Standby"
            local labelActive    = getText("IGUI_LKS_EletricidadeConstrucao_HeatingActive") or "Ligado"
            local ICO_SIZE       = (LINE_H - 2) * 2
            local ICO_GAP        = 40
            local iconsW         = ICO_SIZE * 2 + ICO_GAP
            local offX           = math.floor((self.width - iconsW) / 2)
            local onX            = offX + ICO_SIZE + ICO_GAP

            -- INJEÇÃO DE VARIÁVEIS COLUNA ESQUERDA (arrowAndColdIcon) e DIREITA (arrowAndHotIcon)
            local offX_final     = offX + HUD_Offsets.arrowAndColdIcon.x
            local onX_final      = onX + HUD_Offsets.arrowAndHotIcon.x
            local offY_final     = y - HUD_Offsets.arrowAndColdIcon.y
            local onY_final      = y - HUD_Offsets.arrowAndHotIcon.y

            -- Destaque dos botões do termostato (utiliza a tabela Thermostat_Alpha para ajuste dinâmico de opacidade)
            local alphaHighlight = (Thermostat_Alpha.activeHighlight or 100) / 100

            if self._heatingEnabled then
                -- Aquecimento Ativo: Chama acesa com realce forte, Floco de Neve apagado com borda sutil
                self:drawRect(onX_final - 3, onY_final, ICO_SIZE + 6, ICO_SIZE + 4, alphaHighlight, 0.90, 0.30, 0.10)
                self:drawRectBorder(onX_final - 3, onY_final, ICO_SIZE + 6, ICO_SIZE + 4, alphaHighlight, 0.90, 0.30,
                    0.10)

                -- Borda sutil de inatividade para o floco de neve
                self:drawRectBorder(offX_final - 3, offY_final, ICO_SIZE + 6, ICO_SIZE + 4, alphaHighlight * 0.20, 0.20,
                    0.60,
                    0.90)
            else
                -- Refrigeração Ativa: Floco de Neve aceso com realce forte, Chama apagada com borda sutil
                self:drawRect(offX_final - 3, offY_final, ICO_SIZE + 6, ICO_SIZE + 4, alphaHighlight, 0.20, 0.60, 0.90)
                self:drawRectBorder(offX_final - 3, offY_final, ICO_SIZE + 6, ICO_SIZE + 4, alphaHighlight, 0.20, 0.60,
                    0.90)

                -- Borda sutil de inatividade para a chama
                self:drawRectBorder(onX_final - 3, onY_final, ICO_SIZE + 6, ICO_SIZE + 4, alphaHighlight * 0.20, 0.90,
                    0.30,
                    0.10)
            end

            -- Rótulos textuais acima de cada botão
            local textW1   = getTextManager():MeasureStringX(FONT_S, labelStandby)
            local textX1   = offX_final + (ICO_SIZE - textW1) / 2 + HUD_Offsets.labelStandby.x
            local textW2   = getTextManager():MeasureStringX(FONT_S, labelActive)
            local textX2   = onX_final + (ICO_SIZE - textW2) / 2 + HUD_Offsets.labelActive.x

            local standbyY = offY_final - 18 - HUD_Offsets.labelStandby.y
            local activeY  = onY_final - 18 - HUD_Offsets.labelActive.y

            if self._heatingEnabled then
                self:drawText(labelStandby, textX1, standbyY, 0.55, 0.55, 0.55, 0.60, FONT_S)
                self:drawText(labelActive, textX2, activeY, 0.90, 0.30, 0.10, 1.00, FONT_S)
            else
                self:drawText(labelStandby, textX1, standbyY, 0.20, 0.60, 0.90, 1.00, FONT_S)
                self:drawText(labelActive, textX2, activeY, 0.55, 0.55, 0.55, 0.60, FONT_S)
            end

            -- Floco de neve (Esquerda)
            if self._heatOffTex then
                self:drawTextureScaled(self._heatOffTex, offX_final, offY_final + 4, ICO_SIZE, ICO_SIZE, 1, 1, 1, 1)
            else
                self:drawText(getText("IGUI_LKS_EletricidadeConstrucao_HeatingOff") or "DESLIGADO", offX_final, offY_final + 8, 0.60, 0.60, 0.60,
                    1, FONT_S)
            end

            -- Chama (Direita)
            if self._heatOnTex then
                self:drawTextureScaled(self._heatOnTex, onX_final, onY_final + 4, ICO_SIZE, ICO_SIZE, 1, 1, 1, 1)
            else
                self:drawText(getText("IGUI_LKS_EletricidadeConstrucao_HeatingOn") or "LIGADO", onX_final, onY_final + 8, 0.20, 0.80, 0.28, 1,
                    FONT_S)
            end

            -- Amarra as caixas clicáveis do mouse aos novos locais movidos
            self._heatOffBtnArea = {
                y1 = y - HUD_Offsets.arrowAndColdIcon.y,
                y2 = y + ICO_SIZE + 4 -
                    HUD_Offsets.arrowAndColdIcon.y,
                x1 = offX_final,
                x2 = offX_final + ICO_SIZE
            }
            self._heatOnBtnArea  = {
                y1 = y - HUD_Offsets.arrowAndHotIcon.y,
                y2 = y + ICO_SIZE + 4 -
                    HUD_Offsets.arrowAndHotIcon.y,
                x1 = onX_final,
                x2 = onX_final + ICO_SIZE
            }

            y                    = y + ICO_SIZE + 4 + 6

            self._thermDownTex   = self._thermDownTex or getTexture(THERM_DOWN_PATH)
            self._thermUpTex     = self._thermUpTex or getTexture(THERM_UP_PATH)
            local ICON_SIZE      = 24
            local tempStr        = tostring(self._heatingTemp or 22) .. " C"
            local tempW          = getTextManager():MeasureStringX(FONT_S, tempStr)

            -- Posições X e Y base das setas e do valor numérico
            local mX_base        = math.floor(offX + (ICO_SIZE / 2) - (ICON_SIZE / 2))
            local pX_base        = math.floor(onX + (ICO_SIZE / 2) - (ICON_SIZE / 2))
            local vX             = math.floor((self.width - tempW) / 2)

            local mX_final       = mX_base + HUD_Offsets.arrowAndColdIcon.x
            local pX_final       = pX_base + HUD_Offsets.arrowAndHotIcon.x

            local tempLineH      = 28
            -- Centra verticalmente a seta de 24px dentro da linha de 28px
            local mY_final       = y + math.floor((tempLineH - ICON_SIZE) / 2) - HUD_Offsets.arrowAndColdIcon.y
            local pY_final       = y + math.floor((tempLineH - ICON_SIZE) / 2) - HUD_Offsets.arrowAndHotIcon.y
            -- Centra verticalmente o texto (altura aproximada de 14px da fonte FONT_S)
            local textY          = y + math.floor((tempLineH - 14) / 2)

            drawLabel            = getText("IGUI_LKS_EletricidadeConstrucao_TargetTemp") or "Ajustar Temperatura"
            drawLabel            = string.gsub(drawLabel, ":%s*$", "")
            self:drawText(drawLabel .. ":", x0, textY, 1, 1, 1, 0.80, FONT_S)

            -- Seta Azul (Apanha o offset do Floco de Neve)
            if self._thermDownTex then
                self:drawTextureScaled(self._thermDownTex, mX_final, mY_final, ICON_SIZE, ICON_SIZE, 1, 1, 1, 1)
            else
                self:drawText("[-]", mX_final, mY_final - 1, 0.75, 0.75, 0.75, 1, FONT_S)
            end

            -- Texto central da temperatura (Fica fixo no centro morto da janela)
            self:drawText(tempStr, vX, textY, 0.90, 0.90, 0.50, 1, FONT_S)

            -- Seta Vermelha (Apanha o offset da Chama)
            if self._thermUpTex then
                self:drawTextureScaled(self._thermUpTex, pX_final, pY_final, ICON_SIZE, ICON_SIZE, 1, 1, 1, 1)
            else
                self:drawText("[+]", pX_final, pY_final - 1, 0.75, 0.75, 0.75, 1, FONT_S)
            end

            -- Amarra as áreas de clique das setas aos novos locais movidos
            self._heatMinusArea = {
                y1 = mY_final,
                y2 = mY_final + ICON_SIZE,
                x1 = mX_final,
                x2 = mX_final + ICON_SIZE
            }
            self._heatPlusArea  = {
                y1 = pY_final,
                y2 = pY_final + ICON_SIZE,
                x1 = pX_final,
                x2 = pX_final + ICON_SIZE
            }
            y                   = y + tempLineH
        end
    else
        self:drawText(getText("IGUI_NotConnectedToBuilding") or "Não conectado a uma construção", x0, y + 5, 0.58, 0.58,
            0.58, 1, FONT_S)
        y = y + LINE_H
    end

    local btnH = self.closeBtn and self.closeBtn.height or 25
    y = y + 8

    if self.coverageBtn then self.coverageBtn:setY(y) end
    if self.closeBtn then self.closeBtn:setY(y) end

    local newH = y + btnH + 10
    if math.abs(self.height - newH) > 1 then self:setHeight(newH) end
end

-- ============================================================
-- FECHAR
-- ============================================================

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:close()
    self:applyHighlights(false)
    if self.generator then
        local ok, gx, gy, gz = pcall(function()
            return self.generator:getX(), self.generator:getY(),
                self.generator:getZ()
        end)
        if ok and gx then
            local genKey = gx .. "," .. gy .. "," .. gz
            LKS_EletricidadeConstrucao_GeneratorInfoWindow.instances[genKey] = nil
        else
            for k, v in pairs(LKS_EletricidadeConstrucao_GeneratorInfoWindow.instances) do
                if v == self then
                    LKS_EletricidadeConstrucao_GeneratorInfoWindow.instances[k] = nil; break
                end
            end
        end
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

-- ============================================================
-- CONSTRUTOR
-- ============================================================

function LKS_EletricidadeConstrucao_GeneratorInfoWindow:new(x, y, generator, playerNum, anchorSquare)
    local o = ISCollapsableWindow:new(x, y, MIN_WIN_W, 350)
    setmetatable(o, self)
    self.__index                    = self
    o.generator                     = generator
    o.playerNum                     = playerNum or 0
    o.anchorX, o.anchorY, o.anchorZ = nil, nil, nil
    if anchorSquare then o.anchorX, o.anchorY, o.anchorZ = anchorSquare:getX(), anchorSquare:getY(), anchorSquare:getZ() end
    o.title     = getText("IGUI_BuildingPowerInfo") or "Informações Elétricas da Construção"
    o.resizable = false
    return o
end

-- ============================================================
-- API PÚBLICA
-- ============================================================

function LKS_EletricidadeConstrucao_GeneratorInfoWindow.Open(character, generator, anchorSquare, buildingHint)
    if not character then
        LKS_EletricidadeConstrucao.Error("[LKS PATCH - LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow.lua] Personagem invalido")
        return
    end

    local buildingData = ResolveBuildingDataFromAnchor(anchorSquare, buildingHint)

    if not generator and buildingData then
        local refs = CollectGeneratorReferencesForBuilding(buildingData, anchorSquare)
        generator = refs[1]
    elseif generator and not buildingData then
        local poolId, poolData = ResolveBuildingPool(generator)
        buildingData = poolData or ResolveBuildingDataFromAnchor(anchorSquare, poolId)
    end

    if not generator and buildingData then generator = CreateBuildingAnchorProxy(buildingData, anchorSquare) end

    if not generator then
        LKS_EletricidadeConstrucao.Warn(
            "[LKS PATCH - LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow.lua] Gerador fora de alcance – aproxime-se mais do gerador e tente novamente")
        return
    end

    local genKey = generator:getX() .. "," .. generator:getY() .. "," .. generator:getZ()
    local existing = LKS_EletricidadeConstrucao_GeneratorInfoWindow.instances[genKey]
    if existing then
        existing.generator = generator
        existing.buildingData = buildingData or existing.buildingData
        if anchorSquare then
            existing.anchorX, existing.anchorY, existing.anchorZ = anchorSquare:getX(), anchorSquare:getY(),
                anchorSquare:getZ()
        else
            existing.anchorX, existing.anchorY, existing.anchorZ = nil, nil, nil
        end
        existing:bringToTop()
        existing:requestFreshStats()
        return
    end

    local x = math.floor((getCore():getScreenWidth() - MIN_WIN_W) / 2)
    local y = math.floor((getCore():getScreenHeight() - 350) / 2)

    local win = LKS_EletricidadeConstrucao_GeneratorInfoWindow:new(x, y, generator, character:getPlayerNum(), anchorSquare)
    win.buildingData = buildingData
    win:initialise()
    win:instantiate()
    win:addToUIManager()
    win:setVisible(true)

    LKS_EletricidadeConstrucao_GeneratorInfoWindow.instances[genKey] = win
    win:requestFreshStats()
    LKS_EletricidadeConstrucao.Print("[GeneratorInfoWindow] Aberta para o gerador em " .. genKey)
end

function LKS_EletricidadeConstrucao_GeneratorInfoWindow.CloseAll()
    for _, win in pairs(LKS_EletricidadeConstrucao_GeneratorInfoWindow.instances) do win:close() end
end

-- ============================================================
-- EXPORTAR
-- ============================================================

LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow = LKS_EletricidadeConstrucao_GeneratorInfoWindow
print("[LKS PATCH - LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow.lua] Janela de Informacoes do Gerador carregada com sucesso")
