# DOCUMENTAÇÃO OFICIAL E ESPECIFICAÇÃO DO SISTEMA — LUME JOIAS

---

## 1. Visão Geral e Objetivo do Sistema

O **Lume Joias** é um Sistema de Gerenciamento de Estoque (SGE) multi-filial desenvolvido para controlar a movimentação, armazenagem, transferências inter-filiais e pedidos de compra de joias e semijoias.

### Objetivos Principais:
- Controlar com precisão o saldo de estoque de produtos por filial em tempo real.
- Garantir rastreabilidade total das movimentações de estoque (entradas, saídas, transferências e ajustes).
- Aplicar controle de acesso baseado em funções (RBAC - Role-Based Access Control) diferenciando permissões entre **Gerentes** e **Funcionários**.
- Impedir inconsistências de estoque via validações de negócio, integridade referencial e políticas de segurança no banco de dados (Row Level Security - RLS).
- Disponibilizar uma interface Single Page Application (SPA) responsiva, intuitiva e sem necessidade de bundlers ou frameworks pesados.

---

## 2. Arquitetura Atual e Tecnologias Utilizadas

O sistema adota uma arquitetura 100% Jamstack / Serverless:

```text
+-----------------------------------------------------------------------+
|                           CLIENTE (BROWSER)                           |
|  Single Page Application (SPA): HTML5 + CSS3 + Vanilla JavaScript ES6+|
+-----------------------------------------------------------------------+
                                   |
                     HTTPS / REST API & WebSockets
                                   |
                                   v
+-----------------------------------------------------------------------+
|                       SUPABASE BACKEND-AS-A-SERVICE                   |
|  - Supabase Auth (GoTrue) - Autenticação JWT                          |
|  - PostgREST API - Direct Database Operations                         |
|  - Realtime Engine - WebSockets (sge_realtime_channel)                |
|  - PostgreSQL Database - Tabelas, FKs, Triggers e RLS                 |
+-----------------------------------------------------------------------+
                                   |
                            Hospedagem Static
                                   v
+-----------------------------------------------------------------------+
|                             GITHUB PAGES                              |
|  Deploy contínuo via GitHub Actions Workflow (.github/workflows)       |
+-----------------------------------------------------------------------+
```

### Tecnologias e Bibliotecas:
- **Frontend Core:** HTML5, CSS3, JavaScript Vanilla ES6+.
- **Cliente Supabase:** CDN oficial `@supabase/supabase-js` (versão 2).
- **Hospedagem:** GitHub Pages estático.
- **Backend / Banco de Dados:** Supabase Cloud (PostgreSQL 15+).
- **CI/CD:** GitHub Actions (`.github/workflows/static.yml`).
- **Automação de Testes:** Python 3 + Playwright para testes de integração end-to-end e validação visual responsiva.

---

## 3. Estrutura de Arquivos e Responsabilidades

Atualmente, o repositório está organizado diretamente na raiz para publicação direta no GitHub Pages:

```text
/
├── index.html                   # Estrutura HTML única da SPA (Modals, Tabelas, Cards)
├── main.js                      # Lógica da aplicação, roteamento SPA, Supabase Auth, Realtime e Manipulação DOM
├── style.css                    # Estilização global, temas (Claro/Escuro), layout responsivo e grids
├── supabase_rls_policies.sql    # DDL com políticas de segurança em nível de linha (RLS) para PostgreSQL
├── img/                         # Recursos visuais e marcas do sistema
│   ├── Lume.png                 # Logotipo oficial Lume Joias (modo claro)
│   └── LumeEscuro.png           # Logotipo oficial Lume Joias (modo escuro)
├── .github/workflows/           # Automação de CI/CD
│   └── static.yml               # Workflow de publicação do GitHub Pages
├── especificações do sistema/   # Diretório oficial de documentação
│   └── DOCUMENTACAO_SISTEMA_LUME_JOIAS.md # Este documento unificado
├── tests/                       # Diretório oficial de testes automatizados
│   └── test_*.py                # Suíte de testes Playwright/Python
└── scripts/                     # Diretório de utilitários operacionais e administrativos
    ├── executar_limpeza_supabase.py # Utilitário para limpeza controlada de tabelas operacionais
    └── migrar_usuarios_supabase.py  # Utilitário administrativo para provisionamento no Supabase Auth
```

