# Resolução de Conflito - Funcionamento do Encanamento e Modos do Combo

Este documento registra o diagnóstico e a resolução técnica dos comportamentos inesperados identificados na integração do Combo Washer Dryer (`IsoCombinationWasherDryer`), detalhando o funcionamento do sistema de encanamento do Project Zomboid Build 42 e as regras de negócio de modos de operação e ícones acumulativos.

---

## 🔍 1. O Problema Relatado
Durante os testes de validação do Combo Washer Dryer:
1. A opção de encanamento ("Conectar Canos") não aparecia ao interagir com o Combo no mundo (ao contrário da máquina de lavar comum).
2. O jogador não conseguia alternar entre os modos de lavagem e secagem.
3. A validação hidráulica estava impedindo a ativação do Combo mesmo em modo de Secagem (que não consome água).

---

## 🛠️ 2. Diagnóstico Técnico e Soluções

### A. Ações Temporizadas (Timed Actions) Distintas
No Project Zomboid B42, o Combo Washer Dryer possui um conjunto de timed actions exclusivas na API Java e Lua que diferem das lavadoras e secadoras individuais:
- **Ativação (Ligar/Desligar):** Utiliza a classe `ISToggleComboWasherDryer` e a função `onToggleComboWasherDryer` em vez de `onToggleClothingWasher`.
- **Alternância de Modo:** Utiliza a classe `ISSetComboWasherDryerMode` e a função `onSetComboWasherDryerMode`.

**Solução:** Refatoramos as chamadas de callback no menu de contexto ([LKS_ContextMenu_WasherDryer.lua](common/media/lua/client/LKS_ContextMenu_WasherDryer.lua)) para invocar os manipuladores corretos de ativação e modo do Combo.

---

### B. Menu de Sub-opções de Modo
Como o menu de contexto original do Java foi substituído para permitir a injeção estética de nossos ícones e a ordenação UX no topo, a opção de alternância de modo ("Modo: Secadora" ou "Modo: Lavadora") precisou ser manualmente recriada no submenu do cliente.

**Solução:** Adicionamos a opção dinamicamente no submenu usando a timed action de modo nativa, exibindo o ícone original correspondente ao modo de destino para melhor feedback visual.

---

### C. Validação Hidráulica por Modo de Operação
O Combo Washer Dryer desempenha dois papéis:
- **Modo Secagem (Dryer):** Opera apenas com eletricidade (não requer água).
- **Modo Lavagem (Washer):** Opera com eletricidade e exige reservatório de água abastecido.

**Solução:** Ajustamos o script de contexto para que a checagem de água (`getFluidAmount() > 0`) seja ignorada quando o Combo estiver em modo secagem (`objetoEletrico:isModeWasher() == false`).

---

### D. Lógica Acumulativa de Ícones (Loot Window & Menu)
Para refletir o estado real do aparelho de forma consistente nas abas laterais de inventário e nos ícones de menu:
- **Prioridade Máxima (Sem Energia):** O ícone de tomada desligada (`Combo_Washer_Dryer_Gray_Electricity_Off.png`) predomina e é exibido sempre que a área estiver desenergizada, independente de haver água ou não.
- **Prioridade Média (Sem Água no Modo Lavagem):** Se houver energia elétrica mas a máquina estiver sem água e no modo de Lavagem, exibe o ícone de gota d'água riscada (`Combo_Washer_Dryer_Gray_Water_Off.png`).
- **Estado Normal / Operacional:** Se energizada (e com água, caso em modo lavagem), exibe o ícone normal cinza (`Combo_Washer_Dryer_Gray.png`).

---

## 🔎 3. Regras de Encanamento (Plumbing) no Project Zomboid B42

A ausência da opção de encanamento ("Conectar Canos") no clique direito é governada por validações nativas do motor do jogo (Java). Para que a opção seja exibida, os seguintes critérios técnicos do mapa e do jogador devem ser atendidos:

1. **Restrição de Ambiente Interno (Indoors):**
   O grid square (`IsoGridSquare`) onde o objeto está posicionado **não pode ser considerado área externa** (a propriedade `square:isOutside()` deve ser `false`). O motor de jogo bloqueia a conexão hidráulica de objetos colocados na grama, terra ou em decks externos sem teto/paredes reconhecidos como uma "room".
2. **Posicionamento da Fonte de Água:**
   Deve existir um reservatório coletor de água (como um Rain Collector Barrel) no nível diretamente acima (coordenada `z + 1`) posicionado exatamente na mesma coordenada `x`/`y` do aparelho ou em uma das 8 células adjacentes.
3. **Ferramenta de Trabalho:**
   O jogador deve portar uma chave de cano (*Pipe Wrench* / `Base.PipeWrench` ou tags equivalentes). Se os critérios de posicionamento forem válidos mas faltar a ferramenta, a opção de plumbing aparece vermelha e desabilitada (com o tooltip explicativo). Se o posicionamento for inválido, a opção sequer é ofertada pelo motor.
4. **Resets de Estado na Movimentação:**
   Dispositivos gerados na criação do mapa começam com a flag `waterPiped` ativada por padrão no sprite. Ao usar a ferramenta de mover (pegar e colocar), a conexão se desfaz (zerando o estado em Java) e a propriedade de mod data `canBeWaterPiped` é definida como `true`, liberando a opção de encanar no clique direito do mundo.
