# Referência Geral de Ferramentas do Agente

Este documento descreve expectativas independentes de plataforma. Cada agente deve adaptar os nomes concretos das ferramentas ao ambiente em que estiver rodando.

## Princípios

- Prefira ferramentas nativas de leitura, busca e edição quando disponíveis.
- Para busca textual, use uma ferramenta equivalente a `rg`/ripgrep sempre que possível.
- Para edição, prefira operações estruturadas de patch ou substituição controlada.
- Evite criar arquivos por `echo`, redirecionamento de shell ou comandos frágeis quando houver ferramenta de escrita apropriada.
- Não rode comandos destrutivos sem intenção explícita do usuário.
- Não simule execução: se precisar validar, execute o comando real ou declare que não foi possível.

## Categorias

### Exploração

- Listar diretórios e arquivos.
- Ler arquivos relevantes.
- Buscar padrões em texto.
- Inspecionar status Git e diffs.

### Edição

- Aplicar patches pequenos e revisáveis.
- Criar arquivos a partir de templates.
- Mover ou remover arquivos apenas quando isso fizer parte do escopo aprovado.

### Execução

- Rodar testes, builds, linters e scripts locais.
- Preferir comandos do projeto documentados em `README.md`, `.agents/rules/` ou manifestos da stack.
- Informar quando uma validação não puder ser executada por falta de runtime, Docker, credenciais ou dependências.

### Comunicação

- Mantenha o usuário informado em tarefas longas.
- Relate decisões, trade-offs e bloqueios de forma objetiva.
- Ao finalizar, liste mudanças principais e validação executada.
