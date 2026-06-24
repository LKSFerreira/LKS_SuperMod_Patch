# Organizador de Itens — Guardar Itens Automaticamente

Funcionalidade QoL que permite ao jogador distribuir automaticamente itens do inventário para containers próximos "favoritados", baseado na correspondência de tipos de itens já existentes nesses containers.

---

## Visão Geral

O jogador favorita containers próximos (estantes, armários, freezers, guarda-roupas) e com um único clique no botão **[Guardar Itens]** na barra do inventário, o personagem caminha até cada container favoritado e deposita automaticamente os itens correspondentes.

### Princípio de Correspondência (MVP)

Um item do inventário é elegível para transferência se:

1. O container destino está **favoritado** (estrela ativa).
2. O container destino **já contém pelo menos 1 unidade** do mesmo tipo (`fullType`) do item no inventário.
3. O item **não está equipado**, **não é favorito** e **não está em hotbar**.

> **Inspiração direta:** Mecânica "Quick Stack to Nearby Chests" do Terraria — só empilha em containers que já possuem aquele item.

### Raio de Atuação

A funcionalidade opera em **toda a base do jogador** — não apenas containers adjacentes. O raio de busca padrão é de **50x50 tiles** (25 tiles em cada direção a partir do jogador). Isso permite que o jogador esteja em qualquer ponto da base e o sistema encontre todos os containers favoritados dentro do perímetro.

O personagem caminha fisicamente até cada container (pathfinding real), então o tempo de execução é proporcional à distância e quantidade de containers favoritados.

---

## Análise de Mods Existentes (Estado da Arte)

### 1. Quick Sort Build 42 (Robob27)

| Campo | Valor |
|-------|-------|
| **Workshop ID** | `3542556795` |
| **Autor** | Robob27 |
| **URL** | https://steamcommunity.com/sharedfiles/filedetails/?id=3542556795 |
| **GitHub** | https://github.com/robob27/pzquicksortb42 |
| **Compatível B42** | ✅ Sim |

**Funcionalidades:**
- "Quick Sort" (item individual) → procura container próximo com mesmo item
- "Quick Sort All" → todos os itens do inventário/mochila atual
- "Quick Sort \<Categoria\>" → itens da mesma categoria
- Submenu agrupado, raio configurável (padrão 7 tiles)
- Só containers explorados, protege favoritos/equipados

**Diferenças do nosso mod:**
- Usa **menu de contexto** (clique direito) — não tem botão dedicado
- Não tem sistema de **favoritar containers** — usa todos os próximos
- Não faz o personagem **caminhar fisicamente** até o container
- Não gera **TimedAction** — transferência é instantânea (quebraimmersão)

### 2. LootSense: QuickStack B42

| Campo | Valor |
|-------|-------|
| **Workshop ID** | `3733862305` |
| **Autor** | LootSense |
| **URL** | https://steamcommunity.com/sharedfiles/filedetails/?id=3733862305 |
| **Nexus** | https://www.nexusmods.com/projectzomboid/mods/334 |
| **Compatível B42** | ✅ Sim |

**Funcionalidades:**
- "Smart Unload Nearby" → pipeline de prioridade (tipo > tag > label > categoria)
- "Quick Stack Only" → apenas correspondência por tipo
- "Sort by Labels" → respeita rótulos de containers
- Preview antes de confirmar
- Usa TimedActions vanilla (imersivo)
- Sandbox options configuráveis

**Diferenças do nosso mod:**
- Mais complexo (pipeline de 4 estágios de fallback)
- Não tem sistema de **favoritar containers** — opera em todos os próximos
- Tem preview modal — nossa UX será mais direta (1 clique)
- Já usa TimedActions corretamente — boa referência de implementação

### 3. Terraria — Quick Stack to Nearby Chests (Referência de Game Design)

- Funciona em raio fixo (~40 tiles)
- Só empilha em baús que **já possuem** aquele item (mesmo princípio)
- Um botão dedicado na UI do inventário
- Processa todos os baús próximos em 1 ação
- Não requer seleção prévia de baús — opera em todos

---

## Diferencial do LKS SuperMod Patch (Nossa Proposta)

| Aspecto | Quick Sort B42 | LootSense | **LKS Organizador** |
|---------|---------------|-----------|---------------------|
| Ativação | Menu contexto | Menu contexto | **Botão dedicado na barra** |
| Seleção de containers | Todos próximos | Todos próximos | **Somente favoritados** |
| Imersão | Transferência instantânea | TimedAction | **Walk + TimedAction** |
| Controle do jogador | Pouco (raio) | Médio (preview) | **Total (favoritos)** |
| Integração visual | Nenhuma | Nenhuma | **Estrela nos containers** |

