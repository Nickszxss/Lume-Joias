import asyncio
from playwright.async_api import async_playwright

TEST_USERS = [
    {"email": "anderson.func@empresa.com", "senha": "etec2026@DS", "nome": "Anderson", "cargo": "Funcionário"},
    {"email": "isabella.func@empresa.com", "senha": "etec2026@DS", "nome": "Isabella", "cargo": "Funcionário"},
    {"email": "nicoly.func@empresa.com", "senha": "160611", "nome": "Nicoly", "cargo": "Funcionário"},
    {"email": "robson.grt@empresa.com", "senha": "etec2026@DS", "nome": "Robson", "cargo": "Gerente"},
    {"email": "manuella.grt@empresa.com", "senha": "etec2026@DS", "nome": "Manuella", "cargo": "Gerente"},
    {"email": "nicoly.grt@empresa.com", "senha": "160611", "nome": "Nicoly", "cargo": "Gerente"},
]

async def run():
    print("=== STARTING TAREFA 5 - PRODUCT CLEANUP AND USER PRESERVATION TESTS ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # Test 1: Verify all 6 user logins work seamlessly
        for usr in TEST_USERS:
            context = await browser.new_context()
            page = await context.new_page()
            await page.goto("http://localhost:8080/index.html")
            await page.fill("#login-email", usr["email"])
            await page.fill("#login-senha", usr["senha"])
            await page.click("button:has-text('Entrar')")
            await page.wait_for_selector("#app.active", timeout=10000)

            logged_name = await page.text_content("#user-nome")
            logged_type = await page.text_content("#user-tipo")
            print(f"[USER LOGIN SUCCESS] Email: {usr['email']} -> Name: {logged_name}, Role: {logged_type}")
            assert usr["nome"] in logged_name, f"Expected {usr['nome']} in logged name"

            # Check Produtos table cleared state
            await page.click("a[data-page='produtos']")
            await page.wait_for_selector("#page-produtos.active", timeout=5000)
            await page.wait_for_timeout(500)

            tbody_produtos = await page.text_content("#tbody-produtos")
            print(f"[{usr['cargo']} VIEW - Produtos Table]:", tbody_produtos.strip())
            assert "Nenhum produto" in tbody_produtos or len(tbody_produtos.strip()) == 0, "Products table not properly cleared"

            await context.close()

        print("=== ALL 6 USERS VERIFIED SUCCESSFULLY & PRODUCTS CLEARED ===")
        await browser.close()

asyncio.run(run())
