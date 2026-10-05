# Documentação do Projeto — Lume Joias

## 1. Link da Aplicação Hospedada e Arquitetura

```text
GitHub Pages:
https://nickszxss.github.io/Lume-Joias/
```

- **Arquitetura Real:** SPA Estática Client-Side (HTML5, CSS3, JavaScript Vanilla ES6+) hospedada no GitHub Pages comunicando-se diretamente com o Supabase PostgreSQL via SDK / REST API pública.
- **Backend Java/Spring Boot:** Suprimido do fluxo de execução em produção; todas as operações ocorrem diretamente no cliente com Supabase.

---

## 2. Dados de Usuários e Autenticação (Aprovado — Tarefa 2)

Os usuários abaixo estão cadastrados na tabela `usuarios` do Supabase com senhas em hash BCrypt (`etec2026@DS`) e autenticados de forma segura via integração dual: Supabase Auth (`signInWithPassword`) e validação de hash BCrypt client-side via `bcryptjs` (sem comparação em texto claro e sem exposição de `service_role`):

| Nome     | E-mail                        | Senha       | Cargo       | Permissões / Filial | Status Autenticação |
| -------- | ----------------------------- | ----------- | ----------- | ------------------- | ------------------- |
| Anderson | `anderson.func@empresa.com`   | etec2026@DS | Funcionário | Filial Centro (ID 1) | Aprovado (Testado) |
| Robson   | `robson.grt@empresa.com`      | etec2026@DS | Gerente     | Acesso Geral (5 Filiais) | Aprovado (Testado) |
| Isabella | `isabella.func@empresa.com`   | etec2026@DS | Funcionário | Filial Norte (ID 2) | Aprovado (Testado) |
| Manuella | `manuella.grt@empresa.com`    | etec2026@DS | Gerente     | Acesso Geral (5 Filiais) | Aprovado (Testado) |

---

## 3. Matriz de Homologação e Diagnóstico por Módulo

| Módulo / Funcionalidade | Status da Auditoria | Diagnóstico Técnico & Implementação |
| :--- | :--- | :--- |
| **Autenticação / Login** | **APROVADO** | Integrado ao Supabase Auth + validação de hash BCrypt via `bcryptjs`. Testes de login, senha incorreta, F5 e logout validados. |
| **Pedidos de Compra** | **PENDENTE (Tarefa 3)** | Mapeamento incorreto de colunas/tabelas (`pedidos_compra` vs `itens_pedido_compra`). |
| **Dashboard** | **PENDENTE (Tarefa 4)** | Necessário aplicar filtro por `filial_id` na requisição ao Supabase para funcionários. |
| **Estoque / Ajustes** | Operacional | Leitura e ajuste manual atualizando estoque e criando registros em `movimentacoes`. |
| **Transferências** | Operacional | Validação de saldo de origem, atualização atômica e registro duplo no histórico. |
| **Histórico / Audit** | Operacional | Exibição de movimentações vinculadas aos nomes reais de usuários e filiais. |
| **Design / Tema** | Operacional | Alternância entre Modo Claro (rose `#9d3b5c`) e Escuro (`#c65b7e`) funcional. |
| **Responsividade** | **PENDENTE (Tarefa 5)** | Suporte a breakpoint em 900px ativo, com pendências de ajuste fino para viewports <400px. |

---

## 4. Testes Automatizados Executados (Tarefa 2)

| Caso de Teste | Resultado | Método / Detalhes |
| :--- | :--- | :--- |
| **Campos Vazios** | PASSOU | Bloqueio no frontend exibindo notificação toast amigável. |
| **Senha Incorreta** | PASSOU | Rejeição segura sem expor dados do usuário. |
| **Login Gerente (Robson)** | PASSOU | Sessão iniciada como Gerente com acesso total a 5 filiais. |
| **Persistência de Sessão (F5)** | PASSOU | Sessão restaurada do `localStorage` / Supabase Auth sem desconectar. |
| **Logout Definitivo** | PASSOU | Chamada `signOut()`, limpeza de tokens e redirecionamento à tela de login. |
| **Login Funcionário (Anderson)** | PASSOU | Sessão iniciada como Funcionário com botão de criar pedidos desabilitado. |

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
