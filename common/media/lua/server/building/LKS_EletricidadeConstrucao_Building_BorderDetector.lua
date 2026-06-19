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

-- ARQUIVO: LKS_EletricidadeConstrucao_Building_BorderDetector.lua
-- OBJETIVO: Detecta os limites das construções físicas no mapa usando escaneamento de cômodos e paredes.
-- LOCALIZAÇÃO: server/building

if not LKS_EletricidadeConstrucao then
    print("[LKS PATCH - LKS_EletricidadeConstrucao_Building_BorderDetector.lua] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

LKS_EletricidadeConstrucao.Building = LKS_EletricidadeConstrucao.Building or {}
LKS_EletricidadeConstrucao.Building.BorderDetector = LKS_EletricidadeConstrucao.Building.BorderDetector or {}

-- ============================================================================
-- CONSTANTES
-- ============================================================================

local DIRECOES = {
    {x =  0, y = -1},  -- Norte
    {x =  1, y =  0},  -- Leste
    {x =  0, y =  1},  -- Sul
    {x = -1, y =  0}   -- Oeste
}

-- ============================================================================
-- FUNÇÕES AUXILIARES
-- ============================================================================

--- Verifica se um nível Z específico possui pelo menos um interruptor de luz nos limites do cômodo.
--- @param comodo any O objeto BuildingDef do cômodo.
--- @param coordenadaZ number O nível Z.
--- @return boolean Retorna true se houver pelo menos um interruptor.
local function TemInterruptorDeLuzNoNivel(comodo, coordenadaZ)
    local comodoX1 = comodo:getX() - 2
    local comodoY1 = comodo:getY() - 2
    local comodoX2 = comodo:getX2() + 2
    local comodoY2 = comodo:getY2() + 2
    
    for coordenadaX = comodoX1, comodoX2 do
        for coordenadaY = comodoY1, comodoY2 do
            local quadrado = getSquare(coordenadaX, coordenadaY, coordenadaZ)
            if quadrado then
                local objetos = quadrado:getObjects()
                if objetos then
                    for i = 0, objetos:size() - 1 do
                        local objeto = objetos:get(i)
                        if objeto and instanceof(objeto, "IsoLightSwitch") then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

--- Verifica se um nível Z possui pelo menos um interruptor nos limites retangulares dados.
--- @param limiteX1 number Coordenada X mínima.
--- @param limiteY1 number Coordenada Y mínima.
--- @param limiteX2 number Coordenada X máxima.
--- @param limiteY2 number Coordenada Y máxima.
--- @param coordenadaZ number O nível Z.
--- @return boolean Retorna true se houver pelo menos um interruptor.
local function TemInterruptorDeLuzNosLimites(limiteX1, limiteY1, limiteX2, limiteY2, coordenadaZ)
    for coordenadaX = limiteX1, limiteX2 do
        for coordenadaY = limiteY1, limiteY2 do
            local quadrado = getSquare(coordenadaX, coordenadaY, coordenadaZ)
            if quadrado then
                local objetos = quadrado:getObjects()
                if objetos then
                    for i = 0, objetos:size() - 1 do
                        local objeto = objetos:get(i)
                        if objeto and instanceof(objeto, "IsoLightSwitch") then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

--- Determina quais níveis Z devem ser escaneados baseando-se na presença de interruptores.
--- @param comodo any O objeto BuildingDef do cômodo.
--- @param inicioZ number O nível Z inicial.
--- @return table Uma lista com os níveis Z para escaneamento.
local function ObterNiveisZParaEscanear(comodo, inicioZ)
    local comodoX1 = comodo:getX() - 2
    local comodoY1 = comodo:getY() - 2
    local comodoX2 = comodo:getX2() + 2
    local comodoY2 = comodo:getY2() + 2
    
    local niveisZ = {}
    
    -- Sempre escaneia o andar inicial
    table.insert(niveisZ, inicioZ)
    
    -- Escaneia subsolos (de -1 a -3)
    for coordenadaZ = -1, -3, -1 do
        if TemInterruptorDeLuzNosLimites(comodoX1, comodoY1, comodoX2, comodoY2, coordenadaZ) then
            table.insert(niveisZ, coordenadaZ)
        end
    end
    
    -- Escaneia andares superiores (de +1 a +10), interrompendo se encontrar um andar sem interruptores
    for coordenadaZ = 1, 10 do
        if TemInterruptorDeLuzNosLimites(comodoX1, comodoY1, comodoX2, comodoY2, coordenadaZ) then
            table.insert(niveisZ, coordenadaZ)
        else
            break
        end
    end
    
    return niveisZ
end

--- Determina quais níveis Z devem ser escaneados baseando-se em limites geométricos (sem cômodos associados).
--- @param limiteX1 number Coordenada X mínima.
--- @param limiteY1 number Coordenada Y mínima.
--- @param limiteX2 number Coordenada X máxima.
--- @param limiteY2 number Coordenada Y máxima.
--- @param inicioZ number O nível Z inicial.
--- @return table Uma lista com os níveis Z para escaneamento.
local function ObterNiveisZParaEscanearLimites(limiteX1, limiteY1, limiteX2, limiteY2, inicioZ)
    local niveisZ = {}
    
    -- Sempre escaneia o andar inicial
    table.insert(niveisZ, inicioZ)
    
    -- Escaneia subsolos (de -1 a -3)
    for coordenadaZ = -1, -3, -1 do
        if TemInterruptorDeLuzNosLimites(limiteX1, limiteY1, limiteX2, limiteY2, coordenadaZ) then
            table.insert(niveisZ, coordenadaZ)
        end
    end
    
    -- Escaneia andares superiores (de +1 a +10)
    for coordenadaZ = 1, 10 do
        if TemInterruptorDeLuzNosLimites(limiteX1, limiteY1, limiteX2, limiteY2, coordenadaZ) then
            table.insert(niveisZ, coordenadaZ)
        else
            break
        end
    end
    
    return niveisZ
end

-- ============================================================================
-- DETECÇÃO DE BORDAS
-- ============================================================================

--- Detecta todos os quadrados (tiles) pertencentes ao mesmo IsoBuilding do interruptor de luz.
--- @param inicioX number Coordenada X inicial.
--- @param inicioY number Coordenada Y inicial.
--- @param inicioZ number Coordenada Z inicial.
--- @param raio number Raio de recuo utilizado apenas em fallbacks.
--- @param idConstrucao string|nil ID opcional da construção (identifica construções feitas por jogadores).
--- @return table Lista contendo os quadrados identificados.
function LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBorders(inicioX, inicioY, inicioZ, raio, idConstrucao)
    LKS_EletricidadeConstrucao.Core.Logger.StartTimer("BorderDetection")

    local quadradoInicial = getSquare(inicioX, inicioY, inicioZ)
    local construcaoInicial = quadradoInicial and quadradoInicial:getBuilding()

    -- Verifica se é uma construção criada pelo jogador (ID no formato "bld_X_Y_Z")
    local construidoPeloJogador = idConstrucao and string.match(idConstrucao, "^bld_%-?%d+_%-?%d+_%-?%d+$") ~= nil

    if not construcaoInicial then
        if construidoPeloJogador then
            local raioRecuo = raio or 30
            print(string.format(
                "[LKS PATCH - BorderDetector] Construção criada pelo jogador %s em (%d,%d,%d) – usando raio fallback de %d",
                idConstrucao or "?", inicioX, inicioY, inicioZ, raioRecuo))
            local recuo = LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(
                inicioX, inicioY, inicioZ, raioRecuo)
            LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BorderDetection", 100)
            return recuo
        end

        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("Detector de Bordas: nenhuma IsoBuilding em (%d,%d,%d), buscando construções próximas...",
                inicioX, inicioY, inicioZ),
            "Building"
        )
        
        -- Busca por construções vizinhas
        local construcoesProximas = {}
        local raioBusca = 10
        for dx = -raioBusca, raioBusca do
            for dy = -raioBusca, raioBusca do
                local quadrado = getSquare(inicioX + dx, inicioY + dy, inicioZ)
                if quadrado then
                    local construcao = quadrado:getBuilding()
                    if construcao and not construcoesProximas[construcao] then
                        construcoesProximas[construcao] = true
                        print(string.format("[LKS PATCH - BorderDetector] Construção próxima encontrada no deslocamento (%d,%d)", dx, dy))
                    end
                end
            end
        end
        
        local totalConstrucoesProximas = 0
        for _ in pairs(construcoesProximas) do
            totalConstrucoesProximas = totalConstrucoesProximas + 1
        end
        
        if totalConstrucoesProximas > 0 then
            print(string.format("[LKS PATCH - BorderDetector] Encontrada(s) %d construção(ões) próxima(s), escaneando seus cômodos...", totalConstrucoesProximas))
            
            local quadrados = {}
            
            for construcao in pairs(construcoesProximas) do
                local definicao = construcao:getDef()
                if definicao then
                    local comodos = definicao:getRooms()
                    if comodos and comodos:size() > 0 then
                        for roomIdx = 0, comodos:size() - 1 do
                            local comodo = comodos:get(roomIdx)
                            if comodo then
                                local comodoX1 = comodo:getX()
                                local comodoY1 = comodo:getY()
                                local comodoX2 = comodo:getX2()
                                local comodoY2 = comodo:getY2()
                                
                                local niveisZ = ObterNiveisZParaEscanear(comodo, inicioZ)
                                
                                for _, z in ipairs(niveisZ) do
                                    for x = comodoX1 - 2, comodoX2 + 2 do
                                        for y = comodoY1 - 2, comodoY2 + 2 do
                                            table.insert(quadrados, {x = x, y = y, z = z, type = "interior"})
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            if #quadrados > 0 then
                quadrados = LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(quadrados)
                print(string.format("[LKS PATCH - BorderDetector] Varredura de construções próximas: %d quadrados em %d construções", 
                    #quadrados, totalConstrucoesProximas))
                LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BorderDetection", 100)
                return quadrados
            end
        end
        
        -- Fallback final por raio
        print("[LKS PATCH - BorderDetector] Nenhuma construcao com comodos por perto, usando recuo por raio")
        local recuo = LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(
            inicioX, inicioY, inicioZ, raio or 80)
        LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BorderDetection", 100)
        return recuo
    end

    local definicao = construcaoInicial:getDef()
    if not definicao then
        local recuo = LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(inicioX, inicioY, inicioZ, raio or 30)
        LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BorderDetection", 100)
        return recuo
    end

    local quadrados = {}
    local comodos = definicao:getRooms()
    
    if comodos and comodos:size() > 0 then
        for roomIdx = 0, comodos:size() - 1 do
            local comodo = comodos:get(roomIdx)
            if comodo then
                local comodoX1 = comodo:getX()
                local comodoY1 = comodo:getY()
                local comodoX2 = comodo:getX2()
                local comodoY2 = comodo:getY2()
                
                local niveisZ = ObterNiveisZParaEscanear(comodo, inicioZ)
                
                for _, z in ipairs(niveisZ) do
                    -- Adiciona uma borda extra de 2 tiles para capturar interruptores/luzes nas paredes externas
                    for x = comodoX1 - 2, comodoX2 + 2 do
                        for y = comodoY1 - 2, comodoY2 + 2 do
                            local quadrado = getSquare(x, y, z)
                            if quadrado then
                                local construcaoQuadrado = quadrado:getBuilding()
                                if construcaoQuadrado == construcaoInicial or construcaoQuadrado == nil then
                                    table.insert(quadrados, {x = x, y = y, z = z, type = "interior"})
                                end
                            end
                        end
                    end
                end
            end
        end
        
        quadrados = LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(quadrados)
    else
        -- Fallback geométrico por limites
        local caixaX = definicao:getX()
        local caixaY = definicao:getY()
        local larguraConstrucao = definicao:getW()
        local alturaConstrucao = definicao:getH()
        local tamanhoBorda = 2
        local extendidoX = caixaX - tamanhoBorda
        local extendidoY = caixaY - tamanhoBorda
        local extendidoLargura = larguraConstrucao + (tamanhoBorda * 2)
        local extendidoAltura = alturaConstrucao + (tamanhoBorda * 2)

        local niveisZ = ObterNiveisZParaEscanearLimites(extendidoX, extendidoY, extendidoX + extendidoLargura - 1, extendidoY + extendidoAltura - 1, inicioZ)
        
        for _, z in ipairs(niveisZ) do
            for x = extendidoX, extendidoX + extendidoLargura - 1 do
                for y = extendidoY, extendidoY + extendidoAltura - 1 do
                    local quadrado = getSquare(x, y, z)
                    if quadrado then
                        local naConstrucao = (quadrado:getBuilding() == construcaoInicial)
                        local naBorda = (x < caixaX or x >= caixaX + larguraConstrucao or y < caixaY or y >= caixaY + alturaConstrucao)
                        if naConstrucao or (naBorda and quadrado:getBuilding() == nil) then
                            table.insert(quadrados, {x = x, y = y, z = z, type = "interior"})
                        end
                    end
                end
            end
        end

        quadrados = LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(quadrados)
    end

    LKS_EletricidadeConstrucao.Core.Logger.EndTimer("BorderDetection", 100)
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Detector de Bordas: encontrados %d quadrados via varredura de limites", #quadrados),
        "Building"
    )

    return quadrados
end

--- Varredura de fallback por raio ao redor de um ponto central.
--- @param cx number Centro X.
--- @param cy number Centro Y.
--- @param cz number Centro Z.
--- @param r number Raio.
--- @return table Lista de quadrados identificados.
function LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(cx, cy, cz, r)
    local quadrados = {}
    local raio = r or 45
    local zMinimo = math.max(0, cz - 3)
    local zMaximo = cz + 10
    
    for dz = zMinimo, zMaximo do
        for dx = -raio, raio do
            for dy = -raio, raio do
                local sx, sy, sz = cx + dx, cy + dy, dz
                local quadrado = getSquare(sx, sy, sz)
                if quadrado then
                    table.insert(quadrados, {x = sx, y = sy, z = sz, type = "interior"})
                end
            end
        end
    end
    return quadrados
end

--- Verifica se há barreiras físicas (paredes/portas fechadas) entre dois quadrados adjacentes.
--- @param x1 number X de origem.
--- @param y1 number Y de origem.
--- @param z1 number Z de origem.
--- @param x2 number X de destino.
--- @param y2 number Y de destino.
--- @param z2 number Z de destino.
--- @return boolean Retorna true se houver barreira.
function LKS_EletricidadeConstrucao.Building.BorderDetector.HasBarrier(x1, y1, z1, x2, y2, z2)
    local quadrado1 = getSquare(x1, y1, z1)
    local quadrado2 = getSquare(x2, y2, z2)

    if not quadrado1 or not quadrado2 then
        return true  -- Quadrados descarregados atuam como barreira
    end

    return quadrado1:getBuilding() ~= quadrado2:getBuilding()
end

--- Verifica se o quadrado possui parede na direção do ponto de destino.
--- @param quadrado any O GridSquare avaliado.
--- @param targetX number Destino X.
--- @param targetY number Destino Y.
--- @return boolean Retorna true se houver parede.
function LKS_EletricidadeConstrucao.Building.BorderDetector.HasWallTowards(quadrado, targetX, targetY)
    local quadradoDestino = getSquare(targetX, targetY, quadrado:getZ())
    if not quadradoDestino then return true end
    return quadrado:getBuilding() ~= quadradoDestino:getBuilding()
end

--- Verifica se há uma porta conectando dois quadrados específicos.
--- @param quadrado1 any Primeiro quadrado.
--- @param quadrado2 any Segundo quadrado.
--- @param x1 number X do primeiro quadrado.
--- @param y1 number Y do primeiro quadrado.
--- @param x2 number X do segundo quadrado.
--- @param y2 number Y do segundo quadrado.
--- @return boolean Retorna true se existir porta.
function LKS_EletricidadeConstrucao.Building.BorderDetector.HasDoorBetween(quadrado1, quadrado2, x1, y1, x2, y2)
    if LKS_EletricidadeConstrucao.Building.BorderDetector.HasDoorTowards(quadrado1, x2, y2) then
        return true
    end
    if LKS_EletricidadeConstrucao.Building.BorderDetector.HasDoorTowards(quadrado2, x1, y1) then
        return true
    end
    return false
end

--- Verifica se o quadrado possui um objeto IsoDoor na direção das coordenadas de destino.
--- @param quadrado any O quadrado a ser avaliado.
--- @param targetX number Destino X.
--- @param targetY number Destino Y.
--- @return boolean Retorna true se existir uma porta.
function LKS_EletricidadeConstrucao.Building.BorderDetector.HasDoorTowards(quadrado, targetX, targetY)
    local objetos = quadrado:getObjects()
    if not objetos then
        return false
    end
    
    local quadradoX = quadrado:getX()
    local quadradoY = quadrado:getY()
    
    for i = 0, objetos:size() - 1 do
        local objeto = objetos:get(i)
        if objeto and instanceof(objeto, "IsoDoor") then
            local north = objeto:getNorth()
            if north then
                if targetY ~= quadradoY then
                    return true
                end
            else
                if targetX ~= quadradoX then
                    return true
                end
            end
        end
    end
    
    return false
end

--- Remove duplicidades de uma lista de coordenadas de quadrados.
--- @param tiles table Lista com chaves x, y, z.
--- @return table Lista unificada sem duplicidades.
function LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(tiles)
    local vistos = {}
    local unicos = {}
    
    for _, quadrado in ipairs(tiles) do
        local key = string.format("%d_%d_%d", quadrado.x, quadrado.y, quadrado.z)
        if not vistos[key] then
            vistos[key] = true
            table.insert(unicos, quadrado)
        end
    end
    
    return unicos
end

-- ============================================================================
-- MÉTODOS DE DETECÇÃO ALTERNATIVOS
-- ============================================================================

--- Detecta limites usando algoritmo de Raycasting (mais veloz, porém menos preciso).
--- @param startX number Início X.
--- @param startY number Início Y.
--- @param startZ number Início Z.
--- @param raio number Raio limite.
--- @return table Lista de quadrados de borda.
function LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBordersRaycast(startX, startY, startZ, raio)
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Usando detecção de bordas por raycast em (%d,%d,%d) com raio=%d",
            startX, startY, startZ, raio),
        "Building"
    )
    
    local quadradosBorda = {}
    local passo = 1
    
    for angulo = 0, 359, 15 do
        local radianos = math.rad(angulo)
        local direcaoX = math.cos(radianos)
        local direcaoY = math.sin(radianos)
        
        for distancia = 1, raio, passo do
            local x = math.floor(startX + (direcaoX * distancia) + 0.5)
            local y = math.floor(startY + (direcaoY * distancia) + 0.5)
            local quadrado = getSquare(x, y, startZ)
            
            if not quadrado then
                break
            end
            
            local temParede = LKS_EletricidadeConstrucao.Building.BorderDetector.HasWallTowards(quadrado, startX, startY)
            if temParede then
                table.insert(quadradosBorda, {
                    x = x,
                    y = y,
                    z = startZ,
                    type = "wall"
                })
                break
            end
        end
    end
    
    return LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(quadradosBorda)
