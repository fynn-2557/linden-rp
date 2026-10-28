'use strict';
const names={police:'Polizei',fire:'Feuerwehr',ems:'Rettungsdienst',civilian:'Zivilist'};
const symbols={police:'◈',fire:'◇',ems:'✚',civilian:'●'};
const ranks={}; // Populated from the server's NRW role catalog; never trusted for authorization.
let data={characters:[],departments:{},activeId:null},selectedDepartment='police';
const $=id=>document.getElementById(id);
const make=(tag,props={},children=[])=>{const el=document.createElement(tag);for(const [k,v] of Object.entries(props)){if(k==='text')el.textContent=v;else if(k==='className')el.className=v;else el.setAttribute(k,v);}for(const c of children){if(c)el.append(c);}return el;};
function inform(text,bad=false){$('flash').hidden=false;$('flash').textContent=text;$('flash').classList.toggle('bad',bad);}
function field(label,id,placeholder,kind='text'){return make('label',{className:'field',text:label},[make(kind==='select'?'select':'input',{id,name:id,placeholder:placeholder||'',autocomplete:'off',required:'true'})]);}
function send(action,payload){FivePRS.action(action,payload);}
function popup(mode){
 const form=$('modal-form'),body=$('modal-body');body.replaceChildren();form.dataset.mode=mode;
 if(mode==='redeem'){$('modal-eyebrow').textContent='CODE REDEMPTION';$('modal-title').textContent='Charakter-Code einlösen';body.append(make('p',{className:'hint',text:'Dein persönlicher Code steht in der Discord-DM des Bots. Er kann nur einmal verwendet werden.'}),field('Einlösecode','code','XXXXXX-XXXXXX-XXXXXX-XXXXXX'));$('submit').textContent='Code einlösen';}
 if(mode==='new'){
  $('modal-eyebrow').textContent='TEMPORARY CHARACTER';$('modal-title').textContent='Temporären Charakter erstellen';
  const main=data.characters.find(c=>c.kind==='main'&&c.department===selectedDepartment);
  body.append(make('p',{className:'hint',text:'Temporäre Charaktere werden beim nächsten administrativen Reset gelöscht. Dienstgrade sind auf deine Freigabe begrenzt.'}));
  body.append(field('Vorname','firstName','Vorname'),field('Nachname','lastName','Nachname'));
  const label=field('Dienstgrad','rank','','select'),select=label.querySelector('select');
  if(main&&main.trainingState!=='training')for(let i=0;i<=main.rank;i++){select.append(make('option',{value:String(i),text:ranks[selectedDepartment][i]||`Rang ${i}`}));}
  body.append(label);$('submit').textContent='Charakter erstellen';
 }
 $('modal').showModal();
}
$('cancel').addEventListener('click',()=>$('modal').close());
$('modal-form').addEventListener('submit',e=>{
 e.preventDefault();const mode=e.currentTarget.dataset.mode;
 if(mode==='redeem')send('redeem',{code:$('code').value.trim().toUpperCase()});
 else if(mode==='new')send('temporary',{department:selectedDepartment,firstName:$('firstName').value.trim(),lastName:$('lastName').value.trim(),rank:Number($('rank').value)});
 $('modal').close();
});
$('first-code').addEventListener('click',()=>popup('redeem'));
$('redeem-code').addEventListener('click',()=>popup('redeem'));
$('new').addEventListener('click',()=>{
 const main=data.characters.find(c=>c.kind==='main'&&c.department===selectedDepartment);
 if(!main){popup('redeem');return;}
 if(main.trainingState==='training'){inform('Die Grundausbildung muss erst bestanden werden, bevor du weitere Charaktere in dieser Behörde erstellst.',true);return;}
 popup('new');
});
$('refresh').addEventListener('click',()=>send('load'));
function render(){
 $('connection').textContent='VERBUNDEN';
 const counts=Object.fromEntries(Object.keys(names).map(k=>[k,data.characters.filter(c=>c.department===k).length]));
 $('categories').replaceChildren(...Object.entries(names).map(([dept,name])=>{
  const button=make('button',{className:`category${selectedDepartment===dept?' active':''}`},[make('span',{className:'symbol',text:symbols[dept]}),make('span',{text:name}),make('small',{text:String(counts[dept])})]);
  button.addEventListener('click',()=>{selectedDepartment=dept;render();});return button;
 }));
 const list=data.characters.filter(c=>c.department===selectedDepartment);
 $('current-dept').textContent=(names[selectedDepartment]||selectedDepartment).toUpperCase();$('count').textContent=String(list.length);
 $('characters').replaceChildren(...list.map(c=>{
  const active=c.id===data.activeId;
  const card=make('article',{className:`character${active?' active':''}`});
  const avatar=make('div',{className:'avatar',text:c.kind==='main'?'★':'◉'});
  const badges=[make('span',{className:`pill ${c.kind==='main'?'main':''}`,text:c.kind==='main'?'HAUPTCHARAKTER':'TEMP'})];
  if(c.trainingState==='training')badges.push(make('span',{className:'pill training',text:'AUSBILDUNG'}));
  if(c.trainingState==='probation')badges.push(make('span',{className:'pill probation',text:`PROBEZEIT · ${c.dutyCount || 0}/3 DIENSTE`}));
  const person=make('div',{className:'person'},[make('div',{className:'person-name'},[make('span',{text:`${c.firstName} ${c.lastName}`}),...badges]),make('div',{className:'meta',text:`${c.rankLabel}  ·  ${active?'AKTIVER CHARAKTER':'IDENTITÄT '+c.id.slice(0,8).toUpperCase()}`})]);
  const actions=make('div',{className:'actions'});
  if(!active){const btn=make('button',{className:'mini',text:'Auswählen'});btn.addEventListener('click',()=>send('select',{characterId:c.id}));actions.append(btn);}
  if(active){const clothes=make('button',{className:'mini',text:'Outfits'});clothes.addEventListener('click',()=>send('appearance'));actions.append(clothes);
   const edit=make('button',{className:'mini',text:'Aussehen'});edit.addEventListener('click',()=>send('appearance-edit'));actions.append(edit);}
  card.append(avatar,person,actions);return card;
 }));
 $('empty').hidden=data.characters.length>0;
 if(data.activeDuty){inform('Du bist im Dienst. Charakterwechsel ist bis zum Dienstende gesperrt.');}
 if(data.ff && selectedDepartment==='civilian'){
   $('current-dept').textContent='ZIVILIST / FF '+data.ff.unit+' · '+(data.ff.orientationPassed?'EINGEWIESEN':'EINWEISUNG OFFEN');
 }
}
FivePRS.on('state',state=>{if(!state?.characters)return;data=state;Object.assign(ranks,data.rankOptions||{});const active=data.characters.find(c=>c.id===data.activeId);if(active)selectedDepartment=active.department;else if(data.characters.length)selectedDepartment=data.characters[0].department;render();inform('Charakterdaten aktualisiert.');});
FivePRS.on('error',payload=>inform(payload.message||'Unbekannter Fehler',true));
FivePRS.on('info',payload=>inform(payload.message||''));
FivePRS.action('load');
