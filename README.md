# LKS SuperMod Patch

Faz correções, melhorias de UX/UI, ajustes de scripts, traduções PT-BR e incorporações nativas de mecânicas para Project Zomboid Build 42. Todos os créditos aos criadores originais referenciados.

> [!IMPORTANT]
> Este mod agora é carregável de forma independente para as mecânicas incorporadas nativamente. Não carregue o **Generator Powered Buildings / GeneratorPlus2** junto com este patch, pois a funcionalidade foi integrada ao módulo `LKS_EletricidadeConstrucao`.

## Sobre o Patch

O projeto evoluiu de um patch de compatibilidade para uma base modular LKS. Mods pequenos e escolhidos são incorporados nativamente quando isso reduz dependências, melhora organização e permite manutenção centralizada.

## Funcionalidades Principais

- **Eletricidade de Construção LKS:** geradores conectados a construções, rede compartilhada, carga/strain, UI de energia, barris de combustível e aquecimento.
- **Refrigeração LKS:** ligar/desligar geladeiras e freezers com estados persistentes.
- **Lavanderia LKS:** menus e ícones dinâmicos para lavadoras, secadoras e combos.
- **Culinária LKS:** controle elétrico e alertas para fogões e micro-ondas.
- **Tradução PT-BR:** chaves organizadas em arquivos de tradução para facilitar manutenção e novas localizações.

## Créditos e Compatibilidade

| Referência Original | Autor | ID Workshop | Status |
| :--- | :--- | :--- | :--- |
| Generator Powered Buildings | Beathoven | 3597471949 | Incorporado nativamente; não carregar junto |
| Fridges Off! | 4422 / Erick | 2853974107 | Incorporado nativamente |

## Instalação

1. Inscreva-se neste patch.
2. Não ative o Generator Powered Buildings / GeneratorPlus2 junto com este mod.
3. Coloque o LKS SuperMod Patch no final da ordem de carregamento quando usar outros mods compatíveis.

## Ferramentas de Desenvolvimento

O repositório conta com utilitários em Python para apoiar auditoria de código, testes de integridade e processamento de assets.

### Auditoria Geral

```bash
python tools/auditoria_mod.py validar-sintaxe
python tools/auditoria_mod.py auditar-traducoes --ignorar-nativas
python tools/auditoria_mod.py auditar-caminhos
```

### Tools Assets

```bash
python tools/LKS_Tools.py
python tools/LKS_Tools.py -a
python tools/LKS_Tools.py -b <termo_do_asset>
```
