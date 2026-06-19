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

-- ARQUIVO: LKS_EletricidadeConstrucao_Actions_ActivateGenerator.lua
-- OBJETIVO: Ação Temporizada (TimedAction) para ligar e desligar geradores elétricos.
-- DETALHE TÉCNICO: Integra tanto geradores convencionais/avulsos quanto geradores associados
-- a redes elétricas de prédios e malhas de energia complexas.
-- Versão: 2.0.0-alpha
-- Data: 15 de Junho de 2026

-- Garante que o namespace principal exista
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Actions_ActivateGenerator] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- Carrega dependência nativa do jogo
require "TimedActions/ISBaseTimedAction"

LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_Actions_ActivateGenerator", "2.0.0")

LKS_EletricidadeConstrucao.Actions = LKS_EletricidadeConstrucao.Actions or {}

-- ============================================================================
-- DEFINIÇÃO DA CLASSE DE AÇÃO TEMPORIZADA
-- ============================================================================

LKS_EletricidadeConstrucao_ActivateGenerator = ISBaseTimedAction:derive("LKS_EletricidadeConstrucao_ActivateGenerator")

-- ============================================================================
-- VERIFICAÇÕES DE VALIDAÇÃO
-- ============================================================================

function LKS_EletricidadeConstrucao_ActivateGenerator:isValid()
    -- O gerador físico deve continuar existindo no mundo
    if not self.generator then return false end
    
    -- O gerador deve estar presente no quadrado (grid square) ativo
    local quadrado = self.generator:getSquare()
    if not quadrado then return false end
    
    -- Se estiver ativando (ligando), valida combustível e condição mecânica
    if self.activate then
        if self.generator:getFuel() <= 0 then return false end
        if self.generator:getCondition() <= 0 then return false end
    end
    
    return true
end

function LKS_EletricidadeConstrucao_ActivateGenerator:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

function LKS_EletricidadeConstrucao_ActivateGenerator:update()
    self.character:faceThisObject(self.generator)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

-- ============================================================================
-- ANIMAÇÕES
-- ============================================================================

function LKS_EletricidadeConstrucao_ActivateGenerator:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function LKS_EletricidadeConstrucao_ActivateGenerator:stop()
    ISBaseTimedAction.stop(self)
end

function LKS_EletricidadeConstrucao_ActivateGenerator:perform()
    ISBaseTimedAction.perform(self)
end

-- ============================================================================
-- AUXILIARES DE EXECUÇÃO DE AÇÃO
-- ============================================================================

--- Cria uma cópia profunda de uma tabela contendo as coordenadas da caixa delimitadora (BoundingBox).
--- @param origem table A tabela contendo os limites geométricos.
--- @return table|nil Retorna a cópia estruturada ou nil se inválida.
local function CopiarCaixaDelimitadora(origem)
    if type(origem) ~= "table" then
        return nil
    end

    local xMinimo = tonumber(origem.minX or origem[1])
    local yMinimo = tonumber(origem.minY or origem[2])
    local xMaximo = tonumber(origem.maxX or origem[3])
    local yMaximo = tonumber(origem.maxY or origem[4])
    
    if not (xMinimo and yMinimo and xMaximo and yMaximo) then
        return nil
    end

    return {
        minX = xMinimo,
        minY = yMinimo,
        maxX = xMaximo,
        maxY = yMaximo,
    }
end

--- Verifica se uma tabela genérica contém um determinado valor.
--- @param tabela table A tabela a pesquisar.
--- @param valor any O valor a localizar.
--- @return boolean Retorna true se o valor estiver presente na tabela.
local function TabelaContemValor(tabela, valor)
    if type(tabela) ~= "table" then
        return false
    end
    for _, entrada in pairs(tabela) do
        if entrada == valor then
            return true
        end
    end
    return false
end

