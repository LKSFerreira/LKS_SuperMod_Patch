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

-- ARQUIVO: LKS_EletricidadeConstrucao_Utils_Validation.lua
-- OBJETIVO: Funções utilitárias para validação de dados de entrada, verificação de tipos e sanidade.
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace existe antes de carregar o módulo
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Utils_Validation] Namespace LKS_EletricidadeConstrucao nao encontrado - pulando carregamento do modulo")
    return
end

-- ============================================================================
-- VERIFICAÇÕES DE NIL
-- ============================================================================

--- Verifica se o valor fornecido é nulo (nil).
--- @param valor any O valor a ser avaliado.
--- @return boolean Retorna true se o valor for nil, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsNil(valor)
    return valor == nil
end

--- Verifica se o valor fornecido não é nulo (not nil).
--- @param valor any O valor a ser avaliado.
--- @return boolean Retorna true se o valor não for nil, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsNotNil(valor)
    return valor ~= nil
end

--- Retorna o valor original ou um valor padrão caso o original seja nulo (nil).
--- @param valor any O valor a ser validado.
--- @param valorPadrao any O valor alternativo retornado caso o primeiro seja nulo.
--- @return any O valor original ou o valor padrão.
function LKS_EletricidadeConstrucao.Utils.Validation.OrDefault(valor, valorPadrao)
    if valor == nil then
        return valorPadrao
    end
    return valor
end

-- ============================================================================
-- VERIFICAÇÕES DE TIPO
-- ============================================================================

--- Verifica se o valor fornecido é um número.
--- @param valor any O valor a ser avaliado.
--- @return boolean Retorna true se for um número, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(valor)
    return type(valor) == "number"
end

--- Verifica se o valor fornecido é uma string (texto).
--- @param valor any O valor a ser avaliado.
--- @return boolean Retorna true se for uma string, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsString(valor)
    return type(valor) == "string"
end

--- Verifica se o valor fornecido é um booleano (verdadeiro/falso).
--- @param valor any O valor a ser avaliado.
--- @return boolean Retorna true se for um booleano, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsBoolean(valor)
    return type(valor) == "boolean"
end

--- Verifica se o valor fornecido é uma tabela.
--- @param valor any O valor a ser avaliado.
--- @return boolean Retorna true se for uma tabela, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsTable(valor)
    return type(valor) == "table"
end

--- Verifica se o valor fornecido é uma função.
--- @param valor any O valor a ser avaliado.
--- @return boolean Retorna true se for uma função, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsFunction(valor)
    return type(valor) == "function"
end

--- Retorna o tipo em formato texto do valor avaliado.
--- @param valor any O valor a ser avaliado.
--- @return string O nome do tipo retornado pela engine (ex: "table", "string", "number").
function LKS_EletricidadeConstrucao.Utils.Validation.GetType(valor)
    return type(valor)
end

-- ============================================================================
-- VALIDAÇÕES DE INTERVALOS E NÚMEROS
-- ============================================================================

--- Valida se um número está contido dentro de um intervalo inclusivo.
--- @param valor number O número a ser validado.
--- @param limiteMinimo number O valor mínimo aceitável.
--- @param limiteMaximo number O valor máximo aceitável.
--- @param nomeVariavel string|nil O nome descritivo da variável para enriquecer a mensagem de erro.
--- @return boolean, string|nil Retorna true se estiver no intervalo, ou false acompanhado de uma mensagem de erro estruturada.
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateRange(valor, limiteMinimo, limiteMaximo, nomeVariavel)
    nomeVariavel = nomeVariavel or "valor"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(valor) then
        return false, nomeVariavel .. " deve ser um número"
    end
    
    if valor < limiteMinimo or valor > limiteMaximo then
        return false, string.format("%s deve estar entre %s e %s (recebido %s)", 
            nomeVariavel, tostring(limiteMinimo), tostring(limiteMaximo), tostring(valor))
    end
    
    return true, nil
end

--- Valida se um número é estritamente maior que zero (positivo).
--- @param valor number O número a ser validado.
--- @param nomeVariavel string|nil O nome descritivo da variável para enriquecer a mensagem de erro.
--- @return boolean, string|nil Retorna true se for positivo, ou false com a mensagem de erro correspondente.
function LKS_EletricidadeConstrucao.Utils.Validation.ValidatePositive(valor, nomeVariavel)
    nomeVariavel = nomeVariavel or "valor"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(valor) then
        return false, nomeVariavel .. " deve ser um número"
    end
    
    if valor <= 0 then
        return false, nomeVariavel .. " deve ser positivo (recebido " .. tostring(valor) .. ")"
    end
    
    return true, nil
end

