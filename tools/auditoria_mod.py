# -*- coding: utf-8 -*-
"""
================================================================================
🔍 AUDITORIA DO MOD - LKS SUPERMOD PATCH
================================================================================
Autor: LKS FERREIRA
Versão: 1.1 (Project Zomboid Build 42)
Data da Última Modificação: 14/06/2026

PROPÓSITO:
CLI unificada desenvolvida para auditoria estrutural do mod.
Suas funções principais englobam:
1. Validação de Sintaxe Lua: Analisa a abertura e fechamento de escopos e blocos
   lógicos (if, function, for, do, repeat, end, etc.) a fim de apontar blocos
   não finalizados ou redundâncias.
2. Auditoria de Traduções: Compara chaves de tradução presentes no código Lua
   com arquivos de tradução (.properties), identificando chaves faltantes,
   sobrando ou com traduções vazias.
3. Auditoria de Caminhos: Varre a base de código e documentações em busca de
   caminhos absolutos e locais (ex: 'C:/Users/...') para evitar vazamento de
   dados do ambiente local do desenvolvedor no repositório.

COMO USAR:
- Validação estrutural de arquivos Lua:
    python tools/auditoria_mod.py validar-sintaxe [<caminho_arquivo_ou_pasta>]
- Auditoria de chaves de tradução:
    python tools/auditoria_mod.py auditar-traducoes [--idioma <idioma>] [--ignorar-nativas]
- Auditoria de vazamento de caminhos absolutos:
    python tools/auditoria_mod.py auditar-caminhos
================================================================================
"""

import os
import re
import sys
import json
import argparse

# ============================================================================
# MÓDULO 1: VALIDADOR ESTRUTURAL DE LUA
# ============================================================================

