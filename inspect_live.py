import asyncio
from playwright.async_api import async_playwright

async def inspect():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(viewport={"width": 1280, "height": 800})
        page = await context.new_page()

        page.on("console", lambda msg: print(f"CONSOLE [{msg.type}]: {msg.text}"))
        page.on("pageerror", lambda err: print(f"PAGE ERROR: {err}"))
        page.on("requestfailed", lambda req: print(f"REQ FAILED: {req.url} {req.failure}"))

        print("--- Navigating to live site ---")
        await page.goto("https://nickszxss.github.io/Lume-Joias/", wait_until="networkidle")

        print("\n--- Evaluating Supabase and Users directly from browser ---")
        db_check = await page.evaluate("""async () => {
            const client = window.supabaseClient;
            if (!client) return { error: 'No supabaseClient' };
            try {
                const { data: usuarios, error: uErr } = await client.from('usuarios').select('*');
                const { data: filiais, error: fErr } = await client.from('filiais').select('*');
                const { data: produtos, error: pErr } = await client.from('produtos').select('*');
                const { data: estoques, error: eErr } = await client.from('estoques').select('*');
                const { data: movimentacoes, error: mErr } = await client.from('movimentacoes').select('*');
                const { data: transferencias, error: tErr } = await client.from('transferencias').select('*');
                const { data: pedidos, error: pedErr } = await client.from('pedidos_compra').select('*');

                return {
                    usuarios: { data: usuarios, error: uErr },
                    filiaisCount: filiais ? filiais.length : null,
                    produtosCount: produtos ? produtos.length : null,
                    estoquesCount: estoques ? estoques.length : null,
                    movimentacoesCount: movimentacoes ? movimentacoes.length : null,
                    transferenciasCount: transferencias ? transferencias.length : null,
                    pedidosCount: pedidos ? pedidos.length : null
                };
            } catch(e) {
                return { exception: e.message };
            }
        }""")

        import json
        print("DB Check Result:", json.dumps(db_check, indent=2))

        await browser.close()

asyncio.run(inspect())
