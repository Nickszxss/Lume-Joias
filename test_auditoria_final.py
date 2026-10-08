import asyncio
from playwright.async_api import async_playwright

EXPECTED_SKU_MAP = {
    "Colar de prata": "001",
    "Colar de ouro": "002",
    "Anel de prata": "003",
    "Anel de ouro": "004",
    "Brinco de prata": "005",
    "Brinco de ouro": "006",
    "Solitária": "007",
    "Pulseira de prata": "008",
    "Pulseira de ouro": "009"
}

ALL_USERS = [
    {"email": "anderson.func@empresa.com", "senha": "etec2026@DS", "nome": "Anderson", "cargo": "funcionario"},
    {"email": "isabella.func@empresa.com", "senha": "etec2026@DS", "nome": "Isabella", "cargo": "funcionario"},
    {"email": "nicoly.func@empresa.com", "senha": "160611", "nome": "Nicoly", "cargo": "funcionario"},
    {"email": "robson.grt@empresa.com", "senha": "etec2026@DS", "nome": "Robson", "cargo": "gerente"},
    {"email": "manuella.grt@empresa.com", "senha": "etec2026@DS", "nome": "Manuella", "cargo": "gerente"},
    {"email": "nicoly.grt@empresa.com", "senha": "160611", "nome": "Nicoly", "cargo": "gerente"}
]

BRANCHES = {
    "Centro": "Filial Centro",
    "Norte": "Filial Norte",
    "Sul": "Filial Sul",
    "Leste": "Filial Leste",
    "Oeste": "Filial Oeste"
}

