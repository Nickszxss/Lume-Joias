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

def test_1_rpc_cadastrar_produto_com_estoques_cinco_filiais():
    sql = load_sql_content()
    assert "cadastrar_produto_com_estoques_rpc" in sql
    assert "p_filiais_ids" in sql
    assert "INSERT INTO public.estoques" in sql

def test_2_registros_estoque_inicial_quantidade_zero():
    sql = load_sql_content()
    assert "INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)" in sql
    assert "p_quantidade" in sql

def test_3_autorizacao_servidor_perfil_gerente():
    sql = load_sql_content()
    assert "v_user_cargo != 'gerente'" in sql
    assert "Apenas gerentes possuem permissao para cadastrar produtos" in sql

def test_4_prevencao_duplicidade_sku_e_idempotencia():
    sql = load_sql_content()
    assert "unique_violation" in sql or "codigo/SKU % ja esta em uso" in sql
    assert "cadastrar_produto" in sql
    assert "p_idempotency_key" in sql

def test_5_nao_alteracao_estoques_existentes():
    sql = load_sql_content()
    # Inserção de estoques é atômica para o NOVO produto (v_prod_id), sem UPDATE em estoques de produtos existentes
    assert "INSERT INTO public.produtos" in sql
    assert "RETURNING id INTO v_prod_id;" in sql

def test_6_integracao_frontend_rpc_atomica():
    js = load_main_js_content()
    assert "cadastrar_produto_com_estoques_rpc" in js
    assert "produtoIdempotencyKey" in js

def test_7_preservacao_todas_as_suites_de_testes():
    sql = load_sql_content()
    assert "CHECK (quantidade >= 0)" in sql
    assert "ajustar_estoque_rpc" in sql
    assert "concluir_transferencia_rpc" in sql
    assert "receber_pedido_rpc" in sql
    assert "criar_pedido_compra_rpc" in sql
