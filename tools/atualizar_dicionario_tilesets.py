# -*- coding: utf-8 -*-
"""
================================================================================
🧱 ATUALIZADOR DO DICIONÁRIO DE TILESETS - LKS SUPERMOD PATCH
================================================================================
Autor: LKS FERREIRA
Versão: 1.1 (Project Zomboid Build 42)
Data da Última Modificação: 14/06/2026

PROPÓSITO:
Ferramenta de extração de metadados de blocos 3D e tilesets de eletrodomésticos
da instalação original do jogo.
Varre o arquivo 'newtiledefinitions.tiles.txt' oficial do Project Zomboid,
captura dados de recipientes e texturas de lavadoras, geladeiras, fogões, TVs, etc.,
e compila as definições no arquivo centralizador 'dicionario_tilesets.json'. Esse
dicionário é utilizado pela ferramenta 'LKS_Tools.py' para sugestão dinâmica
de nomes limpos de arquivos PNG e busca unificada de assets.

COMO USAR:
- Execução Padrão (configurações do .env ou caminhos comuns de downloads):
    python tools/atualizar_dicionario_tilesets.py
================================================================================
"""

import os
import re
import json

def extrair_tiles_do_jogo(caminho_jogo):
    caminho_def = os.path.join(caminho_jogo, "media", "newtiledefinitions.tiles.txt")
    if not os.path.exists(caminho_def):
        print(f"Erro: Arquivo não encontrado em {caminho_def}")
        return None

    # Queremos buscar tilesets de interesse
    tilesets_alvo = [
        "appliances_laundry_01",
        "appliances_cooking_01",
        "appliances_refrigeration_01",
        "appliances_television_01",
        "appliances_radio_01",
        "appliances_misc_01",
        "appliances_com_01",
        "appliances_01"
    ]

    resultado = {}
    for ts in tilesets_alvo:
        resultado[ts] = {
            "descricao": f"Tileset: {ts}",
            "itens": {}
        }

    # Regex para capturar o nome do sprite do comentário, ex: // appliances_laundry_01_5
    re_comentario = re.compile(r"^\s*//\s*([a-zA-Z0-9_]+)")
    
    with open(caminho_def, "r", encoding="utf-8", errors="ignore") as f:
        linhas = f.readlines()

    total_linhas = len(linhas)
    i = 0
    while i < total_linhas:
        linha = linhas[i].strip()
        match_coment = re_comentario.match(linha)
        if match_coment:
            sprite_name = match_coment.group(1)
            # Verifica se pertence a algum dos tilesets alvo
            pertençe = False
            for ts in tilesets_alvo:
                if sprite_name.startswith(ts + "_"):
                    pertençe = True
                    tileset_atual = ts
                    break
            
            if pertençe:
                # Vamos varrer o bloco "tile { ... }" seguinte
                i += 1
                propriedades = {}
                dentro_bloco = False
                while i < total_linhas:
                    l_bloco = linhas[i].strip()
                    if "tile" in l_bloco:
                        dentro_bloco = True
                    elif l_bloco == "{":
                        dentro_bloco = True
                    elif l_bloco == "}":
                        break
                    elif dentro_bloco and "=" in l_bloco:
                        partes = l_bloco.split("=", 1)
                        chave = partes[0].strip()
                        valor = partes[1].strip()
                        if valor: # Apenas propriedades com valor preenchido
                            propriedades[chave] = valor
                    i += 1
                
                # Se achamos propriedades interessantes (como CustomName ou Container)
                if propriedades:
                    nome_amigavel = propriedades.get("CustomName", "")
                    grupo = propriedades.get("GroupName", "")
                    direcao = propriedades.get("Facing", "")
                    tipo_container = propriedades.get("ContainerType", "")
                    
                    if nome_amigavel or tipo_container:
                        identificador = sprite_name
                        desc = f"{nome_amigavel}"
                        if grupo:
                            desc += f" ({grupo})"
                        if direcao:
                            desc += f" - Facing: {direcao}"
                        if tipo_container:
                            desc += f" [Container: {tipo_container}]"
                        
                        resultado[tileset_atual]["itens"][identificador] = {
                            "nome": nome_amigavel,
                            "grupo": grupo,
                            "direcao": direcao,
                            "container": tipo_container,
                            "descricao_completa": desc
                        }
        i += 1

    # Limpa os tilesets que não tiveram nenhum item relevante encontrado
    resultado_filtrado = {k: v for k, v in resultado.items() if v["itens"]}
    return resultado_filtrado

