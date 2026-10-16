// EMPTY disposable loopback PostgreSQL only. Never reads linked Supabase config.
// node tool/test_dynamic_room_concurrency.mjs --disposable --local-config <ignored connection.json>
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';
import pg from '../build/phase2_sql_tests/node_modules/pg/lib/index.js';
import { bootstrapRoomCapacity, actor } from './room_capacity_occupancy_fixture.mjs';
const at=process.argv.indexOf('--local-config');
assert.ok(process.argv.includes('--disposable')&&at>=0,'Explicit disposable local config required');
const config=JSON.parse(readFileSync(process.argv[at+1],'utf8'));
const address=new URL(config.connectionString);
assert.ok(['127.0.0.1','localhost','[::1]'].includes(address.hostname));
assert.match(address.pathname,/^\/carmelink_room_validation(?:_[a-z0-9_]+)?$/);
const clients=Array.from({length:3},()=>new pg.Client({connectionString:config.connectionString}));
const [root,a,b]=clients;
const db={query:(sql,args)=>root.query(sql,args),exec:sql=>root.query(sql)};
let passed=0;
const one=async(sql,args=[]) => (await root.query(sql,args)).rows[0];
async function fixture() {
 const r=(await one("select create_room_with_capacity($1,'Ground') id",[randomUUID()])).id;
 const beds=(await root.query('select id from bed_spaces where room_id=$1 order by label',[r])).rows.map(b=>b.id);
 const tenants=[];
 for(let n=0;n<4;n++) {const id=randomUUID();tenants.push(id);await root.query("insert into profiles values($1::uuid,'tenant',$1::text,now())",[id]);await root.query('insert into tenant_details(profile_id) values($1)',[id]);}
 return {id:r,beds,tenants};
}
function prepare(client,f,mode,index=0,count=1) {
 const members=Array.from({length:count},(_,n)=>({tenant_id:f.tenants[index+n],bed_id:f.beds[index+n],security_deposit:'1000.00',monthly_rent:String(2000+index*100)}));
 return client.query('select prepare_contract_occupancy($1,$2,6000,$3::jsonb,current_date,current_date+30) ids',[f.id,mode,JSON.stringify(members)]);
}
async function run(client,action) {
 await client.query('begin');await client.query("set local statement_timeout='8s';set local deadlock_timeout='200ms'");await actor(client);
 try {const result=await action();await client.query('commit');return {ok:true,result};}
 catch(error) {await client.query('rollback');return {ok:false,code:error.code,message:error.message};}
}
async function race(left,right) {
 const result=await Promise.all([run(a,left),run(b,right)]);
 assert.ok(result.some(r=>r.ok));
 assert.ok(result.every(r=>!['40P01','57014'].includes(r.code)),JSON.stringify(result.map(r=>({ok:r.ok,code:r.code,message:r.message}))));
 return result;
}
async function check(name,fn) {await fn();console.log(`PASS ${++passed}: ${name}`);}
try {
 await Promise.all(clients.map(c=>c.connect()));
 assert.equal(Number((await one("select count(*) n from pg_tables where schemaname='public'")).n),0,'Refusing a nonempty database');
 assert.equal(new Set(await Promise.all(clients.map(async c=>(await c.query('select pg_backend_pid() pid')).rows[0].pid))).size,3);
 await bootstrapRoomCapacity(db,{randomUUID});
 await check('same-bed Standard Shared preparations serialize without duplicate assignments/contracts',async()=>{
  const f=await fixture();const result=await race(()=>prepare(a,f,'standard_shared'),()=>prepare(b,f,'standard_shared'));
  assert.equal(result.filter(r=>r.ok).length,1);
  assert.equal(Number((await one('select count(*) n from tenant_assignments where bed_space_id=$1 and status=\'active\'',[f.beds[0]])).n),1);
 });
 await check('different-bed newcomers can retry safely and retain their independent fixed rents',async()=>{
  const f=await fixture();const result=await race(()=>prepare(a,f,'standard_shared',0),()=>prepare(b,f,'standard_shared',1));
  if(!result[0].ok) await prepare(root,f,'standard_shared',0);
  if(!result[1].ok) await prepare(root,f,'standard_shared',1);
  const rows=(await root.query('select monthly_rent from tenant_contracts where tenant_id=any($1::uuid[]) order by monthly_rent',[f.tenants])).rows;
  assert.deepEqual(rows.map(r=>r.monthly_rent),['2000.00','2100.00']);
 });
 await check('Exclusive Shared and Standard Shared cannot concurrently reserve the same room',async()=>{
  const f=await fixture();const result=await race(()=>prepare(a,f,'shared',0,2),()=>prepare(b,f,'standard_shared',2));
  assert.equal(result.filter(r=>r.ok).length,1);
  const groups=(await root.query('select snapshot->>\'mode\' mode from contract_occupancy_arrangements where room_id=$1 and not released',[f.id])).rows;
  assert.equal(groups.length,1);
 });
 await check('capacity growth and preparation preserve room/bed consistency under concurrent writes',async()=>{
  const f=await fixture();await race(()=>a.query("select configure_room_capacity($1,6,4,(select room_number from rooms where id=$1),'Ground','Approved expansion')",[f.id]),()=>prepare(b,f,'standard_shared'));
  const row=await one('select capacity,(select count(*)::int from bed_spaces where room_id=r.id and retired_at is null) beds from rooms r where id=$1',[f.id]);
  assert.equal(row.capacity,row.beds);
 });
 await check('bed tuple/room lock inversion fails fast instead of deadlocking',async()=>{
  const f=await fixture();await b.query('begin');await actor(b);
  const pid=(await a.query('select pg_backend_pid() pid')).rows[0].pid;
  await b.query('select id from bed_spaces where id=$1 for update',[f.beds[0]]);
  const left=run(a,()=>prepare(a,f,'standard_shared'));
  let waiting=false;
  for(let n=0;n<80;n++) {
   const row=await one("select wait_event_type from pg_stat_activity where pid=$1",[pid]);
   if(row?.wait_event_type==='Lock') {waiting=true;break;}
   await new Promise(resolve=>setTimeout(resolve,20));
  }
  assert.ok(waiting,'Expected independent lock wait');
  let code;
  try {await b.query("update bed_spaces set label='Approved label' where id=$1",[f.beds[0]]);} catch(error){code=error.code;}
  await b.query('rollback');
  assert.equal(code,'55P03');assert.ok((await left).ok);
 });
 await check('authorized Caretaker assignment completion releases only a legally ended reservation',async()=>{
  const f=await fixture();const ids=(await prepare(root,f,'solo')).rows[0].ids;
  await root.query("update tenant_contracts set status='terminated' where id=$1",[ids[0]]);
  assert.equal((await one('select released from contract_occupancy_arrangements where room_id=$1',[f.id])).released,false);
  const result=await run(a,async()=>{
    await actor(a,'00000000-0000-0000-0000-000000000002');
    await a.query('set local role authenticated');
    await a.query('select end_tenant_assignment($1)',[f.tenants[0]]);
  });
  assert.ok(result.ok,result.message);
  assert.equal((await one('select released from contract_occupancy_arrangements where room_id=$1',[f.id])).released,true);
 });
 console.log(`${passed} independent PostgreSQL concurrency checks passed.`);
} catch(error){console.error(error.message);process.exitCode=1;}
finally {await Promise.allSettled(clients.map(c=>c.end()));}
