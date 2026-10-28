'use strict';
const http=require('node:http');
const {timingSafeEqual}=require('node:crypto');
function secureEq(a,b){const x=Buffer.from(a||''),y=Buffer.from(b||'');return x.length===y.length && timingSafeEqual(x,y);}
function serve(store,secret,{host='127.0.0.1',port=4792}={}){
  if(!secret || secret.length<32) throw new Error('RP_API_SECRET muss mindestens 32 Zeichen lang sein.');
  const operations={
    '/v1/whitelist': ({discordId})=>({allowed:store.whitelist(discordId)}),
    '/v1/state': ({discordId,license})=>store.state(discordId,license),
    '/v1/redeem': ({discordId,license,code})=>store.redeem(discordId,license,code),
    '/v1/temporary': ({discordId,license,department,firstName,lastName,rank})=>store.temporary(discordId,license,department,firstName,lastName,rank),
    '/v1/select': ({discordId,license,characterId,previousAppearance})=>store.select(discordId,license,characterId,previousAppearance),
    // These endpoints are callable ONLY by the trusted FiveM SERVER resource.
    // There is intentionally no rp_identity:action client dispatch to these endpoints.
    '/v1/duty-start': ({discordId,license,ff})=>store.startDuty(discordId,license,{ff:ff===true}),
    '/v1/duty-stop': ({discordId,license,count,reason})=>store.stopDuty(discordId,license,{count:count!==false,reason:reason==='disconnect'?'disconnect':'normal'}),
    '/v1/appearance': ({discordId,license,appearance})=>store.saveAppearance(discordId,license,appearance),
  };
  const server=http.createServer((req,res)=>{
    const respond=(status,value)=>{res.writeHead(status,{'content-type':'application/json; charset=utf-8','cache-control':'no-store'});res.end(JSON.stringify(value));};
    if(!secureEq(req.headers.authorization,'Bearer '+secret)) return respond(401,{error:'Nicht autorisiert.'});
    if(req.method!=='POST'||!operations[req.url]) return respond(404,{error:'Unbekannte Anfrage.'});
    let body='';req.on('data',chunk=>{body+=chunk;if(body.length>160000)req.destroy();});
    req.on('end',()=>{try{const data=JSON.parse(body);if(!data||typeof data!=='object')throw Error('Payload fehlt.');respond(200,{ok:true,result:operations[req.url](data)});}catch(e){respond(400,{ok:false,error:e.message});}});
  });
  server.listen(port,host,()=>console.log(`[RP API] Local API on http://${host}:${port}`));
  return server;
}
module.exports={serve};
