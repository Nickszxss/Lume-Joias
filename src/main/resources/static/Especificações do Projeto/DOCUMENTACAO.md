# DOCUMENTACAO.md — Sistema de Gerenciamento de Estoque (Lume Joias)

## Sistema
O **Lume Joias** é um Sistema de Gerenciamento de Estoque projetado para controlar o fluxo de mercadorias de uma empresa de joias com **5 filiais**. O sistema permite controle preciso de produtos, alterações manuais de estoque (entradas e saídas), transferências entre filiais, pedidos de compra para reposição e relatórios gráficos com indicadores em tempo real.

```text
GitHub Pages:
https://Nickszxss.github.io/Lume-Joias/
```

---

## Tecnologias
- **Backend**: Java 17, Spring Boot (Spring Web, Spring JDBC)
- **Segurança**: BCryptPasswordEncoder para hash de senhas
- **Banco de Dados**: PostgreSQL hospedado no Supabase via Pooler IPv4/IPv6 (`aws-0-us-east-1.pooler.supabase.com:6543`)
- **Frontend**: HTML5, CSS3, JavaScript (Chart.js para gráficos, Single Page Application)
- **Testes**: JUnit 5, Spring Boot Test (23 testes de integração com 100% de aprovação)
- **Versionamento**: Git

---

## Filiais
O sistema opera com exatamente 5 filiais oficiais:
1. **Filial Centro** (ID 1)
2. **Filial Norte** (ID 2)
3. **Filial Sul** (ID 3)
4. **Filial Leste** (ID 4)
5. **Filial Oeste** (ID 5)

Todos os nomes genéricos ("Filial 1", "Filial 2", etc.) foram substituídos nos bancos de dados Supabase, controladores Java, telas frontend, seletores e relatórios.

---

## Produtos Cadastrados
O catálogo do sistema é composto por joias legítimas cadastradas e persistidas no Supabase:
- **Anel de Ouro 18K** (`JOIA-001`) — Qtd. Mínima: 10
- **Anel de Prata 950** (`JOIA-002`) — Qtd. Mínima: 15
- **Aliança de Ouro 18K** (`JOIA-003`) — Qtd. Mínima: 8
- **Brinco de Ouro 18K** (`JOIA-004`) — Qtd. Mínima: 10
- **Brinco de Prata 950** (`JOIA-005`) — Qtd. Mínima: 20
- **Colar de Ouro 18K** (`JOIA-006`) — Qtd. Mínima: 5
- **Colar de Prata 950** (`JOIA-007`) — Qtd. Mínima: 12
- **Pulseira de Ouro 18K** (`JOIA-008`) — Qtd. Mínima: 8
- **Pulseira de Prata 950** (`JOIA-009`) — Qtd. Mínima: 15
- **Pingente de Ouro 18K** (`JOIA-010`) — Qtd. Mínima: 8
- **Pingente de Prata 950** (`JOIA-011`) — Qtd. Mínima: 15

---

## Estoque por Filial
Cada produto possui um registro independente de quantidade e status por filial na tabela `estoques` do Supabase. Nenhuma quantidade é global; o estoque do Centro é mantido separado do estoque da Norte, Sul, Leste e Oeste.

---

## Status do Estoque
O status é calculated dinamicamente com base na quantidade disponível e no limite de quantidade mínima (`qtd_minima`) configurada para o produto:
- **Suficiente**: Quantidade maior que a quantidade mínima.
- **Baixo**: Quantidade menor ou igual à quantidade mínima e maior que zero.
- **Zerado**: Quantidade igual a 0.

---

## Usuários e Permissões

| Nome     | Email                      | Senha       | Cargo       | Permissões e Acesso |
| -------- | -------------------------- | ----------- | ----------- | ------------------- |
| Anderson | `anderson.func@empresa.com` | `etec2026@DS` | Funcionário | Acesso restrito à Filial Centro (ID 1). Ajusta estoque e solicita transferência da sua filial. Não realiza pedidos de compra. |
| Robson   | `robson.grt@empresa.com`   | `etec2026@DS` | Gerente     | Acesso total às 5 filiais. Ajusta estoque, solicita/conclui transferências, cria pedidos de compra e visualiza relatórios globais. |
| Isabella | `isabella.func@empresa.com` | `etec2026@DS` | Funcionário | Acesso restrito à Filial Norte (ID 2). Ajusta estoque e solicita transferência da sua filial. Não realiza pedidos de compra. |
| Manuella | `manuella.grt@empresa.com`  | `etec2026@DS` | Gerente     | Acesso total às 5 filiais. Ajusta estoque, solicita/conclui transferências, cria pedidos de compra e visualiza relatórios globais. |

---

