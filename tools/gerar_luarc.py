# -*- coding: utf-8 -*-
"""
================================================================================
⚙️ GERADOR DE CONFIGURAÇÃO LuaLS — LKS SUPERMOD PATCH
================================================================================
Autor: LKS FERREIRA
Versão: 2.0 (Project Zomboid Build 42)
Data da Última Modificação: 17/06/2026

PROPÓSITO:
Gera automaticamente o arquivo ``.luarc.json`` e os stubs de tipos Java
(``.types/LKS_PZ_Types.lua``) para o lua-language-server, eliminando
warnings falso-positivos de globals indefinidos e tipos desconhecidos.

O script executa 5 etapas:
1. Lê ``PZ_GAME_DIR`` do ``.env`` na raiz do projeto.
2. Escaneia os Lua do jogo para catalogar definições existentes (IS*, Events, etc.).
3. Escaneia os Lua do mod para identificar globals referenciados.
4. Calcula o delta (globals do engine Java) e gera o ``.luarc.json``.
5. Extrai tipos Java referenciados em annotations EmmyLua e gera os stubs.

COMO USAR:
    python tools/gerar_luarc.py

PRÉ-REQUISITO:
    Variável ``PZ_GAME_DIR`` definida no ``.env``, apontando para a instalação
    do Project Zomboid (ex: ``PZ_GAME_DIR=C:\\Users\\...\\ProjectZomboid``).
================================================================================
"""

import json
import os
import re
import sys
from pathlib import Path

# Garante que o console do Windows aceite codificação UTF-8
if sys.version_info >= (3, 7):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

# Ativa suporte a cores ANSI no Windows
if os.name == "nt":
    os.system("")

# Cores do terminal
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RED = "\033[31m"
GRAY = "\033[90m"

# Caminhos do projeto (relativos ao script em tools/)
RAIZ_PROJETO = Path(__file__).resolve().parent.parent
CAMINHO_ENV = RAIZ_PROJETO / ".env"
CAMINHO_LUARC = RAIZ_PROJETO / ".luarc.json"
CAMINHO_LUA_MOD = RAIZ_PROJETO / "common" / "media" / "lua"
CAMINHO_TYPES = RAIZ_PROJETO / ".types"
CAMINHO_STUBS = CAMINHO_TYPES / "LKS_PZ_Types.lua"

# Globals nativos do Lua 5.1 que não precisam ser declarados
GLOBALS_LUA_PADRAO = frozenset({
    "assert", "collectgarbage", "dofile", "error", "getfenv", "getmetatable",
    "ipairs", "load", "loadfile", "loadstring", "module", "next", "pairs",
    "pcall", "print", "rawequal", "rawget", "rawset", "require", "select",
    "setfenv", "setmetatable", "tonumber", "tostring", "type", "unpack",
    "xpcall", "_G", "_VERSION",
    "coroutine", "debug", "io", "math", "os", "package", "string", "table",
})

# Palavras-chave do Lua que não são globals
PALAVRAS_CHAVE_LUA = frozenset({
    "and", "break", "do", "else", "elseif", "end", "false", "for",
    "function", "goto", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while",
})

# Padrões regex que identificam globals do engine Java do PZ
PADROES_ENGINE = [
    re.compile(r"^get[A-Z]"),       # getPlayer, getCore, getCell, etc.
    re.compile(r"^is[A-Z]"),        # isClient, isServer, etc.
    re.compile(r"^send[A-Z]"),      # sendClientCommand, sendServerCommand
    re.compile(r"^Iso[A-Z]"),       # IsoObject, IsoGenerator, IsoGridSquare, etc.
    re.compile(r"^IS[A-Z]"),        # ISPanel, ISButton, ISCollapsableWindow, etc.
    re.compile(r"^Container_"),     # Container_Fridge, Container_Freezer, etc.
]

# Globals do engine PZ que não seguem os padrões acima
GLOBALS_ENGINE_CONHECIDOS = frozenset({
    "instanceof", "ZombRand", "Events", "Keyboard", "Mouse",
    "UIFont", "SandboxVars", "Translator", "HUD", "Mod",
    "EventManager", "ModData", "Math", "KahluaTable",
    "IsoPlayer", "IsoObject", "IsoMicrowave", "IsoGridSquare",
    "IsoGenerator", "IsoHeatSource", "IsoLightSwitch", "IsoStove",
    "IsoThumpable", "IsoSpriteManager", "IsoUtils", "IsoDirections",
    "Texture", "ItemContainer", "ISContextMenu", "ISWorldObjectContextMenu",
    "ISTimedActionQueue", "ISBaseTimedAction", "ISUIElement",
    "ISCollapsableWindow", "ISPanel", "ISButton", "ISLabel",
    "ISTextEntryBox", "ISScrollingListBox", "ISTickBox",
    "luautils", "ContainerButtonIcons", "Fluid", "FluidType",
    "getNumActivePlayers", "getPlayerData", "getMouseX", "getMouseY",
})

