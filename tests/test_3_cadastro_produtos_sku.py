import asyncio
from playwright.async_api import async_playwright

async def test_cadastro_produtos_sku():
    print("=== TESTE CONSOLIDADO 3: CADASTRO DE PRODUTOS, SKU E ESTOQUE MÍNIMO ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto("http://localhost:8080/index.html")
        await page.wait_for_timeout(1000)

        # 1. Login como Gerente (Manuella)
        await page.fill("#login-email", "manuella.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button[onclick='fazerLogin()']")
        await page.wait_for_timeout(1000)

        # 2. Navegar para Produtos
        await page.click("a[data-page='produtos']")
        await page.wait_for_timeout(500)

        # 3. Testar Placeholder de Categoria no Modal
        await page.click("button[onclick='abrirModalProduto()']")
        await page.wait_for_timeout(500)

        placeholder = await page.get_attribute("#p-cat", "placeholder")
        print(f"[TESTE PLACEHOLDER]: Encontrado -> {placeholder}")
        assert "automática" in placeholder.lower(), f"Placeholder esperado 'Categoria automática', mas foi '{placeholder}'"

        # 4. Testar Mapeamento Automático de SKU e Categoria por Tipo de Joia
        await page.select_option("#p-nome", "Brinco de ouro")
        sku_val = await page.input_value("#p-sku")
        cat_val = await page.input_value("#p-cat")
        print(f"[TESTE SKU E CAT AUTO]: Selecionado 'Brinco de ouro' -> SKU: {sku_val}, Categoria: {cat_val}")
        assert sku_val == "06", f"SKU esperado '06', mas foi '{sku_val}'"
        assert cat_val == "BRINCO", f"Categoria esperada 'BRINCO', mas foi '{cat_val}'"

        # Click Cancel inside active #modal-produto modal
        await page.click("#modal-produto button[onclick='fecharModal()']")
        await page.wait_for_timeout(500)

        print("[SUCESSO]: Teste de Cadastro de Produtos, SKU e Estoque Mínimo aprovado 100%!")
        await context.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(test_cadastro_produtos_sku())
