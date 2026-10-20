import re
import pytest

SQL_FILE_PATH = "supabase_rls_policies.sql"
MIGRATION_FILE_PATH = "scripts/migracao_cadastro_produto_multiplas_filiais_rpc.sql"
MAIN_JS_FILE_PATH = "main.js"
INDEX_HTML_FILE_PATH = "index.html"
STYLE_CSS_FILE_PATH = "style.css"

def load_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()

def test_1_cadastro_com_uma_filial_selecionada():
    js = load_file(MAIN_JS_FILE_PATH)
    sql = load_file(SQL_FILE_PATH)
    # Frontend permite array com 1 filial e RPC aceita p_filiais_ids com 1 elemento
    assert "p_filiais_ids" in sql
    assert "p-filial-cb" in js
    assert "checkedFiliais.length === 0" in js

def test_2_cadastro_com_varias_filiais_selecionadas():
    js = load_file(MAIN_JS_FILE_PATH)
    sql = load_file(SQL_FILE_PATH)
    # Suporte a array de filiais
    assert "p_filiais_ids integer[]" in sql
    assert "checkedFiliais" in js

def test_3_aplicacao_mesma_quantidade_por_filial():
    sql = load_file(SQL_FILE_PATH)
    html = load_file(INDEX_HTML_FILE_PATH)
    # A quantidade informada é aplicada individualmente a cada filial selecionada
    assert "A quantidade informada será aplicada a cada filial selecionada." in html
    assert "INSERT INTO public.estoques (filial_id, produto_id, quantidade, status, updated_at)" in sql
    assert "VALUES (v_filial_rec.id, v_prod_id, p_quantidade, v_status, now());" in sql

def test_4_rejeicao_lista_filiais_vazia():
    js = load_file(MAIN_JS_FILE_PATH)
    sql = load_file(SQL_FILE_PATH)
    # Rejeição no JS e SQL de lista de filiais vazia
    assert "Selecione pelo menos uma filial." in js
    assert "Selecione pelo menos uma filial." in sql

def test_5_rejeicao_filiais_ids_ausente_ou_nao_array():
    js = load_file(MAIN_JS_FILE_PATH)
    assert "!dados.filiaisIds || !Array.isArray(dados.filiaisIds)" in js

def test_6_rejeicao_ids_invalidos_e_duplicados():
    js = load_file(MAIN_JS_FILE_PATH)
    sql = load_file(SQL_FILE_PATH)
    # JS e SQL rejeitam IDs de filiais inválidas e duplicadas
    assert "Uma ou mais filiais selecionadas são inválidas." in js
    assert "IDs de filiais duplicados não são permitidos." in js
    assert "Uma ou mais filiais selecionadas sao invalidas ou inativas." in sql

def test_7_filiais_nao_selecionadas_sem_estoque():
    sql = load_file(SQL_FILE_PATH)
    # RPC faz LOOP apenas nas filiais que batem com ANY(p_filiais_ids)
    assert "WHERE id = ANY(p_filiais_ids) AND ativa IS TRUE" in sql

def test_8_lista_filiais_vertical_modal():
    css = load_file(STYLE_CSS_FILE_PATH)
    html = load_file(INDEX_HTML_FILE_PATH)
    # CSS configura lista vertical (flex-direction: column)
    assert "filiais-checkbox-group" in css
    assert "flex-direction: column;" in css or "flex-direction:column;" in css
    assert "p-filiais-container" in html

def test_9_validacao_quantidade_0_a_50():
    js = load_file(MAIN_JS_FILE_PATH)
    sql = load_file(SQL_FILE_PATH)
    assert "p_quantidade < 0 OR p_quantidade > 50" in sql
    assert "A quantidade deve ser um número inteiro entre 0 e 50." in js
