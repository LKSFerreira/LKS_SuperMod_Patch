---
name: testes
description: Planeja e executa validações automatizadas ou manuais adequadas à stack do projeto.
---

# Propósito

Use esta skill quando precisar criar, ajustar ou executar testes, builds, linters ou validações de comportamento.

# Workflow

1. Identifique a stack pelos manifestos.
2. Leia scripts disponíveis em `package.json`, `pyproject.toml`, `Makefile`, `pom.xml`, `go.mod` ou equivalentes.
3. Escolha a menor validação que cubra o risco da mudança.
4. Rode os comandos reais quando o ambiente permitir.
5. Registre falhas com comando, sintoma e provável causa.

# Estratégia

- Mudanças pequenas: teste focado ou auditoria estática.
- Mudanças compartilhadas: testes unitários e integração relevante.
- UI: validar fluxo principal e estados de erro.
- Infra: validar configuração e comando de subida quando possível.

# Restrições

- Não invente resultado de teste.
- Informe dependências ausentes, credenciais indisponíveis ou runtime faltante.
