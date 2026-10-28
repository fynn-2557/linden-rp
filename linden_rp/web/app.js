'use strict';
const $ = id => document.getElementById(id);
const esc = v => String(v ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const get = (obj,key,fallback='') => obj && obj[key] !== undefined && obj[key] !== null ? obj[key] : fallback;
const rid = () => 'r'+Date.now().toString(36)+'-'+(++counter);
let loaded=false;
let counter=0, currentPage='dispatch', selectedIncident=null, selectedCall=null, selectedEntity=null, kind='org', mapDraft=null;
let state={ role:{dispatcher:false,creator:false,voice:'none',job:null,framework:'standalone'}, incidents:[], calls:[], vehicles:[], entities:[], journal:[], messages:[] };
let pending=new Map(), toastTimer, alertTimer, currentDialog=null;
const categories={ org:'Organisationen', station:'Wachen', vehicle:'Fahrzeuge', keyword:'Stichwörter / AAO', object:'Objekte', hospital:'Krankenhäuser', access:'Leitstellen-Zugänge', group:'Gesprächsgruppen', number:'Notrufnummern' };
const fieldDefs={
 org:[['name','Name','text'],['short','Kürzel','text'],['job','Framework-Job','text'],['color','Farbe (Hex)','text']],
 station:[['name','Wachenname','text'],['org','Organisation','org'],['job','Framework-Job','text'],['x','X-Koordinate','number'],['y','Y-Koordinate','number'],['postal','Postleitzahl','text']],
 vehicle:[['callsign','Funkkennung','text'],['type','Fahrzeugtyp (z. B. HLF)','text'],['org','Organisation','org'],['station_id','Wache','station'],['plate','Ingame-Kennzeichen','text'],['name','Anzeige-Name','text']],
 keyword:[['name','Stichwort / Name','text'],['org','Organisation','org'],['aao','AAO: HLF:2,RTW:1 …','text']],
 object:[['name','Objekt / Gebäude','text'],['org','Zuständigkeit','org'],['x','X-Koordinate','number'],['y','Y-Koordinate','number'],['note','Zugang / Gefahren / Hinweise','textarea']],
 hospital:[['name','Krankenhaus','text'],['x','X-Koordinate','number'],['y','Y-Koordinate','number'],['specialties','Fachbereiche, getrennt mit Komma','text']],
 access:[['name','Berechtigung / Dienststelle','text'],['job','Framework-Job (Leitstelle)','text']],
 group:[['name','Gesprächsgruppenname','text'],['channel','Funkkanal (Zahl)','number'],['org','Organisation','org']],
 number:[['name','Notrufstelle','text'],['number','Rufnummer','text'],['org','Organisation','org']]
};
const statusLabels={'0':'Prioritätsruf','1':'Einsatzbereit Funk','2':'Einsatzbereit Wache','3':'Einsatz übernommen','4':'Am Einsatzort','5':'Sprechwunsch','6':'Nicht einsatzbereit','7':'Patient aufgenommen','8':'Transportziel erreicht'};
function ents(kind){return state.entities.filter(e=>e.kind===kind).map(e=>{let data={};try{data=JSON.parse(e.data)}catch{}return {...e,value:data}})}
function stamp(d){if(!d)return '';const date=new Date(String(d).replace(' ','T'));return isNaN(date.getTime())?esc(d):date.toLocaleTimeString('de-DE',{hour:'2-digit',minute:'2-digit'});}
function fullStamp(d){if(!d)return '';const date=new Date(String(d).replace(' ','T'));return isNaN(date.getTime())?esc(d):date.toLocaleString('de-DE');}
function isDispatch(){return !!state.role.dispatcher}
function notify(text,error=false){const el=$('toast');el.textContent=text;el.className='toast'+(error?' error':'');clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.add('hidden'),4000)}
function post(name,data={}){if(typeof GetParentResourceName!=='function')return Promise.resolve({ok:false,error:'Offline-Vorschau: keine FiveM-Verbindung.'});return fetch(`https://${GetParentResourceName()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json; charset=UTF-8'},body:JSON.stringify(data)}).then(r=>r.json());}
function rpc(action,payload={}){const id=rid();return new Promise(async resolve=>{const timeout=setTimeout(()=>{pending.delete(id);resolve({ok:false,error:'Server antwortet nicht.'})},12000);pending.set(id,r=>{clearTimeout(timeout);resolve(r)});try{const a=await post('rpc',{action,payload,rid:id});if(!a.ok){clearTimeout(timeout);pending.delete(id);resolve(a)}}catch(e){clearTimeout(timeout);pending.delete(id);resolve({ok:false,error:String(e)})}})}
async function send(action,data,after){const r=await rpc(action,data);if(!r.ok){notify(r.error||'Aktion fehlgeschlagen',true);return false}notify('Aktion ausgeführt');if(after)after(r.data);return true}
function clock(){const now=new Date();$('clock').textContent=now.toLocaleTimeString('de-DE')}
setInterval(clock,1000);clock();
function page(name){
 if(loaded && name==='dispatch'&&!isDispatch()){notify('Leitstelle nur mit zugewiesener Berechtigung.',true);name='calls'}
 currentPage=name;
 document.querySelectorAll('[data-page]').forEach(b=>b.classList.toggle('active',b.dataset.page===name));
 document.querySelectorAll('.screen').forEach(e=>e.classList.add('hidden'));
 $('page-'+name).classList.remove('hidden');$('path').textContent='ZENTRALE / '+name.toUpperCase();
 render();
}
function render(){
 const active=state.incidents.filter(i=>i.state!=='CLOSED');const calls=state.calls.filter(c=>c.status==='OPEN');const units=state.vehicles;
 $('incidentCount').textContent=active.length;$('callCount').textContent=calls.length;$('statInc').textContent=active.length;$('statCalls').textContent=calls.length;$('statUnits').textContent=units.filter(u=>Number(u.fms)===2).length;$('statBusy').textContent=units.filter(u=>u.incident_id).length;
 $('role').textContent=state.role.creator?'Creator + Disposition':state.role.dispatcher?'Leitstelle besetzt':'Notruf-Teilnehmer';
 const own=Object.values(state.operators||{}).find(x=>x.name===$('player').textContent); $('operatorLed').style.background=own?.status==='red'?'#e86e6e':own?.status==='yellow'?'#e6a36a':'#67bba4';
 $('createIncident').disabled=!isDispatch(); $('creatorDenied').classList.toggle('hidden',!!state.role.creator);$('creatorContent').classList.toggle('hidden',!state.role.creator);$('newEntity').disabled=!state.role.creator;
 renderIncidents();renderDetail();renderMap();renderCalls();renderConversation();renderFleet();renderRadio();renderPager();renderCreator();renderArchive();
}
function renderIncidents(){
 const query=$('searchCase').value.trim().toLowerCase();const incidents=state.incidents.filter(i=>i.state!=='CLOSED' && [i.title,i.keyword_name,i.location_label,i.id].some(v=>String(v).toLowerCase().includes(query)));
 $('caseTotal').textContent=incidents.length+' Vorgänge';
 $('incidentList').innerHTML=incidents.map(i=>`<button class="case ${Number(selectedIncident)===Number(i.id)?'active':''}" data-case="${i.id}"><div class="case-top"><span class="case-chip ${i.priority==3?'low':i.priority==2?'mid':''}">P${esc(i.priority)}</span><span class="case-title">${esc(i.title)}</span><span class="case-time">${stamp(i.created_at)}</span></div><div class="case-sub"><span class="case-no">#${i.id}</span><span>⌖ ${esc(i.location_label||'Position ohne Adresse')}</span></div></button>`).join('')||'<div class="empty-state"><span>◈</span><b>Keine aktiven Einsätze</b><small>Neue Einsätze werden hier live angezeigt.</small></div>';
 document.querySelectorAll('[data-case]').forEach(b=>b.onclick=()=>{selectedIncident=Number(b.dataset.case);render()});
}
function renderDetail(){
 const i=state.incidents.find(x=>Number(x.id)===Number(selectedIncident));const el=$('caseDetail');
 if(!i){$('caseNo').textContent='KEINE AUSWAHL';el.classList.add('empty');el.innerHTML='<div class="empty-state"><span>⌑</span><b>Kein Einsatz ausgewählt</b><small>Wähle einen Vorgang aus der Liste.</small></div>';return}
 $('caseNo').textContent='AKTE #'+i.id;el.classList.remove('empty');
 const records=state.journal.filter(j=>Number(j.incident_id)===Number(i.id)).sort((a,b)=>Number(a.id)-Number(b.id));
 const assigned=state.vehicles.filter(v=>Number(v.incident_id)===Number(i.id));
 el.innerHTML=`<div class="case-data"><span class="case-chip">${esc(i.keyword_name||'EINSATZ')}</span><h2>${esc(i.title)}</h2><div class="meta-line">⌖ ${esc(i.location_label||'Koordinaten')} ${esc(i.postal)}</div><div class="meta-line">ERÖFFNET ${fullStamp(i.created_at)}</div><div class="meta-line">EINHEITEN ${assigned.length ? assigned.map(x=>esc(x.callsign)).join(' · ') : 'Keine'}</div></div><div class="journal">${records.map(j=>`<div class="journal-row"><div><small>${stamp(j.created_at)} · ${esc(j.kind)} · ${esc(j.actor)}</small>${esc(j.message)}</div></div>`).join('')||'<small>Keine Tagebucheinträge.</small>'}</div><div class="detail-actions"><button class="outline" id="addNote">＋ Tagebuch</button><button class="outline" id="assignVehicle">＋ Einheit</button><button class="critical" id="closeIncident" ${i.state==='CLOSED'?'disabled':''}>Abschließen</button></div>`;
 $('addNote').onclick=()=>promptDialog('note',i);$('assignVehicle').onclick=()=>promptDialog('assign',i);$('closeIncident').onclick=()=>{if(confirm('Einsatz #'+i.id+' wirklich abschließen?'))send('incident:close',{id:i.id},()=>{selectedIncident=null})};
}
function mapPercent(x,y){return {left:Math.max(3,Math.min(97,(Number(x)+4200)/8400*100)),top:Math.max(3,Math.min(97,(4200-Number(y))/8400*100))}}
function renderMap(){const pins=state.incidents.filter(i=>i.state!=='CLOSED').map(i=>({id:i.id,x:i.x,y:i.y,kind:'case',glyph:'!',title:i.title}));ents('station').forEach(s=>pins.push({x:s.value.x,y:s.value.y,kind:'station',glyph:'⌂',title:s.value.name}));
 $('mapPins').innerHTML=pins.map(p=>{const q=mapPercent(p.x,p.y);return `<button title="${esc(p.title)}" class="pin ${p.kind==='station'?'station':''}" style="left:${q.left}%;top:${q.top}%" data-pin="${esc(p.id||'')}">${p.glyph}</button>`}).join('');
 document.querySelectorAll('[data-pin]').forEach(b=>b.onclick=e=>{e.stopPropagation();if(b.dataset.pin){selectedIncident=Number(b.dataset.pin);render()}});
}
function renderCalls(){const calls=state.calls.slice().sort((a,b)=>b.id-a.id);$('callList').innerHTML=calls.map(c=>`<button class="case ${Number(selectedCall)===Number(c.id)?'active':''}" data-call="${c.id}"><div class="case-top"><span class="case-chip ${c.number==='110'?'low':''}">${esc(c.number)}</span><span class="case-title">${esc(c.caller_name)}</span><span class="case-time">${stamp(c.created_at)}</span></div><div class="case-sub">#${c.id} · ${esc(c.status)} · ${esc(c.detail.slice(0,95))}</div></button>`).join('')||'<div class="empty-state"><b>Keine Notrufe</b></div>';
 document.querySelectorAll('[data-call]').forEach(b=>b.onclick=()=>{selectedCall=Number(b.dataset.call);render()});}
function renderConversation(){const c=state.calls.find(x=>Number(x.id)===Number(selectedCall));if(!c){$('callRef').textContent='KEINE AUSWAHL';$('conversation').innerHTML='<div class="empty-state"><b>Gespräch auswählen</b></div>';return}
 $('callRef').textContent='NOTRUF #'+c.id+' · '+c.status;
 const msgs=state.messages.filter(m=>Number(m.call_id)===Number(c.id)).sort((a,b)=>Number(a.id)-Number(b.id));
 $('conversation').innerHTML=msgs.map(m=>`<div class="bubble ${m.sender_type==='DISPATCH'?'dispatch':''}">${esc(m.message)}<small>${esc(m.sender)} · ${stamp(m.created_at)}</small></div>`).join('');$('conversation').scrollTop=$('conversation').scrollHeight;
 $('chatSend').disabled=c.status==='CLOSED';$('closeCall').disabled=c.status==='CLOSED';$('closeCall').textContent=isDispatch()?'Beenden':'Auflegen';$('linkCall').disabled=!isDispatch();$('blockCaller').classList.toggle('hidden',!state.role.creator);
}
function renderFleet(){const rows=state.vehicles;
 $('fleetTable').innerHTML=`<div class="fleet-row"><b>FUNKRUFNAME</b><b>TYP</b><b>STATUS</b><b>ORG</b><b>BESATZUNG</b></div>${rows.map(v=>`<div class="fleet-row"><b>${esc(v.callsign)}</b><span>${esc(v.type)}</span><span class="fms" title="${esc(statusLabels[String(v.fms)])}">${v.fms} · ${esc(statusLabels[String(v.fms)]||'?')}</span><span>${esc(v.org)}</span><span>${v.crew_assigned||v.crew_identifier?'Besetzt':'Unbesetzt'}</span></div>`).join('')||'<div class="empty-state"><b>Keine Fahrzeuge eingerichtet</b><small>Creator → Fahrzeuge</small></div>'}`;
}
function renderRadio(){const dropdown=$('radioVehicle'), prior=dropdown.value;
 dropdown.innerHTML=state.vehicles.map(v=>`<option value="${esc(v.callsign)}">${esc(v.callsign)} · ${esc(v.type)}</option>`).join('');if(state.vehicles.some(v=>v.callsign===prior))dropdown.value=prior;
 $('fmsKeys').innerHTML=Array.from({length:9},(_,i)=>`<button title="${esc(statusLabels[i])}" data-fms="${i}">${i}</button>`).join('')+'<button title="Fahrzeug übernehmen" id="crew">⤴</button>';
 document.querySelectorAll('[data-fms]').forEach(b=>b.onclick=()=>send('vehicle:status',{callsign:dropdown.value,fms:Number(b.dataset.fms)}));
 $('crew').onclick=()=>send('vehicle:crew',{callsign:dropdown.value});
}
function renderPager(){const items=state.journal.filter(j=>j.kind==='ALARM'||j.kind==='NOTRUFKNOPF'||j.kind==='SPRECHWUNSCH').slice(0,30);
 $('pagerEvents').innerHTML=items.map(j=>`<div class="pager-notice"><b>${esc(j.kind)} · EINSATZ #${esc(j.incident_id)}</b><div>${esc(j.message)}</div><small class="muted">${fullStamp(j.created_at)}</small></div>`).join('')||'<div class="empty-state"><b>Noch keine Alarmmeldungen</b><small>Ereignisse erscheinen nach einer Alarmierung.</small></div>';
}
function renderCreator(){const filter=$('kindFilter');if(!filter.options.length)filter.innerHTML=Object.entries(categories).map(([k,v])=>`<option value="${k}">${esc(v)}</option>`).join('');filter.value=kind;
 const list=ents(kind);
 $('entityList').innerHTML=list.map(e=>`<button class="case ${Number(selectedEntity)===Number(e.id)?'active':''}" data-entity="${e.id}"><span class="case-title">${esc(e.value.name||e.value.callsign)}</span><span class="case-sub">${esc(e.value.org||e.value.job||e.value.aao||e.value.type||'ID '+e.id)}</span></button>`).join('')||'<div class="empty-state"><b>Keine Datensätze vorhanden</b></div>';
 document.querySelectorAll('[data-entity]').forEach(b=>b.onclick=()=>{selectedEntity=Number(b.dataset.entity);renderCreator()});
 const ent=list.find(x=>Number(x.id)===Number(selectedEntity));
 const data=ent?ent.value:{};
 $('entityForm').innerHTML=(fieldDefs[kind]||[]).map(([key,label,type])=>{
 const value=get(data,key,'');let widget;
 if(type==='textarea')widget=`<textarea name="${key}">${esc(value)}</textarea>`;
 else if(type==='org')widget=`<select name="${key}"><option value="">— auswählen —</option>${ents('org').map(e=>`<option value="${esc(e.value.name)}" ${value===e.value.name?'selected':''}>${esc(e.value.name)}</option>`).join('')}</select>`;
 else if(type==='station')widget=`<select name="${key}"><option value="">— auswählen —</option>${ents('station').map(e=>`<option value="${e.id}" ${String(value)===String(e.id)?'selected':''}>${esc(e.value.name)}</option>`).join('')}</select>`;
 else widget=`<input name="${key}" type="${type}" value="${esc(value)}" ${type==='number'?'step="any"':''}>`;
 return `<label class="${type==='textarea'?'wide':''}">${esc(label)}${widget}</label>`}).join('');$('entityDelete').disabled=!ent;
}
function renderArchive(){const closed=state.incidents.filter(i=>i.state==='CLOSED');$('archiveList').innerHTML=closed.map(i=>`<button class="case" data-arch="${i.id}"><b>${esc(i.title)}</b><small>${fullStamp(i.closed_at)} · #${i.id}</small></button>`).join('')||'<div class="empty-state"><b>Archiv ist leer</b></div>';
 document.querySelectorAll('[data-arch]').forEach(el=>el.onclick=()=>{selectedIncident=Number(el.dataset.arch);page('dispatch')});
 $('archiveJournal').innerHTML=state.journal.map(j=>`<div class="pager-notice"><b>#${j.incident_id} · ${esc(j.kind)}</b><div>${esc(j.message)}</div><small>${fullStamp(j.created_at)}</small></div>`).join('');
}
function field(label,key,type='text',value='',options=null){if(type==='select')return `<label>${esc(label)}<select name="${key}">${options.map(([v,t])=>`<option value="${esc(v)}" ${String(value)===String(v)?'selected':''}>${esc(t)}</option>`).join('')}</select></label>`;
 return `<label>${esc(label)}${type==='textarea'?`<textarea name="${key}">${esc(value)}</textarea>`:`<input name="${key}" type="${type}" value="${esc(value)}" ${type==='number'?'step="any"':''}>`}</label>`}
function promptDialog(type,reference=null){currentDialog={type,reference};$('dialog').classList.remove('hidden');
 if(type==='incident'){$('dialogTitle').textContent='Einsatz eröffnen';const x=reference?.x??mapDraft?.x??0,y=reference?.y??mapDraft?.y??0;const keywords=ents('keyword').map(k=>[k.value.name,k.value.name]);
 $('myPosition').classList.remove('hidden');
 $('dialogFields').innerHTML=field('Kurzbeschreibung','title','text',reference?.detail?.slice(0,120)||'')+field('Stichwort / AAO','keyword','select',keywords[0]?.[0]||'',[['','— Stichwort auswählen —'],...keywords])+field('Straße / Objekt','location','text','')+field('Postleitzahl (optional)','postal')+field('X-Koordinate','x','number',x)+field('Y-Koordinate','y','number',y)+field('Priorität','priority','select','2',[['1','Sofort'],['2','Dringend'],['3','Normal']]);
 }else if(type==='call'){$('myPosition').classList.add('hidden');$('dialogTitle').textContent='Notruf absetzen';$('dialogFields').innerHTML=field('Notrufnummer','number','select','112',[['112','112 · Feuerwehr / Rettungsdienst'],['110','110 · Polizei']])+field('Was ist passiert?','detail','textarea','');
 }else if(type==='note'){$('myPosition').classList.add('hidden');$('dialogTitle').textContent='Tagebucheintrag';$('dialogFields').innerHTML=field('Meldung / Maßnahme','message','textarea');
 }else if(type==='assign'){$('myPosition').classList.add('hidden');$('dialogTitle').textContent='Fahrzeug disponieren';$('dialogFields').innerHTML=field('Einheit','callsign','select','',state.vehicles.map(v=>[v.callsign,v.callsign+' · '+v.type+' · Status '+v.fms]));
 }}
$('myPosition').onclick=async()=>{const p=await post('position');if(!p.ok){notify(p.error,true);return}for(const key of ['x','y']){const input=$('dialogFields').querySelector(`[name=${key}]`);if(input)input.value=p[key]}const address=$('dialogFields').querySelector('[name=location]');if(address)address.value=p.street};
function closeDialog(){$('dialog').classList.add('hidden');currentDialog=null}
$('dialogClose').onclick=closeDialog;$('dialogCancel').onclick=closeDialog;
$('dialogForm').onsubmit=async ev=>{ev.preventDefault();if(!currentDialog)return;const form=Object.fromEntries(new FormData(ev.target).entries());let action,payload;
 if(currentDialog.type==='incident'){action='incident:create';payload={...form,callId:currentDialog.reference?.id};}
 else if(currentDialog.type==='call'){action='call:create';payload=form;}
 else if(currentDialog.type==='note'){action='incident:note';payload={...form,id:currentDialog.reference.id};}
 else if(currentDialog.type==='assign'){action='vehicle:assign';payload={...form,incidentId:currentDialog.reference.id};}
 const result=await rpc(action,payload);if(!result.ok){notify(result.error,true);return}closeDialog();notify('Erfolgreich gespeichert');if(action==='incident:create'){selectedIncident=result.data.id;page('dispatch');if(result.data.alarmed?.length)notify('Alarmiert: '+result.data.alarmed.join(', '))}if(action==='call:create'){selectedCall=result.data.id;page('calls')}
};
$('createIncident').onclick=()=>promptDialog('incident');$('callSelf').onclick=()=>promptDialog('call');
$('searchCase').oninput=renderIncidents;
$('chatSend').onclick=async()=>{const message=$('chatInput').value.trim();if(!selectedCall||!message)return;if(await send('call:message',{callId:selectedCall,message}))$('chatInput').value='';};
$('chatInput').addEventListener('keydown',e=>{if(e.key==='Enter')$('chatSend').click()});
document.querySelectorAll('[data-question]').forEach(b=>b.onclick=()=>{$('chatInput').value=b.dataset.question;$('chatInput').focus()});
$('closeCall').onclick=()=>{if(selectedCall&&confirm('Notruf abschließen?'))send(isDispatch()?'call:close':'call:hangup',{id:selectedCall})};
$('blockCaller').onclick=()=>{if(!state.role.creator||!selectedCall)return;const days=Number(prompt('Sperrdauer in Tagen (1 bis 30)', '1'));if(!Number.isInteger(days)||days<1||days>30)return notify('Ungültige Sperrdauer.',true);const reason=prompt('Grund für die Sperre','Missbräuchliche Notrufe');if(!reason)return;send('call:block',{id:selectedCall,days,reason})};
$('linkCall').onclick=()=>{const c=state.calls.find(x=>Number(x.id)===Number(selectedCall));if(c)promptDialog('incident',c)};
$('speech').onclick=()=>send('vehicle:request',{callsign:$('radioVehicle').value});$('panic').onclick=()=>{if(confirm('Fahrzeug-Notruf an die Leitstelle senden?'))send('vehicle:panic',{callsign:$('radioVehicle').value})};
$('joinRadio').onclick=()=>send('radio:join',{channel:Number($('radioChannel').value)});
$('kindFilter').onchange=e=>{kind=e.target.value;selectedEntity=null;renderCreator()};
$('newEntity').onclick=()=>{selectedEntity=null;renderCreator()};
$('testAAO').onclick=async()=>{if(kind!=='keyword'){notify('Wähle zunächst Stichwörter / AAO aus.',true);return}const keyword=ents('keyword').find(e=>Number(e.id)===Number(selectedEntity));if(!keyword){notify('Wähle ein Stichwort aus.',true);return}const r=await rpc('incident:preview',{keyword:keyword.value.name});if(!r.ok){notify(r.error,true);return}const missing=Object.entries(r.data.missing).filter(([,v])=>v>0).map(([k,v])=>`${k}: ${v}`);alert(`AAO-Test für ${keyword.value.name} (freie Einheiten, keine Änderungen):\n${r.data.vehicles.join(', ')||'Keine passenden Einheiten'}\nFehlende Fahrzeuge: ${missing.join(', ')||'keine'}`)};
document.querySelectorAll('[data-status]').forEach(b=>b.onclick=()=>send('operator:status',{status:b.dataset.status}));
$('entitySave').onclick=async()=>{const ent=ents(kind).find(e=>Number(e.id)===Number(selectedEntity));const data={};$('entityForm').querySelectorAll('[name]').forEach(el=>data[el.name]=el.value);if(await send('entity:save',{kind,id:ent?.id,data}))selectedEntity=null;};
$('entityDelete').onclick=async()=>{if(!selectedEntity||!confirm('Datensatz endgültig löschen?'))return;if(await send('entity:delete',{id:selectedEntity}))selectedEntity=null;};
$('copyAce').onclick=()=>{const command='add_ace group.admin linden.creator allow';navigator.clipboard?.writeText(command).then(()=>notify('ACE-Befehl kopiert')).catch(()=>notify(command));};
$('map').onclick=ev=>{const rect=ev.currentTarget.getBoundingClientRect();const x=Math.round((ev.clientX-rect.left)/rect.width*8400-4200),y=Math.round(4200-(ev.clientY-rect.top)/rect.height*8400);mapDraft={x,y};$('coords').textContent=`KARTENPUNKT: X ${x} · Y ${y} (SCHEMATISCH)`;};
$('closeBtn').onclick=()=>post('close');
document.querySelectorAll('[data-page]').forEach(b=>b.onclick=()=>page(b.dataset.page));
document.addEventListener('keydown',e=>{if(e.key==='Escape'){$('dialog').classList.contains('hidden')?post('close'):closeDialog()}});
function alarm(entry){const el=$('miniAlert');el.innerHTML=`▲ ${esc(entry.title)}<small>${entry.critical?'PRIORITÄT: NOTRUF':'NEUE MELDUNG'} · ${(entry.x||0).toFixed(0)} / ${(entry.y||0).toFixed(0)}</small>`;el.classList.remove('hidden');clearTimeout(alertTimer);alertTimer=setTimeout(()=>el.classList.add('hidden'),7000);
 try{const ctx=new (window.AudioContext||window.webkitAudioContext)();[0,.25,.5].forEach(t=>{const osc=ctx.createOscillator(),g=ctx.createGain();osc.type='sine';osc.frequency.value=entry.critical?850:640;g.gain.value=.09;osc.connect(g);g.connect(ctx.destination);osc.start(ctx.currentTime+t);osc.stop(ctx.currentTime+t+.15)});setTimeout(()=>ctx.close(),1500)}catch{}
}
window.addEventListener('message',e=>{const m=e.data||{};
 if(m.type==='open'){$('application').classList.remove('hidden');$('player').textContent=m.name||'DISPATCH';page(m.mode==='call'?'calls':m.mode==='pager'?'pager':m.mode==='radio'?'radio':m.mode==='creator'?'creator':'dispatch')}
 if(m.type==='close')$('application').classList.add('hidden');
 if(m.type==='snapshot'){state=m.state||state;loaded=true;render();if(currentPage==='dispatch'&&!isDispatch())page('calls')}
 if(m.type==='response'){const fn=pending.get(m.rid);if(fn){pending.delete(m.rid);fn(m.response)}}
 if(m.type==='notice')notify(m.message,m.level==='error');if(m.type==='alert')alarm(m.alert);
});
if(typeof GetParentResourceName!=='function'){
 $('application').classList.remove('hidden');$('player').textContent='OFFLINE-VORSCHAU';
 state.role={dispatcher:true,creator:true,framework:'offline',voice:'none'};loaded=true;
 state.incidents=[{id:24,title:'Gebäudebrand · Mehrfamilienhaus',keyword_name:'B3 – Gebäudebrand',location_label:'Vinewood Park Dr.',postal:'7283',x:312,y:944,priority:1,state:'OPEN',created_at:'2026-10-28 10:24:00'},{id:23,title:'VU – eingeklemmte Person',keyword_name:'H1 – Hilfeleistung',location_label:'Olympic Fwy',x:-710,y:-160,priority:2,state:'OPEN',created_at:'2026-10-28 10:18:00'}];
 state.vehicles=[{callsign:'FL LS 1/46-1',type:'HLF',fms:3,org:'Feuerwehr',incident_id:24},{callsign:'RD LS 1/82-1',type:'RTW',fms:2,org:'Rettungsdienst'},{callsign:'POL LS 1/10-1',type:'FuStW',fms:2,org:'Polizei'}];
 state.journal=[{id:1,incident_id:24,kind:'CREATE',message:'Einsatz eröffnet',actor:'DISPATCH',created_at:'2026-10-28 10:24:00'},{id:2,incident_id:24,kind:'ALARM',message:'FL LS 1/46-1 alarmiert',actor:'AAO',created_at:'2026-10-28 10:25:00'}];
 state.calls=[{id:9,number:'112',caller_name:'Mustermann',detail:'Rauch im Treppenhaus',status:'OPEN',created_at:'2026-10-28 10:23:00',x:312,y:944}];
 state.messages=[{id:1,call_id:9,sender:'Mustermann',sender_type:'CALLER',message:'Es kommt Rauch aus dem Treppenhaus.',created_at:'2026-10-28 10:23:00'}];selectedIncident=24;page('dispatch');
}
