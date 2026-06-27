# -*- coding: utf-8 -*-
"""
================================================================================
🎨 TOOLS ASSETS - LKS SUPERMOD PATCH
================================================================================
Autor: LKS FERREIRA
Versão: 1.5 (Refatorado - Project Zomboid Build 42)
Data da Última Modificação: 27/06/2026

PROPÓSITO:
Ponto de entrada unificado para humanos. Gerencia o menu interativo com
experiência rica (UI/UX, emojis, banners coloridos) e garante retrocompatibilidade
com argumentos CLI clássicos, delegando as lógicas para scripts específicos em tools/.

COMO USAR (HUMANO):
- Modo Interativo (Menu):
    python LKS_Tools.py
- Comandos CLI Clássicos:
    python LKS_Tools.py <Nome_Sprite_Original>
    python LKS_Tools.py -e <Nome_Sprite_Original>
    python LKS_Tools.py -b <Termo_de_Busca>
    python LKS_Tools.py -i <Caminho_do_PNG>
    python LKS_Tools.py -c <PNG_Original> [-o <PNG_Saida>]
    python LKS_Tools.py -a
================================================================================
"""

import os
import sys
import re
import argparse
import subprocess
import shutil
from pathlib import Path

# Configurações de caminhos padrão
DIRETORIO_RAIZ = Path(__file__).resolve().parent
DIRETORIO_FERRAMENTAS = DIRETORIO_RAIZ / "tools"
DIRETORIO_UI_MOD = DIRETORIO_RAIZ / "common" / "media" / "ui"

# Cores do terminal
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RED = "\033[31m"
GRAY = "\033[90m"

# Garante suporte UTF-8 no Windows
if sys.version_info >= (3, 7):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
if os.name == 'nt':
    os.system('')

# Importação dinâmica das ferramentas
try:
    from tools.extrair_sprites import (
        extrair_assets_do_jogo,
        sugerir_nome_arquivo,
        validar_e_salvar_caminho,
        obter_diretorio_jogo_grafico,
        DIRETORIO_JOGO_PADRAO
    )
    from tools.inspecionar_imagem import inspecionar_propriedades_imagem
    from tools.processar_imagem import processar_imagem_core, processar_imagem_interativo
    from tools.buscar_referencias import buscar_referencias_assets
except ImportError as erro_importacao:
    print(f"{RED}[-] ERRO CRÍTICO: Não foi possível importar os scripts de ferramentas em tools/.{RESET}")
    print(f"Detalhe: {erro_importacao}")
    sys.exit(1)


def print_banner() -> None:
    """Exibe um banner ASCII moderno com bordas unicode elegantes e emojis para humanos."""
    os.system('cls' if os.name == 'nt' else 'clear')
    emoji_ferramenta = "🔧"
    largura_interna = 74
    
    def formatar_linha_banner(conteudo, cor_borda=CYAN):
        conteudo_limpo = re.sub(r'\033\[[0-9;]*m', '', conteudo)
        tamanho_visual = sum(2 if ord(char) > 0xffff else 1 for char in conteudo_limpo)
        espacos_necessarios = max(0, largura_interna - tamanho_visual)
        espacos_esquerda = espacos_necessarios // 2
        espacos_direita = espacos_necessarios - espacos_esquerda
        return f"    {cor_borda}║{RESET}{' ' * espacos_esquerda}{conteudo}{' ' * espacos_direita}{cor_borda}║{RESET}"

    linha_superior = f"    {CYAN}╔" + "═" * largura_interna + f"╗{RESET}"
    linha_1 = formatar_linha_banner(f"{BOLD}{emoji_ferramenta} LKS TOOLS - SUPERMOD PATCH {emoji_ferramenta}{RESET}")
    linha_2 = formatar_linha_banner(f"{GRAY}Centralizador de Extração, Inspeção e Auditoria de Sprites{RESET}")
    linha_inferior = f"    {CYAN}╚" + "═" * largura_interna + f"╝{RESET}"
    
    print("\n" + linha_superior)
    print(linha_1)
    print(linha_2)
    print(linha_inferior + "\n")


def redirecionar_auditoria_completa() -> None:
    """Chama de forma unificada a auditoria completa do script auditoria_mod.py."""
    caminho_auditoria = DIRETORIO_FERRAMENTAS / "auditoria_mod.py"
    if caminho_auditoria.exists():
        print(f"\n{CYAN}[*] Iniciando a auditoria completa do mod...{RESET}\n")
        subprocess.run([sys.executable, str(caminho_auditoria)])
    else:
        print(f"{RED}[-] Erro: Script de auditoria 'auditoria_mod.py' não encontrado em: {caminho_auditoria}{RESET}")


