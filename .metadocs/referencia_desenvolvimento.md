# 📖 Guia de Referência de Desenvolvimento e Testes

Este documento serve como um guia rápido de consulta técnica para testes in-game, caminhos de sistema, controle de progresso de assets de eletrodomésticos (appliances) e execução de ferramentas auxiliares do mod.

---

## 📂 Diretórios do Jogo e Mod

*   **Instalação do Jogo (Project Zomboid)**: Configurável via `PZ_GAME_DIR` no arquivo `.env` na raiz do mod.
    *   *Nota*: Este caminho é automaticamente mantido de forma consistente no arquivo `.env` na raiz do mod.
*   **Destino de Assets de UI do Mod**: `common/media/ui/`
    *   *Nota*: Onde ficam as imagens das abas de inventário e botões de tomada/gerador.

---

## 🛠️ Status da Implementação de Ícones (Checklist)

Utilize a lista abaixo para gerenciar e acompanhar quais assets foram convertidos e validados in-game para evitar o reaproveitamento genérico de ícones do jogo original:

*   [x] **Máquina de Lavar Roupas** (`clothingwasher`)
    *   *Ícone Único Energizado*: `Container_ClothingWasher.png` (Concluído)
    *   *Ícone Único Desenergizado*: `LKS_Container_ClothingWasher_Electricity_Off.png` (Concluído)
*   [x] **Secadora de Roupas** (`clothingdryer`)
    *   *Ícone Único Energizado*: `Container_ClothingDryer.png` (Concluído)
    *   *Ícone Único Desenergizado*: `LKS_Container_ClothingDryer_Electricity_Off.png` (Concluído)
*   [x] **Geladeira** (`fridge`)
    *   *Ícone Único Energizado*: `Container_Fridge.png` (Concluído)
    *   *Ícone Único Desenergizado*: `LKS_Container_Fridge_Electricity_Off.png` (Concluído)
*   [x] **Freezer / Congelador** (`freezer`)
    *   *Ícone Único Energizado*: `Container_Freezer.png` (Concluído)
    *   *Ícone Único Desenergizado*: `LKS_Container_Freezer_Electricity_Off.png` (Concluído)
*   [ ] **Forno Micro-ondas** (`microwave`)
    *   *Ícone Único Energizado*: `Container_Microwave.png` (Asset original importado)
    *   *Ícone Único Desenergizado*: `LKS_Container_Microwave_Off.png` *(Aguardando criação gráfica)*
*   [ ] **Fogão / Forno Elétrico** (`stove`)
    *   *Ícone Único Energizado*: `Container_Stove.png` (Asset original importado)
    *   *Ícone Único Desenergizado*: `LKS_Container_Stove_Off.png` *(Aguardando criação gráfica)*

---

## 📌 Guia de Nomes Internos vs Nomes de Arquivos

Mapeamento completo para referência durante as edições de imagens e alterações no código Lua:

| Identificador do Mod (Lua) | Sprite Original no `.pack` | Arquivo do Mod (Energizado) | Arquivo do Mod (Sem Energia) |
| :--- | :--- | :--- | :--- |
| `clothingwasher` | `Container_ClothingWasher` | `Container_ClothingWasher.png` | `LKS_Container_ClothingWasher_Electricity_Off.png` |
| `clothingdryer` | `Container_ClothingDryer` | `Container_ClothingDryer.png` | `LKS_Container_ClothingDryer_Electricity_Off.png` |
| `fridge` | `Container_Fridge` | `Container_Fridge.png` | `LKS_Container_Fridge_Electricity_Off.png` |
| `freezer` | `Container_Freezer` | `Container_Freezer.png` | `LKS_Container_Freezer_Electricity_Off.png` |
| `microwave` | `Container_Microwave` | `Container_Microwave.png` | `LKS_Container_Microwave_Off.png` |
| `stove` | `Container_Oven` | `Container_Stove.png` | `LKS_Container_Stove_Off.png` |

---

## 💡 Próximos Passos de Criação e Edição (GIMP/Photoshop)

Como já extraímos com sucesso todos os 4 assets originais em cores para a pasta `common/media/ui/`:

1.  **Micro-ondas**:
    *   Abra `Container_Microwave.png` em seu editor gráfico.
    *   Crie a versão desenergizada (escala de cinza + plug desligado ou marcador off).
    *   Salve como `LKS_Container_Microwave_Off.png` em `common/media/ui/`.
2.  **Fogão / Forno**:
    *   Abra `Container_Stove.png` em seu editor gráfico.
    *   Crie a versão desenergizada correspondente.
    *   Salve como `LKS_Container_Stove_Off.png` em `common/media/ui/`.

---

## 🔨 Tilesets de Testes (Debug / Brush Tool)

Para spawnar e testar os contêineres e eletrodomésticos in-game usando o menu de **Debug / Brush Tool / Tiles**, utilize os seguintes nomes de tilesets:

| Eletrodoméstico | Tileset correspondente no PZ | Notas |
| :--- | :--- | :--- |
| **Lavadora de Roupas** (`clothingwasher`) | `appliances_laundry_01` | Contém máquinas de lavar residenciais e industriais |
| **Secadora de Roupas** (`clothingdryer`) | `appliances_laundry_01` | Contém secadoras residenciais e industriais |
| **Fogão / Forno Elétrico** (`stove`) | `appliances_cooking_01` | Contém fogões elétricos, fogões a gás e micro-ondas |
| **Micro-ondas** (`microwave`) | `appliances_cooking_01` | Vários modelos de bancada |
| **Geladeiras e Freezers** (`fridge` / `freezer`) | `appliances_refrigeration_01` | Geladeiras residenciais, industriais e freezers horizontais |

---

## 🛠️ Comandos Rápidos das Ferramentas (`tools/`)

### 🎨 1. Gerenciador de Assets (`gerenciador_assets.py`)
Centraliza operações de imagens do mod.

*   **Modo Interativo (Menu Passo-a-Passo)**:
    ```bash
    python tools/gerenciador_assets.py
    ```
*   **Extrair Assets Originais do Jogo (Fridge, Microwave, Freezer, Stove)**:
    ```bash
    python tools/gerenciador_assets.py extrair
    ```
*   **Extrair Sprites Customizados Arbitrários**:
    ```bash
    python tools/gerenciador_assets.py extrair -s NomeSpriteOriginal:NomeArquivoSaida.png
    ```
*   **Inspecionar Imagem (Resolução, Alpha, Bit-Depth)**:
    ```bash
    python tools/gerenciador_assets.py inspecionar common/media/ui/LKS_Container_Fridge_Electricity_Off.png
    ```
*   **Converter PNG de 16-bit para 8-bit (Evita crashes no PZ)**:
    ```bash
    python tools/gerenciador_assets.py converter <imagem_16bit.png> -o <imagem_8bit.png>
    ```
*   **Auditar Imagens Órfãs (Imagens sem uso nos scripts Lua)**:
    ```bash
    python tools/gerenciador_assets.py auditar
    ```

### 🔍 2. Auditoria Geral de Qualidade (`auditoria_mod.py`)
Valida a integridade do código Lua e traduções.

*   **Verificar Sintaxe dos Arquivos Lua**:
    ```bash
    python tools/auditoria_mod.py validar-sintaxe
    ```
*   **Auditar Traduções PT-BR**:
    ```bash
    python tools/auditoria_mod.py auditar-traducoes --ignorar-nativas
    ```
*   **Buscar e Corrigir Vazamentos de Caminhos Locais (Cwd/Absolutos)**:
    ```bash
    python tools/auditoria_mod.py auditar-caminhos --corrigir
    ```
