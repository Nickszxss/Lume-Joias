-- =====================================================================
-- MIGRAÇÃO DEDICADA — RPCs FUNCIONAIS DE ESTOQUE (LUME-JOIAS)
-- Objetivo: Instalar as RPCs essenciais ausentes no banco remoto (ajustar_estoque_rpc,
--           cadastrar_produto_com_estoques_rpc, criar_pedido_compra_rpc) de forma
--           atômica e transacional, com suporte a idempotência e concorrência.
-- AVISO: Não altera políticas RLS nem recria funções já existentes no Supabase (como receber_pedido_rpc e concluir_transferencia_rpc).
-- Local de execução: Supabase Dashboard -> SQL Editor.
-- =====================================================================

BEGIN;

-- 1. RPC Transacional Atômico para Ajuste de Estoque com Suporte a Idempotência e Bloqueio de Saídas Acima do Saldo
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
  v_qtd_ant integer;
  v_qtd_nova integer;
  v_status text;
  v_lock_key bigint;
  v_params_hash text;
  v_idempotent_rec record;
  v_resultado json;
BEGIN
  -- 1. Autenticação e Verificação Estrita do Usuário por auth.uid()
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

  -- 2. Checagem de Idempotência
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

  SELECT ativo INTO v_prod_ativo FROM public.produtos WHERE id = p_produto_id LIMIT 1;
  IF v_prod_ativo IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: Produto ID % nao encontrado.', p_produto_id;
  END IF;
  IF v_prod_ativo = false THEN
    RAISE EXCEPTION 'Operacao negada: Produto ID % esta inativo e nao pode receber ajustes de estoque.', p_produto_id;
  END IF;

  -- 5. Trava Determinística de Concorrência
  v_lock_key := pg_catalog.hashtextextended(p_filial_id::text || ':' || p_produto_id::text, 0);
  PERFORM pg_catalog.pg_advisory_xact_lock(v_lock_key);

  SELECT quantidade INTO v_qtd_ant
  FROM public.estoques
  WHERE filial_id = p_filial_id AND produto_id = p_produto_id
  FOR UPDATE;

  IF v_qtd_ant IS NULL THEN
    v_qtd_ant := 0;
  END IF;

  -- 6. Validação do Saldo e Proteção contra Integer Overflow
  IF p_tipo = 'saida' THEN
    IF v_qtd_ant < p_quantidade THEN
      RAISE EXCEPTION 'Saldo insuficiente na filial para realizar a saida (disponivel: %, solicitado: %).', v_qtd_ant, p_quantidade;
    END IF;
    v_qtd_nova := v_qtd_ant - p_quantidade;
  ELSE
    IF p_quantidade > 2147483647 - v_qtd_ant THEN
      RAISE EXCEPTION 'Operacao negada: O incremento ultrapassaria o limite maximo de INTEGER (2147483647).';
    END IF;
    v_qtd_nova := v_qtd_ant + p_quantidade;
  END IF;

  -- Status fixo por faixa
  v_status := CASE
    WHEN v_qtd_nova = 0 THEN 'zerado'
    WHEN v_qtd_nova < 20 THEN 'baixo'
    WHEN v_qtd_nova <= 50 THEN 'suficiente'
    ELSE 'suficiente+'
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


