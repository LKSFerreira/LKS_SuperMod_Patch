---
name: sincroniza_contexto
description: Sincronização de contexto, auditoria e escuta de demandas. Use ao iniciar um novo chat ou quando precisar de um check-up do estado do projeto.
---

# Propósito

Atue como Tech Lead. Antes de retomar trabalho profundo, alinhe a documentação com o estado real do repositório.

# Workflow

## 1. Leitura obrigatória

Leia:

1. `AGENTS.md`
2. `.agents/rules/workflow.md`
3. `.agents/rules/code.md`
4. `.metadocs/roadmap.md`, se existir
5. `.metadocs/historico.md`, se existir
6. `README.md`
7. Manifestos da stack, como `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml` ou equivalentes

## 2. Auditoria

- Compare o roadmap com arquivos reais.
- Identifique tarefas concluídas, pendências e documentação desatualizada.
- Aponte arquivos ou regras referenciados que não existem.
- Verifique se há sinais de stack divergente da tag `LINGUAGEM_PROJETO`.

## 3. Relatório

Responda com:

- **Status do roadmap:** última entrega e próxima etapa.
- **Consistência:** OK ou inconsistências encontradas.
- **Problemas:** lista objetiva dos pontos que impedem avanço seguro.

# Restrições

- Não implemente mudanças durante a sincronização, a menos que o usuário peça explicitamente um hotfix.
- Não invente progresso que não esteja refletido em arquivos.
