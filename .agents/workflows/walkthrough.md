---
description: Salva o artefato de walkthrough e atualiza o histórico de documentação.
---

# Walkthrough / Fechamento de Tarefa

Este workflow utiliza a skill `fecha_feature` para documentar suas entregas.

## Como usar:

1. **Tarefas Planejadas**: Se você terminou algo que estava no `feat/`, este comando promoverá o arquivo para `walkthrough/`.
2. **Tarefas Ad-hoc**: Se você fez algo espontâneo, este comando criará um novo registro de documentação diretamente no histórico.

## Ação Obrigatória

**Delegue imediatamente** a execução para a skill `fecha_feature` (localizada em `.agents/skills/fecha_feature/`).

Leia o `SKILL.md` da skill e identifique se deve seguir o **Fluxo A (Promoção)** ou **Fluxo B (Criação Ad-hoc)**.
