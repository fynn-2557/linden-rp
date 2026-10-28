'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {Store}=require('../bot/store');
const discord='123456789012345678';const license='license:'+'a'.repeat(40);const license2='license:'+'b'.repeat(40);
const fresh=()=>new Store();
function approve(store,id=discord,dept='police',first='Michael',last='Anderson'){
 const req=store.apply(id,dept,first,last);return store.approve(req.id);
}
function start(store){const first=approve(store);const state=store.redeem(discord,license,first.code);return {first,state};}
test('erste Bewerbung nur Behörden, keine Zivilisten',()=>{
 const store=fresh();assert.throws(()=>store.apply(discord,'civilian','Jason','Miller'),/Zivilist/);
 assert.throws(()=>store.apply(discord,'police','X','Y'),/Charaktername/);
 assert.equal(store.apply(discord,'police','Michael','Anderson').department,'police');store.close();
});
test('Erst-Whitelist -> einmaliger Code -> gebundene FiveM-Lizenz',()=>{
 const s=fresh();const {first,state}=start(s);
 assert.equal(state.characters.length,1);assert.equal(state.characters[0].kind,'main');
 assert.throws(()=>s.redeem(discord,license,first.code),/bereits eingelöst/);
 assert.throws(()=>s.state(discord,license2),/bereits an eine andere/);
 s.close();
});
test('zusätzliche Rolle erst nach bestandener Erstausbildung',()=>{
 const s=fresh();start(s);
 assert.throws(()=>s.apply(discord,'fire','Daniel','Meyer'),/Grundausbildung/);
 s.trainingPass(discord,'police');
 const x=approve(s,discord,'fire','Daniel','Meyer');assert.ok(x.code);
 const chars=s.redeem(discord,license,x.code).characters;
 assert.equal(chars.filter(c=>c.kind==='main').length,2);
 s.close();
});
test('temporärer Charakter nur nach Ausbildung, Rang maximal eigener Hauptrang',()=>{
 const s=fresh();start(s);
 assert.throws(()=>s.temporary(discord,license,'police','David','Meyer',0),/Grundausbildung/);
 s.trainingPass(discord,'police');s.setRank(discord,'police',5);
 assert.throws(()=>s.temporary(discord,license,'police','David','Meyer',6),/Rang/);
 const chars=s.temporary(discord,license,'police','David','Meyer',3).characters;
 assert.equal(chars.length,2);assert.equal(chars.find(c=>c.kind==='temporary').rankLabel,'Erste/-r Polizeihauptkommissar/-in');
 s.close();
});
test('Rangherabsetzung reduziert temporäre Rangobergrenzen und Reset löscht nur temporär',()=>{
 const s=fresh();start(s);s.trainingPass(discord,'police');s.setRank(discord,'police',7);
 const state=s.temporary(discord,license,'police','David','Meyer',6);
 s.select(discord,license,state.characters.find(c=>c.kind==='temporary').id);
 s.setRank(discord,'police',2);
 assert.equal(s.state(discord,license).characters.find(c=>c.kind==='temporary').rank,2);
 assert.equal(s.resetTemporary(),1);
 const final=s.state(discord,license);assert.equal(final.activeId,null);assert.equal(final.characters.length,1);s.close();
});
test('Charakterwechsel speichert Aussehen beim alten Charakter',()=>{
 const s=fresh();start(s);s.trainingPass(discord,'police');
 const chars=s.temporary(discord,license,'police','David','Meyer',0).characters;
 const second=chars.find(c=>c.kind==='temporary');
 s.select(discord,license,second.id,{ped:'test',components:[1,2,3]});
 assert.equal(s.state(discord,license).characters.find(c=>c.kind==='main').appearance.ped,'test');
 assert.throws(()=>s.select(discord,license,'not-a-real-character'),/nicht verfügbar/);
 s.close();
});
test('Einlösecode darf nicht von einem anderen Discord-Konto eingelöst werden',()=>{
 const s=fresh();const code=approve(s).code;
 const other='123456789012345679';approve(s,other,'fire','Daniel','Foster');
 assert.throws(()=>s.redeem(other,license2,code),/Code ungültig/);s.close();
});
test('gleichzeitige Erstbewerbungen werden nicht ermöglicht',()=>{
 const s=fresh();s.apply(discord,'police','Michael','Anderson');
 assert.throws(()=>s.apply(discord,'fire','Daniel','Foster'),/eine Erstbewerbung/);
 s.close();
});
test('Code erneut ausstellen invalidiert alten Code',()=>{
 const s=fresh();const a=approve(s);const code2=s.reissue(discord,'police');
 assert.throws(()=>s.redeem(discord,license,a.code),/Code ungültig/);
 assert.equal(s.redeem(discord,license,code2).characters.length,1);
 assert.throws(()=>s.reissue(discord,'police'),/Kein noch nicht eingelöster/);s.close();
});

