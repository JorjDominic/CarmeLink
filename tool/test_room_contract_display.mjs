// Disposable embedded PostgreSQL. Never connects to a shared/live database.
import {PGlite} from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import {bootstrapOccupancyFixture} from './contract_occupancy_test_fixture.mjs';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite(); const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
let sequence=20,passed=0; const owner=id(1);
const row=async(sql,p=[]) => (await db.query(sql,p)).rows[0];
const actor=who=>db.query("select set_config('test.actor',$1,false)",[who]);
const check=async(name,run)=>{await run();passed++;console.log(`PASS ${name}`);};
async function fixture(capacity=4) {
  const room=id(sequence++);await db.query("insert into rooms(id,room_number,floor,capacity) values($1,$2,'Ground',$3)",[room,`Room-${sequence}`,capacity]);
  const tenants=[],beds=[];
  for(let i=0;i<capacity;i++) {
    const tenant=id(sequence++),bed=id(sequence++);tenants.push(tenant);beds.push(bed);
    await db.query("insert into profiles values($1::uuid,'tenant','Tenant '||$1::text,now())",[tenant]);
    await db.query("insert into bed_spaces(id,room_id,label) values($1,$2,$3)",[bed,room,`Bed ${i+1}`]);
    await db.query('insert into tenant_details(profile_id) values($1)',[tenant]);
  }
  return {room,tenants,beds};
}
const summary=async(room=null,history=false)=>(await row('select get_room_contract_occupancies($1,$2) records',[room,history])).records;
const prepare=async(f,n)=>(await row("select prepare_contract_occupancy($1,$2,6000,$3::jsonb,current_date,current_date+30,'Room display fixture') ids",
  [f.room,n===1?'solo':'shared',JSON.stringify(f.tenants.slice(0,n).map((tenant,i)=>({tenant_id:tenant,bed_id:f.beds[i],security_deposit:'1500.00'})))])).ids;
