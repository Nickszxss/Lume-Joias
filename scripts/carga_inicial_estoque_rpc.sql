-- =====================================================================
-- CANDIDATO SQL: CARGA INICIAL DE ESTOQUE TRANSACIONAL (LUME-JOIAS)
-- AVISO: ESTRITAMENTE NÃO APLICADO EM PRODUÇÃO NESTA TAREFA.
-- =====================================================================

-- 1. Tabela de Controle de Idempotência Imutável
CREATE TABLE IF NOT EXISTS public.carga_inicial_controle (
    id SERIAL PRIMARY KEY,
    identificador_carga TEXT UNIQUE NOT NULL,
    total_unidades INTEGER NOT NULL,
    total_combinacoes INTEGER NOT NULL,
    executado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Função Transacional Atômica com SECURITY DEFINER e search_path Fixo
CREATE OR REPLACE FUNCTION public.executar_carga_inicial_estoque_rpc()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_prod_id integer;
  v_filial_id integer;
  v_qtd integer;
  v_status text;
  v_prods_criados integer := 0;
  v_estoques_criados integer := 0;
  v_movs_criadas integer := 0;

  -- Mapeamento Estrito das 5 Filiais Oficiais (ID -> Nome Exato no Banco)
  v_mapa_filiais jsonb := '{"Filial Centro": 1, "Filial Norte": 2, "Filial Sul": 3, "Filial Leste": 4, "Filial Oeste": 5}'::jsonb;

  -- Matriz Imutável dos 9 Produtos Oficiais
  v_matrix jsonb := '{
    "Colar de prata": {"sku": "01", "Filial Centro": 32, "Filial Norte": 15, "Filial Sul": 48, "Filial Leste": 7, "Filial Oeste": 56},
    "Colar de ouro": {"sku": "02", "Filial Centro": 12, "Filial Norte": 41, "Filial Sul": 23, "Filial Leste": 59, "Filial Oeste": 5},
    "Anel de prata": {"sku": "03", "Filial Centro": 54, "Filial Norte": 28, "Filial Sul": 9, "Filial Leste": 36, "Filial Oeste": 17},
    "Anel de ouro": {"sku": "04", "Filial Centro": 21, "Filial Norte": 63, "Filial Sul": 14, "Filial Leste": 44, "Filial Oeste": 30},
    "Brinco de prata": {"sku": "05", "Filial Centro": 46, "Filial Norte": 8, "Filial Sul": 35, "Filial Leste": 19, "Filial Oeste": 61},
    "Brinco de ouro": {"sku": "06", "Filial Centro": 6, "Filial Norte": 52, "Filial Sul": 27, "Filial Leste": 38, "Filial Oeste": 13},
    "Solitária": {"sku": "07", "Filial Centro": 39, "Filial Norte": 18, "Filial Sul": 64, "Filial Leste": 11, "Filial Oeste": 25},
    "Pulseira de prata": {"sku": "08", "Filial Centro": 16, "Filial Norte": 43, "Filial Sul": 3, "Filial Leste": 57, "Filial Oeste": 31},
    "Pulseira de ouro": {"sku": "09", "Filial Centro": 60, "Filial Norte": 24, "Filial Sul": 33, "Filial Leste": 2, "Filial Oeste": 47}
  }'::jsonb;

  k_prod text;
  k_filial text;
  v_prod_obj jsonb;
  v_tot_unidades_calc integer := 0;
