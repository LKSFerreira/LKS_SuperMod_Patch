# Mecânica de Ligar e Desligar Geladeiras e Freezers (Fridges Off)

Esta documentação detalha a arquitetura cliente/servidor e a lógica de substituição de contêineres do mod Fridges Off para ligar e desligar aparelhos de refrigeração individualmente.

## 1. Funcionamento no Jogo

Na versão padrão do Project Zomboid, geladeiras e congeladores consomem energia elétrica continuamente caso o quadrado físico em que estejam possua energia, sendo impossível desligá-los individualmente. O mod Fridges Off resolve essa limitação:

1. **Interação de Tomada**: O jogador pode clicar com o botão direito em uma geladeira ou freezer e selecionar *"Ligar"* ou *"Desligar"*. A opção exibe ícones de plugue de tomada verde (`LKS_Pwr_On.png`) e vermelho (`LKS_Pwr_Off.png`).
2. **Impacto no Gerador**: Ao desligar uma geladeira, o consumo elétrico do gerador correspondente cai imediatamente. Isso permite poupar combustível e reduzir o desgaste de geradores, especialmente útil no multiplayer ou para congeladores vazios.
3. **Preservação de Alimentos**: Ao ser desligada, a taxa de resfriamento do contêiner é zerada, fazendo com que os alimentos armazenados nele estraguem no ritmo normal de temperatura ambiente.

---

## 2. Aspectos Técnicos e Fluxo de Código

### Transição de Tipo de Contêiner
Como o motor Java do Project Zomboid gerencia o congelamento de alimentos com base estritamente no tipo de container do objeto (`fridge` ou `freezer`), o mod realiza a transição alterando dinamicamente a string de tipo do contêiner físico:

- **Desligar**:
  - `fridge` $\rightarrow$ `geladeira_desligada`
  - `freezer` $\rightarrow$ `congelador_desligado`
- **Ligar**:
  - `geladeira_desligada` $\rightarrow$ `fridge`
  - `congelador_desligado` $\rightarrow$ `freezer`

### Registro de Texturas Visuais
Ao bootar o cliente, o mod vincula novas imagens de textura para as abas laterais do inventário (Loot Window) de contêineres desligados na tabela global `ContainerButtonIcons`:
```lua
ContainerButtonIcons.geladeira_desligada = getTexture("media/ui/LKS_Container_Fridge_Off.png")
ContainerButtonIcons.congelador_desligado = getTexture("media/ui/LKS_Container_Freezer_Off.png")
```

---

## 3. Arquitetura de Rede e Sincronização (Multiplayer)

A alteração do estado elétrico e do tipo de contêiner ocorre sob um fluxo rígido de rede cliente/servidor para evitar descompassos e duplicações de itens:

```
[Cliente] -(clique "Desligar") -> Envia sendClientCommand("fridges-off", "off", coords)
                                      │
                                      ▼
[Servidor] -> Recebe comando no evento OnClientCommand
           -> Altera o tipo do container no quadrado físico do mapa
           -> Força reamostragem elétrica do gerador (updateGenerators)
           -> Dispara comando sendServerCommand("fridges-off", "sync", syncData)
                                      │
                                      ▼
[Cliente]  -> Recebe comando no evento OnServerCommand
           -> Atualiza localmente o tipo de container do objeto
           -> Força a recarga e refresh visual da janela de Loot (refreshBackpacks)
```

Essa arquitetura garante que todos os jogadores conectados na vizinhança vejam os contêineres e seus respectivos estados elétricos sincronizados em tempo real.
