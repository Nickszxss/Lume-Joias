/* =====================================================================
   SGE — Camada de Front-end (visualização + interação)
   Toda a lógica de negócio e persistência fica no backend Java + Supabase.
   Este arquivo apenas consome a API e atualiza a tela.
   ===================================================================== */

// ---------- CONFIGURAÇÃO DA API ----------
// Ajuste para a URL real do seu backend Java quando estiver disponível.
const API_BASE_URL = 'http://localhost:8080/api';

// Wrapper único de fetch: centraliza headers, tratamento de erro e JSON.
async function apiRequest(path, options = {}) {
  const res = await fetch(`${API_BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...options
  });

  if (!res.ok) {
    let msg = `Erro ${res.status}`;
    try { const body = await res.json(); msg = body.message || msg; } catch (_) {}
    throw new Error(msg);
  }

  if (res.status === 204) return null;
  return res.json();
}

// Endpoints — ajuste os caminhos conforme as rotas definidas no Java.
const api = {
  login:               (dados)          => apiRequest('/auth/login', { method: 'POST', body: JSON.stringify(dados) }),

  listarFiliais:       ()               => apiRequest('/filiais'),

  listarProdutos:      ()               => apiRequest('/produtos'),
  criarProduto:        (dados)          => apiRequest('/produtos', { method: 'POST', body: JSON.stringify(dados) }),

  listarEstoque:       (filialId)       => apiRequest(`/estoque${filialId ? `?filialId=${filialId}` : ''}`),
  ajustarEstoque:      (dados)          => apiRequest('/estoque/ajustar', { method: 'POST', body: JSON.stringify(dados) }),

  listarTransferencias:()               => apiRequest('/transferencias'),
  criarTransferencia:  (dados)          => apiRequest('/transferencias', { method: 'POST', body: JSON.stringify(dados) }),
  concluirTransferencia:(id)            => apiRequest(`/transferencias/${id}/concluir`, { method: 'PATCH' }),

  listarPedidos:       ()               => apiRequest('/pedidos'),
  criarPedido:         (dados)          => apiRequest('/pedidos', { method: 'POST', body: JSON.stringify(dados) }),

  listarAlertas:       ()               => apiRequest('/estoque/alertas'),
  listarHistorico:     (filtros = {})   => {
    const qs = new URLSearchParams(filtros).toString();
    return apiRequest(`/historico${qs ? `?${qs}` : ''}`);
  },
  resumoDashboard:     (filialId)       => apiRequest(`/dashboard${filialId ? `?filialId=${filialId}` : ''}`),
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
  el.innerHTML = '<tr><td colspan="10" class="empty-state">Carregando...</td></tr>';
}

// ---------- LOGIN ----------
async function fazerLogin(){
  const nome = $('login-nome') ? $('login-nome').value.trim() : '';
  const email = $('login-email').value.trim();
  const senha = $('login-senha').value;
  if(!email || !senha){ toast('Preencha e-mail e senha.', true); return; }

  try {
    const resposta = await api.login({ email, senha, nome });
    // Espera-se que o backend retorne algo como:
    // { nome, tipo: 'gerente' | 'funcionario', filialId }
    if (nome) resposta.nome = nome;
    aplicarLogin(resposta);
  } catch (err) {
    toast(err.message || 'Não foi possível entrar. Verifique suas credenciais.', true);
  }
}

// Atalho para testar o layout sem o backend rodando ainda.
function simularLogin(tipo){
  const nomeInput = $('login-nome') ? $('login-nome').value.trim() : '';
  const nome = nomeInput || (tipo === 'gerente' ? 'Gerente' : 'Funcionário');
  aplicarLogin(tipo === 'gerente'
    ? {nome, tipo:'gerente', filial_id:null}
    : {nome, tipo:'funcionario', filial_id:1});
}

async function aplicarLogin(dadosUsuario){
  usuario = dadosUsuario;
  $('login-screen').style.display = 'none';
  $('app').classList.add('active');
  $('user-nome').textContent = usuario.nome || '';
  $('user-tipo').textContent = usuario.tipo === 'gerente' ? 'Gerente' : 'Funcionário';
  $('user-initial').textContent = usuario.nome ? usuario.nome[0].toUpperCase() : (usuario.tipo === 'gerente' ? 'G' : 'F');

  const btnPedido = $('btn-novo-pedido');
  btnPedido.disabled = usuario.tipo !== 'gerente';
  btnPedido.title = usuario.tipo !== 'gerente' ? 'Apenas gerentes criam pedidos de compra' : '';
  $('pedidos-desc').textContent = usuario.tipo !== 'gerente'
    ? 'Somente gerentes podem criar pedidos (você está em modo de visualização)'
    : 'Criados manualmente pelo gerente para reposição';
  $('dash-desc').textContent = usuario.tipo === 'gerente'
    ? 'Visão geral das 5 filiais'
    : `Visão da sua filial: ${nomeFilial(usuario.filial_id)}`;

  await carregarFiliais();
  montarFiltros();
  irPara('dashboard');
}

function sair(){
  usuario = null;
  $('app').classList.remove('active');
  $('login-screen').style.display = 'flex';
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
  $('page-'+page).classList.add('active');
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
  $('dash-filiais').innerHTML = `<button class="on" onclick="setFilialDash(null,this)">${usuario.tipo==='gerente'?'Todas':'Minha filial'}</button>` + html;
  $('estoque-filiais').innerHTML = `<button class="on" onclick="setFilialEstoque(null,this)">${usuario.tipo==='gerente'?'Todas':'Minha filial'}</button>` + html;
  $('hist-filial').innerHTML = '<option value="">Todas as filiais</option>' +
    vis.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');
}
function setFilialDash(id, btn){
  filialDashSel = id;
  $('dash-filiais').querySelectorAll('button').forEach(b=>b.classList.remove('on'));
  btn.classList.add('on');
  renderDashboard();
}
function setFilialEstoque(id, btn){
  filialEstoqueSel = id;
  $('estoque-filiais').querySelectorAll('button').forEach(b=>b.classList.remove('on'));
  btn.classList.add('on');
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
  $('dash-kpis').innerHTML = `
    <div class="card kpi"><span class="label">Itens em estoque</span><span class="value">${dados.totalItens ?? 0}</span><span class="badge info">${fid?nomeFilial(fid):'5 filiais'}</span></div>
    <div class="card kpi"><span class="label">Produtos cadastrados</span><span class="value">${dados.totalProdutos ?? produtos.length}</span><span class="badge ok">ativos</span></div>
    <div class="card kpi"><span class="label">Estoque baixo</span><span class="value" style="color:var(--warn-color)">${dados.totalBaixo ?? 0}</span><span class="badge warn">atenção</span></div>
    <div class="card kpi"><span class="label">Estoque zerado</span><span class="value" style="color:var(--danger-color)">${dados.totalZerado ?? 0}</span><span class="badge danger">urgente</span></div>
    <div class="card kpi"><span class="label">Transferências pendentes</span><span class="value" style="color:var(--rose-primary)">${dados.totalTransferenciasPendentes ?? 0}</span><span class="badge info">aguardando</span></div>`;
}

function pintarGraficos(dados){
  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  const textColor = isDark ? '#97979d' : '#6b6b6f';
  const gridColor = isDark ? '#2c2c3355' : '#e4e4e7';
  const roseColor = isDark ? '#c65b7e' : '#9d3b5c';

  const porFilial = dados.estoquePorFilial || []; // [{nome, total}]
  if(chartFilial) chartFilial.destroy();
  chartFilial = new Chart($('chart-estoque-filial'), {
    type:'bar',
    data:{ labels: porFilial.map(d=>d.nome),
      datasets:[{ label:'Itens', data: porFilial.map(d=>d.total), backgroundColor: roseColor, borderRadius:4 }] },
    options:{ responsive:true, maintainAspectRatio:false, plugins:{legend:{display:false}},
      scales:{ x:{ticks:{color:textColor}, grid:{display:false}}, y:{ticks:{color:textColor}, grid:{color:gridColor}} } }
  });

  const movimentacoesSemana = dados.movimentacoesSemana || { labels:[], entradas:[], saidas:[] };
  if(chartMov) chartMov.destroy();
  chartMov = new Chart($('chart-movimentacoes'), {
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

function pintarAlertasDashboard(alertas){
  $('dash-alertas').innerHTML = alertas.length === 0
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

// ---------- PRODUTOS ----------
async function renderProdutos(){
  mostrarLoading($('tbody-produtos'));
  try {
    produtos = await api.listarProdutos();
    estoques = await api.listarEstoque();
    pintarProdutos();
  } catch (err) {
    $('tbody-produtos').innerHTML = '<tr><td colspan="8" class="empty-state">Não foi possível carregar os produtos.</td></tr>';
  }
}

function pintarProdutos(){
  if(produtos.length === 0){
    $('tbody-produtos').innerHTML = '<tr><td colspan="8" class="empty-state">Nenhum produto cadastrado. Clique em "Novo Produto" para começar.</td></tr>';
    return;
  }

  const busca = $('busca-produto').value.toLowerCase();
  const st = $('filtro-status').value;

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
  $('tbody-produtos').innerHTML = html || '<tr><td colspan="8" class="empty-state">Nenhum produto encontrado.</td></tr>';
}
function renderProdutosFiltro(){ pintarProdutos(); } // usado nos oninput/onchange da tela

function abrirModalProduto(){
  $('modal-overlay').classList.add('active');
  $('modal-produto').style.display = 'block';
}

async function salvarProduto(){
  const nome = $('p-nome').value.trim();
  const sku = $('p-sku').value.trim();
  const categoria = $('p-cat').value.trim();
  const qtd_minima = parseInt($('p-min').value) || 0;
  const qtd_inicial = parseInt($('p-qtd').value) || 0;

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
    $('tbody-estoque').innerHTML = '<tr><td colspan="6" class="empty-state">Não foi possível carregar o estoque.</td></tr>';
  }
}

function pintarEstoque(){
  if(estoques.length === 0){
    $('tbody-estoque').innerHTML = '<tr><td colspan="6" class="empty-state">Nenhum produto cadastrado ainda.</td></tr>';
    return;
  }
  $('tbody-estoque').innerHTML = estoques.map(e => {
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
  $('ajuste-titulo').textContent = `Ajustar: ${nomeProduto(pid)} (${nomeFilial(fid)})`;
  $('modal-overlay').classList.add('active');
  $('modal-ajuste').style.display = 'block';
}

async function salvarAjuste(){
  const tipo = $('a-tipo').value;
  const quantidade = parseInt($('a-qtd').value) || 0;
  const motivo = $('a-motivo').value.trim();

  if(quantidade <= 0){ toast('Informe uma quantidade válida.', true); return; }

  try {
    await api.ajustarEstoque({
      produtoId: ajusteTarget.pid,
      filialId: ajusteTarget.fid,
      tipo, quantidade,
      motivo: motivo || 'Ajuste manual',
      usuario: usuario.nome
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
    $('tbody-transferencias').innerHTML = '<tr><td colspan="9" class="empty-state">Não foi possível carregar as transferências.</td></tr>';
  }
}

function pintarTransferencias(){
  $('tbody-transferencias').innerHTML = transferencias.length === 0
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

  $('t-produto').innerHTML = produtos.map(p=>`<option value="${p.id}">${p.nome}</option>`).join('');
  $('t-origem').innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');
  $('t-destino').innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');

  $('modal-overlay').classList.add('active');
  $('modal-transferencia').style.display = 'block';
}

async function salvarTransferencia(){
  const produtoId = parseInt($('t-produto').value);
  const origemId = parseInt($('t-origem').value);
  const destinoId = parseInt($('t-destino').value);
  const quantidade = parseInt($('t-qtd').value) || 0;

  if(origemId === destinoId){ toast('Origem e Destino devem ser diferentes.', true); return; }

  try {
    await api.criarTransferencia({ produtoId, origemId, destinoId, quantidade, solicitante: usuario.nome });
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
    $('tbody-pedidos').innerHTML = '<tr><td colspan="7" class="empty-state">Não foi possível carregar os pedidos.</td></tr>';
  }
}

function pintarPedidos(){
  $('tbody-pedidos').innerHTML = pedidos.length === 0
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

  $('pc-produto').innerHTML = produtos.map(p=>`<option value="${p.id}">${p.nome}</option>`).join('');
  $('pc-filial').innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');

  $('modal-overlay').classList.add('active');
  $('modal-pedido').style.display = 'block';
}

async function salvarPedido(){
  const produtoId = parseInt($('pc-produto').value);
  const filialId = parseInt($('pc-filial').value);
  const quantidade = parseInt($('pc-qtd').value) || 0;

  try {
    await api.criarPedido({ produtoId, filialId, quantidade, solicitante: usuario.nome });
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
    $('alertas-kpis').innerHTML = `
      <div class="card kpi"><span class="label">Estoque Baixo</span><span class="value" style="color:var(--warn-color)">${dados.totalBaixo ?? 0}</span></div>
      <div class="card kpi"><span class="label">Estoque Zerado</span><span class="value" style="color:var(--danger-color)">${dados.totalZerado ?? 0}</span></div>`;

    const itens = dados.itens || [];
    $('tbody-alertas').innerHTML = itens.length === 0
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
  } catch (err) {
    $('tbody-alertas').innerHTML = '<tr><td colspan="7" class="empty-state">Não foi possível carregar os alertas.</td></tr>';
  }
}

// ---------- HISTÓRICO ----------
async function renderHistorico(){
  mostrarLoading($('tbody-historico'));
  const tipo = $('hist-tipo').value;
  const filialId = $('hist-filial').value;

  try {
    movimentacoes = await api.listarHistorico({ ...(tipo && {tipo}), ...(filialId && {filialId}) });
    $('tbody-historico').innerHTML = movimentacoes.length === 0
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
  } catch (err) {
    $('tbody-historico').innerHTML = '<tr><td colspan="8" class="empty-state">Não foi possível carregar o histórico.</td></tr>';
  }
}

// ---------- FECHAR MODAIS ----------
function fecharModal(){
  $('modal-overlay').classList.remove('active');
  document.querySelectorAll('.modal').forEach(m => m.style.display = 'none');
}
