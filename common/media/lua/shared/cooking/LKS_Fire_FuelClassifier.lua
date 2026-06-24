-- ============================================================================
-- ARQUIVO: LKS_Fire_FuelClassifier.lua
-- EXTENSAO: LKS SuperMod Patch (Classificador de Combustivel Solido)
-- OBJETIVO: Centraliza a logica de classificacao de itens como combustivel
--           para todos os meios de fogo com combustivel solido. Logica
--           invertida: tudo queima EXCETO itens na lista de exclusao.
-- AUTOR: LKS FERREIRA
-- VERSAO: 1.0 (Project Zomboid Build 42)
-- DATA DA ULTIMA MODIFICACAO: 24/06/2026
-- ============================================================================

require "Camping/ISCampingMenu"

-- ============================================================================
-- CONFIGURACAO
-- ============================================================================

--- Flag global para habilitar dano a nao-combustiveis em containers de fogo acesos.
--- FUTURO: quando habilitado, itens nao-combustiveis dentro de containers acesos
--- sofrerao dano progressivo (perda de condicao, derretimento de plastico com
--- emissao de gas toxico similar ao gerador em ambiente fechado).
LKS_FIRE_DAMAGE_ENABLED = false

--- Multiplicador de eficiencia quando itens sao consumidos diretamente no fogo
--- sem usar "Transformar em Combustivel".
local MULTIPLICADOR_PENALIDADE = 0.75

-- ============================================================================
-- LISTAS DE EXCLUSAO
-- ============================================================================

--- Tags de item que indicam material nao-combustivel.
--- Itens com qualquer uma dessas tags NAO queimam.
--- @type table<string, boolean>
local TAGS_NAO_COMBUSTIVEIS = {
    ["hasmetal"]           = true,
    ["metalpiece"]         = true,
    ["smallsheetmetal"]    = true,
    ["sheetmetalsnips"]    = true,
    ["lightmetalsnips"]    = true,
    ["metalsaw"]           = true,
    ["metalbucket"]        = true,
    ["stone"]              = true,
    ["stonemaul"]          = true,
    ["limestone"]          = true,
    ["concrete"]           = true,
    ["brokenglass"]        = true,
    ["glass"]              = true,
    ["glassbottle"]        = true,
    ["glassbottlesmall"]   = true,
    ["carbattery"]         = true,
    ["copperore"]          = true,
    ["coppersource"]       = true,
}

--- Categorias de item (DisplayCategory) que NAO queimam.
--- @type table<string, boolean>
local CATEGORIAS_NAO_COMBUSTIVEIS = {
    ["Weapon"]                    = true,
    ["WeaponPart"]                = true,
    ["WeaponCrafted"]             = true,
    ["WeaponImprovised"]          = true,
    ["Tool"]                      = true,
    ["ToolWeapon"]                = true,
    ["VehicleMaintenance"]        = true,
    ["VehicleMaintenanceWeapon"]  = true,
    ["Ammo"]                      = true,
    ["Explosives"]                = true,
    ["Security"]                  = true,
    ["ProtectiveGear"]            = true,
    ["Electronics"]               = true,
    ["Fishing"]                   = true,
    ["FishingWeapon"]             = true,
    ["AnimalPartWeapon"]          = true,
    ["BrokenWeapon"]              = true,
    ["CookingWeapon"]             = true,
    ["GardeningWeapon"]           = true,
    ["HouseholdWeapon"]           = true,
    ["InstrumentWeapon"]          = true,
    ["JunkWeapon"]                = true,
    ["MaterialWeapon"]            = true,
    ["SportsWeapon"]              = true,
}

--- Lista de tipos especificos de item que NAO queimam.
--- Para itens que na vida real sao metal/nao-inflamaveis mas o PZ
--- nao marca com tag hasmetal. Extensivel para cenarios futuros.
--- @type table<string, boolean>
local TIPOS_NAO_COMBUSTIVEIS = {
    ["Paperclip"]           = true,
    ["PaperclipBox"]        = true,
    ["ElectronicsScrap"]    = true,
    ["ScrapMetal"]          = true,
    ["FishingHook"]         = true,
    ["FishingHookBox"]      = true,
    ["FishingHook_Forged"]  = true,
    ["Needle"]              = true,
    ["Needle_Brass"]        = true,
    ["Needle_Forged"]       = true,
    ["SutureNeedle"]        = true,
    ["SutureNeedleHolder"]  = true,
    ["Tweezers"]            = true,
    ["Tweezers_Forged"]     = true,
    ["Forceps_Forged"]      = true,
    ["ScissorsBlunt"]       = true,
    ["ScissorsBluntMedical"] = true,
    ["Splint"]              = true,
    ["KnittingNeedles"]     = true,
    ["Bell"]                = true,
    ["EngineParts"]         = true,
    ["CarBatteryCharger"]   = true,
    ["TrapCage"]            = true,
    ["TrapMouse"]           = true,
    ["Dart"]                = true,
}

