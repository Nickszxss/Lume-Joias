/* =====================================================================
   SGE — Protótipo de Frontend
   Todos os dados abaixo são SIMULADOS apenas para visualização.
   Em produção, o backend Java (Spring) fornece via REST:
   autenticação JWT, regras de RBAC (gerente/funcionário),
   cálculo de status (suficiente/baixo/zerado), validação de
   transferências, pedidos de compra e agregações dos relatórios.
   ===================================================================== */

const FILIAIS = [
  {id:1, nome:'Filial Centro'},
  {id:2, nome:'Filial Norte'},
  {id:3, nome:'Filial Sul'},
  {id:4, nome:'Filial Leste'},
  {id:5, nome:'Filial Oeste'},
];

// estado simulado
let usuario = null; // {nome, tipo, filial_id}
let produtos = [
  {id:1, sku:'PRD-001', nome:'Água Mineral 500ml', categoria:'Bebidas', qtd_minima:20},
  {id:2, sku:'PRD-002', nome:'Refrigerante Cola 2L', categoria:'Bebidas', qtd_minima:15},
  {id:3, sku:'PRD-003', nome:'Arroz Branco 5kg', categoria:'Alimentos', qtd_minima:10},
  {id:4, sku:'PRD-004', nome:'Feijão Carioca 1kg', categoria:'Alimentos', qtd_minima:10},
  {id:5, sku:'PRD-005', nome:'Sabão em Pó 800g', categoria:'Limpeza', qtd_minima:8},
  {id:6, sku:'PRD-006', nome:'Detergente 500ml', categoria:'Limpeza', qtd_minima:12},
];
let estoques = []; // {produto_id, filial_id, quantidade}
let movimentacoes = []; // {data, produto_id, filial_id, tipo, anterior, nova, usuario, motivo}
let transferencias = []; // {id, produto_id, origem_id, destino_id, quantidade, solicitante, data, status}
let pedidos = []; // {id, produto_id, quantidade, filial_id, solicitante, data, status}

// semeia estoques simulados
produtos.forEach(p=>{
  FILIAIS.forEach(f=>{
    const q = Math.floor(Math.random()*40);
    estoques.push({produto_id:p.id, filial_id:f.id, quantidade:q});
  });
});
// garante alguns alertas
estoques[1].quantidade = 4;  // baixo
estoques[7].quantidade = 0;  // zerado
estoques[13].quantidade = 3; // baixo
estoques[22].quantidade = 0; // zerado

let proxIdTransf = 1, proxIdPedido = 1;
let chartFilial = null, chartMov = null;

// ---------- helpers ----------
const $ = id => document.getElementById(id);
const nomeFilial = id => FILIAIS.find(f=>f.id===id)?.nome || '—';
const nomeProduto = id => produtos.find(p=>p.id===id)?.nome || '—';
const skuProduto = id => produtos.find(p=>p.id===id)?.sku || '—';
const minProduto = id => produtos.find(p=>p.id===id)?.qtd_minima || 0;

function statusEstoque(qtd, min){ // espelha trigger SQL do backend
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
  // RF-03 / RF-04 / RF-05 / RNF-18: regra aplicada pelo backend; aqui só simula
  return usuario.tipo === 'gerente' ? FILIAIS : FILIAIS.filter(f=>f.id===usuario.filial_id);
}

// ---------- login ----------
function fazerLogin(){
  const email = $('login-email').value.trim();
  if(!email){ toast('Informe o e-mail (protótipo: use os links de simulação).', true); return; }
  simularLogin(email.includes('gerente') ? 'gerente' : 'funcionario');
}
function simularLogin(tipo){
  usuario = tipo === 'gerente'
    ? {nome:'Carla Gerente', tipo:'gerente', filial_id:null}
    : {nome:'João Silva', tipo:'funcionario', filial_id:1};
  $('login-screen').style.display = 'none';
  $('app').classList.add('active');
  $('user-nome').textContent = usuario.nome;
  $('user-tipo').textContent = (tipo==='gerente'?'Gerente — todas as filiais':`Funcionário — ${nomeFilial(usuario.filial_id)}`)
    + ` · ${tipo}`;
  $('user-initial').textContent = usuario.nome[0];
  // RNF-17: funcionário não cria pedidos (botão desabilitado)
  const btnPedido = $('btn-novo-pedido');
  btnPedido.disabled = tipo !== 'gerente';
  btnPedido.title = tipo !== 'gerente' ? 'Apenas gerentes criam pedidos de compra (RNF-17)' : '';
  $('pedidos-desc').textContent = tipo !== 'gerente'
    ? 'Somente gerentes podem criar pedidos (você está em modo de visualização)'
    : 'Criados manualmente pelo gerente para reposição';
  $('dash-desc').textContent = tipo === 'gerente'
    ? 'Visão geral das 5 filiais'
    : `Visão da sua filial: ${nomeFilial(usuario.filial_id)}`;
  montarFiltros();
  irPara('dashboard');
}
function sair(){
  usuario = null;
  $('app').classList.remove('active');
  $('login-screen').style.display = 'flex';
}

