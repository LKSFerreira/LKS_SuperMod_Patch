# Moddata Bidirecional — Padrão de Vínculo entre Objetos — Project Zomboid Build 42

Quando dois objetos do mundo precisam de referência mútua (ex: botijão ↔ fogão), usar moddata em AMBOS os lados com coordenadas como chave de vínculo.

---

## Padrão

```lua
-- CONECTAR: marca ambos
local dadosFogao = fogao:getModData()
dadosFogao.LKS_BotijaoConectado = true

local dadosBotijao = botijao:getModData()
dadosBotijao.LKS_ConectadoAoFogaoX = fogao:getX()
dadosBotijao.LKS_ConectadoAoFogaoY = fogao:getY()
dadosBotijao.LKS_ConectadoAoFogaoZ = fogao:getZ()

-- DESCONECTAR: limpa ambos (escaneia raio para encontrar o par)
dadosFogao.LKS_BotijaoConectado = nil
dadosBotijao.LKS_ConectadoAoFogaoX = nil
-- ...

-- VALIDAÇÃO DEFENSIVA: no acesso ao menu, confirma que o par físico existe
-- Se moddata diz conectado mas o objeto sumiu → auto-limpa
```

---

## Vantagens sobre referência unidirecional

- Exclusividade 1:1 garantida (botijão só serve 1 fogão)
- Limpeza automática quando qualquer lado é removido (pickup, destruição, despawn)
- Funciona em multiplayer (moddata é sincronizado pelo engine)
- Botijão no inventário com moddata residual → limpar automaticamente (impossível estar conectado se está no inventário)

---

## Quando usar

- Qualquer mecânica de conexão física entre objetos do mundo (botijão↔fogão, mangueira↔barril, etc.)
- NÃO usar para relações transitórias (apenas para estado persistente)
