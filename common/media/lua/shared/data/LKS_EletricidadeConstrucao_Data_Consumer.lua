-- ============================================================================
-- 🌟 LKS SUPERMOD PATCH — CRÉDITOS & AGRADECIMENTOS 🌟
-- ============================================================================
-- 💖 Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- 🛠️ Mod Original: Generator Powered Buildings (ID Workshop: 3597471949)
-- 👤 Autor Original: Beathoven
-- 🌐 Link: https://steamcommunity.com/sharedfiles/filedetails/?id=3597471949
-- 
-- Este mod só é possível graças a todos os modders que vieram antes de mi.
-- Um agradecimento especial ao autor por sua contribuição incrível à comunidade!
-- ============================================================================

-- ARQUIVO: LKS_EletricidadeConstrucao_Data_Consumer.lua
-- OBJETIVO: Modelo de dados (Schema) e operações para Consumidores de Energia (luzes, eletrodomésticos, etc.)
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace existe antes de carregar o módulo
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Data_Consumer] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- ============================================================================
-- DEFINIÇÃO DO SCHEMA
-- ============================================================================

--- Schema de dados de um Consumidor de Energia.
--- @class ConsumerData
--- @field squareX number Coordenada X do quadrado (tile) na grade do mundo
--- @field squareY number Coordenada Y do quadrado (tile) na grade do mundo
--- @field squareZ number Coordenada Z do quadrado (tile) na grade do mundo
--- @field objectType string Tipo do consumidor ("light", "appliance", "lamp", etc.)
--- @field applianceType string|nil Subtipo específico do eletrodoméstico ("fridge", "tv", "radio", "stove", "washer", "dryer", "freezer", "microwave")
--- @field isActive boolean Estado de atividade atual (ligado/desligado)
--- @field powerDraw number Consumo elétrico do consumidor (para cálculo de esforço/strain)
--- @field fuelConsumptionLph number Taxa de consumo de combustível em L/h (específico do vanilla)
--- @field objectIndex number|nil Índice do objeto físico no quadrado do grid (para múltiplos objetos)
--- @field sprite string|nil Nome do sprite de identificação visual do objeto

local ConsumerSchema = {
    squareX = 0,
    squareY = 0,
    squareZ = 0,
    objectType = "light",
    applianceType = nil,
    isActive = false,
    powerDraw = 1,
    fuelConsumptionLph = 0.002,
    objectIndex = nil,
    sprite = nil
}

-- ============================================================================
-- TIPOS DE CONSUMIDORES
-- ============================================================================

LKS_EletricidadeConstrucao.Data.Consumer.Types = {
    LIGHT = "light",
    LAMP = "lamp",
    APPLIANCE = "appliance",
    UNKNOWN = "unknown"
}

-- ============================================================================
-- CONSTRUTOR
-- ============================================================================

--- Cria uma nova instância de dados de um consumidor (ConsumerData) em um determinado quadrado.
--- @param quadrado IsoGridSquare O quadrado da grade contendo o consumidor.
--- @param tipoObjeto string O tipo do consumidor elétrico.
--- @param indiceObjeto number|nil O índice do objeto no quadrado (opcional).
--- @return ConsumerData A nova instância populada com o estado do consumidor.
function LKS_EletricidadeConstrucao.Data.Consumer.New(quadrado, tipoObjeto, indiceObjeto)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    
    -- Validação de entrada
    Validation.AssertNotNil(quadrado, "O quadrado do grid não pode ser nulo")
    Validation.Assert(Validation.IsGridSquare(quadrado), "O objeto fornecido deve ser do tipo IsoGridSquare")
    
    -- Clona a estrutura do Schema
    local dadosConsumidor = Table.DeepCopy(ConsumerSchema)
    
    -- Define coordenadas do quadrado
    dadosConsumidor.squareX = quadrado:getX()
    dadosConsumidor.squareY = quadrado:getY()
    dadosConsumidor.squareZ = quadrado:getZ()
    
    -- Define tipo de objeto
    dadosConsumidor.objectType = tipoObjeto or LKS_EletricidadeConstrucao.Data.Consumer.Types.UNKNOWN
    
    -- Define índice do objeto
    dadosConsumidor.objectIndex = indiceObjeto
    
    -- Detecta estado operacional inicial e calcula o consumo elétrico
    LKS_EletricidadeConstrucao.Data.Consumer.UpdateFromSquare(dadosConsumidor, quadrado)
    
    return dadosConsumidor
