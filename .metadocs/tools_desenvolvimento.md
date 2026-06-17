# Ferramentas de Desenvolvimento — LKS SuperMod Patch

Catálogo completo das ferramentas Python em `tools/`. Todas utilizam `PZ_GAME_DIR` do `.env` quando necessário.

## Pré-requisito global

```
PZ_GAME_DIR=C:\caminho\para\ProjectZomboid
```

Definido no `.env` na raiz do projeto. Cada dev ajusta para sua instalação local.

---

## 1. `gerar_luarc.py` — Configuração do lua-language-server

**Propósito:** Gera automaticamente `.luarc.json` e `.types/LKS_PZ_Types.lua` para eliminar warnings falso-positivos no VS Code. Escaneia os arquivos Lua do jogo e do mod para calcular quais globals e tipos Java precisam ser declarados.

**Quando usar:**
- Após instalar/atualizar o Project Zomboid (nova Build)
- Ao usar um novo global do engine Java (`get*`, `Iso*`, `IS*`, etc.)
- Ao adicionar annotations `@param`/`@type` com tipos Java novos
- Ao configurar o projeto em uma nova máquina

```bash
python tools/gerar_luarc.py          # Gera tudo
python tools/gerar_luarc.py --help   # Exibe ajuda detalhada
```

**Gera:**
- `.luarc.json` — configuração completa do LuaLS (library paths, globals, runtime)
- `.types/LKS_PZ_Types.lua` — stubs EmmyLua de classes Java do PZ

---

## 2. `auditoria_mod.py` — Auditoria estrutural do mod

**Propósito:** CLI unificada para validação de integridade do código. Verifica blocos Lua (if/end, function/end), compara chaves de tradução e detecta caminhos absolutos locais vazados no repositório.

**Quando usar:**
- Antes de commits com código Lua novo
- Ao adicionar/remover chaves de tradução
- Para verificar se caminhos locais vazaram no repo

```bash
python tools/auditoria_mod.py validar-sintaxe [<caminho>]
python tools/auditoria_mod.py auditar-traducoes [--idioma <idioma>] [--ignorar-nativas]
python tools/auditoria_mod.py auditar-caminhos
```

---

## 3. `LKS_Tools.py` — Gerenciador de Assets e Sprites

**Propósito:** Ferramenta de gerenciamento de texturas PNG. Extrai sprites dos `.pack` do jogo, inspeciona metadados de imagem, converte 16-bit para 8-bit e audita imagens órfãs.

**Quando usar:**
- Ao precisar extrair um sprite do jogo para override
- Para verificar se uma PNG está em formato compatível (8-bit)
- Para encontrar imagens no `media/ui/` que nenhum script Lua referencia

```bash
python tools/LKS_Tools.py              # Menu interativo
python tools/LKS_Tools.py -e <sprite>  # Extrair sprite do jogo
python tools/LKS_Tools.py -b <termo>   # Buscar referências de assets
python tools/LKS_Tools.py -i <png>     # Inspecionar imagem
python tools/LKS_Tools.py -c <png>     # Converter para 8-bit
python tools/LKS_Tools.py -a           # Auditar imagens órfãs
```

---

## 4. `sanitiza_log.py` — Higienizador de logs do jogo

**Propósito:** Filtra o `console.txt` do PZ removendo ruídos de outros mods para isolar logs, mensagens de debug e erros do LKS SuperMod Patch. Gera `console_sanitizado.txt` e `console_erros.txt`.

**Quando usar:**
- Ao depurar erros in-game do mod
- Para isolar stack traces específicos do LKS

```bash
python tools/sanitiza_log.py                          # Detecta console.txt automaticamente
python tools/sanitiza_log.py <console.txt> [<saida>]  # Informando caminho manual
```

---

## 5. `atualizar_dicionario_tilesets.py` — Extrator de metadados de tilesets

**Propósito:** Varre `newtiledefinitions.tiles.txt` do PZ para extrair metadados de eletrodomésticos (contêineres, texturas, propriedades) e compila em `tools/dicionario_tilesets.json`. Esse dicionário é consumido por `LKS_Tools.py` para sugestões dinâmicas.

**Quando usar:**
- Após atualização do PZ que altera tiles/appliances
- Ao precisar mapear novos eletrodomésticos para absorção

```bash
python tools/atualizar_dicionario_tilesets.py
```

---

## 6. `configurar_terminal.py` — Configurador de atalhos do IDE

**Propósito:** Aplica configurações de teclado no Antigravity IDE (fork VS Code) para que Shift+Enter funcione como quebra de linha no terminal integrado. Também configura MinTTY se necessário.

**Quando usar:**
- Após formatação de PC ou reinstalação do IDE
- Quando Shift+Enter não funciona no terminal

```bash
python tools/configurar_terminal.py
```

---

## Resumo rápido

| Ferramenta | Comando curto | Frequência de uso |
|---|---|---|
| `gerar_luarc.py` | `python tools/gerar_luarc.py` | A cada update do PZ ou setup novo |
| `auditoria_mod.py` | `python tools/auditoria_mod.py validar-sintaxe` | Antes de cada commit Lua |
| `LKS_Tools.py` | `python tools/LKS_Tools.py` | Ao trabalhar com assets |
| `sanitiza_log.py` | `python tools/sanitiza_log.py` | Ao depurar erros |
| `atualizar_dicionario_tilesets.py` | `python tools/atualizar_dicionario_tilesets.py` | Raro (update do PZ) |
| `configurar_terminal.py` | `python tools/configurar_terminal.py` | Uma vez por máquina |
