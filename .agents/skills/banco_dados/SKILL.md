---
name: banco_dados
description: Planeja e valida mudanças de banco de dados, queries, migrações e seeds com foco em segurança e reversibilidade.
---

# Propósito

Use esta skill para modelagem, migrações, queries SQL, seeds, backups locais e diagnóstico de dados.

# Workflow

1. Identifique o banco e a ferramenta de migração.
2. Leia schema, migrations e modelos existentes.
3. Planeje mudanças reversíveis quando possível.
4. Separe alteração estrutural, seed e ajuste de aplicação.
5. Valide com testes ou comandos de migração disponíveis.

# Segurança

- Não rode comandos destrutivos em dados reais sem confirmação explícita.
- Prefira transações para alterações manuais.
- Em ambientes produtivos, use leitura primeiro e confirme impacto.
- Não exponha strings de conexão com credenciais.
