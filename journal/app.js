'use strict';
const $ = id => document.getElementById(id);
const titles = {overview:'Overview',accounts:'Accounts & allocations',strategies:'Strategies',journal:'Trade journal',imports:'Import centre',guide:'How to use'};
let state = null, selected = '', staged = [], page = 0, busy = false, stopped = false;
const fmt = (v, digits=2) => v === null || v === undefined ? '—' : Number(v).toLocaleString(undefined,{minimumFractionDigits:digits,maximumFractionDigits:digits});
const escapeHTML = v => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const e = escapeHTML;
function message(text, bad=false) { $('message').textContent=text; $('message').className=bad?'negative':'success'; }
async function api(path, data) {
  const response=await fetch(path,data===undefined?{}:{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
  const result=await response.json(); if(!response.ok) throw new Error(result.error||'Request failed'); return result;
}
function run(fn) { return async event => { if(event) event.preventDefault(); try {await fn(event);} catch(error){message(error.message,true);} }; }
function requireAccount(){if(!selected)throw new Error('Add and select an account / dataset first.');return selected;}
const account = () => state?.accounts.find(a=>a.id===selected);
const cash = v => `${fmt(v)} ${e(account()?.currency||'')}`;
const pf = m => m.profit_factor===null?(m.no_losses?'No losses': '—'):fmt(m.profit_factor);
const sign = v => v<0?'negative':v>0?'positive':'';
function table(headers, rows, empty='No records yet.') {
  return rows.length?`<table><thead><tr>${headers.map(h=>`<th>${e(h)}</th>`).join('')}</tr></thead><tbody>${rows.map(row=>`<tr>${row.map(cell=>`<td>${cell}</td>`).join('')}</tr>`).join('')}</tbody></table>`:`<p class="empty">${e(empty)}</p>`;
}
function navigate(){const screen=titles[location.hash.slice(1)]?location.hash.slice(1):'overview';for(const key of Object.keys(titles))$(key).hidden=key!==screen;$('title').textContent=titles[screen];document.querySelectorAll('nav a').forEach(a=>{if(a.hash===`#${screen}`)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current');});$('filters').hidden=!['overview','strategies','journal'].includes(screen);}
window.addEventListener('hashchange',navigate);
function query(){const params=new URLSearchParams();if(selected)params.set('account_id',selected);for(const [id,key] of [['strategy','strategy'],['config','config'],['from','start'],['to','end']])if($(id).value)params.set(key,$(id).value);return params;}
function fillSelect(id, values, placeholder){const before=$(id).value;$(id).innerHTML=`<option value="">${e(placeholder)}</option>`+values.map(v=>`<option value="${e(v)}">${e(v)}</option>`).join('');$(id).value=values.includes(before)?before:'';}
async function refresh(resetOptions=false){
  if(busy)return;busy=true;
  try{
    if($('from').value&&$('to').value&&$('from').value>$('to').value)throw new Error('From date must not be after To date.');
    state=await api('/api/state?'+query());
    if(!selected&&state.accounts.length){selected=state.accounts[0].id;state=await api('/api/state?'+query());}
    $('account').innerHTML=state.accounts.length?state.accounts.map(a=>`<option value="${e(a.id)}">${e(a.name)} · ${e(a.kind)}</option>`).join(''):'<option value="">Add an account to begin</option>';
    $('account').value=selected;
    if(resetOptions){fillSelect('strategy',[...new Set(state.trades.map(t=>t.strategy))].sort(),'All strategies');fillSelect('config',[...new Set(state.trades.map(t=>t.config))].sort(),'All configs');}
    render();
  }finally{busy=false;}
}
function render(){
  const m=state.metrics, a=account();
  const last=state.imports.find(i=>i.committed);$('updated').textContent=last?`Last successful import · ${last.time}`:'No successful CSV import yet';
  const entries=[['Net P&L',cash(m.net),'After reported costs'],['Closed trades',fmt(m.trades,0),'Selected account and date range'],['Win rate',m.win_rate===null?'—':fmt(m.win_rate,1)+'%','Net-positive trades'],['Expectancy',fmt(m.expectancy_r,3)+' R',`${m.r_count} / ${m.trades} trades with known risk`],['Profit factor',pf(m),'Net gains / net losses'],['Closed-trade DD',cash(m.max_dd),'No floating equity data'],['Closed-trade DD · R',fmt(m.max_dd_r)+' R','Only shown with complete risk data'],['Longest losing streak',fmt(m.losing_streak,0),'Based on imported exits']];
  $('metrics').innerHTML=entries.map(([title,value,detail])=>`<article><p>${e(title)}</p><h2>${value}</h2><small>${e(detail)}</small></article>`).join('');
  $('coverage').textContent=m.trades?`${state.trades[state.trades.length-1].closed.slice(0,10)} → ${state.trades[0].closed.slice(0,10)} · ${a.clock}`:'Add an account, then import your first report.';
  chart(m.curve);
  const periods=rows=>table(['Period','Trades','Net P&L','Win %','Avg R'],rows.map(r=>[e(r.period),fmt(r.trades,0),`<span class="${sign(r.net)}">${fmt(r.net)}</span>`,fmt(r.win_rate,1),fmt(r.expectancy_r,3)]));
  $('years').innerHTML=periods(state.years);$('months').innerHTML=periods([...state.months].reverse());
  $('account-cards').innerHTML=state.accounts.map(a=>`<article class="system"><div class="top"><h2>${e(a.name)}</h2><span class="badge">${e(a.kind)}</span></div><p>Reconstructed balance</p><h2>${fmt(a.reconstructed_balance)} ${e(a.currency)}</h2><p>Trading net ${fmt(a.net)} · Payouts ${fmt(a.payouts)} · Fees ${fmt(a.fees)}</p><p>Daily allowance ${fmt(a.daily_budget)} ${e(a.currency)}</p><p>${Object.entries(a.allocations).map(([g,p])=>`${g}: ${fmt(p,1)}% (${fmt(a.daily_budget*p/100)})`).join(' · ')}</p><p>Reserve ${fmt(100-Object.values(a.allocations).reduce((s,v)=>s+v,0),1)}%</p><p>${e(a.clock)}</p><p class="note">${e(a.notes)}</p><button class="secondary" data-edit-account="${e(a.id)}">Edit planning values</button></article>`).join('')||'<p class="empty">Add your first account below. This does not connect a broker.</p>';
  const portfolios={};for(const a of state.accounts){if(['Demo','Backtest'].includes(a.kind))continue;const p=portfolios[a.currency]??={net:0,payouts:0,fees:0};p.net+=a.net;p.payouts+=a.payouts;p.fees+=a.fees;}
  $('portfolio').innerHTML='<h2>Whole-system cash summary</h2>'+table(['Currency','Trading net','Payouts received','Fees paid','Payouts less fees'],Object.entries(portfolios).map(([currency,p])=>[e(currency),fmt(p.net),fmt(p.payouts),fmt(p.fees),fmt(p.payouts-p.fees)]))+'<p class="muted">Eval, funded and personal accounts only; demo/backtests excluded. Currencies are never added together. These are reported totals, not verified balances or combined live drawdown.</p>';
  $('system-cards').innerHTML=state.systems.map((s,i)=>`<article class="system"><div class="top"><h2>${e(s.strategy)}</h2><span class="grade">${e(s.note.grade||'Ungraded')}</span></div><p>Config ${e(s.config)} · ${e(s.note.status||'Unreviewed')}</p><h2 class="${sign(s.net)}">${fmt(s.net)} ${e(a?.currency||'')}</h2><p>${s.trades} trades · ${fmt(s.win_rate,1)}% wins · ${fmt(s.expectancy_r,3)} R / trade</p><p>PF ${pf(s)} · closed DD ${fmt(s.max_dd)} · ${fmt(s.max_dd_r)} R</p><p>Reference risk ${s.note.risk_percent===undefined||s.note.risk_percent===null?'not set':fmt(s.note.risk_percent)+'%'}</p><p class="note">${e(s.note.notes||'')}</p><button class="secondary" data-edit-strategy="${i}">Grade / notes</button></article>`).join('')||'<p class="empty">Import trades or register a research strategy below.</p>';
  renderTrades();
  $('flows').innerHTML='<h2>Cash-flow journal · selected account</h2>'+table(['Date','Type','Amount','Notes'],state.flows.sort((a,b)=>b.time.localeCompare(a.time)).map(f=>[e(f.time),e(f.kind),fmt(f.amount),e(f.notes)]));
  $('watches').innerHTML=state.watches.map(w=>`<section class="panel"><h3>${e(state.accounts.find(a=>a.id===w.account_id)?.name||w.account_id)}</h3><p>${e(w.path)} · ${e(w.pattern)}</p><p class="muted">${e(w.status)} · ${e(w.last_scan||'Not scanned yet')}</p><button class="secondary" data-watch="${e(w.id)}" data-enabled="${!w.enabled}">${w.enabled?'Pause imports':'Resume imports'}</button></section>`).join('');
  $('import-history').innerHTML=table(['When · UTC','File','Result','Details'],state.imports.map(i=>[e(i.time),e(i.filename),i.committed?`Imported ${i.new} · duplicates ${i.duplicates}`:'Blocked',e([...(i.errors||[]),...(i.conflicts||[]).map(c=>'Conflicting ID '+c),i.flagged?`${i.flagged} integrity-flagged rows`: '',i.skipped?`${i.skipped} open/non-final rows excluded`: ''].filter(Boolean).join('; '))]));
  $('signals').innerHTML=table(['Status','Reason','Count'],state.rejections.map(r=>[e(r.status),e(r.reason),fmt(r.count,0)]));
  $('storage').textContent='Saved locally: '+state.data_path;
  document.querySelectorAll('[data-edit-account]').forEach(b=>b.onclick=()=>editAccount(b.dataset.editAccount));
  document.querySelectorAll('[data-edit-strategy]').forEach(b=>b.onclick=()=>editStrategy(state.systems[Number(b.dataset.editStrategy)]));
  document.querySelectorAll('[data-watch]').forEach(b=>b.onclick=run(async()=>{await api('/api/watch-toggle',{id:b.dataset.watch,enabled:b.dataset.enabled==='true'});await refresh();}));
}
function chart(curve){
  if(!curve.length){$('curve').innerHTML='<text x="35" y="130" class="chart-label">Your closed-trade P&amp;L curve will appear after importing.</text>';return;}
  const vals=[0,...curve.map(p=>p.net)],low=vals.reduce((a,b)=>Math.min(a,b),0),high=vals.reduce((a,b)=>Math.max(a,b),0),span=high-low||1;
  const y=v=>220-(v-low)/span*190;
  // Bin long histories, keeping each bin's extrema so drawdown spikes remain visible.
  let points=vals.map((v,i)=>({i,v}));
  if(points.length>1800){const step=Math.ceil(points.length/600),sample=[];for(let i=0;i<points.length;i+=step){const block=points.slice(i,i+step);const min=block.reduce((a,b)=>a.v<b.v?a:b),max=block.reduce((a,b)=>a.v>b.v?a:b);for(const p of [block[0],min,max,block[block.length-1]].sort((a,b)=>a.i-b.i))if(sample.at(-1)?.i!==p.i)sample.push(p);}points=sample;}
  const d=points.map((p,index)=>`${index?'L':'M'}${100+p.i/Math.max(1,vals.length-1)*880},${y(p.v)}`).join(' ');
  $('curve').innerHTML=`<title>Cumulative net profit from ${curve.length} exit timestamps</title><line x1="100" x2="980" y1="${y(0)}" y2="${y(0)}" class="chart-grid"/><path d="${d}" class="chart-line"/><text x="0" y="35" class="chart-label">${e(fmt(high,0))}</text><text x="0" y="225" class="chart-label">${e(fmt(low,0))}</text><text x="100" y="252" class="chart-label">${e(curve[0].time.slice(0,10))}</text><text x="880" y="252" class="chart-label">${e(curve.at(-1).time.slice(0,10))}</text>`;
}
function renderTrades(){const trades=state.trades;const max=Math.max(0,Math.ceil(trades.length/50)-1);page=Math.min(page,max);$('trade-table').innerHTML=table(['Exit · report time','Trade ID','Strategy / config','Symbol','Side','Net P&L','Initial risk','Net R','Flags'],trades.slice(page*50,page*50+50).map(t=>[e(t.closed),e(t.trade_id),e(t.strategy)+'<br><small>'+e(t.config)+'</small>',e(t.symbol),e(t.direction),`<span class="${sign(t.net)}">${fmt(t.net)}</span>`,fmt(t.risk),fmt(t.r,3),e(t.flags)]));$('page-info').textContent=`Page ${page+1} / ${max+1} · ${trades.length} trades`;$('previous').disabled=page===0;$('next').disabled=page===max;}
function formData(id){return Object.fromEntries(new FormData($(id)));}
function populate(id,data){for(const [key,val]of Object.entries(data)){const input=$(id).elements.namedItem(key);if(input)input.value=val??'';}}
function editAccount(id){const a=state.accounts.find(a=>a.id===id);populate('account-form',{...a,grade_a:a.allocations.A,grade_b:a.allocations.B,grade_c:a.allocations.C});$('account-editor').open=true;$('account-editor').scrollIntoView({block:'start'});}
function editStrategy(s){populate('strategy-form',{strategy:s.strategy,config:s.config,grade:'Ungraded',status:'Research',risk_percent:'',notes:'',...s.note});$('strategy-editor').open=true;$('strategy-editor').scrollIntoView({block:'start'});}
$('account-form').onsubmit=run(async()=>{const d=formData('account-form');d.allocations={A:d.grade_a,B:d.grade_b,C:d.grade_c};const a=await api('/api/account',d);selected=a.id;clearFilters();await refresh(true);message('Account saved. Allocations are journal notes only.');});
$('new-account').onclick=()=>{$('account-form').reset();$('account-form').elements.id.value='';};
$('strategy-form').onsubmit=run(async()=>{await api('/api/strategy',formData('strategy-form'));await refresh();message('Strategy notes saved. Nothing changed in MT5.');});
$('flow-form').onsubmit=run(async()=>{await api('/api/flow',{...formData('flow-form'),account_id:requireAccount()});$('flow-form').reset();await refresh();message('Cash flow recorded.');});
$('trade-form').onsubmit=run(async()=>{const result=await api('/api/trade',{...formData('trade-form'),account_id:requireAccount()});await refresh(true);message(result.new?'Closed trade saved.':'Duplicate skipped.');});
$('watch-form').onsubmit=run(async()=>{requireAccount();if(!confirm(`Automatically import matching files into ${account().name}? Only enable this for an account-specific folder.`))return;await api('/api/watch',{...formData('watch-form'),account_id:selected,enabled:true});await refresh();message('Folder reading enabled. Allow about 30 seconds for stable files.');});
function clearFilters(){for(const id of ['strategy','config','from','to'])$(id).value='';page=0;}
$('account').onchange=run(async()=>{selected=$('account').value;clearFilters();staged=[];$('commit').disabled=true;$('preview-results').replaceChildren();await refresh(true);});
$('apply-filters').onclick=run(async()=>{page=0;await refresh();});$('clear-filters').onclick=run(async()=>{clearFilters();await refresh(true);});
$('previous').onclick=()=>{page--;renderTrades();};$('next').onclick=()=>{page++;renderTrades();};
$('export').onclick=run(()=>{location.href='/api/export?account_id='+encodeURIComponent(requireAccount());});
function toBase64(file){return new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result).split(',')[1]);reader.onerror=()=>reject(new Error('Could not read file'));reader.readAsDataURL(file);});}
$('files').onchange=()=>{staged=[];$('commit').disabled=true;$('preview-results').replaceChildren();};
function previewHTML(item){const p=item.preview;return `<div class="preview-item"><h3>${e(item.filename)}</h3><p>${e(p.kind)} · ${p.new} new · ${p.duplicates} duplicates · ${p.skipped} non-final skipped</p><p>${p.error_count} invalid rows · ${p.conflict_count} conflicts · ${p.flagged} flagged rows</p><p class="muted">Configs: ${e(p.configs.join(', ')||'none')}</p>${p.errors.length?'<pre class="negative">'+e(p.errors.join('\n'))+'</pre>':''}${p.conflicts.length?'<p class="negative">Conflicting IDs: '+e(p.conflicts.join(', '))+'</p>':''}${table(p.kind==='trades'?['First rows','Symbol','Net','R']:['First rows','Status','Reason'],p.sample.map(r=>p.kind==='trades'?[e(r.closed),e(r.symbol),fmt(r.net),fmt(r.r,3)]:[e(r.time),e(r.status),e(r.reason)]))}</div>`;}
$('preview').onclick=run(async()=>{const target=requireAccount(),files=[...$('files').files];if(!files.length)throw new Error('Select CSV files first.');staged=[];$('commit').disabled=true;$('preview').disabled=true;try{for(const file of files){if(file.size>24*1024*1024)throw new Error(`${file.name}: maximum 24 MB`);const content=await toBase64(file),preview=await api('/api/preview',{account_id:target,filename:file.name,content});staged.push({account_id:target,filename:file.name,content,preview});}$('preview-results').innerHTML=staged.map(previewHTML).join('');$('commit').disabled=target!==selected||staged.some(s=>s.preview.error_count||s.preview.conflict_count);message($('commit').disabled?'Import blocked. Review the errors; no records changed.':'Preview ready. Confirm to save these files.', $('commit').disabled);}finally{$('preview').disabled=false;}});
$('commit').onclick=run(async()=>{if(!staged.length||staged.some(s=>s.account_id!==selected))throw new Error('Preview again for the selected account.');$('commit').disabled=true;let added=0,duplicates=0;try{for(const item of staged){const result=await api('/api/import',item);if(!result.committed)throw new Error('File blocked on final validation. Earlier successful files remain imported; see history.');added+=result.new;duplicates+=result.duplicates;}staged=[];$('preview-results').replaceChildren();$('files').value='';clearFilters();await refresh(true);message(`Imported ${added} rows. Skipped ${duplicates} duplicates.`);}catch(error){await refresh();throw error;}});
$('restore').onclick=run(async()=>{const file=$('restore-file').files[0];if(!file)throw new Error('Choose a backup first.');if(file.size>128*1024*1024)throw new Error('Backup exceeds 128 MB.');if(!confirm('Replace this journal with the selected backup? A safety backup will be saved first.'))return;const result=await api('/api/restore',{content:await toBase64(file),confirm:'RESTORE'});selected='';staged=[];$('commit').disabled=true;clearFilters();await refresh(true);message('Restored. Folder imports are paused. Previous journal backed up to '+result.safety_backup);});
navigate();run(()=>refresh(true))();
$('stop').onclick=run(async()=>{if(!confirm('Close the journal and pause folder reading? This has no effect on MT5.'))return;await api('/api/stop',{});stopped=true;document.querySelectorAll('button,input,select,textarea').forEach(el=>el.disabled=true);message('Journal closed. Your EA is unaffected. Double-click Open-E2-Journal to reopen.');});
setInterval(()=>{if(!stopped&&!busy&&!document.querySelector('form:focus-within'))run(()=>refresh())();},30000);
