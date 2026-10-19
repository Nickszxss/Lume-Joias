-- =====================================================================
-- SCRIPT DE MIGRAÇÃO DEDICADO — LUME JOIAS
-- Objeto: Proteção Estrita contra Saídas Acima do Saldo Disponível em Estoque
-- Arquitetura: Supabase PostgreSQL (Ajuste Manual e Transferências)
-- =====================================================================

BEGIN;

-- 1. Restrição de Integridade Não-Negativa em public.estoques
DO $$
DECLARE
    v_negatives_count integer;
BEGIN
    SELECT count(*) INTO v_negatives_count FROM public.estoques WHERE quantidade < 0;
    IF v_negatives_count > 0 THEN
        RAISE EXCEPTION 'ERRO DE SEGURANÇA: Existem % registros com quantidade negativa na tabela public.estoques. A constraint CHECK (quantidade >= 0) nao pode ser aplicada. Regularize os saldos antes de reexecutar o script.', v_negatives_count;
    ELSE
        ALTER TABLE public.estoques DROP CONSTRAINT IF EXISTS estoques_quantidade_nonnegative;
        ALTER TABLE public.estoques ADD CONSTRAINT estoques_quantidade_nonnegative CHECK (quantidade >= 0);
    END IF;
END $$;

-- 2. Fechamento de UPDATE direto sobre public.estoques
REVOKE UPDATE (id, filial_id, produto_id, quantidade, status, updated_at) ON public.estoques FROM PUBLIC, anon, authenticated;

-- 3. RPC Transacional Atômico para Ajuste de Estoque com Proteção de Saldo
CREATE OR REPLACE FUNCTION public.ajustar_estoque_rpc(
  p_produto_id bigint,
  p_filial_id bigint,
  p_tipo text,
  p_quantidade integer,
  p_motivo text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_auth_uid uuid;
  v_user_count integer;
  v_user_id bigint;
  v_user_cargo text;
  v_user_filial_id bigint;
  v_filial_ativa boolean;
  v_prod_ativo boolean;
  v_qtd_minima integer;
  v_qtd_ant integer;
  v_qtd_nova integer;
  v_status text;
  v_lock_key bigint;
  v_params_hash text;
  v_idempotent_rec record;
  v_resultado json;
BEGIN
  -- 1. Autenticação e Verificação Estrita do Usuário
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: Usuario nao autenticado.';
  END IF;

  SELECT count(*) INTO v_user_count
  FROM public.usuarios
  WHERE auth_user_id = v_auth_uid AND ativo = true;

  IF v_user_count = 0 THEN
    RAISE EXCEPTION 'Acesso negado: Conta invalida, inativa ou sem vinculo Auth.';
  ELSIF v_user_count > 1 THEN
    RAISE EXCEPTION 'Acesso negado: Identidade ambígua detectada no sistema.';
  END IF;

  SELECT id, LOWER(tipo::text), filial_id INTO v_user_id, v_user_cargo, v_user_filial_id
  FROM public.usuarios
  WHERE auth_user_id = v_auth_uid AND ativo = true;

  -- Permissão por Filial
  IF v_user_filial_id IS NULL OR v_user_filial_id != p_filial_id THEN
    RAISE EXCEPTION 'Acesso negado: Usuario nao possui permissao para ajustar o estoque de outra filial (Filial Alvo: %, Sua Filial: %).', p_filial_id, v_user_filial_id;
  END IF;

  -- 2. Validação Estrita de Parâmetros de Entrada
  IF p_produto_id IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: ID do produto e obrigatorio.';
  END IF;
  IF p_filial_id IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: ID da filial e obrigatorio.';
  END IF;
  IF p_tipo IS NULL OR p_tipo NOT IN ('entrada', 'saida') THEN
    RAISE EXCEPTION 'Operacao negada: Tipo de ajuste invalido (%). Use entrada ou saida.', p_tipo;
  END IF;
  IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
    RAISE EXCEPTION 'Operacao negada: Quantidade de ajuste deve ser um inteiro maior que zero.';
  END IF;
  IF p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
    RAISE EXCEPTION 'Operacao negada: Motivo do ajuste de estoque e obrigatorio.';
  END IF;

  -- 3. Validação de Filial e Produto Ativos
  SELECT ativa INTO v_filial_ativa FROM public.filiais WHERE id = p_filial_id LIMIT 1;
  IF v_filial_ativa IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: Filial ID % nao encontrada.', p_filial_id;
  END IF;
  IF v_filial_ativa = false THEN
    RAISE EXCEPTION 'Operacao negada: Filial ID % esta inativa.', p_filial_id;
  END IF;

  SELECT ativo, qtd_minima INTO v_prod_ativo, v_qtd_minima FROM public.produtos WHERE id = p_produto_id LIMIT 1;
  IF v_prod_ativo IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: Produto ID % nao encontrado.', p_produto_id;
  END IF;
  IF v_prod_ativo = false THEN
    RAISE EXCEPTION 'Operacao negada: Produto ID % esta inativo e nao pode receber ajustes de estoque.', p_produto_id;
  END IF;

  -- 4. Trava Contra Concorrência (Advisory Lock + SELECT FOR UPDATE)
  v_lock_key := pg_catalog.hashtext(p_filial_id::text || '_' || p_produto_id::text);
  PERFORM pg_catalog.pg_advisory_xact_lock(v_lock_key);

  SELECT quantidade INTO v_qtd_ant
  FROM public.estoques
  WHERE filial_id = p_filial_id AND produto_id = p_produto_id
  FOR UPDATE;

  IF v_qtd_ant IS NULL THEN
    v_qtd_ant := 0;
  END IF;

  -- 5. Validação do Saldo para Operações de Saída
  IF p_tipo = 'saida' THEN
    IF v_qtd_ant < p_quantidade THEN
      RAISE EXCEPTION 'Saldo insuficiente na filial para realizar a saida (disponivel: %, solicitado: %).', v_qtd_ant, p_quantidade;
    END IF;
    v_qtd_nova := v_qtd_ant - p_quantidade;
  ELSE
    v_qtd_nova := v_qtd_ant + p_quantidade;
  END IF;

  -- Calcular status do estoque
  v_status := CASE
    WHEN v_qtd_nova = 0 THEN 'zerado'
    WHEN v_qtd_nova <= COALESCE(v_qtd_minima, 0) THEN 'baixo'
    ELSE 'suficiente'
  END;

  -- 6. Atualização Atômica do Saldo
  INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
  VALUES (p_filial_id, p_produto_id, v_qtd_nova, v_status::public.status_estoque, now())
  ON CONFLICT (filial_id, produto_id) DO UPDATE
  SET quantidade = EXCLUDED.quantidade,
      status = EXCLUDED.status,
      updated_at = now();

  -- 7. Registro de Movimentação Auditável
  INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
  VALUES (p_produto_id, p_filial_id, v_user_id, p_tipo, p_quantidade, v_qtd_ant, v_qtd_nova, COALESCE(p_motivo, 'Ajuste manual de estoque'), now());

  v_resultado := json_build_object(
    'success', true,
    'message', 'Estoque ajustado com sucesso.',
    'quantidade_anterior', v_qtd_ant,
    'quantidade_nova', v_qtd_nova
  );

  RETURN v_resultado;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.ajustar_estoque_rpc(bigint, bigint, text, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajustar_estoque_rpc(bigint, bigint, text, integer, text, text) TO authenticated;

COMMIT;
