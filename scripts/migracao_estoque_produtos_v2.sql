-- =====================================================================
-- SCRIPT DE MIGRAÇÃO DEDICADO E TRANSACIONAL — LUME JOIAS (v2.0)
-- Objeto: Ajuste de Estoque, Categorias Automáticas e Inativação Local por Filial
-- Arquitetura: Supabase PostgreSQL
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. CONSULTAS DE DIAGNÓSTICO / VERIFICAÇÃO PRÉVIA (LEITURA)
-- O DBA pode executar estas consultas separadamente antes de aplicar a migração:
--
-- a) Verificar produtos com descrições/categorias fora do padrão oficial:
--    SELECT id, nome, codigo, descricao FROM public.produtos WHERE descricao IS NULL OR descricao NOT IN ('ANEL', 'PULSEIRA', 'SOLITARIA', 'COLAR', 'BRINCO');
--
-- b) Verificar estoques negativos antes do ajuste:
--    SELECT id, filial_id, produto_id, quantidade FROM public.estoques WHERE quantidade < 0;
--
-- c) Verificar usuários inativos com tentativas de acesso:
--    SELECT id, nome, email, cargo, filial_id FROM public.usuarios WHERE ativo = false;
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 2. TABELA DE INATIVAÇÃO LOCAL DE PRODUTOS POR FILIAL
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.produtos_filiais_inativos (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    produto_id bigint NOT NULL REFERENCES public.produtos(id) ON DELETE CASCADE,
    filial_id bigint NOT NULL REFERENCES public.filiais(id) ON DELETE CASCADE,
    desativado_por bigint REFERENCES public.usuarios(id),
    created_at timestamptz DEFAULT now(),
    CONSTRAINT unique_produto_filial_inativo UNIQUE (produto_id, filial_id)
);

-- Habilitar RLS em produtos_filiais_inativos
ALTER TABLE public.produtos_filiais_inativos ENABLE ROW LEVEL SECURITY;

-- Remover políticas preexistentes na tabela para garantir idempotência
DROP POLICY IF EXISTS "Leitura Inativos Estrita por Filial" ON public.produtos_filiais_inativos;
DROP POLICY IF EXISTS "Leitura Inativos por Perfil Filial" ON public.produtos_filiais_inativos;
DROP POLICY IF EXISTS "Leitura Inativos por Autenticado" ON public.produtos_filiais_inativos;
DROP POLICY IF EXISTS "Insercao Inativos Apenas Gerente Filial" ON public.produtos_filiais_inativos;
DROP POLICY IF EXISTS "Exclusao Inativos Apenas Gerente Filial" ON public.produtos_filiais_inativos;

