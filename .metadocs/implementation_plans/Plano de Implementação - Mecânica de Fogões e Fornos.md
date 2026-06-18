# Plano de Implementação — Mecânica de Fogões e Fornos (3 Tipos)

## Summary

Implementação completa da mecânica de fogões recategorizada em 3 tipos (Convencional, Antigo, Indução) com diferenciação de combustível, ignição, qualidade de comida e interação com o mundo. O fogão de indução é um item novo exclusivo do mod (craftável), colocável em cima de balcões. Sprites vanilla de fogões modernos também serão reclassificados como indução via tabela de sprites (seleção manual futura) — a **resistência elétrica é apenas uma variante visual do tipo Indução**, compartilhando exatamente a mesma mecânica (só eletricidade, só panela de metal, qualidade superior). O fogão convencional utiliza gás encanado (pré-corte) e botijões (pós-corte). O fogão antigo (`IsoFireplace`) já funciona no vanilla com combustível sólido.

**Referências**:
- Design: `documents/mecanica_fogoes_fornos.md`
- Pesquisa: `documents/pesquisa_fogoes_fase1.md`
- Driver existente: `common/media/lua/client/devices/LKS_Device_Cooking.lua`

---

## Fase 1B — Tabela de Classificação de Sprites

### Objetivo

Criar a tabela que mapeia sprites vanilla de `IsoStove` para os tipos do mod. Sprites modernos selecionados manualmente serão reclassificados como **indução** — a "resistência elétrica" não é um tipo separado, é apenas uma variante visual que usa **exatamente a mesma mecânica** do tipo Indução (só eletricidade, só panela de metal, colocável em balcão). Sprites não mapeados permanecem como convencional (gás).

### Proposed Changes

#### [NEW] `common/media/lua/shared/LKS_Cooking_SpriteClassification.lua`

```lua
--- Mapeamento de sprites vanilla para tipos de fogão do mod.
--- Sprites listados aqui são reclassificados de "convencional" (padrão) para indução.
--- Sprites NÃO listados permanecem como Convencional (gás).
LKS_Cooking_TiposPorSprite = {
    -- Fogão de indução (sprites vanilla modernos — seleção manual futura)
    -- ["appliances_cooking_01_XX"] = "inducao",
    -- ["appliances_cooking_01_YY"] = "inducao",
    -- Placeholders: o usuário selecionará os sprites específicos no futuro
}

--- Tipo padrão para IsoStove quando o sprite não está mapeado.
LKS_Cooking_TipoPadrao = "convencional"
```

#### [MODIFY] `common/media/lua/client/devices/LKS_Device_Cooking.lua`

- Ao processar um `IsoStove`, consultar `LKS_Cooking_TiposPorSprite` usando o nome do sprite.
- Se sprite mapeado como `"inducao"` → aplicar mecânica de indução (só eletricidade, só metal).
- Se não mapeado → tipo convencional (gás).

---

## Fase 2 — Fogão Convencional com Gás Encanado

### Objetivo

Fazer os fogões `IsoStove` existentes no mapa funcionarem com **gás encanado** (pré-corte de utilidades) como fonte de combustível primária, em vez de depender exclusivamente de eletricidade. Após o corte, o fogão convencional requer botijão (Fase 5) ou fonte de calor manual.

### Proposed Changes

#### [MODIFY] `common/media/lua/client/devices/LKS_Device_Cooking.lua`

1. **Refatorar verificação de energia**:
   - Atualmente o driver verifica apenas `isPowered()` (eletricidade).
   - Adicionar lógica de **fonte de combustível múltipla**: gás encanado OU eletricidade OU botijão conectado.
   - Criar função `verificarFonteEnergia(objetoEletrico)`:
     ```lua
     -- Retorna: { tipo = "gas_encanado"|"eletricidade"|"botijao"|nil, disponivel = boolean }
     ```

