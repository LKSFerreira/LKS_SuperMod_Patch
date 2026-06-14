# -*- coding: utf-8 -*-
"""
================================================================================
🧹 SANITIZADOR DE LOGS - LKS SUPERMOD PATCH
================================================================================
Autor: LKS FERREIRA
Versão: 1.1 (Project Zomboid Build 42)
Data da Última Modificação: 14/06/2026

PROPÓSITO:
Ferramenta para higienização e monitoramento de logs de execução do jogo.
Filtra os arquivos de log oficiais ('console.txt') gerados pelo Project Zomboid,
removendo ruídos associados a outros mods já validados do ecossistema para
isolar logs de carregamento, mensagens personalizadas de depuração e erros do
LKS SuperMod Patch.
Gera os arquivos 'console_sanitizado.txt' (log limpo) e 'console_erros.txt'
(relatório consolidado de exceções críticas detectadas).

COMO USAR:
- Execução Padrão (utiliza o log oficial detectado no sistema do usuário):
    python tools/sanitiza_log.py
- Informando um arquivo de log customizado:
    python tools/sanitiza_log.py <caminho_console.txt> [<caminho_saida_sanitizado.txt>]
================================================================================
"""

import sys
import os
from pathlib import Path

# Garante que o console do Windows aceite codificação UTF-8
if sys.version_info >= (3, 7):
    sys.stdout.reconfigure(encoding='utf-8', errors='ignore')
    sys.stderr.reconfigure(encoding='utf-8', errors='ignore')

# Cores ANSI para o terminal (portável no Windows 10/11)
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RED = "\033[31m"

def obter_caminho_console_jogo():
    """Tenta localizar o arquivo console.txt oficial na pasta padrão do Project Zomboid do usuário."""
    caminho_padrao = Path(os.path.expanduser("~")) / "Zomboid" / "console.txt"
    if caminho_padrao.exists():
        return caminho_padrao
    return None

