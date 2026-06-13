# Walkthrough - Integração Realista de Eletricidade e Tradução LKS

Este documento descreve a consolidação técnica de todas as alterações, melhorias de UX/UI, traduções e padrões de código aplicados no **LKS SuperMod Patch** para os módulos de eletricidade e refrigeração.

---

## 🛠️ O que foi feito

### 1. Fagocitação e Correção do *Fridges Off!*
- **Integração Nativa**: Copiamos os scripts cliente/servidor e os assets de inventário originais do mod *Fridges Off!* para a estrutura do patch, eliminando a dependência externa na Steam.
- **Correção da Refrigeração Infinita (Build 42)**: A engine do jogo em Java ativa o resfriamento nativo se o nome do contêiner contiver o radical `"fridge"` ou `"freezer"`. Para resolver o bug de energia grátis do gerador, redefinimos os contêineres inativos para:
  - Geladeira desligada: **`"geladeira_desligada"`**
  - Freezer desligado: **`"congelador_desligado"`**
- **Melhoria Visual**: Adicionamos os ícones de tomada `LKS_Pwr_On.png` (verde) e `LKS_Pwr_Off.png` (vermelho) às opções de menu de contexto das geladeiras no cliente.

### 2. Renomeação e Autoria de Assets (`LKS_`)
- **Renomeação Física**: Modificamos todos os arquivos de imagem de interface originais de `PB_*.png` para `LKS_*.png` em `common/media/ui/` para marcar a autoria própria das artes feitas ou editadas pelo criador do patch.
- **Atualização de Referências**: Corrigimos todas as constantes e strings de caminhos nos scripts `PB_UI_DebugPanel.lua`, `PB_ContextMenu_Generator.lua` e `PB_UI_GeneratorInfoWindow.lua`.

### 3. Ocultação Dinâmica da Conexão Vanilla de Gerador
- **Função `temConstrucaoNoRaio`**: Criamos uma função de busca geométrica em Lua que verifica a existência de edifícios em um raio de 20x20 tiles do gerador.
- **Remoção de Redundância**: 
  - Se houver uma construção no raio, a opção vanilla **"Conectar Gerador"** é removida do menu de contexto, forçando o jogador a usar a conexão realista do mod (**"Conectar à Construção"**).
  - Se estiver em campo aberto (longe de prédios), a opção vanilla **"Conectar Gerador"** permanece visível para permitir a energização simples de aparelhos ao ar livre.

### 4. Correção e Auditoria de Traduções PT-BR
- **Mapeamento de Chaves**: Identificamos e adicionamos traduções essenciais que estavam pendentes no arquivo [IG_UI.json](common/media/lua/shared/Translate/PTBR/IG_UI.json):
  - `"IGUI_NoBuildingNearby_Desc"`: Traduzido como *"O gerador deve ser colocado ao lado de uma construção com paredes"*.
  - `"IGUI_ConnectRequiresKnowledge"`: Traduzido como *"Requer a receita de Gerador ou Elétrica Nível 3)"*.
  - `"IGUI_Generator_CannotActivate"`: Traduzido como *"Não é possível ligar o gerador"*.
- Isso evita que o jogo carregue os fallbacks em inglês herdados do mod base.

### 5. Homenagem e Agradecimento aos Criadores
- **Créditos Preservados**: Inserimos cabeçalhos de agradecimento personalizados e mantivemos os comentários EmmyLua originais no topo de todos os scripts herdados de outros mods, honrando o trabalho de **Erick** (*Fridges Off!*) e **Beathoven** (*Generator Powered Buildings*).

### 6. Padrões de Código para Lua (`lua.md`)
- **Regras Criadas**: Criamos o arquivo de especificações [.agents/rules/lua.md](.agents/rules/lua.md) seguindo as diretrizes do PEP 8/Python, definindo tipagem com EmmyLua, português estrito e proibição de abreviações para funções de autoria própria.

---

## 🔎 Como Validar Manualmente

### Validação de Geladeiras (Fridges Off!)
1. Clique com o botão direito em uma geladeira e selecione **"Desligar"** (confirme a exibição do ícone de tomada desligada vermelha).
2. Verifique se o título do contêiner no inventário mudou para *"Geladeira desligada"* e o ícone do contêiner atualizou.
3. Confirme que o consumo de energia no painel do gerador diminuiu.
4. Ligue novamente usando a opção **"Ligar"** (com o ícone de tomada verde).

### Validação do Menu do Gerador
1. **Próximo de Casa**: Coloque um gerador perto de uma construção. Abra o menu e confirme que a opção vanilla **"Conectar Gerador"** sumiu, restando apenas **"Conectar à Construção"**.
2. **No Campo**: Coloque o gerador a mais de 20 tiles de qualquer prédio. Confirme que a opção **"Conectar Gerador"** reaparece no menu, enquanto a opção **"Conectar à Construção"** fica desativada (vermelha) com a descrição traduzida em pt-BR explicativa.