--- Tenta recuperar os metadados elétricos (PoolData) vinculados a uma construção a partir dos geradores ativos do mundo.
--- @param identificadorPoolConstrucao string O ID da piscina de construção.
--- @param gerador any O objeto do gerador ativo.
--- @return table|nil O arquivo de estado recuperado ou nil.
local function ResolverDadosPoolConstrucao(identificadorPoolConstrucao, gerador)
    local dadosModAtuais = gerador and gerador:getModData() or nil
    if dadosModAtuais and dadosModAtuais.LKS_EletricidadeConstrucao_PoolData then
        return dadosModAtuais.LKS_EletricidadeConstrucao_PoolData
    end
    
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not gerenciadorEstado or not gerenciadorEstado.GetAllGenerators then
        return nil
    end

    local xAtual = gerador and gerador.getX and gerador:getX() or nil
    local yAtual = gerador and gerador.getY and gerador:getY() or nil
    local zAtual = gerador and gerador.getZ and gerador:getZ() or nil

    for _, dadosGerador in pairs(gerenciadorEstado.GetAllGenerators() or {}) do
        if dadosGerador and TabelaContemValor(dadosGerador.connectedBuildings, identificadorPoolConstrucao) then
            local xGerador = tonumber(dadosGerador.x)
            local yGerador = tonumber(dadosGerador.y)
            local zGerador = tonumber(dadosGerador.z) or 0
            if not (xGerador == xAtual and yGerador == yAtual and zGerador == zAtual) then
                local quadrado = getSquare(xGerador, yGerador, zGerador)
                if quadrado then
                    local objetos = quadrado:getObjects()
                    for indiceObjeto = 0, objetos:size() - 1 do
                        local objeto = objetos:get(indiceObjeto)
                        if objeto and instanceof(objeto, "IsoGenerator") then
                            local dadosModObjeto = objeto:getModData()
                            if dadosModObjeto and dadosModObjeto.LKS_EletricidadeConstrucao_PoolData then
                                return dadosModObjeto.LKS_EletricidadeConstrucao_PoolData
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

--- Recria uma construção no gerenciador a partir de metadados recuperados (PoolData).
--- @param identificadorPoolConstrucao string O ID da construção.
--- @param gerenciadorEstado table O gerenciador de estado.
--- @param dadosPool table Os metadados de simulação recuperados.
--- @param xAncora number Coordenada X âncora padrão.
--- @param yAncora number Coordenada Y âncora padrão.
--- @param zAncora number Coordenada Z âncora padrão.
--- @param motivo string Descritivo textual do motivo da reestruturação.
--- @return table|nil O estado de dados da construção recriada.
local function RestaurarConstrucaoDosDadosPool(identificadorPoolConstrucao, gerenciadorEstado, dadosPool, xAncora, yAncora, zAncora, motivo)
    if not dadosPool then
        return nil
    end

    local xConstrucao = dadosPool.x
    local yConstrucao = dadosPool.y
    local zConstrucao = dadosPool.z
    if xConstrucao == nil then xConstrucao = xAncora end
    if yConstrucao == nil then yConstrucao = yAncora end
    if zConstrucao == nil then zConstrucao = zAncora or 0 end
    if xConstrucao == nil or yConstrucao == nil then
        return nil
    end

    local dadosConstrucao = {
        id = identificadorPoolConstrucao,
        x = xConstrucao,
        y = yConstrucao,
        z = zConstrucao,
        generatorId = nil,
        powerConsumers = {},
        totalPowerDraw = 0,
        heatingPowerDraw = 0,
        isPowered = false,
        borderRadius = tonumber(dadosPool.borderRadius) or 30,
        lastScanTime = getTimestampMs(),
        boundingBox = CopiarCaixaDelimitadora(dadosPool.boundingBox),
        isRVInterior = dadosPool.isRVInterior == true,
        heatingEnabled = false,
        heatingSourceCount = 0,
        heatingTargetTemp = 22,
        connectedGenerators = {},
    }

    if gerenciadorEstado.AddBuilding then
        gerenciadorEstado.AddBuilding(dadosConstrucao)
    end

    if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Logger then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(string.format(
            "[ActivateGenerator] %s: Reconstrução efetuada do prédio %s a partir dos metadados elétricos%s",
            tostring(motivo or "update"),
            tostring(identificadorPoolConstrucao),
            dadosConstrucao.boundingBox and " com caixa delimitadora integrada" or ""
        ), "Power")
    end

    return gerenciadorEstado.GetBuilding and gerenciadorEstado.GetBuilding(identificadorPoolConstrucao) or dadosConstrucao
