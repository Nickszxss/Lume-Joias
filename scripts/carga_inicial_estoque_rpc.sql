-- =====================================================================
-- CANDIDATO SQL: CARGA INICIAL DE ESTOQUE TRANSACIONAL (LUME-JOIAS) - REVISÃO TAREFA 15
-- DISTRIBUIÇÃO DAS 45 MOVIMENTAÇÕES ENTRE OS 3 GERENTES OFICIAIS (IDs 3, 5, 7)
-- AVISO: ESTRITAMENTE NÃO APLICADO EM PRODUÇÃO NESTA TAREFA.
-- =====================================================================

-- 1. Tabela de Controle de Idempotência Imutável
CREATE SEQUENCE IF NOT EXISTS public.carga_inicial_controle_id_seq;

CREATE TABLE IF NOT EXISTS public.carga_inicial_controle (
    id INTEGER PRIMARY KEY DEFAULT nextval('public.carga_inicial_controle_id_seq'),
    identificador_carga TEXT UNIQUE NOT NULL,
    total_unidades INTEGER NOT NULL,
    total_combinacoes INTEGER NOT NULL,
    executado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Atribuição explícita de propriedade das tabelas/sequências para o papel administrativo
ALTER TABLE public.carga_inicial_controle OWNER TO postgres;
ALTER SEQUENCE public.carga_inicial_controle_id_seq OWNER TO postgres;
ALTER SEQUENCE public.carga_inicial_controle_id_seq OWNED BY public.carga_inicial_controle.id;

-- Revogação estrita de privilégios públicos e de papéis cliente-side
REVOKE ALL ON TABLE public.carga_inicial_controle FROM PUBLIC;
REVOKE ALL ON TABLE public.carga_inicial_controle FROM anon;
REVOKE ALL ON TABLE public.carga_inicial_controle FROM authenticated;

REVOKE ALL ON SEQUENCE public.carga_inicial_controle_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE public.carga_inicial_controle_id_seq FROM anon;
REVOKE ALL ON SEQUENCE public.carga_inicial_controle_id_seq FROM authenticated;

-- 2. Função Transacional Atômica com SECURITY DEFINER e search_path Estritamente Fixo
CREATE OR REPLACE FUNCTION public.executar_carga_inicial_estoque_rpc()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_prod_id integer;
  v_filial_id integer;
  v_qtd integer;
  v_status text;
  v_gerente_id integer;
  v_prods_criados integer := 0;
  v_estoques_criados integer := 0;
  v_movs_criadas integer := 0;

  -- Mapeamento Estrito das 5 Filiais Oficiais (ID -> Nome Exato no Banco)
  v_mapa_filiais jsonb := '{"Filial Centro": 1, "Filial Norte": 2, "Filial Sul": 3, "Filial Leste": 4, "Filial Oeste": 5}'::jsonb;

  -- Matriz Imutável dos 9 Produtos Oficiais com atribuição de Gerente (IDs 3, 5 e 7)
  -- Gerente ID 3 (Sul): Produtos 01, 02, 03 (15 movimentações)
  -- Gerente ID 5 (Oeste): Produtos 04, 05, 06 (15 movimentações)
  -- Gerente ID 7 (Leste): Produtos 07, 08, 09 (15 movimentações)
  v_matrix jsonb := '{
    "Colar de prata": {"sku": "01", "gerente_id": 3, "Filial Centro": 32, "Filial Norte": 15, "Filial Sul": 48, "Filial Leste": 7, "Filial Oeste": 56},
    "Colar de ouro": {"sku": "02", "gerente_id": 3, "Filial Centro": 12, "Filial Norte": 41, "Filial Sul": 23, "Filial Leste": 59, "Filial Oeste": 5},
    "Anel de prata": {"sku": "03", "gerente_id": 3, "Filial Centro": 54, "Filial Norte": 28, "Filial Sul": 9, "Filial Leste": 36, "Filial Oeste": 17},
    "Anel de ouro": {"sku": "04", "gerente_id": 5, "Filial Centro": 21, "Filial Norte": 63, "Filial Sul": 14, "Filial Leste": 44, "Filial Oeste": 30},
    "Brinco de prata": {"sku": "05", "gerente_id": 5, "Filial Centro": 46, "Filial Norte": 8, "Filial Sul": 35, "Filial Leste": 19, "Filial Oeste": 61},
    "Brinco de ouro": {"sku": "06", "gerente_id": 5, "Filial Centro": 6, "Filial Norte": 52, "Filial Sul": 27, "Filial Leste": 38, "Filial Oeste": 13},
    "Solitária": {"sku": "07", "gerente_id": 7, "Filial Centro": 39, "Filial Norte": 18, "Filial Sul": 64, "Filial Leste": 11, "Filial Oeste": 25},
    "Pulseira de prata": {"sku": "08", "gerente_id": 7, "Filial Centro": 16, "Filial Norte": 43, "Filial Sul": 3, "Filial Leste": 57, "Filial Oeste": 31},
    "Pulseira de ouro": {"sku": "09", "gerente_id": 7, "Filial Centro": 60, "Filial Norte": 24, "Filial Sul": 33, "Filial Leste": 2, "Filial Oeste": 47}
  }'::jsonb;

  k_prod text;
  k_filial text;
  v_prod_obj jsonb;

  -- Variáveis de Checagem Físicas Individuais das 45 Combinações
  v_cnt_comb_invalidas integer := 0;
  v_cnt_movs_invalidas integer := 0;
  v_cnt_total_estoque_par integer := 0;
  v_cnt_prods integer;
  v_cnt_estoques_extras integer;
  v_cnt_movs_extras integer;
  v_sum_unidades integer;
  v_movs_gerente_3 integer := 0;
  v_movs_gerente_5 integer := 0;
  v_movs_gerente_7 integer := 0;