**Nossos diferenciais:**

1. **Controle explícito** — O jogador decide QUAIS containers participam via sistema de favoritos (estrela).
2. **Imersão total** — O personagem caminha até cada container e executa transferências com animação real (TimedAction).
3. **UI integrada** — Botão na barra de título do inventário + estrela visual nos containers da Loot Window.
4. **Sem mágica** — Nada acontece se o container não estiver acessível (parede, distância, trancado).

---

## Decisão: Fagocitação ou Implementação Própria?

**Decisão: Implementação 100% própria. Sem fagocitação.**

Justificativa:
- O Quick Sort B42 não usa TimedActions (anti-imersivo, quebraria compatibilidade com nossas regras).
- O LootSense é closed-source (Nexus) e tem pipeline complexo que não precisamos.
- Nenhum deles implementa o conceito de **favoritar containers** — que é o diferencial central da nossa feature.
- A implementação é relativamente simples e se encaixa perfeitamente na arquitetura de Handlers do B42.
- O **TwisTonFire - Inventory** (mod instalado localmente, 1.800+ linhas) resolve um problema DIFERENTE (inventário compartilhado virtual) — não tem sobreposição funcional com "guardar itens automaticamente". Decidido manter como dependência externa opcional e garantir compatibilidade via cadeia de monkey patches.

---

## Regras de Negócio

### RN-01: Elegibilidade do Container para Favoritação

Um container pode ser favoritado se:
- É um IsoObject do mundo com pelo menos 1 container acessível (`getContainerCount() > 0`)
- Não é o chão (`floor`)
- Não é parte do jogador (inventário, mochilas)
- Não está trancado (`isLockedToCharacter`)
- O jogador está adjacente ao container no momento da favoritação (clique direito)

Containers elegíveis comuns:
- Estantes, armários, guarda-roupas, cômodas
- Geladeiras, freezers
- Armários de armas, armários de ferramentas
- Caixas, baús, cofres (destrancados)
- Containers de veículos (futuro — Fase 4)

> **Nota:** O jogador precisa estar adjacente para FAVORITAR (menu de contexto), mas o scan para GUARDAR opera em 50x50 tiles.

### RN-02: Persistência dos Favoritos

- Favoritos são armazenados via `modData` no **objeto Java** do container (IsoObject pai).
- Chave: `LKS_ContainerFavorito = true`
- Persiste entre saves e reloads.
- Se o jogador destruir/mover o móvel, o favorito se perde (comportamento esperado).

### RN-03: Correspondência de Itens (MVP)

Um item do inventário do jogador é candidato a transferência para um container favoritado se:

1. O container favoritado **contém pelo menos 1 item** com o mesmo `fullType`.
2. O item **não está equipado** em nenhum slot (mão, corpo, mochila vestida).
3. O item **não é favorito** (`item:isFavorite() == false`).
4. O item **não está no hotbar** do jogador.
5. O container destino **não está cheio** (peso/capacidade).

### RN-04: Ordem de Processamento

1. Varrer área 50x50 tiles ao redor do jogador buscando containers com `LKS_ContainerFavorito` no modData.
2. Filtrar containers inacessíveis (pathfinding impossível, trancados, destruídos).
3. Para cada container favoritado válido (ordenado por **distância** ao jogador — mais perto primeiro):
   a. Identificar quais itens do inventário do jogador correspondem (mesmos `fullType` presentes no container).
   b. Enfileirar ação de caminhar até o container (`ISWalkToTimedAction` via `AdjacentFreeTileFinder`).
   c. Enfileirar transferências (`ISInventoryTransferAction`) para cada item correspondente.
4. Se nenhum item do inventário corresponde a nenhum container favoritado → feedback visual (tooltip).
5. A fila inteira é executada sequencialmente pelo `ISTimedActionQueue` — o personagem caminha até cada container, deposita, vai ao próximo.

### RN-05: Proteção de Itens

Itens **NUNCA** transferidos automaticamente:
- Equipados (qualquer slot)
- Favoritos do jogador (`isFavorite()`)
- No hotbar
- Contêineres equipados (mochilas vestidas) — nunca transferir a mochila em si
- Itens sendo usados em ações em andamento

