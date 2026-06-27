# -*- coding: utf-8 -*-
"""
================================================================================
🎨 EXTRAIR SPRITES - LKS SUPERMOD PATCH
================================================================================
Módulo utilitário para extrair texturas e sprites de arquivos .pack do Project Zomboid.
Pode ser executado diretamente por agentes LLM/terminal ou importado pelo menu principal.
"""

import os
import sys
import struct
import io
import json
import re
import shutil
from pathlib import Path
from PIL import Image

# Cores do terminal para feedback em modo texto
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RED = "\033[31m"
GRAY = "\033[90m"

# Configurações de caminhos padrão
DIRETORIO_FERRAMENTAS = Path(__file__).resolve().parent
DIRETORIO_RAIZ = DIRETORIO_FERRAMENTAS.parent
DIRETORIO_UI_MOD = DIRETORIO_RAIZ / "common" / "media" / "ui"


def ler_string(fluxo: io.BytesIO) -> str | None:
    """
    Lê uma string precedida por seu tamanho de 4 bytes (little-endian uint) a partir de um fluxo binário.

    **Exemplo:**

    .. code-block:: python

        with open("arquivo.pack", "rb") as arquivo_binario:
            texto = ler_string(arquivo_binario)
    """
    bytes_tamanho = fluxo.read(4)
    if not bytes_tamanho or len(bytes_tamanho) < 4:
        return None
    tamanho = struct.unpack("<I", bytes_tamanho)[0]
    bytes_string = fluxo.read(tamanho)
    return bytes_string.decode('utf-8', errors='replace')


def ler_int(fluxo: io.BytesIO) -> int | None:
    """
    Lê um inteiro de 4 bytes (little-endian uint) a partir de um fluxo binário.

    **Exemplo:**

    .. code-block:: python

        with open("arquivo.pack", "rb") as arquivo_binario:
            numero = ler_int(arquivo_binario)
    """
    bytes_inteiro = fluxo.read(4)
    if not bytes_inteiro or len(bytes_inteiro) < 4:
        return None
    return struct.unpack("<I", bytes_inteiro)[0]


def sugerir_nome_arquivo(sprite_nome: str) -> str:
    """
    Consulta o dicionario_tilesets.json e gera um nome de arquivo amigável e limpo para o sprite.

    **Exemplo:**

    .. code-block:: python

        nome_saida = sugerir_nome_arquivo("appliances_refrigeration_01_0")
        print(nome_saida)  # Ex: Container_Fridge.png
    """
    try:
        caminho_json = DIRETORIO_FERRAMENTAS / "data" / "dicionario_tilesets.json"
        if caminho_json.exists():
            with open(caminho_json, "r", encoding="utf-8") as arquivo_json:
                dados = json.load(arquivo_json)
            
            for ts_nome, ts_dados in dados.get("tilesets", {}).items():
                itens = ts_dados.get("itens", {})
                if sprite_nome in itens:
                    item = itens[sprite_nome]
                    nome = item.get("nome", "").strip().replace(" ", "_")
                    grupo = item.get("grupo", "").strip().replace(" ", "_")
                    direcao = item.get("direcao", "").strip()
                    
                    partes = []
                    if nome:
                        partes.append(nome)
                    if grupo and grupo.lower() != nome.lower():
                        partes.append(grupo)
                    if direcao:
                        partes.append(direcao)
                    
                    if partes:
                        nome_sugerido = "_".join(partes)
                        nome_sugerido = re.sub(r"[^\w\-]", "", nome_sugerido)
                        return f"{nome_sugerido}.png"
    except Exception:
        pass
    return f"{sprite_nome}.png"


def obter_diretorio_jogo_agnostico() -> str:
    """
    Tenta localizar a pasta de instalação do Project Zomboid dinamicamente em locais comuns do sistema.

    **Exemplo:**

    .. code-block:: python

        pasta_jogo = obter_diretorio_jogo_agnostico()
    """
    downloads_usuario = Path(os.path.expanduser("~")) / "Downloads" / "ProjectZomboid"
    if downloads_usuario.exists():
        return str(downloads_usuario)

    caminhos_steam_comuns = [
        r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid",
        r"C:\Program Files\Steam\steamapps\common\ProjectZomboid",
        r"D:\SteamLibrary\steamapps\common\ProjectZomboid",
        r"D:\Steam\steamapps\common\ProjectZomboid",
        r"E:\SteamLibrary\steamapps\common\ProjectZomboid",
        r"E:\Steam\steamapps\common\ProjectZomboid",
        os.path.expanduser("~/.local/share/Steam/steamapps/common/ProjectZomboid")
    ]

    for caminho in caminhos_steam_comuns:
        caminho_path = Path(caminho)
        if caminho_path.exists():
            return str(caminho_path)
    return ""


