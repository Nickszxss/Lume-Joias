/* =====================================================================
   SGE — Camada de Front-end (visualização + interação)
   A lógica de negócio e persistência se comunica diretamente com o Supabase.
   ===================================================================== */

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
 * Sanitização contra injeção de scripts (XSS) ao inserir texto dinâmico no DOM via innerHTML
 */
function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
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
  window.escapeHtml = escapeHtml;
}

// ---------- CONFIGURAÇÃO DA API E BASE DADOS DEMO/STATIC ----------
const IS_LOCAL = false;
const API_BASE_URL = '';

// Fallback de dados estáticos para simulação completa quando backend não estiver exposto publicamente
let mockFiliais = [
  { id: 1, nome: 'Filial Centro' },
  { id: 2, nome: 'Filial Norte' },
  { id: 3, nome: 'Filial Sul' },
  { id: 4, nome: 'Filial Leste' },
  { id: 5, nome: 'Filial Oeste' }
];

let mockProdutos = [];
let mockEstoques = [];
let mockTransferencias = [];
let mockPedidos = [];
let mockMovimentacoes = [];

// Wrapper único de fetch: centraliza headers, tratamento de erro, JSON e fallback local.
async function apiRequest(path, options = {}) {
  let res;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, {
      headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
      ...options
    });
  } catch (err) {
    return resolverMockLocal(path, options);
  }

  if (!res.ok) {
    let msg = `Erro ${res.status}`;
    try { const body = await res.json(); msg = body.message || msg; } catch (_) {}
    throw new Error(msg);
  }

  if (res.status === 204) return null;
  return await res.json();
}

