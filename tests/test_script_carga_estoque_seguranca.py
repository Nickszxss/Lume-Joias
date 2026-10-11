import os
import sys
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from scripts.executar_carga_estoque_supabase import (
    EXPECTED_MATRIX,
    EXPECTED_FILIAL_TOTAIS,
    EXPECTED_TOTAL_UNIDADES,
    EXPECTED_COMBINACOES,
    validar_matriz_local,
    executar_carga_estoque,
)


class TestScriptCargaEstoqueSeguranca(unittest.TestCase):

    def test_validacao_matriz_estatica_sucesso(self):
        """Testa se os totais oficiais da matriz conferem com os 1.392 itens e 45 combinações."""
        ok, msg = validar_matriz_local()
        self.assertTrue(ok, f"Falha na validação local da matriz: {msg}")
        self.assertIn("1.392 unidades", msg)

    def test_modo_simulacao_dry_run_padrao(self):
        """Testa se omitir --confirm-load ativa o modo simulação sem chamadas ao Supabase."""
        import asyncio
        res = asyncio.run(executar_carga_estoque(confirm_load=False, dry_run=True))

        self.assertTrue(res["sucesso"])
        self.assertEqual(res["modo"], "dry-run")
        self.assertIn("Simulação concluída com sucesso", res["mensagem"])

    def test_estrutura_matriz_produtos_skus(self):
        """Testa se a matriz contém exatamente os 9 produtos com SKUs de 2 dígitos ('01' a '09')."""
        self.assertEqual(len(EXPECTED_MATRIX), 9)
        skus_encontrados = set()
        for prod_nome, dados in EXPECTED_MATRIX.items():
            sku = dados["sku"]
            self.assertEqual(len(sku), 2, f"SKU {sku} de {prod_nome} deve ter 2 dígitos")
            skus_encontrados.add(sku)

        self.assertEqual(len(skus_encontrados), 9)
        self.assertEqual(skus_encontrados, {"01", "02", "03", "04", "05", "06", "07", "08", "09"})

    def test_totais_por_filial_oficiais(self):
        """Testa se os totais das 5 filiais conferem exatamente com as somas das linhas."""
        totais_calculados = {
            "Filial Centro": 0,
            "Filial Norte": 0,
            "Filial Sul": 0,
            "Filial Leste": 0,
            "Filial Oeste": 0,
        }
        mapa_filiais = {
            "Centro": "Filial Centro",
            "Norte": "Filial Norte",
            "Sul": "Filial Sul",
            "Leste": "Filial Leste",
            "Oeste": "Filial Oeste",
        }

        for prod_nome, dados in EXPECTED_MATRIX.items():
            for f_curto, qtd in dados.items():
                if f_curto == "sku":
                    continue
                totais_calculados[mapa_filiais[f_curto]] += qtd

        self.assertEqual(totais_calculados["Filial Centro"], 286)
        self.assertEqual(totais_calculados["Filial Norte"], 292)
        self.assertEqual(totais_calculados["Filial Sul"], 256)
        self.assertEqual(totais_calculados["Filial Leste"], 273)
        self.assertEqual(totais_calculados["Filial Oeste"], 285)
        self.assertEqual(sum(totais_calculados.values()), 1392)

    def test_matriz_incorreta_rejeicao(self):
        """Testa se matriz com soma alterada é rejeitada pela pré-validação estática."""
        matriz_corrompida = {k: dict(v) for k, v in EXPECTED_MATRIX.items()}
        matriz_corrompida["Colar de prata"]["Centro"] = 999
        with patch("scripts.executar_carga_estoque_supabase.EXPECTED_MATRIX", matriz_corrompida):
            ok, msg = validar_matriz_local()
            self.assertFalse(ok)
            self.assertIn("Total geral divergente", msg)


if __name__ == "__main__":
    unittest.main()