async function approve(c) {
  await db.query("insert into contract_signers values($1,'tenant',true,'verified'),($1,'lessor',true,'verified')",[c]);
  await db.query("insert into contract_requirements values($1,true,'verified')",[c]);
  await db.query("insert into contract_documents values($1::uuid,'generated',1,'not_required',$1::text||'/original'),($1::uuid,'signed',1,'verified',$1::text||'/signed')",[c]);
  await db.query("insert into storage.objects values('contract-documents',$1::text||'/signed')",[c]);
  await db.query("update tenant_contracts set signature_status='verified' where id=$1",[c]);
}
try {
  await bootstrapOccupancyFixture(db,fixture);
  await db.exec(readFileSync('supabase/migrations/202610130003_room_contract_occupancy_display.sql','utf8'));
  await check('vacant and legacy rooms have no invented occupancy arrangements',async()=>{
    assert.deepEqual(await summary((await fixture()).room),[]);
  });
  for(const n of [1,2,3,4]) await check(`${n} occupants expose snapshot totals and authoritative contract shares`,async()=>{
    const f=await fixture(),ids=await prepare(f,n); const g=(await summary(f.room)).at(0);
    assert.equal(g.members.length,n);assert.equal(g.mode,n===1?'solo':'shared');
    assert.equal(g.total_rent_cents,600000);assert.equal(g.released,false);
    for(const m of g.members) {assert.equal(m.rent_cents,600000/n);assert.ok(ids.includes(m.contract_id));assert.equal(m.status,'draft');}
    assert.ok(!JSON.stringify(g).includes('deposit'));
    assert.equal((await row('select capacity from rooms where id=$1',[f.room])).capacity,4);
    assert.equal((await row('select count(*)::int n from bed_spaces where room_id=$1',[f.room])).n,4);
  });
  await check('caretaker occupancy reads omit financial terms and do not grant contract access',async()=>{
    const f=await fixture();await prepare(f,2);await actor(id(2));await db.exec('set role authenticated');
    const g=(await summary(f.room)).at(0);assert.equal(g.members.length,2);
    assert.equal(g.total_rent_cents,undefined);assert.ok(g.members.every(m=>m.rent_cents===undefined));
    assert.ok(!JSON.stringify(g).includes('deposit'));
    assert.equal((await db.query('select id from tenant_contracts')).rows.length,0);
    await assert.rejects(prepare(f,1),/Owner access required/);
    await assert.rejects(db.exec('select snapshot from contract_occupancy_arrangements'),/permission denied/);
    await db.exec('reset role');await actor(owner);
  });
  await check('tenant guardian missing session and unknown role cannot read staff projection',async()=>{
    const f=await fixture();await prepare(f,1);
    const guardian=id(4);await db.query("insert into profiles values($1,'guardian','Guardian',now())",[guardian]);
    for(const who of [f.tenants[0],guardian,'',id(999999)]) {
      await actor(who);await db.exec('set role authenticated');
      await assert.rejects(summary(),/Staff room access required/);await db.exec('reset role');
    }
    await actor(owner);
    await db.exec('set role anon');await assert.rejects(summary(),/permission denied/);await db.exec('reset role');
  });
  await check('activation refreshes existing room realtime row without changing physical records',async()=>{
    const f=await fixture(),ids=await prepare(f,1);await approve(ids[0]);
    const before=await row('select updated_at,capacity from rooms where id=$1',[f.room]);
    await db.query('select activate_tenant_contract($1)',[ids[0]]);
    const after=await row('select updated_at,capacity from rooms where id=$1',[f.room]);
    assert.ok(new Date(after.updated_at).getTime()>new Date(before.updated_at).getTime());assert.equal(after.capacity,before.capacity);
    assert.equal((await summary(f.room))[0].members[0].status,'active');
  });
  await check('departure preserves group reservation shares history and existing bills',async()=>{
    const f=await fixture(),ids=await prepare(f,3);
    for(const c of ids) {await approve(c);await db.query('select activate_tenant_contract($1)',[c]);}
    const original=await row('select snapshot,deposit_terms from contract_occupancy_arrangements where room_id=$1',[f.room]);
    const bills=(await db.query('select * from billing_charges where contract_id=any($1::uuid[]) order by id',[ids])).rows;
    await db.query("update tenant_assignments set status='ended',ends_on=current_date where tenant_id=$1",[f.tenants[2]]);
    await db.query("update tenant_contracts set status='terminated' where id=$1",[ids[2]]);
    const g=(await summary(f.room))[0];assert.equal(g.released,false);assert.equal(g.members.length,3);
    assert.ok(g.members.every(m=>m.rent_cents===200000));assert.equal(g.members.filter(m=>m.status==='active').length,2);
    assert.deepEqual(await row('select snapshot,deposit_terms from contract_occupancy_arrangements where room_id=$1',[f.room]),original);
    assert.deepEqual((await db.query('select * from billing_charges where contract_id=any($1::uuid[]) order by id',[ids])).rows,bills);
    await assert.rejects(db.query('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)',[f.tenants[3],f.beds[3]]),/reserved/);
    await assert.rejects(db.query('update rooms set is_active=false where id=$1',[f.room]),/reserved/);
    for(const c of ids.slice(0,2)) await db.query("update tenant_contracts set status='terminated' where id=$1",[c]);
    assert.deepEqual(await summary(f.room),[]);const old=(await summary(f.room,true))[0];assert.equal(old.released,true);
    assert.ok(old.members.every(m=>m.status==='terminated'));
    assert.equal((await row("select count(*)::int n from tenant_assignments a join bed_spaces b on b.id=a.bed_space_id where b.room_id=$1",[f.room])).n,3);
  });
  await check('amendment restrictions and reserved bed metadata protection remain intact',async()=>{
    const f=await fixture(),ids=await prepare(f,2);
    await assert.rejects(db.query('update tenant_contracts set monthly_rent=3500 where id=$1',[ids[0]]),/immutable|amendment/);
    await assert.rejects(db.query("update bed_spaces set label='Changed' where id=$1",[f.beds[3]]),/reserved/);
  });
  await check('display rollback removes only projection and signals preserving occupancy history',async()=>{
    const before=(await db.query('select * from contract_occupancy_arrangements order by id')).rows;
    await assert.rejects(db.exec(readFileSync('supabase/rollback/202610130002_contract_occupancy_stabilization.sql','utf8')),/Phase 3 room display/);
    await db.exec('rollback');
    await db.exec(readFileSync('supabase/rollback/202610130003_room_contract_occupancy_display.sql','utf8'));
    assert.deepEqual((await db.query('select * from contract_occupancy_arrangements order by id')).rows,before);
    await db.exec(readFileSync('supabase/migrations/202610130003_room_contract_occupancy_display.sql','utf8'));
  });
  console.log(`Passed ${passed} room contract display PostgreSQL checks. Full Supabase realtime delivery remains pending.`);
} finally {await db.close();}
