# 🎨 Arquitetura de Assets, Interfaces e Funcionamento do Motor do PZ

Este documento explica de forma detalhada e didática como o motor gráfico do **Project Zomboid** gerencia ícones de inventário (UI), texturas de mundo (Tilesets), overrides de assets, e como o nosso mod e ferramentas interagem com esse ecossistema.

---

## 🛠️ 1. Como o Jogo Renderiza Ícones de Recipientes (UI)

Quando você abre o inventário de um móvel no jogo, a aba lateral exibe um ícone para identificar o tipo do recipiente (container). O motor do jogo utiliza dois métodos diferentes para renderizar esses ícones:

### Método A: Ícones Pré-Desenhados (Imagens Estáticas)
Para contêineres clássicos (Geladeira, Freezer, Micro-ondas, Fogão/Oven, Lavadoras), os desenvolvedores do jogo desenharam ícones 2D específicos. No entanto, esses ícones estão divididos em duas origens físicas na instalação do jogo:
*   **Empacotados em Packs**: Compactados nos arquivos de pacotes binários `media/texturepacks/UI.pack` e `UI2.pack`.
*   **Arquivos Avulsos (Soltos)**: Algumas imagens de UI (incluindo `Container_ClothingWasher.png` e `Container_ClothingDryer.png`) residem diretamente como arquivos `.png` avulsos na pasta `media/ui/` da instalação original do jogo.
*   **Mapeamento de Nomes Oficial (Sem Adivinhação)**: 
    O Project Zomboid gerencia essas associações usando a tabela global no arquivo Lua oficial do jogo:
    `media/lua/shared/Definitions/ContainerButtonIcons.lua`
    
    Neste arquivo, o jogo mapeia as chaves dos recipientes para as texturas carregadas (sejam elas empacotadas nos packs ou arquivos avulsos):
    ```lua
    t.clothingWasher = getTexture("media/ui/Container_ClothingWasher.png")
    t.fridge = getTexture("media/ui/Container_Fridge.png")
    t.oven = getTexture("media/ui/Container_Oven.png")

    ContainerButtonIcons.clothingwasher = t.clothingWasher
    ContainerButtonIcons.fridge = t.fridge
    ContainerButtonIcons.stove = t.oven  -- Nota: "stove" aponta para a textura do "oven"
    ```

### Método B: Renderização Dinâmica 3D (Em Tempo Real)
Para quase todos os outros recipientes (ex: Combo Washer Dryer, armários, caixotes), **não existem imagens 2D de interface pré-desenhadas** mapeadas na tabela do jogo.
*   **Como o jogo resolve**: O motor gráfico do jogo pega o sprite tridimensional do mundo do próprio móvel (ex: o sprite do chão `appliances_laundry_01_0`) e o desenha reduzido em tempo real dentro do quadrado da aba de inventário.

### 💡 Hack de Modding: Injeção na Tabela Global
Como a tabela `ContainerButtonIcons` é global, nós podemos registrar novos ícones de contêineres customizados (ou sobrescrever os existentes) injetando o caminho direto do nosso mod no Lua:
```lua
-- Injeção no Lua do mod para registrar as variantes de desligado apontando para o ícone padrão, permitindo a sobreposição dinâmica:
ContainerButtonIcons.geladeira_desligada = ContainerButtonIcons.fridge or getTexture("media/ui/Container_Fridge.png")
```

---

## 🏷️ 2. Ícones de UI de Contêiner (`Container_`) vs. Itens de Mochila (`Item_`)

É muito importante não confundir o **ícone da aba lateral de recipientes** com o **ícone do item físico** que fica na mochila do jogador. O Project Zomboid gerencia essas duas categorias com convenções e locais distintos:

### A. Ícones de Interface de Contêiner (Prefixados com `Container_`)
*   **Finalidade**: Representar visualmente a aba de inventário de um móvel.
*   **Mapeamento**: Definido em `media/lua/shared/Definitions/ContainerButtonIcons.lua`.
*   **Exemplos**: `Container_Fridge`, `Container_Oven`, `Container_ClothingWasher`.

