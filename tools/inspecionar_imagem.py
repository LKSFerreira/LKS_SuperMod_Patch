# -*- coding: utf-8 -*-
"""
================================================================================
🔍 INSPEÇÃO DE IMAGEM - LKS SUPERMOD PATCH
================================================================================
Módulo para inspecionar propriedades de cor, bit depth, dimensões e canais de imagens.
Pode ser executado diretamente via CLI com saída formatada ou JSON, ou importado.
"""

import os
import sys
import json
from pathlib import Path
from PIL import Image

# Cores do terminal para feedback textual
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RED = "\033[31m"
GRAY = "\033[90m"


def obter_profundidade_bits_png_raw(caminho_arquivo: Path | str) -> int | None:
    """
    Lê os metadados do cabeçalho IHDR do PNG para obter a profundidade por canal diretamente.

    **Exemplo:**

    .. code-block:: python

        bits = obter_profundidade_bits_png_raw("minha_imagem.png")
    """
    try:
        with open(caminho_arquivo, 'rb') as arquivo_binario:
            cabecalho = arquivo_binario.read(30)
            if len(cabecalho) < 26 or cabecalho[:8] != b'\x89PNG\r\n\x1a\n' or cabecalho[12:16] != b'IHDR':
                return None
            return cabecalho[24]  # Posição do bit depth no cabeçalho IHDR
    except Exception:
        return None


def inspecionar_propriedades_imagem(
    caminho_arquivo: Path | str,
    indice: int = 1,
    silencioso: bool = False
) -> dict | None:
    """
    Exibe e valida as propriedades de cor, bit depth e canais de uma imagem.
    Retorna um dicionário contendo os dados inspecionados.

    **Exemplo:**

    .. code-block:: python

        dados = inspecionar_propriedades_imagem("ui/painel.png")
    """
    caminho = Path(caminho_arquivo)
    if not caminho.exists():
        if not silencioso:
            print(f"{RED}[-] Arquivo não encontrado: {caminho}{RESET}")
        return None
        
    tamanho_bytes = caminho.stat().st_size
    tamanho_formatado = f"{tamanho_bytes / 1024:.2f} KB"
    
    try:
        with Image.open(caminho) as imagem:
            largura, altura = imagem.size
            dimensoes = f"{largura}x{altura} pixels"
            formato = imagem.format
            modo = imagem.mode
            
            # Detecção de canais alpha
            tem_alpha = "Sim" if (imagem.mode in ('RGBA', 'LA', 'PA') or (imagem.mode == 'P' and 'transparency' in imagem.info)) else "Não"
            
            # Detecção de bits por canal (bpc)
            bpc_raw = obter_profundidade_bits_png_raw(caminho) if formato == 'PNG' else None
            is_16_bit = (bpc_raw == 16 or '16' in imagem.mode or imagem.mode in ('I', 'F'))
            
            bpc_str = f"{bpc_raw} bits/canal" if bpc_raw else f"{imagem.mode} (bpc baseado no modo)"
            
            dados_resultado = {
                "nome": caminho.name,
                "caminho": str(caminho.resolve()),
                "tamanho_bytes": tamanho_bytes,
                "tamanho_formatado": tamanho_formatado,
                "largura": largura,
                "altura": altura,
                "dimensoes": dimensoes,
                "formato": formato,
                "modo_cor": modo,
                "bits_por_canal": bpc_raw,
                "bits_por_canal_str": bpc_str,
                "is_16_bit": is_16_bit,
                "tem_alpha": tem_alpha == "Sim"
            }
            
            if not silencioso:
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
                
            return dados_resultado
            
    except Exception as erro:
        if not silencioso:
            print(f"{RED}[-] Erro ao ler a imagem {caminho.name}: {erro}{RESET}\n")
        return {
            "nome": caminho.name,
            "caminho": str(caminho.resolve()),
            "erro": str(erro)
        }


def main() -> None:
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Inspeciona propriedades físicas e de canal de uma imagem ou pasta de imagens."
    )
    parser.add_argument("--caminho", "-c", required=True, help="Caminho do arquivo de imagem ou diretório a inspecionar")
    parser.add_argument("--json", action="store_true", help="Retorna saída estruturada estritamente em formato JSON")
    
    args = parser.parse_args()
    
    caminho = Path(args.caminho)
    if not caminho.exists():
        if args.json:
            print(json.dumps({"sucesso": False, "erro": f"Caminho não encontrado: {args.caminho}"}))
            sys.exit(1)
        else:
            print(f"{RED}[-] ERRO: Caminho não encontrado: {args.caminho}{RESET}")
            sys.exit(1)
            
    if caminho.is_file():
        resultado = inspecionar_propriedades_imagem(caminho, indice=1, silencioso=args.json)
        if args.json:
            print(json.dumps(resultado, indent=2))
    else:
        resultados = []
        extensoes_suportadas = ('.png', '.jpg', '.jpeg', '.tga', '.webp', '.bmp')
        arquivos = [arquivo for arquivo in caminho.iterdir() if arquivo.is_file() and arquivo.suffix.lower() in extensoes_suportadas]
        
        for idx, arquivo in enumerate(arquivos, 1):
            resultado = inspecionar_propriedades_imagem(arquivo, indice=idx, silencioso=args.json)
            if resultado:
                resultados.append(resultado)
                
        if args.json:
            print(json.dumps(resultados, indent=2))


if __name__ == "__main__":
    if sys.version_info >= (3, 7):
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    if os.name == 'nt':
        os.system('')
        
    main()
