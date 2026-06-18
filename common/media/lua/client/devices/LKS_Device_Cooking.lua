-- ============================================================================
-- ARQUIVO: LKS_Device_Cooking.lua
-- EXTENSÃO: LKS SuperMod Patch (Módulo de Comportamento de Culinária)
-- OBJETIVO: Driver de comportamento e texturas para fogões (Stoves) e
--           micro-ondas (Microwaves) no gerenciador LKS_ApplianceManager.
--           Suporta 3 tipos de fogão: Convencional (gás), Antigo (lenha)
--           e Indução (eletricidade). A classificação é feita por sprite
--           via LKS_Cooking_SpriteClassification.
-- AUTOR: LKS FERREIRA
-- VERSÃO: 2.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 18/06/2026
-- ============================================================================

-- Inicialização defensiva do gerenciador para robustez de carregamento
LKS_ApplianceManager = LKS_ApplianceManager or {}
LKS_ApplianceManager.devices = LKS_ApplianceManager.devices or {}
LKS_ApplianceManager.containerTypeMap = LKS_ApplianceManager.containerTypeMap or {}
LKS_ApplianceManager.javaClassMap = LKS_ApplianceManager.javaClassMap or {}

if LKS_ApplianceManager.recursoAtivo and not LKS_ApplianceManager.recursoAtivo("CookingEnabled", true) then
    print("[LKS PATCH - LKS_Device_Cooking.lua] Culinária desativada no sandbox.")
    return
end

local ClassificacaoSprites = require("LKS_Cooking_SpriteClassification")
local SistemaGas = require("LKS_Cooking_GasSystem")

local LKS_Device_Cooking = {
    recipientesAceitos = {"stove", "microwave", "woodstove", "fireplace"},
    classesJava = {"IsoStove", "IsoMicrowave", "IsoFireplace"},
    brilhoInativo = "escurece25"
}

local LKS_ConfiguracaoIconesCulinaria = {
    stove = {
        energizado    = nil,
    },
    microwave = {
        energizado    = nil,
    },
}

--- Retorna a textura correspondente baseada nos estados de energia e tipo de contêiner.
---
--- @param chaveConfiguracao string O tipo de aparelho ("stove", "microwave").
--- @param temEnergia boolean Se o aparelho possui fornecimento elétrico ativo.
--- @return Texture O objeto de textura carregado do jogo.
local function obterTexturaEstado(chaveConfiguracao, temEnergia)
    local configuracaoIcone = LKS_ConfiguracaoIconesCulinaria[chaveConfiguracao]
    if not configuracaoIcone then return nil end

    if configuracaoIcone.energizado then
        return getTexture(configuracaoIcone.energizado)
    else
        return ContainerButtonIcons[chaveConfiguracao]
    end
end

--- Verifica se há objetos metálicos no interior do contêiner do micro-ondas.
---
--- @param containerInventario ItemContainer O contêiner de itens a inspecionar.
--- @return boolean contemMetal Retorna true se houver pelo menos um item metálico.
local function verificarPresencaMetal(containerInventario)
    if not containerInventario then return false end
    local itens = containerInventario:getItems()
    if not itens then return false end

    for indice = 0, itens:size() - 1 do
        local item = itens:get(indice)
        if item then
            -- Valida tags e propriedades de metal comuns do jogo base
            if item:isMetal() or (item:getMetalValue() and item:getMetalValue() > 0) then
                return true
            end
            -- Fallback para tipos conhecidos de latas e objetos metálicos
            local tipoItem = item:getType()
            if tipoItem == "TinCan" or tipoItem == "CannedSoup" or tipoItem == "CannedBeans" or tipoItem == "CannedPeaches" then
                return true
            end
        end
    end
    return false
end

