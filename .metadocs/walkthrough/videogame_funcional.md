# Walkthrough — Videogame Portátil Funcional

## Contexto

Feature planejada em `.metadocs/feat/video_game.md` e implementada na Fase 1
(Modo Automático). O item vanilla `Base.VideoGame` foi transformado em um
dispositivo funcional com interface completa, sistema de bateria, volume
controlável e mecânicas de risco/recompensa.

---

## O Que Foi Feito

### Item e Script
- Criado `LKS_Entretenimento.LKS_Videogame` com `RequiresEquippedBothHands = true`
- Override do vanilla via `ItemName.json`: "Videogame (Com Defeito)"
- Distribuição de loot em 10 tabelas procedurais via `OnPostDistributionMerge`

### Interface (ISCollapsableWindow)
- Arquitetura modular idêntica ao Walkie-Talkie (RWMElement + RWMPanel)
- 4 módulos: Modo (tela + botões), Energia (baterias), Som (volume + fone), Cartucho
- Componentes reais do PZ: ISItemDropBox, ISBatteryStatusDisplay, ISLedLight
- Mini tela com animação em 3 camadas (texto pulsante + barra corrente + scanline CRT)
- Barra de volume clicável com gradiente verde→amarelo→vermelho

### Mecânica de Jogo
- TimedAction infinita com `stopOnWalk` e `stopOnRun`
- Redução de estresse e depressão proporcional ao volume × multiplicadores
- 2 pilhas obrigatórias, consumidas simultaneamente
- Volume controla: buff de moodles, consumo de bateria, atração de zumbis
- Fone de ouvido: +20% eficiência, -50% consumo, anula atração de zumbis
- Ícone de som alternável (mute/unmute) com assets compostos via `compor_icone.py`

### Preparação Futura
- Slot de cartucho (UI presente, desabilitado)
- Botão [Jogar] desabilitado sem cartucho
- Arquitetura pronta para nova janela de minijogos com canvas

---

## Arquivos Criados/Modificados

| Arquivo | Tipo |
|---------|------|
| `scripts/lks_videogame_items.txt` | Script do item |
| `shared/videogame/LKS_Videogame_Config.lua` | Constantes de balanceamento |
| `client/devices/videogame/LKS_Videogame_Window.lua` | Interface principal |
| `client/devices/videogame/LKS_Videogame_Action.lua` | TimedAction do modo auto |
| `client/devices/videogame/LKS_Videogame_Handler.lua` | Context menu + EveryOneMinute |
| `server/videogame/LKS_Videogame_Distribution.lua` | Distribuição de loot |
| `ui/LKS_Icone_Som_Ativo.png` | Ícone de som ativo |
| `ui/LKS_Icone_Som_Mutado.png` | Ícone de som mutado (composto) |
| `Translate/PTBR/ItemName.json` | Nome do item + vanilla "Com Defeito" |
| `Translate/EN/ItemName.json` | Idem em inglês |
| `Translate/PTBR/IG_UI.json` | Chaves de interface |
| `Translate/EN/IG_UI.json` | Idem em inglês |

---

## Decisões Técnicas

1. **ISCollapsableWindow vs NR_BasePanel**: Optou-se por ISCollapsableWindow com RWMElement
   para manter qualidade idêntica ao Walkie-Talkie sem dependência obrigatória do NeatUI.

2. **modData vs DeviceData**: Usou-se modData do item (não DeviceData Java) para persistência,
   permitindo controle total sem classes Java customizadas.

3. **2 pilhas obrigatórias**: Design de custo-benefício — baterias são recurso valioso no
   apocalipse, incentivando o jogador a balancear volume e duração.

4. **Multiplicadores baseados em 1.0**: Sistema de balanceamento clean — sempre multiplicativo,
   nunca aditivo, evitando acúmulo que zeraria moodles instantaneamente.

5. **Volume como mecânica central**: Não é apenas estético — controla diretamente eficácia,
   consumo e risco (atração de zumbis). Forçando decisão estratégica do jogador.

---

## Como Validar

1. Dar item: `/additem LKS_Entretenimento.LKS_Videogame` + 2x `Base.Battery`
2. Equipar nas mãos → clique direito → "Ligar Videogame"
3. Inserir 2 baterias nos slots (drag-and-drop)
4. Clicar [Auto] → personagem entra em animação, tela mostra ">>> PLAYING <<<"
5. Verificar moodles diminuindo com o tempo (acelerar jogo para testar)
6. Ajustar volume clicando na barra → observar mudança no consumo de bateria
7. Inserir fone → verificar economia e anulação de zumbis
8. Clicar ícone de som → mutar/desmutar → barra esvazia

---

## Pendências Futuras

- [ ] Implementar minijogos reais (Cobrinha, Pong, Pac-man, Tetris, Top-Gear)
- [ ] Sistema de cartuchos (inserir/remover, cada um = um jogo)
- [ ] Janela de jogo com canvas funcional (drawRect/drawLine/drawText)
- [ ] Redução de campo de visão (-80%) — API PZ não identificada
- [ ] Leaderboard multiplayer (GlobalModData preparado)
- [ ] Sentado em cadeiras/sofás/chão (animação complementar)
- [ ] Efeitos sonoros audíveis pelo jogador (bleeps de jogo)
- [ ] Sistema de condição/reparo do item
