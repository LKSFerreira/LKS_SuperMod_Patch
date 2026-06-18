# Roadmap

Use este arquivo como fonte de verdade do andamento do projeto ou estudo.

## Estado atual

- [x] Definir objetivo principal: patch QoL e expansão de mecânicas para Project Zomboid Build 42, com foco em Generator Powered Buildings e integrações LKS.
- [x] Identificar stack e comandos de validação: Lua para scripts do mod, JSON para traduções/sandbox e Python para ferramentas de auditoria.
- [x] Registrar primeira entrega planejada.
- [x] Implementar modularização por Sandbox Options para ativação isolada de mecânicas.

## Próximos passos

- **Mecânica de Fogões e Fornos**: Recategorização dos fogões em 3 tipos (Convencional/Antigo/Indução) com mecânicas de gás, combustível sólido, eletricidade, qualidade de comida e botijões. Design em `documents/mecanica_fogoes_fornos.md`, pesquisa em `documents/pesquisa_fogoes_fase1.md`.
- **Implementação Nativa do Mod de Cheats**: Absorver nativamente o mod de cheats independente (spawner de itens, forçar estados elétricos/hidráulicos, validar mecânicas). Mod ainda não incorporado ao LKS SuperMod Patch.
- **Botão de Ajuda (?) na Interface de Energia**: Ver dívida técnica abaixo.
- **Biodigestor e Gás Renovável**: Mecânica independente de longo prazo. Construção craftável que converte resíduos orgânicos em biogás para restaurar gás encanado pós-corte. Requer Farming + Carpintaria. Será documentada em arquivo de design próprio quando priorizada.

## Dívidas Técnicas

- [x] **Tradução da Categoria de Recipientes**: Corrigir a categoria nativa exibida para itens que comportam fluidos. O jogo exibe genericamente *"Recipiente de Água"*. A proposta é ajustar a tradução (de forma estática e consistente) para exibir *"Recipiente de Líquido"* para todos esses recipientes, independente do fluido atual.

- [ ] **Botão de Ajuda (?) na Interface**: Criar um botão com o ícone "?" na barra da janela de informações de energia. Ao clicar, exibir uma explicação didática da mecânica de compartilhamento de carga de múltiplos geradores e das regras de controle de temperatura (ex: ligar aquecimento no inverno e standby/snowflake no verão para economizar combustível).

- [ ] **Atenção à Compatibilidade com [B42] Useful Barrels**: O criador de *Generator Powered Buildings* (Beathoven) pode ter reaproveitado lógica/arquivos do mod *[B42] Useful Barrels* (particularmente nas mecânicas de barris/combustível). Ao traduzir ou alterar o *Useful Barrels* no futuro, deve-se auditar possíveis colisões de escopo, arquivos clonados ou hooks conflitantes para evitar falhas ou quebras em ambos os sistemas.

- [ ] **Ícones Personalizados do Menu de Botijão de Gás**: Criar ícones PNG dedicados para as opções de menu de contexto de botijão. Atualmente reutiliza `LKS_Connect.png` (Instalar/Trocar) e `LKS_Disconnect.png` (Desinstalar), que são ícones genéricos do sistema elétrico. Desenhar ícones temáticos de gás/botijão para diferenciação visual.

- [ ] **Mapeamento Completo de Propriedades de CraftRecipe (ZedScript)**: A Indie Stone não documenta oficialmente todas as propriedades e valores válidos de `craftRecipe` (ex: `timedAction`, `Tags`, `flags`, `mode`). Realizar engenharia reversa nos scripts vanilla para catalogar e documentar em YAML todas as propriedades aceitas, valores válidos de `timedAction` (com descrição da animação de cada um), `Tags` de estação de craft, `flags` de items e `mode` de consumo. Salvar em `documents/` no mesmo formato de `propriedades_sprite_objetos_pz.yaml`.

- [ ] **Roadmap e Histórico Desatualizados**: Os commits recentes do sprint de Fogões/Gás (sistema de gás, qualidade de comida, modo bateria para indução, botijão, receitas, itens elétricos) não estão refletidos no roadmap nem no histórico. Atualizar ambos os arquivos com o progresso parcial da feature "Mecânica de Fogões e Fornos".

- [ ] **Arquivos Lua Fora da Hierarquia Documentada**: `LKS_Cooking_Quality.lua`, `LKS_Cooking_GasSystem.lua` e `LKS_Cooking_SpriteClassification.lua` estão na raiz de `shared/` ao invés de em subdiretório temático. A arquitetura documenta `core/`, `data/`, `utils/`, `actions/`. Avaliar criação de `shared/cooking/` ou redistribuição nos subdiretórios existentes.

- [ ] **Markdown Solto na Raiz do Repositório**: `persona_prompt.md`, `prompt_crriar_editar_imagens_assets.md` (typo no nome) e `verificar_problemas_compatibilidades.md` estão na raiz sem organização. Migrar para `.metadocs/` ou `documents/` conforme o conteúdo.

