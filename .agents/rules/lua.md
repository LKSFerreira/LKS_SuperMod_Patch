---
trigger: model_decision
description: Regras para Lua, padrão de tipos EmmyLua e documentação estruturada.
---

# Regras Específicas para Lua

Este arquivo define todas as regras específicas para projetos Lua, incluindo a integração e correção de scripts em Project Zomboid.

## 1: Padrão de Tipagem e Anotações (EmmyLua)

Como Lua é uma linguagem dinamicamente tipada, usamos anotações **EmmyLua** (compatíveis com LLLS/Lua Language Server) para documentar a tipagem estática e interfaces.

**Diretrizes:**
- Declare tipos de parâmetros com `---@param nome_parametro tipo descricao`.
- Declare retornos com `---@return tipo descricao`.
- Defina tipos customizados ou tabelas globais do Project Zomboid (ex: `IsoPlayer`, `IsoGridSquare`, `IsoGenerator`) usando anotações explícitas de classe/tipo.

## 2: Padrão de Código e Nomenclatura (Clean Code)
- **Idioma e Nomenclatura (pt-BR)**: Em funções e variáveis de autoria própria do projeto (não herdadas de APIs nativas do PZ ou de mods externos), use **português estrito** e **sem abreviações** (ex: `quadradoAlvo` em vez de `sq`, `coordenadaX` em vez de `cx`).
- **Escopo de Variáveis**: Sempre prefira o escopo local (`local`) para funções e variáveis internas a fim de evitar poluição global e problemas de concorrência/conflitos de carregamento de mods.

## 3: Padrão de Documentação de Funções (Docstrings Lua)

O desenvolvedor deve seguir o formato estruturado do EmmyLua no início das declarações.

**Estrutura Obrigatória:**
1. **Resumo**: O que a função/método faz (em pt-BR).
2. **Detalhamento (Opcional)**: Regras de negócio e validações.
3. **Exemplo**: Bloco de código funcional usando markdown (`--- ```lua`).
4. **Typing**: Anotações EmmyLua de argumentos e retornos.

**Template Canônico (Referência Absoluta):**

```lua
--- Cria e valida o estado elétrico de um novo aparelho.
---
--- Esta função gerencia as conexões lógicas internas do circuito.
---
--- **Exemplo:**
--- ```lua
--- local sucesso = registrarAparelho(gerador, "geladeira", 120)
--- print(sucesso) -- Output: true
--- ```
---
--- @param gerador IsoGenerator O gerador responsável por alimentar o aparelho.
--- @param tipoAparelho string O tipo de aparelho (ex: "geladeira", "freezer").
--- @param consumo Watts O consumo total de potência.
--- @return boolean sucesso Retorna true se a operação foi executada com sucesso.
local function registrarAparelho(gerador, tipoAparelho, consumo)
    -- ... implementação ...
end
```
