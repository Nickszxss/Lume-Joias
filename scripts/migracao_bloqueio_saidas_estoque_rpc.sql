-- =====================================================================
-- SCRIPT DE MIGRAÇÃO DEDICADO — LUME JOIAS (v2.4 OFICIAL E AJUSTADO)
-- Objeto: Proteção Estrita contra Saídas Acima do Saldo Disponível em Estoque,
--         Harmonização de Locks de Concorrência, Suporte a Idempotência e Fechamento Rigoroso de Permissões Direct Update.
-- Arquitetura: Supabase PostgreSQL (Ajuste Manual de Estoque)
-- =====================================================================

BEGIN;

-- 1. Restrição de Integridade Não-Negativa em public.estoques
-- Elimina preventivamente ambas as variações de nomes de constraint conhecidas para evitar duplicação.
DO $$
DECLARE
    v_negatives_count integer;
BEGIN
    SELECT count(*) INTO v_negatives_count FROM public.estoques WHERE quantidade < 0;
    IF v_negatives_count > 0 THEN
        RAISE EXCEPTION 'ERRO DE SEGURANÇA: Existem % registros com quantidade negativa na tabela public.estoques. A constraint CHECK (quantidade >= 0) nao pode ser aplicada. Regularize os saldos antes de reexecutar o script.', v_negatives_count;
    ELSE
        ALTER TABLE public.estoques DROP CONSTRAINT IF EXISTS quantidade_nao_negativa;
        ALTER TABLE public.estoques DROP CONSTRAINT IF EXISTS estoques_quantidade_nonnegative;
        ALTER TABLE public.estoques ADD CONSTRAINT estoques_quantidade_nonnegative CHECK (quantidade >= 0);
    END IF;
END $$;

-- 2. Fechamento de UPDATE direto e amplo sobre public.estoques
REVOKE UPDATE ON public.estoques FROM PUBLIC, anon, authenticated;
REVOKE UPDATE (id, filial_id, produto_id, quantidade, status, updated_at) ON public.estoques FROM PUBLIC, anon, authenticated;

-- 3. RPC Transacional Atômico para Ajuste de Estoque com Suporte Completo a Idempotência e Locks Harmonizados
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

  -- Regra P0 de Autorização Estrita por Filial
  IF v_user_filial_id IS NULL OR v_user_filial_id != p_filial_id THEN
    RAISE EXCEPTION 'Acesso negado: Usuario nao possui permissao para ajustar o estoque de outra filial (Filial Alvo: %, Sua Filial: %).', p_filial_id, v_user_filial_id;
  END IF;

  -- 2. Checagem e Processamento de Idempotência
  IF p_idempotency_key IS NULL OR TRIM(p_idempotency_key) = '' THEN
    RAISE EXCEPTION 'Operacao negada: Chave de idempotencia e obrigatoria para esta operacao.';
  END IF;

  IF LENGTH(p_idempotency_key) > 255 THEN
    RAISE EXCEPTION 'Operacao negada: Chave de idempotencia excede o tamanho maximo permitido (255 caracteres).';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key));
  v_params_hash := md5('ajustar_estoque:' || COALESCE(p_produto_id::text, '') || ':' || COALESCE(p_filial_id::text, '') || ':' || COALESCE(p_tipo, '') || ':' || COALESCE(p_quantidade::text, '') || ':' || COALESCE(p_motivo, ''));

  SELECT * INTO v_idempotent_rec
  FROM public.idempotencia_chaves
  WHERE chave = p_idempotency_key;

  IF FOUND THEN
    IF v_idempotent_rec.usuario_id IS DISTINCT FROM v_user_id THEN
      RAISE EXCEPTION 'Acesso negado: A chave de idempotencia % pertence a outro usuario.', p_idempotency_key;
    END IF;
    IF v_idempotent_rec.escopo IS DISTINCT FROM 'ajustar_estoque' THEN
      RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada em outro escopo (%).', p_idempotency_key, v_idempotent_rec.escopo;
    END IF;
    IF v_idempotent_rec.parametros_hash = v_params_hash THEN
      RETURN v_idempotent_rec.resultado_json;
    ELSE
      RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada com parametros diferentes.', p_idempotency_key;
    END IF;
  END IF;

  -- 3. Validação Estrita de Parâmetros de Entrada
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

  -- 4. Validação de Filial e Produto Ativos
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

  -- 5. Trava Determinística e Padronizada de Concorrência
  -- Utiliza a convenção exata da base de dados: hashtextextended(filial_id::text || ':' || produto_id::text, 0)
  -- Garante sincronização perfeita e serialização entre ajustes manuais, conclusões de transferência e recebimentos de pedidos.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_filial_id::text || ':' || p_produto_id::text, 0));

  SELECT quantidade INTO v_qtd_ant
  FROM public.estoques
  WHERE filial_id = p_filial_id AND produto_id = p_produto_id
  FOR UPDATE;

  IF v_qtd_ant IS NULL THEN
    v_qtd_ant := 0;
  END IF;

  -- 6. Validação do Saldo para Operações de Saída
  IF p_tipo = 'saida' THEN
    IF v_qtd_ant < p_quantidade THEN
      RAISE EXCEPTION 'Saldo insuficiente na filial para realizar a saida (disponivel: %, solicitado: %).', v_qtd_ant, p_quantidade;
    END IF;
    v_qtd_nova := v_qtd_ant - p_quantidade;
  ELSE
    v_qtd_nova := v_qtd_ant + p_quantidade;
  END IF;

  -- Calcular status do estoque com base na quantidade mínima
  v_status := CASE
    WHEN v_qtd_nova = 0 THEN 'zerado'
    WHEN v_qtd_nova <= COALESCE(v_qtd_minima, 0) THEN 'baixo'
    ELSE 'suficiente'
  END;

  -- 7. Atualização Atômica do Saldo
  INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
  VALUES (p_filial_id, p_produto_id, v_qtd_nova, v_status::public.status_estoque, now())
  ON CONFLICT (filial_id, produto_id) DO UPDATE
  SET quantidade = EXCLUDED.quantidade,
      status = EXCLUDED.status,
      updated_at = now();

  -- 8. Registro de Movimentação Auditável na Mesma Transação
  INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
  VALUES (p_produto_id, p_filial_id, v_user_id, p_tipo, p_quantidade, v_qtd_ant, v_qtd_nova, COALESCE(p_motivo, 'Ajuste manual de estoque'), now());

  v_resultado := json_build_object(
    'success', true,
    'message', 'Estoque ajustado com sucesso.',
    'quantidade_anterior', v_qtd_ant,
    'quantidade_nova', v_qtd_nova
  );

  -- 9. Persistência da Chave de Idempotência
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    INSERT INTO public.idempotencia_chaves (chave, usuario_id, escopo, parametros_hash, resultado_json)
    VALUES (p_idempotency_key, v_user_id, 'ajustar_estoque', v_params_hash, v_resultado)
    ON CONFLICT (chave) DO NOTHING;
  END IF;

  RETURN v_resultado;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.ajustar_estoque_rpc(bigint, bigint, text, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajustar_estoque_rpc(bigint, bigint, text, integer, text, text) TO authenticated;

COMMIT;
