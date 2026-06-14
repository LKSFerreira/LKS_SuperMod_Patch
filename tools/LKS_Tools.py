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

def converter_profundidade_bits(entrada, saida, target_depth=8):
    """Converte a profundidade de bits de um PNG para 8-bit (evitando crashes de 16-bit)."""
    p_entrada = Path(entrada)
    p_saida = Path(saida)
    
    if not p_entrada.exists():
        print(f"{RED}[-]- Arquivo de entrada não encontrado: {p_entrada}{RESET}")
        return False
        
    try:
        img = Image.open(p_entrada)
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
            
        img.save(p_saida, format="PNG")
        print(f"{GREEN}[+] Arquivo '{p_entrada.name}' convertido com sucesso para 8 bits/canal (32-bit RGBA) ➔ '{p_saida.name}'{RESET}")
        return True
    except Exception as e:
        print(f"{RED}[-] Erro ao processar conversão de bits: {e}{RESET}")
        return False

# ============================================================================
# 🔍 MÓDULO 4: AUDITORIA DE IMAGENS MORTAS (FIND FILES)
# ============================================================================

def auditar_imagens_mortas():
    """Analisa o mod para descobrir se há imagens na pasta media/ui que não estão sendo usadas nos arquivos Lua."""
    print(f"{CYAN}[*] Iniciando auditoria de assets órfãos...{RESET}")
    
    # 1. Coleta arquivos de código do mod
    arquivos_codigo = []
    for extensao in ["*.lua", "*.json", "*.txt", "*.md"]:
        arquivos_codigo.extend(DIRETORIO_RAIZ.rglob(extensao))
        
    # Unifica o texto do código em uma grande string de busca
    conteudo_codigo = ""
    for arquivo_codigo in arquivos_codigo:
        try:
            with open(arquivo_codigo, "r", encoding="utf-8", errors="ignore") as arquivo_leitor:
                conteudo_codigo += arquivo_leitor.read().lower()
        except Exception:
            pass
            
    # 2. Coleta imagens da pasta de UI
    if not DIRETORIO_UI_MOD.exists():
        print(f"{YELLOW}[!] Pasta de UI do mod vazia ou inexistente.{RESET}")
        return
        
    imagens = [caminho_imagem for caminho_imagem in DIRETORIO_UI_MOD.iterdir() if caminho_imagem.is_file() and caminho_imagem.suffix.lower() in ('.png', '.jpg', '.tga')]
    
    print(f"[INFO] Indexados {len(arquivos_codigo)} arquivos de código e {len(imagens)} imagens de UI.")
    print("-" * 65)
    print(f"{'ARQUIVO DE IMAGEM':<38} | {'STATUS NO CÓDIGO':<20}")
    print("-" * 65)
    
    imagens_nao_referenciadas = []
    for caminho_imagem in imagens:
        nome_base = caminho_imagem.stem
        padrao_busca_regex = r"\b" + re.escape(nome_base.lower()) + r"\b"
        
        if re.search(padrao_busca_regex, conteudo_codigo):
            print(f"✅ {caminho_imagem.name:<36} | Usado/Referenciado")
        else:
            print(f"❌ {RED}{caminho_imagem.name:<36}{RESET} | {RED}SUSPEITO (NÃO REFERENCIADO){RESET}")
            imagens_nao_referenciadas.append(caminho_imagem)
            
    print("-" * 65)

