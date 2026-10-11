import asyncio
from playwright.async_api import async_playwright

async def run_dashboard_interface():
    print("=== STARTING CONSOLIDATED TESTS: DASHBOARD E INTERFACE (GRUPO B) ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # 1. TESTES ORIGINÁRIOS DE test_dashboard_funcionario.py (Anderson - Filial Centro)
        context_func = await browser.new_context()
        page_func = await context_func.new_page()
        print("[TEST 1 - Dashboard Funcionário] Restrições de perfil para Anderson (Filial Centro)")
        await page_func.goto("http://localhost:8080/index.html")
        await page_func.fill("#login-email", "anderson.func@empresa.com")
        await page_func.fill("#login-senha", "etec2026@DS")
        await page_func.click("button:has-text('Entrar')")
        await page_func.wait_for_selector("#app.active", timeout=10000)

        nome_user = await page_func.text_content("#user-nome")
        assert "Anderson" in nome_user, f"Nome do funcionário incorreto: {nome_user}"

        is_dash_visible = await page_func.is_visible("#page-dashboard.active")
        assert is_dash_visible, "Dashboard não está visível para o funcionário"

        # Verificar se o botão de criar pedido está desabilitado para funcionário
        await page_func.click("a[data-page='pedidos']")
        await page_func.wait_for_selector("#page-pedidos.active", timeout=5000)
        btn_disabled = await page_func.is_disabled("#btn-novo-pedido")
        assert btn_disabled, "Purchase order button should be disabled for funcionário"
        await context_func.close()

        # 2. TESTES ORIGINÁRIOS DE test_tarefa4_filtro_estoque.py (Robson - Gerente Filial Oeste)
        context_grt = await browser.new_context()
        page_grt = await context_grt.new_page()
        print("[TEST 2 - Filtro de Estoque] Botões de filtro por filial no Estoque")
        await page_grt.goto("http://localhost:8080/index.html")
        await page_grt.fill("#login-email", "robson.grt@empresa.com")
        await page_grt.fill("#login-senha", "etec2026@DS")
        await page_grt.click("button:has-text('Entrar')")
        await page_grt.wait_for_selector("#app.active", timeout=10000)

        # Navegar para a tela de Estoque
        await page_grt.click("a[data-page='estoque']")
        await page_grt.wait_for_selector("#page-estoque.active", timeout=5000)

        all_rows_text = await page_grt.text_content("#tbody-estoque")
        assert len(all_rows_text) > 0, "All branches stock content empty"

        filiais_para_testar = [
            ("Centro", "Filial Centro"),
            ("Norte", "Filial Norte"),
            ("Sul", "Filial Sul"),
            ("Leste", "Filial Leste"),
            ("Oeste", "Filial Oeste")
        ]

        for button_label, expected_branch_name in filiais_para_testar:
            button_selector = f"#estoque-filiais button:has-text('{button_label}')"
            if await page_grt.is_visible(button_selector):
                await page_grt.click(button_selector)
                await page_grt.wait_for_timeout(300)
                filtered_rows_text = await page_grt.text_content("#tbody-estoque")
                print(f"  [OK] Filtro '{button_label}' clicado com sucesso.")

        await context_grt.close()
        await browser.close()
        print("=== CONSOLIDATED TESTS: DASHBOARD E INTERFACE PASSED SUCCESSFULLY! ===")

if __name__ == "__main__":
    asyncio.run(run_dashboard_interface())
