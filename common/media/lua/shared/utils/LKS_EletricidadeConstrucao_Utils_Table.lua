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

-- ARQUIVO: LKS_EletricidadeConstrucao_Utils_Table.lua
-- OBJETIVO: Funções utilitárias de manipulação de tabelas (cópia profunda, mesclagem, contagem, etc.)
-- Versão: 2.0.0-alpha
-- Data: 22 de Fevereiro de 2026

-- Garante que o namespace existe antes de carregar o módulo
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Utils_Table] Namespace LKS_EletricidadeConstrucao não encontrado - pulando carregamento do módulo")
    return
end

-- ============================================================================
-- CÓPIA DE TABELAS
-- ============================================================================

--- Realiza uma cópia rasa (shallow copy) de uma tabela (apenas o primeiro nível).
--- @param tabela table A tabela a ser copiada.
--- @return table A nova tabela contendo a cópia rasa.
function LKS_EletricidadeConstrucao.Utils.Table.ShallowCopy(tabela)
    if type(tabela) ~= "table" then
        return tabela
    end
    
    local copia = {}
    for chave, valor in pairs(tabela) do
        copia[chave] = valor
    end
    return copia
end

--- Realiza uma cópia profunda (deep copy) de uma tabela de forma recursiva, tratando referências circulares.
--- @param tabela table A tabela a ser copiada.
--- @param visitados table|nil Uso interno para rastreamento de referências circulares.
--- @return table A nova tabela contendo a cópia profunda.
function LKS_EletricidadeConstrucao.Utils.Table.DeepCopy(tabela, visitados)
    if type(tabela) ~= "table" then
        return tabela
    end
    
    -- Evita recursão infinita se houver referências circulares
    visitados = visitados or {}
    if visitados[tabela] then
        return visitados[tabela]
    end
    
    local copia = {}
    visitados[tabela] = copia
    
    for chave, valor in pairs(tabela) do
        copia[LKS_EletricidadeConstrucao.Utils.Table.DeepCopy(chave, visitados)] = 
            LKS_EletricidadeConstrucao.Utils.Table.DeepCopy(valor, visitados)
    end
    
    return copia
end

-- ============================================================================
-- MESCLAGEM DE TABELAS
-- ============================================================================

--- Mescla duas tabelas (cópia rasa), modificando a tabela de destino no local.
--- @param destino table A tabela que receberá os novos valores.
--- @param origem table A tabela que contém os valores a serem copiados.
--- @return table A tabela de destino modificada.
function LKS_EletricidadeConstrucao.Utils.Table.Merge(destino, origem)
    for chave, valor in pairs(origem) do
        destino[chave] = valor
    end
    return destino
end

--- Mescla profundamente (deep merge) duas tabelas de forma recursiva.
--- @param destino table A tabela que receberá as alterações.
--- @param origem table A tabela que contém os novos valores.
--- @return table A tabela de destino modificada.
function LKS_EletricidadeConstrucao.Utils.Table.DeepMerge(destino, origem)
    for chave, valor in pairs(origem) do
        if type(valor) == "table" and type(destino[chave]) == "table" then
            LKS_EletricidadeConstrucao.Utils.Table.DeepMerge(destino[chave], valor)
        else
            destino[chave] = valor
        end
    end
    return destino
end

-- ============================================================================
-- CONTAGEM E VERIFICAÇÕES
-- ============================================================================

--- Conta a quantidade total de elementos em uma tabela (funciona para índices numéricos e associativos).
--- @param tabela table A tabela a ser contada.
--- @return number O número total de elementos.
function LKS_EletricidadeConstrucao.Utils.Table.Count(tabela)
    local contador = 0
    for _ in pairs(tabela) do
        contador = contador + 1
    end
    return contador
end

--- Verifica se uma tabela está vazia.
--- Nota: A engine Kahlua do Project Zomboid não possui a função global next(). Por isso, usamos pairs().
--- @param tabela table A tabela a ser verificada.
--- @return boolean Retorna true se a tabela estiver vazia, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Table.IsEmpty(tabela)
    for _ in pairs(tabela) do 
        return false 
    end
    return true
end

--- Verifica se a tabela contém um valor específico.
--- @param tabela table A tabela a ser pesquisada.
--- @param valorDesejado any O valor a ser encontrado na tabela.
--- @return boolean Retorna true se o valor for encontrado, caso contrário false.
function LKS_EletricidadeConstrucao.Utils.Table.Contains(tabela, valorDesejado)
    for _, valor in pairs(tabela) do
        if valor == valorDesejado then
            return true
        end
    end
    return false
end

