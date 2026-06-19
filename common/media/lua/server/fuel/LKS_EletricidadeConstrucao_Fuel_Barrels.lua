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

-- ARQUIVO: LKS_EletricidadeConstrucao_Fuel_Barrels.lua
-- OBJETIVO: Conecta barris de combustível líquidos à rede elétrica de geradores para abastecimento automático.
-- LOCALIZAÇÃO: server/fuel

if not LKS_EletricidadeConstrucao then return end

LKS_EletricidadeConstrucao.Fuel = LKS_EletricidadeConstrucao.Fuel or {}
LKS_EletricidadeConstrucao.Fuel.Barrels = LKS_EletricidadeConstrucao.Fuel.Barrels or {}

local Barrels = LKS_EletricidadeConstrucao.Fuel.Barrels
local Logger  = LKS_EletricidadeConstrucao.Core.Logger

-- ============================================================================
-- CONSTANTES
-- ============================================================================

-- Sprites de objetos no mapa que são tratados como barris/recipientes de gasolina acopláveis.
local SPRITES_ACOPLAVEIS = {
    ["useful_barrels_1_2"]                   = true,
    ["crafted_01_28"]                        = true,
    ["crafted_01_32"]                        = true,
    ["useful_barrels_1_0"]                   = true,
    ["carpentry_02_120"]                     = true,
    ["carpentry_02_122"]                     = true,
    ["carpentry_02_124"]                     = true,
    ["carpentry_02_54"]                      = true,
    ["industry_01_22"]                       = true,
    ["industry_01_23"]                       = true,
    ["location_military_generic_01_14"]      = true,
    ["location_military_generic_01_6"]       = true,
}

local CHAVE_MODDATA = "LKS_EletricidadeConstrucao_FuelBarrels"

-- ============================================================================
-- FUNÇÕES AUXILIARES
-- ============================================================================

--- Retorna a chave de coordenada única para um barril específico.
--- @param barril any O objeto do barril.
--- @return string A string identificadora.
local function ChaveDoBarril(barril)
    local quadrado = barril:getSquare()
    return quadrado:getX() .. "_" .. quadrado:getY() .. "_" .. quadrado:getZ()
end

--- Recupera o banco de dados persistente no ModData do jogo.
--- @return table A tabela de barris vinculados.
local function ObterBancoDadosBarris()
    local dadosMod = ModData.getOrCreate(CHAVE_MODDATA)
    if not dadosMod.linkedBarrels then dadosMod.linkedBarrels = {} end
    return dadosMod
end

--- Salva o banco de dados persistente no ModData do jogo.
--- @param dadosMod table Os dados de barris vinculados.
local function SalvarBancoDadosBarris(dadosMod)
    ModData.add(CHAVE_MODDATA, dadosMod)
end

-- ============================================================================
-- API DE COMBUSTÍVEL
-- ============================================================================

--- Verifica se um objeto do mapa pode ser acoplado à rede de combustível.
--- @param objeto any O objeto a ser avaliado.
--- @return boolean Retorna true se for acoplável.
function Barrels.IsLinkable(objeto)
    if not objeto then return false end
    local sprite = objeto:getSprite()
    if not sprite then return false end
    local nome = sprite:getName()
    if not nome then return false end
    if SPRITES_ACOPLAVEIS[nome] then return true end
    
    -- Também aceita qualquer objeto que contenha um fluid container com gasolina
    if objeto.getFluidContainer then
        local ok, recipienteFluidos = pcall(function() return objeto:getFluidContainer() end)
        if ok and recipienteFluidos then
            local ok2, possuiGasolina = pcall(function() return recipienteFluidos:contains(Fluid.Petrol) end)
            if ok2 and possuiGasolina then return true end
        end
    end
    return false
end

