// In-memory disposable PostgreSQL only; no production connection.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';
import { bootstrapRoomCapacity, actor, owner, approve } from './room_capacity_occupancy_fixture.mjs';
const db=new PGlite(); let passed=0;
const one=async(sql,args=[]) => (await db.query(sql,args)).rows[0];
const check=async(name,run)=>{await run();console.log(`PASS ${++passed}: ${name}`);};
const room=async(capacity=4)=>{
 const r=await one("select create_room_with_capacity($1,'Ground','Approved physical arrangement',$2) id",[randomUUID(),capacity]);
 return {id:r.id,beds:(await db.query('select * from bed_spaces where room_id=$1 and retired_at is null order by label',[r.id])).rows};
};
const tenant=async()=>{
 const id=randomUUID();await db.query("insert into profiles values($1::uuid,'tenant',$1::text,now())",[id]);await db.query('insert into tenant_details(profile_id) values($1)',[id]);return id;
};
const resize=(r,capacity,expected=r.beds.length)=>db.query("select configure_room_capacity($1,$2,$3,(select room_number from rooms where id=$1),'Ground','Approved adjustment')",[r.id,capacity,expected]);
const prepare=async(r,mode,count=1,rates=[])=>{
 const members=[];for(let n=0;n<count;n++)members.push({tenant_id:await tenant(),bed_id:r.beds[n].id,security_deposit:'1500.00',monthly_rent:rates[n]??'2300.00'});
 const ids=(await one("select prepare_contract_occupancy($1,$2,6000,$3::jsonb,current_date,current_date+30) ids",[r.id,mode,JSON.stringify(members)])).ids;
 return {ids,members};
};
try {
 const original=await bootstrapRoomCapacity(db,{randomUUID});
 await check('upgrade preserves original rooms, assignments, contracts and rates',async()=>{
  assert.equal((await one('select monthly_rent from tenant_contracts where id=$1',[original.legacyContract.id])).monthly_rent,'2500.00');
  assert.equal((await one('select count(*)::int n from bed_spaces where room_id=$1',[original.legacyFixture.room])).n,4);
  assert.deepEqual((await db.query('select id,occupancy_snapshot,monthly_rent,security_deposit,status from tenant_contracts where id=any($1::uuid[]) order by id',[original.sharedContracts])).rows,original.sharedHistory);
 });
 await check('four beds default; custom capacity and duplicate/invalid rooms',async()=>{
  const id=(await one("select create_room_with_capacity('Default room','Ground') id")).id;
  assert.equal((await one('select count(*)::int n from bed_spaces where room_id=$1',[id])).n,4);
  assert.equal((await room(6)).beds.length,6);
  await assert.rejects(db.query("select create_room_with_capacity(' default ROOM ','Ground')"));
  for(const invalid of [0,-1,null]) await assert.rejects(room(invalid));
 });
 await check('increase capacity and safe decrease retain every original bed ID',async()=>{
  const r=await room();await resize(r,6);
  assert.equal((await one('select count(*)::int n from bed_spaces where room_id=$1 and retired_at is null',[r.id])).n,6);
  await resize(r,3,6);
  assert.equal((await one('select count(*)::int n from bed_spaces where room_id=$1',[r.id])).n,6);
  assert.equal((await one('select count(*)::int n from bed_spaces where room_id=$1 and retired_at is null',[r.id])).n,3);
  await resize(r,5,3);
  assert.equal((await one('select count(*)::int n from bed_spaces where id=any($1::uuid[])',[r.beds.map(b=>b.id)])).n,4);
  await assert.rejects(resize(r,7,3),/changed/);
 });
 await check('occupied, reserved and historical beds prevent unsafe capacity decreases',async()=>{
  const r=await room(2),t=await tenant();
  await db.query('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)',[t,r.beds[0].id]);
  await db.query("update bed_spaces set status='reserved' where id=$1",[r.beds[1].id]);
  await assert.rejects(resize(r,1),/conflicts/);
  await db.query("update tenant_assignments set status='ended' where tenant_id=$1",[t]);
  await assert.rejects(resize(r,1),/conflicts/);
  assert.equal((await one('select capacity from rooms where id=$1',[r.id])).capacity,2);
 });
 await check('direct writes cannot mismatch physical capacity or revive retired bed identities',async()=>{
  const r=await room();await assert.rejects(db.query('update rooms set capacity=5 where id=$1',[r.id]),/must match/);
  await resize(r,3);
  const retired=await one('select id from bed_spaces where room_id=$1 and retired_at is not null',[r.id]);
  await assert.rejects(db.query("update bed_spaces set status='available' where id=$1",[retired.id]),/Retired/);
  await assert.rejects(db.query('delete from bed_spaces where id=$1',[retired.id]),/preserve|Preserve|Retire/);
  await assert.rejects(db.query('delete from rooms where id=$1',[r.id]),/retired bed history/);
 });
 for(const n of [1,2,3,6]) await check(`${n===1?'Solo':'Exclusive Shared'} ${n} occupants: exact shares, signatures and room reservation`,async()=>{
  const r=await room(Math.max(4,n));const c=await prepare(r,n===1?'solo':'shared',n);
  const contracts=(await db.query('select * from tenant_contracts where id=any($1::uuid[])',[c.ids])).rows;
  assert.equal(contracts.reduce((sum,c)=>sum+Number(c.monthly_rent),0),6000);
  await assert.rejects(db.query('select activate_tenant_contract($1)',[c.ids[0]]));
  for(const id of c.ids) {await approve(db,id);await db.query('select activate_tenant_contract($1)',[id]);}
  if(n<r.beds.length) await assert.rejects(db.query('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)',[await tenant(),r.beds.at(-1).id]),/reserved/);
  await assert.rejects(prepare(r,'standard_shared'),/reserved/);
  await assert.rejects(resize(r,3,r.beds.length));
 });
 for(const n of [2,3]) await check(`Standard Shared ${n} occupants: individual rents, independent newcomer and billing immutability`,async()=>{
  const r=await room();const first=await prepare(r,'standard_shared',n,['2000.00','2500.00','2750.00']);
  for(const id of first.ids) {await approve(db,id);await db.query('select activate_tenant_contract($1)',[id]);}
  const before=(await db.query('select id,monthly_rent,security_deposit,occupancy_snapshot from tenant_contracts where id=any($1::uuid[]) order by id',[first.ids])).rows;
  const charges=(await db.query('select * from billing_charges where contract_id=any($1::uuid[]) order by id',[first.ids])).rows;
  const added=await prepare({...r,beds:r.beds.slice(n)},'standard_shared',1,['3300.00']);
  await approve(db,added.ids[0]);await db.query('select activate_tenant_contract($1)',[added.ids[0]]);
  assert.deepEqual((await db.query('select id,monthly_rent,security_deposit,occupancy_snapshot from tenant_contracts where id=any($1::uuid[]) order by id',[first.ids])).rows,before);
  assert.deepEqual((await db.query('select * from billing_charges where contract_id=any($1::uuid[]) order by id',[first.ids])).rows,charges);
  assert.equal((await one('select monthly_rent from tenant_contracts where id=$1',[added.ids[0]])).monthly_rent,'3300.00');
  const projection=(await one('select get_room_contract_occupancies($1) groups',[r.id])).groups;
  assert.equal(projection.length,2);assert.ok(projection.every(g=>g.mode==='standard_shared' && !('total_rent_cents' in g)));
  await assert.rejects(prepare(r,'solo'),/reserved/);
 });
 await check('full Standard Shared, duplicate bed and missing rent are rejected atomically',async()=>{
  const r=await room(2);const first=await prepare(r,'standard_shared',2);
  await assert.rejects(prepare(r,'standard_shared',1),/Conflicting/);
  const fresh=await room(); const a=await tenant(),b=await tenant();
  await assert.rejects(db.query("select prepare_contract_occupancy($1,'standard_shared',6000,$2::jsonb,current_date,current_date+30)",[fresh.id,JSON.stringify([{tenant_id:a,bed_id:fresh.beds[0].id,security_deposit:0},{tenant_id:b,bed_id:fresh.beds[0].id,security_deposit:0}])]),/Duplicate/);
  await assert.rejects(db.query("select prepare_contract_occupancy($1,'standard_shared',6000,$2::jsonb,current_date,current_date+30)",[fresh.id,JSON.stringify([{tenant_id:a,bed_id:fresh.beds[0].id,security_deposit:0}])]),/individual monthly rent/);
  assert.equal((await one('select count(*)::int n from tenant_contracts where id=any($1::uuid[])',[first.ids])).n,2);
 });
 await check('contract end never frees an active assignment; release requires both legal end and assignment end',async()=>{
  const r=await room(),c=await prepare(r,'solo');
  await db.query("update tenant_contracts set status='terminated' where id=$1",[c.ids[0]]);
  assert.equal((await one('select released from contract_occupancy_arrangements where room_id=$1',[r.id])).released,false);
  await actor(db,'00000000-0000-0000-0000-000000000002');await db.exec('set role authenticated');
  await db.query('select end_tenant_assignment($1)',[c.members[0].tenant_id]);
  await db.exec('reset role');await actor(db,owner);
  assert.equal((await one('select released from contract_occupancy_arrangements where room_id=$1',[r.id])).released,true);
 });
 await check('ending an assignment first cannot release an active contractual obligation',async()=>{
  const r=await room(),c=await prepare(r,'solo');
  await actor(db,'00000000-0000-0000-0000-000000000002');await db.exec('set role authenticated');
  await db.query('select end_tenant_assignment($1)',[c.members[0].tenant_id]);
  await db.exec('reset role');await actor(db,owner);
  assert.equal((await one('select released from contract_occupancy_arrangements where room_id=$1',[r.id])).released,false);
  await db.query("update tenant_contracts set status='terminated' where id=$1",[c.ids[0]]);
  assert.equal((await one('select released from contract_occupancy_arrangements where room_id=$1',[r.id])).released,true);
 });
 await check('Owner-only structure and contract preparation; Caretaker projection excludes rent',async()=>{
  const r=await room();await prepare(r,'standard_shared');
  const newcomer=await tenant();
  for(const who of ['00000000-0000-0000-0000-000000000002',await tenant()]) {
   await actor(db,who);await db.exec('set role authenticated');
   await assert.rejects(room());await assert.rejects(resize(r,6));
   await assert.rejects(db.query("select prepare_contract_occupancy($1,'standard_shared',2000,$2::jsonb,current_date,current_date+30)",[r.id,JSON.stringify([{tenant_id:newcomer,bed_id:r.beds[1].id,monthly_rent:2000,security_deposit:0}])]),/Owner access/);
   await db.exec('reset role');
  }
  await actor(db,'00000000-0000-0000-0000-000000000002');await db.exec('set role authenticated');
  const groups=(await one('select get_room_contract_occupancies($1) groups',[r.id])).groups;
  assert.ok(groups.every(g=>!('total_rent_cents' in g)&&g.members.every(m=>!('rent_cents' in m))));
  await db.exec('reset role');await actor(db,owner);
 });
 await check('archived rooms reject capacity changes and assignments; restore retains bed identities',async()=>{
  const r=await room();await db.query('update rooms set is_active=false where id=$1',[r.id]);
  await assert.rejects(resize(r,6),/archived/);
  await assert.rejects(prepare(r,'solo'),/active registered/);
  await db.query('update rooms set is_active=true where id=$1',[r.id]);
  assert.deepEqual((await db.query('select id from bed_spaces where room_id=$1 order by label',[r.id])).rows.map(b=>b.id),r.beds.map(b=>b.id));
 });
 await check('signed occupancy rates and unsupported amendments remain blocked',async()=>{
  const r=await room(),c=await prepare(r,'standard_shared');await approve(db,c.ids[0]);await db.query('select activate_tenant_contract($1)',[c.ids[0]]);
  await assert.rejects(db.query('update tenant_contracts set monthly_rent=1 where id=$1',[c.ids[0]]),/immutable|signed/);
  await assert.rejects(db.query("insert into tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent,previous_contract_id) values($1,current_date+31,current_date+61,3000,$2)",[c.members[0].tenant_id,c.ids[0]]),/amendment|renew|expired|ended|reserved/);
  await assert.rejects(db.query('insert into room_transfers(id,contract_id,tenant_id) values($1,$2,$3)',[randomUUID(),c.ids[0],c.members[0].tenant_id]),/amendment/);
 });
 console.log(`${passed} dynamic room/occupancy PostgreSQL checks passed.`);
} catch(error){console.error(error);process.exitCode=1;}
finally{await db.close();}
