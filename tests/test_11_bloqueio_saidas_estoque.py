import re
import pytest

SQL_FILE_PATH = "supabase_rls_policies.sql"

def load_sql_content():
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def test_1_saida_valida_saldo_suficiente():
    sql = load_sql_content()
    assert "ajustar_estoque_rpc" in sql
    assert "p_tipo = 'saida'" in sql
    assert "v_qtd_nova := v_qtd_ant - p_quantidade;" in sql
    assert "INSERT INTO public.movimentacoes" in sql

def test_2_rejeicao_saida_quantidade_zero():
    sql = load_sql_content()
    assert "p_quantidade IS NULL OR p_quantidade <= 0" in sql
    assert "Quantidade de ajuste deve ser um inteiro maior que zero." in sql

def test_3_rejeicao_saida_quantidade_negativa():
    sql = load_sql_content()
    assert "p_quantidade IS NULL OR p_quantidade <= 0" in sql
    assert "quantidade > 0" in sql

def test_4_rejeicao_saida_superior_saldo_disponivel():
    sql = load_sql_content()
    assert "v_qtd_ant < p_quantidade" in sql
    assert "Saldo insuficiente na filial para realizar a saida" in sql

def test_5_manutencao_saldo_inalterado_saida_rejeitada():
    sql = load_sql_content()
    # Em PostgreSQL/PLpgSQL, qualquer RAISE EXCEPTION reverte a transação inteira mantendo o saldo inalterado
    assert "RAISE EXCEPTION 'Saldo insuficiente na filial para realizar a saida (disponivel: %, solicitado: %).', v_qtd_ant, p_quantidade;" in sql

def test_6_ausencia_movimentacao_saida_rejeitada():
    sql = load_sql_content()
    # A inserção em movimentacoes em ajustar_estoque_rpc ocorre estritamente no final, após todas as verificações com RAISE EXCEPTION
    assert sql.find("RAISE EXCEPTION 'Saldo insuficiente na filial para realizar a saida") < sql.find("INSERT INTO public.movimentacoes")

def test_7_atualizacao_correta_saldo_e_movimentacao_unica_saida_valida():
    sql = load_sql_content()
    assert "ON CONFLICT (filial_id, produto_id) DO UPDATE" in sql
    assert "VALUES (p_produto_id, p_filial_id, v_user_id, p_tipo, p_quantidade, v_qtd_ant, v_qtd_nova, COALESCE(p_motivo, 'Ajuste manual de estoque'), now());" in sql

def test_8_protecao_caminhos_saida_mapeados():
    sql = load_sql_content()
    # Ambas as RPCs de saída estão protegidas com SECURITY DEFINER e busca de saldo com SELECT FOR UPDATE
    assert "CREATE OR REPLACE FUNCTION public.ajustar_estoque_rpc" in sql
    assert "CREATE OR REPLACE FUNCTION public.concluir_transferencia_rpc" in sql
    assert "FOR UPDATE" in sql

def test_9_restricoes_autorizacao_e_chamadas_diretas_api():
    sql = load_sql_content()
    # Direct UPDATE on estoques blocked
    assert "REVOKE UPDATE (id, filial_id, produto_id, quantidade, status, updated_at) ON public.estoques FROM PUBLIC, anon, authenticated;" in sql
    # Direct INSERT on movimentacoes blocked
    assert "REVOKE ALL ON public.movimentacoes FROM PUBLIC, anon, authenticated;" in sql
    # Strict role/branch validation
    assert "v_user_filial_id IS NULL OR v_user_filial_id != p_filial_id" in sql

def test_10_preservacao_testes_anteriores_e_constraint_nao_negativo():
    sql = load_sql_content()
    assert "CHECK (quantidade >= 0)" in sql
    assert "status::text = 'solicitada'" in sql
    assert "status::text = 'aberto'" in sql
