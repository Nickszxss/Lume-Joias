-- =====================================================================
-- SCRIPT DE MIGRAÇÃO DEDICADO — RECEBIMENTO DE PEDIDOS DE COMPRA (RPC)
-- Projeto: Lume-Joias (v2.2 REVISADO E HARMONIZADO)
-- Objetivo: Garantir o recebimento atômico de pedidos de compra com idempotência,
--         prevenção de integer overflow, validação de produtos ativos e locks harmonizados.
-- =====================================================================

BEGIN;

-- Drop de assinaturas anteriores para garantir atualização limpa sem ambiguidades de sobrecarga
DROP FUNCTION IF EXISTS public.receber_pedido_rpc(bigint, text);
DROP FUNCTION IF EXISTS public.receber_pedido_rpc(bigint, text, text);

CREATE OR REPLACE FUNCTION public.receber_pedido_rpc(
  p_pedido_id bigint,
  p_observacao text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_pedido record;
  v_item record;
  v_auth_uid uuid;
  v_user_count integer;
  v_user_id bigint;
  v_user_cargo text;
  v_user_filial_id bigint;
  v_items_count integer;
  v_prod_ativo boolean;
  v_prod_qtd_minima integer;
  v_dest_qtd_ant integer;
  v_dest_qtd_nova bigint;
  v_dest_status text;
  v_params_hash text;
  v_idempotent_rec record;
  v_resultado json;
BEGIN
  -- 1. Autenticação e Verificação do Usuário Logado
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

  -- 2. Checagem e Processamento de Idempotência
  IF p_idempotency_key IS NULL OR TRIM(p_idempotency_key) = '' THEN
    RAISE EXCEPTION 'Operacao negada: Chave de idempotencia e obrigatoria para esta operacao.';
  END IF;

  IF LENGTH(p_idempotency_key) > 255 THEN
    RAISE EXCEPTION 'Operacao negada: Chave de idempotencia excede o tamanho maximo permitido (255 caracteres).';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key));
  v_params_hash := md5('receber_pedido:' || COALESCE(p_pedido_id::text, '') || ':' || COALESCE(p_observacao, ''));

  SELECT * INTO v_idempotent_rec
  FROM public.idempotencia_chaves
  WHERE chave = p_idempotency_key;

  IF FOUND THEN
    IF v_idempotent_rec.usuario_id IS DISTINCT FROM v_user_id THEN
      RAISE EXCEPTION 'Acesso negado: A chave de idempotencia % pertence a outro usuario.', p_idempotency_key;
    END IF;
    IF v_idempotent_rec.escopo IS DISTINCT FROM 'receber_pedido' THEN
      RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada em outro escopo (%).', p_idempotency_key, v_idempotent_rec.escopo;
    END IF;
    IF v_idempotent_rec.parametros_hash = v_params_hash THEN
      RETURN v_idempotent_rec.resultado_json;
    ELSE
      RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada com parametros diferentes.', p_idempotency_key;
    END IF;
  END IF;

  -- 3. Bloquear linha do pedido com SELECT FOR UPDATE
  SELECT * INTO v_pedido
  FROM public.pedidos_compra
  WHERE id = p_pedido_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pedido de compra ID % nao encontrado.', p_pedido_id;
  END IF;

  IF v_pedido.status::text = 'recebido' THEN
    RAISE EXCEPTION 'Operacao negada: Pedido ID % ja foi recebido anteriormente em %.', p_pedido_id, v_pedido.recebido_at;
  END IF;

  IF v_pedido.status::text = 'cancelado' THEN
    RAISE EXCEPTION 'Operacao negada: Pedido ID % esta cancelado.', p_pedido_id;
  END IF;

  IF v_pedido.status::text != 'aberto' THEN
    RAISE EXCEPTION 'Operacao negada: Pedido ID % possui status invalido (%) para recebimento.', p_pedido_id, v_pedido.status;
  END IF;

  IF COALESCE(v_user_cargo, '') NOT IN ('gerente', 'funcionario') THEN
    RAISE EXCEPTION 'Acesso negado: Perfil de usuario invalido para esta operacao.';
  END IF;

  IF v_user_cargo != 'gerente' AND (v_user_filial_id IS NULL OR v_user_filial_id != v_pedido.filial_id) THEN
    RAISE EXCEPTION 'Acesso negado: Usuario nao possui permissao para receber pedidos de outra filial (Filial do Pedido: %, Sua Filial: %).', v_pedido.filial_id, v_user_filial_id;
  END IF;

  -- 4. Validar existencia de itens no pedido
  SELECT count(*) INTO v_items_count
  FROM public.itens_pedido_compra
  WHERE pedido_id = p_pedido_id;

  IF v_items_count = 0 THEN
    RAISE EXCEPTION 'Operacao negada: Pedido de compra ID % nao possui itens vinculados.', p_pedido_id;
  END IF;

  -- 5. Processar cada item do pedido em ordem determinística de produto_id para prevenir deadlocks
  FOR v_item IN
    SELECT * FROM public.itens_pedido_compra WHERE pedido_id = p_pedido_id ORDER BY produto_id ASC
  LOOP
    IF v_item.quantidade <= 0 THEN
      RAISE EXCEPTION 'Operacao negada: Item ID % possui quantidade invalida (%).', v_item.id, v_item.quantidade;
    END IF;

    -- Validar existência e estado ativo do produto
    SELECT ativo, qtd_minima INTO v_prod_ativo, v_prod_qtd_minima FROM public.produtos WHERE id = v_item.produto_id LIMIT 1;
    IF v_prod_ativo IS NULL THEN
      RAISE EXCEPTION 'Operacao negada: Produto ID % do pedido nao foi encontrado.', v_item.produto_id;
    END IF;
    IF v_prod_ativo = false THEN
      RAISE EXCEPTION 'Operacao negada: Produto ID % esta inativo e o pedido nao pode ser recebido.', v_item.produto_id;
    END IF;

    -- Advisory Lock transacional harmonizado por par filial/produto
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_pedido.filial_id::text || ':' || v_item.produto_id::text, 0));

    -- Obter e bloquear estoque anterior com SELECT FOR UPDATE
    SELECT COALESCE(
      (SELECT quantidade FROM public.estoques WHERE filial_id = v_pedido.filial_id AND produto_id = v_item.produto_id FOR UPDATE),
      0
    ) INTO v_dest_qtd_ant;

    -- Calcular novo saldo e verificar integer overflow
    v_dest_qtd_nova := v_dest_qtd_ant::bigint + v_item.quantidade::bigint;
    IF v_dest_qtd_nova > 2147483647 THEN
      RAISE EXCEPTION 'Operacao negada: O recebimento do pedido excede a capacidade maxima de estoque permitida (2.147.483.647 unidades).';
    END IF;

    v_dest_status := CASE
      WHEN v_dest_qtd_nova = 0 THEN 'zerado'
      WHEN v_dest_qtd_nova <= COALESCE(v_prod_qtd_minima, 0) THEN 'baixo'
      ELSE 'suficiente'
    END;

    -- Incrementar estoque com status padronizado
    INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
    VALUES (v_pedido.filial_id, v_item.produto_id, v_dest_qtd_nova::integer, v_dest_status::public.status_estoque, now())
    ON CONFLICT (filial_id, produto_id) DO UPDATE
    SET quantidade = EXCLUDED.quantidade,
        status = EXCLUDED.status,
        updated_at = now();

    -- Registrar movimentação auditável na mesma transação
    INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
    VALUES (v_item.produto_id, v_pedido.filial_id, v_user_id, 'entrada', v_item.quantidade, v_dest_qtd_ant, v_dest_qtd_nova::integer, COALESCE(p_observacao, 'Recebimento de Pedido de Compra'), now());
  END LOOP;

  -- 6. Marcar pedido como recebido
  UPDATE public.pedidos_compra
  SET status = 'recebido',
      observacao = COALESCE(p_observacao, observacao),
      recebido_at = now()
  WHERE id = p_pedido_id;

  v_resultado := json_build_object('success', true, 'message', 'Pedido de compra recebido com sucesso.', 'pedido_id', p_pedido_id);

  -- 7. Persistência da Chave de Idempotência
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    INSERT INTO public.idempotencia_chaves (chave, usuario_id, escopo, parametros_hash, resultado_json)
    VALUES (p_idempotency_key, v_user_id, 'receber_pedido', v_params_hash, v_resultado)
    ON CONFLICT (chave) DO NOTHING;
  END IF;

  RETURN v_resultado;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.receber_pedido_rpc(bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.receber_pedido_rpc(bigint, text, text) TO authenticated;

COMMIT;
