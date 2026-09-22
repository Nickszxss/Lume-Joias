# Especificação Técnica — Sistema de Gerenciamento de Estoque

&gt; **Versão:** 1.0  
&gt; **Data:** 03/09/2026  
&gt; **Baseado em:** Documento de Requisitos (Sistema de Gerenciamento de Estoque — 5 Filiais)  
&gt; **Stack:** Java + JavaScript + HTML5/CSS3 + PostgreSQL + Jules (conexão com o banco de dados) + Git

---

## 1. Visão Geral

Esta especificação técnica detalha a implementação do **Sistema de Gerenciamento de Estoque para 5 Filiais**, mapeando cada requisito funcional e não-funcional do documento de requisitos original para componentes concretos da arquitetura proposta.

| Aspecto | Decisão Técnica |
|---------|-----------------|
| **Arquitetura** | Monolítica em camadas (Presentation → Backend Java → Banco de Dados) |
| **Backend** | Java |
| **Conexão com o banco** | Jules (em substituição ao Node.js, para conectar a aplicação ao banco de dados) |
| **Banco de Dados** | PostgreSQL (consultas e regras diretamente em SQL) |
| **Autenticação** | Login validado no backend Java com dados armazenados no PostgreSQL |
| **Autorização** | Controle de acesso baseado no enum `tipo` (`gerente` / `funcionario`) |
| **Frontend** | HTML5/CSS3/JavaScript (protótipo web) |
| **Gráficos** | Gráficos em JavaScript (frontend) + dados agregados via consultas SQL no PostgreSQL |
| **Versionamento** | Git |

---

## 2. Matriz de Rastreabilidade de Requisitos

### 2.1 Requisitos Funcionais → Implementação

| ID | Requisito (Documento Original) | Componente Técnico | Arquivo / Endpoint | Status |
|----|----------------------------------|-------------------|-------------------|--------|
| **RF-01** | Login de usuários | Validação de login no backend Java | `AuthService.java` — `autenticar()` 
| **RF-02** | Dois tipos de usuário: gerente e funcionário | Enum `tipo` no PostgreSQL | `schema_estoque.sql` — `tipo ENUM` 
| **RF-03** | Gerente acessa 5 filiais | Regra de autorização (`gerente`) + query sem filtro de filial | `AuthService.java` 
| **RF-04** | Funcionário acessa só sua filial | Verificação de filial + `WHERE filial_id` nas consultas | `AuthService.java` + consultas SQL 
| **RF-05** | Impedir acesso a outras filiais | Bloqueio de acesso (HTTP 403) no backend Java | `AuthService.java` 
| **RF-06** | Cadastrar produtos | CRUD Produto | Tabela `produtos` no PostgreSQL + funcionalidade Java (cadastro) 
| **RF-07** | Armazenar quantidade por filial | Tabela `estoques` (filial_id + produto_id UNIQUE) | `schema_estoque.sql` 
| **RF-08** | Aumentar quantidade | `ajustarQuantidade()` tipo `entrada` | `EstoqueService.java` 
| **RF-09** | Diminuir quantidade | `ajustarQuantidade()` tipo `saida` | `EstoqueService.java` 
| **RF-10** | Gerente altera estoque | Mesma operação, validação por tipo de usuário | `EstoqueService.java` 
| **RF-11** | Status: suficiente, baixo, zerado | Trigger SQL + campo `status` ENUM | `schema_estoque.sql` — `atualizar_status_estoque()` 
| **RF-12** | Registrar quem alterou | `usuario_id` FK em `movimentacoes` | `schema_estoque.sql` 
| **RF-13** | Histórico: produto, qtd anterior, qtd nova | Tabela `movimentacoes` | `schema_estoque.sql` 
| **RF-14** | Histórico: usuário e data/hora | `usuario_id` + `created_at` | `schema_estoque.sql` 
| **RF-15** | Histórico de transferências | Tabela `transferencias` + `movimentacoes` | `schema_estoque.sql` 
| **RF-16** | Solicitar transferência | Funcionalidade Java de solicitação de transferência | `TransferenciaService.java` — `solicitar()` 
| **RF-17** | Registrar origem, destino, produto, quantidade | Campos `origem_id`, `destino_id`, `produto_id`, `quantidade` | `schema_estoque.sql` 
| **RF-18** | Transferência altera estoque origem | `concluir()` decrementa origem | `TransferenciaService.java` 
| **RF-19** | Transferência altera estoque destino | `concluir()` incrementa destino | `TransferenciaService.java` 
| **RF-20** | Transferência no histórico | Gera 2 registros em `movimentacoes` | `TransferenciaService.java` 
| **RF-21** | Somente gerente cria pedido de compra | Regra de autorização (`gerente`) no backend Java | `PedidoService.java` 
| **RF-22** | Selecionar produto e quantidade | Funcionalidade Java de criação de pedido | `PedidoService.java` — `criar()` 
| **RF-23** | Identificar estoque baixo/zerado | Consulta de alertas de estoque | `EstoqueService.java` — `estoqueBaixoZerado()` 
| **RF-24** | Gráficos de estoque e movimentações | Dados agregados via SQL + gráficos em JavaScript | `RelatorioService.java` + frontend JS 
| **RF-25** | Gerente vê gráficos de 5 filiais | Query sem filtro de filial | `RelatorioService.java` 
| **RF-26** | Funcionário vê só sua filial | `WHERE filial_id = filial do usuário logado` | Todas as consultas SQL 

### 2.2 Requisitos Não-Funcionais → Implementação

| ID | Requisito Não-Funcional | Solução Técnica |
|----|------------------------|-----------------|
| **RNF-01** | Não realiza vendas | Sistema registra apenas ajustes de estoque (entrada/saída) sem módulo de vendas |
| **RNF-02** | Não possui caixa | Sem tabela/função financeira |
| **RNF-03** | Não controla clientes | Sem tabela `clientes` |
| **RNF-04** | Não realiza pagamentos | Sem integração com gateways |
| **RNF-05** | Não emite notas fiscais | Sem módulo fiscal |
| **RNF-06** | Não compra automaticamente | Pedidos de compra são criados manualmente pelo gerente |
| **RNF-07** | Sem integração com fornecedores | `pedidos_compra` é registro interno apenas |
| **RNF-08** | Não controla preços de venda | Tabela `produtos` não possui campo `preco` |
| **RNF-09** | Sem controle financeiro | Sem tabelas de contas/receitas/despesas |
| **RNF-10** | Sem app mobile | Frontend web responsivo (protótipo HTML) |
| **RNF-11** | Sem IA | Sem módulos de ML/predição |
| **RNF-12** | Sem previsão automática | Status baseado em `qtd_minima` configurada manualmente |
| **RNF-13** | Sem pedidos automáticos | Pedidos criados manualmente via funcionalidade Java |
| **RNF-14** | Sem recomendação de produtos | Sem algoritmo de recomendação |
| **RNF-15** | Sem marketing | Sem módulo de campanhas |
| **RNF-16** | Sem funcionalidades de vendas | Apenas ajuste de estoque com motivo livre |
| **RNF-17** | Funcionário não realiza compras | Regra de autorização no backend Java bloqueia a criação de pedidos por funcionários |
| **RNF-18** | Funcionário não vê outras filiais | Verificação de filial + filtro em todas as consultas SQL |

---

## 3. Arquitetura de Software

### 3.1 Diagrama de Camadas