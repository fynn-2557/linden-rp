'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {Store}=require('../bot/store');
const {serve}=require('../bot/api');
const secret='f'.repeat(64);
test('HTTP API rejects unauthorized requests and never accepts a forged rank',async()=>{
 const store=new Store();const app=store.apply('123456789012345678','police','Michael','Anderson');const approved=store.approve(app.id);
 const server=serve(store,secret,{port:0});await new Promise(resolve=>server.on('listening',resolve));
 const url=`http://127.0.0.1:${server.address().port}`;
 const call=(route,body,token=secret)=>fetch(url+'/v1/'+route,{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+token},body:JSON.stringify(body)});
 try{
  const unauth=await call('whitelist',{discordId:'123456789012345678'},'wrong');assert.equal(unauth.status,401);
  const who=await call('whitelist',{discordId:'123456789012345678'});assert.equal((await who.json()).result.allowed,true);
  const license='license:'+'e'.repeat(40);
  const redeem=await call('redeem',{discordId:'123456789012345678',license,code:approved.code});assert.equal(redeem.status,200);
  const forbidden=await call('temporary',{discordId:'123456789012345678',license,department:'police',rank:5,firstName:'David',lastName:'Meyer'});assert.equal(forbidden.status,400);
  const body=await forbidden.json();assert.match(body.error,/Grundausbildung/);
 }finally{await new Promise(resolve=>server.close(resolve));store.close();}
});