function resolverMockLocal(path, options) {
  const method = (options.method || 'GET').toUpperCase();
  const body = options.body ? JSON.parse(options.body) : {};

  if (path === '/filiais' && method === 'GET') return mockFiliais;
  if (path === '/produtos' && method === 'GET') return mockProdutos;
  if (path === '/produtos' && method === 'POST') {
    const novoP = { id: mockProdutos.length + 1, sku: body.sku, nome: body.nome, categoria: body.categoria || 'Geral', qtd_minima: body.qtd_minima || 0 };
    mockProdutos.push(novoP);
    mockFiliais.forEach(f => mockEstoques.push({ produto_id: novoP.id, filial_id: f.id, quantidade: body.qtd_inicial || 0, status: statusEstoque(body.qtd_inicial || 0, body.qtd_minima || 0) }));
    return novoP;
  }

  if (path.startsWith('/estoque') && method === 'GET' && !path.includes('/alertas')) {
    const urlParams = new URLSearchParams(path.split('?')[1] || '');
    const fid = urlParams.get('filialId');
    return fid ? mockEstoques.filter(e => e.filial_id == fid) : mockEstoques;
  }

  if (path === '/estoque/ajustar' && method === 'POST') {
    let est = mockEstoques.find(e => e.produto_id == body.produtoId && e.filial_id == body.filialId);
    if (!est) {
      est = { produto_id: body.produtoId, filial_id: body.filialId, quantidade: 0, status: 'zerado' };
      mockEstoques.push(est);
    }
    const ant = est.quantidade;
    est.quantidade = body.tipo === 'entrada' ? est.quantidade + body.quantidade : Math.max(0, est.quantidade - body.quantidade);
    const prd = mockProdutos.find(p => p.id == body.produtoId);
    est.status = statusEstoque(est.quantidade, prd ? prd.qtd_minima : 0);

    mockMovimentacoes.unshift({
      data: new Date().toLocaleString('pt-BR'),
      produto_id: body.produtoId,
      produtoNome: prd ? prd.nome : 'Produto',
      filial_id: body.filialId,
      filialNome: mockFiliais.find(f => f.id == body.filialId)?.nome || 'Filial',
      tipo: body.tipo,
      anterior: ant,
      nova: est.quantidade,
      usuario: body.usuario || 'Usuário',
      motivo: body.motivo || 'Ajuste manual'
    });
    return est;
  }

  if (path === '/transferencias' && method === 'GET') return mockTransferencias;
  if (path === '/transferencias' && method === 'POST') {
    const prd = mockProdutos.find(p => p.id == body.produtoId);
    const orig = mockFiliais.find(f => f.id == body.origemId);
    const dest = mockFiliais.find(f => f.id == body.destinoId);
    const novaT = {
      id: mockTransferencias.length + 1,
      produto_id: body.produtoId, produtoNome: prd?.nome,
      origem_id: body.origemId, origemNome: orig?.nome,
      destino_id: body.destinoId, destinoNome: dest?.nome,
      quantidade: body.quantidade, solicitante: body.solicitante,
      data: new Date().toLocaleDateString('pt-BR'), status: 'pendente'
    };
    mockTransferencias.unshift(novaT);
    return novaT;
  }

  if (path.includes('/transferencias/') && path.endsWith('/concluir')) {
    const id = path.split('/')[2];
    const t = mockTransferencias.find(item => item.id == id);
    if (t) t.status = 'concluida';
    return t;
  }

  if (path === '/pedidos' && method === 'GET') return mockPedidos;
  if (path === '/pedidos' && method === 'POST') {
    const prd = mockProdutos.find(p => p.id == body.produtoId);
    const fil = mockFiliais.find(f => f.id == body.filialId);
    const novoP = {
      id: mockPedidos.length + 1,
      produto_id: body.produtoId, produtoNome: prd?.nome,
      quantidade: body.quantidade, filial_id: body.filialId, filialNome: fil?.nome,
      solicitante: body.solicitante, data: new Date().toLocaleDateString('pt-BR'), status: 'aberto'
    };
    mockPedidos.unshift(novoP);
    return novoP;
  }

  if (path.includes('/pedidos/') && path.endsWith('/receber')) {
    const id = path.split('/')[2];
    const p = mockPedidos.find(item => item.id == id);
    if (p) {
      if (p.status === 'recebido') throw new Error('Este pedido de compra já foi marcado como recebido anteriormente.');
      p.status = 'recebido';
      let est = mockEstoques.find(e => e.produto_id == p.produto_id && e.filial_id == p.filial_id);
      if (!est) {
        est = { produto_id: p.produto_id, filial_id: p.filial_id, quantidade: 0, status: 'zerado' };
        mockEstoques.push(est);
      }
      const ant = est.quantidade;
      est.quantidade += p.quantidade;
      const prd = mockProdutos.find(prdItem => prdItem.id == p.produto_id);
      est.status = statusEstoque(est.quantidade, prd ? prd.qtd_minima : 0);

      mockMovimentacoes.unshift({
        data: new Date().toLocaleString('pt-BR'),
        produto_id: p.produto_id,
        produtoNome: prd ? prd.nome : 'Produto',
        filial_id: p.filial_id,
        filialNome: mockFiliais.find(f => f.id == p.filial_id)?.nome || 'Filial',
        tipo: 'entrada',
        anterior: ant,
        nova: est.quantidade,
        usuario: usuario ? usuario.nome : 'Usuário',
        motivo: `Recebimento do Pedido de Compra #${p.id}`
      });
    }
    return p;
  }

  if (path === '/estoque/alertas' && method === 'GET') {
    const alertas = mockEstoques.filter(e => e.status === 'baixo' || e.status === 'zerado').map(e => {
      const p = mockProdutos.find(prd => prd.id === e.produto_id) || {};
      const f = mockFiliais.find(fil => fil.id === e.filial_id) || {};
      return { ...e, sku: p.sku, produtoNome: p.nome, filialNome: f.nome, quantidadeMinima: p.qtd_minima };
    });
    return {
      totalBaixo: alertas.filter(a => a.status === 'baixo').length,
      totalZerado: alertas.filter(a => a.status === 'zerado').length,
      itens: alertas
    };
  }

  if (path.startsWith('/historico') && method === 'GET') return mockMovimentacoes;

  if (path.startsWith('/dashboard') && method === 'GET') {
    const urlParams = new URLSearchParams(path.split('?')[1] || '');
    const fid = urlParams.get('filialId');
    const listE = fid ? mockEstoques.filter(e => e.filial_id == fid) : mockEstoques;
    const totalItens = listE.reduce((sum, e) => sum + e.quantidade, 0);
    const totalBaixo = listE.filter(e => e.status === 'baixo').length;
    const totalZerado = listE.filter(e => e.status === 'zerado').length;
    const estoquePorFilial = mockFiliais.map(f => ({
      nome: f.nome,
      total: mockEstoques.filter(e => e.filial_id === f.id).reduce((s, e) => s + e.quantidade, 0)
    }));
    return {
      totalItens,
      totalProdutos: mockProdutos.length,
      totalBaixo,
      totalZerado,
      totalTransferenciasPendentes: mockTransferencias.filter(t => t.status === 'pendente').length,
      estoquePorFilial,
      movimentacoesSemana: { labels: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'], entradas: [12, 19, 3, 5, 2, 3, 10], saidas: [2, 3, 20, 5, 1, 4, 8] },
      alertas: mockEstoques.filter(e => e.status === 'baixo' || e.status === 'zerado').map(e => ({
        ...e,
        produtoNome: mockProdutos.find(p => p.id === e.produto_id)?.nome,
        filialNome: mockFiliais.find(f => f.id === e.filial_id)?.nome,
        quantidadeMinima: mockProdutos.find(p => p.id === e.produto_id)?.qtd_minima
      }))
    };
  }

  return [];
}

// Helper para obter o cliente Supabase ativo
function getSupabaseClient() {
  return window.supabaseClient || (typeof window.initSupabase === 'function' ? window.initSupabase() : null);
}

// Operações da API com cliente Supabase direto (com fallback gracioso para mock estático)
const api = {
  login: (dados) => apiRequest('/auth/login', { method: 'POST', body: JSON.stringify(dados) }),

  listarFiliais: async () => {
    const client = getSupabaseClient();
    if (client) {
      const { data, error } = await client.from('filiais').select('*').order('id', { ascending: true });
      if (!error && data && data.length > 0) return data;
    }
    return apiRequest('/filiais');
  },

  listarProdutos: async () => {
    const client = getSupabaseClient();
    if (client) {
      const { data, error } = await client.from('produtos').select('*').order('id', { ascending: true });
      if (!error && data) {
        return data.map(p => ({
          id: p.id,
          sku: p.sku || p.codigo || obterSkuPorNome(p.nome),
          nome: p.nome,
          categoria: p.categoria || p.descricao || 'Geral',
          qtd_minima: p.qtd_minima ?? 0,
          ativo: p.ativo !== false
        }));
      }
    }
    return apiRequest('/produtos');
  },

  editarProduto: async (id, dados) => {
    if (usuario && usuario.tipo !== 'gerente') {
      throw new Error('Apenas gerentes possuem permissão para editar produtos.');
    }
    if (!dados.nome || !dados.sku) {
      throw new Error('Nome e SKU do produto são obrigatórios.');
    }
    if (!Number.isInteger(dados.qtd_minima) || dados.qtd_minima < 0) {
      throw new Error('A quantidade mínima deve ser um número inteiro maior ou igual a zero.');
    }

    const client = getSupabaseClient();
    if (client) {
      const { data: existingSkus, error: skuErr } = await client
        .from('produtos')
        .select('id, codigo')
        .eq('codigo', dados.sku)
        .neq('id', id);

      if (skuErr) {
        throw new Error(skuErr.message || 'Erro ao verificar duplicidade de SKU.');
      }

      if (existingSkus && existingSkus.length > 0) {
        throw new Error(`O SKU '${dados.sku}' já está em uso por outro produto.`);
      }

      const payload = {
        nome: dados.nome,
        codigo: dados.sku,
        descricao: dados.categoria || 'Geral',
        qtd_minima: dados.qtd_minima
      };

      const { data, error } = await client
        .from('produtos')
        .update(payload)
        .eq('id', id)
        .select()
        .single();

      if (error) {
        throw new Error(error.message || 'Erro ao atualizar dados do produto no Supabase.');
      }
      notificarRealtime('produtos', { id });
      return data;
    }
    return apiRequest(`/produtos/${id}`, { method: 'PUT', body: JSON.stringify(dados) });
  },

  inativarProdutoLocal: async (produtoId, filialId) => {
    if (usuario && usuario.tipo !== 'gerente') {
      throw new Error('Apenas gerentes possuem permissão para retirar produtos de uso.');
    }

    const targetFilial = filialId || (usuario ? usuario.filial_id : null);
    if (!targetFilial) {
      throw new Error('Filial não identificada para inativação local.');
    }

    if (usuario && usuario.tipo === 'gerente' && usuario.filial_id && targetFilial != usuario.filial_id) {
      throw new Error('Gerente só pode retirar de uso produtos da sua própria filial.');
    }

    const client = getSupabaseClient();
    if (client) {
      const { data, error } = await client
        .from('produtos_filiais_inativos')
        .insert([{
          produto_id: parseInt(produtoId),
          filial_id: parseInt(targetFilial),
          desativado_por: usuario ? usuario.id : null
        }])
        .select()
        .single();

      if (error && error.code !== '23505') {
        throw new Error(error.message || 'Erro ao inativar produto na filial.');
      }

      notificarRealtime('produtos_filiais_inativos', { produto_id: produtoId, filial_id: targetFilial });
      return data || { success: true };
    }
    return apiRequest(`/produtos/${produtoId}/inativar-local`, { method: 'POST', body: JSON.stringify({ filialId: targetFilial }) });
  },

  listarInativosLocais: async () => {
    const client = getSupabaseClient();
    if (client) {
      const { data, error } = await client.from('produtos_filiais_inativos').select('*');
      if (!error && data) return data;
    }
    return apiRequest('/produtos/inativos-locais');
  },

  criarProduto: async (dados) => {
    if (!dados.nome || !dados.sku) {
      throw new Error('Preencha Nome e SKU do produto.');
    }
    if (!Number.isInteger(dados.qtd_minima) || dados.qtd_minima < 0) {
      throw new Error('A quantidade mínima deve ser um inteiro válido maior ou igual a zero.');
    }

    const client = getSupabaseClient();
    if (client) {
      const skuBase = dados.sku || obterSkuPorNome(dados.nome);
      let codigoFinal = skuBase;

      const { data: prodsExistentes, error: pExistErr } = await client.from('produtos').select('codigo');
      if (pExistErr) {
        throw new Error(pExistErr.message || 'Erro ao verificar códigos de produto existentes.');
      }

      if (prodsExistentes && prodsExistentes.length > 0) {
        const codigosEmUso = new Set(prodsExistentes.map(p => p.codigo));
        if (codigosEmUso.has(skuBase)) {
          let contador = 1;
          while (codigosEmUso.has(`${skuBase}-${contador}`)) {
            contador++;
          }
          codigoFinal = `${skuBase}-${contador}`;
        }
      }

      const payloadProduto = {
        nome: dados.nome,
        codigo: codigoFinal,
        descricao: dados.categoria || 'Geral',
        qtd_minima: dados.qtd_minima ?? 10,
        unidade_medida: 'unidade',
        ativo: true
      };

      const { data: pData, error: pErr } = await client.from('produtos').insert([payloadProduto]).select().single();
      if (pErr) {
        if (pErr.code === '23505' || pErr.status === 409) {
          throw new Error('Não foi possível cadastrar o produto porque o código informado já está em uso. Tente novamente com um código exclusivo.');
        }
        throw new Error(pErr.message || 'Erro ao cadastrar produto no Supabase.');
      }

      if (pData) {
        const prodId = pData.id;
        const targetFilialId = parseInt(dados.filialId);
        const initialQtd = 0;
        const st = 'zerado';

        const estoqueRecord = {
          produto_id: prodId,
          filial_id: targetFilialId,
          quantidade: initialQtd,
          status: st
        };
        const { error: estErr } = await client.from('estoques').insert([estoqueRecord]);
        if (estErr) {
          console.warn('Não foi possível inserir estoque inicial para o novo produto:', estErr.message);
        }

        notificarRealtime('produtos', { id: prodId });
        notificarRealtime('estoques', { produto_id: prodId, filial_id: targetFilialId });
        return {
          id: prodId,
          sku: codigoFinal,
          nome: dados.nome,
          categoria: dados.categoria || 'Geral',
          qtd_minima: dados.qtd_minima ?? 10,
          filial_id: targetFilialId
        };
      }
    }
    return apiRequest('/produtos', { method: 'POST', body: JSON.stringify(dados) });
  },

  listarEstoque: async (filialId) => {
    if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
      filialId = usuario.filial_id;
    }
    const client = getSupabaseClient();
    if (client) {
      let query = client.from('estoques').select('*');
      if (filialId !== null && filialId !== undefined && filialId !== '') {
        query = query.eq('filial_id', parseInt(filialId));
      }
      const { data, error } = await query;
      if (!error && data) return data;
    }
    return apiRequest(`/estoque${filialId ? `?filialId=${filialId}` : ''}`);
  },

  ajustarEstoque: async (dados) => {
    if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id && dados.filialId != usuario.filial_id) {
      throw new Error('Acesso negado: Funcionário só pode alterar o estoque da sua própria filial.');
    }
    if (!Number.isInteger(dados.quantidade) || dados.quantidade <= 0) {
      throw new Error('A quantidade de ajuste deve ser um número inteiro maior que zero.');
    }

    const client = getSupabaseClient();
    if (client) {
      const { data, error } = await client.rpc('ajustar_estoque_rpc', {
        p_produto_id: parseInt(dados.produtoId),
        p_filial_id: parseInt(dados.filialId),
        p_tipo: dados.tipo,
        p_quantidade: parseInt(dados.quantidade),
        p_motivo: dados.motivo || 'Ajuste manual'
      });

      if (error) {
        throw new Error(error.message || 'Erro ao executar ajuste de estoque.');
      }

      if (data && data.success === false) {
        throw new Error(data.message || 'Não foi possível realizar o ajuste de estoque.');
      }

      notificarRealtime('estoques', { produto_id: dados.produtoId, filial_id: dados.filialId });
      notificarRealtime('movimentacoes', { produto_id: dados.produtoId, filial_id: dados.filialId });
      return data || { success: true };
    }
    return apiRequest('/estoque/ajustar', { method: 'POST', body: JSON.stringify(dados) });
  },

  listarTransferencias: async () => {
    const client = getSupabaseClient();
    if (client) {
      let query = client.from('transferencias').select('*').order('id', { ascending: false });
      const { data, error } = await query;
      if (!error && data) {
        const { data: prods } = await client.from('produtos').select('id, nome');
        const { data: fils } = await client.from('filiais').select('id, nome');
        let usrs = null;
        const { data: usrsData, error: uErr } = await client.from('usuarios').select('id, nome');
        if (!uErr && usrsData) usrs = usrsData;

        let listT = data;
        if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
          listT = listT.filter(t => (t.origem_id == usuario.filial_id || t.origem_filial_id == usuario.filial_id || t.destino_id == usuario.filial_id || t.destino_filial_id == usuario.filial_id));
        }
        return listT.map(t => ({
          id: t.id,
          produto_id: t.produto_id,
          produtoNome: prods?.find(p => p.id === t.produto_id)?.nome || 'Produto',
          origem_id: t.origem_id || t.origem_filial_id,
          origemNome: fils?.find(f => f.id === (t.origem_id || t.origem_filial_id))?.nome || 'Filial Origem',
          destino_id: t.destino_id || t.destino_filial_id,
          destinoNome: fils?.find(f => f.id === (t.destino_id || t.destino_filial_id))?.nome || 'Filial Destino',
          quantidade: t.quantidade,
          solicitante: t.solicitante || usrs?.find(u => u.id === t.usuario_id)?.nome || (usuario ? usuario.nome : 'Solicitante'),
          data: t.created_at ? new Date(t.created_at).toLocaleDateString('pt-BR') : new Date().toLocaleDateString('pt-BR'),
          status: t.status || 'solicitada'
        }));
      }
    }
    return apiRequest('/transferencias');
  },

  criarTransferencia: async (dados) => {
    if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id && dados.origemId != usuario.filial_id) {
      throw new Error('Acesso negado: Funcionário só pode solicitar transferência tendo sua filial como origem.');
    }
    if (!Number.isInteger(dados.quantidade) || dados.quantidade <= 0) {
      throw new Error('Informe uma quantidade inteira válida maior que zero para a transferência.');
    }
    if (dados.origemId === dados.destinoId) {
      throw new Error('Filial de Origem e Destino devem ser diferentes.');
    }

    const client = getSupabaseClient();
    if (client) {
      const { data: origEst, error: origErr } = await client
        .from('estoques')
        .select('*')
        .eq('produto_id', dados.produtoId)
        .eq('filial_id', dados.origemId)
        .maybeSingle();

      if (origErr) {
        throw new Error(origErr.message || 'Erro ao verificar estoque da filial de origem.');
      }

      const estoqueDisponivel = origEst ? origEst.quantidade : 0;
      if (estoqueDisponivel < dados.quantidade) {
        throw new Error(`Estoque insuficiente na filial de origem (disponível: ${estoqueDisponivel}, solicitado: ${dados.quantidade}).`);
      }

      const payload = {
        produto_id: dados.produtoId,
        origem_id: dados.origemId,
        destino_id: dados.destinoId,
        quantidade: dados.quantidade,
        usuario_id: usuario ? usuario.id : null,
        status: 'pendente',
        created_at: new Date().toISOString()
      };
      const { data, error } = await client.from('transferencias').insert([payload]).select().single();
      if (!error && data) {
        notificarRealtime('transferencias', { id: data.id });
        return {
          id: data.id,
          produto_id: data.produto_id,
          origem_id: data.origem_id,
          destino_id: data.destino_id,
          quantidade: data.quantidade,
          solicitante: usuario ? usuario.nome : 'Solicitante',
          data: new Date().toLocaleDateString('pt-BR'),
          status: 'pendente'
        };
      } else if (error) {
        throw new Error(error.message || 'Erro ao criar transferência no Supabase.');
      }
    }
    return apiRequest('/transferencias', { method: 'POST', body: JSON.stringify(dados) });
  },

  concluirTransferencia: async (id) => {
    const client = getSupabaseClient();
    if (client) {
      const { data, error } = await client.rpc('concluir_transferencia_rpc', { p_transferencia_id: id });
      if (error) {
        throw new Error(error.message || 'Erro ao concluir transferência.');
      }
      if (!data || data.success !== true) {
        const msg = (data && data.message) ? data.message : 'A operação de transferência não pôde ser concluída pelo banco de dados.';
        throw new Error(msg);
      }
      notificarRealtime('transferencias', { id });
      return data;
    }
    return apiRequest(`/transferencias/${id}/concluir`, { method: 'PATCH' });
  },

  listarPedidos: async () => {
    const client = getSupabaseClient();
    if (client) {
      const { data: pedidosData, error: pErr } = await client.from('pedidos_compra').select('*').order('id', { ascending: false });
      if (!pErr && pedidosData) {
        const { data: itensData } = await client.from('itens_pedido_compra').select('*');
        const { data: prods } = await client.from('produtos').select('id, nome');
        const { data: fils } = await client.from('filiais').select('id, nome');
        let usrs = null;
        const { data: usrsData, error: uErr } = await client.from('usuarios').select('id, nome');
        if (!uErr && usrsData) usrs = usrsData;

        return pedidosData.map(p => {
          const itensDoPedido = itensData ? itensData.filter(i => String(i.pedido_id) === String(p.id)) : [];
          const primeiroItem = itensDoPedido.length > 0 ? itensDoPedido[0] : null;

          const pid = primeiroItem ? primeiroItem.produto_id : (p.produto_id ?? p.produtoId);
          const fid = p.filial_id ?? p.filialId;
          const qtd = primeiroItem ? primeiroItem.quantidade : (p.quantidade ?? p.qtd ?? 0);

          const prdEncontrado = prods?.find(prd => String(prd.id) === String(pid));
          const filEncontrada = fils?.find(f => String(f.id) === String(fid));
          const usrEncontrado = usrs?.find(u => String(u.id) === String(p.usuario_id));

          return {
            id: p.id,
            produto_id: pid,
            produtoNome: prdEncontrado ? prdEncontrado.nome : (nomeProduto(pid) !== '—' ? nomeProduto(pid) : `Produto #${pid || 'N/A'}`),
            quantidade: qtd,
            filial_id: fid,
            filialNome: filEncontrada ? filEncontrada.nome : (nomeFilial(fid) !== '—' ? nomeFilial(fid) : `Filial #${fid || 'N/A'}`),
            solicitante: usrEncontrado ? usrEncontrado.nome : (p.solicitante || p.usuario || 'Gerente'),
            data: p.created_at ? new Date(p.created_at).toLocaleDateString('pt-BR') : (p.data || new Date().toLocaleDateString('pt-BR')),
            status: p.status || 'aberto',
            itens: itensDoPedido
          };
        });
      }
    }
    return apiRequest('/pedidos');
  },

  criarPedido: async (dados) => {
    if (usuario && usuario.tipo !== 'gerente') {
      throw new Error('Apenas gerentes possuem permissão para criar pedidos.');
    }
    if (!dados.produtoId || !dados.filialId || !Number.isInteger(dados.quantidade) || dados.quantidade <= 0) {
      throw new Error('Informe um produto, filial e uma quantidade inteira maior que zero.');
    }

    const client = getSupabaseClient();
    if (client) {
      const payloadPedido = {
        filial_id: dados.filialId,
        usuario_id: usuario ? usuario.id : null,
        status: 'aberto',
        created_at: new Date().toISOString()
      };

      const { data: pedido, error: pErr } = await client
        .from('pedidos_compra')
        .insert([payloadPedido])
        .select()
        .single();

      if (pErr || !pedido) {
        throw new Error(pErr?.message || 'Erro ao criar registro do pedido de compra.');
      }

      const payloadItem = {
        pedido_id: pedido.id,
        produto_id: dados.produtoId,
        quantidade: dados.quantidade
      };

      const { data: item, error: iErr } = await client
        .from('itens_pedido_compra')
        .insert([payloadItem])
        .select()
        .single();

      if (iErr) {
        await client.from('pedidos_compra').delete().eq('id', pedido.id);
        throw new Error(iErr.message || 'Erro ao gravar os itens do pedido de compra.');
      }

      notificarRealtime('pedidos_compra', { id: pedido.id });
      return {
        id: pedido.id,
        produto_id: dados.produtoId,
        produtoNome: nomeProduto(dados.produtoId),
        quantidade: dados.quantidade,
        filial_id: dados.filialId,
        filialNome: nomeFilial(dados.filialId),
        solicitante: usuario ? usuario.nome : 'Gerente',
        data: new Date().toLocaleDateString('pt-BR'),
        status: 'aberto'
      };
    }
    return apiRequest('/pedidos', { method: 'POST', body: JSON.stringify(dados) });
  },

  receberPedido: async (id) => {
    const client = getSupabaseClient();
    if (client) {
      const { data, error } = await client.rpc('receber_pedido_rpc', { p_pedido_id: id });
      if (error) {
        throw new Error(error.message || 'Erro ao receber pedido de compra.');
      }
      if (!data || data.success !== true) {
        const msg = (data && data.message) ? data.message : 'A operação de recebimento de pedido não pôde ser concluída pelo banco de dados.';
        throw new Error(msg);
      }
      notificarRealtime('pedidos_compra', { id });
      return data;
    }
    return apiRequest(`/pedidos/${id}/receber`, { method: 'POST' });
  },

  listarAlertas: async () => {
    const client = getSupabaseClient();
    if (client) {
      let { data: listE } = await client.from('estoques').select('*');
      const { data: listP } = await client.from('produtos').select('*');
      const { data: listF } = await client.from('filiais').select('*');

      if (listE && usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
        listE = listE.filter(e => e.filial_id == usuario.filial_id);
      }

      if (listE && listP && listF) {
        const alertas = listE.filter(e => e.status === 'baixo' || e.status === 'zerado').map(e => {
          const p = listP.find(prd => prd.id === e.produto_id) || {};
          const f = listF.find(fil => fil.id === e.filial_id) || {};
          return {
            ...e,
            sku: p.sku || p.codigo || `JOIA-00${p.id}`,
            produtoNome: p.nome,
            filialNome: f.nome,
            quantidadeMinima: p.qtd_minima || 0
          };
        });
        return {
          totalBaixo: alertas.filter(a => a.status === 'baixo').length,
          totalZerado: alertas.filter(a => a.status === 'zerado').length,
          itens: alertas
        };
      }
    }
    return apiRequest('/estoque/alertas');
  },

  listarHistorico: async (filtros = {}) => {
    if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
      filtros.filialId = usuario.filial_id;
    }
    const client = getSupabaseClient();
    if (client) {
      let query = client.from('movimentacoes').select('*').order('id', { ascending: false });
      if (filtros.tipo) query = query.eq('tipo', filtros.tipo);
      if (filtros.filialId) query = query.eq('filial_id', filtros.filialId);

      const { data, error } = await query;
      if (!error && data) {
        const { data: prods } = await client.from('produtos').select('id, nome');
        const { data: fils } = await client.from('filiais').select('id, nome');
        let usrs = null;
        const { data: usrsData, error: uErr } = await client.from('usuarios').select('id, nome');
        if (!uErr && usrsData) usrs = usrsData;

        return data.map(m => {
          const usrEncontrado = usrs?.find(u => String(u.id) === String(m.usuario_id));
          const prdEncontrado = prods?.find(p => String(p.id) === String(m.produto_id));
          const filEncontrada = fils?.find(f => String(f.id) === String(m.filial_id));

          return {
            id: m.id,
            data: m.created_at ? new Date(m.created_at).toLocaleString('pt-BR') : (m.data || new Date().toLocaleString('pt-BR')),
            produto_id: m.produto_id,
            produtoNome: prdEncontrado ? prdEncontrado.nome : (nomeProduto(m.produto_id) !== '—' ? nomeProduto(m.produto_id) : `Produto #${m.produto_id || 'N/A'}`),
            filial_id: m.filial_id,
            filialNome: filEncontrada ? filEncontrada.nome : (nomeFilial(m.filial_id) !== '—' ? nomeFilial(m.filial_id) : `Filial #${m.filial_id || 'N/A'}`),
            tipo: m.tipo,
            anterior: m.quantidade_anterior ?? m.anterior ?? 0,
            nova: m.quantidade_nova ?? m.nova ?? m.quantidade ?? 0,
            usuario: usrEncontrado ? usrEncontrado.nome : (m.usuario || m.usuario_nome || 'Sistema'),
            motivo: m.motivo || 'Movimentação'
          };
        });
      }
    }
    const qs = new URLSearchParams(filtros).toString();
    return apiRequest(`/historico${qs ? `?${qs}` : ''}`);
  },

  resumoDashboard: async (filialId) => {
    if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
      filialId = usuario.filial_id;
    }
    const client = getSupabaseClient();
    if (client) {
      let queryE = client.from('estoques').select('*');
      if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
        queryE = queryE.eq('filial_id', usuario.filial_id);
      } else if (filialId) {
        queryE = queryE.eq('filial_id', filialId);
      }
      const { data: listE } = await queryE;
      const { data: listP } = await client.from('produtos').select('*');
      const { data: listF } = await client.from('filiais').select('*');

      let queryT = client.from('transferencias').select('*');
      if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
        queryT = queryT.or(`origem_id.eq.${usuario.filial_id},destino_id.eq.${usuario.filial_id}`);
      }
      const { data: listT } = await queryT;

      if (listE && listP && listF) {
        const targetFilial = filialId || (usuario && usuario.tipo === 'funcionario' ? usuario.filial_id : null);
        const filteredE = targetFilial ? listE.filter(e => e.filial_id == targetFilial) : listE;
        const totalItens = filteredE.reduce((sum, e) => sum + e.quantidade, 0);
        const totalBaixo = filteredE.filter(e => e.status === 'baixo').length;
        const totalZerado = filteredE.filter(e => e.status === 'zerado').length;

        const visFiliais = (usuario && usuario.tipo === 'funcionario' && usuario.filial_id)
          ? listF.filter(f => String(f.id) === String(usuario.filial_id))
          : listF;

        const estoquePorFilial = visFiliais.map(f => ({
          nome: f.nome,
          total: listE.filter(e => String(e.filial_id) === String(f.id)).reduce((s, e) => s + (e.quantidade || 0), 0)
        }));

        const alertas = filteredE.filter(e => e.status === 'baixo' || e.status === 'zerado').map(e => ({
          ...e,
          produtoNome: listP.find(p => String(p.id) === String(e.produto_id))?.nome || `Produto #${e.produto_id}`,
          filialNome: listF.find(f => String(f.id) === String(e.filial_id))?.nome || `Filial #${e.filial_id}`,
          quantidadeMinima: listP.find(p => String(p.id) === String(e.produto_id))?.qtd_minima || 0
        }));

        const filteredT = (usuario && usuario.tipo === 'funcionario' && usuario.filial_id)
          ? (listT ? listT.filter(t => (String(t.origem_id) === String(usuario.filial_id) || String(t.destino_id) === String(usuario.filial_id)) && (t.status === 'solicitada' || t.status === 'pendente')) : [])
          : (listT ? listT.filter(t => t.status === 'solicitada' || t.status === 'pendente') : []);

        const diasSemana = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
        const hoje = new Date();
        const labelsSemana = [];
        const entradasSemana = [0, 0, 0, 0, 0, 0, 0];
        const saidasSemana = [0, 0, 0, 0, 0, 0, 0];

        const diasDatas = [];
        for (let i = 6; i >= 0; i--) {
          const d = new Date(hoje);
          d.setDate(hoje.getDate() - i);
          labelsSemana.push(diasSemana[d.getDay()]);
          diasDatas.push(d.toISOString().split('T')[0]);
        }

        let queryMov = client.from('movimentacoes').select('*');
        if (targetFilial) {
          queryMov = queryMov.eq('filial_id', targetFilial);
        }
        const { data: listM } = await queryMov;

        if (listM && listM.length > 0) {
          listM.forEach(m => {
            if (!m.created_at) return;
            const dataStr = new Date(m.created_at).toISOString().split('T')[0];
            const idx = diasDatas.indexOf(dataStr);
            if (idx !== -1) {
              const qtd = m.quantidade ?? m.quantidade_nova ?? 0;
              if (m.tipo === 'entrada') {
                entradasSemana[idx] += qtd;
              } else if (m.tipo === 'saida') {
                saidasSemana[idx] += qtd;
              }
            }
          });
        }

        return {
          estoques: filteredE,
          produtos: listP,
          totalItens,
          totalProdutos: listP.length,
          totalBaixo,
          totalZerado,
          totalTransferenciasPendentes: filteredT.length,
          estoquePorFilial,
          movimentacoesSemana: {
            labels: labelsSemana,
            entradas: entradasSemana,
            saidas: saidasSemana
          },
          alertas
        };
      }
    }
    return apiRequest(`/dashboard${filialId ? `?filialId=${filialId}` : ''}`);
  },
};

