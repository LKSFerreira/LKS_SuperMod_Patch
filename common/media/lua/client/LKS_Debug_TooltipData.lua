-- ============================================================================
-- ARQUIVO: LKS_Debug_TooltipData.lua
-- EXTENSÃO: LKS SuperMod Patch (Ferramenta de Desenvolvimento)
-- OBJETIVO: Base de dados de descrições para tooltips do Inspetor de Objetos.
--           Mapeia nomes de propriedades do PropertyContainer para descrições
--           claras e concisas em pt-BR, exibidas como tooltip ao passar o mouse.
-- AUTOR: LKS FERREIRA
-- VERSÃO: 1.0 (Project Zomboid Build 42)
-- DATA DA ÚLTIMA MODIFICAÇÃO: 17/06/2026
-- ============================================================================
--
-- ## USO:
--
-- Este módulo é consumido pelo LKS_Debug_Tool.lua na aba "Inspetor de Objeto".
-- Ao passar o mouse sobre uma propriedade na lista, o tooltip correspondente
-- é exibido automaticamente usando o sistema nativo ISScrollingListBox.tooltip.
--
-- ## MANUTENÇÃO:
--
-- Para adicionar novas propriedades, basta inserir uma entrada na tabela
-- correspondente à seção onde ela aparece no inspetor.
--
-- ============================================================================

LKS_DebugTooltipData = LKS_DebugTooltipData or {}

-- =============================================================================
-- PROPRIEDADES DO SPRITE (PropertyContainer)
-- Estas são as propriedades lidas via objeto:getProperties():getPropertyNames()
-- =============================================================================