---

## 4. Instalação, Execução e Publicação no GitHub Pages

### 4.1 Execução Local
Para rodar e testar a aplicação localmente:
1. Navegue até a raiz do repositório.
2. Inicie um servidor HTTP local simples em Python (porta 8080):
   ```bash
   python3 -m http.server 8080 -d .
   ```
3. Acesse `http://localhost:8080` no navegador.

### 4.2 Publicação no GitHub Pages
- O arquivo `.github/workflows/static.yml` é disparado automaticamente a cada push na branch `master`.
- O workflow copia os arquivos estáticos (`index.html`, `main.js`, `style.css` e o diretório `img/`) para o diretório de compilação `_site` e realiza o deploy no GitHub Pages.
- **URL Publicada:** `https://nickszxss.github.io/Lume-Joias/`

---

## 5. Integração com Supabase e Configuração da Conexão

A comunicação entre a SPA e o Supabase ocorre de forma direta no navegador através de credenciais públicas do projeto:

- **Supabase URL:** `https://pssrggtqmphcpqbdhjex.supabase.co`
- **Chave Pública Anon/Publishable:** `sb_publishable_p9yLQDR5lj0uT0F5NQ1_aw_6TyS9job`
- **Inicialização no `main.js`:**
  ```javascript
  const client = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
  ```

### Comunicação em Tempo Real (Realtime WebSockets):
A SPA mantém um canal WebSocket ativo (`sge_realtime_channel`) escutando eventos de alteração no banco de dados para sincronizar os dados na tela em tempo real entre diferentes sessões de usuários:
```javascript
client.channel('sge_realtime_channel')
  .on('postgres_changes', { event: '*', schema: 'public' }, () => reordenarEAtualizarTelas())
  .subscribe();
```

---

## 6. Tabelas do Banco de Dados e Políticas RLS

O banco de dados relacional PostgreSQL no Supabase contém 8 tabelas principais na schema `public` (conforme verificado em `supabase_rls_policies.sql` e `DOCUMENTACAO.md`):

### 6.1 Esquema do Banco de Dados Real
1. **`usuarios`** (`id`, `nome`, `email`, `senha`, `cargo`, `tipo`, `filial_id`, `ativo`, `created_at`, `auth_user_id`) — Cadastro dos perfis dos usuários e vinculação de filial com chave estrangeira `auth_user_id UUID REFERENCES auth.users(id)`.
2. **`filiais`** (`id`, `nome`, `endereco`, `cidade`, `estado`, `ativa`, `created_at`) — Cadastro das 5 filiais oficiais (Centro, Norte, Sul, Leste, Oeste).
3. **`produtos`** (`id`, `nome`, `descricao`, `codigo`, `unidade_medida`, `qtd_minima`, `ativo`, `created_at`) — Catálogo de produtos/joias com SKUs (código) e categorias automáticas (`ANEL`, `PULSEIRA`, `SOLITARIA`, `COLAR`, `BRINCO`).
4. **`produtos_filiais_inativos`** (`id`, `produto_id`, `filial_id`, `desativado_por`, `created_at`) — Registro de inativação/retirada de uso local por produto e filial solicitada por gerentes.
4. **`estoques`** (`id`, `filial_id`, `produto_id`, `quantidade`, `status`, `updated_at`) — Saldo atual de cada produto por filial.
5. **`movimentacoes`** (`id`, `produto_id`, `filial_id`, `usuario_id`, `tipo`, `quantidade`, `quantidade_anterior`, `quantidade_nova`, `motivo`, `created_at`) — Histórico auditável de movimentações.
6. **`transferencias`** (`id`, `origem_id`, `destino_id`, `produto_id`, `usuario_id`, `quantidade`, `status`, `observacao`, `created_at`, `concluida_at`) — Registro de solicitações de transferência inter-filiais (`pendente`, `concluida`).
7. **`pedidos_compra`** (`id`, `filial_id`, `usuario_id`, `status`, `observacao`, `created_at`, `recebido_at`) — Ordens de compra de produtos (`aberto`, `recebido`).
8. **`itens_pedido_compra`** (`id`, `pedido_id`, `produto_id`, `quantidade`) — Itens detalhados de cada pedido de compra.

