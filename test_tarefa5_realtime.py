import asyncio
from playwright.async_api import async_playwright

async def run():
    print("==========================================================")
    print("   TESTE DE INTEGRAÇÃO - SUPABASE REALTIME (TAREFA 5)     ")
    print("==========================================================")

    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # --------------------------------------------------------
        # SESSÃO A: Robson (Gerente na Filial Oeste) observa Pedidos
        # --------------------------------------------------------
        print("\n--- PASSO 1: Sessão A (Robson) entra e abre Pedidos de Compra ---")
        context_a = await browser.new_context()
        page_a = await context_a.new_page()
        await page_a.goto("http://localhost:8080/index.html")
        await page_a.fill("#login-email", "robson.grt@empresa.com")
        await page_a.fill("#login-senha", "etec2026@DS")
        await page_a.click("button:has-text('Entrar')")
        await page_a.wait_for_selector("#app.active", timeout=10000)

        await page_a.evaluate("irPara('pedidos')")
        await page_a.wait_for_selector("#page-pedidos.active", timeout=5000)

        pedidos_iniciais_a = await page_a.text_content("#tbody-pedidos")
        print("[TEST 1 - Pedidos Iniciais Sessão A]:\n", pedidos_iniciais_a.strip())

        # --------------------------------------------------------
        # SESSÃO B: Manuella (Gerente) cria um novo Pedido de Compra
        # --------------------------------------------------------
        print("\n--- PASSO 2: Sessão B (Manuella) cria um novo Pedido de Compra ---")
        context_b = await browser.new_context()
        page_b = await context_b.new_page()
        await page_b.goto("http://localhost:8080/index.html")
        await page_b.fill("#login-email", "manuella.grt@empresa.com")
        await page_b.fill("#login-senha", "etec2026@DS")
        await page_b.click("button:has-text('Entrar')")
        await page_b.wait_for_selector("#app.active", timeout=10000)

        # Obter produto ativo para o pedido
        p_info = await page_b.evaluate("""async () => {
            const client = window.supabaseClient || window.initSupabase();
            const { data } = await client.from('produtos').select('*').eq('ativo', true).limit(1).single();
            return data;
        }""")
        p_id = p_info["id"]

        novo_pedido = await page_b.evaluate(f"""async () => {{
            return await api.criarPedido({{
                produtoId: {p_id},
                filialId: 4,
                quantidade: 25,
                solicitante: 'Manuella'
            }});
        }}""")
        pedido_id = novo_pedido["id"]
        print(f"[TEST 2 - Novo Pedido Criado na Sessão B]: ID #{pedido_id}")

        # --------------------------------------------------------
        # VERIFICAÇÃO REALTIME NA SESSÃO A (Sem F5 / Sem Reload)
        # --------------------------------------------------------
        print("\n--- PASSO 3: Verificando Atualização Automática em Tempo Real na Sessão A ---")
        # Aguardar recebimento do evento via Realtime WebSocket
        await page_a.wait_for_timeout(3000)

        pedidos_realtime_a = await page_a.text_content("#tbody-pedidos")
        print("[TEST 3 - Pedidos Atualizados em Tempo Real Sessão A]:\n", pedidos_realtime_a.strip())
        assert f"#{pedido_id}" in pedidos_realtime_a or str(pedido_id) in pedidos_realtime_a, "O novo pedido não foi renderizado em tempo real na Sessão A!"
        print("[TEST 3 - Realtime em Pedidos de Compra OK!]")

        # --------------------------------------------------------
        # SESSÃO B: Ajusta estoque e verifica Realtime na Sessão A (Estoque)
        # --------------------------------------------------------
        print("\n--- PASSO 4: Sessão A navega para Estoque, Sessão B ajusta Estoque ---")
        await page_a.evaluate("irPara('estoque')")
        await page_a.wait_for_selector("#page-estoque.active", timeout=5000)

        # Sessão B faz um ajuste de estoque no produto p_id para a Filial 1
        await page_b.evaluate(f"""async () => {{
            return await api.ajustarEstoque({{
                produtoId: {p_id},
                filialId: 1,
                tipo: 'entrada',
                quantidade: 50,
                motivo: 'Ajuste Realtime Teste',
                usuario: 'Manuella'
            }});
        }}""")

        await page_a.wait_for_timeout(3000)
        estoque_a = await page_a.text_content("#tbody-estoque")
        print("[TEST 4 - Estoque Atualizado em Tempo Real na Sessão A]:\n", estoque_a.strip())
        assert str(p_info["nome"]) in estoque_a, "Ajuste de estoque não refletiu em tempo real na Sessão A!"
        print("[TEST 4 - Realtime em Estoque OK!]")

        # --------------------------------------------------------
        # PASSO 5: Encerramento das Subscrições no Logout
        # --------------------------------------------------------
        print("\n--- PASSO 5: Verificando Encerramento das Subscrições no Logout ---")
        channel_before = await page_a.evaluate("realtimeChannel !== null")
        print("[TEST 5 - Canal Ativo Antes do Logout]:", channel_before)
        assert channel_before is True, "Canal Realtime deveria estar ativo!"

        await page_a.click("#logout")
        await page_a.wait_for_timeout(1000)

        channel_after = await page_a.evaluate("realtimeChannel === null")
        print("[TEST 5 - Canal Removido Após o Logout]:", channel_after)
        assert channel_after is True, "Canal Realtime não foi removido após o logout!"

        await context_a.close()
        await context_b.close()
        await browser.close()

    print("\n==========================================================")
    print("   TODOS OS TESTES DA TAREFA 5 PASSARAM COM SUCESSO!     ")
    print("==========================================================")

asyncio.run(run())
