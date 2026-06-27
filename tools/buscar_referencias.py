# -*- coding: utf-8 -*-
"""
================================================================================
🔍 BUSCA UNIFICADA DE REFERÊNCIAS - LKS SUPERMOD PATCH
================================================================================
Módulo para buscar referências de assets 2D (UI/Itens) em arquivos .pack do jogo
e assets 3D (Mundo) no dicionário de tilesets de metadados.
"""

import os
import sys
import json
import re
import struct
import shutil
from pathlib import Path

# Cores do terminal
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RED = "\033[31m"
GRAY = "\033[90m"

try:
    from tools.extrair_sprites import (
        ler_string,
        ler_int,
        sugerir_nome_arquivo,
        extrair_assets_do_jogo,
        DIRETORIO_UI_MOD,
        DIRETORIO_FERRAMENTAS,
        DIRETORIO_RAIZ,
        DIRETORIO_JOGO_PADRAO,
        obter_diretorio_jogo_grafico
    )
except ImportError:
    from extrair_sprites import (
        ler_string,
        ler_int,
        sugerir_nome_arquivo,
        extrair_assets_do_jogo,
        DIRETORIO_UI_MOD,
        DIRETORIO_FERRAMENTAS,
        DIRETORIO_RAIZ,
        DIRETORIO_JOGO_PADRAO,
        obter_diretorio_jogo_grafico
    )


def buscar_referencias_assets(
    termo_busca: str,
    pasta_jogo: str,
    silencioso: bool = False
) -> tuple[list[dict], list[dict]]:
    """
    Busca referências de assets 2D nos packs de UI e 3D no JSON de metadados do mod.

    Retorna uma tupla contendo duas listas de dicionários: (sprites_ui, sprites_mundo).

    **Exemplo:**

    .. code-block:: python

        sprites_ui, sprites_mundo = buscar_referencias_assets("Fridge", "C:\\ProjectZomboid")
    """
    termo = termo_busca.lower().strip()
    if not termo:
        if not silencioso:
            print(f"{RED}[-] Erro: O termo de busca não pode ser vazio.{RESET}")
        return [], []
        
    if not silencioso:
        print(f"\n{CYAN}[*] Buscando referências de assets para: '{termo_busca}'...{RESET}")
    
    # 1. Busca no JSON de metadados (dicionario_tilesets.json) para sprites do mundo 3D
    sprites_mundo = []
    caminho_json = DIRETORIO_FERRAMENTAS / "data" / "dicionario_tilesets.json"
    if caminho_json.exists():
        try:
            with open(caminho_json, "r", encoding="utf-8") as arquivo_json:
                dados = json.load(arquivo_json)
            
            for ts_nome, ts_dados in dados.get("tilesets", {}).items():
                for sprite_id, item in ts_dados.get("itens", {}).items():
                    nome_completo = f"{item.get('nome', '')} {item.get('grupo', '')} {sprite_id}".lower()
                    if termo in nome_completo:
                        sprites_mundo.append({
                            "sprite": sprite_id,
                            "detalhes": item.get("descricao_completa", f"{item.get('nome')} - Facing: {item.get('direcao')}")
                        })
        except Exception:
            pass
            
    # 2. Busca nos packs de UI (UI.pack e UI2.pack) para ícones 2D e itens
    sprites_ui = []
    pasta_packs = Path(pasta_jogo) / "media" / "texturepacks"
    if pasta_packs.exists():
        for pack_nome in ["UI.pack", "UI2.pack"]:
            caminho_pack = pasta_packs / pack_nome
            if caminho_pack.exists():
                try:
                    with open(caminho_pack, "rb") as arquivo_binario:
                        primeiros_bytes = arquivo_binario.read(4)
                        e_pzpk = (primeiros_bytes == b"PZPK")
                        
                        if e_pzpk:
                            versao = ler_int(arquivo_binario)
                            num_paginas = ler_int(arquivo_binario)
                        else:
                            if len(primeiros_bytes) < 4:
                                continue
                            num_paginas = struct.unpack("<I", primeiros_bytes)[0]
                            
                        if num_paginas is None:
                            continue
                            
                        for pag_idx in range(num_paginas):
                            if pag_idx > 0 and not e_pzpk:
                                arquivo_binario.seek(arquivo_binario.tell() + 4) # Pula o DEADBEEF
                            nome_pagina = ler_string(arquivo_binario)
                            num_sprites = ler_int(arquivo_binario)
                            arquivo_binario.seek(arquivo_binario.tell() + 4) # Pula flag_pagina
                            
                            dados_sprites_pag = []
                            for _ in range(num_sprites):
                                nome_sprite = ler_string(arquivo_binario)
                                arquivo_binario.seek(arquivo_binario.tell() + 32) # Pula dados dimensionais
                                
                                if termo in nome_sprite.lower():
                                    dados_sprites_pag.append(nome_sprite)
                                    
                            for sprite_nome in dados_sprites_pag:
                                sprites_ui.append({
                                    "sprite": sprite_nome,
                                    "pack": pack_nome,
                                    "pagina": nome_pagina,
                                    "caminho_avulso": None
                                })
                                
                            # Pula dados de imagem
                            if e_pzpk:
                                tam_png = ler_int(arquivo_binario)
                                if tam_png:
                                    arquivo_binario.seek(arquivo_binario.tell() + tam_png)
                            else:
                                bloco_dados = bytearray()
                                while True:
                                    dados_lidos = arquivo_binario.read(4096)
                                    if not dados_lidos:
                                        break
                                    bloco_dados.extend(dados_lidos)
                                    idx_iend = bloco_dados.find(b"IEND")
                                    if idx_iend != -1:
                                        excesso = len(bloco_dados) - (idx_iend + 8)
                                        arquivo_binario.seek(arquivo_binario.tell() - excesso)
                                        break
                except Exception:
                    pass

    # 2.2 Busca por arquivos avulsos de imagem na pasta media/ui/ do jogo
    pasta_ui_jogo = Path(pasta_jogo) / "media" / "ui"
    if pasta_ui_jogo.exists():
        for arquivo in pasta_ui_jogo.iterdir():
            if arquivo.is_file() and arquivo.suffix.lower() in ('.png', '.jpg', '.tga'):
                if termo in arquivo.name.lower():
                    if not any(item['sprite'].lower() == arquivo.name.lower() for item in sprites_ui):
                        sprites_ui.append({
                            "sprite": arquivo.name,
                            "pack": "avulso",
                            "pagina": "Diretório media/ui",
                            "caminho_avulso": str(arquivo.resolve())
                        })

    return sprites_ui, sprites_mundo