async def run():
    print("==========================================================")
    print("      AUDITORIA FINAL DAS ALTERAÇÕES - SGE LUME JOIAS     ")
    print("==========================================================")

    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # --------------------------------------------------------
        # AUDITORIA 1: AUTENTICAÇÃO E PRESERVAÇÃO DE USUÁRIOS
        # --------------------------------------------------------
        print("\n--- 1. AUDITORIA DE LOGIN E PRESERVAÇÃO DE USUÁRIOS ---")
        for u in ALL_USERS:
            context = await browser.new_context()
            page = await context.new_page()
            await page.goto("http://localhost:8080/index.html")
            await page.fill("#login-email", u["email"])
            await page.fill("#login-senha", u["senha"])
            await page.click("button:has-text('Entrar')")
            await page.wait_for_selector("#app.active", timeout=10000)

            logged_name = await page.text_content("#user-nome")
            logged_role = await page.text_content("#user-tipo")
            print(f"[AUDIT LOGIN OK] {u['email']} -> Nome: {logged_name.strip()} ({logged_role.strip()})")
            assert u["nome"] in logged_name, f"Login failed for {u['email']}"
            await context.close()

        # --------------------------------------------------------
        # AUDITORIA 2: MAPA DE SKUS (001 a 009)
        # --------------------------------------------------------
        print("\n--- 2. AUDITORIA DA TABELA OFICIAL DE SKUS (001 - 009) ---")
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1000)

        await page.click("a[data-page='produtos']")
        await page.wait_for_selector("#page-produtos.active", timeout=5000)
        await page.wait_for_timeout(1000)
        await page.click("button:has-text('+ Novo Produto')")
        await page.wait_for_selector("#modal-produto", timeout=5000)

        for prod_type, expected_sku in EXPECTED_SKU_MAP.items():
            await page.select_option("#p-nome", value=prod_type)
            await page.wait_for_timeout(200)
            sku_val = await page.input_value("#p-sku")
            print(f"[AUDIT SKU OK] Tipo: '{prod_type}' => SKU: '{sku_val}'")
            assert sku_val == expected_sku, f"SKU mismatch for {prod_type}: expected {expected_sku}, got {sku_val}"

        # --------------------------------------------------------
        # AUDITORIA 3: CADASTRO POR FILIAL E PERSISTÊNCIA F5
        # --------------------------------------------------------
        print("\n--- 3. AUDITORIA DE CADASTRO POR FILIAL ÚNICA E PERSISTÊNCIA F5 ---")
        # Cadastrar 'Solitária' (SKU 007) vinculado EXCLUSIVAMENTE à Filial Leste (ID 4)
        await page.select_option("#p-nome", value="Solitária")
        await page.select_option("#p-filial", value="4") # Filial Leste
        await page.fill("#p-min", "2")
        await page.fill("#p-qtd", "8")
        await page.click("#modal-produto button:has-text('Salvar')")
        await page.wait_for_timeout(1000)

        toast_msg = await page.text_content("#toast")
        print("[AUDIT SAVE TOAST]:", toast_msg.strip())
        assert "sucesso" in toast_msg.lower(), "Save product failed"

        # Verificar se está no Estoque da Filial Leste
        await page.click("a[data-page='estoque']")
        await page.wait_for_selector("#page-estoque.active", timeout=5000)
        await page.wait_for_timeout(1000)

        await page.click("#estoque-filiais button:has-text('Leste')")
        await page.wait_for_timeout(500)
        rows_leste = await page.text_content("#tbody-estoque")
        print("[AUDIT ESTOQUE LESTE]:\n", rows_leste.strip())
        assert "Solitária" in rows_leste and "Filial Leste" in rows_leste, "Product not in Filial Leste stock"

        # Verificar se NÃO VAZOU para Filial Centro (ID 1)
        await page.click("#estoque-filiais button:has-text('Centro')")
        await page.wait_for_timeout(500)
        rows_centro = await page.text_content("#tbody-estoque")
        print("[AUDIT ESTOQUE CENTRO - VAZAMENTO CHECK]:\n", rows_centro.strip())
        assert "Solitária" not in rows_centro, "Product leaked into Filial Centro!"

        # F5 Reload e confirmação de persistência
        await page.reload()
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.click("a[data-page='produtos']")
        await page.wait_for_selector("#page-produtos.active", timeout=5000)
        await page.wait_for_timeout(1000)
        prod_table_f5 = await page.text_content("#tbody-produtos")
        print("[AUDIT F5 PERSISTENCE OK] Table after reload:\n", prod_table_f5.strip())
        assert "007" in prod_table_f5 and "Solitária" in prod_table_f5, "F5 persistence check failed"

        # --------------------------------------------------------
        # AUDITORIA 4: FILTRO DE FILIAIS NO ESTOQUE
        # --------------------------------------------------------
        print("\n--- 4. AUDITORIA DE FILTRAGEM POR FILIAL NO ESTOQUE ---")
        await page.click("a[data-page='estoque']")
        await page.wait_for_selector("#page-estoque.active", timeout=5000)
        await page.wait_for_timeout(1000)

        for btn_label, branch_full_name in BRANCHES.items():
            await page.click(f"#estoque-filiais button:has-text('{btn_label}')")
            await page.wait_for_timeout(500)
            b_rows = await page.text_content("#tbody-estoque")
            print(f"[AUDIT FILTER '{btn_label}'] Filtered successfully.")
            if "Nenhum produto" not in b_rows and len(b_rows.strip()) > 0:
                assert branch_full_name in b_rows, f"Missing {branch_full_name} in filter"
                for other_btn, other_full_name in BRANCHES.items():
                    if other_full_name != branch_full_name:
                        assert other_full_name not in b_rows, f"Data leak: found {other_full_name} under {branch_full_name}"

        # --------------------------------------------------------
        # AUDITORIA 5: BANCO DE DADOS NO SUPABASE
        # --------------------------------------------------------
        print("\n--- 5. AUDITORIA DE ESTRUTURA E ESTADO NO SUPABASE ---")
        db_audit = await page.evaluate("""async () => {
            const client = window.supabaseClient || window.initSupabase();
            if (!client) return { error: 'Supabase client missing' };

            const { data: users } = await client.from('usuarios').select('id, email, cargo');
            const { data: filiais } = await client.from('filiais').select('id, nome');
            const { data: prods } = await client.from('produtos').select('id, nome, codigo');

            return {
                totalUsuarios: users ? users.length : 0,
                totalFiliais: filiais ? filiais.length : 0,
                totalProdutosAtuais: prods ? prods.length : 0
            };
        }""")
        print("[AUDIT SUPABASE DB STATE]:", db_audit)
        assert db_audit["totalUsuarios"] in (6, 7), "Users account count mismatch in Supabase"
        assert db_audit["totalFiliais"] == 5, "Filiais count mismatch in Supabase"

        await context.close()
        await browser.close()

    print("\n==========================================================")
    print("      AUDITORIA FINAL CONCLUÍDA COM 100% DE SUCESSO!     ")
    print("==========================================================")

asyncio.run(run())
