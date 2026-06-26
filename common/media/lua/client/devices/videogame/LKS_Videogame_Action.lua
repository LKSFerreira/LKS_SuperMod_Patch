-- ============================================================================
-- LKS SUPERMOD PATCH — Videogame Funcional
-- ============================================================================
-- ARQUIVO: LKS_Videogame_Action.lua
-- OBJETIVO: TimedAction para o modo automático de jogo. Reduz estresse e depressão,
--           limita campo de visão, atrai zumbis e consome bateria.
-- ============================================================================

require "TimedActions/ISBaseTimedAction"

---@class LKS_Videogame_Action : ISBaseTimedAction
LKS_Videogame_Action = ISBaseTimedAction:derive("LKS_Videogame_Action")

-- ============================================================================
-- CONSTRUTOR
-- ============================================================================

---@param jogador IsoPlayer Jogador que está jogando
---@param itemVideogame InventoryItem Item do videogame equipado
---@return LKS_Videogame_Action
function LKS_Videogame_Action:new(jogador, itemVideogame)
    local objeto = ISBaseTimedAction.new(self, jogador)
    objeto.maxTime = -1
    objeto.itemVideogame = itemVideogame
    objeto.campoVisaoOriginal = nil
    objeto.ultimoTickReducao = 0
    objeto.stopOnWalk = true
    objeto.stopOnRun = true
    return objeto
end

-- ============================================================================
-- VALIDAÇÃO
-- ============================================================================

function LKS_Videogame_Action:isValid()
    local jogador = self.character
    if not jogador or jogador:isDead() then return false end
    if not self.itemVideogame then return false end

    -- Verifica se item está equipado nas mãos
    local maoEsquerda = jogador:getSecondaryHandItem()
    local maoDireita = jogador:getPrimaryHandItem()
    if maoEsquerda ~= self.itemVideogame and maoDireita ~= self.itemVideogame then
        return false
    end

    -- Verifica se tem bateria
    local modData = self.itemVideogame:getModData()
    local carga1 = modData["LKS_VG_bateria1_carga"] or 0
    local carga2 = modData["LKS_VG_bateria2_carga"] or 0
    if carga1 <= 0 and carga2 <= 0 then
        return false
    end

    return true
end

-- ============================================================================
-- START
-- ============================================================================

function LKS_Videogame_Action:start()
    local jogador = self.character
    local config = LKS_VIDEOGAME

    -- Animação: segurar item e olhar para baixo (como lendo)
    self:setActionAnim(CharacterActionAnims.Read)
    self:setAnimVariable("ReadType", config.tipoAnimacao)
    self:setOverrideHandModels(nil, self.itemVideogame)

    -- TODO: Campo de visão (-80%) — API não disponível em Lua, implementar quando encontrada

    -- Marcar hora de início para controle de ticks
    self.ultimoTickReducao = getGameTime():getWorldAgeHours() * 60

    -- Registrar no modData que está jogando (para EveryOneMinute detectar)
    local modData = self.itemVideogame:getModData()
    modData["LKS_VG_jogando"] = true
    modData["LKS_VG_inicioJogo"] = getGameTime():getWorldAgeHours() * 60
end

-- ============================================================================
-- UPDATE (chamado a cada tick da TimedAction)
-- ============================================================================

