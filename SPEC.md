# ESPECIFICAÇÃO TÉCNICA — LUME JOIAS

## 1. Arquitetura da Aplicação

O **Lume Joias** é um Sistema de Gerenciamento de Estoque (SGE) multi-filial projetado para operar com arquitetura 100% serverless:

```text
Frontend:
HTML + CSS + JavaScript (Vanilla ES6+)

Hospedagem:
GitHub Pages

Backend / BaaS:
Supabase

Banco de Dados:
PostgreSQL / Supabase
```

---

## 2. Autenticação

O sistema está migrando para autenticação exclusivamente realizada via **Supabase Auth**:

```text
E-mail + Senha
       ↓
Supabase Auth (GoTrue auth.users)
       ↓
Consulta public.usuarios (Metadados: nome, cargo, filial_id)
       ↓
Sessão Autenticada
```

- **Migração Supabase Auth:** O Supabase Auth (`auth.users`) é o único responsável pela autenticação de credenciais da conta.
- **Hospedagem Serverless:** O GitHub Pages hospeda o frontend estático e não executa backend Java/Spring Boot.
- **Sem campo de nome no login:** O formulário exige exclusivamente E-mail e Senha.
- **Tabela de Funcionários:** A tabela `public.usuarios` armazena os dados complementares do usuário (nome, e-mail, cargo, filial_id, ativo).

---

## 3. Perfis e Permissões de Usuários

### Gerente
- Visão consolidada do estoque das 5 filiais no Dashboard.
- Permissão para criar novos Pedidos de Compra (`#btn-novo-pedido`).
- Solicitação e conclusão de transferências entre quaisquer filiais.

### Funcionário
- Visão restrita e isolada do estoque de sua filial atribuída (`filial_id`).
- Origem de transferência e seleção de filial no cadastro de produto travadas na sua própria filial.
- Sem permissão para criar Pedidos de Compra.

### Reset de Produtos e Preservação da Estrutura de Usuários
- Todos os registros legados de produtos, estoques iniciais, movimentações e transferências operacionais foram removidos.
- A estrutura de autenticação (`usuarios`), todas as 6 contas de usuários (gerentes e funcionários) e as 5 filiais oficiais foram integralmente preservadas.

### Filtro de Filiais na Tela de Estoque
- O filtro de estoque permite alternar entre "Todas as filiais" e as 5 filiais individuais (Centro, Norte, Sul, Leste, Oeste).
- A tabela de estoque exibe a coluna dedicada `Filial` e atualiza reativamente os dados consultando a API do Supabase com o parâmetro `.eq('filial_id', filialId)`.

### Tabela Oficial de SKUs e Regras de Cadastro por Filial
- O cadastro de produtos exige a escolha obrigatória de uma filial (`filial_id`).
- O produto criado é associado exclusivamente à filial selecionada (registro único na tabela `estoques`), não sendo propagado automaticamente para as demais filiais.
- O SKU é preenchido e atualizado automaticamente com preservação dos zeros à esquerda de acordo com o tipo de produto selecionado:
  - Colar de prata → `001`
  - Colar de ouro → `002`
  - Anel de prata → `003`
  - Anel de ouro → `004`
  - Brinco de prata → `005`
  - Brinco de ouro → `006`
  - Solitária → `007`
  - Pulseira de prata → `008`
  - Pulseira de ouro → `009`

### Usuários de Teste

| Nome     | E-mail                        | Cargo       | Filial Atribuída | Status `public.usuarios` | Status `auth.users` |
| -------- | ----------------------------- | ----------- | ---------------- | ------------------------ | ------------------- |
| Anderson | `anderson.func@empresa.com`   | Funcionário | Filial Centro (ID 1) | Ativo (ID 4)             | Provisionado Admin  |
| Robson   | `robson.grt@empresa.com`      | Gerente     | Filial Oeste (ID 5)  | Ativo (ID 5)             | Provisionado Admin  |
| Isabella | `isabella.func@empresa.com`   | Funcionária | Filial Norte (ID 2)  | Ativo (ID 6)             | Provisionado Admin  |
| Manuella | `manuella.grt@empresa.com`    | Gerente     | Filial Leste (ID 4)  | Ativo (ID 7)             | Provisionado Admin  |
| Nicoly   | `nicoly.func@empresa.com`     | Funcionária | Filial Sul (ID 3)    | Ativo (ID 2)             | Provisionado Admin  |
| Nicoly   | `nicoly.grt@empresa.com`      | Gerente     | Filial Sul (ID 3)    | Ativo (ID 3)             | Provisionado Admin  |

*Notas de Configuração:*
- As seis contas Auth foram instruídas para provisionamento administrativo seguro.
- O Supabase Auth é o responsável pela autenticação e gestão de sessão de conta.
- A tabela `public.usuarios` permanece responsável pelos dados complementares do funcionário.
- O vínculo entre `auth.users` e `public.usuarios` será tratado na TAREFA 2.3.

---

## 4. Estrutura do Banco de Dados (Supabase PostgreSQL)

- `usuarios`: `id`, `nome`, `email`, `senha`, `cargo`, `tipo`, `filial_id`, `ativo`
- `filiais`: `id`, `nome`, `endereco`, `cidade`, `estado`, `ativa`
- `produtos`: `id`, `nome`, `descricao`, `codigo`, `unidade_medida`, `qtd_minima`, `ativo`
- `estoques`: `id`, `filial_id`, `produto_id`, `quantidade`, `status`
- `movimentacoes`: `id`, `produto_id`, `filial_id`, `usuario_id`, `tipo`, `quantidade`, `quantidade_anterior`, `quantidade_nova`, `motivo`
- `transferencias`: `id`, `origem_id`, `destino_id`, `produto_id`, `usuario_id`, `quantidade`, `status`
- `pedidos_compra`: `id`, `filial_id`, `usuario_id`, `status`
- `itens_pedido_compra`: `id`, `pedido_id`, `produto_id`, `quantidade`
