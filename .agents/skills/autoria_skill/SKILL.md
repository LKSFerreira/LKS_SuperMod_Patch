---
name: autoria_skill
description: Cria ou melhora skills reutilizáveis em `.agents/skills/` com escopo claro e instruções acionáveis.
---

# Propósito

Use esta skill quando o usuário pedir para criar uma skill, salvar um procedimento reutilizável ou melhorar instruções existentes.

# Estrutura mínima

Cada skill deve ter:

```markdown
---
name: nome_da_skill
description: O que faz e quando usar.
---

# Propósito

# Workflow

# Restrições
```

# Boas práticas

- O `description` deve indicar gatilho de uso.
- A skill deve ensinar um procedimento, não apenas registrar notas soltas.
- Recursos, scripts e templates ficam dentro da pasta da skill.
- Evite dependência de uma plataforma específica, salvo se essa for a finalidade da skill.
