/* =====================================================================
   SGE — Módulo Central do Supabase (Cliente Frontend)
   Projeto: Lume-Joias / LumeEstoque
   ===================================================================== */

const SUPABASE_URL = 'https://pssrggtqmphcpqbdhjex.supabase.co';
// Chave anon/pública fornecida para acesso client-side no frontend
const SUPABASE_ANON_KEY = 'sb_publishable_p9yLQDR5lj0uT0F5NQ1_aw_6TyS9job';

let supabaseClient = null;

function initSupabase() {
  if (window.supabase) {
    supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    window.supabaseClient = supabaseClient;
  } else {
    console.warn('Supabase JS SDK não carregado no window.');
  }
  return supabaseClient;
}

// Inicialização automática ao carregar o script
if (typeof window !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initSupabase);
  } else {
    initSupabase();
  }
}

/**
 * Teste simples de conexão autorizada com o Supabase
 * Realiza uma consulta de leitura na tabela pública 'filiais' sem modificar dados.
 */
async function testarConexaoSupabase() {
  try {
    const client = supabaseClient || initSupabase();
    if (!client) {
      return { ok: false, error: 'Cliente Supabase não inicializado.' };
    }
    const { data, error } = await client.from('filiais').select('id, nome').limit(5);
    if (error) {
      return { ok: false, error: error.message };
    }
    return { ok: true, data };
  } catch (err) {
    return { ok: false, error: err.message || 'Erro de rede ou conexão com o Supabase' };
  }
}

// Exportação global para uso nos demais scripts frontend
if (typeof window !== 'undefined') {
  window.SUPABASE_URL = SUPABASE_URL;
  window.supabaseClient = supabaseClient;
  window.initSupabase = initSupabase;
  window.testarConexaoSupabase = testarConexaoSupabase;
}
