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

-- ARQUIVO: LKS_EletricidadeConstrucao_Utils_Geometry.lua
-- OBJETIVO: Funções utilitárias geométricas e espaciais aplicadas à grade do Project Zomboid (tiles e chunks).
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace principal existe
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Utils_Geometry] Namespace LKS_EletricidadeConstrucao não encontrado - abortando carregamento do módulo")
    return
end

-- ============================================================================
-- DISTÂNCIAS ENTRE TILES E PROXIMIDADE
-- ============================================================================

--- Calcula a distância Manhattan entre dois blocos na grade do jogo (soma das diferenças absolutas dos eixos).
---
--- @param x1 number Coordenada X do primeiro bloco.
--- @param y1 number Coordenada Y do primeiro bloco.
--- @param x2 number Coordenada X do segundo bloco.
--- @param y2 number Coordenada Y do segundo bloco.
--- @return number A distância Manhattan calculada.
function LKS_EletricidadeConstrucao.Utils.Geometry.ManhattanDistance(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end

--- Calcula a distância Euclidiana simples entre dois blocos na grade do jogo.
---
--- @param x1 number Coordenada X do primeiro bloco.
--- @param y1 number Coordenada Y do primeiro bloco.
--- @param x2 number Coordenada X do segundo bloco.
--- @param y2 number Coordenada Y do segundo bloco.
--- @return number A distância linear calculada.
function LKS_EletricidadeConstrucao.Utils.Geometry.EuclideanDistance(x1, y1, x2, y2)
    return LKS_EletricidadeConstrucao.Utils.Math.Distance2D(x1, y1, x2, y2)
end

--- Calcula a distância de Chebyshev entre dois blocos na grade (máximo das distâncias dos eixos individuais).
---
--- @param x1 number Coordenada X do primeiro bloco.
--- @param y1 number Coordenada Y do primeiro bloco.
--- @param x2 number Coordenada X do segundo bloco.
--- @param y2 number Coordenada Y do segundo bloco.
--- @return number A distância de Chebyshev calculada.
function LKS_EletricidadeConstrucao.Utils.Geometry.ChebyshevDistance(x1, y1, x2, y2)
    return math.max(math.abs(x2 - x1), math.abs(y2 - y1))
end

--- Verifica se dois blocos (tiles) na grade do jogo são adjacentes (incluindo diagonais).
---
--- @param x1 number Coordenada X do primeiro bloco.
--- @param y1 number Coordenada Y do primeiro bloco.
--- @param x2 number Coordenada X do segundo bloco.
--- @param y2 number Coordenada Y do segundo bloco.
--- @return boolean Retorna true se os blocos estiverem encostados.
function LKS_EletricidadeConstrucao.Utils.Geometry.IsAdjacent(x1, y1, x2, y2)
    return LKS_EletricidadeConstrucao.Utils.Geometry.ChebyshevDistance(x1, y1, x2, y2) == 1
end

--- Verifica se um bloco específico está dentro do raio circular a partir do centro (Euclidiano).
---
--- @param x number Coordenada X do bloco a testar.
--- @param y number Coordenada Y do bloco a testar.
--- @param centerX number Coordenada X do centro do raio.
--- @param centerY number Coordenada Y do centro do raio.
--- @param radius number Raio de busca linear.
--- @return boolean Retorna true se o bloco estiver dentro do círculo delimitado.
function LKS_EletricidadeConstrucao.Utils.Geometry.IsWithinRadius(x, y, centerX, centerY, radius)
    local distSq = LKS_EletricidadeConstrucao.Utils.Math.DistanceSquared2D(x, y, centerX, centerY)
    return distSq <= (radius * radius)
end

-- ============================================================================
-- VALIDAÇÕES DE COORDENADAS DO PROJECT ZOMBOID
-- ============================================================================

--- Verifica se as coordenadas informadas são seguras e válidas no mapa de Project Zomboid.
--- Compatível com o mod RV Interior (que gera coordenadas especiais entre -100000 e 200000).
---
--- @param x number Coordenada X.
--- @param y number Coordenada Y.
--- @param z number Coordenada Z (andares de 0 a 8) (opcional).
--- @return boolean Retorna true se as coordenadas estiverem dentro das faixas válidas e lógicas do mapa.
function LKS_EletricidadeConstrucao.Utils.Geometry.IsValidCoordinate(x, y, z)
    if not x or not y then return false end
    
    local constants = LKS_EletricidadeConstrucao.Constants.BUILDING
    
    -- Validação do eixo X
    if x < constants.RV_INTERIOR_MIN_COORD or x > constants.RV_INTERIOR_MAX_COORD then
        return false
    end
    
    -- Validação do eixo Y
    if y < constants.RV_INTERIOR_MIN_COORD or y > constants.RV_INTERIOR_MAX_COORD then
        return false
    end
    
    -- Validação do andar (eixo Z) se informado
    if z then
        if z < constants.MIN_Z_LEVEL or z > constants.MAX_Z_LEVEL then
            return false
        end
    end
    
    return true
end

--- Verifica se as coordenadas informadas pertencem ao mapa especial de Interiores de RV (RV Interior).
---
--- **Detalhe Técnico:** O mod RV Interior tipicamente instancia seus cômodos fictícios em
--- coordenadas negativas no plano cartesiano do mapa do PZ.
---
--- @param x number Coordenada X.
--- @param y number Coordenada Y.
--- @return boolean Retorna true se a coordenada representar uma sala do RV Interior.
function LKS_EletricidadeConstrucao.Utils.Geometry.IsRVInteriorCoordinate(x, y)
    return x < 0 or y < 0
end

-- ============================================================================
-- ENVOLTÓRIOS GRÁFICOS (BOUNDING BOX)
-- ============================================================================

--- Cria uma Bounding Box (caixa de enquadramento) bidimensional a partir de uma lista de coordenadas de tiles.
---
--- @param coordinates table Lista indexada contendo tabelas no formato {x, y} ou {x, y, z}.
--- @return table Tabela contendo minX, minY, maxX, maxY, width e height, ou nil se a lista estiver vazia.
function LKS_EletricidadeConstrucao.Utils.Geometry.GetBoundingBox(coordinates)
    if not coordinates or #coordinates == 0 then
        return nil
    end
    
    local minX = coordinates[1][1] or coordinates[1].x
    local minY = coordinates[1][2] or coordinates[1].y
    local maxX = minX
    local maxY = minY
    
    for i = 2, #coordinates do
        local x = coordinates[i][1] or coordinates[i].x
        local y = coordinates[i][2] or coordinates[i].y
        
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end
    
    return {
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY,
        width = maxX - minX + 1,
        height = maxY - minY + 1
    }
end

--- Verifica se uma determinada coordenada de bloco está contida dentro de uma Bounding Box.
---
--- @param x number Coordenada X do bloco.
--- @param y number Coordenada Y do bloco.
--- @param bbox table A tabela de Bounding Box contendo minX, minY, maxX e maxY.
--- @return boolean Retorna true se o bloco estiver localizado dentro dos limites do envoltório.
function LKS_EletricidadeConstrucao.Utils.Geometry.IsInsideBBox(x, y, bbox)
    return x >= bbox.minX and x <= bbox.maxX and
           y >= bbox.minY and y <= bbox.maxY
end

--- Expande os limites de uma Bounding Box adicionando uma margem em quadrados para todas as direções.
---
--- @param bbox table A Bounding Box de origem.
--- @param margin number Margem em quadrados (tiles) a ser adicionada.
--- @return table A nova Bounding Box expandida.
function LKS_EletricidadeConstrucao.Utils.Geometry.ExpandBBox(bbox, margin)
    return {
        minX = bbox.minX - margin,
        minY = bbox.minY - margin,
        maxX = bbox.maxX + margin,
        maxY = bbox.maxY + margin,
        width = bbox.width + (margin * 2),
        height = bbox.height + (margin * 2)
    }
end

-- ============================================================================
-- VARREDURAS DE CONTORNO (BORDER DETECTION)
-- ============================================================================

--- Obtém as coordenadas de todos os blocos contidos em um raio circular a partir do centro.
---
--- @param centerX number Coordenada X do centro.
--- @param centerY number Coordenada Y do centro.
--- @param radius number Raio em blocos.
--- @return table Lista contendo tabelas no formato {x, y}.
function LKS_EletricidadeConstrucao.Utils.Geometry.GetTilesInRadius(centerX, centerY, radius)
    local tiles = {}
    
    for x = centerX - radius, centerX + radius do
        for y = centerY - radius, centerY + radius do
            if LKS_EletricidadeConstrucao.Utils.Geometry.IsWithinRadius(x, y, centerX, centerY, radius) then
                table.insert(tiles, {x = x, y = y})
            end
        end
    end
    
    return tiles
end

--- Obtém todos os blocos de borda (contorno) ao redor de uma estrutura.
--- Muito mais preciso que Bounding Box simples para edifícios complexos ou em formato de L.
---
--- @param structureTiles table Lista contendo as coordenadas {x, y, z} da construção.
--- @param borderRadius number Espessura da borda a ser gerada ao redor do prédio (em tiles).
--- @return table Lista contendo as coordenadas {x, y, z} dos blocos da borda.
function LKS_EletricidadeConstrucao.Utils.Geometry.GetBorderTiles(structureTiles, borderRadius)
    local borderTiles = {}
    local processedTiles = {}  -- Tabela de hash rápida para evitar duplicados
    
    -- Para cada tile pertencente à estrutura física do prédio, varre suas adjacências
    for _, tile in ipairs(structureTiles) do
        local x = tile.x or tile[1]
        local y = tile.y or tile[2]
        local z = tile.z or tile[3] or 0
        
        for offsetX = -borderRadius, borderRadius do
            for offsetY = -borderRadius, borderRadius do
                -- Ignora o ponto central (0,0) pois este representa o próprio prédio
                if offsetX ~= 0 or offsetY ~= 0 then
                    local borderX = x + offsetX
                    local borderY = y + offsetY
                    local key = borderX .. "," .. borderY .. "," .. z
                    
                    if not processedTiles[key] then
                        processedTiles[key] = true
                        table.insert(borderTiles, {x = borderX, y = borderY, z = z})
                    end
                end
            end
        end
    end
    
    return borderTiles
end

-- ============================================================================
-- DIREÇÃO E ÂNGULOS
-- ============================================================================

--- Obtém o vetor de direção normalizado (direção de vetor unitário) partindo do ponto 1 para o ponto 2.
---
--- @param x1 number X do ponto de origem.
--- @param y1 number Y do ponto de origem.
--- @param x2 number X do ponto de destino.
--- @param y2 number Y do ponto de destino.
--- @return number, number O vetor normalizado (dx, dy).
function LKS_EletricidadeConstrucao.Utils.Geometry.GetDirection(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    
    if length == 0 then
        return 0, 0
    end
    
    return dx / length, dy / length
end

--- Obtém o ângulo em graus (0° a 360°) partindo do ponto 1 para o ponto 2.
---
--- @param x1 number X do ponto de origem.
--- @param y1 number Y do ponto de origem.
--- @param x2 number X do ponto de destino.
--- @param y2 number Y do ponto de destino.
--- @return number O ângulo em graus trigonométricos.
function LKS_EletricidadeConstrucao.Utils.Geometry.GetAngle(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local radians = math.atan2(dy, dx)
    local degrees = math.deg(radians)
    
    if degrees < 0 then
        degrees = degrees + 360
    end
    
    return degrees
end

-- ============================================================================
-- CONVERSORES DE GRADE E CHUNKS DO PZ
-- ============================================================================

--- Converte coordenadas globais do mapa do jogo para coordenadas de Chunks.
---
--- **Nota da Engine:** No Project Zomboid, cada Chunk (região básica de carregamento)
--- corresponde a um grid quadrado de exatamente 10x10 tiles.
---
--- @param x number Coordenada global X.
--- @param y number Coordenada global Y.
--- @return number, number A coordenada do Chunk (ChunkX, ChunkY).
function LKS_EletricidadeConstrucao.Utils.Geometry.WorldToChunk(x, y)
    return math.floor(x / 10), math.floor(y / 10)
end

--- Gera uma chave textual única para identificação do Chunk.
---
--- @param x number Coordenada global X.
--- @param y number Coordenada global Y.
--- @return string A chave de chunk formatada como "cx,cy".
function LKS_EletricidadeConstrucao.Utils.Geometry.GetChunkKey(x, y)
    local cx, cy = LKS_EletricidadeConstrucao.Utils.Geometry.WorldToChunk(x, y)
    return cx .. "," .. cy
end

--- Converte uma chave de tile "x,y,z" de volta para coordenadas numéricas individuais.
---
--- @param key string A chave textual do tile.
--- @return number, number, number As coordenadas numéricas X, Y e Z de volta.
function LKS_EletricidadeConstrucao.Utils.Geometry.ParseTileKey(key)
    local parts = {}
    for part in string.gmatch(key, "[^,]+") do
        table.insert(parts, tonumber(part))
    end
    return parts[1], parts[2], parts[3] or 0
end

--- Cria uma chave textual única a partir de coordenadas espaciais informadas.
---
--- @param x number Coordenada X.
--- @param y number Coordenada Y.
--- @param z number Coordenada Z (andar).
--- @return string A chave textual formatada como "x,y,z".
function LKS_EletricidadeConstrucao.Utils.Geometry.MakeTileKey(x, y, z)
    z = z or 0
    return x .. "," .. y .. "," .. z
end

-- ============================================================================
-- CONCLUSÃO DA INICIALIZAÇÃO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Utils.Geometry", "2.0.0")

return LKS_EletricidadeConstrucao.Utils.Geometry
