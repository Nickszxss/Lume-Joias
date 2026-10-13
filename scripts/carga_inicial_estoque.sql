-- =====================================================================
-- SCRIPT SQL DE CARGA INICIAL DE ESTOQUE (LUME-JOIAS)
-- Execução única, direta e atômica via Supabase SQL Editor.
-- Sem criação de tabelas, funções, RPCs ou sequências permanentes.
-- =====================================================================

DO $$
DECLARE
  v_prod_id integer;
  v_filial_id integer;
  v_qtd integer;
  v_status text;
  v_gerente_id integer;

  v_mgr_sul integer;
  v_mgr_oeste integer;
  v_mgr_leste integer;

  v_prods_criados integer := 0;
  v_estoques_criados integer := 0;
  v_movs_criadas integer := 0;
  v_sum_unidades integer := 0;

  -- Mapeamento das 5 Filiais Oficiais (Nome -> ID)
  v_mapa_filiais jsonb := '{"Filial Centro": 1, "Filial Norte": 2, "Filial Sul": 3, "Filial Leste": 4, "Filial Oeste": 5}'::jsonb;

  -- Matriz Imutável dos 9 Produtos Oficiais e Quantidades por Filial
  v_matrix jsonb := '{
    "Colar de prata": {"sku": "01", "grupo_mgr": "sul", "Filial Centro": 32, "Filial Norte": 15, "Filial Sul": 48, "Filial Leste": 7, "Filial Oeste": 56},
    "Colar de ouro": {"sku": "02", "grupo_mgr": "sul", "Filial Centro": 12, "Filial Norte": 41, "Filial Sul": 23, "Filial Leste": 59, "Filial Oeste": 5},
    "Anel de prata": {"sku": "03", "grupo_mgr": "sul", "Filial Centro": 54, "Filial Norte": 28, "Filial Sul": 9, "Filial Leste": 36, "Filial Oeste": 17},
    "Anel de ouro": {"sku": "04", "grupo_mgr": "oeste", "Filial Centro": 21, "Filial Norte": 63, "Filial Sul": 14, "Filial Leste": 44, "Filial Oeste": 30},
    "Brinco de prata": {"sku": "05", "grupo_mgr": "oeste", "Filial Centro": 46, "Filial Norte": 8, "Filial Sul": 35, "Filial Leste": 19, "Filial Oeste": 61},
    "Brinco de ouro": {"sku": "06", "grupo_mgr": "oeste", "Filial Centro": 6, "Filial Norte": 52, "Filial Sul": 27, "Filial Leste": 38, "Filial Oeste": 13},
    "Solitária": {"sku": "07", "grupo_mgr": "leste", "Filial Centro": 39, "Filial Norte": 18, "Filial Sul": 64, "Filial Leste": 11, "Filial Oeste": 25},
    "Pulseira de prata": {"sku": "08", "grupo_mgr": "leste", "Filial Centro": 16, "Filial Norte": 43, "Filial Sul": 3, "Filial Leste": 57, "Filial Oeste": 31},
    "Pulseira de ouro": {"sku": "09", "grupo_mgr": "leste", "Filial Centro": 60, "Filial Norte": 24, "Filial Sul": 33, "Filial Leste": 2, "Filial Oeste": 47}
  }'::jsonb;

  k_prod text;
  k_filial text;
  v_prod_obj jsonb;
  v_grupo_mgr text;