# Diretórios a ignorar no workspace do LuaLS
DIRETORIOS_IGNORADOS = [
    ".venv",
    ".git",
    ".github",
    ".agents",
    ".metadocs",
    "scratch",
    "tools",
    "documents",
]

# Regex compilados
PADRAO_FUNCAO_GLOBAL = re.compile(r"^function\s+([A-Za-z_]\w+)\s*[.(:]", re.MULTILINE)
PADRAO_ATRIBUICAO_GLOBAL = re.compile(r"^([A-Z][A-Za-z_]\w*)\s*=\s*", re.MULTILINE)
PADRAO_CHAMADA_FUNCAO = re.compile(r"(?<![.:\"'\w])([a-zA-Z_]\w*)\s*\(")
PADRAO_TABELA_GLOBAL = re.compile(r"(?<![.:\"'\w{,])([A-Z][A-Za-z_]\w*)\s*\.")
PADRAO_LOCAL = re.compile(r"\blocal\s+(?:function\s+)?(\w+)")
PADRAO_ANNOTATION_TIPO = re.compile(r"---@(?:param|type|return|field)\s+(?:\w+\s+)?([A-Z][A-Za-z_]\w*)")

# Tipos primitivos/builtins do Lua e EmmyLua que não precisam de stub
TIPOS_BUILTINS = frozenset({
    "any", "nil", "boolean", "number", "string", "integer", "table",
    "function", "thread", "userdata", "void", "self",
})

# Tipos Java que são mapeados como aliases para primitivos (não precisam de @class)
ALIASES_PRIMITIVOS_JAVA = frozenset({
    "Integer", "String", "Float", "Double", "Boolean", "Watts",
})


def ler_diretorio_jogo() -> Path:
    """
    Lê ``PZ_GAME_DIR`` do arquivo ``.env`` na raiz do projeto.

    :returns: Caminho absoluto do diretório do jogo.
    :raises SystemExit: Se ``.env`` não existir ou ``PZ_GAME_DIR`` não estiver definido.
    """
    if not CAMINHO_ENV.exists():
        print(f"{RED}✗ Arquivo .env não encontrado em {CAMINHO_ENV}{RESET}")
        sys.exit(1)

    conteudo = CAMINHO_ENV.read_text(encoding="utf-8")
    for linha in conteudo.splitlines():
        linha_processada = linha.strip()
        if linha_processada.startswith("PZ_GAME_DIR="):
            valor = linha_processada.split("=", 1)[1].strip().strip('"').strip("'")
            caminho = Path(valor)
            if not caminho.exists():
                print(f"{RED}✗ PZ_GAME_DIR aponta para caminho inexistente: {caminho}{RESET}")
                sys.exit(1)
            return caminho

    print(f"{RED}✗ PZ_GAME_DIR não definido no .env{RESET}")
    sys.exit(1)


def ler_arquivo_lua(caminho_arquivo: Path) -> str:
    """
    Lê o conteúdo de um arquivo Lua com tratamento de encoding.

    :param caminho_arquivo: Caminho do arquivo ``.lua``.
    :returns: Conteúdo do arquivo como string, ou string vazia em caso de erro.
    """
    try:
        return caminho_arquivo.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def remover_comentarios(linha: str) -> str:
    """
    Remove comentários Lua de uma linha de código.

    Preserva strings que contenham ``--`` dentro de aspas.

    :param linha: Linha de código Lua.
    :returns: Linha sem o comentário inline.
    """
    resultado = linha.strip()
    if resultado.startswith("--"):
        return ""

    em_aspas_simples = False
    em_aspas_duplas = False
    indice = 0
    while indice < len(resultado) - 1:
        caractere = resultado[indice]
        if caractere == '"' and not em_aspas_simples:
            em_aspas_duplas = not em_aspas_duplas
        elif caractere == "'" and not em_aspas_duplas:
            em_aspas_simples = not em_aspas_simples
        elif caractere == "-" and resultado[indice + 1] == "-" and not em_aspas_simples and not em_aspas_duplas:
            return resultado[:indice]
        indice += 1

    return resultado