### B. Ícones de Itens no Inventário/Mochila (Prefixados com `Item_`)
*   **Finalidade**: Representar itens portáteis carregados na bolsa ou no inventário do jogador.
*   **Mapeamento**: Definido nos scripts textuais de itens do jogo na pasta `media/scripts/` (ex: `items.txt`).
*   **Como o jogo monta**: O motor de renderização do jogo lê o campo `Icon` do script de item e concatena:
    $$\text{"Item\_"} + \text{Valor do campo Icon}$$
*   **Exemplo Prático (O Gerador)**:
    No script oficial `media/scripts/items.txt`, o gerador portátil está configurado assim:
    ```text
    item Generator
    {
        Type = Normal,
        DisplayName = Generator,
        Icon = Generator,   <-- Define o ícone de inventário
        ...
    }
    ```
    Como o `Icon` é `Generator`, o motor gráfico busca a textura chamada **`Item_Generator`** no seu pacote de UI.
*   *Nota*: Se você rodar `python tools/gerenciador_assets.py Item_Generator`, o gerenciador extrairá com sucesso o sprite do gerador portátil da mochila.

---

## 🔄 3. Como Funciona a Sobrescrita de Assets (Texture Override)

O Project Zomboid prioriza arquivos soltos presentes nas pastas do seu mod antes de carregar seus arquivos internos empacotados (`.pack`). Isso permite fazer alterações estéticas sem programar nenhuma linha de código.

*   **Caminho do override**: `common/media/ui/` do mod.
*   **Exemplo Prático**: Se o seu mod contiver o arquivo `common/media/ui/Container_Fridge.png`, o jogo automaticamente ignorará o ícone de geladeira original do `UI.pack` e renderizará a sua imagem personalizada.
*   **Regra de Ouro**: **Não é necessário incluir nem distribuir arquivos originais inalterados** na pasta do mod. O jogo já os possui em sua memória padrão. Só salvamos no mod arquivos que criamos do zero ou que modificamos de fato.

---

## ⚙️ 4. Por Que a Combo Washer Dryer Compartilha o Ícone?

Se inspecionarmos o arquivo oficial de propriedades de tiles do jogo (`newtiledefinitions.tiles.txt`), a Combo Washer Dryer azul (`appliances_laundry_01_0`) é definida assim:

```text
    // appliances_laundry_01_0
    tile
    {
        ...
        CustomName = Combo Washer Dryer
        IsoType = IsoCombinationWasherDryer
        ...
```

*   **Mágica do Motor Java**: Ela não possui a propriedade estática `ContainerType`. Em vez disso, ela possui um `IsoType` especial chamado `IsoCombinationWasherDryer`.
*   Ao ler essa propriedade, o motor Java do jogo cria a máquina no mapa e injeta nela um contêiner programado de fábrica com o tipo genérico **`clothingwasher`**.
*   Como o tipo de contêiner dela é `clothingwasher`, ela compartilha por padrão o mesmo ícone (`Container_ClothingWasher.png`) da lavadora branca tradicional.

### 💡 Como contornamos isso?
Se criarmos um arquivo chamado `Container_WasherDryer.png`, o jogo **não** o usará sozinho, porque nenhuma máquina tem o contêiner do tipo `WasherDryer` nativamente. 
Para aplicar um ícone diferente e exclusivo para a Combo azul, nós usamos a **programação Lua** para interceptar a criação da UI e dizer: *"Se o sprite do objeto no mundo for `appliances_laundry_01_0`, force a interface a usar o nosso ícone customizado, senão use o genérico."*

---

## 🎨 5. Extração Sob Demanda com o Gerenciador de Assets

Graças à nossa ferramenta centralizada `gerenciador_assets.py`, você não precisa guardar dezenas de imagens originais inalteradas no repositório do mod. Se precisar de uma imagem original para usar como referência no Photoshop ou GIMP, você pode extraí-la do jogo instantaneamente.

### Como Extrair via Linha de Comando (CLI):
O gerenciador possui um **interceptador inteligente** de argumentos. Você não precisa lembrar de sintaxes complexas, basta passar o nome do sprite direto:

```bash
python tools/gerenciador_assets.py <nome_do_sprite>
```

#### Exemplos Reais:
*   **Extrair Ícone de Geladeira Original**:
    ```bash
    python tools/gerenciador_assets.py Container_Fridge
    ```
    *(Gera: `common/media/ui/Container_Fridge.png` extraído em alta qualidade do `UI.pack`).*

