import asyncio
from playwright.async_api import async_playwright

async def run():
    print("==========================================================")
    print("   TESTE DE INTEGRAÇÃO - EDITAR E INATIVAR PRODUTOS (TAREFA 4) ")
    print("==========================================================")

    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # --------------------------------------------------------
        # PASSO 1: Gerente (Robson) Edita um Produto
        # --------------------------------------------------------
        print("\n--- PASSO 1: Gerente Editando Nome, SKU e Categoria ---")
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        await page.click("a[data-page='produtos']")
        await page.wait_for_timeout(1000)
        await page.wait_for_selector("#page-produtos.active", timeout=5000)

        # Obter primeiro produto cadastrado
        p_info = await page.evaluate("""async () => {
            const client = window.supabaseClient || window.initSupabase();
            const { data } = await client.from('produtos').select('*').order('id', { ascending: true }).limit(1).single();
            return data;
        }""")
        p_id = p_info["id"]
        print(f"[TEST 1] Editando Produto ID #{p_id} (Nome Original: '{p_info['nome']}')")

        # Abrir modal de edição para o produto
        await page.click(f"tr:has-text('{p_info['nome']}') button:has-text('Editar')")
        await page.wait_for_selector("#modal-editar-produto", timeout=5000)

        novo_nome = "Colar de Prata Imperial"
        novo_sku = "001-IMP"
        nova_cat = "Anéis"

        await page.fill("#ep-nome", novo_nome)
        await page.fill("#ep-sku", novo_sku)
        await page.fill("#ep-cat", nova_cat)
        await page.click("#modal-editar-produto button:has-text('Salvar Alterações')")
        await page.wait_for_timeout(1000)

        toast_edit = await page.text_content("#toast")
        print("[TEST 1 - Toast Edição]:", toast_edit.strip())
        assert "sucesso" in toast_edit.lower(), "Falha ao editar produto"

        # Verificar se dados atualizados aparecem na tabela
        produtos_html = await page.text_content("#tbody-produtos")
        print("[TEST 1 - Tabela Pós-Edição]:\n", produtos_html.strip())
        assert novo_nome in produtos_html and novo_sku in produtos_html and nova_cat in produtos_html, "Dados editados não aparecem na tabela!"

        # --------------------------------------------------------
        # PASSO 2: Persistência após Reload (F5)
        # --------------------------------------------------------
        print("\n--- PASSO 2: Verificando Persistência F5 da Edição ---")
        await page.reload()
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.click("a[data-page='produtos']")
        await page.wait_for_timeout(1000)
        await page.wait_for_selector("#page-produtos.active", timeout=5000)

        prod_f5 = await page.text_content("#tbody-produtos")
        assert novo_nome in prod_f5 and novo_sku in prod_f5, "Persistência F5 da edição falhou!"
        print("[TEST 2 - Persistência F5 da Edição OK]")

        # --------------------------------------------------------
        # PASSO 3: Inativar Produto e Verificar Preservação
        # --------------------------------------------------------
        print("\n--- PASSO 3: Inativando Produto e Verificando Preservação ---")
        # Inativar produto via API para evitar janela de diálogo 'confirm()' no headless
        inativar_res = await page.evaluate(f"""async () => {{
            try {{
                return await api.inativarProduto({p_id});
            }} catch (err) {{
                return err.message;
            }}
        }}""")
        print("[TEST 3 - Resposta Inativação API]:", inativar_res)
        await page.reload()
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.click("a[data-page='produtos']")
        await page.wait_for_timeout(1000)
        await page.wait_for_selector("#page-produtos.active", timeout=5000)

        prod_inativo_html = await page.text_content("#tbody-produtos")
        print("[TEST 3 - Tabela com Produto Inativo]:\n", prod_inativo_html.strip())
        assert "Inativo" in prod_inativo_html or "row-inativo" in prod_inativo_html, "Badge ou classe Inativo não presente na tabela!"

        # --------------------------------------------------------
        # PASSO 4: Verificar Omissão do Produto Inativo nas Seleções
        # --------------------------------------------------------
        print("\n--- PASSO 4: Verificando Omissão do Produto Inativo nos Seletores ---")
        # Testar modal de Nova Transferência
        await page.click("a[data-page='transferencias']")
        await page.wait_for_timeout(1000)
        await page.wait_for_selector("#page-transferencias.active", timeout=5000)
        await page.click("button:has-text('+ Nova Transferência')")
        await page.wait_for_selector("#modal-transferencia", timeout=5000)

        opt_transf = await page.text_content("#t-produto")
        print("[TEST 4 - Opções de Transferência]:", opt_transf.strip())
        assert novo_nome not in opt_transf, "Produto inativo vazou no seletor de transferências!"
        await page.evaluate("fecharModal()")

        # Testar modal de Novo Pedido
        await page.click("a[data-page='pedidos']")
        await page.wait_for_timeout(1000)
        await page.wait_for_selector("#page-pedidos.active", timeout=5000)
        await page.click("#btn-novo-pedido")
        await page.wait_for_selector("#modal-pedido", timeout=5000)

        opt_pedido = await page.text_content("#pc-produto")
        print("[TEST 4 - Opções de Pedidos]:", opt_pedido.strip())
        assert novo_nome not in opt_pedido, "Produto inativo vazou no seletor de pedidos de compra!"
        await page.evaluate("fecharModal()")

        await page.click("#logout")
        await page.wait_for_timeout(1000)
        await context.close()

        # --------------------------------------------------------
        # PASSO 5: Testar Bloqueio para Funcionário (Anderson)
        # --------------------------------------------------------
        print("\n--- PASSO 5: Testando Restrições para Funcionário ---")
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "anderson.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        await page.click("a[data-page='produtos']")
        await page.wait_for_timeout(1000)
        await page.wait_for_selector("#page-produtos.active", timeout=5000)

        btn_edit_count = await page.locator("#tbody-produtos button:has-text('Editar')").count()
        btn_inat_count = await page.locator("#tbody-produtos button:has-text('Inativar')").count()
        print(f"[TEST 5 - Botões visíveis para Funcionário]: Editar: {btn_edit_count}, Inativar: {btn_inat_count}")
        assert btn_edit_count == 0 and btn_inat_count == 0, "Funcionário não deveria visualizar botões Editar/Inativar!"

        # Tentar chamar API de edição diretamente como funcionário
        edit_func_err = await page.evaluate(f"""async () => {{
            try {{
                await api.editarProduto({p_id}, {{ nome: 'Tentativa Hacker', sku: 'HACK' }});
                return "Sucesso Indevido";
            }} catch (err) {{
                return err.message;
            }}
        }}""")
        print("[TEST 5 - Tentativa de Edição por Funcionário]:", edit_func_err)
        assert "Apenas gerentes" in edit_func_err or "permissao" in edit_func_err.lower(), "API permitiu edição indevida por funcionário!"

        await context.close()
        await browser.close()

    print("\n==========================================================")
    print("   TODOS OS TESTES DA TAREFA 4 PASSARAM COM SUCESSO!     ")
    print("==========================================================")

asyncio.run(run())