def carregar_caminho_env() -> str | None:
    """
    Tenta carregar o caminho do jogo a partir do arquivo .env na raiz do projeto.

    **Exemplo:**

    .. code-block:: python

        caminho_env = carregar_caminho_env()
    """
    caminho_env = DIRETORIO_RAIZ / ".env"
    if caminho_env.exists():
        try:
            with open(caminho_env, "r", encoding="utf-8") as arquivo_env:
                for linha in arquivo_env:
                    linha = linha.strip()
                    if linha.startswith("PZ_GAME_DIR="):
                        caminho = linha.split("=", 1)[1].strip().strip('"').strip("'")
                        if os.path.exists(caminho):
                            return caminho
        except Exception:
            pass
    return None


def salvar_caminho_env(caminho: str) -> None:
    """
    Salva o caminho do jogo no arquivo .env na raiz do projeto para consistência.

    **Exemplo:**

    .. code-block:: python

        salvar_caminho_env("C:\\Steam\\ProjectZomboid")
    """
    caminho_env = DIRETORIO_RAIZ / ".env"
    try:
        linhas = []
        existente = False
        if caminho_env.exists():
            with open(caminho_env, "r", encoding="utf-8") as arquivo_env:
                for linha in arquivo_env:
                    if linha.strip().startswith("PZ_GAME_DIR="):
                        linhas.append(f"PZ_GAME_DIR={caminho}\n")
                        existente = True
                    else:
                        linhas.append(linha)
        if not existente:
            linhas.append(f"PZ_GAME_DIR={caminho}\n")
            
        with open(caminho_env, "w", encoding="utf-8") as arquivo_env:
            arquivo_env.writelines(linhas)
    except Exception:
        pass


def validar_e_salvar_caminho(caminho: str) -> bool:
    """
    Verifica se a pasta do jogo é válida (contém media/texturepacks) e a salva consistentemente no .env.

    **Exemplo:**

    .. code-block:: python

        valido = validar_e_salvar_caminho("C:\\ProjectZomboid")
    """
    if not caminho:
        return False
    caminho_path = Path(caminho)
    pasta_packs = caminho_path / "media" / "texturepacks"
    if caminho_path.exists() and pasta_packs.exists():
        caminho_salvo = carregar_caminho_env()
        if not caminho_salvo or os.path.normpath(caminho_salvo) != os.path.normpath(caminho):
            salvar_caminho_env(str(caminho_path.resolve()))
        return True
    return False


def obter_diretorio_jogo_grafico() -> str:
    """
    Abre um diálogo gráfico de seleção de pasta ou cai em fallback de input textual.

    **Exemplo:**

    .. code-block:: python

        pasta_jogo = obter_diretorio_jogo_grafico()
    """
    try:
        import tkinter as tk
        from tkinter import filedialog
        
        raiz_tk = tk.Tk()
        raiz_tk.withdraw()
        raiz_tk.attributes("-topmost", True)
        
        pasta_inicial = carregar_caminho_env() or obter_diretorio_jogo_agnostico() or "C:\\"
        print(f"{CYAN}[*] Abrindo explorador de pastas do sistema... Selecione a pasta do Project Zomboid.{RESET}")
        
        dir_selecionado = filedialog.askdirectory(
            title="Selecione a pasta de instalação do Project Zomboid",
            initialdir=pasta_inicial
        )
        raiz_tk.destroy()
        
        if dir_selecionado:
            dir_normalizado = os.path.abspath(dir_selecionado)
            if validar_e_salvar_caminho(dir_normalizado):
                return dir_normalizado
            else:
                print(f"{YELLOW}[!] A pasta selecionada não parece conter 'media/texturepacks'.{RESET}")
    except Exception:
        pass
        
    while True:
        caminho_digitado = input("Digite o caminho de instalação do Project Zomboid: ").strip()
        if not caminho_digitado:
            continue
        caminho_normalizado = os.path.abspath(caminho_digitado)
        if validar_e_salvar_caminho(caminho_normalizado):
            return caminho_normalizado
        print(f"{RED}[-] Caminho inválido. A pasta 'media/texturepacks' não foi encontrada. Tente novamente.{RESET}")


# Caminho do jogo padrão consolidado
DIRETORIO_JOGO_PADRAO = carregar_caminho_env() or obter_diretorio_jogo_agnostico() or r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"


