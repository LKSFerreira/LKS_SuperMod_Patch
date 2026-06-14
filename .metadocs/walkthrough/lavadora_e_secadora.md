# Walkthrough - Suporte Elétrico e Visuais para Lavanderia (Washer, Dryer e Combo)

Este documento descreve as implementações de suporte elétrico, hidráulico e visual para secadoras, lavadoras de roupas e o modelo integrado de Lavadora e Secadora (Combo Washer Dryer), além da padronização de nomenclatura de assets e documentações associadas.

---

## 🛠️ O que foi feito

### 1. Menu de Contexto Dinâmico para Lavanderia (Washer, Dryer e Combo)
- **Remoção de Menus Java**: Removemos as opções nativas geradas pelo Java no menu de contexto ("Secadora Branca" e "Máquina de Lavar Branca"). Isso elimina erros de inicialização de submenus e sub-opções nulas (`subOption = nil`).
- **Detecção do Combo Washer Dryer**: Adicionamos o suporte para a classe Java `IsoCombinationWasherDryer` e a flag `isComboLavadoraSecadora`. Como o Combo herda da classe `IsoClothingWasher`, ele é detectado **antes** da lavadora comum no loop de objetos do mundo.
- **Tabela Centralizada de Configuração (`LKS_ConfiguracaoIconesLavanderia`)**:
  Criamos uma tabela centralizada no topo do arquivo [LKS_ContextMenu_WasherDryer.lua](file:///common/media/lua/client/LKS_ContextMenu_WasherDryer.lua) para gerenciar os ícones de cada máquina quando ligada/desligada, permitindo fácil acoplamento de futuras variantes (como a lavadora branca).
- **Validação Hidráulica por Modo (Combo)**:
  - **Modo Secagem (Dryer):** O Combo não exige água no reservatório para funcionar. Ele pode ser ligado mesmo que o reservatório esteja zerado, exigindo apenas fornecimento de energia elétrica.
  - **Modo Lavagem (Washer) e Lavadoras Comuns:** Exige água ativa no reservatório de fluidos (`getFluidAmount() > 0`) para permitir ligar o equipamento. Se desenergizado ou sem água, a opção de ligar fica desativada (notAvailable = true), exibindo o respectivo ícone explicativo e mensagens no tooltip.
- **Alternância de Modos do Combo**:
  Adicionamos a opção dinamicamente no submenu do Combo ("Modo: Secadora" ou "Modo: Lavadora" conforme a tradução e o estado atual) para alternar o modo físico de funcionamento. Utiliza a timed action correta `ISWorldObjectContextMenu.onSetComboWasherDryerMode`.
- **Ações de Ativação Seguras (Timed Actions)**:
  Utiliza callbacks nativos seguros (`onToggleClothingDryer` para secadora, `onToggleClothingWasher` para lavadora e `onToggleComboWasherDryer` para o Combo). Isso resolve o travamento de fila de ações e chama as funções apropriadas para cada tipo de classe Java.

### 2. Customização Dinâmica de Abas de Inventário (Loot Window) e Ícones
- **Monkey Patch Seguro para Combo**: Estendemos o patch na função `ISInventoryPage:addContainerButton` para interceptar a aba lateral de inventário e obter o objeto pai (`recipiente:getParent()`).
- **Lógica Acumulativa de Ícones (Context Menu e Loot Window)**:
  - **Sem Energia:** Se o aparelho estiver sem energia, o ícone de tomada desligada (`Combo_Washer_Dryer_Gray_Electricity_Off.png`) é utilizado. Este estado tem a prioridade máxima.
  - **Energizado, Sem Água (Modo Lavagem):** Se a máquina estiver energizada, sem água e no modo de lavagem, exibe o ícone de gota d'água riscada (`Combo_Washer_Dryer_Gray_Water_Off.png`).
  - **Energizado e Operacional:** Em perfeito estado (ou no modo secagem que dispensa água), exibe o ícone original cinza (`Combo_Washer_Dryer_Gray.png`).
- Lavadoras e secadoras comuns utilizam seus respectivos ícones nativos (com energia) e as versões personalizadas `_Electricity_Off.png` (sem energia).

### 3. Correção Ortográfica e Padronização de Assets
- Varremos todo o mod e metadocs corrigindo a nomenclatura obsoleta dos assets para:
  - `_Electricity_Off.png` (corrigindo a grafia antiga `Eletricity`)
  - `LKS_Button_Power_On.png` / `LKS_Button_Power_Off.png` (substituindo `LKS_Pwr_On/Off`)
  - `LKS_Take_Generator.png` (substituindo `LKS_Take_Gen`)
  - `LKS_House_Electricity_On.png` / `LKS_House_Electricity_Off.png` (substituindo `LKS_House_Eletricity`)
  - `LKS_Fix_Generator.png` (substituindo `LKS_Fix_Generator.png`)

---

## 🔎 Funcionamento de Encanamento (Plumbing)

Para que a opção de plumbing ("Conectar Canos") apareça no menu de clique direito do mundo, o Project Zomboid exige:
1. **Ambiente Interno (Indoors):** O objeto de destino deve estar posicionado **dentro de um edifício/construção** (propriedade do grid square `isOutside() == false`). Não é possível conectar canos em lavadoras ou pias expostas na grama.
2. **Fonte de Água:** Deve haver um coletor de chuva (Rain Collector Barrel) no piso diretamente acima (um nível `z` superior) na mesma coordenada horizontal ou adjacente.
3. **Ferramenta:** O jogador deve carregar uma **Pipe Wrench** (Chave de Cano) no inventário de mão principal.
4. **Estado de Movimentação:** Se o objeto foi gerado de forma nativa pelo mapa, o jogo já o define como plumbed por padrão (flag `waterPiped` ativa). Ao utilizar a ferramenta de movimentar (pegar e colocar), a conexão se desfaz e a opção de "Conectar Canos" é habilitada no clique direito.

---

## 🔎 Como Validar Manualmente

### Validação das Máquinas (Lavadora, Secadora e Combo)
1. **Sem Energia**: Aproxime-se de qualquer uma das três máquinas sem energia ativa na área. Verifique que a opção de ligação está vermelha, exibe o tooltip explicativo e a aba lateral do inventário possui a tomada desligada (`_Electricity_Off.png`).
2. **Alternância de Modo (Combo)**:
   - Altere o modo do Combo para **Lavagem**. Verifique que a opção Ligar fica desabilitada e vermelha com tooltip se não houver água, e o ícone na Loot Window e no menu exibe `Combo_Washer_Dryer_Gray_Water_Off.png`.
   - Altere o modo para **Secagem**. Verifique que a opção Ligar fica ativa (verde) mesmo sem nenhuma gota de água na máquina (desde que haja energia elétrica), e o ícone na Loot Window e no menu volta para `Combo_Washer_Dryer_Gray.png`.
3. **Plumbing (Conexão)**:
   - Posicione o Combo dentro de uma casa (indoors).
   - Coloque um coletor de chuva no andar superior (um nível acima) e verifique se a opção "Conectar Canos" aparece disponível no menu de contexto (seja ativa com chave de cano ou desabilitada em vermelho se faltar a chave).