end

-- ============================================================================
-- VALIDAÇÃO DE INTEGRIDADE
-- ============================================================================

--- Valida se a estrutura de dados de um consumidor está correta e com valores válidos.
--- @param dadosConsumidor ConsumerData A tabela de dados do consumidor.
--- @return boolean, string|nil Retorna true se estiver correto, ou false com a mensagem descritiva do erro.
function LKS_EletricidadeConstrucao.Data.Consumer.Validate(dadosConsumidor)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    -- Verifica se é do tipo tabela
    if not Validation.IsTable(dadosConsumidor) then
        return false, "Os dados do consumidor devem estar estruturados em uma tabela"
    end
    
    -- Valida chaves obrigatórias requeridas pelo Schema
    local valido, erro = Validation.ValidateKeys(dadosConsumidor, {
        "squareX", "squareY", "squareZ", "objectType", 
        "isActive", "powerDraw"
    }, "Dados do consumidor")
    
    if not valido then
        return false, erro
    end
    
    -- Valida se as coordenadas são numéricas e geográficas
    valido, erro = Validation.ValidateCoordinates(dadosConsumidor.squareX, dadosConsumidor.squareY, dadosConsumidor.squareZ)
    if not valido then
        return false, erro
    end
    
    -- Valida formato do tipo de objeto
    valido, erro = Validation.ValidateNotEmpty(dadosConsumidor.objectType, "objectType")
    if not valido then
        return false, erro
    end
    
    -- Valida tipo do estado ativo
    if not Validation.IsBoolean(dadosConsumidor.isActive) then
        return false, "O campo 'isActive' deve ser um booleano"
    end
    
    -- Valida se a potência elétrica desenhada não é negativa
    valido, erro = Validation.ValidateNonNegative(dadosConsumidor.powerDraw, "powerDraw")
    if not valido then
        return false, erro
    end
    
    return true, nil
end

-- ============================================================================
-- SERIALIZAÇÃO E DESSERIALIZAÇÃO (PERSISTÊNCIA MODDATA)
-- ============================================================================

--- Serializa os dados do consumidor em um formato de tabela limpa para armazenamento no ModData.
--- @param dadosConsumidor ConsumerData A estrutura de dados do consumidor.
--- @return table Uma cópia limpa e serializável dos dados do consumidor.
function LKS_EletricidadeConstrucao.Data.Consumer.Serialize(dadosConsumidor)
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    return Table.DeepCopy(dadosConsumidor)
end

--- Desserializa a estrutura de dados de um consumidor a partir dos dados lidos do ModData.
--- @param dadosSerializados table Tabela de dados brutos carregados do ModData.
--- @return ConsumerData|nil Retorna os dados desserializados ou nil se for inválido.
function LKS_EletricidadeConstrucao.Data.Consumer.Deserialize(dadosSerializados)
    if not dadosSerializados then
        return nil
    end
    
    local Table = LKS_EletricidadeConstrucao.Utils.Table
    local dadosConsumidor = Table.DeepCopy(dadosSerializados)
    
    -- Realiza validação final dos dados carregados
    local valido, erro = LKS_EletricidadeConstrucao.Data.Consumer.Validate(dadosConsumidor)
    if not valido then
        LKS_EletricidadeConstrucao.Error("[Consumer.Deserialize] Dados do consumidor invalidos: " .. erro)
        return nil
    end
    
    return dadosConsumidor
end

-- ============================================================================
-- OPERAÇÕES DE ATUALIZAÇÃO E DETECÇÃO DE ESTADO FÍSICO
-- ============================================================================