def coletar_definicoes_lua(diretorio_lua: Path) -> set[str]:
    """
    Escaneia arquivos Lua para coletar nomes definidos globalmente.

    Procura padrões como:

    - ``function NomeGlobal(`` — definição de função global
    - ``NomeGlobal = `` no início de linha — atribuição global
    - ``function NomeGlobal:metodo(`` — definição de método em tabela global

    :param diretorio_lua: Caminho para diretório contendo arquivos ``.lua``.
    :returns: Conjunto de nomes globais definidos.
    """
    definicoes = set()

    for arquivo in diretorio_lua.rglob("*.lua"):
        conteudo = ler_arquivo_lua(arquivo)
        if not conteudo:
            continue

        for correspondencia in PADRAO_FUNCAO_GLOBAL.finditer(conteudo):
            definicoes.add(correspondencia.group(1))

        for correspondencia in PADRAO_ATRIBUICAO_GLOBAL.finditer(conteudo):
            definicoes.add(correspondencia.group(1))

    return definicoes


def coletar_globals_usados_no_mod() -> set[str]:
    """
    Escaneia os Lua do mod para coletar referências a globals.

    Foca em chamadas de função (``getPlayer()``, ``instanceof()``) que são
    o padrão dominante dos globals do engine Java. Também subtrai definições
    locais (``local function ...``, ``local nome = ...``) para eliminar
    falsos positivos.

    :returns: Conjunto de nomes de globals referenciados no mod.
    """
    chamadas_funcao = set()
    definicoes_locais = set()

    for arquivo in CAMINHO_LUA_MOD.rglob("*.lua"):
        conteudo = ler_arquivo_lua(arquivo)
        if not conteudo:
            continue

        # Coleta definições locais (ignorando comentários)
        for linha in conteudo.splitlines():
            linha_limpa = remover_comentarios(linha)
            if not linha_limpa:
                continue
            for correspondencia in PADRAO_LOCAL.finditer(linha_limpa):
                definicoes_locais.add(correspondencia.group(1))

        for linha in conteudo.splitlines():
            linha_limpa = remover_comentarios(linha)
            if not linha_limpa:
                continue

            # Captura chamadas de função standalone (não métodos)
            for correspondencia in PADRAO_CHAMADA_FUNCAO.finditer(linha_limpa):
                chamadas_funcao.add(correspondencia.group(1))

            # Captura tabelas globais acessadas com ponto (SandboxVars.X, Events.Y)
            for correspondencia in PADRAO_TABELA_GLOBAL.finditer(linha_limpa):
                chamadas_funcao.add(correspondencia.group(1))

    # Remove definições locais do mod (não são globals)
    return chamadas_funcao - definicoes_locais


def eh_global_engine(nome: str) -> bool:
    """
    Verifica se um identificador corresponde a um global do engine Java do PZ.

    Usa padrões de nomenclatura conhecidos do engine (``get*``, ``is*``,
    ``send*``, ``Iso*``, ``Container_*``) e uma lista de globals avulsos.

    :param nome: Nome do identificador.
    :returns: True se o identificador é reconhecido como global do engine.
    """
    if nome in GLOBALS_ENGINE_CONHECIDOS:
        return True

    for padrao in PADROES_ENGINE:
        if padrao.match(nome):
            return True

    return False


def calcular_globals_engine(
    globals_usados_mod: set[str],
    definicoes_jogo: set[str],
    definicoes_mod: set[str],
) -> list[str]:
    """
    Calcula globals que são expostos pelo engine Java e precisam de declaração.

    Aplica duas camadas de filtragem:

    1. Remove tudo que já tem definição em Lua (jogo, mod, stdlib, keywords).
    2. Dos restantes, aceita apenas os que correspondem a padrões conhecidos
       do engine Java do PZ (``get*``, ``is*``, ``send*``, ``Iso*``, etc.).

    :param globals_usados_mod: Globals referenciados no mod.
    :param definicoes_jogo: Globals definidos nos Lua do jogo.
    :param definicoes_mod: Globals definidos no próprio mod.
    :returns: Lista ordenada de globals do engine Java para ``diagnostics.globals``.
    """
    resolvidos = definicoes_jogo | definicoes_mod | GLOBALS_LUA_PADRAO | PALAVRAS_CHAVE_LUA

    candidatos = globals_usados_mod - resolvidos

    globals_engine = {
        nome for nome in candidatos
        if nome.isascii()
        and len(nome) >= 3
        and eh_global_engine(nome)
    }

    return sorted(globals_engine)


