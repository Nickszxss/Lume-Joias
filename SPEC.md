# Especificação Técnica — Sistema de Gerenciamento de Estoque

> **Versão:** 2.6 (Pós-Tarefa 6: Ajustes Responsivos)
> **Data:** 05/10/2026
> **Arquitetura Target:** SPA Estática (HTML5 / CSS3 / JavaScript Vanilla) + Supabase (PostgreSQL / RPC) + GitHub Pages

---

## 1. Visão Geral e Estado Atual

Esta especificação técnica reflete a conclusão da **Tarefa 6 (Ajustes Responsivos do Lume Joias)**.

| Componente | Especificação Projetada | Estado Atual Implementado | Status |
|------------|-------------------------|---------------------------|--------|
| **Arquitetura** | SPA Cliente-Servidor (GitHub Pages + Supabase) | GitHub Pages + Supabase Direct | **Concluído** |
| **Autenticação** | Supabase Auth + BCrypt hash verification (`bcryptjs`) | `signInWithPassword` + `bcryptjs.compareSync` | **Concluído** |
| **Pedidos de Compra** | Inserção e Leitura Relacional Master-Detail | `pedidos_compra` + `itens_pedido_compra` com rollback | **Concluído** |
| **Políticas RLS** | Habilitação e Políticas Granulares no PostgreSQL | `supabase_rls_policies.sql` | **Concluído** |
| **Escopo / Dashboard** | Isolamento por `filial_id` para funcionário | Queries filtradas no client (REST) e restrições RLS | **Concluído** |
| **Responsividade** | Support a 375px, 390px, 768px, Tablet e Desktop | Breakpoints otimizados, modais scroll em 88vh, sem overflow do body | **Concluído** |

---

## 2. Resoluções Homologadas e Comportamento Visual

- **Smartphone 375px & 390px (e.g. iPhone SE / 12 / 13 / 14):**
  - Sidebar oculta e transformada em top bar fixa grid (`.logo`, `.theme-toggle-container`, `.user-box`).
  - Menu de navegação pill horizontal com scroll suave tátil.
  - Modais com `max-height: 88vh; overflow-y: auto` e botões empilhados verticalmente.
  - Tabelas contidas em cards com `overflow-x: auto` e aviso visual *"← Deslize para ver mais →"*.
  - `body { overflow-x: hidden; }` impedindo rolagem lateral indesejada da página.

- **Tablet 768px (Portrait) & 1024px (Landscape):**
  - Transição fluida de visualização em 2 colunas para 1 coluna nos gráficos e cards do Dashboard.
  - Navegação tátil responsiva em abas no menu superior.

- **Desktop (1366px+):**
  - Sidebar lateral fixa de 250px mantida.