--- Retorna a textura para a Loot Window baseada no estado de energia do recipiente.
---
--- @param recipiente ItemContainer O contêiner sendo desenhado.
--- @param recipienteTipo string O tipo do contêiner.
--- @param objetoPai IsoObject O objeto pai no mundo.
--- @param temEnergia boolean Se o contêiner possui energia elétrica ativa.
--- @return Texture A textura resolvida para o inventário.
function LKS_Device_Cooking.obterTexturaInventario(recipiente, recipienteTipo, objetoPai, temEnergia)
    local chaveConfiguracao = nil
    if recipienteTipo == "stove" then
        chaveConfiguracao = "stove"
    elseif recipienteTipo == "microwave" then
        chaveConfiguracao = "microwave"
    end

    if not chaveConfiguracao then return nil end
    return obterTexturaEstado(chaveConfiguracao, temEnergia)
end

--- Constrói o submenu LKS para fogões e micro-ondas no mundo.
---
--- ## Como funciona o menu de contexto no Project Zomboid (ISContextMenu):
---
--- O jogo dispara o evento `OnFillWorldObjectContextMenu` para cada clique-direito
--- no mundo. Múltiplos handlers (vanilla + mods) adicionam opções ao mesmo `menuContexto`.
--- Para aparelhos como fogões e micro-ondas, o vanilla JÁ cria um submenu agrupador
--- com o nome traduzido do objeto (ex: "Fogão Vermelho"), e dentro dele coloca as
--- opções "Ligar/Desligar" e "Configurações" (timer, temperatura, potência).
---
--- ### Anatomia de uma opção (`menuContexto.options[i]`):
--- - `.name`         → Texto exibido (string traduzida via getText)
--- - `.onSelect`     → Callback executado ao clicar
--- - `.target`       → Primeiro argumento passado ao callback
--- - `.param1/.param2` → Argumentos adicionais do callback
--- - `.iconTexture`  → Textura exibida à esquerda da opção
--- - `.toolTip`      → Tooltip ISToolTip exibido ao passar o mouse
--- - `.notAvailable` → Se true, a opção fica cinza/desabilitada
--- - `.subOption`    → ID do submenu vinculado (via `addSubMenu`)
---
--- ### Operações principais da API ISContextMenu:
--- - `menuContexto:addOption(texto, alvo, callback, param1, param2)` → Adiciona opção
--- - `menuContexto:addOptionOnTop(texto)` → Adiciona no topo (prioridade visual)
--- - `ISContextMenu:getNew(menuPai)` → Cria submenu vinculado ao menu pai
--- - `menuContexto:addSubMenu(opcaoPai, submenu)` → Vincula submenu a uma opção
--- - `menuContexto:removeOptionByName(texto)` → Remove opção por nome exato
--- - `menuContexto:getSubMenu(idSubmenu)` → Obtém referência ao submenu de uma opção
---
--- ### Estratégia de sequestro do submenu vanilla:
--- Em vez de criar um SEGUNDO submenu com o mesmo nome (causando duplicata),
--- a abordagem correta é:
--- 1. LOCALIZAR a opção vanilla existente pelo nome do objeto traduzido
--- 2. OBTER o submenu vanilla já criado via `.subOption`
--- 3. REMOVER apenas as opções que queremos substituir (Ligar/Desligar)
--- 4. INJETAR nossas opções aprimoradas no submenu existente
--- 5. PRESERVAR tudo que não tocamos (Configurações e qualquer outra)
---
--- @param jogadorNumero number O índice do jogador local (0 a 3).
--- @param menuContexto ISContextMenu O menu de contexto sendo preenchido.
--- @param objetosMundo table A lista de objetos físicos clicados no mundo.
--- @param objetoEletrico IsoObject O objeto elétrico clicado.
function LKS_Device_Cooking.construirMenuContexto(jogadorNumero, menuContexto, objetosMundo, objetoEletrico)
    local ehFogao = instanceof(objetoEletrico, "IsoStove")
    local ehMicroondas = instanceof(objetoEletrico, "IsoMicrowave")

    local chaveConfiguracao = nil
    if ehFogao then
        chaveConfiguracao = "stove"
    elseif ehMicroondas then
        chaveConfiguracao = "microwave"
    end

    -- Resolução do nome traduzido do aparelho via propriedades do sprite
    local nomeObjetoTraduzido = ""
    if ehFogao then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Fogão"
    elseif ehMicroondas then
        nomeObjetoTraduzido = objetoEletrico:getName() or "Micro-ondas"
    end

    local propriedadesObjeto = objetoEletrico:getProperties()
    if propriedadesObjeto then
        local nomeGrupo = propriedadesObjeto:has("GroupName") and propriedadesObjeto:get("GroupName") or nil
        local nomeCustomizado = propriedadesObjeto:has("CustomName") and propriedadesObjeto:get("CustomName") or nil
        if nomeGrupo and nomeCustomizado then
            nomeObjetoTraduzido = Translator.getMoveableDisplayName(nomeGrupo .. " " .. nomeCustomizado)
        elseif nomeCustomizado then
            nomeObjetoTraduzido = Translator.getMoveableDisplayName(nomeCustomizado)
        end
    end

    -- Identifica o tipo de fogão por sprite (convencional, inducao ou antigo)
    local tipoFogao = nil
    if ehFogao then
        tipoFogao = ClassificacaoSprites.obterTipoFogao(objetoEletrico)
    end

    -- Detecta fonte de energia usando o sistema unificado
    local jogador = getSpecificPlayer(jogadorNumero)
    local fonteEnergia = nil
    local temEnergia = false
    local containerInventario = objetoEletrico:getContainer()

    if ehFogao and tipoFogao then
        fonteEnergia = SistemaGas.verificarFonteEnergia(objetoEletrico, jogador, tipoFogao)
        temEnergia = fonteEnergia.disponivel
    else
        -- Micro-ondas: mantém lógica original (só eletricidade)
        if containerInventario and containerInventario:isPowered() then
            temEnergia = true
        end
    end

    local texturaIconeMenu = obterTexturaEstado(chaveConfiguracao, temEnergia)
    local estaAtivo = false
    if objetoEletrico.isActivated then
        estaAtivo = objetoEletrico:isActivated()
    elseif objetoEletrico.Activated then
        estaAtivo = objetoEletrico:Activated()
    end

    -- =========================================================================
    -- PASSO 1: LOCALIZAR O SUBMENU VANILLA EXISTENTE
    -- =========================================================================
    -- O jogo base já cria uma opção-pai com o nome do aparelho (ex: "Fogão Vermelho")
    -- e vincula um submenu a ela contendo "Ligar" e "Configurações".
    -- Precisamos ENCONTRAR essa opção existente para sequestrar seu submenu,
    -- em vez de criar um duplicado.
    --
    -- A busca é feita por nome exato (`opcao.name == nomeObjetoTraduzido`) e
    -- verificando se a opção possui um submenu vinculado (`.subOption` preenchido).
    -- =========================================================================
    local opcaoVanillaEncontrada = nil
    local submenuVanilla = nil

    for _, opcao in ipairs(menuContexto.options) do
        if opcao.name == nomeObjetoTraduzido and opcao.subOption then
            opcaoVanillaEncontrada = opcao
            submenuVanilla = menuContexto:getSubMenu(opcao.subOption)
            break
        end
    end

    -- =========================================================================
    -- PASSO 2: DECIDIR SE SEQUESTRA O VANILLA OU CRIA UM NOVO
    -- =========================================================================
    -- Se o vanilla já criou o submenu, reutilizamos ele.
    -- Se não (caso de mods que alteram a ordem ou fogões sem submenu vanilla),
    -- criamos o nosso normalmente como fallback.
    -- =========================================================================
    local submenu = nil
    local opcaoMenuPai = nil

    if submenuVanilla then
        -- Sequestro: reutiliza o submenu vanilla existente
        submenu = submenuVanilla
        opcaoMenuPai = opcaoVanillaEncontrada

        -- Aplica ícone LKS na opção-pai vanilla
        if texturaIconeMenu then
            opcaoMenuPai.iconTexture = texturaIconeMenu
        end
    else
        -- Fallback: cria submenu próprio (caso o vanilla não tenha criado um)
        opcaoMenuPai = menuContexto:addOptionOnTop(nomeObjetoTraduzido)
        submenu = ISContextMenu:getNew(menuContexto)
        menuContexto:addSubMenu(opcaoMenuPai, submenu)

        if texturaIconeMenu then
            opcaoMenuPai.iconTexture = texturaIconeMenu
        end
    end

    -- =========================================================================
    -- PASSO 3: REMOVER OPÇÃO VANILLA DE LIGAR/DESLIGAR DO SUBMENU
    -- =========================================================================
    -- Remove apenas a opção de toggle do submenu vanilla (que substituiremos
    -- pela nossa versão aprimorada com tooltips). A opção "Configurações" e
    -- qualquer outra permanecem intactas.
    --
    -- Usamos `removeOptionByName` que é o método nativo do ISContextMenu para
    -- remoção segura por nome exato — sem necessidade de manipulação manual
    -- de índices da tabela `options`.
    -- =========================================================================
    local textoLigarVanilla = getText("ContextMenu_TurnOn")
    local textoDesligarVanilla = getText("ContextMenu_TurnOff")

    if submenu and submenu.removeOptionByName then
        pcall(function() submenu:removeOptionByName(textoLigarVanilla) end)
        pcall(function() submenu:removeOptionByName(textoDesligarVanilla) end)
    end

    -- =========================================================================
    -- PASSO 4: INJETAR NOSSAS OPÇÕES APRIMORADAS NO SUBMENU
    -- =========================================================================
    -- Adicionamos nossa versão de Ligar/Desligar com:
    -- - Ícones customizados (LKS_Button_Power_On/Off)
    -- - Tooltips com temperatura atual em °C (fogão)
    -- - Alertas de segurança coloridos (equipamento aquecido, metal no micro-ondas)
    -- - Estado desabilitado visual quando não há energia
    --
    -- Estas opções são inseridas NO TOPO do submenu via `addOptionOnTop` para
    -- que apareçam antes de "Configurações" (hierarquia: energia > ajustes).
    -- =========================================================================
    local chaveTextoLigar = getText("ContextMenu_TurnOn") or "Ligar"
    local chaveTextoDesligar = getText("ContextMenu_TurnOff") or "Desligar"

    if estaAtivo then
        local opcaoDesligar = submenu:addOptionOnTop(chaveTextoDesligar, objetosMundo, function()
            if ehFogao then
                ISWorldObjectContextMenu.onToggleStove(objetosMundo, objetoEletrico, jogadorNumero)
            elseif ehMicroondas then
                ISWorldObjectContextMenu.onToggleMicrowave(objetosMundo, objetoEletrico, jogadorNumero)
            end
        end)
        opcaoDesligar.iconTexture = getTexture("media/ui/LKS_Button_Power_Off.png")

        if ehFogao then
            local tooltipInfo = ISWorldObjectContextMenu.addToolTip()
            tooltipInfo:setName(nomeObjetoTraduzido)
            local temperaturaAtual = objetoEletrico:getCurrentTemperature()
            local textoTemperatura = string.format(getText("IGUI_LKS_TemperaturaAtual") or "Temperatura Atual: %.1f°C", temperaturaAtual)
            local textoAlerta = " <RGB:1,0,0> " .. (getText("IGUI_LKS_AlertaEquipamentoAquecido") or "⚠️ CUIDADO: Equipamento aquecido! Risco de incêndio se deixado sem supervisão.")
            tooltipInfo.description = textoTemperatura .. "\n" .. textoAlerta
            opcaoDesligar.toolTip = tooltipInfo
        end
    else
        if temEnergia then
            local opcaoLigar = submenu:addOptionOnTop(chaveTextoLigar, objetosMundo, function()
                if ehFogao then
                    ISWorldObjectContextMenu.onToggleStove(objetosMundo, objetoEletrico, jogadorNumero)
                elseif ehMicroondas then
                    ISWorldObjectContextMenu.onToggleMicrowave(objetosMundo, objetoEletrico, jogadorNumero)
                end
            end)
            opcaoLigar.iconTexture = getTexture("media/ui/LKS_Button_Power_On.png")

            if ehMicroondas and verificarPresencaMetal(containerInventario) then
                local tooltipAviso = ISWorldObjectContextMenu.addToolTip()
                tooltipAviso:setName(nomeObjetoTraduzido)
                tooltipAviso.description = " <RGB:1,1,0> " .. (getText("IGUI_LKS_AvisoMetalMicroondas") or "⚠️ AVISO: Contém objetos metálicos no interior! Risco de faíscas e incêndio.")
                opcaoLigar.toolTip = tooltipAviso
            end
        else
            -- Opção desabilitada: mostra visualmente que falta energia/gás/fonte de calor
            local opcaoLigarSemRequisitos = submenu:addOptionOnTop(chaveTextoLigar, objetosMundo, nil)
            opcaoLigarSemRequisitos.notAvailable = true
            opcaoLigarSemRequisitos.iconTexture = getTexture("media/ui/LKS_Menu_Electricity_Off.png")

            local tooltipErro = ISWorldObjectContextMenu.addToolTip()
            tooltipErro:setName(nomeObjetoTraduzido)

            if fonteEnergia and fonteEnergia.requerIgnicaoManual and not fonteEnergia.temIgnicaoManual then
                tooltipErro.description = getText("IGUI_LKS_RequerFonteCalor") or "Requer uma fonte de calor (isqueiro, fósforos, etc.) para acender."
            elseif tipoFogao == "convencional" then
                tooltipErro.description = getText("IGUI_LKS_RequerGasOuEletricidade") or "Requer gás encanado, botijão de gás conectado ou eletricidade."
            elseif tipoFogao == "inducao" then
                tooltipErro.description = getText("IGUI_LKS_RequerEletricidade") or "Requer uma fonte de eletricidade (rede ou gerador)."
            else
                tooltipErro.description = getText("IGUI_LKS_RequerEnergiaProxima") or "Requer uma fonte de energia próxima."
            end

            opcaoLigarSemRequisitos.toolTip = tooltipErro
        end
    end

    -- ============================================================================
    -- TODO: 💥 MECÂNICA AVANÇADA DE FÍSICA DE METAL NO MICRO-ONDAS
    -- Desenvolver nas próximas etapas os seguintes comportamentos para o micro-ondas:
    -- 1. Detecção de funcionamento ativo com metais no interior.
    -- 2. Após 2 segundos ligado, iniciar efeitos visuais/sonoros de faíscas ("pipocos" e "estalos").
    -- 3. Atingir o ápice de faíscas aos 5 segundos de funcionamento.
    -- 4. Consequências físicas aplicadas ao final do ciclo ou interrupção:
    --    - Redução progressiva de integridade do micro-ondas (25% de dano por ciclo).
    --    - Estragar qualquer tipo de comida no interior.
    --    - Danificar e quebrar utensílios não-preparados (ex: rádios de pilha, eletrônicos).
    -- 5. Sistema de filtragem fina de contêiner para permitir itens plausíveis
    --    (como roupas, calçados, tecidos) e rejeitar itens impossíveis (pneus, cadeiras).
    -- ============================================================================
end

-- Registro dinâmico no Appliance Manager
table.insert(LKS_ApplianceManager.devices, LKS_Device_Cooking)
for _, tipo in ipairs(LKS_Device_Cooking.recipientesAceitos) do
    LKS_ApplianceManager.containerTypeMap[tipo] = LKS_Device_Cooking
end
for _, classe in ipairs(LKS_Device_Cooking.classesJava) do
    LKS_ApplianceManager.javaClassMap[classe] = LKS_Device_Cooking
end

print("[LKS PATCH - LKS_Device_Cooking.lua] Carregado com sucesso!")
