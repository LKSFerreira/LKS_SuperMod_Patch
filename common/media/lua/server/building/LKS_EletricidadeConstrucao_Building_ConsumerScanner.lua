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

-- ARQUIVO: LKS_EletricidadeConstrucao_Building_ConsumerScanner.lua
-- OBJETIVO: Escaneia as construções físicas para registrar consumidores de energia (luzes, luminárias e aparelhos).
-- LOCALIZAÇÃO: server/building

if not LKS_EletricidadeConstrucao then
    print("[LKS PATCH - LKS_EletricidadeConstrucao_Building_ConsumerScanner.lua] Namespace LKS_EletricidadeConstrucao não encontrado - pulando carregamento do módulo")
    return
end

LKS_EletricidadeConstrucao.Building = LKS_EletricidadeConstrucao.Building or {}
LKS_EletricidadeConstrucao.Building.ConsumerScanner = LKS_EletricidadeConstrucao.Building.ConsumerScanner or {}

-- ============================================================================
-- DETECÇÃO DE CONSUMIDORES
-- ============================================================================

--- Escaneia a construção física em busca de consumidores de energia.
--- @param dadosConstrucao table Os dados da construção no StateManager.
--- @param quadradosBorda table A lista de quadrados pertencentes à construção.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.ScanConsumers(dadosConstrucao, quadradosBorda)
    if not dadosConstrucao then
        LKS_EletricidadeConstrucao.Core.Logger.Error("Dados da construção vazios (nil)", "Building")
        return
    end
    
    if not quadradosBorda or #quadradosBorda == 0 then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("Nenhum quadrado de borda para a construção %s", dadosConstrucao.id),
            "Building"
        )
        return
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.StartTimer("ConsumerScan")
    
    local todosQuadrados = quadradosBorda
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Escaneando %d quadrados por consumidores (em múltiplos níveis Z)", #todosQuadrados),
        "Building"
    )
    
    local totalLuzes = 0
    local totalLuminarias = 0
    local totalDispositivos = 0
    local candidatosDispositivos = {}
    local quadradoAncora = getSquare(dadosConstrucao.x, dadosConstrucao.y, dadosConstrucao.z or 0)
    local construcaoAncora = quadradoAncora and quadradoAncora:getBuilding() or nil

    local function IsQuadradoDeOutraConstrucao(quadrado)
        if not quadrado or not construcaoAncora then
            return false
        end

        local construcaoQuadrado = quadrado:getBuilding()
        return construcaoQuadrado ~= nil and construcaoQuadrado ~= construcaoAncora
    end
    
    local quadradosEscaneados = {}
    
    -- Coleta o anel perimetral de um bloco ao redor do interior para capturar lâmpadas/luzes externas
    local function ColetarQuadradosPerimetro(interior)
        local resultado = {}
        local vistos = {}
        local direcoes = {
            {x = 1,  y = 0}, {x = -1, y = 0},
            {x = 0,  y = 1}, {x = 0,  y = -1}
        }
        for _, tile in ipairs(interior) do
            for _, d in ipairs(direcoes) do
                local posicaoX = tile.x + d.x
                local posicaoY = tile.y + d.y
                local chave = posicaoX .. "_" .. posicaoY .. "_" .. tile.z
                if not vistos[chave] then
                    vistos[chave] = true
                    table.insert(resultado, {x = posicaoX, y = posicaoY, z = tile.z})
                end
            end
        end
        return resultado
    end

    -- Varre cada bloco em busca de objetos
    for _, tile in ipairs(todosQuadrados) do
        local quadrado = getSquare(tile.x, tile.y, tile.z)
        
        if quadrado and not IsQuadradoDeOutraConstrucao(quadrado) then
            local squareKey = tile.x .. "_" .. tile.y .. "_" .. tile.z
            quadradosEscaneados[squareKey] = true
            
            local objetos = quadrado:getObjects()
            if objetos then
                for i = 0, objetos:size() - 1 do
                    local objeto = objetos:get(i)
                    if objeto then
                        local tipoConsumidor = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerType(objeto)
                        if tipoConsumidor then
                            local dadosConsumidor = LKS_EletricidadeConstrucao.Data.Consumer.New(quadrado, tipoConsumidor)
                            
                            local Constants = LKS_EletricidadeConstrucao.Constants.FUEL
                            local taxaCombustivelBase = Constants.CONSUMPTION_APPLIANCE_DEFAULT_LPH
                            
                            if tipoConsumidor == "light" or tipoConsumidor == "lamp" then
                                taxaCombustivelBase = Constants.CONSUMPTION_LIGHT_LPH
                                dadosConsumidor.applianceType = nil
                            elseif tipoConsumidor == "appliance" then
                                local tipoDispositivo, taxaCombustivel = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceDetails(objeto)
                                dadosConsumidor.applianceType = tipoDispositivo
                                taxaCombustivelBase = taxaCombustivel
                                
                                dadosConsumidor.powerDraw = LKS_EletricidadeConstrucao.Data.Consumer.CalculatePowerDraw(dadosConsumidor, quadrado)
                                
                                LKS_EletricidadeConstrucao.Core.Logger.Debug(
                                    string.format("Dispositivo elétrico detectado: tipo=%s, consumoEnergia=%.1f, sprite=%s",
                                        tostring(tipoDispositivo or "NENHUM"),
                                        dadosConsumidor.powerDraw,
                                        objeto:getSprite() and objeto:getSprite():getName() or "unknown"),
                                    "Building")
                            end
                            
                            local multiplicadorSandbox = 1.0
                            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier then
                                multiplicadorSandbox = LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier()
                            end
                            dadosConsumidor.fuelConsumptionLph = taxaCombustivelBase * multiplicadorSandbox
                            
                            LKS_EletricidadeConstrucao.Data.Building.AddConsumer(dadosConstrucao, dadosConsumidor)
                            
                            if tipoConsumidor == "light" then
                                totalLuzes = totalLuzes + 1
                            elseif tipoConsumidor == "lamp" then
                                totalLuminarias = totalLuminarias + 1
                            elseif tipoConsumidor == "appliance" then
                                totalDispositivos = totalDispositivos + 1
                            end
                        else
                            local candidato = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceCandidateTag(objeto)
                            if candidato then table.insert(candidatosDispositivos, candidato) end
                        end
                    end
                end
            end
        end
    end

    -- Varre a borda perimetral externa de segurança
    local quadradosPerimetro = ColetarQuadradosPerimetro(todosQuadrados)
    for _, tile in ipairs(quadradosPerimetro) do
        local squareKey = tile.x .. "_" .. tile.y .. "_" .. tile.z
        if not quadradosEscaneados[squareKey] then
            quadradosEscaneados[squareKey] = true
            
            local quadrado = getSquare(tile.x, tile.y, tile.z)
            if quadrado and not IsQuadradoDeOutraConstrucao(quadrado) then
                local objetos = quadrado:getObjects()
                if objetos then
                    for i = 0, objetos:size() - 1 do
                        local objeto = objetos:get(i)
                        if objeto then
                            local tipoConsumidor = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerType(objeto)
                            if tipoConsumidor == "light" or tipoConsumidor == "lamp" then
                                local dadosConsumidor = LKS_EletricidadeConstrucao.Data.Consumer.New(quadrado, tipoConsumidor)
                                
                                local taxaCombustivelBase = LKS_EletricidadeConstrucao.Constants.FUEL.CONSUMPTION_LIGHT_LPH
                                local multiplicadorSandbox = 1.0
                                if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier then
                                    multiplicadorSandbox = LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier()
                                end
                                
                                dadosConsumidor.fuelConsumptionLph = taxaCombustivelBase * multiplicadorSandbox
                                dadosConsumidor.applianceType = nil
                                LKS_EletricidadeConstrucao.Data.Building.AddConsumer(dadosConstrucao, dadosConsumidor)
                                if tipoConsumidor == "light" then
                                    totalLuzes = totalLuzes + 1
                                elseif tipoConsumidor == "lamp" then
                                    totalLuminarias = totalLuminarias + 1
                                end
                            else
                                local candidato = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceCandidateTag(objeto)
                                if candidato then table.insert(candidatosDispositivos, candidato) end
                            end
                        end
                    end
                end
            end
        end
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.EndTimer("ConsumerScan", 100)
    
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("Consumidores encontrados na construção %s: %d luzes, %d luminárias, %d aparelhos",
            dadosConstrucao.id, totalLuzes, totalLuminarias, totalDispositivos),
        "Building"
    )

    if totalDispositivos == 0 and #candidatosDispositivos > 0 then
        local vistos = {}
        local unicos = {}
        for _, tag in ipairs(candidatosDispositivos) do
            if not vistos[tag] then
                vistos[tag] = true
                table.insert(unicos, tag)
            end
        end
        LKS_EletricidadeConstrucao.Core.Logger.Info(
            string.format("Candidatos a dispositivos encontrados (não contabilizados): %s", table.concat(unicos, ", ")),
            "Building"
        )
    end
