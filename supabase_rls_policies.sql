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
CREATE OR REPLACE FUNCTION public.get_auth_user_cargo()
RETURNS text AS $$
  SELECT COALESCE(
    (SELECT cargo FROM public.usuarios WHERE email = auth.jwt() ->> 'email' LIMIT 1),
    'funcionario'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_auth_user_filial_id()
RETURNS bigint AS $$
  SELECT filial_id FROM public.usuarios WHERE email = auth.jwt() ->> 'email' LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 3. Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Acesso Leitura Usuarios" ON public.usuarios;
DROP POLICY IF EXISTS "Bloqueio Alteracao Cargo Filial Usuarios" ON public.usuarios;

DROP POLICY IF EXISTS "Leitura Publica Filiais" ON public.filiais;
DROP POLICY IF EXISTS "Leitura Publica Produtos" ON public.produtos;

DROP POLICY IF EXISTS "Leitura Estoques por Perfil" ON public.estoques;
DROP POLICY IF EXISTS "Escrita Estoques por Perfil" ON public.estoques;

DROP POLICY IF EXISTS "Leitura Movimentacoes por Perfil" ON public.movimentacoes;
DROP POLICY IF EXISTS "Insercao Movimentacoes por Perfil" ON public.movimentacoes;

DROP POLICY IF EXISTS "Leitura Transferencias por Perfil" ON public.transferencias;
DROP POLICY IF EXISTS "Insercao Transferencias por Perfil" ON public.transferencias;

DROP POLICY IF EXISTS "Leitura Pedidos Compra por Perfil" ON public.pedidos_compra;
DROP POLICY IF EXISTS "Insercao Pedidos Compra Apenas Gerente" ON public.pedidos_compra;

DROP POLICY IF EXISTS "Leitura Itens Pedido Compra" ON public.itens_pedido_compra;
DROP POLICY IF EXISTS "Insercao Itens Pedido Compra Apenas Gerente" ON public.itens_pedido_compra;

-- 4. POLÍTICAS DA TABELA 'usuarios'
CREATE POLICY "Acesso Leitura Usuarios" ON public.usuarios
FOR SELECT USING (true);

CREATE POLICY "Bloqueio Alteracao Cargo Filial Usuarios" ON public.usuarios
FOR UPDATE USING (
  public.get_auth_user_cargo() = 'gerente' OR id = (
    SELECT id FROM public.usuarios WHERE email = auth.jwt() ->> 'email' LIMIT 1
  )
) WITH CHECK (
  public.get_auth_user_cargo() = 'gerente' OR (
    cargo = public.get_auth_user_cargo() AND
    filial_id IS NOT DISTINCT FROM public.get_auth_user_filial_id()
  )
);

-- 5. POLÍTICAS DAS TABELAS 'filiais' E 'produtos'
CREATE POLICY "Leitura Publica Filiais" ON public.filiais FOR SELECT USING (true);
CREATE POLICY "Leitura Publica Produtos" ON public.produtos FOR SELECT USING (true);

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

CREATE POLICY "Leitura Itens Pedido Compra" ON public.itens_pedido_compra
FOR SELECT USING (true);

CREATE POLICY "Insercao Itens Pedido Compra Apenas Gerente" ON public.itens_pedido_compra
FOR INSERT WITH CHECK (
  public.get_auth_user_cargo() = 'gerente'
);
