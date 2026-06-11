from __future__ import annotations
import os
import sys
import argparse
from pathlib import Path

# Tentativa de importação do Tkinter para suporte a explorador de arquivos gráfico
try:
    import tkinter as tk
    from tkinter import filedialog
    TK_AVAILABLE = True
except ImportError:
    TK_AVAILABLE = False

# Corrige problemas de codificação Unicode no terminal do Windows
if sys.version_info >= (3, 7):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

# Ativa suporte a códigos ANSI de cor no terminal Windows
if os.name == 'nt':
    os.system('')

# Códigos ANSI para estilização
RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
MAGENTA = "\033[35m"
RED = "\033[31m"
GRAY = "\033[90m"

BANNER = f"""
{MAGENTA}{BOLD}╔══════════════════════════════════════════════════════════╗
║             🎨  CONVERSOR DE IMAGEM PARA SVG  🎨         ║
║                      (VETORIZAÇÃO REAL)                  ║
╚══════════════════════════════════════════════════════════╝{RESET}
"""

def check_pillow():
    try:
        from PIL import Image
        return Image
    except ImportError:
        return None

def format_size(size_in_bytes):
    for unit in ['B', 'KB', 'MB']:
        if size_in_bytes < 1024.0:
            return f"{size_in_bytes:.2f} {unit}"
        size_in_bytes /= 1024.0
    return f"{size_in_bytes:.2f} GB"

def svg_header(width: int, height: int, view_w: int, view_h: int) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {view_w} {view_h}" shape-rendering="crispEdges">\n'
    )

def rgba_to_hex(r: int, g: int, b: int) -> str:
    return f"#{r:02x}{g:02x}{b:02x}"

def calculate_dimensions(w: int, h: int, resize_str: str) -> tuple[int, int]:
    resize_str = resize_str.strip().lower()
    if resize_str.endswith('x'):
        factor = float(resize_str[:-1])
        return max(1, int(w * factor)), max(1, int(h * factor))
    elif resize_str.endswith('%'):
        factor = float(resize_str[:-1]) / 100.0
        return max(1, int(w * factor)), max(1, int(h * factor))
    else:
        new_w = int(resize_str)
        ratio = new_w / w
        return new_w, max(1, int(h * ratio))

