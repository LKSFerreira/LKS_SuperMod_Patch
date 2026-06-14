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
- **Tabela de Configuração Dinâmica**: Introduzimos a tabela `LKS_ConfiguracaoAbasEletricas` para desacoplar as strings rígidas de tipo de contêiner. Agora, geladeiras, congeladores, lavadoras, secadoras e micro-ondas buscam suas texturas ativa/inativa de forma dinâmica e limpa na tabela.
- **Proteção a Dispositivos Manuais/Combustão**: Para evitar falsos positivos em dispositivos como o Forno a Lenha clássico ("Antique Stove") que compartilham o mesmo tipo de container (`stove`) mas funcionam sem eletricidade, adicionamos a propriedade `requerVerificacaoEletrica`. Quando ativa, a lógica inspeciona se o sprite do objeto possui a propriedade `"RequiresElectricity" == "true"` antes de aplicar qualquer alteração de ícone.

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

### Validação de Dispositivos Não-Elétricos (Antique Stove/Lareiras)
1. Certifique-se de que a energia da rede geral da construção está cortada/desligada.
2. Abra o inventário de um Forno a Lenha ("Antique Stove") ou lareira.
3. Confirme que o ícone de inventário dele permanece colorido e inalterado (a validação de `"RequiresElectricity"` funcionou, ignorando-o).

### Validação das Documentações
- Verifique a presença dos arquivos na pasta `mecanicas/` do mod na raiz do projeto.