--- Detecta se o eletrodoméstico está ligado fisicamente avaliando os objetos Java no grid.
--- Ignora validações de fornecimento de energia (ligado/desligado geral do prédio) para obter o estado definido pelo jogador.
--- @param quadrado IsoGridSquare O quadrado de grade onde o consumidor está instalado.
--- @return boolean Retorna true se o eletrodoméstico reconhecido estiver ligado.
function LKS_EletricidadeConstrucao.Data.Consumer.GetApplianceStateFromSquare(quadrado)
    if not quadrado then
        return false
    end
    local listaObjetos = quadrado:getObjects()
    if not listaObjetos then
        return false
    end
    for indice = 0, listaObjetos:size() - 1 do
        local objetoGrid = listaObjetos:get(indice)
        if objetoGrid then
            -- Televisões e rádios (interoperabilidade com IsoTelevision / IsoRadio)
            if instanceof(objetoGrid, "IsoTelevision") or instanceof(objetoGrid, "IsoRadio") then
                if objetoGrid.getDeviceData then
                    local dadosDispositivo = objetoGrid:getDeviceData()
                    if dadosDispositivo and dadosDispositivo.getIsTurnedOn then
                        return dadosDispositivo:getIsTurnedOn()
                    end
                end
                return false
            end
            -- Fogões (IsoStove)
            if instanceof(objetoGrid, "IsoStove") then
                return objetoGrid.Activated and objetoGrid:Activated() or false
            end
            -- Lavadoras e secadoras portáteis (moveable)
            if instanceof(objetoGrid, "IsoClothingDryer")
            or instanceof(objetoGrid, "IsoClothingWasher")
            or instanceof(objetoGrid, "IsoCombinationWasherDryer")
            or instanceof(objetoGrid, "IsoStackedWasherDryer") then
                return objetoGrid.isActivated and objetoGrid:isActivated() or false
            end
            -- Contêineres de eletrodomésticos nativos do mundo (geladeiras, secadoras, lavadoras)
            if objetoGrid.getContainerByType then
                if objetoGrid:getContainerByType("clothingdryer")  ~= nil
                or objetoGrid:getContainerByType("clothingwasher") ~= nil then
                    return objetoGrid.isActivated and objetoGrid:isActivated() or false
                end
                if objetoGrid:getContainerByType("fridge")   ~= nil
                or objetoGrid:getContainerByType("freezer")  ~= nil then
                    return true   -- Geladeiras/freezers sempre consomem energia quando há energia disponível
                end
            end
        end
    end
    return false   -- Eletrodomésticos desconhecidos ou puramente estéticos (sprites): inativos por padrão
end

--- Sincroniza e atualiza o estado operacional e de consumo do dispositivo a partir de seu quadrado físico.
--- @param dadosConsumidor ConsumerData A tabela contendo os dados locais do consumidor.
--- @param quadrado IsoGridSquare O quadrado físico no grid do mapa.
function LKS_EletricidadeConstrucao.Data.Consumer.UpdateFromSquare(dadosConsumidor, quadrado)
    local Validation = LKS_EletricidadeConstrucao.Utils.Validation
    
    Validation.AssertNotNil(quadrado, "O quadrado físico não pode ser nulo")
    
    -- Nota técnica: square:haveElectricity() avalia o grid de energia nativo (vanilla).
    -- Este mod gerencia sua própria malha de fornecimento. Derivamos a ativação:
    --   • Eletrodomésticos: avalia o estado real ligado/desligado definido no objeto físico.
    --   • Luzes/Lâmpadas: assume ativas por padrão. O distribuidor ajusta após avaliar interruptores.
    if dadosConsumidor.objectType == LKS_EletricidadeConstrucao.Data.Consumer.Types.APPLIANCE then
        dadosConsumidor.isActive = LKS_EletricidadeConstrucao.Data.Consumer.GetApplianceStateFromSquare(quadrado)
    else
        dadosConsumidor.isActive = true   -- Assume ativa até validação com interruptor (UpdateBuildingPower)
    end
    
    -- Recalcula a demanda de carga com base nas configurações
    dadosConsumidor.powerDraw = LKS_EletricidadeConstrucao.Data.Consumer.CalculatePowerDraw(dadosConsumidor, quadrado)
end

