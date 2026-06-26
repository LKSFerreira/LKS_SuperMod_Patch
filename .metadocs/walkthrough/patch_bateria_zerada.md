# Walkthrough — Patch Bateria Zerada

## Contexto

Demanda espontânea durante testes do videogame portátil. Ao remover baterias
com 0% de carga de dispositivos vanilla, o item desaparecia. O jogador espera
receber a pilha de volta (mesmo sem carga) para eventual recarga ou descarte.

## Status: DÍVIDA TÉCNICA (não resolvido)

O engine Java do PZ destrói automaticamente itens `base:drainable` quando
`usedDelta` chega a 0 — mesmo que recriemos o item via Lua com `setUsedDelta(0.001)`,
o engine faz cleanup no tick seguinte. A única solução real seria:

1. Override do script `Base.Battery` adicionando `KeepOnDeplete = true`
2. Ou criar item customizado `LKS_BateriaVazia` (não-drainable) ao detectar carga 0

Ambas requerem investigação adicional sobre efeitos colaterais.

## O Que Foi Feito

Monkey-patch de `ISDeviceBatteryAction:invoke()` em `LKS_Patch_BateriaZerada.lua`:
- Captura tamanho do inventário antes/depois de `getBattery()`
- Se Java não devolveu o item, cria `Base.Battery` com `setUsedDelta(0)` manualmente
- Afeta todos os dispositivos com bateria (Walkie-Talkie, TV, rádios, etc.)
- Não altera o comportamento de inserção (branch `else` inalterado)

## Decisões

- **Global vs específico**: Optou-se por patch global (afeta todos os dispositivos)
  já que o comportamento de "sumir" é universalmente indesejável.
- **Comparação de tamanho do inventário**: Abordagem defensiva — se o Java já devolveu
  normalmente (bateria com carga), não duplica. Só cria quando o Java falhou em devolver.

## Como Validar

1. Inserir bateria em qualquer Walkie-Talkie
2. Usar até 0% de carga
3. Clicar direito no slot para remover
4. Verificar: `Base.Battery` com 0% aparece no inventário
