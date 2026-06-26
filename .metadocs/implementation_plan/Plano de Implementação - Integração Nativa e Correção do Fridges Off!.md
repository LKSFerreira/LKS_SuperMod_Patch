# Plano de Implementação - Integração Nativa e Correção do Fridges Off!

Este plano propõe a integração ("fagocitação") nativa das mecânicas do mod *Fridges Off!* diretamente no **LKS SuperMod Patch**, eliminando a dependência do mod original e corrigindo o bug crítico da Build 42 onde geladeiras desligadas continuavam refrigerando indefinidamente sem consumir energia.

## User Review Required

> [!IMPORTANT]
> - Utilizaremos as chaves de tipo de contêiner `"geladeira_desligada"` e `"congelador_desligado"` (em português, sem os radicais *"fridge"* e *"freezer"*). Isso impede que o motor Java de refrigeração do Project Zomboid aplique conservação térmica a esses recipientes, consertando o bug de refrigeração infinita sem eletricidade.
> - As chaves de tradução em português do mod original serão adicionadas diretamente nos arquivos JSON existentes do patch (`IG_UI.json` e `ContextMenu.json`), fornecendo fallbacks em português de forma estática.

---

## Proposed Changes

### Traduções (Localization)

#### [MODIFY] [IG_UI.json](common/media/lua/shared/Translate/PTBR/IG_UI.json)
Adicionar as chaves que definem o título do contêiner desligado no inventário:
```json
  "IGUI_ContainerTitle_geladeira_desligada": "Geladeira desligada",
  "IGUI_ContainerTitle_congelador_desligado": "Freezer desligado",
```

#### [MODIFY] [ContextMenu.json](common/media/lua/shared/Translate/PTBR/ContextMenu.json)
Adicionar as opções de menu de contexto em português:
```json
  "ContextMenu_TurnOn": "Ligar",
  "ContextMenu_TurnOff": "Desligar",
```

---

### Scripts de Lógica (Lua)

#### [MODIFY] [fridgesoff_client.lua](common/media/lua/client/fridgesoff_client.lua)
Refatorar para usar os novos tipos `"geladeira_desligada"` e `"congelador_desligado"`:
1. No menu de contexto, verificar `"geladeira_desligada"` e `"congelador_desligado"` ao exibir a opção "Ligar".
2. Na função `loadNewIcons()`, associar as texturas PNG copiadas aos novos tipos.
3. No comando de sincronização (`onServerCommand`), atualizar a transição de tipos do contêiner.

#### [MODIFY] [fridgesoff_server.lua](common/media/lua/server/fridgesoff_server.lua)
Refatorar a lógica do servidor para usar os novos tipos:
1. No loop de busca de objetos, verificar `"geladeira_desligada"` e `"congelador_desligado"`.
2. No comando de desligar (`off`), mudar o tipo de `"fridge"` para `"geladeira_desligada"` e `"freezer"` para `"congelador_desligado"`.
3. No comando de ligar (`on`), reverter para os tipos originais nativos.

---

## Verification Plan

### Passo a Passo de Testes Manuais

1. **Preparação do Ambiente**:
   - Inicie o jogo com o mod patch ativo (sem o mod *Fridges Off!* original ativado).
   - Tenha um gerador com combustível ligado e conectado a uma casa ou abrigo.

2. **Teste 1: Desligamento e Redução de Consumo**:
   - Clique com o botão direito na geladeira/freezer da casa e selecione a opção **"Desligar"**.
   - Abra a janela **Informações Elétricas da Construção** (a partir de qualquer interruptor de luz).
   - Verifique se a quantidade de **Aparelhos Conectados** e o **Consumo Elétrico** diminuíram.
   - Abra o inventário e confirme que o contêiner exibe o ícone de tomada desligada correspondente e o título *"Geladeira desligada"* / *"Freezer desligado"*.

3. **Teste 2: Interrupção da Refrigeração (Alimento Estragando)**:
   - Coloque um alimento perecível fresco (ex: carne fresca, tomate) dentro da geladeira/freezer desligada.
   - Avance o tempo do jogo e observe se a barra de frescor do alimento diminui na velocidade normal de temperatura ambiente (o alimento deve estragar normalmente, confirmando que a refrigeração parou de fato).

4. **Teste 3: Religamento e Consumo**:
   - Clique com o botão direito na geladeira desligada e selecione **"Ligar"**.
   - Confirme no menu de energia do gerador que o consumo elétrico voltou a subir e os alimentos voltaram a ficar conservados e gelados (indicados pelo tom azul/frio na barra).