### 6.2 Políticas de Segurança RLS (Row Level Security)
As políticas RLS estão definidas em `supabase_rls_policies.sql` e garantem a nível de banco:
- **`public.usuarios` (Vínculo Seguro Auth.uid):** Leitura e autorização resolvidas via `auth_user_id = auth.uid()` com `ativo = true` ou por gerentes estritamente para usuários da sua própria filial (`filial_id = public.get_auth_user_filial_id()`), eliminando dependência do e-mail do JWT para autorização.
- **Ajuste Atômico de Estoque (`ajustar_estoque_rpc`):** Processamento transacional com autorização estrita por filial (`p_filial_id = usuario.filial_id`), bloqueio pessimista `FOR UPDATE` e chave transacional de concorrência `pg_advisory_xact_lock` para criar e atualizar linhas de estoque em concorrência sem saldos negativos.
- **Fechamento de UPDATE Direto em Estoques:** Bloqueio total de permissões de `UPDATE` direto na tabela `public.estoques`, forçando a execução exclusiva via RPCs atômicas (`ajustar_estoque_rpc`, `concluir_transferencia_rpc`, `receber_pedido_rpc`).
- **Inativação Local por Filial (`produtos_filiais_inativos`):** RLS de leitura estritamente isolado pela filial do usuário (`filial_id = public.get_auth_user_filial_id()`) e inserção/exclusão restrita exclusivamente a gerentes da própria filial, sem alterar o cadastro global nem as demais filiais.
- Leitura de produtos, estoques e filiais para qualquer usuário autenticado.

---

## 7. Autenticação, Identificação do Usuário e Controle de Permissões

### 7.1 Fluxo de Autenticação e Vínculo de Identidade (Auth ↔ Usuários)
- A autenticação é realizada via **Supabase Auth / GoTrue** com e-mail e senha (`client.auth.signInWithPassword`).
- Após o login bem-sucedido via Auth, o sistema busca o perfil do usuário na tabela `public.usuarios` primariamente através do vínculo unívoco `auth_user_id = auth.user.id`.
- As funções auxiliares e RPCs no banco de dados (`get_auth_user_cargo()`, `get_auth_user_filial_id()`, `get_auth_user_id()`, `ajustar_estoque_rpc`, `concluir_transferencia_rpc`, `receber_pedido_rpc`) validam a identidade internamente por `u.auth_user_id = auth.uid()` e `u.ativo = true`.
- Se o usuário não possuir registro correspondente ativo em `public.usuarios` ou seu vínculo estiver ausente/inativo, o acesso é sumariamente negado com zero permissões.

### 7.2 Migração Versionada do Vínculo de Identidade
O repositório possui o script de migração DDL preparado em `scripts/migracao_vincular_auth_usuarios.sql`.
- **Objetivo:** Adicionar a coluna `auth_user_id UUID` com constraint de Foreign Key `fk_usuarios_auth_user` para `auth.users(id)` e constraint de Unicidade `uq_usuarios_auth_user_id`.
- **Mecanismo de Migração Inicial:** Realiza a associação inicial dos usuários cadastrados às contas do Supabase Auth por correspondência exata de e-mail (`LOWER(u.email) = LOWER(a.email)`).
- **Validações de Interrupção Atômica:** Interrompe com `RAISE EXCEPTION` em caso de:
  1. Registro interno em `public.usuarios` sem conta correspondente em `auth.users`.
  2. Ambiguidade (mais de uma conta Auth para o mesmo e-mail interno).
  3. Conta Auth sendo associada a mais de um usuário interno.
- **Idempotência:** Pode ser reexecutado com segurança sem alterar vínculos válidos preexistentes.
- **AVISO IMPORTANTE:** A migração **NÃO foi executada** no ambiente Supabase Cloud remoto nesta etapa. O SQL permanece versionado para revisão e aplicação futura no banco de produção/homologação.
- **Validação Local:** A exatidão do SQL e das políticas RLS é testada localmente executando:
  ```bash
  /home/jules/.local/bin/pytest tests/test_9_sql_rls_validation.py
  ```
