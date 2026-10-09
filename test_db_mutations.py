import asyncio
import json
from playwright.async_api import async_playwright

async def test_mutations():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        print("--- Navigating to live site ---")
        await page.goto("https://nickszxss.github.io/Lume-Joias/", wait_until="networkidle")

        # Login as Robson
        await page.fill("#login-nome", "Robson")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_timeout(1000)

        # 1. Test Stock Adjustment
        print("\n--- 1. Testing Stock Adjustment (Entrada +1) ---")
        await page.click("a[data-page='estoque']")
        await page.wait_for_timeout(500)

        # Get first stock item row before adjustment
        first_row_before = await page.evaluate("""() => {
            const first = document.querySelector('#tbody-estoque tr');
            const cols = first.querySelectorAll('td');
            return {
                nome: cols[1].innerText,
                qtd: parseInt(cols[2].innerText)
            };
        }""")
        print("Before adjustment:", first_row_before)

        # Click Adjust on first row
        await page.click("#tbody-estoque tr button:has-text('Ajustar')")
        await page.wait_for_timeout(500)

        await page.select_option("#a-tipo", "entrada")
        await page.fill("#a-qtd", "1")
        await page.fill("#a-motivo", "Teste Automatizado de Auditoria")
        await page.click("#modal-ajuste button:has-text('Confirmar')")
        await page.wait_for_timeout(1500)

        first_row_after = await page.evaluate("""() => {
            const first = document.querySelector('#tbody-estoque tr');
            const cols = first.querySelectorAll('td');
            return {
                nome: cols[1].innerText,
                qtd: parseInt(cols[2].innerText)
            };
        }""")
        print("After adjustment:", first_row_after)

        # 2. Test Transfer Creation & Conclusion
        print("\n--- 2. Testing Transfer Creation ---")
        await page.click("a[data-page='transferencias']")
        await page.wait_for_timeout(500)

        await page.click("button:has-text('Nova Transferência')")
        await page.wait_for_timeout(500)

        await page.fill("#t-qtd", "1")
        await page.select_option("#t-origem", "1") # Filial Centro
        await page.select_option("#t-destino", "2") # Filial Norte
        await page.click("#modal-transferencia button:has-text('Solicitar')")
        await page.wait_for_timeout(1500)

        latest_transf = await page.evaluate("""() => {
            const first = document.querySelector('#tbody-transferencias tr');
            if (!first) return null;
            const cols = first.querySelectorAll('td');
            return {
                id: cols[0].innerText,
                produto: cols[1].innerText,
                origem: cols[2].innerText,
                destino: cols[3].innerText,
                qtd: cols[4].innerText,
                solicitante: cols[5].innerText,
                status: cols[7].innerText
            };
        }""")
        print("New Transfer created:", latest_transf)

        # Conclude transfer
        print("\n--- Concluding Transfer ---")
        await page.click("#tbody-transferencias tr button:has-text('Concluir')")
        await page.wait_for_timeout(2000)

        latest_transf_after = await page.evaluate("""() => {
            const first = document.querySelector('#tbody-transferencias tr');
            const cols = first.querySelectorAll('td');
            return {
                id: cols[0].innerText,
                status: cols[7].innerText
            };
        }""")
        print("Transfer Status After Conclude:", latest_transf_after)

        # Check Historico for recorded movements
        print("\n--- Checking Historico for recorded audit trail ---")
        await page.click("a[data-page='historico']")
        await page.wait_for_timeout(1000)

        latest_hist = await page.evaluate("""() => {
            const rows = Array.from(document.querySelectorAll('#tbody-historico tr')).slice(0, 3);
            return rows.map(r => {
                const cols = r.querySelectorAll('td');
                return {
                    data: cols[0].innerText,
                    produto: cols[1].innerText,
                    filial: cols[2].innerText,
                    tipo: cols[3].innerText,
                    ant: cols[4].innerText,
                    nova: cols[5].innerText,
                    usr: cols[6].innerText,
                    motivo: cols[7].innerText
                };
            });
        }""")
        print("Latest Historico Entries:", json.dumps(latest_hist, indent=2))

        await browser.close()

asyncio.run(test_mutations())
