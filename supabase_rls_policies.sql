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

-- 7. POLÍTICAS E CONCESSÕES DA TABELA 'estoques'
CREATE POLICY "Leitura Estoques por Perfil" ON public.estoques
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Insercao Estoques por Perfil" ON public.estoques
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Atualizacao Estoques por Perfil" ON public.estoques
FOR UPDATE USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
) WITH CHECK (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

GRANT SELECT, INSERT, UPDATE ON public.estoques TO authenticated;

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

  -- 2. Validar e bloquear estoque da origem (SELECT FOR UPDATE)
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

  -- 3. Bloquear e calcular estoque do destino
  SELECT COALESCE(
    (SELECT quantidade FROM public.estoques WHERE filial_id = v_transf.destino_id AND produto_id = v_transf.produto_id FOR UPDATE),
    0
  ) INTO v_dest_qtd_ant;

  v_dest_qtd_nova := v_dest_qtd_ant + v_transf.quantidade;

  -- 4. Atualizar estoque da origem
  UPDATE public.estoques
  SET quantidade = v_origem_qtd_nova, updated_at = now()
  WHERE filial_id = v_transf.origem_id AND produto_id = v_transf.produto_id;

  -- 5. Atualizar/Inserir estoque do destino
  INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
  VALUES (v_transf.destino_id, v_transf.produto_id, v_transf.quantidade, 'Disponivel', now())
  ON CONFLICT (filial_id, produto_id) DO UPDATE
  SET quantidade = public.estoques.quantidade + EXCLUDED.quantidade,
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