def image_to_svg_blocks(img, target_w: int | None = None, target_h: int | None = None, view_w: int | None = None, view_h: int | None = None, show_progress: bool = True) -> tuple[str, int]:
    img = img.convert("RGBA")
    img_w, img_h = img.size
    px = img.load()
    
    svg_w = target_w if target_w is not None else img_w
    svg_h = target_h if target_h is not None else img_h
    vw = view_w if view_w is not None else img_w
    vh = view_h if view_h is not None else img_h
    
    parts = [svg_header(svg_w, svg_h, vw, vh)]
    rect_count = 0

    if show_progress:
        print(f"{CYAN}⚡ Processando pixels e otimizando formas geométricas...{RESET}")
    
    for y in range(img_h):
        if show_progress and img_h > 100 and y % (img_h // 10 or 1) == 0:
            percent = int((y / img_h) * 100)
            print(f"   {GRAY}⏳ Progresso: {percent}% concluído...{RESET}", end="\r")

        x = 0
        while x < img_w:
            r, g, b, a = px[x, y]
            start = x
            x += 1

            while x < img_w and px[x, y] == (r, g, b, a):
                x += 1

            width = x - start

            if a == 0:
                continue

            color = rgba_to_hex(r, g, b)
            opacity = a / 255
            rect_count += 1

            if opacity >= 0.999:
                parts.append(
                    f'<rect x="{start}" y="{y}" width="{width}" height="1" fill="{color}" />\n'
                )
            else:
                parts.append(
                    f'<rect x="{start}" y="{y}" width="{width}" height="1" fill="{color}" fill-opacity="{opacity:.6f}" />\n'
                )

    if show_progress and img_h > 100:
        print(f"   {GRAY}⏳ Progresso: 100% concluído!      {RESET}\n")

    parts.append("</svg>\n")
    return "".join(parts), rect_count

def process_image(entrada_path: Path, saida_path: Path, resize_str: str | None, resize_timing: str | None, quantize_colors: int | None, Image_lib, show_progress: bool = True, show_stats: bool = True):
    if not entrada_path.exists():
        raise FileNotFoundError(f"O arquivo '{entrada_path}' não foi encontrado.")
        
    if entrada_path.is_dir():
        raise IsADirectoryError(f"'{entrada_path}' é um diretório, não um arquivo de imagem válido.")

    try:
        img = Image_lib.open(entrada_path)
    except Exception:
        raise ValueError(f"O arquivo '{entrada_path.name}' não parece ser uma imagem válida ou suportada.")

    orig_width, orig_height = img.size
    orig_size = format_size(entrada_path.stat().st_size)

    target_w, target_h = orig_width, orig_height
    was_resized = False

    if resize_str:
        try:
            target_w, target_h = calculate_dimensions(orig_width, orig_height, resize_str)
            was_resized = True
        except Exception as e:
            if show_progress:
                print(f"\n{YELLOW}⚠️  Erro ao analisar formato de redimensionamento '{resize_str}': {e}. Mantendo tamanho original.{RESET}")
            was_resized = False

    if was_resized and (resize_timing == 'before' or resize_timing is None):
        img = img.resize((target_w, target_h), Image_lib.Resampling.NEAREST)

    if quantize_colors and quantize_colors > 1:
        base = img.convert("RGBA")
        pal = base.convert("P", palette=Image_lib.Palette.ADAPTIVE, colors=quantize_colors)
        img = pal.convert("RGBA")

    if was_resized and resize_timing == 'after':
        svg_content, rect_count = image_to_svg_blocks(img, target_w=target_w, target_h=target_h, view_w=orig_width, view_h=orig_height, show_progress=show_progress)
        final_pixels_for_ratio = orig_width * orig_height
    else:
        svg_content, rect_count = image_to_svg_blocks(img, show_progress=show_progress)
        final_pixels_for_ratio = img.width * img.height

    saida_path.write_text(svg_content, encoding="utf-8")
    svg_size = format_size(saida_path.stat().st_size)
    
    reduction = (1 - (rect_count / final_pixels_for_ratio)) * 100 if final_pixels_for_ratio > 0 else 0

    if show_stats:
        print(f"{GREEN}┌──{RESET} {GREEN}{BOLD}✨ VETORIZAÇÃO CONCLUÍDA COM SUCESSO! ✨{RESET}{GREEN} ────────────────────{RESET}")
        
        def print_row(emoji, label, value):
            print(f"{GREEN}│{RESET}  {emoji} {BOLD}{label:<22}:{RESET} {value}")

        print_row("📂", "Imagem Original", entrada_path.name)
        print_row("📐", "Dimensões Originais", f"{orig_width}x{orig_height} px")
        if was_resized:
            flow_desc = "Antes da vetorização" if resize_timing == "before" else "Depois da vetorização"
            print_row("📏", "Novas Dimensões", f"{target_w}x{target_h} px")
            print_row("⚙️ ", "Redimensionamento", flow_desc)
        print_row("🎨", "Formatos e Cores", f"Modo {img.mode}")
        print_row("💾", "Tamanho Original", orig_size)
        print_row("🖼️ ", "Vetor SVG Criado", saida_path.name)
        print_row("📊", "Tamanho do SVG", svg_size)
        print_row("🔲", "Total de Retângulos", rect_count)
        print_row("🚀", "Otimização Vetorial", f"{reduction:.2f}% de redução")
        print(f"{GREEN}└───{RESET}\n")
        print(f"{BLUE}💡 DICA: O arquivo SVG gerado mantém as bordas nítidas ao dar zoom (perfeito para pixel art)!{RESET}\n")

def get_interactive_input(prompt_text: str) -> str:
    try:
        val = input(prompt_text).strip()
        if val.lower() in ('sair', 'exit', 'q', 'quit'):
            print(f"\n{BLUE}👋 Saindo do programa. Até logo!{RESET}\n")
            sys.exit(0)
        return val
    except KeyboardInterrupt:
        raise KeyboardInterrupt

def select_file_via_explorer() -> str:
    if not TK_AVAILABLE:
        print(f"\n{RED}⚠️  Interface gráfica (Tkinter) indisponível. Por favor, digite o caminho manualmente.{RESET}")
        return ""
    try:
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        file_path = filedialog.askopenfilename(
            title="Selecione a Imagem Original",
            filetypes=[
                ("Imagens", "*.png *.jpg *.jpeg *.webp *.gif *.bmp"),
                ("Todos os arquivos", "*.*")
            ]
        )
        root.destroy()
        return file_path
    except Exception as e:
        print(f"\n{RED}⚠️  Falha ao abrir explorador de arquivos: {e}. Digite o caminho manualmente.{RESET}")
        return ""

def select_directory_via_explorer(title: str = "Selecione o diretório") -> str:
    if not TK_AVAILABLE:
        print(f"\n{RED}⚠️  Interface gráfica (Tkinter) indisponível. Por favor, digite o caminho manualmente.{RESET}")
        return ""
    try:
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        dir_path = filedialog.askdirectory(title=title)
        root.destroy()
        return dir_path
    except Exception as e:
        print(f"\n{RED}⚠️  Falha ao abrir explorador de pastas: {e}. Digite o caminho manualmente.{RESET}")
        return ""

def run_interactive(Image_lib):
    print(f"{YELLOW}Modo Interativo Ativado. (Digite 'sair' a qualquer momento para encerrar){RESET}\n")
    
    # Menu Inicial: Tipo de processamento
    print(f"{BOLD}Escolha o modo de conversão:{RESET}")
    print("  [1] Arquivo Único (Vetorizar apenas uma imagem)")
    print("  [2] Em Lote (Vetorizar todas as imagens de uma pasta)")
    
    while True:
        opcao_modo = get_interactive_input(f"\n{BOLD}Selecione a opção (1 ou 2):{RESET} ")
        if opcao_modo in ("1", "2"):
            break
        print(f"{RED}Opção inválida. Selecione 1 ou 2.{RESET}")

    # --- MODO 1: ARQUIVO ÚNICO ---
    if opcao_modo == "1":
        entrada_path = None
        while True:
            prompt_str = f"📂 {BOLD}Digite o nome, caminho ou 9 para abrir o explorador de arquivos:{RESET} "
            entrada_input = get_interactive_input(prompt_str)
            if not entrada_input:
                print(f"{RED}Entrada inválida. Tente novamente.{RESET}")
                continue
                
            if entrada_input == "9":
                print(f"{CYAN}📂 Selecionando imagem via explorador...{RESET}")
                file_selected = select_file_via_explorer()
                if file_selected:
                    entrada_path = Path(file_selected)
                    print(f"{GREEN}✓ Selecionado: {entrada_path}{RESET}")
                    break
                else:
                    print(f"{YELLOW}Nenhum arquivo selecionado via explorador. Tente digitar.{RESET}")
                    continue

            temp_path = Path(entrada_input)
            if not temp_path.exists():
                print(f"{YELLOW}⚠️  Arquivo não encontrado diretamente. Buscando no repositório...{RESET}")
                script_dir = Path(__file__).parent
                matches = list(script_dir.rglob(entrada_input))
                if not matches:
                    matches = [p for p in script_dir.rglob("*") if p.is_file() and p.stem.lower() == entrada_input.lower()]
                    
                if not matches:
                    print(f"{RED}❌ Arquivo não encontrado. Digite um caminho ou nome válido.{RESET}")
                    continue
                    
                if len(matches) == 1:
                    entrada_path = matches[0]
                    print(f"{GREEN}✓ Encontrado: {entrada_path}{RESET}")
                    break
                
                print(f"\n{YELLOW}⚠️  Encontrados múltiplos arquivos correspondentes no repositório:{RESET}")
                for i, match in enumerate(matches, 1):
                    print(f"   {BOLD}[{i}]{RESET} {GRAY}{match.relative_to(script_dir)}{RESET}")
                print()
                
                while True:
                    escolha = get_interactive_input(f"{BOLD}Digite o número do arquivo que deseja utilizar (1 a {len(matches)}):{RESET} ")
                    try:
                        num_idx = int(escolha) - 1
                        if 0 <= num_idx < len(matches):
                            entrada_path = matches[num_idx]
                            print(f"{GREEN}✓ Escolhido: {entrada_path}{RESET}")
                            break
                        else:
                            print(f"{RED}Número fora do intervalo. Escolha entre 1 e {len(matches)}.{RESET}")
                    except ValueError:
                        print(f"{RED}Escolha inválida. Digite um número.{RESET}")
                break
            else:
                entrada_path = temp_path
                break
                
        # Ordem de redimensionamento
        resize_str = None
        resize_timing = None
        print(f"\n{BOLD}📐 Ordem/Fluxo de Redimensionamento:{RESET}")
        print("  [1] Redimensionar ANTES da vetorização (Recomendado para Pixel Arts grandes. Otimiza tamanho do SVG)")
        print("  [2] Redimensionar DEPOIS da vetorização (Altera o tamanho do SVG preservando todos os detalhes)")
        print("  [3] Não redimensionar (Manter dimensões originais)")
        
        while True:
            opcao_res = get_interactive_input(f"\n{BOLD}Selecione a opção (1, 2 ou 3):{RESET} ")
            if opcao_res == "1":
                resize_timing = "before"
                break
            elif opcao_res == "2":
                resize_timing = "after"
                break
            elif opcao_res == "3":
                resize_timing = None
                break
            print(f"{RED}Opção inválida. Digite 1, 2 ou 3.{RESET}")
                
        if resize_timing:
            while True:
                resize_input = get_interactive_input(f"📏 {BOLD}Redimensionar para? (Ex: '256' para largura, '2x' para duplicar, '0.5x' para metade):{RESET} ")
                if not resize_input:
                    print(f"{RED}Você deve digitar um valor de redimensionamento.{RESET}")
                    continue
                resize_str = resize_input
                break

        # Quantização de cores
        quantize_colors = None
        quantize_input = get_interactive_input(f"\n🎨 {BOLD}Reduzir paleta para N cores? (Enter para original, ex: 16):{RESET} ")
        if quantize_input:
            try:
                quantize_colors = int(quantize_input)
                if quantize_colors <= 1:
                    print(f"{YELLOW}Valor inválido. Mantendo cores originais.{RESET}")
                    quantize_colors = None
            except ValueError:
                print(f"{YELLOW}Valor inválido. Mantendo cores originais.{RESET}")

        # Caminho de saída
        saida_input = get_interactive_input(f"\n💾 {BOLD}Caminho do SVG de saída ou 9 para abrir o explorador (Enter para mesma pasta):{RESET} ")
        if saida_input == "9":
            print(f"{CYAN}📂 Selecionando local de destino via explorador...{RESET}")
            if not TK_AVAILABLE:
                print(f"{RED}⚠️  Interface gráfica indisponível. Usando padrão.{RESET}")
                saida_path = entrada_path.with_suffix(".svg")
            else:
                root = tk.Tk()
                root.withdraw()
                root.attributes("-topmost", True)
                save_selected = filedialog.asksaveasfilename(
                    title="Salvar SVG como",
                    defaultextension=".svg",
                    filetypes=[("Arquivos SVG", "*.svg")],
                    initialfile=entrada_path.with_suffix(".svg").name
                )
                root.destroy()
                saida_path = Path(save_selected) if save_selected else entrada_path.with_suffix(".svg")
        elif saida_input:
            saida_path = Path(saida_input)
        else:
            saida_path = entrada_path.with_suffix(".svg")

        # Processa a imagem única
        try:
            process_image(entrada_path, saida_path, resize_str, resize_timing, quantize_colors, Image_lib)
        except Exception as e:
            print(f"\n{RED}❌ ERRO: {e}{RESET}\n")

    # --- MODO 2: CONVERSÃO EM LOTE ---
    else:
        print(f"\n{CYAN}📂 Selecione a pasta de origem onde estão as imagens...{RESET}")
        dir_origem = select_directory_via_explorer("Selecione o diretório com as imagens originais")
        
        if not dir_origem:
            # Se cancelar/não achar, tenta pedir texto
            dir_origem = get_interactive_input(f"📂 {BOLD}Digite o caminho da pasta de origem:{RESET} ")
            if not dir_origem or not os.path.isdir(dir_origem):
                print(f"{RED}❌ Pasta de origem inválida. Cancelando lote.{RESET}\n")
                return

        path_origem = Path(dir_origem)
        # Varre arquivos de imagem suportados
        suportados = ('.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp')
        imagens = [p for p in path_origem.iterdir() if p.is_file() and p.suffix.lower() in suportados]

        if not imagens:
            print(f"\n{RED}❌ Nenhuma imagem suportada ({', '.join(suportados)}) foi encontrada em '{path_origem}'.{RESET}\n")
            return

        print(f"\n{GREEN}✓ Encontrada(s) {len(imagens)} imagem(ns) para processar.{RESET}")

        # Configurações do lote (iguais para todas as imagens)
        resize_str = None
        resize_timing = None
        print(f"\n{BOLD}📐 Ordem/Fluxo de Redimensionamento para o Lote:{RESET}")
        print("  [1] Redimensionar ANTES da vetorização (Recomendado para Pixel Arts. Otimiza tamanho do SVG)")
        print("  [2] Redimensionar DEPOIS da vetorização (Altera o tamanho do SVG preservando detalhes originais)")
        print("  [3] Não redimensionar (Manter dimensões originais)")
        
        while True:
            opcao_res = get_interactive_input(f"\n{BOLD}Selecione a opção (1, 2 ou 3):{RESET} ")
            if opcao_res == "1":
                resize_timing = "before"
                break
            elif opcao_res == "2":
                resize_timing = "after"
                break
            elif opcao_res == "3":
                resize_timing = None
                break
            print(f"{RED}Opção inválida. Digite 1, 2 ou 3.{RESET}")
                
        if resize_timing:
            while True:
                resize_input = get_interactive_input(f"📏 {BOLD}Redimensionar para? (Ex: '256' para largura, '2x' para duplicar, '0.5x' para metade):{RESET} ")
                if not resize_input:
                    print(f"{RED}Você deve digitar um valor de redimensionamento.{RESET}")
                    continue
                resize_str = resize_input
                break

        # Quantização
        quantize_colors = None
        quantize_input = get_interactive_input(f"\n🎨 {BOLD}Reduzir paleta para N cores? (Enter para original, ex: 16):{RESET} ")
        if quantize_input:
            try:
                quantize_colors = int(quantize_input)
                if quantize_colors <= 1:
                    print(f"{YELLOW}Valor inválido. Mantendo cores originais.{RESET}")
                    quantize_colors = None
            except ValueError:
                print(f"{YELLOW}Valor inválido. Mantendo cores originais.{RESET}")

        # Pasta de destino
        print(f"\n{CYAN}📂 Selecione a pasta onde os arquivos SVG serão salvos...{RESET}")
        dir_destino = select_directory_via_explorer("Selecione o diretório para salvar os arquivos SVG")
        
        if not dir_destino:
            dir_destino = get_interactive_input(f"💾 {BOLD}Digite o caminho da pasta de destino:{RESET} ")
            if not dir_destino:
                print(f"{RED}❌ Pasta de destino inválida. Cancelando lote.{RESET}\n")
                return
                
        path_destino = Path(dir_destino)
        path_destino.mkdir(parents=True, exist_ok=True)

        print(f"\n{CYAN}🚀 Iniciando processamento do lote...{RESET}")
        sucessos = 0
        falhas = 0

        for i, img_path in enumerate(imagens, 1):
            out_name = img_path.stem + ".svg"
            out_path = path_destino / out_name
            
            print(f"\n[{i}/{len(imagens)}] 🖼️  Processando: {img_path.name} -> {out_name}")
            try:
                # Processa silenciosamente sem desenhar o card grande por arquivo, apenas o progresso
                process_image(img_path, out_path, resize_str, resize_timing, quantize_colors, Image_lib, show_progress=True, show_stats=False)
                print(f"{GREEN}✓ Sucesso!{RESET}")
                sucessos += 1
            except Exception as e:
                print(f"{RED}❌ Falha ao processar {img_path.name}: {e}{RESET}")
                falhas += 1

        # Painel resumido do lote
        print(f"\n{GREEN}┌──{RESET} {GREEN}{BOLD}✨ CONVERSÃO EM LOTE CONCLUÍDA! ✨{RESET}{GREEN} ──────────────────────────{RESET}")
        
        def print_batch_row(emoji, label, value):
            print(f"{GREEN}│{RESET}  {emoji} {BOLD}{label:<24}:{RESET} {value}")

        print_batch_row("📁", "Pasta de Origem", path_origem.name)
        print_batch_row("💾", "Pasta de Destino", path_destino.name)
        print_batch_row("🖼️ ", "Total de Arquivos", len(imagens))
        print_batch_row("✓ ", "Convertidos com Sucesso", sucessos)
        print_batch_row("❌", "Falhas no Processamento", falhas)
        print(f"{GREEN}└───{RESET}\n")

def run_cli(args, Image_lib):
    entrada_path = Path(args.entrada)
    saida_path = Path(args.saida) if args.saida else entrada_path.with_suffix(".svg")
    
    try:
        process_image(entrada_path, saida_path, args.resize, args.resize_timing, args.quantize, Image_lib)
    except Exception as e:
        print(f"\n{RED}❌ ERRO: {e}{RESET}\n")
        sys.exit(1)

def main() -> None:
    try:
        print(BANNER)
        
        Image_lib = check_pillow()
        if Image_lib is None:
            print(f"{RED}❌ ERRO: A biblioteca 'Pillow' (PIL) é necessária para ler e redimensionar imagens.{RESET}")
            print(f"Por favor, instale executando: {YELLOW}pip install Pillow{RESET}\n")
            sys.exit(1)

        # Se não houver argumentos, entra no modo interativo
        if len(sys.argv) == 1:
            run_interactive(Image_lib)
        else:
            parser = argparse.ArgumentParser(
                description=(
                    f"{MAGENTA}{BOLD}🎨 CONVERSOR RASTER PARA SVG VETORIAL REAL{RESET}\n\n"
                    "Converte imagens de pixel (PNG, JPG, WebP, etc.) em formas geométricas reais (<rect>).\n"
                    "O algoritmo agrupa pixels horizontais de mesma cor em retângulos vetoriais, mantendo\n"
                    "a nitidez perfeita (crispEdges) ao dar zoom. Ideal para UI de mods, ícones e Pixel Art."
                ),
                epilog=(
                    f"{CYAN}{BOLD}EXEMPLOS DE USO:{RESET}\n"
                    "  1. Converter mantendo o tamanho e cores originais:\n"
                    "     python imagem_para_svg.py icone.png\n\n"
                    "  2. Converter definindo um nome específico de saída:\n"
                    "     python imagem_para_svg.py icone.png -o meu_vetor.svg\n\n"
                    "  3. Ampliar a imagem em 2x antes da vetorização:\n"
                    "     python imagem_para_svg.py icone.png --resize 2x --resize-timing before\n\n"
                    "  4. Reduzir a largura de exibição do SVG resultante para 128px após a vetorização:\n"
                    "     python imagem_para_svg.py icone.png --resize 128 --resize-timing after\n\n"
                    "  5. Reduzir a paleta para 16 cores (ótimo para reduzir tamanho do SVG):\n"
                    "     python imagem_para_svg.py icone.png --quantize 16\n\n"
                    f"{YELLOW}💡 DICA: Sem argumentos, o programa roda no Modo Interativo Passo-a-Passo!{RESET}"
                ),
                formatter_class=argparse.RawTextHelpFormatter
            )
            parser.add_argument("entrada", help="Caminho do arquivo de imagem original (PNG, JPG, WebP, GIF, etc.)")
            parser.add_argument("-o", "--saida", help="Caminho/nome do arquivo SVG final a ser gerado\n(padrão: mesmo nome da imagem com extensão .svg)")
            parser.add_argument(
                "--resize",
                type=str,
                default=None,
                help=(
                    "Redimensiona a imagem usando interpolação Nearest Neighbor (Vizinho Próximo).\n"
                    "Mantém a pixel art 100%% nítida ao ampliar ou reduzir.\n"
                    "Formatos aceitos:\n"
                    "  - Largura em pixels: ex. '256' (altura é calculada proporcionalmente)\n"
                    "  - Multiplicador: ex. '2x' (dobra), '0.5x' (metade)\n"
                    "  - Porcentagem: ex. '200%%' (dobra), '50%%' (metade)"
                )
            )
            parser.add_argument(
                "--resize-timing",
                choices=["before", "after"],
                default="before",
                help=(
                    "Define quando executar o redimensionamento:\n"
                    "  - 'before': Redimensiona os pixels originais ANTES da vetorização (SVG menor)\n"
                    "  - 'after': Vetoriza a imagem original, mas altera o viewBox/viewport do SVG resultante (preserva detalhes)"
                )
            )
            parser.add_argument(
                "--quantize",
                type=int,
                default=None,
                help=(
                    "Reduz a paleta de cores da imagem para N cores únicas adaptativas.\n"
                    "Ajuda a reduzir significativamente o tamanho do arquivo SVG gerado."
                )
            )

            args = parser.parse_args()
            run_cli(args, Image_lib)
    except KeyboardInterrupt:
        print(f"\n\n{BLUE}👋 Conversão cancelada pelo usuário. Até mais!{RESET}\n")
        sys.exit(0)

if __name__ == "__main__":
    main()