function LKS_Videogame_Action:update()
    local jogador = self.character
    local config = LKS_VIDEOGAME

    -- Verificar se ainda é válido
    if not self:isValid() then
        self:forceComplete()
        return
    end

    -- Calcular tempo decorrido desde último tick de redução
    local tempoAtual = getGameTime():getWorldAgeHours() * 60
    local minutosDecorridos = tempoAtual - self.ultimoTickReducao

    if minutosDecorridos >= 1 then
        self.ultimoTickReducao = tempoAtual
        local minutosParaProcessar = math.floor(minutosDecorridos)

        local modData = self.itemVideogame:getModData()

        -- Volume como proporção (0.0 a 1.0)
        local volume = (modData["LKS_VG_volume"] or config.volumeInicial) / 100.0
        local mutado = modData["LKS_VG_mutado"]
        if mutado then volume = 0 end

        -- Composição multiplicativa: base * volume * eficaciaVolume * eficaciaFone
        local multiplicadorFone = 1.0
        if self:jogadorTemFone() then
            multiplicadorFone = config.eficaciaFone
        end
        local multiplicadorTotal = volume * config.eficaciaVolume * multiplicadorFone

        -- Reduzir estresse
        local estatisticas = jogador:getStats()
        local estresseAtual = estatisticas:get(CharacterStat.STRESS)
        local reducaoEstresse = config.reducaoEstressePorMinuto * minutosParaProcessar * multiplicadorTotal
        local novoEstresse = math.max(0, estresseAtual - reducaoEstresse)
        estatisticas:set(CharacterStat.STRESS, novoEstresse)

        -- Reduzir depressão
        local depressaoAtual = estatisticas:get(CharacterStat.UNHAPPINESS)
        local reducaoDepressao = config.reducaoDepressaoPorMinuto * minutosParaProcessar * multiplicadorTotal
        local novaDepressao = math.max(0, depressaoAtual - reducaoDepressao)
        estatisticas:set(CharacterStat.UNHAPPINESS, novaDepressao)

        -- Atração de zumbis (somente se não mutado e sem fone)
        if not mutado and (not config.foneAnulaAtracaoZumbis or not self:jogadorTemFone()) then
            if volume > 0.1 then
                self:emitirSomAtracaoZumbis()
            end
        end
    end

    -- Aplicar redução de campo de visão continuamente
    self:aplicarReducaoCampoVisao()
end

-- ============================================================================
-- STOP / PERFORM
-- ============================================================================

function LKS_Videogame_Action:stop()
    self:restaurarEstado()
    ISBaseTimedAction.stop(self)
end

function LKS_Videogame_Action:perform()
    self:restaurarEstado()
    ISBaseTimedAction.perform(self)
end

--- Restaura estado original do jogador ao parar de jogar
function LKS_Videogame_Action:restaurarEstado()
    local jogador = self.character
    if not jogador then return end

    -- Restaurar campo de visão
    -- (O PZ restaura automaticamente quando a ação termina, mas garantimos)

    -- Limpar modData de estado
    if self.itemVideogame then
        local modData = self.itemVideogame:getModData()
        modData["LKS_VG_jogando"] = nil
        modData["LKS_VG_inicioJogo"] = nil
    end

    -- Atualizar janela se estiver aberta
    local playerNum = jogador:getPlayerNum()
    if LKS_Videogame_Window and LKS_Videogame_Window.instancias[playerNum] then
        local janela = LKS_Videogame_Window.instancias[playerNum]
        janela.estaJogando = false
    end
end

-- ============================================================================
-- MECÂNICAS DE RISCO
-- ============================================================================

--- Aplica redução de campo de visão enquanto joga
function LKS_Videogame_Action:aplicarReducaoCampoVisao()
    -- TODO: Implementar redução de campo de visão quando API identificada
end

--- Emite som que atrai zumbis em raio configurado
function LKS_Videogame_Action:emitirSomAtracaoZumbis()
    local jogador = self.character
    if not jogador then return end

    local config = LKS_VIDEOGAME
    local raio = config.raioAtracaoZumbis

    -- character:addWorldSoundUnlessInvisible(radius, volume, isRepeat)
    jogador:addWorldSoundUnlessInvisible(raio, raio, false)
end

-- ============================================================================
-- UTILITÁRIOS
-- ============================================================================

---@return boolean temFone Se o videogame tem fone inserido
function LKS_Videogame_Action:jogadorTemFone()
    if not self.itemVideogame then return false end
    local modData = self.itemVideogame:getModData()
    return modData["LKS_VG_fone_tipo"] ~= nil
end

-- ============================================================================
-- FUNÇÃO GLOBAL DE INÍCIO (chamada pela janela)
-- ============================================================================

---@param jogador IsoPlayer Jogador que vai jogar
---@param itemVideogame InventoryItem Item do videogame
function LKS_Videogame_iniciarAcaoJogar(jogador, itemVideogame)
    if not jogador or not itemVideogame then return end

    local acao = LKS_Videogame_Action:new(jogador, itemVideogame)
    ISTimedActionQueue.add(acao)
end

print("[LKS PATCH - LKS_Videogame_Action.lua] Carregado com sucesso!")
