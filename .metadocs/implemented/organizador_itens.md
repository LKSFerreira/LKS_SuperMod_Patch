# Walkthrough: Organizador de Itens

**Data:** 23/06/2026
**Autor:** LKS
**Status:** Estável (testado em jogo, funcional)

## Contexto

Feature 100% original do LKS SuperMod Patch. Sistema de favoritar containers pela base e guardar itens automaticamente com um clique. Scan de 50×50 tiles em todos os andares (Z=0 a Z=7).

## Arquitetura Final

### Arquivos Criados

| Arquivo | Responsabilidade |
|---------|------------------|
| `client/LKS_Organizer_Motor.lua` | Core: scan, matching fullType, montagem de plano, execução com ISWalkToTimedAction |
| `client/LKS_Organizer_Handler.lua` | Botão "Guardar Itens" (ISInventoryWindowContainerControls) |
| `client/LKS_Organizer_ContextMenu.lua` | Favoritar/Desfavoritar no menu de contexto do mundo |
| `client/LKS_Organizer_FavoritoVisual.lua` | Botão "Favoritos" + estrela na Loot Window + overlay sidebar |

### Mecânica

1. Jogador clica direito em container do mundo → "Favoritar para Guardar Itens"
2. Container marcado com modData + overlay de estrela na sidebar
3. Jogador clica "Guardar Itens" no inventário
4. Motor escaneia 50×50×8 tiles → encontra containers favoritos
5. Para cada item no inventário: verifica se fullType existe em algum container favorito
6. Monta plano de transferência agrupado por container
7. Executa: ISWalkToTimedAction → ISInventoryTransferAction (por item)

### Decisões Técnicas

- ISWalkToTimedAction (não ISPathFindAction) — compatível com ISInventoryTransferAction
- Scan em bags equipadas como fonte de itens
- Bags no chão como containers favoritáveis (IsoWorldInventoryObject)
- Overlay de estrela via monkey-patch de `addContainerButton` com pool de botões reciclados
- Container `floor` excluído da overlay

## Validação

- Testado pelo usuário em jogo com múltiplos cenários
- Pathfinding multi-andar funcional
- Transferência de itens confirmada
- Estrela visual consistente após fix do `buttonPool`