2. **Implementar check de gás encanado**:
   - Reaproveitar a lógica de `hasWaterPiped()` / corte de utilidades do vanilla.
   - Verificar se o dia de jogo atual é anterior ao dia de corte de gás (sandbox option nova).
   - Se gás encanado disponível → fogão funciona sem eletricidade.

3. **Adaptar menu de contexto**:
   - Se tem gás encanado: mostrar opções de Ligar/Desligar normalmente.
   - Se não tem gás encanado E não tem eletricidade E não tem botijão: mostrar opção desabilitada com tooltip explicativo.
   - Adicionar verificação de **fonte de calor manual** no inventário do jogador quando não há acendedor elétrico (pós-corte de eletricidade).

#### [NEW] `common/media/lua/shared/LKS_GasEncanado_Config.lua`

- Definir constantes e sandbox options para o sistema de gás:
  - `GasShutoffDay` — dia de corte do gás encanado (padrão: mesmo dia da água ou configurável separado)
  - `GasEnabled` — flag master para ativar/desativar mecânica de gás
- Manter alinhamento com o padrão de configuração existente em `LKS_EletricidadeConstrucao_Config.lua`.

#### [MODIFY] `42.15/sandbox-options.txt` (ou equivalente)

- Adicionar opções de sandbox:
  - `LKS_EletricidadeConstrucao.GasShutoffDay` — integer (padrão: -1 = mesmo que água)
  - `LKS_EletricidadeConstrucao.GasEnabled` — boolean (padrão: true)

#### [MODIFY] `common/media/lua/shared/Translate/PTBR/IG_UI.json` e `EN/IG_UI.json`

- Chaves de tradução para tooltips de gás:
  - `IGUI_LKS_GasEncanadoDisponivel`
  - `IGUI_LKS_GasEncanadoCortado`
  - `IGUI_LKS_RequerFonteCalor`
  - `IGUI_LKS_RequerGasOuEletricidade`
  - `Sandbox_LKS_GasShutoffDay`
  - `Sandbox_LKS_GasEnabled`

### Ignição — Verificação de Fonte de Calor

Quando não há eletricidade (acendedor piezoelétrico indisponível), o jogador precisa de uma fonte de calor para acender o fogão a gás:

```lua
--- Verifica se o jogador possui qualquer item com tag START_FIRE ou tipo Lighter/Matches.
--- @param jogador IsoPlayer
--- @return boolean, string|nil (temFonte, nomeItem)
local function verificarFonteCalorInventario(jogador)
    -- Busca por ItemTag.START_FIRE
    -- Busca por tipos: "Lighter", "Matches", "LighterDisposable", "LighterBBQ", "Lighter_Battery"
    -- Busca por item novo do mod: "LKS_AcendedorImprovisado"
end
```

### Regras de negócio

- Gás encanado ativo + eletricidade ativa → acendedor automático (sem consumir item)
- Gás encanado ativo + sem eletricidade → requer fonte de calor manual (consome 1 uso)
- Sem gás encanado + sem botijão → fogão **não funciona** (independente de eletricidade)
- Eletricidade sozinha (sem gás/botijão) → fogão **não funciona** (exceto se for indução)

---

## Fase 3 — Fogão Antigo (Lenha/IsoFireplace)

### Objetivo

Garantir que o driver LKS reconheça `IsoFireplace` (fogões a lenha, lareiras com container `woodstove`) e aplique a mecânica de qualidade de comida com chance de queimar.

### Proposed Changes

#### [MODIFY] `common/media/lua/client/devices/LKS_Device_Cooking.lua`

1. **Expandir `recipientesAceitos`**:
   ```lua
   recipientesAceitos = {"stove", "microwave", "woodstove", "fireplace"}
   classesJava = {"IsoStove", "IsoMicrowave", "IsoFireplace"}
   ```

