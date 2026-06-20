-- ============================================================================
-- ARQUIVO: LKS_Debug_Tool.lua
-- EXTENSÃO: LKS SuperMod Patch (Ferramenta de Desenvolvimento Unificada)
-- OBJETIVO: Painel de depuração e desenvolvimento com sistema de abas escalável.
--           Centraliza todas as ferramentas de dev: Lua Reloader, Inspetor de
--           Menu de Contexto, Inspetor de Objetos e funcionalidades futuras.
-- AUTOR: LKS FERREIRA
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- ATALHO: F12 para abrir/fechar
-- DATA DA ÚLTIMA MODIFICAÇÃO: 16/06/2026
-- ============================================================================
--
-- ## ARQUITETURA:
--
-- A ferramenta usa um padrão de abas dinâmicas (tab system). Cada aba é uma
-- tabela Lua com a seguinte interface:
--
--   {
--       nome       = "Texto da Aba",
--       icone      = nil,  -- (opcional) caminho de textura para ícone na aba
--       criar      = function(self, painel, posicaoY) end,  -- cria widgets da aba
--       renderizar = function(self, painel) end,            -- desenho custom por frame
--       atualizar  = function(self, painel) end,            -- lógica por frame (opcional)
--       destruir   = function(self, painel) end,            -- cleanup ao trocar aba (opcional)
--   }
--
-- Para adicionar uma nova aba no futuro, basta registrar com:
--   LKS_DebugTool.registrarAba(definicaoAba)
--
-- ============================================================================

require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTickBox"
require "LKS_Debug_TooltipData"

-- ============================================================================
-- NAMESPACE E CONFIGURAÇÃO GLOBAL
-- ============================================================================

LKS_DebugTool = LKS_DebugTool or {}
LKS_DebugTool.abas = {}
LKS_DebugTool.dadosCompartilhados = {}

-- ============================================================================
-- 🎨 TEMA VISUAL: Escuro com acentos azuis (estilo IDE/terminal moderno)
-- ============================================================================

LKS_DebugTool.tema = {
    -- Fundo da janela
    fundoPrincipal      = { r = 0.08, g = 0.08, b = 0.12, a = 0.95 },
    bordaPrincipal      = { r = 0.25, g = 0.35, b = 0.55, a = 1.0 },

    -- Barra de abas
    fundoBarraAbas      = { r = 0.06, g = 0.06, b = 0.10, a = 1.0 },
    abaAtiva            = { r = 0.15, g = 0.25, b = 0.45, a = 1.0 },
    abaInativa          = { r = 0.10, g = 0.10, b = 0.16, a = 0.9 },
    abaHover            = { r = 0.12, g = 0.18, b = 0.32, a = 1.0 },
    textoAbaAtiva       = { r = 0.85, g = 0.92, b = 1.0, a = 1.0 },
    textoAbaInativa     = { r = 0.50, g = 0.55, b = 0.65, a = 1.0 },

    -- Conteúdo
    fundoConteudo       = { r = 0.07, g = 0.07, b = 0.11, a = 1.0 },
    bordaSecao         = { r = 0.20, g = 0.30, b = 0.50, a = 0.6 },
    textoTitulo         = { r = 0.70, g = 0.85, b = 1.0, a = 1.0 },
    textoNormal         = { r = 0.80, g = 0.82, b = 0.88, a = 1.0 },
    textoDetalhe        = { r = 0.50, g = 0.55, b = 0.65, a = 0.9 },

    -- Botões
    botaoPrimario       = { r = 0.15, g = 0.30, b = 0.55, a = 0.9 },
    botaoPrimarioHover  = { r = 0.20, g = 0.40, b = 0.70, a = 1.0 },
    botaoPerigo         = { r = 0.55, g = 0.15, b = 0.15, a = 0.9 },
    botaoSucesso        = { r = 0.12, g = 0.45, b = 0.20, a = 0.9 },

    -- Inputs
    fundoInput          = { r = 0.05, g = 0.05, b = 0.08, a = 1.0 },
    bordaInput          = { r = 0.25, g = 0.35, b = 0.55, a = 0.8 },

    -- Acento azul claro para highlights e indicadores
    acento              = { r = 0.30, g = 0.60, b = 1.0, a = 1.0 },
    acentoSuave         = { r = 0.20, g = 0.40, b = 0.80, a = 0.5 },
}

-- ============================================================================
-- DIMENSÕES DA JANELA
-- ============================================================================

local JANELA_LARGURA = 720
local JANELA_ALTURA = 560
local BARRA_ABAS_ALTURA = 38
local ABA_LARGURA_MIN = 120
local ABA_PADDING = 8
local MARGEM = 12
local ESPACO_VERTICAL = 8
local CONTEUDO_INICIO_Y = 58

-- ============================================================================
-- CLASSE PRINCIPAL: LKS_DebugToolWindow
-- ============================================================================

local LKS_DebugToolWindow = ISCollapsableWindow:derive("LKS_DebugToolWindow")

function LKS_DebugToolWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function LKS_DebugToolWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(true)
    self.minimumWidth = 580
    self.minimumHeight = 420

    self.abaAtualIndice = 1
    self.widgetsAba = {}

    -- Cria o conteúdo da primeira aba ativa
    self:construirAbaAtual()
end

--- Remove todos os widgets da aba atual antes de trocar.
function LKS_DebugToolWindow:limparWidgetsAba()
    -- Chama destruir da aba atual se existir
    local abaAtual = LKS_DebugTool.abas[self.abaAtualIndice]
    if abaAtual and abaAtual.destruir then
        abaAtual.destruir(abaAtual, self)
    end

    -- Remove widgets filhos da aba (exceto os da barra de título)
    for _, widget in ipairs(self.widgetsAba) do
        if widget and widget.removeFromUIManager then
            self:removeChild(widget)
        end
    end
    self.widgetsAba = {}
end

--- Constrói os widgets da aba selecionada.
function LKS_DebugToolWindow:construirAbaAtual()
    local aba = LKS_DebugTool.abas[self.abaAtualIndice]
    if not aba then return end

    if aba.criar then
        aba.criar(aba, self, CONTEUDO_INICIO_Y + MARGEM)
    end
end

--- Troca para uma aba pelo índice.
---
--- @param indice number O índice da aba destino.
function LKS_DebugToolWindow:trocarAba(indice)
    if indice == self.abaAtualIndice then return end
    if indice < 1 or indice > #LKS_DebugTool.abas then return end

    self:limparWidgetsAba()
    self.abaAtualIndice = indice
    self:construirAbaAtual()
end

--- Registra um widget como pertencente à aba atual (para limpeza ao trocar).
---
--- @param widget ISUIElement O widget a rastrear.
function LKS_DebugToolWindow:registrarWidget(widget)
    table.insert(self.widgetsAba, widget)
end

--- Adiciona um widget filho e o registra para limpeza automática.
---
--- @param widget ISUIElement O widget a adicionar.
function LKS_DebugToolWindow:adicionarWidgetAba(widget)
    self:addChild(widget)
    self:registrarWidget(widget)
end

