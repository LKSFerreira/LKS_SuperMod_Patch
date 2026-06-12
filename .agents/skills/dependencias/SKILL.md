---
name: dependencias
description: Gerencia dependências, runtimes e pacotes respeitando a stack e o ambiente do projeto.
---

# Propósito

Use esta skill ao instalar, remover, atualizar ou diagnosticar dependências.

# Workflow

1. Identifique o gerenciador pelo lockfile ou manifesto.
2. Use o gerenciador oficial da stack:
   - Node: `npm`, `pnpm` ou `yarn` conforme lockfile.
   - Python: `uv` quando configurado; caso contrário, siga o manifesto existente.
   - Java: Maven ou Gradle conforme projeto.
   - Go: `go mod`.
   - Rust: `cargo`.
3. Em projetos com Docker, instale dentro do container quando essa for a regra local.
4. Atualize lockfiles junto com manifestos.
5. Rode validação mínima após mudanças.

# Restrições

- Não instale pacotes no host quando o projeto exigir container.
- Não altere versões amplamente sem justificar impacto.
- Não edite lockfile manualmente.