// ---------- ESTADO LOCAL ----------
let usuario = null;
let FILIAIS = [];
let produtos = [];
let estoques = [];
let inativosLocais = [];
let movimentacoes = [];
let transferencias = [];
let pedidos = [];

let chartFilial = null, chartMov = null;
let filialDashSel = null, filialEstoqueSel = null;
let ajusteTarget = null;
let realtimeChannel = null;

// ---------- REALTIME SUBSCRIPTIONS (SUPABASE REALTIME) ----------
function notificarRealtime(tabela, dados = {}) {
  if (realtimeChannel) {
    try {
      realtimeChannel.send({
        type: 'broadcast',
        event: 'sge_data_change',
        payload: { tabela, ...dados }
      });
    } catch (_) {}
  }
}

function iniciarRealtimeSubscriptions() {
  const client = getSupabaseClient();
  if (!client || typeof client.channel !== 'function') return;

  if (realtimeChannel) {
    try { client.removeChannel(realtimeChannel); } catch (_) {}
    realtimeChannel = null;
  }

  try {
    realtimeChannel = client.channel('sge_realtime_channel')
      .on('broadcast', { event: 'sge_data_change' }, (p) => {
        if (p && p.payload && p.payload.tabela) {
          atualizarTelasRealtime(p.payload.tabela, p.payload);
        }
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'estoques' }, (p) => atualizarTelasRealtime('estoques', p))
      .on('postgres_changes', { event: '*', schema: 'public', table: 'movimentacoes' }, (p) => atualizarTelasRealtime('movimentacoes', p))
      .on('postgres_changes', { event: '*', schema: 'public', table: 'transferencias' }, (p) => atualizarTelasRealtime('transferencias', p))
      .on('postgres_changes', { event: '*', schema: 'public', table: 'pedidos_compra' }, (p) => atualizarTelasRealtime('pedidos_compra', p))
      .subscribe();
  } catch (err) {
    console.warn('Supabase Realtime indisponível temporariamente:', err);
  }
}

