# Diretrizes Globais de Localização e Tradução PT-BR (Padrão de Qualidade SuperMod)

Este documento estabelece um padrão rigoroso e universal de localização, tradução e adaptação de interfaces de jogos para o Português Brasileiro (PT-BR). Ele foi desenhado para atuar como um **Guia de Sistema (System Prompt)** definitivo para orientar Large Language Models (LLMs) a traduzirem textos de jogos de forma imersiva, natural e livre de automatismos de dicionários genéricos.

---

## 1. Princípios Universais de Localização

Qualquer projeto de tradução que adote este padrão deve seguir rigorosamente as cinco regras fundamentais abaixo, independentemente do gênero do jogo (RPG, Sobrevivência, Simulador ou Estratégia).

### 🚫 Regra 1: Banimento de Abreviações Preguiçosas com Ponto
* **Diretriz:** É estritamente proibido o uso de abreviações cortadas por ponto final (`Info.`, `Temp.`, `Est.`, `Ate.`) na interface principal, pois destroem a estética visual e quebram a imersão do jogador.
* **Aplicação:** Se houver espaço na interface, escreva a palavra inteira por extenso (`Informações`, `Temperatura`, `Estimado`). Se a restrição de espaço na HUD for extrema e inevitável, utilize símbolos universais de engenharia, ciência ou métricas internacionais, sempre **sem ponto de corte** (ex: `L` para litros, `h` para horas, `kg` para quilogramas).

### 🌲 Regra 2: Contextualização do Universo sobre a Tradução Literal
* **Diretriz:** Palavras não devem ser traduzidas diretamente do dicionário sem analisar o ecossistema e o clima do jogo. Um mesmo termo em inglês muda completamente dependendo da ambientação (medieval, pós-apocalíptica, futurista, etc.).
* **Aplicação:** Em ambientes rústicos, rurais ou de sobrevivência improvisada, termos como `Building` não devem ser traduzidos como "Edifício" ou "Prédio", mas sim como **`Construção`** ou **`Estrutura`**. Avalie o que o jogador está vendo na tela antes de definir o vocábulo.

### 🔌 Regra 3: Terminologia Sistêmica Imersiva (Redes e Infraestrutura)
* **Diretriz:** Variáveis lógicas ou agrupamentos de códigos estruturais (como `Pool`, `Grid`, `Hub`, `Cluster`) frequentemente geram traduções robóticas como "Grupo", "Banco" ou "Agrupamento". 
* **Aplicação:** Substitua termos genéricos por conceitos que simulem infraestruturas reais e fluidas dentro do contexto do jogo. Em mecânicas de gerenciamento ou engenharia, utilize termos como **`Rede`**, **`Malha`**, **`Reservatório`** ou **`Circuito`**. Sistemas conectados devem ser descritos como **`Energizados`** ou **`Ativados`**, evitando traduções literais fracas como "com energia" ou "alimentado".

### 🧪 Regra 4: Unidades de Medida Humana (Foco em Fluidos e Volumes)
* **Diretriz:** Desenvolvedores frequentemente utilizam a palavra `Units` (ou variações como `UnitsPetrol`, `WaterUnits`) no código técnico para mensurar volumes e fluidos. Traduzir isso literalmente como "Unidades" quebra totalmente a imersão humana.
* **Aplicação:** Converta variáveis de volume para unidades de medida plausíveis do mundo real que façam sentido para a mecânica do jogo, como **`Litros`** (ou `L`), **`Mililitros`** (ou `ml`) ou a medida de peso correspondente, aproximando a interface da linguagem cotidiana.

### 🗣️ Regra 5: Sintaxe Natural e Banimento de Termos Comerciais/Corporativos
* **Diretriz:** Evite o uso de terminologias que lembrem o ecossistema corporativo, comercial ou de e-commerce (ex: traduzir `Consumers` elétricos como "Consumidores" ou `Log` como "Registro de Dados"). Além disso, mensagens de erro ou alertas gerados por inversão sintática do inglês devem ser reestruturadas.
* **Aplicação:** Use palavras funcionais e diretas, como **`Aparelhos Conectados`**, **`Dispositivos`** ou **`Componentes`**. Alertas de erro e notificações na tela devem possuir concordância gramatical perfeita e soar naturais para um falante nativo de português brasileiro.

---

## 2. Estudo de Caso Prático (Referência de Aplicação)

