// Independent sessions against the disposable fixture created by test_conduct_investigation_agreements.mjs.
// node tool/test_conduct_investigation_concurrency.mjs --disposable --local-config <ignored local config>
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import pg from '../build/phase2_sql_tests/node_modules/pg/lib/index.js';
const at=process.argv.indexOf('--local-config');
assert.ok(process.argv.includes('--disposable')&&at>=0);
const config=JSON.parse(readFileSync(process.argv[at+1],'utf8'));
const url=new URL(config.connectionString);
assert.ok(['127.0.0.1','localhost','[::1]'].includes(url.hostname));
assert.match(url.pathname,/^\/carmelink_conduct_validation_[a-z0-9_]+$/);
const clients=Array.from({length:3},()=>new pg.Client({connectionString:config.connectionString}));
const [root,a,b]=clients;
let passed=0;
const one=async(sql,args=[])=>(await root.query(sql,args)).rows[0];
const check=async(name,run)=>{await run();console.log(`PASS ${++passed}: ${name}`);};
const actor=async(client,id)=>{
 await client.query('reset role');await client.query("select set_config('test.actor',$1,false)",[id]);await client.query('set role authenticated');
};
const run=async(client,action)=>{
 await client.query('begin');await client.query("set local statement_timeout='8s'");
 try {const result=await action();await client.query('commit');return {ok:true,result};}
 catch(error) {await client.query('rollback');return {ok:false,code:error.code,message:error.message};}
};
try {
 await Promise.all(clients.map(c=>c.connect()));
 const owner=(await one("select id from profiles where role='owner' limit 1")).id;
 const tenant=randomUUID();await root.query("insert into profiles values($1,'tenant','Concurrent test tenant')",[tenant]);
 const agreement=(await one("select id from confidentiality_agreement_versions where audience='tenant' order by published_at desc,id desc limit 1")).id;
 await check('simultaneous acceptance retries save one server record with the same identifier',async()=>{
  await actor(a,tenant);await actor(b,tenant);
  const results=await Promise.all([a,b].map(c=>run(c,()=>c.query('select accept_confidentiality_agreement($1,true,true) id',[agreement]))));
  assert.ok(results.every(r=>r.ok));assert.equal(results[0].result.rows[0].id,results[1].result.rows[0].id);
  assert.equal((await one('select count(*)::int n from confidentiality_agreement_acceptances where user_id=$1 and agreement_id=$2',[tenant,agreement])).n,1);
 });
 await check('publication and acceptance serialize; an unaccepted stale version is rejected',async()=>{
  const newcomer=randomUUID();await root.query("insert into profiles values($1,'tenant','Publication race test')",[newcomer]);
  await actor(a,owner);await a.query('begin');
  await a.query("select publish_confidentiality_agreement('tenant',$1,'APPROVED TEST FIXTURE ONLY. Concurrent publication test content.',true)",[randomUUID()]);
  await actor(b,newcomer);
  const pending=run(b,()=>b.query('select accept_confidentiality_agreement($1,true,true)',[agreement]));
  await a.query('commit');const result=await pending;
  assert.equal(result.ok,false);assert.match(result.message,/newer/);
  assert.equal((await one('select count(*)::int n from confidentiality_agreement_acceptances where user_id=$1',[newcomer])).n,0);
 });
 const caseId=randomUUID();await root.query(`insert into conduct_cases(id,tenant_id,category,title,description,incident_at,status,opened_by,tenant_notified_at)
  values($1,$2,'rule_violation','Concurrent incident','Original concurrency test incident',now(),'under_review',$3,now())`,[caseId,tenant,owner]);
 await check('conflicting investigation decisions serialize and reject the stale outcome',async()=>{
  const v=(await one('select updated_at::text v from conduct_cases where id=$1',[caseId])).v;
  await actor(a,owner);await actor(b,owner);
  const results=await Promise.all([a,b].map((c,n)=>run(c,()=>c.query('select record_conduct_investigation_decision($1,$2,$3,$4,$5)',
   [caseId,v,n?'not_confirmed':'confirmed','Independently reviewed documented decision',randomUUID()]))));
  assert.equal(results.filter(r=>r.ok).length,1);assert.equal(results.find(r=>!r.ok).code,'40001');
  assert.equal((await one("select count(*)::int n from conduct_case_events where case_id=$1 and event_type like 'investigation_%'",[caseId])).n,1);
 });
 const path=`${caseId}/${randomUUID()}.png`;
 await root.query("insert into storage.objects(bucket_id,name,owner_id,metadata) values('conduct_case_evidence',$1,$2,'{\"size\":123,\"mimetype\":\"image/png\"}')",[path,owner]);
 const register=c=>c.query("select register_conduct_case_evidence($1,$2,'image.png','image/png',123,'Original concurrent evidence') id",[caseId,path]);
 await check('concurrent evidence registration retries produce one attachment and one history entry',async()=>{
  await actor(a,owner);await actor(b,owner);
  const results=await Promise.all([a,b].map(c=>run(c,()=>register(c))));
  assert.ok(results.every(r=>r.ok),JSON.stringify(results.map(r=>({ok:r.ok,message:r.message}))));
  assert.equal(results[0].result.rows[0].id,results[1].result.rows[0].id);
  assert.equal((await one("select count(*)::int n from conduct_case_events where case_id=$1 and event_type='evidence_added'",[caseId])).n,1);
 });
 await check('storage deletion cannot race a successful registration',async()=>{
  const pendingPath=`${caseId}/${randomUUID()}.png`;
  await root.query("insert into storage.objects(bucket_id,name,owner_id,metadata) values('conduct_case_evidence',$1,$2,'{\"size\":123,\"mimetype\":\"image/png\"}')",[pendingPath,owner]);
  await actor(a,owner);await a.query('begin');
  await a.query("select register_conduct_case_evidence($1,$2,'image.png','image/png',123,'Protected race evidence')",[caseId,pendingPath]);
  await actor(b,owner);const deletion=run(b,()=>b.query('delete from storage.objects where name=$1',[pendingPath]));
  await a.query('commit');const result=await deletion;if(result.ok) assert.equal(result.result.rowCount,0);else assert.equal(result.code,'42501');
  assert.equal((await one('select count(*)::int n from storage.objects where name=$1',[pendingPath])).n,1);
 });
 console.log(`${passed} independent PostgreSQL concurrency checks passed.`);
} catch(error) { console.error(error.message);process.exitCode=1; }
finally {await Promise.allSettled(clients.map(c=>c.end()));}
