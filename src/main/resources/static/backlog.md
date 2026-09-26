# Backlog — Sistema de Gerenciamento de Estoque (5 Filiais)

> **Versão:** 1.0
> **Data:** 15/09/2026
> **Origem:** Especificação Técnica v1.0 (03/09/2026)
> **Stack:** Java + JavaScript + HTML5/CSS3 + PostgreSQL + Jules + Git

---

## Épico 1 — Banco de Dados (PostgreSQL)
## 📋 Épico 1 — Banco de Dados (PostgreSQL)

**Base:** RF-02, RF-06 a RF-15, RF-17, RNF-08

1. **Criar schema e tipos ENUM** — `tipo` (gerente/funcionario), `status` (suficiente/baixo/zerado), tipos de movimentação
2. **Criar tabelas core** — `filiais`, `usuarios`, `produtos`, `estoques` (UNIQUE `filial_id` + `produto_id`)
3. **Criar tabelas de histórico** — `movimentacoes` (com `usuario_id`, `qtd_anterior`, `qtd_nova`, `created_at`), `transferencias` (origem/destino/produto/quantidade), `pedidos_compra`
4. **Implementar trigger `atualizar_status_estoque()`** — recalcula status automaticamente com base em `qtd_minima` (RF-11, RNF-12)
5. **Seed de dados** — 5 filiais, usuários de teste (1 gerente + 1 funcionário por filial), produtos e estoques iniciais

## Épico 2 — Camada de Conexão (Jules)
## 📋 Épico 2 — Camada de Conexão (Jules)

**Base:** decisão arquitetural da seção 1 da SPEC

6. **Configurar conexão Jules ↔ PostgreSQL** — pool de conexões, arquivo de configuração de credenciais
7. **Definir padrão de execução de queries** — repositório genérico para consultas SQL parametrizadas

## Épico 3 — Autenticação e Autorização (Java)
## 📋 Épico 3 — Autenticação e Autorização (Java)

**Base:** RF-01 a RF-05, RF-26, RNF-18

8. **`AuthService.java` — `autenticar()`** — validar login contra tabela `usuarios` (RF-01)
9. **Gerenciamento de sessão** — manter usuário logado (filial + tipo) entre requisições
10. **Middleware/regra de autorização** — gerente acessa as 5 filiais (RF-03); funcionário limitado à sua filial (RF-04)
11. **Bloqueio de acesso (HTTP 403)** — impedir funcionário de acessar dados de outra filial (RF-05)

## Épico 4 — Cadastro de Produtos e Ajuste de Estoque
## 📋 Épico 4 — Cadastro de Produtos e Ajuste de Estoque

**Base:** RF-06 a RF-13

12. **CRUD de produtos** — cadastro, listagem, edição (gerente) (RF-06)
13. **`EstoqueService.java` — `ajustarQuantidade()`** — entrada (RF-08) e saída (RF-09) com validação de saldo
14. **Validação por tipo de usuário** — gerente altera estoque livremente; funcionário conforme regra definida (RF-10)
15. **Registro em `movimentacoes`** — produto, qtd anterior, qtd nova, usuário, data/hora (RF-12, RF-13, RF-14)

## Épico 5 — Transferências entre Filiais
## 📋 Épico 5 — Transferências entre Filiais

**Base:** RF-15 a RF-20

16. **`TransferenciaService.java` — `solicitar()`** — registrar origem, destino, produto, quantidade (RF-16, RF-17)
17. **`concluir()`** — decrementar origem + incrementar destino (RF-18, RF-19)
18. **Geração automática do histórico** — 2 registros em `movimentacoes` (saída na origem, entrada no destino) (RF-20)

## Épico 6 — Pedidos de Compra
## 📋 Épico 6 — Pedidos de Compra

**Base:** RF-21 a RF-23, RNF-06/07/13/17

19. **`PedidoService.java` — `criar()`** — selecionar produto + quantidade, registrar pedido interno (RF-22)
20. **Regra de autorização** — somente gerente cria pedidos; bloqueio para funcionário (RF-21, RNF-17)
21. **`EstoqueService.java` — `estoqueBaixoZerado()`** — consulta de alertas com base no `status` (RF-23)

## Épico 7 — Relatórios e Gráficos
## 📋 Épico 7 — Relatórios e Gráficos

**Base:** RF-24, RF-25, RF-26

22. **`RelatorioService.java`** — queries agregadas de estoque e movimentações
23. **Filtro por perfil** — gerente vê as 5 filiais (RF-25); funcionário vê só a sua, com `WHERE filial_id` (RF-26)
24. **Gráficos em JavaScript (frontend)** — consumir endpoints e renderizar visualizações (RF-24)

## Épico 8 — Frontend (Protótipo Web)
## 📋 Épico 8 — Frontend (Protótipo Web)

**Base:** RNF-10

25. **Telas de autenticação** — login, controle de acesso às funcionalidades por perfil
26. **Telas de estoque** — listagem por filial, cadastro de produto, ajuste de quantidade (entrada/saída), alertas
27. **Telas de transferência e pedidos** — solicitação de transferência, criação de pedido de compra
28. **Dashboard de gráficos** — visualização conforme perfil logado
29. **Responsividade** — protótipo HTML5/CSS3 acessível em desktop e mobile (browser)

## Épico 9 — Qualidade e Versionamento
## 📋 Épico 9 — Qualidade e Versionamento

**Base:** decisão de Git + matriz de rastreabilidade

30. **Repositório Git** — estrutura inicial, `.gitignore`, branches (`main` + feature branches)
31. **Validação da matriz de rastreabilidade** — checar RF-01 a RF-26 e RNF-01 a RNF-18 implementados
32. **Testes de regras críticas** — autorização (gerente vs. funcionário), trigger de status, integridade das transferências
33. **Verificação de escopo negativo** — confirmar ausência de vendas, caixa, clientes, notas fiscais (RNF-01 a RNF-09, RNF-16)

---

##  Ordem de Execução Sugerida
## 🗺️ Ordem de Execução Sugerida

```javascript
Épico 1 → Épico 2 → Épico 3 → Épico 4 → Épico 5 → Épico 6 → Épico 7/8 (paralelo) → Épico 9
```

Os épicos **3** e **4** são a espinha dorsal do sistema; sem eles nada mais funciona.