def run_menu_interativo() -> None:
    """Exibe o menu interativo com emojis para uso por humanos."""
    while True:
        print_banner()
        print(f"  {BOLD}Selecione a operação desejada:{RESET}")
        print(f"    {CYAN}[1]{RESET} 📦 Extrair Assets do Jogo (.pack ➔ PNG)")
        print(f"    {CYAN}[2]{RESET} 🔍 Inspecionar Imagem (Resolução, modo, bit depth)")
        print(f"    {CYAN}[3]{RESET} ⚙️  Processar Imagem (Redimensionar, Converter bits/formatos, Lotes)")
        print(f"    {CYAN}[4]{RESET} 📋 Executar Auditoria Completa do Mod (auditoria_mod.py)")
        print(f"    {CYAN}[5]{RESET} 🔎 Buscar Referências de Assets (Unificado 2D/3D)")
        print(f"    {CYAN}[0]{RESET} 🚪 Sair")
        
        try:
            opcao = input(f"\n  {BOLD}Escolha uma opção (0-5):{RESET} ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\n  Saindo...")
            break
            
        if opcao == "0":
            print(f"\n{GREEN}[+] Obrigado por usar o LKS Tools! Até logo!{RESET}\n")
            break
            
        elif opcao == "1":
            caminho_jogo = DIRETORIO_JOGO_PADRAO
            pasta_packs = Path(caminho_jogo) / "media" / "texturepacks" if caminho_jogo else None
            if not caminho_jogo or not pasta_packs or not pasta_packs.exists():
                print(f"{YELLOW}[!] Caminho do jogo não configurado ou inválido. Abrindo explorador de pastas...{RESET}")
                caminho_jogo = obter_diretorio_jogo_grafico()
            else:
                print(f"{GREEN}[+] Diretório do jogo configurado: {caminho_jogo}{RESET}\n")
            
            sprite_alvo = input("Digite o nome do Sprite original do jogo a extrair (ou Enter para os padrões): ").strip()
            
            if sprite_alvo:
                sprite_alvo_limpo = re.sub(r"\.(png|jpg|tga|jpeg|gif)$", "", sprite_alvo, flags=re.IGNORECASE)
                nome_sugerido = sugerir_nome_arquivo(sprite_alvo_limpo)
                nome_arq = input(f"Nome do arquivo de saída PNG [Padrão: {nome_sugerido}]: ").strip()
                if not nome_arq:
                    nome_arq = nome_sugerido
                nome_arq = os.path.basename(nome_arq)
                if not nome_arq.lower().endswith(".png"):
                    nome_arq += ".png"
                mapeamento = {sprite_alvo_limpo: nome_arq}
            else:
                mapeamento = {
                    "container_fridge": "Container_Fridge.png",
                    "container_freezer": "Container_Freezer.png",
                    "container_microwave": "Container_Microwave.png",
                    "container_oven": "Container_Stove.png"
                }
            
            extrair_assets_do_jogo(caminho_jogo, mapeamento, str(DIRETORIO_UI_MOD))
            input(f"\nPressione Enter para voltar ao menu...")
            
        elif opcao == "2":
            caminho_img = input("Digite o nome ou caminho da imagem ou pasta: ").strip().strip('"').strip("'")
            caminho = Path(caminho_img)
            if caminho.exists():
                if caminho.is_file():
                    inspecionar_propriedades_imagem(caminho)
                else:
                    for idx, arq in enumerate(caminho.iterdir(), 1):
                        if arq.is_file() and arq.suffix.lower() in ('.png', '.jpg', '.tga', '.webp'):
                            inspecionar_propriedades_imagem(arq, idx)
            else:
                # Tenta na pasta UI do mod
                caminho_mod = DIRETORIO_UI_MOD / caminho_img
                if caminho_mod.exists():
                    inspecionar_propriedades_imagem(caminho_mod)
                else:
                    print(f"{RED}[-] Caminho não encontrado: '{caminho_img}'{RESET}")
            input(f"\nPressione Enter para voltar ao menu...")
            
        elif opcao == "3":
            processar_imagem_interativo()
            input(f"\nPressione Enter para voltar ao menu...")
            
        elif opcao == "4":
            redirecionar_auditoria_completa()
            input(f"\nPressione Enter para voltar ao menu...")
            
        elif opcao == "5":
            caminho_jogo = DIRETORIO_JOGO_PADRAO
            pasta_packs = Path(caminho_jogo) / "media" / "texturepacks" if caminho_jogo else None
            if not caminho_jogo or not pasta_packs or not pasta_packs.exists():
                caminho_jogo = obter_diretorio_jogo_grafico()
            else:
                print(f"{GREEN}[+] Diretório do jogo configurado: {caminho_jogo}{RESET}\n")
            
            termo = input("Digite o termo de busca (ex: Generator, Washer, Fridge): ").strip()
            if termo:
                # Usa o buscar_referencias_assets e apresenta o relatório
                sprites_ui, sprites_mundo = buscar_referencias_assets(termo, caminho_jogo, silencioso=False)
                
                print(f"\n{CYAN}┌── {BOLD}🔍 ÍCONES 2D / INTERFACE ENCONTRADOS (Packs de UI e Avulsos):{RESET}")
                if sprites_ui:
                    for idx, item in enumerate(sprites_ui, 1):
                        sprite_nome = item['sprite']
                        pagina = item['pagina']
                        pack_nome = item['pack'].split('.')[0] if item['pack'] != "avulso" else "avulso"
                        
                        if item['pack'] == "avulso":
                            print(f"{CYAN}│{RESET}  [{idx:<2}] Sprite: {GREEN}{sprite_nome:<30}{RESET} (Arquivo avulso em {pagina})")
                        else:
                            print(f"{CYAN}│{RESET}  [{idx:<2}] Sprite: {GREEN}{sprite_nome:<30}{RESET} (em {pagina} no {pack_nome})")
                else:
                    print(f"{CYAN}│{RESET}  {YELLOW}Nenhum ícone 2D (Item/UI) encontrado para o termo '{termo}'.{RESET}")
                print(f"{CYAN}└───{RESET}")
                    
                print(f"\n{CYAN}┌── {BOLD}🧱 SPRITES 3D / TILESETS ENCONTRADOS (Mundo):{RESET}")
                offset_3d = len(sprites_ui)
                if sprites_mundo:
                    for idx, item in enumerate(sprites_mundo, 1):
                        sprite_nome = item['sprite']
                        detalhes = item['detalhes']
                        print(f"{CYAN}│{RESET}  [{idx + offset_3d:<2}] Sprite: {CYAN}{sprite_nome}{RESET} ➔ {detalhes}")
                else:
                    print(f"{CYAN}│{RESET}  {YELLOW}Nenhum sprite 3D (Mundo/Tileset) encontrado para o termo '{termo}'.{RESET}")
                print(f"{CYAN}└───{RESET}")

                total_encontrados = sprites_ui + sprites_mundo
                if total_encontrados:
                    try:
                        escolha = input(f"\nDeseja extrair/copiar algum destes assets? (números separados por vírgula, ou Enter para sair): ").strip()
                        if escolha:
                            tokens = re.split(r"[,;\s]+", escolha)
                            numeros_validos = []
                            for token in tokens:
                                if not token:
                                    continue
                                num = int(token)
                                if 1 <= num <= len(total_encontrados):
                                    numeros_validos.append(num)
                                else:
                                    print(f"{RED}[-] Número {num} fora do intervalo. Ignorado.{RESET}")

                            for num in numeros_validos:
                                asset_alvo = total_encontrados[num - 1]
                                sprite_nome = asset_alvo["sprite"]

                                if asset_alvo.get("pack") == "avulso":
                                    caminho_origem = Path(asset_alvo["caminho_avulso"])
                                    caminho_destino = DIRETORIO_UI_MOD / sprite_nome
                                    os.makedirs(DIRETORIO_UI_MOD, exist_ok=True)
                                    shutil.copy2(caminho_origem, caminho_destino)
                                    caminho_destino_rel = os.path.relpath(caminho_destino, DIRETORIO_RAIZ).replace('\\', '/')
                                    print(f"{GREEN}  [+] Arquivo avulso copiado com sucesso: {caminho_origem.name} ➔ ./{caminho_destino_rel}{RESET}")
                                else:
                                    nome_saida = sugerir_nome_arquivo(sprite_nome)
                                    print(f"\n[*] Extraindo '{sprite_nome}'...")
                                    mapeamento = {sprite_nome: nome_saida}
                                    extrair_assets_do_jogo(caminho_jogo, mapeamento, str(DIRETORIO_UI_MOD))
                    except ValueError:
                        print(f"{RED}[-] Entrada inválida (use apenas números separados por vírgula).{RESET}")
                    except Exception as erro:
                        print(f"{RED}[-] Erro na seleção/cópia: {erro}{RESET}")
            input(f"\nPressione Enter para voltar ao menu...")


