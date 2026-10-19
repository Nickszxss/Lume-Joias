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

def test_1_padronizacao_cinco_categorias_oficiais_frontend():
    js = load_main_js_content()
    assert "nomeLower.includes('anel')" in js
    assert "nomeLower.includes('pulseira')" in js
    assert "nomeLower.includes('solitária') || nomeLower.includes('solitaria')" in js
    assert "nomeLower.includes('colar')" in js
    assert "nomeLower.includes('brinco')" in js

def test_2_rejeicao_nomes_invalidos_sem_categoria_oficial():
    js = load_main_js_content()
    sql = load_sql_content()
    assert "Nome do produto deve corresponder a uma categoria permitida" in js
    assert "Nome do produto nao corresponde a uma categoria permitida" in sql

def test_3_impossibilidade_escolha_manual_categoria():
    js = load_main_js_content()
    assert "obterCategoriaPorNome(nome)" in js
    assert 'readonly' in load_main_js_content() or 'p-cat' in js

def test_4_validacao_motivo_obrigatorio_ajuste_estoque():
    js = load_main_js_content()
    sql = load_sql_content()
    assert "O motivo do ajuste de estoque é obrigatório." in js
    assert "Motivo do ajuste de estoque e obrigatorio." in sql

def test_5_preservacao_todas_as_suites_sql_e_rpcs():
    sql = load_sql_content()
    assert "CHECK (quantidade >= 0)" in sql
    assert "ajustar_estoque_rpc" in sql
    assert "concluir_transferencia_rpc" in sql
    assert "receber_pedido_rpc" in sql
    assert "criar_pedido_compra_rpc" in sql
    assert "cadastrar_produto_com_estoques_rpc" in sql
