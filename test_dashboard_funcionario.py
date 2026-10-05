import asyncio
import os
from playwright.async_api import async_playwright

async def run():
    print("=== STARTING EMPLOYEE DASHBOARD ISOLATION INTEGRATION TESTS ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # Test 1: Employee (Anderson) Dashboard Data Structure
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-nome", "Anderson")
        await page.fill("#login-email", "anderson.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1500)

        # Intercept and evaluate api.resumoDashboard() payload
        dash_data = await page.evaluate("api.resumoDashboard()")
        print("[TEST 1 - Employee Data] estoquePorFilial length:", len(dash_data.get('estoquePorFilial', [])))
        print("[TEST 1 - Employee Data] estoquePorFilial:", dash_data.get('estoquePorFilial'))

        # Verify EXACTLY 1 filial in chart data
        assert len(dash_data.get('estoquePorFilial', [])) == 1, "Employee chart should contain ONLY 1 filial"
        assert dash_data['estoquePorFilial'][0]['nome'] == 'Filial Centro', "Employee chart filial name mismatch"

        # Verify all stock records returned belong strictly to Filial 1
        estoques_returned = dash_data.get('estoques', [])
        for e in estoques_returned:
            assert str(e.get('filial_id')) == '1', f"Data leak detected: stock record from branch {e.get('filial_id')} returned to employee"
        print(f"[TEST 1 - Employee Data] All {len(estoques_returned)} stock records belong to Filial Centro (ID 1)")

        await page.click("#logout")
        await page.wait_for_timeout(1000)
        await context.close()

        # Test 2: Manager (Robson) Dashboard Data Structure
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-nome", "Robson")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1500)

        manager_dash_data = await page.evaluate("api.resumoDashboard()")
        print("[TEST 2 - Manager Data] estoquePorFilial length:", len(manager_dash_data.get('estoquePorFilial', [])))
        assert len(manager_dash_data.get('estoquePorFilial', [])) == 5, "Manager chart should contain all 5 filiais"

        await context.close()
        await browser.close()
    print("=== ALL EMPLOYEE DASHBOARD ISOLATION TESTS PASSED SUCCESSFULLY! ===")

asyncio.run(run())
