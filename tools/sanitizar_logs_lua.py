# -*- coding: utf-8 -*-
"""
================================================================================
🔤 SANITIZADOR DE LOGS LUA — LKS SUPERMOD PATCH
================================================================================
Autor: LKS FERREIRA
Versão: 1.0 (Project Zomboid Build 42)

PROPÓSITO:
Substitui caracteres acentuados PT-BR por equivalentes ASCII APENAS em strings
de log/debug (Registrador.Info/Warn/Error, print com tags [LKS]).
NÃO TOCA em fallbacks de getText(), traduções, ou strings visíveis ao jogador.

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

# Padrões que identificam linhas de LOG (onde sanitizar)
PADROES_LOG = [
    re.compile(r'Registrador\.(Info|Warn|Error|Debug)\s*\('),
    re.compile(r'print\s*\(\s*["\'].*\[LKS'),
    re.compile(r'print\s*\(\s*["\']\[LKS'),
]

# Padrões que identificam strings PROTEGIDAS (NUNCA sanitizar)
PADROES_PROTEGIDOS = [
    re.compile(r'getText\s*\(.*\)\s+or\s+["\']'),
    re.compile(r'\.(description|name)\s*='),
    re.compile(r'addOption\s*\('),
    re.compile(r'addOptionOnTop\s*\('),
    re.compile(r'toolTip'),
    re.compile(r'setName\s*\('),
]


def linha_eh_log(linha: str) -> bool:
    """Verifica se a linha contém chamada de log/debug."""
    for padrao in PADROES_LOG:
        if padrao.search(linha):
            return True
    return False


def linha_eh_protegida(linha: str) -> bool:
    """Verifica se a linha contém strings visíveis ao jogador."""
    for padrao in PADROES_PROTEGIDOS:
        if padrao.search(linha):
            return True
    return False


CARACTERES_ACENTUADOS = set('áàãâÁÀÃÂéêÉÊíÍóõôÓÕÔúüÚÜçÇ')


def tem_acentos(texto: str) -> bool:
    """Verifica se o texto contém caracteres acentuados PT-BR."""
    return any(c in CARACTERES_ACENTUADOS for c in texto)


def sanitizar_strings_log(linha: str) -> str:
    """Substitui acentos PT-BR por ASCII nas strings da linha de log."""
    resultado = []
    dentro_string = False
    delimitador = None
    inicio_string = 0

    for i, caractere in enumerate(linha):
        if not dentro_string:
            if caractere in ('"', "'"):
                dentro_string = True
                delimitador = caractere
                inicio_string = i
        else:
            if caractere == delimitador and (i == 0 or linha[i - 1] != '\\'):
                # Fim da string — sanitiza o conteúdo
                conteudo = linha[inicio_string + 1:i]
                conteudo_sanitizado = conteudo.translate(MAPA_ACENTOS)
                resultado.append(linha[:inicio_string + 1] if not resultado else '')
                resultado.append(conteudo_sanitizado)
                resultado.append(delimitador)
                linha = linha[i + 1:]
                dentro_string = False
                return ''.join(resultado) + sanitizar_strings_log(linha)

    return ''.join(resultado) + linha if resultado else linha


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

    for numero, linha in enumerate(linhas, 1):
        if linha_eh_log(linha) and not linha_eh_protegida(linha) and tem_acentos(linha):
            linha_nova = sanitizar_strings_log(linha)
            if linha_nova != linha:
                substituicoes += 1
                mudancas.append(f"  L{numero}: {linha.rstrip()}")
                mudancas.append(f"     → {linha_nova.rstrip()}")
                linhas_modificadas.append(linha_nova)
            else:
                linhas_modificadas.append(linha)
        else:
            linhas_modificadas.append(linha)

    if aplicar and substituicoes > 0:
        with open(caminho, 'w', encoding='utf-8', newline='') as arquivo:
            arquivo.writelines(linhas_modificadas)

    return substituicoes, mudancas


def main():
    diretorio_script = os.path.dirname(os.path.abspath(__file__))
    diretorio_raiz = os.path.abspath(os.path.join(diretorio_script, ".."))
    diretorio_lua = os.path.join(diretorio_raiz, "common", "media", "lua")

    parser = argparse.ArgumentParser(
        description="Sanitiza acentos PT-BR em strings de log Lua (preserva UI)."
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
