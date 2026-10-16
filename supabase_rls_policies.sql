-- =====================================================================
-- SCRIPT DE POLÍTICAS RLS (ROW LEVEL SECURITY) — LUME JOIAS
-- Arquitetura: Supabase PostgreSQL (GitHub Pages + Supabase Client)
-- =====================================================================

-- 1. Habilitar RLS em todas as tabelas públicas
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.filiais ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estoques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimentacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transferencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos_compra ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itens_pedido_compra ENABLE ROW LEVEL SECURITY;

-- 2. Funções auxiliares para extrair perfil e filial do usuário autenticado no JWT
-- Endurecidas com SECURITY DEFINER e search_path totalmente limpo (SET search_path = '') com qualificações explícitas
CREATE OR REPLACE FUNCTION public.get_auth_user_cargo()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT u.cargo FROM public.usuarios u WHERE u.email = (auth.jwt() ->> 'email') LIMIT 1),
    'funcionario'
  );
$$;

CREATE OR REPLACE FUNCTION public.get_auth_user_filial_id()
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT u.filial_id FROM public.usuarios u WHERE u.email = (auth.jwt() ->> 'email') LIMIT 1;
$$;

-- Restringir execução de funções SECURITY DEFINER apenas para usuários autenticados
REVOKE EXECUTE ON FUNCTION public.get_auth_user_cargo() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_auth_user_filial_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_auth_user_cargo() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_auth_user_filial_id() TO authenticated;

-- 3. Remover políticas antigas se existirem
-- 3. Bloco PL/pgSQL Idempotente para remover TODAS as políticas preexistentes nas 8 tabelas do schema public
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

-- 4. POLÍTICAS DA TABELA 'usuarios'
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

-- Política de SELECT: Funcionários veem apenas o próprio perfil. Gerentes veem apenas usuários da própria filial.
CREATE POLICY "Leitura Usuarios por Perfil" ON public.usuarios
FOR SELECT USING (
  email = (auth.jwt() ->> 'email') OR
  (
    public.get_auth_user_cargo() = 'gerente' AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id()
  )
);

-- Política de UPDATE: Garantir que funcionários alterem apenas o próprio nome e gerentes apenas nomes de usuários da própria filial
-- Política de UPDATE: Garantir que funcionários alterem apenas o próprio nome e gerentes apenas nomes de usuários da própria filial sem alterar cargo/filial/ativo
CREATE POLICY "Bloqueio Alteracao Cargo Filial Usuarios" ON public.usuarios
FOR UPDATE USING (
  email = (auth.jwt() ->> 'email') OR
  (
    public.get_auth_user_cargo() = 'gerente' AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id()
  )
) WITH CHECK (
  (
    email = (auth.jwt() ->> 'email') AND
    cargo = public.get_auth_user_cargo() AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id() AND
    tipo = public.get_auth_user_cargo()
  ) OR
  (
    public.get_auth_user_cargo() = 'gerente' AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id() AND
    cargo = 'funcionario'
  )
);

-- Permissões SQL Rígidas (Column-Level Privileges):
-- 1. Revogar privilégios do nível de tabela e de TODAS as colunas para PUBLIC, anon e authenticated
REVOKE ALL ON public.usuarios FROM PUBLIC, anon, authenticated;
REVOKE SELECT ON public.usuarios FROM PUBLIC, anon, authenticated;
REVOKE UPDATE ON public.usuarios FROM PUBLIC, anon, authenticated;
REVOKE SELECT (id, nome, email, senha, cargo, tipo, filial_id, ativo, created_at) ON public.usuarios FROM PUBLIC, anon, authenticated;
REVOKE UPDATE (id, nome, email, senha, cargo, tipo, filial_id, ativo, created_at) ON public.usuarios FROM PUBLIC, anon, authenticated;

-- 2. Conceder SELECT no nível de coluna exclusivamente para authenticated (omitindo explicitamente a coluna 'senha')
GRANT SELECT (id, nome, email, cargo, tipo, filial_id, ativo, created_at) ON public.usuarios TO authenticated;

-- 3. Conceder UPDATE exclusivamente na coluna 'nome' autorizada
GRANT UPDATE (nome) ON public.usuarios TO authenticated;

-- 5. POLÍTICAS DAS TABELAS 'filiais' E 'produtos'
CREATE POLICY "Leitura Publica Filiais" ON public.filiais FOR SELECT USING (true);
CREATE POLICY "Leitura Publica Produtos" ON public.produtos FOR SELECT USING (true);

CREATE POLICY "Atualizacao Produtos Apenas Gerente" ON public.produtos
FOR UPDATE USING (
  public.get_auth_user_cargo() = 'gerente'
);

-- 6. POLÍTICAS DA TABELA 'estoques'
CREATE POLICY "Leitura Estoques por Perfil" ON public.estoques
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Escrita Estoques por Perfil" ON public.estoques
FOR ALL USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

-- 7. POLÍTICAS DA TABELA 'movimentacoes'
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

-- 8. POLÍTICAS DA TABELA 'transferencias'
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

CREATE POLICY "Atualizacao Transferencias por Perfil" ON public.transferencias
FOR UPDATE USING (
  public.get_auth_user_cargo() = 'gerente' OR
  destino_id = public.get_auth_user_filial_id()
);

-- 9. POLÍTICAS DAS TABELAS 'pedidos_compra' E 'itens_pedido_compra'
CREATE POLICY "Leitura Pedidos Compra por Perfil" ON public.pedidos_compra
FOR SELECT USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

CREATE POLICY "Insercao Pedidos Compra Apenas Gerente" ON public.pedidos_compra
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente'
);

CREATE POLICY "Atualizacao Pedidos Compra por Perfil" ON public.pedidos_compra
FOR UPDATE USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

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