--- Retorna a quantidade de gasolina contida em um barril específico.
--- @param barril any O objeto do barril.
--- @return number A quantidade de combustível em litros.
function Barrels.GetPetrolAmount(barril)
    if not barril then return 0 end
    if not barril.getFluidAmount then return 0 end

    -- Tenta verificar via FluidContainer (independe do idioma do jogo)
    if barril.getFluidContainer then
        local ok, recipienteFluidos = pcall(function() return barril:getFluidContainer() end)
        if ok and recipienteFluidos and recipienteFluidos.contains then
            local ok2, possuiGasolina = pcall(function() return recipienteFluidos:contains(Fluid.Petrol) end)
            if ok2 and possuiGasolina then
                local quantidade = barril:getFluidAmount()
                return quantidade > 0 and quantidade or 0
            end
            return 0
        end
    end

    -- Fallback: verifica pelo nome do fluido na interface
    if barril.getFluidUiName then
        local nomeFluido = barril:getFluidUiName()
        local nomeGasolina = getText("Fluid_Name_Petrol")
        if string.lower(nomeFluido or "") == string.lower(nomeGasolina or "") then
            local quantidade = barril:getFluidAmount()
            return quantidade > 0 and quantidade or 0
        end
    end

    return 0
end

--- Retira gasolina de um barril até o limite solicitado.
--- @param barril any O objeto do barril.
--- @param quantidade number A quantidade máxima a retirar em litros.
--- @return number A quantidade real que foi drenada.
function Barrels.RemoveFuel(barril, quantidade)
    if not barril or quantidade <= 0 then return 0 end
    if not barril.getFluidAmount then return 0 end

    local quadrado = barril:getSquare()
    if not quadrado or not quadrado:getChunk() then return 0 end

    if barril.getFluidContainer then
        local ok, recipienteFluidos = pcall(function() return barril:getFluidContainer() end)
        if not ok or not recipienteFluidos then return 0 end
        local ok2, possuiGasolina = pcall(function() return recipienteFluidos:contains(Fluid.Petrol) end)
        if not ok2 or not possuiGasolina then return 0 end
    end

    local atual = barril:getFluidAmount()
    if atual <= 0 then return 0 end

    local remover = math.min(quantidade, atual)
    local manter = atual - remover

    barril:emptyFluid()
    if manter > 0 then
        if not quadrado:getChunk() then return remover end
        barril:addFluid(FluidType.Petrol, manter)
    end
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        barril:transmitModData()
    end
    return remover
end

-- ============================================================================
-- VINCULAR / DESVINCULAR
-- ============================================================================

--- Vincula um barril físico à rede de combustível de uma construção lógica.
--- @param barril any O objeto físico do barril.
--- @param idConstrucao string O ID da construção correspondente.
--- @return boolean, string|nil Retorna status de sucesso e mensagem de erro se falhar.
function Barrels.Link(barril, idConstrucao)
    if not barril or not idConstrucao then
        return false, "argumento nulo (nil)"
    end
    if not Barrels.IsLinkable(barril) then
        return false, "não é um barril acoplável"
    end

    local chave = ChaveDoBarril(barril)
    local dadosModBarril = barril:getModData()
    local idConstrucaoAnterior = dadosModBarril.LKS_EletricidadeConstrucao_LinkedBuilding

    local bancoDados = ObterBancoDadosBarris()
    if idConstrucaoAnterior and idConstrucaoAnterior ~= idConstrucao and bancoDados.linkedBarrels[idConstrucaoAnterior] then
        bancoDados.linkedBarrels[idConstrucaoAnterior][chave] = nil
        local _anyLeft = false
        for _ in pairs(bancoDados.linkedBarrels[idConstrucaoAnterior]) do _anyLeft = true; break end
        if not _anyLeft then bancoDados.linkedBarrels[idConstrucaoAnterior] = nil end
    end

    -- Salva no ModData do próprio barril físico
    dadosModBarril.LKS_EletricidadeConstrucao_LinkedBuilding = idConstrucao
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        barril:transmitModData()
    end

    -- Salva no banco persistente do mod
    if not bancoDados.linkedBarrels[idConstrucao] then
        bancoDados.linkedBarrels[idConstrucao] = {}
    end
    bancoDados.linkedBarrels[idConstrucao][chave] = true
    SalvarBancoDadosBarris(bancoDados)

    Logger.Info(string.format("Barril %s acoplado a construcao %s", chave, idConstrucao), "Fuel.Barrels")
    return true
