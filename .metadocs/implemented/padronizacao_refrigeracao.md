# Walkthrough - Padronização do Driver de Refrigeração e Retrocompatibilidade

Este documento detalha a refatoração arquitetural aplicada no mod Fridges Off para integrá-lo como o driver oficial `LKS_Device_Refrigeration` no kernel de dispositivos, bem como a resolução do bug de interface em saves legados.

---

## 🛠️ O que foi feito

### 1. Expansão de Roteamento no Kernel (`LKS_ApplianceManager`)
*   **Motivação**: Geladeiras e freezers no Project Zomboid B42 são representados por objetos genéricos do tipo `IsoObject` com contêineres e não por classes dedicadas no Java (como `IsoStove`).
*   **Implementação**: Modificamos a busca de cliques do menu de contexto em `LKS_ApplianceManager.lua` para que, caso a busca por classe Java falhe, faça um fallback buscando o driver registrado baseado no **tipo do contêiner** (`recipiente:getType()`). Isso impede conflito de colisões com outros cliques no mundo.

### 2. Criação do Driver Oficial (`LKS_Device_Refrigeration`)
*   **Localização**: `common/media/lua/client/devices/LKS_Device_Refrigeration.lua`
*   **Lógica**:
    *   Cadastrado nos recipientes `"fridge"`, `"freezer"`, `"geladeira_desligada"`, `"congelador_desligado"` e nas chaves legadas `"fridge_off"`, `"freezer_off"`.
    *   Gerenciamento da timed action `ISToggleFridgesFreezers` para ligar e desligar.
    *   Implementação do método `obterTexturaInventario` para substituir a aba lateral pelo ícone desligado correspondente.
    *   Criação de opções premium no menu contextual (`construirMenuContexto`) com ícones dinâmicos de tomada.
    *   Escuta ao evento `Events.OnServerCommand` para sincronizar estados elétricos no multiplayer e recarregar inventários locais.

### 3. Ajuste do Servidor (`LKS_Device_Refrigeration_Server`)
*   **Localização**: `common/media/lua/server/LKS_Device_Refrigeration_Server.lua`
*   **Lógica**: Recebe comandos de rede `"fridges-off"` e realiza a alteração de tipo dos contêineres físicos no mapa, forçando o recálculo do consumo de combustíveis de geradores próximos na vizinhança.

### 4. Correção e Retrocompatibilidade com Saves Legados
*   **Problema**: O mod de Erick utilizava os tipos de contêineres `"fridge_off"` e `"freezer_off"`. Saves existentes que continham geladeiras desligadas com estes tipos quebravam a interface do inventário exibindo o erro visual `!Needs IGUI_ContainerTitle defined for: fridge_off`.
*   **Solução**:
    *   Inserimos as chaves de tradução correspondentes em português no `IG_UI.json`.
    *   Mapeamos o driver cliente e o processamento de rede do servidor para tratar esses tipos legados de forma idêntica à normalizada do patch. Ao religar o aparelho, o tipo é migrado automaticamente para as chaves vanilla do jogo base (`fridge` e `freezer`).

---

## 🔎 Validação e Auditoria

A suite unificada de auditoria foi executada e validada:
```powershell
python tools/LKS_Tools.py -a
```
*   **Validação de Sintaxe Lua**: 13/13 arquivos Lua validados com sucesso (incluindo os novos drivers cliente e servidor).
*   **Mapeamento de Traduções**: 100% das chaves mapeadas com arquivos JSON locais.
*   **Integridade de Assets**: Todas as texturas e ícones de tomada off estão referenciados no código Lua.
