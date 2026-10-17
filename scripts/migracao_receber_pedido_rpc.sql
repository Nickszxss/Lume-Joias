-- =====================================================================
-- MIGRAÇÃO MÍNIMA INDEPENDENTE — CRIAÇÃO E CONFIGURAÇÃO DA RPC `receber_pedido_rpc`
-- Projeto: Lume-Joias
-- Descrição: Cria a função RPC para recebimento transacional de pedidos de compra e configura suas permissões de execução.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.receber_pedido_rpc(
  p_pedido_id bigint,
  p_observacao text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_pedido record;
  v_item record;
  v_user_email text;
  v_user_id bigint;
  v_user_cargo text;
  v_user_filial_id bigint;
  v_items_count integer;
  v_dest_qtd_ant integer;
  v_dest_qtd_nova integer;
BEGIN
  -- 1. Validar autenticação do usuário via JWT
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

  -- 2. Bloquear linha do pedido com SELECT FOR UPDATE para evitar processamento duplo
  SELECT * INTO v_pedido
  FROM public.pedidos_compra
  WHERE id = p_pedido_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pedido de compra ID % nao encontrado.', p_pedido_id;
  END IF;

  IF v_pedido.status = 'recebido' THEN
    RAISE EXCEPTION 'Operacao negada: Pedido ID % ja foi recebido anteriormente em %.', p_pedido_id, v_pedido.recebido_at;
  END IF;

  IF v_pedido.status != 'aberto' THEN
    RAISE EXCEPTION 'Operacao negada: Pedido ID % possui status invalido (%) para recebimento.', p_pedido_id, v_pedido.status;
  END IF;

  IF v_user_cargo != 'gerente' AND v_user_filial_id != v_pedido.filial_id THEN
    RAISE EXCEPTION 'Acesso negado: Usuario nao pertence a filial responsável pelo pedido.';
  END IF;

  -- 3. Validar existência de itens vinculados ao pedido
  SELECT count(*) INTO v_items_count
  FROM public.itens_pedido_compra
  WHERE pedido_id = p_pedido_id;

  IF v_items_count = 0 THEN
    RAISE EXCEPTION 'Operacao negada: Pedido de compra ID % nao possui itens vinculados.', p_pedido_id;
  END IF;

  -- 4. Processar cada item do pedido atomicamente
  FOR v_item IN
    SELECT * FROM public.itens_pedido_compra WHERE pedido_id = p_pedido_id
  LOOP
    IF v_item.quantidade <= 0 THEN
      RAISE EXCEPTION 'Operacao negada: Item ID % possui quantidade invalida (%).', v_item.id, v_item.quantidade;
    END IF;

    -- Obter e bloquear estoque anterior
    SELECT COALESCE(
      (SELECT quantidade FROM public.estoques WHERE filial_id = v_pedido.filial_id AND produto_id = v_item.produto_id FOR UPDATE),
      0
    ) INTO v_dest_qtd_ant;

    v_dest_qtd_nova := v_dest_qtd_ant + v_item.quantidade;

    -- Incrementar estoque
    INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
    VALUES (v_pedido.filial_id, v_item.produto_id, v_item.quantidade, 'Disponivel', now())
    ON CONFLICT (filial_id, produto_id) DO UPDATE
    SET quantidade = public.estoques.quantidade + EXCLUDED.quantidade,
        updated_at = now();

    -- Registrar movimentação auditável com saldos anteriores e posteriores REAIS
    INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
    VALUES (v_item.produto_id, v_pedido.filial_id, v_user_id, 'entrada', v_item.quantidade, v_dest_qtd_ant, v_dest_qtd_nova, COALESCE(p_observacao, 'Recebimento de Pedido de Compra'), now());
  END LOOP;

  -- 5. Marcar pedido como recebido
  UPDATE public.pedidos_compra
  SET status = 'recebido',
      observacao = COALESCE(p_observacao, observacao),
      recebido_at = now()
  WHERE id = p_pedido_id;

  RETURN json_build_object('success', true, 'message', 'Pedido de compra recebido com sucesso.', 'pedido_id', p_pedido_id);
END;
$$;

-- Configuração rigorosa de permissões de execução
REVOKE EXECUTE ON FUNCTION public.receber_pedido_rpc(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.receber_pedido_rpc(bigint, text) TO authenticated;
