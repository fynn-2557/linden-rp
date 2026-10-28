'use strict';
// Discord bot; does NOT trust Discord IDs or ranks supplied by FiveM clients.
const {Client,GatewayIntentBits,Events,REST,Routes,SlashCommandBuilder,PermissionFlagsBits,ActionRowBuilder,ButtonBuilder,ButtonStyle,StringSelectMenuBuilder,ModalBuilder,TextInputBuilder,TextInputStyle,EmbedBuilder} = require('discord.js');
const {Store,RANKS,FF_RANKS}=require('./store');
const {serve}=require('./api');
const path=require('node:path');
require('dotenv').config();
const env=process.env;
for(const key of ['DISCORD_TOKEN','DISCORD_CLIENT_ID','DISCORD_GUILD_ID','DISCORD_STAFF_ROLE_ID','DISCORD_REVIEW_CHANNEL_ID','RP_API_SECRET']) {
  if(!env[key])throw new Error(`Missing environment variable ${key}`);
}
const db=new Store(path.resolve(env.RP_DATABASE||'./data/characters.sqlite'));
serve(db,env.RP_API_SECRET,{host:env.RP_API_HOST||'127.0.0.1',port:Number(env.RP_API_PORT||4792)});
const client=new Client({intents:[GatewayIntentBits.Guilds]});
const departments={police:'Polizei',fire:'Feuerwehr',ems:'Rettungsdienst',civilian:'Zivilist'};
const eligible=(i)=>i.guildId===env.DISCORD_GUILD_ID && (i.member?.roles?.cache?.has(env.DISCORD_STAFF_ROLE_ID)||i.memberPermissions?.has(PermissionFlagsBits.Administrator));
// These optional lead/trainer Discord roles can manage only their respective tasks.
const hasRole=(i,roleId)=>!!roleId && !!i.member?.roles?.cache?.has(roleId);
const isTrainer=i=>eligible(i)||hasRole(i,env.DISCORD_TRAINER_ROLE_ID);
const isFfLead=i=>eligible(i)||hasRole(i,env.DISCORD_FF_LEAD_ROLE_ID);
const canPromote=(i,dept)=>eligible(i)||({police:hasRole(i,env.DISCORD_POLICE_LEAD_ROLE_ID),fire:hasRole(i,env.DISCORD_FIRE_LEAD_ROLE_ID),ems:hasRole(i,env.DISCORD_EMS_LEAD_ROLE_ID)})[dept]===true;
const selector=(id,placeholder,extras=false)=>new ActionRowBuilder().addComponents(new StringSelectMenuBuilder().setCustomId(id).setPlaceholder(placeholder).addOptions(Object.entries(departments).filter(([k])=>extras||k!=='civilian').map(([value,label])=>({label,value,description:`Bewerbung für ${label}`}))));
const dmButtons=()=>new ActionRowBuilder().addComponents(new ButtonBuilder().setCustomId('rp:dm:extra').setLabel('Weitere Rolle beantragen').setStyle(ButtonStyle.Primary),new ButtonBuilder().setCustomId('rp:dm:help').setLabel('Hilfe / Status').setStyle(ButtonStyle.Secondary));
const commands=[
 new SlashCommandBuilder().setName('rp_setup').setDescription('Erstbewerbungs-Embed veröffentlichen'),
 new SlashCommandBuilder().setName('rp_training_pass').setDescription('Grundausbildung bestanden').addUserOption(x=>x.setName('mitglied').setDescription('Discord-Mitglied').setRequired(true)).addStringOption(x=>x.setName('behorde').setDescription('Abteilung').setRequired(true).addChoices(...Object.entries(departments).filter(([k])=>k!=='civilian').map(([value,name])=>({name,value})))),
 new SlashCommandBuilder().setName('rp_rank').setDescription('Maximalrang für Hauptcharakter setzen').addUserOption(x=>x.setName('mitglied').setDescription('Discord-Mitglied').setRequired(true)).addStringOption(x=>x.setName('behorde').setDescription('Abteilung').setRequired(true).addChoices(...Object.entries(departments).map(([value,name])=>({name,value})))).addIntegerOption(x=>x.setName('index').setDescription('Rangindex beginnend bei 0').setMinValue(0).setRequired(true)),
 new SlashCommandBuilder().setName('rp_resend_code').setDescription('Unbenutzten Charakter-Code neu per DM senden').addUserOption(x=>x.setName('mitglied').setDescription('Discord-Mitglied').setRequired(true)).addStringOption(x=>x.setName('behorde').setDescription('Behörde').setRequired(true).addChoices(...Object.entries(departments).map(([value,name])=>({name,value})))),
 new SlashCommandBuilder().setName('rp_probation_complete').setDescription('Probezeit nach 7 Tagen und 3 Diensten abschließen').addUserOption(x=>x.setName('mitglied').setDescription('Mitglied').setRequired(true)).addStringOption(x=>x.setName('behorde').setDescription('Behörde').setRequired(true).addChoices(...Object.entries(departments).filter(([k])=>k!=='civilian').map(([value,name])=>({name,value})))),
 new SlashCommandBuilder().setName('rp_qualification').setDescription('Nach bestandenem Lehrgang Qualifikation eintragen').addUserOption(x=>x.setName('mitglied').setDescription('Mitglied').setRequired(true)).addStringOption(x=>x.setName('behorde').setDescription('Behörde').setRequired(true).addChoices(...Object.entries(departments).filter(([k])=>k!=='civilian').map(([value,name])=>({name,value})))).addStringOption(x=>x.setName('qualifikation').setDescription('Kurzcode z.B. gruppenfuehrer').setRequired(true)),
 new SlashCommandBuilder().setName('rp_ff_aufnahme').setDescription('Zivil-Hauptcharakter in einen FF-Löschzug aufnehmen').addUserOption(x=>x.setName('mitglied').setDescription('Mitglied').setRequired(true)).addStringOption(x=>x.setName('loeschzug').setDescription('Bezeichnung des Löschzugs').setRequired(true)),
 new SlashCommandBuilder().setName('rp_ff_einweisung').setDescription('Örtliche FF-Einweisung abschließen').addUserOption(x=>x.setName('mitglied').setDescription('Mitglied').setRequired(true)),
 new SlashCommandBuilder().setName('rp_ff_fuehrung').setDescription('FF-Führungsfreigabe erteilen').addUserOption(x=>x.setName('mitglied').setDescription('Mitglied').setRequired(true)),
 new SlashCommandBuilder().setName('rp_ff_rang').setDescription('FF-Dienstgrad nach Beförderungsentscheidung setzen').addUserOption(x=>x.setName('mitglied').setDescription('Mitglied').setRequired(true)).addIntegerOption(x=>x.setName('index').setDescription('Index laut FF-Dienstgradliste').setMinValue(0).setMaxValue(FF_RANKS.length-1).setRequired(true)),
 new SlashCommandBuilder().setName('rp_reset_temporary').setDescription('Alle temporären Charaktere löschen (manueller Reset)'),
].map(x=>x.toJSON());
function modal(dept){
  const m=new ModalBuilder().setCustomId('rp:form:'+dept).setTitle('RP-Bewerbung · '+departments[dept]);
  m.addComponents(new ActionRowBuilder().addComponents(new TextInputBuilder().setCustomId('first').setLabel('Vorname des Hauptcharakters').setStyle(TextInputStyle.Short).setRequired(true).setMaxLength(40)),new ActionRowBuilder().addComponents(new TextInputBuilder().setCustomId('last').setLabel('Nachname des Hauptcharakters').setStyle(TextInputStyle.Short).setRequired(true).setMaxLength(40)),new ActionRowBuilder().addComponents(new TextInputBuilder().setCustomId('rules').setLabel('Regeln gelesen? Bitte JA eingeben').setStyle(TextInputStyle.Short).setRequired(true).setMaxLength(3)));
  return m;
}
async function sendApplication(i,dept){
  const first=i.fields.getTextInputValue('first'),last=i.fields.getTextInputValue('last');
  if(i.fields.getTextInputValue('rules').trim().toUpperCase()!=='JA') return i.reply({content:'Bitte zuerst das Regelwerk lesen und mit JA bestätigen.',ephemeral:true});
  const application=db.apply(i.user.id,dept,first,last);
  const review=await client.channels.fetch(env.DISCORD_REVIEW_CHANNEL_ID);
  const embed=new EmbedBuilder().setTitle('Neue RP-Bewerbung').setDescription(`<@${i.user.id}> · ${departments[dept]}\nHauptcharakter: **${first} ${last}**`).setFooter({text:'Bewerbung '+application.id}).setColor(0x304b61);
  const actions=new ActionRowBuilder().addComponents(new ButtonBuilder().setCustomId('rp:approve:'+application.id).setStyle(ButtonStyle.Success).setLabel('Genehmigen'),new ButtonBuilder().setCustomId('rp:deny:'+application.id).setStyle(ButtonStyle.Danger).setLabel('Ablehnen'));
  await review.send({embeds:[embed],components:[actions]});
  await i.reply({content:'✅ Bewerbung eingereicht. Das Serverteam prüft sie und informiert dich per DM.',ephemeral:true});
}
client.on(Events.InteractionCreate,async i=>{
 try {
  if(i.isChatInputCommand()){
    const deptArg=i.options.getString('behorde');
    const authorized=(i.commandName==='rp_training_pass'||i.commandName==='rp_qualification') ? isTrainer(i)
      : (i.commandName==='rp_ff_einweisung') ? isTrainer(i)||isFfLead(i)
      : (i.commandName.startsWith('rp_ff_')) ? isFfLead(i)
      : (i.commandName==='rp_rank'||i.commandName==='rp_probation_complete') ? canPromote(i,deptArg)
      : eligible(i);
    if(!authorized)return i.reply({content:'Für diesen Verwaltungsvorgang fehlt dir die Berechtigung.',ephemeral:true});
    if(i.commandName==='rp_setup'){
      const e=new EmbedBuilder().setTitle('RP-Whitelist | Willkommen').setDescription('Wähle deine erste Behörde und bestätige danach die Regeln. Zivilist ist erst nach bestandener erster Grundausbildung verfügbar.').setColor(0x273d52);
      await i.channel.send({embeds:[e],components:[selector('rp:apply','Erste Behörde wählen')]});return i.reply({content:'Bewerbungs-Embed veröffentlicht.',ephemeral:true});
    }
    if(i.commandName==='rp_training_pass'){
      const id=i.options.getUser('mitglied').id,dept=i.options.getString('behorde');db.trainingPass(id,dept);
      await i.reply({content:`✅ Grundausbildung für <@${id}> (${departments[dept]}) bestanden. Probezeit läuft ab jetzt.`,ephemeral:true});
      try{await (await client.users.fetch(id)).send({content:'🎓 Deine Grundausbildung ist bestanden. Ab jetzt kannst du weitere Behörden und Zivilist beantragen.',components:[dmButtons()]});}catch{}
      return;
    }
    if(i.commandName==='rp_rank'){
      const id=i.options.getUser('mitglied').id,dept=i.options.getString('behorde'),rank=i.options.getInteger('index');db.setRank(id,dept,rank);
      return i.reply({content:`✅ ${departments[dept]}: Höchstrang für <@${id}> ist jetzt ${RANKS[dept][rank]} (${rank}).`,ephemeral:true});
    }
    if(i.commandName==='rp_probation_complete'){
      const id=i.options.getUser('mitglied').id,dept=i.options.getString('behorde');db.probationComplete(id,dept,i.user.id);
      return i.reply({content:`✅ Probezeit für <@${id}> (${departments[dept]}) abgeschlossen.`,ephemeral:true});
    }
    if(i.commandName==='rp_qualification'){
      const id=i.options.getUser('mitglied').id,dept=i.options.getString('behorde'),key=i.options.getString('qualifikation').trim().toLowerCase();
      db.grantQualification(id,dept,key,i.user.id);
      return i.reply({content:`✅ Qualifikation ${key} für <@${id}> (${departments[dept]}) eingetragen.`,ephemeral:true});
    }
    if(i.commandName==='rp_ff_aufnahme'){
      const id=i.options.getUser('mitglied').id,unit=i.options.getString('loeschzug');
      const civil=db.main(id,'civilian');db.ffAdmit(id,civil?.id,unit,i.user.id);
      return i.reply({content:`✅ <@${id}> in die FF (${unit}) aufgenommen. Einweisung noch erforderlich.`,ephemeral:true});
    }
    if(i.commandName==='rp_ff_einweisung'){
      const id=i.options.getUser('mitglied').id;db.ffOrientation(id,i.user.id);
      return i.reply({content:`✅ FF-Einweisung für <@${id}> abgeschlossen.`,ephemeral:true});
    }
    if(i.commandName==='rp_ff_fuehrung'){
      const id=i.options.getUser('mitglied').id;db.ffLeadership(id,i.user.id);
      return i.reply({content:`✅ FF-Führungsfreigabe für <@${id}> erteilt.`,ephemeral:true});
    }
    if(i.commandName==='rp_ff_rang'){
      const id=i.options.getUser('mitglied').id,rank=i.options.getInteger('index');db.ffSetRank(id,rank,i.user.id);
      return i.reply({content:`✅ FF-Dienstgrad für <@${id}>: ${FF_RANKS[rank]}.`,ephemeral:true});
    }
    if(i.commandName==='rp_resend_code'){
      const id=i.options.getUser('mitglied').id,dept=i.options.getString('behorde');
      const code=db.reissue(id,dept);
      try {await (await client.users.fetch(id)).send({content:`Dein neuer, einmaliger RP-Charakter-Code für ${departments[dept]} lautet: \`${code}\`. Der alte Code ist ungültig.`});return i.reply({content:'✅ Ein neuer Code wurde per DM verschickt.',ephemeral:true});}
      catch{return i.reply({content:'⚠️ DM blockiert. Bitte den Spieler auffordern, DMs zu öffnen; dann Befehl erneut ausführen.',ephemeral:true});}
    }
    if(i.commandName==='rp_reset_temporary'){
      const count=db.resetTemporary();return i.reply({content:`✅ ${count} temporäre Charaktere entfernt. Spieler müssen danach ihren Hauptcharakter neu auswählen.`,ephemeral:true});
    }
  }
  if(i.isStringSelectMenu()){
    if(i.customId==='rp:apply')return i.showModal(modal(i.values[0]));
    if(i.customId==='rp:extra:select'){
      if(!db.firstPassed(i.user.id))return i.reply({content:'Weitere Rollen erst nach bestandener Grundausbildung.',ephemeral:true});
      return i.showModal(modal(i.values[0]));
    }
  }
  if(i.isModalSubmit()&&i.customId.startsWith('rp:form:'))return sendApplication(i,i.customId.split(':')[2]);
  if(i.isButton()){
    if(i.customId==='rp:dm:extra'){
      if(!db.firstPassed(i.user.id))return i.reply({content:'Weitere Rollen kannst du erst nach bestandener erster Grundausbildung beantragen.',ephemeral:true});
      return i.reply({content:'Wähle die zusätzliche Rolle:',components:[selector('rp:extra:select','Weitere Rolle auswählen',true)],ephemeral:true});
    }
    if(i.customId==='rp:dm:help')return i.reply({content:'Nach einer Genehmigung erhältst du den persönlichen Code hier per DM. Im Spiel M drücken, Characters öffnen, Code einlösen. Codes sind 30 Tage gültig und nur einmal verwendbar.',ephemeral:true});
    if(i.customId.startsWith('rp:approve:')||i.customId.startsWith('rp:deny:')){
      if(!eligible(i))return i.reply({content:'Nur das Serverteam darf Bewerbungen bearbeiten.',ephemeral:true});
      const isApproved=i.customId.startsWith('rp:approve:');const id=i.customId.split(':')[2];const application=db.application(id);
      if(!application||application.status!=='pending')return i.reply({content:'Bereits bearbeitet.',ephemeral:true});
      await i.deferUpdate();
      if(isApproved){
        const approved=db.approve(id);
        try{await (await client.users.fetch(approved.discordId)).send({content:`✅ **${approved.name}** (${departments[approved.dept]}) wurde genehmigt.\n\nDein **einmaliger Charakter-Code:** \`${approved.code}\`\n\nFiveM öffnen → **M** → **Characters** → **Code einlösen**. Code nicht weitergeben.`,components:[dmButtons()]});}
        catch{await i.followUp({content:'⚠️ Bewerbung genehmigt, aber die DM konnte nicht zugestellt werden. Für einen neuen Code muss die Teamverwaltung ergänzt werden; bitte keine Codes öffentlich posten.',ephemeral:true});}
      } else {
        db.deny(id);try{await (await client.users.fetch(application.discord_id)).send('Deine RP-Bewerbung wurde leider abgelehnt. Bei Fragen wende dich an das Serverteam.');}catch{}
      }
      await i.message.edit({components:[],embeds:[EmbedBuilder.from(i.message.embeds[0]).setFooter({text:`${isApproved?'Genehmigt':'Abgelehnt'} durch ${i.user.username}`})]});
    }
  }
 } catch(e) {console.error('[Discord]',e);if(i.deferred||i.replied)await i.followUp({content:'Fehler: '+e.message,ephemeral:true}).catch(()=>{});else await i.reply({content:'Fehler: '+e.message,ephemeral:true}).catch(()=>{});}
});
client.once(Events.ClientReady,async()=>{
 const rest=new REST({version:'10'}).setToken(env.DISCORD_TOKEN);
 await rest.put(Routes.applicationGuildCommands(env.DISCORD_CLIENT_ID,env.DISCORD_GUILD_ID),{body:commands});
 console.log(`[RP Discord] Online as ${client.user.tag}`);
});
client.login(env.DISCORD_TOKEN);
