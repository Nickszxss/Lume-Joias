import argparse
import hashlib
import json
import os
import sys
import asyncio
from playwright.async_api import async_playwright

BACKUP_FILE_PATH = "backups/backup_sge_lume_joias_2026-10-10_17-23-07.json"
EXPECTED_CHECKSUM = "0d4f71e123edc20946fd9b32777ed11ef9a77eceac91b1ace02fbfd709d3c248"

FIXED_CLEANUP_SCOPE = [
    "itens_pedido_compra",
    "pedidos_compra",
    "transferencias",
    "movimentacoes",
    "estoques",
    "produtos",
]

EXPECTED_BACKUP_COUNTS = {
    "produtos": 16,
    "estoques": 16,
    "movimentacoes": 0,
    "transferencias": 0,
    "pedidos_compra": 0,
    "itens_pedido_compra": 0,
}


def validar_backup(backup_path=BACKUP_FILE_PATH):
    """Valida a existência, leitura, esquema, contagens e checksum do arquivo de backup."""
    if not os.path.exists(backup_path):
        return False, f"Arquivo de backup não encontrado no caminho: {backup_path}"

    try:
        with open(backup_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        return False, f"Erro ao ler/parsear arquivo de backup JSON: {str(e)}"

    if not isinstance(data, dict):
        return False, "Estrutura do backup é inválida (deve ser um objeto JSON)."

    # Aceitar tanto 'tables' quanto 'tabelas' para suporte à estrutura real do backup
    tabelas_backup = data.get("tables", data.get("tabelas"))
    if not isinstance(tabelas_backup, dict):
        return False, "Seção 'tables'/'tabelas' ausente ou inválida no backup."

    for tabela, expected_count in EXPECTED_BACKUP_COUNTS.items():
        if tabela not in tabelas_backup:
            return False, f"Tabela operacional obrigatória '{tabela}' ausente no backup."

        entry = tabelas_backup[tabela]
        if isinstance(entry, dict) and "records" in entry:
            registros = entry["records"]
        elif isinstance(entry, list):
            registros = entry
        else:
            return False, f"Conteúdo da tabela '{tabela}' deve conter uma lista ou sub-objeto 'records'."

        if not isinstance(registros, list):
            return False, f"Registros da tabela '{tabela}' devem ser uma lista."

        if len(registros) != expected_count:
            return False, (
                f"Contagem divergente para '{tabela}': esperado {expected_count}, "
                f"encontrado {len(registros)} no backup."
            )

    # Validar Checksum SHA-256 do Payload
    saved_checksum = data.get("checksum_sha256")
    data_copy = dict(data)
    if "checksum_sha256" in data_copy:
        del data_copy["checksum_sha256"]

    payload_json = json.dumps(data_copy, indent=2, ensure_ascii=False)
    calculated_checksum = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()

    if calculated_checksum != EXPECTED_CHECKSUM:
        return False, (
            f"Checksum do payload divergente! Calculado: {calculated_checksum}, "
            f"Esperado: {EXPECTED_CHECKSUM}"
        )

    if saved_checksum and saved_checksum != EXPECTED_CHECKSUM:
        return False, (
            f"Checksum salvo no JSON ({saved_checksum}) divergi com o esperado ({EXPECTED_CHECKSUM})."
        )

    return True, "Backup validado com sucesso (existência, contagens, estrutura e checksum SHA-256 OK)."


async def executar_limpeza(confirm_cleanup=False, dry_run=True, target_url="http://localhost:8080/index.html"):
    print("=== SCRIPT DE LIMPEZA OPERACIONAL SUPABASE ===")
    print("[AVISO]: Operação REST PostgREST não atômica (sem rollback automático em falhas intermediárias).")

    # 1. Validação Obrigatória de Backup
    backup_ok, msg_backup = validar_backup()
    print(f"[VALUDAÇÃO BACKUP]: {msg_backup}")
    if not backup_ok:
        print("[ERRO CRÍTICO]: Abortando execução devido a falha na validação do backup local.")
        return {"sucesso": False, "erro": msg_backup}

    # 2. Modo Simulação / Dry-Run por Padrão
    if dry_run or not confirm_cleanup:
        print("\n--- MODO SIMULAÇÃO / DRY-RUN ATIVO ---")
        print("Nenhuma exclusão será realizada no Supabase.")
        print(f"Projeto de Destino Alvo: {target_url}")
        print("Escopo Fixo de Tabelas a Limpar (Ordem Sequencial FK):")
        for idx, tbl in enumerate(FIXED_CLEANUP_SCOPE, 1):
            ref_count = EXPECTED_BACKUP_COUNTS.get(tbl, 0)
            print(f"  {idx}. public.{tbl} (Contagem no Backup: {ref_count})")
        print("Tabelas Protegidas (Isoladas): public.usuarios, public.filiais, auth.users.")
        print("Para executar deleções reais no futuro, é obrigatório passar a flag --confirm-cleanup.")
        return {"sucesso": True, "modo": "dry-run", "mensagem": "Simulação concluída com sucesso."}

    # 3. Execução Destrutiva com Playwright (Somente com --confirm-cleanup)
    print("\n--- INICIANDO EXECUÇÃO DESTRUTIVA CONTRA O SUPABASE ---")
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
            if (!client) return { error: 'Cliente Supabase não disponível no contexto da página' };

            const res = { etapas: [], sucesso: true };

            // 1. Identificar e Validar Usuários e Filiais Antes da Limpeza
            const { data: usersBefore, error: errUsers } = await client.from('usuarios').select('id');
            const { data: filiaisBefore, error: errFiliais } = await client.from('filiais').select('id');

            if (errUsers || !usersBefore || usersBefore.length === 0) {
                return { sucesso: false, error: 'Falha ao validar identidades de usuarios antes da limpeza: ' + (errUsers?.message || 'dados vazios') };
            }
            if (errFiliais || !filiaisBefore || filiaisBefore.length === 0) {
                return { sucesso: false, error: 'Falha ao validar identidades de filiais antes da limpeza: ' + (errFiliais?.message || 'dados vazios') };
            }

            res.usuarios_ids_antes = usersBefore.map(u => u.id);
            res.filiais_ids_antes = filiaisBefore.map(f => f.id);

            // Escopo Fixo Sequencial Fail-Fast
            const scope = [
                'itens_pedido_compra',
                'pedidos_compra',
                'transferencias',
                'movimentacoes',
                'estoques',
                'produtos'
            ];

            for (const tabela of scope) {
                const { count, error } = await client.from(tabela).delete({ count: 'exact' }).neq('id', 0);
                if (error) {
                    res.sucesso = false;
                    res.erro_etapa = { tabela, erro: error.message };
                    res.etapas.push({ tabela, status: 'FALHA', erro: error.message });
                    // FAIL-FAST: Interrompe imediatamente as etapas seguintes
                    break;
                }
                res.etapas.push({ tabela, status: 'OK', registros_removidos: count });
            }

            // Validar Usuários e Filiais Após a Limpeza se houve sucesso
            if (res.sucesso) {
                const { data: usersAfter } = await client.from('usuarios').select('id');
                const { data: filiaisAfter } = await client.from('filiais').select('id');
                res.usuarios_ids_depois = usersAfter ? usersAfter.map(u => u.id) : [];
                res.filiais_ids_depois = filiaisAfter ? filiaisAfter.map(f => f.id) : [];

                // Validar Preservação Exata de Identidades
                const usersEqual = JSON.stringify(res.usuarios_ids_antes.sort()) === JSON.stringify(res.usuarios_ids_depois.sort());
                const filiaisEqual = JSON.stringify(res.filiais_ids_antes.sort()) === JSON.stringify(res.filiais_ids_depois.sort());

                if (!usersEqual || !filiaisEqual) {
                    res.sucesso = false;
                    res.error = 'VIOLAÇÃO DE DADOS PROTEGIDOS: Registros de usuarios ou filiais foram alterados!';
                }
            }

            return res;
        }""")

        await context.close()
        await browser.close()

        print("[RESULTADO EXECUÇÃO]:", json.dumps(result, indent=2))
        return result


def main():
    parser = argparse.ArgumentParser(description="Script de Limpeza Operacional do Lume-Joias")
    parser.add_argument("--confirm-cleanup", action="store_true", help="Confirma a execução destrutiva real das exclusões.")
    parser.add_argument("--dry-run", action="store_true", default=False, help="Executa apenas a simulação e validação do backup (Padrão).")

    args = parser.parse_args()

    # Executar assincronamente
    dry_run_flag = True if not args.confirm_cleanup else args.dry_run
    res = asyncio.run(executar_limpeza(confirm_cleanup=args.confirm_cleanup, dry_run=dry_run_flag))

    if not res.get("sucesso", False):
        sys.exit(1)


if __name__ == "__main__":
    main()
