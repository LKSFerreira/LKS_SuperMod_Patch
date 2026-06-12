---
name: diagnosticos
description: Investiga erros de build, lint, runtime e configuração antes de propor correções.
---

# Propósito

Use esta skill quando houver falha, comportamento inesperado, erro de ambiente ou regressão.

# Workflow

1. Reproduza ou leia o erro real.
2. Colete contexto mínimo: comando, stack trace, arquivos afetados e mudanças recentes.
3. Identifique causa provável antes de editar.
4. Corrija o menor ponto responsável pelo erro.
5. Rode novamente a validação que falhou.

# Restrições

- Não esconda erro removendo validação.
- Não faça rollback amplo sem pedido explícito.
- Informe quando o erro depender de serviço externo ou credencial ausente.
