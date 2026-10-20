-- MIGRAÇÃO PRÉVIA OBRIGATÓRIA — LUME-JOIAS
-- Local de execução: Supabase Dashboard > SQL Editor.
-- Efeito: altera apenas o tipo enum usado por public.estoques.status.
-- Execute este arquivo sozinho, confirme sucesso/commit e só então execute
-- supabase_rls_policies_corrigido.sql em uma consulta separada.
-- Não combina esta instrução com o arquivo principal: o valor novo do enum
-- precisa estar confirmado antes de funções/triggers o utilizarem.

ALTER TYPE public.status_estoque ADD VALUE IF NOT EXISTS 'suficiente+';
