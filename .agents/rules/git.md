---
trigger: model_decision
description: Regras de versionamento, commits e PRs.
---

# Regras Git

- Commit, push e PR exigem solicitação explícita do usuário.
- Commits devem ser atômicos e representar um único objetivo lógico.
- Não use `git add .`, `git add -A` ou `git commit -a` quando houver mudanças heterogêneas.
- Mensagens de commit devem seguir a skill `.agents/skills/commit/`.
- Textos de PR devem seguir a skill `.agents/skills/pr/`.
- Nunca reverta mudanças que possam ter sido feitas pelo usuário sem aprovação clara.
