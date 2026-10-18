-- =====================================================================
-- SCRIPT DE POLÍTICAS RLS (ROW LEVEL SECURITY) E PRIVILÉGIOS — LUME JOIAS
-- Arquitetura: Supabase PostgreSQL (GitHub Pages + Supabase Client)
-- =====================================================================

-- 1. Habilitar RLS nas 8 tabelas públicas do sistema
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.filiais ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estoques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimentacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transferencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos_compra ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itens_pedido_compra ENABLE ROW LEVEL SECURITY;

-- Constraint de Integridade do Banco: Validação preventiva estrita com interrupção por RAISE EXCEPTION se houver saldos negativos
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

-- 2. Funções auxiliares para extrair perfil e filial do usuário autenticado no JWT
-- Endurecidas com SECURITY DEFINER e search_path totalmente limpo (SET search_path = '') com qualificações explícitas.
-- Retornam NULL se a identidade no JWT for anônima, inválida, não encontrada ou se o usuário estiver INATIVO (u.ativo = true),
-- garantindo que usuários inativos ou não reconhecidos obtenham ZERO permissões por padrão nas políticas RLS.
CREATE OR REPLACE FUNCTION public.get_auth_user_cargo()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT u.cargo
  FROM public.usuarios u
  WHERE u.email = (auth.jwt() ->> 'email')
    AND u.ativo = true
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_auth_user_filial_id()
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT u.filial_id
  FROM public.usuarios u
  WHERE u.email = (auth.jwt() ->> 'email')
    AND u.ativo = true
  LIMIT 1;
$$;

-- Restringir execução de funções SECURITY DEFINER apenas para usuários autenticados
REVOKE EXECUTE ON FUNCTION public.get_auth_user_cargo() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_auth_user_filial_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_auth_user_cargo() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_auth_user_filial_id() TO authenticated;

-- 3. Bloco PL/pgSQL Idempotente para remover TODAS as políticas preexistentes nas 8 tabelas
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename IN (
            'usuarios', 'filiais', 'produtos', 'estoques',
            'movimentacoes', 'transferencias', 'pedidos_compra', 'itens_pedido_compra'
          )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
    END LOOP;
END $$;

-- Bloco PL/pgSQL Idempotente para remover TODAS as políticas preexistentes de public.usuarios
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'usuarios'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.usuarios', pol.policyname);
    END LOOP;
END $$;

-- 4. REVOGAÇÃO RIGOROSA DE PRIVILÉGIOS RESIDUAIS SOBRE TABELAS E SEQUÊNCIAS
REVOKE ALL ON public.usuarios, public.filiais, public.produtos, public.estoques, public.movimentacoes, public.transferencias, public.pedidos_compra, public.itens_pedido_compra FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon, authenticated;

-- Permissões estritas em sequências vinculadas explicitamente a colunas (refobjsubid > 0 e deptype 'a'/'i') das 8 tabelas do Lume-Joias
DO $$
DECLARE
    seq RECORD;
BEGIN
    FOR seq IN
        SELECT DISTINCT
            sn.nspname AS seqschema,
            s.relname AS seqname
        FROM pg_class s
        JOIN pg_namespace sn ON sn.oid = s.relnamespace
        JOIN pg_depend d ON d.objid = s.oid
        JOIN pg_class t ON t.oid = d.refobjid
        JOIN pg_namespace tn ON tn.oid = t.relnamespace
        WHERE s.relkind = 'S'
          AND d.deptype IN ('a', 'i')
          AND d.refobjsubid > 0
          AND tn.nspname = 'public'
          AND t.relname IN (
            'usuarios', 'filiais', 'produtos', 'estoques',
            'movimentacoes', 'transferencias', 'pedidos_compra', 'itens_pedido_compra'
          )
    LOOP
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %I.%I TO authenticated', seq.seqschema, seq.seqname);
    END LOOP;
END $$;

-- 5. POLÍTICAS E CONCESSÕES DA TABELA 'usuarios'
CREATE POLICY "Leitura Usuarios por Perfil" ON public.usuarios
FOR SELECT USING (
  (email = (auth.jwt() ->> 'email') AND ativo = true) OR
  (
    public.get_auth_user_cargo() = 'gerente' AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id()
  )
);