end

--- Reescreve e rescaneia cômodos elétricos de uma construção existente (após modificações físicas no mundo).
--- @param dadosConstrucao table Os dados da construção no StateManager.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.RescanConsumers(dadosConstrucao)
    if not dadosConstrucao then
        LKS_EletricidadeConstrucao.Core.Logger.Error("ReescanearConsumidores: dadosConstrucao é nulo (nil)", "Building")
        return
    end

    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("ReescanearConsumidores para a construção %s", dadosConstrucao.id),
        "Building"
    )

    local raioVarredura = dadosConstrucao.borderRadius
    local bldId = dadosConstrucao.id or ""
    if string.match(bldId, "^bld_%-?%d+_%-?%d+_%-?%d+$") then
        if dadosConstrucao.boundingBox then
            local bb = dadosConstrucao.boundingBox
            local metadeLargura = math.ceil((bb.maxX - bb.minX) / 2) + 3
            local metadeAltura = math.ceil((bb.maxY - bb.minY) / 2) + 3
            raioVarredura = math.max(metadeLargura, metadeAltura, raioVarredura or 2)
        else
            raioVarredura = math.max(raioVarredura or 2, 30)
        end
    end

    local quadradosBorda = LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBorders(
        dadosConstrucao.x,
        dadosConstrucao.y,
        dadosConstrucao.z,
        raioVarredura,
        dadosConstrucao.id
    )

    if not quadradosBorda or #quadradosBorda == 0 then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("ReescanearConsumidores: sem quadrados de borda para a construção %s", dadosConstrucao.id),
            "Building"
        )
        return
    end

    local Scanner = LKS_EletricidadeConstrucao.Building.Scanner
    local possuiExistentes = false
    if dadosConstrucao.powerConsumers then
        for _ in pairs(dadosConstrucao.powerConsumers) do possuiExistentes = true; break end
    end
    
    if possuiExistentes and Scanner and Scanner.IsBuildingAreaLoaded
       and not Scanner.IsBuildingAreaLoaded(dadosConstrucao) then
        LKS_EletricidadeConstrucao.Core.Logger.Info(
            string.format("ReescanearConsumidores: carregamento parcial de chunk para %s – preservando consumidores existentes",
                dadosConstrucao.id),
            "Building")
        return
    end

    -- Limpa lista antiga para reinserção atualizada
    LKS_EletricidadeConstrucao.Data.Building.ClearConsumers(dadosConstrucao)

    LKS_EletricidadeConstrucao.Building.ConsumerScanner.ScanConsumers(dadosConstrucao, quadradosBorda)

    -- Recalcula consumo elétrico consolidado
    LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(dadosConstrucao)

    LKS_EletricidadeConstrucao.Core.StateManager.AddBuilding(dadosConstrucao)

    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("ReescanearConsumidores concluído para a construção %s: %d consumidores, consumo de %.1f",
            dadosConstrucao.id, #dadosConstrucao.powerConsumers, dadosConstrucao.totalPowerDraw or 0),
        "Building"
    )
