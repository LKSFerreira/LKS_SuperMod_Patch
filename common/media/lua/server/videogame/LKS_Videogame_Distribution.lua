-- ============================================================================
-- LKS SUPERMOD PATCH — Videogame Funcional
-- ============================================================================
-- ARQUIVO: LKS_Videogame_Distribution.lua
-- OBJETIVO: Injetar o item LKS_Videogame nas mesmas tabelas de loot do
--           Base.VideoGame vanilla, garantindo que apareça naturalmente no mundo.
-- ============================================================================

local function LKS_Videogame_injetarDistribuicao()
    -- Tabelas procedurais onde o VideoGame vanilla aparece
    -- Usamos a mesma chance (weight) do vanilla para cada tabela
    local tabelasAlvo = {
        { nome = "ElectronicStoreMisc",    peso = 10 },
        { nome = "GigamartElectronics",    peso = 10 },
        { nome = "CrateToys",             peso = 4 },
        { nome = "WardrobeChild",         peso = 2 },
        { nome = "DeskGeneric",           peso = 2 },
        { nome = "BedroomDresser",        peso = 2 },
        { nome = "ShelfGeneric",          peso = 1 },
        { nome = "CrateRandomJunk",       peso = 4 },
        { nome = "PawnShopElectronics",   peso = 10 },
        { nome = "GarageRandom",          peso = 0.2 },
    }

    local itemFullType = "LKS_Entretenimento.LKS_Videogame"

    for _, tabela in ipairs(tabelasAlvo) do
        if ProceduralDistributions and ProceduralDistributions.list[tabela.nome] then
            local listaItens = ProceduralDistributions.list[tabela.nome].items
            if listaItens then
                table.insert(listaItens, itemFullType)
                table.insert(listaItens, tabela.peso)
            end
        end
    end
end

Events.OnPostDistributionMerge.Add(LKS_Videogame_injetarDistribuicao)

print("[LKS PATCH - LKS_Videogame_Distribution.lua] Carregado com sucesso!")