end

--- Garante o vínculo físico e lógico entre um gerador ativo e a malha de uma construção.
--- @param dadosConstrucao table Os dados de representação do prédio.
--- @param gerador any O gerador físico.
--- @param gerenciadorEstado table O gerenciador de estado.
--- @return table Os dados atualizados da construção.
local function GarantirGeradorVinculado(dadosConstrucao, gerador, gerenciadorEstado)
    if not (dadosConstrucao and gerador and gerador.getSquare) then
        return dadosConstrucao
    end

    local quadrado = gerador:getSquare()
    if not quadrado then
        return dadosConstrucao
    end

    local chaveGerador = string.format("%d_%d_%d", quadrado:getX(), quadrado:getY(), quadrado:getZ())
    dadosConstrucao.connectedGenerators = dadosConstrucao.connectedGenerators or {}

    local possuiGerador = false
    for _, chaveExistente in pairs(dadosConstrucao.connectedGenerators) do
        if chaveExistente == chaveGerador then
            possuiGerador = true
            break
        end
    end

    if not possuiGerador then
        table.insert(dadosConstrucao.connectedGenerators, chaveGerador)
        if gerenciadorEstado and gerenciadorEstado.MarkDirty then
            gerenciadorEstado.MarkDirty()
        end
    end

    return dadosConstrucao
end

