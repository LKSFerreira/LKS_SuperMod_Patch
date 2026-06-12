---
name: variaveis_ambiente
description: Orienta criação e manutenção de variáveis de ambiente, secrets e arquivos `.env.example`.
---

# Propósito

Use esta skill quando a tarefa envolver configuração, secrets, `.env`, `.env.example` ou credenciais.

# Regras

- Nunca exponha secrets reais em arquivos versionados.
- Versione apenas exemplos seguros em `.env.example`.
- Documente nome, finalidade e formato esperado das variáveis.
- Prefira falhar cedo com mensagem clara quando uma variável obrigatória faltar.
- Separe variáveis de cliente e servidor quando a stack tiver frontend.

# Validação

- Busque por chaves hardcoded antes de finalizar.
- Confirme que `.env` está ignorado pelo Git.
- Rode o fluxo de inicialização ou build quando possível.