LKS_DebugTooltipData.propriedadesSprite = {

    -- =========================================================================
    -- IDENTIDADE E NOMEAÇÃO
    -- =========================================================================

    CustomName = "Nome personalizado do objeto. Compoe o nome final: GroupName + CustomName (ex: 'Fancy' + 'Bed' = 'Fancy Bed').",
    GroupName = "Prefixo do nome — indica cor, estilo ou variante visual (ex: 'Red', 'Blue', 'Modern'). Diferencia variações do mesmo tipo de objeto.",
    CustomItem = "ID do item especifico retornado ao coletar (ex: 'Radio.HamRadio'). Sobrescreve o moveable generico.",
    IsoType = "Classe Java que controla o comportamento do objeto. 'IsoObject' = generico. Outros: IsoStove (fogao), IsoRadio, IsoClothingWasher, etc.",
    name = "Nome interno do sprite no sistema do jogo.",

    -- =========================================================================
    -- POSICIONAMENTO E ORIENTAÇÃO
    -- =========================================================================

    Facing = "Direcao da FRENTE do objeto (N/S/E/W). Se Facing='S', a frente olha para o Sul (orientacao Norte). Base para o sistema de rotacao.",
    Noffset = "Delta de indice no spritesheet para a versao virada para Norte. Soma-se ao sprite ID base. Valor 0 = sem sprite nessa direcao.",
    Soffset = "Delta de indice no spritesheet para a versao virada para Sul.",
    Woffset = "Delta de indice no spritesheet para a versao virada para Oeste. Ex: Woffset=2 significa sprite Oeste = spriteID + 2.",
    Eoffset = "Delta de indice no spritesheet para a versao virada para Leste.",
    LinkedOffset = "Offset para sprite vinculado em objetos multi-tile. Distancia em indice de sprite ate o tile parceiro.",
    LinkedLocIs = "Direcao onde esta o tile parceiro vinculado (N/S/E/W). Para objetos compostos de multiplos tiles.",
    SpriteGridPos = "Posicao X,Y dentro de objetos multi-tile. X cresce para sudeste, Y para sudoeste (visao isometrica).",
    SpriteGridLevel = "Nivel vertical no grid de sprites (para objetos com multiplos andares).",

    -- =========================================================================
    -- SUPERFÍCIE E ALTURA
    -- =========================================================================

    Surface = "Altura em pixels da superficie plana. Define onde itens sao colocados 'em cima' (mesas, bancadas). Valor 0 = nivel do chao.",
    IsSurfaceOffset = "Quando presente, Surface indica a altura da BASE do objeto (nao da superficie). Usado para objetos sobre outros (abajur sobre mesa).",
    ItemHeight = "Altura da superficie propria quando IsSurfaceOffset esta ativo. Define onde itens ficam em cima DESTE objeto.",
    IsTable = "Trata como superficie de mesa — permite colocar itens sobre ele.",
    IsTableTop = "Permite empilhar outros tiles/objetos moveis sobre este.",
    halfheight = "Tile ocupa metade da altura padrao.",
    IsHigh = "Ocupa apenas a METADE SUPERIOR do espaco (quadros, prateleiras suspensas). Permite objetos baixos no mesmo tile.",
    IsLow = "Ocupa apenas a METADE INFERIOR do espaco (camas, bancadas). Permite objetos altos (IsHigh) no mesmo tile.",
    IsStackable = "Permite empilhar multiplas instancias deste objeto verticalmente.",
    FloorHeight = "Altura do piso definida por este tile (pisos elevados).",
    FloorHeightOneThird = "Piso com altura de 1/3 do padrao.",
    FloorHeightTwoThirds = "Piso com altura de 2/3 do padrao.",
    IgnoreSurfaceSnap = "Ignora snap automatico a superficie abaixo. Posicionamento livre em vez de encaixar na mesa/balcao.",

    -- =========================================================================
    -- MOVIMENTAÇÃO E COLETA
    -- =========================================================================

    IsMoveAble = "Objeto movel — jogador pode pegar e reposicionar. Gera item de inventario tipo 'moveable'.",
    isMoveAbleObject = "Variante de IsMoveAble para objetos compostos.",
    MoveType = "Subtipo movel: Normal, WallObject (parede), WindowObject (janela), FloorTile (piso), FloorRug (tapete), Vegitation (planta).",
    PickUpTool = "Ferramenta necessaria para pegar: None (maos), Hammer (martelo), Crowbar (pe-de-cabra), Electrician, Cutter, Shovel, Wrench.",
    PlaceTool = "Ferramenta necessaria para COLOCAR de volta no mundo. Mesmos valores de PickUpTool.",
    PickUpLevel = "Nivel minimo na habilidade da ferramenta para poder pegar. Ex: PickUpTool='Hammer' + PickUpLevel=3 exige Carpintaria 3.",
    PickUpWeight = "Peso bruto (dividir por 10 = peso no inventario). Ex: 200 = peso 20.0. Tambem influencia tempo da acao (mais pesado = mais lento).",
    CanBreak = "Objeto pode quebrar ao ser pego. Chance diminui com nivel na habilidade. So funciona com PickUpTool definido.",
    ForceSingleItem = "Objetos multi-tile viram 1 unico item no inventario (ex: sofa de 3 tiles = 1 item 'Sofa').",
    IsClosedState = "Sprite atual e o estado FECHADO. Usado para alternancia aberto/fechado (janelas, armarios).",
    WallObjectAllowDoorframe = "Permite colocar este objeto de parede em batentes de porta.",
    IsGridExtensionTile = "Tile de extensao de grid — parte de objeto multi-tile que nao e o tile principal.",

    -- =========================================================================
    -- MATERIAIS E DESMONTE
    -- =========================================================================

    Material = "Material primario. Determina itens retornados ao desmontar: Wood (tabuas), Steel (parafusos), Fabric (trapos), Brick (tijolos), etc.",
    Material2 = "Material secundario — retorna itens adicionais ao desmontar. 'Undefined' e ignorado.",
    Material3 = "Material terciario — mais itens ao desmontar.",
    MaterialType = "Tipo para efeitos de som e particulas: Metal_Large, Wood_Small, Glass, Stone, Carpet, Concrete, etc. Diferente de Material (craft).",
    CanScrap = "Pode ser sucateado/desmontado para materiais. Requer Material valido.",
    ScrapSize = "Tamanho do desmonte: Small (3 usos), Medium (5 usos), Large (10 usos de ferramenta).",
    ScrapUseTool = "LOGICA INVERTIDA: presenca = NAO requer ferramenta para desmontar.",
    ScrapUseSkill = "LOGICA INVERTIDA: presenca = NAO requer habilidade para desmontar.",
    ScrapToolUseOverride = "Sobrescreve numero padrao de usos de ferramenta para desmontar.",

    -- =========================================================================
    -- COLISÃO E FÍSICA
    -- =========================================================================

    solid = "Completamente solido — bloqueia toda passagem de personagens e zombies.",
    solidtrans = "Solido mas transparente (vidro, grade). Bloqueia passagem, permite visao.",
    solidfloor = "Piso solido — suporta peso, bloqueia queda.",
    collideN = "Bloqueia colisao na borda Norte (meia-parede, balcao). Personagens nao passam por esse lado.",
    collideW = "Bloqueia colisao na borda Oeste.",
    BlocksPlacement = "Nenhum outro tile pode ser colocado neste quadrado. Reserva espaco.",
    blocksight = "Bloqueia linha de visao — personagens e zombies nao veem atraves.",
    BlockRain = "Bloqueia chuva — areas abaixo ficam secas.",
    canPathN = "NPCs/zombies podem tracar caminho pela borda Norte.",
    canPathW = "NPCs/zombies podem tracar caminho pela borda Oeste.",
    CantClimb = "Impede escalada deste objeto.",
    HoppableN = "Pode ser pulado pela borda Norte (cercas baixas, balcoes).",
    HoppableW = "Pode ser pulado pela borda Oeste.",
    TallHoppableN = "Pode ser escalado pela borda Norte (cercas altas) — mais lento que pular.",
    TallHoppableW = "Pode ser escalado pela borda Oeste.",
    FenceTypeHigh = "Cerca alta — afeta animacao de escalar.",
    FenceTypeLow = "Cerca baixa — pulo rapido.",
    HitByCar = "Veiculos podem atingir/destruir este objeto.",
    CarSlowFactor = "Fator de reducao de velocidade de veiculos ao passar por cima.",
    MinimumCarSpeedDmg = "Velocidade minima do carro para causar dano a este objeto.",
    StopCar = "Para veiculos completamente ao colidir (postes, arvores grandes).",
    SpearOnlyAttackThrough = "Apenas lancas podem atacar atraves deste tile (grades, frestas).",
    PhysicsMesh = "Malha de colisao customizada para fisica avancada.",
    PhysicsShape = "Forma geometrica de colisao (caixa, cilindro, etc).",
    Movement = "Modificador de velocidade de movimento ao caminhar sobre este tile.",

    -- =========================================================================
    -- PAREDES E ESTRUTURAS
    -- =========================================================================

    WallN = "Parede na borda Norte.",
    WallW = "Parede na borda Oeste.",
    WallNW = "Parede de canto Norte-Oeste (pilar de esquina).",
    WallSE = "Parede de canto Sudeste.",
    WallNTrans = "Parede Norte transparente (vitrine, grade).",
    WallWTrans = "Parede Oeste transparente.",
    WallNWTrans = "Canto NW transparente.",
    WallType = "Tipo/material da parede (afeta som, destruicao, textura de dano).",
    WallOverlay = "Overlay sobre parede existente (papel de parede, pintura aplicada).",
    wall = "Flag generica — tile e uma parede.",
    CornerNorthWall = "Canto de parede norte (pilar estrutural).",
    CornerWestWall = "Canto de parede oeste.",
    doorN = "Porta na borda Norte.",
    doorW = "Porta na borda Oeste.",
    doorTrans = "Porta transparente (vidro).",
    doorFrN = "Batente de porta na borda Norte.",
    doorFrW = "Batente de porta na borda Oeste.",
    DoorWallN = "Parede com porta embutida — Norte.",
    DoorWallW = "Parede com porta embutida — Oeste.",
    DoorWallNW = "Parede com porta no canto NW.",
    DoorWallNTrans = "Parede com porta transparente — Norte.",
    DoorWallWTrans = "Parede com porta transparente — Oeste.",
    DoorWallNWTrans = "Parede com porta transparente — canto NW.",
    DoorSound = "Som reproduzido ao abrir/fechar esta porta.",
    DoubleDoor = "Porta dupla (dois batentes).",
    DoubleDoor1 = "Primeiro batente de porta dupla.",
    DoubleDoor2 = "Segundo batente de porta dupla.",
    GarageDoor = "Porta de garagem (abre verticalmente).",
    WindowN = "Janela na borda Norte.",
    WindowW = "Janela na borda Oeste.",
    windowFN = "Frame de janela na borda Norte.",
    windowFW = "Frame de janela na borda Oeste.",
    WindowLocked = "Janela trancada — nao pode ser aberta sem arrombar.",
    UnbreakableWindowN = "Janela Norte inquebravel (blindada).",
    UnbreakableWindowW = "Janela Oeste inquebravel.",
    UnbreakableWindowNW = "Janela canto NW inquebravel.",
    makeWindowInvincible = "Torna a janela invencivel (nao pode ser destruida).",
    forceLocked = "Forca estado trancado — impede abertura sem arrombamento.",
    forcedLocked = "Trancamento forcado.",

    -- =========================================================================
    -- CONTAINERS E ARMAZENAMENTO
    -- =========================================================================

    container = "Tipo de container: fridge, freezer, stove, microwave, shelves, counter, crate, etc.",
    ContainerCapacity = "Capacidade de armazenamento em unidades de peso.",
    ContainerPosition = "Posicao visual do container (onde icone de inventario aparece).",
    ContainerOpenSound = "Som ao abrir o container.",
    ContainerCloseSound = "Som ao fechar o container.",
    ContainerPutSound = "Som ao colocar item dentro.",
    ContainerTakeSound = "Som ao retirar item.",
    IsFridge = "Geladeira — resfria itens quando energizado.",
    Freezer = "Freezer — congela itens quando energizado.",
    FreezerCapacity = "Capacidade do compartimento freezer.",
    FreezerPosition = "Posicao do compartimento freezer no objeto.",
    NoFreezer = "Geladeira SEM compartimento freezer.",
    IsTrashCan = "Lixeira — pode conter loot de lixo.",
    WheelieBin = "Lixeira com rodas.",
    IsWaterCollector = "Coleta agua da chuva automaticamente.",

    -- =========================================================================
    -- ILUMINAÇÃO E VISUAL
    -- =========================================================================

    lightR = "Componente VERMELHO da luz emitida (0.0 a 1.0).",
    lightG = "Componente VERDE da luz emitida.",
    lightB = "Componente AZUL da luz emitida.",
    LightRadius = "Raio da luz emitida em tiles.",
    LightFilterR = "Filtro de cor da luz — vermelho.",
    LightFilterG = "Filtro de cor da luz — verde.",
    LightFilterB = "Filtro de cor da luz — azul.",
    LightFilterIntensity = "Intensidade do filtro de luz.",
    LightFilterMix = "Mistura entre luz natural e filtrada.",
    lightswitch = "Interruptor de luz — controla iluminacao do comodo.",
    streetlight = "Poste de luz — ilumina area externa.",
    HasLightOnSprite = "Sprite possui indicador visual de luz acesa (LED, lampada).",
    NoWallLighting = "Desabilita calculo de iluminacao de parede.",
    unlit = "Tile nao e afetado pela iluminacao dinamica (sempre escuro).",
    alwaysDraw = "Forca renderizacao mesmo quando normalmente ocultado pelo cutaway (recorte de paredes).",
    forceRender = "Forca renderizacao incondicional.",
    forceFade = "Forca efeito de fade (transparencia gradual).",
    NeverCutaway = "Nunca aplica cutaway — sempre visivel mesmo com paredes.",
    invisible = "Existe no mundo mas NAO e renderizado.",
    trans = "Semi-transparente.",
    Translucent = "Translucido (vidro fosco, cortinas finas).",
    transparentFloor = "Piso transparente (grade, vidro no chao).",
    transparentN = "Borda Norte transparente.",
    transparentW = "Borda Oeste transparente.",
    TreatAsWallOrder = "Renderiza na mesma ordem de desenho que paredes.",
    hidewalls = "Oculta paredes adjacentes quando este tile e renderizado.",
    CutawayHint = "Dica para o sistema de cutaway sobre como recortar.",
    RenderLayer = "Camada de renderizacao — controla ordem de desenho.",
    OpaquePixelsOnly = "Renderiza apenas pixels opacos (ignora semi-transparencia).",
    UseObjectDepthTexture = "Herda textura de profundidade do objeto abaixo (overlays em prateleiras).",
    TileOverlay = "Tile e um overlay (camada sobre outro tile).",
    FloorOverlay = "Overlay de piso (poca d'agua, sujeira, sangue).",

    -- =========================================================================
    -- INTERAÇÃO E GAMEPLAY
    -- =========================================================================

    bed = "Cama — jogador pode dormir.",
    BedType = "Tipo de cama (qualidade do sono, conforto).",
    chairN = "Cadeira virada para Norte — jogador pode sentar.",
    chairS = "Cadeira virada para Sul.",
    chairE = "Cadeira virada para Leste.",
    chairW = "Cadeira virada para Oeste.",
    Microwave = "Micro-ondas — aquece alimentos, requer energia.",
    TV = "Televisao.",
    radio = "Radio.",
    jukebox = "Jukebox — reproduz musica ambiente.",
    signal = "Sinal de radio/TV que este aparelho recebe.",
    propaneTank = "Tanque de propano — alimenta churrasqueiras.",
    fuelAmount = "Quantidade de combustivel contida.",
    GeneratorSound = "Som emitido pelo gerador quando ligado.",
    GenericCraftingSurface = "Superficie utilizavel para crafting generico.",
    SinkType = "Tipo de pia — capacidade de agua e funcionalidades.",
    firerequirement = "Requisito de fogo para interagir.",
    canBeCut = "Pode ser cortado (vegetacao, arvores, arbustos).",
    canBeRemoved = "Pode ser removido sem ferramenta especial.",
    Bush = "Arbusto — pode ser cortado, pode esconder itens.",
    tree = "Arvore — pode ser derrubada com machado.",
    vegitation = "Vegetacao generica.",
    CanAttachAnimal = "Pode amarrar animais (postes, cercas).",
    IsMirror = "Espelho — jogador pode ver sua aparencia.",
    IsPaintable = "Superficie pode receber pintura.",
    PaintingType = "Tipo de quadro/pintura.",
    CloseSneakBonus = "Bonus de furtividade quando agachado proximo.",
    SeatMaterial = "Material do assento (som ao sentar, conforto).",
    livingRoom = "Identifica como sala de estar (logica de meta-zonas).",

    -- =========================================================================
    -- CLIMA E AMBIENTE
    -- =========================================================================

    MoveWithWind = "Sprite oscila com o vento (bandeiras, plantas, cortinas).",
    WindType = "Tipo de animacao de vento.",
    HasRaindrop = "Gotas de chuva renderizadas sobre este tile.",
    HasRainSplashes = "Respingos de chuva na superficie.",
    SnowTile = "Sprite alternativo quando ha neve.",
    BurntTile = "Sprite quando queimado.",
    DamagedSprite = "Sprite quando danificado.",
    burning = "Em chamas.",
    burntOut = "Completamente queimado.",
    unflammable = "Nao pode pegar fogo.",
    smoke = "Emite particulas de fumaca.",
    AmbientSound = "Som ambiente constante (buzzing, agua correndo).",
    ForceAmbient = "Forca emissao de som ambiente.",
    ThumpSound = "Som ao ser socado por zombies.",

    -- =========================================================================
    -- PISOS E TELHADOS
    -- =========================================================================

    grassFloor = "Piso de grama — pode ser arado para plantio.",
    diamondFloor = "Piso com padrao diamante.",
    natureFloor = "Piso natural (terra, areia, cascalho).",
    FloorMaterial = "Material do piso (som de passos, velocidade).",
    FootstepMaterial = "Material para som de passos (mais granular).",
    GrimeType = "Tipo de sujeira acumulada ao longo do tempo.",
    RoofGroup = "Grupo de telhado.",
    WestRoofB = "Telhado oeste — base.",
    WestRoofM = "Telhado oeste — meio.",
    WestRoofT = "Telhado oeste — topo.",
    isEave = "Beiral de telhado.",
    FasciaEdge = "Acabamento horizontal do telhado.",
    FasciaEdgeReversible = "Fascia invertivel.",

    -- =========================================================================
    -- ATTACHMENT (VINCULAÇÃO ESTRUTURAL)
    -- =========================================================================

    AttachedFloor = "Vinculado ao piso — destruido se piso for removido.",
    attachedFloor = "Vinculado ao piso — destruido se piso for removido.",
    attachedCeiling = "Vinculado ao teto (luminarias, ventiladores).",
    attachedN = "Vinculado a parede Norte — destruido se parede removida.",
    attachedS = "Vinculado a parede Sul.",
    attachedE = "Vinculado a parede Leste.",
    attachedW = "Vinculado a parede Oeste.",
    attachedNW = "Vinculado ao canto NW.",
    attachedSE = "Vinculado ao canto SE.",
    attachedSurface = "Vinculado a superficie abaixo — destruido se movel base removido.",
    AttachedToGlass = "Vinculado ao vidro — destruido se vidro quebrar.",
    attachtostairs = "Vinculado a escada.",
    IsFloorAttached = "Confirmacao de vinculo ao piso.",
    FloorAttachmentN = "Ponto de attachment no piso — lado Norte.",
    FloorAttachmentS = "Ponto de attachment no piso — lado Sul.",
    FloorAttachmentE = "Ponto de attachment no piso — lado Leste.",
    FloorAttachmentW = "Ponto de attachment no piso — lado Oeste.",

    -- =========================================================================
    -- ESCADAS
    -- =========================================================================

    stairsBN = "Base de escada — Norte.",
    stairsBW = "Base de escada — Oeste.",
    stairsMN = "Meio de escada — Norte.",
    stairsMW = "Meio de escada — Oeste.",
    stairsTN = "Topo de escada — Norte.",
    stairsTW = "Topo de escada — Oeste.",

    -- =========================================================================
    -- CORTINAS E ESCALADA
    -- =========================================================================

    curtainN = "Cortina no lado Norte.",
    curtainS = "Cortina no lado Sul.",
    curtainE = "Cortina no lado Leste.",
    curtainW = "Cortina no lado Oeste.",
    CurtainOffset = "Offset de sprite para estado da cortina (aberta/fechada).",
    CurtainSound = "Som ao abrir/fechar cortina.",
    climbSheetN = "Pode escalar pela corda/lencol — janela Norte.",
    climbSheetS = "Escalar — janela Sul.",
    climbSheetE = "Escalar — janela Leste.",
    climbSheetW = "Escalar — janela Oeste.",
    climbSheetTopN = "Topo da corda — Norte.",
    climbSheetTopS = "Topo da corda — Sul.",
    climbSheetTopE = "Topo da corda — Leste.",
    climbSheetTopW = "Topo da corda — Oeste.",
    TieSheetRope = "Permite amarrar lencol/corda para escape.",

    -- =========================================================================
    -- CONEXÃO E MULTI-TILE
    -- =========================================================================

    connectX = "Ponto de conexao X para objetos interconectados.",
    connectY = "Ponto de conexao Y para objetos interconectados.",
    GlassRemovedOffset = "Offset para sprite sem vidro (janela quebrada).",
    OpenTileOffset = "Offset para sprite no estado aberto (portas, armarios).",
    open = "Estado inicial do tile e aberto.",
    SmashedTileOffset = "Offset para sprite destruido/quebrado.",
    StackReplaceTileOffset = "Offset do tile substituto ao empilhar.",

    -- =========================================================================
    -- ENTIDADES E SCRIPTS
    -- =========================================================================

    EntityScript = "Script de entidade vinculado (sistema Build 42).",
    EntityScriptName = "Nome do script de entidade.",
    blueprint = "Blueprint associado (sistema de construcao).",

    -- =========================================================================
    -- DIVERSOS
    -- =========================================================================

    exterior = "Area externa.",
    interior = "Area interna.",
    InteriorSide = "Lado interior da parede (textura interna vs externa).",
    noStart = "Jogadores NAO podem iniciar spawn aqui.",
    cutN = "Permite cortar vegetacao na borda Norte.",
    cutW = "Permite cortar vegetacao na borda Oeste.",
    taintedWater = "Agua contaminada — causa doenca se bebida sem ferver.",
    water = "Fonte de agua.",
    waterAmount = "Quantidade de agua disponivel.",
    waterMaxAmount = "Capacidade maxima de agua.",
    waterPiped = "Conectado a rede de agua encanada.",
    SlopedSurfaceDirection = "Direcao da inclinacao (telhados, rampas).",
    SlopedSurfaceHeightMin = "Altura minima da superficie inclinada (0-100).",
    SlopedSurfaceHeightMax = "Altura maxima da superficie inclinada (0-100).",
}

