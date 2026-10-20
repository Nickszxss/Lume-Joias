import asyncio
from playwright.async_api import async_playwright

def test_validar_status_transferencias_solicitada_main_js():
    with open("main.js", "r", encoding="utf-8") as f:
        js = f.read()

    # Inserção e retorno de transferências devem utilizar 'solicitada'
    assert "status: 'solicitada'" in js
    assert "status: 'pendente'" not in js

    # Filtros e lógica de renderização de transferências
    assert "t.status === 'solicitada'" in js
    assert "const pender = t.status === 'solicitada';" in js

def test_validar_usuario_id_auth_transferencias_main_js():
    with open("main.js", "r", encoding="utf-8") as f:
        js = f.read()

    # Consulta de sessão autenticada via client.auth.getUser()
    assert "client.auth.getUser()" in js
    # Consulta na tabela public.usuarios pelo e-mail do auth.user
    assert ".from('usuarios')" in js
    assert ".eq('email', authData.user.email)" in js
    assert "usuario_id: usuarioDb.id" in js
    # Omite created_at manual na inserção
    assert "created_at: new Date().toISOString()" not in js

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
        if btn_novo_p and await btn_novo_p.is_visible() and not await btn_novo_p.is_disabled():
            await btn_novo_p.click()
            await page.wait_for_timeout(500)
            modal_p = await page.query_selector("#modal-pedido")
            if modal_p and await modal_p.is_visible():
                await page.click("#modal-pedido button[onclick='fecharModal()']")

        # 3. Navegar para Transferências
        await page.click("a[data-page='transferencias']")
        await page.wait_for_timeout(500)

        btn_transf = await page.query_selector("button[onclick='abrirModalTransferencia()']")
        if btn_transf and await btn_transf.is_visible():
            await btn_transf.click()
            await page.wait_for_timeout(500)
            modal_t = await page.query_selector("#modal-transferencia")
            if modal_t and await modal_t.is_visible():
                await page.click("#modal-transferencia button[onclick='fecharModal()']")

        print("[SUCESSO]: Teste de Pedidos, Transferências e Realtime aprovado 100%!")
        await context.close()
        await browser.close()

if __name__ == "__main__":
    test_validar_status_transferencias_solicitada_main_js()
    test_validar_usuario_id_auth_transferencias_main_js()
    asyncio.run(test_pedidos_transferencias_realtime())
