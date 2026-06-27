"""
Servidor MCP - LKS_SuperMod_Patch
Expõe as ferramentas refatoradas do projeto como "endpoints" MCP para agentes de IA.
"""

import sys
import json
import io
import contextlib
from pathlib import Path
from mcp.server.fastmcp import FastMCP

# Cria o servidor FastMCP
servidor = FastMCP("lks_supermod_tools")

# Importa as ferramentas utilitárias refatoradas do pacote tools/
try:
    from tools.extrair_sprites import (
        extrair_assets_do_jogo,
        sugerir_nome_arquivo,
        validar_e_salvar_caminho,
        DIRETORIO_JOGO_PADRAO,
        DIRETORIO_UI_MOD,
        DIRETORIO_RAIZ
    )
    from tools.inspecionar_imagem import inspecionar_propriedades_imagem
    from tools.processar_imagem import (
        processar_imagem_core,
        remover_fundo_svg,
        DIRETORIO_SAIDA_PADRAO
    )
    from tools.buscar_referencias import buscar_referencias_assets
    
    # Importa as ferramentas de auditoria e sanitização de logs
    from tools.auditoria_mod import (
        executar_validacao_sintaxe,
        executar_auditoria_traducoes,
        executar_auditoria_completa
    )
    from tools.filtrar_console_pz import sanitizar_log
except ImportError as erro_import:
    sys.stderr.write(f"Erro ao importar dependências de tools/: {erro_import}\n")
    sys.exit(1)

# Imports opcionais (ferramentas que podem ter dependências extras)
try:
    from tools.gerar_luarc import main as gerar_luarc_main
    TEM_GERAR_LUARC = True
except ImportError:
    TEM_GERAR_LUARC = False

try:
    from tools.compor_icone import compor_icone
    TEM_COMPOR_ICONE = True
except ImportError:
    TEM_COMPOR_ICONE = False

try:
    from tools.normaliza_utf8_para_ascii_lua import processar_arquivo as normalizar_arquivo_lua
    TEM_NORMALIZAR = True
except ImportError:
    TEM_NORMALIZAR = False


@servidor.tool()
def buscar_referencias_assets_pz(termo: str, caminho_jogo: str = "") -> str:
    """
    Busca referências de assets 2D (itens, interface) e 3D (mundo, tilesets) a partir de um termo.

    :param termo: O termo de busca (Ex: 'Fridge', 'Washer', 'Generator').
    :param caminho_jogo: Diretório de instalação do jogo (opcional, deduzido a partir do arquivo .env).
    :return: String contendo JSON com os sprites UI e do mundo localizados.
    """
    jogo_dir = caminho_jogo.strip() if caminho_jogo else DIRETORIO_JOGO_PADRAO
    if not Path(jogo_dir).exists():
        return json.dumps({"sucesso": False, "erro": "Diretório de instalação do jogo inválido ou não encontrado."})
        
    try:
        sprites_ui, sprites_mundo = buscar_referencias_assets(termo, jogo_dir, silencioso=True)
        return json.dumps({
            "sucesso": True,
            "termo": termo,
            "ui_sprites": sprites_ui,
            "mundo_sprites": sprites_mundo
        }, indent=2)
    except Exception as erro:
        return json.dumps({"sucesso": False, "erro": str(erro)})


@servidor.tool()
def inspecionar_propriedades_imagem_pz(caminho_imagem: str) -> str:
    """
    Inspeciona uma imagem e extrai largura, altura, modo de cor e verifica se é de 16-bit (incompatível).

    :param caminho_imagem: Caminho do arquivo de imagem PNG ou de outro formato no projeto.
    :return: String contendo JSON com as propriedades analisadas da imagem.
    """
    caminho = Path(caminho_imagem)
    if not caminho.exists():
        caminho_fallback = DIRETORIO_UI_MOD / caminho_imagem
        if caminho_fallback.exists():
            caminho = caminho_fallback
        else:
            return json.dumps({"sucesso": False, "erro": f"Imagem não encontrada no caminho '{caminho_imagem}'."})
            
    try:
        resultado = inspecionar_propriedades_imagem(caminho, silencioso=True)
        return json.dumps(resultado, indent=2)
    except Exception as erro:
        return json.dumps({"sucesso": False, "erro": str(erro)})