end

--- Coleta todas as coordenadas de interior pertencentes ao mesmo IsoBuilding.
--- @param startX number Início X.
--- @param startY number Início Y.
--- @param startZ number Início Z.
--- @param raio number Raio de recuo caso não encontre IsoBuilding físico.
--- @return table Lista de coordenadas dos quadrados internos.
function LKS_EletricidadeConstrucao.Building.BorderDetector.GetInteriorTiles(startX, startY, startZ, raio)
    local quadradoInicial = getSquare(startX, startY, startZ)
    local construcaoInicial = quadradoInicial and quadradoInicial:getBuilding()

    if not construcaoInicial then
        return LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(
            startX, startY, startZ, raio or 30)
    end

    local definicao = construcaoInicial:getDef()
    if not definicao then
        return LKS_EletricidadeConstrucao.Building.BorderDetector.RadiusFallback(startX, startY, startZ, raio or 30)
    end

    local caixaX = definicao:getX()
    local caixaY = definicao:getY()
    local larguraConstrucao = definicao:getW()
    local alturaConstrucao = definicao:getH()
    local tamanhoBorda = 2
    local extendidoX = caixaX - tamanhoBorda
    local extendidoY = caixaY - tamanhoBorda
    local extendidoLargura = larguraConstrucao + (tamanhoBorda * 2)
    local extendidoAltura = alturaConstrucao + (tamanhoBorda * 2)

    local niveisZ = ObterNiveisZParaEscanearLimites(extendidoX, extendidoY, extendidoX + extendidoLargura - 1, extendidoY + extendidoAltura - 1, startZ)

    local quadrados = {}
    for _, z in ipairs(niveisZ) do
        for x = extendidoX, extendidoX + extendidoLargura - 1 do
            for y = extendidoY, extendidoY + extendidoAltura - 1 do
                local quadrado = getSquare(x, y, z)
                if quadrado then
                    local naConstrucao = (quadrado:getBuilding() == construcaoInicial)
                    local naBorda = (x < caixaX or x >= caixaX + larguraConstrucao or y < caixaY or y >= caixaY + alturaConstrucao)
                    if naConstrucao or naBorda then
                        table.insert(quadrados, {x = x, y = y, z = z})
                    end
                end
            end
        end
    end

    quadrados = LKS_EletricidadeConstrucao.Building.BorderDetector.RemoveDuplicateTiles(quadrados)

    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("ObterQuadradosInteriores: encontrados %d quadrados via varredura de limites", #quadrados),
        "Building"
    )

    return quadrados