--- Valida se um número é maior ou igual a zero (não-negativo).
--- @param valor number O número a ser validado.
--- @param nomeVariavel string|nil O nome descritivo da variável para enriquecer a mensagem de erro.
--- @return boolean, string|nil Retorna true se for não-negativo, ou false com a mensagem de erro correspondente.
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateNonNegative(valor, nomeVariavel)
    nomeVariavel = nomeVariavel or "valor"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(valor) then
        return false, nomeVariavel .. " deve ser um número"
    end
    
    if valor < 0 then
        return false, nomeVariavel .. " não deve ser negativo (recebido " .. tostring(valor) .. ")"
    end
    
    return true, nil
end

-- ============================================================================
-- VALIDAÇÕES DE TEXTO (STRINGS)
-- ============================================================================

--- Verifica se uma string está vazia ou consiste apenas de espaços em branco.
--- @param texto string O texto a ser avaliado.
--- @return boolean Retorna true se estiver vazio ou com espaços em branco, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsEmptyString(texto)
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsString(texto) then
        return true
    end
    return texto == "" or texto:match("^%s*$") ~= nil
end

--- Valida se uma string é válida e não está vazia.
--- @param texto string O texto a ser validado.
--- @param nomeVariavel string|nil O nome descritivo da variável para enriquecer a mensagem de erro.
--- @return boolean, string|nil Retorna true se for válida e populada, ou false com a mensagem de erro.
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateNotEmpty(texto, nomeVariavel)
    nomeVariavel = nomeVariavel or "texto"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsString(texto) then
        return false, nomeVariavel .. " deve ser um texto"
    end
    
    if LKS_EletricidadeConstrucao.Utils.Validation.IsEmptyString(texto) then
        return false, nomeVariavel .. " não pode estar vazio"
    end
    
    return true, nil
end

--- Valida se o comprimento de um texto está contido em um intervalo de tamanho específico.
--- @param texto string O texto a ser avaliado.
--- @param comprimentoMinimo number O comprimento de caracteres mínimo aceitável.
--- @param comprimentoMaximo number O comprimento de caracteres máximo aceitável.
--- @param nomeVariavel string|nil O nome descritivo da variável para enriquecer a mensagem de erro.
--- @return boolean, string|nil Retorna true se estiver no intervalo de comprimento, ou false com a mensagem de erro.
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateLength(texto, comprimentoMinimo, comprimentoMaximo, nomeVariavel)
    nomeVariavel = nomeVariavel or "texto"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsString(texto) then
        return false, nomeVariavel .. " deve ser um texto"
    end
    
    local comprimento = string.len(texto)
    
    if comprimento < comprimentoMinimo or comprimento > comprimentoMaximo then
        return false, string.format("o comprimento de %s deve estar entre %d e %d (recebido %d)",
            nomeVariavel, comprimentoMinimo, comprimentoMaximo, comprimento)
    end
    
    return true, nil
end

-- ============================================================================
-- VALIDAÇÕES DE TABELAS
-- ============================================================================

--- Valida se uma tabela existe e não está vazia.
--- @param tabela table A tabela a ser validada.
--- @param nomeVariavel string|nil O nome descritivo da variável para enriquecer a mensagem de erro.
--- @return boolean, string|nil Retorna true se a tabela for populada, ou false com a mensagem de erro correspondente.
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateNotEmptyTable(tabela, nomeVariavel)
    nomeVariavel = nomeVariavel or "tabela"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsTable(tabela) then
        return false, nomeVariavel .. " deve ser uma tabela"
    end
    
    if LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(tabela) then
        return false, nomeVariavel .. " não pode estar vazia"
    end
    
    return true, nil
end

--- Valida se uma tabela contém todas as chaves obrigatórias requeridas.
--- @param tabela table A tabela a ser validada.
--- @param chavesObrigatorias table Um vetor contendo os nomes de chaves requeridas na tabela.
--- @param nomeVariavel string|nil O nome descritivo da tabela para a mensagem de erro.
--- @return boolean, string|nil Retorna true se todas as chaves estiverem presentes, ou false com a mensagem de erro identificando a chave faltante.
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateKeys(tabela, chavesObrigatorias, nomeVariavel)
    nomeVariavel = nomeVariavel or "tabela"
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsTable(tabela) then
        return false, nomeVariavel .. " deve ser uma tabela"
    end
    
    for _, chave in ipairs(chavesObrigatorias) do
        if tabela[chave] == nil then
            return false, nomeVariavel .. " está sem a chave obrigatória: " .. tostring(chave)
        end
    end
    
    return true, nil
end

-- ============================================================================
-- VALIDAÇÕES DE COORDENADAS DO MAPA
-- ============================================================================