function LKS_DebugToolWindow:prerender()
    ISCollapsableWindow.prerender(self)

    local tema = LKS_DebugTool.tema
    local tituloH = self:titleBarHeight()

    -- Fundo da barra de abas
    self:drawRect(0, tituloH, self.width, BARRA_ABAS_ALTURA,
        tema.fundoBarraAbas.a, tema.fundoBarraAbas.r, tema.fundoBarraAbas.g, tema.fundoBarraAbas.b)

    -- Linha inferior da barra de abas (separador)
    self:drawRect(0, tituloH + BARRA_ABAS_ALTURA - 1, self.width, 1,
        tema.bordaSecao.a, tema.bordaSecao.r, tema.bordaSecao.g, tema.bordaSecao.b)

    -- Desenha cada aba
    local abaX = ABA_PADDING
    local abaY = tituloH + 3
    local abaAltura = BARRA_ABAS_ALTURA - 4

    for indice, aba in ipairs(LKS_DebugTool.abas) do
        local textoLargura = getTextManager():MeasureStringX(UIFont.Small, aba.nome)
        local textoAltura = getTextManager():MeasureStringY(UIFont.Small, aba.nome)
        local abaLargura = math.max(ABA_LARGURA_MIN, textoLargura + 24)

        local ehAtiva = (indice == self.abaAtualIndice)
        local corFundo = ehAtiva and tema.abaAtiva or tema.abaInativa
        local corTexto = ehAtiva and tema.textoAbaAtiva or tema.textoAbaInativa

        -- Fundo da aba
        self:drawRect(abaX, abaY, abaLargura, abaAltura,
            corFundo.a, corFundo.r, corFundo.g, corFundo.b)

        -- Indicador inferior azul na aba ativa
        if ehAtiva then
            self:drawRect(abaX, abaY + abaAltura - 2, abaLargura, 2,
                tema.acento.a, tema.acento.r, tema.acento.g, tema.acento.b)
        end

        -- Borda sutil
        self:drawRectBorder(abaX, abaY, abaLargura, abaAltura,
            0.3, tema.bordaSecao.r, tema.bordaSecao.g, tema.bordaSecao.b)

        -- Texto centralizado (vertical e horizontal)
        local textoX = abaX + (abaLargura - textoLargura) / 2
        local textoY = abaY + (abaAltura - textoAltura) / 2
        self:drawText(aba.nome, textoX, textoY, corTexto.r, corTexto.g, corTexto.b, corTexto.a, UIFont.Small)

        -- Armazena bounds para detecção de clique
        aba._bounds = { x = abaX, y = abaY, largura = abaLargura, altura = abaAltura }

        abaX = abaX + abaLargura + 4
    end

    -- Fundo da área de conteúdo
    local conteudoY = tituloH + BARRA_ABAS_ALTURA
    local conteudoAltura = self.height - conteudoY
    self:drawRect(MARGEM, conteudoY + MARGEM / 2, self.width - MARGEM * 2, conteudoAltura - MARGEM,
        tema.fundoConteudo.a, tema.fundoConteudo.r, tema.fundoConteudo.g, tema.fundoConteudo.b)
end

function LKS_DebugToolWindow:render()
    ISCollapsableWindow.render(self)

    -- Delegação de renderização customizada para a aba ativa
    local abaAtual = LKS_DebugTool.abas[self.abaAtualIndice]
    if abaAtual and abaAtual.renderizar then
        abaAtual.renderizar(abaAtual, self)
    end
end

function LKS_DebugToolWindow:update()
    ISCollapsableWindow.update(self)

    -- Delegação de lógica por frame para a aba ativa
    local abaAtual = LKS_DebugTool.abas[self.abaAtualIndice]
    if abaAtual and abaAtual.atualizar then
        abaAtual.atualizar(abaAtual, self)
    end
end

function LKS_DebugToolWindow:onMouseDown(x, y)
    -- Detecta clique nas abas
    local tituloH = self:titleBarHeight()
    if y >= tituloH and y <= tituloH + BARRA_ABAS_ALTURA then
        for indice, aba in ipairs(LKS_DebugTool.abas) do
            if aba._bounds then
                local bounds = aba._bounds
                if x >= bounds.x and x <= bounds.x + bounds.largura
                    and y >= bounds.y and y <= bounds.y + bounds.altura then
                    self:trocarAba(indice)
                    return true
                end
            end
        end
    end

    return ISCollapsableWindow.onMouseDown(self, x, y)
end

function LKS_DebugToolWindow:close()
    -- Chama destruir da aba atual
    local abaAtual = LKS_DebugTool.abas[self.abaAtualIndice]
    if abaAtual and abaAtual.destruir then
        abaAtual.destruir(abaAtual, self)
    end

    self:removeFromUIManager()
    LKS_DebugTool.instance = nil
end

function LKS_DebugToolWindow:new(posicaoX, posicaoY)
    local objeto = ISCollapsableWindow:new(posicaoX, posicaoY, JANELA_LARGURA, JANELA_ALTURA)
    setmetatable(objeto, self)
    self.__index = self
    objeto.title = getText("IGUI_LKS_Debug_WindowTitle") or "Ferramenta de Debug LKS"
    objeto.moveWithMouse = true
    objeto.resizable = true
    objeto.drawFrame = true
    objeto.backgroundColor = LKS_DebugTool.tema.fundoPrincipal
    objeto.borderColor = LKS_DebugTool.tema.bordaPrincipal
    return objeto
end

-- ============================================================================
-- API PÚBLICA: Registro de Abas
-- ============================================================================

--- Registra uma nova aba no sistema de debug.
---
--- @param definicaoAba table Tabela com campos: nome, criar, renderizar, atualizar, destruir.
function LKS_DebugTool.registrarAba(definicaoAba)
    table.insert(LKS_DebugTool.abas, definicaoAba)
end

-- ============================================================================
-- TOGGLE (F12)
-- ============================================================================

function LKS_DebugTool.toggle()
    if LKS_DebugTool.instance then
        LKS_DebugTool.instance:close()
    else
        local larguraTela = getCore():getScreenWidth()
        local alturaTela = getCore():getScreenHeight()
        local posicaoX = (larguraTela - JANELA_LARGURA) / 2
        local posicaoY = (alturaTela - JANELA_ALTURA) / 2

        local janela = LKS_DebugToolWindow:new(posicaoX, posicaoY)
        janela:initialise()
        janela:addToUIManager()
        LKS_DebugTool.instance = janela
    end
end

-- ============================================================================
-- ABA 1: RECARREGAR (LUA RELOADER)
-- ============================================================================

local abaRecarregar = {
    nome = getText("IGUI_LKS_Debug_TabReload") or "Recarregar",
    filtroTexto = "",
    resultadosFiltro = 0,
    arquivosPorMod = {},
    modsDisponiveis = nil,
    modsAtivos = nil,
    painelModsVisivel = false,
    todosArquivosAtivo = false,
}

