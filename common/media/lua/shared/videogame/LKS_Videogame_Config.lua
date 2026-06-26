-- ============================================================================
-- LKS SUPERMOD PATCH — Videogame Funcional
-- ============================================================================
-- ARQUIVO: LKS_Videogame_Config.lua
-- OBJETIVO: Constantes de balanceamento do videogame portátil.
--
-- REGRAS DE MULTIPLICADORES:
--   1.0 = neutro (sem efeito)
--   < 1 = reduz/nerfa
--   > 1 = aumenta/buffa
--   Multiplicadores são SEMPRE compostos multiplicativamente entre si.
-- ============================================================================

LKS_VIDEOGAME = {

    -- ========================================================================
    -- DURAÇÃO BASE
    -- Tempo que leva para zerar moodles no cenário de referência:
    -- volume 100%, sem fone, sem nenhum multiplicador extra.
    -- ========================================================================
    horasParaZerarEstresse      = 3,
    horasParaZerarDepressao     = 3,
    horasDuracaoBaterias        = 2,    -- com 2 pilhas novas no volume 100% sem fone

    -- ========================================================================
    -- VOLUME
    -- O jogador controla de 0 a 100. Esse valor é usado como proporção (0.0 a 1.0)
    -- na fórmula de redução de moodles e consumo de bateria.
    -- ========================================================================
    volumeInicial               = 70,   -- valor ao equipar pela primeira vez (0-100)

    -- ========================================================================
    -- MULTIPLICADORES
    -- Todos baseados em 1.0 = neutro.
    -- Ajuste para balancear: menor = nerfa, maior = buffa.
    -- ========================================================================

    -- Quanto o volume potencializa a redução de moodles.
    -- Fórmula: reducao = base * (volume/100) * eficaciaVolume
    -- Com 0.5: no volume 100% a reducao será 50% do base (mais lento)
    -- Com 1.0: no volume 100% a reducao será 100% do base (padrão documentado)
    -- Com 2.0: no volume 100% a reducao será 200% do base (mais rápido)
    eficaciaVolume              = 1.0,

    -- Quanto o fone de ouvido melhora a redução de moodles (sobre o resultado do volume)
    -- 1.2 = +20% mais eficiente com fone
    eficaciaFone                = 1.2,

    -- Quanto o fone economiza bateria.
    -- 0.5 = consome apenas metade com fone (economia de 50%)
    -- 1.0 = sem economia
    economiaFone                = 0.5,

    -- Quanto o volume aumenta o consumo de bateria.
    -- Fórmula: consumo = base * (volume/100) * pesoVolumeNaBateria
    -- 1.0 = consumo proporcional linear ao volume
    -- 1.5 = 50% mais pesado no consumo
    pesoVolumeNaBateria         = 1.1,

    -- ========================================================================
    -- ATRAÇÃO DE ZUMBIS
    -- ========================================================================
    raioAtracaoZumbis           = 5,        -- tiles de raio (sem fone, volume > 10%)
    foneAnulaAtracaoZumbis      = true,     -- se true, fone impede atração

    -- ========================================================================
    -- ANIMAÇÃO
    -- ========================================================================
    tipoAnimacao                = "book",   -- "book", "newspaper" ou "photo"

    -- ========================================================================
    -- REFERÊNCIAS DE ITENS
    -- ========================================================================
    itemFullType                = "LKS_Entretenimento.LKS_Videogame",
    itemVanillaFullType         = "Base.VideoGame",

    bateriasAceitas             = {
        "Base.Battery",
    },

    fonesAceitos                = {
        "Base.Headphones",
        "Base.Earbuds",
    },
}

-- ============================================================================
-- VALORES DERIVADOS (calculados automaticamente — não editar)
-- ============================================================================

--- Taxa base de redução de estresse por minuto (estresse: 0.0 a 1.0)
LKS_VIDEOGAME.reducaoEstressePorMinuto = 1.0 / (LKS_VIDEOGAME.horasParaZerarEstresse * 60)

--- Taxa base de redução de depressão por minuto (depressão: 0 a 100)
LKS_VIDEOGAME.reducaoDepressaoPorMinuto = 100.0 / (LKS_VIDEOGAME.horasParaZerarDepressao * 60)

--- Consumo base de carga por minuto (100% dividido pela duração em minutos)
LKS_VIDEOGAME.consumoBateriaPorMinuto = 100.0 / (LKS_VIDEOGAME.horasDuracaoBaterias * 60)

print("[LKS PATCH - LKS_Videogame_Config.lua] Carregado com sucesso!")
