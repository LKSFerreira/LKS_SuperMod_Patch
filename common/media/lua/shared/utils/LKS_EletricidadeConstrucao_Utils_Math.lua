-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Utils_Math.lua
-- LKS_EletricidadeConstrucao V2 - Mathematical Utility Functions
-- Pure math helpers with no side effects or state
-- Version: 2.0.0-alpha
-- Date: February 22, 2026

-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Utils_Math] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- ============================================================================
-- CLAMPING & RANGES
-- ============================================================================

--- Clamp a value between min and max
--- @param value number The value to clamp
--- @param min number Minimum allowed value
--- @param max number Maximum allowed value
--- @return number Clamped value
function LKS_EletricidadeConstrucao.Utils.Math.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- Check if value is within range (inclusive)
--- @param value number The value to check
--- @param min number Range minimum
--- @param max number Range maximum
--- @return boolean True if in range
function LKS_EletricidadeConstrucao.Utils.Math.InRange(value, min, max)
    return value >= min and value <= max
end

--- Normalize value from [min, max] to [0, 1]
--- @param value number Value to normalize
--- @param min number Range minimum
--- @param max number Range maximum
--- @return number Normalized value (0-1)
function LKS_EletricidadeConstrucao.Utils.Math.Normalize(value, min, max)
    if max == min then return 0 end
    return (value - min) / (max - min)
end

--- Lerp (linear interpolation) between two values
--- @param a number Start value
--- @param b number End value
--- @param t number Interpolation factor (0-1)
--- @return number Interpolated value
function LKS_EletricidadeConstrucao.Utils.Math.Lerp(a, b, t)
    return a + (b - a) * t
end

--- Remap value from one range to another
--- @param value number Value to remap
--- @param inMin number Input range minimum
--- @param inMax number Input range maximum
--- @param outMin number Output range minimum
--- @param outMax number Output range maximum
--- @return number Remapped value
function LKS_EletricidadeConstrucao.Utils.Math.Remap(value, inMin, inMax, outMin, outMax)
    local normalized = LKS_EletricidadeConstrucao.Utils.Math.Normalize(value, inMin, inMax)
    return LKS_EletricidadeConstrucao.Utils.Math.Lerp(outMin, outMax, normalized)
end

-- ============================================================================
-- ROUNDING
-- ============================================================================

--- Round to nearest integer
--- @param value number Value to round
--- @return number Rounded value
function LKS_EletricidadeConstrucao.Utils.Math.Round(value)
    return math.floor(value + 0.5)
end

--- Round to specified decimal places
--- @param value number Value to round
--- @param decimals number Number of decimal places
--- @return number Rounded value
function LKS_EletricidadeConstrucao.Utils.Math.RoundTo(value, decimals)
    local mult = 10 ^ decimals
    return math.floor(value * mult + 0.5) / mult
end

--- Round down (floor)
--- @param value number Value to floor
--- @return number Floored value
function LKS_EletricidadeConstrucao.Utils.Math.Floor(value)
    return math.floor(value)
end

--- Round up (ceil)
--- @param value number Value to ceil
--- @return number Ceiled value
function LKS_EletricidadeConstrucao.Utils.Math.Ceil(value)
    return math.ceil(value)
end

-- ============================================================================
-- SIGN & ABSOLUTE VALUE
-- ============================================================================

--- Get sign of number (-1, 0, or 1)
--- @param value number The value
--- @return number -1 if negative, 0 if zero, 1 if positive
function LKS_EletricidadeConstrucao.Utils.Math.Sign(value)
    if value > 0 then return 1 end
    if value < 0 then return -1 end
    return 0
end

--- Get absolute value
--- @param value number The value
--- @return number Absolute value
function LKS_EletricidadeConstrucao.Utils.Math.Abs(value)
    return math.abs(value)
end

-- ============================================================================
-- MIN/MAX
-- ============================================================================

--- Get minimum of two values
--- @param a number First value
--- @param b number Second value
--- @return number Minimum value
function LKS_EletricidadeConstrucao.Utils.Math.Min(a, b)
    return math.min(a, b)
