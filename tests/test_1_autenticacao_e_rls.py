import asyncio
from playwright.async_api import async_playwright

async def run_autenticacao_e_rls():
    print("=== STARTING CONSOLIDATED TESTS: AUTENTICAÇÃO E RLS (GRUPO A) ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto("http://localhost:8080/index.html")
        await page.wait_for_timeout(1000)

        # TEST 1: Login com campos vazios
        print("[TEST 1 - Auth] Campos vazios")
        await page.click("button[onclick='fazerLogin()']")
        await page.wait_for_timeout(500)
        toast_msg = await page.inner_text("#toast")
        assert "obrigatórios" in toast_msg or "Acesso negado" in toast_msg, f"Toast inesperado: {toast_msg}"

        # TEST 2: Login com e-mail incorreto
        print("[TEST 2 - Auth] E-mail errado")
        await page.fill("#login-email", "email_inexistente@empresa.com")
        await page.fill("#login-senha", "123456")
        await page.click("button[onclick='fazerLogin()']")
        await page.wait_for_timeout(1000)
        toast_msg = await page.inner_text("#toast")
        assert "Acesso negado" in toast_msg or "incorretos" in toast_msg, f"Toast inesperado: {toast_msg}"

        # TEST 3: Login Sucesso Anderson (Funcionário Filial Centro 1)
        print("[TEST 3 - Auth] Login Anderson")
        await page.fill("#login-email", "anderson.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button[onclick='fazerLogin()']")
        await page.wait_for_timeout(1500)

        # Assert App visible
        app_visible = await page.is_visible("#app")
        assert app_visible, "App não ficou visível para Anderson!"

        # Assert Cargo/Tipo
        user_tipo = await page.inner_text("#user-tipo")
        assert "Funcionário" in user_tipo, f"Tipo inesperado: {user_tipo}"

        # TEST 4: RLS - Anderson não pode criar pedido
        btn_novo_pedido = await page.query_selector("#btn-novo-pedido")
        assert btn_novo_pedido is not None, "Botão de novo pedido não encontrado!"
        is_disabled = await btn_novo_pedido.is_disabled()
        assert is_disabled, "Funcionário Anderson não teve o botão de novo pedido desabilitado!"

        # Logout Anderson
        await page.click("button[onclick='sair()']")
        await page.wait_for_timeout(1000)

        # TEST 5: Login Robson (Gerente Filial Oeste 5)
        print("[TEST 5 - Auth/RLS] Login Robson (Gerente)")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button[onclick='fazerLogin()']")
        await page.wait_for_timeout(1500)

        # Assert Gerente
        user_tipo_robson = await page.inner_text("#user-tipo")
        assert "Gerente" in user_tipo_robson, f"Tipo inesperado para Robson: {user_tipo_robson}"

        btn_novo_pedido_robson = await page.query_selector("#btn-novo-pedido")
        is_disabled_robson = await btn_novo_pedido_robson.is_disabled()
        assert not is_disabled_robson, "Gerente Robson deveria ter botão de novo pedido habilitado!"

        # Logout Robson
        await page.click("button[onclick='sair()']")
        await page.wait_for_timeout(1000)

        print("=== CONSOLIDATED TESTS: AUTENTICAÇÃO E RLS PASSED SUCCESSFULLY! ===")
        await context.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(run_autenticacao_e_rls())
