import asyncio
import json
from playwright.async_api import async_playwright

async def run_full_suite():
    results = {}
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(viewport={"width": 1280, "height": 800})
        page = await context.new_page()

        console_logs = []
        page_errors = []
        page.on("console", lambda msg: console_logs.append(f"[{msg.type}] {msg.text}"))
        page.on("pageerror", lambda err: page_errors.append(str(err)))

        print("Navigating to https://nickszxss.github.io/Lume-Joias/ ...")
        await page.goto("https://nickszxss.github.io/Lume-Joias/", wait_until="networkidle")

        # ----------------------------------------------------
        # TEST 1: Login functionality (BCrypt / Plaintext password issue?)
        # ----------------------------------------------------
        print("\n--- Testing Login with different users ---")

        # Try Robson (BCrypt password in Supabase 'usuarios' table)
        await page.fill("#login-nome", "Robson")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_timeout(1500)

        login_robson = await page.evaluate("""() => {
            return {
                appActive: document.getElementById('app').classList.contains('active'),
                user: JSON.parse(localStorage.getItem('lume_usuario') || 'null'),
                toast: document.getElementById('toast')?.innerText
            }
        }""")
        print("Login Robson (Gerente):", login_robson)

        # Logout if logged in
        if login_robson['appActive']:
            await page.click("#logout")
            await page.wait_for_timeout(500)

        # Try Anderson (Funcionario)
        await page.fill("#login-nome", "Anderson")
        await page.fill("#login-email", "anderson.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_timeout(1500)

        login_anderson = await page.evaluate("""() => {
            return {
                appActive: document.getElementById('app').classList.contains('active'),
                user: JSON.parse(localStorage.getItem('lume_usuario') || 'null'),
                toast: document.getElementById('toast')?.innerText
            }
        }""")
        print("Login Anderson (Funcionario):", login_anderson)

        # Try Wrong Password
        if login_anderson['appActive']:
            await page.click("#logout")
            await page.wait_for_timeout(500)

        await page.fill("#login-nome", "Robson")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "SENHA_ERRADA")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_timeout(1000)

        login_wrong = await page.evaluate("""() => {
            return {
                appActive: document.getElementById('app').classList.contains('active'),
                toast: document.getElementById('toast')?.innerText
            }
        }""")
        print("Login Wrong Password:", login_wrong)

        # Re-login as Robson for remaining functional tests
        await page.fill("#login-nome", "Robson")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_timeout(1500)

        # ----------------------------------------------------
        # TEST 2: Dashboard Data & Charts
        # ----------------------------------------------------
        print("\n--- Testing Dashboard & Charts ---")
        dash_info = await page.evaluate("""() => {
            const kpis = Array.from(document.querySelectorAll('#dash-kpis .kpi')).map(c => ({
                label: c.querySelector('.label')?.innerText,
                value: c.querySelector('.value')?.innerText
            }));
            const alerts = document.querySelectorAll('#dash-alertas tr').length;
            const chartFilialData = window.chartFilial ? window.chartFilial.data.datasets[0].data : null;
            const chartMovData = window.chartMov ? {
                entradas: window.chartMov.data.datasets[0].data,
                saidas: window.chartMov.data.datasets[1].data
            } : null;
            return { kpis, alertsCount: alerts, chartFilialData, chartMovData };
        }""")
        print("Dashboard Info:", json.dumps(dash_info, indent=2))

        # ----------------------------------------------------
        # TEST 3: Produtos & Stock Status Calculation
        # ----------------------------------------------------
        print("\n--- Testing Produtos Page ---")
        await page.click("a[data-page='produtos']")
        await page.wait_for_timeout(1000)

        prod_info = await page.evaluate("""() => {
            const rows = Array.from(document.querySelectorAll('#tbody-produtos tr'));
            return rows.slice(0, 10).map(r => {
                const cols = r.querySelectorAll('td');
                if (cols.length < 7) return { empty: r.innerText };
                return {
                    sku: cols[0].innerText,
                    nome: cols[1].innerText,
                    categoria: cols[2].innerText,
                    qtd_min: cols[3].innerText,
                    filial: cols[4].innerText,
                    qtd_atual: cols[5].innerText,
                    status: cols[6].innerText
                };
            });
        }""")
        print("Sample Produtos (First 10):", json.dumps(prod_info, indent=2))

        # Test Filter on Produtos
        await page.fill("#busca-produto", "Anel")
        await page.wait_for_timeout(300)
        filtered_count = await page.locator("#tbody-produtos tr").count()
        print(f"Filtered productos count for 'Anel': {filtered_count}")
        await page.fill("#busca-produto", "")

        # ----------------------------------------------------
        # TEST 4: Estoque Page & Adjustments
        # ----------------------------------------------------
        print("\n--- Testing Estoque Page ---")
        await page.click("a[data-page='estoque']")
        await page.wait_for_timeout(1000)

        est_info = await page.evaluate("""() => {
            const rows = Array.from(document.querySelectorAll('#tbody-estoque tr'));
            return rows.slice(0, 5).map(r => {
                const cols = r.querySelectorAll('td');
                if (cols.length < 5) return { empty: r.innerText };
                return {
                    sku: cols[0].innerText,
                    nome: cols[1].innerText,
                    qtd: cols[2].innerText,
                    min: cols[3].innerText,
                    status: cols[4].innerText
                };
            });
        }""")
        print("Sample Estoque (First 5):", json.dumps(est_info, indent=2))

        # ----------------------------------------------------
        # TEST 5: Transferencias & Real DB Update Test
        # ----------------------------------------------------
        print("\n--- Testing Transferencias Page ---")
        await page.click("a[data-page='transferencias']")
        await page.wait_for_timeout(1000)

        transf_info = await page.evaluate("""() => {
            const rows = Array.from(document.querySelectorAll('#tbody-transferencias tr'));
            return rows.map(r => {
                const cols = r.querySelectorAll('td');
                if (cols.length < 8) return { empty: r.innerText };
                return {
                    id: cols[0].innerText,
                    produto: cols[1].innerText,
                    origem: cols[2].innerText,
                    destino: cols[3].innerText,
                    qtd: cols[4].innerText,
                    solicitante: cols[5].innerText,
                    data: cols[6].innerText,
                    status: cols[7].innerText
                };
            });
        }""")
        print("Transferencias List:", json.dumps(transf_info, indent=2))

        # ----------------------------------------------------
        # TEST 6: Pedidos de Compra
        # ----------------------------------------------------
        print("\n--- Testing Pedidos de Compra Page ---")
        await page.click("a[data-page='pedidos']")
        await page.wait_for_timeout(1000)

        pedidos_info = await page.evaluate("""() => {
            const rows = Array.from(document.querySelectorAll('#tbody-pedidos tr'));
            return rows.map(r => {
                const cols = r.querySelectorAll('td');
                if (cols.length < 7) return { empty: r.innerText };
                return {
                    id: cols[0].innerText,
                    produto: cols[1].innerText,
                    qtd: cols[2].innerText,
                    filial: cols[3].innerText,
                    solicitante: cols[4].innerText,
                    data: cols[5].innerText,
                    status: cols[6].innerText
                };
            });
        }""")
        print("Pedidos de Compra List:", json.dumps(pedidos_info, indent=2))

        # ----------------------------------------------------
        # TEST 7: Alertas Page
        # ----------------------------------------------------
        print("\n--- Testing Alertas Page ---")
        await page.click("a[data-page='alertas']")
        await page.wait_for_timeout(1000)

        alertas_info = await page.evaluate("""() => {
            const kpis = Array.from(document.querySelectorAll('#alertas-kpis .kpi')).map(c => ({
                label: c.querySelector('.label')?.innerText,
                value: c.querySelector('.value')?.innerText
            }));
            const rows = Array.from(document.querySelectorAll('#tbody-alertas tr')).map(r => {
                const cols = r.querySelectorAll('td');
                if (cols.length < 6) return { empty: r.innerText };
                return {
                    sku: cols[0].innerText,
                    produto: cols[1].innerText,
                    filial: cols[2].innerText,
                    qtd_atual: cols[3].innerText,
                    qtd_min: cols[4].innerText,
                    status: cols[5].innerText
                };
            });
            return { kpis, rows };
        }""")
        print("Alertas Page Info:", json.dumps(alertas_info, indent=2))

        # ----------------------------------------------------
        # TEST 8: Historico Page
        # ----------------------------------------------------
        print("\n--- Testing Historico Page ---")
        await page.click("a[data-page='historico']")
        await page.wait_for_timeout(1000)

        hist_info = await page.evaluate("""() => {
            const rows = Array.from(document.querySelectorAll('#tbody-historico tr'));
            return rows.slice(0, 10).map(r => {
                const cols = r.querySelectorAll('td');
                if (cols.length < 8) return { empty: r.innerText };
                return {
                    data: cols[0].innerText,
                    produto: cols[1].innerText,
                    filial: cols[2].innerText,
                    tipo: cols[3].innerText,
                    anterior: cols[4].innerText,
                    nova: cols[5].innerText,
                    usuario: cols[6].innerText,
                    motivo: cols[7].innerText
                };
            });
        }""")
        print("Historico Sample (First 10):", json.dumps(hist_info, indent=2))

        # ----------------------------------------------------
        # TEST 9: Mobile Responsiveness (Viewport 375x667)
        # ----------------------------------------------------
        print("\n--- Testing Mobile Responsiveness (375x667) ---")
        await page.set_viewport_size({"width": 375, "height": 667})
        await page.wait_for_timeout(500)
        await page.screenshot(path="/tmp/mobile_dashboard.png")

        mobile_nav = await page.evaluate("""() => {
            const menu = document.getElementById('menu');
            const menuStyle = window.getComputedStyle(menu);
            const sidebar = document.querySelector('aside');
            const sidebarStyle = window.getComputedStyle(sidebar);
            return {
                menuDisplay: menuStyle.display,
                menuOverflowX: menuStyle.overflowX,
                sidebarPosition: sidebarStyle.position,
                sidebarWidth: sidebarStyle.width,
                sidebarFlexDirection: sidebarStyle.flexDirection
            };
        }""")
        print("Mobile Nav CSS Styles:", json.dumps(mobile_nav, indent=2))

        # Take screenshot of Produtos table on mobile
        await page.click("a[data-page='produtos']")
        await page.wait_for_timeout(500)
        await page.screenshot(path="/tmp/mobile_produtos.png")

        print("\n--- Console Errors ---")
        for err in page_errors:
            print("ERROR:", err)

        await browser.close()

asyncio.run(run_full_suite())
