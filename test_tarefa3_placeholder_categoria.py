import asyncio
from playwright.async_api import async_playwright

async def run():
    print("==========================================================")
    print("   TESTE DE INTEGRAÇÃO - PLACEHOLDER DA CATEGORIA (TAREFA 3) ")
    print("==========================================================")

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        # Ir para a página de Produtos
        await page.click("a[data-page='produtos']")
        await page.wait_for_timeout(1000)
        await page.wait_for_selector("#page-produtos.active", timeout=5000)

        # Abrir modal Novo Produto
        await page.click("button:has-text('+ Novo Produto')")
        await page.wait_for_selector("#modal-produto", timeout=5000)

        # Obter placeholder do campo #p-cat
        placeholder = await page.get_attribute("#p-cat", "placeholder")
        print(f"[TEST TAREFA 3] Categoria Placeholder: '{placeholder}'")

        assert placeholder == "Ex: Anéis", f"Placeholder incorreto: esperado 'Ex: Anéis', obtido '{placeholder}'"
        assert "bebida" not in placeholder.lower(), "Placeholder não pode conter referências a bebidas"

        await context.close()
        await browser.close()

    print("\n==========================================================")
    print("   TESTE DO PLACEHOLDER CONCLUÍDO COM 100% DE SUCESSO!   ")
    print("==========================================================")

asyncio.run(run())