function encerrarRealtimeSubscriptions() {
  const client = getSupabaseClient();
  if (client && realtimeChannel) {
    try { client.removeChannel(realtimeChannel); } catch (_) {}
    realtimeChannel = null;
  }
}

function atualizarTelasRealtime(tabela, payload) {
  const activePage = document.querySelector('.page.active')?.id;

  if (activePage === 'page-dashboard') {
    renderDashboard();
  } else if (activePage === 'page-estoque' && tabela === 'estoques') {
    renderEstoque();
  } else if (activePage === 'page-produtos' && tabela === 'estoques') {
    renderProdutos();
  } else if (activePage === 'page-transferencias' && tabela === 'transferencias') {
    renderTransferencias();
  } else if (activePage === 'page-pedidos' && tabela === 'pedidos_compra') {
    renderPedidos();
  } else if (activePage === 'page-alertas' && (tabela === 'estoques' || tabela === 'produtos')) {
    renderAlertas();
  } else if (activePage === 'page-historico' && tabela === 'movimentacoes') {
    renderHistorico();
  }
}

const ICON_SUN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>';
const ICON_MOON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5Z"/></svg>';

// ---------- TEMA ----------
function initTheme() {
  const savedTheme = localStorage.getItem('theme') || 'light';
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeUI(savedTheme);
}

function toggleTheme() {
  const currentTheme = document.documentElement.getAttribute('data-theme');
  const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', newTheme);
  localStorage.setItem('theme', newTheme);
  updateThemeUI(newTheme);
  if (document.getElementById('page-dashboard')?.classList.contains('active')) renderDashboard();
}

function updateThemeUI(theme) {
  const icon = document.getElementById('theme-icon');
  const text = document.getElementById('theme-text');
  const loginLogo = document.getElementById('login-logo');
  const appLogo = document.getElementById('app-logo');
  const logoSrc = theme === 'dark' ? 'img/LumeEscuro.png' : 'img/Lume.png';

  if (loginLogo) loginLogo.src = logoSrc;
  if (appLogo) appLogo.src = logoSrc;

  if (theme === 'dark') { if (icon) icon.innerHTML = ICON_SUN; if (text) text.textContent = 'Modo Claro'; }
  else { if (icon) icon.innerHTML = ICON_MOON; if (text) text.textContent = 'Modo Escuro'; }
}
initTheme();

// ---------- HELPERS ----------
const $ = id => document.getElementById(id);
const nomeFilial = id => FILIAIS.find(f=>f.id===id)?.nome || '—';
const nomeProduto = id => produtos.find(p=>p.id===id)?.nome || '—';
const skuProduto = id => produtos.find(p=>p.id===id)?.sku || '—';
const minProduto = id => produtos.find(p=>p.id===id)?.qtd_minima || 0;

function statusEstoque(qtd){
  if(qtd === 0 || qtd <= 0) return 'zerado';
  return 'suficiente';
}
const STATUS_LABEL = {suficiente:'Disponível', zerado:'Zerado'};

function toast(msg, erro=false){
  const t = $('toast');
  if(!t) return;
  t.textContent = msg;
  t.className = 'toast show' + (erro ? ' error' : '');
  setTimeout(()=> t.classList.remove('show'), 3200);
}

function getEstoque(pid, fid){
  return estoques.find(e=>e.produto_id===pid && e.filial_id===fid);
}

function filiaisVisiveis(){
  return usuario.tipo === 'gerente' ? FILIAIS : FILIAIS.filter(f=>f.id===usuario.filial_id);
}

function mostrarLoading(el){
  if(el) el.innerHTML = '<tr><td colspan="10" class="empty-state">Carregando...</td></tr>';
}

