# Walkthrough - Tradução Estática de Categorias de Recipientes de Fluido

Este documento descreve a resolução da dívida técnica de tradução onde o jogo exibia "Recipiente de Água" para qualquer item que comportasse fluidos (como galões de gasolina, baldes com combustível, panelas, etc.).

## O que foi feito

### 1. Sobrescrita de Tradução da Categoria
- Identificamos nos arquivos de tradução originais da Build 42 do Project Zomboid (localizado em `Downloads/ProjectZomboid`) que a chave responsável por exibir a categoria na interface é `"IGUI_ItemCat_WaterContainer"`.
- Sobrescrevemos essa chave de forma limpa adicionando-a ao arquivo de tradução de interface existente do mod, [IG_UI.json](file:///c:/Users/LKSFERREIRA/Zomboid/mods/LKS_SuperMod_Patch/common/media/lua/shared/Translate/PTBR/IG_UI.json):
  ```json
  "IGUI_ItemCat_WaterContainer": "Recipiente de Líquido",
  ```
- Isso garante que a categoria seja alterada de forma estática e nativa para todos os recipientes de fluido, sem exigir processamento em Lua em tempo de execução.

## Como Validar
1. Inicie o jogo com o mod ativo.
2. Inspecione no inventário qualquer item que sirva como recipiente de fluidos contendo outros líquidos que não sejam água (como galão de gasolina, balde com combustível, etc.).
3. Verifique se a categoria do item no inventário mudou para *"Recipiente de Líquido"* de forma correta e consistente.
