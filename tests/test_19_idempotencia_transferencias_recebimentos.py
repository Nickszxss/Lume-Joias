import re
import pytest

SQL_FILE_PATH = "supabase_rls_policies.sql"
MAIN_JS_FILE_PATH = "main.js"

def load_sql_content():
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def load_main_js_content():
    with open(MAIN_JS_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def test_cenario_a_retentativa_apos_sucesso_concluir_transferencia():
    sql = load_sql_content()
    # Verifica suporte a p_idempotency_key em concluir_transferencia_rpc
    assert "p_idempotency_key text DEFAULT NULL" in sql
    assert "concluir_transferencia:" in sql
    assert "RETURN v_idempotent_rec.resultado_json;" in sql
    # Verifica insercao em idempotencia_chaves ao concluir transferencia
    assert "INSERT INTO public.idempotencia_chaves (chave, usuario_id, escopo, parametros_hash, resultado_json)" in sql

def test_cenario_a_retentativa_apos_sucesso_receber_pedido():
    sql = load_sql_content()
    # Verifica suporte a p_idempotency_key em receber_pedido_rpc
    assert "receber_pedido:" in sql
    assert "INSERT INTO public.idempotencia_chaves" in sql

def test_cenario_b_chave_reutilizada_parametros_diferentes():
    sql = load_sql_content()
    # Verifica rejeicao por parametros_hash diferente em idempotencia
    assert "Operacao negada: A chave de idempotencia % ja foi utilizada com parametros diferentes." in sql
    assert "md5('concluir_transferencia:'" in sql
    assert "md5('receber_pedido:'" in sql

def test_cenario_c_e_d_advisory_locks_e_atomicitatade_rollback():
    sql = load_sql_content()
    # Advisory lock de idempotencia para serializacao concorrente
    assert "pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key))" in sql
    # Manutencao dos advisory locks existentes e SELECT FOR UPDATE
    assert "FOR UPDATE" in sql

def test_cenario_e_chave_outro_usuario_rejeicao():
    sql = load_sql_content()
    # Verifica protecao contra sequestro de respostas de outro usuario
    assert ("IF v_idempotent_rec.usuario_id != v_user_id THEN" in sql or "IF v_idempotent_rec.usuario_id IS DISTINCT FROM v_user_id THEN" in sql)
    assert "Acesso negado: A chave de idempotencia % pertence a outro usuario." in sql

def test_validacao_5_escopos_canonicos_e_propriedade():
    sql = load_sql_content()
    # Verifica escopos canonicos nas 5 RPCs
    assert "IF v_idempotent_rec.escopo IS DISTINCT FROM 'ajustar_estoque' THEN" in sql
    assert "IF v_idempotent_rec.escopo IS DISTINCT FROM 'concluir_transferencia' THEN" in sql
    assert "IF v_idempotent_rec.escopo IS DISTINCT FROM 'receber_pedido' THEN" in sql
    assert "IF v_idempotent_rec.escopo IS DISTINCT FROM 'criar_pedido' THEN" in sql
    assert "IF v_idempotent_rec.escopo IS DISTINCT FROM 'cadastrar_produto' THEN" in sql

def test_cenario_f_frontend_keys_map_e_retentativa():
    js = load_main_js_content()
    # Verifica gerenciamento de chaves no frontend por ID do item
    assert "concluirTransfKeysMap" in js
    assert "receberPedidoKeysMap" in js
    assert "p_idempotency_key: idempotencyKey" in js
    assert "delete concluirTransfKeysMap[id];" in js
    assert "delete receberPedidoKeysMap[id];" in js

def test_cenario_f_assinaturas_sql_e_revogacoes():
    sql = load_sql_content()
    # Verifica DROP FUNCTION com assinaturas compativeis e GRANTs para authenticated
    assert "DROP FUNCTION IF EXISTS public.concluir_transferencia_rpc(bigint, text, text);" in sql
    assert "DROP FUNCTION IF EXISTS public.receber_pedido_rpc(bigint, text, text);" in sql
    assert "GRANT EXECUTE ON FUNCTION public.concluir_transferencia_rpc(bigint, text, text) TO authenticated;" in sql
    assert "GRANT EXECUTE ON FUNCTION public.receber_pedido_rpc(bigint, text, text) TO authenticated;" in sql

def test_receber_pedido_rpc_permissao_gerente():
    sql = load_sql_content()
    # Verifica que gerentes podem receber pedidos mesmo de filiais distintas
    assert "IF v_user_cargo != 'gerente' AND (v_user_filial_id IS NULL OR v_user_filial_id != v_pedido.filial_id) THEN" in sql