-- ============================================================================
-- FUNCOES DE CLASSIFICACAO
-- ============================================================================

--- Verifica se um item possui alguma tag que indica material nao-combustivel.
---
--- @param item InventoryItem O item a verificar.
--- @return boolean ehNaoCombustivel True se o item tem tag de material nao-combustivel.
local function temTagNaoCombustivel(item)
    -- Usar getTags():toArray() que retorna strings como "base:hasmetal"
    local sucesso, tags = pcall(function()
        return item:getTags():toArray()
    end)

    if not sucesso or not tags then return false end

    for _, tagStr in ipairs(tags) do
        if tagStr then
            local tagConvertida = tostring(tagStr)
            -- Tags vem como "base:hasmetal" — extrair sufixo apos ":"
            local sufixo = tagConvertida:match(":(.+)") or tagConvertida
            if TAGS_NAO_COMBUSTIVEIS[sufixo] then
                return true
            end
        end
    end
    return false
end

--- Determina se um item eh combustivel solido.
---
--- Logica invertida: tudo queima EXCETO o que esta na lista de exclusao.
--- Expande sobre o vanilla: couro queima, containers com itens sao processados,
--- itens misc (carteira, borracha, dinheiro) queimam.
---
--- @param item InventoryItem O item a classificar.
--- @param ignorarFavoritoEquipado boolean|nil Se true, ignora verificacao de favorito/equipado.
--- @return boolean ehCombustivel True se o item pode virar combustivel.
function LKS_ehCombustivel(item, ignorarFavoritoEquipado)
    if not item then return false end

    -- Manter regra vanilla: itens favoritos ou equipados nao queimam
    if not ignorarFavoritoEquipado then
        if item:isFavorite() or item:isEquipped() then
            return false
        end
    end

    -- FluidContainer com liquido nao queima (manter vanilla)
    if item:getFluidContainer() and item:getFluidContainer():getAmount() > 0 then
        return false
    end

    -- Tipo especifico na lista de excecoes explicitas
    local tipo = item:getType()
    if TIPOS_NAO_COMBUSTIVEIS[tipo] then
        return false
    end

    -- Tags de material nao-combustivel
    if temTagNaoCombustivel(item) then
        return false
    end

    -- Categoria nao-combustivel
    local categoriaDisplay = item:getDisplayCategory()
    local categoriaBase = item:getCategory()
    if categoriaDisplay and CATEGORIAS_NAO_COMBUSTIVEIS[categoriaDisplay] then
        return false
    end
    if categoriaBase and CATEGORIAS_NAO_COMBUSTIVEIS[categoriaBase] then
        return false
    end

    -- Roupas molhadas queimam com penalidade proporcional a umidade
    -- A penalidade eh aplicada no calculo de duracao, nao bloqueia o item
    -- (verificacao removida - wetness afeta apenas eficiencia via LKS_calcularDuracao)

    -- Se passou por todas as exclusoes: eh combustivel
    return true
end

--- Coleta recursivamente todos os itens combustiveis dentro de um item container.
---
--- Percorre mochilas, bolsas, carteiras e qualquer InventoryContainer.
--- Separa itens em combustiveis e nao-combustiveis.
---
--- @param item InventoryItem O item a processar (pode ser container ou item simples).
--- @param listaCombustiveis table Lista para adicionar itens combustiveis encontrados.
--- @param listaNaoCombustiveis table Lista para adicionar itens nao-combustiveis encontrados.
--- @param ignorarFavoritoEquipado boolean|nil Se true, ignora verificacao de favorito/equipado.
function LKS_ehCombustivelRecursivo(item, listaCombustiveis, listaNaoCombustiveis, ignorarFavoritoEquipado)
    if not item then return end

    -- Se eh um InventoryContainer (mochila, bolsa, carteira, sacola)
    if instanceof(item, "InventoryContainer") then
        local inventarioInterno = item:getInventory()
        if inventarioInterno and not inventarioInterno:isEmpty() then
            local itensInternos = inventarioInterno:getItems()
            -- Percorre de tras para frente (remocao segura)
            for indice = itensInternos:size() - 1, 0, -1 do
                local itemInterno = itensInternos:get(indice)
                LKS_ehCombustivelRecursivo(itemInterno, listaCombustiveis, listaNaoCombustiveis, ignorarFavoritoEquipado)
            end
        end

        -- O container em si (mochila, bolsa) tambem eh combustivel se passar no filtro
        if LKS_ehCombustivel(item, ignorarFavoritoEquipado) then
            table.insert(listaCombustiveis, item)
        else
            table.insert(listaNaoCombustiveis, item)
        end
        return
    end

    -- Item simples
    if LKS_ehCombustivel(item, ignorarFavoritoEquipado) then
        table.insert(listaCombustiveis, item)
    else
        table.insert(listaNaoCombustiveis, item)
    end
