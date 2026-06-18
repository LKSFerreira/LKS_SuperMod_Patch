# Mecânica de Fogões e Fornos — Design de Implementação

Este documento descreve a proposta de mecânica realista para fogões e fornos no LKS SuperMod Patch. O objetivo é transformar cada tipo de aparelho de cozinha em uma experiência distinta, com regras de funcionamento, combustível, ignição e qualidade de comida próprias.

## Visão Geral

O mod vanilla do Project Zomboid trata todos os fogões como um único tipo funcional (`IsoStove`). Esta proposta recategoriza os aparelhos em 3 tipos com mecânicas independentes, criando progressão de gameplay e escolhas significativas para o jogador no pós-apocalipse.

| Tipo | Combustível primário | Ignição | Eletricidade | Qualidade da comida | Complexidade |
|---|---|---|---|---|---|
| **Convencional** | Gás (encanado ou botijão) | Elétrica ou fonte de calor manual | Opcional (acendedor) | Boa | Média |
| **Antigo** | Lenha / combustível sólido | Fonte de calor manual obrigatória | Nenhuma | Normal (chance de queimar) | Baixa |
| **Indução** | Nenhum | Automática | Obrigatória | Boa a Excelente | Alta |

---

## 1. Fogão Convencional (Gás)

### Descrição

Fogão residencial padrão encontrado na maioria das casas. Funciona com gás encanado (antes do corte de utilidades) ou botijão de gás (após o corte). Possui bocas de fogão e forno embutido. É o tipo mais versátil e comum no mapa.

### Fonte de combustível

#### Gás encanado (pré-corte)

- Funciona da mesma forma que a **água encanada** no vanilla: fornecimento ilimitado até o dia de corte de utilidades (padrão: 30 dias in-game, configurável por sandbox).
- **Implementação técnica**: Reaproveitar a mesma lógica de `hasWaterPiped()` / `getFluidAmount()` que já existe para água. O gás encanado é conceitualmente idêntico — um recurso de infraestrutura com corte programado.
- Após o corte do gás encanado, o jogador precisa de uma fonte alternativa.

#### Botijão de gás (pós-corte)

Após o corte do gás encanado, o jogador precisa de botijões como fonte alternativa. Existem **3 tipos** com mecânicas de transporte distintas:

##### Botijão Vanilla (Pequeno / Portátil)

- Já existe no jogo base.
- **Cabe no inventário** do jogador.
- Capacidade pequena (a definir no balanceamento).
- Encontrado em: casas comuns, cozinhas de apartamentos, trailers.

##### Botijão de 15kg (Residencial)

- **Criado pelo mod** — item novo.
- **NÃO cabe no inventário** — requer transporte físico.
- **Mecânica de transporte**: Idêntica ao carregamento de geradores no vanilla (o jogador pega, caminha lento, coloca no chão).
- **Recarregamento**: Mesma penalidade de peso e mecânica dos geradores — o jogador precisa encontrar outro botijão cheio, não é possível recarregar um vazio sem infraestrutura (futura mecânica de postos de gás ou biodigestor).
- Capacidade moderada (define duração em horas — fase de balanceamento).
- **Locais de spawn**:
  - Trailers e motorhomes
  - Casas de periferia (área de serviço, garagem)
  - Restaurantes e lanchonetes
  - Churrasquerias e food trucks
  - Acampamentos e áreas de camping

##### Botijão de 45kg (Comercial/Industrial)

- **Criado pelo mod** — item novo.
- **NÃO cabe no inventário** — requer transporte pesado.
- **Mecânica de transporte**: Idêntica ao carregamento de **corpos de zumbi** no vanilla (arrasto no chão, extremamente lento, consome stamina).
- **Recarregamento**: Mesmo princípio — encontrar outro cheio ou futura integração com biodigestor.
- Capacidade alta (dura muito mais que os outros — fase de balanceamento).
- **Locais de spawn**:
  - Caminhões de carga (baú traseiro)
  - Garagens de residências de alto padrão
  - Fábricas e galpões industriais
  - Restaurantes industriais e refeitórios de prédios comerciais
  - Depósitos de gás (postos, distribuidoras)
  - Hospitais e laboratórios (equipamento de calor)

##### Tabela comparativa de botijões

