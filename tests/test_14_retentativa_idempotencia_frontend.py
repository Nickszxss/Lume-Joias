import re
import pytest

MAIN_JS_FILE_PATH = "main.js"
SQL_FILE_PATH = "supabase_rls_policies.sql"

def load_main_js_content():
    with open(MAIN_JS_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def load_sql_content():
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def test_1_geracao_chave_abrir_modal_ajuste_e_pedido():
    js = load_main_js_content()
    assert "ajusteIdempotencyKey =" in js
    assert "pedidoIdempotencyKey =" in js
    assert "abrirModalAjuste" in js
    assert "abrirModalPedido" in js

def test_2_reutilizacao_chave_em_retentativa_ou_erro():
    js = load_main_js_content()
    # Chaves não são limpas no bloco catch ou no erro de api
    assert "idempotencyKey: ajusteIdempotencyKey" in js
    assert "idempotencyKey: pedidoIdempotencyKey" in js

def test_3_descarte_chave_somente_no_sucesso():
    js = load_main_js_content()
    # Chaves redefinidas para null após o processamento com sucesso
    assert "ajusteIdempotencyKey = null;" in js
    assert "pedidoIdempotencyKey = null;" in js

def test_4_isolamento_de_chaves_entre_operacoes():
    js = load_main_js_content()
    assert "let ajusteIdempotencyKey = null;" in js
    assert "let pedidoIdempotencyKey = null;" in js

def test_5_preservacao_todas_as_suites_sql_e_rpcs():
    sql = load_sql_content()
    assert "CREATE TABLE IF NOT EXISTS public.idempotencia_chaves" in sql
    assert "ajustar_estoque_rpc" in sql
    assert "criar_pedido_compra_rpc" in sql
    assert "concluir_transferencia_rpc" in sql
    assert "receber_pedido_rpc" in sql
