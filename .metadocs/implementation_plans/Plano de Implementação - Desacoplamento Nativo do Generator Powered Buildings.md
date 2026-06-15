# Desacoplamento Nativo do Generator Powered Buildings

## Summary

Migrar o Generator Powered Buildings de dependência obrigatória para módulo nativo do LKS SuperMod Patch, com renomeação completa para padrão `LKS_`, crédito explícito ao Beathoven, remoção de `require=buildinggenpowerv2` e consolidação do boot duplicado `0_PB_Init.lua` / `PB_Init.lua`.

A primeira ação da implementação será salvar este plano em `.metadocs/implementation_plans/Plano de Implementação - Desacoplamento Nativo do Generator Powered Buildings.md`.

## Key Changes

- Remover a dependência externa em `42.15/mod.info` e adicionar incompatibilidade explícita com `buildinggenpowerv2`, `buildinggenpowermp` e `buildinggenpower`, para evitar dois sistemas elétricos carregados ao mesmo tempo.
- Vendorizar do mod local `GeneratorPlus2` todos os módulos ausentes de `shared/core`, `shared/data`, `shared/utils`, `shared/actions`, `server`, `server/building`, `server/fuel`, `server/power`, `server/heating` e client sync/commands.
- Renomear arquivos, globals, comandos, logs e módulos para padrão LKS:
  - `PoweredBuildings` / `PB` -> `LKS_EletricidadeConstrucao`
  - `PB_*` -> `LKS_EletricidadeConstrucao_*`
  - comandos de rede `"PoweredBuildings"` -> `"LKS_EletricidadeConstrucao"`
  - chaves novas de ModData -> prefixo `LKS_`
- Manter leitura de chaves legadas apenas em rotina de migração, convertendo saves antigos para chaves `LKS_` sem manter aliases públicos permanentes.
- Consolidar inicialização em um único entrypoint real, preferencialmente `shared/0_LKS_EletricidadeConstrucao_Init.lua`, e deixar qualquer arquivo legado necessário como shim mínimo, sem duplicar boot.
- Reorganizar o módulo como parte da arquitetura LKS:
  - núcleo/config/logger/runtime em `shared`
  - dados e utilitários em `shared`
  - ações compartilhadas em `shared/actions`
  - distribuição elétrica, combustível, barris, aquecimento e scanner de construção em `server`
  - menus, UI, sync e comandos client em `client`
- Incorporar `sandbox-options.txt` com opções LKS para ativação modular:
  - eletricidade realista
  - aquecimento/climatização
  - barris de combustível
  - refrigeração
  - lavanderia
  - culinária
  - debug/dev tools
- Adaptar `LKS_ApplianceManager` para respeitar flags de sandbox antes de registrar hooks e drivers.
- Manter homenagem no topo dos arquivos derivados do Generator Powered Buildings, com autor, nome original, Workshop ID `3597471949` e nota de adaptação nativa ao LKS.
- Atualizar docs: README, Steam readme, roadmap, histórico e walkthrough novo explicando que Generator Powered Buildings foi incorporado nativamente e não é mais dependência.

## Interfaces And Translations

- Criar/atualizar traduções em:
  - `common/media/lua/shared/Translate/PTBR/*.json`
  - `common/media/lua/shared/Translate/EN/*.json`
- Todo texto visível ao usuário deve ter chave em tradução; fallbacks no código podem existir, mas em PT-BR.
- Renomear chaves novas para prefixo LKS, evitando novas chaves `IGUI_PB_*` e `Sandbox_GeneratorPoweredBuildings_*`.
- Preservar chaves antigas só quando necessário para migração ou compatibilidade com saves existentes, documentando como legado.
- Assets vindos do GeneratorPlus2 devem ser renomeados para padrão `LKS_` quando ainda não existirem equivalentes; assets já adaptados no LKS devem prevalecer.

## Test Plan

- Validações automatizadas/static:
  - `.venv\Scripts\python.exe tools\auditoria_mod.py validar-sintaxe`
  - `.venv\Scripts\python.exe tools\auditoria_mod.py auditar-traducoes --ignorar-nativas`
  - `.venv\Scripts\python.exe tools\auditoria_mod.py auditar-caminhos`
  - buscar resíduos indevidos com `rg "PoweredBuildings|PB_|buildinggenpowerv2|buildinggenpowermp|buildinggenpower"` e aceitar apenas créditos, docs, incompatibilidade e migração legada.
- Teste manual no jogo, sem GeneratorPlus2 instalado:
  - criar/abrir mundo com apenas LKS SuperMod Patch ativo
  - confirmar que o mod carrega sem erro no console
  - conectar gerador a uma construção
  - abrir janela de informações elétricas pelo gerador e por interruptor
  - ligar/desligar gerador e validar energia em luzes/eletrodomésticos
  - conectar múltiplos geradores e validar compartilhamento de carga
  - vincular/desvincular barril e validar combustível agregado
  - alternar aquecimento e temperatura alvo
  - salvar, sair, reabrir e validar persistência/migração
  - testar geladeiras, freezer, lavadora, secadora, combo e fogão/micro-ondas com flags de sandbox ligadas/desligadas
- Teste de conflito:
  - ativar GeneratorPlus2 junto com LKS e confirmar que o jogo bloqueia via incompatibilidade, em vez de carregar dois sistemas.

## Assumptions

- A entrega será completa, não mínima: remover dependência externa, importar funcionalidade, renomear para `LKS_`, modularizar sandbox e documentar.
- Não haverá framework novo de testes; validação será por auditoria estática, busca textual e roteiro manual dentro do Project Zomboid.
- O código final não deve manter namespace público `PoweredBuildings`; qualquer referência antiga deve ficar limitada a migração de dados e créditos.
- PT-BR é a tradução principal; EN entra como fallback organizado em arquivo próprio para facilitar tradução por outros modders.
