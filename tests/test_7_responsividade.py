import asyncio
from playwright.async_api import async_playwright

async def run_responsividade():
    print("=== STARTING CONSOLIDATED TESTS: RESPONSIVIDADE (GRUPO C) ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # 1. TESTES ORIGINÁRIOS DE test_responsive.py (Viewports Mobile e Tablet)
        print("[TEST 1 - Responsividade] Teste de Viewport Mobile (375x667)")
        context_mobile = await browser.new_context(viewport={"width": 375, "height": 667})
        page_mobile = await context_mobile.new_page()
        await page_mobile.goto("http://localhost:8080/index.html")
        await page_mobile.fill("#login-email", "anderson.func@empresa.com")
        await page_mobile.fill("#login-senha", "etec2026@DS")
        await page_mobile.click("button:has-text('Entrar')")
        await page_mobile.wait_for_selector("#app.active", timeout=10000)

        is_menu_visible = await page_mobile.is_visible("#menu")
        assert is_menu_visible, "Menu pílula móvel não está visível em 375px"
        await context_mobile.close()

        print("[TEST 2 - Responsividade] Teste de Viewport Tablet (768x1024)")
        context_tablet = await browser.new_context(viewport={"width": 768, "height": 1024})
        page_tablet = await context_tablet.new_page()
        await page_tablet.goto("http://localhost:8080/index.html")
        await page_tablet.fill("#login-email", "anderson.func@empresa.com")
        await page_tablet.fill("#login-senha", "etec2026@DS")
        await page_tablet.click("button:has-text('Entrar')")
        await page_tablet.wait_for_selector("#app.active", timeout=10000)

        is_app_visible = await page_tablet.is_visible("#app.active")
        assert is_app_visible, "App container não está visível em 768px"
        await context_tablet.close()

        # 2. TESTES ORIGINÁRIOS DE test_responsivo_t6.py (Menu Pílula e Interações de Modal em Mobile)
        print("[TEST 3 - Responsividade T6] Interações de Menu Pílula e Modais em 390x844")
        context_t6 = await browser.new_context(viewport={"width": 390, "height": 844})
        page_t6 = await context_t6.new_page()
        await page_t6.goto("http://localhost:8080/index.html")
        await page_t6.fill("#login-email", "robson.grt@empresa.com")
        await page_t6.fill("#login-senha", "etec2026@DS")
        await page_t6.click("button:has-text('Entrar')")
        await page_t6.wait_for_selector("#app.active", timeout=10000)

        # Navegação via menu pílula em mobile
        await page_t6.click("a[data-page='produtos']")
        await page_t6.wait_for_selector("#page-produtos.active", timeout=5000)
        is_prod_view_active = await page_t6.is_visible("#page-produtos.active")
        assert is_prod_view_active, "Navegação para Produtos via menu móvel falhou"

        # Abertura e fechamento do modal de produto sem submissão de dados
        await page_t6.click("button:has-text('+ Novo Produto')")
        await page_t6.wait_for_selector("#modal-produto", timeout=5000)
        is_modal_visible = await page_t6.is_visible("#modal-produto")
        assert is_modal_visible, "Modal de produto não abriu em tela móvel"

        # Fechar modal chamando fecharModal()
        await page_t6.evaluate("fecharModal()")
        await page_t6.wait_for_timeout(300)
        is_modal_hidden = not await page_t6.is_visible("#modal-produto")
        assert is_modal_hidden, "Modal de produto não fechou corretamente"

        await context_t6.close()
        await browser.close()
        print("=== CONSOLIDATED TESTS: RESPONSIVIDADE PASSED SUCCESSFULLY! ===")

if __name__ == "__main__":
    asyncio.run(run_responsividade())
