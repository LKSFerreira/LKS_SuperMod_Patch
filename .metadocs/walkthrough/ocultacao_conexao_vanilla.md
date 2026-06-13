# Walkthrough - Ocultação Dinâmica da Conexão Vanilla do Gerador

Este documento descreve a lógica implementada no **LKS SuperMod Patch** para ocultar dinamicamente a opção vanilla de conexão de gerador a fim de dar precedência e relevância à mecânica realista de conexão a prédios.

## O que foi feito

### 1. Detecção Inteligente de Prédios (`temConstrucaoNoRaio`)
- Criamos a função auxiliar `temConstrucaoNoRaio(quadrado, raio)` no script [PB_ContextMenu_Generator.lua](common/media/lua/client/PB_ContextMenu_Generator.lua).
- A função escaneia a área ao redor do gerador à procura de qualquer quadrado que possua um objeto de prédio válido (`sq:getBuilding() ~= nil`).

### 2. Remoção Seletiva da Opção Vanilla
- Se um edifício for localizado no raio de **20x20 tiles** (o mesmo raio de operação padrão):
  - A opção vanilla **"Conectar Gerador"** (`ContextMenu_GeneratorPlug`) é removida dinamicamente do menu.
  - Apenas a opção realista **"Conectar à Construção"** é exibida (e fica ativa se o gerador for posicionado corretamente ao lado de uma parede externa, ou inativa com tooltip instrutivo caso contrário).
- Se **nenhum** edifício for localizado no raio de 20x20 tiles (por exemplo, gerador colocado no deserto ou no meio da mata):
  - A opção vanilla **"Conectar Gerador"** continua visível e utilizável pelo jogador.
  - A opção **"Conectar à Construção"** é exibida como indisponível (com o tooltip de aviso).

---

## Como Validar Manualmente
1. **Perto de uma Construção**:
   - Posicione um gerador no chão ao lado de qualquer casa ou construção no raio de 20x20.
   - Clique com o botão direito no gerador e abra a aba **Generator**.
   - Confirme que a opção **"Conectar Gerador"** (com o ícone da tomada amarela/azul) **não é exibida**.
   - Apenas a opção **"Conectar à Construção"** deve estar listada.
2. **Longe de Construções (Área Aberta)**:
   - Posicione o gerador no meio de uma floresta ou campo aberto (sem prédios em um raio de 20x20).
   - Clique com o botão direito, abra a aba **Generator** e confirme que a opção vanilla **"Conectar Gerador"** está visível e funcional.
   - A opção **"Conectar à Construção"** deve aparecer em vermelho (desabilitada) com o tooltip explicativo.
