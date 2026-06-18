# -*- coding: utf-8 -*-
"""
================================================================================
🎨 TOOLS ASSETS - LKS SUPERMOD PATCH
================================================================================
Autor: LKS FERREIRA
Versão: 1.4 (Project Zomboid Build 42)
Data da Última Modificação: 18/06/2026

PROPÓSITO:
Ferramenta utilitária de linha de comando (CLI) e menu interativo para o mod.
Suas funções principais englobam:
1. Extração automatizada de texturas/sprites de arquivos .pack do jogo.
2. Inspeção de metadados de imagem PNG (resolução, formato, modo, canais e
   profundidade de bits), identificando e alertando sobre texturas de 16 bits.
3. Otimização de imagens PNG de 16 bits para 8 bits para prevenir travamentos.
4. Auditoria estrutural de imagens órfãs na pasta 'media/ui' do mod.
5. Busca de referências e mapeamento de assets 2D/3D no jogo e nos metadados.

COMO USAR:
- Modo Interativo (Menu):
    python tools/LKS_Tools.py
- Extração de Sprite (CLI):
    python tools/LKS_Tools.py <Nome_Sprite_Original>
    python tools/LKS_Tools.py -e <Nome_Sprite_Original>
- Busca Unificada de Referências:
    python tools/LKS_Tools.py -b <Termo_de_Busca>
    (na seleção interativa, aceita múltiplos números separados por vírgula,
    ponto-e-vírgula ou espaço — ex: "1, 3, 5" ou "1;3;5")
- Inspeção de Imagem:
    python tools/LKS_Tools.py -i <Caminho_do_PNG>
- Otimização para 8-bit:
    python tools/LKS_Tools.py -c <PNG_Original> [-o <PNG_Saida>]
- Auditoria de Imagens Órfãs:
    python tools/LKS_Tools.py -a
================================================================================
"""

import os
import sys
import struct
import io
import argparse
import shutil
import re
from pathlib import Path
from PIL import Image

# Configurações de caminhos padrão
DIRETORIO_FERRAMENTAS = Path(__file__).resolve().parent
DIRETORIO_RAIZ = DIRETORIO_FERRAMENTAS.parent
DIRETORIO_UI_MOD = DIRETORIO_RAIZ / "common" / "media" / "ui"

def sugerir_nome_arquivo(sprite_nome):
    """Consulta o dicionario_tilesets.json e gera um nome de arquivo amigável e limpo."""
    try:
        caminho_json = DIRETORIO_FERRAMENTAS / "dicionario_tilesets.json"
        if caminho_json.exists():
            import json
            with open(caminho_json, "r", encoding="utf-8") as f:
                dados = json.load(f)
            
            # Procura o sprite nos itens de cada tileset
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
                        # Une os termos e limpa caracteres inválidos para arquivos
                        nome_sugerido = "_".join(partes)
                        nome_sugerido = re.sub(r"[^\w\-]", "", nome_sugerido)
                        return f"{nome_sugerido}.png"
            
            # Se passou por todos os tilesets e não achou
            print(f"\n{CYAN}[INFO] Sprite '{sprite_nome}' não está catalogado na referência rápida do mod. Usando nome original como fallback.{RESET}")
    except Exception:
        pass
    return f"{sprite_nome}.png"

def obter_diretorio_jogo_agnostico():
    """Tenta localizar a pasta de instalação do Project Zomboid dinamicamente em locais comuns do sistema."""
    # 1. Tenta a pasta de downloads do usuário do sistema operacional atual
    downloads_usuario = Path(os.path.expanduser("~")) / "Downloads" / "ProjectZomboid"
    if downloads_usuario.exists():
        return str(downloads_usuario)

    # 2. Pastas padrão comuns da biblioteca Steam no Windows e Linux
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
        p = Path(caminho)
        if p.exists():
            return str(p)
    return ""

def carregar_caminho_env():
    """Tenta carregar o caminho do jogo a partir do arquivo .env na raiz do projeto."""
    caminho_env = DIRETORIO_RAIZ / ".env"
    if caminho_env.exists():
        try:
            with open(caminho_env, "r", encoding="utf-8") as f:
                for linha in f:
                    linha = linha.strip()
                    if linha.startswith("PZ_GAME_DIR="):
                        caminho = linha.split("=", 1)[1].strip().strip('"').strip("'")
                        if os.path.exists(caminho):
                            return caminho
        except Exception:
            pass
    return None

def salvar_caminho_env(caminho):
    """Salva o caminho do jogo no arquivo .env na raiz do projeto para consistência."""
    caminho_env = DIRETORIO_RAIZ / ".env"
    try:
        linhas = []
        existente = False
        if caminho_env.exists():
            with open(caminho_env, "r", encoding="utf-8") as f:
                for l in f:
                    if l.strip().startswith("PZ_GAME_DIR="):
                        linhas.append(f"PZ_GAME_DIR={caminho}\n")
                        existente = True
                    else:
                        linhas.append(l)
        if not existente:
            linhas.append(f"PZ_GAME_DIR={caminho}\n")
            
        with open(caminho_env, "w", encoding="utf-8") as f:
            f.writelines(linhas)
        print(f"{GREEN}[+] Caminho do jogo salvo com sucesso em {caminho_env.name}!{RESET}")
    except Exception as e:
        print(f"{YELLOW}[!] Aviso: Não foi possível salvar o caminho no .env: {e}{RESET}")

def validar_e_salvar_caminho(caminho):
    """Verifica se a pasta do jogo é válida e a salva consistentemente no .env."""
    if not caminho:
        return False
    p = Path(caminho)
    pasta_packs = p / "media" / "texturepacks"
    if p.exists() and pasta_packs.exists():
        caminho_salvo = carregar_caminho_env()
        if not caminho_salvo or os.path.normpath(caminho_salvo) != os.path.normpath(caminho):
            salvar_caminho_env(str(p.resolve()))
        return True
    return False

