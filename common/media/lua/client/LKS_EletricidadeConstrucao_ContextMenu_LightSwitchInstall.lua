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

-- ARQUIVO: LKS_EletricidadeConstrucao_ContextMenu_LightSwitchInstall.lua
-- OBJETIVO: Permite a instalação física de interruptores de luz nativos do jogo de volta nas paredes.
-- LOCALIZAÇÃO: client

if isClient() or not isServer() then
    -- Execução autorizada no cliente ou host local
else
    return -- Ignorado em servidores dedicados
end

if LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.RegisterModule then
    LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ContextMenu_LightSwitchInstall", "2.0.0")
end

-- ============================================================================
-- CONSTANTES / UTILITÁRIOS
-- ============================================================================

local ITENS_INTERRUPTOR = {
    "Base.lighting_indoor_01_0",
    "Base.lighting_indoor_01_1",
    "Base.lighting_indoor_01_2",
    "Base.lighting_indoor_01_3",
    "Base.lighting_indoor_01_4",
    "Base.lighting_indoor_01_5",
    "Base.lighting_indoor_01_6",
    "Base.lighting_indoor_01_7",
}

local DIR_N = 0
local DIR_S = 4
local DIR_E = 6
local DIR_W = 2

--- Verifica se o item informado é um interruptor de luz padrão.
--- @param item any O item de inventário.
--- @return boolean Retorna true se corresponder a um interruptor.
local function IsInterruptorLuzItem(item)
    if not item then return false end
    local tipoCompleto = item:getFullType()
    for _, tipoInterruptor in ipairs(ITENS_INTERRUPTOR) do
        if tipoCompleto == tipoInterruptor then return true end
    end
    return false
end

--- Retorna a direção direcional ISO correspondente da engine.
--- @param constanteDirecao integer A constante direcional.
--- @return any A direção ISO.
local function ObterDirecaoIso(constanteDirecao)
    if constanteDirecao == DIR_N then return IsoDirections.N
    elseif constanteDirecao == DIR_S then return IsoDirections.S
    elseif constanteDirecao == DIR_E then return IsoDirections.E
    elseif constanteDirecao == DIR_W then return IsoDirections.W end
    return IsoDirections.N
end

--- Localiza uma parede adjacente ao jogador em qualquer direção cardeal (N, S, E, W).
--- @param quadradoJogador any O GridSquare do jogador.
--- @return integer|nil direcao, any|nil O quadrado da parede.
local function LocalizarParedeAdjacente(quadradoJogador)
    if not quadradoJogador then return nil, nil end

    -- Parede Norte no quadrado do jogador
    local paredeNorte = quadradoJogador:getWall(true)
    if paredeNorte then
        return DIR_N, quadradoJogador
    end

    -- Parede Sul (no quadrado ao sul, virada para o norte)
    local quadradoSul = quadradoJogador:getAdjacentSquare(ObterDirecaoIso(DIR_S))
    if quadradoSul then
        local paredeSul = quadradoSul:getWall(true)
        if paredeSul then
            return DIR_S, quadradoJogador
        end
    end

    -- Parede Oeste no quadrado do jogador
    local paredeOeste = quadradoJogador:getWall(false)
    if paredeOeste then
        return DIR_W, quadradoJogador
    end

    -- Parede Leste (no quadrado a leste, virada para o oeste)
    local quadradoLeste = quadradoJogador:getAdjacentSquare(ObterDirecaoIso(DIR_E))
    if quadradoLeste then
        local paredeLeste = quadradoLeste:getWall(false)
        if paredeLeste then
            return DIR_E, quadradoJogador
        end
    end

    return nil, nil
end

--- Mapeamento de Sprites nativos (Base 42):
--- lighting_indoor_01_0 = Parede Norte
--- lighting_indoor_01_1 = Parede Oeste
--- lighting_indoor_01_2 = Parede Leste
--- lighting_indoor_01_3 = Parede Sul
--- @param direcao integer A constante direcional.
--- @return string O nome do sprite.
local function ObterSpriteInterruptor(direcao)
    if direcao == DIR_N then return "lighting_indoor_01_0" end
    if direcao == DIR_S then return "lighting_indoor_01_3" end
    if direcao == DIR_W then return "lighting_indoor_01_1" end
    if direcao == DIR_E then return "lighting_indoor_01_2" end
    return "lighting_indoor_01_0"
end

-- ============================================================================
-- AÇÃO TEMPORIZADA (TIMED ACTION)
-- ============================================================================

LKS_EletricidadeConstrucao_InstallLightswitchAction = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_InstallLightswitchAction")

function LKS_EletricidadeConstrucao_InstallLightswitchAction:isValid()
    return self.item ~= nil and
           self.square ~= nil and
           self.direction ~= nil and
           self.character:getInventory():contains(self.item)
