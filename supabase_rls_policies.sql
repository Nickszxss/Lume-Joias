-- =====================================================================
-- SCRIPT DE POLÍTICAS RLS (ROW LEVEL SECURITY) E PRIVILÉGIOS — LUME JOIAS
-- Arquitetura: Supabase PostgreSQL (GitHub Pages + Supabase Client)
-- Versão Auditada e Endurecida: P0/P1 Segurança, Vínculo Auth (auth_user_id ↔ auth.uid()) e Privilégios Restritos
-- =====================================================================

BEGIN;

-- 1. Alterações DDL Preventivas na Tabela 'usuarios' e Criar tabela de 'produtos_filiais_inativos'
ALTER TABLE public.usuarios
ADD COLUMN IF NOT EXISTS auth_user_id UUID;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_usuarios_auth_user' AND conrelid = 'public.usuarios'::regclass
    ) THEN
        ALTER TABLE public.usuarios
        ADD CONSTRAINT fk_usuarios_auth_user
        FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_usuarios_auth_user_id' AND conrelid = 'public.usuarios'::regclass
    ) THEN
        ALTER TABLE public.usuarios
        ADD CONSTRAINT uq_usuarios_auth_user_id
        UNIQUE (auth_user_id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.produtos_filiais_inativos (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    produto_id bigint NOT NULL REFERENCES public.produtos(id) ON DELETE CASCADE,
    filial_id bigint NOT NULL REFERENCES public.filiais(id) ON DELETE CASCADE,
    desativado_por bigint REFERENCES public.usuarios(id),
    created_at timestamptz DEFAULT now(),
    CONSTRAINT unique_produto_filial_inativo UNIQUE (produto_id, filial_id)
);

-- Tabela para Armazenamento de Chaves de Idempotência
CREATE TABLE IF NOT EXISTS public.idempotencia_chaves (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    chave text NOT NULL UNIQUE,
    usuario_id bigint REFERENCES public.usuarios(id),
    escopo text NOT NULL,
    parametros_hash text NOT NULL,
    resultado_json json NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Habilitar RLS nas 8 tabelas públicas do sistema + produtos_filiais_inativos + idempotencia_chaves
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.idempotencia_chaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.filiais ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estoques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimentacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transferencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos_compra ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itens_pedido_compra ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produtos_filiais_inativos ENABLE ROW LEVEL SECURITY;

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

-- 2. Funções auxiliares para extrair perfil e filial do usuário autenticado no Supabase Auth via auth.uid()
-- Endurecidas com SECURITY DEFINER, search_path totalmente limpo (SET search_path = '') e checagem estrita de unicidade por auth_user_id.
-- A fonte oficial de autorização utiliza o enum u.tipo::text ('gerente', 'funcionario').
-- Se houver ausência de vínculo (auth.uid() IS NULL / auth_user_id IS NULL), ambiguidade ou se a conta estiver inativa,
-- as funções retornam NULL, assegurando ZERO permissões por padrão nas políticas RLS.
CREATE OR REPLACE FUNCTION public.get_auth_user_cargo()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
  v_auth_uid uuid;
  v_count integer;
  v_cargo text;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.usuarios u
  WHERE u.auth_user_id = v_auth_uid AND u.ativo = true;

  IF v_count <> 1 THEN
    RETURN NULL;
  END IF;

  SELECT LOWER(u.tipo::text) INTO v_cargo
  FROM public.usuarios u
  WHERE u.auth_user_id = v_auth_uid AND u.ativo = true;

  RETURN v_cargo;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_auth_user_filial_id()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
  v_auth_uid uuid;
  v_count integer;
  v_filial_id bigint;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.usuarios u
  WHERE u.auth_user_id = v_auth_uid AND u.ativo = true;

  IF v_count <> 1 THEN
    RETURN NULL;
  END IF;

  SELECT u.filial_id INTO v_filial_id
  FROM public.usuarios u
  WHERE u.auth_user_id = v_auth_uid AND u.ativo = true;

  RETURN v_filial_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_auth_user_id()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
  v_auth_uid uuid;
  v_count integer;
  v_user_id bigint;
BEGIN
  v_auth_uid := auth.uid();
  IF v_auth_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.usuarios u
  WHERE u.auth_user_id = v_auth_uid AND u.ativo = true;

  IF v_count <> 1 THEN
    RETURN NULL;
  END IF;

  SELECT u.id INTO v_user_id
  FROM public.usuarios u
  WHERE u.auth_user_id = v_auth_uid AND u.ativo = true;

  RETURN v_user_id;
END;
$$;

-- Restringir execução de funções SECURITY DEFINER apenas para usuários autenticados
REVOKE EXECUTE ON FUNCTION public.get_auth_user_cargo() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_auth_user_filial_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_auth_user_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_auth_user_cargo() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_auth_user_filial_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_auth_user_id() TO authenticated;

-- 3. Bloco PL/pgSQL Idempotente para remover TODAS as políticas preexistentes nas tabelas
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
            'movimentacoes', 'transferencias', 'pedidos_compra', 'itens_pedido_compra',
            'produtos_filiais_inativos'
          )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
    END LOOP;
END $$;

-- 4. REVOGAÇÃO RIGOROSA DE PRIVILÉGIOS RESIDUAIS SOBRE TABELAS E SEQUÊNCIAS DO PROJETO
REVOKE ALL ON public.usuarios, public.filiais, public.produtos, public.estoques, public.movimentacoes, public.transferencias, public.pedidos_compra, public.itens_pedido_compra, public.produtos_filiais_inativos FROM PUBLIC, anon, authenticated;

-- Permissões estritas EXCLUSIVAMENTE em sequências vinculadas a colunas das 9 tabelas do Lume-Joias
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
            'movimentacoes', 'transferencias', 'pedidos_compra', 'itens_pedido_compra',
            'produtos_filiais_inativos'
          )
    LOOP
        EXECUTE format('REVOKE ALL ON SEQUENCE %I.%I FROM PUBLIC, anon, authenticated', seq.seqschema, seq.seqname);
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %I.%I TO authenticated', seq.seqschema, seq.seqname);
    END LOOP;
