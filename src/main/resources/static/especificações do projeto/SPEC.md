# Especificação Técnica — Sistema de Gerenciamento de Estoque

> **Versão:** 2.3 (Pós-Tarefa 3: Correção de Pedidos de Compra)
> **Data:** 05/10/2026
> **Arquitetura Target:** SPA Estática (HTML5 / CSS3 / JavaScript Vanilla) + Supabase (PostgreSQL / RPC) + GitHub Pages

---

## 1. Visão Geral e Estado Atual

Esta especificação técnica reflete a conclusão com sucesso da **Tarefa 3 (Correção da Criação de Pedidos de Compra)**.

| Componente | Especificação Projetada | Estado Atual Implementado | Status |
|------------|-------------------------|---------------------------|--------|
| **Arquitetura** | SPA Cliente-Servidor (GitHub Pages + Supabase) | GitHub Pages + Supabase Direct | **Concluído** |
| **Autenticação** | Supabase Auth + BCrypt hash verification (`bcryptjs`) | `signInWithPassword` + `bcryptjs.compareSync` | **Concluído** |
| **Pedidos de Compra** | Inserção e Leitura Relacional Master-Detail | `pedidos_compra` + `itens_pedido_compra` com rollback | **Concluído** |
| **Permissões de Pedido** | Exclusivo para Gerentes | Bloqueio em frontend e backend (`main.js`) | **Concluído** |
| **Escopo / Dashboard** | Isolamento por `filial_id` para funcionário | Leitura total do banco via Anon Key | Pendente (Tarefa 4) |

---

## 2. Arquitetura do Módulo de Pedidos de Compra

```text
Gerente (Robson/Manuella)
  │
  ▼
salvarPedido() [main.js]
  │
  ├── 1. Inserção do Registro Pai
  │       └── INSERT INTO pedidos_compra (filial_id, usuario_id, status: 'aberto')
  │             └── Retorna pedido.id
  │
  └── 2. Inserção do Registro Filho (Item)
          └── INSERT INTO itens_pedido_compra (pedido_id, produto_id, quantidade)
                ├── Sucesso ──> Notifica toast e renderiza tabela de pedidos
                └── Falha ──> ROLLBACK: DELETE FROM pedidos_compra WHERE id = pedido.id
```

---

## 3. Matriz de Rastreabilidade de Requisitos

| Requisito | Descrição | Status Pós-Tarefa 3 | Teste Realizado |
|-----------|-----------|----------------------|-----------------|
| **RF-01** | Login de usuários | **Concluído & Aprovado** | Validados logins de Robson e Anderson |
| **RF-21** | Somente gerente cria pedido de compra | **Concluído & Aprovado** | Testada criação por Gerente e bloqueio para Funcionário |
| **RF-22** | Selecionar produto e quantidade no pedido | **Concluído & Aprovado** | Testada criação em `pedidos_compra` + `itens_pedido_compra` |
| **RF-23** | Identificar estoque baixo/zerado | **Operacional** | Alertas e lista de reposição validados |
| **RF-24..RF-26** | Dashboard e Gráficos por Filial | Pendente (Tarefa 4) | Planejado para Tarefa 4 |
