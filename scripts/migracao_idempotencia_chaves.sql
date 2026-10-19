-- =====================================================================
-- MIGRAÇÃO IDEMPOTENTE E SEGURA — TABELA public.idempotencia_chaves
-- Projeto: Lume-Joias
-- Objetivo: Garantir a estrutura, restrições e permissões para armazenamento de chaves de idempotência sem alteração de dados remotos no Supabase Cloud.
-- =====================================================================

BEGIN;

-- 1. Criação condicional da tabela com estrutura padrão completa
CREATE TABLE IF NOT EXISTS public.idempotencia_chaves (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    chave text NOT NULL,
    usuario_id bigint NOT NULL REFERENCES public.usuarios(id),
    escopo text NOT NULL,
    parametros_hash text NOT NULL,
    resultado_json json NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- 2. Garantir colunas essenciais para tabelas preexistentes (sem defaults artificiais para dados legados)
ALTER TABLE public.idempotencia_chaves ADD COLUMN IF NOT EXISTS usuario_id bigint REFERENCES public.usuarios(id);
ALTER TABLE public.idempotencia_chaves ADD COLUMN IF NOT EXISTS escopo text;
ALTER TABLE public.idempotencia_chaves ADD COLUMN IF NOT EXISTS parametros_hash text;
ALTER TABLE public.idempotencia_chaves ADD COLUMN IF NOT EXISTS resultado_json json;
ALTER TABLE public.idempotencia_chaves ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- 3. Detecção estrita de registros legados inválidos/nulos (ABORTA a migração para análise manual se houver dados incompletos)
DO $$
DECLARE
    v_invalid_legacy_count integer;
BEGIN
    SELECT count(*) INTO v_invalid_legacy_count
    FROM public.idempotencia_chaves
    WHERE chave IS NULL OR TRIM(chave) = ''
       OR usuario_id IS NULL
       OR escopo IS NULL OR TRIM(escopo) = ''
       OR parametros_hash IS NULL OR TRIM(parametros_hash) = ''
       OR resultado_json IS NULL;

    IF v_invalid_legacy_count > 0 THEN
        RAISE EXCEPTION 'Migração interrompida: A tabela public.idempotencia_chaves possui % registros legados incompletos ou com colunas obrigatórias NULAS (chave, usuario_id, escopo, parametros_hash, resultado_json). Efetue o saneamento manual antes de prosseguir.', v_invalid_legacy_count;
    END IF;
END $$;

-- Enforçar NOT NULL nas colunas críticas após confirmar ausência de nulos legados
ALTER TABLE public.idempotencia_chaves ALTER COLUMN chave SET NOT NULL;
ALTER TABLE public.idempotencia_chaves ALTER COLUMN usuario_id SET NOT NULL;
ALTER TABLE public.idempotencia_chaves ALTER COLUMN escopo SET NOT NULL;
ALTER TABLE public.idempotencia_chaves ALTER COLUMN parametros_hash SET NOT NULL;
ALTER TABLE public.idempotencia_chaves ALTER COLUMN resultado_json SET NOT NULL;

-- 4. Detecção estrita de chaves duplicadas (ABORTA a migração em caso de duplicatas)
DO $$
DECLARE
    v_duplicados_count integer;
BEGIN
    SELECT count(*) INTO v_duplicados_count
    FROM (
        SELECT chave FROM public.idempotencia_chaves GROUP BY chave HAVING count(*) > 1
    ) dup;

    IF v_duplicados_count > 0 THEN
        RAISE EXCEPTION 'Migração interrompida: Existem % chaves de idempotência duplicadas na tabela public.idempotencia_chaves. Resolva os conflitos de duplicação manualmente antes de aplicar a restrição UNIQUE.', v_duplicados_count;
    END IF;
END $$;

-- 5. Adicionar restrição UNIQUE global na coluna chave se não existir (valida tipo 'u', coluna chave única, não parcial e índice pronto)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
        WHERE n.nspname = 'public'
          AND t.relname = 'idempotencia_chaves'
          AND a.attname = 'chave'
          AND c.contype = 'u'
          AND cardinality(c.conkey) = 1
    ) AND NOT EXISTS (
        SELECT 1
        FROM pg_index i
        JOIN pg_class t ON i.indrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = i.indkey[0]
        WHERE n.nspname = 'public'
          AND t.relname = 'idempotencia_chaves'
          AND a.attname = 'chave'
          AND i.indisunique = true
          AND i.indisvalid = true
          AND i.indisready = true
          AND i.indpred IS NULL
          AND i.indnkeyatts = 1
    ) THEN
        ALTER TABLE public.idempotencia_chaves ADD CONSTRAINT idempotencia_chaves_chave_key UNIQUE (chave);
    END IF;
END $$;

-- 6. Configurações estritas de RLS e Revogação de Acesso Direto para Clientes
ALTER TABLE public.idempotencia_chaves ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.idempotencia_chaves FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.idempotencia_chaves TO service_role;

COMMIT;