if __name__ == "__main__":
    # Caminhos baseados no arquivo para resiliência
    diretorio_ferramentas = os.path.dirname(os.path.abspath(__file__))
    diretorio_raiz = os.path.dirname(diretorio_ferramentas)
    caminho_env = os.path.join(diretorio_raiz, ".env")
    caminho_saida = os.path.join(diretorio_ferramentas, "dicionario_tilesets.json")
    
    # Ler caminho do jogo do .env na raiz do projeto
    pz_dir = None
    if os.path.exists(caminho_env):
        with open(caminho_env, "r", encoding="utf-8") as env:
            for line in env:
                if line.startswith("PZ_GAME_DIR="):
                    pz_dir = line.split("=", 1)[1].strip().strip('"').strip("'")
                    break
    
    if not pz_dir:
        # Tenta localizar de forma agnóstica se não estiver no .env
        from pathlib import Path
        downloads_usuario = Path(os.path.expanduser("~")) / "Downloads" / "ProjectZomboid"
        if downloads_usuario.exists():
            pz_dir = str(downloads_usuario)
        else:
            pz_dir = "C:\\Users\\LKSFERREIRA\\Downloads\\ProjectZomboid"
            
    if not os.path.exists(pz_dir):
        print(f"Erro: O diretório de instalação do Project Zomboid não existe em: {pz_dir}")
        print("Por favor, configure a chave PZ_GAME_DIR no arquivo .env na raiz do mod.")
        sys.exit(1)
 
    print(f"Buscando definições de tilesets no jogo: {pz_dir}")
    dados = extrair_tiles_do_jogo(pz_dir)
    
    caminhos_assets = {
        "icones_inventario_ui": {
            "descricao": "Ícones de recipientes exibidos nas abas de inventário do jogador",
            "arquivo_pack_origem": "media/texturepacks/UI.pack",
            "diretorio_destino_mod": "common/media/ui/",
            "mapeamento_padrao": {
                "container_fridge": "Container_Fridge.png (Geladeira)",
                "container_freezer": "Container_Freezer.png (Freezer)",
                "container_microwave": "Container_Microwave.png (Micro-ondas)",
                "container_oven": "Container_Stove.png (Fogão/Forno - extraído como 'container_oven')"
            }
        },
        "texturas_mundo_tilesets": {
            "descricao": "Spritesheets/Atlas das texturas dos blocos no mundo 3D",
            "arquivos_pack_origem": [
                "media/texturepacks/Tiles1x.pack (Resolução Padrão)",
                "media/texturepacks/Tiles2x.pack (Alta Resolução - HD)"
            ],
            "arquivos_atlas_png_no_jogo": [
                "media/textures/Tileset/appliances_laundry_01.png",
                "media/textures/Tileset/appliances_cooking_01.png",
                "media/textures/Tileset/appliances_refrigeration_01.png",
                "media/textures/Tileset/appliances_television_01.png"
            ]
        }
    }
    
    if dados:
        with open(caminho_saida, "w", encoding="utf-8") as out:
            json.dump({
                "caminhos_assets": caminhos_assets,
                "tilesets": dados
            }, out, indent=2, ensure_ascii=False)
        print(f"Dicionário de tilesets atualizado com sucesso em: {caminho_saida}")
    else:
        print("Falha ao extrair dados dos tilesets.")