// ---------- LOGIN ----------
async function fazerLogin(){
  const loginBtn = document.querySelector('#login-screen button');
  if (loginBtn && loginBtn.disabled) return;
  const originalText = loginBtn ? loginBtn.textContent : 'Entrar';

  const emailInput = $('login-email');
  const senhaInput = $('login-senha');
  const email = emailInput ? emailInput.value.trim() : '';
  const senha = senhaInput ? senhaInput.value : '';

  if(!email || !senha){ toast('E-mail e senha são obrigatórios.', true); return; }

  if (loginBtn) { loginBtn.disabled = true; loginBtn.textContent = 'Entrando...'; }

  try {
    const client = getSupabaseClient();
    if (!client || !client.auth) {
      throw new Error('Erro de comunicação com o Supabase.');
    }

    const { data: authData, error: authErr } = await client.auth.signInWithPassword({
      email: email,
      password: senha
    });

    if (authErr || !authData || !authData.user) {
      throw new Error('Acesso negado. E-mail ou senha incorretos.');
    }

    let uData = null;
    let uErr = null;

    const resAuth = await client
      .from('usuarios')
      .select('id, nome, email, cargo, tipo, filial_id, ativo, auth_user_id')
      .eq('auth_user_id', authData.user.id)
      .maybeSingle();

    if (!resAuth.error && resAuth.data) {
      uData = resAuth.data;
    } else {
      const resEmail = await client
        .from('usuarios')
        .select('id, nome, email, cargo, tipo, filial_id, ativo, auth_user_id')
        .ilike('email', email)
        .maybeSingle();
      uData = resEmail.data;
      uErr = resEmail.error;
    }

    if (uErr || !uData) {
      await client.auth.signOut();
      throw new Error('Acesso negado. Perfil de funcionário não localizado.');
    }

    if (uData.ativo === false) {
      await client.auth.signOut();
      throw new Error('Acesso negado. Usuário desativado.');
    }

    const cargo = (uData.cargo || uData.tipo || 'funcionario').toLowerCase();
    const resposta = {
      id: uData.id,
      nome: uData.nome || email.split('@')[0],
      email: uData.email,
      cargo: cargo,
      tipo: cargo,
      filial_id: uData.filial_id ?? (cargo === 'gerente' ? null : 1),
      access_token: authData.session?.access_token
    };

    aplicarLogin(resposta);
  } catch (err) {
    toast(err.message || 'Acesso negado. Credenciais inválidas.', true);
  } finally {
    if (loginBtn) { loginBtn.disabled = false; loginBtn.textContent = originalText; }
  }
}

function simularLogin(tipo){
  const nome = (tipo === 'gerente' ? 'Gerente' : 'Funcionário');
  aplicarLogin(tipo === 'gerente'
    ? {nome, tipo:'gerente', cargo:'gerente', filial_id:3}
    : {nome, tipo:'funcionario', cargo:'funcionario', filial_id:1});
}

async function aplicarLogin(dadosUsuario){
  usuario = dadosUsuario;
  if (!usuario.tipo && usuario.cargo) {
    usuario.tipo = usuario.cargo;
  }
  if (usuario.filialId !== undefined && usuario.filial_id === undefined) {
    usuario.filial_id = usuario.filialId;
  }

  localStorage.setItem('lume_usuario', JSON.stringify(usuario));

  const loginScreen = $('login-screen');
  if (loginScreen) loginScreen.style.display = 'none';

  const appScreen = $('app');
  if (appScreen) appScreen.classList.add('active');

  const uNome = $('user-nome');
  if (uNome) uNome.textContent = usuario.nome || '';

  const uTipo = $('user-tipo');
  if (uTipo) uTipo.textContent = usuario.tipo === 'gerente' ? 'Gerente' : 'Funcionário';

  const uInit = $('user-initial');
  if (uInit) uInit.textContent = usuario.nome ? usuario.nome[0].toUpperCase() : (usuario.tipo === 'gerente' ? 'G' : 'F');

  const btnPedido = $('btn-novo-pedido');
  if (btnPedido) {
    btnPedido.disabled = usuario.tipo !== 'gerente';
    btnPedido.title = usuario.tipo !== 'gerente' ? 'Apenas gerentes criam pedidos de compra' : '';
  }

  const pedDesc = $('pedidos-desc');
  if (pedDesc) {
    pedDesc.textContent = usuario.tipo !== 'gerente'
      ? 'Somente gerentes podem criar pedidos (você está em modo de visualização)'
      : 'Criados manualmente pelo gerente para reposição';
  }

  await carregarFiliais();

  const dashDesc = $('dash-desc');
  if (dashDesc) {
    dashDesc.textContent = usuario.tipo === 'gerente'
      ? `Bem-vindo(a), ${usuario.nome}! Visão geral das 5 filiais.`
      : `Bem-vindo(a), ${usuario.nome}! Visão da sua filial: ${nomeFilial(usuario.filial_id)}.`;
  }

  montarFiltros();
  iniciarRealtimeSubscriptions();
  irPara('dashboard');
}

async function sair(){
  encerrarRealtimeSubscriptions();
  const client = getSupabaseClient();
  if (client && client.auth) {
    try { await client.auth.signOut(); } catch (_) {}
  }
  usuario = null;
  localStorage.removeItem('lume_usuario');
  const appScreen = $('app');
  if (appScreen) appScreen.classList.remove('active');

  const loginScreen = $('login-screen');
  if (loginScreen) loginScreen.style.display = 'flex';
}

async function verificarSessaoAtiva(){
  const client = getSupabaseClient();
  if (client && client.auth) {
    try {
      const { data, error } = await client.auth.getSession();
      if (!error && data && data.session && data.session.user) {
        const authUser = data.session.user;
        let uData = null;
        let uErr = null;

        const resAuth = await client
          .from('usuarios')
          .select('id, nome, email, cargo, tipo, filial_id, ativo, auth_user_id')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();

        if (!resAuth.error && resAuth.data) {
          uData = resAuth.data;
        } else {
          const resEmail = await client
            .from('usuarios')
            .select('id, nome, email, cargo, tipo, filial_id, ativo, auth_user_id')
            .ilike('email', authUser.email)
            .maybeSingle();
          uData = resEmail.data;
          uErr = resEmail.error;
        }

        if (!uErr && uData && uData.ativo !== false) {
          const cargo = (uData.cargo || uData.tipo || 'funcionario').toLowerCase();
          aplicarLogin({
            id: uData.id,
            nome: uData.nome,
            email: uData.email,
            cargo: cargo,
            tipo: cargo,
            filial_id: uData.filial_id ?? (cargo === 'gerente' ? null : 1),
            access_token: data.session.access_token
          });
          return;
        }
      }
    } catch (_) {}
  }

  const salvalog = localStorage.getItem('lume_usuario');
  if (salvalog) {
    try {
      const u = JSON.parse(salvalog);
      if (u && u.nome && u.cargo) {
        aplicarLogin(u);
      }
    } catch (_) {
      localStorage.removeItem('lume_usuario');
    }
  }
}

if (typeof window !== 'undefined') {
  document.addEventListener('DOMContentLoaded', verificarSessaoAtiva);
}

// ---------- CARREGAMENTO DE DADOS BASE ----------
async function carregarFiliais(){
  try {
    FILIAIS = await api.listarFiliais();
  } catch (err) {
    FILIAIS = [
      {id:1, nome:'Filial Centro'}, {id:2, nome:'Filial Norte'}, {id:3, nome:'Filial Sul'},
      {id:4, nome:'Filial Leste'}, {id:5, nome:'Filial Oeste'}
    ];
  }
}

// ---------- NAVEGAÇÃO ----------
document.querySelectorAll('#menu a').forEach(a=>{
  a.addEventListener('click', ()=> irPara(a.dataset.page));
});

function irPara(page){
  document.querySelectorAll('#menu a').forEach(a=>a.classList.toggle('active', a.dataset.page===page));
  document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));
  const targetPage = $('page-'+page);
  if(targetPage) targetPage.classList.add('active');
  if(page==='dashboard') renderDashboard();
  if(page==='produtos') renderProdutos();
  if(page==='estoque') renderEstoque();
  if(page==='transferencias') renderTransferencias();
  if(page==='pedidos') renderPedidos();
  if(page==='alertas') renderAlertas();
  if(page==='historico') renderHistorico();
}

// ---------- FILTROS DE FILIAL ----------
function montarFiltros(){
  const vis = filiaisVisiveis();
  const dashHtml = vis.map(f=>`<button onclick="setFilialDash(${f.id},this)">${escapeHtml(f.nome.replace('Filial ',''))}</button>`).join('');
  const dashF = $('dash-filiais');
  if (dashF) dashF.innerHTML = `<button class="on" onclick="setFilialDash(null,this)">${usuario.tipo==='gerente'?'Todas':'Minha filial'}</button>` + dashHtml;

  const estHtml = vis.map(f=>`<button onclick="setFilialEstoque(${f.id},this)">${escapeHtml(f.nome.replace('Filial ',''))}</button>`).join('');
  const estF = $('estoque-filiais');
  if (estF) estF.innerHTML = `<button class="on" onclick="setFilialEstoque(null,this)">${usuario.tipo==='gerente'?'Todas':'Minha filial'}</button>` + estHtml;

  const histF = $('hist-filial');
  if (histF) {
    const showAllOpt = usuario && usuario.tipo === 'gerente';
    histF.innerHTML = (showAllOpt ? '<option value="">Todas as filiais</option>' : '') +
      vis.map(f=>`<option value="${f.id}">${escapeHtml(f.nome)}</option>`).join('');
  }
}

function setFilialDash(id, btn){
  filialDashSel = id;
  const dashF = $('dash-filiais');
  if (dashF) dashF.querySelectorAll('button').forEach(b=>b.classList.remove('on'));
  if (btn) btn.classList.add('on');
  renderDashboard();
}

function setFilialEstoque(id, btn){
  filialEstoqueSel = id;
  const estF = $('estoque-filiais');
  if (estF) estF.querySelectorAll('button').forEach(b=>b.classList.remove('on'));
  if (btn) btn.classList.add('on');
  renderEstoque();
}

// ---------- DASHBOARD ----------
async function renderDashboard(){
  try {
    const dados = await api.resumoDashboard(filialDashSel);
    estoques = dados.estoques || [];
    produtos = dados.produtos || produtos;
    transferencias = dados.transferenciasPendentes || transferencias;
    pintarKpis(dados);
    pintarGraficos(dados);
    pintarAlertasDashboard(dados.alertas || []);
  } catch (err) {
    toast('Não foi possível carregar o dashboard.', true);
  }
}

function pintarKpis(dados){
  const fid = filialDashSel || (usuario && usuario.tipo === 'funcionario' ? usuario.filial_id : null);
  const kpis = $('dash-kpis');
  if (kpis) {
    kpis.innerHTML = `
      <div class="card kpi"><span class="label">Itens em estoque</span><span class="value">${dados.totalItens ?? 0}</span><span class="badge info">${fid?escapeHtml(nomeFilial(fid)):'5 filiais'}</span></div>
      <div class="card kpi"><span class="label">Produtos cadastrados</span><span class="value">${dados.totalProdutos ?? produtos.length}</span><span class="badge ok">ativos</span></div>
      <div class="card kpi"><span class="label">Estoque baixo</span><span class="value" style="color:var(--warn-color)">${dados.totalBaixo ?? 0}</span><span class="badge warn">atenção</span></div>
      <div class="card kpi"><span class="label">Estoque zerado</span><span class="value" style="color:var(--danger-color)">${dados.totalZerado ?? 0}</span><span class="badge danger">urgente</span></div>
      <div class="card kpi"><span class="label">Transferências pendentes</span><span class="value" style="color:var(--rose-primary)">${dados.totalTransferenciasPendentes ?? 0}</span><span class="badge info">aguardando</span></div>`;
  }
}