## Alteração de Estoque
- Permite aumentos (entradas) e diminuições (saídas) manuais.
- **Bloqueio de estoque negativo**: Caso um usuário tente retirar uma quantidade superior ao estoque disponível, a operação é bloqueada com mensagem de erro explicativa ("Não há quantidade suficiente em estoque...").
- Toda alteração atualiza a tabela `estoques`, recalcula o status e grava imediatamente o registro correspondente na tabela `movimentacoes` no Supabase.

---

## Histórico de Movimentações
Todas as alterações manuais e transferências geram registros permanentes no banco de dados na tabela `movimentacoes`, registrando:
- Produto
- Filial
- Tipo de movimentação (`entrada` / `saida`)
- Quantidade anterior
- Nova quantidade
- Usuário responsável
- Data e horário (`created_at`)
- Motivo informado

---

## Transferências entre Filiais
- Permite mover produtos entre filiais distintas.
- **Validações**:
  - Filial de origem e destino não podem ser iguais.
  - Quantidade deve ser maior que zero.
  - Filial de origem deve possuir saldo de estoque suficiente para a quantidade solicitada.
- Ao concluir uma transferência, a filial de origem perde o estoque, a filial de destino recebe a quantidade e ambas as movimentações são registradas no histórico.

---

## Pedidos de Compra
- Módulo de reposição exclusivo para o perfil **Gerente**.
- Permite selecionar o produto, a filial de destino e a quantidade desejada.
- Funcionários que tentam realizar pedidos de compra recebem resposta HTTP 403 Forbidden.

---

## Gráficos e Dashboard
- Renderizados no frontend usando **Chart.js** alimentados por dados reais do Supabase via `/api/dashboard`.
- Exibe KPIs de itens em estoque, produtos cadastrados, itens com estoque baixo/zerado e transferências pendentes.
- Exibe gráfico de barras com distribuição de itens por filial e gráfico de linhas com movimentações semanais reais consultadas no Supabase.
- Gerentes visualizam dados consolidados das 5 filiais ou filtrados por filial específica. Funcionários visualizam somente os dados referentes à sua própria filial.

---

## Estrutura do Banco de Dados (Supabase)
Tabelas mantidas no PostgreSQL:
- `usuarios`: Cadastro de usuários, cargos (`gerente`/`funcionario`), hashes de senha e vinculação de filial.
- `filiais`: Lista das 5 filiais oficiais.
- `produtos`: Cadastro do catálogo de joias com código/SKU e quantidade mínima.
- `estoques`: Relação (filial_id, produto_id, quantidade, status, updated_at).
- `movimentacoes`: Histórico completo de auditoria de entradas e saídas.
- `transferencias`: Registro de solicitações e conclusões de transferências entre filiais.
- `pedidos_compra` e `itens_pedido_compra`: Registro de solicitações de compras realizadas por gerentes.

---

## Relatório das Modificações Realizadas

### Modificação 1
**Modificação**: Nomes das Filiais no Banco e Sistema.
**Problema**: O banco e frontend utilizavam "Filial 1", "Filial 2", etc.
**Solução**: Atualizadas todas as filiais no Supabase para `Filial Centro`, `Filial Norte`, `Filial Sul`, `Filial Leste` e `Filial Oeste`.
**Arquivos**: `DatabaseUserInitializer.java`, `main.js`, `index.html`.

### Modificação 2
**Modificação**: Cadastro e Semeadura do Catálogo de Joias e Estoque Inicial.
**Problema**: A tabela `produtos` e `estoques` no Supabase estavam vazias.
**Solução**: Implementado cadastrador automático de 11 produtos de joalheria e estipulado estoque inicial variado entre as 5 filiais com reajuste automático de status.
**Arquivos**: `DatabaseUserInitializer.java`.

### Modificação 3
**Modificação**: Implementação Completa da API REST Java Spring Boot.
**Problema**: O backend possuía apenas rotas de login.
**Solução**: Criados Controllers e Services para `/api/filiais`, `/api/produtos`, `/api/estoque`, `/api/transferencias`, `/api/pedidos`, `/api/historico` e `/api/dashboard`.
**Arquivos**: Pacotes `controller`, `service` e `dto` em `src/main/java/com/nicoly/LumeEstoque/`.

### Modificação 4
**Modificação**: Testes de Integração e Organização de Documentação.
**Problema**: Necessidade de garantir 100% de conformidade técnica e organizar a localização dos arquivos de especificação.
**Solução**: Criada suíte `EstoqueIntegrationTest.java` com 23 testes passando com sucesso. Organizado o arquivo `DOCUMENTACAO.md` dentro de `src/main/resources/static/especificações do projeto/DOCUMENTACAO.md`.

---

## Pendências

```text
Nenhuma pendência identificada. O sistema encontra-se 100% testado, validado e integrado ao Supabase.
```
