---
name: NomeDaSkillAvancada
description: Descrição da skill complexa que utiliza scripts ou templates para execução de tarefas.
---

# 🎯 Propósito

Explique o objetivo de alto nível dessa operação complexa.

# 📁 Estrutura da Skill

Sempre que usar esta skill, tenha em mente a estrutura das pastas:

- `scripts/`: Scripts utilitários que devem ser executados.
- `examples/`: Exemplos de código ou payloads JSON.
- `resources/`: Templates estáticos (HTML, Markdown, Config, etc).

# 🛠️ Instruções de Execução (Workflow)

Siga estritamente este fluxo operacional:

1. **Configuração e Setup:**
   - Antes de iniciar, execute o script localizado em `scripts/setup_ambiente.sh`.
   - Se houver falhas na execução, aborte a operação e notifique o usuário.

2. **Processamento:**
   - Leia o arquivo de exemplo armazenado em `examples/arquitetura_base.json` para entender o formato esperado.
   - Aplique as mudanças solicitadas pelo usuário seguindo o padrão do exemplo.

3. **Geração e Finalização:**
   - Para criar o documento final, utilize o conteúdo de base encontrado em `resources/template.md`.
   - Preencha o template e salve o resultado na pasta principal do projeto.

# 💡 Tratamento e Diagnóstico de Erros

- Se o passo 1 falhar com _Permission Denied_, tente rodar `chmod +x` no script de setup.
- Se a dependência X não for encontrada, gere uma mensagem de erro orientando o usuário.
