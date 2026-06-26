---
trigger: always_on
---

# Fluxo de Trabalho - Projeto

## Princípios

- Diagnostique antes de alterar.
- Planeje mudanças substanciais antes da execução.
- Implemente apenas o escopo solicitado.
- Valide com testes, build, lint ou auditoria estática quando aplicável.
- Preserve mudanças existentes que possam ter sido feitas pelo usuário.
- Não simule execução: se precisar validar, execute o comando real ou declare que não foi possível.

## Etapas

1. **Descoberta:** leia regras, metadocs e arquivos afetados.
2. **Plano:** defina a abordagem, riscos e validação.
3. **Execução:** aplique mudanças pequenas e coesas.
4. **Verificação:** rode checks compatíveis com a stack.
5. **Entrega:** resuma alterações, validação e pendências.

## Bloqueios

Pare para alinhamento quando a tarefa exigir decisão de produto, credenciais, serviços externos indisponíveis ou ação destrutiva não solicitada.