class ArgumentParserPTBR(argparse.ArgumentParser):
    """Subclasse customizada do ArgumentParser para internacionalização de erros em pt-BR."""
    def error(self, message):
        mensagem_traduzida = message
        if "not allowed with argument" in message:
            partes = message.split("not allowed with argument")
            arg1 = partes[0].replace("argument", "argumento").strip()
            arg2 = partes[1].strip()
            mensagem_traduzida = f"{arg1} não é permitido em conjunto com {arg2} (estas opções são mutuamente exclusivas)."
        elif "unrecognized arguments" in message:
            mensagem_traduzida = message.replace("unrecognized arguments", "argumentos não reconhecidos")
        elif "ignored with" in message:
            mensagem_traduzida = message.replace("ignored with", "ignorado com")
        elif "is required" in message:
            mensagem_traduzida = message.replace("argument", "argumento").replace("is required", "é obrigatório")
        elif "invalid choice" in message:
            mensagem_traduzida = message.replace("invalid choice", "escolha inválida").replace("choose from", "escolha entre").replace("argument", "argumento")
        elif "one of the arguments" in message and "is required" in message:
            mensagem_traduzida = message.replace("one of the arguments", "um dos seguintes argumentos").replace("is required", "é obrigatório")

        sys.stderr.write(f"\n{RED}┌──────────────────────────────────────────────────────────────────────────────┐{RESET}\n")
        sys.stderr.write(f"{RED}│ ❌ ERRO DE ARGUMENTO CLI:                                                    │{RESET}\n")
        sys.stderr.write(f"{RED}└──────────────────────────────────────────────────────────────────────────────┘{RESET}\n")
        sys.stderr.write(f"  {YELLOW}{mensagem_traduzida}{RESET}\n\n")
        sys.stderr.write(f"{CYAN}💡 DICA: Digite 'python LKS_Tools.py -h' ou '--help' para ver a documentação.{RESET}\n\n")
        sys.exit(2)