| Tipo | Capacidade | Transporte | Inventário | Raridade | Onde encontrar |
|---|---|---|---|---|---|
| Vanilla (pequeno) | Baixa | Mão / inventário | ✅ Sim | Comum | Casas, apartamentos |
| 15kg (residencial) | Média | Carregar (mecânica de gerador) | ❌ Não | Moderada | Trailers, periferia, restaurantes |
| 45kg (comercial) | Alta | Arrastar (mecânica de corpo) | ❌ Não | Rara | Caminhões, fábricas, garagens de luxo |

##### Conexão ao fogão

- O jogador conecta o botijão ao fogão mediante uma **instalação manual** com itens específicos.
- **Distância máxima**: Até **2 tiles** de distância entre botijão e fogão (comprimento da mangueira).
- **Itens necessários** (todos existem no vanilla):
  - 1 - Mangueira de borracha
  - 2 - Enforca-gato (abraçadeira)
  - 1 - Fita isolante
  - 1 - Ferramenta de corte (faca ou canivete)
  - 1 - Alicate
- A instalação consome tempo (timed action) e o resultado é uma conexão persistente.
- O gás é consumido gradualmente durante o uso do fogão.
- Quando o botijão esvazia, o fogão para de funcionar até um novo botijão ser conectado.

**Ações disponíveis após instalação**:

| Ação | Descrição | Itens necessários |
|---|---|---|
| **Trocar botijão** | Substitui o botijão vazio por um cheio reaproveitando a mangueira existente | 1 enforca-gato (novo) + 1 alicate |
| **Desinstalar botijão** | Remove completamente o botijão e a mangueira — desfaz a instalação | Apenas as mãos (ou alicate para facilitar) |

- **Trocar** é a opção econômica: a mangueira e a fita isolante já estão no lugar, só precisa trocar a abraçadeira do lado do botijão novo.
- **Desinstalar** remove tudo. Para usar um botijão novamente no futuro, será necessária uma **nova instalação completa** (todos os 5 itens originais).
- Na instalação original são gastos **2 enforca-gatos** (um em cada ponta da mangueira). Na troca, apenas **1** (lado do botijão novo).

#### Biodigestor (mecânica futura)

- O jogo permite criação de animais (farming).
- Um **biodigestor** é uma construção craftável que converte resíduos orgânicos (esterco de animais, restos de comida) em biogás.
- O biogás é armazenado em um reservatório e pode ser conectado ao encanamento de gás da construção, restaurando o fornecimento de gás encanado pós-corte.
- Funciona de forma análoga à caixa d'água no telhado: o biodigestor produz gás → o gás flui para os aparelhos conectados via tubulação.
- **Requisitos de craft**: Farming + Carpintaria (níveis a definir).
- **Escopo**: Mecânica complexa que requer documentação e arquivo de design próprio. Não será implementada junto com os fogões — será um projeto separado para garantir qualidade e funcionalidade.

### Ignição

O fogão convencional precisa de uma **faísca** para acender. Duas fontes possíveis:

#### Acendedor elétrico do fogão

- Quando a residência possui eletricidade (rede pública ou gerador conectado), o fogão usa seu próprio acendedor piezoelétrico integrado.
- Não consome itens. Funciona automaticamente ao ligar o fogão.

#### Fonte de calor manual

O jogador pode acender o fogão manualmente usando qualquer fonte de calor do inventário. Todos os itens abaixo **já existem no vanilla**, exceto a Pilha + Palha de aço:

| Fonte de calor | Disponibilidade | Reutilizável | Notas |
|---|---|---|---|
| Isqueiro | Comum em casas e corpos | Sim (com combustível) | Fonte padrão do vanilla |
| Fósforos (caixa) | Comum | Consumível | Cada uso gasta 1 fósforo |
| Acendedor de magnésio | Raro (lojas de camping) | Sim (durabilidade) | Funciona mesmo molhado |
| **Pilha + Palha de aço** | Craftável | Consumível | **Mecânica nova do mod** |

> **Pesquisa necessária**: Investigar se existem mais fontes de calor no vanilla (tocha, drill, notched plank, etc.) que poderiam ser aceitas como ignição para fogões.

##### Pilha + Palha de aço (mecânica nova)

- **Receita**: 1 Pilha (mínimo 20% de carga) + 1 Palha de Aço de Cozinha
- **Processo**: Ao fechar os polos da pilha com a palha de aço, o curto-circuito gera uma fagulha.
- **Resultado**: A palha de aço é consumida (destruída). A pilha perde 20% de carga.
- **Requisito**: Nenhuma skill específica — qualquer jogador pode executar.
- **Lore**: Técnica real de sobrevivência amplamente documentada.

### Manutenção

