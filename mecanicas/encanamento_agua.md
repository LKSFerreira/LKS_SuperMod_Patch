# Mecânica de Encanamento e Abastecimento de Água (B42)

Esta documentação descreve as regras físicas e a lógica de código do Project Zomboid B42 para conectar coletores de água da chuva a aparelhos do mundo (torneiras, pias e lavadoras de roupas) após o corte de água da cidade.

## 1. Funcionamento Físico no Jogo

Para que o encanamento (plumbing) seja ativado com sucesso, o jogo exige conformidade com as seguintes restrições de posicionamento e ferramentas:

1. **Simulação de Gravidade**: O reservatório ou coletor de água da chuva (Rain Collector Barrel) **deve** ser posicionado exatamente **um nível acima** (no andar de cima ou telhado) do aparelho que será encanado. O jogo não permite conexões no mesmo andar.
2. **Posicionamento Relativo**: O coletor superior deve estar localizado na mesma coordenada horizontal $(X, Y)$ do eletrodoméstico ou em um dos 8 quadrados adjacentes a essa coordenada no nível superior.
3. **Ferramenta Necessária**: O personagem do jogador deve portar uma **Chave de Cano (Pipe Wrench)** ou **Chave Inglesa** no inventário principal.
4. **Interação**: Clicando com o botão direito no eletrodoméstico/torneira no andar inferior, o jogador seleciona a opção de menu de contexto *"Encanar [Aparelho]"*. A ação consome tempo e faz o personagem interagir fisicamente.

---

## 2. Aspectos Técnicos e Fluxo de Código

### Validação de Fluidos na Lavadora
No Project Zomboid B42, o container da lavadora de roupas (`IsoClothingWasher`) possui um reservatório de fluidos interno.
- A máquina de lavar requer que o volume de fluidos do objeto seja maior que zero para permitir a ligação do ciclo de lavagem.
- Em código Lua, a validação é feita através do método:
  ```lua
  local temAgua = objetoEletrico:getFluidAmount() > 0
  ```
- Caso o reservatório de fluidos esteja vazio (`fluidAmount <= 0`), o método Java `IsoClothingWasher:setActivated(true)` rejeita a ativação silenciosamente.
- Para manter a consistência de interface, o mod adiciona a restrição nativa `"IGUI_RequiresWaterSupply"` (*"Requer encanamento de água"*) ao tooltip de erro quando o jogador tenta ativar o menu elétrico sem água disponível.

### Link Físico do Encanamento
O encanamento mapeia a coordenada tridimensional do coletor superior à entidade do eletrodoméstico inferior. Toda vez que a lavadora executa o ciclo de lavagem, o motor Java do jogo drena o volume de água correspondente diretamente do coletor no andar de cima.
