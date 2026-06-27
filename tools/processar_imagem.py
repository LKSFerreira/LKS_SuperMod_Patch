# -*- coding: utf-8 -*-
"""
================================================================================
⚙️ PROCESSAMENTO E OTIMIZAÇÃO DE IMAGEM - LKS SUPERMOD PATCH
================================================================================
Módulo responsável por redimensionamento, conversão para 8-bit, vetorização SVG
e remoção de fundo em SVG.
"""

import os
import sys
import json
import xml.etree.ElementTree as ElementTree
from pathlib import Path
from PIL import Image

# Cores do terminal para feedback
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
DIRETORIO_SAIDA_PADRAO = DIRETORIO_RAIZ / "imagem_out"


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

    Preserva a nitidez de pixel art através do atributo shape-rendering="crispEdges".

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


def remover_fundo_svg(
    caminho_entrada: Path,
    caminho_saida: Path,
    cor_fundo: str | None = None,
    tolerancia: float = 15.0,
    interativo: bool = True,
    silencioso: bool = False
) -> bool:
    """
    Analisa um arquivo SVG, detecta a cor de fundo dominante ou selecionada e a remove do XML.
    """
    if not caminho_entrada.exists():
        if not silencioso:
            print(f"{RED}[-] Arquivo SVG de entrada não encontrado: {caminho_entrada}{RESET}")
        return False

    try:
        # Registra o namespace para evitar prefixos ns0: nos elementos salvos
        ElementTree.register_namespace('', 'http://www.w3.org/2000/svg')
        
        arvore = ElementTree.parse(caminho_entrada)
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
            
        retangulos = []
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
            if not silencioso:
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
        
        opcoes = []
        if retangulo_fundo:
            opcoes.append(retangulo_fundo[1])
            
        for cor, peso in cores_ordenadas:
            if cor in opcoes:
                continue
            percentual = (peso / sum(bordas_cores.values())) * 100 if sum(bordas_cores.values()) > 0 else 0
            if percentual < 1.0:
                continue
            opcoes.append(cor)
            
        cor_fundo_detectada = None
        
        if interativo:
            print(f"\n{CYAN}{BOLD}🎨 Detecção de fundo no SVG:{RESET}")
            if retangulo_fundo:
                print(f"  {CYAN}[1]{RESET} {retangulo_fundo[1]} (Retângulo de fundo gigante explícito)")
            for indice, opcao_cor in enumerate(opcoes, 1):
                if retangulo_fundo and opcao_cor == retangulo_fundo[1]:
                    continue
                peso_cor = bordas_cores.get(opcao_cor, 0)
                percentual = (peso_cor / sum(bordas_cores.values())) * 100 if sum(bordas_cores.values()) > 0 else 0
                print(f"  {CYAN}[{indice}]{RESET} {opcao_cor} - {percentual:.1f}% de cobertura nas bordas")
                
            print(f"  {CYAN}[c]{RESET} Digitar um código hexadecimal personalizado (ex: #282c34)")
            
            escolha = input(f"\n  {BOLD}Escolha a cor a remover (1-{len(opcoes)} ou 'c'):{RESET} ").strip().lower()
            
            if escolha.isdigit() and 1 <= int(escolha) <= len(opcoes):
                cor_fundo_detectada = opcoes[int(escolha) - 1]
            elif escolha == 'c':
                cor_fundo_detectada = input("  Digite o código hexadecimal da cor: ").strip().lower()
                if not cor_fundo_detectada.startswith("#"):
                    cor_fundo_detectada = f"#{cor_fundo_detectada}"
            else:
                if opcoes:
                    cor_fundo_detectada = opcoes[0]
                    if not silencioso:
                        print(f"  {YELLOW}[!] Opção padrão selecionada: {cor_fundo_detectada}{RESET}")
            
            tolerancia_str = input(f"\n  {BOLD}Digite a tolerância de cor (0 para cor exata, ou Enter para o padrão 15):{RESET} ").strip()
            if tolerancia_str:
                try:
                    tolerancia = float(tolerancia_str)
                except ValueError:
                    pass
        else:
            # Em modo autônomo (não-interativo), se o usuário passou a cor específica, usa-a.
            # Caso contrário, usa a cor de fundo detectada de maior peso.
            if cor_fundo:
                cor_fundo_detectada = cor_fundo.strip().lower()
                if not cor_fundo_detectada.startswith("#"):
                    cor_fundo_detectada = f"#{cor_fundo_detectada}"
            elif opcoes:
                cor_fundo_detectada = opcoes[0]
                
        if not cor_fundo_detectada:
            return False

        cor_fundo_rgb = hex_para_rgb(cor_fundo_detectada)
            
        elementos_removidos = 0
        
        def filtrar_elementos(elemento):
            nonlocal elementos_removidos
            filhos_mantidos = []
            for filho in elemento:
                if filho.tag.endswith('rect'):
                    cor_hex = filho.get('fill', '').lower().strip()
                    if cor_hex:
                        if cor_hex == cor_fundo_detectada:
                            elementos_removidos += 1
                            continue
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
        
        if interativo and not silencioso:
            print(f"{GREEN}[+] Fundo ({cor_fundo_detectada}) removido! Removidos {elementos_removidos} elementos.{RESET}")
            print(f"{GREEN}[+] SVG sem fundo salvo em: {caminho_saida_completo.name}{RESET}")
        return True
        
    except Exception as erro:
        if not silencioso:
            print(f"{RED}[-] Erro ao ler ou remover fundo do SVG: {erro}{RESET}")
        return False


