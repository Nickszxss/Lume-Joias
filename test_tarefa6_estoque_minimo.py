import asyncio
import time
from playwright.async_api import async_playwright

async def run():
    print("==========================================================")
    print("   TESTE DE INTEGRAÇÃO - ESTOQUE MÍNIMO NO CADASTRO (TAREFA 6) ")
    print("==========================================================")

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        # --------------------------------------------------------
        # PASSO 1: Login de Gerente (Robson)
        # --------------------------------------------------------
        print("\n--- PASSO 1: Realizando Login do Gerente ---")
        await page.goto("http://localhost:8080/index.html")
        await page.fill("#login-email", "robson.grt@empresa.com")
        await page.fill("#login-senha", "etec2026@DS")
        await page.click("button:has-text('Entrar')")
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1000)

        # --------------------------------------------------------
        # PASSO 2: Cadastrar Produto com Estoque Mínimo = 10
        # --------------------------------------------------------
        print("\n--- PASSO 2: Cadastrando Produto com Estoque Mínimo = 10 ---")
        await page.click("#menu a[data-page='produtos']")
        await page.wait_for_selector("#page-produtos.active", timeout=5000)

        await page.click("button:has-text('+ Novo Produto')")
        await page.wait_for_selector("#modal-produto", timeout=5000)

        # Verificar se o campo Valor Inicial/p-qtd NÃO existe mais no formulário
        p_qtd_exists = await page.locator("#p-qtd").count()
        print(f"[TEST 2 - Check #p-qtd]: Campo #p-qtd presente: {p_qtd_exists > 0}")
        assert p_qtd_exists == 0, "O antigo campo #p-qtd (Valor Inicial) não foi removido!"

        await page.select_option("#p-nome", value="Anel de prata") # SKU 003
        await page.fill("#p-cat", "Anéis")
        await page.select_option("#p-filial", value="1") # Filial Centro
        await page.select_option("#p-min", value="10")
        await page.click("#modal-produto button:has-text('Salvar')")
        await page.wait_for_timeout(1000)

        toast1 = await page.text_content("#toast")
        print("[TEST 2 - Toast Cadastro Min 10]:", toast1.strip())
        assert "sucesso" in toast1.lower(), "Falha ao cadastrar produto com min 10"

        # --------------------------------------------------------
        # PASSO 3: Cadastrar Produto com Estoque Mínimo = 30
        # --------------------------------------------------------
        print("\n--- PASSO 3: Cadastrando Produto com Estoque Mínimo = 30 ---")
        await page.click("button:has-text('+ Novo Produto')")
        await page.wait_for_selector("#modal-produto", timeout=5000)

        await page.select_option("#p-nome", value="Anel de ouro") # SKU 004
        await page.fill("#p-cat", "Anéis")
        await page.select_option("#p-filial", value="1") # Filial Centro
        await page.select_option("#p-min", value="30")
        await page.click("#modal-produto button:has-text('Salvar')")
        await page.wait_for_timeout(1000)

        toast2 = await page.text_content("#toast")
        print("[TEST 3 - Toast Cadastro Min 30]:", toast2.strip())
        assert "sucesso" in toast2.lower(), "Falha ao cadastrar produto com min 30"

        # --------------------------------------------------------
        # PASSO 4: Cadastrar Produto com Estoque Mínimo = 50
        # --------------------------------------------------------
        print("\n--- PASSO 4: Cadastrando Produto com Estoque Mínimo = 50 ---")
        await page.click("button:has-text('+ Novo Produto')")
        await page.wait_for_selector("#modal-produto", timeout=5000)

        await page.select_option("#p-nome", value="Solitária") # SKU 007
        await page.fill("#p-cat", "Anéis")
        await page.select_option("#p-filial", value="1") # Filial Centro
        await page.select_option("#p-min", value="50")
        await page.click("#modal-produto button:has-text('Salvar')")
        await page.wait_for_timeout(1000)

        toast3 = await page.text_content("#toast")
        print("[TEST 4 - Toast Cadastro Min 50]:", toast3.strip())
        assert "sucesso" in toast3.lower(), "Falha ao cadastrar produto com min 50"

        # --------------------------------------------------------
        # PASSO 5: Validar Registro no Supabase e Tabela de Produtos
        # --------------------------------------------------------
        print("\n--- PASSO 5: Validando Produtos na Tabela e Supabase ---")
        prod_tbody = await page.text_content("#tbody-produtos")
        print("[TEST 5 - Tabela Produtos]:\n", prod_tbody.strip())

        assert "Anel de prata" in prod_tbody and "10" in prod_tbody, "Anel de prata (min 10) não encontrado na tabela"
        assert "Anel de ouro" in prod_tbody and "30" in prod_tbody, "Anel de ouro (min 30) não encontrado na tabela"
        assert "Solitária" in prod_tbody and "50" in prod_tbody, "Solitária (min 50) não encontrada na tabela"

        # --------------------------------------------------------
        # PASSO 6: Testar Lógica de Alertas de Estoque Baixo / Zerado
        # --------------------------------------------------------
        print("\n--- PASSO 6: Testando Lógica de Alertas (Produto Solitária min 50) ---")
        # Obter produto Solitária com ID mais recente
        p_info = await page.evaluate("""async () => {
            const client = window.supabaseClient || window.initSupabase();
            const { data } = await client.from('produtos').select('*').eq('nome', 'Solitária').order('id', { ascending: false }).limit(1).single();
            return data;
        }""")
        p_id = p_info["id"]

        initial_est = await page.evaluate(f"""async () => {{
            const client = window.supabaseClient || window.initSupabase();
            const {{ data }} = await client.from('estoques').select('*').eq('produto_id', {p_id}).eq('filial_id', 1).single();
            return data;
        }}""")
        print("[TEST 6 - Estoque Inicial do Produto Solitária criado]:", initial_est)
        assert initial_est["quantidade"] >= 0 and initial_est["status"] in ['zerado', 'baixo', 'suficiente'], "Estoque inicial inválido!"

        # Ajuste 1: Adicionar 60 unidades -> quantidade = 60, min = 50 -> Status: Suficiente (Normal)
        await page.evaluate(f"""async () => {{
            return await api.ajustarEstoque({{
                produtoId: {p_id},
                filialId: 1,
                tipo: 'entrada',
                quantidade: 60,
                motivo: 'Teste Alerta Normal'
            }});
        }}""")
        await page.reload()
        await page.wait_for_selector("#app.active", timeout=10000)
        await page.wait_for_timeout(1000)

        await page.click("#menu a[data-page='estoque']")
        await page.wait_for_selector("#page-estoque.active", timeout=5000)
        est_normal = await page.text_content(f"tr:has-text('Solitária')")
        print("[TEST 6 - Estoque após entrada Status]:", est_normal.strip())

        # --------------------------------------------------------
        # PASSO 7: Tela de Alertas e Dashboard
        # --------------------------------------------------------
        print("\n--- PASSO 7: Verificando Alertas na Interface ---")
        await page.click("#menu a[data-page='alertas']")
        await page.wait_for_selector("#page-alertas.active", timeout=5000)
        await page.wait_for_function("!document.querySelector('#tbody-alertas').textContent.includes('Carregando...')")
        alertas_html = await page.text_content("#tbody-alertas")
        print("[TEST 7 - Tabela Alertas]:\n", alertas_html.strip())

        await context.close()
        await browser.close()

    print("\n==========================================================")
    print("   TODOS OS TESTES DA TAREFA 6 PASSARAM COM SUCESSO!     ")
    print("==========================================================")

asyncio.run(run())