end

--- Desvincula um barril físico.
--- @param barril any O objeto do barril.
--- @param idConstrucao string|nil O ID da construção associada (opcional).
function Barrels.Unlink(barril, idConstrucao)
    if not barril then return end

    local chave = ChaveDoBarril(barril)
    local bid = idConstrucao or barril:getModData().LKS_EletricidadeConstrucao_LinkedBuilding

    -- Limpa do barril físico
    local dadosModBarril = barril:getModData()
    dadosModBarril.LKS_EletricidadeConstrucao_LinkedBuilding = nil
    if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
        barril:transmitModData()
    end

    if not bid then return end

    -- Limpa do banco de dados global
    local bancoDados = ObterBancoDadosBarris()
    if bancoDados.linkedBarrels[bid] then
        bancoDados.linkedBarrels[bid][chave] = nil
        local _anyLeft = false
        for _ in pairs(bancoDados.linkedBarrels[bid]) do _anyLeft = true; break end
        if not _anyLeft then bancoDados.linkedBarrels[bid] = nil end
    end
    SalvarBancoDadosBarris(bancoDados)

    Logger.Info(string.format("Barril %s desacoplado da construcao %s", chave, bid), "Fuel.Barrels")
end

--- Verifica se o barril está vinculado à construção específica.
--- @param barril any O objeto do barril.
--- @param idConstrucao string O ID da construção.
--- @return boolean Retorna true se estiver vinculado.
function Barrels.IsLinked(barril, idConstrucao)
    if not barril or not idConstrucao then return false end
    local dadosModBarril = barril:getModData()
    return dadosModBarril.LKS_EletricidadeConstrucao_LinkedBuilding == idConstrucao
end

--- Retorna o ID da construção vinculada ao barril.
--- @param barril any O objeto do barril.
--- @return string|nil O ID da construção ou nil.
function Barrels.GetLinkedBuilding(barril)
    if not barril then return nil end
    return barril:getModData().LKS_EletricidadeConstrucao_LinkedBuilding
end

-- ============================================================================
-- CONSULTA DE BARRIS ACOPLADOS
-- ============================================================================

