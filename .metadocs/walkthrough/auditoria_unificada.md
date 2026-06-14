# Walkthrough - Consolidação e Unificação da Auditoria de Código e Assets

Este documento descreve a consolidação do sistema de testes e auditorias técnicas do mod em uma suíte unificada, a delegação dinâmica por subprocessos do menu interativo e a padronização de formatação e colorização ANSI no terminal do desenvolvedor.

---

## 🛠️ O que foi feito

### 1. Centralização da Auditoria de Assets Órfãos (`auditoria_mod.py`)
- **Migração de Lógica:** Migramos o algoritmo de detecção de imagens órfãs (Módulo 4) da pasta `media/ui` de [LKS_Tools.py](tools/LKS_Tools.py) para o script consolidado [auditoria_mod.py](tools/auditoria_mod.py).
- **Consolidação do Relatório:** A execução padrão de [auditoria_mod.py](tools/auditoria_mod.py) (sem argumentos) agora roda de forma integrada os 4 testes de sanidade técnica do mod:
  1. Validação de Sintaxe Lua
  2. Auditoria de Traduções PT-BR
  3. Auditoria de Vazamento de Caminhos Absolutos
  4. Auditoria de Imagens Órfãs/Sem Uso na interface do Mod

### 2. Alinhamento Dinâmico de Tabelas no Console
- **Espaçamento Inteligente:** A tabela do Módulo 4 calcula dinamicamente a largura máxima necessária com base no maior nome de arquivo de imagem antes de aplicar a formatação do console.
- **Resolução de Desalinhamento ANSI:** As cores ANSI são aplicadas no texto após a formatação de espaçamento da coluna, impedindo que caracteres de escape invisíveis contem na largura da string e desalinhem a divisória de coluna `|`.

### 3. Padronização e Colorização de Logs ANSI
- **Interface Visual Unificada:** Todos os utilitários Python passaram a suportar a colorização padrão do mod:
  - **Verde (`\033[32m`):** Mensagens positivas, status de sucesso `[+]` ou `[OK]`.
  - **Vermelho (`\033[31m`):** Mensagens de falha, erros críticos `[-]` ou `[FALHA]`.
  - **Amarelo (`\033[33m`):** Avisos, instruções ou alertas suspeitos `[!]`.
  - **Ciano (`\033[36m`):** Ações de inicialização `[*]`.
- **Scripts Atualizados:** Adicionamos definições de cores e suporte a consoles do Windows nos arquivos [auditoria_mod.py](tools/auditoria_mod.py) e [atualizar_dicionario_tilesets.py](tools/atualizar_dicionario_tilesets.py).

### 4. Delegação e Retrocompatibilidade (`LKS_Tools.py`)
- **Delegação por Subprocesso:** O menu interativo (opção `[4]`) e a flag de linha de comando (`-a` / `--auditar`) do [LKS_Tools.py](tools/LKS_Tools.py) agora invocam o script [auditoria_mod.py](tools/auditoria_mod.py) por meio de um subprocesso Python. Isso centraliza toda a lógica de auditorias em um local único, mantendo a retrocompatibilidade e evitando códigos duplicados.
- **Rótulo Atualizado:** O texto da opção 4 no menu foi alterado de *"Auditar Código do Mod (Buscar imagens órfãs/sem uso)"* para *"Executar Auditoria Completa do Mod (auditoria_mod.py)"*.

---

## 🔎 Como Validar Manualmente

### 1. Auditoria Unificada com Cores
1. Execute o comando `python tools/auditoria_mod.py` (ou `completa`).
2. Verifique se os 4 módulos são executados em sequência e se o relatório final consolidado apresenta os status de sucesso `[OK]` coloridos em **verde**.

### 2. Delegação no Gerenciador de Assets
1. Execute `python tools/LKS_Tools.py`.
2. Selecione a opção `[4]` do menu.
3. Confirme que a suíte completa de auditoria roda via subprocesso e retorna o relatório perfeitamente alinhado com a divisória `|` na mesma posição vertical.