- Sofre **desgaste leve** com o uso prolongado.
- Após determinado número de usos, a eficiência diminui (tempo de cozimento aumenta).
- Pode ser reparado com ferramentas básicas (chave inglesa + peças).
- A falta de manutenção **não** causa incêndio, apenas reduz eficiência.

### Qualidade da comida

- Produz comida de qualidade **Boa** como padrão.
- A qualidade é afetada pelo nível de Cooking do jogador.
- Sem risco elevado de queimar comida em operação normal.

### Regras especiais

- **Plástico no fogão**: Se o jogador colocar itens de plástico (garrafas, recipientes plásticos) dentro do fogão convencional enquanto aceso, o material é **destruído** e gera fumaça tóxica (dano de saúde leve).
- **Sem panela**: Cozinhar diretamente na boca sem panela/frigideira tem consequências, mas o jogador precisa descobrir sozinho.
- **Easter egg — Manual do Fogão**: Um item raro encontrável no mundo que documenta dicas, truques, todas as mecânicas ocultas e inclui uma **receita especial exclusiva** que aplica todos os conceitos (pré-aquecimento + panela correta + fogão limpo). Essa receita produz uma comida única com buff especial.

---

## 2. Fogão/Forno Antigo (Lenha)

### Descrição

Fogão rústico a lenha ou forno de tijolo. Encontrado em fazendas, cabanas rurais e construções antigas. Não requer eletricidade nem gás. É a opção mais primitiva e resiliente.

### Fonte de combustível

- **Combustível sólido**: Lenha, tábuas, galhos, papel, livros, revistas — qualquer material inflamável aceito pelo engine do PZ.
- O combustível é consumido ao longo do tempo. A duração depende do tipo e quantidade:
  - Troncos/lenha: Horas de duração
  - Tábuas: Duração moderada
  - Papel/livros: Curta duração

> **Pesquisa necessária**: Verificar se o vanilla já implementa a mecânica de combustível sólido para fogões a lenha. Se sim, reaproveitar. Se não, implementar baseado na mecânica de fogueiras (`campfire`).

### Ignição

- Requer **obrigatoriamente** uma fonte de calor manual (isqueiro, fósforos, palha de aço + pilha, etc.).
- **Nunca** usa acendedor elétrico — não possui componente elétrico.

### Manutenção

- Quase **nunca** precisa de manutenção.
- Durabilidade extremamente alta — construído para durar.
- Acúmulo de cinzas pode ser uma mecânica futura (reduz eficiência se não limpo).

### Qualidade da comida

- Produz comida de qualidade **Normal** como padrão.
- Possui **chance de queimar** a comida durante o processo de cozimento:
  - Chance base: **10%** por cozimento.
  - A cada nível de Cooking, a chance reduz em **1%** (Cooking 10 = 0% de chance).
  - Comida queimada passa para qualidade **Ruim/Estragada**.
  - O jogo vanilla já implementa um status de "queimando" após a etapa de cozimento — reutilizar essa mecânica.
- A irregularidade do calor da lenha justifica a variação de qualidade.

### Efeitos ambientais

- **Produz calor ao redor**: Aquece os tiles adjacentes. Pode ser usado como fonte de aquecimento no inverno.
- **Gases tóxicos**: Se utilizado em ambiente fechado (sem janela aberta ou sem estar ao lado de fora), produz monóxido de carbono.
  - **Implementação**: Mesma mecânica que os geradores vanilla — o jogo já calcula toxicidade de geradores em ambientes fechados.
  - O jogador precisa abrir janelas ou colocar o fogão em área ventilada.

### Vantagens estratégicas

- Funciona **sem eletricidade e sem gás** — ideal para fase tardia do jogo.
- Combustível abundante (árvores, mobília destruída, livros).
- Fonte de aquecimento dual (cozinha + calor).

### Regras especiais

- **Plástico no forno**: Assim como o convencional, materiais plásticos são destruídos e geram fumaça tóxica.

### Balanceamento (a definir)

| Parâmetro | Valor proposto | Notas |
|---|---|---|
| Duração de 1 tronco | ~2-3 horas in-game | Precisa de playtesting |
| Duração de tábuas | ~1-1.5 horas in-game | Precisa de playtesting |
| Duração de papel/livro | ~15-30 minutos in-game | Precisa de playtesting |
| Chance de queimar comida | 10-15% base | Reduz com Cooking skill |
| Raio de aquecimento | 3-5 tiles | Mesmo do sistema de aquecimento LKS |

---

