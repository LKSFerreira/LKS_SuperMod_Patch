# Mecânica — Devolução de Bateria com 0% (Patch Global)

Patch que sobrescreve o comportamento vanilla de `ISDeviceBatteryAction:invoke()`
para garantir que baterias com 0% de carga sejam devolvidas ao inventário do jogador
ao invés de desaparecerem ao serem removidas de qualquer dispositivo.

---

## Problema

No vanilla, quando uma bateria atinge 0% de carga dentro de um dispositivo
(Walkie-Talkie, TV, rádio, etc.) e o jogador a remove, o método Java
`deviceData:getBattery(inventory)` não cria o item de volta no inventário — a
bateria simplesmente desaparece.

---

## Solução

Monkey-patch de `ISDeviceBatteryAction:invoke()` em `LKS_Patch_BateriaZerada.lua`:

1. Captura o tamanho do inventário antes da chamada Java `getBattery()`
2. Executa a chamada normalmente
3. Se o tamanho do inventário não aumentou (Java não devolveu), cria manualmente
   `Base.Battery` com `setUsedDelta(0)`

---

## Escopo

Afeta **todos os dispositivos** que usam `ISDeviceBatteryAction`:
- Walkie-Talkie
- TV
- Rádio de veículo
- Qualquer mod que use o sistema vanilla de bateria

---

## Arquivo

| Arquivo | Localização |
|---------|-------------|
| `LKS_Patch_BateriaZerada.lua` | `common/media/lua/shared/` |

---

## Validação

1. Inserir bateria em Walkie-Talkie
2. Usar até 0%
3. Remover via clique direito no slot
4. Verificar que `Base.Battery` com 0% aparece no inventário
