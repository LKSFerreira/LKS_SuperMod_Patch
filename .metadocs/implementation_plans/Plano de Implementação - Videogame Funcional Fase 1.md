# Plano de Implementação — Videogame Funcional (Fase 1: Modo Automático)

## Contexto

Transformar o conceito de videogame portátil em um dispositivo funcional no LKS SuperMod Patch.
Na Fase 1, o jogador pode ligar o videogame, equipá-lo nas duas mãos e jogar automaticamente
(animação idle), reduzindo estresse e depressão com consumo de bateria, e gerando som de jogo, podendo atrair zumbis próximo. (max 5 tiles)

**Base de pesquisa:** `docs/pesquisa_videogame_funcional.md`
**Design doc:** `.metadocs/feat/video_game.md`

---

## Escopo da Fase 1

| Incluso | Futuramente |
|---------|-------------|
| Item funcional LKS + vanilla "Com Defeito" | Minijogos (Cobrinha, Pong, Pac-man, Tetris, Top-Gear, entre outros) |
| Janela NR_BasePanel com seções | Cartuchos funcionais |
| 2 slots de bateria com drain (2 pilhas no total) | Sistema de condição/reparo |
| Toggle Ligar/Desligar | Sons/efeitos sonoros audíveis pelo jogador (bleeps de jogo) |
| Modo automático (TimedAction + EveryOneMinute) | Leaderboard ativo |
| Redução de estresse e depressão | Animação customizada |
| Atração de zumbis pelo som (raio 5 tiles) | Sentado em cadeira, sofás, chão, camas |
| Enquanto joga campo de visão -80% | Balanceamento futuro caso valores sejam pouco ou muito |
| Bônus fone: +20% eficiência moodles | — |
| Bônus fone: +25% economia de bateria | — |
| Bônus fone: anula atração de zumbis (som não vaza) | — |
| Slot de cartucho (UI desabilitada) | — |
| Config centralizado de balanceamento | — |

---

## Arquitetura de Arquivos

```
common/media/
├── scripts/
│   └── lks_videogame_items.txt           → Script do item LKS_Videogame + override vanilla
├── lua/
│   ├── shared/
│   │   └── videogame/
│   │       └── LKS_Videogame_Config.lua  → Constantes de balanceamento
│   ├── client/
│   │   └── devices/videogame/
│   │       ├── LKS_Videogame_Window.lua  → Janela NR_BasePanel (UI principal)
│   │       ├── LKS_Videogame_Action.lua  → TimedAction de "jogar" (animação + moodles)
│   │       └── LKS_Videogame_Handler.lua → Context menu + EveryOneMinute (drain bateria)
│   └── server/
│       └── videogame/
│           └── LKS_Videogame_Sync.lua    → Sync multiplayer de leaderboard (stub)
└── Translate/
    ├── PTBR/
    │   └── IG_UI.json                    → Chaves de tradução PT-BR
    └── EN/
        └── IG_UI.json                    → Chaves de tradução EN
```

---

## Etapas de Implementação

### Etapa 1: Script do Item e Infraestrutura

**Objetivo:** Criar o item funcional e o override do vanilla.

**Tarefas:**
1. Criar `lks_videogame_items.txt`:
   - Item `LKS_Videogame` (módulo `LKS_Propano`):
     - `RequiresEquipBothHands = TRUE`
     - `Weight = 1`
     - `DisplayCategory = Electronics`
     - `Icon = VideoGame` (reutiliza ícone vanilla)
     - `WorldStaticModel = VideoGame`
     - `Tags = base:hasmetal;base:miscelectronic`
     - `DisplayName = Videogame Portátil`
   - Override de `Base.VideoGame`:
     - `DisplayName = Videogame (Com Defeito)`
     
2. Criar `LKS_Videogame_Config.lua` (shared):
   - Tabela `LKS_VIDEOGAME` com todas as constantes:
     - Tempo para zerar moodles (3h)
     - Duração de bateria (2h)
     - Número de baterias (2)
     - Taxa de redução por minuto
     - Bônus fone — eficiência moodles (+20%)
     - Bônus fone — economia de bateria (+25%)
     - Redução de campo de visão (-80%)
     - Raio de atração de zumbis (5 tiles)
     - ReadType da animação

