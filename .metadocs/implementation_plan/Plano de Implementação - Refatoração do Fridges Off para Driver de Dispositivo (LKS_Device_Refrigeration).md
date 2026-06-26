# Refatoração do Fridges Off para Driver de Dispositivo (LKS_Device_Refrigeration)

Este plano descreve a refatoração e integração completa do mod Fridges Off ao ecossistema de dispositivos controlado pelo `LKS_ApplianceManager`. O script do cliente será migrado para a pasta `devices/` como um driver de dispositivo estruturado, e o script do servidor será padronizado.

## User Review Required

> [!IMPORTANT]
> **Expansão do Appliance Manager (Kernel)**:
> Para dar suporte a aparelhos que não herdam de classes Java exclusivas de eletrodomésticos (como geladeiras e freezers, que no PZ são representados por `IsoObject` genéricos com contêineres), expandiremos a lógica de roteamento do menu de contexto em [LKS_ApplianceManager.lua](common/media/lua/client/LKS_ApplianceManager.lua) para buscar também via **tipo de contêiner** no `containerTypeMap`.
>
> Isso preserva a integridade de colisão do menu de contexto e evita que a interação com outros objetos genéricos do mundo colida com o driver de refrigeração.

---

## Proposed Changes

### Kernel de Dispositivos (Appliance Manager)

#### [MODIFY] [LKS_ApplianceManager.lua](common/media/lua/client/LKS_ApplianceManager.lua)
*   Modificar a função `onFillWorldObjectContextMenu` para que, se nenhum driver for detectado via `instanceof` de classe Java, ela tente detectar o driver com base no tipo de contêiner (`recipiente:getType()`) consultando o `LKS_ApplianceManager.containerTypeMap`.

---

### Módulo do Cliente (Devices)

#### [NEW] [LKS_Device_Refrigeration.lua](common/media/lua/client/devices/LKS_Device_Refrigeration.lua)
*   **Declaração do Driver**: Criar o driver `LKS_Device_Refrigeration` mapeando os contêineres `"fridge"`, `"freezer"`, `"geladeira_desligada"`, `"congelador_desligado"`.
*   **Timed Action**: Declarar a Timed Action `ISToggleFridgesFreezers` para gerenciamento da aproximação física e envio de pacotes de rede para ligar/desligar.
*   **Menu de Contexto**: Implementar a lógica de construção de menu de contexto `construirMenuContexto` adicionando as opções "Ligar" e "Desligar" com ícones e tooltips apropriados.
*   **Textura de Inventário**: Implementar a lógica `obterTexturaInventario` para substituir dinamicamente o ícone do contêiner nas abas laterais do inventário (Loot Window) se estiver desligado.
*   **Sincronização Multiplayer**: Escutar o evento `Events.OnServerCommand` para atualizar localmente a recarga visual do inventário e do quadrado físico.
*   **Registro**: Cadastrar o driver nas tabelas de registro dinâmico do `LKS_ApplianceManager`.

#### [DELETE] [LKS_Geladeiras_Client.lua](common/media/lua/client/LKS_Geladeiras_Client.lua)
*   Excluir o script temporário antigo.

---

### Módulo do Servidor (Server)

#### [NEW] [LKS_Device_Refrigeration_Server.lua](common/media/lua/server/LKS_Device_Refrigeration_Server.lua)
*   Copiar a lógica de rede do servidor, renomeando as declarações internas e logs para `LKS_Device_Refrigeration_Server.lua`.
*   Continuar escutando os comandos de rede do cliente via módulo `"fridges-off"` e gerenciando o recálculo do consumo de geradores próximos.

#### [DELETE] [LKS_Geladeiras_Server.lua](common/media/lua/server/LKS_Geladeiras_Server.lua)
*   Excluir o script temporário antigo.

---

## Verification Plan

### Automated Tests
*   Executar ferramentas de linter/validador de sintaxe Lua para certificar a correta escrita das modificações.
    ```powershell
    python tools/LKS_Tools.py -a
    ```

### Manual Verification
*   Validar se as geladeiras e congeladores continuam exibindo o menu contextual de ligar/desligar no jogo e se os ícones do inventário desenergizado funcionam corretamente sob o novo ecossistema integrado.