end

--- Retorna a classificação de tipo de consumidor elétrico de um IsoObject.
--- @param object any O objeto físico no mundo.
--- @return string|nil O tipo ("light", "lamp", "appliance") ou nil.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerType(object)
    if not object then
        return nil
    end
    
    if instanceof(object, "IsoLight") then
        return "light"
    end
    
    if instanceof(object, "IsoLightSwitch") then
        return "light"
    end
    
    local sprite = object:getSprite()
    if sprite then
        local spriteName = sprite:getName()
        if spriteName then
            local nomeMinusculo = string.lower(spriteName)
            
            if (string.find(nomeMinusculo, "lights_") or
                string.find(nomeMinusculo, "fluorescent") or
                string.find(nomeMinusculo, "ceiling_light") or
                string.find(nomeMinusculo, "wall_light") or
                string.find(nomeMinusculo, "streetlight")) and
               not string.find(nomeMinusculo, "switch") and
               not string.find(nomeMinusculo, "lighter") and
               not string.find(nomeMinusculo, "flashlight") then
                return "light"
            end
            
            if string.find(nomeMinusculo, "lamp") or
               string.find(nomeMinusculo, "lighting") or
               string.find(nomeMinusculo, "floorlamp") or
               string.find(nomeMinusculo, "desklamp") or
               string.find(nomeMinusculo, "tablelamp") then
                return "lamp"
            end
        end
    end
    
    if LKS_EletricidadeConstrucao.Building.ConsumerScanner.IsAppliance(object) then
        return "appliance"
    end
    
    return nil
