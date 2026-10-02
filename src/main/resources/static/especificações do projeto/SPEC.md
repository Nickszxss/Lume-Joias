# Especificação Técnica — Sistema de Gerenciamento de Estoque

> **Versão:** 1.0
> **Data:** 03/09/2026
> **Baseado em:** Documento de Requisitos (Sistema de Gerenciamento de Estoque — 5 Filiais)
> **Stack:** Java + JavaScript + HTML5/CSS3 + PostgreSQL + Git

---

## 1. Visão Geral

Esta especificação técnica detalha a implementação do **Sistema de Gerenciamento de Estoque para 5 Filiais**, mapeando cada requisito funcional e não-funcional do documento de requisitos original para componentes concretos da arquitetura proposta.

| Aspecto | Decisão Técnica |
|---------|-----------------|
| **Arquitetura** | Monolítica em camadas (Presentation → Backend Java → Banco de Dados) |
| **Backend** | Java 17 com Spring Boot 3 |
| **Banco de Dados** | PostgreSQL via Supabase Pooler (conexão JDBC) |
| **Autenticação** | Login validado no backend Java com dados armazenados no PostgreSQL |
| **Autorização** | Controle de acesso baseado no cargo (`gerente` / `funcionario`) |
| **Frontend** | HTML5 / CSS3 / JavaScript (SPA estática) |
| **Gráficos** | Chart.js no frontend + dados agregados via APIs REST em Java/Spring Boot |
| **Versionamento** | Git |

---

## 2. Matriz de Rastreabilidade de Requisitos

### 2.1 Requisitos Funcionais → Implementação

| ID | Requisito (Documento Original) | Componente Técnico | Arquivo / Endpoint | Status |
|----|----------------------------------|-------------------|-------------------|--------|
| **RF-01** | Login de usuários | Validação de login no backend Java enviando Nome, E-mail e Senha | `AuthController.java` — `/api/auth/login` | Concluído |
| **RF-02** | Dois tipos de usuário: gerente e funcionário | Enum/Cargo no PostgreSQL (`cargo`) | `Usuario.java` / `AuthService.java` | Concluído |
| **RF-03** | Gerente acessa 5 filiais | Regra de autorização (`gerente`) + consulta sem filtro | `DashboardService.java`, `FilialController.java` | Concluído |
| **RF-04** | Funcionário acessa só sua filial | Filtro por `filial_id` nas consultas SQL | `EstoqueService.java` | Concluído |
| **RF-05** | Impedir acesso a outras filiais | Bloqueio de acesso no backend Java | `EstoqueService.java` | Concluído |
| **RF-06** | Cadastrar produtos | CRUD Produto | `ProdutoController.java` — `/api/produtos` | Concluído |
| **RF-07** | Armazenar quantidade por filial | Tabela `estoques` (`filial_id` + `produto_id`) | `EstoqueController.java` — `/api/estoque` | Concluído |
| **RF-08** | Aumentar quantidade | `ajustarEstoque()` tipo `entrada` | `EstoqueService.java` | Concluído |
| **RF-09** | Diminuir quantidade | `ajustarEstoque()` tipo `saida` | `EstoqueService.java` | Concluído |
| **RF-10** | Gerente altera estoque | Operação de ajuste com controle de perfil | `EstoqueService.java` | Concluído |
| **RF-11** | Status: suficiente, baixo, zerado | Cálculo de status e enum `status` | `EstoqueService.java` / `main.js` | Concluído |
| **RF-12** | Registrar quem alterou | Campo `usuario` na movimentação | `HistoricoService.java` | Concluído |
| **RF-13** | Histórico: produto, qtd anterior, qtd nova | Tabela / Registro de Histórico | `HistoricoController.java` — `/api/historico` | Concluído |
| **RF-14** | Histórico: usuário e data/hora | Registro de `data` e `usuario` | `HistoricoService.java` | Concluído |
| **RF-15** | Histórico de transferências | Tabela `transferencias` + `movimentacoes` | `TransferenciaController.java` | Concluído |
| **RF-16** | Solicitar transferência | Fluxo de transferência entre filiais | `TransferenciaController.java` — `/api/transferencias` | Concluído |
| **RF-17** | Registrar origem, destino, produto, quantidade | Registro completo da transferência | `TransferenciaService.java` | Concluído |
| **RF-18** | Transferência altera estoque origem | Débito na origem | `TransferenciaService.java` | Concluído |
| **RF-19** | Transferência altera estoque destino | Crédito no destino ao concluir | `TransferenciaService.java` | Concluído |
| **RF-20** | Transferência no histórico | Registro em movimentações | `TransferenciaService.java` | Concluído |
| **RF-21** | Somente gerente cria pedido de compra | Validação de perfil no backend | `PedidoCompraController.java` — `/api/pedidos` | Concluído |
| **RF-22** | Selecionar produto e quantidade | Criação do pedido de compra | `PedidoService.java` | Concluído |
| **RF-23** | Identificar estoque baixo/zerado | API de alertas | `EstoqueController.java` — `/api/estoque/alertas` | Concluído |
| **RF-24** | Gráficos de estoque e movimentações | Chart.js no frontend + API agregada | `DashboardController.java` — `/api/dashboard` | Concluído |
| **RF-25** | Gerente vê gráficos de 5 filiais | Dados consolidados das 5 filiais | `DashboardService.java` | Concluído |
| **RF-26** | Funcionário vê só sua filial | Filtro por `filial_id` do usuário logado | `DashboardService.java` | Concluído |

---

## 3. Arquitetura de Software

### 3.1 Diagrama de Camadas

A arquitetura do **Lume Joias** é composta por três camadas principais:

1. **Camada de Apresentação (Presentation / Frontend):**
   - Desenvolvida em HTML5, CSS3 e JavaScript puro (ES6+).
   - Renderização no navegador via SPA (Single Page Application).
   - Comunicação via API REST (`fetch`) com fallback para simulação local quando hospedado isoladamente (ex: GitHub Pages).

2. **Camada de Aplicação e Negócio (Backend Spring Boot):**
   - Controllers REST (`com.nicoly.LumeEstoque.controller`) para exposição dos endpoints.
   - Services (`com.nicoly.LumeEstoque.service`) para validações de regras de negócio, perfil do usuário e orquestração.
   - Repositories (`com.nicoly.LumeEstoque.repository`) e DTOs para transferência limpa de dados.

3. **Camada de Persistência (Banco de Dados Supabase / PostgreSQL):**
   - Banco PostgreSQL hospedado no Supabase.
   - Tabelas de `usuarios`, `filiais`, `produtos`, `estoques`, `movimentacoes`, `transferencias` e `pedidos_compra`.
