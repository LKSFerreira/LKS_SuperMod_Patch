# Pesquisa — Videogame Funcional (Fase de Investigação)

Documento de referência técnica para implementação do Videogame Funcional.
Investigação concluída em 24/06/2026.

---

## 1. Item Vanilla `Base.VideoGame`

**Script atual** (`media/scripts/generated/items/normal.txt:4485-4494`):

```
item VideoGame
{
    DisplayCategory = Electronics,
    ItemType = base:normal,
    Weight = 0.8,
    Icon = VideoGame,
    MetalValue = 7.0,
    WorldStaticModel = VideoGame,
    Tags = base:hasmetal;base:miscelectronic,
}
```

**Características:**
- Item simples (Normal), sem funcionalidade
- Sem suporte a baterias (não é `Radio`, não tem `DeviceData`)
- Sem `TwoHandWeapon` — precisa ser modificado para forçar duas mãos
- Modelo 3D: `WorldItems/VideoGame` (mesh + texture), escala 0.5
- Ícone: `VideoGame` (já existe no jogo)

**Decisão necessária:** Criar item novo (`LKS_Propano.LKS_Videogame`) OU modificar o vanilla.
Recomendação: criar item NOVO para evitar conflitos com outros mods.

---

## 2. ISRadioWindow — Arquitetura da Janela de Dispositivo

### Hierarquia de Classes
```
ISPanel
  └── ISCollapsableWindow
       └── ISRadioWindow
```

### Localização
`media/lua/client/RadioCom/ISRadioWindow.lua`

### Como funciona

1. **Ativação:** `ISRadioWindow.activate(player, deviceObject)` — abre a janela
   - Detecta se é `InventoryItem`, `IsoObject` ou `VehiclePart`
   - Cria singleton por `playerNum` (não duplica janelas)
   - Para itens de inventário: verifica se está equipado na mão (primary/secondary/back)

2. **Módulos empilhados:** Sistema modular com seções independentes
   ```lua
   self:addModule(RWMGeneral:new(...), getText("IGUI_RadioGeneral"), true)
   self:addModule(RWMPower:new(...), getText("IGUI_RadioPower"), true)
   self:addModule(RWMSignal:new(...), getText("IGUI_RadioSignal"), true)
   -- etc.
   ```
   Cada módulo decide se está visível via `readFromObject()` retornando true/false.

3. **Layout automático:** No `prerender()`, os módulos habilitados são empilhados verticalmente e a altura da janela ajustada.

4. **Auto-close:** No `update()`, se o item sair da mão → desliga o dispositivo e fecha a janela.

### Módulos Vanilla

| Módulo | Classe | Função |
|--------|--------|--------|
| Geral | `RWMGeneral` | Info do dispositivo (nome, tipo) |
| Energia | `RWMPower` | LED + Toggle + Bateria + Barra % |
| Energia Grid | `RWMGridPower` | Para dispositivos na rede elétrica |
| Sinal | `RWMSignal` | Barras de força do sinal |
| Volume | `RWMVolume` | Barra de volume + fone de ouvido |
| Microfone | `RWMMicrophone` | Mute para rádios two-way |
| Mídia | `RWMMedia` | Slot para CD/VHS + Play/Stop |
| Canal | `RWMChannel` | Seletor de frequência (rádio) |
| Canal TV | `RWMChannelTV` | Seletor de canal (TV) |

---

## 3. Sistema de Bateria (RWMPower)

### Localização
`media/lua/client/RadioCom/RadioWindowModules/RWMPower.lua`

### Componentes da UI

```
[LED] [Ligar] [🔋 Drop] [████████ 100%]
```

1. **ISLedLight** — LED verde (ligado) / verde escuro (desligado)
2. **ISButton** — Toggle "Ligar"/"Desligar"
3. **ISItemDropBox** — Slot drag-and-drop para `Base.Battery`
   - Textura backdrop: `Item_Battery`
   - Tooltip: "Arraste uma bateria aqui"
   - Validação: `verifyItem()` aceita apenas `Base.Battery`
4. **ISBatteryStatusDisplay** — Barra de progresso com %
   - Textura: `Radio_ConditionGradient` (gradiente vermelho→verde)
   - Desenha: `drawTextureScaled` (fundo) + `drawRect` (barra) + `drawRectBorder` + texto %

