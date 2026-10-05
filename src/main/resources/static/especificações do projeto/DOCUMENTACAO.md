# Documentação do Projeto — Lume Joias

## 1. Link da Aplicação Hospedada e Arquitetura

```text
GitHub Pages:
https://nickszxss.github.io/Lume-Joias/
```

- **Arquitetura Real:** SPA Estática Client-Side (HTML5, CSS3, JavaScript Vanilla ES6+) hospedada no GitHub Pages comunicando-se diretamente com o Supabase PostgreSQL via SDK / REST API pública.
- **Backend Java/Spring Boot:** Suprimido do fluxo de execução em produção; todas as operações ocorrem diretamente no cliente com Supabase.

---

## 2. Dados de Usuários e Autenticação

Os usuários abaixo estão cadastrados na tabela `usuarios` do Supabase com senhas em hash BCrypt:

| Nome     | E-mail                        | Senha       | Cargo       | Permissões / Filial |
| -------- | ----------------------------- | ----------- | ----------- | ------------------- |
| Anderson | `anderson.func@empresa.com`   | etec2026@DS | Funcionário | Filial Centro (ID 1) |
| Robson   | `robson.grt@empresa.com`      | etec2026@DS | Gerente     | Acesso Geral (5 Filiais) |
| Isabella | `isabella.func@empresa.com`   | etec2026@DS | Funcionário | Filial Norte (ID 2) |
| Manuella | `manuella.grt@empresa.com`    | etec2026@DS | Gerente     | Acesso Geral (5 Filiais) |

> **Diagnóstico de Auditoria (Login):**
> A função RPC PostgreSQL `validar_login` **não está criada** no schema público do Supabase (`PGRST202`). O mecanismo de fallback em JavaScript realiza comparação direta em texto claro (`u.senha === senha`), a qual falha porque o banco armazena hashes BCrypt.

---

## 3. Relatório de Auditoria Técnica (Outubro/2026)

### 3.1 Problemas Confirmados e Causas Raízes

1. **Falha no Login de Usuários (`validar_login` / BCrypt):**
   - **Causa Raiz:** A RPC `validar_login` com extensão `pgcrypto` não foi executada/criada na instância do Supabase. O código JS em `main.js` tenta chamar a RPC, falha e cai em um fallback local que faz `u.senha === senha`. Como a coluna `senha` possui hash BCrypt (`$2a$10$...`), a comparação string falha.

2. **Falha e Dados Incompletos em Pedidos de Compra:**
   - **Causa Raiz:** O schema real do Supabase utiliza modelo normalizado master-detail (tabela `pedidos_compra` vinculada à tabela `itens_pedido_compra`). O código frontend `main.js` tenta inserir `produto_id` e `quantidade` diretamente em `pedidos_compra`, onde estas colunas não existem. Ao listar, os campos aparecem vazios/indefinidos.

3. **Vazamento de Dados de Outras Filiais no Dashboard do Funcionário:**
   - **Causa Raiz:** A função `resumoDashboard` em `main.js` consulta a tabela `estoques` sem aplicar filtro de `filial_id` na requisição ao Supabase. Todos os registros de estoque das 5 filiais são baixados no cliente, permitindo visualização de dados restritos e violando a regra de escopo de filial.

4. **Inconsistências de Responsividade Mobile e Modais:**
   - **Causa Raiz:** Elementos de tabela e diálogos modais em telas menores que 400px sofrem com falta de rolagem vertical/horizontal adequada ou truncamento de botões de ação.

---

## 4. Matriz de Homologação e Diagnóstico por Módulo

| Módulo / Funcionalidade | Status da Auditoria | Diagnóstico Técnico |
| :--- | :--- | :--- |
| **Autenticação / Login** | **CRÍTICO** | Função RPC `validar_login` ausente no Supabase; fallback JS incompatível com hashes BCrypt. |
| **Pedidos de Compra** | **CRÍTICO** | Mapeamento incorreto de colunas/tabelas (`pedidos_compra` vs `itens_pedido_compra`). |
| **Dashboard** | **ATENÇÃO** | Vazamento de dados client-side para funcionários por falta de filtro de filial nas queries. |
| **Estoque / Ajustes** | Operacional | Leitura e ajuste manual atualizando estoque e criando registros em `movimentacoes`. |
| **Transferências** | Operacional | Validação de saldo de origem, atualização atômica e registro duplo no histórico. |
| **Histórico / Audit** | Operacional | Exibição de movimentações vinculadas aos nomes reais de usuários e filiais. |
| **Design / Tema** | Operacional | Alternância entre Modo Claro (rose `#9d3b5c`) e Escuro (`#c65b7e`) funcional. |
| **Responsividade** | Ajustes Pendentes | Suporte a breakpoint em 900px ativo, com pendências de ajuste fino para viewports <400px. |

---

## 5. Schema Real do Banco de Dados Supabase (Confirmado)

- `usuarios`: `id`, `nome`, `email`, `senha` (BCrypt), `cargo`, `tipo`, `filial_id`, `ativo`, `created_at`
- `filiais`: `id`, `nome`, `endereco`, `cidade`, `estado`, `ativa`, `created_at`
- `produtos`: `id`, `nome`, `descricao`, `codigo` (SKU), `unidade_medida`, `qtd_minima`, `ativo`, `created_at`
- `estoques`: `id`, `filial_id`, `produto_id`, `quantidade`, `status`, `updated_at`
- `movimentacoes`: `id`, `produto_id`, `filial_id`, `usuario_id`, `tipo`, `quantidade`, `quantidade_anterior`, `quantidade_nova`, `motivo`, `created_at`
- `transferencias`: `id`, `origem_id`, `destino_id`, `produto_id`, `usuario_id`, `quantidade`, `status`, `observacao`, `created_at`, `concluida_at`
- `pedidos_compra`: `id`, `filial_id`, `usuario_id`, `status`, `observacao`, `created_at`, `recebido_at`
- `itens_pedido_compra`: `id`, `pedido_id`, `produto_id`, `quantidade`

---

## 6. Plano Recomendado de Correção (Ordem de Execução para Tarefas Seguintes)

1. **Migração Supabase (RPC `validar_login` & Hashes):** Criar e validar a RPC de autenticação segura no PostgreSQL.
2. **Correção de Pedidos de Compra:** Adaptar o frontend e/ou schema para lidar corretamente com `pedidos_compra` e `itens_pedido_compra`.
3. **Isolamento de Dados no Dashboard:** Garantir que consultas ao Supabase respeitem estritamente o `filial_id` do usuário logado.
4. **Refinamento de Responsividade:** Ajustar CSS para tabelas e modais em telas <400px.