// ---------- navegação ----------
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

// ---------- filtros de filial (simula RF-03/RF-04) ----------
function montarFiltros(){
  const vis = filiaisVisiveis();
  const html = vis.map(f=>`<button onclick="setFilialDash(${f.id},this)">${f.nome.replace('Filial ','')}</button>`).join('');
  $('dash-filiais').innerHTML = `<button class="on" onclick="setFilialDash(null,this)">${usuario.tipo==='gerente'?'Todas':'Minha filial'}</button>` + html;
  $('estoque-filiais').innerHTML = `<button class="on" onclick="setFilialEstoque(null,this)">${usuario.tipo==='gerente'?'Todas':'Minha filial'}</button>` + html;
  $('hist-filial').innerHTML = '<option value="">Todas as filiais</option>' +
    vis.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');
}
let filialDashSel = null, filialEstoqueSel = null;
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
function renderDashboard(){
  const fid = filialDashSel;
  const ests = estoques.filter(e=>!fid || e.filial_id===fid);
  const totalItens = ests.reduce((s,e)=>s+e.quantidade,0);
  const baixos = ests.filter(e=>statusEstoque(e.quantidade, minProduto(e.produto_id))==='baixo').length;
  const zerados = ests.filter(e=>e.quantidade===0).length;
  const pendentes = transferencias.filter(t=>t.status==='pendente' && (!fid || t.origem_id===fid || t.destino_id===fid)).length;

  $('dash-kpis').innerHTML = `
    <div class="card kpi"><span class="label">Itens em estoque</span><span class="value">${totalItens}</span><span class="badge info">${fid?nomeFilial(fid):'5 filiais'}</span></div>
    <div class="card kpi"><span class="label">Produtos cadastrados</span><span class="value">${produtos.length}</span><span class="badge ok">ativos</span></div>
    <div class="card kpi"><span class="label">Estoque baixo</span><span class="value" style="color:var(--warn)">${baixos}</span><span class="badge warn">atenção</span></div>
    <div class="card kpi"><span class="label">Estoque zerado</span><span class="value" style="color:var(--danger)">${zerados}</span><span class="badge danger">urgente</span></div>
    <div class="card kpi"><span class="label">Transferências pendentes</span><span class="value" style="color:var(--purple)">${pendentes}</span><span class="badge info">aguardando</span></div>`;

  // gráfico: estoque por filial
  const dadosPorFilial = FILIAIS.filter(f=>!fid || f.id===fid).map(f=>({
    nome:f.nome.replace('Filial ',''),
    total:estoques.filter(e=>e.filial_id===f.id).reduce((s,e)=>s+e.quantidade,0)
  }));
  if(chartFilial) chartFilial.destroy();
  chartFilial = new Chart($('chart-estoque-filial'), {
    type:'bar',
    data:{labels:dadosPorFilial.map(d=>d.nome),
      datasets:[{label:'Itens',data:dadosPorFilial.map(d=>d.total),
        backgroundColor:['#38bdf8','#a78bfa','#22c55e','#f59e0b','#ef4444'],borderRadius:8}]},
    options:{responsive:true,maintainAspectRatio:false,
      plugins:{legend:{display:false}},
      scales:{x:{ticks:{color:'#94a3b8'},grid:{display:false}},y:{ticks:{color:'#94a3b8'},grid:{color:'#33415555'}}}}
  });

  // gráfico: movimentações últimos 7 dias (simulado)
  const dias=[...Array(7)].map((_,i)=>{const d=new Date();d.setDate(d.getDate()-(6-i));return d;});
  const entradas=dias.map(d=>movimentacoes.filter(m=>m.tipo==='entrada'&&new Date(m.data).toDateString()===d.toDateString()).reduce((s,m)=>s+(m.nova-m.anterior),0));
  const saidas=dias.map(d=>movimentacoes.filter(m=>m.tipo==='saida'&&new Date(m.data).toDateString()===d.toDateString()).reduce((s,m)=>s+(m.anterior-m.nova),0));
  if(chartMov) chartMov.destroy();
  chartMov = new Chart($('chart-movimentacoes'), {
    type:'line',
    data:{labels:dias.map(d=>d.toLocaleDateString('pt-BR',{day:'2-digit',month:'2-digit'})),
      datasets:[
        {label:'Entradas',data:entradas,borderColor:'#22c55e',backgroundColor:'#22c55e33',fill:true,tension:.35},
        {label:'Saídas',data:saidas,borderColor:'#ef4444',backgroundColor:'#ef444433',fill:true,tension:.35}]},
    options:{responsive:true,maintainAspectRatio:false,
      plugins:{legend:{labels:{color:'#e2e8f0'}}},
      scales:{x:{ticks:{color:'#94a3b8'},grid:{display:false}},y:{ticks:{color:'#94a3b8'},grid:{color:'#33415555'}}}}
  });

  // alertas no dashboard
  const alertas = ests.filter(e=>statusEstoque(e.quantidade,minProduto(e.produto_id))!=='suficiente').slice(0,6);
  $('dash-alertas').innerHTML = alertas.length ? `<table><thead><tr><th>Produto</th><th>Filial</th><th>Qtd.</th><th>Mín.</th><th>Status</th></tr></thead><tbody>${
    alertas.map(a=>`<tr><td>${nomeProduto(a.produto_id)}</td><td>${nomeFilial(a.filial_id)}</td><td>${a.quantidade}</td><td>${minProduto(a.produto_id)}</td><td><span class="pill ${statusEstoque(a.quantidade,minProduto(a.produto_id))}">${STATUS_LABEL[statusEstoque(a.quantidade,minProduto(a.produto_id))]}</span></td></tr>`).join('')
  }</tbody></table>` : `<div class="empty">✅ Nenhum alerta nesta seleção.</div>`;
}

