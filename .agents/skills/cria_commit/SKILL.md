---
name: cria_commit
description: Aplica rigorosamente os padrões de versionamento para criar commits atômicos e segmentados, com mensagem padronizada por emoji e tipo. Use sempre que o usuário pedir para criar commit, sugerir mensagem de versionamento, analisar `git diff` para commitar, ou executar `git add`/`git commit`.
---

# Propósito

Use esta skill sempre que for solicitado a criar um commit, descrever mudanças para versionamento ou executar `git commit`. Esta skill garante dois invariantes:

1. cada commit representa um único grupo lógico de alteração;
2. a mensagem segue o padrão imutável do projeto.

Vários arquivos podem e devem ficar no mesmo commit quando fizerem parte do mesmo objetivo técnico, funcional ou documental.

# Pré-requisitos

1. **Aprovação do Usuário:** Exigir pedido explícito ou aprovação clara antes de executar qualquer commit.
2. **Análise de Alterações:** Ler `git status`, `git diff --stat`, `git diff` e, quando necessário, `git diff --cached` para mapear exatamente o que mudou.
3. **Definição de Tipo e Emoji:** Consultar a Tabela de Tipos (abaixo) para classificar o commit; usar estritamente o modelo em `resources/commit_template.md`.
4. **Stage e Execução:**
   - Executar `git add` somente no grupo lógico atual.
   - Nunca usar `git add .`, `git add -A`, `git commit -a` ou equivalentes amplos sem recorte explícito.
   - Rodar `git commit -m "SUA MENSAGEM"` após validação do índice.

# Instruções de Execução

## Workflow Obrigatório

1. **Mapear os grupos lógicos de alteração**
   - Separar as mudanças por objetivo, escopo e impacto.
   - Tratar como grupos distintos exemplos como:
     - documentação e código;
     - refactor e correção de bug;
     - infraestrutura e feature;
     - arquivos independentes sem a mesma intenção de negócio.

2. **Decidir se cabe um único commit ou vários**
   - Permitir um único commit somente quando todas as mudanças pertencem claramente ao mesmo objetivo funcional, técnico ou documental.
   - Não separar artificialmente arquivos que fazem parte do mesmo fluxo só porque são muitos.
   - Se houver mais de um grupo lógico, interromper a execução automática de um commit único, apresentar a segmentação proposta e seguir criando um commit por grupo.
   - Se o usuário pedir "faça o commit" no singular, isso não autoriza juntar mudanças heterogêneas em um commit só.

3. **Definir tipo e emoji por grupo**
   - Classificar cada grupo individualmente usando a Tabela de Tipos oficial.
   - Nunca usar um tipo genérico para esconder mistura de escopos.

4. **Construir a mensagem**
   - Usar estritamente o modelo localizado em `resources/commit_template.md`.
   - Nenhuma outra variação é permitida.

5. **Stagear somente o grupo atual**
   - Executar `git add -- <arquivos do grupo>` somente para os arquivos pertinentes.
   - Validar o stage com `git diff --cached --stat` e, se necessário, `git diff --cached`.
   - Se o stage contiver arquivos fora do grupo, corrigir antes do commit.

6. **Executar o commit**
   - Rodar `git commit -m "SUA MENSAGEM"` somente após confirmar que o índice contém um único grupo lógico.
   - Repetir o processo para o próximo grupo até esgotar as mudanças que o usuário deseja versionar.

## Checklist de Atomicidade

Antes de cada commit, validar:

- existe um único objetivo claro neste stage;
- a mensagem descreve o stage sem juntar assuntos independentes;
- os arquivos staged pertencem ao mesmo fluxo;
- o commit pode ser revertido isoladamente sem desmontar trabalho não relacionado.

Se qualquer item falhar, o commit deve ser segmentado.

## Regra de Bloqueio

Parar e alinhar com o usuário antes de commitar quando ocorrer qualquer cenário abaixo:

- há múltiplos grupos lógicos e a divisão não está óbvia;
- o usuário pediu uma mensagem, mas não definiu se quer commitar um subconjunto ou tudo;
- existe mistura de arquivos staged e unstaged que altera o significado do commit;
- o repositório contém mudanças de autoria possivelmente diferente e o agrupamento é ambíguo.

### Tabela de Tipos Oficial

Só é permitido usar as combinações exatas de código emoji e tipo abaixo:

- `:tada:` -> `init`
- `:books:` -> `docs`
- `:bug:` -> `fix`
- `:sparkles:` -> `feat`
- `:bricks:` -> `ci`
- `:recycle:` -> `refactor`
- `:zap:` -> `perf`
- `:boom:` -> `breaking`
- `:lipstick:` -> `feat`
- `:test_tube:` -> `test`
- `:bulb:` -> `docs`
- `:card_file_box:` -> `data`
- `:broom:` -> `cleanup`
- `:wastebasket:` -> `remove`

# Regras e Restrições

- **Idioma:** Sempre em `pt-BR`.
- **Atomicidade:** Um commit deve representar uma única intenção rastreável.
- **Segmentação obrigatória:** É proibido commitar tudo em bloco quando houver mais de um assunto.
- **Agrupamento permitido:** É correto agrupar vários arquivos em um mesmo commit quando todos sustentam a mesma intenção.
- **Stage mínimo:** É proibido usar stage amplo ou automático sem recorte explícito por grupo.
- **Formatação de referências:** Nomes de arquivos, funções, rotas ou variáveis na descrição devem obrigatoriamente estar entre crases.
- **Emoji em texto:** Usar a string textual do emoji, como `:bug:` e não o emoji Unicode.
- **Mensagem honesta:** A descrição não pode esconder múltiplas mudanças sob rótulos vagos como "ajustes gerais", "organiza arquivos" ou "atualizações diversas".

## Exemplo de Conduta Esperada

Se o repositório tiver:

- alterações em `PRD.md` e `README.md`;
- criação de `.agents/skills/cria_commit/SKILL.md`;
- ajuste em `src/server/bootstrap.ts`;

o agente não deve criar um commit único. Deve, no mínimo, propor a separação entre:

- `docs` para documentação;
- `feat`, `fix` ou `refactor` para código;
- outro commit para regras e automação do agente, se isso não fizer parte do mesmo objetivo documental.
