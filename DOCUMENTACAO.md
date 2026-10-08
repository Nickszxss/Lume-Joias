# Documentação do Projeto — Lume Joias

## 1. Link da Aplicação Hospedada e Arquitetura

```text
GitHub Pages:
https://nickszxss.github.io/Lume-Joias/
```

- **Arquitetura Oficial:**
  ```text
  Frontend:
  HTML + CSS + JavaScript

  Hospedagem:
  GitHub Pages

  Backend/BaaS:
  Supabase

  Banco de dados:
  PostgreSQL / Supabase
  ```
- **Execução Serverless:** A aplicação é 100% estática client-side (HTML5, CSS3, JavaScript Vanilla ES6+) hospedada no GitHub Pages comunicando-se diretamente com o Supabase PostgreSQL via SDK / REST API pública. O GitHub Pages não executa nenhum backend Java/Spring Boot.

---

## 2. Autenticação e Usuários de Teste

- **Diretrizes de Autenticação:**
  - O sistema está migrando para autenticação exclusivamente pelo **Supabase Auth** (`supabase.auth.signInWithPassword`).
  - O GitHub Pages não executa backend Java/Spring Boot.
  - A autenticação deve utilizar **e-mail + senha**.
  - A tabela de funcionários (`public.usuarios`) armazena os dados complementares do usuário (nome, cargo, filial_id, ativo).
  - O Supabase Auth (`auth.users`) será o único responsável pela autenticação e validação da conta.

A autenticação no frontend é realizada solicitando exclusivamente:
```text
E-mail + Senha
```
O campo Nome do Usuário não é exigido no formulário de login. O nome do perfil do usuário é recuperado após a autenticação e utilizado para exibição no sistema, dashboard, relatórios e auditoria de movimentações.

Os usuários ativos cadastrados no Supabase (`public.usuarios` e Supabase Auth com senhas em hash BCrypt):

| Nome     | E-mail                        | Cargo       | Filial Atribuída | Escopo / Permissões | Pedidos de Compra |
| -------- | ----------------------------- | ----------- | ---------------- | ------------------- | ----------------- |
| Anderson | `anderson.func@empresa.com`   | Funcionário | Filial Centro (ID 1) | Restrito à Filial Centro | Bloqueado |
| Robson   | `robson.grt@empresa.com`      | Gerente     | Filial Oeste (ID 5)  | Acesso Geral (5 Filiais) | Habilitado |
| Isabella | `isabella.func@empresa.com`   | Funcionária | Filial Norte (ID 2)  | Restrito à Filial Norte  | Bloqueado |
| Manuella | `manuella.grt@empresa.com`    | Gerente     | Filial Leste (ID 4)  | Acesso Geral (5 Filiais) | Habilitado |
| Nicoly   | `nicoly.func@empresa.com`     | Funcionária | Filial Sul (ID 3)    | Restrito à Filial Sul    | Bloqueado |
| Nicoly   | `nicoly.grt@empresa.com`      | Gerente     | Filial Sul (ID 3)    | Acesso Geral (5 Filiais) | Habilitado |

*Notas de Autenticação Definitiva e RLS:*
- **Autenticação 100% Supabase Auth:** Login exclusivo via `supabase.auth.signInWithPassword({ email, password })`.
- **Validação de Permissões e RLS:** Permissões de cargo (`gerente` / `funcionario`) e filial são consultadas diretamente do banco PostgreSQL (`public.usuarios`) e aplicadas pelo RLS (`supabase_rls_policies.sql`).
- **Segurança:** O frontend não permite alteração manual de perfil ou escopo, e o RLS impede que requisições bypassem o isolamento por filial ou criem pedidos sem permissão.
- **Isolamento de Contas:** `nicoly.func@empresa.com` (Funcionária / Filial Sul) e `nicoly.grt@empresa.com` (Gerente / Filial Sul) operam como contas totalmente independentes.

---

## 3. Matriz de Homologação e Diagnóstico por Módulo