// ---------- PRODUTOS ----------
function renderProdutos(){
  const busca = $('busca-produto').value.toLowerCase();
  const fs = $('filtro-status').value;
  const vis = filiaisVisiveis();
  let linhas = [];
  estoques.filter(e=>vis.some(f=>f.id===e.filial_id)).forEach(e=>{
    const p = produtos.find(p=>p.id===e.produto_id);
    if(busca && !p.nome.toLowerCase().includes(busca) && !p.sku.toLowerCase().includes(busca)) return;
    const st = statusEstoque(e.quantidade, p.qtd_minima);
    if(fs && st!==fs) return;
    linhas.push({p, e, st});
  });
  linhas.sort((a,b)=>a.p.sku.localeCompare(b.p.sku));
  $('tbody-produtos').innerHTML = linhas.length ? linhas.map(({p,e,st})=>`
    <tr>
      <td style="color:var(--muted)">${p.sku}</td>
      <td><b>${p.nome}</b></td>
      <td>${p.categoria}</td>
      <td>${p.qtd_minima}</td>
      <td>${nomeFilial(e.filial_id)}</td>
      <td><b>${e.quantidade}</b></td>
      <td><span class="pill ${st}">${STATUS_LABEL[st]}</span></td>
      <td><button class="btn-sm btn-outline" onclick="abrirModalAjuste(${p.id},${e.filial_id})">Ajustar</button></td>
    </tr>`).join('') : `<tr><td colspan="8"><div class="empty">Nenhum produto encontrado.</div></td></tr>`;
}

