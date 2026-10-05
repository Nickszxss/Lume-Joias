import asyncio
import os
from playwright.async_api import async_playwright

async def run():
    print("=== STARTING AUTHENTICATION INTEGRATION TESTS ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # Test 1: Empty Fields
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_timeout(500)
        toast_text = await page.text_content("#toast")
        print("[TEST 1 - Empty Fields] Toast message:", toast_text)
        assert "obrigatórios" in toast_text, "Empty fields test failed"
        await context.close()

        # Test 2: Incorrect Password
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-nome", "Robson")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "senha_incorreta_123")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_timeout(1000)
        toast_text = await page.text_content("#toast")
        print("[TEST 2 - Wrong Password] Toast message:", toast_text)
        assert "negado" in toast_text.lower() or "incorretos" in toast_text.lower(), "Wrong password test failed"
        await context.close()

        # Test 3: Valid Manager Login (Robson)
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-nome", "Robson")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        user_name = await page.text_content("#user-nome")
        user_tipo = await page.text_content("#user-tipo")
        print(f"[TEST 3 - Valid Manager] Logged in as: {user_name} ({user_tipo})")
        assert user_name == "Robson", "Manager name mismatch"
        assert user_tipo == "Gerente", "Manager role mismatch"

        # Test 4: Reload page (F5) - Session Persistence
        await page.reload()
        await page.wait_for_selector("#app.active", timeout=10000)
        reloaded_name = await page.text_content("#user-nome")
        print(f"[TEST 4 - Session Persistence] Name after reload: {reloaded_name}")
        assert reloaded_name == "Robson", "Session persistence failed"

        # Test 5: Logout
        await page.click("#logout")
        await page.wait_for_timeout(1000)
        is_login_visible = await page.is_visible("#login-screen")
        print(f"[TEST 5 - Logout] Login screen visible: {is_login_visible}")
        assert is_login_visible, "Logout failed"
        await context.close()

        # Test 6: Valid Employee Login (Anderson)
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-nome", "Anderson")
        await page.fill("#login-email", "anderson.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        user_name = await page.text_content("#user-nome")
        user_tipo = await page.text_content("#user-tipo")
        print(f"[TEST 6 - Valid Employee] Logged in as: {user_name} ({user_tipo})")
        assert user_name == "Anderson", "Employee name mismatch"
        assert user_tipo == "Funcionário", "Employee role mismatch"

        # Test 7: Employee Restrictions Check (Purchase order button disabled)
        await page.click("a[data-page='pedidos']")
        await page.wait_for_timeout(500)
        btn_disabled = await page.is_disabled("#btn-novo-pedido")
        print(f"[TEST 7 - Employee Restriction] New order button disabled: {btn_disabled}")
        assert btn_disabled, "Employee restriction check failed"

        await context.close()
        await browser.close()
    print("=== ALL AUTHENTICATION TESTS PASSED SUCCESSFULLY! ===")

asyncio.run(run())