end

--- Verifica se o objeto físico é classificado como um eletrodoméstico/aparelho consumidor.
--- @param object any O objeto do mundo.
--- @return boolean Retorna true se for um aparelho.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.IsAppliance(object)
    if not object then
        return false
    end

    if instanceof(object, "IsoLight") or instanceof(object, "IsoLightSwitch") then
        return false
    end
    
    if instanceof(object, "IsoStove") or
       instanceof(object, "IsoRadio") or
       instanceof(object, "IsoTelevision") or
       instanceof(object, "IsoClothingDryer") or
       instanceof(object, "IsoClothingWasher") or
       instanceof(object, "IsoCombinationWasherDryer") or
       instanceof(object, "IsoStackedWasherDryer") then
        return true
    end

    if object.getContainerByType then
        if object:getContainerByType("fridge")        ~= nil
        or object:getContainerByType("freezer")       ~= nil
        or object:getContainerByType("clothingdryer") ~= nil
        or object:getContainerByType("clothingwasher") ~= nil then
            return true
        end
    end
    
    local sprite = object:getSprite()
    if sprite then
        local spriteName = sprite:getName()
        if spriteName then
            local nomeMinusculo = string.lower(spriteName)
            
            if string.find(nomeMinusculo, "fridge") or
               string.find(nomeMinusculo, "freezer") or
               string.find(nomeMinusculo, "microwave") or
               string.find(nomeMinusculo, "oven") or
               string.find(nomeMinusculo, "stove") or
               string.find(nomeMinusculo, "television") or
               string.find(nomeMinusculo, "radio") or
               string.find(nomeMinusculo, "washer") or
               string.find(nomeMinusculo, "dryer") then
                return true
            end
        end
    end

    if object.getDeviceData then
        local ok, dadosDispositivo = pcall(function() return object:getDeviceData() end)
        if ok and dadosDispositivo then
            return true
        end
    end
    
    return false
end

--- Retorna identificadores e dados internos de objetos suspeitos de serem aparelhos para fins de depuração.
--- @param object any O objeto avaliado.
--- @return string|nil A string descritiva.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceCandidateTag(object)
    if not object then return nil end
    local sprite = object.getSprite and object:getSprite()
    local name = sprite and sprite:getName() or "<no-sprite>"
    if object.getDeviceData and object:getDeviceData() then
        return name .. "[device]"
    end
    if object.setIsPowered then
        return name .. "[powerable]"
    end
    if object.getContainerCount and object:getContainerCount() > 0 then
        return name .. "[container]"
    end
    return nil
end