*   **Extrair Sprite do Mundo da Combo Washer Dryer (Sul)**:
    ```bash
    python tools/gerenciador_assets.py appliances_laundry_01_0
    ```
    *(Gera automaticamente o nome amigável sugerido: `common/media/ui/Exemplo_Combo__Washer_Dryer_Blue_S.png` extraído em alta qualidade do `Tiles2x.pack`).*

### O Que o Gerenciador Faz Por Trás das Cenas:
1.  **Dedução de Intenção**: Identifica que você passou o nome de um sprite e ativa a rotina de extração.
2.  **Consulta de Metadados**: Lê o dicionário de tilesets do jogo original no arquivo [dicionario_tilesets.json](tools/dicionario_tilesets.json) para sugerir nomes amigáveis e estruturados de arquivos com base nos tilesets catalogados. Ele é consumido programaticamente pelas funções `sugerir_nome_arquivo` e `buscar_referencias_assets`.
3.  **Busca Híbrida Inteligente**: Varre simultaneamente os arquivos binários compactados (`.pack`) e o diretório físico de imagens soltas (`media/ui/`) da instalação do jogo para achar qualquer correspondência do termo.
4.  **Cópia vs. Extração**: Se você selecionar um sprite empacotado, ele realiza o recorte de coordenadas do atlas correspondente. Se selecionar um arquivo de imagem avulso, ele executa uma cópia de arquivo padrão (`shutil.copy2`) direta para a pasta do mod, garantindo simplicidade e velocidade.
5.  **Inteligência de Resolução**: Prioriza texturas HD (`Tiles2x.pack`) e impede que versões SD sobrescrevam arquivos HD de qualidade superior já existentes na pasta do mod.
6.  **Tratamento de Erros e Sanitização**: Limpa caracteres de caminho inválidos, avisa sobre sprites não encontrados no jogo e suporta nomes nativos como fallback.

---

## 🔄 6. Atualização do Dicionário de Tilesets

Para evitar que o dicionário de tilesets fique defasado após atualizações oficiais do Project Zomboid (como novas versões ou patches da Build 42), disponibilizamos uma ferramenta de atualização automatizada:

*   **Script Atualizador**: [atualizar_dicionario_tilesets.py](tools/atualizar_dicionario_tilesets.py)
*   **Como Executar**:
    ```bash
    python tools/atualizar_dicionario_tilesets.py
    ```

### O que o Atualizador Faz:
1.  Localiza o caminho de instalação do Project Zomboid a partir do arquivo `.env` (ou do fallback do sistema).
2.  Lê e analisa em tempo real o arquivo oficial de definições de tiles do jogo (`media/newtiledefinitions.tiles.txt`).
3.  Filtra e extrai todas as propriedades relevantes (nomes amigáveis, categorias, orientações e contêineres) para os principais de eletrodomésticos (`appliances_laundry`, `appliances_cooking`, `appliances_refrigeration`, etc.).
4.  Reescreve o banco [dicionario_tilesets.json](tools/dicionario_tilesets.json) limpo e com suporte a UTF-8, garantindo que novas adições do jogo fiquem disponíveis na CLI de busca imediatamente.

---

## 🔍 6. Caso Prático: Descobrindo se um Ícone de Interface Existe

Suponha que você queira extrair o ícone 2D da Combo Washer Dryer, mas não saiba se o jogo original possui essa imagem desenhada de fábrica. Você tenta rodar o comando usando o nome lógico de interface:

```bash
python tools/gerenciador_assets.py Container_ComboWasherDryer
```

Como o jogo **não possui** esse sprite de UI desenhado de fábrica (pois ele desenha o sprite do mundo isométrico em tempo real), a ferramenta fará o escaneamento em todos os pacotes e exibirá em vermelho o seguinte alerta de erro no encerramento:

```text
[!] AVISO: Os seguintes sprites não foram encontrados em nenhum arquivo .pack:
  - Container_ComboWasherDryer (Verifique a grafia ou o nome do tileset)

[*] Extração finalizada! Total importado: 0/1 assets.
```

**O que isso te ensina no desenvolvimento?**
*   Que o ícone estático `Container_ComboWasherDryer` não existe nos arquivos do jogo.
*   Que para customizar a interface desse eletrodoméstico no mod, você deve extrair o sprite 3D do mundo (`appliances_laundry_01_0`) ou fazer o override do ícone comum de lavadora (`Container_ClothingWasher`).