function abaRecarregar.criar(self, painel, posicaoY)
    local tema = LKS_DebugTool.tema
    local margemEsquerda = MARGEM * 2
    local larguraUtil = painel.width - margemEsquerda - MARGEM * 2
    local alturaRedimensionamento = painel:resizeWidgetHeight()
    local alturaLinha = 26
    local alturaBotao = 28
    local statusAltura = 22

    -- Linha 1: Botão [Mods Habilitados] + Título
    local larguraBotaoMods = 140

    local botaoModsHabilitados = ISButton:new(
        margemEsquerda, posicaoY, larguraBotaoMods, alturaLinha,
        getText("IGUI_LKS_Debug_EnabledMods") or "Mods habilitados", painel, function()
            abaRecarregar.alternarPainelMods(self, painel)
        end)
    botaoModsHabilitados:initialise()
    botaoModsHabilitados.backgroundColor = { r = 0.60, g = 0.40, b = 0.10, a = 0.95 }
    botaoModsHabilitados.borderColor = { r = 0.80, g = 0.55, b = 0.15, a = 1.0 }
    painel:adicionarWidgetAba(botaoModsHabilitados)

    local rotuloTitulo = ISLabel:new(
        margemEsquerda + larguraBotaoMods + ESPACO_VERTICAL * 2,
        posicaoY + 3, alturaLinha,
        getText("IGUI_LKS_Debug_ReloadTitle") or "Recarregamento de Arquivos dos Mods",
        tema.textoTitulo.r, tema.textoTitulo.g, tema.textoTitulo.b, tema.textoTitulo.a,
        UIFont.Medium, true)
    painel:adicionarWidgetAba(rotuloTitulo)

    posicaoY = posicaoY + alturaLinha + ESPACO_VERTICAL

    -- Linha 2: Descrição
    local rotuloDescricao = ISLabel:new(margemEsquerda, posicaoY, 18,
        getText("IGUI_LKS_Debug_ReloadDescription") or "Filtre por nome ou selecione mods para recarregar arquivos Lua em tempo real.",
        tema.textoDetalhe.r, tema.textoDetalhe.g, tema.textoDetalhe.b, tema.textoDetalhe.a,
        UIFont.Small, true)
    painel:adicionarWidgetAba(rotuloDescricao)

    posicaoY = posicaoY + 20 + ESPACO_VERTICAL

    -- Linha 3: Campo de filtro (estica com a janela)
    local rotuloFiltro = ISLabel:new(
        margemEsquerda, posicaoY + 5, alturaLinha, getText("IGUI_LKS_Debug_FilterLabel") or "Filtro:",
        tema.textoNormal.r, tema.textoNormal.g, tema.textoNormal.b, tema.textoNormal.a,
        UIFont.Small, true)
    painel:adicionarWidgetAba(rotuloFiltro)

    local deslocamentoFiltro = 50
    local entradaFiltro = ISTextEntryBox:new(
        "",
        margemEsquerda + deslocamentoFiltro,
        posicaoY,
        larguraUtil - deslocamentoFiltro,
        alturaLinha)
    entradaFiltro.anchorRight = true
    entradaFiltro:initialise()
    entradaFiltro:instantiate()
    entradaFiltro:setClearButton(true)
    entradaFiltro:setText("")
    entradaFiltro:setPlaceholderText(    getText("IGUI_LKS_Debug_FilterPlaceholder") or "Filtrar por nome de arquivo...")
    entradaFiltro.backgroundColor = tema.fundoInput
    entradaFiltro.borderColor = tema.bordaInput

    -- Callback event-driven: filtra a lista a cada tecla digitada
    local referenciaAba = self
    local referenciaPainel = painel
    entradaFiltro.onTextChangeFunction = function(alvo, entradaTexto)
        local textoNovo = entradaTexto:getInternalText()
        if textoNovo == nil then textoNovo = "" end
        referenciaAba.filtroTexto = textoNovo
        abaRecarregar.atualizarLista(referenciaAba, referenciaPainel)
    end
    entradaFiltro.target = painel

    painel:adicionarWidgetAba(entradaFiltro)
    self.entradaFiltro = entradaFiltro
    self.filtroTexto = ""

    posicaoY = posicaoY + alturaLinha + ESPACO_VERTICAL

    -- Linha 4: Botões de ação
    local espacamentoBotao = 8
    local larguraBotao = math.floor((larguraUtil - espacamentoBotao * 2) / 3)

    local botaoRecarregarTodos = ISButton:new(
        margemEsquerda, posicaoY, larguraBotao, alturaBotao,
        getText("IGUI_LKS_Debug_ReloadAll") or "Recarregar todos", painel, function()
            abaRecarregar.recarregarTodos(self, painel)
        end)
    botaoRecarregarTodos:initialise()
    botaoRecarregarTodos.backgroundColor = tema.botaoPrimario
    botaoRecarregarTodos.borderColor = tema.bordaSecao
    painel:adicionarWidgetAba(botaoRecarregarTodos)

    local botaoRecarregarMarcados = ISButton:new(
        margemEsquerda + larguraBotao + espacamentoBotao,
        posicaoY, larguraBotao, alturaBotao,
        getText("IGUI_LKS_Debug_ReloadSelected") or "Recarregar marcados", painel, function()
            abaRecarregar.recarregarMarcados(self, painel)
        end)
    botaoRecarregarMarcados:initialise()
    botaoRecarregarMarcados.backgroundColor = tema.botaoSucesso
    botaoRecarregarMarcados.borderColor = tema.bordaSecao
    painel:adicionarWidgetAba(botaoRecarregarMarcados)

    local botaoLimparFiltro = ISButton:new(
        margemEsquerda + (larguraBotao + espacamentoBotao) * 2,
        posicaoY, larguraBotao, alturaBotao,
        getText("IGUI_LKS_Debug_ClearFilter") or "Limpar filtro", painel, function()
            self.entradaFiltro:setText("")
            self.filtroTexto = ""
            abaRecarregar.atualizarLista(self, painel)
        end)
    botaoLimparFiltro:initialise()
    botaoLimparFiltro.backgroundColor = tema.abaInativa
    botaoLimparFiltro.borderColor = tema.bordaSecao
    painel:adicionarWidgetAba(botaoLimparFiltro)

    posicaoY = posicaoY + alturaBotao + ESPACO_VERTICAL

    -- Lista de arquivos com checkbox (preenche o espaço restante, redimensiona com a janela)
    local alturaLista = painel.height - posicaoY - statusAltura - alturaRedimensionamento - ESPACO_VERTICAL * 2
    local listaArquivos = ISScrollingListBox:new(margemEsquerda, posicaoY, larguraUtil, alturaLista)
    listaArquivos.anchorRight = true
    listaArquivos.anchorBottom = true
    listaArquivos:initialise()
    listaArquivos:instantiate()
    listaArquivos.itemheight = 24
    listaArquivos.backgroundColor = tema.fundoInput
    listaArquivos.borderColor = tema.bordaInput
    listaArquivos.drawBorder = true
    listaArquivos.doDrawItem = abaRecarregar.desenharItemLista

    -- Intercepta clique para toggle de checkbox
    listaArquivos.onMouseDown = function(listaSelf, posicaoMouseX, posicaoMouseY)
        ISScrollingListBox.onMouseDown(listaSelf, posicaoMouseX, posicaoMouseY)
        local indiceLinha = listaSelf:rowAt(posicaoMouseX, posicaoMouseY)
        if indiceLinha and indiceLinha > 0 and indiceLinha <= #listaSelf.items then
            local itemClicado = listaSelf.items[indiceLinha]
            itemClicado.item.marcado = not itemClicado.item.marcado
        end
    end

    painel:adicionarWidgetAba(listaArquivos)
    self.listaArquivos = listaArquivos

    -- Barra de status (ancorada no rodapé, acompanha redimensionamento)
    local statusPosicaoY = posicaoY + alturaLista + ESPACO_VERTICAL
    local rotuloStatus = ISLabel:new(margemEsquerda, statusPosicaoY, statusAltura, "",
        tema.textoDetalhe.r, tema.textoDetalhe.g, tema.textoDetalhe.b, tema.textoDetalhe.a,
        UIFont.Small, true)
    rotuloStatus.anchorBottom = true
    rotuloStatus.anchorTop = false
    painel:adicionarWidgetAba(rotuloStatus)
    self.rotuloStatus = rotuloStatus
    abaRecarregar.definirStatus(self, getText("IGUI_LKS_Debug_ReadyStatus") or "Pronto. Selecione arquivos e clique em Recarregar marcados.")

    -- Popula a lista inicial
    abaRecarregar.inicializarMods(self)
    abaRecarregar.atualizarLista(self, painel)
end

--- Alterna a exibição do painel de seleção de mods (toggle).
--- Quando ativado, lista todos os mods ativos no jogo para que o usuário
--- selecione quais mods participarão da filtragem e recarga.
function abaRecarregar.alternarPainelMods(self, painel)
    -- Se o painel de mods já está visível, esconde
    if self.painelModsVisivel then
        self.painelModsVisivel = false
        if self.listaModsWidget then
            painel:removeChild(self.listaModsWidget)
            self.listaModsWidget = nil
        end
        -- Restaura visibilidade da lista de arquivos
        if self.listaArquivos then
            self.listaArquivos:setVisible(true)
        end
        abaRecarregar.atualizarLista(self, painel)
        return
    end

    -- Mostra o painel de seleção de mods sobre a lista de arquivos
    self.painelModsVisivel = true

    -- Esconde a lista de arquivos para não renderizar por baixo
    if self.listaArquivos then
        self.listaArquivos:setVisible(false)
    end

    -- Garante que os mods foram inicializados
    abaRecarregar.inicializarMods(self)

    -- Cria a lista visual de mods (substitui a lista de arquivos temporariamente)
    local tema = LKS_DebugTool.tema
    local margemEsquerda = MARGEM * 2
    local larguraUtil = painel.width - margemEsquerda - MARGEM * 2
    local posY = self.listaArquivos:getY()
    local alturaLista = self.listaArquivos:getHeight()

    local listaMods = ISScrollingListBox:new(margemEsquerda, posY, larguraUtil, alturaLista)
    listaMods.anchorRight = true
    listaMods.anchorBottom = true
    listaMods:initialise()
    listaMods:instantiate()
    listaMods.itemheight = 28
    listaMods.backgroundColor = { r = 0.06, g = 0.06, b = 0.10, a = 1.0 }
    listaMods.borderColor = tema.acento
    listaMods.drawBorder = true
    listaMods.doDrawItem = abaRecarregar.desenharItemMod

    -- Primeira opção especial: "Todos os arquivos .lua"
    listaMods:addItem(getText("IGUI_LKS_Debug_AllLuaFiles") or "Todos os arquivos .lua", { modId = "__TODOS__", ativo = self.todosArquivosAtivo, especial = true })

    -- Popula com mods disponíveis
    for _, modId in ipairs(self.modsDisponiveis) do
        local ativo = self.modsAtivos[modId] == true
        listaMods:addItem(modId, { modId = modId, ativo = ativo })
    end

    -- Ao clicar em um mod, alterna ativação
    listaMods.onMouseDown = function(listaSelf, x, y)
        ISScrollingListBox.onMouseDown(listaSelf, x, y)
        local indice = listaSelf:rowAt(x, y)
        if indice and indice > 0 and indice <= #listaSelf.items then
            local item = listaSelf.items[indice]
            local dados = item.item

            if dados.modId == "__TODOS__" then
                -- Toggle "Todos os arquivos .lua"
                local novoEstado = not dados.ativo
                dados.ativo = novoEstado
                self.todosArquivosAtivo = novoEstado

                -- Ao ativar "Todos", marca todos os mods individuais
                if novoEstado then
                    for _, itemMod in ipairs(listaSelf.items) do
                        if itemMod.item.modId ~= "__TODOS__" then
                            itemMod.item.ativo = true
                            self.modsAtivos[itemMod.item.modId] = true
                        end
                    end
                end
            else
                -- Toggle individual: não afeta o estado de "Todos"
                dados.ativo = not dados.ativo
                self.modsAtivos[dados.modId] = dados.ativo
            end
        end
    end

    painel:addChild(listaMods)
    self.listaModsWidget = listaMods
