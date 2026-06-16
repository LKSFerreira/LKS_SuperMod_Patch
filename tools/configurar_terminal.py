# -*- coding: utf-8 -*-
"""
================================================================================
⌨️  CONFIGURADOR DE TERMINAL - LKS SUPERMOD PATCH
================================================================================
Autor: LKS FERREIRA
Versão: 1.0
Data da Última Modificação: 16/06/2026

PROPÓSITO:
Aplica configurações de atalhos de teclado no Antigravity IDE (fork do VS Code)
para que Shift+Enter funcione como quebra de linha no terminal integrado.
Útil após formatações de PC ou reinstalações do IDE.

Também configura o MinTTY (Git Bash standalone) caso necessário.

COMO USAR:
    python tools/configurar_terminal.py
================================================================================
"""

import json
import os
import sys
from pathlib import Path

if sys.version_info >= (3, 7):
    sys.stdout.reconfigure(encoding="utf-8", errors="ignore")
    sys.stderr.reconfigure(encoding="utf-8", errors="ignore")

RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RED = "\033[31m"

KEYBINDING_SHIFT_ENTER = {
    "key": "shift+enter",
    "command": "workbench.action.terminal.sendSequence",
    "args": {"text": "\u001b[13;2u"},
    "when": "terminalFocus && !terminalTextSelected",
}

MINTTYRC_LINHA = "Key_Shift+Return=\\x1b[13;2u"


def encontrar_diretorio_ide() -> Path | None:
    """Localiza o diretório de configuração do Antigravity IDE no AppData.

    :return: Caminho para o diretório User do IDE ou None se não encontrado.
    :rtype: Path | None

    .. code-block:: python

        caminho = encontrar_diretorio_ide()
        # Path('C:/Users/.../AppData/Roaming/Antigravity IDE/User')
    """
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return None

    diretorio_ide = Path(appdata) / "Antigravity IDE" / "User"
    if diretorio_ide.exists():
        return diretorio_ide

    return None


def carregar_keybindings(caminho_arquivo: Path) -> list[dict]:
    """Carrega keybindings existentes do arquivo JSON.

    :param caminho_arquivo: Caminho para o keybindings.json.
    :return: Lista de keybindings existentes.
    :rtype: list[dict]
    """
    if not caminho_arquivo.exists():
        return []

    try:
        conteudo = caminho_arquivo.read_text(encoding="utf-8").strip()
        if not conteudo:
            return []
        dados = json.loads(conteudo)
        if isinstance(dados, list):
            return dados
    except (json.JSONDecodeError, OSError) as erro:
        print(f"{YELLOW}[AVISO] Não foi possível ler keybindings existentes: {erro}{RESET}")

    return []


def binding_ja_existe(bindings: list[dict]) -> bool:
    """Verifica se o binding de Shift+Enter já está configurado.

    :param bindings: Lista de keybindings atuais.
    :return: True se o binding já existe.
    :rtype: bool
    """
    for binding in bindings:
        if (
            binding.get("key") == "shift+enter"
            and binding.get("command") == "workbench.action.terminal.sendSequence"
            and binding.get("args", {}).get("text") == "\x1b[13;2u"
        ):
            return True
    return False


def aplicar_keybinding_ide(diretorio_usuario: Path) -> bool:
    """Aplica o keybinding de Shift+Enter no Antigravity IDE.

    :param diretorio_usuario: Caminho para o diretório User do IDE.
    :return: True se a configuração foi aplicada com sucesso.
    :rtype: bool
    """
    caminho_arquivo = diretorio_usuario / "keybindings.json"
    bindings = carregar_keybindings(caminho_arquivo)

    if binding_ja_existe(bindings):
        print(f"{GREEN}  ✅ Shift+Enter já está configurado no IDE.{RESET}")
        return True

    bindings.append(KEYBINDING_SHIFT_ENTER)

    try:
        caminho_arquivo.write_text(
            json.dumps(bindings, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        print(f"{GREEN}  ✅ Keybinding aplicado em: {caminho_arquivo}{RESET}")
        return True
    except OSError as erro:
        print(f"{RED}  ❌ Falha ao gravar keybindings: {erro}{RESET}")
        return False


def aplicar_minttyrc() -> bool:
    """Aplica configuração de Shift+Enter no MinTTY (Git Bash standalone).

    :return: True se a configuração foi aplicada com sucesso.
    :rtype: bool
    """
    caminho_minttyrc = Path.home() / ".minttyrc"

    if caminho_minttyrc.exists():
        conteudo_existente = caminho_minttyrc.read_text(encoding="utf-8")
        if MINTTYRC_LINHA in conteudo_existente:
            print(f"{GREEN}  ✅ Shift+Enter já está configurado no MinTTY.{RESET}")
            return True
        conteudo_novo = conteudo_existente.rstrip() + "\n\n" + f"# Shift+Enter envia escape sequence para quebra de linha\n{MINTTYRC_LINHA}\n"
    else:
        conteudo_novo = f"# Shift+Enter envia escape sequence para quebra de linha\n{MINTTYRC_LINHA}\n"

    try:
        caminho_minttyrc.write_text(conteudo_novo, encoding="utf-8")
        print(f"{GREEN}  ✅ Configuração aplicada em: {caminho_minttyrc}{RESET}")
        return True
    except OSError as erro:
        print(f"{RED}  ❌ Falha ao gravar .minttyrc: {erro}{RESET}")
        return False


def main() -> None:
    """Ponto de entrada principal do configurador de terminal."""
    if os.name == "nt":
        os.system("")

    print(f"\n{CYAN}┌── {BOLD}⌨️  CONFIGURADOR DE TERMINAL - Shift+Enter{RESET}")
    print(f"{CYAN}│{RESET}")

    sucesso_total = True

    # Antigravity IDE
    print(f"{CYAN}│{RESET}  {BOLD}[1/2] Antigravity IDE{RESET}")
    diretorio_ide = encontrar_diretorio_ide()
    if diretorio_ide:
        if not aplicar_keybinding_ide(diretorio_ide):
            sucesso_total = False
    else:
        print(f"{YELLOW}  ⚠️  Antigravity IDE não encontrado em %APPDATA%.{RESET}")

    # MinTTY (Git Bash)
    print(f"{CYAN}│{RESET}  {BOLD}[2/2] MinTTY (Git Bash){RESET}")
    if not aplicar_minttyrc():
        sucesso_total = False

    print(f"{CYAN}│{RESET}")
    if sucesso_total:
        print(f"{CYAN}│{RESET}  {GREEN}{BOLD}Configuração concluída!{RESET}")
        print(f"{CYAN}│{RESET}  {YELLOW}⚠️  Reinicie o Antigravity IDE para aplicar.{RESET}")
    else:
        print(f"{CYAN}│{RESET}  {RED}{BOLD}Algumas configurações falharam. Verifique os erros acima.{RESET}")
    print(f"{CYAN}└───{RESET}\n")


if __name__ == "__main__":
    main()