--- Calcula o consumo elétrico desenhado pelo consumidor de acordo com o seu tipo.
--- @param dadosConsumidor ConsumerData Os dados do consumidor.
--- @param quadrado IsoGridSquare|nil O quadrado físico de grade (opcional).
--- @return number O consumo elétrico correspondente do dispositivo.
function LKS_EletricidadeConstrucao.Data.Consumer.CalculatePowerDraw(dadosConsumidor, quadrado)
    local Constants = LKS_EletricidadeConstrucao.Constants.FUEL
    
    -- Consumo elétrico base por tipo
    if dadosConsumidor.objectType == LKS_EletricidadeConstrucao.Data.Consumer.Types.LIGHT then
        return Constants.POWER_DRAW_LIGHT or 1
    elseif dadosConsumidor.objectType == LKS_EletricidadeConstrucao.Data.Consumer.Types.LAMP then
        return Constants.POWER_DRAW_LAMP or 1
    elseif dadosConsumidor.objectType == LKS_EletricidadeConstrucao.Data.Consumer.Types.APPLIANCE then
        -- Valida se existe um subtipo de eletrodoméstico específico configurado
        if dadosConsumidor.applianceType then
            local tipo = dadosConsumidor.applianceType
            if tipo == "fridge" then
                return Constants.POWER_DRAW_FRIDGE or 10
            elseif tipo == "freezer" then
                return Constants.POWER_DRAW_FREEZER or 10
            elseif tipo == "fridgeFreezer" then
                return Constants.POWER_DRAW_FRIDGE_FREEZER or 15
            elseif tipo == "stove" then
                return Constants.POWER_DRAW_STOVE or 6
            elseif tipo == "microwave" then
                return Constants.POWER_DRAW_MICROWAVE or 5
            elseif tipo == "washer" then
                return Constants.POWER_DRAW_WASHER or 7
            elseif tipo == "dryer" then
                return Constants.POWER_DRAW_DRYER or 7
            elseif tipo == "tv" then
                return Constants.POWER_DRAW_TV or 3
            elseif tipo == "radio" then
                return Constants.POWER_DRAW_RADIO or 2
            end
        end
        -- Consumo padrão para eletrodomésticos genéricos
        return Constants.POWER_DRAW_APPLIANCE or 2
    else
        return 1 -- Fallback padrão
    end
end

-- ============================================================================
-- OPERAÇÕES DE ESTADO
-- ============================================================================

--- Define o estado de ativação operacional do consumidor elétrico.
--- @param dadosConsumidor ConsumerData Os dados do consumidor.
--- @param ativo boolean Retorna true para ligar o consumidor.
function LKS_EletricidadeConstrucao.Data.Consumer.SetActive(dadosConsumidor, ativo)
    dadosConsumidor.isActive = ativo
end

--- Inverte (alterna) o estado operacional ativo atual do consumidor elétrico.
--- @param dadosConsumidor ConsumerData Os dados do consumidor.
function LKS_EletricidadeConstrucao.Data.Consumer.Toggle(dadosConsumidor)
    dadosConsumidor.isActive = not dadosConsumidor.isActive
end

-- ============================================================================
-- DETECÇÃO E VARREDURA DE TIPOS
-- ============================================================================

--- Detecta o tipo de consumidor elétrico instalado em um quadrado de grade do mapa.
--- @param quadrado IsoGridSquare O quadrado a ser inspecionado.
--- @return string O tipo de consumidor identificado.
function LKS_EletricidadeConstrucao.Data.Consumer.DetectType(quadrado)
    if not quadrado then
        return LKS_EletricidadeConstrucao.Data.Consumer.Types.UNKNOWN
    end
    
    -- Procura por objetos de luminárias portáteis (lâmpadas/abajures)
    local listaObjetos = quadrado:getObjects()
    if listaObjetos then
        for indice = 0, listaObjetos:size() - 1 do
            local objetoGrid = listaObjetos:get(indice)
            if objetoGrid then
                local sprite = objetoGrid:getSprite()
                if sprite then
                    local nomeSprite = sprite:getName()
                    if nomeSprite and nomeSprite:contains("lamp") then
                        return LKS_EletricidadeConstrucao.Data.Consumer.Types.LAMP
                    end
                end
            end
        end
    end
    
    -- Verifica se o quadrado suporta iluminação nativa de teto
    if quadrado:canHaveLight() then
        return LKS_EletricidadeConstrucao.Data.Consumer.Types.LIGHT
    end
    
    -- Fallback padrão: iluminação comum
    return LKS_EletricidadeConstrucao.Data.Consumer.Types.LIGHT
