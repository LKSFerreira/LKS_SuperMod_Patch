# Roadmap

Use este arquivo como fonte de verdade do andamento do projeto ou estudo.

## Estado atual

- [x] Definir objetivo principal: patch QoL e expansão de mecânicas para Project Zomboid Build 42, com foco em Generator Powered Buildings e integrações LKS.
- [x] Identificar stack e comandos de validação: Lua para scripts do mod, JSON para traduções/sandbox e Python para ferramentas de auditoria.
- [x] Registrar primeira entrega planejada.
- [x] Implementar modularização por Sandbox Options para ativação isolada de mecânicas.

## Próximos passos

- **Suíte de Desenvolvimento e Testes (Retrabalho do Mod de Cheats)**: Redesenhar o módulo de cheats para atuar como uma suíte de auxílio ao desenvolvimento de mods (*developer tools*), permitindo spawnar, forçar estados elétricos/hidráulicos e validar mecânicas locais de forma rápida, isolada e opcional.

## Dívidas Técnicas

- [x] **Tradução da Categoria de Recipientes**: Corrigir a categoria nativa exibida para itens que comportam fluidos. O jogo exibe genericamente *"Recipiente de Água"*. A proposta é ajustar a tradução (de forma estática e consistente) para exibir *"Recipiente de Líquido"* para todos esses recipientes, independente do fluido atual.

- [ ] **Botão de Ajuda (?) na Interface**: Criar um botão com o ícone "?" na barra da janela de informações de energia. Ao clicar, exibir uma explicação didática da mecânica de compartilhamento de carga de múltiplos geradores e das regras de controle de temperatura (ex: ligar aquecimento no inverno e standby/snowflake no verão para economizar combustível).

- [ ] **Atenção à Compatibilidade com [B42] Useful Barrels**: O criador de *Generator Powered Buildings* (Beathoven) pode ter reaproveitado lógica/arquivos do mod *[B42] Useful Barrels* (particularmente nas mecânicas de barris/combustível). Ao traduzir ou alterar o *Useful Barrels* no futuro, deve-se auditar possíveis colisões de escopo, arquivos clonados ou hooks conflitantes para evitar falhas ou quebras em ambos os sistemas.

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

