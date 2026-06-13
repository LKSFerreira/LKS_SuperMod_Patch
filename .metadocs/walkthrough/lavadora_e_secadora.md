# Walkthrough - Suporte Elétrico para Máquinas e Registro de Mecânicas

Este documento descreve as implementações de suporte elétrico, hidráulico e visual para secadoras e lavadoras de roupas, além da centralização e documentação das mecânicas do patch no diretório `mecanicas/`.

---

## 🛠️ O que foi feito

### 1. Menu de Contexto Dinâmico para Lavadora e Secadora
- **Remoção de Menus Java**: Implementamos a varredura e remoção completa das opções nativas geradas pelo Java no menu de contexto (como "Secadora Branca" e "Máquina de Lavar Branca"). Isso elimina erros de inicialização de submenus e sub-opções nulas (`subOption = nil`).
- **Recriação do Menu no Cliente**: Recriamos a opção pai e o submenu do zero de forma exclusiva no cliente, com o ícone 32x32 correspondente ao inventário da máquina.
- **Ordenação no Topo**: Utilizamos o método `addOptionOnTop` para que a interação com a máquina seja exibida sempre no topo das interações de clique direito.
- **Validação Hidráulica**: A lavadora de roupas agora exige água ativa no reservatório de fluidos (`getFluidAmount() > 0`) para permitir ser ligada.
- **Validação de Energia**: Se a máquina estiver desenergizada ou sem água, a opção de ligar fica vermelha/desabilitada, concatenando as mensagens de erro nos tooltips ("Requer uma fonte de energia próxima" e/ou "Requer encanamento de água").

### 2. Ações de Interação Seguras (Timed Actions)
- **Substituição de Método**: Trocamos o método `addGetUpOption` por `addOption` comum no menu de contexto. Isso resolve o travamento da fila de ações temporizadas do personagem, deixando o gerenciamento da aproximação física do jogador sob controle seguro do método nativo `luautils.walkAdj`.

### 3. Customização Dinâmica de Abas de Inventário (Loot Window)
- **Monkey Patch Seguro**: Realizamos um patch na função `ISInventoryPage:addContainerButton` para interceptar a renderização das abas de inventário laterais.
- **Ícones Desenergizados**: Caso o quadrado da lavadora (`clothingwasher`) ou secadora (`clothingdryer`) perca energia elétrica, a aba correspondente exibe automaticamente a textura desenergizada (`LKS_Container_ClothingWasher_Eletricity_Off.png` e `LKS_Container_ClothingDryer_Eletricity_Off.png`), atualizando visualmente em tempo real.

### 4. Telemetria e Padronização de Logs
- **Logs de Inicialização**: Inserimos as mensagens padronizadas de início e fim no console para garantir o monitoramento completo do carregamento dos scripts do mod:
  - `common/media/lua/client/PB_ClientInit.lua`
  - `common/media/lua/client/PB_ContextMenu_Barrel.lua`
  - `common/media/lua/client/fridgesoff_client.lua`
  - `common/media/lua/server/fridgesoff_server.lua`

### 5. Documentação de Mecânicas na Raiz
- **Nova Pasta de Mecânicas**: Criamos o diretório `mecanicas/` na raiz do mod e registramos os seguintes guias explicativos de funcionamento físico e lógico:
  - `mecanicas/encanamento_agua.md`: Regras de gravidade, ferramentas e fluidos do PZ B42.
  - `mecanicas/eletricidade_realista.md`: Regras da rede Power Pool e consumo do Powered Buildings.
  - `mecanicas/ligar_desligar_geladeiras.md`: Arquitetura cliente/servidor do mod Fridges Off.

---

## 🔎 Como Validar Manualmente

### Validação das Máquinas (Lavadora e Secadora)
1. **Sem Energia**: Aproxime-se de uma lavadora/secadora desenergizada. Verifique que a opção de ligação está vermelha, exibe o tooltip explicativo e a aba lateral do inventário possui a tomada desligada.
2. **Com Energia**: Ligue um gerador conectado. Verifique que as abas de inventário voltam a exibir a textura original colorida.
3. **Sem Água (Lavadora)**: Tente ligar a lavadora sem água encanada. Verifique que o botão de ligar fica desativado e o tooltip exibe a pendência hidráulica.
4. **Com Água (Lavadora)**: Conecte um coletor de chuva no nível superior usando uma Chave de Cano. Verifique se a opção de ligar fica ativa com o ícone de tomada verde (`LKS_Pwr_On.png`).

### Validação das Documentações
- Verifique a presença dos arquivos na pasta `mecanicas/` do mod na raiz do projeto.
