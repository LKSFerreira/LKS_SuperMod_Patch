---
name: revisao_codigo
description: Revisa alterações de código com foco em bugs, regressões, segurança, arquitetura e lacunas de teste.
---

# Propósito

Use esta skill quando o usuário pedir revisão, auditoria de diff, análise de PR ou avaliação de risco técnico.

# Workflow

1. Leia `git status`, `git diff --stat` e os diffs relevantes.
2. Entenda o comportamento esperado pelos docs e testes existentes.
3. Priorize achados por severidade.
4. Aponte arquivo e linha quando possível.
5. Diferencie bug real, risco, sugestão e pergunta aberta.

# Saída esperada

- Findings primeiro, ordenados por severidade.
- Perguntas ou pressupostos depois dos findings.
- Resumo curto apenas no fim.
- Se não houver problemas, diga isso claramente e informe lacunas de validação.

# Restrições

- Não reescreva código durante uma revisão, a menos que o usuário peça correção.
- Não trate preferência estética como bug.