function abrirModalProduto(){
  $('p-nome').value=''; $('p-sku').value=''; $('p-cat').value=''; $('p-min').value=10; $('p-qtd').value=0;
  abrirModal('modal-produto');
}
function salvarProduto(){
  const nome=$('p-nome').value.trim(), sku=$('p-sku').value.trim(), cat=$('p-cat').value.trim();
  if(!nome||!sku){ toast('Preencha nome e SKU.', true); return; }
  const p = {id:Math.max(...produtos.map(p=>p.id))+1, sku, nome, categoria:cat||'Geral', qtd_minima:+$('p-min').value||0};
  produtos.push(p);
  filiaisVisiveis().forEach(f=>estoques.push({produto_id:p.id, filial_id:f.id, quantidade:0}));
  // estoque inicial na filial do usuário (ou Centro para gerente)
  const ef = getEstoque(p.id, usuario.filial_id || 1);
  ef.quantidade = +$('p-qtd').value||0;
  toast(`Produto "${nome}" cadastrado (simulação — o backend Java persiste).`);
  fecharModal(); renderProdutos();
}

// ---------- ESTOQUE / AJUSTES (RF-08/09/10) ----------
let ajusteCtx = null;
function renderEstoque(){
  const fid = filialEstoqueSel;
  const vis = filiaisVisiveis();
  const linhas = estoques.filter(e=>vis.some(f=>f.id===e.filial_id) && (!fid || e.filial_id===fid));
  $('tbody-estoque').innerHTML = linhas.length ? linhas.map(e=>{
    const p = produtos.find(p=>p.id===e.produto_id);
    const st = statusEstoque(e.quantidade, p.qtd_minima);
    return `<tr>
      <td style="color:var(--muted)">${p.sku}</td>
      <td><b>${p.nome}</b><br><small style="color:var(--muted)">${nomeFilial(e.filial_id)}</small></td>
      <td><b style="font-size:15px">${e.quantidade}</b></td>
      <td>${p.qtd_minima}</td>
      <td><span class="pill ${st}">${STATUS_LABEL[st]}</span></td>
      <td><button class="btn-sm btn-outline" onclick="abrirModalAjuste(${p.id},${e.filial_id})">Ajustar</button></td>
    </tr>`;
  }).join('') : `<tr><td colspan="6"><div class="empty">Nenhum item.</div></td></tr>`;
}
function abrirModalAjuste(pid, fid){
  ajusteCtx = {pid, fid};
  $('ajuste-titulo').textContent = `Ajustar: ${nomeProduto(pid)} — ${nomeFilial(fid)}`;
  $('a-qtd').value = 1; $('a-motivo').value='';
  abrirModal('modal-ajuste');
}
function salvarAjuste(){
  const qtd = +$('a-qtd').value;
  if(!qtd || qtd<1){ toast('Quantidade inválida.', true); return; }
  const tipo = $('a-tipo').value;
  const est = getEstoque(ajusteCtx.pid, ajusteCtx.fid);
  if(tipo==='saida' && est.quantidade < qtd){ toast('Quantidade insuficiente em estoque.', true); return; }
  const anterior = est.quantidade;
  est.quantidade = tipo==='entrada' ? anterior+qtd : anterior-qtd;
  movimentacoes.unshift({
    data:new Date().toISOString(), produto_id:ajusteCtx.pid, filial_id:ajusteCtx.fid,
    tipo, anterior, nova:est.quantidade, usuario:usuario.nome, motivo:$('a-motivo').value||'—'
  });
  toast(`Estoque atualizado: ${anterior} → ${est.quantidade}`);
  fecharModal(); renderEstoque(); renderProdutos();
}