- **Passos Futuros no Supabase Remote:**
  1. Aplicar a migração `scripts/migracao_vincular_auth_usuarios.sql` no SQL Editor do console Supabase.
  2. Aplicar o DDL atualizado de políticas RLS em `supabase_rls_policies.sql`.
  3. Verificar se todos os 7 usuários ativos possuem `auth_user_id` preenchido sem ambiguidades.

### 7.2 Perfis Oficiais Cadastrados:
| Usuário | E-mail | Cargo | Filial Associada |
|---|---|---|---|
| Anderson | `anderson.func@empresa.com` | Funcionário | Filial Centro (ID 1) |
| Isabella | `isabella.func@empresa.com` | Funcionário | Filial Norte (ID 2) |
| Nicoly Funcionária | `nicoly.func@empresa.com` | Funcionário | Filial Sul (ID 3) |
| Manuella | `manuella.grt@empresa.com` | Gerente | Filial Leste (ID 4) |
| Robson | `robson.grt@empresa.com` | Gerente | Filial Oeste (ID 5) |
| Nicoly Gerente | `nicoly.grt@empresa.com` | Gerente | Filial Sul (ID 3) |
| Nicoly Teste | `nicoly.teste@empresa.com` | Funcionário | Filial Sul (ID 3) |

---

## 8. Regras de Negócio do Sistema

### 8.1 Produtos e Mapeamento de SKU Padronizado (01 a 09)
No cadastro de novos produtos, o tipo/nome da joia é selecionado obrigatoriamente a partir de um dropdown com 9 opções predefinidas. Cada tipo preenche automaticamente o código base do SKU (de 2 dígitos):
- **Colar de prata:** SKU Base `01`
- **Colar de ouro:** SKU Base `02`
- **Anel de prata:** SKU Base `03`
- **Anel de ouro:** SKU Base `04`
- **Brinco de prata:** SKU Base `05`
- **Brinco de ouro:** SKU Base `06`
- **Solitária:** SKU Base `07`
- **Pulseira de prata:** SKU Base `08`
- **Pulseira de ouro:** SKU Base `09`

#### Garantia de Unicidade de SKU:
Para evitar erro HTTP 409 (`produtos_codigo_key` duplicate key violation), a função `api.criarProduto` verifica o banco e adiciona sufixos numéricos sequenciais automáticos quando o SKU base já existir (ex: `03`, `03-1`, `03-2`).

### 8.2 Estoque e Categorias Automáticas
- A categoria do produto é determinada automaticamente com base no tipo do produto e validada por `CHECK constraint` no banco: `ANEL`, `PULSEIRA`, `SOLITARIA`, `COLAR` e `BRINCO`.
- A funcionalidade de Estoque Mínimo foi descontinuada e removida da UI para simplificar o controle operacional, mantendo os status de saldo como **Disponível** (`quantidade > 0`) e **Zerado** (`quantidade = 0`).
- Todas as operações de ajuste de estoque utilizam a RPC atômica `ajustar_estoque_rpc` com bloqueio pessimista `SELECT FOR UPDATE`.

### 8.3 Edição e Inativação Lógica de Produtos
- **Apenas Gerentes** têm permissão no frontend e no RLS para editar dados de um produto ou inativá-lo (`api.inativarProduto`).
- A inativação é **lógica** (`ativo = false`). O registro do produto é preservado no banco para manter a integridade histórica de movimentações, mas é ocultado das opções para novas transferências e pedidos de compra.

### 8.4 Transferências Inter-filiais
- Funcionários e gerentes podem solicitar transferências de produtos entre a sua filial e outra filial de destino.
- **Conclusão de Transferência:** Apenas o **gerente** ou os **funcionários atribuídos à filial de DESTINO** podem marcar a transferência como concluída. Funcionários da filial de origem ou de terceiras filiais são impedidos de concluir a transferência.

### 8.5 Recebimento de Pedidos de Compra
- Ao registrar um Pedido de Compra, o status inicial é `aberto` / `solicitado`.
- Ao clicar em *"Marcar como Recebido"*, o sistema atualiza o status para `recebido`, registra a data `recebido_at`, incrementa automaticamente o saldo de estoque da filial destinatária e gera uma entrada de auditoria na tabela `movimentacoes`.

---

## 9. Interface, Identidade Visual, Tipografia e Temas

