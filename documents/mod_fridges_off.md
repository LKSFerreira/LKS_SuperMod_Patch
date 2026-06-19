# Documentação de Referência - Fridges Off! (Mod Original)

Este documento reúne e analisa o funcionamento, recursos, bugs conhecidos e limitações do mod original **Fridges Off!** (Workshop ID: `2853974107`, Mod ID: `fridgesoff`) desenvolvido por **4422**. 

Essas informações servem de base teórica para fagocitar e incorporar a lógica de desligamento de geladeiras e freezers nativamente no nosso mod patch (dando os devidos créditos de autoria original).

---

## 🎯 O que o Mod Faz?
O **Fridges Off!** adiciona uma mecânica realista de controle elétrico de eletrodomésticos, permitindo que os jogadores liguem, desliguem ou retirem da tomada (unplug) as geladeiras e congeladores (freezers) do jogo.

---

## ⚙️ Como Funciona? (Mecânica e Fluxo de Jogo)
- Adiciona uma opção no menu de contexto dos eletrodomésticos de refrigeração para desligar ou desconectar o aparelho da tomada.
- Ao desligar a geladeira ou freezer, o consumo elétrico daquele aparelho específico cessa, reduzindo a carga total da rede do abrigo/gerador.
- Naturalmente, ao desligar o aparelho, o processo de resfriamento cessa e os alimentos armazenados nele começam a estragar no ritmo normal de temperatura ambiente.

---

## ⚠️ Bugs Conhecidos e Limitações da Build 42 (Workshop Reports)
O mod original foi desenvolvido primariamente para a Build 41 e, embora os jogadores relatem que ele "semi-funciona" na Build 42 (Build 42.15/42.17 SP), ele apresenta problemas graves na versão atual:

1. **Textos Quebrados**:
   - Várias mensagens de interface e opções de menu aparecem com formatação quebrada ou chaves de tradução ausentes na Build 42.

2. **Perda de Identidade do Congelador (Freezer)**:
   - Na Build 42, os congeladores desligados passam a agir meramente como geladeiras normais quando desligados e religados, perdendo o isolamento térmico de freezer e o balanceamento realista de conservação.

3. **Inatividade Elétrica (Geladeiras Infinitas)**:
   - Jogadores relatam um bug crítico onde a geladeira desligada continua refrigerando/conservando os alimentos perfeitamente, porém **sem consumir energia** da rede. Isso quebra o balanceamento e a proposta realista do jogo.

4. **Instabilidade no Multiplayer (Dedicated MP)**:
   - Não funciona ou é extremamente instável em servidores dedicados multiplayer nas versões Build 42.13+.

5. **Correções de Terceiros (Fixes)**:
   - Devido ao abandono do mod original (última atualização em dezembro de 2024), a comunidade criou patches alternativos de correção, como o *Fridges Off! B42 Fix* (Workshop ID: `3682455407`).

---

## ⚖️ Estratégia de Fagocitação (LKS Patch)
Para evitar que o usuário precise instalar múltiplos mods e lidar com bugs de compatibilidade entre o `Generator Powered Buildings` e o `Fridges Off!`, iremos:
- Incorporar a funcionalidade de ligar/desligar geladeiras diretamente no código do **LKS SuperMod Patch**.
- Corrigir a lógica de consumo e refrigeração na Build 42 para impedir "geladeiras infinitas sem energia".
- Tratar o isolamento do freezer separadamente da geladeira para preservar a conservação realista dos congelados.
- Dar os créditos de autoria da ideia original ao criador **4422** na descrição do Steam Workshop e no README.