## 3. Fogão/Forno por Indução (Inventado pelo Mod)

### Descrição

Fogão de indução eletromagnética — **mecânica exclusiva do LKS SuperMod Patch**, não existe no vanilla. Representa tecnologia moderna premium encontrada em residências de alto padrão. Funciona **exclusivamente com eletricidade** e produz a melhor qualidade de comida.

### Obtenção

#### Encontrar no mundo

- **Casas de alto padrão**: Boa chance de spawn em cozinhas de residências luxuosas.
- **Cabe no inventário** do jogador — peso equivalente ao de uma **bateria de carro** (referência de peso).

#### Craft

O jogador pode construir um fogão de indução se souber a receita.

**Como aprender a receita**:

| Método | Requisito | Notas |
|---|---|---|
| Ler revista de elétrica específica | Nenhum nível mínimo | Revista nova criada pelo mod |
| Atingir Elétrica nível 5 | Automático | Desbloqueia a receita sem revista |
| Desmontar 2 fogões de indução | Elétrica nível 2 (mínimo) | Com Elétrica 1, desmonta mas **não aprende** |

**Materiais de craft** (quantidades na fase de balanceamento):

| Material | Status |
|---|---|
| Placas de metal | Vanilla |
| Parafusos | Vanilla |
| Maçarico | Vanilla |
| Bobina | **Verificar se existe no vanilla — possivelmente item novo do mod** |
| Fio elétrico | Vanilla |
| Placa de circuito | Vanilla |

### Fonte de energia

#### Rede elétrica ou gerador

- Requer eletricidade ativa: rede pública (antes do corte) ou gerador conectado à construção via LKS_EletricidadeConstrucao.
- Consumo elétrico **moderado** (entre uma geladeira e uma secadora de roupas).

#### Modo de emergência (baterias)

Quando não há rede elétrica nem gerador disponível, o jogador pode improvisar alimentação usando:

| Componente | Quantidade | Onde encontrar | Status |
|---|---|---|---|
| Bateria de carro | 2 unidades | Veículos, oficinas mecânicas | Vanilla |
| Inversor de corrente | 1 unidade | Lojas de eletrônicos, galpões industriais | **Verificar se existe no vanilla — possivelmente item novo do mod** |
| Mini transformador | 1 unidade | Oficinas elétricas, armazéns | **Verificar se existe no vanilla — possivelmente item novo do mod** |

- O conjunto bateria + inversor + transformador fornece energia limitada ao fogão.
- As baterias são consumidas durante o uso (drenam carga por **tempo de uso**, não por cozimento).
- Duração total do modo emergência: a definir na fase de balanceamento.

### Ignição

- **Automática** — ligar o fogão de indução é instantâneo, sem faísca, sem combustível. Basta ter eletricidade.
- Sem componente de calor manual. Se não houver eletricidade (nem modo bateria), simplesmente não liga.

### Manutenção

- Manutenção **moderada** — circuitos eletrônicos são sensíveis.
- Pode requerer peças eletrônicas para reparo (placas de circuito, fios, solda).
- Se danificado e não reparado, para de funcionar completamente (diferente do convencional que apenas perde eficiência).

### Qualidade da comida

- Produz comida de qualidade **Boa a Excelente**.
- Controle preciso de temperatura = sem risco de queimar.
- **Regra especial Cooking 10**: Se o jogador possui Cooking nível 10 (máximo), **todas** as comidas produzidas em fogão de indução terão:
  - Qualidade Excelente garantida
  - Buffs máximos aplicados
  - Remoção de debuffs do jogador (tristeza, tédio, estresse reduzidos)

### Restrição de panelas

- **Apenas panelas de metal** funcionam no fogão de indução.
- Panelas de cerâmica, vidro ou plástico **não funcionam**.
- Se o jogador tentar usar recipiente incompatível, o fogão simplesmente **não aquece** — sem aviso, sem explicação. O jogador precisa descobrir sozinho por que não funciona.
- **Easter egg**: Um item raro chamado **"Manual do Fogão de Indução"** pode ser encontrado no mundo. Ao ler, o jogador aprende que apenas panelas de metal são compatíveis. Sem o manual, é tentativa e erro.
- Qualquer material que não seja metal simplesmente **não sofre efeito** — sem aquecimento, sem destruição, sem dano. A indução só gera calor em metal.

### Consumo elétrico

| Modo | Consumo proposto | Notas |
|---|---|---|
| Standby (ligado, sem cozinhar) | Negligível | Consumo mínimo |
| Cozinhando (boca ativa) | Moderado | A definir em unidades do jogo na fase de balanceamento |
| Forno ativo | Alto | Impacta strain do gerador — a definir em unidades |

