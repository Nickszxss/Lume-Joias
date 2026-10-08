import asyncio
from playwright.async_api import async_playwright

async def run():
    print("==========================================================")
    print("   TESTE DE INTEGRAÇÃO - RESTRINGIR CONCLUSÃO TRANSFERÊNCIAS ")
    print("==========================================================")

    async with async_playwright() as p:
        browser = await p.chromium.launch()

        # --------------------------------------------------------
        # PASSO 1: Preparação - Gerente (Robson) cria produto na Filial Norte e solicita transferência para Filial Sul
        # --------------------------------------------------------
        print("\n--- PASSO 1: Criando Produto e Solicitando Transferência (Norte -> Sul) ---")
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        # Garantir produto com estoque na Filial Norte (ID 2)
        await page.wait_for_timeout(500)
        await page.click("#menu a[data-page='produtos']")
        await page.wait_for_selector("#page-produtos.active", timeout=5000)
        await page.click("button:has-text('+ Novo Produto')")
        await page.wait_for_selector("#modal-produto", timeout=5000)
        await page.select_option("#p-nome", value="Brinco de prata") # SKU 005
        await page.select_option("#p-filial", value="2") # Filial Norte
        await page.fill("#p-min", "5")
        await page.fill("#p-qtd", "30")
        await page.click("#modal-produto button:has-text('Salvar')")
        await page.wait_for_timeout(1000)

        # Solicitar transferência de 10 unidades de Filial Norte (2) -> Filial Sul (3)
        await page.click("#menu a[data-page='transferencias']")
        await page.wait_for_selector("#page-transferencias.active", timeout=5000)

        await page.click("button:has-text('+ Nova Transferência')")
        await page.wait_for_selector("#modal-transferencia", timeout=5000)

        await page.select_option("#t-origem", value="2") # Norte
        await page.select_option("#t-destino", value="3") # Sul
        await page.fill("#t-qtd", "10")
        await page.click("#modal-transferencia button:has-text('Solicitar')")
        await page.wait_for_timeout(1000)

        toast_transf = await page.text_content("#toast")
        print("[TEST 1 - Solicitar Transferência Toast]:", toast_transf.strip())
        assert "solicitada" in toast_transf.lower(), "Falha ao solicitar transferência"

        # Obter ID da transferência criada
        transf_info = await page.evaluate("""async () => {
            const client = window.supabaseClient || window.initSupabase();
            const { data } = await client.from('transferencias').select('*').order('id', { ascending: false }).limit(1).single();
            return data;
        }""")
        transf_id = transf_info["id"]
        print(f"[TEST 1 - Transferência criada]: ID #{transf_id} (Origem: Filial Norte ID 2 -> Destino: Filial Sul ID 3)")

        await page.click("#logout")
        await page.wait_for_timeout(1000)
        await context.close()

        # --------------------------------------------------------
        # PASSO 2: Testar bloqueio para Funcionária da Filial de ORIGEM (Isabella - Norte ID 2)
        # --------------------------------------------------------
        print("\n--- PASSO 2: Testando Bloqueio na Filial de Origem (Isabella - Norte) ---")
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "isabella.func@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        await page.click("#menu a[data-page='transferencias']")
        await page.wait_for_selector("#page-transferencias.active", timeout=5000)

        # Verificar se o botão Concluir para a transferência está desabilitado na UI
        orig_btn = page.locator(f"tr:has-text('#{transf_id}') button:has-text('Concluir')")
        is_disabled = await orig_btn.is_disabled()
        print(f"[TEST 2 - Origem UI Check]: Botão 'Concluir' desabilitado: {is_disabled}")
        assert is_disabled, "O botão 'Concluir' deveria estar desabilitado para o funcionário da origem!"

        # Tentar chamar api.concluirTransferencia via JS/API para testar a trava de segurança na camada de dados
        api_err = await page.evaluate(f"""async () => {{
            try {{
                await api.concluirTransferencia({transf_id});
                return "Sucesso Indevido";
            }} catch (err) {{
                return err.message;
            }}
        }}""")
        print("[TEST 2 - Origem API Check Error]:", api_err)
        assert "Acesso negado" in api_err and "origem" in api_err.lower(), "Trava de dados falhou para a filial de origem!"

        await page.click("#logout")
        await page.wait_for_timeout(1000)
        await context.close()

        # --------------------------------------------------------
        # PASSO 3: Testar Sucesso na Filial de DESTINO (Nicoly - Sul ID 3)
        # --------------------------------------------------------
        print("\n--- PASSO 3: Testando Conclusão na Filial de Destino (Nicoly - Sul) ---")
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "nicoly.func@empresa.com")
        await page.fill("#login-senha", "160611")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        await page.click("a[data-page='transferencias']")
        await page.wait_for_timeout(1000)
        await page.wait_for_selector("#page-transferencias.active", timeout=5000)

        dest_btn = page.locator(f"tr:has-text('#{transf_id}') button:has-text('Concluir')")
        is_dest_disabled = await dest_btn.is_disabled()
        print(f"[TEST 3 - Destino UI Check]: Botão 'Concluir' desabilitado: {is_dest_disabled}")
        assert not is_dest_disabled, "O botão 'Concluir' deveria estar HABILITADO para o funcionário do destino!"

        # Executar conclusão
        await dest_btn.click()
        await page.wait_for_timeout(1500)

        toast_concl = await page.text_content("#toast")
        print("[TEST 3 - Toast Conclusão]:", toast_concl.strip())
        assert "sucesso" in toast_concl.lower(), "Falha ao concluir transferência pelo destino"

        # Verificar se status mudou para 'concluida'
        rows_apos = await page.text_content("#tbody-transferencias")
        print("[TEST 3 - Tabela Pós-Conclusão]:\n", rows_apos.strip())
        assert "concluida" in rows_apos.lower(), "Status da transferência não atualizou para 'concluida'"

        # --------------------------------------------------------
        # PASSO 4: Testar Bloqueio de Duplicidade
        # --------------------------------------------------------
        print("\n--- PASSO 4: Testando Bloqueio de Tentativa Duplicada ---")
        dup_err = await page.evaluate(f"""async () => {{
            try {{
                await api.concluirTransferencia({transf_id});
                return "Sucesso Indevido";
            }} catch (err) {{
                return err.message;
            }}
        }}""")
        print("[TEST 4 - Tentativa de Conclusão Duplicada]:", dup_err)
        assert "anteriormente" in dup_err.lower(), "Bloqueio de duplicidade na conclusão falhou!"

        await page.click("#logout")
        await page.wait_for_timeout(1000)
        await context.close()

        # --------------------------------------------------------
        # PASSO 5: Testar Permissão de Gerente (Robson) para Concluir Qualquer Transferência
        # --------------------------------------------------------
        print("\n--- PASSO 5: Testando Permissão do Gerente ---")
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)

        # Criar nova transferência Leste (4) -> Oeste (5)
        await page.click("a[data-page='transferencias']")
        await page.wait_for_timeout(1000)
        await page.wait_for_selector("#page-transferencias.active", timeout=5000)

        await page.click("button:has-text('+ Nova Transferência')")
        await page.wait_for_selector("#modal-transferencia", timeout=5000)

        await page.select_option("#t-origem", value="2") # Norte
        await page.select_option("#t-destino", value="1") # Centro
        await page.fill("#t-qtd", "5")
        await page.click("#modal-transferencia button:has-text('Solicitar')")
        await page.wait_for_timeout(1000)

        t_mgr_id = await page.evaluate("""async () => {
            const client = window.supabaseClient || window.initSupabase();
            const { data } = await client.from('transferencias').select('*').order('id', { ascending: false }).limit(1).single();
            return data.id;
        }""")

        # Gerente Robson (Filial Oeste) pode concluir transferência entre Norte e Centro
        await page.click(f"tr:has-text('#{t_mgr_id}') button:has-text('Concluir')")
        await page.wait_for_timeout(1500)

        toast_mgr = await page.text_content("#toast")
        print("[TEST 5 - Gerente Conclusão Toast]:", toast_mgr.strip())
        assert "sucesso" in toast_mgr.lower(), "Gerente falhou ao concluir transferência"

        await context.close()
        await browser.close()

    print("\n==========================================================")
    print("   TODOS OS TESTES DA TAREFA 2 PASSARAM COM SUCESSO!     ")
    print("==========================================================")

asyncio.run(run())