def sanitizar_log(arquivo_entrada=None, arquivo_saida=None):
    # Se não for informado um arquivo de entrada, tenta buscar dinamicamente
    if not arquivo_entrada:
        caminho_jogo = obter_caminho_console_jogo()
        if caminho_jogo:
            arquivo_entrada = caminho_jogo
            print(f"{CYAN}[INFO] Arquivo de log oficial detectado em: {arquivo_entrada}{RESET}")
        else:
            # Fallback para console.txt no diretório atual
            arquivo_entrada = Path("console.txt")
    else:
        arquivo_entrada = Path(arquivo_entrada)

    if not arquivo_entrada.exists():
        print(f"{RED}[-] ERRO: O arquivo de log '{arquivo_entrada}' não foi encontrado.{RESET}")
        print(f"{YELLOW}💡 Dica: Certifique-se de que o jogo já rodou ao menos uma vez ou passe o caminho do log manualmente.{RESET}")
        return

    # Se não for informado um arquivo de saída, salva na raiz do mod
    if not arquivo_saida:
        diretorio_raiz = Path(__file__).resolve().parent.parent
        arquivo_saida = diretorio_raiz / "console_sanitizado.txt"
    else:
        arquivo_saida = Path(arquivo_saida)

    termos_para_remover = [
        # Mod Validado: Performance
        'loading Performance',
        'mod "Performance" overrides',

        # Mod Validado: NeatUI_Framework
        'loading NeatUI_Framework',

        # Mod Validado: LuaDigitalWatchUI
        'loading LuaDigitalWatchUI',

        # Mod Validado: RC_RealisticColdMod
        'loading RC_RealisticColdMod',

        # Mod Validado: UsefulBarrelsMP
        'loading UsefulBarrelsMP',

        # Mod Validado: fridgesoff
        'loading fridgesoff',

        # Mod Validado: AutoMechanics
        'loading AutoMechanics',

        # Mod Validado: EURY_LIGHTFIRE
        'loading EURY_LIGHTFIRE',

        # Mod Validado: EuTenhoEsseLivro
        'loading EuTenhoEsseLivro',

        # Mod Validado: NamedSkillVHSTapes
        'loading NamedSkillVHSTapes',

        # Mods Validados: Ecossistema Neat (Crafting, Building e seus Addons de XP)
        'loading Neat_Crafting',
        'loading Neat_Crafting_AddonXP',
        'loading Neat_Building',
        'loading Neat_Building_AddonXP',

        # Mod Validado: MoreItemInformation
        'loading MoreItemInformation',

        # Mod Validado: EURY_CLOTHINGINFO
        'loading EURY_CLOTHINGINFO',

        # Mod Validado: RUNE-EXP
        'mod "RUNE-EXP" overrides',

        # Mods Validados: Indicadores Visuais e Tweaks de HUD
        'loading RYGProgressIndicator',
        'loading RYGProgressIndicatorSegmented',
        'loading CleanHotBar',
        'loading JustHideDebugMenu',
        'loading CleanUI',
        'loading Neat_Rocco',

        # Mods Validados: Traits e Tradução Base
        'loading MoreDescriptionForTraits4213',
        'loading MoreDescriptionForTraits4213_TranslationPatch',
        'loading PTBRB42'
    ]

    linhas_totais = 0
    linhas_gravadas = 0
    contagem_erros = 0
    linhas_erros = []
    bloco_stack_trace = False

    try:
        # Ativa suporte a cores ANSI no Windows
        if os.name == 'nt':
            os.system('')

        # O arquivo de erros será gravado no mesmo diretório do arquivo_saida
        diretorio_saida = Path(arquivo_saida).parent
        arquivo_erros = diretorio_saida / "console_erros.txt"

        with open(arquivo_entrada, "r", encoding="utf-8", errors="ignore") as f_in, \
             open(arquivo_saida, "w", encoding="utf-8") as f_out:
            
            for linha in f_in:
                linhas_totais += 1
                if not any(termo in linha for termo in termos_para_remover):
                    f_out.write(linha)
                    linhas_gravadas += 1
                    
                    # Detecção inteligente de erros e blocos de stack trace do Lua/Java
                    e_erro = "ERROR:" in linha or "Exception" in linha or "Lua fail" in linha or "STACK TRACE" in linha
                    
                    if "STACK TRACE" in linha or "dumping Lua stack trace" in linha:
                        bloco_stack_trace = True
                    elif bloco_stack_trace and not linha.strip():
                        bloco_stack_trace = False
                        
                    if e_erro or bloco_stack_trace or "Stack trace:" in linha or "\tLua(" in linha or "\tse.krka.kahlua." in linha:
                        linhas_erros.append(linha)
                        contagem_erros += 1

        # Salva o arquivo contendo apenas os erros extraídos
        if contagem_erros > 0:
            with open(arquivo_erros, "w", encoding="utf-8") as f_err:
                f_err.writelines(linhas_erros)

        print(f"\n{GREEN}┌── {BOLD}SANILOG - LOG SANITIZADO COM SUCESSO!{RESET}")
        print(f"{GREEN}│{RESET}  📄 {BOLD}Entrada:{RESET} {arquivo_entrada}")
        print(f"{GREEN}│{RESET}  💾 {BOLD}Saída:{RESET} {arquivo_saida}")
        print(f"{GREEN}│{RESET}  📊 {BOLD}Linhas analisadas:{RESET} {linhas_totais}")
        print(f"{GREEN}│{RESET}  🧹 {BOLD}Linhas gravadas (filtradas):{RESET} {linhas_gravadas} ({linhas_totais - linhas_gravadas} removidas)")
        
        if contagem_erros > 0:
            print(f"{GREEN}│{RESET}  ⚠️  {RED}{BOLD}Erros/Exceções encontrados:{RESET} {RED}{contagem_erros} linhas de erro extraídas!{RESET}")
            print(f"{GREEN}│{RESET}  📁 {BOLD}Relatório de erros gravado em:{RESET} {arquivo_erros}")
            
            # Se a quantidade de erros for pequena, exibe-os diretamente no terminal para depuração rápida
            num_exibir = min(len(linhas_erros), 15)
            print(f"{GREEN}│{RESET}")
            print(f"{GREEN}│{RESET}  🔍 {BOLD}Exibindo últimas/principais {num_exibir} linhas de erro no console:{RESET}")
            for l_err in linhas_erros[-num_exibir:]:
                print(f"{GREEN}│{RESET}    {RED}{l_err.strip()}{RESET}")
        else:
            print(f"{GREEN}│{RESET}  ✅ {GREEN}{BOLD}Erros/Exceções encontrados:{RESET} Nenhum erro crítico detectado nas linhas gravadas.")
        print(f"{GREEN}└───{RESET}\n")

    except Exception as e:
        print(f"{RED}[-] Erro ao processar o arquivo de log: {e}{RESET}")

if __name__ == "__main__":
    entrada_usuario = sys.argv[1] if len(sys.argv) > 1 else None
    sanitizar_log(entrada_usuario)