### Consumo de Bateria
- `powerUpdateSimulation()`: decrementa `0.01` a cada 20 updates
- Vanilla: ~0.2 power/segundo em tempo real (depende do tick rate)
- Para o videogame: vamos controlar via `EveryOneMinute` (2h = 120 min game)

### Ações
- Inserir bateria: `ISDeviceBatteryAction` (TimedAction com animação)
- Ligar/Desligar: `ISRadioAction("ToggleOnOff")` → `deviceData:setIsTurnedOn()`

---

## 4. Sistema de VHS / Mídia (Conceito de Cartuchos)

### Localização
- `media/lua/shared/RecordedMedia/recorded_media.lua` — Banco de mídias
- `media/lua/shared/RecordedMedia/ISRecordedMedia.lua` — Registro no Java
- `media/lua/shared/TimedActions/ISDeviceMediaAction.lua` — Ações de inserir/remover
- `media/lua/client/RadioCom/RadioWindowModules/RWMMedia.lua` — UI de mídia

### Como funciona

1. **Item de mídia** (`VHS_Retail`, `VHS_Home`): tem `MediaCategory = Retail-VHS`
2. **Dispositivo** tem `mediaType`: 0 = CD, 1 = VHS
3. **Inserção:** Valida `item:getMediaType() == deviceData:getMediaType()`
4. **Playback:** `deviceData:StartPlayMedia()` / `StopPlayMedia()`
5. **Conteúdo:** Registrado em `RecMedia["id"]` com título, linhas, categoria

### Aplicação ao Videogame (Conceito de Cartuchos)

O sistema de VHS pode ser adaptado para "cartuchos de jogo":
- Criar items com `MediaCategory = Game-Cartridge` (nova categoria)
- Cada cartucho = um jogo diferente (Cobrinha, Pong, etc.)
- O videogame teria `mediaType = 2` (nova categoria, ou reusar existente)
- UI mostraria qual cartucho está inserido
- **Extensibilidade:** Novos jogos = novos cartuchos (como VHS para TV)

> **Nota:** Esta é uma mecânica FUTURA (Fase 2+). A Fase 1 usa modo automático sem cartucho.

---

## 5. Animações Disponíveis

### Melhor candidata: `CharacterActionAnims.Read`

```lua
self:setActionAnim(CharacterActionAnims.Read)
self:setAnimVariable("ReadType", "book")  -- ou "newspaper", "photo"
self:setOverrideHandModels(nil, self.item)
```

**Por que funciona:**
- Personagem segura item na mão secundária (mão esquerda)
- Olha para baixo (como se estivesse lendo/jogando)
- Fica em idle parado — perfeito para "jogando"
- Já existe no vanilla, sem necessidade de assets novos

**Variantes de ReadType:**
| ReadType | Postura | Adequação |
|----------|---------|-----------|
| `"book"` | Segura com as duas mãos, olha para baixo | ⭐ Melhor opção |
| `"newspaper"` | Segura aberto, braços mais largos | Possível alternativa |
| `"photo"` | Segura pequeno, olha de perto | Boa para Game Boy |

### Override de modelo na mão
`setOverrideHandModels(nil, self.item)` — renderiza o modelo 3D do VideoGame na mão do personagem.

### Referência: ISReadABook (redução de moodles)

O vanilla já implementa redução de `Unhappiness` durante a leitura:
```lua
-- Em start():
self.stats.boredom = character:getStats():get(CharacterStat.BOREDOM)
self.stats.unhappiness = character:getStats():get(CharacterStat.UNHAPPINESS)
self.stats.stress = character:getStats():get(CharacterStat.STRESS)

-- Em update():
if self.item:getUnhappyChange() < 0.0 then
    if stats:get(CharacterStat.UNHAPPINESS) > self.stats.unhappiness then
        stats:set(CharacterStat.UNHAPPINESS, self.stats.unhappiness)
    end
end
```

Podemos usar padrão similar mas com nossa própria taxa de redução.

---

## 6. Mods de UI Instalados

### NeatUI Framework (`NeatUI_Framework`)
Framework compartilhado que fornece componentes reutilizáveis:
- `NI_SquareButton` — Botão quadrado com estados (active/hover/pressed)
- Texturas em `media/ui/NeatUI/Button/Background.png` e `Boarder.png`

### Neat Rocco's UI (`Neat_Rocco`)
Redesign completo de menus vanilla. Depende do NeatUI_Framework.

