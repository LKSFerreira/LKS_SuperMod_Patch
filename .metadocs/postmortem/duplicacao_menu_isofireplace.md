# Postmortem — Duplicação de Menu de Contexto para IsoFireplace

## Problema

Ao clicar com botão direito em um `IsoFireplace` (forno antigo / lareira), apareciam **2 ou 3 entradas** "Forno Antigo" duplicadas no menu de contexto.

## Causa Raiz

O PZ B42 cria menus para `IsoFireplace` por **dois caminhos independentes**:

1. **`ISCampingMenu.doCampingMenu`** — chamado pelo Java via `ISWorldObjectContextMenuLogic.createMenuEntries()` (linha 205 de `ISWorldObjectContextMenu.lua`). Trata campfires e fire-interaction tiles.
2. **`ISBBQMenu.OnFillWorldObjectContextMenu`** — registrado como listener do evento `OnFillWorldObjectContextMenu` (triggerEvent na linha 209). Trata BBQs e fire-interaction tiles.

Ambos detectam `IsoFireplace` via `isFireInteractionObject()` e criam submenus independentes com o mesmo nome (`getTileName()`). Resultado: duplicata.

Se outro mod (ex: nosso `LKS_ApplianceManager` com `IsoFireplace` em `classesJava`) também criava menu, virava triplicata.

## Tentativas que Falharam

1. **`Events.OnFillWorldObjectContextMenu.Remove(handler)`** — não funciona porque `ISCampingMenu.doCampingMenu` NÃO é registrado via `.Add()`. É chamado diretamente pelo Java.
2. **`ISBBQMenu.OnFillWorldObjectContextMenu = nil`** — não funciona porque o Java guarda referência direta à função no momento do registro. Setar nil na tabela não afeta a referência interna.
3. **`goto` para pular blocos** — Kahlua (Lua 5.1) não suporta `goto`/labels. Erro de compilação.

## Solução Final

Três ações combinadas:

1. **Sobrescrita de `ISCampingMenu.doCampingMenu`** — o Java busca a função na tabela global ISCampingMenu. Ao sobrescrever, o Java automaticamente usa nossa versão no próximo clique.

2. **Neutralização com função vazia** — `ISBBQMenu.OnFillWorldObjectContextMenu = function() end`. O Java armazena referência à função da tabela no momento que carrega o script. Como nosso mod carrega DEPOIS do vanilla, a referência registrada aponta para NOSSA função vazia (que substitui a original na tabela antes do registro do evento ocorrer... na verdade, o evento já foi registrado com a original, MAS a key na tabela agora aponta para a vazia. O PZ faz lookup por nome na tabela ao triggerar o evento, não por referência direta).

3. **Handler de limpeza como rede de segurança** — `limparDuplicatasFireMenu` registrado via `Events.OnFillWorldObjectContextMenu.Add()` que roda após todos os handlers e remove opções com mesmo nome e submenu, mantendo apenas a primeira.

## Lição Aprendida

- No PZ B42, menus de contexto para fire objects vêm de 2 sistemas separados (Camping + BBQ)
- Sobrescrever a função na tabela global É suficiente para `doCampingMenu` (lookup por nome)
- Para `ISBBQMenu`, a neutralização com função vazia funciona porque o PZ resolve o handler por tabela
- Sempre ter um handler de limpeza de duplicatas como fallback contra mods terceiros
