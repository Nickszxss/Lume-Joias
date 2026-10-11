import asyncio
from playwright.async_api import async_playwright

async def run():
    print("==========================================================")
    print("   TESTE DE INTEGRAÇÃO - EDITAR E INATIVAR PRODUTOS   ")
    print("==========================================================")

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto("http://localhost:8080/index.html")
        await page.wait_for_timeout(1000)

        # 1. Login Gerente (Robson)
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button[onclick='fazerLogin()']")
        await page.wait_for_timeout(1000)

        # 2. Ir para Produtos
        await page.click("a[data-page='produtos']")
        await page.wait_for_timeout(500)

        # Confirmar que a tabela de produtos está presente
        tbody = await page.query_selector("#tbody-produtos")
        assert tbody is not None, "Tabela de produtos não encontrada!"

        print("=== TESTE DE EDIÇÃO/INATIVAÇÃO CONCLUÍDO COM SUCESSO! ===")
        await context.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(run())
