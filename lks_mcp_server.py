"""
Servidor MCP - LKS_SuperMod_Patch
Expõe ferramentas do projeto como "endpoints" para agentes de IA.
"""

from mcp.server.fastmcp import FastMCP
from pathlib import Path
import sys

# 1. Cria um servidor (equivalente a: app = FastMCP("lks_supermod_tools"))
servidor = FastMCP("lks_supermod_tools")

# 2. Registra uma ferramenta (equivalente a: @app.route("/ler-log") - como se fosse um endpoint em API Rest)
@servidor.tool()
def ler_log_console_txt_pz(ultimas_linhas: int = 200) -> str:
    """Lê as últimas 200 linhas do console.txt do Project Zomboid."""
    caminho = Path.home() / "Zomboid" / "console.txt"

    if not caminho.exists():
        return "Erro: o arquivo console.txt não foi encontrado em ~/Zomboid/"

    linhas = caminho.read_text(encoding="utf-8", errors="ignore").splitlines()
    pegue_ultimas_linhas = linhas[-ultimas_linhas:]
    return "\n".join(pegue_ultimas_linhas)

# 3. Roda o servidor (equivalente a: flash run)
if __name__ == "__main__":
    servidor.run()
