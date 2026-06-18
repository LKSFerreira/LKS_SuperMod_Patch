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
import fnmatch

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
# CONFIGURAÇÃO DE EXCLUSÃO MANUAL PARA AUDITORIA DE CAMINHOS ABSOLUTOS
# Adicione aqui arquivos e diretórios que NÃO devem ser validados quanto a caminhos absolutos.
# ============================================================================
ITENS_IGNORADOS_MANUAL = [
    # Diretórios
    ".git",
    ".venv",
    ".vscode",
    "__pycache__",
    "node_modules",
    
    # Diretrizes e regras de agentes (contêm arquivos markdown com links file:///)
    ".agents",
    
    # Scripts e ferramentas auxiliares
    "tools",
    
    # Arquivos específicos
    "console_sanitizado.txt",
    "console_erros.txt",
    # Adicione novos itens abaixo:
]

def carregar_regras_gitignore(diretorio_raiz):
    """
    Carrega as regras do arquivo .gitignore presente na raiz do mod.
    Retorna uma lista de padrões de ignorados.
    """
    caminho_gitignore = os.path.join(diretorio_raiz, ".gitignore")
    padroes = []
    if not os.path.exists(caminho_gitignore):
        return padroes
        
    try:
        with open(caminho_gitignore, 'r', encoding='utf-8') as arquivo:
            for linha in arquivo:
                linha = linha.strip()
                # Ignora linhas vazias ou comentários
                if not linha or linha.startswith('#'):
                    continue
                padroes.append(linha)
    except Exception as erro:
        print(f"{YELLOW}[!] Aviso ao carregar .gitignore: {erro}{RESET}")
    return padroes

