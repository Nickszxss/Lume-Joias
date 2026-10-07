import asyncio
from playwright.async_api import async_playwright

async def run():
    print("=== EXECUTANDO LIMPEZA DE PRODUTOS NO SUPABASE ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto("http://localhost:8080/index.html")
        await page.wait_for_timeout(1000)

        # Execute cleanup queries via page context
        result = await page.evaluate("""async () => {
            const client = window.supabaseClient || window.initSupabase();
            if (!client) return { error: 'Cliente Supabase não disponível' };

            const res = {};

            // Delete dependent records
            const { count: countItens, error: errItens } = await client.from('itens_pedido_compra').delete().neq('id', 0);
            res.itens_pedido_compra = { countItens, errItens: errItens?.message };

            const { count: countPedidos, error: errPedidos } = await client.from('pedidos_compra').delete().neq('id', 0);
            res.pedidos_compra = { countPedidos, errPedidos: errPedidos?.message };

            const { count: countTransf, error: errTransf } = await client.from('transferencias').delete().neq('id', 0);
            res.transferencias = { countTransf, errTransf: errTransf?.message };

            const { count: countMov, error: errMov } = await client.from('movimentacoes').delete().neq('id', 0);
            res.movimentacoes = { countMov, errMov: errMov?.message };

            const { count: countEst, error: errEst } = await client.from('estoques').delete().neq('id', 0);
            res.estoques = { countEst, errEst: errEst?.message };

            const { count: countProd, error: errProd } = await client.from('produtos').delete().neq('id', 0);
            res.produtos = { countProd, errProd: errProd?.message };

            // Verify users and filiais
            const { data: usuarios, count: countUsers } = await client.from('usuarios').select('id, email', { count: 'exact' });
            res.usuarios_preservados = { countUsers, totalUsers: usuarios ? usuarios.length : 0 };

            const { data: filiais, count: countFiliais } = await client.from('filiais').select('id, nome', { count: 'exact' });
            res.filiais_preservadas = { countFiliais, totalFiliais: filiais ? filiais.length : 0 };

            return res;
        }""")

        print("[CLEANUP RESULT]:", result)
        await context.close()
        await browser.close()

asyncio.run(run())