-- =============================================================================
-- TOOLTIPS PARA SEÇÃO DE IDENTIDADE (capturada manualmente pelo inspetor)
-- =============================================================================

LKS_DebugTooltipData.identidade = {
    ["Classe Java"] = "Classe Java que instancia este objeto. Determina comportamentos: IsoObject (generico), IsoStove (fogao), IsoThumpable (destruivel), etc.",
    ["Sprite"] = "Nome do sprite no atlas de texturas. Formato: 'tileset_nome_XX' onde XX e o indice no spritesheet.",
    ["Coordenadas"] = "Posicao no mundo: X (menor=direita, maior=esquerda), Y (menor=perto, maior=longe), Z (altura/andar).",
    ["Nome"] = "Nome de exibicao do objeto no jogo.",
}

-- =============================================================================
-- TOOLTIPS PARA SEÇÃO DE CONTAINER
-- =============================================================================

LKS_DebugTooltipData.container = {
    ["Tipo"] = "Tipo do container — define categoria de loot e icone de inventario.",
    ["Capacidade"] = "Capacidade maxima em unidades de peso que este container suporta.",
    ["Energizado"] = "Se o container esta recebendo energia eletrica (necessario para geladeiras/freezers).",
    ["Itens Dentro"] = "Quantidade total de itens armazenados atualmente neste container.",
}