--- Recupera ou reconstrói o estado lógico de um edifício garantindo sua integridade estrutural.
--- @param identificadorPoolConstrucao string O ID da piscina de construção.
--- @param gerador any O objeto do gerador ativo.
--- @param motivo string Descritivo técnico do motivo da verificação.
--- @return table|nil O estado da construção estruturada.
local function GarantirEstadoConstrucao(identificadorPoolConstrucao, gerador, motivo)
    local gerenciadorEstado = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager
    if not gerenciadorEstado or not identificadorPoolConstrucao then
        return nil
    end

    local dadosPool = ResolverDadosPoolConstrucao(identificadorPoolConstrucao, gerador)
    local dadosConstrucao = gerenciadorEstado.GetBuilding and gerenciadorEstado.GetBuilding(identificadorPoolConstrucao) or nil
    local caixaDelimitadoraRestaurada = CopiarCaixaDelimitadora(dadosPool and dadosPool.boundingBox)

    if dadosConstrucao then
        local reparado = false
        if caixaDelimitadoraRestaurada and not dadosConstrucao.boundingBox then
            dadosConstrucao.boundingBox = caixaDelimitadoraRestaurada
            reparado = true
        end
        if dadosPool then
            if dadosConstrucao.x == nil and dadosPool.x ~= nil then
                dadosConstrucao.x = dadosPool.x
                reparado = true
            end
            if dadosConstrucao.y == nil and dadosPool.y ~= nil then
                dadosConstrucao.y = dadosPool.y
                reparado = true
            end
            if dadosConstrucao.z == nil and dadosPool.z ~= nil then
                dadosConstrucao.z = dadosPool.z
                reparado = true
            end
            if (not dadosConstrucao.borderRadius or dadosConstrucao.borderRadius <= 0)
                    and dadosPool.borderRadius ~= nil then
                dadosConstrucao.borderRadius = tonumber(dadosPool.borderRadius) or dadosConstrucao.borderRadius
                reparado = true
            end
        end
        if reparado and gerenciadorEstado.MarkDirty then
            gerenciadorEstado.MarkDirty()
        end
    end

    if dadosConstrucao and dadosConstrucao.boundingBox then
        return GarantirGeradorVinculado(dadosConstrucao, gerador, gerenciadorEstado)
    elseif dadosConstrucao and caixaDelimitadoraRestaurada then
        dadosConstrucao.boundingBox = caixaDelimitadoraRestaurada
        if gerenciadorEstado.MarkDirty then
            gerenciadorEstado.MarkDirty()
        end
        return GarantirGeradorVinculado(dadosConstrucao, gerador, gerenciadorEstado)
    elseif dadosConstrucao then
        return GarantirGeradorVinculado(dadosConstrucao, gerador, gerenciadorEstado)
    end

    local xAncora, yAncora, zAncora = nil, nil, nil

    if dadosPool and dadosPool.x ~= nil and dadosPool.y ~= nil then
        xAncora = dadosPool.x
        yAncora = dadosPool.y
        zAncora = dadosPool.z or (gerador and gerador:getZ()) or 0
    else
        local xBusca, yBusca, zBusca = string.match(tostring(identificadorPoolConstrucao), "^bld_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        xAncora, yAncora, zAncora = tonumber(xBusca), tonumber(yBusca), tonumber(zBusca)
    end

    if not dadosConstrucao and dadosPool then
        dadosConstrucao = RestaurarConstrucaoDosDadosPool(
            identificadorPoolConstrucao,
            gerenciadorEstado,
            dadosPool,
            xAncora,
            yAncora,
            zAncora,
            motivo
        )
    end

    local Scanner = LKS_EletricidadeConstrucao.Building and LKS_EletricidadeConstrucao.Building.Scanner
    if xAncora ~= nil and yAncora ~= nil and Scanner and Scanner.ScanBuilding then
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Logger then
            LKS_EletricidadeConstrucao.Core.Logger.Warn(string.format(
                "[ActivateGenerator] %s: Varrendo estrutura do prédio %s a partir da âncora (%d,%d,%d)",
                tostring(motivo or "update"), tostring(identificadorPoolConstrucao), xAncora, yAncora, zAncora or 0
            ), "Power")
        end

        local sucesso, varrida = pcall(Scanner.ScanBuilding, xAncora, yAncora, zAncora or 0, identificadorPoolConstrucao)
        if sucesso and varrida then
            dadosConstrucao = varrida
        else
            dadosConstrucao = gerenciadorEstado.GetBuilding and gerenciadorEstado.GetBuilding(identificadorPoolConstrucao) or dadosConstrucao
        end
    end

    if not dadosConstrucao and xAncora ~= nil and yAncora ~= nil then
        dadosConstrucao = {
            id = identificadorPoolConstrucao,
            x = xAncora,
            y = yAncora,
            z = zAncora or 0,
            generatorId = nil,
            powerConsumers = {},
            totalPowerDraw = 0,
            heatingPowerDraw = 0,
            isPowered = false,
            borderRadius = 30,
            lastScanTime = getTimestampMs(),
            boundingBox = nil,
            isRVInterior = false,
            heatingEnabled = false,
            heatingSourceCount = 0,
            heatingTargetTemp = 22,
            connectedGenerators = {},
        }
        if gerenciadorEstado.AddBuilding then
            gerenciadorEstado.AddBuilding(dadosConstrucao)
        end
    end

    return GarantirGeradorVinculado(dadosConstrucao, gerador, gerenciadorEstado)
end

--- Força a atualização do fornecimento elétrico de uma construção após ligar/desligar um gerador da piscina.
--- @param identificadorPoolConstrucao string O ID da piscina de construção.
--- @param gerador any O objeto do gerador.
--- @param motivo string Descritivo do motivo do disparo.
--- @return table|nil A construção atualizada.
local function AtualizarEnergiaConstrucao(identificadorPoolConstrucao, gerador, motivo)
    if not identificadorPoolConstrucao then
        return nil
    end

    local dadosConstrucao = GarantirEstadoConstrucao(identificadorPoolConstrucao, gerador, motivo)
    local DistribuidorEnergia = LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor
    
    if DistribuidorEnergia then
        if DistribuidorEnergia.ForceUpdateBuilding then
            DistribuidorEnergia.ForceUpdateBuilding(identificadorPoolConstrucao)
        elseif DistribuidorEnergia.ForceUpdate then
            DistribuidorEnergia.ForceUpdate()
        end
    end

    return dadosConstrucao
end

--- Efetua fisicamente a ativação ou desativação lógica do gerador no mapa do Project Zomboid.
--- @param gerador any O objeto gerador (IsoGenerator).
--- @param ativar boolean True para ligar, false para desligar.
--- @return boolean Retorna true se a operação ocorreu com sucesso.
local function ExecutarAtivacaoGerador(gerador, ativar)
    if not gerador then return false end

    local dadosMod = gerador:getModData()
    local identificadorPoolConstrucao = dadosMod.Gen_BuildingPoolID
    local estaNoModoConstrucao = identificadorPoolConstrucao ~= nil

    if ativar then
        -- LIGA O GERADOR
        gerador:setActivated(true)

        -- Atualiza dados em tempo de execução para contagem independente de chunks
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
            local GerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
            local identificadorGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(
                gerador:getX(), gerador:getY(), gerador:getZ())
            local dadosGerador = GerenciadorEstado.GetGenerator(identificadorGerador)
            if dadosGerador then
                dadosGerador.activated = true
                GerenciadorEstado.MarkDirty()
            end
        end

        -- Transmite alterações aos clientes em partidas Multiplayer
        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
            gerador:transmitModData()
            if isServer() then
                gerador:sync()
            end
        end

        -- Ativa os sistemas térmicos de aquecimento de imediato
        if LKS_EletricidadeConstrucao_HeatingClient and LKS_EletricidadeConstrucao_HeatingClient.Apply then
            local dadosModAux = gerador:getModData()
            if dadosModAux.HeatingEnabled == true then
                LKS_EletricidadeConstrucao_HeatingClient.Apply(gerador)
            end
        end

        -- Se estiver vinculado a uma rede elétrica de construção, energiza o circuito
        if estaNoModoConstrucao and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            local possuiOutroGeradorAtivo = false
            if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
                local dadosConstrucao = GarantirEstadoConstrucao(identificadorPoolConstrucao, gerador, "activation")
                if dadosConstrucao and dadosConstrucao.connectedGenerators then
                    for _, chaveGerador in pairs(dadosConstrucao.connectedGenerators) do
                        local xGerador, yGerador, zGerador = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        if xGerador and yGerador and zGerador then
                            xGerador, yGerador, zGerador = tonumber(xGerador), tonumber(yGerador), tonumber(zGerador)
                            local quadrado = getSquare(xGerador, yGerador, zGerador)
                            if quadrado then
                                local objetos = quadrado:getObjects()
                                for indiceObjeto = 0, objetos:size() - 1 do
                                    local objeto = objetos:get(indiceObjeto)
                                    if objeto and instanceof(objeto, "IsoGenerator") and objeto ~= gerador then
                                        if objeto:isActivated() then
                                            possuiOutroGeradorAtivo = true
                                            local xOutro, yOutro, zOutro = objeto:getX(), objeto:getY(), objeto:getZ()
                                            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager
                                               and LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator then
                                                LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator(xOutro, yOutro, zOutro)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            AtualizarEnergiaConstrucao(identificadorPoolConstrucao, gerador, possuiOutroGeradorAtivo and "activation-pool" or "activation-first-generator")

            -- Atualiza a taxa de consumo de combustível do gerador ativado de imediato
            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager
               and LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator then
                LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator(
                    gerador:getX(), gerador:getY(), gerador:getZ())
            end
        end

        LKS_EletricidadeConstrucao.Print(string.format(
            "[ActivateGenerator] Gerador ativado em (%d,%d,%d)", 
            gerador:getX(), gerador:getY(), gerador:getZ()))
    else
        -- DESLIGA O GERADOR
        gerador:setActivated(false)

        -- Atualiza dados de execução
        if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
            local GerenciadorEstado = LKS_EletricidadeConstrucao.Core.StateManager
            local identificadorGerador = LKS_EletricidadeConstrucao.Data.Generator.MakeId(
                gerador:getX(), gerador:getY(), gerador:getZ())
            local dadosGerador = GerenciadorEstado.GetGenerator(identificadorGerador)
            if dadosGerador then
                dadosGerador.activated = false
                GerenciadorEstado.MarkDirty()
            end
        end

        -- Transmite alterações aos clientes em partidas Multiplayer
        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
            gerador:transmitModData()
            if isServer() then
                gerador:sync()
            end
        end

        -- Remove as fontes térmicas vinculadas de imediato
        if LKS_EletricidadeConstrucao_HeatingClient and LKS_EletricidadeConstrucao_HeatingClient.Remove then
            local quadradoAux = gerador:getSquare()
            if quadradoAux then
                LKS_EletricidadeConstrucao_HeatingClient.Remove(quadradoAux:getX() .. "_" .. quadradoAux:getY() .. "_" .. quadradoAux:getZ())
            end
        end

        -- Corta ou reduz a energia da malha elétrica do edifício
        if estaNoModoConstrucao and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Distributor then
            local possuiOutroGeradorAtivo = false
            if LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.StateManager then
                local dadosConstrucao = GarantirEstadoConstrucao(identificadorPoolConstrucao, gerador, "deactivation")
                if dadosConstrucao and dadosConstrucao.connectedGenerators then
                    for _, chaveGerador in pairs(dadosConstrucao.connectedGenerators) do
                        local xGerador, yGerador, zGerador = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                        if xGerador and yGerador and zGerador then
                            xGerador, yGerador, zGerador = tonumber(xGerador), tonumber(yGerador), tonumber(zGerador)
                            local quadrado = getSquare(xGerador, yGerador, zGerador)
                            if quadrado then
                                local objetos = quadrado:getObjects()
                                for indiceObjeto = 0, objetos:size() - 1 do
                                    local objeto = objetos:get(indiceObjeto)
                                    if objeto and instanceof(objeto, "IsoGenerator") and objeto ~= gerador then
                                        if objeto:isActivated() then
                                            possuiOutroGeradorAtivo = true
                                            local xOutro, yOutro, zOutro = objeto:getX(), objeto:getY(), objeto:getZ()
                                            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager
                                               and LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator then
                                                LKS_EletricidadeConstrucao.Fuel.Manager.ForceUpdateGenerator(xOutro, yOutro, zOutro)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            AtualizarEnergiaConstrucao(identificadorPoolConstrucao, gerador, possuiOutroGeradorAtivo and "deactivation-pool" or "deactivation-last-generator")
        end

        LKS_EletricidadeConstrucao.Print(string.format(
            "[ActivateGenerator] Gerador desativado em (%d,%d,%d)", 
            gerador:getX(), gerador:getY(), gerador:getZ()))
    end

    return true
end

function LKS_EletricidadeConstrucao_ActivateGenerator:complete()
    local AmbienteExecucao = LKS_EletricidadeConstrucao.Core and LKS_EletricidadeConstrucao.Core.Runtime
    local ehClienteMultiplayer = AmbienteExecucao and AmbienteExecucao.IsMultiplayerClient and AmbienteExecucao.IsMultiplayerClient()

    if ehClienteMultiplayer then
        local quadrado = self.generator and self.generator:getSquare()
        if quadrado and isClient() then
            sendClientCommand(self.character, "LKS_EletricidadeConstrucao", "ActivateGenerator", {
                genX = quadrado:getX(),
                genY = quadrado:getY(),
                genZ = quadrado:getZ(),
                activate = self.activate == true,
            })
        end
        return true
    end

    return ExecutarAtivacaoGerador(self.generator, self.activate)
end

-- ============================================================================
-- CONSTRUTOR E CÁLCULO DE DURABILIDADE
-- ============================================================================

function LKS_EletricidadeConstrucao_ActivateGenerator:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    -- Ação de ligar/desligar dura aproximadamente 5 segundos físicos (50 ticks)
    return 50
end

function LKS_EletricidadeConstrucao_ActivateGenerator:new(character, generator, activate)
    local objetoInstanciado = ISBaseTimedAction.new(self, character)
    objetoInstanciado.character = character
    objetoInstanciado.generator = generator
    objetoInstanciado.activate = activate
    objetoInstanciado.stopOnWalk = true
    objetoInstanciado.stopOnRun = true
    objetoInstanciado.maxTime = objetoInstanciado:getDuration()
    return objetoInstanciado
end

-- ============================================================================
-- EXPORTAÇÃO PARA O NAMESPACE
-- ============================================================================

LKS_EletricidadeConstrucao_ActivateGenerator.Execute = ExecutarAtivacaoGerador
LKS_EletricidadeConstrucao.Actions.ActivateGenerator = LKS_EletricidadeConstrucao_ActivateGenerator

LKS_EletricidadeConstrucao.Print("Acao ActivateGenerator carregada no namespace")