def coletar_tipos_java_annotations() -> set[str]:
    """
    Escaneia annotations EmmyLua nos Lua do mod para extrair tipos Java.

    Busca padrões ``@param nome Tipo``, ``@type Tipo``, ``@return Tipo``
    e ``@field nome fun(...): Tipo`` para identificar classes Java do PZ
    que não possuem definição em Lua.

    :returns: Conjunto de nomes de tipos Java referenciados nas annotations.
    """
    tipos_encontrados = set()

    for arquivo in CAMINHO_LUA_MOD.rglob("*.lua"):
        conteudo = ler_arquivo_lua(arquivo)
        if not conteudo:
            continue

        for linha in conteudo.splitlines():
            linha_processada = linha.strip()
            if not linha_processada.startswith("---@"):
                continue

            for correspondencia in PADRAO_ANNOTATION_TIPO.finditer(linha_processada):
                tipo = correspondencia.group(1)
                if tipo not in TIPOS_BUILTINS:
                    tipos_encontrados.add(tipo)

    return tipos_encontrados


def gerar_stubs_tipos(
    tipos_java: set[str],
    definicoes_jogo: set[str],
    definicoes_mod: set[str],
) -> list[str]:
    """
    Filtra tipos Java que realmente precisam de stub (não resolvidos por library).

    :param tipos_java: Tipos encontrados nas annotations do mod.
    :param definicoes_jogo: Definições globais do jogo (resolvidas via library).
    :param definicoes_mod: Definições globais do mod.
    :returns: Lista ordenada de tipos que precisam de declaração ``---@class``.
    """
    resolvidos = definicoes_jogo | definicoes_mod

    tipos_pendentes = {
        tipo for tipo in tipos_java
        if tipo not in resolvidos
        and tipo not in ALIASES_PRIMITIVOS_JAVA
        and tipo.isascii()
        and len(tipo) >= 3
    }

    return sorted(tipos_pendentes)


def escrever_arquivo_stubs(tipos_pendentes: list[str]) -> None:
    """
    Gera o arquivo ``.types/LKS_PZ_Types.lua`` com declarações ``---@class``
    e aliases para tipos primitivos Java.

    :param tipos_pendentes: Lista de tipos Java que precisam de stub.
    """
    CAMINHO_TYPES.mkdir(parents=True, exist_ok=True)

    linhas = [
        "-- ============================================================================",
        "-- ARQUIVO: LKS_PZ_Types.lua (GERADO AUTOMATICAMENTE)",
        "-- OBJETIVO: Declarações de tipos do engine Java do Project Zomboid para o",
        "--           lua-language-server (LuaLS). Fornece autocomplete e elimina",
        "--           warnings \"undefined-doc-name\" em annotations EmmyLua.",
        "-- NOTA: Este arquivo NÃO é carregado pelo jogo. Existe apenas para o LSP.",
        "-- GERADO POR: python tools/gerar_luarc.py",
        "-- ============================================================================",
        "",
        "---@meta",
        "",
        "-- ============================================================================",
        "-- CLASSES DO ENGINE JAVA (Project Zomboid Build 42)",
        "-- ============================================================================",
        "",
    ]

    for tipo in tipos_pendentes:
        linhas.append(f"---@class {tipo}")
        linhas.append(f"---@field [any] any")
        linhas.append("")

    linhas.extend([
        "-- ============================================================================",
        "-- ALIASES DE TIPOS PRIMITIVOS JAVA (usados em annotations legadas)",
        "-- ============================================================================",
        "",
        "---@alias Integer integer",
        "---@alias String string",
        "---@alias Float number",
        "---@alias Double number",
        "---@alias Boolean boolean",
        "---@alias Watts number",
        "",
    ])

    CAMINHO_STUBS.write_text("\n".join(linhas), encoding="utf-8")


def montar_configuracao_luarc(diretorio_jogo: Path, globals_engine: list[str]) -> dict:
    """
    Monta o dicionário de configuração do ``.luarc.json``.

    :param diretorio_jogo: Caminho da instalação do Project Zomboid.
    :param globals_engine: Lista de globals do engine Java.
    :returns: Dicionário pronto para serializar em JSON.
    """
    caminho_lua_jogo = diretorio_jogo / "media" / "lua"

    caminhos_biblioteca = [
        str(caminho_lua_jogo / subpasta).replace("\\", "/")
        for subpasta in ("shared", "client", "server")
    ]

    # Adiciona a pasta .types do projeto (stubs EmmyLua de tipos Java do PZ)
    caminho_types = str(RAIZ_PROJETO / ".types").replace("\\", "/")
    caminhos_biblioteca.append(caminho_types)

    return {
        "$schema": "https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json",
        "runtime": {
            "version": "Lua 5.1",
            "path": [
                "?.lua",
                "?/init.lua",
            ],
            "pathStrict": False,
        },
        "workspace": {
            "library": caminhos_biblioteca,
            "ignoreDir": DIRETORIOS_IGNORADOS,
            "checkThirdParty": False,
        },
        "diagnostics": {
            "globals": globals_engine,
            "disable": [
                "lowercase-global",
            ],
        },
        "hint": {
            "enable": True,
        },
    }


