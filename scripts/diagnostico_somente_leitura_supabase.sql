-- =====================================================================
-- SCRIPT DE DIAGNÓSTICO SOMENTE LEITURA PARA SUPABASE / POSTGRESQL (LUME-JOIAS)
-- Finalidade: Verificar os pré-requisitos e o estado atual do banco de dados antes da aplicação do supabase_rls_policies.sql.
-- AVISO: ESTE SCRIPT CONTÉM EXCLUSIVAMENTE CONSULTAS SELECT (Egressa ZERO alteração no banco).
-- Local de execução: Supabase Dashboard -> SQL Editor.
-- =====================================================================

-- ---------------------------------------------------------------------
-- DIAGNÓSTICO 1: Verificar se o enum public.status_estoque contém 'suficiente+'
-- ---------------------------------------------------------------------
SELECT
  e.enumlabel AS valor_enum,
  EXISTS (
    SELECT 1 FROM pg_enum e2
    JOIN pg_type t2 ON e2.enumtypid = t2.oid
    WHERE t2.typname = 'status_estoque' AND e2.enumlabel = 'suficiente+'
  ) AS contem_suficiente_plus
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE t.typname = 'status_estoque'
ORDER BY e.enumsortorder;


-- ---------------------------------------------------------------------
-- DIAGNÓSTICO 2: Verificar se public.usuarios.auth_user_id existe e contagem de usuários ativos sem vínculo
-- ---------------------------------------------------------------------
SELECT
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'usuarios' AND column_name = 'auth_user_id'
  ) AS coluna_auth_user_id_existe,
  (
    SELECT count(*) FROM public.usuarios
    WHERE ativo = true AND (
      NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'usuarios' AND column_name = 'auth_user_id'
      ) OR auth_user_id IS NULL
    )
  ) AS usuarios_ativos_sem_vinculo_count;


-- ---------------------------------------------------------------------
-- DIAGNÓSTICO 3: Verificar e-mails duplicados em public.usuarios e auth.users
-- ---------------------------------------------------------------------
-- 3a. Duplicidades dentro da tabela public.usuarios (case-insensitive)
SELECT LOWER(email) AS email_normalizado, count(*) AS total_ocorrencias
FROM public.usuarios
GROUP BY LOWER(email)
HAVING count(*) > 1;

-- 3b. Cruzamento de e-mails entre public.usuarios e auth.users para identificar inconsistências/ambiguidades
SELECT
  u.id AS usuario_id,
  u.nome,
  u.email AS usuario_email,
  count(a.id) AS correspondencias_auth
FROM public.usuarios u
LEFT JOIN auth.users a ON LOWER(u.email) = LOWER(a.email)
GROUP BY u.id, u.nome, u.email
HAVING count(a.id) <> 1;


-- ---------------------------------------------------------------------
-- DIAGNÓSTICO 4: Verificar se existem quantidades negativas na tabela public.estoques
-- ---------------------------------------------------------------------
SELECT
  count(*) AS total_registros_negativos,
  COALESCE(json_agg(json_build_object('id', id, 'filial_id', filial_id, 'produto_id', produto_id, 'quantidade', quantidade)), '[]'::json) AS registros_negativos
FROM public.estoques
WHERE quantidade < 0;


-- ---------------------------------------------------------------------
-- DIAGNÓSTICO 5: Listar versões e assinaturas exatas das funções RPC ativas em public
-- ---------------------------------------------------------------------
SELECT
  p.proname AS nome_funcao,
  pg_get_function_identity_arguments(p.oid) AS argumentos_identificacao,
  pg_get_functiondef(p.oid) AS definicao_resumida
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'ajustar_estoque_rpc',
    'concluir_transferencia_rpc',
    'receber_pedido_rpc',
    'criar_pedido_compra_rpc',
    'cadastrar_produto_com_estoques_rpc'
  )
ORDER BY p.proname, argumentos_identificacao;


-- ---------------------------------------------------------------------
-- DIAGNÓSTICO 6: Proprietário, SECURITY DEFINER e privilégios de public.atualizar_status_estoque()
-- ---------------------------------------------------------------------
-- 6a. Proprietário, SECURITY DEFINER e search_path da função
SELECT
  p.proname AS funcao,
  pg_get_userbyid(p.proowner) AS proprietario,
  p.prosecdef AS is_security_definer,
  p.proconfig AS search_path_config
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'atualizar_status_estoque';

-- 6b. Privilégios de EXECUTE atribuídos à função
SELECT
  routine_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public' AND routine_name = 'atualizar_status_estoque';


-- ---------------------------------------------------------------------
-- DIAGNÓSTICO 7: Verificar o estado das políticas RLS, tabelas novas e permissões aplicadas parcialmente
-- ---------------------------------------------------------------------
-- 7a. Existência das tabelas novas do ecossistema
SELECT
  table_name,
  EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = t.table_name) AS tabela_existe,
  (SELECT rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename = t.table_name) AS rls_habilitado
FROM (VALUES ('produtos_filiais_inativos'), ('idempotencia_chaves')) AS t(table_name);

-- 7b. Quantidade de políticas RLS ativas por tabela no esquema public
SELECT
  tablename,
  count(*) AS total_politicas_rls
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;
