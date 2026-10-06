import asyncio
import os
from playwright.async_api import async_playwright

async def run():
    print("=== STARTING NICOLY GERENTE INTEGRATION TESTS ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        # Login with nicoly.grt@empresa.com and 160611
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "nicoly.grt@empresa.com")
        await page.fill("#login-senha", "160611")
        await page.click("button:has-text('Entrar')")

        # Verify successful login
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1000)

        user_name = await page.text_content("#user-nome")
        user_tipo = await page.text_content("#user-tipo")
        print(f"[TEST 1 - User Info] Name: {user_name}, Role: {user_tipo}")
        assert user_name == "Nicoly", "User name mismatch for Nicoly Gerente"
        assert user_tipo == "Gerente", "Role mismatch for Nicoly Gerente"

        # Verify Manager Dashboard 5 Filiais Consolidated View
        dash_desc = await page.text_content("#dash-desc")
        print("[TEST 2 - Manager Dashboard] Desc:", dash_desc)
        assert "5 filiais" in dash_desc, "Dashboard description did not reference 5 filiais"

        kpi_badge = await page.text_content("#dash-kpis .kpi .badge.info")
        print("[TEST 2 - Manager KPI Badge]:", kpi_badge)
        assert "5 filiais" in kpi_badge, "KPI badge did not reference 5 filiais"

        # Verify Manager Permissions (Purchase Order button enabled)
        await page.click("a[data-page='pedidos']")
        await page.wait_for_selector("#page-pedidos.active", timeout=5000)
        btn_disabled = await page.is_disabled("#btn-novo-pedido")
        print("[TEST 3 - Manager Permission] New Order button disabled:", btn_disabled)
        assert not btn_disabled, "Purchase order button should be enabled for gerente"

        await context.close()
        await browser.close()
    print("=== ALL NICOLY GERENTE TESTS PASSED SUCCESSFULLY! ===")

asyncio.run(run())