end

--- Get maximum of two values
--- @param a number First value
--- @param b number Second value
--- @return number Maximum value
function LKS_EletricidadeConstrucao.Utils.Math.Max(a, b)
    return math.max(a, b)
end

--- Get minimum of multiple values
--- @param ... number Values to compare
--- @return number Minimum value
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

--- Get maximum of multiple values
--- @param ... number Values to compare
--- @return number Maximum value
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
-- AVERAGING
-- ============================================================================

--- Calculate average of multiple values
--- @param ... number Values to average
--- @return number Average value
function LKS_EletricidadeConstrucao.Utils.Math.Average(...)
    local values = {...}
    if #values == 0 then return 0 end
    
    local sum = 0
    for i = 1, #values do
        sum = sum + values[i]
    end
    return sum / #values
end

--- Calculate weighted average
--- @param values table Array of values
--- @param weights table Array of weights (same length as values)
--- @return number Weighted average
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
-- PERCENTAGE
-- ============================================================================

--- Convert decimal to percentage (0.5 → 50)
--- @param value number Decimal value (0-1)
--- @return number Percentage (0-100)
function LKS_EletricidadeConstrucao.Utils.Math.ToPercentage(value)
    return value * 100
end

--- Convert percentage to decimal (50 → 0.5)
--- @param value number Percentage (0-100)
--- @return number Decimal value (0-1)
function LKS_EletricidadeConstrucao.Utils.Math.FromPercentage(value)
    return value / 100
end

--- Calculate percentage of total
--- @param part number Part value
--- @param total number Total value
--- @return number Percentage (0-100)
function LKS_EletricidadeConstrucao.Utils.Math.PercentOf(part, total)
    if total == 0 then return 0 end
    return (part / total) * 100
end

-- ============================================================================
-- COMPARISON
-- ============================================================================

--- Check if two floats are approximately equal (with epsilon)
--- @param a number First value
--- @param b number Second value
--- @param epsilon number Optional tolerance (default 0.0001)
--- @return boolean True if approximately equal
function LKS_EletricidadeConstrucao.Utils.Math.ApproxEqual(a, b, epsilon)
    epsilon = epsilon or 0.0001
    return math.abs(a - b) < epsilon
end

--- Check if value is approximately zero
--- @param value number Value to check
--- @param epsilon number Optional tolerance (default 0.0001)
--- @return boolean True if approximately zero
function LKS_EletricidadeConstrucao.Utils.Math.ApproxZero(value, epsilon)
    epsilon = epsilon or 0.0001
    return math.abs(value) < epsilon
end

-- ============================================================================
-- SPECIAL FUNCTIONS
-- ============================================================================

--- Smooth step interpolation (ease in/out)
--- @param edge0 number Lower edge
--- @param edge1 number Upper edge
--- @param x number Input value
--- @return number Smoothed value (0-1)
function LKS_EletricidadeConstrucao.Utils.Math.SmoothStep(edge0, edge1, x)
    -- Clamp x to [0, 1]
    local t = LKS_EletricidadeConstrucao.Utils.Math.Clamp((x - edge0) / (edge1 - edge0), 0, 1)
    -- Hermite interpolation
    return t * t * (3 - 2 * t)
end

--- Calculate distance between two points (2D)
--- @param x1 number First point X
--- @param y1 number First point Y
--- @param x2 number Second point X
--- @param y2 number Second point Y
--- @return number Distance
function LKS_EletricidadeConstrucao.Utils.Math.Distance2D(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--- Calculate squared distance (faster, for comparisons)
--- @param x1 number First point X
--- @param y1 number First point Y
--- @param x2 number Second point X
--- @param y2 number Second point Y
--- @return number Squared distance
function LKS_EletricidadeConstrucao.Utils.Math.DistanceSquared2D(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Utils.Math", "2.0.0")

return LKS_EletricidadeConstrucao.Utils.Math
