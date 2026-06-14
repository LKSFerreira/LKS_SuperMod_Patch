# 🛠️ LKS SuperMod Patch

Faz diversas correções, melhorias de UX/UI, bugs de scripts e traduções PT-BR para a coleção de mods Build 42. TODOS OS CRÉDITOS AOS CRIADORES ORIGINAIS.

> [!IMPORTANT]
> **REQUISITO OBRIGATÓRIO:** Este mod não é independente. Você precisa ter o mod original instalado para que este patch funcione.

## 📝 Sobre o Patch
Este é um mod de melhoria voltado para a qualidade de vida (QoL) e correção estética de diversos mods. O foco aqui é polimento visual, alinhamento de interfaces e otimização de traduções.

## 🚀 O que foi melhorado?
- **Interface (UI):** Ajuste fino de alinhamento.
- **Tradução:** Melhoria dos textos em PT-BR.
- **Estrutura:** Otimização da árvore de arquivos para melhor compatibilidade com outras modificações.

## ⚖️ Créditos e Compatibilidade
Este projeto é um **Patch/Add-on** e não existiria sem o trabalho fantástico dos autores originais. Abaixo, os mods cobertos pelo patch:

| Mod Original | ID Workshop |
| :--- | :--- |
| Generator Powered Buildings | 3597471949 |

*Agradeço imenso a todos os modders, pois sem eles nada disso existiria. É graças a esses desenvolvedores que a continuidade e melhoria dos mods é possível através desta comunidade.*

## 📦 Instalação
1. Inscreva-se no mod original.
2. Inscreva-se neste patch.
3. Certifique-se de que este patch seja o **ÚLTIMO A SER CARREGADO** na sua ordem de carregamento (load order).

## 🛠️ Ferramentas de Desenvolvimento

O repositório conta com dois utilitários centrais em Python para apoiar a auditoria de código, testes de integridade e processamento de assets:

### 🔍 1. Auditoria Geral de Qualidade
- **Script**: [tools/auditoria_mod.py](tools/auditoria_mod.py)
- **Funcionalidades**:
  - **Validação de Sintaxe (Estrutura de blocos Lua)**:
    ```bash
    python tools/auditoria_mod.py validar-sintaxe
    ```
  - **Auditoria de Traduções (PT-BR)**:
    ```bash
    python tools/auditoria_mod.py auditar-traducoes --ignorar-nativas
    ```
  - **Auditoria e Correção de Caminhos Absolutos**:
    ```bash
    # Apenas detectar caminhos absolutos e vazamentos locais
    python tools/auditoria_mod.py auditar-caminhos

    # Corrigir automaticamente caminhos locais apontando para o mod
    python tools/auditoria_mod.py auditar-caminhos --corrigir
    ```

### 🎨 2. Tools Assets - LKS SuperMod Patch
Reúne todas as operações de assets (extração, inspeção, conversão e auditoria de arquivos órfãos) em uma única interface (CLI / Menu interativo):
- **Script**: [tools/LKS_Tools.py](tools/LKS_Tools.py)
- **Localização Padrão do Jogo**: Configurável via variável `PZ_GAME_DIR` no arquivo `.env` na raiz do mod.
- **Modo Interativo (Menu)**:
  Executando sem argumentos adicionais, abre-se um assistente de terminal amigável passo a passo:
  ```bash
  python tools/LKS_Tools.py
  ```
- **Modo CLI (Argumentos diretos)**:
  - **Extrair assets originais do jogo (.pack ➔ PNG)**:
    ```bash
    python tools/LKS_Tools.py -e <Nome_Sprite_Original>
    ```
  - **Inspecionar propriedades de imagem (bit depth, alpha, etc.)**:
    ```bash
    python tools/LKS_Tools.py -i <imagem_ou_pasta>
    ```
  - **Otimizar textura PNG para 8-bit (evita travamentos no PZ)**:
    ```bash
    python tools/LKS_Tools.py -c <imagem_entrada> [-o <saida>]
    ```
  - **Auditar arquivos de imagens órfãos/não utilizados no código**:
    ```bash
    python tools/LKS_Tools.py -a
    ```
  - **Buscar referências de assets (UI 2D e Mundo 3D) de forma unificada**:
    ```bash
    python tools/LKS_Tools.py -b <termo_do_asset>
    ```