end



--- Renderizador para itens da lista de mods (checkbox visual).
function abaRecarregar.desenharItemMod(self, y, item, alt)
    local tema = LKS_DebugTool.tema
    local alturaItem = self.itemheight
    local dados = item.item

    -- Hover
    if self.mouseoverselected == item.index then
        self:drawRect(0, y, self:getWidth(), alturaItem, 0.08, 0.3, 0.5, 0.8)
    end

    -- Fundo especial para "Todos os arquivos .lua"
    if dados.especial then
        self:drawRect(0, y, self:getWidth(), alturaItem, 0.06, tema.acento.r, tema.acento.g, tema.acento.b)
    end

    -- Checkbox visual — centralizada verticalmente na linha
    local checkSize = 14
    local checkX = 12
    local checkY = y + math.floor((alturaItem - checkSize) / 2)

    if dados.ativo then
        self:drawRect(checkX, checkY, checkSize, checkSize, 0.9, tema.acento.r, tema.acento.g, tema.acento.b)
        local textoX = "X"
        local larguraTexto = getTextManager():MeasureStringX(UIFont.Small, textoX)
        local alturaTexto = getTextManager():MeasureStringY(UIFont.Small, textoX)
        local centroX = checkX + math.floor((checkSize - larguraTexto) / 2)
        local centroY = checkY + math.floor((checkSize - alturaTexto) / 2)
        self:drawText(textoX, centroX, centroY, 1, 1, 1, 1, UIFont.Small)
    else
        self:drawRectBorder(checkX, checkY, checkSize, checkSize, 0.7, 0.5, 0.5, 0.6)
    end

    -- Nome do mod — alinhado verticalmente ao centro da linha
    local textoNome = item.text or ""
    local alturaTextoNome = getTextManager():MeasureStringY(UIFont.Small, textoNome)
    local textoY = y + math.floor((alturaItem - alturaTextoNome) / 2)
    local textoXPos = checkX + checkSize + 12

    local corTexto = dados.especial and tema.textoAbaAtiva or (dados.ativo and tema.textoAbaAtiva or tema.textoDetalhe)
    local fonte = dados.especial and UIFont.Medium or UIFont.Small
    self:drawText(textoNome, textoXPos, textoY, corTexto.r, corTexto.g, corTexto.b, corTexto.a, fonte)

    -- Separador após "Todos"
    if dados.especial then
        self:drawRect(0, y + alturaItem - 1, self:getWidth(), 1,
            0.4, tema.bordaSecao.r, tema.bordaSecao.g, tema.bordaSecao.b)
    end

    return y + alturaItem
end

