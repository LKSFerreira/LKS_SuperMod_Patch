# Histórico

Registre aqui entregas concluídas, decisões importantes e links para walkthroughs.

## Entradas

- **12/06/2026**: [Renderização de Fluidos](walkthrough/renderizacao_fluidos.md) - Correção da renderização de recipientes com fluidos no menu do gerador e registro de dívidas técnicas.
- **12/06/2026**: [Melhorias Visuais do Termostato](walkthrough/visual_termostato.md) - Escalonamento das setas para 24px, ajustes de alinhamento vertical, espaçamento de respiro de 12px e tradução adaptativa para PT-BR.
- **12/06/2026**: [Tradução de Categorias de Recipientes](walkthrough/traducao_recipientes.md) - Sobrescrita de categoria estática para "Recipiente de Líquido" na Build 42.
- **12/06/2026**: [Integração e Correção do Fridges Off!](walkthrough/fagocitacao_fridges_off.md) - Fagocitação nativa e solução definitiva da refrigeração fantasma sem consumo usando novos tipos em português.
- **13/06/2026**: [Ocultação Dinâmica da Conexão Vanilla](walkthrough/ocultacao_conexao_vanilla.md) - Ocultação inteligente da opção 'Conectar Gerador' quando houver edifícios no raio de 20x20 tiles para privilegiar a mecânica realista.
- **13/06/2026**: [Consolidação da Eletricidade Realista LKS](walkthrough/patch_lks_eletricidade_construcao.md) - Walkthrough mestre consolidando a fagocitação de geladeiras, renomeação de assets LKS, tooltips e as regras de estilo de código Lua.
- **13/06/2026**: [Suporte Elétrico para Máquinas e Registro de Mecânicas](walkthrough/lavadora_e_secadora.md) - Melhorias de UX, suporte hidráulico/elétrico para secadoras e lavadoras de roupas, e centralização da documentação de funcionamento das mecânicas na raiz.
- **14/06/2026**: [Suporte Completo a Combos e Ícones de Lavanderia](walkthrough/lavadora_e_secadora.md) - Implementação e correções para o Combo Washer Dryer, alternância de modos, timed actions nativas do combo e suporte a ícones de falta de água (Water Off) para lavadoras comuns e combos.
- **14/06/2026**: [Arquitetura Micro-Kernel e Sistema de Culinária](walkthrough/gerenciador_dispositivos.md) - Refatoração para centralização de patches no Kernel `LKS_ApplianceManager.lua`, migração do driver de lavanderia e novo driver de culinária para fogões e micro-ondas com avisos de segurança e texturas exclusivas sem energia.
- **14/06/2026**: [Consolidação das Ferramentas de Auditoria](walkthrough/auditoria_unificada.md) - Migração de auditoria de assets órfãos para `auditoria_mod.py`, delegação por subprocesso em `LKS_Tools.py`, paleta de cores ANSI para logs e alinhamento de tabela dinâmico.
- **14/06/2026**: [Correção de Auditoria e Ajustes do Banner](walkthrough/correcao_auditoria.md) - Resolução de falsos positivos na auditoria, correção e substituição automática de links locais e alinhamento visual simétrico do menu interativo.
- **14/06/2026**: [Padronização do Driver de Refrigeração](walkthrough/padronizacao_refrigeracao.md) - Refatoração do Fridges Off para driver LKS_Device_Refrigeration, expansão do kernel Appliance Manager e suporte a saves legados.
- **14/06/2026**: [Desacoplamento Nativo do Generator Powered Buildings](walkthrough/desacoplamento_generator_powered_buildings.md) - Remoção da dependência obrigatória do GeneratorPlus2, vendorização dos módulos como LKS_EletricidadeConstrucao, incompatibilidade explícita com os IDs originais e modularização por Sandbox Options.
- **15/06/2026**: [Readequação de Badges e Ajuste de Auditoria](walkthrough/readequacao_assets_auditoria.md) - Refinamento na renderização de badges nos aparelhos com validação de container válido e correção da ferramenta de auditoria para ignorar texturas nativas do jogo.