def extrair_assets_do_jogo(
    pasta_jogo: str,
    mapeamento_alvos: dict[str, str],
    pasta_destino: str,
    silencioso: bool = False
) -> dict[str, str | None]:
    """
    Extrai sprites especificados de arquivos .pack e os salva na pasta_destino.

    Retorna um dicionário mapeando cada sprite de busca ao caminho final extraído ou None se falhou.

    **Exemplo:**

    .. code-block:: python

        mapeamento = {"container_fridge": "Container_Fridge.png"}
        resultados = extrair_assets_do_jogo("C:\\PZ", mapeamento, "common/media/ui")
    """
    pasta_packs = Path(pasta_jogo) / "media" / "texturepacks"
    if not pasta_packs.exists():
        if not silencioso:
            print(f"{RED}[-] ERRO: Pasta de texturepacks não encontrada em: {pasta_packs}{RESET}")
        return {sprite: None for sprite in mapeamento_alvos}

    os.makedirs(pasta_destino, exist_ok=True)
    encontrados = {}
    alvos_limpos = {k.lower(): (k, v) for k, v in mapeamento_alvos.items()}
    arquivos_pack = [arquivo for arquivo in os.listdir(pasta_packs) if arquivo.lower().endswith(".pack")]

    if not silencioso:
        print(f"{CYAN}[*] Iniciando extração a partir de {len(arquivos_pack)} arquivos .pack...{RESET}")

    for nome_pack in arquivos_pack:
        caminho_pack = pasta_packs / nome_pack
        try:
            with open(caminho_pack, "rb") as arquivo_binario:
                primeiros_bytes = arquivo_binario.read(4)
                e_pzpk = (primeiros_bytes == b"PZPK")
                
                if e_pzpk:
                    versao_pack = ler_int(arquivo_binario)
                    num_paginas = ler_int(arquivo_binario)
                else:
                    if not primeiros_bytes or len(primeiros_bytes) < 4:
                        continue
                    num_paginas = struct.unpack("<I", primeiros_bytes)[0]

                if num_paginas is None:
                    continue

                for indice_pagina in range(num_paginas):
                    if indice_pagina > 0 and not e_pzpk:
                        marcador = ler_int(arquivo_binario)
                        if marcador != 0xDEADBEEF:
                            break

                    nome_pagina = ler_string(arquivo_binario)
                    num_sprites = ler_int(arquivo_binario)
                    flag_pagina = ler_int(arquivo_binario)

                    dados_sprites = []
                    for _ in range(num_sprites):
                        nome_sprite = ler_string(arquivo_binario)
                        posicao_x = ler_int(arquivo_binario)
                        posicao_y = ler_int(arquivo_binario)
                        largura = ler_int(arquivo_binario)
                        altura = ler_int(arquivo_binario)
                        offset_x = ler_int(arquivo_binario)
                        offset_y = ler_int(arquivo_binario)
                        largura_original = ler_int(arquivo_binario)
                        altura_original = ler_int(arquivo_binario)

                        nome_sprite_limpo = nome_sprite.lower()
                        if nome_sprite_limpo in alvos_limpos:
                            dados_sprites.append({
                                "nome_original": nome_sprite,
                                "nome_limpo": nome_sprite_limpo,
                                "x": posicao_x,
                                "y": posicao_y,
                                "w": largura,
                                "h": altura
                            })

                    posicao_inicio_imagem = arquivo_binario.tell()
                    
                    if e_pzpk:
                        tamanho_total_png = ler_int(arquivo_binario)
                        if tamanho_total_png is None:
                            break
                        dados_imagem_png = arquivo_binario.read(tamanho_total_png)
                    else:
                        bloco_dados = bytearray()
                        tamanho_bloco = 4096
                        posicao_iend = -1
                        while True:
                            dados_lidos = arquivo_binario.read(tamanho_bloco)
                            if not dados_lidos:
                                break
                            bloco_dados.extend(dados_lidos)
                            posicao_iend = bloco_dados.find(b"IEND")
                            if posicao_iend != -1:
                                tamanho_total_png = posicao_iend + 8
                                dados_imagem_png = bytes(bloco_dados[:tamanho_total_png])
                                arquivo_binario.seek(posicao_inicio_imagem + tamanho_total_png)
                                break
                        if posicao_iend == -1:
                            break

                    if dados_sprites:
                        try:
                            imagem_atlas = Image.open(io.BytesIO(dados_imagem_png))
                            for sprite in dados_sprites:
                                nome_saida = alvos_limpos[sprite["nome_limpo"]][1]
                                caminho_saida = Path(pasta_destino) / nome_saida
                                
                                # Inteligência de Resolução: Se já existe um arquivo HD, não sobrescreve
                                if caminho_saida.exists():
                                    try:
                                        with Image.open(caminho_saida) as img_existente:
                                            if img_existente.width >= sprite["w"] and img_existente.height >= sprite["h"]:
                                                encontrados[sprite["nome_limpo"]] = str(caminho_saida.resolve())
                                                if not silencioso:
                                                    caminho_saida_rel = os.path.relpath(caminho_saida, DIRETORIO_RAIZ).replace('\\', '/')
                                                    print(f"{CYAN}  [-] Sprite '{sprite['nome_original']}' ignorado: Versão de igual/melhor qualidade já existente em ./{caminho_saida_rel}{RESET}")
                                                continue
                                    except Exception:
                                        pass
                                
                                caixa_corte = (
                                    sprite["x"],
                                    sprite["y"],
                                    sprite["x"] + sprite["w"],
                                    sprite["y"] + sprite["h"]
                                )
                                imagem_recortada = imagem_atlas.crop(caixa_corte)
                                imagem_recortada.save(caminho_saida, "PNG")
                                
                                encontrados[sprite["nome_limpo"]] = str(caminho_saida.resolve())
                                if not silencioso:
                                    caminho_saida_rel = os.path.relpath(caminho_saida, DIRETORIO_RAIZ).replace('\\', '/')
                                    sufixo_hd = " (Versão HD)" if "tiles2x" in nome_pack.lower() else ""
                                    print(f"{GREEN}  [+] Sprite extraído: {sprite['nome_original']} ➔ ./{caminho_saida_rel}{sufixo_hd} (de {nome_pagina} em {nome_pack}){RESET}")
                        except Exception as erro:
                            if not silencioso:
                                print(f"{RED}  [-] Erro ao processar recortes na página {nome_pagina}: {erro}{RESET}")
        except Exception as erro:
            if not silencioso:
                print(f"{RED}[-] Erro ao analisar o arquivo {nome_pack}: {erro}{RESET}")

    resultados = {}
    for original, final_nome in mapeamento_alvos.items():
        original_limpo = original.lower()
        if original_limpo in encontrados:
            resultados[original] = encontrados[original_limpo]
        else:
            resultados[original] = None
            if not silencioso:
                print(f"  {YELLOW}- {original} (Não encontrado nos packs){RESET}")

    return resultados


