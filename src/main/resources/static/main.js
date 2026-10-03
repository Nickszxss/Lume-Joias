/* =====================================================================
   SGE — Camada de Front-end (visualização + interação)
   Toda a lógica de negócio e persistência fica no backend Java + Supabase.
   Este arquivo apenas consome a API e atualiza a tela.
   ===================================================================== */

// ---------- CONFIGURAÇÃO DA API E BASE DADOS DEMO/STATIC ----------
const IS_LOCAL = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
const API_BASE_URL = IS_LOCAL ? 'http://localhost:8080/api' : '/api';

// Usuários válidos para fallback no GitHub Pages / frontend estático
const MOCK_USUARIOS = [
  { id: 1, nome: 'Anderson', email: 'anderson.func@empresa.com', senha: 'etec2026@DS', cargo: 'funcionario', tipo: 'funcionario', filial_id: 1 },
  { id: 2, nome: 'Robson', email: 'robson.grt@empresa.com', senha: 'etec2026@DS', cargo: 'gerente', tipo: 'gerente', filial_id: null },
  { id: 3, nome: 'Isabella', email: 'isabella.func@empresa.com', senha: 'etec2026@DS', cargo: 'funcionario', tipo: 'funcionario', filial_id: 2 },
  { id: 4, nome: 'Manuella', email: 'manuella.grt@empresa.com', senha: 'etec2026@DS', cargo: 'gerente', tipo: 'gerente', filial_id: null }
];

// Fallback de dados estáticos para simulação completa no GitHub Pages quando backend Java não estiver exposto publicamente
let mockFiliais = [
  { id: 1, nome: 'Filial Centro' },
  { id: 2, nome: 'Filial Norte' },
  { id: 3, nome: 'Filial Sul' },
  { id: 4, nome: 'Filial Leste' },
  { id: 5, nome: 'Filial Oeste' }
];

let mockProdutos = [
  { id: 1, sku: 'JOIA-001', nome: 'Anel de Ouro 18k', categoria: 'Aneis', qtd_minima: 5 },
  { id: 2, sku: 'JOIA-002', nome: 'Colar de Prata 925', categoria: 'Colares', qtd_minima: 10 },
  { id: 3, sku: 'JOIA-003', nome: 'Brinco de Diamante', categoria: 'Brincos', qtd_minima: 3 }
];

let mockEstoques = [
  { produto_id: 1, filial_id: 1, quantidade: 12, status: 'suficiente' },
  { produto_id: 1, filial_id: 2, quantidade: 2, status: 'baixo' },
  { produto_id: 2, filial_id: 1, quantidade: 15, status: 'suficiente' },
  { produto_id: 2, filial_id: 2, quantidade: 0, status: 'zerado' },
  { produto_id: 3, filial_id: 1, quantidade: 1, status: 'baixo' }
];

let mockTransferencias = [
  { id: 1, produto_id: 1, produtoNome: 'Anel de Ouro 18k', origem_id: 1, origemNome: 'Filial Centro', destino_id: 2, destinoNome: 'Filial Norte', quantidade: 2, solicitante: 'Anderson', data: new Date().toLocaleDateString('pt-BR'), status: 'pendente' }
];

let mockPedidos = [
  { id: 1, produto_id: 2, produtoNome: 'Colar de Prata 925', quantidade: 20, filial_id: 2, filialNome: 'Filial Norte', solicitante: 'Robson', data: new Date().toLocaleDateString('pt-BR'), status: 'solicitado' }
];

let mockMovimentacoes = [
  { data: new Date().toLocaleString('pt-BR'), produto_id: 1, produtoNome: 'Anel de Ouro 18k', filial_id: 1, filialNome: 'Filial Centro', tipo: 'entrada', anterior: 10, nova: 12, usuario: 'Anderson', motivo: 'Carga inicial de estoque' }
];