@servidor.tool()
def extrair_sprites_pz(sprites: list[str], caminho_jogo: str = "", pasta_destino: str = "") -> str:
    """
    Extrai sprites originais do jogo de arquivos .pack e os salva como PNG no projeto.

    :param sprites: Lista de sprites a extrair, ex: ['sprite_original'] ou ['sprite_original:nome_saida.png'].
    :param caminho_jogo: Pasta de instalação do Project Zomboid (opcional, detectado via .env).
    :param pasta_destino: Pasta onde salvar os PNGs extraídos (opcional, padrão 'common/media/ui').
    :return: String contendo JSON com os resultados das extrações (caminhos finais ou erros).
    """
    jogo_dir = caminho_jogo.strip() if caminho_jogo else DIRETORIO_JOGO_PADRAO
    if not Path(jogo_dir).exists():
        return json.dumps({"sucesso": False, "erro": "Diretório de instalação do jogo inválido ou não encontrado."})
        
    destino = pasta_destino.strip() if pasta_destino else str(DIRETORIO_UI_MOD)
    
    mapeamento = {}
    for item in sprites:
        if ":" in item:
            original, saida = item.split(":", 1)
            mapeamento[original.strip()] = saida.strip()
        else:
            sprite_nome = item.strip()
            mapeamento[sprite_nome] = sugerir_nome_arquivo(sprite_nome)
            
    try:
        resultados = extrair_assets_do_jogo(jogo_dir, mapeamento, destino, silencioso=True)
        sucesso_geral = any(caminho is not None for caminho in resultados.values())
        return json.dumps({
            "sucesso": success_geral if 'success_geral' in locals() else sucesso_geral,
            "resultados": resultados
        }, indent=2)
    except Exception as erro:
        return json.dumps({"sucesso": False, "erro": str(erro)})


@servidor.tool()
def processar_imagem_pz(
    caminho_entrada: str,
    caminho_saida: str = "",
    redimensionar: str = "",
    converter_bits: bool = False,
    formato: str = "",
    remover_fundo: bool = False,
    fundo_cor: str = "",
    fundo_tolerancia: float = 15.0
) -> str:
    """
    Processa imagens (redimensionar, conversão de bits para 8-bit, vetorização SVG ou remoção de fundo).

    :param caminho_entrada: Arquivo de imagem a ser processado.
    :param caminho_saida: Arquivo de destino (opcional, sugerido na pasta imagem_out por padrão).
    :param redimensionar: Parâmetro de tamanho (Ex: '2x', '50%', '256' ou '512x512').
    :param converter_bits: Converte a imagem para 8-bit seguro (evita crash do Project Zomboid).
    :param formato: Extensão final de destino para conversão de formato (Ex: png, jpg, webp, svg, tga).
    :param remover_fundo: Se verdadeiro, tenta remover a cor de fundo de um arquivo SVG.
    :param fundo_cor: Cor hexadecimal do fundo a remover (opcional, detectada se omitida).
    :param fundo_tolerancia: Tolerância de similaridade de cor para a remoção do fundo (padrão 15.0).
    :return: String contendo JSON com os caminhos dos arquivos de saída gerados.
    """
    entrada = Path(caminho_entrada)
    if not entrada.exists():
        return json.dumps({"sucesso": False, "erro": f"Arquivo de entrada não encontrado no caminho '{caminho_entrada}'."})
        
    ext_final = formato.strip().lower().replace(".", "") if formato else entrada.suffix.replace(".", "")
    if not ext_final:
        ext_final = "png"
        
    saida = Path(caminho_saida) if caminho_saida else DIRETORIO_SAIDA_PADRAO / f"{entrada.stem}.{ext_final}"
    
    if remover_fundo or (entrada.suffix.lower() == ".svg" and fundo_cor):
        try:
            sucesso = remover_fundo_svg(
                entrada,
                saida,
                cor_fundo=fundo_cor,
                tolerancia=fundo_tolerancia,
                interativo=False,
                silencioso=True
            )
            return json.dumps({
                "sucesso": sucesso,
                "caminho_saida": str(saida.with_suffix(".svg").resolve()) if sucesso else None
            })
        except Exception as erro:
            return json.dumps({"sucesso": False, "erro": str(erro)})
            
    try:
        sucesso = processar_imagem_core(
            entrada,
            saida,
            redimensionar_str=redimensionar if redimensionar else None,
            converter_bits=converter_bits,
            formato_saida=ext_final if formato else None,
            silencioso=True
        )
        return json.dumps({
            "sucesso": sucesso,
            "caminho_saida": str(saida.with_suffix(f".{ext_final}").resolve()) if sucesso else None
        }, indent=2)
    except Exception as erro:
        return json.dumps({"sucesso": False, "erro": str(erro)})