### RN-06: Feedback ao Jogador

| Situação | Feedback |
|----------|----------|
| Nenhum container favoritado | Tooltip: "Nenhum container favoritado. Clique ⭐ em um container para favoritá-lo." |
| Nenhum item correspondente | Tooltip: "Nenhum item para guardar nos containers favoritados." |
| Processamento iniciado | Animação normal de transferência (walk + timer) |
| Container inacessível | Pula para o próximo (não interrompe a fila) |

### RN-07: Cancelamento

- O jogador pode cancelar a qualquer momento movendo-se (comportamento padrão de TimedActions com `stopOnWalk = true`).
- Itens já transferidos permanecem no destino (não há rollback).

---

## Arquitetura Técnica

### Ponto de Integração: Handler System (B42)

O Build 42 introduziu o sistema `ISInventoryWindowContainerControls` que permite registrar handlers (botões) na área de controle do painel de inventário do jogador. Este é o ponto de injeção correto.

```
ISInventoryWindowContainerControls.AddHandler(handlerClass)
```

O handler define:
- `shouldBeVisible()` — quando mostrar o botão
- `getControl()` — o widget ISButton
- `perform()` — ação ao clicar

### Arquivos Propostos

```
common/media/lua/
├── client/
│   ├── LKS_Organizer_Handler.lua           → Handler do botão "Guardar Itens" (ISInventoryWindowContainerControls)
│   ├── LKS_Organizer_ContextMenu.lua       → Menu de contexto: Favoritar/Desfavoritar (OnFillWorldObjectContextMenu)
│   └── LKS_Organizer_Motor.lua             → Lógica de scan 50x50, correspondência e enfileiramento de ações
├── shared/
│   └── Translate/
│       ├── PTBR/IG_UI.json                 → Chaves de tradução
│       └── EN/IG_UI.json                   → Chaves de tradução
└── ui/
    └── LKS_Menu_Favoritar.png              → Ícone estrela 32x32 (menu contexto) — já existe
```

### Diagrama de Fluxo

```
[Jogador clica "Guardar Itens"]
         │
         ▼
[Scan 50x50 tiles → coletar containers com LKS_ContainerFavorito]
         │
         ├─ Nenhum favorito? → Tooltip feedback → FIM
         │
         ▼
[Filtrar containers com itens correspondentes no inventário]
         │
         ├─ Nenhum item corresponde? → Tooltip feedback → FIM
         │
         ▼
[Ordenar containers por distância (mais perto primeiro)]
         │
         ▼
[Para cada container com correspondências:]
         │
         ▼
[Enfileirar: ISPathFindAction:pathToLocationF → tile adjacente ao container]
         │
         ▼
[Enfileirar: ISInventoryTransferAction × N itens correspondentes]
         │
         ▼
[Próximo container...]
         │
         ▼
[FIM — Fila executada pelo ISTimedActionQueue sequencialmente]
```

> **Pathfinding:** O PZ possui `ISPathFindAction` com `pathToLocationF(jogador, x, y, z)` que usa o Java `PathFindBehavior2` internamente — pathfinding real com desvio de obstáculos, paredes, portas. Funciona para distâncias longas dentro de chunks carregados. É o mesmo sistema usado para "Walk to" em veículos e cadáveres.

### Integração com Loot Window (Estrela de Favorito)

~~Para o botão de estrela nos containers da Loot Window~~ — **DESCARTADO.** A Loot Window só exibe containers a ~1 tile de distância (adjacentes). Como o raio de atuação é 50x50 tiles (toda a base), a favoritação precisa ser feita via **menu de contexto do mundo** ao clicar com botão direito no container.

**Mecanismo de Favoritação:**

O jogador clica com **botão direito** em qualquer container do mundo (armário, estante, freezer, etc.) e verá a opção **"⭐ Favoritar para Guardar Itens"** / **"Desfavoritar"** no menu de contexto.

Esse menu aparece via `Events.OnFillWorldObjectContextMenu` — o mesmo evento que já usamos para outros menus do mod. A opção:
- Exibe ícone de estrela (dourada se favoritado, cinza se não)
- Tem tooltip explicando a funcionalidade
- Toggle instantâneo (sem TimedAction — apenas marca modData)

**Indicador Visual (Opcional — Fase 2):**
- Containers favoritados recebem `setHighlighted()` quando o jogador ativa o modo "Guardar Itens"
- Ou: ícone de estrela sobreposto no sprite do container via overlay (pesquisar viabilidade)