--- Coleta os arquivos Lua recarregáveis de um mod pelo seu ID.
---
--- Utiliza as APIs nativas do debug do PZ: `getLoadedLuaCount()` e `getLoadedLua(indice)`
--- para obter todos os arquivos Lua carregados pelo engine, depois filtra pelo
--- diretório do mod obtido via `getModInfoByID(modId):getDir()`.
---
--- @param modId string O ID do mod (ex: "LKSSuperModPatch").
--- @return table arquivos Lista de caminhos completos para `reloadLuaFile`.
function abaRecarregar.coletarArquivosDeMod(self, modId)
    local arquivos = {}

    if not getModInfoByID then return arquivos end

    local modInfo = getModInfoByID(modId)
    if not modInfo then return arquivos end

    local modDir = modInfo:getDir()
    if not modDir then return arquivos end

    -- Normaliza o diretório do mod para comparação
    modDir = string.gsub(string.lower(tostring(modDir)), "\\", "/")

    -- Percorre TODOS os arquivos Lua carregados pelo engine
    local totalArquivos = getLoadedLuaCount()
    for indice = 0, totalArquivos - 1 do
        local caminhoCompleto = getLoadedLua(indice)
        if caminhoCompleto then
            local caminhoNormalizado = string.gsub(string.lower(tostring(caminhoCompleto)), "\\", "/")
            -- Verifica se o arquivo pertence ao diretório deste mod
            if string.find(caminhoNormalizado, modDir, 1, true) then
                table.insert(arquivos, tostring(caminhoCompleto))
            end
        end
    end

    table.sort(arquivos)

    if #arquivos > 0 then
        print("[LKS Debug Tool] Mod '" .. modId .. "': " .. tostring(#arquivos) .. " arquivos encontrados.")
    else
        print("[LKS Debug Tool] Mod '" .. modId .. "': 0 arquivos (dir=" .. modDir .. ").")
    end

    return arquivos
end

--- Inicializa os mods disponíveis e coleta arquivos do LKS na primeira abertura.
function abaRecarregar.inicializarMods(self)
    if self.modsDisponiveis then return end

    self.modsDisponiveis = {}
    self.modsAtivos = {}
    self.arquivosPorMod = {}

    -- Coleta todos os mods ativos do jogo
    local modosAtivos = getActivatedMods and getActivatedMods()
    if modosAtivos then
        for indice = 0, modosAtivos:size() - 1 do
            local modId = modosAtivos:get(indice)
            if modId then
                local idStr = type(modId) == "string" and modId or tostring(modId)
                table.insert(self.modsDisponiveis, idStr)
                -- LKS ativo por padrão, outros desativados
                self.modsAtivos[idStr] = (idStr == "LKSSuperModPatch")
            end
        end
    end

    if #self.modsDisponiveis == 0 then
        self.modsDisponiveis = { "LKSSuperModPatch" }
        self.modsAtivos = { LKSSuperModPatch = true }
    end

    table.sort(self.modsDisponiveis)

    -- Coleta arquivos dos mods ativos
    for modId, ativo in pairs(self.modsAtivos) do
        if ativo then
            self.arquivosPorMod[modId] = abaRecarregar.coletarArquivosDeMod(self, modId)
            print("[LKS Debug Tool] Mod '" .. modId .. "': " .. tostring(#self.arquivosPorMod[modId]) .. " arquivos encontrados.")
        end
    end
end

--- Retorna a lista de arquivos de acordo com o modo ativo.
---
--- Modo "Todos os arquivos .lua": retorna TODOS os arquivos Lua carregados pelo
--- engine, excluindo apenas arquivos de mods que foram explicitamente desmarcados.
---
--- Modo normal: retorna apenas arquivos dos mods individualmente marcados.
---
--- @return table arquivos Lista unificada de caminhos ordenada alfabeticamente.
function abaRecarregar.obterArquivosAtivos(self)
    if self.todosArquivosAtivo then
        return abaRecarregar.obterTodosArquivosComExclusao(self)
    end

    -- Modo normal: apenas mods marcados
    local arquivos = {}
    for modId, ativo in pairs(self.modsAtivos) do
        if ativo then
            if not self.arquivosPorMod[modId] then
                self.arquivosPorMod[modId] = abaRecarregar.coletarArquivosDeMod(self, modId)
            end
            for _, arquivo in ipairs(self.arquivosPorMod[modId]) do
                table.insert(arquivos, arquivo)
            end
        end
    end

    table.sort(arquivos)
    return arquivos
end

--- Retorna todos os arquivos Lua carregados pelo engine, excluindo
--- aqueles que pertencem a mods explicitamente desmarcados.
---
--- @return table arquivos Lista de todos os caminhos Lua, filtrada por exclusões.
function abaRecarregar.obterTodosArquivosComExclusao(self)
    local arquivos = {}

    -- Coleta diretórios dos mods desmarcados para exclusão
    local diretoriosExcluidos = {}
    for modId, ativo in pairs(self.modsAtivos) do
        if not ativo then
            local modInfo = getModInfoByID and getModInfoByID(modId)
            if modInfo then
                local modDir = modInfo:getDir()
                if modDir then
                    local dirNormalizado = string.gsub(string.lower(tostring(modDir)), "\\", "/")
                    table.insert(diretoriosExcluidos, dirNormalizado)
                end
            end
        end
    end

    -- Percorre TODOS os arquivos Lua carregados
    local totalArquivos = getLoadedLuaCount()
    for indice = 0, totalArquivos - 1 do
        local caminhoCompleto = getLoadedLua(indice)
        if caminhoCompleto then
            local caminhoNormalizado = string.gsub(string.lower(tostring(caminhoCompleto)), "\\", "/")

            -- Verifica se o arquivo pertence a algum mod excluído
            local excluido = false
            for _, dirExcluido in ipairs(diretoriosExcluidos) do
                if string.find(caminhoNormalizado, dirExcluido, 1, true) then
                    excluido = true
                    break
                end
            end

            if not excluido then
                table.insert(arquivos, tostring(caminhoCompleto))
            end
        end
    end

    table.sort(arquivos)
    return arquivos
end

--- Atualiza a lista visual com base nos mods selecionados e no filtro digitado.
---
--- Usa `getShortenedFilename` (API nativa do PZ) para exibir nomes curtos na
--- lista, enquanto armazena o caminho completo no `.item.caminho` para reload.
function abaRecarregar.atualizarLista(self, painel)
    if not self.listaArquivos then return end

    self.listaArquivos:clear()

    local filtro = string.lower(tostring(self.filtroTexto or ""))

    local contador = 0
    local arquivosAtivos = abaRecarregar.obterArquivosAtivos(self)

    for _, caminhoCompleto in ipairs(arquivosAtivos) do
        local nomeAbreviado = getShortenedFilename(caminhoCompleto) or caminhoCompleto
        local incluir = true
        if filtro ~= "" then
            incluir = string.find(string.lower(nomeAbreviado), filtro, 1, true) ~= nil
        end

        if incluir then
            self.listaArquivos:addItem(nomeAbreviado, { caminho = caminhoCompleto })
            contador = contador + 1
        end
    end

    self.resultadosFiltro = contador
end

--- Renderizador customizado com checkbox para cada arquivo da lista.
function abaRecarregar.desenharItemLista(self, y, item, alt)
    local tema = LKS_DebugTool.tema
    local alturaItem = self.itemheight
    local dados = item.item

    -- Hover
    if self.mouseoverselected == item.index then
        self:drawRect(0, y, self:getWidth(), alturaItem, 0.08, 0.3, 0.5, 0.8)
    end

    -- Checkbox visual — centralizada verticalmente
    local checkSize = 12
    local checkX = 8
    local checkY = y + math.floor((alturaItem - checkSize) / 2)

    if dados.marcado then
        self:drawRect(checkX, checkY, checkSize, checkSize, 0.9, tema.acento.r, tema.acento.g, tema.acento.b)
        local textoMarca = "X"
        local larguraMarca = getTextManager():MeasureStringX(UIFont.Small, textoMarca)
        local alturaMarca = getTextManager():MeasureStringY(UIFont.Small, textoMarca)
        self:drawText(textoMarca,
            checkX + math.floor((checkSize - larguraMarca) / 2),
            checkY + math.floor((checkSize - alturaMarca) / 2),
            1, 1, 1, 1, UIFont.Small)
    else
        self:drawRectBorder(checkX, checkY, checkSize, checkSize, 0.5, 0.4, 0.4, 0.5)
    end

    -- Nome do arquivo
    local textoNome = item.text or ""
    local alturaNome = getTextManager():MeasureStringY(UIFont.Small, textoNome)
    local textoY = y + math.floor((alturaItem - alturaNome) / 2)
    local textoX = checkX + checkSize + 8

    local corTexto = tema.textoNormal
    if string.find(string.lower(textoNome), "lks") then
        corTexto = tema.acento
    end
    if dados.marcado then
        corTexto = tema.textoAbaAtiva
    end

    self:drawText(textoNome, textoX, textoY, corTexto.r, corTexto.g, corTexto.b, corTexto.a, UIFont.Small)

    return y + alturaItem
end

local LIMITE_RELOAD_SEGURO = 50

--- Verifica se o recarregamento em massa e seguro.
--- Arquivos de um unico mod sao sempre permitidos independente da quantidade.
--- O limite so se aplica quando multiplos mods ou "Todos os arquivos .lua" estao ativos.
---@param self table Instancia da janela de debug.
---@param totalArquivos number Quantidade de arquivos a recarregar.
---@return boolean seguro true se o recarregamento pode prosseguir.
function abaRecarregar.verificarSegurancaReload(self, totalArquivos)
    if totalArquivos <= LIMITE_RELOAD_SEGURO then
        return true
    end

    if self.todosArquivosAtivo then
        return false
    end

    local quantidadeModsAtivos = 0
    for _, ativo in pairs(self.modsAtivos) do
        if ativo then
            quantidadeModsAtivos = quantidadeModsAtivos + 1
        end
    end

    return quantidadeModsAtivos <= 1
end

--- Recarrega TODOS os arquivos visíveis na lista (respeitando filtro e mods ativos).
--- Exibe aviso de segurança quando a quantidade excede o limite seguro e multiplos mods estao ativos.
function abaRecarregar.recarregarTodos(self, painel)
    if not self.listaArquivos then return end

    local total = #self.listaArquivos.items

    if not abaRecarregar.verificarSegurancaReload(self, total) then
        abaRecarregar.definirStatus(self,
            getText("IGUI_LKS_Debug_WarningMassReload", tostring(total)) or ("AVISO: " .. tostring(total) .. " arquivos de multiplos mods! Recarregamento em massa pode causar crash."),
            "aviso")
        print("[LKS Debug Tool] Reload em massa bloqueado: " .. tostring(total) .. " arquivos de multiplos mods excede o limite seguro de " .. tostring(LIMITE_RELOAD_SEGURO) .. ".")
        return
    end

    local contador = 0
    local erros = {}

    for _, item in ipairs(self.listaArquivos.items) do
        local caminhoReload = item.item.caminho
        local sucesso, mensagemErro = pcall(reloadLuaFile, caminhoReload)
        if sucesso then
            contador = contador + 1
        else
            table.insert(erros, (item.text or "?") .. ": " .. tostring(mensagemErro))
            print("[LKS Debug Tool] ERRO reload: " .. tostring(caminhoReload) .. " -> " .. tostring(mensagemErro))
        end
    end

    if #erros > 0 then
        abaRecarregar.definirStatus(self, getText("IGUI_LKS_Debug_ReloadError", erros[1]) or ("Erro ao recarregar: " .. erros[1]), "erro")
    else
        abaRecarregar.definirStatus(self, getText("IGUI_LKS_Debug_ReloadedCount", tostring(contador), tostring(total)) or ("Recarregados " .. tostring(contador) .. " de " .. tostring(total) .. " arquivos."), "sucesso")
    end
end

--- Recarrega os arquivos marcados com checkbox na lista.
--- Exibe aviso de segurança quando a quantidade excede o limite seguro e multiplos mods estao ativos.
function abaRecarregar.recarregarMarcados(self, painel)
    if not self.listaArquivos then return end

    -- Conta marcados antes de recarregar
    local total = 0
    for _, item in ipairs(self.listaArquivos.items) do
        if item.item.marcado then
            total = total + 1
        end
    end

    if total == 0 then
        abaRecarregar.definirStatus(self, getText("IGUI_LKS_Debug_NoFilesSelected") or "Nenhum arquivo marcado. Clique nos arquivos para selecionar.", "aviso")
        return
    end

    if not abaRecarregar.verificarSegurancaReload(self, total) then
        abaRecarregar.definirStatus(self,
            getText("IGUI_LKS_Debug_WarningSelectedMassReload", tostring(total)) or ("AVISO: " .. tostring(total) .. " arquivos marcados de multiplos mods! Reduza a selecao."),
            "aviso")
        print("[LKS Debug Tool] Reload em massa bloqueado: " .. tostring(total) .. " arquivos de multiplos mods excede o limite seguro de " .. tostring(LIMITE_RELOAD_SEGURO) .. ".")
        return
    end

    local contador = 0
    local erros = {}

    for _, item in ipairs(self.listaArquivos.items) do
        if item.item.marcado then
            local caminhoReload = item.item.caminho
            local sucesso, mensagemErro = pcall(reloadLuaFile, caminhoReload)
            if sucesso then
                contador = contador + 1
            else
                table.insert(erros, (item.text or "?") .. ": " .. tostring(mensagemErro))
                print("[LKS Debug Tool] ERRO reload: " .. tostring(caminhoReload) .. " -> " .. tostring(mensagemErro))
            end
        end
    end

    if #erros > 0 then
        abaRecarregar.definirStatus(self, getText("IGUI_LKS_Debug_ReloadError", erros[1]) or ("Erro ao recarregar: " .. erros[1]), "erro")
    else
        abaRecarregar.definirStatus(self, getText("IGUI_LKS_Debug_ReloadedSelectedCount", tostring(contador), tostring(total)) or ("Recarregados " .. tostring(contador) .. " de " .. tostring(total) .. " arquivos marcados."), "sucesso")
    end
end

--- Atualiza o texto e a cor da barra de status no rodapé.
---
--- @param mensagem string Texto a exibir na barra de status.
--- @param tipoMensagem string Tipo visual: "sucesso" (verde), "erro" (vermelho), "aviso" (amarelo) ou nil (neutro).
function abaRecarregar.definirStatus(self, mensagem, tipoMensagem)
    if not self.rotuloStatus then return end

    self.rotuloStatus:setName(mensagem)

    if tipoMensagem == "sucesso" then
        self.rotuloStatus:setColor(0.3, 1.0, 0.4)
    elseif tipoMensagem == "erro" then
        self.rotuloStatus:setColor(1.0, 0.3, 0.3)
    elseif tipoMensagem == "aviso" then
        self.rotuloStatus:setColor(1.0, 0.85, 0.3)
    else
        local tema = LKS_DebugTool.tema
        self.rotuloStatus:setColor(tema.textoDetalhe.r, tema.textoDetalhe.g, tema.textoDetalhe.b)
    end

    print("[LKS Debug Tool] " .. mensagem)
end

function abaRecarregar.atualizar(self, painel)
    -- O filtro principal é tratado via callback onTextChange (event-driven).
    -- Este fallback cobre o caso do clear button (X) que limpa sem disparar onTextChange.
    if not self.entradaFiltro then return end

    local textoAtual = self.entradaFiltro:getText()
    if textoAtual == nil then textoAtual = "" end

    if textoAtual ~= self.filtroTexto then
        self.filtroTexto = textoAtual
        abaRecarregar.atualizarLista(self, painel)
    end
end

function abaRecarregar.destruir(self, painel)
    self.listaArquivos = nil
    self.entradaFiltro = nil
    self.rotuloStatus = nil
end

-- ============================================================================
-- ABA 2: MENU DE CONTEXTO (INSPETOR)
-- ============================================================================

local abaMenuContexto = {
    nome = getText("IGUI_LKS_Debug_TabContextMenu") or "Menu de Contexto",
    ultimoMenuCapturado = nil,
    ultimoMenuVanilla = nil,
    ultimosObjetos = nil,
}

function abaMenuContexto.criar(self, painel, posicaoY)
    local tema = LKS_DebugTool.tema
    local margemEsquerda = MARGEM * 2
    local larguraUtil = painel.width - margemEsquerda - MARGEM * 2
    local alturaRedimensionamento = painel:resizeWidgetHeight()

    -- Título
    local rotuloTitulo = ISLabel:new(margemEsquerda, posicaoY, 22, getText("IGUI_LKS_Debug_ContextMenuTitle") or "Inspetor de Menu de Contexto",
        tema.textoTitulo.r, tema.textoTitulo.g, tema.textoTitulo.b, tema.textoTitulo.a,
        UIFont.Medium, true)
    painel:adicionarWidgetAba(rotuloTitulo)
    posicaoY = posicaoY + 26 + ESPACO_VERTICAL

    -- Instrucao
    local rotuloInstrucao = ISLabel:new(margemEsquerda, posicaoY, 18,
        getText("IGUI_LKS_Debug_ContextMenuInstruction") or "Clique em objetos do mundo para capturar o menu.",
        tema.textoDetalhe.r, tema.textoDetalhe.g, tema.textoDetalhe.b, tema.textoDetalhe.a,
        UIFont.Small, true)
    painel:adicionarWidgetAba(rotuloInstrucao)
    posicaoY = posicaoY + 22 + ESPACO_VERTICAL

    -- Lista de captura (scrolling list)
    local alturaLista = painel.height - posicaoY - alturaRedimensionamento - MARGEM
    local listaCaptura = ISScrollingListBox:new(margemEsquerda, posicaoY, larguraUtil, alturaLista)
    listaCaptura.anchorRight = true
    listaCaptura.anchorBottom = true
    listaCaptura:initialise()
    listaCaptura:instantiate()
    listaCaptura.itemheight = 20
    listaCaptura.backgroundColor = tema.fundoInput
    listaCaptura.borderColor = tema.bordaInput
    listaCaptura.drawBorder = true
    listaCaptura.doDrawItem = abaMenuContexto.desenharItemLista
    painel:adicionarWidgetAba(listaCaptura)
    self.listaCaptura = listaCaptura

    -- Se já há dados capturados, exibe
    if self.ultimoMenuCapturado then
        abaMenuContexto.popularLista(self)
    end
end

--- Captura o menu de contexto final e tenta reconstruir o menu vanilla original.
---
--- @param menuContexto ISContextMenu O menu de contexto preenchido (com todos os mods).
--- @param objetosMundo table Os objetos clicados.
--- @param jogadorNumero number O indice do jogador.
function abaMenuContexto.capturarMenu(self, menuContexto, objetosMundo, jogadorNumero)
    self.ultimoMenuCapturado = menuContexto
    self.ultimosObjetos = objetosMundo
    self.ultimoMenuVanilla = nil

    abaMenuContexto.popularLista(self)
end

--- Popula a lista de captura com os dados do menu atual e as opcoes vanilla.
function abaMenuContexto.popularLista(self)
    if not self.listaCaptura or not self.ultimoMenuCapturado then return end

    self.listaCaptura:clear()
    local menu = self.ultimoMenuCapturado

    -- Secao: Menu Atual (com todos os mods ativos)
    self.listaCaptura:addItem(getText("IGUI_LKS_Debug_CurrentMenuSection") or "[ MENU ATUAL ]", { tipo = "secao" })

    if menu.options then
        abaMenuContexto.adicionarOpcoesNaLista(self, menu, 0, "")
    end

    -- Gambiarra para não cortar o ultimo item, eu não queria fazer isso mais o agente LLM claude opus 4.6 foi estupido e incapaz de resolver esse problema de forma elegante.
    self.listaCaptura:addItem(" ", { tipo = "espacador" })
end

--- Adiciona opcoes recursivamente na lista com indentacao.
function abaMenuContexto.adicionarOpcoesNaLista(self, menu, nivel, prefixo)
    if not menu or not menu.options then return end

    for indice, opcao in ipairs(menu.options) do
        local nome = opcao.name or (getText("IGUI_LKS_Debug_NoName") or "(sem nome)")
        local temSubmenu = opcao.subOption and opcao.subOption > 0
        local temIcone = opcao.iconTexture ~= nil
        local desabilitado = opcao.notAvailable == true

        local indentacao = string.rep("    ", nivel)
        local indicePrefixo = prefixo ~= "" and (prefixo .. "." .. indice) or tostring(indice)

        local texto = string.format("%s[%s] %s",
            indentacao, indicePrefixo, nome)

        self.listaCaptura:addItem(texto, {
            tipo = "opcao",
            nivel = nivel,
            temSubmenu = temSubmenu,
            desabilitado = desabilitado,
            temIcone = temIcone,
            texturaIcone = opcao.iconTexture,
            nome = nome,
        })

        -- Recursao em submenus
        if temSubmenu then
            local submenu = menu:getSubMenu(opcao.subOption)
            if submenu then
                abaMenuContexto.adicionarOpcoesNaLista(self, submenu, nivel + 1, indicePrefixo)
            end
        end
    end
end

--- Renderizador customizado para itens da lista de captura.
--- Renderiza icones quando disponveis e diferencia secoes e opcoes.
function abaMenuContexto.desenharItemLista(self, y, item, alt)
    local tema = LKS_DebugTool.tema
    local dados = item.item
    local alturaItem = self.itemheight

    if dados.tipo == "secao" then
        local larguraSecao = self:getWidth()
        local scrollbarVisivel = self.vscroll and self.vscroll:getIsVisible()
        if scrollbarVisivel then
            larguraSecao = larguraSecao - 17
        end
        self:drawRect(0, y, larguraSecao, alturaItem,
            0.10, tema.acento.r, tema.acento.g, tema.acento.b)
        local textoAltura = getTextManager():MeasureStringY(UIFont.Small, item.text)
        local textoY = y + math.floor((alturaItem - textoAltura) / 2)
        self:drawText(item.text, 8, textoY,
            tema.textoTitulo.r, tema.textoTitulo.g, tema.textoTitulo.b, 1.0, UIFont.Small)

    elseif dados.tipo == "espacador" then
        -- Invisivel, apenas ocupa espaco

    else
        -- Hover
        if self.mouseoverselected == item.index then
            local larguraHover = self:getWidth()
            local scrollbarVisivel = self.vscroll and self.vscroll:getIsVisible()
            if scrollbarVisivel then
                larguraHover = larguraHover - 17
            end
            self:drawRect(0, y, larguraHover, alturaItem, 0.08, 0.3, 0.5, 0.8)
        end

        local textoX = 8

        -- Renderiza icone do menu se disponivel
        if dados.temIcone and dados.texturaIcone then
            local tamanhoIcone = alturaItem - 4
            local iconeY = y + 2
            pcall(function()
                self:drawTextureScaled(dados.texturaIcone, textoX, iconeY, tamanhoIcone, tamanhoIcone, 1.0)
            end)
            textoX = textoX + tamanhoIcone + 4
        end

        local corTexto = tema.textoNormal
        if dados.desabilitado then
            corTexto = tema.textoDetalhe
        elseif dados.temSubmenu then
            corTexto = tema.acento
        end

        -- Margem dinamica baseada na visibilidade do scrollbar
        local margemBase = 8
        local scrollbarVisivel = self.vscroll and self.vscroll:getIsVisible()
        local margemScrollbar = scrollbarVisivel and 17 or 0
        local margemDireita = margemBase + margemScrollbar

        -- Calcula espaco disponivel para o texto principal
        local larguraDisponivel = self:getWidth() - textoX - margemDireita
        local textoRenderizado = item.text
        local larguraTexto = getTextManager():MeasureStringX(UIFont.Small, textoRenderizado)

        if larguraTexto > larguraDisponivel and #textoRenderizado > 6 then
            while getTextManager():MeasureStringX(UIFont.Small, textoRenderizado .. "...") > larguraDisponivel and #textoRenderizado > 3 do
                textoRenderizado = string.sub(textoRenderizado, 1, #textoRenderizado - 1)
            end
            textoRenderizado = textoRenderizado .. "..."
        end

        local textoAltura = getTextManager():MeasureStringY(UIFont.Small, textoRenderizado)
        local textoY = y + math.floor((alturaItem - textoAltura) / 2)
        self:drawText(textoRenderizado, textoX, textoY, corTexto.r, corTexto.g, corTexto.b, corTexto.a, UIFont.Small)
    end

    return y + alturaItem
end

function abaMenuContexto.destruir(self, painel)
    self.listaCaptura = nil
end

-- ============================================================================
-- ABA 3: INSPETOR DE OBJETO
-- ============================================================================

local abaInspetorObjeto = {
    nome = getText("IGUI_LKS_Debug_TabObjectInspector") or "Inspetor de Objeto",
    ultimoObjeto = nil,
    propriedadesCapturadas = {},
}

function abaInspetorObjeto.criar(self, painel, posicaoY)
    local tema = LKS_DebugTool.tema
    local margemEsquerda = MARGEM * 2
    local larguraUtil = painel.width - margemEsquerda - MARGEM * 2
    local alturaRedimensionamento = painel:resizeWidgetHeight()

    -- Título
    local rotuloTitulo = ISLabel:new(margemEsquerda, posicaoY, 22, getText("IGUI_LKS_Debug_ObjectInspectorTitle") or "Inspetor de Propriedades do Objeto",
        tema.textoTitulo.r, tema.textoTitulo.g, tema.textoTitulo.b, tema.textoTitulo.a,
        UIFont.Medium, true)
    painel:adicionarWidgetAba(rotuloTitulo)
    posicaoY = posicaoY + 26 + ESPACO_VERTICAL

    -- Instrucao
    local rotuloInstrucao = ISLabel:new(margemEsquerda, posicaoY, 18,
        getText("IGUI_LKS_Debug_ObjectInspectorInstruction") or "Clique em um objeto para inspecionar.",
        tema.textoDetalhe.r, tema.textoDetalhe.g, tema.textoDetalhe.b, tema.textoDetalhe.a,
        UIFont.Small, true)
    painel:adicionarWidgetAba(rotuloInstrucao)
    posicaoY = posicaoY + 22 + ESPACO_VERTICAL

    -- Lista de propriedades
    local alturaLista = painel.height - posicaoY - alturaRedimensionamento - MARGEM
    local listaPropriedades = ISScrollingListBox:new(margemEsquerda, posicaoY, larguraUtil, alturaLista)
    listaPropriedades.anchorRight = true
    listaPropriedades.anchorBottom = true
    listaPropriedades:initialise()
    listaPropriedades:instantiate()
    listaPropriedades.itemheight = 20
    listaPropriedades.backgroundColor = tema.fundoInput
    listaPropriedades.borderColor = tema.bordaInput
    listaPropriedades.drawBorder = true
    listaPropriedades.doDrawItem = abaInspetorObjeto.desenharItemLista
    painel:adicionarWidgetAba(listaPropriedades)
    self.listaPropriedades = listaPropriedades

    -- Se já há dados capturados, exibe
    if self.ultimoObjeto then
        abaInspetorObjeto.popularLista(self)
    end
end

--- Captura as propriedades de um objeto do mundo e organiza por seção.
---
--- @param objeto IsoObject O objeto do mundo a inspecionar.
function abaInspetorObjeto.capturarObjeto(self, objeto)
    if not objeto then return end
    self.ultimoObjeto = objeto
    self.propriedadesCapturadas = {}

    -- SEÇÃO: Identidade
    local identidade = {}
    local classeJava = "?"
    if objeto.getClass then
        local ok, val = pcall(function() return tostring(objeto:getClass():getSimpleName()) end)
        if ok then classeJava = val end
    end
    table.insert(identidade, { chave = getText("IGUI_LKS_Debug_JavaClass") or "Classe Java", valor = classeJava })

    local spriteName = "?"
    if objeto.getSprite and objeto:getSprite() then
        local ok, val = pcall(function() return objeto:getSprite():getName() end)
        if ok and val then spriteName = val end
    end
    table.insert(identidade, { chave = getText("IGUI_LKS_Debug_Sprite") or "Sprite", valor = spriteName })

    if objeto.getSquare and objeto:getSquare() then
        local quadrado = objeto:getSquare()
        local coordenadas = string.format("x:%d  y:%d  z:%d", quadrado:getX(), quadrado:getY(), quadrado:getZ())
        table.insert(identidade, { chave = getText("IGUI_LKS_Debug_Coordinates") or "Coordenadas", valor = coordenadas })
    end

    if objeto.getName then
        local ok, nome = pcall(function() return objeto:getName() end)
        if ok and nome then
            table.insert(identidade, { chave = getText("IGUI_LKS_Debug_Name") or "Nome", valor = nome })
        end
    end

    table.insert(self.propriedadesCapturadas, { secao = getText("IGUI_LKS_Debug_SectionIdentity") or "[ID] Identidade", itens = identidade })

    -- SEÇÃO: Propriedades do Sprite (PropertyContainer)
    local propriedades = {}
    if objeto.getProperties then
        local ok, props = pcall(function() return objeto:getProperties() end)
        if ok and props then
            local propList = props:getPropertyNames()
            if propList then
                for i = 0, propList:size() - 1 do
                    local chave = propList:get(i)
                    local valor = props:get(chave) or ""
                    table.insert(propriedades, { chave = chave, valor = valor })
                end
            end
        end
    end

    if #propriedades > 0 then
        table.sort(propriedades, function(a, b) return a.chave < b.chave end)
        table.insert(self.propriedadesCapturadas, { secao = getText("IGUI_LKS_Debug_SectionSpriteProps") or "[SPR] Propriedades do Sprite", itens = propriedades })
    end

    -- SEÇÃO: Container
    local containerInfo = {}
    if objeto.getContainer then
        local ok, container = pcall(function() return objeto:getContainer() end)
        if ok and container then
            table.insert(containerInfo, { chave = getText("IGUI_LKS_Debug_Type") or "Tipo", valor = container:getType() or "?" })
            table.insert(containerInfo, { chave = getText("IGUI_LKS_Debug_Capacity") or "Capacidade", valor = tostring(container:getCapacity()) })
            table.insert(containerInfo, { chave = getText("IGUI_LKS_Debug_Powered") or "Energizado", valor = tostring(container:isPowered()) })

            local ok2, itens = pcall(function() return container:getItems() end)
            if ok2 and itens then
                table.insert(containerInfo, { chave = getText("IGUI_LKS_Debug_ItemsInside") or "Itens Dentro", valor = tostring(itens:size()) })
            end
        end
    end

    if #containerInfo > 0 then
        table.insert(self.propriedadesCapturadas, { secao = getText("IGUI_LKS_Debug_SectionContainer") or "[CTN] Container", itens = containerInfo })
    end

    -- SEÇÃO: Flags
    local flags = {}
    if objeto.getSprite and objeto:getSprite() then
        local sprite = objeto:getSprite()
        if sprite.getProperties then
            local ok, spriteProps = pcall(function() return sprite:getProperties() end)
            if ok and spriteProps then
                local flagList = spriteProps:getFlagsList()
                if flagList then
                    for i = 0, flagList:size() - 1 do
                        table.insert(flags, { chave = flagList:get(i):toString(), valor = getText("IGUI_LKS_Debug_FlagCheck") or "X" })
                    end
                end
            end
        end
    end

    if #flags > 0 then
        table.insert(self.propriedadesCapturadas, { secao = getText("IGUI_LKS_Debug_SectionFlags") or "[FLG] Flags", itens = flags })
    end

    -- SEÇÃO: Estado (se aplicável)
    local estado = {}
    if objeto.isActivated then
        local ok, val = pcall(function() return objeto:isActivated() end)
        if ok then table.insert(estado, { chave = getText("IGUI_LKS_Debug_Activated") or "Ativado", valor = tostring(val) }) end
    end
    if objeto.getCurrentTemperature then
        local ok, val = pcall(function() return objeto:getCurrentTemperature() end)
        if ok then table.insert(estado, { chave = getText("IGUI_LKS_Debug_Temperature") or "Temperatura", valor = getText("IGUI_LKS_Debug_TempValue", string.format("%.1f", val)) or (string.format("%.1f", val) .. " C") }) end
    end
    if objeto.getCondition then
        local ok, val = pcall(function() return objeto:getCondition() end)
        if ok then table.insert(estado, { chave = getText("IGUI_LKS_Debug_Condition") or "Condição", valor = tostring(val) }) end
    end

    if #estado > 0 then
        table.insert(self.propriedadesCapturadas, { secao = getText("IGUI_LKS_Debug_SectionState") or "[EST] Estado", itens = estado })
    end

    abaInspetorObjeto.popularLista(self)
end

--- Popula a lista visual com os dados capturados organizados por seção.
function abaInspetorObjeto.popularLista(self)
    if not self.listaPropriedades then return end
    self.listaPropriedades:clear()

    local secaoAtual = nil

    for _, secao in ipairs(self.propriedadesCapturadas) do
        secaoAtual = secao.secao

        -- Cabeçalho de seção (sem tooltip)
        self.listaPropriedades:addItem(secao.secao, { tipo = "secao" })

        -- Itens da seção com tooltip via terceiro argumento nativo
        for _, item in ipairs(secao.itens) do
            local texto = "  " .. item.chave .. " = " .. item.valor
            local tooltipTexto = LKS_DebugTooltipData.buscarTooltip(item.chave, secaoAtual)
            self.listaPropriedades:addItem(texto, { tipo = "propriedade", chave = item.chave, valor = item.valor }, tooltipTexto)
        end
    end

    -- Gambiarra para não cortar o ultimo item, eu não queria fazer isso mais o agente LLM claude opus 4.6 foi estupido e incapaz de resolver esse problema de forma elegante.
    self.listaPropriedades:addItem(" ", { tipo = "espacador" })
end

--- Renderizador customizado para itens de propriedade.
function abaInspetorObjeto.desenharItemLista(self, y, item, alt)
    local tema = LKS_DebugTool.tema
    local dados = item.item
    local alturaItem = self.itemheight

    if dados.tipo == "secao" then
        -- Fundo de seção com acento (alinhado com hover)
        local larguraSecao = self:getWidth()
        local scrollbarVisivel = self.vscroll and self.vscroll:getIsVisible()
        if scrollbarVisivel then
            larguraSecao = larguraSecao - 17
        end
        self:drawRect(0, y, larguraSecao, alturaItem, 0.12, tema.acento.r, tema.acento.g, tema.acento.b)
        local textoAltura = getTextManager():MeasureStringY(UIFont.Small, item.text)
        local textoY = y + math.floor((alturaItem - textoAltura) / 2)
        self:drawText(item.text, 8, textoY, tema.textoTitulo.r, tema.textoTitulo.g, tema.textoTitulo.b, 1.0, UIFont.Small)
    elseif dados.tipo == "espacador" then
        -- Invisivel, apenas ocupa espaco
    else
        -- Hover
        if self.mouseoverselected == item.index then
            local larguraHover = self:getWidth()
            local scrollbarVisivel = self.vscroll and self.vscroll:getIsVisible()
            if scrollbarVisivel then
                larguraHover = larguraHover - 17
            end
            self:drawRect(0, y, larguraHover, alturaItem, 0.05, 0.3, 0.5, 0.8)
        end

        -- Renderiza chave em cor de acento e valor em cor normal
        local margemBase = 8
        local scrollbarVisivel = self.vscroll and self.vscroll:getIsVisible()
        local margemScrollbar = scrollbarVisivel and 17 or 0
        local margemDireita = margemBase + margemScrollbar
        local larguraDisponivel = self:getWidth() - 8 - margemDireita
        local textoChave = "  " .. (dados.chave or "")
        local textoValor = " = " .. (dados.valor or "")
        local larguraChave = getTextManager():MeasureStringX(UIFont.Small, textoChave)
        local larguraValor = getTextManager():MeasureStringX(UIFont.Small, textoValor)

        -- Trunca o valor se exceder a area visivel
        if larguraChave + larguraValor > larguraDisponivel and #textoValor > 6 then
            local valorOriginal = dados.valor or ""
            while larguraChave + getTextManager():MeasureStringX(UIFont.Small, " = " .. valorOriginal .. "...") > larguraDisponivel and #valorOriginal > 3 do
                valorOriginal = string.sub(valorOriginal, 1, #valorOriginal - 1)
            end
            textoValor = " = " .. valorOriginal .. "..."
        end

        local textoAltura = getTextManager():MeasureStringY(UIFont.Small, textoChave)
        local textoY = y + math.floor((alturaItem - textoAltura) / 2)
        self:drawText(textoChave, 8, textoY, tema.acento.r, tema.acento.g, tema.acento.b, 0.9, UIFont.Small)
        self:drawText(textoValor, 8 + larguraChave, textoY,
            tema.textoNormal.r, tema.textoNormal.g, tema.textoNormal.b, tema.textoNormal.a, UIFont.Small)
    end

    return y + alturaItem
end

function abaInspetorObjeto.destruir(self, painel)
    self.listaPropriedades = nil
end

-- ============================================================================
-- HANDLER DE CAPTURA (OnFillWorldObjectContextMenu)
-- ============================================================================
-- Este handler captura dados dos cliques no mundo para alimentar as abas
-- "Menu Contexto" e "Inspetor de Objeto" em tempo real.
-- ============================================================================

local function aoPreencherMenuContextoMundo(jogadorNumero, menuContexto, objetosMundo, apenasTeste)
    if apenasTeste then return end
    if not LKS_DebugTool.instance then return end

    -- Captura para a aba de Menu de Contexto (passa jogadorNumero para reconstruir vanilla)
    pcall(function()
        abaMenuContexto:capturarMenu(menuContexto, objetosMundo, jogadorNumero)
    end)

    -- Captura para a aba de Inspetor de Objeto (primeiro objeto relevante)
    pcall(function()
        if objetosMundo and #objetosMundo > 0 then
            abaInspetorObjeto:capturarObjeto(objetosMundo[1])
        end
    end)
end

-- ============================================================================
-- REGISTRO DAS ABAS E EVENTOS
-- ============================================================================

LKS_DebugTool.registrarAba(abaRecarregar)
LKS_DebugTool.registrarAba(abaMenuContexto)
LKS_DebugTool.registrarAba(abaInspetorObjeto)

-- Handler de captura de menus
Events.OnFillWorldObjectContextMenu.Add(aoPreencherMenuContextoMundo)

-- Atalho F12 para toggle
local function aoTeclaPressionada(tecla)
    if tecla == Keyboard.KEY_F12 then
        LKS_DebugTool.toggle()
    end
end

Events.OnKeyPressed.Add(aoTeclaPressionada)

print("[LKS PATCH - LKS_Debug_Tool.lua] Ferramenta de desenvolvimento carregada (F12 para abrir).")
