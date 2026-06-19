# Postmortem — Detecção de IsoWorldInventoryObject no Menu de Contexto

**Data:** 19/06/2026
**Feature:** Menu de contexto do botijão de propano (CAMINHO 2: clique no item no chão)

---

## Problema

Ao clicar com botão direito em um botijão no chão, nosso submenu ("Botijão > Pegar + Instalar + Informações") não aparecia. O menu vanilla "Pegar" e "Posicionamento 3D Estendido" detectavam o item corretamente, mas nosso handler não.

---

## Investigação

### Tentativa 1: Detecção direta via `objetosMundo`
O handler `OnFillWorldObjectContextMenu` recebe `(player, context, worldobjects, test)`. Iteramos `worldobjects` procurando `IsoWorldInventoryObject` com `instanceof`. **Funcionava apenas ao clicar no pixel exato do hitbox do item** — área clicável minúscula.

**Causa:** Items dropados no chão têm `WorldStaticModel` (modelo 3D) com altura. Na visão isométrica, o topo do modelo aparece 1-2 tiles acima do tile real. O engine registra o clique no tile visual, não no tile do item.

### Tentativa 2: Varredura 3x3 ao redor do tile clicado
Escaneamos tiles adjacentes para compensar o offset isométrico. **Problema:** o menu aparecia ao clicar em tiles vizinhos que NÃO tinham botijão — comportamento incorreto.

### Tentativa 3: Compensação isométrica direcional
Verificamos tiles específicos (abaixo-esquerda, acima-direita) para compensar a projeção iso. **Problema:** direção inconsistente dependendo da posição da câmera.

### Tentativa 4: Extrair referência do menu vanilla "Pegar"
Tentamos acessar `param1` das opções dentro do submenu "Pegar" vanilla. **Problema:** opções criadas pelo Java não expõem `param1` via `ipairs` — iteração por índice numérico também falhou.

### Tentativa 5 (SOLUÇÃO): Extrair do "Posicionamento 3D Estendido"
Descobrimos que a opção vanilla "Posicionamento 3D Estendido" (`ContextMenu_ExtendedPlacement`) é criada pelo Java via `ISWorldObjectContextMenuLogic.createMenuEntries`, que usa `IsoObjectPicker` (raycasting 3D→2D preciso).

**Achado crítico via debug:**
```
opcao[1]: name=Gas Tank 45kg
  param1 = IsoPlayer (JOGADOR, não o item!)
  target = IsoWorldInventoryObject (O ITEM!)
```

O campo `target` contém o `IsoWorldInventoryObject`. O campo `param1` contém o jogador. **Invertido** do que se espera pela assinatura `addOption(name, target, onSelect, param1, ...)`.

---

## Solução Final

```lua
local textoPlacement = getText("ContextMenu_ExtendedPlacement")
local opcaoPlacement = menuContexto:getOptionFromName(textoPlacement)
if opcaoPlacement and opcaoPlacement.subOption then
    local submenu = menuContexto:getSubMenu(opcaoPlacement.subOption)
    if submenu then
        local opcaoItem = submenu:getOptionFromName(nomeDoItem)
        if opcaoItem and opcaoItem.target then
            local worldItem = opcaoItem.target  -- IsoWorldInventoryObject
        end
    end
end
```

---

## Lições Aprendidas

1. **`IsoObjectPicker` não tem API Lua para world items** — existe `PickCorpse`, `PickDoor`, `PickWindow`, etc., mas NÃO `PickWorldItem`. A detecção precisa de items no chão é exclusiva do Java.

2. **Reutilizar detecção vanilla é legítimo** — em vez de reimplementar raycasting isométrico, reutilizar o resultado que o Java já calculou. A opção "Posicionamento 3D Estendido" é vanilla e sempre existe.

3. **Campos de opção: `target` ≠ `param1`** — para opções criadas pelo Java em `ISWorldObjectContextMenuLogic`, o mapeamento é `target = objeto do mundo`, `param1 = jogador`. Não assumir que `param1` é sempre o objeto.

4. **`ipairs` não funciona em opções Java** — usar `getOptionFromName(nome)` que funciona independente de como a opção foi criada (Lua ou Java).

5. **`removeOptionByName` funciona em opções Java** — mesmo padrão usado pelo mod Generator Powered Buildings para remover opções vanilla do submenu do gerador.
