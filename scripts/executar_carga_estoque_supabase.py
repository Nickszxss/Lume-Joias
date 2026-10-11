import argparse
import json
import sys
import asyncio
from playwright.async_api import async_playwright

EXPECTED_MATRIX = {
    "Colar de prata": {"sku": "01", "Centro": 32, "Norte": 15, "Sul": 48, "Leste": 7, "Oeste": 56},
    "Colar de ouro": {"sku": "02", "Centro": 12, "Norte": 41, "Sul": 23, "Leste": 59, "Oeste": 5},
    "Anel de prata": {"sku": "03", "Centro": 54, "Norte": 28, "Sul": 9, "Leste": 36, "Oeste": 17},
    "Anel de ouro": {"sku": "04", "Centro": 21, "Norte": 63, "Sul": 14, "Leste": 44, "Oeste": 30},
    "Brinco de prata": {"sku": "05", "Centro": 46, "Norte": 8, "Sul": 35, "Leste": 19, "Oeste": 61},
    "Brinco de ouro": {"sku": "06", "Centro": 6, "Norte": 52, "Sul": 27, "Leste": 38, "Oeste": 13},
    "Solitária": {"sku": "07", "Centro": 39, "Norte": 18, "Sul": 64, "Leste": 11, "Oeste": 25},
    "Pulseira de prata": {"sku": "08", "Centro": 16, "Norte": 43, "Sul": 3, "Leste": 57, "Oeste": 31},
    "Pulseira de ouro": {"sku": "09", "Centro": 60, "Norte": 24, "Sul": 33, "Leste": 2, "Oeste": 47},
}

EXPECTED_FILIAL_TOTAIS = {
    "Filial Centro": 286,
    "Filial Norte": 292,
    "Filial Sul": 256,
    "Filial Leste": 273,
    "Filial Oeste": 285,
}

EXPECTED_TOTAL_UNIDADES = 1392
EXPECTED_COMBINACOES = 45


def validar_matriz_local():
    """Valida estaticamente os totais da matriz e combinações esperadas."""
    totais = {"Filial Centro": 0, "Filial Norte": 0, "Filial Sul": 0, "Filial Leste": 0, "Filial Oeste": 0}
    total_geral = 0
    combinações = 0

    mapa_filiais = {
        "Centro": "Filial Centro",
        "Norte": "Filial Norte",
        "Sul": "Filial Sul",
        "Leste": "Filial Leste",
        "Oeste": "Filial Oeste",
    }

    for prod, dados in EXPECTED_MATRIX.items():
        for f_curto, qtd in dados.items():
            if f_curto == "sku":
                continue
            f_nome = mapa_filiais[f_curto]
            totais[f_nome] += qtd
            total_geral += qtd
            combinações += 1

    if combinações != EXPECTED_COMBINACOES:
        return False, f"Combinações divergentes: {combinações} (esperado: {EXPECTED_COMBINACOES})"

    if total_geral != EXPECTED_TOTAL_UNIDADES:
        return False, f"Total geral divergente: {total_geral} (esperado: {EXPECTED_TOTAL_UNIDADES})"

    for f_nome, exp_tot in EXPECTED_FILIAL_TOTAIS.items():
        if totais[f_nome] != exp_tot:
            return False, f"Total para '{f_nome}' divergente: {totais[f_nome]} (esperado: {exp_tot})"

    return True, "Matriz estática validada com sucesso (1.392 unidades, 45 combinações, totais por filial OK)."


async def executar_carga_estoque(confirm_load=False, dry_run=True, target_url="http://localhost:8080/index.html"):
    print("=== MECANISMO DE CARGA INICIAL DE ESTOQUE SUPABASE (MODO VIA RPC) ===")

    # 1. Validação local da matriz
    ok_matriz, msg_matriz = validar_matriz_local()
    print(f"[VALIDAÇÃO MATRIZ]: {msg_matriz}")
    if not ok_matriz:
        return {"sucesso": False, "erro": msg_matriz}

    # 2. Modo Simulação / Dry-Run
    if dry_run or not confirm_load:
        print("\n--- MODO SIMULAÇÃO / DRY-RUN ATIVO ---")
        print("Nenhuma escrita será realizada no Supabase.")
        print(f"URL Alvo: {target_url}")
        print("Totais Validados da Matriz:")
        for f_nome, exp_tot in EXPECTED_FILIAL_TOTAIS.items():
            print(f"  - {f_nome}: {exp_tot} unidades")
        print(f"Total Geral: {EXPECTED_TOTAL_UNIDADES} unidades em {EXPECTED_COMBINACOES} combinações.")
        print("Para executar a carga real no futuro via RPC, é obrigatório aplicar a migration SQL e passar --confirm-load.")
        return {"sucesso": True, "modo": "dry-run", "mensagem": "Simulação concluída com sucesso."}

    # 3. Execução Controlada Transacional via RPC (Somente com --confirm-load)
    print("\n--- INICIANDO CHAMADA RPC TRANSACIONAL CONTRA O SUPABASE ---")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        try:
            await page.goto(target_url)
            await page.wait_for_timeout(1000)
        except Exception as e:
            await context.close()
            await browser.close()
            return {"sucesso": False, "erro": f"Não foi possível acessar a URL do projeto: {str(e)}"}

        result = await page.evaluate("""async () => {
            const client = window.supabaseClient || window.initSupabase();
            if (!client) return { error: 'Cliente Supabase não disponível' };

            // Invocação da função RPC transacional atômica no PostgreSQL
            const { data, error } = await client.rpc('executar_carga_inicial_estoque_rpc');
            if (error) {
                return { sucesso: false, error: 'Falha na execução RPC (Rollback executado): ' + error.message };
            }

            return data;
        }""")

        await context.close()
        await browser.close()

        print("[RESULTADO EXECUÇÃO RPC]:", json.dumps(result, indent=2))
        return result


def main():
    parser = argparse.ArgumentParser(description="Mecanismo de Carga Inicial Transacional de Estoque - Lume-Joias")
    parser.add_argument("--confirm-load", action="store_true", help="Confirma a execução real da carga via RPC no Supabase.")
    parser.add_argument("--dry-run", action="store_true", default=False, help="Executa apenas a simulação e validação da matriz (Padrão).")

    args = parser.parse_args()

    dry_run_flag = True if not args.confirm_load else args.dry_run
    res = asyncio.run(executar_carga_estoque(confirm_load=args.confirm_load, dry_run=dry_run_flag))

    if not res.get("sucesso", False):
        sys.exit(1)


if __name__ == "__main__":
    main()