CREATE POLICY "Bloqueio Alteracao Cargo Filial Usuarios" ON public.usuarios
FOR UPDATE USING (
  (email = (auth.jwt() ->> 'email') AND ativo = true) OR
  (
    public.get_auth_user_cargo() = 'gerente' AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id()
  )
) WITH CHECK (
  (
    email = (auth.jwt() ->> 'email') AND
    cargo IS NOT DISTINCT FROM public.get_auth_user_cargo() AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id() AND
    tipo IS NOT DISTINCT FROM public.get_auth_user_cargo() AND
    ativo = true
  ) OR
  (
    public.get_auth_user_cargo() = 'gerente' AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id() AND
    cargo = 'funcionario' AND
    tipo = 'funcionario'
  )
);

-- Permissões por Coluna em 'usuarios' (Omitindo explicitamente a coluna 'senha')
REVOKE SELECT (id, nome, email, senha, cargo, tipo, filial_id, ativo, created_at) ON public.usuarios FROM PUBLIC, anon, authenticated;
REVOKE UPDATE (id, nome, email, senha, cargo, tipo, filial_id, ativo, created_at) ON public.usuarios FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, nome, email, cargo, tipo, filial_id, ativo, created_at) ON public.usuarios TO authenticated;
GRANT UPDATE (nome) ON public.usuarios TO authenticated;

-- 6. POLÍTICAS E CONCESSÕES DAS TABELAS 'filiais' E 'produtos'
CREATE POLICY "Leitura Publica Filiais" ON public.filiais FOR SELECT USING (true);
GRANT SELECT ON public.filiais TO anon, authenticated;

CREATE POLICY "Leitura Publica Produtos" ON public.produtos FOR SELECT USING (true);

CREATE POLICY "Insercao Produtos por Autenticado" ON public.produtos
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Atualizacao Produtos Apenas Gerente" ON public.produtos
FOR UPDATE USING (
  public.get_auth_user_cargo() = 'gerente'
);

GRANT SELECT ON public.produtos TO anon, authenticated;
GRANT INSERT, UPDATE ON public.produtos TO authenticated;

-- Tabela e Políticas para Inativação/Retirada de Uso Local de Produtos por Filial
CREATE TABLE IF NOT EXISTS public.produtos_filiais_inativos (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    produto_id bigint NOT NULL REFERENCES public.produtos(id) ON DELETE CASCADE,
    filial_id bigint NOT NULL REFERENCES public.filiais(id) ON DELETE CASCADE,
    desativado_por bigint REFERENCES public.usuarios(id),
    created_at timestamptz DEFAULT now(),
    CONSTRAINT unique_produto_filial_inativo UNIQUE (produto_id, filial_id)
);