---

## 4. Mecânicas Transversais (Todos os Tipos)

### Interação com objetos incompatíveis

| Material no fogão | Convencional (gás) | Antigo (lenha) | Indução (elétrico) |
|---|---|---|---|
| Plástico | Destruído + fumaça tóxica | Destruído + fumaça tóxica | Nada acontece (sem chama) |
| Metal (panelas) | Funciona normalmente | Funciona normalmente | Funciona normalmente |
| Cerâmica/vidro | Funciona normalmente | Funciona normalmente | **Não aquece** |

### Detecção de metal no micro-ondas

A mecânica de detecção de metais no micro-ondas **existe** no driver `LKS_Device_Cooking.lua` (função `verificarPresencaMetal()` — usa `item:isMetal()` e `item:getMetalValue()`). **Validar in-game** se funciona corretamente antes de reutilizar como referência para a lógica inversa do fogão de indução (micro-ondas rejeita metal, indução exige metal).

> **Ação pendente**: Criar um documento de **mecânicas já implementadas** no mod para evitar esquecimento do que existe ou não. Referência: `.metadocs/` ou `documents/`.

### Futura integração com sistema de Cooking

Quando o sistema de qualidade de comida for implementado:

| Qualidade | Efeito no jogador | Aparelho que produz |
|---|---|---|
| Ruim/Estragada | Debuffs (náusea, unhappiness) | Antigo (comida queimada) |
| Normal | Sem efeito especial | Antigo (sucesso), qualquer sem skill |
| Boa | Buffs leves (happiness, reduz stress) | Convencional, Indução |
| Excelente | Buffs fortes (happiness, remove debuffs) | Indução + Cooking 10 |

---

## 5. Reutilização de Mecânicas Existentes

### O que já existe e pode ser reaproveitado

| Mecânica | Origem | Reutilização proposta |
|---|---|---|
| Corte de utilidades (água/luz) | Vanilla PZ | Modelo para corte de gás encanado |
| Encanamento via coletor de chuva | Vanilla PZ | Modelo para conexão de botijão/biodigestor |
| Toxicidade de geradores em ambiente fechado | Vanilla PZ | Gases do forno a lenha em recinto fechado |
| Fogueira e combustível sólido | Vanilla PZ | Mecânica de combustível do forno antigo |
| Detecção de metal no micro-ondas | LKS Mod (atual) | Validação de panela no fogão de indução |
| Rede elétrica de construções | LKS Mod (atual) | Alimentação do fogão de indução |
| Sistema de aquecimento | LKS Mod (atual) | Calor emitido pelo forno antigo |

### O que precisa ser pesquisado

- [ ] Botijões de gás no vanilla: Existem? São de mod? Quais mecânicas possuem?
- [ ] Fogão a lenha no vanilla: O `IsoStove` já diferencia tipos? Existe `IsoFireplace` separado?
- [ ] Propriedades de sprite dos fogões: Quais sprites do jogo correspondem a cada tipo proposto?
- [ ] Sistema de skills: Como o Cooking skill afeta receitas atualmente?
- [ ] Baterias de carro: Como o jogo expõe carga/drenagem via API Lua?

---

## 6. Mecânicas Adicionais

### Pré-aquecimento do forno (bônus opcional)

- **Não é obrigatório** para cozinhar. O jogador pode usar o forno diretamente.
- Quando implementarmos o sistema de receitas de culinária, receitas que **exigem pré-aquecimento** fornecerão um **bônus adicional nos buffs** da comida se o jogador tiver pré-aquecido o forno antes.
- Sem pré-aquecimento em receita que pede: a comida sai Normal em vez de Boa. Com pré-aquecimento: Boa com bônus extra.
- Escopo: Será implementado junto com a reformulação da mecânica de culinária, não antes.

### Vazamento de gás (evento raro com consequências graves)

Ocorre **apenas** quando **duas condições** são atendidas simultaneamente:
1. **Soma** de Elétrica + Mecânica + Cooking **< 6** (menor que 6)
2. **E** pelo menos uma das 3 skills é **≤ 1**

Se **todas** as skills forem ≥ 2, ou se a soma for ≥ 6, o evento **nunca** acontece.