def main() -> None:
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Busca referências de assets de UI (2D) e mundo (3D) no Project Zomboid."
    )
    parser.add_argument("--termo", "-t", required=True, help="Termo de busca (ex: Fridge, Generator)")
    parser.add_argument("--jogo", "-j", default=DIRETORIO_JOGO_PADRAO, help="Diretório do jogo")
    parser.add_argument("--json", action="store_true", help="Saída estruturada em JSON")
    
    args = parser.parse_args()
    
    caminho_jogo = args.jogo
    if not Path(caminho_jogo).exists() or not (Path(caminho_jogo) / "media" / "texturepacks").exists():
        if args.json:
            print(json.dumps({"sucesso": False, "erro": "Diretório do jogo inválido."}))
            sys.exit(1)
        else:
            print(f"{RED}[-] ERRO: Diretório do jogo inválido.{RESET}")
            sys.exit(1)
            
    sprites_ui, sprites_mundo = buscar_referencias_assets(args.termo, caminho_jogo, silencioso=args.json)
    
    if args.json:
        print(json.dumps({
            "sucesso": True,
            "termo": args.termo,
            "ui_sprites": sprites_ui,
            "mundo_sprites": sprites_mundo
        }, indent=2))
        sys.exit(0)
        
    # Imprime saída visual humana
    print(f"\n{CYAN}┌── {BOLD}🔍 ÍCONES 2D / INTERFACE ENCONTRADOS (Packs de UI e Avulsos):{RESET}")
    if sprites_ui:
        for indice, item in enumerate(sprites_ui, 1):
            sprite_nome = item['sprite']
            pagina = item['pagina']
            pack_nome = item['pack'].split('.')[0] if item['pack'] != "avulso" else "avulso"
            
            if item['pack'] == "avulso":
                print(f"{CYAN}│{RESET}  [{indice:<2}] Sprite: {GREEN}{sprite_nome:<30}{RESET} (Arquivo avulso em {pagina})")
            else:
                print(f"{CYAN}│{RESET}  [{indice:<2}] Sprite: {GREEN}{sprite_nome:<30}{RESET} (em {pagina} no {pack_nome})")
    else:
        print(f"{CYAN}│{RESET}  {YELLOW}Nenhum ícone 2D (Item/UI) encontrado.{RESET}")
    print(f"{CYAN}└───{RESET}")
        
    print(f"\n{CYAN}┌── {BOLD}🧱 SPRITES 3D / TILESETS ENCONTRADOS (Mundo):{RESET}")
    offset_3d = len(sprites_ui)
    if sprites_mundo:
        for indice, item in enumerate(sprites_mundo, 1):
            sprite_nome = item['sprite']
            detalhes = item['detalhes']
            print(f"{CYAN}│{RESET}  [{indice + offset_3d:<2}] Sprite: {CYAN}{sprite_nome}{RESET} ➔ {detalhes}")
    else:
        print(f"{CYAN}│{RESET}  {YELLOW}Nenhum sprite 3D (Mundo/Tileset) encontrado.{RESET}")
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
                        caminho_destino = Path(DIRETORIO_UI_MOD) / sprite_nome
                        os.makedirs(DIRETORIO_UI_MOD, exist_ok=True)
                        shutil.copy2(caminho_origem, caminho_destino)
                        caminho_destino_rel = os.path.relpath(caminho_destino, DIRETORIO_RAIZ).replace('\\', '/')
                        print(f"{GREEN}  [+] Arquivo avulso copiado com sucesso: {caminho_origem.name} ➔ ./{caminho_destino_rel}{RESET}")
                    else:
                        nome_saida = sugerir_nome_arquivo(sprite_nome)
                        print(f"\n[*] Extraindo '{sprite_nome}'...")
                        mapeamento = {sprite_nome: nome_saida}
                        extrair_assets_do_jogo(caminho_jogo, mapeamento, DIRETORIO_UI_MOD)
        except ValueError:
            print(f"{RED}[-] Entrada inválida (use apenas números separados por vírgula).{RESET}")
        except Exception as erro:
            print(f"{RED}[-] Erro na seleção/cópia: {erro}{RESET}")


if __name__ == "__main__":
    if sys.version_info >= (3, 7):
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    if os.name == 'nt':
        os.system('')
        
    main()
