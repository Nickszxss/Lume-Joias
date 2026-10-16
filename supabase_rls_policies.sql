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

-- 2. Funções auxiliares para extrair perfil e filial do usuário autenticado no JWT
-- Endurecidas com SECURITY DEFINER e search_path totalmente limpo (SET search_path = '') com qualificações explícitas.
-- Retornam NULL se a identidade no JWT for anônima, inválida ou não encontrada, impedindo concessão de permissões por padrão.
CREATE OR REPLACE FUNCTION public.get_auth_user_cargo()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT u.cargo FROM public.usuarios u WHERE u.email = (auth.jwt() ->> 'email') LIMIT 1;
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

-- 4. REVOGAÇÃO DE PRIVILÉGIOS RESIDUAIS SOBRE AS 8 TABELAS OPERACIONAIS E SEQUÊNCIAS
REVOKE ALL ON public.usuarios, public.filiais, public.produtos, public.estoques, public.movimentacoes, public.transferencias, public.pedidos_compra, public.itens_pedido_compra FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon;

-- Permissões de uso em sequências para geração de IDs automáticos
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- 5. POLÍTICAS E CONCESSÕES DA TABELA 'usuarios'
CREATE POLICY "Leitura Usuarios por Perfil" ON public.usuarios
FOR SELECT USING (
  email = (auth.jwt() ->> 'email') OR
  (
    public.get_auth_user_cargo() = 'gerente' AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id()
  )
);

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
    cargo IS NOT DISTINCT FROM public.get_auth_user_cargo() AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id() AND
    tipo IS NOT DISTINCT FROM public.get_auth_user_cargo()
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

CREATE POLICY "Escrita Estoques por Perfil" ON public.estoques
FOR ALL USING (
  public.get_auth_user_cargo() = 'gerente' OR
  filial_id = public.get_auth_user_filial_id()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.estoques TO authenticated;

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

-- 9. POLÍTICAS E CONCESSÕES DA TABELA 'transferencias'
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

GRANT SELECT, INSERT, UPDATE ON public.transferencias TO authenticated;

-- 10. POLÍTICAS E CONCESSÕES DAS TABELAS 'pedidos_compra' E 'itens_pedido_compra'
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

GRANT SELECT, INSERT, UPDATE ON public.pedidos_compra TO authenticated;

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
