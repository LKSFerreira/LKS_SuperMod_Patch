# Melhorias Visuais do Termostato e Ajustes de Layout

Este documento resume as melhorias na interface de clima da janela de energia da construção (`PB_UI_GeneratorInfoWindow.lua`), bem como a calibração estética e correção de traduções relacionadas.

## O que foi feito

### 1. Dimensionamento das Setas de Temperatura
- Aumentada a escala das setas de temperatura (`PB_Therm_Down` e `PB_Therm_Up`) de **16px** para **24px** na interface para melhor definição visual na tela.
- Ajustada a altura vertical da linha de temperatura para **28px** para comportar o novo tamanho de 24px sem sobrepor ou cortar elementos vizinhos.
- Alinhamento vertical preciso e dinâmico centralizando as setas e os textos na nova altura da linha.
- Ajustadas as caixas de clique do mouse (`_heatMinusArea` e `_heatPlusArea`) para casar milimetricamente com a nova área de exibição das setas de 24px.

### 2. Espaçamento Vertical (Respiro)
- Adicionado espaçamento vertical (`y = y + 12`) antes de iniciar a seção **SISTEMA DE CLIMATIZAÇÃO** para evitar que a linha divisória cinza-escuro e o título azul cortassem ou encostassem no texto "Carga da Rede Elétrica" da linha superior.

### 3. Melhoria nas Traduções em PT-BR
- Ajustadas e criadas chaves de tradução no arquivo de idioma `IG_UI.json`:
  - `IGUI_PB_SectionHeating`: Traduzido para `"SISTEMA DE CLIMATIZAÇÃO"` (ajustando fallbacks e consistência visual).
  - `IGUI_PB_HeatingStandby`: Traduzido para `"Standby"`.
  - `IGUI_PB_HeatingActive`: Traduzido para `"Ligado"`.

## Validação Manual Realizada
- Abertura da janela de energia elétrica a partir de interruptores de luz no jogo.
- Verificação visual da centralização horizontal e vertical das setas de temperatura e do texto de status.
- Teste de cliques nas setas para aumentar/diminuir temperatura confirmando o funcionamento preciso nas coordenadas atualizadas de 24px.