// ---------- TRANSFERÊNCIAS (RF-15 a RF-20) ----------
function renderTransferencias(){
  $('tbody-transferencias').innerHTML = transferencias.length ? transferencias.map(t=>`
    <tr>
      <td style="color:var(--muted)">#${t.id}</td>
      <td><b>${nomeProduto(t.produto_id)}</b></td>
      <td>${nomeFilial(t.origem_id)}</td>
      <td>${nomeFilial(t.destino_id)}</td>
      <td>${t.quantidade}</td>
      <td>${t.solicitante}</td>
      <td>${new Date(t.data).toLocaleString('pt-BR')}</td>
      <td><span class="pill ${t.status==='pendente'?'pendente':'concluida'}">${t.status==='pendente'?'Pendente':'Concluída'}</span></td>
      <td>${t.status==='pendente' ? `<button class="btn-sm btn-success" onclick="concluirTransferencia(${t.id})">Concluir</button>` : '—'}</td>
    </tr>`).join('') : `<tr><td colspan="9"><div class="empty">Nenhuma transferência registrada.</div></td></tr>`;
}
function abrirModalTransferencia(){
  const opts = produtos.map(p=>`<option value="${p.id}">${p.sku} — ${p.nome}</option>`).join('');
  $('t-produto').innerHTML = opts;
  $('t-origem').innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');
  $('t-destino').innerHTML = FILIAIS.map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');
  $('t-destino').selectedIndex = 1;
  abrirModal('modal-transferencia');
}
function salvarTransferencia(){
  const pid=+$('t-produto').value, ori=+$('t-origem').value, des=+$('t-destino').value, qtd=+$('t-qtd').value;
  if(ori===des){ toast('Origem e destino devem ser diferentes.', true); return; }
  const est = getEstoque(pid, ori);
  if(!qtd || qtd<1){ toast('Quantidade inválida.', true); return; }
  if(est.quantidade < qtd){ toast(`Estoque insuficiente na ${nomeFilial(ori)}.`, true); return; }
  transferencias.unshift({
    id:proxIdTransf++, produto_id:pid, origem_id:ori, destino_id:des, quantidade:qtd,
    solicitante:usuario.nome, data:new Date().toISOString(), status:'pendente'
  });
  toast('Transferência solicitada (pendente de conclusão).');
  fecharModal(); renderTransferencias();
}
function concluirTransferencia(id){
  const t = transferencias.find(t=>t.id===id);
  const eo = getEstoque(t.produto_id, t.origem_id);
  const ed = getEstoque(t.produto_id, t.destino_id);
  if(eo.quantidade < t.quantidade){ toast('Estoque de origem já não permite concluir.', true); return; }
  const antO = eo.quantidade, antD = ed.quantidade;
  eo.quantidade -= t.quantidade;
  ed.quantidade += t.quantidade;
  // RF-20: gera 2 registros no histórico
  movimentacoes.unshift({data:new Date().toISOString(), produto_id:t.produto_id, filial_id:t.origem_id,
    tipo:'transferencia', anterior:antO, nova:eo.quantidade, usuario:usuario.nome, motivo:`Transferência #${id} → ${nomeFilial(t.destino_id)}`});
  movimentacoes.unshift({data:new Date().toISOString(), produto_id:t.produto_id, filial_id:t.destino_id,
    tipo:'transferencia', anterior:antD, nova:ed.quantidade, usuario:usuario.nome, motivo:`Transferência #${id} ← ${nomeFilial(t.origem_id)}`});
  t.status = 'concluida';
  toast(`Transferência #${id} concluída.`);
  renderTransferencias();
}

// ---------- PEDIDOS (RF-21/22/23, RNF-17) ----------
function renderPedidos(){
  $('tbody-pedidos').innerHTML = pedidos.length ? pedidos.map(p=>`
    <tr>
      <td style="color:var(--muted)">#${p.id}</td>
      <td><b>${nomeProduto(p.produto_id)}</b></td>
      <td>${p.quantidade}</td>
      <td>${nomeFilial(p.filial_id)}</td>
      <td>${p.solicitante}</td>
      <td>${new Date(p.data).toLocaleString('pt-BR')}</td>
      <td><span class="pill pendente">Aberto</span></td>
    </tr>`).join('') : `<tr><td colspan="7"><div class="empty">Nenhum pedido de compra criado.</div></td></tr>`;
}
function abrirModalPedido(){
  if(usuario.tipo!=='gerente'){ toast('Somente gerentes criam pedidos de compra.', true); return; }
  $('pc-produto').innerHTML = produtos.map(p=>`<option value="${p.id}">${p.sku} — ${p.nome}</option>`).join('');
  $('pc-filial').innerHTML = filiaisVisiveis().map(f=>`<option value="${f.id}">${f.nome}</option>`).join('');
  abrirModal('modal-pedido');
}
function salvarPedido(){
  const qtd = +$('pc-qtd').value;
  if(!qtd || qtd<1){ toast('Quantidade inválida.', true); return; }
  pedidos.unshift({
    id:proxIdPedido++, produto_id:+$('pc-produto').value, quantidade:qtd,
    filial_id:+$('pc-filial').value, solicitante:usuario.nome, data:new Date().toISOString(), status:'aberto'
  });
  toast('Pedido de compra criado (registro interno, sem envio automático a fornecedores).');
  fecharModal(); renderPedidos();
}

