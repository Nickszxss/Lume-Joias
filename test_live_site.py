import asyncio
import json
from playwright.async_api import async_playwright

async def run_tests():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)

        # Test 1: Desktop Viewport - Login & All Features
        context = await browser.new_context(viewport={"width": 1280, "height": 800})
        page = await context.new_page()

        console_logs = []
        page_errors = []
        network_errors = []

        page.on("console", lambda msg: console_logs.append(f"[{msg.type}] {msg.text}"))
        page.on("pageerror", lambda err: page_errors.append(str(err)))

        print("=== 1. Loading https://nickszxss.github.io/Lume-Joias/ ===")
        response = await page.goto("https://nickszxss.github.io/Lume-Joias/", wait_until="networkidle")
        print(f"HTTP Status: {response.status}")

        # Check Supabase initialization and connection status from console/window
        supabase_status = await page.evaluate("""() => {
            return {
                supabaseDefined: typeof window.supabase !== 'undefined',
                supabaseClientDefined: typeof window.supabaseClient !== 'undefined',
                localStorageUser: localStorage.getItem('lume_usuario')
            }
        }""")
        print("Supabase Status:", supabase_status)

        # Test Login as Gerente (Robson)
        print("\n=== 2. Testing Login - Gerente (Robson) ===")
        await page.fill("#login-nome", "Robson")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")

        await page.wait_for_timeout(1000)
        app_visible = await page.is_visible("#app.active")
        user_nome = await page.inner_text("#user-nome") if app_visible else "N/A"
        user_tipo = await page.inner_text("#user-tipo") if app_visible else "N/A"
        print(f"Login Gerente Success: {app_visible}, User: {user_nome}, Cargo: {user_tipo}")

        # Test Dashboard KPIs & Charts
        print("\n=== 3. Testing Dashboard & Charts (Gerente) ===")
        kpis = await page.evaluate("""() => {
            const cards = document.querySelectorAll('#dash-kpis .kpi');
            return Array.from(cards).map(c => ({
                label: c.querySelector('.label')?.innerText,
                value: c.querySelector('.value')?.innerText
            }));
        }""")
        print("Dashboard KPIs:", kpis)

        # Check if Charts rendered
        chart1 = await page.evaluate("() => typeof window.chartFilial !== 'undefined' && window.chartFilial !== null")
        chart2 = await page.evaluate("() => typeof window.chartMov !== 'undefined' && window.chartMov !== null")
        print(f"Chart Filial Rendered: {chart1}, Chart Movimentacoes Rendered: {chart2}")

        # Test Filter by Filial on Dashboard
        print("\n=== 4. Testing Filial Filters on Dashboard ===")
        filial_btns = await page.query_selector_all("#dash-filiais button")
        print(f"Filial buttons count: {len(filial_btns)}")
        if len(filial_btns) > 1:
            await filial_btns[1].click() # Click first filial
            await page.wait_for_timeout(500)
            kpis_filtered = await page.evaluate("""() => {
                const cards = document.querySelectorAll('#dash-kpis .kpi');
                return Array.from(cards).map(c => ({
                    label: c.querySelector('.label')?.innerText,
                    value: c.querySelector('.value')?.innerText
                }));
            }""")
            print("Filtered KPIs:", kpis_filtered)

        # Test Page - Produtos
        print("\n=== 5. Testing Produtos Page ===")
        await page.click("a[data-page='produtos']")
        await page.wait_for_timeout(500)
        prod_rows = await page.locator("#tbody-produtos tr").count()
        print(f"Produtos rows count: {prod_rows}")

        # Test Add Product Modal
        print("\n=== 6. Testing Add Product Modal ===")
        btn_novo_prod = await page.is_visible("button:has-text('Novo Produto')")
        print(f"Button 'Novo Produto' visible: {btn_novo_prod}")

        # Test Page - Estoque
        print("\n=== 7. Testing Estoque Page ===")
        await page.click("a[data-page='estoque']")
        await page.wait_for_timeout(500)
        est_rows = await page.locator("#tbody-estoque tr").count()
        print(f"Estoque rows count: {est_rows}")

        # Test Adjust Stock Modal
        print("\n=== 8. Testing Stock Adjustment Modal ===")
        adjust_btns = await page.locator("#tbody-estoque button:has-text('Ajustar')").count()
        if adjust_btns > 0:
            await page.locator("#tbody-estoque button:has-text('Ajustar')").first.click()
            await page.wait_for_timeout(500)
            modal_visible = await page.is_visible("#modal-ajuste")
            print(f"Modal Ajuste visible: {modal_visible}")
            await page.click("#modal-ajuste .close-modal")

        # Test Page - Transferencias
        print("\n=== 9. Testing Transferencias Page ===")
        await page.click("a[data-page='transferencias']")
        await page.wait_for_timeout(500)
        transf_rows = await page.locator("#tbody-transferencias tr").count()
        print(f"Transferencias rows count: {transf_rows}")

        # Test Page - Pedidos de Compra
        print("\n=== 10. Testing Pedidos de Compra Page (Gerente) ===")
        await page.click("a[data-page='pedidos']")
        await page.wait_for_timeout(500)
        ped_btn_enabled = await page.is_enabled("#btn-novo-pedido")
        print(f"Gerente can click 'Novo Pedido': {ped_btn_enabled}")

        # Test Page - Alertas
        print("\n=== 11. Testing Alertas Page ===")
        await page.click("a[data-page='alertas']")
        await page.wait_for_timeout(500)
        alert_rows = await page.locator("#tbody-alertas tr").count()
        print(f"Alertas rows count: {alert_rows}")

        # Test Page - Historico
        print("\n=== 12. Testing Historico Page ===")
        await page.click("a[data-page='historico']")
        await page.wait_for_timeout(500)
        hist_rows = await page.locator("#tbody-historico tr").count()
        print(f"Historico rows count: {hist_rows}")

        # Logout & Test Funcionário (Anderson)
        print("\n=== 13. Testing Logout & Login - Funcionário (Anderson) ===")
        await page.click(".btn-logout")
        await page.wait_for_timeout(500)

        await page.fill("#login-nome", "Anderson")
        await page.fill("#login-email", "anderson.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_timeout(1000)

        func_app_visible = await page.is_visible("#app.active")
        func_user_tipo = await page.inner_text("#user-tipo") if func_app_visible else "N/A"
        print(f"Login Funcionario Success: {func_app_visible}, Cargo: {func_user_tipo}")

        # Check Pedidos button restriction for Funcionário
        await page.click("a[data-page='pedidos']")
        await page.wait_for_timeout(500)
        func_ped_disabled = await page.is_disabled("#btn-novo-pedido")
        print(f"Funcionário 'Novo Pedido' disabled: {func_ped_disabled}")

        # Check Filial restriction for Funcionário in Transferencias
        await page.click("a[data-page='transferencias']")
        await page.wait_for_timeout(500)
        await page.click("button:has-text('Nova Transferência')")
        await page.wait_for_timeout(500)
        origem_disabled = await page.is_disabled("#t-origem")
        print(f"Funcionário Origin Filial locked/disabled in Transfer modal: {origem_disabled}")
        await page.click("#modal-transferencia .close-modal")

        # Test Responsive Viewports (Mobile & Tablet)
        print("\n=== 14. Testing Responsive Viewports (Mobile & Tablet) ===")
        for name, w, h in [("Mobile_375x667", 375, 667), ("Tablet_768x1024", 768, 1024)]:
            await page.set_viewport_size({"width": w, "height": h})
            await page.wait_for_timeout(500)
            await page.screenshot(path=f"/tmp/{name}_dash.png")

            # Check horizontal scroll hint or menu wrapping
            menu_visible = await page.is_visible("#menu")
            sidebar_width = await page.evaluate("() => document.querySelector('.sidebar')?.getBoundingClientRect().width")
            print(f"[{name}] Menu visible: {menu_visible}, Sidebar width: {sidebar_width}px")

        # Check console errors
        print("\n=== Page Console Errors captured during run ===")
        for err in page_errors:
            print("ERROR:", err)
        print("\n=== Console logs captured (last 10) ===")
        for log in console_logs[-10:]:
            print(log)

        await browser.close()

asyncio.run(run_tests())
