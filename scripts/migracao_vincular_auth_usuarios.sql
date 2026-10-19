-- =====================================================================
-- SCRIPT DE MIGRAÇÃO: VÍNCULO SUPABASE AUTH ↔ PUBLIC.USUARIOS (LUME JOIAS)
-- Arquitetura: Supabase PostgreSQL (auth.users <-> public.usuarios)
-- Finalidade: Estabelecer chave estrangeira e vinculo idempotente por auth_user_id UUID
-- =====================================================================

BEGIN;

-- 1. Alteração do esquema de forma idempotente e segura
ALTER TABLE public.usuarios
ADD COLUMN IF NOT EXISTS auth_user_id UUID;

-- Adicionar constraint de Foreign Key se ainda não existir
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_usuarios_auth_user' AND conrelid = 'public.usuarios'::regclass
    ) THEN
        ALTER TABLE public.usuarios
        ADD CONSTRAINT fk_usuarios_auth_user
        FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Adicionar constraint de Unicidade se ainda não existir
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_usuarios_auth_user_id' AND conrelid = 'public.usuarios'::regclass
    ) THEN
        ALTER TABLE public.usuarios
        ADD CONSTRAINT uq_usuarios_auth_user_id
        UNIQUE (auth_user_id);
    END IF;
END $$;

-- 2. Validações prévias rígidas e associação inicial por e-mail
DO $$
DECLARE
    v_total_usuarios integer;
    v_unlinked_count integer;
    v_missing_auth integer;
    v_ambiguous_auth integer;
    v_duplicate_link integer;
BEGIN
    SELECT count(*) INTO v_total_usuarios FROM public.usuarios;

    -- Verificar se já foi executado e todos os usuários já possuem auth_user_id
    SELECT count(*) INTO v_unlinked_count
    FROM public.usuarios
    WHERE auth_user_id IS NULL;

    IF v_unlinked_count = 0 THEN
        RAISE NOTICE 'Migração já executada previamente com sucesso: todos os % usuários possuem auth_user_id preenchido.', v_total_usuarios;
        RETURN;
    END IF;

    -- Validar se existe algum usuário interno sem exatamente 1 conta correspondente em auth.users (por e-mail exato)
    SELECT count(*) INTO v_missing_auth
    FROM public.usuarios u
    WHERE u.auth_user_id IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM auth.users a
          WHERE LOWER(a.email) = LOWER(u.email)
      );

    IF v_missing_auth > 0 THEN
        RAISE EXCEPTION 'MIGRAÇÃO ABORTADA: Existem % registros em public.usuarios sem conta correspondente em auth.users.', v_missing_auth;
    END IF;

    -- Validar se existe ambiguidade (mais de 1 conta auth.users para o mesmo e-mail de um usuário interno)
    SELECT count(*) INTO v_ambiguous_auth
    FROM (
        SELECT u.id
        FROM public.usuarios u
        JOIN auth.users a ON LOWER(a.email) = LOWER(u.email)
        WHERE u.auth_user_id IS NULL
        GROUP BY u.id
        HAVING count(a.id) > 1
    ) amb;

    IF v_ambiguous_auth > 0 THEN
        RAISE EXCEPTION 'MIGRAÇÃO ABORTADA: Existem % usuários internos com múltiplas contas correspondentes em auth.users.', v_ambiguous_auth;
    END IF;

    -- Validar se alguma conta auth.users corresponderia a mais de 1 usuário interno
    SELECT count(*) INTO v_duplicate_link
    FROM (
        SELECT a.id
        FROM auth.users a
        JOIN public.usuarios u ON LOWER(u.email) = LOWER(a.email)
        GROUP BY a.id
        HAVING count(u.id) > 1
    ) dup;

    IF v_duplicate_link > 0 THEN
        RAISE EXCEPTION 'MIGRAÇÃO ABORTADA: Existem % contas de auth.users associadas a mais de um registro interno em public.usuarios.', v_duplicate_link;
    END IF;

    -- 3. Executar o vínculo para os registros pendentes (preservando inativos e IDs internos)
    UPDATE public.usuarios u
    SET auth_user_id = a.id
    FROM auth.users a
    WHERE u.auth_user_id IS NULL
      AND LOWER(u.email) = LOWER(a.email);

    -- 4. Verificação final de integridade pós-update
    SELECT count(*) INTO v_unlinked_count
    FROM public.usuarios
    WHERE auth_user_id IS NULL;

    IF v_unlinked_count > 0 THEN
        RAISE EXCEPTION 'MIGRAÇÃO ABORTADA: % usuários internos permanecem sem vinculo de auth_user_id após a execução.', v_unlinked_count;
    END IF;

    RAISE NOTICE 'Migração concluída com sucesso: todos os % usuários foram vinculados às suas contas auth.users.', v_total_usuarios;
END $$;

COMMIT;