--- Coleta a lista de objetos de barris vinculados à construção que estão atualmente carregados no mundo.
--- @param idConstrucao string O ID da construção.
--- @return table A lista de objetos de barris físicos ativos.
function Barrels.GetLinkedBarrels(idConstrucao)
    if not idConstrucao then return {} end
    local bancoDados = ObterBancoDadosBarris()
    if not bancoDados.linkedBarrels or not bancoDados.linkedBarrels[idConstrucao] then return {} end

    local celula = getCell()
    if not celula then return {} end

    local resultado = {}
    local obsoletos = {}

    for chave, _ in pairs(bancoDados.linkedBarrels[idConstrucao]) do
        local posicaoX, posicaoY, posicaoZ = string.match(chave, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if posicaoX then
            local quadrado = celula:getGridSquare(tonumber(posicaoX), tonumber(posicaoY), tonumber(posicaoZ))
            if quadrado and quadrado:getChunk() then
                local objetos = quadrado:getObjects()
                local encontrado = false
                for i = 0, objetos:size() - 1 do
                    local objeto = objetos:get(i)
                    if objeto and Barrels.IsLinkable(objeto) then
                        local idConstrucaoAcoplada = objeto:getModData().LKS_EletricidadeConstrucao_LinkedBuilding
                        if idConstrucaoAcoplada == idConstrucao then
                            table.insert(resultado, objeto)
                            encontrado = true
                            break
                        end
                    end
                end
                if not encontrado then
                    table.insert(obsoletos, chave)
                end
            end
        end
    end

    -- Remove do banco as chaves de barris deletados ou destruídos
    if #obsoletos > 0 then
        for _, k in ipairs(obsoletos) do
            bancoDados.linkedBarrels[idConstrucao][k] = nil
        end
        local _anyRemain = false
        for _ in pairs(bancoDados.linkedBarrels[idConstrucao]) do _anyRemain = true; break end
        if not _anyRemain then
            bancoDados.linkedBarrels[idConstrucao] = nil
        end
        SalvarBancoDadosBarris(bancoDados)
    end

    return resultado
end

-- ============================================================================
-- AUTO-ABASTECIMENTO
-- ============================================================================

--- Executa o abastecimento automático de combustível a partir dos barris acoplados aos geradores vinculados.
--- @param dadosConstrucao table Os dados da construção lógica.
function Barrels.AutoRefuel(dadosConstrucao)
    if not dadosConstrucao then return end
    if not dadosConstrucao.connectedGenerators
       or LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(dadosConstrucao.connectedGenerators) then return end

    local barrels = Barrels.GetLinkedBarrels(dadosConstrucao.id)
    if #barrels == 0 then return end

    local GerenciadorEnergia = LKS_EletricidadeConstrucao and LKS_EletricidadeConstrucao.Power and LKS_EletricidadeConstrucao.Power.Manager
    if not GerenciadorEnergia then return end

    local geradores = {}
    local combustivelNecessario = 0

    for _, chaveGerador in pairs(dadosConstrucao.connectedGenerators) do
        local posicaoX, posicaoY, posicaoZ = string.match(chaveGerador, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
        if posicaoX then
            local gerador = GerenciadorEnergia.GetGeneratorAt(tonumber(posicaoX), tonumber(posicaoY), tonumber(posicaoZ))
            if gerador then
                local maxFuel = gerador:getMaxFuel()
                local curFuel = gerador:getFuel()
                local necessario = maxFuel - curFuel
                if necessario > 0.01 then
                    table.insert(geradores, {gen=gerador, needed=necessario})
                    combustivelNecessario = combustivelNecessario + necessario
                end
            end
        end
    end

    if combustivelNecessario <= 0 or #geradores == 0 then return end

    -- Drena dos barris acoplados até sanar a necessidade total da fiação
    local combustivelRetirado = 0
    for _, barril in ipairs(barrels) do
        if combustivelRetirado >= combustivelNecessario then break end
        local retirar = math.min(Barrels.GetPetrolAmount(barril), combustivelNecessario - combustivelRetirado)
        local real = Barrels.RemoveFuel(barril, retirar)
        combustivelRetirado = combustivelRetirado + real
    end

    if combustivelRetirado <= 0 then return end

    -- Distribui proporcionalmente entre os geradores conectados
    for _, entrada in ipairs(geradores) do
        local parcela = combustivelRetirado * (entrada.needed / combustivelNecessario)
        local cur = entrada.gen:getFuel()
        entrada.gen:setFuel(cur + parcela)
        if LKS_EletricidadeConstrucao.Core.Runtime.RequiresNetworkSync() then
            entrada.gen:transmitModData()
        end
    end

    Logger.Info("Fuel.Barrels", string.format(
        "Abastecimento automático da construção %s: retirados %.1f L de %d barris para %d geradores",
        tostring(dadosConstrucao.id), combustivelRetirado, #barrels, #geradores))
end

--- Executa a rotina de reabastecimento automático em todas as construções cadastradas.
function Barrels.UpdateAll()
    local SM = LKS_EletricidadeConstrucao.Core.StateManager
    if not SM then return end
    local buildings = SM.GetAllBuildings()
    if not buildings then return end
    
    for _, bd in pairs(buildings) do
        if bd.connectedGenerators and not LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(bd.connectedGenerators) then
            Barrels.AutoRefuel(bd)
        end
    end
end

-- ============================================================================
-- REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Fuel.Barrels", "2.0.0")

return Barrels
