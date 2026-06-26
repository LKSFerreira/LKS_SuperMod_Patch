---
name: find
alias: busca_skills
description: Descobre e instala skills do ecossistema aberto (skills.sh) quando o agente precisa de capacidades extras.
tags: [skills, marketplace, busca, instalação, extensão, ecossistema, npx]
triggers: ["busca uma skill", "instala skill", "tem skill para isso", "find skill", "skills.sh", "procura uma skill"]
---

# Propósito

Use esta skill quando o usuário pedir para buscar, descobrir ou instalar skills do ecossistema aberto. O marketplace em [skills.sh](https://skills.sh/) é compatível com todos os agentes: Copilot CLI, Codex, Gemini, Antigravity, Claude Code.

# Pré-requisitos

- Node.js instalado (para usar `npx`).
- Conexão com a internet.

# Instruções de Execução

## 1. Entender a necessidade

Identifique:
- O **domínio** (ex: React, testes, deploy, banco de dados)
- A **tarefa específica** (ex: escrever testes, criar animações, revisar PRs)
- Se é algo comum o suficiente para que uma skill provavelmente exista

## 2. Buscar skills

Execute a busca usando o CLI:

```bash
npx skills find [termo de busca]
```

Exemplos:
- Usuário pergunta "como otimizo meu React?" → `npx skills find react performance`
- Usuário pede "ajuda com PR reviews" → `npx skills find pr review`
- Usuário quer "gerar changelog" → `npx skills find changelog`

Para filtrar por autor confiável:
```bash
npx skills find [termo] --owner vercel-labs
```

## 3. Verificar qualidade antes de recomendar

Antes de recomendar uma skill, valide:

- **Instalações**: prefira skills com 1K+ instalações. Cautela com menos de 100.
- **Reputação da fonte**: fontes oficiais (`vercel-labs`, `anthropics`, `microsoft`) são mais confiáveis.
- **Stars no GitHub**: repositório com menos de 100 stars deve ser tratado com ceticismo.

## 4. Apresentar opções ao usuário

Ao encontrar skills relevantes, apresente:

- Nome e o que ela faz
- Quantidade de instalações e fonte
- Comando de instalação
- Link para mais detalhes

Exemplo de resposta:

```
Encontrei uma skill que pode ajudar! A "react-best-practices" oferece
guidelines de otimização React/Next.js da Vercel Engineering.
(185K instalações)

Para instalar:
npx skills add vercel-labs/agent-skills@react-best-practices

Mais detalhes: https://skills.sh/vercel-labs/agent-skills/react-best-practices
```

## 5. Instalar se o usuário aprovar

```bash
npx skills add <owner/repo@skill> -g -y
```

- `-g` instala globalmente (nível do usuário)
- `-y` pula confirmações

## 6. Verificar atualizações

```bash
npx skills check    # verifica atualizações
npx skills update   # atualiza todas
```

# Categorias comuns

| Categoria | Termos de busca |
|---|---|
| Desenvolvimento web | react, nextjs, typescript, css, tailwind |
| Testes | testing, jest, playwright, e2e |
| DevOps | deploy, docker, kubernetes, ci-cd |
| Documentação | docs, readme, changelog, api-docs |
| Qualidade de código | review, lint, refactor, best-practices |
| Design | ui, ux, design-system, accessibility |
| Produtividade | workflow, automation, git |

# Quando nenhuma skill for encontrada

Se nada for encontrado:
1. Informe que não encontrou skill existente.
2. Ofereça ajudar com a tarefa diretamente usando capacidades gerais.
3. Sugira criar uma skill própria usando a skill `/skill`.

# Regras e Restrições

- **NUNCA** instale uma skill sem aprovação explícita do usuário.
- **Sempre** verifique reputação e contagem de instalações antes de recomendar.
- **Prefira** skills de fontes oficiais quando houver alternativas equivalentes.