2. **Diferenciar comportamento por tipo**:
   - `IsoFireplace` / `woodstove`: aplicar mecânica de chance de queimar (10% - Cooking%).
   - Não verificar `isPowered()` para `IsoFireplace` — funciona com combustível sólido.
   - Menu de contexto: validar que tem combustível adicionado e fonte de calor.

3. **Mecânica de gases tóxicos**:
   - Verificar se `IsoFireplace` está em ambiente fechado (mesma lógica de geradores vanilla).
   - Se fechado e ativo: aplicar dano de toxicidade progressivo ao jogador.

#### [NEW] `common/media/lua/shared/LKS_CozinhaAntiga_Logica.lua` (ou integrado no driver)

- Função `calcularChanceQueimar(nivelCooking)`:
  ```lua
  return math.max(0, 10 - nivelCooking)  -- 10% base, -1% por nível
  ```
- Função `verificarAmbienteFechado(quadrado)`: reutilizar lógica vanilla de geradores.

### Regras de negócio

- `IsoFireplace` com combustível + fonte de calor → funciona
- Sem combustível → não funciona (vanilla já gerencia isso)
- Ambiente fechado + ativo → gases tóxicos (mesma mecânica de gerador)
- Chance de queimar: 10% - nível de Cooking (mínimo 0%)

---

## Fase 4 — Fogão de Indução (Item Novo)

### Objetivo

Criar o fogão de indução como **item novo do mod**, colocável em cima de balcões/superfícies. Funciona exclusivamente com eletricidade. Produz comida de qualidade superior.

### Proposed Changes

#### [NEW] `common/media/scripts/items_lks_cooking.txt`

Definição do item:

```
item LKS_FogaoInducao
{
    DisplayName = Fogão de Indução,
    DisplayCategory = Appliance,
    Type = Normal,
    Weight = 5.0,
    Icon = LKS_FogaoInducao,
    WorldStaticModel = LKS_FogaoInducao,
    PlaceMultipleOnTop = true,
    CanPlaceOnTop = true,
    IsCookable = false,
    Tooltip = Tooltip_LKS_FogaoInducao,
    Tags = base:hasmetal;base:smeltablesteellarge,
}
```

> Nota: `CanPlaceOnTop = true` / `PlaceMultipleOnTop = true` são as propriedades que permitem colocar em cima de balcões. Pesquisar exato nome da propriedade no PZ B42 — pode ser `Surface`, `PlaceOnSurface` ou via tileset properties.

#### [NEW] `common/media/scripts/recipes_lks_cooking.txt`

Receita de craft:

```
craftRecipe MakeLKS_FogaoInducao
{
    category = Electrical,
    xpAward = Electrical:25,
    time = 300,
    needToBeLearn = true,
    inputs
    {
        item 3 Base.SheetMetal,
        item 8 Base.Screws,
        item 1 Base.BlowTorch,
        item 1 LKS.Bobina,
        item 2 Base.Wire,
        item 1 Base.ElectronicsScrap,
    },
    outputs
    {
        item 1 LKS.LKS_FogaoInducao,
    },
}
```

#### [NEW] `common/media/scripts/items_lks_components.txt`

Itens novos (componentes):

```
item Bobina
{
    DisplayName = Bobina Elétrica,
    DisplayCategory = Electronics,
    Type = Normal,
    Weight = 0.5,
    Icon = LKS_Bobina,
    WorldStaticModel = LKS_Bobina,
    MetalValue = 10.0,
    Tags = base:hasmetal,
}
```

#### [NEW] Revista de aprendizado de receita

```
item LKS_RevistaEletricaInducao
{
    DisplayName = Revista: Cooktops Modernos,
    DisplayCategory = SkillBook,
    Type = Literature,
    Weight = 0.3,
    Icon = LKS_RevistaEletrica,
    TeachRecipe = MakeLKS_FogaoInducao,
    Tags = base:media,
}
```

#### [MODIFY] `common/media/lua/client/devices/LKS_Device_Cooking.lua`