-- =============================================================================
-- TOOLTIPS PARA SEÇÃO DE ESTADO
-- =============================================================================

LKS_DebugTooltipData.estado = {
    ["Ativado"] = "Se o objeto esta ligado/ativo (luzes, fogoes, geladeiras).",
    ["Temperatura"] = "Temperatura interna atual do objeto em graus Celsius.",
    ["Condicao"] = "Estado de conservacao do objeto (0 = destruido, valor maximo = perfeito).",
}

-- =============================================================================
-- TOOLTIPS PARA FLAGS (IsoFlagType)
-- =============================================================================

LKS_DebugTooltipData.flags = {
    canBeCut = "Pode ser cortado (vegetacao, arbustos, cercas vivas).",
    canBeRemoved = "Pode ser removido manualmente.",
    collideN = "Colisao na borda Norte — bloqueia passagem.",
    collideW = "Colisao na borda Oeste.",
    doorN = "Flag de porta — borda Norte.",
    doorW = "Flag de porta — borda Oeste.",
    DoorWallN = "Parede com porta embutida — Norte.",
    DoorWallW = "Parede com porta embutida — Oeste.",
    HoppableN = "Pode ser pulado pela borda Norte (cerca baixa).",
    HoppableW = "Pode ser pulado pela borda Oeste.",
    solid = "Completamente solido — bloqueia toda passagem.",
    solidfloor = "Piso solido — suporta peso.",
    solidtrans = "Solido mas transparente (vidro, grade).",
    taintedWater = "Agua contaminada.",
    TallHoppableN = "Pode ser escalado (cerca alta) — Norte.",
    TallHoppableW = "Pode ser escalado — Oeste.",
    vegitation = "Vegetacao (afeta visibilidade, forageamento).",
    WallN = "Parede na borda Norte.",
    WallNTrans = "Parede Norte transparente.",
    WallNW = "Parede de canto Norte-Oeste.",
    WallW = "Parede na borda Oeste.",
    WallWTrans = "Parede Oeste transparente.",
    water = "Contem agua.",
    WindowN = "Janela — borda Norte.",
    WindowW = "Janela — borda Oeste.",
    WallOverlay = "Overlay sobre parede (papel de parede, tinta).",
}

