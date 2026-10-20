import asyncio
from playwright.async_api import async_playwright

async def test_criar_transferencia_auth_user_query():
    print("=== TESTE 22: VALIDAÇÃO DE CONSULTA POR AUTH_USER_ID EM CRIAR_TRANSFERENCIA ===")
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()

        await page.goto("http://localhost:8080/index.html")
        await page.wait_for_timeout(500)

        # 1. Simular login e testar fluxo do api.criarTransferencia com mock do client Supabase
        test_res = await page.evaluate("""
            async () => {
                const logs = [];
                // Mock do client Supabase
                const mockClient = {
                    from: (table) => {
                        logs.push(`from:${table}`);
                        if (table === 'estoques') {
                            return {
                                select: () => ({
                                    eq: () => ({
                                        eq: () => ({
                                            maybeSingle: async () => ({ data: { quantidade: 100 }, error: null })
                                        })
                                    })
                                })
                            };
                        }
                        if (table === 'usuarios') {
                            return {
                                select: (cols) => ({
                                    eq: (col, val) => {
                                        logs.push(`usuarios.eq:${col}=${val}`);
                                        return {
                                            eq: (col2, val2) => ({
                                                single: async () => {
                                                    if (col === 'auth_user_id' && val === 'uuid-test-123') {
                                                        return { data: { id: 7, nome: 'Usuário Teste' }, error: null };
                                                    }
                                                    return { data: null, error: { message: 'Not found' } };
                                                }
                                            })
                                        };
                                    }
                                })
                            };
                        }
                        if (table === 'transferencias') {
                            return {
                                insert: (payload) => {
                                    logs.push(`transferencias.insert:${JSON.stringify(payload)}`);
                                    return {
                                        select: () => ({
                                            single: async () => ({
                                                data: { id: 101, ...payload[0] },
                                                error: null
                                            })
                                        })
                                    };
                                }
                            };
                        }
                        return {};
                    },
                    auth: {
                        getUser: async () => ({
                            data: { user: { id: 'uuid-test-123', email: 'test@empresa.com' } },
                            error: null
                        })
                    }
                };

                const origGetClient = getSupabaseClient;
                window.getSupabaseClient = () => mockClient;

                try {
                    // Teste 1: Transferência válida mantendo usuarioDb.id no payload
                    const res = await api.criarTransferencia({
                        produtoId: 1,
                        origemId: 1,
                        destinoId: 2,
                        quantidade: 5
                    });

                    // Teste 2: Origem e destino iguais
                    let erroOrigemDestino = null;
                    try {
                        await api.criarTransferencia({ produtoId: 1, origemId: 1, destinoId: 1, quantidade: 5 });
                    } catch (e) {
                        erroOrigemDestino = e.message;
                    }

                    // Teste 3: Quantidade inválida
                    let erroQtd = null;
                    try {
                        await api.criarTransferencia({ produtoId: 1, origemId: 1, destinoId: 2, quantidade: -1 });
                    } catch (e) {
                        erroQtd = e.message;
                    }

                    // Teste 4: Sessão sem user.id
                    window.getSupabaseClient = () => ({
                        ...mockClient,
                        auth: { getUser: async () => ({ data: { user: null }, error: null }) }
                    });
                    let erroSessao = null;
                    try {
                        await api.criarTransferencia({ produtoId: 1, origemId: 1, destinoId: 2, quantidade: 5 });
                    } catch (e) {
                        erroSessao = e.message;
                    }

                    // Teste 5: Usuário sem cadastro no BD / inativo
                    window.getSupabaseClient = () => ({
                        ...mockClient,
                        auth: { getUser: async () => ({ data: { user: { id: 'uuid-desconhecido', email: 'x@x.com' } }, error: null }) }
                    });
                    let erroUsuarioDb = null;
                    try {
                        await api.criarTransferencia({ produtoId: 1, origemId: 1, destinoId: 2, quantidade: 5 });
                    } catch (e) {
                        erroUsuarioDb = e.message;
                    }

                    return {
                        success: true,
                        res,
                        logs,
                        erroOrigemDestino,
                        erroQtd,
                        erroSessao,
                        erroUsuarioDb
                    };
                } finally {
                    window.getSupabaseClient = origGetClient;
                }
            }
        """)

        assert test_res["success"] is True, "Execução do teste falhou."
        # Confirmar que a busca foi feita por auth_user_id
        assert any("usuarios.eq:auth_user_id=uuid-test-123" in log for log in test_res["logs"]), f"Consulta por auth_user_id não realizada! Logs: {test_res['logs']}"
        # Confirmar que usuario_id no payload recebeu usuarioDb.id (7)
        assert any('"usuario_id":7' in log for log in test_res["logs"]), f"usuario_id no payload não foi o ID do banco (7)! Logs: {test_res['logs']}"
        # Validar mensagens de erro das regras
        assert "Filial de Origem e Destino devem ser diferentes" in test_res["erroOrigemDestino"]
        assert "quantidade" in test_res["erroQtd"].lower()
        assert "Sessão inválida" in test_res["erroSessao"]
        assert "Usuário autenticado não encontrado" in test_res["erroUsuarioDb"]

        print("[OK] Consulta por auth_user_id, preservação do usuarioDb.id e validações testadas com sucesso.")

        await context.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(test_criar_transferencia_auth_user_query())
