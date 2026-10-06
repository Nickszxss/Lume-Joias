import asyncio
import os
from playwright.async_api import async_playwright

async def run():
    print("=== STARTING PURCHASE ORDERS INTEGRATION TESTS ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # Test 1: Manager (Robson) Creates Purchase Order
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        # Go to Pedidos de Compra page
        await page.click("a[data-page='pedidos']")
        await page.wait_for_selector("#page-pedidos.active", timeout=5000)
        await page.wait_for_timeout(500)

        # Open Modal
        await page.click("#btn-novo-pedido")
        await page.wait_for_selector("#modal-pedido", timeout=5000)

        # Select product, filial, quantity
        await page.select_option("#pc-produto", index=0)
        await page.select_option("#pc-filial", value="2") # Filial Norte
        await page.fill("#pc-qtd", "25")
        await page.click("#modal-pedido button:has-text('Criar Pedido')")
        await page.wait_for_timeout(1000)

        toast_text = await page.text_content("#toast")
        print("[TEST 1 - Create Purchase Order] Toast:", toast_text)
        assert "sucesso" in toast_text.lower(), "Purchase order creation failed"

        # Verify new order in table
        pedidos_rows = await page.text_content("#tbody-pedidos")
        print("[TEST 1 - Table Rows]:", pedidos_rows)
        assert "25" in pedidos_rows, "Quantity 25 not found in pedidos table"
        assert "Filial Norte" in pedidos_rows, "Filial Norte not found in pedidos table"

        # Test 2: Reload Page (F5) and verify persistence
        await page.reload()
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.click("a[data-page='pedidos']")
        await page.wait_for_selector("#page-pedidos.active", timeout=5000)
        await page.wait_for_timeout(1000)
        reloaded_rows = await page.text_content("#tbody-pedidos")
        print("[TEST 2 - Persistence on Reload]:", reloaded_rows)
        assert "25" in reloaded_rows and "Filial Norte" in reloaded_rows, "Persistence check failed"

        # Test 3: Rejection of Invalid Quantity
        await page.click("#btn-novo-pedido")
        await page.wait_for_selector("#modal-pedido", timeout=5000)
        await page.fill("#pc-qtd", "0")
        await page.click("#modal-pedido button:has-text('Criar Pedido')")
        await page.wait_for_timeout(500)
        invalid_toast = await page.text_content("#toast")
        print("[TEST 3 - Invalid Quantity] Toast:", invalid_toast)
        assert "quantidade válida" in invalid_toast.lower(), "Invalid quantity rejection failed"
        await page.evaluate("fecharModal()")
        await page.wait_for_timeout(500)

        # Logout Manager
        await page.click("#logout")
        await page.wait_for_timeout(1000)
        await context.close()

        # Test 4: Employee (Anderson) Restriction
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "anderson.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        await page.click("a[data-page='pedidos']")
        await page.wait_for_selector("#page-pedidos.active", timeout=5000)
        await page.wait_for_timeout(500)
        btn_disabled = await page.is_disabled("#btn-novo-pedido")
        print("[TEST 4 - Employee Restriction] Button disabled:", btn_disabled)
        assert btn_disabled, "Employee button restriction failed"

        await context.close()
        await browser.close()
    print("=== ALL PURCHASE ORDERS INTEGRATION TESTS PASSED SUCCESSFULLY! ===")

asyncio.run(run())