END $$;

-- 5. POLÍTICAS E CONCESSÕES DA TABELA 'usuarios' (Sem fallback por e-mail no JWT)
CREATE POLICY "Leitura Usuarios por Perfil" ON public.usuarios
FOR SELECT USING (
  (auth_user_id = auth.uid() AND ativo = true) OR
  (
    public.get_auth_user_cargo() = 'gerente' AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id()
  )
);

CREATE POLICY "Bloqueio Alteracao Cargo Filial Usuarios" ON public.usuarios
FOR UPDATE USING (
  (auth_user_id = auth.uid() AND ativo = true) OR
  (
    public.get_auth_user_cargo() = 'gerente' AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id()
  )
) WITH CHECK (
  (
    auth_user_id = auth.uid() AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id() AND
    tipo::text IS NOT DISTINCT FROM public.get_auth_user_cargo() AND
    ativo = true
  ) OR
  (
    public.get_auth_user_cargo() = 'gerente' AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id() AND
    tipo::text = 'funcionario'
  )
);

-- Permissões por Coluna em 'usuarios' (Omitindo explicitamente a coluna 'senha')
REVOKE SELECT (id, nome, email, senha, cargo, tipo, filial_id, ativo, created_at, auth_user_id) ON public.usuarios FROM PUBLIC, anon, authenticated;
REVOKE UPDATE (id, nome, email, senha, cargo, tipo, filial_id, ativo, created_at, auth_user_id) ON public.usuarios FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, nome, email, cargo, tipo, filial_id, ativo, created_at, auth_user_id) ON public.usuarios TO authenticated;
GRANT UPDATE (nome) ON public.usuarios TO authenticated;

-- 6. POLÍTICAS E CONCESSÕES DAS TABELAS 'filiais', 'produtos' E 'produtos_filiais_inativos'
CREATE POLICY "Leitura Publica Filiais" ON public.filiais FOR SELECT USING (true);
GRANT SELECT ON public.filiais TO anon, authenticated;

CREATE POLICY "Leitura Publica Produtos" ON public.produtos FOR SELECT USING (true);

CREATE POLICY "Insercao Produtos Apenas Gerente" ON public.produtos
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente'
);

CREATE POLICY "Atualizacao Produtos Apenas Gerente" ON public.produtos
FOR UPDATE USING (
  public.get_auth_user_cargo() = 'gerente'
);

GRANT SELECT ON public.produtos TO anon, authenticated;
GRANT INSERT, UPDATE ON public.produtos TO authenticated;

