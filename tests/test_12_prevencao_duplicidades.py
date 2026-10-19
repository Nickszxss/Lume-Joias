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

def test_1_frontend_btn_submit_disable_and_loading():
    js = load_main_js_content()
    assert ".disabled = true" in js
    assert "Processando" in js or "Salvando" in js or "Aguarde" in js or "Carregando" in js

def test_2_frontend_btn_submit_reactivation_on_finally_or_error():
    js = load_main_js_content()
    assert "finally" in js or ".disabled = false" in js
    assert ".disabled = false" in js

def test_3_rpc_rejeicao_transferencia_duplicada():
    sql = load_sql_content()
    assert "v_transf.status::text = 'concluida'" in sql
    assert "ja foi concluida anteriormente" in sql

def test_4_rpc_rejeicao_pedido_duplicado():
    sql = load_sql_content()
    assert "v_pedido.status::text = 'recebido'" in sql
    assert "ja foi recebido anteriormente" in sql

def test_5_concorrencia_e_pessimistic_locking():
    sql = load_sql_content()
    assert "FOR UPDATE" in sql
    assert "pg_advisory_xact_lock" in sql

def test_6_on_conflict_upsert_estoques_preenchendo_duplicidade():
    sql = load_sql_content()
    assert "ON CONFLICT (filial_id, produto_id) DO UPDATE" in sql

def test_7_preservacao_operacoes_legitimas_posteriores():
    sql = load_sql_content()
    assert "ajustar_estoque_rpc" in sql
    assert "concluir_transferencia_rpc" in sql
    assert "receber_pedido_rpc" in sql

def test_8_preservacao_testes_anteriores_e_constraints():
    sql = load_sql_content()
    assert "CHECK (quantidade >= 0)" in sql
    assert "SECURITY DEFINER" in sql
    assert "SET search_path = ''" in sql