3. Adicionar traduções em PTBR e EN

**Validação:** Item aparece no inventário com nome correto, equipa nas duas mãos.

---

### Etapa 2: Janela do Dispositivo (UI)

**Objetivo:** Criar a janela NR_BasePanel do videogame. UI e UX impecáveis, simulando um gameboy ou estilo de game portável. Tela, botões, teclas, mouse totalmente funcionais para os modos manuais.

**Tarefas:**
1. Criar `LKS_Videogame_Window.lua` herdando de `NR_BasePanel`:
   - Header com:
     - Título: "Videogame Portátil" (ou nome do item)
     - PowerButton (verde=ligado, vermelho=desligado)
     - CloseButton
   - Seção "Energia":
     - 2x ISItemDropBox para baterias (backdrop: `Item_Battery`)
     - 2x Barra de carga (estilo ISBatteryStatusDisplay)
     - Ícone de fone (ISItemDropBox para `Base.Headphones`/`Base.Earbuds`)
   - Seção "Modo":
     - Label "Modo Automático" (Fase 1 — único modo)
     - Botão "Jogar" / "Parar"
   - Seção "Cartucho" (preparação futura):
     - ISItemDropBox com backdrop de cartucho
     - Label: "Sem cartucho — Modo Automático"
     - Drop box desabilitado (mouseEnabled = false)
   - Seção "Status":
     - Barra de progresso: Estresse (quanto já reduziu)
     - Barra de progresso: Depressão (quanto já reduziu)
     - Texto: taxa de redução/hora

2. Integrar com NR_Config para cores/padding consistentes
3. Auto-close quando item sair das mãos (mesmo padrão ISRadioWindow:update)
4. Abrir via context menu do item equipado

**Validação:** Janela abre, mostra seções, powerButton funciona visualmente.

---

### Etapa 3: Sistema de Bateria

**Objetivo:** Implementar inserção, remoção e consumo de baterias via modData.

**Tarefas:**
1. No modData do item:
   - `LKS_VG_bateria1_id` → ID do item Battery inserido (ou nil)
   - `LKS_VG_bateria1_carga` → float 0.0 a 100.0
   - `LKS_VG_bateria2_id` → idem
   - `LKS_VG_bateria2_carga` → idem

2. Drag-and-drop de bateria no ISItemDropBox:
   - `verifyItem()`: aceita apenas `Base.Battery`
   - `addBattery()`: remove do inventário, salva carga no modData
   - `removeBattery()`: cria Battery com carga restante, devolve ao inventário

3. Consumo via `EveryOneMinute`:
   - Se ligado: drenar `cargaPorMinuto` da bateria ativa
   - Bateria 1 drena primeiro; quando zerada, muda para bateria 2
   - Quando ambas zeradas: desliga automaticamente
   - Fone equipado: reduz drain em X% (economia)

4. UI atualiza barras em tempo real (no `update()` do painel)

**Validação:** Inserir/remover baterias, drain visível, desliga quando acaba.

---

### Etapa 4: Modo Automático (TimedAction + Moodles)

**Objetivo:** Implementar a ação de "jogar" que reduz estresse e depressão, limita campo de visão e atrai zumbis.

**Tarefas:**
1. Criar `LKS_Videogame_Action.lua` (ISBaseTimedAction):
   - `start()`:
     - `setActionAnim(CharacterActionAnims.Read)`
     - `setAnimVariable("ReadType", "book")`
     - `setOverrideHandModels(nil, self.item)`
     - Captura stats atuais (estresse, depressão)
     - Reduz campo de visão do jogador em 80% (restaurar no stop)
   - `update()`:
     - A cada tick: reduz estresse e depressão pela taxa configurada
     - Verifica se baterias ainda têm carga (senão, forceComplete)
     - Verifica se item ainda está equipado
     - Emite som que atrai zumbis em raio de 5 tiles
   - `stop()`:
     - Condição de parada: moodles zerados OU bateria acabou OU jogador moveu
     - Restaura campo de visão original
   - `perform()`:
     - Cleanup final (salva estado, restaura visão)
   - Duração: `maxTime = -1` (infinita, para até condição de stop)