function pintarGraficos(dados){
  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  const textColor = isDark ? '#97979d' : '#6b6b6f';
  const gridColor = isDark ? '#2c2c3355' : '#e4e4e7';
  const roseColor = isDark ? '#c65b7e' : '#9d3b5c';

  const porFilial = dados.estoquePorFilial || [];
  const canvasFilial = $('chart-estoque-filial');
  if(canvasFilial && typeof Chart !== 'undefined') {
    if(chartFilial) chartFilial.destroy();
    chartFilial = new Chart(canvasFilial, {
      type:'bar',
      data:{ labels: porFilial.map(d=>d.nome),
        datasets:[{ label:'Itens', data: porFilial.map(d=>d.total), backgroundColor: roseColor, borderRadius:4 }] },
      options:{ responsive:true, maintainAspectRatio:false, plugins:{legend:{display:false}},
        scales:{ x:{ticks:{color:textColor}, grid:{display:false}}, y:{ticks:{color:textColor}, grid:{color:gridColor}} } }
    });
  }

  const movimentacoesSemana = dados.movimentacoesSemana || { labels:[], entradas:[], saidas:[] };
  const canvasMov = $('chart-movimentacoes');
  if(canvasMov && typeof Chart !== 'undefined') {
    if(chartMov) chartMov.destroy();
    chartMov = new Chart(canvasMov, {
      type:'line',
      data:{ labels: movimentacoesSemana.labels,
        datasets:[
          {label:'Entradas', data: movimentacoesSemana.entradas, borderColor:'#2f7d4f', tension:0.3},
          {label:'Saídas', data: movimentacoesSemana.saidas, borderColor: roseColor, tension:0.3}
        ]},
      options:{ responsive:true, maintainAspectRatio:false, plugins:{legend:{labels:{color:textColor}}},
        scales:{ x:{ticks:{color:textColor}, grid:{display:false}}, y:{ticks:{color:textColor}, grid:{color:gridColor}} } }
    });
  }
}

function pintarAlertasDashboard(alertas){
  const dashA = $('dash-alertas');
  if (dashA) {
    dashA.innerHTML = alertas.length === 0
      ? '<p class="empty-state">Nenhum alerta no momento.</p>'
      : `<table>
          <thead><tr><th>Produto</th><th>Filial</th><th>Qtd. Atual</th><th>Qtd. Mínima</th><th>Status</th></tr></thead>
          <tbody>
            ${alertas.map(e => `
              <tr>
                <td><b>${escapeHtml(e.produtoNome ?? nomeProduto(e.produto_id))}</b></td>
                <td>${escapeHtml(e.filialNome ?? nomeFilial(e.filial_id))}</td>
                <td>${e.quantidade}</td>
                <td>${e.quantidadeMinima ?? minProduto(e.produto_id)}</td>
                <td><span class="badge ${e.quantidade===0?'danger':'warn'}">${STATUS_LABEL[e.status ?? statusEstoque(e.quantidade, e.quantidadeMinima ?? minProduto(e.produto_id))]}</span></td>
              </tr>
            `).join('')}
          </tbody>
        </table>`;
  }
}

// ---------- PRODUTOS ----------
async function renderProdutos(){
  mostrarLoading($('tbody-produtos'));
  try {
    produtos = await api.listarProdutos();
    estoques = await api.listarEstoque();
    inativosLocais = await api.listarInativosLocais();
    pintarProdutos();
  } catch (err) {
    const tb = $('tbody-produtos');
    if (tb) tb.innerHTML = '<tr><td colspan="8" class="empty-state">Não foi possível carregar os produtos.</td></tr>';
  }
}

function pintarProdutos(){
  const tb = $('tbody-produtos');
  if (!tb) return;

  if(produtos.length === 0){
    tb.innerHTML = '<tr><td colspan="8" class="empty-state">Nenhum produto cadastrado. Clique em "Novo Produto" para começar.</td></tr>';
    return;
  }

  const busca = $('busca-produto') ? $('busca-produto').value.toLowerCase() : '';
  const st = $('filtro-status') ? $('filtro-status').value : '';

  const isGerente = usuario && usuario.tipo === 'gerente';

  let html = '';
  produtos
    .filter(p => p.nome.toLowerCase().includes(busca) || p.sku.toLowerCase().includes(busca))
    .forEach(p => {
      let filteredEstoques = estoques.filter(e => e.produto_id === p.id);
      if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
        filteredEstoques = filteredEstoques.filter(e => e.filial_id == usuario.filial_id);
      }
      filteredEstoques.forEach(e => {
        const status = statusEstoque(e.quantidade);
        if(st && status !== st) return;

        const isInativoNaFilial = inativosLocais.some(i => String(i.produto_id) === String(p.id) && String(i.filial_id) === String(e.filial_id));

        let statusBadge = `<span class="badge ${status==='zerado'?'danger':'ok'}">${STATUS_LABEL[status]}</span>`;
        if (p.ativo === false || isInativoNaFilial) {
          statusBadge += ` <span class="badge danger" style="background:#ef444422; color:#ef4444; margin-left:4px;">Inativo na Filial</span>`;
        }

        let acoesHtml = `<button class="btn-sm btn-secondary" onclick="abrirModalAjuste(${p.id}, ${e.filial_id})">Ajustar</button>`;
        if (isGerente && usuario && usuario.filial_id == e.filial_id) {
          acoesHtml += `
            <button class="btn-sm btn-secondary" style="margin-left:4px;" onclick="abrirModalEditarProduto(${p.id})">Editar</button>
            ${(!isInativoNaFilial && p.ativo !== false) ? `<button class="btn-sm btn-secondary" style="margin-left:4px; color:var(--danger-color, #ef4444);" onclick="inativarPrd(${p.id}, ${e.filial_id}, this)">Inativar</button>` : ''}
          `;
        } else if (isGerente) {
          acoesHtml += `
            <button class="btn-sm btn-secondary" style="margin-left:4px;" onclick="abrirModalEditarProduto(${p.id})">Editar</button>
          `;
        }

        html += `
          <tr class="${(p.ativo === false || isInativoNaFilial) ? 'row-inativo' : ''}">
            <td><code>${escapeHtml(p.sku)}</code></td>
            <td><b>${escapeHtml(p.nome)}</b></td>
            <td>${escapeHtml(p.categoria)}</td>
            <td>${escapeHtml(nomeFilial(e.filial_id))}</td>
            <td>${e.quantidade}</td>
            <td>${statusBadge}</td>
            <td>${acoesHtml}</td>
          </tr>`;
      });
    });
  tb.innerHTML = html || '<tr><td colspan="8" class="empty-state">Nenhum produto encontrado.</td></tr>';
}

function abrirModalEditarProduto(id) {
  if (usuario && usuario.tipo !== 'gerente') {
    toast('Apenas gerentes podem editar produtos.', true);
    return;
  }
  const prd = produtos.find(p => p.id === id);
  if (!prd) {
    toast('Produto não localizado.', true);
    return;
  }

  $('ep-id').value = prd.id;
  $('ep-nome').value = prd.nome;
  $('ep-sku').value = prd.sku;
  $('ep-cat').value = obterCategoriaPorNome(prd.nome);

  const overlay = $('modal-overlay');
  const modalE = $('modal-editar-produto');
  if (overlay) overlay.classList.add('active');
  if (modalE) modalE.style.display = 'block';
}

async function salvarEdicaoProduto() {
  const saveBtn = document.querySelector('#modal-editar-produto button.btn-primary');
  if (saveBtn && saveBtn.disabled) return;

  const id = parseInt($('ep-id').value);
  const nome = $('ep-nome').value.trim();
  const sku = $('ep-sku').value.trim();
  const categoria = obterCategoriaPorNome(nome);

  if (!nome || !sku) {
    toast('Nome e SKU são obrigatórios.', true);
    return;
  }

  if (saveBtn) saveBtn.disabled = true;

  try {
    await api.editarProduto(id, { nome, sku, categoria, qtd_minima: 0 });
    fecharModal();
    toast('Produto atualizado com sucesso!');
    renderProdutos();
  } catch (err) {
    toast(err.message || 'Não foi possível atualizar o produto.', true);
  } finally {
    if (saveBtn) saveBtn.disabled = false;
  }
}

async function inativarPrd(id, filialId, btn) {
  if (usuario && usuario.tipo !== 'gerente') {
    toast('Apenas gerentes podem inativar produtos.', true);
    return;
  }
  const prd = produtos.find(p => p.id === id);
  if (!prd) return;

  const targetFilial = filialId || (usuario ? usuario.filial_id : null);
  if (usuario && usuario.tipo === 'gerente' && usuario.filial_id && targetFilial != usuario.filial_id) {
    toast('Acesso negado: Gerente só pode retirar de uso produtos da sua própria filial.', true);
    return;
  }

  if (!confirm(`Deseja realmente retirar de uso o produto "${prd.nome}" na filial ${nomeFilial(targetFilial)}?`)) {
    return;
  }

  if (btn && btn.disabled) return;
  if (btn) btn.disabled = true;

  try {
    await api.inativarProdutoLocal(id, targetFilial);
    toast(`Produto "${prd.nome}" retirado de uso na filial ${nomeFilial(targetFilial)} com sucesso!`);
    renderProdutos();
  } catch (err) {
    toast(err.message || 'Não foi possível inativar o produto na filial.', true);
  } finally {
    if (btn) btn.disabled = false;
  }
}

const MAPA_SKU = {
  'Colar de prata': '01',
  'Colar de ouro': '02',
  'Anel de prata': '03',
  'Anel de ouro': '04',
  'Brinco de prata': '05',
  'Brinco de ouro': '06',
  'Solitária': '07',
  'Pulseira de prata': '08',
  'Pulseira de ouro': '09'
};

const MAPA_CATEGORIAS_OFICIAIS = {
  'anel de ouro': 'ANEL',
  'anel de prata': 'ANEL',
  'pulseira de ouro': 'PULSEIRA',
  'pulseira de prata': 'PULSEIRA',
  'solitária': 'SOLITARIA',
  'solitaria': 'SOLITARIA',
  'colar de ouro': 'COLAR',
  'colar de prata': 'COLAR',
  'brinco de ouro': 'BRINCO',
  'brinco de prata': 'BRINCO'
};