1. **Adicionar tipo `"induction"` ao driver**:
   ```lua
   recipientesAceitos = {"stove", "microwave", "woodstove", "fireplace", "induction"}
   ```

2. **Lógica específica de indução**:
   - Verificar `isPowered()` obrigatoriamente (sem alternativa de gás/calor manual).
   - Verificar se contém **panelas de metal** antes de cozinhar:
     ```lua
     local function verificarPanelaMetal(containerInventario)
         -- Usa mesma lógica de verificarPresencaMetal() mas invertida:
         -- retorna true se TODOS os itens cookable são de metal
     end
     ```
   - Se não tem panela de metal: fogão não aquece (sem mensagem — jogador descobre sozinho).

3. **Qualidade de comida**:
   - Comida cozida em indução: qualidade Boa (padrão) ou Excelente (Cooking 10).
   - Nunca queima (chance 0% independente do nível).

4. **Aprendizado automático por skill**:
   - Hook em `Events.LevelPerk` para desbloquear receita ao atingir Elétrica 5.

5. **Aprendizado por desmontagem**:
   - Hook para contar fogões de indução desmontados.
   - Se Elétrica ≥ 2 e desmontou 2: desbloqueia receita.
   - Se Elétrica = 1: desmonta mas não aprende.

#### [NEW] Assets (placeholders iniciais)

- `common/media/ui/LKS_FogaoInducao.png` — ícone de inventário (placeholder)
- `common/media/textures/LKS_FogaoInducao_Item.png` — sprite de mundo (placeholder)
- `common/media/ui/LKS_Bobina.png` — ícone bobina (placeholder)
- `common/media/ui/LKS_RevistaEletrica.png` — ícone revista (placeholder)

### Propriedade de colocação em superfície

O fogão de indução deve ser **colocável em cima de balcões** (como o modelo cooktop das imagens de referência). Pesquisa indica que isso requer:

- Definir no tileset/sprite as propriedades `Surface` e posicionamento
- Ou usar o sistema de `Moveables` com `CanPlaceOnTop`
- Validar exatamente qual propriedade o PZ B42 usa para itens em bancada

> **Pesquisa adicional necessária**: Verificar como itens como "TV portátil", "rádio" e "microondas" são definidos para ficarem em cima de mesas no jogo base. Replicar a mesma abordagem.

### Regras de negócio

- Requer eletricidade obrigatória (rede ou gerador)
- Sem eletricidade → não funciona, sem alternativa
- Só aquece panelas de metal → sem aviso, não aquece outros materiais
- Qualidade: Boa (padrão), Excelente com Cooking 10
- Nunca queima comida (chance = 0%)
- Craftável após aprender receita (revista, Elétrica 5, ou desmontar 2)
- Colocável em cima de balcão/bancada/mesa

---

## Fase 5 — Botijão de Gás (Pós-Corte)

### Objetivo

Implementar os 2 tipos novos de botijão (15kg e 45kg) e a mecânica de conexão ao fogão convencional com mangueira.

### Proposed Changes

#### [NEW] `common/media/scripts/items_lks_gas.txt`

```
item LKS_Botijao15kg
{
    DisplayName = Botijão de Gás 15kg,
    DisplayCategory = Material,
    Type = Drainable,
    Weight = 15.0,
    WeightEmpty = 5.0,
    Icon = LKS_Botijao15kg,
    UseDelta = 0.0001,
    UseWhileEquipped = false,
    UseWorldItem = true,
    cantBeConsolided = true,
    WorldStaticModel = LKS_Botijao15kg,
    KeepOnDeplete = true,
    Tags = base:hasmetal;base:smeltablesteellarge,
    CustomContextMenu = true,
}

item LKS_Botijao45kg
{
    DisplayName = Botijão de Gás 45kg,
    DisplayCategory = Material,
    Type = Drainable,
    Weight = 45.0,
    WeightEmpty = 15.0,
    Icon = LKS_Botijao45kg,
    UseDelta = 0.00005,
    UseWhileEquipped = false,
    UseWorldItem = true,
    cantBeConsolided = true,
    WorldStaticModel = LKS_Botijao45kg,
    KeepOnDeplete = true,
    Tags = base:hasmetal;base:smeltablesteellarge,
    CustomContextMenu = true,
}
```

