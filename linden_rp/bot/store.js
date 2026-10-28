'use strict';
// FivePRS roleplay identity store. Node >=22.13 (node:sqlite).
const { DatabaseSync } = require('node:sqlite');
const { randomBytes, randomUUID, createHash } = require('node:crypto');
const path = require('node:path');
const fs = require('node:fs');

const {RANKS,FF_RANKS} = require('./ranks');
const LETTERS = /^[\p{L}][\p{L}\p{M}' .-]{1,39}$/u;
const sha = (s) => createHash('sha256').update(s).digest('hex');
function assert(test, message) { if (!test) throw new Error(message); }
function validName(value) { assert(typeof value === 'string' && LETTERS.test(value.trim()), 'Ungültiger Charaktername (2–40 Zeichen).'); return value.trim(); }
function validDept(dept) { assert(Object.hasOwn(RANKS, dept), 'Unbekannte Behörde.'); return dept; }

class Store {
  constructor(file=':memory:') {
    if (file !== ':memory:') fs.mkdirSync(path.dirname(file), { recursive: true });
    this.db = new DatabaseSync(file);
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;
      CREATE TABLE IF NOT EXISTS players (discord_id TEXT PRIMARY KEY, license TEXT UNIQUE, active_id TEXT, first_training_passed INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS applications (id TEXT PRIMARY KEY, discord_id TEXT NOT NULL, dept TEXT NOT NULL, first_name TEXT NOT NULL, last_name TEXT NOT NULL, status TEXT NOT NULL, created_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS characters (id TEXT PRIMARY KEY, discord_id TEXT NOT NULL, dept TEXT NOT NULL, first_name TEXT NOT NULL, last_name TEXT NOT NULL, kind TEXT NOT NULL, rank_index INTEGER NOT NULL DEFAULT 0, training_state TEXT NOT NULL, redeemed INTEGER NOT NULL DEFAULT 0, appearance TEXT, created_at INTEGER NOT NULL, probation_started INTEGER, duty_count INTEGER NOT NULL DEFAULT 0);
      CREATE UNIQUE INDEX IF NOT EXISTS one_main_per_dept ON characters(discord_id,dept) WHERE kind='main';
      CREATE TABLE IF NOT EXISTS codes (digest TEXT PRIMARY KEY, character_id TEXT NOT NULL UNIQUE, discord_id TEXT NOT NULL, expires_at INTEGER NOT NULL, redeemed_at INTEGER);
      CREATE TABLE IF NOT EXISTS audit (id INTEGER PRIMARY KEY AUTOINCREMENT, at INTEGER NOT NULL, action TEXT NOT NULL, discord_id TEXT, detail TEXT);
      CREATE TABLE IF NOT EXISTS duty_sessions (id TEXT PRIMARY KEY, discord_id TEXT NOT NULL, character_id TEXT NOT NULL, dept TEXT NOT NULL, started_at INTEGER NOT NULL, ended_at INTEGER, end_reason TEXT);
      CREATE UNIQUE INDEX IF NOT EXISTS one_open_duty_per_player ON duty_sessions(discord_id) WHERE ended_at IS NULL;
      CREATE TABLE IF NOT EXISTS ff_memberships (discord_id TEXT PRIMARY KEY, civilian_char_id TEXT NOT NULL, unit TEXT NOT NULL, rank_index INTEGER NOT NULL DEFAULT 0, orientation_passed INTEGER NOT NULL DEFAULT 0, leadership_approved INTEGER NOT NULL DEFAULT 0, approved_by TEXT NOT NULL, joined_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS qualifications (discord_id TEXT NOT NULL, dept TEXT NOT NULL, key TEXT NOT NULL, granted_by TEXT NOT NULL, granted_at INTEGER NOT NULL, PRIMARY KEY(discord_id,dept,key));
    `);
  }
  audit(action,id,detail) { this.db.prepare('INSERT INTO audit(at,action,discord_id,detail) VALUES (?,?,?,?)').run(Date.now(),action,id,String(detail??'')); }
  player(id) { return this.db.prepare('SELECT * FROM players WHERE discord_id=?').get(id); }
  main(id,dept) { return this.db.prepare("SELECT * FROM characters WHERE discord_id=? AND dept=? AND kind='main'").get(id,dept); }
  firstPassed(id) { return !!this.player(id)?.first_training_passed; }
  apply(id,dept,first,last) {
    assert(/^\d{16,22}$/.test(id),'Ungültige Discord-ID.'); validDept(dept);
    validName(first);validName(last);
    const existing=this.db.prepare("SELECT 1 FROM applications WHERE discord_id=? AND dept=? AND status='pending'").get(id,dept);
    assert(!existing,'Du hast bereits eine offene Bewerbung für diesen Bereich.');
    assert(!this.main(id,dept),'Für diese Behörde existiert bereits ein Hauptcharakter.');
    if (!this.player(id)) {
      assert(dept!=='civilian','Zivilist ist nicht als erste Rolle erlaubt.');
      assert(!this.db.prepare("SELECT 1 FROM applications WHERE discord_id=? AND status='pending'").get(id),'Du darfst nur eine Erstbewerbung gleichzeitig haben.');
    } else assert(this.firstPassed(id),'Erst die erste Grundausbildung abschließen.');
    const item={id:randomUUID(),discordId:id,department:dept,firstName:validName(first),lastName:validName(last)};
    this.db.prepare('INSERT INTO applications VALUES (?,?,?,?,?,?,?)').run(item.id,id,dept,item.firstName,item.lastName,'pending',Date.now());
    this.audit('application',id,item.id+' '+dept);
    return item;
  }
  application(id) {return this.db.prepare('SELECT * FROM applications WHERE id=?').get(id);}
  approve(applicationId) {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const app=this.application(applicationId);assert(app && app.status==='pending','Bewerbung bereits bearbeitet oder unbekannt.');
      assert(!this.main(app.discord_id,app.dept),'Für diesen Bereich gibt es bereits einen Hauptcharakter.');
      const player=this.player(app.discord_id);
      assert(!player || player.first_training_passed,'Die erste Ausbildung ist noch nicht bestanden; weitere Rollen sind nicht erlaubt.');
      this.db.prepare('INSERT OR IGNORE INTO players(discord_id) VALUES (?)').run(app.discord_id);
      const charId=randomUUID(), code=randomBytes(12).toString('hex').toUpperCase().match(/.{1,6}/g).join('-');
      const state=app.dept==='civilian'?'qualified':'training';
      this.db.prepare('INSERT INTO characters(id,discord_id,dept,first_name,last_name,kind,rank_index,training_state,redeemed,created_at) VALUES (?,?,?,?,?,?,?,?,0,?)').run(charId,app.discord_id,app.dept,app.first_name,app.last_name,'main',0,state,Date.now());
      this.db.prepare('INSERT INTO codes VALUES (?,?,?,?,NULL)').run(sha(code),charId,app.discord_id,Date.now()+30*24*3600000);
      this.db.prepare("UPDATE applications SET status='approved' WHERE id=?").run(applicationId);
      this.audit('approved',app.discord_id,charId);
      this.db.exec('COMMIT');
      return {code,characterId:charId,dept:app.dept,name:app.first_name+' '+app.last_name,discordId:app.discord_id};
    } catch(e) {this.db.exec('ROLLBACK');throw e;}
  }
  reissue(id,dept) {
    validDept(dept);
    const main=this.main(id,dept);
    assert(main && !main.redeemed,'Kein noch nicht eingelöster Hauptcharakter gefunden.');
    const code=randomBytes(12).toString('hex').toUpperCase().match(/.{1,6}/g).join('-');
    this.db.exec('BEGIN IMMEDIATE');
    try {
      this.db.prepare('DELETE FROM codes WHERE character_id=? AND redeemed_at IS NULL').run(main.id);
      this.db.prepare('INSERT INTO codes VALUES (?,?,?,?,NULL)').run(sha(code),main.id,id,Date.now()+30*24*3600000);
      this.audit('reissue',id,main.id);this.db.exec('COMMIT');return code;
    } catch(e) { this.db.exec('ROLLBACK');throw e; }
  }
  deny(applicationId) {
    const x=this.db.prepare("UPDATE applications SET status='denied' WHERE id=? AND status='pending'").run(applicationId);
    assert(x.changes===1,'Bewerbung bereits bearbeitet oder unbekannt.');
  }
  whitelist(id) {return !!this.player(id) && !!this.db.prepare("SELECT 1 FROM characters WHERE discord_id=? AND kind='main'").get(id);}
  bind(id,license) {
    assert(typeof license==='string' && /^license:[a-f0-9]{40}$/i.test(license),'Keine gültige FiveM-Lizenz.');
    const p=this.player(id);assert(p,'Keine freigeschaltete Discord-Bewerbung.');
    assert(!p.license || p.license===license,'Der Discord-Account ist bereits an eine andere FiveM-Lizenz gebunden.');
    const other=this.db.prepare('SELECT discord_id FROM players WHERE license=?').get(license);
    assert(!other || other.discord_id===id,'FiveM-Lizenz bereits mit anderem Discord-Account verbunden.');
    if (!p.license) this.db.prepare('UPDATE players SET license=? WHERE discord_id=?').run(license,id);
  }
  redeem(id,license,code) {
    assert(typeof code==='string' && /^[A-F0-9-]{20,36}$/i.test(code),'Codeformat ungültig.');
    this.db.exec('BEGIN IMMEDIATE');
    try {
      this.bind(id,license);
      const item=this.db.prepare('SELECT * FROM codes WHERE digest=?').get(sha(code.toUpperCase()));
      assert(item && item.discord_id===id && item.expires_at>Date.now() && !item.redeemed_at,'Code ungültig, abgelaufen oder bereits eingelöst.');
      const ch=this.db.prepare('SELECT * FROM characters WHERE id=?').get(item.character_id);
      assert(ch && ch.discord_id===id && ch.kind==='main','Code nicht für diesen Charakter gültig.');
      this.db.prepare('UPDATE codes SET redeemed_at=? WHERE digest=?').run(Date.now(),item.digest);
      this.db.prepare('UPDATE characters SET redeemed=1 WHERE id=?').run(ch.id);
      this.db.prepare('UPDATE players SET active_id=COALESCE(active_id,?) WHERE discord_id=?').run(ch.id,id);
      this.audit('redeem',id,ch.id);
      this.db.exec('COMMIT');
      return this.state(id,license);
    } catch(e) {this.db.exec('ROLLBACK');throw e;}
  }
  state(id,license) {
    this.bind(id,license);
    const p=this.player(id);
    const chars=this.db.prepare('SELECT id,dept,first_name,last_name,kind,rank_index,training_state,probation_started,duty_count,appearance FROM characters WHERE discord_id=? AND redeemed=1 ORDER BY dept,kind,created_at').all(id);
    const majors={};for(const c of chars){if(c.kind==='main') majors[c.dept]={maxRank:c.rank_index,trained:c.training_state!=='training'};}
    const openDuty=this.db.prepare('SELECT id,dept,started_at,character_id FROM duty_sessions WHERE discord_id=? AND ended_at IS NULL').get(id);
    const ff=this.db.prepare('SELECT unit,rank_index,orientation_passed,leadership_approved,civilian_char_id FROM ff_memberships WHERE discord_id=?').get(id);
    return {activeId:p.active_id,activeDuty:openDuty||null,ff:ff?{unit:ff.unit,rank:ff.rank_index,rankLabel:FF_RANKS[ff.rank_index],orientationPassed:!!ff.orientation_passed,leadershipApproved:!!ff.leadership_approved,civilianCharacterId:ff.civilian_char_id}:null,rankOptions:RANKS,characters:chars.map(c=>({id:c.id,department:c.dept,firstName:c.first_name,lastName:c.last_name,kind:c.kind,rank:c.rank_index,rankLabel:RANKS[c.dept][c.rank_index]||'Unknown',trainingState:c.training_state,probationStarted:c.probation_started,dutyCount:c.duty_count,appearance:c.appearance?JSON.parse(c.appearance):null})),departments:majors,firstTrainingPassed:!!p.first_training_passed};
  }
  temporary(id,license,dept,first,last,rank) {
    this.db.exec('BEGIN IMMEDIATE');try {
      this.bind(id,license);validDept(dept); assert(Number.isInteger(rank),'Ungültiger Rang.');
      const main=this.main(id,dept);assert(main && main.redeemed && main.training_state!=='training','Behörde nicht freigeschaltet oder Grundausbildung noch offen.');
      assert(rank>=0 && rank<=main.rank_index,'Der Rang überschreitet deine Freigabe.');
      const charId=randomUUID();
      this.db.prepare('INSERT INTO characters(id,discord_id,dept,first_name,last_name,kind,rank_index,training_state,redeemed,created_at) VALUES (?,?,?,?,?,?,?,?,1,?)').run(charId,id,dept,validName(first),validName(last),'temporary',rank,'qualified',Date.now());
      this.audit('temporary',id,charId);this.db.exec('COMMIT');return this.state(id,license);
    }catch(e){this.db.exec('ROLLBACK');throw e;}
  }
  select(id,license,charId,previousAppearance) {
    this.db.exec('BEGIN IMMEDIATE');try {
      this.bind(id,license);
      const target=this.db.prepare('SELECT * FROM characters WHERE id=? AND discord_id=? AND redeemed=1').get(charId,id);
      assert(target,'Charakter nicht verfügbar.');
      const p=this.player(id);
      assert(!this.db.prepare('SELECT 1 FROM duty_sessions WHERE discord_id=? AND ended_at IS NULL').get(id),'Im Dienst ist kein Charakterwechsel möglich.');
      if(p.active_id && previousAppearance!==undefined && previousAppearance!==null) this._saveAppearance(id,p.active_id,previousAppearance);
      this.db.prepare('UPDATE players SET active_id=? WHERE discord_id=?').run(charId,id);
      this.audit('select',id,charId);this.db.exec('COMMIT');return this.state(id,license);
    }catch(e){this.db.exec('ROLLBACK');throw e;}
  }
  _saveAppearance(id,charId,skin) {
    assert(skin && typeof skin==='object' && !Array.isArray(skin),'Ungültige Outfitdaten.');
    const data=JSON.stringify(skin);
    assert(data.length<150000,'Outfitdaten zu groß.');
    const x=this.db.prepare('UPDATE characters SET appearance=? WHERE id=? AND discord_id=? AND redeemed=1').run(data,charId,id);
    assert(x.changes===1,'Aktiver Charakter fehlt.');
  }
  saveAppearance(id,license,skin) {
    this.bind(id,license);const p=this.player(id);assert(p.active_id,'Kein aktiver Charakter.');
    this._saveAppearance(id,p.active_id,skin);return {ok:true};
  }
  trainingPass(id,dept) {
    const main=this.main(id,validDept(dept));assert(main && main.training_state==='training','Keine offene Grundausbildung gefunden.');
    this.db.prepare("UPDATE characters SET training_state='probation',probation_started=?,duty_count=0 WHERE id=?").run(Date.now(),main.id);
    this.db.prepare('UPDATE players SET first_training_passed=1 WHERE discord_id=?').run(id);
    this.audit('training-pass',id,dept);return {ok:true};
  }
  setRank(id,dept,rank) {
    validDept(dept);assert(Number.isInteger(rank) && rank>=0 && rank<RANKS[dept].length,'Ungültiger Rangindex.');
    const main=this.main(id,dept);assert(main,'Kein Hauptcharakter.');
    this.db.prepare("UPDATE characters SET rank_index=? WHERE id=?").run(rank,main.id);
    // Temporaries above new maximum must not retain their rank.
    this.db.prepare("UPDATE characters SET rank_index=? WHERE discord_id=? AND dept=? AND kind='temporary' AND rank_index>?").run(rank,id,dept,rank);
    this.audit('rank',id,dept+':'+rank);return {ok:true};
  }
  // Start/stop MUST be invoked by a trusted server-side duty adapter, never by a game client.
  startDuty(id,license,{ff=false}={}) {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      this.bind(id,license);
      assert(!this.db.prepare('SELECT 1 FROM duty_sessions WHERE discord_id=? AND ended_at IS NULL').get(id),'Bereits im Dienst.');
      const p=this.player(id);
      const c=this.db.prepare('SELECT * FROM characters WHERE id=? AND discord_id=? AND redeemed=1').get(p.active_id,id);
      assert(c,'Zuerst einen gültigen Charakter wählen.');
      assert(c.training_state!=='training','Grundausbildung noch nicht abgeschlossen.');
      if(ff){
        assert(c.dept==='civilian','FF-Dienst nur mit Zivilcharakter.');
        const membership=this.db.prepare('SELECT * FROM ff_memberships WHERE discord_id=?').get(id);
        assert(membership && membership.civilian_char_id===c.id && membership.orientation_passed,'FF-Aufnahme oder Einweisung fehlt.');
      } else assert(c.dept!=='civilian','Zivilisten haben keinen regulären BOS-Dienst.');
      // A temporary char and the main char both contribute to that department's probation.
      const dutyId=randomUUID();
      this.db.prepare('INSERT INTO duty_sessions (id,discord_id,character_id,dept,started_at) VALUES (?,?,?,?,?)').run(dutyId,id,c.id,ff?'ff':c.dept,Date.now());
      this.audit('duty-start',id,dutyId+' '+(ff?'ff':c.dept));
      this.db.exec('COMMIT');
      return {dutyId,department:ff?'ff':c.dept,characterId:c.id};
    }catch(e){this.db.exec('ROLLBACK');throw e;}
  }
  stopDuty(id,license,{count=true,reason='normal'}={}) {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      this.bind(id,license);
      const session=this.db.prepare('SELECT * FROM duty_sessions WHERE discord_id=? AND ended_at IS NULL').get(id);
      assert(session,'Kein laufender Dienst.');
      this.db.prepare('UPDATE duty_sessions SET ended_at=?,end_reason=? WHERE id=?').run(Date.now(),reason,session.id);
      if(count) this.db.prepare("UPDATE characters SET duty_count=duty_count+1 WHERE discord_id=? AND dept=? AND kind='main' AND training_state IN ('probation','qualified')").run(id,session.dept);
      this.audit('duty-end',id,session.id+':'+(count?'count':'no-count'));
      this.db.exec('COMMIT');
      return {counted:!!count,department:session.dept};
    }catch(e){this.db.exec('ROLLBACK');throw e;}
  }
  probationComplete(id,dept,approvedBy) {
    validDept(dept);assert(dept!=='civilian','Zivilisten haben keine BOS-Probezeit.');
    assert(typeof approvedBy==='string'&&approvedBy.length>0,'Bestätigende Führungskraft fehlt.');
    const main=this.main(id,dept);
    assert(main&&main.training_state==='probation','Keine offene Probezeit.');
    assert(main.probation_started && Date.now()-main.probation_started>=7*24*3600000,'Die Mindestprobezeit von 7 Tagen ist noch nicht erreicht.');
    assert(main.duty_count>=3,'Mindestens drei Dienste erforderlich.');
    this.db.prepare("UPDATE characters SET training_state='qualified' WHERE id=?").run(main.id);
    this.audit('probation-passed',id,dept+' by '+approvedBy);
    return {ok:true};
  }
  grantQualification(id,dept,key,approvedBy) {
    validDept(dept);
    assert(typeof key==='string'&&/^[a-z][a-z0-9_]{1,47}$/.test(key),'Ungültiger Qualifikationsschlüssel.');
    assert(approvedBy && typeof approvedBy==='string','Ausbilder fehlt.');
    const main=this.main(id,dept); assert(main && main.training_state!=='training','Grundausbildung fehlt.');
    this.db.prepare('INSERT INTO qualifications(discord_id,dept,key,granted_by,granted_at) VALUES (?,?,?,?,?) ON CONFLICT(discord_id,dept,key) DO UPDATE SET granted_by=excluded.granted_by,granted_at=excluded.granted_at').run(id,dept,key,approvedBy,Date.now());
    this.audit('qualification',id,dept+':'+key+' by '+approvedBy);
    return {ok:true};
  }
  // FF is a civilian-character assignment and does NOT create a separate BF job.
  ffAdmit(id,civilianCharId,unit,approvedBy) {
    const bf=this.main(id,'fire'),civil=this.main(id,'civilian');
    assert(bf&&bf.training_state!=='training','Feuerwehr-Grundausbildung fehlt.');
    assert(civil&&civil.redeemed&&civil.id===civilianCharId,'Für die FF muss der freigeschaltete Zivil-Hauptcharakter genutzt werden.');
    assert(typeof unit==='string'&&/^[\p{L}\p{N} .-]{2,60}$/u.test(unit),'Ungültiger Löschzug.');
    assert(typeof approvedBy==='string'&&approvedBy.length>0,'FF-Führung fehlt.');
    assert(!this.db.prepare('SELECT 1 FROM ff_memberships WHERE discord_id=?').get(id),'FF-Aufnahme besteht bereits.');
    this.db.prepare('INSERT INTO ff_memberships(discord_id,civilian_char_id,unit,approved_by,joined_at) VALUES (?,?,?,?,?)').run(id,civilianCharId,unit,approvedBy,Date.now());
    this.audit('ff-admit',id,unit+' by '+approvedBy);return {ok:true};
  }
  ffSetRank(id,rank,approvedBy) {
    assert(Number.isInteger(rank)&&rank>=0&&rank<FF_RANKS.length,'Ungültiger FF-Dienstgrad.');
    assert(typeof approvedBy==='string'&&approvedBy.length>0,'FF-Führung fehlt.');
    const ff=this.db.prepare('SELECT * FROM ff_memberships WHERE discord_id=?').get(id);
    assert(ff&&ff.orientation_passed,'FF-Aufnahme oder Einweisung fehlt.');
    this.db.prepare('UPDATE ff_memberships SET rank_index=? WHERE discord_id=?').run(rank,id);
    this.audit('ff-rank',id,rank+' by '+approvedBy);return {ok:true};
  }
  ffOrientation(id,approvedBy) {
    assert(this.db.prepare('SELECT 1 FROM ff_memberships WHERE discord_id=?').get(id),'Keine FF-Aufnahme.');
    assert(approvedBy,'Einweisende Person fehlt.');
    this.db.prepare('UPDATE ff_memberships SET orientation_passed=1 WHERE discord_id=?').run(id);
    this.audit('ff-orientation',id,approvedBy);return {ok:true};
  }
  ffLeadership(id,approvedBy) {
    const ff=this.db.prepare('SELECT * FROM ff_memberships WHERE discord_id=?').get(id);
    assert(ff&&ff.orientation_passed,'Örtliche FF-Einweisung fehlt.');
    assert(this.db.prepare("SELECT 1 FROM qualifications WHERE discord_id=? AND dept='fire' AND key='gruppenfuehrer'").get(id),'Anerkannte Führungsqualifikation fehlt.');
    assert(approvedBy,'FF-Führung fehlt.');
    this.db.prepare('UPDATE ff_memberships SET leadership_approved=1 WHERE discord_id=?').run(id);
    this.audit('ff-leadership',id,approvedBy);return {ok:true};
  }
  resetTemporary() {
    this.db.exec('BEGIN IMMEDIATE');try {
      const count=this.db.prepare("SELECT COUNT(*) n FROM characters WHERE kind='temporary'").get().n;
      this.db.prepare("UPDATE duty_sessions SET ended_at=?,end_reason='reset' WHERE ended_at IS NULL AND character_id IN (SELECT id FROM characters WHERE kind='temporary')").run(Date.now());
      this.db.prepare("UPDATE players SET active_id=NULL WHERE active_id IN (SELECT id FROM characters WHERE kind='temporary')").run();
      this.db.prepare("DELETE FROM characters WHERE kind='temporary'").run();
      this.audit('reset-temporary',null,count);this.db.exec('COMMIT');return count;
    }catch(e){this.db.exec('ROLLBACK');throw e;}
  }
  close(){this.db.close();}
}
module.exports={Store,RANKS,FF_RANKS};