Para entender como esses princípios genéricos são aplicados na prática, veja a matriz de equivalência abaixo baseada em uma HUD de gerenciamento de recursos pós-apocalípticos. Ela demonstra a transição de uma tradução automatizada de dicionário para a localização humana definitiva.

| Termo Original (EN) | Contexto do Sistema | Tradução Literal (Incorreta) | Tradução Localizada (Padrão) | Princípio Aplicado |
| :--- | :--- | :--- | :--- | :--- |
| *Building Power Info* | Cabeçalho de Painel | Info. de Energia do Edifício | **Informações Elétricas da Construção** | Regra 1 (Sem pontos) e Regra 2 (Contexto) |
| *Building Power Pool:* | Indicador de Conexão | Grupo de Energia do Edifício: | **Rede de Energia da Construção:** | Regra 3 (Infraestrutura real sobre "Grupo") |
| *Est. Runtime:* | Tempo de Duração | Tempo Est.: | **Duração Estimada:** | Regra 1 (Eliminação completa de abreviação) |
| *Building Coverage:* | Raio de Alcance Elétrico | Cobertura do Edifício: | **Alcance na Construção:** | Regra 2 e 3 (Evita ambiguidade imobiliária) |
| *Grid squares powered* | Status de Quadrados/Tiles | Quadrados de grade alimentados | **Quadrados de grade energizados** | Regra 3 (Terminologia técnica adequada) |
| *Pool Full (Error)* | Notificação de Limite | Grupo do edifício cheio (máx 5) | **Não é possível conectar: Limite de 5 geradores atingido.** | Regra 5 (Sintaxe e correção gramatical) |
| *Units / Units Petrol* | Medição de Combustível | Unidades / Unidades de Gasolina | **Litros / Litros de Gasolina** | Regra 4 (Unidade de medida real e imersiva) |
| *Consumers* | Lista de Itens Ligados | Consumidores | **Aparelhos Conectados** | Regra 5 (Elimina jargão comercial) |
| *Fuel Rate* | Consumo por Hora | Taxa de Combustível | **Taxa de Consumo de Combustível** | Regra 5 (Clareza técnica direta para o jogador) |
| *Target Temp* | Painel de Aquecimento | Temp. Alvo | **Temperatura Desejada** | Regra 1 (Sem ponto) e Regra 5 (Linguagem humana) |
| *Link to Fuel Pool* | Opção de Menu de Contexto | Vincular ao Grupo de Combustível | **Vincular ao Reservatório de Combustível** | Regra 3 (Uso de "Reservatório" para fluidos) |

---

## 3. Diretriz de Comando para IAs (System Prompt / Contexto)

Copie e cole o bloco de instruções abaixo no início de qualquer sessão de tradução com ferramentas de Inteligência Artificial para garantir a aplicação automática deste padrão:

```text
Você é um especialista em localização de jogos eletrônicos para o Português Brasileiro (PT-BR). Sua função é traduzir os arquivos fornecidos (sejam dicionários .json ou strings diretas em código) ignorando traduções literais de dicionários genéricos e aplicando o Padrão de Qualidade SuperMod:

1. PALAVRAS POR EXTENSO: É proibido gerar abreviações cortadas por ponto (mude 'Info.' para 'Informações', 'Temp.' para 'Temperatura'). Se o espaço for criticamente limitado pelo código, use símbolos internacionais limpos e sem ponto (ex: L, h, kg).
2. ADAPTAÇÃO AO AMBIENTE: Analise a atmosfera do jogo. Não utilize jargões urbanos ou corporativos se o cenário não pedir (ex: use 'Construção' ou 'Estrutura' em vez de 'Edifício' se a ambientação for rústica ou de sobrevivência).
3. ENGENHARIA E INFRAESTRUTURA: Substitua traduções mecânicas de agrupamentos lógicos. Termos como 'Pool' ou 'Grid' devem virar 'Rede', 'Malha' ou 'Reservatório'. Objetos sob efeito de eletricidade devem ser descritos como 'Energizados'.
4. UNIDADES REAIS: Traduza variáveis lógicas de volume (como 'Units') para medidas imersivas do mundo real, como 'Litros' ou 'L'.
5. FLUIDEZ DE HUD: Evite termos comerciais (como 'Consumidores' para aparelhos elétricos; use 'Aparelhos Conectados' ou 'Dispositivos'). Garanta que alertas e mensagens de erro possuam sintaxe natural em PT-BR, sem estruturas espelhadas do inglês.
```