def obter_diretorio_jogo_grafico():
    """Abre um diálogo gráfico de seleção de pasta para evitar erros de digitação (barras, etc.)."""
    try:
        import tkinter as tk
        from tkinter import filedialog
        
        # Cria uma janela oculta do Tkinter
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        
        # Define pasta inicial padrão
        pasta_inicial = carregar_caminho_env() or obter_diretorio_jogo_agnostico() or "C:\\"
        print(f"{CYAN}[*] Abrindo explorador de pastas do sistema... Selecione a pasta do Project Zomboid.{RESET}")
        
        dir_selecionado = filedialog.askdirectory(
            title="Selecione a pasta de instalação do Project Zomboid",
            initialdir=pasta_inicial
        )
        root.destroy()
        
        if dir_selecionado:
            dir_normalizado = os.path.abspath(dir_selecionado)
            if validar_e_salvar_caminho(dir_normalizado):
                return dir_normalizado
            else:
                print(f"{YELLOW}[!] Aviso: A pasta selecionada '{dir_normalizado}' não parece ser uma instalação válida (falta 'media/texturepacks').{RESET}")
    except Exception as e:
        print(f"{YELLOW}[!] Aviso: Interface gráfica indisponível ({e}). Digite o caminho manualmente.{RESET}")
        
    # Fallback de terminal de texto caso o Tkinter falhe ou o usuário queira digitar
    while True:
        caminho_digitado = input(f"Digite o caminho de instalação do Project Zomboid: ").strip()
        if not caminho_digitado:
            continue
        caminho_normalizado = os.path.abspath(caminho_digitado)
        if validar_e_salvar_caminho(caminho_normalizado):
            return caminho_normalizado
        print(f"{RED}[-] Caminho inválido (pasta 'media/texturepacks' não encontrada). Tente novamente.{RESET}")

# Caminho de instalação dinâmico e consistente carregado do .env ou de locais comuns
DIRETORIO_JOGO_PADRAO = carregar_caminho_env() or obter_diretorio_jogo_agnostico() or r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"

# Garante que o console do Windows aceite codificação UTF-8
if sys.version_info >= (3, 7):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

# Ativa suporte a cores ANSI no Windows
if os.name == 'nt':
    os.system('')

# Cores do terminal
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RED = "\033[31m"
GRAY = "\033[90m"

# ============================================================================
# 📁 MÓDULO 1: LEITURA E EXTRAÇÃO DE ARQUIVOS .PACK
# ============================================================================

def ler_string(fluxo):
    """Lê uma string precedida por seu tamanho de 4 bytes (little-endian uint)."""
    bytes_tamanho = fluxo.read(4)
    if not bytes_tamanho or len(bytes_tamanho) < 4:
        return None
    tamanho = struct.unpack("<I", bytes_tamanho)[0]
    bytes_string = fluxo.read(tamanho)
    return bytes_string.decode('utf-8', errors='replace')

def ler_int(fluxo):
    """Lê um inteiro de 4 bytes (little-endian uint)."""
    bytes_inteiro = fluxo.read(4)
    if not bytes_inteiro or len(bytes_inteiro) < 4:
        return None
    return struct.unpack("<I", bytes_inteiro)[0]

def extrair_assets_do_jogo(pasta_jogo, mapeamento_alvos, pasta_destino):
    """Extrai sprites selecionados de arquivos .pack da instalação do jogo."""
    pasta_packs = Path(pasta_jogo) / "media" / "texturepacks"
    if not pasta_packs.exists():
        print(f"{RED}[-] ERRO: Pasta de texturepacks do jogo não encontrada em: {pasta_packs}{RESET}")
        return False

    os.makedirs(pasta_destino, exist_ok=True)
    copiados = 0
    encontrados = {}

    # Normaliza as chaves de busca para minúsculas
    alvos_limpos = {k.lower(): (k, v) for k, v in mapeamento_alvos.items()}
    arquivos_pack = [arq for arq in os.listdir(pasta_packs) if arq.lower().endswith(".pack")]

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

                    # Coleta metadados de sprites
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
                                
                                # Inteligência de Resolução: Se já existe um arquivo HD, não sobrescreve com SD
                                if caminho_saida.exists():
                                    try:
                                        with Image.open(caminho_saida) as img_existente:
                                            if img_existente.width >= sprite["w"] and img_existente.height >= sprite["h"]:
                                                # O arquivo existente já é melhor ou igual em qualidade
                                                caminho_saida_rel = os.path.relpath(caminho_saida, DIRETORIO_RAIZ).replace('\\', '/')
                                                print(f"{CYAN}  [-] Sprite '{sprite['nome_original']}' ignorado: Versão de igual/melhor qualidade já existente em ./{caminho_saida_rel}{RESET}")
                                                encontrados[sprite["nome_limpo"]] = True
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
                                
                                caminho_saida_rel = os.path.relpath(caminho_saida, DIRETORIO_RAIZ).replace('\\', '/')
                                sufixo_hd = " (Versão HD)" if "tiles2x" in nome_pack.lower() else ""
                                print(f"{GREEN}  [+] Sprite extraído: {sprite['nome_original']} ➔ ./{caminho_saida_rel}{sufixo_hd} (de {nome_pagina} em {nome_pack}){RESET}")
                                encontrados[sprite["nome_limpo"]] = True
                        except Exception as e:
                            print(f"{RED}  [-] Erro ao processar recortes com Pillow na página {nome_pagina}: {e}{RESET}")
        except Exception as e:
            print(f"{RED}[-] Erro ao analisar o arquivo {nome_pack}: {e}{RESET}")

    total_unicos = len(encontrados)
    
    # Detecção e avisos em vermelho de sprites inválidos/não localizados nos packs
    nao_encontrados = [orig for orig, destino in mapeamento_alvos.items() if orig.lower() not in encontrados]
    if nao_encontrados:
        print(f"\n{RED}[!] AVISO: Os seguintes sprites não foram encontrados em nenhum arquivo .pack:{RESET}")
        for sprite_ausente in nao_encontrados:
            print(f"  {YELLOW}- {sprite_ausente} (Verifique a grafia ou o nome do tileset){RESET}")
            
    print(f"\n{GREEN}[*] Extração finalizada! Total importado: {total_unicos}/{len(mapeamento_alvos)} assets.{RESET}")
    return total_unicos > 0

# ============================================================================
# 🔍 MÓDULO 2: INSPEÇÃO DE PROPRIEDADES DE IMAGEM
# ============================================================================

def obter_profundidade_bits_png_raw(caminho_arquivo):
    """Lê os metadados do cabeçalho IHDR do PNG para obter a profundidade por canal."""
    try:
        with open(caminho_arquivo, 'rb') as f:
            header = f.read(30)
            if len(header) < 26 or header[:8] != b'\x89PNG\r\n\x1a\n' or header[12:16] != b'IHDR':
                return None
            return header[24] # Posição do bit depth no cabeçalho IHDR
    except Exception:
        return None

