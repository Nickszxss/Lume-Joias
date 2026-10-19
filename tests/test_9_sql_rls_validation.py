import re
import pytest

SQL_FILE_PATH = "supabase_rls_policies.sql"

def load_sql_content():
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def test_absence_of_pendente_and_presence_of_solicitada():
    sql = load_sql_content()
    # Ensure 'pendente' is not used as a valid status in transfer RLS policy or RPC
    assert "status = 'pendente'" not in sql, "'pendente' status check found in SQL policies"
    assert "status::text = 'pendente'" not in sql, "'pendente' status check found in SQL policies"
    assert "status != 'pendente'" not in sql, "'pendente' status check found in RPC"
    assert "status::text != 'pendente'" not in sql, "'pendente' status check found in RPC"

    # Ensure 'solicitada' is properly checked
    assert "solicitada" in sql, "'solicitada' state missing from SQL script"
    assert "status::text = 'solicitada'" in sql or "status = 'solicitada'" in sql, "Transfer status 'solicitada' missing from RLS policy"

def test_stock_status_logic_and_qtd_minima():
    sql = load_sql_content()
    # Check that 'zerado', 'baixo', and 'suficiente' are evaluated in RPCs
    assert "'zerado'" in sql, "Stock status 'zerado' missing"
    assert "'baixo'" in sql, "Stock status 'baixo' missing"
    assert "'suficiente'" in sql, "Stock status 'suficiente' missing"

    # Verify qtd_minima usage from produtos
    assert "qtd_minima" in sql, "produtos.qtd_minima missing from stock calculation"

    # Ensure non-existent column 'estoque_minimo' is NOT referenced
    assert "estoque_minimo" not in sql, "Invalid column 'estoque_minimo' referenced in SQL"

def test_absence_of_unconfirmed_recebido_por():
    sql = load_sql_content()
    # Verify recebido_por is NOT in the SQL script
    assert "recebido_por" not in sql, "Non-existent column 'recebido_por' found in SQL script"
    # Ensure recebido_at IS preserved
    assert "recebido_at" in sql, "Valid column 'recebido_at' missing from SQL script"

def test_usuarios_senha_protection_and_type_conversions():
    sql = load_sql_content()
    # Ensure senha is omitted from GRANT SELECT
    grant_select = re.search(r"GRANT SELECT \(([^)]+)\) ON public\.usuarios", sql)
    assert grant_select is not None, "GRANT SELECT on usuarios missing"
    selected_columns = [col.strip() for col in grant_select.group(1).split(",")]
    assert "senha" not in selected_columns, "Sensitive column 'senha' included in GRANT SELECT"

    # Verify explicit type conversion between tipo_usuario and text (cargo)
    assert "tipo::text" in sql, "Explicit type cast 'tipo::text' missing for PostgreSQL enum/varchar compatibility"

def test_produtos_filiais_inativos_explicit_privileges():
    sql = load_sql_content()
    # Check table creation and RLS
    assert "CREATE TABLE IF NOT EXISTS public.produtos_filiais_inativos" in sql or "ALTER TABLE public.produtos_filiais_inativos ENABLE ROW LEVEL SECURITY;" in sql
    # Check REVOKE ALL includes produtos_filiais_inativos
    revoke_match = re.search(r"REVOKE ALL ON [^;]*produtos_filiais_inativos[^;]*FROM", sql)
    assert revoke_match is not None, "Explicit REVOKE ALL on produtos_filiais_inativos missing"

def test_rpc_execution_restrictions():
    sql = load_sql_content()
    rpcs = ["ajustar_estoque_rpc", "concluir_transferencia_rpc", "receber_pedido_rpc"]
    for rpc in rpcs:
        assert f"REVOKE EXECUTE ON FUNCTION public.{rpc}" in sql, f"REVOKE EXECUTE for {rpc} missing"
        assert f"GRANT EXECUTE ON FUNCTION public.{rpc}" in sql, f"GRANT EXECUTE for {rpc} missing"
        assert "SECURITY DEFINER" in sql, f"SECURITY DEFINER for {rpc} missing"

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
    # Script should NOT contain INSERT statements into seed data like usuarios or filiais
    assert "INSERT INTO public.usuarios" not in sql, "Found prohibited direct INSERT into usuarios"
    assert "INSERT INTO public.filiais" not in sql, "Found prohibited direct INSERT into filiais"
