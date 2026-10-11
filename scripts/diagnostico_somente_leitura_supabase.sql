-- =====================================================================
-- PACOTE DE DIAGNÓSTICO SOMENTE LEITURA PARA O SUPABASE (LUME-JOIAS)
-- AVISO: CONSULTAS ESTRITAMENTE SOMENTE LEITURA (ZERO ALTERAÇÕES)
-- =====================================================================

-- 1. Estrutura e Colunas das Tabelas Principais
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('produtos', 'estoques', 'movimentacoes', 'filiais', 'carga_inicial_controle')
ORDER BY table_name, ordinal_position;

-- 2. Existência da Tabela e Sequência de Controle
SELECT
  EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'carga_inicial_controle') AS tabela_controle_existe,
  EXISTS (SELECT 1 FROM information_schema.sequences WHERE sequence_schema = 'public' AND sequence_name = 'carga_inicial_controle_id_seq') AS sequencia_controle_existe;

-- 3. Proprietários Reais dos Objetos do Esquema Público
SELECT tablename, tableowner FROM pg_tables WHERE schemaname = 'public'
UNION ALL
SELECT sequencename AS tablename, sequenceowner AS tableowner FROM pg_sequences WHERE schemaname = 'public';

-- 4. Proprietário, SECURITY DEFINER e Configuração da Função RPC (se já criada)
SELECT
  p.proname AS funcao,
  pg_get_userbyid(p.proowner) AS proprietario,
  p.prosecdef AS security_definer,
  p.proconfig AS search_path_config
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'executar_carga_inicial_estoque_rpc';

-- 5. Privilégios nas Tabelas e Sequências para anon, authenticated, postgres e service_role
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('produtos', 'estoques', 'movimentacoes', 'filiais', 'carga_inicial_controle')
ORDER BY table_name, grantee;

-- 6. Verificação de Conflitos Preexistentes nos SKUs '01' a '09'
SELECT id, codigo, nome, ativo, created_at
FROM public.produtos
WHERE codigo IN ('01','02','03','04','05','06','07','08','09');

-- 7. Verificação de Histórico Parcial Preexistente da Carga
SELECT count(*) AS total_movimentacoes_carga
FROM public.movimentacoes
WHERE motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1';

-- 8. Verificação do Estado Real das 5 Filiais Oficiais
SELECT id, nome, ativa, created_at
FROM public.filiais
WHERE id IN (1, 2, 3, 4, 5)
ORDER BY id;