@servidor.tool()
def auditar_sintaxe_lua_pz(caminho_alvo: str = "") -> str:
    """
    Executa a validação de sintaxe e de blocos estruturais de arquivos Lua do mod (if, functions, end).

    :param caminho_alvo: Caminho da pasta ou do arquivo Lua a auditar (opcional, padrão 'common/').
    :return: Relatório textual com as inconsistências e erros estruturais detectados.
    """
    alvo = caminho_alvo.strip() if caminho_alvo else str(DIRETORIO_RAIZ / "common")
    if not Path(alvo).exists():
        return f"Erro: O caminho especificado '{alvo}' não existe."
        
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        try:
            executar_validacao_sintaxe(alvo)
        except Exception as erro:
            print(f"Exceção durante a validação de sintaxe: {erro}")
            
    return buffer.getvalue()


@servidor.tool()
def auditar_traducoes_pz(idioma: str = "PTBR", ignorar_nativas: bool = True) -> str:
    """
    Audita chaves de tradução comparando chamadas getText() no código Lua com arquivos .properties.

    :param idioma: Idioma a ser validado (ex: 'PTBR', 'EN' - correspondente à subpasta em Translate).
    :param ignorar_nativas: Oculta avisos de chaves nativas do PZ base (sem prefixos LKS_ ou PB_).
    :return: Relatório textual com chaves faltantes, traduzidas incorretamente ou em excesso.
    """
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        try:
            executar_auditoria_traducoes(str(DIRETORIO_RAIZ), idioma, ignorar_nativas)
        except Exception as erro:
            print(f"Exceção durante a auditoria de traduções: {erro}")
            
    return buffer.getvalue()


@servidor.tool()
def auditar_completo_mod_pz() -> str:
    """
    Executa a suite completa de auditoria do mod (sintaxe Lua, traduções, caminhos absolutos, junctions e imagens órfãs).

    :return: Relatório consolidado contendo os resultados de todas as auditorias.
    """
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        try:
            executar_auditoria_completa(str(DIRETORIO_RAIZ))
        except Exception as erro:
            print(f"Exceção durante a auditoria completa do mod: {erro}")
            
    return buffer.getvalue()


@servidor.tool()
def sanitizar_e_ler_erros_console_pz(caminho_console: str = "") -> str:
    """
    Executa a filtragem de logs do PZ, extraindo exceções, erros e stack traces do mod para depuração imediata.

    :param caminho_console: Caminho para o log console.txt do jogo (opcional, detectado automaticamente se omitido).
    :return: Conteúdo do relatório console_erros.txt consolidado com os erros isolados.
    """
    entrada_log = caminho_console.strip() if caminho_console else None
    
    # Redireciona o stdout para não poluir
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        try:
            sanitizar_log(entrada_log)
        except Exception as erro:
            print(f"Exceção na sanitização de logs: {erro}")
            
    # O arquivo de erros gerado fica na raiz do mod
    caminho_erros = DIRETORIO_RAIZ / "console_erros.txt"
    if caminho_erros.exists():
        try:
            erros_conteudo = caminho_erros.read_text(encoding="utf-8", errors="ignore")
            if erros_conteudo.strip():
                return erros_conteudo
            else:
                return "Sanitização concluída: Nenhum erro ou stack trace relevante foi detectado."
        except Exception as erro_leitura:
            return f"Erro ao ler o relatório de exceções gerado: {erro_leitura}"
            
    return "Sanitização concluída: O arquivo de relatório de erros 'console_erros.txt' não foi gerado."