--- Procura a primeira ocorrência de um valor em um vetor/array e retorna seu índice numérico.
--- @param tabela table A lista onde a pesquisa será realizada.
--- @param valorDesejado any O valor a ser localizado.
--- @return number|nil O índice da primeira ocorrência, ou nil caso não seja encontrado.
function LKS_EletricidadeConstrucao.Utils.Table.IndexOf(tabela, valorDesejado)
    for indice, valor in ipairs(tabela) do
        if valor == valorDesejado then
            return indice
        end
    end
    return nil
end

-- ============================================================================
-- FILTRAGEM E MAPEAMENTO
-- ============================================================================

--- Filtra os elementos de uma tabela usando uma função predicado de callback.
--- @param tabela table A tabela a ser filtrada.
--- @param predicado function A função de validação com assinatura (valor, chave) -> boolean.
--- @return table Uma nova tabela apenas com os elementos que passaram no predicado.
function LKS_EletricidadeConstrucao.Utils.Table.Filter(tabela, predicado)
    local resultado = {}
    for chave, valor in pairs(tabela) do
        if predicado(valor, chave) then
            resultado[chave] = valor
        end
    end
    return resultado
end

--- Mapeia e transforma os elementos de uma tabela aplicando uma função de callback em cada um.
--- @param tabela table A tabela a ser mapeada.
--- @param transformador function A função transformadora com assinatura (valor, chave) -> novoValor.
--- @return table Uma nova tabela contendo os elementos transformados.
function LKS_EletricidadeConstrucao.Utils.Table.Map(tabela, transformador)
    local resultado = {}
    for chave, valor in pairs(tabela) do
        resultado[chave] = transformador(valor, chave)
    end
    return resultado
end

--- Procura pelo primeiro elemento na tabela que satisfaça a função predicado de callback.
--- @param tabela table A tabela a ser pesquisada.
--- @param predicado function A função de busca com assinatura (valor, chave) -> boolean.
--- @return any, any O valor e a chave do primeiro elemento correspondente, ou nil, nil.
function LKS_EletricidadeConstrucao.Utils.Table.Find(tabela, predicado)
    for chave, valor in pairs(tabela) do
        if predicado(valor, chave) then
            return valor, chave
        end
    end
    return nil, nil
end

-- ============================================================================
-- CHAVES E VALORES
-- ============================================================================

--- Retorna todas as chaves (keys) presentes na tabela como um vetor numérico.
--- @param tabela table A tabela para extrair as chaves.
--- @return table Um vetor contendo todas as chaves.
function LKS_EletricidadeConstrucao.Utils.Table.Keys(tabela)
    local chaves = {}
    for chave, _ in pairs(tabela) do
        table.insert(chaves, chave)
    end
    return chaves
end

--- Retorna todos os valores (values) presentes na tabela como um vetor numérico.
--- @param tabela table A tabela para extrair os valores.
--- @return table Um vetor contendo todos os valores.
function LKS_EletricidadeConstrucao.Utils.Table.Values(tabela)
    local valores = {}
    for _, valor in pairs(tabela) do
        table.insert(valores, valor)
    end
    return valores
end

--- Converte uma tabela em uma representação textual estruturada (usado para depuração).
--- @param tabela table A tabela a ser serializada para texto.
--- @param profundidadeMaxima number|nil O limite máximo de recursão estrutural (padrão: 3).
--- @param profundidadeAtual number|nil Rastreamento interno da profundidade atual de execução.
--- @return string A representação em texto estruturado da tabela.
function LKS_EletricidadeConstrucao.Utils.Table.ToString(tabela, profundidadeMaxima, profundidadeAtual)
    profundidadeMaxima = profundidadeMaxima or 3
    profundidadeAtual = profundidadeAtual or 0
    
    if type(tabela) ~= "table" then
        return tostring(tabela)
    end
    
    if profundidadeAtual >= profundidadeMaxima then
        return "{...}"
    end
    
    local partes = {}
    for chave, valor in pairs(tabela) do
        local chaveTexto = tostring(chave)
        local valorTexto
        
        if type(valor) == "table" then
            valorTexto = LKS_EletricidadeConstrucao.Utils.Table.ToString(valor, profundidadeMaxima, profundidadeAtual + 1)
        else
            valorTexto = tostring(valor)
        end
        
        table.insert(partes, chaveTexto .. " = " .. valorTexto)
    end
    
    return "{" .. table.concat(partes, ", ") .. "}"
end

-- ============================================================================
-- INICIALIZAÇÃO E REGISTRO DO MÓDULO
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Utils.Table", "2.0.0")

return LKS_EletricidadeConstrucao.Utils.Table