### Scan de Containers Favoritados (Raio 50x50)

O scan NÃO depende da Loot Window — opera diretamente nas grid squares do mapa:

```lua
--- Varre 50x50 tiles ao redor do jogador buscando containers favoritados.
local raio = 25 -- 25 tiles em cada direção = 50x50 total
for dy = -raio, raio do
    for dx = -raio, raio do
        local quadrado = getCell():getGridSquare(jogadorX + dx, jogadorY + dy, jogadorZ)
        if quadrado then
            local objetos = quadrado:getObjects()
            for i = 0, objetos:size() - 1 do
                local objeto = objetos:get(i)
                for ci = 1, objeto:getContainerCount() do
                    local container = objeto:getContainerByIndex(ci - 1)
                    local modData = objeto:getModData()
                    if modData["LKS_ContainerFavorito"] then
                        -- Container favoritado encontrado
                    end
                end
            end
        end
    end
end
```

**Consideração de performance:** 50×50 = 2.500 tiles. Cada tile pode ter ~5-10 objetos. Total ~12.500-25.000 checks por ativação. Isso é aceitável para execução **única** no momento do clique (não é tick contínuo). Se necessário, otimizar com cache em `OnGameStart` + invalidação por evento.

### APIs Vanilla Utilizadas

| API | Propósito |
|-----|-----------|
| `ISInventoryWindowContainerControls.AddHandler()` | Registrar botão "Guardar Itens" |
| `Events.OnFillWorldObjectContextMenu.Add()` | Injetar opção Favoritar/Desfavoritar |
| `object:getModData()` | Persistir favorito no IsoObject do container |
| `object:getContainerCount()` / `getContainerByIndex()` | Acessar containers do objeto |
| `item:getFullType()` | Correspondência de tipo |
| `item:isFavorite()` | Proteção de itens favoritos |
| `item:isEquipped()` | Proteção de itens equipados |
| `ISPathFindAction:pathToLocationF(char, x, y, z)` | **Pathfinding real** até o container (longa distância) |
| `AdjacentFreeTileFinder.Find(square, player)` | Encontrar tile adjacente livre para destino do pathfind |
| `ISTimedActionQueue.add()` | Enfileirar ações sequenciais |
| `ISInventoryTransferAction:new()` | Transferir item (com animação) |
| `getCell():getGridSquare(x, y, z)` | Scan de tiles no raio 50x50 |
| `getPlayerInventory(n).inventoryPane.inventoryPage.backpacks` | Listar containers do jogador |
| `getPlayerHotbar(n):isInHotbar(item)` | Verificar hotbar |
| `character:getPathFindBehavior2()` | Engine de pathfinding Java (usado internamente pelo ISPathFindAction) |

---

## Interface Visual (UX)

### Botão "Guardar Itens" — Painel de Inventário

- **Posição:** Barra inferior de controles do inventário do jogador (ao lado de "Transferir Tudo").
- **Texto:** "Guardar Itens" (PT-BR) / "Store Items" (EN)
- **Visibilidade:** Sempre visível quando há pelo menos 1 container favoritado E o inventário não está vazio.
- **Estado desabilitado:** Quando nenhum item do inventário corresponde a nenhum container favoritado.
- **Cor:** Usar `altColor = true` (destaque verde do sistema de handlers) para diferenciar visualmente.

### Estrela de Favorito — Menu de Contexto do Mundo

- **Ativação:** Clique direito em qualquer container do mundo (armário, estante, freezer, etc.)
- **Opção no menu:** "⭐ Favoritar para Guardar Itens" / "Desfavoritar"
- **Visual:**
  - ☆ (contorno, cinza) icone = container não favoritado → mostra "Favoritar"
  - ★ (preenchida, dourada) icone = container favoritado → mostra "Desfavoritar"
- **Interação:** Clique alterna o estado (toggle instantâneo, sem TimedAction).
- **Assets necessários:**
  - `LKS_Menu_Favoritar.png` — 32x32, estrela (já criado pelo usuário ⭐)
  - Variante desativada pode ser composta via `tools/compor_icone.py` se necessário (Fase 2)

### Tooltip do Botão "Guardar Itens"

Ao passar o mouse sobre o botão:
```
Guardar Itens
Transfere automaticamente itens do inventário para
containers favoritados (⭐) que já possuem o mesmo tipo.

Containers favoritados: 3
Itens para guardar: 7
```

