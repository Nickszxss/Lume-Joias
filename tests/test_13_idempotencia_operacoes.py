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

def test_1_tabela_idempotencia_chaves():
    sql = load_sql_content()
    assert "CREATE TABLE IF NOT EXISTS public.idempotencia_chaves" in sql
    assert "chave text NOT NULL UNIQUE" in sql
    assert "parametros_hash text NOT NULL" in sql
    assert "resultado_json json NOT NULL" in sql

def test_2_ajustar_estoque_rpc_idempotencia():
    sql = load_sql_content()
    assert "p_idempotency_key text DEFAULT NULL" in sql
    assert "pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key))" in sql
    assert "v_idempotent_rec.parametros_hash = v_params_hash" in sql
    assert "RETURN v_idempotent_rec.resultado_json;" in sql
    assert "A chave de idempotencia % ja foi utilizada com parametros diferentes" in sql
    assert "INSERT INTO public.idempotencia_chaves" in sql

def test_3_criar_pedido_compra_rpc_atomico_e_idempotente():
    sql = load_sql_content()
    assert "CREATE OR REPLACE FUNCTION public.criar_pedido_compra_rpc" in sql
    assert "INSERT INTO public.pedidos_compra" in sql
    assert "INSERT INTO public.itens_pedido_compra" in sql
    assert "p_idempotency_key text DEFAULT NULL" in sql
    assert "pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key))" in sql
    assert "v_idempotent_rec.parametros_hash = v_params_hash" in sql

def test_4_frontend_integracao_idempotencia_uuid_v4():
    js = load_main_js_content()
    assert "crypto.randomUUID()" in js
    assert "p_idempotency_key: idempotencyKey" in js
    assert "criar_pedido_compra_rpc" in js

def test_5_preservacao_privilegios_e_security_definer():
    sql = load_sql_content()
    assert "REVOKE EXECUTE ON FUNCTION public.criar_pedido_compra_rpc" in sql
    assert "GRANT EXECUTE ON FUNCTION public.criar_pedido_compra_rpc" in sql
    assert "REVOKE EXECUTE ON FUNCTION public.ajustar_estoque_rpc" in sql
    assert "GRANT EXECUTE ON FUNCTION public.ajustar_estoque_rpc" in sql

def test_6_preservacao_testes_anteriores_e_constraints():
    sql = load_sql_content()
    assert "CHECK (quantidade >= 0)" in sql
    assert "origem_id = v_transf.destino_id" in sql
    assert "status::text = 'concluida'" in sql
    assert "status::text = 'recebido'" in sql
