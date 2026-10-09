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
- Permissão para editar dados de produtos (nome, SKU, categoria, qtd mínima).
- Permissão para inativar produtos (`ativo = false`) sem exclusão física de registros históricos.
- Permissão para criar novos Pedidos de Compra (`#btn-novo-pedido`).
- Permissão para marcar qualquer Pedido de Compra como recebido.
- Solicitação e conclusão de transferências entre quaisquer filiais.

### Edição e Inativação de Produtos
- **Editar:** O gerente pode alterar nome, SKU, categoria e quantidade mínima do produto. Validação impede SKUs duplicados.
- **Inativar:** Altera o atributo `ativo` para `false`. Registros históricos em estoques, movimentações, transferências e pedidos são preservados integralmente.
- **Omissão em novas operações:** Produtos inativos são excluídos das opções de seleção para novas transferências e novos pedidos de compra.

### Restrição de Conclusão de Transferências
- **Filial de origem:** Não pode concluir a transferência (botão desabilitado no frontend e bloqueado no backend/RLS).
- **Filial de destino:** Pode concluir a transferência.
- **Gerente:** Pode concluir qualquer transferência.
- **Outras filiais:** Não podem concluir a transferência.

### Atualização em Tempo Real (Supabase Realtime)
- O sistema utiliza `supabaseClient.channel('sge_realtime_channel')` para escutar alterações em tempo real nas tabelas `estoques`, `movimentacoes`, `transferencias` e `pedidos_compra`.
- Quando um registro é inserido, atualizado ou excluído por qualquer usuário/dispositivo no Supabase, os eventos `postgres_changes` são capturados instantaneamente no frontend.
- O manipulador de eventos identifica a página ativa na interface (`#page-dashboard`, `#page-estoque`, `#page-transferencias`, `#page-pedidos`, `#page-alertas`, `#page-historico`) e dispara a renderização reativa sem necessidade de recarregar manualmente a página (F5).
- A subscrição é iniciada no evento `aplicarLogin` e cancelada com `removeChannel` na execução do `sair`.

### Recebimento de Pedidos de Compra
- Os pedidos abertos possuem a ação "Marcar como Recebido".
- Ao ser executada:
  1. O status do pedido é alterado para `recebido` com registro da data/hora no banco de dados.
  2. A quantidade solicitada é somada ao estoque da filial solicitante (`estoques`).
  3. Uma movimentação do tipo `entrada` é gravada na tabela `movimentacoes` com o responsável.
  4. O sistema bloqueia duplicidade de recebimento.
  5. A ação é desabilitada/removida da interface para pedidos já recebidos.

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

### Cadastro de Produtos: Substituição do Valor Inicial por Estoque Mínimo
- No cadastro de novos produtos, o antigo campo "Valor Inicial" foi substituído por "Estoque Mínimo", com opções de 10, 30 ou 50 unidades.
- O valor selecionado é salvo na coluna `qtd_minima` da tabela `produtos` no Supabase PostgreSQL.
- O estoque inicial do produto na filial selecionada é inicializado com 0 unidades (`quantidade = 0`, status `zerado`).
- O parâmetro `qtd_minima` é utilizado para os alertas de estoque baixo (`quantidade <= qtd_minima` → status `baixo`, `quantidade = 0` → status `zerado`).
- Produtos já cadastrados no banco mantêm seus valores de `qtd_minima` sem alterações automáticas destrutivas.

### Tabela Oficial de SKUs e Regras de Cadastro por Filial
- O cadastro de produtos exige a escolha obrigatória de uma filial (`filial_id`).
- O produto criado é associado exclusivamente à filial selecionada (registro único na tabela `estoques`), não sendo propagado automaticamente para as demais filiais.
- O SKU-base de 2 dígitos é preenchido e atualizado automaticamente de acordo com o tipo de produto selecionado:
  - Colar de prata → `01`
  - Colar de ouro → `02`
  - Anel de prata → `03`
  - Anel de ouro → `04`
  - Brinco de prata → `05`
  - Brinco de ouro → `06`
  - Solitária → `07`
  - Pulseira de prata → `08`
  - Pulseira de ouro → `09`
- **Geração de Códigos Exclusivos e Tratamento de Duplicidades:** Ao cadastrar múltiplos produtos do mesmo tipo, o sistema consulta a tabela `produtos` no Supabase e atribui automaticamente um sufixo numérico incremental exclusivo (ex: `03`, `03-1`, `03-2`), respeitando a constraint de unicidade `produtos_codigo_key`. Em caso de rejeição HTTP 409 (código `23505`), o erro é tratado e exibido de forma transparente ao usuário sem recorrer a fallbacks de cadastros fictícios no mock local.

### Usuários de Teste

| Nome     | E-mail                        | Cargo       | Filial Atribuída | Escopo / Permissões | Pedidos de Compra |
| -------- | ----------------------------- | ----------- | ---------------- | ------------------- | ----------------- |
| Anderson | `anderson.func@empresa.com`   | Funcionário | Filial Centro (ID 1) | Restrito à Filial Centro | Bloqueado |
| Robson   | `robson.grt@empresa.com`      | Gerente     | Filial Oeste (ID 5)  | Acesso Geral (5 Filiais) | Habilitado |
| Isabella | `isabella.func@empresa.com`   | Funcionária | Filial Norte (ID 2)  | Restrito à Filial Norte  | Bloqueado |
| Manuella | `manuella.grt@empresa.com`    | Gerente     | Filial Leste (ID 4)  | Acesso Geral (5 Filiais) | Habilitado |
| Nicoly   | `nicoly.func@empresa.com`     | Funcionária | Filial Sul (ID 3)    | Restrito à Filial Sul    | Bloqueado |
| Nicoly   | `nicoly.grt@empresa.com`      | Gerente     | Filial Sul (ID 3)    | Acesso Geral (5 Filiais) | Habilitado |

*Notas de Autenticação Definitiva e RLS:*
- **Autenticação 100% Supabase Auth:** O fluxo de login depende exclusivamente de `supabase.auth.signInWithPassword({ email, password })`.
- **Remoção do Fallback BCrypt:** O mecanismo de comparação local de hash BCrypt e a dependência da biblioteca `bcryptjs` foram integralmente removidos de `main.js` e `index.html`.
- **Papel da Tabela `public.usuarios`:** A tabela `public.usuarios` funciona estritamente como perfil complementar (`nome`, `cargo`, `filial_id`, `ativo`). O campo `senha` não é consultado durante a autenticação.
- **Isolamento e Vínculo de Perfis:** Mapeamento por e-mail unívoco no Supabase Auth (`auth.jwt() ->> 'email' = public.usuarios.email`).

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