// Wrapper único de fetch: centraliza headers, tratamento de erro, JSON e fallback local para GitHub Pages.
async function apiRequest(path, options = {}) {
  let res;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, {
      headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
      ...options
    });
  } catch (err) {
    // Caso esteja rodando sem o backend Java ativo (ex: GitHub Pages puro sem servidor), executa fallback funcional
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

  if (path === '/auth/login' && method === 'POST') {
    const usr = MOCK_USUARIOS.find(u =>
      u.nome.toLowerCase() === (body.nome || '').trim().toLowerCase() &&
      u.email.toLowerCase() === (body.email || '').trim().toLowerCase() &&
      u.senha === body.senha
    );
    if (!usr) throw new Error('Credenciais inválidas.');
    return { id: usr.id, nome: usr.nome, email: usr.email, cargo: usr.cargo, tipo: usr.tipo, filial_id: usr.filial_id, filialId: usr.filial_id };
  }

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
      solicitante: body.solicitante, data: new Date().toLocaleDateString('pt-BR'), status: 'solicitado'
    };
    mockPedidos.unshift(novoP);
    return novoP;
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
          sku: p.sku || p.codigo || `JOIA-00${p.id}`,
          nome: p.nome,
          categoria: p.categoria || 'Geral',
          qtd_minima: p.qtd_minima ?? 0
        }));
      }
    }
    return apiRequest('/produtos');
  },

  criarProduto: async (dados) => {
    const client = getSupabaseClient();
    if (client) {
      // Inserir produto na tabela produtos do Supabase
      const payloadProduto = {
        nome: dados.nome,
        codigo: dados.sku,
        descricao: dados.categoria || 'Geral',
        qtd_minima: dados.qtd_minima || 0,
        unidade_medida: 'unidade',
        ativo: true
      };
      const { data: pData, error: pErr } = await client.from('produtos').insert([payloadProduto]).select().single();
      if (!pErr && pData) {
        const prodId = pData.id;
        // Inserir registros de estoque inicial para as 5 filiais
        const { data: listF } = await client.from('filiais').select('id');
        const filiaisIds = (listF && listF.length > 0) ? listF.map(f => f.id) : [1, 2, 3, 4, 5];
        const initialQtd = dados.qtd_inicial || 0;
        const minQtd = dados.qtd_minima || 0;
        const st = initialQtd === 0 ? 'zerado' : (initialQtd <= minQtd ? 'baixo' : 'suficiente');

        const estoqueRecords = filiaisIds.map(fid => ({
          produto_id: prodId,
          filial_id: fid,
          quantidade: initialQtd,
          status: st
        }));
        await client.from('estoques').insert(estoqueRecords);

        return {
          id: prodId,
          sku: dados.sku,
          nome: dados.nome,
          categoria: dados.categoria || 'Geral',
          qtd_minima: dados.qtd_minima || 0
        };
      }
    }
    return apiRequest('/produtos', { method: 'POST', body: JSON.stringify(dados) });
  },

  listarEstoque: async (filialId) => {
    const client = getSupabaseClient();
    if (client) {
      let query = client.from('estoques').select('*');
      if (filialId) query = query.eq('filial_id', filialId);
      const { data, error } = await query;
      if (!error && data) return data;
    }
    return apiRequest(`/estoque${filialId ? `?filialId=${filialId}` : ''}`);
  },

  ajustarEstoque: async (dados) => {
    const client = getSupabaseClient();
    if (client) {
      // Buscar registro atual de estoque
      const { data: currentStock } = await client
        .from('estoques')
        .select('*')
        .eq('produto_id', dados.produtoId)
        .eq('filial_id', dados.filialId)
        .single();

      const anterior = currentStock ? currentStock.quantidade : 0;
      const novaQtd = dados.tipo === 'entrada'
        ? anterior + dados.quantidade
        : Math.max(0, anterior - dados.quantidade);

      // Buscar produto para verificar quantidade mínima
      const { data: prd } = await client.from('produtos').select('*').eq('id', dados.produtoId).single();
      const minQtd = prd ? (prd.qtd_minima || 0) : 0;
      const st = novaQtd === 0 ? 'zerado' : (novaQtd <= minQtd ? 'baixo' : 'suficiente');

      if (currentStock) {
        await client
          .from('estoques')
          .update({ quantidade: novaQtd, status: st, updated_at: new Date().toISOString() })
          .eq('id', currentStock.id);
      } else {
        await client
          .from('estoques')
          .insert([{ produto_id: dados.produtoId, filial_id: dados.filialId, quantidade: novaQtd, status: st }]);
      }

      // Registrar auditoria em movimentacoes
      await client.from('movimentacoes').insert([{
        produto_id: dados.produtoId,
        filial_id: dados.filialId,
        tipo: dados.tipo,
        quantidade: dados.quantidade,
        quantidade_anterior: anterior,
        quantidade_nova: novaQtd,
        usuario: dados.usuario || (usuario ? usuario.nome : 'Usuário'),
        motivo: dados.motivo || 'Ajuste manual',
        created_at: new Date().toISOString()
      }]);

      return { produto_id: dados.produtoId, filial_id: dados.filialId, quantidade: novaQtd, status: st };
    }
    return apiRequest('/estoque/ajustar', { method: 'POST', body: JSON.stringify(dados) });
  },

  listarTransferencias: async () => {
    const client = getSupabaseClient();
    if (client) {
      const { data, error } = await client.from('transferencias').select('*').order('id', { ascending: false });
      if (!error && data) {
        const { data: prods } = await client.from('produtos').select('id, nome');
        const { data: fils } = await client.from('filiais').select('id, nome');
        return data.map(t => ({
          id: t.id,
          produto_id: t.produto_id,
          produtoNome: prods?.find(p => p.id === t.produto_id)?.nome || 'Produto',
          origem_id: t.origem_id || t.origem_filial_id,
          origemNome: fils?.find(f => f.id === (t.origem_id || t.origem_filial_id))?.nome || 'Filial Origem',
          destino_id: t.destino_id || t.destino_filial_id,
          destinoNome: fils?.find(f => f.id === (t.destino_id || t.destino_filial_id))?.nome || 'Filial Destino',
          quantidade: t.quantidade,
          solicitante: t.solicitante || t.usuario || 'Solicitante',
          data: t.created_at ? new Date(t.created_at).toLocaleDateString('pt-BR') : new Date().toLocaleDateString('pt-BR'),
          status: t.status || 'solicitada'
        }));
      }
    }
    return apiRequest('/transferencias');
  },

  criarTransferencia: async (dados) => {
    const client = getSupabaseClient();
    if (client) {
      const payload = {
        produto_id: dados.produtoId,
        origem_id: dados.origemId,
        destino_id: dados.destinoId,
        quantidade: dados.quantidade,
        solicitante: dados.solicitante || (usuario ? usuario.nome : 'Solicitante'),
        status: 'solicitada',
        created_at: new Date().toISOString()
      };
      const { data, error } = await client.from('transferencias').insert([payload]).select().single();
      if (!error && data) {
        return {
          id: data.id,
          produto_id: data.produto_id,
          origem_id: data.origem_id,
          destino_id: data.destino_id,
          quantidade: data.quantidade,
          solicitante: data.solicitante,
          data: new Date().toLocaleDateString('pt-BR'),
          status: 'solicitada'
        };
      }
    }
    return apiRequest('/transferencias', { method: 'POST', body: JSON.stringify(dados) });
  },

  concluirTransferencia: async (id) => {
    const client = getSupabaseClient();
    if (client) {
      const { data: transf } = await client.from('transferencias').select('*').eq('id', id).single();
      if (transf) {
        await client.from('transferencias').update({ status: 'concluida' }).eq('id', id);

        // Deduzir da origem e adicionar no destino
        const origId = transf.origem_id || transf.origem_filial_id;
        const destId = transf.destino_id || transf.destino_filial_id;

        if (origId && destId) {
          const { data: origEst } = await client.from('estoques').select('*').eq('produto_id', transf.produto_id).eq('filial_id', origId).single();
          const { data: destEst } = await client.from('estoques').select('*').eq('produto_id', transf.produto_id).eq('filial_id', destId).single();

          if (origEst) {
            const novOrig = Math.max(0, origEst.quantidade - transf.quantidade);
            await client.from('estoques').update({ quantidade: novOrig }).eq('id', origEst.id);
          }
          if (destEst) {
            const novDest = destEst.quantidade + transf.quantidade;
            await client.from('estoques').update({ quantidade: novDest }).eq('id', destEst.id);
          }
        }
        return { ...transf, status: 'concluida' };
      }
    }
    return apiRequest(`/transferencias/${id}/concluir`, { method: 'PATCH' });
  },

  listarPedidos: async () => {
    const client = getSupabaseClient();
    if (client) {
      const { data, error } = await client.from('pedidos_compra').select('*').order('id', { ascending: false });
      if (!error && data) {
        const { data: prods } = await client.from('produtos').select('id, nome');
        const { data: fils } = await client.from('filiais').select('id, nome');
        return data.map(p => ({
          id: p.id,
          produto_id: p.produto_id,
          produtoNome: prods?.find(prd => prd.id === p.produto_id)?.nome || 'Produto',
          quantidade: p.quantidade,
          filial_id: p.filial_id,
          filialNome: fils?.find(f => f.id === p.filial_id)?.nome || 'Filial',
          solicitante: p.solicitante || p.usuario || 'Gerente',
          data: p.created_at ? new Date(p.created_at).toLocaleDateString('pt-BR') : new Date().toLocaleDateString('pt-BR'),
          status: p.status || 'aberto'
        }));
      }
    }
    return apiRequest('/pedidos');
  },

  criarPedido: async (dados) => {
    const client = getSupabaseClient();
    if (client) {
      const payload = {
        produto_id: dados.produtoId,
        filial_id: dados.filialId,
        quantidade: dados.quantidade,
        solicitante: dados.solicitante || (usuario ? usuario.nome : 'Gerente'),
        status: 'aberto',
        created_at: new Date().toISOString()
      };
      const { data, error } = await client.from('pedidos_compra').insert([payload]).select().single();
      if (!error && data) {
        return {
          id: data.id,
          produto_id: data.produto_id,
          quantidade: data.quantidade,
          filial_id: data.filial_id,
          solicitante: data.solicitante,
          data: new Date().toLocaleDateString('pt-BR'),
          status: 'aberto'
        };
      }
    }
    return apiRequest('/pedidos', { method: 'POST', body: JSON.stringify(dados) });
  },

  listarAlertas: async () => {
    const client = getSupabaseClient();
    if (client) {
      const { data: listE } = await client.from('estoques').select('*');
      const { data: listP } = await client.from('produtos').select('*');
      const { data: listF } = await client.from('filiais').select('*');

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
    const client = getSupabaseClient();
    if (client) {
      let query = client.from('movimentacoes').select('*').order('id', { ascending: false });
      if (filtros.tipo) query = query.eq('tipo', filtros.tipo);
      if (filtros.filialId) query = query.eq('filial_id', filtros.filialId);

      const { data, error } = await query;
      if (!error && data) {
        const { data: prods } = await client.from('produtos').select('id, nome');
        const { data: fils } = await client.from('filiais').select('id, nome');
        return data.map(m => ({
          id: m.id,
          data: m.created_at ? new Date(m.created_at).toLocaleString('pt-BR') : new Date().toLocaleString('pt-BR'),
          produto_id: m.produto_id,
          produtoNome: prods?.find(p => p.id === m.produto_id)?.nome || 'Produto',
          filial_id: m.filial_id,
          filialNome: fils?.find(f => f.id === m.filial_id)?.nome || 'Filial',
          tipo: m.tipo,
          anterior: m.quantidade_anterior ?? m.anterior ?? 0,
          nova: m.quantidade_nova ?? m.nova ?? m.quantidade ?? 0,
          usuario: m.usuario || 'Usuário',
          motivo: m.motivo || 'Movimentação'
        }));
      }
    }
    const qs = new URLSearchParams(filtros).toString();
    return apiRequest(`/historico${qs ? `?${qs}` : ''}`);
  },

  resumoDashboard: async (filialId) => {
    const client = getSupabaseClient();
    if (client) {
      const { data: listE } = await client.from('estoques').select('*');
      const { data: listP } = await client.from('produtos').select('*');
      const { data: listF } = await client.from('filiais').select('*');
      const { data: listT } = await client.from('transferencias').select('*');

      if (listE && listP && listF) {
        const filteredE = filialId ? listE.filter(e => e.filial_id == filialId) : listE;
        const totalItens = filteredE.reduce((sum, e) => sum + e.quantidade, 0);
        const totalBaixo = filteredE.filter(e => e.status === 'baixo').length;
        const totalZerado = filteredE.filter(e => e.status === 'zerado').length;

        const estoquePorFilial = listF.map(f => ({
          nome: f.nome,
          total: listE.filter(e => e.filial_id === f.id).reduce((s, e) => s + e.quantidade, 0)
        }));

        const alertas = filteredE.filter(e => e.status === 'baixo' || e.status === 'zerado').map(e => ({
          ...e,
          produtoNome: listP.find(p => p.id === e.produto_id)?.nome,
          filialNome: listF.find(f => f.id === e.filial_id)?.nome,
          quantidadeMinima: listP.find(p => p.id === e.produto_id)?.qtd_minima || 0
        }));

        return {
          estoques: filteredE,
          produtos: listP,
          totalItens,
          totalProdutos: listP.length,
          totalBaixo,
          totalZerado,
          totalTransferenciasPendentes: listT ? listT.filter(t => t.status === 'solicitada' || t.status === 'pendente').length : 0,
          estoquePorFilial,
          movimentacoesSemana: { labels: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'], entradas: [12, 19, 3, 5, 2, 3, 10], saidas: [2, 3, 20, 5, 1, 4, 8] },
          alertas
        };
      }
    }
    return apiRequest(`/dashboard${filialId ? `?filialId=${filialId}` : ''}`);
  },
};

// ---------- ESTADO LOCAL (apenas cache do que veio da API) ----------
let usuario = null;
let FILIAIS = [];
let produtos = [];
let estoques = [];
let movimentacoes = [];
let transferencias = [];
let pedidos = [];

let chartFilial = null, chartMov = null;
let filialDashSel = null, filialEstoqueSel = null;
let ajusteTarget = null;

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
  if (document.getElementById('page-dashboard').classList.contains('active')) renderDashboard();
}
function updateThemeUI(theme) {
  const icon = document.getElementById('theme-icon');
  const text = document.getElementById('theme-text');
  const loginLogo = document.getElementById('login-logo');
  const appLogo = document.getElementById('app-logo');
  const logoSrc = theme === 'dark' ? 'img/LumeEscuro.png' : 'img/Lume.png';

  if (loginLogo) loginLogo.src = logoSrc;
  if (appLogo) appLogo.src = logoSrc;

  if (theme === 'dark') { icon.innerHTML = ICON_SUN; text.textContent = 'Modo Claro'; }
  else { icon.innerHTML = ICON_MOON; text.textContent = 'Modo Escuro'; }
}
initTheme();