function obterCategoriaPorNome(nome) {
  if (!nome) return 'ANEL';
  const nomeLower = nome.trim().toLowerCase();
  return MAPA_CATEGORIAS_OFICIAIS[nomeLower] || 'ANEL';
}

function obterSkuPorNome(nome) {
  if (!nome) return '01';
  const nomeLower = nome.trim().toLowerCase();
  for (const [key, val] of Object.entries(MAPA_SKU)) {
    if (key.toLowerCase() === nomeLower) return val;
  }
  return '01';
}

function atualizarSkuPorTipo() {
  const pNome = $('p-nome');
  const pSku = $('p-sku');
  const pCat = $('p-cat');
  if (pNome) {
    const tipo = pNome.value;
    if (pSku) pSku.value = obterSkuPorNome(tipo);
    if (pCat) pCat.value = obterCategoriaPorNome(tipo);
  }
}

function renderProdutosFiltro(){ pintarProdutos(); }

function abrirModalProduto(){
  const pf = $('p-filial');
  if (pf) {
    pf.innerHTML = FILIAIS.map(f => `<option value="${f.id}">${escapeHtml(f.nome)}</option>`).join('');
    if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
      pf.value = usuario.filial_id;
      pf.disabled = true;
    } else {
      pf.disabled = false;
    }
  }

  atualizarSkuPorTipo();

  const overlay = $('modal-overlay');
  const modalP = $('modal-produto');
  if (overlay) overlay.classList.add('active');
  if (modalP) modalP.style.display = 'block';
}

async function salvarProduto(){
  const saveBtn = document.querySelector('#modal-produto button.btn-primary');
  if (saveBtn && saveBtn.disabled) return;

  const nome = $('p-nome') ? $('p-nome').value.trim() : '';
  const sku = $('p-sku') ? $('p-sku').value.trim() : '';
  const categoria = obterCategoriaPorNome(nome);
  const filialId = parseInt($('p-filial') ? $('p-filial').value : 0);
  const minRaw = $('p-min') ? $('p-min').value : '10';
  const qtd_minima = parseInt(minRaw);

  if(!nome || !sku){ toast('Preencha Nome e SKU.', true); return; }
  if(!filialId){ toast('Selecione uma filial obrigatória.', true); return; }
  if(!Number.isInteger(qtd_minima) || qtd_minima < 0){ toast('Estoque mínimo deve ser um número inteiro válido.', true); return; }

  if (saveBtn) saveBtn.disabled = true;

  try {
    await api.criarProduto({ nome, sku, categoria, filialId, qtd_minima });
    fecharModal();
    toast('Produto adicionado com sucesso!');
    renderProdutos();
  } catch (err) {
    toast(err.message || 'Não foi possível salvar o produto.', true);
  } finally {
    if (saveBtn) saveBtn.disabled = false;
  }
}

// ---------- ESTOQUE ----------
async function renderEstoque(){
  mostrarLoading($('tbody-estoque'));
  try {
    estoques = await api.listarEstoque(filialEstoqueSel);
    if(produtos.length === 0) produtos = await api.listarProdutos();
    atualizarSelectFiltroProdutoEstoque();
    pintarEstoque();
  } catch (err) {
    const tb = $('tbody-estoque');
    if (tb) tb.innerHTML = '<tr><td colspan="7" class="empty-state">Não foi possível carregar o estoque.</td></tr>';
  }
}

function atualizarSelectFiltroProdutoEstoque() {
  const selectP = $('filtro-estoque-produto');
  if (!selectP) return;

  const currentVal = selectP.value;
  const options = ['<option value="">Todos os produtos</option>'];
  produtos.forEach(p => {
    options.push(`<option value="${p.id}">${escapeHtml(p.nome)} (${escapeHtml(p.sku)})</option>`);
  });
  selectP.innerHTML = options.join('');
  if (currentVal) selectP.value = currentVal;
}

function pintarEstoque(){
  const tb = $('tbody-estoque');
  if (!tb) return;

  let list = estoques;
  if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
    list = list.filter(e => e.filial_id == usuario.filial_id);
  } else if (filialEstoqueSel) {
    list = list.filter(e => e.filial_id == filialEstoqueSel);
  }

  const prodSel = $('filtro-estoque-produto') ? $('filtro-estoque-produto').value : '';
  if (prodSel) {
    list = list.filter(e => String(e.produto_id) === String(prodSel));
  }

  if(list.length === 0){
    tb.innerHTML = '<tr><td colspan="6" class="empty-state">Nenhum produto cadastrado ainda neste filtro.</td></tr>';
    return;
  }
  tb.innerHTML = list.map(e => {
    const p = produtos.find(prd => String(prd.id) === String(e.produto_id)) || {};
    const st = statusEstoque(e.quantidade);
    return `
      <tr>
        <td><code>${escapeHtml(p.sku ?? '—')}</code></td>
        <td><b>${escapeHtml(p.nome ?? '—')}</b></td>
        <td>${escapeHtml(nomeFilial(e.filial_id))}</td>
        <td>${e.quantidade}</td>
        <td><span class="badge ${st==='zerado'?'danger':'ok'}">${STATUS_LABEL[st]}</span></td>
        <td><button class="btn-sm btn-secondary" onclick="abrirModalAjuste(${e.produto_id}, ${e.filial_id})">Ajustar</button></td>
      </tr>`;
  }).join('');
}

function abrirModalAjuste(pid, fid){
  if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id && fid != usuario.filial_id) {
    toast('Acesso negado: Funcionário só pode alterar o estoque da sua própria filial.', true);
    return;
  }
  ajusteTarget = {pid, fid};
  const titulo = $('ajuste-titulo');
  if (titulo) titulo.textContent = `Ajustar: ${nomeProduto(pid)} (${nomeFilial(fid)})`;

  const overlay = $('modal-overlay');
  const modalA = $('modal-ajuste');
  if (overlay) overlay.classList.add('active');
  if (modalA) modalA.style.display = 'block';
}

async function salvarAjuste(){
  const saveBtn = document.querySelector('#modal-ajuste button.btn-primary');
  if (saveBtn && saveBtn.disabled) return;

  const tipo = $('a-tipo') ? $('a-tipo').value : 'entrada';
  const qtdRaw = $('a-qtd') ? $('a-qtd').value : '0';
  const quantidade = parseInt(qtdRaw);
  const motivo = $('a-motivo') ? $('a-motivo').value.trim() : '';

  if (!Number.isInteger(quantidade) || quantidade <= 0) {
    toast('Informe uma quantidade inteira válida maior que zero.', true);
    return;
  }

  if (saveBtn) saveBtn.disabled = true;

  try {
    await api.ajustarEstoque({
      produtoId: ajusteTarget.pid,
      filialId: ajusteTarget.fid,
      tipo, quantidade,
      motivo: motivo || 'Ajuste manual',
      usuario: usuario ? usuario.nome : 'Usuário'
    });
    fecharModal();
    toast('Estoque atualizado!');
    irPara('estoque');
  } catch (err) {
    toast(err.message || 'Não foi possível ajustar o estoque.', true);
  } finally {
    if (saveBtn) saveBtn.disabled = false;
  }
}

// ---------- TRANSFERÊNCIAS ----------
async function renderTransferencias(){
  mostrarLoading($('tbody-transferencias'));
  try {
    transferencias = await api.listarTransferencias();
    pintarTransferencias();
  } catch (err) {
    const tb = $('tbody-transferencias');
    if (tb) tb.innerHTML = '<tr><td colspan="9" class="empty-state">Não foi possível carregar as transferências.</td></tr>';
  }
}

function pintarTransferencias(){
  const tb = $('tbody-transferencias');
  if (!tb) return;

  tb.innerHTML = transferencias.length === 0
    ? '<tr><td colspan="9" class="empty-state">Nenhuma transferência registrada.</td></tr>'
    : transferencias.map(t => {
      const pender = t.status === 'solicitada' || t.status === 'pendente';
      const tDestinoId = t.destino_id || t.destino_filial_id;
      const podeConcluir = usuario && (usuario.tipo === 'gerente' || String(tDestinoId) === String(usuario.filial_id));

      let acaoHtml = '—';
      if (pender) {
        if (podeConcluir) {
          acaoHtml = `<button class="btn-sm btn-primary" onclick="concluirTransf(${t.id}, this)">Concluir</button>`;
        } else {
          acaoHtml = `<button class="btn-sm btn-secondary" disabled title="Apenas a filial de destino ou um gerente pode concluir esta transferência">Concluir</button>`;
        }
      }

      return `
      <tr>
        <td>#${t.id}</td>
        <td><b>${escapeHtml(t.produtoNome ?? nomeProduto(t.produto_id))}</b></td>
        <td>${escapeHtml(t.origemNome ?? nomeFilial(t.origem_id))}</td>
        <td>${escapeHtml(t.destinoNome ?? nomeFilial(t.destino_id))}</td>
        <td>${t.quantidade}</td>
        <td>${escapeHtml(t.solicitante)}</td>
        <td>${escapeHtml(t.data)}</td>
        <td><span class="badge ${t.status==='concluida'?'ok':'info'}">${escapeHtml(t.status)}</span></td>
        <td>${acaoHtml}</td>
      </tr>
    `}).join('');
}

async function abrirModalTransferencia(){
  try {
    if(produtos.length === 0) produtos = await api.listarProdutos();
  } catch (err) {
    toast('Não foi possível carregar os produtos.', true);
    return;
  }
  const produtosAtivos = produtos.filter(p => p.ativo !== false);
  if(produtosAtivos.length === 0){ toast('Nenhum produto ativo disponível para transferência.', true); return; }

  const tp = $('t-produto');
  if (tp) tp.innerHTML = produtosAtivos.map(p=>`<option value="${p.id}">${escapeHtml(p.nome)}</option>`).join('');

  const to = $('t-origem');
  if (to) {
    to.innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${escapeHtml(f.nome)}</option>`).join('');
    if (usuario && usuario.tipo === 'funcionario' && usuario.filial_id) {
      to.value = usuario.filial_id;
      to.disabled = true;
    } else {
      to.disabled = false;
    }
  }

  const td = $('t-destino');
  if (td) td.innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${escapeHtml(f.nome)}</option>`).join('');

  const overlay = $('modal-overlay');
  const modalT = $('modal-transferencia');
  if (overlay) overlay.classList.add('active');
  if (modalT) modalT.style.display = 'block';
}

