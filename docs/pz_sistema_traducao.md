# Sistema de Tradução do Project Zomboid (Build 42)

## Estrutura de Arquivos

As traduções ficam em `media/lua/shared/Translate/<IDIOMA>/`:

```
Translate/
├── EN/          → Inglês (fallback obrigatório)
│   ├── ContextMenu.json
│   ├── IG_UI.json
│   ├── ItemName.json
│   └── Sandbox.json
└── PTBR/        → Português Brasil
    ├── ContextMenu.json
    ├── IG_UI.json
    ├── ItemName.json
    └── Sandbox.json
```

## Regra de Ouro

Cada tipo de string tem seu **arquivo dedicado**. O nome do arquivo NÃO define um prefixo
automático — as keys no JSON são usadas **exatamente como estão** em `getText()`.

| Arquivo         | Tipo de String          | Formato da Key no JSON          | Uso em Lua                          |
|----------------|-------------------------|----------------------------------|--------------------------------------|
| `ItemName.json` | Nomes de itens          | `"Module.ItemName"`             | `item:getDisplayName()` (automático) |
| `IG_UI.json`    | Strings de UI genéricas | `"IGUI_ChaveDescritiva"`        | `getText("IGUI_ChaveDescritiva")`    |
| `ContextMenu.json` | Opções de menu      | `"ContextMenu_Acao"`            | `getText("ContextMenu_Acao")`        |
| `Sandbox.json`  | Opções de sandbox       | `"Sandbox_ChaveDescritiva"`     | Engine resolve automaticamente       |

## ItemName.json — Tradução de Nomes de Itens

### Formato Correto

A key é o **fullType** do item (Módulo.NomeDoItem), sem prefixo `ItemName_`:

```json
{
    "LKS_Propano.LKS_Botijao15kg": "Botijão de Gás 15kg",
    "LKS_Propano.LKS_Botijao45kg": "Botijão de Gás 45kg",
    "LKS_Cooking.LKS_FogaoInducao": "Fogão de Indução"
}
```

### ❌ Formato ERRADO (não funciona para getDisplayName)

```json
{
    "ItemName_LKS_Propano.LKS_Botijao15kg": "Botijão de Gás 15kg"
}
```

Colocar no `IG_UI.json` com prefixo `ItemName_` faz `getText("ItemName_...")` funcionar
no Lua, mas o **engine Java** (`item:getDisplayName()`) NÃO encontra — ele busca
diretamente pelo fullType no `ItemName.json`.

### Consequência do Erro

- `item:getDisplayName()` → retorna o `DisplayName` do script (fallback inglês)
- Visualizador de itens / admin spawn → mostra nome em inglês
- Menus de contexto que usam `getDisplayName()` → nome errado

### DisplayName no Script de Item

Com `ItemName.json` configurado corretamente, **NÃO é necessário** o campo
`DisplayName` no script `.txt`. Removê-lo evita o aviso de deprecação do B42.

O engine resolve na seguinte ordem:
1. Busca key = `fullType` no `ItemName.json` do idioma ativo
2. Se não encontra, busca no `ItemName.json` do EN (fallback)
3. Se não encontra, usa `DisplayName` do script (se existir)
4. Se nada existe, retorna o ID cru do item

## Referência: Como Outros Mods Fazem

```json
// RealisticTemperature → Translate/EN/ItemName.json
{
    "RC_TempSimMod.Mov_RCElectricHeater1": "Electric Space Heater",
    "RC_TempSimMod.Mov_RCGasHeater": "Gas Space Heater"
}

// Vanilla → Translate/PTBR/ItemName.json
{
    "Base.PropaneTank": "Botijão de Gás",
    "Base.223Box": "Caixa de Munição .223"
}
```

## Padrão de Nomenclatura de Keys (IG_UI.json)

Para strings de UI do nosso mod, seguir:

```
IGUI_LKS_<Contexto>                 → Strings genéricas do mod
IGUI_LKS_EletricidadeConstrucao_*  → Sistema de eletricidade
IGUI_LKS_Debug_*                    → Ferramenta de debug
```

## DisplayCategory no Script

O campo `DisplayCategory` no script de itens define a aba/categoria no inventário.
Ele também precisa de tradução via `IG_UI.json`:

```json
// Script: DisplayCategory = FireSource
// IG_UI.json:
{ "IGUI_ItemCat_FireSource": "Fonte de Calor" }
```
