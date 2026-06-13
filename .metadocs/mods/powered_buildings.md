# Documentação de Referência - Generator Powered Buildings (Mod Original)

Este documento reúne e analisa o funcionamento, recursos, compatibilidades e limitações do mod original **Generator Powered Buildings** (Workshop ID: `3597471949`, Mod IDs: `buildinggenpowerv2`, `buildinggenpowermp`, `buildinggenpower`) desenvolvido por **Beathoven**. 

As informações a seguir servem como fonte de verdade para a elaboração de patches de compatibilidade, correções de interface e documentação no `README.MD` e `readme_steam.txt`.

---

## 🎯 O que o Mod Faz?
O **Generator Powered Buildings** transforma geradores de energia convencionais em sistemas de energia centralizados para construções inteiras no Project Zomboid (Build 42). 

Em vez de depender apenas do raio de cobertura original tridimensional (20x20 blocos ao redor do gerador), o mod permite vincular geradores diretamente a uma estrutura/prédio. A partir dessa conexão, a eletricidade é gerenciada e distribuída por toda a malha de cômodos e andares da construção.

---

## ⚙️ Como Funciona? (Mecânica e Fluxo de Jogo)

1. **Conexão e Inicialização**:
   - O jogador posiciona o gerador perto do prédio desejado.
   - Usa o menu de contexto do gerador para selecionar a opção: **Conectar à Construção**.
   - Liga o gerador para iniciar o escaneamento inicial que detecta todos os eletrodomésticos, luzes e consumidores elétricos ativos da estrutura.

2. **Gerenciamento de Rede (Pool)**:
   - Permite agrupar e linkar **até 10 geradores** para suprir uma única construção.
   - O consumo de combustível e a carga elétrica (strain) são distribuídos de forma equilibrada entre todos os geradores ativos conectados à mesma rede.
   - Mantém o raio nativo tridimensional de 20x20 ao ar livre para cada gerador individual, permitindo cobrir áreas externas próximas ao redor do prédio.
   - Estende a rede de energia por cerca de **3 blocos além das paredes externas da construção** para manter eletrodomésticos posicionados na área de fora (como churrasqueiras, luzes de parede ou freezers de pátio) funcionando.

3. **Janela de Controle de Energia (Building Power Info)**:
   - Acessada a partir de qualquer interruptor de luz ativo na construção ou do próprio gerador.
   - Exibe informações em tempo real sobre:
     - Nível total e capacidade máxima de combustível do reservatório combinado.
     - Condição física dos geradores individuais.
     - Consumo elétrico (Power Draw) e Carga da Rede Elétrica (Strain).
     - Contagem de consumidores ativos (Luzes, Lâmpadas, Eletrodomésticos).
     - Status dos barris de combustível interligados.
     - Configurações do termostato/climatização.
   - **Funcionalidade de Caminho**: Clicar na linha de um gerador na interface faz o personagem caminhar automaticamente até ele.

4. **Reabastecimento Automático (Linked Barrels)**:
   - O jogador pode interligar barris de combustível (`petrol barrels`) ou mods compatíveis de armazenamento à rede de geradores para aumentar drasticamente a capacidade de combustível e ativar o abastecimento automático das máquinas.

5. **Sistema de Climatização (Aquecimento/Resfriamento)**:
   - Suporte ao controle de temperatura ambiente interno da construção, com ajuste de temperatura alvo (Target Temperature) por termostato.
   - O jogador pode colocar o termostato em modo inativo (Standby/Snowflake) enquanto mantém a rede elétrica ativa para economizar combustível nas estações quentes.
   - Suporte a posicionamento de fontes de calor em andares superiores.
   - Suporte a construções criadas inteiramente por jogadores ou anexos construídos ao lado de prédios nativos.

---

## 🔧 Opções do Sandbox (Configurações do Servidor)
- `HeatingSystemEnabled`: Ativa/desativa o sistema de climatização.
- `HeatRadius`: Ajusta o raio de propagação do calor interno.
- `BaseLoadCapacity`: Define a capacidade de carga básica de cada gerador na rede.
- `MaxConsumersPerBuilding`: Limita a quantidade máxima de aparelhos elétricos por construção.
- `MaxGeneratorsPerBuilding`: Limita a quantidade de geradores associados a um único prédio (máximo de 10).

---

## 🤝 Compatibilidade de Mods

### Mods Compatíveis Testados:
- **Realistic Temperature Mod [B42]**: Funciona em conjunto com as mecânicas de clima.
- **Fridges Off!**: Mod de desligamento de geladeiras (integrado na lógica de consumidores).
- **[B42] Useful Barrels**: Permite o uso de barris deste mod para conexão e reabastecimento automático de combustível.

### Mods com Limitações ou Incompatibilidades Conhecidas:
- **Immersive Solar Panels**: Quando o sistema muda para energia solar (desligando os geradores a combustível), o sistema de controle de temperatura (aquecimento) deste mod deixa de funcionar, gerando quedas de temperatura interna no inverno.

---

## ⚠️ Limitações Conhecidas & Em Desenvolvimento (WIP)
- **Multiplayer (MP)**: O sistema de controle de aquecimento/climatização (`HeatingSystemEnabled`) é mais estável em singleplayer. O comportamento do interruptor geral de climatização no servidor multiplayer ainda está sendo finalizado.
- **Áreas Externas**: O modo de construção ainda herda o raio tridimensional nativo do gerador fora das paredes do prédio.
- **Danos por Carga**: Sobrecarga severa (Strain >= 100%) aumenta drasticamente o consumo de combustível, mas o dano acelerado nas máquinas por sobrecarga ainda está em fase de refinamento.
- **Regressões em MP**: Regressões pontuais nas bordas de carregamento de chunks no multiplayer podem ocorrer enquanto a sincronização do servidor é estabilizada.
