import re
import pytest

MAIN_JS_FILE_PATH = "main.js"
SQL_FILE_PATH = "supabase_rls_policies.sql"
MIGRATION_FILE_PATH = "scripts/migracao_inativacao_local_e_normalizacao_categorias.sql"

def load_main_js_content():
    with open(MAIN_JS_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def load_sql_content():
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def load_migration_content():
    with open(MIGRATION_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def test_1_entrada_e_saida_estoque_validadas():
    js = load_main_js_content()
    sql = load_sql_content()
    assert "ajustar_estoque_rpc" in js
    assert "ajustar_estoque_rpc" in sql
    assert "p_tipo: dados.tipo" in js or "tipo, quantidade" in js
    assert "p_tipo NOT IN ('entrada', 'saida')" in sql

def test_2_bloqueio_saida_acima_do_saldo():
    sql = load_sql_content()
    assert "v_qtd_ant < p_quantidade" in sql
    assert "Saldo insuficiente na filial para realizar a saida" in sql

def test_3_registro_correto_historico():
    sql = load_sql_content()
    assert "INSERT INTO public.movimentacoes" in sql
    assert "quantidade_anterior" in sql
    assert "quantidade_nova" in sql

def test_4_cadastro_produto_com_cinco_estoques_iniciais():
    js = load_main_js_content()
    sql = load_sql_content()
    assert "cadastrar_produto_com_estoques_rpc" in js
    assert "cadastrar_produto_com_estoques_rpc" in sql
    assert "INSERT INTO public.estoques" in sql
    assert "v_filial_count <> 5" in sql or "ORDER BY id ASC" in sql

def test_5_prevencao_duplicidade_estoque():
    sql = load_sql_content()
    assert "ON CONFLICT (filial_id, produto_id) DO UPDATE" in sql

def test_6_categoria_automatica_por_nome():
    js = load_main_js_content()
    assert "function obterCategoriaPorNome" in js
    assert "ANEL" in js and "PULSEIRA" in js and "SOLITARIA" in js and "COLAR" in js and "BRINCO" in js

def test_7_ausencia_dependencias_estoque_minimo_frontend():
    js = load_main_js_content()
    assert "qtd_minima" not in js
    assert "quantidadeMinima" not in js
    assert "minProduto" not in js

def test_8_botao_mais_dez_incremento_e_idempotencia():
    js = load_main_js_content()
    assert "adicionarMaisDezEstoque" in js
    assert "quantidade: 10" in js
    assert "btn.disabled = true;" in js

def test_9_filtros_combinados_filial_e_produto():
    js = load_main_js_content()
    assert "filialEstoqueSel" in js
    assert "prodSel" in js
    assert "list = list.filter(e => String(e.produto_id) === String(prodSel));" in js

def test_10_inativacao_local_produto_por_filial():
    js = load_main_js_content()
    sql_mig = load_migration_content()
    assert "inativarProdutoLocal" in js
    assert "produtos_filiais_inativos" in js
    assert "produtos_filiais_inativos" in sql_mig
    assert "unique_produto_filial_inativo" in sql_mig

def test_11_compatibilidade_assinaturas_rpcs_javascript():
    js = load_main_js_content()
    assert "cadastrar_produto_com_estoques_rpc" in js
    assert "ajustar_estoque_rpc" in js
    assert "concluir_transferencia_rpc" in js
    assert "receber_pedido_rpc" in js
    assert "criar_pedido_compra_rpc" in js
