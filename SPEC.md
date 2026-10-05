# Especificação Técnica — Sistema de Gerenciamento de Estoque

> **Versão:** 2.5 (Pós-Tarefa 5: Correção do Dashboard do Funcionário)
> **Data:** 05/10/2026
> **Arquitetura Target:** SPA Estática (HTML5 / CSS3 / JavaScript Vanilla) + Supabase (PostgreSQL / RPC) + GitHub Pages

---

## 1. Visão Geral e Estado Atual

Esta especificação técnica reflete a conclusão da **Tarefa 5 (Correção do Dashboard do Funcionário)**.

| Componente | Especificação Projetada | Estado Atual Implementado | Status |
|------------|-------------------------|---------------------------|--------|
| **Arquitetura** | SPA Cliente-Servidor (GitHub Pages + Supabase) | GitHub Pages + Supabase Direct | **Concluído** |
| **Autenticação** | Supabase Auth + BCrypt hash verification (`bcryptjs`) | `signInWithPassword` + `bcryptjs.compareSync` | **Concluído** |
| **Pedidos de Compra** | Inserção e Leitura Relacional Master-Detail | `pedidos_compra` + `itens_pedido_compra` com rollback | **Concluído** |
| **Políticas RLS** | Habilitação e Políticas Granulares no PostgreSQL | `supabase_rls_policies.sql` | **Concluído** |
| **Escopo / Dashboard** | Isolamento por `filial_id` para funcionário | Queries filtradas no client (REST) e restrições RLS | **Concluído** |

---

## 2. Comportamento do Dashboard por Perfil

- **Funcionário (Anderson/Isabella):**
  - O gráfico "Estoque por Filial" exibe unicamente 1 barra com o saldo da filial atribuída (`Filial Centro`).
  - O gráfico de linhas "Movimentações (7 dias)" exibe entradas e saídas restritas à filial atribuída.
  - A tabela de alertas lista produtos com estoque baixo ou zerado pertencentes exclusivamente à sua filial.
  - O payload da resposta HTTP da API Supabase não contém registros de outras filiais.

- **Gerente (Robson/Manuella):**
  - O gráfico "Estoque por Filial" exibe 5 barras representativas das 5 filiais oficiais.
  - Os KPIs refletem o saldo consolidado global de todas as filiais.
  - O filtro superior permite isolar o Dashboard por qualquer uma das 5 filiais individualmente.