#### [NEW] `common/media/lua/client/LKS_Botijao_ContextMenu.lua`

Menu de contexto para interação com botijões:

- **Instalar botijão**: Verifica itens no inventário (mangueira, 2 enforca-gatos, fita isolante, ferramenta de corte, alicate). Distância ≤ 2 tiles do fogão. Timed action.
- **Trocar botijão**: Verifica 1 enforca-gato novo + alicate. Substitui botijão vazio por cheio.
- **Desinstalar botijão**: Remove conexão completamente. Próxima vez requer instalação completa.

#### [NEW] `common/media/lua/shared/actions/LKS_Actions_InstalarBotijao.lua`

Timed action para instalação/troca/desinstalação do botijão.

#### [MODIFY] `common/media/lua/client/devices/LKS_Device_Cooking.lua`

- Integrar check de botijão conectado na função `verificarFonteEnergia()`.
- Consumir gás do botijão durante uso ativo do fogão (drenar `UsedDelta` por tempo).

### Mecânica de transporte

| Botijão | Mecânica | Implementação |
|---|---|---|
| 15kg | Carregar como gerador | Mesma lógica vanilla de carregamento de geradores |
| 45kg | Arrastar como corpo de zumbi | Mesma lógica vanilla de arrasto de corpos |

### Mecânica de vazamento (evento raro)

- Verificar skills ao instalar: soma Elétrica + Mecânica + Cooking < 6 E alguma ≤ 1
- Se condição atendida: 1% de chance de flag `vazamentoGasPendente`
- Próximo uso: aviso de gás → 10 segundos → explosão
- Dano conforme proximidade (fatal/50%/pânico)

### Locais de spawn

Configurar distribuição nos scripts de loot ou via procedural:
- 15kg: trailers, periferia, restaurantes, food trucks, camping
- 45kg: caminhões, fábricas, garagens de luxo, distribuidoras, hospitais

---

## Fase 6 — Sistema de Qualidade de Comida

### Objetivo

Criar camada de qualidade sobre o sistema vanilla de cozimento, com 4 níveis que afetam buffs/debuffs do jogador.

### Proposed Changes

#### [NEW] `common/media/lua/shared/LKS_QualidadeComida.lua`

Sistema central de qualidade:

```lua
LKS_QualidadeComida = {
    NIVEIS = {
        RUIM = { id = 1, nome = "Ruim", multiplicadorBuff = -1.0 },
        NORMAL = { id = 2, nome = "Normal", multiplicadorBuff = 0 },
        BOA = { id = 3, nome = "Boa", multiplicadorBuff = 1.0 },
        EXCELENTE = { id = 4, nome = "Excelente", multiplicadorBuff = 2.0 },
    }
}
```

- Calcular qualidade baseada em: tipo de fogão + nível Cooking + status de limpeza + pré-aquecimento
- Aplicar buffs/debuffs ao consumir comida via hook em `Events.OnEat` ou equivalente

#### [NEW] `common/media/lua/shared/LKS_LimpezaFogao.lua`

Sistema de status de limpeza:

- 5 níveis: Brilhando → Limpo → Sujo → Muito Sujo → Imundo
- Degrada a cada cozimento
- Muito Sujo/Imundo: chance de comida estragada
- Limpar: pano + produto de limpeza (Brilhando) ou só água (Limpo)

---

## Fase 8 — Acendedor Improvisado (Pilha + Palha de Aço)

### Objetivo

Criar item craftável consumível "Acendedor Improvisado" com identidade visual e sonora própria.

### Proposed Changes

