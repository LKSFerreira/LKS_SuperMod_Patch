import os
import sys

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
{BLUE}{BOLD}╔══════════════════════════════════════════════════════════╗
║                🔍  INSPECTOR DE IMAGENS  🔍              ║
╚══════════════════════════════════════════════════════════╝{RESET}
"""

def check_pillow():
    try:
        from PIL import Image
        return Image
    except ImportError:
        return None

def format_size(size_in_bytes):
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_in_bytes < 1024.0:
            return f"{size_in_bytes:.2f} {unit}"
        size_in_bytes /= 1024.0
    return f"{size_in_bytes:.2f} TB"

def print_image_properties(file_path, idx, Image_lib):
    filename = os.path.basename(file_path)
    abs_path = os.path.abspath(file_path)
    directory = os.path.dirname(abs_path)
    file_size = format_size(os.path.getsize(file_path))
    
    # Valores Padrão / Sem Pillow
    dimensions = f"{YELLOW}N/A (Requer Pillow){RESET}"
    img_format = f"{YELLOW}N/A (Requer Pillow){RESET}"
    img_mode = f"{YELLOW}N/A (Requer Pillow){RESET}"
    alpha_status = f"{YELLOW}N/A (Requer Pillow){RESET}"
    warning = ""

    if Image_lib is None:
        warning = f"{RED}⚠️  Instale a biblioteca Pillow ('pip install Pillow') para mais detalhes.{RESET}"
    else:
        try:
            with Image_lib.open(file_path) as img:
                dimensions = f"{GREEN}{img.width}x{img.height} pixels{RESET}"
                img_format = f"{GREEN}{img.format}{RESET}"
                img_mode = f"{GREEN}{img.mode}{RESET}"
                
                # Determina canal alpha
                has_alpha = False
                if img.mode in ('RGBA', 'LA', 'PA'):
                    has_alpha = True
                elif img.mode == 'P' and 'transparency' in img.info:
                    has_alpha = True
                elif 'A' in img.mode:
                    has_alpha = True
                    
                if has_alpha:
                    alpha_status = f"{GREEN}🟢 Sim ({img.mode}/Transparência){RESET}"
                else:
                    alpha_status = f"{RED}🔴 Não{RESET}"
        except Exception as e:
            warning = f"{RED}❌ Erro de Leitura: {e}{RESET}"

    # Renderiza com borda lateral esquerda (estilo bloco moderno)
    header_text = f" 📄 Arquivo #{idx}: {filename} "
    
    print(f"{BLUE}┌──{RESET}{CYAN}{BOLD}{header_text}{RESET}{BLUE}─" + "─" * 20 + f"{RESET}")
    
    # Função auxiliar para manter alinhamento
    def print_row(emoji, label, value):
        print(f"{BLUE}│{RESET}  {emoji} {BOLD}{label:<20}:{RESET} {value}")

    print_row("📍", "Caminho Completo", f"{GRAY}{abs_path}{RESET}")
    print_row("📁", "Diretório", f"{GRAY}{directory}{RESET}")
    print_row("💾", "Tamanho do Arquivo", f"{YELLOW}{file_size}{RESET}")
    print_row("📏", "Dimensões", dimensions)
    print_row("⚙️ ", "Formato", img_format)
    print_row("🎨", "Modo de Cor", img_mode)
    print_row("🌈", "Possui Canal Alpha?", alpha_status)
    
    if warning:
        print_row("⚠️ ", "Aviso", warning)
        
    print(f"{BLUE}└───{RESET}\n")

def search_and_inspect(target, search_dir="."):
    Image_lib = check_pillow()
    
    # Verifica se target é um caminho direto absoluto ou relativo para um diretório
    direct_dir = None
    if os.path.isabs(target) and os.path.isdir(target):
        direct_dir = target
    else:
        potential_path = os.path.join(search_dir, target)
        if os.path.isdir(potential_path):
            direct_dir = potential_path

    matching_dirs = []
    if direct_dir:
        matching_dirs.append(direct_dir)
    else:
        # Busca diretórios que coincidam com o nome (case-insensitive)
        for root, dirs, files in os.walk(search_dir):
            for d in dirs:
                if d.lower() == target.lower():
                    matching_dirs.append(os.path.join(root, d))
                    
    # Se encontramos diretórios correspondentes, inspeciona todas as imagens dentro deles
    if matching_dirs:
        image_extensions = ('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tga', '.webp')
        all_images = []
        for m_dir in matching_dirs:
            for root, dirs, files in os.walk(m_dir):
                for file in files:
                    if file.lower().endswith(image_extensions):
                        all_images.append(os.path.join(root, file))
        
        if all_images:
            print(f"\n{GREEN}✨ Encontrado(s) {len(matching_dirs)} diretório(s) correspondente(s) com {len(all_images)} imagem(ns):{RESET}\n")
            for idx, img_path in enumerate(all_images, 1):
                print_image_properties(img_path, idx, Image_lib)
            return
        else:
            print(f"\n{YELLOW}⚠️  Diretório(s) encontrado(s), mas nenhuma imagem foi detectada.{RESET}\n")
            return

    # Caso contrário, busca por arquivos correspondentes (comportamento original)
    matches = []
    for root, dirs, files in os.walk(search_dir):
        for file in files:
            # Caso 1: Match exato do nome com extensão
            if file.lower() == target.lower():
                matches.append(os.path.join(root, file))
            # Caso 2: Match apenas pelo nome do arquivo (sem extensão) se o usuário não digitou extensão
            elif '.' not in target and os.path.splitext(file)[0].lower() == target.lower():
                # Garante que seja um formato de imagem comum
                ext = os.path.splitext(file)[1].lower()
                if ext in ('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tga', '.webp'):
                    matches.append(os.path.join(root, file))
                    
    if not matches:
        print(f"\n{RED}❌ Nenhum arquivo ou diretório encontrado com o nome '{target}' no diretório.{RESET}\n")
        return

    print(f"\n{GREEN}✨ Encontrado(s) {len(matches)} arquivo(s) correspondente(s):{RESET}\n")
    for idx, match_path in enumerate(matches, 1):
        print_image_properties(match_path, idx, Image_lib)

if __name__ == "__main__":
    print(BANNER)
    
    # Verifica se o nome do arquivo/diretório foi passado como argumento de linha de comando
    if len(sys.argv) > 1:
        target_file = sys.argv[1]
    else:
        target_file = input(f"{BOLD}Digite o nome do arquivo ou diretório de imagens (ex: icone.png ou new_ui):{RESET} ").strip()
        
    if not target_file:
        print(f"{RED}Nome inválido.{RESET}")
        sys.exit(1)
        
    # Executa a busca a partir do diretório do script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    search_and_inspect(target_file, script_dir)
