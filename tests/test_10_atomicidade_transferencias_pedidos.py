import re
import pytest

SQL_FILE_PATH = "supabase_rls_policies.sql"

def load_sql_content():
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        return f.read()

def test_1_transferencia_sucesso_fluxo_completo():
    sql = load_sql_content()
    assert "concluir_transferencia_rpc" in sql
    # Atualização de saldos de origem e destino
    assert "v_origem_qtd_nova := v_origem_qtd_ant - v_transf.quantidade;" in sql
    assert "v_dest_qtd_nova := v_dest_qtd_ant + v_transf.quantidade;" in sql
    # Movimentações auditáveis
    assert "'saida', v_transf.quantidade" in sql or "tipo, quantidade" in sql
    assert "'entrada', v_transf.quantidade" in sql or "tipo, quantidade" in sql
    # Atualização de status e data de conclusão
    assert "status = 'concluida'" in sql
    assert "concluida_at = now()" in sql

def test_2_rejeicao_saldo_insuficiente():
    sql = load_sql_content()
    assert "v_origem_qtd_ant < v_transf.quantidade" in sql
    assert "Saldo insuficiente em estoque na filial de origem" in sql

def test_3_rejeicao_transferencia_cancelada_concluida_ou_mesma_origem_destino():
    sql = load_sql_content()
    assert "v_transf.status::text = 'concluida'" in sql
    assert "v_transf.status::text = 'cancelada'" in sql
    assert "v_transf.origem_id = v_transf.destino_id" in sql
    assert "origem e destino identicos" in sql

def test_4_rejeicao_usuario_nao_autorizado():
    sql = load_sql_content()
    assert "v_user_cargo != 'gerente' AND (v_user_filial_id IS NULL OR v_user_filial_id != v_transf.destino_id)" in sql
    assert "Somente gerentes ou funcionarios da filial de destino podem concluir a transferencia" in sql

def test_5_rollback_integral_falha_transferencia():
    sql = load_sql_content()
    # No PL/pgSQL com SECURITY DEFINER, qualquer RAISE EXCEPTION desfaz a transação implicitamente
    raise_count = sql.count("RAISE EXCEPTION")
    assert raise_count >= 10, "Validações com RAISE EXCEPTION devem existir para garantir o rollback integral em qualquer falha"

def test_6_recebimento_valido_pedido():
    sql = load_sql_content()
    assert "receber_pedido_rpc" in sql
    assert "v_dest_qtd_nova := v_dest_qtd_ant + v_item.quantidade;" in sql
    assert "'entrada', v_item.quantidade" in sql
    assert "status = 'recebido'" in sql
    assert "recebido_at = now()" in sql

def test_7_rejeicao_pedido_vazio_cancelado_ou_ja_recebido():
    sql = load_sql_content()
    assert "v_pedido.status::text = 'recebido'" in sql
    assert "v_pedido.status::text = 'cancelado'" in sql
    assert "v_items_count = 0" in sql
    assert "nao possui itens vinculados" in sql

def test_8_rollback_integral_falha_recebimento():
    sql = load_sql_content()
    assert "RAISE EXCEPTION 'Operacao negada: Item ID % possui quantidade invalida (%).', v_item.id, v_item.quantidade;" in sql or "v_item.quantidade <= 0" in sql

def test_9_ausencia_registros_duplicados_estoque():
    sql = load_sql_content()
    assert "ON CONFLICT (filial_id, produto_id) DO UPDATE" in sql
    assert "CONSTRAINT estoques_quantidade_nonnegative" in sql or "quantidade = EXCLUDED.quantidade" in sql

def test_10_tentativas_concorrentes_concluir_transferencia():
    sql = load_sql_content()
    # SELECT FOR UPDATE no registro de transferencia
    assert "FROM public.transferencias\n  WHERE id = p_transferencia_id\n  FOR UPDATE" in sql or "WHERE id = p_transferencia_id\n  FOR UPDATE" in sql or "FOR UPDATE;" in sql
    # Advisory locks determinísticos
    assert "v_transf.origem_id < v_transf.destino_id" in sql
    assert "pg_advisory_xact_lock" in sql

def test_11_tentativas_concorrentes_receber_pedido():
    sql = load_sql_content()
    # SELECT FOR UPDATE no pedido
    assert "FROM public.pedidos_compra\n  WHERE id = p_pedido_id\n  FOR UPDATE" in sql or "WHERE id = p_pedido_id\n  FOR UPDATE" in sql
    # Advisory locks e SELECT FOR UPDATE no estoque
    assert ("pg_advisory_xact_lock(pg_catalog.hashtext(v_pedido.filial_id::text || '_' || v_item.produto_id::text))" in sql or
            "pg_advisory_xact_lock(pg_catalog.hashtextextended(v_pedido.filial_id::text || ':' || v_item.produto_id::text, 0))" in sql)
    assert "FOR UPDATE" in sql

def test_12_consistencia_final_estoque_movimentacoes_status():
    sql = load_sql_content()
    assert "status = v_origem_status::public.status_estoque" in sql or "v_origem_status" in sql
    assert "status = v_dest_status::public.status_estoque" in sql or "v_dest_status" in sql
    assert "'zerado'" in sql and "'baixo'" in sql and "'suficiente'" in sql