def main() -> None:
    # Pré-processador dinâmico de argumentos (retrocompatibilidade para argumentos legados)
    if len(sys.argv) > 1:
        argumentos_originais = sys.argv[1:]
        
        subcomandos_legados = {
            "extrair": "-e",
            "inspecionar": "-i",
            "converter": "-c",
            "auditar": "-a",
            "buscar": "-b"
        }
        for indice, argumento in enumerate(argumentos_originais):
            if argumento.lower() in subcomandos_legados:
                argumentos_originais[indice] = subcomandos_legados[argumento.lower()]
        
        valores_soltos = []
        flags_presentes = []
        configuracoes = []
        
        flags_acao_com_valor = ("-i", "--inspecionar", "-c", "--converter", "-b", "--buscar")
        flags_acao_sem_valor = ("-e", "--extrair", "-a", "--auditar")
        configs_gerais = ("-j", "--jogo", "-d", "--destino", "-o", "--saida", "-s", "--sprite", "-r", "--resize", "-f", "--format")
        
        indice_atual = 0
        while indice_atual < len(argumentos_originais):
            argumento = argumentos_originais[indice_atual]
            if argumento in flags_acao_sem_valor:
                flags_presentes.append(argumento)
                indice_atual += 1
            elif argumento in flags_acao_com_valor or argumento in configs_gerais:
                if indice_atual + 1 < len(argumentos_originais) and not argumentos_originais[indice_atual+1].startswith("-"):
                    configuracoes.append((argumento, argumentos_originais[indice_atual+1]))
                    indice_atual += 2
                else:
                    flags_presentes.append(argumento)
                    indice_atual += 1
            elif argumento.startswith("-"):
                flags_presentes.append(argumento)
                indice_atual += 1
            else:
                valores_soltos.append(argumento)
                indice_atual += 1
                
        flag_acao_ativa_com_valor = next((flag for flag in flags_presentes if flag in flags_acao_com_valor), None)
        
        if flag_acao_ativa_com_valor and valores_soltos:
            valor_associado = valores_soltos.pop(0)
            configuracoes.append((flag_acao_ativa_com_valor, valor_associado))
            flags_presentes.remove(flag_acao_ativa_com_valor)
            
        if valores_soltos:
            for valor_solto in valores_soltos:
                configuracoes.append(("-s", valor_solto))
            qualquer_acao = (
                any(flag in flags_acao_sem_valor or flag in flags_acao_com_valor for flag in flags_presentes) or
                any(par_config[0] in flags_acao_com_valor for par_config in configuracoes)
            )
            if not qualquer_acao and "-e" not in flags_presentes and "--extrair" not in flags_presentes:
                flags_presentes.append("-e")
                
        novos_argumentos = [sys.argv[0]]
        for flag in flags_presentes:
            novos_argumentos.append(flag)
        for opcao_config, valor_config in configuracoes:
            novos_argumentos.append(opcao_config)
            novos_argumentos.append(valor_config)
            
        sys.argv = novos_argumentos

    parser = ArgumentParserPTBR(
        description=f"{CYAN}{BOLD}🎨 LKS TOOLS - SUPERMOD PATCH{RESET}\n\n"
                    f"DICA: Você pode passar o nome de um sprite diretamente como primeiro argumento para extraí-lo!\n"
                    f"Exemplos:\n"
                    f"  python LKS_Tools.py Container_Fridge         (Extrai o ícone da interface)\n"
                    f"  python LKS_Tools.py -b Generator             (Busca referências de assets)\n",
        formatter_class=argparse.RawTextHelpFormatter
    )
    
    grupo_acao = parser.add_mutually_exclusive_group()
    
    grupo_acao.add_argument(
        "--extrair", "-e",
        action="store_true",
        help="Extrai texturas de arquivos .pack do jogo (padrão ou customizado via -s)"
    )
    grupo_acao.add_argument(
        "--inspecionar", "-i",
        metavar="CAMINHO",
        help="Inspeciona propriedades de cor, bits e canais de uma imagem ou pasta"
    )
    grupo_acao.add_argument(
        "--converter", "-c",
        metavar="ENTRADA",
        help="Converte imagem PNG para 8-bit seguro para evitar travamento no jogo"
    )
    grupo_acao.add_argument(
        "--auditar", "-a",
        action="store_true",
        help="Executa a auditoria unificada completa do mod"
    )
    grupo_acao.add_argument(
        "--buscar", "-b",
        metavar="TERMO",
        help="Busca referências de um asset (UI e Mundo) a partir de um termo"
    )
    
    parser.add_argument("--jogo", "-j", default=DIRETORIO_JOGO_PADRAO, help="Diretório de instalação do Project Zomboid")
    parser.add_argument("--destino", "-d", default=str(DIRETORIO_UI_MOD), help="Pasta de destino para imagens PNG extraídas")
    parser.add_argument(
        "--sprite", "-s",
        action="append",
        help="Mapeamento de sprite para extrair no formato 'sprite_original:nome_saida.png' (pode ser repetido)"
    )
    parser.add_argument("--saida", "-o", help="Caminho do arquivo PNG de saída (usado com --converter)")
    parser.add_argument("--resize", "-r", help="Redimensiona a imagem (Ex: 2x, 50%%, 256, 512x512)")
    parser.add_argument("--format", "-f", help="Converte para outro formato (Ex: png, jpg, webp, svg, tga)")
    
    args = parser.parse_args()
    
    # Se nenhuma ação principal baseada em flags foi especificada, abre o modo interativo
    if not (args.extrair or args.inspecionar or args.converter or args.auditar or args.buscar):
        run_menu_interativo()
        return
        
    # Executa a ação correspondente delegando aos scripts em tools/
    if args.extrair:
        caminho_jogo = args.jogo
        if not validar_e_salvar_caminho(caminho_jogo):
            print(f"{YELLOW}[!] Caminho '{caminho_jogo}' não é uma instalação válida. Abrindo explorador gráfico...{RESET}")
            caminho_jogo = obter_diretorio_jogo_grafico()
            
        mapeamento = {}
        if args.sprite:
            for item_sprite in args.sprite:
                if ":" in item_sprite:
                    sprite_original_usuario, arquivo_saida_usuario = item_sprite.split(":", 1)
                    sprite_original_limpo = re.sub(r"\.(png|jpg|tga|jpeg|gif)$", "", sprite_original_usuario.strip(), flags=re.IGNORECASE)
                    mapeamento[sprite_original_limpo] = arquivo_saida_usuario.strip()
                else:
                    nome_sprite_usuario = item_sprite.strip()
                    nome_sprite_limpo = re.sub(r"\.(png|jpg|tga|jpeg|gif)$", "", nome_sprite_usuario, flags=re.IGNORECASE)
                    mapeamento[nome_sprite_limpo] = sugerir_nome_arquivo(nome_sprite_limpo)
        else:
            mapeamento = {
                "container_fridge": "Container_Fridge.png",
                "container_freezer": "Container_Freezer.png",
                "container_microwave": "Container_Microwave.png",
                "container_oven": "Container_Stove.png"
            }
        extrair_assets_do_jogo(caminho_jogo, mapeamento, args.destino)
        
    elif args.inspecionar:
        caminho = Path(args.inspecionar)
        if caminho.exists():
            if caminho.is_file():
                inspecionar_propriedades_imagem(caminho)
            else:
                for idx, arq in enumerate(caminho.iterdir(), 1):
                    if arq.is_file() and arq.suffix.lower() in ('.png', '.jpg', '.tga', '.webp'):
                        inspecionar_propriedades_imagem(arq, idx)
        else:
            caminho_mod = DIRETORIO_UI_MOD / args.inspecionar
            if caminho_mod.exists():
                inspecionar_propriedades_imagem(caminho_mod)
            else:
                print(f"{RED}[-] Caminho não encontrado: {caminho}{RESET}")
                
    elif args.converter:
        saida = args.saida if args.saida else args.converter
        ext_final = args.format.strip().lower() if args.format else None
        caminho_saida = Path(saida)
        if ext_final and not args.saida:
            caminho_saida = caminho_saida.with_suffix(f".{ext_final}")
            
        processar_imagem_core(
            Path(args.converter),
            caminho_saida,
            args.resize,
            True,
            ext_final
        )
        
    elif args.auditar:
        redirecionar_auditoria_completa()
        
    elif args.buscar:
        caminho_jogo = args.jogo
        if not validar_e_salvar_caminho(caminho_jogo):
            print(f"{YELLOW}[!] Caminho '{caminho_jogo}' não é uma instalação válida. Abrindo explorador gráfico...{RESET}")
            caminho_jogo = obter_diretorio_jogo_grafico()
        # Chama a busca unificada e exibe o relatório de terminal
        sprites_ui, sprites_mundo = buscar_referencias_assets(args.buscar, caminho_jogo, silencioso=False)
        
        print(f"\n{CYAN}┌── {BOLD}🔍 ÍCONES 2D / INTERFACE ENCONTRADOS (Packs de UI e Avulsos):{RESET}")
        if sprites_ui:
            for idx, item in enumerate(sprites_ui, 1):
                sprite_nome = item['sprite']
                pagina = item['pagina']
                pack_nome = item['pack'].split('.')[0] if item['pack'] != "avulso" else "avulso"
                if item['pack'] == "avulso":
                    print(f"{CYAN}│{RESET}  [{idx:<2}] Sprite: {GREEN}{sprite_nome:<30}{RESET} (Arquivo avulso em {pagina})")
                else:
                    print(f"{CYAN}│{RESET}  [{idx:<2}] Sprite: {GREEN}{sprite_nome:<30}{RESET} (em {pagina} no {pack_nome})")
        else:
            print(f"{CYAN}│{RESET}  {YELLOW}Nenhum ícone 2D (Item/UI) encontrado.{RESET}")
        print(f"{CYAN}└───{RESET}")
            
        print(f"\n{CYAN}┌── {BOLD}🧱 SPRITES 3D / TILESETS ENCONTRADOS (Mundo):{RESET}")
        offset_3d = len(sprites_ui)
        if sprites_mundo:
            for idx, item in enumerate(sprites_mundo, 1):
                sprite_nome = item['sprite']
                detalhes = item['detalhes']
                print(f"{CYAN}│{RESET}  [{idx + offset_3d:<2}] Sprite: {CYAN}{sprite_nome}{RESET} ➔ {detalhes}")
        else:
            print(f"{CYAN}│{RESET}  {YELLOW}Nenhum sprite 3D (Mundo/Tileset) encontrado.{RESET}")
        print(f"{CYAN}└───{RESET}")


if __name__ == "__main__":
    main()
