# Especificação Técnica — Sistema de Gerenciamento de Estoque

> **Versão:** 2.0
> **Data:** 04/10/2026
> **Baseado em:** Documento de Requisitos (Sistema de Gerenciamento de Estoque — 5 Filiais)
> **Stack:** HTML5/CSS3/JavaScript (SPA Static) + Supabase (PostgreSQL / RPC) + GitHub Pages + Git

---

## 1. Visão Geral

Esta especificação técnica detalha a implementação do **Sistema de Gerenciamento de Estoque para 5 Filiais**, mapeando cada requisito funcional e não-funcional do documento de requisitos original para componentes concretos da arquitetura desacoplada e serverless.

| Aspecto | Decisão Técnica |
|---------|-----------------|
| **Arquitetura** | SPA Cliente-Servidor Desacoplada (Frontend Estático → Supabase Client SDK / REST / RPC) |
| **Hospedagem** | GitHub Pages (HTML5, CSS3, JavaScript ES6) |
| **Banco de Dados** | PostgreSQL hospedado no Supabase |
| **Autenticação** | RPC PostgreSQL (`validar_login`) no Supabase com extensão `pgcrypto` (validação segura de BCrypt server-side) |
| **Autorização** | Controle de acesso baseado no perfil (`gerente` / `funcionario`) e RLS no PostgreSQL |
| **Frontend / Responsividade** | HTML5 / CSS3 / JS Vanilla (Breakpoints CSS em 900px e 500px para Desktop 1280px, Tablet 768px e Smartphone 375px) |
| **Gráficos** | Chart.js 4.x no frontend |
| **Versionamento / Homologação** | Git (Branch `master`) / Homologado e Aprovado nos 9 eixos funcionais e de segurança |

---

## 2. Matriz de Rastreabilidade de Requisitos

### 2.1 Requisitos Funcionais → Implementação

| ID | Requisito (Documento Original) | Componente Técnico | Arquivo / Endpoint | Status |
|----|----------------------------------|-------------------|-------------------|--------|
| **RF-01** | Login de usuários | Validação de login segura via RPC PostgreSQL `validar_login` enviando Nome, E-mail e Senha | `main.js` / Supabase RPC `validar_login` | Concluído |
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
| **RF-12** | Registrar quem alterou | Campo `usuario_id` vinculado à tabela `usuarios` | `main.js` / Supabase `movimentacoes` | Concluído |
| **RF-13** | Histórico: produto, qtd anterior, qtd nova | Tabela / Registro de Histórico | `main.js` / `api.listarHistorico()` | Concluído |
| **RF-14** | Histórico: usuário e data/hora | Registro de `created_at` e `usuario_id` | `main.js` / `api.listarHistorico()` | Concluído |
| **RF-15** | Histórico de transferências | Tabela `transferencias` + `movimentacoes` | `TransferenciaController.java` | Concluído |
| **RF-16** | Solicitar transferência | Fluxo de transferência entre filiais | `TransferenciaController.java` — `/api/transferencias` | Concluído |
| **RF-17** | Registrar origem, destino, produto, quantidade | Registro completo da transferência | `TransferenciaService.java` | Concluído |
| **RF-18** | Transferência altera estoque origem | Débito na origem | `TransferenciaService.java` | Concluído |
| **RF-19** | Transferência altera estoque destino | Crédito no destino ao concluir | `TransferenciaService.java` | Concluído |
| **RF-20** | Transferência no histórico | Registro em movimentações | `TransferenciaService.java` | Concluído |
| **RF-21** | Somente gerente cria pedido de compra | Validação de perfil de gerente no frontend e no Supabase | `main.js` / Supabase RLS | Concluído |
| **RF-22** | Selecionar produto e quantidade | Criação do pedido de compra | `main.js` / `api.criarPedido()` | Concluído |
| **RF-23** | Identificar estoque baixo/zerado | API de alertas | `EstoqueController.java` — `/api/estoque/alertas` | Concluído |
| **RF-24** | Gráficos de estoque e movimentações | Chart.js 4.x no frontend + dados em tempo real do Supabase | `main.js` / `api.resumoDashboard()` | Concluído |
| **RF-25** | Gerente vê gráficos de 5 filiais | Consolidado das 5 filiais via Supabase | `main.js` / `resumoDashboard()` | Concluído |
| **RF-26** | Funcionário vê só sua filial | Filtro por `filial_id` do usuário logado no JS e Supabase | `main.js` / `resumoDashboard()` | Concluído |

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