// ---------- HELPERS ----------
const $ = id => document.getElementById(id);
const nomeFilial = id => FILIAIS.find(f=>f.id===id)?.nome || '—';
const nomeProduto = id => produtos.find(p=>p.id===id)?.nome || '—';
const skuProduto = id => produtos.find(p=>p.id===id)?.sku || '—';
const minProduto = id => produtos.find(p=>p.id===id)?.qtd_minima || 0;

// Se o backend já enviar o status pronto (recomendado), use e.status em vez desta função.
function statusEstoque(qtd, min){
  if(qtd === 0) return 'zerado';
  if(qtd <= min) return 'baixo';
  return 'suficiente';
}
const STATUS_LABEL = {suficiente:'Suficiente', baixo:'Baixo', zerado:'Zerado'};

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
  const nomeInput = $('login-nome');
  const emailInput = $('login-email');
  const senhaInput = $('login-senha');
  const nome = nomeInput ? nomeInput.value.trim() : '';
  const email = emailInput ? emailInput.value.trim() : '';
  const senha = senhaInput ? senhaInput.value : '';

  if(!nome || !email || !senha){ toast('Nome, e-mail e senha são obrigatórios.', true); return; }

  try {
    let resposta = null;

    // Tentar autenticar via cliente Supabase se disponível
    const client = window.supabaseClient || (typeof window.initSupabase === 'function' ? window.initSupabase() : null);
    if (client) {
      const { data, error } = await client
        .from('usuarios')
        .select('*')
        .ilike('email', email)
        .limit(1);

      if (!error && data && data.length > 0) {
        const u = data[0];
        // Validar nome (case-insensitive) e senha
        const nomeValido = u.nome && u.nome.trim().toLowerCase() === nome.toLowerCase();
        const senhaValida = u.senha && u.senha === senha;

        if (nomeValido && senhaValida) {
          const cargo = (u.cargo || u.tipo || 'funcionario').toLowerCase();
          resposta = {
            id: u.id,
            nome: u.nome,
            email: u.email,
            cargo: cargo,
            tipo: cargo,
            filial_id: u.filial_id ?? u.filialId ?? (cargo === 'gerente' ? null : 1)
          };
        }
      }
    }

    // Se o Supabase direto não retornou resposta, fallback para MOCK_USUARIOS (GitHub Pages estático)
    if (!resposta) {
      const mock = MOCK_USUARIOS.find(u =>
        u.nome.toLowerCase() === nome.toLowerCase() &&
        u.email.toLowerCase() === email.toLowerCase() &&
        u.senha === senha
      );
      if (mock) {
        resposta = { id: mock.id, nome: mock.nome, email: mock.email, cargo: mock.cargo, tipo: mock.tipo, filial_id: mock.filial_id };
      }
    }

    if (!resposta) {
      throw new Error('Acesso negado. Credenciais inválidas.');
    }

    aplicarLogin(resposta);
  } catch (err) {
    toast(err.message || 'Acesso negado. Credenciais inválidas.', true);
  }
}