test('NRW-Rangmodell enthält keine US-Police-Officer-Grade',()=>{
 const {RANKS,FF_RANKS}=require('../bot/store');
 assert.equal(RANKS.police[0],'Polizeikommissar/-in');
 assert.equal(RANKS.fire[0],'Brandmeister/-in');
 assert.equal(RANKS.ems.at(-1),'Notfallsanitäter/-in');
 assert.equal(FF_RANKS[0],'Feuerwehranwärter/-in');
});
test('Dienstzählung: kein Mindestminutenwert, aber kein Doppeltzählen oder Wechsel im Dienst',()=>{
 const s=fresh(); start(s);s.trainingPass(discord,'police');
 const current=s.state(discord,license).activeId;
 assert.equal(s.startDuty(discord,license).department,'police');
 assert.throws(()=>s.startDuty(discord,license),/Bereits im Dienst/);
 assert.throws(()=>s.select(discord,license,current),/kein Charakterwechsel/);
 assert.equal(s.stopDuty(discord,license).counted,true);
 assert.equal(s.state(discord,license).characters.find(x=>x.kind==='main').dutyCount,1);
 assert.throws(()=>s.stopDuty(discord,license),/Kein laufender/);
 s.startDuty(discord,license);s.stopDuty(discord,license);
 s.startDuty(discord,license);s.stopDuty(discord,license);
 assert.equal(s.state(discord,license).characters[0].dutyCount,3);
 assert.throws(()=>s.probationComplete(discord,'police','Leitung'),/7 Tagen/);
 s.db.prepare('UPDATE characters SET probation_started=? WHERE discord_id=? AND dept=?').run(Date.now()-8*24*3600000,discord,'police');
 assert.equal(s.probationComplete(discord,'police','Leitung').ok,true);
 assert.equal(s.state(discord,license).characters[0].trainingState,'qualified');s.close();
});
test('offene Pflichtdienste zählen nicht, erst abgeschlossene Dienstsitzungen',()=>{
 const s=fresh();start(s);s.trainingPass(discord,'police');
 s.startDuty(discord,license);
 assert.equal(s.state(discord,license).characters[0].dutyCount,0);
 assert.equal(s.stopDuty(discord,license,{count:false}).counted,false);
 assert.equal(s.state(discord,license).characters[0].dutyCount,0);
 s.close();
});
test('FF braucht BF-Ausbildung, genehmigten Zivilcharakter, Einweisung und Führungserlaubnis',()=>{
 const s=fresh();start(s);
 assert.throws(()=>s.ffAdmit(discord,'fake','Löschzug 1','Führung'),/Feuerwehr-Grundausbildung/);
 s.trainingPass(discord,'police');
 const fire=approve(s,discord,'fire','Erik','Meier');s.redeem(discord,license,fire.code);
 s.trainingPass(discord,'fire');
 const civil=approve(s,discord,'civilian','Jonas','Schmitz');s.redeem(discord,license,civil.code);
 const civMain=s.main(discord,'civilian');
 assert.equal(s.ffAdmit(discord,civMain.id,'Löschzug 1','FF-Führung').ok,true);
 assert.throws(()=>s.ffLeadership(discord,'FF-Führung'),/Einweisung/);
 assert.equal(s.ffOrientation(discord,'Ausbilder').ok,true);
 assert.throws(()=>s.ffLeadership(discord,'FF-Führung'),/Führungsqualifikation/);
 s.grantQualification(discord,'fire','gruppenfuehrer','Ausbilder');
 assert.equal(s.ffLeadership(discord,'FF-Führung').ok,true);
 s.select(discord,license,civMain.id);
 assert.equal(s.startDuty(discord,license,{ff:true}).department,'ff');
 s.stopDuty(discord,license);
 assert.equal(s.state(discord,license).ff.leadershipApproved,true);
 assert.equal(s.state(discord,license).ff.unit,'Löschzug 1');s.close();
});
