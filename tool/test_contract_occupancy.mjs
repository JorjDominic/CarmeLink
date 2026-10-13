import {bootstrapOccupancyFixture} from './contract_occupancy_test_fixture.mjs';
// Isolated PostgreSQL only. Reuses the existing PGlite installation; no live data.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const owner=id(1); let seq=20, passed=0;
const row=async(sql,p=[]) => (await db.query(sql,p)).rows[0];
const check=async(name,run)=>{await run(); passed++; console.log(`PASS ${name}`);};
const actor=who=>db.query("select set_config('test.actor',$1,false)",[who]);
async function fixture(capacity=4) {
  const room=id(seq++); await db.query("insert into rooms(id,room_number,floor,capacity) values($1,$2,'Ground', $3)",[room,`Custom-${seq}`,capacity]);
  const tenants=[], beds=[];
  for(let n=0;n<capacity;n++){
    const tenant=id(seq++), bed=id(seq++); tenants.push(tenant);beds.push(bed);
    await db.query("insert into profiles values($1::uuid,'tenant','Tenant '||$1::text,now())",[tenant]);
    await db.query("insert into bed_spaces(id,room_id,label) values($1,$2,$3)",[bed,room,`Bed ${n+1}`]);
    await db.query('insert into tenant_details(profile_id) values($1)',[tenant]);
  }
  return {room,tenants,beds};
}
const members=(f,n)=>f.tenants.slice(0,n).map((tenant,i)=>({tenant_id:tenant,bed_id:f.beds[i],security_deposit:'1500.00'}));
const prepare=async(f,n,total='6000.00',custom=null)=> (await row("select prepare_contract_occupancy($1,$2,$3,$4::jsonb,current_date,current_date+30,'Test agreement') ids",[f.room,n===1?'solo':'shared',total,JSON.stringify(custom??members(f,n))])).ids;
const activate=c=>db.query('select activate_tenant_contract($1)',[c]);
async function approve(c) {
  await db.query("insert into contract_signers values($1,'tenant',true,'verified'),($1,'lessor',true,'verified')",[c]);
  await db.query("insert into contract_requirements values($1,true,'verified')",[c]);
  await db.query("insert into contract_documents values($1::uuid,'generated',1,'not_required',$1::text||'/original'),($1::uuid,'signed',1,'verified',$1::text||'/signed')",[c]);
  await db.query("insert into storage.objects values('contract-documents',$1::text||'/signed')",[c]);
  await db.query("update tenant_contracts set signature_status='verified' where id=$1",[c]);
}
try {
  const {legacyFixture,legacyContract}=await bootstrapOccupancyFixture(db,fixture);
  await assert.rejects(db.exec(readFileSync('supabase/rollback/202610130001_contract_room_occupancy.sql','utf8')),/reverse the stabilization/);await db.exec('rollback');
  await db.exec(readFileSync('supabase/rollback/202610130002_contract_occupancy_stabilization.sql','utf8'));
  await db.exec(readFileSync('supabase/migrations/202610130002_contract_occupancy_stabilization.sql','utf8'));
  console.log('PASS empty-database rollback and reapply');
  for(const n of [1,2,3,4]) await check(`${n} occupants, immutable snapshot, exact rent and unchanged deposits`,async()=>{
    const f=await fixture(), ids=await prepare(f,n);
    const contracts=(await db.query('select * from tenant_contracts where id=any($1::uuid[]) order by tenant_id',[ids])).rows;
    assert.equal(contracts.length,n);assert.equal(contracts.reduce((v,c)=>v+Number(c.monthly_rent),0),6000);
    assert.ok(contracts.every(c=>Number(c.monthly_rent)===6000/n && Number(c.security_deposit)===1500 && c.status==='draft'));
    assert.equal(contracts[0].occupancy_snapshot.members.length,n);
    assert.ok(contracts[0].occupancy_snapshot.members.every(m=>!('security_deposit' in m)));
    await assert.rejects(db.query("insert into room_transfers(id,contract_id,tenant_id) values(gen_random_uuid(),$1,$2)",[ids[0],f.tenants[0]]),/group amendment/);
    assert.equal((await row('select capacity from rooms where id=$1',[f.room])).capacity,4);
    await assert.rejects(prepare(f,n),/already reserved/);
    await assert.rejects(db.query("insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)",[id(999999),f.beds.at(-1)]),/reserved/);
  });
  await check('existing selected occupants retain their exact assignment records',async()=>{
    const f=await fixture(2);
    const a=await row('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2) returning id',[f.tenants[0],f.beds[0]]);
    await prepare(f,2);
    assert.equal((await row("select id from tenant_assignments where tenant_id=$1 and status='active'",[f.tenants[0]])).id,a.id);
    assert.equal(Number((await row("select count(*) n from tenant_assignments a join bed_spaces b on b.id=a.bed_space_id where b.room_id=$1 and a.status='active'",[f.room])).n),2);
  });
  await check('centavo allocation sums exactly and is stable in tenant order',async()=>{
    const f=await fixture(), ids=await prepare(f,3,'100.00',members(f,3).reverse());
    const c=(await db.query('select monthly_rent from tenant_contracts where id=any($1::uuid[]) order by tenant_id',[ids])).rows;
    assert.deepEqual(c.map(x=>Number(x.monthly_rent)),[33.34,33.33,33.33]);
  });
  await check('registered custom rooms, capacity, duplicate tenants/beds and rollback',async()=>{
    const f=await fixture(2);
    await assert.rejects(prepare({...f,room:id(9999)},2),/registered room/);
    await assert.rejects(prepare(f,3,'6000',[...members(f,2),{tenant_id:id(9999),bed_id:id(9998),security_deposit:0}]),/capacity/);
    await assert.rejects(prepare(f,2,'6000',[members(f,2)[0],members(f,2)[0]]),/Duplicate/);
    await assert.rejects(prepare(f,2,'6000',members(f,2).map(x=>({...x,bed_id:f.beds[0]}))),/Duplicate/);
    await assert.rejects(prepare(f,2,'1.001'),/Invalid room rent/);
    const count=await row('select count(*) n from contract_occupancy_arrangements where room_id=$1',[f.room]);assert.equal(Number(count.n),0);
    await assert.rejects(db.query("insert into rooms(room_number,floor,capacity) select room_number,floor,capacity from rooms where id=$1",[f.room]),/duplicate key/);
    await prepare(f,2);
  });
  await check('conflicting occupants and beds are rejected',async()=>{
    const f=await fixture(), other=await fixture();
    await db.query('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)',[f.tenants[0],other.beds[0]]);
    await assert.rejects(prepare(f,2),/Conflicting/);
    const g=await fixture();
    await db.query('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)',[g.tenants[3],g.beds[3]]);
    await assert.rejects(prepare(g,2),/outside/);
  });
  await check('activation retains signing guards and existing billing reads allocated rent',async()=>{
    const f=await fixture(), ids=await prepare(f,2);
    await assert.rejects(activate(ids[0]),/signed contract copy|Signed contract|signers|documents/i);
    await approve(ids[0]);await activate(ids[0]);await approve(ids[1]);await activate(ids[1]);
    const bills=(await db.query('select * from billing_charges where contract_id=any($1::uuid[])',[ids])).rows;
    assert.ok(bills.length>0 && bills.every(b=>Number(b.original_amount)===3000));
    const before=JSON.stringify(bills);
    await assert.rejects(db.query('update tenant_contracts set monthly_rent=4000 where id=$1',[ids[0]]),/immutable/);
    await db.query("update tenant_assignments set status='ended',ends_on=current_date where tenant_id=$1",[f.tenants[0]]);
    await db.query("update tenant_contracts set status='terminated' where id=$1",[ids[0]]);
    assert.equal(Number((await row('select monthly_rent from tenant_contracts where id=$1',[ids[1]])).monthly_rent),3000);
    assert.equal(JSON.stringify((await db.query('select * from billing_charges where contract_id=any($1::uuid[])',[ids])).rows),before);
    await assert.rejects(db.query("update tenant_contracts set status='draft' where id=$1",[ids[1]]),/cannot reopen/);
    await assert.rejects(db.query("insert into tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent,previous_contract_id) values($1,current_date+31,current_date+60,3000,$2)",[f.tenants[0],ids[0]]),/reserved occupancy|amendment/);
    await db.query("update tenant_contracts set status='terminated' where id=$1",[ids[1]]);
    assert.equal((await row('select released from contract_occupancy_arrangements where room_id=$1',[f.room])).released,true);
  });
  await check('activation rejects changed assignments and preserves draft on failure',async()=>{
    const f=await fixture(), ids=await prepare(f,2);await approve(ids[0]);
    await db.query("update tenant_assignments set status='ended' where tenant_id=$1",[f.tenants[1]]);
    await assert.rejects(activate(ids[0]),/assignments changed/);
    assert.equal((await row('select status from tenant_contracts where id=$1',[ids[0]])).status,'draft');
  });
  await check('room and bed metadata cannot invalidate reserved contract documents',async()=>{
    const f=await fixture(), ids=await prepare(f,1);
    await assert.rejects(db.query('update rooms set capacity=8 where id=$1',[f.room]),/identity and capacity/);
    await assert.rejects(db.query("update bed_spaces set label='Changed' where id=$1",[f.beds[0]]),/reserved occupancy/);
    await assert.rejects(db.query('delete from tenant_contracts where id=$1',[ids[0]]),/preserve their history/);
  });
  await check('two queued competing attempts produce only one room arrangement',async()=>{
    const f=await fixture();const outcomes=await Promise.allSettled([prepare(f,2),prepare(f,2)]);
    assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);
    assert.equal(Number((await row('select count(*) n from contract_occupancy_arrangements where room_id=$1',[f.room])).n),1);
    // PGlite serializes requests. Real multi-session lock/deadlock behavior needs PostgreSQL.
  });
  await check('existing contract compatibility and tenant access scope',async()=>{
    const f=await fixture();
    await assert.rejects(db.query('insert into tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent) values($1,current_date,current_date+30,2500)',[f.tenants[0]]),/Prepare an occupancy arrangement/);
    await approve(legacyContract.id);await activate(legacyContract.id);
    const renewal=await row("insert into tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent,security_deposit,previous_contract_id) select tenant_id,ends_on+1,ends_on+365,3000,security_deposit,id from tenant_contracts where id=$1 returning occupancy_id,status",[legacyContract.id]);
    assert.equal(renewal.occupancy_id,null);assert.equal(renewal.status,'draft');
    await actor(legacyFixture.tenants[0]);const mine=await row('select get_my_contract() c');assert.equal(mine.c.id,legacyContract.id);assert.equal(mine.c.occupancy_snapshot,null);
    await actor(id(2));await assert.rejects(prepare(f,1),/Owner access required/);await actor(owner);
  });
  await check('reservation RLS permits staff room IDs but hides contractual deposit data',async()=>{
    await db.exec('grant usage on schema public,auth to authenticated');
    await actor(owner);await db.exec('set role authenticated');
    assert.ok((await db.query('select room_id,released from contract_occupancy_arrangements')).rows.length>0);
    await assert.rejects(db.exec('select deposit_terms from contract_occupancy_arrangements'),/permission denied/);
    await assert.rejects(db.exec('update contract_occupancy_arrangements set released=true'),/permission denied/);
    await db.exec('reset role');
    const f=await fixture();await actor(f.tenants[0]);await db.exec('set role authenticated');
    assert.equal((await db.query('select room_id from contract_occupancy_arrangements')).rows.length,0);
    await db.exec('reset role');await actor(owner);
  });
  await check('activation rejects missing roles, null sessions and caretaker sessions',async()=>{
    const f=await fixture(), ids=await prepare(f,1);await approve(ids[0]);
    for(const who of ['',id(9999999),id(2),f.tenants[0]]) {
      await actor(who);await assert.rejects(activate(ids[0]),/Owner access required/);
    }
    await actor(owner);assert.equal((await row('select status from tenant_contracts where id=$1',[ids[0]])).status,'draft');
    await activate(ids[0]);
  });
  await check('actual contract RLS permits own/linked reads and denies unauthorized lifecycle writes',async()=>{
    const f=await fixture(), ids=await prepare(f,1);
    const guardian=id(4);await db.query("insert into profiles values($1,'guardian','Fixture guardian',now())",[guardian]);
    await db.query('insert into guardian_tenant_links(guardian_id,tenant_id) values($1,$2)',[guardian,f.tenants[0]]);
    for(const [who,readCount] of [[owner,1],[id(2),0],[f.tenants[0],1],[guardian,1],[f.tenants[1],0]]) {
      await actor(who);await db.exec('set role authenticated');
      assert.equal((await db.query('select id from tenant_contracts where id=$1',[ids[0]])).rows.length,readCount);
      if(who!==owner) {
        assert.equal((await db.query("update tenant_contracts set notes='Unauthorized' where id=$1 returning id",[ids[0]])).rows.length,0);
        await assert.rejects(activate(ids[0]),/Owner access required/);
      }
      await db.exec('reset role');
    }
    await actor(owner);
  });
  await check('evidence RPCs reject missing roles and unauthorized staff before changing records',async()=>{
    const calls=[
      ["select review_signed_contract_document($1,true,'Fixture review')",[id(999)]],
      ["select review_contract_requirement($1,true,'Fixture review')",[id(999)]],
      ['select set_contract_requirement_required($1,true)',[id(999)]],
      ["select update_contract_signer($1,'verified')",[id(999)]],
      ["select submit_owner_electronic_signature($1,'invalid',100,$2)",[id(999),'a'.repeat(64)]],
    ];
    for(const who of ['',id(999999),id(2)]) {
      await actor(who);for(const [sql,args] of calls) await assert.rejects(db.query(sql,args),/Forbidden|Owner access required/);
    }
    for(const who of ['',id(999999),id(2)]) {
      await actor(who);await assert.rejects(db.query("select submit_tenant_electronic_signature($1,'invalid',100,$2)",[id(999),'a'.repeat(64)]),/Tenant access required/);
      await assert.rejects(db.query("select submit_contract_requirement($1,'invalid','fixture.png','image/png',100,$2,false,0::smallint)",[id(999),'a'.repeat(64)]),/Forbidden/);
    }
    await actor(owner);
  });
  await check('rollback refuses to discard real contractual records',async()=>{
    await assert.rejects(db.exec(readFileSync('supabase/rollback/202610130001_contract_room_occupancy.sql','utf8')),/Rollback blocked/);
    await db.exec('rollback');
    assert.ok(Number((await row('select count(*) n from contract_occupancy_arrangements')).n)>0);
  });
  console.log(`Passed ${passed} occupancy database checks. PGlite serializes requests; run the independent PostgreSQL script for contention checks.`);
} finally {await db.close();}