### 9.1 Identidade Visual e Temas
- A marca visual é representada pelos logotipos `img/Lume.png` (modo claro) e `img/LumeEscuro.png` (modo escuro).
- O sistema suporta alternância dinâmica de tema através de variáveis CSS no `style.css`.

### 9.2 Tipografia
- A tipografia oficial do projeto utiliza a família de fontes: `Century Gothic`, `system-ui`, `-apple-system`, `sans-serif`.

---

## 10. Segurança, Validações e Cuidados Operacionais

- **Senhas e Tokens:** As senhas dos usuários no Supabase GoTrue e na tabela `usuarios` utilizam hash de criptografia seguro (BCrypt). Nenhuma credencial privada ou token administrativo (service role key) está versionada no código.
- **Validação de Entradas:** Formulários utilizam campos obrigatórios (`required`), dropdowns restritos e validações no cliente e no servidor para prevenir SQL Injection e inserção de dados inconsistentes.
- **Tratamento de Exceções HTTP 409:** Erros de violação de unicidade são interceptados exibindo mensagens claras ao usuário final em vez de quebrar a interface.

---

## 11. Testes Existentes e Procedimentos Seguros de Validações

O projeto dispõe de 18 scripts de teste automatizados em Python utilizando a biblioteca Playwright para validação E2E:
- `tests/test_auditoria_final.py`: Suíte principal de auditoria de ponta a ponta (login, SKUs, isolamento de estoque por filial e persistência F5).
- `tests/test_auth.py`, `tests/test_dashboard_funcionario.py`, `tests/test_nicoly_func.py`, `tests/test_nicoly_grt.py`: Testes de autenticação e RBAC.
- `tests/test_pedidos.py`, `tests/test_tarefa1_recebimento_pedidos.py`: Fluxo de ordens e recebimentos de compra.
- `tests/test_tarefa2_restringir_transferencias.py`: Validação das restrições de conclusão de transferência.
- `tests/test_tarefa3_sku.py`, `tests/test_tarefa3_placeholder_categoria.py`: Testes de cadastro e SKUs.
- `tests/test_tarefa4_editar_inativar_produtos.py`, `tests/test_tarefa4_filtro_estoque.py`: Gerenciamento de catálogo e filtros.
- `tests/test_tarefa5_realtime.py`, `tests/test_tarefa5_limpeza_produtos.py`: Comunicação Realtime WebSocket e estado.
- `tests/test_tarefa6_estoque_minimo.py`: Validação de alertas de estoque mínimo.
- `tests/test_responsive.py`, `tests/test_responsivo_t6.py`: Testes de responsividade móvel e layout.

---

## 12. Histórico Resumido de Auditorias e Correções Relevantes

1. **Correção do Erro HTTP 409 no Cadastro de Produtos:**
   - *Problema:* Tentativas de cadastrar produtos do mesmo tipo resultavam em erro HTTP 409 por violação da constraint `produtos_codigo_key` no SKU estático.
   - *Solução:* Implementado gerador dinâmico de SKU com sufixos sequenciais (`03-1`, `03-2`) e padronização do catálogo para base de 2 dígitos (`01` a `09`).
2. **Restrição na Conclusão de Transferências:**
   - *Problema:* Qualquer usuário podia concluir transferências pendentes de qualquer filial.
   - *Solução:* Restringida a ação de conclusão exclusivamente a gerentes e funcionários lotados na filial de destino.
3. **Consolidação do Frontend na Raiz:**
   - *Problema:* Estrutura legada em `src/main/resources/static/` causava divergências de publicação no GitHub Pages.
   - *Solução:* Arquivos `index.html`, `main.js` e `style.css` consolidados na raiz do repositório, com workflow do GitHub Actions ajustado.
4. **Substituição do Campo Valor Inicial por Estoque Mínimo:**
   - *Problema:* Produtos novos entravam com estoque inicial direto sem rastro de movimentação de entrada.
   - *Solução:* O modal foi alterado para selecionar a quantidade mínima e inicializar o saldo como `0` em `estoques`.

---

## 13. Problemas Conhecidos, Limitações e Pendências

- **Limite de Envio de E-mails do GoTrue:**
  - O serviço gratuito do Supabase GoTrue aplica limite de envio de e-mails para criação de conta via anon key (HTTP 429 `over_email_send_rate_limit`). Por isso, novos usuários devem ser provisionados administrativamente via script (`migrar_usuarios_supabase.py`) ou console do Supabase.
