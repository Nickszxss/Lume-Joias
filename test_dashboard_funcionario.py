import asyncio
import os
from playwright.async_api import async_playwright

async def run():
    print("=== STARTING EMPLOYEE DASHBOARD ISOLATION INTEGRATION TESTS ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # Test 1: Employee (Anderson - Filial Centro ID 1) Dashboard Isolation
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "anderson.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1500)

        # Retrieve dashboard data via page evaluate
        dash_data = await page.evaluate("api.resumoDashboard()")
        print("[TEST 1 - Employee Data] estoquePorFilial length:", len(dash_data['estoquePorFilial']))
        print("[TEST 1 - Employee Data] estoquePorFilial:", dash_data['estoquePorFilial'])
        assert len(dash_data['estoquePorFilial']) == 1, "Employee saw more than 1 branch in dashboard chart"
        assert dash_data['estoquePorFilial'][0]['nome'] == 'Filial Centro', "Employee branch name mismatch"

        # Check raw estoques returned in resumoDashboard
        employee_estoques = dash_data['estoques']
        all_belong_to_filial_1 = all(e['filial_id'] == 1 for e in employee_estoques)
        print(f"[TEST 1 - Employee Data] All {len(employee_estoques)} stock records belong to Filial Centro (ID 1)")
        assert all_belong_to_filial_1, "Data leakage detected: Employee received stock records from other branches"

        await page.click("#logout")
        await page.wait_for_timeout(1000)
        await context.close()

        # Test 2: Manager (Robson) Sees All 5 Branches
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1500)

        manager_dash_data = await page.evaluate("api.resumoDashboard()")
        print("[TEST 2 - Manager Data] estoquePorFilial length:", len(manager_dash_data['estoquePorFilial']))
        assert len(manager_dash_data['estoquePorFilial']) == 5, "Manager did not see all 5 branches"

        await context.close()
        await browser.close()
    print("=== ALL EMPLOYEE DASHBOARD ISOLATION TESTS PASSED SUCCESSFULLY! ===")

asyncio.run(run())