#### [NEW] `common/media/scripts/items_lks_firestarter.txt`

```
item LKS_AcendedorImprovisado
{
    DisplayName = Acendedor Improvisado,
    DisplayCategory = FireSource,
    Type = Normal,
    Weight = 0.2,
    Icon = LKS_AcendedorImprovisado,
    Tags = base:startfire,
    Tooltip = Tooltip_LKS_AcendedorImprovisado,
}
```

#### [NEW] Receita de craft

```
craftRecipe MakeLKS_AcendedorImprovisado
{
    category = Survivalist,
    time = 60,
    inputs
    {
        item 1 Base.Battery [minCondition:20],
        item 1 Base.SteelWool,
    },
    outputs
    {
        item 1 LKS.LKS_AcendedorImprovisado,
    },
    onGiveXP = function(recipe, ingredients, result, player)
        -- Drenar 20% da pilha (sem destruir)
        -- Destruir a palha de aço (já consumida pelo recipe)
    end,
}
```

#### [NEW] Assets

- `common/media/ui/LKS_AcendedorImprovisado.png` — ícone (placeholder)
- Som: arquivo de áudio de ignição rápida (*fssshh*) — placeholder ou extrair do jogo

> **Pesquisa adicional**: Verificar se `SteelWool` (palha de aço) existe como item no vanilla. Se não, será item novo.

---

## Fase 9 — Modo Bateria para Indução

### Objetivo

Permitir alimentação do fogão de indução via 2 baterias de carro + inversor + mini transformador quando não há rede elétrica.

### Proposed Changes

#### [NEW] `common/media/scripts/items_lks_electrical.txt`

Itens novos (se confirmado que não existem no vanilla):

```
item LKS_InversorCorrente { ... }
item LKS_MiniTransformador { ... }
```

#### [MODIFY] `common/media/lua/client/devices/LKS_Device_Cooking.lua`

- Para fogão de indução: se não tem `isPowered()`, verificar se tem conjunto bateria+inversor+transformador conectado.
- Drenar baterias por **tempo de uso** (não por cozimento).
- Quando baterias esgotam: fogão desliga.

---

## Interfaces e Traduções

### Chaves de tradução necessárias (todas as fases)

**PT-BR** (`common/media/lua/shared/Translate/PTBR/IG_UI.json`):
- `IGUI_LKS_GasEncanadoDisponivel`
- `IGUI_LKS_GasEncanadoCortado`
- `IGUI_LKS_RequerFonteCalor`
- `IGUI_LKS_RequerGasOuEletricidade`
- `IGUI_LKS_RequerEletricidade`
- `IGUI_LKS_BotijaoConectado`
- `IGUI_LKS_BotijaoVazio`
- `IGUI_LKS_InstalarBotijao`
- `IGUI_LKS_TrocarBotijao`
- `IGUI_LKS_DesinstalarBotijao`
- `IGUI_LKS_QualidadeComida_Ruim`
- `IGUI_LKS_QualidadeComida_Normal`
- `IGUI_LKS_QualidadeComida_Boa`
- `IGUI_LKS_QualidadeComida_Excelente`
- `IGUI_LKS_StatusLimpeza_*` (5 níveis)
- `IGUI_LKS_AvisoGasToxico`
- Sandbox options para gás

**EN** (`common/media/lua/shared/Translate/EN/IG_UI.json`):
- Equivalentes em inglês para todas as chaves acima.

---

## Test Plan

### Validações automatizadas

```bash
python tools/auditoria_mod.py validar-sintaxe
python tools/auditoria_mod.py auditar-traducoes --ignorar-nativas
python tools/auditoria_mod.py auditar-caminhos
python tools/gerar_luarc.py
```

### Teste manual por fase

**Fase 1B (Classificação de Sprites)**:
- Fogão com sprite mapeado como "inducao": comporta-se como indução (só eletricidade, só panela metal)
- Fogão com sprite NÃO mapeado: comporta-se como convencional (gás)
- Confirmar que resistência elétrica = indução (mesma mecânica, sprite diferente)