@servidor.tool()
def gerar_configuracao_luarc() -> str:
    """
    Regenera o .luarc.json e os stubs de tipos Java para o lua-language-server.
    Elimina warnings falso-positivos de globals indefinidos nos arquivos Lua do mod.

    :return: Relatório textual do processo de geração.
    """
    if not TEM_GERAR_LUARC:
        return "Erro: módulo gerar_luarc não disponível (verifique imports)."

    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        try:
            gerar_luarc_main()
        except SystemExit:
            pass
        except Exception as erro:
            print(f"Exceção durante a geração do .luarc.json: {erro}")

    return buffer.getvalue()


@servidor.tool()
def compor_icone_pz(caminho_base: str, caminho_badge: str, caminho_saida: str = "", brilho: str = "auto") -> str:
    """
    Compõe um ícone de menu a partir de uma imagem base escurecida + badge sobreposto (canvas 32x32px).

    :param caminho_base: PNG da imagem base (ex: 'common/media/ui/Item_Firewood_Bundle.png').
    :param caminho_badge: PNG do badge/overlay (ex: 'common/media/ui/LKS_Menu_Proibido.png').
    :param caminho_saida: Caminho de saída (opcional, gera automaticamente em output/).
    :param brilho: Nível de escurecimento: 'auto', 'claro', 'medio' ou 'escuro'.
    :return: JSON com o resultado da composição e caminho do arquivo gerado.
    """
    if not TEM_COMPOR_ICONE:
        return json.dumps({"sucesso": False, "erro": "Módulo compor_icone não disponível (verifique Pillow)."})

    base = Path(caminho_base)
    badge = Path(caminho_badge)

    if not base.exists():
        return json.dumps({"sucesso": False, "erro": f"Imagem base não encontrada: {caminho_base}"})
    if not badge.exists():
        return json.dumps({"sucesso": False, "erro": f"Badge não encontrado: {caminho_badge}"})

    saida = Path(caminho_saida) if caminho_saida else Path("output") / f"{base.stem}_{badge.stem}.png"
    saida.parent.mkdir(parents=True, exist_ok=True)

    try:
        compor_icone(base, badge, saida, brilho=brilho)
        return json.dumps({"sucesso": True, "caminho_saida": str(saida.resolve())})
    except Exception as erro:
        return json.dumps({"sucesso": False, "erro": str(erro)})


@servidor.tool()
def normalizar_logs_lua_para_ascii(caminho_alvo: str = "", aplicar: bool = False) -> str:
    """
    Substitui caracteres acentuados PT-BR por ASCII em strings de log/debug dos arquivos Lua.
    NÃO toca em strings de getText(), traduções ou textos visíveis ao jogador.

    :param caminho_alvo: Arquivo ou diretório Lua a processar (padrão: 'common/').
    :param aplicar: Se True, aplica as mudanças. Se False, apenas mostra o que mudaria (dry-run).
    :return: Relatório textual com as substituições encontradas/aplicadas.
    """
    if not TEM_NORMALIZAR:
        return "Erro: módulo normaliza_utf8_para_ascii_lua não disponível."

    alvo = caminho_alvo.strip() if caminho_alvo else str(DIRETORIO_RAIZ / "common")
    if not Path(alvo).exists():
        return f"Erro: caminho '{alvo}' não encontrado."

    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        try:
            if Path(alvo).is_file():
                total, detalhes = normalizar_arquivo_lua(alvo, aplicar)
                print(f"Arquivo: {alvo} — {total} substituições {'aplicadas' if aplicar else 'encontradas'}")
                for detalhe in detalhes:
                    print(f"  {detalhe}")
            else:
                arquivos_lua = list(Path(alvo).rglob("*.lua"))
                total_geral = 0
                for arquivo in arquivos_lua:
                    total, detalhes = normalizar_arquivo_lua(str(arquivo), aplicar)
                    if total > 0:
                        total_geral += total
                        print(f"{arquivo.name}: {total} substituições")
                        for detalhe in detalhes:
                            print(f"  {detalhe}")
                print(f"\nTotal: {total_geral} substituições em {len(arquivos_lua)} arquivos")
        except Exception as erro:
            print(f"Exceção: {erro}")

    return buffer.getvalue()


if __name__ == "__main__":
    servidor.run()