end

-- ============================================================================
-- DEPURAÇÃO
-- ============================================================================

--- Imprime informações de depuração do detector de limites no console.
--- @param x number Posição X.
--- @param y number Posição Y.
--- @param z number Posição Z.
--- @param raio number Raio.
function LKS_EletricidadeConstrucao.Building.BorderDetector.DebugBorders(x, y, z, raio)
    LKS_EletricidadeConstrucao.Print("=== Depuração de Detecção de Bordas ===")
    LKS_EletricidadeConstrucao.Print(string.format("Posição: (%d,%d,%d)", x, y, z))
    LKS_EletricidadeConstrucao.Print("Raio: " .. raio)
    
    local bordas = LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBorders(x, y, z, raio)
    LKS_EletricidadeConstrucao.Print("Quadrados de borda: " .. #bordas)
    
    for i = 1, math.min(10, #bordas) do
        local tile = bordas[i]
        LKS_EletricidadeConstrucao.Print(string.format("  [%d] (%d,%d,%d) type=%s",
            i, tile.x, tile.y, tile.z, tile.type))
    end
    
    if #bordas > 10 then
        LKS_EletricidadeConstrucao.Print("  ... " .. (#bordas - 10) .. " adicionais")
    end
    
    local interior = LKS_EletricidadeConstrucao.Building.BorderDetector.GetInteriorTiles(x, y, z, raio)
    LKS_EletricidadeConstrucao.Print("Quadrados de interior: " .. #interior)
end

-- ============================================================================
-- REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Building.BorderDetector", "2.0.0")

return LKS_EletricidadeConstrucao.Building.BorderDetector
