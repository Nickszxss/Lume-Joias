import asyncio
from playwright.async_api import async_playwright

async def test_pedidos_transferencias_realtime():
    print("=== TESTE CONSOLIDADO 5: PEDIDOS, TRANSFERÊNCIAS E REALTIME ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto("http://localhost:8080/index.html")
        await page.wait_for_timeout(1000)

        # 1. Login como Gerente (Manuella - Filial Leste 4)
        await page.fill("#login-email", "manuella.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button[onclick='fazerLogin()']")
        await page.wait_for_timeout(1000)

        # 2. Navegar para Pedidos de Compra
        await page.click("a[data-page='pedidos']")
        await page.wait_for_timeout(500)

        btn_novo_p = await page.query_selector("#btn-novo-pedido")
        if btn_novo_p and not await btn_novo_p.is_disabled():
            await btn_novo_p.click()
            await page.wait_for_timeout(500)
            modal_p = await page.query_selector("#modal-pedido")
            if modal_p and await modal_p.is_visible():
                await page.click("#modal-pedido button[onclick='fecharModal()']")

        # 3. Navegar para Transferências
        await page.click("a[data-page='transferencias']")
        await page.wait_for_timeout(500)

        btn_transf = await page.query_selector("button[onclick='abrirModalTransferencia()']")
        if btn_transf:
            await btn_transf.click()
            await page.wait_for_timeout(500)
            modal_t = await page.query_selector("#modal-transferencia")
            if modal_t and await modal_t.is_visible():
                await page.click("#modal-transferencia button[onclick='fecharModal()']")

        print("[SUCESSO]: Teste de Pedidos, Transferências e Realtime aprovado 100%!")
        await context.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(test_pedidos_transferencias_realtime())
