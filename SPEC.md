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

A autenticação é realizada diretamente no Supabase utilizando o fluxo:

```text
E-mail + Senha
       ↓
Supabase Auth / public.usuarios
       ↓
Sessão Autenticada
```

- **Sem campo de nome no login:** O formulário exige exclusivamente E-mail e Senha.
- **Identificação:** O nome do usuário permanece registrado no perfil Supabase e é exibido na interface e relatórios após a autenticação.

---

## 3. Perfis e Permissões de Usuários

### Gerente
- Visão consolidada do estoque das 5 filiais no Dashboard.
- Permissão para criar novos Pedidos de Compra (`#btn-novo-pedido`).
- Solicitação e conclusão de transferências entre quaisquer filiais.

### Funcionário
- Visão restrita e isolada do estoque de sua filial atribuída (`filial_id`).
- Origem de transferência travada na sua própria filial.
- Sem permissão para criar Pedidos de Compra.

### Usuários de Teste

| Nome     | E-mail                        | Senha       | Cargo       | Filial Atribuída |
| -------- | ----------------------------- | ----------- | ----------- | ---------------- |
| Anderson | `anderson.func@empresa.com`   | etec2026@DS | Funcionário | Filial Centro (ID 1) |
| Robson   | `robson.grt@empresa.com`      | etec2026@DS | Gerente     | Geral (5 Filiais) |
| Isabella | `isabella.func@empresa.com`   | etec2026@DS | Funcionário | Filial Norte (ID 2) |
| Manuella | `manuella.grt@empresa.com`    | etec2026@DS | Gerente     | Geral (5 Filiais) |
| Nicoly   | `nicoly.func@empresa.com`     | 160611      | Funcionária | Filial Norte (ID 2) |
| Nicoly   | `nicoly.grt@empresa.com`      | 160611      | Gerente     | Filial Leste (ID 4) / Geral |

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