// ---------- ALERTAS (RF-23) ----------
function renderAlertas(){
  const vis = filiaisVisiveis();
  const itens = estoques
    .filter(e=>vis.some(f=>f.id===e.filial_id))
    .map(e=>({e, st:statusEstoque(e.quantidade, minProduto(e.produto_id))}))
    .filter(x=>x.st!=='suficiente');
  const nBaixo = itens.filter(x=>x.st==='baixo').length;
  const nZero = itens.filter(x=>x.st==='zerado').length;
  $('alertas-kpis').innerHTML = `
    <div class="card kpi"><span class="label">Total de alertas</span><span class="value">${itens.length}</span><span class="badge warn">revisar</span></div>
    <div class="card kpi"><span class="label">Estoque baixo</span><span class="value" style="color:var(--warn)">${nBaixo}</span><span class="badge warn">abaixo do mínimo</span></div>
    <div class="card kpi"><span class="label">Estoque zerado</span><span class="value" style="color:var(--danger)">${nZero}</span><span class="badge danger">reposição urgente</span></div>`;
  $('tbody-alertas').innerHTML = itens.length ? itens.map(({e,st})=>`
    <tr>
      <td style="color:var(--muted)">${skuProduto(e.produto_id)}</td>
      <td><b>${nomeProduto(e.produto_id)}</b></td>
      <td>${nomeFilial(e.filial_id)}</td>
      <td><b style="font-size:15px;color:${st==='zerado'?'var(--danger)':'var(--warn)'}">${e.quantidade}</b></td>
      <td>${minProduto(e.produto_id)}</td>
      <td><span class="pill ${st}">${STATUS_LABEL[st]}</span></td>
      <td>${usuario.tipo==='gerente' ? `<button class="btn-sm btn-purple" onclick="pedidoRapido(${e.produto_id},${e.filial_id})">Criar pedido</button>` : '<small style="color:var(--muted)">avisar gerente</small>'}</td>
    </tr>`).join('') : `<tr><td colspan="7"><div class="empty">✅ Todos os estoques estão suficientes.</div></td></tr>`;
}
function pedidoRapido(pid, fid){
  pedidos.unshift({id:proxIdPedido++, produto_id:pid, quantidade:minProduto(pid)*2,
    filial_id:fid, solicitante:usuario.nome, data:new Date().toISOString(), status:'aberto'});
  toast(`Pedido criado para reposição de ${nomeProduto(pid)}.`);
}

// ---------- HISTÓRICO (RF-12/13/14) ----------
function renderHistorico(){
  const ft = $('hist-tipo').value, ff = +$('hist-filial').value || null;
  const vis = filiaisVisiveis();
  const lista = movimentacoes.filter(m=>
    vis.some(f=>f.id===m.filial_id) && (!ft || m.tipo===ft) && (!ff || m.filial_id===ff));
  const ICON = {entrada:'🟢', saida:'🔴', transferencia:'🟣'};
  $('tbody-historico').innerHTML = lista.length ? lista.map(m=>`
    <tr>
      <td style="color:var(--muted);white-space:nowrap">${new Date(m.data).toLocaleString('pt-BR')}</td>
      <td><b>${nomeProduto(m.produto_id)}</b></td>
      <td>${nomeFilial(m.filial_id)}</td>
      <td>${ICON[m.tipo]||''} ${m.tipo}</td>
      <td>${m.anterior}</td>
      <td><b>${m.nova}</b></td>
      <td>${m.usuario}</td>
      <td style="color:var(--muted)">${m.motivo}</td>
    </tr>`).join('') : `<tr><td colspan="8"><div class="empty">Nenhuma movimentação registrada.</div></td></tr>`;
}

// ---------- modais ----------
function abrirModal(id){
  $('modal-overlay').classList.add('open');
  document.querySelectorAll('.modal').forEach(m=>m.style.display='none');
  $(id).style.display='block';
}
function fecharModal(){ $('modal-overlay').classList.remove('open'); }