def processar_imagem_core(
    caminho_entrada: Path,
    caminho_saida: Path,
    redimensionar_str: str | None,
    converter_bits: bool,
    formato_saida: str | None,
    silencioso: bool = False
) -> bool:
    """
    Executa o processamento core de uma imagem, incluindo redimensionamento e conversões de bits/formatos.
    """
    if not caminho_entrada.exists():
        if not silencioso:
            print(f"{RED}[-] Arquivo de entrada não encontrado: {caminho_entrada}{RESET}")
        return False

    if caminho_entrada.suffix.lower() == ".svg":
        if not silencioso:
            print(f"{RED}[-] ERRO: Arquivos SVG não são suportados como imagem de entrada.{RESET}")
        return False

    try:
        with Image.open(caminho_entrada) as imagem_aberta:
            imagem_pil = imagem_aberta.copy()
            
        largura_original, altura_original = imagem_pil.size
        
        if redimensionar_str:
            largura_alvo, altura_alvo = calcular_dimensoes(largura_original, altura_original, redimensionar_str)
            imagem_pil = imagem_pil.resize((largura_alvo, altura_alvo), Image.Resampling.NEAREST)
        
        formato_destino = formato_saida.strip().lower().replace(".", "") if formato_saida else caminho_saida.suffix.strip().lower().replace(".", "")
        if not formato_destino:
            formato_destino = "png"
        
        caminho_saida_completo = caminho_saida.with_suffix(f".{formato_destino}")
        caminho_saida_completo.parent.mkdir(parents=True, exist_ok=True)
        
        # Vetorização para SVG
        if formato_destino == "svg":
            conteudo_svg = converter_imagem_para_svg_blocos(imagem_pil)
            with open(caminho_saida_completo, "w", encoding="utf-8") as arquivo_svg:
                arquivo_svg.write(conteudo_svg)
            if not silencioso:
                print(f"{GREEN}[+] Arquivo vetorizado para SVG com sucesso ➔ '{caminho_saida_completo.name}'{RESET}")
            return True
            
        # Tratamento de incompatibilidades de formato
        if formato_destino in ("jpg", "jpeg"):
            if imagem_pil.mode != "RGB":
                imagem_fundo_branco = Image.new("RGB", imagem_pil.size, (255, 255, 255))
                if imagem_pil.mode == "RGBA":
                    imagem_fundo_branco.paste(imagem_pil, mask=imagem_pil.split()[3])
                else:
                    imagem_fundo_branco.paste(imagem_pil.convert("RGB"))
                imagem_pil = imagem_fundo_branco
        elif converter_bits:
            if imagem_pil.mode not in ("RGB", "RGBA"):
                imagem_pil = imagem_pil.convert("RGBA")
        
        nome_formato_pil = "JPEG" if formato_destino in ("jpg", "jpeg") else formato_destino.upper()
        imagem_pil.save(caminho_saida_completo, format=nome_formato_pil)
        if not silencioso:
            print(f"{GREEN}[+] Arquivo processado com sucesso ➔ '{caminho_saida_completo.name}'{RESET}")
        return True
            
    except Exception as erro:
        if not silencioso:
            print(f"{RED}[-] Erro ao processar a imagem '{caminho_entrada.name}': {erro}{RESET}")
        return False


