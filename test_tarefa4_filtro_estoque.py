import asyncio
from playwright.async_api import async_playwright

BRANCH_NAMES = {
    "Centro": "Filial Centro",
    "Norte": "Filial Norte",
    "Sul": "Filial Sul",
    "Leste": "Filial Leste",
    "Oeste": "Filial Oeste"
}

async def run():
    print("=== STARTING TAREFA 4 - ESTOQUE BRANCH FILTERING TESTS ===")
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

        # Navigate to Estoque
        await page.click("a[data-page='estoque']")
        await page.wait_for_selector("#page-estoque.active", timeout=5000)
        await page.wait_for_timeout(1000)

        # Test "Todas as filiais" default view
        all_rows_text = await page.text_content("#tbody-estoque")
        print("[FILTER TEST - Todas] Content loaded successfully.")
        assert len(all_rows_text) > 0, "All branches stock content empty"

        # Test each individual branch button
        for button_label, expected_branch_name in BRANCH_NAMES.items():
            button_selector = f"#estoque-filiais button:has-text('{button_label}')"
            await page.click(button_selector)
            await page.wait_for_timeout(500)

            filtered_rows_text = await page.text_content("#tbody-estoque")
            print(f"[FILTER TEST - {expected_branch_name}] Rows:\n{filtered_rows_text}")

            if "Nenhum produto" not in filtered_rows_text and len(filtered_rows_text.strip()) > 0:
                assert expected_branch_name in filtered_rows_text, f"Expected {expected_branch_name} in filtered table"
                for other_label, other_branch_name in BRANCH_NAMES.items():
                    if other_branch_name != expected_branch_name:
                        assert other_branch_name not in filtered_rows_text, f"Leaked {other_branch_name} when filtering for {expected_branch_name}"

        # Test "Todas" button reload
        await page.click("#estoque-filiais button:has-text('Todas')")
        await page.wait_for_timeout(500)
        all_reloaded = await page.text_content("#tbody-estoque")
        print("[FILTER TEST - Back to Todas] Loaded successfully.")

        # Test Page Reload (F5) persistence on Estoque page
        await page.reload()
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.click("a[data-page='estoque']")
        await page.wait_for_selector("#page-estoque.active", timeout=5000)
        await page.wait_for_timeout(1000)
        f5_content = await page.text_content("#tbody-estoque")
        print("[FILTER TEST - F5 Reload] Content loaded successfully.")
        assert len(f5_content) > 0, "F5 Reload stock content empty"

        await context.close()
        await browser.close()

    print("=== ALL TAREFA 4 ESTOQUE FILTER TESTS PASSED SUCCESSFULLY! ===")

asyncio.run(run())
