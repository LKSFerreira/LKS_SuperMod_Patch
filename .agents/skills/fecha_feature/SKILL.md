---
name: fecha_feature
description: Finaliza uma feature documentalmente, promovendo o artefato de 'feat' para 'walkthrough' e sincronizando histórico e referências.
---

# 🎯 Propósito

Use esta skill SEMPRE que o usuário sinalizar que terminou o trabalho de uma feature (ou chamar o gatilho explícito `/feat_completa`). Ela orquestra a alteração de documentos, garantindo que propostas mudem para histórico conclusivo.

# 📋 Pré-requisitos

- Confirme se existe um arquivo de plano na pasta `/.metadocs/feat/<tema_da_feature>.md`.
- Confirme que a feature foi validada em código e não possui pontas soltas.

# 🛠️ Instruções de Execução (Workflow)

Escolha o fluxo correto baseado na origem da tarefa:

## Fluxo A: Promoção de Feature Planejada (Com arquivo em `feat/`)
1. **Sincronização**: Abra o documento em `/.metadocs/feat/`, mude o tempo verbal para o passado e adicione os detalhes reais da implementação e validação.
2. **Promoção**: Mova o arquivo para `/.metadocs/walkthrough/<nome_curto>.md`.
3. **Histórico**: Atualize `historico.md` com o link relativo e marque como concluído no `roadmap.md`.

## Fluxo B: Documentação Ad-hoc (Sem planejamento prévio)
1. **Criação**: Crie um novo arquivo diretamente em `/.metadocs/walkthrough/<nome_curto>.md`.
2. **Conteúdo**: Descreva o que foi feito, o contexto da demanda espontânea e como validar.
3. **Histórico**: Adicione a entrada cronológica no `/.metadocs/historico.md` apontando para este novo arquivo.

# ⚠️ Regras e Restrições (Guardrails)

- **Fluxo A vs B**: Se o usuário usar `/fecha_feature`, priorize o Fluxo A. Se usar `/walkthrough` e não houver plano, use o Fluxo B.
- **PROIBIDO:** Deixar o arquivo como "cópia" nas duas pastas.
- **Nomenclatura:** Nomes de `walkthrough` não podem ter mais de 3 palavras em `snake_case`.
- **Links Absolutos:** Proibido o uso de `file:///` no `historico.md`.