---

## Traduções

### PT-BR (`IG_UI.json`)

```json
{
    "IGUI_LKS_GuardarItens": "Guardar Itens",
    "IGUI_LKS_GuardarItens_Tooltip": "Transfere itens automaticamente para containers favoritados",
    "IGUI_LKS_NenhumFavorito": "Nenhum container favoritado. Clique ⭐ em um container para favoritá-lo.",
    "IGUI_LKS_NenhumItemCorrespondente": "Nenhum item para guardar nos containers favoritados.",
    "IGUI_LKS_FavoritarContainer": "Favoritar",
    "IGUI_LKS_DesfavoritarContainer": "Desfavoritar"
}
```

### EN (`IG_UI.json`)

```json
{
    "IGUI_LKS_GuardarItens": "Store Items",
    "IGUI_LKS_GuardarItens_Tooltip": "Auto-transfer items to favorited containers",
    "IGUI_LKS_NenhumFavorito": "No containers favorited. Click ⭐ on a container to favorite it.",
    "IGUI_LKS_NenhumItemCorrespondente": "No items to store in favorited containers.",
    "IGUI_LKS_FavoritarContainer": "Favorite",
    "IGUI_LKS_DesfavoritarContainer": "Unfavorite"
}
```

---

## Fases de Implementação

### Fase 1 — MVP Funcional

**Objetivo:** Botão funcional + estrela + correspondência por `fullType`.

1. Criar `LKS_Organizer_Motor.lua` — lógica de correspondência e coleta.
2. Criar `LKS_Organizer_Handler.lua` — handler do botão "Guardar Itens".
3. Monkey patch no `addContainerButton` da Loot Window para injetar estrela.
4. Persistência via modData.
5. Traduções PT-BR/EN.
6. Teste funcional in-game.

**Entregável:** O jogador pode favoritar containers, clicar "Guardar Itens" e o personagem caminha e transfere itens correspondentes.

### Fase 2 — Polimento e UX (Futuro)

- Tooltip dinâmico mostrando contagem de itens/containers.
- Feedback sonoro ao completar transferências.
- Indicador visual de "processando" durante a fila de ações.
- Highlight no container ativo (usando `setHighlighted`).

### Fase 3 — Correspondência Avançada (Futuro)

- Fallback por **categoria** quando não há correspondência exata por tipo.
- Correspondência por **tags** de item (se o container tiver items com mesmas tags).
- Configuração para o jogador escolher: "Apenas tipo exato" vs "Tipo + Categoria".
- Sandbox option para habilitar/desabilitar a feature globalmente.

### Fase 4 — Integração com Outros Sistemas (Futuro)

- Integração com o `LKS_ApplianceManager` — respeitar estado de energia dos aparelhos.
- Não transferir itens para geladeiras desligadas (se o driver de refrigeração estiver ativo).
- Suporte a containers de veículos.
- Radial menu shortcut (atalho rápido).

---

## Riscos e Limitações

| Risco | Mitigação |
|-------|-----------|
| Performance com muitos itens | Limitar processamento a 50 itens por ciclo |
| Container destruído entre favoritar e usar | Validar existência no `perform()`, pular se inválido |
| Conflito com Quick Sort B42 (se instalado junto) | Nosso handler tem nome único, não conflita com menus de contexto |
| Peso excedido no container destino | Verificar capacidade antes de enfileirar, pular item se não cabe |
| Multiplayer — sync de modData | Usar `sendClientCommand` para favoritos em MP |
| Item consumido durante a fila | `ISInventoryTransferAction:isValid()` vanilla já trata isso |
| **Cadeia de monkey patches no `addContainerButton`** | Ver seção abaixo |

### Compatibilidade com Mods de UI Instalados

**Neat Rocco:** NÃO altera `ISInventoryPage`, `ISInventoryWindowContainerControls` nem `addContainerButton`. Impacto zero na nossa implementação. A UI do Neat Rocco é limitada a painéis dedicados (`NR_OvenPanel`, `NR_FluidTransferPanel`, etc.) e não toca no inventário/Loot Window.

**TwisTonFire - Inventory:** FAZ monkey patch no `addContainerButton` (linha 747 de `twistonfire_inventory.lua` v42.19). O padrão dele é correto — salva `old_addContainerButton` e chama na cadeia. Nosso patch no `LKS_ApplianceManager.lua` já está na cadeia antes dele (por ordem de carregamento via `mod.info`). A estrela de favorito precisa ser injetada **depois** de TwisTonFire terminar seu processamento. 