-- Tabela e Políticas para Inativação/Retirada de Uso Local de Produtos por Filial
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

-- Bloquear UPDATE direto na tabela e em todas as colunas de public.estoques
REVOKE ALL ON public.estoques FROM PUBLIC, anon, authenticated;
REVOKE UPDATE (id, filial_id, produto_id, quantidade, status, updated_at) ON public.estoques FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT ON public.estoques TO authenticated;
GRANT SELECT ON public.estoques TO anon;

-- RPC Transacional Atômico para Ajuste de Estoque com Suporte a Idempotência
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
  v_qtd_minima integer;
  v_qtd_ant integer;
  v_qtd_nova integer;
  v_status text;
  v_lock_key bigint;
  v_params_hash text;
  v_idempotent_rec record;
  v_resultado json;
BEGIN
  -- 1. Autenticação e Verificação Estrita de Unicidade de Usuário por auth.uid()
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

  -- Regra P0 de Autorização Estrita: Tanto gerentes quanto funcionários SÓ PODEM alterar o estoque da PRÓPRIA filial.
  IF v_user_filial_id IS NULL OR v_user_filial_id != p_filial_id THEN
    RAISE EXCEPTION 'Acesso negado: Usuario nao possui permissao para ajustar o estoque de outra filial (Filial Alvo: %, Sua Filial: %).', p_filial_id, v_user_filial_id;
  END IF;

  -- Checagem de Idempotência
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key));
    v_params_hash := md5('ajustar_estoque:' || COALESCE(p_produto_id::text, '') || ':' || COALESCE(p_filial_id::text, '') || ':' || COALESCE(p_tipo, '') || ':' || COALESCE(p_quantidade::text, '') || ':' || COALESCE(p_motivo, ''));

    SELECT * INTO v_idempotent_rec
    FROM public.idempotencia_chaves
    WHERE chave = p_idempotency_key;

    IF FOUND THEN
      IF v_idempotent_rec.usuario_id != v_user_id THEN
        RAISE EXCEPTION 'Acesso negado: A chave de idempotencia % pertence a outro usuario.', p_idempotency_key;
      END IF;
      IF v_idempotent_rec.parametros_hash = v_params_hash THEN
        RETURN v_idempotent_rec.resultado_json;
      ELSE
        RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada com parametros diferentes.', p_idempotency_key;
      END IF;
    END IF;
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
  IF p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
    RAISE EXCEPTION 'Operacao negada: Motivo do ajuste de estoque e obrigatorio.';
  END IF;

  -- 3. Validação de Filial e Produto Ativos no Catálogo Global
  SELECT ativa INTO v_filial_ativa FROM public.filiais WHERE id = p_filial_id LIMIT 1;
  IF v_filial_ativa IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: Filial ID % nao encontrada.', p_filial_id;
  END IF;
  IF v_filial_ativa = false THEN
    RAISE EXCEPTION 'Operacao negada: Filial ID % esta inativa.', p_filial_id;
  END IF;

  SELECT ativo, qtd_minima INTO v_prod_ativo, v_qtd_minima FROM public.produtos WHERE id = p_produto_id LIMIT 1;
  IF v_prod_ativo IS NULL THEN
    RAISE EXCEPTION 'Operacao negada: Produto ID % nao encontrado.', p_produto_id;
  END IF;
  IF v_prod_ativo = false THEN
    RAISE EXCEPTION 'Operacao negada: Produto ID % esta inativo e nao pode receber ajustes de estoque.', p_produto_id;
  END IF;

  -- 4. Proteção contra Concorrência em Registros Inexistentes
  v_lock_key := pg_catalog.hashtext(p_filial_id::text || '_' || p_produto_id::text);
  PERFORM pg_catalog.pg_advisory_xact_lock(v_lock_key);

  -- 5. Obter e bloquear linha existente do estoque
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

  -- Calcular status do estoque com base nas 3 regras: zerado, baixo e suficiente
  v_status := CASE
    WHEN v_qtd_nova = 0 THEN 'zerado'
    WHEN v_qtd_nova <= COALESCE(v_qtd_minima, 0) THEN 'baixo'
    ELSE 'suficiente'
  END;

  -- 6. Atualizar ou inserir estoque de forma atômica
  INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
  VALUES (p_filial_id, p_produto_id, v_qtd_nova, v_status::public.status_estoque, now())
  ON CONFLICT (filial_id, produto_id) DO UPDATE
  SET quantidade = EXCLUDED.quantidade,
      status = EXCLUDED.status,
      updated_at = now();

  -- 7. Registrar movimentação auditável na mesma transação
  INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
  VALUES (p_produto_id, p_filial_id, v_user_id, p_tipo, p_quantidade, v_qtd_ant, v_qtd_nova, COALESCE(p_motivo, 'Ajuste manual de estoque'), now());

  v_resultado := json_build_object(
    'success', true,
    'message', 'Estoque ajustado com sucesso.',
    'quantidade_anterior', v_qtd_ant,
    'quantidade_nova', v_qtd_nova
  );

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