async function salvarTransferencia(){
  const saveBtn = document.querySelector('#modal-transferencia button.btn-primary');
  if (saveBtn && saveBtn.disabled) return;

  const produtoId = parseInt($('t-produto') ? $('t-produto').value : 0);
  const origemId = parseInt($('t-origem') ? $('t-origem').value : 0);
  const destinoId = parseInt($('t-destino') ? $('t-destino').value : 0);
  const qtdRaw = $('t-qtd') ? $('t-qtd').value : '0';
  const quantidade = parseInt(qtdRaw);

  if(!Number.isInteger(quantidade) || quantidade <= 0){
    toast('Informe uma quantidade inteira válida maior que zero.', true);
    return;
  }
  if(origemId === destinoId){ toast('Origem e Destino devem ser diferentes.', true); return; }

  if (saveBtn) saveBtn.disabled = true;

  try {
    await api.criarTransferencia({ produtoId, origemId, destinoId, quantidade, solicitante: usuario ? usuario.nome : 'Usuário' });
    fecharModal();
    toast('Transferência solicitada!');
    renderTransferencias();
  } catch (err) {
    toast(err.message || 'Não foi possível solicitar a transferência.', true);
  } finally {
    if (saveBtn) saveBtn.disabled = false;
  }
}

async function concluirTransf(id, btn){
  if (btn) {
    if (btn.disabled) return;
    btn.disabled = true;
    btn.textContent = 'Processando...';
  }
  try {
    const res = await api.concluirTransferencia(id);
    if (res && res.success === true) {
      toast('Transferência concluída com sucesso!');
      renderTransferencias();
    } else {
      throw new Error((res && res.message) ? res.message : 'Falha na conclusão da transferência.');
    }
  } catch (err) {
    toast(err.message || 'Não foi possível concluir a transferência.', true);
  } finally {
    if (btn) {
      btn.disabled = false;
      btn.textContent = 'Concluir';
    }
  }
}

// ---------- PEDIDOS DE COMPRA ----------
async function renderPedidos(){
  mostrarLoading($('tbody-pedidos'));
  try {
    pedidos = await api.listarPedidos();
    pintarPedidos();
  } catch (err) {
    const tb = $('tbody-pedidos');
    if (tb) tb.innerHTML = '<tr><td colspan="8" class="empty-state">Não foi possível carregar os pedidos.</td></tr>';
  }
}

function pintarPedidos(){
  const tb = $('tbody-pedidos');
  if (!tb) return;

  if (pedidos.length === 0) {
    tb.innerHTML = '<tr><td colspan="8" class="empty-state">Nenhum pedido de compra.</td></tr>';
    return;
  }

  tb.innerHTML = pedidos.map(p => {
    const isRecebido = p.status === 'recebido';
    const statusBadgeClass = isRecebido ? 'ok' : 'info';

    let acaoHtml = '—';
    if (!isRecebido) {
      const pFilialId = p.filial_id ?? p.filialId;
      const podeReceber = usuario && (usuario.tipo === 'gerente' || String(pFilialId) === String(usuario.filial_id));
      if (podeReceber) {
        acaoHtml = `<button class="btn-sm btn-primary" onclick="receberPedido(${p.id}, this)">Marcar como Recebido</button>`;
      } else {
        acaoHtml = `<button class="btn-sm btn-secondary" disabled title="Apenas o gerente ou funcionário desta filial pode receber este pedido">Marcar como Recebido</button>`;
      }
    }

    return `
      <tr>
        <td>#${p.id}</td>
        <td><b>${escapeHtml(p.produtoNome ?? nomeProduto(p.produto_id))}</b></td>
        <td>${p.quantidade}</td>
        <td>${escapeHtml(p.filialNome ?? nomeFilial(p.filial_id))}</td>
        <td>${escapeHtml(p.solicitante)}</td>
        <td>${escapeHtml(p.data)}</td>
        <td><span class="badge ${statusBadgeClass}">${escapeHtml(p.status)}</span></td>
        <td>${acaoHtml}</td>
      </tr>
    `;
  }).join('');
}

async function receberPedido(id, btn){
  if (btn) {
    if (btn.disabled) return;
    btn.disabled = true;
    btn.textContent = 'Processando...';
  }
  try {
    const res = await api.receberPedido(id);
    if (res && res.success === true) {
      toast('Pedido de compra marcado como recebido com sucesso!');
      renderPedidos();
    } else {
      throw new Error((res && res.message) ? res.message : 'Falha ao receber pedido de compra.');
    }
  } catch (err) {
    toast(err.message || 'Não foi possível receber o pedido de compra.', true);
  } finally {
    if (btn) {
      btn.disabled = false;
      btn.textContent = 'Marcar como Recebido';
    }
  }
}

async function abrirModalPedido(){
  if (usuario && usuario.tipo !== 'gerente') {
    toast('Somente gerentes podem criar pedidos de compra.', true);
    return;
  }

  try {
    if(produtos.length === 0) produtos = await api.listarProdutos();
  } catch (err) {
    toast('Não foi possível carregar os produtos.', true);
    return;
  }
  const produtosAtivos = produtos.filter(p => p.ativo !== false);
  if(produtosAtivos.length === 0){ toast('Nenhum produto ativo disponível para criação de pedidos.', true); return; }

  const pcp = $('pc-produto');
  if (pcp) pcp.innerHTML = produtosAtivos.map(p=>`<option value="${p.id}">${escapeHtml(p.nome)}</option>`).join('');

  const pcf = $('pc-filial');
  if (pcf) pcf.innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${escapeHtml(f.nome)}</option>`).join('');

  const overlay = $('modal-overlay');
  const modalP = $('modal-pedido');
  if (overlay) overlay.classList.add('active');
  if (modalP) modalP.style.display = 'block';
}

async function salvarPedido(){
  if (usuario && usuario.tipo !== 'gerente') {
    toast('Apenas gerentes possuem permissão para criar pedidos.', true);
    return;
  }

  const saveBtn = document.querySelector('#modal-pedido button.btn-primary');
  if (saveBtn && saveBtn.disabled) return;

  const produtoId = parseInt($('pc-produto') ? $('pc-produto').value : 0);
  const filialId = parseInt($('pc-filial') ? $('pc-filial').value : 0);
  const qtdRaw = $('pc-qtd') ? $('pc-qtd').value : '0';
  const quantidade = parseInt(qtdRaw);

  if (!produtoId || !filialId || !Number.isInteger(quantidade) || quantidade <= 0) {
    toast('Selecione o produto, a filial e uma quantidade inteira maior que zero.', true);
    return;
  }

  if (saveBtn) saveBtn.disabled = true;

  try {
    await api.criarPedido({ produtoId, filialId, quantidade, solicitante: usuario ? usuario.nome : 'Gerente' });
    fecharModal();
    toast('Pedido de compra criado com sucesso!');
    renderPedidos();
  } catch (err) {
    toast(err.message || 'Não foi possível criar o pedido.', true);
  } finally {
    if (saveBtn) saveBtn.disabled = false;
  }
}

// ---------- ALERTAS ----------
async function renderAlertas(){
  mostrarLoading($('tbody-alertas'));
  try {
    const dados = await api.listarAlertas();
    const kpis = $('alertas-kpis');
    if (kpis) {
      kpis.innerHTML = `
        <div class="card kpi"><span class="label">Estoque Baixo</span><span class="value" style="color:var(--warn-color)">${dados.totalBaixo ?? 0}</span></div>
        <div class="card kpi"><span class="label">Estoque Zerado</span><span class="value" style="color:var(--danger-color)">${dados.totalZerado ?? 0}</span></div>`;
    }

    const tb = $('tbody-alertas');
    if (tb) {
      const itens = dados.itens || [];
      tb.innerHTML = itens.length === 0
        ? '<tr><td colspan="7" class="empty-state">Nenhum alerta no momento.</td></tr>'
        : itens.map(e => `
          <tr>
            <td><code>${escapeHtml(e.sku ?? skuProduto(e.produto_id))}</code></td>
            <td><b>${escapeHtml(e.produtoNome ?? nomeProduto(e.produto_id))}</b></td>
            <td>${escapeHtml(e.filialNome ?? nomeFilial(e.filial_id))}</td>
            <td>${e.quantidade}</td>
            <td>${e.quantidadeMinima ?? minProduto(e.produto_id)}</td>
            <td><span class="badge ${e.status==='zerado'?'danger':'warn'}">${STATUS_LABEL[e.status]}</span></td>
            <td><button class="btn-sm btn-primary" onclick="abrirModalAjuste(${e.produto_id}, ${e.filial_id})">Repor</button></td>
          </tr>`).join('');
    }
  } catch (err) {
    const tb = $('tbody-alertas');
    if (tb) tb.innerHTML = '<tr><td colspan="7" class="empty-state">Não foi possível carregar os alertas.</td></tr>';
  }
}

// ---------- HISTÓRICO ----------
async function renderHistorico(){
  mostrarLoading($('tbody-historico'));
  const tipo = $('hist-tipo') ? $('hist-tipo').value : '';
  const filialId = $('hist-filial') ? $('hist-filial').value : '';

  try {
    movimentacoes = await api.listarHistorico({ ...(tipo && {tipo}), ...(filialId && {filialId}) });
    const tb = $('tbody-historico');
    if (tb) {
      tb.innerHTML = movimentacoes.length === 0
        ? '<tr><td colspan="8" class="empty-state">Nenhuma movimentação registrada.</td></tr>'
        : movimentacoes.map(m => `
          <tr>
            <td>${escapeHtml(m.data)}</td>
            <td><b>${escapeHtml(m.produtoNome ?? nomeProduto(m.produto_id))}</b></td>
            <td>${escapeHtml(m.filialNome ?? nomeFilial(m.filial_id))}</td>
            <td><span class="badge ${m.tipo==='entrada'?'ok':'warn'}">${escapeHtml(m.tipo)}</span></td>
            <td>${m.anterior}</td>
            <td>${m.nova}</td>
            <td>${escapeHtml(m.usuario)}</td>
            <td>${escapeHtml(m.motivo)}</td>
          </tr>
        `).join('');
    }
  } catch (err) {
    const tb = $('tbody-historico');
    if (tb) tb.innerHTML = '<tr><td colspan="8" class="empty-state">Não foi possível carregar o histórico.</td></tr>';
  }
}

// ---------- FECHAR MODAIS ----------
function fecharModal(){
  const overlay = $('modal-overlay');
  if (overlay) overlay.classList.remove('active');
  document.querySelectorAll('.modal').forEach(m => m.style.display = 'none');
}
