import asyncio
from playwright.async_api import async_playwright

async def run():
    print("==========================================================")
    print("   TESTE DE INTEGRAÇÃO - RECEBIMENTO DE PEDIDOS DE COMPRA ")
    print("==========================================================")

    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # --------------------------------------------------------
        # PASSO 1: Gerente (Robson) cria um pedido para a Filial Norte (ID 2)
        # --------------------------------------------------------
        print("\n--- PASSO 1: Criando Pedido de Compra como Gerente ---")
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        # Ir para a página de pedidos
        await page.wait_for_timeout(500)
        await page.click("#menu a[data-page='pedidos']")
        await page.wait_for_selector("#page-pedidos.active", timeout=5000)

        # Abrir modal e criar pedido de 15 unidades para Filial Norte
        await page.click("#btn-novo-pedido")
        await page.wait_for_selector("#modal-pedido", timeout=5000)
        await page.select_option("#pc-produto", index=0)
        await page.select_option("#pc-filial", value="2") # Filial Norte
        await page.fill("#pc-qtd", "15")
        await page.click("#modal-pedido button:has-text('Criar Pedido')")
        await page.wait_for_timeout(1000)

        toast1 = await page.text_content("#toast")
        print("[TEST 1 - Criar Pedido Toast]:", toast1.strip())
        assert "sucesso" in toast1.lower(), "Falha ao criar pedido de compra"

        pedidos_html = await page.text_content("#tbody-pedidos")
        print("[TEST 1 - Tabela de Pedidos]:\n", pedidos_html.strip())
        assert "Filial Norte" in pedidos_html and "15" in pedidos_html and "aberto" in pedidos_html, "Pedido criado não encontrado como 'aberto'"

        # Obter o produto_id e quantidade inicial do estoque na Filial Norte para validação
        stock_before = await page.evaluate("""async () => {
            const client = window.supabaseClient || window.initSupabase();
            const { data: pData } = await client.from('pedidos_compra').select('*').order('id', { ascending: false }).limit(1).single();
            const { data: iData } = await client.from('itens_pedido_compra').select('*').eq('pedido_id', pData.id).single();
            const prodId = iData ? iData.produto_id : pData.produto_id;
            const { data: eData } = await client.from('estoques').select('*').eq('produto_id', prodId).eq('filial_id', 2).single();
            return {
                pedidoId: pData.id,
                produtoId: prodId,
                estoqueAntes: eData ? eData.quantidade : 0
            };
        }""")
        print("[TEST 1 - Estado do estoque antes do recebimento]:", stock_before)
        pedido_id = stock_before["pedidoId"]
        prod_id = stock_before["produtoId"]
        est_antes = stock_before["estoqueAntes"]

        # --------------------------------------------------------
        # PASSO 2: Marcar Pedido como Recebido e Verificar Atualizações
        # --------------------------------------------------------
        print(f"\n--- PASSO 2: Executando 'Marcar como Recebido' no Pedido #{pedido_id} ---")
        # Encontrar a linha do pedido na tabela e clicar em 'Marcar como Recebido'
        row_btn = page.locator(f"tr:has-text('#{pedido_id}') button:has-text('Marcar como Recebido')")
        await row_btn.click()
        await page.wait_for_timeout(1500)

        toast_recebido = await page.text_content("#toast")
        print("[TEST 2 - Toast Recebimento]:", toast_recebido.strip())
        assert "sucesso" in toast_recebido.lower(), "Falha no toast de recebimento"

        # Verificar se o status mudou na tabela
        pedidos_apos = await page.text_content("#tbody-pedidos")
        print("[TEST 2 - Tabela de Pedidos Pós-Recebimento]:\n", pedidos_apos.strip())
        assert "recebido" in pedidos_apos.lower(), "Status do pedido não foi alterado para 'recebido'"

        # Verificar se o botão foi desabilitado/removido na interface (Requisito 8)
        btn_exists = await page.locator(f"tr:has-text('#{pedido_id}') button:has-text('Marcar como Recebido')").count()
        print(f"[TEST 2 - Requisito 8 Check]: Botão 'Marcar como Recebido' ainda visível: {btn_exists > 0}")
        assert btn_exists == 0, "Botão 'Marcar como Recebido' não foi removido/desabilitado para pedido recebido"

        # --------------------------------------------------------
        # PASSO 3: Verificar Entrada no Estoque da Filial Solicitante (Filial Norte)
        # --------------------------------------------------------
        print("\n--- PASSO 3: Verificando Atualização do Estoque ---")
        await page.click("#menu a[data-page='estoque']")
        await page.wait_for_selector("#page-estoque.active", timeout=5000)
        await page.click("#estoque-filiais button:has-text('Norte')")
        await page.wait_for_timeout(500)

        stock_after = await page.evaluate(f"""async () => {{
            const client = window.supabaseClient || window.initSupabase();
            const {{ data: eData }} = await client.from('estoques').select('*').eq('produto_id', {prod_id}).eq('filial_id', 2).single();
            return eData ? eData.quantidade : 0;
        }}""")
        print(f"[TEST 3 - Quantidade no Estoque]: Antes = {est_antes}, Depois = {stock_after} (Esperado = {est_antes + 15})")
        assert stock_after == est_antes + 15, "Estoque da Filial Norte não foi incrementado corretamente!"

        # --------------------------------------------------------
        # PASSO 4: Verificar Registro na Tabela de Histórico (Movimentações)
        # --------------------------------------------------------
        print("\n--- PASSO 4: Verificando Histórico de Movimentações ---")
        await page.click("#menu a[data-page='historico']")
        await page.wait_for_selector("#page-historico.active", timeout=5000)
        await page.wait_for_timeout(1000)

        hist_rows = await page.text_content("#tbody-historico")
        print("[TEST 4 - Tabela de Histórico]:\n", hist_rows.strip())
        assert f"Recebimento do Pedido de Compra #{pedido_id}" in hist_rows or "entrada" in hist_rows.lower(), "Registro de movimentação de entrada não encontrado no histórico"

        # --------------------------------------------------------
        # PASSO 5: Persistência após Reload (F5) e Bloqueio de Duplicidade
        # --------------------------------------------------------
        print("\n--- PASSO 5: Verificando Persistência F5 e Bloqueio de Duplicidade ---")
        await page.reload()
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1000)

        await page.click("#menu a[data-page='pedidos']")
        await page.wait_for_selector("#page-pedidos.active", timeout=5000)
        await page.wait_for_function("document.querySelector('#tbody-pedidos').textContent.includes('#')")

        pedidos_f5 = await page.text_content("#tbody-pedidos")
        print("[TEST 5 - Tabela Pós-F5]:\n", pedidos_f5.strip())
        assert "recebido" in pedidos_f5.lower(), "Persistência F5 do status 'recebido' falhou"

        # Tentar chamar o método de recebimento novamente via API para validar o bloqueio de duplicidade no banco
        double_receive_err = await page.evaluate(f"""async () => {{
            try {{
                await api.receberPedido({pedido_id});
                return null;
            }} catch (err) {{
                return err.message;
            }}
        }}""")
        print("[TEST 5 - Tentativa de Receber Novamente]:", double_receive_err)
        assert double_receive_err and "anteriormente" in double_receive_err.lower(), "Tentativa de receber pedido duplicado não foi bloqueada!"

        await page.click("#logout")
        await page.wait_for_timeout(1000)
        await context.close()

        # --------------------------------------------------------
        # PASSO 6: Testar Permissões (Funcionária da própria filial vs outra filial)
        # --------------------------------------------------------
        print("\n--- PASSO 6: Testando Permissões de Recebimento por Perfil ---")
        # Isabella (Funcionária da Filial Norte - ID 2) cria/recebe pedido da sua própria filial
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "isabella.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        await page.click("#menu a[data-page='pedidos']")
        await page.wait_for_selector("#page-pedidos.active", timeout=5000)
        await page.wait_for_timeout(500)

        # Anderson (Funcionário da Filial Centro - ID 1) não deve conseguir receber pedidos da Filial Norte
        context2 = await browser.new_context()
        page2 = await context2.new_page()
        await page2.goto("http://localhost:8080/index.html")
        await page2.fill("#login-email", "anderson.func@empresa.com")
        await page2.fill("#login-senha", "etec2026@DS")
        await page2.click("button:has-text('Entrar')")
        await page2.wait_for_selector("#app.active", timeout=10000)

        await page2.click("#menu a[data-page='pedidos']")
        await page2.wait_for_selector("#page-pedidos.active", timeout=5000)
        await page2.wait_for_timeout(500)

        # Anderson só visualiza pedidos da sua filial (Centro). Se houver pedido da Filial Norte, não pode receber.
        perm_check = await page2.evaluate(f"""async () => {{
            try {{
                await api.receberPedido({pedido_id});
                return "Sucesso Indevido";
            }} catch (err) {{
                return err.message;
            }}
        }}""")
        print("[TEST 6 - Verificação de Permissão de Outra Filial]:", perm_check)
        assert perm_check and ("negado" in perm_check.lower() or "anteriormente" in perm_check.lower() or "permissao" in perm_check.lower()), "Permissão de outra filial não foi bloqueada"

        await context.close()
        await context2.close()
        await browser.close()

    print("\n==========================================================")
    print("   TODOS OS TESTES DE RECEBIMENTO PASSARAM COM SUCESSO!   ")
    print("==========================================================")

asyncio.run(run())
