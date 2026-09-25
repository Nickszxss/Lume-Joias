# AGENTS.md — Sistema de Gerenciamento de Estoque (5 Filiais)

> Guia para agentes (IA ou humanos) trabalhando neste repositório.
> Baseado na Especificação Técnica v1.0 (03/09/2026) e no Backlog v1.0 (15/09/2026).

---

## 1. Visão Geral do Projeto

Este é um sistema de gerenciamento de estoque para 5 filiais, com dois perfis de usuário: gerente e funcionario (enum `tipo` no PostgreSQL). O sistema controla produtos, ajustes de estoque (entrada e saída), transferências entre filiais, pedidos de compra manuais e relatórios com gráficos.

Atenção: este NÃO é um sistema de vendas. Leia a seção 6 (Escopo Negativo) antes de propor qualquer funcionalidade.

## 2. Stack e Arquitetura

O backend é Java, com conexão ao banco feita via Jules (em substituição ao Node.js). O banco de dados é PostgreSQL, onde as consultas e regras vivem diretamente em SQL. A autenticação é validada no backend Java com dados armazenados no PostgreSQL, e a autorização é baseada no enum `tipo` (gerente ou funcionario). O frontend é um protótipo web em HTML5, CSS3 e JavaScript, com gráficos renderizados em JavaScript a partir de dados agregados por consultas SQL. O versionamento é Git.

A arquitetura é monolítica em camadas: Presentation (frontend) → Backend Java → Banco de Dados (PostgreSQL).

As camadas esperadas são: telas em HTML5/CSS3/JS na apresentação; services Java no backend (AuthService, EstoqueService, TransferenciaService, PedidoService, RelatorioService); e o schema PostgreSQL com as tabelas filiais, usuarios, produtos, estoques, movimentacoes, transferencias e pedidos_compra.

## 3. Regras de Negócio Críticas

Estas regras são inegociáveis. Ao implementar ou modificar qualquer código, preserve-as:

1. O perfil gerente acessa as 5 filiais, sem filtro de filial nas consultas (RF-03, RF-25).
2. O perfil funcionario acessa somente sua filial. Todas as consultas devem conter `WHERE filial_id = <filial do usuário logado>` (RF-04, RF-26, RNF-18). Violação deve retornar HTTP 403 (RF-05).
3. Somente gerente cria pedidos de compra (RF-21, RNF-17) e altera estoque livremente (RF-10).
4. O status do estoque (suficiente, baixo ou zerado) é calculado por trigger SQL (`atualizar_status_estoque()`) com base em `qtd_minima`. Nunca calcular status no frontend (RF-11, RNF-12).
5. Toda alteração de estoque gera registro em `movimentacoes`: produto, quantidade anterior, quantidade nova, usuário (FK `usuario_id`) e data/hora (`created_at`) (RF-12, RF-13, RF-14).
6. Toda transferência concluída decrementa a origem, incrementa o destino e gera 2 registros em `movimentacoes` — uma saída na origem e uma entrada no destino (RF-18, RF-19, RF-20).
7. A tabela `estoques` possui UNIQUE(`filial_id`, `produto_id`) — uma linha por produto por filial (RF-07).
8. Ajustes de estoque são apenas do tipo `entrada` ou `saida`, com motivo livre. Não existe venda (RNF-01, RNF-16).
9. A tabela `produtos` não possui campo `preco` — o sistema não controla preços (RNF-08).

## 4. Convenções de Código

Mensagens de commit e nomes de branch são em português. As branches seguem o padrão `main` (estável) + `feature/<epico>-<descricao-curta>`. Nomes de tabelas, colunas e endpoints usam snake_case em minúsculas, consistentes com o schema. Classes Java de regra de negócio seguem o padrão `*Service.java` definido na SPEC.

No SQL, sempre usar queries parametrizadas — nunca concatenar valores de usuário. Regras de estoque (status, integridade) vivem no banco, em triggers e constraints, não apenas no Java. Não adicionar tabelas ou colunas fora do schema aprovado sem atualizar a matriz de rastreabilidade.

Em segurança: a autorização é sempre verificada no backend Java, nunca apenas ocultando botões no frontend. Credenciais do banco ficam em arquivo de configuração fora do versionamento (`.gitignore`).

## 5. Fluxo de Trabalho (Backlog)

A ordem de execução dos épicos é: Épico 1 (Banco de Dados) → Épico 2 (Conexão Jules) → Épico 3 (Autenticação e Autorização) → Épico 4 (Produtos e Estoque) → Épico 5 (Transferências) → Épico 6 (Pedidos) → Épicos 7 e 8 (Relatórios e Frontend, em paralelo) → Épico 9 (Qualidade). Os épicos 3 e 4 são a espinha dorsal do sistema; sem eles, nada mais funciona.

Para cada tarefa: primeiro leia o backlog (`backlog_estoque.md`) e identifique os RFs e RNFs cobertos; depois implemente mantendo a matriz de rastreabilidade (cada RF deve mapear para um componente/arquivo); ao concluir, marque a tarefa e verifique os RFs atendidos.

O backlog completo tem 9 épicos e 33 tarefas, distribuídos assim: Épico 1 (tarefas 1 a 5) — banco de dados PostgreSQL; Épico 2 (tarefas 6 e 7) — camada de conexão Jules; Épico 3 (tarefas 8 a 11) — autenticação e autorização; Épico 4 (tarefas 12 a 15) — produtos e ajuste de estoque; Épico 5 (tarefas 16 a 18) — transferências; Épico 6 (tarefas 19 a 21) — pedidos de compra; Épico 7 (tarefas 22 a 24) — relatórios e gráficos; Épico 8 (tarefas 25 a 29) — frontend; Épico 9 (tarefas 30 a 33) — qualidade e versionamento.

## 6. Escopo Negativo (NÃO implementar)

O sistema NÃO possui, e você não deve criar, sugerir ou adicionar:

- Vendas ou módulo de PDV (RNF-01, RNF-16)
- Caixa ou funções financeiras (RNF-02)
- Controle de clientes (RNF-03)
- Pagamentos ou gateways (RNF-04)
- Emissão de notas fiscais (RNF-05)
- Compras automáticas — pedidos são manuais, criados pelo gerente (RNF-06, RNF-13)
- Integração com fornecedores (RNF-07)
- Preços de venda ou campo `preco` em produtos (RNF-08)
- Controle financeiro — contas, receitas, despesas (RNF-09)
- App mobile — apenas web responsivo (RNF-10)
- IA, previsão automática ou recomendação de produtos (RNF-11, RNF-12, RNF-14)
- Marketing ou campanhas (RNF-15)
- Funcionário realizando compras ou acessando outras filiais (RNF-17, RNF-18)

Se um requisito parecer exigir algo dessa lista, pare e confirme com o responsável antes de prosseguir.

## 7. Definition of Done

Uma tarefa só está concluída quando:

- O código implementa todos os RFs e RNFs associados no backlog.
- As regras de autorização foram testadas para ambos os perfis (gerente e funcionario).
- O funcionario é bloqueado (HTTP 403) ao tentar acessar outra filial.
- Toda alteração de estoque persiste em `movimentacoes`.
- O trigger de status recalcula corretamente (suficiente, baixo, zerado).
- Nenhum item do Escopo Negativo foi introduzido.
- O commit está em branch `feature/` com mensagem descritiva em português.

## 8. Arquivos de Referência

O arquivo `backlog_estoque.md` contém o backlog completo com os 9 épicos e 33 tarefas. A Especificação Técnica v1.0 é o documento de origem e contém a matriz de rastreabilidade RF/RNF.