end

function LKS_EletricidadeConstrucao_InstallLightswitchAction:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function LKS_EletricidadeConstrucao_InstallLightswitchAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
end

function LKS_EletricidadeConstrucao_InstallLightswitchAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.sound = self.character:playSound("BuildWoodenStructure")
end

function LKS_EletricidadeConstrucao_InstallLightswitchAction:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function LKS_EletricidadeConstrucao_InstallLightswitchAction:perform()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end

    -- Remove o item do inventário do jogador
    self.character:getInventory():Remove(self.item)

    local nomeSprite = ObterSpriteInterruptor(self.direction)
    local sprite = IsoSpriteManager.instance:getSprite(nomeSprite)
    if not sprite then
        ISBaseTimedAction.perform(self)
        return
    end

    -- Instancia o objeto nativo IsoLightSwitch
    local interruptor = IsoLightSwitch.new(getCell(), self.square, sprite, 0)
    if interruptor then
        interruptor:addLightSourceFromSprite()
        self.square:AddSpecialObject(interruptor)
        interruptor:transmitCompleteItemToServer()
        local dadosMod = interruptor:getModData()
        dadosMod.isVanillaLightSwitch = true
    end

    ISBaseTimedAction.perform(self)
end

function LKS_EletricidadeConstrucao_InstallLightswitchAction:new(personagem, item, quadrado, direcao)
    local objetoInstancia = {}
    setmetatable(objetoInstancia, self)
    self.__index = self
    objetoInstancia.character = personagem
    objetoInstancia.item = item
    objetoInstancia.square = quadrado
    objetoInstancia.direction = direcao
    objetoInstancia.stopOnWalk = true
    objetoInstancia.stopOnRun = true
    objetoInstancia.maxTime = 100 -- Aproximadamente 10 segundos
    return objetoInstancia
end

-- ============================================================================
-- EVENTO DE MENU DE CONTEXTO DO INVENTÁRIO
-- ============================================================================

Events.OnFillInventoryObjectContextMenu.Add(function(numeroJogador, contexto, itens)
    local jogadorObjeto = getSpecificPlayer(numeroJogador)
    if not jogadorObjeto then return end

    -- Localiza o item de interruptor na seleção do inventário
    local itemInterruptor = nil
    if itens and #itens > 0 then
        for _, item in ipairs(itens) do
            local itemReal = item
            if type(item) == "table" and item.items then
                itemReal = item.items[1]
            end
            if IsInterruptorLuzItem(itemReal) then
                itemInterruptor = itemReal
                break
            end
        end
    end
    if not itemInterruptor then return end

    local quadradoJogador = jogadorObjeto:getSquare()
    if not quadradoJogador then return end

    local direcao, quadradoParede = LocalizarParedeAdjacente(quadradoJogador)
    if direcao and quadradoParede then
        -- Parede adjacente encontrada: adiciona a opção de instalação
        local opcao = contexto:addOption(
            getText("ContextMenu_InstallLightswitch") or "Instalar Interruptor de Luz",
            jogadorObjeto,
            function()
                ISTimedActionQueue.add(LKS_EletricidadeConstrucao_InstallLightswitchAction:new(jogadorObjeto, itemInterruptor, quadradoParede, direcao))
            end
        )

        local textoDirecao = ""
        if direcao == DIR_N then textoDirecao = "Norte"
        elseif direcao == DIR_S then textoDirecao = "Sul"
        elseif direcao == DIR_W then textoDirecao = "Oeste"
        elseif direcao == DIR_E then textoDirecao = "Leste"
        end

        local dicaContexto = ISInventoryPaneContextMenu.addToolTip()
        dicaContexto:setName(getText("ContextMenu_InstallLightswitch") or "Instalar Interruptor de Luz")
        dicaContexto.description = "Instalar interruptor na parede " .. textoDirecao ..
                              "\nTempo: ~10 segundos" ..
                              "\nLâmpada inclusa"
        opcao.toolTip = dicaContexto
    else
        -- Nenhuma parede adjacente encontrada: exibe a opção desabilitada com aviso explicativo
        local opcao = contexto:addOption(
            getText("ContextMenu_InstallLightswitch") or "Instalar Interruptor de Luz",
            nil,
            nil
        )
        opcao.notAvailable = true
        local dicaContexto = ISInventoryPaneContextMenu.addToolTip()
        dicaContexto:setName(getText("ContextMenu_InstallLightswitch") or "Instalar Interruptor de Luz")
        dicaContexto.description = "Nenhuma parede próxima" ..
                              "\nAproxime-se de uma parede para realizar a instalação."
        opcao.toolTip = dicaContexto
    end
end)
