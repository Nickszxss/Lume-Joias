import asyncio
from playwright.async_api import async_playwright

async def test_main_js_unit_and_rpc_handling():
    print("=== TESTE COMPLEMENTAR: VALIDAÇÕES DE MAIN.JS, RPC, QUANTIDADES E XSS ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto("http://localhost:8080/index.html")
        await page.wait_for_timeout(1000)

        # 1. Testar escapeHtml
        escaped = await page.evaluate("window.escapeHtml('<script>alert(1)</script>')")
        assert escaped == "&lt;script&gt;alert(1)&lt;/script&gt;", f"Expected escaped HTML, got {escaped}"
        print("[OK] Função window.escapeHtml sanitiza marcas HTML perfeitamente.")

        # 2. Login de gerente para testes de modal e funções RPC
        await page.fill("#login-email", "manuella.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button[onclick='fazerLogin()']")
        await page.wait_for_timeout(1000)

        # 3. Testar validação de quantidade negativa/zero em salvamento de ajuste
        await page.click("a[data-page='estoque']")
        await page.wait_for_timeout(500)

        ajuste_btns = await page.query_selector_all("button[onclick^='abrirModalAjuste']")
        if ajuste_btns:
            await ajuste_btns[0].click()
            await page.wait_for_timeout(500)
            await page.fill("#a-qtd", "-5")
            await page.click("#modal-ajuste button.btn-primary")
            toast_text = await page.text_content("#toast")
            assert "quantidade" in toast_text.lower(), f"Esperado toast de erro de quantidade, obteve: {toast_text}"
            print("[OK] Validação de quantidade negativa em ajuste de estoque acionada com sucesso.")
            await page.click("#modal-ajuste button.btn-secondary")
            await page.wait_for_timeout(300)

        # 4. Testar verificação de contrato RPC (data.success === true) via mock
        rpc_result = await page.evaluate("""
            async () => {
                const originalRpc = window.supabaseClient.rpc;
                window.supabaseClient.rpc = async (fn, params) => {
                    return { data: { success: false, message: 'Simulated business failure' }, error: null };
                };
                try {
                    await api.concluirTransferencia(999999);
                    return { threw: false };
                } catch (e) {
                    return { threw: true, message: e.message };
                } finally {
                    window.supabaseClient.rpc = originalRpc;
                }
            }
        """)
        assert rpc_result["threw"] is True, "concluirTransferencia deveria lançar exceção quando data.success !== true"
        assert "Simulated business failure" in rpc_result["message"], f"Mensagem inesperada: {rpc_result['message']}"
        print("[OK] Validação de data.success === true em RPC acionada e testada com sucesso.")

        print("=== TESTE COMPLEMENTAR MAIN.JS CONCLUÍDO COM 100% DE SUCESSO ===")
        await context.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(test_main_js_unit_and_rpc_handling())
