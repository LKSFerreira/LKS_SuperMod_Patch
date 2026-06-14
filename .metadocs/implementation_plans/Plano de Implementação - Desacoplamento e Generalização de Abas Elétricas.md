# Plano de Implementação - Desacoplamento e Generalização de Abas Elétricas

Este plano detalha a refatoração do *monkey patch* da Loot Window (`ISInventoryPage:addContainerButton`) no arquivo [LKS_ContextMenu_WasherDryer.lua](file:///common/media/lua/client/LKS_ContextMenu_WasherDryer.lua). O objetivo é centralizar as lógicas de ícones elétricos em uma tabela de configuração dinâmica e implementar uma validação de propriedade física para evitar que contêineres de combustão manual (como forno a lenha, lareiras ou churrasqueiras) sejam incorretamente marcados como desenergizados.

## User Review Required

> [!IMPORTANT]
> **Diferenciação de Forno Elétrico vs. Forno a Lenha**:
> No Project Zomboid, ambos usam strings de contêiner muito próximas ou idênticas (como `stove`). Para evitar que o forno a lenha ("Antique Stove") exiba ícones de tomada desligada (já que ele funciona puramente a carvão/madeira), nossa lógica inspecionará a propriedade do Sprite do objeto no mapa buscando a chave `"RequiresElectricity" == "true"`.

## Proposed Changes

### Componente: Menus de Contexto e Interface do Cliente (Lua)

#### [MODIFY] [LKS_ContextMenu_WasherDryer.lua](file:///common/media/lua/client/LKS_ContextMenu_WasherDryer.lua)

1. **Definição da Tabela de Configuração**:
   Criar a tabela `LKS_ConfiguracaoAbasEletricas` mapeando os tipos conhecidos de contêineres elétricos e suas respectivas texturas ligadas e desligadas (off):
   ```lua
   local LKS_ConfiguracaoAbasEletricas = {
       clothingwasher = {
           imagemOn = "media/ui/Container_ClothingWasher.png",
           imagemOff = "media/ui/LKS_Container_ClothingWasher_Electricity_Off.png"
       },
       clothingdryer = {
           imagemOn = "media/ui/Container_ClothingDryer.png",
           imagemOff = "media/ui/LKS_Container_ClothingDryer_Electricity_Off.png"
       },
       fridge = {
           imagemOn = "media/ui/Container_Fridge.png",
           imagemOff = "media/ui/Container_FridgeOff.png"
       },
       freezer = {
           imagemOn = "media/ui/Container_Freezer.png",
           imagemOff = "media/ui/Container_FreezerOff.png"
       },
       microwave = {
           imagemOn = "media/ui/Container_Microwave.png",
           imagemOff = "media/ui/LKS_Container_Microwave_Electricity_Off.png" -- Deixado mapeado para suporte futuro
       },
       stove = {
           imagemOn = "media/ui/Container_Stove.png",
           imagemOff = "media/ui/LKS_Container_Stove_Electricity_Off.png", -- Deixado mapeado para suporte futuro
           requerVerificacaoEletrica = true -- Sinaliza que o sprite precisa ser checado para diferenciar de fornos a lenha
       }
   }
   ```

2. **Validação Robusta no Monkey Patch**:
   Refatorar a interceptação em `ISInventoryPage:addContainerButton` para:
   - Obter a configuração a partir de `LKS_ConfiguracaoAbasEletricas[tipoContainer]`.
   - Se `requerVerificacaoEletrica` for verdadeiro, obter o objeto pai (`recipiente:getParent()`) e verificar se o sprite do objeto possui a propriedade `"RequiresElectricity" == "true"`. Caso contrário, ignorar o tratamento (preservando o comportamento para fornos a lenha).
   - Alterar dinamicamente a entrada correspondente em `ContainerButtonIcons` verificando o estado atual da energia do quadrado físico do contêiner (`recipiente:isPowered()`).

---

## Verification Plan

### Automated Tests
- Validar a sintaxe do arquivo Lua atualizado para garantir que não haja erros de estrutura ou parênteses.

### Manual Verification
1. **Teste de Forno Elétrico vs. Forno a Lenha**:
   - Adicione no jogo um Forno Elétrico e um Forno a Lenha ("Antique Stove").
   - Com a energia da vizinhança desligada, abra o inventário de ambos.
   - O Forno Elétrico (se tiver sua textura off implementada futuramente ou mapeada) responderá à lógica elétrica, enquanto o Forno a Lenha deve manter seu ícone de inventário colorido normal e inalterado.
2. **Teste de Lavadoras e Secadoras**:
   - Verificar se o comportamento dinâmico de troca de tomada (On/Off nas abas de inventário) continua funcionando de forma perfeita através da nova tabela centralizada.