**Solução:** Garantir que nosso módulo de favorito carregue APÓS TwisTonFire. Usar `require` tardio ou registrar no evento `OnGameStart` (que dispara após todos os mods carregarem) para capturar a versão mais recente de `ISInventoryPage.addContainerButton` na cadeia.

---

## Nomenclatura de Arquivos (Padrão do Projeto)

| Arquivo | Responsabilidade |
|---------|-----------------|
| `LKS_Organizer_Handler.lua` | Handler do botão na `ISInventoryWindowContainerControls` |
| `LKS_Organizer_FavoritoVisual.lua` | Monkey patch da estrela + toggle |
| `LKS_Organizer_Motor.lua` | Lógica de correspondência, coleta, ordenação, enfileiramento |
| `LKS_Organizer_Estrela_Off.png` | Asset da estrela desativada |
| `LKS_Organizer_Estrela_On.png` | Asset da estrela ativada |

---

## Referências Internas

- `docs/pz_jogador_inventario_eventos.md` — APIs de inventário e eventos
- `docs/pz_timed_actions.md` — Padrão de TimedActions com walkAdj
- `docs/pz_objetos_mundo.md` — modData e getParent()
- `common/media/lua/client/LKS_ApplianceManager.lua:198-250` — Exemplo de monkey patch no `addContainerButton`
- Vanilla: `ISInventoryWindowContainerControls.lua` — Sistema de handlers
- Vanilla: `ISInventoryWindowControlHandler.lua` — Base class para handlers
- Vanilla: `ISInventoryPage.lua:1537-1800` — refreshBackpacks e ciclo de vida de containers
- Vanilla: `ISInventoryTransferAction.lua` — Ação de transferência com animação
- Vanilla: `luautils.walkToContainer()` / `luautils.walkAdj()` — Caminhada até containers

---

## Checklist de Validação (Antes de Implementar)

Pontos que **só podem ser confirmados com teste in-game** — tratados como dívida técnica a resolver durante a implementação:

- [ ] **Enfileiramento de `ISPathFindAction` + `ISInventoryTransferAction`:** Validar se o `ISTimedActionQueue` executa sequencialmente múltiplos pathfinds intercalados com transferências (walkA → depositA → walkB → depositB). Se não, criar TimedAction custom com callback chain.
- [ ] **Persistência de `modData` em mobília:** Confirmar que `objeto:getModData()["LKS_ContainerFavorito"]` persiste em save/load para estantes, armários, guarda-roupas (já funciona para fogões/botijões no sistema de propano — alta probabilidade de funcionar).
- [ ] **Chunks carregados no raio 50x50:** Validar se `getCell():getGridSquare(x, y, z)` retorna nil para tiles fora dos chunks carregados e se isso é tratado graciosamente.
- [ ] **Containers de veículo:** Verificar se `getModData()` funciona em `VehiclePart` da mesma forma (Fase 4).

---

## Diretriz de Depuração (Debug Prints)

Durante toda a implementação da Fase 1, incluir prints de debug **detalhados** para facilitar acompanhamento via `console.txt`. Formato padrão:

```lua
print("[LKS_Organizer] <contexto>: <informacao>")
```

Exemplos esperados no console durante execução:

```
[LKS_Organizer] Scan iniciado: raio 25, jogador em (4521, 3102, 0)
[LKS_Organizer] Container favoritado encontrado: armario em (4518, 3099, 0) — 3 tipos correspondentes
[LKS_Organizer] Container favoritado encontrado: freezer em (4525, 3105, 0) — 1 tipo correspondente
[LKS_Organizer] Total: 2 containers, 7 itens para guardar
[LKS_Organizer] Enfileirando: pathfind ate (4518, 3099, 0)
[LKS_Organizer] Enfileirando: transferir 3x Base.RawChicken para armario
[LKS_Organizer] Enfileirando: pathfind ate (4525, 3105, 0)
[LKS_Organizer] Enfileirando: transferir 1x Base.Screwdriver para freezer
[LKS_Organizer] Fila completa: 4 acoes enfileiradas
```

> **Regra:** Os prints de debug serão removidos apenas na fase de polimento final (Fase 2), após validar todos os fluxos. Durante desenvolvimento, eles são obrigatórios em: scan, correspondência, enfileiramento, pathfind start/complete/fail, transferência start/complete.
