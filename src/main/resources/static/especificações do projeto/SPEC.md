# Especificação Técnica — Sistema de Gerenciamento de Estoque

> **Versão:** 2.2 (Pós-Tarefa 2: Autenticação Segura)
> **Data:** 05/10/2026
> **Arquitetura Target:** SPA Estática (HTML5 / CSS3 / JavaScript Vanilla) + Supabase (PostgreSQL / RPC) + GitHub Pages

---

## 1. Visão Geral e Estado Atual

Esta especificação técnica reflete a conclusão com sucesso da **Tarefa 2 (Autenticação Segura e Correção de Login)**.

| Componente | Especificação Projetada | Estado Atual Implementado | Status |
|------------|-------------------------|---------------------------|--------|
| **Arquitetura** | SPA Cliente-Servidor (GitHub Pages + Supabase) | GitHub Pages + Supabase Direct | **Concluído** |
| **Autenticação** | Supabase Auth + BCrypt hash verification (`bcryptjs`) | `signInWithPassword` + `bcryptjs.compareSync` | **Concluído** |
| **Sessão & Persistence** | Supabase Auth Session + `localStorage` (`lume_usuario`) | Restore automático em `verificarSessaoAtiva()` | **Concluído** |
| **Logout & Expir** | `signOut()` + limpeza de tokens e localStorage | Fluxo limpo e seguro | **Concluído** |
| **Pedidos de Compra** | Relação Pedidos x Produtos | `pedidos_compra` + `itens_pedido_compra` | Pendente (Tarefa 3) |
| **Escopo / Dashboard** | Isolamento por `filial_id` para funcionário | Leitura total do banco via Anon Key | Pendente (Tarefa 4) |

---

## 2. Arquitetura do Módulo de Autenticação

```text
Usuário
  │  (Nome, E-mail, Senha)
  ▼
fazerLogin() [main.js]
  │
  ├── 1. Tenta client.auth.signInWithPassword({ email, password })
  │       ├── Sucesso ──> Carrega perfil em public.usuarios e salva access_token
  │       └── Falha / Não provisionado ──> Segue para o Passo 2
  │
  └── 2. Consulta public.usuarios por e-mail
          ├── Compara hash BCrypt via bcryptjs.compareSync(senha, u.senha)
          │     ├── Valido ──> Inicia sessão, salva perfil e dispara client.auth.signUp()
          │     └── Invalido ──> Exibe alerta toast "Acesso negado"
```

---

## 3. Matriz de Rastreabilidade de Requisitos

| Requisito | Descrição | Status Pós-Tarefa 2 | Teste Realizado |
|-----------|-----------|----------------------|-----------------|
| **RF-01** | Login de usuários | **Concluído & Aprovado** | Validados logins de Robson e Anderson |
| **RF-02** | Dois tipos de usuário: gerente e funcionário | **Concluído & Aprovado** | Roles `gerente` e `funcionario` mantidas |
| **RF-03..RF-05** | Escopo de filial por usuário | Parcial (Front ok, Dashboard pendente) | Botões restritos para funcionários |
| **RF-06..RF-20** | CRUD Produtos, Estoques, Transferências e Histórico | **Operacional** | Aprovados em integração |
| **RF-21..RF-23** | Pedidos de Compra | Pendente (Tarefa 3) | Planejado para próxima tarefa |
| **RF-24..RF-26** | Dashboard e Gráficos | Pendente (Tarefa 4) | Planejado para Tarefa 4 |