-- 8. POLÍTICAS E CONCESSÕES DA TABELA 'movimentacoes'
CREATE POLICY "Leitura Movimentacoes por Perfil" ON public.movimentacoes
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

REVOKE ALL ON public.movimentacoes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.movimentacoes TO authenticated;

-- 9. POLÍTICAS E CONCESSÕES DA TABELA 'transferencias' E RPC ATÔMICO
CREATE POLICY "Leitura Transferencias por Perfil" ON public.transferencias
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  origem_id = public.get_auth_user_filial_id() OR
  destino_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Insercao Transferencias por Perfil" ON public.transferencias
FOR INSERT WITH CHECK (
  (
    public.get_auth_user_cargo() = 'gerente' OR
    origem_id = public.get_auth_user_filial_id()
  ) AND
  origem_id != destino_id AND
  quantidade > 0 AND
  status::text = 'solicitada' AND
  usuario_id = public.get_auth_user_id()
);

GRANT SELECT, INSERT ON public.transferencias TO authenticated;
REVOKE UPDATE ON public.transferencias FROM PUBLIC, anon, authenticated;

-- RPC Transacional Atômico para Conclusão de Transferência
DROP FUNCTION IF EXISTS public.concluir_transferencia_rpc(bigint, text);
DROP FUNCTION IF EXISTS public.concluir_transferencia_rpc(bigint, text, text);
CREATE OR REPLACE FUNCTION public.concluir_transferencia_rpc(
  p_transferencia_id bigint,
  p_observacao text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_transf record;
  v_auth_uid uuid;
  v_user_count integer;
  v_user_id bigint;
  v_user_cargo text;
  v_user_filial_id bigint;
  v_prod_qtd_minima integer;
  v_origem_qtd_ant integer;
  v_origem_qtd_nova integer;
  v_origem_status text;
  v_dest_qtd_ant integer;
  v_dest_qtd_nova integer;
  v_dest_status text;
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

  -- Checagem de Idempotência
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key));
    v_params_hash := md5('concluir_transferencia:' || COALESCE(p_transferencia_id::text, '') || ':' || COALESCE(p_observacao, ''));

    SELECT * INTO v_idempotent_rec
    FROM public.idempotencia_chaves
    WHERE chave = p_idempotency_key;

    IF FOUND THEN
      IF v_idempotent_rec.usuario_id != v_user_id THEN
        RAISE EXCEPTION 'Acesso negado: A chave de idempotencia % pertence a outro usuario.', p_idempotency_key;
      END IF;
      IF v_idempotent_rec.parametros_hash = v_params_hash THEN
        RETURN v_idempotent_rec.resultado_json;
      ELSE
        RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada com parametros diferentes.', p_idempotency_key;
      END IF;
    END IF;
  END IF;

  -- 1. Bloquear linha da transferencia com SELECT FOR UPDATE
  SELECT * INTO v_transf
  FROM public.transferencias
  WHERE id = p_transferencia_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transferencia ID % nao encontrada.', p_transferencia_id;
  END IF;

  IF v_transf.status::text = 'concluida' THEN
    RAISE EXCEPTION 'Operacao negada: Transferencia ID % ja foi concluida anteriormente em %.', p_transferencia_id, v_transf.concluida_at;
  END IF;

  IF v_transf.status::text = 'cancelada' THEN
    RAISE EXCEPTION 'Operacao negada: Transferencia ID % esta cancelada.', p_transferencia_id;
  END IF;

  IF v_transf.status::text != 'solicitada' THEN
    RAISE EXCEPTION 'Operacao negada: Transferencia ID % possui status invalido (%) para conclusao.', p_transferencia_id, v_transf.status;
  END IF;

  IF v_transf.origem_id = v_transf.destino_id THEN
    RAISE EXCEPTION 'Operacao negada: Transferencia ID % possui origem e destino identicos (Filial ID %).', p_transferencia_id, v_transf.origem_id;
  END IF;

  IF v_transf.quantidade <= 0 THEN
    RAISE EXCEPTION 'Operacao negada: Quantidade da transferencia invalida (%).', v_transf.quantidade;
  END IF;

  IF v_user_cargo != 'gerente' AND (v_user_filial_id IS NULL OR v_user_filial_id != v_transf.destino_id) THEN
    RAISE EXCEPTION 'Acesso negado: Somente gerentes ou funcionarios da filial de destino podem concluir a transferencia.';
  END IF;

  -- Obter qtd_minima do produto
  SELECT qtd_minima INTO v_prod_qtd_minima FROM public.produtos WHERE id = v_transf.produto_id LIMIT 1;

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
  v_origem_status := CASE
    WHEN v_origem_qtd_nova = 0 THEN 'zerado'
    WHEN v_origem_qtd_nova <= COALESCE(v_prod_qtd_minima, 0) THEN 'baixo'
    ELSE 'suficiente'
  END;

  -- 4. Bloquear e calcular estoque do destino
  SELECT COALESCE(
    (SELECT quantidade FROM public.estoques WHERE filial_id = v_transf.destino_id AND produto_id = v_transf.produto_id FOR UPDATE),
    0
  ) INTO v_dest_qtd_ant;

  v_dest_qtd_nova := v_dest_qtd_ant + v_transf.quantidade;
  v_dest_status := CASE
    WHEN v_dest_qtd_nova = 0 THEN 'zerado'
    WHEN v_dest_qtd_nova <= COALESCE(v_prod_qtd_minima, 0) THEN 'baixo'
    ELSE 'suficiente'
  END;

  -- 5. Atualizar estoque da origem com status padronizado
  UPDATE public.estoques
  SET quantidade = v_origem_qtd_nova,
      status = v_origem_status::public.status_estoque,
      updated_at = now()
  WHERE filial_id = v_transf.origem_id AND produto_id = v_transf.produto_id;

  -- 6. Atualizar/Inserir estoque do destino com status padronizado
  INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
  VALUES (v_transf.destino_id, v_transf.produto_id, v_dest_qtd_nova, v_dest_status::public.status_estoque, now())
  ON CONFLICT (filial_id, produto_id) DO UPDATE
  SET quantidade = EXCLUDED.quantidade,
      status = EXCLUDED.status,
      updated_at = now();

  -- 7. Registrar movimentações auditáveis com saldos anteriores e posteriores REAIS
  INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
  VALUES (v_transf.produto_id, v_transf.origem_id, v_user_id, 'saida', v_transf.quantidade, v_origem_qtd_ant, v_origem_qtd_nova, COALESCE(p_observacao, 'Transferencia Concluida (Saida Origem)'), now());

  INSERT INTO public.movimentacoes (produto_id, filial_id, usuario_id, tipo, quantidade, quantidade_anterior, quantidade_nova, motivo, created_at)
  VALUES (v_transf.produto_id, v_transf.destino_id, v_user_id, 'entrada', v_transf.quantidade, v_dest_qtd_ant, v_dest_qtd_nova, COALESCE(p_observacao, 'Transferencia Concluida (Entrada Destino)'), now());

  -- 8. Marcar transferencia como concluida
  UPDATE public.transferencias
  SET status = 'concluida',
      observacao = COALESCE(p_observacao, observacao),
      concluida_at = now()
  WHERE id = p_transferencia_id;

  v_resultado := json_build_object('success', true, 'message', 'Transferencia concluida com sucesso.', 'transferencia_id', p_transferencia_id);

  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    INSERT INTO public.idempotencia_chaves (chave, usuario_id, escopo, parametros_hash, resultado_json)
    VALUES (p_idempotency_key, v_user_id, 'concluir_transferencia', v_params_hash, v_resultado)
    ON CONFLICT (chave) DO NOTHING;
  END IF;

  RETURN v_resultado;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.concluir_transferencia_rpc(bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.concluir_transferencia_rpc(bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.concluir_transferencia_rpc(bigint, text, text) TO authenticated;

-- 10. POLÍTICAS E CONCESSÕES DAS TABELAS 'pedidos_compra' E 'itens_pedido_compra' E RPC ATÔMICO
CREATE POLICY "Leitura Pedidos Compra por Perfil" ON public.pedidos_compra
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Insercao Pedidos Compra Apenas Gerente" ON public.pedidos_compra
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente' AND
  status::text = 'aberto' AND
  usuario_id = public.get_auth_user_id()
);

GRANT SELECT, INSERT ON public.pedidos_compra TO authenticated;
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
  public.get_auth_user_cargo() = 'gerente' AND
  quantidade > 0 AND
  EXISTS (
    SELECT 1 FROM public.pedidos_compra p
    WHERE p.id = itens_pedido_compra.pedido_id
      AND p.status::text = 'aberto'
      AND (
        public.get_auth_user_cargo() = 'gerente' OR
        p.filial_id = public.get_auth_user_filial_id()
      )
  )
);