// Atalho para testar o layout sem o backend rodando ainda.
function simularLogin(tipo){
  const nomeInput = $('login-nome') ? $('login-nome').value.trim() : '';
  const nome = nomeInput || (tipo === 'gerente' ? 'Gerente' : 'Funcionário');
  aplicarLogin(tipo === 'gerente'
    ? {nome, tipo:'gerente', cargo:'gerente', filial_id:null}
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

  // Persistir sessão do usuário no localStorage
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
  irPara('dashboard');
}

function sair(){
  usuario = null;
  localStorage.removeItem('lume_usuario');
  const appScreen = $('app');
  if (appScreen) appScreen.classList.remove('active');

  const loginScreen = $('login-screen');
  if (loginScreen) loginScreen.style.display = 'flex';
}

function verificarSessaoAtiva(){
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
    // Fallback local apenas para o protótipo funcionar sem backend.
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
  const html = vis.map(f=>`<button onclick="setFilialDash(${f.id},this)">${f.nome.replace('Filial ','')}</button>`).join('');
  const dashF = $('dash-filiais');
  if (dashF) dashF.innerHTML = `<button class="on" onclick="setFilialDash(null,this)">${usuario.tipo==='gerente'?'Todas':'Minha filial'}</button>` + html;

  const estF = $('estoque-filiais');
  if (estF) estF.innerHTML = `<button class="on" onclick="setFilialEstoque(null,this)">${usuario.tipo==='gerente'?'Todas':'Minha filial'}</button>` + html;

  const histF = $('hist-filial');
  if (histF) {
    histF.innerHTML = '<option value="">Todas as filiais</option>' +
      vis.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');
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
    // Ideal: o backend já devolve os KPIs calculados e os dados dos gráficos prontos.
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
  const fid = filialDashSel;
  const kpis = $('dash-kpis');
  if (kpis) {
    kpis.innerHTML = `
      <div class="card kpi"><span class="label">Itens em estoque</span><span class="value">${dados.totalItens ?? 0}</span><span class="badge info">${fid?nomeFilial(fid):'5 filiais'}</span></div>
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

  const porFilial = dados.estoquePorFilial || []; // [{nome, total}]
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
                <td><b>${e.produtoNome ?? nomeProduto(e.produto_id)}</b></td>
                <td>${e.filialNome ?? nomeFilial(e.filial_id)}</td>
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

  let html = '';
  produtos
    .filter(p => p.nome.toLowerCase().includes(busca) || p.sku.toLowerCase().includes(busca))
    .forEach(p => {
      estoques.filter(e => e.produto_id === p.id).forEach(e => {
        const status = e.status ?? statusEstoque(e.quantidade, p.qtd_minima);
        if(st && status !== st) return;
        html += `
          <tr>
            <td><code>${p.sku}</code></td>
            <td><b>${p.nome}</b></td>
            <td>${p.categoria}</td>
            <td>${p.qtd_minima}</td>
            <td>${nomeFilial(e.filial_id)}</td>
            <td>${e.quantidade}</td>
            <td><span class="badge ${status==='zerado'?'danger':status==='baixo'?'warn':'ok'}">${STATUS_LABEL[status]}</span></td>
            <td><button class="btn-sm btn-secondary" onclick="abrirModalAjuste(${p.id}, ${e.filial_id})">Ajustar</button></td>
          </tr>`;
      });
    });
  tb.innerHTML = html || '<tr><td colspan="8" class="empty-state">Nenhum produto encontrado.</td></tr>';
}
function renderProdutosFiltro(){ pintarProdutos(); } // usado nos oninput/onchange da tela

function abrirModalProduto(){
  const overlay = $('modal-overlay');
  const modalP = $('modal-produto');
  if (overlay) overlay.classList.add('active');
  if (modalP) modalP.style.display = 'block';
}

async function salvarProduto(){
  const nome = $('p-nome') ? $('p-nome').value.trim() : '';
  const sku = $('p-sku') ? $('p-sku').value.trim() : '';
  const categoria = $('p-cat') ? $('p-cat').value.trim() : '';
  const qtd_minima = parseInt($('p-min') ? $('p-min').value : 0) || 0;
  const qtd_inicial = parseInt($('p-qtd') ? $('p-qtd').value : 0) || 0;

  if(!nome || !sku){ toast('Preencha Nome e SKU.', true); return; }

  try {
    await api.criarProduto({ nome, sku, categoria, qtd_minima, qtd_inicial });
    fecharModal();
    toast('Produto adicionado com sucesso!');
    renderProdutos();
  } catch (err) {
    toast(err.message || 'Não foi possível salvar o produto.', true);
  }
}

// ---------- ESTOQUE ----------
async function renderEstoque(){
  mostrarLoading($('tbody-estoque'));
  try {
    estoques = await api.listarEstoque(filialEstoqueSel);
    if(produtos.length === 0) produtos = await api.listarProdutos();
    pintarEstoque();
  } catch (err) {
    const tb = $('tbody-estoque');
    if (tb) tb.innerHTML = '<tr><td colspan="6" class="empty-state">Não foi possível carregar o estoque.</td></tr>';
  }
}

function pintarEstoque(){
  const tb = $('tbody-estoque');
  if (!tb) return;

  if(estoques.length === 0){
    tb.innerHTML = '<tr><td colspan="6" class="empty-state">Nenhum produto cadastrado ainda.</td></tr>';
    return;
  }
  tb.innerHTML = estoques.map(e => {
    const p = produtos.find(prd => prd.id === e.produto_id) || {};
    const st = e.status ?? statusEstoque(e.quantidade, p.qtd_minima);
    return `
      <tr>
        <td><code>${p.sku ?? '—'}</code></td>
        <td><b>${p.nome ?? '—'}</b></td>
        <td>${e.quantidade}</td>
        <td>${p.qtd_minima ?? '—'}</td>
        <td><span class="badge ${st==='zerado'?'danger':st==='baixo'?'warn':'ok'}">${STATUS_LABEL[st]}</span></td>
        <td><button class="btn-sm btn-secondary" onclick="abrirModalAjuste(${e.produto_id}, ${e.filial_id})">Ajustar</button></td>
      </tr>`;
  }).join('');
}

function abrirModalAjuste(pid, fid){
  ajusteTarget = {pid, fid};
  const titulo = $('ajuste-titulo');
  if (titulo) titulo.textContent = `Ajustar: ${nomeProduto(pid)} (${nomeFilial(fid)})`;

  const overlay = $('modal-overlay');
  const modalA = $('modal-ajuste');
  if (overlay) overlay.classList.add('active');
  if (modalA) modalA.style.display = 'block';
}

async function salvarAjuste(){
  const tipo = $('a-tipo') ? $('a-tipo').value : 'entrada';
  const quantidade = parseInt($('a-qtd') ? $('a-qtd').value : 0) || 0;
  const motivo = $('a-motivo') ? $('a-motivo').value.trim() : '';

  if(quantidade <= 0){ toast('Informe uma quantidade válida.', true); return; }

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
    : transferencias.map(t => `
      <tr>
        <td>#${t.id}</td>
        <td><b>${t.produtoNome ?? nomeProduto(t.produto_id)}</b></td>
        <td>${t.origemNome ?? nomeFilial(t.origem_id)}</td>
        <td>${t.destinoNome ?? nomeFilial(t.destino_id)}</td>
        <td>${t.quantidade}</td>
        <td>${t.solicitante}</td>
        <td>${t.data}</td>
        <td><span class="badge ${t.status==='concluida'?'ok':'info'}">${t.status}</span></td>
        <td>${t.status==='pendente' ? `<button class="btn-sm btn-primary" onclick="concluirTransf(${t.id})">Concluir</button>` : '—'}</td>
      </tr>
    `).join('');
}

async function abrirModalTransferencia(){
  try {
    if(produtos.length === 0) produtos = await api.listarProdutos();
  } catch (err) {
    toast('Não foi possível carregar os produtos.', true);
    return;
  }
  if(produtos.length === 0){ toast('Cadastre ao menos um produto antes de transferir.', true); return; }

  const tp = $('t-produto');
  if (tp) tp.innerHTML = produtos.map(p=>`<option value="${p.id}">${p.nome}</option>`).join('');

  const to = $('t-origem');
  if (to) to.innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');

  const td = $('t-destino');
  if (td) td.innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');

  const overlay = $('modal-overlay');
  const modalT = $('modal-transferencia');
  if (overlay) overlay.classList.add('active');
  if (modalT) modalT.style.display = 'block';
}

async function salvarTransferencia(){
  const produtoId = parseInt($('t-produto') ? $('t-produto').value : 0);
  const origemId = parseInt($('t-origem') ? $('t-origem').value : 0);
  const destinoId = parseInt($('t-destino') ? $('t-destino').value : 0);
  const quantidade = parseInt($('t-qtd') ? $('t-qtd').value : 0) || 0;

  if(origemId === destinoId){ toast('Origem e Destino devem ser diferentes.', true); return; }

  try {
    await api.criarTransferencia({ produtoId, origemId, destinoId, quantidade, solicitante: usuario ? usuario.nome : 'Usuário' });
    fecharModal();
    toast('Transferência solicitada!');
    renderTransferencias();
  } catch (err) {
    toast(err.message || 'Não foi possível solicitar a transferência.', true);
  }
}

async function concluirTransf(id){
  try {
    await api.concluirTransferencia(id);
    toast('Transferência concluída!');
    renderTransferencias();
  } catch (err) {
    toast(err.message || 'Não foi possível concluir a transferência.', true);
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
    if (tb) tb.innerHTML = '<tr><td colspan="7" class="empty-state">Não foi possível carregar os pedidos.</td></tr>';
  }
}

function pintarPedidos(){
  const tb = $('tbody-pedidos');
  if (!tb) return;

  tb.innerHTML = pedidos.length === 0
    ? '<tr><td colspan="7" class="empty-state">Nenhum pedido de compra.</td></tr>'
    : pedidos.map(p => `
      <tr>
        <td>#${p.id}</td>
        <td><b>${p.produtoNome ?? nomeProduto(p.produto_id)}</b></td>
        <td>${p.quantidade}</td>
        <td>${p.filialNome ?? nomeFilial(p.filial_id)}</td>
        <td>${p.solicitante}</td>
        <td>${p.data}</td>
        <td><span class="badge info">${p.status}</span></td>
      </tr>
    `).join('');
}

async function abrirModalPedido(){
  try {
    if(produtos.length === 0) produtos = await api.listarProdutos();
  } catch (err) {
    toast('Não foi possível carregar os produtos.', true);
    return;
  }
  if(produtos.length === 0){ toast('Cadastre ao menos um produto antes de criar um pedido.', true); return; }

  const pcp = $('pc-produto');
  if (pcp) pcp.innerHTML = produtos.map(p=>`<option value="${p.id}">${p.nome}</option>`).join('');

  const pcf = $('pc-filial');
  if (pcf) pcf.innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');

  const overlay = $('modal-overlay');
  const modalP = $('modal-pedido');
  if (overlay) overlay.classList.add('active');
  if (modalP) modalP.style.display = 'block';
}

async function salvarPedido(){
  const produtoId = parseInt($('pc-produto') ? $('pc-produto').value : 0);
  const filialId = parseInt($('pc-filial') ? $('pc-filial').value : 0);
  const quantidade = parseInt($('pc-qtd') ? $('pc-qtd').value : 0) || 0;

  try {
    await api.criarPedido({ produtoId, filialId, quantidade, solicitante: usuario ? usuario.nome : 'Usuário' });
    fecharModal();
    toast('Pedido de compra criado!');
    renderPedidos();
  } catch (err) {
    toast(err.message || 'Não foi possível criar o pedido.', true);
  }
}

// ---------- ALERTAS ----------
async function renderAlertas(){
  mostrarLoading($('tbody-alertas'));
  try {
    const dados = await api.listarAlertas();
    // Espera-se { totalBaixo, totalZerado, itens: [...] }
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
            <td><code>${e.sku ?? skuProduto(e.produto_id)}</code></td>
            <td><b>${e.produtoNome ?? nomeProduto(e.produto_id)}</b></td>
            <td>${e.filialNome ?? nomeFilial(e.filial_id)}</td>
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
            <td>${m.data}</td>
            <td><b>${m.produtoNome ?? nomeProduto(m.produto_id)}</b></td>
            <td>${m.filialNome ?? nomeFilial(m.filial_id)}</td>
            <td><span class="badge ${m.tipo==='entrada'?'ok':'warn'}">${m.tipo}</span></td>
            <td>${m.anterior}</td>
            <td>${m.nova}</td>
            <td>${m.usuario}</td>
            <td>${m.motivo}</td>
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
