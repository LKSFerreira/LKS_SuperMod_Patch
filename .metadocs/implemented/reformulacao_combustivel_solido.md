# Walkthrough: Reformulação do Sistema de Combustível Sólido

**Data:** 24/06/2026
**Autor:** LKS
**Status:** Em teste (funcionalidades core operacionais)

## Contexto

O vanilla do PZ Build 42 tem um sistema restritivo de combustível que não aceita muitos itens que logicamente deveriam queimar (sapatos, carteiras, roupas de couro). O menu "Transformar em Combustível" na Loot Window replicava o menu de contexto sem mecânica própria. A reformulação inverte a lógica e cria novas mecânicas.

## Arquitetura Final

### Arquivos Criados

| Arquivo | Camada | Responsabilidade |
|---------|--------|------------------|
| `shared/cooking/LKS_Fire_FuelClassifier.lua` | Shared | Classificador centralizado — `LKS_ehCombustivel()`, `LKS_ehCombustivelRecursivo()`, `LKS_calcularDuracao()` + overrides de `shouldBurn`/`isValidFuel` |
| `client/LKS_Fire_LootWindowHandler.lua` | Client | Handler da Loot Window — processa itens DENTRO do container via TimedAction |
| `client/LKS_Fire_AutoBurn.lua` | Client | Consumo automático de itens em containers acesos (penalidade 75%) |

### Arquivos Modificados

| Arquivo | Mudança |
|---------|---------|
| `client/LKS_Menu_Fire_FuelSolid.lua` | Added `require` do classificador |
| `client/LKS_Menu_Fire_FuelSolid_Patch.lua` | Agrupamento por categoria + `LKS_onAddAllFuelByCategory` |
| `shared/Translate/PTBR/IG_UI.json` | 4 novas chaves |
| `shared/Translate/EN/IG_UI.json` | 4 novas chaves |

## Decisões Técnicas

### Por que lógica invertida?

O vanilla lista o que É combustível (tabela hardcoded + tags + categorias). Qualquer item novo adicionado por mods não queima automaticamente. A lógica invertida garante que tudo queima por padrão — apenas materiais que fisicamente não podem queimar (metal, vidro, pedra) são excluídos.

### Por que `getTags():toArray()` com pcall?

A API `item:hasTag(ItemTag.XXX)` requer constantes Java (`ItemTag.IS_FIRE_FUEL`). Para verificar tags arbitrárias como `base:hasmetal`, seria necessário `ItemTag.get(ResourceLocation.of("base:hasmetal"))`. O `pcall` com `getTags():toArray()` é mais robusto — funciona para qualquer tag sem depender de constantes Java pré-definidas.

### Por que separar LootWindow do Menu de Contexto?

O menu de contexto opera sobre itens no INVENTÁRIO do jogador. O botão da Loot Window opera sobre itens DENTRO do container de fogo. São fluxos diferentes que justificam mecânicas distintas — o botão adiciona a dimensão do tempo (TimedAction).

### Por que penalidade de umidade em vez de bloqueio?

Na vida real, roupas molhadas queimam — só demora mais e produz muita fumaça. Bloquear completamente é ultra-realista ao ponto de prejudicar o gameplay. A penalidade gradual (50% no pior caso) é mais justa.

### Sobre a limitação de `isItemAllowed` (Java)

O engine Java filtra quais itens podem ser colocados/exibidos em containers de fogo via `ItemContainer.isItemAllowed()`. Esse método NÃO é acessível via Lua. Itens podem estar presentes no container (peso muda) mas não renderizados na UI. Isso afeta apenas a visualização, não a funcionalidade — o AutoBurn e o botão Transformar processam os itens normalmente.

## Problemas Encontrados e Soluções

### 1. Sapatos não apareciam como combustível

**Causa:** O vanilla `shouldBurn` bloqueava roupas sem `FabricType`. Sapatos (Shoes_Random, Shoes_TrainerTINT) não têm FabricType definido.
**Solução:** Nosso override remove essa restrição. Tudo que é Clothing queima independente de FabricType.

### 2. "Tudo" por categoria consumia todos os itens

**Causa:** O submenu de categoria usava `LKS_onAddAllFuel` (sem filtro).
**Solução:** Criada `LKS_onAddAllFuelByCategory(jogador, alvo, acao, combustivel, categoria)` que filtra por `DisplayCategory`.

### 3. Roupas molhadas (wetness=100) não apareciam

**Causa:** Restrição vanilla mantida inicialmente (`getWetness() > 0 → bloqueio`).
**Solução:** Removido o bloqueio. Umidade agora aplica penalidade gradual na duração: `1.0 - (wetness/200.0)`.

### 4. Override do isValidFuel não funcionava em algumas situações

**Causa:** O arquivo classificador (shared) precisa ser `require`'d explicitamente nos arquivos client que o usam.
**Solução:** Added `require "cooking/LKS_Fire_FuelClassifier"` em `LKS_Menu_Fire_FuelSolid.lua` e no Patch.

## Fluxo de Dados

```
Jogador abre menu de contexto na lareira
    → ISCampingMenu.getNearbyFuelInfo(player)
        → ISCampingMenu.isValidFuel(item)  [OVERRIDDEN]
            → LKS_ehCombustivel(item)
                → temTagNaoCombustivel(item)  [getTags():toArray() + pcall]
                → CATEGORIAS_NAO_COMBUSTIVEIS[categoria]
                → TIPOS_NAO_COMBUSTIVEIS[tipo]
    → ISCampingMenu.doAddFuelOption()  [OVERRIDDEN pelo Patch]
        → Se >6 tipos: agrupamento por categoria
        → Se <=6 tipos: lista plana
```

```
AutoBurn (EveryTenMinutes)
    → Varre tiles 20×20 ao redor do jogador
        → Encontra container de fogo aceso com itens
            → LKS_ehCombustivelRecursivo(item)
                → Percorre containers aninhados
                → Separa combustíveis vs não-combustíveis
            → Consome combustíveis com 75% eficiência
            → Não-combustíveis permanecem
```

## Compatibilidade

- **Mods de itens:** Itens adicionados por outros mods queimam automaticamente (lógica invertida)
- **TwisTonFire:** Sem conflito (opera em camada diferente)
- **Neat Rocco UI:** Sem conflito (não toca em containers de fogo)
- **Vanilla ISBBQMenu:** Neutralizado pelo LKS_Menu_Fire_FuelSolid.lua (como antes)

## Testes Pendentes

- [ ] AutoBurn: verificar consumo periódico em container aceso
- [ ] Loot Window handler: confirmar TimedAction funcional
- [ ] Recursividade: mochila dentro de mochila dentro da lareira
- [ ] Performance: muitos itens no inventário com agrupamento
- [ ] Multiplayer: sincronização do modData de penalidade
