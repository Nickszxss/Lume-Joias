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

  v_cnt_comb_invalidas integer := 0;
  v_cnt_movs_invalidas integer := 0;
  v_cnt_total_estoque_par integer := 0;
  v_movs_gerente_sul integer := 0;
  v_movs_gerente_oeste integer := 0;
  v_movs_gerente_leste integer := 0;

  -- Mapeamento Estrito das 5 Filiais Oficiais (ID -> Nome Exato no Banco)
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
  -- 1. VALIDAÇÃO ESTREITA DAS 5 FILIAIS OFICIAIS (ID x NOME EXATO E STATUS ATIVO)
  IF (SELECT count(*) FROM public.filiais WHERE id = 1 AND nome = 'Filial Centro' AND ativa = true) <> 1 OR
     (SELECT count(*) FROM public.filiais WHERE id = 2 AND nome = 'Filial Norte' AND ativa = true) <> 1 OR
     (SELECT count(*) FROM public.filiais WHERE id = 3 AND nome = 'Filial Sul' AND ativa = true) <> 1 OR
     (SELECT count(*) FROM public.filiais WHERE id = 4 AND nome = 'Filial Leste' AND ativa = true) <> 1 OR
     (SELECT count(*) FROM public.filiais WHERE id = 5 AND nome = 'Filial Oeste' AND ativa = true) <> 1 THEN
    RAISE EXCEPTION 'ABORTADO: As 5 filiais oficiais (ID 1: Filial Centro, ID 2: Filial Norte, ID 3: Filial Sul, ID 4: Filial Leste, ID 5: Filial Oeste) ativas não foram encontradas ou validadas na tabela public.filiais.';
  END IF;

  -- 2. VALIDAÇÃO E RESOLUÇÃO DETERMINÍSTICA DOS GERENTES ATIVOS POR FILIAL
  -- Grupo Sul: Gerente ativo vinculado à Filial Sul (filial_id = 3). ID 3 preferencial.
  SELECT id INTO v_mgr_sul FROM public.usuarios
  WHERE id = 3 AND (cargo = 'gerente' OR tipo = 'gerente') AND filial_id = 3 AND ativo = true;

  IF v_mgr_sul IS NULL THEN
    SELECT id INTO v_mgr_sul FROM public.usuarios
    WHERE (cargo = 'gerente' OR tipo = 'gerente') AND filial_id = 3 AND ativo = true
    ORDER BY id ASC LIMIT 1;
  END IF;

  -- Grupo Oeste: Gerente ativo vinculado à Filial Oeste (filial_id = 5). ID 5 preferencial.
  SELECT id INTO v_mgr_oeste FROM public.usuarios
  WHERE id = 5 AND (cargo = 'gerente' OR tipo = 'gerente') AND filial_id = 5 AND ativo = true;

  IF v_mgr_oeste IS NULL THEN
    SELECT id INTO v_mgr_oeste FROM public.usuarios
    WHERE (cargo = 'gerente' OR tipo = 'gerente') AND filial_id = 5 AND ativo = true
    ORDER BY id ASC LIMIT 1;
  END IF;

  -- Grupo Leste: Gerente ativo vinculado à Filial Leste (filial_id = 4). ID 7 preferencial.
  SELECT id INTO v_mgr_leste FROM public.usuarios
  WHERE id = 7 AND (cargo = 'gerente' OR tipo = 'gerente') AND filial_id = 4 AND ativo = true;

  IF v_mgr_leste IS NULL THEN
    SELECT id INTO v_mgr_leste FROM public.usuarios
    WHERE (cargo = 'gerente' OR tipo = 'gerente') AND filial_id = 4 AND ativo = true
    ORDER BY id ASC LIMIT 1;
  END IF;

  IF v_mgr_sul IS NULL OR v_mgr_oeste IS NULL OR v_mgr_leste IS NULL THEN
    RAISE EXCEPTION 'ABORTADO: Não foi possível identificar gerentes ativos para assinar as movimentações (Sul: %, Oeste: %, Leste: %).',
      v_mgr_sul, v_mgr_oeste, v_mgr_leste;
  END IF;

  -- 3. VERIFICAÇÃO DE DADOS PREEXISTENTES (PREVENÇÃO DE DUPLICAÇÕES E CONFLITOS DE UNICIDADE)
  IF EXISTS (SELECT 1 FROM public.produtos WHERE codigo IN ('01','02','03','04','05','06','07','08','09')) THEN
    RAISE EXCEPTION 'ABORTADO: Conflito de dados. Já existem produtos cadastrados no banco com os SKUs oficiais (01 a 09).';
  END IF;

  IF EXISTS (SELECT 1 FROM public.produtos WHERE nome IN (
    'Colar de prata', 'Colar de ouro', 'Anel de prata', 'Anel de ouro',
    'Brinco de prata', 'Brinco de ouro', 'Solitária', 'Pulseira de prata', 'Pulseira de ouro'
  )) THEN
    RAISE EXCEPTION 'ABORTADO: Conflito de dados. Já existem produtos cadastrados com nomes oficiais da matriz no banco.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.movimentacoes WHERE motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1') THEN
    RAISE EXCEPTION 'ABORTADO: Estado parcial detectado. Já existem registros de movimentação com o identificador da carga inicial.';
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

      -- Inserção em Estoques (com cast/coerção segura para tipo enum/text se configurado no Postgres)
      INSERT INTO public.estoques (produto_id, filial_id, quantidade, status, updated_at)
      VALUES (v_prod_id, v_filial_id, v_qtd, v_status, NOW());

      v_estoques_criados := v_estoques_criados + 1;

      -- Inserção no Histórico de Movimentações (com cast/coerção segura e gerente obrigatório)
      INSERT INTO public.movimentacoes (produto_id, filial_id, tipo, quantidade, quantidade_anterior, quantidade_nova, usuario_id, motivo, created_at)
      VALUES (v_prod_id, v_filial_id, 'entrada', v_qtd, 0, v_qtd, v_gerente_id, 'CARGA_INICIAL_OFFICIAL_1392_V1', NOW());

      v_movs_criadas := v_movs_criadas + 1;
    END LOOP;
  END LOOP;

  -- 5. VALIDAÇÃO DETALHADA E ITEMIZED DAS 45 COMBINAÇÕES
  FOR k_prod, v_prod_obj IN SELECT * FROM jsonb_each(v_matrix) LOOP
    v_grupo_mgr := v_prod_obj->>'grupo_mgr';
    IF v_grupo_mgr = 'sul' THEN
      v_gerente_id := v_mgr_sul;
    ELSIF v_grupo_mgr = 'oeste' THEN
      v_gerente_id := v_mgr_oeste;
    ELSE
      v_gerente_id := v_mgr_leste;
    END IF;

    SELECT id INTO v_prod_id FROM public.produtos WHERE codigo = v_prod_obj->>'sku';

    FOR k_filial IN SELECT jsonb_object_keys(v_prod_obj) LOOP
      IF k_filial = 'sku' OR k_filial = 'grupo_mgr' THEN CONTINUE; END IF;

      v_filial_id := (v_mapa_filiais->>k_filial)::integer;
      v_qtd := (v_prod_obj->>k_filial)::integer;
      v_status := CASE WHEN v_qtd = 0 THEN 'zerado' WHEN v_qtd <= 10 THEN 'baixo' ELSE 'suficiente' END;

      -- A. Checar registro único em estoques por produto e filial
      SELECT count(*) INTO v_cnt_total_estoque_par FROM public.estoques WHERE produto_id = v_prod_id AND filial_id = v_filial_id;
      IF v_cnt_total_estoque_par <> 1 THEN
        v_cnt_comb_invalidas := v_cnt_comb_invalidas + 1;
      END IF;

      -- B. Checar integridade de quantidade e status no estoque
      IF (SELECT count(*) FROM public.estoques WHERE produto_id = v_prod_id AND filial_id = v_filial_id AND quantidade = v_qtd AND status::text = v_status) <> 1 THEN
        v_cnt_comb_invalidas := v_cnt_comb_invalidas + 1;
      END IF;

      -- C. Checar movimentação de entrada vinculada ao produto, filial, quantidade e gerente correto
      IF (SELECT count(*) FROM public.movimentacoes WHERE produto_id = v_prod_id AND filial_id = v_filial_id AND tipo::text = 'entrada' AND quantidade = v_qtd AND quantidade_anterior = 0 AND quantidade_nova = v_qtd AND usuario_id = v_gerente_id AND motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1') <> 1 THEN
        v_cnt_movs_invalidas := v_cnt_movs_invalidas + 1;
      END IF;
    END LOOP;
  END LOOP;

  IF v_cnt_comb_invalidas > 0 OR v_cnt_movs_invalidas > 0 THEN
    RAISE EXCEPTION 'FALHA DE VALIDAÇÃO ITEMIZADA: Detectadas % combinações de estoque e % movimentações inválidas.',
      v_cnt_comb_invalidas, v_cnt_movs_invalidas;
  END IF;

  -- 6. CONFERÊNCIA DA DISTRIBUIÇÃO POR GERENTE (15 MOVIMENTAÇÕES CADA)
  SELECT count(*) INTO v_movs_gerente_sul FROM public.movimentacoes WHERE usuario_id = v_mgr_sul AND motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1';
  SELECT count(*) INTO v_movs_gerente_oeste FROM public.movimentacoes WHERE usuario_id = v_mgr_oeste AND motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1';
  SELECT count(*) INTO v_movs_gerente_leste FROM public.movimentacoes WHERE usuario_id = v_mgr_leste AND motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1';

  IF v_movs_gerente_sul <> 15 OR v_movs_gerente_oeste <> 15 OR v_movs_gerente_leste <> 15 THEN
    RAISE EXCEPTION 'FALHA NA DISTRIBUIÇÃO DOS GERENTES: Esperado 15 movimentações por gerente (Obtido -> Sul: %, Oeste: %, Leste: %).',
      v_movs_gerente_sul, v_movs_gerente_oeste, v_movs_gerente_leste;
  END IF;

  -- 7. VALIDAÇÕES FINAIS DE TOTAIS GLOBAIS
  SELECT COALESCE(SUM(quantidade), 0) INTO v_sum_unidades
  FROM public.estoques
  WHERE produto_id IN (SELECT id FROM public.produtos WHERE codigo IN ('01','02','03','04','05','06','07','08','09'));

  IF v_prods_criados <> 9 OR v_estoques_criados <> 45 OR v_movs_criadas <> 45 OR v_sum_unidades <> 1392 THEN
    RAISE EXCEPTION 'FALHA DE INTEGRIDADE: Esperado 9 produtos, 45 estoques, 45 movimentações e 1392 unidades. (Obtido: % prods, % estoques, % movs, % unidades). Rollback disparado.',
      v_prods_criados, v_estoques_criados, v_movs_criadas, v_sum_unidades;
  END IF;

  RAISE NOTICE 'SUCCESS: Carga inicial concluída e validada com êxito!';
  RAISE NOTICE 'Produtos criados: % | Estoques criados: % | Movimentações criadas: % | Total unidades: %',
    v_prods_criados, v_estoques_criados, v_movs_criadas, v_sum_unidades;
  RAISE NOTICE 'Gerentes atribuídos: Sul (ID %), Oeste (ID %), Leste (ID %)',
    v_mgr_sul, v_mgr_oeste, v_mgr_leste;
END $$;