--- Valida se os valores das coordenadas espaciais informadas são números aceitáveis e válidos.
--- @param coordenadaX number A coordenada no eixo X.
--- @param coordenadaY number A coordenada no eixo Y.
--- @param coordenadaZ number|nil A coordenada no eixo Z (opcional).
--- @return boolean, string|nil Retorna true se as coordenadas forem numéricas e válidas dentro dos limites do jogo, ou false com a mensagem correspondente.
function LKS_EletricidadeConstrucao.Utils.Validation.ValidateCoordinates(coordenadaX, coordenadaY, coordenadaZ)
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(coordenadaX) then
        return false, "A coordenada X deve ser um número"
    end
    
    if not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(coordenadaY) then
        return false, "A coordenada Y deve ser um número"
    end
    
    if coordenadaZ ~= nil and not LKS_EletricidadeConstrucao.Utils.Validation.IsNumber(coordenadaZ) then
        return false, "A coordenada Z deve ser um número"
    end
    
    -- Utiliza utilitários geométricos do mod para validar limites geográficos no PZ
    if not LKS_EletricidadeConstrucao.Utils.Geometry.IsValidCoordinate(coordenadaX, coordenadaY, coordenadaZ) then
        return false, "As coordenadas estão fora dos limites físicos do jogo"
    end
    
    return true, nil
end

-- ============================================================================
-- VALIDAÇÕES DE OBJETOS DO PROJECT ZOMBOID (INTEROPERABILIDADE JAVA)
-- ============================================================================

--- Valida se o objeto fornecido é uma instância Java da classe de Gerador do jogo (IsoGenerator).
--- @param objeto any O objeto Java a ser verificado.
--- @return boolean Retorna true se for uma instância de IsoGenerator, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsGenerator(objeto)
    if not objeto then 
        return false 
    end
    return instanceof(objeto, "IsoGenerator")
end

--- Valida se o objeto fornecido é uma instância Java da classe de Interruptor de Luz do jogo (IsoLightSwitch).
--- @param objeto any O objeto Java a ser verificado.
--- @return boolean Retorna true se for uma instância de IsoLightSwitch, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsLightSwitch(objeto)
    if not objeto then 
        return false 
    end
    return instanceof(objeto, "IsoLightSwitch")
end

--- Valida se o objeto fornecido é uma instância Java da classe de Quadrado da Grade (Tile) do jogo (IsoGridSquare).
--- @param objeto any O objeto Java a ser verificado.
--- @return boolean Retorna true se for uma instância de IsoGridSquare, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsGridSquare(objeto)
    if not objeto then 
        return false 
    end
    return instanceof(objeto, "IsoGridSquare")
end

--- Valida se o objeto fornecido é uma instância Java da classe base de Objeto do Mundo do jogo (IsoObject).
--- @param objeto any O objeto Java a ser verificado.
--- @return boolean Retorna true se for uma instância de IsoObject, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Validation.IsIsoObject(objeto)
    if not objeto then 
        return false 
    end
    return instanceof(objeto, "IsoObject")
end

-- ============================================================================
-- OPERAÇÕES DE ASSERÇÃO (DISPARAM ERROS DE SIMULAÇÃO)
-- ============================================================================

--- Garante que um valor não é nulo, disparando um erro caso seja.
--- @param valor any O valor a ser avaliado.
--- @param mensagemErro string|nil A mensagem de erro customizada caso a asserção falhe.
function LKS_EletricidadeConstrucao.Utils.Validation.AssertNotNil(valor, mensagemErro)
    if valor == nil then
        error(mensagemErro or "O valor não pode ser nulo (nil)")
    end
end

--- Garante que uma condição booleana é verdadeira, disparando um erro caso seja falsa.
--- @param condicao boolean A condição lógica a ser testada.
--- @param mensagemErro string|nil A mensagem de erro customizada caso a asserção falhe.
function LKS_EletricidadeConstrucao.Utils.Validation.Assert(condicao, mensagemErro)
    if not condicao then
        error(mensagemErro or "Falha de asserção lógica")
    end
end

--- Garante que um valor pertence ao tipo de dado esperado em Lua, disparando um erro caso contrário.
--- @param valor any O valor a ser verificado.
--- @param tipoEsperado string O nome do tipo Lua esperado (ex: "string", "table").
--- @param nomeVariavel string|nil O nome descritivo da variável analisada.
function LKS_EletricidadeConstrucao.Utils.Validation.AssertType(valor, tipoEsperado, nomeVariavel)
    local tipoAtual = type(valor)
    if tipoAtual ~= tipoEsperado then
        error(string.format("A variável %s deve ser do tipo %s (recebido %s)", 
            nomeVariavel or "valor", tipoEsperado, tipoAtual))
    end
end

-- ============================================================================
-- INICIALIZAÇÃO E REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Utils.Validation", "2.0.0")

return LKS_EletricidadeConstrucao.Utils.Validation