def deve_ignorar_caminho(caminho_relativo, padroes_gitignore, itens_ignorados_manual, eh_diretorio=False):
    """
    Verifica se um determinado caminho relativo deve ser ignorado pela auditoria
    com base na lista de exclusão manual e nas regras do .gitignore.
    """
    # Padroniza barras para separador universal Unix
    caminho_relativo = caminho_relativo.replace('\\', '/')
    partes = caminho_relativo.strip('/').split('/')
    nome_alvo = partes[-1] if partes else ""

    # 1. Verificação na lista manual de itens ignorados
    for item in itens_ignorados_manual:
        item_normalizado = item.replace('\\', '/').strip('/')
        # Verifica correspondência exata do caminho completo
        if caminho_relativo == item_normalizado:
            return True
        # Verifica se o caminho está dentro de um diretório ignorado manualmente
        if caminho_relativo.startswith(item_normalizado + '/'):
            return True
        # Verifica correspondência exata do nome do arquivo/pasta
        if nome_alvo == item_normalizado:
            return True

    # 2. Verificação de padrões originados do .gitignore
    for padrao in padroes_gitignore:
        # Padrões de negação do gitignore (começados com !) não são processados nesta lógica simples
        if padrao.startswith('!'):
            continue
            
        padrao_limpo = padrao
        apenas_diretorio = False
        
        # Padrões que terminam com barra especificam apenas diretórios
        if padrao_limpo.endswith('/'):
            apenas_diretorio = True
            padrao_limpo = padrao_limpo[:-1]
            
        if apenas_diretorio and not eh_diretorio:
            continue
            
        # Padrões ancorados na raiz do repositório
        ancorado = padrao_limpo.startswith('/')
        if ancorado:
            padrao_limpo = padrao_limpo[1:]
            
        contem_barra = '/' in padrao_limpo
        
        # Se contiver barra no meio do padrão ou for ancorado, comparamos com o caminho completo
        if ancorado or contem_barra:
            if fnmatch.fnmatch(caminho_relativo, padrao_limpo) or fnmatch.fnmatch(caminho_relativo + '/', padrao_limpo + '/'):
                return True
        else:
            # Caso contrário, comparamos com cada componente do caminho
            for parte in partes:
                if fnmatch.fnmatch(parte, padrao_limpo):
                    return True
                    
    return False

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
        print(f"{RED}[-] Erro: Arquivo não encontrado: {caminho_arquivo}{RESET}")
        return False

    try:
        with open(caminho_arquivo, 'r', encoding='utf-8') as f:
            linhas = f.readlines()
    except Exception as e:
        print(f"{RED}[-] Erro ao ler o arquivo {caminho_arquivo}: {e}{RESET}")
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
                    print(f"{RED}[-] Erro de Sintaxe em {caminho_arquivo}:{numero_linha}{RESET}")
                    print(f"{RED}    Fechamento 'end' encontrado sem bloco correspondente.{RESET}")
                    print(f"{GRAY}    Linha: {linha.strip()}{RESET}")
                    erros += 1
                else:
                    pilha_escopos.pop()
            elif token == 'until':
                if not pilha_escopos:
                    print(f"{RED}[-] Erro de Sintaxe em {caminho_arquivo}:{numero_linha}{RESET}")
                    print(f"{RED}    Fechamento 'until' encontrado sem bloco correspondente.{RESET}")
                    print(f"{GRAY}    Linha: {linha.strip()}{RESET}")
                    erros += 1
                else:
                    topo = pilha_escopos[-1][0]
                    if topo == 'repeat':
                        pilha_escopos.pop()
                    else:
                        print(f"{RED}[-] Incompatibilidade em {caminho_arquivo}:{numero_linha}{RESET}")
                        print(f"{RED}    'until' fechando bloco incorreto. Esperado fechar 'repeat', mas o topo é '{topo}'.{RESET}")
                        print(f"{GRAY}    Linha: {linha.strip()}{RESET}")
                        erros += 1

    # Verificar blocos remanescentes na pilha que não foram fechados
    if pilha_escopos:
        print(f"{RED}[-] Erro de Sintaxe em {caminho_arquivo}: Blocos não fechados no fim do arquivo.{RESET}")
        for token, num_lin, txt_lin in reversed(pilha_escopos):
            print(f"{RED}    Bloco '{token}' aberto na linha {num_lin} nunca foi fechado:{RESET}")
            print(f"{GRAY}    -> {txt_lin}{RESET}")
        erros += len(pilha_escopos)

    if erros > 0:
        print(f"{RED}[-] Validação concluída para '{os.path.basename(caminho_arquivo)}': {erros} erro(s) estrutural(ais) encontrado(s).{RESET}")
        return False
    else:
        print(f"{GREEN}[+] '{os.path.basename(caminho_arquivo)}': Estrutura de blocos validada com sucesso!{RESET}")
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
        if sucessos == total_arquivos:
            print(f"\n{GREEN}[*] Relatório de Validação: {sucessos}/{total_arquivos} arquivos validados com sucesso.{RESET}")
        else:
            print(f"\n{RED}[*] Relatório de Validação: {sucessos}/{total_arquivos} arquivos validados com sucesso.{RESET}")
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
        print(f"{RED}[-] Erro: Diretório de localização não encontrado para o idioma '{idioma}': {diretorio_traducao}{RESET}")
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
                    print(f"{RED}[-] Erro ao ler dicionário {file}: {e}{RESET}")

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
                    print(f"{RED}[-] Erro ao ler arquivo {caminho_lua}: {e}{RESET}")

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
            print(f"{RED}Chave Ausente: {chave}{RESET}")
            print(f"{GRAY}  Usada em: {', '.join(set(arquivos_uso))}{RESET}")
        print(f"\n{RED}[-] Auditoria concluída: {len(chaves_ausentes)} chaves não traduzidas no mod.{RESET}")
        if ignorar_nativas:
            print(f"{GRAY}    (Nota: Chaves nativas da UI do Project Zomboid foram ocultadas desta lista){RESET}")
        return False
    else:
        print(f"{GREEN}[+] Sucesso: Todas as chaves mapeadas em código possuem traduções locais!{RESET}")
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
    
    # Regex para identificar links file:/// (com ou sem drive) ou caminhos absolutos do Windows com letras de drive
    regex_caminho_absoluto = re.compile(
        r'(file:///[^\s"\'>)]+)|(\b[a-zA-Z]:[/\\][\w\-\.\s]+[/\\][\w\-\.\s/\\]+\b)'
    )
    
    extensoes_permitidas = ['.lua', '.json', '.txt', '.md', '.properties', '.xml']
    
    vazamentos_encontrados = 0
    correcoes_efetuadas = 0
    arquivos_afetados = {}

    padroes_gitignore = carregar_regras_gitignore(caminho_raiz_normalizado)

    for raiz, diretorios, arquivos in os.walk(caminho_raiz_normalizado):
        # Filtra os diretórios no os.walk para evitar entrar em caminhos ignorados
        novos_diretorios = []
        for d in diretorios:
            caminho_dir_completo = os.path.join(raiz, d)
            caminho_dir_relativo = os.path.relpath(caminho_dir_completo, caminho_raiz_normalizado)
            if not deve_ignorar_caminho(caminho_dir_relativo, padroes_gitignore, ITENS_IGNORADOS_MANUAL, eh_diretorio=True):
                novos_diretorios.append(d)
        diretorios[:] = novos_diretorios
        
        for arquivo in arquivos:
            caminho_completo = os.path.join(raiz, arquivo)
            caminho_relativo_arquivo = os.path.relpath(caminho_completo, caminho_raiz_normalizado)
            
            # Filtra arquivos ignorados
            if deve_ignorar_caminho(caminho_relativo_arquivo, padroes_gitignore, ITENS_IGNORADOS_MANUAL, eh_diretorio=False):
                continue
                
            extensao = os.path.splitext(arquivo)[1].lower()
            if extensao not in extensoes_permitidas:
                continue
                
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
            
            ocorrencias = [match.group(0) for match in regex_caminho_absoluto.finditer(conteudo)]
            if not ocorrencias:
                continue
                
            novo_conteudo = conteudo
            lista_detalhes = []
            
            # Remove duplicados mantendo a ordem
            ocorrencias_unicas = list(dict.fromkeys(ocorrencias))
            
            for caminho_capturado in ocorrencias_unicas:
                caminho_limpo = caminho_capturado.strip()
                
                # Se começar com file:///, extraímos o caminho real por trás dele
                tem_prefixo_file = caminho_limpo.lower().startswith("file:///")
                caminho_analise = caminho_limpo[8:] if tem_prefixo_file else caminho_limpo
                
                # Se for um caminho absoluto do Windows com letra de drive, normaliza
                # Caso contrário, se for apenas um caminho relativo que tinha file:///, verifica se aponta para dentro
                is_absoluto = False
                if re.match(r'^[a-zA-Z]:', caminho_analise):
                    abs_normalizado = os.path.abspath(caminho_analise)
                    is_absoluto = True
                else:
                    # Se não tem drive, pode ser absoluto Unix ou relativo
                    if caminho_analise.startswith('/') or caminho_analise.startswith('\\'):
                        # Se começar com barra, pode ser absoluto Unix ou relativo à raiz do mod
                        # Remove a barra inicial e vê se existe na raiz do mod
                        caminho_analise_sem_barra = caminho_analise.lstrip('/\\')
                        caminho_teste = os.path.join(caminho_raiz_normalizado, caminho_analise_sem_barra)
                        if os.path.exists(caminho_teste):
                            abs_normalizado = os.path.abspath(caminho_teste)
                        else:
                            abs_normalizado = os.path.abspath(caminho_analise)
                            is_absoluto = True
                    else:
                        # Caminho relativo
                        caminho_teste = os.path.join(caminho_raiz_normalizado, caminho_analise)
                        abs_normalizado = os.path.abspath(caminho_teste)
                
                # Verifica se aponta para dentro do mod
                if abs_normalizado.lower().startswith(caminho_raiz_normalizado.lower()):
                    caminho_relativo = os.path.relpath(abs_normalizado, caminho_raiz_normalizado)
                    caminho_relativo = caminho_relativo.replace("\\", "/")
                    
                    # Se for arquivo Lua e apontar para common/media, simplifica para media
                    if extensao == ".lua" and caminho_relativo.startswith("common/media/"):
                        caminho_relativo = caminho_relativo.replace("common/media/", "media/", 1)
                    elif extensao == ".lua" and caminho_relativo.startswith("common/"):
                        caminho_relativo = caminho_relativo.replace("common/", "", 1)
                        
                    lista_detalhes.append({
                        "original": caminho_limpo,
                        "substituto": caminho_relativo,
                        "tipo": "Local (Substituível)"
                    })
                    
                    if corrigir:
                        novo_conteudo = novo_conteudo.replace(caminho_limpo, caminho_relativo)
                else:
                    # Se aponta para fora e é absoluto, exige correção manual
                    if is_absoluto or tem_prefixo_file:
                        lista_detalhes.append({
                            "original": caminho_limpo,
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
                        print(f"{RED}[-] Erro ao salvar correções em {caminho_relativo_arquivo}: {e}{RESET}")

    print(f"\n--- AUDITORIA DE CAMINHOS ABSOLUTOS ---")
    if arquivos_afetados:
        for arq, detalhes in arquivos_afetados.items():
            print(f"\nArquivo: {CYAN}{arq}{RESET}")
            for det in detalhes:
                tipo_cor = RED if det['tipo'] != "Local (Substituível)" else YELLOW
                print(f"  [{tipo_cor}{det['tipo']}{RESET}] Encontrado: {det['original']}")
                if det['substituto']:
                    if corrigir:
                        print(f"    -> {GREEN}CORRIGIDO para: {det['substituto']}{RESET}")
                    else:
                        print(f"    -> {YELLOW}Sugestão de Correção: {det['substituto']}{RESET}")
                else:
                    print(f"    -> {RED}[ATENÇÃO] Caminho externo ao mod! Corrija manualmente para evitar vazamento.{RESET}")
        
        print(f"\n[*] Resumo:")
        print(f"    Total de caminhos absolutos detectados: {RED if vazamentos_encontrados > 0 else GREEN}{vazamentos_encontrados}{RESET}")
        if corrigir:
            print(f"    Total de caminhos corrigidos automaticamente: {GREEN}{correcoes_efetuadas}{RESET}")
            print(f"    Total de caminhos com correção pendente manual: {RED if (vazamentos_encontrados - correcoes_efetuadas) > 0 else GREEN}{vazamentos_encontrados - correcoes_efetuadas}{RESET}")
        else:
            print(f"    Use o argumento '{YELLOW}--corrigir{RESET}' para corrigir automaticamente os caminhos locais.")
        return False if (vazamentos_encontrados > correcoes_efetuadas) else True
    else:
        print(f"{GREEN}[+] Sucesso: Nenhum caminho absoluto ou vazamento de dados detectado nos arquivos do mod!{RESET}")
        return True

# ============================================================================
# MÓDULO 4: AUDITORIA DE ASSETS (IMAGENS ÓRFÃS / SEM USO)
# ============================================================================

def executar_auditoria_assets(diretorio_raiz):
    """
    Varre a pasta de UI do mod (common/media/ui) e detecta se existem imagens
    PNG/JPG/TGA que não possuem referências nos arquivos de código (Lua, JSON, TXT, MD).
    """
    diretorio_ui = os.path.join(diretorio_raiz, "common", "media", "ui")
    if not os.path.exists(diretorio_ui):
        print(f"{YELLOW}[!] Pasta de UI do mod vazia ou inexistente.{RESET}")
        return True

    # 1. Coleta arquivos de código do mod de forma recursiva
    padroes_gitignore = carregar_regras_gitignore(diretorio_raiz)
    arquivos_codigo = []
    for raiz, _, arquivos in os.walk(os.path.join(diretorio_raiz, "common")):
        # Ignora pastas de controle, ambientes virtuais e ferramentas
        if any(p in raiz for p in ['.git', '.venv', '.vscode', 'tools', '__pycache__']):
            continue
        for arq in arquivos:
            caminho_completo = os.path.join(raiz, arq)
            caminho_relativo = os.path.relpath(caminho_completo, diretorio_raiz)
            if deve_ignorar_caminho(caminho_relativo, padroes_gitignore, ITENS_IGNORADOS_MANUAL, eh_diretorio=False):
                continue
            if arq.endswith(('.lua', '.json', '.txt', '.md')):
                arquivos_codigo.append(caminho_completo)

    # Unifica o conteúdo do código em uma grande string de busca
    conteudo_codigo = ""
    for caminho_arq in arquivos_codigo:
        try:
            with open(caminho_arq, "r", encoding="utf-8", errors="ignore") as f:
                conteudo_codigo += f.read().lower()
        except Exception:
            pass

    # 2. Coleta imagens da pasta de UI
    imagens = []
    try:
        for arq in os.listdir(diretorio_ui):
            caminho_img = os.path.join(diretorio_ui, arq)
            if os.path.isfile(caminho_img) and arq.lower().endswith(('.png', '.jpg', '.tga')):
                imagens.append(arq)
    except Exception as e:
        print(f"{RED}[-] Erro ao ler pasta de UI: {e}{RESET}")
        return False

    # Mapeia os dados e calcula a largura máxima necessária dinamicamente
    dados_tabela = []
    largura_maxima = len("ARQUIVO DE IMAGEM") + 2
    imagens_nao_referenciadas = []
    
    for nome_imagem in imagens:
        nome_base, _ = os.path.splitext(nome_imagem)
        padrao_busca_regex = r"\b" + re.escape(nome_base.lower()) + r"\b"

        if re.search(padrao_busca_regex, conteudo_codigo):
            coluna_1 = f"  [OK] {nome_imagem}"
            coluna_2 = "Usado/Referenciado"
            cor = GREEN
            tag = "[OK]"
        else:
            coluna_1 = f"  [SUSPEITO] {nome_imagem}"
            coluna_2 = "NÃO REFERENCIADO"
            cor = RED
            tag = "[SUSPEITO]"
            imagens_nao_referenciadas.append(nome_imagem)
            
        dados_tabela.append((coluna_1, coluna_2, cor, tag))
        largura_maxima = max(largura_maxima, len(coluna_1))
        
    largura_coluna_1 = largura_maxima + 2
    divisoria_linha = "-" * (largura_coluna_1 + 25)
    
    print(f"\n--- AUDITORIA DE ASSETS (Imagens Órfãs) ---")
    print(f"[INFO] Indexados {len(arquivos_codigo)} arquivos de código e {len(imagens)} imagens de UI.")
    print(divisoria_linha)
    print(f"{'ARQUIVO DE IMAGEM':<{largura_coluna_1}} | {'STATUS NO CÓDIGO':<20}")
    print(divisoria_linha)
    
    for col_1, col_2, cor, tag in dados_tabela:
        # Formata com a largura dinâmica calculada ANTES de injetar as cores
        # para que o caractere de divisória '|' permaneça matematicamente alinhado.
        col_1_formatada = f"{col_1:<{largura_coluna_1}}"
        if cor == GREEN:
            col_1_colorida = col_1_formatada.replace(tag, f"{GREEN}{tag}{RESET}", 1)
            print(f"{col_1_colorida} | {GREEN}{col_2}{RESET}")
        else:
            col_1_colorida = col_1_formatada.replace(tag, f"{RED}{tag}{RESET}", 1)
            print(f"{col_1_colorida} | {RED}{col_2}{RESET}")
            
    print(divisoria_linha)

    # 3. Detecta referências no código a imagens que não existem fisicamente (imagens ausentes)
    referencias_code = set(re.findall(r'media/ui/([a-zA-Z0-9_-]+\.(?:png|jpg|tga))', conteudo_codigo, re.IGNORECASE))
    imagens_existentes_lower = {img.lower() for img in imagens}
    imagens_ausentes = []

    for ref in referencias_code:
        ref_lower = ref.lower()
        # Apenas auditamos imagens que pertencem ao nosso mod (com prefixo 'lks_' ou 'pb_')
        # para evitar falsos positivos com texturas nativas (vanilla) do Project Zomboid
        if not (ref_lower.startswith("lks_")): #or ref_lower.startswith("pb_")):
            continue
            
        if ref_lower not in imagens_existentes_lower:
            imagens_ausentes.append(ref)

    sucesso_auditoria = True

    if imagens_ausentes:
        print(f"\n{RED}[ERR] IMAGENS REFERENCIADAS NO CÓDIGO MAS AUSENTES NO PROJETO:{RESET}")
        for img_ausente in sorted(imagens_ausentes):
            print(f"  {RED}- media/ui/{img_ausente}{RESET}")
        sucesso_auditoria = False

    if imagens_nao_referenciadas:
        print(f"{RED}[-] Auditoria de assets concluída: Encontrada(s) {len(imagens_nao_referenciadas)} imagem(ns) não utilizada(s).{RESET}")
        sucesso_auditoria = False

    if sucesso_auditoria:
        print(f"{GREEN}[+] Sucesso: Integridade dos assets validada! Nenhuma imagem órfã ou referenciada ausente.{RESET}")
        return True
    else:
        return False

def executar_auditoria_completa(diretorio_raiz):
    """
    Executa de forma sequencial e unificada todos os módulos de auditoria do mod:
    1. Validação de Sintaxe Lua
    2. Auditoria de Traduções (PT-BR, ignorando nativas por padrão)
    3. Auditoria de Caminhos Absolutos
    4. Auditoria de Assets (Imagens órfãs na pasta de UI)
    Exibe um painel consolidado com o status de cada verificação.
    """
    print("\n" + "=" * 80)
    print("[*] INICIANDO AUDITORIA UNIFICADA - LKS SUPERMOD PATCH")
    print("=" * 80)
    
    # 1. Validação de Sintaxe Lua
    caminho_common = os.path.join(diretorio_raiz, "common")
    print("\n[MÓDULO 1] Validando Sintaxe Lua...")
    sintaxe_ok = executar_validacao_sintaxe(caminho_common)
    
    # 2. Auditoria de Traduções (ignorar_nativas=True por padrão)
    print("\n[MÓDULO 2] Validando Traduções PT-BR (Foco no Mod)...")
    traducoes_ok = executar_auditoria_traducoes(diretorio_raiz, "PTBR", ignorar_nativas=True)
    
    # 3. Auditoria de Caminhos Absolutos
    print("\n[MÓDULO 3] Validando Caminhos Absolutos...")
    caminhos_ok = executar_auditoria_caminhos(diretorio_raiz, corrigir=True)

    # 4. Auditoria de Assets (Imagens órfãs)
    print("\n[MÓDULO 4] Validando Imagens Órfãs/Sem Uso...")
    assets_ok = executar_auditoria_assets(diretorio_raiz)
    
    print("\n" + "=" * 80)
    print("[*] RELATÓRIO CONSOLIDADO DE AUDITORIA")
    print("=" * 80)
    
    def formatar_status(status_sucesso):
        return f"{GREEN}[OK]{RESET}" if status_sucesso else f"{RED}[FALHA]{RESET}"
        
    print(f"1. Validação de Sintaxe Lua:       {formatar_status(sintaxe_ok)}")
    print(f"2. Auditoria de Traduções (PT-BR): {formatar_status(traducoes_ok)}")
    print(f"3. Auditoria de Caminhos:          {formatar_status(caminhos_ok)}")
    print(f"4. Auditoria de Assets (Imagens):  {formatar_status(assets_ok)}")
    print("=" * 80)
    
    tudo_com_sucesso = sintaxe_ok and traducoes_ok and caminhos_ok and assets_ok
    if tudo_com_sucesso:
        print(f"{GREEN}[+] Excelente! O mod passou em todos os testes de auditoria unificada.{RESET}")
    else:
        print(f"{RED}[-] Atenção: Foram detectados problemas na auditoria. Revise os alertas acima.{RESET}")
        
    print("=" * 80 + "\n")
    return tudo_com_sucesso

# ============================================================================
# MÉTODO DE ENTRADA CLI (MAIN)
# ============================================================================

def executar_documentacao_api(diretorio_raiz, caminho_saida):
    """
    Varre todos os arquivos Lua do mod e extrai documentação de API
    a partir das anotações EmmyLua (---@param, ---@return, docstrings).

    Gera um arquivo Markdown estruturado com todas as funções documentadas,
    organizadas por arquivo/módulo.

    :param diretorio_raiz: Diretório raiz do mod.
    :param caminho_saida: Caminho do arquivo .md de saída.
    :return: True se executou com sucesso.
    """
    diretorio_lua = os.path.join(diretorio_raiz, "common", "media", "lua")
    if not os.path.isdir(diretorio_lua):
        print(f"{RED}[!] Diretório Lua não encontrado: {diretorio_lua}{RESET}")
        return False

    # Coleta todos os arquivos .lua recursivamente
    arquivos_lua = []
    for raiz_atual, _, arquivos in os.walk(diretorio_lua):
        for arquivo in sorted(arquivos):
            if arquivo.endswith(".lua"):
                caminho_completo = os.path.join(raiz_atual, arquivo)
                arquivos_lua.append(caminho_completo)

    if not arquivos_lua:
        print(f"{YELLOW}[!] Nenhum arquivo Lua encontrado.{RESET}")
        return False

    print(f"{CYAN}[*] Analisando {len(arquivos_lua)} arquivos Lua...{RESET}")

    # Regex para detectar definições de função
    regex_funcao_local = re.compile(
        r'^local\s+function\s+(\w+)\s*\((.*?)\)'
    )
    regex_funcao_global = re.compile(
        r'^function\s+([\w.:]+)\s*\((.*?)\)'
    )
    # Regex para anotações EmmyLua
    regex_param = re.compile(r'^---\s*@param\s+(\w+)\s+(\S+)\s*(.*)')
    regex_return = re.compile(r'^---\s*@return\s+(\S+)\s*(\w*)\s*(.*)')
    regex_docline = re.compile(r'^---\s?(.*)')

    # Estrutura de dados: { caminho_relativo: [funcoes] }
    modulos = {}
    total_funcoes = 0
    funcoes_documentadas = 0

    for caminho_arquivo in arquivos_lua:
        caminho_relativo = os.path.relpath(caminho_arquivo, diretorio_lua)
        funcoes_do_arquivo = []

        with open(caminho_arquivo, 'r', encoding='utf-8', errors='replace') as arquivo_handle:
            linhas = arquivo_handle.readlines()

        bloco_doc = []
        parametros = []
        retornos = []
        coletando_doc = False

        for numero_linha, linha in enumerate(linhas, 1):
            linha_strip = linha.rstrip()

            # Detecta linhas de documentação EmmyLua
            match_doc = regex_docline.match(linha_strip)
            if match_doc:
                coletando_doc = True
                conteudo = match_doc.group(1)

                # Verifica se é @param
                match_param = regex_param.match(linha_strip)
                if match_param:
                    parametros.append({
                        'nome': match_param.group(1),
                        'tipo': match_param.group(2),
                        'descricao': match_param.group(3).strip(),
                    })
                    continue

                # Verifica se é @return
                match_ret = regex_return.match(linha_strip)
                if match_ret:
                    retornos.append({
                        'tipo': match_ret.group(1),
                        'nome': match_ret.group(2).strip(),
                        'descricao': match_ret.group(3).strip(),
                    })
                    continue

                # Linha de documentação genérica (não vazia)
                if conteudo.strip():
                    bloco_doc.append(conteudo)
                continue

            # Se não é linha de doc, verifica se é definição de função
            if coletando_doc:
                match_local = regex_funcao_local.match(linha_strip)
                match_global = regex_funcao_global.match(linha_strip)

                if match_local or match_global:
                    match = match_local or match_global
                    nome_funcao = match.group(1)
                    params_texto = match.group(2).strip()
                    escopo = "local" if match_local else "global"

                    funcoes_do_arquivo.append({
                        'nome': nome_funcao,
                        'parametros_texto': params_texto,
                        'escopo': escopo,
                        'linha': numero_linha,
                        'documentacao': bloco_doc[:],
                        'params': parametros[:],
                        'retornos': retornos[:],
                    })
                    total_funcoes += 1
                    if bloco_doc or parametros or retornos:
                        funcoes_documentadas += 1

                # Reset do bloco de documentação
                bloco_doc = []
                parametros = []
                retornos = []
                coletando_doc = False
            else:
                # Detecta funções SEM documentação
                match_local = regex_funcao_local.match(linha_strip)
                match_global = regex_funcao_global.match(linha_strip)
                if match_local or match_global:
                    match = match_local or match_global
                    nome_funcao = match.group(1)
                    params_texto = match.group(2).strip()
                    escopo = "local" if match_local else "global"

                    funcoes_do_arquivo.append({
                        'nome': nome_funcao,
                        'parametros_texto': params_texto,
                        'escopo': escopo,
                        'linha': numero_linha,
                        'documentacao': [],
                        'params': [],
                        'retornos': [],
                    })
                    total_funcoes += 1

        if funcoes_do_arquivo:
            modulos[caminho_relativo] = funcoes_do_arquivo

    # Gera o Markdown de saída
    linhas_saida = []
    linhas_saida.append("# Referência da API Interna — LKS SuperMod Patch")
    linhas_saida.append("")
    linhas_saida.append("> Documento gerado automaticamente por `python tools/auditoria_mod.py documentar-api`")
    linhas_saida.append(f"> Total: **{total_funcoes}** funções em **{len(modulos)}** módulos")
    linhas_saida.append(f"> Cobertura de documentação: **{funcoes_documentadas}/{total_funcoes}** ({(funcoes_documentadas/max(total_funcoes,1)*100):.0f}%)")
    linhas_saida.append("")
    linhas_saida.append("---")
    linhas_saida.append("")

    # Índice por categoria (client, shared, server)
    categorias = {"client": [], "shared": [], "server": []}
    for caminho_rel in sorted(modulos.keys()):
        for categoria in categorias:
            if caminho_rel.startswith(categoria):
                categorias[categoria].append(caminho_rel)
                break

    linhas_saida.append("## Índice")
    linhas_saida.append("")
    for categoria, caminhos in categorias.items():
        if caminhos:
            linhas_saida.append(f"### {categoria}/")
            for caminho_rel in caminhos:
                nome_arquivo = os.path.basename(caminho_rel)
                quantidade = len(modulos[caminho_rel])
                anchor = caminho_rel.replace("\\", "/").replace("/", "").replace(".", "").replace("_", "").lower()
                linhas_saida.append(f"- [`{nome_arquivo}`](#{anchor}) ({quantidade} funções)")
            linhas_saida.append("")

    linhas_saida.append("---")
    linhas_saida.append("")

    # Detalhe de cada módulo
    for caminho_rel in sorted(modulos.keys()):
        funcoes = modulos[caminho_rel]
        caminho_display = caminho_rel.replace("\\", "/")
        linhas_saida.append(f"## `{caminho_display}`")
        linhas_saida.append("")

        for func in funcoes:
            # Cabeçalho da função
            badge_escopo = "🔒" if func['escopo'] == "local" else "🌐"
            assinatura = f"{func['nome']}({func['parametros_texto']})"
            linhas_saida.append(f"### {badge_escopo} `{assinatura}` <sub>L{func['linha']}</sub>")
            linhas_saida.append("")

            # Documentação
            if func['documentacao']:
                for linha_doc in func['documentacao']:
                    linhas_saida.append(f"> {linha_doc}")
                linhas_saida.append("")

            # Parâmetros
            if func['params']:
                linhas_saida.append("| Parâmetro | Tipo | Descrição |")
                linhas_saida.append("|-----------|------|-----------|")
                for param in func['params']:
                    linhas_saida.append(f"| `{param['nome']}` | `{param['tipo']}` | {param['descricao']} |")
                linhas_saida.append("")

            # Retornos
            if func['retornos']:
                linhas_saida.append("**Retorno:**")
                for ret in func['retornos']:
                    nome_ret = f"`{ret['nome']}`" if ret['nome'] else ""
                    linhas_saida.append(f"- `{ret['tipo']}` {nome_ret} — {ret['descricao']}")
                linhas_saida.append("")

            # Sem documentação
            if not func['documentacao'] and not func['params'] and not func['retornos']:
                linhas_saida.append(f"⚠️ *Função sem documentação EmmyLua*")
                linhas_saida.append("")

            linhas_saida.append("---")
            linhas_saida.append("")

    # Escreve arquivo de saída
    os.makedirs(os.path.dirname(caminho_saida), exist_ok=True)
    with open(caminho_saida, 'w', encoding='utf-8') as arquivo_saida:
        arquivo_saida.write("\n".join(linhas_saida))

    print(f"{GREEN}[✓] Documentação gerada com sucesso: {caminho_saida}{RESET}")
    print(f"    {CYAN}Módulos:{RESET} {len(modulos)}")
    print(f"    {CYAN}Funções:{RESET} {total_funcoes}")
    print(f"    {CYAN}Documentadas:{RESET} {funcoes_documentadas}/{total_funcoes} ({(funcoes_documentadas/max(total_funcoes,1)*100):.0f}%)")

    nao_documentadas = total_funcoes - funcoes_documentadas
    if nao_documentadas > 0:
        print(f"    {YELLOW}Sem documentação:{RESET} {nao_documentadas}")

    return True


def main():
    diretorio_script = os.path.dirname(os.path.abspath(__file__))
    diretorio_raiz_padrao = os.path.abspath(os.path.join(diretorio_script, ".."))

    parser = argparse.ArgumentParser(
        description="Ferramenta integrada de auditoria técnica para patches do Project Zomboid."
    )
    
    subparsers = parser.add_subparsers(dest="comando", help="Comandos disponíveis")

    # Comando: completa
    parser_completa = subparsers.add_parser(
        "completa",
        help="Executa de forma unificada e sequencial todos os módulos de auditoria do mod."
    )
    parser_completa.add_argument(
        "--raiz",
        default=diretorio_raiz_padrao,
        help="Diretório raiz do mod."
    )

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
        help="Detecta e corrige automaticamente caminhos absolutos locais para evitar vazamento de dados."
    )
    parser_caminhos.add_argument(
        "--raiz",
        default=diretorio_raiz_padrao,
        help="Diretório raiz do mod."
    )
    parser_caminhos.add_argument(
        "--sem-correcao",
        action="store_true",
        help="Realiza auditoria de caminhos sem aplicar as correções automáticas nos arquivos."
    )

    # Comando: auditar-assets
    parser_assets = subparsers.add_parser(
        "auditar-assets",
        help="Audita a pasta de UI do mod buscando imagens órfãs/sem uso."
    )
    parser_assets.add_argument(
        "--raiz",
        default=diretorio_raiz_padrao,
        help="Diretório raiz do mod."
    )

    # Comando: documentar-api
    parser_docapi = subparsers.add_parser(
        "documentar-api",
        help="Extrai anotações EmmyLua de todos os arquivos Lua e gera referência de API interna."
    )
    parser_docapi.add_argument(
        "--raiz",
        default=diretorio_raiz_padrao,
        help="Diretório raiz do mod."
    )
    parser_docapi.add_argument(
        "--saida",
        default=os.path.join(diretorio_raiz_padrao, "documents", "referencia_api_interna_lks.md"),
        help="Caminho do arquivo Markdown de saída."
    )

    args = parser.parse_args()

    if args.comando == "validar-sintaxe":
        sucesso = executar_validacao_sintaxe(args.caminho)
        sys.exit(0 if sucesso else 1)
    elif args.comando == "auditar-traducoes":
        sucesso = executar_auditoria_traducoes(args.raiz, args.idioma, args.ignorar_nativas)
        sys.exit(0 if sucesso else 1)
    elif args.comando == "auditar-caminhos":
        sucesso = executar_auditoria_caminhos(args.raiz, corrigir=not args.sem_correcao)
        sys.exit(0 if sucesso else 1)
    elif args.comando == "auditar-assets":
        sucesso = executar_auditoria_assets(args.raiz)
        sys.exit(0 if sucesso else 1)
    elif args.comando == "documentar-api":
        sucesso = executar_documentacao_api(args.raiz, args.saida)
        sys.exit(0 if sucesso else 1)
    elif args.comando == "completa":
        sucesso = executar_auditoria_completa(args.raiz)
        sys.exit(0 if sucesso else 1)
    elif args.comando is None:
        # Padrão se nenhum comando for passado: roda auditoria completa
        sucesso = executar_auditoria_completa(diretorio_raiz_padrao)
        sys.exit(0 if sucesso else 1)
    else:
        parser.print_help()
        sys.exit(0)

if __name__ == '__main__':
    main()