**Hierarquia de classes:**
```
ISPanelJoypad (vanilla)
  └── NR_BasePanel (NR_Utils/NR_BasePanel.lua)
       └── NR_OvenPanel, NR_BBQPanel, NR_GeneratorPanel, etc.

ISTableLayout (vanilla)
  └── NR_Header (NR_Utils/NR_Header.lua)

ISButton (vanilla)
  └── NI_SquareButton (NeatUI_Framework)
```

**NR_Config — Constantes visuais:**

| Constante | Valor | Uso |
|-----------|-------|-----|
| `headerBg` | `0.08` | Fundo do header (cinza muito escuro) |
| `panelBg` | `0.15` | Fundo do corpo do painel |
| `headerHeight` | `FONT_HGT_MEDIUM * 1.5` | Altura do header |
| `padding` | `FONT_HGT_SMALL * 0.4` | Espaçamento geral |
| `buttonSize` | `FONT_HGT_MEDIUM` | Tamanho de botões quadrados |
| `barHeight` | `FONT_HGT_SMALL * 1.2` | Altura de barras de progresso |
| `bgAlpha` | `1.0` | Alpha do fundo |
| `separatorColor` | `{0.4, 0.4, 0.4, 0.6}` | Linhas separadoras |
| `selectionColor` | `{0.3, 0.7, 0.35, 0.15}` | Destaque de seleção (verde) |

**Power Button (no NR_Header):**
- Verde = ligado (`0.2, 0.7, 0.3`)
- Vermelho = desligado (`0.7, 0.2, 0.2`)
- Cinza = disabled (cor do fundo)
- Hover: alpha 0.9 (normal: 0.7)

**Padrão de criação de painel NR:**
```lua
function MeuPainel:new(x, y, width, height, dispositivo, personagem)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.character      = personagem
    o.playerNum      = personagem:getPlayerNum()
    o.dispositivo    = dispositivo
    o.hasPowerButton = true  -- habilita power no header
    NR_BasePanel.initBase(o)
    return o
end
```

### Outros Mods de UI Relevantes

| Mod | Função |
|-----|--------|
| `CleanUI` | Inventário/loot compacto (depende de NeatUI_Framework) |
| `CleanHotBar` | Hotbar minimalista |
| `RYGProgressIndicator` | Indicadores de progresso coloridos |
| `BetterClothingInfo` | Tooltips melhorados de roupa |

---

## 7. Interface da TV Antiga (Referência)

A TV usa a MESMA `ISRadioWindow` que o Walkie-Talkie, apenas com módulos diferentes habilitados:
- `RWMGeneral` → Mostra "Canal: Life and Living TV"
- `RWMPower` → Mostra "Desligar" + estado de energia (rede elétrica)
- `RWMVolume` → Barra de volume
- `RWMChannelTV` → Seletor de canal com dropdown

A diferença é que TV é `IsoObject` (no mundo) e verifica `isTelevision()`.

---

## 8. Variáveis de Balanceamento (Proposta)

Para facilitar ajustes futuros, centralizar em um arquivo de configuração:

```lua
-- LKS_Videogame_Config.lua (shared/)
LKS_VIDEOGAME = {
    -- Tempo e eficácia
    TEMPO_ZERAR_ESTRESSE_HORAS     = 3,    -- horas para zerar estresse máximo
    TEMPO_ZERAR_DEPRESSAO_HORAS    = 3,    -- horas para zerar depressão máxima
    
    -- Bateria
    BATERIAS_NECESSARIAS           = 2,    -- slots de bateria
    DURACAO_BATERIA_HORAS          = 2,    -- horas com 2 baterias cheias
    
    -- Redução por minuto (calculado: maxMoodle / tempoEmMinutos)
    -- Stress vai de 0.0 a 1.0; Unhappiness de 0 a 100
    REDUCAO_ESTRESSE_POR_MINUTO    = 1.0 / (3 * 60),  -- ~0.0056/min
    REDUCAO_DEPRESSAO_POR_MINUTO   = 100 / (3 * 60),  -- ~0.556/min
    
    -- Bonus com fone de ouvido (multiplicador)
    BONUS_FONE_MULTIPLICADOR       = 1.25, -- 25% mais eficiente com fone
    
    -- Modo automático
    ANIM_TIPO                      = "book", -- ReadType para animação
}
```

---

## 9. Abordagem de Implementação (Alto Nível)

