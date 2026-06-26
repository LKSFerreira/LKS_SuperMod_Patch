# Copilot Instructions — LKS SuperMod Patch

## Contexto do Projeto

Mod para **Project Zomboid Build 42** (id: `LKSSuperModPatch`). Incorpora nativamente mecânicas de mods menores (Generator Powered Buildings, Fridges Off!) em uma base modular própria com tradução PT-BR.

**Linguagens:** Lua (código do mod) + Python (ferramentas CLI de desenvolvimento).

## Arquitetura

### Estrutura do Mod (PZ)

```
common/media/
├── lua/
│   ├── shared/       → Lógica compartilhada (client+server), namespace, config, constantes
│   │   ├── core/     → Kernel: namespace, logger, event manager, state manager, runtime context
│   │   ├── data/     → Estruturas de dados (state, generator, consumer, building)
│   │   ├── utils/    → Utilitários puros (math, geometry, validation, table)
│   │   └── actions/  → Timed actions do jogador
│   ├── client/       → Lógica de UI, context menus, device drivers
│   │   └── devices/  → Drivers de aparelhos: Refrigeration, Laundry, Cooking
│   └── server/       → Lógica server-side, comandos, power/fuel/heating/building
│       ├── power/    → Manager e distributor de energia
│       ├── fuel/     → Barris, strain, chunk tracker
│       ├── heating/  → Sistema de aquecimento
│       └── building/ → Scanner, consumer scanner, border detector
└── ui/               → Assets PNG de ícones (texture override do jogo)
```

### Padrão Micro-Kernel (ApplianceManager)

O arquivo `LKS_ApplianceManager.lua` é o **kernel** centralizador. Cada tipo de aparelho é um **driver** independente registrado no kernel:

- `LKS_Device_Refrigeration.lua` — geladeiras e freezers
- `LKS_Device_Laundry.lua` — lavadoras, secadoras, combos
- `LKS_Device_Cooking.lua` — fogões e micro-ondas

O kernel faz monkey patch unificado da Loot Window e roteia cliques do mundo para o driver correto.

### Ferramentas Python (`tools/`)

| Comando | Propósito |
|---------|-----------|
| `python tools/auditoria_mod.py validar-sintaxe` | Valida blocos Lua (if/end, function/end) |
| `python tools/auditoria_mod.py auditar-traducoes --ignorar-nativas` | Compara chaves Lua ↔ arquivos .properties |
| `python tools/auditoria_mod.py auditar-caminhos` | Detecta caminhos absolutos locais no repo |
| `python tools/LKS_Tools.py` | Menu interativo de gerenciamento de assets |
| `python tools/LKS_Tools.py -a` | Auditoria de imagens órfãs |
| `python tools/LKS_Tools.py -b <termo>` | Busca referências de sprites no jogo |

Scripts em `scratch/` são experimentais e descartáveis.

## Convenções de Código

### Lua

- **Idioma pt-BR** em variáveis e funções de autoria própria (exceto APIs nativas do PZ).
- **Escopo local** obrigatório para tudo que não for global intencional.
- **EmmyLua annotations** em todas as funções: `---@param`, `---@return` com descrição em pt-BR.
- Nomes longos e descritivos — proibido `p`, `u`, `evt`, `sq`. Use `jogadorObjeto`, `quadradoAlvo`.
- Guard clauses em vez de aninhamento profundo.
- Prefixo `LKS_` no namespace de módulos (ex: `LKS_EletricidadeConstrucao`, `LKS_ApplianceManager`).
- Nomenclatura de arquivos: `LKS_<Modulo>_<Subdominio>.lua`.

### Python

- Gerenciador de pacotes: **`uv`** exclusivamente. Nunca `pip`, `poetry` ou `virtualenv`.
- Tipagem moderna (Python 3.10+): `list`, `dict`, `str | None`.
- Docstrings em formato **RST (Sphinx)** com exemplos em `.. code-block:: python`.
- Linting/formatação: **Ruff**.

### Geral

- Encoding: **UTF-8** sempre. Acentuação pt-BR preservada em todo lugar.
- Sem código morto ou comentado. Comentários só para justificar decisões complexas ("por quê").
- Sem abreviações em nenhuma linguagem.

## Ambiente

- `PZ_GAME_DIR` definido em `.env` na raiz aponta para a instalação do Project Zomboid.
- O dicionário `tools/data/dicionario_tilesets.json` mapeia sprites e tilesets do jogo.
- Arquivo `42.15/mod.info` define metadata do mod (versão, incompatibilidades).

## Tradução PT-BR

O mod segue um padrão rigoroso de localização (documentado em `.metadocs/padrao_traducao_ptbr.md`):

- Sem abreviações com ponto (`Info.` → `Informações`).
- Termos adaptados ao contexto pós-apocalíptico (`Building` → `Construção`, `Pool` → `Rede`).
- Unidades reais (`Units` → `Litros`).
- Sem termos corporativos (`Consumers` → `Aparelhos Conectados`).

## Documentação Interna

- `.metadocs/` — Documentação de desenvolvimento, histórico de entregas, walkthroughs de features.
- `.agents/` — Regras, skills, workflows e templates para agentes AI.
- `mecanicas/` — Design docs de mecânicas planejadas.

## Git

- Commits atômicos, solicitados explicitamente pelo usuário.
- Nunca usar `git add .` com mudanças heterogêneas.
- Mensagens seguem padrão definido em `.agents/skills/commit/`.

## Skills disponíveis

Ao receber `/commit`, `/pr`, `/sync`, `/init`, `/diag`, `/find`, etc., leia o SKILL.md em `.agents/skills/<comando>/`.

Referência rápida: `/commit`, `/pr`, `/sync`, `/init`, `/tests`, `/review`, `/deps`, `/db`, `/env`, `/diag`, `/feat`, `/front`, `/skill`, `/find`, `/web`.
