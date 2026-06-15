-- ============================================================================
-- 🌟 LKS SUPERMOD PATCH — CRÉDITOS & AGRADECIMENTOS 🌟
-- ============================================================================
-- 💖 Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- 🛠️ Mod Original: Generator Powered Buildings (ID Workshop: 3597471949)
-- 👤 Autor Original: Beathoven
-- 🌐 Link: https://steamcommunity.com/sharedfiles/filedetails/?id=3597471949
-- 
-- Este mod só é possível graças a todos os modders que vieram antes de mim.
-- Um agradecimento especial ao autor por sua contribuição incrível à comunidade!
-- ============================================================================

-- ARQUIVO: LKS_EletricidadeConstrucao_ClientInit.lua
-- OBJETIVO: Inicialização do lado do cliente (carrega interfaces, menus e utilitários).
-- LOCALIZAÇÃO: client

print("[LKS PATCH - LKS_EletricidadeConstrucao_ClientInit.lua] Carregando Inicialização de Cliente do LKS_EletricidadeConstrucao...")

if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_ClientInit] Namespace LKS_EletricidadeConstrucao não encontrado - pulando carregamento do módulo")
    return
end

if LKS_EletricidadeConstrucao.Config and not LKS_EletricidadeConstrucao.Config.ModEnabled then
    print("[LKS_EletricidadeConstrucao_ClientInit] Eletricidade realista desativada no sandbox - pulando módulo")
    return
end

-- Registra o módulo de inicialização do cliente no namespace
LKS_EletricidadeConstrucao.RegisterModule("LKS_EletricidadeConstrucao_ClientInit")

-- ============================================================================
-- CARREGAMENTO DOS MENUS DE CONTEXTO
-- ============================================================================

-- Menu de contexto para geradores
require "LKS_EletricidadeConstrucao_ContextMenu_Generator"

-- Menu de contexto para interruptores de luz (informações de energia do prédio)
require "LKS_EletricidadeConstrucao_ContextMenu_LightSwitch"

-- Menu de contexto para instalação de interruptores de luz nativos com visualização prévia
require "LKS_EletricidadeConstrucao_ContextMenu_LightSwitchInstall"

-- TODO: Menu de contexto para barris (Fase 5)
if not LKS_EletricidadeConstrucao.Config or LKS_EletricidadeConstrucao.Config.BarrelSystemEnabled then
    require "actions/LKS_EletricidadeConstrucao_Actions_LinkBarrel"
    require "LKS_EletricidadeConstrucao_ContextMenu_Barrel"
end

-- ============================================================================
-- CARREGAMENTO DOS MÓDULOS DE INTERFACE GRÁFICA (UI)
-- ============================================================================

-- Janela de informações do gerador
require "ui/LKS_EletricidadeConstrucao_UI_GeneratorInfoWindow"

-- Painel de Depuração (apenas se o modo debug estiver ativo no sandbox, alternar com a tecla "-")
if LKS_EletricidadeConstrucao.Config and LKS_EletricidadeConstrucao.Config.DebugMode then
    require "ui/LKS_EletricidadeConstrucao_UI_DebugPanel"
end

-- Mecânica do cliente de aquecimento (gerencia objetos IsoHeatSource)
if not LKS_EletricidadeConstrucao.Config or LKS_EletricidadeConstrucao.Config.HeatingSystemEnabled then
    require "LKS_EletricidadeConstrucao_Heating_Client"
end

-- Sincronização e reconstrução de energia de prédios carregados na tela (Multiplayer)
require "LKS_EletricidadeConstrucao_Power_ClientSync"

-- Manipuladores de respostas a comandos enviados pelo servidor (confirmações no Multiplayer)
require "LKS_EletricidadeConstrucao_ClientCommands"

-- TODO: Visualização gráfica do raio de alcance do gerador (Fase 3)
-- require "ui/LKS_EletricidadeConstrucao_UI_RangeVisualization"

-- ============================================================================
-- CARREGAMENTO DE MANIPULADORES DE ENTRADA (TECLADO/ATALHOS)
-- ============================================================================

-- TODO: Teclas de atalho (Fase 9)
-- require "input/LKS_EletricidadeConstrucao_Input_Hotkeys"

-- ============================================================================
-- CARREGAMENTO DE MÓDULOS DE RENDERIZAÇÃO GRÁFICA
-- ============================================================================

-- TODO: Camada gráfica de depuração do mapa (Fase 10)
-- require "rendering/LKS_EletricidadeConstrucao_Render_DebugOverlay"

print("[LKS PATCH - LKS_EletricidadeConstrucao_ClientInit.lua] Carregado com sucesso!")
