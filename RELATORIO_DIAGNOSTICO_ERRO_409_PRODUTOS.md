# RELATÓRIO DE DIAGNÓSTICO DE ERRO HTTP 409 NO CADASTRO DE PRODUTOS — LUME-JOIAS

---

## A. ESTADO DO PROJETO

- **Repositório:** Lume-Joias (Sistema de Gerenciamento de Estoque)
- **Branch Atual:** `jules-12160408106331505956-702d367f`
- **Commit Completo:** `b98693819f5b8cd606ea4844045d02d51d6d1d05` (Merge pull request #77)
- **Versão Analisada:** Frontend estático serverless integrado diretamente com Supabase BaaS (PostgreSQL + PostgREST REST API) via `@supabase/supabase-js`.
- **Arquivos Relevantes Analisados:**
  - `src/main/resources/static/main.js` (Lógica de inserção `api.criarProduto`, geração de SKU em `atualizarSkuPorTipo` / `MAPA_SKU`, e manipulador do modal `salvarProduto`).
  - `src/main/resources/static/index.html` (Modal `#modal-produto` e campos de formulário `#p-nome`, `#p-sku`, `#p-cat`, `#p-filial`, `#p-min`).
  - `supabase_rls_policies.sql` (Estrutura de Row Level Security e permissões do PostgreSQL).

---

## B. ERRO ENCONTRADO

- **Requisição que Falha:**
  `POST https://pssrggtqmphcpqbdhjex.supabase.co/rest/v1/produtos?columns=%22nome%22%2C%22codigo%22%2C%22descricao%22%2C%22qtd_minima%22%2C%22unidade_medida%22%2C%22ativo%22&select=*`
- **Status HTTP:** `409 Conflict`
- **Mensagem Completa do Supabase (Resposta JSON Obtida via REST API):**
  ```json
  {
    "code": "23505",
    "details": "Key (codigo)=(003) already exists.",
    "hint": null,
    "message": "duplicate key value violates unique constraint \"produtos_codigo_key\""
  }
  ```

---

## C. CAUSA IDENTIFICADA

- **Causa Comprovada:** Violência da restrição de unicidade (`UNIQUE constraint`) chamada `produtos_codigo_key` na coluna `codigo` da tabela `produtos` do banco de dados PostgreSQL do Supabase.
- **Código de Erro PostgreSQL:** `23505` (`unique_violation`).
- **Componente e Campo Envolvido:**
  - Tabela: `public.produtos`
  - Coluna: `codigo`
  - Constraint: `produtos_codigo_key` (UNIQUE)
- **Mecanismo de Falha:**
  1. O frontend possui um mapeamento estático fixo (`MAPA_SKU` em `main.js`) entre o tipo/nome de joia selecionado no dropdown e o valor preenchido no campo legível `#p-sku` (exemplo: "Anel de prata" sempre gera o SKU/código `"003"`).
  2. Quando um produto do tipo "Anel de prata" já se encontra cadastrado na tabela `produtos` (com `codigo = '003'`), qualquer tentativa subsequente de salvar outro produto do mesmo tipo tentará inserir novamente `codigo = '003'`.
  3. O PostgreSQL rejeita a instrução `INSERT` por violação da constraint `UNIQUE` (`produtos_codigo_key`), retornando erro `23505`, que o PostgREST traduz para a resposta HTTP `409 Conflict`.

---

## D. HIPÓTESES RESTANTES E ANÁLISE DE OUTRAS HIPÓTESES

- **Hipótese A — Código ou SKU duplicado:** **CONFIRMADA COM 100% DE CERTEZA.** Conforme evidenciado na resposta direta da API REST (`Key (codigo)=(003) already exists.`), a tentativa de inserir um SKU/código já existente na tabela aciona a restrição `UNIQUE`.
- **Hipótese B — Outra restrição de unicidade (ex: Chave primária `id`):** **DESCRIPTADA/DESAGRADADA.** O id é um auto-incremento (SERIAL/BIGSERIAL) e não é enviado na requisição POST de inserção.
- **Hipótese C — Incompatibilidade entre frontend e banco:** **PARCIALMENTE CONFIRMADA.** O frontend trata o SKU/código como um identificador fixo por categoria/tipo de joia (`MAPA_SKU`), enquanto o banco de dados exige que a coluna `codigo` seja estritamente **única por produto**.
- **Hipótese D — Trigger ou regra de negócio:** **DESCRIPTADA.** Não existem triggers de bloqueio ativas provocando o erro 409.
- **Hipótese E — Problema de RLS / Permissões:** **DESCRIPTADA.** O RLS permite leitura pública em `produtos` e inserção por usuários autenticados. Se fosse bloqueio de RLS, o PostgREST retornaria HTTP `403 Forbidden` ou `401 Unauthorized`, e não HTTP `409 Conflict`.

---

## E. ANÁLISE DO FRONTEND

- **Arquivos e Funções Envolvidas:**
  - File: `src/main/resources/static/main.js`
  - Funções: `salvarProduto()`, `api.criarProduto(dados)`, `atualizarSkuPorTipo()`, `obterSkuPorTipo(nome)`, e o objeto constante `MAPA_SKU`.
- **Campos Enviados na Requisição:**
  ```javascript
  const payloadProduto = {
    nome: dados.nome,                // ex: "Anel de prata"
    codigo: dados.sku,               // ex: "003" (gerado estaticamente por MAPA_SKU)
    descricao: dados.categoria || 'Geral', // ex: "Anéis"
    qtd_minima: dados.qtd_minima || 10,  // ex: 10
    unidade_medida: 'unidade',       // "unidade"
    ativo: true                      // true
  };
  ```
- **Lógica de Geração do Código/SKU:**
  O frontend possui o seguinte mapa estático:
  ```javascript
  const MAPA_SKU = {
    'Colar de prata': '001',
    'Colar de ouro': '002',
    'Anel de prata': '003',
    'Anel de ouro': '004',
    'Brinco de prata': '005',
    'Brinco de ouro': '006',
    'Solitária': '007',
    'Pulseira de prata': '008',
    'Pulseira de ouro': '009'
  };
  ```
  O campo `#p-sku` é marcado como `readonly` no formulário e é atualizado automaticamente sempre que o usuário altera a seleção do dropdown `#p-nome`. Dessa forma, o usuário não consegue digitar manualmente um SKU diferente nem adicionar um sufixo para desambiguar.
- **Tratamento de Erros Atual:**
  Em `api.criarProduto`, ao receber qualquer erro na inserção via Supabase (`pErr`), o código faz um fallback silencioso chamando `resolverMockLocal('/produtos', ...)`, o que simula a adição na memória local JS, porém **não persiste no banco Supabase** e pode mascarar o erro para o usuário final ou tentar reconexões.

---

## F. ANÁLISE DO SUPABASE (BANCO DE DADOS)

- **Estrutura da Tabela `produtos`:**
  - `id` (bigint / integer, PRIMARY KEY, Auto-increment)
  - `nome` (text, NOT NULL)
  - `descricao` (text)
  - `codigo` (text, UNIQUE via `produtos_codigo_key`)
  - `unidade_medida` (text, default 'unidade')
  - `qtd_minima` (integer, default 0)
  - `ativo` (boolean, default true)
  - `created_at` (timestamptz, default now())
- **Constraints Identificadas:**
  - `produtos_pkey` (PRIMARY KEY em `id`)
  - `produtos_codigo_key` (UNIQUE em `codigo`)
- **Políticas RLS (`supabase_rls_policies.sql`):**
  - `"Leitura Publica Produtos"`: Permite `SELECT` para todos os usuários autenticados/públicos.
  - `"Atualizacao Produtos Apenas Gerente"`: Restringe `UPDATE` para gerentes.
  - As inserções executam dentro das regras ativas do Supabase.

---

## G. ALTERNATIVAS DE CORREÇÃO

### Alternativa 1: Tornar o campo SKU editável ou dinâmico com gerador de sufixo sequencial / timestamp no Frontend
- **O que precisaria ser alterado:**
  1. Remover o atributo `readonly` do campo `#p-sku` no `index.html` ou permitir que o frontend concatene um identificador único/sequencial (ex: `003-01`, `003-02` ou consulta ao maior código existente antes da inserção).
  2. Ajustar `atualizarSkuPorTipo()` no `main.js` para sugerir o SKU base e validar/gerar um sufixo dinâmico caso o SKU base já exista.
- **Benefícios:** Mantém a constraint de integridade `produtos_codigo_key` intacta no banco de dados, garantindo que nenhum produto tenha código duplicado.
- **Riscos:** Baixo risco. Requer ajuste na suíte de testes Playwright caso algum teste dependa de SKUs fixos rígidos sem sufixo.
- **Impacto em Dados Existentes:** Nenhum. Produtos existentes preservam seus SKUs atuais.

### Alternativa 2: Tratar graciosamente o erro 409 no frontend informando o usuário ou sugerindo/auto-incrementando o SKU
- **O que precisaria ser alterado:**
  1. Capturar explicitamente o erro HTTP 409 (`code: "23505"`) dentro de `api.criarProduto` e `salvarProduto`.
  2. Exibir um alerta/toast explicativo ao usuário ("Já existe um produto cadastrado com o código/SKU X. Por favor, utilize um código diferente ou altere o produto existente.") em vez de acionar o fallback para mock local.
- **Benefícios:** Melhora a transparência da interface e evita dados inconsistentes no mock local.
- **Riscos:** Mínimo.
- **Impacto em Dados Existentes:** Nenhum.

### Alternativa 3: Remover a constraint `UNIQUE` (`produtos_codigo_key`) no Supabase
- **O que precisaria ser alterado:** Executar `ALTER TABLE public.produtos DROP CONSTRAINT produtos_codigo_key;` no banco.
- **Benefícios:** Elimina o erro HTTP 409 imediatamente ao permitir códigos repetidos.
- **Riscos e Desvantagens ALTÍSSIMOS:** Quebra a integridade referencial do sistema, permite SKUs duplicados para produtos distintos, pode causar ambiguidades em buscas por código e viola boas práticas de modelagem de banco de dados. **NÃO RECOMENDADO.**

---

## H. RECOMENDAÇÃO FINAL

A solução mais segura e recomendada é uma **combinação das Alternativas 1 e 2**:

1. **Manter a constraint `produtos_codigo_key` (UNIQUE) no banco de dados**, pois ela garante a integridade do cadastro e evita ambiguidade de produtos no estoque.
2. **Ajustar a lógica do Frontend (`main.js`)**:
   - Ao selecionar um tipo no dropdown `#p-nome` (ex: "Anel de prata"), preencher o SKU base ("003"), mas verificar no banco (ou permitir um sufixo numérico automático como "003-1", "003-2" se "003" já existir).
   - Tratar adequadamente o erro 409 (`code 23505`) no modal de cadastro, exibindo uma mensagem clara para o usuário em vez de falhar silenciosamente para o mock local.

---

## I. AVALIAÇÃO DA LIMPEZA DE DADOS (ZERAR A TABELA `produtos`)

- **A causa comprovada depende de registros existentes?**
  Sim, o conflito HTTP 409 ocorre especificamente quando tenta-se inserir um código (ex: `'003'`) que **já existe** na tabela `produtos`.
- **Se os produtos fossem removidos, o conflito provavelmente desapareceria?**
  Sim. Com a tabela vazia, o primeiro cadastro de cada um dos 9 tipos do `MAPA_SKU` funcionaria com sucesso.
- **O erro poderia continuar ocorrendo com a tabela vazia?**
  Sim, o erro voltaria a ocorrer **imediatamente na segunda vez** que qualquer usuário tentasse cadastrar um segundo produto do mesmo tipo (ex: cadastrar dois "Anéis de prata" diferentes), pois ambos gerariam o mesmo SKU estático `"003"`.
- **Existe risco de perder dados sem resolver o problema?**
  Sim. Apagar os produtos existentes limpa a tabela temporariamente, mas não resolve a causa raiz do problema no código do frontend (geração estática de SKU sem desambiguação).
- **Conclusão:** É **indispensável** corrigir a lógica do frontend de geração de SKU antes ou juntamente com qualquer operação de reestruturação de dados.

---

## J. IMPACTO NAS OUTRAS FUNCIONALIDADES

- **Cadastro e Edição de Produtos:** O ajuste permitirá cadastrar múltiplos produtos da mesma categoria sem erros.
- **Estoques por Filial, Movimentações e Transferências:** Como essas tabelas utilizam a chave primária `produto_id` (integer) e não o campo `codigo`/SKU para seus relacionamentos `FOREIGN KEY`, a ajuste no SKU não afetará a integridade nem o funcionamento dessas rotinas.
- **Pedidos de Compra:** Não haverá impacto negativo, mantendo os vinculos por `produto_id`.
- **Login, Usuários, Permissões e RLS:** Zero impacto.

---

## K. TESTES FUTURO ESPERADOS

1. Teste de cadastro de produto único com SKU não existente (deve retornar HTTP 201/200 e salvar no Supabase).
2. Teste de tentativa de cadastro de produto duplicado (deve tratar o conflito graciosamente e notificar o usuário).
3. Teste de regressão completo da suíte Playwright (`python3 test_auditoria_final.py`).

---

## L. DOCUMENTOS QUE PRECISARIAM SER ATUALIZADOS FUTURAMENTE

1. `/DOCUMENTACAO.md`: Registrar a regra de geração de SKU e o tratamento de unicidade do código do produto.
2. `/SPEC.md`: Registrar a especificação do comportamento do campo SKU no formulário de cadastro de produtos.

---

## M. CONFERÊNCIA FINAL

```text
DIAGNÓSTICO: CONCLUÍDO
CÓDIGO ALTERADO: NÃO
BANCO ALTERADO: NÃO
DADOS ALTERADOS: NÃO
CONFIGURAÇÕES ALTERADAS: NÃO
CORREÇÃO IMPLEMENTADA: NÃO
COMMIT DE CORREÇÃO: NÃO
PUSH DE CORREÇÃO: NÃO
```
