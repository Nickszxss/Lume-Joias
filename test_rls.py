import asyncio
import os
from playwright.async_api import async_playwright

async def run():
    print("=== STARTING SECURITY & RLS PERMISSIONS INTEGRATION TESTS ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # Test 1: Employee (Anderson) Dashboard & Scope Isolation
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "anderson.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1500)

        # Dashboard Check
        dash_desc = await page.text_content("#dash-desc")
        print("[TEST 1 - Employee Scope] Welcome text:", dash_desc)
        assert "Filial Centro" in dash_desc or "Anderson" in dash_desc, "Employee branch scope mismatch in dashboard"

        # Check KPI Badge
        kpi_badge = await page.text_content("#dash-kpis .kpi .badge.info")
        print("[TEST 1 - Employee KPI Badge]:", kpi_badge)
        assert "Centro" in kpi_badge or "Minha" in kpi_badge or "1" in kpi_badge or "Filial" in kpi_badge, "KPI branch badge mismatch"

        # Check Transfer Origin locking for employee
        await page.click("a[data-page='transferencias']")
        await page.wait_for_selector("#page-transferencias.active", timeout=5000)
        await page.click("button:has-text('+ Nova Transferência')")
        await page.wait_for_selector("#modal-transferencia", timeout=5000)

        origem_disabled = await page.is_disabled("#t-origem")
        origem_value = await page.input_value("#t-origem")
        print(f"[TEST 1 - Transfer Origin Disabled]: {origem_disabled}, Value: {origem_value}")
        assert origem_disabled and origem_value == "1", "Transfer origin branch locking failed for employee"
        await page.evaluate("fecharModal()")

        await page.click("#logout")
        await page.wait_for_timeout(1000)
        await context.close()

        # Test 2: Manager (Robson) Consolidated Access
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1500)

        manager_badge = await page.text_content("#dash-kpis .kpi .badge.info")
        print("[TEST 2 - Manager KPI Badge]:", manager_badge)
        assert "5 filiais" in manager_badge, "Manager 5 filiais consolidated access check failed"

        await context.close()
        await browser.close()
    print("=== ALL SECURITY & RLS PERMISSIONS TESTS PASSED SUCCESSFULLY! ===")

asyncio.run(run())