end

-- ============================================================================
-- COMPARAÇÕES E IDENTIFICAÇÃO ÚNICA
-- ============================================================================

--- Verifica se dois consumidores compartilham a mesma posição geográfica e índice no grid.
--- @param consumidor1 ConsumerData O primeiro consumidor.
--- @param consumidor2 ConsumerData O segundo consumidor.
--- @return boolean Retorna true se forem o mesmo dispositivo físico.
function LKS_EletricidadeConstrucao.Data.Consumer.IsSame(consumidor1, consumidor2)
    return consumidor1.squareX == consumidor2.squareX
        and consumidor1.squareY == consumidor2.squareY
        and consumidor1.squareZ == consumidor2.squareZ
        and consumidor1.objectIndex == consumidor2.objectIndex
end

--- Gera uma chave descritiva única de texto para indexação do consumidor elétrico.
--- @param dadosConsumidor ConsumerData Os dados do consumidor.
--- @return string A chave única gerada.
function LKS_EletricidadeConstrucao.Data.Consumer.MakeKey(dadosConsumidor)
    if dadosConsumidor.objectIndex then
        return string.format("%d_%d_%d_%d", 
            dadosConsumidor.squareX, dadosConsumidor.squareY, dadosConsumidor.squareZ, dadosConsumidor.objectIndex)
    else
        return string.format("%d_%d_%d", 
            dadosConsumidor.squareX, dadosConsumidor.squareY, dadosConsumidor.squareZ)
    end
end

-- ============================================================================
-- INTEROPERABILIDADE COM O MAPA (GRID SQUARE)
-- ============================================================================

--- Obtém o quadrado da grade física do mapa associado ao consumidor elétrico.
--- @param dadosConsumidor ConsumerData Os dados do consumidor.
--- @return IsoGridSquare|nil O quadrado físico IsoGridSquare ou nulo se descarregado.
function LKS_EletricidadeConstrucao.Data.Consumer.GetSquare(dadosConsumidor)
    return getSquare(dadosConsumidor.squareX, dadosConsumidor.squareY, dadosConsumidor.squareZ)
end

--- Verifica se o consumidor está atualmente em um quadrado físico carregado na memória do jogo.
--- @param dadosConsumidor ConsumerData Os dados do consumidor.
--- @return boolean Retorna true se o quadrado estiver carregado e acessível.
function LKS_EletricidadeConstrucao.Data.Consumer.IsValid(dadosConsumidor)
    local quadrado = LKS_EletricidadeConstrucao.Data.Consumer.GetSquare(dadosConsumidor)
    return quadrado ~= nil
end

--- Obtém a demanda real instantânea de consumo elétrico do consumidor (retorna zero se inativo).
--- @param dadosConsumidor ConsumerData Os dados do consumidor.
--- @return number O consumo elétrico instantâneo correspondente.
function LKS_EletricidadeConstrucao.Data.Consumer.GetCurrentPower(dadosConsumidor)
    if dadosConsumidor.isActive then
        return dadosConsumidor.powerDraw
    else
        return 0
    end
end

-- ============================================================================
-- DEPURAÇÃO
-- ============================================================================

--- Converte o estado operacional do consumidor em uma string descritiva formatada.
--- @param dadosConsumidor ConsumerData Os dados do consumidor analisado.
--- @return string Representação descritiva.
function LKS_EletricidadeConstrucao.Data.Consumer.ToString(dadosConsumidor)
    local textoIndice = dadosConsumidor.objectIndex and string.format("[%d]", dadosConsumidor.objectIndex) or ""
    
    return string.format(
        "Consumidor%s em (%d,%d,%d) | Tipo:%s Ativo:%s Carga:%.1f",
        textoIndice,
        dadosConsumidor.squareX, dadosConsumidor.squareY, dadosConsumidor.squareZ,
        dadosConsumidor.objectType,
        tostring(dadosConsumidor.isActive),
        dadosConsumidor.powerDraw
    )
end

-- ============================================================================
-- INICIALIZAÇÃO E REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Data.Consumer", "2.0.0")

return LKS_EletricidadeConstrucao.Data.Consumer