--- Retorna o consumo padrão de energia de um consumidor genérico.
--- @param dadosConsumidor table Os dados do consumidor.
--- @return number Valor numérico de consumo.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerPowerDraw(dadosConsumidor)
    if not dadosConsumidor then
        return 0
    end
    
    local Constants = LKS_EletricidadeConstrucao.Constants
    
    if dadosConsumidor.objectType == "light" then
        return Constants.FUEL.POWER_DRAW_LIGHT or 1.0
    elseif dadosConsumidor.objectType == "lamp" then
        return Constants.FUEL.POWER_DRAW_LIGHT or 1.0
    elseif dadosConsumidor.objectType == "appliance" then
        return Constants.FUEL.POWER_DRAW_APPLIANCE or 2.0
    end

    return 0
end

--- Retorna os detalhes de um eletrodoméstico específico e sua respectiva taxa de queima/consumo.
--- @param object any O objeto no mundo.
--- @return string|nil tipoDispositivo A chave do tipo.
--- @return number taxaCombustivel O consumo vanilla por hora.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceDetails(object)
    local Constants = LKS_EletricidadeConstrucao.Constants.FUEL
    
    if instanceof(object, "IsoTelevision") then
        return "tv", Constants.CONSUMPTION_TV_LPH
    end
    
    if instanceof(object, "IsoRadio") then
        return "radio", Constants.CONSUMPTION_RADIO_LPH
    end
    
    if instanceof(object, "IsoStove") then
        return "stove", Constants.CONSUMPTION_STOVE_LPH
    end
    
    if instanceof(object, "IsoClothingWasher") or instanceof(object, "IsoStackedWasherDryer") then
        return "washer", Constants.CONSUMPTION_WASHER_LPH
    end
    
    if instanceof(object, "IsoClothingDryer") or instanceof(object, "IsoCombinationWasherDryer") then
        return "dryer", Constants.CONSUMPTION_DRYER_LPH
    end
    
    if object.getContainerByType then
        local possuiGeladeira = object:getContainerByType("fridge") ~= nil
        local possuiCongelador = object:getContainerByType("freezer") ~= nil
        
        if possuiGeladeira and possuiCongelador then
            return "fridgeFreezer", Constants.CONSUMPTION_FRIDGE_FREEZER_LPH
        end
        
        if possuiGeladeira then
            return "fridge", Constants.CONSUMPTION_FRIDGE_LPH
        end
        
        if possuiCongelador then
            return "freezer", Constants.CONSUMPTION_FREEZER_LPH
        end
        
        if object:getContainerByType("clothingwasher") ~= nil then
            return "washer", Constants.CONSUMPTION_WASHER_LPH
        end
        
        if object:getContainerByType("clothingdryer") ~= nil then
            return "dryer", Constants.CONSUMPTION_DRYER_LPH
        end
    end
    
    local sprite = object:getSprite()
    if sprite then
        local spriteName = sprite:getName()
        if spriteName then
            local nomeMinusculo = string.lower(spriteName)
            
            if string.find(nomeMinusculo, "microwave") then
                return "microwave", Constants.CONSUMPTION_MICROWAVE_LPH
            end
            
            if string.find(nomeMinusculo, "fridge") and string.find(nomeMinusculo, "freezer") then
                return "fridgeFreezer", Constants.CONSUMPTION_FRIDGE_FREEZER_LPH
            end
            
            if string.find(nomeMinusculo, "fridge") then
                return "fridge", Constants.CONSUMPTION_FRIDGE_LPH
            end
            
            if string.find(nomeMinusculo, "freezer") or 
               string.find(nomeMinusculo, "appliances_refrigeration") or
               string.find(nomeMinusculo, "commercial_freezer") then
                return "freezer", Constants.CONSUMPTION_FREEZER_LPH
            end
            
            if string.find(nomeMinusculo, "stove") or string.find(nomeMinusculo, "oven") then
                return "stove", Constants.CONSUMPTION_STOVE_LPH
            end
            
            if string.find(nomeMinusculo, "washer") or string.find(nomeMinusculo, "washing") then
                return "washer", Constants.CONSUMPTION_WASHER_LPH
            end
            
            if string.find(nomeMinusculo, "dryer") or string.find(nomeMinusculo, "drying") then
                return "dryer", Constants.CONSUMPTION_DRYER_LPH
            end
            
            LKS_EletricidadeConstrucao.Core.Logger.Debug(
                string.format("Sprite de dispositivo não reconhecido: %s (usando padrão %.3f L/h)",
                    spriteName, Constants.CONSUMPTION_APPLIANCE_DEFAULT_LPH),
                "Building")
        end
    end
    
    return nil, Constants.CONSUMPTION_APPLIANCE_DEFAULT_LPH
