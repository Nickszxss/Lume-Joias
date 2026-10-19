import re
import pytest

SQL_FILE_PATH = "supabase_rls_policies.sql"

def load_sql_content():
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def test_unambiguous_identity_resolution():
    sql = load_sql_content()
    assert "public.get_auth_user_cargo()" in sql
    assert "public.get_auth_user_filial_id()" in sql
    assert "public.get_auth_user_id()" in sql
    assert "IF v_count <> 1 THEN" in sql or "v_user_count > 1" in sql
    assert "Identidade ambígua" in sql or "RETURN NULL;" in sql

def test_coalesce_cargo_and_tipo_unification():
    sql = load_sql_content()
    assert "u.tipo::text" in sql or "tipo::text" in sql, "Authoritative system role u.tipo::text missing"

def test_usuario_id_spoofing_prevention():
    sql = load_sql_content()
    assert "usuario_id = public.get_auth_user_id()" in sql, "usuario_id spoofing guard missing in RLS policies"

def test_absence_of_pendente_and_presence_of_solicitada():
    sql = load_sql_content()
    assert "status = 'pendente'" not in sql, "'pendente' status check found in SQL policies"
    assert "status::text = 'pendente'" not in sql, "'pendente' status check found in SQL policies"
    assert "status != 'pendente'" not in sql, "'pendente' status check found in RPC"
    assert "status::text != 'pendente'" not in sql, "'pendente' status check found in RPC"
    assert "solicitada" in sql, "'solicitada' state missing from SQL script"
    assert "status::text = 'solicitada'" in sql or "status = 'solicitada'" in sql, "Transfer status 'solicitada' missing from RLS policy"

def test_stock_status_logic_and_qtd_minima():
    sql = load_sql_content()
    assert "'zerado'" in sql, "Stock status 'zerado' missing"
    assert "'baixo'" in sql, "Stock status 'baixo' missing"
    assert "'suficiente'" in sql, "Stock status 'suficiente' missing"
    assert "qtd_minima" in sql, "produtos.qtd_minima missing from stock calculation"
    assert "estoque_minimo" not in sql, "Invalid column 'estoque_minimo' referenced in SQL"

def test_absence_of_unconfirmed_recebido_por():
    sql = load_sql_content()
    assert "recebido_por" not in sql, "Non-existent column 'recebido_por' found in SQL script"
    assert "recebido_at" in sql, "Valid column 'recebido_at' missing from SQL script"

def test_usuarios_senha_protection_and_profile_updates():
    sql = load_sql_content()
    grant_select = re.search(r"GRANT SELECT \(([^)]+)\) ON public\.usuarios", sql)
    assert grant_select is not None, "GRANT SELECT on usuarios missing"
    selected_columns = [col.strip() for col in grant_select.group(1).split(",")]
    assert "senha" not in selected_columns, "Sensitive column 'senha' included in GRANT SELECT"
    assert "GRANT UPDATE (nome) ON public.usuarios TO authenticated;" in sql, "GRANT UPDATE (nome) missing for usuarios"

def test_produtos_filiais_inativos_explicit_privileges():
    sql = load_sql_content()
    assert "CREATE TABLE IF NOT EXISTS public.produtos_filiais_inativos" in sql or "ALTER TABLE public.produtos_filiais_inativos ENABLE ROW LEVEL SECURITY;" in sql
    revoke_match = re.search(r"REVOKE ALL ON [^;]*produtos_filiais_inativos[^;]*FROM", sql)
    assert revoke_match is not None, "Explicit REVOKE ALL on produtos_filiais_inativos missing"

def test_security_definer_audit_and_search_path():
    sql = load_sql_content()
    sql_code_lines = [line for line in sql.splitlines() if not line.strip().startswith("--")]
    sql_code = "\n".join(sql_code_lines)
    sec_definer_count = sql_code.count("SECURITY DEFINER")
    search_path_count = sql_code.count("SET search_path = ''")
    assert sec_definer_count > 0, "No SECURITY DEFINER functions found"
    assert sec_definer_count == search_path_count, "All SECURITY DEFINER functions must set search_path = ''"

def test_rpc_execution_restrictions():
    sql = load_sql_content()
    rpcs = ["ajustar_estoque_rpc", "concluir_transferencia_rpc", "receber_pedido_rpc"]
    for rpc in rpcs:
        assert f"REVOKE EXECUTE ON FUNCTION public.{rpc}" in sql, f"REVOKE EXECUTE for {rpc} missing"
        assert f"GRANT EXECUTE ON FUNCTION public.{rpc}" in sql, f"GRANT EXECUTE for {rpc} missing"

def test_deadlock_prevention_advisory_locks():
    sql = load_sql_content()
    assert "v_transf.origem_id < v_transf.destino_id" in sql, "Deterministic branch advisory lock ordering missing"
    assert "pg_advisory_xact_lock" in sql, "Advisory transaction lock missing"

def test_sequence_privileges_scoped_to_project_tables():
    sql = load_sql_content()
    assert "REVOKE ALL ON SEQUENCE" in sql, "Scoped REVOKE ALL ON SEQUENCE missing"
    assert "GRANT USAGE, SELECT ON SEQUENCE" in sql, "Scoped GRANT USAGE, SELECT ON SEQUENCE missing"

def test_negative_stock_prevention():
    sql = load_sql_content()
    assert "CHECK (quantidade >= 0)" in sql, "CHECK (quantidade >= 0) constraint missing"
    assert "quantidade < 0" in sql or "v_negatives_count" in sql, "Negative stock check missing"

def test_transaction_boundaries():
    sql = load_sql_content()
    assert "BEGIN;" in sql, "Script must contain BEGIN;"
    assert "COMMIT;" in sql, "Script must contain COMMIT;"

def test_seed_data_preservation():
    sql = load_sql_content()
    assert "INSERT INTO public.usuarios" not in sql, "Found prohibited direct INSERT into usuarios"
    assert "INSERT INTO public.filiais" not in sql, "Found prohibited direct INSERT into filiais"

def test_nine_tables_rls_matrix():
    sql = load_sql_content()
    tables = [
        'usuarios', 'filiais', 'produtos', 'estoques',
        'movimentacoes', 'transferencias', 'pedidos_compra', 'itens_pedido_compra',
        'produtos_filiais_inativos'
    ]
    for table in tables:
        assert f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY;" in sql, f"RLS not enabled for public.{table}"
