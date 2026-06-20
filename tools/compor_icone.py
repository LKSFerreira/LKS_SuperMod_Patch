#!/usr/bin/env python3
"""
Compositor de icones para o LKS SuperMod Patch.

Gera icones compostos (base escurecida + badge sobreposto) para menus do PZ.
Canvas fixo em 32x32px. Base e badge sao centralizados sem redimensionamento.

Tabela de escurecimento (auto-detectada pela luminosidade da base):
  - claro  (luminosidade >= 0.55): 35% de reducao (fator 0.65)
  - medio  (luminosidade >= 0.35): 25% de reducao (fator 0.75)
  - escuro (luminosidade <  0.35): 15% de reducao (fator 0.85)

Uso:
  uv run tools/compor_icone.py <base.png> <badge.png> [--saida nome.png] [--brilho auto|claro|medio|escuro]

Exemplos:
  uv run tools/compor_icone.py common/media/ui/Item_Firewood_Bundle.png common/media/ui/LKS_Menu_Proibido.png
  uv run tools/compor_icone.py icon.png badge.png --saida common/media/ui/LKS_Custom_Off.png --brilho claro

:author: LKS SuperMod Patch (ferramenta interna)
:version: 1.0
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image, ImageEnhance
except ImportError:
    print("[ERRO] Pillow nao encontrado. Instale com: uv pip install Pillow")
    sys.exit(1)

# ===========================================================================
# CONSTANTES
# ===========================================================================

CANVAS_SIZE = 32

TABELA_BRILHO: dict[str, float] = {
    "claro": 0.65,
    "medio": 0.75,
    "escuro": 0.85,
}

SAIDA_PADRAO_DIR = Path("common/media/ui")


# ===========================================================================
# FUNCOES
# ===========================================================================


def calcular_luminosidade_media(imagem: Image.Image) -> float:
    """
    Calcula a luminosidade media de uma imagem RGBA (apenas pixels visiveis).

    :param imagem: Imagem PIL em modo RGBA.
    :return: Luminosidade media normalizada (0.0 a 1.0).

    .. code-block:: python

        lum = calcular_luminosidade_media(img)
    """
    dados = imagem.tobytes()
    largura, altura = imagem.size
    total_luminosidade = 0.0
    contagem = 0

    for indice in range(0, len(dados), 4):
        r, g, b, a = dados[indice], dados[indice + 1], dados[indice + 2], dados[indice + 3]
        if a < 10:
            continue
        luminosidade = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
        total_luminosidade += luminosidade
        contagem += 1

    if contagem == 0:
        return 0.5

    return total_luminosidade / contagem


def classificar_brilho(luminosidade: float) -> str:
    """
    Classifica a luminosidade em uma categoria da tabela do projeto.

    :param luminosidade: Valor entre 0.0 e 1.0.
    :return: Categoria ("claro", "medio" ou "escuro").

    .. code-block:: python

        categoria = classificar_brilho(0.7)  # "claro"
    """
    if luminosidade >= 0.55:
        return "claro"
    elif luminosidade >= 0.35:
        return "medio"
    else:
        return "escuro"


def centralizar_no_canvas(imagem: Image.Image, tamanho: int = CANVAS_SIZE) -> Image.Image:
    """
    Centraliza uma imagem em um canvas transparente de tamanho fixo.
    A imagem NAO e redimensionada — apenas posicionada no centro.

    :param imagem: Imagem PIL em modo RGBA.
    :param tamanho: Dimensao do canvas quadrado.
    :return: Canvas com a imagem centralizada.
    :raises ValueError: Se a imagem for maior que o canvas.

    .. code-block:: python

        canvas = centralizar_no_canvas(img_28x28)  # 32x32 com img no centro
    """
    if imagem.width > tamanho or imagem.height > tamanho:
        raise ValueError(
            f"Imagem ({imagem.width}x{imagem.height}) excede canvas "
            f"({tamanho}x{tamanho}). Reduza manualmente para evitar distorcao."
        )

    canvas = Image.new("RGBA", (tamanho, tamanho), (0, 0, 0, 0))
    offset_x = (tamanho - imagem.width) // 2
    offset_y = (tamanho - imagem.height) // 2
    canvas.paste(imagem, (offset_x, offset_y), imagem)
    return canvas


def compor_icone(
    caminho_base: Path,
    caminho_badge: Path,
    caminho_saida: Path,
    categoria_brilho: str | None = None,
) -> None:
    """
    Compoe um icone: base escurecida + badge sobreposto, ambos centralizados em 32x32.

    :param caminho_base: PNG do icone base.
    :param caminho_badge: PNG do badge/overlay.
    :param caminho_saida: Caminho de saida do PNG composto.
    :param categoria_brilho: "claro", "medio", "escuro" ou None (auto-detecta).

    .. code-block:: python

        compor_icone(Path("base.png"), Path("badge.png"), Path("saida.png"))
    """
    base = Image.open(caminho_base).convert("RGBA")
    badge = Image.open(caminho_badge).convert("RGBA")

    # Auto-detectar categoria se nao especificada
    if categoria_brilho is None:
        luminosidade = calcular_luminosidade_media(base)
        categoria_brilho = classificar_brilho(luminosidade)
        print(f"  [AUTO] Luminosidade: {luminosidade:.2f} -> '{categoria_brilho}'")

    fator = TABELA_BRILHO[categoria_brilho]
    reducao_percentual = int((1 - fator) * 100)
    print(f"  [INFO] Escurecimento: {reducao_percentual}% (fator {fator})")

    # Escurecer base
    base_escurecida = ImageEnhance.Brightness(base).enhance(fator)

    # Centralizar base no canvas 32x32
    canvas = centralizar_no_canvas(base_escurecida)

    # Centralizar badge no canvas 32x32
    canvas_badge = centralizar_no_canvas(badge)

    # Compor badge sobre base
    resultado = Image.alpha_composite(canvas, canvas_badge)

    # Salvar
    caminho_saida.parent.mkdir(parents=True, exist_ok=True)
    resultado.save(caminho_saida, "PNG")
    print(f"  [OK] Salvo: {caminho_saida} ({CANVAS_SIZE}x{CANVAS_SIZE}px)")


# ===========================================================================
# CLI
# ===========================================================================


def main() -> None:
    """Ponto de entrada CLI."""
    parser = argparse.ArgumentParser(
        description="Compoe icone (base escurecida + badge) para menus PZ. Canvas fixo 32x32.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos:
  uv run tools/compor_icone.py Item_Firewood_Bundle.png LKS_Menu_Proibido.png
  uv run tools/compor_icone.py icon.png badge.png --saida common/media/ui/LKS_Off.png
  uv run tools/compor_icone.py icon.png badge.png --brilho claro
        """,
    )
    parser.add_argument("base", type=Path, help="PNG do icone base")
    parser.add_argument("badge", type=Path, help="PNG do badge/overlay")
    parser.add_argument(
        "--saida",
        type=Path,
        default=None,
        help="Caminho de saida (default: LKS_<NomeBase>_Composed.png em common/media/ui/)",
    )
    parser.add_argument(
        "--brilho",
        choices=["auto", "claro", "medio", "escuro"],
        default="auto",
        help="Categoria de escurecimento (default: auto)",
    )

    args = parser.parse_args()

    if not args.base.exists():
        print(f"[ERRO] Base nao encontrada: {args.base}")
        sys.exit(1)

    if not args.badge.exists():
        print(f"[ERRO] Badge nao encontrado: {args.badge}")
        sys.exit(1)

    if args.saida:
        saida = args.saida
    else:
        nome = args.base.stem
        if nome.startswith("Item_"):
            nome = nome[5:]
        saida = SAIDA_PADRAO_DIR / f"LKS_{nome}_Composed.png"

    categoria = None if args.brilho == "auto" else args.brilho

    print(f"[*] Compondo icone...")
    print(f"  Base:  {args.base}")
    print(f"  Badge: {args.badge}")
    print(f"  Saida: {saida}")
    print()

    try:
        compor_icone(args.base, args.badge, saida, categoria)
    except ValueError as erro:
        print(f"[ERRO] {erro}")
        sys.exit(1)

    print("\n[OK] Concluido!")


if __name__ == "__main__":
    main()