end

--- Calcula a duracao em minutos de um item como combustivel.
---
--- Reutiliza a formula vanilla de ISCampingMenu.getFuelDurationForItem como base.
--- Aplica penalidade de eficiencia quando solicitado (75% do valor normal).
---
--- @param item InventoryItem O item combustivel.
--- @param comPenalidade boolean|nil Se true, aplica multiplicador de penalidade (75%).
--- @return number duracaoMinutos Duracao em minutos como combustivel.
function LKS_calcularDuracao(item, comPenalidade)
    if not item then return 0 end

    local duracaoBase = ISCampingMenu.getFuelDurationForItem(item)

    -- Itens que o vanilla nao reconhece como combustivel mas nos sim:
    -- calcular duracao baseada no peso (mesma formula vanilla)
    if duracaoBase <= 0 then
        local peso = item:getActualWeight()
        local razao = 2.0 / 3.0

        if item:IsClothing() or item:IsInventoryContainer() or item:IsLiterature() or item:IsMap() then
            razao = 0.25
        end

        if item:getFireFuelRatio() > 0 then
            razao = item:getFireFuelRatio()
        end

        duracaoBase = peso * razao * 60
    end

    if comPenalidade then
        duracaoBase = duracaoBase * MULTIPLICADOR_PENALIDADE
    end

    -- Penalidade por umidade: quanto mais molhado, menos eficiente
    -- wetness 0 = 100% eficiencia, wetness 100 = 50% eficiencia (linear)
    if item:IsClothing() and item.getWetness and item:getWetness() > 0 then
        local umidade = item:getWetness()
        local multiplicadorUmidade = 1.0 - (umidade / 200.0)
        duracaoBase = duracaoBase * multiplicadorUmidade
    end

    return duracaoBase
end

-- ============================================================================
-- OVERRIDE DO shouldBurn VANILLA
-- ============================================================================

--- Substitui ISCampingMenu.shouldBurn para usar a nova classificacao LKS.
---
--- O vanilla bloqueia couro e containers com itens. Nossa versao desbloqueia
--- ambos, delegando a classificacao completa para LKS_ehCombustivel.
---
---@diagnostic disable-next-line: duplicate-set-field
ISCampingMenu.shouldBurn = function(item, includeEquipped)
    if not item then return false end
    return LKS_ehCombustivel(item, includeEquipped)
end

--- Substitui ISCampingMenu.isValidFuel para usar a nova classificacao LKS.
---
--- Expande significativamente o que eh considerado combustivel: roupas de couro,
--- itens misc (carteira, borracha), containers vazios, etc.
---
---@diagnostic disable-next-line: duplicate-set-field
ISCampingMenu.isValidFuel = function(item)
    if not item then return false end
    return LKS_ehCombustivel(item)
end

-- ============================================================================
-- STUB PARA DANO A NAO-COMBUSTIVEIS (FUTURO)
-- ============================================================================

--- Stub: aplica dano por calor a um item nao-combustivel dentro de container aceso.
---
--- FUTURO: quando LKS_FIRE_DAMAGE_ENABLED for habilitado, itens nao-combustiveis
--- dentro de containers acesos sofrerao dano progressivo:
--- - Plastico: emissao de gas toxico (reutilizar mecanica de gerador em ambiente fechado)
--- - Metal: aquecimento (dano de queimadura ao pegar sem luvas)
--- - Vidro: derretimento parcial (reduz condicao)
---
--- @param item InventoryItem O item nao-combustivel.
--- @param container ItemContainer O container do fogo.
function LKS_aplicarDanoCalor(item, container)
    if not LKS_FIRE_DAMAGE_ENABLED then return end
    -- FUTURO: implementar dano progressivo
end

-- ============================================================================

print("[LKS PATCH - LKS_Fire_FuelClassifier.lua] Classificador de combustivel carregado")