def inspecionar_propriedades_imagem(caminho_arquivo, indice=1):
    """Exibe e valida as propriedades de cor, bit depth e canais de uma imagem."""
    caminho = Path(caminho_arquivo)
    if not caminho.exists():
        print(f"{RED}[-] Arquivo não encontrado: {caminho}{RESET}")
        return
        
    tamanho_formatado = f"{caminho.stat().st_size / 1024:.2f} KB"
    
    try:
        with Image.open(caminho) as img:
            dimensoes = f"{img.width}x{img.height} pixels"
            formato = img.format
            modo = img.mode
            
            # Detecção de canais alpha
            tem_alpha = "Sim" if (img.mode in ('RGBA', 'LA', 'PA') or (img.mode == 'P' and 'transparency' in img.info)) else "Não"
            
            # Detecção de bits por canal (bpc)
            bpc_raw = obter_profundidade_bits_png_raw(caminho) if formato == 'PNG' else None
            is_16_bit = (bpc_raw == 16 or '16' in img.mode or img.mode in ('I', 'F'))
            
            bpc_str = f"{bpc_raw} bits/canal" if bpc_raw else f"{img.mode} (bpc baseado no modo)"
            
            print(f"{CYAN}┌── {BOLD}Imagem #{indice}: {caminho.name}{RESET}")
            print(f"{CYAN}│{RESET}  📍 {BOLD}Caminho:{RESET} {caminho}")
            print(f"{CYAN}│{RESET}  💾 {BOLD}Tamanho:{RESET} {tamanho_formatado}")
            print(f"{CYAN}│{RESET}  📐 {BOLD}Dimensões:{RESET} {dimensoes}")
            print(f"{CYAN}│{RESET}  ⚙️  {BOLD}Formato:{RESET} {formato}")
            print(f"{CYAN}│{RESET}  🎨 {BOLD}Modo de Cor:{RESET} {modo}")
            
            if is_16_bit:
                print(f"{CYAN}│{RESET}  📊 {BOLD}Profundidade:{RESET} {RED}{bpc_str} (Alta faixa dinâmica - 16-bit! Pode quebrar o jogo!){RESET}")
                print(f"{CYAN}│{RESET}  ⚠️  {YELLOW}{BOLD}Aviso:{RESET} {YELLOW}Textura em 16-bit detectada. Converta para 8-bit para evitar travamentos no PZ.{RESET}")
            else:
                print(f"{CYAN}│{RESET}  📊 {BOLD}Profundidade:{RESET} {GREEN}{bpc_str} (8-bit seguro para o PZ){RESET}")
                
            print(f"{CYAN}│{RESET}  🌈 {BOLD}Canal Alpha?:{RESET} {GREEN if tem_alpha == 'Sim' else RED}{tem_alpha}{RESET}")
            print(f"{CYAN}└───{RESET}\n")
    except Exception as e:
        print(f"{RED}[-] Erro ao ler a imagem {caminho.name}: {e}{RESET}\n")

# ============================================================================
# ⚙️ MÓDULO 3: PROCESSAMENTO E OTIMIZAÇÃO (CONVERSÃO DE BITS / 8-BIT)
# ============================================================================

def calcular_dimensoes(
    largura_original: int,
    altura_original: int,
    redimensionar_str: str
) -> tuple[int, int]:
    """
    Calcula as novas dimensões de uma imagem com base em uma string de configuração.

    Suporta fatores de escala (ex: ``2x``, ``0.5x``), porcentagens (ex: ``50%``, ``200%``),
    largura fixa (ex: ``256``) ou dimensões exatas (ex: ``512x512``).

    **Exemplo:**

    .. code-block:: python

        nova_largura, nova_altura = calcular_dimensoes(100, 100, "2x")
        print(nova_largura, nova_altura)  # Output: 200, 200
    """
    parametro = redimensionar_str.strip().lower()
    if parametro.endswith("x"):
        fator = float(parametro[:-1])
        return max(1, int(largura_original * fator)), max(1, int(altura_original * fator))
    elif parametro.endswith("%"):
        fator = float(parametro[:-1]) / 100.0
        return max(1, int(largura_original * fator)), max(1, int(altura_original * fator))
    elif "x" in parametro:
        largura_str, altura_str = parametro.split("x", 1)
        return max(1, int(largura_str)), max(1, int(altura_str))
    else:
        nova_largura = int(parametro)
        proporcao = nova_largura / largura_original
        return nova_largura, max(1, int(altura_original * proporcao))

def converter_imagem_para_svg_blocos(
    imagem_pil: Image.Image,
    largura_alvo: int | None = None,
    altura_alvo: int | None = None,
    largura_visualizacao: int | None = None,
    altura_visualizacao: int | None = None
) -> str:
    """
    Vetoriza uma imagem convertendo pixels em blocos retangulares de SVG otimizados.

    Preserva a nitidez de pixel art através do atributo crispEdges.

    **Exemplo:**

    .. code-block:: python

        conteudo_svg = converter_imagem_para_svg_blocos(imagem)
    """
    imagem_rgba = imagem_pil.convert("RGBA")
    largura, altura = imagem_rgba.size
    pixels = imagem_rgba.load()

    svg_largura = largura_alvo if largura_alvo is not None else largura
    svg_altura = altura_alvo if altura_alvo is not None else altura
    visualizacao_largura = largura_visualizacao if largura_visualizacao is not None else largura
    visualizacao_altura = altura_visualizacao if altura_visualizacao is not None else altura

    partes_svg = [
        '<?xml version="1.0" encoding="UTF-8"?>\n',
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{svg_largura}" height="{svg_altura}" viewBox="0 0 {visualizacao_largura} {visualizacao_altura}" shape-rendering="crispEdges">\n'
    ]

    for y in range(altura):
        x = 0
        while x < largura:
            vermelho, verde, azul, alpha = pixels[x, y]
            inicio_x = x
            x += 1

            while x < largura and pixels[x, y] == (vermelho, verde, azul, alpha):
                x += 1

            comprimento = x - inicio_x

            if alpha == 0:
                continue

            cor_hex = f"#{vermelho:02x}{verde:02x}{azul:02x}"
            opacidade = alpha / 255.0

            if opacidade >= 0.999:
                partes_svg.append(
                    f'<rect x="{inicio_x}" y="{y}" width="{comprimento}" height="1" fill="{cor_hex}" />\n'
                )
            else:
                partes_svg.append(
                    f'<rect x="{inicio_x}" y="{y}" width="{comprimento}" height="1" fill="{cor_hex}" fill-opacity="{opacidade:.6f}" />\n'
                )

    partes_svg.append("</svg>\n")
    return "".join(partes_svg)

def hex_para_rgb(hex_str: str) -> tuple[int, int, int] | None:
    """Converte uma string hexadecimal de cor para uma tupla RGB."""
    hex_limpo = hex_str.strip().lower().replace("#", "")
    if len(hex_limpo) == 3:
        hex_limpo = "".join([char * 2 for char in hex_limpo])
    if len(hex_limpo) == 6:
        try:
            return int(hex_limpo[0:2], 16), int(hex_limpo[2:4], 16), int(hex_limpo[4:6], 16)
        except ValueError:
            return None
    return None