BEGIN
  -- A. Serialização de Concorrência (Advisory Lock Transacional Único)
  IF NOT pg_try_advisory_xact_lock(88998899) THEN
    RAISE EXCEPTION 'OPERAÇÃO CONCORRENTE DETECTADA: Outra transação de carga inicial está em andamento.';
  END IF;

  -- B. Trava de Execução Prévia (Idempotência Inequívoca)
  IF EXISTS (SELECT 1 FROM public.carga_inicial_controle WHERE identificador_carga = 'CARGA_INICIAL_OFFICIAL_1392_V1') THEN
    RAISE EXCEPTION 'OPERAÇÃO BLOQUEADA: A carga inicial oficial já foi executada e confirmada anteriormente neste banco.';
  END IF;

  -- C. Validação Individual e Estrita das 5 Filiais
  IF (SELECT COUNT(*) FROM public.filiais WHERE id = 1 AND nome = 'Filial Centro' AND ativa = true) <> 1 OR
     (SELECT COUNT(*) FROM public.filiais WHERE id = 2 AND nome = 'Filial Norte' AND ativa = true) <> 1 OR
     (SELECT COUNT(*) FROM public.filiais WHERE id = 3 AND nome = 'Filial Sul' AND ativa = true) <> 1 OR
     (SELECT COUNT(*) FROM public.filiais WHERE id = 4 AND nome = 'Filial Leste' AND ativa = true) <> 1 OR
     (SELECT COUNT(*) FROM public.filiais WHERE id = 5 AND nome = 'Filial Oeste' AND ativa = true) <> 1 THEN
    RAISE EXCEPTION 'OPERAÇÃO ABORTADA: As 5 filiais oficiais (IDs 1 a 5 com nomes exatos e ativas) não foram encontradas no banco.';
  END IF;

  -- D. Validação de Conflitos Prévia
  IF EXISTS (SELECT 1 FROM public.produtos WHERE codigo IN ('01','02','03','04','05','06','07','08','09')) THEN
    RAISE EXCEPTION 'OPERAÇÃO ABORTADA: Já existem produtos cadastrados com os SKUs da carga inicial (01 a 09).';
  END IF;

  -- E. Iterar Matriz e Cadastrar sem ON CONFLICT DO UPDATE (Sem Sobrescrita Indiscriminada)
  FOR k_prod, v_prod_obj IN SELECT * FROM jsonb_each(v_matrix) LOOP

    -- Inserção Rígida do Produto
    INSERT INTO public.produtos (nome, codigo, descricao, unidade_medida, qtd_minima, ativo)
    VALUES (k_prod, v_prod_obj->>'sku', 'Geral', 'unidade', 10, true)
    RETURNING id INTO v_prod_id;

    v_prods_criados := v_prods_criados + 1;

    -- Iterar Filiais do Produto
    FOR k_filial IN SELECT jsonb_object_keys(v_prod_obj) LOOP
      IF k_filial = 'sku' THEN CONTINUE; END IF;

      v_filial_id := (v_mapa_filiais->>k_filial)::integer;
      v_qtd := (v_prod_obj->>k_filial)::integer;
      v_status := CASE WHEN v_qtd = 0 THEN 'zerado' WHEN v_qtd <= 10 THEN 'baixo' ELSE 'suficiente' END;

      -- Inserção Rígida do Estoque (Sem ON CONFLICT DO UPDATE)
      INSERT INTO public.estoques (produto_id, filial_id, quantidade, status, updated_at)
      VALUES (v_prod_id, v_filial_id, v_qtd, v_status, NOW());

      v_estoques_criados := v_estoques_criados + 1;
      v_tot_unidades_calc := v_tot_unidades_calc + v_qtd;

      -- Registrar Entrada Única no Histórico
      INSERT INTO public.movimentacoes (produto_id, filial_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
      VALUES (v_prod_id, v_filial_id, 'entrada', v_qtd, 0, v_qtd, 'CARGA_INICIAL_OFFICIAL_1392_V1', NOW());

      v_movs_criadas := v_movs_criadas + 1;

    END LOOP;
  END LOOP;

  -- F. Validações Pós-Inserção Rígidas (Assertion Check)
  IF v_prods_criados <> 9 OR v_estoques_criados <> 45 OR v_movs_criadas <> 45 OR v_tot_unidades_calc <> 1392 THEN
    RAISE EXCEPTION 'FALHA NA ASSERTION PÓS-INSERÇÃO: Contagens gravadas não correspondem exatamente ao esperado (9 prods, 45 ests, 45 movs, 1392 un).';
  END IF;

  -- G. Gravar Registro de Controle Imutável
  INSERT INTO public.carga_inicial_controle (identificador_carga, total_unidades, total_combinacoes)
  VALUES ('CARGA_INICIAL_OFFICIAL_1392_V1', 1392, 45);

  -- H. Retorno de Confirmação Sucesso
  RETURN jsonb_build_object(
    'sucesso', true,
    'produtos_criados', v_prods_criados,
    'estoques_criados', v_estoques_criados,
    'movimentacoes_criadas', v_movs_criadas,
    'total_unidades', v_tot_unidades_calc,
    'mensagem', 'Carga inicial executada com sucesso e atomicidade transacional.'
  );

EXCEPTION WHEN OTHERS THEN
  -- ROLLBACK AUTOMÁTICO INSTANTÂNEO DE TODA A TRANSAÇÃO POSTGRESQL
  RAISE EXCEPTION 'FALHA NA CARGA INICIAL (ROLLBACK EXECUTADO): %', SQLERRM;
END;
$$;

-- Restrição Estrita de Permissões (SEM ACESSO VIA ANONYMOUS / PUBLIC / AUTHENTICATED)
REVOKE ALL ON FUNCTION public.executar_carga_inicial_estoque_rpc() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.executar_carga_inicial_estoque_rpc() FROM anon;
REVOKE ALL ON FUNCTION public.executar_carga_inicial_estoque_rpc() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.executar_carga_inicial_estoque_rpc() TO postgres, service_role;