def processar_imagem_interativo() -> None:
    """
    Fluxo guiado interativo de console para processar uma imagem ou diretório de imagens.
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
            caminho_sugerido = DIRETORIO_SAIDA_PADRAO / f"{caminho_entrada.stem}_sem_fundo.svg"
            print(f"\nCaminho de saída sugerido: {caminho_sugerido}")
            caminho_saida_usuario = input("Pressione Enter para confirmar ou digite o caminho de saída completo: ").strip().strip('"').strip("'")
            caminho_saida = Path(caminho_saida_usuario) if caminho_saida_usuario else caminho_sugerido
            if remover_fundo_svg(caminho_entrada, caminho_saida, interativo=True):
                caminho_absoluto_saida = caminho_saida.with_suffix(".svg").resolve()
                caminho_uri = f"file:///{str(caminho_absoluto_saida).replace(os.sep, '/')}"
                print(f"🖼️ {GREEN}{BOLD}Imagem de Saída:{RESET} {GREEN}{caminho_uri}{RESET}\n")
            return
        else:
            print(f"{YELLOW}[!] Processamento cancelado. SVG não suporta outras conversões aqui.{RESET}")
            return
            
    eh_diretorio = caminho_entrada.is_dir()
    
    redimensionar_str = None
    deseja_redimensionar = input("Deseja redimensionar a(s) imagem(ns)? (s/n): ").strip().lower()
    if deseja_redimensionar in ("s", "sim"):
        redimensionar_str = input("Digite o parâmetro (ex: '2x', '50%%', '256' ou '512x512'): ").strip()
        
    converter_bits = False
    deseja_converter_bits = input("Deseja otimizar para 8-bit seguro (previne crashes no PZ)? (s/n): ").strip().lower()
    if deseja_converter_bits in ("s", "sim"):
        converter_bits = True
        
    formato_saida = None
    deseja_converter_formato = input("Deseja converter o formato de saída? (s/n): ").strip().lower()
    if deseja_converter_formato in ("s", "sim"):
        formato_saida = input("Digite a extensão de destino (ex: png, jpg, webp, svg, tga): ").strip().lower().replace(".", "")
        
    if eh_diretorio:
        print(f"\n[*] Processando lote de imagens no diretório: {caminho_entrada}")
        DIRETORIO_SAIDA_PADRAO.mkdir(parents=True, exist_ok=True)
        
        extensoes_suportadas = (".png", ".jpg", ".jpeg", ".tga", ".webp", ".bmp")
        arquivos_imagem = [arq for arq in caminho_entrada.iterdir() if arq.is_file() and arq.suffix.lower() in extensoes_suportadas]
        
        if not arquivos_imagem:
            print(f"{YELLOW}[!] Nenhuma imagem compatível encontrada na pasta.{RESET}")
            return
            
        sucessos = 0
        for arq in arquivos_imagem:
            ext_final = formato_saida if formato_saida else arq.suffix.replace(".", "")
            caminho_destino_arquivo = DIRETORIO_SAIDA_PADRAO / f"{arq.stem}.{ext_final}"
            if processar_imagem_core(arq, caminho_destino_arquivo, redimensionar_str, converter_bits, formato_saida):
                sucessos += 1
                
        print(f"\n{GREEN}[+] Processamento de lote finalizado! Sucesso: {sucessos}/{len(arquivos_imagem)} imagens.{RESET}")
        caminho_absoluto_saida = DIRETORIO_SAIDA_PADRAO.resolve()
        caminho_uri = f"file:///{str(caminho_absoluto_saida).replace(os.sep, '/')}"
        print(f"📂 {GREEN}{BOLD}Pasta de Saída:{RESET} {GREEN}{caminho_uri}{RESET}\n")
        
    else:
        ext_final = formato_saida if formato_saida else caminho_entrada.suffix.replace(".", "")
        caminho_sugerido = DIRETORIO_SAIDA_PADRAO / f"{caminho_entrada.stem}.{ext_final}"
        
        print(f"\nCaminho de saída sugerido: {caminho_sugerido}")
        caminho_saida_usuario = input("Pressione Enter para confirmar ou digite o caminho de saída completo: ").strip().strip('"').strip("'")
        caminho_saida = Path(caminho_saida_usuario) if caminho_saida_usuario else caminho_sugerido
        caminho_saida.parent.mkdir(parents=True, exist_ok=True)
        
        if processar_imagem_core(caminho_entrada, caminho_saida, redimensionar_str, converter_bits, formato_saida):
            print(f"\n{GREEN}[+] Imagem processada com sucesso!{RESET}")
            caminho_absoluto_saida = caminho_saida.with_suffix(f".{ext_final}").resolve()
            caminho_uri = f"file:///{str(caminho_absoluto_saida).replace(os.sep, '/')}"
            print(f"🖼️ {GREEN}{BOLD}Imagem de Saída:{RESET} {GREEN}{caminho_uri}{RESET}\n")


def main() -> None:
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Processa imagens do mod (redimensionamento, conversão para 8-bit, SVG e remoção de fundo)."
    )
    parser.add_argument("--entrada", "-e", required=True, help="Imagem ou pasta de entrada")
    parser.add_argument("--saida", "-o", help="Caminho do arquivo ou diretório de saída")
    parser.add_argument("--resize", "-r", help="Redimensiona a imagem (Ex: 2x, 50%%, 256, 512x512)")
    parser.add_argument("--converter-bits", action="store_true", help="Otimiza para 8-bit RGBA seguro")
    parser.add_argument("--format", "-f", help="Conversão de formato final (png, jpg, webp, svg, tga)")
    parser.add_argument("--remover-fundo", action="store_true", help="Remove fundo de arquivo SVG")
    parser.add_argument("--fundo-cor", help="Cor hexadecimal do fundo para remoção automática em SVG")
    parser.add_argument("--fundo-tolerancia", type=float, default=15.0, help="Tolerância de cor para remoção (padrão 15.0)")
    parser.add_argument("--json", action="store_true", help="Saída em formato JSON")
    
    args = parser.parse_args()
    
    caminho_entrada = Path(args.entrada)
    if not caminho_entrada.exists():
        if args.json:
            print(json.dumps({"sucesso": False, "erro": f"Caminho de entrada não encontrado: {args.entrada}"}))
            sys.exit(1)
        else:
            print(f"{RED}[-] ERRO: Entrada não encontrada: {args.entrada}{RESET}")
            sys.exit(1)
            
    # Caso seja remoção de fundo em SVG
    if args.remover_fundo or caminho_entrada.suffix.lower() == ".svg" and args.fundo_cor:
        saida_caminho = Path(args.saida) if args.saida else DIRETORIO_SAIDA_PADRAO / f"{caminho_entrada.stem}_sem_fundo.svg"
        sucesso = remover_fundo_svg(
            caminho_entrada,
            saida_caminho,
            cor_fundo=args.fundo_cor,
            tolerancia=args.fundo_tolerancia,
            interativo=not args.json
        )
        if args.json:
            print(json.dumps({
                "sucesso": sucesso,
                "caminho_saida": str(saida_caminho.with_suffix(".svg").resolve()) if sucesso else None
            }))
        sys.exit(0)
        
    eh_diretorio = caminho_entrada.is_dir()
    pasta_saida = Path(args.saida) if args.saida else DIRETORIO_SAIDA_PADRAO
    
    if eh_diretorio:
        pasta_saida.mkdir(parents=True, exist_ok=True)
        extensoes_suportadas = (".png", ".jpg", ".jpeg", ".tga", ".webp", ".bmp")
        arquivos = [arquivo for arquivo in caminho_entrada.iterdir() if arquivo.is_file() and arquivo.suffix.lower() in extensoes_suportadas]
        
        resultados = []
        for arquivo in arquivos:
            ext_final = args.format.strip().lower() if args.format else arquivo.suffix.replace(".", "")
            caminho_destino = pasta_saida / f"{arquivo.stem}.{ext_final}"
            sucesso = processar_imagem_core(
                arquivo,
                caminho_destino,
                args.resize,
                args.converter_bits,
                args.format,
                silencioso=args.json
            )
            resultados.append({
                "imagem_origem": arquivo.name,
                "sucesso": sucesso,
                "caminho_destino": str(caminho_destino.resolve()) if sucesso else None
            })
            
        if args.json:
            print(json.dumps(resultados, indent=2))
            
    else:
        ext_final = args.format.strip().lower() if args.format else caminho_entrada.suffix.replace(".", "")
        caminho_destino = Path(args.saida) if args.saida else DIRETORIO_SAIDA_PADRAO / f"{caminho_entrada.stem}.{ext_final}"
        caminho_destino.parent.mkdir(parents=True, exist_ok=True)
        
        sucesso = processar_imagem_core(
            caminho_entrada,
            caminho_destino,
            args.resize,
            args.converter_bits,
            args.format,
            silencioso=args.json
        )
        
        if args.json:
            print(json.dumps({
                "sucesso": sucesso,
                "caminho_destino": str(caminho_destino.with_suffix(f".{ext_final}").resolve()) if sucesso else None
            }, indent=2))


if __name__ == "__main__":
    if sys.version_info >= (3, 7):
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    if os.name == 'nt':
        os.system('')
        
    main()
