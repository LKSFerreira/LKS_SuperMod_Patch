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

-- ARQUIVO: LKS_EletricidadeConstrucao_Utils_Math.lua
-- OBJETIVO: Funções utilitárias matemáticas puras (sem efeitos colaterais ou dependências de estado).
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace principal existe
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Utils_Math] Namespace LKS_EletricidadeConstrucao não encontrado - abortando carregamento do módulo")
    return
end

-- ============================================================================
-- LIMITES E INTERVALOS (CLAMPING & RANGES)
-- ============================================================================

--- Clampa um número limitando-o a um valor mínimo e máximo.
---
--- **Exemplo:**
--- ```lua
--- local valor = LKS_EletricidadeConstrucao.Utils.Math.Clamp(150, 0, 100)
--- print(valor) -- Output: 100
--- ```
---
--- @param value number O valor de entrada a ser avaliado.
--- @param min number O limite mínimo permitido.
--- @param max number O limite máximo permitido.
--- @return number O valor clampado.
function LKS_EletricidadeConstrucao.Utils.Math.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- Verifica se um determinado número está dentro do intervalo (inclusivo).
---
--- @param value number O número a ser testado.
--- @param min number O valor mínimo do intervalo.
--- @param max number O valor máximo do intervalo.
--- @return boolean Retorna true se o valor estiver na faixa especificada.
function LKS_EletricidadeConstrucao.Utils.Math.InRange(value, min, max)
    return value >= min and value <= max
end

--- Normaliza um valor de uma escala [min, max] para uma escala decimal [0, 1].
---
--- @param value number O valor a ser normalizado.
--- @param min number O valor mínimo do intervalo de entrada.
--- @param max number O valor máximo do intervalo de entrada.
--- @return number O valor normalizado entre 0.0 e 1.0.
function LKS_EletricidadeConstrucao.Utils.Math.Normalize(value, min, max)
    if max == min then return 0 end
    return (value - min) / (max - min)
end

--- Realiza uma interpolação linear (Lerp) entre dois números baseado em um fator alfa.
---
--- @param a number O valor inicial (quando t = 0).
--- @param b number O valor final (quando t = 1).
--- @param t number O fator de interpolação decimal (0.0 a 1.0).
--- @return number O valor interpolado resultante.
function LKS_EletricidadeConstrucao.Utils.Math.Lerp(a, b, t)
    return a + (b - a) * t
end

--- Remapeia um número de um intervalo de entrada para um novo intervalo de saída desejado.
---
--- **Exemplo:**
--- ```lua
--- -- Remapeia 5 de uma escala de 0-10 para uma nova escala de 0-100
--- local resultado = LKS_EletricidadeConstrucao.Utils.Math.Remap(5, 0, 10, 0, 100)
--- print(resultado) -- Output: 50
--- ```
---
--- @param value number O valor de entrada a ser remapeado.
--- @param inMin number O limite mínimo do intervalo de entrada original.
--- @param inMax number O limite máximo do intervalo de entrada original.
--- @param outMin number O limite mínimo do novo intervalo de saída.
--- @param outMax number O limite máximo do novo intervalo de saída.
--- @return number O valor remapeado correspondente na nova escala.
function LKS_EletricidadeConstrucao.Utils.Math.Remap(value, inMin, inMax, outMin, outMax)
    local normalized = LKS_EletricidadeConstrucao.Utils.Math.Normalize(value, inMin, inMax)
    return LKS_EletricidadeConstrucao.Utils.Math.Lerp(outMin, outMax, normalized)
end

-- ============================================================================
-- ARREDONDAMENTOS (ROUNDING)
-- ============================================================================

--- Arredonda um número para o inteiro mais próximo.
---
--- @param value number O valor decimal de entrada.
--- @return number O número arredondado.
function LKS_EletricidadeConstrucao.Utils.Math.Round(value)
    return math.floor(value + 0.5)
end

--- Arredonda um número para uma quantidade específica de casas decimais.
---
--- @param value number O valor decimal de entrada.
--- @param decimals number A quantidade de casas decimais desejadas (ex: 2 para centavos/porcentagem).
--- @return number O número arredondado com as casas decimais configuradas.
function LKS_EletricidadeConstrucao.Utils.Math.RoundTo(value, decimals)
    local mult = 10 ^ decimals
    return math.floor(value * mult + 0.5) / mult