2. Integrar com fone de ouvido:
   - Verificar `player:getInventory():containsTypeEvalRecurse("Headphones")` ou `"Earbuds"`
   - Se equipado: +20% na taxa de redução de moodles
   - Se equipado: +25% economia no consumo de bateria
   - Se equipado: anula atração de zumbis (som não vaza)

3. Context menu: opção "Jogar Videogame" quando item equipado + baterias inseridas

**Validação:** Personagem entra em animação, moodles diminuem, para quando acaba bateria.

---

### Etapa 5: Handler e Integração

**Objetivo:** Conectar tudo — context menu, EveryOneMinute, abertura de janela.

**Tarefas:**
1. `LKS_Videogame_Handler.lua`:
   - `OnFillInventoryObjectContextMenu`:
     - Se item é LKS_Videogame E está equipado:
       - "Abrir Videogame" → abre janela
       - "Jogar" → inicia TimedAction (atalho direto)
   - `EveryOneMinute`:
     - Para cada jogador: se videogame ligado → drenar bateria
     - Se baterias zeradas → desligar, notificar UI

2. Registro de eventos:
   - `Events.OnFillInventoryObjectContextMenu.Add(LKS_Videogame_onContextMenu)`
   - `Events.EveryOneMinute.Add(LKS_Videogame_atualizarBateria)`

3. Salvar recordes pessoais no player modData (preparação para minijogos)

**Validação:** Fluxo completo funciona: equipar → abrir janela → jogar → moodles descem → bateria acaba → desliga.

---

### Etapa 6: Polimento e Tradução

**Objetivo:** Finalizar UI, tooltips, traduções e testes.

**Tarefas:**
1. Tooltips em todos os elementos da UI:
   - PowerButton: "Ligar" / "Desligar" / "Sem bateria"
   - Slots de bateria: "Arraste uma pilha aqui"
   - Slot de cartucho: "Cartuchos disponíveis em breve"
   - Slot de fone: "Conecte fones para bônus de eficiência"
2. Traduções completas (PTBR + EN)
3. Print de carregamento em todos os arquivos Lua
4. Teste de sintaxe: `python tools/auditoria_mod.py validar-sintaxe`
5. Teste in-game completo

---

## Dependências entre Etapas

```
Etapa 1 (Item + Config)
    │
    ├──→ Etapa 2 (UI/Janela)
    │        │
    │        └──→ Etapa 3 (Bateria)
    │                 │
    │                 └──→ Etapa 4 (TimedAction)
    │                          │
    │                          └──→ Etapa 5 (Handler)
    │                                    │
    │                                    └──→ Etapa 6 (Polimento)
    │
    └──→ [Independente] Etapa de tradução pode ser antecipada
```

---

## Riscos e Mitigações

| Risco | Probabilidade | Mitigação |
|-------|---------------|-----------|
| NR_BasePanel não carrega sem NeatUI_Framework | Baixa (mod instalado) | Verificar dependência no mod.info |
| Animação "book" fica estranha com modelo VideoGame | Média | Testar in-game, fallback para "photo" |
| modData não sincroniza em MP | Baixa (PZ sincroniza automaticamente) | Testar com 2 jogadores |
| ISItemDropBox não funciona fora de ISRadioWindow | Baixa (é widget vanilla genérico) | Testar isolado antes |
| Conflito com mods que alteram Base.VideoGame | Média | Override parcial (só DisplayName) |

---

## Critérios de Aceite (Fase 1)

- [ ] Item aparece no loot e pode ser equipado nas duas mãos
- [ ] Vanilla aparece como "Videogame (Com Defeito)"
- [ ] Janela NeatUI abre com visual consistente
- [ ] 2 baterias podem ser inseridas/removidas via drag-and-drop
- [ ] Ligar consome bateria progressivamente
- [ ] Botão "Jogar" inicia animação de leitura com modelo na mão
- [ ] Estresse e depressão diminuem enquanto joga
- [ ] Fone de ouvido dá bônus verificável
- [ ] Desliga automaticamente quando baterias acabam
- [ ] Funciona em singleplayer e multiplayer
- [ ] Slot de cartucho visível mas desabilitado
- [ ] Variáveis de balanceamento ajustáveis em um único arquivo