def obter_tokens_validos(linha_codigo):
    """
    Remove comentários de linha, comentários em bloco (aproximação simples)
    e strings literais para extrair apenas palavras-chave do fluxo lógico de Lua.
    """
    # Remove comentários de linha simples
    if '--' in linha_codigo:
        linha_codigo = linha_codigo.split('--', 1)[0]
    
    # Remove strings literais para evitar falsos positivos
    linha_codigo = re.sub(r'"[^"\\]*(?:\\.[^"\\]*)*"', '""', linha_codigo)
    linha_codigo = re.sub(r"'[^'\\]*(?:\\.[^'\\]*)*'", "''", linha_codigo)
    
    # Extrai tokens alfanuméricos
    return re.findall(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b', linha_codigo)

def validar_arquivo_lua(caminho_arquivo):
    """
    Analisa a estrutura de blocos abertos/fechados do Lua usando uma pilha.
    Aponta a linha exata e o conteúdo de blocos que ficaram sem fechamento.
    """
    if not os.path.exists(caminho_arquivo):
        print(f"[-] Erro: Arquivo não encontrado: {caminho_arquivo}")
        return False

    try:
        with open(caminho_arquivo, 'r', encoding='utf-8') as f:
            linhas = f.readlines()
    except Exception as e:
        print(f"[-] Erro ao ler o arquivo {caminho_arquivo}: {e}")
        return False

    pilha_escopos = []
    em_comentario_bloco = False
    erros = 0

    for idx_linha, linha in enumerate(linhas):
        numero_linha = idx_linha + 1
        linha_limpa = linha.strip()

        # Tratamento de comentários em bloco
        if em_comentario_bloco:
            if '--]]' in linha_limpa:
                em_comentario_bloco = False
                linha_limpa = linha_limpa.split('--]]', 1)[1]
            else:
                continue

        if linha_limpa.startswith('--[['):
            em_comentario_bloco = True
            continue

        tokens = obter_tokens_validos(linha_limpa)
        if not tokens:
            continue

        # Rastrear chaves que abrem e fecham blocos
        for idx_token, token in enumerate(tokens):
            if token in ['if', 'function', 'for', 'while', 'repeat']:
                pilha_escopos.append((token, numero_linha, linha.strip()))
            elif token == 'do':
                # 'do' abre bloco somente se não fizer parte de um 'for' ou 'while' na mesma linha
                tokens_anteriores = tokens[:idx_token]
                if 'for' not in tokens_anteriores and 'while' not in tokens_anteriores:
                    pilha_escopos.append((token, numero_linha, linha.strip()))
            elif token == 'end':
                if not pilha_escopos:
                    print(f"[-] Erro de Sintaxe em {caminho_arquivo}:{numero_linha}")
                    print(f"    Fechamento 'end' encontrado sem bloco correspondente.")
                    print(f"    Linha: {linha.strip()}")
                    erros += 1
                else:
                    pilha_escopos.pop()
            elif token == 'until':
                if not pilha_escopos:
                    print(f"[-] Erro de Sintaxe em {caminho_arquivo}:{numero_linha}")
                    print(f"    Fechamento 'until' encontrado sem bloco correspondente.")
                    print(f"    Linha: {linha.strip()}")
                    erros += 1
                else:
                    topo = pilha_escopos[-1][0]
                    if topo == 'repeat':
                        pilha_escopos.pop()
                    else:
                        print(f"[-] Incompatibilidade em {caminho_arquivo}:{numero_linha}")
                        print(f"    'until' fechando bloco incorreto. Esperado fechar 'repeat', mas o topo é '{topo}'.")
                        print(f"    Linha: {linha.strip()}")
                        erros += 1

    # Verificar blocos remanescentes na pilha que não foram fechados
    if pilha_escopos:
        print(f"[-] Erro de Sintaxe em {caminho_arquivo}: Blocos não fechados no fim do arquivo.")
        for token, num_lin, txt_lin in reversed(pilha_escopos):
            print(f"    Bloco '{token}' aberto na linha {num_lin} nunca foi fechado:")
            print(f"    -> {txt_lin}")
        erros += len(pilha_escopos)

    if erros > 0:
        print(f"[-] Validação concluída para '{os.path.basename(caminho_arquivo)}': {erros} erro(s) estrutural(ais) encontrado(s).")
        return False
    else:
        print(f"[+] '{os.path.basename(caminho_arquivo)}': Estrutura de blocos validada com sucesso!")
        return True

def executar_validacao_sintaxe(caminho_alvo):
    """
    Roda a validação de forma recursiva para diretórios ou isolada para um único arquivo.
    """
    if os.path.isdir(caminho_alvo):
        print(f"[*] Analisando recursivamente arquivos Lua no diretório: {caminho_alvo}")
        total_arquivos = 0
        sucessos = 0
        for raiz, _, arquivos in os.walk(caminho_alvo):
            for arquivo in arquivos:
                if arquivo.endswith(".lua"):
                    total_arquivos += 1
                    caminho_completo = os.path.join(raiz, arquivo)
                    if validar_arquivo_lua(caminho_completo):
                        sucessos += 1
        print(f"\n[*] Relatório de Validação: {sucessos}/{total_arquivos} arquivos validados com sucesso.")
        return sucessos == total_arquivos
    else:
        return validar_arquivo_lua(caminho_alvo)

# ============================================================================
# MÓDULO 2: AUDITORIA DE TRADUÇÕES
# ============================================================================

def executar_auditoria_traducoes(diretorio_raiz, idioma, ignorar_nativas):
    """
    Audita o uso de getText("...") em scripts Lua e cruza com arquivos JSON de localização.
    """
    diretorio_traducao = os.path.join(diretorio_raiz, "common", "media", "lua", "shared", "Translate", idioma)
    if not os.path.exists(diretorio_traducao):
        print(f"[-] Erro: Diretório de localização não encontrado para o idioma '{idioma}': {diretorio_traducao}")
        return False

    # Ler as chaves de tradução locais do mod
    chaves_json = set()
    for root, _, files in os.walk(diretorio_traducao):
        for file in files:
            if file.endswith(".json"):
                caminho_json = os.path.join(root, file)
                try:
                    with open(caminho_json, "r", encoding="utf-8") as f:
                        dados = json.load(f)
                        chaves_json.update(dados.keys())
                except Exception as e:
                    print(f"[-] Erro ao ler dicionário {file}: {e}")

    # Regex para localizar getText("CHAVE") ou getText('CHAVE')
    regex_gettext = re.compile(r'getText\(\s*["\']([^"\']+)["\']\s*\)')

    chaves_encontradas = {}
    for raiz, _, arquivos in os.walk(os.path.join(diretorio_raiz, "common")):
        for arquivo in arquivos:
            if arquivo.endswith(".lua"):
                caminho_lua = os.path.join(raiz, arquivo)
                try:
                    with open(caminho_lua, "r", encoding="utf-8") as f:
                        conteudo = f.read()
                        for match in regex_gettext.finditer(conteudo):
                            chave = match.group(1)
                            if chave not in chaves_encontradas:
                                chaves_encontradas[chave] = []
                            chaves_encontradas[chave].append(os.path.relpath(caminho_lua, diretorio_raiz))
                except Exception as e:
                    print(f"[-] Erro ao ler arquivo {caminho_lua}: {e}")

    # Identificar chaves ausentes na localização local do mod
    chaves_ausentes = {chave: arquivos for chave, arquivos in chaves_encontradas.items() if chave not in chaves_json}

    # Filtrar chaves nativas do PZ (geralmente sem prefixos locais do mod LKS_ ou PB_) se solicitado
    if ignorar_nativas:
        prefixos_mod = ['LKS_', 'PB_']
        chaves_filtradas = {}
        for chave, arquivos in chaves_ausentes.items():
            # Se a chave contiver um dos prefixos do mod, ela DEVE ser traduzida localmente.
            # Caso contrário, se começar com prefixos genéricos de UI do PZ, assumimos que é vanilla.
            tem_prefixo_local = any(p in chave for p in prefixos_mod)
            prefixo_generico = chave.startswith("ContextMenu_") or chave.startswith("IGUI_") or chave.startswith("Sandbox_")
            if tem_prefixo_local or not prefixo_generico:
                chaves_filtradas[chave] = arquivos
        chaves_ausentes = chaves_filtradas

    print(f"\n--- AUDITORIA DE TRADUÇÕES ({idioma}) ---")
    if chaves_ausentes:
        for chave, arquivos_uso in sorted(chaves_ausentes.items()):
            print(f"Chave Ausente: {chave}")
            print(f"  Usada em: {', '.join(set(arquivos_uso))}")
        print(f"\n[-] Auditoria concluída: {len(chaves_ausentes)} chaves não traduzidas no mod.")
        if ignorar_nativas:
            print("    (Nota: Chaves nativas da UI do Project Zomboid foram ocultadas desta lista)")
        return False
    else:
        print("[+] Sucesso: Todas as chaves mapeadas em código possuem traduções locais!")
        return True

# ============================================================================
# MÓDULO 3: AUDITORIA E CORREÇÃO DE CAMINHOS ABSOLUTOS
# ============================================================================

def executar_auditoria_caminhos(diretorio_raiz, corrigir):
    """
    Varre os arquivos do mod em busca de caminhos absolutos (Windows/Unix)
    que possam expor a estrutura de diretórios ou dados locais do desenvolvedor.
    Converte caminhos locais ao mod em relativos caso 'corrigir' seja True.
    """
    caminho_raiz_normalizado = os.path.abspath(diretorio_raiz)
    
    # Regex para identificar letras de drive do Windows seguidas por caminhos com pelo menos 2 níveis
    # Ex: C:\Users\LKSFERREIRA ou d:/Zomboid/mods
    regex_caminho_absoluto = re.compile(r'\b([a-zA-Z]:[/\\][\w\-\.\s]+[/\\][\w\-\.\s/\\]+)\b')
    
    pastas_excluidas = ['.git', '.venv', '.vscode', '__pycache__']
    arquivos_excluidos = ['console_sanitizado.txt', 'console_erros.txt']
    extensoes_permitidas = ['.lua', '.json', '.txt', '.md', '.properties', '.xml']
    
    vazamentos_encontrados = 0
    correcoes_efetuadas = 0
    arquivos_afetados = {}

    for raiz, diretorios, arquivos in os.walk(caminho_raiz_normalizado):
        # Ignora pastas de controle ou ambientes virtuais
        diretorios[:] = [d for d in diretorios if d not in pastas_excluidas]
        
        for arquivo in arquivos:
            if arquivo in arquivos_excluidos:
                continue
            extensao = os.path.splitext(arquivo)[1].lower()
            if extensao not in extensoes_permitidas:
                continue
                
            caminho_completo = os.path.join(raiz, arquivo)
            caminho_relativo_arquivo = os.path.relpath(caminho_completo, caminho_raiz_normalizado)
            
            try:
                with open(caminho_completo, 'r', encoding='utf-8') as f:
                    conteudo = f.read()
            except Exception as e:
                # Caso falhe com utf-8, tenta com ISO-8859-1 para tolerar outros encodings
                try:
                    with open(caminho_completo, 'r', encoding='iso-8859-1') as f:
                        conteudo = f.read()
                except Exception:
                    continue
            
            ocorrencias = regex_caminho_absoluto.findall(conteudo)
            if not ocorrencias:
                continue
                
            novo_conteudo = conteudo
            lista_detalhes = []
            
            # Remove duplicados mantendo a ordem
            ocorrencias_unicas = list(dict.fromkeys(ocorrencias))
            
            for caminho_absoluto in ocorrencias_unicas:
                caminho_absoluto_limpo = caminho_absoluto.strip()
                abs_normalizado = os.path.abspath(caminho_absoluto_limpo)
                
                # Se aponta para dentro do mod
                if abs_normalizado.lower().startswith(caminho_raiz_normalizado.lower()):
                    caminho_relativo = os.path.relpath(abs_normalizado, caminho_raiz_normalizado)
                    caminho_relativo = caminho_relativo.replace("\\", "/")
                    
                    # Se for arquivo Lua e apontar para common/media, simplifica para media
                    if extensao == ".lua" and caminho_relativo.startswith("common/media/"):
                        caminho_relativo = caminho_relativo.replace("common/media/", "media/", 1)
                    elif extensao == ".lua" and caminho_relativo.startswith("common/"):
                        caminho_relativo = caminho_relativo.replace("common/", "", 1)
                        
                    lista_detalhes.append({
                        "original": caminho_absoluto_limpo,
                        "substituto": caminho_relativo,
                        "tipo": "Local (Substituível)"
                    })
                    
                    if corrigir:
                        novo_conteudo = novo_conteudo.replace(caminho_absoluto_limpo, caminho_relativo)
                else:
                    lista_detalhes.append({
                        "original": caminho_absoluto_limpo,
                        "substituto": None,
                        "tipo": "Externo (Exige Correção Manual)"
                    })
            
            if lista_detalhes:
                arquivos_afetados[caminho_relativo_arquivo] = lista_detalhes
                vazamentos_encontrados += len(lista_detalhes)
                
                if corrigir and novo_conteudo != conteudo:
                    try:
                        with open(caminho_completo, 'w', encoding='utf-8') as f:
                            f.write(novo_conteudo)
                        correcoes_efetuadas += sum(1 for d in lista_detalhes if d["substituto"] is not None)
                    except Exception as e:
                        print(f"[-] Erro ao salvar correções em {caminho_relativo_arquivo}: {e}")

    print(f"\n--- AUDITORIA DE CAMINHOS ABSOLUTOS ---")
    if arquivos_afetados:
        for arq, detalhes in arquivos_afetados.items():
            print(f"\nArquivo: {arq}")
            for det in detalhes:
                print(f"  [{det['tipo']}] Encontrado: {det['original']}")
                if det['substituto']:
                    if corrigir:
                        print(f"    -> CORRIGIDO para: {det['substituto']}")
                    else:
                        print(f"    -> Sugestão de Correção: {det['substituto']}")
                else:
                    print(f"    -> [ATENÇÃO] Caminho externo ao mod! Corrija manualmente para evitar vazamento.")
        
        print(f"\n[*] Resumo:")
        print(f"    Total de caminhos absolutos detectados: {vazamentos_encontrados}")
        if corrigir:
            print(f"    Total de caminhos corrigidos automaticamente: {correcoes_efetuadas}")
            print(f"    Total de caminhos com correção pendente manual: {vazamentos_encontrados - correcoes_efetuadas}")
        else:
            print(f"    Use o argumento '--corrigir' para corrigir automaticamente os caminhos locais.")
        return False if (vazamentos_encontrados > correcoes_efetuadas) else True
    else:
        print("[+] Sucesso: Nenhum caminho absoluto ou vazamento de dados detectado nos arquivos do mod!")
        return True

# ============================================================================
# MÉTODO DE ENTRADA CLI (MAIN)
# ============================================================================

def main():
    diretorio_script = os.path.dirname(os.path.abspath(__file__))
    diretorio_raiz_padrao = os.path.abspath(os.path.join(diretorio_script, ".."))

    parser = argparse.ArgumentParser(
        description="Ferramenta integrada de auditoria técnica para patches do Project Zomboid."
    )
    
    subparsers = parser.add_subparsers(dest="comando", help="Comandos disponíveis")

    # Comando: validar-sintaxe
    parser_sintaxe = subparsers.add_parser(
        "validar-sintaxe", 
        help="Valida a consistência de blocos estruturais de arquivos Lua."
    )
    parser_sintaxe.add_argument(
        "--caminho", 
        default=os.path.join(diretorio_raiz_padrao, "common"),
        help="Caminho para o arquivo Lua ou pasta a ser analisada de forma recursiva."
    )

    # Comando: auditar-traducoes
    parser_traducao = subparsers.add_parser(
        "auditar-traducoes", 
        help="Verifica se todas as chamadas de getText() do mod possuem tradução local."
    )
    parser_traducao.add_argument(
        "--raiz", 
        default=diretorio_raiz_padrao,
        help="Diretório raiz do mod."
    )
    parser_traducao.add_argument(
        "--idioma", 
        default="PTBR",
        help="Idioma a ser validado (nome da subpasta em Translate)."
    )
    parser_traducao.add_argument(
        "--ignorar-nativas", 
        action="store_true",
        help="Oculta chaves nativas do PZ base que não utilizam os prefixos do mod (LKS_ ou PB_)."
    )

    # Comando: auditar-caminhos
    parser_caminhos = subparsers.add_parser(
        "auditar-caminhos",
        help="Detecta e corrige caminhos absolutos locais para evitar vazamento de dados."
    )
    parser_caminhos.add_argument(
        "--raiz",
        default=diretorio_raiz_padrao,
        help="Diretório raiz do mod."
    )
    parser_caminhos.add_argument(
        "--corrigir",
        action="store_true",
        help="Substitui automaticamente os caminhos absolutos locais pelas suas versões relativas."
    )

    args = parser.parse_args()

    if args.comando == "validar-sintaxe":
        sucesso = executar_validacao_sintaxe(args.caminho)
        sys.exit(0 if sucesso else 1)
    elif args.comando == "auditar-traducoes":
        sucesso = executar_auditoria_traducoes(args.raiz, args.idioma, args.ignorar_nativas)
        sys.exit(0 if sucesso else 1)
    elif args.comando == "auditar-caminhos":
        sucesso = executar_auditoria_caminhos(args.raiz, args.corrigir)
        sys.exit(0 if sucesso else 1)
    else:
        parser.print_help()
        sys.exit(0)

if __name__ == '__main__':
    main()
