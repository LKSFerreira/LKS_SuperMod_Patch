# Organizador de Itens — Gerenciamento Automático de Inventário

Documentação técnica do sistema de organização automática de itens do LKS SuperMod Patch. Feature 100% original, sem fagocitação de mods externos.

---

## Conceito

O Organizador permite ao jogador **favoritar containers** no mundo (armários, estantes, freezers, bags no chão) e com um clique no botão **"Guardar Itens"** no painel de inventário, o personagem caminha automaticamente até cada container favoritado e deposita itens correspondentes (mesmo `fullType` já existente no destino).

---

## Arquitetura

### Arquivos

| Arquivo | Responsabilidade |
|---------|-----------------|
| `LKS_Organizer_Motor.lua` | Lógica central: scan 50×50 (todos andares), correspondência por fullType, enfileiramento de ações |
| `LKS_Organizer_Handler.lua` | Botão "Guardar Itens" via `ISInventoryWindowContainerControls.AddHandler` |
| `LKS_Organizer_FavoritoVisual.lua` | Botão "Favoritos" (inventário) + botão ⭐ (Loot Window) + overlay estrela na sidebar |
| `LKS_Organizer_ContextMenu.lua` | Opção "Favoritar/Desfavoritar" no menu de contexto do mundo |
| `LKS_Menu_Favoritar.png` | Ícone estrela 32×32 |

### Pontos de Integração com o Vanilla

| Sistema Vanilla | Como Integramos |
|-----------------|-----------------|
| `ISInventoryWindowContainerControls.AddHandler()` | Botão "Guardar Itens" e "Favoritos" no painel do jogador |
| `ISLootWindowContainerControls.AddHandler()` | Botão ⭐ na barra de controles do container selecionado |
| `ISInventoryPage:addContainerButton()` | Monkey patch (OnGameStart) para overlay de estrela na sidebar |
| `Events.OnFillWorldObjectContextMenu` | Opção Favoritar/Desfavoritar no menu de contexto |
| `ISWalkToTimedAction` | Caminhar até container destino |
| `ISInventoryTransferAction` | Transferir item (com animação e validação) |
| `object:getModData()` | Persistência do estado de favorito |

---

## Como Funciona (Fluxo Completo)

### Favoritar um Container

1. Jogador aproxima-se de um container (armário, estante, etc.)
2. Duas formas de favoritar:
   - **Loot Window:** Clicar no botão ⭐ na barra de controles do container selecionado
   - **Menu de contexto:** Clique direito no objeto → "Favoritar para Guardar Itens"
3. O sistema grava `LKS_ContainerFavorito = true` no `modData` do IsoObject
4. Estrela aparece no ícone do container na sidebar da Loot Window

### Guardar Itens

1. Jogador clica "Guardar Itens" no painel de inventário (esquerdo)
2. **Scan:** Varre 50×50 tiles em TODOS os andares (Z=0 a Z=7)
   - Busca objetos fixos com `getContainerCount() > 0` e modData favorito
   - Busca `IsoWorldInventoryObject` (bags no chão) com modData favorito
3. **Correspondência:** Para cada container favoritado, compara `fullType` dos itens dentro com itens do jogador
   - Busca no inventário principal (itens soltos)
   - Busca em mochilas **equipadas** no corpo do jogador
   - Protege: equipados, favoritos, hotbar, containers vestidos
4. **Enfileiramento:** Para cada container com correspondências (ordenado por distância):
   - `ISWalkToTimedAction` → caminhar até tile adjacente
   - `ISInventoryTransferAction` × N → transferir cada item
5. Personagem executa a fila sequencialmente (walk → deposit → walk → deposit...)

---

## O Que Funciona

- ✅ Scan multi-andar (Z=0 a Z=7)
- ✅ Correspondência por `fullType` (match exato)
- ✅ Busca em mochilas equipadas no jogador
- ✅ Proteção de itens equipados/favoritos/hotbar
- ✅ Pathfinding com `ISWalkToTimedAction` (contorna obstáculos)
- ✅ Transferência real com animação (`ISInventoryTransferAction`)
- ✅ Cancelamento por movimento do jogador (comportamento padrão)
- ✅ Bags/mochilas dropadas no chão como containers favoritáveis
- ✅ Persistência via `modData` (sobrevive save/load)
- ✅ Feedback via `Say()` quando não há favoritos ou itens correspondentes
- ✅ Overlay de estrela na sidebar da Loot Window (indica visualmente)
- ✅ Botão ⭐ na barra de controles da Loot Window (toggle rápido)
- ✅ Menu de contexto como alternativa para favoritar
- ✅ Botão "Favoritos" com modal listando containers e distâncias

## O Que Não Funciona / Limitações Conhecidas

