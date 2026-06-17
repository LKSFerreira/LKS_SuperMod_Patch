# Mecânica de Eletricidade Realista (Powered Buildings)

Esta documentação descreve a arquitetura lógica e o funcionamento da distribuição realista de eletricidade implementada pelo mod Powered Buildings.

## 1. Funcionamento da Rede Elétrica da Construção (Power Pool)

A mecânica tradicional do Project Zomboid distribui energia de um gerador em um raio esférico de 20 tiles, sem distinção de paredes ou tipo de imóvel. O Powered Buildings reescreve essa física, introduzindo o conceito de **Rede Elétrica da Construção (Building Power Pool)**.

1. **Conexão à Construção**: O jogador pode conectar um gerador diretamente a uma parede de um edifício válido (composto por cômodos delimitados por paredes).
2. **Raio de Busca (20x20)**: Para permitir a conexão, o gerador deve estar posicionado em um raio de até 20 tiles de distância de uma construção válida. Caso nenhuma construção seja detectada no raio, a opção de conectar à construção é ocultada no menu de contexto.
3. **Compartilhamento de Carga**: Múltiplos geradores (até 5) podem ser conectados à mesma construção, criando uma rede unificada de compartilhamento de carga (Power Pool). A carga total de consumo dos aparelhos da casa é dividida igualmente entre os geradores ativos conectados.

---

## 2. Consumo de Energia e Sobrecarga

O mod calcula cumulativamente o consumo elétrico da construção baseado nos aparelhos ativos:

- **Eletrodomésticos Grandes**: Geladeiras, freezers, lavadoras e secadoras consomem potências elevadas de watts quando ativas.
- **Lâmpadas e Iluminação**: As luzes ligadas em todos os cômodos da construção somam-se ao consumo global da rede.
- **Sobrecarga (Overload)**: Se o consumo acumulado de watts exceder a capacidade máxima somada dos geradores conectados, a rede elétrica entra em sobrecarga, disparando alertas na interface e gerando risco físico de incêndio ou explosão nos geradores.
- **Eficiência de Combustível**: O consumo de combustível de cada gerador varia proporcionalmente à carga que ele está sustentando no pool elétrico.

---

## 3. Aspectos Técnicos e Código

### Inspeção e Associação de Prédios
O mod utiliza métodos de grid square para verificar cômodos e prédios associados:
```lua
if quadradoAlvo:getBuilding() or quadradoAlvo:haveBuilding() then
    -- Construção detectada
end
```

### Janela de Informações Elétricas (UI)
A interface de informações elétricas da construção centraliza dados e telemetria:
- Lista todos os geradores vinculados.
- Exibe o combustível consolidado nos barris de abastecimento e geradores.
- Calcula a duração estimada (em dias/horas) do combustível da rede com base no consumo atual.
- Apresenta a carga da rede elétrica e consumo em Watts.