-- =============================================================================
-- FUNÇÃO UTILITÁRIA: Busca tooltip para uma chave em qualquer seção
-- =============================================================================

---@param chavePropriedade string Nome da propriedade a buscar
---@param secaoAtual string Identificador da seção onde a propriedade está (opcional)
---@return string|nil textoTooltip Descrição encontrada ou nil
function LKS_DebugTooltipData.buscarTooltip(chavePropriedade, secaoAtual)
    if not chavePropriedade then return nil end

    -- Busca na seção específica primeiro (prioridade)
    if secaoAtual then
        if secaoAtual:find("%[ID%]") and LKS_DebugTooltipData.identidade[chavePropriedade] then
            return LKS_DebugTooltipData.identidade[chavePropriedade]
        elseif secaoAtual:find("%[CTN%]") and LKS_DebugTooltipData.container[chavePropriedade] then
            return LKS_DebugTooltipData.container[chavePropriedade]
        elseif secaoAtual:find("%[EST%]") and LKS_DebugTooltipData.estado[chavePropriedade] then
            return LKS_DebugTooltipData.estado[chavePropriedade]
        elseif secaoAtual:find("%[FLG%]") and LKS_DebugTooltipData.flags[chavePropriedade] then
            return LKS_DebugTooltipData.flags[chavePropriedade]
        end
    end

    -- Busca nas propriedades de sprite (seção mais ampla)
    if LKS_DebugTooltipData.propriedadesSprite[chavePropriedade] then
        return LKS_DebugTooltipData.propriedadesSprite[chavePropriedade]
    end

    -- Busca nas flags como fallback
    if LKS_DebugTooltipData.flags[chavePropriedade] then
        return LKS_DebugTooltipData.flags[chavePropriedade]
    end

    return nil
end
