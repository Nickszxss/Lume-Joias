import hashlib
import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# Ensure scripts package can be imported
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from scripts.executar_limpeza_supabase import (
    BACKUP_FILE_PATH,
    EXPECTED_CHECKSUM,
    EXPECTED_BACKUP_COUNTS,
    FIXED_CLEANUP_SCOPE,
    validar_backup,
    executar_limpeza,
)


class TestScriptLimpezaSeguranca(unittest.TestCase):

    def setUp(self):
        # Create a valid temp backup payload matching production
        self.valid_data = {
            "version": "1.0",
            "created_at": "2026-10-10T17:23:07.000Z",
            "tabelas": {
                "produtos": [{ "id": i } for i in range(16)],
                "estoques": [{ "id": i } for i in range(16)],
                "movimentacoes": [],
                "transferencias": [],
                "pedidos_compra": [],
                "itens_pedido_compra": [],
                "usuarios": [{ "id": i } for i in range(7)],
                "filiais": [{ "id": i } for i in range(5)],
            }
        }

        # Calculate checksum over data without checksum_sha256 key
        payload_json = json.dumps(self.valid_data, indent=2, ensure_ascii=False)
        self.valid_checksum = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()
        self.valid_data["checksum_sha256"] = self.valid_checksum

    def test_backup_real_producao(self):
        """Testa diretamente a validação do arquivo de backup real em backups/backup_sge_lume_joias_2026-10-10_17-23-07.json."""
        ok, msg = validar_backup(BACKUP_FILE_PATH)
        self.assertTrue(ok, f"Backup real de produção falhou na validação: {msg}")
        self.assertIn("Backup validado com sucesso", msg)

    def test_estrutura_tables_records_real(self):
        """Testa o suporte à estrutura 'tables' com sub-objetos 'records'."""
        data_tables_records = {
            "version": "1.0",
            "tables": {
                "produtos": { "count": 16, "records": [{ "id": i } for i in range(16)] },
                "estoques": { "count": 16, "records": [{ "id": i } for i in range(16)] },
                "movimentacoes": { "count": 0, "records": [] },
                "transferencias": { "count": 0, "records": [] },
                "pedidos_compra": { "count": 0, "records": [] },
                "itens_pedido_compra": { "count": 0, "records": [] },
            }
        }
        payload_json = json.dumps(data_tables_records, indent=2, ensure_ascii=False)
        chk = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()
        data_tables_records["checksum_sha256"] = chk

        tmp_path = "tests/temp_tables_records.json"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(data_tables_records, f, indent=2, ensure_ascii=False)

        try:
            with patch("scripts.executar_limpeza_supabase.EXPECTED_CHECKSUM", chk):
                ok, msg = validar_backup(tmp_path)
                self.assertTrue(ok, f"Falhou ao validar estrutura 'tables'/'records': {msg}")
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def test_backup_inexistente(self):
        """Testa que arquivo inexistente aborta a execução."""
        ok, msg = validar_backup("backups/arquivo_fantasma.json")
        self.assertFalse(ok)
        self.assertIn("não encontrado", msg)

    def test_json_invalido(self):
        """Testa que arquivo JSON malformado é rejeitado."""
        tmp_path = "tests/temp_invalid.json"
        with open(tmp_path, "w", encoding="utf-8") as f:
            f.write("{ json_invalido: true ")
        try:
            ok, msg = validar_backup(tmp_path)
            self.assertFalse(ok)
            self.assertIn("Erro ao ler/parsear", msg)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def test_checksum_incorreto(self):
        """Testa que um backup modificado (checksum divergente) é rejeitado sem alterar contagem."""
        corrupted_data = json.loads(json.dumps(self.valid_data))
        corrupted_data["tabelas"]["produtos"][0]["nome"] = "Produto Alterado Maliciosamente"

        tmp_path = "tests/temp_corrupted.json"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(corrupted_data, f, indent=2, ensure_ascii=False)
        try:
            ok, msg = validar_backup(tmp_path)
            self.assertFalse(ok)
            self.assertIn("Checksum do payload divergente", msg)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def test_contagens_inesperadas(self):
        """Testa que contagem diferente do esperado é rejeitada."""
        wrong_count_data = dict(self.valid_data)
        wrong_count_data["tabelas"]["produtos"] = [{"id": 1}] # 1 item instead of 16

        data_copy = dict(wrong_count_data)
        if "checksum_sha256" in data_copy:
            del data_copy["checksum_sha256"]
        new_checksum = hashlib.sha256(json.dumps(data_copy, indent=2, ensure_ascii=False).encode("utf-8")).hexdigest()
        wrong_count_data["checksum_sha256"] = new_checksum

        tmp_path = "tests/temp_wrong_count.json"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(wrong_count_data, f, indent=2, ensure_ascii=False)
        try:
            ok, msg = validar_backup(tmp_path)
            self.assertFalse(ok)
            self.assertIn("Contagem divergente para 'produtos'", msg)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    @patch("scripts.executar_limpeza_supabase.validar_backup")
    def test_modo_simulacao_sem_chamadas_destrutivas(self, mock_validar):
        """Testa se o modo simulation/dry-run retorna sucesso sem abrir Playwright ou Supabase real."""
        mock_validar.return_value = (True, "Backup OK para simulação")
        import asyncio
        res = asyncio.run(executar_limpeza(confirm_cleanup=False, dry_run=True))

        self.assertTrue(res["sucesso"])
        self.assertEqual(res["modo"], "dry-run")

    @patch("scripts.executar_limpeza_supabase.validar_backup")
    def test_ausencia_flag_confirmacao_ativa_dry_run(self, mock_validar):
        """Testa se omitir --confirm-cleanup impede execução destrutiva mesmo com dry_run=False."""
        mock_validar.return_value = (True, "Backup OK")
        import asyncio
        res = asyncio.run(executar_limpeza(confirm_cleanup=False, dry_run=False))

        self.assertTrue(res["sucesso"])
        self.assertEqual(res["modo"], "dry-run")

    @patch("scripts.executar_limpeza_supabase.validar_backup")
    def test_url_destino_inexistente_aborto(self, mock_validar):
        """Testa se falha ao conectar no host de destino aborta com erro tratado."""
        mock_validar.return_value = (True, "Backup OK")
        import asyncio
        res = asyncio.run(executar_limpeza(confirm_cleanup=True, dry_run=False, target_url="http://127.0.0.1:59999/invalid"))

        self.assertFalse(res["sucesso"])
        self.assertIn("Não foi possível acessar a URL do projeto", res["erro"])

    def test_escopo_fixo_restrito(self):
        """Garante que a lista FIXED_CLEANUP_SCOPE contém unicamente as 6 tabelas autorizadas."""
        expected_scope = [
            "itens_pedido_compra",
            "pedidos_compra",
            "transferencias",
            "movimentacoes",
            "estoques",
            "produtos",
        ]
        self.assertEqual(FIXED_CLEANUP_SCOPE, expected_scope)
        self.assertNotIn("usuarios", FIXED_CLEANUP_SCOPE)
        self.assertNotIn("filiais", FIXED_CLEANUP_SCOPE)
        self.assertNotIn("auth.users", FIXED_CLEANUP_SCOPE)


if __name__ == "__main__":
    unittest.main()
