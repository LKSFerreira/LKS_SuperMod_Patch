# Videogame Funcional — Design de Mecânica

## Visão Geral

Transformar o item vanilla `Base.VideoGame` (Eletrônico, 0.8kg) em um dispositivo funcional que **reduz estresse e depressão** quando usado pelo jogador. A implementação reaproveita a arquitetura de UI do Walkie-Talkie (janela de dispositivo com energia, controles e estado).

---

## Requisitos de Uso

| Requisito | Detalhe |
|-----------|---------|
| **Item** | `Base.VideoGame` equipado nas duas mãos |
| **Baterias** | 2 pilhas (`Base.Battery`) inseridas no dispositivo |
| **Fones** | Fone de ouvido equipado (opcional para bônus? ou obrigatório?) |
| **Estado** | Ligar o dispositivo (botão na janela, como Walkie-Talkie) |

---

## Efeitos

- **Reduz estresse** (Moodle: Stress)
- **Reduz depressão** (Moodle: Unhappiness)
- Taxa de redução proporcional ao tempo jogando
- No estresse/depressão MÁXIMO → zerar em **6 horas** de uso contínuo

---

## Consumo de Energia

- **2 pilhas** obrigatórias (slot duplo de bateria na janela)
- Duração máxima: **2 horas** com 2 pilhas cheias (100%)
- Quando baterias acabam → desliga automaticamente
- **Custo-benefício:** Alto consumo de bateria, alta recompensa (redução significativa de moodles)

---

## Modos de Uso

### Modo 1: Automático

- Jogador clica "Jogar" na janela do dispositivo
- Personagem joga automaticamente (animação idle/sentado)
- Continua até:
  - Estresse E depressão chegarem a zero, OU
  - Bateria acabar, OU
  - Jogador cancelar (mover-se, clicar)
- **Tempo máximo para zerar moodles máximos:** 6 horas

### Modo 2: Minijogos Manuais (Interativo)

Minijogos reais jogáveis dentro do PZ, desenvolvidos por nós:

| Minijogo | Controles | Descrição |
|----------|-----------|-----------|
| **Cobrinha** | Teclado (setas) | Snake clássico, fases progressivas |
| **Ping Pong** | Mouse ou teclado | Pong contra IA, dificuldade crescente |
| **Outros (futuro)** | Teclado e/ou mouse | A definir |

**Recompensa por fase:** Ao completar uma fase, reduz X de estresse e Y de depressão (ao invés de redução por hora).

| Fase | Redução (a balancear) |
|------|----------------------|
| Fase 1 concluída | -X estresse, -Y depressão |
| Fase 2 concluída | -X estresse, -Y depressão |
| Fase 3+ concluída | -X estresse, -Y depressão (bônus progressivo?) |

> **Nota de balanceamento:** Valores exatos de redução por fase serão definidos em playtesting. O princípio é que jogar manualmente (minijogos) dá recompensa MELHOR que o modo automático por unidade de tempo — incentivando o jogador a realmente jogar.

---

## Referência de Implementação: Janela do Walkie-Talkie

A UI do Walkie-Talkie (`ISRadioWindow`) serve como base. Elementos a reaproveitar:

| Elemento Walkie-Talkie | Equivalente Videogame |
|------------------------|----------------------|
| Seção "Energia" | Seção "Energia" — 2 slots de bateria + indicador % |
| Botão "Ligar" | Botão "Ligar" |
| Ícone de fone | Ícone de fone (conectar headset) |
| Barra de bateria | Barra de bateria (2x) |
| Seção "Volume" | **Remover** (não necessário) |
| Seção "Sinal/Canal" | **Substituir por:** seletor de minijogo ou botão "Jogar" |
| Seção "Microfone" | **Remover** |

### Janela Proposta (Esboço)