### Opção A: Derivar de ISRadioWindow (como TV/Walkie)
- **Prós:** Reutiliza bateria, toggle, media slot, auto-close
- **Contras:** Precisa de `DeviceData` Java (item precisa ser `Radio`)
- **Problema:** `Base.VideoGame` não é `Radio`. Teria que criar item com classe Java de rádio.

### Opção B: Painel independente com NR_BasePanel
- **Prós:** UI bonita NeatUI, controle total, sem dependência de DeviceData
- **Contras:** Reimplementar bateria e toggle manualmente (mas é simples)
- **Vantagem:** Pode usar modData para estado (como já fazemos em lavanderia)

### Opção C: Híbrido — ISCollapsableWindow com módulos custom
- Mesma arquitetura modular do ISRadioWindow, mas sem herdar dele
- Módulos próprios: `VGMPower`, `VGMStatus`, `VGMModo`
- Bateria via modData (não DeviceData Java)

**Recomendação:** Opção B (NR_BasePanel) para UI impecável com NeatUI,
usando modData para persistência de estado (baterias, ligado/desligado, tempo jogado).

---

## 10. Decisões Finais (Consolidadas)

| # | Decisão | Resultado |
|---|---------|-----------|
| 1 | Item | Novo `LKS_Propano.LKS_Videogame` (funcional) + vanilla renomeado "Com Defeito" |
| 2 | UI | NR_BasePanel (NeatUI) — visual consistente com Neat Rocco |
| 3 | Animação | `CharacterActionAnims.Read` + ReadType `"book"` + modelo 3D na mão |
| 4 | Fone | Bônus opcional: +eficiência de redução de moodles + economia de bateria |
| 5 | Cartuchos | Arquitetura preparada para futuro (slot + validação), sem minijogos agora |
| 6 | Estado | Híbrido: modData item + player modData + GlobalModData (leaderboard MP) |

### Detalhamento da Decisão 6 — Persistência de Estado

```
┌─────────────────────────────────────────────────────────────────┐
│ item:getModData()          → Estado do dispositivo físico        │
│   .LKS_VG_ligado           (boolean)                            │
│   .LKS_VG_cargaBateria1   (float 0.0-100.0)                    │
│   .LKS_VG_cargaBateria2   (float 0.0-100.0)                    │
│   .LKS_VG_tempoUsoMinutos (int — tempo total de uso)            │
│   .LKS_VG_cartuchoInserido (string fullType ou nil)             │
├─────────────────────────────────────────────────────────────────┤
│ player:getModData()        → Recordes pessoais do jogador       │
│   .LKS_VG_recordeCobrinha  (int — fase máxima)                  │
│   .LKS_VG_recordePong      (int — pontuação máxima)             │
│   .LKS_VG_tempoTotalJogado (int — minutos lifetime)             │
├─────────────────────────────────────────────────────────────────┤
│ ModData.getOrCreate("LKS_VG_Leaderboard") → Ranking global (MP) │
│   .cobrinha = { {nome, fase, data}, ... }                       │
│   .pong     = { {nome, pontos, data}, ... }                     │
│   (Persiste no save do mundo, todos jogadores veem)             │
└─────────────────────────────────────────────────────────────────┘
```

### Detalhamento da Decisão 1 — Item Vanilla "Com Defeito"

O `Base.VideoGame` vanilla será modificado via script override:
- `DisplayName = Videogame (Com Defeito)` 
- Mantém propriedades originais (peso, ícone, tags)
- Pode ser usado como peça para crafting/reparo do funcional (futuro)
- O item funcional (`LKS_Propano.LKS_Videogame`) terá:
  - `RequiresEquipBothHands = TRUE`
  - Peso similar (0.8kg)
  - Tags: `base:hasmetal;base:miscelectronic`
  - Modelo 3D: reutiliza `VideoGame` vanilla ou cria novo

### Detalhamento da Decisão 5 — Arquitetura de Cartuchos (Preparação)

A UI terá um **slot de cartucho** visualmente presente desde a Fase 1:
- ISItemDropBox com ícone de cartucho (backdrop texture)
- Tooltip: "Insira um cartucho de jogo"
- Na Fase 1: slot desabilitado ou mostra "Sem cartucho — Modo Automático"
- Quando cartuchos existirem: inserir cartucho habilita minijogo correspondente
- Cada minijogo roda em um ISPanel com canvas (drawRect, drawLine, drawText)
- Tela do minijogo: retângulo escuro dentro da janela, simula tela do Game Boy