Exemplos:
- Elétrica 0, Mecânica 2, Cooking 2 (soma 4, tem ≤1) → ⚠️ risco ativo
- Elétrica 1, Mecânica 1, Cooking 1 (soma 3, tem ≤1) → ⚠️ risco ativo
- Elétrica 1, Mecânica 2, Cooking 2 (soma 5, tem ≤1) → ⚠️ risco ativo
- Elétrica 0, Mecânica 0, Cooking 0 (soma 0, tem ≤1) → ⚠️ risco ativo
- Elétrica 2, Mecânica 2, Cooking 2 (soma 6, nenhum ≤1) → ✅ sem risco
- Elétrica 2, Mecânica 2, Cooking 1 (soma 5, tem ≤1) → ⚠️ risco ativo
- Elétrica 3, Mecânica 2, Cooking 1 (soma 6, tem ≤1) → ✅ sem risco (soma ≥ 6)
- Elétrica 4, Mecânica 1, Cooking 0 (soma 5, tem ≤1) → ⚠️ risco ativo
- Elétrica 3, Mecânica 3, Cooking 2 (soma 8, nenhum ≤1) → ✅ sem risco

**Chance de ativação**: 1% por conexão realizada nestas condições.

**Sequência do evento**:
1. Ao conectar, uma flag invisível é adicionada ao fogão (`vazamentoGasPendente = true`).
2. Na **próxima vez** que o jogador tentar usar o fogão, uma mensagem de gás tóxico surge na tela.
3. Após **10 segundos** do aviso, o botijão explode na área.

**Tabela de dano por proximidade**:

| Posição do jogador | Dano | Efeito adicional |
|---|---|---|
| Ao lado do botijão (adjacente) | **Fatal** | Morte instantânea ou quase-morte |
| No mesmo cômodo | **50% da vida** | Pânico por **7 dias** |
| Na área visual da explosão (outro cômodo, janela) | Nenhum dano físico | Pânico por **1 dia** |

- Jogadores com skills mais altas **nunca** ativam essa mecânica — o evento só é possível quando soma < 6 e alguma skill ≤ 1.
- A explosão também danifica tiles ao redor (incêndio, destruição de mobília).

### Limpeza do fogão (afeta qualidade da comida)

A limpeza **não** causa incêndio nem afeta funcionamento — apenas impacta a **somatória de buffs** das comidas produzidas.

**Status de limpeza** (progressivo por uso):

| Status | Ícone | Efeito na comida |
|---|---|---|
| Brilhando de tão limpo | ✨ | Bônus máximo nos buffs |
| Limpo | ✅ | Buffs normais (padrão) |
| Sujo | ⚠️ | Redução leve nos buffs |
| Muito Sujo | 🟠 | Chance moderada de produzir comida estragada/queimada |
| Imundo | 🔴 | Chance alta de produzir comida estragada/queimada |

- O status degrada a cada cozimento.
- Limpar requer: pano/esponja + produto de limpeza (ou água + sabão).
- Limpar restaura para Brilhando se o jogador tiver itens de limpeza completos, ou para Limpo com apenas água.

### Indicador de temperatura (Celsius)

- A UI do fogão/forno exibe a temperatura atual em **graus Celsius** (mecânica já parcialmente implementada no driver de culinária).
- Cada receita pode ter uma faixa de temperatura ideal.

---

## 7. Prioridade de Implementação

| Fase | Escopo | Dependências |
|---|---|---|
| **Fase 1** | Recategorização de sprites (mapear fogões existentes nos 3 tipos) | Pesquisa de tilesets |
| **Fase 2** | Fogão convencional com gás encanado (pré-corte funcional) | Mecânica de utilidades |
| **Fase 3** | Fogão antigo com combustível sólido | Pesquisa vanilla |
| **Fase 4** | Fogão de indução com eletricidade obrigatória | LKS_EletricidadeConstrucao |
| **Fase 5** | Botijão de gás pós-corte | Pesquisa de items |
| **Fase 6** | Qualidade de comida e integração Cooking skill | Sistema de buffs |
| **Fase 7** | Biodigestor e gás renovável | **Mecânica independente** — ver roadmap |
| **Fase 8** | Pilha + Palha de aço (fonte de calor craftável) | Receitas de craft |
| **Fase 9** | Modo bateria para indução | Sistema de baterias |

---

## 8. Status

- **Documento criado em**: 17/06/2026
- **Status**: Proposta inicial — em discussão
- **Driver existente**: `LKS_Device_Cooking.lua` (cobre fogões e micro-ondas como tipo único)
- **Próximo passo**: Mapear sprites de fogões do jogo base para categorização nos 3 tipos