- ⚠️ `AdjacentFreeTileFinder.Find()` pode retornar nil se o jogador está longe do container destino → mitigado com fallback manual de tiles vizinhos
- ⚠️ Containers de veículos não suportados (Fase 4 futura)
- ⚠️ Se um container está atrás de porta trancada ou parede sem acesso, é pulado silenciosamente
- ⚠️ Mochilas favoritadas no chão perdem o favorito ao serem pegas (modData do IsoWorldInventoryObject é destruído) — comportamento correto e desejado (proteção natural)
- ⚠️ Se a mochila do jogador não está "equipada" (apenas no inventário), itens dentro não são considerados como fonte

## O Que Foi Tentado e Não Resolveu

| Abordagem | Por que não funcionou |
|-----------|----------------------|
| `ISPathFindAction:pathToLocationF()` para caminhar | Incompatível com `ISInventoryTransferAction` — a validação de containers acessíveis falhava após o pathfind |
| `jogador:getInventory():getItems()` para todos os itens | Não inclui itens dentro de mochilas equipadas — apenas itens soltos no inventário principal |
| `AdjacentFreeTileFinder.Find(square, player)` como única validação | Retorna nil quando jogador está longe do destino (não valida "potencial", valida "agora") |
| Scan apenas no Z do jogador | Bases com múltiplos andares não encontravam containers em outros pisos |
| Overlay de estrela sem atualizar `objetoPai` em botões reciclados | Botões do `buttonPool` mantinham referência do container ANTIGO — estrela aparecia inconsistentemente |

---

## APIs Vanilla Utilizadas

| API | Propósito |
|-----|-----------|
| `ISInventoryWindowContainerControls.AddHandler()` | Registrar botões no painel do jogador |
| `ISLootWindowContainerControls.AddHandler()` | Registrar botão ⭐ na Loot Window |
| `ISInventoryPage:addContainerButton()` | Monkey patch para overlay de estrela |
| `Events.OnFillWorldObjectContextMenu.Add()` | Menu de contexto Favoritar |
| `Events.OnGameStart.Add()` | Registro tardio do monkey patch |
| `object:getModData()` | Persistência de favoritos |
| `item:getFullType()` | Correspondência por tipo |
| `item:getContainer()` | Obter container real do item (mochila vs inventário) |
| `item:isFavorite()` / `item:isEquipped()` | Proteção de itens |
| `ISWalkToTimedAction:new(jogador, square)` | Caminhar até container |
| `ISInventoryTransferAction:new(jogador, item, src, dest)` | Transferir com animação |
| `AdjacentFreeTileFinder.Find(square, player)` | Encontrar tile adjacente |
| `getCell():getGridSquare(x, y, z)` | Scan de tiles |
| `square:getObjects()` / `square:getWorldObjects()` | Varrer objetos do tile |
| `square:isFree()` / `square:isBlockedTo()` | Fallback de tile adjacente |
| `ISMoveableSpriteProps.fromObject()` | Nome legível do container |
| `Translator.getMoveableDisplayName()` | Tradução do nome |
| `getPlayerHotbar(n):isInHotbar(item)` | Proteção de hotbar |

---

## Compatibilidade com Outros Mods

| Mod | Impacto | Solução |
|-----|---------|---------|
| **TwisTonFire - Inventory** | Faz monkey patch no `addContainerButton` | Nosso patch registra via `OnGameStart` (final da cadeia) |
| **Neat Rocco** | Não toca no inventário/Loot Window | Zero conflito |
| **Quick Sort B42** | Usa menus de contexto (escopo diferente) | Zero conflito — coexistem |

---

## Tradução

Chaves em `IG_UI.json` (PT-BR com fallback / EN):

| Chave | PT-BR | EN |
|-------|-------|-----|
| `IGUI_LKS_Organizer_GuardarItens` | Guardar Itens | Store Items |
| `IGUI_LKS_Organizer_Favoritar` | Favoritar para Guardar Itens | Favorite for Item Storage |
| `IGUI_LKS_Organizer_Desfavoritar` | Desfavoritar | Unfavorite |
| `IGUI_LKS_Organizer_NenhumFavorito` | Nenhum container favoritado... | No containers favorited... |
| `IGUI_LKS_Organizer_NenhumItem` | Nenhum item para guardar... | No items to store... |
| `IGUI_LKS_Organizer_Tooltip` | Transfere itens automaticamente... | Auto-transfer items... |
| `IGUI_LKS_Organizer_ContainerInacessivel` | Container inacessivel, pulando... | Container unreachable... |
| `IGUI_LKS_Organizer_Favoritos_Botao` | Favoritos | Favorites |
| `IGUI_LKS_Organizer_Favoritos_Tooltip` | Ver containers favoritados | View favorited containers |
| `IGUI_LKS_Organizer_Favoritos_Titulo` | Containers Favoritados | Favorited Containers |
| `IGUI_LKS_Organizer_Favoritos_Instrucao` | Para remover: clique direito... | To remove: right-click... |
