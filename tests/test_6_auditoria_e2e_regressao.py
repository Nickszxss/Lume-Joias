import asyncio
from playwright.async_api import async_playwright

async def test_auditoria_e2e_regressao():
    print("=== TESTE CONSOLIDADO 6: AUDITORIA E2E E REGRESSÃO FINAL ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto("http://localhost:8080/index.html")
        await page.wait_for_timeout(1000)

        # 1. Login como Gerente (Robson - Filial Oeste 5)
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button[onclick='fazerLogin()']")
        await page.wait_for_timeout(1000)

        # 2. Navegar e verificar todas as 7 telas da aplicação
        telas = ["dashboard", "produtos", "estoque", "transferencias", "pedidos", "alertas", "historico"]
        for tela in telas:
            await page.click(f"a[data-page='{tela}']")
            await page.wait_for_timeout(400)
            page_el = await page.query_selector(f"#page-{tela}")
            assert page_el is not None, f"Tela {tela} não encontrada no DOM!"

        # 3. Testar Logout
        await page.click("button[onclick='sair()']")
        await page.wait_for_timeout(500)
        login_screen = await page.query_selector("#login-screen")
        assert login_screen is not None, "Falha ao deslogar!"

        print("[SUCESSO]: Teste de Auditoria E2E e Regressão Final aprovado 100%!")
        await context.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(test_auditoria_e2e_regressao())
