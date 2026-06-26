# Plano de Implementação - Melhorias de Eletricidade e Visuais para Secadora e Lavadora de Roupas

Este plano descreve as modificações necessárias para dar suporte às regras de eletricidade e aprimoramentos visuais para secadoras de roupas (`IsoClothingDryer`) e lavadoras de roupas (`IsoClothingWasher`) ao interagir via menu de clique direito do mundo.

## User Review Required

> [!NOTE]
> Os novos ícones elétricos serão fornecidos pelo usuário no diretório de assets (`common/media/ui/`). Nós usaremos a nomenclatura padronizada com o prefixo `LKS_` e sufixo `_Electricity_Off.png` baseados no nome do ícone original do inventário.

## Proposed Changes

### Componente: Traduções (Localization)

#### [MODIFY] [IG_UI.json](common/media/lua/shared/Translate/PTBR/IG_UI.json)
Adicionar a chave de tradução para a mensagem de erro do tooltip de falta de energia:
```json
  "IGUI_LKS_RequerEnergiaProxima": "Requer uma fonte de energia próxima."
```

---

### Componente: Menus de Contexto do Cliente (Lua)

#### [NEW] [LKS_ContextMenu_WasherDryer.lua](common/media/lua/client/LKS_ContextMenu_WasherDryer.lua)
Criar um novo arquivo para gerenciar as interações com lavadoras e secadoras no clique direito do mundo:
1. **Identificação**: Detectar se há uma secadora (`IsoClothingDryer`) ou lavadora (`IsoClothingWasher`) no array de objetos sob o clique.
2. **Menu Pai**: Exibir o nome amigável do objeto com seu ícone 32x32 correspondente de inventário (ex: `Container_ClothingDryer.png` ou `Container_ClothingWasher.png`).
3. **Validação de Energia**:
   - **Com Energia** (Square do objeto possui energia ou container está ativo):
     - Se máquina ativada: Opção "Desligar" com ícone `LKS_Button_Power_Off.png`.
     - Se máquina desligada: Opção "Ligar" com ícone `LKS_Button_Power_On.png`.
     - Ao clicar em "Ligar" ou "Desligar", chama as funções nativas de ação do PZ (`ISWorldObjectContextMenu.onToggleClothingDryer` ou `onToggleClothingWasher`).
   - **Sem Energia**:
     - Opção "Ligar" fica vermelha e desabilitada (`notAvailable = true`).
     - Exibe o ícone elétrico off: `LKS_Container_ClothingDryer_Electricity_Off.png` ou `LKS_Container_ClothingWasher_Electricity_Off.png`.
     - Adiciona tooltip explicativo: "Requer uma fonte de energia próxima.".

---

## Verification Plan

### Automated Tests
- Validar a sintaxe do arquivo de tradução JSON.
- Validar a sintaxe do arquivo Lua utilizando scripts de verificação ou simulação local.

### Manual Verification
1. Instalar o mod e iniciar o jogo.
2. Colocar uma secadora/lavadora no chão fora de uma área energizada. Clicar com o botão direito e verificar que o menu principal exibe o ícone 32x32 correto e que o botão "Ligar" está vermelho, desabilitado e com o tooltip de erro apropriado e ícone `_Electricity_Off.png`.
3. Energizar a área (por exemplo, ligando um gerador próximo). Clicar com o botão direito e confirmar que a opção "Ligar" agora exibe o ícone `LKS_Button_Power_On.png` e permite interagir.
4. Ligar a máquina e clicar com o botão direito novamente para confirmar que a opção mudou para "Desligar" com o ícone `LKS_Button_Power_Off.png`.
