import os
import re
from pathlib import Path

# Configuração dos caminhos do Mod
# Caminho absoluto da raiz do repositório (diretório pai da pasta 'tools')
MOD_PATH = Path(__file__).resolve().parent.parent


print("=" * 70)
print(f"🚀 INICIANDO AUDITORIA DE INTERFACE - LKS SUPERMOD PATCH")
print("=" * 70)

# 1. Encontrar todos os arquivos de código e tradução do mod
arquivos_codigo = []
for ext in ["*.lua", "*.json", "*.txt", "*.md"]:
    arquivos_codigo.extend(MOD_PATH.rglob(ext))

# Unificar todo o texto do código em uma grande string para busca em massa (case-insensitive)
print(f"[INFO] Indexando {len(arquivos_codigo)} arquivos de código para varredura...")
conteudo_total_codigo = ""
for arq in arquivos_codigo:
    try:
        with open(arq, "r", encoding="utf-8", errors="ignore") as f:
            conteudo_total_codigo += f.read().lower()
    except Exception as e:
        print(f"[AVISO] Não foi possível ler o arquivo {arq.name}: {e}")

# 2. Encontrar todas as imagens dentro de qualquer pasta 'ui' ou 'textures'
imagens_interface = []
for ext in ["*.png", "*.jpg", "*.tga"]:
    for img in MOD_PATH.rglob(ext):
        # Filtrar para focar em assets de interface/textura
        if "ui" in img.parts or "textures" in img.parts:
            imagens_interface.append(img)

print(f"[INFO] Identificados {len(imagens_interface)} assets físicos de imagem no diretório.")
print("-" * 70)
print(f"{'ARQUIVO ENCONTRADO':<35} | {'STATUS NO CÓDIGO':<20}")
print("-" * 70)

# 3. Cruzamento de dados (Cross-Reference)
assets_mortos = []
for img in imagens_interface:
    nome_base = img.stem  # Nome sem a extensão .png
    nome_com_ext = img.name  # Nome com a extensão (ex: rrr.png)
    
    # Verifica se o nome da imagem aparece de alguma forma no código
    # Usamos regex simples para garantir que não pegue falsos positivos colados em outras palavras
    pattern = re.escape(nome_base.lower())
    
    if re.search(pattern, conteudo_total_codigo):
        print(f"✅ {nome_com_ext:<33} | Usado/Referenciado")
    else:
        print(f"❌ \033[91m{nome_com_ext:<33}\033[0m | SUSPEITO (MORTO)")
        assets_mortos.append(img)

print("=" * 70)
print(f"📊 RELATÓRIO FINAL DA AUDITORIA:")
print(f"   - Total de imagens analisadas: {len(imagens_interface)}")
print(f"   - Total de Assets Mortos (Lixo de código): {len(assets_mortos)}")
print("=" * 70)

if assets_mortos:
    print("\n[MANUTENÇÃO] Os seguintes arquivos NÃO são usados pelo código e podem ser ignorados no seu Patch:")
    for asset in assets_mortos:
        # Mostra o caminho relativo a partir da pasta common/
        try:
            rel_path = asset.relative_to(MOD_PATH)
            print(f"   ➔ {rel_path}")
        except:
            print(f"   ➔ {asset.name}")
else:
    print("\n🎉 Limpeza perfeita! Todas as imagens na pasta de UI estão sendo usadas no código.")
print("=" * 70)