- **Persistência de Usuário de Teste:**
  - O usuário `nicoly.teste@empresa.com` existe em `auth.users` e `public.usuarios` para fins de homologação contínua da suíte Playwright.

---

## 14. Arquitetura de Idempotência e Suporte a Retentativas de Conexão

### 14.1. Visão Geral do Mecanismo
Para garantir a integridade dos saldos de estoque e prevenir movimentações e registros de auditoria duplicados quando ocorrem perdas de conexão de rede, o sistema Lume-Joias utiliza uma arquitetura de idempotência atômica em nível de banco de dados (`PostgreSQL PL/pgSQL`) e cliente frontend (`main.js`).

### 14.2. RPCs e Escopos Canônicos de Idempotência
Todas as 5 RPCs críticas de movimentação e criação possuem suporte estrito a chaves de idempotência UUID v4 e escopos canônicos isolados:
1. `ajustar_estoque_rpc(p_produto_id, p_filial_id, p_tipo, p_quantidade, p_motivo, p_idempotency_key)` — Escopo: `ajustar_estoque`
2. `criar_pedido_compra_rpc(p_filial_id, p_produto_id, p_quantidade, p_idempotency_key)` — Escopo: `criar_pedido`
3. `cadastrar_produto_com_estoques_rpc(p_nome, p_sku, p_categoria, p_qtd_minima, p_idempotency_key)` — Escopo: `cadastrar_produto`
4. `concluir_transferencia_rpc(p_transferencia_id, p_observacao, p_idempotency_key)` — Escopo: `concluir_transferencia`
5. `receber_pedido_rpc(p_pedido_id, p_observacao, p_idempotency_key)` — Escopo: `receber_pedido`

### 14.3. Regras e Garantias de Execução
- **Advisory Locks Transacionais (`pg_advisory_xact_lock`):** A recepção de uma chave de idempotência aciona um bloqueio transacional determinístico no hash da chave (`hashtext('idempotency:' || p_idempotency_key)`), serializando requisições simultâneas e eliminando condições de corrida.
- **Validação Sequencial Tríplice (Propriedade, Escopo e Hash):** Cada RPC valida em sequência:
  1. *Propriedade do Usuário:* `v_idempotent_rec.usuario_id IS DISTINCT FROM v_user_id` (impede sequestro ou exposição de respostas entre usuários).
  2. *Escopo Canônico:* `v_idempotent_rec.escopo IS DISTINCT FROM '<escopo_canonico>'` (impede reutilização de chaves entre operações distintas).
  3. *Hash MD5 de Parâmetros:* Se os parâmetros forem idênticos, retorna o resultado armazenado. Se divergirem, rejeita com exceção explícita.
- **Tratamento Imune a NULLs (`IS DISTINCT FROM`):** Todas as comparações lógicas utilizam `IS DISTINCT FROM` e `COALESCE` para evitar falhas de lógica booleana trivalente diante de colunas nulas em dados legados.
- **Ciclo de Vida no Frontend (`main.js` & `sessionStorage`):** O frontend gerencia as chaves utilizando `ObterChaveIdempotenciaFrontend` e `LimparChaveIdempotenciaFrontend`. As chaves são persistidas no `sessionStorage` (sob a chave `lume_idempotency_${userId}_${escopo}_${id}`) com fallback transparente para mapas em memória. Em caso de perda de conexão de rede ou reload da página, a mesma chave é mantida e reenviada. A chave é expurgada do armazenamento local e da memória exclusivamente após a confirmação confiável de sucesso (`res.success === true`).
- **Pré-condições da Migração (`scripts/migracao_idempotencia_chaves.sql`):** A tabela `public.idempotencia_chaves` requer que a coluna `chave` possua restrição de unicidade `UNIQUE (chave)` e que todas as colunas críticas (`chave`, `usuario_id`, `escopo`, `parametros_hash`, `resultado_json`) sejam `NOT NULL`. A migração executa verificações prévias no `pg_constraint` e `pg_index` e realiza um `RAISE EXCEPTION` abortando a transação se forem detectados registros nulos de `usuario_id` ou chaves duplicadas.
