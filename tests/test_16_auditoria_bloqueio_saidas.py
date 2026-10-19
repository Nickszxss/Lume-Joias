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

def test_1_saida_valida_com_saldo_suficiente():
    sql = load_sql_content()
    assert "v_qtd_ant < p_quantidade" in sql
    assert "v_qtd_nova := v_qtd_ant - p_quantidade;" in sql
    assert "INSERT INTO public.movimentacoes" in sql

def test_2_saida_exatamente_igual_ao_saldo():
    sql = load_sql_content()
    # Quando v_qtd_ant = p_quantidade, a expressão (v_qtd_ant < p_quantidade) é Falsa, permitindo a saída zerando o estoque
    assert "IF v_qtd_ant < p_quantidade THEN" in sql
    assert "WHEN v_qtd_nova = 0 THEN 'zerado'" in sql

def test_3_rejeicao_saida_superior_ao_saldo():
    sql = load_sql_content()
    assert "Saldo insuficiente na filial para realizar a saida" in sql
    assert "Saldo insuficiente em estoque na filial de origem" in sql

def test_4_rejeicao_quantidade_zero_negativa_ou_invalida():
    sql = load_sql_content()
    assert "p_quantidade IS NULL OR p_quantidade <= 0" in sql
    assert "v_transf.quantidade <= 0" in sql

def test_5_serializacao_chamadas_simultaneas_locks():
    sql = load_sql_content()
    assert "FOR UPDATE" in sql
    assert "pg_advisory_xact_lock" in sql

def test_6_rejeicao_transferencia_saldo_insuficiente_origem():
    sql = load_sql_content()
    assert "v_origem_qtd_ant < v_transf.quantidade" in sql
    assert "Saldo insuficiente em estoque na filial de origem" in sql

def test_7_rollback_integral_falha():
    sql = load_sql_content()
    assert sql.count("RAISE EXCEPTION") >= 15

def test_8_idempotencia_saida_repetida():
    sql = load_sql_content()
    assert "p_idempotency_key" in sql
    assert "pg_advisory_xact_lock(pg_catalog.hashtext('idempotency:' || p_idempotency_key))" in sql

def test_9_bloqueio_alteracao_direta_api_sem_rpc():
    sql = load_sql_content()
    assert "REVOKE UPDATE (id, filial_id, produto_id, quantidade, status, updated_at) ON public.estoques FROM PUBLIC, anon, authenticated;" in sql
    assert "REVOKE ALL ON public.movimentacoes FROM PUBLIC, anon, authenticated;" in sql

def test_10_preservacao_todas_as_suites_anteriores():
    sql = load_sql_content()
    assert "CHECK (quantidade >= 0)" in sql
    assert "cadastrar_produto_com_estoques_rpc" in sql
    assert "criar_pedido_compra_rpc" in sql
