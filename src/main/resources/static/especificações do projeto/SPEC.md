# Especificação Técnica — Sistema de Gerenciamento de Estoque

> **Versão:** 2.1 (Pós-Auditoria)
> **Data:** 05/10/2026
> **Arquitetura Target:** SPA Estática (HTML5 / CSS3 / JavaScript Vanilla) + Supabase (PostgreSQL / RPC) + GitHub Pages

---

## 1. Visão Geral e Estado Atual

Esta especificação técnica foi atualizada após a **Auditoria Técnica de Outubro/2026** para refletir o diagnóstico preciso dos módulos e da infraestrutura do **Lume Joias**.

| Componente | Especificação Projetada | Estado Atual Auditado | Pendência Diagnosticada |
|------------|-------------------------|-----------------------|-------------------------|
| **Arquitetura** | SPA Cliente-Servidor (GitHub Pages + Supabase) | GitHub Pages + Supabase Direct | Confirmada ausência do backend Java em prod. |
| **Autenticação** | RPC `validar_login` + `pgcrypto` | Fallback em JS com `u.senha === senha` | **CRÍTICO:** RPC `validar_login` ausente no Supabase; senhas estão em hash BCrypt. |
| **Pedidos de Compra** | Relação Pedidos x Produtos | `pedidos_compra` + `itens_pedido_compra` | **CRÍTICO:** Frontend tenta gravar e ler `produto_id` diretamente em `pedidos_compra`. |
| **Escopo / Dashboard** | Isolamento por `filial_id` para funcionário | Leitura total do banco via Anon Key | **ATENÇÃO:** `resumoDashboard` traz estoques globais antes do filtro local. |
| **Estoque / Histórico** | Lógica no cliente com Supabase | Operacional | Atualizações de saldo e registro duplo em `movimentacoes` funcionais. |
| **Responsividade** | Breakpoint 900px + suporte mobile | Operacional com ajustes | Necessário refinar modais e tabelas em telas <400px. |

---

## 2. Schema de Tabelas no Supabase (Confirmado via REST API)

1. **`usuarios`**: `id`, `nome`, `email`, `senha` (BCrypt), `cargo`, `tipo`, `filial_id`, `ativo`, `created_at`
2. **`filiais`**: `id`, `nome`, `endereco`, `cidade`, `estado`, `ativa`, `created_at`
3. **`produtos`**: `id`, `nome`, `descricao`, `codigo` (SKU), `unidade_medida`, `qtd_minima`, `ativo`, `created_at`
4. **`estoques`**: `id`, `filial_id`, `produto_id`, `quantidade`, `status`, `updated_at`
5. **`movimentacoes`**: `id`, `produto_id`, `filial_id`, `usuario_id`, `tipo`, `quantidade`, `quantidade_anterior`, `quantidade_nova`, `motivo`, `created_at`
6. **`transferencias`**: `id`, `origem_id`, `destino_id`, `produto_id`, `usuario_id`, `quantidade`, `status`, `observacao`, `created_at`, `concluida_at`
7. **`pedidos_compra`**: `id`, `filial_id`, `usuario_id`, `status`, `observacao`, `created_at`, `recebido_at`
8. **`itens_pedido_compra`**: `id`, `pedido_id`, `produto_id`, `quantidade`

---

## 3. Especificação das Correções Técnicas Recomendadas

### 3.1 Autenticação e RPC `validar_login`
- **Requisito:** Implementar/Publicar no banco Supabase a função SQL `validar_login(p_nome text, p_email text, p_senha text)` utilizando `pgcrypto` (`crypt(p_senha, senha) = senha`) ou adaptar a validação de forma segura.
- **Segurança:** Isolar e proteger credenciais, mantendo a chave `anon` sem permissão de mutação indevida.

### 3.2 Pedidos de Compra e Relacionamentos
- **Requisito:** Ajustar `main.js` para realizar inserção transacional/dupla:
  1. Inserir em `pedidos_compra` (gerando `pedido_id`).
  2. Inserir os itens em `itens_pedido_compra`.
  3. Atualizar a consulta `listarPedidos()` para realizar `select('*, itens_pedido_compra(*, produtos(*))')` ou JOIN equivalente.

### 3.3 Dashboard e Isolamento de Filial
- **Requisito:** Adicionar o filtro `.eq('filial_id', usuario.filial_id)` diretamente nas requisições do Supabase em `resumoDashboard` quando o usuário for do tipo `funcionario`.

---

## 4. Matriz de Rastreabilidade de Requisitos

| Requisito | Descrição | Status Pós-Auditoria | Ação Requerida |
|-----------|-----------|----------------------|----------------|
| **RF-01** | Login de usuários | Bloqueado por RPC ausente | Criar RPC `validar_login` / suporte a BCrypt |
| **RF-02..RF-05** | Controle de perfil e filiais | Parcial | Aplicar filtro de filial na origem das queries no Supabase |
| **RF-06..RF-14** | CRUD Produtos, Estoques e Histórico | Operacional | Manter e assegurar não regressão |
| **RF-15..RF-20** | Transferências entre Filiais | Operacional | Manter integridade e atomicidade |
| **RF-21..RF-23** | Pedidos de Compra | Inoperante por schema | Adequar inserção/consulta em `itens_pedido_compra` |
| **RF-24..RF-26** | Dashboard e Gráficos | Parcial | Isolar consultas por `filial_id` no client-side |