end

--- Atualiza o estado físico de consumo elétrico (ativo/inativo) no mundo real.
--- @param dadosConsumidor table O registro lógico do consumidor.
--- @param energizado boolean Status elétrico desejado.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.UpdateConsumerPowerState(dadosConsumidor, energizado)
    if not dadosConsumidor then
        return
    end
    
    local quadrado = getSquare(dadosConsumidor.squareX, dadosConsumidor.squareY, dadosConsumidor.squareZ)
    if not quadrado then
        LKS_EletricidadeConstrucao.Core.Logger.Trace(
            string.format("Quadrado não encontrado para o consumidor em (%d,%d,%d)", 
                dadosConsumidor.squareX, dadosConsumidor.squareY, dadosConsumidor.squareZ),
            "Building"
        )
        return
    end
    
    local objetos = quadrado:getObjects()
    if not objetos then
        return
    end
    
    local tipoObjeto = dadosConsumidor.objectType
    for i = 0, objetos:size() - 1 do
        local objeto = objetos:get(i)
        if objeto then
            local corresponde = false
            if tipoObjeto == "light" then
                corresponde = instanceof(objeto, "IsoLight") or instanceof(objeto, "IsoLightSwitch")
            elseif tipoObjeto == "lamp" then
                if instanceof(objeto, "IsoLight") then
                    corresponde = true
                elseif objeto.setIsPowered ~= nil and not instanceof(objeto, "IsoLightSwitch") and not instanceof(objeto, "IsoLight") then
                    corresponde = true
                end
            elseif tipoObjeto == "appliance" then
                corresponde = LKS_EletricidadeConstrucao.Building.ConsumerScanner.IsAppliance(objeto)
            end

            if corresponde then
                LKS_EletricidadeConstrucao.Building.ConsumerScanner.SetObjectPowerState(objeto, tipoObjeto, energizado)
                break
            end
        end
    end
end

--- Modifica o estado do objeto físico no mundo real de acordo com seu tipo.
--- @param object any O objeto do mundo.
--- @param consumerType string O tipo de consumidor.
--- @param isPowered boolean Status elétrico.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.SetObjectPowerState(object, consumerType, isPowered)
    if not object then
        return
    end
    
    if consumerType == "light" then
        if instanceof(object, "IsoLight") then
            if object.setActive then
                object:setActive(isPowered)
            end
            return
        end
        if instanceof(object, "IsoLightSwitch") then
            return
        end
    elseif consumerType == "lamp" then
        if instanceof(object, "IsoLight") then
            if object.setActive then
                object:setActive(isPowered)
            end
            return
        end
        if instanceof(object, "IsoThumpable") and object.setIsPowered then
            object:setIsPowered(isPowered)
            return
        end
    elseif consumerType == "appliance" then
        if instanceof(object, "IsoThumpable") and object.setIsPowered then
            object:setIsPowered(isPowered)
            return
        end
    end
end

