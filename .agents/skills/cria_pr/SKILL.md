---
name: cria_pr
description: Gera o texto descritivo e estético de Pull Requests baseando-se estritamente no template obrigatório, com foco impecável em formatação.
---

# 🎯 Propósito

Use esta skill SEMPRE que for solicitado a criar, formatar ou rascunhar um texto de Pull Request (PR). A estética e o rigor técnico para o usuário são críticos. Nunca crie PRs genéricos sem usar esta estrutura.

# 📋 Pré-requisitos

- Verifique os commits incluídos nas alterações ou leia o log de diff mais recente para entender o escopo do que foi desenvolvido.
- Formule todas as métricas, os impactos técnicos arquiteturais e como os testes devem ser rodados.

# 🛠️ Instruções de Execução (Workflow)

1. **Reunir Contexto:** Identifique qual das frentes do projeto (.docker, backend/python, app/node) foi afetada e liste as mudanças por categorias.
2. **Carregar o Molde:** Utilize **exatamente** o template localizado em `resources/pr_template.md`.
3. **Preenchimento:** Substitua os espaços entre colchetes `[ ]` pelo conteúdo técnico apropriado, prestando MUITA ATENÇÃO às Regras de Formatação abaixo.
4. **Entrega:** Imprima a saída final em um Code Block Markdown (` ```markdown `).

# 🚨 Regras Críticas de Formatação de Links (Guardrails) 🚨

Essas regras não admitem falhas. A quebra delas invalida o PR:

1. **PROIBIDO CAMINHOS ABSOLUTOS:** NUNCA use o protocolo `cci:`, `file:///` ou caminhos absolutos do Windows (ex: `c:/Users/...`).
2. **PROIBIDO LINKS DUPLOS/SMART LINKS:** Nunca envolva links já formatados com colchetes extras (ex: `[[arquivo](link)]`).
3. **OBRIGATÓRIO:** Ao citar arquivos na seção de "Alterações Realizadas", use EXATAMENTE e APENAS o formato Markdown padrão relativo.
   - ✅ Correto: `[app/controllers/api_controller.py](app/controllers/api_controller.py)`
   - ✅ Correto: `[tests/test_main.py](tests/test_main.py)`
   - ❌ Incorreto: `[[app/main.py](cci:7://...)]`
   - ❌ Incorreto: `[arquivo](file:///c:/Users/...)`

Nenhum link ou referência deve ter algo como `(cci:7://file:///c:/)`.

# 🎨 Regras de Estilo

- **Idiomas:** Sempre em `pt-BR`.
- **Estética:** Mantenha fielmente os emojis do template, os hífens organizados e os títulos principais das áreas de mudanças.
- Tente categorizar logicamente: Agrupe refatorações em _Melhorias de Arquitetura_ e correções urgentes em outra categoria com o devido emoji de escudo.