-- Criar Políticas RLS com isolamento estrito por filial
CREATE POLICY "Leitura Inativos Estrita por Filial" ON public.produtos_filiais_inativos
FOR SELECT USING (
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Insercao Inativos Apenas Gerente Filial" ON public.produtos_filiais_inativos
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente' AND
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Exclusao Inativos Apenas Gerente Filial" ON public.produtos_filiais_inativos
FOR DELETE USING (
  public.get_auth_user_cargo() = 'gerente' AND
  filial_id = public.get_auth_user_filial_id()
);

GRANT SELECT, INSERT, DELETE ON public.produtos_filiais_inativos TO authenticated;

-- ---------------------------------------------------------------------
-- 3. MIGRAÇÃO DML DE CATEGORIAS E APLICAÇÃO DE CHECK CONSTRAINT
-- ---------------------------------------------------------------------
DO $$
DECLARE
    v_invalid_count integer;
BEGIN
    -- Mapeamento DML estrito de produtos oficiais com categoria 'GERAL'/'Geral' ou NULL
    UPDATE public.produtos SET descricao = 'COLAR' WHERE nome IN ('Colar de prata', 'Colar de ouro') AND (descricao IS NULL OR descricao IN ('GERAL', 'Geral', ''));
    UPDATE public.produtos SET descricao = 'ANEL' WHERE nome IN ('Anel de prata', 'Anel de ouro') AND (descricao IS NULL OR descricao IN ('GERAL', 'Geral', ''));
    UPDATE public.produtos SET descricao = 'BRINCO' WHERE nome IN ('Brinco de prata', 'Brinco de ouro') AND (descricao IS NULL OR descricao IN ('GERAL', 'Geral', ''));
    UPDATE public.produtos SET descricao = 'SOLITARIA' WHERE nome IN ('Solitária') AND (descricao IS NULL OR descricao IN ('GERAL', 'Geral', ''));
    UPDATE public.produtos SET descricao = 'PULSEIRA' WHERE nome IN ('Pulseira de prata', 'Pulseira de ouro') AND (descricao IS NULL OR descricao IN ('GERAL', 'Geral', ''));

    -- Verificação preventiva antes de aplicar a constraint CHECK
    SELECT count(*) INTO v_invalid_count
    FROM public.produtos
    WHERE descricao IS NULL OR descricao NOT IN ('ANEL', 'PULSEIRA', 'SOLITARIA', 'COLAR', 'BRINCO');

    IF v_invalid_count > 0 THEN
        RAISE EXCEPTION 'MIGRAÇÃO SUSPENSA: Existem % produtos na tabela public.produtos com categoria invalida ou nao reconhecida. Regularize as categorias antes de aplicar a constraint CHECK.', v_invalid_count;
    ELSE
        ALTER TABLE public.produtos DROP CONSTRAINT IF EXISTS produtos_categoria_check;
        ALTER TABLE public.produtos ADD CONSTRAINT produtos_categoria_check
        CHECK (descricao IN ('ANEL', 'PULSEIRA', 'SOLITARIA', 'COLAR', 'BRINCO'));
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 4. RPC TRANSACIONAL ATÔMICO PARA AJUSTE DE ESTOQUE
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ajustar_estoque_rpc(
  p_produto_id bigint,
  p_filial_id bigint,
  p_tipo text,
  p_quantidade integer,
  p_motivo text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_email text;
  v_user_id bigint;
  v_user_cargo text;
  v_user_filial_id bigint;
  v_filial_ativa boolean;
  v_prod_ativo boolean;
  v_qtd_ant integer;
  v_qtd_nova integer;
  v_lock_key bigint;
BEGIN
  -- 1. Autenticação e Verificação de Usuário Ativo
  v_user_email := (auth.jwt() ->> 'email');
  IF v_user_email IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: Usuario nao autenticado.';
  END IF;

  SELECT id, cargo, filial_id INTO v_user_id, v_user_cargo, v_user_filial_id
  FROM public.usuarios
  WHERE email = v_user_email AND ativo = true
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: Conta invalida ou inativa.';
  END IF;

  -- Regra P0 de Autorização Estrita: Usuários só podem alterar o estoque da PRÓPRIA filial.
  IF v_user_filial_id IS NULL OR v_user_filial_id != p_filial_id THEN
    RAISE EXCEPTION 'Acesso negado: Usuario nao possui permissao para ajustar o estoque de outra filial (Filial Alvo: %, Sua Filial: %).', p_filial_id, v_user_filial_id;
  END IF;

  -- 2. Validação de Filial e Produto Ativos
  SELECT ativa INTO v_filial_ativa FROM public.filiais WHERE id = p_filial_id LIMIT 1;
  IF v_filial_ativa IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: Filial ID % nao encontrada.', p_filial_id;
  END IF;
  IF v_filial_ativa = false THEN
    RAISE EXCEPTION 'Operacao negada: Filial ID % esta inativa.', p_filial_id;
  END IF;

  SELECT ativo INTO v_prod_ativo FROM public.produtos WHERE id = p_produto_id LIMIT 1;
  IF v_prod_ativo IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: Produto ID % nao encontrado.', p_produto_id;
  END IF;

  IF p_quantidade <= 0 THEN
    RAISE EXCEPTION 'Operacao negada: Quantidade de ajuste deve ser um inteiro maior que zero.';
  END IF;

  IF p_tipo NOT IN ('entrada', 'saida') THEN
    RAISE EXCEPTION 'Operacao negada: Tipo de ajuste invalido (%). Use entrada ou saida.', p_tipo;
  END IF;

  -- 3. Proteção contra Concorrência em Registros Inexistentes (P0 Concorrência)
  v_lock_key := pg_catalog.hashtext(p_filial_id::text || '_' || p_produto_id::text);
  PERFORM pg_catalog.pg_advisory_xact_lock(v_lock_key);

  -- 4. Obter e bloquear linha existente do estoque
  SELECT quantidade INTO v_qtd_ant
  FROM public.estoques
  WHERE filial_id = p_filial_id AND produto_id = p_produto_id
  FOR UPDATE;

  IF v_qtd_ant IS NULL THEN
    v_qtd_ant := 0;
  END IF;

  IF p_tipo = 'saida' THEN
    IF v_qtd_ant < p_quantidade THEN
      RAISE EXCEPTION 'Saldo insuficiente na filial para realizar a saida (disponivel: %, solicitado: %).', v_qtd_ant, p_quantidade;
    END IF;
    v_qtd_nova := v_qtd_ant - p_quantidade;
  ELSE
    v_qtd_nova := v_qtd_ant + p_quantidade;
  END IF;

  -- 5. Atualizar ou inserir estoque de forma atômica
  INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
  VALUES (p_filial_id, p_produto_id, v_qtd_nova, CASE WHEN v_qtd_nova = 0 THEN 'zerado' ELSE 'suficiente' END, now())
  ON CONFLICT (filial_id, produto_id) DO UPDATE
  SET quantidade = EXCLUDED.quantidade,
      status = EXCLUDED.status,
      updated_at = now();

  -- 6. Registrar movimentação auditável na mesma transação
  INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
  VALUES (p_produto_id, p_filial_id, v_user_id, p_tipo, p_quantidade, v_qtd_ant, v_qtd_nova, COALESCE(p_motivo, 'Ajuste manual de estoque'), now());

  RETURN json_build_object(
    'success', true,
    'message', 'Estoque ajustado com sucesso.',
    'quantidade_anterior', v_qtd_ant,
    'quantidade_nova', v_qtd_nova
  );
END;
$$;

-- Restringir privilégios da RPC exclusivamente para authenticated
REVOKE EXECUTE ON FUNCTION public.ajustar_estoque_rpc(bigint, bigint, text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajustar_estoque_rpc(bigint, bigint, text, integer, text) TO authenticated;

COMMIT;