ALTER TABLE public.produtos_filiais_inativos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Leitura Inativos Estrita por Filial" ON public.produtos_filiais_inativos
FOR SELECT USING (
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Insercao Inativos Apenas Gerente Filial" ON public.produtos_filiais_inativos
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente' AND
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Exclusao Inativos Apenas Gerente Filial" ON public.produtos_filiais_inativos
FOR DELETE USING (
  public.get_auth_user_cargo() = 'gerente' AND
  filial_id = public.get_auth_user_filial_id()
);

GRANT SELECT, INSERT, DELETE ON public.produtos_filiais_inativos TO authenticated;

-- Atualização DML de Produtos Legados ('GERAL'/'Geral') para Categorias Oficiais
-- Atualização DML Condicional e Segura de Produtos Legados para Categorias Oficiais
-- Mapeia estritamente nomes conhecidos de produtos oficiais preservando descrições customizadas de terceiros
DO $$
DECLARE
    v_invalid_count integer;
BEGIN
    UPDATE public.produtos SET descricao = 'COLAR' WHERE nome IN ('Colar de prata', 'Colar de ouro') AND (descricao IS NULL OR descricao IN ('GERAL', 'Geral', ''));
    UPDATE public.produtos SET descricao = 'ANEL' WHERE nome IN ('Anel de prata', 'Anel de ouro') AND (descricao IS NULL OR descricao IN ('GERAL', 'Geral', ''));
    UPDATE public.produtos SET descricao = 'BRINCO' WHERE nome IN ('Brinco de prata', 'Brinco de ouro') AND (descricao IS NULL OR descricao IN ('GERAL', 'Geral', ''));
    UPDATE public.produtos SET descricao = 'SOLITARIA' WHERE nome IN ('Solitária') AND (descricao IS NULL OR descricao IN ('GERAL', 'Geral', ''));
    UPDATE public.produtos SET descricao = 'PULSEIRA' WHERE nome IN ('Pulseira de prata', 'Pulseira de ouro') AND (descricao IS NULL OR descricao IN ('GERAL', 'Geral', ''));

    SELECT count(*) INTO v_invalid_count
    FROM public.produtos
    WHERE descricao IS NULL OR descricao NOT IN ('ANEL', 'PULSEIRA', 'SOLITARIA', 'COLAR', 'BRINCO');

    IF v_invalid_count > 0 THEN
        RAISE EXCEPTION 'MIGRAÇÃO SUSPENSA: Existem % produtos na tabela public.produtos com categoria invalida ou nao reconhecida. Regularize as categorias antes de aplicar a constraint CHECK.', v_invalid_count;
    ELSE
        ALTER TABLE public.produtos DROP CONSTRAINT IF EXISTS produtos_categoria_check;
        ALTER TABLE public.produtos ADD CONSTRAINT produtos_categoria_check
        CHECK (descricao IN ('ANEL', 'PULSEIRA', 'SOLITARIA', 'COLAR', 'BRINCO'));
    END IF;
END $$;

-- 7. POLÍTICAS E CONCESSÕES DA TABELA 'estoques'
CREATE POLICY "Leitura Estoques por Perfil" ON public.estoques
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Insercao Estoques por Perfil" ON public.estoques
FOR INSERT WITH CHECK (
  (
    public.get_auth_user_cargo() = 'gerente' OR
    filial_id = public.get_auth_user_filial_id()
  ) AND
  quantidade = 0
);

CREATE POLICY "Atualizacao Estoques por Perfil" ON public.estoques
FOR UPDATE USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
) WITH CHECK (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

-- Bloquear UPDATE direto na tabela estoques (Alterações de saldo DEVEM obrigatoriamente usar RPCs atômicas)
-- INSERT é mantido estritamente para inicialização de registro com saldo 0 na criação de novos produtos.
REVOKE UPDATE ON public.estoques FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.estoques TO authenticated;

-- RPC Transacional Atômico para Ajuste de Estoque
-- RPC Transacional Atômico para Ajuste de Estoque (Endurecido - P0 Autorização & Concorrência)
-- Proteção estrita por filial, validação de ativos e bloqueio transacional por chave de advisory lock para linhas inexistentes.
CREATE OR REPLACE FUNCTION public.ajustar_estoque_rpc(
  p_produto_id bigint,
  p_filial_id bigint,
  p_tipo text,
  p_quantidade integer,
  p_motivo text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_email text;
  v_user_id bigint;
  v_user_cargo text;
  v_user_filial_id bigint;
  v_filial_ativa boolean;
  v_prod_ativo boolean;
  v_qtd_ant integer;
  v_qtd_nova integer;
  v_lock_key bigint;
BEGIN
  -- 1. Autenticação e Verificação de Usuário
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

  -- Regra P0 de Autorização Estrita: Tanto gerentes quanto funcionários SÓ PODEM alterar o estoque da PRÓPRIA filial.
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

  -- 3. Validação de Filial e Produto Ativos no Catálogo Global
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

  -- 3. Proteção contra Concorrência em Registros Inexistentes (P0 Concorrência)
  -- Bloqueio transacional advisory lock baseado na chave composta (p_filial_id, p_produto_id)
  v_lock_key := pg_catalog.hashtext(p_filial_id::text || '_' || p_produto_id::text);
  PERFORM pg_catalog.pg_advisory_xact_lock(v_lock_key);

  -- 4. Obter e bloquear linha existente do estoque
  SELECT quantidade INTO v_qtd_ant
  FROM public.estoques
  WHERE filial_id = p_filial_id AND produto_id = p_produto_id
  FOR UPDATE;

  IF v_qtd_ant IS NULL THEN
    v_qtd_ant := 0;
  END IF;

  IF p_tipo = 'saida' THEN
    IF v_qtd_ant < p_quantidade THEN
      RAISE EXCEPTION 'Saldo insuficiente na filial para realizar a saida (disponivel: %, solicitado: %).', v_qtd_ant, p_quantidade;
    END IF;
    v_qtd_nova := v_qtd_ant - p_quantidade;
  ELSE
    v_qtd_nova := v_qtd_ant + p_quantidade;
  END IF;

  -- 5. Atualizar ou inserir estoque de forma atômica
  INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
  VALUES (p_filial_id, p_produto_id, v_qtd_nova, CASE WHEN v_qtd_nova = 0 THEN 'zerado' ELSE 'suficiente' END, now())
  ON CONFLICT (filial_id, produto_id) DO UPDATE
  SET quantidade = EXCLUDED.quantidade,
      status = EXCLUDED.status,
      updated_at = now();

  -- 6. Registrar movimentação auditável na mesma transação
  INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
  VALUES (p_produto_id, p_filial_id, v_user_id, p_tipo, p_quantidade, v_qtd_ant, v_qtd_nova, COALESCE(p_motivo, 'Ajuste manual de estoque'), now());

  RETURN json_build_object(
    'success', true,
    'message', 'Estoque ajustado com sucesso.',
    'quantidade_anterior', v_qtd_ant,
    'quantidade_nova', v_qtd_nova
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.ajustar_estoque_rpc(bigint, bigint, text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajustar_estoque_rpc(bigint, bigint, text, integer, text) TO authenticated;

-- 8. POLÍTICAS E CONCESSÕES DA TABELA 'movimentacoes'
CREATE POLICY "Leitura Movimentacoes por Perfil" ON public.movimentacoes
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Insercao Movimentacoes por Perfil" ON public.movimentacoes
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

GRANT SELECT, INSERT ON public.movimentacoes TO authenticated;

-- 9. POLÍTICAS E CONCESSÕES DA TABELA 'transferencias' E RPC ATÔMICO
CREATE POLICY "Leitura Transferencias por Perfil" ON public.transferencias
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  origem_id = public.get_auth_user_filial_id() OR
  destino_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Insercao Transferencias por Perfil" ON public.transferencias
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente' OR
  origem_id = public.get_auth_user_filial_id()
);

GRANT SELECT, INSERT ON public.transferencias TO authenticated;
-- Bloquear UPDATE direto na tabela transferencias (Conclusão DEVE obrigatoriamente usar concluir_transferencia_rpc)
REVOKE UPDATE ON public.transferencias FROM PUBLIC, anon, authenticated;

-- RPC Transacional Atômico para Conclusão de Transferência
-- Valida saldo de origem com SELECT FOR UPDATE, calcula quantidades reais anteriores/posteriores, garante idempotência e rollback integral.
CREATE OR REPLACE FUNCTION public.concluir_transferencia_rpc(
  p_transferencia_id bigint,
  p_observacao text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_transf record;
  v_user_email text;
  v_user_id bigint;
  v_user_cargo text;
  v_user_filial_id bigint;
  v_origem_qtd_ant integer;
  v_origem_qtd_nova integer;
  v_dest_qtd_ant integer;
  v_dest_qtd_nova integer;
BEGIN
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

  -- 1. Bloquear linha da transferencia com SELECT FOR UPDATE
  SELECT * INTO v_transf
  FROM public.transferencias
  WHERE id = p_transferencia_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transferencia ID % nao encontrada.', p_transferencia_id;
  END IF;

  IF v_transf.status = 'concluida' THEN
    RAISE EXCEPTION 'Operacao negada: Transferencia ID % ja foi concluida anteriormente em %.', p_transferencia_id, v_transf.concluida_at;
  END IF;

  IF v_transf.status != 'pendente' THEN
    RAISE EXCEPTION 'Operacao negada: Transferencia ID % possui status invalido (%) para conclusao.', p_transferencia_id, v_transf.status;
  END IF;

  IF v_transf.quantidade <= 0 THEN
    RAISE EXCEPTION 'Operacao negada: Quantidade da transferencia invalida (%).', v_transf.quantidade;
  END IF;

  IF v_user_cargo != 'gerente' AND v_user_filial_id != v_transf.destino_id THEN
    RAISE EXCEPTION 'Acesso negado: Somente gerentes ou funcionarios da filial de destino podem concluir a transferencia.';
  END IF;

  -- 2. Advisory Lock determinístico em ordem de ID de filial para prevenir deadlock entre origem e destino
  IF v_transf.origem_id < v_transf.destino_id THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_transf.origem_id::text || '_' || v_transf.produto_id::text));
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_transf.destino_id::text || '_' || v_transf.produto_id::text));
  ELSE
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_transf.destino_id::text || '_' || v_transf.produto_id::text));
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_transf.origem_id::text || '_' || v_transf.produto_id::text));
  END IF;

  -- 3. Validar e bloquear estoque da origem (SELECT FOR UPDATE)
  SELECT quantidade INTO v_origem_qtd_ant
  FROM public.estoques
  WHERE filial_id = v_transf.origem_id AND produto_id = v_transf.produto_id
  FOR UPDATE;

  IF v_origem_qtd_ant IS NULL THEN
    RAISE EXCEPTION 'Estoque de origem nao encontrado para a filial % e produto %.', v_transf.origem_id, v_transf.produto_id;
  END IF;

  IF v_origem_qtd_ant < v_transf.quantidade THEN
    RAISE EXCEPTION 'Saldo insuficiente em estoque na filial de origem. Saldo atual: %, Solicitado: %.', v_origem_qtd_ant, v_transf.quantidade;
  END IF;

  v_origem_qtd_nova := v_origem_qtd_ant - v_transf.quantidade;

  -- 4. Bloquear e calcular estoque do destino
  SELECT COALESCE(
    (SELECT quantidade FROM public.estoques WHERE filial_id = v_transf.destino_id AND produto_id = v_transf.produto_id FOR UPDATE),
    0
  ) INTO v_dest_qtd_ant;

  v_dest_qtd_nova := v_dest_qtd_ant + v_transf.quantidade;

  -- 5. Atualizar estoque da origem com status padronizado
  UPDATE public.estoques
  SET quantidade = v_origem_qtd_nova,
      status = CASE WHEN v_origem_qtd_nova = 0 THEN 'zerado' ELSE 'suficiente' END,
      updated_at = now()
  WHERE filial_id = v_transf.origem_id AND produto_id = v_transf.produto_id;

  -- 6. Atualizar/Inserir estoque do destino com status padronizado
  INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
  VALUES (v_transf.destino_id, v_transf.produto_id, v_dest_qtd_nova, CASE WHEN v_dest_qtd_nova = 0 THEN 'zerado' ELSE 'suficiente' END, now())
  ON CONFLICT (filial_id, produto_id) DO UPDATE
  SET quantidade = EXCLUDED.quantidade,
      status = EXCLUDED.status,
      updated_at = now();

  -- 6. Registrar movimentações auditáveis com saldos anteriores e posteriores REAIS
  INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
  VALUES (v_transf.produto_id, v_transf.origem_id, v_user_id, 'saida', v_transf.quantidade, v_origem_qtd_ant, v_origem_qtd_nova, COALESCE(p_observacao, 'Transferencia Concluida (Saida Origem)'), now());

  INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
  VALUES (v_transf.produto_id, v_transf.destino_id, v_user_id, 'entrada', v_transf.quantidade, v_dest_qtd_ant, v_dest_qtd_nova, COALESCE(p_observacao, 'Transferencia Concluida (Entrada Destino)'), now());

  -- 7. Marcar transferencia como concluida
  UPDATE public.transferencias
  SET status = 'concluida',
      observacao = COALESCE(p_observacao, observacao),
      concluida_at = now()
  WHERE id = p_transferencia_id;

  RETURN json_build_object('success', true, 'message', 'Transferencia concluida com sucesso.', 'transferencia_id', p_transferencia_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.concluir_transferencia_rpc(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.concluir_transferencia_rpc(bigint, text) TO authenticated;

-- 10. POLÍTICAS E CONCESSÕES DAS TABELAS 'pedidos_compra' E 'itens_pedido_compra' E RPC ATÔMICO
CREATE POLICY "Leitura Pedidos Compra por Perfil" ON public.pedidos_compra
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Insercao Pedidos Compra Apenas Gerente" ON public.pedidos_compra
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente'
);

GRANT SELECT, INSERT ON public.pedidos_compra TO authenticated;
-- Bloquear UPDATE direto na tabela pedidos_compra (Recebimento DEVE obrigatoriamente usar receber_pedido_rpc)
REVOKE UPDATE ON public.pedidos_compra FROM PUBLIC, anon, authenticated;

CREATE POLICY "Leitura Itens Pedido Compra por Perfil" ON public.itens_pedido_compra
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  EXISTS (
    SELECT 1 FROM public.pedidos_compra p
    WHERE p.id = itens_pedido_compra.pedido_id
      AND p.filial_id = public.get_auth_user_filial_id()
  )
);

