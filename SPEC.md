# Especificação Técnica — Sistema de Gerenciamento de Estoque

> **Versão:** 2.4 (Pós-Tarefa 4: Segurança & Políticas RLS)
> **Data:** 05/10/2026
> **Arquitetura Target:** SPA Estática (HTML5 / CSS3 / JavaScript Vanilla) + Supabase (PostgreSQL / RPC) + GitHub Pages

---

## 1. Visão Geral e Estado Atual

Esta especificação técnica reflete a conclusão da **Tarefa 4 (Auditoria e Correção das Permissões RLS e Isolamento de Filial)**.

| Componente | Especificação Projetada | Estado Atual Implementado | Status |
|------------|-------------------------|---------------------------|--------|
| **Arquitetura** | SPA Cliente-Servidor (GitHub Pages + Supabase) | GitHub Pages + Supabase Direct | **Concluído** |
| **Autenticação** | Supabase Auth + BCrypt hash verification (`bcryptjs`) | `signInWithPassword` + `bcryptjs.compareSync` | **Concluído** |
| **Pedidos de Compra** | Inserção e Leitura Relacional Master-Detail | `pedidos_compra` + `itens_pedido_compra` com rollback | **Concluído** |
| **Políticas RLS** | Habilitação e Políticas Granulares no PostgreSQL | `supabase_rls_policies.sql` | **Concluído** |
| **Escopo / Dashboard** | Isolamento por `filial_id` para funcionário | Queries filtradas no client e restrições RLS | **Concluído** |

---

## 2. Matriz de Permissões RLS por Tabela e Perfil

| Tabela | Operação | Perfil Gerente | Perfil Funcionário |
|--------|:--------:|:--------------:|:------------------:|
| **`usuarios`** | SELECT | Todas as filiais | Próprio perfil |
| **`usuarios`** | UPDATE | Permitido | Apenas próprio nome/email (bloqueado cargo e filial_id) |
| **`estoques`** | ALL | Todas as 5 filiais | Apenas `filial_id` da própria conta |
| **`movimentacoes`** | ALL | Todas as 5 filiais | Apenas `filial_id` da própria conta |
| **`transferencias`**| SELECT/INSERT | Todas as 5 filiais | Origem obrigatória = própria filial |
| **`pedidos_compra`**| INSERT | Permitido | **NEGADO** (Somente leitura da própria filial) |