BEGIN
  -- 1. VALIDAÇÃO DAS 5 FILIAIS OFICIAIS
  IF (SELECT count(*) FROM public.filiais WHERE id IN (1, 2, 3, 4, 5) AND ativa = true) <> 5 THEN
    RAISE EXCEPTION 'ABORTADO: As 5 filiais oficiais (IDs 1 a 5, ativas) não foram encontradas na tabela public.filiais.';
  END IF;

  -- 2. VALIDAÇÃO E RESOLUÇÃO DOS GERENTES ATIVOS PARA AS MOVIMENTAÇÕES
  SELECT id INTO v_mgr_sul FROM public.usuarios WHERE id = 3 AND (cargo = 'gerente' OR tipo = 'gerente') AND ativo = true;
  IF v_mgr_sul IS NULL THEN
    SELECT id INTO v_mgr_sul FROM public.usuarios WHERE (cargo = 'gerente' OR tipo = 'gerente') AND filial_id = 3 AND ativo = true LIMIT 1;
  END IF;

  SELECT id INTO v_mgr_oeste FROM public.usuarios WHERE id = 5 AND (cargo = 'gerente' OR tipo = 'gerente') AND ativo = true;
  IF v_mgr_oeste IS NULL THEN
    SELECT id INTO v_mgr_oeste FROM public.usuarios WHERE (cargo = 'gerente' OR tipo = 'gerente') AND filial_id = 5 AND ativo = true LIMIT 1;
  END IF;

  SELECT id INTO v_mgr_leste FROM public.usuarios WHERE id = 7 AND (cargo = 'gerente' OR tipo = 'gerente') AND ativo = true;
  IF v_mgr_leste IS NULL THEN
    SELECT id INTO v_mgr_leste FROM public.usuarios WHERE (cargo = 'gerente' OR tipo = 'gerente') AND filial_id = 4 AND ativo = true LIMIT 1;
  END IF;

  IF v_mgr_sul IS NULL OR v_mgr_oeste IS NULL OR v_mgr_leste IS NULL THEN
    RAISE EXCEPTION 'ABORTADO: Não foi possível identificar gerentes ativos para assinar as movimentações nas filiais.';
  END IF;

  -- 3. VERIFICAÇÃO DE DADOS PREEXISTENTES (PREVENÇÃO DE DUPLICAÇÃO)
  IF EXISTS (SELECT 1 FROM public.produtos WHERE codigo IN ('01','02','03','04','05','06','07','08','09')) THEN
    RAISE EXCEPTION 'ABORTADO: Conflito de dados. Já existem produtos cadastrados no banco com os SKUs oficiais (01 a 09).';
  END IF;

  -- 4. PROCESSAMENTO DA CARGA INICIAL
  FOR k_prod, v_prod_obj IN SELECT * FROM jsonb_each(v_matrix) LOOP
    v_grupo_mgr := v_prod_obj->>'grupo_mgr';
    IF v_grupo_mgr = 'sul' THEN
      v_gerente_id := v_mgr_sul;
    ELSIF v_grupo_mgr = 'oeste' THEN
      v_gerente_id := v_mgr_oeste;
    ELSE
      v_gerente_id := v_mgr_leste;
    END IF;

    -- Inserção do Produto
    INSERT INTO public.produtos (nome, codigo, descricao, unidade_medida, qtd_minima, ativo)
    VALUES (k_prod, v_prod_obj->>'sku', 'Geral', 'unidade', 10, true)
    RETURNING id INTO v_prod_id;

    v_prods_criados := v_prods_criados + 1;

    -- Inserção de Estoques e Movimentações por Filial
    FOR k_filial IN SELECT jsonb_object_keys(v_prod_obj) LOOP
      IF k_filial = 'sku' OR k_filial = 'grupo_mgr' THEN CONTINUE; END IF;

      v_filial_id := (v_mapa_filiais->>k_filial)::integer;
      v_qtd := (v_prod_obj->>k_filial)::integer;
      v_status := CASE WHEN v_qtd = 0 THEN 'zerado' WHEN v_qtd <= 10 THEN 'baixo' ELSE 'suficiente' END;

      -- Inserção em Estoques
      INSERT INTO public.estoques (produto_id, filial_id, quantidade, status, updated_at)
      VALUES (v_prod_id, v_filial_id, v_qtd, v_status, NOW());

      v_estoques_criados := v_estoques_criados + 1;

      -- Inserção no Histórico de Movimentações (Auditável)
      INSERT INTO public.movimentacoes (produto_id, filial_id, tipo, quantidade, quantidade_anterior, quantidade_nova, usuario_id, motivo, created_at)
      VALUES (v_prod_id, v_filial_id, 'entrada', v_qtd, 0, v_qtd, v_gerente_id, 'CARGA_INICIAL_OFFICIAL_1392_V1', NOW());

      v_movs_criadas := v_movs_criadas + 1;
    END LOOP;
  END LOOP;

  -- 5. VALIDAÇÕES FINAIS E ASSERTIONS
  SELECT COALESCE(SUM(quantidade), 0) INTO v_sum_unidades
  FROM public.estoques
  WHERE produto_id IN (SELECT id FROM public.produtos WHERE codigo IN ('01','02','03','04','05','06','07','08','09'));

  IF v_prods_criados <> 9 OR v_estoques_criados <> 45 OR v_movs_criadas <> 45 OR v_sum_unidades <> 1392 THEN
    RAISE EXCEPTION 'FALHA DE INTEGRIDADE: Esperado 9 produtos, 45 estoques, 45 movimentações e 1392 unidades. (Obtido: % prods, % estoques, % movs, % unidades). Rollback disparado.',
      v_prods_criados, v_estoques_criados, v_movs_criadas, v_sum_unidades;
  END IF;

  RAISE NOTICE 'SUCCESS: Carga inicial concluída com êxito!';
  RAISE NOTICE 'Produtos criados: % | Estoques criados: % | Movimentações criadas: % | Total unidades: %',
    v_prods_criados, v_estoques_criados, v_movs_criadas, v_sum_unidades;
END $$;