GRANT SELECT, INSERT ON public.itens_pedido_compra TO authenticated;

-- RPC Transacional Atômico para Recebimento de Pedido de Compra
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
  v_prod_qtd_minima integer;
  v_dest_qtd_ant integer;
  v_dest_qtd_nova integer;
  v_dest_status text;
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

  -- Checagem de Idempotência
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key));
    v_params_hash := md5('receber_pedido:' || COALESCE(p_pedido_id::text, '') || ':' || COALESCE(p_observacao, ''));

    SELECT * INTO v_idempotent_rec
    FROM public.idempotencia_chaves
    WHERE chave = p_idempotency_key;

    IF FOUND THEN
      IF v_idempotent_rec.usuario_id != v_user_id THEN
        RAISE EXCEPTION 'Acesso negado: A chave de idempotencia % pertence a outro usuario.', p_idempotency_key;
      END IF;
      IF v_idempotent_rec.parametros_hash = v_params_hash THEN
        RETURN v_idempotent_rec.resultado_json;
      ELSE
        RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada com parametros diferentes.', p_idempotency_key;
      END IF;
    END IF;
  END IF;

  -- 1. Bloquear linha do pedido com SELECT FOR UPDATE
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

  IF v_user_filial_id IS NULL OR v_user_filial_id != v_pedido.filial_id THEN
    RAISE EXCEPTION 'Acesso negado: Usuario nao possui permissao para receber pedidos de outra filial (Filial do Pedido: %, Sua Filial: %).', v_pedido.filial_id, v_user_filial_id;
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
    SELECT * FROM public.itens_pedido_compra WHERE pedido_id = p_pedido_id ORDER BY produto_id ASC
  LOOP
    IF v_item.quantidade <= 0 THEN
      RAISE EXCEPTION 'Operacao negada: Item ID % possui quantidade invalida (%).', v_item.id, v_item.quantidade;
    END IF;

    SELECT qtd_minima INTO v_prod_qtd_minima FROM public.produtos WHERE id = v_item.produto_id LIMIT 1;

    -- Advisory Lock transacional por chave de produto/filial
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_pedido.filial_id::text || '_' || v_item.produto_id::text));

    -- Obter e bloquear estoque anterior
    SELECT COALESCE(
      (SELECT quantidade FROM public.estoques WHERE filial_id = v_pedido.filial_id AND produto_id = v_item.produto_id FOR UPDATE),
      0
    ) INTO v_dest_qtd_ant;

    v_dest_qtd_nova := v_dest_qtd_ant + v_item.quantidade;
    v_dest_status := CASE
      WHEN v_dest_qtd_nova = 0 THEN 'zerado'
      WHEN v_dest_qtd_nova <= COALESCE(v_prod_qtd_minima, 0) THEN 'baixo'
      ELSE 'suficiente'
    END;

    -- Incrementar estoque com status padronizado
    INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
    VALUES (v_pedido.filial_id, v_item.produto_id, v_dest_qtd_nova, v_dest_status::public.status_estoque, now())
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

  v_resultado := json_build_object('success', true, 'message', 'Pedido de compra recebido com sucesso.', 'pedido_id', p_pedido_id);

  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    INSERT INTO public.idempotencia_chaves (chave, usuario_id, escopo, parametros_hash, resultado_json)
    VALUES (p_idempotency_key, v_user_id, 'receber_pedido', v_params_hash, v_resultado)
    ON CONFLICT (chave) DO NOTHING;
  END IF;

  RETURN v_resultado;
