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

def test_10_1_validacao_quantidade_frontend_e_backend():
    js = load_file(MAIN_JS_FILE_PATH)
    sql = load_file(SQL_FILE_PATH)
    mig = load_file(MIGRATION_FILE_PATH)

    # Validação de quantidade min 0 e max 50 e inteiros
    assert "p_quantidade" in sql
    assert "p_quantidade < 0 OR p_quantidade > 50" in sql or "p_quantidade < 0" in sql
    assert "p_quantidade < 0 OR p_quantidade > 50" in mig

    # Validações no frontend (main.js)
    assert "A quantidade deve ser um número inteiro entre 0 e 50." in js
    assert "Number.isInteger" in js or "parseInt" in js

def test_10_2_selecao_multiplas_filiais_frontend_e_backend():
    html = load_file(INDEX_HTML_FILE_PATH)
    js = load_file(MAIN_JS_FILE_PATH)
    sql = load_file(SQL_FILE_PATH)
    css = load_file(STYLE_CSS_FILE_PATH)

    # Componente visual para seleção de filiais em index.html e style.css
    assert "p-filiais-container" in html
    assert "filiais-checkbox-group" in html or "filiais-checkbox-group" in css
    assert "A quantidade informada será aplicada a cada filial selecionada." in html

    # Lógica de seleção e renderização de checkboxes no frontend
    assert "p-filial-cb" in js
    assert "Selecione pelo menos uma filial." in js

    # Backend suporta array de filiais e valida se não está vazio
    assert "p_filiais_ids" in sql
    assert "Selecione pelo menos uma filial." in sql

def test_10_3_persistencia_produto_unico_e_estoque_apenas_selecionadas():
    sql = load_file(SQL_FILE_PATH)
    js = load_file(MAIN_JS_FILE_PATH)

    # Inserção de produto única em public.produtos
    assert "INSERT INTO public.produtos" in sql
    assert "RETURNING id INTO v_prod_id;" in sql

    # Criação de estoque APENAS para filiais selecionadas
    assert "WHERE id = ANY(p_filiais_ids)" in sql
    assert "INSERT INTO public.estoques" in sql

    # Histórico de movimentações para quantidade > 0
    assert "IF p_quantidade > 0 THEN" in sql
    assert "INSERT INTO public.movimentacoes" in sql
    assert "'entrada'::public.tipo_movimentacao" in sql or "'entrada'" in sql

def test_10_4_seguranca_e_permissoes_rpc():
    sql = load_file(SQL_FILE_PATH)

    assert "REVOKE EXECUTE ON FUNCTION public.cadastrar_produto_com_estoques_rpc" in sql
    assert "GRANT EXECUTE ON FUNCTION public.cadastrar_produto_com_estoques_rpc" in sql
    assert "v_user_cargo != 'gerente'" in sql
    assert "Apenas gerentes possuem permissao para cadastrar produtos" in sql