BEGIN
  -- A. Trava de Concorrência (Advisory Lock Transacional Único)
  IF NOT pg_catalog.pg_try_advisory_xact_lock(88998899) THEN
    RAISE EXCEPTION 'OPERAÇÃO CONCORRENTE DETECTADA: Outra transação de carga inicial está em andamento.';
  END IF;

  -- B.1 Validação Estrutural Completa da Tabela de Controle Preexistente, Sequência, PK, UNIQUE, DEFAULT e Tipos
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_tables WHERE schemaname = 'public' AND tablename = 'carga_inicial_controle') THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'carga_inicial_controle'
        AND column_name = 'id' AND data_type IN ('integer', 'bigint')
    ) OR NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'carga_inicial_controle'
        AND column_name = 'identificador_carga' AND data_type IN ('text', 'character varying') AND is_nullable = 'NO'
    ) OR NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'carga_inicial_controle'
        AND column_name = 'total_unidades' AND data_type = 'integer' AND is_nullable = 'NO'
    ) OR NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'carga_inicial_controle'
        AND column_name = 'total_combinacoes' AND data_type = 'integer' AND is_nullable = 'NO'
    ) OR NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'carga_inicial_controle'
        AND column_name = 'executado_em' AND data_type LIKE '%timestamp%' AND is_nullable = 'NO'
    ) OR NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name AND tc.table_schema = ccu.table_schema
      WHERE tc.table_schema = 'public' AND tc.table_name = 'carga_inicial_controle'
        AND tc.constraint_type = 'PRIMARY KEY' AND ccu.column_name = 'id'
    ) OR NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name AND tc.table_schema = ccu.table_schema
      WHERE tc.table_schema = 'public' AND tc.table_name = 'carga_inicial_controle'
        AND tc.constraint_type = 'UNIQUE' AND ccu.column_name = 'identificador_carga'
    ) OR NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'carga_inicial_controle'
        AND column_name = 'id' AND column_default LIKE '%carga_inicial_controle_id_seq%'
    ) THEN
      RAISE EXCEPTION 'OPERAÇÃO ABORTADA: Tabela public.carga_inicial_controle preexistente é incompatível com o esquema esperado (chave primária em id, restrição UNIQUE em identificador_carga, default de sequência ou tipos divergentes).';
    END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_sequences WHERE schemaname = 'public' AND sequencename = 'carga_inicial_controle_id_seq') THEN
    RAISE EXCEPTION 'OPERAÇÃO ABORTADA: Sequência public.carga_inicial_controle_id_seq não encontrada no esquema público.';
  END IF;

  -- B.2 Trava de Idempotência na Tabela de Controle
  IF EXISTS (SELECT 1 FROM public.carga_inicial_controle WHERE identificador_carga = 'CARGA_INICIAL_OFFICIAL_1392_V1') THEN
    RAISE EXCEPTION 'OPERAÇÃO BLOQUEADA: A carga inicial oficial já foi executada e registrada em carga_inicial_controle anteriormente.';
  END IF;

  -- C. Validação Estrita dos 3 Gerentes Oficiais (IDs 3, 5 e 7 Ativos com cargo = gerente E tipo = gerente e Filiais Correspondentes)
  IF (SELECT count(*) FROM public.usuarios WHERE id = 3 AND filial_id = 3 AND cargo = 'gerente' AND tipo = 'gerente' AND ativo = true) <> 1 OR
     (SELECT count(*) FROM public.usuarios WHERE id = 5 AND filial_id = 5 AND cargo = 'gerente' AND tipo = 'gerente' AND ativo = true) <> 1 OR
     (SELECT count(*) FROM public.usuarios WHERE id = 7 AND filial_id = 4 AND cargo = 'gerente' AND tipo = 'gerente' AND ativo = true) <> 1 THEN
    RAISE EXCEPTION 'OPERAÇÃO ABORTADA: Os 3 gerentes oficiais (IDs 3 [Filial 3], 5 [Filial 5] e 7 [Filial 4] ativos com cargo=gerente e tipo=gerente) não foram encontrados ou validados no banco.';
  END IF;

  -- D. Validação Estrita das 5 Filiais Oficiais
  IF (SELECT count(*) FROM public.filiais WHERE id = 1 AND nome = 'Filial Centro' AND ativa = true) <> 1 OR
     (SELECT count(*) FROM public.filiais WHERE id = 2 AND nome = 'Filial Norte' AND ativa = true) <> 1 OR
     (SELECT count(*) FROM public.filiais WHERE id = 3 AND nome = 'Filial Sul' AND ativa = true) <> 1 OR
     (SELECT count(*) FROM public.filiais WHERE id = 4 AND nome = 'Filial Leste' AND ativa = true) <> 1 OR
     (SELECT count(*) FROM public.filiais WHERE id = 5 AND nome = 'Filial Oeste' AND ativa = true) <> 1 THEN
    RAISE EXCEPTION 'OPERAÇÃO ABORTADA: As 5 filiais oficiais (IDs 1 a 5 com nomes exatos e ativas = true) não foram encontradas no banco.';
  END IF;

  -- E. Validação de Conflitos Prévia
  IF EXISTS (SELECT 1 FROM public.produtos WHERE codigo IN ('01','02','03','04','05','06','07','08','09')) THEN
    RAISE EXCEPTION 'OPERAÇÃO ABORTADA: Conflito de dados. Já existem produtos cadastrados no banco com os SKUs oficiais (01 a 09).';
  END IF;

  IF EXISTS (SELECT 1 FROM public.movimentacoes WHERE motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1') THEN
    RAISE EXCEPTION 'OPERAÇÃO ABORTADA: Estado parcial detectado. Já existem registros de movimentação com o identificador da carga.';
  END IF;

  -- F. Iterar Matriz e Cadastrar Produtos, Estoques e Movimentações com usuario_id NOT NULL do Gerente
  FOR k_prod, v_prod_obj IN SELECT * FROM jsonb_each(v_matrix) LOOP
    v_gerente_id := (v_prod_obj->>'gerente_id')::integer;

    INSERT INTO public.produtos (nome, codigo, descricao, unidade_medida, qtd_minima, ativo)
    VALUES (k_prod, v_prod_obj->>'sku', 'Geral', 'unidade', 10, true)
    RETURNING id INTO v_prod_id;

    v_prods_criados := v_prods_criados + 1;

    FOR k_filial IN SELECT jsonb_object_keys(v_prod_obj) LOOP
      IF k_filial = 'sku' OR k_filial = 'gerente_id' THEN CONTINUE; END IF;

      v_filial_id := (v_mapa_filiais->>k_filial)::integer;
      v_qtd := (v_prod_obj->>k_filial)::integer;
      v_status := CASE WHEN v_qtd = 0 THEN 'zerado' WHEN v_qtd <= 10 THEN 'baixo' ELSE 'suficiente' END;

      -- Inserção Rígida em Estoques com coerção dinâmica/explícita para o tipo real (enum/text)
      INSERT INTO public.estoques (produto_id, filial_id, quantidade, status, updated_at)
      VALUES (v_prod_id, v_filial_id, v_qtd, v_status::public.status_estoque, pg_catalog.now());

      v_estoques_criados := v_estoques_criados + 1;

      -- Inserção Rígida no Histórico com usuario_id OBRIGATÓRIO (NOT NULL) e coerção para tipo movimentação
      INSERT INTO public.movimentacoes (produto_id, filial_id, tipo, quantidade, quantidade_anterior, quantidade_nova, usuario_id, motivo, created_at)
      VALUES (v_prod_id, v_filial_id, 'entrada'::public.tipo_movimentacao, v_qtd, 0, v_qtd, v_gerente_id, 'CARGA_INICIAL_OFFICIAL_1392_V1', pg_catalog.now());

      v_movs_criadas := v_movs_criadas + 1;
    END LOOP;
  END LOOP;

  -- G. Validação Física Itemizada das 45 Combinações e Distribuição por Gerente
  FOR k_prod, v_prod_obj IN SELECT * FROM jsonb_each(v_matrix) LOOP
    v_gerente_id := (v_prod_obj->>'gerente_id')::integer;
    SELECT id INTO v_prod_id FROM public.produtos WHERE codigo = v_prod_obj->>'sku';

    FOR k_filial IN SELECT jsonb_object_keys(v_prod_obj) LOOP
      IF k_filial = 'sku' OR k_filial = 'gerente_id' THEN CONTINUE; END IF;

      v_filial_id := (v_mapa_filiais->>k_filial)::integer;
      v_qtd := (v_prod_obj->>k_filial)::integer;
      v_status := CASE WHEN v_qtd = 0 THEN 'zerado' WHEN v_qtd <= 10 THEN 'baixo' ELSE 'suficiente' END;

      -- G.1 Verificar registro único em estoques
      SELECT count(*) INTO v_cnt_total_estoque_par FROM public.estoques WHERE produto_id = v_prod_id AND filial_id = v_filial_id;
      IF v_cnt_total_estoque_par <> 1 THEN
        v_cnt_comb_invalidas := v_cnt_comb_invalidas + 1;
      END IF;

      -- G.2 Verificar se o único registro possui quantidade e status exatamente iguais à matriz (com coerção para compatibilidade enum/text)
      IF (SELECT count(*) FROM public.estoques WHERE produto_id = v_prod_id AND filial_id = v_filial_id AND quantidade = v_qtd AND status::text = v_status) <> 1 THEN
        v_cnt_comb_invalidas := v_cnt_comb_invalidas + 1;
      END IF;

      -- G.3 Verificar se existe EXATAMENTE UM registro em movimentacoes vinculado ao GERENTE CORRETO (com coerção para tipo enum/text)
      IF (SELECT count(*) FROM public.movimentacoes WHERE produto_id = v_prod_id AND filial_id = v_filial_id AND tipo::text = 'entrada' AND quantidade = v_qtd AND quantidade_anterior = 0 AND quantidade_nova = v_qtd AND usuario_id = v_gerente_id AND motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1') <> 1 THEN
        v_cnt_movs_invalidas := v_cnt_movs_invalidas + 1;
      END IF;
    END LOOP;
  END LOOP;

  -- H. Conferir Distribuição Exata de 15 Movimentações por Gerente
  SELECT count(*) INTO v_movs_gerente_3 FROM public.movimentacoes WHERE usuario_id = 3 AND motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1';
  SELECT count(*) INTO v_movs_gerente_5 FROM public.movimentacoes WHERE usuario_id = 5 AND motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1';
  SELECT count(*) INTO v_movs_gerente_7 FROM public.movimentacoes WHERE usuario_id = 7 AND motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1';

  IF v_movs_gerente_3 <> 15 OR v_movs_gerente_5 <> 15 OR v_movs_gerente_7 <> 15 THEN
    RAISE EXCEPTION 'FALHA NA DISTRIBUIÇÃO DOS GERENTES: Esperado 15 movimentações por gerente (Obtido -> Gerente 3: %, Gerente 5: %, Gerente 7: %).',
      v_movs_gerente_3, v_movs_gerente_5, v_movs_gerente_7;
  END IF;

  -- I. Checagem Rigorosa de Ausência de Registros Extras
  SELECT count(*) INTO v_cnt_estoques_extras
  FROM public.estoques
  WHERE produto_id IN (SELECT id FROM public.produtos WHERE codigo IN ('01','02','03','04','05','06','07','08','09'));

  SELECT count(*) INTO v_cnt_movs_extras
  FROM public.movimentacoes
  WHERE motivo = 'CARGA_INICIAL_OFFICIAL_1392_V1';

  IF v_cnt_estoques_extras <> 45 OR v_cnt_movs_extras <> 45 THEN
    RAISE EXCEPTION 'FALHA NA ASSERTION DE REGISTROS EXTRAS: Detectados registros duplicados ou extras nos produtos da carga inicial (Estoques: %, Movimentações: %).',
      v_cnt_estoques_extras, v_cnt_movs_extras;
  END IF;

  IF v_cnt_comb_invalidas > 0 OR v_cnt_movs_invalidas > 0 THEN
    RAISE EXCEPTION 'FALHA NA ASSERTION ITEMIZADA DAS 45 COMBINAÇÕES: Combinações ou atribuições de gerente inválidas detectadas.';
  END IF;

  -- J. Validações Globais
  SELECT count(*) INTO v_cnt_prods FROM public.produtos WHERE codigo IN ('01','02','03','04','05','06','07','08','09');
  SELECT COALESCE(sum(quantidade),0) INTO v_sum_unidades FROM public.estoques WHERE produto_id IN (SELECT id FROM public.produtos WHERE codigo IN ('01','02','03','04','05','06','07','08','09'));

  IF v_cnt_prods <> 9 OR v_sum_unidades <> 1392 THEN
    RAISE EXCEPTION 'FALHA NA ASSERTION DE TOTAIS GLOBAIS: Dados persistidos divergem dos totais da matriz oficial.';
  END IF;

  -- K. Registro de Controle de Idempotência
  INSERT INTO public.carga_inicial_controle (identificador_carga, total_unidades, total_combinacoes)
  VALUES ('CARGA_INICIAL_OFFICIAL_1392_V1', 1392, 45);

  RETURN jsonb_build_object(
    'sucesso', true,
    'produtos_criados', v_cnt_prods,
    'estoques_criados', v_cnt_estoques_extras,
    'movimentacoes_criadas', v_cnt_movs_extras,
    'distribuicao_gerentes', jsonb_build_object(
      'gerente_id_3', v_movs_gerente_3,
      'gerente_id_5', v_movs_gerente_5,
      'gerente_id_7', v_movs_gerente_7
    ),
    'total_unidades', v_sum_unidades,
    'mensagem', 'Carga inicial executada e distribuída entre os 3 gerentes com sucesso no banco de dados.'
  );

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'FALHA NA CARGA INICIAL (ROLLBACK EXECUTADO): %', SQLERRM;
END;
$$;

-- Atribuição explícita do proprietário da função RPC para postgres
ALTER FUNCTION public.executar_carga_inicial_estoque_rpc() OWNER TO postgres;

-- Restrição de Autorização e Privilégios Mínimos na RPC
REVOKE ALL ON FUNCTION public.executar_carga_inicial_estoque_rpc() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.executar_carga_inicial_estoque_rpc() FROM anon;
REVOKE ALL ON FUNCTION public.executar_carga_inicial_estoque_rpc() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.executar_carga_inicial_estoque_rpc() TO postgres, service_role;