end

--- Arredonda um número sempre para baixo (piso).
---
--- @param value number O número de entrada.
--- @return number O inteiro arredondado para baixo.
function LKS_EletricidadeConstrucao.Utils.Math.Floor(value)
    return math.floor(value)
end

--- Arredonda um número sempre para cima (teto).
---
--- @param value number O número de entrada.
--- @return number O inteiro arredondado para cima.
function LKS_EletricidadeConstrucao.Utils.Math.Ceil(value)
    return math.ceil(value)
end

-- ============================================================================
-- SINAIS E VALORES ABSOLUTOS
-- ============================================================================

--- Retorna o sinal algébrico de um número (-1, 0 ou 1).
---
--- @param value number O número a ser testado.
--- @return number Retorna -1 se negativo, 0 se nulo, ou 1 se positivo.
function LKS_EletricidadeConstrucao.Utils.Math.Sign(value)
    if value > 0 then return 1 end
    if value < 0 then return -1 end
    return 0
end

--- Retorna o valor absoluto de um número (remove o sinal negativo se houver).
---
--- @param value number O número de entrada.
--- @return number O valor absoluto.
function LKS_EletricidadeConstrucao.Utils.Math.Abs(value)
    return math.abs(value)
end

-- ============================================================================
-- MÍNIMOS E MÁXIMOS (MIN/MAX)
-- ============================================================================

--- Retorna o menor valor entre dois números informados.
---
--- @param a number O primeiro número.
--- @param b number O segundo número.
--- @return number O menor dos dois números.
function LKS_EletricidadeConstrucao.Utils.Math.Min(a, b)
    return math.min(a, b)
end

--- Retorna o maior valor entre dois números informados.
---
--- @param a number O primeiro número.
--- @param b number O segundo número.
--- @return number O maior dos dois números.
function LKS_EletricidadeConstrucao.Utils.Math.Max(a, b)
    return math.max(a, b)
end

--- Retorna o menor número contido em uma lista dinâmica de argumentos.
---
--- @param ... number Argumentos numéricos sequenciais.
--- @return number O menor número da sequência.
function LKS_EletricidadeConstrucao.Utils.Math.MinOf(...)
    local values = {...}
    local min = values[1]
    for i = 2, #values do
        if values[i] < min then
            min = values[i]
        end
    end
    return min
end

--- Retorna o maior número contido em uma lista dinâmica de argumentos.
---
--- @param ... number Argumentos numéricos sequenciais.
--- @return number O maior número da sequência.
function LKS_EletricidadeConstrucao.Utils.Math.MaxOf(...)
    local values = {...}
    local max = values[1]
    for i = 2, #values do
        if values[i] > max then
            max = values[i]
        end
    end
    return max
end

-- ============================================================================
-- MÉDIAS (AVERAGING)
-- ============================================================================

--- Calcula a média aritmética simples de uma lista de números informados como argumentos.
---
--- @param ... number Números a serem calculados na média.
--- @return number A média aritmética calculada.
function LKS_EletricidadeConstrucao.Utils.Math.Average(...)
    local values = {...}
    if #values == 0 then return 0 end
    
    local sum = 0
    for i = 1, #values do
        sum = sum + values[i]
    end
    return sum / #values
end

--- Calcula a média ponderada de uma lista de valores multiplicada por pesos correspondentes.
---
--- @param values table Array indexado de valores numéricos.
--- @param weights table Array indexado de pesos (deve possuir o mesmo tamanho do array de valores).
--- @return number A média ponderada resultante.
function LKS_EletricidadeConstrucao.Utils.Math.WeightedAverage(values, weights)
    if #values ~= #weights or #values == 0 then
        return 0
    end
    
    local sum = 0
    local weightSum = 0
    
    for i = 1, #values do
        sum = sum + (values[i] * weights[i])
        weightSum = weightSum + weights[i]
    end
    
    if weightSum == 0 then return 0 end
    return sum / weightSum
