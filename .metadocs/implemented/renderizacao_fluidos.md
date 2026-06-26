# Walkthrough - Renderização Dinâmica de Fluidos no Menu do Gerador

Este documento descreve a correção da renderização de recipientes com fluidos no menu do gerador e o registro de dívida técnica de tradução no roadmap.

## Contexto

No Project Zomboid Build 42, os itens que são recipientes de fluidos (como o balde contendo gasolina) não possuem texturas estáticas individuais para cada tipo de líquido. Em vez disso, o motor do jogo desenha a textura base (o balde vazio) e renderiza dinamicamente um overlay colorido (líquido) por cima da textura do item.

No menu de contexto do gerador do mod (`PB_ContextMenu_Generator.lua`), o patch anterior forçava a extração da textura estática do item de inventário associado à opção e a aplicava à propriedade `opt.iconTexture`. Como consequência, o menu de contexto renderizava a textura estática do balde vazio, ignorando o líquido contido no recipiente.

## Solução Técnica

1. **Alteração em [PB_ContextMenu_Generator.lua](common/media/lua/client/PB_ContextMenu_Generator.lua)**:
   - Renomeamos o extrator para `ExtractContainerItemFromOption(opt)` para retornar a referência da instância de `InventoryItem` em vez de apenas a string de textura estática.
   - Ajustamos a função de aplicação de ícones recursiva `applyIconsDeep` para propagar `inheritedItem` (instância de `InventoryItem`).
   - Para as opções que referenciam um item de inventário específico (e as opções "Adicionar Um" filhas), agora definimos `opt.itemForTexture = currentItem` e limpamos `opt.iconTexture = nil`.
   - Isso permite que a renderização do menu de contexto nativo do jogo (`ISContextMenu:renderOptionTextureOrColor`) utilize a função `ISInventoryItem.renderItemIcon`, que automaticamente desenha o overlay do fluido com a cor correspondente.
   - Mantivemos o mapeamento de ícones estáticos via `iconTexture` apenas para as ações sem item direto associado (como "Ligar", "Desconectar", "Adicionar Tudo").

2. **Registro de Dívida Técnica em [.metadocs\roadmap.md](.metadocs/roadmap.md)**:
   - Adicionamos a seção **Dívidas Técnicas** no roadmap para mapear que os recipientes que contêm fluidos que não sejam água devem ter sua categoria traduzida como "Recipiente de Líquido" em vez do atual "Recipiente de Água".

## Como Validar

1. Entre no jogo e adicione um "Balde com Gasolina" e um "Galão com Gasolina" ao inventário do jogador.
2. Clique com o botão direito no gerador e passe o cursor em "Gerador" -> "Colocar Combustível".
3. Verifique se o menu exibe o ícone do balde preenchido com líquido amarelo (gasolina).
4. Abra o submenu de "Balde com Gasolina (2)" e verifique se a opção "Adicionar Um" também exibe o ícone correto do balde com líquido.
5. Verifique se "Adicionar Tudo" continua exibindo o ícone vermelho padrão de reabastecimento.