| Módulo / Funcionalidade | Status | Detalhamento Técnico |
| :--- | :--- | :--- |
| **Autenticação / Login** | **APROVADO** | Formulário e fluxo de autenticação via Supabase Auth (`signInWithPassword`). Fallback BCrypt completamente removido. |
| **Pedidos de Compra** | **APROVADO** | Estrutura relacional master-detail (`pedidos_compra` + `itens_pedido_compra`) com criação restrita a Gerentes e ação "Marcar como Recebido" com atualização de estoque e histórico. |
| **Segurança & RLS** | **APROVADO** | Políticas RLS e filtros no cliente garantem isolamento rigoroso por filial para funcionários. |
| **Dashboard** | **APROVADO** | Consultas e gráficos isolados por `filial_id` para funcionários. Visão geral consolidada das 5 filiais para gerentes. |
| **Estoque / Ajustes** | **APROVADO** | Atualização direta na tabela `estoques` gerando histórico auditável em `movimentacoes`. |
| **Transferências** | **APROVADO** | Validação de saldo de origem, conclusão restrita à filial de destino ou gerente, atualização atômica para 'concluida' e registro duplo no histórico. |
| **Histórico / Audit** | **APROVADO** | Exibição em tempo real de movimentações com identificação de usuário e filial. |
| **Design / Tema** | **APROVADO** | Alternância dinâmica entre Modo Claro (rose `#9d3b5c`) e Modo Escuro (`#c65b7e`). |
| **Cadastro de Produtos por Filial** | **APROVADO** | Seleção obrigatória de Filial (`#p-filial`) associando o produto/estoque estritamente à filial escolhida. |
| **Preenchimento Automático do SKU** | **APROVADO** | Tabela oficial de SKUs (001 a 009 com zeros à esquerda) preenchida e atualizada automaticamente conforme o tipo de produto selecionado. |
| **Filtro de Filiais no Estoque** | **APROVADO** | Filtro funcional por botões ("Todas" e Filiais 1 a 5) na tela de estoque com coluna de Filial dedicada e filtragem reativa. |
| **Limpeza de Produtos e Preservação de Usuários** | **APROVADO** | Exclusão completa dos produtos legados e estoque inicial, mantendo 100% dos usuários (6 contas) e 5 filiais ativas. |
| **Responsividade** | **APROVADO** | Homologado em smartphones, tablets e desktop sem barra de rolagem horizontal indesejada. |

---

## 4. Especificações de Responsividade e Breakpoints

- **Breakpoints Principais:**
  - `@media (max-width: 900px)`: Transição de sidebar para cabeçalho superior fixo com navegação em barra de pílulas horizontais (`#menu`) com rolagem suave.
  - `@media (max-width: 500px)`: Modais ajustados com `max-height: 88vh; overflow-y: auto`, stack vertical de ações, e tabelas contidas em cards com `overflow-x: auto` e indicador visual `"← Deslize para ver mais →"`.
- **Prevenção de Rolagem Indesejada:** Aplicado `body { overflow-x: hidden; }` garantindo estabilidade do layout em smartphones e tablets.

---

## 5. Schema Real do Banco de Dados Supabase

- `usuarios`: `id`, `nome`, `email`, `senha` (BCrypt), `cargo`, `tipo`, `filial_id`, `ativo`, `created_at`
- `filiais`: `id`, `nome`, `endereco`, `cidade`, `estado`, `ativa`, `created_at`
- `produtos`: `id`, `nome`, `descricao`, `codigo` (SKU), `unidade_medida`, `qtd_minima`, `ativo`, `created_at`
- `estoques`: `id`, `filial_id`, `produto_id`, `quantidade`, `status`, `updated_at`
- `movimentacoes`: `id`, `produto_id`, `filial_id`, `usuario_id`, `tipo`, `quantidade`, `quantidade_anterior`, `quantidade_nova`, `motivo`, `created_at`
- `transferencias`: `id`, `origem_id`, `destino_id`, `produto_id`, `usuario_id`, `quantidade`, `status`, `observacao`, `created_at`, `concluida_at`
- `pedidos_compra`: `id`, `filial_id`, `usuario_id`, `status`, `observacao`, `created_at`, `recebido_at`

---

## 6. Fluxo de Recebimento de Pedidos de Compra

- **Ação "Marcar como Recebido":** Disponível na tabela de Pedidos de Compra para pedidos com status `aberto`.
- **Validação de Permissão:** Permitido para gerentes ou funcionários vinculados à filial solicitante do pedido.
- **Execução Atômica:**
  1. Alteração do status do pedido para `recebido` com registro de data/hora (`recebido_at`).
  2. Incremento automático da quantidade recebida no estoque da filial solicitante na tabela `estoques`.
  3. Registro auditável no histórico de `movimentacoes` (tipo `'entrada'`, associando `usuario_id`, filial, produto e quantidades anterior/nova).
  4. Bloqueio de duplicidade: impede que o mesmo pedido seja recebido mais de uma vez.
  5. Atualização reativa da interface com desabilitação/remoção do botão de ação para pedidos finalizados.
- `itens_pedido_compra`: `id`, `pedido_id`, `produto_id`, `quantidade`