--- Verifica se o consumidor ainda existe fisicamente no quadrado.
--- @param dadosConsumidor table O registro do consumidor.
--- @return boolean Retorna true se continuar existindo.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.ConsumerExists(dadosConsumidor)
    if not dadosConsumidor then
        return false
    end
    
    local quadrado = getSquare(dadosConsumidor.squareX, dadosConsumidor.squareY, dadosConsumidor.squareZ)
    if not quadrado then
        return false
    end
    
    local objetos = quadrado:getObjects()
    if not objetos then
        return false
    end
    
    for i = 0, objetos:size() - 1 do
        local objeto = objetos:get(i)
        if objeto then
            local objetoX = objeto:getX()
            local objetoY = objeto:getY()
            local objetoZ = objeto:getZ()
            
            if objetoX == dadosConsumidor.squareX and objetoY == dadosConsumidor.squareY and objetoZ == dadosConsumidor.squareZ then
                local tipoObjeto = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerType(objeto)
                if tipoObjeto == dadosConsumidor.objectType then
                    return true
                end
            end
        end
    end
    
    return false
end

--- Limpa e remove da construção os consumidores inválidos (deletados ou movidos).
--- @param dadosConstrucao table Os dados da construção.
--- @return number Quantidade de consumidores removidos.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.CleanInvalidConsumers(dadosConstrucao)
    if not dadosConstrucao then
        return 0
    end
    
    local removidos = 0
    local consumidoresValidos = {}

    for _, consumidor in pairs(dadosConstrucao.powerConsumers) do
        if LKS_EletricidadeConstrucao.Building.ConsumerScanner.ConsumerExists(consumidor) then
            table.insert(consumidoresValidos, consumidor)
        else
            LKS_EletricidadeConstrucao.Core.Logger.Debug(
                string.format("Removendo consumidor inválido em (%d,%d,%d) da construção %s",
                    consumidor.squareX, consumidor.squareY, consumidor.squareZ, dadosConstrucao.id),
                "Building"
            )
            removidos = removidos + 1
        end
    end
    
    dadosConstrucao.powerConsumers = consumidoresValidos
    
    if removidos > 0 then
        LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(dadosConstrucao)
    end
    
    return removidos
end

-- ============================================================================
-- DEPURAÇÃO
-- ============================================================================

--- Imprime estatísticas de depuração de consumidores de uma construção específica.
--- @param dadosConstrucao table Os dados da construção.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.PrintConsumers(dadosConstrucao)
    if not dadosConstrucao then
        LKS_EletricidadeConstrucao.Print("Sem dados de construção")
        return
    end
    
    local todos = {}
    local totalContagem = 0
    local luzes = 0
    local luminarias = 0
    local dispositivos = 0
    
    for _, consumidor in pairs(dadosConstrucao.powerConsumers) do
        totalContagem = totalContagem + 1
        table.insert(todos, consumidor)
        if consumidor.objectType == "light" then
            luzes = luzes + 1
        elseif consumidor.objectType == "lamp" then
            luminarias = luminarias + 1
        elseif consumidor.objectType == "appliance" then
            dispositivos = dispositivos + 1
        end
    end

    LKS_EletricidadeConstrucao.Print("=== Consumidores da Construção " .. dadosConstrucao.id .. " ===")
    LKS_EletricidadeConstrucao.Print("Total de Consumidores: " .. totalContagem)
    LKS_EletricidadeConstrucao.Print("Consumo Total de Energia: " .. (dadosConstrucao.totalPowerDraw or 0))
    LKS_EletricidadeConstrucao.Print("Luzes: " .. luzes)
    LKS_EletricidadeConstrucao.Print("Luminárias: " .. luminarias)
    LKS_EletricidadeConstrucao.Print("Aparelhos: " .. dispositivos)

    LKS_EletricidadeConstrucao.Print("\nPrimeiros 10 consumidores:")
    local limite = math.min(10, #todos)
    for i = 1, limite do
        local consumidor = todos[i]
        LKS_EletricidadeConstrucao.Print(string.format("  [%d] %s em (%d,%d,%d) consumo=%.1f",
            i, consumidor.objectType, consumidor.squareX, consumidor.squareY, consumidor.squareZ, consumidor.powerDraw))
    end
    if totalContagem > 10 then
        LKS_EletricidadeConstrucao.Print("  ... " .. (totalContagem - 10) .. " adicionais")
    end
end

-- ============================================================================
-- REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Building.ConsumerScanner", "2.0.0")

return LKS_EletricidadeConstrucao.Building.ConsumerScanner
