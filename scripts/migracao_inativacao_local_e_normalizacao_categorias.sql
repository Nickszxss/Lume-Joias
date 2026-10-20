-- =====================================================================
-- MIGRAÇÃO DEDICADA — INATIVAÇÃO LOCAL E NORMALIZAÇÃO DE CATEGORIAS
-- Projeto: Lume-Joias
-- Objetivo: Garantir a tabela de inativação por filial (produtos_filiais_inativos)
--           e a normalização atômica de categorias 'Geral' para as 5 categorias oficiais
--           (ANEL, PULSEIRA, SOLITARIA, COLAR, BRINCO) com base no nome do produto.
-- Local de execução: Supabase Dashboard -> SQL Editor.
-- =====================================================================

BEGIN;

-- 1. Estrutura e Tabela de Inativação Local por Filial
CREATE TABLE IF NOT EXISTS public.produtos_filiais_inativos (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    produto_id bigint NOT NULL REFERENCES public.produtos(id) ON DELETE CASCADE,
    filial_id bigint NOT NULL REFERENCES public.filiais(id) ON DELETE CASCADE,
    desativado_por bigint REFERENCES public.usuarios(id),
    created_at timestamptz DEFAULT now(),
    CONSTRAINT unique_produto_filial_inativo UNIQUE (produto_id, filial_id)
);

ALTER TABLE public.produtos_filiais_inativos ENABLE ROW LEVEL SECURITY;

-- Politicas RLS para produtos_filiais_inativos
DROP POLICY IF EXISTS "Leitura Inativos Estrita por Filial" ON public.produtos_filiais_inativos;
DROP POLICY IF EXISTS "Insercao Inativos Apenas Gerente Filial" ON public.produtos_filiais_inativos;
DROP POLICY IF EXISTS "Exclusao Inativos Apenas Gerente Filial" ON public.produtos_filiais_inativos;

CREATE POLICY "Leitura Inativos Estrita por Filial" ON public.produtos_filiais_inativos
FOR SELECT USING (
  filial_id = public.get_auth_user_filial_id() OR public.get_auth_user_cargo() = 'gerente'
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

-- 2. Normalização Atômica de Categorias 'Geral' em public.produtos
UPDATE public.produtos
SET descricao = CASE
    WHEN LOWER(nome) LIKE '%anel%' THEN 'ANEL'
    WHEN LOWER(nome) LIKE '%pulseira%' THEN 'PULSEIRA'
    WHEN LOWER(nome) LIKE '%solitária%' OR LOWER(nome) LIKE '%solitaria%' THEN 'SOLITARIA'
    WHEN LOWER(nome) LIKE '%colar%' THEN 'COLAR'
    WHEN LOWER(nome) LIKE '%brinco%' THEN 'BRINCO'
    ELSE descricao
  END
WHERE descricao IS NULL OR descricao = 'Geral' OR descricao = '';

COMMIT;
