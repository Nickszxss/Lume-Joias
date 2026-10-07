import asyncio
from playwright.async_api import async_playwright

EXPECTED_SKUS = {
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

async def run():
    print("=== STARTING TAREFA 3 - AUTOMATIC SKU PREFILL TESTS ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1000)

        # Navigate to Produtos
        await page.click("a[data-page='produtos']")
        await page.wait_for_selector("#page-produtos.active", timeout=5000)
        await page.wait_for_timeout(1000)

        # Open Modal
        await page.click("button:has-text('+ Novo Produto')")
        await page.wait_for_selector("#modal-produto", timeout=5000)

        # Test all 9 types in modal to confirm SKU auto-updates dynamically
        for prod_tipo, expected_sku in EXPECTED_SKUS.items():
            await page.select_option("#p-nome", value=prod_tipo)
            await page.wait_for_timeout(200)
            current_sku = await page.input_value("#p-sku")
            print(f"[MODAL TEST] Type: '{prod_tipo}' -> Auto SKU: '{current_sku}'")
            assert current_sku == expected_sku, f"Expected {expected_sku} for {prod_tipo}, got {current_sku}"

        # Now save a product with type 'Pulseira de ouro' (SKU: 009) for Filial Leste (ID 4)
        await page.select_option("#p-nome", value="Pulseira de ouro")
        await page.select_option("#p-filial", value="4") # Filial Leste
        await page.fill("#p-min", "3")
        await page.fill("#p-qtd", "12")
        await page.click("#modal-produto button:has-text('Salvar')")
        await page.wait_for_timeout(1000)

        toast_text = await page.text_content("#toast")
        print("[TEST SAVE] Toast:", toast_text)
        assert "sucesso" in toast_text.lower(), "Product save failed"

        # Check product row in Produtos table
        prod_table_rows = await page.text_content("#tbody-produtos")
        print("[TEST TABLE] Table content after save:\n", prod_table_rows)
        assert "009" in prod_table_rows and "Pulseira de ouro" in prod_table_rows, "Saved SKU 009 not found in table"

        # Test Page Reload (F5) persistence
        await page.reload()
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.click("a[data-page='produtos']")
        await page.wait_for_selector("#page-produtos.active", timeout=5000)
        await page.wait_for_timeout(1000)

        reloaded_table_rows = await page.text_content("#tbody-produtos")
        print("[TEST PERSISTENCE] Table content after F5 reload:\n", reloaded_table_rows)
        assert "009" in reloaded_table_rows and "Pulseira de ouro" in reloaded_table_rows, "SKU 009 persistence check failed after F5 reload"

        await context.close()
        await browser.close()

    print("=== ALL TAREFA 3 SKU TESTS PASSED SUCCESSFULLY! ===")

asyncio.run(run())
