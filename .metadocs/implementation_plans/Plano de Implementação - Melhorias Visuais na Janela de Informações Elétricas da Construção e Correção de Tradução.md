# Plano de Implementação - Melhorias Visuais na Janela de Informações Elétricas da Construção e Correção de Tradução

Este documento detalha o plano técnico para ajustar a hierarquia de fontes, centralizar títulos/subtítulos, corrigir o nome da seção de termostato para "SISTEMA DE CALEFAÇÃO", e simplificar as variáveis de controle de opacidade do realce em `Thermostat_Alpha`.

## User Review Required

> [!IMPORTANT]
> - A altura da barra de título do `ISCollapsableWindow` nativo do Project Zomboid é configurada como 16 pixels. Para suportar o título principal centralizado e maior usando `FONT_M` de forma elegante, sobrescreveremos o método `titleBarHeight()` para retornar `22` pixels.
> - Limparemos temporariamente `self.title` no `prerender()` antes de chamar `ISCollapsableWindow.prerender(self)` para evitar que a API nativa do jogo desenhe o texto desalinhado e em fonte pequena na barra de título. Em seguida, desenharemos nós mesmos o título centralizado.
> - A tabela de configurações `Thermostat_Alpha` será simplificada para ter apenas a chave `activeHighlight` controlando a opacidade do botão selecionado (seja quente ou frio). O botão inativo manterá uma borda sutil de `20%` proporcional ao `activeHighlight`.

## Proposed Changes

---

### Interface do Usuário (UI)

#### [MODIFY] [PB_UI_GeneratorInfoWindow.lua](common/media/lua/client/ui/PB_UI_GeneratorInfoWindow.lua)

Propomos as seguintes alterações estruturais e de estilização:

1. **Simplificação das Variáveis de Opacidade**:
   - Substituir a tabela `Thermostat_Alpha` por:
     ```lua
     local Thermostat_Alpha = {
         activeHighlight = 100 -- Opacidade do realce do botão selecionado (0% a 100%)
     }
     ```

2. **Personalização e Hierarquia da Barra de Título**:
   - Sobrescrever `titleBarHeight` na janela:
     ```lua
     function PB_GeneratorInfoWindow:titleBarHeight()
         return 22
     end
     ```
   - No método `prerender()`, realizar o desenho manual do título da janela centralizado usando a fonte `FONT_M` (Medium):
     ```lua
     local titleText = self.title
     self.title = ""
     ISCollapsableWindow.prerender(self)
     self.title = titleText

     local th = self:titleBarHeight()
     local fontH = getTextManager():getFontHeight(FONT_M)
     local titleY = math.floor((th - fontH) / 2)
     local titleWidth = getTextManager():MeasureStringX(FONT_M, titleText)
     local titleX = math.floor((self.width - titleWidth) / 2)
     self:drawText(titleText, titleX, titleY, 1, 1, 1, 1, FONT_M)
     ```

3. **Centralização e Redimensionamento de Títulos de Seção**:
   - Modificar `drawSection` para usar a fonte `FONT_M` (Medium), centralizar horizontalmente o texto e retornar `y + 22` pixels (altura de linha ampliada):
     ```lua
     function PB_GeneratorInfoWindow:drawSection(x, y, title)
         self:drawRect(x, y, self.width - MARGIN * 2, 1, 0.55, 0.30, 0.30, 0.30)
         y = y + 5
         local textWidth = getTextManager():MeasureStringX(FONT_M, title)
         local titleX = math.floor((self.width - textWidth) / 2)
         self:drawText(title, titleX, y, 0.50, 0.78, 1.0, 1, FONT_M)
         return y + 22
     end
     ```
   - Corrigir o fallback de tradução no cabeçalho da seção de aquecimento:
     - De: `getText("IGUI_PB_SectionHeating") or "TERMOSTATO DO AMBIENTE INTERNO"`
     - Para: `getText("IGUI_PB_SectionHeating") or "SISTEMA DE CALEFAÇÃO"`

4. **Ajuste na Seção Manual de Barris**:
   - No `render()`, ajustar a seção `BARRIS` para usar a fonte `FONT_M` e ser centralizada horizontalmente na largura do painel, mantendo a contagem em litros (`totalStr`) à direita:
     ```lua
     local secTitle   = getText("IGUI_PB_SectionBarrels") or "BARRIS"
     self:drawRect(x0, y, self.width - MARGIN * 2, 1, 0.55, 0.30, 0.30, 0.30)
     y = y + 5
     local textWidth  = getTextManager():MeasureStringX(FONT_M, secTitle)
     local titleX     = math.floor((self.width - textWidth) / 2)
     self:drawText(secTitle, titleX, y, 0.50, 0.78, 1.0, 1, FONT_M)
     if totalStr ~= "" then
         local tw = getTextManager():MeasureStringX(FONT_S, totalStr)
         self:drawText(totalStr, x0 + (self.width - MARGIN * 2) - tw, y + 3, 0.97, 0.93, 0.55, 1, FONT_S)
     end
     y = y + 22
     ```

5. **Consumo de Opacidade Unificado**:
   - Ajustar as fórmulas de destaque no `render()` para usar `Thermostat_Alpha.activeHighlight` unificadamente:
     ```lua
     local alphaHighlight = (Thermostat_Alpha.activeHighlight or 100) / 100
     ```
   - Atualizar os blocos `drawRect` e `drawRectBorder` dos botões ativo e inativo de acordo.

---

### Tradução (Localization)

#### [MODIFY] [IG_UI.json](common/media/lua/shared/Translate/PTBR/IG_UI.json)

- Garantir que a chave `IGUI_PB_SectionHeating` esteja configurada como `"SISTEMA DE CALEFAÇÃO"`.

---

## Verification Plan

### Automated Tests
- Não se aplica (UI de Project Zomboid).

### Manual Verification
1. No jogo, abrir a janela "Informações Elétricas da Construção" (a partir de qualquer interruptor de luz).
2. Confirmar que a barra de título da janela está ligeiramente mais alta (`22` pixels), exibindo o título `"Informações Elétricas da Construção"` de forma centralizada e em tamanho médio (`FONT_M`).
3. Verificar se as seções `GERADOR`, `BARRIS`, `CONSTRUÇÃO` e `SISTEMA DE CALEFAÇÃO` usam a fonte `FONT_M`, estão centralizadas horizontalmente, e não sobrepõem os elementos seguintes (espaçamento `22` pixels).
4. No termostato do "SISTEMA DE CALEFAÇÃO", confirmar que:
   - Acima do botão frio (floco de neve), aparece o rótulo `"Standby"`.
   - Acima do botão quente (chama), aparece o rótulo `"Ligado"`.
   - Ambos os rótulos estão bem centralizados acima de seus respectivos ícones.
5. Alterar a opacidade em `Thermostat_Alpha.activeHighlight` para 100, 50, e 0 no arquivo de código, verificar se no jogo o preenchimento e a borda do botão ativo respondem de forma linear, e se a borda inativa diminui proporcionalmente.