def cores_sao_semelhantes(cor1_rgb: tuple[int, int, int], cor2_rgb: tuple[int, int, int], tolerancia: float) -> bool:
    """Verifica se a distância euclidiana entre duas cores RGB está dentro da tolerância."""
    r1, g1, b1 = cor1_rgb
    r2, g2, b2 = cor2_rgb
    return ((r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2) ** 0.5 <= tolerancia

def remover_fundo_svg(caminho_entrada: Path, caminho_saida: Path) -> bool:
    """
    Analisa um arquivo SVG, detecta a cor de fundo mais provável e a remove do XML.
    """
    if not caminho_entrada.exists():
        print(f"{RED}[-] Arquivo SVG de entrada não encontrado: {caminho_entrada}{RESET}")
        return False

    try:
        import xml.etree.ElementTree as ET
        
        # Registra o namespace para evitar prefixos ns0: nos elementos salvos
        ET.register_namespace('', 'http://www.w3.org/2000/svg')
        
        arvore = ET.parse(caminho_entrada)
        raiz = arvore.getroot()
        
        largura = 0
        altura = 0
        
        viewbox_str = raiz.get('viewBox')
        if viewbox_str:
            partes = viewbox_str.split()
            if len(partes) == 4:
                largura = int(float(partes[2]))
                altura = int(float(partes[3]))
        
        if largura == 0 or altura == 0:
            largura_attr = raiz.get('width')
            altura_attr = raiz.get('height')
            if largura_attr and altura_attr:
                try:
                    largura = int(float(largura_attr))
                    altura = int(float(altura_attr))
                except ValueError:
                    pass
                    
        if largura == 0:
            largura = 1000
        if altura == 0:
            altura = 1000
            
        frequencias_cores = {}
        retangulos = []
        
        # Encontra todas as tags <rect> (considerando namespaces)
        tags_rect = raiz.findall('.//{http://www.w3.org/2000/svg}rect')
        if not tags_rect:
            tags_rect = raiz.findall('.//rect')
            
        for rect in tags_rect:
            x = int(float(rect.get('x', 0)))
            y = int(float(rect.get('y', 0)))
            w = int(float(rect.get('width', 0)))
            h = int(float(rect.get('height', 0)))
            cor = rect.get('fill', '').lower().strip()
            
            if not cor or cor == 'none':
                continue
                
            retangulos.append((rect, x, y, w, h, cor))
            
        if not retangulos:
            print(f"{YELLOW}[!] Nenhum retângulo colorido foi encontrado no arquivo SVG.{RESET}")
            return False
            
        # 1. Verifica se há um único retângulo gigante cobrindo todo o viewBox
        retangulo_fundo = None
        for rect, x, y, w, h, cor in retangulos:
            if x == 0 and y == 0 and w >= largura and h >= altura:
                retangulo_fundo = (rect, cor)
                break
                
        # 2. Amostra as bordas para descobrir a frequência das cores nas margens
        bordas_cores = {}
        for rect, x, y, w, h, cor in retangulos:
            toca_borda = (x == 0 or y == 0 or (x + w) >= largura or (y + h) >= altura)
            if toca_borda:
                comprimento = w if (y == 0 or (y + h) >= altura) else h
                bordas_cores[cor] = bordas_cores.get(cor, 0) + comprimento

        # Ordena as cores encontradas na borda por peso/frequência
        cores_ordenadas = sorted(bordas_cores.items(), key=lambda item: item[1], reverse=True)
        
        # Constrói o menu interativo de seleção de cor
        print(f"\n{CYAN}{BOLD}🎨 Detecção de fundo no SVG:{RESET}")
        opcoes = []
        
        if retangulo_fundo:
            cor_ret = retangulo_fundo[1]
            print(f"  {CYAN}[1]{RESET} {cor_ret} (Retângulo de fundo gigante explícito)")
            opcoes.append(cor_ret)
            
        for cor, peso in cores_ordenadas:
            # Evita duplicar se já adicionou como retângulo gigante
            if cor in opcoes:
                continue
            percentual = (peso / sum(bordas_cores.values())) * 100 if sum(bordas_cores.values()) > 0 else 0
            if percentual < 1.0: # Ignora ruídos menores que 1%
                continue
            idx = len(opcoes) + 1
            print(f"  {CYAN}[{idx}]{RESET} {cor} - {percentual:.1f}% de cobertura nas bordas")
            opcoes.append(cor)
            
        print(f"  {CYAN}[c]{RESET} Digitar um código hexadecimal personalizado (ex: #282c34)")
        
        escolha = input(f"\n  {BOLD}Escolha a cor a remover (1-{len(opcoes)} ou 'c'):{RESET} ").strip().lower()
        
        cor_fundo_detectada = None
        if escolha.isdigit() and 1 <= int(escolha) <= len(opcoes):
            cor_fundo_detectada = opcoes[int(escolha) - 1]
        elif escolha == 'c':
            cor_fundo_detectada = input("  Digite o código hexadecimal da cor (ex: #282c34): ").strip().lower()
            if not cor_fundo_detectada.startswith("#"):
                cor_fundo_detectada = f"#{cor_fundo_detectada}"
        else:
            if opcoes:
                cor_fundo_detectada = opcoes[0]
                print(f"  {YELLOW}[!] Opção padrão selecionada: {cor_fundo_detectada}{RESET}")
            else:
                print(f"  {RED}[-] Nenhuma cor de fundo pôde ser selecionada.{RESET}")
                return False

        if not cor_fundo_detectada:
            return False

        # Pergunta sobre o limite de tolerância
        tolerancia_str = input(f"\n  {BOLD}Digite a tolerância de cor (0 para cor exata, ou Enter para o padrão 15):{RESET} ").strip()
        tolerancia = 15.0
        if tolerancia_str:
            try:
                tolerancia = float(tolerancia_str)
            except ValueError:
                pass
                
        cor_fundo_rgb = hex_para_rgb(cor_fundo_detectada)
            
        # Filtragem em tempo linear O(N) para evitar lentidão catastrófica O(N^2)
        elementos_removidos = 0
        
        def filtrar_elementos(elemento):
            nonlocal elementos_removidos
            filhos_mantidos = []
            for filho in elemento:
                if filho.tag.endswith('rect'):
                    cor_hex = filho.get('fill', '').lower().strip()
                    if cor_hex:
                        # Se corresponde exatamente à string
                        if cor_hex == cor_fundo_detectada:
                            elementos_removidos += 1
                            continue
                        # Se temos RGB, checa a distância de cor
                        if cor_fundo_rgb:
                            cor_rgb = hex_para_rgb(cor_hex)
                            if cor_rgb and cores_sao_semelhantes(cor_fundo_rgb, cor_rgb, tolerancia):
                                elementos_removidos += 1
                                continue
                filtrar_elementos(filho)
                filhos_mantidos.append(filho)
            elemento[:] = filhos_mantidos

        filtrar_elementos(raiz)
                    
        caminho_saida_completo = caminho_saida.with_suffix(".svg")
        caminho_saida_completo.parent.mkdir(parents=True, exist_ok=True)
        arvore.write(caminho_saida_completo, encoding="utf-8", xml_declaration=True)
        
        print(f"{GREEN}[+] Fundo ({cor_fundo_detectada}) removido! Removidos {elementos_removidos} elementos de fundo.{RESET}")
        print(f"{GREEN}[+] SVG sem fundo salvo em: {caminho_saida_completo.name}{RESET}")
        return True
        
    except Exception as e:
        print(f"{RED}[-] Erro ao ler ou remover fundo do SVG: {e}{RESET}")
        return False

def processar_imagem_core(
    caminho_entrada: Path,
    caminho_saida: Path,
    redimensionar_str: str | None,
    converter_bits: bool,
    formato_saida: str | None
) -> bool:
    """
    Executa o processamento core de uma imagem, incluindo redimensionamento e conversões.

    Valida caminhos, realiza redimensionamentos, ajusta modos de cor incompatíveis,
    reduz a profundidade de bits para 8-bit seguro e gera saídas raster ou vetor SVG.
    """
    if not caminho_entrada.exists():
        print(f"{RED}[-] Arquivo de entrada não encontrado: {caminho_entrada}{RESET}")
        return False

    if caminho_entrada.suffix.lower() == ".svg":
        print(f"{RED}[-] ERRO: Arquivos SVG (vetoriais) não são suportados como imagem de entrada. O script apenas aceita imagens rasterizadas (PNG, JPG, WebP, TGA, BMP) como entrada.{RESET}")
        return False

    try:
        # Usa Image.open diretamente (precisa carregar os dados se formos modificar)
        with Image.open(caminho_entrada) as imagem_aberta:
            imagem_pil = imagem_aberta.copy()
            
        largura_original, altura_original = imagem_pil.size
        
        # Se for solicitado redimensionamento
        if redimensionar_str:
            largura_alvo, altura_alvo = calcular_dimensoes(largura_original, altura_original, redimensionar_str)
            # Resampling NEAREST preserva pixel art nítida
            imagem_pil = imagem_pil.resize((largura_alvo, altura_alvo), Image.Resampling.NEAREST)
        
        # Determinar extensão de saída e formato
        formato_destino = formato_saida.strip().lower().replace(".", "") if formato_saida else caminho_saida.suffix.strip().lower().replace(".", "")
        if not formato_destino:
            formato_destino = "png"
        
        caminho_saida_completo = caminho_saida.with_suffix(f".{formato_destino}")
        caminho_saida_completo.parent.mkdir(parents=True, exist_ok=True)
        
        # Vetorização real para SVG
        if formato_destino == "svg":
            conteudo_svg = converter_imagem_para_svg_blocos(imagem_pil)
            with open(caminho_saida_completo, "w", encoding="utf-8") as arquivo_svg:
                arquivo_svg.write(conteudo_svg)
            print(f"{GREEN}[+] Arquivo '{caminho_entrada.name}' vetorizado para SVG com sucesso ➔ '{caminho_saida_completo.name}'{RESET}")
            return True
            
        # Tratamento de incompatibilidades de formato
        if formato_destino in ("jpg", "jpeg"):
            if imagem_pil.mode != "RGB":
                # Converte RGBA para RGB com fundo branco
                imagem_fundo_branco = Image.new("RGB", imagem_pil.size, (255, 255, 255))
                if imagem_pil.mode == "RGBA":
                    imagem_fundo_branco.paste(imagem_pil, mask=imagem_pil.split()[3])
                else:
                    imagem_fundo_branco.paste(imagem_pil.convert("RGB"))
                imagem_pil = imagem_fundo_branco
        elif converter_bits:
            # Otimiza e padroniza para 8-bit RGBA (ou RGB se for o caso)
            if imagem_pil.mode not in ("RGB", "RGBA"):
                imagem_pil = imagem_pil.convert("RGBA")
        
        # Salvar imagem final rasterizada
        nome_formato_pil = "JPEG" if formato_destino in ("jpg", "jpeg") else formato_destino.upper()
        imagem_pil.save(caminho_saida_completo, format=nome_formato_pil)
        print(f"{GREEN}[+] Arquivo '{caminho_entrada.name}' processado com sucesso ➔ '{caminho_saida_completo.name}'{RESET}")
        return True
            
    except Exception as erro:
        print(f"{RED}[-] Erro ao processar a imagem '{caminho_entrada.name}': {erro}{RESET}")
        return False

def processar_imagem_interativo() -> None:
    """
    Fluxo guiado via linha de comando para processar uma imagem ou diretório de imagens.
    """
    print(f"\n{CYAN}{BOLD}⚙️  Processador de Imagens Interativo{RESET}")
    caminho_entrada_usuario = input("Digite o caminho da imagem de entrada ou pasta: ").strip().strip('"').strip("'")
    if not caminho_entrada_usuario:
        print(f"{RED}[-] Entrada inválida.{RESET}")
        return
        
    caminho_entrada = Path(caminho_entrada_usuario)
    if not caminho_entrada.exists():
        print(f"{RED}[-] Caminho não encontrado: {caminho_entrada}{RESET}")
        return
        
    if caminho_entrada.is_file() and caminho_entrada.suffix.lower() == ".svg":
        deseja_remover_fundo = input("A imagem de entrada é um SVG. Deseja remover o fundo dele? (s/n): ").strip().lower()
        if deseja_remover_fundo in ("s", "sim"):
            diretorio_saida_padrao = DIRETORIO_RAIZ / "imagem_out"
            caminho_sugerido = diretorio_saida_padrao / f"{caminho_entrada.stem}_sem_fundo.svg"
            print(f"\nCaminho de saída sugerido: {caminho_sugerido}")
            caminho_saida_usuario = input("Pressione Enter para confirmar ou digite o caminho de saída completo: ").strip().strip('"').strip("'")
            caminho_saida = Path(caminho_saida_usuario) if caminho_saida_usuario else caminho_sugerido
            if remover_fundo_svg(caminho_entrada, caminho_saida):
                caminho_absoluto_saida = caminho_saida.with_suffix(".svg").resolve()
                caminho_uri = f"file:///{str(caminho_absoluto_saida).replace(os.sep, '/')}"
                print(f"🖼️ {GREEN}{BOLD}Imagem de Saída:{RESET} {GREEN}{caminho_uri}{RESET}\n")
            return
        else:
            print(f"{YELLOW}[!] Processamento cancelado. Arquivos SVG não suportam redimensionamento ou outras conversões no script.{RESET}")
            return
            
    eh_diretorio = caminho_entrada.is_dir()
    
    # 1. Redimensionamento
    redimensionar_str = None
    deseja_redimensionar = input("Deseja redimensionar a(s) imagem(ns)? (s/n): ").strip().lower()
    if deseja_redimensionar in ("s", "sim"):
        redimensionar_str = input("Digite o parâmetro (ex: '2x', '50%', '256' para largura, ou '512x512'): ").strip()
        
    # 2. Otimização de Bits
    converter_bits = False
    deseja_converter_bits = input("Deseja otimizar para 8-bit seguro (previne crashes no PZ)? (s/n): ").strip().lower()
    if deseja_converter_bits in ("s", "sim"):
        converter_bits = True
        
    # 3. Conversão de Formato
    formato_saida = None
    deseja_converter_formato = input("Deseja converter o formato de saída? (s/n): ").strip().lower()
    if deseja_converter_formato in ("s", "sim"):
        formato_saida = input("Digite a extensão de destino (ex: png, jpg, webp, svg, tga): ").strip().lower().replace(".", "")
        
    diretorio_saida_padrao = DIRETORIO_RAIZ / "imagem_out"
    
    if eh_diretorio:
        print(f"\n[*] Processando lote de imagens no diretório: {caminho_entrada}")
        diretorio_saida_padrao.mkdir(parents=True, exist_ok=True)
        
        extensoes_suportadas = (".png", ".jpg", ".jpeg", ".tga", ".webp", ".bmp")
        arquivos_imagem = [arq for arq in caminho_entrada.iterdir() if arq.is_file() and arq.suffix.lower() in extensoes_suportadas]
        
        if not arquivos_imagem:
            print(f"{YELLOW}[!] Nenhuma imagem compatível encontrada na pasta.{RESET}")
            return
            
        sucessos = 0
        for arq in arquivos_imagem:
            ext_final = formato_saida if formato_saida else arq.suffix.replace(".", "")
            caminho_destino_arquivo = diretorio_saida_padrao / f"{arq.stem}.{ext_final}"
            if processar_imagem_core(arq, caminho_destino_arquivo, redimensionar_str, converter_bits, formato_saida):
                sucessos += 1
                
        print(f"\n{GREEN}[+] Processamento de lote finalizado! Sucesso: {sucessos}/{len(arquivos_imagem)} imagens.{RESET}")
        caminho_absoluto_saida = diretorio_saida_padrao.resolve()
        caminho_uri = f"file:///{str(caminho_absoluto_saida).replace(os.sep, '/')}"
        print(f"📂 {GREEN}{BOLD}Pasta de Saída:{RESET} {GREEN}{caminho_uri}{RESET}\n")
        
    else:
        ext_final = formato_saida if formato_saida else caminho_entrada.suffix.replace(".", "")
        caminho_sugerido = diretorio_saida_padrao / f"{caminho_entrada.stem}.{ext_final}"
        
        print(f"\nCaminho de saída sugerido: {caminho_sugerido}")
        caminho_saida_usuario = input("Pressione Enter para confirmar ou digite o caminho de saída completo: ").strip().strip('"').strip("'")
        
        caminho_saida = Path(caminho_saida_usuario) if caminho_saida_usuario else caminho_sugerido
        caminho_saida.parent.mkdir(parents=True, exist_ok=True)
        
        if processar_imagem_core(caminho_entrada, caminho_saida, redimensionar_str, converter_bits, formato_saida):
            print(f"\n{GREEN}[+] Imagem processada com sucesso!{RESET}")
            caminho_absoluto_saida = caminho_saida.with_suffix(f".{ext_final}").resolve()
            caminho_uri = f"file:///{str(caminho_absoluto_saida).replace(os.sep, '/')}"
            print(f"🖼️ {GREEN}{BOLD}Imagem de Saída:{RESET} {GREEN}{caminho_uri}{RESET}\n")

# ============================================================================
# 🔍 MÓDULO 4: REDIRECIONAMENTO DE AUDITORIA (DELEGADO A AUDITORIA_MOD.PY)
# ============================================================================

def redirecionar_auditoria_completa():
    """Chama de forma unificada a auditoria completa do script auditoria_mod.py."""
    import subprocess
    caminho_auditoria = DIRETORIO_FERRAMENTAS / "auditoria_mod.py"
    if caminho_auditoria.exists():
        subprocess.run([sys.executable, str(caminho_auditoria)])
    else:
        print(f"{RED}[-] Erro: Script de auditoria 'auditoria_mod.py' não encontrado.{RESET}")


def print_banner():
    """Exibe um banner ASCII moderno e bordas unicode elegantes na inicialização."""
    os.system('cls' if os.name == 'nt' else 'clear')
    emoji_ferramenta = "🔧"
    largura_interna = 74
    
    def formatar_linha_banner(conteudo, cor_borda=CYAN):
        # Remove códigos de cor ANSI para cálculo de largura visual
        conteudo_limpo = re.sub(r'\033\[[0-9;]*m', '', conteudo)
        
        # Calcula largura visual considerando que emojis ocupam 2 colunas
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

def buscar_referencias_assets(termo_busca, pasta_jogo):
    """Busca referências de assets 2D (UI/Itens) nos packs e 3D (Tilesets) no JSON de metadados."""
    termo = termo_busca.lower().strip()
    if not termo:
        print(f"{RED}[-] Erro: O termo de busca não pode ser vazio.{RESET}")
        return
        
    print(f"\n{CYAN}[*] Buscando referências de assets para: '{termo_busca}'...{RESET}")
    
    # 1. Busca no JSON de metadados (dicionario_tilesets.json) para sprites do mundo 3D
    sprites_mundo = []
    caminho_json = DIRETORIO_FERRAMENTAS / "dicionario_tilesets.json"
    if caminho_json.exists():
        try:
            import json
            with open(caminho_json, "r", encoding="utf-8") as f:
                dados = json.load(f)
            
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
                    with open(caminho_pack, "rb") as f:
                        primeiros_bytes = f.read(4)
                        e_pzpk = (primeiros_bytes == b"PZPK")
                        
                        if e_pzpk:
                            versao = ler_int(f)
                            num_paginas = ler_int(f)
                        else:
                            if len(primeiros_bytes) < 4:
                                continue
                            num_paginas = struct.unpack("<I", primeiros_bytes)[0]
                            
                        if num_paginas is None:
                            continue
                            
                        for pag_idx in range(num_paginas):
                            if pag_idx > 0 and not e_pzpk:
                                f.seek(f.tell() + 4) # Pula o DEADBEEF
                            nome_pagina = ler_string(f)
                            num_sprites = ler_int(f)
                            f.seek(f.tell() + 4) # Pula flag_pagina
                            
                            dados_sprites_pag = []
                            for _ in range(num_sprites):
                                nome_sprite = ler_string(f)
                                f.seek(f.tell() + 32) # Pula dados dimensionais do sprite
                                
                                if termo in nome_sprite.lower():
                                    dados_sprites_pag.append(nome_sprite)
                                    
                            for sp_nome in dados_sprites_pag:
                                sprites_ui.append({
                                    "sprite": sp_nome,
                                    "pack": pack_nome,
                                    "pagina": nome_pagina
                                })
                                
                            # Pula dados da imagem de forma segura
                            if e_pzpk:
                                tam_png = ler_int(f)
                                if tam_png:
                                    f.seek(f.tell() + tam_png)
                            else:
                                bloco_dados = bytearray()
                                while True:
                                    dados_lidos = f.read(4096)
                                    if not dados_lidos:
                                        break
                                    bloco_dados.extend(dados_lidos)
                                    idx_iend = bloco_dados.find(b"IEND")
                                    if idx_iend != -1:
                                        excesso = len(bloco_dados) - (idx_iend + 8)
                                        f.seek(f.tell() - excesso)
                                        break
                except Exception:
                    pass

    # 2.2 Busca por arquivos avulsos de imagem na pasta media/ui/ da instalação do jogo
    pasta_ui_jogo = Path(pasta_jogo) / "media" / "ui"
    if pasta_ui_jogo.exists():
        for arq in pasta_ui_jogo.iterdir():
            if arq.is_file() and arq.suffix.lower() in ('.png', '.jpg', '.tga'):
                if termo in arq.name.lower():
                    # Evita duplicar se por acaso já estiver em sprites_ui
                    if not any(item['sprite'].lower() == arq.name.lower() for item in sprites_ui):
                        sprites_ui.append({
                            "sprite": arq.name,
                            "pack": "avulso",
                            "pagina": "Diretório media/ui",
                            "caminho_avulso": arq
                        })

    # 3. Apresenta o relatório estruturado e premium na tela
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
        print(f"{CYAN}│{RESET}  {YELLOW}Nenhum ícone 2D (Item/UI) encontrado para o termo '{termo_busca}'.{RESET}")
    print(f"{CYAN}└───{RESET}")
        
    print(f"\n{CYAN}┌── {BOLD}🧱 SPRITES 3D / TILESETS ENCONTRADOS (Mundo):{RESET}")
    offset_3d = len(sprites_ui)
    if sprites_mundo:
        for idx, item in enumerate(sprites_mundo, 1):
            sprite_nome = item['sprite']
            detalhes = item['detalhes']
            print(f"{CYAN}│{RESET}  [{idx + offset_3d:<2}] Sprite: {CYAN}{sprite_nome}{RESET} ➔ {detalhes}")
    else:
        print(f"{CYAN}│{RESET}  {YELLOW}Nenhum sprite 3D (Mundo/Tileset) encontrado para o termo '{termo_busca}'.{RESET}")
    print(f"{CYAN}└───{RESET}")

    # 4. Oferece extração interativa simplificada baseada em números
    # Aceita múltiplos valores separados por vírgula, ponto-e-vírgula ou espaço.
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
                        print(f"{RED}[-] Número {num} fora do intervalo (1–{len(total_encontrados)}). Ignorado.{RESET}")

                for num in numeros_validos:
                    asset_alvo = total_encontrados[num - 1]
                    sprite_nome = asset_alvo["sprite"]

                    if asset_alvo.get("pack") == "avulso":
                        caminho_origem = asset_alvo["caminho_avulso"]
                        caminho_destino = Path(DIRETORIO_UI_MOD) / sprite_nome
                        os.makedirs(DIRETORIO_UI_MOD, exist_ok=True)
                        shutil.copy2(caminho_origem, caminho_destino)
                        caminho_destino_rel = os.path.relpath(caminho_destino, DIRETORIO_RAIZ).replace('\\', '/')
                        print(f"{GREEN}  [+] Arquivo avulso copiado com sucesso: {caminho_origem.name} ➔ ./{caminho_destino_rel}{RESET}")
                    else:
                        nome_saida = sugerir_nome_arquivo(sprite_nome)
                        print(f"\n[*] Extraindo '{sprite_nome}'...")
                        mapeamento = {sprite_nome: nome_saida}
                        extrair_assets_do_jogo(pasta_jogo, mapeamento, DIRETORIO_UI_MOD)
        except ValueError:
            print(f"{RED}[-] Entrada inválida (use apenas números separados por vírgula).{RESET}")
        except Exception as e:
            print(f"{RED}[-] Erro na seleção/cópia: {e}{RESET}")

# ============================================================================
# 🎮 INTERFACE E MENU CLI
# ============================================================================

def run_menu_interativo():
    print_banner()
    print(f"  {BOLD}Selecione a operação desejada:{RESET}")
    print(f"    {CYAN}[1]{RESET} Extrair Assets do Jogo (.pack ➔ PNG)")
    print(f"    {CYAN}[2]{RESET} Inspecionar Imagem (Resolução, modo, bit depth)")
    print(f"    {CYAN}[3]{RESET} Processar Imagem (Redimensionar, Converter bits/formatos, Lotes)")
    print(f"    {CYAN}[4]{RESET} Executar Auditoria Completa do Mod (auditoria_mod.py)")
    print(f"    {CYAN}[5]{RESET} Buscar Referências de Assets (Unificado 2D/3D)")
    print(f"    {CYAN}[0]{RESET} Sair")
    
    try:
        opcao = input(f"\n  {BOLD}Escolha uma opção (0-5):{RESET} ").strip()
    except (KeyboardInterrupt, EOFError):
        print("\n  Saindo...")
        return
        
    if opcao == "1":
        # Extração de assets
        caminho_jogo = DIRETORIO_JOGO_PADRAO
        
        # Se o caminho padrão não for válido, força a escolha no diálogo gráfico
        pasta_packs = Path(caminho_jogo) / "media" / "texturepacks" if caminho_jogo else None
        if not caminho_jogo or not pasta_packs or not pasta_packs.exists():
            print(f"{YELLOW}[!] Caminho do jogo não configurado ou inválido. Abrindo explorador de pastas...{RESET}")
            caminho_jogo = obter_diretorio_jogo_grafico()
        else:
            print(f"{GREEN}Diretório do jogo configurado no arquivo .env: {caminho_jogo}{RESET}\n")
        
        sprite_alvo = input("Digite o nome do Sprite original do jogo a extrair (ou Enter para os padrões): ").strip()
        
        if sprite_alvo:
            sprite_alvo_limpo = re.sub(r"\.(png|jpg|tga|jpeg|gif)$", "", sprite_alvo, flags=re.IGNORECASE)
            nome_sugerido = sugerir_nome_arquivo(sprite_alvo_limpo)
            nome_arq = input(f"Nome do arquivo de saída PNG [Padrão: {nome_sugerido}]: ").strip()
            if not nome_arq:
                nome_arq = nome_sugerido
            # Protege contra subdiretórios ou caracteres de caminhos inválidos
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
        
        extrair_assets_do_jogo(caminho_jogo, mapeamento, DIRETORIO_UI_MOD)
        
    elif opcao == "5":
        # Busca unificada
        caminho_jogo = DIRETORIO_JOGO_PADRAO
        pasta_packs = Path(caminho_jogo) / "media" / "texturepacks" if caminho_jogo else None
        if not caminho_jogo or not pasta_packs or not pasta_packs.exists():
            caminho_jogo = obter_diretorio_jogo_grafico()
        else:
            print(f"{GREEN}Diretório do jogo configurado no arquivo .env: {caminho_jogo}{RESET}\n")
        
        termo = input("Digite o termo de busca (ex: Generator, Washer, Fridge): ").strip()
        buscar_referencias_assets(termo, caminho_jogo)
        
    elif opcao == "2":
        # Inspeção
        caminho_img = input("Digite o nome ou caminho da imagem ou pasta: ").strip()
        caminho = Path(caminho_img)
        if caminho.exists():
            if caminho.is_file():
                inspecionar_propriedades_imagem(caminho)
            else:
                for idx, arq in enumerate(caminho.iterdir(), 1):
                    if arq.is_file() and arq.suffix.lower() in ('.png', '.jpg', '.tga', '.webp'):
                        inspecionar_propriedades_imagem(arq, idx)
        else:
            # Tenta buscar na pasta de UI do mod
            caminho_mod = DIRETORIO_UI_MOD / caminho_img
            if caminho_mod.exists():
                inspecionar_propriedades_imagem(caminho_mod)
            else:
                print(f"{RED}[-] Caminho não encontrado.{RESET}")
                
    elif opcao == "3":
        processar_imagem_interativo()
        
    elif opcao == "4":
        # Executa a auditoria completa do mod (redirecionada a auditoria_mod.py)
        redirecionar_auditoria_completa()
        
    elif opcao == "0":
        print("Saindo...")
        
    else:
        print(f"{RED}Opção inválida.{RESET}")

class ArgumentParserPTBR(argparse.ArgumentParser):
    """Subclasse customizada do ArgumentParser para internacionalização de erros em pt-BR."""
    def error(self, message):
        mensagem_traduzida = message
        
        # Converte mensagens de exclusão mútua do argparse
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

        # Exibe a mensagem formatada em pt-BR com bordas visuais elegantes e dica de ajuda
        sys.stderr.write(f"\n{RED}┌──────────────────────────────────────────────────────────────────────────────┐{RESET}\n")
        sys.stderr.write(f"{RED}│ ❌ ERRO DE ARGUMENTO CLI:                                                    │{RESET}\n")
        sys.stderr.write(f"{RED}└──────────────────────────────────────────────────────────────────────────────┘{RESET}\n")
        sys.stderr.write(f"  {YELLOW}{mensagem_traduzida}{RESET}\n\n")
        sys.stderr.write(f"{CYAN}💡 DICA: Digite 'python tools/LKS_Tools.py -h' ou '--help' para ver a documentação.{RESET}\n\n")
        sys.exit(2)

def main():
    # Pré-processador dinâmico de argumentos (tolerante a desordem e suporte retroativo)
    if len(sys.argv) > 1:
        argumentos_originais = sys.argv[1:]
        
        # 1. Mapeia comandos posicionais legados para flags correspondentes
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
        
        # 2. Analisa a estrutura dos argumentos passados
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
                
        # 3. Associa valores soltos às ações ou configurações
        # Se temos uma flag de ação que precisa de valor e temos valores soltos, faz a associação
        flag_acao_ativa_com_valor = next((flag for flag in flags_presentes if flag in flags_acao_com_valor), None)
        
        if flag_acao_ativa_com_valor and valores_soltos:
            # Associa o primeiro valor solto com essa flag de ação
            valor_associado = valores_soltos.pop(0)
            configuracoes.append((flag_acao_ativa_com_valor, valor_associado))
            flags_presentes.remove(flag_acao_ativa_com_valor)
            
        # Se sobrou algum valor solto, deduzimos que a intenção é extração
        if valores_soltos:
            # Mapeia cada valor solto restante para ser um sprite a extrair (-s)
            for valor_solto in valores_soltos:
                configuracoes.append(("-s", valor_solto))
            # Se nenhuma flag de ação principal está em flags_presentes ou configuracoes, adiciona -e
            qualquer_acao = (
                any(flag in flags_acao_sem_valor or flag in flags_acao_com_valor for flag in flags_presentes) or
                any(par_config[0] in flags_acao_com_valor for par_config in configuracoes)
            )
            if not qualquer_acao and "-e" not in flags_presentes and "--extrair" not in flags_presentes:
                flags_presentes.append("-e")
                
        # 4. Reconstrói o sys.argv
        novos_argumentos = [sys.argv[0]]
        for flag in flags_presentes:
            novos_argumentos.append(flag)
        for opcao_config, valor_config in configuracoes:
            novos_argumentos.append(opcao_config)
            novos_argumentos.append(valor_config)
            
        sys.argv = novos_argumentos

    parser = ArgumentParserPTBR(
        description=f"{CYAN}{BOLD}🎨 TOOLS ASSETS - LKS SUPERMOD PATCH{RESET}\n\n"
                    f"DICA: Você pode passar o nome de um sprite diretamente como primeiro argumento para extraí-lo!\n"
                    f"Exemplos:\n"
                    f"  python tools/LKS_Tools.py Container_Fridge         (Extrai o ícone 2D da interface)\n"
                    f"  python tools/LKS_Tools.py -b Generator             (Busca referências de assets)\n",
        formatter_class=argparse.RawTextHelpFormatter
    )
    
    # Grupo de Ações Principais Mutuamente Exclusivas (Impede chamadas simultâneas)
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
        help="Executa a auditoria unificada completa do mod (sintaxe, traduções, caminhos e assets)"
    )
    grupo_acao.add_argument(
        "--buscar", "-b",
        metavar="TERMO",
        help="Busca referências de um asset (UI e Mundo) a partir de um termo"
    )
    
    # Parâmetros Auxiliares
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
        
    # Executa a ação correspondente
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
            # Mapeamento padrão do mod
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
            # Tenta buscar na pasta de UI do mod
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
        buscar_referencias_assets(args.buscar, caminho_jogo)

if __name__ == "__main__":
    main()
