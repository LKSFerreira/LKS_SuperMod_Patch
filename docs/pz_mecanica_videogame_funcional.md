# Mecânica — Videogame Portátil Funcional

Documentação da mecânica do videogame portátil implementada no LKS SuperMod Patch.

---

## Visão Geral

O item `LKS_Entretenimento.LKS_Videogame` é um dispositivo portátil funcional que o jogador
equipa nas duas mãos. Ao ligar e usar no modo automático, reduz estresse e depressão
progressivamente, com consumo de bateria proporcional ao volume do som.

O item vanilla `Base.VideoGame` foi renomeado para "Videogame (Com Defeito)" e permanece
no loot como item inerte (sem funcionalidade).

---

## Requisitos de Uso

| Requisito | Detalhe |
|-----------|---------|
| Item | `LKS_Entretenimento.LKS_Videogame` equipado nas duas mãos |
| Baterias | 2 pilhas (`Base.Battery`) obrigatórias, ambas com carga > 0 |
| Fone | Opcional — bônus multiplicativo de eficiência e economia |

---

## Interface (ISCollapsableWindow + RWMElement)

A janela usa a mesma arquitetura modular do Walkie-Talkie vanilla:

| Módulo | Conteúdo |
|--------|----------|
| **Modo** | Mini tela animada (OFF/READY/PLAYING) + botões [Auto] e [Jogar] |
| **Energia** | 2x (LED + ISItemDropBox bateria + ISBatteryStatusDisplay) |
| **Som** | Ícone mute/unmute + barra de volume clicável + ISItemDropBox fone |
| **Cartucho** | ISItemDropBox (desabilitado — preparação futura para minijogos) |

### Componentes Reais Utilizados

- `ISCollapsableWindow` — janela principal (mesmo tipo do Walkie-Talkie)
- `RWMElement` — wrapper com título colapsável por módulo
- `RWMPanel` — base de cada subpainel
- `ISItemDropBox` — drag-and-drop para baterias, fone e cartucho
- `ISBatteryStatusDisplay` — barra de carga com gradiente e percentual
- `ISLedLight` — indicador LED verde/apagado

---

## Sistema de Volume (0-100%)

O jogador controla o volume clicando na barra. O volume afeta 3 mecânicas:

| Volume | Buff Moodles | Consumo Bateria | Atração Zumbis |
|--------|-------------|-----------------|----------------|
| 0% | Nenhuma redução | Mínimo | Nenhuma |
| 50% | 50% da base | Proporcional | Sim (raio 5 tiles) |
| 100% | 100% da base × eficaciaVolume | Máximo | Sim (raio 5 tiles) |
| Mutado | Nenhuma | Nenhum | Nenhuma |

### Fórmulas

```
reducaoMoodle = taxaBase * (volume/100) * eficaciaVolume * eficaciaFone
consumoBateria = consumoBase * (volume/100) * pesoVolumeNaBateria * economiaFone
```

Todos os multiplicadores são baseados em 1.0 (neutro) e compostos multiplicativamente.

---

## Sistema de Bateria

- 2 pilhas obrigatórias (ambas devem ter carga)
- Drenam simultaneamente (metade do consumo para cada)
- Carga armazenada em modData do item (`LKS_VG_bateria1_carga`, `LKS_VG_bateria2_carga`)
- Inserção/remoção via drag-and-drop (ISItemDropBox) ou clique direito
- Auto-desliga quando ambas zeradas

---

## Fone de Ouvido (Bônus Multiplicativo)

| Efeito | Valor Padrão |
|--------|-------------|
| Eficiência na redução de moodles | ×1.2 (+20%) |
| Economia de bateria | ×0.5 (consome metade) |
| Anula atração de zumbis | Sim |

O fone é inserido via drag-and-drop no slot dedicado (seção Som).

---

## Atração de Zumbis

- Som emitido a cada minuto de jogo quando volume > 10%
- Raio: 5 tiles (configurável)
- Anulado por: fone de ouvido conectado OU mute ativo
- API: `character:addWorldSoundUnlessInvisible(raio, volume, false)`

---

## Modo Automático (TimedAction)

Ao clicar [Auto]:
- Personagem entra em animação de leitura (`CharacterActionAnims.Read`, ReadType `"book"`)
- Modelo 3D do videogame renderizado na mão
- Redução de estresse e depressão a cada minuto de jogo
- Continua indefinidamente até: jogador se mover, baterias acabarem, ou clicar [Parar]

### Condições de Parada
- `stopOnWalk = true` (jogador andou)
- `stopOnRun = true` (jogador correu)
- Baterias zeradas (Handler detecta via EveryOneMinute)
- Jogador clica [Parar] na interface

---

## Modo Manual (Futuro — Cartucho)

Preparação arquitetônica presente:
- Slot de cartucho na interface (desabilitado)
- Botão [Jogar] desabilitado sem cartucho
- Quando implementado: cada cartucho = um minijogo (Cobrinha, Pong, etc.)
- Nova janela será aberta com canvas funcional para jogabilidade real

---

## Variáveis de Balanceamento (LKS_Videogame_Config.lua)

| Variável | Valor Padrão | Descrição |
|----------|-------------|-----------|
| `horasParaZerarEstresse` | 3 | Horas para zerar estresse máximo |
| `horasParaZerarDepressao` | 3 | Horas para zerar depressão máxima |
| `horasDuracaoBaterias` | 2 | Duração com 2 pilhas novas |
| `volumeInicial` | 70 | Volume padrão ao primeiro uso |
| `eficaciaVolume` | 1.0 | Multiplicador de buff por volume |
| `eficaciaFone` | 1.2 | Multiplicador com fone (+20%) |
| `economiaFone` | 0.5 | Consumo com fone (50%) |
| `pesoVolumeNaBateria` | 1.0 | Impacto do volume no consumo |
| `raioAtracaoZumbis` | 5 | Tiles de atração |
| `foneAnulaAtracaoZumbis` | true | Fone bloqueia atração |

---

## Distribuição de Loot

O item funcional aparece nas mesmas categorias do vanilla com cobertura reduzida
(10 tabelas vs 28 do vanilla), tornando-o mais raro como item valioso:

- Lojas de eletrônicos (peso 10)
- Caixas de brinquedos (peso 4)
- Quartos de criança/guarda-roupas (peso 2)
- Mesas/estantes genéricas (peso 1-2)
- Loja de penhores (peso 10)
- Garagens (peso 0.2)

---

## Persistência (modData)

| Chave | Tipo | Descrição |
|-------|------|-----------|
| `LKS_VG_bateria1_carga` | float | Carga bateria slot 1 (0-100) |
| `LKS_VG_bateria2_carga` | float | Carga bateria slot 2 (0-100) |
| `LKS_VG_bateria1_id` | int | ID do item bateria inserido |
| `LKS_VG_bateria2_id` | int | ID do item bateria inserido |
| `LKS_VG_fone_tipo` | string | FullType do fone inserido |
| `LKS_VG_volume` | int | Volume atual (0-100) |
| `LKS_VG_mutado` | bool | Se está mutado |
| `LKS_VG_jogando` | bool | Se está no modo auto |
| `LKS_VG_cartuchoInserido` | string | FullType do cartucho (futuro) |