- [ ] **Sem Manifesto de Dependências Python**: Nenhum `pyproject.toml` ou inline script dependencies nos 6 scripts de `tools/`. Ambiente não é reproduzível por terceiros via `uv`. Adicionar manifesto ou PEP 723 inline metadata.

- [ ] **`README.MD` com Extensão Maiúscula**: O arquivo na raiz usa `.MD` ao invés da convenção padrão `.md`. Renomear para `README.md`.

## Concluído

- [x] **Melhorias Visuais do Termostato (12/06/2026)**: Ampliação das setas para 24px, alinhamento vertical matemático, resolução de crashes por valor nulo, espaçamento de respiro vertical para evitar cortes e tradução adaptativa para PT-BR.
- [x] **Tradução da Categoria de Recipientes (12/06/2026)**: Sobrescrita da chave nativa do jogo no mod de 'Recipiente de Água' para 'Recipiente de Líquido' estático para todos os recipientes de fluidos.
- [x] **Integração e Correção do Fridges Off! (12/06/2026)**: Incorporação nativa das mecânicas de ligar/desligar geladeiras e congeladores. Solução definitiva do bug de refrigeração infinita sem energia na Build 42 usando os novos tipos 'geladeira_desligada' e 'congelador_desligado'.
- [x] **Ocultação Dinâmica da Conexão Vanilla do Gerador (13/06/2026)**: Ocultação da opção nativa "Conectar Gerador" caso haja edifícios em um raio de 20x20 tiles do aparelho, incentivando a integração à malha realista ("Conectar à Construção") e preservando a conexão nativa apenas para uso ao ar livre/selva.
- [x] **Suporte Elétrico para Máquinas e Registro de Mecânicas (13/06/2026)**: Menus de contexto de controle elétrico para secadoras e lavadoras, suporte à validação de água encanada no B42, troca de ícones dinâmicos nas abas de inventário e registro das documentações de mecânicas em arquivos dedicados na raiz.
- [x] **Desacoplamento e Generalização de Abas Elétricas (13/06/2026)**: Refatoração do monkey patch da Loot Window usando tabela de configurações centralizada em Lua e validação física de propriedades de sprite para resguardar contêineres a combustão (forno a lenha, lareiras).
- [x] **Arquitetura Micro-Kernel e Sistema de Culinária (14/06/2026)**: Refatoração completa para centralização de patches em `LKS_ApplianceManager.lua`, criação de driver de lavanderia `LKS_Device_Laundry.lua` e novo driver de culinária `LKS_Device_Cooking.lua` com detecção de metais no micro-ondas, temperatura em graus Celsius no fogão e texturas desenergizadas.
- [x] **Consolidação das Ferramentas de Auditoria (14/06/2026)**: Migração e unificação de testes em `auditoria_mod.py` como a nova auditoria de assets, com delegação de chamadas a partir de `LKS_Tools.py`, alinhamento dinâmico de tabelas e logs coloridos ANSI em todos os programas Python.
- [x] **Correção de Auditoria e Ajustes do Banner (14/06/2026)**: Resolução de falsos positivos na auditoria, correção e substituição automática de links locais e alinhamento visual simétrico do menu interativo.
- [x] **Padronização do Driver de Refrigeração (14/06/2026)**: Refatoração do Fridges Off para driver `LKS_Device_Refrigeration`, expansão do kernel `LKS_ApplianceManager` e suporte a saves legados.
- [x] **Desacoplamento Nativo do Generator Powered Buildings (14/06/2026)**: Incorporação dos módulos do GeneratorPlus2 como `LKS_EletricidadeConstrucao`, remoção de `require=buildinggenpowerv2`, incompatibilidade explícita com IDs originais, traduções PTBR/EN e flags de sandbox para controle modular.
- [x] **Readequação de Badges e Ajuste de Auditoria (15/06/2026)**: Refinamento do sistema de Badges dinâmicos nos aparelhos e modificação do filtro de integridade em `auditoria_mod.py` para ignorar assets vanilla da Build 42.
- [x] **Ferramentas Python e Documentação (15/06/2026)**: Melhorias em `LKS_Tools.py`, criação de `.github/copilot-instructions.md` e `configurar_terminal.py` para corrigir Shift+Enter no Antigravity IDE e MinTTY.
- [x] **Refactor Cirúrgico do Driver de Culinária (16/06/2026)**: Sequestro do submenu vanilla e filtragem cirúrgica de itens em `LKS_Device_Cooking.lua`.
- [x] **Suíte de Desenvolvimento Unificada — LKS_Debug_Tool (16–17/06/2026)**: Ferramenta de depuração própria (F12) com sistema de abas escalável: Lua Reloader (recarga cirúrgica de scripts), Inspetor de Menu de Contexto e Inspetor de Objetos com tooltips dinâmicos via `LKS_Debug_TooltipData.lua` (303 propriedades de sprite mapeadas). Traduções PT-BR/EN e correções de layout. Não relacionada ao mod de cheats externo.
- [x] **Consolidação de Documentação (17/06/2026)**: Migração de `mecanicas/` para `documents/`, documentação de 303 propriedades de sprite e mapeamento de ferramentas/materiais.

