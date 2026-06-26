# Walkthrough - Desacoplamento Nativo do Generator Powered Buildings

## Resumo

O Generator Powered Buildings deixou de ser dependência obrigatória e foi incorporado como módulo nativo `LKS_EletricidadeConstrucao`.

## Mudanças

- Remoção de `require=buildinggenpowerv2` em `42.15/mod.info`.
- Inclusão de incompatibilidade explícita com `buildinggenpowerv2`, `buildinggenpowermp` e `buildinggenpower`.
- Vendorização dos módulos Lua do GeneratorPlus2 com namespace `LKS_EletricidadeConstrucao`.
- Consolidação do boot em `0_LKS_EletricidadeConstrucao_Init.lua`, com `LKS_EletricidadeConstrucao_Init.lua` como shim.
- Inclusão de `common/media/sandbox-options.txt` para ativar/desativar eletricidade realista, aquecimento, barris, refrigeração, lavanderia, culinária e debug.
- Criação de traduções PT-BR e EN para o módulo incorporado.

## Créditos

O comportamento foi adaptado a partir do mod original **Generator Powered Buildings**, de Beathoven, Workshop ID `3597471949`.

## Validação Manual Recomendada

1. Carregar um mundo apenas com LKS SuperMod Patch ativo.
2. Confirmar ausência de erro no console.
3. Conectar um gerador a uma construção.
4. Abrir a janela de informações pelo gerador e por interruptor.
5. Testar múltiplos geradores, barris, aquecimento e persistência após salvar/reabrir.
6. Validar que GeneratorPlus2 não deve ser carregado junto.

## Validação Automatizada Executada

- `validar-sintaxe`: 52/52 arquivos Lua validados com sucesso.
- `auditar-traducoes --ignorar-nativas`: todas as chaves usadas em código possuem tradução local.
- `auditar-caminhos`: nenhum caminho absoluto ou vazamento de dados detectado.
- Busca de resíduos ativos: sem ocorrências indevidas de `PoweredBuildings`, `GeneratorPoweredBuildings`, `PB_` ou `LKS_Eletricidade` antigo em código ativo, manifesto e documentação de usuário.
