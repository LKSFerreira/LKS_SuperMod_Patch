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

-- ARQUIVO: LKS_EletricidadeConstrucao_Actions_OpenInfoWindow.lua
-- OBJETIVO: Ação Temporizada (TimedAction) para abrir a janela de interface gráfica de informações do gerador.
-- Versão: 2.0.0-alpha
-- Data: 15 de Junho de 2026

-- Garante que o namespace principal exista
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Actions_OpenInfoWindow] Namespace LKS_EletricidadeConstrucao não encontrado - pulando carregamento do módulo")
    return
end

-- Carrega dependência nativa do jogo
require "TimedActions/ISBaseTimedAction"

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_Actions_OpenInfoWindow", "2.0.0")

LKS_EletricidadeConstrucao.Actions = LKS_EletricidadeConstrucao.Actions or {}

-- ============================================================================
-- DEFINIÇÃO DA CLASSE DE AÇÃO TEMPORIZADA
-- ============================================================================

LKS_EletricidadeConstrucao_OpenInfoWindow = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_OpenInfoWindow")

-- ============================================================================
-- VALIDAÇÕES
-- ============================================================================

function LKS_EletricidadeConstrucao_OpenInfoWindow:isValid()
    -- O gerador físico deve continuar existindo no mapa
    if not self.generator then return false end
    
    -- O gerador deve estar no mesmo quadrado
    local quadrado = self.generator:getSquare()
    if not quadrado then return false end
    
    return true
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:waitToStart()
    local quadrado = self.anchorSquare or (self.generator and self.generator:getSquare())
    if quadrado then
        self.character:faceLocation(quadrado:getX(), quadrado:getY())
    end
    return self.character:shouldBeTurning()
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:update()
    local quadrado = self.anchorSquare or (self.generator and self.generator:getSquare())
    if quadrado then
        self.character:faceLocation(quadrado:getX(), quadrado:getY())
    end
end

-- ============================================================================
-- ANIMAÇÃO
-- ============================================================================

function LKS_EletricidadeConstrucao_OpenInfoWindow:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:stop()
    ISBaseTimedAction.stop(self)
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:perform()
    ISBaseTimedAction.perform(self)
end

-- ============================================================================
-- OPERAÇÕES E EXECUÇÃO
-- ============================================================================

--- Normaliza a dica da construção (tabela ou string) retornando apenas o seu ID.
--- @param dicaConstrucao table|string A dica da construção.
--- @return string|nil O ID normalizado ou nil.
local function NormalizarDicaConstrucao(dicaConstrucao)
    if type(dicaConstrucao) == "table" then
        return dicaConstrucao.id
    end
    if type(dicaConstrucao) == "string" then
        return dicaConstrucao
    end
    return nil
end

--- Envia a mensagem de abertura da interface para o cliente multiplayer solicitado.
--- @param objetoJogador any O jogador solicitante.
--- @param gerador any O gerador físico de referência.
--- @param quadradoAncora any O quadrado de âncora de mapa.
--- @param dicaConstrucao table|string Dica da construção associada.
--- @return boolean Retorna true se a mensagem do servidor foi enviada.
local function EnviarAberturaJanelaAoCliente(objetoJogador, gerador, quadradoAncora, dicaConstrucao)
    if not objetoJogador or not sendServerCommand then
        return false
    end

    local quadradoGerador = gerador and gerador:getSquare()
    if not quadradoGerador then
        return false
    end

    local cargaDados = {
        kind = "OpenInfoWindow",
        success = true,
        genX = quadradoGerador:getX(),
        genY = quadradoGerador:getY(),
        genZ = quadradoGerador:getZ(),
    }

    local quadrado = quadradoAncora or quadradoGerador
    if quadrado then
        cargaDados.anchorX = quadrado:getX()
        cargaDados.anchorY = quadrado:getY()
        cargaDados.anchorZ = quadrado:getZ()
    end

    local identificadorConstrucao = NormalizarDicaConstrucao(dicaConstrucao)
    if identificadorConstrucao then
        cargaDados.buildingID = identificadorConstrucao
    end

    sendServerCommand(objetoJogador, "LKS_EletricidadeConstrucao", "ActionResult", cargaDados)
    return true
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:complete()
    -- Servidores dedicados não possuem interface visual (UI) nativa;
    -- enviam uma solicitação de comando para que o cliente solicitante abra localmente.
    if isServer() and not isClient() then
        if not EnviarAberturaJanelaAoCliente(self.character, self.generator, self.anchorSquare, self.buildingHint) then
            LKS_EletricidadeConstrucao.Warn("[OpenInfoWindow] Servidor dedicado falhou ao enviar comando de abertura ao cliente")
        end
        return true
    end
    
    -- Verifica se o módulo de interface gráfica foi carregado com sucesso
    if not LKS_EletricidadeConstrucao.UI or not LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow then
        LKS_EletricidadeConstrucao.Error("[OpenInfoWindow] O módulo LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow não foi localizado!")
        return true
    end
    
    LKS_EletricidadeConstrucao.Print("[OpenInfoWindow] Abrindo janela de estatísticas elétricas")
    
    if LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow.Open then
        LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow.Open(
            self.character, self.generator, self.anchorSquare, self.buildingHint)
    else
        LKS_EletricidadeConstrucao.Error("[OpenInfoWindow] O método LKS_EletricidadeConstrucao.UI.GeneratorInfoWindow.Open não foi localizado!")
    end
    
    return true
end

-- ============================================================================
-- DURAÇÃO E CONSTRUTOR
-- ============================================================================

function LKS_EletricidadeConstrucao_OpenInfoWindow:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    -- Abrir a interface de forma natural leva 1 segundo físico (10 ticks)
    return 10
end

function LKS_EletricidadeConstrucao_OpenInfoWindow:new(character, generator, anchorSquare, buildingHint)
    local objetoInstanciado = ISBaseTimedAction.new(self, character)
    objetoInstanciado.character = character
    objetoInstanciado.generator = generator
    objetoInstanciado.anchorSquare = anchorSquare
    objetoInstanciado.buildingHint = NormalizarDicaConstrucao(buildingHint)
    objetoInstanciado.stopOnWalk = true
    objetoInstanciado.stopOnRun = true
    objetoInstanciado.maxTime = objetoInstanciado:getDuration()
    return objetoInstanciado
end

-- ============================================================================
-- EXPORTAÇÃO PARA O NAMESPACE
-- ============================================================================

LKS_EletricidadeConstrucao.Actions.OpenInfoWindow = LKS_EletricidadeConstrucao_OpenInfoWindow

LKS_EletricidadeConstrucao.Print("Ação OpenInfoWindow carregada no namespace")