END;
$$;

-- RPC Transacional Atômico para Criação de Pedido de Compra com Itens e Idempotência
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
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key));
    v_params_hash := md5('criar_pedido:' || COALESCE(p_filial_id::text, '') || ':' || COALESCE(p_produto_id::text, '') || ':' || COALESCE(p_quantidade::text, ''));

    SELECT * INTO v_idempotent_rec
    FROM public.idempotencia_chaves
    WHERE chave = p_idempotency_key;

    IF FOUND THEN
      IF v_idempotent_rec.parametros_hash = v_params_hash THEN
        RETURN v_idempotent_rec.resultado_json;
      ELSE
        RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada com parametros diferentes.', p_idempotency_key;
      END IF;
    END IF;
  END IF;

  -- Inserir o pedido de compra (cabeçalho)
  INSERT INTO public.pedidos_compra (filial_id, usuario_id, status, created_at)
  VALUES (p_filial_id, v_user_id, 'aberto', now())
  RETURNING id INTO v_pedido_id;

  -- Inserir o item do pedido
  INSERT INTO public.itens_pedido_compra (pedido_id, produto_id, quantidade, created_at)
  VALUES (v_pedido_id, p_produto_id, p_quantidade, now());

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

-- RPC Transacional Atômico para Cadastrar Produto e Criar Estoque Inicial em 5 Filiais
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
  IF p_qtd_minima IS NULL OR p_qtd_minima < 0 THEN
    RAISE EXCEPTION 'Operacao negada: Quantidade minima deve ser um inteiro maior ou igual a zero.';
  END IF;

  -- Checagem de Idempotência
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key));
    v_params_hash := md5('cadastrar_produto:' || TRIM(p_nome) || ':' || TRIM(p_sku) || ':' || COALESCE(p_categoria, 'Geral') || ':' || p_qtd_minima::text);

    SELECT * INTO v_idempotent_rec
    FROM public.idempotencia_chaves
    WHERE chave = p_idempotency_key;

    IF FOUND THEN
      IF v_idempotent_rec.parametros_hash = v_params_hash THEN
        RETURN v_idempotent_rec.resultado_json;
      ELSE
        RAISE EXCEPTION 'Operacao negada: A chave de idempotencia % ja foi utilizada com parametros diferentes.', p_idempotency_key;
      END IF;
    END IF;
  END IF;

  -- Verificar se exatamente as 5 filiais oficiais (IDs 1 a 5) existem
  SELECT count(*) INTO v_filial_count
  FROM public.filiais
  WHERE id IN (1, 2, 3, 4, 5);

  IF v_filial_count < 5 THEN
    RAISE EXCEPTION 'Operacao negada: Filiais oficiais (1 a 5) nao foram encontradas no sistema.';
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
      VALUES (TRIM(p_nome), TRIM(p_sku), v_cat_derivada, p_qtd_minima, 'unidade', true, now())
      RETURNING id INTO v_prod_id;
    EXCEPTION
      WHEN unique_violation THEN
        RAISE EXCEPTION 'Nao foi possivel cadastrar o produto porque o codigo/SKU % ja esta em uso.', TRIM(p_sku);
    END;
  END;

  -- Criar exatamente 1 registro de estoque inicial (quantidade = 0) para cada uma das 5 filiais oficiais
  FOR v_filial_rec IN
    SELECT id FROM public.filiais WHERE id IN (1, 2, 3, 4, 5) ORDER BY id ASC
  LOOP
    INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)
    VALUES (v_filial_rec.id, v_prod_id, 0, 'zerado'::public.status_estoque, now());
  END LOOP;

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

REVOKE EXECUTE ON FUNCTION public.criar_pedido_compra_rpc(bigint, bigint, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.criar_pedido_compra_rpc(bigint, bigint, integer, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.ajustar_estoque_rpc(bigint, bigint, text, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajustar_estoque_rpc(bigint, bigint, text, integer, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.concluir_transferencia_rpc(bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.concluir_transferencia_rpc(bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.concluir_transferencia_rpc(bigint, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.receber_pedido_rpc(bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.receber_pedido_rpc(bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.receber_pedido_rpc(bigint, text, text) TO authenticated;

COMMIT;