**Fase 2 (Gás encanado)**:
- Mundo novo, dia 1: fogão convencional funciona sem gerador (gás encanado)
- Avançar para dia 31+: fogão para de funcionar (gás cortado)
- Ter isqueiro no inventário + gás: fogão liga com consumo do isqueiro
- Sem isqueiro + sem eletricidade + com gás: fogão não liga

**Fase 3 (Antigo)**:
- Fogão a lenha com lenha + isqueiro: funciona
- Cozinhar 100x e verificar que ~10% queimam (Cooking 0)
- Cozinhar com Cooking 10: 0% queimam
- Usar em ambiente fechado: gases tóxicos

**Fase 4 (Indução)**:
- Colocar em balcão: funciona
- Sem eletricidade: não liga
- Com eletricidade + panela de metal: cozinha normalmente
- Com eletricidade + panela de cerâmica: não aquece, sem mensagem
- Cooking 10: toda comida sai Excelente
- Craft: aprender por revista, Elétrica 5, ou desmontar 2

**Fase 5 (Botijões)**:
- Instalar com todos os itens: funciona
- Trocar com enforca-gato + alicate: funciona
- Desinstalar e tentar usar: não funciona (precisa reinstalar)
- Skills baixas (soma < 6, alguma ≤ 1): 1% chance de vazamento
- Vazamento → explosão após 10s com dano por zona

**Fase 6 (Qualidade)**:
- Fogão limpo + Cooking alto: comida Excelente com buffs
- Fogão Imundo: chance de estragar
- Verificar buffs/debuffs ao consumir

---

## Assumptions

- Sprites e assets finais serão criados manualmente pelo usuário. Placeholders usados durante implementação.
- Sprites vanilla de fogões modernos serão reclassificados como "resistência elétrica" — seleção manual futura pelo usuário na tabela `LKS_Cooking_TiposPorSprite`.
- Fogões de resistência elétrica e indução são colocáveis em balcão. O convencional e antigo são de chão.
- O sistema de gás encanado reutiliza a mesma janela temporal de corte de utilidades do vanilla (água).
- `IsoFireplace` já possui mecânica funcional de combustível sólido — não reimplementamos, apenas adicionamos camada de qualidade.
- O fogão de indução é um item novo que NÃO substitui nenhum `IsoStove` existente no mapa — é encontrado como loot ou craftado.
- A qualidade de comida (Fase 6) é uma camada **sobre** o sistema vanilla — não substitui o ciclo Uncooked → Cooked → Burned do engine.
- O biodigestor é mecânica independente e não faz parte deste plano.
- Quantidades de craft, valores de UseDelta e tempos serão ajustados na fase de balanceamento final.
- Sons customizados (Acendedor Improvisado, explosão de botijão) podem usar placeholders de sons vanilla existentes até criação dos assets finais.

---

## Ordem de Execução

| Passo | Fase | Dependência |
|---|---|---|
| 1 | Fase 1B — Tabela de classificação de sprites (Resistência Elétrica) | Nenhuma |
| 2 | Fase 2 — Gás encanado + ignição manual | Nenhuma |
| 3 | Fase 3 — IsoFireplace + chance de queimar | Fase 2 (compartilha lógica de fonte de calor) |
| 4 | Fase 4 — Item indução + craft + colocação em balcão | Fase 1B (compartilha lógica de tipo por sprite) |
| 5 | Fase 5 — Botijões + instalação + vazamento | Fase 2 (integra no check de combustível) |
| 6 | Fase 8 — Acendedor Improvisado | Nenhuma (item simples) |
| 6 | Fase 6 — Qualidade de comida | Fases 2+3+4 (precisa dos 3 tipos funcionando) |
| 7 | Fase 9 — Modo bateria indução | Fase 4 (precisa indução funcionando) |
