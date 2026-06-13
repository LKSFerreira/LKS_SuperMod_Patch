# Walkthrough - Integração Nativa e Correção do Fridges Off!

Este documento descreve a fagocitação nativa das mecânicas de ligar/desligar geladeiras do mod *Fridges Off!* no **LKS SuperMod Patch**, e a solução para o bug de refrigeração infinita sem energia na Build 42.

## O que foi feito

### 1. Cópia e Adaptação dos Códigos e Recursos
- Importamos os scripts originais e os colocamos na estrutura do patch:
  - [fridgesoff_client.lua](common/media/lua/client/fridgesoff_client.lua)
  - [fridgesoff_server.lua](common/media/lua/server/fridgesoff_server.lua)
- Copiamos as texturas originais de tomada desligada para a pasta de interface do patch:
  - `common/media/ui/Container_FridgeOff.png`
  - `common/media/ui/Container_FreezerOff.png`

### 2. Correção do Bug de Refrigeração Infinita na Build 42
- **Problema original**: A engine Java de refrigeração da Build 42 aplicava resfriamento caso o tipo do contêiner contivesse as palavras `"fridge"` ou `"freezer"`. O tipo original `"fridge_off"` ativava a refrigeração do Java, mas como o gerador procurava pela string exata `"fridge"`, o consumo de eletricidade ficava zerado (energia grátis).
- **Nossa solução**: Refatoramos toda a lógica do cliente e do servidor para alterar o tipo do contêiner desligado para:
  - Geladeira desligada: **`"geladeira_desligada"`**
  - Freezer desligado: **`"congelador_desligado"`**
- Como esses termos não contêm os radicais `"fridge"` nem `"freezer"`, a refrigeração nativa cessa imediatamente ao desligar da tomada, e o consumo de eletricidade cai a zero no gerador de forma 100% correta e balanceada.

### 3. Integração das Traduções em PT-BR e Melhoria Visual
- Adicionamos as chaves de menu de contexto no [ContextMenu.json](common/media/lua/shared/Translate/PTBR/ContextMenu.json):
  ```json
  "ContextMenu_TurnOn": "Ligar",
  "ContextMenu_TurnOff": "Desligar",
  ```
- Adicionamos os títulos dos contêineres no [IG_UI.json](common/media/lua/shared/Translate/PTBR/IG_UI.json):
  ```json
  "IGUI_ContainerTitle_geladeira_desligada": "Geladeira desligada",
  "IGUI_ContainerTitle_congelador_desligado": "Freezer desligado",
  ```
- Integramos os ícones `LKS_Pwr_On.png` (Ligar) e `LKS_Pwr_Off.png` (Desligar) ao menu de contexto do mundo das geladeiras no script cliente.

### 4. Padronização e Autoria dos Assets (`LKS_`)
- Renomeamos todos os assets do painel elétrico de `PB_*.png` para `LKS_*.png` em `common/media/ui/` para refletir a autoria própria das artes pelo desenvolvedor.
- Atualizamos todas as referências no código nos scripts `PB_UI_DebugPanel.lua`, `PB_ContextMenu_Generator.lua` e `PB_UI_GeneratorInfoWindow.lua`.

---

## Como Validar Manualmente
1. Entre no jogo com o mod ativo (sem o mod *Fridges Off!* original).
2. Clique com o botão direito em uma geladeira e selecione **"Desligar"** (confirmando a exibição do ícone de tomada desligada vermelha `LKS_Pwr_Off` ao lado da opção).
3. Confirme que o título do contêiner no inventário mudou para *"Geladeira desligada"* e o ícone de tomada desligada do inventário é exibido.
4. Clique com o botão direito na geladeira desligada e confirme a opção **"Ligar"** com o ícone de tomada verde `LKS_Pwr_On`.
5. Verifique na janela **Informações Elétricas da Construção** do gerador que o consumo elétrico caiu/subiu instantaneamente.
6. Coloque um alimento perecível (ex: peixe fresco) e acelere o tempo para confirmar que ele estraga no ritmo normal (sem refrigeração fantasma) quando a geladeira estiver desligada.
