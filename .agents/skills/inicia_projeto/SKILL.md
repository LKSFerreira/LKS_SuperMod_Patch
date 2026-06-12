---
name: inicia_projeto
description: Gera o contexto inicial de um projeto ou estudo recém-criado.
---

# Propósito

Padronizar um repositório novo ou recém-criado com regras, metadocs e README coerentes com a stack detectada.

# Workflow

## 1. Identificar stack

Prioridade:

1. `package.json` -> JavaScript/TypeScript
2. `pyproject.toml` ou `requirements.txt` -> Python
3. `go.mod` -> Go
4. `Cargo.toml` -> Rust
5. `composer.json` -> PHP
6. `pom.xml` ou `build.gradle` -> Java
7. Extensões predominantes em `src/`

## 2. Criar estrutura mínima

Se não existirem, crie:

- `AGENTS.md`
- `.agents/rules/workflow.md`
- `.metadocs/roadmap.md`
- `.metadocs/historico.md`
- `.metadocs/feat/`
- `.metadocs/walkthrough/`
- `README.md`

Use os templates em `resources/` quando disponíveis.

## 3. Configurar linguagem

- Substitua `> LINGUAGEM_PROJETO: <linguagem>` pela stack detectada.
- Garanta que exista `.agents/rules/<linguagem>.md` quando a linguagem fizer parte do template.
- Se a linguagem não tiver regra dedicada, registre isso como pendência em `.metadocs/roadmap.md`.

## 4. Finalizar

Informe:

- linguagem detectada;
- arquivos criados ou preservados;
- próximos passos recomendados;
- se o projeto parece pronto para Docker ou precisa de configuração manual.

# Restrições

- Não sobrescreva documentação existente sem comparar conteúdo.
- Não instale dependências durante a inicialização documental.
