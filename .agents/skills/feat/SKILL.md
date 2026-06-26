---
name: feat
alias: fecha_feature
description: Finaliza uma feature documentalmente, promovendo o artefato de 'implementation_plan' para 'implemented' e sincronizando histórico e referências.
tags: [feature, entrega, documentação, promoção, conclusão, release]
triggers: ["finaliza a feature", "feature pronta", "entrega", "fecha feature", "concluído"]
---

# 🎯 Propósito

Use esta skill SEMPRE que o usuário sinalizar que terminou o trabalho de uma feature (ou chamar o gatilho explícito `/feat`). Ela orquestra a alteração de documentos, garantindo que planos mudem para registros conclusivos.

# 📋 Pré-requisitos

- Confirme se existe um arquivo de plano na pasta `/.metadocs/implementation_plan/<tema>.md`.
- Confirme que a feature foi validada em código e não possui pontas soltas.

# 🛠️ Instruções de Execução (Workflow)

Escolha o fluxo correto baseado na origem da tarefa:

## Fluxo A: Promoção de Plano Existente (Com arquivo em `implementation_plan/`)
1. **Sincronização**: Abra o documento em `/.metadocs/implementation_plan/`, mude o tempo verbal para o passado e adicione os detalhes reais da implementação e validação.
2. **Promoção**: Mova o arquivo para `/.metadocs/implemented/<nome_curto>.md`.
3. **Histórico**: Atualize `/HISTORY.md` com o link relativo e marque como concluído no `/ROADMAP.md`.

## Fluxo B: Documentação Ad-hoc (Sem planejamento prévio)
1. **Criação**: Crie um novo arquivo diretamente em `/.metadocs/implemented/<nome_curto>.md`.
2. **Conteúdo**: Descreva o que foi feito, o contexto da demanda espontânea e como validar.
3. **Histórico**: Adicione a entrada cronológica no `/HISTORY.md` apontando para este novo arquivo.

# ⚠️ Regras e Restrições (Guardrails)

- **Fluxo A vs B**: Se houver plano existente, priorize o Fluxo A. Se não houver plano, use o Fluxo B.
- **PROIBIDO:** Deixar o arquivo como "cópia" nas duas pastas.
- **Nomenclatura:** Nomes de arquivos não podem ter mais de 3 palavras em `snake_case`.
- **Links Absolutos:** Proibido o uso de `file:///` no `HISTORY.md`.
