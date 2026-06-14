# Walkthrough - Arquitetura Micro-Kernel e Sistema de Culinária (Cooking)

Este documento detalha a refatoração da arquitetura de eletrodomésticos do mod para um padrão Micro-Kernel e a implementação do driver de culinária para fogões (`IsoStove`) e micro-ondas (`IsoMicrowave`), incluindo avisos de segurança e texturas exclusivas para o estado sem energia.

---

## 🛠️ O que foi feito

### 1. Refatoração para Arquitetura Micro-Kernel (`LKS_ApplianceManager.lua`)
- **Registro Central de Drivers**: Criamos o gerenciador centralizado [LKS_ApplianceManager.lua](file:///common/media/lua/client/LKS_ApplianceManager.lua) para gerenciar o ciclo de vida dos aparelhos interativos do mod.
- **Ponto Único de Patches (Single Source of Truth)**: Centralizamos os monkey patches da Loot Window (`ISInventoryPage:addContainerButton`) e os hooks do menu de contexto de objetos do mundo (`ISWorldObjectContextMenu`). 
- **Despacho Dinâmico**: O Kernel detecta a classe Java e o tipo de objeto, encaminhando a customização de abas e os submenus de contexto para os drivers de dispositivo correspondentes registrados no mapa `LKS_ApplianceManager.drivers`.
- **Inicialização Defensiva**: Os arquivos utilizam a declaração defensiva `LKS_ApplianceManager = LKS_ApplianceManager or {}` para evitar dependências rígidas na ordem de carregamento de scripts pelo Project Zomboid (que segue ordem alfabética).

### 2. Migração do Driver de Lavanderia (`LKS_Device_Laundry.lua`)
- **Isolamento de Domínio**: Migramos toda a lógica de lavadoras, secadoras e combos do arquivo antigo para [LKS_Device_Laundry.lua](file:///common/media/lua/client/devices/LKS_Device_Laundry.lua).
- **Adequação às Diretrizes de Código**: Renomeamos variáveis internas para o português estrito e expressivo (ex: `jogadorObjeto`, `propriedadesObjeto`, `texturaIconeMenu`), eliminando variáveis de uma ou duas letras e abreviações para total legibilidade.
- **Remoção de Código Morto**: O arquivo `LKS_LaundrySystem_WasherDryer.lua` foi removido do diretório raiz.

### 3. Implementação do Driver de Culinária (`LKS_Device_Cooking.lua`)
- **Novo Driver de Dispositivos**: Criamos o driver [LKS_Device_Cooking.lua](file:///common/media/lua/client/devices/LKS_Device_Cooking.lua) focado em fogões (`IsoStove`) e micro-ondas (`IsoMicrowave`).
- **Texturas Exclusivas para Estado sem Energia**:
  - Implementamos ícones específicos para a Loot Window e o menu de contexto quando o aparelho está desenergizado:
    - Fogão sem energia: `Container_Stove_Electricity_Off.png`
    - Micro-ondas sem energia: `Container_Microwave_Electricity_Off.png`
- **Mecânicas de Segurança no Fogão**:
  - Menu de contexto exibe o status térmico atual estimado do fogão em graus Celsius (`°C`).
  - Alerta visual vermelho (`<RGB:1,0,0>`) em tooltips caso o fogão esteja ligado e aquecido, sinalizando o risco de incêndio.
- **Mecânicas de Segurança no Micro-ondas**:
  - Varredura de contêineres para detecção de metais (como panelas ou latas de alumínio).
  - Alerta visual amarelo (`<RGB:1,1,0>`) informando a presença de metais no compartimento e o risco iminente de faíscas ou explosão caso seja ligado.
  - Inclusão de um bloco `TODO` estruturado detalhando a mecânica futura de física de explosão e incêndio no grid square.

---

## 🔎 Como Validar Manualmente

### 1. Validação do Fogão (IsoStove)
1. **Sem Energia**: Verifique se a aba lateral do inventário do fogão exibe a textura desenergizada (`Container_Stove_Electricity_Off.png`).
2. **Com Energia**: Ligue o fogão e altere a temperatura. Aproxime-se e clique com o botão direito para ver o menu.
3. **Temperatura**: Verifique se o menu e o tooltip exibem a temperatura estimada em graus Celsius (ex: `35°C`).
4. **Alerta de Incêndio**: Quando o fogão estiver ligado e aquecendo, verifique se o tooltip exibe o alerta de segurança em vermelho.

### 2. Validação do Micro-ondas (IsoMicrowave)
1. **Sem Energia**: Verifique se a aba do inventário do micro-ondas exibe o ícone cinza correspondente (`Container_Microwave_Electricity_Off.png`).
2. **Aviso de Metal**:
   - Insira um objeto de metal (ex: `Base.Pot`, `Base.TinCan`) no inventário do micro-ondas.
   - Abra o menu de contexto do micro-ondas e valide se a linha ou o tooltip exibe o alerta de metal presente em amarelo.