def print_banner():
    """Exibe um banner ASCII moderno e bordas unicode elegantes na inicialização."""
    os.system('cls' if os.name == 'nt' else 'clear')
    banner = f"""
{CYAN}    ╔══════════════════════════════════════════════════════════════════════════╗
    ║  {BOLD}🎨 GERENCIADOR DE ASSETS - LKS SUPERMOD PATCH (Build 42){RESET}{CYAN}             ║
    ║  {GRAY}Centralizador de Extração, Inspeção e Auditoria de Sprites{RESET}{CYAN}          ║
    ╚══════════════════════════════════════════════════════════════════════════╝{RESET}
"""
    print(banner)

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
    total_encontrados = sprites_ui + sprites_mundo
    if total_encontrados:
        try:
            escolha = input(f"\nDeseja extrair/copiar algum destes assets? (Digite o número correspondente ou Enter para sair): ").strip()
            if escolha:
                num = int(escolha)
                if 1 <= num <= len(total_encontrados):
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
                else:
                    print(f"{RED}[-] Número inválido.{RESET}")
        except ValueError:
            print(f"{RED}[-] Entrada inválida (digite apenas números).{RESET}")
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
    print(f"    {CYAN}[3]{RESET} Otimizar PNG para 8-bit (Corrige crashes de texturas 16-bit)")
    print(f"    {CYAN}[4]{RESET} Auditar Código do Mod (Buscar imagens órfãs/sem uso)")
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
        p_packs = Path(caminho_jogo) / "media" / "texturepacks"
        if not caminho_jogo or not p_packs.exists():
            print(f"{YELLOW}[!] Caminho do jogo não configurado ou inválido. Abrindo explorador de pastas...{RESET}")
            caminho_jogo = obter_diretorio_jogo_grafico()
        else:
            print(f"Caminho do jogo atual: {caminho_jogo}")
            print(f"Deseja alterar esse caminho usando o explorador gráfico? [s/N]: ", end="")
            resposta = input().strip().lower()
            if resposta in ('s', 'sim'):
                caminho_jogo = obter_diretorio_jogo_grafico()
        
        sprite_alvo = input("\nDigite o nome do Sprite original do jogo a extrair (ou Enter para os padrões): ").strip()
        
        if sprite_alvo:
            nome_sugerido = sugerir_nome_arquivo(sprite_alvo)
            nome_arq = input(f"Nome do arquivo de saída PNG [Padrão: {nome_sugerido}]: ").strip()
            if not nome_arq:
                nome_arq = nome_sugerido
            # Protege contra subdiretórios ou caracteres de caminhos inválidos
            nome_arq = os.path.basename(nome_arq)
            if not nome_arq.lower().endswith(".png"):
                nome_arq += ".png"
            mapeamento = {sprite_alvo: nome_arq}
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
        p_packs = Path(caminho_jogo) / "media" / "texturepacks"
        if not caminho_jogo or not p_packs.exists():
            caminho_jogo = obter_diretorio_jogo_grafico()
        
        termo = input("\nDigite o termo de busca (ex: Generator, Washer, Fridge): ").strip()
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
        # Otimização para 8-bit
        img_in = input("Caminho do PNG original (16-bit): ").strip()
        img_out = input("Caminho do arquivo de saída (Enter para mesmo nome/sobrescrever): ").strip() or img_in
        converter_profundidade_bits(img_in, img_out)
        
    elif opcao == "4":
        # Auditoria de imagens órfãs
        auditar_imagens_mortas()
        
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
        sys.stderr.write(f"{CYAN}💡 DICA: Digite 'python tools/gerenciador_assets.py -h' ou '--help' para ver a documentação.{RESET}\n\n")
        sys.exit(2)

def main():
    # Interceptador Dinâmico de CLI (Dedução de Intenção do Desenvolvedor / Suporte Retroativo)
    if len(sys.argv) > 1:
        primeiro_arg = sys.argv[1]
        subcomandos_legados = {
            "extrair": "-e", 
            "inspecionar": "-i", 
            "converter": "-c", 
            "auditar": "-a", 
            "buscar": "-b"
        }
        
        # 1. Suporte retroativo: Converte subcomandos posicionais antigos para as novas flags
        if primeiro_arg.lower() in subcomandos_legados:
            print(f"{CYAN}[INFO] Convertendo comando legado '{primeiro_arg}' para a nova flag '{subcomandos_legados[primeiro_arg.lower()]}'{RESET}")
            sys.argv[1] = subcomandos_legados[primeiro_arg.lower()]
            
        # 2. Deduz extração direta se passar um sprite sem nenhuma flag
        elif not primeiro_arg.startswith("-"):
            print(f"\n{CYAN}[INFO] Intenção de extração direta detectada para o sprite: '{primeiro_arg}'{RESET}")
            # Filtra e preserva apenas parâmetros opcionais válidos (--jogo/--destino ou curtas)
            args_extras = []
            i = 2
            while i < len(sys.argv):
                arg = sys.argv[i]
                if arg.startswith(("-j", "--jogo", "-d", "--destino")):
                    args_extras.append(arg)
                    if i + 1 < len(sys.argv) and not sys.argv[i+1].startswith("-"):
                        args_extras.append(sys.argv[i+1])
                        i += 1
                i += 1
            sys.argv = [sys.argv[0], "-e", "-s", primeiro_arg] + args_extras

    parser = ArgumentParserPTBR(
        description=f"{CYAN}{BOLD}🎨 Gerenciador Integrado de Assets do Mod - LKS SuperMod Patch{RESET}\n\n"
                    f"DICA: Você pode passar o nome de um sprite diretamente como primeiro argumento para extraí-lo!\n"
                    f"Exemplos:\n"
                    f"  python tools/gerenciador_assets.py Container_Fridge         (Extrai o ícone 2D da interface)\n"
                    f"  python tools/gerenciador_assets.py -b Generator             (Busca referências de assets)\n",
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
        help="Audita a pasta de UI do mod buscando imagens órfãs/sem uso"
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
            for item in args.sprite:
                if ":" in item:
                    sprite_orig, arq_saida = item.split(":", 1)
                    mapeamento[sprite_orig.strip()] = arq_saida.strip()
                else:
                    sprite_nome = item.strip()
                    mapeamento[sprite_nome] = sugerir_nome_arquivo(sprite_nome)
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
        converter_profundidade_bits(args.converter, saida)
        
    elif args.auditar:
        auditar_imagens_mortas()
        
    elif args.buscar:
        caminho_jogo = args.jogo
        if not validar_e_salvar_caminho(caminho_jogo):
            print(f"{YELLOW}[!] Caminho '{caminho_jogo}' não é uma instalação válida. Abrindo explorador gráfico...{RESET}")
            caminho_jogo = obter_diretorio_jogo_grafico()
        buscar_referencias_assets(args.buscar, caminho_jogo)

if __name__ == "__main__":
    main()
