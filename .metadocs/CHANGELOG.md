# Histórico de Engenharia e Refatoração — LKS SuperMod Patch

Este documento serve como diretriz técnica e registro de alterações para o **LKS SuperMod Patch** (voltado para o mod *Generator Powered Buildings* na Build 42 do Project Zomboid). A arquitetura deste patch foi fundamentada em três pilares indispensáveis: **Documentação Estruturada**, **Alta Manutenibilidade** e **Isolamento de Código/Assets** para evitar quebras por atualizações do mod original.

---

## 1. Padronização de Documentação e Fluxo de Trabalho (Workflow)

Para garantir que o projeto seja escalável à medida que novos patches de outros mods forem integrados, o sistema de documentação pública foi completamente reestruturado.

* **`README.md` (GitHub):** Atualizado para utilizar o padrão moderno de alertas do GitHub (`> [!IMPORTANT]`) para destacar requisitos obrigatórios de carregamento. Adicionada uma **Tabela de Compatibilidade Dinâmica** para catalogar os mods cobertos e seus respectivos IDs da Oficina Steam.
* **`readme_steam.txt` (BBCode):** Criado um gabarito espelhado convertendo toda a estrutura do Markdown para a sintaxe BBCode aceita pela Steam (incluindo as tags `[table]`, `[tr]`, `[th]`, `[td]`).
* **Fluxo de Manutenção:** O processo de adição de novos mods foi centralizado em inserções de linhas simples nas tabelas de ambos os arquivos, reduzindo o mofamento de informações.

---

## 2. Auditoria e Engenharia Reversa do Termostato

Realizada uma investigação profunda na lógica de controle térmico implementada pelo desenvolvedor original nos arquivos `PB_UI_GeneratorInfoWindow.lua`, `PB_ClientCommands.lua` e `PB_Config.lua` para verificar regras de negócio ocultas.

* **A Trava de Escala Térmica:** Descobriu-se que a janela de interface aplica um *clamp* rígido via código limitando a operação do jogador entre **15°C e 30°C** (`math.max(15, math.min(30, currentTemp + delta))`).
* **Alinhamento com o Mundo Real:** Validou-se que esta faixa de temperatura é baseada em padrões reais de engenharia de climatização (normas internacionais **ASHRAE**).
* *Inverno (20°C a 23°C)* e *Verão (23°C a 26°C)* como zonas de conforto humano baseado no isolamento das roupas.
* *15°C* como piso de economia energética e *30°C* como teto extremo de esforço mecânico, que no mod dispara a barra de sobrecarga (*Strain*) do gerador.


* **Segurança de Sandbox:** Identificou-se que o Administrador do servidor possui uma trava separada no ModData permitindo configurar limites mais amplos de **-20°C a 40°C** via menu administrativo, enquanto o painel do usuário final fica protegido contra abusos térmicos.

---

## 3. Refatoração Técnica de Arquivos Lua

Os arquivos Lua interceptados pelo patch foram reestruturados para remover más práticas do autor original, como caminhos de arquivos espalhados brutos (*hardcoded*) no meio de funções.

### 📑 `common/media/lua/client/PB_ContextMenu_Generator.lua`

* **Centralização de Texturas:** Todos os caminhos de assets de interface foram extraídos das funções lógicas e centralizados em uma tabela de constantes (`local TEX_...`) no topo do arquivo.
* **Tradução de Engenharia:** Todos os logs de erro do terminal, comentários de desenvolvimento e strings de *fallback* textual pós-operador `or` foram 100% traduzidos e adaptados para PT-BR.
* **Correção de Fluxo Planejado (Padrão PB):** O autor original havia adicionado um asset chamado `pb_pwr.png` na pasta, mas esqueceu de alterar o código Lua, deixando o sistema amarrado aos assets legados da versão V1 (`pwr_on.png` e `pwr_off.png`). O código foi corrigido e atualizado para o novo padrão de prefixos unificados: **`PB_Pwr_On.png`** e **`PB_Pwr_Off.png`**.
* **Rastreamento de Console:** Padronizada a saída de depuração no terminal para expor explicitamente o escopo do arquivo: `[LKS PATCH - PB_ContextMenu_Generator.lua]`.

### 📑 `common/media/lua/client/ui/PB_UI_DebugPanel.lua`

* **Correção de Sufixos de Assets:** Identificados dois arquivos que quebravam a padronização do mod original por utilizarem o identificador no final do nome (`quadPB.png` e `housePB.png`). Foram renomeados para o padrão de prefixos limpos: **`PB_Quad.png`** e **`PB_House.png`**.
* **Nacionalização da Interface de Desenvolvedor:** Toda a HUD de debug, tooltips detalhados explicativos do sistema de radar de malhas de salas da engine (`IsoRegions`) e balões de fala de aviso de negação de acesso do personagem (`player:Say`) foram completamente traduzidos para o português.
* **Rastreamento de Console:** Injeção do cabeçalho de auditoria e assinatura de log padronizada: `[LKS PATCH - PB_UI_DebugPanel.lua]`.

---

## 4. Auditoria de Assets e Eliminação de Código Morto (*Bloat*)

Para cumprir o princípio de não distribuir arquivos desnecessários (*Mod Bloat*) que sobrecarregam o download dos jogadores e poluem o repositório, foi desenvolvido um script automatizado de validação cruzada em Python.

### 🐍 O Script Automatizado (`tools/find_files.py`)

O script realiza a leitura binária e textual de toda a árvore do diretório, cruzando todas as imagens físicas das pastas `ui` e `textures` contra strings declaradas em arquivos `.lua`, `.txt`, `.json` e `.md`.

### 📊 Resultado da Auditoria Geral

O script localizou e isolou **8 ativos orfãos/mortos** deixados pelo desenvolvedor original como resíduo de rascunhos ou mecânicas abandonadas:

```text
❌ common\media\textures\Item_lighting_indoor_01_0.png  -> (Item de inventário abandonado)
❌ common\media\textures\Item_lighting_indoor_01_5.png  -> (Item de inventário abandonado)
❌ common\media\ui\boarder_ui_win_pow.png               -> (Borda de janela descartada; erro de digitação)
❌ common\media\ui\ddown.png                             -> (Asset de Dropdown substituído)
❌ common\media\ui\ddown_s.png                           -> (Asset de Dropdown substituído)
❌ common\media\ui\pb_info.png                           -> (Substituído por PB_Gen_Info.png)
❌ common\media\ui\pb_pwr.png                            -> (Substituído por PB_Pwr_On / Off)
❌ common\media\ui\rrr.png                               -> (Rascunho temporário de imagem)

```

**Diretriz de Manutenção:** Estes 8 arquivos **não devem ser incluídos** na pasta de assets do `LKS SuperMod Patch`. O patch deve conter exclusivamente as imagens novas e modificadas que são efetivamente invocadas pelas constantes do código Lua refatorado.