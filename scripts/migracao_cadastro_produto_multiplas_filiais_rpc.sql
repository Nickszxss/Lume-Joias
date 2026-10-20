-- =====================================================================
-- MIGRAÇÃO DE CADASTRO DE PRODUTOS COM QUANTIDADE E MÚLTIPLAS FILIAIS
-- Local de execução: Supabase Dashboard > SQL Editor.
-- Descrição: Permite cadastrar produto uma única vez especificando
-- quantidade (0 a 50) e selecionar uma ou mais filiais.
-- =====================================================================

DROP FUNCTION IF EXISTS public.cadastrar_produto_com_estoques_rpc(text, text, text, integer, text);

CREATE OR REPLACE FUNCTION public.cadastrar_produto_com_estoques_rpc(
  p_nome text,
  p_sku text,
  p_categoria text DEFAULT 'Geral',
  p_qtd_minima integer DEFAULT 10,
  p_idempotency_key text DEFAULT NULL,
  p_quantidade integer DEFAULT 0,
  p_filiais_ids integer[] DEFAULT ARRAY[1, 2, 3, 4, 5]
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
  v_distinct_filiais_count integer;
  v_params_hash text;
  v_idempotent_rec record;
  v_resultado json;
  v_status public.status_estoque;
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

  -- Validação de quantidade (0 a 50)
  IF p_quantidade IS NULL OR p_quantidade < 0 OR p_quantidade > 50 THEN
    RAISE EXCEPTION 'Operacao negada: Quantidade deve ser um numero inteiro entre 0 e 50.';
  END IF;

  -- Validação de filiais selecionadas
  IF p_filiais_ids IS NULL OR array_length(p_filiais_ids, 1) IS NULL OR array_length(p_filiais_ids, 1) = 0 THEN
    RAISE EXCEPTION 'Operacao negada: Selecione pelo menos uma filial.';
  END IF;

  SELECT count(DISTINCT f) INTO v_distinct_filiais_count
  FROM unnest(p_filiais_ids) AS f;

  SELECT count(DISTINCT id) INTO v_filial_count
  FROM public.filiais
  WHERE id = ANY(p_filiais_ids) AND ativa IS TRUE;

  IF v_filial_count <> v_distinct_filiais_count THEN
    RAISE EXCEPTION 'Operacao negada: Uma ou mais filiais selecionadas sao invalidas ou inativas.';
  END IF;

  -- Checagem de Idempotência
  IF p_idempotency_key IS NULL OR TRIM(p_idempotency_key) = '' THEN
    RAISE EXCEPTION 'Operacao negada: Chave de idempotencia e obrigatoria para esta operacao.';
  END IF;

  IF LENGTH(p_idempotency_key) > 255 THEN
    RAISE EXCEPTION 'Operacao negada: Chave de idempotencia excede o tamanho maximo permitido (255 caracteres).';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key));

  SELECT md5('cadastrar_produto:' || TRIM(p_nome) || ':' || TRIM(p_sku) || ':' || p_quantidade::text || ':' || string_agg(f::text, ',' ORDER BY f))
  INTO v_params_hash
  FROM unnest(p_filiais_ids) AS f;

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

  -- Criar registros de estoque APENAS para as filiais selecionadas
  v_filial_count := 0;
  FOR v_filial_rec IN
    SELECT DISTINCT id FROM public.filiais
    WHERE id = ANY(p_filiais_ids) AND ativa IS TRUE
    ORDER BY id ASC
    FOR SHARE
  LOOP
    v_status := CASE
      WHEN p_quantidade = 0 THEN 'zerado'::public.status_estoque
      WHEN p_quantidade < 20 THEN 'baixo'::public.status_estoque
      WHEN p_quantidade <= 50 THEN 'suficiente'::public.status_estoque
      ELSE 'suficiente+'::public.status_estoque
    END;

    INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
    VALUES (v_filial_rec.id, v_prod_id, p_quantidade, v_status, now());

    IF p_quantidade > 0 THEN
      INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
      VALUES (v_prod_id, v_filial_rec.id, v_user_id, 'entrada'::public.tipo_movimentacao, p_quantidade, 0, p_quantidade, 'Cadastro inicial de produto', now());
    END IF;

    v_filial_count := v_filial_count + 1;
  END LOOP;

  IF v_filial_count <> v_distinct_filiais_count THEN
    RAISE EXCEPTION 'Operacao negada: Nao foi possivel confirmar estoque inicial para as filiais selecionadas; a transacao sera revertida.';
  END IF;

  v_resultado := json_build_object(
    'success', true,
    'message', 'Produto cadastrado com sucesso com estoque inicial nas filiais selecionadas.',
    'produto_id', v_prod_id,
    'sku', TRIM(p_sku),
    'nome', TRIM(p_nome),
    'quantidade', p_quantidade,
    'filiais_ids', p_filiais_ids
  );

  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    INSERT INTO public.idempotencia_chaves (chave, usuario_id, escopo, parametros_hash, resultado_json)
    VALUES (p_idempotency_key, v_user_id, 'cadastrar_produto', v_params_hash, v_resultado)
    ON CONFLICT (chave) DO NOTHING;
  END IF;

  RETURN v_resultado;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cadastrar_produto_com_estoques_rpc(text, text, text, integer, text, integer, integer[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cadastrar_produto_com_estoques_rpc(text, text, text, integer, text, integer, integer[]) TO authenticated;
