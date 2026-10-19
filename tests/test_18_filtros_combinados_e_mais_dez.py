import re
import pytest

MAIN_JS_FILE_PATH = "main.js"
INDEX_HTML_FILE_PATH = "index.html"
SQL_FILE_PATH = "supabase_rls_policies.sql"

def load_main_js_content():
    with open(MAIN_JS_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def load_index_html_content():
    with open(INDEX_HTML_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def load_sql_content():
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def test_1_filtros_combinados_filial_e_produto_em_pintar_estoque():
    js = load_main_js_content()
    assert "filialEstoqueSel" in js
    assert "prodSel" in js
    assert "list = list.filter(e => String(e.produto_id) === String(prodSel));" in js

def test_2_limpeza_filtros_retorno_listagem_completa():
    js = load_main_js_content()
    assert "setFilialEstoque(null,this)" in js or "setFilialEstoque" in js
    assert 'Todos os produtos' in js

def test_3_presenca_botao_mais_dez_na_tabela_e_index_html():
    html = load_index_html_content()
    js = load_main_js_content()
    assert "Ações" in html or "Ajustar" in html
    assert "adicionarMaisDezEstoque" in js
    assert "+10" in js

def test_4_incremento_mais_dez_via_rpc_ajustar_estoque():
    js = load_main_js_content()
    sql = load_sql_content()
    assert "quantidade: 10" in js
    assert "tipo: 'entrada'" in js
    assert "Aumento rápido de estoque (+10)" in js
    assert "ON CONFLICT (filial_id, produto_id) DO UPDATE" in sql

def test_5_bloqueio_e_desabilitacao_botao_mais_dez_async():
    js = load_main_js_content()
    assert "btn.disabled = true;" in js
    assert "btn.textContent = '+10...';" in js
    assert "btn.disabled = false;" in js
    assert "btn.textContent = '+10';" in js

def test_6_preservacao_todas_as_suites_anteriores():
    sql = load_sql_content()
    assert "CHECK (quantidade >= 0)" in sql
    assert "ajustar_estoque_rpc" in sql
    assert "concluir_transferencia_rpc" in sql
    assert "receber_pedido_rpc" in sql
    assert "criar_pedido_compra_rpc" in sql
    assert "cadastrar_produto_com_estoques_rpc" in sql