def main() -> None:
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Extrai sprites de texturas .pack do Project Zomboid."
    )
    parser.add_argument("--jogo", "-j", default=DIRETORIO_JOGO_PADRAO, help="Diretório de instalação do Project Zomboid")
    parser.add_argument("--sprite", "-s", action="append", required=True, help="Sprite a extrair no formato 'sprite_original' ou 'sprite_original:nome_saida.png'")
    parser.add_argument("--destino", "-d", default=str(DIRETORIO_UI_MOD), help="Diretório de destino para o PNG extraído")
    parser.add_argument("--json", action="store_true", help="Saída estrita em formato JSON (ideal para agentes LLM)")
    
    args = parser.parse_args()
    
    # Valida caminhos
    caminho_jogo = args.jogo
    if not Path(caminho_jogo).exists() or not (Path(caminho_jogo) / "media" / "texturepacks").exists():
        if args.json:
            print(json.dumps({"sucesso": False, "erro": "Diretório de instalação do Project Zomboid inválido."}))
            sys.exit(1)
        else:
            print(f"{RED}[-] ERRO: Diretório do jogo inválido.{RESET}")
            sys.exit(1)
            
    # Constrói o mapeamento
    mapeamento = {}
    for item in args.sprite:
        if ":" in item:
            original, saida = item.split(":", 1)
            original_limpo = re.sub(r"\.(png|jpg|tga|jpeg|gif)$", "", original.strip(), flags=re.IGNORECASE)
            mapeamento[original_limpo] = saida.strip()
        else:
            original_limpo = re.sub(r"\.(png|jpg|tga|jpeg|gif)$", "", item.strip(), flags=re.IGNORECASE)
            mapeamento[original_limpo] = sugerir_nome_arquivo(original_limpo)
            
    # Executa a extração
    resultados = extrair_assets_do_jogo(caminho_jogo, mapeamento, args.destino, silencioso=args.json)
    
    if args.json:
        # Imprime saída estrita JSON no stdout
        sucesso_geral = any(caminho is not None for caminho in resultados.values())
        print(json.dumps({
            "sucesso": sucesso_geral,
            "resultados": resultados
        }, indent=2))
    else:
        # Imprime relatório textual amigável
        sucesso_geral = any(caminho is not None for caminho in resultados.values())
        if sucesso_geral:
            print(f"\n{GREEN}[+] Extração concluída com sucesso!{RESET}")
        else:
            print(f"\n{RED}[-] Nenhuma textura pôde ser extraída.{RESET}")


if __name__ == "__main__":
    # Garante suporte UTF-8 no terminal Windows
    if sys.version_info >= (3, 7):
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    if os.name == 'nt':
        os.system('')
        
    main()
