# -*- coding: utf-8 -*-
"""
================================================================================
🔤 SANITIZADOR DE LOGS LUA — LKS SUPERMOD PATCH
================================================================================
Autor: LKS FERREIRA
Versão: 1.0 (Project Zomboid Build 42)

PROPÓSITO:
Substitui caracteres acentuados PT-BR por equivalentes ASCII APENAS em strings
diretas de log/debug (Registrador.Info/Warn/Error, Logger.*, print, error).
NÃO TOCA em strings aninhadas em getText(), traduções, ou strings visíveis ao jogador.

COMO USAR:
- Dry-run (mostra o que mudaria sem aplicar):
    python tools/sanitizar_logs_lua.py
- Aplicar mudanças:
    python tools/sanitizar_logs_lua.py --aplicar
================================================================================
"""

import os
import re
import sys
import argparse

if sys.version_info >= (3, 7):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

if os.name == 'nt':
    os.system('')

RESET = "\033[0m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RED = "\033[31m"
GRAY = "\033[90m"

# Mapeamento de caracteres acentuados PT-BR → ASCII
MAPA_ACENTOS = str.maketrans({
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a',
    'Á': 'A', 'À': 'A', 'Ã': 'A', 'Â': 'A',
    'é': 'e', 'ê': 'e', 'É': 'E', 'Ê': 'E',
    'í': 'i', 'Í': 'I',
    'ó': 'o', 'õ': 'o', 'ô': 'o',
    'Ó': 'O', 'Õ': 'O', 'Ô': 'O',
    'ú': 'u', 'ü': 'u', 'Ú': 'U', 'Ü': 'U',
    'ç': 'c', 'Ç': 'C',
})

# Funções aninhadas que devem preservar o texto original.
FUNCOES_PROTEGIDAS = {
    "addOption",
    "addOptionOnTop",
    "getText",
    "setName",
    "toolTip",
}

# Chamadas que podem iniciar um trecho de log.
PADROES_INICIO_LOG = [
    re.compile(r'Registrador\.(Info|Warn|Error|Debug)\Z'),
    re.compile(r'Logger\.(Info|Warn|Error|Debug)\Z'),
    re.compile(r'LKS_EletricidadeConstrucao\.(Warn|Info|Error|Debug)\Z'),
    re.compile(r'LKS_EletricidadeConstrucao\.Core\.Logger\.(Info|Warn|Error|Debug)\Z'),
    re.compile(r'error\Z'),
    re.compile(r'\.Print\Z'),
    re.compile(r'print\Z'),
]


def token_eh_inicio_log(nome_funcao: str) -> bool:
    """Verifica se um token corresponde a uma chamada que inicia log."""
    for padrao in PADROES_INICIO_LOG:
        if padrao.fullmatch(nome_funcao):
            return True
    return False


def sanitizar_segmento_log(segmento: str, pilha_funcoes: list[str]) -> tuple[str, list[str]]:
    """Processa um trecho de log, preservando chamadas protegidas aninhadas."""
    resultado = []
    token_funcao = []
    dentro_string = False
    delimitador = ""
    string_atual = []
    sanitizar_string_atual = False
    indice = 0
    em_log = bool(pilha_funcoes)

    while indice < len(segmento):
        caractere = segmento[indice]

        if dentro_string:
            string_atual.append(caractere)
            if caractere == delimitador:
                barras_anteriores = 0
                cursor = indice - 1
                while cursor >= 0 and segmento[cursor] == "\\":
                    barras_anteriores += 1
                    cursor -= 1

                if barras_anteriores % 2 == 0:
                    if sanitizar_string_atual:
                        conteudo = "".join(string_atual[1:-1]).translate(MAPA_ACENTOS)
                        resultado.append(delimitador)
                        resultado.append(conteudo)
                        resultado.append(delimitador)
                    else:
                        resultado.extend(string_atual)

                    dentro_string = False
                    delimitador = ""
                    sanitizar_string_atual = False
                    string_atual = []
        else:
            if caractere in ('"', "'"):
                dentro_string = True
                delimitador = caractere
                sanitizar_string_atual = em_log and (
                    not pilha_funcoes or pilha_funcoes[-1] not in FUNCOES_PROTEGIDAS
                )
                string_atual = [caractere]
            else:
                resultado.append(caractere)

                if caractere.isalnum() or caractere in "._:":
                    token_funcao.append(caractere)
                elif caractere == "(":
                    nome_funcao = "".join(token_funcao).strip()
                    if em_log:
                        pilha_funcoes.append(nome_funcao)
                    elif token_eh_inicio_log(nome_funcao):
                        em_log = True
                        pilha_funcoes = [nome_funcao]
                    token_funcao = []
                elif caractere == ")":
                    if pilha_funcoes:
                        pilha_funcoes.pop()
                    if not pilha_funcoes:
                        em_log = False
                    token_funcao = []
                else:
                    if not caractere.isspace():
                        token_funcao = []

        indice += 1

    if dentro_string:
        resultado.extend(string_atual)

    return "".join(resultado), pilha_funcoes


def processar_arquivo(caminho: str, aplicar: bool) -> tuple[int, list[str]]:
    """
    Processa um arquivo Lua, sanitizando apenas strings de log.

    :param caminho: Caminho do arquivo .lua
    :param aplicar: Se True, grava as mudanças. Se False, apenas reporta.
    :return: (quantidade_substituicoes, lista_de_mudancas)
    """
    with open(caminho, 'r', encoding='utf-8', errors='replace') as arquivo:
        linhas = arquivo.readlines()

    substituicoes = 0
    mudancas = []
    linhas_modificadas = []
    pilha_funcoes: list[str] = []

    for numero, linha in enumerate(linhas, 1):
        linha_nova, pilha_funcoes = sanitizar_segmento_log(linha, pilha_funcoes)

        if linha_nova != linha:
            substituicoes += 1
            mudancas.append(f"  L{numero}: {linha.rstrip()}")
            mudancas.append(f"     → {linha_nova.rstrip()}")

        linhas_modificadas.append(linha_nova)

    if aplicar and substituicoes > 0:
        with open(caminho, 'w', encoding='utf-8', newline='') as arquivo:
            arquivo.writelines(linhas_modificadas)

    return substituicoes, mudancas


def main():
    diretorio_script = os.path.dirname(os.path.abspath(__file__))
    diretorio_raiz = os.path.abspath(os.path.join(diretorio_script, ".."))
    diretorio_lua = os.path.join(diretorio_raiz, "common", "media", "lua")

    parser = argparse.ArgumentParser(
        description="Sanitiza acentos PT-BR apenas em strings diretas de logs Lua."
    )
    parser.add_argument(
        "--aplicar",
        action="store_true",
        help="Aplica as substituições nos arquivos (sem flag = dry-run)."
    )
    args = parser.parse_args()

    if not os.path.isdir(diretorio_lua):
        print(f"{RED}[!] Diretorio Lua nao encontrado: {diretorio_lua}{RESET}")
        sys.exit(1)

    # Coleta arquivos .lua
    arquivos = []
    for raiz, _, nomes in os.walk(diretorio_lua):
        for nome in sorted(nomes):
            if nome.endswith(".lua"):
                arquivos.append(os.path.join(raiz, nome))

    modo = "APLICANDO" if args.aplicar else "DRY-RUN"
    print(f"{CYAN}[*] Sanitizador de Logs — modo {modo}{RESET}")
    print(f"{CYAN}[*] Escaneando {len(arquivos)} arquivos Lua...{RESET}")
    print()

    total_substituicoes = 0
    arquivos_modificados = 0

    for caminho in arquivos:
        substituicoes, mudancas = processar_arquivo(caminho, args.aplicar)
        if substituicoes > 0:
            caminho_relativo = os.path.relpath(caminho, diretorio_raiz)
            print(f"{YELLOW}[~] {caminho_relativo} ({substituicoes} substituicoes){RESET}")
            for linha_mudanca in mudancas:
                print(f"{GRAY}{linha_mudanca}{RESET}")
            print()
            total_substituicoes += substituicoes
            arquivos_modificados += 1

    print(f"{GREEN}[✓] Concluido: {total_substituicoes} substituicoes em {arquivos_modificados} arquivos{RESET}")
    if not args.aplicar and total_substituicoes > 0:
        print(f"{CYAN}    Use --aplicar para gravar as mudancas.{RESET}")


if __name__ == '__main__':
    main()