def exibir_banner() -> None:
    """
    Exibe o banner estilizado do gerador no terminal.
    """
    print(f"\n{CYAN}╔══════════════════════════════════════════════════════╗{RESET}")
    print(f"{CYAN}║  ⚙️  LuaLS Config Generator — PZ Build 42            ║{RESET}")
    print(f"{CYAN}╚══════════════════════════════════════════════════════╝{RESET}\n")


def main() -> None:
    """
    Ponto de entrada principal.

    Lê configurações, escaneia fontes Lua do jogo e do mod,
    calcula globals do engine e gera o ``.luarc.json``.
    """
    exibir_banner()

    # 1. Ler diretório do jogo
    diretorio_jogo = ler_diretorio_jogo()
    diretorio_lua_jogo = diretorio_jogo / "media" / "lua"
    print(f"  {GREEN}✓{RESET} PZ_GAME_DIR: {GRAY}{diretorio_jogo}{RESET}")

    if not diretorio_lua_jogo.exists():
        print(f"  {RED}✗ Pasta media/lua/ não encontrada em {diretorio_jogo}{RESET}")
        sys.exit(1)

    # 2. Escanear definições do jogo
    print(f"  {YELLOW}⟳{RESET} Escaneando definições Lua do jogo...")
    definicoes_jogo = coletar_definicoes_lua(diretorio_lua_jogo)
    print(f"    {GREEN}✓{RESET} {len(definicoes_jogo)} definições encontradas no jogo")

    # 3. Escanear definições do mod
    print(f"  {YELLOW}⟳{RESET} Escaneando definições Lua do mod...")
    definicoes_mod = coletar_definicoes_lua(CAMINHO_LUA_MOD)
    print(f"    {GREEN}✓{RESET} {len(definicoes_mod)} definições encontradas no mod")

    # 4. Escanear globals usados pelo mod
    print(f"  {YELLOW}⟳{RESET} Escaneando globals referenciados pelo mod...")
    globals_usados = coletar_globals_usados_no_mod()
    print(f"    {GREEN}✓{RESET} {len(globals_usados)} referências únicas encontradas")

    # 5. Calcular globals do engine Java
    globals_engine = calcular_globals_engine(globals_usados, definicoes_jogo, definicoes_mod)
    print(f"    {GREEN}✓{RESET} {len(globals_engine)} globals do engine Java identificados")

    # 6. Extrair tipos Java das annotations EmmyLua
    print(f"  {YELLOW}⟳{RESET} Escaneando tipos Java nas annotations EmmyLua...")
    tipos_java = coletar_tipos_java_annotations()
    tipos_pendentes = gerar_stubs_tipos(tipos_java, definicoes_jogo, definicoes_mod)
    print(f"    {GREEN}✓{RESET} {len(tipos_pendentes)} tipos Java necessitam de stubs")

    # 7. Gerar .types/LKS_PZ_Types.lua
    escrever_arquivo_stubs(tipos_pendentes)
    print(f"    {GREEN}✓{RESET} .types/LKS_PZ_Types.lua gerado ({len(tipos_pendentes)} classes)")

    # 8. Gerar .luarc.json
    configuracao = montar_configuracao_luarc(diretorio_jogo, globals_engine)
    conteudo_json = json.dumps(configuracao, indent=2, ensure_ascii=False) + "\n"
    CAMINHO_LUARC.write_text(conteudo_json, encoding="utf-8")

    print(f"\n  {GREEN}✓ .luarc.json gerado com sucesso{RESET}")
    print(f"    Biblioteca:  {CYAN}{len(configuracao['workspace']['library'])}{RESET} caminhos (jogo + .types)")
    print(f"    Globals:     {CYAN}{len(globals_engine)}{RESET} declarados do engine Java")
    print(f"    Stubs:       {CYAN}{len(tipos_pendentes)}{RESET} classes Java em .types/")
    print(f"    Ignorados:   {CYAN}{len(DIRETORIOS_IGNORADOS)}{RESET} diretórios excluídos")
    print(f"    Caminho:     {GRAY}{CAMINHO_LUARC}{RESET}")
    print(f"\n  {YELLOW}⚡ Recarregue o VS Code (Ctrl+Shift+P → Reload Window) para aplicar.{RESET}\n")


if __name__ == "__main__":
    main()