-- 2. RPC Transacional Atômico para Cadastrar Produto e Criar Estoque Inicial em 5 Filiais
CREATE OR REPLACE FUNCTION public.cadastrar_produto_com_estoques_rpc(
  p_nome text,
  p_sku text,
  p_categoria text DEFAULT 'Geral',
  p_qtd_minima integer DEFAULT 10,
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
  v_prod_id bigint;
  v_filial_rec record;
  v_filial_count integer;
  v_params_hash text;
  v_idempotent_rec record;
  v_resultado json;
BEGIN
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

  IF v_user_cargo != 'gerente' THEN
    RAISE EXCEPTION 'Acesso negado: Apenas gerentes possuem permissao para cadastrar produtos.';
  END IF;

  IF p_nome IS NULL OR TRIM(p_nome) = '' THEN
    RAISE EXCEPTION 'Operacao negada: Nome do produto e obrigatorio.';
  END IF;
  IF p_sku IS NULL OR TRIM(p_sku) = '' THEN
    RAISE EXCEPTION 'Operacao negada: SKU/Codigo do produto e obrigatorio.';
  END IF;

  -- Checagem de Idempotência
  IF p_idempotency_key IS NULL OR TRIM(p_idempotency_key) = '' THEN
    RAISE EXCEPTION 'Operacao negada: Chave de idempotencia e obrigatoria para esta operacao.';
  END IF;

  IF LENGTH(p_idempotency_key) > 255 THEN
    RAISE EXCEPTION 'Operacao negada: Chave de idempotencia excede o tamanho maximo permitido (255 caracteres).';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key));
  v_params_hash := md5('cadastrar_produto:' || TRIM(p_nome) || ':' || TRIM(p_sku));

  SELECT * INTO v_idempotent_rec
  FROM public.idempotencia_chaves
  WHERE chave = p_idempotency_key;

  IF FOUND THEN
    IF v_idempotent_rec.usuario_id IS DISTINCT FROM v_user_id THEN
      RAISE EXCEPTION 'Acesso negado: A chave de idempotencia % pertence a outro usuario.', p_idempotency_key;
    END IF;
    IF v_idempotent_rec.escopo IS DISTINCT FROM 'cadastrar_produto' THEN
      RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada em outro escopo (%).', p_idempotency_key, v_idempotent_rec.escopo;
    END IF;
    IF v_idempotent_rec.parametros_hash = v_params_hash THEN
      RETURN v_idempotent_rec.resultado_json;
    ELSE
      RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada com parametros diferentes.', p_idempotency_key;
    END IF;
  END IF;

  -- Verificar se as cinco filiais oficiais existem e estão ativas.
  SELECT count(*) INTO v_filial_count
  FROM public.filiais
  WHERE id IN (1, 2, 3, 4, 5) AND ativa IS TRUE;

  IF v_filial_count <> 5 THEN
    RAISE EXCEPTION 'Operacao negada: Todas as cinco filiais oficiais (IDs 1 a 5) precisam existir e estar ativas.';
  END IF;

  -- Derivar e validar categoria oficial do produto a partir do nome
  DECLARE
    v_nome_lower text := LOWER(TRIM(p_nome));
    v_cat_derivada text;
  BEGIN
    IF v_nome_lower LIKE '%anel%' THEN v_cat_derivada := 'ANEL';
    ELSIF v_nome_lower LIKE '%pulseira%' THEN v_cat_derivada := 'PULSEIRA';
    ELSIF v_nome_lower LIKE '%solitária%' OR v_nome_lower LIKE '%solitaria%' THEN v_cat_derivada := 'SOLITARIA';
    ELSIF v_nome_lower LIKE '%colar%' THEN v_cat_derivada := 'COLAR';
    ELSIF v_nome_lower LIKE '%brinco%' THEN v_cat_derivada := 'BRINCO';
    ELSE
      RAISE EXCEPTION 'Operacao negada: Nome do produto nao corresponde a uma categoria permitida (Anel, Pulseira, Solitaria, Colar, Brinco).';
    END IF;

    -- Inserir o novo produto no catálogo global com a categoria derivada em descricao
    BEGIN
      INSERT INTO public.produtos (nome, codigo, descricao, qtd_minima, unidade_medida, ativo, created_at)
      VALUES (TRIM(p_nome), TRIM(p_sku), v_cat_derivada, 0, 'unidade', true, now())
      RETURNING id INTO v_prod_id;
    EXCEPTION
      WHEN unique_violation THEN
        RAISE EXCEPTION 'Nao foi possivel cadastrar o produto porque o codigo/SKU % ja esta em uso.', TRIM(p_sku);
    END;
  END;

  -- Criar exatamente 1 registro de estoque inicial (quantidade = 0) para cada uma das 5 filiais oficiais
  v_filial_count := 0;
  FOR v_filial_rec IN
    SELECT id FROM public.filiais
    WHERE id IN (1, 2, 3, 4, 5) AND ativa IS TRUE
    ORDER BY id ASC
    FOR SHARE
  LOOP
    INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
    VALUES (v_filial_rec.id, v_prod_id, 0, 'zerado'::public.status_estoque, now());
    v_filial_count := v_filial_count + 1;
  END LOOP;

  IF v_filial_count <> 5 THEN
    RAISE EXCEPTION 'Operacao negada: Nao foi possivel confirmar estoque inicial para as cinco filiais ativas; a transacao sera revertida.';
  END IF;

  v_resultado := json_build_object(
    'success', true,
    'message', 'Produto cadastrado com sucesso com estoque inicial nas 5 filiais.',
    'produto_id', v_prod_id,
    'sku', TRIM(p_sku),
    'nome', TRIM(p_nome)
  );

  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    INSERT INTO public.idempotencia_chaves (chave, usuario_id, escopo, parametros_hash, resultado_json)
    VALUES (p_idempotency_key, v_user_id, 'cadastrar_produto', v_params_hash, v_resultado)
    ON CONFLICT (chave) DO NOTHING;
  END IF;

  RETURN v_resultado;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cadastrar_produto_com_estoques_rpc(text, text, text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cadastrar_produto_com_estoques_rpc(text, text, text, integer, text) TO authenticated;


-- 3. RPC Transacional Atômico para Criação de Pedido de Compra
CREATE OR REPLACE FUNCTION public.criar_pedido_compra_rpc(
  p_filial_id bigint,
  p_produto_id bigint,
  p_quantidade integer,
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
  v_pedido_id bigint;
  v_params_hash text;
  v_idempotent_rec record;
  v_resultado json;
BEGIN
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

  IF v_user_cargo != 'gerente' THEN
    RAISE EXCEPTION 'Acesso negado: Apenas gerentes possuem permissao para criar pedidos de compra.';
  END IF;

  IF p_filial_id IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: ID da filial e obrigatorio.';
  END IF;
  IF p_produto_id IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: ID do produto e obrigatorio.';
  END IF;
  IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
    RAISE EXCEPTION 'Operacao negada: Quantidade deve ser um inteiro maior que zero.';
  END IF;

  -- Checagem de Idempotência
  IF p_idempotency_key IS NULL OR TRIM(p_idempotency_key) = '' THEN
    RAISE EXCEPTION 'Operacao negada: Chave de idempotencia e obrigatoria para esta operacao.';
  END IF;

  IF LENGTH(p_idempotency_key) > 255 THEN
    RAISE EXCEPTION 'Operacao negada: Chave de idempotencia excede o tamanho maximo permitido (255 caracteres).';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key));
  v_params_hash := md5('criar_pedido:' || COALESCE(p_filial_id::text, '') || ':' || COALESCE(p_produto_id::text, '') || ':' || COALESCE(p_quantidade::text, ''));

  SELECT * INTO v_idempotent_rec
  FROM public.idempotencia_chaves
  WHERE chave = p_idempotency_key;

  IF FOUND THEN
    IF v_idempotent_rec.usuario_id IS DISTINCT FROM v_user_id THEN
      RAISE EXCEPTION 'Acesso negado: A chave de idempotencia % pertence a outro usuario.', p_idempotency_key;
    END IF;
    IF v_idempotent_rec.escopo IS DISTINCT FROM 'criar_pedido' THEN
      RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada em outro escopo (%).', p_idempotency_key, v_idempotent_rec.escopo;
    END IF;
    IF v_idempotent_rec.parametros_hash = v_params_hash THEN
      RETURN v_idempotent_rec.resultado_json;
    ELSE
      RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada com parametros diferentes.', p_idempotency_key;
    END IF;
  END IF;

  -- Inserir o pedido de compra (cabeçalho)
  INSERT INTO public.pedidos_compra (filial_id, usuario_id, status, created_at)
  VALUES (p_filial_id, v_user_id, 'aberto', now())
  RETURNING id INTO v_pedido_id;

  -- Inserir o item do pedido
  INSERT INTO public.itens_pedido_compra (pedido_id, produto_id, quantidade)
  VALUES (v_pedido_id, p_produto_id, p_quantidade);

  v_resultado := json_build_object(
    'success', true,
    'message', 'Pedido de compra criado com sucesso.',
    'pedido_id', v_pedido_id
  );

  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    INSERT INTO public.idempotencia_chaves (chave, usuario_id, escopo, parametros_hash, resultado_json)
    VALUES (p_idempotency_key, v_user_id, 'criar_pedido', v_params_hash, v_resultado)
    ON CONFLICT (chave) DO NOTHING;
  END IF;

  RETURN v_resultado;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.criar_pedido_compra_rpc(bigint, bigint, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_pedido_compra_rpc(bigint, bigint, integer, text) TO authenticated;

COMMIT;
