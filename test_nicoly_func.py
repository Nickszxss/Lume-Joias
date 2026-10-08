import asyncio
import os
from playwright.async_api import async_playwright

async def run():
    print("=== STARTING NICOLY FUNCIONÁRIA INTEGRATION TESTS ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        # Login with nicoly.func@empresa.com and 160611
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "nicoly.func@empresa.com")
        await page.fill("#login-senha", "160611")
        await page.click("button:has-text('Entrar')")

        # Verify successful login
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1000)

        user_name = await page.text_content("#user-nome")
        user_tipo = await page.text_content("#user-tipo")
        print(f"[TEST 1 - User Info] Name: {user_name}, Role: {user_tipo}")
        assert user_name == "Nicoly", "User name mismatch for Nicoly Funcionária"
        assert user_tipo == "Funcionário" or user_tipo == "Funcionária", "Role mismatch for Nicoly Funcionária"

        # Verify Dashboard Scope for Filial Sul (ID 3)
        dash_desc = await page.text_content("#dash-desc")
        print("[TEST 2 - Dashboard Scope] Desc:", dash_desc)
        assert "Filial Sul" in dash_desc, "Dashboard description did not reference Filial Sul"

        kpi_badge = await page.text_content("#dash-kpis .kpi .badge.info")
        print("[TEST 2 - KPI Badge]:", kpi_badge)
        assert "Sul" in kpi_badge or "3" in kpi_badge, "KPI badge did not reference Filial Sul"

        # Verify Employee Restrictions (Purchase Order button disabled)
        await page.click("a[data-page='pedidos']")
        await page.wait_for_selector("#page-pedidos.active", timeout=5000)
        btn_disabled = await page.is_disabled("#btn-novo-pedido")
        print("[TEST 3 - Employee Restriction] New Order button disabled:", btn_disabled)
        assert btn_disabled, "Purchase order button should be disabled for funcionária"

        await context.close()
        await browser.close()
    print("=== ALL NICOLY FUNCIONÁRIA TESTS PASSED SUCCESSFULLY! ===")

asyncio.run(run())