end

-- ============================================================================
-- CONVERSÕES DE PORCENTAGEM
-- ============================================================================

--- Converte um valor decimal em porcentagem simples (ex: 0.5 → 50%).
---
--- @param value number O valor decimal de entrada (0.0 a 1.0).
--- @return number O valor percentual de 0 a 100.
function LKS_EletricidadeConstrucao.Utils.Math.ToPercentage(value)
    return value * 100
end

--- Converte um valor de porcentagem simples de volta para decimal (ex: 50% → 0.5).
---
--- @param value number O valor percentual de 0 a 100.
--- @return number O valor decimal entre 0.0 e 1.0.
function LKS_EletricidadeConstrucao.Utils.Math.FromPercentage(value)
    return value / 100
end

--- Calcula qual é a porcentagem que uma parte representa de um valor total.
---
--- @param part number A parte a ser calculada.
--- @param total number O total de referência.
--- @return number A porcentagem resultante (0 a 100).
function LKS_EletricidadeConstrucao.Utils.Math.PercentOf(part, total)
    if total == 0 then return 0 end
    return (part / total) * 100
end

-- ============================================================================
-- COMPARAÇÕES FLUTUANTES (PRECISÃO)
-- ============================================================================

--- Compara se dois números de ponto flutuante são aproximadamente iguais levando em conta um épsilon.
---
--- @param a number O primeiro número.
--- @param b number O segundo número.
--- @param epsilon number O limite de tolerância (opcional, padrão: 0.0001).
--- @return boolean Retorna true se a diferença for menor que a tolerância definida.
function LKS_EletricidadeConstrucao.Utils.Math.ApproxEqual(a, b, epsilon)
    epsilon = epsilon or 0.0001
    return math.abs(a - b) < epsilon
end

--- Verifica se um número de ponto flutuante é aproximadamente zero (próximo de zero).
---
--- @param value number O valor a ser testado.
--- @param epsilon number O limite de tolerância (opcional, padrão: 0.0001).
--- @return boolean Retorna true se o valor for menor que a tolerância do erro.
function LKS_EletricidadeConstrucao.Utils.Math.ApproxZero(value, epsilon)
    epsilon = epsilon or 0.0001
    return math.abs(value) < epsilon
end

-- ============================================================================
-- GEOMETRIA E FUNÇÕES ESPECIAIS
-- ============================================================================

--- Executa uma interpolação SmoothStep (suavização Hermite de entrada e saída acelerada).
---
--- @param edge0 number O limite inicial inferior da escala.
--- @param edge1 number O limite final superior da escala.
--- @param x number O ponto de entrada a ser suavizado.
--- @return number O valor suavizado decimal final (0.0 a 1.0).
function LKS_EletricidadeConstrucao.Utils.Math.SmoothStep(edge0, edge1, x)
    local t = LKS_EletricidadeConstrucao.Utils.Math.Clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
end

--- Calcula a distância euclidiana simples entre dois pontos em um plano bi-dimensional (2D).
---
--- @param x1 number Coordenada X do ponto inicial.
--- @param y1 number Coordenada Y do ponto inicial.
--- @param x2 number Coordenada X do ponto final.
--- @param y2 number Coordenada Y do ponto final.
--- @return number A distância linear calculada.
function LKS_EletricidadeConstrucao.Utils.Math.Distance2D(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--- Calcula a distância quadrática entre dois pontos 2D (mais rápido para fins de ordenação ou checagem de raio).
---
--- Dispensa a operação pesada de raiz quadrada (`math.sqrt`), servindo idealmente para varreduras de laço rápido.
---
--- @param x1 number Coordenada X do ponto inicial.
--- @param y1 number Coordenada Y do ponto inicial.
--- @param x2 number Coordenada X do ponto final.
--- @param y2 number Coordenada Y do ponto final.
--- @return number A distância quadrada calculada.
function LKS_EletricidadeConstrucao.Utils.Math.DistanceSquared2D(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

-- ============================================================================
-- CONCLUSÃO DA INICIALIZAÇÃO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Utils.Math", "2.0.0")

return LKS_EletricidadeConstrucao.Utils.Math
