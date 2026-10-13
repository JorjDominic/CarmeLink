// Run only against an EMPTY local disposable database. Never a linked/live project.
// npm install --prefix build/phase2_sql_tests --no-audit --no-fund --ignore-scripts pg
// node tool/test_contract_occupancy_concurrency.mjs --disposable --local-config build/phase2_stabilization_local/connection.json
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {bootstrapOccupancyFixture} from './contract_occupancy_test_fixture.mjs';
const configIndex=process.argv.indexOf('--local-config');
let connectionString=configIndex>=0?JSON.parse(readFileSync(process.argv[configIndex+1],'utf8')).connectionString:process.env.PHASE2_TEST_DATABASE_URL;
if (!connectionString || !process.argv.includes('--disposable')) {
  console.log('PENDING EXTERNAL VERIFICATION: provide an empty local PostgreSQL database and --disposable.');process.exit(2);
}
const url=new URL(connectionString);
if(process.argv.includes('--docker-network')) { assert.ok(configIndex>=0);url.hostname='carmelink_phase2_validation_pg2';url.port='5432';connectionString=url.toString(); }
assert.ok(['127.0.0.1','localhost','[::1]',...(process.argv.includes('--docker-network')?['carmelink_phase2_validation_pg2']:[])].includes(url.hostname),'Only loopback test databases are allowed');
assert.ok(/^(carmelink_phase2_validation|phase2_validation_[a-z0-9_]+)$/.test(url.pathname.slice(1)),'Use a dedicated validation database name');
const {default:pg}=await import('../build/phase2_sql_tests/node_modules/pg/lib/index.js');
const {Client}=pg;
const clients=[new Client({connectionString}),new Client({connectionString}),new Client({connectionString})];
const [root,a,b]=clients;let sequence=20,passed=0;
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const owner=id(1),owner2=id(3);
const row=async(sql,p=[]) => (await root.query(sql,p)).rows[0];
const check=async(name,run)=>{await run();passed++;console.log(`PASS ${name}`);};
const db={exec:sql=>root.query(sql),query:(sql,p)=>root.query(sql,p)};
const actor=(client,who)=>client.query("select set_config('test.actor',$1,false)",[who]);
async function fixture(capacity=4) {
  const room=id(sequence++);await root.query("insert into rooms(id,room_number,floor,capacity) values($1,$2,'Ground',$3)",[room,`Room-${sequence}`,capacity]);
  const tenants=[],beds=[];
  for(let i=0;i<capacity;i++) {
    const tenant=id(sequence++),bed=id(sequence++);tenants.push(tenant);beds.push(bed);
    await root.query("insert into profiles values($1::uuid,'tenant','Fixture '||$1::text,now())",[tenant]);
    await root.query("insert into bed_spaces(id,room_id,label) values($1,$2,$3)",[bed,room,`Bed ${i}`]);
    await root.query('insert into tenant_details(profile_id) values($1)',[tenant]);
  }
  return {room,tenants,beds};
}
const members=(f,n)=>f.tenants.slice(0,n).map((tenant,i)=>({tenant_id:tenant,bed_id:f.beds[i],security_deposit:'0.00'}));
const prepare=(client,f,n)=>client.query("select prepare_contract_occupancy($1,$2,6000,$3::jsonb,current_date,current_date+30,'Concurrency fixture') ids",[f.room,n===1?'solo':'shared',JSON.stringify(members(f,n))]);
const activate=(client,c)=>client.query('select activate_tenant_contract($1)',[c]);
const assign=(client,tenant,bed)=>client.query('select assign_tenant_bed($1,$2)',[tenant,bed]);
async function approve(c) {
  await root.query("insert into contract_signers values($1,'tenant',true,'verified'),($1,'lessor',true,'verified')",[c]);
  await root.query("insert into contract_requirements values($1,true,'verified')",[c]);
  await root.query("insert into contract_documents values($1::uuid,'generated',1,'not_required',$1::text||'/original'),($1::uuid,'signed',1,'verified',$1::text||'/signed')",[c]);
  await root.query("insert into storage.objects values('contract-documents',$1::text||'/signed')",[c]);
  await root.query("update tenant_contracts set signature_status='verified' where id=$1",[c]);
}
async function begin(client,who=owner) {await client.query('begin');await client.query("set local statement_timeout='8000ms';set local deadlock_timeout='200ms'");await actor(client,who);}
async function finish(client,run) {
  try {const value=await run();await client.query('commit');return {ok:true,value};}
  catch(error) {await client.query('rollback');return {ok:false,code:error.code,message:error.message};}
}
async function race(left,right) {
  await Promise.all([begin(a,owner),begin(b,owner2)]);
  const results=await Promise.all([finish(a,left),finish(b,right)]);
  for(const r of results) assert.ok(!['40P01','57014'].includes(r.code),`Deadlock or timeout: ${r.code}`);
  return results;
}
async function waiting(client) {
  const pid=(await client.query('select pg_backend_pid() pid')).rows[0].pid;return pid;
}
async function waitForLock(pid) {
  const deadline=Date.now()+4000;
  while(Date.now()<deadline) {
    const state=await row('select wait_event_type from pg_stat_activity where pid=$1',[pid]);
    if(state?.wait_event_type==='Lock') return;
    await new Promise(resolve=>setTimeout(resolve,20));
  }
  throw new Error('Expected overlapping lock wait was not observed');
}
async function inversion(expectDeadlock) {
  const f=await fixture();await Promise.all([begin(a),begin(b,owner2)]);
  const pid=(await a.query('select pg_backend_pid() pid')).rows[0].pid;
  await a.query('select 1 from rooms where id=$1 for update',[f.room]);
  await b.query('select 1 from bed_spaces where id=$1 for update',[f.beds[0]]);
  const left=finish(a,()=>prepare(a,f,1));await waitForLock(pid);
  const right=finish(b,()=>assign(b,f.tenants[1],f.beds[0]));
  const results=await Promise.all([left,right]);
  if(expectDeadlock) {
    assert.ok(results.some(r=>r.code==='40P01'),'Baseline outcomes: '+JSON.stringify(results.map(r=>({ok:r.ok,code:r.code,message:r.message}))));
    console.log('REPRODUCED baseline deadlock SQLSTATE 40P01 using independent PostgreSQL sessions');
  } else {
    assert.ok(results[0].ok);assert.equal(results[1].code,'55P03');
    assert.match(results[1].message,/Refresh and retry/);
    assert.equal(Number((await row('select count(*) n from contract_occupancy_arrangements where room_id=$1',[f.room])).n),1);
  }
}
try {
  await Promise.all(clients.map(c=>c.connect()));
  assert.equal(Number((await row("select count(*) n from pg_tables where schemaname='public'")).n),0,'Database must be empty; refusing to change existing data');
  const version=await row('select version() v');console.log(`Database engine: ${version.v.split(',')[0]}`);
  const pids=await Promise.all(clients.map(async c=>(await c.query('select pg_backend_pid() pid')).rows[0].pid));
  assert.equal(new Set(pids).size,3);console.log(`Independent PostgreSQL connections confirmed (${pids.length} sessions)`);
  await bootstrapOccupancyFixture(db,fixture,{stabilize:false});
  await root.query("insert into profiles values($1,'owner','Second owner',now())",[owner2]);
  await root.query("alter table tenant_details add column residency_status text default 'active'");
  const assignmentSql=readFileSync('supabase/migrations/202609100002_complete_tenant_directory.sql','utf8');
  const start=assignmentSql.indexOf('create or replace function public.assign_tenant_bed(');
  await root.query(assignmentSql.slice(start,assignmentSql.indexOf('$$;',start)+3));
  await inversion(true);
  await root.query(readFileSync('supabase/migrations/202610130002_contract_occupancy_stabilization.sql','utf8'));
  if(process.argv.includes('--room-display')) {
    await root.query(readFileSync('supabase/migrations/202610130003_room_contract_occupancy_display.sql','utf8'));
    console.log('Phase 3 room display migration included in contention validation');
  }
  await check('inverse room/bed locking fails cleanly without a deadlock',()=>inversion(false));
  await check('two Owners reserving the same room create only one arrangement',async()=>{
    const f=await fixture();const results=await race(()=>prepare(a,f,2),()=>prepare(b,f,2));
    assert.equal(results.filter(r=>r.ok).length,1);
    assert.equal(Number((await row('select count(*) n from contract_occupancy_arrangements where room_id=$1',[f.room])).n),1);
    assert.equal(Number((await row("select sum(monthly_rent) total from tenant_contracts where occupancy_snapshot->>'room_id'=$1",[f.room])).total),6000);
  });
  await check('solo versus shared activation cannot revive a conflicting closed arrangement',async()=>{
    const f=await fixture();const solo=(await prepare(root,f,1)).rows[0].ids[0];await approve(solo);await activate(root,solo);
    await root.query("update tenant_contracts set status='terminated' where id=$1",[solo]);
    const shared=(await prepare(root,f,2)).rows[0].ids;for(const c of shared)await approve(c);
    const results=await race(()=>activate(a,solo),()=>activate(b,shared[0]));
    assert.equal(results[0].ok,false);
    if(!results[1].ok && results[1].code==='55P03') await activate(root,shared[0]);else assert.ok(results[1].ok,JSON.stringify(results[1]));
    assert.equal(Number((await row("select count(*) n from tenant_contracts where occupancy_id=(select occupancy_id from tenant_contracts where id=$1) and status='active'",[shared[0]])).n),1);
  });
  await check('two assignments to unavailable or solo-reserved beds fail without partial records',async()=>{
    const f=await fixture();await root.query("update bed_spaces set status='maintenance' where id=$1",[f.beds[0]]);
    let results=await race(()=>assign(a,f.tenants[1],f.beds[0]),()=>assign(b,f.tenants[2],f.beds[0]));assert.ok(results.every(r=>!r.ok));
    const g=await fixture();await prepare(root,g,1);
    results=await race(()=>assign(a,g.tenants[1],g.beds[1]),()=>assign(b,g.tenants[2],g.beds[1]));assert.ok(results.every(r=>!r.ok));
    assert.equal(Number((await row("select count(*) n from tenant_assignments where bed_space_id=$1 and status='active'",[g.beds[1]])).n),0);
  });
  await check('concurrent group term changes cannot corrupt approved shares',async()=>{
    const f=await fixture();const ids=(await prepare(root,f,2)).rows[0].ids;for(const c of ids){await approve(c);await activate(root,c);}
    const results=await race(()=>a.query('update tenant_contracts set monthly_rent=4000 where id=$1',[ids[0]]),()=>b.query('update tenant_contracts set monthly_rent=5000 where id=$1',[ids[1]]));assert.ok(results.every(r=>!r.ok));
    const values=(await root.query('select monthly_rent from tenant_contracts where id=any($1::uuid[])',[ids])).rows;assert.ok(values.every(r=>Number(r.monthly_rent)===3000));
  });
  await check('activation racing a conflicting assignment remains atomic',async()=>{
    const f=await fixture();const c=(await prepare(root,f,1)).rows[0].ids[0];await approve(c);
    const results=await race(()=>activate(a,c),()=>assign(b,f.tenants[1],f.beds[1]));assert.equal(results[1].ok,false);
    if(!results[0].ok && results[0].code==='55P03') { assert.equal((await row('select status from tenant_contracts where id=$1',[c])).status,'draft');await activate(root,c); } else assert.ok(results[0].ok,JSON.stringify(results[0]));
    assert.equal((await row('select status from tenant_contracts where id=$1',[c])).status,'active');
    assert.ok((await root.query('select original_amount from billing_charges where contract_id=$1',[c])).rows.every(r=>Number(r.original_amount)===6000));
  });
  await check('activation and signer metadata use a deadlock-safe room/contract order',async()=>{
    const f=await fixture();const c=(await prepare(root,f,1)).rows[0].ids[0];await approve(c);
    await Promise.all([begin(a),begin(b,owner2)]);const pid=(await a.query('select pg_backend_pid() pid')).rows[0].pid;
    await a.query('select 1 from rooms where id=$1 for update',[f.room]);await b.query('select 1 from tenant_contracts where id=$1 for update',[c]);
    const left=finish(a,()=>activate(a,c));await waitForLock(pid);
    const right=finish(b,()=>b.query("update tenant_contracts set signature_status='verified' where id=$1",[c]));
    const results=await Promise.all([left,right]);assert.ok(results[0].ok);assert.equal(results[1].code,'55P03');
  });
  await check('a shared tenant cannot be prepared in two rooms simultaneously',async()=>{
    const f=await fixture(),g=await fixture();g.tenants[0]=f.tenants[0];
    const results=await race(()=>prepare(a,f,1),()=>prepare(b,g,1));assert.equal(results.filter(r=>r.ok).length,1);
    assert.equal(Number((await row("select count(*) n from tenant_contracts where tenant_id=$1 and status='draft'",[f.tenants[0]])).n),1);
  });
  console.log(`Passed ${passed} real PostgreSQL contention checks after reproducing the original deadlock.`);
} finally {await Promise.allSettled(clients.map(c=>c.end()));}