```
┌─────────────────────────────────┐
│  ✕    Videogame                 │
├─────────────────────────────────┤
│           Energia               │
│  ○ Ligar  🎧  ○ ██████ 100%    │
│                ○ ██████ 100%    │
├─────────────────────────────────┤
│            Modo                 │
│  [ Automático ]  [ Minijogos ] │
├─────────────────────────────────┤
│         (se Minijogos)          │
│  [ 🐍 Cobrinha ] [ 🏓 Pong ]  │
│                                 │
│       Fase atual: 3             │
│       Recorde: Fase 7           │
├─────────────────────────────────┤
│          Status                 │
│  Estresse: ████░░░░ -12/h       │
│  Depressão: ██░░░░░░ -8/h       │
└─────────────────────────────────┘
```

---

## Modelo Base: Walkie-Talkie vs Alternativas

### Por que Walkie-Talkie é boa referência:

- Já tem janela de dispositivo funcional com bateria e ligar/desligar
- Suporte a fones de ouvido
- Consumo de bateria por uso
- UI modular com seções (Energia, controles, estado)
- Código Lua acessível (`ISRadioWindow.lua`, `ISRadio*.lua`)

### Possível alternativa: ISReadABookAction

O vanilla já tem `ISReadABookAction` que reduz tédio. Poderia servir como referência para a parte de "usar item por tempo = reduzir moodle". Mas a UI do Walkie-Talkie é superior para nosso caso por ter janela dedicada.

### Arquivos vanilla de referência:

- `media/lua/client/ISUI/ISRadioWindow.lua` — Janela principal do rádio/walkie
- `media/lua/client/RadioData/` — Sistema de rádio (bateria, frequência)
- `media/lua/client/TimedActions/ISReadABookAction.lua` — Ação de ler (reduz tédio)
- `media/lua/shared/NPCs/Moodles.lua` — Sistema de moodles (Stress, Unhappiness)

---

## Números para Balanceamento (Rascunho)

| Parâmetro | Valor |
|-----------|-------|
| Baterias necessárias | 2 |
| Duração total (baterias cheias) | 2 horas in-game |
| Tempo para zerar estresse máximo (automático) | 6 horas |
| Tempo para zerar depressão máxima (automático) | 6 horas |
| Redução por fase (minijogo) — Estresse | A balancear |
| Redução por fase (minijogo) — Depressão | A balancear |
| Bônus por fone de ouvido | A definir (mais imersão = mais redução?) |

**Implicação do custo:** Como baterias duram 2h e zerar moodles leva 6h, o jogador precisa de **3 pares de baterias** (6 pilhas) para zerar completamente no modo automático. Isso torna baterias um recurso valioso e incentiva o modo minijogos (que dá recompensa por fase, não por tempo).

---

## Fases de Implementação (Proposta)

### Fase 1 — Modo Automático + Janela Básica
- Reestruturar `Base.VideoGame` para aceitar 2 baterias
- Criar janela derivada de ISRadioWindow (Energia + Ligar)
- Implementar TimedAction que reduz estresse/depressão por tick
- Consumo de bateria proporcional ao tempo

### Fase 2 — Minijogo: Cobrinha
- Criar ISPanel com canvas de jogo
- Implementar lógica Snake (grid, movimento, crescimento, fases)
- Integrar recompensa por fase completada
- Tela de game over / reiniciar

### Fase 3 — Minijogo: Ping Pong
- Criar ISPanel com canvas de jogo
- Implementar lógica Pong (bola, raquetes, IA)
- Dificuldade progressiva por fase
- Recompensas por fase

### Fase 4 — Polimento
- Fones de ouvido como bônus de eficiência
- Sons de jogo (bips, efeitos — apenas com fone)
- Animação do personagem jogando
- Salvar recordes por save

---

## Notas Técnicas

- O item `Base.VideoGame` já existe no vanilla — precisamos modificar seu script para aceitar baterias (ou criar item derivado `LKS_Propano.LKS_Videogame`)
- A decisão de usar item vanilla vs criar novo depende de compatibilidade com outros mods
- Minijogos rodam em ISPanel com canvas — PZ permite `drawRect`, `drawLine`, `drawText` em tempo real
- O sistema de moodles é acessível via `jogador:getBodyDamage():setUnhappynessLevel()` e `jogador:getStats():setStress()`