CREATE POLICY "Insercao Itens Pedido Compra Apenas Gerente" ON public.itens_pedido_compra
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente'
);

GRANT SELECT, INSERT ON public.itens_pedido_compra TO authenticated;

-- RPC Transacional Atômico para Recebimento de Pedido de Compra
-- Rejeita pedidos sem itens, valida quantidades/produtos, calcula saldos anteriores/posteriores reais, garante rollback e idempotência.
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

  -- 1. Bloquear linha do pedido com SELECT FOR UPDATE
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

  -- 2. Validar existencia de itens no pedido
  SELECT count(*) INTO v_items_count
  FROM public.itens_pedido_compra
  WHERE pedido_id = p_pedido_id;

  IF v_items_count = 0 THEN
    RAISE EXCEPTION 'Operacao negada: Pedido de compra ID % nao possui itens vinculados.', p_pedido_id;
  END IF;

  -- 3. Processar cada item
  FOR v_item IN
    SELECT * FROM public.itens_pedido_compra WHERE pedido_id = p_pedido_id
  LOOP
    IF v_item.quantidade <= 0 THEN
      RAISE EXCEPTION 'Operacao negada: Item ID % possui quantidade invalida (%).', v_item.id, v_item.quantidade;
    END IF;

    -- Advisory Lock transacional por chave de produto/filial
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_pedido.filial_id::text || '_' || v_item.produto_id::text));

    -- Obter e bloquear estoque anterior
    SELECT COALESCE(
      (SELECT quantidade FROM public.estoques WHERE filial_id = v_pedido.filial_id AND produto_id = v_item.produto_id FOR UPDATE),
      0
    ) INTO v_dest_qtd_ant;

    v_dest_qtd_nova := v_dest_qtd_ant + v_item.quantidade;

    -- Incrementar estoque com status padronizado
    INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
    VALUES (v_pedido.filial_id, v_item.produto_id, v_dest_qtd_nova, CASE WHEN v_dest_qtd_nova = 0 THEN 'zerado' ELSE 'suficiente' END, now())
    ON CONFLICT (filial_id, produto_id) DO UPDATE
    SET quantidade = EXCLUDED.quantidade,
        status = EXCLUDED.status,
        updated_at = now();

    -- Registrar movimentação auditável com saldos anteriores e posteriores REAIS
    INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
    VALUES (v_item.produto_id, v_pedido.filial_id, v_user_id, 'entrada', v_item.quantidade, v_dest_qtd_ant, v_dest_qtd_nova, COALESCE(p_observacao, 'Recebimento de Pedido de Compra'), now());
  END LOOP;

  -- 4. Marcar pedido como recebido
  UPDATE public.pedidos_compra
  SET status = 'recebido',
      observacao = COALESCE(p_observacao, observacao),
      recebido_at = now()
  WHERE id = p_pedido_id;

  RETURN json_build_object('success', true, 'message', 'Pedido de compra recebido com sucesso.', 'pedido_id', p_pedido_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.receber_pedido_rpc(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.receber_pedido_rpc(bigint, text) TO authenticated;
