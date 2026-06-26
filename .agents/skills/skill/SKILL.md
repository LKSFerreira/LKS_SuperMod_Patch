---
name: skill
alias: autoria_skill
description: Cria ou melhora skills reutilizáveis em `.agents/skills/` com escopo claro e instruções acionáveis.
tags: [skill, automação, template, meta, criação, agente, scaffold]
triggers: ["cria uma skill", "nova skill", "melhora a skill", "skill", "salva esse procedimento"]
---

# Propósito

Use esta skill quando o usuário pedir para criar uma skill nova, salvar um procedimento reutilizável, melhorar instruções existentes ou publicar no ecossistema.

# Instruções de Execução

## 1. Levantar requisitos

Pergunte ao usuário:

- Qual tarefa/domínio a skill cobre?
- Quais casos de uso específicos ela deve tratar?
- Precisa de scripts executáveis ou só instruções?
- Existe material de referência para incluir?

## 2. Criar a estrutura

Crie o diretório em `.agents/skills/<nome_ingles>/` com:

```
skills/<nome>/
├── SKILL.md           ← Obrigatório
├── resources/         ← Templates estáticos (se necessário)
├── scripts/           ← Scripts utilitários (se necessário)
└── examples/          ← Exemplos de uso (se necessário)
```

Use os templates de referência em `.agents/templates/skills/`:
- `_template_simples/` → para skills instrucionais
- `_template_avancado/` → para skills com scripts, resources e exemplos

## 3. Escrever o SKILL.md

O frontmatter é obrigatório e deve seguir o formato:

```yaml
---
name: nome_ingles, nome_portugues
description: Frase clara sobre o que faz e quando o agente deve usar.
tags: [palavra-chave-1, palavra-chave-2, palavra-chave-3]
triggers: ["frase que o usuário diria", "outra frase", "comando"]
---
```

### Regras do frontmatter:

- **`name`**: inglês primeiro, português depois. O nome inglês deve ser o mesmo do diretório.
- **`description`**: incluir gatilhos de uso — o agente decide se carrega a skill com base nessa linha.
- **`tags`**: 3 a 8 palavras-chave para discovery semântica.
- **`triggers`**: frases naturais que o usuário diria para acionar.

### Estrutura do conteúdo:

```markdown
# Propósito
(O que faz e quando usar)

# Pré-requisitos
(O que precisa estar pronto antes)

# Instruções de Execução
(Passos concretos e acionáveis)

# Regras e Restrições
(Guardrails que não podem ser quebrados)
```

## 4. Revisar com o usuário

Apresente o rascunho e pergunte:

- Cobre seus casos de uso?
- Falta algo ou algo está confuso?
- Alguma seção precisa de mais ou menos detalhe?

## 5. Finalizar

- Verifique que o `SKILL.md` não excede 500 linhas. Se exceder, mova conteúdo de referência para `resources/`.
- Atualize a tabela de skills nos adapters (`CLAUDE.md`, `GEMINI.md`, `copilot-instructions.md`, `AGENTS.md`) se os adapters existirem no projeto.

# Boas Práticas

- O `description` deve indicar claramente **quando** a skill é acionada — o agente decide baseado nessa linha.
- A skill deve ensinar um **procedimento acionável**, não apenas registrar notas soltas.
- Recursos, scripts e templates ficam **dentro da pasta da skill**.
- Evite dependência de plataforma específica, salvo se essa for a finalidade da skill.
- Para operações determinísticas (validação, formatação), prefira scripts utilitários em vez de instruções em texto — reduz overhead de tokens.
- Escreva o conteúdo em **pt-BR**, nomes de diretório e campos do frontmatter em **inglês**.

# Regras e Restrições

- **Nome do diretório**: inglês, lowercase, sem espaços (use `-` se necessário).
- **SKILL.md**: sempre na raiz do diretório da skill, nunca em subdiretório.
- **Não criar skill vazia**: toda skill precisa no mínimo de Propósito + Instruções.
- **Idioma do conteúdo**: pt-BR. Frontmatter em inglês.
